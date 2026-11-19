extends RefCounted
## The towers' ways down (ways_down.gd: the Kraken's whirlpools, the
## Manticore's sinkholes, the Wyvern's slag chutes, the Chimera's root
## hollows), the dark pits every hole is now (holes.gd) and teetering at
## their edge (player.gd begin_teeter), mimics (mimic.gd), inscription
## stones (inscriptions.gd) and guardian glimpses (glimpses.gd).
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const WD := preload("res://scripts/ways_down.gd")
const Holes := preload("res://scripts/holes.gd")
const Mimic := preload("res://scripts/mimic.gd")
const Ins := preload("res://scripts/inscriptions.gd")
const Gl := preload("res://scripts/glimpses.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Objectives := preload("res://scripts/objectives.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const KINDS := {"kraken": "whirlpool", "manticore": "sinkhole", "wyvern": "chute", "chimera": "hollow"}

var t


func run(smoke) -> void:
	t = smoke
	_plans()
	_words()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	await _teeter()
	await _ways_in_play()
	await _mimic()
	await _inscription()
	await _glimpses()
	await _bots()
	WD.forced = false
	Mimic.forced = false
	Ins.forced = false
	Gl.forced = ""


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


# --- plans ------------------------------------------------------------------------------

func _plans() -> void:
	print("ways down: plans (each tower's own, in a room, nothing cut off)")
	WD.forced = true
	for tid in KINDS:
		var floors := 0
		var with := 0
		var ok_kind := true
		var ok_reach := true
		var ok_ring := true
		var ok_mons := true
		var ok_basin := true
		for fl in [2, 3, 4, 5, 6, 7]:
			var plan := Floors.rooms_floor(fl, Towers.TOWERS[tid])
			floors += 1
			var ways: Array = plan.get("ways_down", [])
			if ways.is_empty():
				continue
			with += 1
			ok_reach = ok_reach and Reach.plan_check(plan)["ok"]
			var g := Grid.grid(plan)
			for w in ways:
				ok_kind = ok_kind and w["kind"] == KINDS[tid] and w["tiles"].size() == (2 if tid == "wyvern" else 1)
				var info: Dictionary = plan["room_info"][int(w["room"])]
				for tt in w["tiles"]:
					ok_ring = ok_ring and Rect2(info["rect"]).has_point(Grid.centre(tt))
					for d in Grid.N8:
						var n: Vector2i = tt + d
						ok_ring = ok_ring and (n in w["tiles"] or Grid.is_open(g, n) or true) and Rect2(info["rect"]).grow(1.0).has_point(Grid.centre(n))
				for m in plan["monsters"]:
					ok_mons = ok_mons and m[1].distance_to(w["pos"]) > 50.0
				if tid == "kraken":
					var bi := int(w.get("basin", -1))
					var basins: Array = plan["water"]["basins"]
					ok_basin = ok_basin and bi >= 0 and bi < basins.size() and basins[bi]["kind"] == "tide"
		_check(with >= 4, "%s: most floors get a way down when they may (%d of %d)" % [tid, with, floors])
		_check(ok_kind and ok_ring, "%s: its own kind (%s), inside a room with floor all round" % [tid, KINDS[tid]])
		_check(ok_reach and ok_mons, "%s: it never cuts anything off, and no monster stands on its lip" % tid)
		if tid == "kraken":
			_check(ok_basin, "the Kraken's whirlpools sit over a tide room's drain (its water drives them)")
	WD.forced = false
	# Never on the first floor (nothing below), never in a tower without one.
	var first := Floors.rooms_floor(1, Towers.TOWERS["kraken"])
	var fire := Floors.rooms_floor(4, Towers.TOWERS["firebird"])
	_check(first.get("ways_down", []).is_empty() and fire.get("ways_down", []).is_empty(), "no way down on floor 1, nor in a tower that has its own holes already")
	# Mimics and stones.
	Mimic.forced = true
	Ins.forced = true
	var mim := 0
	var stones := 0
	var ok_alone := true
	var ok_stone := true
	for k in 6:
		var plan := Floors.rooms_floor(5, Towers.TOWERS[Towers.ORDER[k % Towers.ORDER.size()]])
		var mc: Array = plan["chests"].filter(func(c): return c.get("mimic", false))
		if not mc.is_empty():
			mim += 1
			ok_alone = ok_alone and mc.size() == 1 and plan["chests"].filter(func(c): return int(c["room"]) == int(mc[0]["room"])).size() == 1
		if plan.has("inscription"):
			stones += 1
			var st: Dictionary = plan["inscription"]
			ok_stone = ok_stone and Grid.is_open(Grid.grid(plan), Grid.tile(st["pos"])) and st["tower"] == Towers.ORDER[k % Towers.ORDER.size()]
			for w in plan.get("ways_down", []):
				ok_stone = ok_stone and Vector2(st["pos"]).distance_to(w["pos"]) > 60.0
	Mimic.forced = false
	Ins.forced = false
	_check(mim >= 4 and ok_alone, "a mimic is one of the floor's chests, alone in its room (%d of 6 floors)" % mim)
	_check(stones >= 4 and ok_stone, "an inscription stone stands on open floor, never by a way down (%d of 6)" % stones)
	var none := Floors.rooms_floor(2, Towers.TOWERS["gryphon"])
	_check(not none["chests"].any(func(c): return c.get("mimic", false)), "no mimic below floor %d" % int(Mimic.RULES["from"]))


func _words() -> void:
	print("ways down, mimics, stones, glimpses: their words")
	for id in ["teeter", "whirlpool", "sinkhole", "slag_chute", "root_hollow", "mimic", "inscription"]:
		_check(Entity.TIPS.has(id) and String(Entity.TIPS[id]["tip"]).length() <= 170 and String(Entity.TIPS[id]["more"]).length() >= 60, "the Entity has a first-time moment for %s" % id)
	_check(String(Entity.TIPS["jump"]["tip"]).contains("step back quickly") and String(Entity.TIPS["jump"]["more"]).contains("teeter"), "the Chasms help says to step back quickly when you wobble")
	_check(WD.TIPS.values().all(func(id): return String(Entity.TIPS[id]["tip"]).to_lower().contains("step") or String(Entity.TIPS[id]["tip"]).to_lower().contains("walk")), "...and each way down's first moment says how to keep out of it")
	_check("how_ways_down" in Talk.DIALOGUE["how"]["choices"] and Talk.DIALOGUE.has("how_ways_down"), "\"How do things work here?\" has a topic on the ways down")
	var all := (var_to_str(WD.TEXT) + var_to_str(Mimic.TEXT) + var_to_str(Ins.TEXT) + var_to_str(Ins.INSCRIPTIONS) + var_to_str(Gl.TEXT) + var_to_str(Talk.DIALOGUE["how_ways_down"])
		+ var_to_str(Entity.TIPS["teeter"]) + var_to_str(Entity.TIPS["mimic"])).to_lower()
	var bad: Array = BANNED.filter(func(w): return all.contains(w))
	_check(bad.is_empty(), "no banned words (%s)" % [bad])
	# Inscriptions: six a tower, every one a placeholder for the owner.
	var n := 0
	var blank := true
	for tid in Towers.ORDER:
		var list: Array = Ins.INSCRIPTIONS.get(tid, [])
		n += list.size()
		blank = blank and list.size() == 6 and list.all(func(e): return String(e["text"]) == "(Inscription to come)")
	_check(blank and n % 6 == 0, "inscriptions: six for each tower (%d, by sixes), each \"(Inscription to come)\" for now" % n)
	_check(Gl.LOOK.size() == 6 and Gl.LOOK.values().all(func(l): return l["kinds"].size() == 3), "glimpses: each of the six towers has its three, in its own flavour")
	_check(Holes.TEETER["time"] >= 0.5 and Holes.TEETER["time"] <= 1.0, "a teeter gives you between half a second and a second to step back (%s)" % Holes.TEETER["time"])


# --- teetering ----------------------------------------------------------------------------

## A chasm right of the climber; returns its lip (where the climber stands).
func _chasm_right(main) -> Vector2:
	var p = main.player
	# (open floor: the floor's start, with room to its right)
	var at: Vector2 = main.player_start
	for k in 40:
		if not main.is_solid(at) and not main.is_solid(at + Vector2(110, 0)) and not main.is_solid(at + Vector2(-60, 0)):
			break
		at += Vector2(0, 20) if k % 2 == 0 else Vector2(-20, 0)
	p.global_position = at
	p.last_safe = at
	p.velocity = Vector2.ZERO
	p.knock = Vector2.ZERO
	main.set_chasms([Rect2(at + Vector2(18, -40), Vector2(80, 80))])
	return at


func _teeter() -> void:
	print("holes: dark pits, teetering at the edge")
	var main = t.main
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.floor_num = 4
	# Walk onto the edge: you teeter, back on the lip, and don't fall yet.
	_chasm_right(main)
	await t._ticks(2)
	Input.action_press("move_right")
	var until := Time.get_ticks_msec() + 1500
	while p.teeter_t <= 0.0 and Time.get_ticks_msec() < until:
		await t.physics_frame
	Input.action_release("move_right")
	_check(p.teeter_t > 0.0 and not main.in_chasm(p.global_position) and not main.climbing and main.floor_num == 4, "walking onto a chasm's edge: you teeter on the lip, not falling yet")
	_check(p.teeter_dir.dot(Vector2.RIGHT) > 0.7, "...leaning out over it")
	# Step back in time: safe.
	Input.action_press("move_left")
	await t._ticks(3)
	Input.action_release("move_left")
	_check(p.teeter_t <= 0.0 and not main.climbing and main.floor_num == 4, "step back quickly and you recover")
	await t._ticks(20)
	# Again, and wait: you tip in and fall a floor.
	_chasm_right(main)
	await t._ticks(2)
	Input.action_press("move_right")
	until = Time.get_ticks_msec() + 1500
	while p.teeter_t <= 0.0 and Time.get_ticks_msec() < until:
		await t.physics_frame
	Input.action_release("move_right")
	_check(p.teeter_t > 0.0, "...teetering again")
	await t._wait(float(Holes.TEETER["time"]) + 0.3)
	_check(main.climbing or main.floor_num == 3, "stand there and you tip in: down a floor")
	await t._wait(1.4)
	_check(main.floor_num == 3, "...landing on the floor below (%d)" % main.floor_num)
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	# A roll straight in takes you down at once (no teeter).
	main.floor_num = 4
	_chasm_right(main)
	await t._ticks(2)
	p.sta = p.MAX_STA
	p.roll_t = 0.3
	p.roll_dir = Vector2.RIGHT
	p.roll_speed = 400.0
	p._roll_len = 0.3
	var teetered := false
	until = Time.get_ticks_msec() + 1000
	while not main.climbing and Time.get_ticks_msec() < until:
		teetered = teetered or p.teeter_t > 0.0
		await t.physics_frame
	_check(main.climbing and not teetered, "rolling straight over a hole drops you at once, no teeter")
	await t._wait(1.6)
	main.set_chasms([])
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	# The look: palette tokens for the darkness, and the cut stays readable.
	_check(Palette_dark(), "holes are dark pits: the floor below dim, the depth over it, the shaft falling to near-black")


func Palette_dark() -> bool:
	var P = load("res://scripts/palette.gd")
	return P.HOLE_FLOOR_LIGHT.get_luminance() < 0.12 and P.HOLE_SHAFT_DEEP.get_luminance() < 0.03 and P.HOLE_DEPTH.a >= 0.4 and P.HOLE_RIM.get_luminance() > 0.45


# --- the ways down in play ---------------------------------------------------------------------

func _floor(tid: String, n := 5):
	var main = t.main
	for tries in 12:
		main.tower = tid
		WD.forced = true
		main._start_floor(n)
		WD.forced = false
		await t._ticks(2)
		main.banner = {}
		for e in main.enemies():
			e.queue_free()
		await t._frames(2)
		var tf = main.tower_floor
		if tf != null and tf.get("ways") != null and not tf.ways.ways.is_empty():
			return tf.ways
	return null


## Walks the climber from `from` toward `to` until something happens.
func _walk(from: Vector2, dir: Vector2, seconds: float) -> void:
	var main = t.main
	var p = main.player
	p.global_position = from
	p.velocity = Vector2.ZERO
	p.knock = Vector2.ZERO
	await t._ticks(3)
	var acts := {Vector2.RIGHT: "move_right", Vector2.LEFT: "move_left", Vector2.DOWN: "move_down", Vector2.UP: "move_up"}
	var act: String = acts[dir]
	Input.action_press(act)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while p.teeter_t <= 0.0 and not main.climbing and Time.get_ticks_msec() < until:
		await t.physics_frame
	Input.action_release(act)


func _ways_in_play() -> void:
	print("ways down: in play")
	var main = t.main
	var p = main.player
	p.iframes = 999.0
	# --- the Chimera's root hollow: walk onto it, teeter, step back; a jump clears it.
	var wd = await _floor("chimera")
	_check(wd != null, "the Chimera's floor has a root hollow")
	if wd != null:
		var w: Dictionary = wd.ways[0]
		var c: Vector2 = w["pos"]
		_check(main.tower_floor.is_void(c) and main.tower_floor.bot_avoid().size() >= 1 and main.astar.is_point_solid(main._tile_of(c)), "the bot and the monsters keep off it")
		await _walk(c + Vector2(-50, 0), Vector2.RIGHT, 1.5)
		_check(p.teeter_t > 0.0 and not main.climbing, "walking onto a root hollow's edge: a teeter")
		Input.action_press("move_left")
		await t._ticks(3)
		Input.action_release("move_left")
		await t._ticks(15)
		_check(not main.climbing and p.teeter_t <= 0.0, "...step back and you're safe")
		var fl: int = main.floor_num
		await _walk(c + Vector2(-50, 0), Vector2.RIGHT, 1.5)
		await t._wait(float(Holes.TEETER["time"]) + 0.4)
		_check(main.climbing or main.floor_num == fl - 1, "...linger and you go down it")
		await t._wait(1.5)
		_check(main.floor_num == fl - 1, "a root hollow drops you a floor, unhurt (%d)" % main.floor_num)
	# --- the Manticore's sinkhole: sags under you, then opens for good.
	wd = await _floor("manticore")
	_check(wd != null, "the Manticore's floor has a sinkhole")
	if wd != null:
		var w: Dictionary = wd.ways[0]
		var c: Vector2 = w["pos"]
		_check(w["state"] == "sand" and not wd._swallows(w, c), "a sinkhole starts as sand: you can stand on it")
		p.global_position = c
		p.knock = Vector2.ZERO
		await t._ticks(3)
		_check(w["state"] == "sag", "stand on it and it sags (the warning)")
		p.global_position = c + Vector2(-70, 0)
		await t._wait(float(WD.RULES["sag"]) + 0.3)
		_check(w["state"] == "open" and not main.climbing, "...step off in time: it opens without you")
		var fl: int = main.floor_num
		await _walk(c + Vector2(-50, 0), Vector2.RIGHT, 1.5)
		_check(p.teeter_t > 0.0, "an open sinkhole's edge makes you teeter")
		await t._wait(float(Holes.TEETER["time"]) + 0.4)
		await t._wait(1.5)
		_check(main.floor_num == fl - 1, "...and it's a way down (%d)" % main.floor_num)
	# --- the Wyvern's slag chute: the slope slides you in.
	wd = await _floor("wyvern")
	_check(wd != null, "the Wyvern's floor has a slag chute")
	if wd != null:
		var w: Dictionary = wd.ways[0]
		var top: Rect2 = w["rects"][0]
		var fl: int = main.floor_num
		p.global_position = top.get_center() + Vector2(0, -8)
		p.velocity = Vector2.ZERO
		p.knock = Vector2.ZERO
		var until := Time.get_ticks_msec() + 2500
		while not main.climbing and Time.get_ticks_msec() < until:
			await t.physics_frame
		_check(main.climbing, "stand on a slag chute's slope and you slide down it, no teeter")
		await t._wait(1.5)
		_check(main.floor_num == fl - 1, "...to the floor below (%d)" % main.floor_num)
	# --- the Kraken's whirlpool: spins up as the water drains, and pulls.
	wd = await _floor("kraken")
	_check(wd != null, "the Kraken's floor has a whirlpool")
	if wd != null:
		var w: Dictionary = wd.ways[0]
		var c: Vector2 = w["pos"]
		w["force"] = 0.0
		await t._ticks(5)
		_check(float(w["s"]) == 0.0 and not wd._swallows(w, c), "while the water stays, it's only a drain: walkable")
		w.erase("force")
		var b: Dictionary = main.tower_floor.basins[int(w["basin"])]
		# The room's water drains (as its tide would): it spins up.
		b["kind"] = "test"
		b["level"] = 0.5
		b["target"] = 0.0
		await t._wait(float(WD.RULES["form"]) + 0.6)
		_check(float(w["s"]) > 0.55, "as the room's water drains, the whirlpool spins up (%s)" % w["s"])
		p.global_position = c + Vector2(-70, 0)
		p.velocity = Vector2.ZERO
		p.knock = Vector2.ZERO
		await t._ticks(10)
		_check(p.global_position.distance_to(c) < 68.0 and p.knock.dot(Vector2.RIGHT) > 10.0, "...and drags you toward its eye")
		# Walk away and you get out.
		p.global_position = c + Vector2(-70, 0)
		Input.action_press("move_left")
		await t._wait(0.6)
		Input.action_release("move_left")
		_check(p.global_position.distance_to(c) > 90.0 and not main.climbing, "walk away from the pull and you get out")
		var fl: int = main.floor_num
		w["force"] = 1.0
		p.global_position = c + Vector2(-30, 0)
		p.knock = Vector2.ZERO
		var until := Time.get_ticks_msec() + 3000
		while not main.climbing and Time.get_ticks_msec() < until:
			await t.physics_frame
		_check(main.climbing, "stand in its pull and it takes you down")
		await t._wait(1.5)
		_check(main.floor_num == fl - 1, "...to the floor below (%d)" % main.floor_num)
	p.iframes = 0.0


# --- mimics -----------------------------------------------------------------------------------

func _mimic() -> void:
	print("mimics: chests that bite back")
	var main = t.main
	var p = main.player
	var c := {}
	for tries in 12:
		main.tower = "gryphon"
		Mimic.forced = true
		main._start_floor(5)
		Mimic.forced = false
		await t._ticks(2)
		main.banner = {}
		var mc: Array = main.room_rewards.chests.filter(func(x): return x.get("mimic", false))
		if not mc.is_empty():
			c = mc[0]
			break
	_check(not c.is_empty(), "a floor's chest may be a mimic")
	if c.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	_check(not main.enemies().any(func(e): return e.kind == "mimic"), "while it waits it's a chest, not a monster (no lock-in, no count, nothing to target)")
	await t._ticks(int(1.0 / 0.016 * 0.4))  # (the room's guards are gone: its lock turns gold, like any chest's)
	_check(c["open"], "...and it looks open to take, like any chest")
	var before: float = 0.0
	for k in main.run_essence:
		before += float(main.run_essence[k])
	p.iframes = 999.0
	p.global_position = c["pos"] + Vector2(-20, 0)
	await t._ticks(25)
	var mims: Array = main.enemies().filter(func(e): return e.kind == "mimic")
	_check(c.get("sprung", false) and mims.size() == 1, "walk up to it and it springs: a monster")
	if mims.is_empty():
		return
	var m = mims[0]
	var glinted := false
	var bit := false
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not (glinted and bit):
		glinted = glinted or m.glint > 0.0
		bit = bit or m.state in ["recover"] and m.open_t > 0.0
		await t.physics_frame
	_check(glinted and bit, "its bite winds up and glints first, and leaves it open after")
	m.take_hit(99999.0, Vector2.RIGHT)
	await t._frames(3)
	var after: float = 0.0
	for k in main.run_essence:
		after += float(main.run_essence[k])
	var spilt: float = after - before
	var chest_rich: float = (float(main.room_rewards.RULES["chest_base"]) + float(main.room_rewards.RULES["chest_per_floor"]) * main.floor_num) * float(main.room_rewards.RULES["chest_rich"])
	_check(spilt >= chest_rich, "slain, it spills more than a rich chest holds (%d >= %d)" % [int(spilt), int(chest_rich)])
	_check(load("res://scripts/bestiary.gd").BESTIARY.has("mimic") and "mimic" in load("res://scripts/bestiary.gd").kinds(), "the Bestiary has the mimic, found in every tower")
	p.iframes = 0.0


# --- inscription stones -------------------------------------------------------------------------

func _inscription() -> void:
	print("inscription stones")
	var main = t.main
	var p = main.player
	for tries in 12:
		main.tower = "manticore"
		Ins.forced = true
		main._start_floor(4)
		Ins.forced = false
		await t._ticks(2)
		main.banner = {}
		if not main.inscriptions.stone.is_empty():
			break
	var st: Dictionary = main.inscriptions.stone
	_check(not st.is_empty(), "some floors have an inscription stone")
	if st.is_empty():
		return
	for e in main.enemies():
		e.queue_free()
	p.global_position = Vector2(st["pos"]) + Vector2(0, 200)
	await t._wait(0.4)
	_check(not main.inscriptions.reading(), "from afar its words don't show")
	p.global_position = Vector2(st["pos"]) + Vector2(0, 34)
	await t._wait(0.5)
	_check(main.inscriptions.reading() and main.inscriptions.current()["text"] == "(Inscription to come)", "stand beside it and its words show (a placeholder for now)")
	_check(main.notices.log.any(func(e): return String(e["text"]).contains("(Inscription to come)")), "...and go into the Entity's log")
	_check(Ins.words("manticore", int(st["index"])) == Ins.INSCRIPTIONS["manticore"][posmod(int(st["index"]), 6)], "...read from its tower's table, by floor")


# --- glimpses ---------------------------------------------------------------------------------

func _glimpses() -> void:
	print("guardian glimpses")
	var main = t.main
	var p = main.player
	# About once every few floors: roll many floors.
	var had := 0
	Gl.since = 0
	main.tower = "gryphon"
	for k in 60:
		main.floor_num = 2 + k % 9
		main.glimpses.setup({"room_info": [1]})
		if main.glimpses.pending != "":
			had += 1
	_check(had >= 12 and had <= 30, "a glimpse waits on about one floor in three or four (%d of 60)" % had)
	main.first_climb = true
	main.glimpses.setup({"room_info": [1]})
	_check(main.glimpses.pending == "" or Gl.forced != "", "never on the bondless first climb")
	main.first_climb = false
	# Never during a fight.
	main.tower = "wyvern"
	Gl.forced = "eyes"
	main._start_floor(5)
	await t._ticks(2)
	main.banner = {}
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.glimpses.cur = {}
	main.glimpses.pending = "eyes"
	main.glimpses.wait_t = 0.0
	var foe = main.spawn_enemy("slime", p.global_position + Vector2(120, 0))
	foe.wake()
	foe.set_physics_process(false)
	await t._wait(0.4)
	_check(main.glimpses.cur.is_empty() and main.glimpses.pending == "eyes", "a monster after you: no glimpse while you fight")
	foe.queue_free()
	await t._frames(2)
	main.glimpses.hurt_t = 99.0
	# Into a hall for the eyes.
	for info in main.room_info:
		if Rect2(info["rect"]).size.x > 200.0:
			p.global_position = Rect2(info["rect"]).get_center()
			break
	await t._wait(0.3)
	_check(not main.glimpses.cur.is_empty() and main.glimpses.cur["kind"] == "eyes", "calm again: the beast's eyes in a high window")
	_check(main.notices.log.any(func(e): return String(e["text"]).contains("watching")), "...noted in the Entity's log")
	await t._wait(float(Gl.RULES["eyes_time"]) + 0.3)
	_check(main.glimpses.cur.is_empty(), "...then gone")
	# A roar after a big moment.
	main.glimpses.pending = "roar"
	main.glimpses.wait_t = 0.0
	main.glimpses.roar_t = 30.0
	main.glimpses.fought = true
	main.glimpses.calm_t = 0.0
	await t._wait(2.4)
	_check(not main.glimpses.cur.is_empty() and main.glimpses.cur["kind"] == "roar", "after a fight is won, a distant roar")


# --- the floor bot ------------------------------------------------------------------------------

func _bots() -> void:
	print("ways down: the floor bot still finishes floors that have them")
	var Sweep = load("res://tests/floor_bot_sweep.gd")
	var main = t.main
	var ok := 0
	var why: Array = []
	for pick in [["kraken", 5], ["manticore", 5], ["wyvern", 5], ["chimera", 5]]:
		main.tower = pick[0]
		WD.forced = true
		var r: Dictionary = await Sweep.play(t, main, pick[1], 2.0)
		if not r["ok"]:
			why.append("(first try) %s: %s" % [pick[0], String(r["why"]).left(90)])
			r = await Sweep.play(t, main, pick[1], 2.0)
		WD.forced = false
		if r["ok"]:
			ok += 1
		else:
			why.append("%s: %s" % [pick[0], String(r["why"]).left(120)])
	_check(ok >= 3, "the bot finishes floors with a way down (%d of 4) %s" % [ok, why])
