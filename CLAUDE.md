# Notes for Claude

## Workflow
- **Merge automatically.** The owner wants every finished update merged into `main` without asking: push the branch, open a pull request, and merge it. They update by pulling `main` in GitHub Desktop, so anything not on `main` doesn't reach them.
- Before merging, run the checks below and make sure they pass.
- The owner is new to Git and Godot: explain steps plainly, avoid jargon, and give click-by-click instructions when they need to do something.

## Checks
Godot 4.3 is installed in cloud sessions by the environment setup script.

**Keep testing cheap (the owner pays for every wasted rerun).** The cloud machine has 4 cores, and many checks are timing-based: overloading it makes them fail falsely, and chasing those failures wastes the owner's usage. So: at most one or two subagents/builders at a time; builders run only the test parts for what they changed; run the full smoke test once, on a quiet machine, before merging (GitHub runs it again before deploying); never run several full test runs side by side, and don't investigate a failure that only shows up under heavy load. In this engine build, calling a method on a freed node crashes the engine (signal 11): guard with `is_instance_valid` in tests and game code.

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
- The first climb is a normal climb that starts with no mark. Floor 6 opens with the Regard: the tower's guardian (its beast) takes notice and the most-used body part takes its first mark at full strength; then the Proving follows on the same floor, and the guardian offers an exit (leave for the train with the mark, or climb on). Dying before the Regard still grants a mark, but a faint one scaled by the floor reached (50% on floor 1, +10% a floor, full on floor 6) that needs extra essence before it grows (`scripts/climb_shape.gd`).
- Every stair has a barrier that forms as you arrive: an iron gate on floors 1-6 (roll under it in its first 30 seconds, or break it), a ward on floors 7-12 (up in 15 seconds, broken only by the tower's own essence). Slipping past or breaking one costs a horde (6 / 12); with no mark it makes you Unbound, and a marked climber's third slip (across climbs) brings a Maker. Three camps a climb (after floors 3, 6, 9), three cards each. When all six guardians are beaten an ending plays (placeholder text), then the same climber plays on.
- Marks grow from use, refilled from essence banked at stairs (`scripts/mark_use.gd`): at each stair the marks' share refills what each mark's spells used and deepens its pool by 0.6 x that use (an unused mark takes only a trickle; leftovers condense into crystals; no cap a climb). Burns stack: burned, paralyzed, and a forced cast burns a mark out (dark for climbs, counted like a slip toward a Maker). Marks spreading on the body replace the old game's "shroud".
- **Items with essence carry their own pool:** charms with a charge, enchanted off-hand pieces (wands, the Ember Dirk, the Tide Ward) and every enchanted weapon (melee, bow, crossbow, pistol) hold uses of their own essence (kept on the record as "charge"; none noted is full, so old saves' pieces are full), shown as a small flat bar on the item. A use draws on the item's pool first, then on the climber's carried (unbanked) essence; with neither, its essence effect doesn't fire (weapons still work plainly). The climber filters essence in to refill it (inventory in the tower when no monster is after you; the workshop bench with crystals on the train) or to power it (hold the off-hand button: the next use hits harder). Nothing else refills a pool, not even a new climb (`scripts/item_pool.gd`, `tests/parts/item_pools.gd`).
- The healing potion is called the **Healing Vial** (canonical: correct it if it's ever called something else, e.g. "Healing Draught"), and the stamina potion is the **Stamina Vial**.
- **Sixes:** every count of things the player collects or chooses from (marks, monsters, weapons, items, charms, puzzles, titles, ranks, levels, steps...) divides by six; 3 is also allowed. Never cut to fit: a 2 or 4 rounds up to 3 or 6, anything else rounds up to the next multiple of six. The targets agreed so far are in the Systems Map's "Counts by sixes" table.
- **No per-climb caps:** growth (e.g. the Unbound's Nodes growing by use) isn't capped per climb; banked essence (refills cost it) and strain hold the pace (`scripts/unbound.gd`, pace held by `tests/parts/unbound_cup.gd`).
- **Sealing (the Unbound choose; the marked can't):** on the train, on the Body tab, an Unbound can seal a Node (second press, clear warning). A sealed Node takes no essence (most of what would pool there condenses into crystals; a little reaches the open Nodes), gives up what it holds (crystals), its size, technique, gift, minor ability and attributes; at least one Node stays open; each sealed Node makes the open ones grow faster from use and hit harder. Unsealed, a Node starts asleep at size 0. Focus trades breadth for depth, not speed: one open Node reaches level 12 a little sooner than a broad climber's main Node, not drastically (`unbound.gd SEAL`, `tests/parts/sealing.gd`).
- **Guardians learn from each other's deaths (marked and Unbound alike):** guardians don't adapt within a fight; a slain guardian leaves a lesson of how its killer fought (essences, forms, Nodes or marks, range, rolls vs parries) and every other guardian applies every lesson so far, adding up (resist, brace, sidestep shots, keep distance or press in, vary wind-ups), fair and readable, never immune (capped). Mixing up your style beats it. Nobody tells the climber outright: rumours from rival climbers, the Dining car and the Noble; the Entity is only vague. No build is locked out: every guardian stays beatable, and one that flies or burrows must come within reach to strike (`scripts/guardian_lessons.gd`).
- **Slow growth:** renown, essence and other rewards must grow slowly. Old climbers ended up with huge banked essence and the game lost its progression; never hand out large amounts fast.
- **Pronouns:** the player picks pronouns at character creation, and every character who speaks of the climber (the Entity, rivals, the Noble, the Makers, everyone) uses them.
- Story and the purpose of the towers are still to be written by the owner; keep names and text in data so they're easy to change.
- The game is mechanically dense: every new mechanic or screen should come with the Entity explaining it (a first-time moment, a "How does it work?" dialogue topic, and hover/hold help for its buttons), and navigation should be easy to understand without reading the README.

## Six Towers LITE (`lite/`)
- A separate, small Godot project for a six-year-old who can't read (see `lite/README.md`). Keep it separate from the full game: no files shared, only copies of sounds made by `python3 lite/tools/copy_sounds.py` (rerun it when LITE plays a new sound).
- Pictures first (everything must be playable without reading), with a few short, simple words to help a child learning to read: in the Andika font, all in `TEXT` in `lite/scripts/data.gd`, read aloud by a natural voice (Kokoro clips made by `python3 lite/tools/make_voice.py`; rerun it after adding or changing any spoken words, then import; the test fails if a spoken line has no clip). The wordless guide and a pointing finger explain new things instead of the Entity's text. Six floors a climb, each a room from a text map (`lite/scripts/floor_map.gd`) with an easy puzzle, portals and sometimes a secret treasure room; the first climb's Regard after floor 3. The owner wants it challenging (his son finished the first version in 20 minutes): hearts carry between floors, falling ends the climb, monsters and beasts get hard, towers unlock in order, marks grow to 5 stars with an upgrade pick (one of two) at each, essence flows into body parts by play style and favourite weapon, and treasure to wear is found in secret rooms and from beasts. Still fair and readable (clear warnings before every attack), with a much simpler magic system than the full game. Keep its touch controls working.
- It looks like the full game: its climber, monsters, beasts, rooms and buttons are copies of the full game's drawing code (table in `lite/README.md`), drawn bigger (2.2x, beasts 1.6x), brighter and a little more cartoony than the full game (punchier colours and thicker outlines: the TOON_ numbers in `lite/scripts/palette.gd`). When the full game's drawings change, copy the change over if LITE should follow. LITE has the full game's roll, parry, swappable weapons (sword, dagger, hammer, bow), climber screen and appearance choices, all kinder and simpler; monsters get a little harder each floor up.
- Checks, from the `lite` folder: `godot --headless --editor --quit`, then `godot --headless -s tests/test.gd`. Run them too when LITE changes.
- `.github/workflows/web.yml` tests it and publishes it beside the full game: https://raphu88.github.io/sixfold-tower-godot/lite/

## Project
- Everything visual is drawn in code (no art files). Colours live in `scripts/palette.gd` (world) and `scripts/ui.gd` (menus and HUD). Volume comes from the shading toolkit (`scripts/shade.gd`, used through `draw_util.gd` Batch helpers like `ball`, `poly`, `stroke`, `box`, `bar`, `contact`): use it for new drawings so everything is lit the same way (top-left), and keep warnings, text and HUD bars flat.
- Sounds are built from CC0 packs by `tools/build_audio.py`; see `CREDITS.md` and the README. Only use CC0 assets, except fonts: the owner allows SIL Open Font License (OFL) fonts, credited in `CREDITS.md` with their license file shipped alongside. One more exception, for Six Towers LITE only: its spoken voice clips are recorded with the Kokoro voice (Apache 2.0), which the owner approved; credited in `lite/CREDITS.md`.
- See README.md for the design, controls and file layout.
