# Notes for Claude

## Workflow
- **Merge automatically.** The owner wants every finished update merged into `main` without asking: push the branch, open a pull request, and merge it. They update by pulling `main` in GitHub Desktop, so anything not on `main` doesn't reach them.
- Before merging, run the checks below and make sure they pass.
- The owner is new to Git and Godot: explain steps plainly, avoid jargon, and give click-by-click instructions when they need to do something.

## Checks
Godot 4.3 is installed in cloud sessions by the environment setup script.

```bash
godot --headless --editor --quit
```
(imports assets; needed after adding sounds or other files)

```bash
godot --headless -s tests/smoke_test.gd
```

```bash
godot --headless --quit-after 1200
```

Screenshots can be rendered with `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s <script>` using a SceneTree script that saves `root.get_viewport().get_texture().get_image()`.

## Web build
- `.github/workflows/web.yml` exports the game for web on every push to `main` and publishes it to GitHub Pages: https://raphu88.github.io/sixfold-tower-godot/
- The owner tests on an Android phone through that link, so keep the touch controls (`scripts/touch.gd`) working when adding actions.
- To export locally, the web templates (`web_nothreads_release.zip`, `web_nothreads_debug.zip`) must be in `~/.local/share/godot/export_templates/4.3.stable/`.

## Design decisions (from the owner)
- This game ports the owner's earlier web game "Sixfold Tower" while removing anything tied to Andrew Rowe's books (Arcane Ascension). Never use his terms: no "attunement", "spire", "trial", "judgment", "mana". Use **bond** (formally Essence Bond) for the power, **mark** for its sign on the body, **essence** for the resource, **tower** for the place, and **the Regard** for the first-climb moment.
- The first climb is bondless and ends in the Regard: the tower's beast takes notice and the most-used body part takes its first mark. Dying on the first climb still grants a mark, but a faint one that needs extra essence before it grows.
- Bonds grow across climbs from essence banked at stairs, not within a run. Marks spreading on the body replace the old game's "shroud".
- Story and the purpose of the towers are still to be written by the owner; keep names and text in data so they're easy to change.
- The game is mechanically dense: every new mechanic or screen should come with the Entity explaining it (a first-time moment, a "How does it work?" dialogue topic, and hover/hold help for its buttons), and navigation should be easy to understand without reading the README.

## Six Towers LITE (`lite/`)
- A separate, small Godot project for a six-year-old who can't read (see `lite/README.md`). Keep it separate from the full game: no files shared, only copies of sounds made by `python3 lite/tools/copy_sounds.py` (rerun it when LITE plays a new sound).
- Pictures first (everything must be playable without reading), with a few short, simple words to help a child learning to read: in the Andika font, all in `TEXT` in `lite/scripts/data.gd`, read aloud by a natural voice (Kokoro clips made by `python3 lite/tools/make_voice.py`; rerun it after adding or changing any spoken words, then import; the test fails if a spoken line has no clip). The wordless guide and a pointing finger explain new things instead of the Entity's text. Six floors a climb, each a room from a text map (`lite/scripts/floor_map.gd`) with an easy puzzle, portals and sometimes a secret treasure room; the first climb's Regard after floor 3. The owner wants it challenging (his son finished the first version in 20 minutes): hearts carry between floors, falling ends the climb, monsters and beasts get hard, towers unlock in order, marks grow to 5 stars with an upgrade pick (one of two) at each, essence flows into body parts by play style and favourite weapon, and treasure to wear is found in secret rooms and from beasts. Still fair and readable (clear warnings before every attack), with a much simpler magic system than the full game. Keep its touch controls working.
- It looks like the full game: its climber, monsters, beasts, rooms and buttons are copies of the full game's drawing code (table in `lite/README.md`), drawn bigger (2.2x, beasts 1.6x), brighter and a little more cartoony than the full game (punchier colours and thicker outlines: the TOON_ numbers in `lite/scripts/palette.gd`). When the full game's drawings change, copy the change over if LITE should follow. LITE has the full game's roll, parry, swappable weapons (sword, dagger, hammer, bow), climber screen and appearance choices, all kinder and simpler; monsters get a little harder each floor up.
- Checks, from the `lite` folder: `godot --headless --editor --quit`, then `godot --headless -s tests/test.gd`. Run them too when LITE changes.
- `.github/workflows/web.yml` tests it and publishes it beside the full game: https://raphu88.github.io/sixfold-tower-godot/lite/

## Project
- Everything visual is drawn in code (no art files). Colours live in `scripts/palette.gd` (world) and `scripts/ui.gd` (menus and HUD).
- Sounds are built from CC0 packs by `tools/build_audio.py`; see `CREDITS.md` and the README. Only use CC0 assets, except fonts: the owner allows SIL Open Font License (OFL) fonts, credited in `CREDITS.md` with their license file shipped alongside. One more exception, for Six Towers LITE only: its spoken voice clips are recorded with the Kokoro voice (Apache 2.0), which the owner approved; credited in `lite/CREDITS.md`.
- See README.md for the design, controls and file layout.
