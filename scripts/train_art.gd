extends RefCounted
## The train's own look (train_view.gd draws the cars with it): its colours,
## taken from the old game's dusk (a violet-indigo night, gilt, warm
## lamplight on velvet and wood), and small drawing helpers that add to a
## ui.gd Draw.Batch: gradients, soft light, wood grain, raised panels and
## rivets. Everything is drawn in code; there are no image files.

# --- colours ----------------------------------------------------------------------

## The night outside, from the top of the sky down to the glow on the horizon.
const SKY := [Color(0.051, 0.043, 0.071), Color(0.1, 0.078, 0.17), Color(0.22, 0.14, 0.27), Color(0.46, 0.27, 0.3)]
const GROUND := Color(0.055, 0.045, 0.075)  # the land below the horizon
const FAR := Color(0.09, 0.072, 0.14)  # the towers and the far hills
const NEAR := Color(0.045, 0.036, 0.065)  # the nearer hills
const MIST := Color(0.66, 0.6, 0.82)
const MOON := Color(0.95, 0.91, 0.82)
const STAR := Color(0.925, 0.89, 0.81)  # the old game's ink
const GILT := Color(0.886, 0.71, 0.353)  # the old game's gilt
const GILT_HI := Color(1.0, 0.9, 0.64)
const GILT_LO := Color(0.42, 0.29, 0.12)
const COOL := Color(0.56, 0.69, 1.0)  # the old game's cool accent: moonlight
const LAMP := Color(1.0, 0.72, 0.4)  # lamplight
const FLAME := Color(1.0, 0.5, 0.18)  # the firebox
const SHADOW := Color(0.02, 0.015, 0.035)
const OUTLINE := Color(0.03, 0.025, 0.04)

## The cars' materials.
const WALNUT := Color(0.26, 0.15, 0.095)
const OAK := Color(0.4, 0.26, 0.15)
const PLUM := Color(0.25, 0.065, 0.12)  # your car's buttoned velvet
const CURTAIN := Color(0.33, 0.065, 0.12)
const RUNNER := Color(0.19, 0.07, 0.12)  # the carpet runner
const GREEN := Color(0.065, 0.14, 0.12)  # the store car's walls
const STEEL := Color(0.095, 0.15, 0.16)  # the engine's plates
const BOARDS := Color(0.2, 0.13, 0.085)  # the workshop's boards
const COPPER := Color(0.74, 0.42, 0.25)
const IRON := Color(0.12, 0.11, 0.13)
const LEATHER := Color(0.37, 0.22, 0.13)
const VELVET_DARK := Color(0.11, 0.05, 0.08)  # inside the wardrobe and the case


# --- helpers ----------------------------------------------------------------------

## Four corners with a colour each (an even blend between them).
static func quad(b, a: Vector2, c: Vector2, d: Vector2, e: Vector2, ca: Color, cc: Color, cd: Color, ce: Color) -> void:
	b.pts.append_array(PackedVector2Array([a, c, d, a, d, e]))
	b.cols.append_array(PackedColorArray([ca, cc, cd, ca, cd, ce]))


## A rect shading from `top` to `bottom`.
static func vgrad(b, r: Rect2, top: Color, bottom: Color) -> void:
	quad(b, r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), top, top, bottom, bottom)


## A rect shading from `left` to `right`.
static func hgrad(b, r: Rect2, left: Color, right: Color) -> void:
	quad(b, r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), left, right, right, left)


## A polygon whose colour follows its height: `col_at` gives the colour for a y.
static func shaded_poly(b, pts: PackedVector2Array, col_at: Callable) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in idx:
		b.pts.append(pts[i])
		b.cols.append(col_at.call(pts[i].y))


static var _ring := PackedVector2Array()
## How a soft light falls off from its centre: [radius, strength].
const FALL := [[0.0, 1.0], [0.18, 0.78], [0.4, 0.42], [0.65, 0.15], [1.0, 0.0]]


## A soft light: `col` at the centre (its alpha the strength), fading to
## nothing at `rad` (an ellipse). Smooth, unlike rings of dots.
static func light(b, c: Vector2, rad: Vector2, col: Color) -> void:
	if _ring.is_empty():
		for i in 28:
			_ring.append(Vector2.from_angle(TAU * i / 28.0))
	var n := _ring.size()
	for k in FALL.size() - 1:
		var r0: float = FALL[k][0]
		var r1: float = FALL[k + 1][0]
		var c0 := Color(col, col.a * FALL[k][1])
		var c1 := Color(col, col.a * FALL[k + 1][1])
		for i in n:
			var u0: Vector2 = _ring[i] * rad
			var u1: Vector2 = _ring[(i + 1) % n] * rad
			if k == 0:
				b.pts.append_array(PackedVector2Array([c, c + u0 * r1, c + u1 * r1]))
				b.cols.append_array(PackedColorArray([c0, c1, c1]))
			else:
				quad(b, c + u0 * r0, c + u1 * r0, c + u1 * r1, c + u0 * r1, c0, c0, c1, c1)


## A steady pseudo-random 0..1 for a number.
static func rnd(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 78.233) * 43758.5453, 1.0)


## Wood grain over a board: thin wavering lines along it, some darker,
## some lighter, and now and then a knot.
static func grain(b, r: Rect2, col: Color, seed: int, u: float, upright := false, knots := true) -> void:
	var across := r.size.x if upright else r.size.y
	var along := r.size.y if upright else r.size.x
	var n := int(across / (4.5 * u))
	if n < 1 or along < 4.0:
		return
	var steps := clampi(int(along / (22.0 * u)), 3, 14)
	for i in n:
		var k := (i + 0.3 + 0.4 * rnd(seed * 31 + i)) / n
		var c := Color(col.darkened(0.35), 0.4) if (i + seed) % 3 != 0 else Color(col.lightened(0.12), 0.28)
		var amp := (0.6 + 1.4 * rnd(seed + i * 7)) * u
		var ph := rnd(seed * 3 + i) * TAU
		var pts := PackedVector2Array()
		for j in steps + 1:
			var a := float(j) / steps
			var off := sin(a * 5.0 + ph) * amp
			if upright:
				pts.append(Vector2(r.position.x + across * k + off, r.position.y + along * a))
			else:
				pts.append(Vector2(r.position.x + along * a, r.position.y + across * k + off))
		b.path(pts, c, maxf(0.7, 0.8 * u))
	if knots and along > 60.0 * u and rnd(seed * 13) > 0.45:
		var p := r.position + (Vector2(across * (0.3 + 0.4 * rnd(seed + 5)), along * (0.2 + 0.6 * rnd(seed + 9))) if upright
			else Vector2(along * (0.2 + 0.6 * rnd(seed + 9)), across * (0.3 + 0.4 * rnd(seed + 5))))
		var kr := Vector2(2.2, 3.6) * u if upright else Vector2(3.6, 2.2) * u
		b.polygon(oval(p, kr + Vector2(1.2, 1.2) * u, 12), Color(col.darkened(0.3), 0.6))
		b.polygon(oval(p, kr * 0.55, 10), Color(col.darkened(0.55), 0.8))


static func oval(c: Vector2, rad: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(TAU * i / n) * rad)
	return pts


## A raised panel: lit on its top and left edges, shaded on the bottom and
## right, `w` wide (sunk instead if `raised` is false).
static func bevel(b, r: Rect2, base: Color, w: float, raised := true) -> void:
	var hi := base.lightened(0.16)
	var lo := base.darkened(0.42)
	if not raised:
		var sw := hi
		hi = lo
		lo = sw
	var a := r.position
	var e := r.end
	var ia := a + Vector2(w, w)
	var ie := e - Vector2(w, w)
	b.polygon(PackedVector2Array([a, Vector2(e.x, a.y), Vector2(ie.x, ia.y), ia]), hi)
	b.polygon(PackedVector2Array([a, ia, Vector2(ia.x, ie.y), Vector2(a.x, e.y)]), hi.darkened(0.08))
	b.polygon(PackedVector2Array([Vector2(a.x, e.y), Vector2(ia.x, ie.y), ie, e]), lo)
	b.polygon(PackedVector2Array([Vector2(e.x, a.y), e, ie, Vector2(ie.x, ia.y)]), lo.lightened(0.06))
	b.rect(Rect2(ia, ie - ia), base)


## A brass rivet with its shadow and a glint.
static func rivet(b, p: Vector2, rad: float, col := GILT) -> void:
	var n := 8 if rad < 2.5 else 12
	b.circle(p + Vector2(0.35, 0.5) * rad, rad * 1.15, Color(0, 0, 0, 0.35), n)
	b.circle(p, rad, col.darkened(0.4), n)
	b.circle(p - Vector2(0.18, 0.18) * rad, rad * 0.72, col.darkened(0.05), n)
	b.circle(p - Vector2(0.35, 0.35) * rad, rad * 0.32, col.lightened(0.45), 5)


static func rivets(b, from: Vector2, to: Vector2, gap: float, rad: float, col := GILT) -> void:
	var n := int(from.distance_to(to) / gap)
	for i in n + 1:
		rivet(b, from.lerp(to, float(i) / maxf(n, 1)), rad, col)


## A brass (or copper) bar lying along x: lit on top, dark below, a bright line.
static func bar(b, r: Rect2, col := GILT) -> void:
	vgrad(b, r, col.lightened(0.12), col.darkened(0.45))
	b.rect(Rect2(r.position.x, r.position.y + r.size.y * 0.18, r.size.x, maxf(0.8, r.size.y * 0.14)), Color(col.lightened(0.5), 0.75))
	b.rect(Rect2(r.position.x, r.end.y - maxf(0.8, r.size.y * 0.1), r.size.x, maxf(0.8, r.size.y * 0.1)), Color(0, 0, 0, 0.35))


## An upright brass (or copper) bar: lit on the left.
static func post(b, r: Rect2, col := GILT) -> void:
	hgrad(b, r, col.lightened(0.1), col.darkened(0.45))
	b.rect(Rect2(r.position.x + r.size.x * 0.2, r.position.y, maxf(0.8, r.size.x * 0.14), r.size.y), Color(col.lightened(0.5), 0.7))


## A round pipe from a to b: a dark underside, its colour, and a lit stripe.
static func pipe(b, a: Vector2, e: Vector2, w: float, col: Color) -> void:
	var n := (e - a).orthogonal().normalized()
	if n.y > 0.0 or (n.y == 0.0 and n.x > 0.0):
		n = -n  # the lit side faces up (or left)
	b.line(a, e, OUTLINE, w + 2.0)
	b.line(a, e, col.darkened(0.4), w)
	b.line(a + n * w * 0.1, e + n * w * 0.1, col, w * 0.7)
	b.line(a + n * w * 0.26, e + n * w * 0.26, Color(col.lightened(0.5), 0.8), maxf(0.8, w * 0.16))


## A gilt keyline moulding around a rect: a dark line, then a lit one inside.
static func moulding(b, r: Rect2, u: float, col := GILT, alpha := 0.55) -> void:
	var w := maxf(0.8, 1.1 * u)
	_frame(b, r, w, Color(0, 0, 0, 0.45))
	_frame(b, r.grow(-w), w, Color(col, alpha))


static func _frame(b, r: Rect2, w: float, col: Color) -> void:
	b.rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	b.rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), col)
	b.rect(Rect2(r.position + Vector2(0, w), Vector2(w, r.size.y - w * 2.0)), col)
	b.rect(Rect2(Vector2(r.end.x - w, r.position.y + w), Vector2(w, r.size.y - w * 2.0)), col)


## Polygons clipped to a window's glass (the view outside stays inside it).
static func clipped(b, pts: PackedVector2Array, glass: PackedVector2Array, box: Rect2, col: Color) -> void:
	if not _bounds(pts).intersects(box):
		return
	for p in Geometry2D.intersect_polygons(pts, glass):
		b.polygon(p, col)


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## A glass bottle standing at `foot`: dark glass, what it holds, a cork,
## and the light on its shoulder.
static func bottle(b, foot: Vector2, w: float, h: float, col: Color, u: float) -> void:
	var body := Rect2(foot.x - w * 0.5, foot.y - h * 0.7, w, h * 0.7)
	var neck := Rect2(foot.x - w * 0.18, foot.y - h, w * 0.36, h * 0.32)
	b.rect(body.grow(1.0 * u), OUTLINE)
	b.rect(neck.grow(1.0 * u), OUTLINE)
	b.rect(body, Color(col.darkened(0.7), 0.95))
	b.rect(neck, Color(col.darkened(0.6), 0.9))
	vgrad(b, Rect2(body.position.x, body.position.y + body.size.y * 0.35, body.size.x, body.size.y * 0.65), col.darkened(0.1), col.darkened(0.45))
	b.rect(Rect2(neck.position.x, neck.position.y - 2.5 * u, neck.size.x, 3.0 * u), OAK.lightened(0.15))
	b.rect(Rect2(body.position.x + w * 0.15, body.position.y + 1.0 * u, maxf(0.8, w * 0.14), body.size.y - 2.0 * u), Color(1, 1, 1, 0.35))
	b.circle(body.position + Vector2(w * 0.25, 1.5 * u), maxf(0.8, w * 0.12), Color(1, 1, 1, 0.6), 6)
