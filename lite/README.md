# Six Towers LITE

A much simpler Sixfold Tower for young children who can't read yet. It's its own small Godot project (this `lite/` folder), separate from the full game. It loads nothing from it, but it **looks like it**: its climber, monsters, beasts, rooms and buttons are drawn by copies of the full game's own drawing code (see **Looking like the full game**), and its sounds are copies of the full game's.

## Playing it

**https://raphu88.github.io/sixfold-tower-godot/lite/** (built automatically every time `main` changes, beside the full game).

On an Android phone, open the link in Chrome, then **⋮ → Add to Home screen** (or **Install app**). It gets its own icon called *Six Towers LITE*, and opens fullscreen and sideways like an app.

To open it in Godot: in the project manager choose **Import**, pick `lite/project.godot`, then press **F5**.

## How it plays

- **Pictures first, with a few simple words.** Everything can be played from the pictures, colours and sounds alone, but short, simple words go with them to help a child learning to read: each tower's name, the climber saying *Pick a tower!* (and *Hooray!* after a win), *Floor 2*, *Go up!*, *Oops! Try again!*, *The Gryphon sees you!*, *You got a mark!*, *Your magic grows!*, *Hit*, *Home*, *Play*, *OK*, and an easy name on each magic (*Zap*, *Wave*, *Shield*, *Stomp*, *Fire*, *Blades*). They're in **Andika**, a font made by SIL for children learning to read (its letters are shaped the way they're taught, like a single-storey *a* and *g*). On a device with a voice the words are **read aloud** as they appear, so the child hears each word while seeing it; tap the speech bubble to hear it again, and a tower's name is read when it's picked. All the words are in `TEXT` in `scripts/data.gd` (set `SPEAK` to false there to turn the voice off).
- **The home screen**: six towers, each showing its beast and its name; tap one to climb it. Top left, **You** (or tap the climber) opens the climber screen.
- **The climber screen**, like the full game's Climber's Book: a page in a leather and gilt edge with three ribbon tabs, each a picture and a word.
  - **Marks**: the climber with their marks glowing, and a slot for each body part (*Hand*, *Legs*, *Heart*, *Head*, *Neck*, *Back*): its magic's picture and word, its stars and a bar toward the next star, or a *?* where no mark has come yet.
  - **Weapons**: the four weapons, each with stars for how strong and lightning for how quick; tap one to hold it.
  - **Look**: how the climber looks, with all of the full game's choices in its five groups (*Face*, *Hair*, *Body*, *Cloak*, *More*): tap a group, then the arrows beside each choice (*Skin*, *Hair color*, *Shirt*, *Cloak shape*...); the die picks a whole new look. The climber is drawn this way everywhere: home, the climb, the Regard. A crown sits on each tower whose beast you've beaten, and the magic it gave you shows under it. The climber stands below, big, with every mark glowing on its body and a badge beside it for each magic (its picture, its stars, and a little bar toward the next star).
- **The guide.** The Entity, without words: a small glowing light that floats to what to do next (the tower to try, then the stair once a room is clear). The first time, a pointing finger shows the joystick, then the sword button, then the magic button, then the gems that pick a magic.
- **Few controls, each a picture with a word.** The full game's glassy buttons, kept small so the room stays in view in fullscreen (a touch still counts a little outside each one). A floating joystick anywhere on the left. On the right, round the attack button (its picture and word are the weapon in hand; hold it to keep going; it aims at the nearest monster by itself): **Roll**, **Parry**, **Swap** (its picture is the next weapon), and once you have a mark the magic button, whose ring fills up as it recharges, with a gem for each mark above it to pick which magic. Top right: fullscreen and home (home pauses: the house goes home, the play button carries on).
  - Keyboard: arrows or WASD walk; Space, J or Enter attack; L or Ctrl roll; K or Q parry; E magic; Tab or X swap; 1-6 pick a magic; Esc home. On the home screen, left and right pick a tower and Enter climbs it. Controller: left stick, A attack, B roll, left trigger parry, Y magic, X swap, shoulder buttons pick a magic.
- **Roll and parry**, kinder than the full game's. **Roll** is a quick dodge the way you're going: nothing can hurt you while you roll. **Parry** opens a short window (half a second, much wider than the full game's): a monster's lunge into it is blocked and the monster is stunned and thrown back, and a thrown orb flies back at the nearest monster and hurts it. A block makes Parry ready again at once. The first time a monster gets ready to strike near you, a finger points at Roll (and later at Parry).
- **Four weapons**, after the full game's, with its sounds: the **Sword** (all-round), the **Dagger** (quick, short), the **Hammer** (slow, strong, wide; it stuns) and the **Bow** (shoots arrows from afar). Swap between them in a climb or pick one on the climber screen. On floor 2 a finger points at Swap the first time.
- **Gentle fights, harder as you climb.** Five hearts. Monsters turn red, with a red patch where the attack will land, before every lunge or throw; their throws are slow glowing orbs, gone once a room is won. On each floor up they get a little tougher: by floor 5 they have about 70% more health, move a quarter faster and wind up a fifth quicker (still over half a second of warning). All of it is `HARDER` in `scripts/data.gd`. After a hit you blink and can't be hurt for a moment. Monsters sometimes leave a heart. Hearts refill on every floor, and losing them all just starts the room again: nothing is lost.
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

## Looking like the full game

LITE copies the full game's drawing code, adapted (no gear, no lighting, no game systems), so it looks the same, only bigger (characters are drawn 2.2 times the full game's size, beasts 1.6) and a little brighter:

| LITE file | Copied from the full game's |
| --- | --- |
| `scripts/palette.gd`, `scripts/draw_util.gd` | `scripts/palette.gd`, `scripts/draw_util.gd` (unchanged) |
| `scripts/creatures.gd` | the monsters' and beasts' drawing in `scripts/enemy.gd` and `scripts/towers/*.gd` |
| `scripts/look.gd` | `scripts/appearance.gd` (the climber's look and its options), without worn gear |
| `scripts/climber_art.gd` | the climber's drawing in `scripts/player.gd` (body, weapon in hand, swing, roll) and the front figure |
| `scripts/room_art.gd` | the floor, walls, pillars, torches and stair in `scripts/room.gd` |
| `scripts/ui.gd` | the glassy buttons in `scripts/ui.gd`, and a page like the Climber's Book |

They're copies, not links: a change to the full game's drawings doesn't reach LITE until it's copied over again.

## Changing it

Every number, monster, word, name and colour is in `scripts/data.gd`: hearts, speeds, how many monsters on each floor (`FLOORS`), how much harder each floor gets (`HARDER`), which floor brings the Regard (`REGARD_FLOOR`), the beasts' health, the weapons (`WEAPONS`), roll and parry, how much each magic does, how much essence a star needs, and every word on screen (`TEXT`, `PART_WORDS`, `LOOK_WORDS`). The save is `user://save.json`.

| Path | What it is |
| --- | --- |
| `project.godot` | The project (its name, the main scene, the screen) |
| `export_presets.cfg` | The web export (an installable app: fullscreen, sideways) |
| `icon.png` | The app icon and loading picture, drawn in code by `tools/make_icon.gd` |
| `scenes/game.tscn` | The only scene (`scripts/game.gd`) |
| `scripts/game.gd` | Switches between the home screen and a climb; plays the sounds |
| `scripts/data.gd` | Towers, monsters, magic and every number |
| `scripts/home.gd` | The home screen: the six towers, the climber with its marks, the guide, the You button |
| `scripts/climber_screen.gd` | The climber screen: Marks, Weapons and Look |
| `scripts/climb.gd` | A climb: the rooms, the climber, monsters, beasts, magic, sparkles, the stair and the Regard |
| `scripts/pad.gd` | The controls: the joystick, the buttons, keys and controller |
| `scripts/art.gd` | LITE's own pictures: the button and screen icons, hearts, stars, the guide, and the words |
| `scripts/creatures.gd`, `scripts/climber_art.gd`, `scripts/look.gd`, `scripts/room_art.gd`, `scripts/ui.gd`, `scripts/palette.gd`, `scripts/draw_util.gd` | The full game's drawings, copied (see **Looking like the full game**) |
| `scripts/save.gd` | The save: marks, beasts beaten, the weapon, the look, banking and the Regard |
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

The test plays a whole six-floor climb with a simple bot (walk to the nearest monster and keep swinging, then take the stair): the Regard after floor 3, the beast on floor 6. Then it checks a later climb's beast mark, the words, every magic, roll and parry (a blocked lunge, a throw sent back), the four weapons and Swap, harder floors, the climber screen (weapons, look), banking, falling, the save and every sound.
