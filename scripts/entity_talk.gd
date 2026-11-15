extends RefCounted
## Talking with the Entity: pick a question, and it answers from the game's
## own facts, in its voice. No typing, no outside service: everything it can
## say is here, in plain data (and in the Data editor: "The Entity's words").
##
## On the train, click or tap its sphere (or press L, or the right stick);
## in a climb, open its panel and press Talk (or hold L / the right stick).
## menu.gd's "talk" page shows it: the Entity's line, then its choices as
## buttons (mouse, keys, controller and touch, as every page), Esc or B to
## leave.
##
## DIALOGUE is a small tree of nodes, by id. Each node:
##   ask      what you say to get here: the choice's words (blanks allowed)
##   lines    what the Entity says here: one is picked each time. {name}
##            blanks are filled from `fact` (below), and from the words of
##            the moment ({floor}, {tower}...)
##   fact     a fact to fill the blanks with (the game as it is now):
##            tower, hazards, marks, soak, money, next, next_more, climb
##            (the functions _fact_<name> below; facts() lists them)
##   choices  where you can go next: node ids. "start" goes back to the
##            first question; a choice is shown only when its node's `if`
##            holds and it has something to say
##   if       when the choice shows: on_train, in_play, marked, unbound,
##            climbed (on the train after a climb), logged (events to tell)
##   leave    choosing it ends the talk
## At most MAX_CHOICES show at once; more go under "Something else".
##
## STORY SLOTS (the owner's to write): a node whose every line starts with
## STORY_TAG is hidden from players. Write the Entity's answer over that
## line (here, or in the Data editor, which shows the line) and the choice
## appears. Never invent the story here: who the Entity is, and what the
## towers are for, are the owner's.

const Towers := preload("res://scripts/towers.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Essence := preload("res://scripts/essence.gd")
const Entity := preload("res://scripts/entity.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Boons := preload("res://scripts/boons.gd")
const Unbound := preload("res://scripts/unbound.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Notices := preload("res://scripts/notices.gd")
const Flow := preload("res://scripts/essence_flow.gd")

## A line that starts with this is a story slot not written yet (hidden).
const STORY_TAG := "[Yours to write]"
## At most this many choices show at once (Goodbye among them).
const MAX_CHOICES := 5

static var DIALOGUE := {
	"start": {"ask": "Something else.",
		"lines": [
			"Yes? I was counting.",
			"Ask. I keep the answers as well as the list.",
			"You want something. Go on.",
			"Questions. Good. I have a few answers.",
		],
		"choices": ["next", "how", "tower", "marks", "body", "climb", "this_climb", "train", "who", "why", "bye"]},
	# --- what to do ---------------------------------------------------------------------
	"next": {"ask": "What should I do next?", "fact": "next",
		"lines": ["{hint}"],
		"choices": ["next_more", "start", "bye"]},
	"next_more": {"ask": "Anything else?", "fact": "next_more",
		"lines": ["{hint}"],
		"choices": ["start", "bye"]},
	# --- how things work (the game's own rules; numbers from its tables) --------------------
	# A new topic: add a node here with "fact": "rules" (or none), and its id
	# to "how"'s choices.
	"how": {"ask": "How do things work here?",
		"lines": ["Which part? I'll keep it short.", "Ask. The rules are simpler than they look. Mostly."],
		"choices": ["how_essence", "how_marks", "how_new_mark", "how_renown", "how_fall", "how_belt", "how_wheel", "how_states", "how_handy", "how_charms", "how_bags", "how_ward", "how_secret", "how_bestiary", "how_rivals", "start", "bye"]},
	"how_essence": {"ask": "Essence, banking it, and tinctures?", "fact": "rules",
		"lines": ["Monsters, caches and finished tasks give essence. You carry it until a stair banks it, and a fall loses what you carry. At a stair it splits three ways: {body} to your body, {marks} to your marks, {condense} into crystals, the train's money."],
		"choices": ["how_flow", "how_tinctures", "how_marks", "how", "bye"]},
	"how_flow": {"ask": "How does essence flow?", "fact": "rules",
		"lines": ["Divided, never copied. Of what you bank at a stair, {body} soaks into your body, spread by what each part did: unmarked parts fill toward a new mark. {marks} goes to your marks, each kind to the marks of that kind; a kind none of them is made of spreads thinly over all. {condense} becomes crystals; To crystals, in Settings, sets that share, and body and marks share the rest. Eat a crystal and it flows the same way, without the crystals' share. Only a tincture lets you steer."],
		"choices": ["how_tinctures", "how_marks", "how", "bye"]},
	"how_tinctures": {"ask": "What are tinctures?", "fact": "rules",
		"lines": ["A vial of {tincture} essence of one kind. Drink it and you choose where it goes: one mark, where its own kind counts {own}x and any other {other}x, or one unmarked part, toward a new mark there. Vaults and secret rooms hold them, now and then a monster drops one, the outfitter stocks {store_kinds} each visit, and the Workshop crafts one from {craft} crystals of its kind."],
		"choices": ["how_flow", "how_new_mark", "how", "bye"]},
	"how_marks": {"ask": "How do marks grow?", "fact": "rules",
		"lines": ["Across climbs, never during one: from your marks' share of what you bank, {marks} of it. Each kind goes to the marks of that kind and counts {own}x; a kind none of them is made of counts {other}x, spread over all. The more marks you carry, the slower each grows. Each has {steps} steps, and each step brings a spell or makes one stronger. A tincture steers essence into one mark, and the Proving, on floor six, can raise one a step."],
		"choices": ["how_new_mark", "how", "bye"]},
	"how_new_mark": {"ask": "How do I earn a new mark?", "fact": "rules",
		"lines": ["Your body's share of what you bank soaks into your unmarked parts, by what each does, slower the more marks you carry. A part {full} full is ready. Reach a summit and the beast marks it. Or prove yourself sooner: break into a sealed wing on floor {early} or below, keep its rule and beat it, and the Maker of Marks may mark you there. Fall with a full part and there's a {fall_chance} chance it takes a faint mark anyway. One new mark a climb, at most. The first comes at the Regard; fall on that first climb and it's faint: {faint} more banked essence before it grows."],
		"choices": ["how_marks", "how_tinctures", "how", "bye"]},
	"how_renown": {"ask": "What is renown for?", "fact": "rules",
		"lines": ["Renown comes from climbs ({per_floor} a floor reached, {per_best} more for each floor past your best, {beast} a beast), and from drills, bouts and challenges at the stations. Ranks: {ranks}. Ranks open the outfitter's upgrades, the tournament's tiers, drills, challenges and boons. Boons themselves cost crystals, at a station's shrine."],
		"choices": ["how_fall", "how", "bye"]},
	"how_fall": {"ask": "What comes home: a fall, a recall, a summit?", "fact": "rules",
		"lines": ["A fall: your pack, what you wear and your belt are lost, unbanked essence too (a Keeper's Purse keeps itself and one piece), and {weapon} of the time the weapon in your hand. Never an heirloom, never the starting sword or bow. A recall scroll: you leave safe with what you wear and your pack, and unbanked essence becomes crystals. A summit: you may keep one piece as an heirloom, and what's left on your belt becomes crystals."],
		"choices": ["how_belt", "how", "bye"]},
	"how_belt": {"ask": "The belt?", "fact": "rules",
		"lines": ["Your belt holds {kinds} kinds of item, {stack} of each (a few stack otherwise; a Belt Pouch, a Climber's Pack or a Belt Hook charm adds a kind). Pick up a new kind with a full belt and you choose a stack to swap out. Most items come Minor, standard or Greater: the pips on the icon. Sizes share a stack, and a use takes the biggest first. What you buy or brew on the train goes on it, standard size."],
		"choices": ["how_wheel", "how_states", "how_fall", "how", "bye"]},
	"how_wheel": {"ask": "How does the belt wheel work?", "fact": "wheel",
		"lines": ["Tap {item} and you use your current item, the one beside your weapon. Hold {item} and the wheel opens, and the world slows to {slow} of its speed. Point at an item with {point} and let go: it becomes your current item. Nothing is used until you tap {item} again. A mark's button works the same way: hold it to choose a spell, tap it to cast. Choosing never uses anything. I find that restful."],
		"choices": ["how_belt", "how", "bye"]},
	"how_states": {"ask": "What are states, and how do I cure them?", "fact": "states",
		"lines": ["Some monsters' blows leave a state on you when they land: {states}. Each lasts a few seconds, and none of them stuns. The line at the top counts it down and names its cure. A Cleansing Tonic takes off any of them; {wards} keep one off for a while. The stair's rest clears them all."],
		"choices": ["how_handy", "how_belt", "how", "bye"]},
	"how_handy": {"ask": "What's handy in this tower?", "fact": "handy",
		"lines": ["{handy} They turn up more often there, and the outfitter's shelf says where each is handy."],
		"choices": ["how_states", "tower", "how", "bye"]},
	"how_charms": {"ask": "How do charms work?", "fact": "rules",
		"lines": ["You wear one charm, in its slot under the others. It's never used up: its gift is on while you wear it. Some hold a charge that fires by itself when its moment comes. Spent, it stays spent until you feed it essence: at the workshop bench with crystals of its kind, or in the tower from the inventory with essence you haven't banked. A Rune Artist crafts them; the outfitter sells {charm_shop}; vaults and secret rooms sometimes hold one."],
		"choices": ["how_bags", "how", "bye"]},
	"how_bags": {"ask": "How do bags work?", "fact": "rules",
		"lines": ["Your bag sets how many spare pieces your pack holds: {bag_none} with none, {bag_sizes}. Small bags never slow you. A big one does once it's nearly full, {heavy_at} of its spaces or more, and the pack's heading says \"heavy\". Lighten it and you're quick again."],
		"choices": ["how_charms", "how", "bye"]},
	"how_ward": {"ask": "Why won't the stair open?",
		"lines": ["Most floors have one task, and the stair is warded until it's done: braziers, levers, runes, an orb, a puzzle. The banner names it, a line under it counts it, and an arrow points at what's left. Done, the stair opens, and a reliquary beside it offers one of three."],
		"choices": ["how_secret", "how", "bye"]},
	"how_secret": {"ask": "Cracked walls and secret rooms?",
		"lines": ["Dust falls from a cracked wall. A finishing blow breaks it: a way through, hidden essence, sometimes a vault. A secret room hides behind plain wall: lean into the wall and it opens. Flare Powder and the Scroll of Seeing make secret walls glint."],
		"choices": ["how_ward", "how", "bye"]},
	"how_bestiary": {"ask": "What is the Bestiary?", "fact": "rules",
		"lines": ["My notes on every monster, in the Library. An entry starts when you see one and grows when you fight it. Slay it {bestiary_slain} times and it adds its health, then what it's weak to, then how it takes states. A beast takes {bestiary_beast}."],
		"choices": ["how_secret", "how", "bye"]},
	"how_rivals": {"ask": "Who are the other climbers?", "fact": "rivals",
		"lines": ["Climbers like you, with marks of their own. From floor {rival_from}, about {rival_chance} of floors hold one, {rival_per} a climb. Each wants one thing: a trade, a duel for the floor, company to the stair. Some lie hurt beside a hoard. {rival_met}"],
		"choices": ["how_rivals_more", "how", "bye"]},
	"how_rivals_more": {"ask": "What do I get from them?", "fact": "rivals",
		"lines": ["A duel can't kill you: lose and they take a toll, win and the stair's ward lifts. Teamed up, you keep {rival_share} of what you gather, but their marks react with yours. Help the hurt and they remember; rob them and so do they. The Renown Board keeps them all."],
		"choices": ["how_rivals", "how", "bye"]},
	# --- the tower ----------------------------------------------------------------------
	"tower": {"ask": "What is {tower} like?", "fact": "tower",
		"lines": ["{blurb} Its essence is {essence}. {best_line}"],
		"choices": ["tower_beast", "tower_hazards", "how_handy", "start", "bye"]},
	"tower_beast": {"ask": "And its beast?", "fact": "tower",
		"lines": ["{Beast} waits at the top. {beast_hint} {slain_line}"],
		"choices": ["tower_hazards", "start", "bye"]},
	"tower_hazards": {"ask": "What should I watch for there?", "fact": "hazards",
		"lines": ["{hazards}"],
		"choices": ["tower_beast", "start", "bye"]},
	# --- marks ----------------------------------------------------------------------------
	"marks": {"ask": "What do my marks do?", "if": "marked", "fact": "marks",
		"lines": ["As I have them. {marks}"],
		"choices": ["marks_grow", "marks_new", "start", "bye"]},
	"marks_grow": {"ask": "How do marks grow?", "fact": "money",
		"lines": ["From essence you bank at a stair, never in the middle of a climb: {marks} of it goes to your marks, each kind to the marks of that kind. {condense} becomes crystals: To crystals, in Settings. A tincture puts its essence into the one mark you choose."],
		"choices": ["marks_new", "start", "bye"]},
	"marks_new": {"ask": "Will I get another mark?", "fact": "soak",
		"lines": ["{soak}"],
		"choices": ["marks_grow", "start", "bye"]},
	"body": {"ask": "What about my body?", "if": "unbound",
		"lines": ["You carry no marks. You refused them. Your techniques sit on the mark buttons, and the Techniques page changes them."],
		"choices": ["start", "bye"]},
	# --- the climb ------------------------------------------------------------------------
	"climb": {"ask": "How did my last climb go?", "if": "climbed", "fact": "climb",
		"lines": ["{summary}"],
		"choices": ["climb_log", "start", "bye"]},
	"this_climb": {"ask": "How is this climb going?", "if": "in_play", "fact": "climb",
		"lines": ["{summary}"],
		"choices": ["climb_log", "start", "bye"]},
	"climb_log": {"ask": "What happened last?", "if": "logged", "fact": "climb",
		"lines": ["Newest first. {events}"],
		"choices": ["start", "bye"]},
	# --- the train ------------------------------------------------------------------------
	"train": {"ask": "Tell me about the train.", "if": "on_train",
		"lines": ["Six cars. The Engine takes you to a tower. The outfitter buys and sells. Your car holds what you'll wear, your pack and your stash. The Workshop works on gear, the Library keeps my words, and the last car holds the settings."],
		"choices": ["train_money", "train_carry", "start", "bye"]},
	"train_money": {"ask": "How do I pay for things?", "fact": "money",
		"lines": ["Crystals. You hold {crystals} essence in them. {condense} of what you bank at a stair condenses into them, and the outfitter pays for every climb, fall or not. Spend them, craft tinctures from them, or eat them: your book's Crystals and tinctures."],
		"choices": ["train_carry", "start", "bye"]},
	"train_carry": {"ask": "What goes up the tower with me?",
		"lines": ["What you wear, your pack and your belt. The stash never leaves the train. A fall takes your pack and your belt, and sometimes the weapon in your hand. Never an heirloom."],
		"choices": ["train_money", "start", "bye"]},
	# --- story slots: the owner's to write (hidden while they say STORY_TAG) ----------------
	"who": {"ask": "Who are you?",
		"lines": ["[Yours to write] The Entity's answer to \"Who are you?\". Write it over this line, here or in the Data editor."],
		"choices": ["start", "bye"]},
	"why": {"ask": "What are the towers for?",
		"lines": ["[Yours to write] The Entity's answer to \"What are the towers for?\". Write it over this line, here or in the Data editor."],
		"choices": ["start", "bye"]},
	# --- leaving --------------------------------------------------------------------------
	"bye": {"ask": "Goodbye.", "leave": true},
}

## Hints for "What should I do next?", in the order they're thought of: the
## first that applies is said, the next one if you ask again. {blanks} as
## the hint needs.
static var HINTS := {
	"unbanked": "You carry {amount} unbanked essence. Find the stair before something finds you.",
	"low_health": "You're low. A draught, a spring, or the stair.",
	"faint": "Your mark is faint. It needs {amount} more banked essence before it grows.",
	"mark_ready": "Your {part} is full of essence. Reach a summit and it takes a mark, or win a sealed wing early keeping its rule.",
	"better_stash": "Something you keep beats what you'd wear: {piece}. The Loadout puts it on.",
	"belt_empty": "Your belt is empty. The outfitter sells draughts. The Workshop brews them cheaper.",
	"afford_rack": "You can afford {piece} on the outfitter's rack, and it beats yours.",
	"stash_full": "Your stash is full. Sell to the outfitter, or break pieces down at the Workshop.",
	"boon": "You could buy {boon} at a station's Boon Shrine. It goes with you on every climb.",
	"mark_close": "{mark} is {pct}% of the way to step {step}. Bank its essence at a stair.",
	"climb": "Choose a tower at the Engine and pull the lever. Your best: floor {best}, in {tower}.",
	"climb_play": "Up. The stair is somewhere on this floor.",
	"none": "Nothing else. Climb.",
}

## The rest of its words in a talk.
static var TEXT := {
	"more": "Something else...",
	"rivals_none": "You haven't met one yet.",
	"rivals_met": "You've met %d. The last was %s.",
	"leave_key": "%s to leave",
	"more_line": "There's more. Pick one.",
	"back": "Back.",
	"best": "Your best there: floor %d.",
	"best_none": "You haven't climbed it yet.",
	"slain": "You've felled it %s.",
	"slain_none": "You haven't felled it yet.",
	"once": "once",
	"times": "%d times",
	"mark": "{mark} on your {part}, step {step}: {body}.",
	"mark_next": "It's {pct}% of the way to step {next}{brings}.",
	"mark_brings": ", which brings {spell}",
	"mark_top": "It has grown as far as it goes.",
	"mark_faint": "It's faint: {debt} more banked essence before it grows.",
	"soak_part": "Your {part} is {pct}% full. When a part is full, a summit can mark it, or a sealed wing won early. One new mark a climb, at most.",
	"soak_ready": "Your {part} is full. Reach a summit and it takes a mark, or win a sealed wing early keeping its rule.",
	"soak_none": "Every part already carries a mark.",
	"soak_empty": "Not yet. Your body's share of what you bank soaks into your unmarked parts. A full one can be marked at a summit.",
	"summary": "{Tower}: you reached floor {floor}. {gathered}{finds}{banked}{pay}",
	"gathered": "{n} essence gathered. ",
	"finds": "{n} finds. ",
	"banked": "Banked at {n} stairs. ",
	"pay": "The outfitter paid {pay}.",
	"summary_none": "Your last climb was in {tower}. I kept the count, not the details. {best_line}",
	"summary_empty": "Nothing yet. Do something.",
	"events_none": "Nothing worth writing down.",
	"hazards_none": "Nothing I'd warn you about.",
}


# --- a conversation ---------------------------------------------------------------------

var node := "start"
var line := ""  # what the Entity is saying (kept while the page rebuilds)
var offset := 0  # how far down the choices we've paged ("Something else")
var said := 0  # lines said (tests)


## Starts again at the first question.
func begin(main) -> void:
	node = "start"
	offset = 0
	say(main)


## Picks the Entity's line for the node it's at.
func say(main) -> void:
	line = line_for(main, node)
	said += 1


## The Entity's line for a node, filled in.
static func line_for(main, id: String) -> String:
	var n: Dictionary = DIALOGUE.get(id, {})
	var lines: Array = spoken(n)
	if lines.is_empty():
		return ""
	var text := String(lines[randi() % lines.size()])
	return fill(text, facts(main, n))


## A node's lines a player may hear (story slots not written yet are left out).
static func spoken(n: Dictionary) -> Array:
	return Array(n.get("lines", [])).filter(func(l): return String(l).strip_edges() != "" and not String(l).begins_with(STORY_TAG))


## The fills for a node: its fact, and the words of the moment.
static func facts(main, n: Dictionary) -> Dictionary:
	var f := {}
	var fact := String(n.get("fact", ""))
	match fact:
		"tower":
			f = _fact_tower(main)
		"hazards":
			f = _fact_hazards(main)
		"marks":
			f = _fact_marks(main)
		"soak":
			f = _fact_soak(main)
		"money":
			f = _fact_money(main)
		"next":
			f = _fact_next(main)
		"next_more":
			f = _fact_next_more(main)
		"climb":
			f = _fact_climb(main)
		"rules":
			f = _fact_rules()
		"wheel":
			f = _fact_wheel(main)
		"states":
			f = _fact_states()
		"handy":
			f = _fact_handy(main)
		"rivals":
			f = _fact_rivals(main)
	if main != null:
		f["floor"] = f.get("floor", main.get("floor_num"))
	return f


static func fill(text: String, f: Dictionary) -> String:
	text = Entity.fill_words(text, f)
	var re := RegEx.create_from_string("\\{[A-Za-z_]+\\}")
	text = re.sub(text, "", true)
	while text.contains("  "):
		text = text.replace("  ", " ")
	return text.replace(" .", ".").strip_edges()


## True if a choice to this node shows now: its condition holds and it has
## something to say (or it leaves).
static func shows(main, id: String) -> bool:
	var n: Dictionary = DIALOGUE.get(id, {})
	if n.is_empty():
		return false
	var cond := String(n.get("if", ""))
	if cond != "" and not check(main, cond):
		return false
	return bool(n.get("leave", false)) or not spoken(n).is_empty()


## The choices showing now: [{id, ask}], paged (at most MAX_CHOICES).
func choices(main) -> Array:
	var n: Dictionary = DIALOGUE.get(node, {})
	var topics: Array = []
	var leaves: Array = []
	for id in n.get("choices", []):
		id = String(id)
		if id == node or not shows(main, id):
			continue
		var c := {"id": id, "ask": fill(String(DIALOGUE[id].get("ask", id)), facts(main, DIALOGUE[id]) if String(DIALOGUE[id].get("ask", "")).contains("{") else {})}
		(leaves if bool(DIALOGUE[id].get("leave", false)) else topics).append(c)
	var room := MAX_CHOICES - leaves.size()
	var out: Array = []
	if offset > 0:
		room -= 1
	if topics.size() - offset > room:
		out = topics.slice(offset, offset + room - 1)
		out.append({"id": "+more", "ask": String(TEXT["more"])})
	else:
		out = topics.slice(offset)
	if offset > 0:
		out.append({"id": "+back", "ask": String(TEXT["back"])})
	return out + leaves


## Chooses one of the choices showing. False if it ends the talk.
func choose(main, i: int) -> bool:
	var list := choices(main)
	if i < 0 or i >= list.size():
		return true
	var id := String(list[i]["id"])
	match id:
		"+more":
			offset += list.filter(func(c): return not String(c["id"]).begins_with("+") and not bool(DIALOGUE.get(c["id"], {}).get("leave", false))).size()
			line = String(TEXT["more_line"])
			return true
		"+back":
			offset = 0
			say(main)
			return true
	if bool(DIALOGUE.get(id, {}).get("leave", false)):
		return false
	node = id
	offset = 0
	say(main)
	return true


# --- conditions ---------------------------------------------------------------------------

static func check(main, cond: String) -> bool:
	if main == null:
		return false
	var prof = main.profile
	match cond:
		"on_train":
			return bool(main.on_train)
		"in_play":
			return not bool(main.on_train)
		"marked":
			return prof != null and not prof.bonds.is_empty() and not Unbound.is_on(prof)
		"unbound":
			return prof != null and Unbound.is_on(prof)
		"climbed":
			return bool(main.on_train) and prof != null and prof.climbs > 0
		"logged":
			return not _log(main).is_empty()
	return true


# --- facts: the game as it is now -----------------------------------------------------------

## The tower talked about: the one you're in, or on the train the one chosen
## at the engine (else the last one climbed).
static func tower_id(main) -> String:
	if main == null:
		return Towers.ORDER[0]
	if not bool(main.on_train) and Towers.TOWERS.has(String(main.tower)):
		return String(main.tower)
	var m = main.get("menu")
	if m != null and Towers.TOWERS.has(String(m.train_tower)):
		return String(m.train_tower)
	var prof = main.profile
	return String(prof.last_tower) if prof != null and Towers.TOWERS.has(String(prof.last_tower)) else Towers.ORDER[0]


## "The Kraken's Tower" said mid-sentence: "the Kraken's Tower" ({Tower}
## puts the capital back).
static func _the(name: String) -> String:
	return "the" + name.substr(3) if name.begins_with("The ") else name


static func _best(main, id: String) -> int:
	var prof = main.profile if main != null else null
	return int(prof.record.get("best", {}).get(id, 0)) if prof != null else 0


static func _fact_tower(main) -> Dictionary:
	var id := tower_id(main)
	var t: Dictionary = Towers.TOWERS.get(id, {})
	var best := _best(main, id)
	var prof = main.profile if main != null else null
	var slain := int(prof.record.get("beasts_by", {}).get(id, 0)) if prof != null else 0
	return {
		"tower": _the(String(t.get("name", id))),
		"blurb": String(t.get("blurb", "")),
		"essence": Essence.display(String(t.get("essence", ""))),
		"beast": String(t.get("beast", "")),
		"beast_hint": String(t.get("beast_hint", "")),
		"best_line": String(TEXT["best"]) % best if best > 0 else String(TEXT["best_none"]),
		"slain_line": String(TEXT["slain_none"]) if slain <= 0 else String(TEXT["slain"]) % (String(TEXT["once"]) if slain == 1 else String(TEXT["times"]) % slain),
	}


## What to watch for in the tower: its own tidbits (entity_notes.gd), the
## tower's line and one of each of its systems, at most three.
static func _fact_hazards(main) -> Dictionary:
	var id := tower_id(main)
	var f := _fact_tower(main)
	var said: Array = []
	for k in Notes.arrival_keys(id):
		var lines: Array = Notes.lines(String(k))
		if not lines.is_empty():
			said.append(String(lines[0]))
		if said.size() >= 3:
			break
	f["hazards"] = " ".join(said) if not said.is_empty() else String(TEXT["hazards_none"])
	return f


## Your marks: each one's name, part, step, its body gift, and its next step.
static func _fact_marks(main) -> Dictionary:
	var prof = main.profile if main != null else null
	if prof == null:
		return {}
	var parts: Array = []
	for part in Bonds.PART_NAMES:
		if not prof.bonds.has(part):
			continue
		var info: Dictionary = prof.bonds[part]
		var bd: Dictionary = Bonds.BONDS.get(String(info.get("id", "")), {})
		if bd.is_empty():
			continue
		var xp := float(info.get("xp", 0.0))
		var step := ProfileScript.step_for_xp(xp)
		var body: Dictionary = bd.get("body", {})
		var s := fill(String(TEXT["mark"]), {"mark": bd.get("name", ""), "part": String(Bonds.PART_NAMES[part]).to_lower(), "step": step,
			"body": "%s, %s" % [body.get("name", ""), body.get("desc", "")] if not body.is_empty() else ""})
		if bool(info.get("faint", false)) and float(info.get("debt", 0.0)) > 0.0:
			s += " " + fill(String(TEXT["mark_faint"]), {"debt": int(ceil(float(info["debt"])))})
		elif step >= ProfileScript.STEP_XP.size():
			s += " " + String(TEXT["mark_top"])
		else:
			var lo: float = ProfileScript.STEP_XP[step - 1]
			var hi: float = ProfileScript.STEP_XP[step]
			var pct := clampi(int(floor((xp - lo) / maxf(hi - lo, 1.0) * 100.0)), 0, 99)
			var spell := ""
			for sp in bd.get("spells", []):
				if int(sp.get("learn", 0)) == step + 1:
					spell = String(sp.get("name", ""))
			var brings := fill(String(TEXT["mark_brings"]), {"spell": spell}) if spell != "" else ""
			s += " " + fill(String(TEXT["mark_next"]), {"next": step + 1, "pct": pct, "brings": brings})
		parts.append(s)
	return {"marks": " ".join(parts)}


## How near an unmarked part is to taking a mark.
static func _fact_soak(main) -> Dictionary:
	var prof = main.profile if main != null else null
	if prof == null:
		return {}
	if prof.bonds.size() >= Bonds.PART_NAMES.size():
		return {"soak": String(TEXT["soak_none"])}
	var ready: String = prof.ready_for_mark()
	if ready != "":
		return {"soak": fill(String(TEXT["soak_ready"]), {"part": String(Bonds.PART_NAMES.get(ready, ready)).to_lower()})}
	var best := ""
	var most := 0.0
	for part in prof.soak:
		if prof.bonds.has(part):
			continue
		if float(prof.soak[part]) > most:
			most = float(prof.soak[part])
			best = String(part)
	if best == "":
		return {"soak": String(TEXT["soak_empty"])}
	var need: float = ProfileScript.NEW_MARK_SOAK * ProfileScript.MARK_FULL
	return {"soak": fill(String(TEXT["soak_part"]), {"part": String(Bonds.PART_NAMES.get(best, best)).to_lower(), "pct": clampi(int(most / maxf(need, 1.0) * 100.0), 0, 99)})}


## Money: your crystals and the share that condenses at a stair.
static func _fact_money(main) -> Dictionary:
	var prof = main.profile if main != null else null
	var M = load("res://scripts/menu.gd")
	var share := Train.condense_share(M.settings)
	var sh: Dictionary = Flow.shares(share)
	return {"crystals": int(prof.crystals_held()) if prof != null else 0, "condense": "%d%%" % int(round(share * 100.0)),
		"body": "%d%%" % int(round(float(sh["body"]) * 100.0)), "marks": "%d%%" % int(round(float(sh["marks"]) * 100.0))}


## The climber's states (reactions.gd CLIMBER) and their cures (items.gd
## "cures", "ward"), read from the tables: "poison from scorplings and the
## Manticore (Antivenom or Cleansing Tonic)".
static func _fact_states() -> Dictionary:
	var R = load("res://scripts/reactions.gd")
	var Items = load("res://scripts/items.gd")
	var Enemy = load("res://scripts/enemy.gd")
	var by := {}
	for kind in R.CLIMBER.get("from", {}):
		var st := String(R.CLIMBER["from"][kind])
		if not by.has(st):
			by[st] = []
		by[st].append(_foe_name(Enemy, String(kind)))
	var parts: Array = []
	for st in R.STATES:
		if not by.has(st):
			continue
		var cure: String = R.cure_names(st)
		parts.append("%s from %s (%s)" % [String(R.STATES[st]["name"]).to_lower(), _and_words(by[st]), cure])
	var wards: Array = []
	for id in Items.ORDER:
		if not Array(Items.ITEMS[id].get("ward", [])).is_empty():
			wards.append(String(Items.ITEMS[id]["name"]))
	return {"states": "; ".join(parts), "wards": _and_words(wards)}


## A monster's name for a sentence: "scorplings", "the Manticore".
static func _foe_name(Enemy, kind: String) -> String:
	if kind in Enemy.BOSSES:
		return "the " + kind.capitalize()
	return kind + "s"


static func _and_words(list: Array) -> String:
	var s: Array = list.map(func(x): return String(x))
	if s.size() < 2:
		return "".join(s)
	return ", ".join(s.slice(0, s.size() - 1)) + " and " + String(s[-1])


## What's handy in the tower talked about (tower_needs.gd), with why.
static func _fact_handy(main) -> Dictionary:
	var Needs = load("res://scripts/tower_needs.gd")
	var Items = load("res://scripts/items.gd")
	var id := tower_id(main)
	var f := _fact_tower(main)
	var bits: Array = []
	for item in Needs.handy(id):
		if Items.ITEMS.has(item):
			bits.append("%s: %s" % [String(Items.ITEMS[item]["name"]), Needs.why(id, item)])
	f["handy"] = String(Needs.TEXT["talk"]) % [f["tower"], "; ".join(bits)] if not bits.is_empty() else String(Needs.TEXT["none"])
	return f


## The game's rules in numbers, read from its own tables (for "How do things work here?").
static func _fact_rules() -> Dictionary:
	var R = load("res://scripts/renown.gd")
	var Lost = load("res://scripts/lost.gd")
	var Items = load("res://scripts/items.gd")
	var ranks: Array = []
	for r in R.RANKS:
		if int(r[2]) > 0:
			ranks.append("%s at %d" % [r[1], int(r[2])])
	var f := _fact_money(null)
	f.merge({
		"own": _num(ProfileScript.AFFINITY_WEIGHT), "other": _num(ProfileScript.OTHER_WEIGHT), "steps": ProfileScript.STEP_XP.size(),
		"full": "%d%%" % int(round(ProfileScript.MARK_FULL * 100.0)), "faint": int(ProfileScript.FAINT_DEBT),
		"per_floor": int(R.CLIMB.get("floor", 0)), "per_best": int(R.CLIMB.get("best", 0)), "beast": int(R.CLIMB.get("beast", 0)),
		"ranks": ", ".join(ranks), "weapon": "%d%%" % int(round(float(Lost.WEAPON_CHANCE) * 100.0)),
		"kinds": Items.BELT_KINDS, "stack": Items.MAX_STACK,
		"tincture": int(Flow.TINCTURE["essence"]), "craft": int(Flow.TINCTURE["craft"]), "store_kinds": "one kind" if int(Flow.TINCTURE["store_kinds"]) == 1 else "%d kinds" % int(Flow.TINCTURE["store_kinds"]),
		"early": int(Flow.EARNED["last_floor"]), "fall_chance": "%d%%" % int(round(float(Flow.FALL_MARK["chance"]) * 100.0)),
	})
	# Charms and bags (charms.gd, gear.gd BAG): from their tables.
	var Charms = load("res://scripts/charms.gd")
	var n := int(Charms.SHOP["rack"])
	f["charm_shop"] = ("one on his rail" if n == 1 else "%d on his rail" % n)
	f["bag_none"] = int(Gear.BAG["none"])
	var sizes: Array = []
	for id in ["satchel", "pack", "great_pack"]:
		if Gear.PIECES.has(id):
			sizes.append("a %s %d" % [Gear.PIECES[id]["name"], int(Gear.PIECES[id].get("bag", 0))])
	f["bag_sizes"] = ", ".join(sizes)
	f["heavy_at"] = "%d%%" % int(round(float(Gear.BAG["heavy_at"]) * 100.0))
	var Best = load("res://scripts/bestiary.gd")
	f["bestiary_slain"] = _and(Best.TIERS.get("slain", []))
	f["bestiary_beast"] = _and(Best.TIERS.get("beast", []))
	return f


## The other climbers: how often, and who you've met.
static func _fact_rivals(main) -> Dictionary:
	var Rv = load("res://scripts/rivals.gd")
	var met: Array = Rv.met_list(main.profile) if main != null and main.profile != null else []
	var per := int(Rv.RULES["per_climb"])
	var f := {"rival_from": int(Rv.RULES["from"]), "rival_chance": "%d%%" % int(round(float(Rv.RULES["chance"]) * 100.0)),
		"rival_per": "once" if per == 1 else "%d times" % per, "rival_share": "%d%%" % int(round(float(Rv.RULES["team_share"]) * 100.0))}
	f["rival_met"] = String(TEXT.get("rivals_none", "")) if met.is_empty() else String(TEXT.get("rivals_met", "")) % [met.size(), String(met[0].get("name", ""))]
	return f


## The wheels (wheel.gd): how slow the world goes, and the buttons in use.
static func _fact_wheel(main) -> Dictionary:
	var Wheel = load("res://scripts/wheel.gd")
	var mode := "keys"
	if main != null and bool(main.get("touch_active")):
		mode = "touch"
	elif main != null and bool(main.get("pad_active")):
		mode = "pad"
	var ps: bool = main != null and bool(main.get("pad_ps"))
	var point: String = String(Wheel.TEXT.get("point_" + mode, ""))
	return {"slow": "%d%%" % int(round(Wheel.slow() * 100.0)), "item": Entity.fill_keys("{item}", mode, ps), "point": point}


## [1, 5, 15] -> "1, 5 and 15".
static func _and(list: Array) -> String:
	var s: Array = list.map(func(x): return str(int(x)))
	if s.size() < 2:
		return "".join(s)
	return ", ".join(s.slice(0, s.size() - 1)) + " and " + String(s[-1])


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.01))


## What to do next: every hint that applies now, best first.
static func hints(main) -> Array:
	var out: Array = []
	if main == null or main.profile == null:
		return out
	var prof = main.profile
	var p = main.player
	if not bool(main.on_train):
		var carried := 0.0
		for k in main.run_essence:
			carried += float(main.run_essence[k])
		if carried >= 1.0:
			out.append(fill(String(HINTS["unbanked"]), {"amount": int(carried)}))
		if p != null and p.hp < p.max_hp * 0.35:
			out.append(String(HINTS["low_health"]))
	for part in prof.bonds:
		var info: Dictionary = prof.bonds[part]
		if bool(info.get("faint", false)) and float(info.get("debt", 0.0)) > 0.0:
			out.append(fill(String(HINTS["faint"]), {"amount": int(ceil(float(info["debt"])))}))
			break
	var ready: String = prof.ready_for_mark()
	if ready != "":
		out.append(fill(String(HINTS["mark_ready"]), {"part": String(Bonds.PART_NAMES.get(ready, ready)).to_lower()}))
	if bool(main.on_train):
		# Something kept that beats what you'd wear.
		var best_g = null
		var best_v := 0
		for list in [prof.pack, prof.chest]:
			for g in list:
				var vs := Train.versus(prof, p, g)
				if vs > best_v:
					best_v = vs
					best_g = g
		if best_g != null:
			out.append(fill(String(HINTS["better_stash"]), {"piece": Gear.display(best_g)}))
		if prof.supplies.is_empty():
			out.append(String(HINTS["belt_empty"]))
		for g in Train.outfit(prof) + [Train.today(prof)]:
			if Gear.is_gear(g) and Train.versus(prof, p, g) > 0 and Train.short_of(prof, Train.gear_kind(g), Train.buy_price(prof, g)) == "":
				out.append(fill(String(HINTS["afford_rack"]), {"piece": Gear.display(g)}))
				break
		if prof.chest.size() >= Train.CHEST_SIZE:
			out.append(String(HINTS["stash_full"]))
		for id in Boons.BOONS:
			if Boons.why_not(prof, String(id)) == "":
				out.append(fill(String(HINTS["boon"]), {"boon": String(Boons.BOONS[id]["name"])}))
				break
	# The mark nearest its next step.
	var close := {}
	for part in prof.bonds:
		var info: Dictionary = prof.bonds[part]
		var xp := float(info.get("xp", 0.0))
		var step := ProfileScript.step_for_xp(xp)
		if step >= ProfileScript.STEP_XP.size():
			continue
		var lo: float = ProfileScript.STEP_XP[step - 1]
		var hi: float = ProfileScript.STEP_XP[step]
		var pct := int(floor((xp - lo) / maxf(hi - lo, 1.0) * 100.0))
		if pct >= 50 and pct > int(close.get("pct", -1)):
			close = {"mark": Bonds.BONDS.get(String(info.get("id", "")), {}).get("name", ""), "pct": pct, "step": step + 1}
	if not close.is_empty():
		out.append(fill(String(HINTS["mark_close"]), close))
	if bool(main.on_train):
		var id := tower_id(main)
		var best := _best(main, id)
		out.append(fill(String(HINTS["climb"]), {"best": maxi(best, 1), "tower": _the(String(Towers.TOWERS.get(id, {}).get("name", id)))}))
	else:
		out.append(String(HINTS["climb_play"]))
	return out


static func _fact_next(main) -> Dictionary:
	var h := hints(main)
	return {"hint": String(h[0]) if not h.is_empty() else String(HINTS["none"])}


static func _fact_next_more(main) -> Dictionary:
	var h := hints(main)
	return {"hint": String(h[1]) if h.size() > 1 else String(HINTS["none"])}


## The climb's events (notices.gd): this climb's in play; on the train the
## last climb's, kept after it ended.
static func _log(main) -> Array:
	if main == null:
		return []
	if not bool(main.on_train) and main.get("notices") != null:
		return main.notices.log
	return Array(Notices.climb_log.get("log", []))


static func _fact_climb(main) -> Dictionary:
	var prof = main.profile if main != null else null
	var log := _log(main)
	var in_play := main != null and not bool(main.on_train)
	var id := String(main.tower) if in_play else String(Notices.climb_log.get("tower", ""))
	if id == "" and prof != null:
		id = String(prof.last_tower)
	var t: Dictionary = Towers.TOWERS.get(id, {})
	var f := {"tower": _the(String(t.get("name", id)))}
	var best := _best(main, id)
	f["best_line"] = String(TEXT["best"]) % best if best > 0 else ""
	# The newest few, for "What happened last?".
	var recent: Array = []
	for i in range(log.size() - 1, maxi(-1, log.size() - 5), -1):
		recent.append(Notices.log_text(log[i]))
	f["events"] = ". ".join(recent) + "." if not recent.is_empty() else String(TEXT["events_none"])
	if log.is_empty():
		f["summary"] = fill(String(TEXT["summary_empty"] if in_play else TEXT["summary_none"]), f)
		return f
	var floor_n := 0
	var gathered := 0
	var finds := 0
	var banked := 0
	var num := RegEx.create_from_string("\\d+")
	for e in log:
		floor_n = maxi(floor_n, int(e.get("floor", 0)))
		match String(e.get("kind", "")):
			"essence":
				var mm := num.search(String(e.get("text", "")))
				if mm != null:
					gathered += int(mm.get_string())
			"gear", "item", "crystal", "key":
				finds += int(e.get("n", 1))
			"banked":
				banked += int(e.get("n", 1))
	if in_play:
		floor_n = maxi(floor_n, int(main.floor_num))
	var pay := ""
	if not in_play and prof != null and not prof.last_pay.is_empty():
		pay = Train.price_text(String(prof.last_pay.get("kind", "")), int(prof.last_pay.get("amount", 0)))
	f["floor"] = floor_n
	f["summary"] = fill(String(TEXT["summary"]), {"tower": f["tower"], "floor": floor_n,
		"gathered": fill(String(TEXT["gathered"]), {"n": gathered}) + " " if gathered > 0 else "",
		"finds": fill(String(TEXT["finds"]), {"n": finds}) + " " if finds > 0 else "",
		"banked": fill(String(TEXT["banked"]), {"n": banked}) + " " if banked > 0 else "",
		"pay": fill(String(TEXT["pay"]), {"pay": pay}) if pay != "" else ""})
	return f
