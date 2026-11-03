# Sixfold Tower (Godot prototype)

A first playable test of the new magic system: **bonds** marked on body parts that fill through combat. The design lives in the *Sixfold Tower: Magic Redesign* doc; this prototype tests one question: **does filling bonds through combat feel good?**

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard version; no .NET needed).
2. In the Godot project manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5** to play.

Everything visual is drawn in code, so there are no art assets. Sounds and music are recorded CC0 effects in `assets/audio` (see [CREDITS.md](CREDITS.md)).

## Playing on a phone

A web version is built automatically every time `main` changes: **https://raphu88.github.io/sixfold-tower-godot/**. Open it in your phone's browser, turn the phone sideways, and tap the **[ ]** button for fullscreen. It also works in a desktop browser.

On a touchscreen the whole game is drawn 1.5x bigger so it reads on a small screen, and on-screen controls appear as soon as you touch it: a joystick under your left thumb, and buttons on the right for attack (hold to draw the bow), roll, parry, both spells and weapon swap. Aiming is automatic: you face the nearest monster in reach, or the way you're moving.

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Sprint | Shift |
| Roll | Space |
| Strike / hold to draw the bow | Left click or J |
| Switch weapon | 1 Fists, 2 Sword, 3 Bow, or the mouse wheel |
| Parry | Right click or K |
| Cast your marks (hand, legs, heart, brow) | Q, E, F, C |
| Change both bonds' step (testing only) | [ and ] |
| Restart | R |
| New climber (forget all marks and start the first climb again; press twice to confirm) | N, or the New button on a phone |
| Music on/off | M |
| Show/hide controls | H |

## Marks, essence and the Regard

- **Your first climb is bondless.** You start clumsy, with weapons only. Climb 3 floors.
- **Essence:** monsters leave essence when they fall (slimes Water, archers Air, knights Iron). It flies into you and is **banked at the next stair**. Fall before the stair and the unbanked essence is lost.
- **Your body soaks it up** through what each part does: the **hand** from weapon strikes, the **legs** from rolling through attacks, the **heart** from taking hits and surviving, the **brow** from parries. Unmarked parts glow faintly as they soak.
- **The Regard:** at the top of your first climb the tower's beast takes notice. Your most-used body part takes its first **mark**, and the essence you gathered most decides which bond it is. If you fall on the first climb you're still regarded, but the mark is **faint**: weaker (75% power, 25% dearer) until it has soaked up 80 more essence.
- **Growth across climbs:** banked essence strengthens every mark you carry (essence of a mark's own kind counts double), up to step 5. Your marks and their growth are saved.
- **Later marks:** an unmarked body part that soaks up enough over your climbs takes a new mark at a stair, shaped by the essence you've banked since your last one.
- **Bonds so far:** Stormcaller (Air, Chain Lightning), Windwalker (Air, Gale Lift), Tidecaller (Water, Tidal Surge: a wave that hurls foes away), Blade Forger (Iron, Conjured Blades: a fan of piercing blades). Cast with Q (hand), E (legs), F (heart) and C (brow); on a phone, each mark gets its own button.
- **Burns** (from overdrawing a mark) last until the next stair: hand strikes weaker, legs rolls costlier, heart caps your health lower, brow shortens your parry window.

## The climb

Each floor is one room. Clear it and the **stair** at the top of the room opens: walk onto it to climb. Taking the stair is a rest: burns heal, you recover a third of your health and all your stamina. Floors above the first get a random layout of stone pillars, which block movement and arrows, and a group of monsters bought from a budget that grows each floor; monsters also get tougher (`scripts/floors.gd`). Falling ends the run and sends you back to floor 1. Your best floor is saved.

## What's in this build

- **The base climber.** Started very clumsy; now a bit tougher: 140 health, quicker on its feet, faster stamina recovery, cheaper rolls, a slightly wider parry window, and a longer grace period after being hit so a crowd can't chain-hit you.
- **Stormcaller on the hand.** Fills when your strikes land. *Chain Lightning* leaps between up to 4 foes (6 from step 3, and it stuns). Passive *Static*: striking a charged foe arcs to another.
- **Windwalker on the legs.** Fills when you roll through an attack. *Gale Lift* throws foes in front of you into the air, helpless for 1.5 seconds (a wider cone from step 3). Body: your roll becomes a long, cheap wind dash. Passive *Featherweight*: airborne foes take 50% more damage from your strikes.
- **Overdraw.** Cast without enough essence and the spell still fires, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and travel less. Burns heal when the room is cleared (standing in for reaching a stair).
- **Marks and motes on the body.** Each bond shows as a sigil that grows lines with its step, circled by motes as its essence fills.
- **Three weapons.** *Fists*: quick, short-reaching jabs on a cheap 4-hit chain ending in a heavy hook. *Sword*: a 3-hit chain ending in a slow, heavy finisher. *Bow*: hold to draw (you walk slowly while drawing and stamina stops recovering), release to loose. Damage and speed grow with the draw, and a full draw (a soft tick and ring tell you) pierces through foes. A quick tap fires a weak shot; rolling or getting hit drops the arrow. Weapons are plain data in `scripts/weapons.gd`.
- **Solid bodies.** The climber and monsters can't share space; overlapping bodies are pushed apart, and heavier ones (the knight) give way less. Foes lifted by Gale Lift pass over everyone.
- **Readable fights.** Every monster attack follows one rhythm: a wind-up, then a **glint** (a white star and a "ting") exactly 0.25 s before the blow lands, then a recovery where the monster is open. Parry on the glint and it always works; parry a beat after the glint for a **perfect parry** (longer stagger, more stamina back, bigger flash). The parry window is about a third of a second, turns you toward the attacker (or an incoming arrow) so aiming can't make it miss, and can cancel the tail of a swing. Only two monsters attack at a time; the rest circle and wait their turn. Slimes and archers flinch when hit (so aggressive play works on them); knights keep winding up through your hits, so parry, riposte or roll against them. The knight slashes up close and lunges from further out; the slime creeps up and pounces (touching it is harmless).
- **Combat feel.** Strikes chain into a 3-hit combo that costs stamina, with the third swing a heavy finisher; each swing lunges a little and locks your aim. Presses made up to 0.2 s early are buffered. Every hit gets a short hit-pause, sparks, knockback and a squash, and heavier hits get more of each. Hitting a staggered foe is a **riposte** for 2.5x damage. A clean **parry** flashes, rings, refunds some stamina and **reflects arrows** back at monsters. Rolls leave afterimages for exactly as long as you're invulnerable, and a landed dodge shows a ring. Getting hurt knocks you back, flashes the screen edge red and interrupts your swing or cast.
- **The look.** A dim tower room: flagstone floor with moss and cracks, a brick north wall, flickering torches that cast real light (plus a soft glow around the climber), drifting dust and embers, and a vignette. Characters are outlined and shaded: a hooded climber with a visible weapon, a wobbling slime whose eyes follow you, a hooded archer with bow and quiver, and an armoured knight with shield and plume who raises his sword to wind up. Telegraphs, swing trails and health bars ignore the darkness so they always read. The camera follows the climber, zoomed in. Spells, parries, crits and burns flash real light; slain monsters burst into debris.
- **Sound.** Recorded CC0 effects, layered by `tools/build_audio.py` (sword hits are a chop plus a punch body plus a low thump, parries are a metal clang with a ringing tail). Hits sound different on each monster (armour clanks, slime squelches), the archer's bow creaks before it fires and the knight's armour rattles as he winds up, and there are footsteps, per-weapon equip sounds, and a gong when the room is clear. Looping music and tower ambience play underneath; M toggles them. The knight's wind-up and the archer's aim lock each play a warning tone.
- **Three telegraphed monsters.** A slime that hops at you, an archer that locks its aim before firing (a red line), and a knight that winds up a lunge (a filling red bar). Parry the knight's lunge to stagger it.

## What to look for when testing

- Does the base climber feel clumsy but fair?
- Does rolling through attacks to fill the legs feel rewarding or tedious?
- Is overdrawing tempting in a tight spot, and does the burn feel like a real cost?
- Can you read every enemy attack before it lands?

## Project layout

| Path | What it is |
| --- | --- |
| `scenes/main.tscn` | The only scene; everything is built from `main.gd` |
| `scripts/main.gd` | The room, spawning, restart, effects hooks |
| `scripts/player.gd` | The climber: movement, roll, strike, parry, casting, overdraw |
| `scripts/bond.gd` | A bond: essence, steps, burning, and the spell code |
| `scripts/bonds.gd` | Bond definitions: spells and what each step changes |
| `scripts/essence.gd` | Essence kinds and what each monster drops |
| `scripts/profile.gd` | What carries over between climbs: marks, growth, soak, the save |
| `scripts/floors.gd` | Builds each floor: pillar layouts, monster groups, toughness |
| `scripts/enemy.gd` | Slime, archer and knight |
| `scripts/projectile.gd` | Enemy arrows |
| `scripts/fx.gd` | Floating text, lightning and wind cones |
| `scripts/hud.gd` | Health, stamina, bond bars and help text |
| `scripts/controls.gd` | Input actions, set up in code |
| `scripts/touch.gd` | On-screen touch controls |
| `export_presets.cfg` | Web export settings |
| `.github/workflows/web.yml` | Builds and publishes the web version |
| `scripts/audio.gd` | Plays sound effects (random variants) and music |
| `scripts/sound_bank.gd` | Generated list of sound files |
| `scripts/room.gd` | The room's look: floor, walls, torches, dust |
| `scripts/palette.gd` | All the game's colours |
| `scripts/draw_util.gd` | Helpers for drawing outlined, shaded shapes |
| `assets/audio/` | Built sound effects and music |
| `tools/fetch_audio_sources.sh` | Downloads the CC0 source sound packs |
| `tools/build_audio.py` | Builds `assets/audio` from the source packs |
| `scripts/weapons.gd` | Weapon definitions: fists, sword, bow |
| `tests/smoke_test.gd` | Headless test that drives every action |

## Testing

`tests/smoke_test.gd` loads the room and drives the climber through every action (combo, riposte, parry, arrow reflect, roll, both casts, overdraw, getting hurt, death, clearing the room) and checks the results:

```bash
godot --headless -s tests/smoke_test.gd
```

## Rebuilding the sounds

The finished sounds are committed, so you only need this to change them. Each game sound is defined in `SOUNDS` at the top of `tools/build_audio.py` (which source clips to layer, how loud). Needs Python 3 with numpy, and ffmpeg.

```bash
tools/fetch_audio_sources.sh
```

```bash
python3 tools/build_audio.py
```
