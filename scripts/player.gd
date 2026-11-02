extends CharacterBody2D
## The climber. Without bonds it is clumsy, slow and weak.
## Bonds fill through what their body part does, and enhance the body.

const BondScript := preload("res://scripts/bond.gd")

const MAX_HP := 100.0
const MAX_STA := 100.0
const WALK := 120.0
const SPRINT := 185.0
const STRIKE_RANGE := 46.0
const STRIKE_HALF_ARC := 55.0
const STRIKE_DAMAGE := 8.0

var main  # the room (main.gd), set before the player is added
var radius := 14.0
var max_hp := MAX_HP
var max_sta := MAX_STA
var hp := MAX_HP
var sta := MAX_STA
var sta_delay := 0.0
var aim := Vector2.RIGHT
var bonds := {}  # body part -> bond
var dead := false

var roll_t := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var roll_speed := 0.0
var iframes := 0.0
var attack_cd := 0.0
var swing_t := 0.0
var parry_t := 0.0
var parry_cd := 0.0
var cast_t := 0.0
var cast_total := 0.0
var cast_part := ""
var hurt_t := 0.0
var dodge_cd := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	bonds["hand"] = BondScript.new("stormcaller", "hand")
	bonds["legs"] = BondScript.new("windwalker", "legs")


func has_bond(bond_id: String) -> bool:
	for b in bonds.values():
		if b.id == bond_id:
			return true
	return false


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	_tick_timers(delta)
	var mouse := get_global_mouse_position()
	if mouse.distance_to(global_position) > 4.0:
		aim = (mouse - global_position).normalized()

	if cast_t > 0.0:
		# A wind-up can't be cancelled: no moving, no rolling.
		cast_t -= delta
		velocity = Vector2.ZERO
		if cast_t <= 0.0:
			_release_cast()
	elif roll_t > 0.0:
		roll_t -= delta
		velocity = roll_dir * roll_speed
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := WALK
		if Input.is_action_pressed("sprint") and input != Vector2.ZERO and sta > 0.0:
			spd = SPRINT
			sta -= 22.0 * delta
			sta_delay = 0.6
		velocity = input * spd
		if Input.is_action_just_pressed("roll"):
			_try_roll(input)
		elif Input.is_action_just_pressed("attack"):
			_try_attack()
		elif Input.is_action_just_pressed("parry"):
			_try_parry()
		elif Input.is_action_just_pressed("cast_hand"):
			_try_cast("hand")
		elif Input.is_action_just_pressed("cast_legs"):
			_try_cast("legs")
	move_and_slide()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	roll_cd -= delta
	iframes -= delta
	attack_cd -= delta
	swing_t -= delta
	parry_t -= delta
	parry_cd -= delta
	hurt_t -= delta
	dodge_cd -= delta
	sta_delay -= delta
	if sta_delay <= 0.0:
		sta = minf(MAX_STA, sta + 35.0 * delta)


func _try_roll(input: Vector2) -> void:
	if roll_cd > 0.0:
		return
	# Windwalker's Body: the roll becomes a long wind dash.
	var wind := has_bond("windwalker")
	var cost := 20.0 if wind else 30.0
	var dist_mult := 1.0
	var legs = bonds.get("legs")
	if legs != null and legs.burned:
		cost *= 1.5
		dist_mult = 0.7
	if sta < cost:
		main.fx_text(global_position + Vector2(0, -28), "too winded", Color(0.6, 0.6, 0.65))
		return
	sta -= cost
	sta_delay = 0.7
	roll_dir = input.normalized() if input != Vector2.ZERO else aim
	var duration := 0.26 if wind else 0.22
	roll_speed = (500.0 if wind else 320.0) * dist_mult
	roll_t = duration
	iframes = duration * 0.85
	roll_cd = duration + 0.25


func _try_attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.5  # slow, clumsy swings
	swing_t = 0.15
	var dmg := STRIKE_DAMAGE
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var hits := 0
	for e in main.enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() > STRIKE_RANGE + e.radius:
			continue
		if absf(aim.angle_to(to)) > deg_to_rad(STRIKE_HALF_ARC):
			continue
		_strike(e, dmg, to.normalized())
		hits += 1
	# The hand fills when your weapon strikes land.
	if hits > 0 and hand != null:
		hand.fill(6.0 * hits)


func _strike(e, dmg: float, dir: Vector2) -> void:
	# Windwalker passive, Featherweight: airborne foes take extra damage.
	if has_bond("windwalker") and e.airborne > 0.0:
		dmg *= 1.5
	# Stormcaller passive, Static: striking a charged foe arcs to another.
	if has_bond("stormcaller") and e.charged > 0.0:
		for other in main.enemies():
			if other == e:
				continue
			if e.global_position.distance_to(other.global_position) < 150.0:
				main.fx_bolt([e.global_position, other.global_position], Color(0.95, 0.89, 0.42))
				other.take_hit(5.0, Vector2.ZERO)
				break
	e.take_hit(dmg, dir)


func _try_parry() -> void:
	if parry_cd > 0.0:
		return
	parry_t = 0.18
	parry_cd = 0.6


func _try_cast(part: String) -> void:
	var b = bonds.get(part)
	if b == null:
		return
	cast_part = part
	cast_total = b.windup()
	cast_t = cast_total


func _release_cast() -> void:
	var b = bonds[cast_part]
	if b.pay():
		# Overdraw: the spell still fires, but the body part burns.
		main.fx_text(global_position + Vector2(0, -40), "%s burned!" % BondScript.PART_NAMES[cast_part], Color(1.0, 0.4, 0.3))
		main.shake(5.0)
	b.cast(self)


## Called by monsters and projectiles when an attack reaches you.
func receive_attack(dmg: float, source) -> void:
	if dead:
		return
	if iframes > 0.0:
		on_dodge()
		return
	if parry_t > 0.0 and source != null:
		var to_source: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_source) > 0.3:
			parry_t = 0.0
			main.fx_text(global_position + Vector2(0, -34), "Parried!", Color(1.0, 0.89, 0.63))
			if source.has_method("on_parried"):
				source.on_parried()
			return
	if hurt_t > 0.0:
		return
	hp -= dmg
	hurt_t = 0.4
	main.fx_text(global_position + Vector2(0, -24), "-%d" % int(dmg), Color(1.0, 0.42, 0.34))
	main.shake(7.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true


## The legs fill when you roll through an attack.
func on_dodge() -> void:
	if dodge_cd > 0.0:
		return
	dodge_cd = 0.3
	var legs = bonds.get("legs")
	if legs != null:
		legs.fill(10.0)
	main.fx_text(global_position + Vector2(0, -30), "Dodged", Color(0.75, 0.9, 1.0))


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var body := Color(0.88, 0.83, 0.72)
	if hurt_t > 0.0:
		body = Color(1.0, 0.45, 0.4)
	if iframes > 0.0:
		body.a = 0.45
	if dead:
		body = Color(0.4, 0.38, 0.42)

	draw_circle(Vector2(0, radius * 0.7), radius * 0.95, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, radius, body)
	draw_line(aim * radius * 0.6, aim * (radius + 7.0), Color(0.2, 0.18, 0.22), 3.0)

	if swing_t > 0.0:
		var a := aim.angle()
		var half := deg_to_rad(STRIKE_HALF_ARC)
		draw_arc(Vector2.ZERO, STRIKE_RANGE, a - half, a + half, 16, Color(1, 1, 1, 0.7), 3.0)
	if parry_t > 0.0:
		var pa := aim.angle()
		draw_arc(Vector2.ZERO, radius + 9.0, pa - 1.0, pa + 1.0, 12, Color(1.0, 0.89, 0.63), 4.0)
	if cast_t > 0.0:
		var b = bonds[cast_part]
		var k := 1.0 - cast_t / maxf(cast_total, 0.001)
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU * k, 32, b.color(), 3.0)

	# Marks and motes: power is shown on the body, not only on the HUD.
	for b in bonds.values():
		var anchor := Vector2(0, radius * 0.75)
		if b.part == "hand":
			anchor = aim.rotated(PI / 2.0) * radius * 0.8
		var col: Color = b.color()
		if b.burned:
			col = Color(1.0, 0.35, 0.25) if fmod(t, 0.4) < 0.2 else col
		draw_circle(anchor, 3.0, col)
		for i in b.step:
			var spread: float = float(i) - (float(b.step) - 1.0) / 2.0
			var ang: float = anchor.angle() + PI + spread * 0.5
			draw_line(anchor, anchor + Vector2.from_angle(ang) * 7.0, col, 1.5)
		var motes := int(b.essence / 8.0)
		for i in mini(motes, 6):
			var ma := t * 2.0 + float(i) * TAU / 6.0
			draw_circle(anchor + Vector2.from_angle(ma) * 11.0, 1.6, col)
