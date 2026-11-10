extends Control
## The train between climbs, drawn in code from the inside: menu.gd's
## "train" page. Its cars stand side by side in one long strip, each as wide
## as the view (the screen right of the menu's rail): the engine at the
## front (left), then your car, the store car and the workshop. Scrolling
## slides the strip (train_page.gd moves it and puts each car's things in
## its room).
##
## Each room is drawn in layers, back to front: its walls, panelling, floor
## and the dusk in its windows; the view outside (the stars and the moon,
## the six towers and far hills, nearer hills and drifting mist); the window
## frames, curtains, ceiling and the car's own fittings; the lamplight and
## firelight, added on so it warms what it falls on; what moves (the lamps
## swinging, the gauges, the firebox); and the sparks of light that move
## with them (the lamps' glow, dust drifting in it).
##
## Kept light for phones: almost everything is drawn once (again only when
## the screen changes size). The view outside is clipped to each window's
## frame and drawn once too: walking along only slides its layers (the far
## towers slower than the near hills, the stars not at all), and the mist
## drifts the same way. The light only brightens and dims. Only the small
## moving things are redrawn, a few times a second, for the cars on screen.
## Colours and drawing helpers are in train_art.gd; the cars' names and
## words in train.gd.

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")

## Below this screen height (a phone) the margins tighten (menu.gd COMPACT_H).
const COMPACT_H := 600.0
## The room kept clear at the top (under the ceiling), the bottom (the band
## of your crystals) and the sides: [phone, desktop]. (The cars' names and
## the way along the train are on the rail, rail.gd.)
const TOP := [6.0, 10.0]
const BOTTOM := [46.0, 56.0]
const SIDE := [12.0, 22.0]
const LIVE_FPS := 15.0  # how often the lamps, gauges, firebox and their sparks are redrawn
const MIST_PERIOD := 240.0  # the mist repeats every this many (scaled) pixels, so it can drift for ever
const CLOUD_PERIOD := 560.0  # and the clouds every this many
const EASE := 13.0  # how quickly the train settles on a car (higher: quicker)

## How far each part of the view outside slides as you walk along the
## train: 0 stays put on screen (the stars and the moon), 1 moves with the car.
const FAR_SLIDE := 0.15  # the towers and the far hills
const NEAR_SLIDE := 0.4  # the nearer hills
## Where the six towers stand along the horizon (in screen widths, in
## Towers.ORDER): placed so each car's windows show two or three of them.
const TOWER_AT := [0.344, 0.631, 0.854, 0.975, 1.144, 1.307]
## Each tower's outline on the horizon (base at 0, up is negative; scaled by
## the room), its lit windows, and the light at its top.
const TOWER_SHAPE := [
	# The Gryphon's: slender, with a tall pointed roof.
	[[Vector2(-7, 0), Vector2(-6, -66), Vector2(-9, -68), Vector2(0, -104), Vector2(9, -68), Vector2(6, -66), Vector2(7, 0)],
		[Vector2(0, -24), Vector2(0, -46)], Vector2(0, -60)],
	# The Kraken's: broad tiers under a dome.
	[[Vector2(-14, 0), Vector2(-13, -36), Vector2(-9, -38), Vector2(-8, -60), Vector2(-6, -66), Vector2(-3, -69), Vector2(0, -70),
		Vector2(3, -69), Vector2(6, -66), Vector2(8, -60), Vector2(9, -38), Vector2(13, -36), Vector2(14, 0)],
		[Vector2(-5, -20), Vector2(5, -20), Vector2(0, -46)], Vector2(0, -56)],
	# The Wyvern's: a square keep with battlements.
	[[Vector2(-11, 0), Vector2(-11, -64), Vector2(-13, -64), Vector2(-13, -73), Vector2(-8, -73), Vector2(-8, -69), Vector2(-3, -69),
		Vector2(-3, -73), Vector2(3, -73), Vector2(3, -69), Vector2(8, -69), Vector2(8, -73), Vector2(13, -73), Vector2(13, -64),
		Vector2(11, -64), Vector2(11, 0)],
		[Vector2(-4, -22), Vector2(4, -40), Vector2(-4, -52)], Vector2(0, -60)],
	# The Manticore's: massive, stepped.
	[[Vector2(-17, 0), Vector2(-16, -26), Vector2(-11, -27), Vector2(-10, -50), Vector2(-6, -51), Vector2(-5, -72), Vector2(0, -79),
		Vector2(5, -72), Vector2(6, -51), Vector2(10, -50), Vector2(11, -27), Vector2(16, -26), Vector2(17, 0)],
		[Vector2(-8, -16), Vector2(8, -16), Vector2(0, -38)], Vector2(0, -62)],
	# The Firebird's: a flared crown like a brazier.
	[[Vector2(-9, 0), Vector2(-6, -62), Vector2(-12, -71), Vector2(-7, -73), Vector2(-4, -84), Vector2(0, -76), Vector2(4, -84),
		Vector2(7, -73), Vector2(12, -71), Vector2(6, -62), Vector2(9, 0)],
		[Vector2(0, -22), Vector2(0, -42)], Vector2(0, -68)],
	# The Chimera's: crooked, horned.
	[[Vector2(-11, 0), Vector2(-9, -50), Vector2(-12, -57), Vector2(-16, -73), Vector2(-8, -61), Vector2(-4, -67), Vector2(-1, -90),
		Vector2(3, -66), Vector2(8, -61), Vector2(15, -77), Vector2(11, -57), Vector2(8, -50), Vector2(10, 0)],
		[Vector2(-3, -20), Vector2(2, -40)], Vector2(-1, -64)],
]
## The moon: where it hangs on screen (x in screen widths; y as a share of
## the sky in the windows), and its size.
const MOON_AT := Vector2(0.152, 0.22)
const MOON_R := 11.0

## The screen changed size (the cars' things are built again for it).
signal laid_out

var strip: Control  # the cars, side by side
var rooms := {}  # car id -> Room
var chrome: Control  # over the cars: the band of your crystals (train_page.gd)
var inset := 0.0  # the menu's rail down the left (rail.gd): the cars fill the rest
var pos := 1.0  # where the train stands, in cars (0 = the engine)
var target := 1  # the car it settles on
var dragging := false  # a finger or the mouse holds it
var fit_frames := 0  # the cars' things are fitted to their rooms for a few frames after a build
var small := false
var t := 0.0
var live_acc := 0.0
var fit_hook := Callable()  # (train_page.gd: the placards fitted to what they say)
var _laid_for := Vector2.ZERO
var _stars: Array = []  # [x share of the screen, y share of the sky, size, which of two twinkling sets]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # (the cars slide under the rail's edge, not over it)
	for i in 70:
		_stars.append([Art.rnd(i * 3 + 1), pow(Art.rnd(i * 5 + 2), 1.4) * 0.9, 0.6 + 0.9 * pow(Art.rnd(i * 7 + 3), 3.0), i % 2])
	strip = Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var list := ids()
	for i in list.size():
		var r := Room.new(list[i], i, self)
		rooms[list[i]] = r
		strip.add_child(r)
	chrome = Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chrome)
	_lay_out()


func ids() -> Array:
	return Train.CARS.map(func(c): return c[0])


func _size() -> Vector2:
	return get_viewport_rect().size - Vector2(inset, 0.0)


## Leaves `x` clear down the left for the rail (laid out again if it changed).
func set_inset(x: float) -> void:
	if x == inset:
		return
	inset = x
	offset_left = x
	refresh()


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
		for l in r.layers():
			l.size = s
		r.area.position = Vector2(mg.z, mg.x)
		r.area.size = Vector2(s.x - mg.z * 2.0, s.y - mg.x - mg.y)
		_geometry(r)
		_build_views(r)
		r.redraw()
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
	for r in rooms.values():
		if absf(r.index - pos) < 1.0:
			_slide(r)


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
	live_acc += delta
	var live := live_acc >= 1.0 / LIVE_FPS
	if live:
		live_acc = 0.0
	for r in rooms.values():
		if absf(r.index - pos) >= 1.0:
			continue
		# (cheap every frame: the mist slides, the stars and the light brighten and dim)
		_slide(r)
		_breathe(r)
		if live:
			r.live.queue_redraw()
			r.sparks.queue_redraw()


## Takes away every car's things and the chrome (train_page.gd builds them again).
func clear_content() -> void:
	for r in rooms.values():
		for c in r.area.get_children():
			r.area.remove_child(c)
			c.queue_free()
	for c in chrome.get_children():
		chrome.remove_child(c)
		c.queue_free()
	fit_frames = 3


## A car's room: its layers (see the top of this file) and an area (inside
## the margins) for its things. Where its windows, lamps and fittings stand
## is worked out as it's laid out (TrainView._geometry).
class Room extends Control:
	var car := ""
	var index := 0
	var view
	var outside: Control  # the view through the windows (a clipped box of layers for each)
	var front: Control  # window frames, curtains, the ceiling, the car's fittings
	var glow: Control  # the lamplight and firelight (added on; drawn once, it brightens and dims)
	var live: Control  # what moves: the lamps, the gauges, the firebox
	var sparks: Control  # light that moves with them (added on)
	var area: Control
	var u := 1.0  # the room's scale (1 at 720 high)
	var ceil_y := 0.0
	var wain := 0.0  # the brass rail between the wall and the panelling
	var floor_y := 0.0
	var top := 0.0  # the windows' top
	var horizon := 0.0
	var wins: Array = []  # each: {"round", "rect", "glass", and "c", "rad" if round}
	var views: Array = []  # each window's layers outside, by name (_build_views)
	var lamps: Array = []  # where each lamp hangs from the ceiling
	var chain := 20.0  # how long the lamps' chains are
	var fire := Rect2()  # the engine's firebox door
	var gauges: Array = []  # the engine's gauges: [centre, radius]
	var steam := Vector2.ZERO  # the engine's steam valve

	func _init(id: String, i: int, v) -> void:
		car = id
		index = i
		view = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		outside = Control.new()
		outside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(outside)
		front = _layer(view.paint_front)
		glow = _layer(view.paint_glow)
		live = _layer(view.paint_live)
		sparks = _layer(view.paint_sparks)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		sparks.material = add
		area = Control.new()
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(area)

	func _layer(paint: Callable) -> Control:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func(): paint.call(self))
		add_child(c)
		return c

	func layers() -> Array:
		return [outside, front, glow, live, sparks]

	func redraw() -> void:
		queue_redraw()
		for l in layers():
			l.queue_redraw()

	func _draw() -> void:
		view.paint_room(self)

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


# --- where things stand -------------------------------------------------------------

func _geometry(r: Room) -> void:
	var s := r.size
	var u := maxf(0.5, s.y / 720.0)
	var mg := margins()
	r.u = u
	r.ceil_y = mg.x + 4.0 * u
	r.wain = s.y * 0.6
	r.floor_y = s.y - mg.y - 46.0 * u
	r.top = r.ceil_y + 18.0 * u
	var bottom := r.wain - 26.0 * u
	r.wins.clear()
	r.lamps.clear()
	r.gauges.clear()
	r.fire = Rect2()
	r.chain = 20.0 * u
	if r.car == "engine":
		# Round spectacle glasses, high in the cab's front wall.
		var rad := minf(58.0 * u, (bottom - r.top) * 0.42)
		var cy := r.top + rad + 6.0 * u
		r.top = cy - rad
		r.horizon = cy + rad * 0.3
		for fx in [0.14, 0.86]:
			var c := Vector2(s.x * fx, cy)
			r.wins.append({"round": true, "c": c, "rad": rad, "rect": Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), "glass": Art.oval(c, Vector2(rad, rad), 40)})
		for fx in [0.33, 0.67]:
			r.lamps.append(Vector2(s.x * fx, r.ceil_y + 30.0 * u))
		r.chain = 10.0 * u
		var g := Vector2(s.x * 0.5, r.ceil_y + 70.0 * u)
		r.gauges = [[g, 24.0 * u], [g + Vector2(-50.0, 6.0) * u, 15.0 * u], [g + Vector2(50.0, 6.0) * u, 15.0 * u]]
		r.steam = Vector2(s.x * 0.6, r.ceil_y + 10.0 * u)
		r.fire = Rect2(Vector2(s.x * 0.5 - 40.0 * u, r.floor_y - 74.0 * u), Vector2(80.0, 48.0) * u)
	else:
		r.horizon = r.top + (bottom - r.top) * 0.37
		var w := 132.0 * u
		for fx in [0.17, 0.5, 0.83]:
			var rect := Rect2(s.x * fx - w * 0.5, r.top, w, bottom - r.top)
			r.wins.append({"round": false, "rect": rect, "glass": _arch(rect)})
		for fx in [0.335, 0.665]:
			r.lamps.append(Vector2(s.x * fx, r.ceil_y))


## An arched window's glass: a half circle over a rectangle.
static func _arch(rect: Rect2) -> PackedVector2Array:
	var half := rect.size.x * 0.5
	var c := Vector2(rect.get_center().x, rect.position.y + half)
	var pts := PackedVector2Array()
	for k in 21:
		pts.append(c + Vector2.from_angle(PI + PI * k / 20.0) * half)
	pts.append(rect.end)
	pts.append(Vector2(rect.position.x, rect.end.y))
	return pts


## How wide a window's glass is at height y: [left, right].
static func _span(win: Dictionary, y: float) -> Vector2:
	if win["round"]:
		var c: Vector2 = win["c"]
		var h := sqrt(maxf(0.0, win["rad"] * win["rad"] - (y - c.y) * (y - c.y)))
		return Vector2(c.x - h, c.x + h)
	var rect: Rect2 = win["rect"]
	var half := rect.size.x * 0.5
	var cy := rect.position.y + half
	var w := half if y >= cy else sqrt(maxf(0.0, half * half - (cy - y) * (cy - y)))
	return Vector2(rect.get_center().x - w, rect.get_center().x + w)


## Where a lamp's body hangs as it swings, and its angle.
func _lamp_at(r: Room, i: int) -> Array:
	var a := 0.05 * sin(t * 1.15 + i * 1.7 + r.index * 0.9) + 0.012 * sin(t * 2.7 + i * 2.3)
	var hang: Vector2 = r.lamps[i]
	return [hang + Vector2(-sin(a), cos(a)) * (r.chain + 13.0 * r.u), a]


# --- the rooms: drawn once ------------------------------------------------------------

## Behind everything: the wall, the dusk in the windows, the panelling and the floor.
func paint_room(r: Room) -> void:
	var b := UI.Draw.Batch.new()
	_wall(b, r)
	for win in r.wins:
		_sky(b, r, win)
	_panelling(b, r)
	_floor(b, r)
	b.flush(r)


func _wall(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var wall := Rect2(0, 0, s.x, r.wain)
	var skip := func(p: Vector2) -> bool:
		for win in r.wins:
			if win["rect"].grow(4.0 * u).has_point(p):
				return true
		return false
	match r.car:
		"engine":
			# Riveted steel plates, lit from above, with streaks of soot.
			Art.vgrad(b, wall, Art.STEEL.lightened(0.04), Art.STEEL.darkened(0.25))
			var pw := 150.0 * u
			var rows := [r.ceil_y, lerpf(r.ceil_y, r.wain, 0.5), r.wain]
			var x := -20.0 * u
			var n := 0
			while x < s.x:
				for k in 2:
					var pr := Rect2(x, rows[k], pw, rows[k + 1] - rows[k])
					Art.vgrad(b, pr.grow(-1.0 * u), Art.STEEL.lightened(0.06 - 0.03 * k), Art.STEEL.darkened(0.12 + 0.08 * k))
					b.rect(Rect2(pr.position, Vector2(pr.size.x, 1.2 * u)), Color(Art.STEEL.lightened(0.35), 0.5))
					b.rect(Rect2(pr.position.x, pr.end.y - 1.5 * u, pr.size.x, 1.5 * u), Color(0, 0, 0, 0.5))
					b.rect(Rect2(pr.end.x - 1.5 * u, pr.position.y, 1.5 * u, pr.size.y), Color(0, 0, 0, 0.45))
					Art.rivets(b, pr.position + Vector2(8, 7) * u, Vector2(pr.end.x - 8.0 * u, pr.position.y + 7.0 * u), 22.0 * u, 1.7 * u, Art.STEEL.lightened(0.5))
					if Art.rnd(n * 5 + k) > 0.5:
						var sx := pr.position.x + pr.size.x * (0.2 + 0.6 * Art.rnd(n + k * 11))
						Art.vgrad(b, Rect2(sx, pr.position.y + 10.0 * u, (6.0 + 10.0 * Art.rnd(n + 3)) * u, pr.size.y * 0.7), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.0))
				x += pw
				n += 1
		"personal":
			# Plum velvet, quilted with gilt buttons, in walnut-framed bays.
			Art.vgrad(b, wall, Art.PLUM.lightened(0.05), Art.PLUM.darkened(0.2))
			var gap := 38.0 * u
			var row := 0
			var y := r.ceil_y + gap * 0.3
			while y < r.wain - 6.0 * u:
				var x := gap * 0.5 * (row % 2)
				while x < s.x + gap:
					var p := Vector2(x, y)
					if not skip.call(p):
						b.line(p, p + Vector2(gap * 0.5, gap * 0.5), Color(0, 0, 0, 0.28), 1.3 * u)
						b.line(p, p + Vector2(-gap * 0.5, gap * 0.5), Color(0, 0, 0, 0.28), 1.3 * u)
						b.line(p + Vector2(0, 1.5 * u), p + Vector2(gap * 0.5, gap * 0.5 + 1.5 * u), Color(Art.PLUM.lightened(0.3), 0.12), 1.0 * u)
						b.circle(p, 3.2 * u, Art.PLUM.darkened(0.5), 8)
						b.circle(p, 1.5 * u, Art.GILT.darkened(0.25), 6)
						b.circle(p - Vector2(0.5, 0.5) * u, 0.7 * u, Art.GILT_HI, 4)
					x += gap
				y += gap * 0.5
				row += 1
			_bays(b, r, Art.WALNUT)
		"store":
			# Bottle-green damask: gilt pinstripes and a small motif between.
			Art.vgrad(b, wall, Art.GREEN.lightened(0.05), Art.GREEN.darkened(0.25))
			var x := 17.0 * u
			var i := 0
			while x < s.x:
				b.rect(Rect2(x, r.ceil_y, 1.2 * u, r.wain - r.ceil_y), Color(Art.GILT, 0.13))
				var y := r.ceil_y + 30.0 * u + (17.0 * u if i % 2 == 0 else 0.0)
				while y < r.wain - 10.0 * u:
					var p := Vector2(x + 17.0 * u, y)
					if not skip.call(p):
						var d := 5.0 * u
						b.polygon(PackedVector2Array([p + Vector2(0, -d * 1.4), p + Vector2(d * 0.7, 0), p + Vector2(0, d * 1.4), p + Vector2(-d * 0.7, 0)]), Color(Art.GILT, 0.07))
						b.circle(p, 1.0 * u, Color(Art.GILT, 0.2), 6)
					y += 34.0 * u
				x += 34.0 * u
				i += 1
			_bays(b, r, Art.OAK.darkened(0.35))
		"workshop":
			# Upright boards, grained, with a knot here and there and nail heads.
			var bw := 30.0 * u
			var x := 0.0
			var i := 0
			while x < s.x:
				var col := Art.BOARDS.lightened(0.04 * (i % 3)).darkened(0.05 * ((i * 7) % 2))
				var br := Rect2(x, 0, bw, r.wain)
				Art.vgrad(b, br, col.lightened(0.05), col.darkened(0.25))
				Art.grain(b, br.grow(-1.5 * u), col, i * 17 + 3, u, true)
				b.rect(Rect2(x, 0, 1.6 * u, r.wain), Color(0, 0, 0, 0.55))
				b.rect(Rect2(x + 1.6 * u, 0, 1.0 * u, r.wain), Color(col.lightened(0.25), 0.3))
				for ny in [r.ceil_y + 12.0 * u, r.wain - 14.0 * u]:
					b.circle(Vector2(x + bw * 0.5, ny), 1.5 * u, Color(0.1, 0.08, 0.08), 8)
					b.circle(Vector2(x + bw * 0.5 - 0.4 * u, ny - 0.4 * u), 0.6 * u, Color(0.6, 0.55, 0.5, 0.6), 6)
				x += bw
				i += 1
	# The shadow under the cornice.
	Art.vgrad(b, Rect2(0, r.ceil_y, s.x, 40.0 * u), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))


## The wall between the windows framed in mouldings (your car, the store).
func _bays(b, r: Room, wood: Color) -> void:
	var u := r.u
	var edges: Array = [16.0 * u]
	for win in r.wins:
		edges.append(win["rect"].position.x - 12.0 * u)
		edges.append(win["rect"].end.x + 12.0 * u)
	edges.append(r.size.x - 16.0 * u)
	for i in range(0, edges.size(), 2):
		var x0: float = edges[i] + 14.0 * u
		var x1: float = edges[i + 1] - 14.0 * u
		if x1 - x0 < 30.0 * u:
			continue
		var bay := Rect2(x0, r.top + 6.0 * u, x1 - x0, r.wain - r.top - 22.0 * u)
		Art.moulding(b, bay, u, Art.GILT, 0.35)
		Art.moulding(b, bay.grow(-7.0 * u), u, wood.lightened(0.3), 0.3)


## The dusk in a window: dark above, warm at the horizon, the land below.
func _sky(b, r: Room, win: Dictionary) -> void:
	var rect: Rect2 = win["rect"]
	var levels: Array = []
	for k in 25:
		levels.append(lerpf(rect.position.y, rect.end.y, k / 24.0))
	var hgt := r.horizon - r.top
	for h in [0.45, 0.1]:
		levels.append(r.horizon - hgt * h)
	levels.append(r.horizon - 0.01)
	levels.append(r.horizon)
	levels.append(r.horizon + 30.0 * r.u)
	levels = levels.filter(func(y): return y >= rect.position.y and y <= rect.end.y)
	levels.sort()
	for i in levels.size() - 1:
		var y0: float = levels[i]
		var y1: float = levels[i + 1]
		if y1 - y0 < 0.05:
			continue
		var s0 := _span(win, y0)
		var s1 := _span(win, y1)
		var c0 := _sky_col(r, y0, y1 > r.horizon + 0.001)
		var c1 := _sky_col(r, y1, y1 > r.horizon + 0.001)
		Art.quad(b, Vector2(s0.x, y0), Vector2(s0.y, y0), Vector2(s1.y, y1), Vector2(s1.x, y1), c0, c0, c1, c1)


func _sky_col(r: Room, y: float, below: bool) -> Color:
	if below:
		var k := clampf((y - r.horizon) / (30.0 * r.u), 0.0, 1.0)
		return Art.GROUND.lerp(Art.SKY[2].darkened(0.3), 0.4 * (1.0 - k))
	var h := clampf((r.horizon - y) / maxf(r.horizon - r.top, 1.0), 0.0, 1.0)
	if h < 0.1:
		return Art.SKY[3].lerp(Art.SKY[2], h / 0.1)
	if h < 0.45:
		return Art.SKY[2].lerp(Art.SKY[1], (h - 0.1) / 0.35)
	return Art.SKY[1].lerp(Art.SKY[0], (h - 0.45) / 0.55)


## Below the brass rail: raised wooden panels (iron plates in the engine).
func _panelling(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var wood: Color = {"engine": Art.IRON.lightened(0.06), "personal": Art.WALNUT, "store": Art.OAK.darkened(0.25), "workshop": Art.WALNUT.darkened(0.15)}[r.car]
	var band := Rect2(0, r.wain, s.x, r.floor_y - r.wain)
	Art.vgrad(b, band, wood.darkened(0.1), wood.darkened(0.3))
	if r.car != "engine":
		Art.grain(b, band, wood, r.index * 5 + 1, u, false, false)
	var pw := 124.0 * u
	var x0 := 20.0 * u
	var i := 0
	while x0 < s.x:
		var pr := Rect2(x0 + 9.0 * u, r.wain + 14.0 * u, pw - 18.0 * u, r.floor_y - r.wain - 30.0 * u)
		if pr.size.y > 10.0 * u:
			if r.car == "engine":
				Art.bevel(b, pr, wood, 2.0 * u)
				for c in [pr.position + Vector2(6, 6) * u, Vector2(pr.end.x - 6.0 * u, pr.position.y + 6.0 * u), Vector2(pr.position.x + 6.0 * u, pr.end.y - 6.0 * u), pr.end - Vector2(6, 6) * u]:
					Art.rivet(b, c, 1.8 * u, Art.STEEL.lightened(0.5))
			else:
				Art.bevel(b, pr, wood.darkened(0.08), 3.0 * u)
				Art.grain(b, pr.grow(-4.0 * u), wood.darkened(0.08), i * 13 + r.index * 7, u, false)
				Art.moulding(b, pr.grow(-7.0 * u), u, Art.GILT, 0.22)
		x0 += pw
		i += 1
	# The skirting.
	Art.vgrad(b, Rect2(0, r.floor_y - 10.0 * u, s.x, 10.0 * u), wood.darkened(0.35), wood.darkened(0.55))
	b.rect(Rect2(0, r.floor_y - 10.0 * u, s.x, 1.2 * u), Color(Art.GILT, 0.35))
	# The brass rail, and its shadow on the panels.
	Art.vgrad(b, Rect2(0, r.wain + 4.0 * u, s.x, 14.0 * u), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	Art.bar(b, Rect2(0, r.wain - 4.0 * u, s.x, 8.0 * u))


## The floor: boards (iron tread plate in the engine), and a runner along
## your car and the store car.
func _floor(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var fl := Rect2(0, r.floor_y, s.x, s.y - r.floor_y)
	match r.car:
		"engine":
			Art.vgrad(b, fl, Art.IRON.lightened(0.04), Art.IRON.darkened(0.2))
			var y := r.floor_y + 4.0 * u
			var row := 0
			while y < s.y:
				var x := 6.0 * u * (row % 2)
				while x < s.x:
					b.line(Vector2(x, y), Vector2(x + 5.0 * u, y + 2.0 * u), Color(Art.STEEL.lightened(0.4), 0.25), 1.2 * u)
					x += 12.0 * u
				y += 5.0 * u + row * 0.4 * u
				row += 1
		_:
			var wood := Art.WALNUT.darkened(0.3) if r.car != "workshop" else Art.OAK.darkened(0.3)
			Art.vgrad(b, fl, wood.darkened(0.15), wood)
			var y := r.floor_y
			var step := 6.0 * u
			var row := 0
			while y < s.y:
				b.rect(Rect2(0, y, s.x, 1.2 * u), Color(0, 0, 0, 0.45))
				var x := (Art.rnd(row) * 200.0) * u
				while x < s.x:
					b.rect(Rect2(x, y, 1.2 * u, step), Color(0, 0, 0, 0.35))
					x += 190.0 * u
				y += step
				step *= 1.3
				row += 1
			if r.car != "workshop":
				# The runner: deep wine, gilt borders and a diamond along it.
				var ry := r.floor_y + 9.0 * u
				var run := Rect2(0, ry, s.x, s.y - ry)
				var col := Art.RUNNER if r.car == "personal" else Color(0.1, 0.09, 0.17)
				Art.vgrad(b, run, col.darkened(0.15), col)
				b.rect(Rect2(0, ry, s.x, 1.5 * u), Color(0, 0, 0, 0.5))
				b.rect(Rect2(0, ry + 3.0 * u, s.x, 1.5 * u), Color(Art.GILT, 0.5))
				b.rect(Rect2(0, ry + 6.5 * u, s.x, 0.8 * u), Color(Art.GILT, 0.3))
				var dy := ry + 16.0 * u
				var x := 0.0
				while x < s.x + 40.0 * u:
					var dw := 16.0 * u
					var dh := 5.5 * u
					b.polygon(PackedVector2Array([Vector2(x, dy - dh), Vector2(x + dw, dy), Vector2(x, dy + dh), Vector2(x - dw, dy)]), Color(Art.GILT, 0.22))
					b.polygon(PackedVector2Array([Vector2(x, dy - dh * 0.45), Vector2(x + dw * 0.45, dy), Vector2(x, dy + dh * 0.45), Vector2(x - dw * 0.45, dy)]), col.darkened(0.3))
					b.circle(Vector2(x + 20.0 * u, dy), 1.4 * u, Color(Art.GILT, 0.3), 8)
					x += 40.0 * u
			else:
				# Sawdust and shavings.
				for k in 40:
					var p := Vector2(Art.rnd(k * 3) * s.x, r.floor_y + 4.0 * u + Art.rnd(k * 3 + 1) * (s.y - r.floor_y))
					b.circle(p, (0.8 + Art.rnd(k) * 1.2) * u, Color(0.75, 0.6, 0.4, 0.25), 6)
	# The shadow where the wall meets the floor.
	Art.vgrad(b, Rect2(0, r.floor_y, s.x, 12.0 * u), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))


# --- the view outside: drawn once, slid as the train moves --------------------------------

## Each window gets a box clipped to its frame (the frame's corners hide the
## rest), holding the view's layers, back to front: two sets of stars (one
## with the moon), the far towers and hills, mist, the nearer hills, and more
## mist. They're drawn once; walking along only slides them.
func _build_views(r: Room) -> void:
	for c in r.outside.get_children():
		r.outside.remove_child(c)
		c.queue_free()
	r.views.clear()
	for wi in r.wins.size():
		var box: Rect2 = r.wins[wi]["rect"]
		var clip := Control.new()
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.position = box.position
		clip.size = box.size
		r.outside.add_child(clip)
		var v := {}
		for kind in ["stars0", "stars1", "clouds", "far", "mist0", "near", "mist1"]:
			# (a Node2D, not a Control: a Control is culled by its own rect,
			# and these slide far from where they're drawn)
			var c := Node2D.new()
			c.draw.connect(_paint_view.bind(r, wi, kind, c))
			clip.add_child(c)
			v[kind] = c
		r.views.append(v)


## How far a layer of the view outside is slid along, in a room, for where
## the train stands (`slide`: how much it moves with the car).
func _offset(r: Room, slide: float, at: float) -> float:
	return -r.index * r.size.x + (1.0 - slide) * at * r.size.x


## Where the view's layers stand, for where the train stands and the mist's drift.
func _slide(r: Room) -> void:
	var w := r.size.x
	var still := fposmod((pos - r.index) * w, w)
	var far := _offset(r, FAR_SLIDE, pos)
	var near := _offset(r, NEAR_SLIDE, pos)
	var p := MIST_PERIOD * r.u
	var m0 := fposmod(far + t * 4.0 * r.u, p)
	var m1 := fposmod(near - t * 2.5 * r.u, p)
	var cl := fposmod(_offset(r, 0.04, pos) - t * 1.5 * r.u, CLOUD_PERIOD * r.u)
	for wi in r.views.size():
		var v: Dictionary = r.views[wi]
		var o: Vector2 = r.wins[wi]["rect"].position
		v["stars0"].position = Vector2(still, 0) - o
		v["stars1"].position = Vector2(still, 0) - o
		v["clouds"].position = Vector2(cl, 0) - o
		v["far"].position = Vector2(far, 0) - o
		v["near"].position = Vector2(near, 0) - o
		v["mist0"].position = Vector2(m0, 0) - o
		v["mist1"].position = Vector2(m1, 0) - o


## The light brightening and dimming (the firebox flickering), the stars twinkling.
func _breathe(r: Room) -> void:
	var k := 0.93 + 0.07 * sin(t * 2.3 + r.index)
	if r.car == "engine":
		k = 0.84 + 0.1 * sin(t * 9.0) * sin(t * 5.3 + 1.0) + 0.06 * sin(t * 17.0)
	r.glow.modulate.a = k
	for v in r.views:
		v["stars0"].modulate.a = 0.72 + 0.28 * sin(t * 1.7 + r.index)
		v["stars1"].modulate.a = 0.72 + 0.28 * sin(t * 2.3 + 2.0)


## The part of a layer that can show in a window, as the train goes from the
## car before to the car after: [left, right], in the layer's own x.
func _reach(r: Room, box: Rect2, slide: float) -> Vector2:
	var n := ids().size()
	var o0 := _offset(r, slide, maxf(r.index - 1.0, -0.05))
	var o1 := _offset(r, slide, minf(r.index + 1.0, n - 1.0 + 0.05))
	return Vector2(box.position.x - o1 - 8.0 * r.u, box.end.x - o0 + 8.0 * r.u)


func _paint_view(r: Room, wi: int, kind: String, c: Node2D) -> void:
	var b := UI.Draw.Batch.new()
	var win: Dictionary = r.wins[wi]
	var box: Rect2 = win["rect"]
	var w := r.size.x
	var u := r.u
	var sky_h := r.horizon - r.top
	match kind:
		"stars0", "stars1":
			# The stars stay put on screen (they repeat every screen width, so
			# whichever window passes shows its share).
			var set := 0 if kind == "stars0" else 1
			for st in _stars:
				if st[3] != set:
					continue
				for k in [-1.0, 0.0]:
					var p := Vector2(st[0] * w + k * w, r.top + st[1] * sky_h)
					if p.x < box.position.x - w - 4.0 or p.x > box.end.x + 4.0:
						continue
					b.circle(p, st[2] * u, Color(Art.STAR, 0.85), 8)
					if st[2] > 1.3:
						b.rect(Rect2(p.x - st[2] * 2.5 * u, p.y - 0.25 * u, st[2] * 5.0 * u, 0.5 * u), Color(Art.STAR, 0.3))
						b.rect(Rect2(p.x - 0.25 * u, p.y - st[2] * 2.5 * u, 0.5 * u, st[2] * 5.0 * u), Color(Art.STAR, 0.2))
			if set == 0:
				# The moon: a soft cool halo, its shaded side and two dark seas.
				var mr := MOON_R * u * (1.0 if not win["round"] else 0.8)
				for k in [-1.0, 0.0]:
					var mc := Vector2(MOON_AT.x * w + k * w, r.top + MOON_AT.y * sky_h)
					if mc.x < box.position.x - w - 60.0 * u or mc.x > box.end.x + 60.0 * u:
						continue
					Art.light(b, mc, Vector2(mr, mr) * 5.0, Color(Art.COOL.lerp(Art.MOON, 0.4), 0.2))
					b.circle(mc, mr, Art.MOON, 28)
					b.polygon(Art.oval(mc + Vector2(mr * 0.35, -mr * 0.1), Vector2(mr, mr) * 0.86, 24), Color(Art.SKY[1], 0.35))
					b.polygon(Art.oval(mc + Vector2(-mr * 0.3, -mr * 0.2), Vector2(mr, mr) * 0.22, 10), Color(0.75, 0.7, 0.66, 0.6))
					b.polygon(Art.oval(mc + Vector2(-mr * 0.05, mr * 0.35), Vector2(mr, mr) * 0.16, 10), Color(0.75, 0.7, 0.66, 0.5))
		"clouds":
			# Long thin clouds high in the dusk, lit warm along their undersides,
			# drifting slowly (they repeat every CLOUD_PERIOD).
			var p := CLOUD_PERIOD * u
			var x0 := box.position.x - p
			while x0 < box.end.x + p * 0.1:
				for k in 3:
					var cc := Vector2(x0 + p * (0.15 + 0.33 * k + 0.1 * Art.rnd(k * 5 + 1)), r.top + sky_h * (0.25 + 0.3 * Art.rnd(k * 7 + 2)))
					var cw := (34.0 + 26.0 * Art.rnd(k * 3 + 4)) * u
					for j in 3:
						var o := Vector2((j - 1) * cw * 0.55, (j % 2) * -2.5 * u)
						b.polygon(Art.oval(cc + o, Vector2(cw * (0.6 - 0.12 * absf(j - 1)), (4.0 + 2.0 * (j % 2)) * u), 18), Color(Art.SKY[2].lightened(0.12), 0.3))
					b.polygon(Art.oval(cc + Vector2(0, 2.5 * u), Vector2(cw * 0.75, 1.8 * u), 16), Color(Art.SKY[3].lightened(0.2), 0.18))
				x0 += p
		"far":
			var reach := _reach(r, box, FAR_SLIDE)
			# The six towers, each with its top lit in its essence's colour.
			for k in Towers.ORDER.size():
				var bx: float = TOWER_AT[k] * w
				if bx < reach.x - 40.0 * u or bx > reach.y + 40.0 * u:
					continue
				var col := Essence.color(Towers.TOWERS[Towers.ORDER[k]]["essence"])
				var shape: Array = TOWER_SHAPE[k]
				var base := Vector2(bx, r.horizon + 2.0 * u)
				var sc := u * (1.0 if not win["round"] else 0.62)
				var lamp: Vector2 = base + shape[2] * sc
				Art.light(b, lamp, Vector2(32.0, 32.0) * sc, Color(col, 0.38))
				var pts := PackedVector2Array()
				var rim := PackedVector2Array()
				for p in shape[0]:
					pts.append(base + p * sc)
					rim.append(base + (p + Vector2(1.8 if p.x < 0.0 else -1.8, 0.0)) * sc)
				b.polygon(pts, Art.FAR)
				# A cool rim of moonlight down its left side.
				var half := pts.size() / 2
				var lit := PackedVector2Array()
				for i in half + 1:
					lit.append(pts[i])
				for i in range(half, -1, -1):
					lit.append(rim[i])
				b.polygon(lit, Color(Art.COOL.lerp(Art.FAR, 0.5), 0.35))
				for p in shape[1]:
					var wp: Vector2 = base + p * sc
					b.rect(Rect2(wp - Vector2(1.0, 1.6) * sc, Vector2(2.0, 3.2) * sc), Color(col, 0.8))
				b.circle(lamp, 2.4 * sc, col.lightened(0.3), 10)
				b.circle(lamp, 1.2 * sc, Color(1, 1, 1, 0.9), 8)
			b.polygon(_hills(r, reach, func(x): return r.horizon - (3.0 + 2.5 * sin(x / 37.0) + 1.5 * sin(x / 13.0 + 2.0)) * u, r.horizon + 3.0 * u), Art.FAR.darkened(0.2))
		"near":
			var reach := _reach(r, box, NEAR_SLIDE)
			b.polygon(_hills(r, reach, func(x): return r.horizon + (8.0 - 4.0 * sin(x / 47.0 + 1.0) - 2.0 * sin(x / 19.0)) * u, box.end.y + 2.0), Art.NEAR)
		"mist0", "mist1":
			# Mist lying on the land; it repeats every MIST_PERIOD, so it can drift for ever.
			var m := 0 if kind == "mist0" else 1
			var p := MIST_PERIOD * u
			var reach := Vector2(box.position.x - p - 8.0 * u, box.end.x + 8.0 * u)
			var my := r.horizon + (-1.0 + 6.0 * m) * u
			var f := TAU / p
			var band := PackedVector2Array()
			var x := reach.x
			while x <= reach.y + 8.0 * u:
				band.append(Vector2(x, my - (4.0 + 1.8 * sin(x * f * 3.0 + m) + 1.2 * sin(x * f * 7.0)) * u))
				x += 12.0 * u
			x = reach.y + 8.0 * u
			while x >= reach.x:
				band.append(Vector2(x, my + (3.0 + 1.5 * sin(x * f * 2.0 + 1.0 + m) + 0.8 * sin(x * f * 5.0)) * u))
				x -= 12.0 * u
			b.polygon(band, Color(Art.MIST, 0.1 - 0.03 * m))
	b.flush(c)


## A line of hills across [reach.x, reach.y], `height` giving its top at each
## x (in the room's scale), closed along `bottom`.
func _hills(r: Room, reach: Vector2, height: Callable, bottom: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := 9.0 * r.u
	var x := reach.x
	while x <= reach.y + step:
		pts.append(Vector2(x, height.call(x / r.u)))
		x += step
	pts.append(Vector2(x - step, bottom))
	pts.append(Vector2(reach.x, bottom))
	return pts


# --- in front of the view: drawn once -------------------------------------------------

## The window frames, curtains, ceiling, lamps' mounts, the car's own
## fittings, the ends of the car, and a soft darkening towards the edges.
func paint_front(r: Room) -> void:
	var b := UI.Draw.Batch.new()
	for win in r.wins:
		if win["round"]:
			_porthole(b, r, win)
		else:
			_window(b, r, win, r.car == "personal")
	_cornice(b, r)
	match r.car:
		"engine":
			_engine(b, r)
		"store":
			_store(b, r)
		"workshop":
			_workshop(b, r)
	for h in r.lamps:
		b.circle(h, 5.0 * r.u, Art.OUTLINE, 14)
		b.circle(h, 4.0 * r.u, Art.GILT.darkened(0.3), 14)
		b.circle(h - Vector2(1.2, 1.2) * r.u, 1.6 * r.u, Color(Art.GILT_HI, 0.6), 8)
	_ends(b, r)
	_vignette(b, r)
	b.flush(r.front)


## An arched window's brass frame, mullion and transom, the glass's sheen,
## a sill, a little moonlight on the wall below (and curtains in your car).
func _window(b, r: Room, win: Dictionary, curtains: bool) -> void:
	var u := r.u
	var rect: Rect2 = win["rect"]
	var glass: PackedVector2Array = win["glass"]
	var half := rect.size.x * 0.5
	var ac := Vector2(rect.get_center().x, rect.position.y + half)
	var fw := 7.0 * u
	var outer := Rect2(rect.position - Vector2(fw, fw), rect.size + Vector2(fw * 2.0, fw))
	# The frame's shadow on the wall.
	b.rect(Rect2(outer.end.x, outer.position.y + 4.0 * u, 4.0 * u, outer.size.y), Color(0, 0, 0, 0.3))
	# The spandrels: the corners between the arch and its square frame (the
	# view outside is clipped to the square), each with a gilt fan.
	var wood: Color = {"personal": Art.WALNUT, "store": Art.OAK.darkened(0.3), "workshop": Art.BOARDS.darkened(0.1)}.get(r.car, Art.WALNUT)
	for side in [-1.0, 1.0]:
		var corner := Vector2(rect.position.x if side < 0.0 else rect.end.x, rect.position.y)
		var a0 := PI if side < 0.0 else PI * 1.5
		var pts := PackedVector2Array([corner])
		for k in 13:
			pts.append(ac + Vector2.from_angle(a0 + PI * 0.5 * k / 12.0) * half)
		Art.shaded_poly(b, pts, func(y): return wood.lightened(0.1).lerp(wood.darkened(0.3), clampf((y - rect.position.y) / half, 0.0, 1.0)))
		var fan := 0.0 if side < 0.0 else PI * 0.5
		for k in 3:
			b.arc(corner, half * (0.16 + 0.12 * k), fan, fan + PI * 0.5, 8, Color(Art.GILT, 0.5 - 0.1 * k), maxf(0.8, 1.1 * u))
		for k in 3:
			var d := Vector2.from_angle(fan + PI * 0.5 * (k + 1) / 4.0)
			b.line(corner + d * half * 0.16, corner + d * half * 0.4, Color(Art.GILT, 0.35), maxf(0.8, 0.9 * u))
	# The square frame: brass posts and a top rail, riveted.
	for x in [rect.position.x - fw, rect.end.x]:
		b.rect(Rect2(x - 1.2 * u, outer.position.y - 1.2 * u, fw + 2.4 * u, outer.size.y + 1.2 * u), Art.OUTLINE)
	b.rect(Rect2(outer.position.x - 1.2 * u, outer.position.y - 1.2 * u, outer.size.x + 2.4 * u, fw + 2.4 * u), Art.OUTLINE)
	for x in [rect.position.x - fw, rect.end.x]:
		Art.post(b, Rect2(x, outer.position.y, fw, outer.size.y), Art.GILT.darkened(0.28))
		Art.rivets(b, Vector2(x + fw * 0.5, ac.y + 16.0 * u), Vector2(x + fw * 0.5, rect.end.y - 12.0 * u), 42.0 * u, 1.4 * u)
	Art.bar(b, Rect2(outer.position.x, outer.position.y, outer.size.x, fw), Art.GILT.darkened(0.28))
	for x in [outer.position.x + fw * 0.5, outer.end.x - fw * 0.5]:
		Art.rivet(b, Vector2(x, outer.position.y + fw * 0.5), 1.5 * u)
	# The arch inside it: a brass ring with a lit rim, riveted.
	b.arc(ac, half + 2.4 * u, PI - 0.04, TAU + 0.04, 28, Art.OUTLINE, 6.4 * u)
	b.arc(ac, half + 2.4 * u, PI - 0.02, TAU + 0.02, 28, Art.GILT.darkened(0.2), 4.2 * u)
	b.arc(ac, half + 3.8 * u, PI, PI * 1.62, 16, Color(Art.GILT_HI, 0.7), 1.2 * u)
	b.arc(ac, half + 0.4 * u, PI, TAU, 28, Color(0, 0, 0, 0.55), 1.4 * u)
	for k in 7:
		Art.rivet(b, ac + Vector2.from_angle(PI + PI * (k + 0.5) / 7.0) * (half + 2.4 * u), 1.2 * u)
	# A keystone at the top of the arch.
	var ky := rect.position.y
	b.poly(PackedVector2Array([Vector2(ac.x - 6.0 * u, ky - fw - 4.0 * u), Vector2(ac.x + 6.0 * u, ky - fw - 4.0 * u),
		Vector2(ac.x + 3.5 * u, ky + 2.0 * u), Vector2(ac.x - 3.5 * u, ky + 2.0 * u)]), Art.GILT.darkened(0.1), 1.0 * u)
	b.rect(Rect2(ac.x - 5.0 * u, ky - fw - 3.0 * u, 1.6 * u, fw + 3.0 * u), Color(Art.GILT_HI, 0.6))
	# The mullion and the transom.
	Art.post(b, Rect2(ac.x - 1.7 * u, rect.position.y, 3.4 * u, rect.size.y), Art.GILT.darkened(0.35))
	Art.bar(b, Rect2(rect.position.x, ac.y - 1.7 * u, rect.size.x, 3.4 * u), Art.GILT.darkened(0.35))
	# The glass's sheen: two soft streaks.
	var gx := rect.position.x
	var gw := rect.size.x
	Art.clipped(b, PackedVector2Array([Vector2(gx + gw * 0.16, rect.position.y), Vector2(gx + gw * 0.34, rect.position.y),
		Vector2(gx + gw * 0.06, rect.end.y), Vector2(gx - gw * 0.12, rect.end.y)]), glass, rect, Color(1, 1, 1, 0.04))
	Art.clipped(b, PackedVector2Array([Vector2(gx + gw * 0.42, rect.position.y), Vector2(gx + gw * 0.47, rect.position.y),
		Vector2(gx + gw * 0.19, rect.end.y), Vector2(gx + gw * 0.14, rect.end.y)]), glass, rect, Color(1, 1, 1, 0.035))
	# The sill, its shadow, and moonlight on the wall below.
	var sill := Rect2(rect.position.x - fw - 9.0 * u, rect.end.y, rect.size.x + fw * 2.0 + 18.0 * u, 8.0 * u)
	Art.light(b, Vector2(ac.x, sill.end.y + 4.0 * u), Vector2(rect.size.x * 0.75, 22.0 * u), Color(Art.COOL, 0.07))
	b.rect(sill.grow(1.0 * u), Art.OUTLINE)
	Art.vgrad(b, sill, Art.WALNUT.lightened(0.18), Art.WALNUT.darkened(0.35))
	b.rect(Rect2(sill.position, Vector2(sill.size.x, 1.4 * u)), Color(Art.COOL.lerp(Art.GILT_HI, 0.5), 0.45))
	Art.vgrad(b, Rect2(sill.position.x, sill.end.y + 1.0 * u, sill.size.x, 9.0 * u), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))
	if curtains:
		_curtains(b, r, rect)


## Velvet curtains, tied back with gilt cord and tassels, under a scalloped pelmet.
func _curtains(b, r: Room, rect: Rect2) -> void:
	var u := r.u
	var top := rect.position.y - 18.0 * u
	var bot := rect.end.y + 16.0 * u
	var tie := rect.position.y + rect.size.y * 0.6
	for side in [-1.0, 1.0]:
		var outer: float = (rect.position.x - 16.0 * u) if side < 0.0 else (rect.end.x + 16.0 * u)
		var reach: float = outer - side * 34.0 * u  # how far it falls over the glass at the top
		var waist: float = outer - side * 7.0 * u
		var edge := PackedVector2Array()  # its inner edge, top to bottom
		for k in 9:
			var a := k / 8.0
			edge.append(Vector2(lerpf(reach, waist, sin(a * PI * 0.5)), lerpf(top, tie, a)))
		for k in range(1, 7):
			var a := k / 6.0
			edge.append(Vector2(lerpf(waist, outer - side * 26.0 * u, a * a), lerpf(tie, bot, a)))
		var pts := PackedVector2Array([Vector2(outer + side * 10.0 * u, top)])
		pts.append_array(edge)
		pts.append(Vector2(outer + side * 10.0 * u, bot))
		b.poly(pts, Art.CURTAIN, 1.0 * u)
		# Folds gathered at the tie and spreading above and below it.
		for f in 4:
			var k := (f + 0.6) / 4.6
			var at_top := Vector2(lerpf(outer + side * 8.0 * u, reach, k), top)
			var at_tie := Vector2(lerpf(outer + side * 8.0 * u, waist, k), tie)
			var at_bot := Vector2(lerpf(outer + side * 8.0 * u, outer - side * 24.0 * u, k), bot)
			for seg in [[at_top, at_tie], [at_tie, at_bot]]:
				b.line(seg[0], seg[1], Color(0, 0, 0, 0.32), 3.2 * u)
				b.line(seg[0] + Vector2(-side * 2.6 * u, 0), seg[1] + Vector2(-side * 2.2 * u, 0), Color(Art.CURTAIN.lightened(0.35), 0.22), 1.6 * u)
		# The cord and its tassel.
		var tp := Vector2(waist + side * 2.0 * u, tie)
		b.line(tp + Vector2(-side * 6.0 * u, -3.0 * u), tp + Vector2(side * 12.0 * u, 2.0 * u), Art.GILT.darkened(0.15), 2.4 * u)
		b.circle(tp + Vector2(side * 12.0 * u, 2.0 * u), 2.6 * u, Art.GILT, 10)
		b.polygon(PackedVector2Array([tp + Vector2(side * 12.0 * u - 2.0 * u, 4.0 * u), tp + Vector2(side * 12.0 * u + 2.0 * u, 4.0 * u),
			tp + Vector2(side * 12.0 * u + 3.5 * u, 15.0 * u), tp + Vector2(side * 12.0 * u - 3.5 * u, 15.0 * u)]), Art.GILT.darkened(0.2))
		for k in 4:
			b.line(tp + Vector2(side * 12.0 * u + (-2.5 + k * 1.7) * u, 6.0 * u), tp + Vector2(side * 12.0 * u + (-3.0 + k * 2.0) * u, 15.0 * u), Color(Art.GILT_HI, 0.5), 0.7 * u)
	# The pelmet: velvet, scalloped, with a gilt fringe; a brass rod's ends.
	var pl := Rect2(rect.position.x - 34.0 * u, top - 10.0 * u, rect.size.x + 68.0 * u, 12.0 * u)
	b.rect(pl.grow(1.0 * u), Art.OUTLINE)
	Art.vgrad(b, pl, Art.CURTAIN.lightened(0.08), Art.CURTAIN.darkened(0.25))
	var n := int(pl.size.x / (16.0 * u))
	var sw := pl.size.x / n
	for k in n:
		var c := Vector2(pl.position.x + sw * (k + 0.5), pl.end.y)
		b.polygon(Art.oval(c, Vector2(sw * 0.5, 4.5 * u), 12).slice(0, 7), Art.CURTAIN.darkened(0.25))
		b.circle(c + Vector2(0, 4.5 * u), 1.4 * u, Art.GILT, 8)
	b.rect(Rect2(pl.position.x, pl.position.y + 2.0 * u, pl.size.x, 1.4 * u), Color(Art.GILT, 0.7))
	b.rect(Rect2(pl.position.x, pl.end.y - 1.6 * u, pl.size.x, 1.2 * u), Color(Art.GILT, 0.55))
	for x in [pl.position.x - 3.0 * u, pl.end.x + 3.0 * u]:
		b.ball(Vector2(x, pl.position.y + 6.0 * u), 3.6 * u, Art.GILT, false)


## A round spectacle glass in the cab: a heavy riveted brass ring, a hinge and clamps.
func _porthole(b, r: Room, win: Dictionary) -> void:
	var u := r.u
	var c: Vector2 = win["c"]
	var rad: float = win["rad"]
	var glass: PackedVector2Array = win["glass"]
	var box: Rect2 = win["rect"]
	var ring := rad + 7.0 * u
	# A square riveted plate around it (the view outside is clipped to the square).
	var plate := box.grow(14.0 * u)
	b.rect(Rect2(plate.end.x, plate.position.y + 4.0 * u, 4.0 * u, plate.size.y), Color(0, 0, 0, 0.3))
	b.rect(Rect2(plate.position.x + 4.0 * u, plate.end.y, plate.size.x, 4.0 * u), Color(0, 0, 0, 0.3))
	for q in 4:
		var a0 := PI + q * PI * 0.5
		var a1 := a0 + PI * 0.5
		var e0 := _axis(c, plate, a0)
		var e1 := _axis(c, plate, a1)
		var pts := PackedVector2Array([e0, e0 + e1 - c, e1])
		for k in 13:
			pts.append(c + Vector2.from_angle(a1 - PI * 0.5 * k / 12.0) * rad)
		Art.shaded_poly(b, pts, func(y): return Art.STEEL.lightened(0.12).lerp(Art.STEEL.darkened(0.3), clampf((y - plate.position.y) / plate.size.y, 0.0, 1.0)))
	Art.moulding(b, plate, u, Art.STEEL.lightened(0.5), 0.35)
	for p in [plate.position, Vector2(plate.end.x, plate.position.y), Vector2(plate.position.x, plate.end.y), plate.end]:
		Art.rivet(b, p + (c - p).normalized() * 9.0 * u, 2.0 * u, Art.STEEL.lightened(0.5))
	b.arc(c + Vector2(2.5, 3.5) * u, ring, 0.0, TAU, 44, Color(0, 0, 0, 0.35), 16.0 * u)
	b.arc(c, ring, 0.0, TAU, 44, Art.OUTLINE, 16.0 * u)
	b.arc(c, ring, 0.0, TAU, 44, Art.GILT.darkened(0.28), 13.0 * u)
	b.arc(c, ring + 4.5 * u, PI * 0.85, PI * 1.7, 18, Color(Art.GILT_HI, 0.7), 1.6 * u)
	b.arc(c, ring - 4.5 * u, PI * 1.85, PI * 2.7, 18, Color(Art.GILT_HI, 0.35), 1.2 * u)
	b.arc(c, rad + 1.0 * u, 0.0, TAU, 44, Color(0, 0, 0, 0.6), 1.8 * u)
	for k in 10:
		Art.rivet(b, c + Vector2.from_angle(TAU * (k + 0.5) / 10.0) * ring, 1.9 * u)
	# Its sheen.
	Art.clipped(b, PackedVector2Array([c + Vector2(-rad * 0.6, -rad), c + Vector2(-rad * 0.25, -rad), c + Vector2(-rad * 0.75, rad), c + Vector2(-rad * 1.1, rad)]),
		glass, box, Color(1, 1, 1, 0.045))
	# A hinge on the outer side, clamps on the other.
	var out := -1.0 if c.x < r.size.x * 0.5 else 1.0
	var hinge := Rect2(Vector2(c.x + out * (ring + 2.0 * u) - (8.0 * u if out < 0.0 else 0.0), c.y - 12.0 * u), Vector2(8.0, 24.0) * u)
	b.rect(hinge.grow(1.0 * u), Art.OUTLINE)
	Art.post(b, hinge, Art.GILT.darkened(0.3))
	for a in [-0.35, 0.35]:
		var p := c + Vector2.from_angle((0.0 if out < 0.0 else PI) + a) * (ring + 3.0 * u)
		b.circle(p, 4.0 * u, Art.OUTLINE, 12)
		b.circle(p, 3.0 * u, Art.IRON.lightened(0.35), 12)
		b.circle(p - Vector2(0.8, 0.8) * u, 1.2 * u, Color(1, 1, 1, 0.35), 8)


## Where a line from `c` at angle `a` (straight left, up, right or down)
## meets the edge of `r`.
static func _axis(c: Vector2, r: Rect2, a: float) -> Vector2:
	var d := Vector2.from_angle(a).round()
	return Vector2(r.position.x if d.x < 0.0 else (r.end.x if d.x > 0.0 else c.x), r.position.y if d.y < 0.0 else (r.end.y if d.y > 0.0 else c.y))


## Where the wall meets the ceiling: a carved cornice with dentils and a gilt bead
## (in the engine, a riveted iron angle).
func _cornice(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var y := r.ceil_y
	Art.vgrad(b, Rect2(0, 0, s.x, y), Color(0.05, 0.04, 0.06), Color(0.1, 0.075, 0.09))
	if r.car == "engine":
		Art.vgrad(b, Rect2(0, y - 6.0 * u, s.x, 9.0 * u), Art.IRON.lightened(0.2), Art.IRON.darkened(0.2))
		Art.rivets(b, Vector2(10.0 * u, y - 1.5 * u), Vector2(s.x - 10.0 * u, y - 1.5 * u), 26.0 * u, 1.6 * u, Art.STEEL.lightened(0.5))
		return
	var wood := Art.WALNUT if r.car != "store" else Art.OAK.darkened(0.3)
	Art.vgrad(b, Rect2(0, y - 8.0 * u, s.x, 8.0 * u), wood.lightened(0.12), wood.darkened(0.35))
	var x := 3.0 * u
	while x < s.x:
		b.rect(Rect2(x, y, 5.0 * u, 4.5 * u), wood.darkened(0.15))
		b.rect(Rect2(x, y, 1.2 * u, 4.5 * u), Color(wood.lightened(0.3), 0.6))
		x += 9.0 * u
	b.rect(Rect2(0, y, s.x, 0.8 * u), Color(0, 0, 0, 0.5))
	b.rect(Rect2(0, y + 4.5 * u, s.x, 1.4 * u), Color(0, 0, 0, 0.55))
	Art.bar(b, Rect2(0, y - 10.0 * u, s.x, 2.6 * u))


## The cab: copper pipes with flanges and a handwheel, the gauges on a brass
## plate, a water glass, the boiler's backhead and the firebox door, and coal.
func _engine(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var py := r.ceil_y + 14.0 * u
	Art.pipe(b, Vector2(0, py + 16.0 * u), Vector2(s.x, py + 16.0 * u), 5.0 * u, Art.IRON.lightened(0.3))
	for fx in [0.24, 0.76]:
		Art.pipe(b, Vector2(s.x * fx, py), Vector2(s.x * fx, r.wain - 4.0 * u), 8.0 * u, Art.COPPER.darkened(0.08))
		b.circle(Vector2(s.x * fx, py), 7.0 * u, Art.OUTLINE, 16)
		b.circle(Vector2(s.x * fx, py), 6.0 * u, Art.COPPER.darkened(0.15), 16)
		Art.bar(b, Rect2(s.x * fx - 7.0 * u, r.wain - 30.0 * u, 14.0 * u, 5.0 * u), Art.COPPER)
	Art.pipe(b, Vector2(0, py), Vector2(s.x, py), 10.0 * u, Art.COPPER)
	var x := 60.0 * u
	while x < s.x:
		var fl := Rect2(x - 4.0 * u, py - 8.5 * u, 8.0 * u, 17.0 * u)
		b.rect(fl.grow(1.0 * u), Art.OUTLINE)
		Art.post(b, fl, Art.COPPER.darkened(0.1))
		Art.rivet(b, fl.position + Vector2(4.0 * u, 3.0 * u), 1.3 * u, Art.COPPER)
		Art.rivet(b, Vector2(fl.position.x + 4.0 * u, fl.end.y - 3.0 * u), 1.3 * u, Art.COPPER)
		x += 170.0 * u
	# The steam valve on the main pipe.
	var sv := r.steam
	b.rect(Rect2(sv.x - 3.0 * u, sv.y - 8.0 * u, 6.0 * u, 8.0 * u), Art.COPPER.darkened(0.2))
	b.rect(Rect2(sv.x - 6.0 * u, sv.y - 11.0 * u, 12.0 * u, 3.5 * u), Art.GILT.darkened(0.2))
	# A handwheel on the left drop.
	var hw := Vector2(s.x * 0.24, r.wain - 70.0 * u)
	b.arc(hw, 12.0 * u, 0.0, TAU, 24, Art.OUTLINE, 5.0 * u)
	b.arc(hw, 12.0 * u, 0.0, TAU, 24, Color(0.55, 0.12, 0.1), 3.4 * u)
	b.arc(hw, 12.5 * u, PI * 1.0, PI * 1.6, 8, Color(1, 0.6, 0.5, 0.45), 1.0 * u)
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + 0.4)
		b.line(hw + d * 3.0 * u, hw + d * 11.0 * u, Color(0.45, 0.1, 0.08), 2.0 * u)
	b.ball(hw, 3.2 * u, Art.GILT, false)
	# The gauges on their plate.
	var g0: Vector2 = r.gauges[0][0]
	var plate := Rect2(g0.x - 78.0 * u, g0.y - 32.0 * u, 156.0 * u, 60.0 * u)
	b.rect(plate.grow(1.4 * u), Art.OUTLINE)
	Art.bevel(b, plate, Art.GILT.darkened(0.45), 2.5 * u)
	for c in [plate.position + Vector2(6, 6) * u, Vector2(plate.end.x - 6.0 * u, plate.position.y + 6.0 * u), Vector2(plate.position.x + 6.0 * u, plate.end.y - 6.0 * u), plate.end - Vector2(6, 6) * u]:
		Art.rivet(b, c, 1.6 * u)
	for g in r.gauges:
		_gauge_face(b, g[0], g[1], u)
	# The water glass beside them.
	var wg := Rect2(plate.end.x + 14.0 * u, plate.position.y - 6.0 * u, 7.0 * u, 70.0 * u)
	b.rect(wg.grow(1.2 * u), Art.OUTLINE)
	b.rect(wg, Color(0.12, 0.13, 0.18))
	Art.vgrad(b, Rect2(wg.position.x, wg.position.y + wg.size.y * 0.42, wg.size.x, wg.size.y * 0.58), Color(Art.COOL, 0.5), Color(Art.COOL.darkened(0.3), 0.6))
	b.rect(Rect2(wg.position.x + 1.2 * u, wg.position.y, 1.2 * u, wg.size.y), Color(1, 1, 1, 0.3))
	for cy in [wg.position.y - 5.0 * u, wg.end.y]:
		b.rect(Rect2(wg.position.x - 3.0 * u, cy, wg.size.x + 6.0 * u, 5.0 * u).grow(1.0 * u), Art.OUTLINE)
		Art.bar(b, Rect2(wg.position.x - 3.0 * u, cy, wg.size.x + 6.0 * u, 5.0 * u))
	# The backhead: the boiler's riveted face, low in the middle.
	var bc := Vector2(s.x * 0.5, r.floor_y + 4.0 * u)
	var br := 118.0 * u
	var dome := PackedVector2Array()
	for k in 33:
		dome.append(bc + Vector2.from_angle(PI + PI * k / 32.0) * br)
	b.poly(dome, Art.STEEL.darkened(0.25), 1.4 * u)
	Art.shaded_poly(b, dome, func(y): return Art.STEEL.darkened(0.1).lerp(Art.STEEL.darkened(0.5), clampf((y - (bc.y - br)) / br, 0.0, 1.0)))
	b.arc(bc, br - 9.0 * u, PI, TAU, 32, Art.GILT.darkened(0.35), 3.0 * u)
	b.arc(bc, br - 2.0 * u, PI * 1.05, PI * 1.5, 14, Color(Art.STEEL.lightened(0.5), 0.5), 1.4 * u)
	for k in 13:
		Art.rivet(b, bc + Vector2.from_angle(PI + PI * (k + 0.5) / 13.0) * (br - 16.0 * u), 1.8 * u, Art.STEEL.lightened(0.5))
	# The firebox door: a brass frame, an iron door with a vent (the fire
	# shows through it: paint_live), and its latch.
	var door := r.fire
	b.rect(door.grow(7.0 * u), Art.OUTLINE)
	Art.bevel(b, door.grow(6.0 * u), Art.GILT.darkened(0.3), 3.0 * u)
	Art.vgrad(b, door, Art.IRON.lightened(0.18), Art.IRON.darkened(0.1))
	b.rect(_vent(r).grow(1.5 * u), Color(0.02, 0.01, 0.01))
	b.rect(Rect2(door.get_center().x - 0.8 * u, door.position.y, 1.6 * u, door.size.y), Color(0, 0, 0, 0.6))
	var latch := Vector2(door.end.x - 10.0 * u, door.end.y - 9.0 * u)
	b.line(latch, latch + Vector2(-18.0 * u, 0), Art.GILT.darkened(0.1), 2.6 * u)
	b.ball(latch, 3.0 * u, Art.GILT, false)
	# Coal heaped by the backhead, and a shovel against it.
	var coal := Vector2(bc.x + br + 30.0 * u, r.floor_y + 8.0 * u)
	var heap := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		heap.append(coal + Vector2(cos(a) * 34.0, sin(a) * (16.0 + 3.0 * sin(k * 2.7))) * u)
	b.poly(heap, Color(0.06, 0.055, 0.07), 1.0 * u)
	for k in 9:
		var p := coal + Vector2((Art.rnd(k) - 0.5) * 50.0, -Art.rnd(k + 9) * 13.0) * u
		b.circle(p, 1.0 * u, Color(0.6, 0.6, 0.75, 0.35), 6)
	b.stroke(Vector2(bc.x - br - 26.0 * u, r.floor_y + 6.0 * u), Vector2(bc.x - br + 4.0 * u, r.floor_y - 66.0 * u), Art.OAK, 2.6 * u)
	b.poly(PackedVector2Array([Vector2(bc.x - br - 40.0 * u, r.floor_y + 10.0 * u), Vector2(bc.x - br - 14.0 * u, r.floor_y + 10.0 * u),
		Vector2(bc.x - br - 20.0 * u, r.floor_y - 6.0 * u), Vector2(bc.x - br - 34.0 * u, r.floor_y - 6.0 * u)]), Art.IRON.lightened(0.3), 1.0 * u)


## The opening in the firebox door, where the fire shows.
func _vent(r: Room) -> Rect2:
	return Rect2(r.fire.position + Vector2(9.0, 11.0) * r.u, Vector2(r.fire.size.x - 18.0 * r.u, 16.0 * r.u))


## A gauge's face (its needle moves: paint_live): a brass bezel, a cream
## dial with ticks and a red zone, a glint on its glass.
func _gauge_face(b, c: Vector2, rad: float, u: float) -> void:
	b.circle(c + Vector2(1.5, 2.0) * u, rad + 4.0 * u, Color(0, 0, 0, 0.35), 32)
	b.circle(c, rad + 3.6 * u, Art.OUTLINE, 32)
	b.circle(c, rad + 2.6 * u, Art.GILT.darkened(0.2), 32)
	b.arc(c, rad + 1.6 * u, PI * 0.9, PI * 1.6, 12, Color(Art.GILT_HI, 0.8), 1.2 * u)
	b.circle(c, rad, Color(0.9, 0.86, 0.76), 32)
	b.circle(c + Vector2(0, rad * 0.25), rad * 0.85, Color(0.55, 0.45, 0.35, 0.12), 28)
	for k in 11:
		var d := Vector2.from_angle(PI * 0.75 + PI * 1.5 * k / 10.0)
		b.line(c + d * rad * (0.72 if k % 5 == 0 else 0.8), c + d * rad * 0.92, Color(0.15, 0.1, 0.08), maxf(0.8, rad * (0.07 if k % 5 == 0 else 0.04)))
	b.arc(c, rad * 0.86, PI * 0.75 + PI * 1.5 * 0.78, PI * 2.25, 8, Color(0.75, 0.15, 0.1, 0.85), rad * 0.1)
	b.arc(c, rad * 0.8, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.5), maxf(0.8, rad * 0.06))


## The store car: hat boxes and parcels on shelves at the ends of the car.
func _store(b, r: Room) -> void:
	var u := r.u
	var spans := [[22.0 * u, r.wins[0]["rect"].position.x - 30.0 * u], [r.wins[2]["rect"].end.x + 30.0 * u, r.size.x - 22.0 * u]]
	var i := 0
	for sp in spans:
		var x0: float = sp[0]
		var x1: float = sp[1]
		if x1 - x0 < 30.0 * u:
			continue
		for row in 2:
			var sy := r.top + (70.0 + 96.0 * row) * u
			var x := x0 + 3.0 * u
			while x < x1 - 14.0 * u:
				var w := minf((20.0 + 14.0 * Art.rnd(i)) * u, x1 - x - 3.0 * u)
				var h := (12.0 + 12.0 * Art.rnd(i + 5)) * u
				var col: Color = [Color(0.55, 0.42, 0.3), Color(0.24, 0.24, 0.38), Color(0.45, 0.18, 0.2), Color(0.62, 0.55, 0.42), Color(0.2, 0.32, 0.3)][i % 5]
				var box := Rect2(x, sy - h, w, h)
				b.rect(box.grow(1.0 * u), Art.OUTLINE)
				Art.hgrad(b, box, col.darkened(0.1), col.darkened(0.45))
				b.rect(Rect2(box.position.x - 1.0 * u, box.position.y, box.size.x + 2.0 * u, 3.0 * u), col.lightened(0.1))
				b.rect(Rect2(box.position.x + box.size.x * 0.45, box.position.y, 1.8 * u, box.size.y), Color(Art.GILT, 0.65))
				if i % 3 == 0:
					b.rect(Rect2(box.position.x + 3.0 * u, box.position.y + box.size.y * 0.45, box.size.x * 0.3, 4.0 * u), Color(0.9, 0.86, 0.76, 0.7))
				x += w + (3.0 + 8.0 * Art.rnd(i + 9)) * u
				i += 1
			var plank := Rect2(x0 - 4.0 * u, sy, x1 - x0 + 8.0 * u, 6.0 * u)
			b.rect(plank.grow(1.0 * u), Art.OUTLINE)
			Art.vgrad(b, plank, Art.OAK.lightened(0.1), Art.OAK.darkened(0.3))
			Art.vgrad(b, Rect2(plank.position.x, plank.end.y + 1.0 * u, plank.size.x, 10.0 * u), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))
			for bx in [plank.position.x + 8.0 * u, plank.end.x - 12.0 * u]:
				b.polygon(PackedVector2Array([Vector2(bx, plank.end.y), Vector2(bx + 5.0 * u, plank.end.y), Vector2(bx, plank.end.y + 9.0 * u)]), Art.GILT.darkened(0.25))


## The workshop car: a copper pipe along the top, tools hung on the boards
## between the windows, and bottles on shelves at the ends.
func _workshop(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	Art.pipe(b, Vector2(0, r.ceil_y + 12.0 * u), Vector2(s.x, r.ceil_y + 12.0 * u), 6.0 * u, Art.COPPER.darkened(0.1))
	var steel := Color(0.62, 0.62, 0.68)
	var k := 0
	for i in 2:
		var x0: float = r.wins[i]["rect"].end.x + 30.0 * u
		var x1: float = r.wins[i + 1]["rect"].position.x - 30.0 * u
		var lamp_x: float = r.lamps[i].x
		var x := x0
		while x < x1:
			if absf(x - lamp_x) > 30.0 * u:
				var y := r.top + 32.0 * u
				b.circle(Vector2(x, y - 6.0 * u), 1.6 * u, Art.GILT, 8)
				match k % 5:
					0:  # a wrench
						b.stroke(Vector2(x, y), Vector2(x, y + 40.0 * u), steel, 2.6 * u)
						b.arc(Vector2(x, y), 5.0 * u, PI * 0.3, PI * 2.2, 10, Art.OUTLINE, 4.6 * u)
						b.arc(Vector2(x, y), 5.0 * u, PI * 0.3, PI * 2.2, 10, steel, 2.6 * u)
					1:  # a saw
						b.poly(PackedVector2Array([Vector2(x - 4.0 * u, y + 8.0 * u), Vector2(x + 5.0 * u, y + 8.0 * u), Vector2(x + 2.0 * u, y + 46.0 * u), Vector2(x - 6.0 * u, y + 46.0 * u)]), steel.darkened(0.1), 0.9 * u)
						b.line(Vector2(x - 6.0 * u, y + 46.0 * u), Vector2(x - 4.0 * u, y + 8.0 * u), Color(1, 1, 1, 0.35), 0.8 * u)
						b.poly(PackedVector2Array([Vector2(x - 6.0 * u, y - 2.0 * u), Vector2(x + 7.0 * u, y - 2.0 * u), Vector2(x + 6.0 * u, y + 9.0 * u), Vector2(x - 5.0 * u, y + 9.0 * u)]), Art.OAK, 0.9 * u)
					2:  # a mallet
						b.stroke(Vector2(x, y + 8.0 * u), Vector2(x, y + 40.0 * u), Art.OAK.lightened(0.15), 2.4 * u)
						b.poly(PackedVector2Array([Vector2(x - 9.0 * u, y - 2.0 * u), Vector2(x + 9.0 * u, y - 2.0 * u), Vector2(x + 9.0 * u, y + 9.0 * u), Vector2(x - 9.0 * u, y + 9.0 * u)]), Art.OAK.darkened(0.1), 0.9 * u)
						b.rect(Rect2(x - 9.0 * u, y - 2.0 * u, 18.0 * u, 2.0 * u), Color(1, 1, 1, 0.15))
					3:  # calipers
						b.stroke(Vector2(x, y), Vector2(x - 6.0 * u, y + 38.0 * u), steel, 1.6 * u)
						b.stroke(Vector2(x, y), Vector2(x + 6.0 * u, y + 38.0 * u), steel, 1.6 * u)
						b.ball(Vector2(x, y), 2.6 * u, Art.GILT, false)
					4:  # a hammer
						b.stroke(Vector2(x, y + 4.0 * u), Vector2(x, y + 42.0 * u), Art.OAK.lightened(0.1), 2.4 * u)
						b.poly(PackedVector2Array([Vector2(x - 8.0 * u, y - 2.0 * u), Vector2(x + 10.0 * u, y), Vector2(x + 10.0 * u, y + 5.0 * u), Vector2(x - 8.0 * u, y + 6.0 * u)]), steel.darkened(0.15), 0.9 * u)
				k += 1
			x += 22.0 * u
	# Bottles at the ends of the car, catching the light.
	var spans := [[22.0 * u, r.wins[0]["rect"].position.x - 30.0 * u], [r.wins[2]["rect"].end.x + 30.0 * u, s.x - 22.0 * u]]
	var kinds: Array = Essence.KINDS.keys()
	var n := 0
	for sp in spans:
		var x0: float = sp[0]
		var x1: float = sp[1]
		if x1 - x0 < 24.0 * u:
			continue
		for row in 2:
			var sy := r.top + (70.0 + 96.0 * row) * u
			var x := x0 + 6.0 * u
			while x < x1 - 8.0 * u:
				var col := Essence.color(kinds[n % kinds.size()])
				var h := (14.0 + 8.0 * Art.rnd(n + 3)) * u
				var bw := (6.0 + 4.0 * Art.rnd(n + 7)) * u
				Art.bottle(b, Vector2(x + bw * 0.5, sy), bw, h, col, u)
				x += bw + (5.0 + 5.0 * Art.rnd(n)) * u
				n += 1
			var plank := Rect2(x0 - 4.0 * u, sy, x1 - x0 + 8.0 * u, 5.0 * u)
			b.rect(plank.grow(1.0 * u), Art.OUTLINE)
			Art.vgrad(b, plank, Art.OAK.lightened(0.05), Art.OAK.darkened(0.35))
			Art.vgrad(b, Rect2(plank.position.x, plank.end.y + 1.0 * u, plank.size.x, 9.0 * u), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))


## The ends of the car: walnut pillars, riveted, with the gap where two cars meet.
func _ends(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	for side in [0.0, 1.0]:
		var px: float = side * (s.x - 18.0 * u)
		Art.post(b, Rect2(px, 0, 18.0 * u, s.y), Art.WALNUT.darkened(0.15))
		b.rect(Rect2(px + (0.0 if side == 0.0 else 14.0 * u), 0, 4.0 * u, s.y), Color(0.02, 0.015, 0.02))
		Art.rivets(b, Vector2(px + 9.0 * u, r.ceil_y + 20.0 * u), Vector2(px + 9.0 * u, r.floor_y - 10.0 * u), 40.0 * u, 1.8 * u)


## A soft darkening towards the edges, so the eye rests on the middle.
func _vignette(b, r: Room) -> void:
	var s := r.size
	var u := r.u
	var vw := s.x * 0.15
	var dark := Color(Art.SHADOW, 0.5)
	var clear := Color(Art.SHADOW, 0.0)
	Art.hgrad(b, Rect2(0, 0, vw, s.y), dark, clear)
	Art.hgrad(b, Rect2(s.x - vw, 0, vw, s.y), clear, dark)
	Art.vgrad(b, Rect2(0, r.floor_y + 10.0 * u, s.x, s.y - r.floor_y - 10.0 * u), clear, Color(Art.SHADOW, 0.45))
	Art.vgrad(b, Rect2(0, 0, s.x, r.ceil_y + 26.0 * u), Color(Art.SHADOW, 0.3), clear)


# --- what moves, and its light: redrawn a few times a second ---------------------------

## The lamps swinging a little, the gauges' needles, the fire behind the
## firebox door and steam from the valve.
func paint_live(r: Room) -> void:
	var b := UI.Draw.Batch.new()
	var u := r.u
	for i in r.lamps.size():
		_lantern(b, r, i)
	if r.car == "engine":
		var reads := [0.62 + 0.035 * sin(t * 0.9) + 0.01 * sin(t * 8.1), 0.4 + 0.05 * sin(t * 0.6 + 1.0), 0.76 + 0.03 * sin(t * 1.3 + 2.0) + 0.008 * sin(t * 11.0)]
		for i in r.gauges.size():
			var c: Vector2 = r.gauges[i][0]
			var rad: float = r.gauges[i][1]
			var d := Vector2.from_angle(PI * 0.75 + PI * 1.5 * reads[i])
			b.line(c - d * rad * 0.2, c + d * rad * 0.8, Color(0.55, 0.1, 0.08), maxf(1.1, rad * 0.09))
			b.circle(c, maxf(1.6, rad * 0.13), Art.OUTLINE, 10)
			b.circle(c, maxf(1.0, rad * 0.08), Art.GILT, 8)
		# The fire through the vent.
		var v := _vent(r)
		var f := 0.85 + 0.15 * sin(t * 9.0) * sin(t * 5.3 + 1.0)
		Art.vgrad(b, v, Art.FLAME.darkened(0.3) * Color(f, f, f), Color(1.0, 0.82, 0.45) * Color(f, f, f))
		for k in 4:
			var fx := v.position.x + v.size.x * (0.15 + 0.23 * k) + sin(t * 6.0 + k * 2.0) * 2.0 * u
			var fh := v.size.y * (0.5 + 0.35 * sin(t * 7.3 + k * 1.7))
			b.polygon(PackedVector2Array([Vector2(fx - 4.0 * u, v.end.y), Vector2(fx, v.end.y - fh), Vector2(fx + 4.0 * u, v.end.y)]), Color(1.0, 0.95, 0.7, 0.8))
		for k in 7:
			b.rect(Rect2(v.position.x + v.size.x * (k + 0.5) / 7.0 - 1.4 * u, v.position.y, 2.8 * u, v.size.y), Art.IRON.lightened(0.1))
		# Steam from the valve.
		for k in 3:
			var p := fposmod(t * 0.45 + k / 3.0, 1.0)
			var at := r.steam + Vector2(p * 16.0 + sin(t + k) * 3.0, -12.0 - p * 30.0) * u
			b.circle(at, (3.0 + p * 10.0) * u, Color(0.78, 0.75, 0.84, 0.2 * (1.0 - p) * minf(1.0, p * 6.0)), 16)
	b.flush(r.live)


## A brass lantern on a chain, swinging a little: a cap, a warm glass with
## the flame inside, the bars of its cage and a finial.
func _lantern(b, r: Room, i: int) -> void:
	var u := r.u
	var at := _lamp_at(r, i)
	var c: Vector2 = at[0]
	var xf := Transform2D(at[1], c)
	var hang: Vector2 = r.lamps[i]
	var top: Vector2 = xf * Vector2(0, -14.0 * u)
	b.line(hang, top, Art.GILT_LO, 1.4 * u)
	var n := int(hang.distance_to(top) / (4.0 * u))
	for k in n:
		b.circle(hang.lerp(top, (k + 0.5) / n), 1.1 * u, Art.GILT.darkened(0.2), 6)
	var P := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(xf * (p * u))
		return out
	b.poly(P.call([Vector2(-7, -9), Vector2(7, -9), Vector2(5.5, 8), Vector2(-5.5, 8)]), Color(1.0, 0.8, 0.5), 1.0 * u)
	b.polygon(P.call([Vector2(-5.5, -7), Vector2(5.5, -7), Vector2(4.2, 6), Vector2(-4.2, 6)]), Color(1.0, 0.88, 0.62))
	b.polygon(P.call(Art.oval(Vector2(0, 0.5), Vector2(2.0, 4.0), 10)), Color(1.0, 0.98, 0.88))
	for x in [-7.0, 0.0, 7.0]:
		b.line(xf * (Vector2(x, -9) * u), xf * (Vector2(x * 0.79, 8) * u), Color(Art.GILT_LO, 0.9), 1.2 * u)
	b.line(xf * (Vector2(-6.3, -1) * u), xf * (Vector2(6.3, -1) * u), Color(Art.GILT_LO, 0.8), 1.0 * u)
	b.poly(P.call([Vector2(-9, -9), Vector2(9, -9), Vector2(5, -14), Vector2(-5, -14)]), Art.GILT.darkened(0.15), 1.0 * u)
	b.polygon(P.call([Vector2(-8, -9.5), Vector2(-3, -9.5), Vector2(-2, -13.5), Vector2(-4.5, -13.5)]), Color(Art.GILT_HI, 0.55))
	b.poly(P.call([Vector2(-7, 8), Vector2(7, 8), Vector2(4, 12), Vector2(-4, 12)]), Art.GILT.darkened(0.3), 1.0 * u)
	b.circle(xf * (Vector2(0, 14) * u), 1.8 * u, Art.GILT, 8)


## The light, drawn once (it brightens and dims: _breathe): each lamp's warm
## pool on the wall, the panelling and the floor, a faint shaft below it;
## the firebox's glow on the cab; a gleam on the gauges.
func paint_glow(r: Room) -> void:
	var b := UI.Draw.Batch.new()
	var u := r.u
	for i in r.lamps.size():
		var hang: Vector2 = r.lamps[i]
		var c := hang + Vector2(0, r.chain + 13.0 * u)
		Art.quad(b, c + Vector2(-6.0, 10.0) * u, c + Vector2(6.0, 10.0) * u, Vector2(c.x + 110.0 * u, r.floor_y), Vector2(c.x - 110.0 * u, r.floor_y),
			Color(Art.LAMP, 0.05), Color(Art.LAMP, 0.05), Color(Art.LAMP, 0.0), Color(Art.LAMP, 0.0))
		Art.light(b, c + Vector2(0, 26.0 * u), Vector2(190.0, 165.0) * u, Color(Art.LAMP, 0.26))
		Art.light(b, Vector2(c.x, r.wain + 20.0 * u), Vector2(160.0, 70.0) * u, Color(Art.LAMP, 0.12))
		Art.light(b, Vector2(c.x, r.floor_y + 18.0 * u), Vector2(210.0, 30.0) * u, Color(Art.LAMP, 0.26))
	if r.car == "engine":
		var fc := r.fire.get_center()
		Art.light(b, fc, Vector2(230.0, 170.0) * u, Color(Art.FLAME, 0.28))
		Art.light(b, Vector2(fc.x, r.floor_y + 22.0 * u), Vector2(320.0, 40.0) * u, Color(Art.FLAME, 0.26))
		for g in r.gauges:
			Art.light(b, g[0], Vector2(g[1], g[1]) * 1.6, Color(Art.LAMP, 0.08))
	b.flush(r.glow)


## The light that moves: each lamp's bright glow swinging with it, dust
## drifting down through its light, and the firebox's hot heart flickering.
func paint_sparks(r: Room) -> void:
	var b := UI.Draw.Batch.new()
	var u := r.u
	for i in r.lamps.size():
		var c: Vector2 = _lamp_at(r, i)[0]
		var k := 0.93 + 0.07 * sin(t * 2.3 + i * 1.9 + r.index)
		Art.light(b, c, Vector2(50.0, 50.0) * u, Color(Art.LAMP, 0.34 * k))
		var fall := r.floor_y - c.y - 24.0 * u
		for m in 12:
			var seed := i * 31 + m * 7 + r.index * 97
			var life := fposmod(t * 0.035 * (0.6 + Art.rnd(seed)) + Art.rnd(seed + 1), 1.0)
			var y := c.y + 24.0 * u + life * fall
			var spread := 20.0 * u + (y - c.y) * 0.45
			var p := Vector2(c.x + (Art.rnd(seed + 2) - 0.5) * 2.0 * spread + sin(t * 0.5 + seed) * 8.0 * u, y)
			var a := 0.55 * sin(life * PI) * (1.0 - absf(p.x - c.x) / (spread * 1.2))
			if a > 0.02:
				b.circle(p, (0.7 + Art.rnd(seed + 3) * 0.8) * u, Color(1.0, 0.86, 0.62, a), 6)
	if r.car == "engine":
		var f := 0.8 + 0.14 * sin(t * 9.0) * sin(t * 5.3 + 1.0) + 0.06 * sin(t * 17.0)
		Art.light(b, r.fire.get_center(), Vector2(70.0, 46.0) * u, Color(1.0, 0.7, 0.35, 0.4 * f))
	b.flush(r.sparks)


# --- furniture: drawn behind the cars' things -------------------------------------------

## A piece of the car's furniture, drawn behind the slots it holds, so the
## things you can choose sit where they belong: the heirloom wardrobe, your
## pack, the storage chest, the outfitter's shelves, rail and glass case, the
## destination board, the bench's drawers, a placard. It watches its grid
## (`watch`) to put a shelf under each row or a hook over each slot.
class Furnish extends PanelContainer:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
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
		var BR := Art.GILT
		var WAL := Art.WALNUT
		match kind:
			"rack":
				# A walnut wardrobe: a carved crown, grained doors' frame, a
				# velvet back lit from above with a faint mannequin, brass hooks
				# and little feet.
				_shadow(b, r)
				b.rect(r, Art.OUTLINE)
				var body := r.grow(-1.5)
				Art.vgrad(b, body, WAL.lightened(0.08), WAL.darkened(0.25))
				Art.grain(b, body, WAL, 7, 1.0, true, false)
				var inner := r.grow(-8.0)
				Art.bevel(b, inner.grow(2.0), WAL.darkened(0.1), 2.0, false)
				Art.vgrad(b, inner, Art.VELVET_DARK.lightened(0.12), Art.VELVET_DARK.darkened(0.3))
				Art.light(b, Vector2(inner.get_center().x, inner.position.y), Vector2(inner.size.x * 0.75, inner.size.y * 0.55), Color(Art.LAMP, 0.09))
				var c := Vector2(inner.get_center().x, inner.position.y + inner.size.y * 0.3)
				var ghost := Color(0.26, 0.13, 0.16, 0.8)
				b.dot(c + Vector2(0, -inner.size.y * 0.12), inner.size.x * 0.1, ghost)
				b.polygon(PackedVector2Array([c + Vector2(-inner.size.x * 0.3, 0), c + Vector2(inner.size.x * 0.3, 0),
					c + Vector2(inner.size.x * 0.2, inner.size.y * 0.5), c + Vector2(inner.size.x * 0.12, inner.size.y * 0.66),
					c + Vector2(-inner.size.x * 0.12, inner.size.y * 0.66), c + Vector2(-inner.size.x * 0.2, inner.size.y * 0.5)]), ghost)
				b.rect(Rect2(c.x - 2.0, c.y + inner.size.y * 0.66, 4.0, inner.size.y * 0.3), ghost)
				# The crown along the top, and the feet.
				var crown := Rect2(r.position.x - 4.0, r.position.y - 7.0, r.size.x + 8.0, 9.0)
				b.rect(crown.grow(1.0), Art.OUTLINE)
				Art.vgrad(b, crown, WAL.lightened(0.18), WAL.darkened(0.3))
				b.rect(Rect2(crown.position.x, crown.end.y - 2.2, crown.size.x, 1.2), Color(BR, 0.75))
				var cc := Vector2(crown.get_center().x, crown.position.y)
				b.poly(PackedVector2Array([cc + Vector2(-14, 1), cc + Vector2(-6, -5), cc + Vector2(0, -7), cc + Vector2(6, -5), cc + Vector2(14, 1)]), WAL.lightened(0.05), 1.0)
				b.ball(cc + Vector2(0, -2), 2.4, BR, false)
				for fx in [r.position.x + 5.0, r.end.x - 17.0]:
					b.rect(Rect2(fx - 1.0, r.end.y - 1.0, 14.0, 6.0), Art.OUTLINE)
					Art.vgrad(b, Rect2(fx, r.end.y, 12.0, 4.0), WAL.darkened(0.1), WAL.darkened(0.5))
				for i in 4:
					Art.rivet(b, Vector2(r.position.x + r.size.x * (0.2 + 0.2 * i), r.position.y + 4.5), 2.0)
			"pack":
				# A leather pack: a rounded, shaded body, a stitched flap, two
				# straps with brass buckles, and pockets at its sides.
				var body := Rect2(r.position + Vector2(2, 8), r.size - Vector2(4, 10))
				_shadow(b, body)
				for side in [-1.0, 1.0]:
					var pk := Rect2(Vector2(body.position.x - 5.0 if side < 0.0 else body.end.x - 3.0, body.position.y + body.size.y * 0.3), Vector2(8.0, body.size.y * 0.6))
					b.rect(pk.grow(1.2), Art.OUTLINE)
					Art.hgrad(b, pk, Art.LEATHER.darkened(0.1 if side < 0.0 else 0.4), Art.LEATHER.darkened(0.4 if side < 0.0 else 0.1))
				b.rect(body.grow(1.5), Art.OUTLINE)
				Art.vgrad(b, body, Art.LEATHER.lightened(0.04), Art.LEATHER.darkened(0.3))
				for k in 3:
					var y := body.position.y + body.size.y * (0.45 + 0.17 * k)
					b.line(Vector2(body.position.x + 6.0, y), Vector2(body.end.x - 6.0, y + 2.0 * sin(k * 2.0)), Color(0, 0, 0, 0.08), 1.2)
				var flap := Rect2(body.position, Vector2(body.size.x, 14))
				Art.vgrad(b, flap, Art.LEATHER.lightened(0.14), Art.LEATHER.lightened(0.02))
				b.rect(Rect2(flap.position.x, flap.end.y, flap.size.x, 2.0), Color(0, 0, 0, 0.45))
				b.rect(Rect2(flap.position.x, flap.position.y, flap.size.x, 1.2), Color(1, 0.85, 0.65, 0.2))
				_stitch(b, Rect2(flap.position.x + 4.0, flap.position.y + 3.0, flap.size.x - 8.0, flap.size.y - 6.0), Color(0.85, 0.7, 0.48, 0.55))
				_stitch(b, body.grow(-4.0), Color(0.75, 0.6, 0.4, 0.4))
				for k in [0.22, 0.78]:
					var sx: float = body.position.x + body.size.x * k
					b.rect(Rect2(sx - 6.0, r.position.y - 1.0, 12.0, 25.0), Art.OUTLINE)
					Art.hgrad(b, Rect2(sx - 5.0, r.position.y, 10.0, 23.0), Art.LEATHER.darkened(0.15), Art.LEATHER.darkened(0.45))
					var bk := Rect2(sx - 7.0, r.position.y + 14.0, 14.0, 8.0)
					b.rect(bk.grow(1.0), Art.OUTLINE)
					Art.bevel(b, bk, BR.darkened(0.15), 1.5)
					b.rect(Rect2(bk.position + Vector2(3.0, 2.5), Vector2(8.0, 3.0)), Art.LEATHER.darkened(0.4))
					b.rect(Rect2(sx - 0.6, bk.position.y + 1.5, 1.2, 5.0), BR.lightened(0.3))
			"chest":
				# An oak chest: grained planks, iron bands, brass corners, a lock
				# plate with its keyhole, and a sunk bed for each space.
				_shadow(b, r)
				b.rect(r, Art.OUTLINE)
				var body := r.grow(-1.5)
				Art.vgrad(b, body, Art.OAK.lightened(0.08), Art.OAK.darkened(0.25))
				var y := body.position.y
				var k := 0
				while y < body.end.y - 2.0:
					var pl := Rect2(body.position.x, y, body.size.x, minf(14.0, body.end.y - y))
					Art.grain(b, pl, Art.OAK, 30 + k, 1.0, false, false)
					b.rect(Rect2(pl.position.x, pl.end.y - 1.2, pl.size.x, 1.2), Color(0.18, 0.1, 0.05, 0.9))
					b.rect(Rect2(pl.position.x, pl.position.y, pl.size.x, 0.8), Color(1, 0.85, 0.6, 0.12))
					y += 14.0
					k += 1
				for kx in [0.12, 0.88]:
					var band := Rect2(r.position.x + r.size.x * kx - 4.0, r.position.y + 1.5, 8.0, r.size.y - 3.0)
					Art.post(b, band, Art.IRON.lightened(0.3))
					Art.rivets(b, band.position + Vector2(4.0, 8.0), Vector2(band.position.x + 4.0, band.end.y - 8.0), 22.0, 1.5, Art.IRON.lightened(0.6))
				for cx in [r.position.x + 1.5, r.end.x - 13.5]:
					for cy in [r.position.y + 1.5, r.end.y - 13.5]:
						var corner := Rect2(cx, cy, 12, 12)
						Art.bevel(b, corner, BR.darkened(0.2), 1.6)
						Art.rivet(b, corner.get_center(), 1.4)
				for c in _cells():
					Art.bevel(b, c.grow(3.0), Color(0.16, 0.09, 0.05), 1.5, false)
				var lock := Vector2(r.get_center().x, r.end.y - 7.0)
				var lp := Rect2(lock + Vector2(-8, -6), Vector2(16, 12))
				b.rect(lp.grow(1.0), Art.OUTLINE)
				Art.bevel(b, lp, BR.darkened(0.05), 1.6)
				b.dot(lock + Vector2(0, -1), 2.0, Art.OUTLINE)
				b.rect(Rect2(lock.x - 0.8, lock.y - 1.0, 1.6, 4.0), Art.OUTLINE)
			"shelf":
				# Shelves on the wall: a grained back, a plank under each row on
				# brass brackets, each casting a shadow.
				_shadow(b, r)
				Art.vgrad(b, r, Color(0.17, 0.1, 0.07, 0.95), Color(0.1, 0.06, 0.045, 0.95))
				Art.grain(b, r, Color(0.2, 0.12, 0.08), 11, 1.0, true, false)
				var crown := Rect2(r.position.x - 3.0, r.position.y - 3.0, r.size.x + 6.0, 5.0)
				b.rect(crown.grow(1.0), Art.OUTLINE)
				Art.vgrad(b, crown, WAL.lightened(0.2), WAL.darkened(0.2))
				var rows := {}
				for c in _cells():
					rows[int(c.end.y)] = true
				for ry in rows:
					var pl := Rect2(r.position.x + 2, ry + 1.0, r.size.x - 4, 5)
					Art.vgrad(b, Rect2(pl.position.x, pl.end.y, pl.size.x, 9.0), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
					b.rect(pl.grow(1.0), Art.OUTLINE)
					Art.vgrad(b, pl, Art.OAK.lightened(0.15), Art.OAK.darkened(0.25))
					b.rect(Rect2(pl.position, Vector2(pl.size.x, 1.2)), Color(1, 0.85, 0.6, 0.35))
					for bx in [pl.position.x + 10, pl.end.x - 14]:
						b.polygon(PackedVector2Array([Vector2(bx, pl.end.y), Vector2(bx + 5, pl.end.y), Vector2(bx, pl.end.y + 8)]), BR.darkened(0.2))
						b.line(Vector2(bx + 0.5, pl.end.y + 0.5), Vector2(bx + 0.5, pl.end.y + 7.0), Color(BR.lightened(0.4), 0.7), 1.0)
			"rail":
				# The outfit rail: a brass rod (lit along its top) with a steel
				# hanger above each piece.
				_shadow(b, r)
				Art.vgrad(b, r, Color(0.12, 0.08, 0.07, 0.85), Color(0.07, 0.05, 0.05, 0.85))
				var rods := {}
				for c in _cells():
					rods[int(c.position.y) - 11] = true
				for ry in rods:
					b.rect(Rect2(r.position.x + 3, ry - 3.0, r.size.x - 6, 6.0), Art.OUTLINE)
					Art.bar(b, Rect2(r.position.x + 4, ry - 2.0, r.size.x - 8, 4.0))
					for ex in [r.position.x + 4.0, r.end.x - 4.0]:
						b.ball(Vector2(ex, ry), 3.2, BR, false)
				for c in _cells():
					var hx: float = c.get_center().x
					var ry: float = c.position.y - 11.0
					var steel := Color(0.74, 0.74, 0.8)
					b.arc(Vector2(hx, ry - 1.0), 3.0, PI * 0.9, TAU * 1.05, 8, steel, 1.4)
					b.line(Vector2(hx, ry + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
					b.line(Vector2(hx - c.size.x * 0.34, c.position.y + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
					b.line(Vector2(hx + c.size.x * 0.34, c.position.y + 2.0), Vector2(hx, ry + 5.0), steel, 1.4)
					b.line(Vector2(hx - c.size.x * 0.34, c.position.y + 1.0), Vector2(hx - 1.0, ry + 4.0), Color(1, 1, 1, 0.3), 0.8)
			"case":
				# A glass case on a walnut plinth: brass posts, a velvet bed,
				# a little light inside, and the glass's reflections.
				_shadow(b, r)
				var plinth := Rect2(r.position.x, r.end.y - 12.0, r.size.x, 12.0)
				b.rect(plinth.grow(1.0), Art.OUTLINE)
				Art.vgrad(b, plinth, WAL.lightened(0.12), WAL.darkened(0.3))
				Art.grain(b, plinth, WAL, 5, 1.0, false, false)
				b.rect(Rect2(plinth.position, Vector2(plinth.size.x, 1.6)), Color(BR, 0.8))
				var glass := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y - 16))
				Art.vgrad(b, glass, Color(0.55, 0.62, 0.8, 0.08), Color(0.4, 0.45, 0.6, 0.16))
				Art.vgrad(b, Rect2(glass.position.x, glass.end.y - 12.0, glass.size.x, 12.0), Art.VELVET_DARK.lightened(0.15), Art.VELVET_DARK)
				Art.light(b, Vector2(glass.get_center().x, glass.position.y + 4.0), Vector2(glass.size.x * 0.6, glass.size.y * 0.8), Color(Art.LAMP, 0.1))
				b.rect(Rect2(glass.position.x - 1.0, glass.position.y - 2.0, glass.size.x + 2.0, 4.0), Art.OUTLINE)
				Art.bar(b, Rect2(glass.position.x - 1.0, glass.position.y - 1.5, glass.size.x + 2.0, 3.0))
				for gx in [glass.position.x - 1.0, glass.end.x - 2.0]:
					Art.post(b, Rect2(gx, glass.position.y, 3.0, glass.size.y), BR.darkened(0.15))
				b.polygon(PackedVector2Array([glass.position + Vector2(7, 4), glass.position + Vector2(16, 4), glass.position + Vector2(7, glass.size.y * 0.75)]), Color(1, 1, 1, 0.12))
				b.polygon(PackedVector2Array([Vector2(glass.end.x - 12, glass.position.y + 4), Vector2(glass.end.x - 8, glass.position.y + 4), Vector2(glass.end.x - 14, glass.position.y + glass.size.y * 0.5)]), Color(1, 1, 1, 0.08))
			"board":
				# The destination board: slate in a heavy brass frame, riveted,
				# with chalk dust on it.
				_shadow(b, r)
				b.rect(r, Art.OUTLINE)
				Art.bevel(b, r.grow(-1.0), BR.darkened(0.3), 4.0)
				var slate := r.grow(-5.0)
				b.rect(slate.grow(1.0), Color(0, 0, 0, 0.6))
				Art.vgrad(b, slate, Color(0.075, 0.115, 0.11), Color(0.04, 0.065, 0.065))
				for k in 5:
					var p := slate.position + Vector2(slate.size.x * Art.rnd(k * 3 + 1), slate.size.y * Art.rnd(k * 3 + 2))
					b.polygon(Art.oval(p, Vector2(30.0 + 30.0 * Art.rnd(k), 8.0 + 6.0 * Art.rnd(k + 4)), 14), Color(0.8, 0.85, 0.82, 0.025))
				Art.light(b, Vector2(slate.get_center().x, slate.position.y), Vector2(slate.size.x * 0.6, slate.size.y * 0.5), Color(Art.LAMP, 0.05))
				for cx in [r.position.x + 8, r.end.x - 8]:
					for cy in [r.position.y + 8, r.end.y - 8]:
						Art.rivet(b, Vector2(cx, cy), 2.4)
			"drawers":
				# The bench's cabinet: a grained walnut case, each drawer sunk in it.
				_shadow(b, r)
				b.rect(r, Art.OUTLINE)
				var body := r.grow(-1.5)
				Art.vgrad(b, body, WAL.lightened(0.06), WAL.darkened(0.25))
				Art.grain(b, body, WAL, 19, 1.0, false, false)
				for c in _cells():
					Art.bevel(b, c.grow(2.0), WAL.darkened(0.4), 1.5, false)
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

	## A soft shadow under a piece, cast down and to the right.
	func _shadow(b, r: Rect2) -> void:
		b.rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.18))
		b.rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.22))

	func _stitch(b, r: Rect2, col: Color) -> void:
		var x := r.position.x
		while x < r.end.x:
			b.rect(Rect2(x, r.position.y, 4, 1), col)
			b.rect(Rect2(x, r.end.y, 4, 1), col)
			x += 8.0


## The outfitter behind his counter, drawn in code: an old climber in the
## lamplight, his goggles pushed up, bushy brows and a curled grey moustache,
## a tape measure round his neck over a waistcoat and brass-buttoned coat,
## a watch chain, and his hands on the counter by a little brass bell. He
## blinks now and then.
class Outfitter extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	const COAT := Color(0.3, 0.19, 0.14)
	const VEST := Color(0.3, 0.09, 0.15)
	const TAPE := Color(0.9, 0.84, 0.64)
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
		Art.light(b, c + Vector2(-r * 0.3, -r * 0.2), Vector2(r * 3.4, r * 2.8), Color(Art.LAMP, 0.2))
		# His coat, lit from the left, down to the counter.
		var top := c.y + r * 0.7
		var foot := h * 0.86
		var coat := PackedVector2Array([Vector2(c.x - r * 1.7, foot), Vector2(c.x - r * 1.45, top + r * 0.3), Vector2(c.x - r * 0.6, top),
			Vector2(c.x + r * 0.6, top), Vector2(c.x + r * 1.45, top + r * 0.3), Vector2(c.x + r * 1.7, foot)])
		b.poly(coat, COAT, 1.4)
		b.polygon(PackedVector2Array([Vector2(c.x + r * 0.2, top), Vector2(c.x + r * 0.6, top), Vector2(c.x + r * 1.45, top + r * 0.3), Vector2(c.x + r * 1.7, foot), Vector2(c.x + r * 0.5, foot)]), COAT.darkened(0.25))
		b.line(Vector2(c.x - r * 1.45, top + r * 0.32), Vector2(c.x - r * 0.62, top + r * 0.02), Color(1, 0.8, 0.6, 0.2), maxf(1.0, r * 0.06))
		# The waistcoat, the shirt and a cravat.
		b.polygon(PackedVector2Array([Vector2(c.x - r * 0.62, top + r * 0.05), Vector2(c.x + r * 0.62, top + r * 0.05), Vector2(c.x + r * 0.55, foot), Vector2(c.x - r * 0.55, foot)]), VEST)
		b.polygon(PackedVector2Array([Vector2(c.x - r * 0.36, top), Vector2(c.x + r * 0.36, top), Vector2(c.x, top + r * 0.95)]), Color(0.88, 0.84, 0.76))
		b.polygon(PackedVector2Array([Vector2(c.x - r * 0.16, top + r * 0.08), Vector2(c.x + r * 0.16, top + r * 0.08), Vector2(c.x + r * 0.1, top + r * 0.42), Vector2(c.x, top + r * 0.5), Vector2(c.x - r * 0.1, top + r * 0.42)]), Color(0.55, 0.12, 0.12))
		b.dot(Vector2(c.x, top + r * 0.12), r * 0.08, Color(0.45, 0.08, 0.08))
		for i in 3:
			b.dot(Vector2(c.x + r * 0.05, top + r * (0.75 + 0.25 * i)), r * 0.045, Art.GILT)
		# The lapels.
		for side in [-1.0, 1.0]:
			b.poly(PackedVector2Array([Vector2(c.x + side * r * 0.38, top - r * 0.02), Vector2(c.x + side * r * 0.66, top + r * 0.04), Vector2(c.x + side * r * 0.6, top + r * 0.6), Vector2(c.x + side * r * 0.2, top + r * 1.05)]),
				COAT.darkened(0.12 if side < 0.0 else 0.32), 0.8)
		for i in 3:
			b.dot(Vector2(c.x + r * 0.78, top + r * (0.55 + 0.3 * i)), r * 0.06, Art.GILT)
			b.dot(Vector2(c.x + r * 0.76, top + r * (0.53 + 0.3 * i)), r * 0.025, Art.GILT_HI)
		# His watch chain, from a button to his pocket.
		var chain := PackedVector2Array()
		for k in 9:
			var a := k / 8.0
			chain.append(Vector2(lerpf(c.x + r * 0.05, c.x - r * 0.48, a), top + r * (1.0 + 0.22 * sin(a * PI))))
		b.path(chain, Art.GILT, maxf(1.0, r * 0.04))
		# A tape measure round his neck, hanging down over his lapels.
		for side in [-1.0, 1.0]:
			var a0 := Vector2(c.x + side * r * 0.42, top - r * 0.08)
			var a1 := Vector2(c.x + side * r * 0.5, foot - r * 0.1)
			var n := (a1 - a0).orthogonal().normalized() * r * 0.07
			b.poly(PackedVector2Array([a0 - n, a0 + n, a1 + n, a1 - n]), TAPE, 0.8)
			for k in 7:
				var p := a0.lerp(a1, (k + 0.5) / 7.0)
				b.line(p - n, p - n * 0.2, Color(0.25, 0.2, 0.15, 0.8), maxf(0.8, r * 0.02))
		OutfitterFace.head_into(b, c, r, open)
		# The counter: grained oak, a brass edge, a panelled front.
		var counter := Rect2(0, h * 0.82, w, h * 0.18)
		b.rect(counter.grow(1.0), UI.OUTLINE)
		Art.vgrad(b, counter, Art.OAK.lightened(0.06), Art.OAK.darkened(0.35))
		Art.grain(b, counter, Art.OAK, 41, 1.0, false, false)
		Art.bar(b, Rect2(counter.position.x, counter.position.y, w, 4.0))
		Art.vgrad(b, Rect2(counter.position.x, counter.position.y + 4.0, w, 6.0), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))
		# His hands on it, and a little brass bell.
		for side in [-1.0, 1.0]:
			b.ball(Vector2(c.x + side * r * 0.9, h * 0.82), r * 0.22, OutfitterFace.SKIN)
		var bell := Vector2(w * 0.86, h * 0.82)
		b.poly(PackedVector2Array([bell + Vector2(-r * 0.32, 0), bell + Vector2(r * 0.32, 0), bell + Vector2(r * 0.22, -r * 0.2), bell + Vector2(0, -r * 0.3), bell + Vector2(-r * 0.22, -r * 0.2)]), Art.GILT.darkened(0.1), 1.0)
		b.dot(bell + Vector2(-r * 0.08, -r * 0.2), r * 0.06, Art.GILT_HI)
		b.dot(bell + Vector2(0, -r * 0.36), r * 0.06, Art.GILT)
		b.flush(self)


## The outfitter's face, small, beside what he says: drawn in code.
class OutfitterFace extends Control:
	const BRASS := Color(0.86, 0.64, 0.3)
	const SKIN := Color(0.86, 0.68, 0.54)
	const HAIR := Color(0.8, 0.78, 0.76)
	const COAT := Color(0.3, 0.19, 0.14)
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

	## His head: ears, grey hair at the sides and a shining crown, goggles
	## pushed up on his brow, bushy brows, eyes (half shut while blinking),
	## rosy cheeks, a big nose and a curled grey moustache.
	static func head_into(b, c: Vector2, r: float, eyes_open: bool) -> void:
		for side in [-1.0, 1.0]:
			b.ball(c + Vector2(side * r * 0.6, r * 0.02), r * 0.13, SKIN.darkened(0.1), false)
		b.ball(c + Vector2(0, -r * 0.05), r * 0.62, SKIN)
		for side in [-1.0, 1.0]:
			b.dot(c + Vector2(side * r * 0.55, -r * 0.1), r * 0.19, HAIR.darkened(0.1))
			b.dot(c + Vector2(side * r * 0.5, -r * 0.22), r * 0.13, HAIR)
		b.rect(Rect2(c + Vector2(-r * 0.62, -r * 0.5), Vector2(r * 1.24, r * 0.14)), Color(0.22, 0.14, 0.1))
		for side in [-1.0, 1.0]:
			var g := c + Vector2(side * r * 0.24, -r * 0.44)
			b.dot(g, r * 0.2, Color(0.1, 0.08, 0.06))
			b.dot(g + Vector2(r * 0.03, r * 0.03), r * 0.13, Color(0.2, 0.3, 0.35))
			b.arc(g, r * 0.2, 0.0, TAU, 14, BRASS, maxf(1.2, r * 0.08))
			b.dot(g + Vector2(-r * 0.06, -r * 0.06), r * 0.05, Color(0.85, 0.92, 1.0, 0.8))
		# Brows, eyes and cheeks.
		var k := 1.0 if eyes_open else 0.2
		for side in [-1.0, 1.0]:
			b.polygon(PackedVector2Array([c + Vector2(side * r * 0.08, -r * 0.2), c + Vector2(side * r * 0.36, -r * 0.27), c + Vector2(side * r * 0.42, -r * 0.2), c + Vector2(side * r * 0.12, -r * 0.15)]), HAIR)
			b.rect(Rect2(c + Vector2(side * r * 0.22 - r * 0.06, -r * 0.12 - r * 0.04 * k), Vector2(r * 0.12, r * 0.08 * k + 0.6)), Color(0.12, 0.08, 0.06))
			b.dot(c + Vector2(side * r * 0.32, r * 0.08), r * 0.1, Color(0.9, 0.4, 0.35, 0.3))
		b.dot(c + Vector2(0, r * 0.08), r * 0.11, SKIN.darkened(0.15))
		b.dot(c + Vector2(-r * 0.03, r * 0.05), r * 0.04, Color(1, 1, 1, 0.35))
		# The moustache, curled up at its ends.
		b.polygon(PackedVector2Array([c + Vector2(-r * 0.42, r * 0.28), c + Vector2(-r * 0.1, r * 0.16), c + Vector2(0, r * 0.22),
			c + Vector2(r * 0.1, r * 0.16), c + Vector2(r * 0.42, r * 0.28), c + Vector2(r * 0.2, r * 0.32), c + Vector2(0, r * 0.27),
			c + Vector2(-r * 0.2, r * 0.32)]), HAIR)
		for side in [-1.0, 1.0]:
			b.arc(c + Vector2(side * r * 0.44, r * 0.2), r * 0.08, (PI * 0.5 if side > 0.0 else PI * 0.5), (PI * 0.5 - PI * 1.3 if side > 0.0 else PI * 0.5 + PI * 1.3), 6, HAIR, maxf(1.0, r * 0.06))

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
		UI.draw_label(self, Vector2(0, plate.end.y + 20.0), word, 18, UI.GOLD if not disabled else UI.FAINT, HORIZONTAL_ALIGNMENT_CENTER, w)
		if sub != "":
			draw_string(font, Vector2(0, plate.end.y + 35.0), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(UI.TEXT, 0.85))


## The brass band along the bottom (your crystals): riveted brass over dark
## wood (`at_top`: a band along the top, edged below).
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


# --- the workshop's bench ----------------------------------------------------------

## The workshop car's corner, drawn in code over its counters: grained boards
## and a hanging lamp's light, a pegboard of tools, a shelf of bottles in the
## six essences' colours catching the light, the workbench with a vice and a
## flask steaming over a small flame, and the Rune Artist's slate, its runes
## glowing when you carry the Rune Artist's mark (`lit`).
class Bench extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	const Gear := preload("res://scripts/gear.gd")
	const Essence := preload("res://scripts/essence.gd")
	const WOOD := Color(0.42, 0.27, 0.16)
	const SLATE := Color(0.15, 0.16, 0.2)
	const RUNE := Color(0.62, 0.66, 1.0)  # the Rune Artist's colour (bonds.gd)
	var lit := false
	var t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		_acc += delta
		# (the flask's steam and flame and the slate's glow: a few times a
		# second, and only while it's on screen)
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
		# The wall: upright boards, grained, in a dark frame.
		b.rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.3))
		b.rect(Rect2(Vector2.ZERO, size), UI.OUTLINE)
		var bw := 9.0 * u
		var x := 1.5
		var i := 0
		while x < w - 1.5:
			var col := Art.BOARDS.lightened(0.04 * (i % 3))
			var br := Rect2(x, 1.5, minf(bw, w - 1.5 - x), h - 3.0)
			Art.vgrad(b, br, col.lightened(0.04), col.darkened(0.3))
			b.rect(Rect2(x, 1.5, 0.8 * u, h - 3.0), Color(0, 0, 0, 0.5))
			x += bw
			i += 1
		# The lamp's warm light from the top left.
		var lamp := Vector2(w * 0.16, 10.0 * u)
		Art.light(b, lamp + Vector2(0, 14.0 * u), Vector2(70.0, 60.0) * u, Color(Art.LAMP, 0.22))
		b.line(Vector2(lamp.x, 1.5), lamp + Vector2(0, -3.0 * u), Art.GILT_LO, 1.0 * u)
		b.polygon(PackedVector2Array([lamp + Vector2(-7, 2) * u, lamp + Vector2(0, -4) * u, lamp + Vector2(7, 2) * u]), Art.GILT.darkened(0.1))
		b.polygon(PackedVector2Array([lamp + Vector2(-6, 2) * u, lamp + Vector2(-1, -2.5) * u, lamp + Vector2(-1, 2) * u]), Color(Art.GILT_HI, 0.5))
		b.dot(lamp + Vector2(0, 4.5 * u), 3.4 * u, Color(1.0, 0.9, 0.65))
		Art.light(b, lamp + Vector2(0, 4.5 * u), Vector2(12.0, 12.0) * u, Color(1.0, 0.85, 0.5, 0.5))
		# A pegboard of tools: a hammer, tongs and a file.
		var peg := Rect2(w * 0.3, 7.0 * u, w * 0.26, h * 0.36)
		b.rect(peg.grow(1.2 * u), UI.OUTLINE)
		Art.vgrad(b, peg, WOOD.darkened(0.3), WOOD.darkened(0.5))
		for py in 3:
			for px in 5:
				b.circle(peg.position + Vector2(peg.size.x * (px + 0.5) / 5.0, peg.size.y * (py + 0.5) / 3.0), 0.6 * u, Color(0, 0, 0, 0.6), 6)
		var steel := Color(0.66, 0.66, 0.72)
		var hx := peg.position.x + peg.size.x * 0.22
		b.line(Vector2(hx, peg.position.y + 4.0 * u), Vector2(hx, peg.end.y - 3.0 * u), WOOD.lightened(0.15), 2.0 * u)
		b.rect(Rect2(hx - 4.5 * u, peg.position.y + 3.0 * u, 9.0 * u, 4.5 * u), steel.darkened(0.2))
		b.rect(Rect2(hx - 4.5 * u, peg.position.y + 3.0 * u, 9.0 * u, 1.2 * u), Color(1, 1, 1, 0.35))
		var tx := peg.position.x + peg.size.x * 0.55
		b.line(Vector2(tx - 2.0 * u, peg.position.y + 4.0 * u), Vector2(tx + 1.5 * u, peg.end.y - 3.0 * u), steel, 1.4 * u)
		b.line(Vector2(tx + 2.0 * u, peg.position.y + 4.0 * u), Vector2(tx - 1.5 * u, peg.end.y - 3.0 * u), steel.darkened(0.15), 1.4 * u)
		var fx := peg.position.x + peg.size.x * 0.82
		b.line(Vector2(fx, peg.position.y + 4.0 * u), Vector2(fx, peg.end.y - 4.0 * u), Art.COPPER, 1.8 * u)
		b.line(Vector2(fx - 0.5 * u, peg.position.y + 4.0 * u), Vector2(fx - 0.5 * u, peg.end.y - 4.0 * u), Color(1, 0.8, 0.6, 0.4), 0.6 * u)
		# A shelf of bottles, one for each essence, catching the light.
		var shelf_y := h * 0.52
		var kinds: Array = Essence.KINDS.keys()
		for k in kinds.size():
			var bx := w * 0.31 + k * (w * 0.28 / kinds.size()) + 3.0 * u
			Art.bottle(b, Vector2(bx, shelf_y), 3.6 * u, (9.0 + 2.0 * (k % 2)) * u, Essence.color(kinds[k]), u * 0.6)
		b.rect(Rect2(w * 0.3 - 1.0 * u, shelf_y - 0.5 * u, w * 0.3 + 2.0 * u, 2.6 * u), UI.OUTLINE)
		Art.vgrad(b, Rect2(w * 0.3, shelf_y, w * 0.3, 2.0 * u), WOOD.lightened(0.1), WOOD.darkened(0.3))
		Art.vgrad(b, Rect2(w * 0.3, shelf_y + 2.0 * u, w * 0.3, 4.0 * u), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
		# The workbench: a thick grained top with a brass edge, legs and a
		# stretcher, a vice at the left.
		var top := Rect2(5.0 * u, h * 0.62, w * 0.6, 7.0 * u)
		for lx in [top.position.x + 4.0 * u, top.end.x - 9.0 * u]:
			b.rect(Rect2(lx - 0.8 * u, top.end.y, 6.6 * u, h - top.end.y - 2.2 * u), UI.OUTLINE)
			Art.hgrad(b, Rect2(lx, top.end.y, 5.0 * u, h - top.end.y - 3.0 * u), WOOD.darkened(0.15), WOOD.darkened(0.5))
		b.rect(Rect2(top.position.x + 6.0 * u, top.end.y + (h - top.end.y) * 0.55, top.size.x - 12.0 * u, 2.5 * u), WOOD.darkened(0.45))
		b.rect(top.grow(1.2 * u), UI.OUTLINE)
		Art.vgrad(b, top, WOOD.lightened(0.15), WOOD.darkened(0.2))
		Art.grain(b, top, WOOD, 23, u * 0.6, false, false)
		b.rect(Rect2(top.position, Vector2(top.size.x, 1.2 * u)), Color(1, 0.85, 0.6, 0.35))
		b.rect(Rect2(top.position.x, top.end.y - 1.6 * u, top.size.x, 1.6 * u), Art.GILT.darkened(0.2))
		var vice := Vector2(top.position.x + 14.0 * u, top.position.y)
		b.rect(Rect2(vice + Vector2(-6, -8) * u, Vector2(5, 8) * u), steel.darkened(0.3))
		b.rect(Rect2(vice + Vector2(1, -8) * u, Vector2(5, 8) * u), steel.darkened(0.3))
		b.rect(Rect2(vice + Vector2(-6, -8) * u, Vector2(5, 1.2) * u), Color(1, 1, 1, 0.3))
		b.line(vice + Vector2(-9, -4) * u, vice + Vector2(9, -4) * u, Art.GILT, 1.2 * u)
		# A flask over a small flame, steaming.
		var fl := Vector2(top.position.x + top.size.x * 0.62, top.position.y - 8.0 * u)
		var fk := 0.75 + 0.25 * sin(t * 11.0) * sin(t * 7.0)
		Art.light(b, fl + Vector2(0, 6.0 * u), Vector2(16.0, 12.0) * u, Color(Art.FLAME, 0.25 * fk))
		b.polygon(PackedVector2Array([fl + Vector2(-2.0, 7.0) * u, fl + Vector2(0, (3.0 - 1.5 * fk)) * u, fl + Vector2(2.0, 7.0) * u]), Color(1.0, 0.75, 0.3, 0.9))
		b.rect(Rect2(fl + Vector2(-3.5, 6.0) * u, Vector2(7.0, 2.0) * u), Art.COPPER)
		b.dot(fl, 5.2 * u, UI.OUTLINE)
		b.dot(fl, 4.2 * u, Essence.color("water").darkened(0.15))
		b.dot(fl + Vector2(0, 1.0 * u), 3.2 * u, Essence.color("water"))
		b.dot(fl + Vector2(-1.6, -1.6) * u, 1.0 * u, Color(1, 1, 1, 0.7))
		b.rect(Rect2(fl + Vector2(-1.4, -9.0) * u, Vector2(2.8, 5.0) * u), Color(0.8, 0.85, 0.9, 0.7))
		for k in 2:
			var p := fposmod(t * 0.6 + k * 0.5, 1.0)
			b.dot(fl + Vector2(2.0 * u + p * 3.0 * u, -10.0 * u - p * 10.0 * u), (1.4 + p * 2.6) * u, Color(0.78, 0.75, 0.84, 0.4 * (1.0 - p)))
		# The Rune Artist's corner: a slate on the wall with three runes,
		# glowing (and breathing) when the mark is yours; dark otherwise.
		var slate := Rect2(w * 0.66, 6.0 * u, w * 0.31, h * 0.74)
		b.rect(slate.grow(3.0 * u), UI.OUTLINE)
		Art.bevel(b, slate.grow(2.4 * u), Art.WALNUT, 1.4 * u)
		Art.vgrad(b, slate, SLATE.lightened(0.05), SLATE.darkened(0.3))
		b.polygon(Art.oval(slate.get_center() + Vector2(-slate.size.x * 0.1, slate.size.y * 0.2), Vector2(slate.size.x * 0.35, slate.size.y * 0.08), 12), Color(0.85, 0.85, 0.9, 0.04))
		var glow := (0.75 + 0.25 * sin(t * 2.1)) if lit else 0.0
		if lit:
			Art.light(b, slate.get_center(), slate.size * 0.75, Color(RUNE, 0.25 * glow))
		var rr := minf(slate.size.x * 0.22, slate.size.y * 0.13)
		var ids := ["sharpness", "warding", "swiftness"]
		for k in 3:
			var c := Vector2(slate.get_center().x, slate.position.y + slate.size.y * (0.2 + 0.3 * k))
			c.x += (-1.0 if k == 1 else 1.0) * slate.size.x * 0.12
			var col: Color = Color(Gear.LASTING_RUNES[ids[k]]["color"], 0.35 + 0.65 * glow) if lit else Color(0.55, 0.55, 0.62, 0.45)
			Gear.rune_into(b, ids[k], c, rr, col, false)
		# Chalk on the ledge below the slate.
		b.rect(Rect2(slate.position.x - 1.0 * u, slate.end.y + 2.0 * u, slate.size.x + 2.0 * u, 2.4 * u), UI.OUTLINE)
		Art.vgrad(b, Rect2(slate.position.x - 0.5 * u, slate.end.y + 2.4 * u, slate.size.x + 1.0 * u, 1.8 * u), Art.WALNUT.lightened(0.2), Art.WALNUT.darkened(0.2))
		b.rect(Rect2(slate.position.x + slate.size.x * 0.6, slate.end.y + 0.6 * u, 5.0 * u, 1.8 * u), Color(0.92, 0.92, 0.88))
		b.flush(self)
