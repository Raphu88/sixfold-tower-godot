extends Control
## The train between climbs, drawn in code from the inside: menu.gd's
## "train" page. Its cars stand side by side in one long strip, each as wide
## as the screen: the engine at the front (left), then your car, the store
## car and the workshop. Scrolling slides the strip (train_page.gd moves it
## and puts each car's things in its room).
##
## Kept light for phones: each room's walls, windows, lamps and floor are
## drawn once (again only when the screen changes size), so sliding along
## costs nothing; only the lamps' glow and the engine's firebox breathe, on a
## thin layer redrawn a few times a second for the cars on screen.
## Colours are in ui.gd (TRAIN_*); the cars' names and words in train.gd.

const UI := preload("res://scripts/ui.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")

## Below this screen height (a phone) the margins tighten (menu.gd COMPACT_H).
const COMPACT_H := 600.0
## The bands kept clear at the top (the cars' names), the bottom (your
## crystals) and the sides (the arrows to the next car): [phone, desktop].
const TOP := [44.0, 58.0]
const BOTTOM := [50.0, 60.0]
const SIDE := [52.0, 74.0]
const GLOW_FPS := 12.0  # how often the lamps' light is redrawn
const EASE := 13.0  # how quickly the train settles on a car (higher: quicker)

## The rooms' own colours (the rest are ui.gd's TRAIN_*).
const WALNUT := Color(0.3, 0.18, 0.11)
const OAK := Color(0.42, 0.27, 0.16)
const VELVET := Color(0.42, 0.09, 0.1)
const STORE_WALL := Color(0.11, 0.2, 0.16)
const PLANK := Color(0.24, 0.16, 0.11)
const STEEL := Color(0.16, 0.24, 0.22)

## The screen changed size (the cars' things are built again for it).
signal laid_out

var strip: Control  # the cars, side by side
var rooms := {}  # car id -> Room
var chrome: Control  # over the cars: their names, the arrows, your crystals (train_page.gd)
var pos := 1.0  # where the train stands, in cars (0 = the engine)
var target := 1  # the car it settles on
var dragging := false  # a finger or the mouse holds it
var fit_frames := 0  # the cars' things are fitted to their rooms for a few frames after a build
var small := false
var t := 0.0
var glow_acc := 0.0
var fit_hook := Callable()  # (train_page.gd: the placards fitted to what they say)
var _laid_for := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip = Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	for c in Train.CARS:
		var r := Room.new(c[0], self)
		rooms[c[0]] = r
		strip.add_child(r)
	chrome = Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chrome)
	_lay_out()


func ids() -> Array:
	return Train.CARS.map(func(c): return c[0])


func _size() -> Vector2:
	return get_viewport_rect().size


## Lays the cars out again if the screen changed size (before a build).
func refresh() -> void:
	if _size() != _laid_for:
		_lay_out()


## The margins of a room's area (where its things go): top, bottom, side.
func margins() -> Vector3:
	var k := 0 if small else 1
	return Vector3(TOP[k], BOTTOM[k], SIDE[k])


func _lay_out() -> void:
	var s := _size()
	_laid_for = s
	small = s.y < COMPACT_H
	var mg := margins()
	var list := ids()
	for i in list.size():
		var r: Room = rooms[list[i]]
		r.position = Vector2(i * s.x, 0.0)
		r.size = s
		r.glow.size = s
		r.area.position = Vector2(mg.z, mg.x)
		r.area.size = Vector2(s.x - mg.z * 2.0, s.y - mg.x - mg.y)
		r.queue_redraw()
	strip.size = Vector2(s.x * list.size(), s.y)
	fit_frames = 3
	place()


## Settles on car `i`, sliding there (or at once).
func go(i: int, animate := true) -> void:
	target = clampi(i, 0, ids().size() - 1)
	if not animate:
		pos = target
	place()


## A nudge at either end of the train: it rocks a little and settles back.
func bump(dir: int) -> void:
	pos = target + 0.035 * dir


func place() -> void:
	strip.position = Vector2(roundf(-pos * _size().x), 0.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _size() != _laid_for:
		_lay_out()
		laid_out.emit()
	if fit_frames > 0:
		fit_frames -= 1
		for r in rooms.values():
			r.fit()
		if fit_hook.is_valid():
			fit_hook.call()
	if not dragging and pos != target:
		pos = lerpf(pos, target, 1.0 - exp(-delta * EASE))
		if absf(pos - target) < 0.0015:
			pos = target
		place()
	t += delta
	glow_acc += delta
	if glow_acc >= 1.0 / GLOW_FPS:
		glow_acc = 0.0
		var list := ids()
		for i in list.size():
			if absf(i - pos) < 1.0:
				rooms[list[i]].glow.queue_redraw()


## Takes away every car's things and the chrome (train_page.gd builds them again).
func clear_content() -> void:
	for r in rooms.values():
		for c in r.area.get_children():
			r.area.remove_child(c)
			c.queue_free()
		r.lamps.clear()
	for c in chrome.get_children():
		chrome.remove_child(c)
		c.queue_free()
	fit_frames = 3


## A car's room: its walls drawn once, the lamps' glow above them, and an
## area (inside the margins) for its things.
class Room extends Control:
	var car := ""
	var view
	var area: Control
	var glow: Control
	var lamps: Array = []  # where its lamps hang (for the glow)
	var fire := Vector2.ZERO  # the engine's firebox door

	func _init(id: String, v) -> void:
		car = id
		view = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow = Control.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.draw.connect(_draw_glow)
		add_child(glow)
		area = Control.new()
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(area)

	func _draw() -> void:
		view.paint_room(self)

	func _draw_glow() -> void:
		view.paint_glow(self)

	## Shrinks the car's things to fit its area if they're too big (a narrow screen).
	func fit() -> void:
		for c in area.get_children():
			if not (c is Control) or c.is_queued_for_deletion():
				continue
			var need: Vector2 = c.get_combined_minimum_size()
			var k := minf(1.0, minf(area.size.x / maxf(need.x, 1.0), area.size.y / maxf(need.y, 1.0)))
			c.scale = Vector2(k, k)
			c.position = Vector2.ZERO
			c.size = area.size / k


# --- the rooms ----------------------------------------------------------------------

## Draws a car's room: ceiling, walls, windows on the dusk, lamps, panelling
## and floor, then what belongs to that car.
func paint_room(r: Room) -> void:
	var s := r.size
	var u := maxf(0.5, s.y / 720.0)
	var mg := margins()
	var b := UI.Draw.Batch.new()
	var ceil_y := mg.x + 4.0 * u
	var wain := s.y * 0.6
	var floor_y := s.y - mg.y - 6.0 * u
	var look: Array = {
		"engine": [STEEL, UI.TRAIN_IRON.lightened(0.08), UI.TRAIN_IRON.lightened(0.04)],
		"personal": [VELVET, WALNUT, Color(0.2, 0.12, 0.09)],
		"store": [STORE_WALL, OAK.darkened(0.15), PLANK],
		"workshop": [PLANK.darkened(0.1), WALNUT.darkened(0.2), UI.TRAIN_IRON.lightened(0.06)],
	}[r.car]
	# The wall.
	b.rect(Rect2(0, 0, s.x, s.y), look[0])
	match r.car:
		"engine":
			# Riveted steel plates.
			var plate := 150.0 * u
			var x := 0.0
			while x < s.x:
				b.rect(Rect2(x, ceil_y, 2.0 * u, wain - ceil_y), look[0].darkened(0.35))
				_rivet_row(b, Vector2(x + 8.0 * u, ceil_y + 10.0 * u), Vector2(x + 8.0 * u, wain - 8.0 * u), 22.0 * u, u)
				x += plate
			_rivet_row(b, Vector2(0, ceil_y + 10.0 * u), Vector2(s.x, ceil_y + 10.0 * u), 22.0 * u, u)
		"personal":
			# Buttoned velvet: a diamond of tufts.
			var gap := 46.0 * u
			var row := 0
			var y := ceil_y + gap * 0.5
			while y < wain:
				var x := gap * 0.5 * (row % 2)
				while x < s.x:
					b.dot(Vector2(x, y), 3.0 * u, look[0].darkened(0.35))
					b.dot(Vector2(x - 0.8 * u, y - 0.8 * u), 1.4 * u, look[0].lightened(0.25))
					x += gap
				y += gap * 0.5
				row += 1
		"store":
			# Gold pinstripes on bottle green.
			var x := 30.0 * u
			while x < s.x:
				b.rect(Rect2(x, ceil_y, 1.5 * u, wain - ceil_y), Color(UI.TRAIN_BRASS, 0.16))
				x += 36.0 * u
		"workshop":
			# Upright boards.
			var x := 0.0
			var i := 0
			while x < s.x:
				b.rect(Rect2(x, ceil_y, 34.0 * u, wain - ceil_y), look[0].lightened(0.03 * (i % 3)))
				b.rect(Rect2(x, ceil_y, 1.5 * u, wain - ceil_y), look[0].darkened(0.4))
				x += 34.0 * u
				i += 1
	# Windows on the dusk outside (round spectacle glasses in the engine).
	var wins: Array = [0.17, 0.5, 0.83] if r.car != "engine" else [0.14, 0.86]
	var top := ceil_y + 26.0 * u
	var bottom := wain - 30.0 * u
	for i in wins.size():
		var cx: float = s.x * wins[i]
		if r.car == "engine":
			_porthole(b, Vector2(cx, (top + bottom) * 0.5), minf(70.0 * u, (bottom - top) * 0.5), i + 1, u)
		else:
			var w := 128.0 * u
			_window(b, Rect2(cx - w * 0.5, top, w, bottom - top), i + ids().find(r.car) * 3, u, r.car == "personal")
	# Lamps between the windows.
	r.lamps.clear()
	var lamp_xs: Array = [0.335, 0.665] if r.car != "engine" else [0.5]
	for lx in lamp_xs:
		var at := Vector2(s.x * lx, ceil_y + 42.0 * u)
		_sconce(b, at, u)
		r.lamps.append(at + Vector2(0, 8.0 * u))
	# The ceiling: a dark vault with brass ribs, and a cornice.
	b.rect(Rect2(0, 0, s.x, ceil_y), UI.TRAIN_ROOF.darkened(0.2))
	for i in 6:
		var x := s.x * (i + 0.5) / 6.0
		b.rect(Rect2(x - 3.0 * u, 0, 6.0 * u, ceil_y), UI.TRAIN_ROOF.lightened(0.06))
	b.rect(Rect2(0, ceil_y - 5.0 * u, s.x, 5.0 * u), UI.TRAIN_BRASS.darkened(0.3))
	b.rect(Rect2(0, ceil_y - 5.0 * u, s.x, 1.5 * u), UI.TRAIN_BRASS.lightened(0.1))
	# The panelling below, behind a brass rail.
	b.rect(Rect2(0, wain, s.x, floor_y - wain), look[1])
	var pw := 120.0 * u
	var x0 := 18.0 * u
	while x0 < s.x:
		var pr := Rect2(x0 + 8.0 * u, wain + 14.0 * u, pw - 16.0 * u, floor_y - wain - 26.0 * u)
		if pr.size.y > 8.0 * u:
			b.rect(pr, look[1].darkened(0.18))
			b.rect(Rect2(pr.position, Vector2(pr.size.x, 2.0 * u)), look[1].darkened(0.45))
			b.rect(Rect2(pr.position + Vector2(0, pr.size.y - 2.0 * u), Vector2(pr.size.x, 2.0 * u)), look[1].lightened(0.12))
		x0 += pw
	b.rect(Rect2(0, wain - 3.0 * u, s.x, 7.0 * u), UI.TRAIN_BRASS.darkened(0.15))
	b.rect(Rect2(0, wain - 3.0 * u, s.x, 2.0 * u), UI.TRAIN_BRASS.lightened(0.2))
	# The floor.
	b.rect(Rect2(0, floor_y, s.x, s.y - floor_y), look[2])
	var fy := floor_y
	var step := 9.0 * u
	while fy < s.y:
		b.rect(Rect2(0, fy, s.x, 1.2 * u), look[2].darkened(0.4))
		fy += step
		step *= 1.35
	if r.car == "personal":
		# A rug.
		var rug := Rect2(s.x * 0.18, floor_y + 4.0 * u, s.x * 0.64, s.y - floor_y)
		b.rect(rug, VELVET.darkened(0.25))
		b.rect(Rect2(rug.position + Vector2(6.0 * u, 3.0 * u), Vector2(rug.size.x - 12.0 * u, 2.0 * u)), Color(UI.TRAIN_BRASS, 0.6))
	match r.car:
		"engine":
			_engine_room(b, r, s, u, ceil_y, wain, floor_y)
		"store":
			_store_room(b, s, u, ceil_y, wain)
		"workshop":
			_workshop_room(b, s, u, ceil_y, wain)
	# The ends of the car: walnut pillars (where two cars meet, a gangway).
	for side in [0.0, 1.0]:
		var px: float = side * (s.x - 16.0 * u)
		b.rect(Rect2(px, 0, 16.0 * u, s.y), WALNUT.darkened(0.25))
		b.rect(Rect2(px + (0.0 if side == 0.0 else 12.0 * u), 0, 4.0 * u, s.y), Color(0.03, 0.02, 0.02))
		b.rect(Rect2(px + 5.0 * u, 0, 2.0 * u, s.y), WALNUT.lightened(0.1))
		_rivet_row(b, Vector2(px + 9.0 * u, ceil_y + 20.0 * u), Vector2(px + 9.0 * u, floor_y - 10.0 * u), 40.0 * u, u)
	b.flush(r)


func _rivet_row(b, from: Vector2, to: Vector2, gap: float, u: float) -> void:
	var n := int(from.distance_to(to) / gap)
	for i in n + 1:
		var p := from.lerp(to, float(i) / maxf(n, 1))
		b.dot(p, 2.0 * u, UI.TRAIN_BRASS.darkened(0.4))
		b.dot(p + Vector2(-0.5, -0.5) * u, 1.1 * u, UI.TRAIN_BRASS.lightened(0.2))


## An arched window: a brass frame, the dusk outside with a tower or two
## lit in their essence's colour, a mullion and a glint on the glass.
func _window(b, r: Rect2, seed: int, u: float, curtains: bool) -> void:
	var frame := UI.TRAIN_BRASS.darkened(0.25)
	var half := r.size.x * 0.5
	var arch := Vector2(r.get_center().x, r.position.y + half)
	b.rect(Rect2(r.position + Vector2(-6.0 * u, half), Vector2(r.size.x + 12.0 * u, r.size.y - half + 6.0 * u)), UI.OUTLINE)
	b.circle(arch, half + 6.0 * u, UI.OUTLINE)
	b.rect(Rect2(r.position + Vector2(-5.0 * u, half), Vector2(r.size.x + 10.0 * u, r.size.y - half + 5.0 * u)), frame)
	b.circle(arch, half + 5.0 * u, frame)
	# The sky: dark above, warm low down; the field below the horizon.
	var glass := Rect2(r.position.x, arch.y, r.size.x, r.end.y - arch.y)
	var horizon := r.position.y + r.size.y * 0.74
	b.circle(arch, half, UI.TRAIN_SKY[0])
	var bands := 10
	for i in bands:
		var k := float(i) / bands
		var col: Color = UI.TRAIN_SKY[0].lerp(UI.TRAIN_SKY[1], k / 0.6) if k < 0.6 else UI.TRAIN_SKY[1].lerp(UI.TRAIN_SKY[2], (k - 0.6) / 0.4)
		var y0 := lerpf(arch.y, horizon, k)
		b.rect(Rect2(glass.position.x, y0, glass.size.x, (horizon - arch.y) / bands + 1.0), col)
	b.rect(Rect2(glass.position.x, horizon, glass.size.x, glass.end.y - horizon), UI.TRAIN_GROUND.lightened(0.05))
	b.rect(Rect2(glass.position.x, horizon, glass.size.x, 2.0 * u), Color(UI.TRAIN_SKY[2], 0.45))
	# Stars in the arch.
	for i in 4:
		var a := rng_off(seed * 7 + i)
		var p := arch + Vector2((a - 0.5) * half * 1.3, -half * (0.15 + 0.6 * rng_off(seed * 3 + i + 11)))
		b.dot(p, 1.0 * u, Color(1, 0.95, 0.85, 0.5 + 0.4 * a))
	# A tower or two on the horizon.
	for j in 2:
		var id: String = Towers.ORDER[(seed + j * 3) % Towers.ORDER.size()]
		var tx := glass.position.x + glass.size.x * (0.28 + 0.46 * j) + (rng_off(seed + j) - 0.5) * 10.0 * u
		var th := (horizon - arch.y) * (0.55 + 0.35 * rng_off(seed * 5 + j))
		var tw := r.size.x * (0.07 + 0.03 * rng_off(seed + j + 4))
		var dark := Color(0.09, 0.06, 0.12)
		b.polygon(PackedVector2Array([Vector2(tx - tw, horizon + 1.0), Vector2(tx - tw * 0.6, horizon - th), Vector2(tx, horizon - th - 12.0 * u),
			Vector2(tx + tw * 0.6, horizon - th), Vector2(tx + tw, horizon + 1.0)]), dark)
		b.rect(Rect2(tx - 1.6 * u, horizon - th * 0.6, 3.2 * u, 5.0 * u), Color(Essence.color(Towers.TOWERS[id]["essence"]), 0.9))
	# The mullion and transom, and a glint.
	b.rect(Rect2(arch.x - 2.0 * u, r.position.y, 4.0 * u, r.size.y), frame.darkened(0.15))
	b.rect(Rect2(glass.position.x, arch.y - 2.0 * u, glass.size.x, 4.0 * u), frame.darkened(0.15))
	b.polygon(PackedVector2Array([glass.position + Vector2(6.0 * u, 8.0 * u), glass.position + Vector2(18.0 * u, 8.0 * u),
		glass.position + Vector2(8.0 * u, glass.size.y * 0.55), glass.position + Vector2(4.0 * u, glass.size.y * 0.55)]), Color(1, 1, 1, 0.07))
	# A sill.
	b.rect(Rect2(r.position.x - 12.0 * u, r.end.y + 3.0 * u, r.size.x + 24.0 * u, 7.0 * u), WALNUT)
	b.rect(Rect2(r.position.x - 12.0 * u, r.end.y + 3.0 * u, r.size.x + 24.0 * u, 2.0 * u), WALNUT.lightened(0.2))
	if curtains:
		# Velvet curtains, tied back with gold.
		for side in [-1.0, 1.0]:
			var ox: float = r.position.x - 10.0 * u if side < 0.0 else r.end.x + 10.0 * u
			var inner: float = ox - side * 26.0 * u
			var tie := r.position.y + r.size.y * 0.62
			var pts := PackedVector2Array([Vector2(ox + side * 8.0 * u, r.position.y - 14.0 * u), Vector2(inner, r.position.y - 14.0 * u),
				Vector2(ox - side * 4.0 * u, tie), Vector2(inner + side * 6.0 * u, r.end.y + 12.0 * u), Vector2(ox + side * 8.0 * u, r.end.y + 12.0 * u)])
			b.polygon(pts, Color(0.5, 0.1, 0.12))
			b.line(Vector2(ox, r.position.y - 12.0 * u), Vector2(ox, r.end.y + 10.0 * u), Color(0.3, 0.05, 0.07), 3.0 * u)
			b.dot(Vector2(ox - side * 2.0 * u, tie), 4.0 * u, UI.TRAIN_BRASS)
		b.rect(Rect2(r.position.x - 26.0 * u, r.position.y - 18.0 * u, r.size.x + 52.0 * u, 5.0 * u), UI.TRAIN_BRASS.darkened(0.2))


## A round spectacle glass in the cab, the tower ahead lit in its colour.
func _porthole(b, c: Vector2, rad: float, seed: int, u: float) -> void:
	b.dot(c, rad + 9.0 * u, UI.OUTLINE)
	b.dot(c, rad + 8.0 * u, UI.TRAIN_BRASS.darkened(0.2))
	b.dot(c, rad, UI.TRAIN_SKY[1])
	b.dot(c + Vector2(0, rad * 0.45), rad * 0.82, UI.TRAIN_SKY[2].darkened(0.1))
	b.dot(c + Vector2(0, -rad * 0.35), rad * 0.62, UI.TRAIN_SKY[0])
	var horizon := c.y + rad * 0.45
	var id: String = Towers.ORDER[seed % Towers.ORDER.size()]
	var tw := rad * 0.16
	var th := rad * 0.9
	b.polygon(PackedVector2Array([Vector2(c.x - tw, horizon), Vector2(c.x - tw * 0.6, horizon - th), Vector2(c.x, horizon - th - 8.0 * u),
		Vector2(c.x + tw * 0.6, horizon - th), Vector2(c.x + tw, horizon)]), Color(0.09, 0.06, 0.12))
	b.rect(Rect2(c.x - 1.5 * u, horizon - th * 0.6, 3.0 * u, 4.5 * u), Essence.color(Towers.TOWERS[id]["essence"]))
	# The field below, cut off flat by the frame's lower lip.
	b.rect(Rect2(c.x - rad * 0.9, horizon, rad * 1.8, rad * 0.42), UI.TRAIN_GROUND.lightened(0.05))
	b.arc(c, rad + 4.0 * u, 0.0, TAU, 40, UI.TRAIN_BRASS.lightened(0.1), 3.0 * u)
	for i in 8:
		b.dot(c + Vector2.from_angle(TAU * i / 8.0) * (rad + 4.0 * u), 2.0 * u, UI.TRAIN_BRASS.darkened(0.45))


## A brass wall lamp with a warm glass shade.
func _sconce(b, at: Vector2, u: float) -> void:
	b.rect(Rect2(at.x - 7.0 * u, at.y - 20.0 * u, 14.0 * u, 6.0 * u), UI.TRAIN_BRASS.darkened(0.3))
	b.line(at + Vector2(0, -16.0 * u), at + Vector2(0, -4.0 * u), UI.TRAIN_BRASS.darkened(0.1), 2.5 * u)
	b.polygon(PackedVector2Array([at + Vector2(-9.0, -4.0) * u, at + Vector2(9.0, -4.0) * u, at + Vector2(6.0, 12.0) * u, at + Vector2(-6.0, 12.0) * u]), UI.TRAIN_WINDOW)
	b.rect(Rect2(at.x - 10.0 * u, at.y - 6.0 * u, 20.0 * u, 3.0 * u), UI.TRAIN_BRASS)
	b.dot(at + Vector2(0, 14.0 * u), 2.5 * u, UI.TRAIN_BRASS)


## The cab: copper pipes, gauges, and the firebox glowing low in the middle.
func _engine_room(b, r: Room, s: Vector2, u: float, ceil_y: float, wain: float, floor_y: float) -> void:
	# Pipes along the wall.
	b.line(Vector2(0, ceil_y + 22.0 * u), Vector2(s.x, ceil_y + 22.0 * u), UI.TRAIN_COPPER, 7.0 * u)
	b.line(Vector2(0, ceil_y + 20.0 * u), Vector2(s.x, ceil_y + 20.0 * u), UI.TRAIN_COPPER.lightened(0.25), 1.5 * u)
	for px in [0.3, 0.7]:
		b.line(Vector2(s.x * px, ceil_y + 22.0 * u), Vector2(s.x * px, wain), UI.TRAIN_COPPER.darkened(0.1), 6.0 * u)
	# Gauges by the pipes.
	for i in 3:
		var c := Vector2(s.x * (0.42 + 0.08 * i), ceil_y + 58.0 * u)
		b.dot(c, 17.0 * u, UI.OUTLINE)
		b.dot(c, 15.5 * u, UI.TRAIN_BRASS)
		b.dot(c, 12.5 * u, Color(0.92, 0.88, 0.78))
		var a := -PI * 0.75 + PI * (0.4 + 0.3 * i)
		b.line(c, c + Vector2.from_angle(a) * 10.0 * u, Color(0.6, 0.12, 0.1), 1.6 * u)
		b.dot(c, 2.0 * u, UI.OUTLINE)
	# The backhead and the firebox door, low in the middle.
	var fc := Vector2(s.x * 0.5, floor_y - 6.0 * u)
	b.dot(fc, 92.0 * u, UI.TRAIN_IRON)
	b.dot(fc, 86.0 * u, STEEL.darkened(0.2))
	var door := Rect2(fc + Vector2(-34.0, -46.0) * u, Vector2(68.0, 40.0) * u)
	b.rect(door.grow(5.0 * u), UI.TRAIN_BRASS.darkened(0.3))
	b.rect(door, Color(0.95, 0.45, 0.15))
	b.rect(Rect2(door.position + Vector2(0, door.size.y * 0.55), Vector2(door.size.x, door.size.y * 0.45)), Color(1.0, 0.75, 0.3))
	for i in 5:
		b.rect(Rect2(door.position.x + door.size.x * (i + 0.5) / 5.0 - 2.0 * u, door.position.y, 4.0 * u, door.size.y), UI.TRAIN_IRON)
	r.fire = door.get_center()


## The store car: hat boxes and parcels on a high shelf.
func _store_room(b, s: Vector2, u: float, _ceil_y: float, wain: float) -> void:
	# A high shelf of hat boxes and parcels along the wall.
	b.rect(Rect2(20.0 * u, wain - 18.0 * u, s.x - 40.0 * u, 5.0 * u), OAK)
	var x := 30.0 * u
	var i := 0
	while x < s.x - 60.0 * u:
		var w := (26.0 + 14.0 * rng_off(i)) * u
		var h := (12.0 + 10.0 * rng_off(i + 5)) * u
		var col: Color = [Color(0.55, 0.42, 0.28), Color(0.3, 0.32, 0.42), Color(0.48, 0.2, 0.18), Color(0.62, 0.55, 0.4)][i % 4]
		b.rect(Rect2(x, wain - 18.0 * u - h, w, h), col.darkened(0.2))
		b.rect(Rect2(x + w * 0.45, wain - 18.0 * u - h, 2.0 * u, h), Color(UI.TRAIN_BRASS, 0.6))
		x += w + (6.0 + 30.0 * rng_off(i + 9)) * u
		i += 1


## The workshop car: copper pipes and tools hung along the boards.
func _workshop_room(b, s: Vector2, u: float, ceil_y: float, wain: float) -> void:
	b.line(Vector2(0, ceil_y + 16.0 * u), Vector2(s.x, ceil_y + 16.0 * u), UI.TRAIN_COPPER.darkened(0.1), 6.0 * u)
	for i in 9:
		var x := s.x * (0.05 + 0.11 * i)
		var y := wain - 40.0 * u
		match i % 3:
			0:  # a wrench
				b.line(Vector2(x, y - 30.0 * u), Vector2(x, y), UI.TRAIN_IRON.lightened(0.35), 3.0 * u)
				b.circle(Vector2(x, y - 32.0 * u), 5.0 * u, UI.TRAIN_IRON.lightened(0.35))
			1:  # a saw
				b.polygon(PackedVector2Array([Vector2(x - 4.0 * u, y - 30.0 * u), Vector2(x + 4.0 * u, y - 30.0 * u), Vector2(x + 2.0 * u, y), Vector2(x - 6.0 * u, y)]), UI.TRAIN_IRON.lightened(0.45))
				b.rect(Rect2(x - 5.0 * u, y - 36.0 * u, 10.0 * u, 7.0 * u), OAK)
			2:  # a mallet
				b.line(Vector2(x, y - 22.0 * u), Vector2(x, y), OAK.lightened(0.1), 3.0 * u)
				b.rect(Rect2(x - 8.0 * u, y - 30.0 * u, 16.0 * u, 9.0 * u), OAK.darkened(0.1))
		b.dot(Vector2(x, y - 38.0 * u), 1.8 * u, UI.TRAIN_BRASS)


## The moving light: each lamp's warm glow, breathing; the engine's firebox flickering.
func paint_glow(r: Room) -> void:
	var u := maxf(0.5, r.size.y / 720.0)
	var b := UI.Draw.Batch.new()
	for i in r.lamps.size():
		var k := 0.88 + 0.12 * sin(t * 2.1 + i * 1.9 + r.position.x * 0.01)
		UI.glow_into(b, r.lamps[i], 90.0 * u * k, UI.TRAIN_WINDOW, 1.1)
	if r.fire != Vector2.ZERO:
		var f := 0.75 + 0.25 * sin(t * 9.0) * sin(t * 5.3 + 1.0)
		UI.glow_into(b, r.fire, 120.0 * u * f, Color(1.0, 0.5, 0.2), 1.6)
	b.flush(r.glow)


## A steady pseudo-random 0..1 for a number.
static func rng_off(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


# --- furniture: drawn behind the cars' things -------------------------------------------

## A piece of the car's furniture, drawn behind the slots it holds, so the
## things you can choose sit where they belong: the heirloom wardrobe, your
## pack, the storage chest, the outfitter's shelves, rail and glass case, the
## destination board, the bench's drawers, a placard. It watches its grid
## (`watch`) to put a shelf under each row or a hook over each slot.
class Furnish extends PanelContainer:
	const UI := preload("res://scripts/ui.gd")
	const MARGINS := {  # left, top, right, bottom
		"rack": [14, 12, 14, 14], "pack": [16, 22, 16, 14], "chest": [16, 14, 16, 18], "shelf": [12, 8, 12, 12],
		"rail": [12, 8, 12, 10], "case": [14, 16, 14, 18], "board": [16, 12, 16, 14], "drawers": [8, 8, 8, 10],
		"placard": [14, 12, 14, 12], "plain": [10, 8, 10, 8],
	}
	var kind := "plain"
	var watch: Control = null  # the grid whose rows (or slots) the drawing follows

	func _init(k := "plain", small := false) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxEmpty.new()
		var m: Array = MARGINS.get(k, MARGINS["plain"])
		var f := 0.75 if small else 1.0
		st.content_margin_left = m[0] * f
		st.content_margin_top = m[1] * f
		st.content_margin_right = m[2] * f
		st.content_margin_bottom = m[3] * f
		add_theme_stylebox_override("panel", st)
		resized.connect(queue_redraw)

	func follow(g: Control) -> void:
		watch = g
		g.sort_children.connect(queue_redraw)

	## Where the watched grid's children sit, in this piece's own space.
	func _cells() -> Array:
		var out: Array = []
		if watch == null or not is_instance_valid(watch):
			return out
		var inv := get_global_transform().affine_inverse()
		for c in watch.get_children():
			if c is Control and c.visible:
				var gr: Rect2 = c.get_global_rect()
				out.append(Rect2(inv * gr.position, inv.basis_xform(gr.size)))
		return out

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		var r := Rect2(Vector2.ZERO, size)
		var BR := UI.TRAIN_BRASS
		var WAL := Color(0.3, 0.18, 0.11)
		match kind:
			"rack":
				# A walnut wardrobe: frame, dark velvet back, a faint mannequin, brass hooks.
				b.rect(r, UI.OUTLINE)
				b.rect(r.grow(-1.5), WAL.darkened(0.1))
				var inner := r.grow(-8.0)
				b.rect(inner, Color(0.12, 0.06, 0.07))
				var c := Vector2(inner.get_center().x, inner.position.y + inner.size.y * 0.3)
				var ghost := Color(0.24, 0.13, 0.13)
				b.dot(c + Vector2(0, -inner.size.y * 0.12), inner.size.x * 0.1, ghost)
				b.polygon(PackedVector2Array([c + Vector2(-inner.size.x * 0.3, 0), c + Vector2(inner.size.x * 0.3, 0),
					c + Vector2(inner.size.x * 0.2, inner.size.y * 0.5), c + Vector2(inner.size.x * 0.12, inner.size.y * 0.66),
					c + Vector2(-inner.size.x * 0.12, inner.size.y * 0.66), c + Vector2(-inner.size.x * 0.2, inner.size.y * 0.5)]), ghost)
				b.rect(Rect2(c.x - 2.0, c.y + inner.size.y * 0.66, 4.0, inner.size.y * 0.3), ghost)
				for i in 4:
					b.dot(Vector2(r.position.x + r.size.x * (0.2 + 0.2 * i), r.position.y + 5.0), 2.2, BR)
			"pack":
				# A leather pack: rounded body, a flap and two straps.
				var body := Rect2(r.position + Vector2(2, 8), r.size - Vector2(4, 10))
				b.rect(body.grow(1.5), UI.OUTLINE)
				b.rect(body, Color(0.36, 0.23, 0.14))
				b.rect(Rect2(body.position, Vector2(body.size.x, 12)), Color(0.42, 0.28, 0.17))
				b.rect(Rect2(body.position + Vector2(0, 12), Vector2(body.size.x, 2)), Color(0.22, 0.13, 0.08))
				for k in [0.22, 0.78]:
					var sx: float = body.position.x + body.size.x * k
					b.rect(Rect2(sx - 5, r.position.y, 10, 22), Color(0.26, 0.16, 0.09))
					b.rect(Rect2(sx - 6, r.position.y + 15, 12, 6), BR.darkened(0.2))
				_stitch(b, body.grow(-4.0), Color(0.62, 0.48, 0.3, 0.5))
			"chest":
				# An oak chest: planks, iron bands, brass corners and a lock plate.
				b.rect(r, UI.OUTLINE)
				b.rect(r.grow(-1.5), Color(0.44, 0.29, 0.16))
				var y := r.position.y + 6.0
				while y < r.end.y - 4.0:
					b.rect(Rect2(r.position.x + 2, y, r.size.x - 4, 1.2), Color(0.25, 0.15, 0.08))
					y += 14.0
				for k in [0.12, 0.88]:
					b.rect(Rect2(r.position.x + r.size.x * k - 4, r.position.y + 1.5, 8, r.size.y - 3), UI.TRAIN_IRON.lightened(0.2))
				for cx in [r.position.x + 1.5, r.end.x - 13.5]:
					for cy in [r.position.y + 1.5, r.end.y - 13.5]:
						b.rect(Rect2(cx, cy, 12, 12), BR.darkened(0.15))
				var lock := Vector2(r.get_center().x, r.end.y - 7.0)
				b.rect(Rect2(lock + Vector2(-8, -6), Vector2(16, 12)), BR)
				b.dot(lock, 2.2, UI.OUTLINE)
				for c in _cells():
					b.rect(c.grow(3.0), Color(0.18, 0.1, 0.05, 0.85))
			"shelf":
				# Shelves on the wall: a plank under each row, on brass brackets.
				b.rect(r, Color(0.2, 0.12, 0.08, 0.9))
				b.rect(Rect2(r.position, Vector2(r.size.x, 2)), WAL.lightened(0.15))
				var rows := {}
				for c in _cells():
					rows[int(c.end.y)] = true
				for ry in rows:
					var pl := Rect2(r.position.x + 2, ry + 1.0, r.size.x - 4, 5)
					b.rect(pl.grow(1.0), UI.OUTLINE)
					b.rect(pl, Color(0.5, 0.33, 0.19))
					b.rect(Rect2(pl.position, Vector2(pl.size.x, 1.5)), Color(0.62, 0.43, 0.26))
					for bx in [pl.position.x + 10, pl.end.x - 14]:
						b.polygon(PackedVector2Array([Vector2(bx, pl.end.y), Vector2(bx + 4, pl.end.y), Vector2(bx, pl.end.y + 7)]), BR.darkened(0.2))
			"rail":
				# The outfit rail: a brass rod with a hanger above each piece.
				b.rect(r, Color(0.12, 0.08, 0.06, 0.8))
				var rods := {}
				for c in _cells():
					rods[int(c.position.y) - 11] = true
				for ry in rods:
					b.line(Vector2(r.position.x + 4, ry), Vector2(r.end.x - 4, ry), UI.OUTLINE, 6.0)
					b.line(Vector2(r.position.x + 4, ry), Vector2(r.end.x - 4, ry), BR, 3.5)
					b.rect(Rect2(r.position.x + 4, ry - 1.5, r.size.x - 8, 1.0), BR.lightened(0.3))
				for c in _cells():
					var hx: float = c.get_center().x
					var ry: float = c.position.y - 11.0
					var steel := Color(0.72, 0.72, 0.78)
					b.arc(Vector2(hx, ry - 1.0), 3.0, PI * 0.9, TAU * 1.05, 8, steel, 1.4)
					b.line(Vector2(hx, ry + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
					b.line(Vector2(hx - c.size.x * 0.34, c.position.y + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
					b.line(Vector2(hx + c.size.x * 0.34, c.position.y + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
			"case":
				# A glass case on a walnut plinth, brass at the edges.
				var plinth := Rect2(r.position.x, r.end.y - 12.0, r.size.x, 12.0)
				b.rect(plinth.grow(1.0), UI.OUTLINE)
				b.rect(plinth, WAL)
				b.rect(Rect2(plinth.position, Vector2(plinth.size.x, 2)), WAL.lightened(0.2))
				var glass := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y - 16))
				b.rect(glass, Color(0.6, 0.75, 0.85, 0.1))
				b.rect(Rect2(glass.position, Vector2(glass.size.x, 2)), BR)
				b.rect(Rect2(glass.position, Vector2(2, glass.size.y)), BR.darkened(0.2))
				b.rect(Rect2(glass.end.x - 2, glass.position.y, 2, glass.size.y), BR.darkened(0.2))
				b.polygon(PackedVector2Array([glass.position + Vector2(6, 4), glass.position + Vector2(14, 4), glass.position + Vector2(6, glass.size.y * 0.7)]), Color(1, 1, 1, 0.12))
			"board":
				# The destination board: slate in a brass frame.
				b.rect(r, UI.OUTLINE)
				b.rect(r.grow(-1.5), BR.darkened(0.25))
				b.rect(r.grow(-5.0), Color(0.07, 0.11, 0.1))
				for cx in [r.position.x + 8, r.end.x - 8]:
					for cy in [r.position.y + 8, r.end.y - 8]:
						b.dot(Vector2(cx, cy), 2.4, BR.lightened(0.15))
			"drawers":
				# The bench's cabinet: a walnut case of labelled drawers.
				b.rect(r, UI.OUTLINE)
				b.rect(r.grow(-1.5), WAL)
				for c in _cells():
					b.rect(c.grow(2.0), WAL.darkened(0.35))
			"placard":
				# A walnut placard in a brass frame, riveted at the corners.
				b.rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
				b.rect(r, UI.OUTLINE)
				b.rect(r.grow(-1.0), BR.darkened(0.2))
				b.rect(r.grow(-3.5), Color(0.1, 0.075, 0.06, 0.97))
				b.rect(Rect2(r.position + Vector2(3.5, 3.5), Vector2(r.size.x - 7, 1.0)), Color(BR, 0.35))
				for cx in [r.position.x + 7, r.end.x - 7]:
					for cy in [r.position.y + 7, r.end.y - 7]:
						b.dot(Vector2(cx, cy), 2.2, BR.lightened(0.1))
			_:
				b.rect(r, Color(0.08, 0.06, 0.05, 0.75))
		b.flush(self)

	func _stitch(b, r: Rect2, col: Color) -> void:
		var x := r.position.x
		while x < r.end.x:
			b.rect(Rect2(x, r.position.y, 4, 1), col)
			b.rect(Rect2(x, r.end.y, 4, 1), col)
			x += 8.0


## The outfitter behind his counter, drawn in code: an old climber with his
## goggles pushed up, a grey moustache, a brass-buttoned coat and his arms
## on the counter. He blinks now and then.
class Outfitter extends Control:
	const UI := preload("res://scripts/ui.gd")
	const COAT := Color(0.32, 0.2, 0.14)
	var t := 0.0
	var open := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		var o := fmod(t, 5.1) > 0.13
		if o != open:
			open = o
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := minf(w * 0.3, h * 0.26)
		var c := Vector2(w * 0.5, h * 0.36)
		var b := UI.Draw.Batch.new()
		UI.glow_into(b, c, r * 2.2, UI.TRAIN_WINDOW, 0.5)
		# Shoulders and coat, down to the counter.
		var top := c.y + r * 0.7
		b.poly(PackedVector2Array([Vector2(c.x - r * 1.7, h * 0.86), Vector2(c.x - r * 1.45, top + r * 0.3), Vector2(c.x - r * 0.6, top),
			Vector2(c.x + r * 0.6, top), Vector2(c.x + r * 1.45, top + r * 0.3), Vector2(c.x + r * 1.7, h * 0.86)]), COAT, 1.4)
		b.polygon(PackedVector2Array([Vector2(c.x - r * 0.35, top), Vector2(c.x + r * 0.35, top), Vector2(c.x, top + r * 0.9)]), Color(0.86, 0.82, 0.74))
		for i in 3:
			b.dot(Vector2(c.x + r * 0.42, top + r * (0.5 + 0.38 * i)), r * 0.06, UI.TRAIN_BRASS)
		OutfitterFace.head_into(b, c, r, open)
		# The counter he leans on: oak with a brass edge, his hands on it.
		var counter := Rect2(0, h * 0.82, w, h * 0.18)
		b.rect(counter.grow(1.0), UI.OUTLINE)
		b.rect(counter, Color(0.44, 0.29, 0.16))
		b.rect(Rect2(counter.position, Vector2(w, 4.0)), UI.TRAIN_BRASS.darkened(0.1))
		for side in [-1.0, 1.0]:
			b.ball(Vector2(c.x + side * r * 0.9, h * 0.82), r * 0.22, OutfitterFace.SKIN)
		b.flush(self)


## The outfitter's face, small, beside what he says: drawn in code.
class OutfitterFace extends Control:
	const BRASS := Color(0.86, 0.64, 0.3)
	const SKIN := Color(0.86, 0.68, 0.54)
	const HAIR := Color(0.78, 0.76, 0.74)
	const COAT := Color(0.32, 0.2, 0.14)
	const UI := preload("res://scripts/ui.gd")
	var t := 0.0
	var open := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		var o := fmod(t, 5.1) > 0.13
		if o != open:
			open = o
			queue_redraw()

	## His head: grey hair at the sides, goggles pushed up on his brow,
	## eyes (half shut while blinking), a big nose and a grey moustache.
	static func head_into(b, c: Vector2, r: float, eyes_open: bool) -> void:
		b.ball(c + Vector2(0, -r * 0.05), r * 0.62, SKIN)
		b.dot(c + Vector2(-r * 0.56, -r * 0.08), r * 0.18, HAIR)
		b.dot(c + Vector2(r * 0.56, -r * 0.08), r * 0.18, HAIR)
		b.rect(Rect2(c + Vector2(-r * 0.62, -r * 0.5), Vector2(r * 1.24, r * 0.14)), Color(0.22, 0.14, 0.1))
		for side in [-1.0, 1.0]:
			var g := c + Vector2(side * r * 0.24, -r * 0.44)
			b.dot(g, r * 0.2, Color(0.1, 0.08, 0.06))
			b.arc(g, r * 0.2, 0.0, TAU, 14, BRASS, maxf(1.2, r * 0.08))
			b.dot(g + Vector2(-r * 0.06, -r * 0.06), r * 0.05, Color(0.8, 0.9, 1.0, 0.7))
		var k := 1.0 if eyes_open else 0.2
		for side in [-1.0, 1.0]:
			b.rect(Rect2(c + Vector2(side * r * 0.22 - r * 0.06, -r * 0.12 - r * 0.04 * k), Vector2(r * 0.12, r * 0.08 * k + 0.6)), Color(0.12, 0.08, 0.06))
		b.dot(c + Vector2(0, r * 0.08), r * 0.1, SKIN.darkened(0.15))
		b.polygon(PackedVector2Array([c + Vector2(-r * 0.42, r * 0.3), c + Vector2(-r * 0.1, r * 0.16), c + Vector2(0, r * 0.22),
			c + Vector2(r * 0.1, r * 0.16), c + Vector2(r * 0.42, r * 0.3), c + Vector2(r * 0.2, r * 0.3), c + Vector2(0, r * 0.26),
			c + Vector2(-r * 0.2, r * 0.3)]), HAIR)

	func _draw() -> void:
		var r := minf(size.x - 12.0, size.y) * 0.42
		var c := Vector2(r * 1.2, size.y * 0.5)
		var b := UI.Draw.Batch.new()
		UI.glow_into(b, c, r * 1.5, BRASS, 0.8)
		b.polygon(PackedVector2Array([c + Vector2(-r * 0.95, r * 1.15), c + Vector2(-r * 0.7, r * 0.55), c + Vector2(r * 0.7, r * 0.55), c + Vector2(r * 0.95, r * 1.15)]), COAT)
		b.dot(c + Vector2(-r * 0.2, r * 0.82), r * 0.07, BRASS)
		b.dot(c + Vector2(r * 0.2, r * 0.82), r * 0.07, BRASS)
		head_into(b, c, r, open)
		b.flush(self)
		var tip := Vector2(size.x, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(1, -7), tip + Vector2(-9, 0), tip + Vector2(1, 7)]), Color(0.13, 0.095, 0.06, 0.95))


# --- the chrome: over the cars ------------------------------------------------------------

## The engine's regulator: pull it to depart. A brass quadrant, the lever
## and its red knob, and the word under it.
class Lever extends Button:
	const UI := preload("res://scripts/ui.gd")
	var word := "DEPART"
	var sub := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(st, empty)
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.border_color = UI.GOLD
		f.set_border_width_all(2)
		f.set_corner_radius_all(8)
		f.set_expand_margin_all(2)
		add_theme_stylebox_override("focus", f)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var h := size.y
		var hot := is_hovered() or has_focus()
		var down := is_pressed()
		var b := UI.Draw.Batch.new()
		var plate := Rect2(4, 4, w - 8, h - (44 if sub != "" else 30))
		b.rect(plate.grow(1.5), UI.OUTLINE)
		b.rect(plate, UI.TRAIN_IRON.lightened(0.12))
		var pivot := Vector2(w * 0.5, plate.end.y - 10.0)
		var rad := minf(plate.size.x * 0.42, plate.size.y * 0.78)
		b.arc(pivot, rad, PI * 1.12, PI * 1.88, 16, UI.OUTLINE, 9.0)
		b.arc(pivot, rad, PI * 1.12, PI * 1.88, 16, UI.TRAIN_BRASS.lightened(0.15 if hot else 0.0), 6.0)
		for i in 5:
			var a := lerpf(PI * 1.15, PI * 1.85, i / 4.0)
			b.dot(pivot + Vector2.from_angle(a) * rad, 2.2, UI.OUTLINE)
		var ang := PI * (1.72 if down else 1.3)
		var tip := pivot + Vector2.from_angle(ang) * rad * 1.02
		b.stroke(pivot, tip, UI.TRAIN_IRON.lightened(0.45), 5.0)
		b.ball(tip, 8.0, Color(0.75, 0.16, 0.12) if not hot else Color(0.9, 0.24, 0.16))
		b.ball(pivot, 7.0, UI.TRAIN_BRASS)
		b.flush(self)
		draw_string(font, Vector2(0, plate.end.y + 19.0), word, HORIZONTAL_ALIGNMENT_CENTER, w, 16, UI.GOLD if not disabled else UI.FAINT)
		if sub != "":
			draw_string(font, Vector2(0, plate.end.y + 34.0), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(UI.TEXT, 0.85))


## An arrow at the edge of the screen to the next car: a brass tab with a
## chevron, and the car's name under it.
class EdgeArrow extends Button:
	const UI := preload("res://scripts/ui.gd")
	var dir := 1
	var car_name := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		text = ""
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var hot := is_hovered()
		var b := UI.Draw.Batch.new()
		var c := Vector2(w * 0.5, w * 0.62)
		b.dot(c, w * 0.44 + 1.5, UI.OUTLINE)
		b.dot(c, w * 0.44, Color(0.12, 0.09, 0.07, 0.92))
		b.arc(c, w * 0.44 - 1.0, 0.0, TAU, 28, UI.TRAIN_BRASS.lightened(0.2 if hot else 0.0), 2.0)
		var k := w * 0.14 * dir
		var col := UI.GOLD if hot else UI.TRAIN_BRASS.lightened(0.1)
		b.line(c + Vector2(-k, -w * 0.18), c + Vector2(k, 0), col, 3.5)
		b.line(c + Vector2(k, 0), c + Vector2(-k, w * 0.18), col, 3.5)
		b.dot(c + Vector2(k, 0), 1.75, col)
		b.flush(self)
		var lines := car_name.split(" ")
		var y := c.y + w * 0.44 + 14.0
		for l in lines:
			draw_string_outline(font, Vector2(-8, y), l, HORIZONTAL_ALIGNMENT_CENTER, w + 16.0, 11, 4, Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(-8, y), l, HORIZONTAL_ALIGNMENT_CENTER, w + 16.0, 11, Color(UI.TEXT, 0.9))
			y += 12.0


## The brass bands along the top (the cars' names) and the bottom (your
## crystals): riveted brass over dark wood.
class Band extends Control:
	const UI := preload("res://scripts/ui.gd")
	var at_top := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		var r := Rect2(Vector2.ZERO, size)
		b.rect(r, Color(0.09, 0.065, 0.05, 0.96))
		var edge_y := size.y - 3.0 if at_top else 0.0
		b.rect(Rect2(0, edge_y, size.x, 3.0), UI.TRAIN_BRASS.darkened(0.15))
		b.rect(Rect2(0, edge_y + (2.0 if at_top else 0.0), size.x, 1.0), UI.TRAIN_BRASS.lightened(0.25))
		var y := size.y - 9.0 if at_top else 9.0
		var x := 14.0
		while x < size.x:
			b.dot(Vector2(x, y), 1.6, UI.TRAIN_BRASS.darkened(0.35))
			x += 64.0
		b.flush(self)


## Under the cars' names: a gold bar that slides along with the train, so
## you can see where you are (and where you're going) mid-scroll.
class Marker extends Control:
	const UI := preload("res://scripts/ui.gd")
	var view
	var slots: Array = []  # each name's button
	var _drawn := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if view != null and view.pos != _drawn:
			queue_redraw()

	func _draw() -> void:
		if view == null or slots.is_empty():
			return
		_drawn = view.pos
		var inv := get_global_transform().affine_inverse()
		var rects: Array = []
		for s in slots:
			if not is_instance_valid(s):
				return
			var gr: Rect2 = s.get_global_rect()
			rects.append(Rect2(inv * gr.position, inv.basis_xform(gr.size)))
		var p := clampf(view.pos, 0.0, rects.size() - 1.0)
		var i := int(floor(p))
		var j := mini(i + 1, rects.size() - 1)
		var k := p - i
		var a: Rect2 = rects[i]
		var c: Rect2 = rects[j]
		var x := lerpf(a.position.x, c.position.x, k)
		var w := lerpf(a.size.x, c.size.x, k)
		draw_rect(Rect2(x + 10.0, a.end.y - 4.0, w - 20.0, 3.0), UI.GOLD)


# --- the workshop's bench ----------------------------------------------------------

## The workshop car's corner, drawn in code over its counters: the car's panelled
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
	var _acc := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		_acc += delta
		# (the flask's steam and the slate's glow: a few times a second, and
		# only while it's on screen)
		if _acc < 1.0 / 12.0 or not is_visible_in_tree():
			return
		_acc = 0.0
		if get_global_rect().intersects(get_viewport_rect()):
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
