#!/usr/bin/env python3
"""Builds the game's sound effects and music from CC0 source packs.

    tools/fetch_audio_sources.sh .audio_sources
    python3 tools/build_audio.py .audio_sources

Each game sound is one or more variants (one is picked at random when it
plays). Each variant layers recorded clips, optionally with a synthesised
low thump for weight, then gets trimmed, levelled, a touch of shared stone-
room reverb (so everything sounds like it's in the same place) and a fade.

Writes:
    assets/audio/sfx/<name>_<n>.wav
    assets/audio/music/*.ogg           (crossfaded so they loop seamlessly)
    scripts/sound_bank.gd              (the list of sounds for audio.gd)

Needs: python3, numpy, ffmpeg.
"""
import os
import subprocess
import sys

import numpy as np

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT_MUSIC = os.path.join(ROOT, "assets", "audio", "music")
BANK = os.path.join(ROOT, "scripts", "sound_bank.gd")

# Shortcuts into the source packs.
K = "kenney_rpg/OGG/"
A = "artisticdude_rpg/RPG Sound Pack/"
R = "rubberduck_rpg/"
S = "rubberduck_sfx/"
W = "artisticdude_swishes/swishes/"
P = "independent_hits/hit.mp3"  # 37 punches in one file; P#n picks punch n

# A layer is (source, gain dB, delay ms, pitch). Sources starting with
# "synth:" are generated here instead of loaded.
# A sound is {"variants": [[layers...], ...], "level": dB, "verb": wet dB}.
def v(*layers):
    return [tuple(list(l) + [0, 0, 1.0][len(l) - 1:]) if isinstance(l, tuple) else (l, 0, 0, 1.0) for l in layers]


SOUNDS = {
    # --- the climber's weapons -------------------------------------------
    "swing": {"variants": [v(A + "battle/swing.wav"), v(A + "battle/swing2.wav"), v(A + "battle/swing3.wav")], "level": -3},
    "swing_heavy": {"variants": [v((A + "battle/swing.wav", 0, 0, 0.82), (W + "swish-7.wav", -6, 10, 0.75))], "level": -1},
    "punch": {"variants": [v((W + "swish-12.wav", 0, 0, 1.25)), v((W + "swish-13.wav", 0, 0, 1.2)), v((W + "swish-11.wav", 0, 0, 1.3))], "level": -6},
    "punch_heavy": {"variants": [v((W + "swish-3.wav", 0, 0, 0.95))], "level": -3},
    # Sword on flesh: a chop, a punch body and a low thump.
    "hit": {"variants": [
        v((K + "chop.ogg", 0, 0, 1.0), (P + "#20", -6, 0, 0.9), ("synth:thump", -8, 0, 1.0)),
        v((K + "chop.ogg", 0, 0, 0.9), (P + "#33", -6, 0, 0.9), ("synth:thump", -8, 0, 1.0)),
        v((S + "hit_03.ogg", -2, 0, 1.0), (K + "chop.ogg", -4, 0, 1.1), ("synth:thump", -8, 0, 1.0)),
    ], "level": -2},
    "hit_heavy": {"variants": [
        v((S + "slam_03.ogg", 0, 0, 0.85), (K + "chop.ogg", -3, 0, 0.8), (P + "#18", -4, 0, 0.8), ("synth:thump", -3, 0, 0.8)),
        v((S + "slam_02.ogg", -1, 0, 0.85), (P + "#34", -3, 0, 0.8), ("synth:thump", -3, 0, 0.8)),
    ], "level": 0},
    # Fists and arrows: lighter, punchier.
    "hit_light": {"variants": [v((P + "#%d" % n, 0, 0, 1.0), ("synth:thump", -12, 0, 1.3)) for n in (0, 2, 5, 6, 7, 11, 16)], "level": -4},
    "crit": {"variants": [v((S + "slam_02.ogg", 0, 0, 0.8), (S + "metal_07.ogg", -8, 0, 0.9), (P + "#18", -2, 0, 0.75), ("synth:thump", 0, 0, 0.7))], "level": 0, "verb": -11},
    "parry": {"variants": [
        v((S + "metal_09.ogg", 0, 0, 1.0), (A + "inventory/metal-ringing.wav", -8, 15, 1.0)),
        v((S + "metal_09.ogg", 0, 0, 1.08), (A + "inventory/metal-ringing.wav", -8, 15, 1.1)),
    ], "level": -2, "verb": -10},
    "arrow_hit": {"variants": [v((S + "wooden_01.ogg", 0, 0, 1.2), (P + "#9", -4, 0, 1.0)), v((S + "wooden_02.ogg", 0, 0, 1.1), (P + "#12", -4, 0, 1.0))], "level": -4},
    "draw": {"variants": [v((K + "creak2.ogg", 0, 0, 1.05))], "level": -8},
    # A sharp string slap and the arrow's whoosh (no synthesised twang).
    "bow": {"variants": [
        v((W + "swish-13.wav", 0, 0, 1.5), (S + "wooden_02.ogg", -7, 0, 1.7), (P + "#9", -10, 0, 1.4)),
        v((W + "swish-10.wav", 0, 0, 1.55), (S + "wooden_02.ogg", -7, 0, 1.8), (P + "#12", -10, 0, 1.4)),
    ], "level": -6, "verb": -20},
    "ready": {"variants": [v((K + "metalClick.ogg", 0, 0, 1.3))], "level": -10},
    "equip_sword": {"variants": [v((A + "battle/sword-unsheathe2.wav", 0, 0, 1.0))], "level": -8},
    "equip_fists": {"variants": [v((K + "handleSmallLeather.ogg", 0, 0, 1.0))], "level": -6},
    "equip_bow": {"variants": [v((K + "creak3.ogg", 0, 0, 1.0))], "level": -8},
    # --- the climber's body ------------------------------------------------
    "roll": {"variants": [v((A + "inventory/cloth-heavy.wav", 0, 0, 1.1), (K + "footstep01.ogg", -8, 120, 0.9)), v((A + "inventory/cloth.wav", 0, 0, 1.15), (K + "footstep03.ogg", -8, 120, 0.9))], "level": -6},
    "dodge": {"variants": [v((W + "swish-10.wav", 0, 0, 1.35), (K + "cloth4.ogg", -6, 0, 1.2))], "level": -7},
    "hurt": {"variants": [
        v((P + "#21", 0, 0, 0.8), (A + "inventory/cloth-heavy.wav", -6, 0, 0.9), ("synth:thump", -4, 0, 0.8)),
        v((P + "#32", 0, 0, 0.8), (A + "inventory/cloth-heavy.wav", -6, 0, 0.9), ("synth:thump", -4, 0, 0.8)),
    ], "level": -1},
    "death": {"variants": [v((S + "slam_03.ogg", 0, 0, 0.7), (S + "metal_04.ogg", -10, 80, 0.7), ("synth:thump", 0, 0, 0.55))], "level": -1, "verb": -8},
    "winded": {"variants": [v((K + "dropLeather.ogg", 0, 0, 0.8))], "level": -10},
    "step": {"variants": [v((K + "footstep0%d.ogg" % n, 0, 0, 1.0)) for n in range(10)], "level": -14, "verb": -30},
    # --- bonds -------------------------------------------------------------
    "charge": {"variants": [v((R + "spell_01.ogg", 0, 0, 0.9))], "level": -9},
    "zap": {"variants": [v((R + "spell_02.ogg", 0, 0, 1.2), (A + "battle/magic1.wav", -6, 0, 1.4)), v((R + "spell_02.ogg", 0, 0, 1.35), (A + "battle/magic1.wav", -6, 0, 1.5))], "level": -4},
    "gust": {"variants": [v(("synth:wind", 0, 0, 1.0), (W + "swish-7.wav", -4, 0, 0.6))], "level": -4},
    "burn": {"variants": [v((R + "spell_fire_06.ogg", 0, 0, 0.9), (S + "slam_04.ogg", -8, 0, 0.7))], "level": -3},
    # --- monsters ----------------------------------------------------------
    # The glint before a monster's blow: a bright, short metallic ting.
    "glint": {"variants": [v((S + "metal_11.ogg", 0, 0, 1.25), (A + "inventory/metal-ringing.wav", -14, 0, 1.6))], "level": -7, "verb": -14},
    "warn_knight": {"variants": [v((A + "inventory/chainmail1.wav", 0, 0, 0.9), (A + "battle/sword-unsheathe2.wav", -6, 120, 0.85))], "level": -5},
    "warn_archer": {"variants": [v((K + "creak3.ogg", 0, 0, 1.15)), v((K + "creak1.ogg", 0, 0, 1.3))], "level": -6},
    "slime_hop": {"variants": [v((R + "creature_slime_0%d.ogg" % n, 0, 0, 1.1)) for n in (1, 2, 3)], "level": -14},
    "hit_slime": {"variants": [v((R + "creature_slime_03.ogg", 0, 0, 1.2), (S + "plop_01.ogg", -6, 0, 0.9)), v((R + "creature_slime_04.ogg", 0, 0, 1.2), (S + "plop_02.ogg", -6, 0, 0.9))], "level": -8},
    "hit_armor": {"variants": [v((S + "metal_03.ogg", 0, 0, 1.0)), v((S + "metal_01.ogg", 0, 0, 1.1)), v((S + "metal_06.ogg", 0, 0, 0.9))], "level": -7},
    "kill": {"variants": [v((S + "slam_01.ogg", 0, 0, 0.8), ("synth:thump", -4, 0, 0.7))], "level": -3},
    "kill_slime": {"variants": [v((S + "splash_01.ogg", 0, 0, 1.1), (R + "creature_slime_02.ogg", -3, 0, 0.9))], "level": -3},
    "kill_knight": {"variants": [v((A + "inventory/armor-light.wav", 0, 0, 0.8), (S + "slam_03.ogg", -2, 60, 0.75), (S + "metal_05.ogg", -8, 60, 0.8))], "level": -2, "verb": -10},
    "kill_archer": {"variants": [v((R + "creature_hurt_01.ogg", 0, 0, 1.1), (A + "inventory/cloth-heavy.wav", -4, 80, 0.9))], "level": -4},
    # --- the room ----------------------------------------------------------
    "clear": {"variants": [v((S + "gong_02.ogg", 0, 0, 1.0))], "level": -6, "verb": -8},
}

MUSIC = {
    # name: (source, crossfade seconds)
    "music": ("music/evil_temple.ogg", 4.0),
    "ambience": ("music/dark_cavern_ambient_001.ogg", 6.0),
}


# --- loading -------------------------------------------------------------

def decode(path, sr=SR, channels=1):
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", str(channels), "-ar", str(sr), "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    x = np.frombuffer(out, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, channels) if channels > 1 else x


_punches = None


def punches(src_root):
    """Splits the 37-punch recording into single punches."""
    global _punches
    if _punches is None:
        x = decode(os.path.join(src_root, P))
        win = int(0.01 * SR)
        env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, "same"))
        loud = env > env.max() * 0.08
        segs, start, quiet = [], None, 0
        for i in range(0, len(x), win):
            if loud[i]:
                start = i if start is None else start
                quiet = 0
            elif start is not None:
                quiet += win
                if quiet > 0.15 * SR:
                    segs.append(x[max(0, start - win):i - quiet + 4 * win])
                    start = None
        _punches = segs
    return _punches


def synth(kind):
    t = np.arange(int(0.6 * SR)) / SR
    if kind == "thump":  # a low body thud that gives hits weight
        f = 45 + 70 * np.exp(-t * 18)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
    if kind == "pluck":  # Karplus-Strong string: the bow's twang
        period = int(SR / 140)
        buf = np.random.uniform(-1, 1, period)
        out = np.zeros(int(0.45 * SR))
        for i in range(len(out)):
            j = i % period
            out[i] = buf[j]
            buf[j] = 0.5 * (buf[j] + buf[(j + 1) % period]) * 0.993
        return out
    if kind == "wind":  # a gust: noise swept through a resonant band
        n = int(0.55 * SR)
        noise = np.random.uniform(-1, 1, n)
        out, y1, y2 = np.zeros(n), 0.0, 0.0
        for i in range(n):
            k = i / n
            fc = 250 + 1500 * np.sin(np.pi * k)
            w = 2 * np.pi * fc / SR
            r = 0.97
            y = noise[i] * (1 - r) + 2 * r * np.cos(w) * y1 - r * r * y2
            y2, y1 = y1, y
            out[i] = y * np.sin(np.pi * k) ** 1.5
        return out / (np.abs(out).max() + 1e-9)
    raise ValueError(kind)


def load_layer(src_root, src, pitch):
    if src.startswith("synth:"):
        x = synth(src[6:])
    elif "#" in src:
        x = punches(src_root)[int(src.split("#")[1])]
    else:
        x = decode(os.path.join(src_root, src))
    if pitch != 1.0:  # resample: higher pitch is also shorter, like tape
        idx = np.arange(0, len(x) - 1, pitch)
        x = np.interp(idx, np.arange(len(x)), x)
    return trim_start(x)


def trim_start(x, thresh=0.02):
    peak = np.abs(x).max()
    if peak <= 0:
        return x
    on = np.argmax(np.abs(x) > peak * thresh)
    return x[max(0, on - int(0.002 * SR)):]


def trim_end(x, thresh=0.003):
    loud = np.where(np.abs(x) > np.abs(x).max() * thresh)[0]
    return x[:loud[-1] + 1] if len(loud) else x


# --- processing ------------------------------------------------------------

def room_ir():
    """A small stone room: a few early echoes, then a short dark tail."""
    rng = np.random.default_rng(7)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    tail = rng.uniform(-1, 1, n) * np.exp(-t * 6.5)
    # darken the tail (one-pole lowpass, run twice)
    for _ in range(2):
        y = 0.0
        a = 1 - np.exp(-2 * np.pi * 2500 / SR)
        for i in range(n):
            y += a * (tail[i] - y)
            tail[i] = y
    ir = tail * 0.5
    for ms, g in ((11, 0.5), (19, 0.35), (29, 0.3), (41, 0.22)):
        ir[int(ms / 1000 * SR)] += g
    return ir / np.sqrt(np.sum(ir ** 2))


IR = None


def reverb(x, wet_db):
    global IR
    if IR is None:
        IR = room_ir()
    n = len(x) + len(IR)
    size = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(IR, size), size)[:n]
    out = np.zeros(n)
    out[:len(x)] = x
    return out + wet * 10 ** (wet_db / 20)


def loudness(x):
    """RMS over the loud part, in dB."""
    loud = np.abs(x) > np.abs(x).max() * 0.1
    return 20 * np.log10(np.sqrt(np.mean(x[loud] ** 2)) + 1e-12)


def build_variant(src_root, layers, level, verb):
    parts = []
    for src, gain, delay, pitch in layers:
        x = load_layer(src_root, src, pitch)
        x = x / (np.abs(x).max() + 1e-12) * 10 ** (gain / 20)
        parts.append(np.concatenate([np.zeros(int(delay / 1000 * SR)), x]))
    mix = np.zeros(max(len(p) for p in parts))
    for p in parts:
        mix[:len(p)] += p
    # Gentle high-pass: removes rumble that only muddies the mix.
    mix = mix - np.convolve(mix, np.ones(64) / 64, "same")
    # Level everything to the same loudness, then apply this sound's level.
    mix *= 10 ** ((-18 + level - loudness(mix)) / 20)
    mix = reverb(mix, verb)
    mix = trim_end(mix)
    fin, fout = int(0.002 * SR), min(int(0.04 * SR), len(mix) // 3)
    mix[:fin] *= np.linspace(0, 1, fin)
    mix[-fout:] *= np.linspace(1, 0, fout)
    # Soft limiter: round off any peak instead of clipping.
    return np.tanh(mix * 1.1) / 1.1


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32000).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", path],
                   input=pcm, check=True)


def build_music(src_root, name, src, fade):
    """Crossfades the end into the start so the track loops without a seam."""
    sr = 44100
    x = decode(os.path.join(src_root, src), sr, 2)
    n = int(fade * sr)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)[:, None]
    looped = np.concatenate([body, tail * (1 - ramp) + head * ramp])
    looped *= 10 ** ((-19 - 20 * np.log10(np.sqrt(np.mean(looped ** 2)) + 1e-12)) / 20)
    looped = np.tanh(looped * 1.05) / 1.05
    pcm = (np.clip(looped, -1, 1) * 32000).astype("<i2").tobytes()
    path = os.path.join(OUT_MUSIC, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(sr), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", path], input=pcm, check=True)
    return "res://assets/audio/music/%s.ogg" % name


def main():
    src_root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".audio_sources")
    np.random.seed(11)
    os.makedirs(OUT_SFX, exist_ok=True)
    os.makedirs(OUT_MUSIC, exist_ok=True)
    for f in os.listdir(OUT_SFX):
        if f.endswith(".wav"):
            os.remove(os.path.join(OUT_SFX, f))
    bank = {}
    for name, spec in SOUNDS.items():
        paths = []
        for i, layers in enumerate(spec["variants"]):
            x = build_variant(src_root, layers, spec.get("level", -6), spec.get("verb", -16))
            fname = "%s_%d.wav" % (name, i)
            write_wav(os.path.join(OUT_SFX, fname), x)
            paths.append("res://assets/audio/sfx/" + fname)
        bank[name] = paths
        print("built", name, len(paths))
    music = {name: build_music(src_root, name, src, fade) for name, (src, fade) in MUSIC.items()}
    for name in music:
        print("built", name)

    with open(BANK, "w") as f:
        f.write("extends RefCounted\n## Generated by tools/build_audio.py. Do not edit by hand.\n\n")
        f.write("const SFX := {\n")
        for name, paths in bank.items():
            f.write('\t"%s": [%s],\n' % (name, ", ".join('"%s"' % p for p in paths)))
        f.write("}\n\nconst MUSIC := {\n")
        for name, path in music.items():
            f.write('\t"%s": "%s",\n' % (name, path))
        f.write("}\n")


if __name__ == "__main__":
    main()
