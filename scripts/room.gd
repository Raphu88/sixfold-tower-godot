extends Node2D
## The room's look: stone floor, walls with depth, torches with flickering
## light and drifting embers, and dust in the air. Purely visual; the solid
## walls are built in main.gd.

const Palette := preload("res://scripts/palette.gd")

const TILE := 40.0
const WALL_FACE := 46.0  # height of the north wall's visible front

var room: Rect2
var wall := 24.0
var torches: Array = []  # {pos, light, phase}
var embers: Array = []
var dust: Array = []
var light_tex: Texture2D
var ambient: Node2D  # redrawn every frame: flames, embers, dust
var pillars: Array = []  # {pos, r}
var puddles: Array = []  # {pos, r}
var chasms: Array = []  # Rect2 gaps in the floor
var stair_pos := Vector2.ZERO
var stair_open := false:
	set(v):
		stair_open = v
		if stair_light != null:
			stair_light.enabled = v
var stair_light: PointLight2D


## Call before adding to the tree.
func setup(r: Rect2, wall_thickness: float) -> void:
	room = r
	wall = wall_thickness


func _ready() -> void:
	z_index = -10
	light_tex = make_light_texture()
	ambient = Node2D.new()
	ambient.draw.connect(_draw_ambient)
	add_child(ambient)
	stair_light = PointLight2D.new()
	stair_light.texture = light_tex
	stair_light.texture_scale = 1.6
	stair_light.color = Color(1.0, 0.85, 0.5)
	stair_light.energy = 1.4
	stair_light.enabled = false
	stair_light.position = stair_pos
	add_child(stair_light)
	var y := room.position.y - WALL_FACE * 0.45
	for i in 4:
		var x := room.position.x + room.size.x * (0.125 + 0.25 * i)
		var light := PointLight2D.new()
		light.texture = light_tex
		light.texture_scale = 2.6
		light.color = Palette.TORCH
		light.energy = 1.25
		light.position = Vector2(x, y + 30.0)
		add_child(light)
		torches.append({"pos": Vector2(x, y), "light": light, "phase": randf() * 10.0})
	for i in 3:
		var x := room.position.x + room.size.x * (0.25 + 0.25 * i)
		var by := room.end.y + wall * 0.5
		var light := PointLight2D.new()
		light.texture = light_tex
		light.texture_scale = 2.4
		light.color = Palette.TORCH
		light.energy = 1.1
		light.position = Vector2(x, by - 24.0)
		add_child(light)
		torches.append({"pos": Vector2(x, by), "light": light, "phase": randf() * 10.0})
	for i in 70:
		dust.append({
			"pos": Vector2(randf_range(room.position.x, room.end.x), randf_range(room.position.y, room.end.y)),
			"vel": Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 2.0)),
			"size": randf_range(0.8, 1.8),
			"phase": randf() * TAU,
		})


## A soft round light falloff, shared by every light in the game.
static func make_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	g.add_point(0.7, Color(1, 1, 1, 0.12))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex


func set_torch_color(c: Color) -> void:
	for t in torches:
		t["light"].color = c


func set_chasms(list: Array) -> void:
	chasms = list
	queue_redraw()


func set_puddles(list: Array) -> void:
	puddles = list
	queue_redraw()


func set_pillars(list: Array) -> void:
	pillars = list
	queue_redraw()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if stair_light != null:
		stair_light.position = stair_pos
		stair_light.energy = 1.2 + 0.3 * sin(t * 3.0)
	for torch in torches:
		var ph: float = torch["phase"]
		var flick := 0.85 + 0.1 * sin(t * 9.0 + ph) + 0.06 * sin(t * 23.0 + ph * 2.0)
		torch["light"].energy = 1.25 * flick
		torch["light"].texture_scale = 2.6 + 0.1 * sin(t * 5.0 + ph)
		if randf() < 6.0 * delta:
			embers.append({
				"pos": torch["pos"] + Vector2(randf_range(-3.0, 3.0), -10.0),
				"vel": Vector2(randf_range(-10.0, 10.0), randf_range(-45.0, -25.0)),
				"t": randf_range(0.6, 1.2),
			})
	for e in embers:
		e["t"] -= delta
		e["pos"] += e["vel"] * delta
		e["vel"].x += randf_range(-40.0, 40.0) * delta
	embers = embers.filter(func(e): return e["t"] > 0.0)
	for d in dust:
		d["pos"] += d["vel"] * delta
		if not room.grow(10.0).has_point(d["pos"]):
			d["pos"] = Vector2(randf_range(room.position.x, room.end.x), randf_range(room.position.y, room.end.y))
	ambient.queue_redraw()


## Cheap stable per-tile random number in [0, 1).
func _hash(x: int, y: int, salt := 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


func _draw() -> void:
	var outer := room.grow(wall)
	# Beyond the walls: the dark of the tower.
	draw_rect(outer.grow(400.0), Palette.VOID)

	# Floor: square flagstones, some merged into bigger slabs.
	var cols := int(ceil(room.size.x / TILE))
	var rows := int(ceil(room.size.y / TILE))
	var used := {}
	for gy in rows:
		for gx in cols:
			if used.has(Vector2i(gx, gy)):
				continue
			var size := Vector2i(1, 1)
			var roll := _hash(gx, gy, 2)
			if roll < 0.14:
				size = Vector2i(2, 2)
			elif roll < 0.3:
				size = Vector2i(2, 1)
			elif roll < 0.42:
				size = Vector2i(1, 2)
			# Shrink if the slab would overlap another one.
			for dy in size.y:
				for dx in size.x:
					if used.has(Vector2i(gx + dx, gy + dy)) or gx + dx >= cols or gy + dy >= rows:
						size = Vector2i(1, 1)
			for dy in size.y:
				for dx in size.x:
					used[Vector2i(gx + dx, gy + dy)] = true
			var r := Rect2(room.position + Vector2(gx, gy) * TILE, Vector2(size) * TILE).intersection(room)
			var n := _hash(gx, gy)
			var base: Color = Palette.FLOOR.lerp(Palette.FLOOR_LIGHT, n)
			var inner := r.grow(-1.5)
			draw_rect(r, Palette.FLOOR_GAP)
			draw_rect(inner, base)
			# Bevel: lit top-left edges, shadowed bottom-right edges.
			draw_line(inner.position, Vector2(inner.end.x, inner.position.y), base.lightened(0.08), 1.5)
			draw_line(inner.position, Vector2(inner.position.x, inner.end.y), base.lightened(0.04), 1.5)
			draw_line(Vector2(inner.position.x, inner.end.y), inner.end, base.darkened(0.3), 1.5)
			draw_line(Vector2(inner.end.x, inner.position.y), inner.end, base.darkened(0.2), 1.5)
			# Moss creeping in at some corners.
			if _hash(gx, gy, 3) < 0.1:
				var corner := inner.position + inner.size * Vector2(round(_hash(gx, gy, 4)), round(_hash(gx, gy, 5)))
				for k in 6:
					var mp := corner + Vector2(_hash(gx, gy, 10 + k) - 0.5, _hash(gx, gy, 20 + k) - 0.5) * 22.0
					draw_circle(mp, 2.0 + 4.0 * _hash(gx, gy, 30 + k), Color(Palette.MOSS, 0.3))
			# The odd crack.
			if _hash(gx, gy, 7) < 0.12:
				var p0 := inner.position + inner.size * Vector2(_hash(gx, gy, 8), 0.1)
				var p1 := inner.position + inner.size * Vector2(0.5, 0.55)
				var p2 := inner.position + inner.size * Vector2(_hash(gx, gy, 9), 0.92)
				draw_polyline(PackedVector2Array([p0, p1, p2]), base.darkened(0.4), 1.0)

	# A soft darkening toward the walls, so the floor feels enclosed.
	for i in 6:
		var k := float(i) / 6.0
		draw_rect(room.grow(-i * 7.0), Color(0, 0, 0, 0.07 * (1.0 - k)), false, 7.0)

	_draw_walls()
	for pd in puddles:
		# Standing water: dark, with a lighter rim and a glint.
		draw_circle(pd["pos"], pd["r"], Color(0.1, 0.22, 0.28, 0.75))
		draw_circle(pd["pos"], pd["r"] * 0.8, Color(0.14, 0.3, 0.36, 0.6))
		draw_arc(pd["pos"], pd["r"], 0.0, TAU, 40, Color(0.5, 0.75, 0.8, 0.35), 2.0)
		draw_arc(pd["pos"] + Vector2(-pd["r"] * 0.2, -pd["r"] * 0.25), pd["r"] * 0.35, PI * 1.1, PI * 1.6, 10, Color(0.8, 0.95, 1.0, 0.35), 2.0)
	for ch in chasms:
		# A gap in the floor: a cracked lip, then darkness falling away.
		var r: Rect2 = ch
		draw_rect(r.grow(3.0), Color(0.12, 0.1, 0.1))
		draw_rect(r, Color(0.02, 0.015, 0.03))
		for i in 4:
			draw_rect(r.grow(-2.0 - i * 3.0), Color(0.0, 0.0, 0.0, 0.25), false, 3.0)
		draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.55, 0.5, 0.45, 0.6), 2.0)
		draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0.3, 0.27, 0.25, 0.8), 2.0)
	for p in pillars:
		_draw_pillar(p["pos"], p["r"])


func _draw_pillar(pos: Vector2, r: float) -> void:
	# Seen from above: a round stone column with a shadow, rim and cap.
	draw_set_transform(pos + Vector2(r * 0.25, r * 0.55), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r * 1.15, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(pos, r + 2.0, Palette.OUTLINE)
	draw_circle(pos, r, Palette.WALL_FACE.darkened(0.15))
	draw_circle(pos + Vector2(-r * 0.1, -r * 0.12), r * 0.86, Palette.WALL_FACE)
	draw_arc(pos, r * 0.62, 0.0, TAU, 32, Palette.WALL_FACE.darkened(0.25), 1.5)
	draw_circle(pos + Vector2(-r * 0.3, -r * 0.34), r * 0.25, Color(Palette.WALL_EDGE.lightened(0.2), 0.5))
	# A few cracks so pillars aren't identical.
	var h := _hash(int(pos.x), int(pos.y))
	for i in 2:
		var a := (h + i * 0.37) * TAU
		draw_line(pos + Vector2.from_angle(a) * r * 0.3, pos + Vector2.from_angle(a + 0.2) * r * 0.85, Palette.WALL_FACE.darkened(0.35), 1.0)


func _draw_stair(c: CanvasItem, t: float) -> void:
	# Stone steps leading up into the north wall. Sealed until the floor is clear.
	var w := 68.0
	var base := stair_pos + Vector2(0, 16)
	for i in 5:
		var k := float(i) / 5.0
		var step_w := w * (1.0 - k * 0.35)
		var y := base.y - i * 8.0
		var rect := Rect2(Vector2(stair_pos.x - step_w / 2.0, y - 8.0), Vector2(step_w, 8.0))
		var col := Palette.WALL_FACE.lightened(0.05 + k * 0.1)
		if not stair_open:
			col = col.darkened(0.35)
		c.draw_rect(rect, Palette.OUTLINE)
		c.draw_rect(rect.grow(-1.0), col)
		c.draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), col.lightened(0.15), 1.0)
	if stair_open:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		c.draw_arc(stair_pos, 30.0 + pulse * 6.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.5, 0.35 + 0.3 * pulse), 2.5)
		# A chevron pointing up the steps.
		var tip := stair_pos + Vector2(0, -26 - pulse * 4.0)
		c.draw_polyline(PackedVector2Array([tip + Vector2(-9, 7), tip, tip + Vector2(9, 7)]), Color(1.0, 0.9, 0.6, 0.9), 2.5)
	else:
		# Sealed: a chain across the steps.
		for i in 7:
			var x := stair_pos.x - 33.0 + i * 11.0
			c.draw_arc(Vector2(x, base.y - 18.0), 4.0, 0.0, TAU, 10, Color(0.35, 0.33, 0.36), 2.0)


func _draw_ambient() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var c := ambient
	_draw_stair(c, t)
	for torch in torches:
		_draw_torch(c, torch["pos"], t + torch["phase"])
	for e in embers:
		var a: float = clampf(e["t"], 0.0, 1.0)
		c.draw_circle(e["pos"], 1.3, Color(1.0, 0.65, 0.25, a))
	for d in dust:
		var a: float = 0.08 + 0.06 * sin(t * 1.3 + d["phase"])
		c.draw_circle(d["pos"], d["size"], Color(1.0, 0.92, 0.8, a))


func _draw_walls() -> void:
	var r := room
	# Side and bottom walls: seen from above as thick stone rims.
	var rim := Palette.WALL_TOP
	draw_rect(Rect2(r.position.x - wall, r.position.y, wall, r.size.y + wall), rim)
	draw_rect(Rect2(r.end.x, r.position.y, wall, r.size.y + wall), rim)
	draw_rect(Rect2(r.position.x - wall, r.end.y, r.size.x + wall * 2.0, wall), rim)
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Palette.WALL_EDGE, 2.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Palette.WALL_EDGE, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Palette.WALL_EDGE, 2.0)

	# North wall: we see its brick front face, which gives the room depth.
	var face := Rect2(r.position.x - wall, r.position.y - WALL_FACE, r.size.x + wall * 2.0, WALL_FACE)
	draw_rect(Rect2(face.position - Vector2(0, wall), Vector2(face.size.x, wall)), rim)
	draw_rect(face, Palette.WALL_FACE)
	var brick := Vector2(36.0, 11.5)
	var row := 0
	var y := face.position.y
	while y < face.end.y - 0.5:
		var off := brick.x * 0.5 if row % 2 == 1 else 0.0
		var x := face.position.x - off
		while x < face.end.x:
			var b := Rect2(Vector2(x, y), brick).intersection(face)
			if b.size.x > 1.0:
				var shade := _hash(int(x), row, 5) * 0.12
				draw_rect(b.grow(-1.0), Palette.WALL_FACE.lightened(shade))
				draw_line(b.position + Vector2(1, 1), Vector2(b.end.x - 1, b.position.y + 1), Palette.WALL_FACE.lightened(shade + 0.1), 1.0)
			x += brick.x
		y += brick.y
		row += 1
	# Shadow the wall casts onto the floor.
	for i in 5:
		draw_rect(Rect2(r.position.x, r.position.y + i * 4.0, r.size.x, 4.0), Color(0, 0, 0, 0.32 - i * 0.06))

	# Pillars at the corners.
	for px in [r.position.x - wall, r.end.x - 6.0]:
		var p := Rect2(px, r.position.y - WALL_FACE - wall, wall + 6.0, WALL_FACE + wall + 10.0)
		draw_rect(p, Palette.WALL_TOP.darkened(0.15))
		draw_rect(Rect2(p.position, Vector2(p.size.x, 6.0)), Palette.WALL_EDGE)


func _draw_torch(c: CanvasItem, pos: Vector2, t: float) -> void:
	# Iron bracket.
	c.draw_rect(Rect2(pos + Vector2(-3, 4), Vector2(6, 14)), Color(0.13, 0.11, 0.12))
	c.draw_rect(Rect2(pos + Vector2(-6, 2), Vector2(12, 4)), Color(0.2, 0.17, 0.17))
	# Flame: layered teardrops that flicker.
	var h := 13.0 + 2.5 * sin(t * 11.0) + 1.5 * sin(t * 27.0)
	var sway := 1.5 * sin(t * 7.0)
	_flame(c, pos, h, 6.0, sway, Color(0.95, 0.35, 0.12, 0.9))
	_flame(c, pos, h * 0.72, 4.2, sway * 0.7, Color(1.0, 0.65, 0.2, 0.95))
	_flame(c, pos, h * 0.42, 2.6, sway * 0.4, Color(1.0, 0.93, 0.7))


func _flame(c: CanvasItem, base: Vector2, h: float, w: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var p := Vector2(sin(a) * w, -cos(a) * w * 0.8)
		if p.y < 0.0:
			p.y *= h / w
			p.x += sway * (-p.y / h)
		pts.append(base + p)
	c.draw_colored_polygon(pts, col)
