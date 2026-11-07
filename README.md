# Sixfold Tower (Godot prototype)

A first playable test of the new magic system: **bonds** marked on body parts that fill through combat. The design lives in the *Sixfold Tower: Magic Redesign* doc; this prototype tests one question: **does filling bonds through combat feel good?**

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard version; no .NET needed).
2. In the Godot project manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5** to play.

Everything visual is drawn in code, so there are no art assets. Sounds and music are recorded CC0 effects in `assets/audio` (see [CREDITS.md](CREDITS.md)).

## Playing on a phone

A web version is built automatically every time `main` changes: **https://raphu88.github.io/sixfold-tower-godot/**. Open it in your phone's browser, turn the phone sideways, and tap the **[ ]** button for fullscreen. It also works in a desktop browser.

On a touchscreen the whole game is drawn 1.5x bigger so it reads on a small screen, and on-screen controls appear as soon as you touch it: a joystick under your left thumb (past a light tilt you walk at full speed; there is no sprint), and buttons on the right for attack (hold to draw a bow), roll, parry, your marks' spells and weapon swap, a **Take** button that appears only while you stand on gear you could swap for, an **Item** button at the bottom (it shows the item it will use and how many you have; the small arrow beside it picks the next item), and a Menu button at the top right. Aiming is automatic: you face the nearest monster in reach, or the way you're moving.

## Controls

| Action | Keys | Controller (Xbox / PlayStation) |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick |
| Aim | The mouse | Right stick; let go and you aim at the nearest monster, or the way you move |
| Roll | Space | B / Circle |
| Jump (over chasms and burning floor) | Z, or the Jump button on a phone | A / Cross |
| Strike / hold to draw a bow / fire the crossbow | Left click or J | RT / R2 |
| Parry | Right click or K | LT / L2 |
| Switch weapon | 1 Fists, 2 your melee weapon, 3 your ranged weapon, or the mouse wheel | RB / R1 or d-pad right (next), d-pad left (previous) |
| Take the gear you stand on (your old piece is dropped) | Y, or the Take button on a phone | Y / Triangle |
| Cast your marks (hand, legs, heart, brow, throat, back); hold to pick a spell | Q, E, F, C, X, V | Hold LB / L1, then X, A, B, Y, RB, RT (Square, Cross, Circle, Triangle, R1, R2) |
| Use your item | G, or the Item button on a phone | X / Square |
| Next item | T, or the small arrow button beside Item on a phone | D-pad down |
| Choose a tower, camp card or heirloom | 1 to 6, or arrows and Enter, click, or tap the card | D-pad or left stick, then A / Cross |
| Menu (pause, settings, controls, dev tools) | Esc or P, or the Menu button on a phone | Start / Options |
| Restart (hold, so a stray press can't end a climb; once fallen a press is enough) | Hold R | Hold View / Share |
| New climber (forget all marks and start the first climb again; press twice to confirm) | N, or New climber in the menu | New climber in the menu |
| Music on/off | M | Music slider in Settings |
| Show/hide controls | H | D-pad up |

**Controllers.** Plug in (or pair) an Xbox, PlayStation or similar controller and just press a button. The prompts on screen (the controls panel, the gear card's "take it", the card screens, "press ... to begin your next climb") switch to controller buttons as soon as you use it, with PlayStation names on a PlayStation pad, and back to keys the moment you touch the keyboard or mouse (or to touch wording on a phone). Holding LB (L1) turns the face buttons, RB and RT into your six marks' casts; hold the cast button to open the spell ring and point with the right stick. The button layout lives in `scripts/controls.gd` (`PAD` and `PAD_CAST`), read by `scripts/pad.gd`.

## Weapons and armor

Every weapon and suit of armor here is plain, common gear (enchanted weapons, armor and trinkets will come later). Their names, text and numbers live in `scripts/weapons.gd` (weapons) and `scripts/gear.gd` (armor, drops and carrying), so they're easy to change. Each is drawn in code on the climber and has its own HUD icon.

**Carrying.** Gear lasts one climb. You carry four things: **1 fists** (always), **2 a melee weapon**, **3 a ranged weapon**, and **one suit of armor**. Every climb starts with a **sword**, a **shortbow** and **no armor**, except where you hold an heirloom (below). The HUD shows the three weapon slots and the armor slot with their names; the **Body** page in the menu lists your gear with its key numbers.

**Finding gear.** Slain monsters (not beasts) rarely drop a piece (4%), likelier one that suits them: knights favour chain mail, plate, swords, maces and greatswords; archers bows, crossbows and leather; smiths hammers, maces and armor; and so on (`FAVOUR` in `gear.gd`). A side room's essence cache sometimes holds a piece too (35%), and the camp offers a piece of gear as a fourth card beside its three items. Gear lies on the floor with its name. Walk over it with an empty slot (only armor starts empty) and you take it; otherwise a card compares it with what you carry (better numbers in green, worse in red), and **Y** (or **Take** on a phone) swaps: your old piece is dropped where you stand, so you can change your mind.

**Melee weapons** are combo chains; every chain ends in a heavy finisher. Damage is a multiple of the base strike (8), as with the sword.

| Weapon | Class | What it's like | Hits | Stamina per chain | Reach |
| --- | --- | --- | --- | --- | --- |
| Fists | light | quick jabs on a cheap 4-hit chain ending in a heavy hook | 4 to 10 | 42 | 30 to 36 |
| Dagger | light | fast, short and cheap; a backstab deals 2x instead of 1.5x | 6 to 11 | 43 | 36 to 40 |
| Sword | medium | the all-rounder: 3 hits, a slow heavy finisher | 8 to 14 | 58 | 46 to 56 |
| Axe | medium | slower and harder than the sword, with a wider hacking arc | 10 to 18 | 70 | 48 to 56 |
| Mace | medium | every blow counts as heavy against poise: it rocks monsters out of their wind-ups and cracks shells | 9 to 16 | 70 | 44 to 50 |
| Spear | medium | long, narrow thrusts: strike from beyond a monster's reach, but miss what's beside you | 8 to 13 | 54 | 74 to 86 |
| Greatsword | heavy | two-handed: slow, huge sweeping arcs that catch a crowd; hungry for stamina | 13 to 21 | 94 | 60 to 66 |
| War Hammer | heavy | the slowest and heaviest, 2 hits: every blow rocks, and the finisher staggers (half as long on a beast) | 16 to 24 | 74 | 52 to 56 |

**Ranged weapons:**

| Weapon | What it's like |
| --- | --- |
| Shortbow | hold to draw (0.75 s), release to loose: 5 to 20 damage; a full draw pierces. You walk at 45% while drawing. |
| Longbow | a slower draw (1.1 s) for harder, farther arrows (6 to 30 damage), but you barely walk while drawing (28%) |
| Crossbow | press to fire a fast, strong bolt at once (24 damage; it rocks what it hits), then a 1.1 s reload you can't skip. You can walk (a little slower) while it reloads; the slot and the phone's attack button fill back up. |

Weapon classes matter elsewhere too: Blade Forger's **Weapon Memory** throws more, smaller knives with a light weapon, fewer and harder blades with a heavy one, and fast darts with any bow or crossbow. Hunter's spells and Hawk's Eye work with every bow and the crossbow.

**Armor** cuts the damage of attacks that land (after parries, the Warden's barrier and the like); poison and burning floor tick past it. Heavier suits weigh on you: rolls cost more stamina and carry you less far, stamina refills slower, and you walk a little slower. Each suit shows on the climber, from a quilted vest to steel pauldrons and a helm.

| Armor | Damage taken off | Roll cost | Roll reach | Stamina refill | Walk |
| --- | --- | --- | --- | --- | --- |
| None | 0% | normal | normal | normal | normal |
| Padded Armor | 8% | +5% | -2% | -2% | normal |
| Leather Armor | 15% | +12% | -5% | -5% | -2% |
| Chain Mail | 25% | +30% | -12% | -13% | -5% |
| Plate Armor | 35% | +55% | -24% | -25% | -10% |

**Heirlooms.** Survive a climb (beat its beast, or reach the Regard on the first climb without falling) and, after the victory screen, you choose **one** piece you carried to keep as an **heirloom**: a card for your melee weapon, your ranged weapon and your armor (any already kept are left out), and one to keep nothing new. Every later climb starts with your heirlooms in their slots instead of the sword, shortbow or no armor. Each slot holds one heirloom; keeping another piece for the same slot replaces it. The slots are **melee**, **ranged** and **chest** (armor); **helm, gloves, legs, boots, cloak, amulet, rings and backpack** are planned for gear that doesn't exist yet. The **Body** page lists your heirlooms and the planned slots. Starting a new climber forgets them. Slots and text live in `HEIRLOOM_SLOTS` and `HEIRLOOM_TEXT` in `scripts/gear.gd`; heirlooms are saved with your profile.

The dev tools have a **Gear** row: a button for every weapon and armor, to try them at once.

## Items and camps

**Items** (`scripts/items.gd`, where their names, text and numbers live) are carried through the climb and lost when it ends. You can carry up to 3 of each kind. **G** (or the Item button) uses the selected item and **T** (or the small arrow) picks the next; the HUD shows what you carry beside the weapons, with counts, and the selected one outlined in gold. An item that would do nothing (a draught at full health, a vial with full marks) isn't used up.

| Item | What it does |
| --- | --- |
| Healing Draught | heals 40 health over 1.5 seconds |
| Cleansing Tonic | cures poison, heals every burned body part, and a little health |
| Essence Vial | fills every mark with essence |
| Smoke Bomb | a cloud of smoke around you: monsters inside lose track of you (beasts don't) |

Every climb starts with one Healing Draught. Slain monsters (not beasts) sometimes leave an item (8%); walk over it to pick it up.

**Camps.** On a five-floor climb, floor 3's stair leads first to a **camp**: the open room with a campfire and no monsters. You rest fully (all health and stamina, burns and poison healed), then choose one of four cards (keys 1 to 4, the arrows and Enter, the d-pad and A, click, or tap): three items, or a piece of gear (taking it leaves your old piece by the fire). Then take the stair on to floor 4. Each climb has one camp; the bondless first climb has none.

- **Surgeon's Steady Hands:** healing items heal 30% more and work faster.
- **Rune Artist's Runesmith:** after taking an item at a camp, a Rune Artist also chooses a rune for their gear (Sharpness, Warding or Swiftness, as with Inscribe) that lasts the rest of the climb, the beast included, or crafts one more item. Casting Inscribe still changes the rune for one floor.

## Essence density (attributes)

Each essence type is an attribute: Air is Agility, Blade Strength, Stone Vitality, Iron Will, Fire Intellect and Water Spirit. Every bit of essence you bank at a stair settles in you as **density**, by type and in the body parts that earned it (split by what each part did that floor), and it's kept between climbs. Each type gives a small passive bonus that grows with diminishing returns up to 12%: Air move speed, Blade strike damage, Stone health, Iron stamina recovery, Fire spell power, Water how fast your marks fill. The **Body** page in the menu shows your six body parts with their marks and the essence settled in each, and your density and bonus for every type.

## Menus and the dev tool

The game opens on a **title screen** that covers the whole game: a tower drawn in code against a night sky, with lit windows, a moon, mist and drifting motes in the six essence colours (`scripts/title.gd`; the name, tagline and footer text are in its `TEXT` list). Its buttons are **Continue** (or **Begin your first climb** for a new climber), **Body**, **Settings**, **Dev tools** and **New climber** (only once you have marks to lose), with a line showing your marks and best floor. Arrow keys and Enter, a controller (d-pad or left stick to move, A to press), the mouse, or a tap all work; Esc does nothing there. The focused button has a gold outline, and the first one is focused when a page opens. Pages opened from the title show over its backdrop and **Back** returns to it. Leaving the title takes you to the tower choice. During a climb, **Esc** or **P** (or **Start** on a controller, or **Menu** on a phone) pauses and opens the **pause menu**: Resume, Restart this climb, Settings, Controls, Dev tools, New climber, Quit to title. **Settings** has music and sound volume, screen shake, and the controls panel; they're saved. On any page **Esc** or **B** (Circle) goes back a page, and from the pause menu back to the game. The **Controls** page lists every key and controller button side by side.

The **dev tools** page is for testing (`scripts/menu.gd`, with the actions in `main.gd`):
- **Marks:** give any bond to any body part with the arrows, and set its step from 1 to 5. Changes are saved, and giving a mark ends the bondless first climb. Fill essence, or clear every mark.
- **Climb:** move to another tower, change floor, or go straight to the tower's beast.
- **Practice a beast:** fight any of the six beasts at once, at full health with full marks.
- **Spawn a monster:** any monster or beast, near you.
- **Gear:** give yourself any weapon or armor (it replaces what's in that slot).
- **Cheats:** no dying (a killing blow leaves you at 1 health), heal, clear the room, and show traps (outlines every trap and its reach, hidden ones too).

## Towers

Every climb starts by choosing a tower (keys 1 to 6, click, or tap a card). Each tower has its own beast, essence, monster mix and look (`scripts/towers.gd`):

| Tower | Essence | Monsters | Look |
| --- | --- | --- | --- |
| The Gryphon's Tower | Air | archers, bats and thunderlings; the Gryphon on floor 5 | cold, blue stone and pale torches |
| The Kraken's Tower | Water | slimes, lurkers and shellbacks; the Kraken on floor 5 | damp, teal stone and green-white torches |
| The Wyvern's Tower | Iron | knights, cinders and smiths; the Wyvern on floor 5 (the hardest) | hot forge-red stone and orange torches |
| The Manticore's Tower | Stone | scorplings and rams; the Manticore on floor 5 | sun-baked sandstone and warm torches |
| The Firebird's Tower | Fire | wisps and bloomcaps, and chasms to jump; the Firebird on floor 5 | pale, sunlit stone and gold torches |
| The Chimera's Tower | Blade | thornhounds and mongrels; the Chimera on floor 5 | the Thornwild: mossy green stone and pale green torches |

**The Gryphon's tower has a summit.** On floor 5 the Gryphon itself waits, alone. It rakes with its talons up close (a red wedge, parryable), dives on you from range (it locks onto where you stood when it glints; the landing can't be parried, so roll out of the red circle), and throws a fan of feathers (parryable, and a Crosswind turns them back). It can't be lifted or interrupted, only staggered, and at half health it calls two bats. Beat it, take the stair, and the climb is complete.

**The Kraken's tower has a summit too.** On floor 5 the Kraken waits. It sweeps a tentacle across a wide wedge in front of it (parryable), slams three spots at once with one landing where you stand (can't be parried: roll out of the red circles), and spits a fan of ink (parryable). At half health it calls two lurkers.

**The Wyvern waits atop its tower.** On floor 5 it sweeps its tail across a wedge in front of it (parryable), breathes fire down a narrow cone (can't be parried: roll or step aside) that leaves the floor burning, and sprays a fan of embers (parryable). At half health it calls two cinders.

**The Chimera waits atop its tower.** Three beasts in one: the lion mauls up close (parryable) and breathes fire down a narrow cone (can't be parried: roll or step aside); the goat charges in a straight line (parryable; it's stunned if it charges into a wall); the serpent tail spits three poisoned spikes (parryable). At half health it calls two thornhounds.

**The Chimera's monsters:** the **thornhound** is a fast pack hound that circles, glints and leaps at you with a bite (parryable). The **mongrel** is a patchwork beast that alternates a bite up close (parryable) with a fan of thrown quills (parryable).

**Jumping and chasms.** Everyone can jump (Z): a short hop that costs a little stamina and carries you over chasms and burning floor (it isn't a dodge: attacks still hit you in the air). In the Firebird's tower, floors above the first have **chasms**: walk or get knocked into one and you fall, losing some health and climbing back out where you last stood. Walking monsters can't enter chasms; flying ones (bats, cinders, wisps and the beasts that fly) cross them.

**The Firebird waits atop its tower.** On floor 5, in an open hall, it swoops straight through you (parryable), leaving fire in its wake; calls down a firestorm on four spots, one where you stand (can't be parried: get out of the circles, or jump); and throws a fan of embers (parryable). The first time it falls it burns to ashes, can't be hurt for two seconds, and rises again at 40% health. At half health it calls two wisps.

**The Firebird's monsters:** the **wisp** flickers around you, glints and darts straight through where you stood (parryable), leaving a little fire. The **bloomcap** is a rooted fire-fungus: it glints, locks onto where you stand and lobs burning spores that land a moment later (can't be parried: step out of the circle or jump); the ground keeps burning.

**The Manticore waits atop its tower.** On floor 5 it swipes with its claws (a red wedge, parryable), fires a volley of three poisoned tail spikes (parryable), and roars, bursting out around itself (can't be parried: roll through it). At half health it calls two scorplings.

**The Manticore's monsters:** the **scorpling** scuttles up, glints and stings (parryable); a sting that lands **poisons** you: 2 health every half second for a few seconds (the stair's rest cures it). The **ram** lowers its horns, glints and charges in a straight line (parryable). A ram that charges into a wall or pillar is stunned, so letting it miss is an opening.

**The Wyvern's monsters:** the **cinder** is a living ember that flits at range, glints and spits a burning ember (parryable). The **smith** plods up and brings its hammer down in front of it (parryable, but it hits hard), leaving the floor there burning for a few seconds. **Burning floor** costs 4 health every half second you stand in it; rolling through is free.

**The Kraken's monsters:** the **lurker** swims under the water, where only ripples and two eyes show and it can't be hit. It rises near you, glints and lunges (parryable), then stays up for a moment: that's your chance. The **shellback** plods toward you behind a shell that blocks most of a blow from the front (heavy blows crack it), and bashes up close; get behind it.

**The Gryphon's monsters:** the **bat** circles you, then glints and swoops straight through where you stood (parryable). The **thunderling** walks up, stops and sparks, then bursts into a ring of lightning: it can't be parried, so step out of the ring or roll through it.

Every kill also yields 1.5 essence of the tower's own kind, so the tower you choose is how you steer which bonds you'll form. The tower's beast is the one who regards you at the top of your first climb.

## Marks, essence and the Regard

- **Six body parts**, one for each of the six towers: hand, legs, heart, brow, throat and back. Each holds one mark. A **backstab** (striking a foe that faces away from you, because it has committed to an attack or you rolled behind it) deals 50% more damage.

- **Your first climb is bondless.** You start clumsy, with weapons only. Climb 3 floors.
- **Essence:** monsters leave essence when they fall: Air, Water, Iron, Fire or Stone (slimes Water, archers Air, knights Iron, cinders and the Wyvern Fire). It flies into you and is **banked at the next stair**. Fall before the stair and the unbanked essence is lost.
- **Your body soaks it up** through what each part does: the **hand** from weapon strikes (+0.5 per hit), the **legs** from rolling through attacks (+4), the **heart** from taking hits and surviving (+4), the **brow** from parries (+6, perfect +9), the **throat** when one swing or spell hits several foes (+2 for each foe past the first), the **back** from backstabs (+3) and finishing blows (+2). Unmarked parts glow faintly as they soak, and the **"Your mark is forming"** panel shows each part's soak, the leader, and which bond it would be right now.
- **Where and which:** your play style decides the body part (the one you used most), and the essence you gathered decides the bond. No bond has a home body part. When two bonds share an essence (say, the three Air bonds), the way you fought this climb breaks the tie: lots of parrying leans Hunter, lots of striking Stormcaller, lots of dodging Windwalker.
- **The Regard:** at the top of your first climb the tower's beast takes notice. Your most-used body part takes its first **mark**, and the essence you gathered most decides which bond it is. If you fall on the first climb you're still regarded, but the mark is **faint**: weaker (75% power, 25% dearer) until it has soaked up 80 more essence.
- **Growth across climbs:** banked essence strengthens every mark you carry (essence of a mark's own kind counts double), up to step 5. Your marks and their growth are saved.
- **Later marks:** an unmarked body part that soaks up enough over your climbs takes a new mark at a stair, shaped by the essence you've banked since your last one.
- **Each bond is a kit:** a **Body** (an upgrade to a basic action), a **Passive**, and **spells learned as it grows** (new spells at steps 1, 2, 4 and 5; step 3 changes the first). **Tap** a mark's key to cast its selected spell; **hold** it to open a ring of its spells (time slows), point at one and let go to cast it. On a phone, hold the mark's button and slide.
- **The Gryphon's bonds (complete):**
  - **Stormcaller** (Air, hand). Body: Quick Nerves (strikes and rolls recover faster). Passive: Static. Spells: Chain Lightning, Overcharge (a charged foe's death throws lightning at everything near it), Chain Lightning changed (more leaps, stuns), Lightning Rod (chains bend through a planted rod), Thunderhead (chains leap twice as often for 8 seconds).
  - **Windwalker** (Air, legs). Body: Wind Dash. Passive: Featherweight. Spells: Gale Lift, Crosswind (a wind wall that turns arrows back), Gale Lift changed (wide cone), Downdraft (slams airborne foes into the ground), Eye of the Storm (a cyclone that holds foes aloft).
  - **Hunter** (Air, brow). Body: Keen Eyes (see farther in the dark and spot hidden traps). Passive: Quarry (the last foe you struck is always marked, with an arrow at the screen edge when it's out of sight). Spells: Piercing Shot, Track (reveals foes and where they're heading), Piercing Shot changed (a charged, triple-damage shot), Hawk's Eye (arrows deal double damage for 5 seconds), Rain of Arrows.
- **The Kraken's bonds (complete):**
  - **Tidecaller** (Water, legs). Body: Waterborn (full speed through the Kraken's standing water, which slows everyone else). Passive: Undercurrent (foes you drive into a wall are stunned). Spells: Tidal Surge, Riptide (pull a line of foes to you), Tidal Surge changed (an aimed wave that travels forward), Carry (a wave sweeps foes along until they break against a wall), Maelstrom (a whirlpool drags foes to its centre).
  - **Warden** (Water, brow). Body: Heavy Frame (keep holding parry to block). Passive: Steadfast (no knockback or interruption while your barrier holds). Spells: Barrier (a shell that absorbs damage), Absorb (store the hits you take in the barrier), Barrier changed (it bursts with what it absorbed when it breaks), Challenge (nearby foes must come at you and take 50% more damage), Unbreakable (4 seconds of no damage, but no attacking).
  - **Deepcaller** (Water, heart). Body: Deep Lungs (stamina refills faster). Passive: Pressure (badly hurt foes near you slow down). Spells: Undertow (drain up to 3 foes and heal), Anchor (tether a foe to you), Undertow changed (5 foes), Siphon (drain essence to refill your marks), Drink Deep (a drain that grows stronger the longer it holds).
- **The Wyvern's bonds (complete):**
  - **Blade Forger** (Iron). Body: Long Edge (melee strikes reach farther). Passive: Weapon Memory (conjured blades copy the weapon you hold: more, smaller knives with fists or a dagger; fewer, harder blades with a greatsword or war hammer; fast, harder darts with a bow or crossbow). Spells: Conjured Blades, Recall (blades fly out and come back, cutting again on the way), Conjured Blades changed (five blades), Bladeward (blades orbit you for 6 seconds, cutting anything close), Thousand Edges (a storm of blades toward your aim).
  - **Flameblade** (Fire). Body: Hot Blood (strike chains never slow down; even the finisher recovers fast). Passive: Heat (each strike in a row heats your weapon, up to half again as much damage; it fades if you stop striking; shown as an arc around you). Spells: Kindle Blade (your weapon burns for 6 seconds: extra damage and heat builds twice as fast), Flame Lash (a wave of fire), Kindle Blade changed (lasts as long as you keep landing strikes), Searing Parry (kindles your weapon; while it burns, a parry explodes against the attacker), Overheat (release all your heat in one huge blow).
  - **Rune Artist** (Iron). Body: Steady Mind (every spell from every bond winds up 30% faster). Passive: Runesmith (at a camp, also inscribe a rune on your gear for the rest of the climb, or craft one more item). Spells: Rune Trap (a rune on the floor that detonates under a foe; up to 3), Inscribe (a rune on your gear for the floor: sharpness, warding or swiftness, changing each cast), Linked Runes (step 3: setting off one rune sets off them all), Ward Circle (foes can't enter it for 5 seconds), Grand Sigil (inside it, your spells cost nothing for 6 seconds).
- **The Manticore's bonds (complete):**
  - **Sandshaper** (Stone). Body: Rooted Stance (you can't be knocked back or slowed by water). Passive: Shifting Sands (foes walking up to you slow in their last few steps; never an attack already under way). Spells: Quake (hurts foes around you and leaves rubble that slows them), Sand Wall (a wall across your aim that blocks foes and their shots for 5 seconds; you can walk through your own walls), Quake changed (also throws up a ring of low walls), Sinkhole (a pit at your aim swallows a small foe, or traps a large one), Fault Line (a long split in the floor foes can't cross for 8 seconds).
  - **Venomist** (Stone). Body: Venom Glands (weapon strikes add a stack of poison). Passive: Toxin Build (poison stacks up to 12, and each stack makes it last longer; green drops show the stacks). Spells: Venom Spit, Toxic Cloud (poisons foes standing in it), Venom Spit changed (pierces), Neurotoxin (your next hit on a poisoned foe paralyzes it for 2 seconds), Virulence (every poisoned foe takes all its remaining poison at once).
  - **Ashwalker** (Fire). Body: Smokeborn (your light reaches farther). Passive: Unseen Strike (striking a foe that hasn't noticed you yet, or has lost you, deals triple damage; a "?" shows over foes that have lost you). Spells: Smoke Veil (foes inside the smoke lose track of you), Afterimage (an ash copy of you that nearby foes go after), Smoke Veil changed (cast again to ignite the cloud), Vanish (unseen until you strike or 4 seconds pass), Ashfall (for 10 seconds, foes lose you once you're out of reach). Beasts never lose track of you.
- **The Firebird's bonds (complete):**
  - **Flame Contractor** (Fire). Body: Casting Stride (you can walk while a spell winds up). Passive: Kindled (foes your fire kills leave burning ground that burns foes, not you). Spells: Fireball (explodes on impact), Fire Wall (a line of your own burning ground), Fireball changed (charged: a longer wind-up and a much bigger explosion), Cluster Blast (splits into three explosions), Meteor (a long wind-up, then a great explosion at your aim).
  - **Flamewing** (Fire). Body: Phoenix Glide (hold jump to glide). Passive: Fireproof (burning floor doesn't hurt you). Spells: Heat Aura (burns foes near you while it drains its mark; cast again to turn it off), Wingburst (release the aura's built-up heat as burning wings), Heat Aura changed (grows hotter the longer it burns), Warmth (for 10 seconds your aura also restores your health; it will strengthen creatures and allies once those exist), Firebird Form (for 8 seconds the aura doubles and Wingburst is free).
  - **Rekindler** (Fire). Body: Stubborn Heart (below a third of your health you move and recover faster). Passive: Last Ember (once per floor a killing blow leaves you burning at 1 health for 3 seconds; land a hit to stay standing). Spells: Rekindle (lose health over 5 seconds, then regain twice that if you kept fighting), Desperation (the lower your health, the harder and faster you strike), Rekindle changed (foes near you burn too), Pyre Oath (for 10 seconds a killing blow makes you explode instead), Phoenix Heart (for 10 seconds you can't drop below 1 health).
- **The Chimera's bonds (complete):**
  - **Covenant** (Blade). Body: Pack Stride (faster with one of your creatures nearby). Passive: Kinship (monsters of a kind in your pact book are slower to notice you). Spells: Bind and Call (aimed at a monster below a quarter of its health it binds that kind into your **pact book**, kept between climbs; otherwise it calls the next creature of your retinue, the first three kinds in the book, to fight beside you for 30 seconds; a spirit familiar until you've bound one), Command (aimed at a foe, every creature attacks it; aimed at no one, they guard you), Bind and Call changed (each Call brings two), Exchange (swap places with your nearest creature), Grand Call (every creature in your book at once for 12 seconds; drains the mark). Never more than three creatures out at once (Grand Call aside); creatures are as strong as your mark's step, can be killed, and leave when you take the stair. Monsters fight a creature that's closer than you.
  - **Grafter** (Blade). Body: Adaptive Flesh (each graft strengthens its body part's basic action: hand strikes +20%, legs rolls cheaper and longer, heart takes 15% less damage, brow parry window +25%, throat stamina +25%, back backstabs hit harder). Passive: Grafting (slain monsters sometimes leave a graft; walk over it to bind it to its body part, one per part, for the rest of the climb). Spells: Graft Burst (hit everything around you, harder for each graft), Mimic (your newest graft's monster trick, once), Graft Burst changed (each graft adds its own effect), Shed (cast off a graft to heal its part's burn in a burst), Chimera Form (every graft's power doubled for 10 seconds).
  - **Surgeon** (Blade). Body: Steady Hands (healing heals more, including the stair's rest and healing items, which also work faster). Passive: Diagnosis (you see every foe's health and a note on what it's weak to). Spells: Sever (cripples a foe: it can't run or charge), Mend (heals you and nearby creatures, cures poison), Sever changed (a crippled foe is disarmed instead: it can't attack), Transfer (move your burns and poison onto a foe), Amputate (a foe below half health is crippled and disarmed for the rest of the fight).
- **Overdraw:** casting without enough essence still works, but the cast is weaker (70%) and the body part **burns**. Overdraw a burned mark again and it **tears**: the missing essence comes out of your health, so spamming spells can kill you.
- **Burns** last until the next stair: hand strikes weaker, legs rolls costlier, heart caps your health lower, brow shortens your parry window, throat slows stamina recovery, back loses the backstab bonus.

## The climb

**Rooms and corridors.** Floor 1 and the beast's floor are single open rooms. Every floor in between is a larger area of 3 to 5 rooms joined by three-tile-wide corridors (`Floors.rooms_floor`). You start in the first room and the stair is in the last; the monsters wait in the rooms beyond the first. A monster stays put until it sees you (or you come close, or it's hit), then rouses its neighbours and finds its way to you around the walls (a path grid, `AStarGrid2D`). Monsters can't attack what they can't see, and walls stop every shot. Each room has its own torch, and stone door posts frame every opening where a corridor meets a room. Bigger rooms have **cover**: short low walls (one tile thick, two to four long) that block movement, sight and shots like any wall, so you can break line of sight with an archer or lead a monster around one. Cover never sits near the start or the stair or in the way between a room's doorways, and the game checks that the stair, every monster and the cache can still be reached (any piece that would cut one off is left out). On about half the floors a small **side room** branches off one of the rooms: a dead end holding a glowing **essence cache**. Walk onto it for a burst of the tower's essence (more on higher floors); sometimes one of the floor's monsters guards it. The numbers live in `COVER`, `SIDE_ROOM` and `CACHE` in `scripts/floors.gd`. In the Firebird's tower some rooms have a chasm and one corridor is cut by a chasm you must jump; in the Kraken's tower the pools sit in the rooms. Once the stair opens, an arrow at the edge of the screen points the way.

**Traps.** Every floor of rooms has 1 to 3 traps, one kind per tower, set into a floor tile in the rooms beyond the first and in the corridors (never on the start, the stair, a chasm or a pillar). Every trap warns before it hurts, and monsters that wander into one are caught too (`scripts/traps.gd`, where the names, timings and damage live):

| Tower | Trap | How it works | How to avoid it |
| --- | --- | --- | --- |
| Gryphon | gust vent | on a cycle: the grate glows and swirls, then a burst of wind shoves everything near it away (hurts a little; can blow you into trouble) | step away or roll |
| Kraken | sluice grate | on a cycle: the grate glows, then a burst of water knocks you back and slows you for a moment (Sandshaper and Tidecaller aren't slowed) | step away or roll |
| Wyvern | flame vent | on a cycle: the grate glows brighter and brighter, then a jet of fire burns for about a second | step away or roll (jumping into the jet doesn't help) |
| Manticore | spike plate | step on it: a click, then spikes rise 0.4 s later | step off, roll, or jump over it (a plate isn't set off from the air) |
| Firebird | ember vent | on a cycle: the grate glows, then bursts and leaves the floor around it burning | step away, roll or jump |
| Chimera | thorn snare | step on it: a rustle, then thorns hold you in place for a moment | step off, roll or jump; once held, a roll breaks free |

Some traps are **hidden**: their tile is very faint until it warns (spike plates and thorn snares most often). The Hunter's **Keen Eyes** spots them, outlining hidden traps in gold. The dev tools' **Show traps** outlines every trap and its reach.

Each floor is one room. Once three quarters of its monsters are down, the **stair** at the top of the room opens: walk onto it to climb, or finish the rest first for their essence (the HUD shows how many are left). Taking the stair is a rest: burns heal, you recover a third of your health and all your stamina. Floors above the first get a random layout of stone pillars, which block movement and arrows, and a group of monsters bought from a budget that grows each floor; monsters also get tougher (`scripts/floors.gd`). Falling ends the run and sends you back to floor 1. Your best floor is saved.

## What's in this build

- **The base climber.** Started very clumsy; now a bit tougher: 140 health, quicker on its feet, faster stamina recovery, cheaper rolls, a slightly wider parry window, and a longer grace period after being hit so a crowd can't chain-hit you.
- **Stormcaller on the hand.** Fills when your strikes land. *Chain Lightning* leaps between up to 4 foes (6 from step 3, and it stuns). Passive *Static*: striking a charged foe arcs to another.
- **Windwalker on the legs.** Fills when you roll through an attack. *Gale Lift* throws foes in front of you into the air, helpless for 1.5 seconds (a wider cone from step 3). Body: your roll becomes a long, cheap wind dash. Passive *Featherweight*: airborne foes take 50% more damage from your strikes.
- **Overdraw.** Cast without enough essence and the spell still fires, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and travel less. Burns heal at the next stair.
- **Marks and motes on the body.** Each bond shows as a sigil that grows lines with its step, circled by motes as its essence fills.
- **Weapons and armor.** Eight melee weapons, two bows and a crossbow, and four suits of armor (see **Weapons and armor** above). *Bows*: hold to draw (you walk slowly while drawing and stamina stops recovering), release to loose. Damage and speed grow with the draw, and a full draw (a soft tick and ring tell you) pierces through foes. A quick tap fires a weak shot; rolling or getting hit drops the arrow. Weapons are plain data in `scripts/weapons.gd`, armor in `scripts/gear.gd`.
- **Solid bodies.** The climber and monsters can't share space; overlapping bodies are pushed apart, and heavier ones (the knight) give way less. Foes lifted by Gale Lift pass over everyone.
- **Timing over mashing.** Swings cost real stamina (a sword chain is 58), and stamina waits almost a second after you attack before it refills, so mashing leaves you winded. Monsters have **poise**: once they commit to an attack, light hits don't stop it (read the glint, then parry or roll); only heavy hits (finishers) rock them, and light hits make a monster flinch at most once every 1.2 seconds, so you can't stun-lock it. After every attack a monster is **open** for most of its recovery: a gold ring pulses around it and your hits deal 60% more ("Opening!"). Beasts have less health than before, longer openings after their attacks, and their fire burns out faster.
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
| `scripts/towers.gd` | The towers: beast, essence, monster mix, look |
| `scripts/items.gd` | Items (names, effects, drop chances, icons) and what a camp offers |
| `scripts/campfire.gd` | A camp's campfire, drawn in code with its light |
| `scripts/enemy.gd` | Slime, archer and knight |
| `scripts/projectile.gd` | Enemy arrows |
| `scripts/fx.gd` | Floating text, lightning and wind cones |
| `scripts/hud.gd` | Health, stamina, bond bars and help text |
| `scripts/menu.gd` | Title screen, pause menu, settings, controls list and dev tools |
| `scripts/title.gd` | The title screen's drawing: sky, tower, motes, the name and tagline |
| `scripts/controls.gd` | Input actions, set up in code; the controller layout and the controls list |
| `scripts/pad.gd` | Game controller: turns its buttons into actions, LB for casts, notices which device was used last |
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
| `scripts/weapons.gd` | Weapon definitions: every melee weapon, bow and crossbow, as data |
| `scripts/gear.gd` | Armor, gear drops, carrying, heirloom slots, comparing and gear icons |
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
