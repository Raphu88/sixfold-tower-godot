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
C1 = "rd_creature/"  # rubberduck's creature packs
C2 = "rd_creature2/"
RW = "rd_water/"
RM = "rd_metalwood/"
RB = "rd_break/"
R2 = "rd_sfx2/"
CB = "combat150/04_magic_spells/"  # lentikula's spell impacts (and CoMiGo's zaps)
AC = "accessory/sfx/"
DR = "drink/qubodup-bottle-and-drink-sounds/"
MG = "magical/magical_"
GH = "ghostly/atmosmoody/atmoseerie0"
BELL = "bells/bell_ding"
TROLL = "troll/troll-roars.ogg@"  # long recordings of many takes
TROLL_IDLE = "troll/troll-idle-noises.ogg@"
SNARL = "snarls/monster-snarl-attack.ogg@"
SNARLS = "snarls/monster-snarls.ogg@"
SCREECH = "screech/evil_screech_1.ogg@"
TREX = "trex/t-rex_calls.mp3@"
STEAM = "steam/steam hisses - Marker #"

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

    # --- the six beasts ------------------------------------------------------
    # Each has a roar (on its floor, and before its biggest blow), a warning
    # voice for its other wind-ups, a hurt cry and a death. Roars and deaths
    # are full moments (0 to -1), warnings soft (-4), hurt cries under the
    # hit sound they come with (-6 to -7).
    # The Gryphon: an eagle's screech over a lion's chest.
    "roar_gryphon": {"variants": [
        v((SCREECH + "1.94+0.94", 0, 0, 0.8), (TROLL + "1.87+0.99", -9, 0, 0.9), ("dragonflap/dragonflap.wav@0+0.8", -10, 0, 1.0)),
        v((SCREECH + "3.86+0.89", 0, 0, 0.78), (TROLL + "7.09+1.2", -9, 0, 0.9)),
    ], "level": 0, "verb": -10, "lp": 8000},
    "warn_gryphon": {"variants": [v((SCREECH + "0.42+0.6", 0, 0, 1.05), ("dragonflap/dragonflap.wav@0+0.6", -10, 0, 1.1)), v((SCREECH + "5.65+0.6", 0, 0, 1.1))], "level": -4, "lp": 7500},
    "hurt_gryphon": {"variants": [v((SCREECH + "1.94+0.45", 0, 0, 1.15)), v((SCREECH + "3.86+0.45", 0, 0, 1.2))], "level": -7, "lp": 7000},
    "kill_gryphon": {"variants": [v((SCREECH + "1.94+0.94", 0, 0, 0.68), (TROLL + "0.06+0.78", -6, 60, 0.75), (S + "slam_03.ogg", -4, 200, 0.6), ("synth:thump", -4, 200, 0.5))], "level": -1, "verb": -9, "lp": 7000},
    # The Kraken: a deep, wet roar from below the water.
    "roar_kraken": {"variants": [v(("deeproar/monster_roar.wav@0.18+2.2", 0, 0, 1.0), (RW + "splash_05.ogg", -6, 0, 0.7), (C1 + "burble_01.ogg", -10, 150, 0.6))], "level": 0, "verb": -10, "lp": 5000},
    "warn_kraken": {"variants": [v((C2 + "grunt_07.ogg", 0, 0, 0.8), (C1 + "burble_02.ogg", -6, 0, 0.7)), v((C2 + "grunt_09.ogg", 0, 0, 0.8), (C1 + "burble_01.ogg", -6, 0, 0.7))], "level": -4, "lp": 5000},
    "hurt_kraken": {"variants": [v((C1 + "monster_04.ogg", 0, 0, 1.0), (RW + "splash_10.ogg", -8, 0, 0.8)), v((C2 + "monster_12.ogg", 0, 0, 0.8), (RW + "splash_09.ogg", -8, 0, 0.8))], "level": -6, "lp": 5000},
    "kill_kraken": {"variants": [v(("deeproar/monster_roar.wav@0.18+3.0", 0, 0, 0.8), (RW + "splash_04.ogg", -3, 300, 0.7), (S + "slam_02.ogg", -6, 300, 0.6), ("synth:thump", -4, 300, 0.5))], "level": -1, "verb": -8, "lp": 5000},
    # The Wyvern: a reptile's call with fire behind it.
    "roar_wyvern": {"variants": [v((TREX + "0.31+1.17", 0, 0, 1.0), (CB + "Fire Spell Impact 1_s06.wav@0+1.2", -8, 100, 1.0))], "level": 0, "verb": -10, "lp": 7000},
    "warn_wyvern": {"variants": [v(("dino/small_dino_raspy_calls.mp3@0.07+0.85", 0, 0, 0.6), (SNARL + "1.65+1.0", -8, 0, 0.8)), v(("dino/small_dino_raspy_calls.mp3@1.12+0.46", 0, 0, 0.55))], "level": -4, "lp": 6000},
    "hurt_wyvern": {"variants": [v((TREX + "2.44+0.6", 0, 0, 1.1)), v((TREX + "0.31+0.6", 0, 0, 1.15))], "level": -6, "lp": 6000},
    "kill_wyvern": {"variants": [v((TREX + "19.67+2.24", 0, 0, 0.9), (S + "slam_03.ogg", -4, 400, 0.6), ("synth:thump", -4, 400, 0.5))], "level": -1, "verb": -9, "lp": 6000},
    # The Manticore: a lion's roar.
    "roar_manticore": {"variants": [v((TROLL + "7.09+1.64", 0, 0, 0.85), ("bear/ogg/bear_01.ogg", -6, 0, 0.8))], "level": 0, "verb": -10, "lp": 6000},
    "warn_manticore": {"variants": [v((SNARLS + "0.18+1.4", 0, 0, 0.8), ("bear/ogg/bear_02.ogg", -8, 0, 0.9)), v((SNARLS + "4.98+1.4", 0, 0, 0.8))], "level": -4, "lp": 6000},
    "hurt_manticore": {"variants": [v((TROLL + "3.63+0.6", 0, 0, 1.0)), v((TROLL + "9.42+0.6", 0, 0, 1.05))], "level": -6, "lp": 6000},
    "kill_manticore": {"variants": [v((TROLL + "1.87+0.99", 0, 0, 0.7), (C1 + "roar_02.ogg", -6, 0, 0.8), (S + "slam_03.ogg", -4, 300, 0.6), ("synth:thump", -4, 300, 0.5))], "level": -1, "verb": -9, "lp": 6000},
    # The Firebird: a bright scream in a rush of flame.
    "roar_firebird": {"variants": [v(("peacock/peacockscream.flac", 0, 0, 0.75), (CB + "Fire Spell Impact 3_s06.wav@0+1.4", -6, 0, 1.0), (SCREECH + "0.42+0.71", -10, 60, 1.2))], "level": 0, "verb": -10, "lp": 8000},
    "warn_firebird": {"variants": [v(("peacock/peacockscream.flac@0.03+0.6", 0, 0, 0.95), ("flame/flame.ogg", -8, 0, 1.0))], "level": -4, "lp": 8000},
    "hurt_firebird": {"variants": [v(("peacock/peacockscream.flac@0.03+0.4", 0, 0, 1.2)), v(("peacock/peacockscream.flac@0.3+0.4", 0, 0, 1.25))], "level": -7, "lp": 7500},
    "kill_firebird": {"variants": [v(("peacock/peacockscream.flac", 0, 0, 0.6), (CB + "Fire Spell Impact 2_s06.wav@0+1.6", -3, 100, 0.9), ("firecrackle/fire-1.wav@0+1.5", -10, 300, 1.0))], "level": -1, "verb": -9, "lp": 7500},
    # The Chimera: lion, goat and serpent at once.
    "roar_chimera": {"variants": [v((TROLL + "5.40+0.91", 0, 0, 0.8), ("sheep/sheep_baa.flac", -8, 120, 0.6), (STEAM + "1.wav@0.1+0.8", -14, 200, 0.7))], "level": 0, "verb": -10, "lp": 6500},
    "warn_chimera": {"variants": [v((SNARL + "1.65+1.17", 0, 0, 0.75), ("sheep/sheep_baa.flac", -12, 0, 0.7)), v((SNARL + "6.81+0.81", 0, 0, 0.75))], "level": -4, "lp": 6000},
    "hurt_chimera": {"variants": [v((TROLL + "9.42+0.67", 0, 0, 1.05), ("sheep/sheep_baa.flac@0.14+0.4", -10, 0, 0.8))], "level": -6, "lp": 6000},
    "kill_chimera": {"variants": [v((TROLL + "0.06+0.78", 0, 0, 0.65), ("sheep/sheep_baa.flac", -6, 200, 0.5), (S + "slam_03.ogg", -4, 300, 0.6), ("synth:thump", -4, 300, 0.5))], "level": -1, "verb": -9, "lp": 6000},
    "wingbeat": {"variants": [v(("dragonflap/dragonflap.wav@0+0.8", 0, 0, 1.0)), v(("dragonflap/dragonflap.wav@0.8+0.8", 0, 0, 1.05))], "level": -6, "lp": 3000},

    # --- monsters' voices ----------------------------------------------------
    # warn_<kind> as it winds up, hurt_<kind> (spaced out: enemy.gd _voice),
    # kill_<kind> as it dies (main.gd plays kill_<kind> when there is one).
    "hurt_slime": {"variants": [v((RW + "slime_12.ogg", 0, 0, 1.2)), v((RW + "slime_13.ogg", 0, 0, 1.2))], "level": -12, "lp": 5000},
    "hurt_knight": {"variants": [v((C2 + "human_02.ogg", 0, 0, 0.85)), v((C2 + "human_03.ogg", 0, 0, 0.85))], "level": -10, "lp": 6000},
    "hurt_archer": {"variants": [v((C2 + "human_05.ogg", 0, 0, 1.0)), v((C2 + "human_06.ogg", 0, 0, 1.0))], "level": -10, "lp": 6000},
    "warn_bat": {"variants": [v(("bat/ogg/bat_02.ogg@0.08+0.5", 0, 0, 1.0)), v(("bat/ogg/bat_03.ogg@0.43+0.5", 0, 0, 1.0))], "level": -9, "lp": 8000},
    "hurt_bat": {"variants": [v(("bat/ogg/bat_03.ogg@0.04+0.23", 0, 0, 1.1)), v(("bat/ogg/bat_02.ogg@0.98+0.3", 0, 0, 1.15))], "level": -11, "lp": 8000},
    "kill_bat": {"variants": [v(("bat/ogg/bat_01.ogg@0.12+0.95", 0, 0, 0.8), ("synth:thump", -10, 0, 1.2))], "level": -5, "lp": 7500},
    "warn_thunderling": {"variants": [v(("elec/charge.wav@0+0.9", 0, 0, 1.0), (C1 + "cute_03.ogg", -8, 0, 1.0))], "level": -7, "lp": 8000},
    "hurt_thunderling": {"variants": [v((CB + "ElectroZap_s01.wav", 0, 0, 1.0), (C1 + "cute_05.ogg", -4, 0, 1.1)), v((CB + "ElectroZap_s01.wav", 0, 0, 0.9), (C1 + "cute_04.ogg", -4, 0, 1.1))], "level": -10, "lp": 8000},
    "kill_thunderling": {"variants": [v((CB + "HeavyZap_s01.wav", 0, 0, 1.0), ("elec/powerdown.wav@0+0.8", -4, 50, 1.0))], "level": -4, "lp": 8000},
    "warn_lurker": {"variants": [v((RW + "splash_03.ogg", 0, 0, 0.9), (C1 + "burble_01.ogg", -2, 100, 0.8))], "level": -7, "lp": 6000},
    "hurt_lurker": {"variants": [v((RW + "slime_05.ogg", 0, 0, 1.0), (C1 + "grunt_02.ogg", -4, 0, 0.9)), v((RW + "slime_07.ogg", 0, 0, 1.0), (C1 + "grunt_03.ogg", -4, 0, 0.9))], "level": -10, "lp": 6000},
    "kill_lurker": {"variants": [v((RW + "splash_08.ogg", 0, 0, 0.8), (C2 + "die_03.ogg", -4, 0, 0.8))], "level": -3, "lp": 6500},
    "warn_shellback": {"variants": [v((C2 + "grunt_08.ogg", 0, 0, 0.9), (RM + "wood_hit_03.ogg", -6, 0, 0.8))], "level": -6, "lp": 5000},
    "hurt_shellback": {"variants": [v((C2 + "grunt_09.ogg", 0, 0, 1.0), (RM + "wood_hit_05.ogg", -4, 0, 0.8)), v((C2 + "grunt_06.ogg", 0, 0, 1.0), (RM + "wood_hit_06.ogg", -4, 0, 0.8))], "level": -10, "lp": 5000},
    "kill_shellback": {"variants": [v((RM + "wood_breaking_01.ogg", 0, 0, 0.8), (C2 + "grunt_06.ogg", -2, 0, 0.8), ("synth:thump", -6, 0, 0.8))], "level": -3, "lp": 6000},
    "warn_cinder": {"variants": [v(("flame/flame.ogg", 0, 0, 1.2), (STEAM + "1.wav@0.1+0.6", -8, 0, 1.3))], "level": -8, "lp": 7000},
    "hurt_cinder": {"variants": [v(("firecrackle/fire-1.wav@0.3+0.4", 0, 0, 1.2), (C1 + "hurt_02.ogg", -8, 0, 1.4))], "level": -11, "lp": 7000},
    "kill_cinder": {"variants": [v((STEAM + "2.wav@0.05+0.8", 0, 0, 1.0), (CB + "Fire Spell Impact 4_s06.wav@0+0.8", -2, 0, 1.2))], "level": -4, "lp": 7000},
    "warn_smith": {"variants": [v((TROLL_IDLE + "21.70+0.81", 0, 0, 1.0), ("anvil/blacksmithhammer.wav", -12, 100, 0.8))], "level": -5, "lp": 6000},
    "hurt_smith": {"variants": [v((TROLL_IDLE + "22.96+0.79", 0, 0, 1.1), (S + "metal_03.ogg", -12, 0, 0.9)), v((TROLL_IDLE + "19.13+0.33", 0, 0, 1.0))], "level": -9, "lp": 6000},
    "kill_smith": {"variants": [v((TROLL_IDLE + "24.26+0.96", 0, 0, 0.85), (RB + "bfh1_metal_falling_01.ogg", -3, 200, 0.9))], "level": -3, "lp": 6500},
    "warn_scorpling": {"variants": [v((C2 + "bug_10.ogg", 0, 0, 1.0), ("insect/insect0.ogg", -6, 0, 0.7))], "level": -9, "lp": 7000},
    "hurt_scorpling": {"variants": [v((C1 + "bug_01.ogg", 0, 0, 1.0)), v((C1 + "bug_04.ogg", 0, 0, 1.0))], "level": -12, "lp": 7000},
    "kill_scorpling": {"variants": [v((C2 + "bug_13.ogg", 0, 0, 0.9), (RB + "bfh1_rock_breaking_03.ogg", -6, 0, 1.3))], "level": -5, "lp": 7000},
    "warn_ram": {"variants": [v((C1 + "nose.ogg", 0, 0, 0.8), ("sheep/sheep_baa.flac", -6, 150, 0.7))], "level": -6, "lp": 6000},
    "hurt_ram": {"variants": [v(("sheep/sheep_baa.flac@0.14+0.45", 0, 0, 0.8)), v(("sheep/sheep_baa.flac@0.14+0.45", 0, 0, 0.72))], "level": -10, "lp": 6000},
    "kill_ram": {"variants": [v(("sheep/sheep_baa.flac", 0, 0, 0.6), ("synth:thump", -4, 0, 0.8))], "level": -3, "lp": 6000},
    "warn_wisp": {"variants": [v((MG + "3.ogg@0+0.8", 0, 0, 1.2))], "level": -9, "lp": 9000},
    "hurt_wisp": {"variants": [v(("icebreak/IceShatters/LedasLuzta2.ogg", -6, 0, 1.3), (MG + "5.ogg@0+0.4", 0, 0, 1.0))], "level": -12, "lp": 9000},
    "kill_wisp": {"variants": [v((MG + "1.ogg@0+1.2", 0, 0, 1.0), ("teleport/teleport.wav", -6, 0, 1.3))], "level": -5, "lp": 9000},
    "warn_bloomcap": {"variants": [v((C1 + "breath.ogg", 0, 0, 0.8), (RW + "bubble_01.ogg", -6, 0, 0.9))], "level": -9, "lp": 6000},
    "hurt_bloomcap": {"variants": [v((RW + "slime_08.ogg", 0, 0, 1.0), (C2 + "slime_02.ogg", -4, 0, 1.0))], "level": -11, "lp": 6000},
    "kill_bloomcap": {"variants": [v((R2 + "sfx100v2_air_03.ogg", 0, 0, 0.8), (RW + "splash_02.ogg", -6, 0, 1.0), (RW + "slime_10.ogg", -4, 0, 0.9))], "level": -4, "lp": 6500},
    "warn_thornhound": {"variants": [v(("dog/dog/dog-snarl.flac", 0, 0, 1.0)), v(("dog/dog/dog-growl.flac", 0, 0, 1.05))], "level": -7, "lp": 6000},
    "hurt_thornhound": {"variants": [v((C1 + "barking_02.ogg", 0, 0, 1.1)), v((C1 + "hurt_01.ogg", 0, 0, 1.0))], "level": -11, "lp": 6500},
    "kill_thornhound": {"variants": [v((C2 + "die_01.ogg", 0, 0, 1.0), ("dog/dog/dog-grumble.flac", -6, 100, 0.9))], "level": -4, "lp": 6500},
    "warn_mongrel": {"variants": [v((SNARL + "3.43+0.75", 0, 0, 1.0), ("dog/dog/dog-growl.flac", -6, 0, 0.8)), v((SNARL + "5.20+0.78", 0, 0, 1.0))], "level": -6, "lp": 6000},
    "hurt_mongrel": {"variants": [v((C1 + "grunt_04.ogg", 0, 0, 1.0), ("dog/dog/dog-grumble.flac", -8, 0, 1.0)), v((C1 + "grunt_05.ogg", 0, 0, 1.0))], "level": -10, "lp": 6000},
    "kill_mongrel": {"variants": [v((C2 + "die_03.ogg", 0, 0, 1.0), (SNARLS + "9.77+1.2", -6, 0, 0.8))], "level": -3, "lp": 6500},
    # Kraken's ink and other bubbles (and the bench's brewing).
    "bubble": {"variants": [v(RW + "bubble_01.ogg"), v(RW + "bubble_02.ogg"), v((RW + "bubble_03.ogg", 0, 0, 0.8))], "level": -8, "lp": 6000},

    # --- the train -----------------------------------------------------------
    "train_whistle": {"variants": [v(("whistle/steam_whistle.wav", 0, 0, 1.0), (STEAM + "3.wav@0+1.2", -12, 600, 0.8))], "level": -5, "verb": -12, "lp": 7000},
    "train_car": {"variants": [v((R2 + "sfx100v2_door_03.ogg", 0, 0, 1.0), (R2 + "sfx100v2_footstep_wood_01.ogg", -8, 200, 1.0)), v((R2 + "sfx100v2_door_03.ogg", 0, 0, 0.9), (R2 + "sfx100v2_footstep_wood_03.ogg", -8, 200, 1.0))], "level": -12, "lp": 6000, "verb": -30},
    "shop_bell": {"variants": [v((BELL + "2.wav", 0, 0, 1.2))], "level": -14, "lp": 7000, "verb": -20},
    # Buying and selling: crystals changing hands. Brewing, the bench's work.
    "buy": {"variants": [v((AC + "coins-shake-01.wav@0+0.6", 0, 0, 1.0), ("sn_coins/coin.5.ogg", -4, 250, 1.0)), v((AC + "coins-shake-02.wav@0+0.6", 0, 0, 1.0), ("sn_coins/coin.9.ogg", -4, 250, 1.0))], "level": -10, "lp": 8000, "verb": -24},
    "sell": {"variants": [v((AC + "coin-spin-fall-01.wav@0+0.9", 0, 0, 1.0), (AC + "coins-shake-03.wav@0+0.5", -6, 0, 1.0))], "level": -10, "lp": 8000, "verb": -24},
    "brew": {"variants": [v(("boil/cooking_without_cover_01.ogg@1+1.2", 0, 0, 1.0), (RW + "bubble_02.ogg", -4, 200, 1.0), (AC + "vial-glass-round-cork-twist-01.wav", -6, 700, 1.0))], "level": -9, "lp": 7000, "verb": -24},
    "craft": {"variants": [v(("anvil/forger.ogg@0.08+1.0", 0, 0, 1.0), ("anvil/blacksmithhammer.wav", -6, 0, 1.0)), v(("anvil/forger.ogg@0.6+1.0", 0, 0, 1.0), ("anvil/blacksmithhammer.wav", -6, 0, 0.95))], "level": -8, "lp": 7000, "verb": -18},
    "craft_rune": {"variants": [v((RM + "tools_04.ogg", 0, 0, 1.0), (MG + "2.ogg@0+1.0", -4, 100, 1.0))], "level": -9, "lp": 7000, "verb": -18},
    "craft_break": {"variants": [v((RB + "bfh1_metal_falling_01.ogg", 0, 0, 1.0), (RM + "wood_breaking_02.ogg", -6, 0, 1.0))], "level": -8, "lp": 7000, "verb": -20},
    "pour": {"variants": [v((AC + "vial-glass-round-uncork-01.wav", 0, 0, 1.0), (RW + "bubble_01.ogg", -8, 150, 1.0))], "level": -11, "lp": 7000, "verb": -24},

    # --- items being used ----------------------------------------------------
    "drink": {"variants": [v((DR + "bottle-open-01.flac", -2, 0, 1.0), (DR + "swallow-01.flac", 0, 250, 1.0)), v((DR + "bottle-open-02.flac", -2, 0, 1.0), (DR + "swallow-03.flac", 0, 250, 1.0))], "level": -9, "lp": 7000},
    "use_vial": {"variants": [v((DR + "bottle-open-03.flac", -2, 0, 1.0), (DR + "swallow-02.flac", 0, 250, 1.0), (MG + "6.ogg@0+1.0", -2, 350, 1.0))], "level": -8, "lp": 8000},
    "use_smoke": {"variants": [v((STEAM + "3.wav@0+1.0", 0, 0, 0.6), (R2 + "sfx100v2_air_02.ogg", -4, 0, 0.6))], "level": -9, "lp": 3000},
    "throw": {"variants": [v((W + "swish-4.wav", 0, 0, 0.9), (AC + "vials-glass-rattle-04.wav", -10, 0, 1.0))], "level": -7},
    "glass_break": {"variants": [v(RB + "bfh1_glass_breaking_01.ogg"), v(RB + "bfh1_glass_breaking_02.ogg"), v(RB + "bfh1_glass_breaking_03.ogg")], "level": -4, "lp": 8000},
    "use_ward": {"variants": [v((CB + "Healing Spell Impact 6_s08.wav@0+1.0", 0, 0, 0.8), (A + "inventory/metal-ringing.wav", -12, 0, 0.8))], "level": -8, "lp": 6000},
    "use_salts": {"variants": [v((AC + "vial-glass-round-uncork-02.wav", -4, 0, 1.0), (C1 + "breath.ogg", 0, 150, 1.1))], "level": -9, "lp": 7000},
    "use_oil": {"variants": [v((AC + "vial-glass-square-empty-open-01.wav", 0, 0, 1.0), (RW + "slime_01.ogg", -10, 150, 1.2))], "level": -10, "lp": 7000},
    "use_stone": {"variants": [v((RB + "bfh1_rock_falling_02.ogg", 0, 0, 0.8), (SN + "impact.1.ogg", -6, 0, 0.7))], "level": -8, "lp": 5000},
    "flare": {"variants": [v(("flame/flame.ogg", 0, 0, 1.0), ("firecrackle/fire-1.wav@0+0.8", -6, 50, 1.2), (STEAM + "4.wav@0+0.6", -14, 0, 0.8))], "level": -5, "lp": 8000},

    # --- puzzles ---------------------------------------------------------------
    "puzzle_solve": {"variants": [v((BELL + "1.wav", 0, 0, 1.0), (S + "gong_02.ogg", -8, 0, 1.2))], "level": -5, "verb": -8, "lp": 8000},
    "puzzle_fail": {"variants": [v(("sn_cavein/cave_in_-_starninjas.ogg@0+1.0", 0, 0, 0.7), (S + "gong_01.ogg", -10, 0, 0.6))], "level": -4, "verb": -10, "lp": 4000},
    "mirror_turn": {"variants": [v((RM + "wood_squeak_01.ogg", 0, 0, 0.6), (R2 + "sfx100v2_stones_01.ogg", -4, 0, 0.7), (K + "metalClick.ogg", -10, 150, 0.9))], "level": -9, "lp": 6000},
    "ice_slide": {"variants": [v((T + "metal-knife-scrape-01.wav@0.07+0.4", 0, 0, 0.6), ("icebreak/IceShatters/LedasLuzta2.ogg", -14, 0, 0.8))], "level": -11, "lp": 3000},
    "ice_bump": {"variants": [v((SN + "impact.1.ogg", 0, 0, 0.8), ("icebreak/IceShatters/LedasLuzta.ogg", -8, 0, 1.0))], "level": -9, "lp": 7000},
    "statue_voice": {"variants": [v((TROLL_IDLE + "0.80+1.5", 0, 0, 0.6), (GH + "2.mp3.flac@2+1.5", -6, 0, 1.0)), v((TROLL_IDLE + "8.78+1.5", 0, 0, 0.6), (GH + "2.mp3.flac@6+1.5", -6, 0, 1.0))], "level": -8, "verb": -8, "lp": 1600},
    "lock_turn": {"variants": [v(AC + "keyhole-lockbox-turn-01.wav"), v(AC + "keyhole-lockbox-turn-03.wav"), v(AC + "keyhole-lockbox-unlock-01.wav")], "level": -6, "lp": 7000},
    "eye_open": {"variants": [v((MG + "4.ogg@0+1.0", 0, 0, 0.8), (C1 + "weird_04.ogg", -8, 0, 0.9))], "level": -7, "lp": 7000},
    "stone_slide": {"variants": [v((R2 + "sfx100v2_stones_02.ogg", 0, 0, 0.6), (RB + "bfh1_rock_falling_02.ogg", -4, 0, 0.6))], "level": -7, "lp": 4000},
    "lever": {"variants": [v((RM + "metal_spring_01.ogg", 0, 0, 0.7), (R2 + "sfx100v2_switch_01.ogg", -2, 100, 0.9))], "level": -7, "lp": 7000},
    "pedestal": {"variants": [v(("flame/flame.ogg", 0, 0, 1.0), (BELL + "3.wav", -6, 0, 1.3))], "level": -7, "verb": -12, "lp": 8000},

    # --- the Makers and the secret essences -----------------------------------
    "maker_meeting": {"variants": [v((GH + "1.mp3.flac@0+3.0", 0, 0, 1.0), (S + "gong_01.ogg", -6, 0, 0.5), ("drain/qubodup-PowerDrain.ogg", -10, 0, 0.8))], "level": -3, "verb": -6, "lp": 6000},
    "maker_glimpse": {"variants": [v((GH + "3.mp3.flac@3+1.5", 0, 0, 1.2), (MG + "7.ogg@0+1.0", -10, 0, 1.0))], "level": -10, "verb": -8, "lp": 6000},
    "maker_fragment": {"variants": [v((BELL + "4.wav", 0, 0, 0.8), (MG + "1.ogg@0+1.2", -6, 0, 1.0))], "level": -6, "verb": -8, "lp": 8000},
    "maker_grant": {"variants": [v((S + "gong_02.ogg", 0, 0, 0.7), (MG + "3.ogg", -4, 0, 1.0), (BELL + "1.wav", -6, 100, 1.0))], "level": -3, "verb": -6, "lp": 8000},
    "secret_life": {"variants": [v((CB + "Healing Spell Impact 3_s08.wav@0+1.2", 0, 0, 1.0), ("cure/Cure2.wav", -6, 0, 1.0))], "level": -6, "verb": -12, "lp": 8000},
    "secret_unmaking": {"variants": [v(("darkmagic/dark_magic/fout-02.flac", 0, 0, 1.0), ("drain/qubodup-PowerDrain.ogg@0+1.0", -6, 0, 1.0))], "level": -6, "verb": -12, "lp": 7000},
    "secret_pass": {"variants": [v((MG + "2.ogg", 0, 0, 0.8), ("synth:wind", -6, 0, 1.0))], "level": -10, "lp": 6000},
    "life_mend": {"variants": [v(("cure/Cure4.wav", 0, 0, 1.1)), v(("cure/Cure3.wav", 0, 0, 1.1))], "level": -11, "lp": 8000},
    "unmake": {"variants": [v(("darkmagic/dark_magic/fout-02.flac", 0, 0, 1.2), (RB + "bfh1_glass_breaking_04.ogg", -10, 0, 0.5))], "level": -6, "lp": 7000},
    "vessel_fill": {"variants": [v((MG + "6.ogg", 0, 0, 1.0), (RW + "bubble_03.ogg", -6, 0, 1.0))], "level": -9, "lp": 8000},

    # --- big moments ----------------------------------------------------------
    # The Regard: a deep gong, the beast's breath far off, a heartbeat.
    "regard": {"variants": [v((S + "gong_01.ogg", 0, 0, 0.6), ("deeproar/monster_roar.wav@0.18+3.0", -6, 300, 0.7), (GH + "1.mp3.flac@4+3.0", -8, 0, 1.0), ("heartbeat/heartbeat_slow_0.wav", -4, 600, 1.0))], "level": 0, "verb": -6, "lp": 6000},
    # A summit won: bells in a rising chord over a gong.
    "summit_win": {"variants": [v((BELL + "1.wav", 0, 0, 1.0), (BELL + "2.wav", -2, 140, 1.26), (BELL + "3.wav", -3, 280, 1.5), (S + "gong_02.ogg", -4, 0, 0.8))], "level": -2, "verb": -8, "lp": 9000},
    # The Proving's shadow rising.
    "shadow_rise": {"variants": [v(("darkmagic/dark_magic/fout-01.flac@0+2.0", 0, 0, 0.7), ("heartbeat/heartbeat_slow_0.wav", -2, 0, 1.0), (GH + "4.mp3.flac@0+2.5", -6, 0, 1.0), (C2 + "roar_04.ogg", -10, 300, 0.6))], "level": -2, "verb": -8, "lp": 6000},
    # The Entity's tips: a soft, high chime.
    "tip_chime": {"variants": [v((BELL + "2.wav", 0, 0, 1.5))], "level": -18, "verb": -14, "lp": 7000},
    # The Designer's rift tearing through rock.
    "rift": {"variants": [v(("sn_cavein/cave_in_-_starninjas.ogg@0+2.0", 0, 0, 1.0), (CB + "Earth Spell Impact 5_s07.wav@0+1.5", -4, 0, 1.0), ("teleport/teleport.wav", -8, 0, 0.6), ("synth:thump", -2, 0, 0.6))], "level": 0, "verb": -8, "lp": 6000},

    # --- bond spells and the Unbound's forms and effects, by family ----------
    "spell_lightning": {"variants": [
        v((CB + "Lightning Spell Impact 1_s06.wav@0+1.3", 0, 0, 1.0), ("elec/hit.wav@0+0.6", -8, 0, 1.0)),
        v((CB + "Lightning Spell Impact 4_s06.wav@0+1.3", 0, 0, 1.0), ("elec/hit.wav@0+0.6", -8, 0, 1.1)),
    ], "level": -3, "lp": 9000},
    "thunder": {"variants": [v((R2 + "sfx100v2_thunder_01.ogg@0+2.2", 0, 0, 1.0), (CB + "Lightning Spell Impact 3_s06.wav@0+1.0", -2, 0, 1.0), ("synth:thump", -3, 0, 0.6))], "level": 0, "verb": -10, "lp": 8000},
    "spell_wind": {"variants": [v(CB + "Wind Spell Impact 1_s07.wav@0+1.4"), v(CB + "Wind Spell Impact 3_s07.wav@0+1.4")], "level": -6, "lp": 7000},
    "spell_water": {"variants": [
        v((CB + "Water Spell Impact 1_s06.wav@0+1.2", 0, 0, 1.0), (RW + "splash_06.ogg", -8, 0, 1.0)),
        v((CB + "Water Spell Impact 4_s06.wav@0+1.2", 0, 0, 1.0), (RW + "splash_14.ogg", -8, 0, 1.0)),
    ], "level": -5, "lp": 8000},
    "geyser": {"variants": [v((RW + "splash_12.ogg", 0, 0, 0.8), (CB + "Water Spell Impact 3_s06.wav@0+1.3", -4, 0, 1.0), ("synth:thump", -6, 0, 0.8))], "level": -3, "lp": 8000},
    "wave": {"variants": [v((CB + "Water Spell Impact 2_s06.wav@0+1.6", 0, 0, 1.0), ("synth:wind", -8, 0, 0.8)), v((CB + "Water Spell Impact 5_s06.wav@0+1.6", 0, 0, 1.0), ("synth:wind", -8, 0, 0.8))], "level": -5, "lp": 7000},
    "spell_frost": {"variants": [
        v((CB + "Ice Spell Impact 1_s06.wav@0+1.2", 0, 0, 1.0), ("icebreak/IceShatters/LedasLuzta5.ogg", -10, 0, 1.0)),
        v((CB + "Ice Spell Impact 3_s06.wav@0+1.2", 0, 0, 1.0), ("icebreak/IceShatters/LedasLuzta4.ogg", -10, 0, 1.0)),
    ], "level": -6, "lp": 9000},
    "spell_fire": {"variants": [
        v((CB + "Fire Spell Impact 3_s06.wav@0+1.2", 0, 0, 1.0), ("flame/flame.ogg", -6, 0, 1.0)),
        v((CB + "Fire Spell Impact 5_s06.wav@0+1.2", 0, 0, 1.0), ("flame/flame.ogg", -6, 0, 0.9)),
    ], "level": -4, "lp": 8000},
    "fire_blast": {"variants": [
        v((CB + "Fire Spell Impact 1_s06.wav@0+1.4", 0, 0, 1.0), (S + "slam_04.ogg", -6, 0, 0.8), ("synth:thump", -4, 0, 0.7)),
        v((CB + "Fire Spell Impact 4_s06.wav@0+1.4", 0, 0, 1.0), (S + "slam_04.ogg", -6, 0, 0.75), ("synth:thump", -4, 0, 0.7)),
    ], "level": -2, "lp": 8000},
    "spell_stone": {"variants": [
        v((CB + "Earth Spell Impact 2_s07.wav@0+1.2", 0, 0, 1.0), (RB + "bfh1_rock_breaking_01.ogg", -6, 0, 1.0)),
        v((CB + "Earth Spell Impact 4_s07.wav@0+1.2", 0, 0, 1.0), (RB + "bfh1_rock_breaking_02.ogg", -6, 0, 1.0)),
    ], "level": -3, "lp": 7000},
    "spell_sand": {"variants": [v(("sandspell/sand-spell.flac", 0, 0, 1.0), (CB + "Earth Spell Impact 3_s07.wav@0+1.0", -10, 0, 1.0))], "level": -5, "lp": 7000},
    "spell_iron": {"variants": [
        v((S + "metal_07.ogg", 0, 0, 1.0), ("anvil/blacksmithhammer.wav", -4, 0, 1.0), (A + "inventory/metal-ringing.wav", -10, 20, 0.9)),
        v((RM + "metal_hit_01.ogg", 0, 0, 0.9), ("anvil/blacksmithhammer.wav", -4, 0, 0.9), (A + "inventory/metal-ringing.wav", -10, 20, 0.8)),
    ], "level": -4, "verb": -12, "lp": 8000},
    "spell_blade": {"variants": [
        v((W + "swish-12.wav", 0, 0, 1.1), (A + "battle/sword-unsheathe2.wav", -4, 40, 1.0), (S + "metal_09.ogg", -10, 80, 1.2)),
        v((W + "swish-13.wav", 0, 0, 1.1), (A + "battle/sword-unsheathe2.wav", -4, 40, 0.9), (S + "metal_09.ogg", -10, 80, 1.1)),
    ], "level": -5, "lp": 8000},
    "spell_rune": {"variants": [v((MG + "3.ogg@0+1.0", 0, 0, 1.0), (BELL + "4.wav", -12, 0, 1.2))], "level": -7, "lp": 8000},
    "spell_poison": {"variants": [v((RW + "slime_06.ogg", 0, 0, 1.0), (STEAM + "2.wav@0+0.6", -10, 0, 0.8), (RW + "bubble_02.ogg", -8, 0, 1.0))], "level": -6, "lp": 6000},
    "spell_life": {"variants": [v(CB + "Healing Spell Impact 6_s08.wav@0+1.2"), v(CB + "Healing Spell Impact 15_s08.wav@0+1.2")], "level": -7, "lp": 8000},
    "spell_unmaking": {"variants": [v(("darkmagic/dark_magic/fout-03.flac@0+1.2", 0, 0, 1.0), ("drain/qubodup-PowerDrain.ogg@0+1.0", -8, 0, 1.0))], "level": -5, "lp": 7000},
    "beast_call": {"variants": [v((SNARLS + "0.18+1.5", 0, 0, 1.0), (C1 + "howl.ogg", -6, 100, 1.0))], "level": -4, "lp": 6000},
    "form_bolt": {"variants": [v((CB + "EnergyZap_s01.wav", 0, 0, 1.0), (CB + "ElectroZap_s01.wav", -6, 0, 1.0))], "level": -6, "lp": 8000},
    "form_beam": {"variants": [v(("elec/charge.wav@0+1.0", 0, 0, 1.0), (MG + "7.ogg@0+1.0", -8, 0, 1.0))], "level": -7, "lp": 8000},
    "form_hum": {"variants": [v((MG + "4.ogg@0+1.2", 0, 0, 0.6))], "level": -8, "lp": 3000},
    "form_shell": {"variants": [v((CB + "Healing Spell Impact 1_s08.wav@0+1.0", 0, 0, 0.7), (S + "metal_09.ogg", -10, 0, 0.6))], "level": -7, "lp": 7000},
    "heartbeat": {"variants": [v(("heartbeat/heartbeat_slow_0.wav@0+0.9", 0, 0, 1.0), ("synth:thump", -6, 0, 0.8))], "level": -4, "lp": 3000},
}

# Each tower's ambience (and the train's), built as a seamless loop under
# the music: "beds" run the whole length (looped if short), "scatter" drops
# one-shots in at random every so often (distant cries, drips, an anvil).
# Layer: (source, gain dB, pitch, lp, hp); scatter adds the average gap (s).
AMB_LEN = 40.0
AMBIENCE = {
    # Wind-swept halls, and something with wings far above.
    "gryphon": {"beds": [("windy/windy_ambiance.ogg@10+44", 0, 1.0, 3000, 80)],
                "scatter": [(SCREECH + "1.94+0.94", -24, 0.6, 1800, 200, 14), ("dragonflap/dragonflap.wav", -20, 0.9, 1500, 60, 11)]},
    # Flooded halls: dripping, lapping water, a bubble, something huge below.
    "kraken": {"beds": [("drip/atmosbasement.mp3_.flac", 0, 1.0, 6000, 100), (RW + "loop_water_02.ogg", -10, 0.9, 2500, 100)],
               "scatter": [(RW + "bubble_01.ogg", -16, 0.8, 3000, 100, 7), (RW + "bubble_02.ogg", -16, 0.7, 3000, 100, 9),
                           ("deeproar/monster_roar.wav@0.18+4.0", -24, 0.55, 700, 40, 19)]},
    # The forge: a boiler's roar, the fire, an anvil somewhere, steam.
    "wyvern": {"beds": [("steam/generator_loop.wav", -2, 0.9, 1800, 40), ("firecrackle/fire-1.wav", -8, 1.0, 5000, 200)],
               "scatter": [("anvil/blacksmithhammer.wav", -20, 0.8, 3000, 200, 7), (STEAM + "1.wav", -24, 0.8, 4000, 300, 11)]},
    # Sun-baked sandstone: a dry wind, insects in the heat, sand trickling.
    "manticore": {"beds": [("windy/windy_ambiance.ogg@60+44", -2, 0.9, 1800, 80), ("crickets/crickets_1.mp3", -14, 1.15, 9000, 2500)],
                  "scatter": [(R2 + "sfx100v2_stones_01.ogg", -24, 0.6, 3000, 200, 9), (R2 + "sfx100v2_stones_03.ogg", -24, 0.5, 3000, 200, 13)]},
    # Open heights over chasms: a high wind, embers, a far-off cry.
    "firebird": {"beds": [("windy/windy_ambiance.ogg@100+44", 0, 1.1, 4000, 200), ("firecrackle/fire-1.wav", -16, 1.1, 6000, 300)],
                 "scatter": [("peacock/peacockscream.flac", -28, 0.7, 2500, 300, 17)]},
    # The Thornwild: night insects, birds, a growl in the thorns.
    "chimera": {"beds": [("crickets/crickets_1.mp3", -6, 1.0, 8000, 300)],
                "scatter": [("forestbirds/Forest Birds/Forest Birds 2.wav", -18, 1.0, 6000, 400, 10), ("forestbirds/Forest Birds/Forest Birds 7.wav", -18, 0.95, 6000, 400, 12),
                            (SNARLS + "9.77+2.55", -26, 0.7, 1500, 100, 15), ("dog/dog/dog-growl.flac", -26, 0.8, 1500, 100, 17)]},
    # The train: a deep rumble, the engine's chuff, wheels over rail joints.
    "train": {"beds": [("synth:rumble", 0, 1.0, 140, 25), ("steamboat/steamboat_engine.wav", -12, 0.8, 1400, 60)],
              "clack": (R2 + "sfx100v2_wood_hit_01.ogg", -14, 0.55, 2500, 150),
              "scatter": [(AC + "vials-glass-rattle-03.wav", -30, 0.8, 5000, 300, 9)]},
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
    elif src.startswith(P + "#"):
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
    # Godot imports the effects with QOA compression (about a fifth of the
    # size in the web build, and it sounds the same): a new sound gets an
    # .import file asking for it; Godot fills in the rest on import.
    imp = path + ".import"
    if os.path.exists(imp):
        text = open(imp).read()
        if "compress/mode=2" not in text:
            open(imp, "w").write(text.replace("compress/mode=0", "compress/mode=2").replace("compress/mode=1", "compress/mode=2"))
    else:
        open(imp, "w").write('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\ncompress/mode=2\n')


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


def _amb_clip(src_root, src, pitch, lp, hp):
    if src == "synth:rumble":  # brown noise: the train's low rumble
        n = int((AMB_LEN + 8) * SR)
        x = np.cumsum(np.random.uniform(-1, 1, n))
        x -= np.convolve(x, np.ones(4000) / 4000, "same")  # (no drift)
    else:
        x = load_layer(src_root, src, pitch)
    x = band(x, lp, hp)
    return x / (np.sqrt(np.mean(x[np.abs(x) > np.abs(x).max() * 0.05] ** 2)) + 1e-12)


def build_ambience(src_root, name, spec):
    """A seamless mono loop: beds looped to length, one-shots scattered, the
    end crossfaded into the start. Small for the web build (mono, 32 kHz)."""
    rng = np.random.default_rng(len(name) * 101)
    fade = 3.0
    n, nf = int(AMB_LEN * SR), int(fade * SR)
    out = np.zeros(n + nf)
    for src, gain, pitch, lp, hp in spec.get("beds", []):
        x = _amb_clip(src_root, src, pitch, lp, hp) * 10 ** (gain / 20)
        pos = 0
        xf = min(int(0.5 * SR), len(x) // 4)
        while pos < len(out):  # loop a short bed with small crossfades
            seg = x.copy()
            seg[:xf] *= np.linspace(0, 1, xf) if pos > 0 else 1
            seg[-xf:] *= np.linspace(1, 0, xf)
            end = min(len(out), pos + len(seg))
            out[pos:end] += seg[:end - pos]
            pos += len(seg) - xf
    if "clack" in spec:  # wheels over rail joints: two clacks each second or so
        src, gain, pitch, lp, hp = spec["clack"]
        c = _amb_clip(src_root, src, pitch, lp, hp) * 10 ** (gain / 20)
        t = 0.3
        while t < AMB_LEN:
            for dt, g in ((0.0, 1.0), (0.16, 0.7)):
                at = int((t + dt) * SR)
                end = min(len(out), at + len(c))
                out[at:end] += c[:end - at] * g * rng.uniform(0.8, 1.1)
            t += 1.15
    for src, gain, pitch, lp, hp, every in spec.get("scatter", []):
        x = _amb_clip(src_root, src, pitch, lp, hp)
        t = rng.uniform(0, every)
        while t < AMB_LEN:
            at = int(t * SR)
            g = 10 ** ((gain + rng.uniform(-4, 1)) / 20)
            seg = x * g
            idx = (np.arange(len(seg)) + at) % n  # (wraps around the loop's end)
            np.add.at(out, idx, seg)
            t += every * rng.uniform(0.6, 1.4)
    # Crossfade the tail into the head so it loops without a seam.
    ramp = np.linspace(0, 1, nf)
    looped = out[:n].copy()
    looped[:nf] = out[n:n + nf] * (1 - ramp) + out[:nf] * ramp
    looped *= 10 ** ((-21 - 20 * np.log10(np.sqrt(np.mean(looped ** 2)) + 1e-12)) / 20)
    looped = np.tanh(looped * 1.05) / 1.05
    pcm = (np.clip(looped, -1, 1) * 32000).astype("<i2").tobytes()
    path = os.path.join(OUT_MUSIC, "ambience_%s.ogg" % name)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "2", path], input=pcm, check=True)
    return "res://assets/audio/music/ambience_%s.ogg" % name


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
    for name, spec in AMBIENCE.items():
        music["ambience_" + name] = build_ambience(src_root, name, spec)
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
