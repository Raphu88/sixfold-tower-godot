extends "res://scripts/mirror.gd"
## A RIVAL CLIMBER's body (rivals.gd spawns it for a duel or a team-up).
##
## In a DUEL it fights you as your mirror image does (mirror.gd: its
## weapon's swing chain, rolls, a guard, and a spell for each of up to two
## of its marks, every attack telegraphed and glinting), but drawn as a
## climber of its own (its look and gear, its marks glowing on its body),
## and its spells leave its bond's state on you when they land (reactions.gd
## CLIMBER). It never dies: at its yield share of health it yields
## (rivals.gd on_yield).
##
## TEAMED UP (an ally) it fights the floor's monsters beside you: it walks to
## the nearest, swings at it, and casts its marks' spells at them, each
## leaving its bond's state (rivals.gd BOND_STATE) through reactions.gd, so a
## state of its meets one of yours and a reaction fires. Monsters strike it
## too; it takes only its share of a blow, and falls back hurt at its leave
## share of health (rivals.gd on_spent). Your blows never reach it.

const Bonds := preload("res://scripts/bonds.gd")

## Its warm light, the ring at its feet (in a duel, as an ally), and the
## words over it.
static var RIVAL_LOOK := {"glow": Color(1.0, 0.85, 0.6), "rim": Color(1.0, 0.78, 0.5), "ally": Color(0.6, 1.0, 0.75)}
static var RIVAL_TEXT := {"yields": "Yields", "falls_back": "Falls back"}
## As an ally: how far it looks for a foe (from itself, and from you), the
## wind-up of its swing and its spells (times their duel wind-up), and the
## pause after.
static var ALLY := {"seek": 380.0, "near_you": 260.0, "swing_wind": 0.35, "spell_wind": 0.8, "swing_pause": 0.75, "spell_pause": 0.5, "follow": 70.0}

var rival_name := ""
var host = null  # rivals.gd: told when it yields or falls back
var bond_states := {}
var state_secs := 4.0
var yield_at := 0.12
var taken_k := 0.6
var leave_at := 0.2
var bonds_held: Array = []  # [bond, part, step]
var target = null
var standing := false  # stood down: no longer fighting


## Call before adding it to the room. `data`: rivals.gd body_data.
func setup_rival(room, data: Dictionary, as_ally: bool, host_node) -> void:
	main = room
	kind = "rival"
	mirror = true  # (like a mirror image: never bound, harvested or written in the Bestiary)
	host = host_node
	rival_name = String(data.get("name", ""))
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	max_hp = float(data.get("hp", 120.0)) * tough.x
	hp = max_hp
	radius = float(STATS["radius"])
	speed = float(STATS["speed"])
	weight = float(STATS["weight"])
	color = RIVAL_LOOK["rim"]
	dmg = Weapons.BASE * tough.y
	aware = true
	notice_t = 0.0
	spell_t = float(SPELL["first"])
	w_id = String(data.get("weapon", "sword"))
	wd = Weapons.info(w_id)
	if wd.is_empty():
		w_id = "fists"
		wd = Weapons.info("fists")
	ranged = String(wd["kind"]) != "melee"
	chain = [] if ranged else (wd["combo"] as Array).slice(0, int(SWING["links"]))
	armor = clampf(float(data.get("armor_k", 0.2)), 0.0, 0.8)
	armor_id = String(data.get("armor", ""))
	look = data.get("look", {})
	bond_states = data.get("states", {})
	state_secs = float(data.get("state_seconds", 4.0))
	yield_at = float(data.get("yield", 0.12))
	taken_k = float(data.get("taken", 0.6))
	leave_at = float(data.get("leave", 0.2))
	bonds_held = data.get("bonds", []).duplicate(true)
	marks.clear()
	spells.clear()
	var bl: Array = bonds_held.duplicate()
	bl.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	for bd in bl:
		var id := String(bd[0])
		var col: Color = Bonds.BONDS.get(id, {}).get("color", Color.WHITE)
		marks.append([String(bd[1]), col, int(bd[2])])
		if spells.size() >= int(SPELL["max"]):
			continue
		spells.append({"bond": id, "name": spell_name(id, int(bd[2])), "shape": String(BOND_SHAPE.get(id, "blast")), "color": col, "step": int(bd[2])})
	ally = as_ally
	if ally:
		state = "ally"
		ally_life = max_hp
		ally_t = hp
	else:
		state = "emerge"
		state_t = 1.0


## The newest spell a bond knows at a step (its name, for the word over it).
static func spell_name(id: String, step: int) -> String:
	var out := String(Bonds.BONDS.get(id, {}).get("name", id))
	for sp in Bonds.BONDS.get(id, {}).get("spells", []):
		if int(sp.get("learn", 1)) <= step:
			out = String(sp.get("name", out))
	return out


func bond_ids() -> Array:
	return bonds_held.map(func(b): return String(b[0]))


func _glow_color() -> Color:
	return RIVAL_LOOK["glow"]


# --- the duel: a mirror image's fight, but it yields -------------------------------------

## A spell that lands on you leaves its bond's state (reactions.gd CLIMBER).
func _release_spell(p) -> void:
	var sp: Dictionary = spells[spell_i]
	var before: float = p.hp
	super._release_spell(p)
	var st := String(bond_states.get(String(sp["bond"]), ""))
	if p.hp < before and not p.dead and Reactions.CLIMBER.get("seconds", {}).has(st):
		Reactions.apply(main, p, st, 0.0, self)


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead or standing or ally:
		return  # (your blows never reach the one beside you)
	super.take_hit(amount, dir, force, heavy, pierce)
	if not dead and not standing and hp <= max_hp * yield_at:
		_yield()


func _refuse_death() -> bool:
	return true  # (it yields instead: take_hit above)


func _yield() -> void:
	standing = true
	main.fx_text(global_position + Vector2(0, -radius - 30.0), RIVAL_TEXT["yields"], RIVAL_LOOK["rim"])
	main.fx_ring(global_position, RIVAL_LOOK["rim"], 44.0, 0.45, 3.0)
	var h = host
	_remove()
	if h != null and is_instance_valid(h):
		h.on_yield(self)


## Out of the fight (a duel over, a team ended): gone from the room; rivals.gd
## draws them standing where they were while they leave.
func stand_down() -> void:
	standing = true
	_remove()


func _remove() -> void:
	dead = true
	if main != null and is_instance_valid(main):
		main.release_attack(self)
	remove_from_group("enemies")
	remove_from_group("allies")
	queue_free()


# --- teamed up: an ally ---------------------------------------------------------------------

## A monster's blow reaching it: its share, and it falls back when hurt.
func receive_attack(amount: float, source, unblockable := false) -> void:
	if dead or standing:
		return
	if not ally:
		super.receive_attack(amount, source, unblockable)
		return
	hp -= amount * taken_k
	flash = 0.12
	ally_t = hp
	main.fx_text(global_position + Vector2(0, -radius - 10.0), str(int(round(amount * taken_k))), Color(1.0, 0.6, 0.55))
	if hp <= max_hp * leave_at:
		standing = true
		main.fx_text(global_position + Vector2(0, -radius - 26.0), RIVAL_TEXT["falls_back"], Color(0.8, 0.8, 0.8))
		var h = host
		_remove()
		if h != null and is_instance_valid(h):
			h.on_spent(self)


func _ally_ai(delta: float) -> void:
	if standing:
		return
	roll_cd -= delta
	spell_t -= delta
	swing_anim -= delta
	ally_cd -= delta
	ally_t = hp
	ally_life = max_hp
	var p = main.player
	if target != null and (not is_instance_valid(target) or target.dead or target.submerged):
		target = null
	if target == null or Engine.get_physics_frames() % 20 == 0:
		target = _pick_target(p)
	var go := Vector2.ZERO
	match state:
		"wind_spell":
			state_t -= delta
			if target != null:
				var to: Vector2 = target.global_position - global_position
				face = face.slerp(to.normalized(), minf(1.0, 8.0 * delta)).normalized()
				lunge_dir = face
				if state_t > 0.25:
					spell_spot = target.global_position
			if state_t <= 0.0:
				_ally_release()
				state = "ally"
				ally_cd = float(ALLY["spell_pause"])
		"wind_swing":
			state_t -= delta
			if state_t <= 0.0:
				_ally_swing()
				state = "ally"
				ally_cd = float(ALLY["swing_pause"])
		_:
			state = "ally"
			if target != null:
				var to2: Vector2 = target.global_position - global_position
				var dist := to2.length()
				face = face.slerp(to2.normalized(), minf(1.0, 8.0 * delta)).normalized()
				var sp_range := 0.0
				if not spells.is_empty():
					sp_range = float(SHAPES[spells[spell_i]["shape"]]["range"]) + 40.0
				if not spells.is_empty() and spell_t <= 0.0 and dist < sp_range and main.clear_line(global_position, target.global_position):
					wind_dur = float(SHAPES[spells[spell_i]["shape"]]["wind"]) * float(ALLY["spell_wind"])
					state = "wind_spell"
					state_t = wind_dur
					spell_spot = target.global_position
					lunge_dir = to2.normalized()
					main.fx_text(global_position + Vector2(0, -radius - 34.0), String(spells[spell_i]["name"]), spells[spell_i]["color"])
					main.sfx("charge", 0.9, -6.0)
				elif dist > _reach() + target.radius - 4.0:
					go = _toward(target.global_position)
				elif ally_cd <= 0.0:
					wind_dur = float(ALLY["swing_wind"])
					state = "wind_swing"
					state_t = wind_dur
					lunge_dir = to2.normalized()
			elif p != null and global_position.distance_to(p.global_position) > float(ALLY["follow"]):
				go = _toward(p.global_position)
				face = face.slerp(go.normalized(), minf(1.0, 6.0 * delta)).normalized() if go != Vector2.ZERO else face
	velocity = go + knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	_redraw()


func _toward(at: Vector2) -> Vector2:
	var d := (at - global_position).normalized()
	if not main.clear_line(global_position, at):
		d = main.path_dir(global_position, at)
	return d * speed


## The foe to fight: the nearest near you, else the nearest near it.
func _pick_target(p):
	var best = null
	var best_d := float(ALLY["near_you"])
	if p != null:
		for e in main.targets():
			var d: float = p.global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	if best != null:
		return best
	best_d = float(ALLY["seek"])
	for e in main.targets():
		var d2 := global_position.distance_to(e.global_position)
		if d2 < best_d and main.clear_line(global_position, e.global_position):
			best_d = d2
			best = e
	return best


func _ally_swing() -> void:
	var sw: Dictionary = chain[0] if not chain.is_empty() else {"range": 40.0, "arc": 50.0, "dmg": 1.0}
	var reach := float(sw["range"]) + 6.0
	var arc := float(sw["arc"])
	swing_side = float(sw.get("side", 1.0))
	swing_heavy = false
	swing_anim = float(wd.get("swing_time", 0.15)) * 2.0
	main.fx_cone(global_position, lunge_dir, reach + 8.0, deg_to_rad(arc), RIVAL_LOOK["ally"])
	main.sfx(String(wd.get("sound", "swing")), float(wd.get("pitch", 1.0)) * 0.95, -4.0)
	var amount: float = dmg * float(STATS["melee"]) * float(sw.get("dmg", 1.0))
	for e in main.targets():
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(arc):
			e.take_hit(amount, to.normalized(), 140.0)


## Its spell on the floor's monsters: their damage, and its bond's state on
## each it strikes (the state first, so a reaction can fire before it falls).
func _ally_release() -> void:
	if spells.is_empty():
		return
	var sp: Dictionary = spells[spell_i]
	var shape: Dictionary = SHAPES[sp["shape"]]
	var col: Color = sp["color"]
	var amount := spell_damage(sp)
	spell_i = (spell_i + 1) % spells.size()
	var ev: Array = SPELL["every"]
	spell_t = randf_range(float(ev[0]), float(ev[1]))
	var hit: Array = []
	match String(sp["shape"]):
		"blast":
			var r := float(shape["r"])
			main.fx_ring(spell_spot, col, r, 0.4, 4.0)
			main.fx_burst(spell_spot, Vector2.ZERO, col, 16, 220.0)
			main.light_flash(spell_spot, col, 1.5, 1.6, 0.3)
			main.sfx("zap" if sp["bond"] == "stormcaller" else "slam", 0.9, -4.0)
			for e in main.targets():
				if e.global_position.distance_to(spell_spot) < r + e.radius:
					hit.append(e)
		"cone":
			var reach := float(shape["reach"])
			var half := deg_to_rad(float(shape["arc"]))
			main.fx_cone(global_position, lunge_dir, reach, half, col)
			main.sfx("swing_heavy", 0.8, -4.0)
			for e in main.targets():
				var to: Vector2 = e.global_position - global_position
				if to.length() < reach + e.radius and absf(lunge_dir.angle_to(to)) <= half:
					hit.append(e)
		"nova":
			var r2 := float(shape["r"])
			main.fx_ring(global_position, col, r2, 0.4, 5.0)
			main.fx_burst(global_position, Vector2.ZERO, col, 20, 260.0)
			main.light_flash(global_position, col, 1.6, 1.6, 0.3)
			main.sfx("slam", 1.1, -4.0)
			for e in main.targets():
				if e.global_position.distance_to(global_position) < r2 + e.radius:
					hit.append(e)
		_:  # a volley: bolts at its foe and up to two others near
			var n := int(shape["count"])
			var near: Array = main.targets().filter(func(e): return e.global_position.distance_to(global_position) < float(shape["range"]) + 40.0)
			near.sort_custom(func(a, b): return a.global_position.distance_to(spell_spot) < b.global_position.distance_to(spell_spot))
			for e in near.slice(0, n):
				hit.append(e)
				main.fx_bolt([global_position, e.global_position], col)
			main.sfx("swing_light", 1.3, -4.0)
	var st := String(bond_states.get(String(sp["bond"]), ""))
	for e in hit:
		if not is_instance_valid(e) or e.dead:
			continue
		if st != "":
			Reactions.apply(main, e, st, state_secs, self)
		if is_instance_valid(e) and not e.dead:
			var dir: Vector2 = (e.global_position - global_position).normalized()
			e.take_hit(amount, dir, 120.0)


# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if standing:
		return
	var t := Time.get_ticks_msec() * 0.001
	_dt = clampf(get_process_delta_time(), 0.0, 0.05)
	var spd := velocity.length()
	_move = move_toward(_move, clampf(spd / 120.0, 0.0, 1.0), _dt * 6.0)
	_phase = fmod(_phase + spd * _dt / 11.0, TAU)
	var lift := -12.0 if airborne > 0.0 else 0.0
	var f := face
	var sd := f.orthogonal()
	draw_circle(Vector2(0, radius * 0.75), radius * 1.05, Color(0, 0, 0, 0.3))
	var b := Draw.Batch.new()
	if state == "roll":
		_draw_rolled(b)
	else:
		draw_climber(b, look, _pose(f, sd, t))
	for m in marks:
		var at := _mark_at(String(m[0]), f, sd)
		var mc: Color = m[1]
		b.dot(at, 3.2, Color(Palette.OUTLINE, 0.8))
		b.dot(at, 2.3, mc)
		for i in int(m[2]):
			var a := at.angle() + PI + (float(i) - (float(m[2]) - 1.0) / 2.0) * 0.5
			b.line(at + Vector2.from_angle(a) * 3.0, at + Vector2.from_angle(a) * 6.0, Color(mc, 0.9), 1.2)
	var fl := clampf(flash / 0.12, 0.0, 1.0) * 0.6
	if fl > 0.0:
		for i in b.cols.size():
			b.cols[i] = Color(Color(b.cols[i]).lerp(Color(1, 1, 1), fl), b.cols[i].a)
	_last.pts = b.pts.duplicate()
	_last.cols = b.cols.duplicate()
	draw_set_transform(Vector2(0, lift))
	b.flush(self)
	draw_set_transform(Vector2.ZERO)
	if overlay != null:
		overlay.queue_redraw()


## Over the darkness: a ring at its feet (warm in a duel, green beside you),
## and in a duel its attacks' telegraphs, as a mirror image's.
func _overlay_extra(o) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var col: Color = RIVAL_LOOK["ally"] if ally else RIVAL_LOOK["rim"]
	o.arc(Vector2(0, radius * 0.7), radius + 5.0, 0.0, TAU, 1.4, Color(col, 0.35 + 0.15 * sin(now * 2.6)), 30)
	if not ally:
		_telegraphs(o)
	elif state == "wind_spell" and not spells.is_empty():
		var sc: Color = spells[spell_i]["color"]
		o.arc(Vector2.ZERO, radius + 8.0 + 10.0 * _wk(wind_dur), 0.0, TAU, 2.0, Color(sc, 0.8), 28)
