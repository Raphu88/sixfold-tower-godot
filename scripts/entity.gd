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
const Pronouns := preload("res://scripts/pronouns.gd")  # (lines that speak of the climber: {they}, {them}, {their}...)

## Its name and the words around it.
static var TEXT := {
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
	"away": "%s to send away",  # under a tip in a menu (it stays until sent away)
	"away_touch": "tap",
	"away_keys": "click or L",
}

## How long the Entity's words stay on screen in a climb, in seconds. A
## first-time tip: tip_base, plus tip_per_char for each letter, kept between
## tip_min and tip_max. A tidbit (one short line): bit_base plus
## bit_per_char a letter. A tidbit kept waiting for its turn longer than
## bit_stale is dropped. None of it stops the game, and a tap or click on
## the bubble or the sphere sends it away sooner. In menus and on the train
## there is no timer: a tip stays until it's sent away (a click or tap on
## it, or L / the right stick).
static var TIMING := {
	"tip_base": 6.0, "tip_per_char": 0.11, "tip_min": 12.0, "tip_max": 24.0,
	"bit_base": 7.2, "bit_per_char": 0.07, "bit_stale": 18.0,
}

## Short lines for moments and pages. One is picked (they're said in the
## Entity's voice). {floor}, {beast}, {Beast}, {tower} and {mark} are filled in.
static var LINES := {
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
	"deeds": [
		"Deeds. The towers notice what you do. So do I.",
		"Small things, done well, add up. I wrote them down.",
		"Thirty-six of them. You'll want them all. I know you.",
	],
	"blades": [
		"Six blades, one in each tower. They wait for the patient.",
		"A blade at the summit is a blade for good.",
		"They wake slowly. Most good things do.",
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
	"rank_up": [
		"{rank}. They say your name a little louder now.",
		"{rank}. Doors open. Some of them were locked for a reason.",
		"{rank}, then. I wrote it down.",
	],
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
	["station", "Stations, renown and titles"],
	["screens", "Screens"],
	["creator", "Creator tools"],
]

## Every tip, in Archive order within its group: the Entity's line ("tip",
## 1 or 2 short sentences, shown the first time) and a fuller, plain
## explanation ("more", in the Archive). Ids are what code passes to
## main.tip("id"). An id that isn't here falls back to the part before its
## last "_" ("puzzle_mirrors" -> "puzzle", "door_iron" -> "door"), so a new
## puzzle or door kind still gets a tip until it has its own.
static var TIPS := {
	# --- first steps ---
	# A new climber's start (start_pages.gd, new_start.gd): the slots, the
	# introduction, the name and the questions.
	"slots": {"group": "start", "name": "Climbers and slots",
		"tip": "Six climbers may climb, each in a slot of their own. Continue plays the last one; New Climber begins another.",
		"more": "The title screen shows Continue (the climber played last) above New Climber once a climber exists. New Climber begins a new climber in an empty slot: there are six, and each keeps its own marks, essence, crystals, train, heirlooms, look, name and record. Climbers, on the title screen, shows every slot: choose a card to play that climber, an empty one to begin a new climber there, or Delete under a card to forget a climber for good (it asks twice). Settings are shared by every climber."},
	"intro": {"group": "start", "name": "The introduction",
		"tip": "I'll tell you what you need, a line at a time. Next goes on. On later climbers you may skip me.",
		"more": "A new climber begins on a black screen, where I say a few lines about the train, the towers, the marks and the other way: one idea each. Next (or a tap, Enter or A) goes to the next line, Back to the one before. The first climber hears them all; once a climber has been made on this device, Skip goes straight to making the next one."},
	"create_name": {"group": "start", "name": "Name and pronouns",
		"tip": "A name, if you like, and how others speak of you. The Dice offers a name; the pronouns are used by everyone who mentions you.",
		"more": "The first step of a new climber: a name (optional; the Dice picks one) and pronouns: he, she or they. Everyone who speaks of you uses them: me, other climbers, the Noble, the Makers, and the notices and logs. The example line shows how they read. Next goes on to your look. Both can be changed later on the Appearance page (the climber screen's Marks tab, or your car on the train)."},
	"questionnaire": {"group": "start", "name": "Before you climb",
		"tip": "Three questions. What you did before decides your weapon and armour, where you grew up your first tower and home, and why you climb how hard your start is.",
		"more": "After your look come three questions. What did you do before? Soldier (sword, chain armour), Hunter (shortbow, dagger, leather armour), Labourer (war hammer, padded armour), Beggar (a dagger, no armour), Scholar (sword cane, padded armour) or Sailor (flintlock, leather armour); these pieces are kept as heirlooms, so every climb begins with them, and every climb also carries the shortbow. Where did you grow up? Near one of the six towers: your first climb is there, and its station is your home. Why climb? Born into it (the easiest: fine gear, 30 crystals of your home's kind, your family's title), Hired by someone (common gear, 15 crystals, your employer's title, a contract from the Noble already in hand) or Self made (the hardest: worn gear until your first mark, nothing else, but renown comes a quarter faster until your first title). Back changes an answer; the summary shows what you'll begin with before Begin. Nothing here decides whether you'll take a mark or refuse it: that waits for the tower."},
	"entity": {"group": "start", "name": "The Entity",
		"tip": "You can see me. Good. When something new finds you, I'll say so, and keep every word in the Archive.",
		"more": "The Entity is the small glowing presence that speaks in the corner of the screen. The first time you meet anything new, it says a line or two about it. Dismiss a tip with {dismiss}, or let it fade; it never stops the game. Everything it has told you is kept here in the Archive (the Library: a car on the train, or {menu}, then Library, in a climb), grouped by subject; subjects you haven't met yet show as ???. Settings & Controls can turn the tips off (the Archive still fills in), and Replay tips makes the Entity tell you everything again."},
	"move": {"group": "start", "name": "First steps",
		"tip": "Walk with {move}. Strike with {attack}. Roll through what you can't stop; parry what you can with {parry}.",
		"more": "Strikes chain into a combo that ends in a heavy finisher; each one costs stamina, and stamina waits a moment after you attack before it refills, so mashing leaves you winded; act past empty anyway and your max stamina shrinks (fatigue) until a Stamina Vial or a camp's rest. A roll ({roll}) makes you untouchable for a moment and costs stamina. A parry ({parry}) on time takes no damage, staggers the attacker and sends arrows back. A jump ({jump}) carries you over chasms and burning floor, but attacks still hit you in the air. Hitting a staggered foe is a riposte for 2.5 times the damage, and striking a foe from behind (a backstab) deals 50% more."},
	"glint": {"group": "start", "name": "The glint",
		"tip": "A white star and a ting: the blow lands a quarter second later. Parry on the glint, or be somewhere else.",
		"more": "Every monster attack keeps one rhythm: a wind-up, then the glint exactly a quarter of a second before the blow lands, then a recovery. Parry on the glint and it always works; parry a beat after it for a perfect parry (a longer stagger and more stamina back). Red circles and cones that can't be parried are for rolling out of. After an attack a monster is open for most of its recovery: a gold ring pulses around it and your hits deal 60% more. Traps glint too."},
	"fatigue": {"group": "start", "name": "Fatigue",
		"tip": "You pushed past empty, so your stamina bar shrank. A Stamina Vial or a camp's rest gives it back. The stair won't.",
		"more": "Stamina refills quickly, but when you roll, strike, shoot or jump with too little of it, the action still happens: what your stamina can't pay is taken off your max stamina instead. That is fatigue. The lost end of the stamina bar shows dark and hatched, and stamina refills only up to what's left. Fatigue never shrinks the bar below a part of it; past that a roll or a jump is simply too winded. A Stamina Vial shakes off all of it and fills your stamina (it's usable even with the bar full), a camp's rest clears it, and every climb starts without it. The stair's rest fills your stamina but leaves fatigue as it is. On a computer, hovering over the bars says how much you've lost."},
	"death": {"group": "start", "name": "Falling",
		"tip": "You fell. What you carried this climb is gone. What you are is not.",
		"more": "Falling ends the climb. The gear and items you carried and any essence you hadn't banked are lost (lost pieces may turn up again; see Lost on the way down), and the next climb starts again on floor 1 ({restart}). Your marks and their growth, the essence settled in you, your heirlooms and your record all stay. On the first climb a fall still brings the Regard, but the mark it leaves is faint."},
	# --- essence and marks ---
	"essence": {"group": "essence", "name": "Essence",
		"tip": "That light flying into you is essence. It's only yours once you bank it at a stair.",
		"more": "Monsters leave essence when they fall, each kind its own type (Air, Water, Iron, Fire, Stone, Blade), and every kill also gives a little of the tower's own essence. It flies into you and is banked at the next stair you take. Fall before the stair and the unbanked essence is lost. Meanwhile your body soaks up what it does: the hand from strikes, the legs from rolling through attacks, the heart from taking hits, the brow from parries, the throat from hitting several foes at once, the back from backstabs and finishing blows."},
	"bank": {"group": "essence", "name": "Banking at the stair",
		"tip": "Banked, and split three ways: some to your body, some to your marks, some into crystals. The stair's line says how much went where.",
		"more": "Every stair banks the essence you gathered on the floor below, and splits it three ways. Your body's share soaks into your body parts by what each did on the floor: unmarked parts fill toward a new mark, and every part settles it as density (each type an attribute with a small passive bonus: the climber screen's Essence tab). Your marks' share grows your marks: each kind goes to the marks of that kind, and a kind none of them is made of spreads thinly over all of them. The crystals' share becomes essence crystals, the train's money (To crystals, in Settings, sets that share; body and marks share the rest). The stair's line says how much went where. Bonds grow across climbs, never within one. Taking the stair is also a rest: burns heal, poison is cured, you recover a third of your health and all your stamina."},
	"split": {"group": "essence", "name": "The split",
		"tip": "What you bank splits three ways now: your body, your marks, crystals. The stair's line says how much went where.",
		"more": "Banked essence is divided, not copied. Your body's share soaks into your parts by what each did (unmarked parts fill toward a new mark) and settles as density. Your marks' share grows your marks, each kind going to the marks of that kind. The crystals' share becomes crystals, the train's money. To crystals, in Settings, sets the crystals' share; body and marks share the rest. Ask me how essence flows for the numbers."},
	"crystal_eat": {"group": "essence", "name": "Eating a crystal",
		"tip": "Eaten. A crystal's essence flows into you the natural way: your body and your marks share it. You can't steer it.",
		"more": "A crystal can be eaten instead of spent: the climber's book (its Essence ribbon, then Crystals and tinctures), or the Inventory in a climb. Its essence flows into you as a stair's would, without the crystals' share: your body and your marks divide it, each kind to the marks of that kind. Nothing steers it. To choose where essence goes, drink a tincture."},
	"tincture": {"group": "essence", "name": "Tinctures",
		"tip": "A tincture goes where you choose: one mark, or one unmarked part. The only way to steer essence.",
		"more": "A tincture is a stoppered vial of one kind of essence. Drink it and choose where it goes: into one of your marks (it grows; its own kind counts fully, any other a little) or into an unmarked body part (it soaks toward a new mark there, and leans that mark toward the tincture's kind). Vaults and secret rooms hold them, and now and then a fallen monster leaves one; the outfitter stocks some each visit; the Workshop's Tinctures counter crafts them from crystals of their kind. On your belt in a climb, or packed for your next climb on the train, drink them from the book's Crystals and tinctures, your Loadout or the Workshop. A tincture left on your belt comes home packed for your next climb."},
	"earned_mark": {"group": "essence", "name": "A part nearly full",
		"tip": "One of your parts is nearly full. Breaking into a sealed room can bring rewards, if you prove yourself to those that watch.",
		"more": "An unmarked part that is fully soaked can take a new mark at a summit. It can come sooner: break into a sealed wing on an early floor, keep its rule and beat it, and a Maker may grant the mark there. A fall with a full part may leave a faint mark on it instead. At most one new mark a climb."},
	"wing_watch": {"group": "essence", "name": "Those that watch",
		"tip": "A sealed door. Breaking in can bring rewards, if you prove yourself to those that watch.",
		"more": "A sealed wing asks one question: take no hit, be quick, or fell every foe staggered. Keep its rule and its vault opens. On an early floor, with a part of you fully soaked, keeping the rule may bring more than the vault: a Maker may grant a new mark there. At most one new mark a climb."},
	"maker_mark": {"group": "essence", "name": "A mark granted",
		"tip": "You kept the rule, early, with a part full. A Maker noticed, and marked you for it.",
		"more": "Beat a sealed wing keeping its rule on an early floor while one of your unmarked parts is fully soaked, before you've taken a new mark this climb, and the Maker of Marks grants the mark there instead of at the summit. Its bond is chosen as a summit's would be: by the essence you've banked since your last mark, and how you fought. At most one new mark a climb."},
	"fall_mark": {"group": "essence", "name": "A mark in falling",
		"tip": "You fell with a part full, and it took a mark anyway. A faint one. Feed it.",
		"more": "Fall with a fully soaked part and there's a small chance it takes a mark as you fall, faint like a first climb's fallen mark: weaker until it has soaked up its debt of essence. At most one new mark a climb."},
	"regard": {"group": "essence", "name": "The Regard",
		"tip": "The guardian has noticed you. I noticed it noticing. Your most-used part bears a mark now.",
		"more": "Your first climb starts with no mark. Reach floor 6 and it opens with the Regard: the tower's guardian, its beast, takes notice, the body part you used most takes your first mark at full strength, and the essence you gathered most decides which bond it is. Then the guardian lets you choose: leave for the train with your mark, or climb on (the Proving follows on the same floor). Fall before floor 6 and you are still regarded, but the mark is faint: as strong as the floor you reached (half strength on floor 1, a tenth more each floor up) until it has soaked up more essence. Break a vault's seal or a lock-in room's doorway with bare fists on the first climb, or slip past a stair's barrier, and the guardian refuses to mark you instead: you are Unbound."},
	"first_climb": {"group": "essence", "name": "Your first climb",
		"tip": "No mark yet. Climb. On floor six the guardian will take notice.",
		"more": "The first climb is a climb like any other, with camps after floors 3, 6 and 9. You carry no mark at first. Floor 6 opens with the Regard: the tower's guardian marks the body part you used most. Fall before it and you're still marked, but faintly: the higher you got, the stronger the mark."},
	"death_mark": {"group": "essence", "name": "A mark from a fall",
		"tip": "You fell before floor six. The guardian marked you anyway, as strongly as you climbed.",
		"more": "A first mark from a fall is faint, its strength set by the highest floor you reached: half strength on floor 1, a tenth more each floor, full on floor 6. A faint mark hits softer and costs more until it has soaked up its debt of essence (the weaker it is, the bigger the debt); then it is a full mark and grows as any other."},
	"regard_exit": {"group": "essence", "name": "The guardian's exit",
		"tip": "It offers you a way out. Leave with your mark, or climb on. Both are fine. One is braver.",
		"more": "After the Regard on floor 6 the guardian offers an exit. Leave with the mark and the climb ends as a survived one: what you wear and your pack come home, your belt turns into crystals and the outfitter pays. Climb on and the Proving waits on the same floor, then the floors above, to the summit; from then on a fall is a fall."},
	"regard_climb_on": {"group": "essence", "name": "Climbing on",
		"tip": "Marked, and still climbing. The Proving first. A fall now costs what any fall costs.",
		"more": "Having chosen to climb on after the Regard, the climb goes on like a marked one: the Proving on floor 6, a camp after it, then floors 7 to 12 and the guardian at the summit. Fall now and you lose your pack and belt as on any climb; your new mark stays."},
	"lethal_again": {"group": "tower", "name": "Floor six again",
		"tip": "Back on floor six. The Proving won't ask twice, unless you choose its lethal door.",
		"more": "A fall can take you below floor 6 after you've won the Proving. Climbing back, floor 6 is an ordinary floor: you don't face the Proving again on that climb. You can choose the Lethal Proving instead, harder and for a greater prize; die beyond its door and the climb ends."},
	"barrier_gate": {"group": "tower", "name": "The stair's gate",
		"tip": "The stair's gate is coming down. Roll under it before it shuts, and you skip the floor. The tower won't like it.",
		"more": "On floors 1 to 6 an iron gate closes over the stair as you arrive: the ring over it counts down 30 seconds. Until it shuts you can roll ({roll}) under it and slip past. Once it's shut, it can still be broken with weapons, bare fists or spells, but it takes many blows (a blow only counts when it strikes no foe). Either way you skip the floor's task and the tower sends a horde of 6. The stair opens when the horde has fallen. With no mark, doing it makes you Unbound."},
	"barrier_ward": {"group": "tower", "name": "The stair's ward",
		"tip": "A ward rises over the stair. Only this tower's own essence breaks it, and not easily.",
		"more": "On floors 7 to 12 a ward of light rises over the stair, fully up within 15 seconds (you can still roll through it while it rises). Once up, only the essence of this tower's own marks hurts it: a spell of that essence, a weapon or an item carrying it. Anything else, it drinks. Breaking it takes a while, skips the floor's task, and the tower sends a horde of 12."},
	"barrier_break": {"group": "tower", "name": "Breaking a barrier",
		"tip": "It cracks. Keep at it and it breaks. A horde will come through.",
		"more": "Each blow at a stair's barrier that strikes no foe cracks it a little: a finisher or a spell more. A gate breaks to any weapon, bare fists or spells; a ward only to its tower's own essence. Broken, it skips the floor's task, and the tower sends a horde."},
	"barrier_slip_warn": {"group": "tower", "name": "Caught at the gate",
		"tip": "It caught you this once. Roll in again and you're through. Skipping the floor brings a horde, and with no mark, the guardian refuses you.",
		"more": "The very first time you roll into a closing barrier, it throws you back as a warning. After that, a roll under a closing gate (or through a rising ward) slips you past: the floor's task is skipped and the tower sends a horde. With no mark yet, the guardian refuses you on the spot and you become Unbound. A marked climber who does it three times is met by a Maker."},
	"barrier_horde": {"group": "tower", "name": "The horde",
		"tip": "A horde, for skipping the floor. The stair opens when it's all down.",
		"more": "Slipping past or breaking a stair's barrier skips the floor's task, and the tower answers with a horde: 6 of its creatures for a gate, 12 for a ward, awake and coming for you. The stair waits until the last of them falls; then it opens. The count over the stair shows how many are left."},
	"barrier_unbound": {"group": "tower", "name": "Refused",
		"tip": "No mark, and you went around the tower's rules. The guardian refuses you. You're Unbound now.",
		"more": "A climber with no mark yet who slips past or breaks a stair's barrier is refused by the guardian on the spot: no mark, now or later, and you become Unbound (banked essence fills your body parts raw). The horde still comes. The climb goes on."},
	"barrier_maker_soon": {"group": "tower", "name": "Noticed",
		"tip": "Three times around the stairs. Something is waiting for this horde to fall.",
		"more": "Slipping past or breaking a stair's barrier is counted across every climb. A marked climber who has done it three times (and every three times after) is confronted by a Maker once that floor's horde has fallen."},
	"barrier_maker": {"group": "tower", "name": "A Maker's confrontation",
		"tip": "One of them came for you. Answer it. Carefully.",
		"more": "A Maker confronts a marked climber who keeps slipping past the stairs' barriers. Choose an answer (left and right and confirm, its number, or a tap). Keep the rules and it lets you go; defy it and it takes half the essence you carry. Its words are not written yet."},
	"ending": {"group": "tower", "name": "The ending",
		"tip": "All six guardians. I wrote it all down. Keep going, if you like.",
		"more": "Once all six towers' guardians have been beaten, the ending plays after the last summit. Then the same climber plays on: every tower stays open, and everything you have stays yours."},
	"casting": {"group": "essence", "name": "Casting",
		"tip": "Your mark answers to {cast}. Tap to cast; hold to choose a spell while the world slows. Choosing never casts.",
		"more": "Each mark is a bond with a body (an upgrade to a basic action), a passive, and spells learned as it grows (at steps 1, 2, 4 and 5; step 3 changes the first). A mark fills with essence during a climb as its body part does its work, and glows once a spell can be cast. Tap the mark's key ({cast}) to cast its selected spell, or hold it to open the wheel of its spells, point at one and let go: that spell goes on the button, and nothing is cast until you tap it. The climber screen ({climber}) has a page for every mark with all its spells."},
	"overdraw": {"group": "essence", "name": "Overdraw",
		"tip": "You cast with too little essence and the mark burned. It heals at the stair. Do it again only if it's worth it.",
		"more": "Casting without enough essence still fires the spell, but the body part burns: a burned hand weakens your strikes, burned legs make rolls cost more and carry you less far, and so on. Burns heal at the next stair (or with a Cleansing Tonic)."},
	"abilities": {"group": "essence", "name": "Your abilities",
		"tip": "Every spell your marks know, the button for each and what it costs: {abilities}.",
		"more": "The climber screen's Abilities tab lists each mark with the button that casts it, then every spell it knows, and those it will learn (dimmed, with the step that teaches them). Each shows what it does and what it costs; choose one for its full numbers and what later steps change. During a climb, {abilities} to look at it (held, it closes again when you let go). Tap a mark's button ({cast}) to cast its chosen spell, or hold it to pick another from its wheel (picking never casts). The first time you cast each spell, its name and what it does show at the top of the screen. On the train the Abilities page also offers Try your abilities: a quiet room with training dummies."},
	"reactions": {"group": "essence", "name": "States and reactions",
		"tip": "Two things you did to it met. That was a reaction. Wet and lightning, fire and poison: try them together.",
		"more": "Spells leave states on a foe: charged, airborne, soaked, burning, poisoned, bleeding, slowed, or unseen (it has lost track of you). Small badges over its head show what it holds. When a second state lands on a foe that holds the first, a reaction fires once: soaked and charged Conduct lightning to every soaked foe nearby and stun them; soaked and burning make Steam, a cloud that hides you; burning and poison spread as Fumes; a foe slammed out of the air makes a Crater; charged and airborne bring a Skybolt; draining a bleeding foe is a Hemorrhage (the drain doubled); a slowed foe Smoulders (burns twice as long); and poison on a foe that has lost track of you is an Ambush (five more stacks). The Unbound's essences leave states too: Water soaks, Fire burns, Blade bleeds."},
	"synergies": {"group": "essence", "name": "Synergies",
		"tip": "Your marks are talking to each other. Each lends the other a trait. That's a synergy. Your book lists them.",
		"more": "Marks you carry together answer each other. Any two marks lend each other one trait, about a quarter as strong as the real thing: Stormcaller lends Charge, Tidecaller Soak, Warden a thin barrier when you cast, Venomist a stack of poison, Surgeon a small bleed, and so on, so each mark's spells pick up a touch of the other's. Twelve pairs go further and form a named synergy instead: Tempest (Stormcaller and Tidecaller), Dust Devil (Windwalker and Sandshaper), Whirling Steel (Blade Forger and Windwalker), Forge Runes (Flameblade and Rune Artist), Wildfire (Flame Contractor and Flamewing), Undying (Warden and Rekindler), Bloodletter (Deepcaller and Surgeon), Ambusher (Hunter and Ashwalker), Toxic Precision (Venomist and Surgeon), Menagerie (Covenant and Grafter), Scald (Tidecaller and Flame Contractor) and Lightning Steel (Stormcaller and Blade Forger). A teammate's marks count while they fight beside you. Your book's Marks section lists what your marks lend each other and the named synergies you hold; the Library lists every named synergy you have formed."},
	"new_mark": {"group": "essence", "name": "A new mark",
		"tip": "Another part of you soaked up enough. A new mark takes hold.",
		"more": "Your body's share of the essence you bank soaks into your unmarked parts, by what each one does; the fuller a part, and the more marks you carry, the slower it fills. A full part takes a new mark at a summit, or sooner from a Maker for a sealed wing won early with its rule kept, or now and then, faint, as you fall. Its bond is shaped by the essence you've banked since your last mark (a tincture drunk into the part leans it too). At most one new mark a climb. The climber screen shows which part is forming its mark next, and which bond it would be."},
	# --- secret essences (secret.gd) ---
	"secret": {"group": "secret", "name": "Core essences",
		"tip": "Making and Unmaking: the core essences, the Makers' own. Only great foes leave them, never an ordinary monster.",
		"more": "Making and Unmaking are the two core essences, the Makers' own essence, which every other essence comes from. Ordinary monsters never leave them: only great foes do. A tower's beast leaves mostly Making and some Unmaking; the Proving's shadow of the beast the same, but less; a mirror image of you mostly Unmaking and some Making; a champion (a sealed wing's, or the Proving's sentinel) a little of one or the other, depending on the tower. Like other essence there's more of it higher up. They aren't currency."},
	"secret_path": {"group": "secret", "name": "Your path",
		"tip": "Chosen, for good. Only that essence soaks into you now. Bank it at the stair and it settles in your body as core essence.",
		"more": "The first time a great foe falls and its core essence rises, you choose your path: Making or Unmaking. The choice is for good. From then on only your path's essence soaks in. You carry it unbanked like other essence (a fall loses it) and bank it at the stair, where half of it settles in your body as core essence: evenly, in all six body parts, until your body is saturated. It never takes a mark and never pushes out a bond. The core essence in your body shows as your aura, which grows in six steps, each a real change in how you play."},
	"secret_pass": {"group": "secret", "name": "Passing through",
		"tip": "That one isn't yours. It passes through you and is gone. Nothing of it is banked.",
		"more": "Once you've chosen your path, the other core essence still rises from great foes, but it passes straight through you and out the other side. None of it is kept or banked (unless you carry a vessel). Your path's essence soaks in as before."},
	"core_essence": {"group": "secret", "name": "Core essence",
		"tip": "Your path's essence settles in your body: core essence, a little in every part. It comes slowly, and it stays.",
		"more": "Banked at the stair, half of your path's essence settles in your body as core essence. It spreads evenly over your six body parts and can't be moved, poured or drained. It comes far more slowly than other essence, only from great foes. Each part holds 120 at most, so once every part is full your body is saturated and no more settles; what comes after that will one day start to replace your other essence (Ascendance: coming soon). The total in your body sets your aura. For the Unbound it takes room in each body part beside its Node, leaving less for the Node to hold, and adds its own touch to every technique."},
	"aura": {"group": "secret", "name": "Your aura",
		"tip": "Your core essence shows: an aura. The more your body holds, the stronger it shows and the more it gives you.",
		"more": "Your aura is your core essence made visible: a living green glow for Making, a flickering violet haze for Unmaking, around you as you climb. It grows in six steps with the core essence in your body (at 12, 36, 72, 126, 198 and 300), for marked climbers and the Unbound alike. Making: health regrows, kills mend you, healing grows stronger, and at the last step a killing blow leaves you standing once a floor. Unmaking: more damage for less health, an erosion that hurts awake monsters beside you, strikes that ignore armour, and at the last step slain foes come apart. Its gem beside your health bar shows a pip for each step (hover it for what they do), and the climber screen's Essence tab shows them all."},
	"core_saturated": {"group": "secret", "name": "Saturated",
		"tip": "Your body holds all the core essence it can. Ascendance is still to come.",
		"more": "Every part of your body is full of core essence (with the Unbound's own essence, each holds 120). No more core essence settles for now: the path's essence you carry up still banks, but nothing more stays. One day it will start to replace your other essence, until you are core essence through and through: Ascendance. Coming soon."},
	"vessel": {"group": "secret", "name": "The vessel",
		"tip": "A vessel on your belt. What passes through you, it can hold: the essence that isn't your path, 30 at most.",
		"more": "A vessel is a sealed glass vessel bound in brass. The workshop's bench brews one (a Rune Artist with their own essence; anyone else through the Rune Artist there, for a premium), and very rarely a vault holds one. It takes one kind of space on your belt and is never used up. Once you have a path, the other secret essence that rises from great foes curls into it instead of passing through you, up to 30, one kind only. What it holds is unbanked: fall and the vessel is lost with your belt. Survive or read a recall scroll and it comes home to your stash, filled or not (never broken into crystals); from there you can pack it for your next climb."},
	"vessel_capture": {"group": "secret", "name": "Captured",
		"tip": "Caught, not passed. The vessel holds it now. Keep it whole until you're home.",
		"more": "Each time the other secret essence rises from a great foe, the vessel on your belt takes what it has room for; the rest still passes through you. Your path's essence soaks into you as before. The gauge beside your health bar shows how full it is."},
	"vessel_full": {"group": "secret", "name": "A full vessel",
		"tip": "The vessel is full. Bring it home and it can be traded, worked into a piece, or offered.",
		"more": "A full vessel holds 30 of a secret essence. Kept in your stash on the train, it can be traded to the outfitter (Sell: 120 crystal essence of one kind, or 30 of every kind), worked into a piece at the workshop's bench (one rank past +3, or a deep rune at the Inscribe spell's full strength), or offered to the Maker of Marks as the Developer's bribe. Carried up on your belt, it can be offered to a Maker when you plead for a change of path: it is likelier to agree, and keeps the vessel."},
	"flow_2": {"group": "secret", "name": "The aura: step 2",
		"tip": "Step two. Making: every kill mends you a little. Unmaking: your aura erodes awake monsters beside you.",
		"more": "At 36 core essence. Making: every monster that falls mends you a little, and your health regrows faster. Unmaking: monsters that are awake and right beside you take a little damage every second; the damage-for-health trade grows."},
	"flow_3": {"group": "secret", "name": "The aura: step 3",
		"tip": "Step three. What your aura gives grows stronger.",
		"more": "At 72 core essence. Making: your health regrows faster and kills mend you more. Unmaking: the erosion bites harder and your damage grows (and your health shrinks a little more)."},
	"flow_4": {"group": "secret", "name": "The aura: step 4",
		"tip": "Step four. Making: healing works far better. Unmaking: your strikes ignore armour.",
		"more": "At 126 core essence. Making: everything that heals you heals much more: Healing Vials, healing springs, your marks' heals and weapons that heal on a kill. Unmaking: your weapon strikes ignore armour: a shellback's shell no longer turns them and a knight's guard no longer shrugs off light blows. Beasts still don't flinch."},
	"flow_5": {"group": "secret", "name": "The aura: step 5",
		"tip": "Step five. Everything your aura gives grows again.",
		"more": "At 198 core essence. Making: regrowth, mending and healing all grow a little more. Unmaking: the erosion and your damage grow again."},
	"flow_6": {"group": "secret", "name": "The aura: step 6",
		"tip": "The last step. Making: once a floor, a killing blow leaves you standing. Unmaking: slain foes come apart and hurt those beside them.",
		"more": "At 300 core essence. Making: once on each floor, a blow that would kill you leaves you at a quarter of your health instead, in a burst that throws back the monsters around you. Unmaking: a monster you slay comes apart, hurting the monsters right beside it by part of its health (an undone monster doesn't undo again)."},
	# --- the Unbound (unbound.gd, unbound_run.gd, technique.gd) ---
	"unbound": {"group": "unbound", "name": "Unbound",
		"tip": "No mark, now or ever. Six Nodes in your body sleep until essence wakes them; then they grow as you use them.",
		"more": "An Unbound climber carries no tower bond. Their six body parts are Nodes: the Hand Node, the Legs Node, the Heart Node, the Brow Node, the Throat Node and the Back Node. A Node starts asleep. Each kind of essence you bank flows to its natural Node (Blade the hand, Air the legs, Stone the back, Water the throat, Fire the brow, Iron the heart; on the train you can route a kind elsewhere, on the climber screen's Techniques tab) and soaks into it; when enough has soaked in, the Node wakes. Awake, a Node has two numbers: what it holds (the essence that powers its techniques, which you can move between Nodes on the Body tab) and its size, its density: how much it can hold, 120 at most. It grows by use: what its techniques spend comes back at the stair from the essence you bank into it, and stretches it a little. Every 10 of size is a level: 3 wakes it (a minor ability), 5 a gift, 6 a technique cast with that Node's mark button ({cast}), 12 its capstone. Your Nodes' sizes also give your attributes, and their total sets your stage, from Stir to Unbound. The Makers stand outside the towers, so secret bonds can still be earned. It's for good: only the Developer's holder can let the beasts mark them again."},
	"unbound_offer": {"group": "unbound", "name": "The refusal",
		"tip": "You may refuse this mark. Refuse, and there is no road back.",
		"more": "Only at the Regard on your first climb, and only if you broke no barrier on it: the guardian offers its mark. Accepting changes nothing. Refusing makes you Unbound: no tower bond ever again, and banked essence fills your body parts raw instead. Refusing takes a second press, since it can't be undone. Once marked, a climber can't become Unbound."},
	"unbound_fists_found": {"group": "unbound", "name": "Something gave",
		"tip": "That barrier shuddered. Break one on your first climb and the beast will refuse to mark you.",
		"more": "A barrier the tower puts up (a vault's seal, a lock-in room's shut doorway) can be struck with bare fists. The very first time, it only shudders. On the first climb, before the Regard, keep striking and it breaks: that breaks the tower's rules, and at the Regard the guardian refuses to mark you. You become Unbound, with no choice. (The stair's own gate or ward is different: anyone may break or slip past it, for a horde.)"},
	"unbound_fists": {"group": "unbound", "name": "Bare fists",
		"tip": "Fists out, hold {attack} against a barrier. Each blow costs essence and skin. It breaks, and gives nothing.",
		"more": "With your fists out on your first climb, hold the strike ({attack}) against a barrier: a vault's seal or a lock-in room's shut doorway. Each blow drains some of your unbanked essence, hurts your hands (more when there's little essence to drain; never the last of your health) and cracks it. A few blows break it: you skip its challenge and forfeit its reward (a broken ward gives no puzzle bonus; a broken vault is empty), and the beast will refuse to mark you at the Regard. Once Unbound, you strike barriers with raw essence from a step away, with any melee weapon (the Proving's sealed reliquary too): it costs unbanked essence and doesn't hurt."},
	"unbound_rules": {"group": "unbound", "name": "Rules broken",
		"tip": "You broke a barrier on your first climb. At the Regard, the beast will refuse to mark you.",
		"more": "Breaking even one barrier on the first climb, before the Regard, breaks the tower's rules. At the Regard the beast refuses to mark you, and you become Unbound: no tower bond, now or later. A fall on the first climb is refused the same way."},
	"unbound_fists_marked": {"group": "unbound", "name": "It holds",
		"tip": "The barrier shudders and holds. Bare fists only break barriers on the first climb.",
		"more": "After the first climb, a marked climber's fists only make a barrier shudder. Only the Unbound can break one later, with raw essence."},
	"unbound_cast": {"group": "unbound", "name": "Your techniques",
		"tip": "A Node at level 6 carries a technique on its mark button. {cast} casts it; cast it before it's full and it costs strain.",
		"more": "Each Node at level 6 or more carries one technique, on that body part's mark button ({cast}). It fills from the Node's work, the way a mark does: strikes fill the hand, rolls through attacks the legs, hits survived the heart, parries the brow, several foes at once the throat, backstabs and finishers the back. Its medallion's ring shows the fill. Full, a cast spends nothing from you, but what it spends counts as use: refilled at the stair, it makes the Node grow. Cast it before it's full and the missing share comes out as strain on its Node: the bar under the medallion. Past the white tick the Node hits harder but may waver; at the end of the bar it erupts. If you carry the technique's essences unbanked, a cast spends them and hits harder. The first time you cast each one, its name and what it does show at the top of the screen."},
	"abilities_unbound": {"group": "unbound", "name": "Seeing and changing them",
		"tip": "To see your techniques and what each does: {abilities}. Change them on the climber screen's Techniques tab, on the train.",
		"more": "The climber screen's Techniques tab holds everything about your techniques: the essences each is made of (its Node's own mix), its form, what it does, how it fills, its strain and boost, the button that casts it, and what each Node's minor ability and gift do. During a climb, {abilities} to look at it (held, it closes again when you let go). On the train it changes a technique's form, its essences' effects and its variation; the Body tab shows your Nodes and moves essence between them. On the train the Techniques tab also offers Try your abilities: a quiet room with training dummies that never strike back."},
	"unbound_strain": {"group": "unbound", "name": "Strain",
		"tip": "Past the white tick, that part hits harder and may waver. At the end of the bar it erupts.",
		"more": "Every technique strains the body part it comes from (the bar under its medallion; more for each essence it combines, and more when you cast before it has filled). Above 70 its techniques hit 25% harder but may waver: half strength, off aim. At 100 the part erupts. Strain fades while you don't cast from that part, and the stair's rest clears it."},
	"unbound_erupt": {"group": "unbound", "name": "Eruption",
		"tip": "It erupted. That part is dark for a while. An eruption can kill you.",
		"more": "At 100 strain the raw essence in a part erupts: you lose almost half your health (it can kill you, and that's a fall like any other), the part goes dark for 8 seconds (nothing from it can be cast) and raw essence shows on it."},
	"unbound_techniques": {"group": "unbound", "name": "Techniques",
		"tip": "Your six techniques, one per Node. Choose a Node above, then its form, effects and variation: each press changes it at once.",
		"more": "The climber screen's Techniques tab holds everything about your techniques. Choose a Node along the top (its mark button's key is on it). Its card draws the technique in a glass globe (the form inside, the Node's essences poured in, the variation on its spout), a dial shows the strain one cast adds, and beside it are its name and what it does in plain words. Under the card: Form (the forms the Node has opened), an Effect for each essence in the Node (press for the next one that has opened), a Variation, its name, Boost, where each kind of banked essence flows, what each Node's minor ability and gift do, and on the train Try your abilities (a practice room). Every press changes the technique at once and it's carried straight away: there's no Set button and nothing to lose. You can look anywhere; techniques change only on the train, between climbs. Words first. A form is the shape a body part gives (the hand a strike or a bolt, the legs a dash or a leap, the back a shell or a push, the throat a shout or a pull, the brow a mark or sight, the heart something on yourself). An effect is what an essence does to what it hits: Fire burns, Water slows, Air reaches farther, Stone staggers and guards, Iron pierces armour and pulls, Blade cuts and bleeds, Making heals you, Unmaking erodes and ignores armour. A technique is a form and the effects of the essence in its part: Strike and Burn make Flame Fist. A variation is a small change on top (Wide, Quick, Chain...). The first essence in a Node leads its technique at full strength and must stay at least half of what the Node holds; up to two more add their touch, stronger the bigger their share. The essences are the Node's own mix: to change them, move essence from one Node to another on the Body tab, which costs a quarter of it: before a path it condenses into crystals, on the Making path it turns into core essence, on the Unmaking path it is unmade."},
	"unbound_condense": {"group": "unbound", "name": "Condensing",
		"tip": "No mark for you at the top. Choose a Node, and the tower's essence condenses into it.",
		"more": "At a summit the Unbound take no mark. Instead some of the tower's essence condenses straight into the Node you choose: a sleeping Node soaks it in and comes closer to waking; an awake one grows a little, as if it had been used, and tops up what it holds. The bigger the Node, the less it grows, as with all growth."},
	"node_awake": {"group": "unbound", "name": "A Node awakens",
		"tip": "That Node woke. Now and then its own work carries a touch of its essence.",
		"more": "When enough essence has soaked into a sleeping Node, it wakes at level 3, with its minor ability: now and then, what the Node does (your weapon strikes for the hand, rolls for the legs, parries for the brow, blows you survive for the heart, a swing that catches several foes for the throat, backstabs and finishing blows for the back) also carries a touch of the essence that leads it to the nearest foe. A Fire hand's strikes sometimes burn; a Water brow's parries slow. Nothing to press: it's always on. Awake, the Node shows its size and what it holds on the Body tab, and from now on it grows as you use it."},
	"unbound_half": {"group": "unbound", "name": "Level 6",
		"tip": "That Node reached level 6. It carries a technique now, on its mark button.",
		"more": "At level 6 a Node carries a technique: a form of that body part, made of the essence the Node holds. It learns its first form by itself so you can use it at once ({cast}); on the climber screen's Techniques tab, on the train, you can choose its other form instead, and later forms as the Node grows. Its name comes from the two, like Flame Fist for Fire and a strike. Casting it is also how the Node grows best: what it spends comes back at the stair and stretches it."},
	"unbound_learned": {"group": "unbound", "name": "A first technique",
		"tip": "Your Node learned a technique by itself. Change its form on the Techniques tab whenever you're on the train.",
		"more": "A Node that reaches level 6 learns its first form at once, so you have something to cast straight away. On the train, the climber screen's Techniques tab lets you choose the Node's other starting form (the hand's Strike or Bolt, the legs' Dash or Leap, and so on) and, as the Node grows, the forms its tree opens."},
	"unbound_full": {"group": "unbound", "name": "Level 12",
		"tip": "That Node is as big as it grows. Its capstone wakes.",
		"more": "At size 120, level 12, a Node is as big as it can grow: its capstone wakes, and its techniques hit their hardest. It takes no more banked essence than it can hold (the rest condenses into crystals). If one essence alone fills it, it also brings that essence's signature."},
	"unbound_pure": {"group": "unbound", "name": "A pure Node",
		"tip": "One essence alone fills that Node. Pure, it brings a signature.",
		"more": "A Node at full size, filled to the top with one essence alone, is pure, and brings a signature technique of its own: pure Air in the Legs Node brings Blink, a short vanishing step to where you aim. It shows as another form of that Node on the Techniques tab. Other signatures are coming soon. Add a second essence and the signature is gone until the Node is pure again."},
	"unbound_core_led": {"group": "unbound", "name": "Core-led",
		"tip": "Your core essence leads that Node now. Its technique is a core technique.",
		"more": "When the core essence is at least half of what a Node holds, it leads the Node: its technique becomes a core technique, stronger from level 6 and stronger again at level 12, in your core's own colours. The other essence left in the Node adds only a small touch, and at each stair the core slowly absorbs it, until the Node is all core."},
	"unbound_body": {"group": "unbound", "name": "Your body",
		"tip": "Your six Nodes. A sleeping one shows nothing yet; an awake one shows its size and what it holds. Press one to choose it.",
		"more": "On the climber screen the Unbound see a Body tab instead of Marks: a card for each of their six Nodes. A sleeping Node says only that it sleeps. An awake Node shows its level, its size (its density: how much it can hold, 120 at most), the essences it holds and its core essence. Press a card to choose that Node: under the cards, what each of its levels brings; then your attributes (from your Nodes' sizes); then Move essence. From is the awake Node to move out of, Essence which of its essences, and To where it goes: another awake Node with room for it, or a sleeping one to feed (what arrives soaks in and brings it closer to waking). Move takes up to 6 at a press, and the button shows how much and the price. Moving never changes a Node's size: only use does. Drain into crystals empties some of the essence into crystals of its kind instead. It works anywhere the climber screen opens, but never while a monster is after you."},
	"unbound_move": {"group": "unbound", "name": "Moving essence",
		"tip": "Moved. A quarter of it is the price. A Node's size doesn't change: only use makes it grow.",
		"more": "On the climber screen's Body tab you can move essence of one kind from one awake Node to another, feed it to a sleeping Node (it soaks in), or drain it into crystals with its own button. It works on the train, at a camp, at a stair or in a climb, but not while a monster is after you. A quarter of what you move is the price. Essence is never lost: before you choose a path that quarter condenses into crystals; on the Making path it turns into Making, your core essence; on the Unmaking path it is unmade. A Node's first essence must stay at least half of what it holds, and a Node takes three kinds at most: a Node that can't take it is skipped. Moving changes what a Node holds, never its size."},
	"node_seal": {"group": "unbound", "name": "Sealing a Node",
		"tip": "On the train you can seal a Node: give it up, and your open Nodes grow deeper.",
		"more": "On the train, the Body tab lets the Unbound seal a Node; the marked can't. A sealed Node takes no essence: what would pool there mostly condenses into crystals, and only a little flows on to your open Nodes. Sealing gives the Node up: what it holds condenses into crystals, and its size, technique, gift, minor ability and attributes are gone. In return every sealed Node makes your open Nodes grow faster from use and hit harder. One Node always stays open. You can unseal a Node later, on the train, but it starts again asleep, at size 0. Focus trades breadth for depth, not speed: a focused body grows its one Node a little sooner, never all at once."},
	"node_sealed": {"group": "unbound", "name": "A sealed Node",
		"tip": "Sealed. That Node is quiet now; your open Nodes grow deeper for it.",
		"more": "A sealed Node takes no essence and gives nothing: no technique, gift, minor ability or attributes. What it held has condensed into crystals. Each sealed Node makes your open Nodes grow faster from use and hit harder. Essence that would have pooled there mostly condenses into crystals on the way; route your kinds to your open Nodes on the Techniques tab to keep them. Unseal it on the train if you change your mind: it starts again asleep, at size 0."},
	"node_unsealed": {"group": "unbound", "name": "An unsealed Node",
		"tip": "Unsealed. It starts again asleep, at size 0: bank essence routed to it to wake it.",
		"more": "An unsealed Node is open again, but it starts from nothing: asleep, at size 0, holding nothing, like a new Unbound's. Essence routed to it soaks in until it wakes. Your open Nodes lose its share of the sealing bonus."},
	"node_asleep": {"group": "unbound", "name": "A sleeping Node",
		"tip": "That Node is asleep. It sleeps until enough essence has soaked into it. Bank essence routed to it.",
		"more": "Every Node starts asleep. While it sleeps it holds nothing and shows no numbers: only that it sleeps. The essence you bank that flows to it (its natural kind, or a kind you route to it on the Techniques tab, on the train) soaks in, and when enough has soaked in, it wakes. Feeding it essence from an awake Node on the Body tab helps too, and so does condensing a summit's essence into it. Your first Node wakes after about one climb; the others take a few climbs each, sooner if you route essence to them."},
	"node_grows": {"group": "unbound", "name": "A Node grows",
		"tip": "Your Node grew with use. What its techniques spend comes back at the stair and stretches it a little.",
		"more": "An awake Node grows by use, the body getting stronger with training. Everything its technique spends on a cast (and the essence a boost pays), or before it has a technique what its own work does, is asked back at the next stair: the essence you bank into that Node refills it, and that refilling stretches the Node's size a little. Use that isn't refilled at the stair is gone, so casting far more than you bank adds nothing: what you bank, and the strain of pushing your techniques, set the pace. The bigger it is, the slower it grows. Moving essence never changes a size."},
	"unbound_essence": {"group": "unbound", "name": "Your essence",
		"tip": "Your aura, your core essence and your crystals. Your Nodes' sizes are on the Body tab.",
		"more": "The Unbound's Essence tab shows your aura (once you have a path), the core essence settled in your body, the crystals you hold by kind (eat them, or drink tinctures, from Crystals and tinctures) and what you carry unbanked this climb. Your attributes and what each Node holds are on the Body tab: they come from your Nodes' sizes."},
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
		"more": "Now and then, from floor 4, a Hall of Glass lies off the way to the stair, behind a door bearing a figure in a mirror. Walk in and a mirror image of you steps out of the glass, and the doors shut until it falls. It carries the weapon in your hand (its reach, its chain, its finisher; or your bow), wears your armor (your blows land a little softer) and casts a simpler form of up to two of your marks' spells: a volley of bolts, a circle where you stand, a cone or a ring. Every attack is telegraphed and glints like any monster's. It sometimes rolls clear of a blow, and after attacking it may raise its guard (a silver arc): light blows from the front are turned aside and it answers at once, but a finisher or a blow from behind breaks through. It is a great foe: it leaves mostly Unmaking and some Making, an essence crystal of the tower's kind, and sometimes a piece of gear."},
	"rivals": {"group": "tower", "name": "Other climbers",
		"tip": "Another climber. Each wants something: a trade, a duel for the floor, company to the stair. Some need help. Walk on if you like.",
		"more": "From floor 2, other climbers wait in rooms of their own: nearly half the floors roll for one, up to two a climb, and if you've never met one you will by floor 3. A second in the same climb is someone else, after something else. Each carries their own marks (the dots on their body; their names show when you talk) and wants one thing. A trade: two or three swaps of their gear, items or crystals for something you carry of about the same worth. A duel for the floor: the doors shut, and the first to yield gives up the floor; win and you get crystals, renown and the stair's ward lifts, lose and you are knocked down, never killed, and they take a toll. Teaming up: they fight beside you until the stair, and you keep half the essence and finds while they do; their marks react with yours. A wounded climber beside a hoard: help them, or take it. Walk on leaves; you can come back. Climbers you meet are kept on the Renown Board, and some come back, stronger."},
	"rival_trade": {"group": "tower", "name": "Trading with a climber",
		"tip": "Each card is a swap: theirs for something of yours worth about the same. You give it up as you take theirs.",
		"more": "A climber who wants to trade offers two or three swaps. Each card names what they give and, under it, what they want from you: an item from your belt, a piece from your pack, crystals, or unbanked essence when you have nothing else of that worth. Worth is the outfitter's own prices. A card you can't pay says so. Take one, then step away and come back to take another."},
	"rival_duel": {"group": "tower", "name": "A duel for the floor",
		"tip": "A duel can't kill you. Lose and you're knocked down and pay a toll. Win and the floor is yours.",
		"more": "Accept a duel and the room's doors shut behind you. They fight as a climber does: their weapon's swings with a glint before each, rolls, a guard, and a spell for each of up to two marks, telegraphed in red. Their spells leave their mark's state on you. They yield when badly hurt: you win crystals, renown, sometimes a piece of their gear, and the stair's ward lifts (or a bigger prize if it already has). If a blow would fell you, you're knocked down instead, left with a little health, and they take a share of your unbanked essence or a piece from your pack."},
	"rival_team": {"group": "tower", "name": "Teaming up",
		"tip": "They fight beside you to the stair. You keep half of what you gather while they do. Mix your marks with theirs.",
		"more": "A climber you team up with follows you and fights the floor's monsters until you take the stair: they swing, and cast their marks' spells, each leaving its state on the foes it hits. While they're with you, you keep half the essence you gather and finds drop half as often. Their states meet yours: a reaction one of you set off with the other shows their name under its word. A synergy with their marks holds while they're beside you: their marks lend yours their traits, and a named synergy one of whose marks is theirs holds. Monsters strike them too, and badly hurt they fall back. Reaching the stair together earns renown."},
	"rival_rescue": {"group": "tower", "name": "A wounded climber",
		"tip": "Hurt, beside a hoard. Help them and they'll remember. Take it and they'll remember that too.",
		"more": "From floor 3 you may find a wounded climber slumped beside a hoard. Help them up with a Healing Vial (or some of your own health if you carry none): you earn renown and they owe you, so if you meet them again they bring a gift. Or take the hoard: essence and a finer piece of gear, but you lose a little renown (never a rank), the Makers take note, and if you meet them again they want a duel. Walk on and nothing happens."},
	"rival_gift": {"group": "tower", "name": "A climber's thanks",
		"tip": "Someone you helped. They don't forget.",
		"more": "A climber you helped up once may meet you again on a later climb. They bring crystals of the tower's essence and an item, and offer to climb with you to the stair."},
	"rival_reaction": {"group": "tower", "name": "Marks together",
		"tip": "Their mark and yours, together. One state was theirs, one yours: a reaction neither of you set off alone.",
		"more": "A climber fighting beside you leaves their marks' states on the foes they hit: charged, soaked, burning, poisoned and the rest. When one of your states meets one of theirs, the reaction fires as if you carried both marks, and its word rises with their name under it (\"with\" and the name). It's the way to see what your mark does with marks you don't carry yet."},
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
		"tip": "The floor gives way here. Jump it with {jump}. Walk to the edge and you'll wobble: step back quickly. A roll carries you straight in.",
		"more": "In the Firebird's tower the floor has chasms. Jumping ({jump}) carries you across. Walk onto the edge and you teeter there, arms going round: step back quickly and you're safe, wait and you tip in. A roll, a dash, a blow or the wind takes you straight in. Walking monsters can't follow you over a chasm, but fliers cross them. You can tell a chasm from a doorway: a chasm is a dark pit cut into the floor, with a lit rim and walls falling away into the dark, the floor you'd land on only faint at the bottom; a doorway is a gap in a wall, level with the floor."},
	"chasm_fall": {"group": "tower", "name": "Falling through",
		"tip": "Down a floor. No harm done, except to your pride. Your essence came with you.",
		"more": "Falling into a chasm, or down any tower's way down, doesn't hurt: you land on the floor below (never below floor 1) and climb again from there. Your unbanked essence stays with you. Next time you wobble at an edge, step back quickly."},
	"teeter": {"group": "tower", "name": "Teetering",
		"tip": "Careful. You're on the edge. Step back quickly, or over you go.",
		"more": "Walk onto the edge of any hole (a chasm, a drop, a tower's way down) and you teeter there, arms going round, for a moment. Move back away from it in that moment, or roll away, and you're safe. Stand still or keep going and you tip in and fall to the floor below. A roll, a dash, a blow, the wind or a whirlpool's pull takes you straight in, with no teetering."},
	"whirlpool": {"group": "tower", "name": "Whirlpools",
		"tip": "A drain in the floor. When the water runs out, it spins and pulls. Walk away from the pull, or it takes you down a floor.",
		"more": "In the Kraken's tower some rooms have a round drain in the floor. While the room's water drains away, a whirlpool spins up over it: foam spirals in and its dark eye opens onto the floor below. Come close and it drags you toward the eye; walk away and you get out. Reach the eye and you fall to the floor below, unhurt. When the water is gone it closes again."},
	"sinkhole": {"group": "tower", "name": "Sinkholes",
		"tip": "Pale sand, a dimple, cracks round it. Stand on it and it sags. When the red ring shows, step off, quickly.",
		"more": "In the Manticore's tower some patches of sand lie over nothing. Step on one and it sags: a red ring, sand pouring in, a rumble. A moment later it opens for good into a dark pit, a way down to the floor below. Step off while it sags and you're safe. A walking monster on it when it opens goes down with it."},
	"slag_chute": {"group": "tower", "name": "Slag chutes",
		"tip": "An iron chute in the floor, slag running down it into the dark. Step on the slope and you slide. Keep off it.",
		"more": "In the Wyvern's forge some floors have a slag chute: an iron slope with rails, glowing slag trickling down it into a pit at its foot. Step onto the slope and you slide toward the pit; walk back up hard and you might make it. Reach the pit and you fall to the floor below, unhurt. Walk onto the pit's edge from the side and you teeter: step back quickly."},
	"root_hollow": {"group": "tower", "name": "Root hollows",
		"tip": "A gap among the roots, dark all the way down. Walk round it. Wobble at its edge and step back quickly.",
		"more": "In the Chimera's tower roots have pushed the floor apart here and there, leaving a ragged hollow with rootlets hanging into the dark and the floor below faint at the bottom. Walk onto its edge and you teeter: step back quickly. Fall in and you land on the floor below, unhurt."},
	"mimic": {"group": "tower", "name": "Mimics",
		"tip": "That chest had teeth. Watch its glint: parry the bite, punish the opening. What it swallowed is yours.",
		"more": "Now and then a chest isn't a chest. Walk up to a mimic and it springs open, all teeth and tongue, and hops after you. Its bites glint before they land, like any monster's: parry, or roll through, then strike while it recovers. Slain, it spills what it had swallowed: more essence than a chest, often an item, often gear. Sharp eyes may catch it first: a lid that breathes, a tooth at the seam."},
	# Portals, pocket dimensions and the floor map (portals.gd, vaults.gd, floor_map.gd).
	"portal": {"group": "tower", "name": "Portals",
		"tip": "A portal, asleep. Finish a challenge on this floor, or slay everything on it, and every portal here wakes.",
		"more": "Every floor of rooms has a few portals: one in the entrance, one in the stair hall, and more spread out (three a floor, six from floor 10). They always look the same: a ring of dark stone round a swirl. They join places on the same floor, never one floor to another. They sleep (grey stone, a dim swirl) until you complete a challenge on the floor (its task, a sealed wing where the Regard watches you, the gallery's puzzle) or slay every creature on it; then every portal on the floor wakes at once. The floor map (O, the pause menu's Floor map, or Map on a phone) shows the portals you've seen."},
	"portal_awake": {"group": "tower", "name": "Woken portals",
		"tip": "The portals woke. Step onto one and the floor map opens: choose another portal and you step out of it.",
		"more": "Once a floor's portals wake, step onto any of them and the floor map opens. Choose another woken portal (click or tap it, or the arrows or D-pad and Enter or A) and you step out of it; Esc, B or Close and you stay. A woken portal shows on the map even in a room you haven't seen. They won't answer while a room's doors are shut on you or while the Regard tests you in a sealed wing, and never to another floor."},
	"pocket": {"group": "tower", "name": "Pocket dimensions",
		"tip": "A pocket dimension: a room outside the floor. The floor waits as it was. The portal behind you leads back.",
		"more": "Some walls hide a way out of the floor. Dust drifts from one, it knocks hollow, and Hunter's Keen Eyes outline it. Lean into it, or break it with a finishing blow or a burst, and a portal opens in it. Through it is a pocket dimension: a room no corridor reaches. While you're inside, the floor waits as it was (its monsters stand still), and the portal you arrived by takes you back to where you came in. Pockets aren't on the floor map."},
	"pocket_vault": {"group": "tower", "name": "Pocket vaults",
		"tip": "Three chests. One holds gear better than this floor gives. Mind the third: some chests bite.",
		"more": "A pocket dimension holds a small vault of three chests. One always holds a piece of gear a rarity above what the floor usually gives (Fine at the least), its traits rolled. One holds a choice of essence crystals, now and then a tincture in place of one. The third holds a smaller crystal of the tower's essence, or, from floor 3, may be a mimic. Rarely, a vault holds a lead to the tower's Summit Blade. Walk up to a chest to open it."},
	"vault_guard": {"group": "tower", "name": "Guarded vaults",
		"tip": "Chained shut. Something here wants to be answered first.",
		"more": "Some pocket vaults are guarded, and their chests stay chained until the guard is dealt with. A Tithe Stone (a pale slab with an open hand) asks for unbanked essence: lean on it from below to pay. Three runes on the floor light in an order as you arrive: step on them in that order (a wrong one shows the order again). Or a Keeper, a crowned champion of the tower's monsters, rises: beat it. Leave through the portal whenever you like; the guard waits."},
	"floor_map": {"group": "screens", "name": "The floor map",
		"tip": "Your map of this floor: what you've seen, where you stand, the portals. Hover or hold a marker and I'll say what it is.",
		"more": "The floor map shows the rooms and corridors you've seen on this floor, where you are, the stair once you've seen it, and the floor's portals (asleep or woken). Open it with O, the pause menu's Floor map button, or Map on a phone; Esc, B, O or Close shuts it. The game waits while it's open. Stepping onto a woken portal opens it for travel: choose another portal and you step out of it. Hover a marker or button (or hold a finger on it, or move onto it with the keys or a controller) and I explain it."},
	"husk": {"group": "tower", "name": "Husks",
		"tip": "Empty gear, still fighting. It reads your rhythm: three blows on one beat and it parries the next. Wait a beat, or strike from behind.",
		"more": "A husk is what's left of a climber who fell here: the gear, moving on its own, fighting as a climber would. It slashes and lunges (both glint: parry them) and rolls away when it sees a wind-up coming: a bow drawn, a spell gathering, the finisher of your chain. Strike it three times in one rhythm and its blade comes up crosswise (a pale arc): the next blow on that beat, from the front, is parried, and it cuts back. Change your timing and the guard breaks: Off the beat!"},
	"bellringer": {"group": "tower", "name": "Bellringers",
		"tip": "A bell. Each ring quickens every monster it reaches. It runs from you. Catch it first, or hit it while the bell is up.",
		"more": "A bellringer has no blow of its own. Every few seconds it lifts its bell, and a gold ring on the floor shows how far the sound will carry; then it rings, and every monster inside is quickened for a while: they get over their attacks sooner and move faster (gold ticks turn at their feet). Their glints keep their timing. Strike the bellringer while its bell is up and the ring is lost."},
	"squall": {"group": "tower", "name": "Squalls",
		"tip": "Wind with eyes. Its gust can't be parried: step out of the lane. It's open while it spins up again.",
		"more": "A squall turns most of every blow while it whirls. To attack it stops and spins up, and streaks run down a lane in front of it: the gust follows down that lane. It can't be parried; step sideways, or roll through. Caught, you're shoved down the lane, bent toward a drop if one is near you. After a gust it slows to wind up its next spin, and then your blows land in full."},
	"rookery": {"group": "tower", "name": "Rookeries",
		"tip": "A nest on a ledge. It hatches bats now and then, never more than two at once. Break it and no more come.",
		"more": "A rookery is a nest of twigs on a stone ledge against a wall. It never moves and never strikes. Once it has seen you an egg rocks and cracks (a ring marks where the bat comes out) and a bat flies out, now and then: never more than two of its bats on the wing at once, and three eggs in all. Break the nest and that's the end of them."},
	"stormstone": {"group": "tower", "name": "Stormstones",
		"tip": "A stone that charges, then strikes whoever stands nearest: you or them. Let a monster stand nearer than you.",
		"more": "A stormstone builds charge as its runes light one by one. Full, a red line picks whoever stands nearest within its reach, you or a monster, following whoever is nearest until it glints. Then lightning arcs to them. It can't be parried: roll, or step back so that something else is nearer. A monster it strikes takes double, is stunned and left charged. Nobody in reach, and the charge goes into the ground."},
	"inkling": {"group": "tower", "name": "Inklings",
		"tip": "Ink. It doesn't hurt, but you can't see much in it. The inkling nips from inside: watch for its glint, or walk out.",
		"more": "An inkling puffs up (a dark ring marks the spot, on you) and sprays a cloud of ink where you stand, darkening the floor round you for a few seconds. Then it slips into the cloud to nip you from inside it. Its warning wedge, its eyes and its glint show over the ink, so you can still parry; or just walk out of the cloud."},
	"drowned": {"group": "tower", "name": "The drowned",
		"tip": "It rose from the puddle. Slow, but it bursts when it falls: step out of the ring or you'll be soaked, and lightning loves the wet.",
		"more": "A drowned one lies face down in a puddle, out of reach, until you come near; then it rises and shambles after you. Up close it brings both arms down (it glints: parry it); a blow that lands soaks you. When it falls it swells, a ring showing how far, and bursts, soaking everyone inside. Soaked, lightning on you jumps (Conduct): mind sparks and stones while you're wet."},
	"driftbell": {"group": "tower", "name": "Driftbells",
		"tip": "Its trail crackles where it lies on water: don't step in it. Up close it sparks all round. Back off when it lights up.",
		"more": "A driftbell floats slowly after you and leaves a trail of beads. On water they crackle: touch one and it stings and leaves you charged; on dry stone they fade at once. Come close and its tendrils light up, it glints, and it sparks all round it: that can't be parried, so step back or roll. It's light on health: strike between sparks, or shoot it."},
	"stoker": {"group": "tower", "name": "Stokers",
		"tip": "It feeds the fires. Coal lands in the red circles: step out. Slay it and its fires die down.",
		"more": "A stoker loads glowing coal on its shovel; red circles mark where it will land, one on you and one beside a fire already burning. Then it flings it and the floor there burns; coal on a fire already alight makes it bigger and longer. The coal can't be parried: step out of the circles, or jump. Up close it swings the shovel (parry it). Slay it and every fire it lit dies down."},
	"slagworm": {"group": "tower", "name": "Slagworms",
		"tip": "Its slag hardens into low walls that burn. Jump them or roll through. They cool and crumble soon, and never block your way.",
		"more": "A slagworm crawls after you, slowly, and the slag it leaves hardens into a low glowing wall. Standing on hot slag burns like burning floor; a jump carries you over and a roll through is free. The slag cools dark and crumbles after a few seconds. It never lies near the stair or in a narrow way, and nothing can be trapped by it. Up close it bites (parry it)."},
	"riveter": {"group": "tower", "name": "Riveters",
		"tip": "Three rivets a burst. The first two only glance off a parry. The third glows hot: parry that one and it goes back.",
		"more": "A riveter hovers at range. A red line shows its aim, it glints, and it fires three rivets down the line. The first two glance off a parry. The third glows hot and glints as it flies: parry it and it flies straight back, knocking the riveter out of the air, where it lies sparking a while, open to blows. Or roll through the whole burst."},
	"inscription": {"group": "tower", "name": "Inscription stones",
		"tip": "Old words on a stone. Stand beside it to read them. I keep what you read in my log.",
		"more": "Some floors have a standing stone with an inscription cut into it, its letters glowing faintly. Stand beside it and the words show over it; walk away and they fade. Each tower has its own stones, and what you've read goes into the Entity's log of the climb."},
	# The Manticore's, the Firebird's and the Chimera's newer monsters (scripts/towers/brood.gd):
	# each said the first time one is close by.
	"carrion": {"group": "tower", "name": "The carrion",
		"tip": "A shadow circling over you. It waits for you to weaken. Stay healthy, and when it cries out, watch the ring.",
		"more": "The carrion is a vulture that circles high over the Manticore's courts, out of reach: only its shadow crosses the floor. It dives only when you're badly hurt, or when it's the last foe about, or has waited long enough. It cries out, a red ring follows you on the floor, it glints, and it drops onto the spot: parry it (it comes down staggered), or step out of the ring. Afterwards it stands on the floor a moment, open to blows, before it climbs back up."},
	"basilisk": {"group": "tower", "name": "The basilisk",
		"tip": "When its eyes glow, look away. Meet its glare and your limbs stiffen.",
		"more": "The basilisk keeps its distance and, every few seconds, glares. Its eyes begin to glow and a pale cone fills toward you, then the glint, then the glare itself. Stand in the cone facing it and you're Slowed for as long as you keep looking. Face anything else and the glare does nothing; strike it and the glare breaks off. On a phone, while it glares your aim stops turning you toward it, so walking away turns you away. Up close it bites, and the bite can be parried."},
	"cairn": {"group": "tower", "name": "The cairn",
		"tip": "Those stones stood up. Beat it down and it rebuilds. Hit the rubble hard and it stays down.",
		"more": "A cairn lies as a heap of stones until you pass near, then pulls itself together into a stone figure. It walks slowly and swings heavily: a long wind-up, the glint, a wide arc in front (parry it, and it's open after). Light blows don't rock it. Beaten down it falls apart, and a few seconds later the stones pull together again with part of its health, a couple of times at most. A heavy blow scatters them for good: a finisher, a heavy weapon's blow, a blast, landing as it falls or on its rubble."},
	"kindler": {"group": "tower", "name": "The kindler",
		"tip": "It raises the fallen from their ash. Break its beam with a blow, or stamp the ash out first.",
		"more": "While a kindler lives, the monsters that fall leave heaps of smouldering ash. The kindler keeps its distance, walks to a heap and channels a beam of fire into it from its torch; when the beam ends, the fallen rises again as a weak, ash-grey copy that leaves nothing when it crumbles. Strike the kindler while it channels and it's interrupted. Soak the ash, or stand on it a moment to stamp it out, and nothing rises from it. Or kill the kindler first. Up close it swipes its torch: parry it."},
	"flamemoth": {"group": "tower", "name": "Flamemoths",
		"tip": "Moths, drawn to the light. Fire only feeds them. Water or wind breaks the swarm.",
		"more": "A flamemoth swarm is drawn to light and fire: burning floor (yours too), the torches, a kindler's torch, and you if you're burning. Near a light it circles and forgets you unless you come close, and burning floor feeds it. Fire makes it grow instead of burning it: bigger, tougher and harder-hitting. Water or wind disperses it: soaked, thrown up or shoved hard, the swarm scatters, most of its health gone. It attacks by tightening into a ball, a glint, and darting through where you stood (parry it); its touch burns."},
	"salamander": {"group": "tower", "name": "The salamander",
		"tip": "It swims in the fire, out of reach. Wait for it to surface, or put the fire out.",
		"more": "The salamander swims through burning floor, seen only as a heat shimmer, and nothing can touch it there. Come near the edge and it surfaces, glints and lunges to bite (parry it), then lies on the floor a moment: your chance. With no fire near it kindles a pool of its own: a red ring round it (step out of it: it can't be parried) and the floor bursts alight. It swims in any fire, yours too. Put its fire out with water, or soak it, and it's thrown out, dazed. Fire doesn't burn it."},
	"leafmantis": {"group": "tower", "name": "The leafmantis",
		"tip": "Something in the leaves. Listen for the rustle, watch for the glint. Two slashes: parry the first.",
		"more": "A leafmantis stands still among the leaves and brambles, nearly invisible, where it can't be struck. Come near, or linger, and the leaves rustle, it rears up and glints, then darts in with two fast slashes a beat apart in front of it. Parry the first and the second never comes; a roll takes you through both. Out in the open it stalks you and slashes the same way until it can slip back into hiding. Fire flushes it out, and burning or soaked it can't hide at all."},
	"graftling": {"group": "tower", "name": "The graftling",
		"tip": "It steals parts from the others, and their attacks with them. Keep it away from them, or break its pull.",
		"more": "A graftling alone only claws. Beside another monster it reaches out with stitched tendrils, and if you don't strike it to break them it tears a part away and grafts it on where you can see it: a hound's legs give it a leap, a mongrel's quills a fan of thrown spikes, an iron arm a slam in front of it, a stinging tail a poisoned sting. Each comes with that attack's own telegraph and glint, and each can be parried. The monster it robbed loses some health and reels."},
	"hydra": {"group": "tower", "name": "The hydra whelp",
		"tip": "Cut off a head and two grow back. Unless the wound burns.",
		"more": "A hydra whelp's heads rear back together, glint, then bite one after another in front of it; parry the first and the rest stop. Enough damage cuts off a head, and a few seconds later two grow back from the stump, up to five heads. Burn the wound and it never grows back: a whelp that's burning when a head falls, or is set burning soon after, is left with a seared stump. More heads, more bites."},
	"camp": {"group": "tower", "name": "Camps",
		"tip": "A fire, and nothing hunting you. Rest, choose one of three, go on.",
		"more": "Three camps on every climb, the first one's too: the stairs of floors 3, 6 and 9 lead to a camp first. You rest fully (health, stamina and fatigue, burns and poison), then choose one of three cards: an item, a crystal of the tower's essence, or a piece of gear (Fine or better at the floor 6 camp, Rare at the floor 9 one; your old piece is left by the fire). Then the stair takes you on. A camp isn't a floor, and each comes once a climb."},
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
	"guardians_talk": {"group": "tower", "name": "The guardians talk",
		"tip": "One of them has fallen. The guardians talk when one of them falls.",
		"more": "The six guardians aren't strangers to each other. When one falls, the others hear of it, and of the one who felled it. What they make of that, I can't say for certain. Climbers talk too, on the train and on the stairs. Listen to them."},
	# --- the Makers (makers.gd): not in GROUPS, so the Archive hides them
	# until met; they show on the forbidden shelf. Plain mechanics only: the
	# Entity says nothing of its siblings here.
	"fragment": {"group": "forbidden", "name": "Fragments",
		"tip": "A fragment. Walk up to one to read it. I keep what you find on a shelf in the Archive.",
		"more": "Fragments are rare: at most one on a floor, on about one floor in eight, and only in a secret room or a sealed wing's vault, never on the way to the stair. Walk up to one to read it. Each is kept on its own shelf in the Archive (the climber screen's Archive tab), with how many you have found. Their words are not written yet."},
	"maker_portal": {"group": "forbidden", "name": "A Maker's portal",
		"tip": "It drew you through a portal, and let you go through another. Wherever that was, it wasn't the tower.",
		"more": "When a Maker shows itself, a portal opens where you stand and draws you into a pocket dimension of its own: a void of drifting stone, the Maker vast over it. The meeting happens there. When it's over, you step back out of a portal where you stood, and the floor is as it was."},
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
	"puzzle_lanterns": {"group": "tests", "name": "The Hall of Lanterns",
		"tip": "Lanterns, some dark. A blow changes the one you hit and the ones joined to it. Light them all.",
		"more": "In the Hall of Lanterns, iron lanterns stand in a grid, joined by grooves in the floor. Strike or shoot a lantern and it changes, lit to dark or dark to lit, and so does every lantern joined to it (left, right, ahead and behind). Light every lantern at once to solve it. Nothing here can go wrong for good: striking the same lantern again undoes the blow. Higher floors have more lanterns."},
	"puzzle_bells": {"group": "tests", "name": "The Hall of Bells",
		"tip": "Bells. Listen as they ring, then ring them back in the same order.",
		"more": "In the Hall of Bells, bells hang in a ring round a shell. As you come in they ring a song by themselves, each bell lighting as it sounds; every bell has its own colour, size and note, so you can follow it by eye as well as by ear. Then strike or shoot the bells in the same order: lights by the shell count the notes you've rung. A wrong bell brings hunters, and then the song plays again. Strike the shell to hear it again whenever you like. Higher floors have more bells and longer songs, and the highest may ring one bell twice."},
	"puzzle_crucible": {"group": "tests", "name": "The Crucible",
		"tip": "A crucible on an iron floor. Strike it and it slides until something stops it. Stop it on the mould.",
		"more": "In the Crucible's hall, a crucible of molten metal sits on a smooth iron floor with lumps of slag on it. Strike it and it slides straight away from you until slag or the floor's raised rim stops it; it slides over the mould without stopping, so find stops that leave it resting there. You need room to stand on the side you push from. Arrows only ring off it, and a creature in its way stops it short. Push it somewhere it can never reach the mould and it jams: hunters come, and then it's set back where it began."},
	"puzzle_pods": {"group": "tests", "name": "The Hall of Pods",
		"tip": "The idol's glowing head is the sign it wants. Burst open pods with that sign; leave the rest.",
		"more": "In the Hall of Pods, a three-headed idol (a lion, a goat and a serpent) stands among seed pods. One head glows: that's the sign it wants. Pods open a few at a time, each showing a sign, and close again soon (a ring round each runs down). Strike or shoot an open pod with the wanted sign to burst it; lights at the idol's foot count them. A pod with another sign brings hunters, and the count starts again. Letting a pod close costs nothing, and there's always one with the wanted sign among the open ones. On higher floors the idol turns another head after each burst."},
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
		"tip": "Poisoned. It costs health every half second, and it can kill. Antivenom cures it and keeps it off; so does a Cleansing Tonic.",
		"more": "Poison costs a little health every half second for a few seconds, and unlike your other states it can take your last. Scorplings, the Manticore and bloomcaps poison you when their blows land, and so do gas vents and an overdrawn spell. Antivenom cures it and no poison takes hold for a while after; a Cleansing Tonic cures it too, and the rest at a stair. The line at the top counts it down."},
	"state_burning": {"group": "tests", "name": "Burning",
		"tip": "Burning. A little health every half second, never your last; the line at the top counts it down. Warding Oil or a Cleansing Tonic puts it out.",
		"more": "Cinders, ashwings, the Wyvern and the Firebird set you burning when their blows land, and so does a forge's full heat. It lasts a few seconds and costs a little health every half second, but never your last point. Warding Oil puts it out and keeps it off while it lasts; a Cleansing Tonic takes it off; the rest at a stair cures it."},
	"state_bleeding": {"group": "tests", "name": "Bleeding",
		"tip": "Bleeding. A little health every half second, never your last. Heartroot or Briar Tonic stops it; a Cleansing Tonic too.",
		"more": "Thornhounds, mongrels and briars leave you bleeding when their blows land. It lasts a few seconds and costs a little health every half second, never your last point. Heartroot stops it and heals; Briar Tonic stops it and keeps it off while it lasts (and foes that strike you take thorns); a Cleansing Tonic takes it off too."},
	"state_soaked": {"group": "tests", "name": "Soaked",
		"tip": "Soaked. You walk slower until you dry, and lightning would leap to you. A Cleansing Tonic dries you.",
		"more": "Lurkers and the Kraken soak you when their blows land (a forge's water barrel does too). For a few seconds you walk slower, and if you're charged as well the lightning leaps (Conduct) and hurts. A Cleansing Tonic dries you at once; the rest at a stair too."},
	"state_charged": {"group": "tests", "name": "Charged",
		"tip": "Charged. Your stamina refills at half speed while it crackles. Stoneskin grounds it; a Cleansing Tonic clears it.",
		"more": "Thunderlings and the Gryphon leave you charged when their blows land. For a few seconds your stamina refills at half speed, and if you're soaked too the lightning leaps (Conduct) and hurts. A Stoneskin Draught grounds you: it clears the charge and none holds while it lasts. A Cleansing Tonic clears it too."},
	"climber_states": {"group": "tests", "name": "States on you",
		"tip": "Monsters' blows can leave a state on you: the line at the top names it, counts it down and says what cures it.",
		"more": "Some monsters' blows leave a state on you when they land (never when you parry or roll through them): poison from scorplings, the Manticore and bloomcaps; burning from cinders, ashwings, the Wyvern and the Firebird; bleeding from thornhounds, mongrels and briars; soaked from lurkers and the Kraken; charged from thunderlings and the Gryphon. Each lasts a few seconds; a new blow refreshes it but never makes it longer. None of them stuns you. A line at the top of the screen shows each with its sign, its seconds left and what cures it. A Cleansing Tonic cures them all; Antivenom, Warding Oil, Briar Tonic and Stoneskin each cure one and keep it off for a while. The rest at a stair clears everything. The Bestiary says what each monster leaves."},
	# --- gear and items ---
	"gear": {"group": "gear", "name": "Gear on the floor",
		"tip": "Gear. Stand on it to compare; {take} swaps, and your old piece stays behind.",
		"more": "Gear lasts one climb. You carry fists, a melee weapon and a ranged weapon, and wear a chest piece, a helm, gloves, legs, boots, a cloak, an amulet, two rings, a backpack, a charm and an off-hand piece (a second weapon, a shield or a wand). Slain monsters rarely drop a piece, likelier one that suits them; caches, camps and vaults offer some too. Walk over gear with an empty slot and you take it; otherwise a card names its slot and compares it with what you wear (better numbers in green, worse in red) and {take} swaps, dropping your old piece where you stand so you can change your mind."},
	"gear_slots": {"group": "gear", "name": "Worn pieces",
		"tip": "Not a weapon: something to wear. Helm, gloves, legs, boots, cloak, rings... each slot takes one.",
		"more": "Besides your weapons and chest piece you can wear a helm, gloves, legs, boots, a cloak, an amulet, two rings, a backpack (your bag: how much your pack holds) and a charm. Each piece does one small thing: a little health, harder strikes, a quicker step. Protection from every piece adds up, but never past half a blow. Heavy pieces make rolls cost a little more. Plain (Common) pieces wear down as you use them: badly worn, their bonus halves; worn out, they break. Rings and amulets never wear. The inventory ({inventory}) lays out what you wear like a body."},
	"heirloom": {"group": "gear", "name": "Heirlooms",
		"tip": "You survived. Keep one thing you carried; every climb after begins with it.",
		"more": "Survive a climb (beat its beast, or reach the Regard without falling) and you choose one piece you wore to keep as an heirloom; your rings are kept as a pair. Every later climb starts with your heirlooms in their slots, in full repair. Each slot (melee, ranged, chest, helm, gloves, legs, boots, cloak, amulet, rings, backpack, charm, off-hand) holds one; keeping another piece for the same slot replaces it. The inventory's Heirlooms view shows them."},
	"charm": {"group": "gear", "name": "Charms",
		"tip": "A charm. It's never used up: wear it in your charm slot and its gift stays on. Some hold a charge you feed with essence.",
		"more": "You wear one charm, in the charm slot under your paper doll. A charm is never used up. Its passive is always on while you wear it: more stamina, a quicker roll, a shield that grows back, a ward on the first blow in each room, one more kind of item on your belt, one more pack space, or a safe pocket whose piece a fall can't take. Some charms also hold a charge that fires by itself when its moment comes (a blow that would fell you, a shell that would turn your strike). A spent charge stays spent until you feed the charm essence: in the tower from the inventory, with essence you haven't banked yet; on the train at the workshop bench, with crystals of its kind. The workshop's bench crafts charms (with the Rune Artist's mark yourself, else through the Rune Artist there), the outfitter keeps one or two on his rail, and now and then a vault or a secret room holds one. Like other worn gear they come home when you get out alive, and are lost in a fall."},
	"offhand": {"group": "gear", "name": "The off-hand",
		"tip": "Something in your off hand. A blade adds a strike to your chains; a shield blocks while you hold {parry}; a wand casts with {offhand}.",
		"more": "Your off-hand slot holds a second one-handed weapon, a shield or a wand. A second blade adds its own strike to your strike chains, just before the finisher. A shield blocks: hold {parry} past the parry's moment and blows from in front hurt much less, each costing stamina; with too little stamina the guard breaks and you stagger, and you walk slower while guarding. A clean parry is still better: it costs nothing and gives stamina back. A wand casts a small power with {offhand}. Enchanted off-hand pieces (the Ember Dirk, the Tide Ward and every wand) have their own essence pool for their power: a few uses, spent as it fires, refilled like a charm's charge (the inventory in the tower, with unbanked essence; the workshop bench on the train, with crystals). Two-handed weapons and bows need both hands: while one is out, the off-hand is put away."},
	"summit_blade": {"group": "gear", "name": "Summit Blades",
		"tip": "A Summit Blade, hidden here for whoever looked. Carry it to the summit and it's yours for good. Fall, and it goes back.",
		"more": "One Summit Blade lies hidden in each tower, on one floor, in a quiet corner. You only see it up close, or by its faint glint now and then; a lead (found in a vault) shows its glint from afar and says which floor. Walk over it to take it up: it rides on your back. Reach the summit with it and it's bonded to you for good; fall, or leave another way, and it slips back to its hiding place. It isn't gear: it can't be sold or lost once bonded. You carry one bonded blade at your hip, and its power fires by itself: on a landed finisher, or a perfect parry. Between climbs, on the train, the book's Deeds ribbon (Summit Blades) awakens it a step with crystals of its tower's essence, one step between climbs, six steps in all."},
	"summit_bond": {"group": "gear", "name": "A bonded blade",
		"tip": "The blade is yours now, for good. It rides at your hip, and wakes a little more each time you feed it crystals.",
		"more": "A bonded Summit Blade stays with the climber, whatever happens. Carry one at a time (the book's Deeds ribbon, Summit Blades: Carry this blade). Its power fires by itself in a fight, with a short rest between. On the train you can awaken it a step for crystals of its tower's essence, once between climbs: each step makes its power stronger and its rest shorter. A beast's Regarded piece is a different thing: gear you wield, and lose if you fall."},
	"summit_awaken": {"group": "gear", "name": "Awakening a blade",
		"tip": "It stirs. Climb, and it can wake a little more.",
		"more": "Each Summit Blade awakens in six steps, for crystals of its tower's essence, more for each step. Only one step between climbs: it's slow on purpose."},
	"deeds": {"group": "station", "name": "Deeds",
		"tip": "A deed done. The book keeps them all, with the renown each pays.",
		"more": "There are thirty-six deeds, six of each kind: battle, climbing, marks and essence, stations and tournaments, collecting, and daring. Each pays a little renown when it's done, from 1 to 6, about 120 for all of them. Your book's Deeds ribbon lists every deed, what it asks, how far along you are and what it pays. Nothing to press: they're noticed as you do them."},
	"bag_heavy": {"group": "gear", "name": "Bags and a heavy pack",
		"tip": "Your pack is nearly full, and this bag is big: you walk and roll a little slower until you lighten it.",
		"more": "Your bag (the backpack slot) sets how many spare pieces your pack holds: with no bag, 2; a Satchel 4; a Pack 6; a Great Pack 8 (pouches and bandoliers hold 3, with their own use). A small bag never slows you. A big one does, but only once it's nearly full: at three quarters of its spaces or more, a Pack trims your walk and your rolls a little, a Great Pack more. The pack's heading says so (\"Pack · 5 of 6 · heavy\"). Drop or wear a piece and you're quick again. A charm can add a pack space."},
	"items": {"group": "gear", "name": "Items",
		"tip": "An item. {item} uses the one you've chosen; {item_next} chooses another.",
		"more": "Items last one climb; you can carry up to 3 of each kind (4 with a Climber's Pack). The current item, shown beside your weapon, is the one {item} uses; {item_next} picks the next, and holding {item} opens the belt wheel to choose (choosing never uses). An item that would do nothing (a draught at full health) isn't used up. Three are staples, cheap and common: the Healing Vial, the Stamina Vial and the Essence Vial (it fills your marks). Every climb starts with a Healing and a Stamina Vial, and monsters often leave more staples. Everything else (oils, nets, smoke, flasks, tonics, scrolls...) is rare: a few in a whole climb, from a monster now and then, a cache, a fallen climber, a camp or a vault, so each one is worth keeping for its moment. Most of what you find is essence instead. The outfitter's shelf is where you choose them on purpose. Each tower asks for one or two things in particular: its banner says what's handy there. Every item comes in one size."},
	"tower_handy": {"group": "tower", "name": "What a tower asks for",
		"tip": "Each tower asks for something on your belt. The banner said what's handy here; ask me why.",
		"more": "Every tower's monsters and floors make one or two items clearly useful there: nets for the fliers of the Gryphon's and Firebird's towers, Lantern Oil and Edge Oil in the Kraken's, Warding Oil and Edge Oil in the Wyvern's, Antivenom and Cleansing Tonics in the Manticore's, Briar Tonic and Heartroot in the Chimera's. The tower's banner names them as you arrive, they turn up more often there (still rare: a find to be glad of), the outfitter's shelf says where each is handy, and I can tell you why (\"What's handy in this tower?\")."},
	"dark_floor": {"group": "tower", "name": "Dark floors",
		"tip": "Dark down here. Your light reaches less far. Lantern Oil carries it; Flare Powder lights a room.",
		"more": "From the fourth floor of the Kraken's tower the flooded halls are dark: the light you carry reaches only part as far, and what's beyond it stays black. Lantern Oil makes your light reach much farther for two minutes, enough to see the deep floors as well as the shallow ones; Flare Powder lights the room around you for a while; a Lantern piece of gear helps a little."},
	"rarity": {"group": "gear", "name": "Rarities and traits",
		"tip": "That one is finer than most: see its colour. Finer pieces carry traits, and never wear.",
		"more": "Gear comes Common (pale), Fine (green), Rare (blue), Masterwork (violet) or Storied (amber), and a beast leaves its own Regarded piece (gold). Fine pieces carry one trait, Rare ones two and Masterwork three; a finer weapon also hits a little harder. Masterwork is a maker's finest plain work: only found from the tenth floor up, and seldom. Each trait belongs to an essence (of Vigor is Stone, of Edges is Blade, of the Wind is Air...) and only appears on the slots it suits. Finer pieces turn up higher in the tower, and caches, camps and vaults hold finer things than monsters do. Storied pieces and each tower's own pieces keep their own names and rules. What gear adds stops at a cap (the inventory says \"capped\"), and only Common pieces wear."},
	"masterwork": {"group": "gear", "name": "Masterwork",
		"tip": "Masterwork: a maker's finest plain work. Three traits, and no name of its own. You won't see many.",
		"more": "Masterwork pieces sit between Rare and Storied: plain pieces (no name, no rule of their own) made as well as a piece can be made, with three traits where a Rare piece has two, and a weapon a little harder than a Rare one. They turn up only from the tenth floor up, and seldom even there (vaults, caches and camps roll a little finer). They never wear. The outfitter doesn't hang them on his rail; a title that brings today's piece a rarity higher can turn a Rare one Masterwork."},
	"rapier": {"group": "gear", "name": "The rapier",
		"tip": "A rapier: long, quick thrusts. It rewards a parry: ripostes and backstabs bite deeper while it's in hand.",
		"more": "The rapier is a light, one-handed thrusting blade: its thrusts reach farther than a dagger's or a sword's and cost little stamina, though each hits lighter than a sword. While it's in your hand, ripostes (a strike on a foe staggered by your parry) and backstabs hit 40% harder, on top of anything your gear adds. One hand, so it works with an off-hand piece."},
	"flail": {"group": "gear", "name": "The flail",
		"tip": "A flail. Its chain wraps round a guard and over a shell: blows go straight through.",
		"more": "The flail is a spiked ball on a chain: a middling weapon with a wide swing, a little slower than a mace. Its blows go through guards and shells (a knight's guard, a shellback's shell) as if they weren't there, the way a Wardbreaker Charm's charge lets you strike for a while. One hand, so it works with an off-hand piece."},
	"sling": {"group": "gear", "name": "The sling",
		"tip": "A sling. Hold {attack} to whirl it, let go to throw. A full whirl rocks what it hits; a stone never pierces.",
		"more": "The sling is drawn like a bow: hold {attack} to whirl it and let go to throw a stone (a quick tap still throws a weak one). It's light on stamina, and you can walk faster while it whirls than you could while drawing a bow. A stone never flies through a foe the way a fully drawn arrow does, but a full whirl rocks what it hits, breaking its poise like a heavy blow. It needs both hands, like every bow."},
	"enchanted_weapon": {"group": "gear", "name": "Enchanted weapons",
		"tip": "Enchanted: it shows its essence, and lights a little of the dark.",
		"more": "A Fine or Rare weapon, and a relic of one essence, is enchanted: it glows in that essence's colour, carries a small light that helps a little in dark floors, and gives off specks that suit it: embers for fire, drips for water, wisps for air, sparks on a blow for iron, grit for stone, a shimmer on a swing for blade. Its arrows, bolts and essence shots leave a coloured trail. A Common weapon is ordinary and stays plain. Settings has Effects (Low, Medium, High): Low keeps the lights and drops most of the specks, which is kinder to a phone."},
	"belt": {"group": "gear", "name": "The belt",
		"tip": "Your belt holds four kinds of item. A fifth means letting one go.",
		"more": "The belt holds four kinds of item, up to three of each (a recall scroll is one). Every item is one size, so a stack is simply how many you carry. A Belt Pouch, a Climber's Pack or a Belt Hook charm holds a fifth kind, and a Climber's Pack a fourth of each. Step on a new kind with a full belt and you choose: swap a stack out (it stays where you stand) or leave the new one. Survive the climb and whatever is left on your belt breaks into essence crystals, at half its worth."},
	"belt_wheel": {"group": "gear", "name": "The belt wheel",
		"tip": "Two kinds on your belt now. Hold {item} to choose one; tap {item} to use it. Choosing never uses anything.",
		"more": "A tap of {item} uses your current item, the one shown beside your weapon. Hold {item} (or {item_next}) and the belt wheel opens while the world slows: every item on your belt, with how many you carry; the current one wears a gilt pin. Point at one (the mouse, the right stick, or slide your finger onto it) and let go, or click, and it becomes your current item. Nothing is used until you tap {item} again. A tap of {item_next} picks the next item, and with the wheel open the keys 1 to 9 choose directly. Fire Flasks fly where you aim, oils and draughts work for a while, Flare Powder lights the room and makes hidden traps and secret walls nearby glint."},
	"spell_wheel": {"group": "essence", "name": "The spell wheel",
		"tip": "Let go and that spell waits on the button. Tap {cast} to cast it. Choosing never casts.",
		"more": "Hold a mark's button ({cast}) and the wheel of its spells opens while the world slows. Point at one (the mouse, the right stick, or slide your finger onto it) and let go, or click: it goes on the button, and nothing is cast. A tap of the button casts the spell on it. A mark with one spell has no wheel: holding its button just casts when you let go."},
	# --- the train ---
	"train": {"group": "train", "name": "The train",
		"tip": "A train, of all things. It waits between climbs: an outfitter, your own car, a workshop, a library. The engine takes you on when you're ready.",
		"more": "After the Regard, every climb ends on the train, whether you won, fell or read a recall scroll, and every climb starts from it. Walk along it from car to car ({cars}): the engine at the front, whose map shows the six towers on the loop: climb the one by the station you're at, or ride to another station; the Outfitter's Car (his consumables, weapons and armour, charms, selling, and his upgrade tree); your car (what you'll wear, your pack and your stash); the workshop (its bench: brewing and crafting, with a Rune Artist to craft for climbers without the mark); the Library (everything I've told you, on its shelves, read at the lectern); and the Settings & Controls Car (the settings, every key and button, and Start over). Your name at the top of the rail opens the climber screen; Dev Tools and Exit to Title Station sit under the cars. Your crystals sit along the bottom. Fall in a tower and you're back on the train in a moment."},
	"store": {"group": "train", "name": "The store",
		"tip": "The outfitter buys what climbers bring down and sells to the next ones up. He takes crystals: every stair condenses some for you, and he pays for every climb.",
		"more": "Essence crystals are the only money, and you hold one crystal of each kind, growing as you add to it. Every stair condenses a share of the essence you bank into crystals (To crystals, in Settings), and the outfitter pays for every climb, even one that ends in a fall: a few crystals of the tower's kind for each floor you reached, more for floors past your best there. Every price is in one kind of essence, taken from your crystal of that kind. Common pieces and basic supplies are cheap; finer pieces cost more. The recall scroll is always on the shelf, and takes crystals of any kind, your biggest first. Everything he offers shows at once, in four sections: Consumables (packed onto your belt for your next climb; put one back for its full price before you go), Weapons & armour (his rail, new every visit, and Today's piece, one finer piece in a glass case), Charms, and Sell (your pack and your stash: choose a piece, then Sell on its card, for a crystal of its kind at 40% of its price). When it doesn't all fit, the sections become a list that scrolls. A price you can't pay says how much more you need. Beside it all is his upgrade tree."},
	"shop_tree": {"group": "train", "name": "The outfitter's upgrade tree",
		"tip": "His upgrade tree: your rank is its trunk, and each rank opens nodes on its branches. Buy one with crystals; it's yours for good. Choose a node to learn more.",
		"more": "The trunk is your renown rank: each rank he stocks more for you, free. Four branches grow from it. Prices: money off what he sells, the recall scroll for less, more for what you sell him. Stock: a wider rail, a charm tray, better pieces, a Rare always on the rail, the special order (he holds a piece you choose), and once, a relic. Gifts: a draught on your belt every climb, crystals each visit, a Fine piece on each new rank. Info: what to pack for the next tower, his pick of the pieces that beat yours, a monster's weakness for your Bestiary, which way a contract's thing lies. A node opens when you have its rank and the node below it; a few also need a title from the Noble (a small pennant marks them). It costs crystals of any kind, your biggest first. Gilt nodes are yours, brass ones are open, dark ones are locked. On a phone, the Upgrades sign under him shows the tree."},
	"shop_grows": {"group": "train", "name": "A fuller shop",
		"tip": "His stock has grown with your rank: more on the rail, more on the shelf. It's new every visit.",
		"more": "The outfitter's stock follows your renown rank: the trunk of his upgrade tree. Each rank adds spaces to his rail (everything still shows at once, as a list that scrolls when it's long), more kinds of supply on the shelf, and better chances of Fine and Rare pieces. Pistols and crossbows hang on the rail from Known, and at the highest ranks a named piece or a relic hangs there now and then. Which supplies and pieces appear is new every visit; the Healing and Stamina Vials, the tonic, the Essence Vial and the recall scroll are always there."},
	"shop_title": {"group": "train", "name": "A title on the rail",
		"tip": "The title you wear shows on his rail: he hangs what suits it first. Some titles add an item to his shelf, or a little off.",
		"more": "Wear a title (the Noble at a station grants them) and the outfitter tilts his rail toward pieces that suit it: blades and pistols for a duel title, armour for a tournament title, packs and pouches for a trader's. A line over the rail says which. Some titles also put one supply on his shelf. What a title takes off his prices, or keeps for you on his rail, is one of its benefits: the Noble's card for each title lists them. Take it off and the next rail is as it was."},
	"station": {"group": "station", "name": "Stations",
		"tip": "A station. Nothing you carry is at risk here. Start with Training: short lessons, and I'll talk you through each.",
		"more": "There are six stations, each in a city near its tower, on a loop the train rides. Nothing you carry is at risk at one. Its rail lists the stops: Training (the basics, hands on, and medal drills), the Tournament (brackets against other climbers), the Noble (titles and contracts; every station has its own Noble, and titles are shared by every Noble) and the Renown Board (your rank and what the next one opens). Back to the train, at the foot of the rail, goes back to the Engine, where Step off brings you here again."},
	"training": {"group": "station", "name": "Training",
		"tip": "Each lesson is short. Choose one, then Begin; I'll say how as it starts. Skip what you already know.",
		"more": "Training teaches the game in short lessons: moving, rolling, parrying on the glint, the belt wheel, casting a mark, states and their cures, cracked walls, and the ward on the stair with its task. Each happens in a small arena; nothing there can fell you, and nothing is kept but the lesson being done. A lesson is remembered once done (or skipped), and finishing them all earns a little renown. Under them are the medal drills: a goal, a medal, a small fee in crystals, and renown for each first medal. Two extra drills open only for a title with a Training benefit."},
	"tournament": {"group": "station", "name": "Tournaments",
		"tip": "Three rounds against other climbers. Nobody dies: knocked down, you yield and the bracket ends.",
		"more": "The Tournament runs brackets of three rounds, each against another climber with marks of their own (in the Masters' Bracket, the last is your own reflection). They fight as climbers do, glints and spells and all, and yield when beaten. Between rounds your health and marks are made whole. Knocked down, you yield: the bracket ends, nothing more is lost. Entry costs a fee in crystals. Each round past your best earns renown; winning the bracket pays renown and crystals, the first time a relic in the higher brackets, and a title from the Noble. Higher brackets open with your rank, or two ranks sooner with a title that impresses tournament masters."},
	"noble": {"group": "station", "name": "The Noble",
		"tip": "The Noble grants titles by renown, and gives contracts for the towers. Read what each title gives.",
		"more": "The Noble keeps rooms at the stations. Titles: each needs a rank and a deed; once both are done the Noble will grant it (Be named ...), and you wear one at a time. Contracts: tasks for the towers (reach a floor of a tower, slay a number of one monster, retrieve a thing from a floor). A few are on offer each visit; take one (two from the rank of Respected) and it's tracked at the top of the screen while you climb. Done, it pays renown and crystals, and now and then a charm recipe."},
	"titles_social": {"group": "station", "name": "What titles give",
		"tip": "Only the title you wear counts. Each helps with someone: other climbers, Training, tournament masters, or the outfitter.",
		"more": "A title's benefits are social: how people treat you. Rival climbers may trade kinder, offer to team up more often, take a smaller toll when they beat you, or accept bets. Training may cost less and open its extra drills. Tournament masters may open higher brackets two ranks sooner, cut the fee or add to the prize. The outfitter may take some off, bring today's piece a rarity higher, or keep a Fine piece on his rail for you. Only the title you wear gives its benefits; its card at the Noble lists them."},
	"contracts": {"group": "station", "name": "Contracts",
		"tip": "Take a contract and it's tracked at the top of the screen while you climb. It pays when done.",
		"more": "A contract asks one thing of the towers: reach a floor of a named tower (any climb), slay a number of one kind of monster (anywhere), or retrieve a thing from a floor of a named tower (pick it up, then take the stair with it; a fall drops it and it waits on its floor again). Contracts never block anything: a floor's stair and task don't wait on them. Held contracts show as a line at the top of the screen in a climb, and I note their progress in my log. Done, one pays renown, crystals of its tower's kind and, now and then, a charm recipe for the workshop's bench."},
	"contract_done": {"group": "station", "name": "A contract done",
		"tip": "A contract done, and paid. The Noble has more at the next station.",
		"more": "When a contract is done it pays at once: renown (the line says what for), crystals of its tower's kind, and sometimes a charm recipe the workshop's bench can then craft. The Noble offers new ones every time the train stops at a station."},
	"rank_up": {"group": "station", "name": "A new rank",
		"tip": "A new rank. It opens something to do, not just more to buy. The Renown Board says what the next one opens.",
		"more": "Renown comes from every climb, from tournaments, contracts, Training, and deeds with other climbers; each gain says what it was for. Ranks come at thresholds, and each opens things to do: a higher tournament bracket, more of the Noble's contracts at once, a new tier of titles, a charm recipe, cheaper charm refills. A new rank is announced where you are, and the Renown Board at a station lists every rank and what it opens. The outfitter's stock grows with rank too."},
	"renown_board": {"group": "station", "name": "The Renown Board",
		"tip": "Your rank, how far to the next, and what it opens. Every rank is here; choose one to read it.",
		"more": "The Renown Board shows your renown and rank, how much more the next rank needs and what it opens, every rank with what it opens (choose one for its card), your recent deeds with the renown each earned, and the climbers you've met in the towers with your history with them."},
	"travel": {"group": "station", "name": "The tower map",
		"tip": "The engine's map: six towers on a loop, a station by each. You climb the tower by the station you're at. To climb another, ride there first.",
		"more": "The six stations sit on a loop in tower order, each in a city near its tower. The Engine holds the tower map: every tower, the station by it, the one you're at (a small train) and the fare to each. Choose the tower by your station and pull the lever to climb it. Choose another and its placard shows the ride: how many stops, the fare, and a lever that takes you there. After a climb you're back on the train at the same station."},
	"travel_lock": {"group": "station", "name": "Travel is locked",
		"tip": "For now only this station's tower is open to you. Earn your first mark, or become Unbound, and the train will take you anywhere on the loop.",
		"more": "Travel between stations stays locked until you earn your first mark (a faint one counts too), or until you refuse the marks and become Unbound. Until then the map shows a padlock on every other station, and the climb starts from the station you're at. Once it opens, ride anywhere on the loop for a fare."},
	"fares": {"group": "station", "name": "Fares",
		"tip": "A ride costs 12 crystals of any kind for each stop, the shorter way round: 36 at most. Some titles cut the fare.",
		"more": "The fare is paid in crystals of any kind, the biggest first: 12 for each stop between the station you're at and the one you ride to, going the shorter way round the loop, so 12, 24 or 36. Some titles cut it while you wear them (a quarter, or a half): the Noble's card for each title says so. The map shows the fare on every station; the numbers are in the Data editor."},
	# Training and tournaments (training.gd, tournaments.gd).
	"grace": {"group": "station", "name": "The Noble's Grace",
		"tip": "The towers are closed to you until the Noble grants you the Grace. Earn it here: basic training at the gym, then your first tournament.",
		"more": "Every climber needs the Noble's Grace before entering a tower and taking a mark. A new climber earns it at their home station: first the six lessons of basic training at the gym (every way to move, attack and parry; they can't be skipped until the Grace is yours), then one tournament of three rounds at the tournament grounds. The Grace comes win or lose. Until then the engine's lever is locked."},
	"basic_training": {"group": "station", "name": "Basic training",
		"tip": "Six lessons: moving, rolling, jumping, striking, shooting, parrying. I'll talk you through each. Where your body works hardest, your first mark will show.",
		"more": "Basic training is six short lessons at the gym: walking to posts, rolling, jumping, striking dummies with combos, shooting with your bow, and parrying on the glint. Nothing there can fell you. Essence earned in training (and in your first tournament) goes into your body only, at a quarter of the usual amount: little, but it shows which body part you use most, and so where your first mark will appear. Come back any time to refresh a lesson; after the Grace, a lesson you know can be skipped."},
	"first_tournament": {"group": "station", "name": "The first tournament",
		"tip": "Your first tournament: two rounds of monsters, then a champion fighter. Nobody dies. The Grace is yours either way; each round you win adds a reward.",
		"more": "The first tournament is three rounds at your home station's grounds: low-level monsters twice, then a human champion fighter with no marks. Between rounds your health is made whole; knocked down, you yield and it ends. Win or lose, the Noble grants you the Grace. Each round won adds a reward: one, a Healing Vial; two, a recall scroll; three, a Fine weapon or armour piece of the kind you fought with most. Take no damage at all and the Noble adds a tincture of each essence."},
	"first_rewards": {"group": "station", "name": "Your first rewards",
		"tip": "The Grace is yours. Vials and scrolls wait packed for your next climb; a piece waits in your stash, and tinctures can be drunk from your book's Essence page.",
		"more": "The first tournament's rewards: a Healing Vial and a recall scroll are packed for your next climb (Your Car shows them); a Fine piece goes into your stash, ready to wear from your wardrobe; tinctures, for a flawless tournament, are packed too and can be drunk from your book's Essence page into an unmarked body part. With the Grace the engine's lever opens: your home tower awaits."},
	"advanced_training": {"group": "station", "name": "Advanced training",
		"tip": "Advanced training opens in tiers with the titles the Noble grants you. Each try costs a few crystals of the essence that fits it.",
		"more": "Advanced training refines what basic training taught: the belt wheel, states and cures, cracked walls, the ward and its task, the perfect parry, fighting a crowd. Its three tiers open with titles: your first title, then a title of a higher rank, then a higher one still (each tier's lock says which). Each try costs a small fee in crystals of the essence that fits it, the first time pays a little renown, and the essence you earn is half the usual, flowing into you as at a stair."},
	"mark_training": {"group": "station", "name": "Mark training",
		"tip": "Your mark can train now. Dummies first, then summoned creatures, then human rivals who spar until they yield.",
		"more": "Mark training opens with your first mark (or as an Unbound, with your techniques). Its partners are training dummies, creatures summoned for you, and human rivals with marks of their own who yield when beaten. Its tiers open with titles, like advanced training; each try costs a few crystals of your strongest mark's essence, and pays half the usual essence."},
	"tourney_manager": {"group": "station", "name": "The Tournament Manager",
		"tip": "Tournaments now belong to the Tournament Manager, who moves round the stations. Each place has its own arena, hazards, creatures and rivals.",
		"more": "After your first tournament, the brackets are run by the Tournament Manager, who travels the loop, moving on after each of your climbs (the grounds say where they are and where they go next). Each location changes the arena: its layout and hazards, the creatures in the first round, and the rivals' marks. Entry costs a fee. A win pays renown, crystals, essence (half the usual), a Healing Vial wherever you win, and the first time you win a higher bracket at a location, a prize found only there."},
	"tour_station": {"group": "station", "name": "The station tour",
		"tip": "Let me show you round. The gym, the tournament grounds, the Noble's estate, the train.",
		"more": "The first time you're at a station, the Entity shows you round: the gym (Training), the tournament grounds, the Noble's estate and the train. Its bar at the top of the page has Next, Back and Skip the tour. Ask the Entity \"Show me around again\" to see it again, any time between climbs."},
	"tour_train": {"group": "train", "name": "The train tour",
		"tip": "Let me show you the train, car by car.",
		"more": "The first time you board the train, the Entity shows you its cars in order: the climbers' car (your wardrobe, pack, stash and your climber's book), the outfitter, the workshop, the dining car, the settings and controls car, and last the engine with the tower map. Next, Back and Skip the tour are on its bar at the top of the car. Ask the Entity \"Show me around again\" to see it again."},
	"dining": {"group": "train", "name": "The Dining car",
		"tip": "The Dining car. Other climbers eat here between climbs: some you've met up there, some new. Choose one to talk.",
		"more": "Each time you're on the train, three to five climbers sit at the Dining car's tables: mostly climbers you've met in the towers, who remember what you did, and a new face or two (talk to them and they join the climbers you've met, so you may run into them on a climb). Tap one to talk, then pick a line. Ask for a rumor: something true about a tower, its beast, a monster's weakness (it goes into the Bestiary), a sealed wing or another climber. Make a wager on your next climb. Trade: their goods follow their marks. Or challenge them to a duel, fought in the Arena car. One you robbed is cold and won't trade, bet or share rumors; one you helped or climbed with is glad to see you: a small gift, better odds, a little off."},
	"dining_talk": {"group": "train", "name": "Talking with a climber",
		"tip": "Pick a line. What you did to them up there, they remember down here.",
		"more": "Talking with a climber in the Dining car works like talking with me: pick what you say. Their first words follow your history with them: a duel won or lost, a climb shared, a hand up, a hoard taken. Their marks show under their name, and your history with them under that. Goodbye ends the talk; tap another climber to talk to them instead."},
	"dining_rumor": {"group": "train", "name": "Rumors",
		"tip": "Rumors here are true. Climbers lie about themselves, never about towers.",
		"more": "Each climber in the Dining car has one rumor a visit, and it's always true: the game reads it from its own tables as they say it. A tower's handy item and why, its beast and what to watch for, a monster's weakness (written into the Bestiary at once, marked as told), the floor a sealed wing's rule can start from, a dark tower, another climber's mark, or the best odds on offer tonight. Ask each climber: they tell different things."},
	"dining_bet": {"group": "train", "name": "Wagers",
		"tip": "A wager on your next climb, in the tower the Engine's board has chosen. Win and they pay the stake times the odds.",
		"more": "A climber in the Dining car offers two wagers on your next climb, in the tower chosen on the Engine's board: reach a floor, fell the beast, reach a floor without drinking a Healing Vial, or slay so many of one monster. Harder ones pay more; a warm climber, or a title they like, gives better odds. Choose one, then a stake (crystals of any kind, your biggest first). Up to two at once. They run on your next climb and show at the top of the screen; when the climb ends, however it ends, a win pays the stake times the odds in the tower's essence and a loss keeps your stake. Climb another tower and the wager is off: your stake comes back."},
	"dining_duel": {"group": "train", "name": "Duels in the Arena car",
		"tip": "A duel in the Arena car: name the stake, then first to yield loses. Nobody dies.",
		"more": "Challenge a climber in the Dining car and choose what you fight for: crystals, a piece of gear (yours from the stash against one of theirs), or renown. The duel is fought in the Arena car, which you can only reach this way: a roped ring of sawdust with onlookers on benches. They fight as climbers do in the towers: their weapon, rolls, a guard and their marks' spells. They yield when badly hurt; a blow that would fell you makes you yield instead, never killed. Win: their stake, a little renown, and it counts toward the Duelist title. Lose: they take yours. Either way you're back in the Dining car after, and they remember."},
	"arena_car": {"group": "train", "name": "The Arena car",
		"tip": "The Arena car. First to yield loses. Nobody leaves here dead.",
		"more": "The Arena car is coupled behind the Dining car and opened only for a duel. Fight as you would in a tower; your marks work as ever. When they yield you've won; if a blow would fell you, you yield instead, with a little health left. After two minutes it's called a draw and the stakes stay where they were. The pause menu can give up (that counts as yielding). Then back to the Dining car."},
	"chest": {"group": "train", "name": "Your pack, stash and Loadout",
		"tip": "Your stash keeps things safe on the train. Your pack goes up with you, and falls with you.",
		"more": "Besides what you wear you carry a pack of spare pieces: two with no bag, more with a bag in your backpack slot (a Satchel 4, a Pack 6, a Great Pack 8; a big bag nearly full slows you a little). Swap gear in the tower and your old piece goes in your pack while there's room. Survive a climb, or read a recall scroll, and what you wear and your pack come down to the train with you (fall, and they're lost): sell what you don't want, or keep it in the stash in your car (forty spaces), safe on the train. The Loadout in your car is what you'll wear when you set off: choose pieces from your pack or stash to wear over your heirlooms (an heirloom you don't wear waits on the train, still yours). When you depart, what you chose goes on, your pack comes with you, and a pack piece whose slot is empty you put on too. Fall, and your pack is lost; survive, and only your pack comes back down."},
	"fall_loss": {"group": "train", "name": "Lost on the way down",
		"tip": "A fall takes your pack and your belt, sometimes the weapon in your hand. The tower keeps what it takes. For a while.",
		"more": "Fall in the tower and your pack and everything on your belt are lost, and there's a chance the weapon in your hand goes too (your melee weapon, if your fists were out; never the starting sword or bow). Your heirlooms are never lost, and your stash and crystals are safe on the train. The fall screen says what was taken. The tower remembers the last six pieces you lost, and where: on a later climb of the same tower, near the floor where they fell, your fallen pack may turn up again."},
	"lost_cache": {"group": "train", "name": "A lost cache",
		"tip": "Your own pack, where you fell. The tower gives back, now and then.",
		"more": "A lost cache is the pack you lost in a fall, lying in an ordinary room of the same tower, near the floor where you fell, with a faint pale light over it. Walk onto it and up to three of your lost pieces come back: into your pack while there's room, else at your feet. Each climb of that tower, a floor near where things fell has a chance to hold one. Items from your belt don't come back."},
	"bench": {"group": "train", "name": "The bench",
		"tip": "The workshop's bench. Anyone can brew here: what you make is packed onto your belt for your next climb.",
		"more": "The bench in the workshop car has a counter for each kind of work, and a card with what it costs in essence (a price you can't pay says how much more you need). Brew makes a consumable for your next climb, a little cheaper than the store sells it; put one back before you go and what you paid comes back. Break down turns a piece from your pack or stash, or a packed item, into a crystal of its kind, as the store's Sell does. A choice that can't be undone asks first: tap the same button again to do it."},
	"enchant": {"group": "train", "name": "Enchanting",
		"tip": "Tempering, swapping traits, joining pieces, lasting runes: crafting. Every climber can have it done here.",
		"more": "Crafting at the bench is open to every climber. With the Rune Artist's mark you craft it yourself, with your own essence; without it, the Rune Artist who works the bench crafts it for you, for the same crystals plus a premium on top (each card says who crafts and what the price is made of). Temper raises a piece's rank from +1 to +3: each rank makes its traits a quarter stronger (of their base) and a weapon hit 4% harder; +2 and +3 also need that essence's density settled in you (100, then 300). Retrait swaps one trait for a new one: the crystal you pay chooses its essence. Join makes one Rare piece of two Fine pieces for the same slot, keeping a trait from each. Inscribe puts a lasting rune on a piece (Sharpness, Warding or Swiftness, at half the Inscribe spell's strength), drawn on its icon. A recall scroll can be bound here (you carry one), a vessel brewed or a full one worked into a piece, and new charms crafted. A Rune Artist also brews for 20% less. The bench works on your heirlooms and the pieces in your pack and stash. Only Common pieces wear; anything with a trait never does."},
	"rune_artist": {"group": "train", "name": "The Rune Artist",
		"tip": "Someone works the bench now: a Rune Artist. Bring the crystals and they craft what your marks can't, for a premium on top.",
		"more": "A Rune Artist stands at the workshop's bench. Without the Rune Artist's mark, everything the bench crafts (tempering, swapping a trait, joining two pieces, a lasting rune, a recall scroll, a vessel or working a full one into a piece, a new charm) is crafted for you by them. You pay the same crystals a Rune Artist would use, and their premium on top: half the materials again (at least one of each kind), or a small fee of the piece's kind when a full vessel does the work. Each card shows the whole price and says who crafts. With the mark yourself, you craft with your own essence and pay only the materials. Point at the Rune Artist (or hold a finger on them) to hear what they do; tap them and they'll talk."},
	# --- screens ---
	"climber": {"group": "screens", "name": "The climber screen",
		"tip": "{climber} shows what you are: your marks, the essence in you, and what I've recorded.",
		"more": "The climber screen is your book. Its ribbons are its sections: Abilities (what you can cast now), the Tree (your body map: how you can grow), your marks drawn on your body with a card for each (choose one for every spell and step), the essence settled in you and its bonuses, your record and heirlooms. {climber} opens and closes it (so does your name at the top of the menu's rail, and the book lying in your car on the train); Q and E, or a swipe, turn its pages. Everything I've told you is in the Library."},
	"tree_fork": {"group": "screens", "name": "Choices on the tree",
		"tip": "A choice has opened on your tree. Read both sides: whatever you choose is yours for good, and the other is gone.",
		"more": "As a mark grows, its tree offers choices: at step 2 and step 4 one spell or another, and at step 3 one way or another to change your first spell. Until you choose, the side you've always had stays in use. A choice takes a second press, because it's for good: a mark never goes back. The Unbound choose too, between two variations at some levels of each part; they keep what they choose, but once that part is a level higher they can still learn the side they passed on, for crystal essence. A side marked Coming soon isn't written yet and can't be chosen, and a mark's steps past 5 show as Coming soon until marks grow further."},
	"appearance": {"group": "screens", "name": "Appearance",
		"tip": "How you look is yours to choose. Change each part with {choose}; it changes nothing but your looks.",
		"more": "The appearance page sets how the climber looks in the towers and on the climber screen, in six tabs: Body (masculine, feminine or androgynous, the build, the skin), Face (eye shape, eye colour, features), Hair (style, colour, facial hair and its colour), Clothes (what you wear, its colour, trousers, boots, belt), Cloak (cape or cloak, its colour, trim, texture, the hood up or down) and Extras (an accessory). Every colour row has six swatches and a colour wheel (the rainbow at its end) for a colour of your own: on the wheel, pick a colour, then its brightness and strength, and Done. Left and Right on the tabs turn them (or tap one); up and down move between the rows; Left and Right (or the arrows, or a swatch) change one. Randomise rolls a whole new look and keeps the name. Turn spins the preview (Q and E, or LB and RB). Later, the page also holds your name and pronouns. A new climber chooses a look after the name; change it any time with Appearance on the climber screen's Marks tab, or in your car on the train. Looks never change how you play."},
	"climbers": {"group": "screens", "name": "Climbers",
		"tip": "Up to six climbers, each kept apart. Choose one to play; Delete asks twice.",
		"more": "The Climbers page (from the title screen) holds up to six climbers. Each has their own marks and essence, crystals, train, heirlooms, look and name, record, Makers and everything I have told them; a new climber hears my tips again. Settings, controller setup and tips on or off are shared. Choose a card to play that climber, or an empty slot to begin a new one. Delete under a card asks for a second press, and a deleted climber can't be brought back. Continue on the title plays whoever was played last. Start over only starts the current climber over."},
	"inventory": {"group": "screens", "name": "The inventory",
		"tip": "{inventory} shows everything you carry, and lets you use it.",
		"more": "The inventory lays out what you wear like a body: helm, amulet and cloak; melee weapon, chest and ranged weapon; a ring, gloves and a ring; backpack, legs and boots. Beside it are your fists, the off-hand (a second weapon, a shield or a wand), your charm, gear lying at your feet and a camp's rune; below, your items with their counts (the quick item gilded). Worn pieces show their condition. Switch to Heirlooms to see what every climb begins with. Choose a slot for its details (compared with what you wear), to use an item, or to take the gear at your feet."},
	# --- creator tools (arrange.gd): Arrange mode says these in its own card
	# (the game is paused there), the first time; "always" keeps them
	# readable in the Archive before they're met (guide.gd known) ---
	"arrange": {"group": "creator", "name": "Arrange mode", "always": true,
		"tip": "Three steps. One: pick a block from the list. Two: {grab}. Three: press Save.",
		# (the three steps, left in Arrange mode's list until each is done)
		"steps": ["Pick a block from the list", "Drag it where you want it", "Press Save"],
		"more": "Arrange mode ({arrange}) pauses the game and shows what's on screen as a few big blocks, each with one outline, a number and a name. The list at the side names them: click a row to choose its block. Drag the chosen block to move it, and pull a corner handle to make it bigger or smaller (it keeps its shape). The list says how far it has moved and its size, and the round arrow on its row puts it back. To arrange the parts inside a block, go inside it (double-click it, or Enter); Esc backs out. Only one level's blocks show at a time. A block snaps to an 8 px grid, the screen's edges and centre lines and the blocks beside it, and lines show where; {nosnap} to place it freely. Blocks that come to overlap turn red. With a controller, the d-pad (or LB and RB) picks the next block, A goes inside, B backs out, the left stick moves it, the right stick resizes it, X undoes, Y saves and Start finishes. On a keyboard, Tab picks, the arrows nudge and [ and ] resize. Drag the toolbar or the list by its title to move it aside; the toolbar's ? shows this again. Nothing is kept until you Save."},
	"arrange_sets": {"group": "creator", "name": "Phone and computer layouts", "always": true,
		"tip": "Your phone and your computer each keep a layout of their own. Moving a thing on one leaves the other alone.",
		"more": "There are two layouts: the computer's, and the phone's (which draws everything 1.5 times bigger and has the touch buttons). Each is arranged and saved on its own. Touching the screen switches to the phone's layout; a keyboard, mouse or controller switches back. In Arrange mode the button at the top right of the toolbar changes which one you're editing, so on a computer you can arrange the phone's layout too, shown as a phone shows it."},
	"arrange_save": {"group": "creator", "name": "Saving a layout", "always": true,
		"tip": "Save keeps it on this device. To make it everyone's, Save while the game runs from Godot on your computer, or Copy layout and give it to Claude.",
		"more": "Save keeps your layout on this device only. To make it permanent for everyone: on your computer, run the game from Godot (F5), arrange it, and press Save; that also writes the project's file data/layout.json. Then in GitHub Desktop the change shows on the left: type a short summary at the bottom left (like \"New HUD layout\"), click \"Commit to main\", then \"Push origin\" at the top. On a phone or the web version, Save can't reach the project: tap Copy layout and paste it to Claude in chat. Reset goes back to the shared layout."},
	"arrange_menus": {"group": "creator", "name": "Arranging menus", "always": true,
		"tip": "The menus can be arranged too. The page is one block and the rail another: go inside a block to move its parts.",
		"more": "Open any page (the inventory, the climber's book, Settings, the pause menu, the train's cars) and press F2 (or Dev tools, then Arrange menus). The page stays showing. At first there are two blocks: the page and the left rail (on the train: each piece of furniture in the car you're in, the crystal bar and the rail; go inside a piece for its heading, slots, buttons and words, and a grid for each slot; ‹ Car and Car › in the toolbar move along the train). Go inside the page (double-click it) and its parts show instead: its title, its tabs, each column or row; go inside one of those for its cards. Esc backs out. The page and the left rail have blue bars on their sides: pull the page's side to make it wider or narrower, the rail's right edge to change its width (the wheel over it changes its text size) and, inside the rail, the bottom of its list to spread its pages or cars apart. Reset this puts back the chosen block and what's inside it, Reset page everything showing. Things stay inside the screen or their page, and keep their place as a share of the screen, so a menu arranged on the computer still fits a phone (the phone uses the computer's arrangement unless you arrange its own). Save keeps it, as for the HUD. The toolbar's Arrange the HUD button switches to the HUD."},
	# --- the secret bonds' tools (secret_bonds.gd, secret_tools.gd): mechanical text only ---
	"tool_ring": {"group": "tools", "name": "The tool ring",
		"tip": "Hold {tools} for your secret bond's tools. Every tool costs essence you carry.",
		"more": "A secret bond's tools are used from the tool ring: hold {tools} and the ring opens and time stands still; point at a tool (the mouse, a stick, or slide your finger) and let go to choose it (choosing never uses it). A tap of {tools} uses the chosen tool, or closes an open panel. Under each tool, gems show its cost: your path's secret essence (Making or Unmaking) and ordinary essence, both from what you carry unbanked. A unit of secret essence you don't carry costs three essence instead. A tool that aims works on what you aim at when you use it."},
	"tool_inspect_developer": {"group": "tools", "name": "Inspect (the Developer)",
		"tip": "Your spells' real numbers, for the rest of the floor: on the spell ring while you aim, and in the panel.",
		"more": "The Developer's Inspect shows every spell you carry with its real numbers: cost, wind-up, damage, reach and the rest, with everything that changes them already counted (a faint mark, your density, gear, flow and Tune), and what each step adds. Once paid it lasts the floor: the spell ring shows the pointed spell's numbers while you aim, and using Inspect again opens or closes the panel for free."},
	"tool_tune": {"group": "tools", "name": "Tune (the Developer)",
		"tip": "Between climbs, set each spell for more power, less cost or a quicker wind-up.",
		"more": "The Developer's Tune works between climbs, on the climber screen's Core tab while you're on the train. Each spell you carry takes one setting: Power (20% more power: damage, shields, durations), Thrift (25% less cost) or Quick (40% quicker wind-up). Each change costs crystal essence; clearing a setting is free. The setting stays until you change it."},
	"tool_path": {"group": "tools", "name": "A new path (the Developer)",
		"tip": "The Developer can change your path. Everything your path banked flows out, and a new path starts from nothing.",
		"more": "On the train, the Developer can let your path go: all of its flow, banked and carried, flows out of your shadow, and the next great foe offers the choice of Making or Unmaking again, starting from nothing. It costs crystal essence."},
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
		"more": "The Developer's Write casts any bond's spell you don't hold, once a floor, at the step your best bond has reached: pick an essence, a bond, then a spell (not a form, a toggle, a kin-book spell or Phoenix Heart, which rises by itself). It costs the tool, not a mark's essence. On the train, Write also moves a mark to another body part, or swaps two, for crystal essence: the bond and its growth go with it."},
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
	# --- creator tools: the room painter (painter.gd). It shows these in its
	# own card the first time (the game is paused there), and "?" shows them
	# all again; "always" keeps them readable in the Archive before they're met ---
	"painter": {"group": "creator", "name": "The room painter", "always": true,
		"tip": "Rooms are only tiles. Pick a tile on the right, then tap, click or drag on the grid to lay it. Built-in rooms stay as they are: painting one makes your copy.",
		"more": "The room painter (Dev tools, then Paint rooms) draws a room tile by tile, the way the game's hand-made rooms are written. Pick a tile from the palette on the right: floor, wall, rock, pillar, chasm, water, a monster's spot, a random tile, or a puzzle room's rails, eyes, plates, blocks, gates, levers and rewards. Tap, click or drag on the grid to lay it. The tools on the left: Brush lays tiles one by one, Fill fills an area of the same tile, Box lays a filled box (drag from corner to corner), Eraser lays floor; Mirror copies what you paint to the other side, left and right or top and bottom; Undo and Redo; Zoom (or pinch with two fingers, or the mouse wheel). With a controller, move the cursor with the d-pad or stick: A paints, B erases, LB and RB change the tile, X the tool, Y goes to the buttons. With keys: the arrows, Enter paints, Delete erases, Q and E change the tile, Tab goes to the buttons. Rooms opens the list of rooms (open, copy, rename or delete yours; built-in rooms can only be copied), and Room its settings: its name, size, job (start, combat, stair or puzzle), first floor, whether it may flip, and which towers may use it."},
	"painter_checks": {"group": "creator", "name": "The room's checks", "always": true,
		"tip": "A room must let you reach everything that matters. What's wrong shows on the right, in red, and on the grid. A room that fails waits as a draft.",
		"more": "The painter checks the room as you paint, the way the game would build it: a corridor needs two open tiles side by side, two deep, on a side of the room; the stair, every monster spot, where the climber starts and a puzzle's plates must all be reachable; a low wall (a wall standing free inside the room) that would cut one of them off is left out in play, so it's flagged; and a puzzle room needs what its puzzle uses. Problems show in red on the right and outlined on the grid (tap one to find it); warnings in gold are worth a look but don't stop the room. Chasms are only real in the Firebird's tower, so a room can pass in one tower and not another. A room that fails can still be saved as a draft, but the climb won't use it until it passes."},
	"painter_try": {"group": "creator", "name": "Trying a room", "always": true,
		"tip": "That was your room, in this tower, with monsters on their spots. Try it again whenever you change it.",
		"more": "Try it drops you straight into the room you're painting, in the tower you're climbing, beside a small hall where you start, with a monster on each of its monster spots. You can't fall while trying a room. To come back to the painter, press {menu}, or walk onto the stair. The floor you were on is laid out again afterwards."},
	"painter_climbs": {"group": "creator", "name": "Rooms in your climbs", "always": true,
		"tip": "Switched on, your room joins the climb's rooms for its job, once it passes its checks.",
		"more": "Use in climbs is a switch on each of your rooms (in the room list, the room's settings, and under the palette). Once a room is switched on and passes its checks, the floor planner may pick it like a built-in room of the same job: a start room for the room you begin a floor in, a combat room for the rooms along the way, a stair room for the stair hall, a puzzle room for the gallery. Like the built-ins, it can flip, never appears twice on one floor, and only shows up from its first floor and in the towers you chose. A draft stays out until it passes."},
	"painter_save": {"group": "creator", "name": "Keeping your rooms", "always": true,
		"tip": "Save keeps your rooms on this device. To make them part of the game for good, save from Godot on your computer, or Copy rooms and give them to Claude.",
		"more": "Save keeps your rooms on the device you're playing on. To make them permanent, in every copy of the game and the web build too: on your computer, run the game from Godot (press F5), open the painter and press Save; that writes the project's file data/rooms_custom.json. Then open GitHub Desktop: the change shows on the left. Type a short summary at the bottom left (for example \"New rooms\"), press Commit to main, then Push origin at the top. On your phone: open Save, press Copy rooms and paste the text to Claude, who can add the rooms for you; or paste it into Paste rooms in the painter on your computer (running from Godot) and press Save there. Leaving the painter also saves what isn't saved yet."},
	# --- creator tools: the Data editor (data_page.gd, data_registry.gd) ---
	"data_editor": {"group": "creator", "name": "Edit game data",
		"tip": "Here you can rewrite the game: its words, numbers and colours. Even mine. Pick a section or search, change a value, and it takes.",
		"more": "Edit game data (Dev tools, from {menu} or the title) changes the game's words, numbers and colours without any code. The tabs Words, Numbers, Colours and Appearance each hold sections (the Entity's words, store prices, menu colours and more); choose one, or type in the search box to find any name, word or number. Words go in a text box: its Edit button, a click or a tap opens it, and Enter or leaving the box keeps what you wrote (Esc leaves the box). Numbers have a slider and a box to type in. A colour's swatch opens sliders for its hue, colour, light and opacity, beside a #hex box. A changed entry turns gilt and shows its default under it; its Default button puts it back. My changes lists everything you changed, to put back one at a time, or all at once with two presses. Most changes show at once; a row says if it waits for the next page, the next floor or a restart. Changes save by themselves a moment after you make them (the ? button tells you all this again, and how to keep them for good)."},
	"data_save": {"group": "creator", "name": "Keeping your changes",
		"tip": "Saved. On the computer, in Godot, that went into the project: commit it in GitHub Desktop. On a phone it stays here: send it to Claude.",
		"more": "Where a change is kept depends on where you play. On the computer, running the game from Godot (the play button or F5), Save writes your changes into the project's file data/overrides.json. To make them part of the game for good, open GitHub Desktop: it lists data/overrides.json under Changes. Write a short summary at the bottom left (\"Cheaper vials\", say), click Commit to main, then Push origin at the top. From then on every copy of the game has them, the web version too. On a phone or in a browser, Save keeps the changes on that device only. To keep them for good, press Copy changes and paste what it copies into a message to Claude; or, on the computer, press Paste changes, paste them in, and Save there (then commit them as above)."},
	"data_restart": {"group": "creator", "name": "Changes that wait for a restart",
		"tip": "That one is read when the game starts. It's saved; you'll see it after the game starts again.",
		"more": "A few values are read only once, as the game starts (the colour behind the rooms, for one). Their rows say \"applies after a restart\". The change is saved like any other: close the game and start it again to see it. Everything else shows at once, on the next page you open, or on the next floor, as its row says."},
}

## Room features (themes.gd) -> the tip for walking into one.
static var ROOM_TIPS := {
	"trap": "trap_room", "den": "den", "ambush": "crypt", "spring": "good_room", "cache": "good_room",
	"camp": "good_room", "chasm": "jump", "mirror": "mirror", "rival": "rivals",
}

## Words for {move}, {attack}... in tips: [keys, controller, touch]. The
## controller column may use {a}, {lb}... (button names, controls.gd).
const KEYS := {
	"move": ["WASD or the arrows", "the left stick", "the left of the screen"],
	"attack": ["left click or J", "{rt}", "the big button"],
	"roll": ["Space", "{b}", "Roll"],
	"parry": ["right click or K", "{lt}", "Parry"],
	"jump": ["Z", "{a}", "Jump"],
	"weapon": ["1, 2 or 3, or the mouse wheel", "{rb}", "the Swap button"],
	"take": ["Y", "{y}", "Take"],
	"item": ["G", "{x}", "Item"],
	"item_next": ["T", "the d-pad down", "the small arrow"],
	"cast": ["the mark's key (Q E F C X V)", "{lb} and the mark's button", "the mark's button"],
	"climber": ["Tab", "{back}", "the Climber button"],
	"abilities": ["hold Tab", "press {back}", "hold the Climber button"],
	"inventory": ["I", "the d-pad up", "the Bag button"],
	"menu": ["Esc", "{start}", "Menu"],
	"restart": ["hold R", "hold {back}", "Menu, then Restart"],
	"dismiss": ["Enter or a click", "a press of the right stick", "a tap"],
	"choose": ["the arrows (or a click on a swatch)", "the d-pad or stick", "the arrows or a swatch"],
	"tools": ["B", "{lb} and {lt}", "Tools"],
	"offhand": ["U or the middle mouse button", "the left stick, pressed in", "the Off-hand button"],
	"block": ["holding right click or K", "holding {lt}", "holding Parry"],
	"arrange": ["F2, or Dev tools then Arrange layout", "Dev tools, then Arrange layout", "Settings, then Arrange this screen (on the train: the Settings car, then Arrange the train)"],
	"grab": ["drag it with the mouse", "pick it with the d-pad and push the left stick", "drag it with a finger"],
	"resize": ["pull a corner handle", "push the right stick up or down", "pull a corner handle"],
	"nosnap": ["hold Shift", "turn the grid off with {back}", "turn the grid off in the toolbar"],
	"cars": ["Q and E, the mouse wheel, or a car on the rail at the left", "{lb} and {rb}, or up and down on the rail at the left", "swipe, or tap a car on the rail at the left"],
}

## Menu lines sent away this session (by their words): a page built again
## leaves them out. guide.gd clears it when the tips are replayed.
static var gone := {}
## How a menu line is sent away, for the device in use ("tap", "click or
## L", "RS"): the menu sets it as it builds a page.
static var away_how := ""

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
	text = Pronouns.fill(text)
	for k in fill:
		var v := str(fill[k])
		text = text.replace("{%s}" % k, v)
		text = text.replace("{%s}" % String(k).capitalize(), v.left(1).to_upper() + v.substr(1))
	return text


## Fills {move}, {attack}... with the words for the device in use:
## mode "keys", "pad" or "touch"; `ps` for PlayStation button names.
static func fill_keys(text: String, mode := "keys", ps := false) -> String:
	var col := 1 if mode == "pad" else (2 if mode == "touch" else 0)
	text = Pronouns.fill(text)
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
## A line it says by itself (a first-time tip, a page's line, an answer to
## a choice) stays until it's sent away: a click or tap on it (or the
## sphere), or L / the right stick (entity_helper.gd send_away); `away`
## false for words the player chose to read (the Archive, a talk). A line
## sent away this session comes back hidden.
static func says(text: String, face := 46.0, heading := "", away := true) -> HBoxContainer:
	text = Pronouns.fill(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if away:
		row.set_meta("entity_away", true)
		row.visible = not gone.has(text)
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
	if away and away_how != "":
		# Its name tag, and on the right how to send it away.
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override("separation", 10)
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(tag)
		var how := Label.new()
		how.text = String(TEXT["away"]) % away_how
		UI.style_label(how, "mono", 10, Color(UI.FAINT, 0.9))
		how.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		how.set_meta("entity_away_hint", true)
		head.add_child(how)
		col.add_child(head)
	else:
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
