extends Node2D
## Doors in the doorways of a floor of rooms (floors.gd decides where). A
## closed door is a solid tile: it blocks movement (its own collision body),
## sight (fog.gd reads main.solid) and paths (main.astar). It opens when the
## climber walks up to it, or when an awake monster does, with a thud and a
## puff of dust, and opening it reveals the room behind.
##
## A door's look hints at what waits inside (the room theme's "door" in
## themes.gd), never at the reward:
##   plank    plain planks and two iron bands: an ordinary room
##   den      dark wood, heavy bands, claw marks, bones at the threshold
##   hazard   an iron plate engraved with the hazard's sigil
##   puzzle   a stone door bearing the puzzle's emblem
##   warm     warm light spilling out under it: a good room
##   chained  chains across it and a red glow under it: danger
##   sealed   a stone slab carved with a watching eye, red light under it: a
##            sealed wing (wings.gd), where the Regard tests you
##
## Drawn once and only redrawn while a door swings open, so it costs nothing
## per frame. main.gd owns one of these (`main.door_view`).

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Themes := preload("res://scripts/themes.gd")

## A door opens when a body's edge comes this close to it (px).
const REACH := 24.0
const OPEN_TIME := 0.3
## How often awake monsters are checked against the doors (seconds).
const MONSTER_CHECK := 0.1
## The colours of the hazard sigils (the tower's trap) and the glows under doors.
const SIGIL_COLORS := {
	"wind": Color(0.78, 0.9, 1.0), "wave": Color(0.45, 0.85, 0.95), "flame": Color(1.0, 0.55, 0.22),
	"spike": Color(0.9, 0.82, 0.62), "ember": Color(1.0, 0.7, 0.3), "thorn": Color(0.6, 0.85, 0.4),
	"chasm": Color(0.62, 0.5, 0.85),
}
const WARM := Color(1.0, 0.74, 0.4)
const RED := Color(0.95, 0.22, 0.15)
const EMBLEM := Color(0.75, 0.55, 1.0)

var main
var list: Array = []  # {tiles, rect, horiz, out, room, style, sigil, emblem, open, t, body}
var glow: Node2D  # light under warm and chained doors, unshaded so it reads in the dark
var monster_t := 0.0
var animating := false


func _ready() -> void:
	z_index = -4  # on the floor, under everyone
	glow = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unlit
	glow.draw.connect(_draw_glow)
	add_child(glow)


## A new floor: takes away the old doors (their tiles go with the old grid).
func clear() -> void:
	for d in list:
		if is_instance_valid(d["body"]):
			d["body"].queue_free()
		_drop_light(d)
	list.clear()
	animating = false
	_redraw()


## Hangs the floor's doors: `defs` from the plan ({tiles, horiz, out, room}),
## `themes` the theme id of each room. Call once the layout is built.
func build(defs: Array, themes: Array) -> void:
	clear()
	if main == null or not main.layout_on:
		return
	for def in defs:
		_hang(def, themes)
	_redraw()


## Hangs one more door after build(): `def` as in build(), with its look
## given as "style" whatever room it leads to (a sealed wing's, wings.gd).
func add_door(def: Dictionary) -> Dictionary:
	if main == null or not main.layout_on:
		return {}
	var d := _hang(def, [])
	_redraw()
	return d


func _hang(def: Dictionary, themes: Array) -> Dictionary:
	var c: float = main.Floors.CELL
	var tiles: Array = def["tiles"]
	var a: Vector2i = tiles[0]
	var b: Vector2i = tiles[-1]
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var rect := Rect2(main.room.position + Vector2(lo) * c, Vector2(hi - lo + Vector2i.ONE) * c)
	var d := {"tiles": tiles, "rect": rect, "horiz": def["horiz"], "out": def["out"], "room": def["room"],
		"open": false, "t": 0.0, "body": null, "fixed": def.get("style", "")}
	_style(d, themes)
	for t in tiles:
		_set_tile(t, true)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	d["body"] = body
	list.append(d)
	_add_light(d)
	return d


## Warm and chained doors cast a little light from under them (through the
## darkness layer, so it shows from across the room).
func _add_light(d: Dictionary) -> void:
	_drop_light(d)
	if main == null or main.lighting == null:
		return
	var col: Color
	match String(d.get("style", "")):
		"warm":
			col = WARM
		"chained", "sealed":
			col = RED
		_:
			return
	var edge := _edge(d["rect"], d["out"])
	var at: Vector2 = (edge[0] + edge[1]) * 0.5 + Vector2(d["out"]) * 16.0
	d["light"] = main.lighting.add_light(at, 80.0, col, 0.55, 0.35)


func _drop_light(d: Dictionary) -> void:
	if d.has("light") and main != null and main.lighting != null:
		main.lighting.remove_light(d["light"])
	d.erase("light")


## Updates each door's look after the rooms' themes changed.
func restyle(themes: Array) -> void:
	for d in list:
		_style(d, themes)
		_add_light(d)
	_redraw()


func _style(d: Dictionary, themes: Array) -> void:
	if d.get("fixed", "") != "":
		d["theme"] = ""
		d["style"] = d["fixed"]
		d["sigil"] = ""
		d["emblem"] = ""
		return
	var id: String = themes[d["room"]] if d["room"] >= 0 and d["room"] < themes.size() else "quiet"
	var th: Dictionary = Themes.get_theme(id)
	d["theme"] = id
	d["style"] = th.get("door", "plank")
	d["sigil"] = th.get("sigil", "")
	d["emblem"] = th.get("emblem", "")


func _set_tile(t: Vector2i, closed: bool) -> void:
	var gs: Vector2i = main.grid_size
	if t.x < 0 or t.y < 0 or t.x >= gs.x or t.y >= gs.y:
		return
	main.solid[t.y * gs.x + t.x] = 1 if closed else 0
	if main.astar != null:
		main.astar.set_point_solid(t, closed)


func closed_count() -> int:
	return list.filter(func(d): return not d["open"]).size()


## The door on a grid tile, or {}.
func door_at(t: Vector2i) -> Dictionary:
	for d in list:
		if t in d["tiles"]:
			return d
	return {}


func open_all() -> void:
	for d in list:
		if not d["open"]:
			open_door(d, true)


func open_door(d: Dictionary, quiet := false) -> void:
	if d["open"]:
		return
	d["open"] = true
	d["t"] = 0.0
	_drop_light(d)
	for t in d["tiles"]:
		_set_tile(t, false)
	if is_instance_valid(d["body"]):
		d["body"].queue_free()
	d["body"] = null
	# What's behind is in sight now (fog.gd looks again on its next frame).
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))
	if quiet:
		d["t"] = 1.0
		_redraw()
		return
	animating = true
	var dust := Color(0.55, 0.45, 0.33)
	main.fx_burst(d["rect"].get_center(), d["out"], dust, 10, 90.0)
	main.fx_burst(d["rect"].get_center(), -d["out"], dust, 8, 70.0)
	main.sfx("slam", 1.7, -10.0, 0.08)
	main.sfx("step_plate", 0.6, -6.0, 0.05)
	_redraw()


func _process(delta: float) -> void:
	if list.is_empty() or main == null or main.player == null:
		return
	if animating:
		var still := false
		for d in list:
			if d["open"] and d["t"] < 1.0:
				d["t"] = minf(1.0, d["t"] + delta / OPEN_TIME)
				still = still or d["t"] < 1.0
		animating = still
		_redraw()
	var p = main.player
	if not p.dead:
		for d in list:
			if not d["open"] and _touches(d, p.global_position, p.radius):
				open_door(d)
	monster_t -= delta
	if monster_t <= 0.0:
		monster_t = MONSTER_CHECK
		var shut: Array = list.filter(func(d): return not d["open"])
		if shut.is_empty():
			return
		for e in main.enemies():
			if not e.aware:
				continue
			for d in shut:
				if not d["open"] and _touches(d, e.global_position, e.radius):
					open_door(d)


func _touches(d: Dictionary, pos: Vector2, r: float) -> bool:
	var rect: Rect2 = d["rect"]
	return rect.grow(r + REACH).has_point(pos)


func _redraw() -> void:
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if list.is_empty():
		return
	var b := Draw.Batch.new()
	for d in list:
		if d["open"]:
			_draw_open(b, d)
		else:
			_draw_closed(b, d)
	b.flush(self)


## The light under warm and chained doors, on the side you come from.
func _draw_glow() -> void:
	var b := Draw.Batch.new()
	for d in list:
		if d["open"] and d["t"] >= 1.0:
			continue
		var col: Color
		match String(d["style"]):
			"warm":
				col = WARM
			"chained", "sealed":
				col = RED
			_:
				continue
		var fade := 1.0 - float(d["t"]) if d["open"] else 1.0
		var r: Rect2 = d["rect"]
		var out: Vector2 = d["out"]
		var edge := _edge(r, out)  # the door's outer edge
		for i in 5:
			var depth := 4.0 + i * 5.0
			var strip := _strip(edge, out, depth)
			b.rect(strip, Color(col, 0.10 * fade * (1.0 - i / 5.0)))
		b.rect(_strip(edge, out, 2.5), Color(col.lightened(0.3), 0.75 * fade))
	b.flush(glow)


## The door's outer edge: [from, to] along the side facing `out`.
func _edge(r: Rect2, out: Vector2) -> Array:
	if out == Vector2.UP:
		return [r.position, Vector2(r.end.x, r.position.y)]
	if out == Vector2.DOWN:
		return [Vector2(r.position.x, r.end.y), r.end]
	if out == Vector2.LEFT:
		return [r.position, Vector2(r.position.x, r.end.y)]
	return [Vector2(r.end.x, r.position.y), r.end]


## A strip `depth` px deep outward from an edge, a little shorter than the door.
func _strip(edge: Array, out: Vector2, depth: float) -> Rect2:
	var a: Vector2 = edge[0]
	var c: Vector2 = edge[1]
	var along := (c - a).normalized()
	a += along * 6.0
	c -= along * 6.0
	var far := c + out * depth
	return Rect2(Vector2(minf(a.x, far.x), minf(a.y, far.y)), (far - a).abs())


func _draw_open(b, d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var horiz: bool = d["horiz"]
	var k: float = d["t"]
	var wood := _wood(d)
	# The frame left in the doorway.
	var j := 5.0
	if horiz:
		b.rect(Rect2(r.position.x, r.position.y + 2.0, j, r.size.y - 4.0), wood.darkened(0.35))
		b.rect(Rect2(r.end.x - j, r.position.y + 2.0, j, r.size.y - 4.0), wood.darkened(0.35))
	else:
		b.rect(Rect2(r.position.x + 2.0, r.position.y, r.size.x - 4.0, j), wood.darkened(0.35))
		b.rect(Rect2(r.position.x + 2.0, r.end.y - j, r.size.x - 4.0, j), wood.darkened(0.35))
	# While it swings: the leaf folding away to the side.
	if k < 1.0:
		var leaf := r.grow(-2.0)
		if horiz:
			leaf.size.x *= (1.0 - k)
		else:
			leaf.size.y *= (1.0 - k)
		b.rect(leaf, Color(wood, 1.0 - k * 0.5))


func _wood(d: Dictionary) -> Color:
	match String(d["style"]):
		"den":
			return Palette.DOOR_WOOD.darkened(0.3)
		"puzzle":
			return Palette.DOOR_STONE
		"sealed":
			return Palette.DOOR_STONE.darkened(0.25)
		"hazard":
			return Palette.DOOR_WOOD.darkened(0.15)
	return Palette.DOOR_WOOD


func _draw_closed(b, d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var horiz: bool = d["horiz"]
	var style: String = d["style"]
	var wood := _wood(d)
	var inner := r.grow(-2.0)
	# Shadow and outline, then the leaf.
	b.rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.3))
	b.rect(r, Palette.OUTLINE)
	b.rect(inner, wood)
	var long := inner.size.x if horiz else inner.size.y
	var across := inner.size.y if horiz else inner.size.x
	var along := Vector2.RIGHT if horiz else Vector2.DOWN
	var side := Vector2.DOWN if horiz else Vector2.RIGHT
	var o := inner.position
	if style == "sealed":
		# A dark stone slab with iron studs at its ends and a watching eye
		# carved in the middle, its pupil glowing: the Regard tests whoever enters.
		b.rect(inner.grow(-3.0), wood.lightened(0.06))
		for k in [0.12, 0.88]:
			for j in [0.3, 0.7]:
				b.circle(o + along * long * k + side * across * j, 2.2, Palette.DOOR_IRON.lightened(0.3))
		var c := inner.get_center()
		var s := across * 0.34
		var lid := PackedVector2Array()
		for i in 13:
			var a := PI * float(i) / 12.0
			lid.append(c + along * cos(a) * s * 1.7 - side * sin(a) * s * 0.8)
		for i in range(1, 12):
			var a := PI * float(i) / 12.0
			lid.append(c - along * cos(a) * s * 1.7 + side * sin(a) * s * 0.8)
		b.polygon(lid, wood.darkened(0.45))
		b.polyline(lid + PackedVector2Array([lid[0]]), Color(RED.lightened(0.2), 0.75), 1.6)
		b.circle(c, s * 0.5, Color(RED, 0.85))
		b.circle(c, s * 0.22, Color(1.0, 0.85, 0.6))
		return
	if style == "puzzle":
		# A stone slab: a raised border, joints, and the puzzle's emblem.
		b.rect(inner.grow(-3.0), wood.lightened(0.08))
		b.line(o + along * long * 0.5, o + along * long * 0.5 + side * across, wood.darkened(0.3), 1.5)
		var c := inner.get_center()
		var s := across * 0.32
		match String(d["emblem"]):
			"eye":
				var pts := PackedVector2Array()
				for i in 13:
					var a := PI * float(i) / 12.0
					pts.append(c + Vector2(cos(a) * s * 1.5, -sin(a) * s * 0.75))
				for i in range(1, 12):
					var a := PI * float(i) / 12.0
					pts.append(c + Vector2(-cos(a) * s * 1.5, sin(a) * s * 0.75))
				b.polyline(pts + PackedVector2Array([pts[0]]), Color(EMBLEM, 0.8), 1.8)
				b.circle(c, s * 0.42, Color(EMBLEM, 0.85))
				b.circle(c, s * 0.18, wood.darkened(0.4))
			_:
				b.rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Color(EMBLEM, 0.75))
				b.rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), wood.lightened(0.08))
				b.rect(Rect2(c - Vector2(s, s) * 0.38, Vector2(s, s) * 0.76), Color(EMBLEM, 0.8))
		return
	# Planks: lines across the leaf.
	var planks := 5
	for i in range(1, planks):
		var t := long * float(i) / planks
		b.line(o + along * t, o + along * t + side * across, wood.darkened(0.35), 1.2)
	var iron := Palette.DOOR_IRON
	var bands := 3 if style == "den" else 2
	for i in bands:
		var t := across * (float(i) + 0.75) / (float(bands) + 0.5)
		var bw := 5.0 if style == "den" else 3.5
		b.rect(Rect2(o + side * (t - bw * 0.5), Vector2.ZERO).expand(o + side * (t + bw * 0.5) + along * long), iron)
		if style == "den":
			for k in 4:
				b.circle(o + side * t + along * (long * (0.12 + 0.25 * k)), 1.4, iron.lightened(0.35))
	match style:
		"den":
			# Claw marks gouged across it, and bones at the threshold.
			var c := inner.get_center()
			for k in 3:
				var off := (k - 1) * 6.0
				b.line(c + along * (off - 9.0) + side * -9.0, c + along * (off + 7.0) + side * 9.0, wood.lightened(0.35), 1.6)
			var out: Vector2 = d["out"]
			var sill := r.get_center() + out * (r.size.dot(out.abs()) * 0.5 + 9.0)
			_bone(b, sill + along * -14.0, along.rotated(0.5), 9.0)
			_bone(b, sill + along * 10.0 + out * 4.0, along.rotated(-0.9), 7.0)
		"hazard":
			var c := inner.get_center()
			var rad := across * 0.36
			b.circle(c, rad + 1.5, Palette.OUTLINE)
			b.circle(c, rad, iron.lightened(0.1))
			_sigil(b, c, rad * 0.75, String(d["sigil"]))
		"chained":
			# Two chains across, and a padlock where they cross.
			var a0 := inner.position
			var a1 := inner.end
			var b0 := Vector2(inner.end.x, inner.position.y)
			var b1 := Vector2(inner.position.x, inner.end.y)
			for seg in [[a0, a1], [b0, b1]]:
				var n := 9
				for i in n + 1:
					var p: Vector2 = seg[0].lerp(seg[1], float(i) / n)
					b.circle(p, 3.0, Palette.OUTLINE)
					b.circle(p, 2.0, Color(0.5, 0.48, 0.5))
			var c := inner.get_center()
			b.rect(Rect2(c - Vector2(6, 3), Vector2(12, 10)), Palette.OUTLINE)
			b.rect(Rect2(c - Vector2(5, 2), Vector2(10, 8)), Color(0.55, 0.45, 0.25))
			b.arc(c + Vector2(0, -3), 4.0, PI, TAU, 8, Color(0.5, 0.48, 0.5), 2.0)
			b.rect(Rect2(c + Vector2(-1, 1), Vector2(2, 3)), Palette.OUTLINE)
		"warm":
			# A brass ring to pull.
			var c := inner.get_center() + along * long * 0.28
			b.arc(c, 4.5, 0.0, TAU, 12, Color(0.75, 0.6, 0.3), 1.8)


func _bone(b, c: Vector2, dir: Vector2, len: float) -> void:
	var bone := Color(0.82, 0.78, 0.68)
	var a := c - dir * len * 0.5
	var e := c + dir * len * 0.5
	b.line(a, e, bone, 2.4)
	var n := dir.orthogonal() * 1.6
	for p in [a, e]:
		b.circle(p + n, 1.7, bone)
		b.circle(p - n, 1.7, bone)


## A hazard's sign, engraved in the door's plate.
func _sigil(b, c: Vector2, s: float, sigil: String) -> void:
	var col: Color = SIGIL_COLORS.get(sigil, Color(0.8, 0.8, 0.8))
	match sigil:
		"wind":
			for k in 3:
				var y := (k - 1) * s * 0.55
				var pts := PackedVector2Array()
				for i in 7:
					var x := -s + 2.0 * s * i / 6.0
					pts.append(c + Vector2(x, y + sin(i * 0.9 + k) * s * 0.12))
				b.polyline(pts, col, 1.6)
			b.arc(c + Vector2(s * 0.7, -s * 0.2), s * 0.32, -PI * 0.5, PI * 0.9, 8, col, 1.6)
		"wave":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var x := -s + 2.0 * s * i / 8.0
					pts.append(c + Vector2(x, (k - 0.5) * s * 0.8 + sin(i * 1.4) * s * 0.25))
				b.polyline(pts, col, 1.8)
		"flame":
			var pts := PackedVector2Array()
			for i in 14:
				var a := float(i) / 14.0 * TAU
				var p := Vector2(sin(a) * s * 0.6, -cos(a) * s * 0.55)
				if p.y < 0.0:
					p.y *= 1.9
				pts.append(c + p + Vector2(0, s * 0.3))
			b.polygon(pts, col)
			b.circle(c + Vector2(0, s * 0.42), s * 0.25, col.lightened(0.4))
		"spike":
			for k in 3:
				var x := (k - 1) * s * 0.7
				b.polygon(PackedVector2Array([c + Vector2(x - s * 0.3, s * 0.6), c + Vector2(x, -s * 0.75), c + Vector2(x + s * 0.3, s * 0.6)]), col)
		"ember":
			b.circle(c + Vector2(0, -s * 0.15), s * 0.45, col)
			for k in 3:
				b.circle(c + Vector2((k - 1) * s * 0.55, s * 0.55 + (k % 2) * s * 0.2), s * 0.14, col)
		"thorn":
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(c + Vector2(-s + 2.0 * s * i / 5.0, (s * 0.35) * (1.0 if i % 2 == 0 else -1.0)))
			b.polyline(pts, col, 2.0)
			for i in range(1, 5):
				var p: Vector2 = pts[i]
				b.line(p, p + Vector2(0, -s * 0.3 if i % 2 == 0 else s * 0.3), col, 1.4)
		"chasm":
			b.polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), Color(0.05, 0.03, 0.08))
			b.polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0), c + Vector2(0, -s)]), col, 1.6)
		_:
			b.circle(c, s * 0.4, col)
