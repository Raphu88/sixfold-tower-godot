extends RefCounted
## THE SHADING TOOLKIT: volume for code-drawn shapes, for next to nothing.
##
## Everything in the tower is drawn in code from flat shapes. This gives them
## form the same way everywhere, lit from the top-left of the screen
## (LIGHT, the same as Draw.LIGHT_DIR and the icons' light):
##
##   BALL   a sphere: lit top-left, a soft highlight, a shaded core toward
##          the lower right, a faint bounce light on the shadowed rim
##   SLAB   a flat face: a gentle light-to-dark gradient along the light,
##          a touch of contact darkness along its lower-right edges
##   TUBE   a cylinder across a stroke's width: a lit edge and a shaded one
##   SOFT   a soft round falloff (alpha): drop shadows, glows, contact shade
##   WOOD   SLAB with fine wood grain running along u
##   METAL  SLAB with stronger contrast and a bright sheen band
##   CLOTH  SLAB with soft vertical folds
##   FORM   a standing figure's overall light (the paper doll): a tall
##          cylinder lit from the left, a little darker toward the feet
##   DOME   a figure seen from above (the climber in the tower): one soft
##          dome lit from the top-left, under each part's own shading
##   WHITE  no shading (UV (0, 0): what every un-shaded vertex reads)
##
## How it works: ONE small texture (built in code at first use: tex()) holds
## each material's shading as a brightness, divided by GAIN. A shaded shape
## carries UVs into that texture and its colour times GAIN, so the graphics
## card multiplies them back: the shape's own colour where the texture says
## 1/GAIN, brighter on the lit side, darker in shadow. Vertex colours above
## 1 work in the Compatibility renderer (desktop, web and phones), and the
## texture is shared by every shaded batch, so it costs one texture read a
## pixel and a few UVs a shape: no shader, no material, no extra draw call.
##
## Using it:
##   * Draw.Batch (draw_util.gd) and the monsters' Pen (enemy.gd) do it for
##     you: their character helpers (ball, stroke, limb, poly, egg, quad ...)
##     come out shaded. The plain primitives (rect, line, circle, polygon:
##     "like draw_rect" etc.) stay flat, so icons, text plates and HUD bars
##     look exactly as before.
##   * Shaded primitives on a Batch: b.disc (BALL), b.box / b.fill (SLAB or
##     any material), b.bar (TUBE), b.soft (SOFT), b.grad_rect / b.grad_poly
##     (two-colour gradients), b.rim (a lit-edge highlight), b.contact
##     (a soft shadow on the floor). Pass a material id (Shade.WOOD ...).
##   * A batch drawn in a rotated frame sets b.light to the screen's light
##     turned into its frame (like Batch.ball's light), so shading stays
##     screen-lit.
##   * Raw CanvasItem code: Shade.contact(ci, pos, r) for a floor shadow,
##     Shade.draw_tris() to draw saved shaded triangles (remains, bestiary).
##   * Something that must stay flat on a Batch: use the plain primitives,
##     or set b.shaded = false (the helpers then draw their old flat look).
##   * Settings: `on` (false: every helper draws flat, the pre-toolkit look).
##     Lighting Low turns it off (lighting.gd): building UVs costs the CPU a
##     little (about a quarter more per character), which Low saves.
##
## Tuning: strengths are the numbers in _shade_at(); keep the lit side under
## GAIN and the average near 1 so colours keep their brightness.

const LIGHT := Vector2(-0.6, -0.8)  # toward the light (screen): the top-left

const WHITE := 0
const BALL := 1
const SLAB := 2
const TUBE := 3
const SOFT := 4
const WOOD := 5
const METAL := 6
const CLOTH := 7
const FORM := 8
const DOME := 9
const REGIONS := 10

const CELL := 48  # each material's square in the texture, in pixels
const GAIN := 1.5  # the brightest the texture can make a colour

## Off: every helper draws flat (Settings -> Lighting -> Low sets this,
## lighting.gd set_quality, so Low keeps the plain look at the old cost).
static var on := true

static var _tex: ImageTexture
static var _disc_uv := {}  # "points:material:angle" -> unit circle tris' UVs
static var _box_uv := {}  # material -> a rect's 6 UVs (unrotated)


## The shared shading texture.
static func tex() -> Texture2D:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_build())
	return _tex


static func rid() -> RID:
	return tex().get_rid()


## A colour ready for a shaded vertex (times GAIN; alpha kept).
static func gain(c: Color) -> Color:
	return Color(c.r * GAIN, c.g * GAIN, c.b * GAIN, c.a)


## The transform from a material's unit square (0..1) to its texture UVs.
static func region(m: int) -> Transform2D:
	var w := float(CELL * REGIONS)
	var k := float(CELL - 2)
	return Transform2D(Vector2(k / w, 0.0), Vector2(0.0, k / CELL), Vector2((m * CELL + 1.0) / w, 1.0 / CELL))


## How far `light` is turned from the screen's light (0 on an unrotated canvas).
static func turn(light: Vector2) -> float:
	if light == LIGHT or light == Vector2.ZERO:
		return 0.0
	return LIGHT.angle_to(light)


## UVs for a circle's triangles (Batch.circle_tris / Pen.fan of `points`),
## lit as material `m` (BALL or SOFT), turned by `ang`.
static func disc_uvs(tris: PackedVector2Array, points: int, m: int, ang := 0.0) -> PackedVector2Array:
	var qi := int(roundf(wrapf(ang, -PI, PI) / 0.05))  # (turned in steps of 0.05 radians)
	var key := (points * 16 + m) * 256 + qi + 128
	var hit = _disc_uv.get(key)
	if hit == null:
		if _disc_uv.size() > 2048:
			_disc_uv.clear()
		# unit circle (-1..1) -> turned back into the texture's frame -> 0..1 -> region
		hit = region(m) * Transform2D(-qi * 0.05, Vector2(0.5, 0.5), 0.0, Vector2(0.5, 0.5)) * tris
		_disc_uv[key] = hit
	return hit


## Per-point UVs for a shape lit as a flat face (SLAB, WOOD, METAL, CLOTH):
## its bounds, turned by `ang`, fill the material's square.
static func face_uvs(points: PackedVector2Array, m: int, ang := 0.0) -> PackedVector2Array:
	var q := points
	if ang != 0.0:
		q = Transform2D(-ang, Vector2.ZERO) * points
	var mn := q[0]
	var mx := q[0]
	for p in q:
		mn = mn.min(p)
		mx = mx.max(p)
	var span := (mx - mn).max(Vector2(0.001, 0.001))
	return region(m) * Transform2D(0.0, Vector2.ONE / span, 0.0, -mn / span) * q


## A rect's two triangles' UVs (a, b-top-right, b, a, b, a-bottom-left).
static func box_uvs(m: int) -> PackedVector2Array:
	var hit = _box_uv.get(m)
	if hit == null:
		hit = region(m) * PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
		_box_uv[m] = hit
	return hit


## A soft shadow on the floor under something standing at `pos` (r: its
## half-width), in one quad. For raw CanvasItem drawing; a Batch has contact().
static func contact(ci: CanvasItem, pos: Vector2, r: float, alpha := 0.42, flat := 0.42) -> void:
	var rad := Vector2(r * 1.25, r * 1.25 * flat)
	var a := pos - rad
	var e := pos + rad
	var c := PackedColorArray()
	c.resize(6)
	c.fill(Color(0, 0, 0, alpha))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), PackedVector2Array([a, Vector2(e.x, a.y), e, a, e, Vector2(a.x, e.y)]), c, box_uvs(SOFT), PackedInt32Array(), PackedFloat32Array(), rid())


## Draws saved triangles (with their UVs when they were shaded).
static func draw_tris(item: RID, pts: PackedVector2Array, cols: PackedColorArray, uvs := PackedVector2Array()) -> void:
	if pts.is_empty():
		return
	if uvs.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), pts, cols)
		return
	if uvs.size() != pts.size():
		uvs = uvs.duplicate()
		uvs.resize(pts.size())
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), rid())


# --- building the texture ---------------------------------------------------------

static func _build() -> Image:
	var img := Image.create(CELL * REGIONS, CELL, false, Image.FORMAT_RGBA8)
	var l2 := LIGHT.normalized()
	var l3 := Vector3(l2.x, l2.y, 1.05).normalized()
	for m in REGIONS:
		for y in CELL:
			for x in CELL:
				var u := (x - 1.0) / (CELL - 2.0)
				var v := (y - 1.0) / (CELL - 2.0)
				var c := _shade_at(m, clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0), l2, l3)
				img.set_pixel(m * CELL + x, y, c)
	return img


## A brightness as a texel: shadows lean cool (toward the night's violet,
## like the icons' SHADOW_TINT) and light leans warm, so shading reads as
## light on a surface instead of grey dirt.
static func _px(s: float) -> Color:
	var t := clampf((1.0 - s) / 0.45, 0.0, 1.0)
	var h := clampf((s - 1.0) / 0.3, 0.0, 1.0)
	var c := Vector3(s * (1.0 - 0.1 * t + 0.04 * h), s * (1.0 - 0.04 * t + 0.01 * h), s * (1.0 + 0.16 * t - 0.07 * h)) / GAIN
	return Color(clampf(c.x, 0.0, 1.0), clampf(c.y, 0.0, 1.0), clampf(c.z, 0.0, 1.0), 1.0)


static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)


static func _shade_at(m: int, u: float, v: float, l2: Vector2, l3: Vector3) -> Color:
	# d: -1 (away from the light) .. 1 (toward it) across a flat face
	var d := ((u - 0.5) * l2.x + (v - 0.5) * l2.y) / 0.7071
	match m:
		WHITE:
			return Color(1, 1, 1, 1)
		BALL:
			var p := Vector2(u * 2.0 - 1.0, v * 2.0 - 1.0)
			var r := minf(p.length(), 1.0)
			if p.length() > 1.0:
				p = p / p.length()
			var n := Vector3(p.x, p.y, sqrt(maxf(0.0, 1.0 - r * r)))
			var lit := n.dot(l3)
			var s := lerpf(0.52, 1.22, smoothstep(-0.4, 0.95, lit))
			# the highlight: a soft sheen near the lit side
			var h := Vector3(l3.x, l3.y, l3.z + 1.0).normalized()
			s += 0.34 * pow(maxf(n.dot(h), 0.0), 16.0)
			# the rim on the shadowed side: darker, then a faint bounce light right at the edge
			var away := clampf(-p.normalized().dot(l2) if r > 0.001 else 0.0, 0.0, 1.0)
			s -= 0.08 * smoothstep(0.55, 0.95, r) * away
			s += 0.07 * smoothstep(0.86, 1.0, r) * away
			return _px(s)
		SLAB:
			return _px(_face(u, v, d, 0.22))
		TUBE:
			# u: 0 the lit edge .. 1 the shaded edge
			var x := u * 2.0 - 1.0
			var n2 := Vector2(x, sqrt(maxf(0.0, 1.0 - x * x)))
			var lit2 := n2.dot(Vector2(-0.62, 0.78))
			var s2 := lerpf(0.6, 1.22, smoothstep(-0.35, 1.0, lit2))
			s2 += 0.18 * pow(maxf(lit2, 0.0), 16.0)
			return _px(s2)
		SOFT:
			var r3 := Vector2(u * 2.0 - 1.0, v * 2.0 - 1.0).length()
			var a := clampf(1.0 - r3, 0.0, 1.0)
			return Color(1, 1, 1, a * a * (3.0 - 2.0 * a))
		WOOD:
			var s4 := _face(u, v, d, 0.16)
			var g := sin(v * TAU * 6.5 + 1.8 * sin(u * 5.0 + v * 3.0) + 0.6 * sin(u * 13.0))
			s4 *= 1.0 + 0.07 * g - 0.05 * absf(g) * absf(g) * absf(g)
			s4 *= 1.0 + 0.04 * (_hash(floorf(u * 24.0), floorf(v * 8.0)) - 0.5)
			return _px(s4)
		METAL:
			var s5 := _face(u, v, d, 0.26)
			var band := d - 0.32
			s5 += 0.26 * exp(-band * band * 40.0)  # a bright sheen band toward the light
			s5 -= 0.08 * exp(-(d + 0.55) * (d + 0.55) * 30.0)  # a darker reflection below it
			return _px(s5)
		CLOTH:
			var s6 := _face(u, v, d, 0.14)
			var fold := sin(u * TAU * 2.5 + 0.8 * sin(v * 3.0)) * 0.5 + 0.5
			s6 *= 1.0 - 0.1 * fold * fold + 0.04 * (1.0 - fold)
			return _px(s6)
		FORM:
			var x := u * 2.0 - 1.0
			var n3 := Vector2(x, sqrt(maxf(0.0, 1.0 - x * x)))
			var lit3 := n3.dot(Vector2(-0.55, 0.835))
			var s7 := lerpf(0.62, 1.16, smoothstep(-0.5, 1.0, lit3))
			s7 *= lerpf(1.0, 0.84, smoothstep(0.2, 1.0, v))  # toward the feet, out of the light
			return _px(s7)
		DOME:
			var p4 := Vector2(u * 2.0 - 1.0, v * 2.0 - 1.0)
			var r4 := minf(p4.length(), 1.0)
			var n4 := Vector3(p4.x, p4.y, sqrt(maxf(0.0, 1.0 - r4 * r4)) + 0.35).normalized()
			var lit4 := n4.dot(l3)
			return _px(lerpf(0.62, 1.2, smoothstep(0.0, 1.0, lit4)))
	return Color(1, 1, 1, 1)


## A flat face: brighter toward the light, a soft dark edge along its
## lower-right sides (where it meets what's under it), a faint lit edge
## along the top-left.
static func _face(u: float, v: float, d: float, k: float) -> float:
	var s := 1.0 + k * d
	var e := minf(1.0 - u, 1.0 - v)
	s -= 0.07 * (1.0 - smoothstep(0.0, 0.14, e))
	var t := minf(u, v)
	s += 0.05 * (1.0 - smoothstep(0.0, 0.1, t))
	return s
