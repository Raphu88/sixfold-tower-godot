extends Control
## The train's backdrop, drawn in code, behind its pages (menu.gd "train"):
## a dusk sky with the six towers on the horizon, a steam engine and its
## cars standing at a platform (oxblood and bottle green, brass trim and
## rivets, warm lit windows), and smoke rising from the stack.
##
## Two layers so phones stay light: the still scene (redrawn only when the
## screen changes size) and the moving parts in front (smoke, steam and the
## platform lamps' glow). Colours are in ui.gd (TRAIN_*).

const UI := preload("res://scripts/ui.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")

const PUFF_EVERY := 0.32  # seconds between puffs of smoke
const PUFF_LIFE := 4.2
const STEAM_EVERY := 0.9
const CAR_H := 150.0  # the cars' height (at 720 tall)
const ENGINE_W := 300.0
const CAR_W := 360.0

var t := 0.0
var puffs: Array = []  # {p, v, age, r}
var steam: Array = []  # {p, v, age}
var puff_t := 0.0
var steam_t := 0.0
var rng := RandomNumberGenerator.new()
var scene_layer: Layer
var front_layer: Layer
# Geometry for the current screen size (built in _build).
var built_for := Vector2.ZERO
var u := 1.0  # scale: 1 at 720 tall
var horizon := 0.0
var rail := 0.0
var stack_top := Vector2.ZERO
var lamps: Array = []  # lantern positions
var wheel_puffs: Array = []  # where steam leaks near the engine's wheels


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
	rng.seed = 11
	scene_layer = Layer.new(_draw_scene)
	front_layer = Layer.new(_draw_front)
	add_child(scene_layer)
	add_child(front_layer)
	resized.connect(scene_layer.queue_redraw)
	# Start with the smoke already rising.
	_build(_size())
	for i in int(PUFF_LIFE / PUFF_EVERY):
		_step(PUFF_EVERY)


func _size() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_step(delta)
	front_layer.queue_redraw()


func _step(delta: float) -> void:
	t += delta
	puff_t -= delta
	if puff_t <= 0.0:
		puff_t = PUFF_EVERY * rng.randf_range(0.7, 1.3)
		puffs.append({"p": stack_top, "v": Vector2(rng.randf_range(14.0, 30.0), -rng.randf_range(34.0, 48.0)) * u, "age": 0.0, "r": rng.randf_range(0.8, 1.2)})
	steam_t -= delta
	if steam_t <= 0.0 and not wheel_puffs.is_empty():
		steam_t = STEAM_EVERY * rng.randf_range(0.6, 1.4)
		steam.append({"p": wheel_puffs[rng.randi() % wheel_puffs.size()], "v": Vector2(rng.randf_range(-12.0, 12.0), -rng.randf_range(6.0, 14.0)) * u, "age": 0.0})
	for p in puffs:
		p["age"] += delta
		p["v"].x += 6.0 * u * delta  # the wind carries it off
		p["p"] += p["v"] * delta
	for s in steam:
		s["age"] += delta
		s["p"] += s["v"] * delta
	puffs = puffs.filter(func(p): return p["age"] < PUFF_LIFE)
	steam = steam.filter(func(s): return s["age"] < 1.6)


func _build(s: Vector2) -> void:
	built_for = s
	u = maxf(0.45, s.y / 720.0)
	horizon = s.y * 0.5
	rail = s.y * 0.86
	lamps = [Vector2(s.x * 0.17, rail - 150.0 * u), Vector2(s.x * 0.83, rail - 150.0 * u)]
	# Where the engine's stack and wheels are (as _engine draws them), for the smoke.
	var x := s.x * 0.02
	var w := ENGINE_W * u
	var top := rail - 34.0 * u - CAR_H * u
	var boiler_x := x + 22.0 * u
	var boiler_w := w * 0.64 - 22.0 * u
	stack_top = Vector2(boiler_x + boiler_w * 0.2, top + CAR_H * u * 0.3 - 60.0 * u)
	wheel_puffs = [Vector2(x + w * 0.2, rail - 12.0 * u), Vector2(x + w * 0.48, rail - 10.0 * u)]


# --- the still scene ---------------------------------------------------------------

func _draw_scene(ci: Control) -> void:
	var s := _size()
	if s != built_for:
		_build(s)
	var b := UI.Draw.Batch.new()
	# Sky: dusk, deep violet above, a warm band low down.
	var bands := 28
	for i in bands:
		var k := float(i) / bands
		var col: Color = UI.TRAIN_SKY[0].lerp(UI.TRAIN_SKY[1], k / 0.6) if k < 0.6 else UI.TRAIN_SKY[1].lerp(UI.TRAIN_SKY[2], (k - 0.6) / 0.4)
		b.rect(Rect2(0, horizon * k, s.x, horizon / bands + 1.0), col)
	# The six towers on the horizon, each with a lit window in its essence's colour.
	for i in Towers.ORDER.size():
		var id: String = Towers.ORDER[i]
		var x := s.x * (0.07 + 0.172 * i) + (rng_off(i) * 30.0 - 15.0) * u
		var h := (130.0 + 90.0 * rng_off(i + 7)) * u
		var w := (14.0 + 6.0 * rng_off(i + 3)) * u
		var dark := Color(0.09, 0.06, 0.12)
		b.polygon(PackedVector2Array([Vector2(x - w, horizon + 2), Vector2(x - w * 0.62, horizon - h), Vector2(x, horizon - h - 16.0 * u),
			Vector2(x + w * 0.62, horizon - h), Vector2(x + w, horizon + 2)]), dark)
		b.rect(Rect2(x - 2.0 * u, horizon - h * 0.55, 4.0 * u, 6.0 * u), Color(Essence.color(Towers.TOWERS[id]["essence"]), 0.85))
	# Ground: the far field, then the platform.
	b.rect(Rect2(0, horizon, s.x, s.y - horizon), UI.TRAIN_GROUND.lightened(0.04))
	b.rect(Rect2(0, horizon, s.x, 3.0 * u), Color(UI.TRAIN_SKY[2], 0.35))
	# The rails and sleepers.
	for i in int(s.x / (26.0 * u)) + 1:
		b.rect(Rect2(i * 26.0 * u, rail - 3.0 * u, 14.0 * u, 7.0 * u), Color(0.2, 0.15, 0.12))
	b.rect(Rect2(0, rail - 4.0 * u, s.x, 2.5 * u), Color(0.5, 0.5, 0.55))
	# The train: the engine on the left, then its cars.
	var car_h := CAR_H * u
	var top := rail - 34.0 * u - car_h
	var x := s.x * 0.02
	var engine_w := ENGINE_W * u
	_engine(b, x, top, engine_w, car_h)
	x += engine_w + 16.0 * u
	var car_w := CAR_W * u
	while x < s.x + 10.0:
		_coupling(b, x - 16.0 * u, rail - 46.0 * u)
		_car(b, x, top, car_w, car_h)
		x += car_w + 16.0 * u
	# The platform in front: boards, an edge and two lamp posts.
	var py := rail + 8.0 * u
	b.rect(Rect2(0, py, s.x, s.y - py), Color(0.17, 0.12, 0.09))
	b.rect(Rect2(0, py, s.x, 4.0 * u), UI.TRAIN_BRASS.darkened(0.45))
	var plank := 22.0 * u
	var row := 0
	var y := py + 6.0 * u
	while y < s.y:
		b.rect(Rect2(0, y, s.x, 1.5 * u), Color(0.08, 0.06, 0.05))
		var off := (row % 2) * 60.0 * u
		var xx := -off
		while xx < s.x:
			b.rect(Rect2(xx, y, 1.5 * u, plank), Color(0.08, 0.06, 0.05))
			xx += 120.0 * u
		y += plank
		row += 1
	for l in lamps:
		_lamp_post(b, l, s.y)
	b.flush(ci)


## A steady pseudo-random 0..1 for a number (the towers' sizes).
static func rng_off(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


func _rivets(b, from: Vector2, to: Vector2, gap: float) -> void:
	var n := int(from.distance_to(to) / gap)
	for i in n + 1:
		var p := from.lerp(to, float(i) / maxf(n, 1))
		b.dot(p, 1.6 * u, UI.TRAIN_BRASS.darkened(0.35))
		b.dot(p + Vector2(-0.4, -0.4) * u, 1.0 * u, UI.TRAIN_BRASS.lightened(0.25))


func _wheel(b, c: Vector2, r: float, spokes := 8) -> void:
	b.dot(c, r + 1.5 * u, UI.OUTLINE)
	b.dot(c, r, UI.TRAIN_IRON.lightened(0.12))
	b.arc(c, r * 0.82, 0.0, TAU, 20, UI.TRAIN_IRON.lightened(0.28), maxf(1.0, r * 0.12))
	for i in spokes:
		var a := TAU * i / spokes
		b.line(c, c + Vector2.from_angle(a) * r * 0.8, UI.TRAIN_IRON.lightened(0.3), maxf(1.0, r * 0.08))
	b.dot(c, r * 0.22, UI.TRAIN_BRASS)


func _engine(b, x: float, top: float, w: float, h: float) -> void:
	var bottom := top + h
	var frame_y := bottom - 8.0 * u
	# Frame and the cow-catcher at the front.
	b.rect(Rect2(x + 10.0 * u, frame_y, w - 10.0 * u, 12.0 * u), UI.TRAIN_IRON)
	b.polygon(PackedVector2Array([Vector2(x - 8.0 * u, rail - 4.0 * u), Vector2(x + 18.0 * u, frame_y), Vector2(x + 18.0 * u, rail - 4.0 * u)]), UI.TRAIN_IRON.lightened(0.1))
	# The cab, at the back, with a lit window and an overhanging roof.
	var cab := Rect2(x + w * 0.64, top - 6.0 * u, w * 0.36, h - 2.0 * u)
	b.rect(cab.grow(1.5 * u), UI.OUTLINE)
	b.rect(cab, UI.TRAIN_ENGINE)
	b.rect(Rect2(cab.position + Vector2(cab.size.x * 0.22, cab.size.y * 0.16), Vector2(cab.size.x * 0.56, cab.size.y * 0.3)), UI.TRAIN_WINDOW.darkened(0.15))
	b.rect(Rect2(cab.position + Vector2(-6.0 * u, -10.0 * u), Vector2(cab.size.x + 12.0 * u, 12.0 * u)), UI.TRAIN_ROOF)
	b.rect(Rect2(cab.position + Vector2(-6.0 * u, 0.0), Vector2(cab.size.x + 12.0 * u, 2.0 * u)), UI.TRAIN_BRASS)
	_rivets(b, cab.position + Vector2(6, cab.size.y * 0.62), cab.position + Vector2(cab.size.x - 6.0, cab.size.y * 0.62), 12.0 * u)
	# The boiler: a long green drum with brass bands, a dark smokebox at the front.
	var boiler := Rect2(x + 22.0 * u, top + h * 0.3, w * 0.64 - 22.0 * u, h * 0.5)
	b.rect(boiler.grow(1.5 * u), UI.OUTLINE)
	b.rect(boiler, UI.TRAIN_ENGINE.lightened(0.08))
	b.rect(Rect2(boiler.position, Vector2(boiler.size.x, boiler.size.y * 0.28)), UI.TRAIN_ENGINE.lightened(0.22))
	for k in [0.3, 0.55, 0.8]:
		b.rect(Rect2(boiler.position + Vector2(boiler.size.x * k, 0), Vector2(5.0 * u, boiler.size.y)), UI.TRAIN_BRASS)
	var front := Vector2(boiler.position.x, boiler.get_center().y)
	b.dot(front, boiler.size.y * 0.52, UI.OUTLINE)
	b.dot(front, boiler.size.y * 0.48, UI.TRAIN_IRON.lightened(0.15))
	b.dot(front, boiler.size.y * 0.16, UI.TRAIN_BRASS)
	# The headlamp, the brass dome and the stack.
	var lamp := front + Vector2(4.0 * u, -boiler.size.y * 0.62)
	b.dot(lamp, 9.0 * u, UI.OUTLINE)
	b.dot(lamp, 7.5 * u, UI.TRAIN_BRASS)
	b.dot(lamp + Vector2(-2.0 * u, 0), 5.0 * u, UI.TRAIN_WINDOW.lightened(0.3))
	var dome := Vector2(boiler.position.x + boiler.size.x * 0.62, boiler.position.y)
	b.circle(dome, 15.0 * u, UI.OUTLINE)
	b.circle(dome, 13.5 * u, UI.TRAIN_BRASS)
	b.dot(dome + Vector2(-4.0, -5.0) * u, 4.0 * u, UI.TRAIN_BRASS.lightened(0.35))
	var sx := boiler.position.x + boiler.size.x * 0.2
	var stack := PackedVector2Array([Vector2(sx - 9.0 * u, boiler.position.y + 2.0), Vector2(sx - 11.0 * u, boiler.position.y - 34.0 * u),
		Vector2(sx - 20.0 * u, boiler.position.y - 52.0 * u), Vector2(sx + 20.0 * u, boiler.position.y - 52.0 * u),
		Vector2(sx + 11.0 * u, boiler.position.y - 34.0 * u), Vector2(sx + 9.0 * u, boiler.position.y + 2.0)])
	b.poly(stack, UI.TRAIN_IRON.lightened(0.18), 1.5 * u)
	b.rect(Rect2(sx - 21.0 * u, boiler.position.y - 56.0 * u, 42.0 * u, 6.0 * u), UI.TRAIN_COPPER)
	# Pipes along the boiler, copper.
	b.line(Vector2(boiler.position.x + 30.0 * u, boiler.end.y - 6.0 * u), Vector2(boiler.end.x, boiler.end.y - 6.0 * u), UI.TRAIN_COPPER, 3.0 * u)
	# Driving wheels joined by a brass rod, and small leading wheels.
	var r := 30.0 * u
	var wy := rail - 4.0 * u - r
	var centres: Array = []
	for k in [0.36, 0.58, 0.8]:
		centres.append(Vector2(x + w * k, wy))
	_wheel(b, Vector2(x + w * 0.14, rail - 4.0 * u - r * 0.55), r * 0.55, 6)
	for c in centres:
		_wheel(b, c, r)
	var rod_y := wy + r * 0.35
	b.line(Vector2(centres[0].x, rod_y), Vector2(centres[2].x, rod_y), UI.TRAIN_BRASS.darkened(0.1), 4.0 * u)


func _car(b, x: float, top: float, w: float, h: float) -> void:
	var body := Rect2(x, top, w, h - 18.0 * u)
	# The roof: a low curve with a brass edge.
	var roof := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		roof.append(Vector2(x - 6.0 * u + (w + 12.0 * u) * k, top - sin(PI * k) * 18.0 * u))
	roof.append(Vector2(x + w + 6.0 * u, top + 3.0 * u))
	roof.append(Vector2(x - 6.0 * u, top + 3.0 * u))
	b.poly(roof, UI.TRAIN_ROOF, 1.5 * u)
	b.rect(body.grow(1.5 * u), UI.OUTLINE)
	b.rect(body, UI.TRAIN_CAR)
	b.rect(Rect2(body.position + Vector2(0, body.size.y * 0.66), Vector2(w, body.size.y * 0.34)), UI.TRAIN_CAR.darkened(0.25))
	# Brass trim with rivets, top and bottom.
	for yy in [top + 6.0 * u, top + body.size.y * 0.64]:
		b.rect(Rect2(x, yy, w, 4.0 * u), UI.TRAIN_BRASS.darkened(0.1))
		_rivets(b, Vector2(x + 6.0 * u, yy + 9.0 * u), Vector2(x + w - 6.0 * u, yy + 9.0 * u), 14.0 * u)
	# Arched, lit windows; a door at the end.
	var win_w := 34.0 * u
	var win_h := body.size.y * 0.32
	var count := 4
	var gap := (w - 60.0 * u - count * win_w) / (count + 1)
	for i in count:
		var wx := x + 60.0 * u + gap * (i + 1) + win_w * i
		var wr := Rect2(wx, top + body.size.y * 0.2, win_w, win_h)
		b.rect(wr.grow(3.0 * u), UI.TRAIN_BRASS.darkened(0.2))
		b.circle(Vector2(wr.get_center().x, wr.position.y), win_w * 0.5 + 3.0 * u, UI.TRAIN_BRASS.darkened(0.2))
		b.rect(wr, UI.TRAIN_WINDOW.darkened(0.12))
		b.circle(Vector2(wr.get_center().x, wr.position.y), win_w * 0.5, UI.TRAIN_WINDOW.darkened(0.12))
		b.rect(Rect2(wr.position + Vector2(win_w * 0.5 - 1.0 * u, -win_w * 0.5), Vector2(2.0 * u, win_h + win_w * 0.5)), UI.TRAIN_BRASS.darkened(0.3))
		b.rect(Rect2(wr.position + Vector2(3.0 * u, 3.0 * u), Vector2(win_w * 0.3, win_h * 0.5)), Color(1, 1, 1, 0.12))
	var door := Rect2(x + 12.0 * u, top + body.size.y * 0.14, 34.0 * u, body.size.y * 0.82)
	b.rect(door.grow(2.0 * u), UI.TRAIN_BRASS.darkened(0.3))
	b.rect(door, UI.TRAIN_CAR.darkened(0.35))
	b.dot(door.position + Vector2(door.size.x - 7.0 * u, door.size.y * 0.5), 2.5 * u, UI.TRAIN_BRASS)
	# The undercarriage: an iron frame, a copper pipe and two bogies.
	b.rect(Rect2(x + 8.0 * u, body.end.y, w - 16.0 * u, 10.0 * u), UI.TRAIN_IRON)
	b.line(Vector2(x + 14.0 * u, body.end.y + 6.0 * u), Vector2(x + w - 14.0 * u, body.end.y + 6.0 * u), UI.TRAIN_COPPER.darkened(0.2), 2.5 * u)
	var r := 15.0 * u
	for bx in [x + w * 0.16, x + w * 0.84]:
		b.rect(Rect2(bx - 30.0 * u, body.end.y + 8.0 * u, 60.0 * u, 8.0 * u), UI.TRAIN_IRON.lightened(0.05))
		for dx in [-17.0, 17.0]:
			_wheel(b, Vector2(bx + dx * u, rail - 4.0 * u - r), r, 6)


func _coupling(b, x: float, y: float) -> void:
	b.rect(Rect2(x - 6.0 * u, y - 4.0 * u, 28.0 * u, 8.0 * u), UI.TRAIN_IRON.lightened(0.08))
	b.dot(Vector2(x + 8.0 * u, y), 4.0 * u, UI.TRAIN_BRASS.darkened(0.2))


func _lamp_post(b, at: Vector2, bottom: float) -> void:
	b.rect(Rect2(at.x - 3.0 * u, at.y, 6.0 * u, bottom - at.y), UI.TRAIN_IRON.lightened(0.1))
	b.rect(Rect2(at.x - 9.0 * u, at.y - 4.0 * u, 18.0 * u, 5.0 * u), UI.TRAIN_BRASS.darkened(0.2))
	var cage := Rect2(at.x - 8.0 * u, at.y - 26.0 * u, 16.0 * u, 22.0 * u)
	b.rect(cage.grow(1.5 * u), UI.OUTLINE)
	b.rect(cage, UI.TRAIN_WINDOW)
	b.polygon(PackedVector2Array([Vector2(at.x - 11.0 * u, cage.position.y), Vector2(at.x, cage.position.y - 9.0 * u), Vector2(at.x + 11.0 * u, cage.position.y)]), UI.TRAIN_BRASS.darkened(0.15))


# --- the moving parts ----------------------------------------------------------------

func _draw_front(ci: Control) -> void:
	var b := UI.Draw.Batch.new()
	# The lamps' warm glow, breathing a little.
	for i in lamps.size():
		var l: Vector2 = lamps[i] + Vector2(0, -15.0 * u)
		var k := 0.85 + 0.15 * sin(t * 2.3 + i * 1.7)
		UI.glow_into(b, l, 70.0 * u * k, UI.TRAIN_WINDOW, 1.4)
	# Steam leaking low by the wheels.
	for s in steam:
		var k: float = s["age"] / 1.6
		b.dot(s["p"], (6.0 + 16.0 * k) * u, Color(UI.TRAIN_SMOKE.lightened(0.3), 0.3 * (1.0 - k)))
	# Smoke from the stack: dark and dense near it, growing and fading as it rises.
	for p in puffs:
		var k: float = p["age"] / PUFF_LIFE
		var r: float = (10.0 + 46.0 * sqrt(k)) * u * float(p["r"])
		var a := 0.5 * (1.0 - k) * minf(1.0, p["age"] * 4.0)
		var col := UI.TRAIN_SMOKE.darkened(0.55 * (1.0 - k))
		b.dot(p["p"], r, Color(col, a))
		b.dot(p["p"] + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(col.lightened(0.25), a * 0.6))
	b.flush(ci)


# --- the workshop's bench ----------------------------------------------------------

## The workshop car's corner, drawn in code for its page: the car's panelled
## wall and a lamp, a pegboard of tools, a shelf of bottles in the six
## essences' colours, the workbench with a vice, and the Rune Artist's
## slate, its runes glowing when you carry the Rune Artist's mark (`lit`).
class Bench extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Gear := preload("res://scripts/gear.gd")
	const Essence := preload("res://scripts/essence.gd")
	const WOOD := Color(0.42, 0.27, 0.16)
	const SLATE := Color(0.16, 0.16, 0.2)
	const RUNE := Color(0.62, 0.66, 1.0)  # the Rune Artist's colour (bonds.gd)
	var lit := false
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var u := h / 84.0
		var b := UI.Draw.Batch.new()
		# The wall: oxblood panels with a brass rail, and a dark frame.
		b.rect(Rect2(Vector2.ZERO, size), UI.OUTLINE)
		b.rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), UI.TRAIN_CAR.darkened(0.35))
		for i in 4:
			var px := 6.0 * u + i * (w - 12.0 * u) / 4.0
			b.rect(Rect2(px + 2.0 * u, 6.0 * u, (w - 12.0 * u) / 4.0 - 4.0 * u, h * 0.5), UI.TRAIN_CAR.darkened(0.2))
		b.rect(Rect2(1.5, h * 0.58, w - 3.0, 2.5 * u), UI.TRAIN_BRASS.darkened(0.25))
		# The lamp's warm light from the top left.
		var lamp := Vector2(w * 0.16, 9.0 * u)
		UI.glow_into(b, lamp + Vector2(0, 6.0 * u), 40.0 * u, UI.TRAIN_WINDOW, 1.2)
		b.line(Vector2(lamp.x, 1.5), lamp, UI.TRAIN_IRON.lightened(0.2), 1.2 * u)
		b.polygon(PackedVector2Array([lamp + Vector2(-6, 2) * u, lamp + Vector2(0, -3) * u, lamp + Vector2(6, 2) * u]), UI.TRAIN_BRASS)
		b.dot(lamp + Vector2(0, 5.0 * u), 3.6 * u, UI.TRAIN_WINDOW.lightened(0.2))
		# A pegboard of tools: a hammer, tongs and a file.
		var peg := Rect2(w * 0.3, 7.0 * u, w * 0.26, h * 0.36)
		b.rect(peg.grow(1.2 * u), UI.OUTLINE)
		b.rect(peg, WOOD.darkened(0.35))
		var hx := peg.position.x + peg.size.x * 0.22
		b.line(Vector2(hx, peg.position.y + 4.0 * u), Vector2(hx, peg.end.y - 3.0 * u), WOOD.lightened(0.15), 2.0 * u)
		b.rect(Rect2(hx - 4.5 * u, peg.position.y + 3.0 * u, 9.0 * u, 4.5 * u), UI.TRAIN_IRON.lightened(0.35))
		var tx := peg.position.x + peg.size.x * 0.55
		b.line(Vector2(tx - 2.0 * u, peg.position.y + 4.0 * u), Vector2(tx + 1.5 * u, peg.end.y - 3.0 * u), UI.TRAIN_IRON.lightened(0.4), 1.4 * u)
		b.line(Vector2(tx + 2.0 * u, peg.position.y + 4.0 * u), Vector2(tx - 1.5 * u, peg.end.y - 3.0 * u), UI.TRAIN_IRON.lightened(0.4), 1.4 * u)
		var fx := peg.position.x + peg.size.x * 0.82
		b.line(Vector2(fx, peg.position.y + 4.0 * u), Vector2(fx, peg.end.y - 4.0 * u), UI.TRAIN_COPPER, 1.8 * u)
		# A shelf of bottles, one for each essence.
		var shelf_y := h * 0.5
		b.rect(Rect2(w * 0.3, shelf_y, w * 0.3, 2.0 * u), WOOD)
		var kinds: Array = Essence.KINDS.keys()
		for i in kinds.size():
			var bx := w * 0.31 + i * (w * 0.28 / kinds.size()) + 2.0 * u
			var bh := (7.0 + 2.0 * (i % 2)) * u
			b.rect(Rect2(bx - 1.0 * u, shelf_y - bh - 0.8 * u, 4.6 * u, bh + 0.8 * u), UI.OUTLINE)
			b.rect(Rect2(bx - 0.4 * u, shelf_y - bh, 3.4 * u, bh), Essence.color(kinds[i]).darkened(0.1))
			b.rect(Rect2(bx + 0.2 * u, shelf_y - bh - 2.2 * u, 2.2 * u, 2.2 * u), WOOD.lightened(0.2))
		# The workbench: a thick top with a brass edge, legs, a vice at the left.
		var top := Rect2(5.0 * u, h * 0.62, w * 0.6, 7.0 * u)
		b.rect(top.grow(1.2 * u), UI.OUTLINE)
		b.rect(top, WOOD)
		b.rect(Rect2(top.position, Vector2(top.size.x, 2.0 * u)), WOOD.lightened(0.2))
		b.rect(Rect2(top.position.x, top.end.y - 1.6 * u, top.size.x, 1.6 * u), UI.TRAIN_BRASS.darkened(0.2))
		for lx in [top.position.x + 4.0 * u, top.end.x - 9.0 * u]:
			b.rect(Rect2(lx, top.end.y, 5.0 * u, h - top.end.y - 3.0 * u), WOOD.darkened(0.3))
		b.rect(Rect2(top.position.x + 6.0 * u, top.end.y + (h - top.end.y) * 0.55, top.size.x - 12.0 * u, 2.5 * u), WOOD.darkened(0.4))
		var vice := Vector2(top.position.x + 14.0 * u, top.position.y)
		b.rect(Rect2(vice + Vector2(-6, -8) * u, Vector2(5, 8) * u), UI.TRAIN_IRON.lightened(0.3))
		b.rect(Rect2(vice + Vector2(1, -8) * u, Vector2(5, 8) * u), UI.TRAIN_IRON.lightened(0.3))
		b.line(vice + Vector2(-9, -4) * u, vice + Vector2(9, -4) * u, UI.TRAIN_BRASS, 1.2 * u)
		# Something on the bench: a flask over a small burner, steaming.
		var fl := Vector2(top.position.x + top.size.x * 0.62, top.position.y - 7.0 * u)
		b.dot(fl, 5.2 * u, UI.OUTLINE)
		b.dot(fl, 4.2 * u, Essence.color("water").darkened(0.1))
		b.rect(Rect2(fl + Vector2(-1.4, -9.0) * u, Vector2(2.8, 5.0) * u), Color(0.8, 0.85, 0.9, 0.7))
		b.rect(Rect2(fl + Vector2(-3.0, 4.2) * u, Vector2(6.0, 2.6) * u), UI.TRAIN_COPPER)
		var k := 0.5 + 0.5 * sin(t * 1.7)
		b.dot(fl + Vector2(2.0 * u, -12.0 * u - 3.0 * k * u), (1.6 + k) * u, Color(UI.TRAIN_SMOKE, 0.35 * (1.0 - k)))
		# The Rune Artist's corner: a slate on the wall with three runes,
		# glowing (and breathing) when the mark is yours; dark otherwise.
		var slate := Rect2(w * 0.66, 6.0 * u, w * 0.31, h * 0.74)
		b.rect(slate.grow(2.0 * u), UI.TRAIN_BRASS.darkened(0.3))
		b.rect(slate, SLATE)
		var glow := (0.75 + 0.25 * sin(t * 2.1)) if lit else 0.0
		if lit:
			UI.glow_into(b, slate.get_center(), slate.size.x * 0.7, RUNE, 0.8 * glow)
		var rr := minf(slate.size.x * 0.22, slate.size.y * 0.13)
		var ids := ["sharpness", "warding", "swiftness"]
		for i in 3:
			var c := Vector2(slate.get_center().x + (i - 1) * slate.size.x * 0.0, slate.position.y + slate.size.y * (0.2 + 0.3 * i))
			c.x += (-1.0 if i == 1 else 1.0) * slate.size.x * 0.12
			var col: Color = Color(Gear.LASTING_RUNES[ids[i]]["color"], 0.35 + 0.65 * glow) if lit else Color(0.5, 0.5, 0.58, 0.45)
			Gear.rune_into(b, ids[i], c, rr, col, false)
		# Chalk on the ledge below the slate.
		b.rect(Rect2(slate.position.x, slate.end.y + 2.0 * u, slate.size.x, 2.0 * u), UI.TRAIN_BRASS.darkened(0.3))
		b.rect(Rect2(slate.position.x + slate.size.x * 0.6, slate.end.y - 0.2 * u, 5.0 * u, 2.0 * u), Color(0.9, 0.9, 0.86))
		b.flush(self)
