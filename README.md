# Sixfold Tower (Godot prototype)

A first playable test of the new magic system: **bonds** marked on body parts that fill through combat. The design lives in the *Sixfold Tower: Magic Redesign* doc; this prototype tests one question: **does filling bonds through combat feel good?**

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard version; no .NET needed).
2. In the Godot project manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5** to play.

Everything is drawn in code, so there are no art assets to import.

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Sprint | Shift |
| Roll | Space |
| Strike / hold to draw the bow | Left click or J |
| Switch weapon | 1 Fists, 2 Sword, 3 Bow, or the mouse wheel |
| Parry | Right click or K |
| Cast the hand bond (Stormcaller) | Q |
| Cast the legs bond (Windwalker) | E |
| Change both bonds' step (testing only) | [ and ] |
| Restart | R |

## What's in this build

- **A clumsy base climber.** Slow walk, slow swings, a short roll that costs a lot of stamina.
- **Stormcaller on the hand.** Fills when your strikes land. *Chain Lightning* leaps between up to 4 foes (6 from step 3, and it stuns). Passive *Static*: striking a charged foe arcs to another.
- **Windwalker on the legs.** Fills when you roll through an attack. *Gale Lift* throws foes in front of you into the air, helpless for 1.5 seconds (a wider cone from step 3). Body: your roll becomes a long, cheap wind dash. Passive *Featherweight*: airborne foes take 50% more damage from your strikes.
- **Overdraw.** Cast without enough essence and the spell still fires, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and travel less. Burns heal when the room is cleared (standing in for reaching a stair).
- **Marks and motes on the body.** Each bond shows as a sigil that grows lines with its step, circled by motes as its essence fills.
- **Three weapons.** *Fists*: quick, short-reaching jabs on a cheap 4-hit chain ending in a heavy hook. *Sword*: a 3-hit chain ending in a slow, heavy finisher. *Bow*: hold to draw (you walk slowly while drawing and stamina stops recovering), release to loose. Damage and speed grow with the draw, and a full draw (a soft tick and ring tell you) pierces through foes. A quick tap fires a weak shot; rolling or getting hit drops the arrow. Weapons are plain data in `scripts/weapons.gd`.
- **Solid bodies.** The climber and monsters can't share space; overlapping bodies are pushed apart, and heavier ones (the knight) give way less. Foes lifted by Gale Lift pass over everyone.
- **Combat feel.** Strikes chain into a 3-hit combo that costs stamina, with the third swing a heavy finisher; each swing lunges a little and locks your aim. Presses made up to 0.2 s early are buffered. Every hit gets a short hit-pause, sparks, knockback and a squash, and heavier hits get more of each. Hitting a staggered foe is a **riposte** for 2.5x damage. A clean **parry** flashes, rings, refunds some stamina and **reflects arrows** back at monsters. Rolls leave afterimages for exactly as long as you're invulnerable, and a landed dodge shows a ring. Getting hurt knocks you back, flashes the screen edge red and interrupts your swing or cast.
- **Sound generated in code.** Every sound effect is synthesised at startup (`scripts/audio.gd`), so there are no audio files. Each sound fades in and out to avoid clicks, goes through a soft limiter, and has its own level in `LEVELS` at the top of the file for easy rebalancing. The knight's wind-up and the archer's aim lock each play a warning tone.
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
| `scripts/bond.gd` | A bond: essence, steps, burning, and the two spells |
| `scripts/enemy.gd` | Slime, archer and knight |
| `scripts/projectile.gd` | Enemy arrows |
| `scripts/fx.gd` | Floating text, lightning and wind cones |
| `scripts/hud.gd` | Health, stamina, bond bars and help text |
| `scripts/controls.gd` | Input actions, set up in code |
| `scripts/audio.gd` | Sound effects, synthesised in code |
| `scripts/weapons.gd` | Weapon definitions: fists, sword, bow |
| `tests/smoke_test.gd` | Headless test that drives every action |

## Testing

`tests/smoke_test.gd` loads the room and drives the climber through every action (combo, riposte, parry, arrow reflect, roll, both casts, overdraw, getting hurt, death, clearing the room) and checks the results:

```bash
godot --headless -s tests/smoke_test.gd
```
