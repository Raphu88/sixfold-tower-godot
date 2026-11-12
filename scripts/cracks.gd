extends Node2D
## Cracked walls: wall tiles with visible cracks that break under a heavy
## blow (a combo's finisher), a burst (bombs, fire flasks, exploding spells)
## and crumble with dust and rubble. Behind one is always something:
##   loop    a passage between two rooms that weren't joined: a shortcut
##   stub    a short corridor that ends at a cracked wall (the clue), with
##           an alcove behind it
##   alcove  an alcove straight off a room
## An alcove holds an essence cache (sometimes with gear) or a vault's cards.
## Fair clues: the cracks themselves, dust drifting down when you're near, a
## hollow knock when a lighter blow lands. Cracked walls are never needed:
## the stair and the floor's task never lie behind one (reach.gd counts them
## as rock). The rarer, subtler secret stays the hidden wall you lean on
## (wings.gd). Planned by `plan` (floors.gd), run here (main.gd setup).

const Rooms := preload("res://scripts/rooms.gd")
const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")

const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0

static var TEXT := {
	"knock": "A hollow knock. The cracks run deep: a finishing blow might break it.",
	"crumble": "The wall crumbles",
	"loop": "A way through!",
	"cache": "Hidden essence: +%d",
	"vault_title": "A HIDDEN VAULT",
	"vault_sub": "Walled up long ago, and worth the trouble.",
	"gear": "Hidden away: %s",
}
## dust_every: seconds between dust falls when near; dust_near: how near (px);
## cache: essence (base, per floor); gear_chance: an alcove cache also holds gear.
static var RULES := {"dust_every": [2.2, 4.5], "dust_near": 260.0, "cache_base": 10.0, "cache_per_floor": 3.0, "gear_chance": 0.4,
	"stub": [2, 3], "reach": 30.0}

var main
var list: Array = []  # {kind, tiles, faces, alcove, reward, broken, body, dust_t, taken}
var rubble: Array = []  # {pos, r, rot}: what's left of a broken wall
var knocks := 0  # (tests)
var broken_count := 0


## --- planning (floors.gd) ------------------------------------------------------------

## The floor's cracked walls: [{kind, tiles (Vector2i, solid until broken),
## walk (Rect2s that are floor once open: the passage, stub, alcove), room,
## faces ({tile, out}: the crack faces a room), reward ({kind, pos}, alcoves)}].
## `walk` is what's walkable already (rooms, corridors, kept cells), `kept`
## the wings and secrets, `arena` the floor's area.
static func plan(infos: Array, loops: Array, walk: Array, kept: Array, arena: Rect2, floor_num: int, style: Dictionary, doors: Array) -> Array:
	var out: Array = []
	if floor_num < 2:
		return out
	var want := randi_range(int(style["cracks"][0]), int(style["cracks"][1]))
	var taken: Array = []
	for r in walk:
		taken.append(_tile_rect(r))
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(int(arena.size.x / CELL), int(arena.size.y / CELL)))
	var joined := {}
	for i in infos.size():
		if infos[i].has("link"):
			joined[_pair(i, int(infos[i]["parent"]))] = true
	for l in loops:
		joined[_pair(int(l["a"]), int(l["b"]))] = true
	for attempt in want * 8:
		if out.size() >= want:
			break
		var kind := _weighted(style["crack_kinds"])
		var c := {}
		match kind:
			"loop":
				c = _plan_loop(infos, joined, taken, bounds)
			"stub":
				c = _plan_alcove(infos, taken, bounds, randi_range(int(RULES["stub"][0]), int(RULES["stub"][1])))
			_:
				c = _plan_alcove(infos, taken, bounds, 0)
		if c.is_empty():
			continue
		if c["kind"] != "loop":
			c["reward"]["kind"] = _weighted(style["alcove"])
		for r in c["walk"]:
			taken.append(_tile_rect(r))
		for t in c["tiles"]:
			taken.append(Rect2i(t, Vector2i.ONE))
		out.append(c)
	return out


static func _pair(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


## A passage between two rooms in neighbouring cells not yet joined, all of
## it cracked rock until broken.
static func _plan_loop(infos: Array, joined: Dictionary, taken: Array, bounds: Rect2i) -> Dictionary:
	var pairs: Array = []
	for i in infos.size():
		for j in range(i + 1, infos.size()):
			if i == 0 or joined.has(_pair(i, j)):
				continue
			var d: Vector2i = infos[j]["cell"] - infos[i]["cell"]
			if absi(d.x) + absi(d.y) == 1:
				pairs.append([i, j])
	pairs.shuffle()
	var Floors = load("res://scripts/floors.gd")
	for pr in pairs:
		var link: Dictionary = Floors._link(infos[pr[0]], infos[pr[1]])
		if link.is_empty():
			continue
		var cr: Rect2i = link["corridor"]
		if cr.size.x <= 0 or cr.size.y <= 0 or not bounds.encloses(cr):
			continue
		var clear := true
		for t in taken:
			if cr.intersects(t):
				clear = false
				break
		if not clear:
			continue
		var tiles: Array = []
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				tiles.append(Vector2i(x, y))
		joined[_pair(pr[0], pr[1])] = true
		var out_v: Vector2 = link["out"]
		var faces: Array = []
		for t in link["door"]:
			faces.append({"tile": t, "out": -out_v})  # (the end at room pr[1], facing into it)
		var far := cr.size.x if link["side_c"] >= 2 else cr.size.y
		for t in link["door"]:
			faces.append({"tile": t + Vector2i(out_v) * (far - 1), "out": out_v})
		return {"kind": "loop", "tiles": tiles, "walk": [Rect2(ORIGIN + Vector2(cr.position) * CELL, Vector2(cr.size) * CELL)],
			"rooms": [pr[0], pr[1]], "room": pr[1], "faces": faces}
	return {}


## A 3x3 alcove behind a cracked wall tile in a room's wall (or at the end
## of a stub corridor `stub` tiles long), into rock nothing else uses.
static func _plan_alcove(infos: Array, taken: Array, bounds: Rect2i, stub: int) -> Dictionary:
	var order: Array = range(1, infos.size())
	order.shuffle()
	for i in order:
		var info: Dictionary = infos[i]
		if info["role"] == "stair" or (info["role"] == "gallery" and info.get("puzzle", "") != ""):
			continue
		var rows: Array = info["rows"]
		var size: Vector2i = info["size"]
		var pos: Vector2i = info["pos"]
		var sides: Array = [0, 1, 2, 3]
		sides.shuffle()
		for side in sides:
			var dir: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][side]
			var along: Vector2i = Vector2i(1, 0) if side < 2 else Vector2i(0, 1)
			var n: int = size.x if side < 2 else size.y
			var ks: Array = range(2, n - 2)
			ks.shuffle()
			for k in ks:
				# The room's edge tile in front of it (and its neighbours along the wall) open floor.
				var edge := Vector2i(k, 0) if side == 0 else (Vector2i(k, size.y - 1) if side == 1 else (Vector2i(0, k) if side == 2 else Vector2i(size.x - 1, k)))
				var ok := true
				for s in [-1, 0, 1]:
					var e: Vector2i = edge + along * s
					ok = ok and String(rows[e.y])[e.x] == "."
				if not ok:
					continue
				if side == 0 and absi(k - size.x / 2) <= 2:
					continue  # (the torch hangs over the middle of the north wall)
				var wall_t: Vector2i = pos + edge + dir  # the first tile outside the room
				var stub_tiles: Array = []
				for s in stub:
					stub_tiles.append(wall_t + dir * s)
				var crack: Vector2i = wall_t + dir * stub
				var centre: Vector2i = crack + dir * 2
				var alc := Rect2i(centre - Vector2i.ONE, Vector2i(3, 3))
				var check: Array = [alc.grow(1), Rect2i(crack, Vector2i.ONE)]
				for st in stub_tiles:
					check.append(Rect2i(st - along, Vector2i.ONE) if true else Rect2i())
					check.append(Rect2i(st + along, Vector2i.ONE))
					check.append(Rect2i(st, Vector2i.ONE))
				check.append(Rect2i(crack - along, Vector2i.ONE))
				check.append(Rect2i(crack + along, Vector2i.ONE))
				var clear := true
				for r in check:
					if not bounds.encloses(r):
						clear = false
						break
					for t in taken:
						if r.intersects(t):
							clear = false
							break
					if not clear:
						break
				if not clear:
					continue
				var walk: Array = [Rect2(ORIGIN + Vector2(alc.position) * CELL, Vector2(alc.size) * CELL)]
				for st in stub_tiles:
					walk.append(Rect2(ORIGIN + Vector2(st) * CELL, Vector2(CELL, CELL)))
				var face := {"tile": crack, "out": -Vector2(dir)}
				var alcove_r: Rect2 = walk[0]
				walk.append(Rect2(ORIGIN + Vector2(crack) * CELL, Vector2(CELL, CELL)))  # (floor once broken: no wall body there)
				return {"kind": "stub" if stub > 0 else "alcove", "tiles": [crack], "walk": walk, "room": i, "faces": [face],
					"stub": stub_tiles, "alcove": alcove_r, "reward": {"pos": alcove_r.get_center()}}
	return {}


static func _tile_rect(r: Rect2) -> Rect2i:
	var p := Vector2i(int((r.position.x - ORIGIN.x) / CELL), int((r.position.y - ORIGIN.y) / CELL))
	var e := Vector2i(int(ceil((r.end.x - ORIGIN.x) / CELL)), int(ceil((r.end.y - ORIGIN.y) / CELL)))
	return Rect2i(p, e - p)


static func _weighted(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var roll := randf() * total
	for k in table:
		roll -= float(table[k])
		if roll <= 0.0:
			return k
	return table.keys()[0]


## --- in play ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = -2  # on the floor, over the room's drawing


func setup(plan: Dictionary) -> void:
	clear()
	if main == null or not main.layout_on:
		return
	for c0 in plan.get("cracks", []):
		var c: Dictionary = c0.duplicate(true)
		c["broken"] = false
		c["taken"] = false
		c["dust_t"] = randf_range(RULES["dust_every"][0], RULES["dust_every"][1])
		_set_solid(c["tiles"], true)
		# An alcove is rock to sight and paths until it opens.
		if c.has("alcove"):
			_set_solid(main._tiles_in(c["alcove"]), true)
		c["body"] = _body(c["tiles"])
		list.append(c)
	queue_redraw()


func clear() -> void:
	for c in list:
		if c.get("body") != null and is_instance_valid(c["body"]):
			c["body"].queue_free()
		if c.has("light") and main != null and main.lighting != null:
			main.lighting.remove_light(c["light"])
	list.clear()
	rubble.clear()
	knocks = 0
	broken_count = 0
	queue_redraw()


func _set_solid(tiles: Array, closed: bool) -> void:
	var gs: Vector2i = main.grid_size
	for t in tiles:
		if t.x < 0 or t.y < 0 or t.x >= gs.x or t.y >= gs.y:
			continue
		main.solid[t.y * gs.x + t.x] = 1 if closed else 0
		if main.astar != null:
			main.astar.set_point_solid(t, closed)


func _body(tiles: Array) -> StaticBody2D:
	var r := Rect2(main.room.position + Vector2(tiles[0]) * CELL, Vector2(CELL, CELL))
	for t in tiles:
		r = r.merge(Rect2(main.room.position + Vector2(t) * CELL, Vector2(CELL, CELL)))
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	return body


func _centre(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


## The face tile of a crack nearest a point (world px).
func _near_face(c: Dictionary, pos: Vector2) -> Vector2:
	var best := Vector2.INF
	for f in c["faces"]:
		var q := _centre(f["tile"]) + Vector2(f["out"]) * CELL * 0.5
		if best == Vector2.INF or q.distance_to(pos) < best.distance_to(pos):
			best = q
	return best


## A melee swing (player.gd): a heavy one breaks a crack it reaches; a
## lighter one knocks hollow. Returns true if it touched one.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float, heavy: bool) -> bool:
	var hit := false
	for c in list:
		if c["broken"]:
			continue
		var q := _near_face(c, from)
		var to := q - from
		if to.length() > reach + 22.0 or absf(dir.angle_to(to)) > deg_to_rad(arc_deg + 20.0):
			continue
		hit = true
		if heavy:
			crumble(c)
		else:
			knocks += 1
			main.fx_burst(q, -to.normalized(), Palette.WALL_EDGE, 6, 90.0)
			main.sfx("hit_armor", 0.55, -6.0)
			main.fx_text(q + Vector2(0, -24), TEXT["knock"], Color(0.85, 0.8, 0.72))
	return hit


## A burst (bombs, flasks, spells: main.explode): breaks cracks it reaches.
func blast(pos: Vector2, r: float) -> void:
	for c in list:
		if not c["broken"] and _near_face(c, pos).distance_to(pos) < r + 24.0:
			crumble(c)


func crumble(c: Dictionary) -> void:
	if c["broken"]:
		return
	c["broken"] = true
	broken_count += 1
	_set_solid(c["tiles"], false)
	if c.has("alcove"):
		_set_solid(main._tiles_in(c["alcove"]), false)
	if c.get("body") != null and is_instance_valid(c["body"]):
		c["body"].queue_free()
	c["body"] = null
	for t in c["tiles"]:
		var p := _centre(t)
		main.fx_burst(p, Vector2.ZERO, Palette.WALL_EDGE, 14, 200.0)
		main.fx_burst(p, Vector2.UP, Color(0.55, 0.5, 0.45), 10, 80.0)
		for k in 3:
			rubble.append({"pos": p + Vector2(randf_range(-14, 14), randf_range(-14, 14)), "r": randf_range(3.5, 7.0), "rot": randf() * TAU})
	main.shake(6.0)
	main.sfx("slam", 0.75, -2.0)
	main.sfx("hit_heavy", 0.6, -4.0)
	main.fx_text(_centre(c["tiles"][0]) + Vector2(0, -30), TEXT["loop"] if c["kind"] == "loop" else TEXT["crumble"], Color(0.95, 0.88, 0.7))
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))  # look again: there's more to see
	if main.room_view != null:
		main.room_view.queue_redraw()
	if c.has("reward") and main.lighting != null:
		c["light"] = main.lighting.add_light(c["reward"]["pos"], 110.0, Color(1.0, 0.82, 0.45), 0.6, 0.2)
	main.MakersScript.feed(main, "secret_room", 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if list.is_empty() or main == null or main.player == null:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	for c in list:
		if not c["broken"]:
			# Dust drifts down from it now and then while you're near.
			c["dust_t"] -= delta
			if c["dust_t"] <= 0.0:
				c["dust_t"] = randf_range(RULES["dust_every"][0], RULES["dust_every"][1])
				var q := _near_face(c, pos)
				if q.distance_to(pos) < float(RULES["dust_near"]):
					main.fx_burst(q + Vector2(randf_range(-10, 10), -14), Vector2.DOWN, Color(0.62, 0.57, 0.5), 5, 40.0)
		elif c.has("reward") and not c["taken"] and not p.dead and pos.distance_to(c["reward"]["pos"]) < float(RULES["reach"]) + p.radius:
			_take(c)
	# A reward waiting behind a broken wall glows: redrawn now and then.
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 12.0
		if list.any(func(c): return c["broken"] and c.has("reward") and not c["taken"]):
			queue_redraw()


var redraw_t := 0.0


func _take(c: Dictionary) -> void:
	c["taken"] = true
	var at: Vector2 = c["reward"]["pos"]
	if c.has("light") and main.lighting != null:
		main.lighting.remove_light(c["light"])
		c.erase("light")
	if String(c["reward"].get("kind", "cache")) == "vault":
		main.offer_vault(main.wings.vault_choices(false), TEXT["vault_title"], [TEXT["vault_sub"]])
	else:
		var kind: String = main.tower_data().get("essence", "air")
		var amount: float = float(RULES["cache_base"]) + float(RULES["cache_per_floor"]) * main.floor_num
		main.gather_essence(kind, amount, at)
		main.fx_text(at + Vector2(0, -36), TEXT["cache"] % int(amount), Essence.color(kind))
		if randf() < float(RULES["gear_chance"]):
			var g = main.find_gear("", 1)
			if not g.is_empty():
				main.drop_gear(at + Vector2(0, 14), g, true)
				main.fx_text(at + Vector2(0, -54), TEXT["gear"] % Gear.display(g), Gear.color(g))
	main.fx_ring(at, Color(1.0, 0.85, 0.5), 60.0, 0.5, 3.0)
	main.sfx("glint", 1.2, -2.0)
	queue_redraw()


## What a test or the bot needs: the cracks not yet broken.
func intact() -> Array:
	return list.filter(func(c): return not c["broken"])


func _draw() -> void:
	if list.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var tint: Color = main.room_view.tint if main != null and main.room_view != null and "tint" in main.room_view else Color.WHITE
	for r in rubble:
		var q: Vector2 = r["pos"]
		draw_circle(q + Vector2(1.5, 2.0), r["r"], Color(0, 0, 0, 0.3))
		draw_colored_polygon(_rock(q, r["r"], r["rot"]), (Palette.WALL_TOP.lightened(0.18)) * tint)
	for c in list:
		if c["broken"]:
			if c.has("reward") and not c["taken"]:
				_draw_reward(c, t)
			continue
		for tt in c["tiles"]:
			var rect := Rect2(main.room.position + Vector2(tt) * CELL, Vector2(CELL, CELL))
			var face_tile := false
			var out := Vector2.ZERO
			for f in c["faces"]:
				if f["tile"] == tt:
					face_tile = true
					out = f["out"]
			# The wall itself, in the tower's stone.
			draw_rect(rect, (Palette.VOID.lerp(Palette.WALL_TOP, 0.62)) * tint)
			if face_tile and out == Vector2.DOWN:
				var face := Rect2(rect.position + Vector2(0, CELL * 0.35), Vector2(CELL, CELL * 0.65))
				draw_rect(face, Palette.WALL_FACE * tint)
			if face_tile:
				_draw_crack(rect, out, int(tt.x * 7 + tt.y * 13))


## Cracks: a jagged split from the middle out, branching, with a pale edge,
## and a little rubble at the foot of the wall.
func _draw_crack(rect: Rect2, out: Vector2, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var c := rect.get_center() + out * CELL * 0.12
	var dark := Color(0.02, 0.015, 0.025, 1.0)
	var lit := Color(0.85, 0.78, 0.66, 0.7)
	# A paler, broken block among the dark wall, so it reads from a distance.
	draw_rect(rect.grow(-3.0), Color(0.62, 0.58, 0.54, 0.18))
	draw_rect(rect.grow(-3.0), Color(0.05, 0.04, 0.05, 0.6), false, 1.5)
	for b in 5:
		var a := rng.randf() * TAU
		var p := c
		var pts := PackedVector2Array([p])
		for s in 5:
			a += rng.randf_range(-0.6, 0.6)
			p += Vector2.from_angle(a) * rng.randf_range(4.5, 8.0)
			p = p.clamp(rect.position + Vector2(2, 2), rect.end - Vector2(2, 2))
			pts.append(p)
		draw_polyline(pts, lit, 4.0)
		draw_polyline(pts, dark, 2.2)
	draw_circle(c, 3.4, dark)
	# Chips at its foot, on the floor side.
	for k in 3:
		var q := rect.get_center() + out * CELL * 0.62 + out.orthogonal() * rng.randf_range(-12, 12)
		draw_circle(q, rng.randf_range(1.5, 2.6), Color(0.55, 0.5, 0.44, 0.9))


func _draw_reward(c: Dictionary, t: float) -> void:
	var at: Vector2 = c["reward"]["pos"]
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	if String(c["reward"].get("kind", "cache")) == "vault":
		draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 18)), Palette.OUTLINE)
		draw_rect(Rect2(at + Vector2(-10, -4), Vector2(20, 14)), Color(0.5, 0.42, 0.3))
		draw_rect(Rect2(at + Vector2(-8, -14), Vector2(16, 10)), Color(0.95, 0.78, 0.4, 0.7 + 0.3 * pulse))
	else:
		var col: Color = Essence.color(main.tower_data().get("essence", "air"))
		draw_circle(at + Vector2(0, 6), 11.0, Palette.OUTLINE)
		draw_circle(at + Vector2(0, 6), 9.0, Color(0.42, 0.34, 0.28))
		draw_circle(at, 6.0 + pulse * 1.5, Color(col, 0.85))


func _rock(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 5:
		pts.append(c + Vector2.from_angle(rot + k * TAU / 5.0) * r * (0.75 + 0.25 * float((k * 37) % 3) / 2.0))
	return pts
