extends RefCounted
## Room shapes that aren't boxes, for the towers whose floors are grown or
## broken rather than built (floor_styles.gd "shapes"; floors.gd asks here
## for any shape rooms.gd doesn't know). Carved as rows with rooms.gd's
## legend (". floor, X rock, # a low wall or rock spire, C a chasm"):
##   island   a ragged island of rock: the Firebird's rooms float over the abyss
##   atoll    an island ringed round a hole in its middle (C: a real chasm
##            in the Firebird's tower, so mind your footing)
##   cave     lobes grown into each other: the Thornwild's hollows
##   den      a round den with burrows off it
##   grotto   a cave with clumps of root to hide behind
## Every shape keeps a mouth in the middle of each side (MOUTH: at least
## three tiles wide, four on the north side, and two deep), so corridors can always meet it and
## the stair (at the top middle) always stands on floor.

const SHAPES := ["island", "atoll", "cave", "den", "grotto"]
## How wide each side's mouth is: at least `min` tiles, or this share of the side.
static var MOUTH := {"min": 3, "north": 4, "share": 0.24, "depth": 2}


static func is_shape(s: String) -> bool:
	return s in SHAPES


const Rooms := preload("res://scripts/rooms.gd")


## A room of `shape`, `size` tiles, as rows: carved again (a few times at
## most) until every side has a mouth and the stair's spot is floor.
static func carve(shape: String, size: Vector2i) -> Array:
	var rows: Array = []
	for attempt in 12:
		rows = _carve_once(shape if attempt < 10 else "island", size)
		if _sound(rows, size):
			return rows
	return rows


static func _sound(rows: Array, size: Vector2i) -> bool:
	for side in 4:
		if Rooms.door_slots(rows, side).is_empty():
			return false
	var mid := size.x / 2
	for y in 3:
		for x in range(mid - 2, mid + 2):
			if not Rooms.open_at(rows, x, y):
				return false
	return true


static func _carve_once(shape: String, size: Vector2i) -> Array:
	var w := size.x
	var h := size.y
	var g: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill("X")
		g.append(row)
	match shape:
		"island", "atoll":
			_blob(g, w, h, 0.09 if shape == "island" else 0.04, 0.8 if shape == "island" else 0.92)
		"cave", "grotto":
			_lobes(g, w, h, randi_range(3, 4))
		"den":
			_den(g, w, h)
		_:
			_blob(g, w, h, 0.05, 0.9)
	_mouths(g, w, h)
	_tidy(g, w, h)
	match shape:
		"island":
			_spires(g, w, h, randi_range(0, 2))
		"atoll":
			if mini(w, h) >= 9:
				_hole(g, w, h)
			else:
				_spires(g, w, h, 1)
		"grotto":
			_spires(g, w, h, randi_range(2, 3))
		"cave":
			_spires(g, w, h, randi_range(0, 1))
	# (the stair's spot, at the top middle, stays floor)
	for y in 3:
		for x in range(w / 2 - 2, w / 2 + 2):
			if g[y][x] == "#":
				g[y][x] = "."
	_connect(g, w, h)
	var rows: Array = []
	for row in g:
		rows.append("".join(PackedStringArray(row)))
	return rows


## A ragged round island: a wobbling radius around the middle.
static func _blob(g: Array, w: int, h: int, wobble: float, base: float) -> void:
	var ph := [randf() * TAU, randf() * TAU, randf() * TAU]
	var rx := w * 0.5
	var ry := h * 0.5
	for y in h:
		for x in w:
			var u := (x + 0.5 - rx) / rx
			var v := (y + 0.5 - ry) / ry
			var a := atan2(v, u)
			var r := base + wobble * (sin(a * 2.0 + ph[0]) + 0.8 * sin(a * 3.0 + ph[1]) + 0.6 * sin(a * 5.0 + ph[2]))
			if sqrt(u * u + v * v) <= r + 0.08:
				g[y][x] = "."


## Lobes grown into each other around a middle one.
static func _lobes(g: Array, w: int, h: int, n: int) -> void:
	var c := Vector2(w, h) * 0.5
	var lobes: Array = [[c, Vector2(w * 0.27, h * 0.27)]]
	for i in n:
		var a := randf() * TAU
		var at := c + Vector2(cos(a) * w * 0.22, sin(a) * h * 0.22)
		lobes.append([at, Vector2(randf_range(2.0, maxf(2.2, w * 0.3)), randf_range(2.0, maxf(2.2, h * 0.3)))])
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			for l in lobes:
				var d: Vector2 = (p - l[0]) / l[1]
				if d.length() <= 1.0:
					g[y][x] = "."
					break
	# The edge gnawed here and there.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if g[y][x] == "." and _open_n(g, w, h, x, y) <= 3 and randf() < 0.45:
				g[y][x] = "X"


## A round den with two or three burrows off it.
static func _den(g: Array, w: int, h: int) -> void:
	var c := Vector2(w, h) * 0.5
	var r := Vector2(w * 0.36, h * 0.36)
	var holes: Array = []
	for i in randi_range(2, 3):
		var a := randf() * TAU
		holes.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * 1.05)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			if ((p - c) / r).length() <= 1.0:
				g[y][x] = "."
				continue
			for hp in holes:
				if p.distance_to(hp) <= 1.7:
					g[y][x] = "."


## The mouths: the middle of each side open to the edge, MOUTH tiles wide
## and two deep at least, joined to the room's body.
static func _mouths(g: Array, w: int, h: int) -> void:
	for side in 4:
		var n := w if side < 2 else h
		var deep := h if side < 2 else w
		var pw := maxi(int(MOUTH["north"] if side == 0 else MOUTH["min"]), int(n * float(MOUTH["share"])))
		pw = mini(pw, n - 2)
		var k0 := (n - pw) / 2
		for k in range(k0, k0 + pw):
			for d in deep:
				var x: int
				var y: int
				match side:
					0:
						x = k
						y = d
					1:
						x = k
						y = h - 1 - d
					2:
						x = d
						y = k
					_:
						x = w - 1 - d
						y = k
				if d >= int(MOUTH["depth"]) and g[y][x] == ".":
					break
				g[y][x] = "."
				if d >= deep / 2:
					break


## Fills pinholes and trims lone spurs (a tile with one open side or none).
static func _tidy(g: Array, w: int, h: int) -> void:
	for pass_ in 2:
		for y in h:
			for x in w:
				if g[y][x] == "X" and _open_n(g, w, h, x, y) >= 3:
					g[y][x] = "."
				elif g[y][x] == "." and _open_n(g, w, h, x, y) <= 1 and not _edge_mouth(w, h, x, y):
					g[y][x] = "X"


## Rock spires or root clumps (low walls: cover), off the edges and the mouths.
static func _spires(g: Array, w: int, h: int, n: int) -> void:
	var placed: Array = []
	for tries in 40:
		if placed.size() >= n:
			break
		var t := Vector2i(randi_range(2, w - 3), randi_range(2, h - 3))
		if g[t.y][t.x] != "." or absi(t.x - w / 2) <= 1 and (t.y <= 3 or t.y >= h - 4) or absi(t.y - h / 2) <= 1 and (t.x <= 3 or t.x >= w - 4):
			continue
		var ok := true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q: Vector2i = t + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or g[q.y][q.x] != ".":
					ok = false
		for p in placed:
			ok = ok and Vector2(p).distance_to(Vector2(t)) >= 3.0
		if not ok:
			continue
		g[t.y][t.x] = "#"
		if randf() < 0.5:
			var d: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN][randi() % 2]
			if g[t.y + d.y][t.x + d.x] == ".":
				g[t.y + d.y][t.x + d.x] = "#"
		placed.append(t)


## A hole in the middle (C): the ring round it stays at least three tiles wide.
static func _hole(g: Array, w: int, h: int) -> void:
	var c := Vector2(w, h) * 0.5
	var r := Vector2(maxf(1.0, w * 0.5 - 3.6), maxf(1.0, h * 0.5 - 3.6))
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			if ((p - c) / r).length() <= 1.0 and g[y][x] == ".":
				g[y][x] = "C"


## Keeps only the floor joined to the middle (and to the mouths).
static func _connect(g: Array, w: int, h: int) -> void:
	var start := Vector2i(w / 2, 1)
	if g[start.y][start.x] != ".":
		for y in h:
			for x in w:
				if g[y][x] == ".":
					start = Vector2i(x, y)
					break
			if g[start.y][start.x] == ".":
				break
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var t: Vector2i = q.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			if g[n.y][n.x] in [".", "C", "#"]:
				seen[n] = true
				q.append(n)
	for y in h:
		for x in w:
			if g[y][x] != "X" and not seen.has(Vector2i(x, y)):
				g[y][x] = "X"


static func _open_n(g: Array, w: int, h: int, x: int, y: int) -> int:
	var n := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = Vector2i(x, y) + d
		if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and g[q.y][q.x] == ".":
			n += 1
	return n


static func _edge_mouth(w: int, h: int, x: int, y: int) -> bool:
	return (absi(x - w / 2) <= 2 and (y == 0 or y == h - 1)) or (absi(y - h / 2) <= 2 and (x == 0 or x == w - 1))
