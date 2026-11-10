# Credits

All sound effects and music are **CC0** (public domain) from [OpenGameArt.org](https://opengameart.org). Credit isn't required, but these creators deserve it:

| Pack | Author | Used for |
| --- | --- | --- |
| [50 RPG Sound Effects](https://opengameart.org/content/50-rpg-sound-effects) | Kenney | chops, footsteps, cloth, creaks, knife slices, book pages (menus) |
| [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) | artisticdude | sword swings, armour, cloth, metal ring |
| [Swishes Sound Pack](https://opengameart.org/content/swishes-sound-pack) | artisticdude | punches, heavy swings, dodges |
| [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | rubberduck | spells, slime, creature sounds, arrow thunks, rubble |
| [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) | rubberduck | slams, metal clangs, wood, gong |
| [37 hits/punches](https://opengameart.org/content/37-hitspunches) | Independent.nu | punch and hit bodies |
| [Evil temple Ambiance loop](https://opengameart.org/content/evil-temple-ambiance-loop) | HaelDB | background music |
| [Dark Cavern Ambient](https://opengameart.org/content/dark-cavern-ambient) | Paul Wortmann | tower ambience |
| [Medieval Sound Effects: Weapon Textures](https://opengameart.org/content/medieval-sound-effects-weapon-textures) | Still North Media (posted by MedicineStorm) | bow draw, nock and release, crossbow shot, reload and bolt, dagger and spear swings, blade draws |
| [Fantasy Sound Effects (Tinysized SFX)](https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx) | Vehicle (Jan Schupke) | dagger draw, pouch (pick-ups, inventory), spike trap scrape, gas hiss |
| [Interface Sounds](https://opengameart.org/content/interface-sounds) | Kenney | menu clicks |
| [10 Impact/Shield Blocks](https://opengameart.org/content/10-impactshield-blocks) | StarNinjas | mace and war hammer hits |

The game's sounds are built from these with `tools/build_audio.py`: layered, levelled, given a shared room reverb, and in a few cases mixed with a synthesised thump or string. `tools/fetch_audio_sources.sh` downloads the original packs.

## Fonts

The interface's three typefaces are under the **SIL Open Font License 1.1** (free to use, embed and share with the game; the licence travels with each font in `assets/fonts/<family>/OFL.txt`). They're the unmodified files from Google Fonts (Grenze and Cormorant Garamond are variable fonts: one file holds every weight, and the game picks one).

| Font | Designers | Used for | Files |
| --- | --- | --- | --- |
| [Grenze Gotisch](https://fonts.google.com/specimen/Grenze+Gotisch) | Omnibus-Type (Renata Polastri, Pablo Ugerman) | every title, heading, label, button, tab and name, banners and the HUD's big words | `assets/fonts/grenze_gotisch/` (Bold) |
| [Grenze](https://fonts.google.com/specimen/Grenze) | Omnibus-Type (Renata Polastri, Pablo Ugerman) | text: descriptions, hints, numbers and key badges | `assets/fonts/grenze/` (variable; Regular, Medium and SemiBold used) |
| [Cormorant Garamond](https://fonts.google.com/specimen/Cormorant+Garamond) | Christian Thalmann (Catharsis Fonts) | inscriptions: words written in the world or quoted (rule panels, riddles, the Makers' words, room rules, mottos, the title's tagline) | `assets/fonts/cormorant_garamond/` (Italic, variable; SemiBold used) |
