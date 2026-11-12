extends RefCounted
## The Wyvern's and the Manticore's own floors (scripts/towers/): their
## layouts, their systems (molten channels, cranks, heat and water barrels;
## sun, shade and sand), their own tasks (Stoke the Furnaces, Wake the Sun
## Seals), their creatures (the forge golem, the burrower), their scenarios
## (Hold the Forge, the Sinking Court), reachability over many floors, and
## the floor bot doing their tasks. Run by smoke_test.gd (_part_tests).

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Styles := preload("res://scripts/floor_styles.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Wyv := preload("res://scripts/towers/wyvern_floor.gd")
const Man := preload("res://scripts/towers/manticore_floor.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

var t


func run(smoke) -> void:
	t = smoke
	_carving()
	_plans()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	main.dev_no_death = true
	await _wyvern_system()
	await _furnaces_task()
	await _golem()
	await _forge_scenario()
	await _manticore_system()
	await _sunstones_task()
	await _burrower()
	await _sinking_scenario()
	main.dev_no_death = false
	await _bot()
	main.tower = "kraken"
	Objectives.forced = ""


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The towers' own room shapes: the right size, a way in on every side.
func _carving() -> void:
	print("towers (Wyvern, Manticore): their own room shapes")
	var ok_size := true
	var ok_doors := true
	var ok_own := true
	for shape in ["workshop", "forgehall", "court", "colonnade", "alleys"]:
		ok_own = ok_own and Styles.shape_module(shape) != null
		for k in 20:
			var size := Vector2i(randi_range(9, 14), randi_range(7, 12))
			var rows := Rooms.prepare(Rooms.carve(shape, size))
			ok_size = ok_size and rows.size() == size.y and String(rows[0]).length() == size.x
			for side in 4:
				ok_doors = ok_doors and not Rooms.door_slots(rows, side).is_empty()
	_check(ok_own, "the Wyvern's and the Manticore's shapes are carved by their own scripts (floor_styles.gd SHAPE_MODULES)")
	_check(ok_size, "their carved rooms are the size asked")
	_check(ok_doors, "...and can take a doorway on every side")
	var rows := Rooms.carve("workshop", Vector2i(13, 10))
	_check("".join(PackedStringArray(rows)).count("#") >= 4 and String(rows[5])[6] == ".", "a workshop has benches in rows and a clear aisle down the middle")
	rows = Rooms.carve("court", Vector2i(12, 10))
	_check(String(rows[1]).count("o") >= 2 and String(rows[5])[5] == ".", "a court is ringed by a colonnade, open in the middle")


## Planned floors: the style applied, the systems laid, everything reachable.
func _plans() -> void:
	print("towers (Wyvern, Manticore): planned floors")
	var floors := [2, 3, 4, 5, 7, 8, 9, 10, 11]
	var n_per := 30
	for tid in ["wyvern", "manticore"]:
		var reach_ok := 0
		var mod_ok := true
		var own_shapes := 0
		var rooms := 0
		var stat := {"channels": 0, "cranks": 0, "gutters": 0, "furnaces": 0, "barrels": 0, "suns": 0, "shade": 0, "drifts": 0, "pits": 0}
		var bridges_ok := true
		var metal_solid := true
		var gate_ok := true
		var kinds := {}
		for n in n_per:
			Objectives.climb_used.clear()
			if n % 3 == 0:
				Objectives.forced = "furnaces" if tid == "wyvern" else "sunstones"
			var plan := Floors.rooms_floor(floors[n % floors.size()], Towers.TOWERS[tid])
			Objectives.forced = ""
			var c := Reach.plan_check(plan)
			if c["ok"]:
				reach_ok += 1
			var tf: Dictionary = plan.get("tower_floor", {})
			mod_ok = mod_ok and String(tf.get("module", "")) == String(Styles.STYLES[tid]["module"])
			for ri in plan["room_info"]:
				rooms += 1
				if String(ri["shape"]) in ["workshop", "forgehall", "hall", "court", "colonnade", "alleys"]:
					own_shapes += 1
			var k := String(plan["objective"].get("kind", ""))
			kinds[k] = true
			if tid == "wyvern":
				var g := Reach.plan_grid(plan)
				for ch in tf["channels"]:
					if ch.get("gutter", false):
						stat["gutters"] += 1
					else:
						stat["channels"] += 1
						bridges_ok = bridges_ok and ch["bridge"].size() >= 2
					if ch.has("crank"):
						stat["cranks"] += 1
						gate_ok = gate_ok and plan["lever_gates"].any(func(gt): return int(gt["lock_id"]) == int(ch["lock_id"]))
					for tile in ch["tiles"]:
						var solid: bool = g["solid"][tile.y * g["size"].x + tile.x] == 1
						metal_solid = metal_solid and (solid != (tile in ch["bridge"]))
				stat["furnaces"] += tf["furnaces"].size()
				stat["barrels"] += tf["barrels"].size()
			else:
				stat["suns"] += tf["suns"].size()
				stat["shade"] += tf["shade"].size()
				stat["drifts"] += tf["drifts"].size()
				stat["pits"] += tf["pits"].size()
		_check(mod_ok, "%s: every floor of rooms has the tower's own floor (its module)" % tid)
		_check(reach_ok == n_per, "%s: the stair, every room and the task are reachable on %d of %d floors (reach.gd)" % [tid, reach_ok, n_per])
		_check(own_shapes * 2 >= rooms, "%s: most rooms are carved in the tower's own shapes (%d of %d)" % [tid, own_shapes, rooms])
		if tid == "wyvern":
			_check(stat["channels"] >= n_per and stat["gutters"] >= n_per / 2, "wyvern: halls are cut by molten channels and lined with gutters (%s)" % stat)
			_check(bridges_ok and metal_solid, "...every channel has its bridge, and only the bridge crosses the metal (reach.gd sees the rest as rock)")
			_check(stat["cranks"] >= 3 and gate_ok, "...some bridges are raised, a crank's lever-gate (%d)" % stat["cranks"])
			_check(stat["furnaces"] >= n_per / 3 and stat["barrels"] >= n_per / 2, "...furnaces breathe heat and water barrels stand by")
			_check(kinds.has("furnaces"), "...Stoke the Furnaces is a task here")
		else:
			_check(stat["suns"] >= n_per and stat["shade"] >= n_per * 20 and stat["drifts"] >= n_per * 8, "manticore: courts in the sun, shaded walks and alleys, sand drifts (%s)" % stat)
			_check(stat["pits"] >= n_per / 5, "...and sand pits (%d)" % stat["pits"])
			_check(kinds.has("sunstones"), "...Wake the Sun Seals is a task here")
	# A tower's own kind never turns up in another tower; its scenario neither.
	var lone_own := true
	for n in 200:
		var k := Objectives.pick(3 + n % 8, "gryphon")
		lone_own = lone_own and not (k in ["furnaces", "sunstones"])
		Objectives.climb_used.clear()
	Objectives.forced = "furnaces"
	lone_own = lone_own and Objectives.pick(4, "kraken") != "furnaces" and Objectives.pick(4, "wyvern") == "furnaces"
	Objectives.forced = ""
	_check(lone_own, "the towers' own tasks only turn up in their own tower (even when forced)")
	_check(not ("forge" in Scenarios.kinds_for(9, "kraken")) and "forge" in Scenarios.kinds_for(9, "wyvern") and "sinking" in Scenarios.kinds_for(9, "manticore"), "...and so do their scenarios")


## A Wyvern floor with a raised bridge, made live.
func _wyvern_floor(want_crank := true, kind := ""):
	var main = t.main
	main.tower = "wyvern"
	main._apply_tower_look()
	Objectives.forced = kind
	for n in 40:
		main._start_floor(3 + n % 6)
		await t._frames(1)
		var tf = main.tower_floor
		if tf == null:
			continue
		if not want_crank or tf.channels.any(func(c): return c.has("crank")):
			break
	Objectives.forced = ""
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.banner = {}
	return main.tower_floor


func _wyvern_system() -> void:
	print("towers: the Wyvern's forge (metal, cranks, heat, water)")
	var main = t.main
	var tf = await _wyvern_floor()
	_check(tf != null and tf.get_script() == Wyv, "a Wyvern floor runs its own floor script (main.tower_floor)")
	if tf == null:
		return
	var p = main.player
	var ch: Dictionary = {}
	for c in tf.channels:
		if c.has("crank"):
			ch = c
	_check(not ch.is_empty(), "a floor has a bridge hauled up out of reach")
	if ch.is_empty():
		return
	var bt: Vector2i = ch["bridge"][0]
	_check(main.astar.is_point_solid(bt) and tf.is_molten(Wyv._world(bt)), "a raised bridge's tiles are metal: no path over them")
	# Walk into the metal: it stops you.
	var mt: Vector2i = ch["tiles"].filter(func(x): return not (x in ch["bridge"]))[0]
	var side := Vector2(1, 0) if ch["vertical"] else Vector2(0, 1)
	var from: Vector2 = Wyv._world(mt) - side * 60.0
	if main.is_solid(from):
		from = Wyv._world(mt) + side * 60.0
		side = -side
	p.global_position = from
	await t._frames(2)
	for i in 30:
		p.move_and_collide(side * 6.0)
	await t._frames(1)
	_check(not tf.is_molten(p.global_position), "walking into a molten channel, you stop at its edge")
	# The live check (reach.gd) sees the raised bridge as a lever's door.
	var solid: PackedByteArray = main.solid.duplicate()
	var doors: Array = []
	var opens := {}
	tf.reach_live(solid, main.grid_size, doors, opens)
	_check(doors.any(func(d): return int(d["lock_id"]) == int(ch["lock_id"])) and solid[mt.y * main.grid_size.x + mt.x] == 1, "the live check sees the metal as rock and the raised bridge as a gate its crank opens")
	# Strike the crank: the bridge comes down.
	p.global_position = ch["crank"] + Vector2(0, 30)
	tf.strike(p.global_position, Vector2.UP, 60.0, 60.0)
	await t._frames(2)
	_check(ch["lowered"] and not main.astar.is_point_solid(bt) and not tf.is_molten(Wyv._world(bt)), "striking its crank lowers the bridge: now it can be crossed")
	# Heat: stand in a furnace's blast and it builds; full, it hurts.
	if tf.furnaces.is_empty():
		tf.furnaces.append({"pos": p.global_position, "phase": 0.0, "quench": 0.0})
	var f: Dictionary = tf.furnaces[0]
	var cyc := float(Wyv.HEAT["cycle"])
	f["phase"] = fposmod(0.6 - Time.get_ticks_msec() / 1000.0 / cyc, 1.0)  # (just into its hot spell now)
	p.global_position = main.walkable_point(f["pos"], f["pos"] + Vector2(0, 40), 10.0)
	p.hp = p.max_health()
	tf.heat = 0.0
	var was: float = Reactions.CLIMBER["enabled"]
	Reactions.CLIMBER["enabled"] = false
	_check(tf.heat_at(p.global_position) >= 1.0, "a furnace's bellows blows hot: its heat reaches you (%.2f)" % tf.heat_at(p.global_position))
	await t._wait(0.5)
	_check(tf.heat > 0.1, "linger in the heat and it builds up on you (%.2f)" % tf.heat)
	tf.heat = 1.0
	var hp0: float = p.hp
	await t._wait(0.7)
	_check(p.hp < hp0, "full heat burns: heat damage every half second (the climber's states off)")
	Reactions.CLIMBER["enabled"] = true
	tf.heat = 1.0
	tf.heat_tick = 0.0
	await t._wait(0.2)
	_check(p.states.has("burning"), "...and with monsters' states on the climber, it sets you Burning")
	Reactions.CLIMBER["enabled"] = was
	p.states.clear()
	# A water barrel: quenches the heat, cools you, soaks foes.
	if tf.barrels.is_empty():
		tf.barrels.append({"pos": f["pos"] + Vector2(50, 0), "full": true, "t": 0.0})
	var b: Dictionary = tf.barrels[0]
	b["full"] = true
	f["pos"] = b["pos"] + Vector2(40, 0)
	var foe = main.spawn_enemy("knight", main.walkable_point(b["pos"], b["pos"] + Vector2(30, 0), 10.0))
	await t._frames(2)
	tf.heat = 0.9
	p.global_position = main.walkable_point(b["pos"], b["pos"] + Vector2(0, 30), 10.0)
	tf.strike(p.global_position, (b["pos"] - p.global_position).normalized(), 60.0, 60.0)
	await t._frames(1)
	_check(not b["full"] and tf.heat == 0.0 and f["quench"] > 0.0 and tf.heat_at(f["pos"]) == 0.0, "striking a water barrel quenches the furnace's heat and cools you")
	_check(foe.soaked > 0.0, "...and soaks the foes in its splash")
	foe.queue_free()
	await t._frames(1)


func _furnaces_task() -> void:
	print("towers: Stoke the Furnaces")
	var main = t.main
	var tf = await _wyvern_floor(false, "furnaces")
	var ob = main.objective
	_check(ob.kind == "furnaces" and ob.own_kind and ob.pieces.size() >= 2, "a Wyvern floor's task can be Stoke the Furnaces (%s, %d)" % [ob.kind, ob.pieces.size()])
	if ob.kind != "furnaces":
		return
	var p = main.player
	var pc: Dictionary = ob.pieces[0]
	_check(main.pillars.any(func(pl): return pl["pos"].distance_to(pc["furnace"]) < 2.0), "its furnaces stand solid")
	p.global_position = pc["pos"] + Vector2(0, 34)
	for i in int(Wyv.FURNACE["pumps"]) - 1:
		ob.strike(p.global_position, Vector2.UP, 60.0, 60.0)
		await t._wait(float(Wyv.FURNACE["gap"]) + 0.05)
	_check(pc["state"] == "doing" and float(pc["fire"]) > 0.5, "striking its bellows stokes the furnace (%.2f)" % float(pc["fire"]))
	_check(tf.heat_at(pc["furnace"] + Vector2(0, 30)) > 0.5, "...and a waking furnace throws its heat")
	var f0: float = pc["fire"]
	await t._wait(float(Wyv.FURNACE["rest"]) + 0.6)
	_check(float(pc["fire"]) < f0, "...which dies down if you dawdle")
	for i in 3:
		ob.strike(p.global_position, Vector2.UP, 60.0, 60.0)
		await t._wait(float(Wyv.FURNACE["gap"]) + 0.05)
	_check(pc["state"] == "done", "enough strikes and it roars: one furnace lit")
	_check(ob.status_line() == "Furnaces lit 1 of %d" % ob.pieces.size(), "the HUD counts the furnaces (%s)" % ob.status_line())
	for q in ob.pieces:
		if q["state"] != "done":
			p.global_position = q["pos"] + Vector2(0, 34)
			for i in int(Wyv.FURNACE["pumps"]):
				ob.strike(p.global_position, Vector2.UP, 60.0, 60.0)
				await t._wait(float(Wyv.FURNACE["gap"]) + 0.05)
	await t._frames(3)
	_check(ob.done and not main.ward, "all of them lit: the stair's ward lifts")


func _golem() -> void:
	print("towers: the forge golem")
	var main = t.main
	var p = main.player
	var e = main.spawn_enemy("golem", main.walkable_point(p.global_position, p.global_position + Vector2(140, 0), 14.0))
	await t._frames(2)
	_check(e.get_script() == load("res://scripts/towers/forge_golem.gd"), "a golem is spawned with its own script (enemy.gd SUBKINDS)")
	e.aware = true
	var h0: float = e.heat
	await t._wait(0.6)
	_check(e.heat > h0, "it heats up while it fights (%.2f -> %.2f)" % [h0, e.heat])
	e.heat = 0.95
	e.state = "chase"
	var hp0: float = e.hp
	e.take_hit(10.0, Vector2.RIGHT)
	var hot_cut: float = hp0 - e.hp
	_check(hot_cut > 0.0 and hot_cut < 7.0, "hot, it hardens: a blow does half (%.1f)" % hot_cut)
	for i in 20:
		e.heat = 1.0
		await t._wait(0.1)
		if e.state == "cool":
			break
	_check(e.state == "cool", "full, it has to vent: it slumps, cooling")
	hp0 = e.hp
	e.take_hit(10.0, Vector2.RIGHT)
	_check(hp0 - e.hp > 15.0, "cooling, it takes double (%.1f)" % (hp0 - e.hp))
	e.state = "chase"
	e.heat = 0.7
	e.soak(3.0)
	await t._wait(0.2)
	_check(e.state == "cool" and e.heat < 0.3, "water quenches a warm golem")
	var drop: Array = main.Essence.drop_for("golem", 5)
	_check(drop[0] == "iron" and float(drop[1]) > 0.0 and main.Floors.MONSTERS.has("golem") and Towers.TOWERS["wyvern"]["weights"].has("golem"), "it carries iron essence and joins the Wyvern's monsters")
	t._slay(e)
	await t._frames(2)


func _forge_scenario() -> void:
	print("towers: Hold the Forge")
	var main = t.main
	main.tower = "wyvern"
	var s := {}
	for n in 60:
		main._start_floor(3 + n % 7)
		await t._frames(1)
		for ss in main.scenarios.list:
			if ss["kind"] == "forge":
				s = ss
		if not s.is_empty():
			break
	_check(not s.is_empty(), "Wyvern floors have the forge's scenario room")
	if s.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var p = main.player
	p.global_position = s["start"]
	await t._frames(3)
	var tf = main.tower_floor
	_check(main.scenarios.running() and not tf.forge.is_empty() and s["furnaces"].size() == 3, "stepping onto its mark lights three furnaces and shuts the doors")
	await t._wait(2.2)  # (past its opening banner)
	var fires: Array = tf.forge["fires"]
	_check(fires[0] < 1.0, "the fires die down by themselves")
	var f0: float = fires[1]
	tf.strike(s["furnaces"][1] + Vector2(0, 30), Vector2.UP, 60.0, 60.0)
	_check(fires[1] > f0, "striking a furnace's bellows stokes it")
	_check(main.scenarios.status().get("line", "").begins_with("Lit 3 of 3"), "the HUD keeps count (%s)" % main.scenarios.status())
	s["t"] = float(Wyv.FORGE["time"]) - 0.1
	for i in 30:
		for e in main.enemies():
			t._slay(e)
		if s["state"] == "done":
			break
		await t._wait(0.1)
	_check(s["state"] == "done" and s["grade"] == "gold", "keep all three lit to the end: gold (%s)" % s.get("grade", ""))


## A Manticore floor made live.
func _manticore_floor(kind := ""):
	var main = t.main
	main.tower = "manticore"
	main._apply_tower_look()
	Objectives.forced = kind
	for n in 40:
		main._start_floor(3 + n % 6)
		await t._frames(1)
		var tf = main.tower_floor
		if tf != null and not tf.pits.is_empty() and not tf.suns.is_empty() and not tf.crumbles.is_empty():
			break
	Objectives.forced = ""
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.banner = {}
	return main.tower_floor


func _manticore_system() -> void:
	print("towers: the Manticore's sands (sun, shade, sand)")
	var main = t.main
	var tf = await _manticore_floor()
	_check(tf != null and tf.get_script() == Man, "a Manticore floor runs its own floor script")
	if tf == null:
		return
	var p = main.player
	# Shade hides you; the sun gives you away.
	var sh: Vector2i = tf.shade.keys()[0]
	p.global_position = Man._world(sh)
	await t._frames(3)
	_check(is_equal_approx(main.sight_k(), float(Man.SHADE["sight"])), "in the shade monsters notice you only from nearer (%.2f)" % main.sight_k())
	var foe = main.spawn_enemy("scorpling", main.walkable_point(p.global_position, p.global_position + Vector2(0, 260), 14.0))
	foe.aware = true
	await t._wait(0.5)
	_check(foe.global_position.distance_to(p.global_position) < float(Man.SHADE["lose"]) or foe.is_lost(), "...and one that's after you from afar loses track of you there")
	foe.queue_free()
	var s: Dictionary = tf.suns[0]
	var sr: Rect2 = tf._sun_rect(s).intersection(s["rect"])
	var spot := Vector2.INF
	for k in 40:
		var q := sr.position + Vector2(randf() * sr.size.x, randf() * sr.size.y)
		if not main.is_solid(q) and not tf.in_shade(q):
			spot = q
			break
	if spot != Vector2.INF:
		p.global_position = spot
		await t._frames(3)
		_check(is_equal_approx(main.sight_k(), float(Man.SUN["sight"])), "in the sun you're seen from farther (%.2f)" % main.sight_k())
	var x0: float = tf._sun_at(s)
	_check(float(s["hi"]) > float(s["lo"]), "the sun shaft moves across its court (now at %.0f)" % x0)
	# Sand slows; a pit pulls you to its sink and swallows you.
	var dr: Vector2i = tf.sand.keys()[0]
	_check(main.water_slow(Man._world(dr)) < 1.0 and main.water_slow(Man._world(dr), true) == 1.0, "a sand drift slows you (not a flier)")
	var pit: Dictionary = tf.pits[0]
	p.global_position = pit["pos"] + Vector2(pit["r"] - 16.0, 0)
	tf.last_out = pit["pos"] + Vector2(pit["r"] + 30.0, 0)
	await t._frames(2)
	var d0: float = p.global_position.distance_to(pit["pos"])
	await t._wait(0.3)
	_check(p.global_position.distance_to(pit["pos"]) < d0, "a sand pit pulls you toward its sink")
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	tf.swallow_cd = 0.0
	p.global_position = pit["pos"] + Vector2(4, 0)
	await t._frames(3)
	_check(p.hp < p.max_health() and p.global_position.distance_to(pit["pos"]) > float(pit["r"]), "the sink swallows you: it hurts, and spits you out at the edge")
	# Cracked flagstones give way after you cross.
	var cr: Vector2i = tf.crumbles.keys()[0]
	p.global_position = Man._world(cr)
	await t._frames(3)
	p.global_position = Man._world(cr) + Vector2(0, 80) if not main.is_solid(Man._world(cr) + Vector2(0, 80)) else Man._world(cr) + Vector2(0, -80)
	await t._wait(float(Man.SAND["crumble_t"]) + 0.3)
	_check(float(tf.crumbles[cr]) < 0.0 and tf.is_sand(Man._world(cr)), "a cracked flagstone crumbles into sand once you've crossed it")


func _sunstones_task() -> void:
	print("towers: Wake the Sun Seals")
	var main = t.main
	var tf = await _manticore_floor("sunstones")
	var ob = main.objective
	_check(ob.kind == "sunstones" and ob.pieces.size() >= 2, "a Manticore floor's task can be Wake the Sun Seals (%s)" % ob.kind)
	if ob.kind != "sunstones":
		return
	var p = main.player
	var pc: Dictionary = ob.pieces[0]
	var f0: int = pc["face"]
	p.global_position = pc["pos"] + Vector2(0, 34)
	ob.strike(p.global_position, Vector2.UP, 60.0, 60.0)
	_check(int(pc["face"]) == (f0 + 1) % 8, "striking a sun stone turns it an eighth")
	# Sun on the stone, facing away: nothing; facing its seal: it wakes.
	var per := float(Man.SEAL["period"])
	for q in ob.pieces:
		q["phase"] = fposmod(0.17 - Time.get_ticks_msec() / 1000.0 / per, 1.0)  # (its skylight coming over it now)
	pc["face"] = (int(pc["want"]) + 4) % 8
	await t._wait(0.4)
	_check(tf.stone_lit(pc) and pc["state"] != "done" and float(pc["charge"]) == 0.0, "the sun on a stone facing away lights nothing")
	pc["face"] = pc["want"]
	await t._wait(float(Man.SEAL["charge"]) + 0.3)
	_check(pc["state"] == "done", "turned to face its seal while the sun is on it: the seal wakes")
	for q in ob.pieces:
		q["face"] = q["want"]
		q["phase"] = fposmod(0.17 - Time.get_ticks_msec() / 1000.0 / per, 1.0)
	await t._wait(float(Man.SEAL["charge"]) + 0.4)
	_check(ob.done and not main.ward, "every seal awake: the stair's ward lifts")


func _burrower() -> void:
	print("towers: the burrower")
	var main = t.main
	var tf = main.tower_floor
	if tf == null or tf.get_script() != Man:
		tf = await _manticore_floor()
	var p = main.player
	var dr: Vector2i = tf.sand.keys()[0]
	var e = main.spawn_enemy("burrower", Man._world(dr))
	e.global_position = Man._world(dr)
	await t._frames(2)
	_check(e.get_script() == load("res://scripts/towers/burrower.gd") and e.submerged, "a burrower waits under the sand, out of reach")
	var hp0: float = e.hp
	e.take_hit(10.0, Vector2.RIGHT)
	_check(e.hp == hp0, "...where blows can't touch it")
	_check(not (e in main.targets()), "...and nothing can aim at it")
	# Lured onto stone, it comes up exposed.
	var stone := Vector2.INF
	for k in 12:
		var q: Vector2 = e.global_position + Vector2.from_angle(k * TAU / 12.0) * 70.0
		if not main.is_solid(q) and not tf.is_sand(q):
			stone = q
			break
	if stone != Vector2.INF:
		e.global_position = stone
		e.aware = true
		await t._wait(0.3)
		_check(not e.submerged and e.state in ["crawl", "wind_bite", "up", "recover", "sink"], "on stone it must come up: exposed (%s)" % e.state)
		e.state = "crawl"
		hp0 = e.hp
		e.take_hit(10.0, Vector2.RIGHT)
		_check(hp0 - e.hp > 12.0, "exposed, it takes more from every blow (%.1f)" % (hp0 - e.hp))
	# On sand near you it erupts beneath you.
	e.global_position = Man._world(dr)
	e.state = "sub"
	e.submerged = true
	p.global_position = Man._world(dr) + Vector2(20, 0)
	p.iframes = 0.0
	p.hurt_t = 0.0
	var tf_sand: bool = tf.is_sand(p.global_position)
	var erupted := false
	for i in 30:
		await t._wait(0.05)
		if e.state == "wind_erupt" or e.state == "up":
			erupted = true
			break
	_check(erupted or not tf_sand, "standing on sand near it, it marks the spot and erupts beneath you (%s)" % e.state)
	_check(main.Essence.drop_for("burrower", 5)[0] == "stone" and Towers.TOWERS["manticore"]["weights"].has("burrower"), "it carries stone essence and joins the Manticore's monsters")
	t._slay(e)
	await t._frames(2)


func _sinking_scenario() -> void:
	print("towers: the Sinking Court")
	var main = t.main
	main.tower = "manticore"
	var s := {}
	for n in 60:
		main._start_floor(2 + n % 8)
		await t._frames(1)
		for ss in main.scenarios.list:
			if ss["kind"] == "sinking":
				s = ss
		if not s.is_empty():
			break
	_check(not s.is_empty(), "Manticore floors have the Sinking Court")
	if s.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var p = main.player
	var tf = main.tower_floor
	p.global_position = s["start"]
	await t._frames(3)
	_check(main.scenarios.running() and not tf.sink.is_empty(), "stepping onto its mark starts the floor giving way")
	await t._wait(float(Man.SINK["grace"]) + 2.4)  # (its opening banner, then the grace)
	var sunk: Dictionary = tf.sink["sunk"]
	_check(not sunk.is_empty(), "behind you the floor turns to quicksand (%d tiles)" % sunk.size())
	# Stand in the quicksand: it drags you under.
	var qs := Vector2i(-1, -1)
	for k in sunk:
		if not tf.sink["stones"].has(k):
			qs = k
			break
	if qs.x >= 0:
		p.hurt_t = 0.0
		p.iframes = 0.0
		p.global_position = Man._world(qs)
		var hits0: int = tf.sink["hits"]
		await t._wait(1.4)
		_check(int(tf.sink.get("hits", hits0 + 1)) > hits0, "stand in it too long and it swallows you (onto the nearest stone)")
	_check(tf.slow_at(Man._world(qs)) < 1.0 if qs.x >= 0 else true, "...and it slows you")
	p.global_position = s["end"]
	await t._frames(3)
	_check(s["state"] == "done" and s["grade"] in ["gold", "silver", "bronze"], "reach the far gate: graded (%s)" % s.get("grade", ""))
	_check(tf.sink.is_empty(), "...and the quicksand settles into sand")


## The floor bot does the towers' own tasks.
func _bot() -> void:
	print("towers: the floor bot on the Wyvern's and the Manticore's floors")
	var main = t.main
	var ok := 0
	var why: Array = []
	for pair in [["wyvern", "furnaces", 4], ["manticore", "sunstones", 5]]:
		main.tower = pair[0]
		Objectives.forced = pair[1]
		var r: Dictionary = await Sweep.play(t, main, pair[2], 2.0)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s %s: %s %s" % [pair[0], pair[1], r["why"], r.get("log", [])])
	_check(ok == 2, "the bot finishes a Wyvern and a Manticore floor doing their own tasks (%d of 2) %s" % [ok, why])
