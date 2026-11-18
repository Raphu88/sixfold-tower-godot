# Six Towers LITE

A much simpler Sixfold Tower for young children who can't read yet. It's its own small Godot project (this `lite/` folder), separate from the full game: it shares nothing with it but copies of a few sounds.

## Playing it

**https://raphu88.github.io/sixfold-tower-godot/lite/** (built automatically every time `main` changes, beside the full game).

On an Android phone, open the link in Chrome, then **⋮ → Add to Home screen** (or **Install app**). It gets its own icon called *Six Towers LITE*, and opens fullscreen and sideways like an app.

To open it in Godot: in the project manager choose **Import**, pick `lite/project.godot`, then press **F5**.

## How it plays

- **Pictures first, with a few simple words.** Everything can be played from the pictures, colours and sounds alone, but short, simple words go with them to help a child learning to read: each tower's name, the climber saying *Pick a tower!* (and *Hooray!* after a win), *Floor 2*, *Go up!*, *Oops! Try again!*, *The Gryphon sees you!*, *You got a mark!*, *Your magic grows!*, *Hit*, *Home*, *Play*, *OK*, and an easy name on each magic (*Zap*, *Wave*, *Shield*, *Stomp*, *Fire*, *Blades*). They're in **Andika**, a font made by SIL for children learning to read (its letters are shaped the way they're taught, like a single-storey *a* and *g*). On a device with a voice the words are **read aloud** as they appear, so the child hears each word while seeing it; tap the speech bubble to hear it again, and a tower's name is read when it's picked. All the words are in `TEXT` in `scripts/data.gd` (set `SPEAK` to false there to turn the voice off).
- **The home screen** is the only menu: six towers, each showing its beast and its name; tap one to climb it. A crown sits on each tower whose beast you've beaten, and the magic it gave you shows under it. The climber stands below, big, with every mark glowing on its body and a badge beside it for each magic (its picture, its stars, and a little bar toward the next star).
- **The guide.** The Entity, without words: a small glowing light that floats to what to do next (the tower to try, then the stair once a room is clear). The first time, a pointing finger shows the joystick, then the sword button, then the magic button, then the gems that pick a magic.
- **Big, few controls.** A floating joystick anywhere on the left, a huge sword button on the right (hold it to keep swinging; it aims at the nearest monster by itself), and, once you have a mark, a magic button whose ring fills up as it recharges, with a gem for each mark above it to pick which magic. Top right: fullscreen and home (home pauses: the house goes home, the play button carries on). Keyboard: arrows or WASD, Space or J to swing, K or E for magic, 1-6 to pick a magic, Esc for home; on the home screen, left and right pick a tower and Enter climbs it. A controller works too.
- **Gentle fights.** Five hearts. Monsters are slow and flash red, with a red patch where the attack will land, before every lunge or throw; their throws are slow glowing orbs, gone once a room is won. After a hit you blink and can't be hurt for a moment. Monsters sometimes leave a heart. Hearts refill on every floor, and losing them all just starts the room again: nothing is lost.
- **A climb is six floors:** five rooms of the tower's monsters (3, 4, 4, 5 and 5 of them), then its beast on floor 6 (which calls two helpers at half health). Dots at the top show the floors and the beast's crown; a bar shows the beast's health.
- **The magic, based on the full game.** Monsters leave sparkles of essence in their tower's colour that fly into you. Clear a room and a stair appears; step on it and the sparkles pour into your marks (each colour into the mark of that colour; a colour with no mark of its own grows every mark a little). Your first climb starts with no magic: after floor 3 the tower's beast takes notice (**the Regard**: a star on that floor's dot shows it's coming), its mark flies onto your body, and the climb goes on to floor 6 with your new magic. Sparkles banked before then pour into that first mark. Each mark is one magic, from a bond of the full game, and grows from one star to three across climbs (stronger, bigger, more targets). Beating a beast gives you its mark, or grows it if you have it already, and puts its crown on its tower.

| Tower | Mark on | Magic (its button) | Based on |
| --- | --- | --- | --- |
| Gryphon (Air) | legs | Chain Lightning (*Zap*): zaps the nearest monsters, one after another | Stormcaller |
| Kraken (Water) | heart | Tidal Surge (*Wave*): a wave that hurts and pushes back everything near you, and washes away throws | Tidecaller |
| Wyvern (Iron) | back | Barrier (*Shield*): a bubble that stops every hit for a few seconds | Warden |
| Manticore (Stone) | throat | Quake (*Stomp*): hurts and stuns everything near you, and stops their attacks | Sandshaper |
| Firebird (Fire) | brow | Fireball (*Fire*): flies at the nearest monster and bursts | Flamewing |
| Chimera (Blade) | hand | Conjured Blades (*Blades*): blades circle you and cut what they touch | Blade Forger |

## Changing it

Every number, monster, word, name and colour is in `scripts/data.gd`: hearts, speeds, how many monsters on each floor (`FLOORS`), which floor brings the Regard (`REGARD_FLOOR`), the beasts' health, how much each magic does, how much essence a star needs, and every word on screen (`TEXT`). The save is `user://save.json`.

| Path | What it is |
| --- | --- |
| `project.godot` | The project (its name, the main scene, the screen) |
| `export_presets.cfg` | The web export (an installable app: fullscreen, sideways) |
| `icon.png` | The app icon and loading picture, drawn in code by `tools/make_icon.gd` |
| `scenes/game.tscn` | The only scene (`scripts/game.gd`) |
| `scripts/game.gd` | Switches between the home screen and a climb; plays the sounds |
| `scripts/data.gd` | Towers, monsters, magic and every number |
| `scripts/home.gd` | The home screen: the six towers, the climber with its marks, the guide |
| `scripts/climb.gd` | A climb: the rooms, the climber, monsters, beasts, magic, sparkles, the stair and the Regard |
| `scripts/pad.gd` | The controls: the joystick, the big buttons, keys and controller |
| `scripts/art.gd` | The drawings: the climber with its marks, monsters, beasts and the picture icons |
| `scripts/save.gd` | The save: marks, beasts beaten, banking and the Regard |
| `scripts/audio.gd` | Plays the sounds, music and each place's ambience |
| `scripts/sounds.gd` | The list of sound files (written by `tools/copy_sounds.py`) |
| `assets/audio` | Copies of the full game's sounds that LITE plays (see `CREDITS.md`) |
| `tools/copy_sounds.py` | Copies the sounds LITE plays from the full game and writes `scripts/sounds.gd` |
| `tools/make_icon.gd` | Draws `icon.png` |
| `assets/fonts/andika` | Andika Bold, the words' font (SIL Open Font License, with its `OFL.txt`) |
| `tests/test.gd` | The test |

**Sounds.** LITE keeps copies of only the sounds it plays. After changing which sounds it plays (a new monster, a new magic), or after rebuilding the full game's sounds, run from the repository's folder: `python3 lite/tools/copy_sounds.py`.

## Testing

From the `lite` folder:

```bash
godot --headless --editor --quit        # import (after adding or changing sounds)
godot --headless -s tests/test.gd       # the test
```

The test plays a whole six-floor climb with a simple bot (walk to the nearest monster and keep swinging, then take the stair): the Regard after floor 3, the beast on floor 6. Then it checks a later climb's beast mark, the words, every magic, banking, falling, the save and every sound.
