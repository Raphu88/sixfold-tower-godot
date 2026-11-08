extends RefCounted
## Which of the beast's tests a floor gets, how hard it is, how it meets
## combat, and what it's called. The floor plan (floors.gd) asks for one
## when it lays out the gallery; puzzle.gd runs it. Plain data: edit freely.

const TYPES := {
	"eyes": preload("res://scripts/puzzles/eyes.gd"),
	"plates": preload("res://scripts/puzzles/plates.gd"),
	"statues": preload("res://scripts/puzzles/statues.gd"),
	"mirrors": preload("res://scripts/puzzles/mirrors.gd"),
	"crumble": preload("res://scripts/puzzles/crumble.gd"),
}
## Kinds built into a hand-made room (rooms.gd); the rest make their own
## layout in a plain carved room.
const PREFAB := ["eyes", "plates"]
## Each tower's favourite test, and how often a floor there gets it.
const SIGNATURE := {"gryphon": "mirrors", "wyvern": "crumble", "manticore": "statues"}
const SIGNATURE_CHANCE := 0.5
## Tiers by floor: [up to floor, tier]. Difficulty rises within a climb.
const TIERS := [[3, 1], [8, 2], [99, 3]]
## From this floor the test is in PRESSURE mode (monsters keep coming while
## you think); below it, QUIET mode (it wakes once its guards are dead).
const PRESSURE_FROM := 7
## A carved gallery's size for the kinds that lay themselves out, in tiles:
## [min width, max width, min height, max height].
const ROOM_SIZE := [11, 13, 9, 11]
const ROOM_SHAPES := ["rect", "rect", "round"]

## Dev tool and tests: when set, every floor of rooms gets this kind.
static var forced := ""


static func tier_for(floor_num: int) -> int:
	for t in TIERS:
		if floor_num <= int(t[0]):
			return int(t[1])
	return 3


static func mode_for(floor_num: int) -> String:
	return "pressure" if floor_num >= PRESSURE_FROM else "quiet"


## The kind of test for a floor of a tower (`tid` is the tower's id).
static func pick(floor_num: int, tid: String) -> String:
	if forced != "" and TYPES.has(forced):
		return forced
	if SIGNATURE.has(tid) and randf() < SIGNATURE_CHANCE:
		return SIGNATURE[tid]
	var kinds: Array = TYPES.keys()
	return kinds[randi() % kinds.size()]


## A test's name in a tower (some towers call theirs something else).
static func display_name(kind: String, tid: String) -> String:
	if not TYPES.has(kind):
		return ""
	var script = TYPES[kind]
	var names: Dictionary = script.NAMES if "NAMES" in script.get_script_constant_map() else {}
	return names.get(tid, script.NAME)


## A test of `kind` for a room, checked by its solver; {} if none could be made.
## `info` is the floor plan's room (rect, rows, reserved...), `features` the
## room's parsed features (eyes, plates...), `entrances` the corridor tiles
## at its doorways (world rects: the seal closes them).
static func make(kind: String, info: Dictionary, features: Dictionary, floor_num: int, tid: String, entrances: Array) -> Dictionary:
	if not TYPES.has(kind):
		return {}
	var tier := tier_for(floor_num)
	var ctx := {"rows": info.get("rows", []), "reserved": info.get("reserved", {}), "features": features, "tower": tid}
	var rect: Rect2 = info["rect"]
	var spec: Dictionary = TYPES[kind].make(rect, floor_num, tier, ctx)
	if spec.is_empty():
		return {}
	spec["type"] = kind
	spec["tier"] = tier
	spec["mode"] = mode_for(floor_num)
	spec["room"] = rect
	spec["id"] = info.get("id", "")
	spec["tower"] = tid
	spec["name"] = display_name(kind, tid)
	spec["entrances"] = entrances
	return spec
