extends SceneTree
## A heavier sweep than the normal suite's (tests/parts/reachability.gd):
## builds many floors in every tower and checks each with reach.gd (can the
## stair, every room, every wing's door and every key, lever and carrier be
## reached from the start?).
##
## Run: godot --headless -s tests/reach_sweep.gd -- 200
##   floor plans: 200 per tower and floor number (2 to 11), and the Proving
## Or:  godot --headless -s tests/reach_sweep.gd -- live 50
##   floors as the game builds them (cover, traps, doors, wings): 50 per
##   tower and floor number
## Prints how often each problem was seen; exits 1 if any was.

const TestRun := preload("res://scripts/test_run.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Proving := preload("res://scripts/proving.gd")
const Part := preload("res://tests/parts/reachability.gd")

var counts := {}
var total := 0
var bad := 0


func _init() -> void:
	TestRun.begin()
	_run.call_deferred()


func _run() -> void:
	var per := 50
	var live := false
	var only_tower := ""
	var only_floor := 0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			per = int(a)
		elif a == "live":
			live = true
		elif a.begins_with("tower="):
			only_tower = a.trim_prefix("tower=")
		elif a.begins_with("floor="):
			only_floor = int(a.trim_prefix("floor="))
	var t0 := Time.get_ticks_msec()
	if live:
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.profile.regarded = true
		main.first_climb = false
		for tid in Towers.ORDER:
			if only_tower != "" and tid != only_tower:
				continue
			main.tower = tid
			for n in range(2, Towers.SUMMIT):
				if only_floor > 0 and n != only_floor:
					continue
				for k in per:
					main._start_floor(n)
					_count(Part.live_report(main))
			await process_frame
		main.queue_free()
	else:
		for tid in Towers.ORDER:
			if only_tower != "" and tid != only_tower:
				continue
			var tower: Dictionary = Towers.TOWERS[tid]
			for n in range(2, Towers.SUMMIT):
				if only_floor > 0 and n != only_floor:
					continue
				for k in per:
					var plan := Floors.rooms_floor(n, tower, false)
					_count(Reach.plan_check(plan))
					_dead_ends(plan)
			_count(Reach.plan_check(Proving.build_plan(tower)))
	print("%s: %d, failing: %d (%.2f%%), %d ms" % ["built floors" if live else "floor plans", total, bad, 100.0 * bad / maxf(total, 1), Time.get_ticks_msec() - t0])
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for key in keys:
		print("  %6d  %.2f%%  %s" % [counts[key], 100.0 * counts[key] / total, key])
	if branches > 0:
		print("dead ends (branch rooms) with nothing in them: %d of %d branch rooms (%.1f%%); on %.1f%% of floors" % [empty_branches, branches, 100.0 * empty_branches / branches, 100.0 * floors_with_empty / maxf(total, 1)])
		for th in empty_by_theme:
			print("  %6d  %s" % [empty_by_theme[th], th])
	await process_frame
	TestRun.finish()
	quit(1 if bad > 0 else 0)


var branches := 0
var empty_branches := 0
var floors_with_empty := 0
var empty_by_theme := {}


## Branch rooms (dead ends) holding nothing: no monster, no good room's
## gift, no key or lever, no mural, no wing or secret beside it.
func _dead_ends(plan: Dictionary) -> void:
	var any := false
	for i in plan["room_info"].size():
		var info: Dictionary = plan["room_info"][i]
		if info["role"] != "branch":
			continue
		branches += 1
		var r: Rect2 = info["rect"]
		var th: Dictionary = Floors.Themes.get_theme(info["theme"])
		var full: bool = th["kind"] in ["good", "mirror"] or th["feature"] == "ambush"
		for m in plan["monsters"]:
			full = full or r.has_point(m[1])
		for l in plan["locks"]:
			full = full or (l.has("pos") and r.has_point(l["pos"]))
		for m in plan["puzzle"].get("murals", []):
			full = full or int(m["room_i"]) == i
		for k in plan["wings"] + plan["secrets"]:
			full = full or int(k["parent"]) == i
		if not full:
			empty_branches += 1
			any = true
			empty_by_theme[info["theme"]] = int(empty_by_theme.get(info["theme"], 0)) + 1
	if any:
		floors_with_empty += 1


func _count(r: Dictionary) -> void:
	total += 1
	if r["ok"]:
		return
	bad += 1
	var seen := {}
	var re := RegEx.new()
	re.compile("\\d+ ")
	for p in r["problems"]:
		var key := re.sub(String(p), "", true)
		if not seen.has(key):
			seen[key] = true
			counts[key] = int(counts.get(key, 0)) + 1
