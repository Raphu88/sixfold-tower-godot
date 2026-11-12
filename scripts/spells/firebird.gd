extends RefCounted
## The Firebird's tower (Fire): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd; the
## worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Flame Contractor: step 2 Fire Wall or BLAZING TRAIL (burning ground
##     wherever you walk); step 3, a Transformation of Fireball: SUNFIRE
##     (slower, larger, burning ground along its whole path) or SEEKER FLAME
##     (curves toward foes, explodes twice); step 4 Cluster Blast or
##     DETONATE (every patch of your burning ground bursts at once).
##   Flamewing: step 2 Wingburst or CINDER DIVE (a dive through foes that
##     spends the aura's heat); step 3, Heat Aura becomes FURNACE (heat
##     builds faster, foes in it slow) or EMBER WINGS (it reaches out as
##     wings to your sides, knocking foes away); step 4 Warmth or HEAT HAZE
##     (the aura burns away shots).
##   Rekindler: step 2 Desperation or FLASHPOINT (spend health in a burst
##     of fire); step 3, Rekindle becomes BONFIRE (foes you strike burn,
##     each growing the payback) or CAUTERIZE (a small heal now, the payback
##     as a barrier); step 4 Pyre Oath or BACKDRAFT (blows you take burst
##     into fire).
##
## Step 3's first side keeps the old choice id "change", its second side the
## old id in FORKS[bond][3] (quickfire, broad, deep_burn), so old saves map
## by themselves. The first side runs in cast_change(), the second in
## cast_variation(); their numbers are the bond's step 3 (bonds.gd) and
## FORKS[bond][3]["steps"][3]. The step-5 spells' Apex upgrades are in
## bonds.gd; Meteor's crater is crater() below.
##
## Firebird Form makes a spell marked "free_in_form" free (player.gd), so
## Cinder Dive carries the mark, as Wingburst does. Rekindle's payback
## (twice what you lost, more with Bonfire, a barrier with Cauterize) lives
## in player.gd.
##
## What these spells leave in the world for a while is spell_fx.gd's shared
## Lasting node (spawn() below; chimera.gd uses it too). A new floor clears it.

const FX := preload("res://scripts/spell_fx.gd")
const Reactions := preload("res://scripts/reactions.gd")

static var FORKS := {
	"flame_contractor": {
		"change": {"name": "Sunfire", "says": "a slower, larger fireball that leaves burning ground along its whole path",
			"reach": 420.0, "gap": 24.0, "patch": 18.0, "size": 1.6},
		2: {"id": "blazing_trail", "name": "Blazing Trail", "type": "blazing_trail", "learn": 2,
			"desc": "for 4 seconds you leave a trail of burning ground wherever you walk (it burns foes, not you)",
			"steps": {
				2: {"cost": 10.0, "windup": 0.2, "duration": 4.0, "burns": 2.5, "gap": 30.0},
				4: {"duration": 5.0},
			}},
		3: {"id": "quickfire", "name": "Seeker Flame", "transform": true,
			"desc": "the fireball curves toward foes and explodes twice",
			"steps": {3: {"damage": 18.0, "radius": 62.0, "seek": 5.0, "seek_reach": 240.0, "again": 0.8, "delay": 0.35}}},
		4: {"id": "detonate", "name": "Detonate", "type": "detonate", "learn": 4,
			"desc": "every patch of your burning ground bursts at once (up to 6 bursts); with none, one bigger burst at your aim",
			"steps": {
				4: {"cost": 12.0, "windup": 0.3, "damage": 14.0, "radius": 58.0, "bursts": 6},
				5: {"damage": 17.0},
			}},
	},
	"flamewing": {
		"change": {"name": "Furnace", "says": "the aura's heat builds faster, and foes in it are slowed"},
		2: {"id": "cinder_dive", "name": "Cinder Dive", "type": "cinder_dive", "learn": 2, "free_in_form": true,
			"desc": "dive through the foes along your aim in a streak of fire, setting each one burning; the aura's built-up heat makes it hotter (free in Firebird Form)",
			"steps": {
				2: {"cost": 10.0, "windup": 0.15, "damage": 8.0, "dist": 150.0, "burn": 2.0, "burn_time": 3.0},
				4: {"damage": 11.0},
				5: {"damage": 13.0},
			}},
		3: {"id": "broad", "name": "Ember Wings", "transform": true,
			"desc": "the aura grows hotter the longer it burns and reaches out as wings to your sides, burning hard and knocking away the foes they touch",
			"steps": {3: {"grows": true, "wings": 2.3, "wing_arc": 55.0, "wing_power": 1.5, "push": 300.0, "push_every": 1.0}}},
		4: {"id": "heat_haze", "name": "Heat Haze", "type": "heat_haze", "learn": 4,
			"desc": "for 8 seconds your aura burns away the shots that enter it and sets the foes in it burning (it lights the aura if it's off)",
			"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 8.0, "burn": 2.0}}},
	},
	"rekindler": {
		"change": {"name": "Bonfire", "says": "foes you strike while you burn catch fire, and the payback grows with each one"},
		2: {"id": "flashpoint", "name": "Flashpoint", "type": "flashpoint", "learn": 2,
			"desc": "spend a tenth of your health in a burst of fire around you; the lower your health, the harder it hits",
			"steps": {
				2: {"cost": 9.0, "windup": 0.15, "price": 0.1, "damage": 12.0, "radius": 90.0},
				4: {"damage": 15.0},
				5: {"damage": 18.0},
			}},
		3: {"id": "deep_burn", "name": "Cauterize", "transform": true,
			"desc": "Rekindle heals you a little at once, and its payback comes as a barrier",
			"steps": {3: {"mend": 0.1, "shield": 3.0, "shield_time": 10.0}}},
		4: {"id": "backdraft", "name": "Backdraft", "type": "backdraft", "learn": 4,
			"desc": "for 10 seconds every blow you take bursts into fire around you, hotter for a bigger blow",
			"steps": {
				4: {"cost": 12.0, "windup": 0.2, "duration": 10.0, "damage": 10.0, "radius": 90.0},
				5: {"damage": 13.0},
			}},
	},
}

## The few words these spells show in the world.
static var TEXT := {
	"backdraft": "Backdraft",
	"bonfire": "Bonfire",
	"cauterize": "Cauterized +%d",
}
## Meteor's crater (its Apex): patches of your burning ground in a ring and at the middle.
static var CRATER := {"patches": 6, "patch": 24.0, "ring": 0.55}


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"blazing_trail":
			_blazing_trail(bond, p)
		"detonate":
			_detonate(bond, p)
		"cinder_dive":
			_cinder_dive(bond, p)
		"heat_haze":
			_heat_haze(bond, p)
		"flashpoint":
			_flashpoint(bond, p)
		"backdraft":
			_backdraft(bond, p)
		_:
			return false
	return true


## Step 3's first side, a Transformation (from step 3 until the other side is
## chosen): Sunfire and Bonfire run here. Furnace is Heat Aura's own numbers
## (bond.gd _aura reads them), so it falls through.
static func cast_change(bond, sp: Dictionary, p) -> bool:
	match String(bond.id):
		"flame_contractor":
			_sunfire(bond, sp, p)
			return true
		"rekindler":
			_bonfire(bond, sp, p)
			return true
	return false


## Step 3's second side, a Transformation: Seeker Flame, Ember Wings, Cauterize.
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match [String(bond.id), String(alt.get("id", ""))]:
		["flame_contractor", "quickfire"]:
			_seeker_flame(bond, sp, p)
			return true
		["flamewing", "broad"]:
			_ember_wings(bond, sp, p)
			return true
		["rekindler", "deep_burn"]:
			_cauterize(bond, sp, p)
			return true
	return false


# --- the Transformations ---------------------------------------------------------------

## Sunfire: a slower, bigger fireball that leaves your burning ground every
## few steps of its flight, all the way to where it bursts.
static func _sunfire(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var ch: Dictionary = FORKS["flame_contractor"]["change"]
	var ball = bond._fireball(p, 0)
	var speed := float(bond.spell_stat(sp, "speed"))
	ball.vel = p.aim * speed
	if not bond._overdrawn():
		ball.life = float(ch["reach"]) / maxf(speed, 1.0)
	ball.scale = Vector2.ONE * float(ch["size"])
	var blast = bond.spell_stat(sp, "blast")  # (it hits harder than the plain fireball, at every step)
	if blast != null:
		ball.explode_dmg *= float(blast)
	var trail := float(bond.spell_stat(sp, "trail"))
	var gap := float(ch["gap"])
	var patch := float(ch["patch"])
	main.add_flame(ball.position, patch, trail, true)
	FX.lasting(main, ball.life + 1.0, func(n, _d: float) -> bool:
		var b = n.data["ball"]  # (kept in the data, not captured: it may be gone by now)
		if not is_instance_valid(b) or b.explode_r <= 0.0 or b.is_queued_for_deletion():
			return false
		var at: Vector2 = b.position
		while at.distance_to(n.data["last"]) >= gap:  # (a patch every `gap` px, even on a long frame)
			var next: Vector2 = n.data["last"] + (at - n.data["last"]).normalized() * gap
			main.add_flame(next, patch, trail, true)
			n.data["last"] = next
		return true, Callable(), {"last": ball.position, "ball": ball})
	main.light_flash(p.global_position, bond.color(), 1.4, 1.4, 0.3)


## Seeker Flame: the fireball turns toward the nearest foe ahead of it, and
## where it bursts it bursts again a moment later.
static func _seeker_flame(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var ball = bond._fireball(p, 0)
	var turn := float(bond.spell_stat(sp, "seek"))
	var reach := float(bond.spell_stat(sp, "seek_reach"))
	var again := float(bond.spell_stat(sp, "again"))
	var delay := float(bond.spell_stat(sp, "delay"))
	var r: float = ball.explode_r
	var dmg: float = ball.explode_dmg * again
	var col: Color = bond.color()
	if not bond._overdrawn():
		ball.life = 1.3
	var tick := func(n, d: float) -> bool:
		var fb = n.data["ball"]  # (kept in the data, not captured: it may be gone by now)
		if is_instance_valid(fb) and fb.explode_r > 0.0 and not fb.is_queued_for_deletion():
			n.data["last"] = fb.position
			var best = null
			var best_d := reach
			for e in main.targets():
				var dd: float = e.global_position.distance_to(fb.position)
				if dd < best_d and fb.vel.dot(e.global_position - fb.position) > 0.0:
					best_d = dd
					best = e
			if best != null:
				var want: float = fb.vel.angle_to(best.global_position - fb.position)
				fb.vel = fb.vel.rotated(clampf(want, -turn * d, turn * d))
			return true
		# It burst (or went out): the second burst, where it was.
		if not n.data["again"]:
			n.data["again"] = true
			var at: Vector2 = n.data["last"]
			FX.mark(main, at, delay, col)
			FX.later(main, delay, func():
				main.explode(at, r, dmg, col)
				main.sfx("fire_blast", 1.15, -3.0))
		return false
	FX.lasting(main, 3.0, tick, Callable(), {"last": ball.position, "again": false, "ball": ball})


## Ember Wings: Heat Aura as ever (cast again, it goes out and the wings
## with it). The wings themselves are ember_wings(), which bond.gd _aura
## starts whenever the aura lights (Heat Haze and Firebird Form light it too).
static func _ember_wings(bond, _sp: Dictionary, p) -> void:
	bond._cast_type(p)


## While the aura burns it reaches out as two wings to your sides (across
## your aim): foes they touch burn with the aura and are knocked away, each
## at most once every `push_every` seconds. (`bond`'s selected spell is Heat Aura.)
static func ember_wings(bond, p) -> void:
	var main = p.main
	var fx = FX.of(main)
	if fx != null and fx.lastings.any(func(l): return is_instance_valid(l) and l.data.has("ember_wings")):
		return  # (one pair of wings)
	var col: Color = bond.color()
	var span := float(bond.stat("wings"))
	var arc := deg_to_rad(float(bond.stat("wing_arc")))
	var push := float(bond.stat("push"))
	var every := float(bond.stat("push_every"))
	var power := float(bond.stat("wing_power"))
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(p) or p.dead or p.aura_part != bond.part:
			return false
		n.data["at"] = p.global_position
		n.data["aim"] = p.aim
		var r: float = p.aura_r * (2.0 if p.firebird_t > 0.0 else 1.0)
		n.data["r"] = r
		n.data["tick"] -= d
		if n.data["tick"] > 0.0:
			return true
		n.data["tick"] = 0.5
		var side: Vector2 = p.aim.orthogonal()
		var now: float = n.age
		for e in main.targets():
			var to: Vector2 = e.global_position - p.global_position
			var dist := to.length()
			if dist < r + e.radius or dist > r * span + e.radius or dist < 1.0:
				continue  # (inside the aura itself, or past the wing's tip)
			if absf(side.angle_to(to)) > arc and absf((-side).angle_to(to)) > arc:
				continue
			e.take_hit(p.aura_dmg * power, Vector2.ZERO, 0.0)
			p.aura_heat = minf(60.0, p.aura_heat + p.aura_dmg * power)
			if e.dead:
				continue
			Reactions.apply(main, e, "burning", 1.5, "aura")
			var key: int = e.get_instance_id()
			if now >= float(n.data["pushed"].get(key, -99.0)) + every:
				n.data["pushed"][key] = now
				e.knock = to.normalized() * push * (0.4 if e.kind == "knight" else (0.12 if e.is_boss() else 1.0))
				main.fx_burst(e.global_position, to.normalized(), col, 6, 200.0)
		return true
	var paint := func(n):
		var at: Vector2 = n.data["at"]
		var r: float = n.data["r"]
		var side: Vector2 = Vector2(n.data["aim"]).orthogonal()
		var beat := 0.85 + 0.15 * sin(n.age * 5.0)
		for s in [1.0, -1.0]:
			var axis: Vector2 = side * s
			for i in 7:  # long swept feathers of flame, fanning out to the wing's tip
				var a: float = lerpf(-arc, arc, i / 6.0) * beat
				var dir: Vector2 = axis.rotated(a)
				var tip: Vector2 = at + dir * r * span * (0.8 + 0.2 * cos(a * 2.0))
				var root: Vector2 = at + dir * r * 0.8
				n.draw_line(root, tip, Color(col.lightened(0.25), 0.55), 3.0, true)
				n.draw_line(root.lerp(tip, 0.4), tip, Color(1.0, 0.9, 0.6, 0.45), 1.5, true)
	FX.lasting(main, INF, tick, paint, {"at": p.global_position, "aim": p.aim, "r": p.aura_r, "tick": 0.0, "pushed": {}, "ember_wings": true})
	main.sfx("gust", 0.8, -4.0)


## Bonfire: Rekindle as ever; while you burn, the foes you strike catch fire
## and each grows the payback (player.gd _strike and _tick_fire_bonds).
static func _bonfire(bond, sp: Dictionary, p) -> void:
	bond._cast_type(p)
	p.rekindle_per = float(bond.spell_stat(sp, "per_burning"))
	p.rekindle_most = int(bond.spell_stat(sp, "most"))
	var col: Color = bond.color()
	var tick := func(_n, _d: float) -> bool:
		return is_instance_valid(p) and not p.dead and p.rekindle_t > 0.0
	var paint := func(n):
		if not is_instance_valid(p):
			return
		var at: Vector2 = p.global_position + Vector2(0, 6)
		flame_ring(n, at, Vector2(20, 8), 8, n.age * 3.0, col, 0.8, 7.0 + 1.5 * p.rekindle_burned.size())
	spawn(p.main, float(p.rekindle_total) + 0.1, tick, paint)


## Cauterize: a small heal at once, then Rekindle as ever; its payback comes
## as a barrier instead of health (player.gd).
static func _cauterize(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var heal: float = p.mend_by(p.max_hp * float(bond.spell_stat(sp, "mend")) * p.heal_mult())
	bond._cast_type(p)
	p.rekindle_shield = float(bond.spell_stat(sp, "shield"))
	p.rekindle_shield_t = float(bond.spell_stat(sp, "shield_time"))
	if heal >= 1.0:
		main.fx_text(p.global_position + Vector2(0, -58), TEXT["cauterize"] % int(round(heal)), bond.color())
	main.fx_ring(p.global_position, Color(1.0, 0.85, 0.6), 26.0, 0.25, 3.0)


## Meteor's Apex: where it lands (after `delay`), a crater of your burning ground.
static func crater(bond, p, at: Vector2, r: float, seconds: float, delay: float) -> void:
	var main = p.main
	var col: Color = bond.color()
	FX.later(main, delay, func():
		var n := int(CRATER["patches"])
		main.add_flame(at, float(CRATER["patch"]), seconds, true)
		for i in n:
			main.add_flame(at + Vector2.from_angle(TAU * i / n) * r * float(CRATER["ring"]), float(CRATER["patch"]), seconds, true)
		spawn(main, seconds, Callable(), func(nd):  # the scorched rim
			var a: float = nd.fade(0.8)
			nd.draw_arc(at, r * 0.8, 0.0, TAU, 40, Color(0.18, 0.1, 0.08, 0.5 * a), 6.0, true)
			nd.draw_arc(at, r * 0.8, 0.0, TAU, 40, Color(col, 0.35 * a), 2.0, true)))


# --- what stays a while ------------------------------------------------------------

## Something a spell leaves in the world for `seconds`: spell_fx.gd's shared
## Lasting node. tick(n, delta) returns false to end it early; paint(n)
## draws with n.draw_*; n.age counts up, n.data holds the spell's own state,
## and n.fade(tail) eases out over its last `tail` seconds (0.35 if not given).
static func spawn(main, seconds: float, tick: Callable, paint: Callable, data := {}) -> Node2D:
	return FX.lasting(main, seconds, tick, paint, data, {"fade_in": false, "fade_edge": 0.35})


## Rising tongues of flame in a ring (the game's flames: short thick strokes).
static func flame_ring(n: CanvasItem, at: Vector2, r: Vector2, count: int, t: float, col: Color, a: float, tall := 6.0) -> void:
	for i in count:
		var ang := TAU * i / count + t * 1.3
		var pt := at + Vector2(cos(ang) * r.x, sin(ang) * r.y)
		var h := tall + tall * 0.6 * sin(t * 12.0 + i * 2.1)
		n.draw_line(pt, pt + Vector2(0, -h), Color(col, 0.75 * a), 3.0)
		n.draw_line(pt + Vector2(0, -h * 0.3), pt + Vector2(0, -h * 0.8), Color(1.0, 0.9, 0.6, 0.6 * a), 1.5)


# --- Flame Contractor -----------------------------------------------------------------

## Blazing Trail: a patch of your burning ground every `gap` pixels you walk.
static func _blazing_trail(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dur: float = float(bond.stat("duration")) * (0.6 if bond._overdrawn() else 1.0)  # overdrawn: it gutters out sooner
	var burns := float(bond.stat("burns"))
	var gap := float(bond.stat("gap"))
	main.add_flame(p.global_position, 18.0, burns, true)
	var tick := func(n, _d: float) -> bool:
		if not is_instance_valid(p) or p.dead:
			return false
		if p.global_position.distance_to(n.data["last"]) >= gap:
			main.add_flame(p.global_position, 18.0, burns, true)
			n.data["last"] = p.global_position
		n.data["at"] = p.global_position
		return true
	var paint := func(n):
		var at: Vector2 = n.data["at"] + Vector2(0, 8)
		var a: float = n.fade()
		flame_ring(n, at, Vector2(15, 6), 7, n.age * 4.0, col.lightened(0.2), a, 6.0)
		for i in 4:
			var u := fmod(n.age * 1.6 + i * 0.25, 1.0)
			n.draw_circle(at + Vector2(sin(n.age * 7.0 + i * 1.9) * 9.0, -u * 26.0), 1.6, Color(1.0, 0.75, 0.35, (1.0 - u) * a))
	spawn(main, dur, tick, paint, {"last": p.global_position, "at": p.global_position})
	main.fx_ring(p.global_position, col, 36.0, 0.3, 3.0)
	main.light_flash(p.global_position, col, 1.3, 1.4, 0.3)
	main.sfx("spell_fire", 1.1, -2.0)


## Detonate: the patches of your burning ground nearest you burst, one after
## another (patches close together make one burst); with none, one bigger
## burst where you aim.
static func _detonate(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dmg: float = bond.damage()
	var r := float(bond.stat("radius"))
	var most := int(bond.stat("bursts"))
	var here: Vector2 = p.global_position
	var ground: Array = main.flames.filter(func(f): return f.get("friendly", false) and float(f["t"]) > 0.05)
	ground.sort_custom(func(a, b): return a["pos"].distance_to(here) < b["pos"].distance_to(here))
	var spots: Array = []
	for f in ground:
		if spots.size() >= most:
			break
		if not spots.any(func(s): return s.distance_to(f["pos"]) < r * 0.8):
			spots.append(f["pos"])
	for f in ground:  # (the ground that burst is spent)
		if spots.any(func(s): return s.distance_to(f["pos"]) < r):
			f["t"] = 0.04
	if spots.is_empty():
		spots.append(main.walkable_point(here, here + p.aim * 120.0, 14.0))
		dmg *= 1.5
		r *= 1.3
	for i in spots.size():
		var s: Vector2 = spots[i]
		FX.later(main, 0.08 + 0.07 * i, func():
			main.explode(s, r, dmg, col)
			main.sfx("fire_blast", 0.9 + 0.08 * i, -4.0))
	# Fuses race out from you to each patch.
	var paint := func(n):
		var k := clampf(n.age / 0.12, 0.0, 1.0)
		var from: Vector2 = n.data["from"]
		for i in n.data["spots"].size():
			var to: Vector2 = n.data["spots"][i]
			var kk := clampf(k - i * 0.1, 0.0, 1.0)
			var tip := from.lerp(to, kk)
			n.draw_line(from, tip, Color(col, 0.5 * n.fade(0.2)), 2.0, true)
			n.draw_circle(tip, 3.0, Color(1.0, 0.9, 0.6, n.fade(0.2)))
	spawn(main, 0.15 + 0.07 * spots.size(), Callable(), paint, {"from": here, "spots": spots})
	main.sfx("charge", 1.5, -6.0)


# --- Flamewing --------------------------------------------------------------------

## Cinder Dive: you dive along your aim (stopping at a wall), striking and
## setting burning each foe you pass; it spends the aura's built-up heat.
static func _cinder_dive(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var start: Vector2 = p.global_position
	var end: Vector2 = main.walkable_point(start, start + p.aim * float(bond.stat("dist")), 14.0)
	var dmg: float = bond.damage() + p.aura_heat * 0.3
	p.aura_heat = 0.0
	var burn: float = float(bond.stat("burn")) * bond.power()
	for e in main.targets():
		if Geometry2D.get_closest_point_to_segment(e.global_position, start, end).distance_to(e.global_position) < e.radius + 18.0:
			e.take_hit(dmg, p.aim, 220.0, true)
			e.ignite(burn, float(bond.stat("burn_time")))
	p.global_position = end
	p.iframes = maxf(p.iframes, 0.25)
	for k in 3:
		main.add_flame(start.lerp(end, (k + 0.5) / 3.0), 15.0, 1.5, true)
	var paint := func(n):
		var a: Vector2 = n.data["a"]
		var b: Vector2 = n.data["b"]
		var f: float = n.fade(0.4)
		if a.distance_to(b) < 6.0:
			n.draw_circle(b, 18.0, Color(col, 0.3 * f))
			return
		var dir := (b - a).normalized()
		var side := dir.orthogonal()
		n.draw_colored_polygon(PackedVector2Array([a, b + side * 11.0, b + dir * 16.0, b - side * 11.0]), Color(col, 0.35 * f))
		for i in 6:  # the wings' feathers, swept back
			var u := (i + 1) / 7.0
			var base := a.lerp(b, u)
			var l := (12.0 + 14.0 * u) * f
			n.draw_line(base, base + (side * 0.8 - dir * 0.6).normalized() * l, Color(col.lightened(0.35), 0.75 * f), 2.0, true)
			n.draw_line(base, base + (-side * 0.8 - dir * 0.6).normalized() * l, Color(col.lightened(0.35), 0.75 * f), 2.0, true)
		n.draw_line(a, b, Color(1.0, 0.92, 0.65, 0.85 * f), 2.0, true)
	spawn(main, 0.45, Callable(), paint, {"a": start, "b": end})
	main.light_flash(end, col, 1.6, 1.8, 0.3)
	main.fx_burst(end, p.aim, col, 14, 260.0)
	main.sfx("gust", 1.2)
	main.sfx("spell_fire", 1.0, -2.0)
	main.shake(3.0)
	if bond._overdrawn():
		p.hp = maxf(1.0, p.hp - 5.0)  # an overdrawn dive scorches you too
		main.fx_text(p.global_position + Vector2(0, -30), "-5", col)


## Heat Haze: while the aura burns, shots that enter it burn away and the
## foes in it are set burning. It lights the aura if it's off.
static func _heat_haze(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	if p.aura_part == "":
		for b in p.bonds.values():
			if b.id == "flamewing":
				var keep: int = b.selected
				for i in b.spells().size():
					if b.spells()[i]["type"] == "aura":
						b.select(i)
						b._aura(p)
				b.select(keep)
	var burn: float = float(bond.stat("burn")) * bond.power()
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(p) or p.dead:
			return false
		n.data["at"] = p.global_position
		for pf in n.data["puffs"]:
			pf["t"] -= d
		n.data["puffs"] = n.data["puffs"].filter(func(pf): return pf["t"] > 0.0)
		if p.aura_part == "":
			return true  # (the aura is off: the haze waits)
		var r: float = p.aura_r * (2.0 if p.firebird_t > 0.0 else 1.0)
		n.data["r"] = r
		for c in main.get_children():
			if "reflected" in c and not c.friendly and not c.is_queued_for_deletion() and c.global_position.distance_to(p.global_position) < r:
				n.data["puffs"].append({"pos": c.global_position, "t": 0.5})
				main.fx_burst(c.global_position, Vector2.ZERO, col, 6, 120.0)
				main.sfx("hiss", 1.4, -8.0)
				c.queue_free()
		n.data["tick"] -= d
		if n.data["tick"] <= 0.0:
			n.data["tick"] = 0.5
			for e in main.targets():
				if e.global_position.distance_to(p.global_position) < r + e.radius:
					e.ignite(burn, 1.5)
		return true
	var paint := func(n):
		var at: Vector2 = n.data["at"]
		var a: float = n.fade(0.5) * (1.0 if is_instance_valid(p) and p.aura_part != "" else 0.35)
		var r: float = n.data["r"]
		var t: float = n.age
		for i in 3:  # shimmering rings of heat
			var rr := r * (0.4 + 0.25 * i) + 3.0 * sin(t * 3.0 + i)
			var st := t * (1.2 + 0.4 * i) + i * 2.0
			n.draw_arc(at, rr, st, st + 1.7, 18, Color(col.lightened(0.4), 0.28 * a), 1.5, true)
			n.draw_arc(at, rr, st + PI, st + PI + 1.2, 14, Color(col.lightened(0.4), 0.2 * a), 1.5, true)
		for i in 5:  # wavering lines of rising heat
			var x := (i - 2) * r * 0.3
			var u := fmod(t * 0.8 + i * 0.37, 1.0)
			var pts := PackedVector2Array()
			for k in 5:
				var y := -k * 6.0 - u * 20.0
				pts.append(at + Vector2(x + sin(t * 6.0 + k + i) * 3.0, y + r * 0.3))
			n.draw_polyline(pts, Color(1.0, 0.85, 0.55, 0.3 * a * (1.0 - u)), 1.5, true)
		for pf in n.data["puffs"]:  # what burned away: a puff of smoke
			var k: float = 1.0 - float(pf["t"]) / 0.5
			n.draw_circle(pf["pos"] + Vector2(0, -10.0 * k), 4.0 + 8.0 * k, Color(0.5, 0.45, 0.42, 0.45 * (1.0 - k)))
	spawn(main, float(bond.stat("duration")), tick, paint, {"at": p.global_position, "r": p.aura_r, "tick": 0.0, "puffs": []})
	main.fx_ring(p.global_position, col, p.aura_r, 0.4, 3.0)
	main.sfx("spell_fire", 1.25, -2.0)
	main.sfx("gust", 0.6, -8.0)


# --- Rekindler ----------------------------------------------------------------------

## Flashpoint: a tenth of your health (never your last) feeds a burst of
## fire around you; the lower your health afterwards, the harder it hits.
static func _flashpoint(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var at: Vector2 = p.global_position
	var price: float = minf(p.max_hp * float(bond.stat("price")), maxf(0.0, p.hp - 1.0))
	if price > 0.0:
		p.hp -= price
		main.fx_text(at + Vector2(0, -44), "-%d" % int(round(price)), Color(1.0, 0.45, 0.3))
	var low := clampf(1.0 - p.hp / p.max_hp, 0.0, 1.0)
	var dmg: float = bond.damage() * (1.0 + 1.5 * low)
	var r := float(bond.stat("radius"))
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - at
		if to.length() < r + e.radius:
			e.take_hit(dmg, to.normalized(), 260.0, true)
			e.ignite(2.0 * bond.power(), 2.0)
			hits += 1
	if hits > 0:
		p.rekindle_fought = true  # (it counts as fighting for Rekindle)
	var paint := func(n):
		var k := clampf(n.age / 0.25, 0.0, 1.0)
		var rr: float = r * (1.0 - pow(1.0 - k, 3.0))
		var f: float = n.fade(0.2)
		n.draw_arc(n.data["at"], rr, 0.0, TAU, 40, Color(col, 0.7 * f), 3.0, true)
		for i in 18:
			var d := Vector2.from_angle(TAU * i / 18.0 + 0.3)
			var tall := 10.0 + 6.0 * sin(i * 2.7 + n.age * 20.0)
			n.draw_line(n.data["at"] + d * rr * 0.75, n.data["at"] + d * (rr + tall), Color(col.lightened(0.3), 0.8 * f), 3.0)
	spawn(main, 0.4, Callable(), paint, {"at": at})
	main.fx_burst(at, Vector2.ZERO, col, 22, 320.0)
	main.light_flash(at, col, 1.8, 2.0, 0.35)
	main.sfx("fire_blast", 0.9)
	main.sfx("hit_heavy", 0.9, -4.0)
	main.shake(5.0)


## Backdraft: for a while, any blow that takes 3 or more health bursts into
## fire around you (the bigger the blow, the hotter).
static func _backdraft(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var base: float = bond.damage()
	var r := float(bond.stat("radius"))
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(p) or p.dead:
			return false
		n.data["cd"] -= d
		n.data["at"] = p.global_position
		for b in n.data["bursts"]:
			b["t"] += d
		n.data["bursts"] = n.data["bursts"].filter(func(b): return b["t"] < 0.4)
		var last: float = n.data["last"]
		if p.hp < last - 2.5 and n.data["cd"] <= 0.0:
			n.data["cd"] = 0.3
			var dmg: float = base + (last - p.hp) * 0.5
			for e in main.targets():
				var to: Vector2 = e.global_position - p.global_position
				if to.length() < r + e.radius:
					e.take_hit(dmg, to.normalized(), 240.0, true)
					e.ignite(2.0, 2.0)
			n.data["bursts"].append({"t": 0.0})
			main.fx_burst(p.global_position, Vector2.ZERO, col, 16, 280.0)
			main.fx_text(p.global_position + Vector2(0, -58), TEXT["backdraft"], col)
			main.light_flash(p.global_position, col, 1.5, 1.8, 0.3)
			main.sfx("fire_blast", 1.05)
			main.shake(3.0)
		n.data["last"] = p.hp
		return true
	var paint := func(n):
		var at: Vector2 = n.data["at"]
		var a: float = n.fade(0.5)
		flame_ring(n, at + Vector2(0, -4), Vector2(17, 9), 6, n.age * 3.0, col, a * 0.8, 5.0)
		for b in n.data["bursts"]:
			var k: float = float(b["t"]) / 0.4
			n.draw_arc(at, r * (0.3 + 0.7 * k), 0.0, TAU, 36, Color(col.lightened(0.2), 0.8 * (1.0 - k)), 4.0, true)
	spawn(main, float(bond.stat("duration")), tick, paint, {"last": p.hp, "cd": 0.0, "at": p.global_position, "bursts": []})
	main.fx_ring(p.global_position, col, 40.0, 0.35, 3.0)
	main.sfx("charge", 0.9, -3.0)
	main.sfx("spell_fire", 0.9, -3.0)
