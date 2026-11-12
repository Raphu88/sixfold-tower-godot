extends RefCounted
## The Manticore's tower (Stone and Fire): its bonds' fork alternatives, and
## the code that runs them. The content contract is at the top of
## library.gd; the worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Sandshaper
##     Step 2: Sand Wall (today's) or Sandblast: a cone of scouring sand that
##       stings the foes in front of you and blinds them.
##     Step 3, two Transformations of Quake: Shatter (side A, bonds.gd's step
##       3) or Upheaval (side B, the "aftershock" choice).
##     Step 4: Sinkhole (today's) or Quicksand: a wide patch at your aim that
##       slows foes hard and grinds them down.
##     Shifting Sands II: slowed foes can't dodge or block. III: standing
##       still a second hardens your skin. Apex: Fault Line buries and crushes.
##   Venomist
##     Step 2: Toxic Cloud (today's) or Contagion: a foe you infect spreads
##       its poison to every foe that comes near it.
##     Step 3: Corrosive (side A) or Bloom (side B, "spray").
##     Step 4: Neurotoxin (today's) or Enfeeble: every poisoned foe near you
##       hits softer and walks slower for a while.
##     Toxin Build II: a poisoned foe that dies passes its poison on. III: a
##       foe at 8 stacks is staggered. Apex: Virulence refills your mark.
##   Ashwalker
##     Step 2: Afterimage (today's) or Ash Step: you vanish in ash and step
##       out further along your aim; foes where you stood lose you.
##     Step 3: Ember Smoke (side A) or Shroud Walk (side B, "billowing").
##     Step 4: Vanish (today's) or Cinder Trail: for a while your steps leave
##       burning ash behind you.
##     Unseen Strike II: it staggers too. III: a kill while unseen hides you
##       again a moment. Apex: during Ashfall an unseen strike leaps on.
##
## The step-3 choices keep their old ids (a save that chose today's change
## gets side A; one that chose the other side gets side B). Side A's numbers
## are the first spell's step 3 in bonds.gd; side B's are FORKS[bond][3].
##
## What these spells leave in the world for a while is spell_fx.gd's shared
## lasting helper (_add below): it pauses with the fight and a new floor
## clears it. Enfeeble softens a foe through its dmg_mult (enemy.gd).

const FX := preload("res://scripts/spell_fx.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const Reactions := preload("res://scripts/reactions.gd")

static var FORKS := {
	"sandshaper": {
		"change": {"name": "Shatter", "says": "the quake leaves sharp shards that cut foes walking over them"},
		2: {"id": "sandblast", "name": "Sandblast", "type": "sandblast", "learn": 2,
			"desc": "a blast of scouring sand in a cone in front of you stings every foe it catches and blinds them: they lose track of you",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "damage": 7.0, "reach": 125.0, "arc": 40.0, "blind": 2.5},
				4: {"damage": 9.0},
				5: {"damage": 11.0},
			}},
		3: {"id": "aftershock", "name": "Upheaval",
			"desc": "the quake throws every foe it strikes into the air, helpless (a beast is only rocked)",
			"steps": {3: {"shards": 0.0, "upheaval": 1.6}}},
		4: {"id": "quicksand", "name": "Quicksand", "type": "quicksand", "learn": 4,
			"desc": "a wide patch of quicksand at your aim for 6 seconds: foes in it are slowed hard, drawn to its middle and ground down",
			"steps": {4: {"cost": 14.0, "windup": 0.4, "duration": 6.0, "radius": 78.0, "range": 140.0, "damage": 3.0}}},
	},
	"venomist": {
		"change": {"name": "Corrosive", "says": "the spit still pierces, your poison strips shells and guards, and poisoned foes take 25% more from blows"},
		2: {"id": "contagion", "name": "Contagion", "type": "contagion", "learn": 2,
			"desc": "infect the foe you aim at with 2 stacks of poison; for 6 seconds its poison spreads to every foe that comes near it",
			"steps": {2: {"cost": 10.0, "windup": 0.3, "stacks": 2, "duration": 6.0, "radius": 80.0, "range": 300.0}}},
		3: {"id": "spray", "name": "Bloom",
			"desc": "Venom Spit bursts into a small cloud of poison where it lands, for 2.5 seconds",
			"steps": {3: {"corrode": 0.0, "pierce": false, "bloom": 2.5, "bloom_radius": 45.0}}},
		4: {"id": "enfeeble", "name": "Enfeeble", "type": "enfeeble", "learn": 4,
			"desc": "every poisoned foe near you is enfeebled for 6 seconds: it hits 40% softer and walks slower (a beast, half as much)",
			"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 6.0, "radius": 220.0, "weaken": 0.4}}},
	},
	"ashwalker": {
		"change": {"name": "Ember Smoke", "says": "the smoke burns the foes inside it"},
		2: {"id": "ash_step", "name": "Ash Step", "type": "ash_step", "learn": 2,
			"desc": "you vanish in a puff of ash and step out further along your aim; foes near where you stood lose track of you",
			"steps": {2: {"cost": 9.0, "windup": 0.15, "distance": 135.0, "radius": 60.0, "duration": 2.5}}},
		3: {"id": "billowing", "name": "Shroud Walk",
			"desc": "Smoke Veil's cloud moves with you for its first 3 seconds",
			"steps": {3: {"embers": false, "follow": 3.0}}},
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
	"buried": "Buried",
	"seized": "Seized",
	"hidden": "Hidden",
	"off_balance": "Staggered",
	"refilled": "+%d essence",
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


## The step-3 Transformations' side B: the first spell cast as it is, its
## numbers (FORKS[bond][3] steps) doing the rest (bond.gd reads them).
static func cast_variation(bond, _sp: Dictionary, p, alt: Dictionary) -> bool:
	match String(alt.get("id", "")):
		"aftershock", "spray", "billowing":
			if not String(bond.id) in ["sandshaper", "venomist", "ashwalker"]:
				return false
			bond._cast_type(p)
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
	main.sfx("spell_sand")
	main.sfx("hit_light", 0.7, -4.0)
	main.light_flash(origin + aim * 40.0, col, 1.0, 0.8, 0.25)


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
	main.sfx("spell_stone", 0.7)
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
	main.sfx("spell_poison")
	main.sfx("hiss", 1.2, -8.0)


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
	main.sfx("spell_poison", 0.8)
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
	main.sfx("spell_fire", 1.3, -2.0)
	main.light_flash(p.global_position, col, 1.0, 1.0, 0.3)


# --- marks' growth: Transformations, passive ranks and Apexes ----------------------------
# (bond.gd, player.gd, enemy.gd and main.gd call these; each does nothing
# unless its mark has grown to it.)

## The climber's bond with this id (null if none).
static func _held(p, bond_id: String):
	if p == null or not is_instance_valid(p) or not ("bonds" in p):
		return null
	for b in p.bonds.values():
		if String(b.id) == bond_id and b.has_method("passive_rank"):
			return b
	return null


static func _rank(p, bond_id: String) -> int:
	var b = _held(p, bond_id)
	return b.passive_rank() if b != null else 0


## A number of the bond's first spell at its step (its step-3 Transformation's, if chosen).
static func _first(bond, key: String, fallback = 0.0):
	var v = bond.spell_stat(bond.data()["spells"][0], key)
	return v if v != null else fallback


static func _player(main):
	if main == null or not is_instance_valid(main) or not ("player" in main):
		return null
	var p = main.player
	return p if p != null and is_instance_valid(p) else null


## Upheaval (side B): a foe the quake strikes is thrown into the air for
## `upheaval` seconds (a beast is too heavy: it's only rocked).
static func upheave(bond, e) -> void:
	var t = bond.stat("upheaval")
	if t == null or float(t) <= 0.0 or not is_instance_valid(e) or e.dead:
		return
	if e.is_boss():
		e.stagger(0.3)
		return
	Reactions.apply(e.main, e, "airborne", float(t), bond)


## Shatter (side A): the quake leaves sharp shards over its ground for
## `shards` seconds; a foe walking over them is cut for `shard_damage` of
## the quake's damage, at most once every `shard_every` seconds.
static func shatter(bond, p, at: Vector2, r: float) -> void:
	var secs = bond.stat("shards")
	if secs == null or float(secs) <= 0.0:
		return
	var main = p.main
	var dmg: float = bond.damage() * float(bond.stat("shard_damage"))
	var every := float(bond.stat("shard_every"))
	var st := {"tick": 0.0, "last": {}, "next": {}}
	var tick := func(it: Dictionary, delta: float):
		st["tick"] -= delta
		if st["tick"] > 0.0:
			return
		st["tick"] = 0.25
		var last: Dictionary = st["last"]
		var nxt: Dictionary = st["next"]
		var now := {}
		for e in main.targets():
			if e.global_position.distance_to(at) > r + e.radius * 0.5:
				continue
			now[e] = e.global_position
			var moved: bool = e.velocity.length() > 8.0 or (last.has(e) and Vector2(last[e]).distance_to(e.global_position) > 2.0)
			if moved and float(it["age"]) >= float(nxt.get(e, 0.0)):
				nxt[e] = float(it["age"]) + every
				e.take_hit(dmg, Vector2.ZERO, 0.0)
				main.fx_burst(e.global_position + Vector2(0, e.radius * 0.6), Vector2.UP, SAND, 5, 120.0)
		st["last"] = now
	var paint := func(b, it: Dictionary):
		var a := clampf(float(it["age"]) / 0.25, 0.0, 1.0) * clampf(float(it["t"]) / 0.6, 0.0, 1.0)
		for i in 22:  # shards of stone standing up out of the ground (fixed places: no flicker)
			var u := fmod(i * 0.618, 1.0)
			var v := sqrt(fmod(i * 0.377 + 0.13, 1.0))
			var pt := at + Vector2.from_angle(TAU * u) * r * 0.92 * v
			var h := 5.0 + fmod(i * 0.71, 1.0) * 5.0
			var lean := (fmod(i * 0.29, 1.0) - 0.5) * 4.0
			b.polygon(PackedVector2Array([pt + Vector2(-2.6, 0), pt + Vector2(2.6, 0), pt + Vector2(lean, -h)]), Color(SAND.darkened(0.25), 0.9 * a))
			b.line(pt + Vector2(0.8, -0.5), pt + Vector2(lean * 0.8 + 0.4, -h + 1.0), Color(SAND.lightened(0.3), 0.7 * a), 1.0)
	_add(main, float(secs), tick, paint, false)


## Fault Line's Apex: every foe on the line as it splits is buried (stunned
## `bury` seconds, a beast half as long) and crushed (the spell's damage).
static func bury(bond, p, center: Vector2) -> void:
	var t = bond.stat("bury")
	if t == null or float(t) <= 0.0:
		return
	var main = p.main
	var half: Vector2 = p.aim.orthogonal() * float(bond.stat("length")) * 0.5
	var a := center - half
	var z := center + half
	var w := float(bond.stat("bury_width"))
	var dmg: float = bond.damage()
	for e in main.targets():
		var c := Geometry2D.get_closest_point_to_segment(e.global_position, a, z)
		if c.distance_to(e.global_position) > w + e.radius:
			continue
		e.take_hit(dmg, Vector2.ZERO, 0.0, true)
		if not is_instance_valid(e) or e.dead:
			continue
		e.stagger(float(t) * (0.5 if e.is_boss() else 1.0))
		main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), TEXT["buried"], SAND)
		var foe = e
		var paint := func(b, it: Dictionary):
			if not is_instance_valid(foe):
				return
			var k := clampf(float(it["age"]) / 0.2, 0.0, 1.0) * clampf(float(it["t"]) / 0.4, 0.0, 1.0)
			var at: Vector2 = foe.global_position + Vector2(0, foe.radius * 0.3)
			b.circle(at, foe.radius + 6.0, Color(SAND.darkened(0.5), 0.55 * k))
			for i in 7:  # earth heaped over it
				var ang := PI + PI * float(i) / 6.0
				b.circle(at + Vector2.from_angle(ang) * (foe.radius + 2.0) * Vector2(1.0, 0.5), 5.0, Color(SAND.darkened(0.2), 0.85 * k), 10)
		_add(main, float(t) * (0.5 if e.is_boss() else 1.0), Callable(), paint, true)


## Shifting Sands II: a foe it counts as slowed (the slowed state, your rubble,
## or Shifting Sands' last steps: enemy.gd's 110).
static func slowed(main, e) -> bool:
	if Reactions.has(e, "slowed") or main.rubble_slow(e.global_position) < 1.0:
		return true
	var p = _player(main)
	return p != null and p.has_bond("sandshaper") and e.global_position.distance_to(p.global_position) < 110.0


## Corrosive's strength (0 unless the Venomist chose it).
static func _corrode(main) -> float:
	var b = _held(_player(main), "venomist")
	if b == null or b.step < 3:
		return 0.0
	return float(_first(b, "corrode", 0.0))


## A blow on `e` ignores its shell or guard: Corrosive poison (side A), or
## Shifting Sands II on a slowed foe (enemy.gd take_hit).
static func strips_guard(main, e) -> bool:
	var p = _player(main)
	if p == null or e.dead:
		return false
	if e.venom > 0 and _corrode(main) > 0.0:
		return true
	return _rank(p, "sandshaper") >= 2 and slowed(main, e)


## Corrosive: a poisoned foe takes `corrode` more from blows (1 for any other).
static func blow_mult(main, e) -> float:
	if e.venom <= 0:
		return 1.0
	return 1.0 + _corrode(main)


## Bloom (side B): the spit bursts into a small cloud of poison where it lands
## (a Toxic Cloud of `bloom_radius` for `bloom` seconds).
static func bloom(bond, shot) -> void:
	var t = bond.stat("bloom")
	if t == null or float(t) <= 0.0:
		return
	var main = shot.main
	var r := float(bond.stat("bloom_radius"))
	var col: Color = bond.color()
	shot.on_end.append(func(_s, at: Vector2):
		main.clouds.append({"pos": at, "r": r, "t": float(t), "tick": 0.0, "color": col})
		main.fx_burst(at, Vector2.ZERO, col, 12, 170.0)
		main.fx_ring(at, col, r, 0.3, 2.0)
		main.sfx("hit_slime", 0.85, -4.0))


## Toxin Build II: a poisoned foe that dies passes `pass` of its stacks
## (at least one) to each foe within `pass_radius` (main.gd on_enemy_killed).
static func on_killed(main, e) -> void:
	if e.venom <= 0:
		return
	var b = _held(_player(main), "venomist")
	if b == null or b.passive_rank() < 2:
		return
	var n := maxi(1, int(ceil(float(e.venom) * b.passive_num("pass", 0.5))))
	var r: float = b.passive_num("pass_radius", 90.0)
	for o in main.targets():
		if o == e or o.dead:
			continue
		if o.global_position.distance_to(e.global_position) <= r + o.radius:
			o.add_venom(n)
			main.fx_bolt([e.global_position, o.global_position], b.color())


## Toxin Build III: a foe at `stagger_at` stacks or more is staggered (a
## beast half as long), at most once every `again` seconds (enemy.gd add_venom).
static func on_venom(main, e) -> void:
	if e.dead or e.venom < 2:
		return
	var b = _held(_player(main), "venomist")
	if b == null or b.passive_rank() < 3 or e.venom < int(b.passive_num("stagger_at", 8.0)):
		return
	var now := Time.get_ticks_msec()
	if now < int(e.get_meta("toxin_stagger", 0)):
		return
	e.set_meta("toxin_stagger", now + int(b.passive_num("again", 4.0) * 1000.0))
	e.stagger(b.passive_num("stagger", 0.8) * (0.5 if e.is_boss() else 1.0))
	main.fx_text(e.global_position + Vector2(0, -e.radius - 30.0), TEXT["seized"], b.color())


## Virulence's Apex: each foe it burst refills the mark with `refill` of a
## Venom Spit's essence (up to the mark's capacity).
static func refill(bond, p, n: int) -> void:
	var k = bond.stat("refill")
	if k == null or float(k) <= 0.0 or n <= 0:
		return
	var add: float = bond.spell_cost(bond.data()["spells"][0]) * float(k) * n
	bond.essence = minf(bond.capacity(), bond.essence + add)
	p.main.fx_text(p.global_position + Vector2(0, -52), TEXT["refilled"] % int(round(add)), bond.color())


## Smoke Veil's step 3: Ember Smoke (side A: the smoke burns the foes in it,
## `damage` every half second) or Shroud Walk (side B: it moves with you
## for `follow` seconds).
static func veil(bond, p, sm: Dictionary) -> void:
	var main = p.main
	if bool(bond.stat("embers")):
		var dmg: float = bond.damage()
		var st := {"tick": 0.0}
		var tick := func(it: Dictionary, delta: float):
			if not main.smokes.any(func(x): return is_same(x, sm)):
				it["done"] = true
				return
			st["tick"] -= delta
			if st["tick"] > 0.0:
				return
			st["tick"] = 0.5
			for e in main.targets():
				if e.global_position.distance_to(sm["pos"]) < float(sm["r"]) + e.radius:
					Reactions.apply(main, e, "burning", 1.0, bond, dmg)
		var paint := func(b, it: Dictionary):
			var age: float = it["age"]
			var a := clampf(age / 0.4, 0.0, 1.0) * clampf(float(it["t"]) / 0.6, 0.0, 1.0)
			var c: Vector2 = sm["pos"]
			var r := float(sm["r"])
			for i in 14:  # embers drifting up through the smoke
				var u := fmod(i * 0.618, 1.0)
				var rise := fmod(age * (0.35 + 0.2 * fmod(i * 0.37, 1.0)) + u, 1.0)
				var pt := c + Vector2(cos(TAU * u) * r * 0.8 * sqrt(fmod(i * 0.41 + 0.2, 1.0)), sin(TAU * u) * r * 0.5) + Vector2(sin(age * 2.0 + i) * 4.0, -24.0 * rise)
				b.circle(pt, 1.4 + 0.8 * (1.0 - rise), Color(1.0, 0.55 + 0.3 * rise, 0.2, 0.85 * a * (1.0 - rise)), 8)
		_add(main, float(sm["t"]) + 0.5, tick, paint, true)
	var f = bond.stat("follow")
	if f != null and float(f) > 0.0:
		var walk := func(it: Dictionary, _delta: float):
			if not is_instance_valid(p) or p.dead or not main.smokes.any(func(x): return is_same(x, sm)):
				it["done"] = true
				return
			sm["pos"] = p.global_position
		_add(main, float(f), walk, Callable(), false)


## Unseen Strike's ranks and Ashfall's Apex, after an unseen strike landed
## (player.gd _strike): II staggers the foe (knocked off balance for
## `stagger` seconds, its attack broken; not the stun a riposte needs); III
## hides you a moment if it died; while Ashfall falls, the strike leaps to
## the nearest other foe within `leap` for `leap_share` of its damage.
static func unseen_struck(p, e, dmg: float, dir: Vector2) -> void:
	var b = _held(p, "ashwalker")
	if b == null:
		return
	var main = p.main
	var rank: int = b.passive_rank()
	var alive: bool = is_instance_valid(e) and not e.dead
	if rank >= 2 and alive and not e.is_boss():
		e.flinch = maxf(e.flinch, b.passive_num("stagger", 0.6))
		if e.is_attacking():
			e.aim_dir = Vector2.ZERO
			e._end_attack(e._idle_state(), 0.6)
		main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["off_balance"], b.color())
	if rank >= 3 and not alive:
		p.vanish_t = maxf(p.vanish_t, b.passive_num("hide", 1.5))
		main.fx_burst(p.global_position, Vector2.ZERO, ASH, 12, 160.0)
		main.fx_text(p.global_position + Vector2(0, -44), TEXT["hidden"], b.color())
	if main.ashfall_t <= 0.0:
		return
	var leap := 0.0
	var share := 0.0
	for sp in b.spells():
		if String(sp.get("type", "")) == "ashfall" and b.spell_stat(sp, "leap") != null:
			leap = float(b.spell_stat(sp, "leap"))
			share = float(b.spell_stat(sp, "leap_share"))
	if leap <= 0.0:
		return
	var from: Vector2 = e.global_position if is_instance_valid(e) else p.global_position
	var best = null
	var bd := leap
	for o in main.targets():
		if o == e or o.dead:
			continue
		var d: float = o.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = o
	if best == null:
		return
	var to: Vector2 = best.global_position
	best.take_hit(dmg * share, (to - from).normalized() if to.distance_to(from) > 0.1 else dir, 140.0, true)
	var paint := func(bb, it: Dictionary):
		var k := clampf(float(it["t"]) / 0.35, 0.0, 1.0)
		bb.line(from, to, Color(ASH, 0.5 * k), 7.0)
		bb.line(from, to, Color(1.0, 0.6, 0.3, 0.8 * k), 2.0)
		for i in 6:  # cinders along the leap
			bb.circle(from.lerp(to, (float(i) + 0.5) / 6.0) + Vector2(0, -8.0 * (1.0 - k)), 1.8, Color(1.0, 0.65, 0.3, k), 8)
	_add(main, 0.35, Callable(), paint, true)
	main.fx_burst(to, Vector2.ZERO, ASH, 10, 180.0)
	main.sfx("hit_stab", 1.1, -4.0)


## Shifting Sands III: standing still `still` seconds hardens your skin, so
## blows take `harden` less (player.gd receive_attack multiplies by this).
static func hardened(p) -> float:
	var b = _held(p, "sandshaper")
	if b == null or b.passive_rank() < 3 or float(p.still_for) < b.passive_num("still", 1.0):
		return 1.0
	return 1.0 - b.passive_num("harden", 0.3)


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
