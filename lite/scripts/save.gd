extends RefCounted
## Six Towers LITE's save: its marks, the beasts beaten, the guide's
## first-time moments and the magic chosen last. Banking at stairs and the
## Regard (a beast's mark) are worked out here too.

const Data := preload("res://scripts/data.gd")
const PATH := "user://save.json"
const TEST_PATH := "user://test_save.json"  # (the tests keep their own file)

## essence -> {"part": body part, "grown": essence grown into it}
var marks := {}
## The towers whose beast has been beaten.
var beaten: Array = []
## Essence gathered before the first mark: it pours into the first mark.
var spare := 0.0
## The guide's first-time moments already shown (climb.gd _hints).
var seen := {}
## The magic chosen last (an essence).
var chosen := ""
## Body parts' soak: part -> essence soaked up by play style (Data.DEED_PART),
## for parts without a mark; the next mark goes on the fullest.
var soak := {}
## Weapon -> how many hits it's landed (the most used is the favourite).
var weapon_use := {}
## Marks that gained a star and wait for an upgrade to be picked (one entry
## per star, oldest first): essence ids.
var pending_ups: Array = []
## Treasures found (Data.TREASURES ids), and what's worn: slot -> id.
var found: Array = []
var worn := {}
## The weapon in hand (Data.WEAPON_ORDER).
var weapon := "sword"
## How the climber looks: option ids (look.gd), chosen on the climber screen.
var app := {}


static func load_save():
	var s = load("res://scripts/save.gd").new()
	if not FileAccess.file_exists(path()):
		return s
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return s
	var m = parsed.get("marks", {})
	if typeof(m) == TYPE_DICTIONARY:
		for k in m:
			if Data.MAGIC.has(k) and typeof(m[k]) == TYPE_DICTIONARY:
				var ups: Array = []
				for u in m[k].get("ups", []):
					ups.append(String(u))
				s.marks[k] = {"part": String(m[k].get("part", "hand")), "grown": float(m[k].get("grown", 0.0)), "ups": ups}
	var b = parsed.get("beaten", [])
	if typeof(b) == TYPE_ARRAY:
		for t in b:
			if Data.TOWERS.has(String(t)) and not s.beaten.has(String(t)):
				s.beaten.append(String(t))
	s.spare = float(parsed.get("spare", 0.0))
	var seen = parsed.get("seen", {})
	if typeof(seen) == TYPE_DICTIONARY:
		s.seen = seen
	s.chosen = String(parsed.get("chosen", ""))
	for d in [["soak", s.soak], ["weapon_use", s.weapon_use]]:
		var src = parsed.get(d[0], {})
		if typeof(src) == TYPE_DICTIONARY:
			for k in src:
				d[1][String(k)] = float(src[k])
	var pu = parsed.get("pending_ups", [])
	if typeof(pu) == TYPE_ARRAY:
		for e in pu:
			if s.marks.has(String(e)):
				s.pending_ups.append(String(e))
	var fd = parsed.get("found", [])
	if typeof(fd) == TYPE_ARRAY:
		for id in fd:
			if Data.TREASURES.has(String(id)) and not s.found.has(String(id)):
				s.found.append(String(id))
	var wn = parsed.get("worn", {})
	if typeof(wn) == TYPE_DICTIONARY:
		for k in wn:
			if s.found.has(String(wn[k])):
				s.worn[String(k)] = String(wn[k])
	s.weapon = String(parsed.get("weapon", "sword"))
	if not Data.WEAPONS.has(s.weapon):
		s.weapon = "sword"
	var app = parsed.get("app", {})
	if typeof(app) == TYPE_DICTIONARY:
		s.app = app
	return s


func save() -> void:
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"marks": marks, "beaten": beaten, "spare": spare, "seen": seen, "chosen": chosen, "weapon": weapon, "app": app, "found": found, "worn": worn, "soak": soak, "weapon_use": weapon_use, "pending_ups": pending_ups}))


## Where the save lives (its own file in a test run).
static func path() -> String:
	return TEST_PATH if Engine.has_meta("lite_test") else PATH


## Finds one of `choices` not found yet (at random) and wears it. Returns its
## id, or "" if they're all found already.
func find_treasure(choices: Array) -> String:
	var left: Array = choices.filter(func(id): return not found.has(id))
	if left.is_empty():
		return ""
	var id: String = left[randi() % left.size()]
	found.append(id)
	wear(id)
	return id


## Wears a found treasure (taking off what was in its slot).
func wear(id: String) -> void:
	if not Data.TREASURES.has(id):
		return
	worn[slot_of(id)] = id


func slot_of(id: String) -> String:
	var tr: Dictionary = Data.TREASURES.get(id, {})
	return "skin" if tr.get("kind", "") == "skin" else String(tr.get("slot", "head"))


## The mark on a body part (its essence), or "".
func mark_on(part: String) -> String:
	for k in marks:
		if marks[k]["part"] == part:
			return k
	return ""


func star(essence: String) -> int:
	return Data.stars(float(marks[essence]["grown"])) if marks.has(essence) else 0


## How many times a mark has taken an upgrade (Data.UPGRADE_INFO id).
func ups(essence: String, id: String) -> int:
	if not marks.has(essence):
		return 0
	return (marks[essence].get("ups", []) as Array).count(id)


## Grows a mark; each star it gains queues an upgrade to pick.
func grow(essence: String, amount: float) -> void:
	if not marks.has(essence) or amount <= 0.0:
		return
	var before := star(essence)
	marks[essence]["grown"] = float(marks[essence]["grown"]) + amount
	for k in star(essence) - before:
		pending_ups.append(essence)


## Takes an upgrade for the oldest mark waiting for one.
func take_upgrade(id: String) -> void:
	if pending_ups.is_empty():
		return
	var e: String = pending_ups.pop_front()
	if marks.has(e):
		if not marks[e].has("ups"):
			marks[e]["ups"] = []
		marks[e]["ups"].append(id)


## The weapon used most (the favourite), or "".
func favourite() -> String:
	var best := ""
	var most := 0.0
	for w in weapon_use:
		if float(weapon_use[w]) > most:
			most = float(weapon_use[w])
			best = w
	return best


## The empty body part that has soaked up the most (where the next mark goes),
## or `fallback` if none has soaked anything.
func next_mark_part(fallback: String) -> String:
	var best := ""
	var most := 0.0
	for p in Data.PARTS:
		if mark_on(p) == "" and float(soak.get(p, 0.0)) > most:
			most = float(soak.get(p, 0.0))
			best = p
	if best != "":
		return best
	if mark_on(fallback) == "":
		return fallback
	for p in Data.PARTS:
		if mark_on(p) == "":
			return p
	return fallback


## The beast of `tower` marks the climber (or grows its mark if it's there).
## `beat`: it was beaten (its crown); false for the first climb's Regard,
## when it only takes notice. Returns true for a new mark. The mark goes on
## the body part that soaked up the most (play style).
func regard(tower: String, beat := true) -> bool:
	var e: String = Data.TOWERS[tower]["essence"]
	if beat and not beaten.has(tower):
		beaten.append(tower)
	if marks.has(e):
		grow(e, Data.BEAST_GROWTH)
		return false
	var part := next_mark_part(String(Data.TOWERS[tower]["part"]))
	marks[e] = {"part": part, "grown": 0.0, "ups": []}
	grow(e, spare + float(soak.get(part, 0.0)))
	soak.erase(part)
	spare = 0.0
	chosen = e
	return true


## Pours essence banked at a stair into the climber. BODY_SHARE of it goes to
## the body parts by what each did (`deeds`: part -> how much; a marked part
## grows its mark, an empty one soaks it up); the rest goes to the marks by
## colour: each mark takes all of its own colour, the others are shared out
## thinly. With no mark yet, the colours wait for the first one. `bag` is
## essence -> amount.
func bank(bag: Dictionary, deeds := {}) -> void:
	var total := 0.0
	for k in bag:
		total += float(bag[k])
	if total <= 0.0:
		return
	var weights := {}
	for p in deeds:
		weights[p] = float(deeds[p])
	var fav := favourite()
	var fav_part: String = Data.DEED_PART.get("hit_" + fav, "")
	if weights.has(fav_part):
		weights[fav_part] = float(weights[fav_part]) * (1.0 + Data.FAVOURITE_BONUS)
	if weights.is_empty():
		for p in Data.PARTS:
			weights[p] = 1.0
	var wsum := 0.0
	for p in weights:
		wsum += float(weights[p])
	var body := total * Data.BODY_SHARE
	for p in weights:
		var amt := body * float(weights[p]) / wsum
		var e := mark_on(p)
		if e != "":
			grow(e, amt)
		else:
			soak[p] = float(soak.get(p, 0.0)) + amt
	var k_rest := 1.0 - Data.BODY_SHARE
	if marks.is_empty():
		spare += total * k_rest
		return
	for k in bag:
		var amt := float(bag[k]) * k_rest
		if marks.has(k):
			grow(k, amt)
		else:
			var each := amt * Data.OTHER_SHARE / float(marks.size())
			for m in marks:
				grow(m, each)
