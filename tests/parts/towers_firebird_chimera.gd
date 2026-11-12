extends RefCounted
## The Firebird's and the Chimera's own floors: islands over the abyss
## (updrafts, burning bridges, ember storms), the Thornwild (living thorns,
## brambles, spore pods), their own tasks (Rekindle the Beacons, the
## Hungry Grove), creatures (the ashwing, the briar) and scenarios (the
## Burning Bridge, the Closing Thicket), and reachability over many floors.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Organic := preload("res://scripts/towers/organic.gd")
const Rooms := preload("res://scripts/rooms.gd")
const FB := preload("res://scripts/towers/firebird_floor.gd")
const CH := preload("res://scripts/towers/chimera_floor.gd")
const Creatures := preload("res://scripts/towers/creatures.gd")

var t


func run(smoke) -> void:
	t = smoke
	_shapes()
	_plans()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	await _firebird_system()
	await _rekindle()
	await _ashwing()
	await _burning_bridge()
	await _thornwild_system()
	await _heartroots()
	await _briar()
	await _thicket()
	await _bots()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A floor of a tower with a task forced (and its foes still).
func _floor(tid: String, n: int, kind := "") -> void:
	var main = t.main
	main.tower = tid
	Objectives.forced = kind
	main._start_floor(n)
	Objectives.forced = ""
	await t._frames(2)
	main.banner = {}
	for e in main.enemies():
		e.set_physics_process(false)


func _sys(name: String):
	for s in t.main.tower_systems:
		if (name == "firebird" and s.has_method("set_burnt")) or (name == "chimera" and s.has_method("add_thorn")):
			return s
	return null


# --- layouts ----------------------------------------------------------------------------

func _shapes() -> void:
	print("towers (firebird, chimera): grown and broken room shapes")
	var ok_mouth := true
	var ok_irregular := true
	var ok_hole := false
	for shape in Organic.SHAPES:
		for k in 12:
			var size := Vector2i(randi_range(8, 14), randi_range(7, 12))
			var rows := Rooms.prepare(Organic.carve(shape, size))
			for side in 4:
				ok_mouth = ok_mouth and not Rooms.door_slots(rows, side).is_empty()
			var mid := size.x / 2
			for y in 3:
				for x in range(mid - 2, mid + 2):
					ok_mouth = ok_mouth and Rooms.open_at(rows, x, y)
			var rock := 0
			for r in rows:
				rock += String(r).count("X")
			ok_irregular = ok_irregular and rock >= 4
			if shape == "atoll" and mini(size.x, size.y) >= 9:
				ok_hole = ok_hole or String("".join(PackedStringArray(rows))).contains("C")
	_check(ok_mouth, "grown rooms keep a mouth on every side (corridors meet them) and floor under the stair")
	_check(ok_irregular and ok_hole, "...and they aren't boxes: ragged outlines, an atoll's hole of chasm")


func _plans() -> void:
	print("towers (firebird, chimera): floor plans and reachability")
	var fb := {"gaps": 0, "burning": 0, "storms": 0, "spires": 0, "organic": 0, "rooms": 0, "bad": [], "floors": 0}
	var ch := {"thorns": 0, "closing": 0, "brambles": 0, "pods": 0, "organic": 0, "rooms": 0, "bad": [], "floors": 0, "on_way": 0}
	for k in 4:
		for fl in [2, 3, 4, 5, 7, 8, 9, 10, 11]:
			var plan := Floors.rooms_floor(fl, Towers.TOWERS["firebird"], false)
			fb["floors"] += 1
			var c := Reach.plan_check(plan)
			if not c["ok"] or not plan.get("ok", false):
				fb["bad"].append("floor %d: %s" % [fl, c["problems"]])
			var d: Dictionary = plan.get("firebird", {})
			fb["gaps"] += d.get("gaps", []).size()
			fb["burning"] += d.get("burning", []).size()
			fb["storms"] += d.get("storms", []).size()
			for s in d.get("storms", []):
				fb["spires"] += int(s.get("spires", 0))
			for ri in plan.get("room_info", []):
				fb["rooms"] += 1
				if Organic.is_shape(String(ri["shape"])):
					fb["organic"] += 1
			for g in d.get("gaps", []):
				fb["ok_gap"] = fb.get("ok_gap", true) and plan["chasms"].has(g["rect"]) and g["vents"].size() == 2
			plan = Floors.rooms_floor(fl, Towers.TOWERS["chimera"], false)
			ch["floors"] += 1
			c = Reach.plan_check(plan)
			if not c["ok"] or not plan.get("ok", false):
				ch["bad"].append("floor %d: %s" % [fl, c["problems"]])
			var w: Dictionary = plan.get("thornwild", {})
			for th in w.get("thorns", []):
				ch["thorns"] += 1
				if th["kind"] == "closing":
					ch["closing"] += 1
			ch["brambles"] += w.get("brambles", []).size()
			ch["pods"] += w.get("pods", []).size()
			for ri in plan.get("room_info", []):
				ch["rooms"] += 1
				if Organic.is_shape(String(ri["shape"])):
					ch["organic"] += 1
			# Thorns stand on walkable floor (they're cut, never needed rock): the
			# stair is reached with them as floor, as reach.gd sees them.
			for th in w.get("thorns", []):
				for tt in th["tiles"]:
					ch["on_way"] += 1 if Reach.plan_grid(plan)["solid"][tt.y * Reach.plan_grid(plan)["size"].x + tt.x] == 0 else 0
				break
	_check(fb["bad"].is_empty(), "the Firebird's floors: the stair, every room and the task are always reachable (%d floors) %s" % [fb["floors"], fb["bad"]])
	_check(ch["bad"].is_empty(), "the Thornwild's floors: the stair, every room and the task are always reachable (%d floors) %s" % [ch["floors"], ch["bad"]])
	_check(fb["organic"] * 10 >= fb["rooms"] * 6 and ch["organic"] * 10 >= ch["rooms"] * 6, "most rooms are grown or broken, not boxes (Firebird %d of %d, Thornwild %d of %d)" % [fb["organic"], fb["rooms"], ch["organic"], ch["rooms"]])
	_check(fb["gaps"] >= 18 and fb.get("ok_gap", false) and fb["burning"] >= 18 and fb["storms"] >= 20 and fb["spires"] >= 20,
		"the Firebird lays updraft gaps, burning bridges and ember storms with rock to shelter behind (%d, %d, %d, %d spires)" % [fb["gaps"], fb["burning"], fb["storms"], fb["spires"]])
	_check(ch["thorns"] >= 50 and ch["closing"] >= 12 and ch["brambles"] >= 30 and ch["pods"] >= 60 and ch["on_way"] > 0,
		"the Thornwild lays thorn walls, closing thickets, brambles and spore pods (%d, %d, %d, %d)" % [ch["thorns"], ch["closing"], ch["brambles"], ch["pods"]])
	# The towers' own kinds stay home.
	var leak := false
	for i in 300:
		leak = leak or Objectives.pick(5, "kraken") in ["rekindle", "heartroots"] or Objectives.pick(5, "firebird") == "heartroots"
	_check(not leak and "rekindle" in Objectives.all_kinds() and Objectives.allowed("rekindle", "firebird") and not Objectives.allowed("rekindle", "gryphon"),
		"Rekindle and the Hungry Grove are their towers' own tasks, never elsewhere")
	_check("burning_bridge" in Scenarios.kinds_for(4, "firebird") and not ("burning_bridge" in Scenarios.kinds_for(4, "kraken")) and "thicket" in Scenarios.kinds_for(4, "chimera"),
		"the Burning Bridge and the Closing Thicket are their towers' own scenarios")


# --- the Firebird -------------------------------------------------------------------------

func _firebird_system() -> void:
	print("towers: the Firebird's islands (updrafts, burning bridges, ember storms)")
	var main = t.main
	var fb = _sys("firebird")
	var found := false
	for i in 30:
		await _floor("firebird", 7, "shards")
		if not fb.gaps.is_empty() and not fb.bridges.is_empty() and not fb.storms.is_empty():
			found = true
			break
	_check(found and fb.on and main.room_view.layout_painter == fb, "a Firebird floor wakes its system and paints the abyss")
	if not found:
		return
	var open := 0
	for v in main.sight_open:
		open += int(v)
	_check(open > 100, "you can see across the abyss to other islands (%d tiles open to the eye)" % open)
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	# An updraft carries you over a gap too wide to jump.
	var g: Dictionary = fb.gaps[0]
	var v: Dictionary = g["vents"][0]
	var floor0: int = main.floor_num
	p.global_position = Rect2(v["rect"]).get_center()
	await t._until(func(): return fb.carries > 0, 1.0)
	await t._until(func(): return p.jump_t <= 0.0, 3.0)
	await t._frames(3)
	_check(fb.carries == 1 and main.floor_num == floor0 and p.global_position.distance_to(v["to"]) < 30.0 and not Rect2(g["rect"]).has_point(p.global_position),
		"stepping onto a vent, the updraft carries you across the gap (%s from the landing)" % str(p.global_position.distance_to(v["to"])))
	# A bridge burns behind you once you've crossed, and regrows.
	var b: Dictionary = fb.bridges[0]
	var keep_regrow: float = FB.RULES["regrow"]
	FB.RULES["regrow"] = 1.0
	p.global_position = b["a"]
	await t._frames(3)
	p.global_position = Rect2(b["slice"]).get_center()
	await t._frames(3)
	p.global_position = b["b"]
	await t._frames(3)
	var far: Vector2 = b["b"] + (Vector2(b["b"]) - Vector2(b["a"])).normalized() * 50.0
	p.global_position = far
	await t._frames(3)
	_check(b["state"] == "smoulder", "crossing a burning bridge sets it smouldering behind you")
	await t._until(func(): return b["state"] == "burnt", 3.0)
	var gone: bool = main.in_chasm(Rect2(b["slice"]).get_center())
	await t._until(func(): return b["state"] == "whole", 3.0)
	_check(gone and b["state"] == "whole" and not main.in_chasm(Rect2(b["slice"]).get_center()), "...a slice of it falls away into the abyss, then regrows from embers")
	FB.RULES["regrow"] = keep_regrow
	# An ember storm: caught in the open it burns you; behind rock it passes over.
	var s: Dictionary = fb.storms[0]
	var rect: Rect2 = s["rect"]
	var spot := Vector2.INF
	var cover := Vector2.INF
	for y in range(int(rect.position.y) + 20, int(rect.end.y), 40):
		for x in range(int(rect.position.x) + 20, int(rect.end.x), 40):
			var q := Vector2(x, y)
			if main.is_solid(q) or main.in_chasm(q):
				continue
			if not fb.shelter(s, q) and spot == Vector2.INF:
				spot = q
			if fb.shelter(s, q) and cover == Vector2.INF:
				cover = q
	_check(spot != Vector2.INF and cover != Vector2.INF, "a storm island has open ground and ground sheltered behind rock")
	if spot != Vector2.INF:
		s["t"] = float(FB.RULES["every"]) - float(s["phase"]) - 0.05  # (the sweep is about to begin)
		p.global_position = spot
		p.iframes = 0.0
		var hp0: float = p.hp
		await t._until(func(): return fb.storm_hits > 0, float(FB.RULES["sweep"]) + 1.0)
		_check(fb.storm_hits == 1 and p.hp < hp0, "an ember storm sweeping across the island burns a climber caught in the open")
	if cover != Vector2.INF:
		s["t"] = float(FB.RULES["every"]) * 2.0 - float(s["phase"]) - 0.05
		s["hit"] = {}
		p.global_position = cover
		await t._until(func(): return fb.sheltered > 0, float(FB.RULES["sweep"]) + 1.0)
		_check(fb.sheltered >= 1, "...and passes over one sheltered behind rock")


func _rekindle() -> void:
	print("towers: Rekindle the Beacons")
	var main = t.main
	await _floor("firebird", 5, "rekindle")
	var ob = main.objective
	_check(ob.kind == "rekindle" and ob.custom != null and main.ward, "the Firebird's task can be Rekindle the Beacons")
	if ob.custom == null:
		return
	var rk = ob.custom
	_check(rk.extras.size() >= 2 and rk.extras[0]["kind"] == "hearth" and rk.burn >= 14.0 and ob.pieces.size() >= 2, "a hearth, braziers and beacons; the flame lasts %.0f s" % rk.burn)
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	p.global_position = ob.pieces[0]["pos"]
	await t._frames(3)
	_check(ob.pieces[0]["state"] == "todo", "a beacon won't light without a flame")
	p.global_position = rk.extras[0]["pos"]
	await t._frames(3)
	_check(rk.carrying and main.hud.goal_line().contains("%"), "walking up to the hearth takes a flame (%s)" % main.hud.goal_line())
	p.global_position = main.player_start
	await t._frames(2)
	rk.flame = 0.05
	await t._wait(0.3)
	_check(not rk.carrying, "...which gutters out if it isn't carried in time")
	for pc in ob.pieces:
		p.global_position = rk.extras[0]["pos"]
		await t._frames(2)
		p.global_position = pc["pos"]
		await t._frames(3)
	await t._frames(2)
	_check(ob.done and not main.ward, "carrying the flame to every beacon lifts the ward")
	var b2 := FB.new()
	_check(load("res://scripts/towers/rekindle.gd").burn_time([Vector2.ZERO], [Vector2(2000, 0)], 10) > 30.0, "the flame always lasts the longest leg (a far beacon gets more time)")
	b2.free()


func _ashwing() -> void:
	print("towers: the ashwing rises from its ashes")
	var main = t.main
	await _floor("firebird", 4, "shards")
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	var at: Vector2 = p.global_position + Vector2(0, -60)
	var a = await t._spawn("ashwing", at)
	_check(a.kind in a.FLIERS and Creatures.has("ashwing") and main.Floors.MONSTERS.has("ashwing") and Towers.TOWERS["firebird"]["weights"].has("ashwing"), "the ashwing is the Firebird's, a flier, in its tower's mix")
	a.take_hit(9999.0, Vector2.ZERO, 0.0)
	await t._frames(1)
	_check(not a.dead and a.state == "ashes", "struck down, it sinks into a heap of glowing ash")
	a.set_physics_process(true)
	a.state_t = 0.1
	await t._wait(0.3)
	_check(not a.dead and a.state != "ashes" and a.get_meta("reborn", false) and a.hp < a.max_hp, "...and rises again (at %d of %d health)" % [int(a.hp), int(a.max_hp)])
	a.take_hit(9999.0, Vector2.ZERO, 0.0)
	_check(a.dead, "the second time it falls for good")
	var b = await t._spawn("ashwing", at)
	b.take_hit(9999.0, Vector2.ZERO, 0.0)
	b.take_hit(1.0, Vector2.RIGHT, 50.0)
	_check(b.dead, "a blow on its ash scatters it: it won't rise")
	var c = await t._spawn("ashwing", at)
	c.take_hit(9999.0, Vector2.ZERO, 0.0)
	c.soaked = 2.0
	c.set_physics_process(true)
	await t._frames(3)
	_check(not is_instance_valid(c) or c.dead, "soaked ash won't rise either")


func _burning_bridge() -> void:
	print("towers: the Burning Bridge")
	var main = t.main
	var fb = _sys("firebird")
	var sc := {}
	var keep: float = main.Floors.Styles.STYLES["default"]["scenario"]
	for i in 40:
		await _floor("firebird", 4, "shards")
		for s in main.scenarios.list:
			if s["kind"] == "burning_bridge":
				sc = s
		if not sc.is_empty():
			break
	_check(not sc.is_empty() and sc["steps"].size() >= 2 and main.in_chasm(Rect2(sc["chasms"][0]).get_center()), "a Firebird room can be the Burning Bridge: a chasm and a bridge across it")
	if sc.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	p.global_position = sc["start"]
	await t._until(func(): return sc["state"] == "run", 3.0)
	var mobs: int = sc["mobs"].size()
	await t._until(func(): return int(sc["burnt"]) >= 1, 3.0)
	var first: Rect2 = sc["steps"][0]
	_check(mobs >= 2 and int(sc["burnt"]) >= 1 and main.in_chasm(first.get_center()), "stepping onto the mark, the bridge starts burning behind you and foes come from the far side")
	for e in sc["mobs"]:
		if is_instance_valid(e):
			e.set_physics_process(false)
	p.global_position = sc["end"]
	await t._frames(3)
	_check(sc["state"] == "done" and sc["grade"] in ["gold", "silver", "bronze"], "reaching the far side ends it with a grade (%s)" % sc["grade"])
	await t._wait(1.8)
	_check(not main.in_chasm(first.get_center()), "...and the bridge knits back")
	main.Floors.Styles.STYLES["default"]["scenario"] = keep


# --- the Thornwild ------------------------------------------------------------------------

func _thornwild_system() -> void:
	print("towers: the Thornwild (thorns, closing thickets, brambles, spore pods)")
	var main = t.main
	var ch = _sys("chimera")
	var found := false
	for i in 30:
		await _floor("chimera", 7, "shards")
		if ch.on and not ch.grown().is_empty() and not ch.bramble.is_empty() and ch.pods.size() >= 2 and ch.thorns.any(func(x): return x["kind"] == "closing"):
			found = true
			break
	_check(found and main.room_view.layout_painter == ch, "a Thornwild floor wakes its system and paints its grown rock")
	if not found:
		return
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	var th: Dictionary = ch.grown()[0]
	var c: Vector2 = Rect2(th["rect"]).get_center()
	_check(th["body"] != null and main.astar.is_point_solid(th["tiles"][0]), "a thorn wall blocks the way (and monsters' paths)")
	var side: Vector2 = c + (Vector2(-50, 0) if Rect2(th["rect"]).size.y > Rect2(th["rect"]).size.x else Vector2(0, -50))
	if main.is_solid(side):
		side = c - (side - c)
	ch.strike(side, (c - side).normalized(), 50.0, 60.0, false)
	_check(th["state"] == "grown", "one light blow only scores it")
	ch.strike(side, (c - side).normalized(), 50.0, 60.0, false)
	_check(th["state"] == "cut" and th["body"] == null and not main.astar.is_point_solid(th["tiles"][0]), "a second blow cuts through (any weapon will do)")
	var keep_r: float = CH.RULES["regrow"]
	CH.RULES["regrow"] = 0.3
	th["t"] = 0.3
	p.global_position = c
	await t._wait(0.6)
	_check(th["state"] == "cut", "it never grows back onto someone standing in it")
	p.global_position = c + Vector2(200, 200)
	if main.is_solid(p.global_position):
		p.global_position = main.player_start
	await t._until(func(): return th["state"] == "grown", 2.0)
	_check(th["state"] == "grown", "...but grows back once the way is clear")
	CH.RULES["regrow"] = keep_r
	main.explode(c, 40.0, 1.0, Color(1, 0.5, 0.2))
	_check(th["state"] == "cut" and th["fire"], "fire burns a thorn wall away at once")
	# A closing thicket: open as you pass, shut behind you.
	var cl: Dictionary = ch.thorns.filter(func(x): return x["kind"] == "closing")[0]
	var cc: Vector2 = Rect2(cl["rect"]).get_center()
	_check(cl["state"] == "open" and cl["body"] == null, "a closing thicket stands open")
	p.global_position = cc
	await t._wait(0.3)
	var cor: Rect2 = cl["corridor"]
	var away: Vector2 = main.player_start
	p.global_position = away
	await t._until(func(): return cl["state"] == "grown", 2.5)
	_check(cl["state"] == "grown", "...until you've gone through: then it grows closed behind you")
	# Brambles slow you; a foe knocked into them bleeds.
	var bt: Vector2i = ch.bramble.keys()[0]
	var bpos: Vector2 = main.room.position + (Vector2(bt) + Vector2(0.5, 0.5)) * 40.0
	_check(main.water_slow(bpos) < 0.7 and main.water_slow(bpos + Vector2(4000, 4000)) == 1.0, "brambles slow whoever walks them")
	var e = await t._spawn("slime", bpos)
	e.knock = Vector2(300, 0)
	ch._tick_brambles()
	_check(e.bleeding > 0.0, "...and a foe knocked into them bleeds")
	e.queue_free()
	# Spore pods: poison hurts what stands in the cloud, calm soothes foes.
	var pois: Array = ch.pods.filter(func(x): return x["kind"] == "poison")
	var calm: Array = ch.pods.filter(func(x): return x["kind"] == "calm")
	var pd: Dictionary = pois[0] if not pois.is_empty() else ch.pods[0]
	pd["kind"] = "poison"
	var f = await t._spawn("knight", Vector2(pd["pos"]) + Vector2(20, 0))
	var hp0: float = f.hp
	p.global_position = Vector2(pd["pos"]) + Vector2(60, 0)
	ch.strike(p.global_position, Vector2.LEFT, 70.0, 60.0, false)
	_check(pd["burst"], "a blow bursts a spore pod")
	await t._wait(0.7)
	_check(f.hp < hp0, "a poison cloud hurts a foe standing in it")
	f.queue_free()
	var pd2: Dictionary = calm[0] if not calm.is_empty() else ch.pods[1]
	pd2["kind"] = "calm"
	var g = await t._spawn("knight", Vector2(pd2["pos"]) + Vector2(10, 0))
	ch.burst(pd2)
	await t._frames(4)
	_check(g.calm, "a calming cloud soothes the foes in it")
	g.queue_free()


func _heartroots() -> void:
	print("towers: the Hungry Grove")
	var main = t.main
	var ch = _sys("chimera")
	await _floor("chimera", 5, "heartroots")
	var ob = main.objective
	_check(ob.kind == "heartroots" and ob.custom != null and main.ward and ob.pieces.size() >= 3, "the Chimera's task can be the Hungry Grove")
	if ob.custom == null:
		return
	var hr = ob.custom
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	var now: Dictionary = hr.awake()
	var asleep: Dictionary = ob.pieces.filter(func(x): return x != now)[0]
	p.global_position = Vector2(asleep["pos"]) + Vector2(-40, 0)
	p.iframes = 0.0
	var hp0: float = p.hp
	ob.strike(p.global_position, Vector2.RIGHT, 50.0, 60.0)
	_check(hr.lashes == 1 and asleep["state"] == "todo" and p.hp < hp0, "striking a sleeping heart-root, its thorns lash you")
	var goal: Array = main.hud.arrow_goal()
	_check(not goal.is_empty() and goal[0] == now["pos"], "the arrow points at the root that's awake")
	for i in ob.pieces.size():
		var r: Dictionary = hr.awake()
		if r.is_empty():
			break
		for k in 3:
			p.global_position = Vector2(r["pos"]) + Vector2(-40, 0)
			ob.strike(p.global_position, Vector2.RIGHT, 50.0, 60.0)
		await t._frames(2)
	await t._frames(3)
	_check(ob.done and not main.ward and hr.step == ob.pieces.size(), "cutting each as it wakes, in turn, lifts the ward")
	_check(ch.withered and ch.grown().is_empty(), "...and every thorn on the floor withers")


func _briar() -> void:
	print("towers: the briar (thicket lurker)")
	var main = t.main
	await _floor("chimera", 4, "shards")
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	var at: Vector2 = p.global_position + Vector2(60, 0)
	if main.is_solid(at):
		at = p.global_position + Vector2(-60, 0)
	var b = await t._spawn("briar", at)
	_check(b.submerged and b.state == "hide" and not (b in main.targets()), "the briar hides as a bush: it can't be targeted")
	b.aware = true
	b.set_physics_process(true)
	p.iframes = 0.0
	await t._until(func(): return b.state == "grab" or b.state == "rooted", 2.0)
	_check(b.state == "grab" and main.trap_view.root_t > 0.0, "come close and it lashes out and grabs you")
	p.roll_t = 0.3
	await t._frames(3)
	p.roll_t = 0.0
	await t._frames(3)
	_check(b.state != "grab", "...a roll breaks free")
	b.queue_free()
	var c = await t._spawn("briar", at)
	main.explode(at + Vector2(10, 0), 30.0, 1.0, Color(1, 0.5, 0.2))
	_check(not c.submerged and c.stun > 0.0, "fire flushes a hiding briar out")
	c.queue_free()


func _thicket() -> void:
	print("towers: the Closing Thicket")
	var main = t.main
	var ch = _sys("chimera")
	var sc := {}
	for i in 40:
		await _floor("chimera", 4, "shards")
		for s in main.scenarios.list:
			if s["kind"] == "thicket":
				sc = s
		if not sc.is_empty():
			break
	_check(not sc.is_empty(), "a Thornwild room can be the Closing Thicket")
	if sc.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)
	var p = main.player
	p.max_hp = 999.0
	p.hp = 999.0
	var before: int = ch.thorns.size()
	p.global_position = sc["start"]
	await t._until(func(): return sc["state"] == "run", 3.0)
	await t._wait(1.4)
	_check(ch.thorns.size() > before + 2, "stepping onto the mark, hedges and thorns grow in from the edges (%d)" % (ch.thorns.size() - before))
	p.global_position = sc["end"]
	await t._frames(3)
	_check(sc["state"] == "done" and sc["grade"] != "none", "reaching the doorway in time ends it with a grade (%s)" % sc["grade"])
	await t._wait(1.5)
	_check(ch.thorns.size() <= before, "...and the thicket withers away")


# --- the floor bot ----------------------------------------------------------------------------

func _bots() -> void:
	print("towers: the floor bot plays the Firebird's and the Thornwild's floors")
	var Sweep = load("res://tests/floor_bot_sweep.gd")
	var main = t.main
	var ok := 0
	var why: Array = []
	for pick in [["firebird", 4, "rekindle"], ["chimera", 4, "heartroots"], ["firebird", 8, "shards"], ["chimera", 8, "levers"]]:
		main.tower = pick[0]
		Objectives.forced = pick[2]
		var r: Dictionary = await Sweep.play(t, main, pick[1], 4.0)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s %d %s: %s" % [pick[0], pick[1], pick[2], r["why"]])
	_check(ok >= 3, "the bot finishes the towers' own floors, tasks included (%d of 4) %s" % [ok, why])
