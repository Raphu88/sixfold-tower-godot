extends Node2D
## Line-of-sight fog on floors of rooms: you see only what your climber can
## see. Walls (and low walls) block sight; chasms, water and pillars don't.
## Places you've seen stay dimly mapped; places you haven't are dark.
## Monsters out of sight are hidden.
##
## Cheap on phones: one tiny texture (a pixel per 40 px tile), redrawn only
## when the climber moves to a new tile, stretched over the floor with
## smooth filtering so the edges are soft. One draw call.

## How far the climber sees, in tiles.
const RADIUS := 11
## How dark the fog is: never seen, and seen before but out of sight now.
const DARK := 1.0
const REMEMBERED := 0.6
## How fast the fog clears or closes (alpha per second).
const FADE := 5.0

var main
var grid := Vector2i.ZERO
var seen := PackedByteArray()  # 1 once a tile has been seen this floor
var vis := PackedByteArray()  # 1 while a tile is in sight
var shade := PackedFloat32Array()  # the fog's alpha per tile, easing toward its target
var img: Image
var tex: ImageTexture
var last_tile := Vector2i(-999, -999)
var easing := false


func _ready() -> void:
	z_index = 40  # over the floor, the monsters and the climber; under the HUD
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit


## A new floor: forget everything (or switch off, on floors without rooms).
func reset() -> void:
	last_tile = Vector2i(-999, -999)
	if main == null or not main.layout_on or main.solid.is_empty():
		grid = Vector2i.ZERO
		visible = false
		_show_all_foes()
		return
	visible = true
	grid = main.grid_size
	var n := grid.x * grid.y
	seen = PackedByteArray()
	seen.resize(n)
	vis = PackedByteArray()
	vis.resize(n)
	shade = PackedFloat32Array()
	shade.resize(n)
	shade.fill(DARK)
	img = Image.create(grid.x, grid.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, DARK))
	tex = ImageTexture.create_from_image(img)
	_look()
	_snap()


func _process(delta: float) -> void:
	if not visible or grid == Vector2i.ZERO or main == null or main.player == null:
		return
	var t: Vector2i = main._tile_of(main.player.global_position)
	if t != last_tile:
		_look()
	if easing:
		_ease(delta)
	_hide_unseen_foes()


## Works out what's in sight from the climber's tile.
func _look() -> void:
	var from: Vector2i = main._tile_of(main.player.global_position)
	last_tile = from
	vis.fill(0)
	var r2 := RADIUS * RADIUS
	for y in range(maxi(0, from.y - RADIUS), mini(grid.y, from.y + RADIUS + 1)):
		for x in range(maxi(0, from.x - RADIUS), mini(grid.x, from.x + RADIUS + 1)):
			var dx := x - from.x
			var dy := y - from.y
			if dx * dx + dy * dy > r2:
				continue
			if _line_clear(from, Vector2i(x, y)):
				var i := y * grid.x + x
				vis[i] = 1
				seen[i] = 1
	easing = true


## True if nothing solid stands between two tiles (the far tile itself may be
## a wall: you see its face).
func _line_clear(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		if x == b.x and y == b.y:
			return true
		if not (x == a.x and y == a.y) and main.solid[y * grid.x + x] == 1:
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


func _target(i: int) -> float:
	if vis[i] == 1:
		return 0.0
	return REMEMBERED if seen[i] == 1 else DARK


## Eases each tile's fog toward what it should be, and repaints the texture.
func _ease(delta: float) -> void:
	var moving := false
	var step := FADE * delta
	for i in shade.size():
		var want := _target(i)
		var cur := shade[i]
		if cur != want:
			cur = move_toward(cur, want, step)
			shade[i] = cur
			img.set_pixel(i % grid.x, i / grid.x, Color(0, 0, 0, cur))
			moving = true
	easing = moving
	tex.update(img)
	queue_redraw()


## Jumps straight to the right fog (a new floor).
func _snap() -> void:
	for i in shade.size():
		shade[i] = _target(i)
		img.set_pixel(i % grid.x, i / grid.x, Color(0, 0, 0, shade[i]))
	easing = false
	tex.update(img)
	queue_redraw()


## Whether a point on the floor is in the climber's sight right now.
func sees(pos: Vector2) -> bool:
	if not visible or grid == Vector2i.ZERO:
		return true
	var t: Vector2i = main._tile_of(pos)
	if t.x < 0 or t.y < 0 or t.x >= grid.x or t.y >= grid.y:
		return false
	return vis[t.y * grid.x + t.x] == 1


func _hide_unseen_foes() -> void:
	var pp: Vector2 = main.player.global_position
	for e in main.enemies():
		e.visible = sees(e.global_position) or e.global_position.distance_to(pp) < 70.0


func _show_all_foes() -> void:
	if main == null:
		return
	for e in main.enemies():
		e.visible = true


func _draw() -> void:
	if tex == null or grid == Vector2i.ZERO:
		return
	var c: float = main.Floors.CELL
	draw_texture_rect(tex, Rect2(main.room.position, Vector2(grid) * c), false)
