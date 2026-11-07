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
## ------------------------------------------------------------------------------

const Palette := preload("res://scripts/palette.gd")

const FEATHER_ALPHA := 0.35  # the soft ring under an outline
const LIGHT_DIR := Vector2(-0.6, -0.8)  # where the light comes from (screen)


## A soft oval shadow on the floor.
static func shadow(c: CanvasItem, pos: Vector2, r: float, alpha := 0.35) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(1.0, 0.45))
	circles(c, [Vector2.ZERO, Vector2.ZERO], [r * 1.1, r * 0.85], [Color(0, 0, 0, alpha * 0.5), Color(0, 0, 0, alpha * 0.6)])
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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

	func _color(col: Color, n: int) -> void:
		var c := PackedColorArray()
		c.resize(n)
		c.fill(col)
		cols.append_array(c)

	## Like draw_rect (filled).
	func rect(r: Rect2, col: Color) -> void:
		var a := r.position
		var b := r.end
		pts.append_array([a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)])
		_color(col, 6)

	## Like draw_line with a width (not antialiased).
	func line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		var t := (from - to).orthogonal().normalized() * width * 0.5
		pts.append_array([from + t, to + t, to - t, from + t, to - t, from - t])
		_color(col, 6)

	## Like draw_circle. Specks a pixel or two across can use fewer points.
	func circle(pos: Vector2, r: float, col: Color, points := CIRCLE_POINTS) -> void:
		var tris := circle_tris(points)
		pts.append_array(Transform2D(0.0, Vector2(r, r), 0.0, pos) * tris)
		_color(col, tris.size())

	## Like draw_colored_polygon (same triangulation).
	func polygon(points: PackedVector2Array, col: Color) -> void:
		var idx := Geometry2D.triangulate_polygon(points)
		for i in idx:
			pts.append(points[i])
		_color(col, idx.size())

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
		var l := light.normalized()
		dot(pos, r, col.darkened(0.35))
		dot(pos + l * r * 0.18, r * 0.86, col)
		dot(pos + l * r * 0.48, r * 0.34, Color(col.lightened(0.45), 0.55))

	## A thick outlined line with round ends, for blades, shafts and limbs.
	func stroke(a: Vector2, b: Vector2, col: Color, width: float) -> void:
		var o := width + 2.4
		line(a, b, Color(Palette.OUTLINE, FEATHER_ALPHA), o + 1.6)
		dot(a, (o + 1.6) * 0.5, Color(Palette.OUTLINE, FEATHER_ALPHA))
		dot(b, (o + 1.6) * 0.5, Color(Palette.OUTLINE, FEATHER_ALPHA))
		line(a, b, Palette.OUTLINE, o)
		dot(a, o * 0.5, Palette.OUTLINE)
		dot(b, o * 0.5, Palette.OUTLINE)
		line(a, b, col, width)

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
	func poly(points: PackedVector2Array, col: Color, outline := 1.6) -> void:
		if outline > 0.0:
			path(points, Color(Palette.OUTLINE, FEATHER_ALPHA), outline * 2.0 + 1.6, true)
			path(points, Palette.OUTLINE, outline * 2.0, true)
		polygon(points, col)

	## A sword lying along dir from the grip, with crossguard and pommel.
	func sword(grip: Vector2, dir: Vector2, length: float, glint := 0.0) -> void:
		var side := dir.orthogonal()
		var tip := grip + dir * length
		stroke(grip - dir * 5.0, grip, Palette.WOOD.darkened(0.3), 3.0)  # hilt
		stroke(grip + side * 5.0, grip - side * 5.0, Palette.STEEL.darkened(0.35), 2.5)  # crossguard
		stroke(grip + dir * 2.0, tip, Palette.STEEL.darkened(0.12), 3.2)  # blade
		line(grip + dir * 3.0 - side * 0.8, tip - dir * 1.0 - side * 0.8, Palette.STEEL.darkened(0.45), 1.0)  # its shaded edge
		line(grip + dir * 3.0 + side * 0.7, tip - dir * 2.0 + side * 0.7, Color(1, 1, 1, 0.55 + glint * 0.45), 1.0)
		dot(grip - dir * 6.0, 2.2, Palette.STEEL.darkened(0.2))  # pommel

	# The CanvasItem names, so drawing code can be handed a Batch instead.
	func draw_rect(r: Rect2, col: Color) -> void:
		rect(r, col)

	func draw_line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		line(from, to, col, width)

	func draw_circle(pos: Vector2, r: float, col: Color) -> void:
		circle(pos, r, col)

	func draw_colored_polygon(points: PackedVector2Array, col: Color) -> void:
		polygon(points, col)

	## Sends everything collected so far to `c` (at the current draw transform).
	func flush(c: CanvasItem) -> void:
		if pts.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), PackedInt32Array(), pts, cols)
		pts = PackedVector2Array()
		cols = PackedColorArray()


## A Batch split into squares of the world, each sent as its own canvas item.
## Godot lights a canvas item with every light that touches any part of it,
## so one floor-sized drawing pays for every torch on every pixel; split up,
## each square only pays for the lights near it, and squares off screen are
## skipped. Rects (and straight lines) are cut exactly at the square edges and
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
