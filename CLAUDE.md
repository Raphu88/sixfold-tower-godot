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

## Project
- Everything visual is drawn in code (no art files). Colours live in `scripts/palette.gd` (world) and `scripts/ui.gd` (menus and HUD).
- Sounds are built from CC0 packs by `tools/build_audio.py`; see `CREDITS.md` and the README. Only use CC0 assets.
- See README.md for the design, controls and file layout.
