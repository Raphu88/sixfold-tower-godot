extends RefCounted
## Rooms, drawn as text grids: one character per 40 px tile. floors.gd picks
## a hand-made room ("prefab") or carves a plain shape for each room of a
## floor, flips prefabs at random so they don't repeat exactly, and joins the
## rooms with corridors that meet them at their EDGES (never through them):
## a corridor only enters where the room's outer two rows are open floor, so
## nothing drawn here is ever cut away. Edit or add rooms here: each row of
## a grid must be the same length, and a room may be at most MAX_SIZE tiles.
##
## Legend:
##   .  floor
##   X  rock: not part of the room (its outline bends around it)
##   #  wall (a solid tile: blocks movement, sight and shots). A wall that
##      touches the room's edge becomes part of its outline (like X); one
##      standing free inside is drawn as a low stone wall.
##   o  pillar (round, blocks movement and shots)
##   C  chasm in towers that have them (the Firebird's); a wall elsewhere
##   ~  standing water in towers that have it (the Kraken's); floor elsewhere
##   M  a monster's spot (monsters prefer these)
##   ?  random: usually floor, sometimes a wall or a pillar
## Puzzle rooms (puzzle.gd) also use:
##   =  low rail: blocks walking, not sight or shots (arrows fly over it)
##   E  a stone eye to hit (with a strike or an arrow)
##   P  a pressure plate that needs a weight (a block or a monster)
##   B  a stone block to push
##   G  a gate, open once the puzzle is solved
##   L  a lever that puts the blocks back
##   $  the reward behind the gate
##
## Each room: id, role ("start", "combat", "puzzle" or "stair"), the first
## floor it can appear on, whether it may be flipped, and its grid. Puzzle
## rooms also say which puzzle they hold and how hard it is (tier 1 or 2).
## Stair rooms keep the middle of their top row open: the stair stands there.

## The biggest a room may be, in tiles (it must fit a cell of the floor's plan).
const MAX_SIZE := Vector2i(14, 12)

const ROOMS := [
	# --- start rooms: calm, open, a pillar or two -----------------------------
	{"id": "start_plain", "role": "start", "from": 1, "flip": true, "grid": [
		"...........",
		".o.......o.",
		"...........",
		"...........",
		"...........",
		"...........",
		"...........",
		".o.......o.",
		"...........",
	]},
	{"id": "start_alcoves", "role": "start", "from": 1, "flip": true, "grid": [
		"##.......##",
		"#.........#",
		"...........",
		"...........",
		"...........",
		"...........",
		"...........",
		"#.........#",
		"##.......##",
	]},
	# --- stair rooms: the stair stands at the top middle ----------------------
	{"id": "stair_flanked", "role": "stair", "from": 1, "flip": false, "grid": [
		"....o...o....",
		".............",
		".............",
		"..M.......M..",
		".............",
		".............",
		".............",
		".o.........o.",
		".............",
	]},
	{"id": "stair_dais", "role": "stair", "from": 1, "flip": false, "grid": [
		"###.......###",
		"##.........##",
		".............",
		"...##...##...",
		".............",
		"..M.......M..",
		".............",
		".............",
		".............",
		".............",
	]},
	# --- combat rooms ------------------------------------------------------------
	{"id": "pillared_hall", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		".o.........o.",
		".............",
		"...o.....o...",
		"..M.......M..",
		".............",
		".............",
		"...o.....o...",
		".............",
		".o.........o.",
		".............",
	]},
	{"id": "four_blocks", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		".##.......##.",
		".##.M...M.##.",
		".............",
		"...##...##...",
		".............",
		"...##...##...",
		".............",
		".##.......##.",
		".##.......##.",
		".............",
	]},
	{"id": "l_room", "role": "combat", "from": 2, "flip": true, "grid": [
		"........XXXXX",
		"........XXXXX",
		"...M....XXXXX",
		"...o.........",
		".............",
		".............",
		".........M...",
		".............",
		".....##......",
		".....##....o.",
		".............",
	]},
	{"id": "pit_quarters", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		".CCC.....CCC.",
		".CCC..M..CCC.",
		".............",
		".............",
		".............",
		".............",
		".............",
		".CCC..M..CCC.",
		".CCC.....CCC.",
		".............",
	]},
	{"id": "balcony", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		"..M.......M..",
		".............",
		".####...####.",
		".............",
		".............",
		".............",
		".............",
		".............",
		"...o.....o...",
		".............",
	]},
	{"id": "colonnade", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		".o.o.....o.o.",
		".............",
		".o.o..M..o.o.",
		".............",
		".............",
		".............",
		".o.o..M..o.o.",
		".............",
		".o.o.....o.o.",
		".............",
	]},
	{"id": "alcove_hall", "role": "combat", "from": 2, "flip": true, "grid": [
		"###..###..###",
		"#M.........M#",
		".............",
		".............",
		".............",
		".............",
		".............",
		"#M.........M#",
		"###..###..###",
	]},
	{"id": "split_room", "role": "combat", "from": 3, "flip": true, "grid": [
		"...#.........",
		"...#....M....",
		"...#.........",
		"...#....o....",
		".............",
		".............",
		".............",
		"...#....o....",
		"...#.........",
		"...#....M....",
		"...#.........",
	]},
	{"id": "flooded_court", "role": "combat", "from": 2, "flip": true, "grid": [
		".............",
		".~~~.....~~~.",
		".~~~..o..~~~.",
		".~~~.....~~~.",
		".............",
		"..M.......M..",
		".............",
		".~~~.....~~~.",
		".~~~..o..~~~.",
		".~~~.....~~~.",
		".............",
	]},
	{"id": "rubble_field", "role": "combat", "from": 3, "flip": true, "grid": [
		".............",
		".?..?...?..?.",
		".............",
		"..?..M.M..?..",
		".............",
		".............",
		".............",
		"..?.......?..",
		".............",
		".?..?...?..?.",
		".............",
	]},
	{"id": "crossroads", "role": "combat", "from": 3, "flip": false, "grid": [
		"###.......###",
		"###.......###",
		"##....M....##",
		".............",
		".............",
		".............",
		".............",
		".............",
		"##....M....##",
		"###.......###",
		"###.......###",
	]},
	# --- puzzle rooms: solving one lifts the ward on the stair ------------------
	{"id": "eye_corner", "role": "puzzle", "puzzle": "eyes", "tier": 1, "from": 2, "flip": true, "grid": [
		"#####........",
		"#.E.#........",
		"=...=........",
		"=====........",
		".............",
		".............",
		".............",
		"........###..",
		"........#$#..",
		"........#G#..",
		".............",
	]},
	{"id": "eye_pair", "role": "puzzle", "puzzle": "eyes", "tier": 2, "from": 4, "flip": true, "grid": [
		"#####...#####",
		"#.E.#...#.E.#",
		"=...=...=...=",
		"=====...=====",
		".............",
		".............",
		".............",
		".............",
		".###.........",
		".#$G.........",
		".###.........",
		".............",
	]},
	{"id": "plate_block", "role": "puzzle", "puzzle": "plates", "tier": 1, "from": 2, "flip": true, "grid": [
		".............",
		"..L..........",
		".............",
		"..B..........",
		".............",
		".............",
		".............",
		"..P.....###..",
		"........#$#..",
		"........#G#..",
		".............",
	]},
	{"id": "plate_pair", "role": "puzzle", "puzzle": "plates", "tier": 2, "from": 4, "flip": true, "grid": [
		".............",
		"..B.......M..",
		".............",
		".............",
		"..P.......P..",
		".............",
		".............",
		"..L..........",
		".........###.",
		".........#$#.",
		".........#G#.",
		".............",
	]},
]

const CHARS := ".X#oC~M?=EPBGL$"
## Tiles a corridor may open onto, and a monster or a feature may stand on.
const OPEN := ".M~"

## Carved shapes, for rooms that aren't hand-made (each tower favours some:
## its "shapes" in towers.gd).
##   rect     a plain room
##   open     a plain room, a tile bigger each way
##   hall     long and low
##   ell      one corner quarter filled in (an L)
##   cross    the four corners notched
##   round    the corners cut off
##   pillars  four square pillars, kept clear of the middle
##   ring     a ring around one great block in the middle
##   circle   round: everything outside an ellipse cut away
##   gallery  a long gallery with a row of pillars down each side
##   split    two levels: a ledge of low wall across the room, with steps
##            (gaps) through it; room.gd lights the upper level and draws the steps
##   cover    low walls scattered through the room to hide behind
const SHAPES := ["rect", "open", "hall", "ell", "cross", "round", "pillars", "ring", "circle", "gallery", "split", "cover"]


## Rooms made in the room painter (painter.gd) that pass its checks and are
## switched on for climbs: room_store.gd fills this at startup and whenever
## a room changes. Each is a room like those above, with "towers" (the tower
## ids it may appear in; empty for all) and "ok" (the towers where it passes
## the checks: chasms are only real in some towers).
static var custom: Array = []


## The rooms for a role that can appear on a floor (of the tower `tid`, if
## given: the painter's rooms are only offered where they're allowed and pass).
static func for_role(role: String, floor_num: int, tid := "") -> Array:
	var out: Array = ROOMS.filter(func(r): return r["role"] == role and int(r["from"]) <= floor_num)
	for r in custom:
		if r["role"] != role or int(r["from"]) > floor_num:
			continue
		var towers: Array = r.get("towers", [])
		var ok: Array = r.get("ok", [])
		if tid != "" and ((not towers.is_empty() and not (tid in towers)) or not (tid in ok)):
			continue
		if tid == "" and ok.is_empty():
			continue
		out.append(r)
	return out


## The game's own check that low walls never shut anything away. main.gd
## runs it on every floor of rooms, and the room painter on one room.
## `solid` is the grid (1 = solid, row by row, `size` tiles), changed in
## place: each block (a list of tiles: one low wall) is made solid in turn,
## and kept only if every goal can still be reached from `from`; one that
## would cut a goal off is left out. A path may step diagonally only past
## two open sides (as monsters walk). Returns the indices of the blocks kept.
static func cover_kept(size: Vector2i, solid: PackedByteArray, blocks: Array, from: Vector2i, goals: Array, astar: AStarGrid2D = null) -> Array:
	if astar == null:
		astar = AStarGrid2D.new()
		astar.region = Rect2i(Vector2i.ZERO, size)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.update()
		for y in size.y:
			for x in size.x:
				if solid[y * size.x + x] == 1:
					astar.set_point_solid(Vector2i(x, y), true)
	var kept: Array = []
	for i in blocks.size():
		var tiles: Array = blocks[i].filter(func(t): return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and solid[t.y * size.x + t.x] == 0)
		for t in tiles:
			solid[t.y * size.x + t.x] = 1
			astar.set_point_solid(t, true)
		var reachable := true
		for g in goals:
			if astar.get_id_path(from, g).is_empty():
				reachable = false
				break
		if reachable:
			kept.append(i)
		else:
			for t in tiles:
				solid[t.y * size.x + t.x] = 0
				astar.set_point_solid(t, false)
	return kept


## A room's size in tiles.
static func size_of(room: Dictionary) -> Vector2i:
	var g: Array = room["grid"]
	return Vector2i(String(g[0]).length(), g.size())


## The room's grid as rows, flipped left-right and/or top-bottom.
static func flipped(room: Dictionary, flip_x: bool, flip_y: bool) -> Array:
	var rows: Array = room["grid"].duplicate()
	if flip_y:
		rows.reverse()
	if flip_x:
		rows = rows.map(func(r: String) -> String:
			var out := ""
			for i in range(r.length() - 1, -1, -1):
				out += r[i]
			return out)
	return rows


## A carved room of `shape`, `size` tiles, as rows (the same legend as the
## hand-made rooms).
static func carve(shape: String, size: Vector2i) -> Array:
	var own: Script = load("res://scripts/floor_styles.gd").shape_module(shape)
	if own != null:
		return own.carve(shape, size)  # (a tower's own shape: floor_styles.gd SHAPE_MODULES)
	var w := size.x
	var h := size.y
	var g: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		g.append(row)
	var big := w >= 8 and h >= 7
	var cx := w / 2
	var cy := h / 2
	match shape:
		"ell":
			if big:
				var qw := w / 2 - 1
				var qh := h / 2 - 1
				var qx := 0 if randf() < 0.5 else w - qw
				var qy := 0 if randf() < 0.5 else h - qh
				for y in range(qy, qy + qh):
					for x in range(qx, qx + qw):
						if absi(x - cx) > 1 or absi(y - cy) > 1:
							g[y][x] = "X"
		"cross":
			if big:
				for o in [Vector2i(0, 0), Vector2i(w - 2, 0), Vector2i(0, h - 2), Vector2i(w - 2, h - 2)]:
					for y in 2:
						for x in 2:
							g[o.y + y][o.x + x] = "X"
		"round":
			var c := 2 if big else 1
			for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
				var dx := 1 if corner.x == 0 else -1
				var dy := 1 if corner.y == 0 else -1
				for k in c:
					g[corner.y][corner.x + dx * k] = "X"
					g[corner.y + dy * k][corner.x] = "X"
		"pillars":
			if w >= 9 and h >= 7:
				for o in [Vector2i(2, 2), Vector2i(w - 4, 2), Vector2i(2, h - 4), Vector2i(w - 4, h - 4)]:
					if absi(o.x - cx) < 2 and absi(o.y - cy) < 2:
						continue
					for y in 2:
						for x in 2:
							g[o.y + y][o.x + x] = "#"
		"ring":
			# One great block in the middle, a walk of at least two tiles around it.
			var bw := maxi(2, w - 6)
			var bh := maxi(2, h - 6)
			if w >= 8 and h >= 7:
				var x0 := (w - bw) / 2
				var y0 := (h - bh) / 2
				for y in range(y0, y0 + bh):
					for x in range(x0, x0 + bw):
						g[y][x] = "#"
		"circle":
			var rx := w * 0.5
			var ry := h * 0.5
			for y in h:
				for x in w:
					var dx := (x + 0.5 - rx) / rx
					var dy := (y + 0.5 - ry) / ry
					if dx * dx + dy * dy > 1.12:
						g[y][x] = "X"
		"gallery":
			if w >= 9 and h >= 6:
				for x in range(2, w - 2, 3):
					g[1][x] = "o"
					g[h - 2][x] = "o"
		"split":
			# A ledge across the long way, two tiles from the middle, with steps through it.
			if h >= 7 and w >= 8:
				var ly := cy - 1 if randf() < 0.5 else cy
				for x in range(1, w - 1):
					g[ly][x] = "#"
				var steps := [2, w - 4] if w >= 10 else [w / 2 - 1]
				if w >= 12:
					steps.append(w / 2 - 1)
				for sx in steps:
					for k in 2:
						if sx + k >= 1 and sx + k < w - 1:
							g[ly][sx + k] = "."
		"cover":
			# Low walls to hide behind, kept off the edges and apart.
			if w >= 8 and h >= 7:
				var spots := []
				for tries in 30:
					if spots.size() >= 3 + (w * h) / 60:
						break
					var horiz := randf() < 0.5
					var o := Vector2i(randi_range(2, w - 4), randi_range(2, h - 4))
					var near := false
					for s in spots:
						near = near or (absi(s.x - o.x) < 3 and absi(s.y - o.y) < 3)
					if near:
						continue
					spots.append(o)
					g[o.y][o.x] = "#"
					if horiz:
						g[o.y][o.x + 1] = "#"
					else:
						g[o.y + 1][o.x] = "#"
	var rows: Array = []
	for row in g:
		rows.append("".join(PackedStringArray(row)))
	return rows


## Gets a room's rows ready to build: random tiles are decided, and walls
## that touch the room's edge become part of its outline (rock).
static func prepare(rows: Array) -> Array:
	var g: Array = []
	for row in rows:
		var r: Array = []
		for ch in String(row):
			if ch == "?":
				var roll := randf()
				ch = "#" if roll < 0.25 else ("o" if roll < 0.4 else ".")
			r.append(ch)
		g.append(r)
	var h := g.size()
	var w: int = g[0].size()
	var todo: Array = []
	for y in h:
		for x in w:
			if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and g[y][x] == "#":
				todo.append(Vector2i(x, y))
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		if g[t.y][t.x] != "#":
			continue
		g[t.y][t.x] = "X"
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and g[n.y][n.x] == "#":
				todo.append(n)
	var out: Array = []
	for r in g:
		out.append("".join(PackedStringArray(r)))
	return out


## Whether a tile of the rows is open floor (out of bounds: no).
static func open_at(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= String(rows[0]).length():
		return false
	return OPEN.contains(String(rows[y])[x])


## Where a corridor two tiles wide may meet a side of the room: offsets along
## that side (0 north, 1 south, 2 west, 3 east) where both its tiles and the
## two tiles in from them are open floor, away from the corners.
static func door_slots(rows: Array, side: int) -> Array:
	var h := rows.size()
	var w := String(rows[0]).length()
	var n := w if side < 2 else h
	var out: Array = []
	for k in range(1, n - 2):
		var ok := true
		for i in 2:
			for depth in 2:
				var x: int
				var y: int
				match side:
					0:
						x = k + i
						y = depth
					1:
						x = k + i
						y = h - 1 - depth
					2:
						x = depth
						y = k + i
					_:
						x = w - 1 - depth
						y = k + i
				ok = ok and open_at(rows, x, y)
		if ok:
			out.append(k)
	return out


## The top-left tile of an n x n patch of open floor nearest the room's
## middle (for a spring, a cache or a camp), or (-1, -1) if there's none.
static func clear_spot(rows: Array, n := 3) -> Vector2i:
	var h := rows.size()
	var w := String(rows[0]).length()
	var best := Vector2i(-1, -1)
	var best_d := INF
	var mid := Vector2(w - n, h - n) * 0.5
	for y in range(1, h - n):
		for x in range(1, w - n):
			var ok := true
			for dy in n:
				for dx in n:
					ok = ok and String(rows[y + dy])[x + dx] == "."
			if ok:
				var d := Vector2(x, y).distance_squared_to(mid)
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


## Open floor tiles at least `margin` tiles in from the room's edge.
static func open_tiles(rows: Array, margin := 1) -> Array:
	var out: Array = []
	var h := rows.size()
	var w := String(rows[0]).length()
	for y in range(margin, h - margin):
		for x in range(margin, w - margin):
			if String(rows[y])[x] == "." or String(rows[y])[x] == "M":
				out.append(Vector2i(x, y))
	return out


## The parts of a room you can walk in (everything but its rock), as world
## rects: runs of tiles in each row, joined with identical runs below.
static func walk_rects(rows: Array, origin: Vector2, cell: float) -> Array:
	var runs: Array = []  # [x0, x1, y0, y1] in tiles, x1/y1 exclusive
	var open_runs := {}  # "x0,x1" -> index in runs, for the row above
	for y in rows.size():
		var row: String = rows[y]
		var now := {}
		var x := 0
		while x < row.length():
			if row[x] == "X":
				x += 1
				continue
			var x0 := x
			while x < row.length() and row[x] != "X":
				x += 1
			var key := "%d,%d" % [x0, x]
			if open_runs.has(key):
				var i: int = open_runs[key]
				runs[i][3] = y + 1
				now[key] = i
			else:
				runs.append([x0, x, y, y + 1])
				now[key] = runs.size() - 1
		open_runs = now
	var out: Array = []
	for r in runs:
		out.append(Rect2(origin + Vector2(r[0], r[2]) * cell, Vector2(r[1] - r[0], r[3] - r[2]) * cell))
	return out


## Turns a room's rows, placed with its top-left tile at `origin` (world
## px), into floor features: wall blocks, pillars, chasms, pools and monster
## spots. `tower` decides what C and ~ become. (Rock, X, is left out: it's
## simply not part of the room's walkable area.)
static func features(rows: Array, origin: Vector2, cell: float, tower: Dictionary) -> Dictionary:
	var out := {"blocks": [], "pillars": [], "chasms": [], "pools": [], "spots": [],
		"rails": [], "eyes": [], "plates": [], "pushers": [], "gates": [], "levers": [], "rewards": []}
	var chasms_here: bool = tower.get("chasms", false)
	var water_here: bool = tower.get("puddles", false)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "?":
				var roll := randf()
				ch = "#" if roll < 0.25 else ("o" if roll < 0.4 else ".")
			var tile := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			match ch:
				"#":
					out["blocks"].append(tile)
				"o":
					out["pillars"].append({"pos": tile.get_center(), "r": randf_range(16.0, 20.0)})
				"C":
					if chasms_here:
						out["chasms"].append(tile)
					else:
						out["blocks"].append(tile)
				"~":
					if water_here:
						out["pools"].append(tile)
				"M":
					out["spots"].append(tile.get_center())
				"=":
					out["rails"].append(tile)
				"E":
					out["eyes"].append(tile.get_center())
				"P":
					out["plates"].append(tile.get_center())
				"B":
					out["pushers"].append(tile.get_center())
				"G":
					out["gates"].append(tile)
				"L":
					out["levers"].append(tile.get_center())
				"$":
					out["rewards"].append(tile.get_center())
	out["blocks"] = merge_rows(out["blocks"])
	out["rails"] = merge_rows(out["rails"])
	out["chasms"] = merge_rows(out["chasms"])
	return out


## Joins tiles that sit side by side in a row into one rect each (fewer pieces).
static func merge_rows(tiles: Array) -> Array:
	var out: Array = []
	for t in tiles:
		var r: Rect2 = t
		if not out.is_empty():
			var last: Rect2 = out[-1]
			if is_equal_approx(last.position.y, r.position.y) and is_equal_approx(last.end.x, r.position.x) and is_equal_approx(last.size.y, r.size.y):
				out[-1] = Rect2(last.position, Vector2(last.size.x + r.size.x, last.size.y))
				continue
		out.append(r)
	return out
