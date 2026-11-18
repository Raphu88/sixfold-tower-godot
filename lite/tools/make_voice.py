#!/usr/bin/env python3
"""Records the voice clips Six Towers LITE reads aloud, with the Kokoro voice.

Every phrase the game can say comes from Data.spoken() in scripts/data.gd
(this tool asks Godot for the list through tools/list_phrases.gd). Each phrase
is spoken by Kokoro (an open text-to-speech voice, Apache 2.0), the silence
around it is trimmed (with the short 'uh' Kokoro puts before words like
'Face'), all clips are made equally loud (about -16 LUFS) and saved as small
OGG files in assets/voice/. If the voice says a word oddly, add a respelling
to SAY below. It then writes scripts/voice.gd, which maps each phrase to its
clip, for the game to load.

Run it again whenever words are added or changed in data.gd. It only records
phrases that are new or changed (assets/voice/manifest.json remembers what was
made, and how), deletes clips no longer used, and rewrites voice.gd. Changing
VOICE, SPEED or PROCESS below re-records everything. Afterwards, from the lite
folder, run `godot --headless --editor --quit` so Godot imports the new clips.

One-time setup (Python 3.10+, ffmpeg with libvorbis, Godot 4.3 as `godot` on
the PATH, or set GODOT=/path/to/godot):

    pip install kokoro-onnx==0.6.1 soundfile pyloudnorm

(kokoro-onnx brings onnxruntime, numpy and phonemizer with a bundled espeak-ng;
pyloudnorm brings scipy.)
The Kokoro model files (about 350 MB) are NOT kept in the repo: the first run
downloads them into ~/.cache/kokoro/ (or $KOKORO_CACHE) from MODEL_URL and
VOICES_URL below.

Run (from anywhere):

    python3 lite/tools/make_voice.py            # record what's new or changed
    python3 lite/tools/make_voice.py --all      # re-record every phrase
    python3 lite/tools/make_voice.py --dry-run  # only say what would change
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

# --- Voice settings (changing any of these re-records every clip) ----------
VOICE = "af_heart"   # warm, friendly American English voice (Kokoro's best-rated)
SPEED = 0.9          # a little slower than normal, for a young child
LANG = "en-us"
# Bump when trimming/loudness/encoding below changes, to re-record everything.
PROCESS = 3

# Words the voice says better when spelled differently (the screen still shows
# the real word). Whole words only, matched ignoring case. Changing an entry
# re-records just the phrases that use it.
SAY = {
    "Gryphon": "Griffin",   # otherwise "GRIF-ahn"
    "Hooray": "Hurray",     # otherwise "HOR-ay"
}

# --- Kokoro model files (downloaded once into the cache, never committed) --
RELEASE = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
MODEL_FILE = "kokoro-v1.0.onnx"
VOICES_FILE = "voices-v1.0.bin"
MODEL_URL = RELEASE + MODEL_FILE
VOICES_URL = RELEASE + VOICES_FILE
CACHE = os.path.expanduser(os.environ.get("KOKORO_CACHE", "~/.cache/kokoro"))

# --- Clip processing ------------------------------------------------------
TARGET_LUFS = -16.0   # loudness every clip is brought to
PEAK_DBFS = -1.5      # never let a sample go above this
LEAD_PAD = 0.04       # seconds of quiet kept before the first sound
TAIL_PAD = 0.12       # and after the last (soft endings fade slowly)
GATE_DB = -42.0       # "silence" = this far below the clip's loudest moment
OGG_QUALITY = 4       # Vorbis quality (q4 is about 64 kbit/s; speech is far less)

LITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICE_DIR = os.path.join(LITE, "assets", "voice")
MANIFEST = os.path.join(VOICE_DIR, "manifest.json")
VOICE_GD = os.path.join(LITE, "scripts", "voice.gd")
RES_DIR = "res://assets/voice/"


def phrases_from_godot():
    """Asks Godot for Data.spoken() (via tools/list_phrases.gd)."""
    godot = os.environ.get("GODOT", "godot")
    cmd = [godot, "--headless", "-s", "tools/list_phrases.gd"]
    try:
        out = subprocess.run(cmd, cwd=LITE, capture_output=True, text=True, timeout=300)
    except FileNotFoundError:
        sys.exit("Couldn't run Godot (%r). Put it on the PATH or set GODOT." % godot)
    for line in out.stdout.splitlines():
        if line.startswith("PHRASES_JSON "):
            phrases = json.loads(line[len("PHRASES_JSON "):])
            seen, result = set(), []
            for p in phrases:
                p = str(p).strip()
                if p and p not in seen:
                    seen.add(p)
                    result.append(p)
            return result
    sys.exit("Godot didn't print the phrase list.\n" + out.stdout + out.stderr)


def clip_name(text):
    """A readable, stable file name: a slug of the text plus a short hash, so
    'Zap' and 'Zap!' or 'Floor 2' and 'Floor 3' never share a file."""
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:40].rstrip("_") or "clip"
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()[:6]
    return "%s_%s.ogg" % (slug, digest)


def to_say(text):
    """The text actually given to the voice (SAY respellings applied)."""
    for word, said in SAY.items():
        text = re.sub(r"\b%s\b" % re.escape(word), said, text, flags=re.IGNORECASE)
    # A bare word ("Wave") gets an odd, trailing-off ending; a full stop gives
    # it the natural falling tone of a finished sentence.
    if not re.search(r"[.!?]$", text):
        text += "."
    return text


def first_sound(kokoro, text):
    """The first speech sound of the text, as Kokoro will say it."""
    phonemes = kokoro.tokenizer.phonemize(text, LANG)
    return next((c for c in phonemes if c.isalpha()), "")


def download(url, dest):
    print("  downloading %s\n    -> %s" % (url, dest))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    part = dest + ".part"
    with urllib.request.urlopen(url) as r, open(part, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done, last = 0, 0.0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if total and time.time() - last > 2:
                last = time.time()
                print("    %3d%% of %d MB" % (done * 100 // total, total >> 20))
    os.replace(part, dest)


def load_kokoro():
    try:
        from kokoro_onnx import Kokoro
    except ImportError:
        sys.exit("Missing Python packages. Run:\n"
                 "    pip install kokoro-onnx==0.6.1 soundfile pyloudnorm")
    model = os.path.join(CACHE, MODEL_FILE)
    voices = os.path.join(CACHE, VOICES_FILE)
    for path, url in ((model, MODEL_URL), (voices, VOICES_URL)):
        if not os.path.exists(path):
            print("Kokoro model file missing; fetching it once (not kept in the repo):")
            download(url, path)
    return Kokoro(model, voices)


HISSES = set("fsʃθz")         # first sounds that hiss (f, s, sh, th, z)
STOPS = set("pbtdkɡ")         # and that start with a hush (p, b, t, d, k, g)


def murmur_frames(frames, db, first_sound):
    """Kokoro starts clips with a short, quiet voiced 'uh' (30-90 ms) before
    the first real sound, so 'Face' sounds like 'a face' and 'Stomp' like 'is
    stomp'. When the phrase starts with a hissing sound or a p/b/t/d/k/g, find
    where that sound really begins (the hiss, or the hush before the pop) and
    return how many 10 ms frames come before it. Other first sounds (vowels,
    m, n, l, r, w, h, the 'th' of 'the') blend with the murmur and are left
    alone, as is anything that doesn't look like a murmur."""
    import numpy as np
    if len(db) < 16 or first_sound not in HISSES | STOPS:
        return 0
    zc = (np.abs(np.diff(np.sign(frames[:16]), axis=1)) > 0).sum(axis=1)
    hiss = frames.shape[1] * 0.2   # crossings per frame of an s/f/sh hiss
    buzz = frames.shape[1] * 0.15  # a murmur crosses far less often
    # Skip the faint fade-up: start where the sound is within 12 dB of the murmur.
    base = int(np.argmax(db[:4] > db[:4].max() - 12))
    for i in range(base + 2, base + 11):
        peak = float(db[base:i].max())
        if np.median(zc[base:i]) > buzz:
            return 0  # mostly hissy or popping already: real speech
        if zc[i] > buzz and zc[i:i + 3].max() > hiss:
            return i  # the hiss of s/f/sh, or the puff after p/t/k, starts here
        if first_sound in STOPS and db[i] < peak - 7:
            return i  # the hush before b/d/g
    return 0


def trim(samples, rate, first_sound="", report=None):
    """Cuts the silence before and after the speech, keeping a little air."""
    import numpy as np
    hop = max(1, int(rate * 0.01))
    n = len(samples) // hop
    if n == 0:
        return samples
    frames = samples[: n * hop].reshape(n, hop)
    rms = np.sqrt(np.mean(frames.astype(np.float64) ** 2, axis=1)) + 1e-12
    db = 20 * np.log10(rms)
    loud = np.where(db > max(db.max() + GATE_DB, -60.0))[0]
    if len(loud) == 0:
        return samples
    skip = murmur_frames(frames[loud[0]:], db[loud[0]:], first_sound)
    if report is not None:
        report.append(skip * 10)
    first = (loud[0] + skip) * hop
    end = min(len(samples), (loud[-1] + 1) * hop + int(TAIL_PAD * rate))
    fade_in, fade_out = int(0.005 * rate), int(0.03 * rate)
    speech = samples[max(0, first - fade_in):end].astype(np.float32).copy()
    if len(speech) > fade_in + fade_out:
        speech[:fade_in] *= np.linspace(0, 1, fade_in, dtype=np.float32)
        speech[-fade_out:] *= np.linspace(1, 0, fade_out, dtype=np.float32)
    # A little quiet before the speech (silence, so a dropped murmur stays gone).
    out = np.concatenate([np.zeros(int(LEAD_PAD * rate), np.float32), speech])
    return out


def loudness(samples, rate):
    import numpy as np
    import pyloudnorm
    # Loudness needs at least 0.4 s of audio; repeat very short words so
    # they're measured as themselves (padding with silence would skew it).
    probe = samples
    while len(probe) < int(rate * 1.2):
        probe = np.concatenate([probe, samples])
    return pyloudnorm.Meter(rate).integrated_loudness(probe.astype(np.float64))


def limit(samples, rate):
    """A smooth look-ahead peak limiter: turns down only the brief moments
    that would go over PEAK_DBFS (a 'p' or 't' burst), not the whole clip."""
    import numpy as np
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    ceiling = 10 ** (PEAK_DBFS / 20)
    need = np.minimum(1.0, ceiling / (np.abs(samples) + 1e-12))
    if need.min() >= 1.0:
        return samples
    width = max(3, int(rate * 0.012)) | 1
    gain = minimum_filter1d(need, size=width)            # start early (look-ahead)
    gain = minimum_filter1d(gain, size=width * 4, origin=width * 2 - 1)  # recover slowly
    gain = uniform_filter1d(gain, size=width)            # no clicks
    out = samples * np.minimum(gain, need)
    return out.astype(np.float32)


def normalize(samples, rate):
    """Brings the clip to TARGET_LUFS, with peaks kept under PEAK_DBFS.
    Returns (samples, LUFS before, gain in dB)."""
    lufs = loudness(samples, rate)
    gain_db = TARGET_LUFS - lufs
    out = samples
    for _ in range(3):  # limiting lowers loudness a touch; make up for it
        out = limit(samples * (10 ** (gain_db / 20)), rate)
        miss = TARGET_LUFS - loudness(out, rate)
        if abs(miss) < 0.2:
            break
        gain_db += miss
    return out.astype("float32"), lufs, gain_db


def encode(samples, rate, dest):
    import soundfile
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "clip.wav")
        soundfile.write(wav, samples, rate, subtype="FLOAT")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", wav, "-ac", "1", "-ar", str(rate),
             "-c:a", "libvorbis", "-q:a", str(OGG_QUALITY), "-map_metadata", "-1",
             "-fflags", "+bitexact", "-flags:a", "+bitexact", dest],
            check=True)


def save_manifest(phrases, clips):
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"note": "Made by tools/make_voice.py; lets reruns skip unchanged clips.",
                   "clips": {p: clips[p] for p in phrases if p in clips}},
                  f, indent=1, ensure_ascii=False)
        f.write("\n")


def write_voice_gd(phrases, files):
    lines = [
        "extends RefCounted",
        "## GENERATED by tools/make_voice.py -- don't edit by hand; rerun the tool.",
        "## Recorded voice clips for every phrase in Data.spoken(): phrase -> clip.",
        "## Voice: Kokoro (hexgrad, Apache 2.0), speed %s." % SPEED,
        "",
        "const VOICE := %s" % json.dumps(VOICE),
        "",
        "const CLIPS := {",
    ]
    for p in phrases:
        lines.append("\t%s: %s," % (json.dumps(p, ensure_ascii=False),
                                     json.dumps(RES_DIR + files[p])))
    lines.append("}")
    text = "\n".join(lines) + "\n"
    old = open(VOICE_GD, encoding="utf-8").read() if os.path.exists(VOICE_GD) else None
    if old != text:
        with open(VOICE_GD, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        return True
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--all", action="store_true", help="re-record every phrase")
    ap.add_argument("--dry-run", action="store_true", help="only report what would change")
    args = ap.parse_args()
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is needed (with libvorbis) to make the OGG files.")

    t0 = time.time()
    phrases = phrases_from_godot()
    print("%d phrases from Data.spoken()." % len(phrases))

    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f).get("clips", {})
    os.makedirs(VOICE_DIR, exist_ok=True)

    want = {"voice": VOICE, "speed": SPEED, "lang": LANG, "model": MODEL_FILE,
            "process": PROCESS}
    files = {p: clip_name(p) for p in phrases}
    todo = []
    for p in phrases:
        old = manifest.get(p)
        same = old and old.get("file") == files[p] and old.get("said") == to_say(p) and all(
            old.get(k) == v for k, v in want.items())
        if args.all or not same or not os.path.exists(os.path.join(VOICE_DIR, files[p])):
            todo.append(p)

    keep = set(files.values())
    stale = sorted(f for f in os.listdir(VOICE_DIR)
                   if f.endswith(".ogg") and f not in keep)

    if args.dry_run:
        print("Would record %d: %s" % (len(todo), todo))
        print("Would delete %d: %s" % (len(stale), stale))
        return

    new_manifest = {p: manifest[p] for p in phrases if p in manifest and p not in todo}
    if todo:
        print("Recording %d phrase(s) with %s at speed %s:" % (len(todo), VOICE, SPEED))
        kokoro = load_kokoro()
        for p in todo:
            said = to_say(p)
            samples, rate = kokoro.create(said, voice=VOICE, speed=SPEED, lang=LANG, trim=False)
            samples = trim(samples, rate, first_sound(kokoro, said))
            samples, lufs, gain = normalize(samples, rate)
            dest = os.path.join(VOICE_DIR, files[p])
            encode(samples, rate, dest)
            secs = len(samples) / rate
            new_manifest[p] = dict(file=files[p], said=said, seconds=round(secs, 3), **want)
            save_manifest(phrases, new_manifest)  # so a stopped run keeps its work
            print("  + %-28s %-36s %5.2fs  %+5.1f dB" % (json.dumps(p), files[p], secs, gain))
            if secs < 0.2 or secs > 0.6 + 0.12 * len(p):
                print("    ! check this one: %.2fs seems %s for %r"
                      % (secs, "short" if secs < 0.2 else "long", p))
    else:
        print("Nothing new to record.")

    for f in stale:
        for path in (os.path.join(VOICE_DIR, f), os.path.join(VOICE_DIR, f + ".import")):
            if os.path.exists(path):
                os.remove(path)
        print("  - deleted %s (phrase no longer used)" % f)

    save_manifest(phrases, new_manifest)
    changed = write_voice_gd(phrases, files)
    print("%s scripts/voice.gd." % ("Wrote" if changed else "Unchanged:"))
    total = sum(os.path.getsize(os.path.join(VOICE_DIR, f)) for f in keep)
    print("Done in %.1fs: %d recorded, %d deleted, %d clips (%.0f KB)."
          % (time.time() - t0, len(todo), len(stale), len(keep), total / 1024))
    if todo or stale:
        print("Next, from the lite folder: godot --headless --editor --quit"
              " (imports the clips).")


if __name__ == "__main__":
    main()
