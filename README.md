# Sixfold Tower (Godot prototype)

A first playable test of the new magic system: **bonds** marked on body parts that fill through combat. The design lives in the *Sixfold Tower: Magic Redesign* doc; this prototype tests one question: **does filling bonds through combat feel good?**

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard version; no .NET needed).
2. In the Godot project manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5** to play.

Everything visual is drawn in code, so there are no art assets. Sounds and music are recorded CC0 effects in `assets/audio` (see [CREDITS.md](CREDITS.md)).

## Playing on a phone

A web version is built automatically every time `main` changes: **https://raphu88.github.io/sixfold-tower-godot/**. Open it in your phone's browser, turn the phone sideways, and tap the **[ ]** button for fullscreen. It also works in a desktop browser.

On a touchscreen the whole game is drawn 1.5x bigger so it reads on a small screen, and on-screen controls appear as soon as you touch it: a joystick under your left thumb (past a light tilt you walk at full speed; there is no sprint), and buttons on the right for attack (hold to draw a bow), roll, parry, your marks' spells and weapon swap, a **Take** button that appears only while you stand on gear you could swap for, an **Item** button at the bottom (it shows the item it will use and how many you have; tap it to use that item, or hold it to open a ring of your belt items, slide your finger toward one and let go to use it; the small arrow beside it picks the next item), and small **Bag** (inventory), **Climber** and **Menu** buttons at the top right. Aiming is automatic: you face the nearest monster in reach, or the way you're moving.

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
| Take the gear you stand on (your old piece goes in your pack, or is dropped if it's full) | Y, or the Take button on a phone | Y / Triangle |
| Cast your marks (hand, legs, heart, brow, throat, back); hold to pick a spell | Q, E, F, C, X, V | Hold LB / L1, then X, A, B, Y, RB, RT (Square, Cross, Circle, Triangle, R1, R2) |
| Use your item (tap); hold to open the ring of belt items, point at one and let go | G, or the Item button on a phone | X / Square |
| Next item (tap); hold for the item ring | T, or the small arrow button beside Item on a phone | D-pad down |
| Choose a tower, camp card or heirloom | 1 to 6, or arrows and Enter, click, or tap the card (after the Regard, towers are chosen on the train's Depart car) | D-pad or left stick, then A / Cross |
| The train between climbs: switch cars | Q / E, or tap a car's tab | LB / RB |
| Pause menu (resume, settings, controls, dev tools, exit) | Esc or P, or the Menu button on a phone | Start / Options |
| Climber screen (marks, essence, record) | Tab, or the Climber button on a phone | Press View / Share |
| Inventory (gear, items, heirlooms) | I, or the Bag button on a phone | D-pad up |
| Restart (hold, so a stray press can't end a climb; once fallen a press is enough) | Hold R | Hold View / Share |
| New climber (forget all marks and start the first climb again; press twice to confirm) | N, or New climber in the menu | New climber in the menu |
| Music on/off | M | Music slider in Settings |
| Show/hide the controls list on screen (off at first; also in Settings) | H | Settings |
| Dismiss the Entity's tip (or tap or click it) | Enter | Press the right stick (RS / R3) |

**Controllers.** Plug in (or pair) an Xbox, PlayStation or similar controller and just press a button. The prompts on screen (the controls panel, the gear card's "take it", the card screens, "press ... to begin your next climb") switch to controller buttons as soon as you use it, with PlayStation names on a PlayStation pad, and back to keys the moment you touch the keyboard or mouse (or to touch wording on a phone). Holding LB (L1) turns the face buttons, RB and RT into your six marks' casts; hold the cast button to open the spell ring and point with the right stick. The button layout lives in `scripts/controls.gd` (`PAD` and `PAD_CAST`), read by `scripts/pad.gd`.

## Gear: weapons, armor and worn pieces

Gear is everything you carry and wear. Weapons live in `scripts/weapons.gd`; armor, the worn pieces, drops, wear and heirlooms in `scripts/gear.gd`. Names, text and numbers are plain data there, so they're easy to change. Everything is drawn in code, with its own icon.

**Slots.** Gear lasts one climb. You carry **1 fists** (always), **2 a melee weapon** and **3 a ranged weapon**, and you wear a **chest** piece (armor), a **helm**, **gloves**, **legs**, **boots**, a **cloak**, an **amulet**, **two rings** and a **backpack**. An **off-hand** slot is kept for later (it shows locked). Every climb starts with a **sword**, a **shortbow** and nothing else, except where you hold an heirloom (below). The HUD shows only the weapon in your hand (swapping with 1-3, the controller or the phone's Swap button pops up all three weapon slots for a moment); the **inventory** (I) shows everything you wear.

**Gear records.** Each piece is a small record, not just a name: its **base** (which piece it is), its **rarity**, its **traits**, its **rank** (kept for the bench, later), for a named piece its **name** (`named`), and, for plain Common pieces, its **wear**. Helpers in `gear.gd` make (`make`, `make_named`, `roll_gear`), convert (`rec`, `code`), describe (`display`, `describe`, `trait_lines`, `stats`), compare (`compare`, `plays_like`) and add up (`total_effects`, `capped_keys`, `protection`) records. Old saves, which kept heirlooms as plain names, are converted automatically when they load.

**Finding gear.** Slain monsters (not beasts) rarely drop a piece (4%), with a rarity by floor (see **Rarities and traits** below), likelier one that suits them: knights favour chain mail, plate, swords, maces, greatswords, iron helms and gauntlets; archers bows, crossbows, leather and leather caps; smiths hammers, maces, armor, gauntlets and hobnail boots; bats dusk cloaks; and so on (`FAVOUR` in `gear.gd`). A drop can be for any slot. Rings and amulets don't appear on the bondless first climb. A Forgotten Cache's urn of essence sometimes holds a piece too (35%), a camp offers a piece of gear as a fourth card beside its three items, and a vault may hold one (Fine at the least); caches, camps and vaults roll one rarity row higher than monsters, and the floor 9 camp's piece is Rare. Gear lies on the floor with its name in its rarity's colour (Fine and better pieces also glint). Walk over it with an empty slot and you take it (a second ring goes on your other hand); otherwise a card names its **slot** and compares it with what you wear there (better numbers in green with an up arrow, worse in red with a down arrow), and **Y** (or **Take** on a phone) swaps: your old piece goes in your **pack** if there's room, else it's dropped where you stand, so you can change your mind. The first time you find a worn piece, the Entity explains the slots.

**The pack.** Besides what you wear you carry a **pack** of **4 spare pieces** (`PACK_SIZE` in `gear.gd`; a Climber's Pack holds 2 more). Swapping gear puts your old piece in it while there's room. The inventory's **Pack** view (beside Worn and Heirlooms) shows it: choose a pack piece to **Wear it** (what you wore takes its place) or **Drop it here**, and the gear at your feet has **Into your pack**. Survive a climb (or read a recall scroll) and your pack comes down to the **train** with you, to sell or keep in your chest; fall and it's lost.

**Worn pieces** (the Common ones; each does one small thing). *Heavy* pieces make every roll cost 3% more stamina, on top of your chest piece's weight.

| Piece | Slot | What it does |
| --- | --- | --- |
| Cloth Hood | Helm | your light reaches 10% farther |
| Leather Cap | Helm | +8 health |
| Iron Helm | Helm (heavy) | 6% damage taken off |
| Grip Wraps | Gloves | strike chains cost 6% less stamina |
| Leather Gloves | Gloves | strikes hit 4% harder |
| Gauntlets | Gloves (heavy) | strikes hit 7% harder; the parry window is 5% shorter |
| Padded Trousers | Legs | +10 max stamina |
| Leather Leggings | Legs | rolls carry 5% farther |
| Chain Leggings | Legs (heavy) | 5% damage taken off |
| Soft Boots | Boots | you walk 4% faster |
| Climbing Boots | Boots | jumps cost no stamina and carry 10% farther |
| Hobnail Boots | Boots (heavy) | light blows (under 14 damage) can't knock you back; you walk 3% slower |
| Travel Cloak | Cloak | poison wears off 25% sooner and burning floor hurts 25% less |
| Dusk Cloak | Cloak | monsters notice you 20% later |
| Satchel | Backpack | carry 4 of each item instead of 3 (the recall scroll stays one) |
| Belt Pouch | Backpack | one more kind of item on the belt (5) |

**Rings and amulets** (Fine, so they never wear; you wear two rings and both count):

| Piece | Slot | What it does |
| --- | --- | --- |
| Bone Charm | Amulet | +10 health |
| Ember Charm | Amulet | spells hit 6% harder |
| Iron Band | Ring | stamina refills 5% faster |
| Garnet Ring | Ring | strikes hit 4% harder |

**Rare by nature** (found only as Rare finds; never wear):

| Piece | Slot | What it does |
| --- | --- | --- |
| Tide Locket | Amulet | marks fill 8% faster; +6 health |
| Pearl Ring | Ring | each kill puts 2 essence into your emptiest mark |
| Ring of the Overdrawn | Ring | your first overdraw each floor doesn't burn the body part |
| Climber's Pack | Backpack | one more kind of item on the belt, 4 of each, and 2 more pack spaces |

The climber shows what's visible: the helm (a cloth hood, a leather cap or an iron helm), the cloak's colour, gloves on the hands, and boots (hobnails glint on their studs).

**Protection** from everything you wear adds up (plate 35%, an iron helm 6% and chain leggings 5% make 46%) but never goes past **50%** (`PROTECTION_CAP`).

### Rarities and traits

Gear comes in five **rarities** (`RARITIES` in `gear.gd`), each with its colour on the floor label, the drop's glint, the inventory slot's edge and the card: **Common** (parchment), **Fine** (green, 1 trait, weapons +5% damage), **Rare** (blue, 2 traits, weapons +10%), **Storied** (amber, its own named rule and 1 trait, weapons +12%) and **Regarded** (gold, kept for the beasts' own weapons, later). Rings and amulets are Fine by nature, so they carry one trait fewer. Backpacks take no traits. Only plain **Common** pieces wear; anything with a trait, and anything finer, never does.

**Rarity by floor** (slain monsters; caches, camps and vaults roll one row higher; `RARITY_ODDS`):

| Floors | Common | Fine | Rare | Storied |
| --- | --- | --- | --- | --- |
| 1 to 3 | 80% | 20% | 0% | 0% |
| 4 to 6 | 60% | 32% | 8% | 0% |
| 7 to 9 | 45% | 38% | 15% | 2% |
| 10 to 12 | 35% | 40% | 20% | 5% |

Storied pieces are only found from floor 7 up. A **Rare** or better find fades in a short notice under the floor title ("RARE: Axe of the Riposte").

**Traits** (`TRAITS`): each belongs to an essence (shown in its colour on the card) and rolls only on the slots it suits. Names read like *Fine Leather Gloves of Edges* or *Rare Iron Helm of Vigor* (the first trait names the piece).

| Trait | Essence | Fine | Rare | Slots |
| --- | --- | --- | --- | --- |
| of Vigor | Stone | +6 health | +10 | helm, chest, legs, cloak, amulet |
| of Footing | Stone | traps and burning floor hurt 15% less | 25% | boots, legs |
| of Edges | Blade | strikes +3% | +5% | melee, gloves, rings |
| of the Riposte | Blade | ripostes and backstabs +8% | +12% | melee, gloves |
| of Breath | Iron | +8 max stamina | +12 | legs, chest, cloak |
| of Second Wind | Iron | stamina refills 4% faster | 6% | rings, amulet, chest |
| of Thorns | Iron | foes that strike you up close take 3 | 5 | chest, gloves |
| of the Wind | Air | walk +2% | +3% | boots, cloak, legs |
| of Rolling | Air | rolls cost 5% less stamina | 8% | boots, legs |
| of the Hunt | Air | bows and crossbows +5% | +8% | ranged, gloves, helm |
| of Kindling | Fire | spells +4% | +6% | amulet, rings, helm |
| of Embers | Fire | strikes have a 10% chance to set the foe burning (2 every half second for 2 s) | 15% | melee, gloves |
| of the Well | Water | marks fill 4% faster | 6% | amulet, rings, helm |
| of Calm | Water | parry window +5% | +8% | gloves, helm, rings |

**Caps** (`CAPS`): whatever you wear adds at most +25% strikes, +40 health, +30 stamina, +12% walk and +20% spells; the inventory says "(capped)" beside a number that has hit its cap. The gear card's comparison counts traits (green up arrows, red down arrows), and for weapons its "plays like" line names the traits it adds or loses ("hits harder, adds Embers").

**Named pieces** (`NAMED`) keep their own names. **Tower pieces** (Rare) are only found in their own tower; **Storied** pieces anywhere from floor 7:

| Piece | Base | Found | What it does |
| --- | --- | --- | --- |
| Stormstring | shortbow | Gryphon's tower | a full draw also arcs to one more foe for half damage |
| Coral Trident | spear | Kraken's tower | hits slow foes by 25% for 1.5 s |
| Barnacle Mail | chain mail | Kraken's tower | foes that strike you up close take 5 |
| Cinder Axe | axe | Wyvern's tower | the finisher leaves the floor burning for 2 s (it burns foes, not you) |
| Wyvern Scaleplate | plate | Wyvern's tower | 32% off a blow with chain mail's weight |
| Stinger Dagger | dagger | Manticore's tower | every hit poisons the foe a little more |
| Sunsteel Blade | sword | Firebird's tower | kills heal you 4 |
| Thornmaul | war hammer | Chimera's tower | a staggering finisher throws thorns at foes nearby for 6 |
| Watcher's Helm | helm | Storied | foes you parry take 20% more from you for 3 s; +6 health |
| Quickhand Gloves | gloves | Storied | each kill fills your hand's mark by 5%; strikes +3% |
| Phantom Treads | boots | Storied | a dodge quickens your walk by 20% for 2 s; rolls keep you untouchable a moment longer |
| Emberkin Mantle | cloak | Storied | once a floor, falling below a fifth of your health heals 25 over 2 s |
| Heartstone | amulet | Storied | +16 health; 1 health back every 3 s while no monster has noticed you |
| Spellweave Ring | ring | Storied | every third spell you cast costs nothing |
| Reaver's Greatsword | greatsword | Storied | kills restore 4 health and 4 essence to your hand's mark |
| Bastion Plate | plate | Storied | once a floor, falling below 30% health raises a 30-point barrier for 6 s |

**Hunter's Keen Eyes** outline gear on the floor in its rarity's colour, even through the dark.

**Wear.** Only **Common** pieces wear, and pieces with traits never will. Each use takes a little condition off the pieces it uses: a landed swing wears your melee weapon and gloves, a shot your bow or crossbow, a blow that lands on you your chest, helm, legs and cloak, a roll or jump your boots (`WEAR` and `WEAR_BY` in `gear.gd`; a piece used all climb long gets badly worn near the end of it). At **25%** a piece is **badly worn**: its bonus is halved (a chest piece protects half as much; a weapon hits 25% softer), it shows cracks on its icon and its card says so. At **0** it **breaks** and its slot is empty: a broken weapon leaves you your fists until you find another. Each piece's condition shows as a thin bar under it in the inventory. Heirlooms start every climb in full repair.

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

**Heirlooms.** Survive a climb (beat its beast, or reach the Regard on the first climb without falling) and, after the victory screen, you choose **one** piece you wore to keep as an **heirloom**: a card for each slot you fill (any piece already kept is left out), and one to keep nothing new. Your **rings** share one card and are kept **together**. With many cards they sit in two rows. Every later climb starts with your heirlooms in their slots, in full repair. Each slot holds one heirloom (Rings holds both rings); keeping another piece for the same slot replaces it. The heirloom slots are **melee**, **ranged**, **chest**, **helm**, **gloves**, **legs**, **boots**, **cloak**, **amulet**, **rings** and **backpack**, with **off-hand** kept for later. There's one free heirloom per survived climb. The **inventory**'s Heirlooms view shows them on the same body layout, and the climber screen's Record tab lists them. Starting a new climber forgets them. Slots and text live in `HEIRLOOM_SLOTS` and `HEIRLOOM_TEXT` in `scripts/gear.gd`; heirlooms are saved with your profile as records.

The dev tools have a **Gear** row: a button for every weapon, armor and worn piece, and one to take off every piece, to try them at once; a **Finds** row drops a Fine, Rare or Storied find (or any named piece) at your feet, and an **Items** row puts any item on your belt.

## Items and camps

**Items** (`scripts/items.gd`, where their names, text and numbers live) are carried on your **belt** through the climb. The belt holds **4 kinds** of item, up to **3 of each** (a Satchel or Climber's Pack: 4 of each; a Belt Pouch or Climber's Pack: a fifth kind; the recall scroll is always one). Walk onto a new kind with a full belt and the **take card** opens (the monsters wait): swap one stack out (it's left where you stand) or leave the new item on the floor; either way it waits until you step off and back on. A camp's or vault's item with a full belt is left at your feet. **G** (or the Item button) uses the selected item and **T** (or the small arrow) picks the next; **hold** G, the Item button, X or the d-pad down to open the **item ring**: time slows, point at an item (the mouse, a stick, or slide your finger from the button) and let go to use it. A quick tap never opens it. The HUD shows the selected item beside the weapon, with its count; the inventory (I) shows the belt, with an empty cell for each kind it has room for. An item that would do nothing (a draught at full health, a vial with full marks) isn't used up.

| Item | Essence | What it does |
| --- | --- | --- |
| Healing Draught | Stone | heals 40 health over 1.5 seconds |
| Cleansing Tonic | Water | cures poison, heals every burned body part, and a little health |
| Essence Vial | Water | fills every mark with essence |
| Smoke Bomb | Fire | a cloud of smoke around you: monsters inside lose track of you (beasts don't) |
| Fire Flask | Fire | thrown where you aim (it stops short of walls): bursts for 30 (+10% a floor) and leaves the floor burning for 3 s (it burns foes, not you) |
| Edge Oil | Blade | strikes hit 25% harder for 20 s |
| Warding Oil | Iron | a 25-point barrier for 15 s; traps can't hurt you while it holds |
| Haste Draught | Air | walk 25% faster and rolls cost 30% less for 10 s |
| Stoneskin Draught | Stone | 20% damage taken off (it counts toward the 50% cap) and no knockback for 12 s |
| Second Wind Salts | Iron | stamina full at once, refilling 50% faster for 8 s |
| Flare Powder | Air | lights the room for 20 s; hidden traps and secret walls nearby glint |
| Recall Scroll | Air and Water | only from vaults, one at most: read it to leave the tower safely, keeping everything (see **Sealed wings, vaults and secrets**) |

Every climb starts with one Healing Draught. Slain monsters (not beasts) sometimes leave an item (8%); walk over it to pick it up. Warding Oil and Stoneskin Draughts are never dropped by monsters; camps and vaults offer them.

**The belt at the end of a climb.** Survive a climb (beat its beast, reach the Regard without falling, or read a recall scroll) and whatever is left on your belt breaks into **essence crystals** at half its worth, one crystal per essence (`value` and `BREAK_SHARE` in `items.gd`); the victory screen says what it became. Fall and it's lost.

**Bonds and items:**

- **Ashwalker:** Smoke Bombs last twice as long.
- **Flameblade:** Edge Oil builds heat twice as fast.
- **Flame Contractor:** Fire Flasks burst 50% wider (and a foe they kill leaves Kindled ground, as with your other fire).
- **Hunter:** Keen Eyes outline dropped gear in its rarity's colour; Flare Powder lasts twice as long.

**Camps.** On a full climb, the stairs of floors 3 and 9 lead first to a **camp** (`CAMP_AFTER` in `items.gd`): the open room with a campfire and no monsters. You rest fully (all health and stamina, burns and poison healed), then choose one of four cards (keys 1 to 4, the arrows and Enter, the d-pad and A, click, or tap): three items, or a piece of gear (taking it leaves your old piece by the fire). Then take the stair on to the next floor (a camp isn't a floor: after floor 3's camp comes floor 4). Each camp comes once a climb; the bondless first climb has none.

- **Surgeon's Steady Hands:** healing items heal 30% more and work faster.
- **Rune Artist's Runesmith:** after taking an item at a camp, a Rune Artist also chooses a rune for their gear (Sharpness, Warding or Swiftness, as with Inscribe) that lasts the rest of the climb, the beast included, or crafts one more item. Casting Inscribe still changes the rune for one floor.

## The train (between climbs)

After the Regard, every climb ends on **the train**, a steampunk train waiting outside the towers, whether you won, fell or read a recall scroll, and every climb starts from it (the first climb is bondless and has no train: it appears with the Regard). For now it's a menu over a train drawn in code (brass trim and rivets, lit windows, smoke from the stack); a walkable train can come later. Its cars are tabs (**Q** / **E**, **LB** / **RB**, or tap one), with your **crystals** (a gem and how much essence you hold of each kind) and a **Menu** button along the bottom; Esc (Start) opens the menu, and closing any page returns to the train. The words, prices and numbers live in `scripts/train.gd`.

- **Your car:** your heirlooms (the paper doll, as in the inventory), your **pack** and your **storage chest** (8 spaces, `CHEST_SIZE`). Choose a piece to move it between pack and chest, or sell it. The chest is safe between climbs; the pack goes up the tower with you, and as you enter you put on any pack piece whose slot is empty (or holds only the starting sword or bow, not an heirloom). On a phone, Chest and Heirlooms take turns.
- **The store car**, kept by **the outfitter**: a retired climber who buys what climbers bring down and sells it to the next ones up (his lines are in `OUTFITTER`; he has no name yet). **Supplies**: consumables packed onto your belt for your next climb (as much as the belt holds, beside the starting draught; put one back for its full price before you go). **Outfit**: a rack of 8 Common pieces, new every visit, bought into your pack. **Today's piece**: one Fine or Rare piece, new after every climb. **Sell**: a piece from your pack or chest becomes a crystal of its kind at 40% of its price (`SELL_SHARE`; worn Common pieces fetch less); the button asks once ("Tap again to sell").
- **The workshop car:** its bench is still being fitted (brewing, tempering and joining come later).
- **Depart:** a card for each tower (its essence and your best floor there). Choose one and the climb begins; your pack and supplies come with you.

**Money.** Essence crystals are the only currency. Every price is in one kind of essence (a consumable's own kind; a piece's trait or named kind, else its slot's: chest and helm Stone, gloves and melee Blade, legs, ranged and backpack Iron, boots and cloak Air, amulets Fire, rings Water), shown as a gem and a number, red when you can't pay; the card says why in words ("needs 12 more Fire"). The outfitter takes your **smallest crystals of that kind first**; if they hold more than the price, the rest comes back as **one new crystal** (change). Prices: a Common piece's `BASE_PRICE` (8 to 20) times its rarity (Fine x2, Rare x4, Storied x8); consumables cost their worth in `items.gd`. The Entity explains the train, the store and the chest the first time you see each. The chest, pack, packed supplies and the store's stock are saved with your profile (the `train` section; old saves load with an empty chest).

## Essence density (attributes)

Each essence type is an attribute: Air is Agility, Blade Strength, Stone Vitality, Iron Will, Fire Intellect and Water Spirit. Every bit of essence you bank at a stair settles in you as **density**, by type and in the body parts that earned it (split by what each part did that floor), and it's kept between climbs. Each type gives a small passive bonus that grows with diminishing returns up to 12%: Air move speed, Blade strike damage, Stone health, Iron stamina recovery, Fire spell power, Water how fast your marks fill. The **climber screen** (Tab) shows your six body parts with their marks, and its Essence tab your density and bonus for every type and the essence settled in each part.

## Menus and the dev tool

The game opens on a **title screen** that covers the whole game: a tower drawn in code against a night sky, with lit windows, a moon, mist and drifting motes in the six essence colours (`scripts/title.gd`; the name, tagline and footer text are in its `TEXT` list). Its buttons are **Continue** (or **Begin your first climb** for a new climber), **Climber**, **Settings**, **Dev tools** and **New climber** (only once you have marks to lose), with a line showing your marks and best floor. Arrow keys and Enter, a controller (d-pad or left stick to move, A to press), the mouse, or a tap all work; Esc does nothing there. The focused button has a gold outline, and the first one is focused when a page opens. Pages opened from the title show over its backdrop and **Back** returns to it. Leaving the title takes you to the tower choice (after the Regard, to the train).

During a climb there are three screens, and each pauses the game while it's open (menus fade in and out quickly):

- **Pause menu:** **Esc** or **P** (**Start** on a controller, **Menu** on a phone). Resume; Climber and Inventory; Settings and Controls; the Entity's **Archive** and Dev tools; Restart this climb and New climber (it asks first); and **Exit to title**. On a computer there is also **Quit game**; in a browser or on a phone Exit takes you to the title instead.
- **Climber screen:** **Tab** (a short press of **View / Share**, the **Climber** button on a phone). Your character sheet, in four tabs (switch with the buttons, or **Q** / **E**, **LB** / **RB** on a controller; the screen reopens on the tab you used last): **Marks** (the climber drawn in full, hooded and cloaked, with each mark glowing on its body part in its bond's colour and a thin ring of the essence settled there, beside a card for each body part with its mark's medallion, step and growth), **Essence** (density and attribute bonus for each type, the essence settled in each body part, and what you carry unbanked), **Record** (the Entity's record of you: this climb's tower and floor, your counters, each tower's best floor and your heirlooms) and **Archive** (everything the Entity has told you; see below).
- **A mark's page:** choose a card on the Marks tab (click or tap it, or focus it and press **Enter** or **A**). It shows the mark's emblem, its body part and essence, its step and growth (and the banked essence each step needs, or the essence a faint mark still owes), its **Body** and **Passive** effects, and **every spell**: the step that teaches it, how to cast it, its cost, wind-up and other numbers, what it does and what each later step changes. Spells not learned yet are dimmed with a lock and "learned at step N". The steps are listed at the bottom with what each brings. An unmarked part's page says what soaks into it and, where your next mark is forming, which bond it would be. **Q** / **E** (**LB** / **RB**, or the buttons either side of Back) show the next mark; **Back** (**Esc**, **B**) returns to the cards, and **Tab** closes the screen. **Up** / **down** scroll the page.
- **Inventory:** **I** (**d-pad up**, the **Bag** button on a phone). A **paper doll**: what you wear, laid out like a body (helm, amulet, cloak / melee weapon, chest, ranged weapon / ring, gloves, ring / backpack, legs, boots), with fists, the off-hand (locked, for later), gear lying at your feet (marked "new") and a camp's rune beside it, and your belt below: its items with their counts (the quick item gilded) and an empty cell for each kind it still has room for. **Worn / Pack / Heirlooms** at the top switches the doll to your pack's spare pieces or your heirlooms. On the train, I opens your car instead. The weapon in hand is gilded, empty slots show their name, Common pieces show their condition as a thin bar, finer pieces are edged in their rarity's colour, and a piece that is also your heirloom has a small gold mark. Focus or tap a slot to see its card on the right: what it does, its traits (each in its essence's colour), its rarity and condition, and its numbers set against the gear at your feet or what every climb starts with (green up arrows where it's better, red down arrows where it's worse), with a "plays like" line for weapons ("Compared with yours: hits harder, slower"); the gear at your feet against what you wear, with **Take it** (or, with two rings on, a button to swap either ring); or an item's text with **Use** (or press the item's slot again) and **Make it your quick item**.

The same key closes its screen (Tab closes the climber screen, I the inventory), and **Esc** or **B** (Circle) goes back a page, or out of the menu from the pause menu or a screen opened by its key; every page shows its Back or Close button with the keys that do the same. **Settings** has music and sound volume, screen shake, the on-screen controls list (off at first), the **HUD size** (small, normal or large), and the Entity's **guide tips** (on or off, and **Replay tips**); they're saved. The Entity presents Settings and the Record: its face and a line sit at the top of both. The **Controls** page lists every key and controller button side by side. On a phone the climber screen and inventory tighten up to fit the screen without scrolling.

The menus and HUD share one look: the interface colours, panel and slot styles, text sizes and the drawn pieces (bars, essence gems, mark medallions and emblems, key badges, locks) live in `scripts/ui.gd`; the item and gear icons are drawn in `scripts/items.gd` and `scripts/gear.gd`, filled, outlined and shaded like the characters. Each mark's emblem follows its essence: Air a three-bladed swirl, Water a drop, Fire a flame, Stone a cut gem, Iron a shield, Blade a four-pointed star. The HUD is kept small so the tower gets the screen. Always there, top left: slim health (with the numbers on the bar) and stamina bars, the weapon in hand and the quick item (small, with its use key and count), and a small medallion per mark that fills with essence and glows once a spell can be cast (on a phone the mark's button lights up too). The rest fades in only when it matters: the essence you've gathered since the last stair (when you pick some up), your three weapons for a moment when you swap, the floor's title when you arrive, the open stair, and for the first seconds of a floor the keys for the menu, climber screen, inventory and controls (H shows every key). The weapon slots, the armor, every item, your attributes and where your next mark is forming are on the climber screen (Tab) and in the inventory (I). On a computer, hovering the mouse over a HUD slot or mark shows what it is and its numbers. The HUD's always-there part is only redrawn when one of its values changes, and the touch buttons too, which keeps phones fast.

The **dev tools** page is for testing (`scripts/menu.gd`, with the actions in `main.gd`):
- **Marks:** give any bond to any body part with the arrows, and set its step from 1 to 5. Changes are saved, and giving a mark ends the bondless first climb. Fill essence, or clear every mark.
- **Climb:** move to another tower, change floor, or go straight to the tower's beast.
- **Practice a beast:** fight any of the six beasts at once, at full health with full marks.
- **Spawn a monster:** any monster or beast, near you.
- **Gear:** give yourself any weapon or armor (it replaces what's in that slot).
- **Puzzles:** put one kind of puzzle on every floor of rooms (or back to the usual mix), and go to a floor of rooms to try it.
- **Cheats:** no dying (a killing blow leaves you at 1 health), heal, clear the room, and show traps (outlines every trap and its reach, hidden ones too).

## The Entity: tips, the Archive and the Record

**The Entity** is a small, mysterious presence: a softly glowing orb with two dark eyes and a wry little mouth, drifting sparks and a gentle bob, drawn in code. It watches the climber, as the beast does, but it isn't the beast, and it never explains the story (that's still to be written). Its name and everything it says live in `scripts/entity.gd`, in plain data, so it's easy to rename or rewrite: `TEXT` (its name and the words around it), `LINES` (short lines for moments and pages) and `TIPS` (each tip's line and a fuller account for the Archive, in the groups of `GROUPS`). In the text, `{move}`, `{attack}`, `{roll}` and the like become the keys, controller buttons or touch buttons for whatever the climber is using (`KEYS`).

**Tips.** The first time the climber meets something new, the Entity says a line or two about it in a bubble at the top right (on a phone, under the Bag, Climber and Menu buttons, clear of the joystick and the action buttons; on a short screen it slides left of any cast button). One bubble at a time: the rest wait their turn. A tip never stops the game; it fades after 6 to 12 seconds, and a tap or click on it, **Enter**, or a press of the right stick dismisses it at once. Bubbles wait while a menu is open or the screen is black between floors. Each tip is said once per save (the "guide" section of the save file). The tips: the Entity itself and the first steps (at the start of a climb), the glint (a monster's first glint), falling, essence (the first essence gathered), banking at the stair, the Regard, casting and the climber screen (a climb with marks), overdraw (a burned mark), a new mark, the open stair, rooms and fog, room names, good rooms, monster dens, restless crypts, doors (the first door opened), locked and sealed doors (for doors to come), chasms (near one) and falling through one, camps, the Proving, the beast, the ward, puzzles (each kind, the first time you walk into its room), traps (the first warning), trap rooms, hidden traps, gas vents, poison, gear on the floor, worn pieces (the first helm, ring or other worn piece found), rarities and traits (the first find better than Common), heirlooms, items, the belt (once it's full), the item ring (once you carry two kinds) and the inventory.

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
- A cell or two beside the spine is kept for a **sealed wing**, and sometimes one for a **secret room** (see **Sealed wings, vaults and secrets** below).

**Rooms.** A room is either **hand-made**, drawn as a small text grid in `scripts/rooms.gd` (one character per tile: walls, pillars, chasms, pools, monster spots and random tiles), or a shape **carved** in its tower's style: plain, open, a long hall, an L, a cross (corners notched), round (corners cut) or pillared (`SHAPES` in `rooms.gd`; each tower's favourites are its `shapes` in `towers.gd`: the Kraken's tower likes halls and L-shapes, the Wyvern's pillared rooms, and so on). Hand-made rooms suit their job (calm start rooms, combat rooms, stair rooms, puzzle rooms), flip at random so they don't repeat exactly, and never appear twice on a floor. A wall that touches a room's edge becomes part of its outline; one standing free inside is a low wall you can hide behind (it blocks movement, sight and shots). The game checks that the stair, every monster and the cache can be reached (any low wall that would cut one off is left out). To add a room, copy one in `rooms.gd` and draw your own.

**Corridors and doors.** Corridors are two tiles wide and run straight from one room's wall to the facing wall of the next, as near the middle of both walls as the rooms' shapes allow, so they never cut through a room and what's drawn in it stays as drawn. Stone posts frame each doorway. Many doorways have a **door** (`scripts/doors.gd`): likelier on rooms where danger waits (three in four on dens, crypts, the stair landing and the puzzle room; one in three elsewhere; never on the start room). A closed door is solid: it blocks the way, shots and sight, so a room behind one stays dark until you open it. Walk up to a door and it swings open (a thud and a puff of dust); awake monsters open doors too. A door's look hints at the challenge inside, never the reward: plain planks for an ordinary room, iron bands, claw marks and bones at the threshold for a den, an engraved sigil of the hazard (wind, a wave, a flame, spikes, an ember, thorns or a chasm) for a trap room, a stone door with the puzzle's emblem (an eye or a plate) for the puzzle room, warm light under the door for a good room, and chains and a red glow for danger (a crypt, the stair landing), and a dark stone slab carved with a watching eye for a sealed wing.

**Room themes.** Every room has a **theme**: what it is (`scripts/themes.gd`, where the names, rules, tints and door looks live, all easy to rename). The first time you walk into a themed room its name and one-line rule show across the screen, for example "MONSTER DEN: Bones and claw marks. Something lives here." Each theme also washes the room's floor in its colour (with bones in a den, scorch marks in a furnace). Themes are given by rules, not pure chance: the start room is the **Arrival Hall**, the stair room the **Stair Landing** (its guards wait there) and the gallery takes its puzzle's theme (**Hall of Statues**, **Hall of Mirrors**, **Hall of Stones**, **Ice Hall**, **Essence Lock**, **Hall of Pedestals**, **Hall of Eyes** or **Weighing Room**). Of the other rooms, the first is always a good room and the second a **Monster Den**; after that comes a mix, with no bad theme twice a floor, a cap on bad rooms (3 up to floor 3, then 4), each tower's own themes twice as likely, and a theme that doesn't fit its room swapped for one that does.
- **Good rooms:** a **Healing Spring** (stand in the pool to heal until it runs dry), a **Forgotten Cache** (an urn of the tower's essence: walk onto it for a burst, more on higher floors; sometimes it holds gear), a **Fallen Climber's Camp** (a cold fire, a bedroll and an item left behind), and each tower's own (the Gryphon's Windswept Aerie, the Kraken's Tidepool, the Wyvern's Cold Forge, the Manticore's Hidden Oasis, the Firebird's Ember Pyre, the Chimera's Thornwild Nest). Two at most a floor, and no traps in them.
- **Bad rooms:** the **Monster Den** (more of the floor's monsters wait there), the **Restless Crypt** (from floor 3: its dead rise when you walk in), the **Pillared Hall** (archers like it), the **trap rooms**, each laying its own set piece of traps (see Traps: the Spike Gallery, Dart Hall, the Furnace and Miasma Hall in any tower, plus each tower's own: the Gryphon's Windhall, the Kraken's Sluice Hall, the Firebird's Emberfall and the Chimera's Bramble Hall; every floor from 2 has one), and in the Firebird's tower **the Chasm**, a band of chasm right across a room. A quiet room is just a **Quiet Hall**.

Monsters wait in the rooms: most in the den, some guarding the stair, the rest along the route and in the branches, never in the start room or a good room (hand-made rooms' marked spots first). A monster stays put until it sees you (or you come close, or it's hit), then rouses its neighbours and finds its way to you around the walls (a path grid, `AStarGrid2D`). Monsters can't attack what they can't see, and walls stop every shot. Each room has one torch on its north wall.

**Fog.** On floors of rooms you see only what your climber can see: walls block sight (chasms, water and pillars don't), places you've seen stay dimly mapped, and places you haven't are dark. Monsters out of sight are hidden until you see them (`scripts/fog.gd`), and closed doors block sight like walls. The cache's and spring's numbers live in `CACHE` and `SPRING` in `scripts/floors.gd`. In the Firebird's tower the rooms' chasm tiles are real chasms, and every floor has a chasm to jump (a Chasm room, or failing that a long corridor cut by one); elsewhere chasm tiles are walls. In the Kraken's tower the rooms' pools fill with water. Once the stair opens, an arrow at the edge of the screen points the way.

**Puzzles and the ward.** Every floor of rooms has a puzzle in its **gallery**, and its stair is **warded**: it won't open, however many monsters fall, until the puzzle is solved. It's all part of the Regard: the beast watches, and tests. A main puzzle never needs a bond, an item or a piece of gear, only what every climber has (strikes, a bow, rolls, jumps, parries, walking), and it can never lock you out. Each kind is **generated** at random and **checked by a solver** before it's used, so it's always solvable, and it gets harder up the climb: **tier 1** on floors 2-3, **tier 2** on 4-8, **tier 3** on 9-11. The rule text stands **in the world**, in a framed panel near the puzzle that the darkness doesn't dim (with "The beast is watching."). Eight kinds so far:

| Puzzle | How it's made and checked | How to solve it | Harder higher up |
| --- | --- | --- | --- |
| **Three Statues** ("The Riddling Statues" in the Manticore's tower) | Three statues before three plates, each saying something about where the way lies or about each other; a plaque gives the rules (one always tells the truth, the other two always lie). Statements are drawn at random until **exactly one** plate fits every way the roles could be shared out. | Walk up to a statue to hear it. Stand on the plate behind the true way for a second. | Tier 2: at least one statement about another statue's honesty. Tier 3: two statements each, and one statue **alternates** (one true, one false). |
| **Beam and Mirrors** ("Wind Mirrors" in the Gryphon's tower) | A lamp throws a beam across the room's tiles. The generator walks a path with turns (never crossing itself, only over open floor), puts a mirror at each turn, then scrambles them so the beam misses; a solver tries every way the mirrors can face. Walls stop the beam. | **Strike or shoot** a mirror to turn it. Hold the beam on the sigil. Auto-aim turns to the nearest mirror. | 3, 4, then 5 mirrors; decoy mirrors from tier 2; one **fixed** (iron-bound) mirror at tier 3. |
| **The Crumbling Path** ("Ember Path" in the Wyvern's tower) | A grid of stones in the middle of the room, maybe with holes (pits). A search confirms a route exists that steps on every stone exactly once, starting from the edge. | Step on every stone once. Each lights as you step on it; going back onto a lit stone **hurts** and puts the path out, and so does breaking the path (stepping to a stone not beside the last) or wandering off it. Even a jump's shadow wakes the stones. | 5x3 stones; 5x4 with a hole; 6x5 with two holes. |
| **The Ice Hall** ("Tide Slick" in the Kraken's tower) | The hall's floor is ice with rocks frozen in it, inside a ring of plain floor. Rocks are scattered at random; a search over every slide from every way onto the ice finds how many slides each resting place needs, and the **dais** goes on one needing at least 2 (the most it can, up to 3 more). Layouts where you could get stuck are thrown away. | Once on the ice you **slide** along the tile grid until a rock stops you (or off the far side back onto the floor); any push of the stick, keys or touch stick picks the nearest of the four directions. No rolling or jumping there. Come to **rest** on the dais. A blow sends you sliding; a monster in your lane stops you short. Getting it wrong costs nothing: slide off and walk round. | The dais needs at least 2, 3, then 4 slides. |
| **The Essence Lock** ("The Hungry Lock" in the Chimera's tower) | A lock whose riddle names one of the six essences (riddles are data in `lock.gd`). Once you're well inside, foes appear glowing in the answer and in **decoy** essences, each with its essence's sign over it. | Slay a glowing foe and it leaves a **spark**: walk over it to carry it (one at a time) to the lock. The wrong spark brings an ambush, then a new riddle. A **spell from a mark** of the right essence cast beside the lock, an **item** of it used there, or a strike from a **weapon** of it (a named piece or a trait of that essence) answers at once, and never fails. | Tier 1: two decoys; tier 2: three; tier 3: two or three essences **in order**. |
| **The Hall of Pedestals** ("The Remembered Fires" in the Firebird's tower) | A row of pedestals, each carved with a sign. The order is kept in numbered **murals** set in the north walls of **other rooms** of the floor (never behind a locked door). The hall's panel counts the murals you've found. | Strike or shoot the pedestals in the murals' order. The first wrong one brings an ambush; then try again. | 3, then 4 signs; tier 3 adds a pedestal no mural shows. |
| **Hall of Eyes** (a hand-made room) | Stone eyes behind low **rails** (rails stop walking but not sight or arrows). | Hit every eye, with a strike or an arrow over the rail. Auto-aim turns to the nearest unlit eye. | Tier 2: an eye stays lit only a couple of seconds, so light them all together; tier 3: shorter still. |
| **Weighing Room** (a hand-made room) | Pressure plates that need a **weight**: the climber is too light. | Push a **stone block** onto each plate (walk into it for a moment and it slides a tile), or lure a monster onto it. Strike the **lever** to put the blocks back. | More plates. |

Each tower favours its own (the Gryphon mirrors, the Kraken the ice, the Wyvern the crumbling path, the Manticore the statues, the Firebird the pedestals, the Chimera the lock: half its floors).

**How puzzles meet combat.** Low down a puzzle is **quiet**: it sleeps ("The statues will not speak while blood is spilled") until the monsters in its room are dead. From floor 7 it's **pressure**: it wakes at once, and while you're in its room the beast sends a monster every few seconds (two at a time at most), so you think while you fight. Some puzzle rooms **seal** when you step in (the statues, the crumbling path and the lock from tier 2, the mirrors at tier 3; never the ice or the pedestals, whose way back is through the door): the doorways grind shut until the question is answered. A **wrong answer** (a wrong statue plate, a wrong spark, a pedestal out of order) brings an **ambush** and opens the seal so you can fight or run; once the ambush is dead (or after 40 seconds at most) the puzzle **resets**, the statues with a new riddle. It never stays shut.

**Bonds that break puzzles.** Some bonds give a **shortcut** (never needed; the panel says so when you have one): the Windwalker's **Crosswind** turns every mirror its wall of wind passes; the Hunter's **Keen Eyes** shows which statues lie after a few moments near them; the Flamewing's **Phoenix Glide** passes over the stones unfelt, so you can cross a lit one; the Stormcaller's **Static** makes a woken eye spark to the nearest sleeping one; the Sandshaper's **Rooted Stance** is heavy enough to hold a plate down.

Solving lifts the ward ("THE WARD LIFTS"), opens the stair (and a seal), and gives a burst of the tower's essence (behind a **gate** in the hand-made rooms). Floor 1 and the beast's floor have no ward: there the stair still opens once three quarters of the monsters are down. Each kind lives in its own script in `scripts/puzzles/` (`statues.gd`, `mirrors.gd`, `crumble.gd`, `ice.gd`, `lock.gd`, `memory.gd`, `eyes.gd`, `plates.gd`, each with its names, rule text and shortcuts as data at the top); `catalog.gd` picks which floor gets which and how hard; `scripts/puzzle.gd` is the host that runs one (the ward, the reward, the seal, quiet and pressure modes, failure and the ambush, auto-aim and the rule panels). The dev tools' **Puzzles** buttons put one kind on every floor of rooms (use the floor buttons to try each tier).

**Traps.** Traps are the beast's tests, laid **on purpose** and meant to be hard (`scripts/traps.gd`, where the names, timings, damage and placement rules live):
- **Trap rooms.** Every floor from floor 2 has at least one trap room (a room theme, see Room themes), and its traps are a **set piece built out of the room's own shape**: rows across its short side, slots in its two long walls, vents at its two ends. All the traps of a set piece keep **one shared beat**, so the pattern can be learned; higher up the beat quickens, the rows close up, and a second wave runs between the first (from floor 7). From floor 4 **monsters wait among the traps** (one, then two from floor 8), so you fight inside the pattern. The room's one-line rule only hints at how it works.
- **Traps may block the way.** A set piece can run right up to a doorway, and a spike patch spans a corridor on the way to the stair, so you must cross it.
- **Guards.** From floor 3, spikes ring the cache's urn two tiles out, rising one after another around the ring.
- **Corridors** hold one spike patch a floor (two from floor 7), all on one beat, some of its spikes hidden.
- **Hidden plates** (one to three a floor) can be anywhere but on a door itself.

| Room (tower) | The set piece | How to get through |
| --- | --- | --- |
| **Spike Gallery** (any; the Manticore's favourite) | rows of spikes across the room's short side, each row a beat behind the last: a wave rolling down the room (two interleaved waves from floor 7); some spikes are hidden | follow the wave across, stepping into each row just after it drops; roll or jump |
| **Dart Hall** (any) | slits in both long walls fire darts across the room, one wall then the other, half a beat apart; a dart only hurts where it is in its flight | listen for the click and watch the slit's eye redden; cross a line just after its dart passes; roll (jumping doesn't help) |
| **The Furnace** (any from floor 3; the Wyvern's favourite) | grates at both ends breathe fire toward the middle in turns, one half of the room, then the other; a line across the middle never burns, and **one side is always safe** | cross the half that has just burned, wait on the middle line, then cross the other; roll |
| **Miasma Hall** (any from floor 4; the Manticore's and Chimera's favourite) | cracked vents breathe choking gas one after another down the room; a path of pale **clean stones** winds through where the gas never reaches | keep to the clean stones: **linger in a cloud and it will kill you** |
| **Windhall** (Gryphon) | gust lanes blow across the room toward a long wall lined with spikes, lane after lane; the spikes rise just as a gust lands you on them | cross between the gusts, or roll through one |
| **Sluice Hall** (Kraken) | water sweeps down the hall from one end, the rows taking turns, knocking you along and slowing you; a pillar or two stand in the flood | step into the dry row, or shelter behind a pillar; roll |
| **Emberfall** (Firebird) | embers fall on scorch rings a column at a time, a wave sweeping down the room, and the floor burns after; higher up the rings close up into walls of fire, and from floor 9 more fall between them, half a beat apart | watch the rings warm and keep moving; roll or jump |
| **Bramble Hall** (Chimera) | brambles fill the room, with snares among them (more of them hidden higher up); a snare's snap **wakes the pack**; a trodden path winds clear through | keep to the path; once held, a roll breaks free |
| **The Chasm** (Firebird) | a band of chasm right across the room, its ends left open where a doorway meets it | jump it; fall in and you drop to the floor below (no harm done) |

**Hard to spot.** A trap at rest shows only a faint tell on its tile (a few small holes, a grate, cracks, a scorch ring, a slit in the wall), never its reach, and it's drawn under the darkness, so you only see it where your light or a torch falls. **Hidden** traps show nothing at all until you're right on top of them. The Hunter's **Keen Eyes** shows every trap, outlining the hidden ones in gold; the dev tools' **Show traps** outlines every trap and its reach.

**Short warnings.** Just before it fires a trap gives a short tell, never a flash: a click or a hiss, spikes peeking out of their holes, a grate shimmering, a slit's eye reddening, a wisp of gas, a ring warming. Grates, slits and rings also give a small glint in the last moment (0.25 s); spikes, snares and gas don't. A hidden plate, once stepped on, gives you even less time (0.3 s) to get clear. Only fire and falling embers light the dark. Traps **hurt badly** (about 10 to 28, more higher up). Rolling through a firing trap counts as a dodge (feeding your legs), but only once per trap. Monsters that wander into one are caught too. The Manticore's and Chimera's towers also hide **gas vents**: set one off and a cloud spreads that keeps hurting while you stand in it; it can kill you if you don't get out.

**Never shut for good.** After the traps are laid, a **protection pass** keeps them off the start, the stair, the doors themselves, the puzzle room and the good rooms (only the cache's guard ring goes there), then searches the floor treating as walls only the tiles that are **never** safe (where overlapping beats leave no moment to cross). While the stair, the puzzle room, a healing spring or a camp can't be reached that way, it opens one such tile on the way (cutting a lane short there, or taking a trap away) and searches again. So the way through may be guarded, but a climber who times it, rolls or jumps can always get through. A chasm doesn't count: it's jumped. Monsters never wait on a trap tile, and nothing that matters ever sits in a chasm. The dev tools' **Speed readout** shows, at the bottom right, the frame rate and frame time, draw calls, node count, and how many monsters, traps and lights there are (to check for lag on a phone).

**Cheap to draw.** A trap at rest never changes, so every resting trap (and a set piece's path and brambles) is drawn once into a few squares of the floor; each frame only the traps warning or firing on screen (and hidden ones right beside you) are drawn, all in one batch, 30 times a second.

**The stair.** On floor 1 and the beast's floor the **stair** at the top of the room opens once three quarters of the monsters are down; on floors of rooms it opens when the puzzle lifts its ward. Walk onto it to climb, or finish the rest first for their essence (the HUD shows how many are left). Taking the stair is a rest: burns heal, you recover a third of your health and all your stamina. Each floor's monsters are bought from a budget that grows with height, and they get tougher too (`scripts/floors.gd`). Falling ends the run and sends you back to floor 1. Your best floor is saved.

## Locked doors and lock-in rooms

**Locked doors** (from floor 3, most floors have one, some higher floors two; `LOCKS` in `floors.gd`, the words in `LOCK_TEXT` in `doors.gd`). Only doors off the main route are locked (a branch room's or a sealed wing's), so the way to the stair never needs a key, and what opens a locked door is always found on the main route, so you can reach it without passing the lock. A locked door keeps its usual look (so it still hints at the room) with a lock drawn over it, never a hint of the reward; bump it and it stays shut with a clank, "Locked", and a line saying how it opens. Monsters can't open it either.
- **A padlock:** its key lies in another room (a small gold glint; walk over it), or **one of the floor's monsters carries it** and drops it when it falls. Walk up to the door with the key and it turns.
- **Iron bars:** a **lever** stands in another room; strike it and the bars lift, with a clank, a nudge of the camera and a banner.
- **A violet ward:** solving the floor's puzzle opens it.

**Lock-in rooms.** Some rooms shut their doorways behind you once you're well inside: monster dens (3 in 4), restless crypts (9 in 10), some guard rooms (3 in 10), the stair landing from floor 6 (3 in 5), and the sealed wings (`LOCK_IN` in `doors.gd`). Iron bars drop with a slam and a banner ("THE DOORS GRIND SHUT"), and the top of the screen says the doors are shut and how many foes are left (on a phone too). They open again when the monsters that were in the room are dead. A room with no monsters left never shuts, and two and a half minutes open it whatever happens, so you're never stranded.

## Sealed wings, vaults and secrets

Everything here is part of the Regard: the beast watches and tests, using what comes into the tower. Names, lines and numbers live in `scripts/wings.gd` (`TEXT`, `CONDITIONS`, `WAVES`, `REWARD`, `SECRET`) and `scripts/items.gd` (`RECALL`, `CRYSTAL`), so they're easy to change.

**Sealed wings** (from floor 2; one a floor, two from floor 10). A room of 9-11 by 7-9 tiles is carved into each kept cell beside the spine, joined by a corridor to its spine room, behind a **sealed door** (a dark stone slab carved with a watching eye, red light under it). Cut into one of its walls is a 3x3 **vault alcove** behind a one-tile vault door drawn as a **pulsing gold seal with a keyhole**, with warm light leaking out from under it, so you know from the moment you see it that a locked vault waits and that the room's question opens it. The seal's emblem shows the **challenge**, never the reward: a shield (take no hit), an hourglass (be quick), crossed blades (staggered kills), or a puzzle's emblem.
- **Walk in and the way shuts behind you:** the doorway grinds closed (solid to walking, sight and monsters' paths) with a slam and a banner: "The way behind you grinds shut. This room will not let you go until its question is answered."
- **The question**, for now, is a **challenge room**: two or three waves of the tower's own monsters and one rule, shown on screen with the wave and the clock: **Untouched** (take no hit), **Swift** (beat every wave within the time given) or, from floor 4, **Staggered** (every foe must fall while staggered: parry it, then strike).
- **Keep the rule** and beat the waves: the seal breaks, the vault opens, and so does the way out.
- **Break the rule** and either the waves go on and the vault opens with a **lesser prize** at the end, or the tower sends its **champion**: a bigger, tougher version of one of its monsters (three and a half times the health, crowned, a gold aura, and a ground slam telegraphed by a closing ring: roll out of it). Its fall reopens the way, but the vault's seal goes dark for good; the champion leaves an essence crystal where it fell.
- **You're never trapped:** every ending reopens the way out, and a question that drags on for four minutes gives up.
- **For puzzles later:** a puzzle host can claim a wing (its slot is `wing["puzzle_slot"]`): `puzzle.gd` answers `wing_puzzle(wing)` with a puzzle type (and `wing_emblem(type)` with the seal's emblem), gets `start_wing_puzzle(wing)` when the climber walks in, and calls `main.wings.wing_solved(id)` or `main.wings.wing_failed(id)` (a failure sends the champion).

**Vault rewards** are real things to walk up to: a **pedestal** in the alcove with a gold light over it. Walk up and choose one of its cards (like a camp's: keys 1 to 3, arrows and Enter, the d-pad and A, click or tap): two **essence crystals** of different kinds (the tower's own and another: a slight steer toward the next bond), and a piece of **gear** (the rarer of two), a **recall scroll** (only if you don't already carry one, and not on the first climb) or an **item**. A lesser prize is a smaller crystal and an item. The monsters wait while you choose.

**Essence crystals** hold essence outside you and are **kept between climbs** (in your save). Consume one from the **Inventory** (I, or the Bag button on a phone: the Essence crystals row, then **Consume one**) to bank its essence into you at once, as at a stair: your marks grow, and it counts toward which bond your next mark becomes. Or spend it at the train's store (see **The train**); crafting comes later.

**The recall scroll** (you carry one at most) shows with your items: make it your quick item (T, or the small arrow on a phone) and use it, or pick it in the Inventory and press **Read it**. It asks first; use it again within 3 seconds to read it. Reading it **leaves the tower safely, keeping everything**: your unbanked essence settles into essence crystals (one per kind) and this floor's soak is banked; there's no heirloom choice (the climb wasn't won); your pack comes with you, and you go on to the train. Its words won't come on the bondless first climb.

**Secret rooms.** Sometimes a kept cell holds a small room joined by a passage one tile wide whose first tile, in a spine room's wall, looks like any other wall. Until it opens, the passage and room are solid rock to sight, fog and paths. Its hints: **dust** drifting down near it now and then when you're close, a **hollow knock** when you strike it, and **Hunter's Keen Eyes** outline it. **Lean into it** (walk into it) for three quarters of a second and it grinds open; on a phone, push the stick into it. Inside: a hidden **essence cache** (more than a good room's, sometimes with gear), a choice of three **essence crystals**, or a **Tithe Door**: a pale door with an open hand carved on it, asking for unbanked essence (it says how much, never what it keeps). Lean on it to pay; the vault behind it holds a full vault's cards.

## What's in this build

- **The base climber.** Started very clumsy; now a bit tougher: 140 health, quicker on its feet, faster stamina recovery, cheaper rolls, a slightly wider parry window, and a longer grace period after being hit so a crowd can't chain-hit you.
- **Stormcaller on the hand.** Fills when your strikes land. *Chain Lightning* leaps between up to 4 foes (6 from step 3, and it stuns). Passive *Static*: striking a charged foe arcs to another.
- **Windwalker on the legs.** Fills when you roll through an attack. *Gale Lift* throws foes in front of you into the air, helpless for 1.5 seconds (a wider cone from step 3). Body: your roll becomes a long, cheap wind dash. Passive *Featherweight*: airborne foes take 50% more damage from your strikes.
- **Overdraw.** Cast without enough essence and the spell still fires, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and travel less. Burns heal at the next stair.
- **Marks and motes on the body.** Each bond shows as a sigil that grows lines with its step, circled by motes as its essence fills.
- **Gear.** Eight melee weapons, two bows and a crossbow, four suits of armor, and sixteen Common worn pieces plus Fine and Rare rings, amulets and a pack for the helm, gloves, legs, boots, cloak, amulet, ring and backpack slots; Fine, Rare and Storied finds with fourteen essence traits, sixteen named pieces (eight only in their own tower), caps on what gear adds, wear on Common pieces and a 50% protection cap (see **Gear: weapons, armor and worn pieces** above). *Bows*: hold to draw (you walk slowly while drawing and stamina stops recovering), release to loose. Damage and speed grow with the draw, and a full draw (a soft tick and ring tell you) pierces through foes. A quick tap fires a weak shot; rolling or getting hit drops the arrow. Weapons are plain data in `scripts/weapons.gd`, armor and worn pieces in `scripts/gear.gd`.
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
- Do Fine and Rare finds feel worth hunting, without the HUD filling up? Are the trait lines and "(capped)" clear on a phone?
- Is the item ring (hold the Item button, slide, let go) quick enough to use mid-fight, and does a tap still just use the quick item?

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
| `scripts/doors.gd` | Doors: solid until you walk up, styled to hint at the room behind; locked doors with their keys and levers; lock-in rooms |
| `scripts/wings.gd` | Sealed wings (the seal, the shut doorway, the challenge waves, the champion), vault pedestals and their cards, secret rooms (dust, knock, lean, caches, Tithe Doors) |
| `scripts/fog.gd` | Line-of-sight fog on floors of rooms (worked out up to 12 times a second; drawn by `lighting.gd`) |
| `scripts/lighting.gd` | The darkness layer: one shader over the world, the light registry (`add_light`, flashes), the fog and the vignette |
| `scripts/puzzle.gd` | The puzzle host: the stair's ward, the reward, the seal, quiet and pressure modes, failure and its ambush, auto-aim, rule panels, rails and gates |
| `scripts/puzzles/` | One script per puzzle (statues, mirrors, crumble, ice, lock, memory, eyes, plates) with its generator, solver and text; `catalog.gd` picks which floor gets which, and how hard |
| `scripts/towers.gd` | The towers: height (12 floors, the Proving on 6), beast, essence, monster mix, room shapes, look |
| `scripts/items.gd` | Items (names, effects, drop chances, worth, icons), the belt and its take card words, the item ring hold, bond notes on items, and what a camp offers |
| `scripts/campfire.gd` | A camp's campfire, drawn in code (its light comes from `lighting.gd`) |
| `scripts/enemy.gd` | Slime, archer and knight |
| `scripts/projectile.gd` | Enemy arrows |
| `scripts/fx.gd` | Floating text, lightning and wind cones |
| `scripts/hud.gd` | The small HUD (health, stamina, weapon, quick item, marks), the fading notices, overlays and the dev speed readout |
| `scripts/menu.gd` | Title screen, pause menu, climber screen, inventory, settings, controls list and dev tools |
| `scripts/train.gd` | The train between climbs: its cars, the store's prices, stock and words, the outfitter's lines, buying (with change), selling, the chest and departing |
| `scripts/train_page.gd` | The train's page in the menus: car tabs, your car, the store car, the workshop, Depart, the crystal bar, the outfitter's face |
| `scripts/train_view.gd` | The train drawn behind its page: dusk sky, the six towers, the engine and cars, smoke |
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
| `scripts/gear.gd` | Gear records, rarities and their odds by floor, traits, caps, named pieces (Storied and tower pieces), armor and the worn pieces, slots and the paper doll, drops, wear, protection, heirloom slots (and old-save conversion), comparing and gear icons |
| `tests/smoke_test.gd` | Headless test that drives every action |

## Testing

`tests/smoke_test.gd` loads the room and drives the climber through every action (combo, riposte, parry, arrow reflect, roll, both casts, overdraw, getting hurt, death, clearing the room), and checks gear and items too (rarity odds by floor, traits and caps, the belt and its take card, each consumable, the item ring, the belt breaking into crystals, the pack and the train: buying with change, a price you can't pay, selling, the chest's save, departing), then reports the results:

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
