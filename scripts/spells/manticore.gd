extends RefCounted
## The Manticore's tower (Stone and Fire): its bonds' fork alternatives, and
## the code that runs them. The content contract is at the top of
## library.gd; the worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Sandshaper
##     Step 2: Sand Wall (today's) or Sandblast: a cone of scouring sand that
##       stings the foes in front of you and blinds them.
##     Step 3: Ringed (today's change) or Aftershock (Echo): a second quake,
##       half as strong, shakes the same ground a second later.
##     Step 4: Sinkhole (today's) or Quicksand: a wide patch at your aim that
##       slows foes hard and grinds them down.
##   Venomist
##     Step 2: Toxic Cloud (today's) or Contagion: a foe you infect spreads
##       its poison to every foe that comes near it.
##     Step 3: Piercing (today's change) or Spray (Split): Venom Spit throws
##       three globs in a fan, each with half the poison.
##     Step 4: Neurotoxin (today's) or Enfeeble: every poisoned foe near you
##       hits softer and walks slower for a while.
##   Ashwalker
##     Step 2: Afterimage (today's) or Ash Step: you vanish in ash and step
##       out further along your aim; foes where you stood lose you.
##     Step 3: Igniting (today's change) or Billowing (Wide): a much wider
##       smoke cloud that lasts longer.
##     Step 4: Vanish (today's) or Cinder Trail: for a while your steps leave
##       burning ash behind you.
##
## What these spells leave in the world for a while is spell_fx.gd's shared
## lasting helper (_add below): it pauses with the fight and a new floor
## clears it. Enfeeble softens a foe through its dmg_mult (enemy.gd).

const FX := preload("res://scripts/spell_fx.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")

static var FORKS := {
	"sandshaper": {
		"change": {"name": "Ringed", "says": "Quake also throws up a ring of low walls"},
		2: {"id": "sandblast", "name": "Sandblast", "type": "sandblast", "learn": 2,
			"desc": "a blast of scouring sand in a cone in front of you stings every foe it catches and blinds them: they lose track of you",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "damage": 7.0, "reach": 125.0, "arc": 40.0, "blind": 2.5},
				4: {"damage": 9.0},
				5: {"damage": 11.0},
			}},
		3: {"id": "aftershock", "variation": "echo", "name": "Aftershock",
			"desc": "a second quake, half as strong, shakes the same ground a second later",
			"steps": {3: {"ring": false, "aftershock": 0.5, "delay": 1.0}}},
		4: {"id": "quicksand", "name": "Quicksand", "type": "quicksand", "learn": 4,
			"desc": "a wide patch of quicksand at your aim for 6 seconds: foes in it are slowed hard, drawn to its middle and ground down",
			"steps": {4: {"cost": 14.0, "windup": 0.4, "duration": 6.0, "radius": 78.0, "range": 140.0, "damage": 3.0}}},
	},
	"venomist": {
		"change": {"name": "Piercing", "says": "Venom Spit pierces"},
		2: {"id": "contagion", "name": "Contagion", "type": "contagion", "learn": 2,
			"desc": "infect the foe you aim at with 2 stacks of poison; for 6 seconds its poison spreads to every foe that comes near it",
			"steps": {2: {"cost": 10.0, "windup": 0.3, "stacks": 2, "duration": 6.0, "radius": 80.0, "range": 300.0}}},
		3: {"id": "spray", "variation": "split", "name": "Spray",
			"desc": "Venom Spit throws three globs in a fan, each half as hard but carrying 3 stacks of poison",
			"steps": {3: {"pierce": false, "copies": 3, "spray": 14.0, "stacks": 6}}},
		4: {"id": "enfeeble", "name": "Enfeeble", "type": "enfeeble", "learn": 4,
			"desc": "every poisoned foe near you is enfeebled for 6 seconds: it hits 40% softer and walks slower (a beast, half as much)",
			"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 6.0, "radius": 220.0, "weaken": 0.4}}},
	},
	"ashwalker": {
		"change": {"name": "Igniting", "says": "cast Smoke Veil again to ignite the cloud"},
		2: {"id": "ash_step", "name": "Ash Step", "type": "ash_step", "learn": 2,
			"desc": "you vanish in a puff of ash and step out further along your aim; foes near where you stood lose track of you",
			"steps": {2: {"cost": 9.0, "windup": 0.15, "distance": 135.0, "radius": 60.0, "duration": 2.5}}},
		3: {"id": "billowing", "variation": "wide", "name": "Billowing",
			"desc": "Smoke Veil's cloud is much wider and lasts 8 seconds",
			"steps": {3: {"ignite": false, "duration": 8.0}}},
		4: {"id": "cinder_trail", "name": "Cinder Trail", "type": "cinder_trail", "learn": 4,
			"desc": "for 5 seconds your steps leave burning ash behind you that burns the foes who cross it",
			"steps": {4: {"cost": 12.0, "windup": 0.2, "duration": 5.0, "embers": 2.5, "spacing": 24.0, "radius": 16.0}}},
	},
}

## Words these spells show in the world.
static var TEXT := {
	"no_target": "no target",
	"nothing_poisoned": "nothing poisoned",
	"blinded": "Blinded",
	"infected": "Infected",
	"enfeebled": "Enfeebled",
}

const SAND := Color(0.85, 0.72, 0.48)
const ASH := Color(0.55, 0.5, 0.5)


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"sandblast":
			_sandblast(bond, p)
		"quicksand":
			_quicksand(bond, p)
		"contagion":
			_contagion(bond, p)
		"enfeeble":
			_enfeeble(bond, p)
		"ash_step":
			_ash_step(bond, p)
		"cinder_trail":
			_cinder_trail(bond, p)
		_:
			return false
	return true


## The step-3 variations this file runs itself (Billowing is the library's
## own Wide: it returns false and the library casts it, a wider cloud).
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match String(alt.get("id", "")):
		"aftershock":
			if String(bond.id) != "sandshaper":
				return false
			_aftershock(bond, sp, p)
			return true
		"spray":
			if String(bond.id) != "venomist":
				return false
			_spray(bond, sp, p)
			return true
	return false


# --- Sandshaper ---------------------------------------------------------------------------

## Sandblast: every foe within `reach` and `arc` degrees of your aim is
## stung and staggered a moment, then loses track of you for `blind` seconds
## (a beast never loses you: it's only stung).
static func _sandblast(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var reach := float(bond.stat("reach"))
	var half := deg_to_rad(float(bond.stat("arc")))
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() <= reach + e.radius and absf(aim.angle_to(to)) <= half:
			e.take_hit(bond.damage(), to.normalized(), 110.0)
			if not e.dead:
				e.stagger(0.25)
				e.lose_track(float(bond.stat("blind")), null)
				if not e.is_boss():
					main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["blinded"], SAND)
	main.fx_cone(origin, aim, reach, half, col)
	var paint := func(b, it: Dictionary):
		var age: float = it["age"]
		var k := clampf(age / 0.45, 0.0, 1.0)
		for i in 28:  # grains flung out across the cone (fixed paths: no flicker)
			var u := fmod(i * 0.618, 1.0)
			var a := aim.angle() + (u * 2.0 - 1.0) * half
			var spd := 0.55 + 0.45 * fmod(i * 0.377, 1.0)
			var at := origin + Vector2.from_angle(a) * reach * minf(1.0, k * spd * 1.6) * (0.25 + 0.75 * spd)
			b.circle(at, 1.2 + fmod(i * 0.71, 1.4), Color(SAND.lightened(0.1 * (i % 3)), 0.85 * (1.0 - k)), 8)
		b.circle(origin + aim * reach * 0.5 * k, reach * 0.35 * (0.5 + k), Color(SAND, 0.12 * (1.0 - k)))
	_add(main, 0.45, Callable(), paint, true)
	main.sfx("gust", 0.8, -2.0)
	main.sfx("hit_light", 0.7, -4.0)
	main.light_flash(origin + aim * 40.0, col, 1.0, 0.8, 0.25)


## Aftershock: Quake as it is (without Ringed), and a second quake on the
## same ground `delay` later at `aftershock` of its strength (no rubble).
static func _aftershock(bond, sp: Dictionary, p) -> void:
	bond._cast_type(p)
	var main = p.main
	var col: Color = bond.color()
	var at: Vector2 = p.global_position
	var r := float(bond.spell_stat(sp, "radius"))
	var delay := float(bond.spell_stat(sp, "delay"))
	var dmg: float = bond.spell_damage(sp) * float(bond.spell_stat(sp, "aftershock"))
	FX.mark(main, at, delay, col)
	var paint := func(b, it: Dictionary):
		var k := clampf(float(it["age"]) / delay, 0.0, 1.0)
		var fade := clampf(float(it["t"]) / 0.4, 0.0, 1.0)
		for i in 7:  # cracks running out from where the quake struck
			var a := TAU * i / 7.0 + 0.4
			var mid := at + Vector2.from_angle(a + 0.15) * r * 0.45 * k
			var end := at + Vector2.from_angle(a - 0.1) * r * 0.85 * k
			b.line(at, mid, Color(0.12, 0.09, 0.06, 0.7 * fade), 2.5)
			b.line(mid, end, Color(0.12, 0.09, 0.06, 0.6 * fade), 1.8)
			b.line(mid, end + Vector2(0, -1), Color(SAND, 0.35 * fade), 1.0)
	_add(main, delay + 0.4, Callable(), paint, false)
	FX.later(main, delay, func():
		for e in main.targets():
			var to: Vector2 = e.global_position - at
			if to.length() < r + e.radius:
				e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.ZERO, 120.0, true)
				if not e.dead and not e.is_boss():
					e.stagger(0.3)
		main.fx_ring(at, col, r, 0.4, 5.0)
		main.fx_burst(at, Vector2.ZERO, col, 14, 220.0)
		main.sfx("slam", 1.05, -3.0)
		main.shake(5.0))


## Quicksand: a patch at your aim (short of a wall) for `duration` seconds.
## Foes in it walk at half speed and slower still (rubble and a chill), are
## drawn toward its middle, and take `damage` every half second.
static func _quicksand(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var r := float(bond.stat("radius"))
	var dur := float(bond.stat("duration"))
	var center: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(bond.stat("range")), 14.0)
	var dmg: float = bond.damage()
	main.rubble.append({"pos": center, "r": r, "t": dur})  # (rubble slows what walks in it: main.rubble_slow)
	var st := {"tick": 0.5}
	var tick := func(_it: Dictionary, delta: float):
		st["tick"] -= delta
		var bite := false
		if st["tick"] <= 0.0:
			st["tick"] = 0.5
			bite = true
		for e in main.targets():
			var to: Vector2 = center - e.global_position
			if to.length() > r + e.radius * 0.5:
				continue
			e.chill_t = maxf(e.chill_t, 0.3)
			if not e.is_boss() and to.length() > 6.0:
				e.move_and_collide(to.normalized() * 22.0 * delta)
			if bite:
				e.take_hit(dmg, Vector2.ZERO, 0.0)
	var paint := func(b, it: Dictionary):
		var age: float = it["age"]
		var a := clampf(age / 0.3, 0.0, 1.0) * clampf(float(it["t"]) / 0.6, 0.0, 1.0)
		b.circle(center, r, Color(SAND.darkened(0.45), 0.35 * a))
		b.circle(center, r * 0.55, Color(SAND.darkened(0.6), 0.3 * a))
		for k in 4:  # the sand turning in toward the middle
			var rr := r * (0.25 + 0.2 * k)
			var s := age * (1.6 - k * 0.25) + k * 1.3
			b.arc(center, rr, s, s + 2.4, 16, Color(SAND, (0.25 + 0.1 * k) * a), 2.0)
		b.arc(center, r, 0.0, TAU, 40, Color(col, 0.55 * a), 2.0)
	_add(main, dur, tick, paint, false)
	main.fx_burst(center, Vector2.ZERO, SAND, 16, 180.0)
	main.sfx("slam", 0.6, -4.0)
	main.sfx("gust", 0.5, -4.0)
	main.shake(3.0)


# --- Venomist ---------------------------------------------------------------------------

## Contagion: the foe nearest your aim takes `stacks` of poison; for
## `duration` seconds every other foe within `radius` of it takes a stack
## every half second. If it dies first, its poison bursts onto the foes near it.
static func _contagion(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var target = _aimed(p, float(bond.stat("range")))
	if target == null:
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["no_target"], col)
		return
	target.add_venom(int(bond.stat("stacks")))
	var r := float(bond.stat("radius"))
	var st := {"pos": target.global_position, "tick": 0.5}
	var tick := func(it: Dictionary, delta: float):
		var dead: bool = not is_instance_valid(target) or target.dead
		if not dead:
			st["pos"] = target.global_position
		st["tick"] -= delta
		if st["tick"] > 0.0 and not dead:
			return
		st["tick"] = 0.5
		for e in main.targets():
			if e != target and e.global_position.distance_to(st["pos"]) <= r + e.radius:
				e.add_venom(1)
		if dead:
			it["done"] = true
			main.fx_burst(st["pos"], Vector2.ZERO, col, 16, 200.0)
			main.sfx("hit_slime", 0.8, -2.0)
	var from: Vector2 = p.global_position
	var paint := func(b, it: Dictionary):
		var age: float = it["age"]
		var at: Vector2 = st["pos"]
		var a := clampf(age / 0.2, 0.0, 1.0) * clampf(float(it["t"]) / 0.6, 0.0, 1.0)
		if age < 0.18:  # the glob flying to it
			b.circle(from.lerp(at, age / 0.18), 4.5, Color(col, 0.95), 12)
		b.circle(at, r, Color(col, 0.06 * a))
		b.arc(at, r, age * 0.8, age * 0.8 + TAU, 36, Color(col, 0.3 * a), 1.5)
		for i in 6:  # drops of venom circling it, and falling off it
			var ang := age * 2.2 + TAU * i / 6.0
			var dp := at + Vector2.from_angle(ang) * r * (0.45 + 0.35 * fmod(age * 0.7 + i * 0.29, 1.0))
			b.circle(dp, 2.2, Color(col.lightened(0.25), 0.8 * a), 10)
		var drip := fmod(age * 1.3, 1.0)
		b.circle(at + Vector2(-5, -10 + 18.0 * drip), 2.0, Color(col, 0.8 * a * (1.0 - drip)), 10)
	_add(main, float(bond.stat("duration")), tick, paint, true)
	main.fx_text(target.global_position + Vector2(0, -target.radius - 26.0), TEXT["infected"], col)
	main.sfx("hit_slime", 1.1, -3.0)
	main.sfx("hiss", 1.2, -8.0)


## Spray: three globs of Venom Spit in a fan `spray` degrees apart, each half
## as hard and carrying half the stacks (rounded up). It doesn't pierce.
static func _spray(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var stacks := maxi(1, int(ceil(float(bond.spell_stat(sp, "stacks")) * 0.5)))
	var dmg: float = bond.spell_damage(sp) * 0.5
	var spread := deg_to_rad(float(bond.spell_stat(sp, "spray")))
	var copies := maxi(1, int(bond.spell_stat(sp, "copies")))
	for i in copies:
		var dir: Vector2 = p.aim.rotated(spread * (float(i) - float(copies - 1) * 0.5))
		var b = main.spawn_player_arrow(p.global_position + dir * (p.radius + 6.0), dir * 520.0, dmg, 60.0, false)
		b.style = "venom"
		b.tint = col
		b.venom = stacks
	main.sfx("hit_slime", 1.5, -4.0)
	if bond.overdraw_mult < 1.0:
		p.poison(1.5)  # (an overdrawn spit poisons you briefly, as Venom Spit does)


## Enfeeble: every poisoned foe within `radius` hits `weaken` softer (a beast
## half as much) and walks slower for `duration` seconds. Casting it again on
## an enfeebled foe only makes it last longer.
static func _enfeeble(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var r := float(bond.stat("radius"))
	var dur := float(bond.stat("duration"))
	var weaken := float(bond.stat("weaken"))
	var n := 0
	for e in main.targets():
		if e.venom <= 0 or e.global_position.distance_to(p.global_position) > r + e.radius:
			continue
		n += 1
		main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), TEXT["enfeebled"], col)
		var had = e.get_meta("enfeebled") if e.has_meta("enfeebled") else null
		if had is Dictionary and float(had["t"]) > 0.0 and not had["done"]:
			had["t"] = maxf(float(had["t"]), dur)
			continue
		var k := weaken * (0.5 if e.is_boss() else 1.0)
		var foe = e
		foe.dmg_mult *= 1.0 - k  # (enemy.gd: its blows, softened)
		var tick := func(it: Dictionary, _delta: float):
			if not is_instance_valid(foe) or foe.dead:
				it["done"] = true
				return
			foe.chill_t = maxf(foe.chill_t, 0.3)
			if float(it["t"]) <= 0.05:  # (wearing off: its strength comes back)
				it["done"] = true
				foe.dmg_mult /= 1.0 - k
				foe.remove_meta("enfeebled")
		var paint := func(b, it: Dictionary):
			if not is_instance_valid(foe):
				return
			var age: float = it["age"]
			var at: Vector2 = foe.global_position
			var a := clampf(age / 0.2, 0.0, 1.0) * clampf(float(it["t"]) / 0.5, 0.0, 1.0)
			var rr: float = foe.radius
			b.arc(at + Vector2(0, rr * 0.6), rr + 4.0, 0.2, PI - 0.2, 14, Color(col.darkened(0.2), 0.6 * a), 2.0)
			for i in 3:  # wilting wisps drooping off it
				var x := (float(i) - 1.0) * rr * 0.6
				var u := fmod(age * 0.9 + i * 0.33, 1.0)
				var top := at + Vector2(x, -rr - 10.0 + 14.0 * u)
				b.line(top, top + Vector2(0, 5), Color(col, 0.75 * a * (1.0 - u)), 2.0)
				b.circle(top + Vector2(0, 6), 1.6, Color(col.lightened(0.2), 0.8 * a * (1.0 - u)), 8)
		var it := _add(main, dur, tick, paint, true)
		foe.set_meta("enfeebled", it)
	if n == 0:
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["nothing_poisoned"], col)
	main.fx_ring(p.global_position, col, r, 0.45, 2.5)
	main.sfx("hiss", 0.8, -2.0)
	main.light_flash(p.global_position, col, 1.2, 1.0, 0.3)


# --- Ashwalker --------------------------------------------------------------------------

## Ash Step: you step `distance` along your aim at once (short of a wall),
## untouchable for a moment; a smoke cloud of `radius` stays where you stood
## for `duration` seconds, and the foes near it lose track of you at once.
static func _ash_step(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var from: Vector2 = p.global_position
	var to: Vector2 = main.walkable_point(from, from + p.aim * float(bond.stat("distance")), 14.0)
	var r := float(bond.stat("radius"))
	main.fx_ghost(from, p.radius, ASH)
	p.global_position = to
	p.iframes = maxf(p.iframes, 0.25)
	main.smokes.append({"pos": from, "r": r, "t": float(bond.stat("duration"))})
	for e in main.enemies():
		if e.global_position.distance_to(from) < r + 60.0:
			e.lose_track(1.5, null)
	main.fx_burst(from, Vector2.ZERO, ASH, 14, 160.0)
	main.fx_burst(to, Vector2.ZERO, ASH, 8, 120.0)
	var paint := func(b, it: Dictionary):
		var k := clampf(float(it["t"]) / 0.5, 0.0, 1.0)
		var d := to - from
		for i in 10:  # cinders hanging where you passed, drifting up
			var u := (float(i) + 0.5) / 10.0
			var at := from + d * u + d.orthogonal().normalized() * sin(i * 2.7) * 5.0 + Vector2(0, -12.0 * (1.0 - k) * (0.5 + u))
			b.circle(at, 1.6, Color(1.0, 0.55, 0.25, 0.8 * k), 8)
			b.circle(at + Vector2(3, 2), 2.2, Color(ASH, 0.5 * k), 8)
		b.circle(to, 14.0 * (1.0 - k) + 6.0, Color(col, 0.2 * k))
	_add(main, 0.5, Callable(), paint, true)
	main.sfx("dodge", 1.0, -2.0)
	main.sfx("gust", 1.4, -4.0)
	if bond.overdraw_mult < 1.0:
		p.poison(1.0)  # (an overdrawn step chokes you, as an overdrawn veil does)


## Cinder Trail: for `duration` seconds, every `spacing` you move leaves a
## patch of your own fire (`radius`, burning `embers` seconds) that burns the
## foes who walk into it, never you.
static func _cinder_trail(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var spacing := float(bond.stat("spacing"))
	var r := float(bond.stat("radius"))
	var life := float(bond.stat("embers"))
	var st := {"last": p.global_position}
	main.add_flame(p.global_position, r, life, true)
	var tick := func(it: Dictionary, _delta: float):
		if not is_instance_valid(p) or p.dead:
			it["done"] = true
			return
		if p.global_position.distance_to(st["last"]) >= spacing:
			st["last"] = p.global_position
			main.add_flame(p.global_position, r, life, true)
	var paint := func(b, it: Dictionary):
		if not is_instance_valid(p):
			return
		var age: float = it["age"]
		var a := clampf(age / 0.2, 0.0, 1.0) * clampf(float(it["t"]) / 0.4, 0.0, 1.0)
		var feet: Vector2 = p.global_position + Vector2(0, p.radius * 0.6)
		for i in 6:  # embers rising off your heels
			var u := fmod(age * 1.4 + i * 0.17, 1.0)
			var at := feet + Vector2(sin(i * 2.1 + age * 3.0) * 9.0, -22.0 * u)
			b.circle(at, 1.8 * (1.0 - u) + 0.6, Color(1.0, 0.6 - 0.2 * u, 0.2, 0.9 * a * (1.0 - u)), 8)
		b.circle(feet, 10.0, Color(col, 0.18 * a))
	_add(main, float(bond.stat("duration")), tick, paint, true)
	main.sfx("burn", 1.4, -2.0)
	main.light_flash(p.global_position, col, 1.0, 1.0, 0.3)


# --- helpers ------------------------------------------------------------------------------

## The foe nearest where you aim, within reach (or null), as bond.gd picks one.
static func _aimed(p, reach: float):
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


## Something this file left in the world: `tick(item, delta)` each frame and
## `paint(batch, item)` each draw (either may be an empty Callable), for
## `seconds` or until item.done. `high` draws it over the darkness. (The
## shared helper, spell_fx.gd item(): it pauses with the fight and a new
## floor clears it.)
static func _add(main, seconds: float, tick: Callable, paint: Callable, high := false) -> Dictionary:
	return FX.item(main, seconds, tick, paint, high)
