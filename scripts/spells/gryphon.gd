extends RefCounted
## The Gryphon's tower (Air): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd.
##
## WORKED EXAMPLE: Stormcaller.
##   Step 2: Overcharge (today's) or Ball Lightning: a slow orb that sparks
##     each foe it passes, and every second lightning leaps from it.
##   Step 3: Forked (today's change: Chain Lightning leaps 2 more times and
##     stuns) or Lingering: the last leap leaves a charged patch.
##   Step 4: Lightning Rod (today's) or Thunderclap: a clap of thunder around
##     you stuns every charged foe in reach and spends its charge.
## Windwalker (Gale Lift):
##   Step 2: Crosswind or Updraft: a column of rising wind throws each foe
##     that walks into it into the air.
##   Step 3: Widened (today's) or Echoing: a second gust a second later.
##   Step 4: Downdraft or Hurl: fling every foe in the air along your aim.
## Hunter (Piercing Shot):
##   Step 2: Track or Snare: a snare on the floor catches the first foe in it.
##   Step 3: Charged (today's) or Split: three arrows fan out.
##   Step 4: Hawk's Eye or Pinning Shot: an arrow that pins a foe in place.
##
## Things that last a while and need their own drawing (Updraft's column,
## Snare's loop, Pinning Shot's arrow...) are small Lasting nodes under the
## SpellFx node (spell_fx.gd), so they pause with the fight and a new floor
## clears them, like SpellFx's own orbs and fields.

const FX := preload("res://scripts/spell_fx.gd")

## A big beast is held only this much as long by a stun, a snare or a pin.
const BOSS_SHARE := 0.5

static var FORKS := {
	"stormcaller": {
		"change": {"name": "Forked", "says": "Chain Lightning leaps 2 more times and stuns"},
		2: {"id": "ball_lightning", "name": "Ball Lightning", "type": "ball_lightning", "learn": 2,
			"desc": "a slow orb of lightning drifts where you aim, sparking each foe it passes; every second lightning leaps from it",
			"steps": {
				2: {"cost": 10.0, "windup": 0.35, "damage": 6.0, "speed": 115.0, "duration": 3.2, "radius": 34.0, "spark": 0.45, "leaps": 2, "hop": 150.0, "chain_every": 1.0},
				4: {"damage": 8.0, "leaps": 3},
			}},
		3: {"id": "lingering", "variation": "lingering", "name": "Lingering",
			"desc": "the last leap leaves a charged patch for 3 seconds that charges and shocks foes standing in it",
			"steps": {3: {"patch": 3.0, "patch_radius": 55.0, "patch_damage": 3.0}}},
		4: {"id": "thunderclap", "name": "Thunderclap", "type": "thunderclap", "learn": 4,
			"desc": "a clap of thunder around you stuns every charged foe in reach and spends its charge",
			"steps": {
				4: {"cost": 10.0, "windup": 0.3, "radius": 240.0, "stun": 1.5, "damage": 8.0},
				5: {"stun": 1.8, "damage": 10.0},
			}},
	},
	"windwalker": {
		"change": {"name": "Widened", "says": "Gale Lift lifts every foe in a wide cone"},
		2: {"id": "updraft", "name": "Updraft", "type": "updraft", "learn": 2,
			"desc": "a column of rising wind stands where you aim for 4 seconds and throws each foe that walks into it into the air",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "duration": 4.0, "radius": 46.0, "range": 120.0, "lift": 1.2},
				4: {"duration": 5.0, "radius": 56.0},
			}},
		3: {"id": "echoing", "variation": "echo", "name": "Echoing",
			"desc": "a second gust follows a second later and lifts them again, keeping foes aloft longer",
			"steps": {3: {"lift": 1.8}}},
		4: {"id": "hurl", "name": "Hurl", "type": "hurl", "learn": 4,
			"desc": "fling every foe in the air along your aim; each crashes into the foes in its path and lands hard",
			"steps": {
				4: {"cost": 10.0, "windup": 0.3, "damage": 15.0, "splash": 12.0, "force": 720.0, "reach": 420.0},
			}},
	},
	"hunter": {
		"change": {"name": "Charged", "says": "a longer wind-up charges Piercing Shot for triple damage"},
		2: {"id": "snare", "name": "Snare", "type": "snare", "learn": 2,
			"desc": "set a snare where you aim: the first foe to step in it is caught, stunned a moment and slowed to a crawl for 3 seconds",
			"steps": {
				2: {"cost": 6.0, "windup": 0.25, "range": 110.0, "radius": 24.0, "hold": 3.0, "damage": 4.0, "duration": 20.0, "count": 2},
			}},
		3: {"id": "split_shot", "variation": "split", "name": "Split",
			"desc": "three arrows fan out from your bow, each a little weaker",
			"steps": {3: {"arrows": 3, "spread": 6.0, "power": 0.8}}},
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
}


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


## Step-3 variations run here: Stormcaller's Lingering and Hunter's Split.
## (Windwalker's Echoing is the library's own Echo.)
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match String(alt.get("id", "")):
		"lingering":
			if String(bond.id) == "stormcaller":
				_lingering(bond, sp, p)
				return true
		"split_shot":
			if String(bond.id) == "hunter":
				_split_shot(bond, sp, p)
				return true
	return false


# --- something that lasts -------------------------------------------------------------

## Something a spell leaves for a while: spell_fx.gd's shared Lasting node
## (tick(n, delta), paint(n); n.t, n.total, n.age, n.fade(), n.finish()).
static func _lasting(main, seconds: float, tick: Callable, paint: Callable) -> Node2D:
	return FX.lasting(main, seconds, tick, paint)


static func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead


# --- Stormcaller -------------------------------------------------------------------------

## Stormcaller's Lingering: Chain Lightning as it is, then the patch where its last leap struck.
static func _lingering(bond, sp: Dictionary, p) -> void:
	bond.last_point = null
	bond._cast_type(p)
	if bond.last_point == null:
		return
	var main = p.main
	var dmg: float = float(bond.spell_stat(sp, "patch_damage")) * bond.spell_power(sp) * bond.flow_power
	FX.field(main, bond.last_point, float(bond.spell_stat(sp, "patch_radius")), float(bond.spell_stat(sp, "patch")), 0.5, bond.color(), func(foes: Array):
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				e.charged = maxf(e.charged, 3.0)
				e.take_hit(dmg, Vector2.ZERO, 0.0))


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
				main.sfx("zap", 1.3, -6.0))
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


## Hunter's Split: three arrows fan out, each at `power` (no charging).
static func _split_shot(bond, sp: Dictionary, p) -> void:
	var count := maxi(1, int(bond.spell_stat(sp, "arrows")))
	var spread := deg_to_rad(float(bond.spell_stat(sp, "spread")))
	var aim: Vector2 = p.aim
	for i in count:
		p.aim = aim.rotated(spread * (float(i) - float(count - 1) * 0.5))
		bond.var_power = float(bond.spell_stat(sp, "power"))
		bond._cast_type(p)
	p.aim = aim
	bond.var_power = 1.0


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
