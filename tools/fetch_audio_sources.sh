#!/usr/bin/env bash
# Downloads the CC0 sound packs that tools/build_audio.py builds the game's
# sounds from. Everything here is CC0 (public domain) from opengameart.org.
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
get_file independent_hits hit.mp3                    # Independent.nu: 37 hits/punches
get_file music evil_temple.ogg                       # HaelDB: Evil temple Ambiance loop
get_file music dark_cavern_ambient_001.ogg           # Paul Wortmann: Dark Cavern Ambient
echo "Sources ready in $DIR"
