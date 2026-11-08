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

Needs: python3, numpy, ffmpeg (and 7z or py7zr for fetching the sources).
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
KI = "kenney_interface/Audio/"
A = "artisticdude_rpg/RPG Sound Pack/"
R = "rubberduck_rpg/"
S = "rubberduck_sfx/"
W = "artisticdude_swishes/swishes/"
SN = "starninjas_impact/"
T = "tinysized/sfx-cc0/"
M = "medieval_textures/"  # long recordings of many takes: "file@start+length" picks one
P = "independent_hits/hit.mp3"  # 37 punches in one file; P#n picks punch n

# A layer is (source, gain dB, delay ms, pitch). Sources starting with
# "synth:" are generated here instead of loaded; "file@1.25+0.3" takes the
# 0.3 s starting 1.25 s into the file (one take of a long recording).
# A sound is {"variants": [[layers...], ...], "level": dB, "verb": wet dB,
# "lp": low-pass Hz, "hp": high-pass Hz, "vtrim": [dB per variant]} (the
# filters and trims are optional; a trim evens out variants that measure
# alike but don't sound alike).
#
# Levels by kind, so nothing jumps out of the mix: footsteps and menus
# quiet (-12 to -18), swings and draws soft (-3 to -10), hits in the middle
# (-2 to -4), and only parries, crits, slams and deaths at full (0 to -2).
def v(*layers):
    return [tuple(list(l) + [0, 0, 1.0][len(l) - 1:]) if isinstance(l, tuple) else (l, 0, 0, 1.0) for l in layers]


# Bow and crossbow takes (Still North Media's medieval weapon recordings).
LB_DRAW = M + "English Longbow Draw.wav@"
LB_SHOOT = M + "English Longbow Shoot.wav@"
SR_SHOOT = M + "Scythian Recurve Shoot.wav@"
ARROW_PASS = M + "Scythian Recurve Arrow Pass.wav@"
NOCK = M + "Scythian Recurve Nock Arrow.wav@"
XB_SHOOT = M + "Crossbow Shoot.wav@"
XB_NUT = M + "Crossbow Set Nut Against Sear.wav@"
XB_BOLT = M + "Crossbow Place Bolt.wav@"
XB_LEVER = M + "Crossbow Lever Trigger.wav@"


def bow_release(snap):
    """Loosing an arrow: the string's snap, the arrow's short whoosh and a
    little body thump from the limbs."""
    return v((snap, 0, 0, 1.0), (ARROW_PASS + "1.08+0.40", -9, 8, 1.0), ("synth:thump", -14, 0, 1.8))


SOUNDS = {
    # --- the climber's weapons -------------------------------------------
    "swing": {"variants": [v(A + "battle/swing.wav"), v(A + "battle/swing2.wav"), v(A + "battle/swing3.wav")], "level": -3},
    "swing_heavy": {"variants": [v((A + "battle/swing.wav", 0, 0, 0.82), (W + "swish-7.wav", -6, 10, 0.75))], "level": -1},
    # Dagger: a quick, light swish (a real dagger cutting the air).
    "swing_light": {"variants": [
        v((M + "Dagger Swing.wav@0.95+0.25", 0, 0, 1.0), (W + "swish-12.wav", -8, 0, 1.35)),
        v((M + "Dagger Swing.wav@2.13+0.25", 0, 0, 1.0), (W + "swish-13.wav", -8, 0, 1.3)),
    ], "level": -5, "hp": 300},
    "swing_light_heavy": {"variants": [v((M + "Dagger Swing.wav@0.95+0.25", 0, 0, 0.9), (W + "swish-11.wav", -4, 0, 1.0))], "level": -3, "hp": 250},
    # Spear: a narrow thrust.
    "thrust": {"variants": [
        v((M + "Spear Swing.wav@3.13+0.28", 0, 0, 1.0), (W + "swish-13.wav", -10, 0, 1.0)),
        v((M + "Spear Swing.wav@4.05+0.28", 0, 0, 1.0), (W + "swish-12.wav", -10, 0, 1.0)),
        v((M + "Spear Swing.wav@1.48+0.28", 0, 0, 1.0), (W + "swish-13.wav", -10, 0, 0.95)),
    ], "level": -8, "hp": 200},
    "thrust_heavy": {"variants": [v((M + "Spear Swing.wav@3.13+0.28", 0, 0, 0.9), (W + "swish-7.wav", -4, 0, 0.9))], "level": -5, "hp": 180},
    # Mace and war hammer: a dull, heavy whoosh.
    "swing_blunt": {"variants": [
        v((A + "battle/swing.wav", 0, 0, 0.78), (W + "swish-7.wav", -5, 0, 0.7)),
        v((A + "battle/swing2.wav", 0, 0, 0.75), (W + "swish-4.wav", -5, 0, 0.7)),
    ], "level": -2, "lp": 2500},
    "swing_blunt_heavy": {"variants": [v((A + "battle/swing.wav", 0, 0, 0.68), (W + "swish-3.wav", -4, 10, 0.65))], "level": -1, "lp": 2200},
    "punch": {"variants": [v((W + "swish-12.wav", 0, 0, 1.25)), v((W + "swish-13.wav", 0, 0, 1.2)), v((W + "swish-11.wav", 0, 0, 1.3))], "level": -6, "lp": 4000},
    "punch_heavy": {"variants": [v((W + "swish-3.wav", 0, 0, 0.95))], "level": -3, "lp": 3500},
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
    # Fists: lighter, punchier.
    "hit_light": {"variants": [v((P + "#%d" % n, 0, 0, 1.0), ("synth:thump", -12, 0, 1.3)) for n in (0, 2, 5, 6, 7, 11, 16)], "level": -4},
    # Dagger: a slice with a little body.
    "hit_stab": {"variants": [
        v((K + "knifeSlice2.ogg", -2, 0, 1.0), (P + "#5", 0, 0, 1.05), ("synth:thump", -12, 0, 1.3)),
        v((K + "knifeSlice.ogg", -2, 0, 1.05), (P + "#7", 0, 0, 1.05), ("synth:thump", -12, 0, 1.3)),
        v((K + "knifeSlice2.ogg", -3, 0, 0.92), (P + "#11", 0, 0, 1.0), ("synth:thump", -12, 0, 1.3)),
    ], "level": -5.5, "lp": 6500},
    # Mace and war hammer: a blunt, bone-deep thud with no blade in it.
    "hit_blunt": {"variants": [
        v((SN + "impact.8.ogg", 0, 0, 1.0), (P + "#18", -4, 0, 0.85), ("synth:thump", -5, 0, 0.9)),
        v((SN + "impact.6.ogg", 0, 0, 1.0), (P + "#34", -4, 0, 0.85), ("synth:thump", -5, 0, 0.9)),
        v((SN + "impact.1.ogg", 0, 0, 1.0), (P + "#20", -4, 0, 0.85), ("synth:thump", -5, 0, 0.9)),
    ], "level": -3, "lp": 5000},
    "crit": {"variants": [v((S + "slam_02.ogg", 0, 0, 0.8), (S + "metal_07.ogg", -8, 0, 0.9), (P + "#18", -2, 0, 0.75), ("synth:thump", 0, 0, 0.7))], "level": 0, "verb": -11},
    "parry": {"variants": [
        v((S + "metal_09.ogg", 0, 0, 1.0), (A + "inventory/metal-ringing.wav", -8, 15, 1.0)),
        v((S + "metal_09.ogg", 0, 0, 1.08), (A + "inventory/metal-ringing.wav", -8, 15, 1.1)),
    ], "level": -2, "verb": -10},
    # An arrow or bolt striking: a dry wooden thunk with weight under it.
    "arrow_hit": {"variants": [
        v((R + "wood_03.ogg", 0, 0, 1.0), (K + "chop.ogg", -4, 0, 0.85), (P + "#9", -8, 0, 0.9), ("synth:thump", -8, 0, 1.6)),
        v((R + "wood_05.ogg", 0, 0, 0.9), (K + "chop.ogg", -4, 0, 0.8), (P + "#12", -8, 0, 0.9), ("synth:thump", -8, 0, 1.6)),
        v((R + "item_wood_02.ogg", 0, 0, 0.9), (K + "chop.ogg", -3, 0, 0.9), ("synth:thump", -8, 0, 1.5)),
    ], "level": -3, "lp": 6000, "verb": -18},
    # Drawing a bow: the stave's creak as the string comes back.
    "draw": {"variants": [v(LB_DRAW + "9.40+0.85"), v(LB_DRAW + "11.70+0.80"), v(LB_DRAW + "20.25+0.85")], "level": -11, "vtrim": [-2, 0, 0], "lp": 7000, "hp": 200, "verb": -20},
    # Full draw: the nock settling, a small click.
    "bow_full": {"variants": [v(NOCK + "0.41+0.12"), v(NOCK + "3.69+0.12")], "level": -9, "vtrim": [0, 4], "lp": 7000, "verb": -18},
    # Loosing an arrow: string snap, whoosh, a little thump.
    "bow": {"variants": [
        bow_release(LB_SHOOT + "1.25+0.30"),
        bow_release(LB_SHOOT + "0.10+0.30"),
        bow_release(LB_SHOOT + "3.19+0.30"),
        bow_release(SR_SHOOT + "3.39+0.30"),
    ], "level": 2, "vtrim": [0.5, -0.5, 1.5, 1.0], "lp": 9000, "verb": -18},
    # The crossbow: a hard clack, the bolt's whoosh and a solid kick.
    "crossbow": {"variants": [
        v((XB_SHOOT + "0.32+0.30", 0, 0, 1.0), (ARROW_PASS + "1.08+0.40", -12, 10, 0.9), ("synth:thump", -6, 0, 1.2)),
        v((XB_SHOOT + "1.92+0.30", 0, 0, 1.0), (ARROW_PASS + "2.15+0.40", -12, 10, 0.9), ("synth:thump", -6, 0, 1.2)),
        v((XB_SHOOT + "0.83+0.30", 0, 0, 1.0), (ARROW_PASS + "1.08+0.40", -12, 10, 0.9), ("synth:thump", -6, 0, 1.2)),
    ], "level": 2, "vtrim": [1.5, 0, 0], "lp": 9000, "verb": -16},
    # Reloading: the windlass ratchet, then the bolt dropping into place.
    "crossbow_reload": {"variants": [v(
        (XB_NUT + "1.90+0.25", 0, 0, 1.0), (XB_NUT + "0.90+0.20", -2, 150, 1.0),
        (XB_NUT + "3.10+0.25", 0, 300, 1.0), (XB_NUT + "1.90+0.25", -2, 450, 0.95))], "level": -9, "lp": 7000},
    "crossbow_load": {"variants": [v((XB_BOLT + "0.38+0.35", 0, 0, 1.0), (XB_LEVER + "2.34+0.25", -8, 0, 1.0))], "level": -7, "lp": 7000},
    "ready": {"variants": [v((K + "metalClick.ogg", 0, 0, 1.3))], "level": -10, "lp": 7000},
    # Switching weapons: each kind sounds like what it is.
    "equip_sword": {"variants": [v(M + "Katana Draw Fast.wav@0.30+0.40")], "level": -4, "lp": 7000},
    "equip_dagger": {"variants": [v((T + "seax-unsheathe-02.wav", 0, 0, 1.15))], "level": -10, "lp": 7000},
    "equip_heavy": {"variants": [v((M + "Katana Draw Fast.wav@0.30+0.40", 0, 0, 0.8), (K + "dropLeather.ogg", -6, 60, 0.9))], "level": -8, "lp": 6000},
    "equip_blunt": {"variants": [v((K + "handleSmallLeather.ogg", 0, 0, 0.9), (SN + "impact.8.ogg", -6, 40, 1.2))], "level": -9, "lp": 5000},
    "equip_fists": {"variants": [v((K + "handleSmallLeather.ogg", 0, 0, 1.0))], "level": -6},
    "equip_bow": {"variants": [v((M + "English Longbow Nock Arrow.wav@0.74+0.30", 0, 0, 1.0), (K + "creak3.ogg", -10, 0, 1.0))], "level": -9, "lp": 7000},
    "equip_crossbow": {"variants": [v((XB_BOLT + "2.38+0.35", 0, 0, 1.0), (XB_NUT + "1.90+0.20", -4, 120, 1.0))], "level": -5, "lp": 7000},
    # Putting on armor, picking things up, keeping an heirloom.
    "armor_on": {"variants": [v((A + "inventory/armor-light.wav", 0, 0, 0.95), (A + "inventory/chainmail1.wav", -4, 80, 1.0))], "level": -7, "lp": 7000},
    "pickup": {"variants": [v((T + "cloth-pouch-shake-02.wav", 0, 0, 1.0)), v((T + "cloth-pouch-shake-01.wav", 0, 0, 1.05))], "level": -9, "vtrim": [0, 4], "lp": 7000},
    "heirloom": {"variants": [v((M + "Katana Draw Fast.wav@0.30+0.40", 0, 0, 0.9), (S + "gong_01.ogg", -6, 60, 1.5))], "level": -5, "verb": -8, "lp": 8000},
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
    # Armor jingling on each step (played with "step" in chain mail or plate).
    "step_chain": {"variants": [
        v(A + "inventory/chainmail1.wav@0.03+0.20"), v(A + "inventory/chainmail2.wav@0.02+0.20"),
        v((A + "inventory/chainmail1.wav@0.20+0.20", 0, 0, 1.1)),
    ], "level": -20, "vtrim": [0, 0, 4], "lp": 7000, "verb": -30},
    "step_plate": {"variants": [
        v((A + "inventory/armor-light.wav@0.0+0.22", 0, 0, 0.9), (A + "inventory/chainmail2.wav@0.02+0.2", -6, 0, 0.9)),
        v((A + "inventory/armor-light.wav@0.08+0.22", 0, 0, 0.85)),
    ], "level": -19, "lp": 6000, "verb": -30},
    # --- bonds -------------------------------------------------------------
    "charge": {"variants": [v((R + "spell_01.ogg", 0, 0, 0.9))], "level": -9},
    "zap": {"variants": [v((R + "spell_02.ogg", 0, 0, 1.2), (A + "battle/magic1.wav", -6, 0, 1.4)), v((R + "spell_02.ogg", 0, 0, 1.35), (A + "battle/magic1.wav", -6, 0, 1.5))], "level": -5, "lp": 9000},
    "gust": {"variants": [v(("synth:wind", 0, 0, 1.0), (W + "swish-7.wav", -4, 0, 0.6))], "level": -6},
    "burn": {"variants": [v((R + "spell_fire_06.ogg", 0, 0, 0.9), (S + "slam_04.ogg", -8, 0, 0.7))], "level": -4, "lp": 8000},
    # Gas escaping a vent: a compressed-air spray slowed and darkened into
    # a soft hiss (raw, it's a piercing whistle).
    "hiss": {"variants": [
        v((T + "compressed-air-spray-02.wav@0.05+0.9", 0, 0, 0.6)),
        v((T + "compressed-air-spray-02.wav@0.9+0.9", 0, 0, 0.55)),
    ], "level": -13, "lp": 3500, "hp": 300},
    # --- monsters ----------------------------------------------------------
    # The glint before a monster's blow: a bright, short metallic ting.
    "glint": {"variants": [v((S + "metal_11.ogg", 0, 0, 1.25), (A + "inventory/metal-ringing.wav", -14, 0, 1.6))], "level": -7, "verb": -14, "lp": 7000},
    "warn_knight": {"variants": [v((A + "inventory/chainmail1.wav", 0, 0, 0.9), (A + "battle/sword-unsheathe2.wav", -6, 120, 0.85))], "level": -5, "lp": 8000},
    # An archer drawing: the same bow creak as yours, shorter.
    # Enemy archers drawing: the real bow stave only, a little low and soft
    # (the old creak layer and the sped-up draw read as a squeaky spring).
    "warn_archer": {"variants": [
        v((LB_DRAW + "11.70+0.55", 0, 0, 0.9)),
        v((LB_DRAW + "14.10+0.60", 0, 0, 0.88)),
    ], "level": -8, "lp": 3800, "hp": 120},
    "slime_hop": {"variants": [v((R + "creature_slime_0%d.ogg" % n, 0, 0, 1.1)) for n in (1, 2, 3)], "level": -14, "lp": 6000},
    "hit_slime": {"variants": [v((R + "creature_slime_03.ogg", 0, 0, 1.2), (S + "plop_01.ogg", -6, 0, 0.9)), v((R + "creature_slime_04.ogg", 0, 0, 1.2), (S + "plop_02.ogg", -6, 0, 0.9))], "level": -8, "lp": 5000},
    "hit_armor": {"variants": [v((S + "metal_03.ogg", 0, 0, 1.0)), v((S + "metal_01.ogg", 0, 0, 1.1)), v((S + "metal_06.ogg", 0, 0, 0.9))], "level": -7, "lp": 8000},
    # A beast's blow landing on the floor: deep, with rubble (built low, so
    # it isn't slowed to mud at the call).
    "slam": {"variants": [
        v((S + "slam_03.ogg", 0, 0, 0.6), (S + "slam_02.ogg", -4, 30, 0.55), ("synth:thump", 0, 0, 0.5), (R + "stones_01.ogg", -9, 40, 0.8)),
        v((S + "slam_02.ogg", 0, 0, 0.58), (S + "slam_03.ogg", -4, 30, 0.6), ("synth:thump", 0, 0, 0.5), (R + "stones_02.ogg", -9, 40, 0.8)),
    ], "level": -1, "verb": -9, "lp": 4000},
    "kill": {"variants": [
        v((S + "slam_01.ogg", 0, 0, 0.8), ("synth:thump", -4, 0, 0.7)),
        v((S + "slam_01.ogg", 0, 0, 0.75), (R + "creature_hurt_02.ogg", -9, 20, 0.8), ("synth:thump", -4, 0, 0.7)),
        v((S + "slam_05.ogg", 0, 0, 0.8), (R + "creature_hurt_01.ogg", -10, 20, 0.85), ("synth:thump", -4, 0, 0.7)),
    ], "level": -3, "lp": 7000},
    "kill_slime": {"variants": [v((S + "splash_01.ogg", 0, 0, 1.1), (R + "creature_slime_02.ogg", -3, 0, 0.9))], "level": -3, "lp": 7000},
    "kill_knight": {"variants": [v((A + "inventory/armor-light.wav", 0, 0, 0.8), (S + "slam_03.ogg", -2, 60, 0.75), (S + "metal_05.ogg", -8, 60, 0.8))], "level": -3, "verb": -10},
    "kill_archer": {"variants": [v((R + "creature_hurt_01.ogg", 0, 0, 1.1), (A + "inventory/cloth-heavy.wav", -4, 80, 0.9))], "level": -4},
    # --- traps -------------------------------------------------------------
    "trap_click": {"variants": [v((XB_LEVER + "2.34+0.25", 0, 0, 0.85), (K + "metalClick.ogg", -10, 0, 0.8))], "level": -5, "lp": 6000},
    "trap_spikes": {"variants": [v((S + "metal_03.ogg", 0, 0, 0.9), (T + "metal-knife-scrape-01.wav@0.07+0.25", -8, 0, 1.0), (S + "slam_04.ogg", -8, 0, 0.8))], "level": -5, "lp": 7000},
    # --- the room ----------------------------------------------------------
    "clear": {"variants": [v((S + "gong_02.ogg", 0, 0, 1.0))], "level": -6, "verb": -8},
    # --- menus (dry and soft, like the pages of a journal) -----------------
    "ui_move": {"variants": [v(KI + "click_001.ogg")], "level": -9, "lp": 6000, "verb": -60},
    "ui_confirm": {"variants": [v((K + "bookFlip2.ogg", 0, 0, 1.0), (KI + "select_002.ogg", -8, 0, 1.0))], "level": -10, "lp": 7000, "verb": -60},
    "ui_back": {"variants": [v((K + "bookFlip1.ogg", 0, 0, 0.9), (KI + "back_002.ogg", -8, 0, 1.0))], "level": -8, "lp": 7000, "verb": -60},
    "ui_open": {"variants": [v(K + "bookOpen.ogg")], "level": -16, "lp": 7000, "verb": -60},
    "ui_close": {"variants": [v(K + "bookClose.ogg")], "level": -10.5, "lp": 7000, "verb": -60},
    "ui_bag": {"variants": [v((T + "cloth-pouch-shake-02.wav", 0, 0, 1.0), (K + "handleSmallLeather.ogg", -4, 0, 1.0))], "level": -15, "lp": 7000, "verb": -60},
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


_decoded = {}


def decode_cached(path):
    if path not in _decoded:
        _decoded[path] = decode(path)
    return _decoded[path]


def load_layer(src_root, src, pitch):
    if src.startswith("synth:"):
        x = synth(src[6:])
    elif "#" in src:
        x = punches(src_root)[int(src.split("#")[1])]
    elif "@" in src:  # one take of a long recording: file@start+length (seconds)
        path, span = src.rsplit("@", 1)
        start, length = (float(t) for t in span.split("+"))
        x = decode_cached(os.path.join(src_root, path))[int(start * SR):int((start + length) * SR)].copy()
        n = min(len(x) // 4, int(0.015 * SR))
        x[len(x) - n:] *= np.linspace(1, 0, n)  # cut the take off softly
    else:
        x = decode_cached(os.path.join(src_root, src))
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


def band(x, lp=None, hp=None):
    """Low-/high-pass filter (gentle 12 dB/octave slopes, done in one FFT)."""
    if not lp and not hp:
        return x
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if lp:
        g /= np.sqrt(1 + (f / lp) ** 4)
    if hp:
        g *= (f / hp) ** 2 / np.sqrt(1 + (f / hp) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * g, len(x))


def loudness(x):
    """RMS over the loud part, in dB."""
    loud = np.abs(x) > np.abs(x).max() * 0.1
    return 20 * np.log10(np.sqrt(np.mean(x[loud] ** 2)) + 1e-12)


def build_variant(src_root, layers, level, verb, lp=None, hp=None):
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
    # Per-sound tone: a low-pass tames hiss and harsh highs, a high-pass rumble.
    mix = band(np.concatenate([mix, np.zeros(int(0.02 * SR))]), lp, hp)
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
            level = spec.get("level", -6) + (spec["vtrim"][i] if "vtrim" in spec else 0)
            x = build_variant(src_root, layers, level, spec.get("verb", -16), spec.get("lp"), spec.get("hp"))
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
