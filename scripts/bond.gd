extends RefCounted
## One bond: a named power marked on one body part.
## The body part decides how it fills; the bond's data (bonds.gd) decides
## its spell and how that spell grows with each step.

const Bonds := preload("res://scripts/bonds.gd")
const PART_NAMES := Bonds.PART_NAMES
const PART_FILLS := Bonds.PART_FILLS
const PART_BURN := Bonds.PART_BURN
const MAX_STEP := 5

var id: String
var part: String
var step := 1
var essence := 0.0
var burned := false
var faint := false  # a mark taken in defeat: weaker until it catches up
var overdraw_mult := 1.0  # set for an overdrawn cast: desperate casts are weaker

## How strong an overdrawn cast is, and how much health per missing essence
## overdrawing an already-burned mark tears out of you.
const OVERDRAW_POWER := 0.7
const TEAR_HEALTH := 1.0


func _init(bond_id: String, body_part: String) -> void:
	id = bond_id
	part = body_part


func data() -> Dictionary:
	return Bonds.BONDS[id]


# --- spells ----------------------------------------------------------------------

var selected := 0  # which learned spell the mark's key casts


## The spells this bond knows at its current step, in the order learned.
func spells() -> Array:
	return data()["spells"].filter(func(sp): return int(sp["learn"]) <= step)


## The spell the mark's key casts.
func spell() -> Dictionary:
	var known := spells()
	return known[clampi(selected, 0, known.size() - 1)]


func select(i: int) -> void:
	selected = clampi(i, 0, spells().size() - 1)


## A value for the selected spell at the current step: the latest step at or
## below this one that sets it wins.
func stat(key: String):
	return spell_stat(spell(), key)


func spell_stat(sp: Dictionary, key: String):
	var steps: Dictionary = sp["steps"]
	var value = null
	for s in range(1, step + 1):
		if steps.has(s) and steps[s].has(key):
			value = steps[s][key]
	return value


func display_name() -> String:
	return data()["name"]


func spell_name() -> String:
	return spell()["name"]


func spell_desc() -> String:
	return spell()["desc"]


func body_name() -> String:
	return data()["body"]["name"]


func passive_name() -> String:
	return data()["passive"]["name"]


func color() -> Color:
	return data()["color"]


func capacity() -> float:
	return 30.0 + 10.0 * step


func cost() -> float:
	return float(stat("cost")) * (1.25 if faint else 1.0)


## A faint mark's spells hit softer, and so do desperate (overdrawn) casts.
func power() -> float:
	return (0.75 if faint else 1.0) * overdraw_mult


func damage() -> float:
	return float(stat("damage")) * power()


func windup() -> float:
	return float(stat("windup"))


## What reaching `new_step` brings, in a few words (empty if nothing).
func step_note(new_step: int) -> String:
	return Bonds.step_note(id, new_step)


func fill(amount: float) -> void:
	essence = minf(capacity(), essence + amount)


## Pays for a cast. Returns "paid", "burned" (overdrawn: the body part burns)
## or "torn" (overdrawn again while burned: it costs health instead), and
## sets overdraw_mult for the cast. `missing` is how much essence was short.
var missing := 0.0


func pay(free := false) -> String:
	if free:  # Grand Sigil: spells cost nothing inside it
		overdraw_mult = 1.0
		missing = 0.0
		return "paid"
	if essence >= cost():
		essence -= cost()
		overdraw_mult = 1.0
		missing = 0.0
		return "paid"
	missing = cost() - essence
	essence = 0.0
	overdraw_mult = OVERDRAW_POWER
	if burned:
		return "torn"
	burned = true
	return "burned"


func cast(p) -> void:
	match spell()["type"]:
		"chain":
			_chain(p)
		"overcharge":
			_overcharge(p)
		"rod":
			_rod(p)
		"thunderhead":
			_thunderhead(p)
		"lift":
			_lift(p)
		"crosswind":
			_crosswind(p)
		"downdraft":
			_downdraft(p)
		"cyclone":
			_cyclone(p)
		"shot":
			_shot(p)
		"track":
			_track(p)
		"hawkeye":
			_hawkeye(p)
		"rain":
			_rain(p)
		"surge":
			_surge(p)
		"riptide":
			_riptide(p)
		"carry":
			_carry(p)
		"maelstrom":
			_maelstrom(p)
		"barrier":
			_barrier(p)
		"absorb":
			_absorb(p)
		"challenge":
			_challenge(p)
		"unbreakable":
			_unbreakable(p)
		"drain":
			_drain(p)
		"anchor":
			_anchor(p)
		"siphon":
			_siphon(p)
		"drink":
			_drink(p)
		"blades":
			_blades(p)
		"recall":
			_recall(p)
		"bladeward":
			_bladeward(p)
		"edges":
			_edges(p)
		"kindle":
			_kindle(p)
		"lash":
			_lash(p)
		"searing":
			_searing(p)
		"overheat":
			_overheat(p)
		"trap":
			_trap(p)
		"inscribe":
			_inscribe(p)
		"ward":
			_ward(p)
		"sigil":
			_sigil(p)



func _overdrawn() -> bool:
	return overdraw_mult < 1.0


func _chain(p) -> void:
	var main = p.main
	var leaps: int = int(stat("leaps")) * (2 if p.thunderhead_t > 0.0 else 1)
	var from: Vector2 = p.global_position
	var reach: float = stat("reach")
	var hit: Array = []
	var points: Array = [from]
	# Lightning Rod: the chain bends through a planted rod first.
	if not main.rod.is_empty() and from.distance_to(main.rod["pos"]) < 420.0:
		from = main.rod["pos"]
		points.append(from)
		reach = maxf(reach, float(main.rod["reach"]))
	for i in leaps:
		var best = null
		var best_d := reach
		for e in main.targets():
			if e in hit:
				continue
			var d: float = from.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		points.append(best.global_position)
		from = best.global_position
		reach = stat("hop")
	if hit.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	main.fx_bolt(points, color())
	for pt in points:
		main.light_flash(pt, color(), 1.0, 1.4, 0.3)
	main.sfx("zap")
	main.hitstop(0.07)
	main.shake(5.0)
	var stun: float = stat("stun")
	for e in hit:
		if not is_instance_valid(e) or e.dead:
			continue
		e.charged = 4.0
		if stun > 0.0:
			e.stagger(stun)
		e.take_hit(damage(), Vector2.ZERO)
	# Overdrawn, the last leap may jump back to you.
	if _overdrawn() and randf() < 0.5:
		main.fx_bolt([points[-1], p.global_position], color())
		p.hp = maxf(1.0, p.hp - 6.0)
		main.fx_text(p.global_position + Vector2(0, -50), "the chain jumps back! -6", Color(1.0, 0.4, 0.3))


# Charge one foe; when it dies, lightning leaps from it to every foe nearby.
func _overcharge(p) -> void:
	var main = p.main
	var target = _target_in_aim(p, 320.0)
	if target == null:
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	target.overcharge_t = stat("duration")
	target.overcharge_dmg = damage()
	target.overcharge_r = stat("radius")
	main.fx_bolt([p.global_position, target.global_position], color())
	main.fx_ring(target.global_position, color(), 30.0, 0.3, 2.0)
	main.sfx("zap", 0.8, -4.0)


# Plant a rod: your chains bend through it.
func _rod(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * 90.0
	main.rod = {"pos": at, "t": stat("duration"), "reach": stat("reach")}
	main.fx_ring(at, color(), 26.0, 0.3, 2.0)
	main.light_flash(at, color(), 0.9, 1.0, 0.3)
	main.sfx("equip_sword", 0.7, -2.0)


# For a while, every chain leaps twice as many times.
func _thunderhead(p) -> void:
	var main = p.main
	p.thunderhead_t = stat("duration")
	main.fx_ring(p.global_position, color(), 80.0, 0.5, 4.0)
	main.light_flash(p.global_position, color(), 2.0, 1.6, 0.6)
	main.sfx("zap", 0.6)
	main.shake(4.0)


## The foe nearest to where you're aiming, within reach (or null).
func _target_in_aim(p, reach: float):
	var best = null
	var best_score := INF
	for e in p.main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() > reach:
			continue
		var score: float = to.length() * (1.0 + 2.0 * absf(p.aim.angle_to(to)))
		if score < best_score:
			best_score = score
			best = e
	return best


# A gust in front of you throws foes into the air, helpless.
func _lift(p) -> void:
	var main = p.main
	var half_arc := deg_to_rad(stat("arc"))
	var reach: float = stat("reach")
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	main.fx_cone(origin, aim, reach, half_arc, color())
	main.light_flash(origin + aim * reach * 0.5, color(), 1.4, 0.8, 0.35)
	main.sfx("gust", 0.9)
	var lifted := 0
	var dmg: float = damage()
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > half_arc:
			continue
		e.lift(stat("lift"))
		e.knock = aim * 120.0
		if dmg > 0.0:
			e.take_hit(dmg, aim, 60.0)
		lifted += 1
	if lifted == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing to lift", color())


# A wave bursts out around you, hurling every foe in reach away. From step 3
# it is an aimed wave that travels forward.
func _surge(p) -> void:
	var main = p.main
	var origin: Vector2 = p.global_position
	if _overdrawn():
		p.knock = -p.aim * 300.0  # an overdrawn surge knocks you back too
	main.sfx("hit_slime", 0.6)
	main.sfx("gust", 0.7, -4.0)
	main.shake(5.0)
	if stat("aimed"):
		main.add_wave(origin, p.aim, stat("width"), stat("travel"), damage(), stat("push"), false, color())
		return
	var radius: float = stat("radius")
	main.fx_ring(origin, color(), radius, 0.45, 6.0)
	main.fx_ring(origin, Color(1, 1, 1, 0.8), radius * 0.6, 0.3, 2.0)
	main.fx_burst(origin, Vector2.ZERO, color(), 24, 320.0)
	main.light_flash(origin, color(), 1.6, 1.2, 0.4)
	var hit := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() > radius + e.radius:
			continue
		var dir := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
		e.tide_push(dir * float(stat("push")))
		e.take_hit(damage(), dir, stat("push"))
		hit += 1
	if hit == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing in reach", color())


# Pull every foe in a line toward you.
func _riptide(p) -> void:
	var main = p.main
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var length: float = stat("length")
	var pulled := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		var along := to.dot(aim)
		if along < 0.0 or along > length or absf(to.dot(aim.orthogonal())) > stat("width") * 0.5 + e.radius:
			continue
		var pull := -aim * minf(along * 2.4, 520.0)
		e.tide_push(pull)
		e.take_hit(damage(), Vector2.ZERO)
		e.knock = pull
		pulled += 1
	main.fx_cone(origin, aim, length, deg_to_rad(6.0), color())
	main.sfx("gust", 0.6, -2.0)
	if pulled == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing in line", color())


# A wave carries every foe in front of you until it breaks against a wall.
func _carry(p) -> void:
	p.main.add_wave(p.global_position, p.aim, stat("width"), 2000.0, damage(), 0.0, true, color())
	p.main.sfx("hit_slime", 0.5)
	p.main.sfx("gust", 0.6)


# A whirlpool drags every foe in a wide area to its centre.
func _maelstrom(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.maelstroms.append({"pos": at, "r": stat("radius"), "t": stat("duration") * power(), "damage": damage(), "tick": 0.0, "color": color()})
	main.sfx("gust", 0.5)
	main.light_flash(at, color(), 1.8, 1.0, 0.5)


# A shell that absorbs damage (from step 3 it bursts when it breaks).
func _barrier(p) -> void:
	var dur: float = stat("duration") * (0.5 if _overdrawn() else 1.0)  # an overdrawn barrier cracks early
	p.raise_barrier(float(stat("shield")) * power(), dur, bool(stat("burst")), color())
	p.main.fx_ring(p.global_position, color(), 40.0, 0.35, 3.0)
	p.main.sfx("parry", 0.7, -6.0)


# For a moment every hit you take is stored in your barrier instead.
func _absorb(p) -> void:
	p.absorb_t = stat("duration")
	if p.barrier_t <= 0.0:
		p.raise_barrier(1.0, stat("duration") + 2.0, _burst_known(), color())
	p.main.fx_ring(p.global_position, color(), 30.0, 0.3, 2.0)
	p.main.sfx("charge", 1.4, -4.0)


func _burst_known() -> bool:
	for sp in spells():
		if sp["type"] == "barrier":
			return bool(spell_stat(sp, "burst"))
	return false


# Every foe nearby must come at you, and takes more damage from you.
func _challenge(p) -> void:
	var main = p.main
	var n := 0
	for e in main.targets():
		if e.global_position.distance_to(p.global_position) < stat("radius"):
			e.challenged_t = stat("duration")
			n += 1
	main.fx_ring(p.global_position, color(), stat("radius"), 0.5, 4.0)
	main.sfx("warn_knight", 0.8)
	main.shake(3.0)
	if n == 0:
		main.fx_text(p.global_position + Vector2(0, -34), "no one to challenge", color())


# For a few seconds you take no damage, but cannot attack.
func _unbreakable(p) -> void:
	p.unbreak_t = stat("duration")
	p.main.fx_ring(p.global_position, color(), 60.0, 0.5, 5.0)
	p.main.light_flash(p.global_position, color(), 1.4, 1.4, 0.5)
	p.main.sfx("parry", 0.5)


## The foes nearest you, up to `count`, within `reach`.
func _nearest(p, count: int, reach: float) -> Array:
	var list: Array = p.main.targets().filter(func(e): return e.global_position.distance_to(p.global_position) < reach)
	list.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	return list.slice(0, count)


# Drag life out of the nearest foes and drink some of it back.
func _drain(p) -> void:
	var main = p.main
	var foes := _nearest(p, int(stat("targets")), stat("reach"))
	if foes.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no one in reach", color())
		return
	var total := 0.0
	for e in foes:
		main.fx_bolt([e.global_position, p.global_position], color())
		e.take_hit(damage(), Vector2.ZERO)
		total += damage()
	var heal: float = total * float(stat("heal")) * (1.5 if p.main.tower_data()["essence"] == "water" else 1.0)
	p.hp = minf(p.max_health(), p.hp + heal)
	main.fx_text(p.global_position + Vector2(0, -40), "+%d" % int(heal), Color(0.5, 1.0, 0.6))
	main.sfx("zap", 0.5, -4.0)
	if _overdrawn():
		p.hp = maxf(1.0, p.hp - 6.0)  # an overdrawn Undertow drains you as well


# Tether a foe so it cannot move away from you.
func _anchor(p) -> void:
	var target = _target_in_aim(p, stat("reach"))
	if target == null:
		p.main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	p.anchor_target = target
	p.anchor_t = stat("duration")
	p.anchor_len = stat("length")
	p.main.sfx("equip_sword", 0.6, -2.0)


# Drain essence instead of health: it refills every mark you carry.
func _siphon(p) -> void:
	var main = p.main
	var foes := _nearest(p, int(stat("targets")), stat("reach"))
	if foes.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no one in reach", color())
		return
	for e in foes:
		main.fx_bolt([e.global_position, p.global_position], Color(0.6, 0.85, 1.0))
		e.take_hit(damage(), Vector2.ZERO)
	for b in p.bonds.values():
		b.fill(float(stat("refill")) * foes.size())
	main.fx_text(p.global_position + Vector2(0, -40), "essence drawn", Color(0.6, 0.85, 1.0))
	main.sfx("zap", 0.6, -4.0)


# Channel a drain on one foe; it grows stronger every second it holds.
func _drink(p) -> void:
	var target = _target_in_aim(p, stat("reach"))
	if target == null:
		p.main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	p.drink_target = target
	p.drink_t = stat("duration")
	p.drink_age = 0.0
	p.drink_dmg = damage()
	p.main.sfx("charge", 0.6)


# A fan of conjured blades that pierce through every foe in their path.
## Weapon Memory: conjured blades take after the weapon in your hand.
func _blade_shape(p) -> Dictionary:
	match p.weapon:
		"fists":
			return {"extra": 2, "speed": 640.0, "mult": 0.7, "life": 1.2}
		"bow":
			return {"extra": 0, "speed": 840.0, "mult": 1.3, "life": 2.0}
	return {"extra": 0, "speed": 560.0, "mult": 1.0, "life": 1.5}


func _throw_blades(p, count: int, spread: float, back := false, jitter := 0.0) -> void:
	var main = p.main
	var shape := _blade_shape(p)
	count += int(shape["extra"])
	var aim: Vector2 = p.aim
	for i in count:
		var off := (float(i) - (float(count) - 1.0) / 2.0) * spread / maxf(1.0, float(count - 1)) * 2.0 if count > 1 else 0.0
		off += randf_range(-jitter, jitter)
		var dir := aim.rotated(off)
		var spd: float = float(shape["speed"]) * (randf_range(0.85, 1.1) if jitter > 0.0 else 1.0)
		var b = main.spawn_player_arrow(p.global_position + dir * (p.radius + 6.0), dir * spd, damage() * float(shape["mult"]), 120.0, true)
		b.style = "blade"
		b.tint = color()
		b.life = float(shape["life"])
		if back:
			b.return_to = p
			b.out_t = 0.4


func _blades(p) -> void:
	var main = p.main
	var aim: Vector2 = p.aim
	_throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")) * (float(stat("count")) - 1.0) / 2.0)
	main.sfx("swing", 1.4)
	main.sfx("equip_sword", 1.3, -4.0)
	main.light_flash(p.global_position + aim * 30.0, color(), 1.0, 0.9, 0.25)


# A wall of wind across your path that turns enemy arrows back.
func _crosswind(p) -> void:
	var main = p.main
	var center: Vector2 = p.global_position + p.aim * 50.0
	var half: Vector2 = p.aim.orthogonal() * stat("length") * 0.5
	main.walls.append({"a": center - half, "b": center + half, "t": stat("duration"), "color": color()})
	main.sfx("gust", 1.1, -2.0)
	main.light_flash(center, color(), 1.0, 0.8, 0.3)


# Slam every foe in the air into the ground.
func _downdraft(p) -> void:
	var main = p.main
	var slammed := 0
	for e in main.targets():
		if e.airborne <= 0.0 or e.global_position.distance_to(p.global_position) > 420.0:
			continue
		e.airborne = 0.0
		main.fx_ring(e.global_position, color(), stat("radius"), 0.35, 4.0)
		main.fx_burst(e.global_position, Vector2.ZERO, Color(0.8, 0.75, 0.7), 12, 220.0)
		for o in main.targets():
			if o != e and o.global_position.distance_to(e.global_position) < stat("radius"):
				o.take_hit(float(stat("splash")) * power(), (o.global_position - e.global_position).normalized(), 120.0)
		e.take_hit(damage(), Vector2.ZERO, 0.0, true)
		slammed += 1
	if slammed == 0:
		main.fx_text(p.global_position + Vector2(0, -34), "nothing in the air", color())
	else:
		main.sfx("hit_heavy", 0.8)
		main.shake(7.0)
		main.hitstop(0.08)


# A cyclone that holds every foe inside it aloft.
func _cyclone(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.cyclones.append({"pos": at, "r": stat("radius"), "t": stat("duration") * power(), "color": color()})
	main.sfx("gust", 0.6)
	main.light_flash(at, color(), 1.8, 1.2, 0.5)


# A long-range arrow of essence that pierces a whole line of foes.
func _shot(p) -> void:
	var main = p.main
	var dir: Vector2 = p.aim
	if _overdrawn():
		dir = dir.rotated(randf_range(-0.4, 0.4))  # an overdrawn shot flies wide
	var dmg := damage() * (3.0 if stat("charged") else 1.0)
	var b = main.spawn_player_arrow(p.global_position + dir * (p.radius + 8.0), dir * float(stat("speed")), dmg, 160.0, true)
	b.style = "essence"
	b.tint = color()
	b.life = 1.5
	main.sfx("bow", 1.3)
	main.light_flash(p.global_position + dir * 30.0, color(), 0.9, 1.0, 0.2)
	if stat("charged"):
		main.shake(4.0)


# Reveal every foe and where it is heading.
func _track(p) -> void:
	p.main.track_t = stat("duration")
	p.main.sfx("glint", 0.8, -4.0)
	p.main.fx_ring(p.global_position, color(), 160.0, 0.6, 2.0)


# For a few seconds, every arrow strikes a weak point.
func _hawkeye(p) -> void:
	p.hawk_t = stat("duration")
	p.main.sfx("ready", 0.8)
	p.main.fx_ring(p.global_position, color(), 50.0, 0.4, 3.0)


# Arrows fall on a marked area.
func _rain(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.rains.append({"pos": at, "r": stat("radius"), "t": stat("duration"), "tick": 0.0, "damage": damage(), "color": color()})
	main.sfx("bow", 0.8)


# --- Blade Forger --------------------------------------------------------------

# Blades fly out, then come back to you, cutting again on the way.
func _recall(p) -> void:
	_throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")), true)
	p.main.sfx("swing", 1.2)
	p.main.sfx("equip_sword", 1.1, -4.0)


# Blades circle you, cutting anything that comes close.
func _bladeward(p) -> void:
	p.bladeward_t = stat("duration")
	p.bladeward_dmg = damage()
	p.bladeward_r = stat("radius")
	p.bladeward_color = color()
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.35, 3.0)
	p.main.sfx("equip_sword", 1.4)


# A storm of blades fanning out toward your aim.
func _edges(p) -> void:
	var main = p.main
	_throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")) * 0.5, false, deg_to_rad(4.0))
	main.sfx("swing_heavy", 1.3)
	main.sfx("equip_sword", 0.9)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.6, 1.4, 0.35)
	main.shake(4.0)


# --- Flameblade --------------------------------------------------------------------

func _kindle(p) -> void:
	p.kindle_t = stat("duration")
	p.kindle_dmg = damage()
	p.kindle_sustain = bool(stat("sustain"))
	p.kindle_color = color()
	p.main.fx_ring(p.global_position + p.aim * 14.0, color(), 30.0, 0.3, 3.0)
	p.main.sfx("burn", 1.2, -4.0)
	p.main.light_flash(p.global_position, color(), 1.2, 1.2, 0.3)


# A wave of fire thrown forward.
func _lash(p) -> void:
	var main = p.main
	main.add_wave(p.global_position + p.aim * (p.radius + 6.0), p.aim, stat("width"), stat("travel"), damage(), 70.0, false, color())
	main.sfx("swing_heavy", 1.1)
	main.sfx("burn", 1.0, -4.0)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.4, 1.4, 0.3)


# Kindles your weapon; while it burns, parries explode.
func _searing(p) -> void:
	p.kindle_t = maxf(p.kindle_t, stat("duration"))
	p.kindle_dmg = maxf(p.kindle_dmg, 3.0 * power())
	p.kindle_color = color()
	p.searing_dmg = damage()
	p.main.fx_ring(p.global_position, color(), 36.0, 0.35, 3.0)
	p.main.sfx("burn", 1.0, -4.0)


# All your heat, released in one blow in front of you.
func _overheat(p) -> void:
	var main = p.main
	var heat: float = p.heat
	var dmg: float = (float(stat("damage")) + heat * 0.5) * power()
	var reach: float = stat("reach")
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + e.radius and absf(p.aim.angle_to(to)) <= deg_to_rad(65.0):
			e.take_hit(dmg, to.normalized(), 260.0, true)
			hits += 1
	p.heat = 0.0
	main.fx_cone(p.global_position, p.aim, reach + 10.0, deg_to_rad(65.0), color())
	main.fx_text(p.global_position + Vector2(0, -40), "Overheat! %d" % int(dmg), color())
	main.sfx("crit", 0.8)
	main.sfx("burn", 0.8)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.0 + heat / 60.0, 1.8, 0.4)
	main.shake(4.0 + heat / 15.0)
	main.hitstop(0.1)


# --- Rune Artist ----------------------------------------------------------------------

const MAX_RUNES := 3


func _trap(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * 50.0
	at = at.clamp(main.room.position + Vector2(20, 20), main.room.end - Vector2(20, 20))
	main.runes.append({"pos": at, "r": 22.0, "blast": stat("blast"), "damage": damage(), "linked": bool(stat("linked")), "color": color(), "t": 40.0})
	while main.runes.size() > MAX_RUNES:
		main.runes.pop_front()
	main.fx_ring(at, color(), 26.0, 0.3, 2.0)
	main.sfx("ready", 0.7, -4.0)


const GEAR_RUNES := ["sharpness", "warding", "swiftness"]
const GEAR_NAMES := {"sharpness": "Sharpness: strikes hit harder", "warding": "Warding: you take less damage", "swiftness": "Swiftness: you move faster"}


func _inscribe(p) -> void:
	var i := (GEAR_RUNES.find(p.rune_gear) + 1) % GEAR_RUNES.size()
	p.rune_gear = GEAR_RUNES[i]
	p.main.fx_text(p.global_position + Vector2(0, -40), GEAR_NAMES[p.rune_gear], color())
	p.main.fx_ring(p.global_position, color(), 24.0, 0.3, 2.0)
	p.main.sfx("ready", 1.1, -4.0)


func _ward(p) -> void:
	p.main.wards.append({"pos": p.global_position, "r": stat("radius"), "t": stat("duration"), "color": color()})
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.4, 4.0)
	p.main.sfx("parry", 0.6, -4.0)


func _sigil(p) -> void:
	p.main.sigils.append({"pos": p.global_position, "r": stat("radius"), "t": stat("duration"), "color": color()})
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.5, 5.0)
	p.main.light_flash(p.global_position, color(), 1.6, 2.0, 0.5)
	p.main.sfx("crit", 0.6, -4.0)
