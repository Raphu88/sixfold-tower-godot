extends RefCounted
## Six Towers LITE's drawings, all in code: the climber with marks glowing
## on its body, the monsters, the six beasts and the picture icons that stand
## in for words. Each function draws onto a CanvasItem `c` around `pos`.

const Data := preload("res://scripts/data.gd")

const OUT := Color(0.06, 0.05, 0.08)
## The climber's colours.
const CLOAK := Color(0.28, 0.55, 0.62)
const SKIN := Color(0.93, 0.8, 0.66)
const TUNIC := Color(0.42, 0.34, 0.27)
const HAIR := Color(0.36, 0.22, 0.14)
const BOOT := Color(0.24, 0.17, 0.13)

## Where each body part's mark glows on the climber, in its own units
## (the figure is about 60 tall, its feet at 0).
const PART_SPOT := {
	"brow": Vector2(0, -50),
	"throat": Vector2(0, -36),
	"heart": Vector2(-5, -27),
	"hand": Vector2(17, -17),
	"legs": Vector2(-6, -5),
	"back": Vector2(-13, -31),
}


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


# --- the climber ---------------------------------------------------------------

## The climber. `marks` is body part -> colour (glowing dots on the body);
## `stars` is body part -> stars (the glow grows with them).
static func climber(c: CanvasItem, pos: Vector2, s: float, flip := false, marks := {}, stars := {}, t := 0.0, walk := 0.0) -> void:
	var bob := sin(walk * 10.0) * 2.0 if walk > 0.0 else 0.0
	_begin(c, pos, s, flip)
	# shadow
	c.draw_colored_polygon(_ellipse(Vector2(0, 2), 16, 5), Color(0, 0, 0, 0.3))
	# legs and boots
	var step := sin(walk * 10.0) * 4.0 if walk > 0.0 else 0.0
	_disc(c, Vector2(-6 + step, -3), 5, BOOT)
	_disc(c, Vector2(6 - step, -3), 5, BOOT)
	# cloak (body)
	_poly(c, PackedVector2Array([Vector2(-15, -6 + bob), Vector2(15, -6 + bob), Vector2(10, -38 + bob), Vector2(-10, -38 + bob)]), CLOAK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -8 + bob), Vector2(6, -8 + bob), Vector2(4, -34 + bob), Vector2(-4, -34 + bob)]), TUNIC)
	# arm and hand
	_disc(c, Vector2(17, -17 + bob), 5, SKIN)
	# head
	_disc(c, Vector2(0, -47 + bob), 12, SKIN)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-12, -48 + bob), Vector2(-10, -58 + bob), Vector2(0, -61 + bob), Vector2(10, -58 + bob), Vector2(12, -50 + bob), Vector2(5, -55 + bob), Vector2(-5, -54 + bob)]), HAIR)
	# eyes (blink now and then)
	var blink := fmod(t, 3.7) < 0.12
	for x in [-4.0, 4.5]:
		if blink:
			c.draw_line(Vector2(x - 2, -46 + bob), Vector2(x + 2, -46 + bob), OUT, 1.5)
		else:
			c.draw_circle(Vector2(x, -46 + bob), 2.0, OUT)
	# marks
	for part in marks:
		var p: Vector2 = PART_SPOT.get(part, Vector2.ZERO) + Vector2(0, bob)
		var col: Color = marks[part]
		var st := int(stars.get(part, 1))
		var pulse := 0.75 + 0.25 * sin(t * 3.0 + p.x)
		glow(c, p, 6.0 + 2.5 * st, col, pulse * (0.5 + 0.2 * st))
		_mark_sign(c, p, 3.0 + 0.6 * st, col.lightened(0.3))
	_end(c)


## A mark's sign: a little four-pointed star.
static func _mark_sign(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		var rr := r * (1.0 if i % 2 == 0 else 0.4)
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)


# --- monsters ------------------------------------------------------------------

## A monster in its tower's colour. `flash` (0 to 1) turns it red-white before
## it attacks; `hurt` (0 to 1) flashes it white when struck.
static func monster(c: CanvasItem, pos: Vector2, look: String, col: Color, t: float, flash := 0.0, hurt := 0.0, flip := false, s := 1.0) -> void:
	var body := col
	if flash > 0.0:
		body = body.lerp(Color(1.0, 0.3, 0.25), clampf(flash, 0.0, 1.0) * (0.6 + 0.4 * sin(t * 30.0)))
	if hurt > 0.0:
		body = body.lerp(Color.WHITE, hurt)
	var dark := body.darkened(0.35)
	var hop := absf(sin(t * 6.0)) * 3.0
	_begin(c, pos, s, flip)
	c.draw_colored_polygon(_ellipse(Vector2(0, 2), 16, 5), Color(0, 0, 0, 0.3))
	match look:
		"blob":
			_poly(c, _ellipse(Vector2(0, -12 - hop * 0.5), 18 + hop * 0.6, 14 - hop * 0.4), body)
		"winged":
			var flap := sin(t * 14.0) * 8.0
			_poly(c, PackedVector2Array([Vector2(-6, -22), Vector2(-30, -32 - flap), Vector2(-22, -14)]), dark)
			_poly(c, PackedVector2Array([Vector2(6, -22), Vector2(30, -32 - flap), Vector2(22, -14)]), dark)
			_disc(c, Vector2(0, -20 - hop), 12, body)
		"hooded":
			_poly(c, PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(8, -30), Vector2(0, -38), Vector2(-8, -30)]), body)
			c.draw_circle(Vector2(0, -24), 7, dark.darkened(0.4))
		"finned":
			_poly(c, PackedVector2Array([Vector2(-4, -24), Vector2(4, -42), Vector2(10, -22)]), dark)
			_poly(c, _ellipse(Vector2(0, -14 - hop * 0.5), 20, 12), body)
		"armored":
			_disc(c, Vector2(-7, -3), 5, dark)
			_disc(c, Vector2(7, -3), 5, dark)
			_poly(c, PackedVector2Array([Vector2(-14, -6), Vector2(14, -6), Vector2(12, -30), Vector2(-12, -30)]), body)
			_disc(c, Vector2(0, -36), 10, body.lightened(0.15))
			c.draw_line(Vector2(-7, -37), Vector2(7, -37), OUT, 3.0)
			c.draw_line(Vector2(0, -46), Vector2(0, -54), Color(0.8, 0.2, 0.18), 4.0)
		"flame":
			var w := sin(t * 9.0) * 3.0
			_poly(c, PackedVector2Array([Vector2(-14, -8), Vector2(-10, -26), Vector2(-4 + w, -42), Vector2(2, -30), Vector2(8 - w, -44), Vector2(14, -22), Vector2(14, -8), Vector2(0, -2)]), body)
		"spiky":
			var pts := PackedVector2Array()
			for i in 14:
				var a := TAU * float(i) / 14.0
				var r := 18.0 if i % 2 == 0 else 11.0
				pts.append(Vector2(cos(a) * r, -14 - hop * 0.5 + sin(a) * r * 0.8))
			_poly(c, pts, body)
		_:
			_disc(c, Vector2(0, -14), 14, body)
	# eyes: every monster looks at you
	var ey: float = {"blob": -14.0, "winged": -21.0, "hooded": -25.0, "finned": -15.0, "armored": -38.0, "flame": -20.0, "spiky": -15.0}.get(look, -14.0) - hop * 0.5
	for x in [-5.0, 5.0]:
		c.draw_circle(Vector2(x, ey), 4.0, Color.WHITE)
		c.draw_circle(Vector2(x + 1.5, ey), 2.0, OUT)
	_end(c)


# --- beasts ----------------------------------------------------------------------

## The tower's beast, big. Each is drawn after the full game's beast: the
## Gryphon's wings and beak, the Kraken's tentacles, the Wyvern's wings and
## horns, the Manticore's mane and stinger, the Firebird's flames and the
## Chimera's three heads.
static func beast(c: CanvasItem, pos: Vector2, tower: String, t: float, flash := 0.0, hurt := 0.0, flip := false, s := 1.0) -> void:
	var col := Data.tower_color(tower)
	if flash > 0.0:
		col = col.lerp(Color(1.0, 0.3, 0.25), clampf(flash, 0.0, 1.0) * (0.6 + 0.4 * sin(t * 30.0)))
	if hurt > 0.0:
		col = col.lerp(Color.WHITE, hurt)
	var dark := col.darkened(0.4)
	var gold := Color(0.95, 0.75, 0.3)
	var breathe := sin(t * 2.5) * 2.0
	_begin(c, pos, s, flip)
	c.draw_colored_polygon(_ellipse(Vector2(0, 4), 44, 12), Color(0, 0, 0, 0.3))
	var eye_at := Vector2(10, -62)
	match tower:
		"gryphon":
			var flap := sin(t * 5.0) * 14.0
			_poly(c, PackedVector2Array([Vector2(-10, -50), Vector2(-70, -90 - flap), Vector2(-60, -50), Vector2(-40, -30)]), dark)
			_poly(c, PackedVector2Array([Vector2(10, -50), Vector2(70, -90 - flap), Vector2(60, -50), Vector2(40, -30)]), dark)
			_poly(c, _ellipse(Vector2(0, -32 + breathe), 30, 26), gold.darkened(0.15))
			_disc(c, Vector2(4, -64 + breathe), 18, col.lightened(0.3))
			_poly(c, PackedVector2Array([Vector2(16, -68 + breathe), Vector2(36, -60 + breathe), Vector2(18, -56 + breathe)]), gold)
			eye_at = Vector2(8, -68 + breathe)
		"kraken":
			for i in 6:
				var x := -36.0 + 14.4 * float(i)
				var pts := PackedVector2Array()
				for k in 6:
					var y := -20.0 + float(k) * 6.0
					pts.append(Vector2(x + sin(t * 3.0 + float(i) + float(k) * 0.8) * 6.0, y))
				c.draw_polyline(pts, OUT, 13.0, true)
				c.draw_polyline(pts, dark, 9.0, true)
			_poly(c, _ellipse(Vector2(0, -50 + breathe), 36, 40), col)
			eye_at = Vector2(0, -50 + breathe)
		"wyvern":
			var flap := sin(t * 4.0) * 10.0
			_poly(c, PackedVector2Array([Vector2(-14, -46), Vector2(-76, -84 - flap), Vector2(-66, -40), Vector2(-34, -26)]), Color(0.6, 0.2, 0.15))
			_poly(c, PackedVector2Array([Vector2(14, -46), Vector2(76, -84 - flap), Vector2(66, -40), Vector2(34, -26)]), Color(0.6, 0.2, 0.15))
			_poly(c, _ellipse(Vector2(0, -28 + breathe), 30, 24), col)
			_poly(c, PackedVector2Array([Vector2(-8, -40), Vector2(8, -40), Vector2(14, -66), Vector2(2, -70)]), col)
			_disc(c, Vector2(8, -74 + breathe), 15, col.lightened(0.1))
			_poly(c, PackedVector2Array([Vector2(0, -84 + breathe), Vector2(-6, -102 + breathe), Vector2(6, -86 + breathe)]), gold)
			_poly(c, PackedVector2Array([Vector2(12, -86 + breathe), Vector2(16, -104 + breathe), Vector2(18, -86 + breathe)]), gold)
			eye_at = Vector2(10, -76 + breathe)
		"manticore":
			var tail := PackedVector2Array()
			for k in 8:
				var a := float(k) / 7.0
				tail.append(Vector2(-30 - a * 26.0, -20 - a * 60.0 + sin(a * 3.0) * 10.0) + Vector2(sin(t * 2.0) * a * 6.0, 0))
			c.draw_polyline(tail, OUT, 12.0, true)
			c.draw_polyline(tail, dark, 8.0, true)
			_poly(c, PackedVector2Array([tail[7] + Vector2(-8, 0), tail[7] + Vector2(10, -4), tail[7] + Vector2(4, 14)]), Color(0.3, 0.2, 0.15))
			_poly(c, _ellipse(Vector2(0, -26 + breathe), 36, 22), col)
			var mane := PackedVector2Array()
			for i in 18:
				var a := TAU * float(i) / 18.0
				var r := 30.0 if i % 2 == 0 else 22.0
				mane.append(Vector2(14, -58 + breathe) + Vector2(cos(a), sin(a)) * r)
			_poly(c, mane, Color(0.6, 0.35, 0.18))
			_disc(c, Vector2(14, -58 + breathe), 17, col.lightened(0.2))
			eye_at = Vector2(14, -60 + breathe)
		"firebird":
			var flap := sin(t * 6.0) * 16.0
			for side in [-1.0, 1.0]:
				_poly(c, PackedVector2Array([Vector2(side * 10, -46), Vector2(side * 74, -96 - flap), Vector2(side * 56, -60), Vector2(side * 70, -50 - flap * 0.5), Vector2(side * 34, -30)]), Color(1.0, 0.75, 0.25))
			for k in 3:
				var x := -10.0 + float(k) * 10.0
				_poly(c, PackedVector2Array([Vector2(x - 6, -16), Vector2(x + sin(t * 8.0 + float(k)) * 6.0, 10), Vector2(x + 6, -16)]), Color(1.0, 0.4, 0.2), 1.0)
			_poly(c, _ellipse(Vector2(0, -36 + breathe), 22, 26), col)
			_disc(c, Vector2(6, -66 + breathe), 14, col.lightened(0.2))
			_poly(c, PackedVector2Array([Vector2(16, -70 + breathe), Vector2(32, -64 + breathe), Vector2(16, -60 + breathe)]), gold)
			for k in 3:
				_poly(c, PackedVector2Array([Vector2(-4 + float(k) * 5, -78 + breathe), Vector2(-8 + float(k) * 6 + sin(t * 7.0 + float(k)) * 3, -98 + breathe), Vector2(float(k) * 5, -78 + breathe)]), Color(1.0, 0.85, 0.3), 1.0)
			eye_at = Vector2(8, -68 + breathe)
		"chimera":
			var tail := PackedVector2Array()
			for k in 8:
				var a := float(k) / 7.0
				tail.append(Vector2(-34 - a * 30.0, -24 - a * 40.0 + sin(t * 3.0 + a * 5.0) * 6.0))
			c.draw_polyline(tail, OUT, 12.0, true)
			c.draw_polyline(tail, Color(0.35, 0.6, 0.3), 8.0, true)
			_disc(c, tail[7], 8, Color(0.4, 0.7, 0.35))
			_poly(c, _ellipse(Vector2(0, -28 + breathe), 38, 24), col)
			# the goat
			_disc(c, Vector2(-12, -60 + breathe), 12, Color(0.85, 0.82, 0.72))
			c.draw_arc(Vector2(-18, -70 + breathe), 10, PI, TAU, 10, Color(0.5, 0.42, 0.3), 5.0)
			# the lion
			var mane := PackedVector2Array()
			for i in 16:
				var a := TAU * float(i) / 16.0
				var r := 25.0 if i % 2 == 0 else 18.0
				mane.append(Vector2(18, -56 + breathe) + Vector2(cos(a), sin(a)) * r)
			_poly(c, mane, Color(0.62, 0.4, 0.2))
			_disc(c, Vector2(18, -56 + breathe), 14, Color(0.85, 0.65, 0.35))
			eye_at = Vector2(18, -58 + breathe)
	# eyes
	for x in [-6.0, 6.0]:
		c.draw_circle(eye_at + Vector2(x, 0), 5.0, Color(1.0, 0.92, 0.5))
		c.draw_circle(eye_at + Vector2(x + 1.5, 0), 2.4, OUT)
	_end(c)


## A beast's face for the home screen's tower cards (the beast, small).
static func beast_badge(c: CanvasItem, pos: Vector2, tower: String, t: float, s := 0.5) -> void:
	beast(c, pos + Vector2(0, 30) * s, tower, t, 0.0, 0.0, false, s)


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
