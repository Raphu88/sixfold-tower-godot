# Sixfold Tower (Godot prototype)

A first playable test of the new magic system: **bonds** marked on body parts that fill through combat. The design lives in the *Sixfold Tower: Magic Redesign* doc; this prototype tests one question: **does filling bonds through combat feel good?**

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard version; no .NET needed).
2. In the Godot project manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5** to play.

Everything visual is drawn in code, so there are no art assets. Sounds and music are recorded CC0 effects in `assets/audio` (see [CREDITS.md](CREDITS.md)).

## Playing on a phone

A web version is built automatically every time `main` changes: **https://raphu88.github.io/sixfold-tower-godot/**. Open it in your phone's browser, turn the phone sideways, and tap the **[ ]** button for fullscreen. It also works in a desktop browser.

On a touchscreen the whole game is drawn 1.5x bigger so it reads on a small screen, and on-screen controls appear as soon as you touch it: a joystick under your left thumb (past a light tilt you walk at full speed; there is no sprint), and buttons on the right for attack (hold to draw a bow), roll, parry, your marks' spells and weapon swap, a **Take** button that appears only while you stand on gear you could swap for, an **Item** button at the bottom (it shows the item it will use and how many you have; the small arrow beside it picks the next item), and small **Bag** (inventory), **Climber** and **Menu** buttons at the top right. Aiming is automatic: you face the nearest monster in reach, or the way you're moving.

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
| Pause menu (resume, settings, controls, dev tools, exit) | Esc or P, or the Menu button on a phone | Start / Options |
| Climber screen (marks, essence, record) | Tab, or the Climber button on a phone | Press View / Share |
| Inventory (gear, items, heirlooms) | I, or the Bag button on a phone | D-pad up |
| Restart (hold, so a stray press can't end a climb; once fallen a press is enough) | Hold R | Hold View / Share |
| New climber (forget all marks and start the first climb again; press twice to confirm) | N, or New climber in the menu | New climber in the menu |
| Music on/off | M | Music slider in Settings |
| Show/hide the controls list on screen (off at first; also in Settings) | H | Settings |
| Dismiss the Entity's tip (or tap or click it) | Enter | Press the right stick (RS / R3) |

**Controllers.** Plug in (or pair) an Xbox, PlayStation or similar controller and just press a button. The prompts on screen (the controls panel, the gear card's "take it", the card screens, "press ... to begin your next climb") switch to controller buttons as soon as you use it, with PlayStation names on a PlayStation pad, and back to keys the moment you touch the keyboard or mouse (or to touch wording on a phone). Holding LB (L1) turns the face buttons, RB and RT into your six marks' casts; hold the cast button to open the spell ring and point with the right stick. The button layout lives in `scripts/controls.gd` (`PAD` and `PAD_CAST`), read by `scripts/pad.gd`.

## Weapons and armor

Every weapon and suit of armor here is plain, common gear (enchanted weapons, armor and trinkets will come later). Their names, text and numbers live in `scripts/weapons.gd` (weapons) and `scripts/gear.gd` (armor, drops and carrying), so they're easy to change. Each is drawn in code on the climber and has its own HUD icon.

**Carrying.** Gear lasts one climb. You carry four things: **1 fists** (always), **2 a melee weapon**, **3 a ranged weapon**, and **one suit of armor**. Every climb starts with a **sword**, a **shortbow** and **no armor**, except where you hold an heirloom (below). The HUD shows the weapon in your hand (swapping with 1-3, the controller or the phone's Swap button pops up all three slots for a moment); the **inventory** (I) shows every slot, the armor and their key numbers.

**Finding gear.** Slain monsters (not beasts) rarely drop a piece (4%), likelier one that suits them: knights favour chain mail, plate, swords, maces and greatswords; archers bows, crossbows and leather; smiths hammers, maces and armor; and so on (`FAVOUR` in `gear.gd`). A Forgotten Cache's urn of essence sometimes holds a piece too (35%), and a camp offers a piece of gear as a fourth card beside its three items. Gear lies on the floor with its name. Walk over it with an empty slot (only armor starts empty) and you take it; otherwise a card compares it with what you carry (better numbers in green, worse in red), and **Y** (or **Take** on a phone) swaps: your old piece is dropped where you stand, so you can change your mind.

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

**Heirlooms.** Survive a climb (beat its beast, or reach the Regard on the first climb without falling) and, after the victory screen, you choose **one** piece you carried to keep as an **heirloom**: a card for your melee weapon, your ranged weapon and your armor (any already kept are left out), and one to keep nothing new. Every later climb starts with your heirlooms in their slots instead of the sword, shortbow or no armor. Each slot holds one heirloom; keeping another piece for the same slot replaces it. The slots are **melee**, **ranged** and **chest** (armor); **helm, gloves, legs, boots, cloak, amulet, rings and backpack** are planned for gear that doesn't exist yet. The **inventory** shows your heirloom slots, the planned ones locked, and the climber screen's Record tab lists your heirlooms. Starting a new climber forgets them. Slots and text live in `HEIRLOOM_SLOTS` and `HEIRLOOM_TEXT` in `scripts/gear.gd`; heirlooms are saved with your profile.

The dev tools have a **Gear** row: a button for every weapon and armor, to try them at once.

## Items and camps

**Items** (`scripts/items.gd`, where their names, text and numbers live) are carried through the climb and lost when it ends. You can carry up to 3 of each kind. **G** (or the Item button) uses the selected item and **T** (or the small arrow) picks the next; the HUD shows the selected item beside the weapon, with its count; the inventory (I) shows every item you carry. An item that would do nothing (a draught at full health, a vial with full marks) isn't used up.

| Item | What it does |
| --- | --- |
| Healing Draught | heals 40 health over 1.5 seconds |
| Cleansing Tonic | cures poison, heals every burned body part, and a little health |
| Essence Vial | fills every mark with essence |
| Smoke Bomb | a cloud of smoke around you: monsters inside lose track of you (beasts don't) |

Every climb starts with one Healing Draught. Slain monsters (not beasts) sometimes leave an item (8%); walk over it to pick it up.

**Camps.** On a full climb, the stairs of floors 3 and 9 lead first to a **camp** (`CAMP_AFTER` in `items.gd`): the open room with a campfire and no monsters. You rest fully (all health and stamina, burns and poison healed), then choose one of four cards (keys 1 to 4, the arrows and Enter, the d-pad and A, click, or tap): three items, or a piece of gear (taking it leaves your old piece by the fire). Then take the stair on to the next floor (a camp isn't a floor: after floor 3's camp comes floor 4). Each camp comes once a climb; the bondless first climb has none.

- **Surgeon's Steady Hands:** healing items heal 30% more and work faster.
- **Rune Artist's Runesmith:** after taking an item at a camp, a Rune Artist also chooses a rune for their gear (Sharpness, Warding or Swiftness, as with Inscribe) that lasts the rest of the climb, the beast included, or crafts one more item. Casting Inscribe still changes the rune for one floor.

## Essence density (attributes)

Each essence type is an attribute: Air is Agility, Blade Strength, Stone Vitality, Iron Will, Fire Intellect and Water Spirit. Every bit of essence you bank at a stair settles in you as **density**, by type and in the body parts that earned it (split by what each part did that floor), and it's kept between climbs. Each type gives a small passive bonus that grows with diminishing returns up to 12%: Air move speed, Blade strike damage, Stone health, Iron stamina recovery, Fire spell power, Water how fast your marks fill. The **climber screen** (Tab) shows your six body parts with their marks, and its Essence tab your density and bonus for every type and the essence settled in each part.

## Menus and the dev tool

The game opens on a **title screen** that covers the whole game: a tower drawn in code against a night sky, with lit windows, a moon, mist and drifting motes in the six essence colours (`scripts/title.gd`; the name, tagline and footer text are in its `TEXT` list). Its buttons are **Continue** (or **Begin your first climb** for a new climber), **Climber**, **Settings**, **Dev tools** and **New climber** (only once you have marks to lose), with a line showing your marks and best floor. Arrow keys and Enter, a controller (d-pad or left stick to move, A to press), the mouse, or a tap all work; Esc does nothing there. The focused button has a gold outline, and the first one is focused when a page opens. Pages opened from the title show over its backdrop and **Back** returns to it. Leaving the title takes you to the tower choice.

During a climb there are three screens, and each pauses the game while it's open (menus fade in and out quickly):

- **Pause menu:** **Esc** or **P** (**Start** on a controller, **Menu** on a phone). Resume; Climber and Inventory; Settings and Controls; the Entity's **Archive** and Dev tools; Restart this climb and New climber (it asks first); and **Exit to title**. On a computer there is also **Quit game**; in a browser or on a phone Exit takes you to the title instead.
- **Climber screen:** **Tab** (a short press of **View / Share**, the **Climber** button on a phone). Your character sheet, in four tabs (switch with the buttons, or **Q** / **E**, **LB** / **RB** on a controller; the screen reopens on the tab you used last): **Marks** (the climber drawn in full, hooded and cloaked, with each mark glowing on its body part in its bond's colour and a thin ring of the essence settled there, beside a card for each body part with its mark's medallion, step and growth), **Essence** (density and attribute bonus for each type, the essence settled in each body part, and what you carry unbanked), **Record** (the Entity's record of you: this climb's tower and floor, your counters, each tower's best floor and your heirlooms) and **Archive** (everything the Entity has told you; see below).
- **A mark's page:** choose a card on the Marks tab (click or tap it, or focus it and press **Enter** or **A**). It shows the mark's emblem, its body part and essence, its step and growth (and the banked essence each step needs, or the essence a faint mark still owes), its **Body** and **Passive** effects, and **every spell**: the step that teaches it, how to cast it, its cost, wind-up and other numbers, what it does and what each later step changes. Spells not learned yet are dimmed with a lock and "learned at step N". The steps are listed at the bottom with what each brings. An unmarked part's page says what soaks into it and, where your next mark is forming, which bond it would be. **Q** / **E** (**LB** / **RB**, or the buttons either side of Back) show the next mark; **Back** (**Esc**, **B**) returns to the cards, and **Tab** closes the screen. **Up** / **down** scroll the page.
- **Inventory:** **I** (**d-pad up**, the **Bag** button on a phone). A grid of slots with their icons: your carried gear (fists, melee, ranged, armor; the one in hand gilded), gear lying at your feet (marked "new"), your items with their counts (the quick item gilded), every heirloom slot (the eight planned ones shown locked), and a camp's rune if you hold one. Focus or tap a slot to see its details on the right: a weapon's or armor's numbers set against the gear at your feet or what every climb starts with (better in green, worse in red; the gear at your feet against what you carry, with **Take it**), or an item's text with **Use** (or press the item's slot again) and **Make it your quick item**.

The same key closes its screen (Tab closes the climber screen, I the inventory), and **Esc** or **B** (Circle) goes back a page, or out of the menu from the pause menu or a screen opened by its key; every page shows its Back or Close button with the keys that do the same. **Settings** has music and sound volume, screen shake, the on-screen controls list (off at first), the **HUD size** (small, normal or large), and the Entity's **guide tips** (on or off, and **Replay tips**); they're saved. The Entity presents Settings and the Record: its face and a line sit at the top of both. The **Controls** page lists every key and controller button side by side. On a phone the climber screen and inventory tighten up to fit the screen without scrolling.

The menus and HUD share one look: the interface colours, panel and slot styles, text sizes and the drawn pieces (bars, essence gems, mark medallions and emblems, key badges, locks) live in `scripts/ui.gd`; the item and gear icons are drawn in `scripts/items.gd` and `scripts/gear.gd`, filled, outlined and shaded like the characters. Each mark's emblem follows its essence: Air a three-bladed swirl, Water a drop, Fire a flame, Stone a cut gem, Iron a shield, Blade a four-pointed star. The HUD is kept small so the tower gets the screen. Always there, top left: slim health (with the numbers on the bar) and stamina bars, the weapon in hand and the quick item (small, with its use key and count), and a small medallion per mark that fills with essence and glows once a spell can be cast (on a phone the mark's button lights up too). The rest fades in only when it matters: the essence you've gathered since the last stair (when you pick some up), your three weapons for a moment when you swap, the floor's title when you arrive, the open stair, and for the first seconds of a floor the keys for the menu, climber screen, inventory and controls (H shows every key). The weapon slots, the armor, every item, your attributes and where your next mark is forming are on the climber screen (Tab) and in the inventory (I). On a computer, hovering the mouse over a HUD slot or mark shows what it is and its numbers. The HUD's always-there part is only redrawn when one of its values changes, and the touch buttons too, which keeps phones fast.

The **dev tools** page is for testing (`scripts/menu.gd`, with the actions in `main.gd`):
- **Marks:** give any bond to any body part with the arrows, and set its step from 1 to 5. Changes are saved, and giving a mark ends the bondless first climb. Fill essence, or clear every mark.
- **Climb:** move to another tower, change floor, or go straight to the tower's beast.
- **Practice a beast:** fight any of the six beasts at once, at full health with full marks.
- **Spawn a monster:** any monster or beast, near you.
- **Gear:** give yourself any weapon or armor (it replaces what's in that slot).
- **Cheats:** no dying (a killing blow leaves you at 1 health), heal, clear the room, and show traps (outlines every trap and its reach, hidden ones too).

## The Entity: tips, the Archive and the Record

**The Entity** is a small, mysterious presence: a softly glowing orb with two dark eyes and a wry little mouth, drifting sparks and a gentle bob, drawn in code. It watches the climber, as the beast does, but it isn't the beast, and it never explains the story (that's still to be written). Its name and everything it says live in `scripts/entity.gd`, in plain data, so it's easy to rename or rewrite: `TEXT` (its name and the words around it), `LINES` (short lines for moments and pages) and `TIPS` (each tip's line and a fuller account for the Archive, in the groups of `GROUPS`). In the text, `{move}`, `{attack}`, `{roll}` and the like become the keys, controller buttons or touch buttons for whatever the climber is using (`KEYS`).

**Tips.** The first time the climber meets something new, the Entity says a line or two about it in a bubble at the top right (on a phone, under the Bag, Climber and Menu buttons, clear of the joystick and the action buttons; on a short screen it slides left of any cast button). One bubble at a time: the rest wait their turn. A tip never stops the game; it fades after 6 to 12 seconds, and a tap or click on it, **Enter**, or a press of the right stick dismisses it at once. Bubbles wait while a menu is open or the screen is black between floors. Each tip is said once per save (the "guide" section of the save file). The tips: the Entity itself and the first steps (at the start of a climb), the glint (a monster's first glint), falling, essence (the first essence gathered), banking at the stair, the Regard, casting and the climber screen (a climb with marks), overdraw (a burned mark), a new mark, the open stair, rooms and fog, room names, good rooms, monster dens, restless crypts, doors (the first door opened), locked and sealed doors (for doors to come), chasms (near one) and falling through one, camps, the Proving, the beast, the ward, puzzles (each kind, the first time you walk into its room), traps (the first warning), trap rooms, hidden traps, gas vents, poison, gear on the floor, heirlooms, items and the inventory.

**Moments.** The Entity also has a short word, in the same bubble, when you fall, when a beast is slain, at a new mark and on reaching the Proving (the first time it's the tip; after that one of a few lines).

**The Archive** (the climber screen's **Archive** tab, or **Archive** in the pause menu) keeps everything the Entity has told you, grouped by subject (first steps, essence and marks, the tower, puzzles and traps, gear and items, screens), with a count of how many you've heard. Subjects you haven't met show as **???**. Choose one (click, tap, or the arrows and Enter) to read the Entity's line and a fuller, plain account. With tips turned off in Settings the Entity stays quiet, but the Archive still fills in as you meet things. **Replay tips** (in Settings and the Archive) makes the Entity say everything again; the Archive keeps what it has.

**The Record** (the climber screen's Record tab) is the Entity's record of you: climbs, best floor, marks, floors climbed, monsters slain, beasts slain, falls, puzzles solved, essence banked, heirlooms kept, falls through chasms, the best floor and beasts slain in each tower, and, once you've started over, the climbers before you. The counters are kept with the climber in `profile.gd` (`record`, `note()`, `note_floor()`, `note_beast()`) and start again with a new climber.

**Hooking up a new system.** Call `main.tip("id")` the first time the climber meets it (one line; it's cheap and safe to call every frame) and add an entry for `"id"` to `TIPS` in `entity.gd`. An id with no entry of its own falls back to the part before its last `_` (a new puzzle kind `"puzzle_mirrors"` gets the general `"puzzle"` tip, `"door_iron"` gets `"door"`). Moments use `GuideScript.say("key", {...})` or `GuideScript.moment("tip", "key")`. The bubble, the queue and what's been said live in `scripts/guide.gd`. Tests keep the Entity quiet unless they set the `sixfold_tips` meta on `Engine`. Hovering a HUD slot on a computer shows its tooltip with the Entity's small face in the corner.

## Towers

Every climb starts by choosing a tower (keys 1 to 6, click, or tap a card). Each tower has its own beast, essence, monster mix and look (`scripts/towers.gd`):

| Tower | Essence | Monsters | Look |
| --- | --- | --- | --- |
| The Gryphon's Tower | Air | archers, bats and thunderlings; the Gryphon on floor 12 | cold, blue stone and pale torches |
| The Kraken's Tower | Water | slimes, lurkers and shellbacks; the Kraken on floor 12 | damp, teal stone and green-white torches |
| The Wyvern's Tower | Iron | knights, cinders and smiths; the Wyvern on floor 12 (the hardest) | hot forge-red stone and orange torches |
| The Manticore's Tower | Stone | scorplings and rams; the Manticore on floor 12 | sun-baked sandstone and warm torches |
| The Firebird's Tower | Fire | wisps and bloomcaps, and chasms to jump; the Firebird on floor 12 | pale, sunlit stone and gold torches |
| The Chimera's Tower | Blade | thornhounds and mongrels; the Chimera on floor 12 | the Thornwild: mossy green stone and pale green torches |

**The Gryphon's tower has a summit.** On floor 12, the summit, the Gryphon itself waits, alone. It rakes with its talons up close (a red wedge, parryable), dives on you from range (it locks onto where you stood when it glints; the landing can't be parried, so roll out of the red circle), and throws a fan of feathers (parryable, and a Crosswind turns them back). It can't be lifted or interrupted, only staggered, and at half health it calls two bats. Beat it, take the stair, and the climb is complete.

**The Kraken's tower has a summit too.** On floor 12 the Kraken waits. It sweeps a tentacle across a wide wedge in front of it (parryable), slams three spots at once with one landing where you stand (can't be parried: roll out of the red circles), and spits a fan of ink (parryable). At half health it calls two lurkers.

**The Wyvern waits atop its tower.** On floor 12 it sweeps its tail across a wedge in front of it (parryable), breathes fire down a narrow cone (can't be parried: roll or step aside) that leaves the floor burning, and sprays a fan of embers (parryable). At half health it calls two cinders.

**The Chimera waits atop its tower.** Three beasts in one: the lion mauls up close (parryable) and breathes fire down a narrow cone (can't be parried: roll or step aside); the goat charges in a straight line (parryable; it's stunned if it charges into a wall); the serpent tail spits three poisoned spikes (parryable). At half health it calls two thornhounds.

**The Chimera's monsters:** the **thornhound** is a fast pack hound that circles, glints and leaps at you with a bite (parryable). The **mongrel** is a patchwork beast that alternates a bite up close (parryable) with a fan of thrown quills (parryable).

**Jumping and chasms.** Everyone can jump (Z): a short hop that costs a little stamina and carries you over chasms and burning floor (it isn't a dodge: attacks still hit you in the air). In the Firebird's tower, floors above the first have **chasms**: walk or get knocked into one and you fall through it: it doesn't hurt, but you land on the floor below and climb again from there (never below floor 1; your unbanked essence stays with you). Walking monsters can't enter chasms; flying ones (bats, cinders, wisps and the beasts that fly) cross them.

**The Firebird waits atop its tower.** On floor 12, in an open hall, it swoops straight through you (parryable), leaving fire in its wake; calls down a firestorm on four spots, one where you stand (can't be parried: get out of the circles, or jump); and throws a fan of embers (parryable). The first time it falls it burns to ashes, can't be hurt for two seconds, and rises again at 40% health. At half health it calls two wisps.

**The Firebird's monsters:** the **wisp** flickers around you, glints and darts straight through where you stood (parryable), leaving a little fire. The **bloomcap** is a rooted fire-fungus: it glints, locks onto where you stand and lobs burning spores that land a moment later (can't be parried: step out of the circle or jump); the ground keeps burning.

**The Manticore waits atop its tower.** On floor 12 it swipes with its claws (a red wedge, parryable), fires a volley of three poisoned tail spikes (parryable), and roars, bursting out around itself (can't be parried: roll through it). At half health it calls two scorplings.

**The Manticore's monsters:** the **scorpling** scuttles up, glints and stings (parryable); a sting that lands **poisons** you: 2 health every half second for a few seconds (the stair's rest cures it). The **ram** lowers its horns, glints and charges in a straight line (parryable). A ram that charges into a wall or pillar is stunned, so letting it miss is an opening.

**The Wyvern's monsters:** the **cinder** is a living ember that flits at range, glints and spits a burning ember (parryable). The **smith** plods up and brings its hammer down in front of it (parryable, but it hits hard), leaving the floor there burning for a few seconds. **Burning floor** costs 4 health every half second you stand in it; rolling through is free.

**The Kraken's monsters:** the **lurker** swims under the water, where only ripples and two eyes show and it can't be hit. It rises near you, glints and lunges (parryable), then stays up for a moment: that's your chance. The **shellback** plods toward you behind a shell that blocks most of a blow from the front (heavy blows crack it), and bashes up close; get behind it.

**The Gryphon's monsters:** the **bat** circles you, then glints and swoops straight through where you stood (parryable). The **thunderling** walks up, stops and sparks, then bursts into a ring of lightning: it can't be parried, so step out of the ring or roll through it.

Every kill also yields 1.5 essence of the tower's own kind, so the tower you choose is how you steer which bonds you'll form. The tower's beast is the one who regards you at the top of your first climb.

## Marks, essence and the Regard

- **Six body parts**, one for each of the six towers: hand, legs, heart, brow, throat and back. Each holds one mark. A **backstab** (striking a foe that faces away from you, because it has committed to an attack or you rolled behind it) deals 50% more damage.

- **Your first climb is bondless.** You start clumsy, with weapons only. Climb 3 floors.
- **Essence:** monsters leave essence when they fall: Air, Water, Iron, Fire or Stone (slimes Water, archers Air, knights Iron, cinders and the Wyvern Fire). It flies into you and is **banked at the next stair**. Fall before the stair and the unbanked essence is lost.
- **Your body soaks it up** through what each part does: the **hand** from weapon strikes (+0.5 per hit), the **legs** from rolling through attacks (+4), the **heart** from taking hits and surviving (+4), the **brow** from parries (+6, perfect +9), the **throat** when one swing or spell hits several foes (+2 for each foe past the first), the **back** from backstabs (+3) and finishing blows (+2). Unmarked parts glow faintly as they soak, and the climber screen's Marks tab (Tab) shows each unmarked part's soak, the leader ("your next mark is forming"), and which bond it would be right now.
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

**How tall a tower is.** Every tower is 12 floors to the summit, where its beast waits (`SUMMIT` in `towers.gd`). Floor 6 is **the Proving**, where the tower takes your measure: for now it's an ordinary floor with its own banner (its name and line are in `PROVING` in `towers.gd`); its special test comes later. Your bondless first climb is 3 floors and ends in the Regard. Camps after floors 3 and 9 aren't floors.

**Floors are planned.** Floor 1 and the beast's floor are single open rooms. Every floor in between is planned on a grid of cells, one room each at most, and the grid grows with height: 4 by 3 cells on floors 2 to 5, 5 by 3 on floors 6 to 9, 5 by 4 on floors 10 and 11 (`PLAN` in `scripts/floors.gd`). Each floor has 6 to 11 rooms:
- **The spine** is the main route, a walk from cell to neighbouring cell. Each of its rooms has a job: the **entrance** (you start here), **guard rooms**, the **gallery** in the middle (it holds the floor's puzzle) and the **stair hall** (the stair stands at the top of it).
- **Branch rooms** (2 or 3) hang off the spine in the cells beside it: side rooms worth a look.
- A cell or two beside the spine is kept for a **sealed wing**, and sometimes one for a **secret room**. They're only kept for now (the plan lists them); the wings and secrets themselves come later.

**Rooms.** A room is either **hand-made**, drawn as a small text grid in `scripts/rooms.gd` (one character per tile: walls, pillars, chasms, pools, monster spots and random tiles), or a shape **carved** in its tower's style: plain, open, a long hall, an L, a cross (corners notched), round (corners cut) or pillared (`SHAPES` in `rooms.gd`; each tower's favourites are its `shapes` in `towers.gd`: the Kraken's tower likes halls and L-shapes, the Wyvern's pillared rooms, and so on). Hand-made rooms suit their job (calm start rooms, combat rooms, stair rooms, puzzle rooms), flip at random so they don't repeat exactly, and never appear twice on a floor. A wall that touches a room's edge becomes part of its outline; one standing free inside is a low wall you can hide behind (it blocks movement, sight and shots). The game checks that the stair, every monster and the cache can be reached (any low wall that would cut one off is left out). To add a room, copy one in `rooms.gd` and draw your own.

**Corridors and doors.** Corridors are two tiles wide and run straight from one room's wall to the facing wall of the next, as near the middle of both walls as the rooms' shapes allow, so they never cut through a room and what's drawn in it stays as drawn. Stone posts frame each doorway. Many doorways have a **door** (`scripts/doors.gd`): likelier on rooms where danger waits (three in four on dens, crypts, the stair landing and the puzzle room; one in three elsewhere; never on the start room). A closed door is solid: it blocks the way, shots and sight, so a room behind one stays dark until you open it. Walk up to a door and it swings open (a thud and a puff of dust); awake monsters open doors too. A door's look hints at the challenge inside, never the reward: plain planks for an ordinary room, iron bands, claw marks and bones at the threshold for a den, an engraved sigil of the hazard (wind, a wave, a flame, spikes, an ember, thorns or a chasm) for a trap room, a stone door with the puzzle's emblem (an eye or a plate) for the puzzle room, warm light under the door for a good room, and chains and a red glow for danger (a crypt, the stair landing).

**Room themes.** Every room has a **theme**: what it is (`scripts/themes.gd`, where the names, rules, tints and door looks live, all easy to rename). The first time you walk into a themed room its name and one-line rule show across the screen, for example "MONSTER DEN: Bones and claw marks. Something lives here." Each theme also washes the room's floor in its colour (with bones in a den, scorch marks in a furnace). Themes are given by rules, not pure chance: the start room is the **Arrival Hall**, the stair room the **Stair Landing** (its guards wait there) and the gallery takes its puzzle's theme (**Hall of Eyes** or **Weighing Room**). Of the other rooms, the first is always a good room and the second a **Monster Den**; after that comes a mix, with no bad theme twice a floor, a cap on bad rooms (3 up to floor 3, then 4), each tower's own themes twice as likely, and a theme that doesn't fit its room swapped for one that does.
- **Good rooms:** a **Healing Spring** (stand in the pool to heal until it runs dry), a **Forgotten Cache** (an urn of the tower's essence: walk onto it for a burst, more on higher floors; sometimes it holds gear), a **Fallen Climber's Camp** (a cold fire, a bedroll and an item left behind), and each tower's own (the Gryphon's Windswept Aerie, the Kraken's Tidepool, the Wyvern's Cold Forge, the Manticore's Hidden Oasis, the Firebird's Ember Pyre, the Chimera's Thornwild Nest). Two at most a floor, and no traps in them.
- **Bad rooms:** the **Monster Den** (more of the floor's monsters wait there), the **Restless Crypt** (from floor 3: its dead rise when you walk in), the **Pillared Hall** (archers like it), each tower's **trap room**, where its set piece of traps is laid (Windhall, Sluice Hall, the Furnace, Spike Gallery, Emberfall, Bramble Hall), and in the Firebird's tower **the Chasm**, a band of chasm right across a room. A quiet room is just a **Quiet Hall**.

Monsters wait in the rooms: most in the den, some guarding the stair, the rest along the route and in the branches, never in the start room or a good room (hand-made rooms' marked spots first). A monster stays put until it sees you (or you come close, or it's hit), then rouses its neighbours and finds its way to you around the walls (a path grid, `AStarGrid2D`). Monsters can't attack what they can't see, and walls stop every shot. Each room has one torch on its north wall.

**Fog.** On floors of rooms you see only what your climber can see: walls block sight (chasms, water and pillars don't), places you've seen stay dimly mapped, and places you haven't are dark. Monsters out of sight are hidden until you see them (`scripts/fog.gd`), and closed doors block sight like walls. The cache's and spring's numbers live in `CACHE` and `SPRING` in `scripts/floors.gd`. In the Firebird's tower the rooms' chasm tiles are real chasms, and every floor has a chasm to jump (a Chasm room, or failing that a long corridor cut by one); elsewhere chasm tiles are walls. In the Kraken's tower the rooms' pools fill with water. Once the stair opens, an arrow at the edge of the screen points the way.

**Puzzles and the ward.** Every floor of rooms has a **puzzle room** (drawn in `scripts/rooms.gd`), and its stair is **warded**: it won't open, however many monsters fall, until the puzzle is solved. A main puzzle never needs a bond, an item or a piece of gear, only what every climber has (`scripts/puzzle.gd`, where the text and numbers live):
- **Stone eyes** sit behind low **rails** (rails stop walking but not sight or arrows). Hit every eye, with a strike if you can reach it or an arrow over the rail, to solve it. On harder floors an eye stays lit only a couple of seconds, so you must light them all together. With no monster near, auto-aim (phones and controllers) turns to the nearest unlit eye.
- **Pressure plates** need a **weight**: the climber is too light. Push a **stone block** onto a plate (walk into it for a moment and it slides a tile), or lure a monster onto it and keep it alive. Every plate held at once solves it; strike the **lever** to put the blocks back if one gets stuck.

Solving lifts the ward ("THE WARD LIFTS"), opens the stair, and opens the room's **gate**, behind which waits a burst of the tower's essence. Floor 1 and the beast's floor have no ward: there the stair still opens once three quarters of the monsters are down.

**Traps.** Traps are the beast's tests, one kind per tower, laid out as **set pieces**: the first in the floor's trap room (see Room themes), the rest at chokepoints (mostly corridors, sometimes rooms beyond the first, never a good room), plus one or two **hidden plates** anywhere past the first room (`scripts/traps.gd`, where the names, timings, damage and shapes live). Traps in a set piece keep **one shared beat**, so they fire in a readable pattern (a wave, or a checkerboard) you can learn and walk through. Visible traps show their reach engraved on the floor (lanes with arrows for the way they fire). Every trap warns before it hurts: a glow, then a **glint** (a white star and a "ting", like a monster's) a moment before it fires. Because of that, traps **hurt badly** (about 10 to 28, more higher up), and getting hit is your own fault. Rolling through a firing trap counts as a dodge (feeding your legs), but only once per trap. Monsters that wander into one are caught too.

| Tower | Set piece | How it works | How to avoid it |
| --- | --- | --- | --- |
| Gryphon | gust lanes | nozzles along a corridor fire lanes of wind across it in a wave, shoving you hard along the lane | time it, or roll |
| Kraken | sluice sweeps | waves roll along two rows of a corridor in turn, knocking you along and slowing you (Sandshaper and Tidecaller aren't slowed) | walk the dry row, or roll |
| Wyvern | flame jets | nozzles fire 3-tile jets of fire across a corridor in a wave, burning for about a second | step in behind the wave, or roll (jumping doesn't help) |
| Manticore | spike field | a patch of plates in a checkerboard; the two halves take turns | step on the resting squares, roll, or jump |
| Firebird | ember mortars | marked circles in a row burst in turn and leave the floor burning | step away, roll or jump |
| Chimera | bramble patch | snares (half of them hidden) hold you in place, and their rustle **wakes the monsters** nearby | step around, roll or jump; once held, a roll breaks free |

**Hidden traps** can be anywhere: their tile is very faint, but the moment one is set off it shows itself (a click, a hiss or a rustle, its reach lit up) and gives you about half a second to get clear. The Manticore's and Chimera's towers also hide **gas vents**: set one off and a cloud spreads that keeps hurting while you stand in it. It can kill you if you don't get out quickly, and it hurts monsters too. The Hunter's **Keen Eyes** spots hidden traps, outlining them in gold. The dev tools' **Show traps** outlines every trap and its reach, and **Speed readout** shows, at the bottom right, the frame rate and frame time, draw calls, node count, and how many monsters, traps and lights there are (to check for lag on a phone).

**The stair.** On floor 1 and the beast's floor the **stair** at the top of the room opens once three quarters of the monsters are down; on floors of rooms it opens when the puzzle lifts its ward. Walk onto it to climb, or finish the rest first for their essence (the HUD shows how many are left). Taking the stair is a rest: burns heal, you recover a third of your health and all your stamina. Each floor's monsters are bought from a budget that grows with height, and they get tougher too (`scripts/floors.gd`). Falling ends the run and sends you back to floor 1. Your best floor is saved.

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
- **The look.** A dark tower: flagstone floor with moss and cracks, a brick north wall, flickering torches, drifting dust and embers. The darkness is **one layer** over the world (`scripts/lighting.gd`, like the web version's): a single screen-sized shader that darkens everything in the tower's own fog colour and cuts soft holes of light around the climber, the torches, the stair, the cache, lit puzzle eyes, burning floor and short flashes, and adds a vignette. It costs one draw call however many lights there are (up to 48 at once), and it reads the line-of-sight fog in the same pass. The open stair, the cache, lit eyes and the ward also get a soft coloured glow so the eye goes to them. Each tower's darkness colour and stone hue live in `scripts/palette.gd` (`TOWER_FOG`, `TOWER_TINT`). Characters are outlined and shaded: a hooded climber with a visible weapon, a wobbling slime whose eyes follow you, a hooded archer with bow and quiver, and an armoured knight with shield and plume who raises his sword to wind up. Telegraphs, swing trails, health bars and words in the world (damage numbers, gear names) are drawn above the darkness so they always read. The camera follows the climber, zoomed in. Spells, parries, crits and burns flash light (`main.light_flash`); slain monsters burst into debris.
- **Sound.** Recorded CC0 effects, layered by `tools/build_audio.py` (sword hits are a chop plus a punch body plus a low thump, parries are a metal clang with a ringing tail). Every weapon sounds like itself: a dagger's quick swish and slice, a spear's thrust, the dull whoosh and bone-deep thud of a mace or war hammer, and its own sound when you switch to it. Bows are real bow recordings: the stave creaks while you draw (lower on the longbow), the nock clicks at full draw, and the release is a string snap and a whoosh that grows louder and sharper the longer you held it; arrows land with a wooden thunk (into walls too). The crossbow fires with a hard clack, ratchets as it reloads and clicks when the bolt drops in. Hits sound different on each monster (armour clanks, slime squelches), the archer's bow creaks before it fires and the knight's armour rattles as he winds up, beasts' blows land with a deep slam, chain mail and plate jingle as you walk, trap plates click before they fire, gas vents hiss (`hiss`), and there are pick-up, armor and heirloom sounds, soft page-turn sounds in the menus, and a gong when the room is clear. Levels are set by kind (footsteps and menus quiet, hits in the middle, slams and parries loudest) so nothing jumps out, and in a busy fight one sound never plays more than four times at once. Looping music and tower ambience play underneath; M toggles them. The knight's wind-up and the archer's aim lock each play a warning tone.
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
| `scripts/floors.gd` | Plans each floor: the grid, spine, branches and kept cells, corridors, doors, monster groups, toughness |
| `scripts/rooms.gd` | The hand-made rooms, drawn as text grids, the carved shapes, and how they turn into walls, pillars, chasms and pools |
| `scripts/themes.gd` | Room themes: names, one-line rules, tints, door looks, and the rules that hand them out |
| `scripts/doors.gd` | Doors: solid until you walk up, styled to hint at the room behind |
| `scripts/fog.gd` | Line-of-sight fog on floors of rooms (worked out up to 12 times a second; drawn by `lighting.gd`) |
| `scripts/lighting.gd` | The darkness layer: one shader over the world, the light registry (`add_light`, flashes), the fog and the vignette |
| `scripts/puzzle.gd` | The floor's puzzle (eyes, plates, blocks, rails, gates, levers) and the stair's ward |
| `scripts/towers.gd` | The towers: height (12 floors, the Proving on 6), beast, essence, monster mix, room shapes, look |
| `scripts/items.gd` | Items (names, effects, drop chances, icons) and what a camp offers |
| `scripts/campfire.gd` | A camp's campfire, drawn in code (its light comes from `lighting.gd`) |
| `scripts/enemy.gd` | Slime, archer and knight |
| `scripts/projectile.gd` | Enemy arrows |
| `scripts/fx.gd` | Floating text, lightning and wind cones |
| `scripts/hud.gd` | The small HUD (health, stamina, weapon, quick item, marks), the fading notices, overlays and the dev speed readout |
| `scripts/menu.gd` | Title screen, pause menu, climber screen, inventory, settings, controls list and dev tools |
| `scripts/ui.gd` | The interface's colours, panel and slot styles and text sizes (menus and HUD) |
| `scripts/entity.gd` | The Entity: its name, lines, tips and Archive text (data), and its face, drawn in code |
| `scripts/guide.gd` | The Entity in play: the tip registry and queue, the bubble, dismissing it, and what's been said |
| `scripts/title.gd` | The title screen's drawing: sky, tower, motes, the name and tagline |
| `scripts/controls.gd` | Input actions, set up in code; the controller layout and the controls list |
| `scripts/pad.gd` | Game controller: turns its buttons into actions, LB for casts, notices which device was used last |
| `scripts/touch.gd` | On-screen touch controls |
| `export_presets.cfg` | Web export settings |
| `.github/workflows/web.yml` | Builds and publishes the web version |
| `scripts/audio.gd` | Plays sound effects (random variants) and music |
| `scripts/sound_bank.gd` | Generated list of sound files |
| `scripts/room.gd` | The room's look: floor, walls, torches, dust |
| `scripts/palette.gd` | The world's colours (the interface's are in `ui.gd`) |
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

The finished sounds are committed, so you only need this to change them. Each game sound is defined in `SOUNDS` at the top of `tools/build_audio.py` (which source clips to layer, how loud, and an optional low-pass/high-pass to tame harsh highs or rumble). Needs Python 3 with numpy, ffmpeg, and to fetch the sources `7z` or `pip install py7zr` (one pack comes as .7z). The smoke test checks that every sound the code plays is in the bank.

```bash
tools/fetch_audio_sources.sh
```

```bash
python3 tools/build_audio.py
```
