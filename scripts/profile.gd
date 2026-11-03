extends RefCounted
## What carries over between climbs: your marks (bonds), how much essence has
## soaked into your unmarked body parts, and the essence you've banked since
## your last mark. Saved to user://sixfold.cfg.
##
## The first climb is bondless. It ends in the Regard: the tower's beast
## takes notice and your most-used body part takes its first mark. Fall
## during the first climb and you're still regarded, but the mark is faint:
## it must soak up FAINT_DEBT essence before it can grow.

const Bonds := preload("res://scripts/bonds.gd")
const SAVE_PATH := "user://sixfold.cfg"

const FIRST_CLIMB_FLOORS := 3
const FAINT_DEBT := 80.0
## Banked essence needed to reach each step (index = step - 1).
const STEP_XP := [0.0, 60.0, 160.0, 320.0, 540.0]
## Soak an unmarked body part needs before a later mark takes there,
## multiplied by how many marks you already carry.
const NEW_MARK_SOAK := 140.0

var regarded := false
var bonds := {}  # part -> {"id", "xp", "faint", "debt"}
var soak := {}  # part -> banked soak in unmarked parts
var tally := {}  # essence kind -> banked since the last mark
var climbs := 0
var best_floor := 1
var saving := true


static func step_for_xp(xp: float) -> int:
	var step := 1
	for i in STEP_XP.size():
		if xp >= STEP_XP[i]:
			step = i + 1
	return step


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_floor = int(cfg.get_value("climb", "best_floor", 1))
	regarded = bool(cfg.get_value("profile", "regarded", false))
	bonds = cfg.get_value("profile", "bonds", {})
	soak = cfg.get_value("profile", "soak", {})
	tally = cfg.get_value("profile", "tally", {})
	climbs = int(cfg.get_value("profile", "climbs", 0))


func save() -> void:
	if not saving:
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("climb", "best_floor", best_floor)
	cfg.set_value("profile", "regarded", regarded)
	cfg.set_value("profile", "bonds", bonds)
	cfg.set_value("profile", "soak", soak)
	cfg.set_value("profile", "tally", tally)
	cfg.set_value("profile", "climbs", climbs)
	cfg.save(SAVE_PATH)


## Which bond a body part takes, given the essence gathered: the dominant
## kind picks the bond's affinity, and a bond whose home is this part wins
## ties. Bonds already carried are skipped.
func choose_bond(part: String, essence: Dictionary) -> String:
	var kinds: Array = essence.keys()
	kinds.sort_custom(func(a, b): return float(essence[a]) > float(essence[b]))
	if kinds.is_empty():
		kinds = ["air"]
	var held := bonds.values().map(func(b): return b["id"])
	for kind in kinds + ["air", "water", "iron"]:
		var options: Array = []
		for id in Bonds.BONDS:
			if Bonds.BONDS[id]["affinity"] == kind and not (id in held):
				options.append(id)
		if options.is_empty():
			continue
		for id in options:
			if Bonds.BONDS[id]["home"] == part:
				return id
		return options[0]
	return ""


## Marks a body part with a bond. Faint marks owe FAINT_DEBT essence first.
func add_bond(part: String, id: String, faint: bool) -> void:
	bonds[part] = {"id": id, "xp": 0.0, "faint": faint, "debt": FAINT_DEBT if faint else 0.0}
	soak.erase(part)
	tally = {}


## Banks a stair's worth of essence and soak. Returns lines describing what
## changed (steps gained, faint marks strengthened).
func bank(essence: Dictionary, run_soak: Dictionary) -> Array:
	var lines: Array = []
	var total := 0.0
	for kind in essence:
		total += float(essence[kind])
		tally[kind] = float(tally.get(kind, 0.0)) + float(essence[kind])
	for part in run_soak:
		if not bonds.has(part):
			soak[part] = float(soak.get(part, 0.0)) + float(run_soak[part])
	for part in bonds:
		var b: Dictionary = bonds[part]
		var info: Dictionary = Bonds.BONDS[b["id"]]
		# Essence of the bond's own kind counts double.
		var gain := total + float(essence.get(info["affinity"], 0.0))
		if gain <= 0.0:
			continue
		if b["faint"]:
			b["debt"] = float(b["debt"]) - gain
			if b["debt"] <= 0.0:
				gain = -float(b["debt"])
				b["debt"] = 0.0
				b["faint"] = false
				lines.append("Your %s mark is no longer faint" % info["name"])
			else:
				continue
		var before := step_for_xp(float(b["xp"]))
		b["xp"] = float(b["xp"]) + gain
		var after := step_for_xp(float(b["xp"]))
		if after > before:
			var note: String = Bonds.STEP_NOTES.get(b["id"], {}).get(after, "")
			lines.append("%s grows to step %d%s" % [info["name"], after, (": " + note) if note != "" else ""])
	return lines


## An unmarked body part that has soaked up enough takes a new mark.
## Returns the part, or "" if none is ready.
func ready_for_mark() -> String:
	var need := NEW_MARK_SOAK * float(maxi(1, bonds.size()))
	var best := ""
	var best_soak := need
	for part in soak:
		if bonds.has(part):
			continue
		if float(soak[part]) >= best_soak:
			best_soak = float(soak[part])
			best = part
	return best
