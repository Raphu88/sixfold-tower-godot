extends Node2D
## The room's look: stone floor, walls with depth, torches with flickering
## flames and drifting embers, and dust in the air. Purely visual; the solid
## walls are built in main.gd. The light itself (torches, stair, cache) is
## cast by the darkness layer (lighting.gd), which reads `torches` here.

const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Lost := preload("res://scripts/lost.gd")
const Mirror := preload("res://scripts/mirror.gd")

const TILE := 40.0
const WALL_FACE := 46.0  # height of the north wall's visible front

var room: Rect2
var wall := 24.0
var torches: Array = []  # {pos, phase, below}: lighting.gd lights each one
var embers: Array = []
var dust: Array = []
var ambient: Node2D  # redrawn every frame: flames, embers, dust
var pillars: Array = []  # {pos, r}
var puddles: Array = []  # {pos, r}
var chasms: Array = []  # Rect2 gaps in the floor
var stair_pos := Vector2.ZERO
var stair_open := false
var torch_color := Palette.TORCH
# A floor of rooms: which tiles are solid (walls between rooms).
var grid := Vector2i.ZERO
var solid := PackedByteArray()
var layout_rooms: Array = []
var blocks: Array = []  # low cover walls inside rooms (Rect2, solid tiles)
var block_tiles := {}  # Vector2i -> true: tiles drawn as cover, not as wall
var doors: Array = []  # door-frame posts beside corridor openings (Rect2 tiles)
var cache := {}  # a good room's essence cache: {pos, kind, taken}
var lost_cache := {}  # your lost things (lost.gd): {pos, taken}
# Room themes (themes.gd): each room's floor tint and marks, drawn into the
# floor squares (static: no cost per frame). {walk: [Rect2], rect, rows, tint, decor}
var looks: Array = []
var springs: Array = []  # healing springs: {pos, r, left} (shared with main.gd)
var camps: Array = []  # fallen climbers' cold camps: {pos}
# The floor and walls are drawn in squares (see Draw.Chunked): fewer draw
# calls, and only the squares on screen are drawn.
const CHUNK := 400.0
var batch  # while drawing
var chunk_items: Array = []  # the squares' canvas items
var features: Node2D  # puddles, chasms and pillars, drawn over the floor
var tint := Color.WHITE  # the tower's stone colour, passed on to the squares
var layout_painter = null  # main.tower_floor while it has one (its paint_layout hook may draw the walls)
var ambient_t := 0.0  # until the next redraw of flames, embers and dust


## Call before adding to the tree.
func setup(r: Rect2, wall_thickness: float) -> void:
	room = r
	wall = wall_thickness


func _ready() -> void:
	z_index = -10
	ambient = Node2D.new()
	ambient.draw.connect(_draw_ambient)
	add_child(ambient)
	features = Node2D.new()
	features.draw.connect(_draw_features)
	add_child(features)
	move_child(features, 0)  # under the torches, embers and dust
	_make_torches()
	_make_dust()


## Switches to another area (the open room, or the bigger area of a rooms floor).
func reconfigure(r: Rect2) -> void:
	room = r
	_make_torches()
	_make_dust()
	queue_redraw()


## A rooms floor's solid tiles (an empty grid means an open room).
func set_layout(size: Vector2i, tiles: PackedByteArray, rooms: Array, cover: Array = []) -> void:
	grid = size
	solid = tiles
	layout_rooms = rooms
	blocks = cover
	block_tiles.clear()
	for b in blocks:
		var r: Rect2 = b
		for y in range(roundi((r.position.y - room.position.y) / TILE), roundi((r.end.y - room.position.y) / TILE)):
			for x in range(roundi((r.position.x - room.position.x) / TILE), roundi((r.end.x - room.position.x) / TILE)):
				block_tiles[Vector2i(x, y)] = true
	_make_torches()
	queue_redraw()


## Door-frame posts beside the openings where corridors meet rooms.
func set_doors(list: Array) -> void:
	doors = list
	queue_redraw()


## The rooms' themed looks, springs and camps (empty on open floors).
func set_looks(list: Array, spring_list: Array = [], camp_list: Array = []) -> void:
	looks = list
	springs = spring_list
	camps = camp_list
	queue_redraw()


## Redraws the pillars, pools and springs (a spring ran dry).
func refresh_features() -> void:
	if features != null:
		features.queue_redraw()


## A torch on the wall at `pos`; its light falls `below` it, onto the floor.
func _add_torch(pos: Vector2, _scale: float, below: float) -> void:
	torches.append({"pos": pos, "phase": randf() * 10.0, "below": below})


func _make_torches() -> void:
	torches.clear()
	if not layout_rooms.is_empty():
		# A torch on the north wall of every room (two in wide ones).
		for r in layout_rooms:
			var rr: Rect2 = r
			var n := 2 if rr.size.x > 480.0 else 1
			for i in n:
				_add_torch(Vector2(rr.position.x + rr.size.x * (float(i) + 0.5) / n, rr.position.y - 8.0), 2.8, 30.0)
		return
	var y := room.position.y - WALL_FACE * 0.45
	for i in 4:
		_add_torch(Vector2(room.position.x + room.size.x * (0.125 + 0.25 * i), y), 2.6, 30.0)
	for i in 3:
		_add_torch(Vector2(room.position.x + room.size.x * (0.25 + 0.25 * i), room.end.y + wall * 0.5), 2.4, -24.0)


func _make_dust() -> void:
	dust.clear()
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
	torch_color = c


func set_chasms(list: Array) -> void:
	chasms = list
	queue_redraw()


func set_puddles(list: Array) -> void:
	puddles = list
	queue_redraw()


func set_pillars(list: Array) -> void:
	pillars = list
	queue_redraw()


## The part of the world on screen, grown by a torch's reach (all of it
## when there's no camera yet).
func _view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(260.0)


func _process(delta: float) -> void:
	if tint != self_modulate:
		tint = self_modulate
		features.self_modulate = tint
		for ci in chunk_items:
			RenderingServer.canvas_item_set_self_modulate(ci, tint)
	# Embers rise only from torches on screen (nobody sees the others).
	var view := _view_rect()
	for torch in torches:
		if not view.has_point(torch["pos"]):
			continue
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
	# Flames, embers and dust: 30 redraws a second is plenty (phones).
	ambient_t -= delta
	if ambient_t <= 0.0:
		ambient_t = 1.0 / 30.0
		ambient.queue_redraw()


## Cheap stable per-tile random number in [0, 1).
func _hash(x: int, y: int, salt := 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


## True when every tile of a floor slab is solid (a wall or low cover is drawn
## over all of it, so drawing the stone there is wasted work).
func _under_wall(gx: int, gy: int, size: Vector2i) -> bool:
	if grid == Vector2i.ZERO:
		return false
	for dy in size.y:
		for dx in size.x:
			var x := gx + dx
			var y := gy + dy
			if x >= grid.x or y >= grid.y or solid[y * grid.x + x] == 0:
				return false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_chunks()


func _free_chunks() -> void:
	for ci in chunk_items:
		RenderingServer.free_rid(ci)
	chunk_items.clear()


## A rect outline, like draw_rect(r, col, false, width).
func _outline(r: Rect2, col: Color, width: float) -> void:
	var o := width * 0.5
	batch.rect(Rect2(r.position.x - o, r.position.y - o, r.size.x + width, width), col)
	batch.rect(Rect2(r.position.x - o, r.end.y - o, r.size.x + width, width), col)
	batch.rect(Rect2(r.position.x - o, r.position.y + o, width, r.size.y - width), col)
	batch.rect(Rect2(r.end.x - o, r.position.y + o, width, r.size.y - width), col)


func _draw() -> void:
	_free_chunks()
	batch = Draw.Chunked.new(room.position, CHUNK)
	var outer := room.grow(wall)
	# Beyond the walls: the dark of the tower. (Only around the floor: the
	# floor covers the rest, and every lit pixel drawn twice costs a phone.)
	var far := outer.grow(400.0)
	batch.rect(Rect2(far.position, Vector2(far.size.x, room.position.y - far.position.y)), Palette.VOID)
	batch.rect(Rect2(far.position.x, room.end.y, far.size.x, far.end.y - room.end.y), Palette.VOID)
	batch.rect(Rect2(far.position.x, room.position.y, room.position.x - far.position.x, room.size.y), Palette.VOID)
	batch.rect(Rect2(room.end.x, room.position.y, far.end.x - room.end.x, room.size.y), Palette.VOID)

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
			if not _under_wall(gx, gy, size):  # (a wall tile hides it all)
				# The gap around the stone, then the stone (no pixel drawn twice).
				batch.rect(Rect2(r.position, Vector2(r.size.x, inner.position.y - r.position.y)), Palette.FLOOR_GAP)
				batch.rect(Rect2(r.position.x, inner.end.y, r.size.x, r.end.y - inner.end.y), Palette.FLOOR_GAP)
				batch.rect(Rect2(r.position.x, inner.position.y, inner.position.x - r.position.x, inner.size.y), Palette.FLOOR_GAP)
				batch.rect(Rect2(inner.end.x, inner.position.y, r.end.x - inner.end.x, inner.size.y), Palette.FLOOR_GAP)
				batch.rect(inner, base)
				# Bevel: lit top-left edges, shadowed bottom-right edges.
				batch.line(inner.position, Vector2(inner.end.x, inner.position.y), base.lightened(0.08), 1.5)
				batch.line(inner.position, Vector2(inner.position.x, inner.end.y), base.lightened(0.04), 1.5)
				batch.line(Vector2(inner.position.x, inner.end.y), inner.end, base.darkened(0.3), 1.5)
				batch.line(Vector2(inner.end.x, inner.position.y), inner.end, base.darkened(0.2), 1.5)
			# Moss creeping in at some corners.
			if _hash(gx, gy, 3) < 0.1:
				var corner := inner.position + inner.size * Vector2(round(_hash(gx, gy, 4)), round(_hash(gx, gy, 5)))
				for k in 6:
					var mp := corner + Vector2(_hash(gx, gy, 10 + k) - 0.5, _hash(gx, gy, 20 + k) - 0.5) * 22.0
					batch.circle(mp, 2.0 + 4.0 * _hash(gx, gy, 30 + k), Color(Palette.MOSS, 0.3))
			# The odd crack.
			if _hash(gx, gy, 7) < 0.12 and not _under_wall(gx, gy, size):
				var p0 := inner.position + inner.size * Vector2(_hash(gx, gy, 8), 0.1)
				var p1 := inner.position + inner.size * Vector2(0.5, 0.55)
				var p2 := inner.position + inner.size * Vector2(_hash(gx, gy, 9), 0.92)
				batch.polyline(PackedVector2Array([p0, p1, p2]), base.darkened(0.4), 1.0)

	_draw_looks()
	# A soft darkening toward the walls, so the floor feels enclosed.
	for i in 6:
		var k := float(i) / 6.0
		_outline(room.grow(-i * 7.0), Color(0, 0, 0, 0.07 * (1.0 - k)), 7.0)

	# (a tower may draw its own walls, rock, cover and door posts: tower_floor.gd paint_layout)
	if layout_painter == null or not is_instance_valid(layout_painter) or not layout_painter.paint_layout(self, batch):
		_draw_walls()
		_draw_layout()
		for b in blocks:
			_draw_cover(b)
		for d in doors:
			_draw_door_post(d)
	chunk_items = batch.flush(get_canvas_item(), -1)  # under features and ambient
	batch = null
	tint = self_modulate
	features.self_modulate = tint
	for ci in chunk_items:
		RenderingServer.canvas_item_set_self_modulate(ci, tint)
	features.queue_redraw()


func _draw_features() -> void:
	var c := Draw.Batch.new()  # everything in one draw call
	for pd in puddles:
		# Standing water: dark, with a lighter rim and a glint.
		c.circle(pd["pos"], pd["r"], Color(0.1, 0.22, 0.28, 0.75))
		c.circle(pd["pos"], pd["r"] * 0.8, Color(0.14, 0.3, 0.36, 0.6))
		c.arc(pd["pos"], pd["r"], 0.0, TAU, 40, Color(0.5, 0.75, 0.8, 0.35), 2.0)
		c.arc(pd["pos"] + Vector2(-pd["r"] * 0.2, -pd["r"] * 0.25), pd["r"] * 0.35, PI * 1.1, PI * 1.6, 10, Color(0.8, 0.95, 1.0, 0.35), 2.0)
	for ch in chasms:
		# A gap in the floor: a cracked lip, then darkness falling away.
		var r: Rect2 = ch
		c.rect(r.grow(3.0), Color(0.12, 0.1, 0.1))
		c.rect(r, Color(0.02, 0.015, 0.03))
		for i in 4:
			var o := r.grow(-2.0 - i * 3.0)
			var dark := Color(0.0, 0.0, 0.0, 0.25)
			c.rect(Rect2(o.position.x - 1.5, o.position.y - 1.5, o.size.x + 3.0, 3.0), dark)
			c.rect(Rect2(o.position.x - 1.5, o.end.y - 1.5, o.size.x + 3.0, 3.0), dark)
			c.rect(Rect2(o.position.x - 1.5, o.position.y + 1.5, 3.0, o.size.y - 3.0), dark)
			c.rect(Rect2(o.end.x - 1.5, o.position.y + 1.5, 3.0, o.size.y - 3.0), dark)
		c.line(r.position, Vector2(r.end.x, r.position.y), Color(0.55, 0.5, 0.45, 0.6), 2.0)
		c.line(Vector2(r.position.x, r.end.y), r.end, Color(0.3, 0.27, 0.25, 0.8), 2.0)
	for p in pillars:
		_draw_pillar(c, p["pos"], p["r"])
	c.flush(features)
	for sp in springs:
		_draw_spring(features, sp)
	for cp in camps:
		_draw_camp(features, cp["pos"])


## Each themed room's floor: a wash of its colour, and marks for some
## (bones in a den or a crypt, scorch in a hazard room).
func _draw_looks() -> void:
	for lk in looks:
		var tint: Color = lk.get("tint", Color(0, 0, 0, 0))
		var walk: Array = lk.get("walk", [])
		if tint.a > 0.0:
			for r in walk:
				batch.rect(r, tint)
			# A brighter line just inside the room's edge, so the colour reads.
			var rows: Array = lk.get("rows", [])
			var at: Vector2 = lk.get("rect", Rect2()).position
			var line := Color(tint, minf(tint.a * 1.6, 0.25))
			for y in rows.size():
				var row: String = rows[y]
				for x in row.length():
					if row[x] == "X":
						continue
					var tl := at + Vector2(x, y) * TILE
					if y == 0 or String(rows[y - 1])[x] == "X":
						batch.rect(Rect2(tl + Vector2(0, 2), Vector2(TILE, 2)), line)
					if y == rows.size() - 1 or String(rows[y + 1])[x] == "X":
						batch.rect(Rect2(tl + Vector2(0, TILE - 4), Vector2(TILE, 2)), line)
					if x == 0 or row[x - 1] == "X":
						batch.rect(Rect2(tl + Vector2(2, 0), Vector2(2, TILE)), line)
					if x == row.length() - 1 or row[x + 1] == "X":
						batch.rect(Rect2(tl + Vector2(TILE - 4, 0), Vector2(2, TILE)), line)
		if walk.is_empty():
			continue
		var box: Rect2 = lk.get("rect", walk[0])
		var seed := int(box.position.x) * 7 + int(box.position.y) * 13
		if String(lk.get("shape", "")) == "split":
			_draw_split(lk.get("rows", []), box.position)
		match String(lk.get("decor", "")):
			"bones":
				for k in 7:
					var p := box.position + box.size * Vector2(0.1 + 0.8 * _hash(seed, k, 41), 0.12 + 0.76 * _hash(seed, k, 42))
					if _in_walk(p, walk):
						_draw_bone(p, _hash(seed, k, 43) * TAU, 7.0 + 5.0 * _hash(seed, k, 44))
			"scorch":
				for k in 4:
					var p := box.position + box.size * Vector2(0.15 + 0.7 * _hash(seed, k, 45), 0.15 + 0.7 * _hash(seed, k, 46))
					if _in_walk(p, walk):
						batch.circle(p, 14.0 + 10.0 * _hash(seed, k, 47), Color(0, 0, 0, 0.16))
						batch.circle(p, 7.0 + 5.0 * _hash(seed, k, 48), Color(0, 0, 0, 0.14))
			"glass":  # a mirror room (mirror.gd)
				Mirror.draw_glass(batch, lk.get("rows", []), box.position, TILE, seed)
			"ripples":
				for k in 4:
					var p := box.position + box.size * Vector2(0.15 + 0.7 * _hash(seed, k, 49), 0.15 + 0.7 * _hash(seed, k, 50))
					if _in_walk(p, walk):
						var rr := 10.0 + 8.0 * _hash(seed, k, 51)
						for q in 2:
							var pts := PackedVector2Array()
							for i in 13:
								pts.append(p + Vector2.from_angle(TAU * i / 12.0) * (rr + q * 7.0))
							batch.polyline(pts, Color(0.6, 0.85, 0.9, 0.12), 1.5)


## A room on two levels (rooms.gd "split"): the floor above the ledge is
## raised (lit a little, a shadow cast along the ledge's foot) and the gaps
## through the ledge are steps.
func _draw_split(rows: Array, at: Vector2) -> void:
	var ledge := -1
	for y in rows.size():
		var row: String = rows[y]
		if row.count("#") >= row.length() - 6 and row.count("#") >= 4:
			ledge = y
			break
	if ledge < 0:
		return
	for y in ledge:
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "X" and row[x] != "#":
				batch.rect(Rect2(at + Vector2(x, y) * TILE, Vector2(TILE, TILE)), Color(1.0, 0.96, 0.88, 0.05))
	var row_l: String = rows[ledge]
	for x in row_l.length():
		var tl := at + Vector2(x, ledge) * TILE
		if row_l[x] == "#":
			batch.rect(Rect2(tl + Vector2(0, TILE), Vector2(TILE, 6.0)), Color(0, 0, 0, 0.18))
		elif row_l[x] != "X":
			# Steps: treads lit along their front edges, darker going down.
			for k in 4:
				var y0: float = tl.y + k * TILE / 4.0
				batch.rect(Rect2(Vector2(tl.x + 2.0, y0), Vector2(TILE - 4.0, TILE / 4.0 - 1.0)), Color(0, 0, 0, 0.06 + 0.04 * k))
				batch.line(Vector2(tl.x + 2.0, y0), Vector2(tl.x + TILE - 2.0, y0), Color(1.0, 0.95, 0.85, 0.16), 1.5)


func _in_walk(p: Vector2, walk: Array) -> bool:
	for r in walk:
		if r.size.x > 60.0 and r.size.y > 60.0 and r.grow(-24.0).has_point(p):
			return true
	return false


func _draw_bone(c: Vector2, a: float, len: float) -> void:
	var col := Color(0.78, 0.74, 0.64, 0.75)
	var d := Vector2.from_angle(a)
	var n := d.orthogonal() * 1.8
	var p0 := c - d * len * 0.5
	var p1 := c + d * len * 0.5
	batch.line(p0, p1, col, 2.6)
	for p in [p0, p1]:
		batch.circle(p + n, 1.9, col)
		batch.circle(p - n, 1.9, col)


## A healing spring: a pool of clear water ringed with stones (dull and
## dry once used up).
func _draw_spring(c: CanvasItem, sp: Dictionary) -> void:
	var pos: Vector2 = sp["pos"]
	var r: float = sp["r"]
	var full: bool = sp.get("left", 0.0) > 0.0
	var b := Draw.Batch.new()
	for i in 12:
		var a := TAU * i / 12.0
		var sr := 6.0 + 2.0 * _hash(int(pos.x) + i, int(pos.y), 61)
		b.circle(pos + Vector2.from_angle(a) * (r + 4.0), sr + 1.5, Palette.OUTLINE)
		b.circle(pos + Vector2.from_angle(a) * (r + 4.0), sr, Palette.WALL_FACE.lightened(0.1 + 0.1 * _hash(i, int(pos.x), 62)))
	if full:
		b.circle(pos, r, Color(0.1, 0.3, 0.32))
		b.circle(pos + Vector2(-2, -2), r * 0.82, Color(0.16, 0.48, 0.48))
		b.circle(pos + Vector2(-4, -5), r * 0.5, Color(0.25, 0.62, 0.6))
		b.arc(pos + Vector2(-r * 0.25, -r * 0.3), r * 0.42, PI * 1.1, PI * 1.6, 10, Color(0.85, 1.0, 0.95, 0.55), 2.0)
		b.arc(pos + Vector2(r * 0.2, r * 0.2), r * 0.3, PI * 0.1, PI * 0.6, 8, Color(0.85, 1.0, 0.95, 0.3), 1.5)
	else:
		b.circle(pos, r, Color(0.13, 0.12, 0.13))
		b.circle(pos + Vector2(3, 3), r * 0.6, Color(0.1, 0.09, 0.1))
	b.flush(c)


## A fallen climber's cold camp: a ring of stones round charred logs, and a bedroll.
func _draw_camp(c: CanvasItem, pos: Vector2) -> void:
	var b := Draw.Batch.new()
	b.circle(pos, 17.0, Color(0.08, 0.07, 0.07, 0.8))  # ash
	for i in 9:
		var a := TAU * i / 9.0
		b.circle(pos + Vector2.from_angle(a) * 19.0, 5.5, Palette.OUTLINE)
		b.circle(pos + Vector2.from_angle(a) * 19.0, 4.2, Palette.WALL_FACE.lightened(0.15 * _hash(i, int(pos.x), 63)))
	for a in [0.5, -0.6, 1.9]:
		var d := Vector2.from_angle(a)
		b.line(pos - d * 12.0, pos + d * 12.0, Palette.OUTLINE, 6.0)
		b.line(pos - d * 11.0, pos + d * 11.0, Color(0.16, 0.11, 0.08), 4.0)
	b.circle(pos + Vector2(2, -1), 2.0, Color(0.9, 0.45, 0.2, 0.6))  # the last ember
	# The bedroll, unrolled to one side.
	var roll := Rect2(pos + Vector2(-58, -14), Vector2(26, 44))
	b.rect(roll.grow(1.5), Palette.OUTLINE)
	b.rect(roll, Color(0.36, 0.3, 0.22))
	b.rect(Rect2(roll.position, Vector2(roll.size.x, 10)), Color(0.45, 0.38, 0.28))
	b.flush(c)


## The walls between rooms: solid tiles drawn as stone, with a brick front
## face where a wall looks down onto the floor (like the north wall).
func _draw_layout() -> void:
	if grid == Vector2i.ZERO:
		return
	for y in grid.y:
		for x in grid.x:
			if solid[y * grid.x + x] == 0 or block_tiles.has(Vector2i(x, y)):
				continue
			var tile :=Rect2(room.position + Vector2(x, y) * TILE, Vector2(TILE, TILE))
			var open_s := y + 1 < grid.y and solid[(y + 1) * grid.x + x] == 0
			var open_n := y > 0 and solid[(y - 1) * grid.x + x] == 0
			var open_w := x > 0 and solid[y * grid.x + x - 1] == 0
			var open_e := x + 1 < grid.x and solid[y * grid.x + x + 1] == 0
			batch.rect(tile, Palette.VOID.lerp(Palette.WALL_TOP, 0.55 if (open_s or open_n or open_w or open_e) else 0.25))
			if open_s:
				# The wall's brick face, seen from the floor below it.
				var face := Rect2(tile.position + Vector2(0, TILE * 0.35), Vector2(TILE, TILE * 0.65))
				batch.rect(face, Palette.WALL_FACE)
				for row in 3:
					var by := face.position.y + row * face.size.y / 3.0
					var off := 9.0 if row % 2 == 1 else 0.0
					for bx in [0.0, 18.0, 36.0]:
						var b := Rect2(Vector2(face.position.x + bx - off, by), Vector2(18.0, face.size.y / 3.0)).intersection(face)
						if b.size.x > 1.0:
							batch.rect(b.grow(-1.0), Palette.WALL_FACE.lightened(_hash(x * 3 + int(bx), y * 3 + row, 5) * 0.12))
				# Its shadow on the floor.
				batch.rect(Rect2(tile.position + Vector2(0, TILE), Vector2(TILE, 8.0)), Color(0, 0, 0, 0.22))
			if open_n:
				batch.line(tile.position, Vector2(tile.end.x, tile.position.y), Palette.WALL_EDGE, 2.0)
			if open_w:
				batch.line(tile.position, Vector2(tile.position.x, tile.end.y), Palette.WALL_EDGE, 2.0)
			if open_e:
				batch.line(Vector2(tile.end.x, tile.position.y), tile.end, Palette.WALL_EDGE, 2.0)


## A low wall inside a room, seen from above: a shadow, a stone top and a
## short brick face toward the viewer.
func _draw_cover(b: Rect2) -> void:
	var face_h := 14.0
	batch.rect(Rect2(b.position + Vector2(4, b.size.y), Vector2(b.size.x, 8.0)), Color(0, 0, 0, 0.28))
	batch.rect(b.grow(1.5), Palette.OUTLINE)
	var top := Rect2(b.position, Vector2(b.size.x, b.size.y - face_h))
	var face := Rect2(Vector2(b.position.x, b.end.y - face_h), Vector2(b.size.x, face_h))
	batch.rect(top, Palette.WALL_TOP.lightened(0.04))
	# Capstones along the top.
	var horizontal := b.size.x >= b.size.y
	var n := int(round((b.size.x if horizontal else b.size.y) / TILE))
	for i in n:
		var cap := Rect2(top.position + (Vector2(i * TILE, 0) if horizontal else Vector2(0, i * TILE)), Vector2(TILE, TILE)).intersection(top).grow(-2.0)
		if cap.size.x > 2.0 and cap.size.y > 2.0:
			var shade := _hash(int(b.position.x) + i, int(b.position.y), 11) * 0.1
			batch.rect(cap, Palette.WALL_TOP.lightened(0.1 + shade))
			batch.line(cap.position, Vector2(cap.end.x, cap.position.y), Palette.WALL_EDGE, 1.5)
	batch.rect(face, Palette.WALL_FACE)
	var off := 0.0
	for row in 2:
		var by := face.position.y + row * face_h * 0.5
		var bx := face.position.x - off
		while bx < face.end.x:
			var brick := Rect2(Vector2(bx, by), Vector2(18.0, face_h * 0.5)).intersection(face)
			if brick.size.x > 1.0:
				batch.rect(brick.grow(-0.8), Palette.WALL_FACE.lightened(_hash(int(bx), int(by), 12) * 0.12))
			bx += 18.0
		off = 9.0


## A door-frame post: a squared stone column on the wall tile beside an
## opening, so rooms read as rooms.
func _draw_door_post(t: Rect2) -> void:
	var post := t.grow(3.0)
	batch.rect(Rect2(post.position + Vector2(4, 6), post.size), Color(0, 0, 0, 0.3))
	batch.rect(post, Palette.OUTLINE)
	batch.rect(post.grow(-2.0), Palette.WALL_FACE.darkened(0.1))
	var cap := Rect2(post.position + Vector2(2, 2), Vector2(post.size.x - 4.0, post.size.y * 0.55))
	batch.rect(cap, Palette.WALL_TOP.lightened(0.22))
	batch.rect(cap.grow(-5.0), Palette.WALL_TOP.lightened(0.1))
	batch.line(cap.position, Vector2(cap.end.x, cap.position.y), Palette.WALL_EDGE.lightened(0.2), 2.0)
	batch.line(Vector2(post.position.x + 2.0, cap.end.y), Vector2(post.end.x - 2.0, cap.end.y), Palette.WALL_FACE.darkened(0.35), 1.5)


## A side room's essence cache: a squat urn glowing with the tower's essence
## (dark and cracked open once taken).
func _draw_cache(c: CanvasItem, t: float) -> void:
	if cache.is_empty():
		return
	var pos: Vector2 = cache["pos"]
	var col: Color = Essence.color(cache["kind"])
	var taken: bool = cache["taken"]
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	c.draw_set_transform(pos + Vector2(3, 16), 0.0, Vector2(1.0, 0.45))
	c.draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.35))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not taken:
		c.draw_circle(pos, 30.0 + pulse * 5.0, Color(col, 0.10 + 0.08 * pulse))
	var clay := Color(0.42, 0.33, 0.27) if not taken else Color(0.25, 0.21, 0.19)
	# Body, neck and rim.
	c.draw_circle(pos + Vector2(0, 4), 15.0, Palette.OUTLINE)
	c.draw_circle(pos + Vector2(0, 4), 13.5, clay)
	c.draw_circle(pos + Vector2(-4, 0), 6.0, clay.lightened(0.15))
	c.draw_rect(Rect2(pos + Vector2(-7, -16), Vector2(14, 10)), Palette.OUTLINE)
	c.draw_rect(Rect2(pos + Vector2(-5.5, -15), Vector2(11, 9)), clay.darkened(0.1))
	Draw.line(c, pos + Vector2(-10, -16), pos + Vector2(10, -16), clay.lightened(0.2), 3.0)
	# A glowing band around the belly.
	c.draw_arc(pos + Vector2(0, 4), 10.0, PI * 0.15, PI * 0.85, 10, Color(col, 0.9 if not taken else 0.15), 2.0)
	if taken:
		c.draw_polyline(PackedVector2Array([pos + Vector2(-3, -14), pos + Vector2(1, -4), pos + Vector2(-2, 6)]), Palette.OUTLINE, 1.5)
	else:
		# Essence welling out of the mouth.
		for i in 3:
			var k := fmod(t * 0.8 + i / 3.0, 1.0)
			c.draw_circle(pos + Vector2(sin(t * 3.0 + i * 2.0) * 4.0, -18.0 - k * 22.0), 2.5 * (1.0 - k) + 0.5, Color(col, 0.9 * (1.0 - k)))


func _draw_pillar(c, pos: Vector2, r: float) -> void:
	# Seen from above: a round stone column with a shadow, rim and cap.
	var shadow := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		shadow.append(pos + Vector2(r * 0.25, r * 0.55) + Vector2(cos(a), sin(a) * 0.55) * r * 1.15)
	c.polygon(shadow, Color(0, 0, 0, 0.35))
	c.circle(pos, r + 2.0, Palette.OUTLINE)
	c.circle(pos, r, Palette.WALL_FACE.darkened(0.15))
	c.circle(pos + Vector2(-r * 0.1, -r * 0.12), r * 0.86, Palette.WALL_FACE)
	c.arc(pos, r * 0.62, 0.0, TAU, 32, Palette.WALL_FACE.darkened(0.25), 1.5)
	c.circle(pos + Vector2(-r * 0.3, -r * 0.34), r * 0.25, Color(Palette.WALL_EDGE.lightened(0.2), 0.5))
	# A few cracks so pillars aren't identical.
	var h := _hash(int(pos.x), int(pos.y))
	for i in 2:
		var a := (h + i * 0.37) * TAU
		c.line(pos + Vector2.from_angle(a) * r * 0.3, pos + Vector2.from_angle(a + 0.2) * r * 0.85, Palette.WALL_FACE.darkened(0.35), 1.0)


func _draw_stair(c, t: float) -> void:
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
	var b = Draw.Batch.new()  # the stair, torches, embers and dust in one draw
	# Only what's on screen.
	var view := _view_rect().grow(-220.0)
	if view.grow(60.0).has_point(stair_pos):
		_draw_stair(b, t)
	if not cache.is_empty() and view.grow(60.0).has_point(cache["pos"]):
		b.flush(c)
		_draw_cache(c, t)
	if not lost_cache.is_empty() and view.grow(60.0).has_point(lost_cache["pos"]):
		b.flush(c)
		Lost.draw(c, lost_cache["pos"], t, lost_cache["taken"])
	for torch in torches:
		if view.has_point(torch["pos"]):
			_draw_torch(b, torch["pos"], t + torch["phase"])
	for e in embers:
		var a: float = clampf(e["t"], 0.0, 1.0)
		b.circle(e["pos"], 1.3, Color(1.0, 0.65, 0.25, a), 8)
	for d in dust:
		if view.has_point(d["pos"]):
			var a: float = 0.08 + 0.06 * sin(t * 1.3 + d["phase"])
			b.circle(d["pos"], d["size"], Color(1.0, 0.92, 0.8, a), 8)
	b.flush(c)


func _draw_walls() -> void:
	var r := room
	# Side and bottom walls: seen from above as thick stone rims.
	var rim := Palette.WALL_TOP
	batch.rect(Rect2(r.position.x - wall, r.position.y, wall, r.size.y + wall), rim)
	batch.rect(Rect2(r.end.x, r.position.y, wall, r.size.y + wall), rim)
	batch.rect(Rect2(r.position.x - wall, r.end.y, r.size.x + wall * 2.0, wall), rim)
	batch.line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Palette.WALL_EDGE, 2.0)
	batch.line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Palette.WALL_EDGE, 2.0)
	batch.line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Palette.WALL_EDGE, 2.0)

	# North wall: we see its brick front face, which gives the room depth.
	var face := Rect2(r.position.x - wall, r.position.y - WALL_FACE, r.size.x + wall * 2.0, WALL_FACE)
	batch.rect(Rect2(face.position - Vector2(0, wall), Vector2(face.size.x, wall)), rim)
	batch.rect(face, Palette.WALL_FACE)
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
				batch.rect(b.grow(-1.0), Palette.WALL_FACE.lightened(shade))
				batch.line(b.position + Vector2(1, 1), Vector2(b.end.x - 1, b.position.y + 1), Palette.WALL_FACE.lightened(shade + 0.1), 1.0)
			x += brick.x
		y += brick.y
		row += 1
	# Shadow the wall casts onto the floor.
	for i in 5:
		batch.rect(Rect2(r.position.x, r.position.y + i * 4.0, r.size.x, 4.0), Color(0, 0, 0, 0.32 - i * 0.06))

	# Pillars at the corners.
	for px in [r.position.x - wall, r.end.x - 6.0]:
		var p := Rect2(px, r.position.y - WALL_FACE - wall, wall + 6.0, WALL_FACE + wall + 10.0)
		batch.rect(p, Palette.WALL_TOP.darkened(0.15))
		batch.rect(Rect2(p.position, Vector2(p.size.x, 6.0)), Palette.WALL_EDGE)


func _draw_torch(c, pos: Vector2, t: float) -> void:
	# Iron bracket.
	c.draw_rect(Rect2(pos + Vector2(-3, 4), Vector2(6, 14)), Color(0.13, 0.11, 0.12))
	c.draw_rect(Rect2(pos + Vector2(-6, 2), Vector2(12, 4)), Color(0.2, 0.17, 0.17))
	# Flame: layered teardrops that flicker.
	var h := 13.0 + 2.5 * sin(t * 11.0) + 1.5 * sin(t * 27.0)
	var sway := 1.5 * sin(t * 7.0)
	_flame(c, pos, h, 6.0, sway, Color(0.95, 0.35, 0.12, 0.9))
	_flame(c, pos, h * 0.72, 4.2, sway * 0.7, Color(1.0, 0.65, 0.2, 0.95))
	_flame(c, pos, h * 0.42, 2.6, sway * 0.4, Color(1.0, 0.93, 0.7))


func _flame(c, base: Vector2, h: float, w: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var p := Vector2(sin(a) * w, -cos(a) * w * 0.8)
		if p.y < 0.0:
			p.y *= h / w
			p.x += sway * (-p.y / h)
		pts.append(base + p)
	c.draw_colored_polygon(pts, col)
