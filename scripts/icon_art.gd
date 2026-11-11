extends RefCounted
## The shared look of the item and gear icons (items.gd, gear.gd, vessel.gd),
## so they read as one hand-drawn set inside the menus' violet-and-gilt slots.
##
## --- THE ICON STYLE ----------------------------------------------------------------
## Shape: slim and colourful. An icon keeps some air round it in its cell
##   (unit(s) draws the -10..10 grid a little inside the cell).
## Light: one light, from the top-left (LIGHT). Shapes are shaded with smooth
##   gradients (lit at the top-left, falling to a violet-leaning shadow at
##   the lower right), a soft shine on the edges that face the light, a faint
##   cool bounce light along the edges in shadow (so a shape reads round,
##   not flat), and a sharp highlight only on glass, gems and polished metal.
##   A soft contact shadow under the icon sets it down in its slot (ground()).
## Outline: a light, crisp line of dark violet ink (INK), one width for the
##   whole icon scaled to its size (ol(s)), on a faint feather that smooths
##   its edge. Details inside a shape (stitches, grain, rivets) have none.
## Colour: saturated colours tell items apart; shadows lean toward the
##   night's violet (SHADOW_TINT) so the icons sit in the menus' palette;
##   gold is the menus' gilt; steel takes a cool shine, gold a warm one.
## Rarity: finer gear glows softly behind its icon in its rarity's colour,
##   brighter the rarer it is (rarity_glow()); Common has none. A Regarded
##   piece (a beast's own) also throws gold rays and two glints.
## Size: s is half the icon's width. detail(s) says how much fine detail
##   (grain, stitches, rivets) the size can carry: the HUD (~21 px) keeps to
##   clear shapes, a card adds the rest.
## Cost: an icon's triangles are built once per look and size (cached()),
##   then copied into place on every draw, so drawing one is cheap.
## -----------------------------------------------------------------------------------

const Draw := preload("res://scripts/draw_util.gd")

const INK := Color(0.08, 0.055, 0.1)  # the outline: a warm violet-black
const FEATHER := 0.3  # the faint ring under the outline
const LIGHT := Vector2(-0.6, -0.8)  # where the light comes from (Draw.LIGHT_DIR)
const SHADOW_TINT := Color(0.17, 0.1, 0.27)  # mixed into every shadow
const COOL_SHINE := Color(0.9, 0.95, 1.0)
const WARM_SHINE := Color(1.0, 0.95, 0.76)
const ROOM := 0.9  # how much of its cell an icon's grid fills

## Materials' own colours.
const STEEL := Color(0.76, 0.79, 0.87)
const IRON := Color(0.52, 0.53, 0.6)
const GOLD := Color(0.886, 0.71, 0.353)  # the menus' gilt (ui.gd GILT)
const BRASS := Color(0.86, 0.64, 0.3)
const LEATHER := Color(0.5, 0.32, 0.2)
const WOOD := Color(0.6, 0.4, 0.23)
const CORK := Color(0.7, 0.51, 0.32)
const PAPER := Color(0.93, 0.86, 0.68)
const GLASS := Color(0.22, 0.2, 0.31)  # a bottle's dark glass
const SKIN := Color(0.93, 0.8, 0.66)

## Shading options for shape().
const NO_RIM := 1  # no shine along the lit edges
const FLAT := 2  # one tone (no gradient)
const NO_OUTLINE := 4
const THIN := 8  # a thinner outline (a part laid over another)

## How strongly each rarity glows behind an icon.
const RARITY_GLOW := {"common": 0.0, "fine": 0.5, "rare": 0.68, "storied": 0.85, "regarded": 1.0}
## The bounce light on a shape's shadowed edges: a cool violet-white.
const BOUNCE := Color(0.72, 0.7, 0.98)


## The size of one step on an icon's -10..10 grid, for half-size `s`.
static func unit(s: float) -> float:
	return s / 10.0 * ROOM


## The outline width for an icon of half-size `s`.
static func ol(s: float) -> float:
	return clampf(s * 0.068, 0.75, 1.7)


## How much fine detail an icon this size carries: 0 small (the HUD),
## 1 a menu slot, 2 a card or the details panel.
static func detail(s: float) -> int:
	return 0 if s < 13.0 else (1 if s < 26.0 else 2)


## A colour's ramp: [deep, shade, base, lit, shine] for a material kind
## ("metal", "gold", "glass", "leather", "cloth", "wood", "gem" or "").
static func ramp(col: Color, kind := "") -> Array:
	var cool := kind in ["metal", "glass"]
	var shade := col.darkened(0.32).lerp(SHADOW_TINT, 0.22 if cool else 0.14)
	var deep := col.darkened(0.56).lerp(SHADOW_TINT, 0.3 if cool else 0.24)
	var lit := col.lightened(0.2 if kind in ["metal", "gold", "gem"] else 0.13)
	var shine: Color
	match kind:
		"metal", "glass":
			shine = Color(COOL_SHINE, 0.8)
		"gold":
			shine = Color(WARM_SHINE, 0.85)
		"gem":
			shine = Color(1, 1, 1, 0.8)
		"leather", "wood":
			shine = Color(col.lightened(0.4), 0.45)
		"cloth":
			shine = Color(col.lightened(0.32), 0.32)
		_:
			shine = Color(col.lightened(0.42), 0.5)
	return [deep, shade, col, lit, shine]


## The side of a line from `a` to `e` that faces the light (a unit vector).
static func lit_side(a: Vector2, e: Vector2) -> Vector2:
	var side := (e - a).normalized().orthogonal()
	return side if side.dot(LIGHT) > 0.0 else -side


## An ink outline round `pts` (closed), on its feather.
static func outline(b, pts: PackedVector2Array, s: float, w := -1.0) -> void:
	var o := ol(s) if w < 0.0 else w
	_ring(b, pts, Color(INK, FEATHER), o * 2.0 + 1.1)
	_ring(b, pts, INK, o * 2.0)


## A closed line round `pts`, `w` wide, with round joints (smooth corners).
static func _ring(b, pts: PackedVector2Array, col: Color, w: float) -> void:
	var n := pts.size()
	for i in n:
		b.line(pts[i], pts[(i + 1) % n], col, w)
	if w > 1.2:
		var pc := clampi(int(w * 1.5) + 6, 6, 14)
		for p in pts:
			b.circle(p, w * 0.5, col, pc)


## A polygon filled with a smooth gradient along the light: `lit` at its
## top-left end, `base` through the middle and `shade` at its lower right.
static func grad(b, pts: PackedVector2Array, lit: Color, base: Color, shade: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var l := -LIGHT.normalized()
	var mn := INF
	var mx := -INF
	for p in pts:
		var d := p.dot(l)
		mn = minf(mn, d)
		mx = maxf(mx, d)
	var span := maxf(mx - mn, 0.001)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var t := (pts[i].dot(l) - mn) / span
		cols[i] = lit.lerp(base, t / 0.45) if t < 0.45 else base.lerp(shade, (t - 0.45) / 0.55)
	for i in idx:
		b.pts.append(pts[i])
		b.cols.append(cols[i])


## A filled, outlined shape in `col`, shaded the icon way: a smooth gradient
## along the light and a soft shine on the edges facing it. `flags`:
## NO_RIM, FLAT, NO_OUTLINE, THIN.
static func shape(b, pts: PackedVector2Array, col: Color, s: float, kind := "", flags := 0) -> void:
	if pts.size() < 3:
		return
	if not (flags & NO_OUTLINE):
		outline(b, pts, s, ol(s) * (0.7 if flags & THIN else 1.0))
	var r := ramp(col, kind)
	if flags & FLAT:
		b.polygon(pts, col)
	else:
		grad(b, pts, r[3], col, r[1])
	if not (flags & NO_RIM):
		rim(b, pts, s, r[4])
		if s >= 13.0:
			bounce(b, pts, s, kind)
			if kind in ["metal", "gold"]:
				sheen(b, pts, s, r[4])
	if s >= 26.0 and not (flags & THIN) and kind == "leather":
		seam(b, pts, s, r[3])


## A faint cool light along the edges of `pts` that face away from the
## light (light thrown back from below): it rounds a shape off.
static func bounce(b, pts: PackedVector2Array, s: float, kind := "") -> void:
	var w := maxf(0.6, s * 0.05)
	var l := -LIGHT.normalized()
	var n := pts.size()
	var cw := _clockwise(pts)
	var a0 := 0.42 if kind in ["metal", "gold", "glass", "gem"] else 0.28
	for i in n:
		var a := pts[i]
		var e := pts[(i + 1) % n]
		if a.distance_squared_to(e) < 0.01:
			continue
		var side := (e - a).normalized().orthogonal()
		if not cw:
			side = -side
		var facing := side.dot(l)
		if facing < 0.35:
			continue
		var inset := -side * (w * 0.5 + 0.35)
		b.line(a + inset, e + inset, Color(BOUNCE, a0 * clampf((facing - 0.35) * 2.0, 0.0, 1.0)), w)


## Polished metal's sheen: a soft pale band across `pts`, square to the
## light, a little above its middle (cut to the shape).
static func sheen(b, pts: PackedVector2Array, s: float, col: Color) -> void:
	var l := -LIGHT.normalized()
	var mn := INF
	var mx := -INF
	for p in pts:
		mn = minf(mn, p.dot(l))
		mx = maxf(mx, p.dot(l))
	var span := mx - mn
	if span < 3.0:
		return
	var across := l.orthogonal() * 1e3
	var d0 := mn + span * 0.26
	var d1 := mn + span * 0.4
	var band := PackedVector2Array([l * d0 - across, l * d0 + across, l * d1 + across, l * d1 - across])
	for part in Geometry2D.intersect_polygons(pts, band):
		var idx := Geometry2D.triangulate_polygon(part)
		for i in idx:
			var t := (part[i].dot(l) - d0) / (d1 - d0)
			b.pts.append(part[i])
			b.cols.append(Color(col, col.a * 0.32 * (1.0 - absf(t * 2.0 - 1.0))))


## Leather's seam: a row of pale stitches just inside the edge (card size).
static func seam(b, pts: PackedVector2Array, s: float, col: Color) -> void:
	var inner := Geometry2D.offset_polygon(pts, -maxf(1.4, s * 0.075))
	if inner.is_empty():
		return
	var ring: PackedVector2Array = inner[0]
	var w := maxf(0.5, s * 0.022)
	var step := maxf(2.4, s * 0.09)
	var stitch_col := Color(col.lightened(0.35), 0.5)
	var n := ring.size()
	var carry := 0.0
	for i in n:
		var a := ring[i]
		var e := ring[(i + 1) % n]
		var len := a.distance_to(e)
		var t := carry
		while t < len:
			var t1 := minf(t + step * 0.55, len)
			b.line(a.lerp(e, t / len), a.lerp(e, t1 / len), stitch_col, w)
			t += step
		carry = t - len


## A soft contact shadow under an icon of half-size `s` (its foot at `y`
## on the icon's grid, `wide` grid steps across), so it sits in its slot.
static func ground(b, s: float, y := 8.8, wide := 7.0, a := 0.42) -> void:
	var u := unit(s)
	var c := Vector2(0.8, y) * u
	var n := 20
	var rx := wide * u
	var ry := maxf(1.2, 1.7 * u)
	var mid := Color(INK, a)
	var none := Color(INK, 0.0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector2(cos(a0) * rx, sin(a0) * ry)
		var p1 := c + Vector2(cos(a1) * rx, sin(a1) * ry)
		b.pts.append_array([c, p0, p1])
		b.cols.append_array([mid, none, none])


## A small dome rivet (a stud, a nail head) at `p`: dark ring, lit cap, a glint.
static func rivet(b, p: Vector2, r: float, col: Color) -> void:
	var l := LIGHT.normalized()
	b.circle(p + Vector2(0.25, 0.3) * r, r * 1.15, Color(INK, 0.55), 10)
	b.circle(p, r, col.darkened(0.2), 10)
	b.circle(p + l * r * 0.25, r * 0.65, col.lightened(0.25), 10)
	b.circle(p + l * r * 0.45, maxf(0.35, r * 0.28), Color(1, 1, 1, 0.75), 8)


## A row of stitches from `a` to `e`: short dashes, `n` of them.
static func stitches(b, a: Vector2, e: Vector2, n: int, col: Color, w: float) -> void:
	for i in n:
		var t0 := (i + 0.2) / float(n)
		var t1 := (i + 0.65) / float(n)
		b.line(a.lerp(e, t0), a.lerp(e, t1), col, w)


## A feather from `root` to `tip`, `wd` wide: a vane in `col` with a quill
## and a few barbs, lit on its upper side.
static func feather(b, root: Vector2, tip: Vector2, wd: float, col: Color, s: float, flags := 0) -> void:
	var dir := (tip - root).normalized()
	var side := lit_side(root, tip)
	var len := root.distance_to(tip)
	var ctrl := PackedVector2Array([root + dir * len * 0.12, root + dir * len * 0.35 + side * wd, root + dir * len * 0.78 + side * wd * 0.7, tip,
		root + dir * len * 0.75 - side * wd * 0.75, root + dir * len * 0.35 - side * wd * 0.95])
	var vane := smooth(ctrl, 3)
	shape(b, vane, col, s, "cloth", flags)
	var w := maxf(0.5, wd * 0.16)
	b.line(root, tip - dir * len * 0.05, col.lightened(0.45), w)
	if s >= 13.0:
		for k in 4:
			var at := root.lerp(tip, 0.32 + k * 0.14)
			b.line(at, at + (side * 0.8 + dir * 0.6).normalized() * wd * 0.7, Color(col.darkened(0.35), 0.6), w * 0.8)
			b.line(at, at + (-side * 0.8 + dir * 0.6).normalized() * wd * 0.7, Color(col.darkened(0.35), 0.6), w * 0.8)


## A zigzag bolt of lightning from `a` to `e`, `n` kinks, pale with a glow.
static func bolt(b, a: Vector2, e: Vector2, w: float, col: Color, n := 4) -> void:
	var side := (e - a).normalized().orthogonal()
	var prev := a
	for i in n:
		var t := float(i + 1) / n
		var p := a.lerp(e, t) + (side * w * 2.2 * (1.0 if i % 2 == 0 else -1.0) if i < n - 1 else Vector2.ZERO)
		b.line(prev, p, Color(col, 0.35), w * 2.6)
		b.line(prev, p, col, w)
		b.line(prev, p, Color(1, 1, 1, 0.85), w * 0.45)
		prev = p


## A soft shine just inside the edges of `pts` that face the light.
static func rim(b, pts: PackedVector2Array, s: float, col: Color, strength := 1.0) -> void:
	var w := maxf(0.6, s * 0.06)
	var l := LIGHT.normalized()
	var n := pts.size()
	var cw := _clockwise(pts)
	for i in n:
		var a := pts[i]
		var e := pts[(i + 1) % n]
		if a.distance_squared_to(e) < 0.01:
			continue
		var side := (e - a).normalized().orthogonal()
		if not cw:
			side = -side  # (now pointing out)
		var facing := side.dot(l)
		if facing < 0.2:
			continue
		var inset := -side * (w * 0.5 + 0.3)
		b.line(a + inset, e + inset, Color(col, col.a * clampf((facing - 0.2) * 1.6, 0.0, 1.0) * strength), w)


## Which way a polygon winds (true: clockwise on screen, y down).
static func _clockwise(pts: PackedVector2Array) -> bool:
	var area := 0.0
	var n := pts.size()
	for i in n:
		area += pts[i].x * pts[(i + 1) % n].y - pts[(i + 1) % n].x * pts[i].y
	return area > 0.0


## A ball in `col`, outlined and smoothly lit from the top-left; `kind`
## "metal", "gem", "gold" or "glass" adds a sharp highlight.
static func orb(b, c: Vector2, r: float, col: Color, s: float, kind := "", outlined := true) -> void:
	var o := ol(s)
	var l := LIGHT.normalized()
	var rr := ramp(col, kind)
	var n := clampi(int(r * 2.0) + 14, 16, 40)
	if outlined:
		b.circle(c, r + o + 0.55, Color(INK, FEATHER), n)
		b.circle(c, r + o, INK, n)
	# A fan from a lit point near the top-left out to the edge, each edge
	# point shaded by how much it faces the light.
	var hot := c + l * r * 0.38
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector2.from_angle(a0) * r
		var p1 := c + Vector2.from_angle(a1) * r
		b.pts.append_array([hot, p0, p1])
		b.cols.append_array([rr[3], _edge(rr, Vector2.from_angle(a0).dot(l)), _edge(rr, Vector2.from_angle(a1).dot(l))])
	if s >= 13.0 and r >= 2.5:
		var bw := maxf(0.6, r * 0.14)
		var away := (-l).angle()
		b.arc(c, r - bw * 0.7, away - 1.0, away + 1.0, 12, Color(BOUNCE, 0.28 if kind in ["metal", "gem", "glass", "gold"] else 0.18), bw)
	if kind in ["metal", "gem", "glass", "gold"]:
		b.circle(c + l * r * 0.48, maxf(0.55, r * 0.2), rr[4], 12)
	else:
		b.circle(c + l * r * 0.46, maxf(0.5, r * 0.2), Color(rr[4], rr[4].a * 0.6), 12)


static func _edge(rr: Array, facing: float) -> Color:
	return rr[2].lerp(rr[3], facing) if facing > 0.0 else rr[2].lerp(rr[1], -facing)


## A shaft from `a` to `e`, `w` wide, outlined and shaded round across its
## width (a haft, a grip, a bow's limb).
static func rod(b, a: Vector2, e: Vector2, w: float, col: Color, s: float, kind := "", outlined := true) -> void:
	var o := ol(s)
	if outlined:
		var f := w + o * 2.0 + 1.1
		b.line(a, e, Color(INK, FEATHER), f)
		b.circle(a, f * 0.5, Color(INK, FEATHER), 14)
		b.circle(e, f * 0.5, Color(INK, FEATHER), 14)
		b.line(a, e, INK, w + o * 2.0)
		b.circle(a, w * 0.5 + o, INK, 14)
		b.circle(e, w * 0.5 + o, INK, 14)
	var rr := ramp(col, kind)
	var side := lit_side(a, e) * w * 0.5
	_quad(b, a + side, e + side, e, a, rr[3], col)
	_quad(b, a, e, e - side, a - side, col, rr[1])
	b.circle(a, w * 0.5, col, 12)
	b.circle(e, w * 0.5, col, 12)
	if w >= 2.2:
		b.line(a + side * 0.5, e + side * 0.5, rr[4], maxf(0.5, w * 0.16))


## A quad from edge p0-p1 (colour c0) to edge p2-p3 (colour c1).
static func _quad(b, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, c0: Color, c1: Color) -> void:
	b.pts.append_array([p0, p1, p2, p0, p2, p3])
	b.cols.append_array([c0, c0, c1, c0, c1, c1])


## A curved shaft (a bow's limb): centre, radius, from and to angles.
static func arc_rod(b, c: Vector2, r: float, from: float, to: float, w: float, col: Color, s: float, kind := "", taper := 0.0) -> void:
	var o := ol(s)
	var n := clampi(int(absf(to - from) * r / 2.0) + 8, 10, 40)
	var rr := ramp(col, kind)
	var l := LIGHT.normalized()
	var mid := PackedVector2Array()
	var ws := PackedFloat32Array()
	for i in n + 1:
		var t := float(i) / n
		mid.append(c + Vector2.from_angle(lerpf(from, to, t)) * r)
		ws.append(w * (1.0 - taper * absf(t * 2.0 - 1.0)))
	for pass_i in 2:
		var col_o := Color(INK, FEATHER) if pass_i == 0 else INK
		var extra := o * 2.0 + (1.1 if pass_i == 0 else 0.0)
		for i in n:
			b.line(mid[i], mid[i + 1], col_o, (ws[i] + ws[i + 1]) * 0.5 + extra)
		b.circle(mid[0], (ws[0] + extra) * 0.5, col_o, 12)
		b.circle(mid[n], (ws[n] + extra) * 0.5, col_o, 12)
	for i in n:
		var a := lerpf(from, to, (i + 0.5) / n)
		var nrm := Vector2.from_angle(a)
		var k := nrm.dot(l)
		var out := nrm if k > 0.0 else -nrm
		var w0 := ws[i] * 0.5
		var w1 := ws[i + 1] * 0.5
		var lit := col.lerp(rr[3], absf(k))
		_quad(b, mid[i] + out * w0, mid[i + 1] + out * w1, mid[i + 1], mid[i], lit, col)
		_quad(b, mid[i], mid[i + 1], mid[i + 1] - out * w1, mid[i] - out * w0, col, rr[1])


## A glass vessel: `pts` its outside. Dark glass, `liquid` filled up to the
## height `level` (y; INF for none) and lit in a smooth gradient, its
## surface bright, then the glass's cool rim light.
static func glass(b, pts: PackedVector2Array, s: float, liquid: Color, level: float, glow := 0.0) -> void:
	outline(b, pts, s)
	var tint := GLASS.lerp(liquid, 0.14) if level < INF else GLASS
	grad(b, pts, tint.lightened(0.12), tint, tint.darkened(0.3))
	var wall := maxf(0.6, s * 0.06)
	var inner := Geometry2D.offset_polygon(pts, -wall)
	if inner.is_empty():
		return
	var cav: PackedVector2Array = inner[0]
	if level < INF:
		var cut := PackedVector2Array([Vector2(-1e4, level), Vector2(1e4, level), Vector2(1e4, 1e4), Vector2(-1e4, 1e4)])
		var rr := ramp(liquid)
		for part in Geometry2D.intersect_polygons(cav, cut):
			grad(b, part, liquid.lightened(0.18), liquid, rr[1])
			var x0 := INF
			var x1 := -INF
			for p in part:
				if p.y <= level + 0.01:
					x0 = minf(x0, p.x)
					x1 = maxf(x1, p.x)
			if x1 > x0:
				b.line(Vector2(x0 + wall * 0.2, level + 0.35 * wall), Vector2(x1 - wall * 0.2, level + 0.35 * wall), Color(liquid.lightened(0.5), 0.9), maxf(0.6, s * 0.06))
		if glow > 0.0:
			var bc := Vector2.ZERO
			for p in cav:
				bc += p
			bc /= cav.size()
			soft(b, bc + Vector2(0, s * 0.2), s * 0.45, Color(liquid.lightened(0.55), 0.55 * glow))
	rim(b, cav, s, Color(COOL_SHINE, 0.45))


## A sharp elongated shine (glass, polished metal): an oval at `c`.
static func shine(b, c: Vector2, rx: float, ry: float, rot := -0.6, a := 0.7) -> void:
	b.polygon(oval(c, Vector2(rx, ry), rot, 14), Color(1, 1, 1, a))


## A four-pointed sparkle.
static func spark(b, c: Vector2, r: float, col: Color) -> void:
	b.polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.2, -r * 0.2), c + Vector2(r, 0), c + Vector2(r * 0.2, r * 0.2),
		c + Vector2(0, r), c + Vector2(-r * 0.2, r * 0.2), c + Vector2(-r, 0), c + Vector2(-r * 0.2, -r * 0.2)]), col)


## A small flame at `c`, `r` tall: orange round a pale heart, glowing.
static func flame(b, c: Vector2, r: float, s: float) -> void:
	var unit := [Vector2(0, -1.0), Vector2(0.3, -0.45), Vector2(0.52, 0.05), Vector2(0.4, 0.5), Vector2(0, 0.66),
		Vector2(-0.4, 0.5), Vector2(-0.52, 0.05), Vector2(-0.18, -0.3)]
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for v in unit:
		outer.append(c + v * r * 1.4)
		inner.append(c + Vector2(0, r * 0.32) + v * r * 0.72)
	outer = smooth(outer, 3)
	inner = smooth(inner, 3)
	soft(b, c + Vector2(0, r * 0.3), r * 1.8, Color(1.0, 0.55, 0.2, 0.4))
	outline(b, outer, s, ol(s) * 0.7)
	grad(b, outer, Color(1.0, 0.72, 0.3), Color(1.0, 0.5, 0.17), Color(0.9, 0.3, 0.12))
	b.polygon(inner, Color(1.0, 0.92, 0.6))


## A soft round glow: `col` at the centre (its alpha) fading smoothly to
## nothing at radius `r` (one fan of triangles).
static func soft(b, c: Vector2, r: float, col: Color) -> void:
	var n := clampi(int(r * 0.8) + 16, 20, 40)
	var mid := Color(col, col.a * 0.42)
	var none := Color(col, 0.0)
	var prev_in := c + Vector2(r * 0.45, 0)
	var prev_out := c + Vector2(r, 0)
	for i in n:
		var d := Vector2.from_angle(TAU * (i + 1) / n)
		var p_in := c + d * r * 0.45
		var p_out := c + d * r
		b.pts.append_array([c, prev_in, p_in])
		b.cols.append_array([col, mid, mid])
		_quad(b, prev_in, p_in, p_out, prev_out, mid, none)
		prev_in = p_in
		prev_out = p_out


## A rarity's glow behind an icon of half-size `s` at `c` (nothing for Common).
static func rarity_glow(b, c: Vector2, s: float, rarity: String, col: Color) -> void:
	var k: float = RARITY_GLOW.get(rarity, 0.0)
	if k <= 0.0:
		return
	var small := 0.14 if s < 13.0 else 0.0  # (a HUD-sized icon needs it brighter to show)
	if rarity == "regarded":
		# A beast's own piece: gold rays turning out from behind it.
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			var d := Vector2.from_angle(a)
			var reach := s * (1.25 if i % 2 == 0 else 1.0)
			var tip := c + d * reach
			var base_w := s * (0.16 if i % 2 == 0 else 0.11)
			b.pts.append_array([c + d.orthogonal() * base_w, tip, c - d.orthogonal() * base_w])
			b.cols.append_array([Color(col, 0.42 + small), Color(col, 0.0), Color(col, 0.42 + small)])
	soft(b, c, s * (1.15 + 0.3 * k + small * 2.0), Color(col, 0.5 * k + 0.18 + small))
	soft(b, c, s * 0.8, Color(col.lightened(0.25), 0.3 * k + small))


## A Regarded piece's two glints, over its icon (drawn after the icon).
static func regarded_glints(b, c: Vector2, s: float, col: Color) -> void:
	spark(b, c + Vector2(-0.62, -0.7) * s, maxf(1.6, s * 0.17), Color(col.lightened(0.5), 0.95))
	spark(b, c + Vector2(0.74, 0.36) * s, maxf(1.2, s * 0.11), Color(col.lightened(0.6), 0.85))


## Points on an icon's grid: `arr` of Vector2 (about -10..10), scaled by `u`
## and centred on `c`.
static func pts(c: Vector2, u: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(c + v * u)
	return out


## An oval's points, turned by `rot`.
static func oval(c: Vector2, rad: Vector2, rot := 0.0, n := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y).rotated(rot))
	return out


## A rounded rectangle's points.
static func rrect(r: Rect2, rad: float, per := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for i in per:
			out.append(cs[k] + Vector2.from_angle(-PI / 2.0 + (k + i / float(per - 1)) * PI / 2.0) * rad)
	return out


## A smooth closed curve through `ctrl` (a Catmull-Rom loop), `per` points
## between each pair: turns a few corner points into a soft outline.
static func smooth(ctrl: PackedVector2Array, per := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


# --- the cache ----------------------------------------------------------------------

## An icon's size rounded to the cache's steps (a quarter pixel of half
## size, too small to see), so a size that changes smoothly reuses a few
## cached icons instead of building a new one every frame.
static func size_step(s: float) -> float:
	return maxf(0.25, snappedf(s, 0.25))


static var _cache := {}
const CACHE_MAX := 600


## Adds an icon to Batch `b` at `c`: built by `build` (a Callable taking a
## Batch and drawing the icon around Vector2.ZERO) the first time this `key`
## is seen, and copied from the cache after that.
static func cached(b, key: String, c: Vector2, build: Callable) -> void:
	var hit = _cache.get(key)
	if hit == null:
		var nb := Draw.Batch.new()
		build.call(nb)
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		hit = [nb.pts, nb.cols]
		_cache[key] = hit
	b.pts.append_array(Transform2D(0.0, c) * (hit[0] as PackedVector2Array))
	b.cols.append_array(hit[1])


## Forgets every cached icon (tests, or after changing how icons draw).
static func clear_cache() -> void:
	_cache.clear()
