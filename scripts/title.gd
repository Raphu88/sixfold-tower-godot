extends Control
## The title screen's backdrop, drawn in code: a night sky, a stone tower
## rising off the top of the screen with a few lit windows, drifting motes in
## the six essence colours and mist at its foot, plus the game's name.
## The menu (menu.gd) puts its buttons in the space `menu_rect()` leaves free.
##
## Drawn in three layers so phones stay light: the twinkling stars, the still
## scenery (sky, moon, hills, tower; redrawn only when the screen changes
## size), and the moving parts in front (windows, mist, motes, the name).
##
## The words shown here live in TEXT so they're easy to change.

const Essence := preload("res://scripts/essence.gd")
const Palette := preload("res://scripts/palette.gd")

const TEXT := {
	"title": "Sixfold Tower",
	"tagline": "Climb. Be regarded. Bear the marks.",
	"footer": "Prototype  ·  Sounds: CC0, see Credits",
}

const UI := preload("res://scripts/ui.gd")
const GOLD := UI.GOLD
const DIM := Color(0.62, 0.59, 0.67)
const SKY_TOP := Color(0.015, 0.015, 0.04)
const SKY_MID := Color(0.05, 0.045, 0.1)
const SKY_LOW := Color(0.14, 0.09, 0.15)
const STONE := Color(0.035, 0.03, 0.05)
const STONE_LIT := Color(0.42, 0.44, 0.62)
const MOON := Color(0.86, 0.87, 0.95)
const MOTES := 34
const STARS := 70

var t := 0.0
var sky: GradientTexture2D
var glow: GradientTexture2D
var title_font: FontVariation
var motes: Array = []  # {p, v, kind, life, age, size, phase}
var stars: Array = []  # {p (0..1), size, phase}
var rng := RandomNumberGenerator.new()
var stars_layer: Layer
var scene_layer: Layer
var front_layer: Layer

# Geometry that depends on the screen size, rebuilt when it changes.
var built_for := Vector2.ZERO
var far_hills := PackedVector2Array()
var near_hills := PackedVector2Array()
var tower_poly := PackedVector2Array()
var turret_poly := PackedVector2Array()
var windows: Array = []  # {c, w, h}
## How tall the menu's buttons are (set by the menu), so the name and the
## buttons can sit together in the middle of the screen.
var menu_h := 300.0
var show_name := true  # off behind the pages opened from the title


## A full-screen drawing surface that hands its drawing to a function.
class Layer extends Control:
	var paint: Callable

	func _init(fn: Callable) -> void:
		paint = fn
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([SKY_TOP, SKY_MID, SKY_LOW])
	sky = GradientTexture2D.new()
	sky.gradient = g
	sky.width = 4
	sky.height = 256
	sky.fill_from = Vector2(0, 0)
	sky.fill_to = Vector2(0, 1)
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	glow = GradientTexture2D.new()
	glow.gradient = gg
	glow.width = 64
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	# The name in the display face (Grenze Gotisch), set a little open.
	title_font = FontVariation.new()
	title_font.base_font = UI.font("display")
	title_font.spacing_glyph = 1
	for i in STARS:
		stars.append({"p": Vector2(rng.randf(), pow(rng.randf(), 1.6) * 0.72), "size": rng.randf_range(0.8, 1.9), "phase": rng.randf() * TAU})
	for i in MOTES:
		motes.append(_new_mote(true))
	stars_layer = Layer.new(_draw_stars)
	scene_layer = Layer.new(_draw_scene)
	front_layer = Layer.new(_draw_front)
	for l in [stars_layer, scene_layer, front_layer]:
		add_child(l)
	resized.connect(scene_layer.queue_redraw)


## Where the menu's buttons go: the column left of the tower, under the title.
func menu_rect(s: Vector2) -> Rect2:
	var top := _title_y(s) + _title_size(s) * 0.85 + 24.0
	return Rect2(Vector2(0, top), Vector2(s.x * 0.58, minf(menu_h, s.y * 0.94 - top)))


func _title_size(s: Vector2) -> int:
	return int(clampf(s.y * 0.095, 38.0, 70.0))


func _title_y(s: Vector2) -> float:
	# The title's baseline: the name and the menu together, centred (but never
	# too near the top).
	var fs := _title_size(s)
	var block := fs * 1.95 + 24.0 + menu_h
	return maxf(s.y * 0.06, (s.y * 0.95 - block) * 0.5) + fs


func _tower_x(s: Vector2) -> float:
	return s.x * 0.77


func _new_mote(anywhere: bool) -> Dictionary:
	var s := _size()
	var kinds: Array = Essence.KINDS.keys()
	return {
		"p": Vector2(rng.randf() * s.x, rng.randf_range(0.2, 1.0) * s.y if anywhere else s.y + 10.0),
		"v": Vector2(rng.randf_range(-6.0, 6.0), -rng.randf_range(9.0, 24.0)),
		"kind": kinds[rng.randi() % kinds.size()],
		"life": rng.randf_range(10.0, 20.0),
		"age": rng.randf() * 6.0 if anywhere else 0.0,
		"size": rng.randf_range(1.4, 2.8),
		"phase": rng.randf() * TAU,
	}


func _size() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	for i in motes.size():
		var m: Dictionary = motes[i]
		m["age"] += delta
		m["p"] += (m["v"] + Vector2(sin(t * 0.5 + m["phase"]) * 7.0, 0.0)) * delta
		if m["age"] > m["life"] or m["p"].y < -10.0:
			motes[i] = _new_mote(false)
	stars_layer.queue_redraw()
	front_layer.queue_redraw()


func _build(s: Vector2) -> void:
	built_for = s
	var u := s.y / 720.0
	far_hills = _ridge(s, s.y * 0.8, 34.0 * u, 3, 0.9)
	near_hills = _ridge(s, s.y * 0.905, 16.0 * u, 2, 2.3)
	# The tower: a tall, slightly tapering column on the right.
	var cx := _tower_x(s)
	var base := s.y * 0.9
	tower_poly = PackedVector2Array([
		Vector2(cx - _half_width(base + 20.0, s), base + 20.0), Vector2(cx - _half_width(-10.0, s), -10.0),
		Vector2(cx + _half_width(-10.0, s), -10.0), Vector2(cx + _half_width(base + 20.0, s), base + 20.0)])
	# A squat turret leaning on its left side, with battlements.
	var tl := cx - _half_width(base, s) - 62.0 * u
	var tr := cx - _half_width(base, s) + 10.0 * u
	var top := base - 250.0 * u
	turret_poly = PackedVector2Array([Vector2(tl, base + 20.0), Vector2(tl, top)])
	var mw := (tr - tl) / 5.0
	for i in 5:
		var up := top - (12.0 * u if i % 2 == 0 else 0.0)
		turret_poly.append(Vector2(tl + mw * i, up))
		turret_poly.append(Vector2(tl + mw * (i + 1), up))
	turret_poly.append(Vector2(tr, top))
	turret_poly.append(Vector2(tr, base + 20.0))
	# Lit windows: [x offset (share of the half-width), height above the base, width, height].
	windows.clear()
	for w in [[0.0, 26.0, 26.0, 40.0], [-0.45, 170.0, 10.0, 22.0], [0.5, 300.0, 10.0, 22.0],
			[-0.1, 450.0, 11.0, 24.0], [0.4, 600.0, 10.0, 22.0], [-0.5, 690.0, 9.0, 20.0]]:
		var y: float = base - w[1] * u
		windows.append({"c": Vector2(cx + w[0] * _half_width(y, s), y), "w": w[2] * u, "h": w[3] * u})
	windows.append({"c": Vector2((tl + tr) * 0.5 - 4.0 * u, base - 150.0 * u), "w": 7.0 * u, "h": 15.0 * u})


func _ridge(s: Vector2, y: float, amp: float, waves: int, seed_off: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-10, s.y + 10)])
	var n := 24
	for i in n + 1:
		var x := s.x * float(i) / float(n)
		var k := float(i) / float(n) * TAU * waves
		pts.append(Vector2(x, y - amp * (0.6 * sin(k + seed_off) + 0.4 * sin(k * 2.3 + seed_off * 3.0))))
	pts.append(Vector2(s.x + 10, s.y + 10))
	return pts


## The tower's half-width at a height on screen (it tapers as it rises).
func _half_width(y: float, s: Vector2) -> float:
	var k := clampf(y / (s.y * 0.9), 0.0, 1.0)
	return lerpf(78.0, 98.0, k) * s.y / 720.0


# --- the layers ------------------------------------------------------------------

func _draw_stars(c: CanvasItem) -> void:
	var s := _size()
	c.draw_texture_rect(sky, Rect2(Vector2.ZERO, s), false)
	for st in stars:
		var a := 0.35 + 0.3 * sin(t * 0.8 + st["phase"])
		c.draw_rect(Rect2(st["p"] * s, Vector2.ONE * st["size"]), Color(0.85, 0.85, 1.0, a))


func _draw_scene(c: CanvasItem) -> void:
	var s := _size()
	_build(s)
	var u := s.y / 720.0
	var cx := _tower_x(s)
	var base := s.y * 0.9
	# A pale moon, half hidden behind the tower, and a warm glow on the horizon.
	var moon := Vector2(cx - 120.0 * u, s.y * 0.3)
	_glow(c, moon, Vector2.ONE * 520.0 * u, Color(0.45, 0.47, 0.7, 0.16))
	_glow(c, moon, Vector2.ONE * 190.0 * u, Color(0.7, 0.72, 0.9, 0.2))
	c.draw_circle(moon, 54.0 * u, Color(MOON, 0.85))
	c.draw_circle(moon + Vector2(-14, 12) * u, 13.0 * u, Color(0.7, 0.71, 0.82, 0.5))
	c.draw_circle(moon + Vector2(18, -16) * u, 8.0 * u, Color(0.7, 0.71, 0.82, 0.45))
	c.draw_circle(moon + Vector2(10, 22) * u, 6.0 * u, Color(0.7, 0.71, 0.82, 0.4))
	_glow(c, Vector2(s.x * 0.5, s.y * 0.95), Vector2(s.x * 1.3, 260.0 * u), Color(0.6, 0.3, 0.25, 0.16))
	c.draw_colored_polygon(far_hills, Color(0.06, 0.05, 0.085))

	# The tower and its turret.
	c.draw_colored_polygon(turret_poly, STONE)
	c.draw_colored_polygon(tower_poly, STONE)
	# Stone courses with staggered joints, and a ledge every few courses.
	var y := base - 18.0 * u
	var row := 0
	var course := 19.0 * u
	while y > -10.0:
		var hw := _half_width(y, s)
		if row % 9 == 8:
			var lw := hw + 9.0 * u
			c.draw_rect(Rect2(cx - lw, y - 7.0 * u, lw * 2.0, 9.0 * u), Color(0.05, 0.045, 0.07))
			c.draw_line(Vector2(cx - lw, y - 7.0 * u), Vector2(cx + lw, y - 7.0 * u), Color(STONE_LIT, 0.28), 1.0)
			c.draw_rect(Rect2(cx - lw, y + 2.0 * u, lw * 2.0, 3.0 * u), Color(0, 0, 0, 0.35))
		else:
			c.draw_line(Vector2(cx - hw, y), Vector2(cx + hw, y), Color(1, 1, 1, 0.03), 1.0)
			var bw := 34.0 * u
			var x := cx - hw + (bw * 0.5 if row % 2 == 0 else bw)
			while x < cx + hw - 4.0:
				c.draw_line(Vector2(x, y), Vector2(x, y - course), Color(1, 1, 1, 0.022), 1.0)
				x += bw
		y -= course
		row += 1
	# Moonlight catches the left edges; the right side falls into shadow.
	c.draw_colored_polygon(PackedVector2Array([tower_poly[0], tower_poly[1],
		tower_poly[1] + Vector2(26.0 * u, 0), tower_poly[0] + Vector2(30.0 * u, 0)]), Color(STONE_LIT, 0.05))
	c.draw_line(tower_poly[0], tower_poly[1], Color(STONE_LIT, 0.5), 1.5)
	c.draw_line(turret_poly[0], turret_poly[1], Color(STONE_LIT, 0.35), 1.0)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + _half_width(base, s) * 0.3, base + 20.0), Vector2(cx + _half_width(0, s) * 0.3, -10.0),
		tower_poly[2], tower_poly[3]]), Color(0, 0, 0, 0.32))


func _draw_front(c: CanvasItem) -> void:
	var s := _size()
	if s != built_for:
		scene_layer.queue_redraw()
		_build(s)
	var u := s.y / 720.0
	var font := ThemeDB.fallback_font
	# Windows: warm, slowly breathing light.
	for i in windows.size():
		var w: Dictionary = windows[i]
		var wc: Vector2 = w["c"]
		var ww: float = w["w"]
		var wh: float = w["h"]
		var f := 0.82 + 0.12 * sin(t * 1.3 + i * 1.7) + 0.06 * sin(t * 4.1 + i)
		_glow(c, wc, Vector2(ww * 8.0, wh * 4.0), Color(Palette.TORCH, 0.2 * f))
		var col := Color(Palette.TORCH.lerp(Color(1.0, 0.86, 0.6), 0.3), f)
		var arch := Vector2(wc.x, wc.y - wh * 0.5 + ww * 0.5)
		c.draw_rect(Rect2(wc.x - ww * 0.5, arch.y, ww, wh - ww * 0.5), col)
		c.draw_circle(arch, ww * 0.5, col)
		c.draw_rect(Rect2(wc.x - ww * 0.5 - 1.5, wc.y + wh * 0.5 - 1.0, ww + 3.0, 3.0), Color(0.08, 0.07, 0.1))
	c.draw_colored_polygon(near_hills, Color(0.02, 0.018, 0.03))
	# Mist drifting slowly at the foot of the tower.
	for i in 7:
		var span := s.x + 500.0 * u
		var mx := fposmod(span * (i / 7.0) + t * (5.0 + i * 1.3), span) - 250.0 * u
		var my := s.y * (0.85 + 0.03 * (i % 3))
		_glow(c, Vector2(mx, my), Vector2(520, 110) * u, Color(0.55, 0.55, 0.72, 0.09))
	# Motes of essence rising.
	for m in motes:
		var age: float = m["age"]
		var life: float = m["life"]
		var a := minf(age / 2.0, 1.0) * minf((life - age) / 2.5, 1.0)
		a *= 0.65 + 0.35 * sin(t * 2.0 + m["phase"])
		if a <= 0.0:
			continue
		var col := Essence.color(m["kind"])
		var mp: Vector2 = m["p"]
		var r: float = m["size"] * maxf(u, 0.8)
		_glow(c, mp, Vector2.ONE * r * 11.0, Color(col, 0.4 * a))
		c.draw_circle(mp, r * 0.75, Color(col.lightened(0.35), a))

	c.draw_string(font, Vector2(16, s.y - 10), TEXT["footer"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(DIM, 0.7))
	if not show_name:
		return
	# The name, a small ornament and the tagline (an inscription: the fine italic).
	var col_w := s.x * 0.58
	var fs := _title_size(s)
	var ns := int(fs * 1.4)  # (Grenze Gotisch is small for its size, in mixed case)
	var ty := _title_y(s) + fs * 0.12
	var name: String = UI.title_case(TEXT["title"])
	_glow(c, Vector2(col_w * 0.5, ty - ns * 0.3), Vector2(minf(col_w * 0.9, ns * 9.0), ns * 2.2), Color(UI.GILT, 0.1))
	c.draw_string_outline(title_font, Vector2(0, ty + 4.0), name, HORIZONTAL_ALIGNMENT_CENTER, col_w, ns, 12, Color(0, 0, 0, 0.5))
	c.draw_string_outline(title_font, Vector2(0, ty), name, HORIZONTAL_ALIGNMENT_CENTER, col_w, ns, 4, Color(0.22, 0.12, 0.04, 0.95))
	c.draw_string(title_font, Vector2(0, ty), name, HORIZONTAL_ALIGNMENT_CENTER, col_w, ns, UI.GILT)
	# A lit upper edge: the name again, a shade lighter, a pixel up.
	c.draw_string(title_font, Vector2(0, ty - 1.0), name, HORIZONTAL_ALIGNMENT_CENTER, col_w, ns, Color(UI.GILT_HI, 0.35))
	var ts := int(clampf(fs * 0.38, 17.0, 26.0))
	var half := minf(col_w * 0.3, 180.0)
	var d := ty + fs * 0.3
	UI.draw_divider(c, Vector2(col_w * 0.5 - half, d), Vector2(col_w * 0.5 + half, d), Color(UI.GILT, 0.8))
	var tag_y := d + ts + 8.0
	var it := UI.font("inscription")
	c.draw_string_outline(it, Vector2(0, tag_y), TEXT["tagline"], HORIZONTAL_ALIGNMENT_CENTER, col_w, ts, 4, Color(0, 0, 0, 0.6))
	c.draw_string(it, Vector2(0, tag_y), TEXT["tagline"], HORIZONTAL_ALIGNMENT_CENTER, col_w, ts, Color(UI.TEXT, 0.88))


## A soft blob of light (or shadow) of a size and colour.
func _glow(c: CanvasItem, at: Vector2, sz: Vector2, col: Color) -> void:
	c.draw_texture_rect(glow, Rect2(at - sz * 0.5, sz), false, col)
