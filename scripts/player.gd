extends CharacterBody2D
## The climber. Without bonds it is clumsy, slow and weak.
## Bonds fill through what their body part does, and enhance the body.

const BondScript := preload("res://scripts/bond.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

const MAX_HP := 140.0  # tougher than the first, very clumsy climber
const MAX_STA := 100.0
const WALK := 135.0
const SPRINT := 200.0
const STRIKE_DAMAGE := 8.0
const BUFFER_TIME := 0.2  # presses this early still count when you recover
const COMBO_WINDOW := 0.35  # time after recovering to continue the chain
## Parry: active this long after pressing; a hit that lands within
## PARRY_PERFECT of the press is a perfect parry. Monsters glint 0.25 s
## before their blow, so pressing on the glint always parries, and pressing
## a beat after it is perfect.
const PARRY_WINDOW := 0.32
const PARRY_PERFECT := 0.14

var main  # the room (main.gd), set before the player is added
var radius := 14.0
var weight := 1.0  # how hard it is to shove when bodies collide
var max_hp := MAX_HP
var max_sta := MAX_STA
var hp := MAX_HP
var sta := MAX_STA
var sta_delay := 0.0
var aim := Vector2.RIGHT
var bonds := {}  # body part -> bond
var dead := false
var mouse_aim := true  # tests turn this off to aim by hand
var touch_aim := false  # on phones: face the nearest foe, or where you move

var weapon := "sword"
var pending_weapon := ""
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
var drawing := false
var draw_t := 0.0
var draw_release := false
var draw_ready := false
var parry_t := 0.0
var parry_cd := 0.0
var parry_flash := 0.0
var parry_window := PARRY_WINDOW
var ward_t := 0.0  # Warden's ward: blows that land on it are turned aside
var ward_blocks := 0
var ward_perfect := false
var ward_color := Color.WHITE
var cast_t := 0.0
var cast_total := 0.0
var cast_part := ""
var hurt_t := 0.0
var dodge_cd := 0.0
var knock := Vector2.ZERO
var squash := 0.0
var buffered := ""
var buffer_t := 0.0
var step_t := 0.0
var overlay: Node2D  # unlit layer for swing trails and rings


func _ready() -> void:
	collision_layer = 2
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
	# Bonds are given by the room from your saved marks (none on a first climb).
	swing = wdata()["combo"][0]


func wdata() -> Dictionary:
	return Weapons.WEAPONS[weapon]


## A body part did its thing: it soaks up essence toward a mark, and fills
## the bond on it (if it has one) for casting.
func _part_action(part: String, soak: float, fill: float) -> void:
	main.add_soak(part, soak)
	var b = bonds.get(part)
	if b != null:
		b.fill(fill)


func _burned(part: String) -> bool:
	var b = bonds.get(part)
	return b != null and b.burned


## A burned heart caps your health lower until the next stair.
func max_health() -> float:
	return max_hp * (0.75 if _burned("heart") else 1.0)


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
	if parry_t > 0.0:
		pass  # a parry keeps facing the threat it turned toward
	elif touch_aim:
		if attack_cd <= 0.0:
			_auto_aim()
	elif mouse_aim and mouse.distance_to(global_position) > 4.0 and attack_cd <= 0.0:
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
		if pending_weapon != "" and attack_cd <= 0.0 and not drawing:
			_equip(pending_weapon)
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := WALK
		if drawing:
			spd *= wdata()["move_mult"]
			_tick_draw(delta)
		elif attack_cd > 0.0:
			spd *= 0.35  # committed to the swing
		elif Input.is_action_pressed("sprint") and input != Vector2.ZERO and sta > 0.0:
			spd = SPRINT
			sta -= 22.0 * delta
			sta_delay = 0.6
		velocity = input * spd
		_footsteps(delta, spd if input != Vector2.ZERO else 0.0)
		if buffered != "" and _try_action(buffered, input):
			buffered = ""
	velocity += knock
	move_and_slide()
	queue_redraw()


## Touch aiming: lock onto the nearest monster in reach (the bow reaches
## further), otherwise face the way you're moving.
func _auto_aim() -> void:
	var reach := 380.0 if weapon == "bow" else 150.0
	var best = null
	var best_d := reach
	for e in main.enemies():
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	var target := aim
	if best != null:
		target = (best.global_position - global_position).normalized()
	else:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move.length() > 0.2:
			target = move.normalized()
	aim = aim.slerp(target, 0.35).normalized()


func _footsteps(delta: float, speed: float) -> void:
	if speed <= 1.0:
		step_t = 0.0
		return
	step_t -= delta
	if step_t <= 0.0:
		step_t = 36.0 / speed  # one step every ~36 px travelled
		main.sfx("step", 1.0, -2.0 if speed > WALK else -5.0, 0.08)


func _read_buffer() -> void:
	for i in Weapons.ORDER.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			pending_weapon = Weapons.ORDER[i]
	if Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("weapon_prev"):
		var step := 1 if Input.is_action_just_pressed("weapon_next") else -1
		var from := pending_weapon if pending_weapon != "" else weapon
		var idx := (Weapons.ORDER.find(from) + step + Weapons.ORDER.size()) % Weapons.ORDER.size()
		pending_weapon = Weapons.ORDER[idx]

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
	elif Input.is_action_just_pressed("cast_heart"):
		pressed = "cast_heart"
	elif Input.is_action_just_pressed("cast_brow"):
		pressed = "cast_brow"
	if pressed != "":
		buffered = pressed
		buffer_t = BUFFER_TIME
	elif buffer_t <= 0.0:
		buffered = ""


func _equip(id: String) -> void:
	pending_weapon = ""
	if id == weapon:
		return
	weapon = id
	combo = 0
	combo_t = 0.0
	if wdata()["kind"] == "melee":
		swing = wdata()["combo"][0]
	main.fx_text(global_position + Vector2(0, -30), wdata()["name"], Color(0.85, 0.82, 0.9))
	main.sfx("equip_" + weapon)


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
		"cast_heart":
			return _try_cast("heart")
		"cast_brow":
			return _try_cast("brow")
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
	ward_t -= delta
	hurt_t -= delta
	dodge_cd -= delta
	buffer_t -= delta
	sta_delay -= delta
	squash = move_toward(squash, 0.0, 5.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	hp = minf(hp, max_health())
	if sta_delay <= 0.0 and not drawing:
		sta = minf(MAX_STA, sta + 45.0 * delta)


func _winded() -> void:
	main.fx_text(global_position + Vector2(0, -28), "too winded", Color(0.6, 0.6, 0.65))
	main.sfx("winded")


func _try_roll(input: Vector2) -> bool:
	if roll_cd > 0.0 or attack_cd > 0.15:
		return false
	# Windwalker's Body: the roll becomes a long wind dash.
	var wind := has_bond("windwalker")
	var cost := 16.0 if wind else 24.0
	var dist_mult := 1.0
	if _burned("legs"):
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
	drawing = false  # rolling drops a drawn arrow
	main.sfx("roll")
	if wind:
		main.sfx("gust", 1.3, -6.0)
	return true


func _try_attack() -> bool:
	if attack_cd > 0.0 or drawing:
		return false
	if sta <= 0.0:
		_winded()
		return true
	if wdata()["kind"] == "bow":
		drawing = true
		draw_t = 0.0
		draw_release = false
		draw_ready = false
		main.sfx("draw", 1.0, 0.0, 0.03)
		return true
	return _melee()


func _melee() -> bool:
	var w := wdata()
	var chain: Array = w["combo"]
	if combo_t <= 0.0 or combo >= chain.size():
		combo = 0
	swing = chain[combo]
	var heavy: bool = swing["heavy"]
	combo = (combo + 1) % chain.size()
	sta = maxf(0.0, sta - swing["sta"])
	sta_delay = 0.6
	attack_cd = swing["recover"]
	combo_t = attack_cd + COMBO_WINDOW
	swing_t = w["swing_time"]
	lunge_t = 0.08
	lunge_speed = swing["lunge"]
	var snd: String = w["sound"]
	main.sfx(snd + "_heavy" if heavy else snd, 1.0 + 0.06 * combo)

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
		_strike(e, dmg, to.normalized(), swing["knock"], heavy, w["hit_sound"])
		hits += 1
	# The hand fills when your weapon strikes land.
	if hits > 0:
		_part_action("hand", 0.5 * hits, 6.0 * hits)
	return true


func _tick_draw(delta: float) -> void:
	var w := wdata()
	draw_t += delta
	if draw_t >= w["draw_time"] and not draw_ready:
		draw_ready = true
		main.sfx("ready", 1.0, 0.0, 0.0)
		main.fx_ring(global_position + aim * (radius + 8.0), Color(1.0, 0.9, 0.6), 18.0, 0.2, 2.0)
	if (mouse_aim or touch_aim) and not Input.is_action_pressed("attack"):
		draw_release = true
	# A quick tap still looses a weak shot once the arrow is nocked.
	if draw_release and draw_t >= w["min_draw"]:
		release_draw()


## Looses the drawn arrow. Power grows with how long you held the draw.
func release_draw() -> void:
	if not drawing:
		return
	var w := wdata()
	var k: float = clampf(draw_t / w["draw_time"], 0.0, 1.0)
	var full := k >= 1.0
	drawing = false
	attack_cd = w["recover"]
	sta = maxf(0.0, sta - w["sta"])
	sta_delay = 0.6
	var dmg: float = lerpf(w["dmg_min"], w["dmg_max"], k * k)
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var speed: float = lerpf(w["speed_min"], w["speed_max"], k)
	var force: float = lerpf(w["knock_min"], w["knock_max"], k)
	main.spawn_player_arrow(global_position + aim * (radius + 6.0), aim * speed, dmg, force, full)
	main.sfx("bow", 0.9 + 0.2 * k, -6.0 + 6.0 * k)
	knock = -aim * (60.0 if full else 20.0)
	if full:
		main.shake(3.0)


## Called by your arrows when they hit a monster.
func ranged_hit(e, dmg: float, dir: Vector2, force: float, heavy: bool) -> void:
	_strike(e, dmg, dir, force, heavy, "arrow_hit")
	_part_action("hand", 0.5, 6.0)


func _strike(e, dmg: float, dir: Vector2, force: float, heavy: bool, hit_sound := "hit") -> void:
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
				main.sfx("zap", 1.25, -6.0)
				other.take_hit(5.0, Vector2.ZERO)
				break
	var contact: Vector2 = e.global_position - dir * e.radius
	if crit:
		main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), "Riposte!", Color(1.0, 0.85, 0.4))
		main.fx_ring(contact, Color(1.0, 0.85, 0.4), 40.0, 0.3, 4.0)
		main.fx_burst(contact, dir, Color(1.0, 0.9, 0.6), 14, 380.0)
		main.sfx("crit")
		main.light_flash(contact, Color(1.0, 0.85, 0.5), 1.0, 1.5, 0.2)
		main.hitstop(0.14)
		main.shake(9.0)
	else:
		main.fx_burst(contact, dir, Color(1.0, 0.95, 0.85), 8 if heavy else 5)
		main.sfx("hit_heavy" if heavy else hit_sound)
	# The monster's body adds its own note: armour clanks, slime squelches.
	var material: String = e.MATERIAL.get(e.kind, "")
	if material != "":
		main.sfx(material, 1.0, -2.0 if heavy or crit else -4.0)
		main.hitstop(0.085 if heavy else 0.05)
		main.shake(5.0 if heavy else 2.5)
	e.take_hit(dmg, dir, force, heavy or crit)


func _try_parry() -> bool:
	if parry_cd > 0.0:
		return false
	# The tail of a swing can be cancelled into a parry, but not its start.
	if attack_cd > 0.0 and swing.get("recover", 0.0) - attack_cd < 0.12:
		return false
	attack_cd = 0.0
	lunge_t = 0.0
	drawing = false
	parry_window = PARRY_WINDOW * (0.6 if _burned("brow") else 1.0)
	parry_t = parry_window
	parry_cd = 0.45
	var threat := _nearest_threat()
	if threat != Vector2.ZERO:
		aim = threat
	return true


## The direction of the most pressing danger: a monster mid-attack or an
## incoming arrow (whichever is closest), else the nearest monster.
func _nearest_threat() -> Vector2:
	var best := Vector2.ZERO
	var best_d := 230.0
	for e in main.enemies():
		if e.is_attacking():
			var d: float = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e.global_position
	for c in main.get_children():
		if "friendly" in c and not c.friendly:
			var d2: float = global_position.distance_to(c.global_position)
			if d2 < minf(best_d, 170.0):
				best_d = d2
				best = c.global_position
	if best == Vector2.ZERO:
		best_d = 130.0
		for e in main.enemies():
			var d3: float = global_position.distance_to(e.global_position)
			if d3 < best_d:
				best_d = d3
				best = e.global_position
	if best == Vector2.ZERO:
		return Vector2.ZERO
	return (best - global_position).normalized()


func _try_cast(part: String) -> bool:
	var b = bonds.get(part)
	if b == null:
		return true
	if attack_cd > 0.0 or drawing:
		return false
	cast_part = part
	cast_total = b.windup()
	cast_t = cast_total
	main.sfx("charge", 1.0, 0.0, 0.03)
	return true


func _release_cast() -> void:
	var b = bonds[cast_part]
	var paid: String = b.pay()
	var part_name: String = BondScript.PART_NAMES[cast_part]
	if paid == "burned":
		# Overdraw: a weaker, desperate cast, and the body part burns.
		main.fx_text(global_position + Vector2(0, -40), "%s burned!" % part_name, Color(1.0, 0.4, 0.3))
		main.fx_burst(global_position, Vector2.ZERO, Color(1.0, 0.4, 0.25), 12, 200.0)
		main.sfx("burn")
		main.light_flash(global_position, Color(1.0, 0.4, 0.2), 1.2, 1.6, 0.4)
		main.shake(5.0)
	elif paid == "torn":
		# Overdrawing a burned mark tears it: the missing essence comes out of you.
		var cost_hp: float = maxf(4.0, b.missing * b.TEAR_HEALTH)
		main.fx_text(global_position + Vector2(0, -40), "%s mark tears! -%d" % [part_name, int(cost_hp)], Color(1.0, 0.25, 0.2))
		main.fx_burst(global_position, Vector2.ZERO, Color(0.9, 0.15, 0.12), 18, 260.0)
		main.sfx("burn", 0.8)
		main.sfx("hurt", 0.9, -4.0)
		main.light_flash(global_position, Color(1.0, 0.2, 0.15), 1.3, 1.8, 0.4)
		main.shake(7.0)
		main.hurt_flash = 0.35
		hp -= cost_hp
		if hp <= 0.0:
			hp = 0.0
			dead = true
			main.sfx("death", 1.0, 0.0, 0.0)
			main.on_player_died()
			return
	b.cast(self)
	b.overdraw_mult = 1.0


## Called by monsters and projectiles when an attack reaches you.
func receive_attack(dmg: float, source) -> void:
	if dead:
		return
	if iframes > 0.0:
		on_dodge()
		return
	if ward_t > 0.0 and ward_blocks > 0 and source != null:
		ward_blocks -= 1
		if ward_blocks <= 0:
			ward_t = 0.0
		main.fx_text(global_position + Vector2(0, -46), "Turned", ward_color)
		_on_parry(source, ward_perfect)
		return
	if parry_t > 0.0 and source != null:
		var to_source: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_source) > -0.1:  # anything in front of you, roughly
			_on_parry(source, parry_window - parry_t <= PARRY_PERFECT)
			return
	if hurt_t > 0.0:
		return
	hp -= dmg
	hurt_t = 0.7  # longer grace after a hit, so a crowd can't chain-hit you
	squash = 1.0
	if source != null:
		knock = (global_position - source.global_position).normalized() * 240.0
	# Getting hit interrupts swings, draws and cast wind-ups.
	cast_t = 0.0
	lunge_t = 0.0
	drawing = false
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
		main.on_player_died()
	else:
		# The heart fills when you take a hit and survive.
		_part_action("heart", 4.0, 8.0)


## Warden's Turning Ward.
func raise_ward(duration: float, blocks: int, perfect: bool, col: Color) -> void:
	ward_t = duration
	ward_blocks = blocks
	ward_perfect = perfect
	ward_color = col


func _on_parry(source, perfect := false) -> void:
	parry_t = 0.0
	parry_cd = 0.0  # a clean parry lets you act again at once
	parry_flash = 0.35 if perfect else 0.25
	sta = minf(MAX_STA, sta + (30.0 if perfect else 12.0))
	var at: Vector2 = global_position + aim * (radius + 8.0)
	var gold := Color(1.0, 0.92, 0.7)
	if perfect:
		main.fx_text(global_position + Vector2(0, -38), "PERFECT PARRY", Color(1.0, 0.85, 0.35))
		main.fx_ring(at, gold, 95.0, 0.45, 6.0)
		main.fx_ring(at, Color(1, 1, 1), 50.0, 0.3, 3.0)
		main.fx_burst(at, aim, gold, 22, 420.0)
		main.sfx("parry", 1.1)
		main.sfx("crit", 1.3, -6.0)
		main.light_flash(at, gold, 1.8, 2.4, 0.4)
		main.hitstop(0.24)
		main.shake(8.0)
	else:
		main.fx_text(global_position + Vector2(0, -34), "Parried", gold)
		main.fx_ring(at, gold, 70.0, 0.35, 5.0)
		main.fx_burst(at, aim, gold, 14, 340.0)
		main.sfx("parry")
		main.light_flash(at, gold, 1.3, 2.0, 0.3)
		main.hitstop(0.14)
		main.shake(6.0)
	# The brow fills when you parry.
	_part_action("brow", 9.0 if perfect else 6.0, 18.0 if perfect else 12.0)
	if source.has_method("on_parried"):
		source.on_parried(perfect)


## The legs fill when you roll through an attack.
func on_dodge() -> void:
	if dodge_cd > 0.0:
		return
	dodge_cd = 0.3
	_part_action("legs", 4.0, 10.0)
	main.fx_text(global_position + Vector2(0, -30), "Dodged", Color(0.75, 0.9, 1.0))
	main.fx_ring(global_position, Color(0.75, 0.9, 1.0), 34.0, 0.25, 2.0)
	main.sfx("dodge")
	main.hitstop(0.04)


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var cloak := Palette.CLIMBER_CLOAK
	var skin := Palette.CLIMBER_SKIN
	if hurt_t > 0.25:
		cloak = cloak.lerp(Color(1.0, 0.35, 0.3), 0.6)
	if dead:
		cloak = Color(0.3, 0.29, 0.32)
		skin = Color(0.45, 0.42, 0.42)
	var alpha := 0.5 if iframes > 0.0 else 1.0
	modulate.a = alpha

	Draw.shadow(self, Vector2(0, radius * 0.75), radius)
	var side := aim.orthogonal()
	# Squash along the facing: stretched when rolling, flattened when hit.
	var sq_dir := roll_dir if roll_t > 0.0 else aim
	draw_set_transform(Vector2.ZERO, sq_dir.angle(), Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.2))
	var body := Transform2D(sq_dir.angle(), Vector2.ZERO).affine_inverse()

	# Weapon held on the far side is drawn before the body.
	if weapon == "bow":
		_draw_weapon(body)
	# Cloak, shoulders and hood, all in the facing frame.
	var f := body.basis_xform(aim)  # facing, in the transformed frame
	var sd := body.basis_xform(side)
	Draw.ball(self, -f * 2.0, radius, cloak)
	Draw.ball(self, sd * radius * 0.72 + f * 1.5, 5.0, cloak.darkened(0.12))
	Draw.ball(self, -sd * radius * 0.72 + f * 1.5, 5.0, cloak.darkened(0.12))
	Draw.ball(self, f * 2.5, 7.5, cloak.darkened(0.25))  # hood
	draw_circle(f * 6.0, 3.8, skin)  # face peeking out of the hood
	draw_circle(f * 7.2 + sd * 1.5, 0.9, Palette.OUTLINE)
	draw_circle(f * 7.2 - sd * 1.5, 0.9, Palette.OUTLINE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if weapon != "bow":
		_draw_weapon(Transform2D.IDENTITY)

	# Essence soaking into unmarked body parts: faint glows that grow
	# until one of them takes a mark.
	for part in BondScript.Bonds.PARTS:
		if bonds.has(part):
			continue
		var k: float = main.soak_fraction(part)
		if k <= 0.02:
			continue
		var at := _mark_anchor(part, side)
		var pulse := 0.6 + 0.4 * sin(t * 3.0 + at.x)
		draw_circle(at, 1.5 + 3.0 * k, Color(1.0, 0.95, 0.8, 0.25 * k * pulse + 0.1 * k))

	# Marks and motes: power is shown on the body, not only on the HUD.
	for b in bonds.values():
		var anchor := _mark_anchor(b.part, side)
		var col: Color = b.color()
		if b.faint:
			col.a = 0.45 + 0.25 * sin(t * 4.0)
		if b.burned:
			col = Color(1.0, 0.35, 0.25) if fmod(t, 0.4) < 0.2 else col
		draw_circle(anchor, 3.2, Palette.OUTLINE)
		draw_circle(anchor, 2.4, col)
		for i in b.step:
			var spread: float = float(i) - (float(b.step) - 1.0) / 2.0
			var ang: float = anchor.angle() + PI + spread * 0.5
			draw_line(anchor, anchor + Vector2.from_angle(ang) * 6.0, col, 1.5)
		var motes := int(b.essence / 8.0)
		for i in mini(motes, 6):
			var ma := t * 2.0 + float(i) * TAU / 6.0
			draw_circle(anchor + Vector2.from_angle(ma) * 10.0, 1.5, col)
	if overlay != null:
		overlay.queue_redraw()


## Where each body part's mark sits on the climber.
func _mark_anchor(part: String, side: Vector2) -> Vector2:
	match part:
		"hand":
			return side * radius * 0.95 + aim * 3.0
		"brow":
			return aim * (radius * 0.55)
		"heart":
			return -side * radius * 0.3 - aim * 3.0
	return Vector2(0, radius * 0.55)  # legs


## Swing trails, parry and cast rings: drawn unlit so they read in the dark.
func _draw_overlay() -> void:
	var c := overlay
	if swing_t > 0.0 and weapon == "sword":
		var a := aim.angle()
		var half := deg_to_rad(swing["arc"])
		var reach: float = swing["range"]
		var heavy: bool = swing["heavy"]
		var k: float = 1.0 - swing_t / wdata()["swing_time"]
		var sweep: float = swing["side"]
		var from := a - half * sweep
		var to := lerpf(from, a + half * sweep, minf(1.0, k * 1.6))
		var col := Color(1.0, 0.88, 0.55) if heavy else Color(0.95, 0.97, 1.0)
		# A crescent trail: several arcs fading toward the inside.
		for i in 5:
			var rr := reach - i * 3.0
			c.draw_arc(Vector2.ZERO, rr, minf(from, to), maxf(from, to), 20, Color(col, (0.75 - i * 0.14) * (1.0 - k * 0.5)), 3.5 if heavy else 2.5)
	if swing_t > 0.0 and weapon == "fists":
		var k2: float = 1.0 - swing_t / wdata()["swing_time"]
		if k2 > 0.3:
			var hand: Vector2 = aim * swing["range"]
			c.draw_arc(hand, 7.0 + 6.0 * k2, 0.0, TAU, 14, Color(1, 0.95, 0.85, 0.6 * (1.0 - k2)), 2.0)
	if parry_t > 0.0:
		var pa := aim.angle()
		c.draw_arc(Vector2.ZERO, radius + 10.0, pa - 1.0, pa + 1.0, 14, Color(1.0, 0.89, 0.63), 4.0)
		c.draw_arc(Vector2.ZERO, radius + 14.0, pa - 0.8, pa + 0.8, 14, Color(1.0, 0.89, 0.63, 0.4), 2.0)
	if ward_t > 0.0 and ward_blocks > 0:
		# The ward: a turning ring of six facets, one pip per blow it can still turn.
		var tw := Time.get_ticks_msec() * 0.002
		var fade := clampf(ward_t / 0.5, 0.3, 1.0)
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(tw + TAU * i / 6.0) * (radius + 9.0))
		c.draw_polyline(pts, Color(ward_color, 0.75 * fade), 2.0, true)
		for i in ward_blocks:
			c.draw_circle(Vector2(-6.0 * (ward_blocks - 1) / 2.0 + 6.0 * i, -radius - 14.0), 2.0, Color(ward_color, fade))
	if parry_flash > 0.0:
		c.draw_circle(Vector2.ZERO, radius + 6.0, Color(1.0, 0.95, 0.8, 0.5 * parry_flash / 0.25))
	if cast_t > 0.0:
		var b = bonds[cast_part]
		var k3 := 1.0 - cast_t / maxf(cast_total, 0.001)
		c.draw_arc(Vector2.ZERO, radius + 14.0, -PI / 2.0, -PI / 2.0 + TAU * k3, 32, b.color(), 3.0)
		c.draw_circle(Vector2.ZERO, radius + 14.0 * k3, Color(b.color(), 0.12))
	if drawing:
		var w := wdata()
		var kd: float = clampf(draw_t / w["draw_time"], 0.0, 1.0)
		var grip := aim * (radius + 5.0)
		var col2 := Color(1.0, 0.9, 0.6, 0.8) if kd >= 1.0 else Color(1, 1, 1, 0.15 + 0.3 * kd)
		c.draw_line(grip + aim * 18.0, grip + aim * (60.0 + 160.0 * kd), col2, 1.0 + kd)


func _draw_weapon(xf: Transform2D) -> void:
	var dir := xf.basis_xform(aim)
	var side := dir.orthogonal()
	match weapon:
		"sword":
			var grip := side * (radius * 0.95) + dir * 4.0
			var blade_dir := dir.rotated(0.5)  # resting: angled forward
			if swing_t > 0.0:
				# The blade follows the swing across the arc.
				var k: float = 1.0 - swing_t / wdata()["swing_time"]
				var half := deg_to_rad(swing["arc"])
				var sweep: float = swing["side"]
				blade_dir = dir.rotated(lerpf(-half * sweep, half * sweep, minf(1.0, k * 1.6)))
				grip = blade_dir * 8.0
			elif attack_cd > 0.0:
				var half2 := deg_to_rad(swing["arc"])
				blade_dir = dir.rotated(half2 * swing["side"])
				grip = blade_dir * 8.0
			Draw.sword(self, grip, blade_dir, 26.0 if swing.get("heavy", false) else 24.0, 1.0 if swing_t > 0.0 else 0.0)
		"fists":
			var skin := Palette.CLIMBER_SKIN
			for s in [-1.0, 1.0]:
				var rest: Vector2 = dir * (radius * 0.7) + side * s * radius * 0.75
				var pos: Vector2 = rest
				var r := 3.8
				if swing_t > 0.0 and s == swing["side"]:
					var k: float = 1.0 - swing_t / wdata()["swing_time"]
					var ext: float = sin(PI * minf(1.0, k * 1.2))
					pos = rest.lerp(dir * swing["range"], ext)
					r = 5.2 if swing["heavy"] else 4.4
				Draw.ball(self, pos, r, skin)
		"bow":
			var k := 0.0
			if drawing:
				k = clampf(draw_t / wdata()["draw_time"], 0.0, 1.0)
			var grip := dir * (radius + 5.0)
			var tip_a := grip - dir * 5.0 + side * 14.0
			var tip_b := grip - dir * 5.0 - side * 14.0
			var limb := PackedVector2Array([tip_a, grip + side * 7.0, grip, grip - side * 7.0, tip_b])
			draw_polyline(limb, Palette.OUTLINE, 5.5, true)
			draw_polyline(limb, Palette.WOOD, 3.0, true)
			# The string pulls back as you draw.
			var nock := grip - dir * (5.0 + 12.0 * k)
			draw_polyline(PackedVector2Array([tip_a, nock, tip_b]), Color(0.92, 0.9, 0.82), 1.0, true)
			if drawing:
				Draw.stroke(self, nock, nock + dir * (18.0 + 14.0 * k), Palette.WOOD.lightened(0.2), 1.6)
				draw_circle(nock + dir * (19.0 + 14.0 * k), 2.0, Palette.STEEL)
			Draw.ball(self, grip + side * 0.5, 3.2, Palette.CLIMBER_SKIN)
