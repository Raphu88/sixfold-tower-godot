extends RefCounted
## The Kraken's and the Gryphon's own floors (scripts/towers/): their
## layouts (winding corridors, round rooms and water; open halls, drops and
## bridges), their systems (water levels that slow, soak and stop you;
## voids you fall through, the floors below, the wind), their tasks
## (sluices, vanes), their creatures (the deepfin, the harrier), their
## scenarios (the Filling Room, the Long Bridge), reachability over many
## floors, and the floor bot on both. Run by smoke_test.gd (_part_tests).

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const K := preload("res://scripts/towers/kraken_floor.gd")
const G := preload("res://scripts/towers/gryphon_floor.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

var t


func run(smoke) -> void:
	t = smoke
	_layouts()
	_reach()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	main.dev_no_death = true
	await _water()
	await _sluices()
	await _deepfin()
	await _flood_room()
	await _voids()
	await _vanes()
	await _harrier()
	await _long_bridge()
	_data()
	await _bot()
	main.dev_no_death = false
	main.tower = "kraken"


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _plan(tid: String, fl: int, kind := "") -> Dictionary:
	Objectives.forced = kind
	Objectives.climb_used.clear()
	var plan: Dictionary = Floors.rooms_floor(fl, Towers.TOWERS[tid])
	Objectives.forced = ""
	return plan


## A floor of the tower with something on it (tries a few floors).
func _floor_with(tid: String, fl: int, kind: String, want: Callable) -> bool:
	var main = t.main
	main.tower = tid
	for n in 60:
		Objectives.forced = kind
		Objectives.climb_used.clear()
		main._start_floor(fl + n % 4)
		Objectives.forced = ""
		await t._ticks(1)
		if want.call(main):
			for e in main.enemies():
				e.set_physics_process(false)
			return true
	return false


# --- layouts -------------------------------------------------------------------------

func _layouts() -> void:
	print("towers: the Kraken's and the Gryphon's layouts")
	K.STATS = {"corridors": 0, "long": 0, "wound": 0}
	var circles := 0
	var rooms := 0
	var basins := {}
	var tagged := true
	for k in 12:
		var plan := _plan("kraken", [3, 5, 8, 10][k % 4])
		tagged = tagged and plan.get("tower_floor", {}).get("module", "") == K.PATH
		for ri in plan.get("room_info", []):
			rooms += 1
			circles += 1 if ri["shape"] == "circle" else 0
		for b in plan.get("water", {}).get("basins", []):
			basins[b["kind"]] = int(basins.get(b["kind"], 0)) + 1
	_check(tagged, "the Kraken's floors are built by its own floor script")
	_check(K.STATS["long"] > 0 and K.STATS["wound"] >= K.STATS["long"] / 2, "its corridors wind and twist (%d of %d long ones)" % [K.STATS["wound"], K.STATS["long"]])
	_check(circles * 3 >= rooms, "its rooms are mostly round and oval (%d of %d)" % [circles, rooms])
	_check(basins.get("tide", 0) > 0 and basins.get("pool", 0) > 0 and basins.get("flood", 0) + basins.get("sunken", 0) > 0, "its floors hold water: tides, pools, floods or sunken rooms %s" % [basins])
	var with_voids := 0
	var bridged := 0
	var tagged_g := true
	for k in 12:
		var plan := _plan("gryphon", [3, 5, 8, 10][k % 4])
		tagged_g = tagged_g and plan.get("tower_floor", {}).get("module", "") == G.PATH
		if not plan.get("voids", []).is_empty():
			with_voids += 1
		if not plan.get("sky_bridges", []).is_empty() or int(plan.get("bridged_corridors", 0)) > 0:
			bridged += 1
	_check(tagged_g, "the Gryphon's floors are built by its own floor script")
	_check(with_voids >= 11, "its halls open onto drops (%d of 12 floors)" % with_voids)
	_check(bridged >= 6, "...crossed by bridges and walkways (%d of 12)" % bridged)
	# Other towers keep their plain corridors and no tower system.
	var plain := _plan("wyvern", 5)
	_check(not plain.has("water") and not plain.has("voids") and String(plain.get("tower_floor", {}).get("module", "")) != K.PATH, "other towers keep their own floors (no water, no drops)")


## Reachability: over dozens of floors of each, the stair, every room and
## lock can be reached with deep water and drops as walls; deep water and
## drops only ever take a second way, except the task's own moat or gap,
## which really does shut the stair room until the task opens it.
func _reach() -> void:
	print("towers: reachability over many floors")
	for tid in ["kraken", "gryphon"]:
		var bad: Array = []
		var only_way_ok := true
		var gate_ok := true
		var tasks := 0
		for k in 30:
			var fl: int = [2, 3, 4, 5, 7, 8, 9, 10, 11][k % 9]
			var kind := ("sluices" if tid == "kraken" else "vanes") if k % 3 == 0 else ""
			var plan := _plan(tid, fl, kind)
			var c := Reach.plan_check(plan)
			if not c["ok"] or not plan.get("ok", false):
				bad.append("%d: %s" % [fl, c["problems"]])
				continue
			var g := Reach.plan_grid(plan)
			var start := Reach.tile(plan["start"])
			var block := {}
			for fl2 in plan.get("gates", []):
				for tt in fl2["tiles"]:
					block[tt] = true
			var walked := Grid.walk(g, start, block)
			var st := Reach.tile(plan["stair"])
			var reached_stair := Reach.near_reached(walked, g["size"], plan["stair"])
			var task_kind := String(plan.get("objective", {}).get("kind", ""))
			if task_kind in ["sluices", "vanes"]:
				tasks += 1
				gate_ok = gate_ok and not reached_stair  # (the moat or gap shuts it)
			else:
				# No task gate: a sunken room's water never stands between you and the stair.
				only_way_ok = only_way_ok and reached_stair
		_check(bad.is_empty(), "%s: every floor's stair, rooms and locks can be reached (%s)" % [tid, bad])
		_check(only_way_ok, "%s: deep water and drops are never the only way to the stair" % tid)
		_check(tasks >= 8 and gate_ok, "%s: the task's moat or gap really shuts the stair room until it's done (%d floors)" % [tid, tasks])


# --- the Kraken's water --------------------------------------------------------------

func _water() -> void:
	print("towers: the Kraken's water")
	var main = t.main
	var ok: bool = await _floor_with("kraken", 5, "", func(m): return m.tower_floor != null and m.tower_floor.basins.any(func(b): return b["kind"] == "pool"))
	_check(ok and main.tower_floor != null, "a Kraken floor runs its water")
	if not ok:
		return
	var tf = main.tower_floor
	var p = main.player
	# A tide at its high: shallow water slows you.
	var tide: Dictionary = {}
	for b in tf.basins:
		if b["kind"] == "tide" and b.get("shape", "") == "channel":
			tide = b
			break
	if tide.is_empty():
		for b in tf.basins:
			if b["kind"] == "tide":
				tide = b
				break
	tide["phase"] = 0.5 - tf.t / float(tide["period"])  # (high tide now)
	tf._tick_levels(0.0, true)
	var wet_at: Vector2 = Grid.centre(tide["tiles"][tide["tiles"].size() / 2])
	if tide.get("shape", "") == "ellipse":
		wet_at = tide["c"]
	_check(tide["level"] >= K.WATER["shallow"] and main.in_water(wet_at) and is_equal_approx(main.water_slow(wet_at), 0.6), "at high tide the water is shallow: it slows you (level %.2f)" % tide["level"])
	tide["phase"] = 0.0 - tf.t / float(tide["period"])  # (low tide)
	tf._tick_levels(0.0, true)
	_check(not main.in_water(wet_at), "...and at low tide it drains away")
	# A pool: deep, solid to walkers, out of the monsters' paths.
	var pool: Dictionary = tf.basins.filter(func(b): return b["kind"] == "pool")[0]
	var pt: Vector2i = pool["tiles"][0]
	var lt: Vector2i = main._tile_of(Grid.centre(pt))
	_check(pool["deep"] and tf.deep_at(Grid.centre(pt)) and main.astar.is_point_solid(lt), "a round room's pool is deep: monsters path round it")
	# Walk the climber at it: deep water stops you.
	var edge: Vector2 = tf._nearest_dry(Grid.centre(pt), int(pool["id"]))
	p.global_position = edge
	p.velocity = Vector2.ZERO
	var into: Vector2 = (Grid.centre(pt) - edge).normalized()
	for i in 40:
		p.knock = into * 200.0
		await t.physics_frame
	_check(not tf.deep_at(p.global_position), "deep water can't be waded: the climber stops at its edge")
	# A flooding corridor: deep at high tide, wadeable at low; whoever's in it is swept out.
	var flood: Dictionary = {}
	for b in tf.basins:
		if b["kind"] == "flood":
			flood = b
	if not flood.is_empty():
		flood["phase"] = 0.5 - tf.t / float(flood["period"])
		tf._tick_levels(0.0, true)
		_check(flood["deep"], "a loop corridor floods deep at high tide")
		flood["phase"] = -tf.t / float(flood["period"])
		tf._tick_levels(0.0, true)
		_check(not flood["deep"] and not main.astar.is_point_solid(main._tile_of(Grid.centre(flood["tiles"][0]))), "...and opens again as it drains")
		p.global_position = Grid.centre(flood["tiles"][0])
		flood["level"] = K.WATER["deep"] + 0.01
		flood["phase"] = 0.5 - tf.t / float(flood["period"])
		tf._tick_levels(0.016, false)
		_check(flood["swept"] and p.knock.length() > 100.0, "rising deep water sweeps the climber out")
	# A sunken room drained by its wheel.
	ok = await _floor_with("kraken", 3, "", func(m): return m.tower_floor != null and not m.tower_floor.valves.is_empty())
	_check(ok, "Kraken floors have sunken rooms behind sluice wheels")
	if ok:
		tf = main.tower_floor
		var v: Dictionary = tf.valves[0]
		var b: Dictionary = tf.basins[int(v["basin"])]
		_check(b["deep"], "...its water deep until the wheel is turned")
		for e in main.enemies():
			e.queue_free()
		p.knock = Vector2.ZERO  # (the sweep above may still be carrying the climber)
		p.velocity = Vector2.ZERO
		var at_wheel := func():
			p.global_position = v["pos"]  # (stand at it: nothing may push you off meanwhile)
			return v["done"]
		await t._until(at_wheel, K.WATER["wheel_time"] + 3.0)
		_check(v["done"] and float(b["target"]) < K.WATER["shallow"], "standing at the wheel turns it: the room drains")
		for i in 40:
			if not b["deep"]:
				break
			await t._game_wait(0.15)
		_check(not b["deep"] and not main.astar.is_point_solid(main._tile_of(Grid.centre(b["tiles"][0]))), "...and the room can be walked (its chest on the bottom in reach)")
		var spilled := false
		for x in tf.basins:
			spilled = spilled or (x["kind"] == "tide" and int(x["room"]) == int(v["room"]) and x["spill_t"] > 0.0)
		_check(spilled or not tf.basins.any(func(x): return x["kind"] == "tide" and int(x["room"]) == int(v["room"])), "...sending its water into the wheel's room")


func _sluices() -> void:
	print("towers: the Kraken's task, the sluices")
	var main = t.main
	var ok: bool = await _floor_with("kraken", 4, "sluices", func(m): return m.objective.kind == "sluices")
	_check(ok, "the Kraken's floors can have the sluices task")
	if not ok:
		return
	var tf = main.tower_floor
	var ob = main.objective
	var moat: Dictionary = tf.basins.filter(func(b): return b["kind"] == "moat")[0]
	_check(moat["deep"] and main.ward, "the stair room's passage is flooded deep and the stair warded")
	_check(ob.status_line() == Objectives.KINDS["sluices"]["status"] % [0, ob.pieces.size()], "the HUD keeps its line (%s)" % ob.status_line())
	for e in main.enemies():
		e.queue_free()
	var p = main.player
	var first_target := 0.92
	p.knock = Vector2.ZERO
	p.max_hp = 999.0
	p.hp = 999.0
	for pc in ob.pieces:
		for e in main.enemies():  # (a hurt climber's wheel slips back: keep foes away)
			e.queue_free()
		var at_wheel := func():
			p.global_position = pc["pos"]
			return pc["state"] == "done"
		await t._until(at_wheel, Objectives.KINDS["sluices"]["turn_time"] + 3.0)
		if ob.done_count() == 1:
			first_target = float(moat["target"])
	_check(first_target < 0.9, "each wheel turned lowers the water a step (%.2f)" % first_target)
	_check(ob.done and not main.ward, "turning every wheel does the task: the ward lifts")
	for i in 60:
		if not moat["deep"]:
			break
		await t._game_wait(0.15)
	_check(not moat["deep"] and not main.astar.is_point_solid(main._tile_of(Grid.centre(moat["tiles"][0]))), "...and the stairwell drains: the way to the stair is open")
	var live := Reach.live_check(main)
	_check(not live["checked"] or live["stair"], "the stair can be reached")


func _deepfin() -> void:
	print("towers: the deepfin")
	var main = t.main
	var ok: bool = await _floor_with("kraken", 5, "", func(m): return m.tower_floor != null and m.tower_floor.basins.any(func(b): return b["kind"] == "pool"))
	if not ok:
		_check(false, "a floor with a pool for the deepfin")
		return
	var tf = main.tower_floor
	for e in main.enemies():
		e.queue_free()
	await t._ticks(1)
	var pool: Dictionary = tf.basins.filter(func(b): return b["kind"] == "pool")[0]
	var at: Vector2 = Grid.centre(pool["tiles"][0])
	var e = main.spawn_enemy("deepfin", at)
	e.max_hp = 9999.0  # (struck below: it must outlive the checks)
	e.hp = 9999.0
	e.aware = true
	e.notice_t = 0.0
	await t._ticks(2)
	_check(e.submerged and not main.targets().has(e), "under the water a deepfin can't be struck or aimed at")
	var p = main.player
	p.global_position = tf._nearest_dry(at, int(pool["id"]))
	p.iframes = 999.0
	var states := {}
	for i in 240:
		states[e.state] = true
		if e.state == "stranded" or e.state == "crawl":
			break
		await t.physics_frame
	_check(states.has("rise") and states.has("wind"), "it rises and glints when you come to the water (%s)" % [states.keys()])
	# Out of the water: stranded, soaked, exposed.
	e.global_position = p.global_position + Vector2(0, 30)
	e.state = "stranded"
	e.state_t = 2.0
	e.submerged = false
	await t._ticks(3)
	_check(not e.submerged and main.targets().has(e) and main.Reactions.has(e, "soaked"), "out of the water it's soaked through (lightning arcs through it)")
	var hp0: float = e.hp
	e.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(hp0 - e.hp > 10.0, "...and every blow lands harder (%.1f)" % (hp0 - e.hp))
	e.queue_free()
	# With no deep water to live in, it keeps to the shallows as a lurker.
	main.tower = "wyvern"
	main._start_floor(3)
	await t._ticks(1)
	var f = main.spawn_enemy("deepfin", main.player.global_position + Vector2(120, 0))
	f.aware = true
	await t._ticks(3)
	_check(f.kind == "lurker", "without deep water it lives as a lurker does")
	f.queue_free()
	_check(load("res://scripts/essence.gd").DROPS.has("deepfin") and main.Floors.MONSTERS.has("deepfin") and Towers.TOWERS["kraken"]["weights"].has("deepfin"), "it drops water essence and spawns in the Kraken's tower")


func _flood_room() -> void:
	print("towers: the Filling Room")
	var main = t.main
	var saved := {}
	for k in Scenarios.SCENARIOS:
		saved[k] = Scenarios.SCENARIOS[k]["from"]
		if k != "flood":
			Scenarios.SCENARIOS[k]["from"] = 99
	var ok: bool = await _floor_with("kraken", 3, "", func(m): return m.scenarios.list.any(func(s): return s["kind"] == "flood"))
	for k in saved:
		Scenarios.SCENARIOS[k]["from"] = saved[k]
	_check(ok, "Kraken floors have the Filling Room")
	if not ok:
		return
	var s: Dictionary = main.scenarios.list.filter(func(x): return x["kind"] == "flood")[0]
	for e in main.enemies():
		e.queue_free()
	var p = main.player
	p.global_position = s["start"]
	await t._ticks(3)
	_check(main.scenarios.running() and main.tower_floor.scn_basin >= 0, "stepping onto its mark begins it: the water comes in")
	await t._until(func(): return float(main.tower_floor.basins[main.tower_floor.scn_basin]["level"]) > 0.0, 5.0)
	var lvl: float = main.tower_floor.basins[main.tower_floor.scn_basin]["level"]
	_check(lvl > 0.0, "...rising (%.2f)" % lvl)
	_check(not main.scenarios.status().is_empty(), "the HUD follows it (%s)" % main.scenarios.status().get("line", ""))
	p.global_position = s["wheel"]
	for i in 80:
		if s["state"] == "done":
			break
		for e in main.enemies():
			t._slay(e)
		p.global_position = s["wheel"]
		await t._game_wait(0.1)
	_check(s["state"] == "done" and s["grade"] in ["gold", "silver", "bronze"], "turning the drain wheel in time gives a grade (%s)" % s.get("grade", ""))


# --- the Gryphon's heights -----------------------------------------------------------

func _voids() -> void:
	print("towers: the Gryphon's drops, the floors below, the wind")
	var main = t.main
	var ok: bool = await _floor_with("gryphon", 5, "", func(m): return m.tower_floor != null and m.tower_floor.voids.size() > 4)
	_check(ok, "a Gryphon floor has open drops")
	if not ok:
		return
	var tf = main.tower_floor
	for e in main.enemies():
		e.queue_free()
	var vt: Vector2i = tf.voids.keys()[0]
	_check(main.in_chasm(Grid.centre(vt)) and main.astar.is_point_solid(main._tile_of(Grid.centre(vt))), "a drop is a chasm you fall through, and out of the monsters' paths")
	_check(not tf.lower.is_empty() and not tf.air_rects.is_empty(), "through the drops and past the walls, the floors below are drawn")
	# The wind: it shoves you near a drop.
	var p = main.player
	var ex: Vector2i = tf.exposed.keys()[0]
	p.global_position = Grid.centre(ex)
	p.knock = Vector2.ZERO
	tf.gust_state = "blow"
	tf.gust_t = 1.0
	tf.gust_dir = Vector2.RIGHT
	for i in 8:
		tf.gust_state = "blow"
		tf.gust_t = 1.0
		tf._tick_gust(1.0 / 60.0)
	_check(p.knock.dot(Vector2.RIGHT) > 50.0, "a gust shoves you near a drop (%.0f)" % p.knock.x)
	tf.gust_state = "calm"
	tf.gust_t = 99.0
	p.knock = Vector2.ZERO
	# An airborne foe over a drop falls.
	var slime = main.spawn_enemy("slime", Grid.centre(ex))
	await t._ticks(1)
	var fell_before: int = main.floor_total
	slime.airborne = 0.5
	slime.global_position = Grid.centre(vt)
	tf._tick_falls()
	slime.airborne = 0.0
	tf._tick_falls()
	await t._ticks(1)
	_check(not is_instance_valid(slime) or slime.dead, "a foe thrown into the air comes down over a drop and falls")
	# The climber falls to the floor below.
	var fl0: int = main.floor_num
	p.global_position = Grid.centre(vt)
	p.iframes = 0.0
	for i in 90:
		if main.floor_num < fl0:
			break
		await t._game_wait(0.05)
	_check(main.floor_num == fl0 - 1, "stepping off an edge drops you to the floor below (%d -> %d)" % [fl0, main.floor_num])
	for i in 100:  # (let the fall finish: the floor below is built at the end of its fade)
		if not main.climbing and main.fade <= 0.0:
			break
		await t._game_wait(0.05)
	await t._ticks(2)


func _vanes() -> void:
	print("towers: the Gryphon's task, the wind vanes")
	var main = t.main
	var ok: bool = await _floor_with("gryphon", 4, "vanes", func(m): return m.objective.kind == "vanes")
	_check(ok, "the Gryphon's floors can have the vanes task")
	if not ok:
		return
	var tf = main.tower_floor
	var ob = main.objective
	_check(not tf.span.is_empty() and main.ward and not tf.span_open, "no bridge reaches the stair room: an open gap")
	var st: Vector2i = tf.span.keys()[0]
	_check(main.in_chasm(Grid.centre(st)), "...you'd fall through it")
	for e in main.enemies():
		e.queue_free()
	var p = main.player
	for pc in ob.pieces:
		p.global_position = pc["pos"] + Vector2(0, 40)
		for k in int(Objectives.KINDS["vanes"]["strikes"]):
			ob.strike(p.global_position, Vector2.UP, 60.0, 60.0)
	await t._ticks(3)
	_check(ob.done and not main.ward, "striking every vane round does the task")
	_check(tf.span_open and not main.in_chasm(Grid.centre(st)) and not main.astar.is_point_solid(main._tile_of(Grid.centre(st))), "...and the wind blows across the gap: you can walk it")


func _harrier() -> void:
	print("towers: the harrier")
	var main = t.main
	var ok: bool = await _floor_with("gryphon", 5, "", func(m): return m.tower_floor != null and m.tower_floor.voids.size() > 4)
	if not ok:
		_check(false, "a floor with drops for the harrier")
		return
	var tf = main.tower_floor
	for e in main.enemies():
		e.queue_free()
	await t._ticks(1)
	var p = main.player
	p.global_position = Grid.centre(tf.exposed.keys()[0])
	var stand: Vector2 = p.global_position
	tf.gust_state = "calm"  # (no gust may shove the climber out of its path, or pass for its knock)
	tf.gust_t = 999.0
	p.knock = Vector2.ZERO
	# (in sight: it dives only at what it sees; a spot round the climber with a clear line)
	var in_sight := func() -> Vector2:
		for k in 8:
			var q: Vector2 = main.walkable_point(p.global_position, p.global_position + Vector2(140, 0).rotated(k * TAU / 8.0), 14.0)
			if q.distance_to(p.global_position) > 60.0 and main.clear_line(q, p.global_position):
				return q
		return main.walkable_point(p.global_position, p.global_position + Vector2(140, 0), 14.0)
	var e = main.spawn_enemy("harrier", in_sight.call())
	e.aware = true
	e.notice_t = 0.0
	await t._ticks(2)
	_check(float(e.get_meta("h", 0.0)) > 20.0 and e.kind in e.FLIERS, "a harrier soars high over the halls")
	var states := {}
	p.hp = p.max_hp
	p.iframes = 0.0
	p.hurt_t = 0.0
	var hit := false
	var thrown := 0.0
	for i in 900:
		states[e.state] = true
		if p.hp < p.max_hp:
			hit = e.lunge_hit  # (its own strike, not something else)
			thrown = p.knock.length()
			break
		p.global_position = stand
		p.velocity = Vector2.ZERO
		p.iframes = 0.0
		p.hurt_t = 0.0
		e.state_t = minf(e.state_t, 0.3) if e.state == "soar" else e.state_t
		if i % 240 == 239 and e.state == "soar" and not main.clear_line(e.global_position, p.global_position):
			e.global_position = in_sight.call()  # (circling, it slipped behind a wall: it can't dive at what it can't see)
		await t.physics_frame
	_check(states.has("wind_dive") and states.has("dive"), "it dives at you with a glint (%s; %d px, can attack %s, aware %s, lost %s, state_t %.2f, script %s)" % [states.keys(), int(e.global_position.distance_to(p.global_position)), main.can_attack(), e.aware, e.is_lost(), e.state_t, e.get_script().resource_path])
	_check(hit and thrown > 150.0, "its strike throws you the way it flew (%d)" % int(thrown))
	tf.gust_t = 2.0
	# Parried near a drop: it falls.
	e.global_position = tf._nearest_floor(Grid.centre(tf.voids.keys()[0]))
	_check(tf.near_void(e.global_position, 75.0), "it stands on a ledge")
	e.on_parried(false)
	await t._ticks(1)
	_check(not is_instance_valid(e) or e.dead, "parried on a ledge, it tumbles over the edge and falls")
	_check(load("res://scripts/essence.gd").DROPS.has("harrier") and Towers.TOWERS["gryphon"]["weights"].has("harrier"), "it drops air essence and spawns in the Gryphon's tower")


func _long_bridge() -> void:
	print("towers: the Long Bridge")
	var main = t.main
	var saved := {}
	for k in Scenarios.SCENARIOS:
		saved[k] = Scenarios.SCENARIOS[k]["from"]
		if k != "bridge":
			Scenarios.SCENARIOS[k]["from"] = 99
	var ok: bool = await _floor_with("gryphon", 3, "", func(m): return m.scenarios.list.any(func(s): return s["kind"] == "bridge"))
	for k in saved:
		Scenarios.SCENARIOS[k]["from"] = saved[k]
	_check(ok, "Gryphon floors have the Long Bridge")
	if not ok:
		return
	var s: Dictionary = main.scenarios.list.filter(func(x): return x["kind"] == "bridge")[0]
	var tf = main.tower_floor
	var drop := 0
	for tt in Grid.tiles_of(s["rect"]):
		drop += 1 if tf.voids.has(tt) else 0
	_check(drop >= 8, "its hall falls away but for the bridge (%d tiles of drop)" % drop)
	for e in main.enemies():
		e.queue_free()
	var p = main.player
	p.global_position = s["start"]
	await t._ticks(3)
	_check(main.scenarios.running(), "stepping onto its mark begins it")
	await t._until(func(): return main.enemies().any(func(x): return x.kind == "harrier"), 8.0)  # (its intro, then the first raptor)
	var raptors: int = main.enemies().filter(func(x): return x.kind == "harrier").size()
	_check(raptors >= 1, "raptors come diving out of the open air (%d; %s, spawns %d)" % [raptors, s["state"], s["spawns"].size()])
	for e in main.enemies():
		t._slay(e)
	p.global_position = s["end"]
	await t._until(func(): return s["state"] == "done", 2.0)
	_check(s["state"] == "done" and s["grade"] in ["gold", "silver", "bronze"], "reaching the far perch gives a grade (%s)" % s.get("grade", ""))


# --- data and the bot ----------------------------------------------------------------

func _data() -> void:
	var Reg = load("res://scripts/data_registry.gd")
	var tables: Array = []
	for sec in Reg.SECTIONS:
		tables.append_array(sec["tables"])
	var need := ["towers.kraken_floor/WATER", "towers.kraken_floor/TEXT", "towers.gryphon_floor/VOIDS", "towers.gryphon_floor/GUST", "towers.gryphon_floor/TEXT",
		"towers.deepfin/DEEPFIN", "towers.harrier/HARRIER", "towers.deepfin/DEEPFIN_TEXT", "towers.harrier/HARRIER_TEXT"]
	_check(need.all(func(x): return x in tables), "the towers' numbers and words are in the Data editor")
	_check(Objectives.KINDS["sluices"]["towers"] == ["kraken"] and Objectives.KINDS["vanes"]["towers"] == ["gryphon"] and not Objectives.allowed("sluices", "gryphon"), "each tower's own task comes up only there")
	_check(Scenarios.kinds_for(5, "kraken").has("flood") and not Scenarios.kinds_for(5, "gryphon").has("flood") and Scenarios.kinds_for(5, "gryphon").has("bridge"), "each tower's own scenario comes up only there")


func _bot() -> void:
	print("towers: the floor bot on the Kraken's and the Gryphon's floors")
	var main = t.main
	var plays := [["kraken", 4, "sluices"], ["gryphon", 4, "vanes"], ["kraken", 7, "shards"], ["gryphon", 7, "braziers"]]
	var ok := 0
	var why: Array = []
	for pl in plays:
		main.tower = pl[0]
		Objectives.forced = pl[2]
		var r: Dictionary = await Sweep.play(t, main, pl[1], 2.0)
		if not r["ok"]:
			why.append("(first try) %s %d %s: %s" % [pl[0], pl[1], pl[2], String(r["why"]).left(80)])
			r = await Sweep.play(t, main, pl[1], 2.0)  # (the bot is no player: a floor that beats it gets one fresh floor)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s %d %s: %s" % [pl[0], pl[1], pl[2], r["why"]])
	_check(ok >= plays.size() - 1, "the bot finishes the towers' floors, their own tasks included (%d of %d; a floor that beats it gets one fresh floor) %s" % [ok, plays.size(), why])
