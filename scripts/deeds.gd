extends Node
## DEEDS: the climber's achievements (the old game had 52; the owner kept
## them "in sixes, with modest renown"). 36 deeds in 6 kinds of 6, each
## worth 1 to 6 renown, 120 renown for all of them together: a deed is a
## nod, never a fortune (slow growth).
##
## Each deed (DEEDS) has its kind (KINDS), name, what it asks, its renown
## and a RULE read from what the climber has already done:
##   record  a counter of the Entity's record (profile.gd note: "slain",
##           "floors", "puzzles", "tasks", "essence", "heirlooms",
##           "provings", "slips", "beasts"), at least "n"
##   count   a counter kept here (note() below: "perfect_parries",
##           "blocks", "off_strikes", "clean_floors", "summits", "wand_casts"...)
##   marks   marks carried;  path  a secret essence's path chosen
##   best    the best floor reached in any tower; towers  towers whose
##           best floor is at least "n"
##   kinds   kinds of monster slain (the Bestiary)
##   beasts_by  towers whose beast has fallen
##   found / bonded / awake   Summit Blades found, bonded, fully awake
##   renown  one of the Noble's title rules (renown.gd deed_done): "of" is
##           the rule ("visits", "lessons", "tier", "golds", "contracts",
##           "unfallen", "rivals"...), "n" and "with" its numbers
##   titles  titles granted (not the ones a climber is born or hired with)
##
## This node (main.gd makes one) looks every half second: a deed newly done
## pays its renown (renown.gd earn: said in the feed and the Entity's log)
## and shows a small notice over the climber; the first one, the Entity
## explains. The book's Deeds ribbon lists them all (deeds_page.gd). Done
## deeds are kept with the climber (profile.gd `deeds`).
##
## Names, words and numbers are plain data here, easy to change.

const Renown := preload("res://scripts/renown.gd")

## The six kinds: [id, name, colour].
static var KINDS := [
	["battle", "Battle", Color(0.9, 0.42, 0.36)],
	["climbing", "Climbing", Color(0.56, 0.78, 0.95)],
	["marks", "Marks and essence", Color(0.72, 0.56, 0.95)],
	["stations", "Stations and tournaments", Color(0.95, 0.78, 0.4)],
	["collecting", "Collecting", Color(0.55, 0.85, 0.55)],
	["daring", "Daring", Color(0.95, 0.56, 0.3)],
]

static var DEEDS := {
	# Battle
	"first_blood": {"kind": "battle", "name": "First Blood", "desc": "Slay a monster.", "renown": 1, "rule": "record", "key": "slain", "n": 1},
	"six_score": {"kind": "battle", "name": "Six Score", "desc": "Slay 120 monsters.", "renown": 4, "rule": "record", "key": "slain", "n": 120},
	"steady_hand": {"kind": "battle", "name": "Steady Hand", "desc": "Parry 36 blows perfectly.", "renown": 3, "rule": "count", "key": "perfect_parries", "n": 36},
	"shield_wall": {"kind": "battle", "name": "Shield Wall", "desc": "Block 36 blows with a shield.", "renown": 2, "rule": "count", "key": "blocks", "n": 36},
	"two_blades": {"kind": "battle", "name": "Two Blades", "desc": "Land 60 off-hand strikes.", "renown": 2, "rule": "count", "key": "off_strikes", "n": 60},
	"beastfeller": {"kind": "battle", "name": "Beastfeller", "desc": "Fell a tower's beast.", "renown": 5, "rule": "record", "key": "beasts", "n": 1},
	# Climbing
	"halfway_up": {"kind": "climbing", "name": "Halfway Up", "desc": "Reach floor 6 of a tower.", "renown": 1, "rule": "best", "n": 6},
	"the_summit": {"kind": "climbing", "name": "The Summit", "desc": "Finish a climb at a tower's summit.", "renown": 5, "rule": "count", "key": "summits", "n": 1},
	"stairworn_boots": {"kind": "climbing", "name": "Stairworn Boots", "desc": "Climb 120 floors in all.", "renown": 3, "rule": "record", "key": "floors", "n": 120},
	"six_towers": {"kind": "climbing", "name": "Six Towers", "desc": "Reach floor 6 in all six towers.", "renown": 6, "rule": "towers", "n": 6},
	"puzzler": {"kind": "climbing", "name": "Puzzler", "desc": "Solve 12 puzzles.", "renown": 2, "rule": "record", "key": "puzzles", "n": 12},
	"taskbearer": {"kind": "climbing", "name": "Taskbearer", "desc": "Finish 12 floor tasks.", "renown": 2, "rule": "record", "key": "tasks", "n": 12},
	# Marks and essence
	"marked": {"kind": "marks", "name": "Marked", "desc": "Take your first mark.", "renown": 2, "rule": "marks", "n": 1},
	"thrice_marked": {"kind": "marks", "name": "Thrice Marked", "desc": "Carry three marks.", "renown": 4, "rule": "marks", "n": 3},
	"fully_marked": {"kind": "marks", "name": "Fully Marked", "desc": "Carry a mark on all six body parts.", "renown": 6, "rule": "marks", "n": 6},
	"banked": {"kind": "marks", "name": "Banked", "desc": "Bank 600 essence in all.", "renown": 3, "rule": "record", "key": "essence", "n": 600},
	"deep_well": {"kind": "marks", "name": "Deep Well", "desc": "Bank 3600 essence in all.", "renown": 4, "rule": "record", "key": "essence", "n": 3600},
	"a_path_chosen": {"kind": "marks", "name": "A Path Chosen", "desc": "Choose a path of the secret essences.", "renown": 3, "rule": "path", "n": 1},
	# Stations and tournaments
	"stopped_in": {"kind": "stations", "name": "Stopped In", "desc": "Stop at a station.", "renown": 1, "rule": "renown", "of": "visits", "n": 1},
	"trained": {"kind": "stations", "name": "Trained", "desc": "Finish the Training basics.", "renown": 2, "rule": "renown", "of": "lessons", "n": 0},
	"bracket_won": {"kind": "stations", "name": "Bracket Won", "desc": "Win the Novice Bracket of a tournament.", "renown": 3, "rule": "renown", "of": "tier", "n": 1},
	"gold_medal": {"kind": "stations", "name": "Gold Medal", "desc": "Win a gold medal in a drill.", "renown": 4, "rule": "renown", "of": "golds", "n": 1},
	"contracted": {"kind": "stations", "name": "Contracted", "desc": "Finish 3 of the Noble's contracts.", "renown": 4, "rule": "renown", "of": "contracts", "n": 3},
	"named": {"kind": "stations", "name": "Named", "desc": "Be granted a title by the Noble.", "renown": 2, "rule": "titles", "n": 1},
	# Collecting
	"kept_close": {"kind": "collecting", "name": "Kept Close", "desc": "Keep an heirloom.", "renown": 1, "rule": "record", "key": "heirlooms", "n": 1},
	"naturalist": {"kind": "collecting", "name": "Naturalist", "desc": "Slay 12 kinds of monster.", "renown": 2, "rule": "kinds", "n": 12},
	"bestiary_keeper": {"kind": "collecting", "name": "Bestiary Keeper", "desc": "Slay 36 kinds of monster.", "renown": 5, "rule": "kinds", "n": 36},
	"glint_in_the_dark": {"kind": "collecting", "name": "Glint in the Dark", "desc": "Find a Summit Blade.", "renown": 4, "rule": "found", "n": 1},
	"bladebound": {"kind": "collecting", "name": "Bladebound", "desc": "Bond three Summit Blades.", "renown": 5, "rule": "bonded", "n": 3},
	"fully_awake": {"kind": "collecting", "name": "Fully Awake", "desc": "Awaken a Summit Blade to its last step.", "renown": 6, "rule": "awake", "n": 6},
	# Daring
	"untouched": {"kind": "daring", "name": "Untouched", "desc": "Climb a floor without taking a hit.", "renown": 3, "rule": "count", "key": "clean_floors", "n": 1},
	"surefooted": {"kind": "daring", "name": "Surefooted", "desc": "Finish 3 climbs in a row without falling.", "renown": 4, "rule": "renown", "of": "unfallen", "n": 3},
	"proven": {"kind": "daring", "name": "Proven", "desc": "Win a Proving.", "renown": 4, "rule": "record", "key": "provings", "n": 1},
	"slipped_through": {"kind": "daring", "name": "Slipped Through", "desc": "Slip past a stair's barrier.", "renown": 3, "rule": "record", "key": "slips", "n": 1},
	"six_beasts": {"kind": "daring", "name": "Six Beasts", "desc": "Fell the beast of all six towers.", "renown": 6, "rule": "beasts_by", "n": 6},
	"duelist": {"kind": "daring", "name": "Duelist", "desc": "Win a duel with another climber.", "renown": 3, "rule": "renown", "of": "rivals", "with": "duels_won", "n": 1},
}
const ORDER := ["first_blood", "six_score", "steady_hand", "shield_wall", "two_blades", "beastfeller",
	"halfway_up", "the_summit", "stairworn_boots", "six_towers", "puzzler", "taskbearer",
	"marked", "thrice_marked", "fully_marked", "banked", "deep_well", "a_path_chosen",
	"stopped_in", "trained", "bracket_won", "gold_medal", "contracted", "named",
	"kept_close", "naturalist", "bestiary_keeper", "glint_in_the_dark", "bladebound", "fully_awake",
	"untouched", "surefooted", "proven", "slipped_through", "six_beasts", "duelist"]

## How often the watcher looks (seconds). More than this many deeds done at
## once (an old save's first look) are paid as one gain, in one line.
static var RULES := {"every": 0.5, "one_line_from": 3}

static var TEXT := {
	"reason": "Deed: %s",
	"reason_many": "%d deeds: %s and more",
	"notice": "Deed: %s",
	"page_title": "Deeds",
	"page_sub": "%d of %d done  ·  %d of %d renown",
	"done": "Done",
	"progress": "%d of %d",
	"renown": "+%d",
	"tab_deeds": "Deeds",
	"tab_blades": "Summit Blades",
}

var main
## Off in tests (their renown sums stay their own) unless a test turns it on.
var on := not Engine.has_meta("sixfold_test")
var _wait := 0.0
var _floor := -1
var _hits := 0
var _player_id := 0


# --- the climber's deeds -----------------------------------------------------------------------

## The climber's deeds: "done" (deed id -> the climb count when done) and
## "n" (counter -> amount).
static func state(profile) -> Dictionary:
	if not (profile.deeds is Dictionary):
		profile.deeds = {}
	var d: Dictionary = profile.deeds
	for k in ["done", "n"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}
	return d


## Adds to one of the deeds' own counters (main may be null: nothing).
static func note(main, key: String, amount := 1.0) -> void:
	if main == null or main.get("profile") == null:
		return
	if main.get("arena") != null and main.arena.get("on") == true:
		return  # (the station's arena counts for nothing)
	var n: Dictionary = state(main.profile)["n"]
	n[key] = float(n.get(key, 0.0)) + amount


static func counter(profile, key: String) -> float:
	return float(state(profile)["n"].get(key, 0.0))


static func is_done(profile, id: String) -> bool:
	return state(profile)["done"].has(id)


static func done_count(profile) -> int:
	return ORDER.filter(func(id): return is_done(profile, id)).size()


static func renown_total() -> int:
	var t := 0
	for id in ORDER:
		t += int(DEEDS[id]["renown"])
	return t


static func renown_earned(profile) -> int:
	var t := 0
	for id in ORDER:
		if is_done(profile, id):
			t += int(DEEDS[id]["renown"])
	return t


static func kind_name(kind: String) -> String:
	for k in KINDS:
		if k[0] == kind:
			return String(k[1])
	return kind


static func kind_color(kind: String) -> Color:
	for k in KINDS:
		if k[0] == kind:
			return k[2]
	return Color.WHITE


static func of_kind(kind: String) -> Array:
	return ORDER.filter(func(id): return String(DEEDS[id]["kind"]) == kind)


## How far along a deed is: [have, need] (need 0 for a yes-or-no deed).
static func progress(profile, id: String) -> Array:
	var d: Dictionary = DEEDS[id]
	var n := int(d.get("n", 0))
	var SB = load("res://scripts/summit_blades.gd")
	match String(d["rule"]):
		"record":
			return [profile.count(String(d["key"])), n]
		"count":
			return [int(counter(profile, String(d["key"]))), n]
		"marks":
			return [profile.bonds.size(), n]
		"path":
			return [1 if String(profile.path) != "" else 0, 0]
		"best":
			var best := 0
			for t in profile.record.get("best", {}):
				best = maxi(best, int(profile.record["best"][t]))
			return [best, n]
		"towers":
			var got := 0
			for t in profile.record.get("best", {}):
				if int(profile.record["best"][t]) >= 6:
					got += 1
			return [got, n]
		"kinds":
			var k := 0
			for kind in profile.bestiary:
				if profile.bestiary[kind] is Dictionary and int(profile.bestiary[kind].get("slain", 0)) > 0:
					k += 1
			return [k, n]
		"beasts_by":
			var by: Dictionary = profile.record.get("beasts_by", {})
			return [by.keys().filter(func(t): return int(by[t]) > 0).size(), n]
		"found":
			return [SB.state(profile)["found"].size(), n]
		"bonded":
			return [SB.bonded_count(profile), n]
		"awake":
			var top := 0
			for t in SB.state(profile)["bonded"]:
				top = maxi(top, SB.level(profile, t))
			return [top, n]
		"titles":
			var got2: Array = Renown.state(profile)["titles"].filter(func(t): return not (String(t) in ["family", "hired"]))
			return [got2.size(), n]
		"renown":
			var rule := {"rule": String(d["of"]), "n": n, "of": String(d.get("with", ""))}
			return [1 if Renown.deed_done(profile, rule) else 0, 0]
	return [0, 0]


static func met(profile, id: String) -> bool:
	var pr := progress(profile, id)
	if int(pr[1]) <= 0:
		return int(pr[0]) > 0
	return int(pr[0]) >= int(pr[1])


## Marks every deed newly done, pays its renown (one line for many at once)
## and returns their ids.
static func check(main) -> Array:
	if main == null or main.get("profile") == null:
		return []
	var prof = main.profile
	var s := state(prof)
	var fresh: Array = []
	for id in ORDER:
		if not s["done"].has(id) and met(prof, id):
			s["done"][id] = int(prof.climbs)
			fresh.append(id)
	if fresh.is_empty():
		return fresh
	var total := 0
	for id in fresh:
		total += int(DEEDS[id]["renown"])
	if fresh.size() >= int(RULES["one_line_from"]):
		Renown.earn(prof, total, TEXT["reason_many"] % [fresh.size(), DEEDS[fresh[0]]["name"]])
	else:
		for id in fresh:
			Renown.earn(prof, int(DEEDS[id]["renown"]), TEXT["reason"] % DEEDS[id]["name"])
	prof.save()
	if main.get("player") != null and is_instance_valid(main.player) and main.has_method("fx_text"):
		main.fx_text(main.player.global_position + Vector2(0, -58), TEXT["notice"] % DEEDS[fresh[0]]["name"], kind_color(String(DEEDS[fresh[0]]["kind"])))
		main.sfx("chime", 1.2, -6.0, 0.0)
	if main.has_method("tip"):
		main.tip("deeds")
	return fresh


# --- the watcher ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or main.get("profile") == null or not on:
		return
	_watch_floor()
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = float(RULES["every"])
	check(main)


## A floor climbed without a hit; perfect parries (the climber's own signal).
func _watch_floor() -> void:
	var p = main.get("player")
	if p == null or not is_instance_valid(p):
		return
	if p.get_instance_id() != _player_id:
		_player_id = p.get_instance_id()
		_floor = int(main.floor_num)
		_hits = int(p.hits_taken)
		if p.has_signal("on_parry") and not p.on_parry.is_connected(_parried):
			p.on_parry.connect(_parried)
		return
	var f := int(main.floor_num)
	if f == _floor:
		return
	if f == _floor + 1 and not p.dead and int(p.hits_taken) == _hits and not bool(main.get("on_train")):
		note(main, "clean_floors")
	_floor = f
	_hits = int(p.hits_taken)


func _parried(_source, perfect: bool) -> void:
	if perfect:
		note(main, "perfect_parries")
