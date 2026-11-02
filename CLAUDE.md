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

## Project
- Everything visual is drawn in code (no art files). Colours live in `scripts/palette.gd`.
- Sounds are built from CC0 packs by `tools/build_audio.py`; see `CREDITS.md` and the README. Only use CC0 assets.
- See README.md for the design, controls and file layout.
