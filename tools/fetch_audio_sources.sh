#!/usr/bin/env bash
# Downloads the CC0 sound packs that tools/build_audio.py builds the game's
# sounds from. Everything here is CC0 (public domain) from opengameart.org.
# The Medieval Weapon Textures pack comes as .7z: needs 7z, or `pip install py7zr`.
# Usage: tools/fetch_audio_sources.sh [dir]   (default: .audio_sources)
set -euo pipefail
DIR="${1:-.audio_sources}"
BASE="https://opengameart.org/sites/default/files"
mkdir -p "$DIR"
cd "$DIR"

get_zip() {  # name file
  [ -d "$1" ] && return
  curl -fsSL -o "$1.zip" "$BASE/$2"
  mkdir -p "$1" && unzip -q -o "$1.zip" -d "$1" && rm "$1.zip"
}
get_7z() {  # name file (several archives may unpack into one folder)
  [ -f "$1/.$2.done" ] && return
  curl -fsSL -o "$2" "$BASE/$2"
  mkdir -p "$1"
  if command -v 7z >/dev/null; then 7z x -y -o"$1" "$2" >/dev/null
  else python3 -m py7zr x "$2" "$1"  # pip install py7zr
  fi
  rm "$2" && touch "$1/.$2.done"
}
get_file() {  # name file
  mkdir -p "$1"
  [ -f "$1/$2" ] || curl -fsSL -o "$1/$2" "$BASE/$2"
}

get_zip kenney_rpg RPGsounds_Kenney.zip              # Kenney: 50 RPG Sound Effects
get_zip artisticdude_rpg rpg_sound_pack.zip          # artisticdude: RPG Sound Pack
get_zip rubberduck_rpg 80-CC0-RPG-SFX_0.zip          # rubberduck: 80 CC0 RPG SFX
get_zip rubberduck_sfx 100-CC0-SFX_0.zip             # rubberduck: 100 CC0 SFX
get_zip starninjas_impact impact_-_starninjas.zip    # StarNinjas: 10 Impact/Shield Blocks
get_zip artisticdude_swishes swishes.zip             # artisticdude: Swishes Sound Pack
get_zip tinysized tinysized.zip                      # Vehicle (Jan Schupke): Tinysized SFX
get_zip kenney_interface kenney_interfaceSounds.zip  # Kenney: Interface Sounds
get_7z medieval_textures medieval_sfx_textures_1_of_2.7z  # Still North Media: Medieval Weapon Textures
get_7z medieval_textures medieval_sfx_textures_2_of_2.7z
get_file independent_hits hit.mp3                    # Independent.nu: 37 hits/punches
get_file music evil_temple.ogg                       # HaelDB: Evil temple Ambiance loop
get_file music dark_cavern_ambient_001.ogg           # Paul Wortmann: Dark Cavern Ambient

# --- monsters, the train, the bench, puzzles, the Makers, bonds and towers ---
get_zip rd_creature 80-CC0-creature-SFX_0.zip        # rubberduck: 80 CC0 creature SFX
get_zip rd_creature2 80-CC0-creature-sfx-2.zip       # rubberduck: 80 CC0 creature SFX #2
get_zip rd_water water-splash-slime-sfx.zip          # rubberduck: 40 CC0 water / splash / slime SFX
get_zip rd_metalwood 100-CC0-wood-metal-SFX.zip      # rubberduck: 100 CC0 metal and wood SFX
get_zip rd_break sfx_breaking_and_falling.zip        # rubberduck: 75 CC0 breaking / falling / hit SFX
get_zip rd_sfx2 sfx_100_v2.zip                       # rubberduck: 100 CC0 SFX #2
get_zip sn_coins coins_-_starninjas.zip              # StarNinjas: 12 Coin Sound Effects
get_file sn_cavein cave_in_-_starninjas.ogg          # StarNinjas: Cave In
get_file troll troll-roars.ogg                       # Darsycho: Big scary troll sounds
get_file troll troll-idle-noises.ogg
get_file snarls monster-snarl-attack.ogg             # Darsycho: Monster snarls
get_file snarls monster-snarls.ogg
get_file deeproar monster_roar.wav                   # trazzz123: CC0 Deep Monster Roar
get_zip bat bat.zip                                  # AntumDeluge: Bat Screeches
get_zip bear bear.zip                                # AntumDeluge: Bear Growls
get_file sheep sheep_baa.flac                        # AntumDeluge: Sheep Baa
get_file screech evil_screech_1.ogg                  # Nocturnal_Vanguard: Evil Screech 1
get_file peacock peacockscream.flac                  # qubodup: Peacock scream
get_file trex t-rex_calls.mp3                        # CaveboyTup: T-rex Calls
get_file dino small_dino_raspy_calls.mp3             # CaveboyTup: Small Dino Raspy Calls
get_7z dog dog_0.7z                                  # qubodup: Dog Snarl Grunt Grumble
get_zip insect insect.zip                            # fvcalderan: Insect Sounds
get_file whistle steam_whistle.wav                   # bart: Steam whistle
get_zip steam steam_hisses.zip                       # bart: Steam release sounds
get_file steam generator_loop.wav                    # bart: Steam boiler sound loop
get_file steamboat steamboat_engine.wav              # Spring Spring: Steamboat Engine Sound
get_file anvil forger.ogg                            # themightyglider: Hammer on Anvil
get_file anvil blacksmithhammer.wav                  # VishwaJai: Blacksmith's Hammer
get_file boil cooking_without_cover_01.ogg           # TinyWorlds: boiling water loops
get_7z drink qubodup-bottle-and-drink-sounds.7z      # qubodup: Liquid Bottle Drink Set
get_zip accessory accessory.zip                      # Vehicle (Jan Schupke): Fantasy Accessory SFX Library
get_zip combat150 150gameeffectsounds.zip            # untamedpixels: 150 Combat Sound Effects (spell impacts by lentikula)
for f in charge.wav chargestart.wav hit.wav powerdown.wav teleport_1.wav; do
  get_file elec "$f"                                 # faxcorp: Electricity Game Sound Pack
done
for n in 1 2 3 4 5 6 7; do get_file magical "magical_$n.ogg"; done  # JaggedStone: Magic Spell SFX
get_file teleport teleport.wav                       # Ogrebane: Teleport Spell
get_7z darkmagic dark_magic.7z                       # qubodup: 3 dark magic spells
get_file drain qubodup-PowerDrain.ogg                # qubodup: Energy Drain
get_zip cure curemagic.zip                           # Someoneman: Cure Magic
for n in 1 2 3 4; do get_file bells "bell_ding$n.wav"; done  # PWL: Bell dings/chimes
get_7z ghostly independent_nu_ljudbank-atmosphere_moody.7z  # qubodup (Independent.nu): 4 Atmospheric ghostly loops
get_file heartbeat heartbeat_slow_0.wav              # bart: Heartbeat sounds
get_file dragonflap dragonflap.wav                   # VishwaJai: Dragon Flap
get_zip icebreak IceShatters_0.zip                   # IgnasD: Ice breaking/shattering
get_file sandspell sand-spell.flac                   # qubodup: Sand spell
get_file windy windy_ambiance.ogg                    # Some Weirdo: windy ambient noise
get_7z forestbirds forest_birds.7z                   # pauliuw: Forest bird sounds
get_file drip atmosbasement.mp3_.flac                # qubodup: Dripping water loop
get_file firecrackle fire-1.wav                      # AntumDeluge: Fire Crackling
get_file flame flame.ogg                             # themightyglider: Catching fire
echo "Sources ready in $DIR"
