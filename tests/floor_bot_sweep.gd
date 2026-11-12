extends SceneTree
## The floor bot's heavy sweep: on many floors of every tower and depth, the
## bot (tests/floor_bot_driver.gd) plays the floor as a player would (walks
## by path, opens doors by walking, fights with normal attacks, does the
## floor's task, solves its puzzle) and walks up the stair. Reports the
## completion rate, the time per floor, every floor it failed and why, and
## what the floors hold: rooms with no payoff, dead ends with nothing,
## pieces of the task per floor.
##
## Run: godot --headless --fixed-fps 60 -s tests/floor_bot_sweep.gd -- 2
##   (--fixed-fps 60 runs every physics tick exactly, as fast as the computer
##   allows: raising the game's time scale instead would make each tick coarser)
##   (the number: floors per tower and depth; "speed=8" runs the game that
##   many times faster, "tower=kraken" or "kind=runes" to narrow it down)

const TestRun := preload("res://scripts/test_run.gd")
const Driver := preload("res://tests/floor_bot_driver.gd")
const FLOORS := [2, 3, 4, 5, 7, 8, 9, 10, 11]

var main


func _init() -> void:
	TestRun.begin()
	Engine.set_meta("sixfold_test", true)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var each := 2
	var speed := 1.0  # (run it with --fixed-fps 60: as fast as the computer allows, every tick exact)
	var only_tower := ""
	var only_kind := ""
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			each = int(a)
		elif a.begins_with("speed="):
			speed = float(a.trim_prefix("speed="))
		elif a.begins_with("tower="):
			only_tower = a.trim_prefix("tower=")
		elif a.begins_with("kind="):
			only_kind = a.trim_prefix("kind=")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var res := await sweep(self, main, each, speed, only_tower, only_kind)
	print_report(res)
	TestRun.finish()
	quit(0 if res["failed"].size() <= maxi(1, res["floors"] / 50) else 1)


## Plays `each` floors per tower and depth. Returns the tallies.
static func sweep(tree: SceneTree, m, each: int, speed: float, only_tower := "", only_kind := "", floors: Array = FLOORS) -> Dictionary:
	var O = load("res://scripts/objectives.gd")
	var res := {"floors": 0, "ok": 0, "time": 0.0, "failed": [], "kinds": {}, "kind_ok": {}, "pieces": 0, "rooms": 0, "nopay": 0, "dead_ends": 0, "dead_nopay": 0,
		"real": 0.0, "loops": 0, "cracks": 0, "scenarios": 0, "close_calls": 0, "close_floors": 0}
	var t0 := Time.get_ticks_msec()
	m.profile.regarded = true
	m.first_climb = false
	m.player.mouse_aim = false
	var towers: Array = m.Towers.ORDER if only_tower == "" else [only_tower]
	var kinds: Array = O.all_kinds()
	var ki := maxi(0, m.Towers.ORDER.find(only_tower)) * floors.size() * each  # (one tower alone: start where the full sweep would)
	for tid in towers:
		for fl in floors:
			for k in each:
				m.tower = tid
				# The task: the next kind in turn (so every kind gets played), unless narrowed.
				O.forced = only_kind if only_kind != "" else kinds[ki % kinds.size()]
				ki += 1
				var r: Dictionary = await play(tree, m, fl, speed)
				O.forced = ""
				res["floors"] += 1
				var kind: String = r["kind"]
				res["kinds"][kind] = int(res["kinds"].get(kind, 0)) + 1
				res["pieces"] += int(r["pieces"])
				res["rooms"] += int(r["rooms"])
				res["nopay"] += int(r["nopay"])
				res["dead_ends"] += int(r["dead_ends"])
				res["dead_nopay"] += int(r["dead_nopay"])
				res["loops"] += int(r["loops"])
				res["cracks"] += int(r["cracks"])
				res["scenarios"] += int(r["scenarios"])
				res["close_calls"] += int(r.get("close_calls", 0))
				if int(r.get("close_calls", 0)) > 0:
					res["close_floors"] += 1
				if r["ok"]:
					res["ok"] += 1
					res["time"] += float(r["time"])
					res["kind_ok"][kind] = int(res["kind_ok"].get(kind, 0)) + 1
				else:
					res["failed"].append("%s floor %d (%s): %s  %s" % [tid, fl, kind, r["why"], r.get("log", [])])
				print("  %s %-9s floor %2d  %-10s %s  %.0f s" % ["ok  " if r["ok"] else "FAIL", tid, fl, kind, "" if r["ok"] else r["why"], r["time"]])
	res["real"] = (Time.get_ticks_msec() - t0) / 1000.0
	return res


## One floor: built as the game builds it, played by the bot to the stair.
static func play(tree: SceneTree, m, fl: int, speed: float) -> Dictionary:
	# (the last floor's stair: let its fade and the floor after it finish first)
	var w0 := Time.get_ticks_msec()
	while (m.climbing or m.fade > 0.0) and Time.get_ticks_msec() - w0 < 10000:
		await tree.process_frame
	m.camp_choosing = false
	m.in_camp = false
	m.player.set_physics_process(true)
	m._start_floor(fl)
	await tree.process_frame
	m.banner = {}
	var p = m.player
	# A sturdy climber: the sweep tests the floors, not the fighting.
	p.max_hp = 1500.0
	p.hp = 1500.0
	p.iframes = 0.0
	m.dev_no_death = true  # (the dev tool's No dying: the bot's close calls are counted instead)
	var plan: Dictionary = m.floor_plan
	var out := measure(plan)
	var bot = Driver.new()
	tree.root.add_child(bot)
	bot.start(m, 300.0)
	m.test_speed = speed
	Engine.time_scale = speed
	Engine.max_physics_steps_per_frame = 16
	var real0 := Time.get_ticks_msec()
	while not bot.done:
		await tree.process_frame
		if Engine.time_scale != speed and m.hitstop_until == 0 and not m.slowmo:
			Engine.time_scale = speed
		if Time.get_ticks_msec() - real0 > 900000:
			bot._finish(false, "real-time limit")
	m.test_speed = 1.0
	m.dev_no_death = false
	Engine.time_scale = 1.0
	var r: Dictionary = bot.result
	bot.queue_free()
	for k in out:
		r[k] = out[k]
	if m.climbing:
		# (let the stair's fade finish before the next floor)
		for i in 90:
			await tree.process_frame
			if not m.climbing:
				break
	return r


## What a floor holds: rooms, dead ends, rooms with no payoff, pieces of the task.
static func measure(plan: Dictionary) -> Dictionary:
	var F = load("res://scripts/floors.gd")
	var T = load("res://scripts/themes.gd")
	var info: Array = plan.get("room_info", [])
	var links := {}
	for i in info.size():
		links[i] = 0
	for i in info.size():
		var par := int(info[i]["parent"])
		if par >= 0:
			links[i] += 1
			links[par] += 1
	var obj: Dictionary = plan.get("objective", {})
	var piece_rooms := {}
	for pc in obj.get("pieces", []):
		piece_rooms[int(pc["room"])] = true
	if obj.has("tablet"):
		piece_rooms[int(obj["tablet"]["room"])] = true
	var chest_rooms := {}
	for c in plan.get("chests", []):
		chest_rooms[int(c["room"])] = true
	var out := {"kind": String(obj.get("kind", "")), "pieces": obj.get("pieces", []).size(), "rooms": info.size(), "nopay": 0, "dead_ends": 0, "dead_nopay": 0,
		"loops": int(plan.get("loops", 0)), "cracks": plan.get("cracks", []).size(), "scenarios": plan.get("scenarios", []).size()}
	for i in info.size():
		if i == 0:
			continue
		var th: Dictionary = T.get_theme(String(info[i]["theme"]))
		var pays: bool = th["feature"] in F.PAYOFF_FEATURES or chest_rooms.has(i) or piece_rooms.has(i)
		if not pays:
			out["nopay"] += 1
		if int(links[i]) <= 1 and info[i]["role"] != "stair":
			out["dead_ends"] += 1
			if not pays:
				out["dead_nopay"] += 1
	return out


static func print_report(res: Dictionary) -> void:
	var n: int = res["floors"]
	print("")
	print("FLOOR BOT: %d of %d floors finished (%.1f%%)" % [res["ok"], n, 100.0 * res["ok"] / maxf(1.0, n)])
	print("  average time per finished floor: %.1f s of play" % (res["time"] / maxf(1.0, res["ok"])))
	print("  real time: %.0f s" % res["real"])
	print("  close calls (health hit 1; the bot can't fall): %d, on %d floors" % [res["close_calls"], res["close_floors"]])
	print("  by task: ", res["kind_ok"], " of ", res["kinds"])
	print("  pieces of the task per floor: %.2f" % (float(res["pieces"]) / maxf(1.0, n)))
	print("  rooms: %d, with no payoff: %d; dead ends: %d, with nothing: %d" % [res["rooms"], res["nopay"], res["dead_ends"], res["dead_nopay"]])
	print("  loops per floor: %.2f, cracked walls per floor: %.2f, scenario rooms per floor: %.2f" % [float(res["loops"]) / maxf(1.0, n), float(res["cracks"]) / maxf(1.0, n), float(res["scenarios"]) / maxf(1.0, n)])
	if not res["failed"].is_empty():
		print("  failed:")
		for f in res["failed"]:
			print("    ", f)
