extends RefCounted
## Shared drawing helpers for the code-drawn characters: outlined, shaded
## shapes and soft shadows. Every function draws onto the CanvasItem passed in.
##
## --- STYLE GUIDE (climber, monsters, weapons, projectiles) ---------------------
## Follow this so everything in the tower looks like one game.
##
## Outline: every solid shape gets a dark rim in Palette.OUTLINE, 1.6 px for
##   balls (Draw.ball) and 1.2 px each side for limbs, blades and shafts
##   (Draw.stroke adds 2.4 to the width). Thin details inside a shape (stitches,
##   rivets, eyes) get no outline.
## Soft edges: no antialiased lines. Every outline sits on a feather, a ring
##   1 px wider in OUTLINE at low alpha (FEATHER_ALPHA), which smooths the
##   edge on a phone. ball(), stroke() and poly() do it for you.
## Shading: lit from the top-left of the SCREEN. A ball is a darker base, the
##   colour slightly offset to the top-left, then a small pale highlight
##   (Draw.ball). In a rotated frame, turn the screen's top-left into your
##   frame (light = frame.basis_xform(LIGHT_DIR)) before placing highlights.
## Limbs and weapons: Draw.stroke from joint to joint (arms ~3.6 px, shafts
##   2.6-3.4 px, blades 3.2 px), hands and feet as small Draw.balls on the
##   ends. Blades get a 1 px pale glint line along one edge.
## Colours: from scripts/palette.gd; darken or lighten them rather than
##   inventing new hues. Hurt = lerp toward red; dead = desaturated grey.
## Motion: animate from time or a phase that changes smoothly (sin, lerp).
##   Never pick random numbers per frame, hard-switch colours on a timer, or
##   swap draw order mid-animation: those read as flicker.
## Lighting bug: on anything torchlight falls on (any canvas item without an
##   unshaded material), NEVER use draw_line, draw_multiline or a wide
##   draw_polyline/draw_arc: Godot 4.3's Compatibility renderer lights only
##   one of their two triangles, so they look half-lit and shimmer as they
##   move. Use Draw.line / Draw.polyline / Draw.stroke / Draw.arc (quads)
##   instead. Unshaded layers (HUD, effects overlays) may use the built-ins.
## Cost: every draw_* call is a draw call. Build a whole character into one
##   Batch (b.ball, b.stroke, b.poly, b.line, b.circle ...) and flush it once.
## Volume (shade.gd, the shading toolkit): the character helpers (ball,
##   stroke, limb, poly, sword) are shaded for you: balls as spheres, strokes
##   as cylinders, polygons as lit faces with a highlight on their lit edges.
##   For more, use b.disc / b.oval / b.box / b.fill / b.bar (any material:
##   Shade.WOOD, Shade.METAL, Shade.CLOTH ...), b.grad_rect / b.grad_poly,
##   b.rim and b.contact (a soft floor shadow). The plain primitives (rect,
##   line, circle, polygon, path, arc) stay flat, like the draw_* they copy.
##   In a rotated frame set b.light (the screen's light in that frame).
## ------------------------------------------------------------------------------

const Palette := preload("res://scripts/palette.gd")
const Shade := preload("res://scripts/shade.gd")

const FEATHER_ALPHA := 0.35  # the soft ring under an outline
const LIGHT_DIR := Vector2(-0.6, -0.8)  # where the light comes from (screen)


## A soft oval shadow on the floor (one quad: shade.gd's SOFT falloff).
static func shadow(c: CanvasItem, pos: Vector2, r: float, alpha := 0.35) -> void:
	Shade.contact(c, pos, r, minf(1.0, alpha * 1.5), 0.42)


## A ball lit from the top-left: soft dark rim, shaded side, highlight.
static func ball(c: CanvasItem, pos: Vector2, r: float, col: Color, outline := true) -> void:
	var b := Batch.new()
	b.ball(pos, r, col, outline)
	b.flush(c)


## An outlined polygon with a flat fill.
static func poly(c: CanvasItem, pts: PackedVector2Array, col: Color, outline := 1.6) -> void:
	var b := Batch.new()
	b.poly(pts, col, outline)
	b.flush(c)


## A line with a width, drawn as a filled quad. Use this (not draw_line with
## a width) on anything torchlight falls on: in Godot 4.3's Compatibility
## renderer a wide draw_line is lit on only one of its two triangles, so it
## shimmers half-lit as it moves under a light. Thin 1 px lines are fine.
static func line(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width := 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var o := d.normalized().orthogonal() * (width * 0.5)
	c.draw_colored_polygon(PackedVector2Array([a + o, b + o, b - o, a - o]), col)


## A polyline with a width, as quads with round joints (see line()), in one draw.
static func polyline(c: CanvasItem, pts: PackedVector2Array, col: Color, width := 1.0, closed := false) -> void:
	var b := Batch.new()
	b.path(pts, col, width, closed)
	b.flush(c)


## An arc with a width, as quads (see line()), in one draw.
static func arc(c: CanvasItem, center: Vector2, r: float, from: float, to: float, points: int, col: Color, width := 1.0) -> void:
	var b := Batch.new()
	b.arc(center, r, from, to, points, col, width)
	b.flush(c)


## A thick outlined line with round ends, for blades, bows and limbs.
static func stroke(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var bt := Batch.new()
	bt.stroke(a, b, col, width)
	bt.flush(c)


## A sword lying along dir from the grip, with crossguard and pommel.
static func sword(c: CanvasItem, grip: Vector2, dir: Vector2, length: float, glint := 0.0) -> void:
	var b := Batch.new()
	b.sword(grip, dir, length, glint)
	b.flush(c)


## A wobbly blob outline (slimes), as polygon points.
static func blob(center: Vector2, r: float, t: float, wobble: float, squash := Vector2.ONE, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / n * TAU
		var rr := r * (1.0 + wobble * sin(a * 3.0 + t * 5.0) + wobble * 0.6 * sin(a * 5.0 - t * 7.0))
		pts.append(center + Vector2(cos(a) * rr * squash.x, sin(a) * rr * squash.y))
	return pts


## --- batching -------------------------------------------------------------------
## Godot sends every circle and polygon to the graphics card as its own draw
## call, which is slow on phones and in browsers. These draw several shapes
## as one list of triangles, in order, and send them all at once: the picture
## is the same (same shapes, same layering), only cheaper to draw.

static var _ring := PackedVector2Array()
static var _fans := {}  # how many circles -> their triangle indices


## Circles drawn in order as one draw call, each exactly like draw_circle.
static func circles(c: CanvasItem, at: PackedVector2Array, radii: PackedFloat32Array, cols: PackedColorArray) -> void:
	var n := at.size()
	if _ring.is_empty():
		_ring = Batch.circle_ring()
	if not _fans.has(n):
		var idx := PackedInt32Array()
		for k in n:
			var o := k * Batch.CIRCLE_POINTS
			for i in Batch.CIRCLE_POINTS - 2:
				idx.append_array([o, o + i + 1, o + i + 2])
		_fans[n] = idx
	var pts := PackedVector2Array()
	var colors := PackedColorArray()
	var one := PackedColorArray()
	one.resize(Batch.CIRCLE_POINTS)
	for k in n:
		pts.append_array(Transform2D(0.0, Vector2(radii[k], radii[k]), 0.0, at[k]) * _ring)
		one.fill(cols[k])
		colors.append_array(one)
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), _fans[n], pts, colors)


class Batch:
	const CIRCLE_POINTS := 64  # what Godot's own draw_circle uses
	static var _circle_tris := {}  # points -> unit circle triangles

	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()  # into Shade.tex(); empty until a shaded shape is added
	var shaded := true  # false: the shaded helpers draw flat (the old look)
	var light := LIGHT_DIR  # the screen's light in this batch's frame (set it in a rotated frame)
	var form := false  # the plain shapes take a whole figure's light too (begin_form)
	var _form_xf := Transform2D()
	static var _bar_uv := {}

	## The points of a unit circle, placed like Godot's draw_circle places them.
	static func circle_ring(n := CIRCLE_POINTS) -> PackedVector2Array:
		var ring := PackedVector2Array()
		for i in n:
			var a := i * TAU / n
			ring.append(Vector2(cos(a), sin(a)))
		return ring

	## A unit circle as a triangle list, fanned like Godot's draw_circle.
	static func circle_tris(n := CIRCLE_POINTS) -> PackedVector2Array:
		if not _circle_tris.has(n):
			var ring := circle_ring(n)
			var tris := PackedVector2Array()
			for i in n - 2:
				tris.append_array([ring[0], ring[i + 1], ring[i + 2]])
			_circle_tris[n] = tris
		return _circle_tris[n]

	func size() -> int:
		return pts.size()

	var _one := PackedColorArray()  # (reused: one colour, n times)

	func _color(col: Color, n: int) -> void:
		_one.resize(n)
		_one.fill(col)
		cols.append_array(_one)

	## Like draw_rect (filled).
	func rect(r: Rect2, col: Color) -> void:
		var a := r.position
		var b := r.end
		var q := PackedVector2Array([a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)])
		if form:
			_shaded(q, col, _form_xf * q)
			return
		pts.append_array(q)
		_color(col, 6)

	## Like draw_line with a width (not antialiased).
	func line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		var t := (from - to).orthogonal().normalized() * width * 0.5
		var q := PackedVector2Array([from + t, to + t, to - t, from + t, to - t, from - t])
		if form:
			_shaded(q, col, _form_xf * q)
			return
		pts.append_array(q)
		_color(col, 6)

	## Like draw_circle. Specks a pixel or two across can use fewer points.
	func circle(pos: Vector2, r: float, col: Color, points := CIRCLE_POINTS) -> void:
		var tris := circle_tris(points)
		var q := Transform2D(0.0, Vector2(r, r), 0.0, pos) * tris
		if form:
			_shaded(q, col, _form_xf * q)
			return
		pts.append_array(q)
		_color(col, tris.size())

	## Like draw_colored_polygon (same triangulation).
	func polygon(points: PackedVector2Array, col: Color) -> void:
		var idx := Geometry2D.triangulate_polygon(points)
		var q := PackedVector2Array()
		q.resize(idx.size())
		for i in idx.size():
			q[i] = points[idx[i]]
		if form:
			_shaded(q, col, _form_xf * q)
			return
		pts.append_array(q)
		_color(col, idx.size())

	## A whole figure's light over the plain shapes that follow (until
	## end_form): `box` is the figure's frame (local coordinates) mapped onto
	## material `m` (Shade.FORM: a standing figure lit from the left; Shade.
	## DOME: a figure seen from above, in a frame turned by b.light). The
	## helpers' own shading (balls, strokes, polygons) goes on as before.
	func begin_form(box: Rect2, m := Shade.FORM) -> void:
		if not _on():
			return
		var to_unit := Transform2D(0.0, Vector2.ONE / box.size, 0.0, -box.position / box.size)
		if m == Shade.DOME:
			var c := box.get_center()
			to_unit = Transform2D(-Shade.turn(light), Vector2.ONE / box.size, 0.0, Vector2(0.5, 0.5)) * Transform2D(0.0, -c)
		_form_xf = Shade.region(m) * to_unit
		form = true

	func end_form() -> void:
		form = false

	## Like draw_polyline (not antialiased): a strip with mitred joints.
	func polyline(points: PackedVector2Array, col: Color, width: float) -> void:
		var side := PackedVector2Array()
		var prev_t := Vector2.ZERO
		for i in points.size():
			var t := prev_t
			if i < points.size() - 1:
				t = (points[i + 1] - points[i]).normalized().orthogonal()
				if i == 0:
					prev_t = t
			var tangent := (t + prev_t).normalized() * width * 0.5
			side.append_array([points[i] + tangent, points[i] - tangent])
			prev_t = t
		for i in points.size() - 1:
			var k := i * 2
			pts.append_array([side[k], side[k + 1], side[k + 2], side[k + 1], side[k + 3], side[k + 2]])
		_color(col, (points.size() - 1) * 6)

	# --- the character style (see the style guide at the top) ---

	## A circle with as many points as its size needs (cheap for small ones).
	func dot(pos: Vector2, r: float, col: Color) -> void:
		circle(pos, r, col, clampi(int(r * 3.0) + 10, 12, 48))

	## A ball lit from the top-left: feather, outline, shaded side, highlight.
	## `light` is the light's direction in the current frame (LIGHT_DIR on
	## an unrotated canvas item).
	func ball(pos: Vector2, r: float, col: Color, outline := true, light := LIGHT_DIR) -> void:
		if outline:
			dot(pos, r + 2.4, Color(Palette.OUTLINE, FEATHER_ALPHA))
			dot(pos, r + 1.6, Palette.OUTLINE)
		if _on():
			_disc(pos, Vector2(r, r), 0.0, col, Shade.BALL, Shade.turn(light if light != LIGHT_DIR else self.light))
			return
		var l := light.normalized()
		dot(pos, r, col.darkened(0.35))
		dot(pos + l * r * 0.18, r * 0.86, col)
		dot(pos + l * r * 0.48, r * 0.34, Color(col.lightened(0.45), 0.55))

	## A thick outlined line with round ends, for blades, shafts and limbs.
	func stroke(a: Vector2, b: Vector2, col: Color, width: float, m := Shade.TUBE) -> void:
		var o := width + 2.4
		line(a, b, Color(Palette.OUTLINE, FEATHER_ALPHA), o + 1.6)
		dot(a, (o + 1.6) * 0.5, Color(Palette.OUTLINE, FEATHER_ALPHA))
		dot(b, (o + 1.6) * 0.5, Color(Palette.OUTLINE, FEATHER_ALPHA))
		line(a, b, Palette.OUTLINE, o)
		dot(a, o * 0.5, Palette.OUTLINE)
		dot(b, o * 0.5, Palette.OUTLINE)
		bar(a, b, col, width, m)

	## A limb through joints (shoulder, elbow, wrist): like stroke() for each
	## segment, but outlined all at once and filled after, so the joints are
	## smooth and round instead of each segment's rim cutting across the
	## next. `widths` has one width per segment.
	func limb(points: PackedVector2Array, widths: PackedFloat32Array, col: Color) -> void:
		var n := points.size()
		if n < 2:
			return
		for pass_i in 3:
			var add: float = [4.0, 2.4, 0.0][pass_i]
			var c: Color = [Color(Palette.OUTLINE, FEATHER_ALPHA), Palette.OUTLINE, col][pass_i]
			var fill := pass_i == 2 and _on()
			for i in n - 1:
				if fill:
					bar(points[i], points[i + 1], c, widths[i])
				else:
					line(points[i], points[i + 1], c, widths[i] + add)
			for i in n:
				var w: float = widths[mini(i, n - 2)] if i == 0 or i == n - 1 else maxf(widths[i - 1], widths[i])
				if fill:
					var along := points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]
					_joint(points[i], w * 0.5, c, along)
				else:
					dot(points[i], (w + add) * 0.5, c)

	## A polyline with a width, as quads with round joints.
	func path(points: PackedVector2Array, col: Color, width: float, closed := false) -> void:
		var n := points.size()
		if n < 2:
			return
		var last := n if closed else n - 1
		for i in last:
			line(points[i], points[(i + 1) % n], col, width)
		if width > 2.0:
			for p in points:
				dot(p, width * 0.5, col)

	## An arc with a width, as quads (from and to in radians).
	func arc(center: Vector2, r: float, from: float, to: float, points: int, col: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in points + 1:
			pts.append(center + Vector2.from_angle(lerpf(from, to, float(i) / points)) * r)
		path(pts, col, width)

	## An outlined polygon with a flat fill (outline 0 for none).
	func poly(points: PackedVector2Array, col: Color, outline := 1.6, m := Shade.SLAB) -> void:
		if outline > 0.0:
			path(points, Color(Palette.OUTLINE, FEATHER_ALPHA), outline * 2.0 + 1.6, true)
			path(points, Palette.OUTLINE, outline * 2.0, true)
		fill(points, col, m)
		if outline > 0.0:
			rim(points, Color(col.lightened(0.4), 0.45), 1.0)

	## A sword lying along dir from the grip, with crossguard and pommel.
	func sword(grip: Vector2, dir: Vector2, length: float, glint := 0.0) -> void:
		var side := dir.orthogonal()
		var tip := grip + dir * length
		stroke(grip - dir * 5.0, grip, Palette.WOOD.darkened(0.3), 3.0)  # hilt
		stroke(grip + side * 5.0, grip - side * 5.0, Palette.STEEL.darkened(0.35), 2.5)  # crossguard
		stroke(grip + dir * 2.0, tip, Palette.STEEL.darkened(0.12), 3.2, Shade.METAL)  # blade (with a sheen)
		line(grip + dir * 3.0 - side * 0.8, tip - dir * 1.0 - side * 0.8, Palette.STEEL.darkened(0.45), 1.0)  # its shaded edge
		line(grip + dir * 3.0 + side * 0.7, tip - dir * 2.0 + side * 0.7, Color(1, 1, 1, 0.55 + glint * 0.45), 1.0)
		dot(grip - dir * 6.0, 2.2, Palette.STEEL.darkened(0.2))  # pommel

	# --- shaded shapes (shade.gd) ---

	func _on() -> bool:
		return shaded and Shade.on

	## Adds triangles `q` in `col` with UVs `uv` into the shading texture.
	func _shaded(q: PackedVector2Array, col: Color, uv: PackedVector2Array, gained := true) -> void:
		if uvs.size() != pts.size():
			uvs.resize(pts.size())  # (flat shapes added before this read UV 0,0: no shading)
		pts.append_array(q)
		if gained:
			col = Color(col.r * Shade.GAIN, col.g * Shade.GAIN, col.b * Shade.GAIN, col.a)
		_one.resize(q.size())
		_one.fill(col)
		cols.append_array(_one)
		uvs.append_array(uv)

	func _disc(pos: Vector2, rad: Vector2, rot: float, col: Color, m: int, ang: float) -> void:
		var n := clampi(int(maxf(rad.x, rad.y) * 3.0) + 10, 12, 48)
		var tris := circle_tris(n)
		_shaded(Transform2D(rot, rad, 0.0, pos) * tris, col, Shade.disc_uvs(tris, n, m, ang - rot), m != Shade.SOFT)

	## A round joint in a shaded stroke (a limb's elbow): lit across like the
	## bar either side of it (`along` the limb), so no knob shows.
	func _joint(pos: Vector2, r: float, col: Color, along: Vector2) -> void:
		var n := clampi(int(r * 3.0) + 10, 12, 48)
		var tris := circle_tris(n)
		var t := along.orthogonal().normalized()
		var s := clampf(t.dot(light.normalized()) * 2.5, -1.0, 1.0)  # as bar()
		var k := -0.5 * s
		var uvx := Shade.region(Shade.TUBE) * Transform2D(Vector2(k * t.x, k * t.x), Vector2(k * t.y, k * t.y), Vector2(0.5, 0.5))
		_shaded(Transform2D(0.0, Vector2(r, r), 0.0, pos) * tris, col, uvx * tris)

	## A shaded circle: a sphere (BALL) unless another material is given.
	func disc(pos: Vector2, r: float, col: Color, m := Shade.BALL) -> void:
		if not _on():
			dot(pos, r, col)
			return
		_disc(pos, Vector2(r, r), 0.0, col, m, Shade.turn(light))

	## A shaded oval, `rad` its two radii, turned by `rot`.
	func oval(pos: Vector2, rad: Vector2, rot: float, col: Color, m := Shade.BALL) -> void:
		if not _on():
			var o := PackedVector2Array()
			for i in 20:
				o.append(pos + Vector2(cos(i * TAU / 20.0) * rad.x, sin(i * TAU / 20.0) * rad.y).rotated(rot))
			polygon(o, col)
			return
		_disc(pos, rad, rot, col, m, Shade.turn(light))

	## A shaded rect (a lit face by default: SLAB, or WOOD, METAL, CLOTH ...).
	func box(r: Rect2, col: Color, m := Shade.SLAB) -> void:
		if not _on():
			rect(r, col)
			return
		var a := r.position
		var e := r.end
		var q := PackedVector2Array([a, Vector2(e.x, a.y), e, a, e, Vector2(a.x, e.y)])
		var ang := Shade.turn(light)
		_shaded(q, col, Shade.box_uvs(m) if ang == 0.0 else Shade.face_uvs(q, m, ang), m != Shade.SOFT)

	## A shaded polygon: its bounds lit as material `m` (BALL makes a blob a sphere).
	func fill(points: PackedVector2Array, col: Color, m := Shade.SLAB) -> void:
		if not _on():
			polygon(points, col)
			return
		var idx := Geometry2D.triangulate_polygon(points)
		if idx.is_empty():
			return
		var fu := _form_xf * points if form and m == Shade.SLAB else Shade.face_uvs(points, m, Shade.turn(light))
		var q := PackedVector2Array()
		var uv := PackedVector2Array()
		q.resize(idx.size())
		uv.resize(idx.size())
		for i in idx.size():
			q[i] = points[idx[i]]
			uv[i] = fu[idx[i]]
		_shaded(q, col, uv, m != Shade.SOFT)

	## A shaded straight stroke (no outline): a cylinder (TUBE) across its
	## width, lit on the side facing the light; METAL gives a blade's sheen.
	func bar(from: Vector2, to: Vector2, col: Color, width: float, m := Shade.TUBE) -> void:
		if not _on() or width < 1.6:
			line(from, to, col, width)
			return
		var t := (from - to).orthogonal().normalized()
		var sq := roundf(clampf(t.dot(light.normalized()) * 2.5, -1.0, 1.0) * 20.0)  # +20: the +t side is lit
		var key := m * 64 + int(sq) + 20
		var uv = _bar_uv.get(key)
		if uv == null:
			var up := 0.5 - 0.5 * sq / 20.0
			var dn := 0.5 + 0.5 * sq / 20.0
			uv = Shade.region(m) * PackedVector2Array([Vector2(up, up), Vector2(up, up), Vector2(dn, dn), Vector2(up, up), Vector2(dn, dn), Vector2(dn, dn)])
			_bar_uv[key] = uv
		t *= width * 0.5
		_shaded(PackedVector2Array([from + t, to + t, to - t, from + t, to - t, from - t]), col, uv)

	## A soft-edged oval of colour (shadows, glows): `rad` its radii.
	func soft(pos: Vector2, rad: Vector2, col: Color) -> void:
		if not Shade.on:
			var o := PackedVector2Array()
			for i in 16:
				o.append(pos + Vector2(cos(i * TAU / 16.0) * rad.x, sin(i * TAU / 16.0) * rad.y) * 0.75)
			polygon(o, Color(col, col.a * 0.6))
			return
		var a := pos - rad
		var e := pos + rad
		_shaded(PackedVector2Array([a, Vector2(e.x, a.y), e, a, e, Vector2(a.x, e.y)]), col, Shade.box_uvs(Shade.SOFT), false)

	## A soft shadow on the floor under something `r` wide at `pos`.
	func contact(pos: Vector2, r: float, alpha := 0.42, flat := 0.42) -> void:
		soft(pos, Vector2(r * 1.25, r * 1.25 * flat), Color(0, 0, 0, alpha))

	## A rect filled top to bottom (or left to right) from c0 to c1.
	func grad_rect(r: Rect2, c0: Color, c1: Color, vertical := true) -> void:
		var a := r.position
		var e := r.end
		pts.append_array([a, Vector2(e.x, a.y), e, a, e, Vector2(a.x, e.y)])
		if vertical:
			cols.append_array([c0, c0, c1, c0, c1, c1])
		else:
			cols.append_array([c0, c1, c1, c0, c1, c0])

	## A polygon shaded from `lit` (its end toward the light) to `dark`.
	func grad_poly(points: PackedVector2Array, lit: Color, dark: Color) -> void:
		var idx := Geometry2D.triangulate_polygon(points)
		if idx.is_empty():
			return
		var l := light.normalized()
		var mn := INF
		var mx := -INF
		for p in points:
			mn = minf(mn, p.dot(l))
			mx = maxf(mx, p.dot(l))
		var span := maxf(mx - mn, 0.001)
		for i in idx:
			pts.append(points[i])
			cols.append(dark.lerp(lit, (points[i].dot(l) - mn) / span))

	## A thin highlight just inside the edges of `points` that face the
	## light (stronger the more squarely they face it).
	func rim(points: PackedVector2Array, col: Color, width := 1.0) -> void:
		var n := points.size()
		if n < 3 or not _on():
			return
		var area := 0.0
		for i in n:
			area += points[i].cross(points[(i + 1) % n])
		var sg := 1.0 if area > 0.0 else -1.0  # outward normals point this way round
		var l := light.normalized()
		for i in n:
			var a := points[i]
			var e := points[(i + 1) % n]
			var d := e - a
			if d.length_squared() < 1.0:
				continue
			var out := Vector2(d.y, -d.x).normalized() * sg
			var f := out.dot(l)
			if f <= 0.25:
				continue
			var inset := -out * (width * 0.5 + 0.2)
			var k := d.normalized() * minf(width, d.length() * 0.25)
			var p0 := a + inset + k
			var p1 := e + inset - k
			var t := out * (width * 0.5)
			pts.append_array([p0 + t, p1 + t, p1 - t, p0 + t, p1 - t, p0 - t])  # (flat: a highlight needs no shading)
			_color(Color(col, col.a * smoothstep(0.25, 0.8, f)), 6)

	# The CanvasItem names, so drawing code can be handed a Batch instead.
	func draw_rect(r: Rect2, col: Color) -> void:
		rect(r, col)

	func draw_line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		line(from, to, col, width)

	func draw_circle(pos: Vector2, r: float, col: Color) -> void:
		circle(pos, r, col)

	func draw_colored_polygon(points: PackedVector2Array, col: Color) -> void:
		polygon(points, col)

	func draw_arc(center: Vector2, r: float, from: float, to: float, points: int, col: Color, width: float, _antialiased := false) -> void:
		arc(center, r, from, to, points, col, width)

	func draw_polyline(points: PackedVector2Array, col: Color, width: float, _antialiased := false) -> void:
		polyline(points, col, width)

	## Sends everything collected so far to `c` (at the current draw transform).
	func flush(c: CanvasItem) -> void:
		if pts.is_empty():
			return
		if uvs.is_empty():
			RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), PackedInt32Array(), pts, cols)
		else:
			uvs.resize(pts.size())
			RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), PackedInt32Array(), pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), Shade.rid())
		pts = PackedVector2Array()
		cols = PackedColorArray()
		uvs = PackedVector2Array()


## A Batch split into squares of the world, each sent as its own canvas item.
## Squares off screen are skipped, so a floor-sized drawing only costs what's
## on screen (a few draw calls with big squares). Rects (and straight lines) are cut exactly at the square edges and
## circles that cross an edge are clipped, so nothing is drawn twice or moved.
class Chunked:
	var origin: Vector2
	var size: float
	var parts := {}  # Vector2i -> Batch

	func _init(at: Vector2, square: float) -> void:
		origin = at
		size = square

	func _key(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - origin.x) / size), floori((p.y - origin.y) / size))

	func _part(k: Vector2i) -> Batch:
		if not parts.has(k):
			parts[k] = Batch.new()
		return parts[k]

	func _square(k: Vector2i) -> Rect2:
		return Rect2(origin + Vector2(k) * size, Vector2(size, size))

	func rect(r: Rect2, col: Color) -> void:
		r = r.abs()
		var k0 := _key(r.position)
		var k1 := _key(r.end)
		if k0 == k1:
			_part(k0).rect(r, col)
			return
		for y in range(k0.y, k1.y + 1):
			for x in range(k0.x, k1.x + 1):
				var k := Vector2i(x, y)
				var piece := r.intersection(_square(k))
				if piece.has_area():
					_part(k).rect(piece, col)

	## A rect shaded corner to corner (colours at its top-left, top-right,
	## bottom-right and bottom-left), cut at the square edges like rect().
	## For soft light and shade baked into the floor: wall shadows, the
	## darkening where floor meets wall, each flagstone's tilt to the light.
	func shade_rect(r: Rect2, tl: Color, tr: Color, br: Color, bl: Color) -> void:
		r = r.abs()
		if not r.has_area():
			return
		var k0 := _key(r.position)
		var k1 := _key(r.end)
		for y in range(k0.y, k1.y + 1):
			for x in range(k0.x, k1.x + 1):
				var k := Vector2i(x, y)
				var piece := r.intersection(_square(k)) if k0 != k1 else r
				if not piece.has_area():
					continue
				var a := (piece.position - r.position) / r.size
				var e := (piece.end - r.position) / r.size
				var c00 := _bilerp(tl, tr, br, bl, a.x, a.y)
				var c10 := _bilerp(tl, tr, br, bl, e.x, a.y)
				var c11 := _bilerp(tl, tr, br, bl, e.x, e.y)
				var c01 := _bilerp(tl, tr, br, bl, a.x, e.y)
				var p := _part(k)
				var pa := piece.position
				var pe := piece.end
				p.pts.append_array([pa, Vector2(pe.x, pa.y), pe, pa, pe, Vector2(pa.x, pe.y)])
				p.cols.append_array([c00, c10, c11, c00, c11, c01])

	static func _bilerp(tl: Color, tr: Color, br: Color, bl: Color, u: float, v: float) -> Color:
		return tl.lerp(tr, u).lerp(bl.lerp(br, u), v)

	## A soft fade from `col` at one side of `r` to clear at the other
	## (side: Vector2.UP / DOWN / LEFT / RIGHT, where the colour is strongest).
	func fade_rect(r: Rect2, col: Color, side: Vector2) -> void:
		var clear := Color(col, 0.0)
		if side == Vector2.UP:
			shade_rect(r, col, col, clear, clear)
		elif side == Vector2.DOWN:
			shade_rect(r, clear, clear, col, col)
		elif side == Vector2.LEFT:
			shade_rect(r, col, clear, clear, col)
		else:
			shade_rect(r, clear, col, col, clear)

	func line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		if from.y == to.y:
			rect(Rect2(minf(from.x, to.x), from.y - width * 0.5, absf(to.x - from.x), width), col)
		elif from.x == to.x:
			rect(Rect2(from.x - width * 0.5, minf(from.y, to.y), width, absf(to.y - from.y)), col)
		else:
			_part(_key((from + to) * 0.5)).line(from, to, col, width)

	func circle(pos: Vector2, r: float, col: Color) -> void:
		var k0 := _key(pos - Vector2(r, r))
		var k1 := _key(pos + Vector2(r, r))
		if k0 == k1:
			_part(k0).circle(pos, r, col)
			return
		_clipped(Transform2D(0.0, Vector2(r, r), 0.0, pos) * Batch.circle_ring(), col)

	func polyline(points: PackedVector2Array, col: Color, width: float) -> void:
		var bounds := Rect2(points[0], Vector2.ZERO)
		for p in points:
			bounds = bounds.expand(p)
		bounds = bounds.grow(width)
		if _key(bounds.position) == _key(bounds.end):
			_part(_key(points[0])).polyline(points, col, width)
			return
		# Crossing a square's edge: cut each segment of the strip separately.
		var strip := Batch.new()
		strip.polyline(points, col, width)
		for i in range(0, strip.pts.size(), 6):
			var q := strip.pts
			_clipped(PackedVector2Array([q[i], q[i + 1], q[i + 4], q[i + 2]]), col)

	## A convex shape cut along the square edges it crosses.
	func _clipped(shape: PackedVector2Array, col: Color) -> void:
		var bounds := Rect2(shape[0], Vector2.ZERO)
		for p in shape:
			bounds = bounds.expand(p)
		var k0 := _key(bounds.position)
		var k1 := _key(bounds.end)
		for y in range(k0.y, k1.y + 1):
			for x in range(k0.x, k1.x + 1):
				var k := Vector2i(x, y)
				var sq := _square(k)
				var box := PackedVector2Array([sq.position, Vector2(sq.end.x, sq.position.y), sq.end, Vector2(sq.position.x, sq.end.y)])
				for piece in Geometry2D.intersect_polygons(shape, box):
					_part(k).polygon(piece, col)

	## Sends each square to its own canvas item under `parent`; returns them
	## (free them with RenderingServer.free_rid when redrawing).
	func flush(parent: RID, draw_index: int) -> Array:
		var items: Array = []
		for k in parts:
			var b: Batch = parts[k]
			if b.size() == 0:
				continue
			var ci := RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(ci, parent)
			RenderingServer.canvas_item_set_draw_index(ci, draw_index)
			RenderingServer.canvas_item_add_triangle_array(ci, PackedInt32Array(), b.pts, b.cols)
			items.append(ci)
		parts.clear()
		return items
