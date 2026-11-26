extends Control
## THE OPENING: the Entity's six screens about the world (new_start.gd
## INTRO), each with its own slow scene drawn in code behind the words
## (menu.gd shows it under the "intro" page; start_pages.gd builds the
## words and the buttons over it, at the bottom of the screen).
##
##   1  the world tearing: six essences stream wild out of a cracking world,
##      until six small figures stand round it and hold it together
##      (the Regard's glimpse of the fracture: fracture.gd's world and cracks)
##   2  six towers rising over six glowing wells, a guardian on each (the
##      Bestiary's own drawings, as dark shapes), marks of light drifting
##      down to the people below (the station's towers: station_view.gd)
##   3  the dead land at night, a storm of wild essence far off, and the
##      Turning, lit and running on essence, going round its loop of track
##      between six distant cities
##   4  a city lit by crystals at the foot of a tower, the crystals' light
##      running into it, and marked climbers coming down the road
##   5  inside a carriage: the conductor's nod, the doors closing, the train
##      moving off and a tower growing in the window (the train's woods and
##      lamplight: train_art.gd)
##   6  the seat beside you, and the Entity (entity.gd's face) appearing on it
##
## Light for a phone: one Batch a frame (a few for the shapes that need
## their own frame), redrawn at most OPENING "fps" times a second, a few
## drifting specks scaled by the Effects setting (particles.gd EFFECTS), no
## shaders. Everything is lit from the top-left (the shading toolkit); the
## words stay flat, on a dark band. A click or tap on the picture goes on
## (tapped; the menu's Next does the same for Enter, Space and A).
## The music: the story track's six tolls, one for each screen
## (audio.gd story_toll). Its numbers are here (the Data editor).

signal tapped

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Fracture := preload("res://scripts/fracture.gd")
const StationView := preload("res://scripts/station_view.gd")
const Particles := preload("res://scripts/particles.gd")
const Palette := preload("res://scripts/palette.gd")
const Shade := preload("res://scripts/shade.gd")

## "fade_in": seconds a screen takes to come up out of the dark;
## "tap_after": a tap on the picture goes on only after this long on a
## screen (so one tap never skips two); "fps": the most redraws a second;
## "motes": how many drifting specks a screen shows at Effects Medium (Low
## shows a few, High a little more).
static var OPENING := {"fade_in": 0.8, "tap_after": 0.35, "fps": 30.0, "motes": 18}
## The six essences, in the order the screens use them (one for each tower).
const KINDS := ["air", "water", "iron", "fire", "stone", "blade"]
## The tower the fourth screen's city stands under.
const CITY_TOWER := "firebird"
const SCREENS := 6

var main  # main.gd: the music and the climber's look (may be null in tests)
var line := 0  # the screen showing (0..5)
var t := 0.0  # seconds on this screen (real time: the game is paused under the menu)
var clock := 0.0  # seconds since it was made (for motion that carries on across screens)
var text_top := -1.0  # where the words begin (menu.gd _layout); -1: near the bottom
var draws := 0  # how many times a whole screen has drawn (tests)
var _shown := -1
var _last_us := 0
var _redraw := 0.0
var _u := 1.0  # the size of things, from the screen
var Entity: GDScript
var Story: GDScript
var Bestiary: GDScript
var Appearance: GDScript
var _beasts := {}  # kind -> [solid triangles, bounds]


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
			_shown = -1)
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
	var h := stage_height(s)
	_u = clampf(minf(h / 430.0, s.x / 760.0), 0.45, 1.8)
	var b := UI.Draw.Batch.new()
	match line:
		0:
			_world(b, s, h)
		1:
			_towers(b, s, h)
		2:
			_turning(b, s, h)
		3:
			_city(b, s, h)
		4:
			_carriage(b, s, h)
		_:
			_seat(b, s, h)
	b.flush(self)
	# The words' band: flat and dark, so they read over any scene.
	var top := stage_height(s)
	var band := UI.Draw.Batch.new()
	Art.vgrad(band, Rect2(0, top - 70.0 * _u, s.x, 70.0 * _u + 14.0), Color(Art.SHADOW, 0.0), Color(Art.SHADOW, 0.86))
	band.rect(Rect2(0, top + 14.0, s.x, maxf(s.y - top - 14.0, 0.0)), Color(Art.SHADOW, 0.86))
	band.flush(self)
	# Each screen comes up out of the dark.
	var dark := 1.0 - smoothstep(0.0, float(OPENING["fade_in"]), t)
	if dark > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, dark))
	draws += 1  # (counted once the whole screen has drawn: tests)


# --- shared pieces -------------------------------------------------------------------

## A night sky down to `horizon` in four colours (the last is the ground).
func _sky(b, s: Vector2, horizon: float, cols: Array) -> void:
	Art.vgrad(b, Rect2(0, 0, s.x, horizon * 0.55), cols[0], cols[1])
	Art.vgrad(b, Rect2(0, horizon * 0.55, s.x, horizon * 0.45 + 1.0), cols[1], cols[2])
	b.rect(Rect2(0, horizon, s.x, s.y - horizon), cols[3])


## Still stars in `area`, twinkling a little.
func _stars(b, area: Rect2, n: int, seed: int) -> void:
	for i in n:
		var p := area.position + Vector2(Art.rnd(i * 3 + seed), Art.rnd(i * 7 + seed + 1)) * area.size
		var tw := 0.6 + 0.4 * sin(clock * (0.7 + Art.rnd(i + seed) * 1.3) + float(i))
		var sz := 1.0 + Art.rnd(i * 5 + seed) * 1.2
		b.rect(Rect2(p, Vector2(sz, sz)), Color(Art.STAR, (0.18 + 0.42 * Art.rnd(i * 11 + seed)) * tw))


## A ridge of hills along `y` across `x0..x1`, slid by `off` (parallax).
func _ridge(x0: float, x1: float, y: float, amp: float, seed: int, off := 0.0, bottom := -1.0) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x0, bottom if bottom > 0.0 else y + amp * 3.0)])
	var n := 18
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var k := (x + off) / maxf(amp * 9.0, 1.0)
		pts.append(Vector2(x, y - amp * (0.55 + 0.3 * sin(k * 1.3 + seed) + 0.15 * sin(k * 3.1 + seed * 2.0))))
	pts.append(Vector2(x1, bottom if bottom > 0.0 else y + amp * 3.0))
	return pts


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


## A small robed figure facing us, its arms reaching toward `toward`,
## with a rim of `col` (the first screen's six). No outline, so it can fade.
func _holder(b, feet: Vector2, h: float, col: Color, a: float, toward: Vector2) -> void:
	var robe := PackedVector2Array([feet + Vector2(-h * 0.27, 0), feet + Vector2(-h * 0.15, -h * 0.6), feet + Vector2(0, -h * 0.66),
		feet + Vector2(h * 0.15, -h * 0.6), feet + Vector2(h * 0.27, 0)])
	b.soft(feet, Vector2(h * 0.6, h * 0.5), Color(col, 0.18 * a))
	var cloth := Color(0.17, 0.14, 0.22, a)
	var d := toward.normalized()
	var sh := feet + Vector2(0, -h * 0.56)
	for sg in [-1.0, 1.0]:
		var shoulder: Vector2 = sh + Vector2(sg * h * 0.11, 0)
		var hand: Vector2 = shoulder + (d * 0.9 + Vector2(0, -0.12)).normalized() * h * 0.4 + d.orthogonal() * sg * h * 0.07
		b.bar(shoulder, hand, cloth.lightened(0.05), maxf(2.0, h * 0.08))
		b.soft(hand, Vector2.ONE * h * 0.16, Color(col.lightened(0.3), 0.7 * a))
	b.fill(robe, cloth)
	b.disc(feet + Vector2(0, -h * 0.75), h * 0.13, Color(0.21, 0.18, 0.27, a))
	var edge := PackedVector2Array(robe)
	b.polyline(edge, Color(col.lightened(0.2), 0.55 * a), 1.0)


## A guardian, as a dark shape rimmed in its essence: the Bestiary's own
## drawing of it (bestiary.gd shape), `w` across, centred on `c`.
func _beast(kind: String, c: Vector2, w: float, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	if not _beasts.has(kind):
		var solid: PackedVector2Array = Bestiary.shape(kind).get("solid", PackedVector2Array())
		var bd := Rect2(solid[0], Vector2.ZERO) if not solid.is_empty() else Rect2()
		for p in solid:
			bd = bd.expand(p)
		_beasts[kind] = [solid, bd]
	var solid: PackedVector2Array = _beasts[kind][0]
	var bd: Rect2 = _beasts[kind][1]
	if solid.is_empty() or bd.size.x < 1.0:
		return
	var fit := w / maxf(bd.size.x, bd.size.y)
	var item := get_canvas_item()
	var rim := PackedColorArray()
	rim.resize(solid.size())
	rim.fill(Color(col.lightened(0.25), 0.6 * a))
	var dark := PackedColorArray()
	dark.resize(solid.size())
	dark.fill(Color(0.03, 0.025, 0.05, 0.97 * a))
	var grow := 1.0 + 3.0 / maxf(bd.size.x * fit, 1.0)
	draw_set_transform(c - bd.get_center() * fit * grow, 0.0, Vector2.ONE * fit * grow)
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), solid, rim)
	draw_set_transform(c - bd.get_center() * fit, 0.0, Vector2.ONE * fit)
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), solid, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- 1. the world tearing, and the six who held it -------------------------------------

func _world(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	b.rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.015, 0.035))
	_stars(b, Rect2(0, 0, w, h), 60, 3)
	var r := minf(h * 0.22, w * 0.15)
	var tear := smoothstep(0.4, 2.6, t)
	var figs := smoothstep(3.0, 4.2, t)
	var hold := smoothstep(4.0, 5.8, t)
	var shake := Vector2(sin(clock * 41.0), cos(clock * 37.0)) * 3.0 * u * tear * (1.0 - hold)
	var mid := Vector2(w * 0.5, h * 0.52) + shake
	# The world: a shaded ball with its lands (the Regard's glimpse of it).
	b.soft(mid, Vector2.ONE * r * 1.9, Color(0.35, 0.45, 0.85, 0.16 + 0.1 * hold))
	b.ball(mid, r, Color(0.2, 0.36, 0.52))
	for l in [[-0.42, -0.3, 0.3, 0.17, 0.5], [0.3, -0.45, 0.2, 0.12, -0.3], [0.38, 0.12, 0.26, 0.2, 1.1], [-0.2, 0.42, 0.34, 0.14, -0.2], [-0.55, 0.15, 0.14, 0.1, 0.9]]:
		b.oval(mid + Vector2(l[0], l[1]) * r, Vector2(l[2], l[3]) * r, l[4], Color(0.36, 0.5, 0.3))
	# The cracks, each bleeding an essence, and the essence streaming out wild.
	var glow := lerpf(1.0, 0.35, hold)
	for i in 6:
		var col: Color = Essence.color(KINDS[i])
		var pts: PackedVector2Array = Fracture._part(Fracture._crack(i, r), tear)
		if pts.size() < 2:
			continue
		for k in pts.size():
			pts[k] += mid
		b.polyline(pts, Color(col, 0.28 * glow), 8.0 + 6.0 * tear)
		b.polyline(pts, Color(col.lightened(0.3), 0.85 * glow), 3.0)
		b.polyline(pts, Color(0.03, 0.02, 0.05, 0.9), 1.3)
		var reach := r * 1.7 * tear * (1.0 - 0.8 * hold)
		if reach < 2.0:
			continue
		var ribbon := PackedVector2Array([pts[pts.size() - 1]])
		var at: Vector2 = ribbon[0]
		var ang := -PI / 2.0 + TAU * float(i) / 6.0 + 0.35
		for k in 10:
			ang += sin(clock * 1.7 + float(k) * 0.6 + float(i) * 1.3) * 0.3
			at += Vector2.from_angle(ang) * reach / 10.0
			ribbon.append(at)
		b.polyline(ribbon, Color(col, 0.15), 12.0 * u + 4.0)
		b.polyline(ribbon, Color(col.lightened(0.25), 0.55), 2.4)
		for m in 3:
			var f := fposmod(clock * 0.7 + float(m) * 0.33 + float(i) * 0.11, 1.0)
			b.soft(_along(ribbon, f), Vector2.ONE * (6.0 + 10.0 * f) * u, Color(col, 0.6 * (1.0 - f)))
	# The six who held it: small figures round the world, binding it with light.
	if figs <= 0.0:
		return
	var spots := PackedVector2Array()
	for i in 6:
		spots.append(mid + Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 6.0 + 0.35 + PI / 6.0) * r * 1.62)
	if hold > 0.0:
		var ring := PackedVector2Array(spots)
		ring.append(spots[0])
		b.polyline(ring, Color(Art.GILT, 0.28 * hold), 1.5)
	var fh := r * 0.36
	for i in 6:
		var col: Color = Essence.color(KINDS[i])
		var feet: Vector2 = spots[i] + Vector2(0, fh * 0.45)
		var to_mid: Vector2 = mid - (feet - Vector2(0, fh * 0.56))
		if hold > 0.0:
			var hand: Vector2 = feet + Vector2(0, -fh * 0.56) + to_mid.normalized() * fh * 0.42
			b.line(hand, mid - to_mid.normalized() * r * 0.98, Color(col.lightened(0.2), 0.55 * hold), 2.0)
			b.soft(mid - to_mid.normalized() * r * 0.98, Vector2.ONE * 9.0 * u, Color(col, 0.5 * hold))
		_holder(b, feet, fh, col, figs, to_mid)


# --- 2. six towers over six wells -------------------------------------------------------

func _towers(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.8
	_sky(b, s, horizon, [Art.SKY[0], Art.SKY[1], Art.SKY[2], Art.GROUND])
	_stars(b, Rect2(0, 0, w, horizon * 0.7), 50, 11)
	b.polygon(_ridge(0.0, w, horizon + 2.0, 16.0 * u, 2, clock * 2.0), Art.FAR)
	var n: int = Towers.ORDER.size()
	var tops: Array = []
	var risen_at := 0.0
	for i in n:
		var id: String = Towers.ORDER[i]
		var info: Dictionary = Towers.TOWERS[id]
		var col: Color = Essence.color(String(info.get("essence", "air")))
		var x := w * (0.08 + 0.84 * (float(i) + 0.5) / n)
		var full := h * (0.48 if i % 2 == 0 else 0.4)
		var start := 0.2 + float(i) * 0.28
		var rise := smoothstep(start, start + 1.6, t)
		risen_at = start + 1.6
		var base := Vector2(x, horizon + 2.0)
		# The well at its foot, glowing in its essence.
		var ww := full * 0.3
		var pulse := 0.85 + 0.15 * sin(clock * 1.3 + float(i))
		b.soft(base + Vector2(0, 3), Vector2(ww * 1.7, ww * 0.5), Color(col, 0.45 * pulse))
		b.polygon(UI._oval(base + Vector2(0, 3), Vector2(ww, ww * 0.22)), Color(0.02, 0.02, 0.04))
		b.polygon(UI._oval(base + Vector2(0, 2.5), Vector2(ww * 0.78, ww * 0.15)), Color(col.lightened(0.2), 0.85 * pulse))
		if rise > 0.01:
			StationView._near_tower(b, base, full * rise, id, clock)
		tops.append({"at": Vector2(x, base.y - full * rise - full * 0.2 * 0.9 - 4.0), "col": col, "kind": String(info.get("beast_kind", id)), "w": full * 0.3, "rise": rise})
	var keen := smoothstep(risen_at, risen_at + 1.0, t)  # (the guardians, once every tower stands)
	# The people below, and the marks of light drifting down to them.
	var people := 12
	var ph := h * 0.075
	var feet_y := horizon + (h - horizon) * 0.78
	var feet: Array = []
	for j in people:
		feet.append(Vector2(w * (0.05 + 0.9 * (float(j) + 0.5) / people) + (Art.rnd(j + 30) - 0.5) * 14.0 * u, feet_y + (Art.rnd(j + 40) - 0.5) * 8.0 * u))
	b.flush(self)
	for tp in tops:
		_beast(tp["kind"], tp["at"] - Vector2(0, tp["w"] * 0.35), tp["w"], tp["col"], keen * float(tp["rise"]))
	for j in people:
		Story.climber(self, feet[j], ph, 1.0, Color(0.7, 0.68, 0.8))
	var fx := UI.Draw.Batch.new()
	for j in people:
		var lit := smoothstep(risen_at + 1.6 + float(j % 6) * 0.5, risen_at + 2.2 + float(j % 6) * 0.5, t)
		if lit > 0.0:
			var mc: Color = Essence.color(KINDS[(j * 5 + 1) % 6])
			var mp: Vector2 = feet[j] + Vector2(ph * 0.08, -ph * 0.6)
			fx.soft(mp, Vector2.ONE * ph * 0.55, Color(mc, 0.5 * lit))
			fx.circle(mp, maxf(1.2, ph * 0.08), Color(mc.lightened(0.4), lit), 10)
	if keen > 0.0:
		var motes := _count(int(OPENING["motes"]))
		for m in motes:
			var tp: Dictionary = tops[m % n]
			var to: Vector2 = feet[(m * 5 + 1) % people] + Vector2(0, -ph * 0.6)
			var period := 6.0 + Art.rnd(m + 7) * 3.0
			var f := fposmod(clock + Art.rnd(m) * period, period) / period
			var p: Vector2 = Vector2(tp["at"]).lerp(to, f * f * (3.0 - 2.0 * f)) + Vector2(sin(f * TAU + float(m)) * 18.0 * u, -sin(f * PI) * 26.0 * u)
			var mc: Color = tp["col"]
			fx.soft(p, Vector2.ONE * 7.0 * u, Color(mc, 0.45 * keen * sin(f * PI)))
			fx.circle(p, 1.6 * u, Color(mc.lightened(0.5), 0.9 * keen * sin(f * PI)), 10)
	fx.flush(self)


# --- 3. the dead land and the Turning ----------------------------------------------------

func _turning(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.4
	_sky(b, s, horizon, [Art.SKY[0], Art.SKY[1], Color(0.15, 0.1, 0.2), Color(0.06, 0.05, 0.07)])
	_stars(b, Rect2(0, 0, w, horizon * 0.85), 55, 21)
	var moon := Vector2(w * 0.84, h * 0.12)
	b.soft(moon, Vector2.ONE * 40.0 * u, Color(Art.MOON, 0.18))
	b.disc(moon, 12.0 * u, Art.MOON)
	# A storm of wild essence far off: deadly, and kept away from.
	var sx := w * 0.15
	var flick := 0.55 + 0.45 * sin(clock * 5.3) * sin(clock * 2.1)
	b.soft(Vector2(sx, horizon - 16.0 * u), Vector2(170.0, 64.0) * u, Color(Palette.WILD, 0.3 * flick))
	b.soft(Vector2(sx + 30.0 * u, horizon - 30.0 * u), Vector2(90.0, 40.0) * u, Color(Essence.color("fire"), 0.14 * flick))
	for m in _count(8):
		var ang := clock * (0.6 + 0.1 * float(m)) + float(m) * 1.7
		b.soft(Vector2(sx, horizon - 22.0 * u) + Vector2(cos(ang) * 60.0, sin(ang) * 18.0) * u, Vector2.ONE * 5.0 * u, Color(Essence.color(KINDS[m % 6]), 0.5))
	if fposmod(clock, 2.6) < 0.22:
		var bolt := PackedVector2Array()
		for k in 7:
			bolt.append(Vector2(sx + (Art.rnd(k + int(clock / 2.6) * 7) - 0.5) * 30.0 * u, horizon - 90.0 * u + float(k) * 14.0 * u))
		b.polyline(bolt, Color(Palette.WILD, 0.35), 6.0)
		b.polyline(bolt, Color(Palette.WILD_HOT, 0.9), 2.0)
	b.polygon(_ridge(0.0, w, horizon + 1.0, 14.0 * u, 5, 0.0), Art.FAR)
	# The dead land: dark, cracked, a few bare trees.
	Art.vgrad(b, Rect2(0, horizon, w, s.y - horizon), Color(0.1, 0.08, 0.1), Color(0.03, 0.025, 0.04))
	for i in 9:
		var c0 := Vector2(Art.rnd(i * 13 + 2) * w, horizon + (0.12 + 0.85 * Art.rnd(i * 17 + 5)) * (h - horizon))
		var crack := PackedVector2Array([c0])
		for k in 4:
			crack.append(crack[k] + Vector2((Art.rnd(i * 5 + k) - 0.3) * 30.0 * u, (Art.rnd(i * 3 + k + 9) - 0.5) * 8.0 * u))
		b.polyline(crack, Color(0.0, 0.0, 0.0, 0.5), 1.4)
	for i in 5:
		var tb := Vector2(Art.rnd(i * 29 + 1) * w, horizon + (0.08 + 0.3 * Art.rnd(i * 31 + 3)) * (h - horizon))
		var th := (14.0 + 12.0 * Art.rnd(i + 70)) * u
		b.line(tb, tb + Vector2(0, -th), Color(0.05, 0.04, 0.05), 2.0)
		b.line(tb + Vector2(0, -th * 0.6), tb + Vector2(-th * 0.35, -th * 0.95), Color(0.05, 0.04, 0.05), 1.4)
		b.line(tb + Vector2(0, -th * 0.75), tb + Vector2(th * 0.3, -th * 1.05), Color(0.05, 0.04, 0.05), 1.2)
	# The loop of track.
	var c := Vector2(w * 0.5, h * 0.7)
	var rx := w * 0.38
	var ry := h * 0.2
	for side in [-1.0, 1.0]:
		var rail := PackedVector2Array()
		for k in 73:
			var a := TAU * float(k) / 72.0
			rail.append(c + Vector2(cos(a) * (rx + side * 3.0 * u), sin(a) * (ry + side * 1.6 * u)))
		b.polyline(rail, Color(0.46, 0.4, 0.4, 0.9), 2.0)
	for k in 48:
		var a := TAU * float(k) / 48.0
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		var out := Vector2(cos(a), sin(a) * 0.5).normalized()
		b.line(p - out * 6.0 * u, p + out * 6.0 * u, Color(0.2, 0.15, 0.12, 0.85), 2.2)
	# The six cities on the loop (the far ones first), and the train.
	var cities: Array = []
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.5
		var depth := lerpf(0.55, 1.0, (sin(a) + 1.0) * 0.5) * 1.7
		cities.append({"a": a, "p": c + Vector2(cos(a) * rx * 1.1, sin(a) * ry * 1.3), "k": depth, "i": i})
	for cy in cities:
		if sin(float(cy["a"])) < 0.0:
			_town(b, cy["p"], float(cy["k"]), int(cy["i"]))
	_train(b, c, rx, ry)
	for cy in cities:
		if sin(float(cy["a"])) >= 0.0:
			_town(b, cy["p"], float(cy["k"]), int(cy["i"]))


## A distant city: lit houses round the foot of its tower, a glow over it.
func _town(b, p: Vector2, k: float, i: int) -> void:
	var u := _u * k
	var col: Color = Essence.color(String(Towers.TOWERS[Towers.ORDER[i]].get("essence", "air")))
	b.soft(p + Vector2(0, -10.0 * u), Vector2(46.0, 20.0) * u, Color(Art.LAMP, 0.16))
	var spire := PackedVector2Array([p + Vector2(-4.0 * u, 0), p + Vector2(-2.5 * u, -40.0 * u), p + Vector2(0, -47.0 * u), p + Vector2(2.5 * u, -40.0 * u), p + Vector2(4.0 * u, 0)])
	b.polygon(spire, Art.FAR.lerp(Color(0.08, 0.07, 0.1), 0.4))
	b.soft(p + Vector2(0, -44.0 * u), Vector2.ONE * 7.0 * u, Color(col, 0.7))
	for j in 6:
		var hx := p.x + (float(j) - 2.5) * 7.0 * u
		var hh := (6.0 + 8.0 * Art.rnd(i * 11 + j)) * u
		b.rect(Rect2(hx - 3.2 * u, p.y - hh, 6.4 * u, hh), Color(0.07, 0.06, 0.09))
		if Art.rnd(i * 7 + j + 3) > 0.35:
			b.rect(Rect2(hx - 1.0 * u, p.y - hh * 0.65, 2.0 * u, 2.0 * u), Art.LAMP if j % 3 != 1 else col.lightened(0.3))


## The Turning: an engine and its cars going round the loop, lit, running on
## essence (a cool glow under it and a trail of motes behind).
func _train(b, c: Vector2, rx: float, ry: float) -> void:
	var u := _u
	var a := fposmod(t * 0.16 + 0.2, TAU)  # (it comes round the near side as the screen opens)
	var cars := 6
	var spots: Array = []
	for k in cars:
		var depth := lerpf(0.6, 1.0, (sin(a) + 1.0) * 0.5)
		var len := 52.0 * u * depth
		spots.append({"a": a, "k": depth, "len": len})
		var speed := Vector2(-sin(a) * rx, cos(a) * ry).length()
		a -= (len + 4.0 * u * depth) / maxf(speed, 1.0)
	var essence := Color(0.55, 0.88, 1.0)
	# The trail of essence behind the last car.
	var last: Dictionary = spots[cars - 1]
	var trail := _count(10)
	for m in trail:
		var f := fposmod(clock * 0.5 + float(m) / float(trail), 1.0)
		var ta := float(last["a"]) - (0.05 + f * 0.5)
		var tp := c + Vector2(cos(ta) * rx, sin(ta) * ry) + Vector2(0, -4.0 * u)
		b.soft(tp, Vector2.ONE * (3.0 + 4.0 * f) * u, Color(essence, 0.35 * (1.0 - f)))
	for k in range(cars - 1, -1, -1):
		var sp: Dictionary = spots[k]
		var ca := float(sp["a"])
		var p := c + Vector2(cos(ca) * rx, sin(ca) * ry)
		var d := Vector2(-sin(ca) * rx, cos(ca) * ry).normalized()
		var dk := float(sp["k"])
		var half := float(sp["len"]) * 0.5
		var hh := 15.0 * u * dk
		var b0 := p - d * half
		var b1 := p + d * half
		b.soft(p + Vector2(0, 1), Vector2(half * 1.3, 5.0 * u * dk), Color(essence, 0.32))
		# Its body: a box along the track, with some width where it's seen end on.
		var side := Vector2(hh * 0.5 * (1.0 - absf(d.x)), 0)
		var up := Vector2(0, -hh)
		var body := Geometry2D.convex_hull(PackedVector2Array([b0 - side, b0 + side, b1 - side, b1 + side, b0 - side + up, b0 + side + up, b1 - side + up, b1 + side + up]))
		b.fill(body, Color(0.27, 0.16, 0.1) if k > 0 else Color(0.12, 0.16, 0.18))
		b.line(b0 + up, b1 + up, Color(0.06, 0.05, 0.07), 2.0 * dk)
		b.line(b0, b1, Color(Art.GILT, 0.5), 1.0)
		if k > 0:
			b.soft(p + Vector2(0, -hh * 0.6), Vector2(half * 1.2, hh * 0.9), Color(Art.LAMP, 0.18))
			for wi in 4:
				var wp := b0.lerp(b1, 0.16 + 0.226 * float(wi)) + Vector2(0, -hh * 0.62)
				b.rect(Rect2(wp - Vector2(3.0, 2.4) * u * dk, Vector2(6.0, 4.8) * u * dk), Art.LAMP)
		else:
			var front := b1
			Art.light(b, front + Vector2(0, -hh * 0.4), Vector2(34.0, 18.0) * u * dk, Color(Art.LAMP, 0.45))
			b.circle(front + Vector2(0, -hh * 0.4), 2.2 * u * dk, Art.GILT_HI, 10)
			b.line(p + Vector2(0, -hh), p + Vector2(0, -hh - 5.0 * u * dk), Color(0.08, 0.08, 0.1), 3.0 * dk)
			b.soft(p + Vector2(0, -hh - 9.0 * u * dk), Vector2.ONE * 6.0 * u * dk, Color(essence, 0.4))


# --- 4. a city lit by crystals ----------------------------------------------------------

func _city(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var horizon := h * 0.72
	_sky(b, s, horizon, [Art.SKY[0], Art.SKY[1], Art.SKY[2], Color(0.06, 0.045, 0.06)])
	_stars(b, Rect2(0, 0, w, horizon * 0.5), 30, 41)
	Art.vgrad(b, Rect2(0, horizon * 0.45, w, horizon * 0.55 + 1.0), Color(Art.LAMP, 0.0), Color(Art.LAMP, 0.16))
	var base := Vector2(w * 0.74, horizon + 4.0)
	var th := h * 0.55
	b.polygon(_ridge(0.0, w, horizon + 2.0, 12.0 * u, 8, 0.0), Art.FAR)
	StationView._near_tower(b, base, th, CITY_TOWER, clock)
	# Its gate, lit.
	var gw := th * 0.2 * 0.5
	b.rect(Rect2(base.x - gw * 0.5, base.y - gw * 1.1, gw, gw * 1.1), Color(Art.LAMP, 0.85))
	Art.light(b, base + Vector2(0, -gw * 0.5), Vector2(60.0, 40.0) * u, Color(Art.LAMP, 0.25))
	# The road down from the gate into the city.
	var road := PackedVector2Array([base, Vector2(w * 0.6, h * 0.84), Vector2(w * 0.36, h * 0.91), Vector2(w * 0.04, h * 0.98)])
	b.polyline(road, Color(0.15, 0.11, 0.1), 12.0 * u)
	b.polyline(road, Color(0.24, 0.18, 0.14), 6.0 * u)
	# The crystals' light running from the tower into the city.
	var flows := _count(8)
	for m in flows:
		var f := fposmod(clock * 0.09 + float(m) / float(flows), 1.0)
		var p := _along(road, f) + Vector2(0, -7.0 * u)
		var fc: Color = Essence.color(KINDS[m % 6])
		b.soft(p, Vector2.ONE * 6.0 * u, Color(fc, 0.5 * sin(f * PI)))
	# The houses: a far row and a near row, their windows lit.
	for row in 2:
		var y0 := horizon + (6.0 if row == 0 else (h - horizon) * 0.55)
		var x := -10.0 * u
		var i := 0
		while x < w * (0.62 if row == 0 else 0.5):
			var hw := (26.0 + 22.0 * Art.rnd(i * 7 + row * 50)) * u * (0.8 if row == 0 else 1.15)
			var hh := (24.0 + 34.0 * Art.rnd(i * 11 + row * 50)) * u * (0.8 if row == 0 else 1.15)
			var wall := Color(0.08, 0.065, 0.09) if row == 0 else Color(0.11, 0.085, 0.1)
			b.box(Rect2(x, y0 - hh, hw, hh), wall)
			b.polygon(PackedVector2Array([Vector2(x - 2.0 * u, y0 - hh), Vector2(x + hw * 0.5, y0 - hh - hw * 0.4), Vector2(x + hw + 2.0 * u, y0 - hh)]), wall.darkened(0.3))
			for wi in 2:
				for wj in 2:
					if Art.rnd(i * 13 + wi * 3 + wj + row * 70) > 0.3:
						var wc: Color = Art.LAMP if Art.rnd(i + wi + wj * 5 + row) > 0.25 else Essence.color(KINDS[(i + wi) % 6]).lightened(0.3)
						b.rect(Rect2(x + hw * (0.2 + 0.4 * wi), y0 - hh * (0.75 - 0.4 * wj), hw * 0.18, hh * 0.16), wc)
			x += hw + 3.0 * u
			i += 1
	# Crystal lamps along the road, each a crystal of an essence, glowing.
	for k in 5:
		var lp := _along(road, 0.12 + 0.19 * float(k))
		var lc: Color = Essence.color(KINDS[(k + 1) % 6])
		var ph := 22.0 * u * lerpf(0.8, 1.2, float(k) / 4.0)
		b.line(lp + Vector2(10.0 * u, 0), lp + Vector2(10.0 * u, -ph), Color(0.05, 0.04, 0.06), 2.0)
		var cp := lp + Vector2(10.0 * u, -ph - 4.0 * u)
		var pulse := 0.8 + 0.2 * sin(clock * 2.0 + float(k))
		Art.light(b, cp, Vector2(26.0, 26.0) * u, Color(lc, 0.35 * pulse))
		b.fill(PackedVector2Array([cp + Vector2(0, -5.0 * u), cp + Vector2(3.2 * u, 0), cp + Vector2(0, 5.0 * u), cp + Vector2(-3.2 * u, 0)]), lc.lightened(0.2))
	b.flush(self)
	# Marked climbers coming down the road, their marks glowing.
	var fx := UI.Draw.Batch.new()
	for k in 5:
		var f := fposmod(clock * 0.03 + float(k) * 0.2 + 0.05, 1.0)
		var p := _along(road, f)
		var ch := lerpf(14.0, 32.0, f) * u
		var a := smoothstep(0.0, 0.06, f) * (1.0 - smoothstep(0.94, 1.0, f))
		var mc: Color = Essence.color(KINDS[(k * 2 + 3) % 6])
		Story.climber(self, p, ch, a, mc)
		fx.soft(p + Vector2(ch * 0.1, -ch * 0.62), Vector2.ONE * ch * 0.4, Color(mc, 0.55 * a))
		fx.circle(p + Vector2(ch * 0.1, -ch * 0.62), maxf(1.0, ch * 0.07), Color(mc.lightened(0.45), a), 10)
	# A few motes of crystal light rising over the city.
	var motes := _count(int(OPENING["motes"]) / 2)
	for m in motes:
		var f := fposmod(clock * 0.06 + Art.rnd(m + 3), 1.0)
		var p := Vector2(Art.rnd(m * 7 + 1) * w * 0.65, horizon + 20.0 * u - f * horizon * 0.6) + Vector2(sin(clock * 0.8 + float(m)) * 8.0 * u, 0)
		fx.soft(p, Vector2.ONE * 4.0 * u, Color(Essence.color(KINDS[m % 6]), 0.4 * sin(f * PI)))
	fx.flush(self)


# --- 5. inside the carriage: the conductor's nod, the doors, the window ----------------

## Fills `area` with the carriage's wall around the openings in `holes`
## (so what's seen through them is covered at their edges): panelled oak
## above, walnut below `dado`.
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
				Art.vgrad(b, r, Art.WALNUT.darkened(0.25), Art.WALNUT.darkened(0.5))
				if absf(y0 - dado) < 0.5:
					b.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(Art.GILT, 0.4))  # (the dado rail)
			else:
				Art.vgrad(b, r, Art.OAK.darkened(0.45).lerp(Art.OAK.darkened(0.3), (y0 - area.position.y) / maxf(area.size.y, 1.0)), Art.OAK.darkened(0.3))


## The view out of a carriage window `wr`: night, far hills sliding by,
## nearer ones faster, and the tower (`grow` 0..1 how near it is).
func _window_view(b, wr: Rect2, slide: float, grow: float, tower: String) -> void:
	var u := _u
	var horizon := wr.position.y + wr.size.y * 0.78
	Art.vgrad(b, Rect2(wr.position, Vector2(wr.size.x, horizon - wr.position.y)), Art.SKY[0], Art.SKY[2])
	b.rect(Rect2(wr.position.x, horizon, wr.size.x, wr.end.y - horizon), Art.GROUND)
	_stars(b, Rect2(wr.position, Vector2(wr.size.x, wr.size.y * 0.5)), 16, 61)
	b.polygon(_ridge(wr.position.x, wr.end.x, horizon, 10.0 * u, 3, slide * 0.15, wr.end.y), Art.FAR)
	var th := lerpf(wr.size.y * 0.22, wr.size.y * 0.62, grow)
	var tx := wr.position.x + wr.size.x * lerpf(0.72, 0.6, grow)
	StationView._near_tower(b, Vector2(tx, horizon + 2.0), th, tower, clock)
	b.polygon(_ridge(wr.position.x, wr.end.x, horizon + wr.size.y * 0.1, 7.0 * u, 9, slide * 0.6, wr.end.y), Art.NEAR)


## The conductor on the platform: peaked cap, long coat with gilt buttons
## and epaulettes, a lantern in one hand; `nod` 0..1 (the head dips, the
## eyes close).
func _conductor(b, feet: Vector2, ch: float, nod: float) -> void:
	var navy := Color(0.12, 0.14, 0.25)
	var skin := Color(0.86, 0.68, 0.55)
	b.contact(feet, ch * 0.18, 0.4)
	# Legs and boots under the coat.
	for sg in [-1.0, 1.0]:
		b.bar(feet + Vector2(sg * ch * 0.06, -ch * 0.12), feet + Vector2(sg * ch * 0.06, -ch * 0.02), Color(0.06, 0.06, 0.08), ch * 0.06)
	var coat := PackedVector2Array([feet + Vector2(-ch * 0.16, -ch * 0.1), feet + Vector2(-ch * 0.15, -ch * 0.64), feet + Vector2(-ch * 0.06, -ch * 0.7),
		feet + Vector2(ch * 0.06, -ch * 0.7), feet + Vector2(ch * 0.15, -ch * 0.64), feet + Vector2(ch * 0.16, -ch * 0.1)])
	# The far arm hanging, the near one holding the lantern out a little.
	b.stroke(feet + Vector2(ch * 0.14, -ch * 0.62), feet + Vector2(ch * 0.19, -ch * 0.36), navy.darkened(0.1), ch * 0.06)
	b.poly(coat, navy, 1.2, Shade.CLOTH)
	b.rect(Rect2(feet + Vector2(-ch * 0.155, -ch * 0.38), Vector2(ch * 0.31, ch * 0.03)), Color(0.08, 0.06, 0.05))
	b.line(feet + Vector2(0, -ch * 0.69), feet + Vector2(0, -ch * 0.1), Color(0.05, 0.06, 0.12), 1.2)
	for k in 3:
		b.circle(feet + Vector2(ch * 0.025, -ch * (0.6 - 0.09 * k)), maxf(1.2, ch * 0.012), Art.GILT_HI, 10)
	for sg in [-1.0, 1.0]:
		b.bar(feet + Vector2(sg * ch * 0.08, -ch * 0.675), feet + Vector2(sg * ch * 0.16, -ch * 0.655), Art.GILT, maxf(2.0, ch * 0.025))
	var hand := feet + Vector2(-ch * 0.24, -ch * 0.4)
	b.stroke(feet + Vector2(-ch * 0.14, -ch * 0.62), hand, navy.darkened(0.05), ch * 0.06)
	var lamp := hand + Vector2(0, ch * 0.07)
	Art.light(b, lamp, Vector2.ONE * ch * 0.35, Color(Art.LAMP, 0.35))
	b.line(hand, lamp + Vector2(0, -ch * 0.03), Art.OUTLINE, 1.2)
	b.box(Rect2(lamp - Vector2(ch * 0.025, ch * 0.035), Vector2(ch * 0.05, ch * 0.07)), Art.LAMP.lightened(0.2))
	b.disc(hand, ch * 0.022, skin)
	# The head, dipping in the nod.
	var head := feet + Vector2(ch * 0.015 * nod, -ch * 0.79 + ch * 0.045 * nod)
	b.bar(feet + Vector2(0, -ch * 0.7), head + Vector2(0, ch * 0.05), skin.darkened(0.15), ch * 0.05)
	b.ball(head, ch * 0.075, skin)
	for sg in [-1.0, 1.0]:
		var e: Vector2 = head + Vector2(sg * ch * 0.027, ch * 0.0)
		if nod > 0.45:
			b.line(e - Vector2(ch * 0.01, 0), e + Vector2(ch * 0.01, 0), Art.OUTLINE, 1.2)
		else:
			b.circle(e, maxf(1.0, ch * 0.008), Art.OUTLINE, 8)
	b.line(head + Vector2(-ch * 0.03, ch * 0.03), head + Vector2(ch * 0.03, ch * 0.03), Color(0.3, 0.22, 0.18), maxf(1.5, ch * 0.012))  # (a moustache)
	var cap := Rect2(head + Vector2(-ch * 0.08, -ch * 0.125), Vector2(ch * 0.16, ch * 0.06))
	b.box(cap, navy.darkened(0.1))
	b.rect(Rect2(cap.position + Vector2(0, cap.size.y * 0.6), Vector2(cap.size.x, cap.size.y * 0.25)), Art.GILT)
	b.bar(head + Vector2(-ch * 0.085, -ch * 0.06), head + Vector2(ch * 0.1, -ch * 0.06), Color(0.05, 0.05, 0.08), maxf(2.0, ch * 0.02))


func _carriage(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var floor_y := h * 0.92
	var moving := maxf(t - 2.8, 0.0)
	var slide := 22.0 * moving * moving if moving < 2.0 else 88.0 + 88.0 * (moving - 2.0)
	slide *= u
	# Through the doorway: the platform at night, a lamp, the conductor.
	var dr := Rect2(w * 0.07, h * 0.17, w * 0.27, floor_y - h * 0.17)
	var plat := dr.position.y + dr.size.y * 0.8
	Art.vgrad(b, Rect2(dr.position, Vector2(dr.size.x, plat - dr.position.y)), Art.SKY[1], Art.SKY[3])
	Art.vgrad(b, Rect2(dr.position.x, plat, dr.size.x, dr.end.y - plat), Art.OAK.darkened(0.5), Art.WALNUT.darkened(0.6))
	b.rect(Rect2(dr.position.x, plat, dr.size.x, 2.0), Color(0.86, 0.72, 0.3, 0.7))
	var lamp := Vector2(dr.position.x + dr.size.x * 0.22 - slide, dr.position.y + dr.size.y * 0.25)
	b.line(lamp, Vector2(lamp.x, plat), Art.OUTLINE, 3.0)
	Art.light(b, lamp, Vector2(70.0, 60.0) * u, Color(Art.LAMP, 0.3))
	b.circle(lamp, 4.0 * u, Art.LAMP.lightened(0.2), 12)
	var nod := sin(clampf((t - 0.5) / 0.8, 0.0, 1.0) * PI)
	_conductor(b, Vector2(dr.position.x + dr.size.x * 0.6 - slide, plat + dr.size.y * 0.06), dr.size.y * 0.6, nod)
	# The window: night, and the tower growing nearer.
	var wr := Rect2(w * 0.43, h * 0.15, w * 0.5, h * 0.47)
	_window_view(b, wr, slide, smoothstep(2.6, 11.0, t), CITY_TOWER)
	# The carriage around them.
	var dado := h * 0.68
	_wall_around(b, Rect2(0, h * 0.07, w, floor_y - h * 0.07), [dr, wr], dado)
	Art.vgrad(b, Rect2(0, 0, w, h * 0.07), Art.WALNUT.darkened(0.55), Art.WALNUT.darkened(0.3))
	b.rect(Rect2(0, h * 0.07 - 2.0, w, 2.0), Color(Art.GILT, 0.55))
	Art.vgrad(b, Rect2(0, floor_y, w, s.y - floor_y), Art.RUNNER, Art.RUNNER.darkened(0.5))
	b.rect(Rect2(0, floor_y, w, 2.0), Color(0, 0, 0, 0.5))
	# The doors sliding shut over the doorway, a small window in each.
	var shut := smoothstep(1.3, 2.7, t)
	var half := dr.size.x * 0.5
	for side in [0, 1]:
		var pw := half * shut
		if pw < 1.0:
			continue
		var pr := Rect2(dr.position.x if side == 0 else dr.end.x - pw, dr.position.y, pw, dr.size.y)
		b.box(pr, Art.WALNUT.lightened(0.05))
		b.rect(Rect2(pr.end.x - 2.0 if side == 0 else pr.position.x, pr.position.y, 2.0, pr.size.y), Color(Art.GILT, 0.6))
		var pane := Rect2(pr.position.x + pr.size.x * 0.2, pr.position.y + pr.size.y * 0.12, pr.size.x * 0.6, pr.size.y * 0.3)
		if pane.size.x > 4.0:
			Art.vgrad(b, pane, Art.SKY[1], Art.SKY[2])
			if lamp.x > pane.position.x and lamp.x < pane.end.x:
				b.soft(Vector2(lamp.x, pane.get_center().y), Vector2.ONE * 9.0 * u, Color(Art.LAMP, 0.6))
			Art.bevel(b, Rect2(pane.position - Vector2(3, 3), Vector2(pane.size.x + 6, 3)), Art.GILT_LO, 1.0)
	# Frames, curtains, and the carriage's own lamp.
	for fr in [dr, wr]:
		Art.bevel(b, Rect2(fr.position - Vector2(6, 6), Vector2(fr.size.x + 12, 6)), Art.GILT_LO.lightened(0.15), 2.0)
		Art.bevel(b, Rect2(fr.position + Vector2(-6, fr.size.y), Vector2(fr.size.x + 12, 6)), Art.GILT_LO, 2.0)
		Art.bevel(b, Rect2(fr.position - Vector2(6, 0), Vector2(6, fr.size.y)), Art.GILT_LO.lightened(0.08), 2.0)
		Art.bevel(b, Rect2(fr.end.x, fr.position.y, 6, fr.size.y), Art.GILT_LO, 2.0)
	for sg in [0.0, 1.0]:
		var cx: float = wr.position.x + wr.size.x * float(sg)
		var cw := 26.0 * u
		var cur := PackedVector2Array([Vector2(cx - cw, wr.position.y - 8.0), Vector2(cx + cw, wr.position.y - 8.0), Vector2(cx + cw * 0.5, wr.end.y + 10.0), Vector2(cx - cw * 0.5, wr.end.y + 10.0)])
		b.fill(cur, Art.CURTAIN, Shade.CLOTH)
		b.line(Vector2(cx - cw * 0.3, wr.position.y - 4.0), Vector2(cx - cw * 0.15, wr.end.y + 8.0), Color(0, 0, 0, 0.25), 2.0)
	var sconce := Vector2((dr.end.x + wr.position.x) * 0.5, h * 0.32)
	var flick := 0.9 + 0.1 * sin(clock * 7.0)
	Art.light(b, sconce, Vector2(110.0, 90.0) * u, Color(Art.LAMP, 0.18 * flick))
	b.rect(Rect2(sconce + Vector2(-5.0, -9.0) * u, Vector2(10.0, 14.0) * u), Art.LAMP.lightened(0.2))
	b.rect(Rect2(sconce + Vector2(-7.0, 5.0) * u, Vector2(14.0, 3.0) * u), Art.GILT)


# --- 6. the seat beside you, and the Entity ----------------------------------------------

func _seat(b, s: Vector2, h: float) -> void:
	var w := s.x
	var u := _u
	var floor_y := h * 0.98
	var wr := Rect2(w * 0.3, h * 0.08, w * 0.4, h * 0.3)
	_window_view(b, wr, 180.0 * u + clock * 40.0 * u, 1.0, CITY_TOWER)
	var dado := h * 0.44
	_wall_around(b, Rect2(0, 0, w, floor_y), [wr], dado)
	Art.vgrad(b, Rect2(0, floor_y, w, maxf(s.y - floor_y, 0.0)), Art.RUNNER, Art.RUNNER.darkened(0.5))
	Art.bevel(b, Rect2(wr.position - Vector2(6, 6), Vector2(wr.size.x + 12, 6)), Art.GILT_LO.lightened(0.15), 2.0)
	Art.bevel(b, Rect2(wr.position + Vector2(-6, wr.size.y), Vector2(wr.size.x + 12, 6)), Art.GILT_LO, 2.0)
	Art.bevel(b, Rect2(wr.position - Vector2(6, 0), Vector2(6, wr.size.y)), Art.GILT_LO.lightened(0.08), 2.0)
	Art.bevel(b, Rect2(wr.end.x, wr.position.y, 6, wr.size.y), Art.GILT_LO, 2.0)
	# The bench: buttoned velvet in a walnut frame.
	var back := Rect2(w * 0.12, h * 0.47, w * 0.76, h * 0.31)
	b.box(Rect2(back.position - Vector2(8, 8) * u, back.size + Vector2(16, 12) * u), Art.WALNUT, Shade.WOOD)
	b.box(back, Art.PLUM, Shade.CLOTH)
	for i in 9:
		for j in 2:
			var bp := back.position + Vector2(back.size.x * (float(i) + 0.5 + 0.5 * float(j % 2)) / 9.5, back.size.y * (0.3 + 0.4 * float(j)))
			b.circle(bp, 2.2 * u, Art.PLUM.darkened(0.45), 10)
	var seat_y := back.end.y
	b.box(Rect2(back.position.x, seat_y - 4.0 * u, back.size.x, 14.0 * u), Art.PLUM.lightened(0.08), Shade.CLOTH)
	# The Entity's light, gathering on the empty half of the bench.
	var ec := Vector2(w * 0.63, seat_y - h * 0.2)
	var er := minf(h * 0.1, w * 0.07)
	var ea := smoothstep(1.2, 3.2, t)
	Art.light(b, ec, Vector2(er * 4.0, er * 3.0), Color(Entity.GLOW, 0.22 * ea))
	b.flush(self)
	# You, sitting there (your own look: appearance.gd's figure).
	var k := h * 0.32 / 150.0
	draw_set_transform(Vector2(w * 0.37, seat_y + 4.0 * u), 0.0, Vector2(k, k))
	var fb := UI.Draw.Batch.new()
	Appearance.draw_front(fb, _look())
	fb.flush(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The table in front, a lamp on it.
	var tb := UI.Draw.Batch.new()
	var top := seat_y + 14.0 * u
	tb.box(Rect2(w * 0.18, top, w * 0.64, s.y - top), Art.WALNUT.darkened(0.15), Shade.WOOD)
	tb.rect(Rect2(w * 0.18, top, w * 0.64, 3.0), Color(Art.GILT, 0.6))
	var lp := Vector2(w * 0.24, top)
	Art.light(tb, lp + Vector2(0, -14.0 * u), Vector2(70.0, 50.0) * u, Color(Art.LAMP, 0.22))
	tb.fill(PackedVector2Array([lp + Vector2(-7.0, 0) * u, lp + Vector2(-4.0, -18.0) * u, lp + Vector2(4.0, -18.0) * u, lp + Vector2(7.0, 0) * u]), Art.GILT_LO.lightened(0.2))
	tb.rect(Rect2(lp + Vector2(-3.0, -16.0) * u, Vector2(6.0, 10.0) * u), Art.LAMP.lightened(0.25))
	# Sparks gathering where it will be, before it shows.
	var gather := smoothstep(0.2, 1.4, t) * (1.0 - smoothstep(2.4, 3.6, t))
	if gather > 0.0:
		var n := _count(12)
		for m in n:
			var ang := TAU * float(m) / float(n) + clock * 0.8
			var dist := er * (3.0 - 2.0 * fposmod(clock * 0.5 + Art.rnd(m), 1.0))
			tb.soft(ec + Vector2.from_angle(ang) * dist, Vector2.ONE * 4.0 * u, Color(Entity.SPARK if m % 2 == 0 else Entity.GLOW, 0.7 * gather))
	tb.flush(self)
	if ea > 0.0:
		Entity.draw_face(self, ec, er, clock, ea)


## The climber's look (their own, or the default look before they choose).
func _look() -> Dictionary:
	if main != null and is_instance_valid(main) and "climber_look" in main and main.climber_look is Dictionary and not main.climber_look.is_empty():
		return main.climber_look
	return Appearance.look(Appearance.DEFAULTS)
