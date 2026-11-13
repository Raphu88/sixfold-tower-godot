extends RefCounted
## The room painter's tiles (painter.gd): what each character of a room's
## grid is called, and how it's drawn, close to the game's own look
## (room.gd's flagstones, walls, low walls and pillars; puzzle.gd's eyes,
## plates and blocks), in a tower's colours. Names and notes are data:
## rename freely.

const Palette := preload("res://scripts/palette.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")

## The palette, in order: [character, name, what it does].
const TILES := [
	[".", "Floor", "Open floor."],
	["#", "Wall", "Solid. On the room's edge it's part of its outline; inside, a low wall to hide behind."],
	["X", "Rock", "Not part of the room: its outline bends around it."],
	["o", "Pillar", "A round pillar. Blocks walking and shots."],
	["C", "Chasm", "A chasm to jump in the Firebird's tower. A low wall elsewhere."],
	["~", "Water", "Standing water in the Kraken's tower. Floor elsewhere."],
	["M", "Monster spot", "Monsters wait here."],
	["?", "Random", "Usually floor, sometimes a low wall or a pillar."],
	["=", "Rail", "Puzzle rooms: blocks walking, not sight or arrows."],
	["E", "Stone eye", "Hall of Eyes: hit every eye."],
	["P", "Plate", "Weighing Room: needs a block or a monster on it."],
	["B", "Block", "Weighing Room: a stone block to push."],
	["G", "Gate", "Puzzle rooms: opens once the puzzle is solved."],
	["L", "Lever", "Weighing Room: puts the blocks back."],
	["$", "Reward", "Puzzle rooms: the reward behind the gate."],
]


static func tile_name(ch: String) -> String:
	for t in TILES:
		if t[0] == ch:
			return t[1]
	return ch


static func tile_note(ch: String) -> String:
	for t in TILES:
		if t[0] == ch:
			return t[2]
	return ""


## A tower's look for the painter: its stone tint and what C and ~ become.
static func look(tid: String) -> Dictionary:
	var t: Dictionary = Towers.TOWERS.get(tid, {})
	var stone: Color = t.get("stone", Color.WHITE)
	return {"tint": stone * Palette.TOWER_TINT.get(tid, Color.WHITE), "chasms": t.get("chasms", false), "water": t.get("puddles", false)}


static func _hash(x: int, y: int, salt := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


## Draws one tile `ch` in the rect `r`. `lk` is look(); `at` the tile's place
## (for the stones' variety); `outline` a wall that's part of the room's
## outline; `open_below` the tile under it is open (a wall shows its face).
static func draw(ci: CanvasItem, ch: String, r: Rect2, lk: Dictionary, at := Vector2i.ZERO, outline := false, open_below := false) -> void:
	var tint: Color = lk.get("tint", Color.WHITE)
	var s := r.size.x
	match ch:
		"X":
			_rock(ci, r, tint, at, open_below)
			return
		"#":
			if outline:
				_rock(ci, r, tint, at, open_below)
				return
	_floor(ci, r, tint, at)
	var c := r.get_center()
	match ch:
		"#":
			_low_wall(ci, r, tint, at)
		"o":
			_pillar(ci, c, s * 0.44, tint)
		"C":
			if lk.get("chasms", false):
				_chasm(ci, r)
			else:
				_low_wall(ci, r, tint, at)
				ci.draw_polyline(PackedVector2Array([r.position + Vector2(s * 0.2, s * 0.3), c + Vector2(-s * 0.05, -s * 0.12), c + Vector2(s * 0.12, s * 0.02), r.position + Vector2(s * 0.8, s * 0.36)]), Color(0, 0, 0, 0.65), maxf(1.0, s * 0.05))
		"~":
			if lk.get("water", false):
				ci.draw_circle(c, s * 0.5, Color(0.1, 0.22, 0.28, 0.85))
				ci.draw_circle(c, s * 0.4, Color(0.14, 0.3, 0.36, 0.7))
				ci.draw_arc(c, s * 0.5, 0.0, TAU, 24, Color(0.5, 0.75, 0.8, 0.4), maxf(1.0, s * 0.04))
				ci.draw_arc(c + Vector2(-s * 0.1, -s * 0.12), s * 0.18, PI * 1.1, PI * 1.6, 8, Color(0.8, 0.95, 1.0, 0.4), maxf(1.0, s * 0.04))
			else:
				for i in 2:
					ci.draw_arc(c + Vector2(0, (i - 0.5) * s * 0.22), s * (0.26 - i * 0.06), PI * 1.15, PI * 1.85, 8, Color(0.45, 0.7, 0.85, 0.35), maxf(1.0, s * 0.04))
		"M":
			_monster(ci, c, s)
		"?":
			var f := UI.font("display")
			var fs := int(s * 0.62)
			var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			UI.draw_text(ci, f, Vector2(c.x - w * 0.5 + 1, c.y + fs * 0.32 + 1), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
			UI.draw_text(ci, f, Vector2(c.x - w * 0.5, c.y + fs * 0.32), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD)
		"=":
			var y := c.y
			ci.draw_rect(Rect2(r.position.x, y - s * 0.09, s, s * 0.18), Palette.OUTLINE)
			ci.draw_rect(Rect2(r.position.x, y - s * 0.06, s, s * 0.1), Palette.WOOD * tint)
			for px in [0.18, 0.82]:
				ci.draw_rect(Rect2(r.position.x + s * px - s * 0.08, y - s * 0.2, s * 0.16, s * 0.34), Palette.OUTLINE)
				ci.draw_rect(Rect2(r.position.x + s * px - s * 0.055, y - s * 0.17, s * 0.11, s * 0.28), (Palette.WALL_FACE * tint).lightened(0.1))
		"E":
			ci.draw_circle(c, s * 0.38, Palette.OUTLINE)
			ci.draw_circle(c, s * 0.34, (Palette.WALL_FACE * tint).lightened(0.08))
			var eye := PackedVector2Array()
			for i in 13:
				var a := TAU * i / 12.0
				eye.append(c + Vector2(cos(a) * s * 0.24, sin(a) * s * 0.12))
			ci.draw_colored_polygon(eye, Color(0.95, 0.9, 0.78))
			ci.draw_circle(c, s * 0.09, Palette.EYE_LIGHT.darkened(0.2))
			ci.draw_circle(c, s * 0.045, Palette.OUTLINE)
		"P":
			var pr := r.grow(-s * 0.16)
			ci.draw_rect(pr, Palette.OUTLINE)
			ci.draw_rect(pr.grow(-s * 0.04), (Palette.WALL_FACE * tint).darkened(0.1))
			ci.draw_rect(pr.grow(-s * 0.12), Color(UI.GILT, 0.55), false, maxf(1.0, s * 0.04))
		"B":
			var br := r.grow(-s * 0.1)
			ci.draw_rect(Rect2(br.position + Vector2(s * 0.05, s * 0.08), br.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(br, Palette.OUTLINE)
			ci.draw_rect(br.grow(-s * 0.04), (Palette.WALL_FACE * tint).lightened(0.05))
			ci.draw_rect(Rect2(br.position + Vector2(s * 0.04, s * 0.04), Vector2(br.size.x - s * 0.08, br.size.y * 0.45)), (Palette.WALL_TOP * tint).lightened(0.2))
		"G":
			ci.draw_rect(r.grow(-s * 0.06), Color(0, 0, 0, 0.35))
			for i in 4:
				var x := r.position.x + s * (0.2 + i * 0.2)
				ci.draw_line(Vector2(x, r.position.y + s * 0.1), Vector2(x, r.end.y - s * 0.1), Palette.DOOR_IRON.lightened(0.25), maxf(1.5, s * 0.07))
			ci.draw_line(Vector2(r.position.x + s * 0.12, c.y), Vector2(r.end.x - s * 0.12, c.y), Palette.DOOR_IRON.lightened(0.1), maxf(1.5, s * 0.08))
		"L":
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y + s * 0.1, s * 0.44, s * 0.16), Palette.OUTLINE)
			ci.draw_rect(Rect2(c.x - s * 0.19, c.y + s * 0.12, s * 0.38, s * 0.11), Palette.DOOR_IRON.lightened(0.2))
			ci.draw_line(c + Vector2(0, s * 0.14), c + Vector2(s * 0.18, -s * 0.26), Palette.WOOD, maxf(1.5, s * 0.08))
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.26), s * 0.08, Palette.DANGER)
		"$":
			UI.draw_gem(ci, c, s * 0.26, UI.GILT)


## The game's flagstone: a gap around a stone, lit top-left, shadowed bottom-right.
static func _floor(ci: CanvasItem, r: Rect2, tint: Color, at: Vector2i) -> void:
	var s := r.size.x
	var k := s / 40.0
	ci.draw_rect(r, Palette.FLOOR_GAP * tint)
	# (a touch lighter than the floor at rest: in play a torch and the climber's light fall on it)
	var base: Color = (Palette.FLOOR.lerp(Palette.FLOOR_LIGHT, _hash(at.x, at.y)) * tint).lightened(0.1)
	var inner := r.grow(-1.5 * k)
	ci.draw_rect(inner, base)
	var w := maxf(1.0, 1.5 * k)
	ci.draw_line(inner.position, Vector2(inner.end.x, inner.position.y), base.lightened(0.08), w)
	ci.draw_line(inner.position, Vector2(inner.position.x, inner.end.y), base.lightened(0.04), w)
	ci.draw_line(Vector2(inner.position.x, inner.end.y), inner.end, base.darkened(0.3), w)
	ci.draw_line(Vector2(inner.end.x, inner.position.y), inner.end, base.darkened(0.2), w)


## Rock, and walls on the room's outline: dark stone, with its brick face
## where it looks down onto the floor (as the game draws the walls).
static func _rock(ci: CanvasItem, r: Rect2, tint: Color, at: Vector2i, open_below: bool) -> void:
	var s := r.size.x
	ci.draw_rect(r, Palette.VOID.lerp(Palette.WALL_TOP * tint, 0.4))
	# A faint hatch: not part of the room.
	for i in 3:
		var o := s * (0.2 + i * 0.3)
		ci.draw_line(r.position + Vector2(o, 0), r.position + Vector2(0, o), Color(0, 0, 0, 0.25), maxf(1.0, s * 0.03))
	if open_below:
		var face := Rect2(r.position + Vector2(0, s * 0.35), Vector2(s, s * 0.65))
		ci.draw_rect(face, Palette.WALL_FACE * tint)
		for row in 3:
			var by := face.position.y + row * face.size.y / 3.0
			var off := s * 0.22 if row % 2 == 1 else 0.0
			for bx in [0.0, 0.45, 0.9]:
				var b := Rect2(Vector2(face.position.x + bx * s - off, by), Vector2(s * 0.45, face.size.y / 3.0)).intersection(face)
				if b.size.x > 1.0:
					ci.draw_rect(b.grow(-maxf(0.5, s * 0.025)), (Palette.WALL_FACE * tint).lightened(_hash(at.x * 3 + int(bx * 10), at.y * 3 + row, 5) * 0.12))


## A low wall seen from above: a stone top and a short brick face.
static func _low_wall(ci: CanvasItem, r: Rect2, tint: Color, at: Vector2i) -> void:
	var s := r.size.x
	var face_h := s * 0.35
	ci.draw_rect(Rect2(r.position + Vector2(s * 0.08, s * 0.08), r.size), Color(0, 0, 0, 0.28))
	ci.draw_rect(r.grow(-maxf(0.5, s * 0.02)), Palette.OUTLINE)
	var top := Rect2(r.position + Vector2(s * 0.05, s * 0.05), Vector2(s * 0.9, s * 0.95 - face_h))
	ci.draw_rect(top, (Palette.WALL_TOP * tint).lightened(0.1 + _hash(at.x, at.y, 11) * 0.1))
	ci.draw_line(top.position, Vector2(top.end.x, top.position.y), Palette.WALL_EDGE * tint, maxf(1.0, s * 0.04))
	var face := Rect2(Vector2(r.position.x + s * 0.05, top.end.y), Vector2(s * 0.9, face_h - s * 0.05))
	ci.draw_rect(face, Palette.WALL_FACE * tint)
	for row in 2:
		var by := face.position.y + row * face.size.y * 0.5
		var off := s * 0.22 if row == 1 else 0.0
		var bx := face.position.x - off
		while bx < face.end.x:
			var brick := Rect2(Vector2(bx, by), Vector2(s * 0.45, face.size.y * 0.5)).intersection(face)
			if brick.size.x > 1.0:
				ci.draw_rect(brick.grow(-maxf(0.4, s * 0.02)), (Palette.WALL_FACE * tint).lightened(_hash(int(bx), int(by), 12) * 0.12))
			bx += s * 0.45


static func _pillar(ci: CanvasItem, pos: Vector2, r: float, tint: Color) -> void:
	ci.draw_circle(pos + Vector2(r * 0.25, r * 0.4), r * 1.05, Color(0, 0, 0, 0.32))
	ci.draw_circle(pos, r + maxf(1.0, r * 0.1), Palette.OUTLINE)
	ci.draw_circle(pos, r, (Palette.WALL_FACE * tint).darkened(0.15))
	ci.draw_circle(pos + Vector2(-r * 0.1, -r * 0.12), r * 0.86, Palette.WALL_FACE * tint)
	ci.draw_arc(pos, r * 0.62, 0.0, TAU, 24, (Palette.WALL_FACE * tint).darkened(0.25), maxf(1.0, r * 0.07))
	ci.draw_circle(pos + Vector2(-r * 0.3, -r * 0.34), r * 0.25, Color((Palette.WALL_EDGE * tint).lightened(0.2), 0.5))


static func _chasm(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size.x
	ci.draw_rect(r, Color(0.12, 0.1, 0.1))
	ci.draw_rect(r.grow(-s * 0.06), Color(0.02, 0.015, 0.03))
	for i in 3:
		ci.draw_rect(r.grow(-s * (0.1 + i * 0.08)), Color(0, 0, 0, 0.25), false, maxf(1.0, s * 0.05))
	ci.draw_line(r.position + Vector2(0, s * 0.06), Vector2(r.end.x, r.position.y + s * 0.06), Color(0.55, 0.5, 0.45, 0.6), maxf(1.0, s * 0.05))


## A monster's spot: a dark-red creature waiting, its eyes open.
static func _monster(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_circle(c + Vector2(0, s * 0.16), s * 0.26, Color(0, 0, 0, 0.3))
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.3 + s * 0.08))
	body.append(c + Vector2(s * 0.3, s * 0.2))
	body.append(c + Vector2(-s * 0.3, s * 0.2))
	ci.draw_colored_polygon(body, Palette.OUTLINE)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(c + (p - c) * 0.86 + Vector2(0, s * 0.01))
	ci.draw_colored_polygon(inner, Color(0.62, 0.17, 0.15))
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(side * s * 0.1, -s * 0.02), s * 0.06, Color(1.0, 0.92, 0.7))
		ci.draw_circle(c + Vector2(side * s * 0.1, -s * 0.01), s * 0.03, Palette.OUTLINE)


## The stair at the top middle of a stair room: stone steps.
static func draw_stair(ci: CanvasItem, top_mid: Vector2, s: float, tint: Color) -> void:
	var w := s * 1.7
	var base := top_mid + Vector2(0, s * 0.85)
	for i in 5:
		var k := float(i) / 5.0
		var step_w := w * (1.0 - k * 0.35)
		var y := base.y - i * s * 0.2
		var rect := Rect2(Vector2(top_mid.x - step_w / 2.0, y - s * 0.2), Vector2(step_w, s * 0.2))
		var col := (Palette.WALL_FACE * tint).lightened(0.05 + k * 0.1)
		ci.draw_rect(rect, Palette.OUTLINE)
		ci.draw_rect(rect.grow(-1.0), col)
	var tip := top_mid + Vector2(0, s * 0.1)
	ci.draw_polyline(PackedVector2Array([tip + Vector2(-s * 0.22, s * 0.18), tip, tip + Vector2(s * 0.22, s * 0.18)]), Color(Palette.STAIR_LIGHT, 0.9), maxf(1.5, s * 0.06))
