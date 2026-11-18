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
				s.marks[k] = {"part": String(m[k].get("part", "hand")), "grown": float(m[k].get("grown", 0.0))}
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
	return s


func save() -> void:
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"marks": marks, "beaten": beaten, "spare": spare, "seen": seen, "chosen": chosen}))


## Where the save lives (its own file in a test run).
static func path() -> String:
	return TEST_PATH if Engine.has_meta("lite_test") else PATH


## The mark on a body part (its essence), or "".
func mark_on(part: String) -> String:
	for k in marks:
		if marks[k]["part"] == part:
			return k
	return ""


func star(essence: String) -> int:
	return Data.stars(float(marks[essence]["grown"])) if marks.has(essence) else 0


## The beast of `tower` marks the climber (or grows its mark if it's there).
## `beat`: it was beaten (its crown); false for the first climb's Regard,
## when it only takes notice. Returns true for a new mark.
func regard(tower: String, beat := true) -> bool:
	var e: String = Data.TOWERS[tower]["essence"]
	if beat and not beaten.has(tower):
		beaten.append(tower)
	if marks.has(e):
		marks[e]["grown"] = float(marks[e]["grown"]) + Data.BEAST_GROWTH
		return false
	var part: String = Data.TOWERS[tower]["part"]
	if mark_on(part) != "":  # (only if the data gives two towers one part)
		for p in Data.PARTS:
			if mark_on(p) == "":
				part = p
				break
	marks[e] = {"part": part, "grown": spare}
	spare = 0.0
	chosen = e
	return true


## Pours essence banked at a stair into the marks: each mark takes all of its
## own colour; the other colours are shared out more thinly. With no mark
## yet, it waits for the first one. `bag` is essence -> amount.
func bank(bag: Dictionary) -> void:
	if marks.is_empty():
		for k in bag:
			spare += float(bag[k])
		return
	for k in bag:
		var amt := float(bag[k])
		if marks.has(k):
			marks[k]["grown"] = float(marks[k]["grown"]) + amt
		else:
			var each := amt * Data.OTHER_SHARE / float(marks.size())
			for m in marks:
				marks[m]["grown"] = float(marks[m]["grown"]) + each
