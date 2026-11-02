extends CharacterBody2D
## The climber. Without bonds it is clumsy, slow and weak.
## Bonds fill through what their body part does, and enhance the body.

const BondScript := preload("res://scripts/bond.gd")

const MAX_HP := 100.0
const MAX_STA := 100.0
const WALK := 120.0
const SPRINT := 185.0
const STRIKE_DAMAGE := 8.0
const BUFFER_TIME := 0.2  # presses this early still count when you recover

## The three-hit chain. The third swing is a slow, heavy finisher.
const COMBO := [
	{"dmg": 1.0, "range": 46.0, "arc": 55.0, "sta": 12.0, "recover": 0.4, "lunge": 190.0, "knock": 150.0, "sweep": 1.0},
	{"dmg": 1.1, "range": 46.0, "arc": 55.0, "sta": 12.0, "recover": 0.42, "lunge": 190.0, "knock": 160.0, "sweep": -1.0},
	{"dmg": 1.8, "range": 56.0, "arc": 75.0, "sta": 20.0, "recover": 0.66, "lunge": 300.0, "knock": 300.0, "sweep": 1.0},
]
const COMBO_WINDOW := 0.35  # time after recovering to continue the chain

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
var mouse_aim := true  # tests turn this off to aim by hand

var roll_t := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var roll_speed := 0.0
var iframes := 0.0
var ghost_t := 0.0
var attack_cd := 0.0
var combo := 0
var combo_t := 0.0
var swing_t := 0.0
var swing := {}
var lunge_t := 0.0
var lunge_speed := 0.0
var parry_t := 0.0
var parry_cd := 0.0
var parry_flash := 0.0
var cast_t := 0.0
var cast_total := 0.0
var cast_part := ""
var hurt_t := 0.0
var dodge_cd := 0.0
var knock := Vector2.ZERO
var squash := 0.0
var buffered := ""
var buffer_t := 0.0


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
	swing = COMBO[0]


func has_bond(bond_id: String) -> bool:
	for b in bonds.values():
		if b.id == bond_id:
			return true
	return false


func _physics_process(delta: float) -> void:
	if dead:
		velocity = knock
		knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	_tick_timers(delta)
	var mouse := get_global_mouse_position()
	if mouse_aim and mouse.distance_to(global_position) > 4.0 and attack_cd <= 0.0:
		aim = (mouse - global_position).normalized()
	_read_buffer()

	if cast_t > 0.0:
		# A wind-up can't be cancelled: no moving, no rolling.
		cast_t -= delta
		velocity = Vector2.ZERO
		if cast_t <= 0.0:
			_release_cast()
	elif roll_t > 0.0:
		roll_t -= delta
		velocity = roll_dir * roll_speed
		# Afterimages show exactly when you are untouchable.
		if iframes > 0.0:
			ghost_t -= delta
			if ghost_t <= 0.0:
				ghost_t = 0.03
				main.fx_ghost(global_position, radius, Color(0.75, 0.9, 1.0) if has_bond("windwalker") else Color(0.88, 0.83, 0.72))
	elif lunge_t > 0.0:
		lunge_t -= delta
		velocity = aim * lunge_speed
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := WALK
		if attack_cd > 0.0:
			spd *= 0.35  # committed to the swing
		elif Input.is_action_pressed("sprint") and input != Vector2.ZERO and sta > 0.0:
			spd = SPRINT
			sta -= 22.0 * delta
			sta_delay = 0.6
		velocity = input * spd
		if buffered != "" and _try_action(buffered, input):
			buffered = ""
	velocity += knock
	move_and_slide()
	queue_redraw()


func _read_buffer() -> void:
	var pressed := ""
	if Input.is_action_just_pressed("roll"):
		pressed = "roll"
	elif Input.is_action_just_pressed("attack"):
		pressed = "attack"
	elif Input.is_action_just_pressed("parry"):
		pressed = "parry"
	elif Input.is_action_just_pressed("cast_hand"):
		pressed = "cast_hand"
	elif Input.is_action_just_pressed("cast_legs"):
		pressed = "cast_legs"
	if pressed != "":
		buffered = pressed
		buffer_t = BUFFER_TIME
	elif buffer_t <= 0.0:
		buffered = ""


## Returns true once the action is spent (done, or refused for a reason
## that waiting won't fix), false if it should stay buffered.
func _try_action(action: String, input: Vector2) -> bool:
	match action:
		"roll":
			return _try_roll(input)
		"attack":
			return _try_attack()
		"parry":
			return _try_parry()
		"cast_hand":
			return _try_cast("hand")
		"cast_legs":
			return _try_cast("legs")
	return true


func _tick_timers(delta: float) -> void:
	roll_cd -= delta
	iframes -= delta
	attack_cd -= delta
	combo_t -= delta
	swing_t -= delta
	parry_t -= delta
	parry_cd -= delta
	parry_flash -= delta
	hurt_t -= delta
	dodge_cd -= delta
	buffer_t -= delta
	sta_delay -= delta
	squash = move_toward(squash, 0.0, 5.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if sta_delay <= 0.0:
		sta = minf(MAX_STA, sta + 35.0 * delta)


func _winded() -> void:
	main.fx_text(global_position + Vector2(0, -28), "too winded", Color(0.6, 0.6, 0.65))
	main.sfx("winded", 1.0, -6.0)


func _try_roll(input: Vector2) -> bool:
	if roll_cd > 0.0 or attack_cd > 0.15:
		return false
	# Windwalker's Body: the roll becomes a long wind dash.
	var wind := has_bond("windwalker")
	var cost := 20.0 if wind else 30.0
	var dist_mult := 1.0
	var legs = bonds.get("legs")
	if legs != null and legs.burned:
		cost *= 1.5
		dist_mult = 0.7
	if sta < cost:
		_winded()
		return true
	sta -= cost
	sta_delay = 0.7
	roll_dir = input.normalized() if input != Vector2.ZERO else aim
	var duration := 0.26 if wind else 0.22
	roll_speed = (500.0 if wind else 320.0) * dist_mult
	roll_t = duration
	iframes = duration * 0.85
	roll_cd = duration + 0.25
	attack_cd = 0.0
	combo = 0
	ghost_t = 0.0
	squash = 0.6
	main.sfx("gust" if wind else "roll", 1.4 if wind else 1.0, -4.0 if wind else 0.0)
	return true


func _try_attack() -> bool:
	if attack_cd > 0.0:
		return false
	if sta <= 0.0:
		_winded()
		return true
	if combo_t <= 0.0:
		combo = 0
	swing = COMBO[combo]
	var finisher := combo == COMBO.size() - 1
	combo = (combo + 1) % COMBO.size()
	sta = maxf(0.0, sta - swing["sta"])
	sta_delay = 0.8
	attack_cd = swing["recover"]
	combo_t = attack_cd + COMBO_WINDOW
	swing_t = 0.15
	lunge_t = 0.08
	lunge_speed = swing["lunge"]
	main.sfx("swing_heavy" if finisher else "swing", 1.0 + 0.08 * combo)

	var dmg: float = STRIKE_DAMAGE * swing["dmg"]
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var hits := 0
	for e in main.enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() > swing["range"] + e.radius:
			continue
		if absf(aim.angle_to(to)) > deg_to_rad(swing["arc"]):
			continue
		_strike(e, dmg, to.normalized(), swing["knock"], finisher)
		hits += 1
	# The hand fills when your weapon strikes land.
	if hits > 0 and hand != null:
		hand.fill(6.0 * hits)
	return true


func _strike(e, dmg: float, dir: Vector2, force: float, heavy: bool) -> void:
	var crit := false
	# A staggered foe is open: a riposte deals critical damage.
	if e.stun > 0.0:
		dmg *= 2.5
		force *= 1.4
		crit = true
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
				main.sfx("zap", 1.3, -6.0)
				other.take_hit(5.0, Vector2.ZERO)
				break
	var contact: Vector2 = e.global_position - dir * e.radius
	if crit:
		main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), "Riposte!", Color(1.0, 0.85, 0.4))
		main.fx_ring(contact, Color(1.0, 0.85, 0.4), 40.0, 0.3, 4.0)
		main.fx_burst(contact, dir, Color(1.0, 0.9, 0.6), 14, 380.0)
		main.sfx("crit")
		main.hitstop(0.14)
		main.shake(9.0)
	else:
		main.fx_burst(contact, dir, Color(1.0, 0.95, 0.85), 8 if heavy else 5)
		main.sfx("hit_heavy" if heavy else "hit")
		main.hitstop(0.085 if heavy else 0.05)
		main.shake(5.0 if heavy else 2.5)
	e.take_hit(dmg, dir, force)


func _try_parry() -> bool:
	if parry_cd > 0.0 or attack_cd > 0.0:
		return false
	parry_t = 0.18
	parry_cd = 0.6
	return true


func _try_cast(part: String) -> bool:
	var b = bonds.get(part)
	if b == null:
		return true
	if attack_cd > 0.0:
		return false
	cast_part = part
	cast_total = b.windup()
	cast_t = cast_total
	main.sfx("charge", 1.0 / maxf(cast_total / 0.3, 0.5), -4.0, 0.0)
	return true


func _release_cast() -> void:
	var b = bonds[cast_part]
	if b.pay():
		# Overdraw: the spell still fires, but the body part burns.
		main.fx_text(global_position + Vector2(0, -40), "%s burned!" % BondScript.PART_NAMES[cast_part], Color(1.0, 0.4, 0.3))
		main.fx_burst(global_position, Vector2.ZERO, Color(1.0, 0.4, 0.25), 12, 200.0)
		main.sfx("burn")
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
			_on_parry(source)
			return
	if hurt_t > 0.0:
		return
	hp -= dmg
	hurt_t = 0.4
	squash = 1.0
	if source != null:
		knock = (global_position - source.global_position).normalized() * 240.0
	# Getting hit interrupts swings and cast wind-ups.
	cast_t = 0.0
	lunge_t = 0.0
	combo = 0
	main.fx_text(global_position + Vector2(0, -24), "-%d" % int(dmg), Color(1.0, 0.42, 0.34))
	main.fx_burst(global_position, knock.normalized(), Color(1.0, 0.4, 0.34), 8)
	main.sfx("hurt")
	main.hitstop(0.1)
	main.shake(8.0)
	main.hurt_flash = 0.35
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)


func _on_parry(source) -> void:
	parry_t = 0.0
	parry_cd = 0.0  # a clean parry lets you act again at once
	parry_flash = 0.25
	sta = minf(MAX_STA, sta + 15.0)
	var at: Vector2 = global_position + aim * (radius + 8.0)
	main.fx_text(global_position + Vector2(0, -34), "Parried!", Color(1.0, 0.89, 0.63))
	main.fx_ring(at, Color(1.0, 0.92, 0.7), 70.0, 0.35, 5.0)
	main.fx_burst(at, aim, Color(1.0, 0.92, 0.7), 14, 340.0)
	main.sfx("parry")
	main.hitstop(0.16)
	main.shake(6.0)
	if source.has_method("on_parried"):
		source.on_parried()


## The legs fill when you roll through an attack.
func on_dodge() -> void:
	if dodge_cd > 0.0:
		return
	dodge_cd = 0.3
	var legs = bonds.get("legs")
	if legs != null:
		legs.fill(10.0)
	main.fx_text(global_position + Vector2(0, -30), "Dodged", Color(0.75, 0.9, 1.0))
	main.fx_ring(global_position, Color(0.75, 0.9, 1.0), 34.0, 0.25, 2.0)
	main.sfx("dodge")
	main.hitstop(0.04)


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var body := Color(0.88, 0.83, 0.72)
	if hurt_t > 0.25:
		body = Color(1.0, 0.45, 0.4)
	if iframes > 0.0:
		body = body.lerp(Color(0.75, 0.9, 1.0), 0.4)
		body.a = 0.45
	if dead:
		body = Color(0.4, 0.38, 0.42)

	draw_circle(Vector2(0, radius * 0.7), radius * 0.95, Color(0, 0, 0, 0.25))
	# Squash along the facing: stretched when rolling, flattened when hit.
	var sq_dir := roll_dir if roll_t > 0.0 else aim
	draw_set_transform(Vector2.ZERO, sq_dir.angle(), Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.2))
	draw_circle(Vector2.ZERO, radius, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(aim * radius * 0.6, aim * (radius + 7.0), Color(0.2, 0.18, 0.22), 3.0)

	if swing_t > 0.0:
		var a := aim.angle()
		var half := deg_to_rad(swing["arc"])
		var reach: float = swing["range"]
		var heavy: bool = swing == COMBO[COMBO.size() - 1]
		var k := 1.0 - swing_t / 0.15
		# The blade sweeps across the arc, leaving a fading trail.
		var sweep: float = swing["sweep"]
		var from := a - half * sweep
		var to := lerpf(a - half * sweep, a + half * sweep, minf(1.0, k * 1.6))
		var col := Color(1.0, 0.9, 0.6, 0.85) if heavy else Color(1, 1, 1, 0.75)
		draw_arc(Vector2.ZERO, reach, minf(from, to), maxf(from, to), 18, col, 7.0 if heavy else 4.0)
		draw_arc(Vector2.ZERO, reach - 8.0, minf(from, to), maxf(from, to), 18, Color(col, col.a * 0.35), 3.0)
	if parry_t > 0.0:
		var pa := aim.angle()
		draw_arc(Vector2.ZERO, radius + 9.0, pa - 1.0, pa + 1.0, 12, Color(1.0, 0.89, 0.63), 5.0)
	if parry_flash > 0.0:
		var k2 := parry_flash / 0.25
		draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.95, 0.8, 0.5 * k2))
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
