extends RefCounted
## Secret rooms (wings.gd, floors.gd), now POCKET DIMENSIONS (portals.gd,
## vaults.gd): carved in kept cells in every tower with no way to them on
## foot, their hidden spot a plain wall tile in a spine room (no torch on
## it, no trap in front of it), shut to sight, fog, paths and bodies until
## leaned open by keys, a controller or the touch stick; then a portal in the
## wall leads in, the room is seen and lit, and it holds its vault (three
## chests; open, or guarded by a Tithe Stone, runes or a Keeper); a Maker's
## fragment on their north wall; and a Designer's rift beside one tears
## into it. (tests/parts/portals.gd has the portals' own tests.)
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
			if found.get(tid, 0) >= 3 and (contents.size() == 4 or found.get(tid, 0) >= 8):
				break  # (three a tower, more until every kind of guard has turned up)
			var fl: int = 2 + n % 10
			if fl == 6:
				continue
			seed(7300 + n * 13 + tid.length())
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
			if corr.size != Vector2(main.Floors.CELL, main.Floors.CELL) or not set.has(mouth) or set.has(mouth + into):
				bad["its hidden spot is all that's carved of a way in (rock behind it)"] = true
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
					bad["no way into it but its hidden spot (%s)" % tid] = true
			if not s.has("chests") or s["chests"].size() != 3 or not s.has("portal_in") or not s["rect"].has_point(s["portal_in"]):
				bad["a vault of three chests and a portal back, inside the pocket"] = true
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
	_check(contents.has("open") and contents.size() >= 3, "...each a vault: open, or guarded by a Tithe Stone, runes or a Keeper (%s)" % [contents.keys()])
	_check(bad.is_empty(), "...each behind a plain wall tile and shut in every way until it opens%s" % ("" if bad.is_empty() else ": FAILED " + str(bad.keys())))
	main.tower = "kraken"
	seed(Time.get_ticks_usec())


## Leans into a secret wall with keys, a controller's stick or the touch
## stick: a short lean isn't enough, a long one opens it, and then the
## passage and room are open to bodies, paths, sight, light and drawing.
func _lean_open(how: String) -> void:
	print("secret rooms: leaning one open (%s)" % how)
	var s := await _secret_floor()
	_check(not s.is_empty(), "a floor with a secret room (%s)" % how)
	if s.is_empty():
		return
	s["content"] = "open"  # (no Keeper rising to knock you about while this looks around)
	load("res://scripts/vaults.gd").lay_out(s, main.floor_num, false, main.Floors.CELL)
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
	_check(not main.is_solid(mc) and not main.is_solid(deep) and not main.astar.is_point_solid(mouth) and not _collides(mc) and s["portal_out"] == mc,
		"...the wall gives way to a niche holding a portal, and the pocket's room is open")
	_check(main.astar.get_id_path(main._tile_of(mc - into * 40.0), main._tile_of(deep)).is_empty() and main.is_solid(W._tile_center(mouth + Vector2i(into))),
		"...yet still no way to it on foot: rock behind the niche")
	_check(main.room_view.solid[mouth.y * main.grid_size.x + mouth.x] == 0, "...drawn as floor now")
	await t._frames(2)
	_check(main.lighting._solid_copy == main.solid, "...and the light's shadows know the walls moved")
	main.portals.armed = true
	main.portals._move_player(s["portal_out"])
	await t._frames(4)
	var di: Vector2i = main._tile_of(s["rect"].get_center())
	_check(main.portals.in_pocket() and main.fog.vis[di.y * main.grid_size.x + di.x] == 1, "...and through its portal the room is in sight")
	main.portals.armed = true
	main.portals._move_player(s["portal_in"])
	await t._frames(3)
	_check(not main.portals.in_pocket(), "...and its portal back leads out")


## How each kind of vault is guarded, laid out once it's set (vaults.gd).
func _contents() -> void:
	print("secret rooms: their vaults")
	var W = main.wings
	var s := await _secret_floor()
	_check(not s.is_empty(), "a floor with a secret room")
	if s.is_empty():
		return
	var Vaults = load("res://scripts/vaults.gd")
	for kind in ["open", "tithe", "puzzle", "keeper"]:
		s["content"] = kind
		Vaults.lay_out(s, main.floor_num, false, main.Floors.CELL)
		var ok: bool = s["chests"].size() == 3 and s["chests"].all(func(c): return s["rect"].has_point(c["pos"]))
		match kind:
			"open":
				ok = ok and s["vault"] == "open"
			"tithe":
				ok = ok and s["vault"] == "sealed" and float(s["cost"]) > 0.0 and s["rect"].has_point(s["tithe_pos"])
			"puzzle":
				ok = ok and s["vault"] == "sealed" and s["runes"].size() == 3 and s["order"].size() == 3
			"keeper":
				ok = ok and s["vault"] == "sealed" and s["keeper_state"] == "waiting"
		_check(ok, "vault (%s): three chests in the pocket%s" % [kind, "" if kind == "open" else ", chained until its guard is dealt with"])
	_check(W.SECRET.has("lean") and not W.TEXT.has("tithe_title"), "(the old caches and Tithe Doors are gone: a pocket holds a vault)")


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
