extends CharacterBody2D
## The climber. Without bonds it is clumsy, slow and weak.
## Bonds fill through what their body part does, and enhance the body.

const BondScript := preload("res://scripts/bond.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Items := preload("res://scripts/items.gd")

## Damage multiplier for striking a foe from behind.
const BACKSTAB_MULT := 1.5
const MAX_HP := 140.0  # tougher than the first, very clumsy climber
const MAX_STA := 100.0
const STA_REGEN := 34.0  # per second, once the short wait after acting is over
const WALK := 150.0
const SPRINT := 225.0
## A jump: a short hop that clears chasms and burning floor (not attacks).
const JUMP_TIME := 0.42
const JUMP_COST := 10.0
const JUMP_HEIGHT := 16.0
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
# Essence density (attributes): small passive bonuses, set from the profile.
var attr_speed := 1.0  # Air: Agility
var attr_strength := 1.0  # Blade: Strength
var attr_will := 1.0  # Iron: Will
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
# Warden
var barrier_hp := 0.0  # Barrier: absorbs damage until spent or it expires
var barrier_t := 0.0
var barrier_stored := 0.0  # what it has absorbed (released as a burst from step 3)
var barrier_burst := false
var barrier_color := Color.WHITE
var absorb_t := 0.0  # Absorb: hits are stored in the barrier instead
var unbreak_t := 0.0  # Unbreakable: no damage, no attacking
# Deepcaller
var anchor_target  # Anchor: a tethered foe
var anchor_t := 0.0
var anchor_len := 110.0
var drink_target  # Drink Deep: a channelled drain
var drink_t := 0.0
var drink_age := 0.0
var drink_dmg := 0.0
var drink_tick := 0.0
var cast_t := 0.0
var cast_total := 0.0
var cast_part := ""
var hurt_t := 0.0
var dodge_cd := 0.0
var knock := Vector2.ZERO
var trap_slow := 1.0  # a thorn snare holds you, a sluice's water slows you (traps.gd)
var squash := 0.0
var buffered := ""
var buffer_t := 0.0
var step_t := 0.0
# Hold to pick: holding a mark's key opens a ring of its spells.
const PICK_HOLD := 0.25
var pick_part := ""
var pick_t := 0.0
var pick_open := false
var pick_index := -1
var pick_dir_override := Vector2.ZERO  # touch: finger offset from the button
# Bond effects on the climber
var thunderhead_t := 0.0  # Stormcaller's Thunderhead
var hawk_t := 0.0  # Hunter's Hawk's Eye
var quarry  # Hunter's Quarry: the last foe you struck
var overlay: Node2D  # unlit layer for swing trails and rings
# Items (items.gd): what you carry, and healing that is still working.
var items := Items.START.duplicate()  # item id -> count
var item_sel := ""  # the item G uses
var heal_left := 0.0
var heal_rate := 0.0


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


## True if any of your marks has learned a spell of this type.
func _knows(spell_type: String) -> bool:
	for b in bonds.values():
		for sp in b.spells():
			if sp["type"] == spell_type:
				return true
	return false


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
	_update_pick(delta)

	if jump_t > 0.0:
		_tick_jump(delta)
		if buffered != "" and buffer_t > 0.0 and buffered == "parry":
			if _try_action(buffered, Vector2.ZERO):
				buffered = ""
	elif cast_t > 0.0:
		# A wind-up can't be cancelled: no moving, no rolling.
		cast_t -= delta
		velocity = Vector2.ZERO
		if has_bond("flame_contractor"):  # Casting Stride: walk while winding up
			velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * WALK * 0.75
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
		spd *= attr_speed
		if rune_gear == "swiftness":
			spd *= 1.15
		if _stubborn():
			spd *= 1.2
		if has_bond("covenant"):  # Pack Stride
			for a in main.allies():
				if a.global_position.distance_to(global_position) < 130.0:
					spd *= 1.15
					break
		velocity = input * spd * main.water_slow(global_position, has_bond("tidecaller") or has_bond("sandshaper")) * trap_slow
		_footsteps(delta, spd if input != Vector2.ZERO else 0.0)
		if buffered != "" and _try_action(buffered, input):
			buffered = ""
	velocity += knock
	move_and_slide()
	_check_fall()
	queue_redraw()


## Touch aiming: lock onto the nearest monster in reach (the bow reaches
## further), otherwise face the way you're moving.
func _auto_aim() -> void:
	var reach := 380.0 if weapon == "bow" else 150.0
	var best = null
	var best_d := reach
	for e in main.targets():
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


## Hold to pick: while a mark's key is held past PICK_HOLD, a ring of its
## spells opens (time slows) and the direction you point picks one; letting
## go casts it. A quick tap just casts the selected spell.
func _update_pick(delta: float) -> void:
	if pick_part == "":
		return
	var b = bonds.get(pick_part)
	if b == null:
		pick_part = ""
		return
	if Input.is_action_pressed("cast_" + pick_part):
		pick_t += delta / maxf(Engine.time_scale, 0.01)
		if not pick_open and pick_t >= PICK_HOLD and b.spells().size() > 1:
			pick_open = true
			pick_index = b.selected
			main.set_slowmo(true)
		if pick_open:
			_aim_pick(b)
		return
	# Released: pick (if the ring was open) and cast.
	if pick_open:
		_aim_pick(b)  # read the direction one last time (a quick slide-and-release)
		b.select(pick_index)
		main.set_slowmo(false)
	pick_open = false
	pick_dir_override = Vector2.ZERO
	buffered = "cast_" + pick_part
	buffer_t = BUFFER_TIME
	pick_part = ""


## Points into the open ring: the spell in that direction is highlighted.
func _aim_pick(b) -> void:
	var dir := pick_dir_override
	if dir == Vector2.ZERO and not touch_aim:
		dir = get_global_mouse_position() - global_position
	if dir.length() > 18.0:
		var n: int = b.spells().size()
		var step_a := TAU / float(n)
		pick_index = posmod(int(round((dir.angle() + PI / 2.0) / step_a)), n)


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
	elif Input.is_action_just_pressed("jump"):
		pressed = "jump"
	elif Input.is_action_just_pressed("attack"):
		pressed = "attack"
	elif Input.is_action_just_pressed("parry"):
		pressed = "parry"
	elif Input.is_action_just_pressed("use_item"):
		pressed = "item"
	if Input.is_action_just_pressed("item_next"):
		cycle_item()
	# A mark's key: tap to cast its selected spell, hold to pick another
	# (see _update_pick). The cast is buffered when the key is released.
	for part in BondScript.Bonds.PARTS:
		if Input.is_action_just_pressed("cast_" + part) and bonds.has(part):
			pick_part = part
			pick_t = 0.0
			pick_open = false
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
	if jump_t > 0.0 and action != "parry":
		return false  # wait for the landing
	match action:
		"jump":
			return _try_jump(input)
		"roll":
			return _try_roll(input)
		"attack":
			return _try_attack()
		"parry":
			return _try_parry()
		"item":
			use_item()
			return true
	if action.begins_with("cast_"):
		return _try_cast(action.substr(5))
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
	_tick_bond_effects(delta)
	thunderhead_t -= delta
	hawk_t -= delta
	hurt_t -= delta
	dodge_cd -= delta
	buffer_t -= delta
	sta_delay -= delta
	squash = move_toward(squash, 0.0, 5.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	_tick_healing(delta)
	hp = minf(hp, max_health())
	if sta_delay <= 0.0 and not drawing:
		sta = minf(MAX_STA, sta + STA_REGEN * attr_will * delta * (1.35 if has_bond("deepcaller") else 1.0) * (0.6 if _burned("throat") else 1.0) * (1.3 if _stubborn() else 1.0) * (1.0 + 0.25 * graft("throat")))  # Deep Lungs; a burned throat; Stubborn Heart; a throat graft


func _winded() -> void:
	main.fx_text(global_position + Vector2(0, -28), "too winded", Color(0.6, 0.6, 0.65))
	main.sfx("winded")


func _try_jump(input: Vector2) -> bool:
	if roll_t > 0.0 or attack_cd > 0.15 or cast_t > 0.0:
		return false
	if sta < JUMP_COST:
		_winded()
		return true
	sta -= JUMP_COST
	sta_delay = 0.5
	var spd := SPRINT if Input.is_action_pressed("sprint") else WALK
	jump_vel = input * spd
	jump_t = JUMP_TIME
	jump_total = JUMP_TIME
	glide_left = 0.8 if has_bond("flamewing") else 0.0
	drawing = false
	main.sfx("roll", 1.35, -6.0)
	return true


func _tick_jump(delta: float) -> void:
	# Flamewing's Phoenix Glide: hold jump to hang in the air a while longer.
	if glide_left > 0.0 and Input.is_action_pressed("jump") and jump_t < jump_total * 0.5:
		glide_left -= delta
		if fmod(glide_left, 0.1) < delta:
			main.fx_burst(global_position + Vector2(0, -jump_height()), Vector2.DOWN, Color(1.0, 0.55, 0.25), 2, 60.0)
	else:
		jump_t -= delta
	velocity = jump_vel
	if jump_t <= 0.0:
		jump_t = 0.0
		squash = 0.5
		main.sfx("step", 0.8, -4.0)


## How high off the ground you are, for drawing.
func jump_height() -> float:
	if jump_t <= 0.0 or jump_total <= 0.0:
		return 0.0
	var k := clampf(1.0 - jump_t / jump_total, 0.0, 1.0)
	return sin(PI * k) * JUMP_HEIGHT + (6.0 if glide_left > 0.0 and Input.is_action_pressed("jump") and jump_t < jump_total * 0.5 else 0.0)


## Off the ground: chasms and burning floor can't touch you.
func in_air() -> bool:
	return jump_t > 0.0


## Walking (or being knocked) into a chasm: you fall, lose some health,
## and climb back out where you last stood.
func _check_fall() -> void:
	if dead or in_air():
		return
	if not main.in_chasm(global_position):
		last_safe = global_position
		return
	var back := last_safe
	if back == Vector2.ZERO or main.in_chasm(back):
		back = main.player_start
	global_position = back
	knock = Vector2.ZERO
	roll_t = 0.0
	iframes = maxf(iframes, 0.6)
	var dmg := maxf(6.0, max_hp * 0.08)
	hp -= dmg
	main.fx_text(global_position + Vector2(0, -40), "Fell! -%d" % int(dmg), Color(0.85, 0.7, 0.6))
	main.sfx("hurt", 0.8)
	main.shake(5.0)
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


func _try_roll(input: Vector2) -> bool:
	if roll_cd > 0.0 or attack_cd > 0.15:
		return false
	# Windwalker's Body: the roll becomes a long wind dash.
	var wind := has_bond("windwalker")
	var cost := (16.0 if wind else 24.0) * (1.0 - 0.25 * minf(graft("legs"), 1.6))
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
	roll_speed = (500.0 if wind else 320.0) * dist_mult * (1.0 + 0.15 * graft("legs"))
	roll_t = duration
	iframes = duration * 0.85
	roll_cd = (duration + 0.25) * (0.85 if has_bond("stormcaller") else 1.0)  # Quick Nerves
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
	if unbreak_t > 0.0:
		return true  # Unbreakable: you cannot attack
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
	sta_delay = 0.9  # stamina waits a moment after you attack: mashing runs you dry
	var recover: float = swing["recover"]
	if has_bond("flameblade"):
		recover = minf(recover, chain[0]["recover"])  # Hot Blood: chains never slow down
	attack_cd = recover * (0.85 if has_bond("stormcaller") else 1.0)  # Quick Nerves
	if _stubborn():
		attack_cd *= 0.8
	if desperate_t > 0.0:
		attack_cd *= 1.0 - 0.4 * (1.0 - hp / max_hp)
	combo_t = attack_cd + COMBO_WINDOW
	swing_t = w["swing_time"]
	lunge_t = 0.08
	lunge_speed = swing["lunge"]
	var snd: String = w["sound"]
	main.sfx(snd + "_heavy" if heavy else snd, 1.0 + 0.06 * combo)

	var dmg: float = STRIKE_DAMAGE * swing["dmg"] * attr_strength
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	if rune_gear == "sharpness":
		dmg *= 1.3
	if has_bond("flameblade"):
		dmg *= 1.0 + heat / 200.0  # Heat: up to half again as hard
	if kindle_t > 0.0:
		dmg += kindle_dmg
	if desperate_t > 0.0:
		dmg *= 1.0 + 1.5 * (1.0 - hp / max_hp)  # Desperation
	dmg *= 1.0 + 0.2 * graft("hand")
	var reach: float = swing["range"] * (1.25 if has_bond("blade_forger") else 1.0)  # Long Edge
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - global_position
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > deg_to_rad(swing["arc"]):
			continue
		_strike(e, dmg, to.normalized(), swing["knock"], heavy, w["hit_sound"])
		hits += 1
	# The hand fills when your weapon strikes land; the throat when one
	# swing catches several foes.
	if hits > 0:
		_part_action("hand", 0.5 * hits, 6.0 * hits)
	if hits > 1:
		_part_action("throat", 2.0 * (hits - 1), 8.0 * (hits - 1))
	if hits > 0:
		_strikes_landed(hits)
	return true


## Flameblade: landed strikes heat the weapon; kindling keeps burning.
func _strikes_landed(hits: int) -> void:
	if kindle_t > 0.0:
		main.fx_burst(global_position + aim * 24.0, aim, kindle_color, 5, 200.0)
		if kindle_sustain:
			kindle_t = maxf(kindle_t, 2.5)
	if not has_bond("flameblade"):
		return
	heat_idle = 0.0
	var before := heat
	heat = minf(100.0, heat + 12.0 * hits * (2.0 if kindle_t > 0.0 else 1.0))
	if heat >= 100.0 and before < 100.0:
		main.fx_text(global_position + Vector2(0, -44), "White hot", Color(1.0, 0.85, 0.5))
		main.sfx("burn", 1.4, -6.0)


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
	sta_delay = 0.9
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
	# Hunter's Hawk's Eye: every arrow strikes a weak point.
	if hawk_t > 0.0:
		dmg *= 2.0
		main.fx_text(e.global_position + Vector2(0, -e.radius - 34.0), "weak point", Color(0.85, 0.63, 0.42))
	_strike(e, dmg, dir, force, heavy, "arrow_hit")
	_part_action("hand", 0.5, 6.0)


func _strike(e, dmg: float, dir: Vector2, force: float, heavy: bool, hit_sound := "hit") -> void:
	quarry = e  # Hunter's Quarry remembers it
	var crit := false
	# A staggered foe is open: a riposte deals critical damage.
	if e.stun > 0.0:
		dmg *= 2.5
		force *= 1.4
		crit = true
	# Windwalker passive, Featherweight: airborne foes take extra damage.
	if has_bond("windwalker") and e.airborne > 0.0:
		dmg *= 1.5
	# Ashwalker's Unseen Strike: a foe that hasn't noticed you, or lost you.
	if has_bond("ashwalker") and e.unaware():
		dmg *= 3.0
		main.fx_text(e.global_position + Vector2(0, -e.radius - 52.0), "Unseen", Color(0.85, 0.6, 0.5))
	vanish_t = 0.0  # striking ends Vanish
	rekindle_fought = true
	if ember_t > 0.0:
		ember_t = 0.0
		main.fx_text(global_position + Vector2(0, -44), "Rekindled", Color(1.0, 0.6, 0.3))
		main.light_flash(global_position, Color(1.0, 0.5, 0.25), 1.6, 1.8, 0.4)
		main.sfx("crit", 0.8)
	# Venomist's Neurotoxin: a hit on a poisoned foe paralyzes it.
	if neuro_t > 0.0 and e.venom > 0:
		neuro_t = 0.0
		e.stagger(neuro_paralyze)
		main.fx_text(e.global_position + Vector2(0, -e.radius - 40.0), "Paralyzed", Color(0.55, 0.85, 0.35))
	# Venomist's Venom Glands: weapon strikes add a weak poison.
	if has_bond("venomist"):
		e.add_venom(1)
	# A backstab: striking a foe that faces away (it committed to an attack,
	# or you rolled behind it). The back fills; a burned back loses the bonus.
	var backstab: bool = dir != Vector2.ZERO and e.face.dot(dir) > 0.5
	if backstab:
		if not _burned("back"):
			dmg *= BACKSTAB_MULT + 0.5 * graft("back")
		main.fx_text(e.global_position + Vector2(0, -e.radius - 40.0), "Backstab", Color(0.95, 0.6, 0.45))
		_part_action("back", 3.0, 10.0)
	# Stormcaller passive, Static: striking a charged foe arcs to another.
	if has_bond("stormcaller") and e.charged > 0.0:
		for other in main.targets():
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
	# A finishing blow fills the back too.
	if e.dead:
		_part_action("back", 2.0, 6.0)


func _try_parry() -> bool:
	if parry_cd > 0.0:
		return false
	# The tail of a swing can be cancelled into a parry, but not its start.
	if attack_cd > 0.0 and swing.get("recover", 0.0) - attack_cd < 0.12:
		return false
	attack_cd = 0.0
	lunge_t = 0.0
	drawing = false
	parry_window = PARRY_WINDOW * (0.6 if _burned("brow") else 1.0) * (1.0 + 0.25 * graft("brow"))
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
	for e in main.targets():
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
		for e in main.targets():
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
	cast_total = b.windup() * (0.7 if has_bond("rune_artist") else 1.0)  # Steady Mind
	cast_t = cast_total
	main.sfx("charge", 1.0, 0.0, 0.03)
	return true


func _release_cast() -> void:
	var b = bonds[cast_part]
	var free: bool = main.in_sigil(global_position) or (firebird_t > 0.0 and b.spell()["type"] == "wingburst")
	var paid: String = b.pay(free)
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
		if hp <= 0.0 and _defy_death():
			hp = maxf(hp, 1.0)
		if hp <= 0.0:
			hp = 0.0
			dead = true
			main.sfx("death", 1.0, 0.0, 0.0)
			main.on_player_died()
			return
	# Count the foes the spell hits at once: several fill the throat.
	main.cast_hits = 0
	main.counting_hits = true
	b.cast(self)
	main.counting_hits = false
	b.overdraw_mult = 1.0
	if main.cast_hits > 1:
		_part_action("throat", 2.0 * (main.cast_hits - 1), 8.0 * (main.cast_hits - 1))


var fire_t := 0.0  # time spent standing in fire, ticking toward the next burn

# The Wyvern's bonds.
var heat := 0.0  # Flameblade's Heat: 0..100, built by strikes in a row
var heat_idle := 0.0  # time since the last strike landed
var kindle_t := 0.0  # Kindle Blade: the weapon burns
var kindle_dmg := 0.0
var kindle_sustain := false
var kindle_color := Color(1.0, 0.5, 0.24)
var searing_dmg := 0.0  # Searing Parry: a kindled parry explodes for this much
var bladeward_t := 0.0  # Bladeward: blades orbit you
var bladeward_dmg := 0.0
var bladeward_r := 48.0
var bladeward_tick := 0.0
var bladeward_color := Color(0.65, 0.89, 0.71)
var rune_gear := ""  # Inscribe: "sharpness", "warding" or "swiftness" for this floor
var camp_rune := ""  # Runesmith: a rune inscribed at a camp, for the rest of the climb

# The Manticore's bonds.
var neuro_t := 0.0  # Neurotoxin: the next hit on a poisoned foe paralyzes it
var neuro_paralyze := 2.0
var vanish_t := 0.0  # Vanish: unseen until you strike

# Jumping.
var jump_t := 0.0  # time left in the air
var jump_total := 0.0
var jump_vel := Vector2.ZERO
var glide_left := 0.0  # Flamewing's Phoenix Glide: extra air time while jump is held
var last_safe := Vector2.ZERO  # the last solid ground you stood on

# The Firebird's bonds.
var aura_part := ""  # Heat Aura: the mark it burns from ("" when off)
var aura_time := 0.0
var aura_dmg := 3.0
var aura_r := 62.0
var aura_drain := 2.5
var aura_grows := false
var aura_heat := 0.0  # built up while the aura burns foes; Wingburst releases it
var aura_tick := 0.0
var aura_color := Color(1.0, 0.68, 0.28)
var warmth_t := 0.0
var warmth_heal := 2.5
var firebird_t := 0.0  # Firebird Form
var rekindle_t := 0.0  # Rekindle: burning now, paid back later
var rekindle_total := 5.0
var rekindle_loss := 0.0
var rekindle_lost := 0.0
var rekindle_fought := false
var rekindle_spread := false
var rekindle_tick := 0.0
var desperate_t := 0.0
var pyre_t := 0.0
var pyre_dmg := 30.0
var phoenix_t := 0.0
var ember_t := 0.0  # Last Ember: burning at 1 health; strike to stay standing
var ember_used := false

# The Chimera's bonds.
var call_index := 0  # Covenant: the next creature of the retinue
var chimera_t := 0.0  # Grafter's Chimera Form


var poison_t := 0.0  # poisoned: a little damage every half second
var poison_tick := 0.0


## Grafter's Adaptive Flesh: how strongly a graft on this body part works
## (0 without one; doubled in Chimera Form).
func graft(part: String) -> float:
	if not has_bond("grafter") or not main.grafts.has(part):
		return 0.0
	return 2.0 if chimera_t > 0.0 else 1.0


## Stubborn Heart: below a third of your health you move and recover faster.
func _stubborn() -> bool:
	return has_bond("rekindler") and hp < max_hp / 3.0


## Something would kill you. True if you stay standing instead (the caller
## keeps you at 1 health): the dev tool, Phoenix Heart, Pyre Oath, Last Ember.
func _defy_death() -> bool:
	if main.dev_no_death:
		return true
	if phoenix_t > 0.0:
		main.fx_text(global_position + Vector2(0, -44), "Phoenix Heart", Color(1.0, 0.6, 0.3))
		return true
	if pyre_t > 0.0:
		pyre_t = 0.0
		main.explode(global_position, 100.0, pyre_dmg, Color(1.0, 0.4, 0.2))
		main.fx_text(global_position + Vector2(0, -44), "Pyre Oath", Color(1.0, 0.5, 0.25))
		return true
	if has_bond("rekindler") and not ember_used and ember_t <= 0.0:
		ember_used = true
		ember_t = 3.0
		main.fx_text(global_position + Vector2(0, -44), "Last Ember: strike to stay standing!", Color(1.0, 0.5, 0.25))
		main.sfx("burn", 0.7)
		return true
	return ember_t > 0.0  # still burning on your last ember


func _tick_fire_bonds(delta: float) -> void:
	chimera_t -= delta
	warmth_t -= delta
	firebird_t -= delta
	desperate_t -= delta
	pyre_t -= delta
	phoenix_t -= delta
	# Last Ember: burn out unless you land a hit in time.
	if ember_t > 0.0:
		ember_t -= delta
		hp = 1.0
		if ember_t <= 0.0 and not dead:
			hp = 0.0
			dead = true
			main.sfx("death", 1.0, 0.0, 0.0)
			main.on_player_died()
			return
	# Heat Aura: burns foes near you, drains its mark, builds heat.
	if aura_part != "":
		var b = bonds.get(aura_part)
		if b == null or b.essence <= 0.0:
			aura_part = ""
		else:
			b.essence = maxf(0.0, b.essence - aura_drain * delta)
			aura_time += delta
			aura_tick -= delta
			if warmth_t > 0.0:
				hp = minf(max_health(), hp + warmth_heal * delta)
			if aura_tick <= 0.0:
				aura_tick = 0.5
				var r := aura_r * (2.0 if firebird_t > 0.0 else 1.0)
				var dmg := aura_dmg * (1.0 + minf(aura_time / 10.0, 1.0) if aura_grows else 1.0)
				for e in main.targets():
					if e.global_position.distance_to(global_position) < r + e.radius:
						e.take_hit(dmg, Vector2.ZERO, 0.0)
						aura_heat = minf(60.0, aura_heat + dmg)
	# Rekindle: lose health now, regain twice that later if you kept fighting.
	if rekindle_t > 0.0:
		rekindle_t -= delta
		rekindle_tick -= delta
		if rekindle_tick <= 0.0:
			rekindle_tick = 0.5
			var loss := rekindle_loss * 0.5 / rekindle_total
			if hp - loss > 1.0:
				hp -= loss
				rekindle_lost += loss
			if rekindle_spread:
				for e in main.targets():
					if e.global_position.distance_to(global_position) < 60.0 + e.radius:
						e.take_hit(3.0, Vector2.ZERO, 0.0)
		if rekindle_t <= 0.0:
			if rekindle_fought:
				hp = minf(max_health(), hp + rekindle_lost * 2.0)
				main.fx_text(global_position + Vector2(0, -44), "Rekindled +%d" % int(rekindle_lost * 2.0), Color(1.0, 0.6, 0.3))
				main.sfx("ready", 0.8)
			else:
				main.fx_text(global_position + Vector2(0, -44), "the fire goes out", Color(0.7, 0.6, 0.55))


## An overdrawn quake knocks you down: a short stagger of your own.
func stagger_self(seconds: float) -> void:
	attack_cd = maxf(attack_cd, seconds)
	cast_t = 0.0
	main.fx_text(global_position + Vector2(0, -40), "Knocked down", Color(0.85, 0.7, 0.42))


## A sting that landed: poisoned for a few seconds (a new sting refreshes it).
func poison(seconds: float) -> void:
	if poison_t <= 0.0:
		main.fx_text(global_position + Vector2(0, -40), "Poisoned", Color(0.55, 0.85, 0.35))
	poison_t = maxf(poison_t, seconds)


func _tick_poison(delta: float) -> void:
	if poison_t <= 0.0 or dead:
		return
	poison_t -= delta
	poison_tick -= delta
	if poison_tick > 0.0:
		return
	poison_tick = 0.5
	hp -= 2.0
	main.fx_text(global_position + Vector2(0, -24), "-2", Color(0.55, 0.85, 0.35))
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## Standing on burning floor: a small burn every half second (rolling through is free).
func stand_in_fire(delta: float) -> void:
	if iframes > 0.0 or dead or in_air() or has_bond("flamewing"):  # Fireproof
		return
	fire_t += delta
	if fire_t < 0.5:
		return
	fire_t = 0.0
	hp -= 4.0
	main.fx_text(global_position + Vector2(0, -24), "-4", Color(1.0, 0.55, 0.25))
	main.sfx("burn", 1.3, -10.0)
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## Called by monsters and projectiles when an attack reaches you.
## `unblockable` attacks (a ring of lightning, a diving landing) can't be
## parried or warded: roll through them or get out of the way.
func receive_attack(dmg: float, source, unblockable := false) -> void:
	if dead:
		return
	if iframes > 0.0:
		on_dodge()
		return
	if unblockable:
		source = null  # nothing to parry or turn
	if unbreak_t > 0.0:
		main.fx_text(global_position + Vector2(0, -30), "Unbreakable", barrier_color)
		main.sfx("hit_armor", 1.2, -4.0)
		return
	if absorb_t > 0.0:
		barrier_hp += dmg
		barrier_stored += dmg
		barrier_t = maxf(barrier_t, 2.0)
		main.fx_text(global_position + Vector2(0, -30), "Absorbed %d" % int(dmg), barrier_color)
		main.sfx("parry", 0.6, -6.0)
		return
	if parry_t > 0.0 and source != null:
		var to_source: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_source) > -0.1:  # anything in front of you, roughly
			_on_parry(source, parry_window - parry_t <= PARRY_PERFECT)
			return
	# Warden's Heavy Frame: keep holding parry to block.
	if source != null and has_bond("warden") and parry_t <= 0.0 and Input.is_action_pressed("parry") and attack_cd <= 0.0:
		var to_src: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_src) > 0.0 and sta >= 12.0:
			sta -= 12.0
			sta_delay = 0.8
			dmg *= 0.3
			main.fx_text(global_position + Vector2(0, -30), "Blocked", Color(0.85, 0.71, 0.42))
			main.sfx("hit_armor", 1.0, -2.0)
	if hurt_t > 0.0:
		return
	# The Warden's barrier soaks damage first.
	var steadfast := barrier_hp > 0.0
	if barrier_hp > 0.0:
		var take := minf(barrier_hp, dmg)
		barrier_hp -= take
		barrier_stored += take
		dmg -= take
		main.fx_ring(global_position, barrier_color, radius + 10.0, 0.2, 2.0)
		if barrier_hp <= 0.0:
			_break_barrier()
		if dmg <= 0.0:
			main.sfx("hit_armor", 1.3, -4.0)
			return
	if rune_gear == "warding":
		dmg *= 0.75
	dmg *= 1.0 - 0.15 * graft("heart")
	hp -= dmg
	hurt_t = 0.7  # longer grace after a hit, so a crowd can't chain-hit you
	squash = 1.0
	if source != null and not steadfast:
		knock = Vector2.ZERO if has_bond("sandshaper") else (global_position - source.global_position).normalized() * 240.0  # Rooted Stance
	# Getting hit interrupts swings, draws and cast wind-ups (not while
	# the Warden's barrier holds: Steadfast).
	if not steadfast:
		cast_t = 0.0
		lunge_t = 0.0
		drawing = false
		combo = 0
	drink_target = null
	main.fx_text(global_position + Vector2(0, -24), "-%d" % int(dmg), Color(1.0, 0.42, 0.34))
	main.fx_burst(global_position, knock.normalized(), Color(1.0, 0.4, 0.34), 8)
	main.sfx("hurt")
	main.hitstop(0.1)
	main.shake(8.0)
	main.hurt_flash = 0.35
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()
	else:
		# The heart fills when you take a hit and survive.
		_part_action("heart", 4.0, 8.0)


## Warden's Turning Ward.
## Warden's Barrier.
func raise_barrier(shield: float, duration: float, burst: bool, col: Color) -> void:
	barrier_hp = maxf(barrier_hp, shield)
	barrier_t = maxf(barrier_t, duration)
	barrier_burst = burst or barrier_burst
	barrier_color = col


## The barrier is spent or expires: from step 3 it releases what it absorbed.
func _break_barrier() -> void:
	if barrier_burst and barrier_stored > 0.0:
		var power := maxf(10.0, barrier_stored)
		main.fx_ring(global_position, barrier_color, 110.0, 0.4, 6.0)
		main.fx_burst(global_position, Vector2.ZERO, barrier_color, 22, 320.0)
		main.light_flash(global_position, barrier_color, 1.6, 1.6, 0.4)
		main.sfx("crit", 0.8)
		main.shake(6.0)
		for e in main.targets():
			var to: Vector2 = e.global_position - global_position
			if to.length() < 110.0 + e.radius:
				e.take_hit(power, to.normalized(), 260.0, true)
	elif barrier_stored > 0.0 or barrier_hp <= 0.0:
		main.fx_text(global_position + Vector2(0, -36), "Barrier breaks", barrier_color)
	barrier_hp = 0.0
	barrier_t = 0.0
	barrier_stored = 0.0
	barrier_burst = false


## Bond effects that run on a timer: barrier, absorb, anchor, drink.
func _tick_bond_effects(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire_bonds(delta)
	neuro_t -= delta
	vanish_t -= delta
	absorb_t -= delta
	unbreak_t -= delta
	kindle_t -= delta
	# Heat fades once you stop landing strikes.
	heat_idle += delta
	if heat_idle > 1.5:
		heat = move_toward(heat, 0.0, 40.0 * delta)
	# Bladeward: orbiting blades cut whatever comes close.
	if bladeward_t > 0.0:
		bladeward_t -= delta
		bladeward_tick -= delta
		if bladeward_tick <= 0.0:
			bladeward_tick = 0.35
			for e in main.targets():
				var to: Vector2 = e.global_position - global_position
				if to.length() < bladeward_r + e.radius:
					e.take_hit(bladeward_dmg, to.normalized(), 90.0)
					main.fx_burst(e.global_position - to.normalized() * e.radius, to.normalized(), bladeward_color, 4, 180.0)
					main.sfx("hit", 1.4, -8.0)
	if barrier_t > 0.0:
		barrier_t -= delta
		if barrier_t <= 0.0:
			_break_barrier()
	# Anchor: a tethered foe can't get farther than the tether's length.
	if anchor_t > 0.0:
		anchor_t -= delta
		if anchor_target == null or not is_instance_valid(anchor_target) or anchor_target.dead:
			anchor_t = 0.0
		else:
			var to: Vector2 = anchor_target.global_position - global_position
			if to.length() > anchor_len:
				anchor_target.knock = -to.normalized() * minf((to.length() - anchor_len) * 8.0, 400.0)
	# Drink Deep: a drain that grows stronger every second it holds.
	if drink_t > 0.0:
		drink_t -= delta
		drink_age += delta
		drink_tick -= delta
		if drink_target == null or not is_instance_valid(drink_target) or drink_target.dead or drink_target.global_position.distance_to(global_position) > 300.0:
			drink_t = 0.0
		elif drink_tick <= 0.0:
			drink_tick = 0.25
			var d := drink_dmg * (1.0 + drink_age)
			drink_target.take_hit(d, Vector2.ZERO)
			hp = minf(max_health(), hp + d * 0.5)


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
	# Searing Parry: a parry while your weapon is kindled explodes.
	if kindle_t > 0.0 and searing_dmg > 0.0 and _knows("searing"):
		main.fx_ring(at, kindle_color, 70.0, 0.35, 5.0)
		main.fx_burst(at, aim, kindle_color, 18, 320.0)
		main.light_flash(at, kindle_color, 1.6, 1.8, 0.3)
		main.sfx("burn", 0.8)
		for e in main.targets():
			if e.global_position.distance_to(at) < 70.0 + e.radius:
				e.take_hit(searing_dmg, (e.global_position - global_position).normalized(), 200.0, true)
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

	Draw.shadow(self, Vector2(0, radius * 0.75), radius * (1.0 - jump_height() / 40.0))
	var lift := jump_height()
	var side := aim.orthogonal()
	# Squash along the facing: stretched when rolling, flattened when hit.
	var sq_dir := roll_dir if roll_t > 0.0 else aim
	draw_set_transform(Vector2(0, -lift), sq_dir.angle(), Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.2))
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
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
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
		"throat":
			return aim * (radius * 0.25) + side * 2.0
		"back":
			return -aim * (radius * 0.7) + side * 2.0
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
	modulate.a = 0.35 if vanish_t > 0.0 else 1.0
	if aura_part != "":
		var ar := aura_r * (2.0 if firebird_t > 0.0 else 1.0)
		var tt2 := Time.get_ticks_msec() * 0.001
		c.draw_circle(Vector2.ZERO, ar, Color(aura_color, 0.07 + 0.05 * sin(tt2 * 6.0)))
		c.draw_arc(Vector2.ZERO, ar, 0.0, TAU, 40, Color(aura_color, 0.35), 2.0)
		if firebird_t > 0.0:
			for sgn in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(0, -4), Vector2(sgn * 34.0, -18.0 + 4.0 * sin(tt2 * 8.0)), Vector2(sgn * 20.0, 6.0)])
				c.draw_colored_polygon(wing, Color(1.0, 0.6, 0.25, 0.55))
	if rekindle_t > 0.0 or ember_t > 0.0:
		var tt3 := Time.get_ticks_msec() * 0.001
		for i in 4:
			c.draw_circle(Vector2(sin(tt3 * 7.0 + i) * 8.0, -10.0 - fmod(tt3 * 30.0 + i * 6.0, 18.0)), 2.0, Color(1.0, 0.45, 0.25, 0.8))
	var tt := Time.get_ticks_msec() * 0.001
	if bladeward_t > 0.0:
		for i in 4:
			var ba := tt * 5.0 + TAU * i / 4.0
			var bp := Vector2.from_angle(ba) * bladeward_r
			var bd := Vector2.from_angle(ba + PI / 2.0)
			c.draw_colored_polygon(PackedVector2Array([bp + bd * 10.0, bp + bd.orthogonal() * 3.0, bp - bd * 6.0, bp - bd.orthogonal() * 3.0]), Color(bladeward_color, 0.9))
		c.draw_arc(Vector2.ZERO, bladeward_r, 0.0, TAU, 32, Color(bladeward_color, 0.2), 1.5)
	if kindle_t > 0.0:
		var tip := aim * (radius + 18.0)
		for i in 4:
			var fp := tip - aim * (i * 5.0) + Vector2(sin(tt * 13.0 + i) * 2.0, -3.0 - 3.0 * sin(tt * 9.0 + i * 1.7))
			c.draw_circle(fp, 2.6 - i * 0.4, Color(kindle_color, 0.85))
	if heat > 1.0:
		var hc := Color(1.0, 0.45 + 0.4 * heat / 100.0, 0.2, 0.8)
		c.draw_arc(Vector2.ZERO, radius + 9.0, PI * 0.6, PI * 0.6 + PI * 0.8 * heat / 100.0, 16, hc, 2.5)
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
	if barrier_hp > 0.0:
		# The barrier: a dome of facets that dims as it's spent.
		var tw := Time.get_ticks_msec() * 0.0015
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(tw + TAU * i / 6.0) * (radius + 10.0))
		c.draw_colored_polygon(pts, Color(barrier_color, 0.12))
		c.draw_polyline(pts, Color(barrier_color, 0.8), 2.0, true)
	if absorb_t > 0.0:
		c.draw_arc(Vector2.ZERO, radius + 14.0 + 2.0 * sin(Time.get_ticks_msec() * 0.02), 0.0, TAU, 24, Color(barrier_color, 0.8), 2.0)
	if unbreak_t > 0.0:
		c.draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.9), 3.0)
	if has_bond("warden") and parry_t <= 0.0 and Input.is_action_pressed("parry"):
		var ga := aim.angle()
		c.draw_arc(Vector2.ZERO, radius + 8.0, ga - 0.9, ga + 0.9, 12, Color(0.85, 0.71, 0.42, 0.9), 4.0)
	if anchor_t > 0.0 and anchor_target != null and is_instance_valid(anchor_target):
		var to_a: Vector2 = anchor_target.global_position - global_position
		var segs := 8
		for i in segs:
			var a0 := to_a * (float(i) / segs) + to_a.orthogonal().normalized() * sin(i * 1.3 + Time.get_ticks_msec() * 0.006) * 3.0
			var a1 := to_a * (float(i + 1) / segs) + to_a.orthogonal().normalized() * sin((i + 1) * 1.3 + Time.get_ticks_msec() * 0.006) * 3.0
			c.draw_line(a0, a1, Color(0.31, 0.5, 0.84, 0.85), 2.0)
	if drink_t > 0.0 and drink_target != null and is_instance_valid(drink_target):
		var to_d: Vector2 = drink_target.global_position - global_position
		c.draw_line(Vector2.ZERO, to_d, Color(0.31, 0.5, 0.84, 0.35), 6.0)
		c.draw_line(Vector2.ZERO, to_d, Color(0.6, 0.85, 1.0, 0.9), 2.0)
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


# --- items -------------------------------------------------------------------------

## The items you carry, in their usual order.
func carried() -> Array:
	return Items.ORDER.filter(func(id): return int(items.get(id, 0)) > 0)


func item_count(id: String) -> int:
	return int(items.get(id, 0))


## The item G uses (the first you carry if none is picked).
func selected_item() -> String:
	if item_count(item_sel) > 0:
		return item_sel
	var have := carried()
	return have[0] if not have.is_empty() else ""


## Picks up an item. False if you already carry as many as you can.
func add_item(id: String) -> bool:
	if not Items.ITEMS.has(id) or item_count(id) >= Items.MAX_STACK:
		return false
	items[id] = item_count(id) + 1
	if item_count(item_sel) <= 0:
		item_sel = id
	return true


## Switches G to the next item you carry.
func cycle_item() -> void:
	var have := carried()
	if have.is_empty():
		return
	var i := have.find(selected_item())
	item_sel = have[(i + 1) % have.size()]
	main.fx_text(global_position + Vector2(0, -40), Items.ITEMS[item_sel]["name"], Items.color(item_sel))
	main.sfx("step", 1.4, -6.0)


## Uses the selected item. True if it was used up.
func use_item() -> bool:
	if dead:
		return false
	var id := selected_item()
	if id == "":
		main.fx_text(global_position + Vector2(0, -40), "No items", Color(0.7, 0.68, 0.75))
		return false
	if not Items.use(id, self):
		return false
	items[id] = item_count(id) - 1
	if item_count(id) <= 0:
		items.erase(id)
		item_sel = selected_item()
	return true


## Healing items heal over a moment, not all at once.
func _tick_healing(delta: float) -> void:
	if heal_left <= 0.0 or dead:
		heal_left = 0.0
		return
	var h := minf(heal_left, heal_rate * delta)
	hp = minf(max_health(), hp + h)
	heal_left -= h
