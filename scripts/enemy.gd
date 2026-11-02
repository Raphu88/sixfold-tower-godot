extends CharacterBody2D
## Prototype monsters: slime, archer and knight. Every attack is telegraphed,
## so a careful player can always read it.

## The sound a hit makes on this monster's body, layered over the weapon's.
const MATERIAL := {"slime": "hit_slime", "knight": "hit_armor", "archer": ""}

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

const TYPES := {
	"slime": {"hp": 24.0, "speed": 60.0, "radius": 13.0, "color": Color(0.5, 0.88, 0.4), "dmg": 8.0, "weight": 0.7},
	"archer": {"hp": 18.0, "speed": 75.0, "radius": 11.0, "color": Color(0.62, 0.5, 0.3), "dmg": 8.0, "weight": 0.8},
	"knight": {"hp": 48.0, "speed": 60.0, "radius": 15.0, "color": Color(0.66, 0.7, 0.8), "dmg": 14.0, "weight": 3.0},
}

var kind := "slime"
var main
var hp := 1.0
var max_hp := 1.0
var radius := 12.0
var color := Color.WHITE
var speed := 60.0
var dmg := 8.0
var weight := 1.0  # how hard it is to shove when bodies collide
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
var face := Vector2.LEFT  # where it's looking, eased toward the climber
var overlay: Node2D  # unlit layer: telegraphs and the health bar


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
	weight = t["weight"]
	# Monsters take a moment to notice you, and not all at once.
	state_t = randf_range(1.2, 2.4)
	if kind == "knight":
		state = "recover"  # stands still until state_t runs out, then gives chase


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
	overlay = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	overlay.material = unlit
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


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
	if not (kind == "knight" and state in ["wind", "lunge"]):
		face = face.slerp(dir, minf(1.0, 8.0 * delta)).normalized()
	elif kind == "knight":
		face = lunge_dir
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
		velocity = aim_dir * 165.0
		if state_t <= 0.0:
			state = "rest"
			state_t = 1.0
	else:
		velocity = Vector2.ZERO
		if state_t <= 0.0:
			state = "hop"
			aim_dir = dir
			state_t = 0.35
			main.sfx("slime_hop", randf_range(0.9, 1.15))
	if dist < radius + p.radius + 6.0 and contact_cd <= 0.0:
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
		main.sfx("warn_archer")  # the bow creaks as it draws
	if state_t <= 0.0:
		if aim_dir != Vector2.ZERO:
			main.spawn_projectile(global_position + aim_dir * radius, aim_dir * 260.0, dmg)
		aim_dir = Vector2.ZERO
		state_t = randf_range(2.0, 2.8)


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
				main.sfx("warn_knight")  # armour rattles as it winds up
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
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 100)
	var lift_y := -18.0 if airborne > 0.0 else 0.0
	if kind == "slime" and state == "hop":
		lift_y -= sin(PI * clampf(1.0 - state_t / 0.35, 0.0, 1.0)) * 9.0
	Draw.shadow(self, Vector2(0, radius * 0.7), radius * (0.8 if lift_y < -1.0 else 1.0))

	# Squashed along the direction it was hit from.
	draw_set_transform(Vector2(0, lift_y), squash_dir.angle(), Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.25))
	var f := face.rotated(-squash_dir.angle())  # facing, in the squashed frame
	match kind:
		"slime":
			_draw_slime(t, f)
		"archer":
			_draw_archer(f)
		"knight":
			_draw_knight(f)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1, 1, 1, 0.75 * flash / 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if overlay != null:
		overlay.queue_redraw()


func _draw_slime(t: float, f: Vector2) -> void:
	var col := Palette.SLIME
	# Before a hop it gathers itself: squat and wide, quivering.
	var sq := Vector2.ONE
	var wob := 0.05
	if state == "rest" and state_t < 0.25:
		sq = Vector2(1.18, 0.82)
		wob = 0.09
	elif state == "hop":
		sq = Vector2(0.88, 1.12)
	var pts := Draw.blob(Vector2.ZERO, radius, t, wob, sq)
	Draw.poly(self, pts, Color(col.darkened(0.25), 0.95))
	draw_colored_polygon(Draw.blob(Vector2(-1.5, -2.0), radius * 0.8, t, wob, sq), Color(col, 0.9))
	draw_circle(Vector2(-radius * 0.35, -radius * 0.42), radius * 0.22, Color(1, 1, 1, 0.45))
	draw_circle(Vector2(radius * 0.25, radius * 0.3), radius * 0.12, Color(col.lightened(0.3), 0.5))
	# Eyes that follow you.
	var side := f.orthogonal()
	for s in [-1.0, 1.0]:
		var e: Vector2 = f * radius * 0.35 + side * s * radius * 0.32 + Vector2(0, -2)
		draw_circle(e, 2.6, Color(0.97, 0.97, 0.92))
		draw_circle(e + f * 1.1, 1.3, Palette.OUTLINE)


func _draw_archer(f: Vector2) -> void:
	var cloak := Palette.ARCHER
	var side := f.orthogonal()
	# Quiver on the back, then the cloaked body, hood and bow.
	Draw.stroke(self, -f * 6.0 + side * 4.0, -f * 14.0 + side * 8.0, Palette.WOOD.darkened(0.35), 4.0)
	for i in 3:
		draw_line(-f * 13.0 + side * (6.5 + i * 1.5), -f * 17.0 + side * (8.0 + i * 1.5), Color(0.85, 0.82, 0.75), 1.2)
	Draw.ball(self, -f * 1.5, radius, cloak)
	Draw.ball(self, f * 2.0, 6.5, cloak.darkened(0.3))
	draw_circle(f * 5.0, 2.8, Color(0.08, 0.07, 0.07))  # the dark of the hood
	draw_circle(f * 5.6 + side * 1.2, 0.8, Color(1.0, 0.75, 0.4))
	draw_circle(f * 5.6 - side * 1.2, 0.8, Color(1.0, 0.75, 0.4))
	var grip := f * (radius + 3.0) - side * 3.0
	var drawn := aim_dir != Vector2.ZERO
	var pull := 8.0 if drawn else 2.0
	var a := grip - f * 4.0 + side * 11.0
	var b := grip - f * 4.0 - side * 11.0
	var limb := PackedVector2Array([a, grip + side * 5.0, grip, grip - side * 5.0, b])
	draw_polyline(limb, Palette.OUTLINE, 5.0, true)
	draw_polyline(limb, Palette.WOOD, 2.6, true)
	draw_polyline(PackedVector2Array([a, grip - f * pull, b]), Color(0.9, 0.88, 0.8), 1.0, true)
	if drawn:
		Draw.stroke(self, grip - f * pull, grip + f * 8.0, Palette.WOOD.lightened(0.2), 1.4)


func _draw_knight(f: Vector2) -> void:
	var armor := Palette.KNIGHT
	var side := f.orthogonal()
	# Plume trailing behind the helmet.
	Draw.stroke(self, -f * 2.0, -f * 13.0 + side * 2.0, Palette.PLUME, 3.5)
	# Sword: held low, raised high during the wind-up.
	var sword_dir := f.rotated(-1.1)
	var grip := -side * (radius * 0.9) + f * 3.0
	if state == "wind":
		sword_dir = f.rotated(-2.4)
		grip = -side * (radius * 0.6) - f * 4.0
	elif state == "lunge":
		sword_dir = f.rotated(-0.25)
		grip = -side * (radius * 0.5) + f * 8.0
	Draw.sword(self, grip, sword_dir, 22.0)
	# Body: armoured plates.
	Draw.ball(self, Vector2.ZERO, radius, armor)
	draw_arc(Vector2.ZERO, radius * 0.62, f.angle() + 0.9, f.angle() + TAU - 0.9, 16, armor.darkened(0.3), 1.5)
	Draw.ball(self, side * radius * 0.78, 5.5, armor.lightened(0.08))
	Draw.ball(self, -side * radius * 0.78, 5.5, armor.lightened(0.08))
	# Helmet with a visor slit facing you.
	Draw.ball(self, f * 2.0, 7.5, armor.darkened(0.1))
	draw_line(f * 6.0 + side * 3.5, f * 6.0 - side * 3.5, Palette.OUTLINE, 2.0)
	if state == "wind":
		draw_line(f * 6.0 + side * 2.5, f * 6.0 - side * 2.5, Color(1.0, 0.4, 0.3), 1.0)
	# Shield on the off hand.
	var sc := side * (radius * 0.85) + f * 6.0
	var shield := PackedVector2Array()
	for i in 9:
		var a := f.angle() - 1.0 + 2.0 * float(i) / 8.0
		shield.append(sc + Vector2.from_angle(a) * 7.0 - f * 3.0)
	for i in 9:
		var a := f.angle() + 1.0 - 2.0 * float(i) / 8.0
		shield.append(sc + Vector2.from_angle(a) * 3.0 - f * 3.0)
	Draw.poly(self, shield, Color(0.45, 0.3, 0.22))
	draw_circle(sc + f * 1.5, 1.6, Palette.STEEL)


## Telegraphs, status and the health bar: unlit, so they always read.
func _draw_overlay() -> void:
	var c := overlay
	var lift_y := -18.0 if airborne > 0.0 else 0.0
	var danger := Palette.DANGER
	if kind == "knight" and state == "wind":
		var k := 1.0 - state_t / 0.45
		var reach := 140.0
		var w := radius * 2.0
		c.draw_line(Vector2.ZERO, lunge_dir * reach, Color(danger, 0.14), w)
		c.draw_line(Vector2.ZERO, lunge_dir * reach * k, Color(danger, 0.4), w)
		# Chevrons marching along the path.
		var side := lunge_dir.orthogonal()
		for i in 4:
			var d := fmod(float(i) * 35.0 + k * 35.0, reach)
			var at := lunge_dir * d
			c.draw_polyline(PackedVector2Array([at - lunge_dir * 5.0 + side * 6.0, at, at - lunge_dir * 5.0 - side * 6.0]), Color(danger, 0.6), 2.0)
	if kind == "archer" and aim_dir != Vector2.ZERO:
		var k2 := clampf(1.0 - state_t / 0.42, 0.0, 1.0)
		c.draw_line(aim_dir * 14.0, aim_dir * 420.0, Color(danger, 0.25 + 0.4 * k2), 1.0 + k2)
		c.draw_circle(aim_dir * 14.0, 2.0 + k2 * 2.0, Color(danger, 0.8))
	if kind == "slime" and state == "rest" and state_t < 0.25:
		c.draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, Color(danger, 0.6), 2.0)
	if charged > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		for i in 3:
			var a := t * 6.0 + i * TAU / 3.0
			c.draw_line(Vector2(0, lift_y) + Vector2.from_angle(a) * (radius + 2.0), Vector2(0, lift_y) + Vector2.from_angle(a + 0.4) * (radius + 6.0), Color(0.95, 0.89, 0.42, 0.9), 1.5)
	if stun > 0.0:
		var ts := Time.get_ticks_msec() * 0.004
		for i in 3:
			c.draw_circle(Vector2(0, lift_y - radius - 8.0) + Vector2.from_angle(ts + i * TAU / 3.0) * 7.0, 2.0, Color(1.0, 0.89, 0.63))
	if hp < max_hp:
		var w2 := radius * 2.2
		var top := Vector2(-w2 / 2.0, lift_y - radius - 11.0)
		c.draw_rect(Rect2(top - Vector2(1, 1), Vector2(w2 + 2, 5)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(top, Vector2(w2 * hp / max_hp, 3.0)), Color(0.85, 0.25, 0.2))
