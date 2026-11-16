extends SceneTree
## A measure, not a check: how useful each mark is at steps 1, 3 and 5, in
## one standard fight (tests/mark_fight.gd) over several seeds. Prints a row
## per fight and a ranked table: seconds to clear, damage by the mark's spells
## (and their burns, poisons, creatures) against the sword's, damage taken,
## health regained, foes held helpless, casts, and a score against the same
## fight with no mark (higher is better: faster and safer).
##
## Run: godot --headless --fixed-fps 60 -s tests/mark_measure.gd -- seeds=4
##   marks=stormcaller,warden  steps=1,3,5  (narrow it down)

const Fight := preload("res://tests/mark_fight.gd")
const Bonds := preload("res://scripts/bonds.gd")
const TestRun := preload("res://scripts/test_run.gd")

var main


func _init() -> void:
	TestRun.begin()
	Engine.set_meta("sixfold_test", true)
	_run.call_deferred()


func _run() -> void:
	var seeds := 3
	var marks: Array = Bonds.BONDS.keys()
	var steps: Array = [1, 3, 5]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
		elif a.begins_with("marks="):
			marks = Array(a.trim_prefix("marks=").split(","))
		elif a.begins_with("steps="):
			steps = Array(a.trim_prefix("steps=").split(",")).map(func(x): return int(x))
	var rows: Array = []
	var base := await fights(self, "", 1, seeds)
	print("BASE %s" % [base])
	for id in marks:
		for st in steps:
			var r := await fights(self, String(id), st, seeds)
			r["score"] = score(r, base)
			rows.append(r)
			print("ROW %-17s step %d  score %.2f  time %5.1f  spell %5.0f  weapon %5.0f  taken %4.0f  healed %4.0f  cc %5.1f  casts %4.1f  died %d" % [
				id, st, r["score"], r["time"], r["spell"], r["weapon"], r["taken"], r["healed"], r["cc"], r["casts"], r["died"]])
	for st in steps:
		var at: Array = rows.filter(func(r): return r["step"] == st)
		at.sort_custom(func(x, y): return x["score"] > y["score"])
		print("\nRANK step %d (median %.2f)" % [st, median(at.map(func(r): return r["score"]))])
		for r in at:
			print("  %-17s %.2f" % [r["mark"], r["score"]])
	TestRun.finish()
	quit(0)


## `seeds` fights of one mark at one step ("" for no mark): the averages.
static func fights(tree: SceneTree, id: String, st: int, seeds: int) -> Dictionary:
	var sum := {"time": 0.0, "spell": 0.0, "weapon": 0.0, "taken": 0.0, "healed": 0.0, "cc": 0.0, "casts": 0.0, "died": 0.0, "cleared": 0.0}
	for s in seeds:
		var r := await one(tree, id, st, 1000 + s)
		for k in sum:
			sum[k] += float(r[k]) if not (r[k] is bool) else (1.0 if r[k] else 0.0)
	for k in sum:
		sum[k] /= float(seeds)
	sum["mark"] = id
	sum["step"] = st
	return sum


## One fight on a fresh room.
static func one(tree: SceneTree, id: String, st: int, s: int) -> Dictionary:
	for n in tree.root.get_children():
		if n.name == "Main" or n.has_method("_give_bonds"):
			n.queue_free()
	await tree.process_frame
	await tree.process_frame
	Engine.time_scale = 1.0
	seed(s)
	var m = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	for i in 3:
		await tree.process_frame
	m.player.mouse_aim = false
	var f = Fight.new()
	tree.root.add_child(f)
	f.begin(m, id, st)
	while not f.done:
		await tree.physics_frame
	var r: Dictionary = f.result
	f.queue_free()
	return r


## Against the fight with no mark: how much faster (its time over this
## one's) and how much safer (health lost, less health regained, against the
## fight with no mark), the square root of the two multiplied: 1 is no better
## than no mark. A fall counts as the whole time limit and twice the loss.
static func score(r: Dictionary, base: Dictionary) -> float:
	var t := float(r["time"]) + float(r["died"]) * Fight.LIMIT
	var bt := float(base["time"]) + float(base["died"]) * Fight.LIMIT
	var h := maxf(0.0, float(r["taken"]) - float(r["healed"])) * (1.0 + float(r["died"]))
	var bh := maxf(0.0, float(base["taken"]) - float(base["healed"])) * (1.0 + float(base["died"]))
	return sqrt((bt / maxf(t, 1.0)) * ((bh + 50.0) / (h + 50.0)))


static func median(list: Array) -> float:
	var s := list.duplicate()
	s.sort()
	if s.is_empty():
		return 0.0
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else (float(s[s.size() / 2 - 1]) + float(s[s.size() / 2])) * 0.5
