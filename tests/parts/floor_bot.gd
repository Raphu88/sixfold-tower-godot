extends RefCounted
## Floors of rooms, played: the floor's one task (objectives.gd), rooms that
## all pay off, no lock on the way to the stair, loops, cracked walls,
## scenario rooms, and the floor bot (tests/floor_bot_driver.gd) playing
## real floors through the same inputs a controller gives, doing the task
## and reaching the stair. The heavier sweep: tests/floor_bot_sweep.gd.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Themes := preload("res://scripts/themes.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

var t


func run(smoke) -> void:
	t = smoke
	_plans()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	await _task_in_play()
	await _cracks()
	await _scenario()
	await _bot()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## Floor plans: one task each, its pieces spread, no repeat in a climb, no
## lock on the way, every room paying off, loops and cracked walls.
func _plans() -> void:
	print("floors: the task, payoffs, locks, loops and cracked walls (plans)")
	var ok_task := true
	var ok_spread := true
	var ok_start := true
	var ok_nolock := true
	var ok_pay := true
	var ok_quiet := true
	var ok_lockpay := true
	var ok_cracks_opt := true
	var loops := 0
	var cracks := 0
	var oneway := 0
	var kinds := {}
	for tid in Towers.ORDER:
		Objectives.climb_used.clear()
		var used: Array = []
		var fresh := true
		for fl in [2, 3, 4, 5, 7, 8, 9, 10, 11]:
			var plan := Floors.rooms_floor(fl, Towers.TOWERS[tid])
			var obj: Dictionary = plan.get("objective", {})
			ok_task = ok_task and not obj.is_empty() and plan.get("ok", false)
			if obj.is_empty():
				continue
			kinds[obj["kind"]] = true
			fresh = fresh and not (obj["kind"] in used)
			used.append(obj["kind"])
			Objectives.climb_used.append(obj["kind"])
			var rooms := {}
			for pc in obj["pieces"]:
				rooms[int(pc["room"])] = true
				ok_start = ok_start and int(pc["room"]) != 0
			if not obj.get("puzzle", false) and obj["pieces"].size() >= 2 and obj["kind"] != "runes":  # (the runes share their hall)
				ok_spread = ok_spread and rooms.size() >= 2
			# No lock on the way: with every locked door shut for good, the
			# stair and every piece are still reached.
			var g := Reach.plan_grid(plan)
			var doors: Array = []
			for d in plan["doors"] + plan["wings"]:
				var tiles: Array = d["door"] if d.get("kind", "") == "wing" else d["tiles"]
				var kind := String(d.get("lock", ""))
				doors.append({"tiles": tiles, "lock": "lever" if kind in ["key", "carried", "lever", "puzzle"] else kind, "lock_id": int(d.get("lock_id", 0))})
				ok_lockpay = ok_lockpay and (kind in ["", "oneway"] or d.get("kind", "") == "wing" or plan["themes"][int(d["room"])] == "strongroom")
			var opens := {}
			for d in plan["doors"]:
				if String(d.get("lock", "")) == "oneway":
					opens[int(d["lock_id"])] = {"any": d["lock_side"]}
			var f := Reach.flood(g["size"], g["solid"], Reach.tile(plan["start"]), doors, opens)
			ok_nolock = ok_nolock and Reach.near_reached(f["reach"], g["size"], plan["stair"])
			for p in Objectives.targets(obj):
				ok_nolock = ok_nolock and Reach.near_reached(f["reach"], g["size"], p)
			var m := Sweep.measure(plan)
			ok_pay = ok_pay and int(m["nopay"]) == 0
			ok_quiet = ok_quiet and not ("quiet" in plan["themes"])
			loops += int(plan["loops"])
			oneway += plan["doors"].filter(func(d): return d.get("lock", "") == "oneway").size()
			cracks += plan["cracks"].size()
			for c in plan["cracks"]:
				ok_cracks_opt = ok_cracks_opt and c["tiles"].size() >= 1 and not c["faces"].is_empty()
		ok_task = ok_task and fresh
	_check(ok_task, "every floor of rooms has one task that lifts the stair's ward, never the same kind twice in a climb")
	_check(ok_spread and ok_start, "the task's pieces lie in several rooms, never the start room")
	_check(ok_nolock, "no lock on the way: the stair and every piece of the task are reached with every lock shut")
	_check(ok_lockpay, "a lock only guards something worth it (a strongroom or a sealed wing)")
	_check(ok_pay and ok_quiet, "every room pays off (no quiet halls, no empty dead ends)")
	_check(loops >= 54 and oneway > 0, "floors loop: extra ways between rooms, some barred from one side (%d over 54 floors, %d barred)" % [loops, oneway])
	_check(cracks >= 40 and ok_cracks_opt, "cracked walls on most floors (%d over 54)" % cracks)
	_check(kinds.size() >= 12, "many kinds of task turn up (%s)" % [kinds.keys()])


## The task in play: the banner, the HUD's line, the arrow, and the stair's reward.
func _task_in_play() -> void:
	print("floors: the task in play")
	var main = t.main
	Objectives.forced = "shards"
	main._start_floor(4)
	Objectives.forced = ""
	await t._frames(2)
	for e in main.enemies():
		e.set_physics_process(false)
	var ob = main.objective
	_check(ob.kind == "shards" and main.ward and not main.stair_open, "the stair is warded until the task is done")
	_check(main.hud.goal_line() == Objectives.KINDS["shards"]["status"] % [0, ob.pieces.size()], "the HUD keeps its line (%s)" % main.hud.goal_line())
	var goal: Array = main.hud.arrow_goal()
	_check(not goal.is_empty() and goal[1] == "Shard", "the arrow points at the nearest piece still to do")
	for pc in ob.pieces:
		main.player.global_position = pc["pos"]
		await t._frames(3)
	await t._frames(2)
	_check(ob.done and not main.ward and main.stair_open, "gathering every piece lifts the ward (%d of %d)" % [ob.done_count(), ob.pieces.size()])
	_check(main.banner.get("title", "") == Objectives.TEXT["done_title"] and not ob.reliquary.is_empty(), "...the stair is unsealed, with a reliquary beside it")
	goal = main.hud.arrow_goal()
	_check(not goal.is_empty() and goal[0] == main.stair_pos, "...and then the arrow points at the stair")
	main.player.global_position = ob.reliquary["pos"]
	await t._frames(3)
	_check(main.camp_choosing and main.camp["choices"].size() == 3, "the reliquary offers one of three")
	if main.camp_choosing:
		main.choose_camp(0)
	await t._frames(1)


## A cracked wall: a light blow knocks hollow, a finisher breaks it.
func _cracks() -> void:
	print("floors: cracked walls")
	var main = t.main
	var c := {}
	for n in 30:
		main._start_floor(3 + n % 6)
		await t._frames(1)
		for cc in main.cracks.list:
			if cc["kind"] != "loop":
				c = cc
				break
		if not c.is_empty():
			break
	_check(not c.is_empty(), "floors have cracked walls with something behind them")
	if c.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var f: Dictionary = c["faces"][0]
	var face: Vector2 = main.room.position + (Vector2(f["tile"]) + Vector2(0.5, 0.5)) * 40.0
	var p = main.player
	_check(main.is_solid(face), "a cracked wall is solid")
	p.global_position = face + Vector2(f["out"]) * 46.0
	p.aim = -Vector2(f["out"])
	var knocks: int = main.cracks.knocks
	main.cracks.strike(p.global_position, p.aim, 60.0, 60.0, false)
	_check(main.cracks.knocks == knocks + 1 and not c["broken"], "a light blow knocks hollow")
	main.cracks.strike(p.global_position, p.aim, 60.0, 60.0, true)
	await t._frames(2)
	_check(c["broken"] and not main.is_solid(face), "a finishing blow breaks it")
	p.global_position = c["reward"]["pos"]
	await t._frames(3)
	_check(c["taken"] or main.camp_choosing, "what was behind it can be taken")
	if main.camp_choosing:
		main.choose_camp(0)
	# A burst breaks one too.
	var c2 := {}
	for n in 30:
		main._start_floor(3 + n % 6)
		await t._frames(1)
		if not main.cracks.list.is_empty():
			c2 = main.cracks.list[0]
			break
	if not c2.is_empty():
		var f2: Dictionary = c2["faces"][0]
		main.explode(main.room.position + (Vector2(f2["tile"]) + Vector2(0.5, 0.5)) * 40.0 + Vector2(f2["out"]) * 40.0, 50.0, 1.0, Color.WHITE)
		_check(c2["broken"], "a burst (a bomb, a spell) breaks one too")


## A scenario room: step on the mark, play it, be graded and noticed.
func _scenario() -> void:
	print("floors: scenario rooms")
	var main = t.main
	var s := {}
	for n in 40:
		main._start_floor(3 + n % 6)
		await t._frames(1)
		for ss in main.scenarios.list:
			if ss["kind"] == "gauntlet":
				s = ss
		if not s.is_empty():
			break
	_check(not s.is_empty(), "floors have scenario rooms")
	if s.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var noticed: int = main.noticed.size()
	main.player.global_position = s["start"]
	await t._frames(3)
	_check(main.scenarios.running(), "stepping onto its mark begins it")
	for i in 60:
		if s["state"] == "done":
			break
		for e in main.enemies():
			t._slay(e)
		await t._wait(0.2)
	_check(s["state"] == "done" and s["grade"] in ["gold", "silver", "bronze"], "beating it gives a grade (%s)" % s.get("grade", ""))
	_check(main.noticed.size() == noticed + 1 and main.banner.get("title", "").ends_with("NOTICED"), "...and the beast notices (%s)" % main.banner.get("title", ""))


## The bot plays real floors to the stair.
func _bot() -> void:
	print("floors: the floor bot")
	var main = t.main
	var kinds := ["braziers", "orb", "runes", "statues"]
	var towers := ["gryphon", "wyvern", "firebird", "chimera"]
	var floors := [2, 5, 3, 7]
	var ok := 0
	var why: Array = []
	for i in kinds.size():
		main.tower = towers[i]
		Objectives.forced = kinds[i]
		var r: Dictionary = await Sweep.play(t, main, floors[i], 2.0)  # (twice as fast: the parts run has no --fixed-fps)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s %d %s: %s" % [towers[i], floors[i], kinds[i], r["why"]])
	main.tower = "kraken"
	_check(ok >= kinds.size() - 1, "the bot finishes real floors: walks, fights, does the task, takes the stair (%d of %d) %s" % [ok, kinds.size(), why])
