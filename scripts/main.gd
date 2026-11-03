extends Node2D
## Prototype room: one fight to test whether bonds feel good.
## Builds the walls, spawns the climber and three kinds of monster.

const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio.gd")
const RoomScript := preload("res://scripts/room.gd")
const Palette := preload("res://scripts/palette.gd")
const TouchScript := preload("res://scripts/touch.gd")
const Floors := preload("res://scripts/floors.gd")

const SAVE_PATH := "user://sixfold.cfg"
const STAIR_REACH := 26.0

const WALL := 24.0

var room := Rect2(80, 100, 1120, 530)
var player
var fx
var camera: Camera2D
var cleared := false
var shake_amount := 0.0
var audio
var hitstop_until := 0  # real-time msec when the freeze ends
var hurt_flash := 0.0
var light_tex: Texture2D
var touch_active := false  # on-screen controls in use

# The climb
var floor_num := 1
var best_floor := 1
var pillars: Array = []  # {pos, r}
var pillar_bodies: Array = []
var stair_open := false
var stair_pos := Vector2.ZERO
var climbing := false
var fade := 0.0  # black screen between floors, 0..1
var banner := {}  # {title, lines, t}: shown when a floor starts
var room_view
var player_start := Vector2.ZERO

# Attack turns: only this many monsters may be attacking at once.
const MAX_ATTACKERS := 2
var attackers: Array = []


func _ready() -> void:
	# Run after the bodies have moved, so the shove-apart pass sees this frame.
	process_physics_priority = 10
	randomize()
	Engine.time_scale = 1.0  # in case we restarted mid hit-pause
	Controls.setup()
	audio = AudioScript.new()
	add_child(audio)
	_build_walls()

	# Lighting: the whole room is dimmed, torches and the climber's own glow
	# light it back up. Effects ignore the dimming so spells always read.
	RenderingServer.set_default_clear_color(Palette.VOID)
	y_sort_enabled = true  # lower things draw in front of higher things
	var dim := CanvasModulate.new()
	dim.color = Palette.AMBIENT
	add_child(dim)
	room_view = RoomScript.new()
	room_view.setup(room, WALL)
	add_child(room_view)
	light_tex = RoomScript.make_light_texture()

	player_start = Vector2(room.get_center().x, room.end.y - 60.0)
	stair_pos = Vector2(room.get_center().x, room.position.y + 34.0)
	room_view.stair_pos = stair_pos
	player = PlayerScript.new()
	player.main = self
	player.position = Vector2(300, 365)  # floor 1 starts on the left, facing the fight
	add_child(player)
	var glow := PointLight2D.new()
	glow.texture = light_tex
	glow.texture_scale = 1.4
	glow.color = Color(1.0, 0.85, 0.7)
	glow.energy = 0.55
	player.add_child(glow)

	_load_best()
	_start_floor(1)

	fx = FxScript.new()
	fx.z_index = 10
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.material = unlit
	add_child(fx)

	# The camera follows the climber, zoomed in, but never past the walls.
	camera = Camera2D.new()
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(room.position.x - WALL - 20.0)
	camera.limit_right = int(room.end.x + WALL + 20.0)
	camera.limit_top = int(room.position.y - RoomScript.WALL_FACE - WALL - 20.0)
	camera.limit_bottom = int(room.end.y + WALL + 70.0)  # room for the bond HUD
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)
	var touch = TouchScript.new()
	touch.main = self
	layer.add_child(touch)


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
	if hitstop_until > 0 and Time.get_ticks_msec() >= hitstop_until:
		hitstop_until = 0
		Engine.time_scale = 1.0
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("step_up"):
		_change_step(1)
	if Input.is_action_just_pressed("step_down"):
		_change_step(-1)
	if Input.is_action_just_pressed("toggle_music") and audio != null:
		fx_text(player.global_position + Vector2(0, -44), "Music on" if audio.toggle_music() else "Music off", Color(0.85, 0.82, 0.9))
	if not cleared and not climbing and enemies().is_empty():
		cleared = true
		stair_open = true
		room_view.stair_open = true
		sfx("clear", 1.0, 0.0, 0.0)
	if stair_open and not climbing and not player.dead and player.global_position.distance_to(stair_pos) < STAIR_REACH + player.radius:
		_climb()
	if not banner.is_empty():
		banner["t"] -= delta
		if banner["t"] <= 0.0:
			banner = {}
	if player != null:
		camera.position = player.position
	# On phones the whole game is already drawn bigger, so pull the camera back.
	var want := 1.1 if touch_active else 1.35
	camera.zoom = Vector2(want, want)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
	shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)
	hurt_flash = move_toward(hurt_flash, 0.0, delta)


func _physics_process(_delta: float) -> void:
	_separate_bodies()


## Bodies can't share space: overlapping ones are pushed apart, and the
## lighter one gives way more. Foes lifted into the air pass over everyone.
func _separate_bodies() -> void:
	var bodies: Array = enemies().filter(func(e): return e.airborne <= 0.0)
	if player != null and not player.dead:
		bodies.append(player)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			var d: Vector2 = b.global_position - a.global_position
			var min_d: float = a.radius + b.radius
			var dist := d.length()
			if dist >= min_d:
				continue
			var n := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
			var overlap := min_d - dist
			var share: float = b.weight / (a.weight + b.weight)  # a's part of the push
			a.move_and_collide(-n * overlap * share)
			b.move_and_collide(n * overlap * (1.0 - share))


# --- the climb -------------------------------------------------------------

func _start_floor(n: int) -> void:
	floor_num = n
	cleared = false
	stair_open = false
	room_view.stair_open = false
	# Clear out the last floor: monsters, arrows, pillars.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
		e.remove_from_group("enemies")
	for c in get_children():
		if "reflected" in c:
			c.queue_free()
	attackers.clear()
	for b in pillar_bodies:
		b.queue_free()
	pillar_bodies.clear()

	var start: Vector2 = player.position if n == 1 else player_start
	var plan: Dictionary = Floors.build(n, room, start)
	pillars = plan["pillars"]
	for p in pillars:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = p["pos"]
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = p["r"]
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		pillar_bodies.append(body)
	room_view.set_pillars(pillars)

	var tough := Floors.toughness(n)
	for m in plan["monsters"]:
		var e = EnemyScript.new()
		e.setup(m[0], self)
		e.max_hp *= tough.x
		e.hp = e.max_hp
		e.dmg *= tough.y
		e.position = m[1]
		add_child(e)
	player.position = start
	if camera != null:
		camera.position = start
		camera.reset_smoothing()


## Walking onto the open stair: fade out, rest, grow, fade into the next floor.
func _climb() -> void:
	climbing = true
	player.set_physics_process(false)
	sfx("step", 0.8, 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.45)
	tw.tween_callback(_arrive)
	tw.tween_interval(0.25)
	tw.tween_property(self, "fade", 0.0, 0.5)
	tw.tween_callback(func(): climbing = false)


func _arrive() -> void:
	var lines: Array = []
	# Rest at the stair: burns heal, some health and all stamina return.
	var healed := minf(player.max_hp - player.hp, player.max_hp * 0.35)
	player.hp += healed
	player.sta = player.max_sta
	var burned := false
	for b in player.bonds.values():
		burned = burned or b.burned
		b.burned = false
	if burned:
		lines.append("Your burns heal")
	if healed >= 1.0:
		lines.append("Rested: +%d health" % int(healed))
	# Bonds grow a step every two floors.
	var next := floor_num + 1
	var step := clampi(1 + (next - 1) / 2, 1, 5)
	for b in player.bonds.values():
		if step > b.step:
			b.step = step
			var note: String = b.step_note(step)
			lines.append("%s grows to step %d%s" % [b.display_name(), step, (": " + note) if note != "" else ""])
	_start_floor(next)
	if floor_num > best_floor:
		best_floor = floor_num
		_save_best()
	banner = {"title": "FLOOR %d" % floor_num, "lines": lines, "t": 3.0}
	player.set_physics_process(true)
	sfx("clear", 0.8, -8.0, 0.0)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_floor = int(cfg.get_value("climb", "best_floor", 1))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("climb", "best_floor", best_floor)
	cfg.save(SAVE_PATH)


# --- attack turns ------------------------------------------------------------

func _tidy_attackers() -> void:
	attackers = attackers.filter(func(e): return is_instance_valid(e) and not e.dead)


func can_attack() -> bool:
	_tidy_attackers()
	return attackers.size() < MAX_ATTACKERS


func holds_attack(e) -> bool:
	return e in attackers


## A monster asks for a turn to attack. True if it may go ahead.
func request_attack(e) -> bool:
	if e in attackers:
		return true
	if not can_attack():
		return false
	attackers.append(e)
	return true


func release_attack(e) -> void:
	attackers.erase(e)


func _change_step(by: int) -> void:
	for b in player.bonds.values():
		b.step = clampi(b.step + by, 1, 5)
		b.essence = minf(b.essence, b.capacity())
	fx_text(player.global_position + Vector2(0, -44), "Bond step %d" % player.bonds["hand"].step, Color(1, 1, 1))


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(
		func(e): return is_instance_valid(e) and not e.dead)


func spawn_projectile(pos: Vector2, vel: Vector2, dmg: float) -> Node2D:
	var p = ProjectileScript.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.dmg = dmg
	add_child(p)
	return p


func spawn_player_arrow(pos: Vector2, vel: Vector2, dmg: float, force: float, pierce: bool) -> Node2D:
	var p = spawn_projectile(pos, vel, dmg)
	p.friendly = true
	p.force = force
	p.pierce = pierce
	p.life = 1.6
	return p


func on_enemy_killed(e) -> void:
	fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))
	fx_ring(e.global_position, e.color, 46.0, 0.4, 4.0)
	fx_burst(e.global_position, Vector2.ZERO, e.color, 16, 300.0)
	if fx != null:
		fx.debris(e.global_position, e.color, int(e.radius * 0.8))
	var kill_sound: String = "kill_" + e.kind
	sfx(kill_sound if audio != null and audio.has_sound(kill_sound) else "kill")
	hitstop(0.09)
	shake(6.0)


## Hit-pause: freeze the action for a moment so impacts land.
## Overlapping calls keep the longest freeze.
func hitstop(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until > hitstop_until:
		hitstop_until = until
	Engine.time_scale = 0.02


func sfx(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.06) -> void:
	if audio != null:
		audio.play(sound, pitch, volume_db, variance)


func fx_ring(pos: Vector2, color: Color, reach: float, dur := 0.3, width := 3.0) -> void:
	if fx != null:
		fx.ring(pos, color, reach, dur, width)


func fx_burst(pos: Vector2, dir: Vector2, color: Color, count: int, speed := 260.0) -> void:
	if fx != null:
		fx.burst(pos, dir, color, count, speed)


func fx_ghost(pos: Vector2, radius: float, color: Color) -> void:
	if fx != null:
		fx.ghost(pos, radius, color)


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


## A brief burst of real light: lightning, parries, crits, burns.
func light_flash(pos: Vector2, color: Color, size := 1.5, energy := 1.6, dur := 0.25) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = size
	l.color = color
	l.energy = energy
	l.position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
