extends RefCounted
## Holes in the floor you can fall through (chasms, the Gryphon's drops):
## a cut in the floor, never a black pit. Seen from above and a little to the
## south, like the rest of the tower:
##   the floor below   at the bottom, its flagstones smaller and dimmer than
##                     the floor you stand on and sitting a little lower on
##                     screen (the depth), under a faint haze of the tower's
##                     own colour (warm for the Firebird, sky for the Gryphon)
##   the shaft         the cut's far wall drops from the north edge down to
##                     the floor below (courses of stone, darkening as it
##                     goes down); thinner side walls; shade at the foot
##   the rim           a lit lip of cut stone round the hole on the floor
##                     side, with a dark seam outside it and the odd crack
## A doorway is a gap in a wall at floor level; a hole is cut into the floor,
## with a rim and depth. room.gd draws every chasm this way, once, into its
## batched feature layer; the Gryphon (towers/gryphon_floor.gd) draws its own
## floor below with parallax and then the same shaft and rim. The colours
## are palette.gd's HOLE_* tokens; the sizes are LOOK.

const Palette := preload("res://scripts/palette.gd")

const TILE := 40.0
## What's beside a hole tile, on each side.
enum { HOLE, FLOOR, WALL, OPEN }

## The look's numbers (px): shaft, how tall the far wall shows; side, the
## side walls' width; stone, the floor below's flagstone size; shift, how far
## the floor below sits from the floor you stand on (its depth on screen);
## shade, the bands of shade round the foot of the shaft.
static var LOOK := {"shaft": 21.0, "side": 5.0, "stone": 25.0, "shift": Vector2(7.0, 13.0), "shade": 4}


## Cheap stable per-tile random number in [0, 1) (as room.gd's).
static func hash01(x: int, y: int, salt := 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


## The tiles (Vector2i from `origin`) the holes cover.
static func tiles_of(rects: Array, origin: Vector2, cell := TILE) -> Dictionary:
	var out := {}
	for rr in rects:
		var r: Rect2 = rr
		var a := Vector2i(((r.position - origin) / cell).round())
		var b := Vector2i(((r.end - origin) / cell).round())
		for y in range(a.y, maxi(b.y, a.y + 1)):
			for x in range(a.x, maxi(b.x, a.x + 1)):
				out[Vector2i(x, y)] = true
	return out


## The tower's haze over the floor below.
static func haze(tower: String) -> Color:
	return Palette.HOLE_HAZE.get(tower, Palette.HOLE_HAZE["other"])


## The floor below, seen through hole tile `r`: smaller flagstones, dimmer,
## shifted by the depth (laid from `origin`, so neighbouring hole tiles join
## up), and the tower's haze over it. Drawn once (room.gd's feature layer).
## `tint`: the tower's stone colour (room.gd's layer is tinted already).
static func draw_floor_below(c, r: Rect2, origin: Vector2, tower: String, tint := Color.WHITE) -> void:
	var s: float = LOOK["stone"]
	var o: Vector2 = origin + LOOK["shift"]
	c.draw_rect(r, Palette.HOLE_GAP * tint)
	var i0 := int(floor((r.position.x - o.x) / s))
	var i1 := int(ceil((r.end.x - o.x) / s))
	var j0 := int(floor((r.position.y - o.y) / s))
	var j1 := int(ceil((r.end.y - o.y) / s))
	for j in range(j0, j1):
		for i in range(i0, i1):
			var stone := Rect2(o + Vector2(i, j) * s, Vector2(s, s)).grow(-1.0)
			var cut := stone.intersection(r)
			if cut.size.x <= 0.0 or cut.size.y <= 0.0:
				continue
			var col: Color = Palette.HOLE_FLOOR.lerp(Palette.HOLE_FLOOR_LIGHT, hash01(i, j, 61)) * tint
			c.draw_rect(cut, col)
			# Each stone's lit top edge (the floor below has its own light).
			var top := Rect2(stone.position, Vector2(stone.size.x, 1.5)).intersection(r)
			if top.size.x > 0.0 and top.size.y > 0.0:
				c.draw_rect(top, col.lightened(0.12))
	var hz := haze(tower)
	if hz.a > 0.0:
		c.draw_rect(r, hz)
	# A speck on the floor below now and then: an ember in the Firebird's tower, grit elsewhere.
	var tx := int(floor(r.position.x / TILE))
	var ty := int(floor(r.position.y / TILE))
	if hash01(tx, ty, 62) < 0.45:
		var at := r.position + Vector2(0.15 + 0.7 * hash01(tx, ty, 63), 0.5 + 0.4 * hash01(tx, ty, 64)) * r.size
		var speck := Color(1.0, 0.6, 0.3, 0.6) if tower == "firebird" else Color((Palette.HOLE_FLOOR_LIGHT * tint).lightened(0.3), 0.6)
		c.draw_circle(at, 1.3, speck)


## The cut round hole tile `r`: the shaft walls going down where the side
## isn't more hole (or open air), shade at their foot, and the lit rim on
## the floor side. `n`, `s`, `w`, `e`: what's beside it (HOLE, FLOOR, WALL
## or OPEN); `t`: the tile (for its cracks). Where it opens into the air
## (OPEN) the floor below fades into the dark beyond.
static func draw_cut(c, r: Rect2, n: int, s: int, w: int, e: int, t: Vector2i, tint := Color.WHITE) -> void:
	var sh: float = LOOK["shaft"]
	var sw: float = LOOK["side"]
	var top: Color = Palette.HOLE_SHAFT * tint
	var deep: Color = Palette.HOLE_SHAFT_DEEP * tint
	var y0 := r.position.y + (sh if _walled(n) else 0.0)
	var bands := int(LOOK["shade"])
	# Shade at the foot of the walls: the floor below darkens toward them;
	# into open air, it fades into the dark.
	for k in bands:
		var f := 1.0 - float(k) / float(bands)
		var d := 4.0 * k
		var col := Color(0, 0, 0, 0.28 * f)
		var air := Color(Palette.VOID * tint, 0.3 * f)
		if _walled(n):
			c.draw_rect(Rect2(r.position.x, y0 + d, r.size.x, 4.0), col)
		elif n == OPEN:
			c.draw_rect(Rect2(r.position.x, r.position.y + d, r.size.x, 4.0), air)
		if _walled(w):
			c.draw_rect(Rect2(r.position.x + sw + d, y0, 4.0, r.end.y - y0), col)
		elif w == OPEN:
			c.draw_rect(Rect2(r.position.x + d, r.position.y, 4.0, r.size.y), air)
		if _walled(e):
			c.draw_rect(Rect2(r.end.x - sw - d - 4.0, y0, 4.0, r.end.y - y0), col)
		elif e == OPEN:
			c.draw_rect(Rect2(r.end.x - d - 4.0, r.position.y, 4.0, r.size.y), air)
		if s == OPEN:
			c.draw_rect(Rect2(r.position.x, r.end.y - d - 4.0, r.size.x, 4.0), air)
	# The side walls: the west one in shade, the east one catching the light.
	if _walled(w):
		c.draw_rect(Rect2(r.position.x, r.position.y, sw, r.size.y), deep.lerp(top, 0.25))
		c.draw_rect(Rect2(r.position.x + sw - 1.0, r.position.y, 1.0, r.size.y), Color(0, 0, 0, 0.35))
	if _walled(e):
		c.draw_rect(Rect2(r.end.x - sw, r.position.y, sw, r.size.y), deep.lerp(top, 0.6))
		c.draw_rect(Rect2(r.end.x - sw, r.position.y, 1.0, r.size.y), Color(top.lightened(0.15), 0.6))
	# The far wall, dropping from the north edge: courses of stone, darker as they go down.
	if _walled(n):
		var steps := 5
		for k in steps:
			var f := float(k) / float(steps - 1)
			c.draw_rect(Rect2(r.position.x, r.position.y + sh * k / steps, r.size.x, sh / steps + 0.5), top.lerp(deep, f))
		var course := sh / 3.0
		var joint := Color(deep.darkened(0.3), 0.75)
		for row in 3:
			if row > 0:
				c.draw_rect(Rect2(r.position.x, r.position.y + course * row, r.size.x, 1.0), joint)
			var x := r.position.x + 5.0 + 12.0 * hash01(t.x, t.y + row, 65)
			while x < r.end.x - 1.0:
				c.draw_rect(Rect2(x, r.position.y + course * row + 1.0, 1.0, course - 1.0), joint)
				x += 16.0
		c.draw_rect(Rect2(r.position.x, r.position.y + sh - 1.5, r.size.x, 1.5), Color(0, 0, 0, 0.55))
	# The near lip: its underside shows as a dark edge over the floor below.
	if _walled(s):
		c.draw_rect(Rect2(r.position.x, r.end.y - 2.5, r.size.x, 2.5), Color(deep, 0.95))
	# The rim: a lit lip of cut stone on the floor side, a dark seam outside it.
	var rim: Color = Palette.HOLE_RIM * tint
	var seam := Color(Palette.FLOOR_GAP * tint, 0.9)
	if n == FLOOR:
		c.draw_rect(Rect2(r.position.x, r.position.y - 4.5, r.size.x, 1.5), seam)
		c.draw_rect(Rect2(r.position.x, r.position.y - 3.0, r.size.x, 3.0), rim)
	if s == FLOOR:
		c.draw_rect(Rect2(r.position.x, r.end.y + 2.0, r.size.x, 1.5), seam)
		c.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 2.0), Color(rim, 0.8))
	if w == FLOOR:
		c.draw_rect(Rect2(r.position.x - 3.5, r.position.y, 1.5, r.size.y), seam)
		c.draw_rect(Rect2(r.position.x - 2.0, r.position.y, 2.0, r.size.y), Color(rim, 0.85))
	if e == FLOOR:
		c.draw_rect(Rect2(r.end.x + 2.0, r.position.y, 1.5, r.size.y), seam)
		c.draw_rect(Rect2(r.end.x, r.position.y, 2.0, r.size.y), Color(rim, 0.65))
	# The odd crack running from the cut into the floor.
	var sides := [n, s, w, e]
	for side in 4:
		if sides[side] != FLOOR or hash01(t.x, t.y, 70 + side) > 0.3:
			continue
		var u := 0.2 + 0.6 * hash01(t.x, t.y, 74 + side)
		var len := 6.0 + 7.0 * hash01(t.x, t.y, 78 + side)
		var at: Vector2
		var out: Vector2
		match side:
			0:
				at = Vector2(r.position.x + r.size.x * u, r.position.y - 4.0)
				out = Vector2.UP
			1:
				at = Vector2(r.position.x + r.size.x * u, r.end.y + 3.0)
				out = Vector2.DOWN
			2:
				at = Vector2(r.position.x - 3.5, r.position.y + r.size.y * u)
				out = Vector2.LEFT
			_:
				at = Vector2(r.end.x + 3.5, r.position.y + r.size.y * u)
				out = Vector2.RIGHT
		var bend := out.orthogonal() * (hash01(t.x, t.y, 82 + side) - 0.5) * 8.0
		var mid := at + out * len * 0.5 + bend
		var col := Color(Palette.FLOOR_GAP * tint, 0.9)
		c.draw_line(at, mid, col, 1.2)
		c.draw_line(mid, at + out * len + bend * 0.3, col, 1.0)


static func _walled(k: int) -> bool:
	return k == FLOOR or k == WALL
