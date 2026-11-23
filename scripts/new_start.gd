extends RefCounted
## A new climber's start: everything between pressing New Climber and the
## first step into a tower, as data the owner can rewrite.
##
##   1. The introduction (start_pages.gd "intro"): a black screen where the
##      Entity speaks INTRO, one idea a line. Skippable once any climber has
##      been made on this device (the settings file's "start" section, `made`).
##   2. Character creation: the name and pronouns (start_pages.gd "create_name"),
##      then the look (appearance_page.gd "create").
##   3. The questionnaire (start_pages.gd "quiz"): QUESTIONS, three of them.
##      apply() gives the answers' results: the starting weapon and armour
##      (kept as heirlooms, so every climb begins with them), the home tower
##      (profile.home: the starting tower and, with the stations, the home
##      station), crystals, a starting title, a contract, and how hard the
##      start is. No question leans toward the Bonded or the Unbound.
##
## Also here: the one-time clearing of climbers made before this new start
## (clear_old_once), with a notice on the title screen explaining why.
##
## TEXT marked PLACEHOLDER is the owner's to rewrite: the story and the
## purpose of the towers are still to be written.

const Slots := preload("res://scripts/slots.gd")
const Gear := preload("res://scripts/gear.gd")
const Towers := preload("res://scripts/towers.gd")
const Renown := preload("res://scripts/renown.gd")
const Pronouns := preload("res://scripts/pronouns.gd")

## The introduction: what the Entity says on the black screen, in order, one
## idea a line. [what it covers (for the owner), the line]. PLACEHOLDER lines.
static var INTRO := [
	["The train and the towers",
		"[Placeholder] Six towers stand at the edges of the world, and a single train runs between them. You are on it now; you remember boarding, and the conductor's nod as the doors closed."],
	["Why the towers exist",
		"[Placeholder] The towers were raised for a purpose no one agrees on. They test whoever climbs them, and they keep what they learn."],
	["What marks are",
		"[Placeholder] Climb, and the tower takes notice. It leaves a mark on the part of you that served you best, and the mark grows into a bond with power in it."],
	["Those who refuse the mark",
		"[Placeholder] Some refuse the mark. They take essence into their bodies raw and shape it themselves, with no bond to guide it."],
	["What each path costs and offers",
		"[Placeholder] A mark is steady, and it chooses for you. The raw way is freer and slower, and the towers do not love it. Both ask for everything in the end."],
	["The core essences",
		"[Placeholder] Beneath every essence are two: Making and Unmaking, the Makers' own. All the rest comes from them. Remember that, when you meet them."],
]

## The questions, in order. Each: "id", "ask" (the Entity's question), and
## "answers": [{"id", "name", "help" (what it gives, for the button's help
## and the summary)}]. The home question's answers are the six towers.
static var QUESTIONS := [
	{"id": "past", "ask": "What did you do before choosing to become a climber?",
		"answers": [
			{"id": "soldier", "name": "Soldier", "help": "You start with a sword and chain armour."},
			{"id": "hunter", "name": "Hunter", "help": "You start with a shortbow, a dagger and leather armour."},
			{"id": "labourer", "name": "Labourer", "help": "You start with a war hammer and padded armour."},
			{"id": "beggar", "name": "Beggar", "help": "You start with a dagger and no armour."},
			{"id": "scholar", "name": "Scholar", "help": "You start with a sword cane and padded armour."},
			{"id": "sailor", "name": "Sailor", "help": "You start with a flintlock pistol and leather armour (and the usual sword)."},
		]},
	{"id": "home", "ask": "Where did you grow up?",
		"answers": []},  # (filled from the towers: home_answers)
	{"id": "why", "ask": "What made you choose to become a climber?",
		"answers": [
			{"id": "born", "name": "Born into it", "help": "The easiest start: fine gear, 30 crystals and your family's title."},
			{"id": "hired", "name": "Hired by someone", "help": "A middle start: common gear, 15 crystals, a title from your employer and a contract from the Noble already in hand."},
			{"id": "self", "name": "Self made", "help": "The hardest start: worn gear, no crystals and no title, but renown comes a quarter faster until your first title."},
		]},
]

## What each answer gives. Weapons are weapons.gd ids, armour gear.gd ARMOR ids
## ("" for none). Every climb also starts with the shortbow (gear.gd
## start_gear) unless a ranged weapon is given here, and the sword unless a
## melee weapon is (the Sailor keeps the sword beside the flintlock).
static var PAST := {
	"soldier": {"melee": "sword", "ranged": "", "armor": "chain"},
	"hunter": {"melee": "dagger", "ranged": "shortbow", "armor": "leather"},
	"labourer": {"melee": "war_hammer", "ranged": "", "armor": "padded"},
	"beggar": {"melee": "dagger", "ranged": "", "armor": ""},
	"scholar": {"melee": "sword_cane", "ranged": "", "armor": "padded"},
	"sailor": {"melee": "", "ranged": "flintlock", "armor": "leather"},
}

## How you came to climb: the gear's quality ("fine", "common", or "worn":
## common and worn down to `wear` until the Regard), crystals (of your home
## tower's kind), the title worn from the start (renown.gd TITLES; "" for
## none), a contract from the Noble in hand, and renown faster until your
## first title (0.25 = a quarter more).
static var WHY := {
	"born": {"quality": "fine", "crystals": 30, "title": "family", "contract": false, "renown_boost": 0.0},
	"hired": {"quality": "common", "crystals": 15, "title": "hired", "contract": true, "renown_boost": 0.0},
	"self": {"quality": "worn", "crystals": 0, "title": "", "contract": false, "renown_boost": 0.25},
}
## Worn gear's condition at the start (gear.gd: at 0.25 or less a piece is badly worn).
const WORN_START := 0.45

static var TEXT := {
	# The questionnaire page.
	"quiz_title": "Before you climb",
	"quiz_sub": "Three questions. Your answers decide how you begin.",
	"question": "Question %d of %d",
	"home_name": "Near %s",
	"home_help": "You grew up near %s. Your first climb is there, and its station is your home.",
	"back": "Back",
	"change": "Change answers",
	"begin": "Begin: to your home station",
	"summary": "How you begin",
	"sum_gear": "Gear: %s",
	"sum_home": "Home: near %s",
	"sum_crystals": "Crystals: %d of %s",
	"sum_none": "Crystals: none",
	"sum_title": "Title: %s",
	"sum_no_title": "Title: none yet",
	"sum_contract": "A contract from the Noble, in hand",
	"sum_boost": "Renown comes a quarter faster until your first title",
	"quality_fine": "fine",
	"quality_common": "common",
	"quality_worn": "worn",
	"no_armour": "no armour",
	"and": " and ",
	# The name step.
	"name_title": "Who climbs?",
	"name_sub": "A name, and how others speak of you.",
	"name": "Name",
	"name_hint": "optional",
	"dice": "Dice",
	"pronouns": "Pronouns",
	"pronoun_help": "Others will speak of you as {they} and {them}: \"{They} climb{s} well.\"",
	"pronoun_example":"Others will say: \"{They} {are} climbing. I saw {them} on the stair; the mark is {theirs}.\"",
	"next": "Next",
	# The introduction.
	"intro_next": "Next",
	"intro_skip": "Skip",
	"intro_go": "Make your climber",
	# The one-time clearing of old climbers.
	"cleared": "A new start has come to the towers. Climbers made before it can't follow, so they were cleared, once. Your settings are kept. Make a new climber: it begins with the new start.",
	"cleared_ok": "Understood",
	# The title screen.
	"continue": "Continue",
	"new_climber": "New Climber",
	"climbers": "Climbers",
	"full": "All six slots are full. Delete a climber in Climbers to make room.",
	"title_none": "No climber yet. Make one with New Climber.",
	"title_empty": "This slot is empty. New Climber begins one here.",
}

## Placeholder titles from the start (renown.gd TITLES holds them too, with
## rule "origin"). Their names are the owner's to write.
const TITLE_IDS := {"family": "family", "hired": "hired"}


# --- the settings file: made climbers, the one-time clearing ------------------------

static func _settings() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Slots.settings_path())
	return cfg


## How many climbers have been made on this device (the intro can be skipped after one).
static func made() -> int:
	return int(_settings().get_value("start", "made", 0))


static func note_made() -> void:
	var cfg := _settings()
	cfg.set_value("start", "made", int(cfg.get_value("start", "made", 0)) + 1)
	cfg.save(Slots.settings_path())


## The intro can be skipped (a climber was made before on this device).
static func can_skip_intro() -> bool:
	return made() > 0


## Clears every climber made before the new start, once (a marker in the
## settings file). A copy of each cleared file is kept beside it, in case.
## Returns true if any climber was cleared (the title then shows a notice).
static func clear_old_once() -> bool:
	Slots.migrate()  # (a save from before slots moves into slot 1 first)
	var cfg := _settings()
	if cfg.has_section_key("start", "cleared"):
		return false
	var any := false
	for i in range(1, Slots.MAX + 1):
		var p := Slots.path(i)
		if not FileAccess.file_exists(p):
			continue
		if Slots.exists(i):
			any = true
			var copy := p.get_basename() + "_before_new_start.cfg"
			if not FileAccess.file_exists(copy):
				DirAccess.copy_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(copy))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	cfg = _settings()
	cfg.set_value("start", "cleared", 1)
	cfg.set_value("start", "notice", any)
	cfg.set_value("slots", "current", 1)
	cfg.save(Slots.settings_path())
	Slots.forget()
	return any


## The title's notice that old climbers were cleared, until it's dismissed.
static func notice_pending() -> bool:
	return bool(_settings().get_value("start", "notice", false))


static func dismiss_notice() -> void:
	var cfg := _settings()
	cfg.set_value("start", "notice", false)
	cfg.save(Slots.settings_path())


# --- the questionnaire ----------------------------------------------------------------

## The home question's answers: one per tower.
static func home_answers() -> Array:
	var out: Array = []
	for id in Towers.ORDER:
		var nm := String(Towers.TOWERS[id]["name"])
		out.append({"id": id, "name": TEXT["home_name"] % _the(nm), "help": TEXT["home_help"] % _the(nm)})
	return out


static func _the(nm: String) -> String:
	return ("the " + nm.substr(4)) if nm.begins_with("The ") else nm


## A question's answers (the home question's from the towers).
static func answers(q: Dictionary) -> Array:
	return home_answers() if String(q["id"]) == "home" else q["answers"]


static func answer(qid: String, aid: String) -> Dictionary:
	for q in QUESTIONS:
		if String(q["id"]) == qid:
			for a in answers(q):
				if String(a["id"]) == aid:
					return a
	return {}


## True once every question has an answer.
static func complete(picks: Dictionary) -> bool:
	for q in QUESTIONS:
		if answer(String(q["id"]), String(picks.get(q["id"], ""))).is_empty():
			return false
	return true


## The starting pieces for a past and a quality: {carried slot: gear record}.
static func start_pieces(past: String, quality: String) -> Dictionary:
	var p: Dictionary = PAST.get(past, PAST["soldier"])
	var rarity := "fine" if quality == "fine" else "common"
	var out := {}
	for slot in ["melee", "ranged", "armor"]:
		var id := String(p.get(slot, ""))
		if id == "" or not Gear.is_gear(id):
			continue
		var traits: Array = Gear.roll_traits(id, rarity) if rarity == "fine" else []
		out[slot] = Gear.make(id, rarity, traits)
	return out


## Gives a new climber the answers' results (before the first climb).
## `picks`: {"past", "home", "why"} answer ids. Saves.
static func apply(profile, picks: Dictionary) -> void:
	var past := String(picks.get("past", "soldier"))
	var home := String(picks.get("home", Towers.ORDER[0]))
	var why := String(picks.get("why", "self"))
	if not PAST.has(past):
		past = "soldier"
	if not Towers.TOWERS.has(home):
		home = Towers.ORDER[0]
	if not WHY.has(why):
		why = "self"
	var w: Dictionary = WHY[why]
	profile.origin = {"past": past, "home": home, "why": why}
	profile.home = home
	profile.last_tower = home
	# The starting weapon and armour, kept as heirlooms: every climb begins with them.
	var pieces := start_pieces(past, String(w["quality"]))
	for slot in pieces:
		profile.heirlooms[Gear.heirloom_slot_for_carry(slot)] = pieces[slot]
	# Crystals of the home tower's kind.
	if int(w["crystals"]) > 0:
		profile.add_crystal(String(Towers.TOWERS[home]["essence"]), float(w["crystals"]))
	# A title from the start, worn.
	var r := Renown.state(profile)
	var tid := String(w["title"])
	if tid != "" and Renown.TITLES.has(tid) and not r["titles"].has(tid):
		r["titles"].append(tid)
		r["worn"] = tid
	# The Noble's first contract, already in hand.
	if bool(w["contract"]):
		give_contract(profile, home)
	profile.save()


## A reach contract for the home tower, held from the start.
static func give_contract(profile, home: String) -> void:
	var C = load("res://scripts/contracts.gd")
	var o: Dictionary = C.roll(profile, "reach")
	if o.is_empty():
		return
	var k: Dictionary = C.KINDS["reach"]
	o["tower"] = home
	o["floor"] = int(C.RULES["reach_lowest"])
	o["essence"] = String(Towers.TOWERS[home].get("essence", "stone"))
	o["renown"] = int(k.get("renown", 4)) + int(k.get("per", 1)) * int(o["floor"])
	o["crystals"] = int(k.get("crystals", 6)) + int(k.get("crystals_per", 1)) * int(o["floor"])
	o["recipe"] = ""
	C.data(profile)["active"].append(o)


## The climber's gear for this climb, from their start: worn pieces stay
## worn until the Regard (the self made). Called as a climb begins.
static func dress(profile, player) -> void:
	if player == null or profile.regarded:
		return
	var why := String(profile.origin.get("why", ""))
	if not WHY.has(why) or String(WHY[why]["quality"]) != "worn":
		return
	for slot in ["melee", "ranged", "armor"]:
		var g = player.gear.get(slot, {})
		if g is Dictionary and g.has("wear"):
			g["wear"] = minf(float(g["wear"]), WORN_START)
	if player.has_method("refresh_gear"):
		player.refresh_gear()


## Renown earned is a quarter more for the self made, until their first
## title: the extra is kept in fractions, so small gains still add up slowly.
static func renown_bonus(profile, amount: int) -> int:
	if amount <= 0 or profile == null or not ("origin" in profile):
		return 0
	var why := String(profile.origin.get("why", ""))
	var boost := float(WHY.get(why, {}).get("renown_boost", 0.0))
	if boost <= 0.0:
		return 0
	var r := Renown.state(profile)
	if not (r["titles"] as Array).is_empty():
		return 0
	var carry := float(r.get("boost_carry", 0.0)) + amount * boost
	var whole := int(floor(carry))
	r["boost_carry"] = carry - whole
	return whole


## The summary lines after the last answer.
static func summary(picks: Dictionary) -> Array:
	var past := String(picks.get("past", ""))
	var why := String(picks.get("why", ""))
	var home := String(picks.get("home", ""))
	var lines: Array = []
	if PAST.has(past) and WHY.has(why):
		var w: Dictionary = WHY[why]
		var q := String(TEXT["quality_" + String(w["quality"])])
		var names: Array = []
		var p: Dictionary = PAST[past]
		for slot in ["melee", "ranged", "armor"]:
			var id := String(p.get(slot, ""))
			if id != "":
				names.append("%s %s" % [q, Gear.display(id).to_lower()])
		if String(p.get("armor", "")) == "":
			names.append(String(TEXT["no_armour"]))
		lines.append(TEXT["sum_gear"] % ", ".join(names))
	if Towers.TOWERS.has(home):
		lines.append(TEXT["sum_home"] % _the(String(Towers.TOWERS[home]["name"])))
	if WHY.has(why):
		var w2: Dictionary = WHY[why]
		if int(w2["crystals"]) > 0 and Towers.TOWERS.has(home):
			lines.append(TEXT["sum_crystals"] % [int(w2["crystals"]), load("res://scripts/essence.gd").display(String(Towers.TOWERS[home]["essence"]))])
		else:
			lines.append(TEXT["sum_none"])
		var tid := String(w2["title"])
		lines.append(TEXT["sum_title"] % Renown.title_name(tid) if tid != "" else TEXT["sum_no_title"])
		if bool(w2["contract"]):
			lines.append(TEXT["sum_contract"])
		if float(w2["renown_boost"]) > 0.0:
			lines.append(TEXT["sum_boost"])
	return lines
