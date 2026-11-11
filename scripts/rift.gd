extends Node2D
## The Designer's rift (Build, depth 5, once a climb): a corridor torn
## through the floor, two tiles wide, from where the climber stands to the
## stair, straight or with one bend (whichever tears less rock). It goes
## through anything in the way: rock, walls, cover, pillars, doors, trap
## rooms (traps on its tiles are destroyed), sealed wings and their vaults,
## secret rooms (running right beside one tears into it too). Anything
## locked it passes is opened, and what it held is
## TAKEN, not given: a vault's pedestal and cards, a locked room's cache and
## drops, a secret room's contents (and a Maker's fragment on its wall).
##
## Everything that reads solid tiles is brought up to date: main.solid, the
## path grid (main.astar), the walls' collision (main.layout_bodies: the
## runs over torn tiles are cut, and rock newly bared gets its own), the fog
## (it looks again), the lighting's shadows (lighting.gd notices main.solid
## changing and redoes the shadows near it), the floor and walls drawing
## (room.gd draws again from the grid; torches and door-frame posts on torn
## rock go), and the doors' drawing.
##
## Safety: never the floor's outer wall (a tile at the edge is never torn),
## never on the Proving's floor (secret_deep.gd checks), and nothing is ever
## closed, so the climber can't be shut in and the stair stays reachable.
## Words and numbers: secret_bonds.gd (RIFT, TEXT, BUILD["rift"]).
##
## Drawn on the floor (z -6: over the room, under traps, doors and everyone)
## as raw torn rock: rubble where rock was, jagged teeth of rock along its
## edges, and a faint fissure glowing in the Designer's colour (with a few
## faint lights, so it shows in the dark).

const SB := preload("res://scripts/secret_bonds.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Floors := preload("res://scripts/floors.gd")

const C := Floors.CELL
const N4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

var main
var tiles := {}  # Vector2i -> true: every tile the rift runs through this floor
var torn := {}  # Vector2i -> true: those that were rock (or a wall, a door...) before
var line: Array = []  # the fissure: points along its middle
var lights: Array = []
var taken: Array = []  # (tests) what it took: "vault:<id>", "door:<lock id>", "secret:<i>"
var traps_gone := 0  # (tests) traps it destroyed
var _seed := 0


func _ready() -> void:
	z_as_relative = false
	z_index = -6


## A new floor: the old floor's rift went with it.
func clear() -> void:
	tiles = {}
	torn = {}
	line = []
	for id in lights:
		if main != null and main.lighting != null:
			main.lighting.remove_light(id)
	lights = []
	taken = []
	traps_gone = 0
	queue_redraw()


func _inside(t: Vector2i) -> bool:
	var gs: Vector2i = main.grid_size
	return t.x >= 1 and t.y >= 1 and t.x <= gs.x - 2 and t.y <= gs.y - 2  # (never the outer wall)


func _center(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * C


func _tile_rect(t: Vector2i) -> Rect2:
	return Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))


# --- where it runs ------------------------------------------------------------------

## The tiles of a rift from `a` to `b`: the bend after going across first
## (`across_first`) or down first, each step a 2x2 block (two tiles wide,
## offset toward `side`), never the outer wall.
func path(a: Vector2i, b: Vector2i, across_first: bool, side: Vector2i) -> Dictionary:
	var mids: Array = []
	var bend := Vector2i(b.x, a.y) if across_first else Vector2i(a.x, b.y)
	for leg in [[a, bend], [bend, b]]:
		var from: Vector2i = leg[0]
		var to: Vector2i = leg[1]
		var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var t := from
		mids.append(t)
		while t != to:
			t += step
			mids.append(t)
	var out := {}
	for m in mids:
		for d in [Vector2i(0, 0), Vector2i(side.x, 0), Vector2i(0, side.y), side]:
			var t: Vector2i = m + d
			if not _inside(t):
				t = m - d  # (at the edge, the other side)
			if _inside(t):
				out[t] = true
	return {"tiles": out, "mids": mids}


## How much a rift would tear: rock tiles, and a heavy price for running
## through the floor's live puzzle room (it would rather go round).
func _cost(set: Dictionary) -> float:
	var n := 0.0
	var pz_room := Rect2()
	if main.puzzle != null and main.puzzle.active() and not main.floor_plan.get("puzzle", {}).is_empty():
		pz_room = main.floor_plan["puzzle"]["room"]
	for t in set:
		if main._is_solid_tile(t.x, t.y):
			n += 1.0
		if pz_room.size != Vector2.ZERO and pz_room.has_point(_center(t)):
			n += 30.0
	return n


## The rift this climber would tear from where they stand: {tiles, mids}
## ({} if there's nowhere to tear: the stair is where you stand).
func plan_from(pos: Vector2) -> Dictionary:
	var a: Vector2i = main._tile_of(pos)
	var b: Vector2i = main._tile_of(main.stair_pos)
	if a == b:
		return {}
	var fx: float = fposmod(pos.x - main.room.position.x, C) / C
	var fy: float = fposmod(pos.y - main.room.position.y, C) / C
	var side := Vector2i(1 if fx >= 0.5 else -1, 1 if fy >= 0.5 else -1)
	var p1 := path(a, b, true, side)
	var p2 := path(a, b, false, side)
	return p1 if _cost(p1["tiles"]) <= _cost(p2["tiles"]) else p2


## True if the rift would tear anything at all (rock, a door, a trap...).
func worth(pl: Dictionary) -> bool:
	if pl.is_empty():
		return false
	for t in pl["tiles"]:
		if main._is_solid_tile(t.x, t.y):
			return true
	return main.traps.any(func(tr): return pl["tiles"].has(main._tile_of(tr["pos"])))


# --- tearing it -----------------------------------------------------------------------

## Tears the rift from `pos` to the stair. Returns the lines it says ([] if
## it tore nothing).
func tear(pos: Vector2, deep) -> Array:
	var pl := plan_from(pos)
	if not worth(pl):
		return []
	var set: Dictionary = pl["tiles"]
	var lines: Array = [SB.TEXT["rift_done"]]
	_seed = randi()
	for t in set:
		tiles[t] = true
		if main._is_solid_tile(t.x, t.y):
			torn[t] = true
	var gs: Vector2i = main.grid_size
	# What was built by the Designer on its tiles goes.
	if deep != null:
		for w in deep.walls.duplicate():
			if w["tiles"].any(func(t): return set.has(t)):
				if w["body"] != null and is_instance_valid(w["body"]):
					w["body"].queue_free()
				deep.walls.erase(w)
		for g in deep.gates.duplicate():
			if g["tiles"].any(func(t): return set.has(t)):
				if is_instance_valid(g["body"]):
					g["body"].queue_free()
				for t in g["tiles"]:
					main.astar.set_point_solid(t, main._is_solid_tile(t.x, t.y))
				deep.gates.erase(g)
	# Sealed wings and their vaults: opened, and emptied.
	var W = main.wings
	if W != null:
		for w in W.wings:
			var hit := false
			for t in set:
				if w["rect"].grow(2.0).has_point(_center(t)) or t in w["door"] or t == w["vault_door"]:
					hit = true
					break
			if hit and w["vault"] != "taken":
				_empty_wing(w)
				lines.append(SB.TEXT["rift_vault"])
				taken.append("vault:%s" % str(w["id"]))
		for i in W.secrets.size():
			var s: Dictionary = W.secrets[i]
			var st: Array = W._secret_tiles(s)
			var mouth: Vector2i = s["mouth"][0]
			st.append(mouth)
			# Running right beside it tears into it too: its tiles have no wall
			# collision of their own (only its first tile does), so bared rock
			# there would let the climber walk into a passage still shut.
			var beside := func(t: Vector2i) -> bool:
				return t != mouth and N4.any(func(d): return set.has(t + d))
			if (st.any(func(t): return set.has(t)) or st.any(beside)) and not s["taken"]:
				_empty_secret(s)
				lines.append(SB.TEXT["rift_secret"])
				taken.append("secret:%d" % i)
	# Doors: any on its tiles is torn away; a locked room it passes is opened and emptied.
	var DV = main.door_view
	if DV != null:
		for d in DV.list.duplicate():
			var on_it: bool = d["tiles"].any(func(t): return set.has(t))
			var room_i: int = int(d["room"])
			var through := false
			if room_i >= 0 and room_i < main.room_info.size():
				var rr: Rect2 = main.room_info[room_i]["rect"]
				for t in set:
					if rr.has_point(_center(t)):
						through = true
						break
			if String(d["lock"]) != "" and (on_it or through):
				var lid := int(d["lock_id"])
				_drop_lock_items(lid)
				d["lock"] = ""
				if room_i >= 0 and room_i < main.room_info.size():
					_empty_room(main.room_info[room_i]["rect"])
				lines.append(SB.TEXT["rift_door"])
				taken.append("door:%d" % lid)
				if not on_it:
					DV.open_door(d, true)
			if on_it:
				for t in d["tiles"]:
					main.solid[t.y * gs.x + t.x] = 0
					main.astar.set_point_solid(t, false)
				if is_instance_valid(d["body"]):
					d["body"].queue_free()
				DV._drop_light(d)
				DV.list.erase(d)
		# Lock-in rooms it runs through never shut (and one that's shut opens).
		for i in DV.lock_rooms:
			var lr: Dictionary = DV.lock_rooms[i]
			if i < 0 or i >= main.room_info.size():
				continue
			var rr2: Rect2 = main.room_info[i]["rect"].grow(C)
			if set.keys().any(func(t): return rr2.has_point(_center(t))):
				if lr["state"] == "shut":
					DV._reopen(lr)
				lr["state"] = "done"
		DV._redraw()
	# The puzzle's bars on its tiles lift (the puzzle itself still waits).
	var pz = main.puzzle
	if pz != null:
		for g in pz.gates:
			if g["open"]:
				continue
			if main._tiles_in(g["rect"]).any(func(t): return set.has(t)):
				g["open"] = true
				if is_instance_valid(g["body"]):
					g["body"].queue_free()
				pz.set_solid(g["rect"], false)
		pz.queue_redraw()
	# Traps on its tiles are destroyed.
	var before: int = main.traps.size()
	main.traps = main.traps.filter(func(tr): return not set.has(main._tile_of(tr["pos"])))
	traps_gone += before - main.traps.size()
	if traps_gone > 0:
		lines.append(SB.TEXT["rift_traps"] % traps_gone)
	# Cover, pillars and torches in its way.
	var blocks: Array = []
	for b in main.layout_blocks:
		if main._tiles_in(b).any(func(t): return set.has(t)):
			for t in main._tiles_in(b):  # (all of it goes, and its collision with it)
				set[t] = true
				tiles[t] = true
				torn[t] = true
		else:
			blocks.append(b)
	main.layout_blocks = blocks
	var keep_p: Array = []
	var keep_b: Array = []
	for i in main.pillars.size():
		var pp: Dictionary = main.pillars[i]
		if set.has(main._tile_of(pp["pos"])):
			if i < main.pillar_bodies.size():
				main._drop_body(main.pillar_bodies[i])
			continue
		keep_p.append(pp)
		if i < main.pillar_bodies.size():
			keep_b.append(main.pillar_bodies[i])
	if keep_p.size() != main.pillars.size():
		main.pillars = keep_p  # (a new list: the lighting builds its grid again)
		main.pillar_bodies = keep_b
		main.room_view.set_pillars(keep_p)
	# The rock itself.
	for t in set:
		main.solid[t.y * gs.x + t.x] = 0
		main.astar.set_point_solid(t, false)
	_recollide(set)
	# The drawing.
	var rv = main.room_view
	rv.blocks = main.layout_blocks
	rv.block_tiles.clear()
	for b in rv.blocks:
		for t in main._tiles_in(b):
			rv.block_tiles[t] = true
	rv.torches = rv.torches.filter(func(tc): return not set.has(main._tile_of(tc["pos"])))
	rv.doors = rv.doors.filter(func(r): return main.is_solid(r.get_center()))
	rv.queue_redraw()
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))  # (look again)
	if W != null:
		W.dirty = true
		W.queue_redraw()
	main.trap_view.set("_drawn_n", -1)
	_make_line(pl["mids"])
	queue_redraw()
	return lines


## A sealed wing the rift tears into: its question ends, its door and vault
## stand open, and the vault is empty.
func _empty_wing(w: Dictionary) -> void:
	var W = main.wings
	if w["state"] != "done":
		w["state"] = "done"
		W._open(w["door"], w.get("gate_body"))
		w["gate_body"] = null
		if W.active == w:
			W.active = {}
	for key in ["light", "prize_light"]:
		if w.has(key):
			main.lighting.remove_light(w[key])
			w.erase(key)
	W._open([w["vault_door"]], w.get("vault_body"))
	w["vault_body"] = null
	w["vault"] = "taken"
	w.erase("drop")
	var d: Dictionary = main.door_view.door_at(w["door"][0])
	if not d.is_empty():
		_drop_lock_items(int(d["lock_id"]) if String(d["lock"]) != "" else -1)
		d["lock"] = ""
		if not d["open"]:
			main.door_view.open_door(d, true)
	_lose_fragment(w)


## A secret room the rift tears into: open, and empty.
func _empty_secret(s: Dictionary) -> void:
	var W = main.wings
	var st: Array = W._secret_tiles(s)
	W._set_solid(st, false)
	W._open([s["mouth"][0]], s.get("body"))
	s["body"] = null
	if s.get("vault_body") != null:
		W._open([s["vault_door"]], s["vault_body"])
		s["vault_body"] = null
	s["open"] = true
	s["taken"] = true
	if s.has("vault"):
		s["vault"] = "taken"
	if s.has("light"):
		main.lighting.remove_light(s["light"])
		s.erase("light")
	_lose_fragment(s)


## A Maker's fragment on the wall of a vault or secret room the rift emptied goes too.
func _lose_fragment(ref: Dictionary) -> void:
	var mk = main.makers
	if mk != null and not mk.fragment.is_empty() and is_same(mk.fragment.get("ref"), ref) and not mk.fragment.get("read", false):
		mk.clear_floor()


## A locked room the rift tears into: its cache and anything lying there is gone.
func _empty_room(r: Rect2) -> void:
	if not main.cache.is_empty() and not main.cache["taken"] and r.has_point(main.cache["pos"]):
		main.cache["taken"] = true
		main.room_view.refresh_features()
	main.gear_drops = main.gear_drops.filter(func(g): return not r.has_point(g["pos"]))
	main.item_drops = main.item_drops.filter(func(g): return not r.has_point(g["pos"]))


## The key or lever of a lock that's gone is gone too (-1: none).
func _drop_lock_items(lock_id: int) -> void:
	if lock_id < 0:
		return
	var DV = main.door_view
	for arr in [DV.keys, DV.levers]:
		for k in arr.duplicate():
			if int(k["lock_id"]) == lock_id:
				if k.has("light"):
					main.lighting.remove_light(k["light"])
				arr.erase(k)


## A solid tile that something else owns (a door, a vault's door, an unopened
## secret, a shut doorway, a Designer's wall): no wall collision of its own.
func _owned(t: Vector2i) -> bool:
	var DV = main.door_view
	if DV != null and not DV.door_at(t).is_empty():
		return true
	var W = main.wings
	if W != null:
		for w in W.wings:
			if t == w["vault_door"] or t in w["door"]:
				return true
		for s in W.secrets:
			if not s["open"] and (t in W._secret_tiles(s) or t == s["mouth"][0]):
				return true
			if s.has("vault_door") and t == s["vault_door"]:
				return true
	if DV != null:
		for i in DV.lock_rooms:
			if DV.lock_rooms[i]["state"] == "shut" and t in DV._gate_tiles(DV.lock_rooms[i]):
				return true
	var deep = main.secret_tools.deep if main.secret_tools != null else null
	if deep != null and deep.walls.any(func(w): return t in w["tiles"]):
		return true
	return false


## The walls' collision: runs over torn tiles are cut, and rock the rift
## bared (rock beside it with no collision yet) gets runs of its own.
func _recollide(set: Dictionary) -> void:
	var covered := {}
	for b in main.layout_bodies.duplicate():
		if not is_instance_valid(b) or b.get_child_count() == 0:
			continue
		var sh = b.get_child(0).shape
		if not (sh is RectangleShape2D):
			continue
		var r := Rect2(b.position - sh.size * 0.5, sh.size)
		var run: Array = main._tiles_in(r.grow(-2.0))
		if not run.any(func(t): return set.has(t)):
			for t in run:
				covered[t] = true
			continue
		main.layout_bodies.erase(b)
		main._drop_body(b)
		_add_runs(run.filter(func(t): return not set.has(t)), covered)
	var bare: Array = []
	for t in set:
		for d in N8:
			var n: Vector2i = t + d
			if set.has(n) or covered.has(n) or bare.has(n):
				continue
			if main._is_solid_tile(n.x, n.y) and n.x >= 0 and n.y >= 0 and n.x < main.grid_size.x and n.y < main.grid_size.y and not _owned(n):
				bare.append(n)
	_add_runs(bare, covered)


## Bodies for these tiles, merged into runs along each row.
func _add_runs(list: Array, covered: Dictionary) -> void:
	var rows := {}
	for t in list:
		if not rows.has(t.y):
			rows[t.y] = []
		rows[t.y].append(t.x)
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var last: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == last + 1:
				last = xs[i]
				continue
			var r := Rect2(main.room.position + Vector2(start, y) * C, Vector2(last - start + 1, 1) * C)
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
			main.layout_bodies.append(body)
			for x in range(start, last + 1):
				covered[Vector2i(x, y)] = true
			if i < xs.size():
				start = xs[i]
				last = xs[i]


# --- how it looks -----------------------------------------------------------------------

## The fissure along its middle (jagged), and a few faint lights on it.
func _make_line(mids: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	line = []
	for i in mids.size():
		# (toward the middle of the band, two tiles wide)
		var mid := _center(mids[i])
		var nb := 0
		var sum := Vector2.ZERO
		for d in [Vector2i(0, 0)] + N8:
			var t: Vector2i = mids[i] + d
			if tiles.has(t):
				sum += _center(t)
				nb += 1
		if nb > 0:
			mid = mid.lerp(sum / nb, 0.6)
		line.append(mid + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)))
	var col := SB.color("designer")
	if main.lighting != null:
		var every := int(SB.RIFT["light_every"])
		for i in range(0, line.size(), every):
			lights.append(main.lighting.add_light(line[i], float(SB.RIFT["light_reach"]), col, float(SB.RIFT["light"]), float(SB.RIFT["glow"])))


func _draw() -> void:
	if main == null or tiles.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var col := SB.color("designer")
	var rock := Palette.WALL_TOP
	var floor_dark := Palette.FLOOR.darkened(0.45)
	var b := Draw.Batch.new()
	# Rubble where rock was: dark broken ground, loose stones, cracks.
	for t in torn:
		var r := _tile_rect(t)
		b.rect(r, floor_dark)
		for k in 4:
			var at := r.position + Vector2(rng.randf_range(4.0, C - 4.0), rng.randf_range(4.0, C - 4.0))
			var s := rng.randf_range(2.0, 5.5)
			b.poly(PackedVector2Array([at + Vector2(-s, 0), at + Vector2(-s * 0.3, -s * 0.8), at + Vector2(s, -s * 0.2), at + Vector2(s * 0.4, s * 0.7)]), rock.darkened(rng.randf_range(0.1, 0.4)), 0.6)
		if rng.randf() < 0.6:
			var p0 := r.position + Vector2(rng.randf_range(0.0, C), 0.0)
			var p1 := r.get_center() + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
			var p2 := r.position + Vector2(rng.randf_range(0.0, C), C)
			b.line(p0, p1, Color(0, 0, 0, 0.45), 1.2)
			b.line(p1, p2, Color(0, 0, 0, 0.45), 1.2)
	# Where rock stands north of it, its face is torn raw, not bricked: rough
	# stone, a ragged lip hanging over the rift, cracks lit faintly.
	for t in torn:
		var n: Vector2i = t + Vector2i(0, -1)
		if tiles.has(n) or not main._is_solid_tile(n.x, n.y):
			continue
		var nr := _tile_rect(n)
		var top := nr.position.y + C * 0.3
		var face := PackedVector2Array([Vector2(nr.position.x, top), Vector2(nr.end.x, top)])
		var steps := 6
		for k in range(steps, -1, -1):
			var x := nr.position.x + C * float(k) / float(steps)
			face.append(Vector2(x, nr.end.y + (rng.randf_range(2.0, 9.0) if k % 2 == 1 else rng.randf_range(-2.0, 2.0))))
		b.polygon(face, rock.darkened(0.3))
		for k in 3:
			var at := Vector2(nr.position.x + rng.randf_range(4.0, C - 4.0), top + rng.randf_range(3.0, C * 0.5))
			b.poly(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(-1, -3), at + Vector2(5, -1), at + Vector2(2, 3)]), rock.darkened(rng.randf_range(0.05, 0.25)), 0.0)
		var c0 := Vector2(nr.position.x + rng.randf_range(6.0, C - 6.0), top + 2.0)
		var c1 := c0 + Vector2(rng.randf_range(-6.0, 6.0), C * 0.3)
		var c2 := c1 + Vector2(rng.randf_range(-6.0, 6.0), C * 0.3)
		b.line(c0, c1, Color(0, 0, 0, 0.6), 1.6)
		b.line(c1, c2, Color(0, 0, 0, 0.6), 1.4)
		b.line(c1, c2, Color(col, 0.3), 0.8)
		b.line(Vector2(nr.position.x, top), Vector2(nr.end.x, top), Color(rock.lightened(0.1), 0.8), 1.5)
	# Jagged teeth of torn rock along its edges (where rock still stands).
	for t in torn:
		var r := _tile_rect(t)
		for d in N4:
			var n: Vector2i = t + d
			if tiles.has(n) or not main._is_solid_tile(n.x, n.y):
				continue
			var a: Vector2
			var e: Vector2
			match d:
				Vector2i(1, 0):
					a = Vector2(r.end.x, r.position.y)
					e = r.end
				Vector2i(-1, 0):
					a = r.position
					e = Vector2(r.position.x, r.end.y)
				Vector2i(0, 1):
					a = Vector2(r.position.x, r.end.y)
					e = r.end
				_:
					a = r.position
					e = Vector2(r.end.x, r.position.y)
			var inward := -Vector2(d)
			var pts := PackedVector2Array([a])
			var n_teeth := 4
			for k in range(1, n_teeth * 2):
				var f := float(k) / float(n_teeth * 2)
				var depth := rng.randf_range(6.0, 13.0) if k % 2 == 1 else rng.randf_range(1.0, 4.0)
				pts.append(a.lerp(e, f + rng.randf_range(-0.03, 0.03)) + inward * depth)
			pts.append(e)
			b.polygon(pts, rock.darkened(0.15))
			var glow := PackedVector2Array()
			for k in range(1, pts.size() - 1):
				glow.append(pts[k])
			for k in range(1, glow.size()):
				b.line(glow[k - 1], glow[k], Color(col, 0.28), 1.4)
	# The fissure down its middle, faintly glowing.
	for i in range(1, line.size()):
		b.line(line[i - 1], line[i], Color(0.02, 0.01, 0.03, 0.85), 4.0)
		b.line(line[i - 1], line[i], Color(col, 0.55), 1.6)
		b.line(line[i - 1], line[i], Color(col.lightened(0.5), 0.35), 0.7)
	for i in range(0, line.size(), 3):
		b.dot(line[i], 5.0, Color(col, 0.12))
	b.flush(self)
