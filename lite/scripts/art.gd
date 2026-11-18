extends RefCounted
## Six Towers LITE's own drawings, all in code: the picture icons on the
## buttons and screens, hearts and stars, the guide, and the words (in
## Andika). The climber, monsters and beasts are drawn as in the full game
## (climber_art.gd, creatures.gd), and so is the room (room_art.gd).
## Each function draws onto a CanvasItem `c` around `pos`.

const Data := preload("res://scripts/data.gd")

const OUT := Color(0.06, 0.05, 0.08)

## The words' font: Andika, made by SIL for children learning to read (its
## letters are drawn the way they're taught, like a single-storey a and g).
const FONT_PATH := "res://assets/fonts/andika/Andika-Bold.ttf"
static var _font: Font


static func _begin(c: CanvasItem, pos: Vector2, s: float, flip := false) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(-s if flip else s, s))


static func _end(c: CanvasItem) -> void:
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _disc(c: CanvasItem, p: Vector2, r: float, col: Color, line := 2.0) -> void:
	c.draw_circle(p, r + line, OUT)
	c.draw_circle(p, r, col)


static func _poly(c: CanvasItem, pts: PackedVector2Array, col: Color, line := 2.0) -> void:
	if line > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, OUT, line * 2.0, true)
	c.draw_colored_polygon(pts, col)


static func _ellipse(center: Vector2, rx: float, ry: float, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A soft glow: a few see-through circles.
static func glow(c: CanvasItem, p: Vector2, r: float, col: Color, strength := 1.0) -> void:
	for i in 4:
		var f := 1.0 - float(i) / 4.0
		c.draw_circle(p, r * f, Color(col, 0.12 * strength))


# --- words ---------------------------------------------------------------------

static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	return _font


## Words centred on `p` (their middle), big and outlined so they read on
## anything behind them. `pop` (0 to 1) grows them in as they appear.
static func words(c: CanvasItem, p: Vector2, text: String, size := 40, col := Color(1.0, 0.97, 0.88), pop := 1.0) -> void:
	if text == "" or pop <= 0.0:
		return
	var f := font()
	var sz := maxi(1, int(round(float(size) * (0.6 + 0.4 * clampf(pop, 0.0, 1.0)))))
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var base := p + Vector2(-w / 2.0, f.get_ascent(sz) * 0.5 - f.get_descent(sz) * 0.3)
	var a := clampf(pop * 2.0, 0.0, 1.0)
	c.draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, maxi(4, sz / 6), Color(OUT, a))
	c.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, a))


## A speech bubble with words in it, its tail pointing down to `tail`.
static func bubble(c: CanvasItem, p: Vector2, text: String, tail: Vector2, size := 34) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 40.0
	var h := float(size) * 1.6
	var r := Rect2(p - Vector2(w, h) / 2.0, Vector2(w, h))
	_poly(c, PackedVector2Array([Vector2(p.x - 14, r.end.y - 2), tail, Vector2(p.x + 14, r.end.y - 2)]), Color(1, 1, 1))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1)
	box.border_color = OUT
	box.set_border_width_all(4)
	box.set_corner_radius_all(int(h / 2.0))
	box.draw(c.get_canvas_item(), r)
	c.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 10, r.end.y - 5), tail + Vector2(0, -6), Vector2(p.x + 10, r.end.y - 5)]), Color(1, 1, 1))
	words(c, p, text, size, Color(0.12, 0.1, 0.16))


# --- icons ---------------------------------------------------------------------

static func heart(c: CanvasItem, p: Vector2, r: float, full := true) -> void:
	var col := Color(0.95, 0.25, 0.3) if full else Color(0.25, 0.2, 0.25)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		pts.append(p + Vector2(x, y) * r / 16.0)
	_poly(c, pts, col, 2.0)
	if full:
		c.draw_circle(p + Vector2(-r * 0.4, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.6))


static func star(c: CanvasItem, p: Vector2, r: float, col := Color(1.0, 0.85, 0.3), lit := true) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0 - PI / 2.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	_poly(c, pts, col if lit else Color(0.25, 0.23, 0.28), 1.5)


static func sword(c: CanvasItem, p: Vector2, r: float, col := Color(0.92, 0.94, 1.0)) -> void:
	var d := Vector2(1, -1).normalized()
	var n := Vector2(d.y, -d.x)
	var tip := p + d * r
	var base := p - d * r * 0.35
	_poly(c, PackedVector2Array([base + n * r * 0.13, tip + n * r * 0.02, tip + d * r * 0.08, tip - n * r * 0.02, base - n * r * 0.13]), col)
	c.draw_line(base + n * r * 0.38, base - n * r * 0.38, OUT, r * 0.2)
	c.draw_line(base + n * r * 0.34, base - n * r * 0.34, Color(0.95, 0.75, 0.3), r * 0.12)
	c.draw_line(base, p - d * r * 0.8, OUT, r * 0.2)
	c.draw_line(base, p - d * r * 0.78, Color(0.5, 0.32, 0.2), r * 0.12)


## A weapon's picture (Data.WEAPON_ORDER).
static func weapon_icon(c: CanvasItem, p: Vector2, r: float, id: String) -> void:
	var steel := Color(0.88, 0.9, 0.96)
	var wood := Color(0.55, 0.36, 0.2)
	var d := Vector2(1, -1).normalized()
	var n := Vector2(d.y, -d.x)
	match id:
		"sword":
			sword(c, p, r)
		"dagger":
			var tip := p + d * r * 0.75
			var base := p - d * r * 0.05
			_poly(c, PackedVector2Array([base + n * r * 0.16, tip, base - n * r * 0.16]), steel)
			c.draw_line(base + n * r * 0.32, base - n * r * 0.32, OUT, r * 0.2)
			c.draw_line(base + n * r * 0.28, base - n * r * 0.28, Color(0.95, 0.75, 0.3), r * 0.12)
			c.draw_line(base, p - d * r * 0.55, OUT, r * 0.22)
			c.draw_line(base, p - d * r * 0.53, wood, r * 0.13)
		"hammer":
			c.draw_line(p - d * r * 0.85, p + d * r * 0.5, OUT, r * 0.22)
			c.draw_line(p - d * r * 0.83, p + d * r * 0.48, wood, r * 0.13)
			var h := p + d * r * 0.55
			_poly(c, PackedVector2Array([h + n * r * 0.55 - d * r * 0.25, h + n * r * 0.55 + d * r * 0.25, h - n * r * 0.55 + d * r * 0.25, h - n * r * 0.55 - d * r * 0.25]), Color(0.62, 0.64, 0.7))
		"bow":
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(-1.1, 1.1, float(i) / 12.0)
				pts.append(p + Vector2(-r * 0.25, 0) + Vector2(cos(a) * r * 0.75 - r * 0.2, sin(a) * r * 0.9))
			c.draw_polyline(pts, OUT, r * 0.24, true)
			c.draw_polyline(pts, wood, r * 0.13, true)
			c.draw_line(pts[0], pts[12], Color(0.95, 0.92, 0.85), maxf(1.5, r * 0.05))
			c.draw_line(p + Vector2(-r * 0.3, 0), p + Vector2(r * 0.85, 0), OUT, r * 0.13)
			c.draw_line(p + Vector2(-r * 0.3, 0), p + Vector2(r * 0.8, 0), steel.darkened(0.2), r * 0.06)
			_poly(c, PackedVector2Array([p + Vector2(r * 0.95, 0), p + Vector2(r * 0.7, -r * 0.14), p + Vector2(r * 0.7, r * 0.14)]), steel, 1.0)


## Roll: a curling arrow (a tumble).
static func roll_icon(c: CanvasItem, p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 15:
		var a := lerpf(PI * 0.9, PI * 2.6, float(i) / 14.0)
		pts.append(p + Vector2(cos(a), sin(a)) * r * 0.6)
	c.draw_polyline(pts, OUT, r * 0.32, true)
	c.draw_polyline(pts, Color(0.75, 0.9, 1.0), r * 0.18, true)
	var end := pts[14]
	var dir := (pts[14] - pts[13]).normalized()
	_poly(c, PackedVector2Array([end + dir * r * 0.35, end + dir.orthogonal() * r * 0.3, end - dir.orthogonal() * r * 0.3]), Color(0.75, 0.9, 1.0))


## Parry: a blade held up with a spark where a blow meets it.
static func parry_icon(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_line(p + Vector2(-r * 0.7, r * 0.55), p + Vector2(r * 0.55, -r * 0.7), OUT, r * 0.3)
	c.draw_line(p + Vector2(-r * 0.68, r * 0.53), p + Vector2(r * 0.53, -r * 0.68), Color(0.9, 0.92, 1.0), r * 0.16)
	c.draw_line(p + Vector2(-r * 0.62, r * 0.18), p + Vector2(-r * 0.25, r * 0.62), OUT, r * 0.2)
	star(c, p + Vector2(r * 0.2, -r * 0.05), r * 0.42, Color(1.0, 0.9, 0.45))


## Swap: two arrows chasing each other round (put over a weapon's picture).
static func swap_arrows(c: CanvasItem, p: Vector2, r: float) -> void:
	for k in 2:
		var a0 := PI * float(k)
		var pts := PackedVector2Array()
		for i in 7:
			var a := a0 + lerpf(0.3, 2.4, float(i) / 6.0)
			pts.append(p + Vector2(cos(a), sin(a)) * r)
		c.draw_polyline(pts, OUT, r * 0.22, true)
		c.draw_polyline(pts, Color(1, 1, 1, 0.9), r * 0.11, true)
		var dir := (pts[6] - pts[5]).normalized()
		c.draw_colored_polygon(PackedVector2Array([pts[6] + dir * r * 0.25, pts[6] + dir.orthogonal() * r * 0.2, pts[6] - dir.orthogonal() * r * 0.2]), Color(1, 1, 1, 0.9))


## The climber screen's button: a little person.
static func person_icon(c: CanvasItem, p: Vector2, r: float, col := Color(0.95, 0.9, 0.8)) -> void:
	_disc(c, p + Vector2(0, -r * 0.38), r * 0.28, col, 1.5)
	_poly(c, PackedVector2Array([p + Vector2(-r * 0.5, r * 0.62), p + Vector2(-r * 0.32, -r * 0.02), p + Vector2(r * 0.32, -r * 0.02), p + Vector2(r * 0.5, r * 0.62)]), col, 1.5)


## The Look tab: a mirror.
static func mirror_icon(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_line(p + Vector2(0, r * 0.3), p + Vector2(0, r * 0.95), OUT, r * 0.26)
	c.draw_line(p + Vector2(0, r * 0.3), p + Vector2(0, r * 0.92), Color(0.55, 0.36, 0.2), r * 0.14)
	_poly(c, _ellipse(p + Vector2(0, -r * 0.2), r * 0.5, r * 0.62), Color(0.95, 0.75, 0.3))
	c.draw_colored_polygon(_ellipse(p + Vector2(0, -r * 0.2), r * 0.38, r * 0.5), Color(0.7, 0.85, 0.95))
	c.draw_line(p + Vector2(-r * 0.15, -r * 0.5), p + Vector2(r * 0.12, -r * 0.05), Color(1, 1, 1, 0.8), r * 0.08)


## A left or right arrow (the Look tab's choosers).
static func arrow(c: CanvasItem, p: Vector2, r: float, right: bool) -> void:
	var s := 1.0 if right else -1.0
	_poly(c, PackedVector2Array([p + Vector2(s * r * 0.55, 0), p + Vector2(-s * r * 0.35, -r * 0.55), p + Vector2(-s * r * 0.35, r * 0.55)]), Color(0.97, 0.85, 0.58))


## The picture of a magic (one for each essence).
static func magic_icon(c: CanvasItem, p: Vector2, r: float, essence: String) -> void:
	var col := Data.color(essence).lightened(0.25)
	match essence:
		"air":  # lightning
			_poly(c, PackedVector2Array([p + Vector2(0.15, -1) * r, p + Vector2(-0.45, 0.1) * r, p + Vector2(-0.02, 0.1) * r, p + Vector2(-0.2, 1) * r, p + Vector2(0.45, -0.15) * r, p + Vector2(0.05, -0.15) * r]), Color(1.0, 0.95, 0.5))
		"water":  # a wave
			for k in 2:
				var pts := PackedVector2Array()
				for i in 13:
					var x := -0.85 + float(i) / 12.0 * 1.7
					pts.append(p + Vector2(x, -0.2 + float(k) * 0.5 + sin(x * 5.0) * 0.18) * r)
				c.draw_polyline(pts, OUT, r * 0.32, true)
				c.draw_polyline(pts, col, r * 0.2, true)
		"iron":  # a shield
			_poly(c, PackedVector2Array([p + Vector2(-0.7, -0.75) * r, p + Vector2(0.7, -0.75) * r, p + Vector2(0.65, 0.1) * r, p + Vector2(0, 0.9) * r, p + Vector2(-0.65, 0.1) * r]), col)
			c.draw_line(p + Vector2(0, -0.6) * r, p + Vector2(0, 0.65) * r, col.darkened(0.3), r * 0.14)
		"stone":  # rocks
			_poly(c, PackedVector2Array([p + Vector2(-0.95, 0.7) * r, p + Vector2(-0.4, -0.5) * r, p + Vector2(0, 0.0) * r, p + Vector2(0.35, -0.8) * r, p + Vector2(0.95, 0.7) * r]), col)
			c.draw_line(p + Vector2(-0.95, 0.75) * r, p + Vector2(0.95, 0.75) * r, OUT, r * 0.12)
		"fire":  # a flame
			_poly(c, PackedVector2Array([p + Vector2(0, -1) * r, p + Vector2(0.35, -0.35) * r, p + Vector2(0.6, 0.25) * r, p + Vector2(0.35, 0.8) * r, p + Vector2(-0.35, 0.8) * r, p + Vector2(-0.6, 0.25) * r, p + Vector2(-0.25, -0.2) * r]), Color(1.0, 0.5, 0.2))
			_poly(c, PackedVector2Array([p + Vector2(0, -0.2) * r, p + Vector2(0.28, 0.4) * r, p + Vector2(0, 0.75) * r, p + Vector2(-0.28, 0.4) * r]), Color(1.0, 0.9, 0.4), 0.0)
		"blade":  # three little blades
			for k in 3:
				var a := -PI / 2.0 + TAU * float(k) / 3.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				_poly(c, PackedVector2Array([p + d * r * 0.95, p + d * r * 0.2 + n * r * 0.18, p + d * r * 0.1, p + d * r * 0.2 - n * r * 0.18]), col, 1.5)


## A treasure's picture by the slot it's worn in, in its colour.
static func gear_icon(c: CanvasItem, p: Vector2, r: float, slot: String, col: Color) -> void:
	match slot:
		"head":
			_poly(c, PackedVector2Array([p + Vector2(-0.75, 0.35) * r, p + Vector2(-0.7, -0.2) * r, p + Vector2(-0.35, -0.65) * r, p + Vector2(0.35, -0.65) * r, p + Vector2(0.7, -0.2) * r, p + Vector2(0.75, 0.35) * r]), col)
			c.draw_rect(Rect2(p + Vector2(-0.8, 0.3) * r, Vector2(1.6, 0.25) * r), col.darkened(0.25))
		"chest":
			_poly(c, PackedVector2Array([p + Vector2(-0.6, -0.65) * r, p + Vector2(-0.25, -0.75) * r, p + Vector2(0, -0.55) * r, p + Vector2(0.25, -0.75) * r, p + Vector2(0.6, -0.65) * r, p + Vector2(0.55, 0.75) * r, p + Vector2(-0.55, 0.75) * r]), col)
			c.draw_line(p + Vector2(0, -0.5) * r, p + Vector2(0, 0.7) * r, col.darkened(0.3), 2.0)
		"shoulders":
			for sx in [-1.0, 1.0]:
				_poly(c, _ellipse(p + Vector2(sx * 0.42, 0.0) * r, r * 0.42, r * 0.32), col)
		"hands":
			_poly(c, PackedVector2Array([p + Vector2(-0.45, 0.75) * r, p + Vector2(-0.5, -0.2) * r, p + Vector2(-0.3, -0.7) * r, p + Vector2(0.1, -0.75) * r, p + Vector2(0.35, -0.5) * r, p + Vector2(0.7, -0.1) * r, p + Vector2(0.45, 0.1) * r, p + Vector2(0.4, 0.75) * r]), col)
		"feet":
			_poly(c, PackedVector2Array([p + Vector2(-0.4, -0.75) * r, p + Vector2(0.15, -0.75) * r, p + Vector2(0.15, 0.25) * r, p + Vector2(0.75, 0.35) * r, p + Vector2(0.75, 0.75) * r, p + Vector2(-0.4, 0.75) * r]), col)
		"neck":
			c.draw_arc(p + Vector2(0, -0.35) * r, r * 0.5, 0.2, PI - 0.2, 16, col.darkened(0.2), 2.5)
			_poly(c, PackedVector2Array([p + Vector2(0, 0.0) * r, p + Vector2(0.32, 0.38) * r, p + Vector2(0, 0.8) * r, p + Vector2(-0.32, 0.38) * r]), col)
		"back":
			_poly(c, PackedVector2Array([p + Vector2(-0.35, -0.75) * r, p + Vector2(0.35, -0.75) * r, p + Vector2(0.7, 0.75) * r, p + Vector2(-0.7, 0.75) * r]), col)
			c.draw_line(p + Vector2(-0.35, -0.6) * r, p + Vector2(0.35, -0.6) * r, col.lightened(0.3), 2.5)
		_:
			sword(c, p, r * 0.95, col)


## A padlock (a locked tower).
static func padlock(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_arc(p + Vector2(0, -r * 0.35), r * 0.5, PI, TAU, 16, OUT, r * 0.34)
	c.draw_arc(p + Vector2(0, -r * 0.35), r * 0.5, PI, TAU, 16, Color(0.75, 0.75, 0.8), r * 0.18)
	var body := Rect2(p + Vector2(-r * 0.75, -r * 0.4), Vector2(r * 1.5, r * 1.15))
	c.draw_rect(body.grow(3.0), OUT)
	c.draw_rect(body, Color(0.95, 0.76, 0.3))
	c.draw_circle(p + Vector2(0, r * 0.1), r * 0.16, OUT)
	c.draw_line(p + Vector2(0, r * 0.1), p + Vector2(0, r * 0.42), OUT, r * 0.12)


static func house(c: CanvasItem, p: Vector2, r: float) -> void:
	_poly(c, PackedVector2Array([p + Vector2(-0.6, 0.65) * r, p + Vector2(-0.6, -0.05) * r, p + Vector2(0, -0.6) * r, p + Vector2(0.6, -0.05) * r, p + Vector2(0.6, 0.65) * r]), Color(0.95, 0.9, 0.8))
	c.draw_rect(Rect2(p + Vector2(-0.15, 0.2) * r, Vector2(0.3, 0.45) * r), Color(0.55, 0.35, 0.22))


static func check(c: CanvasItem, p: Vector2, r: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-0.6, 0) * r, p + Vector2(-0.15, 0.45) * r, p + Vector2(0.65, -0.5) * r])
	c.draw_polyline(pts, OUT, r * 0.4, true)
	c.draw_polyline(pts, Color(0.5, 0.95, 0.5), r * 0.25, true)


static func cross(c: CanvasItem, p: Vector2, r: float) -> void:
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		c.draw_line(p - d * r * 0.5, p + d * r * 0.5, OUT, r * 0.4)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		c.draw_line(p - d * r * 0.5, p + d * r * 0.5, Color(1.0, 0.45, 0.4), r * 0.25)


static func play(c: CanvasItem, p: Vector2, r: float) -> void:
	_poly(c, PackedVector2Array([p + Vector2(-0.45, -0.6) * r, p + Vector2(0.65, 0) * r, p + Vector2(-0.45, 0.6) * r]), Color(0.6, 1.0, 0.6))


static func crown(c: CanvasItem, p: Vector2, r: float) -> void:
	_poly(c, PackedVector2Array([p + Vector2(-0.8, 0.4) * r, p + Vector2(-0.8, -0.4) * r, p + Vector2(-0.4, 0.0) * r, p + Vector2(0, -0.6) * r, p + Vector2(0.4, 0.0) * r, p + Vector2(0.8, -0.4) * r, p + Vector2(0.8, 0.4) * r]), Color(1.0, 0.82, 0.3))


## The Entity, without words: a small glowing presence that floats to what to
## do next (entity.gd in the full game).
static func guide(c: CanvasItem, p: Vector2, t: float, r := 12.0) -> void:
	var col := Color(0.75, 0.85, 1.0)
	glow(c, p, r * 3.0, col, 1.2)
	c.draw_circle(p, r, Color(0.85, 0.92, 1.0))
	c.draw_circle(p, r * 0.55, Color(1, 1, 1))
	for i in 3:
		var a := t * 2.0 + TAU * float(i) / 3.0
		c.draw_circle(p + Vector2(cos(a), sin(a)) * r * 1.8, r * 0.18, Color(col, 0.8))


## A pointing hand (to say "tap here").
static func finger(c: CanvasItem, p: Vector2, r: float, t: float) -> void:
	var off := Vector2(0.6, 0.9) * r * (0.6 + 0.4 * sin(t * 6.0))
	var tip := p + off
	var d := Vector2(-0.55, -0.85).normalized()
	_poly(c, PackedVector2Array([tip, tip - d.orthogonal() * r * 0.25 - d * r * 0.2, tip - d * r * 1.3 - d.orthogonal() * r * 0.3, tip - d * r * 1.3 + d.orthogonal() * r * 0.45, tip + d.orthogonal() * r * 0.25 - d * r * 0.2]), Color(1.0, 0.92, 0.82))
