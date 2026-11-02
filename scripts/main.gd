extends Node2D
## Prototype room: one fight to test whether bonds feel good.
## Builds the walls, spawns the climber and three kinds of monster.

const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")

const WALL := 24.0

var room := Rect2(80, 80, 1120, 560)
var player
var fx
var camera: Camera2D
var cleared := false
var shake_amount := 0.0


func _ready() -> void:
	randomize()
	Controls.setup()
	_build_walls()

	player = PlayerScript.new()
	player.main = self
	player.position = Vector2(300, 360)
	add_child(player)

	var spawns := [
		["knight", Vector2(760, 360)],
		["slime", Vector2(820, 240)],
		["slime", Vector2(860, 480)],
		["archer", Vector2(1080, 360)],
	]
	for s in spawns:
		var e = EnemyScript.new()
		e.setup(s[0], self)
		e.position = s[1]
		add_child(e)

	fx = FxScript.new()
	fx.z_index = 10
	add_child(fx)

	camera = Camera2D.new()
	camera.position = room.get_center()
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)


func _build_walls() -> void:
	var r := room
	var sides := [
		Rect2(r.position.x - WALL, r.position.y - WALL, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.end.y, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.position.y, WALL, r.size.y),
		Rect2(r.end.x, r.position.y, WALL, r.size.y),
	]
	for s in sides:
		var rect: Rect2 = s
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("step_up"):
		_change_step(1)
	if Input.is_action_just_pressed("step_down"):
		_change_step(-1)
	if not cleared and enemies().is_empty():
		cleared = true
		for b in player.bonds.values():
			b.burned = false
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
	shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)


func _change_step(by: int) -> void:
	for b in player.bonds.values():
		b.step = clampi(b.step + by, 1, 5)
		b.essence = minf(b.essence, b.capacity())
	fx_text(player.global_position + Vector2(0, -44), "Bond step %d" % player.bonds["hand"].step, Color(1, 1, 1))


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(
		func(e): return is_instance_valid(e) and not e.dead)


func spawn_projectile(pos: Vector2, vel: Vector2, dmg: float) -> void:
	var p = ProjectileScript.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.dmg = dmg
	add_child(p)


func on_enemy_killed(e) -> void:
	fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))


func fx_text(pos: Vector2, s: String, color: Color) -> void:
	if fx != null:
		fx.text(pos, s, color)


func fx_bolt(points: Array, color: Color) -> void:
	if fx != null:
		fx.bolt(points, color)


func fx_cone(origin: Vector2, dir: Vector2, reach: float, half: float, color: Color) -> void:
	if fx != null:
		fx.cone(origin, dir, reach, half, color)


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func _draw() -> void:
	draw_rect(room.grow(WALL), Color(0.16, 0.14, 0.2))
	draw_rect(room, Color(0.1, 0.09, 0.13))
	var grid := Color(1, 1, 1, 0.03)
	var x := room.position.x
	while x <= room.end.x:
		draw_line(Vector2(x, room.position.y), Vector2(x, room.end.y), grid, 1.0)
		x += 40.0
	var y := room.position.y
	while y <= room.end.y:
		draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), grid, 1.0)
		y += 40.0
