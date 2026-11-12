extends RefCounted
## The Ice Hall (scripts/puzzles/ice.gd): nobody can be stuck on the ice.
## Over many generated halls, EVERY tile of ice that isn't rock has a line of
## slides off it (not only where slides stop: a monster in the lane, a blink
## or a flight's end can leave you anywhere), no tile is boxed in by rocks,
## and the dais is reached in the slides the solver says. Then, with the real
## controls in a real hall: from tiles a blink or a blow could leave you on,
## the stick slides you off; a blink in the middle of a slide ends it where
## you land. Last, the floor bot (tests/floor_bot_driver.gd) solves a few
## Ice Halls by the puzzle's own solver, one slide at a time.
## The heavy run: `godot --headless --fixed-fps 60 -s tests/floor_bot_sweep.gd -- 2 kind=ice`.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const I := preload("res://scripts/puzzles/ice.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

## Halls generated for the slide-graph check, and Ice Halls the bot plays.
const HALLS := 240
const BOT_HALLS := [["kraken", 3], ["wyvern", 5], ["manticore", 8], ["kraken", 10]]

var t


func run(smoke) -> void:
	t = smoke
	_graphs()
	await t._fresh_main()
	t.main.profile.regarded = true
	t.main.first_climb = false
	await _real_controls()
	await _bot()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A hall's room rows (all open floor) and the tiles kept clear at a few
## doorways (3x3 round a tile on the edge, as floors.gd keeps them).
func _room(w: int, h: int) -> Dictionary:
	var rows: Array = []
	for y in h:
		rows.append(".".repeat(w))
	var reserved := {}
	for k in randi_range(1, 3):
		var side := randi() % 4
		var at := Vector2i(randi_range(1, w - 2), 0 if side == 0 else h - 1) if side < 2 else Vector2i(0 if side == 2 else w - 1, randi_range(1, h - 2))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				reserved[at + Vector2i(dx, dy)] = true
	return {"rows": rows, "reserved": reserved}


## The slide graph over many generated halls.
func _graphs() -> void:
	print("the Ice Hall: every tile of ice has a way off (slide graph)")
	var made := 0
	var stuck := 0
	var boxed := 0
	var off_ok := true
	var need_ok := true
	var clear_ok := true
	var bad: Array = []
	for n in HALLS:
		var w := randi_range(10, 12)
		var h := randi_range(8, 10)
		var tier := 1 + n % 3
		var ctx := _room(w, h)
		var spec: Dictionary = I.make(Rect2(0, 0, w * 40, h * 40), 5, tier, ctx)
		if spec.is_empty():
			continue
		made += 1
		var c: int = spec["cols"]
		var r: int = spec["rows"]
		var rk := {}
		for tt in spec["rocks"]:
			rk[tt] = true
			clear_ok = clear_ok and not ctx["reserved"].has(Vector2i(tt) + Vector2i.ONE)
		var left: Array = I.stuck_tiles(c, r, rk)
		if not left.is_empty():
			stuck += 1
			if bad.size() < 3:
				bad.append(left)
		for y in r:
			for x in c:
				var tt := Vector2i(x, y)
				if rk.has(tt):
					continue
				var moves := 0
				for d in I.DIRS:
					if I.slide_from(tt, d, c, r, rk) != tt:
						moves += 1
				if moves == 0:
					boxed += 1
				# (the line the bot and the hints use: way_off, from any tile)
				off_ok = off_ok and not I.way_off(c, r, rk, tt).is_empty()
		var route: Array = I.route(c, r, rk, spec["dais"])
		var lo: int = I.NEED[tier]
		need_ok = need_ok and not rk.has(spec["dais"]) and route.size() - 1 == int(spec["need"]) and int(spec["need"]) >= lo and int(spec["need"]) <= lo + 3
	_check(made >= HALLS * 9 / 10, "Ice Halls are made for nearly every room asked (%d of %d)" % [made, HALLS])
	_check(stuck == 0 and off_ok, "from EVERY tile of ice that isn't rock, some line of slides leads off (%d halls with a stuck tile %s)" % [stuck, bad])
	_check(boxed == 0, "no tile of ice is boxed in by rocks on all four sides (%d)" % boxed)
	_check(need_ok and clear_ok, "the dais takes the solver's number of slides, within its tier's range; no rock where a doorway is kept clear")


## The real controls in a real hall: blinked (or knocked) onto any tile, the
## stick slides you off; a blink mid-slide ends the slide where you land.
func _real_controls() -> void:
	print("the Ice Hall: off the ice from anywhere, with the real controls")
	var main = t.main
	var p = main.player
	var pz = main.puzzle
	await t._puzzle_floor("ice", 5)
	var ice = pz.cur
	_check(pz.kind == "ice" and ice != null, "an Ice Hall to stand in")
	if pz.kind != "ice" or ice == null:
		return
	await t._wait(0.4)
	p.max_hp = 9999.0
	p.hp = 9999.0
	# Tiles a blink or a blow could leave you on: those no slide stops on
	# first, then any.
	var rests := {}
	for e in I.entries(ice.cols, ice.rows_n):
		rests[I.slide_from(e[0], e[1], ice.cols, ice.rows_n, ice.rocks)] = true
	var tiles: Array = []
	var others: Array = []
	for y in ice.rows_n:
		for x in ice.cols:
			var tt := Vector2i(x, y)
			if ice.rocks.has(tt) or tt == ice.dais:
				continue
			if rests.has(tt):
				others.append(tt)
			else:
				tiles.append(tt)
	tiles.shuffle()
	others.shuffle()
	tiles = (tiles.slice(0, 5) + others).slice(0, 7)
	var got_off := 0
	var tried := 0
	var where: Array = []
	for tt in tiles:
		tried += 1
		p.global_position = ice.center(tt)
		p.velocity = Vector2.ZERO
		await t._frames(3)
		# Slide by the stick, planning again from wherever each slide stops.
		for k in 10:
			if not ice.on_ice(p.global_position):
				break
			var g: Vector2i = ice.grid(p.global_position)
			var off: Array = I.way_off(ice.cols, ice.rows_n, ice.rocks, g, ice.dais)
			if off.is_empty():
				off = I.way_off(ice.cols, ice.rows_n, ice.rocks, g)
			if off.is_empty():
				break
			await t._ice_slide(ice, off[0])
		if not ice.on_ice(p.global_position) and pz.room.has_point(p.global_position):
			got_off += 1
		else:
			where.append(tt)
		pz.solved = false  # (a line that rested on the dais by chance: not what's tested here)
	_check(tried > 0 and got_off == tried, "set down anywhere on the ice, the stick slides you off it (%d of %d; stuck from %s)" % [got_off, tried, where])
	# A blink in the middle of a slide: the slide ends where you land.
	var from := Vector2i(-1, -1)
	var dir := Vector2i.ZERO
	for e in I.entries(ice.cols, ice.rows_n):
		var s: Vector2i = I.slide_from(e[0], e[1], ice.cols, ice.rows_n, ice.rocks)
		if s != I.EXIT and s != e[0] and absi((s - e[0]).x) + absi((s - e[0]).y) >= 4:
			from = e[0]
			dir = e[1]
			break
	if dir != Vector2i.ZERO:
		p.global_position = ice.center(from)
		await t._frames(3)
		Input.action_press(t.MOVE_KEYS[dir])
		var until := Time.get_ticks_msec() + 800
		while ice.slide_dir == Vector2i.ZERO and Time.get_ticks_msec() < until:
			await t.physics_frame
		Input.action_release(t.MOVE_KEYS[dir])
		await t.physics_frame
		# Somewhere two lanes over, not rock.
		var land := Vector2i(-1, -1)
		var side := Vector2i(dir.y, dir.x)
		var here: Vector2i = ice.grid(p.global_position)
		for k in [2, -2, 3, -3, 4, -4]:
			var q: Vector2i = here + side * k
			if ice.in_field(q) and not ice.rocks.has(q) and q != ice.dais:
				land = q
				break
		if land != Vector2i(-1, -1) and ice.slide_dir != Vector2i.ZERO:
			p.global_position = ice.center(land) + Vector2(dir) * 6.0
			await t._frames(20)
			_check(ice.slide_dir == Vector2i.ZERO and ice.grid(p.global_position) == land and p.global_position.distance_to(ice.center(land)) < 3.0,
				"a blink in the middle of a slide ends it where you land, on the middle of the tile")
	pz.clear()
	main.ward = false


## The floor bot solves real Ice Halls, through the controller's inputs.
func _bot() -> void:
	print("the Ice Hall: the floor bot")
	var main = t.main
	var ok := 0
	var why: Array = []
	for b in BOT_HALLS:
		main.tower = b[0]
		Objectives.forced = "ice"
		var r: Dictionary = await Sweep.play(t, main, int(b[1]), 2.0)  # (twice as fast: the parts run has no --fixed-fps)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s %d: %s %s" % [b[0], b[1], r["why"], r.get("log", [])])
	main.tower = "kraken"
	_check(ok >= BOT_HALLS.size() - 1, "the floor bot solves Ice Halls slide by slide and takes the stair (%d of %d) %s" % [ok, BOT_HALLS.size(), why])
