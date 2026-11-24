extends SceneTree
## A measure, not a check: the floor bot (tests/floor_bot_driver.gd) plays
## floors of one tower and this prints the essence it gathered and what each
## body part soaked up on each, to tune the split (essence_flow.gd) and the
## soak rate (profile.gd SOAK_RATE) against real floors. The bot only
## strikes (it never parries or rolls on purpose), so the hand's share of the
## soak is higher than a player's.
##
## "thorough": the bot plays as a thorough player does (the owner's way):
## the task, then every monster it can reach, every chest and cache, every
## cracked wall broken (a finisher's work, done for it) and its alcove
## emptied, then the stair. Each floor prints the kills (the floor's own
## monsters and the adds spawned while it was played) and the essence by
## source (main.gd essence_sources), to hold the progression model's
## essence and kills a floor (tests/progression_model.gd ESSENCE, KILLS)
## to real play.
##
## Run: godot --headless --fixed-fps 60 -s tests/essence_measure.gd -- tower=gryphon
##      godot --headless --fixed-fps 60 -s tests/essence_measure.gd -- tower=chimera thorough floors=1,2,3,4,5,7 runs=2

const TestRun := preload("res://scripts/test_run.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

var main


## The thorough player: the floor bot, then everything else on the floor.
class Thorough extends "res://tests/floor_bot_driver.gd":
	var hunted := {}  # monster -> seconds spent going after it (given up past HUNT)
	const HUNT := 40.0

	func _clearing() -> bool:
		var ob = main.objective
		return not main.ward or ob == null or ob.kind == "" or ob.done

	func _pick_foe():
		var b = super._pick_foe()
		if b != null or not _clearing():
			return b
		var pos: Vector2 = main.player.global_position
		var best_d := INF
		for e in main.enemies():
			if e.dead or e.is_queued_for_deletion() or e.get("submerged") or e.get("ally"):
				continue
			if float(hunted.get(e, 0.0)) > HUNT or (ignore.has(e) and float(ignore[e]) > t_game):
				continue
			var d: float = pos.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				b = e
		return b

	func _fight(e, delta: float) -> void:
		hunted[e] = float(hunted.get(e, 0.0)) + delta
		# (walking to a far one: not "no harm done" yet)
		if main.player.global_position.distance_to(e.global_position) > 46.0 + float(e.radius) + 40.0:
			foe_dry = 0.0
			foe_t = minf(foe_t, 5.0)
		super._fight(e, delta)

	func _task_step() -> Dictionary:
		var st: Dictionary = super._task_step()
		if not _clearing() or not st.has("why") or not String(st["why"]) in ["the stair", "the reliquary"]:
			return st
		var pos: Vector2 = main.player.global_position
		var todo: Array = []
		if main.room_rewards != null:
			for c in main.room_rewards.chests:
				if c["open"] and not c["taken"]:
					todo.append({"pos": c["pos"], "why": "a chest"})
		if not main.cache.is_empty() and not main.cache["taken"]:
			todo.append({"pos": main.cache["pos"], "why": "the cache"})
		if main.cracks != null:
			for c in main.cracks.list:
				if not c["broken"] and float(hunted.get(c, 0.0)) < HUNT:
					todo.append({"pos": main.cracks._near_face(c, pos), "why": "a cracked wall", "crack": c})
				elif c["broken"] and c.has("reward") and not c["taken"] and float(hunted.get(c, 0.0)) < HUNT:
					todo.append({"pos": c["reward"]["pos"], "why": "behind a cracked wall", "crack": c})
		var best := {}
		var best_d := INF
		for x in todo:
			var d: float = _path_len(pos, x["pos"])
			if d < best_d:
				best_d = d
				best = x
		if best.is_empty():
			return st
		if best.has("crack"):
			var c = best["crack"]
			hunted[c] = float(hunted.get(c, 0.0)) + get_physics_process_delta_time()
			if not c["broken"] and pos.distance_to(best["pos"]) < 60.0:
				main.cracks.crumble(c)  # (a finisher at the wall: the bot's taps never chain one on purpose)
				path = PackedVector2Array()
		return {"pos": best["pos"], "act": "walk", "r": 10.0, "why": best["why"]}


func _init() -> void:
	TestRun.begin()
	Engine.set_meta("sixfold_test", true)
	_run.call_deferred()


func _run() -> void:
	var tower := "gryphon"
	var floors: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]
	var thorough := false
	var runs := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tower="):
			tower = a.trim_prefix("tower=")
		elif a.begins_with("floors="):
			floors = Array(a.trim_prefix("floors=").split(",")).map(func(x): return int(x))
		elif a == "thorough":
			thorough = true
		elif a.begins_with("runs="):
			runs = int(a.trim_prefix("runs="))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.profile.regarded = true
	main.first_climb = false
	main.player.mouse_aim = false
	main.tower = tower
	main.lost_cache_chance = main.Lost.CACHE_CHANCE  # (as in the game)
	var total := 0.0
	var soak_total := {}
	var src_total := {}
	var kills_total := 0
	var adds_total := 0
	var n := 0
	for run in runs:
		for fl in floors:
			main.climb_essence = {}
			main.climb_soak = {}
			main.essence_sources = {}
			var r: Dictionary = {}
			if thorough:
				r = await _play_thorough(fl)
			else:
				r = await Sweep.play(self, main, fl, 1.0)
			var e := 0.0
			for k in main.climb_essence:
				e += float(main.climb_essence[k])
			total += e
			n += 1
			var parts := []
			for pt in main.climb_soak:
				soak_total[pt] = float(soak_total.get(pt, 0.0)) + float(main.climb_soak[pt])
				parts.append("%s %.0f" % [pt, float(main.climb_soak[pt])])
			var srcs := []
			for s in main.essence_sources:
				src_total[s] = float(src_total.get(s, 0.0)) + float(main.essence_sources[s])
				srcs.append("%s %.1f" % [s, float(main.essence_sources[s])])
			kills_total += int(r.get("kills", 0))
			adds_total += int(r.get("add_kills", 0))
			print("MEASURE %s floor %2d  %s  essence %4.0f  kills %d (adds %d, left %d of %d planned)  by source: %s  soak: %s  adds: %s" % [tower, fl, "ok  " if r.get("ok", false) else "FAIL " + String(r.get("why", "")),
				e, int(r.get("kills", 0)), int(r.get("add_kills", 0)), int(r.get("left", 0)), int(r.get("planned", 0)), ", ".join(srcs), ", ".join(parts), r.get("adds_by", {})])
	var per := []
	for s in src_total:
		per.append("%s %.1f" % [s, float(src_total[s]) / maxf(1.0, n)])
	print("MEASURE %s total essence %.0f over %d floors (%.1f a floor); kills %.2f a floor (adds %.2f); a floor by source: %s" % [tower, total, n, total / maxf(1.0, n),
		float(kills_total) / maxf(1.0, n), float(adds_total) / maxf(1.0, n), ", ".join(per)])
	TestRun.finish()
	quit(0)


## One floor, played by the thorough bot (as Sweep.play, with the kills counted).
func _play_thorough(fl: int) -> Dictionary:
	var m = main
	var w0 := Time.get_ticks_msec()
	while (m.climbing or m.fade > 0.0) and Time.get_ticks_msec() - w0 < 10000:
		await process_frame
	m.camp_choosing = false
	m.in_camp = false
	m.player.set_physics_process(true)
	m._start_floor(fl)
	await process_frame
	m.banner = {}
	var p = m.player
	p.max_hp = 1500.0
	p.hp = 1500.0
	p.iframes = 0.0
	m.dev_no_death = true
	var planned := {}
	for e in m.enemies():
		planned[e.get_instance_id()] = true
	var seen := {}
	var slain0: int = m.profile.count("slain")
	var bot = Thorough.new()
	root.add_child(bot)
	bot.start(m, 600.0)
	m.test_speed = 1.0
	Engine.max_physics_steps_per_frame = 16
	var real0 := Time.get_ticks_msec()
	while not bot.done:
		await process_frame
		for e in m.enemies():
			if not seen.has(e.get_instance_id()):
				seen[e.get_instance_id()] = String(e.get_meta("add")) if e.has_meta("add") else String(e.kind)
		if Time.get_ticks_msec() - real0 > 900000:
			bot._finish(false, "real-time limit")
	m.dev_no_death = false
	Engine.time_scale = 1.0
	var r: Dictionary = bot.result
	bot.queue_free()
	var alive := {}
	for e in m.enemies():
		alive[e.get_instance_id()] = true
	var adds := 0
	var left := 0
	var by := {}  # what the adds slain were: an add's mark (essence.gd ADDS), else its kind
	for id in seen:
		if not planned.has(id) and not alive.has(id):
			adds += 1
			by[seen[id]] = int(by.get(seen[id], 0)) + 1
	for id in planned:
		if alive.has(id):
			left += 1
	r["kills"] = m.profile.count("slain") - slain0
	r["add_kills"] = adds
	r["adds_by"] = by
	r["left"] = left
	r["planned"] = planned.size()
	if m.climbing:
		for i in 90:
			await process_frame
			if not m.climbing:
				break
	return r
