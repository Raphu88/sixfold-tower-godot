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
echo "Sources ready in $DIR"
