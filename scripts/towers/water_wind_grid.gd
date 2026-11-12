extends RefCounted
## Tile-grid helpers shared by the Kraken's and the Gryphon's floor scripts
## (kraken_floor.gd, gryphon_floor.gd): the floor's grid as the climber
## walks it, the "nothing cut off" check every pool and void must pass, and
## corridors seen along their length.
##
## The rule both towers keep: ground that can't be crossed on foot (deep
## water, an open void) may never cut any other floor off from the start.
## It may only take away the tiles it covers. (Water held back by a valve
## and a gap the wind will bridge are locks instead: reach.gd "fluid_locks".)

const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0  # (floors.gd CELL)
const CELL_TILES := Vector2i(16, 14)  # (floors.gd CELL_TILES)
const N4 := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const N8 := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


## A world point's tile.
static func tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - ORIGIN.x) / CELL)), int(floor((pos.y - ORIGIN.y) / CELL)))


## A tile's middle (world px).
static func centre(t: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


## The tiles a world rect covers.
static func tiles_of(r: Rect2) -> Array:
	var out: Array = []
	var p := Vector2i(int(round((r.position.x - ORIGIN.x) / CELL)), int(round((r.position.y - ORIGIN.y) / CELL)))
	var e := Vector2i(int(round((r.end.x - ORIGIN.x) / CELL)), int(round((r.end.y - ORIGIN.y) / CELL)))
	for y in range(p.y, e.y):
		for x in range(p.x, e.x):
			out.append(Vector2i(x, y))
	return out


static func tiles_of_i(r: Rect2i) -> Array:
	var out: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


## Tiles as world rects, runs in each row joined (fewer bodies, fewer draws).
static func merge(tiles: Array) -> Array:
	var list: Array = tiles.duplicate()
	list.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	var run_start := Vector2i(-99999, -99999)
	var prev := Vector2i(-99999, -99999)
	for t in list:
		if t.y == prev.y and t.x == prev.x + 1:
			prev = t
			continue
		if run_start.x > -99999:
			out.append(Rect2(ORIGIN + Vector2(run_start) * CELL, Vector2(prev.x - run_start.x + 1, 1) * CELL))
		run_start = t
		prev = t
	if run_start.x > -99999:
		out.append(Rect2(ORIGIN + Vector2(run_start) * CELL, Vector2(prev.x - run_start.x + 1, 1) * CELL))
	return out


## The floor's grid as reach.gd sees it: {size, solid (1 = rock)}.
static func grid(plan: Dictionary) -> Dictionary:
	return load("res://scripts/reach.gd").plan_grid(plan)


static func is_open(g: Dictionary, t: Vector2i) -> bool:
	var size: Vector2i = g["size"]
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and g["solid"][t.y * size.x + t.x] == 0


## Walks the grid from `start` (4 ways), never onto a tile in `block`.
## Returns the tiles reached (1) as a byte per tile.
static func walk(g: Dictionary, start: Vector2i, block: Dictionary) -> PackedByteArray:
	var size: Vector2i = g["size"]
	var solid: PackedByteArray = g["solid"]
	var reach := PackedByteArray()
	reach.resize(size.x * size.y)
	if not is_open(g, start) or block.has(start):
		return reach
	var q := PackedInt32Array([start.y * size.x + start.x])
	reach[q[0]] = 1
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var x := i % size.x
		var y := i / size.x
		for d in N4:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
				continue
			var j := ny * size.x + nx
			if reach[j] == 1 or solid[j] == 1 or block.has(Vector2i(nx, ny)):
				continue
			reach[j] = 1
			q.append(j)
	return reach


## True if blocking `block` (tiles) would cut off any tile `base` reached
## (other than the blocked ones themselves).
static func cuts_off(g: Dictionary, start: Vector2i, base: PackedByteArray, block: Dictionary) -> bool:
	var now := walk(g, start, block)
	var size: Vector2i = g["size"]
	for i in base.size():
		if base[i] == 1 and now[i] == 0 and not block.has(Vector2i(i % size.x, i / size.x)):
			return true
	return false


## The floor's locked doors' tiles (not a door barred from one side: it opens
## from its far side).
static func locked_tiles(plan: Dictionary) -> Dictionary:
	var out := {}
	for d in plan.get("doors", []):
		if not String(d.get("lock", "")) in ["", "oneway"]:
			for t in d["tiles"]:
				out[t] = true
	for w in plan.get("wings", []):
		if String(w.get("lock", "")) != "":
			for t in w.get("door", []):
				out[t] = true
	return out


## The "nothing cut off" check both ways: with every door open, and with the
## locked doors still shut (a key or its carrier must stay on this side).
## `walks` is from walks(): {base, base_locked, locked}.
static func cuts(g: Dictionary, start: Vector2i, walks_: Dictionary, block: Dictionary) -> bool:
	if cuts_off(g, start, walks_["base"], block):
		return true
	var both: Dictionary = block.duplicate()
	for t in walks_["locked"]:
		both[t] = true
	return cuts_off(g, start, walks_["base_locked"], both)


static func walks(g: Dictionary, start: Vector2i, plan: Dictionary) -> Dictionary:
	var locked := locked_tiles(plan)
	return {"base": walk(g, start, {}), "base_locked": walk(g, start, locked), "locked": locked}


## Tiles that must stay plain floor (and a tile around each): the start,
## the stair, doors and doorways, what the floor asks you to reach
## (floors.gd cover_targets), monsters, and each room's reserved tiles.
static func protected(plan: Dictionary, infos: Array, monsters_too := true) -> Dictionary:
	var out := {}
	var box := func(t: Vector2i, r: int) -> void:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out[t + Vector2i(dx, dy)] = true
	box.call(tile(plan.get("start", Vector2(-1e6, -1e6))), 2)
	box.call(tile(plan.get("stair", Vector2(-1e6, -1e6))), 2)
	for d in plan.get("doors", []):
		for t in d["tiles"]:
			box.call(t, 1)
	for w in plan.get("wings", []) + plan.get("secrets", []):
		for t in w.get("mouth", []) + w.get("door", []):
			box.call(t, 1)
	for r in plan.get("doorways", []):
		for t in tiles_of(r):
			box.call(t, 1)
	var targets: Array = load("res://scripts/floors.gd").cover_targets(plan)
	if not monsters_too:
		var mons: Array = plan.get("monsters", []).map(func(m): return m[1])
		targets = targets.filter(func(p): return not (p in mons))
	for p in targets:
		box.call(tile(p), 1)
	for c in plan.get("cracks", []):
		for f in c.get("faces", []):
			box.call(f["tile"], 1)
		for t in c.get("tiles", []):
			box.call(t, 1)
	var pz: Dictionary = plan.get("puzzle", {})
	if not pz.is_empty() and pz.has("room"):
		for t in tiles_of(load("res://scripts/floors.gd")._snap(pz["room"])):
			out[t] = true
	for info in infos:
		var at: Vector2i = info["pos"]
		for t in info.get("reserved", {}):
			out[at + Vector2i(t)] = true
	return out


## A room's open tiles (grid tiles), from its rows.
static func room_tiles(info: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = info["rows"]
	var at: Vector2i = info["pos"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "X" and row[x] != "#":
				out.append(at + Vector2i(x, y))
	return out


## Which rooms each room is joined to (by corridors and loops).
static func degree(links: Array, n: int) -> Array:
	var out: Array = []
	out.resize(n)
	out.fill(0)
	for l in links:
		out[int(l["c"])] += 1
		out[int(l["p"])] += 1
	return out


## A corridor seen along its length: {ew (runs east-west), axis0 (first
## tile along it), len, lat (its first tile across), cell_lat (the band of
## cells it runs in, as lateral tiles [lo, hi])}. `at(i, j)` turns (along,
## across) into a tile.
static func corridor(link: Dictionary, infos: Array, c: int) -> Dictionary:
	var cr: Rect2i = link["corridor"]
	var ew: bool = int(link["side_c"]) >= 2
	var cell: Vector2i = infos[c]["cell"]
	var span := CELL_TILES.y if ew else CELL_TILES.x
	var band := cell.y if ew else cell.x
	return {"ew": ew, "axis0": cr.position.x if ew else cr.position.y, "len": cr.size.x if ew else cr.size.y,
		"lat": cr.position.y if ew else cr.position.x, "lo": band * span + 1, "hi": (band + 1) * span - 2}


static func at(c: Dictionary, i: int, j: int) -> Vector2i:
	return Vector2i(int(c["axis0"]) + i, j) if c["ew"] else Vector2i(j, int(c["axis0"]) + i)


## Whether a new tile beside a corridor keeps clear of everything else on the
## floor: none of its eight neighbours is taken (`occ`) unless it's one of
## this corridor's own (`own`).
static func clear_beside(t: Vector2i, occ: Dictionary, own: Dictionary) -> bool:
	if t.x < 0 or t.y < 0:
		return false
	for d in N8:
		var n: Vector2i = t + d
		if occ.has(n) and not own.has(n):
			return false
	return not (occ.has(t) and not own.has(t))
