extends RefCounted
## A room, drawn like the full game's (its room.gd): square flagstones with
## some merged into bigger slabs, bevelled edges, moss and cracks, the north
## wall's brick face with its shadow on the floor, stone rims for the other
## walls, round pillars, torches on the wall and stone steps for the stair.
## Each tower tints its stone (Palette.TOWER_TINT). A little brighter than
## the full game (which is dark between its torches) so a child sees well.

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

const TILE := 40.0
const FACE := 34.0  # the north wall's brick face
## How much lighter than the full game's stone (0: the same).
const BRIGHTER := 0.2


static func _hash(x: int, y: int, salt := 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


static func _tint(col: Color, tower: String) -> Color:
	var t: Color = Palette.TOWER_TINT.get(tower, Color.WHITE)
	return Color(col.r * t.r, col.g * t.g, col.b * t.b, col.a).lightened(BRIGHTER)


## The floor and walls of a room. `room` is the floor (inside the walls),
## `wall` how thick the walls are.
static func draw(c: CanvasItem, room: Rect2, wall: float, tower: String) -> void:
	var b := Draw.Batch.new()
	var floor_a := _tint(Palette.FLOOR, tower)
	var floor_b := _tint(Palette.FLOOR_LIGHT, tower)
	var gap := _tint(Palette.FLOOR_GAP, tower)
	var moss := Palette.MOSS
	b.rect(room.grow(wall + 400.0), Palette.VOID)
	# Floor: square flagstones, some merged into bigger slabs.
	var cols := int(ceil(room.size.x / TILE))
	var rows := int(ceil(room.size.y / TILE))
	var used := {}
	for gy in rows:
		for gx in cols:
			if used.has(Vector2i(gx, gy)):
				continue
			var size := Vector2i(1, 1)
			var roll := _hash(gx, gy, 2)
			if roll < 0.14:
				size = Vector2i(2, 2)
			elif roll < 0.3:
				size = Vector2i(2, 1)
			elif roll < 0.42:
				size = Vector2i(1, 2)
			for dy in size.y:
				for dx in size.x:
					if used.has(Vector2i(gx + dx, gy + dy)) or gx + dx >= cols or gy + dy >= rows:
						size = Vector2i(1, 1)
			for dy in size.y:
				for dx in size.x:
					used[Vector2i(gx + dx, gy + dy)] = true
			var r := Rect2(room.position + Vector2(gx, gy) * TILE, Vector2(size) * TILE).intersection(room)
			var base: Color = floor_a.lerp(floor_b, _hash(gx, gy))
			var inner := r.grow(-1.5)
			b.rect(r, gap)
			b.rect(inner, base)
			# Bevel: lit top-left edges, shadowed bottom-right edges.
			b.line(inner.position, Vector2(inner.end.x, inner.position.y), base.lightened(0.08), 1.5)
			b.line(inner.position, Vector2(inner.position.x, inner.end.y), base.lightened(0.04), 1.5)
			b.line(Vector2(inner.position.x, inner.end.y), inner.end, base.darkened(0.3), 1.5)
			b.line(Vector2(inner.end.x, inner.position.y), inner.end, base.darkened(0.2), 1.5)
			if _hash(gx, gy, 3) < 0.1:
				var corner := inner.position + inner.size * Vector2(round(_hash(gx, gy, 4)), round(_hash(gx, gy, 5)))
				for k in 6:
					var mp := corner + Vector2(_hash(gx, gy, 10 + k) - 0.5, _hash(gx, gy, 20 + k) - 0.5) * 22.0
					b.circle(mp, 2.0 + 4.0 * _hash(gx, gy, 30 + k), Color(moss, 0.3))
			if _hash(gx, gy, 7) < 0.12:
				var p0 := inner.position + inner.size * Vector2(_hash(gx, gy, 8), 0.1)
				var p1 := inner.position + inner.size * Vector2(0.5, 0.55)
				var p2 := inner.position + inner.size * Vector2(_hash(gx, gy, 9), 0.92)
				b.polyline(PackedVector2Array([p0, p1, p2]), base.darkened(0.4), 1.0)
	# A soft darkening toward the walls, so the floor feels enclosed.
	for i in 6:
		var g := room.grow(-i * 7.0)
		var col := Color(0, 0, 0, 0.06 * (1.0 - float(i) / 6.0))
		b.rect(Rect2(g.position, Vector2(g.size.x, 7)), col)
		b.rect(Rect2(g.position.x, g.end.y - 7, g.size.x, 7), col)
		b.rect(Rect2(g.position.x, g.position.y + 7, 7, g.size.y - 14), col)
		b.rect(Rect2(g.end.x - 7, g.position.y + 7, 7, g.size.y - 14), col)
	_walls(b, room, wall, tower)
	b.flush(c)


static func _walls(b, r: Rect2, wall: float, tower: String) -> void:
	var rim := _tint(Palette.WALL_TOP, tower)
	var edge := _tint(Palette.WALL_EDGE, tower)
	var face_col := _tint(Palette.WALL_FACE, tower)
	# Side and bottom walls: seen from above as thick stone rims.
	b.rect(Rect2(r.position.x - wall, r.position.y, wall, r.size.y + wall), rim)
	b.rect(Rect2(r.end.x, r.position.y, wall, r.size.y + wall), rim)
	b.rect(Rect2(r.position.x - wall, r.end.y, r.size.x + wall * 2.0, wall), rim)
	b.line(r.position, Vector2(r.position.x, r.end.y), edge, 2.0)
	b.line(Vector2(r.end.x, r.position.y), r.end, edge, 2.0)
	b.line(Vector2(r.position.x, r.end.y), r.end, edge, 2.0)
	# North wall: its brick front face, which gives the room depth.
	var face := Rect2(r.position.x - wall, r.position.y - FACE, r.size.x + wall * 2.0, FACE)
	b.rect(Rect2(face.position - Vector2(0, wall), Vector2(face.size.x, wall)), rim)
	b.rect(face, face_col)
	var brick := Vector2(36.0, 11.5)
	var row := 0
	var y := face.position.y
	while y < face.end.y - 0.5:
		var off := brick.x * 0.5 if row % 2 == 1 else 0.0
		var x := face.position.x - off
		while x < face.end.x:
			var bk := Rect2(Vector2(x, y), brick).intersection(face)
			if bk.size.x > 1.0:
				var shade := _hash(int(x), row, 5) * 0.12
				b.rect(bk.grow(-1.0), face_col.lightened(shade))
				b.line(bk.position + Vector2(1, 1), Vector2(bk.end.x - 1, bk.position.y + 1), face_col.lightened(shade + 0.1), 1.0)
			x += brick.x
		y += brick.y
		row += 1
	# Shadow the wall casts onto the floor.
	for i in 5:
		b.rect(Rect2(r.position.x, r.position.y + i * 4.0, r.size.x, 4.0), Color(0, 0, 0, 0.32 - i * 0.06))
	for px in [r.position.x - wall, r.end.x - 6.0]:
		var p := Rect2(px, r.position.y - FACE - wall, wall + 6.0, FACE + wall + 10.0)
		b.rect(p, rim.darkened(0.15))
		b.rect(Rect2(p.position, Vector2(p.size.x, 6.0)), edge)


## A round stone pillar seen from above (the full game's).
static func pillar(c: CanvasItem, pos: Vector2, r: float, tower: String) -> void:
	var b := Draw.Batch.new()
	var face_col := _tint(Palette.WALL_FACE, tower)
	var shadow := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		shadow.append(pos + Vector2(r * 0.25, r * 0.55) + Vector2(cos(a), sin(a) * 0.55) * r * 1.15)
	b.polygon(shadow, Color(0, 0, 0, 0.35))
	b.circle(pos, r + 2.0, Palette.OUTLINE)
	b.circle(pos, r, face_col.darkened(0.15))
	b.circle(pos + Vector2(-r * 0.1, -r * 0.12), r * 0.86, face_col)
	b.arc(pos, r * 0.62, 0.0, TAU, 32, face_col.darkened(0.25), 1.5)
	b.circle(pos + Vector2(-r * 0.3, -r * 0.34), r * 0.25, Color(_tint(Palette.WALL_EDGE, tower).lightened(0.2), 0.5))
	var h := _hash(int(pos.x), int(pos.y))
	for i in 2:
		var a := (h + i * 0.37) * TAU
		b.line(pos + Vector2.from_angle(a) * r * 0.3, pos + Vector2.from_angle(a + 0.2) * r * 0.85, face_col.darkened(0.35), 1.0)
	b.flush(c)


## A torch on the wall: an iron bracket and a flickering flame, with its glow.
static func torch(c: CanvasItem, pos: Vector2, t: float) -> void:
	for i in 5:
		var k := 1.0 - float(i) / 5.0
		c.draw_circle(pos + Vector2(0, -6), 70.0 * (0.4 + 0.6 * k), Color(Palette.TORCH, 0.045))
	c.draw_rect(Rect2(pos + Vector2(-3, 4), Vector2(6, 14)), Color(0.13, 0.11, 0.12))
	c.draw_rect(Rect2(pos + Vector2(-6, 2), Vector2(12, 4)), Color(0.2, 0.17, 0.17))
	var h := 13.0 + 2.5 * sin(t * 11.0) + 1.5 * sin(t * 27.0)
	var sway := 1.5 * sin(t * 7.0)
	_flame(c, pos, h, 6.0, sway, Color(0.95, 0.35, 0.12, 0.9))
	_flame(c, pos, h * 0.72, 4.2, sway * 0.7, Color(1.0, 0.65, 0.2, 0.95))
	_flame(c, pos, h * 0.42, 2.6, sway * 0.4, Color(1.0, 0.93, 0.7))


static func _flame(c: CanvasItem, base: Vector2, h: float, w: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var p := Vector2(sin(a) * w, -cos(a) * w * 0.8)
		if p.y < 0.0:
			p.y *= h / w
			p.x += sway * (-p.y / h)
		pts.append(base + p)
	c.draw_colored_polygon(pts, col)


## Stone steps going up (the stair), glowing once the room is clear.
static func stair(c: CanvasItem, pos: Vector2, t: float, tower: String) -> void:
	for i in 5:
		var k := 1.0 - float(i) / 5.0
		c.draw_circle(pos, 120.0 * (0.4 + 0.6 * k) + 6.0 * sin(t * 3.0), Color(Palette.STAIR_LIGHT, 0.06))
	var step := _tint(Palette.WALL_FACE, tower).lightened(0.25)
	var w := 96.0
	for i in 5:
		var k := float(i) / 5.0
		var sw := w * (1.0 - k * 0.35)
		var r := Rect2(pos + Vector2(-sw / 2.0, 34.0 - 15.0 * float(i)), Vector2(sw, 15.0))
		c.draw_rect(r.grow(2.0), Palette.OUTLINE)
		c.draw_rect(r, step.darkened(0.1 * float(i)))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), step.lightened(0.15))
	# The dark of the way up.
	c.draw_rect(Rect2(pos + Vector2(-26, -50), Vector2(52, 20)), Color(0.03, 0.025, 0.05))
	var bob := 6.0 * sin(t * 5.0)
	c.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -66 + bob), pos + Vector2(-18, -90 + bob), pos + Vector2(18, -90 + bob)]), Color(1.0, 0.92, 0.5))


# --- a layout's pieces (floor_map.gd) --------------------------------------------

## The walls and pillars of a layout: each wall tile a raised block, its top
## lit, with a brick face where it meets the floor below (like the north wall).
static func blocks(c: CanvasItem, map, tower: String) -> void:
	var b := Draw.Batch.new()
	var rim := _tint(Palette.WALL_TOP, tower).lightened(0.05)
	var edge := _tint(Palette.WALL_EDGE, tower)
	var face_col := _tint(Palette.WALL_FACE, tower)
	var T: float = map.TILE
	for y in map.ROWS:
		for x in map.COLS:
			var ch: String = map.grid[y][x]
			if ch != "#" and ch != "X":
				continue
			var r := Rect2(map.origin + Vector2(x, y) * T, Vector2(T, T))
			if ch == "#" and _walled(map, x, y):
				# Deep inside a mass of wall: solid dark rock, not blocks.
				b.rect(r, rim.darkened(0.55))
				continue
			var below_open: bool = y + 1 < map.ROWS and String(map.grid[y + 1][x]) != "#"
			var face_h := 13.0 if below_open else 0.0
			# The shadow it casts on the floor below.
			if below_open:
				b.rect(Rect2(r.position + Vector2(0, T), Vector2(T, 8)), Color(0, 0, 0, 0.28))
			var top := Rect2(r.position, Vector2(T, T - face_h))
			b.rect(top.grow(1.0), Palette.OUTLINE)
			b.rect(top, rim.lightened(_hash(x, y, 9) * 0.06))
			b.line(top.position + Vector2(1, 1.5), Vector2(top.end.x - 1, top.position.y + 1.5), edge.lightened(0.15), 2.0)
			b.line(Vector2(top.position.x, top.end.y - 1), Vector2(top.end.x, top.end.y - 1), rim.darkened(0.3), 2.0)
			if face_h > 0.0:
				var face := Rect2(Vector2(r.position.x, top.end.y), Vector2(T, face_h))
				b.rect(face, face_col)
				var off := 10.0 if x % 2 == 0 else 0.0
				var bx := face.position.x - off
				while bx < face.end.x:
					var bk := Rect2(Vector2(bx, face.position.y + 1.0), Vector2(20.0, face_h - 2.0)).intersection(face)
					if bk.size.x > 1.0:
						b.rect(bk.grow(-1.0), face_col.lightened(_hash(int(bx), y, 5) * 0.12))
					bx += 20.0
	b.flush(c)
	for p in map.pillars:
		pillar(c, p, 18.0, tower)


## Is every tile round this one (the eight neighbours) wall, or off the map?
static func _walled(map, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= map.COLS or ny >= map.ROWS:
				continue
			if String(map.grid[ny][nx]) != "#":
				return false
	return true


## A gate across its tiles: iron bars, which sink into the floor once open.
static func gate(c: CanvasItem, map, open_k: float, t: float) -> void:
	var T: float = map.TILE
	for cell in map.gate_cells:
		var r := Rect2(map.origin + Vector2(cell) * T, Vector2(T, T))
		var h := (T - 6.0) * (1.0 - open_k)
		c.draw_rect(Rect2(r.position + Vector2(0, T - 6.0), Vector2(T, 6.0)), Color(0.18, 0.16, 0.18))
		if h <= 1.0:
			continue
		for i in 4:
			var x := r.position.x + 5.0 + i * 10.0
			c.draw_rect(Rect2(Vector2(x - 2.5, r.end.y - 6.0 - h), Vector2(5.0, h)), Palette.OUTLINE)
			c.draw_rect(Rect2(Vector2(x - 1.5, r.end.y - 6.0 - h), Vector2(3.0, h)), Color(0.55, 0.56, 0.62))
		c.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 6.0 - h), Vector2(T, 5.0)), Color(0.4, 0.4, 0.46))


## A pressure plate: a stone disc with a rune that glows; pressed, it sinks
## and glows green.
static func plate(c: CanvasItem, p: Vector2, down: bool, t: float) -> void:
	var glow := Color(0.5, 1.0, 0.6) if down else Color(1.0, 0.85, 0.45)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	for i in 4:
		c.draw_circle(p, 26.0 + 6.0 * i, Color(glow, (0.08 if down else 0.06 * pulse)))
	c.draw_circle(p, 17.0, Palette.OUTLINE)
	c.draw_circle(p, 15.0, Color(0.45, 0.43, 0.48) if not down else Color(0.32, 0.36, 0.34))
	c.draw_arc(p, 9.0, 0.0, TAU, 20, Color(glow, 0.9 if down else 0.5 + 0.4 * pulse), 3.0)
	c.draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color(glow, 0.8), 2.0)
	c.draw_line(p + Vector2(0, -6), p + Vector2(0, 6), Color(glow, 0.8), 2.0)


## A lever on a stone block: hit it and it flips (and glows green).
static func lever(c: CanvasItem, p: Vector2, on: bool, t: float) -> void:
	if not on:
		for i in 4:
			c.draw_circle(p, 24.0 + 6.0 * i, Color(1.0, 0.85, 0.45, 0.05 * (0.6 + 0.4 * sin(t * 4.0))))
	c.draw_rect(Rect2(p + Vector2(-15, -6), Vector2(30, 20)), Palette.OUTLINE)
	c.draw_rect(Rect2(p + Vector2(-13, -4), Vector2(26, 16)), Color(0.42, 0.4, 0.45))
	var tip := p + Vector2(14.0 if on else -14.0, -22.0)
	c.draw_line(p + Vector2(0, 2), tip, Palette.OUTLINE, 7.0)
	c.draw_line(p + Vector2(0, 2), tip, Color(0.55, 0.36, 0.2), 4.0)
	c.draw_circle(tip, 6.0, Palette.OUTLINE)
	c.draw_circle(tip, 4.5, Color(0.5, 0.95, 0.55) if on else Color(0.9, 0.3, 0.25))


## A brazier: a stone bowl, cold, or burning once it's lit (hit it).
static func brazier(c: CanvasItem, p: Vector2, lit: bool, t: float) -> void:
	if lit:
		for i in 5:
			c.draw_circle(p + Vector2(0, -8), 30.0 + 10.0 * i, Color(Palette.TORCH, 0.06))
	elif fmod(t, 2.0) < 1.0:
		c.draw_arc(p, 24.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.45, 0.35), 2.0)
	c.draw_circle(p, 16.0, Palette.OUTLINE)
	c.draw_circle(p, 14.0, Color(0.38, 0.36, 0.4))
	c.draw_circle(p, 9.0, Color(0.15, 0.12, 0.12))
	if lit:
		var h := 18.0 + 3.0 * sin(t * 11.0)
		_flame(c, p + Vector2(0, 2), h, 8.0, 2.0 * sin(t * 7.0), Color(0.95, 0.35, 0.12, 0.95))
		_flame(c, p + Vector2(0, 2), h * 0.7, 5.5, 1.4 * sin(t * 7.0), Color(1.0, 0.65, 0.2))
		_flame(c, p + Vector2(0, 2), h * 0.4, 3.2, 0.8 * sin(t * 7.0), Color(1.0, 0.93, 0.7))
	else:
		c.draw_circle(p + Vector2(-3, 1), 2.5, Color(0.6, 0.25, 0.15))
		c.draw_circle(p + Vector2(3, -1), 2.0, Color(0.5, 0.2, 0.12))


## A portal: a swirl of light in its colour. `faint` for a hidden one.
static func portal(c: CanvasItem, p: Vector2, col: Color, t: float, faint := false) -> void:
	var a := 0.35 if faint else 1.0
	for i in 5:
		c.draw_circle(p, 34.0 + 8.0 * i, Color(col, 0.05 * a))
	c.draw_circle(p, 22.0, Color(col.darkened(0.6), 0.85 * a))
	for k in 3:
		var pts := PackedVector2Array()
		for i in 18:
			var f := float(i) / 17.0
			var ang := t * (2.5 + k * 0.4) + k * TAU / 3.0 + f * 4.0
			pts.append(p + Vector2(cos(ang), sin(ang) * 0.8) * (4.0 + 18.0 * f))
		c.draw_polyline(pts, Color(col.lightened(0.3), 0.85 * a), 3.0, true)
	c.draw_arc(p, 22.0, 0.0, TAU, 36, Color(col.lightened(0.5), 0.9 * a), 2.5)
	for k in 4:
		var ang := -t * 1.5 + k * TAU / 4.0
		c.draw_circle(p + Vector2(cos(ang), sin(ang)) * 30.0, 2.5, Color(1, 1, 1, 0.8 * a))


## Cracks over a cracked wall tile (a secret behind it).
static func crack(c: CanvasItem, map, cell: Vector2i) -> void:
	var r := Rect2(map.origin + Vector2(cell) * map.TILE, Vector2(map.TILE, map.TILE))
	var m := r.get_center() + Vector2(0, -4)
	var col := Color(0.08, 0.06, 0.08, 0.85)
	for k in 5:
		var a := float(k) / 5.0 * TAU + 0.4
		var p1 := m + Vector2.from_angle(a) * 8.0
		var p2 := m + Vector2.from_angle(a + 0.3) * 17.0
		c.draw_line(m, p1, col, 2.0)
		c.draw_line(p1, p2, col, 1.5)


## A chest: dark wood with gold bands; open, its lid up and treasure glowing.
static func chest(c: CanvasItem, p: Vector2, open: bool, t: float) -> void:
	var wood := Color(0.48, 0.3, 0.16)
	var gold := Color(0.95, 0.76, 0.3)
	if not open:
		for i in 4:
			c.draw_circle(p, 26.0 + 7.0 * i, Color(gold, 0.05 * (0.6 + 0.4 * sin(t * 3.0))))
	var body := Rect2(p + Vector2(-17, -6), Vector2(34, 20))
	c.draw_rect(body.grow(2.0), Palette.OUTLINE)
	c.draw_rect(body, wood)
	c.draw_rect(Rect2(body.position + Vector2(0, 7), Vector2(34, 4)), gold)
	if open:
		c.draw_rect(Rect2(p + Vector2(-17, -24), Vector2(34, 14)).grow(2.0), Palette.OUTLINE)
		c.draw_rect(Rect2(p + Vector2(-17, -24), Vector2(34, 14)), wood.darkened(0.25))
		for i in 4:
			c.draw_circle(p + Vector2(0, -6), 10.0 + 8.0 * i, Color(1.0, 0.9, 0.5, 0.12))
	else:
		var lid := Rect2(p + Vector2(-17, -16), Vector2(34, 11))
		c.draw_rect(lid.grow(2.0), Palette.OUTLINE)
		c.draw_rect(lid, wood.lightened(0.1))
		c.draw_rect(Rect2(p + Vector2(-4, -9), Vector2(8, 8)), gold)
