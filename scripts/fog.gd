extends Node2D
## Line-of-sight fog on floors of rooms: you see only what your climber can
## see. Walls (and low walls) block sight; chasms, water and pillars don't.
## Places you've seen stay dimly mapped; places you haven't are dark.
## Monsters out of sight are hidden.
##
## Cheap on phones: one tiny one-channel texture (a pixel per 40 px tile).
## Sight is worked out again at most LOOK_RATE times a second, and only when
## the climber has moved to a new tile; the fog then eases only around the
## climber, and the texture is written in one go from a byte buffer. It is
## drawn by the darkness layer (lighting.gd) in the same pass as the light,
## stretched over the floor with smooth filtering so the edges are soft.

## How far the climber sees, in tiles.
const RADIUS := 11
## How dark the fog is: never seen, and seen before but out of sight now.
const DARK := 1.0
const REMEMBERED := 0.6
## How fast the fog clears or closes (alpha per second).
const FADE := 5.0
## Most times a second sight is worked out again (the web version: 12).
const LOOK_RATE := 12.0

var main
var grid := Vector2i.ZERO
var seen := PackedByteArray()  # 1 once a tile has been seen this floor
var vis := PackedByteArray()  # 1 while a tile is in sight
var shade := PackedFloat32Array()  # the fog's alpha per tile, easing toward its target
var bytes := PackedByteArray()  # the fog's alpha per tile, 0..255 (the texture's data)
var img: Image
var tex: ImageTexture
var last_tile := Vector2i(-999, -999)
var easing := false
var look_t := 0.0  # until sight may be worked out again
var looks := 0  # times sight was worked out (tests and the dev readout)
## The tiles whose fog may still be easing: around where sight was last
## worked out, and around where it was worked out before that.
var ease_box := Rect2i()


func _ready() -> void:
	pass  # (drawn by lighting.gd: this node only keeps the fog's texture)


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
	bytes = PackedByteArray()
	bytes.resize(n)
	bytes.fill(int(DARK * 255.0))
	img = Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_L8, bytes)
	tex = ImageTexture.create_from_image(img)
	_look()
	_snap()


func _process(delta: float) -> void:
	if not visible or grid == Vector2i.ZERO or main == null or main.player == null:
		return
	look_t -= delta
	var t: Vector2i = main._tile_of(main.player.global_position)
	# (A jump of more than a step, like a blink or a swap, is seen at once.)
	if t != last_tile and (look_t <= 0.0 or absi(t.x - last_tile.x) + absi(t.y - last_tile.y) > 2):
		_look()
	if easing:
		_ease(delta)
	_hide_unseen_foes()


## Works out what's in sight from the climber's tile.
func _look() -> void:
	var from: Vector2i = main._tile_of(main.player.global_position)
	look_t = 1.0 / LOOK_RATE
	looks += 1
	# Only tiles near the old and the new spot can change.
	var box := Rect2i(from - Vector2i(RADIUS + 1, RADIUS + 1), Vector2i(RADIUS * 2 + 3, RADIUS * 2 + 3))
	if last_tile.x > -999:
		box = box.merge(Rect2i(last_tile - Vector2i(RADIUS + 1, RADIUS + 1), Vector2i(RADIUS * 2 + 3, RADIUS * 2 + 3)))
	if easing:
		box = box.merge(ease_box)  # (a fade still under way there)
	ease_box = box.intersection(Rect2i(Vector2i.ZERO, grid))
	last_tile = from
	# Clear last time's sight (only near where it was).
	for y in range(ease_box.position.y, ease_box.end.y):
		var row := y * grid.x
		for x in range(ease_box.position.x, ease_box.end.x):
			vis[row + x] = 0
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


## Eases the fog near the climber toward what it should be, and repaints
## the texture in one go.
func _ease(delta: float) -> void:
	var moving := false
	var step := FADE * delta
	for y in range(ease_box.position.y, ease_box.end.y):
		var row := y * grid.x
		for x in range(ease_box.position.x, ease_box.end.x):
			var i := row + x
			var want := _target(i)
			var cur := shade[i]
			if cur != want:
				cur = move_toward(cur, want, step)
				shade[i] = cur
				bytes[i] = int(cur * 255.0)
				moving = true
	easing = moving
	_upload()


## Jumps straight to the right fog (a new floor).
func _snap() -> void:
	for i in shade.size():
		shade[i] = _target(i)
		bytes[i] = int(shade[i] * 255.0)
	easing = false
	_upload()


func _upload() -> void:
	img.set_data(grid.x, grid.y, false, Image.FORMAT_L8, bytes)
	tex.update(img)


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
		var show: bool = sees(e.global_position) or e.global_position.distance_to(pp) < 70.0
		if e.visible != show:
			e.visible = show


func _show_all_foes() -> void:
	if main == null:
		return
	for e in main.enemies():
		e.visible = true

