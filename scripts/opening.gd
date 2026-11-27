extends Control
## THE OPENING: the Entity's six screens about the world (new_start.gd
## INTRO), each with its own slow painted scene drawn in code behind the
## words (menu.gd shows it under the "intro" page; start_pages.gd builds the
## words and the buttons over it, at the bottom of the screen).
##
##   1  the world tearing: a turning world cracks and six essences stream out
##      of it wild, until six robed figures stand in a ring round it and bind
##      it with light (the Regard's glimpse of the fracture: fracture.gd)
##   2  six towers in an arc over six glowing wells, a guardian over each (the
##      Bestiary's own drawings), marks of light drifting down to the people
##      standing on the hill below
##   3  the dead land at night, a storm of wild essence far off, distant cities
##      on the horizon, and the Turning (engine, lit cars, steam) running
##      across it on essence
##   4  a city lit by crystals at the foot of its tower: rooftops, lamps,
##      bunting, the crystals' light running down the road, and marked
##      climbers coming down it
##   5  inside a carriage: the conductor's nod on the platform, the doors
##      sliding shut, the train moving off and a tower growing in the window
##   6  the seat beside you, and the Entity (entity.gd's face) gathering out of
##      sparks onto it
##
## Each scene is painted in layers (sky, far, middle, near) that a slow camera
## push or pan moves at different speeds (parallax), with mist, glows, light
## shafts and a vignette; everything is lit from the top-left (the shading
## toolkit, shade.gd via draw_util.gd Batch). The words stay flat, on a dark
## band.
##
## Light for a phone: each layer is one Batch (the still ones are built once
## and kept: _baked), redrawn at most OPENING "fps" times a second, a few
## drifting specks scaled by the Effects setting (particles.gd EFFECTS), no
## shaders. A click or tap on the picture goes on (tapped; the menu's Next
## does the same for Enter, Space and A).
## The music: the story track's six tolls, one for each screen
## (audio.gd story_toll). Its numbers are here (the Data editor).

signal tapped

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Fracture := preload("res://scripts/fracture.gd")
const Particles := preload("res://scripts/particles.gd")
const Palette := preload("res://scripts/palette.gd")
const Shade := preload("res://scripts/shade.gd")

## "fade_in": seconds a screen takes to come up out of the dark;
## "tap_after": a tap on the picture goes on only after this long on a
## screen (so one tap never skips two); "fps": the most redraws a second;
## "motes": how many drifting specks a screen shows at Effects Medium (Low
## shows a few, High a little more); "camera": seconds the slow camera
## push takes from its start to its end.
static var OPENING := {"fade_in": 0.8, "tap_after": 0.35, "fps": 30.0, "motes": 18, "camera": 16.0}
## The six essences, in the order the screens use them (one for each tower).
const KINDS := ["air", "water", "iron", "fire", "stone", "blade"]
## The tower the fourth screen's city stands under.
const CITY_TOWER := "firebird"
const SCREENS := 6
## Where the light comes from on the first screen's world (x right, y down,
## z toward us): the top-left, like everything else.
const SUN := Vector3(-0.52, -0.58, 0.62)

var main  # main.gd: the music and the climber's look (may be null in tests)
var line := 0  # the screen showing (0..5)
var t := 0.0  # seconds on this screen (real time: the game is paused under the menu)
var clock := 0.0  # seconds since it was made (for motion that carries on across screens)
var text_top := -1.0  # where the words begin (menu.gd _layout); -1: near the bottom
var draws := 0  # how many times a whole screen has drawn (tests)
var layers := 0  # how many layers the last screen drew (tests)
var draw_us := 0  # how long the last screen took to build, in microseconds (tests)
var _shown := -1
var _last_us := 0
var _redraw := 0.0
var _u := 1.0  # the size of things, from the screen
var Entity: GDScript
var Story: GDScript
var Bestiary: GDScript
var Appearance: GDScript
# The camera of the screen showing: it pushes in toward `_focus` by `_push`
# (at depth 1) and drifts by `_pan`, slowly, over OPENING "camera" seconds.
var _focus := Vector2.ZERO
var _push := 0.0
var _pan := Vector2.ZERO
var _sway := Vector2.ZERO  # a small smooth shift of the whole picture (the carriage rocking)
var _cache := {}  # still layers, built once: key -> [points, colours, uvs]
var _tints := {}  # the guardians' drawings and their colours at a strength (kept while showing)
static var _lands := []  # the first screen's continents: [lon/lat outline, colour]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Entity = load("res://scripts/entity.gd")
	Story = load("res://scripts/story_scenes.gd")
	Bestiary = load("res://scripts/bestiary.gd")
	Appearance = load("res://scripts/appearance.gd")
	visibility_changed.connect(func():
		if not visible:
			_shown = -1
			_cache.clear()
			_tints.clear())
	_last_us = Time.get_ticks_usec()


## Shows screen `i` (0..5): a new screen starts its scene from the dark.
func show_line(i: int) -> void:
	line = clampi(i, 0, SCREENS - 1)
	if line != _shown:
		_shown = line
		t = 0.0
		_redraw = 0.0
		queue_redraw()


## A tap on the picture may go on (not straight after a screen changed).
func can_tap() -> bool:
	return t >= float(OPENING["tap_after"])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if not is_visible_in_tree():
		return
	t += dt
	clock += dt
	if main != null and is_instance_valid(main) and "audio" in main and main.audio != null and is_instance_valid(main.audio):
		main.audio.story_toll(line)  # (one toll for each screen)
	_redraw -= dt
	if _redraw <= 0.0:
		_redraw = 1.0 / maxf(float(OPENING["fps"]), 1.0)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		tapped.emit()


## How many specks to show for `base` at the Effects setting.
func _count(base: int) -> int:
	var k := float(Particles.EFFECTS.get(Particles.level, {}).get("count", 1.0))
	return maxi(2, int(round(float(base) * minf(k, 1.4))))


func _view() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


## Where the picture ends and the words begin.
func stage_height(s := Vector2.ZERO) -> float:
	if s == Vector2.ZERO:
		s = _view()
	var top := text_top if text_top > 0.0 else s.y * 0.72
	return clampf(top, s.y * 0.35, s.y)


func _draw() -> void:
	var s := _view()
	var t0 := Time.get_ticks_usec()
	var h := stage_height(s)
	_u = clampf(minf(h / 430.0, s.x / 760.0), 0.45, 1.8)
	layers = 0
	_sway = Vector2.ZERO
	match line:
		0:
			_world(s, h)
		1:
			_towers(s, h)
		2:
			_turning(s, h)
		3:
			_city(s, h)
		4:
			_carriage(s, h)
		_:
			_seat(s, h)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# The words' band: flat and dark, so they read over any scene.
	var band := UI.Draw.Batch.new()
	Art.vgrad(band, Rect2(0, h - 80.0 * _u, s.x, 80.0 * _u + 14.0), Color(Art.SHADOW, 0.0), Color(Art.SHADOW, 0.88))
	band.rect(Rect2(0, h + 14.0, s.x, maxf(s.y - h - 14.0, 0.0)), Color(Art.SHADOW, 0.88))
	band.flush(self)
	# Each screen comes up out of the dark.
	var dark := 1.0 - smoothstep(0.0, float(OPENING["fade_in"]), t)
	if dark > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, dark))
	draws += 1  # (counted once the whole screen has drawn: tests)
	draw_us = Time.get_ticks_usec() - t0


# --- the camera, the layers and the kept ones -----------------------------------------

## Smooth from 0 to 1 and back to rest (a sine in and out).
static func _ease(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(x, 0.0, 1.0))


## The screen's camera for a layer at `depth` (0: the sky, which hardly
## moves; 1: the subject; more: the foreground, which moves most).
func _cam(depth: float) -> Transform2D:
	var e := _ease(t / maxf(float(OPENING["camera"]), 1.0))
	var z := 1.0 + _push * e * depth
	var off := _pan * e * depth
	return Transform2D(0.0, Vector2(z, z), 0.0, _focus + off - _focus * z + _sway)


## Sends a layer to the screen through the camera at `depth`.
func _put(b, depth: float) -> void:
	draw_set_transform_matrix(_cam(depth))
	b.flush(self)
	layers += 1


## A still layer, built by `build` (given a Batch) the first time and kept
## (for this screen at this size), then drawn through the camera at `depth`.
func _baked(key: String, s: Vector2, h: float, depth: float, build: Callable) -> void:
	var k := "%d:%s:%dx%d:%d:%d" % [line, key, int(s.x), int(h), int(Shade.on), int(_u * 100.0)]
	if not _cache.has(k):
		if _cache.size() > 24:
			_cache.clear()
		var b := UI.Draw.Batch.new()
		build.call(b)
		var uvs: PackedVector2Array = b.uvs
		if not uvs.is_empty():
			uvs.resize(b.pts.size())
		_cache[k] = [b.pts, b.cols, uvs]
	var got: Array = _cache[k]
	draw_set_transform_matrix(_cam(depth))
	Shade.draw_tris(get_canvas_item(), got[0], got[1], got[2])
	layers += 1


# --- shared pieces -------------------------------------------------------------------

## A sky down a rect through colour stops: [[0..1 down the rect, colour], ...].
static func _sky(b, r: Rect2, stops: Array) -> void:
	for i in stops.size() - 1:
		var f0: float = stops[i][0]
		var f1: float = stops[i + 1][0]
		Art.vgrad(b, Rect2(r.position.x, r.position.y + r.size.y * f0, r.size.x, r.size.y * (f1 - f0) + 0.5), stops[i][1], stops[i + 1][1])


## Stars in `area`, twinkling a little; every ninth a bright one with a glint.
func _stars(b, area: Rect2, n: int, seed: int, a := 1.0) -> void:
	for i in n:
		var p := area.position + Vector2(Art.rnd(i * 3 + seed), Art.rnd(i * 7 + seed + 1)) * area.size
		var tw := 0.65 + 0.35 * sin(clock * (0.6 + Art.rnd(i + seed) * 1.2) + float(i))
		var big := i % 9 == 0
		var sz := (1.6 if big else 0.9 + Art.rnd(i * 5 + seed) * 0.9) * maxf(_u, 0.7)
		var al := (0.75 if big else 0.2 + 0.4 * Art.rnd(i * 11 + seed)) * tw * a
		b.rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(Art.STAR, al))
		if big:
			b.soft(p, Vector2.ONE * sz * 3.5, Color(Art.STAR, al * 0.35))
			b.rect(Rect2(p - Vector2(sz * 3.0, 0.4), Vector2(sz * 6.0, 0.8)), Color(Art.STAR, al * 0.45))
			b.rect(Rect2(p - Vector2(0.4, sz * 3.0), Vector2(0.8, sz * 6.0)), Color(Art.STAR, al * 0.45))


## A ridge of hills along `y` across `x0..x1`, slid by `off`, down to `bottom`.
func _ridge(x0: float, x1: float, y: float, amp: float, seed: int, off := 0.0, bottom := -1.0, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x0, bottom if bottom > 0.0 else y + amp * 3.0)])
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var k := (x + off) / maxf(amp * 9.0, 1.0)
		pts.append(Vector2(x, y - amp * (0.55 + 0.3 * sin(k * 1.3 + seed) + 0.15 * sin(k * 3.1 + seed * 2.0) + 0.06 * sin(k * 7.3 + seed))))
	pts.append(Vector2(x1, bottom if bottom > 0.0 else y + amp * 3.0))
	return pts


## A hill shape lit along its top: the body, then a thin lit rim on the
## ridge line (the light from the top-left catching it).
func _hill(b, pts: PackedVector2Array, col: Color, rim: Color) -> void:
	b.polygon(pts, col)
	var top := pts.slice(1, pts.size() - 1)
	b.polyline(top, rim, maxf(1.0, 1.2 * _u))


## The point `f` (0..1) of the way along a polyline.
static func _along(pts: PackedVector2Array, f: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector2.ZERO
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := clampf(f, 0.0, 1.0) * total
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		if want <= d or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(want / maxf(d, 0.001), 0.0, 1.0))
		want -= d
	return pts[-1]


## A soft band of mist along `y`, `hh` tall each side, with a few slow
## drifting swells in it.
func _mist(b, x0: float, x1: float, y: float, hh: float, col: Color, a: float, seed: int, drift: float) -> void:
	Art.vgrad(b, Rect2(x0, y - hh, x1 - x0, hh), Color(col, 0.0), Color(col, a))
	Art.vgrad(b, Rect2(x0, y, x1 - x0, hh), Color(col, a), Color(col, 0.0))
	var span := x1 - x0 + hh * 8.0
	for i in 5:
		var x := x0 - hh * 4.0 + fposmod(Art.rnd(seed + i) * span + drift * (0.6 + 0.4 * Art.rnd(seed + i + 9)), span)
		b.soft(Vector2(x, y + (Art.rnd(seed + i * 3) - 0.5) * hh), Vector2(hh * 4.0, hh * 0.9), Color(col, a * 0.7))


## A shaft of light from `top` (`tw` wide) to `bot` (`bw` wide), soft at its
## sides, `col` at the top fading by `fade` (0: gone) at the bottom.
static func _shaft(b, top: Vector2, tw: float, bot: Vector2, bw: float, col: Color, fade := 0.0) -> void:
	var side := (bot - top).orthogonal().normalized()
	if side.x < 0.0:
		side = -side
	var t0 := top - side * tw * 0.5
	var t1 := top + side * tw * 0.5
	var b0 := bot - side * bw * 0.5
	var b1 := bot + side * bw * 0.5
	var ca := col
	var cb := Color(col, col.a * fade)
	var z := Color(col, 0.0)
	var f := [0.0, 0.3, 0.7, 1.0]
	var tc := [z, ca, ca, z]
	var bc := [z, cb, cb, z]
	for i in 3:
		Art.quad(b, t0.lerp(t1, f[i]), t0.lerp(t1, f[i + 1]), b0.lerp(b1, f[i + 1]), b0.lerp(b1, f[i]), tc[i], tc[i + 1], bc[i + 1], bc[i])


## The edges of the picture darkened, softly (a ring from clear to `a`).
static func _vignette(b, s: Vector2, h: float, a: float) -> void:
	var c := Vector2(s.x * 0.5, h * 0.5)
	var rad := Vector2(s.x * 0.62, h * 0.7)
	var rings := [[0.5, 0.0], [1.0, a * 0.6], [2.0, a]]
	var n := 28
	for k in rings.size() - 1:
		var r0: float = rings[k][0]
		var r1: float = rings[k + 1][0]
		var c0 := Color(Art.SHADOW, rings[k][1])
		var c1 := Color(Art.SHADOW, rings[k + 1][1])
		for i in n:
			var d0 := Vector2.from_angle(TAU * i / n) * rad
			var d1 := Vector2.from_angle(TAU * (i + 1) / n) * rad
			Art.quad(b, c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1, c0, c0, c1, c1)


## A colour faded `k` of the way into the air (`air`: the haze's colour).
static func _hz(col: Color, k: float, air: Color) -> Color:
	return Color(col.lerp(Color(air, col.a), clampf(k, 0.0, 1.0)), col.a)


## A closed outline round `pts`, `wd` wide (a mitred strip: cheaper than
## path()'s round joints, for the shapes redrawn every frame).
static func _ink(b, pts: PackedVector2Array, col: Color, wd: float) -> void:
	if pts.size() < 2:
		return
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	b.polyline(loop, col, wd)


## An outlined, shaded shape that can fade (`a`): the game's dark rim, the
## fill in material `m`, and a thin highlight on its lit edges.
func _shape(b, pts: PackedVector2Array, col: Color, a := 1.0, m := Shade.CLOTH, ow := 1.2) -> void:
	if pts.size() < 3:
		return
	_ink(b, pts, Color(Art.OUTLINE, a * 0.35), ow * 2.0 + 1.6)
	_ink(b, pts, Color(Art.OUTLINE, a), ow * 2.0)
	b.fill(pts, Color(col, a), m)
	b.rim(pts, Color(col.lightened(0.45), 0.4 * a), 1.0)


## An outlined shaded stroke that can fade (a sleeve, a leg, a staff).
func _limb(b, p0: Vector2, p1: Vector2, col: Color, wd: float, a := 1.0) -> void:
	b.line(p0, p1, Color(Art.OUTLINE, a), wd + 2.4)
	b.dot(p0, (wd + 2.4) * 0.5, Color(Art.OUTLINE, a))
	b.dot(p1, (wd + 2.4) * 0.5, Color(Art.OUTLINE, a))
	b.bar(p0, p1, Color(col, a), wd)


## A sleek tapering ribbon along `pts`: `wd` wide at its start, thin at its
## end, `col` fading out along it.
static func _ribbon(b, pts: PackedVector2Array, col: Color, wd: float) -> void:
	var n := pts.size()
	for k in n - 1:
		var f := float(k) / maxf(n - 1, 1)
		b.line(pts[k], pts[k + 1], Color(col, col.a * (1.0 - f)), maxf(0.8, wd * (1.0 - f * 0.85)))


## A person seen from the front at a distance: a cloak (hooded or not), a
## head, now and then a pack or a staff; `stride` swings the legs as they
## walk. Returns where their mark shows (the chest).
func _person(b, feet: Vector2, ph: float, seed: int, cloak: Color, a := 1.0, stride := 0.0, walking := false) -> Vector2:
	var skin: Color = [Color(0.86, 0.68, 0.55), Color(0.62, 0.44, 0.32), Color(0.42, 0.28, 0.2), Color(0.93, 0.78, 0.66)][seed % 4]
	var hood := Art.rnd(seed * 3 + 1) > 0.45
	var ow := clampf(ph * 0.03, 0.7, 1.4)
	b.contact(feet, ph * 0.2, 0.42 * a)
	var sw := sin(stride) * ph * 0.06 if walking else 0.0
	var legc := Color(0.1, 0.08, 0.1)
	_limb(b, feet + Vector2(-ph * 0.05, -ph * 0.3), feet + Vector2(-ph * 0.05 + sw, -ph * 0.02), legc, maxf(1.6, ph * 0.075), a)
	_limb(b, feet + Vector2(ph * 0.05, -ph * 0.3), feet + Vector2(ph * 0.05 - sw, -ph * 0.02), legc, maxf(1.6, ph * 0.075), a)
	if Art.rnd(seed * 5 + 2) > 0.7:  # a pack behind the shoulder
		_shape(b, PackedVector2Array([feet + Vector2(ph * 0.08, -ph * 0.66), feet + Vector2(ph * 0.24, -ph * 0.64), feet + Vector2(ph * 0.25, -ph * 0.4), feet + Vector2(ph * 0.1, -ph * 0.42)]), Art.LEATHER, a, Shade.SLAB, ow)
	var lean := sin(stride * 0.5) * ph * 0.01 if walking else 0.0
	var body := PackedVector2Array([feet + Vector2(-ph * 0.2, -ph * 0.14), feet + Vector2(-ph * 0.16 + lean, -ph * 0.55), feet + Vector2(-ph * 0.11 + lean, -ph * 0.68),
		feet + Vector2(lean, -ph * 0.72), feet + Vector2(ph * 0.11 + lean, -ph * 0.68), feet + Vector2(ph * 0.16 + lean, -ph * 0.55), feet + Vector2(ph * 0.2, -ph * 0.14),
		feet + Vector2(0, -ph * 0.1)])
	_shape(b, body, cloak, a, Shade.CLOTH, ow)
	b.line(feet + Vector2(lean * 0.5, -ph * 0.66), feet + Vector2(0, -ph * 0.16), Color(cloak.darkened(0.45), 0.6 * a), maxf(0.8, ph * 0.015))
	var head := feet + Vector2(lean, -ph * 0.82)
	if hood:
		var hp := PackedVector2Array([head + Vector2(-ph * 0.13, ph * 0.1), head + Vector2(-ph * 0.13, -ph * 0.04), head + Vector2(-ph * 0.04, -ph * 0.15),
			head + Vector2(ph * 0.05, -ph * 0.15), head + Vector2(ph * 0.13, -ph * 0.04), head + Vector2(ph * 0.13, ph * 0.1)])
		_shape(b, hp, cloak.lightened(0.05), a, Shade.CLOTH, ow)
		b.oval(head + Vector2(0, ph * 0.02), Vector2(ph * 0.07, ph * 0.085), 0.0, Color(skin.darkened(0.35), a))
	else:
		b.dot(head, ph * 0.1 + ow, Color(Art.OUTLINE, a))
		b.disc(head, ph * 0.1, Color(skin, a))
		b.oval(head + Vector2(0, -ph * 0.06), Vector2(ph * 0.1, ph * 0.05), 0.0, Color(Color(0.18, 0.12, 0.1), a))  # hair
	if Art.rnd(seed * 7 + 3) > 0.75:  # a staff
		var hand := feet + Vector2(-ph * 0.22, -ph * 0.42)
		_limb(b, hand + Vector2(0, -ph * 0.5), hand + Vector2(0, ph * 0.4), Art.OAK.darkened(0.2), maxf(1.4, ph * 0.035), a)
	return feet + Vector2(ph * 0.04 + lean, -ph * 0.52)


# --- 1. the world tearing, and the six who held it -------------------------------------

## The continents, once: six blobs in longitude/latitude, and their colours.
static func _land_list() -> Array:
	if _lands.is_empty():
		var spots := [[0.2, 0.55, 0.62, 0.34], [1.5, -0.2, 0.5, 0.42], [2.6, 0.35, 0.7, 0.3], [3.7, -0.45, 0.42, 0.3], [4.6, 0.2, 0.55, 0.38], [5.5, -0.6, 0.36, 0.2], [0.9, -0.75, 0.6, 0.16]]
		var cols := [Color(0.34, 0.5, 0.3), Color(0.5, 0.47, 0.3), Color(0.3, 0.46, 0.28), Color(0.42, 0.5, 0.32), Color(0.36, 0.52, 0.3), Color(0.82, 0.86, 0.92), Color(0.84, 0.88, 0.94)]
		for i in spots.size():
			var sp: Array = spots[i]
			var loop := PackedVector2Array()
			for k in 16:
				var ang := TAU * k / 16.0
				var wob := 0.72 + 0.5 * Art.rnd(i * 31 + k * 7)
				loop.append(Vector2(sp[0] + cos(ang) * sp[2] * wob, sp[1] + sin(ang) * sp[3] * wob))
			_lands.append([loop, cols[i]])
	return _lands


## A point on the world (longitude turned by `rot`, latitude) to the screen,
## and its facing toward us (z; held to the rim when it's round the back).
static func _on_globe(c: Vector2, r: float, ll: Vector2, rot: float) -> Vector3:
	var lon := wrapf(ll.x + rot, -PI, PI)
	var z_raw := cos(ll.y) * cos(lon)
	lon = clampf(lon, -PI * 0.5, PI * 0.5)
	var x := cos(ll.y) * sin(lon)
	var y := -sin(ll.y)
	return Vector3(c.x + x * r, c.y + y * r, z_raw)


## How lit a point of the world facing `n` is (0..1, the light top-left).
static func _lit(n: Vector3) -> float:
	return maxf(n.dot(SUN.normalized()), 0.0)


## The world: an ocean shaded as a sphere (a fine mesh, lit per point),
## its turning lands, clouds, the night side and the air round its rim.
## (Static: the Regard's glimpse of the fracture draws the same world,
## fracture.gd draw.)
static func _globe(b, c: Vector2, r: float, rot: float, ill: float) -> void:
	var ocean := Color(0.16, 0.34, 0.56)
	var rings := 7
	var seg := 36
	var prev_r := 0.0
	for k in rings:
		var r1 := sin(float(k + 1) / rings * PI * 0.5)
		for i in seg:
			var d0 := Vector2.from_angle(TAU * i / seg)
			var d1 := Vector2.from_angle(TAU * (i + 1) / seg)
			var pts := [d0 * prev_r, d1 * prev_r, d1 * r1, d0 * r1]
			var cs: Array = []
			for p in pts:
				var v: Vector2 = p
				var n := Vector3(v.x, v.y, sqrt(maxf(1.0 - v.length_squared(), 0.0)))
				var l := _lit(n)
				cs.append(Color(ocean * (0.16 + 1.05 * l) + Color(0.05, 0.1, 0.2) * pow(1.0 - n.z, 3.0) * ill, 1.0))
			Art.quad(b, c + pts[0] * r, c + pts[1] * r, c + pts[2] * r, c + pts[3] * r, cs[0], cs[1], cs[2], cs[3])
		prev_r = r1
	# The lands, turning, each lit per point.
	for land in _land_list():
		var loop: PackedVector2Array = land[0]
		var col: Color = land[1]
		var pts := PackedVector2Array()
		var cs := PackedColorArray()
		var seen := false
		for ll in loop:
			var q := _on_globe(c, r, ll, rot)
			seen = seen or q.z > 0.0
			var v := (Vector2(q.x, q.y) - c) / r
			var n := Vector3(v.x, v.y, sqrt(maxf(1.0 - v.length_squared(), 0.0)))
			pts.append(Vector2(q.x, q.y))
			cs.append(Color(col * (0.14 + 1.0 * _lit(n)), 1.0))
		if not seen:
			continue
		var mid := Vector2.ZERO
		for p in pts:
			mid += p
		mid /= float(pts.size())
		var shelf := PackedVector2Array()
		var inner := PackedVector2Array()
		for p in pts:
			shelf.append(mid + (p - mid) * 1.14)
			inner.append(mid + (p - mid) * 0.5 + Vector2(-0.04, -0.03) * r)
		b.polygon(shelf, Color(0.4, 0.7, 0.85, 0.22))
		var idx := Geometry2D.triangulate_polygon(pts)
		for i in idx:
			b.pts.append(pts[i])
			b.cols.append(cs[i])
		var lit_mid := cs[0]
		b.polygon(inner, Color(lit_mid.darkened(0.25), 0.55))
	# Clouds drifting a little faster than the lands.
	for i in 9:
		var ll := Vector2(Art.rnd(i * 13 + 4) * TAU, (Art.rnd(i * 17 + 2) - 0.5) * 2.0)
		var q := _on_globe(c, r, ll, rot * 1.35)
		if q.z <= 0.05:
			continue
		var v := (Vector2(q.x, q.y) - c) / r
		var l := _lit(Vector3(v.x, v.y, q.z))
		b.soft(Vector2(q.x, q.y), Vector2(r * 0.26 * maxf(q.z, 0.3), r * 0.08), Color(1, 1, 1, 0.22 * q.z * (0.3 + l)))
	# A glint of the light on the sea, top-left.
	b.soft(c + Vector2(-0.38, -0.42) * r, Vector2.ONE * r * 0.34, Color(0.85, 0.92, 1.0, 0.22))
	# The air round its rim: bright on the lit side, faint on the night side.
	var n2 := 40
	for i in n2:
		var d0 := Vector2.from_angle(TAU * i / n2)
		var d1 := Vector2.from_angle(TAU * (i + 1) / n2)
		var f0 := clampf(d0.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var f1 := clampf(d1.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var air := Color(0.5, 0.72, 1.0)
		Art.quad(b, c + d0 * r * 0.93, c + d1 * r * 0.93, c + d1 * r, c + d0 * r, Color(air, 0.0), Color(air, 0.0), Color(air, 0.15 + 0.5 * f1), Color(air, 0.15 + 0.5 * f0))
		Art.quad(b, c + d0 * r, c + d1 * r, c + d1 * r * 1.09, c + d0 * r * 1.09, Color(air, 0.15 + 0.5 * f0), Color(air, 0.15 + 0.5 * f1), Color(air, 0.0), Color(air, 0.0))


## One of the six who held the world: a hooded robe trimmed in its essence,
## sleeves reaching toward `toward`, hands alight. `a` fades it in.
func _robed(b, feet: Vector2, fh: float, col: Color, a: float, toward: Vector2) -> Array:
	var ow := clampf(fh * 0.02, 0.8, 1.5)
	var robe_c := Color(0.15, 0.12, 0.21).lerp(col.darkened(0.6), 0.18)
	b.soft(feet + Vector2(0, -fh * 0.45), Vector2(fh * 0.55, fh * 0.7), Color(col, 0.16 * a))
	var d := toward.normalized()
	var sh := feet + Vector2(0, -fh * 0.6)
	var hands: Array = []
	# The far sleeve, behind the robe.
	var hem := [feet + Vector2(-fh * 0.3, 0.0), feet + Vector2(-fh * 0.12, fh * 0.03), feet + Vector2(fh * 0.1, fh * 0.03), feet + Vector2(fh * 0.3, 0.0)]
	var robe := PackedVector2Array([hem[0], feet + Vector2(-fh * 0.2, -fh * 0.42), feet + Vector2(-fh * 0.16, -fh * 0.6), feet + Vector2(-fh * 0.06, -fh * 0.68),
		feet + Vector2(fh * 0.06, -fh * 0.68), feet + Vector2(fh * 0.16, -fh * 0.6), feet + Vector2(fh * 0.2, -fh * 0.42), hem[3], hem[2], hem[1]])
	for sg in [-1.0, 1.0]:
		var shoulder: Vector2 = sh + Vector2(sg * fh * 0.13, 0)
		var elbow: Vector2 = shoulder + (d * 0.6 + Vector2(sg * 0.25, 0.35)).normalized() * fh * 0.22
		var hand: Vector2 = elbow + (d + Vector2(0, -0.15)).normalized() * fh * 0.22 + d.orthogonal() * sg * fh * 0.05
		hands.append(hand)
		if (sg < 0.0) == (d.x > 0.0):
			_limb(b, shoulder, elbow, robe_c.darkened(0.15), fh * 0.09, a)
			_limb(b, elbow, hand, robe_c.darkened(0.15), fh * 0.075, a)
	_shape(b, robe, robe_c, a, Shade.CLOTH, ow)
	# Folds, and the trim of its essence at the hem.
	for sg in [-1.0, 1.0]:
		b.line(feet + Vector2(sg * fh * 0.06, -fh * 0.55), feet + Vector2(sg * fh * 0.14, -fh * 0.02), Color(robe_c.darkened(0.5), 0.6 * a), maxf(0.8, fh * 0.012))
	var trim := PackedVector2Array([hem[0] + Vector2(fh * 0.01, -fh * 0.04), hem[1] + Vector2(0, -fh * 0.04), hem[2] + Vector2(0, -fh * 0.04), hem[3] + Vector2(-fh * 0.01, -fh * 0.04)])
	b.polyline(trim, Color(col, 0.75 * a), maxf(1.0, fh * 0.025))
	# The near sleeve over it.
	for k in 2:
		var sg := -1.0 if k == 0 else 1.0
		if (sg < 0.0) != (d.x > 0.0):
			var shoulder: Vector2 = sh + Vector2(sg * fh * 0.13, 0)
			var hand: Vector2 = hands[k]
			var elbow: Vector2 = shoulder + (d * 0.6 + Vector2(sg * 0.25, 0.35)).normalized() * fh * 0.22
			_limb(b, shoulder, elbow, robe_c, fh * 0.09, a)
			_limb(b, elbow, hand, robe_c, fh * 0.075, a)
	# The hood, its face in shadow, a glint of its essence for eyes.
	var hc := feet + Vector2(0, -fh * 0.76)
	var hood := PackedVector2Array([hc + Vector2(-fh * 0.13, fh * 0.1), hc + Vector2(-fh * 0.14, -fh * 0.03), hc + Vector2(-fh * 0.06, -fh * 0.14),
		hc + Vector2(fh * 0.02, -fh * 0.18), hc + Vector2(fh * 0.1, -fh * 0.1), hc + Vector2(fh * 0.14, fh * 0.0), hc + Vector2(fh * 0.13, fh * 0.1)])
	_shape(b, hood, robe_c.lightened(0.04), a, Shade.CLOTH, ow)
	b.oval(hc + Vector2(fh * 0.01, fh * 0.02), Vector2(fh * 0.075, fh * 0.085), 0.0, Color(0.02, 0.015, 0.03, a))
	for sg in [-1.0, 1.0]:
		b.circle(hc + Vector2(fh * 0.01 + sg * fh * 0.028, fh * 0.015), maxf(0.8, fh * 0.012), Color(col.lightened(0.5), 0.85 * a), 8)
	# The hands, alight.
	for hand in hands:
		b.soft(hand, Vector2.ONE * fh * 0.16, Color(col, 0.55 * a))
		b.circle(hand, maxf(1.2, fh * 0.03), Color(col.lightened(0.6), a), 10)
	return hands


func _world(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var r := minf(h * 0.25, w * 0.15)
	var mid0 := Vector2(w * 0.5, h * 0.44)
	_focus = mid0
	_push = 0.12
	_pan = Vector2(0, 4.0 * u)
	var tear := smoothstep(0.4, 2.6, t)
	var figs := smoothstep(2.8, 4.4, t)
	var hold := smoothstep(4.2, 6.4, t)
	var quake := tear * (1.0 - hold)
	var shake := Vector2(sin(clock * 5.1) + 0.5 * sin(clock * 8.3 + 1.0), cos(clock * 4.6) + 0.5 * sin(clock * 7.7 + 2.0)) * 1.4 * u * quake
	var mid := mid0 + shake
	# Deep space: a dark field, clouds of the six essences far off, stars.
	_baked("space", s, h, 0.1, func(b):
		var m := 80.0 * u
		b.rect(Rect2(-m, -m, w + m * 2.0, s.y + m * 2.0), Color(0.016, 0.012, 0.03))
		for i in 14:
			var p := Vector2(Art.rnd(i * 5 + 1) * w, Art.rnd(i * 9 + 4) * h * 1.1)
			var col: Color = Essence.color(KINDS[i % 6]).lerp(Color(0.3, 0.2, 0.5), 0.55)
			b.soft(p, Vector2(160.0 + 220.0 * Art.rnd(i + 30), 70.0 + 90.0 * Art.rnd(i + 40)) * u, Color(col, 0.1 + 0.08 * Art.rnd(i + 50)))
		for i in 6:  # dark lanes of dust across them
			var p := Vector2(Art.rnd(i * 7 + 61) * w, Art.rnd(i * 3 + 62) * h)
			b.soft(p, Vector2(220.0, 40.0) * u, Color(0.0, 0.0, 0.0, 0.25)))
	var bg := UI.Draw.Batch.new()
	_stars(bg, Rect2(-40.0 * u, -40.0 * u, w + 80.0 * u, h + 60.0 * u), 90, 3)
	_put(bg, 0.15)
	# Where the six stand: a ring round the world, seen a little from above.
	var ring_c := mid + Vector2(0, r * 0.32)
	var rx := r * 2.0
	var ry := r * 0.56
	var spots: Array = []
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var front := sin(ang)
		spots.append({"i": i, "ang": ang, "front": front, "p": ring_c + Vector2(cos(ang) * rx, sin(ang) * ry), "k": lerpf(0.74, 1.12, (front + 1.0) * 0.5)})
	var back := UI.Draw.Batch.new()
	if hold > 0.0:
		_ring_half(back, ring_c, rx, ry, true, hold)
	for sp in spots:
		if float(sp["front"]) < 0.0:
			_holder_at(back, sp, mid, r, figs, hold)
	_put(back, 0.9)
	# The world, its cracks bleeding essence, the essence streaming out wild.
	var gb := UI.Draw.Batch.new()
	Art.light(gb, mid, Vector2.ONE * r * 2.1, Color(0.35, 0.5, 1.0, 0.16 + 0.08 * hold))
	if tear > 0.0:
		Art.light(gb, mid, Vector2.ONE * r * 2.4, Color(Palette.WILD, 0.2 * tear * (1.0 - 0.7 * hold)))
	gb.circle(mid, r + 1.6, Art.OUTLINE, 48)
	_globe(gb, mid, r, clock * 0.06, 1.0)
	var glow := lerpf(1.0, 0.25, hold)
	for i in 6:
		var col: Color = Essence.color(KINDS[i])
		var pts: PackedVector2Array = Fracture._part(Fracture._crack(i, r), tear)
		if pts.size() < 2:
			continue
		for k in pts.size():
			pts[k] += mid
		gb.polyline(pts, Color(col, 0.2 * glow), (10.0 + 8.0 * tear) * u)
		gb.polyline(pts, Color(0.03, 0.01, 0.04, 0.9), 3.2 * u)
		gb.polyline(pts, Color(col.lightened(0.55).lerp(Art.GILT_HI, hold), 0.95), 1.4 * u)
		for k in range(1, pts.size()):
			gb.soft(pts[k], Vector2.ONE * 7.0 * u, Color(col, 0.35 * glow))
		var reach := r * 1.9 * tear * (1.0 - 0.85 * hold)
		if reach < 2.0:
			continue
		var ribbon := PackedVector2Array([pts[pts.size() - 1]])
		var at: Vector2 = ribbon[0]
		var ang := -PI / 2.0 + TAU * float(i) / 6.0 + 0.35
		for k in 12:
			ang += sin(clock * 1.3 + float(k) * 0.5 + float(i) * 1.3) * 0.22 + 0.06
			at += Vector2.from_angle(ang) * reach / 12.0
			ribbon.append(at)
		_ribbon(gb, ribbon, Color(col, 0.18), 18.0 * u)
		_ribbon(gb, ribbon, Color(col.lightened(0.3), 0.75), 3.2 * u)
		for m in 3:
			var f := fposmod(clock * 0.45 + float(m) * 0.33 + float(i) * 0.11, 1.0)
			gb.soft(_along(ribbon, f), Vector2.ONE * (5.0 + 9.0 * f) * u, Color(col, 0.6 * (1.0 - f) * smoothstep(0.0, 0.12, f)))
	_put(gb, 1.0)
	# The ring's near half, and the three in front.
	var fr := UI.Draw.Batch.new()
	if hold > 0.0:
		_ring_half(fr, ring_c, rx, ry, false, hold)
	for sp in spots:
		if float(sp["front"]) >= 0.0:
			_holder_at(fr, sp, mid, r, figs, hold)
	_put(fr, 1.1)
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.7)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


## Half of the ring of light the six make round the world (the far half
## behind it, the near half in front).
func _ring_half(b, c: Vector2, rx: float, ry: float, far: bool, a: float) -> void:
	var pts := PackedVector2Array()
	for k in 25:
		var ang := (PI + PI * k / 24.0) if far else (PI * k / 24.0)
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	b.polyline(pts, Color(Art.GILT, 0.14 * a), 9.0 * _u)
	b.polyline(pts, Color(Art.GILT_HI, (0.4 if far else 0.75) * a), 1.6 * _u)
	for k in range(2, 24, 4):  # small marks along it
		var p: Vector2 = pts[k]
		b.circle(p, 1.6 * _u, Color(Art.GILT_HI, 0.8 * a), 8)


## One of the six at its place on the ring, and its binding light.
func _holder_at(b, sp: Dictionary, mid: Vector2, r: float, figs: float, hold: float) -> void:
	if figs <= 0.0:
		return
	var i: int = sp["i"]
	var col: Color = Essence.color(KINDS[i])
	var k: float = sp["k"]
	var feet: Vector2 = sp["p"]
	var fh := r * 0.6 * k
	feet.y += fh * 0.06 * (1.0 - figs)
	var toward := mid - (feet + Vector2(0, -fh * 0.6))
	var a := figs * lerpf(0.8, 1.0, (float(sp["front"]) + 1.0) * 0.5)
	b.soft(feet + Vector2(0, -fh * 0.5), Vector2(fh * 0.25, fh * 0.9), Color(col.lightened(0.4), 0.5 * (1.0 - figs) * figs * 4.0))
	var hands := _robed(b, feet, fh, col, a, toward)
	if hold <= 0.0:
		return
	var tgt := mid - toward.normalized() * r * 0.97
	for hand in hands:
		var hp: Vector2 = hand
		b.line(hp, tgt, Color(col, 0.18 * hold), 6.0 * _u)
		b.line(hp, tgt, Color(col.lightened(0.45), 0.7 * hold), 1.4 * _u)
	for m in 2:
		var f := fposmod(clock * 0.6 + float(m) * 0.5 + float(i) * 0.17, 1.0)
		b.soft(Vector2(hands[0]).lerp(tgt, f), Vector2.ONE * 5.0 * _u, Color(col.lightened(0.3), 0.7 * hold * sin(f * PI)))
	b.soft(tgt, Vector2.ONE * 12.0 * _u, Color(col, 0.55 * hold))


# --- 2. six towers over six wells -------------------------------------------------------

## A tower of the six: a stepped plinth, a tapering stone body shaded round
## (lit on the left), its courses and bands, lit arched windows, a gallery
## with merlons, a slate spire with a beacon chamber, a crystal at the top,
## and two banners of its essence. `haze` fades it into `air` (distance).
## Returns where its crystal is.
func _tower(b, base: Vector2, th: float, id: String, haze: float, air: Color, seed: int, part := 0) -> Vector2:
	var info: Dictionary = Towers.TOWERS.get(id, {})
	var ec: Color = Essence.color(String(info.get("essence", "air")))
	var torch: Color = info.get("torch", ec)
	var stone := _hz(Color(0.25, 0.21, 0.29), haze, air)
	var slate := _hz(Color(0.15, 0.13, 0.2), haze, air)
	var ink := _hz(Art.OUTLINE, haze * 0.7, air)
	var ow := clampf(th * 0.006, 0.8, 1.8)
	var hb := th * 0.085
	var ht := th * 0.062
	var gy := base.y - th * 0.8
	var y0 := base.y - th * 0.07
	var lw := ht * 1.5
	var ledge := Rect2(base.x - lw, gy - th * 0.03, lw * 2.0, th * 0.03)
	var dw := ht * 0.82
	var dtop := ledge.position.y - th * 0.075
	var drum := Rect2(base.x - dw, dtop, dw * 2.0, ledge.position.y - dtop)
	var tip := Vector2(base.x, dtop - th * 0.15)
	var cr := maxf(2.5, th * 0.02)
	var cp := tip + Vector2(0, -cr * 1.4)
	if part != 2:
		# The plinth: two shaded steps.
		for k in 2:
			var pw := hb * (1.55 - 0.3 * k)
			var py := base.y - th * (0.035 + 0.035 * k)
			var pr := Rect2(base.x - pw, py, pw * 2.0, th * 0.036)
			b.rect(pr.grow(ow), ink)
			b.box(pr, stone.darkened(0.12 - 0.06 * k), Shade.SLAB)
		# The body: shaded round, lit on the left.
		var l0 := Vector2(base.x - hb, y0)
		var r0 := Vector2(base.x + hb, y0)
		var l1 := Vector2(base.x - ht, gy)
		var r1 := Vector2(base.x + ht, gy)
		_ink(b, PackedVector2Array([l0, l1, r1, r0]), ink, ow * 2.0)
		var f := [0.0, 0.18, 0.45, 0.78, 1.0]
		var cs := [stone.lightened(0.1), stone.lightened(0.2), stone, stone.darkened(0.38), stone.darkened(0.55)]
		for i in 4:
			Art.quad(b, l1.lerp(r1, f[i]), l1.lerp(r1, f[i + 1]), l0.lerp(r0, f[i + 1]), l0.lerp(r0, f[i]), cs[i], cs[i + 1], cs[i + 1], cs[i])
		b.line(l0 + Vector2(ow, 0), l1 + Vector2(ow, 0), Color(stone.lightened(0.45), 0.5), ow)
		# Courses of stone, and the joints between their blocks.
		var courses := int(clampf(th / (9.0 * _u), 8.0, 22.0))
		for k in courses:
			var yf := (float(k) + 0.5) / courses
			var yy := lerpf(y0, gy, yf)
			var half := lerpf(hb, ht, yf)
			b.rect(Rect2(base.x - half, yy, half * 2.0, maxf(0.7, ow * 0.6)), Color(ink, 0.32))
			var jx := base.x + half * (0.35 if k % 2 == 0 else -0.2)
			var yn := lerpf(y0, gy, (float(k) + 1.5) / courses)
			b.rect(Rect2(jx, yn, maxf(0.7, ow * 0.6), yy - yn), Color(ink, 0.22))
		# Bands round it.
		for bf in [0.3, 0.56]:
			var yy := lerpf(y0, gy, bf)
			var half := lerpf(hb, ht, bf) + th * 0.008
			var br := Rect2(base.x - half, yy - th * 0.012, half * 2.0, th * 0.018)
			b.rect(br.grow(ow * 0.8), ink)
			b.box(br, stone.lightened(0.08), Shade.SLAB)
			b.rect(Rect2(br.position.x, br.position.y, br.size.x, maxf(0.7, br.size.y * 0.25)), Color(_hz(torch, haze, air), 0.35))
	if part != 2:
		# Windows: arched, most of them lit.
		var wins := [[0.16, 0.0], [0.42, -0.42], [0.42, 0.42], [0.68, 0.0], [0.88, -0.38], [0.88, 0.38]]
		for wi in wins.size():
			var wf: float = wins[wi][0]
			var yy := lerpf(y0, gy, wf)
			var half := lerpf(hb, ht, wf)
			var wx: float = base.x + half * float(wins[wi][1]) * 0.9
			var ww := maxf(1.5, half * (0.3 if wins[wi][1] == 0.0 else 0.22))
			var wh := ww * 2.2
			var lit := Art.rnd(seed * 17 + wi) > 0.2
			var glow := 0.85 + 0.15 * Art.rnd(seed * 3 + wi)
			var arch := PackedVector2Array([Vector2(wx - ww * 0.5, yy), Vector2(wx - ww * 0.5, yy - wh * 0.62)])
			for k in 7:
				arch.append(Vector2(wx, yy - wh * 0.62) + Vector2.from_angle(PI + PI * k / 6.0) * ww * 0.5)
			arch.append(Vector2(wx + ww * 0.5, yy))
			_ink(b, arch, ink, ow * 1.6)
			if lit:
				var wc := _hz(ec.lerp(Art.LAMP, 0.45), haze * 0.4, air)
				b.soft(Vector2(wx, yy - wh * 0.45), Vector2(ww * 2.4, wh * 1.3), Color(wc, 0.3 * glow))
				b.polygon(arch, wc.lightened(0.25 * glow))
				b.rect(Rect2(wx - ww * 0.5, yy - wh * 0.3, ww, wh * 0.3), Color(wc.darkened(0.25), 0.8))
			else:
				b.polygon(arch, Color(0.03, 0.025, 0.05))
			b.rect(Rect2(wx - ww * 0.7, yy, ww * 1.4, maxf(1.0, ow)), stone.lightened(0.15))
	if part != 2:
		# The gallery: corbels under a ledge, merlons along it.
		for k in 5:
			var cx := lerpf(base.x - ht * 0.9, base.x + ht * 0.9, k / 4.0)
			var cor := PackedVector2Array([Vector2(cx - th * 0.01, ledge.end.y), Vector2(cx + th * 0.01, ledge.end.y), Vector2(cx, ledge.end.y + th * 0.025)])
			b.polygon(cor, stone.darkened(0.3))
		b.rect(ledge.grow(ow), ink)
		b.box(ledge, stone.lightened(0.05), Shade.SLAB)
		var mw := lw * 2.0 / 9.0
		for k in 5:
			var mr := Rect2(base.x - lw + mw * (k * 2.0), ledge.position.y - th * 0.028, mw, th * 0.028)
			b.rect(mr.grow(ow * 0.8), ink)
			b.box(mr, stone.lightened(0.02), Shade.SLAB)
	if part != 1:
		# Banners hanging from the gallery, stirring.
		for sg in [-1.0, 1.0]:
			var bx: float = base.x + sg * ht * 0.62
			var bt := ledge.end.y
			var bl := th * 0.22
			var bw := ht * 0.55
			var sway := sin(clock * 1.4 + float(seed) + sg) * bw * 0.22
			var ban := PackedVector2Array([Vector2(bx - bw * 0.5, bt), Vector2(bx + bw * 0.5, bt), Vector2(bx + bw * 0.5 + sway * 0.6, bt + bl),
				Vector2(bx + sway, bt + bl * 0.82), Vector2(bx - bw * 0.5 + sway * 0.6, bt + bl)])
			var cloth := _hz(ec.darkened(0.25), haze, air)
			_shape(b, ban, cloth, 1.0, Shade.CLOTH, ow * 0.8)
			b.rect(Rect2(bx - bw * 0.6, bt - ow, bw * 1.2, maxf(1.5, ow * 2.0)), _hz(Art.GILT, haze, air))
			b.circle(Vector2(bx + sway * 0.3, bt + bl * 0.36), maxf(1.0, bw * 0.2), _hz(Art.GILT_HI, haze, air), 10)
	if part != 2:
		# The beacon chamber, lit, then the spire.
		b.rect(drum.grow(ow), ink)
		b.box(drum, stone.darkened(0.08), Shade.SLAB)
	if part != 1:
		var flick := 0.85 + 0.15 * sin(clock * 3.1 + float(seed))
		b.rect(Rect2(base.x - dw * 0.45, dtop + drum.size.y * 0.2, dw * 0.9, drum.size.y * 0.6), _hz(torch.lightened(0.2), haze * 0.3, air))
		b.soft(drum.get_center(), Vector2(dw * 2.6, drum.size.y * 1.6), Color(torch, 0.35 * flick))
	if part != 2:
		var sl := Vector2(base.x - dw * 1.2, dtop)
		var sr := Vector2(base.x + dw * 1.2, dtop)
		_ink(b, PackedVector2Array([sl, tip, sr]), ink, ow * 2.0)
		Art.quad(b, sl, sl.lerp(sr, 0.4), tip, tip, slate.lightened(0.22), slate, slate, slate.lightened(0.12))
		Art.quad(b, sl.lerp(sr, 0.4), sr, tip, tip, slate, slate.darkened(0.45), slate.darkened(0.3), slate)
		for k in 3:
			var yy := lerpf(dtop, tip.y, 0.25 + 0.22 * k)
			var half := dw * 1.2 * (1.0 - (0.25 + 0.22 * k))
			b.rect(Rect2(base.x - half, yy, half * 2.0, maxf(0.7, ow * 0.6)), Color(ink, 0.4))
	if part != 1:
		# The crystal at the top, and its light.
		var pulse := 0.8 + 0.2 * sin(clock * 1.7 + float(seed) * 0.7)
		b.soft(cp, Vector2.ONE * th * 0.24, Color(ec, (0.3 - 0.14 * haze) * pulse))
		b.soft(cp, Vector2.ONE * th * 0.09, Color(ec.lightened(0.3), (0.45 - 0.2 * haze) * pulse))
		var gem := PackedVector2Array([cp + Vector2(0, -cr * 1.6), cp + Vector2(cr, 0), cp + Vector2(0, cr * 1.2), cp + Vector2(-cr, 0)])
		_ink(b, gem, ink, ow * 1.6)
		b.polygon(gem, ec.lightened(0.15))
		b.polygon(PackedVector2Array([gem[0], gem[3], cp]), ec.lightened(0.6))
	return cp


## A well of essence at a tower's foot: a ring of shaded stones round a
## pool of light, its glow spilling out and a faint column rising.
## `part`: 0 all of it, 1 only what stays still, 2 only its pulsing glow.
func _well(b, c: Vector2, rw: float, col: Color, haze: float, air: Color, seed: int, part := 0) -> void:
	var pulse := 0.85 + 0.15 * sin(clock * 1.2 + float(seed))
	if part != 1:
		b.soft(c, Vector2(rw * 2.6, rw * 0.8), Color(col, 0.35 * pulse))
		b.soft(c + Vector2(0, -rw * 1.2), Vector2(rw * 0.9, rw * 1.8), Color(col, 0.1 * pulse))
	if part == 2:
		return
	_shaft(b, c, rw * 1.6, c + Vector2(0, -rw * 3.2), rw * 0.5, Color(col, 0.14), 0.0)
	var stone := _hz(Color(0.22, 0.19, 0.25), haze, air)
	b.polygon(UI._oval(c, Vector2(rw * 1.08, rw * 0.3), 24), _hz(Art.OUTLINE, haze * 0.7, air))
	b.polygon(UI._oval(c, Vector2(rw, rw * 0.26), 24), stone)
	b.polygon(UI._oval(c + Vector2(0, rw * 0.02), Vector2(rw * 0.8, rw * 0.18), 24), col.darkened(0.2))
	b.polygon(UI._oval(c + Vector2(-rw * 0.08, rw * 0.0), Vector2(rw * 0.55, rw * 0.11), 20), Color(col.lightened(0.45), 0.8))
	for k in 9:  # the rim's stones
		var ang := PI * 0.08 + PI * 0.84 * k / 8.0
		var p := c + Vector2(cos(ang) * rw * 0.92, sin(ang) * rw * 0.25)
		b.box(Rect2(p - Vector2(rw * 0.1, rw * 0.05), Vector2(rw * 0.2, rw * 0.09)), stone.lightened(0.05 * (k % 2)), Shade.SLAB)


## A guardian in its own colours (the Bestiary's drawing), `w` across,
## centred on `c`, `a` its strength (it comes up out of the dark), through
## the camera `xf`.
func _guardian(kind: String, c: Vector2, w: float, a: float, xf: Transform2D) -> void:
	if a <= 0.01:
		return
	if not _tints.has("shape:" + kind):
		_tints["shape:" + kind] = Bestiary.shape(kind)
	var sh: Dictionary = _tints["shape:" + kind]
	var pts: PackedVector2Array = sh.get("pts", PackedVector2Array())
	var n: int = sh.get("shadow", 0)
	if pts.size() <= n:
		return
	var bd: Rect2 = sh.get("bounds", Rect2(-10, -10, 20, 20))
	var fit := w / maxf(bd.size.x, bd.size.y)
	var step := clampi(int(round(a * 8.0)), 1, 8)
	var key := "%s:%d" % [kind, step]
	if not _tints.has(key):
		var src: PackedColorArray = sh["cols"]
		var out := PackedColorArray()
		out.resize(src.size() - n)
		var k := float(step) / 8.0
		for i in range(n, src.size()):
			var cc: Color = src[i]
			out[i - n] = Color(cc.r * 0.92, cc.g * 0.9, cc.b, cc.a * k)
		_tints[key] = out
	var cols: PackedColorArray = _tints[key]
	if not _tints.has(kind):
		var uvs: PackedVector2Array = sh.get("uvs", PackedVector2Array())
		_tints[kind] = [pts.slice(n), uvs.slice(n) if uvs.size() >= pts.size() else PackedVector2Array()]
	var body: PackedVector2Array = _tints[kind][0]
	var body_uv: PackedVector2Array = _tints[kind][1]
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(fit, fit), 0.0, c - bd.get_center() * fit))
	Shade.draw_tris(get_canvas_item(), body, cols, body_uv)
	var glow: PackedVector2Array = sh.get("glow", PackedVector2Array())
	if not glow.is_empty() and a > 0.9:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), glow, sh["glow_cols"])
	draw_set_transform_matrix(xf)


func _towers(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.66
	var air := Color(0.3, 0.2, 0.34)
	_focus = Vector2(w * 0.5, h * 0.45)
	_push = 0.07
	_pan = Vector2(-18.0 * u, 0)
	# The sky at dusk, far mountains in the haze.
	_baked("sky", s, h, 0.1, func(b):
		var m := 60.0 * u
		_sky(b, Rect2(-m, -m, w + m * 2.0, horizon + m), [[0.0, Art.SKY[0]], [0.45, Art.SKY[1]], [0.8, Art.SKY[2]], [1.0, Color(0.5, 0.3, 0.34)]])
		b.rect(Rect2(-m, horizon, w + m * 2.0, s.y - horizon + m), Color(0.07, 0.05, 0.09))
		b.soft(Vector2(w * 0.5, horizon), Vector2(w * 0.7, h * 0.22), Color(0.95, 0.55, 0.45, 0.16))
		_hill(b, _ridge(-m, w + m, horizon - h * 0.05, 26.0 * u, 2, 0.0, horizon + 4.0, 30), _hz(Art.FAR, 0.55, air), Color(0.75, 0.55, 0.65, 0.18))
		_hill(b, _ridge(-m, w + m, horizon - h * 0.005, 16.0 * u, 7, 40.0, horizon + 10.0, 30), _hz(Art.FAR, 0.3, air), Color(0.7, 0.5, 0.6, 0.15)))
	var sb := UI.Draw.Batch.new()
	_stars(sb, Rect2(-40.0 * u, -30.0 * u, w + 80.0 * u, horizon * 0.62), 60, 11)
	for k in 3:  # a slow band of the essences' light across the sky
		var pts := PackedVector2Array()
		for i in 13:
			var x := lerpf(-60.0 * u, w + 60.0 * u, i / 12.0)
			pts.append(Vector2(x, h * (0.12 + 0.05 * k) + sin(x / (180.0 * u) + clock * 0.15 + k) * 14.0 * u))
		sb.polyline(pts, Color(Essence.color(KINDS[k * 2 + 1]), 0.05), (26.0 - 6.0 * k) * u)
	_put(sb, 0.15)
	# The six, in an arc: the middle ones farthest, the outer ones nearest.
	var n: int = Towers.ORDER.size()
	var risen_at := 0.2 + float(n - 1) * 0.28 + 1.6
	var keen := smoothstep(risen_at, risen_at + 1.2, t)
	var groups := [[2, 3], [1, 4], [0, 5]]
	var depths := [0.45, 0.7, 0.95]
	for g in 3:
		var tb := UI.Draw.Batch.new()
		var tops: Array = []
		# Once a group's towers have risen, their stone is kept and only
		# what moves (windows, banners, beacons) is drawn each time.
		var up := t >= 0.2 + float(maxi(groups[g][0], groups[g][1])) * 0.28 + 1.9
		if up:
			_baked("tw%d" % g, s, h, depths[g], func(b):
				for i in groups[g]:
					var fx := (float(i) + 0.5) / n
					var k := lerpf(0.62, 1.0, float(g) / 2.0)
					var base := Vector2(w * (0.5 + (fx - 0.5) * 0.9), horizon + h * 0.03 + (k - 0.62) * h * 0.2)
					var th := h * 0.47 * k
					_tower(b, base, th, Towers.ORDER[i], (1.0 - k) * 1.1, air, i, 1)
					_well(b, base + Vector2(0, h * 0.012), th * 0.15, Essence.color(String(Towers.TOWERS[Towers.ORDER[i]].get("essence", "air"))), (1.0 - k) * 1.1, air, i, 1))
		for i in groups[g]:
			var id: String = Towers.ORDER[i]
			var info: Dictionary = Towers.TOWERS[id]
			var col: Color = Essence.color(String(info.get("essence", "air")))
			var fx := (float(i) + 0.5) / n
			var k := lerpf(0.62, 1.0, float(g) / 2.0)
			var x := w * (0.5 + (fx - 0.5) * 0.9)
			var base := Vector2(x, horizon + h * 0.03 + (k - 0.62) * h * 0.2)
			var th := h * 0.47 * k
			var start := 0.2 + float(i) * 0.28
			var rise := _ease((t - start) / 1.8)
			var haze := (1.0 - k) * 1.1
			var top := base
			if rise >= 0.999 or up:
				top = _tower(tb, base, th, id, haze, air, i, 2 if up else 0)
			elif rise > 0.01:
				# Still rising: it grows up out of the ground (drawn on its own,
				# stretched up from its foot).
				_put(tb, depths[g])
				tb = UI.Draw.Batch.new()
				var rb := UI.Draw.Batch.new()
				top = _tower(rb, base, th, id, haze, air, i)
				draw_set_transform_matrix(_cam(depths[g]) * Transform2D(0.0, Vector2(1.0, rise), 0.0, base) * Transform2D(0.0, -base))
				rb.flush(self)
				layers += 1
				top = base + (top - base) * Vector2(1.0, rise)
			if rise > 0.01:
				tops.append({"at": top, "kind": String(info.get("beast_kind", id)), "w": th * 0.32, "col": col, "rise": rise, "i": i})
			_well(tb, base + Vector2(0, h * 0.012), th * 0.15, col, haze, air, i, 2 if up else 0)
			_mist(tb, x - th * 0.35, x + th * 0.35, base.y + h * 0.005, h * 0.025, Color(0.6, 0.45, 0.6), 0.18, i * 7, clock * 6.0 * u)
		for tp in tops:
			var at: Vector2 = tp["at"]
			var bw: float = tp["w"]
			var bob := sin(clock * 0.9 + float(tp["i"]) * 1.1) * bw * 0.05
			var bc := at + Vector2(0, -bw * 0.55 + bob)
			tp["bc"] = bc
			tb.soft(bc, Vector2(bw * 0.9, bw * 0.75), Color(tp["col"], 0.22 * keen * float(tp["rise"])))
		_put(tb, depths[g])
		var xf := _cam(depths[g])
		for tp in tops:
			_guardian(tp["kind"], tp["bc"], tp["w"], keen * float(tp["rise"]), xf)
		if g == 1:
			var mb := UI.Draw.Batch.new()
			_mist(mb, -60.0 * u, w + 60.0 * u, horizon + h * 0.08, h * 0.05, Color(0.62, 0.48, 0.62), 0.16, 33, clock * 9.0 * u)
			_put(mb, 0.8)
	# The hill in front, and the people on it, marks of light coming to them.
	var people := 9
	var ph := h * 0.12
	var hill_y := h * 0.9
	var spots: Array = []
	var chests: Array = []
	for j in people:
		var fp := Vector2(w * (0.07 + 0.86 * (float(j) + 0.5) / people) + (Art.rnd(j + 30) - 0.5) * 20.0 * u, hill_y - 4.0 * u + (Art.rnd(j + 40) - 0.2) * 12.0 * u)
		var pj := ph * (0.9 + 0.2 * Art.rnd(j + 5))
		spots.append([fp, pj])
		chests.append(fp + Vector2(pj * 0.04, -pj * 0.52))  # (where _person puts the mark)
	# The hill, its grass and the people standing still on it are kept.
	_baked("hill", s, h, 1.2, func(b):
		_hill(b, _ridge(-80.0 * u, w + 80.0 * u, hill_y, 18.0 * u, 4, 0.0, s.y + 80.0 * u, 30), Color(0.045, 0.035, 0.06), Color(0.85, 0.6, 0.7, 0.3))
		for g in 26:  # grass against the glow
			var gx := Art.rnd(g * 7 + 3) * w
			var gy := hill_y - 18.0 * u * 0.5 + Art.rnd(g * 3 + 1) * 10.0 * u
			var lean := (Art.rnd(g + 60) - 0.5) * 4.0 * u
			b.line(Vector2(gx, gy + 6.0 * u), Vector2(gx + lean, gy - 6.0 * u), Color(0.06, 0.05, 0.08), 1.4 * u)
		for j in people:
			var cloak := Color(0.16, 0.13, 0.2).lerp(Color(0.25, 0.16, 0.18), Art.rnd(j + 9))
			_person(b, spots[j][0], spots[j][1], j * 3 + 1, cloak))
	var fg := UI.Draw.Batch.new()
	for j in people:
		var lit := smoothstep(risen_at + 1.4 + float(j % 6) * 0.45, risen_at + 2.0 + float(j % 6) * 0.45, t)
		if lit > 0.0:
			var mc: Color = Essence.color(KINDS[(j * 5 + 1) % 6])
			var mp: Vector2 = chests[j]
			fg.soft(mp, Vector2.ONE * ph * 0.32, Color(mc, 0.5 * lit))
			fg.circle(mp, maxf(1.2, ph * 0.04), Color(mc.lightened(0.5), lit), 10)
	_put(fg, 1.2)
	# The marks drifting from the guardians down to them.
	if keen > 0.0:
		var fx := UI.Draw.Batch.new()
		var motes := _count(int(OPENING["motes"]))
		for m in motes:
			var i := m % n
			var g := 0 if i == 2 or i == 3 else (1 if i == 1 or i == 4 else 2)
			var k := lerpf(0.62, 1.0, float(g) / 2.0)
			var from := Vector2(w * (0.5 + ((float(i) + 0.5) / n - 0.5) * 0.9), horizon + h * 0.03 - h * 0.47 * k * 1.2)
			var to: Vector2 = chests[(m * 5 + 1) % people]
			var period := 6.0 + Art.rnd(m + 7) * 3.0
			var f := fposmod(clock + Art.rnd(m) * period, period) / period
			var e := f * f * (3.0 - 2.0 * f)
			var mc: Color = Essence.color(String(Towers.TOWERS[Towers.ORDER[i]].get("essence", "air")))
			for tr in 3:
				var ft := maxf(e - 0.025 * tr, 0.0)
				var p: Vector2 = from.lerp(to, ft) + Vector2(sin(ft * TAU + float(m)) * 22.0 * u, -sin(ft * PI) * 40.0 * u)
				var al := keen * sin(f * PI) * (1.0 - 0.3 * tr)
				fx.soft(p, Vector2.ONE * (7.0 - tr * 1.5) * u, Color(mc, 0.4 * al))
				if tr == 0:
					fx.circle(p, 1.7 * u, Color(mc.lightened(0.55), 0.95 * al), 10)
		_put(fx, 1.0)
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.6)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


# --- 3. the dead land and the Turning ----------------------------------------------------

## A distant city on the horizon: rooftops round the foot of its tower, a
## warm glow over it, its tower's beacon in its essence.
func _far_city(b, p: Vector2, k: float, i: int, air: Color) -> void:
	var u := _u * k
	var col: Color = Essence.color(String(Towers.TOWERS[Towers.ORDER[i % 6]].get("essence", "air")))
	var body := _hz(Color(0.1, 0.08, 0.13), 0.35, air)
	b.soft(p + Vector2(0, -12.0 * u), Vector2(70.0, 26.0) * u, Color(Art.LAMP, 0.16))
	var tw := 4.5 * u
	var th := 54.0 * u
	b.polygon(PackedVector2Array([p + Vector2(-tw, 0), p + Vector2(-tw * 0.7, -th), p + Vector2(0, -th - 9.0 * u), p + Vector2(tw * 0.7, -th), p + Vector2(tw, 0)]), body)
	b.rect(Rect2(p + Vector2(-tw * 0.3, -th * 0.6), Vector2(tw * 0.6, 2.0 * u)), Color(col, 0.6))
	Art.light(b, p + Vector2(0, -th - 11.0 * u), Vector2.ONE * 18.0 * u, Color(col, 0.55))
	b.circle(p + Vector2(0, -th - 11.0 * u), 1.8 * u, col.lightened(0.5), 8)
	for j in 9:
		var hx := p.x + (float(j) - 4.0) * 6.5 * u
		var hh := (6.0 + 9.0 * Art.rnd(i * 11 + j)) * u
		b.rect(Rect2(hx - 3.2 * u, p.y - hh, 6.4 * u, hh), body)
		b.polygon(PackedVector2Array([Vector2(hx - 3.8 * u, p.y - hh), Vector2(hx, p.y - hh - 3.0 * u), Vector2(hx + 3.8 * u, p.y - hh)]), body)
		if Art.rnd(i * 7 + j + 3) > 0.3:
			b.rect(Rect2(hx - 1.0 * u, p.y - hh * 0.65, 2.0 * u, 2.0 * u), Art.LAMP if j % 3 != 1 else col.lightened(0.3))


## A dead tree: a bent trunk, bare branches (a silhouette).
static func _dead_tree(b, base: Vector2, th: float, col: Color, seed: int) -> void:
	var lean := (Art.rnd(seed) - 0.5) * th * 0.3
	var top := base + Vector2(lean, -th)
	b.line(base, base.lerp(top, 0.6) + Vector2(th * 0.04, 0), col, maxf(1.5, th * 0.07))
	b.line(base.lerp(top, 0.6) + Vector2(th * 0.04, 0), top, col, maxf(1.0, th * 0.045))
	for k in 4:
		var f := 0.45 + 0.13 * k
		var p := base.lerp(top, f)
		var sg := -1.0 if (k + seed) % 2 == 0 else 1.0
		var tip := p + Vector2(sg * th * (0.3 - 0.05 * k), -th * (0.18 + 0.05 * k))
		b.line(p, tip, col, maxf(0.8, th * (0.035 - 0.005 * k)))
		b.line(p.lerp(tip, 0.6), p.lerp(tip, 0.6) + Vector2(sg * th * 0.08, -th * 0.12), col, maxf(0.7, th * 0.02))


## A spoked wheel, turned by `ang`, its hub brass.
func _wheel(b, c: Vector2, r: float, ang: float, col: Color) -> void:
	b.circle(c, r + maxf(1.0, r * 0.12), Art.OUTLINE, 20)
	b.disc(c, r, col.darkened(0.2), Shade.METAL)
	b.circle(c, r * 0.78, col.darkened(0.55), 20)
	for k in 6:
		var d := Vector2.from_angle(ang + TAU * k / 6.0)
		b.line(c, c + d * r * 0.8, col.darkened(0.1), maxf(1.0, r * 0.12))
	b.disc(c, r * 0.24, Art.GILT, Shade.METAL)


## The Turning's engine, facing right, its front at `front` on the rail at
## `rail_y`, `q` its scale; `ang` turns its wheels. Returns its smokestack's top.
func _engine(b, front: float, rail_y: float, q: float, ang: float) -> Vector2:
	var steel := Art.STEEL.lightened(0.12)
	var x0 := front - 100.0 * q
	var ow := maxf(1.0, 1.2 * q * 0.5)
	# The essence it runs on: a cool light under it.
	b.soft(Vector2(front - 50.0 * q, rail_y - 6.0 * q), Vector2(52.0 * q, 10.0 * q), Color(0.55, 0.88, 1.0, 0.35))
	# Frame and running board.
	var frame := Rect2(x0, rail_y - 17.0 * q, 94.0 * q, 5.0 * q)
	b.rect(frame.grow(ow), Art.OUTLINE)
	b.box(frame, Art.IRON.lightened(0.1), Shade.METAL)
	# The boiler: a long drum lying on it, brass bands round it.
	var by := rail_y - 27.0 * q
	b.line(Vector2(x0 + 22.0 * q, by), Vector2(front - 12.0 * q, by), Art.OUTLINE, 21.0 * q + ow * 2.0)
	b.bar(Vector2(x0 + 22.0 * q, by), Vector2(front - 12.0 * q, by), steel, 21.0 * q)
	for bx in [36.0, 54.0, 72.0]:
		b.bar(Vector2(x0 + bx * q, by - 10.5 * q), Vector2(x0 + bx * q, by + 10.5 * q), Art.GILT, 2.2 * q)
	# The smokebox front, the lamp and its beam.
	b.bar(Vector2(front - 24.0 * q, by), Vector2(front - 12.0 * q, by), Art.IRON.lightened(0.12), 21.0 * q)
	b.bar(Vector2(front - 12.0 * q, by - 10.5 * q), Vector2(front - 12.0 * q, by + 10.5 * q), Art.IRON.lightened(0.3), 2.4 * q)
	Art.rivets(b, Vector2(front - 22.0 * q, by - 7.0 * q), Vector2(front - 22.0 * q, by + 7.0 * q), 3.5 * q, 0.7 * q, Art.GILT)
	var lamp := Vector2(front - 9.0 * q, by - 14.0 * q)
	b.box(Rect2(lamp - Vector2(4.0, 3.5) * q, Vector2(8.0, 7.0) * q), Art.GILT_LO.lightened(0.2), Shade.METAL)
	Art.light(b, lamp + Vector2(4.0 * q, 0), Vector2(26.0, 18.0) * q, Color(Art.LAMP, 0.55))
	b.disc(lamp + Vector2(3.0 * q, 0), 2.6 * q, Art.GILT_HI)
	# Its long beam ahead along the line.
	_shaft(b, lamp + Vector2(4.0 * q, 0), 5.0 * q, lamp + Vector2(150.0 * q, 10.0 * q), 46.0 * q, Color(Art.LAMP, 0.3), 0.0)
	# The smokestack, flared, and the domes.
	var stx := front - 24.0 * q
	var stack := PackedVector2Array([Vector2(stx - 3.5 * q, by - 9.0 * q), Vector2(stx - 4.0 * q, by - 20.0 * q), Vector2(stx - 6.5 * q, by - 27.0 * q),
		Vector2(stx + 6.5 * q, by - 27.0 * q), Vector2(stx + 4.0 * q, by - 20.0 * q), Vector2(stx + 3.5 * q, by - 9.0 * q)])
	b.poly(stack, Art.IRON.lightened(0.18), ow, Shade.METAL)
	b.rect(Rect2(stx - 6.5 * q, by - 27.5 * q, 13.0 * q, 2.0 * q), Art.GILT)
	for dm in [[x0 + 48.0 * q, 5.5 * q, Art.GILT], [x0 + 64.0 * q, 4.5 * q, Art.GILT_LO.lightened(0.3)]]:
		var dc := Vector2(dm[0], by - 9.5 * q)
		var dr: float = dm[1]
		var dome := PackedVector2Array()
		for k in 9:
			dome.append(dc + Vector2.from_angle(PI + PI * k / 8.0) * dr)
		b.poly(dome, dm[2], ow, Shade.METAL)
	# The cab at the back: a lit window, a roof.
	var cab := Rect2(x0, rail_y - 50.0 * q, 25.0 * q, 33.0 * q)
	b.rect(cab.grow(ow), Art.OUTLINE)
	b.box(cab, steel.darkened(0.1), Shade.SLAB)
	b.rect(Rect2(cab.position.x, cab.position.y + 4.0 * q, cab.size.x, 1.2 * q), Color(Art.GILT, 0.7))
	var cw := Rect2(cab.position.x + 6.0 * q, cab.position.y + 8.0 * q, 13.0 * q, 11.0 * q)
	b.soft(cw.get_center(), cw.size * 1.4, Color(0.55, 0.88, 1.0, 0.35))
	Art.vgrad(b, cw, Color(0.8, 0.95, 1.0), Color(0.45, 0.75, 0.95))
	var roof := Rect2(x0 - 3.0 * q, cab.position.y - 3.5 * q, 31.0 * q, 4.0 * q)
	b.rect(roof.grow(ow), Art.OUTLINE)
	b.box(roof, Art.IRON.lightened(0.05), Shade.SLAB)
	# The cowcatcher.
	b.poly(PackedVector2Array([Vector2(front - 8.0 * q, rail_y - 13.0 * q), Vector2(front + 5.0 * q, rail_y - 1.0 * q), Vector2(front - 8.0 * q, rail_y - 1.0 * q)]), Art.IRON.lightened(0.15), ow, Shade.METAL)
	# Wheels: a small leading pair, three drivers joined by their rod.
	_wheel(b, Vector2(front - 20.0 * q, rail_y - 5.0 * q), 5.0 * q, ang * 1.6, Art.IRON.lightened(0.3))
	var pins: Array = []
	for wx in [32.0, 50.0, 68.0]:
		var wc := Vector2(x0 + wx * q, rail_y - 8.5 * q)
		_wheel(b, wc, 8.5 * q, ang, Color(0.55, 0.12, 0.1))
		pins.append(wc + Vector2.from_angle(ang) * 4.5 * q)
	b.line(pins[0], pins[2], Art.OUTLINE, 3.6 * q)
	b.bar(pins[0], pins[2], Color(0.75, 0.75, 0.8), 2.2 * q, Shade.METAL)
	for p in pins:
		b.circle(p, 1.4 * q, Art.GILT_HI, 8)
	return Vector2(stx, by - 28.0 * q)


## One of the Turning's cars between `x0` and `x1`: a maroon body with
## brass lines, a curved roof, a row of lit arched windows spilling their
## light, and two bogies.
func _rail_car(b, x0: float, x1: float, rail_y: float, q: float, ang: float, seed: int) -> void:
	var ow := maxf(1.0, 0.6 * q)
	var body := Rect2(x0, rail_y - 44.0 * q, x1 - x0, 30.0 * q)
	var maroon := Art.MAHOGANY.lightened(0.05)
	# Couplings toward the car in front.
	b.line(Vector2(x1, rail_y - 18.0 * q), Vector2(x1 + 5.0 * q, rail_y - 18.0 * q), Art.OUTLINE, 3.0 * q)
	b.rect(body.grow(ow), Art.OUTLINE)
	b.box(body, maroon, Shade.WOOD)
	var roof := PackedVector2Array()
	for k in 13:
		var f := float(k) / 12.0
		roof.append(Vector2(lerpf(x0 - 2.0 * q, x1 + 2.0 * q, f), body.position.y - sin(f * PI) * 5.0 * q))
	roof.append(Vector2(x1 + 2.0 * q, body.position.y + 1.0 * q))
	roof.append(Vector2(x0 - 2.0 * q, body.position.y + 1.0 * q))
	b.poly(roof, Color(0.12, 0.1, 0.13), ow, Shade.METAL)
	b.rect(Rect2(x0, body.position.y + 3.0 * q, body.size.x, 1.2 * q), Color(Art.GILT, 0.8))
	b.rect(Rect2(x0, body.end.y - 4.0 * q, body.size.x, 1.2 * q), Color(Art.GILT, 0.6))
	var nw := maxi(3, int((x1 - x0) / (15.0 * q)))
	var gap := (x1 - x0) / nw
	for k in nw:
		var wx := x0 + gap * (k + 0.5)
		var wr := Rect2(wx - gap * 0.3, body.position.y + 7.0 * q, gap * 0.6, 13.0 * q)
		var flick := 0.88 + 0.12 * sin(clock * 2.3 + float(seed * 5 + k))
		b.soft(Vector2(wx, rail_y + 9.0 * q), Vector2(gap * 0.8, 7.0 * q), Color(Art.LAMP, 0.22 * flick))
		b.soft(wr.get_center(), wr.size * 1.3, Color(Art.LAMP, 0.35 * flick))
		var arch := PackedVector2Array([wr.end, Vector2(wr.position.x, wr.end.y)])
		for j in 7:
			arch.append(Vector2(wr.get_center().x, wr.position.y + wr.size.x * 0.5) + Vector2.from_angle(PI + PI * j / 6.0) * wr.size.x * 0.5)
		_ink(b, arch, Art.OUTLINE, ow * 2.0)
		b.polygon(arch, Art.LAMP.lightened(0.15 * flick))
		b.rect(Rect2(wr.position.x, wr.end.y - wr.size.y * 0.35, wr.size.x, wr.size.y * 0.35), Color(Art.LAMP.darkened(0.3), 0.8))
	for bx in [x0 + 12.0 * q, x1 - 12.0 * q]:
		b.box(Rect2(bx - 9.0 * q, rail_y - 14.0 * q, 18.0 * q, 4.0 * q), Art.IRON, Shade.METAL)
		_wheel(b, Vector2(bx - 5.0 * q, rail_y - 5.0 * q), 4.6 * q, ang * 1.8, Art.IRON.lightened(0.3))
		_wheel(b, Vector2(bx + 5.0 * q, rail_y - 5.0 * q), 4.6 * q, ang * 1.8 + 0.5, Art.IRON.lightened(0.3))


func _turning(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.5
	var air := Color(0.2, 0.15, 0.26)
	var q := minf(w * 0.0021, h * 0.0042)
	var rail_y := h * 0.8
	var front := w * 0.82
	_focus = Vector2(front - 60.0 * q, rail_y - 30.0 * q)
	_push = 0.06
	_pan = Vector2(-24.0 * u, 0)
	var speed := 70.0 * u  # how fast the land slides by (at depth 1)
	var run := clock * speed
	var moon := Vector2(w * 0.8, h * 0.16)
	_baked("sky", s, h, 0.08, func(b):
		var m := 60.0 * u
		_sky(b, Rect2(-m, -m, w + m * 2.0, horizon + m), [[0.0, Art.SKY[0]], [0.5, Art.SKY[1]], [0.88, Color(0.2, 0.13, 0.25)], [1.0, Color(0.32, 0.18, 0.28)]])
		b.rect(Rect2(-m, horizon, w + m * 2.0, s.y - horizon + m), Color(0.05, 0.04, 0.06))
		Art.light(b, moon, Vector2.ONE * 110.0 * u, Color(Art.MOON, 0.16))
		b.circle(moon, 15.0 * u + 1.5, Color(Art.MOON, 0.25), 32)
		b.disc(moon, 15.0 * u, Art.MOON)
		for c in [[-0.3, -0.2, 0.28], [0.25, 0.15, 0.2], [-0.05, 0.35, 0.16], [0.35, -0.3, 0.12]]:
			b.soft(moon + Vector2(c[0], c[1]) * 15.0 * u, Vector2.ONE * c[2] * 15.0 * u, Color(0.6, 0.55, 0.5, 0.3)))
	var sk := UI.Draw.Batch.new()
	_stars(sk, Rect2(-40.0 * u, -30.0 * u, w + 80.0 * u, horizon * 0.8), 70, 21)
	for k in 5:  # long clouds, lit by the moon on top
		var cy := h * (0.1 + 0.07 * k)
		var cx := fposmod(Art.rnd(k * 5) * w + clock * (3.0 + k) * u, w + 400.0 * u) - 200.0 * u
		var cw := (160.0 + 90.0 * Art.rnd(k + 3)) * u
		sk.soft(Vector2(cx, cy), Vector2(cw, 12.0 * u), Color(0.08, 0.06, 0.12, 0.55))
		sk.soft(Vector2(cx - cw * 0.1, cy - 5.0 * u), Vector2(cw * 0.7, 5.0 * u), Color(0.6, 0.55, 0.7, 0.12))
	# The storm of wild essence far off: deadly, and kept away from.
	var sx := w * 0.17
	var sy := horizon - h * 0.12
	var churn := clock * 0.25
	var glow_s := 0.75 + 0.25 * sin(clock * 1.7) * sin(clock * 0.9)
	Art.light(sk, Vector2(sx, sy + h * 0.05), Vector2(170.0, 80.0) * u, Color(Palette.WILD, 0.32 * glow_s))
	for k in 6:  # its rain of essence
		var rx := sx + (float(k) - 2.5) * 22.0 * u + sin(clock * 0.7 + k) * 6.0 * u
		_shaft(sk, Vector2(rx, sy + 10.0 * u), 16.0 * u, Vector2(rx - 18.0 * u, horizon + 4.0 * u), 30.0 * u, Color(Palette.WILD, 0.16), 0.35)
	for k in 9:
		var ang := churn + TAU * k / 9.0
		var cp := Vector2(sx, sy - 6.0 * u) + Vector2(cos(ang) * 70.0, sin(ang) * 16.0) * u
		sk.soft(cp, Vector2(70.0, 34.0) * u, Color(0.07, 0.05, 0.1, 0.85))
		sk.soft(cp + Vector2(-10.0, -12.0) * u, Vector2(44.0, 14.0) * u, Color(0.5, 0.45, 0.62, 0.14))
		sk.soft(cp + Vector2(6.0, 14.0) * u, Vector2(46.0, 12.0) * u, Color(Palette.WILD, 0.2 * glow_s))
	var strike := floorf(clock / 3.3)
	var since := clock - strike * 3.3
	if since < 0.5:
		var fl := exp(-since * 9.0)
		var bolt := PackedVector2Array()
		var bx := sx + (Art.rnd(int(strike) * 3) - 0.5) * 80.0 * u
		for k in 8:
			bolt.append(Vector2(bx + (Art.rnd(k + int(strike) * 11) - 0.5) * 24.0 * u, sy + float(k) * (horizon - sy) / 7.0))
		sk.soft(Vector2(bx, sy), Vector2(120.0, 60.0) * u, Color(Palette.WILD_HOT, 0.3 * fl))
		sk.polyline(bolt, Color(Palette.WILD, 0.4 * fl), 6.0 * u)
		sk.polyline(bolt, Color(Palette.WILD_HOT, fl), 1.8 * u)
	_put(sk, 0.12)
	# The far land: the cities on the horizon, the hills between.
	var far := UI.Draw.Batch.new()
	var far_off := run * 0.04
	_hill(far, _ridge(-80.0 * u, w + 80.0 * u, horizon - h * 0.015, 14.0 * u, 3, far_off, horizon + 30.0 * u, 30), _hz(Art.FAR, 0.35, air), Color(0.7, 0.55, 0.75, 0.15))
	var city_x := [0.36, 0.52, 0.66, 0.9, 1.15]
	for i in city_x.size():
		var span := w + 300.0 * u
		var cx := fposmod(float(city_x[i]) * w - far_off * 1.4 + 150.0 * u, span) - 150.0 * u
		_far_city(far, Vector2(cx, horizon + 2.0 * u), 0.7 + 0.25 * Art.rnd(i + 4), i + 1, air)
	_mist(far, -80.0 * u, w + 80.0 * u, horizon + 4.0 * u, h * 0.03, Color(0.55, 0.45, 0.65), 0.2, 9, clock * 4.0 * u)
	_put(far, 0.2)
	# The dead plain: cracked, glowing faintly where wild essence seeps,
	# bare trees going by.
	var mid := UI.Draw.Batch.new()
	Art.vgrad(mid, Rect2(-80.0 * u, horizon + 6.0 * u, w + 160.0 * u, s.y - horizon), Color(0.2, 0.15, 0.2), Color(0.06, 0.045, 0.065))
	for k in 3:  # long low swells of the plain, lit on their tops by the moon
		var dy := horizon + (rail_y - horizon) * (0.2 + 0.25 * k)
		var dune := _ridge(-80.0 * u, w + 80.0 * u, dy, (5.0 + 3.0 * k) * u, 11 + k * 5, run * (0.15 + 0.1 * k), dy + (rail_y - horizon) * 0.4, 20)
		_hill(mid, dune, Color(0.13, 0.1, 0.13).darkened(0.15 * k), Color(0.75, 0.68, 0.8, 0.16))
	for i in 16:  # stones lying about, lit on top
		var x := fposmod(Art.rnd(i * 23 + 9) * (w + 240.0 * u) - run * 0.4, w + 240.0 * u) - 120.0 * u
		var k := Art.rnd(i * 19 + 4)
		var y := horizon + (0.1 + 0.85 * k) * (rail_y - horizon)
		var sr := (2.0 + 4.0 * k) * u * (0.7 + 0.6 * Art.rnd(i + 2))
		mid.contact(Vector2(x, y + sr * 0.3), sr, 0.4)
		mid.oval(Vector2(x, y), Vector2(sr, sr * 0.6), 0.0, Color(0.2, 0.16, 0.19), Shade.BALL)
	var off_m := run * 0.35
	var span_m := w + 240.0 * u
	for i in 10:
		var x := fposmod(Art.rnd(i * 13 + 2) * span_m - off_m, span_m) - 120.0 * u
		var y := horizon + (0.12 + 0.6 * Art.rnd(i * 17 + 5)) * (rail_y - horizon)
		var crack := PackedVector2Array([Vector2(x, y)])
		for k in 5:
			crack.append(crack[k] + Vector2((Art.rnd(i * 5 + k) - 0.2) * 26.0 * u, (Art.rnd(i * 3 + k + 9) - 0.5) * 6.0 * u))
		mid.polyline(crack, Color(0.0, 0.0, 0.0, 0.55), 1.6 * u)
		if i % 3 == 0:
			mid.polyline(crack, Color(Palette.WILD, 0.25 + 0.1 * sin(clock * 1.3 + i)), 0.9 * u)
			mid.soft(crack[2], Vector2(26.0, 6.0) * u, Color(Palette.WILD, 0.08))
	var off_t := run * 0.5
	for i in 7:
		var x := fposmod(Art.rnd(i * 29 + 1) * span_m - off_t, span_m) - 120.0 * u
		var y := horizon + (0.2 + 0.5 * Art.rnd(i * 31 + 3)) * (rail_y - horizon)
		var k := (y - horizon) / (rail_y - horizon)
		_dead_tree(mid, Vector2(x, y), (20.0 + 26.0 * k + 10.0 * Art.rnd(i + 70)) * u, Color(0.04, 0.03, 0.05), i)
		mid.contact(Vector2(x, y), 8.0 * u * (0.6 + k), 0.3)
	_put(mid, 0.6)
	# The track and the train.
	var tr := UI.Draw.Batch.new()
	var gap := 9.0 * q
	var off := fposmod(run, gap)
	var bx := -80.0 * u - off
	while bx < w + 80.0 * u:
		tr.box(Rect2(bx, rail_y - 0.5 * q, 6.0 * q, 3.2 * q), Color(0.17, 0.12, 0.09), Shade.WOOD)
		bx += gap
	Art.vgrad(tr, Rect2(-80.0 * u, rail_y - 2.0 * q, w + 160.0 * u, 16.0 * q), Color(0.24, 0.2, 0.21), Color(0.1, 0.08, 0.1, 0.0))
	tr.rect(Rect2(-80.0 * u, rail_y + 2.6 * q, w + 160.0 * u, 2.4 * q), Color(0.09, 0.07, 0.08))
	tr.rect(Rect2(-80.0 * u, rail_y - 1.6 * q, w + 160.0 * u, 2.2 * q), Color(0.45, 0.42, 0.45))
	tr.rect(Rect2(-80.0 * u, rail_y - 1.6 * q, w + 160.0 * u, 0.8 * q), Color(0.85, 0.8, 0.8, 0.8))
	var ang := run / maxf(8.5 * q, 1.0)
	var car_len := 70.0 * q
	var stack := _engine(tr, front, rail_y, q, ang)
	var x1 := front - 104.0 * q
	for k in 3:
		_rail_car(tr, x1 - car_len, x1, rail_y, q, ang, k)
		x1 -= car_len + 5.0 * q
	# Steam from the stack, streaming back, lit from above.
	var puffs := _count(12)
	for m in puffs:
		var f := fposmod(clock * 0.32 + float(m) / float(puffs), 1.0)
		var p := stack + Vector2(-f * 260.0 * q - f * f * 80.0 * q, -f * 40.0 * q + f * f * 10.0 * q) + Vector2(sin(f * 7.0 + m) * 4.0 * q, 0)
		var pr := (7.0 + 22.0 * f) * q
		var pa := (1.0 - f) * smoothstep(0.0, 0.06, f)
		tr.soft(p, Vector2(pr * 1.3, pr), Color(0.45, 0.42, 0.55, 0.75 * pa))
		tr.soft(p + Vector2(-pr * 0.3, -pr * 0.35), Vector2(pr * 0.85, pr * 0.6), Color(0.9, 0.87, 0.97, 0.45 * pa))
		tr.soft(p + Vector2(pr * 0.3, pr * 0.2), Vector2(pr * 0.7, pr * 0.5), Color(0.55, 0.88, 1.0, 0.1 * pa))
	# The trail of essence it leaves.
	var trail := _count(10)
	for m in trail:
		var f := fposmod(clock * 0.5 + float(m) / float(trail), 1.0)
		var p := Vector2(x1 + car_len * 0.5 - f * 160.0 * q, rail_y - 6.0 * q - sin(f * PI) * 10.0 * q)
		tr.soft(p, Vector2.ONE * (3.0 + 4.0 * f) * q, Color(0.55, 0.88, 1.0, 0.45 * (1.0 - f) * smoothstep(0.0, 0.1, f)))
	_put(tr, 1.0)
	# The near ground racing by: rocks, a dead branch.
	var fg := UI.Draw.Batch.new()
	Art.vgrad(fg, Rect2(-80.0 * u, rail_y + 10.0 * q, w + 160.0 * u, s.y - rail_y), Color(0.05, 0.035, 0.05, 0.0), Color(0.03, 0.02, 0.035, 0.6))
	var off_f := run * 1.5
	var span_f := w + 400.0 * u
	for i in 6:
		var x := fposmod(Art.rnd(i * 41 + 7) * span_f - off_f, span_f) - 200.0 * u
		var y := h * (0.9 + 0.06 * Art.rnd(i + 3))
		var rr := (14.0 + 18.0 * Art.rnd(i * 3 + 1)) * u
		var rock := PackedVector2Array([Vector2(x - rr, y + rr * 0.3), Vector2(x - rr * 0.7, y - rr * 0.35), Vector2(x - rr * 0.1, y - rr * 0.6), Vector2(x + rr * 0.6, y - rr * 0.4), Vector2(x + rr, y + rr * 0.3)])
		fg.poly(rock, Color(0.13, 0.1, 0.13), 1.2, Shade.SLAB)
		if i % 3 == 1:
			_dead_tree(fg, Vector2(x + rr * 1.4, y + rr * 0.2), rr * 3.2, Color(0.02, 0.015, 0.025), i + 20)
	_put(fg, 1.4)
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.65)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


# --- 4. a city lit by crystals ----------------------------------------------------------

## A house of the city, its foot at `foot` (left corner): a shaded wall, a
## tiled roof, a chimney, lit windows with frames, sometimes a door.
func _house(b, foot: Vector2, hw: float, hh: float, wall: Color, seed: int, haze: float, air: Color, detail: bool) -> void:
	var u := _u
	var ink := _hz(Art.OUTLINE, haze * 0.7, air)
	var ow := maxf(0.8, 1.0 * u)
	var wr := Rect2(foot.x, foot.y - hh, hw, hh)
	var roof_h := hw * (0.35 + 0.2 * Art.rnd(seed + 1))
	var rf := PackedVector2Array([Vector2(wr.position.x - 3.0 * u, wr.position.y), Vector2(wr.get_center().x, wr.position.y - roof_h), Vector2(wr.end.x + 3.0 * u, wr.position.y)])
	# Chimney first (behind the roof).
	if Art.rnd(seed + 5) > 0.35:
		var cx := wr.position.x + hw * (0.22 + 0.5 * Art.rnd(seed + 6))
		var ch := Rect2(cx - 3.0 * u, wr.position.y - roof_h * 0.95, 6.0 * u, roof_h * 0.8)
		b.rect(ch.grow(ow), ink)
		b.box(ch, _hz(Color(0.28, 0.16, 0.13), haze, air), Shade.SLAB)
	b.rect(wr.grow(ow), ink)
	b.box(wr, _hz(wall, haze, air), Shade.WOOD if detail else Shade.SLAB)
	_ink(b, rf, ink, ow * 2.0)
	var tile := _hz(Color(0.2, 0.12, 0.14).lerp(Color(0.14, 0.12, 0.2), Art.rnd(seed + 9)), haze, air)
	Art.quad(b, rf[0], rf[1], rf[1], rf[0].lerp(rf[2], 0.5), tile.lightened(0.15), tile.lightened(0.1), tile, tile)
	Art.quad(b, rf[0].lerp(rf[2], 0.5), rf[1], rf[1], rf[2], tile.darkened(0.2), tile.darkened(0.1), tile.darkened(0.35), tile.darkened(0.45))
	if detail:
		for k in 3:  # rows of tiles
			var f := 0.3 + 0.22 * k
			b.line(rf[0].lerp(rf[1], f), rf[2].lerp(rf[1], f), Color(ink, 0.4), maxf(0.7, 0.7 * u))
	# Windows in rows.
	var cols := 2 if hw < 40.0 * u else 3
	var rows := maxi(1, int(hh / (22.0 * u)))
	for rj in rows:
		for ci in cols:
			var wx := wr.position.x + hw * (float(ci) + 0.5) / cols
			var wy := wr.position.y + hh * (float(rj) + 0.4) / (rows + 0.4)
			var ww := hw * 0.14
			var wh := ww * 1.4
			var lit := Art.rnd(seed * 13 + rj * 5 + ci) > 0.28
			var win := Rect2(wx - ww * 0.5, wy - wh * 0.5, ww, wh)
			b.rect(win.grow(ow), ink)
			if lit:
				var wc: Color = Art.LAMP if Art.rnd(seed + rj + ci * 7) > 0.22 else Essence.color(KINDS[(seed + ci) % 6]).lightened(0.35)
				if detail:
					b.soft(win.get_center(), win.size * 1.6, Color(wc, 0.3))
				Art.vgrad(b, win, _hz(wc.lightened(0.2), haze * 0.3, air), _hz(wc.darkened(0.15), haze * 0.3, air))
				if detail:
					b.rect(Rect2(wx - 0.5 * ow, win.position.y, ow, wh), Color(ink, 0.7))
					b.rect(Rect2(win.position.x, wy - 0.5 * ow, ww, ow), Color(ink, 0.7))
			else:
				b.rect(win, _hz(Color(0.05, 0.04, 0.07), haze, air))
			if detail:
				b.rect(Rect2(win.position.x - ow, win.end.y, ww + ow * 2.0, maxf(1.0, ow * 1.4)), _hz(wall.lightened(0.25), haze, air))
	if detail and Art.rnd(seed + 11) > 0.4:
		var dw := hw * 0.2
		var door := Rect2(wr.get_center().x - dw * 0.5 + hw * 0.2, foot.y - dw * 1.7, dw, dw * 1.7)
		b.rect(door.grow(ow), ink)
		b.box(door, Art.WALNUT, Shade.WOOD)
		b.circle(door.position + Vector2(dw * 0.75, dw * 0.9), maxf(0.8, dw * 0.08), Art.GILT, 6)


func _city(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.6
	var air := Color(0.34, 0.22, 0.32)
	var tbase := Vector2(w * 0.76, horizon + h * 0.02)
	var th := h * 0.5
	_focus = Vector2(w * 0.6, h * 0.6)
	_push = 0.08
	_pan = Vector2(-10.0 * u, 4.0 * u)
	# The road from the tower's gate down through the city toward us.
	var road := PackedVector2Array([tbase + Vector2(0, -2.0 * u), Vector2(w * 0.66, h * 0.72), Vector2(w * 0.5, h * 0.8), Vector2(w * 0.34, h * 0.9), Vector2(w * 0.18, h * 1.04)])
	_baked("sky", s, h, 0.1, func(b):
		var m := 60.0 * u
		_sky(b, Rect2(-m, -m, w + m * 2.0, horizon + m), [[0.0, Art.SKY[0]], [0.4, Art.SKY[1]], [0.78, Art.SKY[2]], [1.0, Color(0.55, 0.32, 0.32)]])
		b.rect(Rect2(-m, horizon, w + m * 2.0, s.y - horizon + m), Color(0.07, 0.05, 0.07))
		b.soft(Vector2(w * 0.35, horizon), Vector2(w * 0.6, h * 0.25), Color(Art.LAMP, 0.16))
		_hill(b, _ridge(-m, w + m, horizon - h * 0.02, 20.0 * u, 8, 0.0, horizon + 20.0 * u, 30), _hz(Art.FAR, 0.45, air), Color(0.8, 0.55, 0.6, 0.15)))
	var sk := UI.Draw.Batch.new()
	_stars(sk, Rect2(-40.0 * u, -30.0 * u, w + 80.0 * u, horizon * 0.5), 40, 41)
	_put(sk, 0.12)
	# The tower over the city, its light, mist about its foot.
	_baked("tower", s, h, 0.45, func(b):
		_mist(b, -60.0 * u, w + 60.0 * u, horizon - h * 0.01, h * 0.04, Color(0.7, 0.5, 0.55), 0.22, 3, 0.0)
		for i in 14:  # the far rooftops climbing toward the tower
			var x := lerpf(-20.0 * u, w * 0.7, i / 13.0)
			var hh := (16.0 + 18.0 * Art.rnd(i + 70)) * u
			var hw := (24.0 + 16.0 * Art.rnd(i + 71)) * u
			_house(b, Vector2(x, horizon + h * 0.02 - (x / w) * h * 0.02), hw, hh, Color(0.13, 0.1, 0.13), i + 100, 0.55, air, false))
	var tw := UI.Draw.Batch.new()
	var top := _tower(tw, tbase, th, CITY_TOWER, 0.0, air, 4)
	var ec: Color = Essence.color(String(Towers.TOWERS[CITY_TOWER].get("essence", "fire")))
	# The beacon's shafts sweeping slowly.
	for k in 2:
		var ang := sin(clock * 0.2 + k * 2.0) * 0.5 + (PI * 0.5 if k == 0 else -PI * 0.5) * 0.0
		var dir := Vector2.from_angle(-PI * 0.5 + ang + (0.9 if k == 0 else -0.9))
		_shaft(tw, top, 4.0 * u, top + dir * h * 0.7, 90.0 * u, Color(ec, 0.06), 0.0)
	# The gate, lit, and the great crystals at its foot pouring light out.
	var gw := th * 0.06
	var gate := PackedVector2Array([tbase + Vector2(-gw, -th * 0.07), tbase + Vector2(-gw, -th * 0.07 - gw * 1.4)])
	for k in 7:
		gate.append(tbase + Vector2(0, -th * 0.07 - gw * 1.4) + Vector2.from_angle(PI + PI * k / 6.0) * gw)
	gate.append(tbase + Vector2(gw, -th * 0.07))
	Art.light(tw, tbase + Vector2(0, -th * 0.1), Vector2(110.0, 70.0) * u, Color(Art.LAMP, 0.3))
	_ink(tw, gate, Art.OUTLINE, 2.0 * u)
	tw.polygon(gate, Art.LAMP.lightened(0.15))
	for k in 6:
		var cx := tbase.x + (float(k) - 2.5) * th * 0.045
		var cc: Color = Essence.color(KINDS[k])
		var ch := th * (0.07 + 0.04 * Art.rnd(k + 2))
		var cp := Vector2(cx, tbase.y + th * 0.005)
		var gem := PackedVector2Array([cp + Vector2(-ch * 0.22, 0), cp + Vector2(-ch * 0.18, -ch * 0.7), cp + Vector2(0, -ch), cp + Vector2(ch * 0.18, -ch * 0.7), cp + Vector2(ch * 0.22, 0)])
		var pulse := 0.8 + 0.2 * sin(clock * 1.4 + k)
		tw.soft(cp + Vector2(0, -ch * 0.5), Vector2(ch * 1.3, ch * 1.1), Color(cc, 0.45 * pulse))
		_ink(tw, gem, Art.OUTLINE, 1.8 * u)
		tw.polygon(gem, cc.darkened(0.15))
		tw.polygon(PackedVector2Array([gem[0], gem[1], gem[2], cp + Vector2(0, -ch * 0.1)]), cc.lightened(0.25))
		tw.line(gem[1].lerp(gem[2], 0.3), cp + Vector2(-ch * 0.05, -ch * 0.15), Color(1, 1, 1, 0.5), maxf(1.0, ch * 0.04))
	_put(tw, 0.5)
	# The middle of the city: the road, the houses either side of it, lamps.
	var md := UI.Draw.Batch.new()
	md.polyline(road, Color(0.1, 0.07, 0.08), 26.0 * u)
	md.polyline(road, Color(0.24, 0.18, 0.16), 18.0 * u)
	for k in 14:  # cobbles in the lamplight
		var p := _along(road, 0.05 + 0.065 * k)
		md.rect(Rect2(p - Vector2(5.0, 1.0) * u, Vector2(10.0, 2.0) * u), Color(0.32, 0.25, 0.21, 0.6))
	# The crystals' light running down the road into the city.
	var flows := _count(10)
	for m in flows:
		var f := fposmod(clock * 0.07 + float(m) / float(flows), 1.0)
		var p := _along(road, f)
		var fc: Color = Essence.color(KINDS[m % 6])
		md.soft(p, Vector2(14.0, 5.0) * u * (0.6 + f), Color(fc, 0.55 * sin(f * PI)))
	_put(md, 0.75)
	_baked("houses", s, h, 0.75, func(b):
		var x := -30.0 * u
		var i := 0
		while x < w * 0.6:
			var hw := (40.0 + 26.0 * Art.rnd(i * 7 + 3)) * u
			var hh := (46.0 + 38.0 * Art.rnd(i * 11 + 5)) * u
			var gy := h * 0.75 + (x / w) * h * -0.06
			var wall: Color = [Color(0.3, 0.22, 0.2), Color(0.26, 0.2, 0.24), Color(0.33, 0.26, 0.2), Color(0.22, 0.2, 0.26)][i % 4]
			_house(b, Vector2(x, gy), hw, hh, wall, i, 0.1, air, true)
			x += hw + 4.0 * u
			i += 1
		_house(b, Vector2(w * 0.86, h * 0.76), 70.0 * u, 70.0 * u, Color(0.28, 0.2, 0.22), 40, 0.05, air, true)
		_house(b, Vector2(w * 0.94, h * 0.79), 80.0 * u, 58.0 * u, Color(0.24, 0.2, 0.25), 41, 0.0, air, true))
	# Bunting across the road and crystal lamps along it.
	var bu := UI.Draw.Batch.new()
	var a0 := Vector2(w * 0.3, h * 0.6)
	var a1 := Vector2(w * 0.86, h * 0.64)
	var sag := PackedVector2Array()
	for k in 17:
		var f := float(k) / 16.0
		sag.append(a0.lerp(a1, f) + Vector2(0, sin(f * PI) * h * 0.06 + sin(clock * 0.9 + f * 4.0) * 1.5 * u))
	bu.polyline(sag, Color(0.06, 0.05, 0.06), 1.4 * u)
	for k in range(1, 16):
		var p: Vector2 = sag[k]
		var fc: Color = Essence.color(KINDS[k % 6]).darkened(0.1)
		var flap := sin(clock * 2.0 + k) * 1.5 * u
		var flag := PackedVector2Array([p + Vector2(-5.0 * u, 0), p + Vector2(5.0 * u, 0), p + Vector2(flap, 11.0 * u)])
		bu.fill(flag, fc, Shade.CLOTH)
	for k in 5:
		var lp := _along(road, 0.1 + 0.2 * float(k)) + Vector2(16.0 * u * (1.0 + float(k) * 0.3), 0)
		var lc: Color = Essence.color(KINDS[(k + 1) % 6])
		var ph := (26.0 + 10.0 * k) * u
		var pulse := 0.8 + 0.2 * sin(clock * 2.0 + float(k))
		bu.soft(lp + Vector2(0, 2.0 * u), Vector2(ph * 0.8, ph * 0.18), Color(lc, 0.3 * pulse))
		_limb(bu, lp, lp + Vector2(0, -ph), Color(0.12, 0.1, 0.12), maxf(1.5, 2.0 * u))
		var cp := lp + Vector2(0, -ph - 5.0 * u)
		Art.light(bu, cp, Vector2.ONE * (22.0 + 4.0 * k) * u, Color(lc, 0.4 * pulse))
		var gem := PackedVector2Array([cp + Vector2(0, -6.0 * u), cp + Vector2(3.5 * u, 0), cp + Vector2(0, 6.0 * u), cp + Vector2(-3.5 * u, 0)])
		_ink(bu, gem, Art.OUTLINE, 1.6 * u)
		bu.polygon(gem, lc.lightened(0.25))
		bu.polygon(PackedVector2Array([gem[0], gem[3], cp]), lc.lightened(0.65))
	_put(bu, 0.8)
	# Marked climbers coming down the road, their marks glowing.
	var cl := UI.Draw.Batch.new()
	for k in 5:
		var f := fposmod(clock * 0.028 + float(k) * 0.2 + 0.05, 1.0)
		var p := _along(road, f)
		var ch := lerpf(18.0, 50.0, f * f) * u
		var a := smoothstep(0.0, 0.08, f) * (1.0 - smoothstep(0.92, 1.0, f))
		var mc: Color = Essence.color(KINDS[(k * 2 + 3) % 6])
		var cloak := Color(0.2, 0.15, 0.22).lerp(mc.darkened(0.6), 0.3)
		var chest := _person(cl, p + Vector2((float(k % 2) - 0.5) * 10.0 * u * f, 0), ch, k * 5 + 2, cloak, a, clock * 5.0 + k, true)
		cl.soft(chest, Vector2.ONE * ch * 0.4, Color(mc, 0.55 * a))
		cl.circle(chest, maxf(1.2, ch * 0.045), Color(mc.lightened(0.5), a), 10)
	# Motes of crystal light rising over the roofs.
	var motes := _count(int(OPENING["motes"]) / 2)
	for m in motes:
		var f := fposmod(clock * 0.05 + Art.rnd(m + 3), 1.0)
		var p := Vector2(Art.rnd(m * 7 + 1) * w * 0.7, h * 0.8 - f * h * 0.55) + Vector2(sin(clock * 0.7 + float(m)) * 10.0 * u, 0)
		cl.soft(p, Vector2.ONE * 5.0 * u, Color(Essence.color(KINDS[m % 6]), 0.45 * sin(f * PI)))
	_put(cl, 0.9)
	# Near rooftops framing the bottom corners, chimney smoke.
	_baked("near", s, h, 1.2, func(b):
		# Near rooftops framing the bottom corners: tiled, lit along their
		# ridges, a dormer window glowing in one, a chimney.
		for side in [0, 1]:
			var x0: float = -60.0 * u if side == 0 else w * 0.83
			var x1: float = w * 0.19 if side == 0 else w + 60.0 * u
			var peak := Vector2(lerpf(x0, x1, 0.45 if side == 0 else 0.55), h * (0.79 if side == 0 else 0.84))
			var eave_y := h * (0.92 if side == 0 else 0.95)
			var roof := PackedVector2Array([Vector2(x0, eave_y), peak, Vector2(x1, eave_y), Vector2(x1, s.y + 60.0 * u), Vector2(x0, s.y + 60.0 * u)])
			var tile := Color(0.2, 0.11, 0.11) if side == 0 else Color(0.15, 0.11, 0.17)
			_ink(b, roof, Art.OUTLINE, 2.4 * u)
			Art.quad(b, Vector2(x0, eave_y), peak, peak + Vector2(0, h * 0.3), Vector2(x0, eave_y + h * 0.3), tile.lightened(0.12), tile.lightened(0.18), tile, tile.darkened(0.2))
			Art.quad(b, peak, Vector2(x1, eave_y), Vector2(x1, eave_y + h * 0.3), peak + Vector2(0, h * 0.3), tile.darkened(0.25), tile.darkened(0.35), tile.darkened(0.55), tile.darkened(0.45))
			for k in 6:  # courses of tiles
				var f := float(k + 1) / 7.0
				b.line(Vector2(x0, eave_y).lerp(peak, 1.0 - f) + Vector2(0, h * 0.04 * f), Vector2(x1, eave_y).lerp(peak, 1.0 - f) + Vector2(0, h * 0.04 * f), Color(0, 0, 0, 0.3), 1.2 * u)
			b.polyline(PackedVector2Array([Vector2(x0, eave_y), peak, Vector2(x1, eave_y)]), Color(0.95, 0.65, 0.45, 0.4), 1.6 * u)
		# A dormer in the left roof, lit.
		var dm := Vector2(w * 0.06, h * 0.88)
		var dwr := Rect2(dm - Vector2(12.0, 0) * u, Vector2(24.0, 22.0) * u)
		b.soft(dwr.get_center(), Vector2(40.0, 30.0) * u, Color(Art.LAMP, 0.3))
		b.rect(dwr.grow(4.0 * u), Art.OUTLINE)
		b.box(dwr.grow(3.0 * u), Color(0.26, 0.18, 0.15), Shade.WOOD)
		Art.vgrad(b, dwr, Art.LAMP.lightened(0.2), Art.LAMP.darkened(0.2))
		b.rect(Rect2(dwr.get_center().x - 1.0 * u, dwr.position.y, 2.0 * u, dwr.size.y), Art.OUTLINE)
		b.rect(Rect2(dwr.position.x, dwr.get_center().y - 1.0 * u, dwr.size.x, 2.0 * u), Art.OUTLINE)
		b.poly(PackedVector2Array([dwr.position + Vector2(-8.0 * u, -3.0 * u), Vector2(dwr.get_center().x, dwr.position.y - 16.0 * u), Vector2(dwr.end.x + 8.0 * u, dwr.position.y - 3.0 * u)]), Color(0.22, 0.12, 0.12), 1.4, Shade.SLAB)
		var chm := Rect2(w * 0.12, h * 0.72, 14.0 * u, h * 0.12)
		b.rect(chm.grow(1.5 * u), Art.OUTLINE)
		b.box(chm, Color(0.3, 0.16, 0.13), Shade.SLAB)
		b.box(Rect2(chm.position - Vector2(2.0 * u, 3.0 * u), Vector2(chm.size.x + 4.0 * u, 5.0 * u)), Color(0.34, 0.2, 0.16), Shade.SLAB))
	var sm := UI.Draw.Batch.new()
	for m in _count(6):
		var f := fposmod(clock * 0.12 + float(m) / 6.0, 1.0)
		var p := Vector2(w * 0.12 + 7.0 * u, h * 0.71) + Vector2(f * 40.0 * u + sin(f * 5.0 + m) * 5.0 * u, -f * h * 0.3)
		sm.soft(p, Vector2.ONE * (6.0 + 18.0 * f) * u, Color(0.45, 0.38, 0.45, 0.25 * (1.0 - f) * smoothstep(0.0, 0.1, f)))
	_put(sm, 1.2)
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.6)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


# --- 5. inside the carriage: the conductor's nod, the doors, the window ----------------

## Fills `area` with the carriage's wall around the openings in `holes`
## (so what's seen through them is covered at their edges): oak above,
## walnut below `dado`, both with grain.
func _wall_around(b, area: Rect2, holes: Array, dado: float) -> void:
	var ys: Array = [area.position.y, area.end.y, dado]
	for hr in holes:
		ys.append(hr.position.y)
		ys.append(hr.end.y)
	ys.sort()
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		if y1 - y0 < 0.5 or y0 < area.position.y or y1 > area.end.y:
			continue
		var xs: Array = [[area.position.x, area.end.x]]
		for hr in holes:
			if hr.position.y < y1 - 0.25 and hr.end.y > y0 + 0.25:
				var next: Array = []
				for seg in xs:
					if hr.end.x <= seg[0] or hr.position.x >= seg[1]:
						next.append(seg)
						continue
					if hr.position.x > seg[0]:
						next.append([seg[0], hr.position.x])
					if hr.end.x < seg[1]:
						next.append([hr.end.x, seg[1]])
				xs = next
		var below := y0 >= dado - 0.25
		for seg in xs:
			var r := Rect2(seg[0], y0, seg[1] - seg[0], y1 - y0)
			if below:
				Art.vgrad(b, r, Art.WALNUT.darkened(0.2), Art.WALNUT.darkened(0.5))
			else:
				Art.vgrad(b, r, Art.OAK.darkened(0.42).lerp(Art.OAK.darkened(0.28), (y0 - area.position.y) / maxf(area.size.y, 1.0)), Art.OAK.darkened(0.28))


## Raised panels on a wall between `x0` and `x1`, from `y0` to `y1`, skipping
## any that touch the openings in `holes`: bevelled, grained, a gilt keyline.
func _panels(b, x0: float, x1: float, y0: float, y1: float, holes: Array, col: Color, seed: int) -> void:
	var u := _u
	var pw := 70.0 * u
	var n := maxi(1, int((x1 - x0) / pw))
	var gap := (x1 - x0) / n
	for i in n:
		var r := Rect2(x0 + gap * i + 6.0 * u, y0 + 6.0 * u, gap - 12.0 * u, y1 - y0 - 12.0 * u)
		if r.size.x < 8.0 or r.size.y < 8.0:
			continue
		var clear := true
		for hr in holes:
			if Rect2(hr).grow(10.0 * u).intersects(r):
				clear = false
		if not clear:
			continue
		Art.bevel(b, r, col, maxf(2.0, 3.0 * u))
		Art.grain(b, r.grow(-3.0 * u), col, seed + i, u, true, true)
		Art.moulding(b, r.grow(-5.0 * u), u, Art.GILT, 0.35)


## The view out of a carriage window `wr`: night, the moon, far hills
## sliding by, nearer ones and telegraph poles faster, and the tower
## (`grow` 0..1 how near it is).
func _window_view(b, wr: Rect2, slide: float, grow: float, tower: String) -> void:
	var u := _u
	var horizon := wr.position.y + wr.size.y * 0.74
	_sky(b, Rect2(wr.position, Vector2(wr.size.x, horizon - wr.position.y)), [[0.0, Art.SKY[0]], [0.6, Art.SKY[1]], [1.0, Art.SKY[2]]])
	b.rect(Rect2(wr.position.x, horizon, wr.size.x, wr.end.y - horizon), Art.GROUND)
	_stars(b, Rect2(wr.position, Vector2(wr.size.x, wr.size.y * 0.5)), 18, 61)
	var moon := wr.position + Vector2(wr.size.x * 0.18, wr.size.y * 0.2)
	b.soft(moon, Vector2.ONE * wr.size.y * 0.2, Color(Art.MOON, 0.18))
	b.disc(moon, maxf(3.0, wr.size.y * 0.04), Art.MOON)
	_hill(b, _ridge(wr.position.x - 20.0, wr.end.x + 20.0, horizon, 10.0 * u, 3, slide * 0.12, wr.end.y), Art.FAR, Color(0.6, 0.5, 0.7, 0.2))
	var th := lerpf(wr.size.y * 0.25, wr.size.y * 0.75, grow)
	var tx := wr.position.x + wr.size.x * lerpf(0.78, 0.62, grow)
	_tower(b, Vector2(tx, horizon + 3.0), th, tower, lerpf(0.55, 0.15, grow), Color(0.22, 0.15, 0.27), 4)
	_mist(b, wr.position.x, wr.end.x, horizon + 2.0, wr.size.y * 0.04, Color(0.5, 0.42, 0.6), 0.2, 5, slide * 0.2)
	_hill(b, _ridge(wr.position.x - 20.0, wr.end.x + 20.0, horizon + wr.size.y * 0.12, 7.0 * u, 9, slide * 0.5, wr.end.y), Art.NEAR, Color(0.5, 0.4, 0.6, 0.15))
	# Telegraph poles flashing past.
	var pg := wr.size.x * 0.7
	var px := wr.position.x + fposmod(-slide * 1.2, pg) - pg * 0.1
	while px < wr.end.x + pg:
		b.rect(Rect2(px, wr.position.y + wr.size.y * 0.3, maxf(2.0, 3.0 * u), wr.size.y), Color(0.03, 0.025, 0.04))
		b.rect(Rect2(px - 8.0 * u, wr.position.y + wr.size.y * 0.34, 18.0 * u, maxf(1.5, 2.0 * u)), Color(0.03, 0.025, 0.04))
		px += pg
	# The glass: a faint sheen across it.
	b.polygon(PackedVector2Array([wr.position + Vector2(wr.size.x * 0.1, 0), wr.position + Vector2(wr.size.x * 0.28, 0), wr.position + Vector2(wr.size.x * 0.12, wr.size.y), wr.position + Vector2(-wr.size.x * 0.06, wr.size.y)]), Color(1, 1, 1, 0.035))


## A window frame of brass round `r`: bevelled, with a keyline inside.
func _frame(b, r: Rect2, wd: float) -> void:
	Art.bevel(b, Rect2(r.position - Vector2(wd, wd), Vector2(r.size.x + wd * 2.0, wd)), Art.GILT_LO.lightened(0.18), maxf(1.5, wd * 0.35))
	Art.bevel(b, Rect2(r.position + Vector2(-wd, r.size.y), Vector2(r.size.x + wd * 2.0, wd)), Art.GILT_LO, maxf(1.5, wd * 0.35))
	Art.bevel(b, Rect2(r.position - Vector2(wd, 0), Vector2(wd, r.size.y)), Art.GILT_LO.lightened(0.1), maxf(1.5, wd * 0.35))
	Art.bevel(b, Rect2(r.end.x, r.position.y, wd, r.size.y), Art.GILT_LO.lightened(0.02), maxf(1.5, wd * 0.35))
	b.rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Color(0, 0, 0, 0.5))


## Heavy curtains drawn back either side of `r`, tied with gilt cord: folds
## shaded across, a fringe at the hem.
func _curtains(b, r: Rect2, u: float) -> void:
	for sg in [0, 1]:
		var cx: float = r.position.x if sg == 0 else r.end.x
		var cw := 34.0 * u
		var top := r.position.y - 14.0 * u
		var tie := r.position.y + r.size.y * 0.58
		var out := -1.0 if sg == 0 else 1.0
		var inner := cx - out * cw * 0.6
		var outer := cx + out * cw * 0.6
		var pts := PackedVector2Array([Vector2(inner, top), Vector2(outer, top), Vector2(outer + out * 4.0 * u, r.end.y + 16.0 * u), Vector2(cx + out * cw * 0.1, r.end.y + 16.0 * u),
			Vector2(cx + out * cw * 0.05, tie + 6.0 * u), Vector2(inner + out * cw * 0.15, tie - r.size.y * 0.2)])
		_ink(b, pts, Art.OUTLINE, 2.4 * u)
		b.fill(pts, Art.CURTAIN, Shade.CLOTH)
		for k in 4:  # folds
			var f := 0.2 + 0.2 * k
			var a := Vector2(lerpf(inner, outer, f), top + 4.0 * u)
			var e := Vector2(lerpf(cx + out * cw * 0.08, outer + out * 3.0 * u, f), r.end.y + 14.0 * u)
			b.line(a, a.lerp(e, 0.5) + Vector2(0, 0), Color(0, 0, 0, 0.28), 2.4 * u)
			b.line(a + Vector2(2.0 * u, 0), a.lerp(e, 0.5) + Vector2(2.0 * u, 0), Color(1, 0.6, 0.6, 0.08), 1.2 * u)
			b.line(a.lerp(e, 0.55), e, Color(0, 0, 0, 0.25), 2.0 * u)
		b.rect(Rect2(minf(cx + out * cw * 0.1, outer + out * 4.0 * u), r.end.y + 13.0 * u, absf(outer + out * 4.0 * u - (cx + out * cw * 0.1)), 4.0 * u), Color(Art.GILT, 0.7))
		var tc := Vector2(cx + out * cw * 0.12, tie)
		b.stroke(tc + Vector2(-out * 12.0 * u, -4.0 * u), tc + Vector2(out * 14.0 * u, 2.0 * u), Art.GILT, 2.6 * u)
		b.ball(tc + Vector2(out * 16.0 * u, 8.0 * u), 3.2 * u, Art.GILT)
	# The brass rail they hang from.
	Art.bar(b, Rect2(r.position.x - 48.0 * u, r.position.y - 18.0 * u, r.size.x + 96.0 * u, 5.0 * u))
	for sg in [-1.0, 1.0]:
		var ex: float = r.position.x - 50.0 * u if sg < 0.0 else r.end.x + 50.0 * u
		b.ball(Vector2(ex, r.position.y - 15.5 * u), 4.0 * u, Art.GILT)


## A brass wall lamp: a bracket, a glass chimney and its flame, its light.
func _sconce(b, c: Vector2, u: float, flick: float) -> void:
	Art.light(b, c, Vector2(120.0, 100.0) * u, Color(Art.LAMP, 0.2 * flick))
	b.stroke(c + Vector2(0, 16.0 * u), c + Vector2(0, 26.0 * u), Art.GILT_LO.lightened(0.2), 3.0 * u)
	b.poly(PackedVector2Array([c + Vector2(-9.0, 10.0) * u, c + Vector2(9.0, 10.0) * u, c + Vector2(5.0, 16.0) * u, c + Vector2(-5.0, 16.0) * u]), Art.GILT, 1.0, Shade.METAL)
	b.soft(c, Vector2(8.0, 12.0) * u, Color(Art.LAMP.lightened(0.3), 0.6 * flick))
	b.poly(PackedVector2Array([c + Vector2(-5.0, 10.0) * u, c + Vector2(-6.0, -4.0) * u, c + Vector2(-3.5, -12.0) * u, c + Vector2(3.5, -12.0) * u, c + Vector2(6.0, -4.0) * u, c + Vector2(5.0, 10.0) * u]), Color(1.0, 0.9, 0.75, 0.25), 1.0, Shade.SLAB)
	b.oval(c + Vector2(0, 2.0 * u), Vector2(2.2, 5.0 * flick) * u, 0.0, Art.LAMP.lightened(0.4), Shade.SOFT)
	b.circle(c + Vector2(0, 3.0 * u), 1.2 * u, Color(1, 1, 0.9), 8)
	b.rect(Rect2(c + Vector2(-4.0, -13.5) * u, Vector2(8.0, 2.0) * u), Art.GILT)


## The conductor on the platform: peaked cap with a badge, a long
## double-breasted coat with lapels, gilt buttons and epaulettes, gloves,
## a lantern in one hand; `nod` 0..1 (the head dips, the eyes close, then
## open again with a small smile).
func _conductor(b, feet: Vector2, ch: float, nod: float, smile: float) -> void:
	var navy := Color(0.13, 0.15, 0.27)
	var skin := Color(0.86, 0.68, 0.55)
	var glove := Color(0.88, 0.86, 0.8)
	var ow := clampf(ch * 0.006, 1.0, 1.8)
	b.contact(feet, ch * 0.2, 0.5)
	# Trousers and boots under the coat.
	for sg in [-1.0, 1.0]:
		_limb(b, feet + Vector2(sg * ch * 0.06, -ch * 0.2), feet + Vector2(sg * ch * 0.06, -ch * 0.04), navy.darkened(0.3), ch * 0.06)
		b.poly(PackedVector2Array([feet + Vector2(sg * ch * 0.06 - ch * 0.04, -ch * 0.05), feet + Vector2(sg * ch * 0.06 + ch * 0.04 + sg * ch * 0.02, -ch * 0.05),
			feet + Vector2(sg * ch * 0.06 + ch * 0.05 + sg * ch * 0.02, 0), feet + Vector2(sg * ch * 0.06 - ch * 0.05, 0)]), Color(0.06, 0.05, 0.06), ow, Shade.METAL)
	# The far arm hanging down.
	b.limb(PackedVector2Array([feet + Vector2(ch * 0.15, -ch * 0.64), feet + Vector2(ch * 0.19, -ch * 0.48), feet + Vector2(ch * 0.19, -ch * 0.34)]), PackedFloat32Array([ch * 0.065, ch * 0.058]), navy.darkened(0.08))
	b.ball(feet + Vector2(ch * 0.19, -ch * 0.32), ch * 0.03, glove)
	# The coat.
	var coat := PackedVector2Array([feet + Vector2(-ch * 0.17, -ch * 0.14), feet + Vector2(-ch * 0.155, -ch * 0.62), feet + Vector2(-ch * 0.07, -ch * 0.7),
		feet + Vector2(ch * 0.07, -ch * 0.7), feet + Vector2(ch * 0.155, -ch * 0.62), feet + Vector2(ch * 0.17, -ch * 0.14), feet + Vector2(0, -ch * 0.12)])
	b.poly(coat, navy, ow, Shade.CLOTH)
	# Lapels and the shirt at the throat.
	b.polygon(PackedVector2Array([feet + Vector2(-ch * 0.04, -ch * 0.7), feet + Vector2(ch * 0.04, -ch * 0.7), feet + Vector2(0, -ch * 0.6)]), Color(0.92, 0.9, 0.86))
	b.polygon(PackedVector2Array([feet + Vector2(-ch * 0.03, -ch * 0.66), feet + Vector2(ch * 0.03, -ch * 0.66), feet + Vector2(0, -ch * 0.61)]), Color(0.45, 0.1, 0.12))
	for sg in [-1.0, 1.0]:
		var lap := PackedVector2Array([feet + Vector2(sg * ch * 0.045, -ch * 0.7), feet + Vector2(sg * ch * 0.1, -ch * 0.66), feet + Vector2(sg * ch * 0.06, -ch * 0.58), feet + Vector2(0, -ch * 0.56)])
		b.fill(lap, navy.lightened(0.12), Shade.CLOTH)
		b.polyline(lap, Color(Art.OUTLINE, 0.6), 1.0)
	# Two rows of buttons, a belt, the hem's gilt line.
	for k in 4:
		for sg in [-1.0, 1.0]:
			Art.rivet(b, feet + Vector2(sg * ch * 0.045, -ch * (0.53 - 0.075 * k)), maxf(1.2, ch * 0.011), Art.GILT)
	b.box(Rect2(feet + Vector2(-ch * 0.16, -ch * 0.4), Vector2(ch * 0.32, ch * 0.035)), Color(0.08, 0.06, 0.05), Shade.SLAB)
	b.box(Rect2(feet + Vector2(-ch * 0.022, -ch * 0.405), Vector2(ch * 0.044, ch * 0.045)), Art.GILT, Shade.METAL)
	b.line(feet + Vector2(-ch * 0.165, -ch * 0.17), feet + Vector2(ch * 0.165, -ch * 0.17), Color(Art.GILT, 0.6), maxf(1.0, ch * 0.006))
	b.line(feet + Vector2(0, -ch * 0.37), feet + Vector2(0, -ch * 0.13), Color(Art.OUTLINE, 0.7), 1.2)
	# A watch chain.
	var chain := PackedVector2Array()
	for k in 7:
		var f := float(k) / 6.0
		chain.append(feet + Vector2(lerpf(-ch * 0.045, -ch * 0.13, f), -ch * 0.47 + sin(f * PI) * ch * 0.025))
	b.polyline(chain, Art.GILT_HI, maxf(1.0, ch * 0.005))
	# Epaulettes with their fringe.
	for sg in [-1.0, 1.0]:
		var ep := feet + Vector2(sg * ch * 0.12, -ch * 0.665)
		b.oval(ep, Vector2(ch * 0.05, ch * 0.018), sg * 0.15, Art.GILT, Shade.METAL)
		for k in 5:
			var fx := ep + Vector2((float(k) - 2.0) * ch * 0.018, ch * 0.012)
			b.line(fx, fx + Vector2(0, ch * 0.022), Art.GILT_HI, maxf(0.8, ch * 0.005))
	# The near arm, holding the lantern out a little.
	var hand := feet + Vector2(-ch * 0.25, -ch * 0.42)
	b.limb(PackedVector2Array([feet + Vector2(-ch * 0.14, -ch * 0.64), feet + Vector2(-ch * 0.22, -ch * 0.52), hand]), PackedFloat32Array([ch * 0.065, ch * 0.058]), navy)
	b.bar(hand + Vector2(ch * 0.015, -ch * 0.02), hand + Vector2(ch * 0.03, -ch * 0.04), Art.GILT, ch * 0.05)
	var lamp := hand + Vector2(0, ch * 0.1)
	Art.light(b, lamp, Vector2.ONE * ch * 0.45, Color(Art.LAMP, 0.4))
	b.line(hand, lamp + Vector2(0, -ch * 0.05), Art.OUTLINE, maxf(1.2, ch * 0.006))
	b.poly(PackedVector2Array([lamp + Vector2(-ch * 0.03, -ch * 0.05), lamp + Vector2(ch * 0.03, -ch * 0.05), lamp + Vector2(ch * 0.02, -ch * 0.065), lamp + Vector2(-ch * 0.02, -ch * 0.065)]), Art.GILT_LO.lightened(0.2), 1.0, Shade.METAL)
	b.box(Rect2(lamp - Vector2(ch * 0.028, ch * 0.045), Vector2(ch * 0.056, ch * 0.08)), Art.LAMP.lightened(0.25), Shade.SLAB)
	b.rect(Rect2(lamp + Vector2(-ch * 0.032, ch * 0.035), Vector2(ch * 0.064, ch * 0.014)), Art.GILT_LO.lightened(0.2))
	b.ball(hand, ch * 0.03, glove)
	# The head, dipping in the nod.
	var head := feet + Vector2(ch * 0.012 * nod, -ch * 0.8 + ch * 0.04 * nod)
	b.bar(feet + Vector2(0, -ch * 0.7), head + Vector2(0, ch * 0.05), skin.darkened(0.2), ch * 0.055)
	for sg in [-1.0, 1.0]:
		b.ball(head + Vector2(sg * ch * 0.073, ch * 0.005), ch * 0.016, skin.darkened(0.08))
	b.ball(head, ch * 0.074, skin)
	b.soft(head + Vector2(-ch * 0.035, ch * 0.025), Vector2.ONE * ch * 0.02, Color(0.9, 0.4, 0.4, 0.3))
	b.soft(head + Vector2(ch * 0.035, ch * 0.025), Vector2.ONE * ch * 0.02, Color(0.9, 0.4, 0.4, 0.3))
	# Grey sideburns.
	for sg in [-1.0, 1.0]:
		b.oval(head + Vector2(sg * ch * 0.062, -ch * 0.012), Vector2(ch * 0.013, ch * 0.03), 0.0, Color(0.62, 0.6, 0.6), Shade.CLOTH)
	for sg in [-1.0, 1.0]:
		var e: Vector2 = head + Vector2(sg * ch * 0.028, -ch * 0.004)
		b.line(e + Vector2(-ch * 0.017, -ch * 0.02 - nod * ch * 0.004), e + Vector2(ch * 0.015, -ch * 0.024 + sg * ch * 0.002), Color(0.45, 0.42, 0.42), maxf(1.2, ch * 0.007))
		if nod > 0.45:
			b.arc(e + Vector2(0, -ch * 0.004), ch * 0.011, 0.2, PI - 0.2, 6, Art.OUTLINE, maxf(1.0, ch * 0.004))
		else:
			b.oval(e, Vector2(ch * 0.008, ch * 0.01), 0.0, Art.OUTLINE, Shade.WHITE)
			b.circle(e + Vector2(-ch * 0.003, -ch * 0.004), maxf(0.6, ch * 0.0028), Color(1, 1, 1, 0.9), 6)
	b.oval(head + Vector2(ch * 0.004, ch * 0.012), Vector2(ch * 0.012, ch * 0.016), 0.0, skin.darkened(0.08))
	# The moustache, and a small smile under it after the nod.
	var mo := head + Vector2(0, ch * 0.034)
	var mous := PackedVector2Array([mo + Vector2(-ch * 0.045, ch * 0.008), mo + Vector2(-ch * 0.02, -ch * 0.006), mo, mo + Vector2(ch * 0.02, -ch * 0.006), mo + Vector2(ch * 0.045, ch * 0.008), mo + Vector2(ch * 0.02, ch * 0.004), mo + Vector2(0, ch * 0.007), mo + Vector2(-ch * 0.02, ch * 0.004)])
	b.fill(mous, Color(0.6, 0.58, 0.58), Shade.CLOTH)
	b.arc(mo + Vector2(0, ch * 0.006), ch * 0.016, 0.4, PI - 0.4, 6, Color(0.45, 0.2, 0.18, 0.4 + 0.5 * smile), maxf(1.0, ch * 0.004))
	# The cap: crown, gilt band, badge, shiny visor.
	var cap := PackedVector2Array([head + Vector2(-ch * 0.078, -ch * 0.05), head + Vector2(-ch * 0.09, -ch * 0.11), head + Vector2(-ch * 0.03, -ch * 0.128),
		head + Vector2(ch * 0.05, -ch * 0.125), head + Vector2(ch * 0.092, -ch * 0.108), head + Vector2(ch * 0.078, -ch * 0.05)])
	b.poly(cap, navy.darkened(0.12), ow, Shade.CLOTH)
	b.rect(Rect2(head + Vector2(-ch * 0.078, -ch * 0.07), Vector2(ch * 0.156, ch * 0.016)), Art.GILT)
	b.disc(head + Vector2(0, -ch * 0.098), ch * 0.014, Art.GILT_HI, Shade.METAL)
	var visor := PackedVector2Array([head + Vector2(-ch * 0.085, -ch * 0.054), head + Vector2(ch * 0.085, -ch * 0.054), head + Vector2(ch * 0.07, -ch * 0.036), head + Vector2(-ch * 0.07, -ch * 0.036)])
	b.poly(visor, Color(0.05, 0.05, 0.07), 1.0, Shade.METAL)


## The carriage's sliding door panel in `r`: walnut with a raised panel, a
## small window (the platform's glow through it while it's out there), a
## brass pull, a gilt edge where the pair meet.
func _door_panel(b, r: Rect2, edge_left: bool, glow_x: float) -> void:
	var u := _u
	b.box(r, Art.WALNUT.lightened(0.04), Shade.WOOD)
	Art.grain(b, r.grow(-2.0 * u), Art.WALNUT.lightened(0.04), 7 if edge_left else 9, u, true, false)
	var low := Rect2(r.position.x + r.size.x * 0.15, r.position.y + r.size.y * 0.52, r.size.x * 0.7, r.size.y * 0.38)
	if low.size.x > 6.0:
		Art.bevel(b, low, Art.WALNUT, maxf(1.5, 2.5 * u))
	var pane := Rect2(r.position.x + r.size.x * 0.18, r.position.y + r.size.y * 0.1, r.size.x * 0.64, r.size.y * 0.32)
	if pane.size.x > 4.0:
		Art.vgrad(b, pane, Art.SKY[1], Art.SKY[2])
		if glow_x > pane.position.x and glow_x < pane.end.x:
			b.soft(Vector2(glow_x, pane.get_center().y), Vector2.ONE * 10.0 * u, Color(Art.LAMP, 0.6))
		b.polygon(PackedVector2Array([pane.position + Vector2(pane.size.x * 0.3, 0), pane.position + Vector2(pane.size.x * 0.5, 0), pane.position + Vector2(pane.size.x * 0.2, pane.size.y), pane.position + Vector2(0, pane.size.y)]), Color(1, 1, 1, 0.06))
		Art.moulding(b, pane.grow(2.0 * u), u, Art.GILT, 0.7)
	var ex := r.end.x - 2.0 if edge_left else r.position.x
	Art.post(b, Rect2(ex, r.position.y, 2.5 * u, r.size.y), Art.GILT)
	var hx := r.end.x - r.size.x * 0.14 if edge_left else r.position.x + r.size.x * 0.14
	Art.post(b, Rect2(hx - 1.5 * u, r.position.y + r.size.y * 0.42, 3.0 * u, r.size.y * 0.1), Art.GILT)


func _carriage(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var floor_y := h * 0.94
	var moving := maxf(t - 2.8, 0.0)
	var slide := 22.0 * moving * moving if moving < 2.0 else 88.0 + 88.0 * (moving - 2.0)
	slide *= u
	var dr := Rect2(w * 0.08, h * 0.2, w * 0.25, floor_y - h * 0.2)
	var wr := Rect2(w * 0.46, h * 0.26, w * 0.44, h * 0.4)
	var dado := h * 0.74
	_focus = wr.get_center()
	_push = 0.06
	_pan = Vector2(0, 0)
	_sway = Vector2(0, sin(clock * 1.9) * 0.8 * u * smoothstep(2.8, 4.0, t))
	var cam := _cam(1.0)
	# Through the doorway: the platform at night, a lamp, the conductor.
	var view := UI.Draw.Batch.new()
	var plat := dr.position.y + dr.size.y * 0.8
	_sky(view, Rect2(dr.position.x, dr.position.y, dr.size.x, plat - dr.position.y), [[0.0, Art.SKY[1]], [0.7, Art.SKY[2]], [1.0, Art.SKY[3]]])
	# The station across the tracks: a wall of arches, lit.
	var sw_y := dr.position.y + dr.size.y * 0.42
	var brick := Color(0.2, 0.12, 0.13)
	view.rect(Rect2(dr.position.x, sw_y - dr.size.y * 0.08, dr.size.x, plat - sw_y + dr.size.y * 0.08), brick)
	view.rect(Rect2(dr.position.x, sw_y - dr.size.y * 0.08, dr.size.x, 3.0 * u), brick.lightened(0.2))
	for k in 6:
		var ax := dr.position.x + float(k) * dr.size.x * 0.34 - fposmod(slide * 0.6, dr.size.x * 0.34) - dr.size.x * 0.1
		var aw := dr.size.x * 0.2
		var ab := plat - dr.size.y * 0.04
		var at := sw_y + aw * 0.5
		var arch := PackedVector2Array([Vector2(ax, ab), Vector2(ax, at)])
		for j in 9:
			arch.append(Vector2(ax + aw * 0.5, at) + Vector2.from_angle(PI + PI * j / 8.0) * aw * 0.5)
		arch.append(Vector2(ax + aw, ab))
		view.soft(Vector2(ax + aw * 0.5, (at + ab) * 0.5), Vector2(aw, ab - at), Color(Art.LAMP, 0.25))
		_ink(view, arch, brick.darkened(0.5), 3.0 * u)
		view.polygon(arch, Art.LAMP.darkened(0.3))
		view.rect(Rect2(ax + aw * 0.5 - 1.0 * u, at - aw * 0.5, 2.0 * u, ab - at + aw * 0.5), Color(brick.darkened(0.4), 0.8))
		view.rect(Rect2(ax, at + (ab - at) * 0.35, aw, 2.0 * u), Color(brick.darkened(0.4), 0.8))
	for k in 5:  # courses of brick
		view.rect(Rect2(dr.position.x, sw_y + (plat - sw_y) * 0.18 * k, dr.size.x, 1.0), Color(0, 0, 0, 0.18))
	Art.vgrad(view, Rect2(dr.position.x, plat, dr.size.x, dr.end.y - plat), Color(0.3, 0.26, 0.27), Color(0.12, 0.1, 0.12))
	view.rect(Rect2(dr.position.x, plat, dr.size.x, 3.0 * u), Color(0.9, 0.75, 0.3, 0.8))
	var lamp := Vector2(dr.position.x + dr.size.x * 0.22 - slide, dr.position.y + dr.size.y * 0.24)
	_limb(view, lamp + Vector2(0, 8.0 * u), Vector2(lamp.x, plat), Color(0.1, 0.1, 0.12), 3.0 * u)
	Art.light(view, lamp, Vector2(90.0, 80.0) * u, Color(Art.LAMP, 0.35))
	view.poly(PackedVector2Array([lamp + Vector2(-6.0, -8.0) * u, lamp + Vector2(6.0, -8.0) * u, lamp + Vector2(4.0, 8.0) * u, lamp + Vector2(-4.0, 8.0) * u]), Art.LAMP.lightened(0.2), 1.2, Shade.SLAB)
	view.poly(PackedVector2Array([lamp + Vector2(-8.0, -8.0) * u, lamp + Vector2(0, -14.0) * u, lamp + Vector2(8.0, -8.0) * u]), Color(0.1, 0.1, 0.12), 1.2, Shade.METAL)
	var nod := sin(clampf((t - 0.5) / 0.9, 0.0, 1.0) * PI)
	var smile := smoothstep(0.9, 1.5, t)
	_conductor(view, Vector2(dr.position.x + dr.size.x * 0.58 - slide, plat + dr.size.y * 0.08), dr.size.y * 0.62, nod, smile)
	# The window: night, and the tower growing nearer.
	_window_view(view, wr, slide, smoothstep(2.6, 12.0, t), CITY_TOWER)
	draw_set_transform_matrix(cam)
	view.flush(self)
	layers += 1
	# The carriage round them (kept: it never changes).
	var built := func(b):
		_wall_around(b, Rect2(-40.0 * u, h * 0.1, w + 80.0 * u, floor_y - h * 0.1), [dr, wr], dado)
		_panels(b, -40.0 * u, w + 40.0 * u, dado + 4.0 * u, floor_y, [dr], Art.WALNUT.darkened(0.15), 3)
		_panels(b, dr.end.x + 10.0 * u, wr.position.x - 10.0 * u, h * 0.12, dado - 4.0 * u, [], Art.OAK.darkened(0.3), 11)
		_panels(b, wr.end.x + 10.0 * u, w + 40.0 * u, h * 0.12, dado - 4.0 * u, [], Art.OAK.darkened(0.3), 17)
		Art.bar(b, Rect2(-40.0 * u, dado - 3.0 * u, dr.position.x - 8.0 * u + 40.0 * u, 6.0 * u))
		Art.bar(b, Rect2(dr.end.x + 8.0 * u, dado - 3.0 * u, w + 40.0 * u - dr.end.x - 8.0 * u, 6.0 * u))
		# The ceiling: a curved cornice, gilt ribs.
		Art.vgrad(b, Rect2(-40.0 * u, -40.0 * u, w + 80.0 * u, h * 0.1 + 40.0 * u), Art.WALNUT.darkened(0.6), Art.WALNUT.darkened(0.25))
		for k in 9:
			var rx := lerpf(-20.0 * u, w + 20.0 * u, k / 8.0)
			b.line(Vector2(rx, -40.0 * u), Vector2(rx + (rx - w * 0.5) * 0.04, h * 0.1), Color(Art.GILT, 0.35), 2.0 * u)
		Art.bar(b, Rect2(-40.0 * u, h * 0.1 - 4.0 * u, w + 80.0 * u, 6.0 * u))
		Art.moulding(b, Rect2(-40.0 * u, h * 0.1 + 4.0 * u, w + 80.0 * u, 10.0 * u), u, Art.GILT, 0.4)
		# The floor: a runner with a gilt border.
		Art.vgrad(b, Rect2(-40.0 * u, floor_y, w + 80.0 * u, s.y - floor_y + 40.0 * u), Art.RUNNER, Art.RUNNER.darkened(0.55))
		b.rect(Rect2(-40.0 * u, floor_y, w + 80.0 * u, 3.0 * u), Color(0, 0, 0, 0.6))
		b.rect(Rect2(-40.0 * u, floor_y + 8.0 * u, w + 80.0 * u, 2.0 * u), Color(Art.GILT, 0.35))
		_frame(b, wr, 9.0 * u)
		_frame(b, dr, 8.0 * u)
		_curtains(b, wr, u)
		# The shade of the frames in the room's own light.
		b.soft(Vector2(dr.get_center().x, floor_y), Vector2(dr.size.x * 0.7, 10.0 * u), Color(0, 0, 0, 0.4))
	_baked("room", s, h, 1.0, built)
	draw_set_transform_matrix(cam)
	# The doors sliding shut over the doorway.
	var dl := UI.Draw.Batch.new()
	var shut := _ease((t - 1.3) / 1.4)
	var half := dr.size.x * 0.5
	for side in [0, 1]:
		var pw := half * shut
		if pw < 1.0:
			continue
		var pr := Rect2(dr.position.x if side == 0 else dr.end.x - pw, dr.position.y, pw, dr.size.y)
		dl.rect(Rect2(pr.position.x - 1.0, pr.position.y, pr.size.x + 2.0, pr.size.y), Art.OUTLINE)
		_door_panel(dl, pr, side == 0, lamp.x)
	# The wall lamp between them, the light it throws.
	var flick := 0.92 + 0.08 * sin(clock * 6.3) * sin(clock * 2.9)
	_sconce(dl, Vector2((dr.end.x + wr.position.x) * 0.5, h * 0.36), u, flick)
	dl.flush(self)
	layers += 1
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.55)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


# --- 6. the seat beside you, and the Entity ----------------------------------------------

func _seat(s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var wr := Rect2(w * 0.32, h * 0.07, w * 0.36, h * 0.27)
	var dado := h * 0.42
	var back := Rect2(w * 0.13, h * 0.44, w * 0.74, h * 0.33)
	var seat_y := back.end.y
	var ec := Vector2(w * 0.635, seat_y - h * 0.21)
	var er := minf(h * 0.1, w * 0.07)
	_focus = Vector2(w * 0.55, h * 0.55)
	_push = 0.07
	_pan = Vector2(-6.0 * u, 0)
	var ea := smoothstep(1.2, 3.2, t)
	# The window, the night going by, the tower near now.
	var vb := UI.Draw.Batch.new()
	_window_view(vb, wr, 180.0 * u + clock * 40.0 * u, 0.8, CITY_TOWER)
	_put(vb, 1.0)
	_baked("room", s, h, 1.0, func(b):
		_wall_around(b, Rect2(-40.0 * u, -40.0 * u, w + 80.0 * u, s.y + 80.0 * u), [wr], dado)
		_panels(b, -40.0 * u, wr.position.x - 40.0 * u, h * 0.04, dado - 4.0 * u, [], Art.OAK.darkened(0.3), 23)
		_panels(b, wr.end.x + 40.0 * u, w + 40.0 * u, h * 0.04, dado - 4.0 * u, [], Art.OAK.darkened(0.3), 29)
		Art.bar(b, Rect2(-40.0 * u, dado - 3.0 * u, w + 80.0 * u, 6.0 * u))
		_frame(b, wr, 8.0 * u)
		_curtains(b, wr, u * 0.85)
		# The bench: buttoned velvet in a walnut frame, piped along its edge.
		var fr := Rect2(back.position - Vector2(10, 10) * u, back.size + Vector2(20, 14) * u)
		b.rect(fr.grow(1.5 * u), Art.OUTLINE)
		b.box(fr, Art.WALNUT, Shade.WOOD)
		Art.grain(b, Rect2(fr.position, Vector2(fr.size.x, 10.0 * u)), Art.WALNUT, 41, u, false, false)
		b.box(back, Art.PLUM, Shade.CLOTH)
		var cols := 10
		var rows := 3
		for i in cols + 1:
			for j in rows:
				var bp := back.position + Vector2(back.size.x * (float(i) + (0.5 if j % 2 == 1 else 0.0)) / cols, back.size.y * (0.18 + 0.32 * j))
				if bp.x > back.end.x - 4.0 * u or bp.x < back.position.x + 4.0 * u:
					continue
				# The tufts: a soft pucker round each button, lit from the top-left.
				b.soft(bp + Vector2(2.0, 2.0) * u, Vector2(10.0, 8.0) * u, Color(0, 0, 0, 0.3))
				b.soft(bp + Vector2(-3.0, -3.0) * u, Vector2(9.0, 7.0) * u, Color(1.0, 0.6, 0.7, 0.07))
				b.disc(bp, 2.4 * u, Art.PLUM.darkened(0.35), Shade.BALL)
		for i in cols:  # the pleats between the buttons
			var x := back.position.x + back.size.x * (float(i) + 0.5) / cols
			b.line(Vector2(x, back.position.y + 4.0 * u), Vector2(x, back.position.y + back.size.y * 0.16), Color(0, 0, 0, 0.18), 1.2 * u)
		b.rect(Rect2(back.position.x, back.position.y, back.size.x, 3.0 * u), Color(Art.PLUM.lightened(0.25), 0.6))
		var cushion := Rect2(back.position.x - 4.0 * u, seat_y - 6.0 * u, back.size.x + 8.0 * u, 18.0 * u)
		b.rect(cushion.grow(1.5 * u), Art.OUTLINE)
		b.box(cushion, Art.PLUM.lightened(0.1), Shade.CLOTH)
		b.rect(Rect2(cushion.position.x, cushion.position.y + 1.0 * u, cushion.size.x, 2.0 * u), Color(Art.PLUM.lightened(0.4), 0.5))
		# Armrests either end.
		for sg in [0, 1]:
			var ax: float = fr.position.x - 8.0 * u if sg == 0 else fr.end.x - 14.0 * u
			var arm := Rect2(ax, back.position.y + back.size.y * 0.45, 22.0 * u, back.size.y * 0.6)
			b.rect(arm.grow(1.5 * u), Art.OUTLINE)
			b.box(arm, Art.WALNUT.lightened(0.05), Shade.WOOD)
			b.disc(Vector2(arm.get_center().x, arm.position.y), 11.0 * u, Art.WALNUT.lightened(0.1), Shade.WOOD))
	# Light: the lamp's warmth on the left, the Entity's cool light on the right.
	var lt := UI.Draw.Batch.new()
	var flick := 0.93 + 0.07 * sin(clock * 5.7) * sin(clock * 2.3)
	_sconce(lt, Vector2(w * 0.12, h * 0.2), u, flick)
	_sconce(lt, Vector2(w * 0.88, h * 0.2), u, flick)
	Art.light(lt, ec, Vector2(er * 4.6, er * 3.4), Color(Entity.GLOW, 0.26 * ea))
	lt.soft(Vector2(ec.x, seat_y), Vector2(er * 2.6, er * 0.5), Color(Entity.GLOW, 0.25 * ea))
	_put(lt, 1.0)
	# You, sitting there (your own look: appearance.gd's figure).
	var k := h * 0.32 / 150.0
	var you := Vector2(w * 0.37, seat_y + 4.0 * u)
	var cb := UI.Draw.Batch.new()
	cb.soft(you + Vector2(10.0 * u, -h * 0.02), Vector2(h * 0.12, h * 0.05), Color(0, 0, 0, 0.35))
	_put(cb, 1.0)
	draw_set_transform_matrix(_cam(1.0) * Transform2D(0.0, Vector2(k, k), 0.0, you))
	var fb := UI.Draw.Batch.new()
	Appearance.draw_front(fb, _look())
	fb.flush(self)
	# The table in front: wood grain, a brass edge, a lamp with a glass shade,
	# a cup and a ticket.
	var top := seat_y + 14.0 * u
	_baked("table", s, h, 1.0, func(b):
		var tr := Rect2(w * 0.18, top, w * 0.64, s.y - top + 40.0 * u)
		b.rect(tr.grow(1.5 * u), Art.OUTLINE)
		b.box(tr, Art.WALNUT.lightened(0.02), Shade.WOOD)
		Art.grain(b, Rect2(tr.position + Vector2(0, 8.0 * u), Vector2(tr.size.x, minf(tr.size.y, h * 0.3))), Art.WALNUT.lightened(0.02), 51, u, false, true)
		Art.bar(b, Rect2(tr.position.x - 4.0 * u, top - 3.0 * u, tr.size.x + 8.0 * u, 7.0 * u))
		var tk := Rect2(w * 0.5, top + 14.0 * u, 46.0 * u, 22.0 * u)
		b.polygon(PackedVector2Array([tk.position, Vector2(tk.end.x, tk.position.y + 3.0 * u), tk.end, Vector2(tk.position.x - 2.0 * u, tk.end.y - 2.0 * u)]), Color(0.88, 0.8, 0.62))
		b.rect(Rect2(tk.position + Vector2(5.0, 6.0) * u, Vector2(26.0 * u, 2.0 * u)), Color(0.4, 0.2, 0.15, 0.7))
		b.rect(Rect2(tk.position + Vector2(5.0, 12.0) * u, Vector2(18.0 * u, 2.0 * u)), Color(0.4, 0.2, 0.15, 0.5))
		var cup := Vector2(w * 0.44, top + 6.0 * u)
		b.contact(cup + Vector2(0, 3.0 * u), 10.0 * u, 0.4)
		b.oval(cup + Vector2(0, 2.0 * u), Vector2(13.0, 4.0) * u, 0.0, Color(0.85, 0.83, 0.8), Shade.BALL)
		b.poly(PackedVector2Array([cup + Vector2(-8.0, -12.0) * u, cup + Vector2(8.0, -12.0) * u, cup + Vector2(6.0, 0) * u, cup + Vector2(-6.0, 0) * u]), Color(0.92, 0.9, 0.86), 1.2, Shade.SLAB)
		b.oval(cup + Vector2(0, -12.0 * u), Vector2(8.0, 2.4) * u, 0.0, Color(0.35, 0.2, 0.12), Shade.SLAB)
		b.arc(cup + Vector2(9.0, -7.0) * u, 4.0 * u, -PI * 0.5, PI * 0.5, 8, Color(0.92, 0.9, 0.86), 2.0 * u)
		b.rect(Rect2(cup + Vector2(-8.0, -8.0) * u, Vector2(16.0 * u, 1.5 * u)), Color(Art.GILT, 0.8)))
	var tb := UI.Draw.Batch.new()
	draw_set_transform_matrix(_cam(1.0))
	# The table lamp: a brass foot and stem, a glass shade, its flame and
	# the pool of warm light it lays on the table.
	var lp := Vector2(w * 0.25, top)
	var ls := 1.5 * u
	Art.light(tb, lp + Vector2(0, -24.0 * ls), Vector2(150.0, 110.0) * u, Color(Art.LAMP, 0.3 * flick))
	tb.soft(lp + Vector2(30.0 * u, 18.0 * u), Vector2(110.0, 22.0) * u, Color(Art.LAMP, 0.16 * flick))
	tb.contact(lp + Vector2(0, 2.0 * ls), 12.0 * ls, 0.45)
	tb.poly(PackedVector2Array([lp + Vector2(-10.0, 0) * ls, lp + Vector2(-5.0, -8.0) * ls, lp + Vector2(5.0, -8.0) * ls, lp + Vector2(10.0, 0) * ls]), Art.GILT, 1.2, Shade.METAL)
	tb.stroke(lp + Vector2(0, -8.0 * ls), lp + Vector2(0, -16.0 * ls), Art.GILT_LO.lightened(0.3), 3.0 * ls)
	tb.soft(lp + Vector2(0, -24.0 * ls), Vector2(10.0, 12.0) * ls, Color(Art.LAMP.lightened(0.3), 0.7 * flick))
	tb.poly(PackedVector2Array([lp + Vector2(-6.0, -16.0) * ls, lp + Vector2(-8.0, -28.0) * ls, lp + Vector2(-4.0, -36.0) * ls, lp + Vector2(4.0, -36.0) * ls, lp + Vector2(8.0, -28.0) * ls, lp + Vector2(6.0, -16.0) * ls]), Color(1.0, 0.85, 0.65, 0.3), 1.0, Shade.SLAB)
	tb.oval(lp + Vector2(0, -24.0 * ls), Vector2(2.4, 5.5 * flick) * ls, 0.0, Art.LAMP.lightened(0.45), Shade.SOFT)
	tb.circle(lp + Vector2(0, -23.0 * ls), 1.4 * ls, Color(1, 1, 0.9), 8)
	tb.rect(Rect2(lp + Vector2(-5.0, -37.5) * ls, Vector2(10.0, 2.0) * ls), Art.GILT)
	# The Entity's cool light on the table's brass edge.
	tb.soft(Vector2(ec.x, top), Vector2(er * 2.4, 6.0 * u), Color(Entity.GLOW, 0.3 * ea))
	# Sparks gathering where it will be, spiralling in, before it shows.
	var gather := smoothstep(0.2, 1.4, t) * (1.0 - smoothstep(2.4, 3.6, t))
	if gather > 0.0:
		var n := _count(14)
		for m in n:
			var f := fposmod(clock * 0.45 + Art.rnd(m), 1.0)
			var ang := TAU * float(m) / float(n) + clock * 0.9 + f * 2.5
			var dist := er * (3.2 - 2.6 * f)
			var p := ec + Vector2.from_angle(ang) * dist * Vector2(1.0, 0.8)
			var sc: Color = Entity.SPARK if m % 2 == 0 else Entity.GLOW
			tb.soft(p, Vector2.ONE * (3.0 + 3.0 * f) * u, Color(sc, 0.75 * gather * sin(f * PI)))
			tb.circle(p, 1.2 * u, Color(1, 1, 1, 0.8 * gather * sin(f * PI)), 6)
		tb.soft(ec, Vector2.ONE * er * 1.4 * gather, Color(Entity.GLOW, 0.3 * gather))
	# A ring of light as it arrives.
	var arrive := smoothstep(1.4, 3.0, t)
	if arrive > 0.0 and arrive < 1.0:
		tb.arc(ec, er * (1.0 + 1.6 * arrive), 0.0, TAU, 40, Color(Entity.GLOW, 0.5 * (1.0 - arrive)), 2.0 * u)
	tb.flush(self)
	layers += 1
	if ea > 0.0:
		Entity.draw_face(self, ec, er, clock, ea)
	var vg := UI.Draw.Batch.new()
	_vignette(vg, s, h, 0.55)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	vg.flush(self)


## The climber's look (their own, or the default look before they choose).
func _look() -> Dictionary:
	if main != null and is_instance_valid(main) and "climber_look" in main and main.climber_look is Dictionary and not main.climber_look.is_empty():
		return main.climber_look
	return Appearance.look(Appearance.DEFAULTS)
