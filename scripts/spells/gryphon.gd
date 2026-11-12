extends RefCounted
## The Gryphon's tower (Air): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd.
##
## WORKED EXAMPLE: Stormcaller.
##   Step 2: Overcharge (today's) or Ball Lightning: a slow orb that sparks
##     each foe it passes, and every second lightning leaps from it.
##   Step 3, a Transformation of Chain Lightning: Branching Storm (every
##     leap splits in two, up to 8 foes) or Living Bolt (the chain doesn't
##     end: it keeps leaping between charged foes for 3 seconds).
##   Step 4: Lightning Rod (today's) or Thunderclap: a clap of thunder around
##     you stuns every charged foe in reach and spends its charge.
## Windwalker (Gale Lift):
##   Step 2: Crosswind or Updraft: a column of rising wind throws each foe
##     that walks into it into the air.
##   Step 3: Skyward (foes fly twice as high and slam down) or Tailwind
##     (you ride the gust forward, launching everything you pass).
##   Step 4: Downdraft or Hurl: fling every foe in the air along your aim.
## Hunter (Piercing Shot):
##   Step 2: Track or Snare: a snare on the floor catches the first foe in it.
##   Step 3: Seeking Shot (curves to your Quarry and strikes it twice) or
##     Rending Shot (foes along its line bleed).
##   Step 4: Hawk's Eye or Pinning Shot: an arrow that pins a foe in place.
##
## The step-3 TRANSFORMATIONS: side A is today's side of the choice (its
## numbers are the first spell's step 3 in bonds.gd, its name "change"
## here; cast_change runs it), side B is FORKS[bond][3] (cast_variation runs
## it). Their ids are the old variations' (lingering, echoing, split_shot) so
## old saves keep the side they chose. The passives' ranks and the great
## spells' Apex upgrades are in bonds.gd; their code is at the end of this file.
##
## Things that last a while and need their own drawing (Updraft's column,
## Snare's loop, Pinning Shot's arrow...) are small Lasting nodes under the
## SpellFx node (spell_fx.gd), so they pause with the fight and a new floor
## clears them, like SpellFx's own orbs and fields.

const FX := preload("res://scripts/spell_fx.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Pacts := preload("res://scripts/pacts.gd")

## A big beast is held only this much as long by a stun, a snare or a pin.
const BOSS_SHARE := 0.5

static var FORKS := {
	"stormcaller": {
		"change": {"name": "Branching Storm", "says": "every leap splits in two, up to 8 foes, all left charged"},
		2: {"id": "ball_lightning", "name": "Ball Lightning", "type": "ball_lightning", "learn": 2,
			"desc": "a slow orb of lightning drifts where you aim, sparking each foe it passes; every second lightning leaps from it",
			"steps": {
				2: {"cost": 10.0, "windup": 0.35, "damage": 6.0, "speed": 115.0, "duration": 3.2, "radius": 34.0, "spark": 0.45, "leaps": 2, "hop": 150.0, "chain_every": 1.0},
				4: {"damage": 8.0, "leaps": 3},
			}},
		3: {"id": "lingering", "name": "Living Bolt",
			"desc": "the chain doesn't end: it keeps leaping between charged foes for 3 seconds",
			"steps": {3: {"live": 3.0, "beat": 0.3, "live_power": 0.3, "live_hop": 220.0}}},
		4: {"id": "thunderclap", "name": "Thunderclap", "type": "thunderclap", "learn": 4,
			"desc": "a clap of thunder around you stuns every charged foe in reach and spends its charge",
			"steps": {
				4: {"cost": 10.0, "windup": 0.3, "radius": 240.0, "stun": 1.5, "damage": 8.0},
				5: {"stun": 1.8, "damage": 10.0},
			}},
	},
	"windwalker": {
		"change": {"name": "Skyward", "says": "foes fly twice as high and slam down, hurting foes where they land"},
		2: {"id": "updraft", "name": "Updraft", "type": "updraft", "learn": 2,
			"desc": "a column of rising wind stands where you aim for 4 seconds and throws each foe that walks into it into the air",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "duration": 4.0, "radius": 46.0, "range": 120.0, "lift": 1.2},
				4: {"duration": 5.0, "radius": 56.0},
			}},
		3: {"id": "echoing", "name": "Tailwind",
			"desc": "you ride the gust forward, launching everything you pass",
			"steps": {3: {"ride_lift": 1.75, "ride": 190.0, "ride_time": 0.3, "ride_radius": 46.0, "damage": 8.0}}},
		4: {"id": "hurl", "name": "Hurl", "type": "hurl", "learn": 4,
			"desc": "fling every foe in the air along your aim; each crashes into the foes in its path and lands hard",
			"steps": {
				4: {"cost": 10.0, "windup": 0.3, "damage": 15.0, "splash": 12.0, "force": 720.0, "reach": 420.0},
			}},
	},
	"hunter": {
		"change": {"name": "Seeking Shot", "says": "the arrow curves to your Quarry and strikes it twice"},
		2: {"id": "snare", "name": "Snare", "type": "snare", "learn": 2,
			"desc": "set a snare where you aim: the first foe to step in it is caught, stunned a moment and slowed to a crawl for 3 seconds",
			"steps": {
				2: {"cost": 6.0, "windup": 0.25, "range": 110.0, "radius": 24.0, "hold": 3.0, "damage": 4.0, "duration": 20.0, "count": 2},
			}},
		3: {"id": "split_shot", "name": "Rending Shot",
			"desc": "every foe along the arrow's line bleeds hard",
			"steps": {3: {"windup": 0.45, "boost": 1.0, "bleed": 4.0, "bleed_t": 5.0}}},
		4: {"id": "pinning_shot", "name": "Pinning Shot", "type": "pin", "learn": 4,
			"desc": "a heavy arrow that pins the first foe it strikes to the floor for 2 seconds, open to every blow",
			"steps": {
				4: {"cost": 10.0, "windup": 0.4, "damage": 16.0, "speed": 760.0, "range": 520.0, "pin": 2.0},
			}},
	},
}

## Words these spells show in play.
static var TEXT := {
	"stunned": "Stunned",
	"no_charged": "nothing charged",
	"nothing_air": "nothing in the air",
	"snared": "Snared",
	"pinned": "Pinned",
	"no_target": "no target",
	"nothing_lift": "nothing to lift",
	"refunded": "Chain Lightning refunded",
	"quarry": "Quarry",
	"refilled": "shot refilled",
	"skybolt": "Bolt",
}

## What each mark's blows are, while its spells strike (a foe drenched by
## the Maelstrom's Apex takes double from these: bond.gd taken_mult).
const LIGHTNING := "lightning"


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"ball_lightning":
			_ball_lightning(bond, p)
		"thunderclap":
			_thunderclap(bond, p)
		"updraft":
			_updraft(bond, p)
		"hurl":
			_hurl(bond, sp, p)
		"snare":
			_snare(bond, p)
		"pin":
			_pin(bond, p)
		_:
			return false
	return true


## Side B of the step-3 Transformations (FORKS[bond][3]): Living Bolt,
## Tailwind and Rending Shot. (Their ids are the old variations'.)
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match [String(bond.id), String(alt.get("id", ""))]:
		["stormcaller", "lingering"]:
			_living_bolt(bond, sp, p)
		["windwalker", "echoing"]:
			_tailwind(bond, sp, p)
		["hunter", "split_shot"]:
			_rending_shot(bond, sp, p)
		_:
			return false
	return true


## Side A (today's side) from step 3: Branching Storm, Skyward, Seeking Shot.
static func cast_change(bond, sp: Dictionary, p) -> bool:
	match String(bond.id):
		"stormcaller":
			_branching(bond, sp, p)
		"windwalker":
			_skyward(bond, sp, p)
		"hunter":
			_seeking_shot(bond, sp, p)
		_:
			return false
	return true


# --- something that lasts -------------------------------------------------------------

## Something a spell leaves for a while: spell_fx.gd's shared Lasting node
## (tick(n, delta), paint(n); n.t, n.total, n.age, n.fade(), n.finish()).
static func _lasting(main, seconds: float, tick: Callable, paint: Callable) -> Node2D:
	return FX.lasting(main, seconds, tick, paint)


static func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead


# --- Stormcaller -------------------------------------------------------------------------

## Ball Lightning: the orb drifts along your aim (stopping at a wall), sparks
## foes it passes (half its damage, each charged), and every `chain_every`
## seconds lightning leaps from it to up to `leaps` foes (twice as many under
## Thunderhead).
static func _ball_lightning(bond, p) -> void:
	var main = p.main
	var dmg: float = bond.damage()
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var hop := float(bond.stat("hop"))
	var leaps := int(bond.stat("leaps"))
	var spark_every := float(bond.stat("spark"))
	var chain_every := float(bond.stat("chain_every"))
	var st := {"spark": 0.0, "chain": chain_every * 0.5, "last": {}}
	var start: Vector2 = p.global_position + p.aim * (p.radius + 14.0)
	FX.orb(main, start, p.aim * float(bond.stat("speed")), float(bond.stat("duration")), radius, col, func(o: Dictionary, delta: float):
		st["spark"] -= delta
		st["chain"] -= delta
		main.hit_kind = LIGHTNING
		if st["spark"] <= 0.0:
			st["spark"] = spark_every
			for e in main.targets():
				if e.global_position.distance_to(o["pos"]) <= radius + e.radius:
					e.charged = maxf(e.charged, 4.0)
					e.take_hit(dmg * 0.5, (e.global_position - o["pos"]).normalized(), 40.0)
					main.fx_bolt([o["pos"], e.global_position], col)
		if st["chain"] <= 0.0:
			st["chain"] = chain_every
			var n := leaps * (2 if p.thunderhead_t > 0.0 else 1)
			var near: Array = main.targets().filter(func(e): return e.global_position.distance_to(o["pos"]) <= hop)
			near.sort_custom(func(a, b): return a.global_position.distance_to(o["pos"]) < b.global_position.distance_to(o["pos"]))
			var pts: Array = [o["pos"]]
			for e in near.slice(0, n):
				pts.append(e.global_position)
				e.charged = maxf(e.charged, 4.0)
				e.take_hit(dmg, Vector2.ZERO)
			if pts.size() > 1:
				main.fx_bolt(pts, col)
				main.light_flash(o["pos"], col, 1.0, 1.2, 0.2)
				main.sfx("zap", 1.3, -6.0)
		main.hit_kind = "")
	main.light_flash(start, col, 1.0, 1.4, 0.3)
	main.sfx("spell_lightning", 1.0, -2.0)


## Thunderclap: every charged foe in reach is stunned and struck, and its
## charge is spent; foes close by that aren't charged are only shoved back.
static func _thunderclap(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var stun := float(bond.stat("stun"))
	var dmg: float = bond.damage()
	var at: Vector2 = p.global_position
	var struck := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - at
		if to.length() > radius + e.radius:
			continue
		if e.charged > 0.0:
			e.charged = 0.0
			e.stagger(stun * (BOSS_SHARE if e.is_boss() else 1.0))
			main.fx_bolt([at, e.global_position], col)
			main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["stunned"], col)
			e.take_hit(dmg, Vector2.ZERO, 0.0)
			struck += 1
		elif to.length() < radius * 0.45:
			e.knock = to.normalized() * 160.0
	var paint := func(n):
		var k: float = clampf(n.age / 0.3, 0.0, 1.0)
		var a: float = 1.0 - clampf(n.age / n.total, 0.0, 1.0)
		var r: float = lerpf(20.0, radius, 1.0 - pow(1.0 - k, 3.0))
		var pts := PackedVector2Array()
		for i in 49:
			var ang := TAU * float(i % 48) / 48.0
			var jag := (8.0 + 6.0 * sin(float(i) * 7.3)) * (1.0 if i % 2 == 0 else -0.6)
			pts.append(at + Vector2.from_angle(ang) * (r + jag))
		n.draw_circle(at, r, Color(col, 0.07 * a))
		n.draw_polyline(pts, Color(col.lightened(0.4), 0.9 * a), 2.5, true)
		n.draw_arc(at, r * 0.7, 0.0, TAU, 40, Color(1, 1, 1, 0.4 * a), 1.5, true)
		n.draw_arc(at, r * 0.35, 0.0, TAU, 28, Color(col, 0.5 * a), 3.0, true)
	_lasting(main, 0.45, Callable(), paint)
	main.light_flash(at, col, 2.2, 1.8, 0.35)
	main.sfx("thunder")
	main.sfx("slam", 0.7, -4.0)
	main.shake(7.0)
	main.hitstop(0.06)
	if struck == 0:
		main.fx_text(at + Vector2(0, -34), TEXT["no_charged"], col)


# --- Windwalker ----------------------------------------------------------------------------

## Updraft: a column of rising wind. Each foe that walks into it is thrown
## into the air once (a beast is only staggered: enemy.gd lift).
static func _updraft(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var lift := float(bond.stat("lift"))
	var at: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(bond.stat("range")), 14.0)
	var lifted := {}
	var tick := func(_n, _d):
		for e in main.targets():
			if lifted.has(e.get_instance_id()) or e.airborne > 0.0:
				continue
			if e.global_position.distance_to(at) <= radius + e.radius:
				lifted[e.get_instance_id()] = true
				e.lift(lift)
				e.knock = (e.global_position - at).normalized() * 50.0
				main.fx_burst(e.global_position, Vector2.UP, col, 8, 200.0)
				main.sfx("gust", 1.4, -6.0)
	var paint := func(n):
		var a: float = n.fade(0.4)
		var tt: float = n.age
		n.draw_circle(at, radius, Color(col, 0.1 * a))
		n.draw_arc(at, radius, 0.0, TAU, 36, Color(col, 0.5 * a), 2.0, true)
		for k in 3:
			var st := tt * (4.0 + k) + k * 2.1
			n.draw_arc(at, radius * (0.3 + 0.22 * k), st, st + 2.4, 18, Color(col.lightened(0.3), 0.55 * a), 1.5, true)
		# Streaks rising up the column (up the screen), fading as they climb.
		for i in 9:
			var u := fmod(tt * 1.4 + float(i) / 9.0, 1.0)
			var x := sin(float(i) * 2.3 + tt * 2.0) * radius * 0.75
			var base := at + Vector2(x, radius * 0.3 - u * 90.0)
			n.draw_line(base, base + Vector2(sin(tt * 6.0 + i) * 3.0, -16.0), Color(1, 1, 1, 0.55 * a * (1.0 - u)), 1.5, true)
	_lasting(main, float(bond.stat("duration")), tick, paint)
	main.fx_ring(at, col, radius, 0.3, 3.0)
	main.light_flash(at, col, 1.0, 0.8, 0.3)
	main.sfx("spell_wind", 1.1)


## Hurl: every foe in the air near you is flung along your aim. It strikes
## each foe in its path (`splash`) and lands hard (`damage`) when it stops,
## hits a wall, or its flight runs out.
static func _hurl(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dmg: float = bond.damage()
	var splash: float = float(bond.stat("splash")) * bond.spell_power(sp) * bond.flow_power
	var aim: Vector2 = p.aim
	var flung: Array = main.targets().filter(func(e): return e.airborne > 0.0 and e.global_position.distance_to(p.global_position) <= float(bond.stat("reach")))
	if flung.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["nothing_air"], col)
		return
	for e in flung:
		e.airborne = maxf(e.airborne, 0.8)
		e.knock = aim * float(bond.stat("force"))
	var struck := {}
	var landed := {}
	var tick := func(n, _d):
		for e in flung:
			if not _alive(e) or landed.has(e.get_instance_id()):
				continue
			for o in main.targets():
				var key := "%d:%d" % [e.get_instance_id(), o.get_instance_id()]
				if o == e or struck.has(key) or o.global_position.distance_to(e.global_position) > e.radius + o.radius + 6.0:
					continue
				struck[key] = true
				o.take_hit(splash, aim, 220.0)
				main.fx_burst(o.global_position, aim, col, 8, 240.0)
				main.sfx("hit_heavy", 1.1, -4.0)
			if n.age > 0.12 and (e.knock.length() < 70.0 or e.get_slide_collision_count() > 0 or n.t <= 0.05):
				landed[e.get_instance_id()] = true
				e.airborne = 0.0
				main.fx_ring(e.global_position, col, 46.0, 0.3, 4.0)
				main.fx_burst(e.global_position, Vector2.ZERO, Color(0.8, 0.75, 0.7), 12, 220.0)
				main.sfx("hit_heavy", 0.8)
				main.shake(5.0)
				e.take_hit(dmg, Vector2.ZERO, 0.0, true)
	var paint := func(n):
		for e in flung:
			if not _alive(e) or landed.has(e.get_instance_id()):
				continue
			var side := aim.orthogonal()
			for k in 3:
				var off: Vector2 = side * (float(k) - 1.0) * e.radius * 0.6
				var from: Vector2 = e.global_position - aim * (e.radius + 4.0) + off
				n.draw_line(from, from - aim * (22.0 + 10.0 * k), Color(col.lightened(0.3), 0.6), 2.0, true)
	_lasting(main, 0.9, tick, paint)
	main.fx_cone(p.global_position, aim, 120.0, deg_to_rad(25.0), col)
	main.sfx("spell_wind", 0.8)
	main.sfx("swing_heavy", 0.8, -4.0)


# --- Hunter ----------------------------------------------------------------------------------

## The snares set and still waiting (the oldest goes when one too many is set).
static var _snares: Array = []


## Snare: a loop of essence on the floor; the first foe to step in it is
## stunned a moment, struck, and slowed to a crawl for `hold` seconds (Sever's
## crippling: enemy.gd cripple_t). A beast is held half as long.
static func _snare(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var hold := float(bond.stat("hold"))
	var dmg: float = bond.damage()
	var at: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(bond.stat("range")), 14.0)
	_snares = _snares.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion())
	while _snares.size() >= maxi(1, int(bond.stat("count"))):
		_snares.pop_front().finish()
	var st := {"caught": null}
	var tick := func(n, _d):
		if st["caught"] != null:
			if not _alive(st["caught"]):
				n.finish()
			return
		if n.age < 0.3:
			return  # (it settles first)
		for e in main.targets():
			if e.airborne > 0.0 or e.global_position.distance_to(at) > radius + e.radius * 0.6:
				continue
			var share := BOSS_SHARE if e.is_boss() else 1.0
			e.stagger(0.6 * share)
			e.cripple_t = maxf(e.cripple_t, hold * share)
			e.take_hit(dmg, Vector2.ZERO, 0.0)
			st["caught"] = e
			n.t = hold * share
			n.total = n.t
			_snares.erase(n)
			main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["snared"], col)
			main.fx_burst(e.global_position, Vector2.ZERO, col, 10, 180.0)
			main.sfx("hit_stab", 0.8)
			main.sfx("equip_bow", 1.2, -6.0)
			break
	var paint := func(n):
		var leather := Color(0.42, 0.29, 0.19)
		var stakes: Array = []
		for i in 3:
			stakes.append(at + Vector2.from_angle(TAU * i / 3.0 + 0.5) * (radius + 6.0))
		if st["caught"] == null:
			var a: float = n.fade(0.5)
			var glint := 0.5 + 0.5 * sin(n.age * 4.0)
			n.draw_arc(at, radius, 0.0, TAU, 28, Color(0.06, 0.05, 0.07, 0.6 * a), 4.0, true)
			n.draw_arc(at, radius, 0.0, TAU, 28, Color(leather.lightened(0.2), 0.9 * a), 2.0, true)
			n.draw_arc(at, radius - 3.0, n.age, n.age + 1.2, 10, Color(col, (0.3 + 0.4 * glint) * a), 1.5, true)
			for s in stakes:
				n.draw_line(s, s + Vector2(0, -7), Color(0.06, 0.05, 0.07, a), 3.5)
				n.draw_line(s, s + Vector2(0, -7), Color(0.75, 0.6, 0.4, a), 1.8)
			return
		var e = st["caught"]
		if not _alive(e):
			return
		var a2: float = n.fade(0.4)
		var ep: Vector2 = e.global_position
		for s in stakes:
			n.draw_line(s, ep, Color(0.06, 0.05, 0.07, 0.6 * a2), 3.0)
			n.draw_line(s, ep, Color(leather.lightened(0.25), 0.9 * a2), 1.5)
			n.draw_line(s, s + Vector2(0, -7), Color(0.75, 0.6, 0.4, a2), 1.8)
		n.draw_arc(ep, e.radius + 4.0, 0.0, TAU, 24, Color(col, 0.6 * a2), 2.0, true)
	var node := _lasting(main, float(bond.stat("duration")), tick, paint)
	if node != null:
		_snares.append(node)
	main.fx_ring(at, col, radius + 6.0, 0.3, 2.0)
	main.sfx("equip_bow", 0.9, -4.0)


## Pinning Shot: a heavy arrow (flown here, not a projectile node, so it can
## pin what it strikes). The first foe it meets takes its damage and is
## stunned (`pin` seconds, half for a beast): open to ripostes. It stops at a wall.
static func _pin(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dir: Vector2 = p.aim
	if bond._overdrawn():
		dir = dir.rotated(randf_range(-0.4, 0.4))  # an overdrawn shot flies wide, like Piercing Shot
	var speed := float(bond.stat("speed"))
	var reach := float(bond.stat("range"))
	var dmg: float = bond.damage()
	var pin := float(bond.stat("pin"))
	var st := {"pos": p.global_position + dir * (p.radius + 8.0), "travel": 0.0, "hit": null, "gone": false}
	var tick := func(n, delta: float):
		if st["gone"]:
			return
		if st["hit"] != null:
			if not _alive(st["hit"]):
				n.finish()
			else:
				st["pos"] = st["hit"].global_position
			return
		var a: Vector2 = st["pos"]
		var b: Vector2 = a + dir * speed * delta
		for e in main.targets():
			var near := Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
			if near.distance_to(e.global_position) > e.radius + 5.0:
				continue
			e.take_hit(dmg, dir, 80.0, true)
			main.fx_burst(e.global_position - dir * e.radius, -dir, col, 12, 260.0)
			main.sfx("arrow_hit", 0.8)
			main.sfx("hit_stab", 0.7, -4.0)
			main.shake(3.0)
			if "quarry" in p:
				p.quarry = e  # (Quarry: the last foe you struck)
			if _alive(e):
				var share := BOSS_SHARE if e.is_boss() else 1.0
				e.stagger(pin * share)
				main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["pinned"], col)
				st["hit"] = e
				st["pos"] = e.global_position
				n.t = pin * share
				n.total = n.t
			else:
				st["gone"] = true
				n.t = 0.1
			return
		st["pos"] = b
		st["travel"] += b.distance_to(a)
		if main.is_solid(b) or not main.room.has_point(b) or st["travel"] > reach:
			st["gone"] = true
			n.t = 0.1
			main.fx_burst(b, -dir, Color(0.8, 0.75, 0.7), 5, 150.0)
			main.sfx("arrow_hit", 1.2, -8.0)
	var paint := func(n):
		var side := dir.orthogonal()
		var pos: Vector2 = st["pos"]
		if st["hit"] == null:
			if st["gone"]:
				return
			n.draw_line(pos - dir * 46.0, pos, Color(col, 0.3), 6.0)
			n.draw_line(pos - dir * 24.0, pos + dir * 2.0, Color(0.06, 0.05, 0.07), 4.5)
			n.draw_line(pos - dir * 24.0, pos + dir * 2.0, Color(col.lightened(0.35)), 2.5)
			n.draw_colored_polygon(PackedVector2Array([pos + dir * 10.0, pos + side * 4.5, pos - dir * 2.0, pos - side * 4.5]), Color(0.9, 0.92, 0.96))
			n.draw_circle(pos, 8.0, Color(col, 0.25))
			return
		var e = st["hit"]
		if not _alive(e):
			return
		var a: float = n.fade(0.3)
		# The arrow stands through the foe into the floor, its shaft slanting back.
		var foot: Vector2 = pos + Vector2(0, e.radius * 0.6)
		var top: Vector2 = foot - dir * 14.0 + Vector2(0, -26.0)
		n.draw_arc(foot, e.radius + 6.0 + 2.0 * sin(n.age * 8.0), 0.0, TAU, 24, Color(col, 0.55 * a), 2.0, true)
		n.draw_line(top, foot, Color(0.06, 0.05, 0.07, a), 4.5)
		n.draw_line(top, foot, Color(col.lightened(0.35), a), 2.5)
		n.draw_line(top, top - dir * 4.0 + side * 5.0 + Vector2(0, -3), Color(0.9, 0.88, 0.85, a), 1.5)
		n.draw_line(top, top - dir * 4.0 - side * 5.0 + Vector2(0, -3), Color(0.9, 0.88, 0.85, a), 1.5)
	_lasting(main, reach / maxf(speed, 1.0) + 0.3, tick, paint)
	main.sfx("bow_full", 0.8)
	main.sfx("bow", 0.9, -4.0)
	main.light_flash(p.global_position + dir * 30.0, col, 1.0, 1.1, 0.25)
	main.shake(2.5)


# --- the step-3 Transformations ----------------------------------------------------------

## The foe nearest `at` within `reach` that isn't in `skip` (or null).
static func _nearest_to(main, at: Vector2, reach: float, skip: Array = []):
	var best = null
	var best_d := reach
	for e in main.targets():
		if e in skip or e.dead:
			continue
		var d: float = at.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Stormcaller's Branching Storm: the first leap goes to the foe nearest you;
## from every foe struck the lightning splits, leaping to the `branch`
## nearest foes not struck yet, until `most` foes are struck (twice as many
## under Thunderhead). Each is struck at `boost` times the spell's damage
## and left charged. A planted Lightning Rod is a stop on the way, as for
## Chain Lightning: a branch with no foe left in reach leaps to it and on
## from it (even around corners), and the rod beats.
static func _branching(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var most := int(bond.spell_stat(sp, "most")) * (2 if p.thunderhead_t > 0.0 else 1)
	var branch := maxi(1, int(bond.spell_stat(sp, "branch")))
	var hop := float(bond.spell_stat(sp, "hop"))
	var rod: Dictionary = main.rod
	var rod_hop := maxf(hop, float(rod.get("reach", 0.0)))
	var st := {"rod_used": false}
	var hit: Array = []
	var legs: Array = []
	var front: Array = []  # [where it leaps from, how far it reaches]
	var first = _nearest_to(main, p.global_position, float(bond.spell_stat(sp, "reach")))
	if first != null:
		hit.append(first)
		legs.append([p.global_position, first.global_position])
		front.append([first.global_position, hop])
	elif not rod.is_empty() and p.global_position.distance_to(rod["pos"]) < float(rod["link"]):
		st["rod_used"] = true
		legs.append([p.global_position, rod["pos"]])
		front.append([rod["pos"], rod_hop])
	while not front.is_empty() and hit.size() < most:
		var next: Array = []
		for f in front:
			var found := 0
			for i in branch:
				if hit.size() >= most:
					break
				var o = _nearest_to(main, f[0], f[1], hit)
				if o == null:
					break
				found += 1
				hit.append(o)
				next.append([o.global_position, hop])
				legs.append([f[0], o.global_position])
			if found == 0 and not st["rod_used"] and not rod.is_empty() and f[0].distance_to(rod["pos"]) < rod_hop:
				st["rod_used"] = true
				legs.append([f[0], rod["pos"]])
				next.append([rod["pos"], rod_hop])
		front = next
	if not st["rod_used"] and not rod.is_empty():
		for e in hit:
			if e.global_position.distance_to(rod["pos"]) < float(rod["reach"]):
				st["rod_used"] = true
				legs.append([e.global_position, rod["pos"]])
				break
	if st["rod_used"]:
		bond.rod_beat(main, rod)
	if hit.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["no_target"], col)
		return
	bond.last_point = hit[-1].global_position
	for leg in legs:
		main.fx_bolt(leg, col)
		main.light_flash(leg[1], col, 0.9, 1.3, 0.25)
	main.sfx("zap")
	main.sfx("thunder", 1.4, -10.0)
	main.hitstop(0.07)
	main.shake(6.0)
	var dmg: float = bond.spell_damage(sp) * float(bond.spell_stat(sp, "boost"))
	for e in hit:
		if _alive(e):
			e.charged = maxf(e.charged, 4.0)
			e.take_hit(dmg, Vector2.ZERO)
	if bond._overdrawn() and randf() < 0.5:  # (as Chain Lightning: the last leap may jump back to you)
		main.fx_bolt([bond.last_point, p.global_position], col)
		p.hp = maxf(1.0, p.hp - 6.0)


## Stormcaller's Living Bolt: Chain Lightning as it is, then for `live`
## seconds the bolt stays alive where it ended: every `beat` it leaps from
## the foe it holds to the nearest other charged foe within `live_hop`
## (never straight back, unless there's nothing else), striking it at
## `live_power` of the spell's damage and keeping it charged. With no other
## charged foe near, it waits on the one it holds.
static func _living_bolt(bond, sp: Dictionary, p) -> void:
	var main = p.main
	bond.last_point = null
	bond._cast_type(p)
	if bond.last_point == null:
		return
	var col: Color = bond.color()
	var dmg: float = bond.spell_damage(sp) * float(bond.spell_stat(sp, "live_power"))
	var hop := float(bond.spell_stat(sp, "live_hop"))
	var beat := float(bond.spell_stat(sp, "beat"))
	var st := {"on": _nearest_to(main, bond.last_point, 40.0), "prev": null, "beat": beat, "pos": bond.last_point, "flash": 0.0}
	var tick := func(_n, delta: float):
		st["beat"] -= delta
		st["flash"] = maxf(0.0, st["flash"] - delta)
		if _alive(st["on"]):
			st["pos"] = st["on"].global_position
		if st["beat"] > 0.0:
			return
		st["beat"] = beat
		var from: Vector2 = st["pos"]
		var best = null
		var best_d := hop
		for e in main.targets():
			if e.dead or e == st["on"] or not Reactions.has(e, "charged"):
				continue
			var d: float = from.distance_to(e.global_position) + (hop * 0.5 if e == st["prev"] else 0.0)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return
		main.fx_bolt([from, best.global_position], col)
		main.sfx("zap", 1.2 + randf() * 0.2, -7.0)
		st["prev"] = st["on"]
		st["on"] = best
		st["pos"] = best.global_position
		st["flash"] = 0.15
		best.charged = maxf(best.charged, 4.0)
		main.hit_kind = LIGHTNING
		best.take_hit(dmg, Vector2.ZERO, 0.0)
		main.hit_kind = ""
	var paint := func(n):
		var a: float = n.fade(0.3)
		var c: Vector2 = st["pos"]
		var r: float = 9.0 + 4.0 * st["flash"] / 0.15
		n.draw_circle(c, r + 6.0, Color(col, 0.18 * a))
		for k in 4:
			var ang: float = n.age * 9.0 + float(k) * TAU / 4.0
			n.draw_line(c + Vector2.from_angle(ang) * 4.0, c + Vector2.from_angle(ang + 0.5) * r, Color(col.lightened(0.4), 0.85 * a), 1.5, true)
		n.draw_circle(c, 3.0, Color(1, 1, 1, 0.9 * a))
	_lasting(main, float(bond.spell_stat(sp, "live")), tick, paint)


## Windwalker's Skyward: the gust (Gale Lift's cone) throws foes `high`
## times as long into the air; each slams down where it lands, taking
## `slam`, and the foes near where it lands (within `splash_radius`) take
## `splash`, each at most once a cast.
static func _skyward(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var half := deg_to_rad(float(bond.spell_stat(sp, "arc")))
	var reach := float(bond.spell_stat(sp, "reach"))
	var lift := float(bond.spell_stat(sp, "lift")) * float(bond.spell_stat(sp, "high"))
	var k: float = bond.spell_power(sp) * bond.flow_power
	var slam := float(bond.spell_stat(sp, "slam")) * k
	var splash := float(bond.spell_stat(sp, "splash")) * k
	var splash_r := float(bond.spell_stat(sp, "splash_radius"))
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	main.fx_cone(origin, aim, reach, half, col)
	main.light_flash(origin + aim * reach * 0.5, col, 1.6, 0.9, 0.35)
	main.sfx("gust", 0.8)
	main.sfx("spell_wind", 1.2, -4.0)
	var up: Array = []
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius or absf(aim.angle_to(to)) > half:
			continue
		e.lift(lift)
		e.knock = aim * 90.0
		if e.airborne > 0.0:
			up.append(e)
		if Pacts.has(p, "dust_devil"):
			bond._shards(main, e.global_position)
	if up.is_empty():
		main.fx_text(origin + Vector2(0, -34), TEXT["nothing_lift"], col)
		return
	var splashed := {}
	var held := {"up": up}  # (a lambda mustn't capture a foe that may be freed)
	var tick := func(_n, delta: float):
		for e in held["up"].duplicate():
			if not _alive(e):
				held["up"].erase(e)
				continue
			if e.airborne > delta * 1.5:
				continue
			held["up"].erase(e)
			e.airborne = 0.0
			var at: Vector2 = e.global_position
			main.fx_ring(at, col, splash_r, 0.35, 4.0)
			main.fx_burst(at, Vector2.ZERO, Color(0.8, 0.75, 0.7), 14, 240.0)
			main.sfx("hit_heavy", 0.75)
			main.shake(5.0)
			for o in main.targets():
				if o != e and not splashed.has(o.get_instance_id()) and o.airborne <= 0.0 and o.global_position.distance_to(at) <= splash_r + o.radius:
					splashed[o.get_instance_id()] = true
					o.take_hit(splash, (o.global_position - at).normalized(), 140.0)
			e.take_hit(slam, Vector2.ZERO, 0.0, true)
		if held["up"].is_empty():
			return false
	var paint := func(n):
		for e in held["up"]:
			if not _alive(e):
				continue
			var c: Vector2 = e.global_position
			var a: float = clampf(e.airborne / 0.6, 0.0, 1.0)
			# A shadow on the floor under each foe aloft, and wind around it.
			n.draw_circle(c + Vector2(0, e.radius + 10.0), e.radius * (0.6 + 0.3 * a), Color(0, 0, 0, 0.25))
			n.draw_arc(c, e.radius + 7.0, n.age * 6.0, n.age * 6.0 + 2.2, 14, Color(col.lightened(0.3), 0.6), 1.5, true)
	_lasting(main, lift + 0.6, tick, paint)


## Windwalker's Tailwind: Gale Lift's gust, and you ride it: you're carried
## `ride` px along your aim over `ride_time` seconds, untouchable, and every
## foe in the gust or that you pass (within `ride_radius`) is thrown into the
## air (`ride_lift` times Gale Lift's lift) and struck (`damage`). The ride
## stops at a wall.
static func _tailwind(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var aim: Vector2 = p.aim
	var t := maxf(0.05, float(bond.spell_stat(sp, "ride_time")))
	var speed := float(bond.spell_stat(sp, "ride")) / t
	var r := float(bond.spell_stat(sp, "ride_radius"))
	var lift := float(bond.spell_stat(sp, "lift")) * float(bond.spell_stat(sp, "ride_lift"))
	var dmg: float = bond.spell_damage(sp)
	var passed := {}
	var gust := func():
		for e in main.targets():
			if passed.has(e.get_instance_id()) or e.global_position.distance_to(p.global_position) > r + e.radius:
				continue
			passed[e.get_instance_id()] = true
			e.lift(lift)
			e.knock = (aim + (e.global_position - p.global_position).normalized()).normalized() * 110.0
			if dmg > 0.0:
				e.take_hit(dmg, aim, 40.0)
			main.fx_burst(e.global_position, Vector2.UP, col, 8, 200.0)
	# The gust itself first (Gale Lift's cone, without its damage), then the ride.
	var half := deg_to_rad(float(bond.spell_stat(sp, "arc")))
	var reach := float(bond.spell_stat(sp, "reach"))
	main.fx_cone(p.global_position, aim, reach, half, col)
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + e.radius and absf(aim.angle_to(to)) <= half:
			e.lift(lift)
			e.knock = aim * 120.0
	p.iframes = maxf(p.iframes, t + 0.1)
	var trail: Array = [p.global_position]
	var tick := func(n, delta: float):
		if not is_instance_valid(p) or p.dead:
			return false
		if n.age <= t:
			var bump = p.move_and_collide(aim * speed * delta)
			trail.append(p.global_position)
			if bump != null:
				n.t = minf(n.t, 0.3)
			gust.call()
	var paint := func(n):
		var a: float = n.fade(0.3)
		var side: Vector2 = aim.orthogonal()
		for i in range(1, trail.size()):
			var k := float(i) / float(trail.size())
			for s in [-1.0, 1.0]:
				n.draw_line(trail[i - 1] + side * s * r * 0.5 * k, trail[i] + side * s * r * 0.5 * k, Color(col.lightened(0.3), 0.5 * a * k), 2.0, true)
		if is_instance_valid(p) and n.age <= t:
			n.draw_arc(p.global_position, r, aim.angle() - 1.2, aim.angle() + 1.2, 16, Color(1, 1, 1, 0.5 * a), 2.0, true)
	_lasting(main, t + 0.4, tick, paint)
	main.sfx("gust", 0.9)
	main.sfx("spell_wind", 1.3)
	main.sfx("roll", 0.8, -4.0)


## A shot flown here (not a projectile node): from beside the climber along
## `dir` at `speed`, for `reach` px or until a wall. `steer(st, delta)` may
## turn st["dir"]; `hit(e, st)` is called once for each foe it meets and
## returns true to stop the arrow there. Drawn as an arrow of essence.
static func _fly(main, p, dir: Vector2, speed: float, reach: float, col: Color, steer: Callable, hit: Callable) -> void:
	var st := {"pos": p.global_position + dir * (p.radius + 8.0), "dir": dir, "travel": 0.0, "met": [], "gone": false, "trail": []}
	var tick := func(n, delta: float):
		if st["gone"]:
			return
		if steer.is_valid():
			steer.call(st, delta)
		var a: Vector2 = st["pos"]
		var b: Vector2 = a + st["dir"] * speed * delta
		for e in main.targets():
			if e in st["met"]:
				continue
			var near := Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
			if near.distance_to(e.global_position) > e.radius + 5.0:
				continue
			st["met"].append(e)
			if bool(hit.call(e, st)):
				st["gone"] = true
				n.t = minf(n.t, 0.3)
				return
		st["pos"] = b
		st["travel"] += a.distance_to(b)
		st["trail"].append(b)
		if st["trail"].size() > 8:
			st["trail"].pop_front()
		if main.is_solid(b) or not main.room.has_point(b) or st["travel"] > reach:
			st["gone"] = true
			n.t = minf(n.t, 0.1)
			main.fx_burst(b, -st["dir"], Color(0.8, 0.75, 0.7), 5, 150.0)
			main.sfx("arrow_hit", 1.2, -8.0)
	var paint := func(n):
		if st["gone"]:
			return
		var pos: Vector2 = st["pos"]
		var d: Vector2 = st["dir"]
		var side := d.orthogonal()
		var tr: Array = st["trail"]
		for i in range(1, tr.size()):
			n.draw_line(tr[i - 1], tr[i], Color(col, 0.12 + 0.3 * float(i) / tr.size()), 5.0, true)
		n.draw_line(pos - d * 22.0, pos, Color(col.lightened(0.35)), 3.0)
		n.draw_colored_polygon(PackedVector2Array([pos + d * 9.0, pos + side * 4.0, pos - d * 2.0, pos - side * 4.0]), Color(0.92, 0.94, 0.98))
		n.draw_circle(pos, 8.0, Color(col, 0.25))
	_lasting(main, reach / maxf(speed, 1.0) + 1.0, tick, paint)


## Hunter's Seeking Shot: the arrow flies along your aim and curves toward
## your Quarry (the last foe you struck; else the foe you aim at, which
## becomes it), turning up to `turn` radians a second once it's within
## `seek` px. Foes on its way are pierced; the Quarry is struck twice
## (`strikes`) at `boost` times the shot's damage, and the arrow stops there.
static func _seeking_shot(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dir: Vector2 = p.aim
	if bond._overdrawn():
		dir = dir.rotated(randf_range(-0.4, 0.4))
	var q = p.quarry if "quarry" in p and _alive(p.quarry) else null
	if q == null:
		q = bond._target_in_aim(p, 700.0)
		if q != null:
			p.quarry = q
	var held := {"q": q}  # (a lambda mustn't capture a foe that may be freed)
	var dmg: float = bond.spell_damage(sp) * float(bond.spell_stat(sp, "boost"))
	var strikes := maxi(1, int(bond.spell_stat(sp, "strikes")))
	var turn := float(bond.spell_stat(sp, "turn"))
	var seek := float(bond.spell_stat(sp, "seek"))
	var steer := func(st: Dictionary, delta: float):
		var tq = held["q"]
		if not _alive(tq):
			return
		var to: Vector2 = tq.global_position - st["pos"]
		if to.length() > seek:
			return
		var ang: float = st["dir"].angle_to(to)
		st["dir"] = st["dir"].rotated(clampf(ang, -turn * delta, turn * delta))
	var hit := func(e, st: Dictionary) -> bool:
		if not is_instance_valid(p) or p.dead:
			return true
		var d: Vector2 = st["dir"]
		if e != held["q"]:
			p.ranged_hit(e, dmg, d, 160.0, true)
			return false
		p.ranged_hit(e, dmg, d, 120.0, true)
		main.fx_burst(e.global_position - d * e.radius, -d, col, 12, 260.0)
		main.sfx("arrow_hit", 0.8)
		var tgt := {"e": e}
		for i in range(1, strikes):
			FX.later(main, 0.12 * i, func():
				if _alive(tgt["e"]) and is_instance_valid(p) and not p.dead:
					p.ranged_hit(tgt["e"], dmg, d, 120.0, true)
					main.fx_burst(tgt["e"].global_position, -d, col.lightened(0.3), 10, 240.0)
					main.sfx("arrow_hit", 1.1))
		return true
	_fly(main, p, dir, float(bond.spell_stat(sp, "speed")), 900.0, col, steer, hit)
	main.sfx("bow", 1.2)
	main.sfx("bow_full", 1.1, -6.0)
	main.light_flash(p.global_position + dir * 30.0, col, 1.0, 1.1, 0.2)


## Hunter's Rending Shot: the arrow (`boost` times the shot's damage)
## pierces a whole line; every foe it passes bleeds (`bleed` each half
## second for `bleed_t` seconds: reactions.gd).
static func _rending_shot(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dir: Vector2 = p.aim
	if bond._overdrawn():
		dir = dir.rotated(randf_range(-0.4, 0.4))
	var dmg: float = bond.spell_damage(sp) * float(bond.spell_stat(sp, "boost"))
	var bleed: float = float(bond.spell_stat(sp, "bleed")) * bond.spell_power(sp) * bond.flow_power
	var secs := float(bond.spell_stat(sp, "bleed_t"))
	var hit := func(e, st: Dictionary) -> bool:
		if not is_instance_valid(p) or p.dead:
			return true
		p.ranged_hit(e, dmg, st["dir"], 160.0, true)
		if _alive(e):
			Reactions.apply(main, e, "bleeding", secs, bond, bleed)
			main.fx_burst(e.global_position, st["dir"], Color(0.86, 0.18, 0.2), 8, 200.0)
		return false
	_fly(main, p, dir, float(bond.spell_stat(sp, "speed")), 900.0, col, Callable(), hit)
	main.sfx("bow", 1.0)
	main.sfx("bow_full", 0.9, -4.0)
	main.light_flash(p.global_position + dir * 30.0, col, 1.0, 1.1, 0.2)
	main.shake(2.5)


# --- the passives' ranks and the Apex upgrades -----------------------------------------------
# (bond.gd, player.gd and main.gd call these; the numbers are in bonds.gd.)

## Thunderhead's Apex: a strike you land calls a bolt from above onto the
## foe (`dmg`), which leaves it charged.
static func sky_bolt(main, e, dmg: float, col: Color) -> void:
	if not _alive(e) or dmg <= 0.0:
		return
	var at: Vector2 = e.global_position
	main.fx_bolt([at + Vector2(randf_range(-20, 20), -220.0), at + Vector2(randf_range(-8, 8), -70.0), at], col)
	main.light_flash(at, col, 1.2, 1.6, 0.2)
	main.sfx("zap", 0.9, -4.0)
	main.hit_kind = LIGHTNING
	e.take_hit(dmg, Vector2.ZERO, 0.0)
	main.hit_kind = ""
	if _alive(e):
		e.charged = maxf(e.charged, 4.0)


## Featherweight III: a roll leaves a gust where it began that lifts the
## light foes near it (never a beast; `most_weight` at most).
static func roll_gust(main, at: Vector2, radius: float, lift: float, most_weight: float, col: Color) -> void:
	var lifted := 0
	for e in main.targets():
		if e.is_boss() or float(e.weight) > most_weight or e.airborne > 0.0 or e.global_position.distance_to(at) > radius + e.radius:
			continue
		e.lift(lift)
		lifted += 1
	main.fx_ring(at, col, radius, 0.3, 2.0)
	if lifted > 0:
		main.sfx("gust", 1.4, -6.0)


## Eye of the Storm's Apex: each cyclone drifts toward where you aim, at
## most `steer` px a second (main.gd ticks the cyclones).
static func steer_cyclone(main, c: Dictionary, delta: float) -> void:
	var p = main.player
	if p == null or not is_instance_valid(p) or p.dead or float(c.get("steer", 0.0)) <= 0.0:
		return
	var want: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(c.get("range", 150.0)), 14.0)
	c["pos"] = (c["pos"] as Vector2).move_toward(want, float(c["steer"]) * delta)


## Rain of Arrows' Apex: the rain drifts after your Quarry, at most
## `follow` px a second (main.gd ticks the rain).
static func follow_quarry(main, r: Dictionary, delta: float) -> void:
	var p = main.player
	if p == null or not is_instance_valid(p) or float(r.get("follow", 0.0)) <= 0.0 or not ("quarry" in p) or not _alive(p.quarry):
		return
	r["pos"] = (r["pos"] as Vector2).move_toward(p.quarry.global_position, float(r["follow"]) * delta)
