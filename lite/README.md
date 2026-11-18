# Six Towers LITE

A much simpler Sixfold Tower for young children who can't read yet. It's its own small Godot project (this `lite/` folder), separate from the full game. It loads nothing from it, but it **looks like it**: its climber, monsters, beasts, rooms and buttons are drawn by copies of the full game's own drawing code (see **Looking like the full game**), and its sounds are copies of the full game's.

## Playing it

**https://raphu88.github.io/sixfold-tower-godot/lite/** (built automatically every time `main` changes, beside the full game).

On an Android phone, open the link in Chrome, then **⋮ → Add to Home screen** (or **Install app**). It gets its own icon called *Six Towers LITE*, and opens fullscreen and sideways like an app.

To open it in Godot: in the project manager choose **Import**, pick `lite/project.godot`, then press **F5**.

## How it plays

- **Pictures first, with a few simple words.** Everything can be played from the pictures, colours and sounds alone, but short, simple words go with them to help a child learning to read: each tower's name, the climber saying *Pick a tower!* (and *Hooray!* after a win), *Floor 2*, *Go up!*, *The door is open!*, *A portal!*, *A secret!*, *You found a treasure!*, *Careful! One heart left!*, *Oh no! Back home.*, *The Gryphon sees you!*, *You got a mark!*, *Pick one!*, *Stronger!*, *Hit*, *Home*, *Play*, *OK*, an easy name on each magic (*Zap*, *Wave*, *Shield*, *Stomp*, *Fire*, *Blades*) and on each treasure (*Dragon Armor*, *Ghost Boots*...). They're in **Andika**, a font made by SIL for children learning to read (its letters are shaped the way they're taught, like a single-storey *a* and *g*).
- **A natural voice reads every word aloud** as it appears, so the child hears each word while seeing it: clips recorded with **Kokoro**, an open-source voice (Apache 2.0), by `tools/make_voice.py` into `assets/voice` (`scripts/voice.gd` lists them). Each pointer is spoken the first time too (*Move with your thumb!*, *Tap the sword to hit!*, *Roll away!*, *Parry to block!*, *Step on all the stones!*, *Hit the lever!*, *Light all the fires!*...). Tap the speech bubble to hear it again; a tower's name is read when it's picked. A line without a clip falls back to the device's own voice. All the words are in `TEXT` in `scripts/data.gd` (set `SPEAK` to false there to turn the voice off).
- **The home screen**: six towers, each showing its beast and its name; tap one to climb it. **The towers open one after another**: a locked tower has a padlock, and tapping it says which beast to beat first. Top left, **You** (or tap the climber) opens the climber screen.
- **The climber screen**, like the full game's Climber's Book: a page in a leather and gilt edge with four ribbon tabs, each a picture and a word.
  - **Marks**: the climber with their marks glowing, and a slot for each body part (*Hand*, *Legs*, *Heart*, *Head*, *Neck*, *Back*): its magic's picture and word, its stars (up to five) and a bar toward the next star. A part without a mark shows a picture of what fills it (a sword, a dagger, a hammer, a roll, a parry or a heart), a ring for how full it is, and *Next mark* on the fullest.
  - **Weapons**: the four weapons, each with stars for how strong and lightning for how quick; tap one to hold it. The **favorite** (the one used most) has a heart.
  - **Look**: how the climber looks, with all of the full game's choices in its five groups (*Face*, *Hair*, *Body*, *Cloak*, *More*): tap a group, then the arrows beside each choice (*Skin*, *Hair color*, *Shirt*, *Cloak shape*...); the die picks a whole new look. The climber is drawn this way everywhere: home, the climb, the Regard. A crown sits on each tower whose beast you've beaten, and the magic it gave you shows under it. The climber stands below, big, with every mark glowing on its body and a badge beside it for each magic (its picture, its stars, and a little bar toward the next star).
  - **Treasure**: everything there is to find (a *?* for each still hidden, and how many are found). Tap a treasure to wear it, or to take it off; what's worn shows on the climber everywhere.
- **The guide.** The Entity, without words: a small glowing light that floats to what to do next (the tower to try, then the stair once a room is clear). The first time, a pointing finger shows the joystick, then the sword button, then the magic button, then the gems that pick a magic.
- **Few controls, each a picture with a word.** The full game's glassy buttons, kept small so the room stays in view in fullscreen (a touch still counts a little outside each one). A floating joystick anywhere on the left. On the right, round the attack button (its picture and word are the weapon in hand; hold it to keep going; it aims at the nearest monster by itself): **Roll**, **Parry**, **Swap** (its picture is the next weapon), and once you have a mark the magic button, whose ring fills up as it recharges, with a gem for each mark above it to pick which magic. Top right: fullscreen and home (home pauses: the house goes home, the play button carries on).
  - Keyboard: arrows or WASD walk; Space, J or Enter attack; L or Ctrl roll; K or Q parry; E magic; Tab or X swap; 1-6 pick a magic; Esc home. On the home screen, left and right pick a tower and Enter climbs it. Controller: left stick, A attack, B roll, left trigger parry, Y magic, X swap, shoulder buttons pick a magic.
- **Roll and parry**, kinder than the full game's. **Roll** is a quick dodge the way you're going: nothing can hurt you while you roll. **Parry** opens a short window (half a second, much wider than the full game's): a monster's lunge into it is blocked and the monster is stunned and thrown back, and a thrown orb flies back at the nearest monster and hurts it. A block makes Parry ready again at once. The first time a monster gets ready to strike near you, a finger points at Roll (and later at Parry).
- **Four weapons**, after the full game's, with its sounds: the **Sword** (all-round), the **Dagger** (quick, short), the **Hammer** (slow, strong, wide; it stuns) and the **Bow** (shoots arrows from afar). Swap between them in a climb or pick one on the climber screen. On floor 2 a finger points at Swap the first time.
- **Fair fights that get hard.** Five hearts, and they carry from floor to floor (each stair gives two back; monsters only now and then leave one). Monsters turn red, with a red patch where the attack will land, before every lunge or throw; their throws are slow glowing orbs, gone once a room is won. Each floor up they get tougher: by floor 5 there are twice as many, with twice the health, a third faster and a quarter quicker to strike (never under half a second of warning); from floor 3 throwers throw three at once, and from floor 4 each room has an elite (bigger and much tougher). Monsters out of sight find their way round the walls. **Losing every heart ends the climb** (*Oh no! Back home.*): what was banked at stairs is kept, what was carried is lost. All the numbers are in `scripts/data.gd` (`FLOORS`, `HARDER`, `ELITE`, `HEARTS_AT_STAIR`...).
- **A climb is six floors**, each a room laid out from a map (`scripts/floor_map.gd`), with walls and pillars to fight round and an **easy puzzle** that opens the gate to the stair: step on every glowing stone, hit the lever, or light every brazier (an arrow lights one too). The guide points at the puzzle once the room is clear, then at the stair. **Portals** come in pairs: step in one and come out of the other (on some floors they're the only way across). Now and then a **cracked wall** hides a secret: hit it and a golden portal opens to a little **treasure room** with a chest; its portal leads back. Five floors of the tower's monsters, then its **beast** on floor 6: it charges, throws a ring of orbs, and leaps onto where you stood (the spot is marked: get out of the red circle); at half health it gets fierce and calls its monsters. Later towers' beasts are tougher. Dots at the top show the floors and the beast's crown; a bar shows the beast's health.
- **The magic, based on the full game.** Monsters leave sparkles of essence in their tower's colour that fly into you. Step on the stair and they pour into you: part into your marks by colour, and part into your body by **play style**: what each body part did on that floor (weapon hits fill the hand for the sword, the back for the dagger, the neck for the hammer and the head for the bow; rolls fill the legs, parries the head, taking hits and using magic the heart), with your **favorite weapon** counting extra. A marked part grows its mark; an empty part fills up, and **the next mark goes on the fullest part**. Your first climb starts with no magic: after floor 3 the tower's beast takes notice (**the Regard**: a star on that floor's dot shows it's coming), its mark flies onto your body, and the climb goes on to floor 6 with your new magic. Each mark is one magic, from a bond of the full game, and grows from one star to **five** across many climbs. **Each new star brings an upgrade: pick one of two** (big pictures, read aloud): *Stronger!* or *Faster!*, then *Bigger!* or a special of that magic's own (*Zap stuns!*, *Double zap!*, *Wave heals!*, *Freezing wave!*, *Bounce back!*, *Spiky shield!*, *Safe stomp!*, *Double stomp!*, *Burning fire!*, *Triple fire!*, *Flying blades!*, *Long blades!*). Beating a beast gives you its mark (or grows it), puts its crown on its tower, opens the next tower, and the first time, leaves its own treasure.
- **Treasure to wear**, drawn like the full game's gear: helmets, armour, shoulder pads, gloves, boots, pendants, capes and a backpack (30 pieces) and four weapon finishes (gold, ice, fire, shadow). Each beast leaves its own piece; the rest are in the chests of secret treasure rooms. A found treasure is worn at once (its picture and name pop up); change what's worn on the climber screen.

| Tower | Mark on | Magic (its button) | Based on |
| --- | --- | --- | --- |
| Gryphon (Air) | legs | Chain Lightning (*Zap*): zaps the nearest monsters, one after another | Stormcaller |
| Kraken (Water) | heart | Tidal Surge (*Wave*): a wave that hurts and pushes back everything near you, and washes away throws | Tidecaller |
| Wyvern (Iron) | back | Barrier (*Shield*): a bubble that stops every hit for a few seconds | Warden |
| Manticore (Stone) | throat | Quake (*Stomp*): hurts and stuns everything near you, and stops their attacks | Sandshaper |
| Firebird (Fire) | brow | Fireball (*Fire*): flies at the nearest monster and bursts | Flamewing |
| Chimera (Blade) | hand | Conjured Blades (*Blades*): blades circle you and cut what they touch | Blade Forger |

## Looking like the full game

LITE copies the full game's drawing code, adapted (no gear, no lighting, no game systems), so it looks like the full game, only bigger (characters are drawn 2.2 times the full game's size, beasts 1.6), brighter and a little more cartoony: every colour is made more saturated and brighter (the dark outlines stay dark) and the outlines are drawn 1.6 times as thick. Those are four numbers at the end of `scripts/palette.gd` (`TOON_SAT`, `TOON_BRIGHT`, `TOON_LIFT`, `TOON_LINE`; all at 1.0 and 0 it would look just like the full game), and the rooms' extra lightness is `BRIGHTER` in `scripts/room_art.gd`.

| LITE file | Copied from the full game's |
| --- | --- |
| `scripts/palette.gd`, `scripts/draw_util.gd` | `scripts/palette.gd`, `scripts/draw_util.gd` (unchanged) |
| `scripts/creatures.gd` | the monsters' and beasts' drawing in `scripts/enemy.gd` and `scripts/towers/*.gd` |
| `scripts/look.gd` | `scripts/appearance.gd` (the climber's look and its options) |
| `scripts/gear_look.gd` | `scripts/gear_look.gd` (worn gear: helms, armour, gloves, boots, amulets, cloaks, the pack; its rarity edges), plus LITE's shoulder slot and weapon finishes |
| `scripts/climber_art.gd` | the climber's drawing in `scripts/player.gd` (body, weapon in hand, swing, roll) and the front figure |
| `scripts/room_art.gd` | the floor, walls, pillars, torches and stair in `scripts/room.gd` (plus LITE's own wall blocks, gates, plates, levers, braziers, portals, cracked walls and chests, in the same style) |
| `scripts/ui.gd` | the glassy buttons in `scripts/ui.gd`, and a page like the Climber's Book |

They're copies, not links: a change to the full game's drawings doesn't reach LITE until it's copied over again.

## Changing it

Every number, monster, word, name and colour is in `scripts/data.gd`: hearts, speeds, how many monsters on each floor (`FLOORS`), how much harder each floor gets (`HARDER`, `ELITE`), which floor brings the Regard (`REGARD_FLOOR`), the beasts (`BEAST_HP`, `BEAST_FURY`, `SLAM_RADIUS`), the weapons (`WEAPONS`), roll and parry, how much each magic does, how much essence a star needs (`STAR_AT`), the upgrades (`upgrade_choices`, `UPGRADE_INFO`), play style (`DEED_PART`, `BODY_SHARE`, `FAVOURITE_BONUS`), the treasures (`TREASURES`) and every word on screen (`TEXT`, `PART_WORDS`, `LOOK_WORDS`).

**Rooms** are text maps in `scripts/floor_map.gd` (`LAYOUTS`): 30 characters across, 16 rows, one character per tile (the key is at the top of that file: `#` wall, `S` start, `E` stair, `G` gate, `o` plate, `L` lever, `F` brazier, `P`/`p` and `Q`/`q` portal pairs, `X` cracked wall, `C` chest). Copy one, change it, and give it the floors it's for ("from" and "to"); the test checks every map (its size, that the stair can be reached, that a gate's puzzle is needed).

**The voice**: after adding or changing words, run `python3 lite/tools/make_voice.py` from the repository's folder (see the top of that file for what it needs); it records only the new lines. The save is `user://save.json`.

| Path | What it is |
| --- | --- |
| `project.godot` | The project (its name, the main scene, the screen) |
| `export_presets.cfg` | The web export (an installable app: fullscreen, sideways) |
| `icon.png` | The app icon and loading picture, drawn in code by `tools/make_icon.gd` |
| `scenes/game.tscn` | The only scene (`scripts/game.gd`) |
| `scripts/game.gd` | Switches between the home screen and a climb; plays the sounds |
| `scripts/data.gd` | Towers, monsters, magic and every number |
| `scripts/home.gd` | The home screen: the six towers, the climber with its marks, the guide, the You button |
| `scripts/climber_screen.gd` | The climber screen: Marks, Weapons, Look and Treasure |
| `scripts/climb.gd` | A climb: the rooms, the climber, monsters, beasts, magic and upgrades, puzzles, portals, the secret room, sparkles, the stair and the Regard |
| `scripts/floor_map.gd` | The rooms' maps (`LAYOUTS`), walls, sight, monsters' way round walls, and each floor's puzzle, portals, secret and chest |
| `scripts/upgrade_pick.gd` | The pick of one of two upgrades when a mark gains a star |
| `scripts/gear_look.gd` | The treasure worn, drawn like the full game's gear (copied from its `scripts/gear_look.gd`), and the weapon finishes |
| `scripts/voice.gd`, `assets/voice` | The natural voice's clips (written by `tools/make_voice.py`) |
| `tools/make_voice.py`, `tools/list_phrases.gd` | Record every spoken line with Kokoro |
| `scripts/pad.gd` | The controls: the joystick, the buttons, keys and controller |
| `scripts/art.gd` | LITE's own pictures: the button and screen icons, hearts, stars, the guide, and the words |
| `scripts/creatures.gd`, `scripts/climber_art.gd`, `scripts/look.gd`, `scripts/room_art.gd`, `scripts/ui.gd`, `scripts/palette.gd`, `scripts/draw_util.gd` | The full game's drawings, copied (see **Looking like the full game**) |
| `scripts/save.gd` | The save: marks and their upgrades, beasts beaten, play style, treasure found and worn, the weapon, the look, banking and the Regard |
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
godot --headless --editor --quit        # import (after adding or changing sounds or voice clips)
godot --headless -s tests/test.gd       # the test
```

A simple bot plays a whole first climb (finding its way round walls, solving the puzzles by going where the guide points, hopping between portal islands; it can't be hurt, as being hurt has its own checks): the Regard after floor 3, the beast on floor 6 and its treasure. Then the test checks every room map and its puzzle, portals, the secret treasure room and its chest, losing the run, hearts carrying over, harder monsters and elites, the beasts' health, fury and leap (a roll gets away), mark upgrades and their effects, play style choosing where marks go, roll and parry, the weapons, walls blocking sight and throws, tower locks, the climber screen (look and treasure), the save, the words, the voice clips and every sound.
