extends RefCounted
## Secret rooms (wings.gd, floors.gd): carved in kept cells in every tower,
## their first tile a plain wall (no torch on it, no trap in front of it),
## shut to sight, fog, paths and bodies until leaned open by keys, a
## controller or the touch stick; then reachable, seen, lit, and holding what
## they hold (a cache, three crystals, a Tithe Door); a Maker's fragment on
## their north wall; and a Designer's rift beside one tears into it.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const N4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var t
var main


func run(smoke) -> void:
	t = smoke
	await t._fresh_main()
	main = t.main
	main.grant_test_bonds()
	main.player.iframes = 0.0
	await _carved_everywhere()
	await _lean_open("keys")
	await _lean_open("controller")
	await _lean_open("touch")
	await _contents()
	await _fragment()
	await _rift_beside()
	_release_moves()
	await t._fresh_main()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _solid(tile: Vector2i) -> bool:
	return main._is_solid_tile(tile.x, tile.y)


func _collides(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not main.get_world_2d().direct_space_state.intersect_point(q).is_empty()


func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


## A floor (of the current tower) with a secret room holding `content`
## ("" for any), its monsters gone and every door open; the secret or {}.
func _secret_floor(content := "") -> Dictionary:
	for n in 120:
		main._start_floor(2 + n % 10 if 2 + n % 10 != 6 else 7)
		await t._frames(1)
		var W = main.wings
		if W.secrets.is_empty() or (content != "" and W.secrets[0]["content"] != content):
			continue
		await t._clear_foes()
		main.open_all_doors()
		main.banner = {}
		main.camp_choosing = false
		main.player.set_physics_process(true)
		return W.secrets[0]
	return {}


func _front(s: Dictionary) -> Vector2i:
	return s["mouth"][0] - Vector2i(s["into"])


## Every tower: secrets are carved, and until they open their passage and
## room are rock in every way, behind a first tile that is just wall.
func _carved_everywhere() -> void:
	print("secret rooms: carved and hidden in every tower")
	var W = main.wings
	var found := {}
	var contents := {}
	var bad := {}
	var floors := 0
	for tid in main.Towers.ORDER:
		main.tower = tid
		for n in 40:
			if found.get(tid, 0) >= 3 and (contents.size() == 3 or found.get(tid, 0) >= 8):
				break  # (three a tower, more until every kind of contents has turned up: they're random)
			var fl: int = 2 + n % 10
			if fl == 6:
				continue
			main._start_floor(fl)
			await t._frames(1)
			floors += 1
			if W.secrets.is_empty():
				continue
			found[tid] = found.get(tid, 0) + 1
			var s: Dictionary = W.secrets[0]
			contents[s["content"]] = true
			var mouth: Vector2i = s["mouth"][0]
			var into := Vector2i(s["into"])
			var tiles: Array = W._secret_tiles(s)
			var set := {}
			for k in tiles:
				set[k] = true
			var side := Vector2i(into.y, into.x)
			var front := _front(s)
			var corr: Rect2 = s["corridor"]
			if minf(corr.size.x, corr.size.y) != main.Floors.CELL or not set.has(mouth) or not set.has(mouth + into):
				bad["a passage one tile wide, its first tile in the wall"] = true
			if not tiles.all(func(k): return _solid(k) and main.astar.is_point_solid(k)):
				bad["solid to sight and paths"] = true
			if main.room_view.solid[mouth.y * main.grid_size.x + mouth.x] != 1 or not _solid(mouth + side) or not _solid(mouth - side):
				bad["its first tile drawn as wall, in a run of wall"] = true
			if not _collides(W._tile_center(mouth)):
				bad["its first tile is solid to bodies"] = true
			for k in tiles:
				for d in N4:
					var nb: Vector2i = k + d
					if set.has(nb) or _solid(nb) or (k == mouth and nb == front):
						continue
					bad["no way into it but its first tile (%s)" % tid] = true
			if _solid(front):
				bad["open floor in front of it"] = true
			if main.room_view.torches.any(func(tc): return main._tile_of(tc["pos"]) == mouth):
				bad["no torch hangs on it (%s)" % tid] = true
			if main.traps.any(func(tr): return main._tile_of(tr["pos"]) == front):
				bad["no trap stands in front of it (%s)" % tid] = true
			if main.pillars.any(func(pl): return main._tile_of(pl["pos"]) == front):
				bad["no pillar stands in front of it"] = true
			main.open_all_doors()
			if main.astar.get_id_path(main._tile_of(main.player_start), front).is_empty():
				bad["the floor in front of it can be reached from the start (%s)" % tid] = true
			# Standing in front of it, nothing of the room shows through the fog.
			main.player.global_position = W._tile_center(front)
			main.fog.last_tile = Vector2i(-999, -999)
			await t._frames(2)
			if main._tiles_in(s["rect"]).any(func(k): return main.fog.vis[k.y * main.grid_size.x + k.x] == 1):
				bad["the room stays dark in the fog from in front of it (%s)" % tid] = true
	_check(found.size() == 6, "every tower carves secret rooms (%s over %d floors)" % [found, floors])
	_check(contents.size() == 3, "...holding a cache, crystals or a Tithe Door (%s)" % [contents.keys()])
	_check(bad.is_empty(), "...each behind a plain wall tile and shut in every way until it opens%s" % ("" if bad.is_empty() else ": FAILED " + str(bad.keys())))
	main.tower = "kraken"


## Leans into a secret wall with keys, a controller's stick or the touch
## stick: a short lean isn't enough, a long one opens it, and then the
## passage and room are open to bodies, paths, sight, light and drawing.
func _lean_open(how: String) -> void:
	print("secret rooms: leaning one open (%s)" % how)
	var s := await _secret_floor()
	_check(not s.is_empty(), "a floor with a secret room (%s)" % how)
	if s.is_empty():
		return
	var W = main.wings
	var p = main.player
	var into: Vector2 = s["into"]
	var mouth: Vector2i = s["mouth"][0]
	var mc: Vector2 = W._tile_center(mouth)
	var deep: Vector2 = s["rect"].get_center()
	p.global_position = mc - into * 60.0
	p.velocity = Vector2.ZERO
	await t._frames(2)
	var touch = null
	var at := Vector2.ZERO
	var key := InputEventKey.new()
	var axes: Array = []
	match how:
		"keys":
			key.physical_keycode = KEY_S if into == Vector2.DOWN else (KEY_W if into == Vector2.UP else (KEY_D if into == Vector2.RIGHT else KEY_A))
			key.keycode = key.physical_keycode
			key.pressed = true
			Input.parse_input_event(key)
		"controller":
			for ax in [[JOY_AXIS_LEFT_X, into.x], [JOY_AXIS_LEFT_Y, into.y]]:
				var ev := InputEventJoypadMotion.new()
				ev.device = 0
				ev.axis = ax[0]
				ev.axis_value = ax[1]
				axes.append(ev)
			for ev in axes:
				Input.parse_input_event(ev)
			await t._frames(1)
			for ev in axes:  # (a real stick keeps reporting while held)
				Input.parse_input_event(ev)
		"touch":
			touch = main.get_children().filter(func(c): return c is CanvasLayer)[0].get_children().filter(func(c): return "stick_touch" in c)[0]
			var screen: Vector2 = touch.get_viewport_rect().size
			touch.stick_touch = -1  # (a finger an earlier test left down must not hold the stick)
			touch.held.clear()
			at = Vector2(200, screen.y - 200)
			if touch.Layout.moved("touch.stick"):
				at = touch.stick_zone().get_center()
			t._touch(0, at, true)
			await t._frames(2)
			t._drag(0, at + into * 20.0)
			await t._frames(1)
			t._drag(0, at + into * 40.0)
	await t._wait(0.4)
	var early: bool = s["open"]
	await t._until(func(): return s["open"], 3.0)  # (a busy machine runs slower)
	match how:
		"keys":
			key.pressed = false
			Input.parse_input_event(key)
		"controller":
			for ev in axes:
				ev.axis_value = 0.0
				Input.parse_input_event(ev)
		"touch":
			t._touch(0, at + into * 40.0, false)
	await t._frames(3)
	_release_moves()
	_check(not early and s["open"], "pressing into it a moment does nothing; leaning on it (%s) grinds it open (early %s, open %s)" % [how, early, s["open"]])
	if how != "keys":
		return
	_check(not main.is_solid(mc) and not main.is_solid(deep) and not main.astar.is_point_solid(mouth) and not _collides(mc) and not _collides(W._tile_center(mouth + Vector2i(into))),
		"...its passage and room open to walking and the path grid")
	# From where the climber leaned (a sealed wing shuts its doors behind
	# you, so the start may be cut off for now); any open tile of the room
	# will do, since its middle can hold what it guards.
	var from_t: Vector2i = main._tile_of(p.global_position)
	var in_room: Array = W._secret_tiles(s).filter(func(k): return s["rect"].has_point(W._tile_center(k)) and not main.astar.is_point_solid(k))
	var reached: bool = in_room.any(func(k): return not main.astar.get_id_path(from_t, k).is_empty())
	_check(reached, "...and the room can be walked into from where you leaned (%s, %d open tiles in it, middle solid: %s)" % [s["content"], in_room.size(), main.astar.is_point_solid(main._tile_of(deep))])
	_check(main.room_view.solid[mouth.y * main.grid_size.x + mouth.x] == 0, "...drawn as floor now")
	await t._frames(2)
	_check(main.lighting._solid_copy == main.solid, "...and the light's shadows know the walls moved")
	p.global_position = W._tile_center(s["door"][0]) + into * 30.0
	await t._frames(4)
	var di: Vector2i = main._tile_of(deep)
	_check(main.fog.vis[di.y * main.grid_size.x + di.x] == 1, "...and the room is in sight once you step in")


## What each kind holds, found once it's open.
func _contents() -> void:
	print("secret rooms: what they hold")
	var W = main.wings
	var p = main.player
	var s := await _secret_floor("cache")
	if not s.is_empty():
		W._open_secret(s)
		var kind: String = main.tower_data()["essence"]
		var had: float = float(main.run_essence.get(kind, 0.0))
		_check(main.lighting.lights.has(s.get("light", -1)), "a hidden cache glows in its room")
		p.global_position = s["rect"].get_center()
		await t._until(func(): return s["taken"], 1.0)
		await t._wait(0.6)
		_check(s["taken"] and float(main.run_essence.get(kind, 0.0)) > had, "walking onto a hidden cache takes its essence (%.0f)" % (float(main.run_essence.get(kind, 0.0)) - had))
	_check(not s.is_empty(), "a floor with a hidden cache")
	s = await _secret_floor("crystals")
	if not s.is_empty():
		W._open_secret(s)
		p.global_position = s["rect"].get_center()
		await t._frames(3)
		var choices: Array = main.camp.get("choices", [])
		_check(main.camp_choosing and choices.size() == 3 and choices.all(func(c): return String(c).begins_with("crystal:")), "a crystal pedestal offers three crystals (%s)" % [choices])
		var before: float = t._purse(main.profile)
		main.choose_camp(0)
		_check(not main.camp_choosing and t._purse(main.profile) > before, "...and one taken is kept")
	_check(not s.is_empty(), "a floor with a crystal pedestal")
	s = await _secret_floor("tithe")
	if not s.is_empty():
		W._open_secret(s)
		var vd: Vector2i = s["vault_door"]
		var vdir: Vector2 = s["vault_dir"]
		_check(_solid(vd) and _collides(W._tile_center(vd)) and not _solid(vd - Vector2i(vdir)), "a Tithe Door stands shut, open floor before it")
		var cost := float(s["cost"])
		main.run_essence = {"fire": cost * 0.5}
		var key := "move_down" if vdir == Vector2.DOWN else ("move_up" if vdir == Vector2.UP else ("move_right" if vdir == Vector2.RIGHT else "move_left"))
		p.global_position = W._tile_center(vd) - vdir * 40.0
		await t._frames(2)
		Input.action_press(key)
		await t._wait(1.2)
		Input.action_release(key)
		_check(s["vault"] == "sealed" and absf(float(main.run_essence["fire"]) - cost * 0.5) < 0.01 and main.banner.get("title", "") == W.TEXT["tithe_title"],
			"it says what it asks, and leaning with too little essence pays nothing (asks %d)" % int(cost))
		main.run_essence = {"fire": cost + 5.0}
		await t._frames(2)
		Input.action_press(key)
		await t._until(func(): return s["vault"] != "sealed", 2.0)
		Input.action_release(key)
		_check(s["vault"] == "open" and not _solid(vd) and absf(float(main.run_essence["fire"]) - 5.0) < 0.01, "...leaning with enough pays it from unbanked essence and it opens")
		p.global_position = s["pedestal"]
		await t._frames(3)
		_check(main.camp_choosing and main.camp.get("stage", "") == "vault" and main.camp.get("choices", []).size() == 3, "...and its vault offers a full vault's cards")
		main.choose_camp(0)
		main.run_essence = {}
	_check(not s.is_empty(), "a floor with a Tithe Door")
	_release_moves()


## A Maker's fragment: on the north wall of a secret room, hidden until it opens.
func _fragment() -> void:
	print("secret rooms: a Maker's fragment on the north wall")
	var mk = main.makers
	var ok := 0
	var bad: Array = []
	for i in 6:
		var s := await _secret_floor()
		if s.is_empty():
			continue
		var spots: Array = mk.candidates().filter(func(c): return c["src"] == "secret")
		if spots.size() != 1:
			bad.append("spots %d" % spots.size())
			continue
		var f: Dictionary = spots[0]
		var wall: Vector2i = f["tile"] + Vector2i(0, -1)
		var tiles: Array = main.wings._secret_tiles(s)
		if not is_same(f["ref"], s) or f["room"] != s["rect"] or wall in tiles or wall in s.get("door", []) or not s["rect"].has_point(f["read_at"]) or f["tile"].y != main._tile_of(s["rect"].position).y:
			bad.append("spot %s" % wall)
			continue
		mk.fragment = f.duplicate()
		mk.fragment["maker"] = mk.ORDER[0]
		mk.fragment["read"] = false
		mk.fragment["light"] = -1
		var hidden: bool = not mk.fragment_open()
		main.wings._open_secret(s)
		await t._frames(2)
		if hidden and mk.fragment_open() and _solid(wall):
			ok += 1
		else:
			bad.append("open")
		mk.clear_floor()
	_check(ok >= 4 and bad.is_empty(), "a fragment's place is the north wall of the secret room (rock, not its doorway), read from inside, hidden until it opens (%d%s)" % [ok, "" if bad.is_empty() else " " + str(bad)])


## The Designer's rift running right beside a shut secret room tears into
## it: nothing is left there that's rock to the eye but not to the body.
func _rift_beside() -> void:
	print("secret rooms: the Designer's rift beside one")
	var SB := preload("res://scripts/secret_bonds.gd")
	SB.grant(main.profile, "designer", 5)
	main._give_bonds()
	var D = main.secret_tools.deep
	var R = D.rift
	var W = main.wings
	var done := false
	for n in 40:
		if done:
			break
		var s := await _secret_floor()
		if s.is_empty():
			continue
		var set := {}
		for k in W._secret_tiles(s):
			set[k] = true
		var got: Dictionary = t._rift_start(R, func(pl):
			var into := false
			var beside := false
			for k in pl["tiles"]:
				into = into or set.has(k)
				for d in N4:
					beside = beside or (set.has(k + d) and k + d != s["mouth"][0])
			return beside and not into, Rect2())
		if got.is_empty():
			continue
		done = true
		main.player.global_position = got["pos"]
		var lines: Array = R.tear(got["pos"], D)
		_check(not lines.is_empty() and s["open"] and s["taken"] and lines.has(SB.TEXT["rift_secret"]), "a rift right beside a secret room tears into it (open, and emptied)")
		var leak := false
		for k in R.tiles:
			for d in N4:
				var nb: Vector2i = k + d
				if set.has(nb) and _solid(nb) and not _collides(W._tile_center(nb)):
					leak = true
		_check(not leak, "...leaving no tile that's rock to the eye but walkable")
	_check(done, "found a floor where a rift runs beside a secret room")
