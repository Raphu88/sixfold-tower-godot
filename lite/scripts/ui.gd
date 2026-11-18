extends RefCounted
## LITE's interface look, after the full game's (its ui.gd): the same glassy
## buttons in a dark bezel with a gilt ring and a gloss, the same gilt and
## parchment colours, and a book-like panel for the climber screen. The
## button functions are copies of the full game's (button_into, ring_into,
## fan_into, glow_into), drawn into a draw_util.gd Batch.

const Draw := preload("res://scripts/draw_util.gd")

static var GILT := Color(0.886, 0.71, 0.353)
static var GILT_HI := Color(0.97, 0.85, 0.58)
static var TEXT := Color(0.925, 0.89, 0.81)
const OUTLINE := Color(0.03, 0.025, 0.04)
## The book's page and its edge (the full game's Climber's Book).
static var PAGE_TOP := Color(0.2, 0.16, 0.13)
static var PAGE_BOTTOM := Color(0.12, 0.095, 0.08)
static var LEATHER := Color(0.36, 0.22, 0.12)


## A glassy button (the full game's look). `col` lights its ring when it's
## ready; `fill` (0 to 1) fills a ring around it, like a recharge.
static func button(c: CanvasItem, at: Vector2, r: float, col: Color, pressed := false, ready := false, fill := 0.0) -> void:
	var b := Draw.Batch.new()
	button_into(b, at, r, col, pressed, ready, fill)
	b.flush(c)


static func button_into(b, c: Vector2, r: float, col: Color, pressed := false, ready := false, fill := 0.0, quiet := false) -> void:
	if ready:
		glow_into(b, c, r * 1.4, col, 0.9)
	ring_into(b, c, r + 0.4, 3.4, Color(OUTLINE, 0.5))
	fan_into(b, c, r - 1.0, Color(0.07, 0.06, 0.1, 0.42 if not pressed else 0.6), Color(0.03, 0.025, 0.045, 0.68 if not pressed else 0.8), 32)
	var gilt := Color(GILT_HI, 0.8) if pressed else Color(GILT, 0.5 if quiet else 0.62)
	ring_into(b, c, r - 0.8, 1.5, gilt)
	ring_into(b, c, r - 0.6, 1.0, Color(GILT_HI, 0.35 if quiet else 0.5), PI * 1.1, PI * 1.9)
	ring_into(b, c, r - 3.4, 1.0, Color(OUTLINE, 0.45))
	if ready:
		ring_into(b, c, r - 0.8, 2.6, Color(col, 0.95))
	if fill > 0.0:
		ring_into(b, c, r - 5.6, 3.6, Color(col.darkened(0.6), 0.5))
		ring_into(b, c, r - 5.6, 3.6, Color(col, 0.9), -PI / 2.0, -PI / 2.0 + TAU * clampf(fill, 0.0, 1.0))
	# The gloss: a pale crescent along the top of the glass.
	ring_into(b, c + Vector2(0, r * 0.06), r - 7.0, 2.0, Color(1, 1, 1, 0.1), PI * 1.15, PI * 1.85)
	if pressed:
		b.dot(c, r - 3.0, Color(col, 0.16))


static func ring_into(b, c: Vector2, r: float, w: float, col: Color, from := 0.0, to := TAU, n := 0) -> void:
	if n <= 0:
		n = clampi(int(r * absf(to - from) / 3.5), 6, 72)
	var r0 := maxf(r - w * 0.5, 0.0)
	var r1 := r + w * 0.5
	var p := PackedVector2Array()
	p.resize(n * 6)
	var d0 := Vector2.from_angle(from)
	var pi0 := c + d0 * r0
	var po0 := c + d0 * r1
	for i in n:
		var d := Vector2.from_angle(lerpf(from, to, float(i + 1) / n))
		var pi1 := c + d * r0
		var po1 := c + d * r1
		var k := i * 6
		p[k] = pi0
		p[k + 1] = po0
		p[k + 2] = po1
		p[k + 3] = pi0
		p[k + 4] = po1
		p[k + 5] = pi1
		pi0 = pi1
		po0 = po1
	b.pts.append_array(p)
	b._color(col, n * 6)


static func fan_into(b, c: Vector2, r: float, inner: Color, outer: Color, n := 40) -> void:
	var p := PackedVector2Array()
	var q := PackedColorArray()
	p.resize(n * 3)
	q.resize(n * 3)
	var prev := c + Vector2(r, 0)
	for i in n:
		var nxt := c + Vector2.from_angle(TAU * float(i + 1) / n) * r
		p[i * 3] = c
		p[i * 3 + 1] = prev
		p[i * 3 + 2] = nxt
		q[i * 3] = inner
		q[i * 3 + 1] = outer
		q[i * 3 + 2] = outer
		prev = nxt
	b.pts.append_array(p)
	b.cols.append_array(q)


static func glow_into(b, c: Vector2, r: float, col: Color, strength := 1.0) -> void:
	for i in 5:
		var k := 1.0 - i / 5.0
		b.dot(c, r * (0.45 + 0.55 * k), Color(col, 0.07 * strength))


## A page of the climber's book: a dark parchment panel in a leather edge
## with a double gilt rule, like the full game's Climber's Book.
static func panel(c: CanvasItem, r: Rect2) -> void:
	c.draw_rect(r.grow(10.0), Color(0, 0, 0, 0.45))
	c.draw_rect(r.grow(6.0), LEATHER.darkened(0.3))
	c.draw_rect(r.grow(4.0), LEATHER)
	var steps := 12
	for i in steps:
		var y0 := r.position.y + r.size.y * float(i) / steps
		c.draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / steps + 1.0), PAGE_TOP.lerp(PAGE_BOTTOM, float(i) / steps))
	c.draw_rect(r.grow(-6.0), Color(GILT, 0.55), false, 2.0)
	c.draw_rect(r.grow(-11.0), Color(GILT, 0.25), false, 1.0)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		c.draw_rect(Rect2(corner - Vector2(5, 5), Vector2(10, 10)), GILT.darkened(0.15))


## A tab of the book (the full game's coloured ribbon tabs), with a picture
## drawn by the caller.
static func tab(c: CanvasItem, r: Rect2, col: Color, on: bool) -> void:
	var lift := -6.0 if on else 0.0
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	c.draw_rect(rr.grow(3.0), OUTLINE)
	c.draw_rect(rr, col.lightened(0.15) if on else col.darkened(0.25))
	c.draw_rect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.35)), Color(1, 1, 1, 0.12))
	if on:
		c.draw_rect(rr.grow(3.0), GILT_HI, false, 3.0)
