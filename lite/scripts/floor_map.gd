extends RefCounted
## A floor's layout: a map of 40 px tiles (30 across, 16 down) read from the
## text maps in LAYOUTS, so new rooms can be made without code. Walls block
## bodies, throws and sight; monsters find their way round them (a flow field
## from the climber). The map also holds the floor's easy puzzle, portals,
## secret and chest:
##   .  floor            #  wall                O  pillar
##   S  where you start  E  the stair (shows once the room is clear)
##   G  gate: shut until the puzzle is solved (stepping on every plate o,
##      hitting the lever L, or lighting every brazier F)
##   P p / Q q  portal pairs: step in one, come out of the other
##   X  a cracked wall: hit it and a secret portal opens to a treasure room
##   C  a chest   R  the treasure room's way back
## A layout is used on floors "from" to "to" (0 is floor 1; 5 is the beast's).

const TILE := 40.0
const COLS := 30
const ROWS := 16
const SOLID := "#OGXLFC"  # (G, X and C stop being solid once opened)

static var LAYOUTS := {
	"hall": {"from": 0, "to": 2, "rows": [
		"X.............................",
		"..............................",
		"..............E...............",
		"..............................",
		".....##..............##.......",
		".....##..............##.......",
		"..............................",
		"..........O........O..........",
		"..............................",
		"..............................",
		".....##..............##.......",
		".....##..............##.......",
		"..............................",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"crossroads": {"from": 0, "to": 3, "rows": [
		".............................X",
		".............E................",
		"..............................",
		"......####........####........",
		"......#..............#........",
		"......#..............#........",
		"..............................",
		".............O..O.............",
		"..............................",
		"......#..............#........",
		"......#..............#........",
		"......####........####........",
		"..............................",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"plates": {"from": 1, "to": 4, "rows": [
		"X############.....############",
		"#...........#..E..#..........#",
		"#...o.......#.....#.......o..#",
		"#...........##GG###..........#",
		"#............................#",
		"#.......####......####.......#",
		"#............................#",
		"#............O..O............#",
		"#............................#",
		"#.......####......####.......#",
		"#............................#",
		"#............................#",
		"#.......o..............o.....#",
		"#............................#",
		"#.............S..............#",
		"#............................#",
	]},
	"lever": {"from": 1, "to": 4, "rows": [
		".............................X",
		".........#####GG#####.........",
		".........#....E.....#.........",
		".........#..........#.........",
		".........############.........",
		"..............................",
		"...L..........................",
		"..............................",
		".....###............###.......",
		".....#................#.......",
		".....#.......O........#.......",
		".....#................#.......",
		".....###............###.......",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"fires": {"from": 2, "to": 4, "rows": [
		"..............................",
		"..F.......#######.........F...",
		"..........#..E..#.............",
		"..........#.....#.............",
		"..........###GG##.............",
		"..............................",
		"....####..............####....",
		"..............................",
		"..............O.O.............",
		"..............................",
		"....####..............####....",
		"..............................",
		"..F...................F.......",
		"..............................",
		"..............S...............",
		"X.............................",
	]},
	"portals": {"from": 1, "to": 4, "rows": [
		"..............................",
		"......E.......................",
		"..............................",
		"..........P...................",
		"##################.###########",
		"..............................",
		"..............................",
		".......O.........O............",
		"..............................",
		"##############.###############",
		"..............................",
		"..............................",
		".........................p....",
		"..............................",
		".......S......................",
		"..............................",
	]},
	"islands": {"from": 2, "to": 4, "rows": [
		"..............................",
		"..q..........E................",
		"..............................",
		"..............................",
		"##############################",
		"..............................",
		"..........Q.......P...........",
		"..............................",
		".......O.............O........",
		"##############################",
		"..............................",
		".............p................",
		"..............................",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"maze": {"from": 3, "to": 4, "rows": [
		"X.............................",
		"...........E..................",
		"..............................",
		"..######...######...######....",
		"..#....................#......",
		"..#..####.....####.....#......",
		".......#.......#..............",
		".......#...O...#....####......",
		".......#.......#.......#......",
		"..####...........####..#......",
		".....#.................#......",
		".....#####...#######...#......",
		"..............................",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"arena": {"from": 5, "to": 5, "rows": [
		"..............................",
		"..............................",
		"..............................",
		"......O................O......",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"......O................O......",
		"..............................",
		"..............................",
		"..............................",
		"..............S...............",
		"..............................",
	]},
	"treasure": {"from": -1, "to": -1, "rows": [
		"##############################",
		"##############################",
		"##############################",
		"##############################",
		"##########.........###########",
		"##########.........###########",
		"##########....C....###########",
		"##########.........###########",
		"##########.........###########",
		"##########....R....###########",
		"##########.........###########",
		"##############################",
		"##############################",
		"##############################",
		"##############################",
		"##############################",
	]},
}

var name := ""
var origin := Vector2(40, 40)  # the top-left corner of the floor, in the room
var grid: Array = []  # rows of single-character strings
var start := Vector2.ZERO
var stair := Vector2.ZERO
var gate_cells: Array = []
var gate_open := true
var puzzle := ""  # "plates", "lever", "fires" or ""
var plates: Array = []  # {cell, pos, down}
var levers: Array = []  # {cell, pos, on}
var fires: Array = []  # {cell, pos, lit}
var portals: Array = []  # {cell, pos, to (index of its pair)}
var cracks: Array = []  # {cell, pos, broken}
var chests: Array = []  # {cell, pos, open}
var back_portal := Vector2.ZERO  # R (the treasure room's way out)
var pillars: Array = []  # positions


## The layouts that suit floor `i` (0-based; the beast's floor is beast_i).
static func names_for(i: int) -> Array:
	var out: Array = []
	for n in LAYOUTS:
		var l: Dictionary = LAYOUTS[n]
		if int(l["from"]) <= i and i <= int(l["to"]):
			out.append(n)
	return out


func load_layout(layout: String, secret := true) -> void:
	name = layout
	grid.clear()
	for row in LAYOUTS[layout]["rows"]:
		var r: Array = []
		for ch in String(row):
			r.append(ch)
		grid.append(r)
	gate_cells.clear()
	plates.clear()
	levers.clear()
	fires.clear()
	portals.clear()
	cracks.clear()
	chests.clear()
	pillars.clear()
	var pairs := {}
	for y in ROWS:
		for x in COLS:
			var ch: String = grid[y][x]
			var cell := Vector2i(x, y)
			var at := center(cell)
			match ch:
				"S":
					start = at
					grid[y][x] = "."
				"E":
					stair = at
					grid[y][x] = "."
				"G":
					gate_cells.append(cell)
				"o":
					plates.append({"cell": cell, "pos": at, "down": false})
				"L":
					levers.append({"cell": cell, "pos": at, "on": false})
				"F":
					fires.append({"cell": cell, "pos": at, "lit": false})
				"X":
					if secret:
						cracks.append({"cell": cell, "pos": at, "broken": false})
					else:
						grid[y][x] = "#"
				"C":
					chests.append({"cell": cell, "pos": at, "open": false})
				"R":
					back_portal = at
					grid[y][x] = "."
				"O":
					pillars.append(at)
				"P", "p", "Q", "q":
					var key := ch.to_upper()
					var i := portals.size()
					portals.append({"cell": cell, "pos": at, "to": -1, "key": key})
					if pairs.has(key):
						portals[i]["to"] = pairs[key]
						portals[pairs[key]]["to"] = i
					else:
						pairs[key] = i
	puzzle = "plates" if not plates.is_empty() else ("lever" if not levers.is_empty() else ("fires" if not fires.is_empty() else ""))
	gate_open = gate_cells.is_empty()


func center(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func cell_of(p: Vector2) -> Vector2i:
	var q := (p - origin) / TILE
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


## Is this tile solid (bodies can't stand in it, throws stop at it)?
func solid(cell: Vector2i) -> bool:
	if not inside(cell):
		return true
	var ch: String = grid[cell.y][cell.x]
	if not SOLID.contains(ch):
		return false
	match ch:
		"G":
			return not gate_open
		"X":
			for c in cracks:
				if c["cell"] == cell:
					return not c["broken"]
			return true
		"C":
			for c in chests:
				if c["cell"] == cell:
					return not c["open"]
	return true


func blocked(p: Vector2) -> bool:
	return solid(cell_of(p))


## Pushes a round body (radius r) out of solid tiles.
func collide(p: Vector2, r: float) -> Vector2:
	for pass_i in 2:
		var c0 := cell_of(p - Vector2(r, r))
		var c1 := cell_of(p + Vector2(r, r))
		for y in range(c0.y, c1.y + 1):
			for x in range(c0.x, c1.x + 1):
				var cell := Vector2i(x, y)
				if not solid(cell):
					continue
				var rect := Rect2(origin + Vector2(cell) * TILE, Vector2(TILE, TILE))
				var near := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
				var d := p - near
				var dist := d.length()
				if dist < r:
					if dist > 0.01:
						p = near + d / dist * r
					else:
						# (the centre is inside the tile: out the nearest side)
						var gaps := [p.x - rect.position.x, rect.end.x - p.x, p.y - rect.position.y, rect.end.y - p.y]
						var k := gaps.find(gaps.min())
						p += [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)][k] * (float(gaps[k]) + r)
	return p


## Can one see from a to b (no solid tile between)?
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / (TILE * 0.4)) + 1
	for i in range(1, n):
		if blocked(a.lerp(b, float(i) / n)):
			return false
	return true


## Steps from `from` over open tiles (and through portals, if `portals`):
## cell -> how many steps away.
func distances(from: Vector2, use_portals := false) -> Dictionary:
	var start_cell := cell_of(from)
	var dist := {start_cell: 0}
	var queue: Array = [start_cell]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var nexts: Array = [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]
		if use_portals:
			for pt in portals:
				if pt["cell"] == c and int(pt["to"]) >= 0:
					nexts.append(portals[int(pt["to"])]["cell"])
		for n in nexts:
			if dist.has(n) or solid(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


## Where a monster at `p` should head to come closer, following `field`
## (distances from the climber): the middle of the neighbouring tile nearest.
func next_step(p: Vector2, field: Dictionary) -> Vector2:
	var c := cell_of(p)
	var best := c
	var bd: int = field.get(c, 99999)
	for n in [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
		if field.has(n) and int(field[n]) < bd:
			bd = field[n]
			best = n
	return center(best)


## Open tiles (with their middles) a monster can stand on, reachable from the
## start, at least `away` px from it.
func spawn_spots(away: float) -> Array:
	var out: Array = []
	var dist := distances(start, true)
	for c in dist:
		var at := center(c)
		if at.distance_to(start) >= away and grid[c.y][c.x] == ".":
			out.append(at)
	return out


## The puzzle's pieces not yet done (where the guide should point).
func puzzle_left() -> Array:
	var out: Array = []
	match puzzle:
		"plates":
			for p in plates:
				if not p["down"]:
					out.append(p["pos"])
		"lever":
			for l in levers:
				if not l["on"]:
					out.append(l["pos"])
		"fires":
			for f in fires:
				if not f["lit"]:
					out.append(f["pos"])
	return out


## Checks the puzzle; opens the gate once it's solved. True when it opens now.
func check_puzzle() -> bool:
	if gate_open or puzzle == "":
		return false
	if puzzle_left().is_empty():
		gate_open = true
		return true
	return false
