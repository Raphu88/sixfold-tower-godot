extends CharacterBody2D
## Prototype monsters: slime, archer and knight. Every attack is telegraphed,
## so a careful player can always read it.

const TYPES := {
	"slime": {"hp": 24.0, "speed": 60.0, "radius": 13.0, "color": Color(0.53, 0.72, 0.36), "dmg": 8.0},
	"archer": {"hp": 18.0, "speed": 75.0, "radius": 11.0, "color": Color(0.87, 0.83, 0.74), "dmg": 8.0},
	"knight": {"hp": 48.0, "speed": 68.0, "radius": 15.0, "color": Color(0.55, 0.59, 0.67), "dmg": 14.0},
}

var kind := "slime"
var main
var hp := 1.0
var max_hp := 1.0
var radius := 12.0
var color := Color.WHITE
var speed := 60.0
var dmg := 8.0
var dead := false

var state := "idle"
var state_t := 0.0
var airborne := 0.0
var stun := 0.0
var charged := 0.0
var flash := 0.0
var contact_cd := 0.0
var aim_dir := Vector2.ZERO
var lunge_dir := Vector2.RIGHT
var lunge_hit := false
var knock := Vector2.ZERO
var squash := 0.0
var squash_dir := Vector2.RIGHT


## Call before adding to the tree.
func setup(k: String, room) -> void:
	kind = k
	main = room
	var t: Dictionary = TYPES[k]
	hp = t["hp"]
	max_hp = hp
	radius = t["radius"]
	color = t["color"]
	speed = t["speed"]
	dmg = t["dmg"]
	state_t = randf_range(0.6, 1.6)
	if kind == "knight":
		state = "chase"


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	flash -= delta
	charged -= delta
	contact_cd -= delta
	squash = move_toward(squash, 0.0, 6.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var p = main.player
	if airborne > 0.0:
		airborne -= delta
		_drift()
		return
	if stun > 0.0:
		stun -= delta
		_drift()
		return
	if p == null or p.dead:
		_drift()
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	match kind:
		"slime":
			_slime(delta, dir, dist, p)
		"archer":
			_archer(delta, dir, dist)
		"knight":
			_knight(delta, dir, dist, p)
	velocity += knock
	move_and_slide()
	queue_redraw()


func _drift() -> void:
	velocity = knock
	move_and_slide()
	queue_redraw()


# Hops toward you; hurts on contact.
func _slime(delta: float, dir: Vector2, dist: float, p) -> void:
	state_t -= delta
	if state == "hop":
		velocity = aim_dir * 190.0
		if state_t <= 0.0:
			state = "rest"
			state_t = 0.8
	else:
		velocity = Vector2.ZERO
		if state_t <= 0.0:
			state = "hop"
			aim_dir = dir
			state_t = 0.35
	if dist < radius + p.radius + 2.0 and contact_cd <= 0.0:
		contact_cd = 0.9
		p.receive_attack(dmg, self)


# Keeps its distance, locks its aim 0.42 s before firing.
func _archer(delta: float, dir: Vector2, dist: float) -> void:
	state_t -= delta
	if aim_dir != Vector2.ZERO:
		velocity = Vector2.ZERO
	elif dist < 170.0:
		velocity = -dir * speed
	elif dist > 260.0:
		velocity = dir * speed
	else:
		velocity = dir.orthogonal() * speed * (1.0 if sin(Time.get_ticks_msec() * 0.0008) > 0.0 else -1.0)
	if state_t <= 0.42 and aim_dir == Vector2.ZERO and dist < 430.0:
		aim_dir = dir
		main.sfx("warn", 1.35, -8.0)
	if state_t <= 0.0:
		if aim_dir != Vector2.ZERO:
			main.spawn_projectile(global_position + aim_dir * radius, aim_dir * 260.0, dmg)
		aim_dir = Vector2.ZERO
		state_t = randf_range(1.6, 2.3)


# Chases, winds up (turning slowly toward you), then lunges in a straight line.
func _knight(delta: float, dir: Vector2, dist: float, p) -> void:
	state_t -= delta
	match state:
		"chase":
			velocity = dir * speed
			if dist < 110.0 and state_t <= 0.0:
				state = "wind"
				state_t = 0.45
				lunge_dir = dir
				main.sfx("warn", 0.75, -4.0)
		"wind":
			velocity = Vector2.ZERO
			if state_t > 0.2:
				lunge_dir = lunge_dir.slerp(dir, minf(1.0, 4.0 * delta))
			if state_t <= 0.0:
				state = "lunge"
				state_t = 0.22
				lunge_hit = false
		"lunge":
			velocity = lunge_dir * 480.0
			if not lunge_hit and dist < radius + p.radius + 8.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.7
		_:
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
				state_t = randf_range(0.4, 0.9)


func take_hit(amount: float, dir: Vector2, force := 140.0) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	squash = 1.0
	if dir != Vector2.ZERO:
		squash_dir = dir
		# The knight is heavy: it barely budges.
		knock = dir * force * (0.4 if kind == "knight" else 1.0)
	main.fx_text(global_position + Vector2(0, -radius - 10.0), str(int(round(amount))), Color(1.0, 0.95, 0.85))
	if hp <= 0.0:
		dead = true
		main.on_enemy_killed(self)
		queue_free()


## Windwalker's Gale Lift: helpless in the air.
func lift(duration: float) -> void:
	airborne = maxf(airborne, duration)
	aim_dir = Vector2.ZERO
	if kind == "knight":
		state = "recover"
		state_t = 0.3
	main.fx_text(global_position + Vector2(0, -radius - 22.0), "Lifted", Color(0.75, 0.9, 1.0))


func stagger(duration: float) -> void:
	stun = maxf(stun, duration)


## A parried knight or slime is staggered and open.
func on_parried() -> void:
	stun = 1.2
	state = "recover"
	state_t = 0.0
	main.fx_text(global_position + Vector2(0, -radius - 22.0), "Staggered", Color(1.0, 0.89, 0.63))


func _draw() -> void:
	var lift_y := -18.0 if airborne > 0.0 else 0.0
	draw_circle(Vector2(0, radius * 0.6), radius * 0.9, Color(0, 0, 0, 0.25))

	# Telegraphs first, so they sit under the body.
	if kind == "knight" and state == "wind":
		var k := 1.0 - state_t / 0.45
		draw_line(Vector2.ZERO, lunge_dir * 140.0, Color(1.0, 0.35, 0.3, 0.25), radius * 2.0)
		draw_line(Vector2.ZERO, lunge_dir * 140.0 * k, Color(1.0, 0.35, 0.3, 0.6), radius * 2.0)
	if kind == "archer" and aim_dir != Vector2.ZERO:
		draw_line(Vector2.ZERO, aim_dir * 420.0, Color(1.0, 0.35, 0.3, 0.5), 2.0)
	if kind == "slime" and state == "rest" and state_t < 0.25:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 20, Color(1.0, 0.35, 0.3, 0.6), 2.0)

	var body := color
	if flash > 0.0:
		body = Color.WHITE
	# Squashed along the direction it was hit from.
	draw_set_transform(Vector2(0, lift_y), squash_dir.angle(), Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.25))
	draw_circle(Vector2.ZERO, radius, body)
	if charged > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 16, Color(0.95, 0.89, 0.42, 0.8), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if stun > 0.0:
		var t := Time.get_ticks_msec() * 0.004
		for i in 3:
			draw_circle(Vector2(0, lift_y - radius - 6.0) + Vector2.from_angle(t + i * TAU / 3.0) * 7.0, 2.0, Color(1.0, 0.89, 0.63))
	if hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(Vector2(-w / 2.0, lift_y - radius - 8.0), Vector2(w, 3.0)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2(-w / 2.0, lift_y - radius - 8.0), Vector2(w * hp / max_hp, 3.0)), Color(0.85, 0.3, 0.25))
