extends RefCounted
## Hand-made rooms ("prefabs"), drawn as text grids: one character per
## 40 px tile. floors.gd picks one for each room of a floor (flipping it at
## random so it doesn't repeat exactly) and joins the rooms with corridors.
## Edit or add rooms here: each row of a grid must be the same length, and
## the corridors run in along the middle row and column, so keep the middle
## fairly open (anything in a corridor's way is cleared for it).
##
## Legend:
##   .  floor
##   #  wall (a solid tile: blocks movement, sight and shots)
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
		"...............",
		".o...........o.",
		"...............",
		"...o.......o...",
		"..M.........M..",
		"...............",
		"...............",
		"...o.......o...",
		"...............",
		".o...........o.",
		"...............",
	]},
	{"id": "four_blocks", "role": "combat", "from": 2, "flip": true, "grid": [
		"...............",
		".##.........##.",
		".##..M...M..##.",
		"...............",
		"....##...##....",
		"...............",
		"...............",
		"...............",
		"....##...##....",
		"...............",
		".##.........##.",
		".##.........##.",
		"...............",
	]},
	{"id": "l_room", "role": "combat", "from": 2, "flip": true, "grid": [
		"..........#####",
		"..........#####",
		"...M......#####",
		"...o......#####",
		"...............",
		"...............",
		"...............",
		"...........M...",
		"...............",
		".....##........",
		".....##.....o..",
		"...............",
		"...............",
	]},
	{"id": "pit_quarters", "role": "combat", "from": 2, "flip": true, "grid": [
		"...............",
		".CCC.......CCC.",
		".CCC...M...CCC.",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		".CCC...M...CCC.",
		".CCC.......CCC.",
		"...............",
	]},
	{"id": "balcony", "role": "combat", "from": 2, "flip": true, "grid": [
		"...............",
		"..M.........M..",
		"...............",
		".#####...#####.",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"....o.....o....",
		"...............",
	]},
	{"id": "colonnade", "role": "combat", "from": 2, "flip": true, "grid": [
		"...............",
		".o.o.......o.o.",
		"...............",
		".o.o...M...o.o.",
		"...............",
		"...............",
		"...............",
		".o.o...M...o.o.",
		"...............",
		".o.o.......o.o.",
		"...............",
	]},
	{"id": "alcove_hall", "role": "combat", "from": 2, "flip": true, "grid": [
		"###...###...###",
		"#M...........M#",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"#M...........M#",
		"###...###...###",
	]},
	{"id": "split_room", "role": "combat", "from": 3, "flip": true, "grid": [
		"....#..........",
		"....#....M.....",
		"....#..........",
		"....#....o.....",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"....#....o.....",
		"....#..........",
		"....#....M.....",
		"....#..........",
	]},
	{"id": "flooded_court", "role": "combat", "from": 2, "flip": true, "grid": [
		"...............",
		".~~~.......~~~.",
		".~~~...o...~~~.",
		".~~~.......~~~.",
		"...............",
		"..M.........M..",
		"...............",
		".~~~.......~~~.",
		".~~~...o...~~~.",
		".~~~.......~~~.",
		"...............",
	]},
	{"id": "rubble_field", "role": "combat", "from": 3, "flip": true, "grid": [
		"...............",
		".?..?.....?..?.",
		"...............",
		"..?..M...M..?..",
		"...............",
		"...............",
		"...............",
		"..?.........?..",
		"...............",
		".?..?.....?..?.",
		"...............",
	]},
	# --- puzzle rooms: solving one lifts the ward on the stair ------------------
	{"id": "eye_corner", "role": "puzzle", "puzzle": "eyes", "tier": 1, "from": 2, "flip": true, "grid": [
		"#####..........",
		"#.E.#..........",
		"=...=..........",
		"=====..........",
		"...............",
		"...............",
		"...............",
		"..........###..",
		"..........#$#..",
		"..........#G#..",
		"...............",
	]},
	{"id": "eye_pair", "role": "puzzle", "puzzle": "eyes", "tier": 2, "from": 4, "flip": true, "grid": [
		"#####.....#####",
		"#.E.#.....#.E.#",
		"=...=.....=...=",
		"=====.....=====",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		".###...........",
		".#$G...........",
		".###...........",
		"...............",
	]},
	{"id": "plate_block", "role": "puzzle", "puzzle": "plates", "tier": 1, "from": 2, "flip": true, "grid": [
		"...............",
		"..L............",
		"...............",
		"..B............",
		"...............",
		"...............",
		"...............",
		"..P.......###..",
		"..........#$#..",
		"..........#G#..",
		"...............",
	]},
	{"id": "plate_pair", "role": "puzzle", "puzzle": "plates", "tier": 2, "from": 4, "flip": true, "grid": [
		"...............",
		"..B.........M..",
		"...............",
		"...............",
		"..P.........P..",
		"...............",
		"...............",
		"...............",
		"..L............",
		"...........###.",
		"...........#$#.",
		"...........#G#.",
		"...............",
	]},
	{"id": "crossroads", "role": "combat", "from": 3, "flip": false, "grid": [
		"####.......####",
		"####.......####",
		"###....M....###",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"###....M....###",
		"####.......####",
		"####.......####",
	]},
]

const CHARS := ".#oC~M?=EPBGL$"


## The rooms for a role that can appear on a floor.
static func for_role(role: String, floor_num: int) -> Array:
	return ROOMS.filter(func(r): return r["role"] == role and int(r["from"]) <= floor_num)


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


## Turns a room's rows, placed with its top-left tile at `origin` (world
## px), into floor features: wall blocks, pillars, chasms, pools and monster
## spots. `tower` decides what C and ~ become.
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
