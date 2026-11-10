extends RefCounted
## The Entity: the small glowing presence that guides the climber. It is the
## voice of the tips (the first time you meet anything new), the keeper of
## the Archive (everything it has told you), and it presents your Record and
## the Settings.
##
## Everything it says lives here, in plain data, so it's easy to rename or
## rewrite: its name (TEXT), its lines for moments and pages (LINES) and its
## tips with their fuller Archive text (TIPS, grouped by GROUPS). The story
## and what the Entity really is are still to be written: keep it terse and
## enigmatic. It watches the climber, as the beast does, but it is NOT the
## beast and never says so.
##
## In tips and Archive text, {move}, {attack}, {roll}... become the keys,
## controller buttons or touch buttons for whatever the climber uses (KEYS).
## guide.gd shows the tips in play; menu.gd shows the Archive, the Record
## and Settings with the Entity's face.

const UI := preload("res://scripts/ui.gd")
const Controls := preload("res://scripts/controls.gd")

## Its name and the words around it.
const TEXT := {
	"name": "the Entity",  # in the middle of a sentence
	"Name": "The Entity",  # at the start of one
	"tag": "THE ENTITY",  # over its speech bubbles
	"archive": "Archive",  # the page of everything it has told you
	"locked": "???",  # an Archive entry not met yet
	"kept": "kept in the Archive",  # under a tip
	"heard": "%d of %d heard",  # Archive progress
	"replay": "Replay the Entity's tips",
	"tips_setting": "Guide tips from the Entity",
	"record_title": "The Entity's record",
}

## Short lines for moments and pages. One is picked (they're said in the
## Entity's voice). {floor}, {beast}, {Beast}, {tower} and {mark} are filled in.
const LINES := {
	# Moments in play (after the first time, which is a tip).
	"death": [
		"Floor {floor}. I wrote it down.",
		"Again, then.",
		"The tower keeps count. So do I.",
		"That one taught you something. I hope.",
		"{Beast} didn't blink. Neither did I.",
	],
	"beast_slain": [
		"{Beast} yields. It will remember you.",
		"Well struck. I watched the whole thing.",
		"So that is how it ends. For it.",
	],
	"new_mark": [
		"{mark}. Your body keeps score.",
		"Another mark. {mark}. It suits you, mostly.",
	],
	"proving": [
		"The Proving again. Stand up straight.",
		"Floor six. It remembers you. So do I.",
	],
	"regard": [
		"Seen again. It never forgets a face. Nor do I.",
		"It looked at you. It will keep looking.",
	],
	# Pages the Entity presents.
	"settings": [
		"Adjust what you must.",
		"Change what you like. The tower won't.",
		"Quieter, louder. I'll wait.",
	],
	"record": [
		"I keep count. Someone should.",
		"Your record, as I have it.",
		"Every climb, every fall. Nothing is lost here.",
	],
	"archive": [
		"All I have told you, kept.",
		"Ask again. I don't mind repeating myself.",
		"What you've met, I've written down. The rest waits.",
	],
	"replay": ["Very well. I'll tell you again."],
	"climbers": [
		"Six may climb. Each keeps their own marks, crystals, train and record.",
		"Choose who climbs. Settings are shared; the rest is theirs alone.",
	],
	# The train, between climbs.
	"train": [
		"The train waits. It always does.",
		"Rest. The towers aren't going anywhere.",
		"Your car is as you left it. I checked.",
		"Steam and brass. You'd think it was going somewhere.",
	],
	"tips_off": ["As you wish. I'll still be watching."],
	"tips_on": ["Then I'll speak up."],
}

## The Archive's groups, in order: [id, name].
const GROUPS := [
	["start", "First steps"],
	["essence", "Essence and marks"],
	["secret", "Secret essences"],
	["tools", "Secret bond tools"],
	["unbound", "The Unbound"],
	["tower", "The tower"],
	["tests", "Puzzles and traps"],
	["gear", "Gear and items"],
	["train", "The train"],
	["screens", "Screens"],
]

## Every tip, in Archive order within its group: the Entity's line ("tip",
## 1 or 2 short sentences, shown the first time) and a fuller, plain
## explanation ("more", in the Archive). Ids are what code passes to
## main.tip("id"). An id that isn't here falls back to the part before its
## last "_" ("puzzle_mirrors" -> "puzzle", "door_iron" -> "door"), so a new
## puzzle or door kind still gets a tip until it has its own.
const TIPS := {
	# --- first steps ---
	"entity": {"group": "start", "name": "The Entity",
		"tip": "You can see me. Good. When something new finds you, I'll say so, and keep every word in the Archive.",
		"more": "The Entity is the small glowing presence that speaks in the corner of the screen. The first time you meet anything new, it says a line or two about it. Dismiss a tip with {dismiss}, or let it fade; it never stops the game. Everything it has told you is kept here in the Archive ({menu}, then Archive, or the Archive tab of the climber screen), grouped by subject; subjects you haven't met yet show as ???. Settings can turn the tips off (the Archive still fills in), and Replay tips makes the Entity tell you everything again."},
	"move": {"group": "start", "name": "First steps",
		"tip": "Walk with {move}. Strike with {attack}. Roll through what you can't stop; parry what you can with {parry}.",
		"more": "Strikes chain into a combo that ends in a heavy finisher; each one costs stamina, and stamina waits a moment after you attack before it refills, so mashing leaves you winded. A roll ({roll}) makes you untouchable for a moment and costs stamina. A parry ({parry}) on time takes no damage, staggers the attacker and sends arrows back. A jump ({jump}) carries you over chasms and burning floor, but attacks still hit you in the air. Hitting a staggered foe is a riposte for 2.5 times the damage, and striking a foe from behind (a backstab) deals 50% more."},
	"glint": {"group": "start", "name": "The glint",
		"tip": "A white star and a ting: the blow lands a quarter second later. Parry on the glint, or be somewhere else.",
		"more": "Every monster attack keeps one rhythm: a wind-up, then the glint exactly a quarter of a second before the blow lands, then a recovery. Parry on the glint and it always works; parry a beat after it for a perfect parry (a longer stagger and more stamina back). Red circles and cones that can't be parried are for rolling out of. After an attack a monster is open for most of its recovery: a gold ring pulses around it and your hits deal 60% more. Traps glint too."},
	"death": {"group": "start", "name": "Falling",
		"tip": "You fell. What you carried this climb is gone. What you are is not.",
		"more": "Falling ends the climb. The gear and items you carried and any essence you hadn't banked are lost (lost pieces may turn up again; see Lost on the way down), and the next climb starts again on floor 1 ({restart}). Your marks and their growth, the essence settled in you, your heirlooms and your record all stay. On the first climb a fall still brings the Regard, but the mark it leaves is faint."},
	# --- essence and marks ---
	"essence": {"group": "essence", "name": "Essence",
		"tip": "That light flying into you is essence. It's only yours once you bank it at a stair.",
		"more": "Monsters leave essence when they fall, each kind its own type (Air, Water, Iron, Fire, Stone, Blade), and every kill also gives a little of the tower's own essence. It flies into you and is banked at the next stair you take. Fall before the stair and the unbanked essence is lost. Meanwhile your body soaks up what it does: the hand from strikes, the legs from rolling through attacks, the heart from taking hits, the brow from parries, the throat from hitting several foes at once, the back from backstabs and finishing blows."},
	"bank": {"group": "essence", "name": "Banking at the stair",
		"tip": "Banked. Your marks drink what you bring up the stair, not what you carry.",
		"more": "Every stair banks the essence you gathered on the floor below. A share of it (20% unless you change it in Settings) condenses into essence crystals instead, the train's money; only the rest is banked. Banked essence strengthens every mark you carry (essence of a mark's own kind counts double), up to step 5, and settles in you as density: each type is an attribute with a small passive bonus (the climber screen's Essence tab). Bonds grow across climbs, never within one. Taking the stair is also a rest: burns heal, poison is cured, you recover a third of your health and all your stamina."},
	"regard": {"group": "essence", "name": "The Regard",
		"tip": "The beast has noticed you. I noticed it noticing. Your most-used part bears a mark now.",
		"more": "The first climb is bondless and ends in the Regard: at its top the tower's beast takes notice, the body part you used most takes your first mark, and the essence you gathered most decides which bond it is. Fall during the first climb and you are still regarded, but the mark is faint: weaker until it has soaked up 80 more essence. Break a barrier on the first climb and the beast refuses to mark you instead: you are Unbound."},
	"casting": {"group": "essence", "name": "Casting",
		"tip": "Your mark answers to {cast}. Tap to cast; hold to choose a spell while time stands still.",
		"more": "Each mark is a bond with a body (an upgrade to a basic action), a passive, and spells learned as it grows (at steps 1, 2, 4 and 5; step 3 changes the first). A mark fills with essence during a climb as its body part does its work, and glows once a spell can be cast. Tap the mark's key ({cast}) to cast its selected spell, or hold it to open a ring of its spells, point at one and let go. The climber screen ({climber}) has a page for every mark with all its spells."},
	"overdraw": {"group": "essence", "name": "Overdraw",
		"tip": "You cast with too little essence and the mark burned. It heals at the stair. Do it again only if it's worth it.",
		"more": "Casting without enough essence still fires the spell, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and carry you less far, and so on. Burns heal at the next stair (or with a Cleansing Tonic)."},
	"new_mark": {"group": "essence", "name": "A new mark",
		"tip": "Another part of you soaked up enough. A new mark takes hold.",
		"more": "An unmarked body part that soaks up enough over your climbs takes a new mark at a stair, shaped by the essence you've banked since your last one. Each new mark needs more soak than the last. The climber screen shows which part is forming its mark next, and which bond it would be."},
	# --- secret essences (secret.gd) ---
	"secret": {"group": "secret", "name": "Secret essences",
		"tip": "Life and Unmaking: the secret essences. Only great foes leave them, never an ordinary monster.",
		"more": "Life and Unmaking are the two secret essences. Ordinary monsters never leave them: only great foes do. A tower's beast leaves mostly Life and some Unmaking; the Proving's shadow of the beast the same, but less; a mirror image of you mostly Unmaking and some Life; a champion (a sealed wing's, or the Proving's sentinel) a little of one or the other, depending on the tower. Like other essence there's more of it higher up. They aren't currency and never settle in a body part."},
	"secret_path": {"group": "secret", "name": "Your path",
		"tip": "Chosen, for good. Only that essence soaks into you now. It gathers in your shadow, and you bank it at the stair.",
		"more": "The first time a great foe falls and its secret essence rises, you choose your path: Life or Unmaking. The choice is for good. From then on only your path's essence soaks in. It doesn't settle in a body part: it gathers in your shadow as one measure, the flow. It never takes a mark and never pushes out a bond. You carry it unbanked like other essence (a fall loses it) and bank it at the stair. Banked flow reaches steps at 25, 75, 150 and 300, each a real change in how you play, and your shadow shows each one."},
	"secret_pass": {"group": "secret", "name": "Passing through",
		"tip": "That one isn't yours. It passes through you and is gone. Nothing of it is banked.",
		"more": "Once you've chosen your path, the other secret essence still rises from great foes, but it passes straight through you and out the other side. None of it is kept or banked (unless you carry a vessel). Your path's essence soaks in as before."},
	"vessel": {"group": "secret", "name": "The vessel",
		"tip": "A vessel on your belt. What passes through you, it can hold: the essence that isn't your path, 30 at most.",
		"more": "A vessel is a sealed glass vessel bound in brass. A Rune Artist brews one at the workshop's bench, and very rarely a vault holds one. It takes one kind of space on your belt and is never used up. Once you have a path, the other secret essence that rises from great foes curls into it instead of passing through you, up to 30, one kind only. What it holds is unbanked: fall and the vessel is lost with your belt. Survive or read a recall scroll and it comes home to your chest, filled or not (never broken into crystals); from there you can pack it for your next climb."},
	"vessel_capture": {"group": "secret", "name": "Captured",
		"tip": "Caught, not passed. The vessel holds it now. Keep it whole until you're home.",
		"more": "Each time the other secret essence rises from a great foe, the vessel on your belt takes what it has room for; the rest still passes through you. Your path's essence soaks into you as before. The gauge beside your health bar shows how full it is."},
	"vessel_full": {"group": "secret", "name": "A full vessel",
		"tip": "The vessel is full. Bring it home and it can be traded, worked into a piece, or offered.",
		"more": "A full vessel holds 30 of a secret essence. Kept in your chest on the train, it can be traded to the outfitter (Sell: 120 crystal essence of one kind, or 30 of every kind), worked into a piece by a Rune Artist at the bench (one rank past +3, or a deep rune at the Inscribe spell's full strength), or offered to the Maker of Marks as the Developer's bribe. Carried up on your belt, it can be offered to a Maker when you plead for a change of path: it is likelier to agree, and keeps the vessel."},
	"flow_1": {"group": "secret", "name": "The flow: step 1",
		"tip": "Your flow reaches its first step. Its gem joins your health bar. Life: health regrows. Unmaking: more damage, less health.",
		"more": "At 25 banked your flow takes hold and its gem appears beside your health bar (hover or look at the climber screen's Essence tab for its steps). Life: your health slowly regrows on its own. Unmaking: you deal more damage with strikes and spells but have less max health; both grow with every step."},
	"flow_2": {"group": "secret", "name": "The flow: step 2",
		"tip": "Step two. Life: every kill mends you a little. Unmaking: an aura erodes awake monsters beside you.",
		"more": "At 75 banked. Life: every monster that falls mends you a little, and your health regrows faster. Unmaking: monsters that are awake and right beside you take a little damage every second; the damage-for-health trade grows."},
	"flow_3": {"group": "secret", "name": "The flow: step 3",
		"tip": "Step three. Life: healing works far better. Unmaking: your strikes ignore armour.",
		"more": "At 150 banked. Life: everything that heals you heals much more: draughts, healing springs, your marks' heals and weapons that heal on a kill. Unmaking: your weapon strikes ignore armour: a shellback's shell no longer turns them and a knight's guard no longer shrugs off light blows. Beasts still don't flinch."},
	"flow_4": {"group": "secret", "name": "The flow: step 4",
		"tip": "The last step. Life: once a floor, a killing blow leaves you standing. Unmaking: slain foes come apart and hurt those beside them.",
		"more": "At 300 banked. Life: once on each floor, a blow that would kill you leaves you at a quarter of your health instead, in a burst that throws back the monsters around you. Unmaking: a monster you slay comes apart, hurting the monsters right beside it by part of its health (an undone monster doesn't undo again)."},
	# --- the Unbound (unbound.gd, unbound_run.gd, technique.gd) ---
	"unbound": {"group": "unbound", "name": "Unbound",
		"tip": "No mark, now or ever. Banked essence pools raw in your six parts. Build your own techniques at the train.",
		"more": "An Unbound climber carries no tower bond. Each kind of essence you bank pools raw in its natural body part (Blade the hand, Air the legs, Stone the back, Water the throat, Fire the brow, Iron the heart) unless you route it elsewhere at the train, and your path's essence runs through all six. A part's raw density sets its level (1 to 10): how hard its techniques hit (up to twice as hard), how many essences it can combine (one, two from level 4, three from level 8), and a gift at level 5. Your six techniques are cast with the marks' buttons ({cast}). Your total raw density sets your stage, from Stir to Unbound. The Makers stand outside the towers, so secret bonds can still be earned. It's for good: only the Developer's holder can let the beasts mark them again."},
	"unbound_offer": {"group": "unbound", "name": "The refusal",
		"tip": "You may refuse this mark. Refuse, and there is no road back.",
		"more": "Only at the Regard, at the end of your first climb, and only if you broke no barrier on it: the beast offers its mark. Accepting changes nothing. Refusing makes you Unbound: no tower bond ever again, and banked essence pools raw in your body instead. Refusing takes a second press, since it can't be undone. After the first climb a marked climber can't become Unbound."},
	"unbound_fists_found": {"group": "unbound", "name": "Something gave",
		"tip": "That barrier shuddered. Break one on your first climb and the beast will refuse to mark you.",
		"more": "A barrier the tower puts up (a warded stair, a vault's seal, a lock-in room's shut doorway) can be struck with bare fists. The very first time, it only shudders. On the bondless first climb, keep striking and it breaks: that breaks the tower's rules, and at the Regard the beast refuses to mark you. You become Unbound, with no choice."},
	"unbound_fists": {"group": "unbound", "name": "Bare fists",
		"tip": "Fists out, hold {attack} against a barrier. Each blow costs essence and skin. It breaks, and gives nothing.",
		"more": "With your fists out on your first climb, hold the strike ({attack}) against a barrier: a warded stair, a vault's seal or a lock-in room's shut doorway. Each blow drains some of your unbanked essence, hurts your hands (more when there's little essence to drain; never the last of your health) and cracks it. A few blows break it: you skip its challenge and forfeit its reward (a broken ward gives no puzzle bonus; a broken vault is empty), and the beast will refuse to mark you at the Regard. Once Unbound, you strike barriers with raw essence from a step away, with any melee weapon (the Proving's sealed reliquary too): it costs unbanked essence and doesn't hurt."},
	"unbound_rules": {"group": "unbound", "name": "Rules broken",
		"tip": "You broke a barrier on your first climb. At the Regard, the beast will refuse to mark you.",
		"more": "Breaking even one barrier on the bondless first climb breaks the tower's rules. At the Regard the beast refuses to mark you, and you become Unbound: no tower bond, now or later. A fall on the first climb is refused the same way."},
	"unbound_fists_marked": {"group": "unbound", "name": "It holds",
		"tip": "The barrier shudders and holds. Bare fists only break barriers on the first climb.",
		"more": "After the first climb, a marked climber's fists only make a barrier shudder. Only the Unbound can break one later, with raw essence."},
	"unbound_strain": {"group": "unbound", "name": "Strain",
		"tip": "Past the white tick, that part hits harder and may waver. At the end of the bar it erupts.",
		"more": "Every technique strains the body part it comes from (the bar under its medallion; more for each essence it combines, and more when you cast before it has filled). Above 70 its techniques hit 25% harder but may waver: half strength, off aim. At 100 the part erupts. Strain fades while you don't cast from that part, and the stair's rest clears it."},
	"unbound_erupt": {"group": "unbound", "name": "Eruption",
		"tip": "It erupted. That part is dark for a while. An eruption can kill you.",
		"more": "At 100 strain the raw essence in a part erupts: you lose almost half your health (it can kill you, and that's a fall like any other), the part goes dark for 8 seconds (nothing from it can be cast) and raw essence shows on it."},
	"unbound_techniques": {"group": "unbound", "name": "Techniques",
		"tip": "A part gives the shape. The first essence leads; the others flavour it. Tap a gem to change it.",
		"more": "A technique is a body part and one to three essences. The part gives its shape (the hand a strike or a bolt, the legs a dash or a leap, the back a shell or a push, the throat a shout or a pull, the brow a mark or sight, the heart something on yourself). Each essence adds what it does: Fire burns, Water slows, Air reaches farther, Stone staggers and guards, Iron pierces armour and pulls, Blade cuts and bleeds, Life heals, Unmaking erodes and ignores armour. The first leads at full strength; the others at half and a third. A technique fills from its part's actions the way a mark does (strikes fill the hand, rolls the legs, parries the brow, hits taken the heart, backstabs the back, several foes at once the throat): full, it casts for nothing; cast it early and the missing share adds strain. If you carry its essences unbanked, a cast spends them and hits 50% harder (switch this off on the techniques page). You carry six, one on each mark button."},
	"unbound_condense": {"group": "unbound", "name": "Condensing",
		"tip": "No mark for you at the top. Choose a part, and the tower's essence condenses there.",
		"more": "At a summit the Unbound take no mark. Instead the tower's essence condenses straight into the body part you choose, raising its raw density."},
	# --- the tower ---
	"stair": {"group": "tower", "name": "The stair",
		"tip": "The stair is open. Go up, or finish what's left for its essence.",
		"more": "On the first floor and the beast's floor the stair opens once three quarters of the monsters are down; on floors of rooms it opens when the floor's puzzle lifts the ward. An arrow at the edge of the screen points the way. Walk onto it to climb: the essence you carry is banked and you rest."},
	"fog": {"group": "tower", "name": "Rooms and fog",
		"tip": "Rooms now, and walls. You see what you can see; the rest you remember, dimly.",
		"more": "Above the first floor every floor is a plan of rooms joined by corridors. Walls block sight (chasms, water and pillars don't), places you've seen stay dimly mapped, and monsters out of sight are hidden. A monster waits where it is until it sees you, then rouses its neighbours and finds its way around the walls."},
	"rooms": {"group": "tower", "name": "Room names",
		"tip": "Rooms have names, and the names are honest. Mostly.",
		"more": "Every room has a theme, shown the first time you walk in: good rooms (a healing spring, a forgotten cache of essence, a fallen climber's camp), bad rooms (a monster den, a restless crypt, a pillared hall, the tower's trap room) and quiet halls. The first room after the entrance is always a good one."},
	"good_room": {"group": "tower", "name": "Good rooms",
		"tip": "A kind room. They're rare. Take what it offers.",
		"more": "A Healing Spring heals you while you stand in its pool, until it runs dry. A Forgotten Cache holds an urn of the tower's essence (sometimes a piece of gear too): walk onto it. A Fallen Climber's Camp has an item left behind. No traps or monsters wait in good rooms, and each tower has its own good room as well."},
	"den": {"group": "tower", "name": "Monster dens",
		"tip": "Bones and claw marks. More of them live here than anywhere else on this floor.",
		"more": "A Monster Den holds more of the floor's monsters than any other room. A door's iron bands and claw marks warn you before you go in. Fight near the doorway and let them come to you."},
	"crypt": {"group": "tower", "name": "Restless crypts",
		"tip": "The dead here don't stay down when disturbed. Keep your back to a wall.",
		"more": "From floor 3, a Restless Crypt's dead rise around you as you walk in, two or three of the tower's monsters at once."},
	"mirror": {"group": "tower", "name": "Mirror images",
		"tip": "Your weapon, your armor, your marks' spells, turned on you. It rolls and guards the way you do.",
		"more": "Now and then, from floor 4, a Hall of Glass lies off the way to the stair, behind a door bearing a figure in a mirror. Walk in and a mirror image of you steps out of the glass, and the doors shut until it falls. It carries the weapon in your hand (its reach, its chain, its finisher; or your bow), wears your armor (your blows land a little softer) and casts a simpler form of up to two of your marks' spells: a volley of bolts, a circle where you stand, a cone or a ring. Every attack is telegraphed and glints like any monster's. It sometimes rolls clear of a blow, and after attacking it may raise its guard (a silver arc): light blows from the front are turned aside and it answers at once, but a finisher or a blow from behind breaks through. It is a great foe: it leaves mostly Unmaking and some Life, an essence crystal of the tower's kind, and sometimes a piece of gear."},
	"doors": {"group": "tower", "name": "Doors",
		"tip": "A door's face hints at what waits behind it. Never at the reward.",
		"more": "Walk up to a closed door and it swings open; awake monsters open doors too. A closed door blocks the way, shots and sight, so a room behind one stays dark until you open it. Plain planks mean an ordinary room; iron bands and claw marks a den; an engraved sigil a trap room; a stone door with an emblem the puzzle room; warm light under the door a good room; chains and a red glow danger."},
	"door": {"group": "tower", "name": "Strange doors",
		"tip": "Not every door opens for the asking. Look around.",
		"more": "Some doors don't open just because you walk up to them. Something on the floor answers for them."},
	"door_locked": {"group": "tower", "name": "Locked doors",
		"tip": "Locked. Something on this floor opens it. Find it.",
		"more": "A locked door won't open when you walk up to it. What opens it is somewhere on the same floor."},
	"door_sealed": {"group": "tower", "name": "Sealed in",
		"tip": "The way shut behind you. It opens when the room is done with you.",
		"more": "Some rooms close their doors once you're inside and open them again only when what's inside is dealt with."},
	"jump": {"group": "tower", "name": "Chasms",
		"tip": "The floor gives way here. Jump it with {jump}. A roll only carries you in.",
		"more": "In the Firebird's tower the floor has chasms. Jumping ({jump}) carries you across; walking or being knocked in drops you through. Walking monsters can't follow you over a chasm, but fliers cross them."},
	"chasm_fall": {"group": "tower", "name": "Falling through",
		"tip": "Down a floor. No harm done, except to your pride. Your essence came with you.",
		"more": "Falling into a chasm doesn't hurt: you land on the floor below (never below floor 1) and climb again from there. Your unbanked essence stays with you."},
	"camp": {"group": "tower", "name": "Camps",
		"tip": "A fire, and nothing hunting you. Rest, choose one thing, go on.",
		"more": "On a full climb the stairs of floors 3 and 9 lead to a camp first. You rest fully (health, stamina, burns and poison), then choose one of four cards: three items or a piece of gear (your old piece is left by the fire). Then the stair takes you on. A camp isn't a floor, and each comes once a climb."},
	"proving": {"group": "tower", "name": "The Proving",
		"tip": "Floor six. The tower takes your measure here. Losing won't kill you. It will cost you.",
		"more": "Halfway up every tower, floor 6 is the Proving: the tower shows what it is about. Cross a gauntlet of its own traps, best its sentinel (a crowned champion with its pack) and face a shadow of its beast; then choose one of three relics, and the stair opens. Lose and you don't die: the tower casts you down to floor 5, keeps half the essence you hadn't banked and leaves a wound (less health until you reach floor 7). Climb back and try again. Each win makes that tower's Proving harder on later climbs, with a better prize. Once you have won it, a second door opens: the Lethal Proving, harder still, with a greater prize. Die there and the climb ends."},
	"proving_lethal": {"group": "tower", "name": "The Lethal Proving",
		"tip": "A second door. It asks more and gives more. It doesn't send anyone back down.",
		"more": "Once you have won a tower's Proving, its antechamber has a second door: the Lethal Proving. It is a tier harder than the ordinary one, and its prize is better. Lean on the door to go in, knowing what it means: die beyond it and the climb ends, as anywhere else in the tower. The ordinary door still forgives."},
	"proving_wound": {"group": "tower", "name": "The lingering wound",
		"tip": "Cast down, and wounded. It will close by floor seven. Climb carefully until then.",
		"more": "Losing the ordinary Proving casts you down to floor 5 with a wound: your health is a quarter lower (the lost part of the bar shows violet, and the climber screen says so) until you have climbed two stairs, which brings you back past floor 6 to floor 7. Half the essence you hadn't banked stays behind."},
	"beast": {"group": "tower", "name": "The beast",
		"tip": "There it is. It has watched you climb. Every blow it throws, it tells you first.",
		"more": "Every tower's beast waits alone on floor 12, the summit. Beasts can't be interrupted, only staggered; they glint before every attack like any monster, their red shapes can't be parried, and at half health they call for help. Beat it, take the stair, and the climb is complete: you keep one piece of gear as an heirloom."},
	# --- the Makers (makers.gd): not in GROUPS, so the Archive hides them
	# until met; they show on the forbidden shelf. Plain mechanics only: the
	# Entity says nothing of its siblings here.
	"fragment": {"group": "forbidden", "name": "Fragments",
		"tip": "A fragment. Walk up to one to read it. I keep what you find on a shelf in the Archive.",
		"more": "Fragments are rare: at most one on a floor, on about one floor in eight, and only in a secret room or a sealed wing's vault, never on the way to the stair. Walk up to one to read it. Each is kept on its own shelf in the Archive (the climber screen's Archive tab), with how many you have found. Their words are not written yet."},
	"glimpse": {"group": "forbidden", "name": "A glimpse",
		"tip": "A second shadow, a bend in the light, or my silence. Something is paying closer attention.",
		"more": "Glimpses come now and then after a stair, as something's interest in you grows: a second shadow beside you, the light bending for a moment, or the Entity going quiet for a while. They change nothing by themselves."},
	"maker": {"group": "forbidden", "name": "A meeting",
		"tip": "When one of them shows itself, the game waits for your answer. Choose a card.",
		"more": "One can show itself only once you have found at least six fragments, and only when how you climb has held its attention: how you use your bonds, how you treat the tower and its monsters, and your body. It comes in the quiet after a stair, and the game waits. Choose an answer with left and right and confirm it (Enter, or the controller's confirm button), press its number, or tap it. A good answer grants its secret bond and a core mark; a bad one turns it away for a while, and it remembers. Once you have a path, you can also ask it for a change of path; it may refuse."},
	"core_mark": {"group": "forbidden", "name": "The core mark",
		"tip": "A core mark: a fine pattern over your whole body, beneath your other marks. It takes no body part.",
		"more": "A core mark holds a secret bond. It covers all six body parts at once and never pushes out a mark. Only one secret bond per climber: the others can still show themselves, but the one whose mark you carry may interrupt them. Its tools are not built yet."},
	# --- puzzles and traps ---
	"ward": {"group": "tests", "name": "The ward",
		"tip": "The stair is warded. Somewhere on this floor is the beast's test. Solve it and the ward lifts.",
		"more": "Every floor of rooms has a puzzle room, and its stair stays warded, however many monsters fall, until the puzzle is solved. A puzzle never needs a bond, an item or a piece of gear, only what every climber has. Solving it lifts the ward, opens the stair and opens the puzzle room's gate, behind which waits a burst of essence."},
	"puzzle": {"group": "tests", "name": "Puzzles",
		"tip": "A test. It needs nothing you don't already carry.",
		"more": "The beast's tests only ask for what every climber has: strikes, arrows, walking, and patience. Solving the floor's test lifts the stair's ward."},
	"puzzle_eyes": {"group": "tests", "name": "Stone eyes",
		"tip": "Stone eyes. Wake every one. An arrow flies over a rail where your feet can't.",
		"more": "Stone eyes sit behind low rails, which stop walking but not sight or arrows. Hit every eye, with a strike if you can reach it or an arrow over the rail. On harder floors an eye stays lit only a couple of seconds, so you must light them all together."},
	"puzzle_plates": {"group": "tests", "name": "Pressure plates",
		"tip": "These want weight, and you're too light. Push a block onto each, or lend them a monster.",
		"more": "Pressure plates need a weight: the climber is too light. Push a stone block onto a plate (walk into it for a moment and it slides a tile), or lure a monster onto it and keep it alive. Every plate held at once solves it; strike the lever to put the blocks back if one gets stuck."},
	"puzzle_ice": {"group": "tests", "name": "The Ice Hall",
		"tip": "Ice. Once you're on it, it decides where you stop. Find the line of slides that ends on the dais.",
		"more": "In an Ice Hall you can't walk on the ice: step on and you slide in a straight line until a rock stops you, or off the far side back onto the floor. While on the ice, any push of {move} picks one of the four directions and sends you sliding; you can't roll or jump there. Come to rest on the dais to solve it (sliding over it does nothing). Getting it wrong costs nothing: slide off and walk back round. A blow can send you sliding, and a monster in your lane stops you short."},
	"puzzle_lock": {"group": "tests", "name": "The Essence Lock",
		"tip": "A lock that wants an essence. Read the riddle, then find a foe glowing with the answer.",
		"more": "An Essence Lock's riddle names one of the six essences (Air, Water, Iron, Fire, Stone, Blade). Once you're inside, foes glowing in different essences appear, each with its essence's sign over it. Slay one and it leaves a spark of its essence: walk over it to carry it (one at a time) and bring it to the lock. The wrong spark brings hunters, and then a new riddle. A spell from a mark of the right essence cast beside the lock, an item of it used there, or a strike from a weapon of it, answers at once. On the highest floors the lock wants two or three essences, in order."},
	"puzzle_memory": {"group": "tests", "name": "The Hall of Pedestals",
		"tip": "Pedestals with signs, and no order given. Look for murals in the other rooms: they number the signs.",
		"more": "The Hall of Pedestals holds a pedestal for each sign. Murals in other rooms of the same floor each show a numeral and a sign; together they give the order. Strike or shoot the pedestals in that order to light them. The first wrong one brings hunters, and then the pedestals go dark to be tried again. The panel in the hall counts the murals you've found. On higher floors there are four signs, and later one pedestal that no mural shows."},
	"traps": {"group": "tests", "name": "Traps",
		"tip": "Traps warn before they bite: a glow, then the glint. They hurt badly, so the warning is all you get.",
		"more": "Traps are the beast's tests, one kind per tower. Visible traps show their reach engraved on the floor. Every trap glows, then glints a moment before it fires, and then it hurts badly. Rolling through a firing trap counts as a dodge. Monsters that wander into one are caught too."},
	"trap_room": {"group": "tests", "name": "Trap rooms",
		"tip": "Its traps keep one beat. Watch a round before you cross.",
		"more": "Each tower lays its traps as a set piece in its trap room (and at chokepoints): gust lanes in the Gryphon's tower, sluice sweeps in the Kraken's, flame jets in the Wyvern's, a spike field in the Manticore's, ember mortars in the Firebird's and bramble snares in the Chimera's. The traps of a set piece share one beat, so they fire in a pattern you can learn and walk through. The door of a trap room bears its hazard's sigil."},
	"hidden_trap": {"group": "tests", "name": "Hidden traps",
		"tip": "That one was hidden. It shows itself once it's set off. Half a breath; move.",
		"more": "A hidden trap's tile is very faint, but the moment one is set off it shows itself (a click, a hiss or a rustle, its reach lit up) and gives you about half a second to get clear. The Hunter's Keen Eyes outlines hidden traps in gold."},
	"gas": {"group": "tests", "name": "Gas vents",
		"tip": "Gas. It keeps hurting while you stand in it. So don't.",
		"more": "The Manticore's and Chimera's towers hide gas vents: set one off and a cloud spreads that keeps hurting while you stand in it. It can kill you if you stay, and it hurts monsters too."},
	"poison": {"group": "tests", "name": "Poison",
		"tip": "Poisoned. It wears off, or the stair cures it. A Cleansing Tonic is quicker.",
		"more": "Poison costs a little health every half second for a few seconds. The rest at a stair cures it, and so does a Cleansing Tonic."},
	# --- gear and items ---
	"gear": {"group": "gear", "name": "Gear on the floor",
		"tip": "Gear. Stand on it to compare; {take} swaps, and your old piece stays behind.",
		"more": "Gear lasts one climb. You carry fists, a melee weapon and a ranged weapon, and wear a chest piece, a helm, gloves, legs, boots, a cloak, an amulet, two rings and a backpack. Slain monsters rarely drop a piece, likelier one that suits them; caches, camps and vaults offer some too. Walk over gear with an empty slot and you take it; otherwise a card names its slot and compares it with what you wear (better numbers in green, worse in red) and {take} swaps, dropping your old piece where you stand so you can change your mind."},
	"gear_slots": {"group": "gear", "name": "Worn pieces",
		"tip": "Not a weapon: something to wear. Helm, gloves, legs, boots, cloak, rings... each slot takes one.",
		"more": "Besides your weapons and chest piece you can wear a helm, gloves, legs, boots, a cloak, an amulet, two rings and a backpack. Each piece does one small thing: a little health, harder strikes, a quicker step. Protection from every piece adds up, but never past half a blow. Heavy pieces make rolls cost a little more. Plain (Common) pieces wear down as you use them: badly worn, their bonus halves; worn out, they break. Rings and amulets never wear. The inventory ({inventory}) lays out what you wear like a body."},
	"heirloom": {"group": "gear", "name": "Heirlooms",
		"tip": "You survived. Keep one thing you carried; every climb after begins with it.",
		"more": "Survive a climb (beat its beast, or reach the Regard without falling) and you choose one piece you wore to keep as an heirloom; your rings are kept as a pair. Every later climb starts with your heirlooms in their slots, in full repair. Each slot (melee, ranged, chest, helm, gloves, legs, boots, cloak, amulet, rings, backpack) holds one; keeping another piece for the same slot replaces it. The inventory's Heirlooms view shows them."},
	"items": {"group": "gear", "name": "Items",
		"tip": "An item. {item} uses the one you've chosen; {item_next} chooses another.",
		"more": "Items last one climb; you can carry up to 3 of each kind (4 with a Satchel). The quick item, shown beside your weapon, is the one {item} uses, and {item_next} picks the next. An item that would do nothing (a draught at full health) isn't used up. Every climb starts with a Healing Draught; monsters sometimes leave items, and camps offer them."},
	"rarity": {"group": "gear", "name": "Rarities and traits",
		"tip": "That one is finer than most: see its colour. Finer pieces carry traits, and never wear.",
		"more": "Gear comes Common (pale), Fine (green), Rare (blue) or Storied (amber). Fine pieces carry one trait and Rare ones two; a Fine or Rare weapon also hits a little harder. Each trait belongs to an essence (of Vigor is Stone, of Edges is Blade, of the Wind is Air...) and only appears on the slots it suits. Finer pieces turn up higher in the tower, and caches, camps and vaults hold finer things than monsters do. Storied pieces and each tower's own pieces keep their own names and rules. What gear adds stops at a cap (the inventory says \"capped\"), and only Common pieces wear."},
	"belt": {"group": "gear", "name": "The belt",
		"tip": "Your belt holds four kinds of item. A fifth means letting one go.",
		"more": "The belt holds four kinds of item, up to three of each (a recall scroll is one). A Belt Pouch or a Climber's Pack holds a fifth kind, and a Satchel or Climber's Pack a fourth of each. Step on a new kind with a full belt and you choose: swap a stack out (it stays where you stand) or leave the new one. Survive the climb and whatever is left on your belt breaks into essence crystals, at half its worth."},
	"item_ring": {"group": "gear", "name": "The item ring",
		"tip": "Hold {item} to see your whole belt. Point, let go, and it's used.",
		"more": "A tap of {item} uses your quick item. Hold it (or {item_next}) and a ring of your belt items opens and time stands still: point at one (the mouse, a stick, or slide your finger) and let go to use it; it becomes your quick item. Fire Flasks fly where you aim, oils and draughts work for a while, Flare Powder lights the room and makes hidden traps and secret walls nearby glint."},
	# --- the train ---
	"train": {"group": "train", "name": "The train",
		"tip": "A train, of all things. It waits between climbs: your own car, a store, a workshop. The engine takes you on when you're ready.",
		"more": "After the Regard, every climb ends on the train, whether you won, fell or read a recall scroll, and every climb starts from it. Walk along it from car to car ({cars}): the engine at the front, where you choose the next tower on its board and pull the lever to depart; your car (your heirlooms, your pack and a storage chest); the store car (the outfitter's supplies, an outfit, today's piece, and selling); and the workshop car (its bench: brewing, and enchanting for a Rune Artist). Your crystals sit along the bottom. Fall in a tower and you're back on the train in a moment."},
	"store": {"group": "train", "name": "The store",
		"tip": "The outfitter buys what climbers bring down and sells to the next ones up. He takes crystals: every stair condenses some for you, and he pays for every climb.",
		"more": "Essence crystals are the only money, and you hold one crystal of each kind, growing as you add to it. Every stair condenses a share of the essence you bank into crystals (20% unless you change it in Settings), and the outfitter pays for every climb, even one that ends in a fall: a few crystals of the tower's kind for each floor you reached, more for floors past your best there. Every price is in one kind of essence, taken from your crystal of that kind. Common pieces and basic supplies are cheap; finer pieces cost more. The recall scroll is always on the shelf, and takes crystals of any kind, your biggest first. Supplies are packed onto your belt for your next climb (put one back for its full price before you go). Outfit is a rack of Common pieces, new every visit, and Today's piece is one finer piece. Sell turns a piece from your pack or chest into a crystal of its kind, at 40% of its price. A price you can't pay says how much more you need."},
	"chest": {"group": "train", "name": "Your pack and chest",
		"tip": "Your chest keeps things safe between climbs. Your pack goes up with you, and falls with you.",
		"more": "Besides what you wear you carry a pack of four spare pieces (a Climber's Pack holds two more). Swap gear in the tower and your old piece goes in your pack while there's room. Survive a climb, or read a recall scroll, and your pack comes down to the train: sell what you don't want, or keep it in the storage chest in your car (eight spaces), safe between climbs. When you depart, your pack comes with you, and any piece whose slot is free you wear at once. Fall, and your pack is lost."},
	"fall_loss": {"group": "train", "name": "Lost on the way down",
		"tip": "A fall takes your pack and your belt, sometimes the weapon in your hand. The tower keeps what it takes. For a while.",
		"more": "Fall in the tower and your pack and everything on your belt are lost, and there's a chance the weapon in your hand goes too (your melee weapon, if your fists were out; never the starting sword or bow). Your heirlooms are never lost, and your chest and crystals are safe on the train. The fall screen says what was taken. The tower remembers the last six pieces you lost, and where: on a later climb of the same tower, near the floor where they fell, your fallen pack may turn up again."},
	"lost_cache": {"group": "train", "name": "A lost cache",
		"tip": "Your own pack, where you fell. The tower gives back, now and then.",
		"more": "A lost cache is the pack you lost in a fall, lying in an ordinary room of the same tower, near the floor where you fell, with a faint pale light over it. Walk onto it and up to three of your lost pieces come back: into your pack while there's room, else at your feet. Each climb of that tower, a floor near where things fell has a chance to hold one. Items from your belt don't come back."},
	"bench": {"group": "train", "name": "The bench",
		"tip": "The workshop's bench. Anyone can brew here: what you make is packed onto your belt for your next climb.",
		"more": "The bench in the workshop car has a counter for each kind of work, and a card with what it costs in essence (a price you can't pay says how much more you need). Brew makes a consumable for your next climb, a little cheaper than the store sells it; put one back before you go and what you paid comes back. Break down turns a piece from your pack or chest, or a packed item, into a crystal of its kind, as the store's Sell does. A choice that can't be undone asks first: tap the same button again to do it."},
	"enchant": {"group": "train", "name": "Enchanting",
		"tip": "Enchanting takes a Rune Artist: tempering, swapping traits, joining pieces, lasting runes.",
		"more": "Only a Rune Artist can enchant at the bench; anyone else sees those counters greyed. Temper raises a piece's rank from +1 to +3: each rank makes its traits a quarter stronger (of their base) and a weapon hit 4% harder; +2 and +3 also need that essence's density settled in you (100, then 300). Retrait swaps one trait for a new one: the crystal you pay chooses its essence. Join makes one Rare piece of two Fine pieces for the same slot, keeping a trait from each. Inscribe puts a lasting rune on a piece (Sharpness, Warding or Swiftness, at half the Inscribe spell's strength), drawn on its icon. A Rune Artist also brews for 20% less, and can bind a recall scroll (you carry one). The bench works on your heirlooms and the pieces in your pack and chest. Only Common pieces wear; anything with a trait never does."},
	# --- screens ---
	"climber": {"group": "screens", "name": "The climber screen",
		"tip": "{climber} shows what you are: your marks, the essence in you, and what I've recorded.",
		"more": "The climber screen has your marks drawn on your body with a card for each (choose one for every spell and step), the essence settled in you and its bonuses, your record and heirlooms, and this Archive. {climber} opens and closes it; Q and E switch tabs."},
	"appearance": {"group": "screens", "name": "Appearance",
		"tip": "How you look is yours to choose. Change each part with {choose}; it changes nothing but your looks.",
		"more": "The appearance page sets how the climber looks in the towers and on the climber screen: an optional name, skin, hair and its colour, eyes, cloak, tunic, and the hood up or down. Up and down move between the rows; Left and Right (or the arrows, or a swatch) change one. Randomise rolls a whole new look and keeps the name. Turn spins the preview (Q and E, or LB and RB). A new climber chooses a look before the first climb; change it any time with Appearance on the climber screen's Marks tab, or in your car on the train. Looks never change how you play."},
	"climbers": {"group": "screens", "name": "Climbers",
		"tip": "Up to six climbers, each kept apart. Choose one to play; Delete asks twice.",
		"more": "The Climbers page (from the title screen) holds up to six climbers. Each has their own marks and essence, crystals, train, heirlooms, look and name, record, Makers and everything I have told them; a new climber hears my tips again. Settings, controller setup and tips on or off are shared. Choose a card to play that climber, or an empty slot to begin a new one. Delete under a card asks for a second press, and a deleted climber can't be brought back. Continue on the title plays whoever was played last. Start over only starts the current climber over."},
	"inventory": {"group": "screens", "name": "The inventory",
		"tip": "{inventory} shows everything you carry, and lets you use it.",
		"more": "The inventory lays out what you wear like a body: helm, amulet and cloak; melee weapon, chest and ranged weapon; a ring, gloves and a ring; backpack, legs and boots. Beside it are your fists, gear lying at your feet and a camp's rune; below, your items with their counts (the quick item gilded). Worn pieces show their condition. Switch to Heirlooms to see what every climb begins with. Choose a slot for its details (compared with what you wear), to use an item, or to take the gear at your feet."},
	# --- the secret bonds' tools (secret_bonds.gd, secret_tools.gd): mechanical text only ---
	"tool_ring": {"group": "tools", "name": "The tool ring",
		"tip": "Hold {tools} for your secret bond's tools. Every tool costs essence you carry.",
		"more": "A secret bond's tools are used from the tool ring: hold {tools} and the ring opens and time stands still; point at a tool (the mouse, a stick, or slide your finger) and let go to use it. A tap uses the last tool again, or closes an open panel. Under each tool, gems show its cost: your path's secret essence (Life or Unmaking) and ordinary essence, both from what you carry unbanked. A unit of secret essence you don't carry costs three essence instead. A tool that aims works on what you were aiming at when the ring opened."},
	"tool_inspect_developer": {"group": "tools", "name": "Inspect (the Developer)",
		"tip": "Your spells' real numbers, for the rest of the floor: on the spell ring while you aim, and in the panel.",
		"more": "The Developer's Inspect shows every spell you carry with its real numbers: cost, wind-up, damage, reach and the rest, with everything that changes them already counted (a faint mark, your density, gear, flow and Tune), and what each step adds. Once paid it lasts the floor: the spell ring shows the pointed spell's numbers while you aim, and using Inspect again opens or closes the panel for free."},
	"tool_tune": {"group": "tools", "name": "Tune (the Developer)",
		"tip": "Between climbs, set each spell for more power, less cost or a quicker wind-up.",
		"more": "The Developer's Tune works between climbs, on the climber screen's Core tab while you're on the train. Each spell you carry takes one setting: Power (20% more power: damage, shields, durations), Thrift (25% less cost) or Quick (40% quicker wind-up). Each change costs crystal essence; clearing a setting is free. The setting stays until you change it."},
	"tool_path": {"group": "tools", "name": "A new path (the Developer)",
		"tip": "The Developer can change your path. Everything your path banked flows out, and a new path starts from nothing.",
		"more": "On the train, the Developer can let your path go: all of its flow, banked and carried, flows out of your shadow, and the next great foe offers the choice of Life or Unmaking again, starting from nothing. It costs crystal essence."},
	"tool_inspect_designer": {"group": "tools", "name": "Inspect (the Designer)",
		"tip": "The floor's whole plan: rooms, doors, traps and their timing, hidden traps and secret walls.",
		"more": "The Designer's Inspect opens the floor's plan: every room and corridor, what kind of room lies behind each door (never what it holds), every trap with its timing, hidden traps and secret walls. Once paid it lasts the floor: traps near you show their timing and when they next fire, doors show what's behind them, and using Inspect again opens or closes the plan for free."},
	"tool_switch_designer": {"group": "tools", "name": "Switch (the Designer)",
		"tip": "Turn the trap you aim at off or on, or open or shut an unlocked door, from a distance.",
		"more": "The Designer's Switch works on the trap or door nearest your aim. A trap switched off rests until you switch it on again (crossed out where you can see it). An unlocked door opens, or shuts and holds for a while: nobody opens it, you or the monsters, until it gives or you switch it again. It can't open a locked door, or shut a doorway something stands in."},
	"tool_inspect_manipulator": {"group": "tools", "name": "Inspect (the Manipulator)",
		"tip": "A monster's numbers, the essence it carries, and its next attack before it starts.",
		"more": "The Manipulator's Inspect reads the monster you aim at: its health, damage and speed, the essence it will leave, and its next attack, shown before it starts (Next), then while it winds up (Now, with the seconds left). The readout stays over it for the floor."},
	"tool_calm": {"group": "tools", "name": "Calm (the Manipulator)",
		"tip": "A calm monster ignores you until it's struck.",
		"more": "The Manipulator's Calm sets the monster you aim at calm: it wanders and ignores you until something strikes it. Great foes (a tower's beast, a shadow, a mirror image, a champion) won't answer."},
	"tool_feud": {"group": "tools", "name": "Set against (the Manipulator)",
		"tip": "Two monsters set against each other fight until one falls.",
		"more": "The Manipulator's Set against turns the monster you aim at and the one nearest it on each other: they fight, with their own attacks, until one falls or a while passes, then they come back to you. Whatever falls leaves its essence for you. Great foes won't answer."},
	"tool_edit_developer": {"group": "tools", "name": "Edit (the Developer)",
		"tip": "Between climbs, move points between a spell's own numbers: raise one by lowering another.",
		"more": "The Developer's Edit works on the train, on the Core tab. Each spell's numbers are grouped: Power (damage, shields), Reach (reach, range, radius, width), Length (how long its effect lasts), Wind-up and Thrift (its cost). A point raises one by 12% and must be paid for by a point lowered in another of the same spell, at most 3 either way. Each point raised costs crystal essence; lowering one is free, and so is clearing it. Inspect shows the numbers with the Edit counted."},
	"tool_splice": {"group": "tools", "name": "Splice (the Developer)",
		"tip": "A spell of yours takes another mark's behaviour for the floor.",
		"more": "The Developer's Splice gives one of your spells a second mark's behaviour until the floor ends: pick the spell, then one of your other marks. Each bond lends its own: a pull, a throw, a burn, poison, a stun, a heal for you, a bolt to the next foe, exposed foes, crippled foes, blinded foes, or a burst. It goes to every foe the spell strikes as it's cast; a spell that fires a shot gives it to the shot; one that strikes nothing at once (a shield, a zone) releases it on the foes around you. One splice at a time: a new one replaces it."},
	"tool_write": {"group": "tools", "name": "Write (the Developer)",
		"tip": "Once a floor, cast a spell of a bond you don't have. On the train, move your marks.",
		"more": "The Developer's Write casts any bond's spell you don't hold, once a floor, at the step your best bond has reached: pick an essence, a bond, then a spell (not a form, a toggle or a pact spell). It costs the tool, not a mark's essence. On the train, Write also moves a mark to another body part, or swaps two, for crystal essence: the bond and its growth go with it."},
	"tool_edit_designer": {"group": "tools", "name": "Edit (the Designer)",
		"tip": "Re-time a trap room, move a trap, or raise or sink a wall for a while.",
		"more": "The Designer's Edit works on the trap you aim at, or the floor in front of you. Re-time slows a trap room's whole beat by half and quiets it for a moment. Move shifts a trap up to three tiles the way you aim, to open floor. Raise lifts a stretch of wall across your aim for 20 seconds: it blocks bodies, sight and paths. Sink lowers a wall one tile thick in front of you for 20 seconds (never the floor's outer wall, a sealed wing, a secret room, a vault or the puzzle's sealed room). A trap room always stays crossable by timing, and a wall never shuts the stair away."},
	"tool_reroll_designer": {"group": "tools", "name": "Reroll (the Designer)",
		"tip": "At the stair, choose the next floor's puzzle and how its rooms lean.",
		"more": "The Designer's Reroll, used by the stair once a floor, offers two puzzles for the next floor, then two leans for its rooms: kinder rooms, trap halls, lairs or hushed halls. The next floor of rooms is planned with them. It can't reach the Proving or the summit."},
	"tool_build_designer": {"group": "tools", "name": "Build (the Designer)",
		"tip": "Your own trap, wall or gate; and once a climb, a rift torn through the floor to the stair.",
		"more": "The Designer's Build places something of your own in front of you, a few times a floor, each at its own cost: a trap (the tower's own plate, set off only by monsters), a wall (for the floor; never one that shuts the stair away), or a gate (you pass, monsters don't, and go around). Once a climb, at the highest cost of any tool, it tears a rift: a corridor two tiles wide from where you stand to the stair, straight or with one bend, through rock, walls, doors, cover and trap rooms (the traps on it are destroyed). Any locked door, vault or hidden room it passes is opened, and what it held is taken, not given. It never opens the floor's outer wall, and not on the Proving's floor."},
	"tool_edit_manipulator": {"group": "tools", "name": "Edit (the Manipulator)",
		"tip": "Tune a monster within a budget, or turn it into a weaker kind of its tower.",
		"more": "The Manipulator's Edit works on the monster you aim at: Slower (40% slower), Weaker (40% less damage), Half its reach (it only attacks from half as far) or Frail (40% less health). A monster takes two changes at most. Instead, an untouched monster can be turned into a weaker kind of its tower, where it stands. Great foes won't answer, and monsters bound to a floor's test keep their kind."},
	"tool_reroll_manipulator": {"group": "tools", "name": "Reroll (the Manipulator)",
		"tip": "Aim at a room you haven't entered: its sleeping monsters become another pack.",
		"more": "The Manipulator's Reroll works on a room you haven't walked into yet: its sleeping monsters become another pack of the tower's monsters, about as strong, chosen from two. A key goes with the new pack."},
	"tool_build_manipulator": {"group": "tools", "name": "Build (the Manipulator)",
		"tip": "Rewrite a monster into your own for the floor, with a second kind's attack.",
		"more": "The Manipulator's Build rewrites the monster you aim at into your own until the floor ends: it fights for you, and every few seconds uses an attack it took from another kind of its tower (a knight that also fires arrows). One at a time. Great foes, key carriers and monsters bound to a floor's test won't answer."},
}

## Room features (themes.gd) -> the tip for walking into one.
const ROOM_TIPS := {
	"trap": "trap_room", "den": "den", "ambush": "crypt", "spring": "good_room", "cache": "good_room",
	"camp": "good_room", "chasm": "jump", "mirror": "mirror",
}

## Words for {move}, {attack}... in tips: [keys, controller, touch]. The
## controller column may use {a}, {lb}... (button names, controls.gd).
const KEYS := {
	"move": ["WASD or the arrows", "the left stick", "the left of the screen"],
	"attack": ["left click or J", "{rt}", "the big button"],
	"roll": ["Space", "{b}", "Roll"],
	"parry": ["right click or K", "{lt}", "Parry"],
	"jump": ["Z", "{a}", "Jump"],
	"take": ["Y", "{y}", "Take"],
	"item": ["G", "{x}", "Item"],
	"item_next": ["T", "the d-pad down", "the small arrow"],
	"cast": ["the mark's key (Q E F C X V)", "{lb} and the mark's button", "the mark's button"],
	"climber": ["Tab", "{back}", "the Climber button"],
	"inventory": ["I", "the d-pad up", "the Bag button"],
	"menu": ["Esc", "{start}", "Menu"],
	"restart": ["hold R", "hold {back}", "Menu, then Restart"],
	"dismiss": ["Enter or a click", "a press of the right stick", "a tap"],
	"choose": ["the arrows (or a click on a swatch)", "the d-pad or stick", "the arrows or a swatch"],
	"tools": ["B", "{lb} and {lt}", "Tools"],
	"cars": ["Q and E, the mouse wheel, or the arrows at the screen's edges", "{lb} and {rb}, or the d-pad", "swipe, or tap the arrows at the screen's edges"],
}

## The Entity's colours (the interface's other colours are in ui.gd).
const GLOW := Color(0.79, 0.75, 1.0)
const DEEP := Color(0.42, 0.36, 0.84)
const EYE := Color(0.11, 0.08, 0.22)
const SPARK := Color(1.0, 0.89, 0.63)


## A tip's entry (resolving fallbacks), or {}.
static func entry(id: String) -> Dictionary:
	return TIPS.get(resolve(id), {})


## The tip id that answers for `id`: itself, or the part before its last "_".
static func resolve(id: String) -> String:
	var at := id
	while not TIPS.has(at):
		var cut := at.rfind("_")
		if cut <= 0:
			return ""
		at = at.left(cut)
	return at


## The tip ids in Archive order, group by group.
static func ordered(group: String) -> Array:
	return TIPS.keys().filter(func(k): return TIPS[k]["group"] == group)


## A line for a moment or page, filled in. `seed` picks which (the same seed,
## the same line: a page that rebuilds keeps its line).
static func line(key: String, seed := -1, fill := {}) -> String:
	var list: Array = LINES.get(key, [""])
	var i := randi() % list.size() if seed < 0 else posmod(seed, list.size())
	return fill_words(list[i], fill)


## Fills {beast}, {floor}... from `fill` (a "Beast" key is made for each "beast").
static func fill_words(text: String, fill: Dictionary) -> String:
	for k in fill:
		var v := str(fill[k])
		text = text.replace("{%s}" % k, v)
		text = text.replace("{%s}" % String(k).capitalize(), v.left(1).to_upper() + v.substr(1))
	return text


## Fills {move}, {attack}... with the words for the device in use:
## mode "keys", "pad" or "touch"; `ps` for PlayStation button names.
static func fill_keys(text: String, mode := "keys", ps := false) -> String:
	var col := 1 if mode == "pad" else (2 if mode == "touch" else 0)
	for k in KEYS:
		var tag := "{%s}" % k
		if text.contains(tag):
			text = text.replace(tag, Controls.pad_text(KEYS[k][col], ps))
	return text.left(1).to_upper() + text.substr(1)


# --- drawing --------------------------------------------------------------------

## The Entity's face: a soft glowing orb with two dark eyes (they blink),
## faint rays, a wry little mouth and sparks drifting around it, bobbing
## gently. `t` is the time in seconds; `a` fades it all.
static func draw_face(ci: CanvasItem, c: Vector2, r: float, t: float, a := 1.0) -> void:
	var bob := sin(t * TAU / 3.2)
	c.y += bob * r * 0.09
	var tilt := -0.05 * bob  # leans a touch as it bobs
	# The glow around it, then the orb, lighter toward the top.
	for i in 6:
		var k := 1.0 - i / 6.0
		ci.draw_circle(c, r * (0.82 + 0.5 * k), Color(DEEP, 0.07 * a))
	ci.draw_circle(c, r * 0.8, Color(DEEP.lerp(GLOW, 0.35), 0.95 * a))
	ci.draw_circle(c + Vector2(0, -r * 0.06), r * 0.7, Color(GLOW, 0.95 * a))
	ci.draw_circle(c + Vector2(-r * 0.05, -r * 0.16), r * 0.5, Color(GLOW.lerp(Color.WHITE, 0.55), 0.9 * a))
	ci.draw_circle(c + Vector2(-r * 0.12, -r * 0.3), r * 0.2, Color(1, 1, 1, 0.55 * a))
	# Faint rays, pulsing.
	var ray_a := (0.45 + 0.25 * sin(t * 2.1)) * a
	for i in 6:
		var ang := -PI / 2.0 + TAU * i / 6.0 + 0.2 + tilt
		var d := Vector2.from_angle(ang)
		ci.draw_line(c + d * r * 0.9, c + d * r * (1.12 + 0.06 * sin(t * 3.0 + i)), Color(GLOW.lerp(Color.WHITE, 0.4), ray_a), maxf(1.0, r * 0.06), true)
	# The eyes: dark ovals with a glint, blinking now and then.
	var blink := fmod(t, 4.3)
	var open := 1.0 if blink > 0.14 else absf(blink - 0.07) / 0.07
	open = maxf(open, 0.12)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.24, -r * 0.04).rotated(tilt)
		ci.draw_colored_polygon(_oval(e, Vector2(r * 0.105, r * 0.15 * open)), Color(EYE, a))
		if open > 0.5:
			ci.draw_circle(e + Vector2(r * 0.03, -r * 0.05), maxf(0.8, r * 0.035), Color(1, 1, 1, 0.95 * a))
	# A small wry mouth, a little higher on one side.
	var m := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		m.append(c + Vector2(lerpf(-0.12, 0.14, k) * r, r * (0.24 + 0.05 * sin(PI * k) - 0.05 * k)).rotated(0.0))
	ci.draw_polyline(m, Color(EYE, 0.8 * a), maxf(1.0, r * 0.06), true)
	# Sparks drifting up and around it.
	var spots := [Vector2(0.86, 0.62), Vector2(-0.9, 0.5), Vector2(0.62, -0.92), Vector2(-0.55, -0.8)]
	for i in spots.size():
		var ph := fmod(t * 0.35 + i * 0.27, 1.0)
		var p: Vector2 = c + spots[i] * r + Vector2(sin(t * 1.3 + i) * r * 0.06, -ph * r * 0.35)
		var sa := sin(PI * ph) * (0.6 + 0.4 * sin(t * 4.0 + i * 2.0)) * a
		var col := SPARK if i % 2 == 0 else Color.WHITE
		ci.draw_circle(p, maxf(1.0, r * (0.07 if i < 2 else 0.05)), Color(col, sa))
		ci.draw_circle(p, maxf(2.0, r * 0.15), Color(col, sa * 0.2))


static func _oval(c: Vector2, rad: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * rad.x, sin(ang) * rad.y))
	return pts


## The Entity's face as a control (menus): animated, with a speech tail
## pointing right when `tail` is set.
class Face extends Control:
	var tail := true
	var t := 0.0
	var outer: GDScript  # entity.gd itself (an inner class can't call its statics directly)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		t = randf() * 3.0
		outer = load("res://scripts/entity.gd")

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var r := minf(s.x - (8.0 if tail else 0.0), s.y) * 0.4
		var c := Vector2(r * 1.25, s.y * 0.5)
		if tail:
			var tip := Vector2(s.x, s.y * 0.5)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(1, -7), tip + Vector2(-9, 0), tip + Vector2(1, 7)]), Color(UI.ENTITY_BG, 0.95))
			draw_polyline(PackedVector2Array([tip + Vector2(1, -7), tip + Vector2(-9, 0), tip + Vector2(1, 7)]), Color(GLOW, 0.4), 1.0, true)
		outer.draw_face(self, c, r, t)


## The Entity says something (menus): its face, then a bubble with its tag
## and the line. `face` is the face's size; `heading` replaces the tag.
static func says(text: String, face := 46.0, heading := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := Face.new()
	f.custom_minimum_size = Vector2(face + 12.0, face)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(f)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.entity_bubble())
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	bubble.add_child(col)
	var tag := Label.new()
	tag.text = heading if heading != "" else TEXT["tag"]
	UI.style_label(tag, "eyebrow", 14, Color(UI.PERIWINKLE, 0.95))  # (its name tag)
	col.add_child(tag)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160.0
	l.add_theme_font_size_override("font_size", UI.SIZE_BODY + 1)
	l.add_theme_color_override("font_color", GLOW.lerp(Color.WHITE, 0.55))
	col.add_child(l)
	row.set_meta("entity_line", text)
	return row
