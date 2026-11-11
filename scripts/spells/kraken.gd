extends RefCounted
## The Kraken's tower (Water): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd; the
## worked example is scripts/spells/gryphon.gd (Stormcaller).
##
## Tidecaller (Tidal Surge):
##   Step 2: Riptide or Flood: a wide pool of water where foes wade slowly.
##   Step 3: Aimed (today's) or Swelling: the burst stays around you but
##     reaches farther (the library's Wide).
##   Step 4: Carry or Geysers: three geysers burst one after another along
##     your aim, throwing foes off their feet.
## Warden (Barrier), as in the owner's proposal:
##   Step 2: Absorb or Bulwark: a curved wall of water in front of you stops
##     shots for 4 seconds.
##   Step 3: Bursting (today's) or Mirrored: shots that hit the barrier fly back.
##   Step 4: Challenge or Tidebreak: a parry while the barrier holds sends out a wave.
## Deepcaller (Undertow):
##   Step 2: Anchor or Leech: a leech of water clings to a foe and drinks from it.
##   Step 3: Deeper (today's) or Patient: a longer wind-up drains nearly
##     twice as hard (the library's Charged).
##   Step 4: Siphon or Drown: pull a foe under; the more hurt it is, the harder.
##
## Things that last a while are small Lasting nodes under the SpellFx node
## (spell_fx.gd): they pause with the fight and a new floor clears them.

const FX := preload("res://scripts/spell_fx.gd")
const Projectile := preload("res://scripts/projectile.gd")

## A big beast is held only this much as long by a stun.
const BOSS_SHARE := 0.5
## The water of the Warden's water spells (Bulwark, Tidebreak's wave): the
## Warden's own colour is gold, kept for their rims.
const WATER := Color(0.55, 0.82, 0.95)

static var FORKS := {
	"tidecaller": {
		"change": {"name": "Aimed", "says": "Tidal Surge becomes an aimed wave that travels forward"},
		2: {"id": "flood", "name": "Flood", "type": "flood", "learn": 2,
			"desc": "flood a wide circle where you aim for 6 seconds: foes in it wade slowly and take a little damage",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "radius": 90.0, "range": 140.0, "duration": 6.0, "damage": 1.5},
				4: {"radius": 105.0, "damage": 2.0},
			}},
		3: {"id": "swelling", "variation": "wide", "name": "Swelling",
			"desc": "the burst stays around you but reaches farther and shoves harder, a little weaker",
			"steps": {3: {"push": 340.0}}},
		4: {"id": "geysers", "name": "Geysers", "type": "geysers", "learn": 4,
			"desc": "three geysers burst one after another along your aim, each throwing foes off their feet",
			"steps": {
				4: {"cost": 14.0, "windup": 0.45, "damage": 12.0, "radius": 50.0, "count": 3, "spacing": 75.0, "stun": 0.6},
				5: {"damage": 14.0},
			}},
	},
	"warden": {
		"change": {"name": "Bursting", "says": "Barrier bursts with what it absorbed when it breaks"},
		2: {"id": "bulwark", "name": "Bulwark", "type": "bulwark", "learn": 2,
			"desc": "a curved wall of water in front of you stops shots for 4 seconds and holds foes back",
			"steps": {
				2: {"cost": 8.0, "windup": 0.2, "duration": 4.0, "radius": 60.0, "arc": 55.0},
				4: {"duration": 5.0},
			}},
		3: {"id": "mirrored", "variation": "mirrored", "name": "Mirrored",
			"desc": "shots that hit the barrier fly back at their shooter, harder",
			"steps": {3: {"mirror": 1.5}}},
		4: {"id": "tidebreak", "name": "Tidebreak", "type": "tidebreak", "learn": 4,
			"desc": "for 8 seconds a parry while your barrier holds sends out a wave (it raises a thin barrier if you have none)",
			"steps": {
				4: {"cost": 10.0, "windup": 0.2, "duration": 8.0, "shield": 12.0, "damage": 14.0, "width": 120.0, "travel": 300.0, "push": 320.0},
				5: {"damage": 17.0},
			}},
	},
	"deepcaller": {
		"change": {"name": "Deeper", "says": "Undertow drains 5 foes"},
		2: {"id": "leech", "name": "Leech", "type": "leech", "learn": 2,
			"desc": "a leech of water clings to the foe you aim at for 6 seconds, drinking from it every second and giving you half",
			"steps": {
				2: {"cost": 8.0, "windup": 0.25, "reach": 280.0, "duration": 6.0, "damage": 3.0, "heal": 0.5},
				4: {"damage": 4.0},
			}},
		3: {"id": "patient", "variation": "charged", "name": "Patient",
			"desc": "a longer wind-up drains up to 3 foes nearly twice as hard",
			"steps": {3: {}}},
		4: {"id": "drown", "name": "Drown", "type": "drown", "learn": 4,
			"desc": "pull the foe you aim at under: the more hurt it is, the harder it strikes, and a badly hurt foe is held a moment",
			"steps": {
				4: {"cost": 10.0, "windup": 0.35, "reach": 240.0, "damage": 10.0, "missing": 0.3, "most": 40.0, "heal": 0.4, "stun": 1.0},
				5: {"damage": 12.0},
			}},
	},
}

## Words these spells show in play.
static var TEXT := {
	"no_target": "no target",
	"tidebreak": "Tidebreak",
	"mirrored": "Mirrored",
	"leeched": "Leeched",
	"drowned": "Drowned",
}


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"flood":
			_flood(bond, sp, p)
		"geysers":
			_geysers(bond, p)
		"bulwark":
			_bulwark(bond, p)
		"tidebreak":
			_tidebreak(bond, sp, p)
		"leech":
			_leech(bond, sp, p)
		"drown":
			_drown(bond, sp, p)
		_:
			return false
	return true


## Warden's Mirrored runs here; Swelling (Wide) and Patient (Charged) are the library's own.
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	if String(bond.id) == "warden" and String(alt.get("id", "")) == "mirrored":
		_mirrored(bond, sp, p)
		return true
	return false


# --- something that lasts: a small node with its own tick and drawing -------------------

## Lives under the SpellFx node: pauses with the fight, and a new floor
## (SpellFx.clear, which drops its token) ends it.
class Lasting extends Node2D:
	var main
	var t := 1.0
	var total := 1.0
	var age := 0.0
	var tick: Callable  # tick(node, delta)
	var paint: Callable  # paint(node): draws with the node's draw_* calls
	var token := {}

	func _process(delta: float) -> void:
		var fx = get_parent()
		if main == null or not is_instance_valid(main) or fx == null or not fx.timers.has(token):
			queue_free()
			return
		age += delta
		t -= delta
		if tick.is_valid():
			tick.call(self, delta)
		if t <= 0.0:
			finish()
			return
		queue_redraw()

	func finish() -> void:
		var fx = get_parent()
		if fx != null and "timers" in fx:
			fx.timers.erase(token)
		queue_free()

	## 0 to 1 as it starts, 1 to 0 as it ends (over `edge` seconds).
	func fade(edge := 0.3) -> float:
		return clampf(age / 0.12, 0.0, 1.0) * clampf(t / edge, 0.0, 1.0)

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


static func _lasting(main, seconds: float, tick: Callable, paint: Callable) -> Lasting:
	var fx = FX.of(main)
	if fx == null:
		return null
	var n := Lasting.new()
	n.main = main
	n.t = seconds
	n.total = maxf(seconds, 0.01)
	n.tick = tick
	n.paint = paint
	n.token = {"t": INF, "fn": Callable(), "lasting": n.get_instance_id()}  # (never fires; SpellFx.clear drops it)
	fx.timers.append(n.token)
	fx.add_child(n)
	return n


static func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead


## The monsters' shots in flight (projectile.gd, not yours or turned back).
static func _foe_shots(main) -> Array:
	return main.get_children().filter(func(c): return c.get_script() == Projectile and not c.friendly and not c.is_queued_for_deletion())


## Water drawn in the game's way: a pale pool, a bright rim and drifting ripples.
static func _draw_water(n, at: Vector2, r: float, col: Color, a: float) -> void:
	n.draw_circle(at, r, Color(col.darkened(0.2), 0.28 * a))
	n.draw_circle(at, r * 0.8, Color(col, 0.12 * a))
	n.draw_arc(at, r, 0.0, TAU, 44, Color(col.lightened(0.35), 0.7 * a), 2.0, true)
	for k in 3:
		var u := fmod(n.age * 0.45 + float(k) / 3.0, 1.0)
		n.draw_arc(at, r * (0.2 + 0.75 * u), 0.0, TAU, 32, Color(1, 1, 1, 0.3 * a * (1.0 - u)), 1.2, true)
	for k in 6:
		var ang := float(k) * TAU / 6.0 + sin(n.age * 0.8 + k) * 0.4
		var pos := at + Vector2.from_angle(ang) * r * (0.35 + 0.4 * fmod(float(k) * 0.37 + n.age * 0.2, 1.0))
		n.draw_line(pos - Vector2(4, 0), pos + Vector2(4, 0), Color(1, 1, 1, 0.35 * a), 1.2, true)


# --- Tidecaller --------------------------------------------------------------------------

## Flood: a pool where foes wade slowly (a Coral Trident's chill: enemy.gd
## chill_t) and take a little damage every half second. Fliers pass over it.
static func _flood(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var at: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(bond.stat("range")), 14.0)
	var dmg: float = bond.damage()
	var st := {"tick": 0.0}
	var tick := func(_n, delta: float):
		st["tick"] -= delta
		if st["tick"] > 0.0:
			return
		st["tick"] = 0.5
		for e in main.targets():
			if e.airborne > 0.0 or e.kind in e.FLIERS or e.global_position.distance_to(at) > radius + e.radius * 0.5:
				continue
			e.chill_t = maxf(e.chill_t, 0.7)
			e.take_hit(dmg, Vector2.ZERO, 0.0)
	var paint := func(n):
		_draw_water(n, at, radius * clampf(n.age / 0.35, 0.2, 1.0), col, n.fade(0.6))
	_lasting(main, float(bond.stat("duration")), tick, paint)
	main.fx_burst(at, Vector2.ZERO, col, 18, 240.0)
	main.light_flash(at, col, 1.4, 0.9, 0.4)
	main.sfx("hit_slime", 0.5)
	main.sfx("gust", 0.6, -6.0)


## Geysers: a line of spots along your aim (stopping at a wall), each
## marked a moment before it bursts; each burst strikes and staggers the
## foes on it.
static func _geysers(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var spacing := float(bond.stat("spacing"))
	var stun := float(bond.stat("stun"))
	var dmg: float = bond.damage()
	var spots: Array = []
	for i in maxi(1, int(bond.stat("count"))):
		var at: Vector2 = p.global_position + p.aim * spacing * float(i + 1)
		if main.is_solid(at) or not main.room.has_point(at):
			break
		spots.append(at)
	if spots.is_empty():
		spots.append(p.global_position + p.aim * 30.0)
	for i in spots.size():
		var at: Vector2 = spots[i]
		var delay := 0.18 + 0.2 * float(i)
		FX.mark(main, at, delay, col)
		FX.later(main, delay, func():
			_geyser_burst(main, at, radius, dmg, stun, col))
	main.sfx("hit_slime", 0.6, -4.0)


static func _geyser_burst(main, at: Vector2, radius: float, dmg: float, stun: float, col: Color) -> void:
	for e in main.targets():
		var to: Vector2 = e.global_position - at
		if to.length() > radius + e.radius:
			continue
		e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.RIGHT, 160.0)
		if _alive(e):
			e.stagger(stun * (BOSS_SHARE if e.is_boss() else 1.0))
	var paint := func(n):
		var k: float = clampf(n.age / n.total, 0.0, 1.0)
		var a: float = 1.0 - k
		var h := 70.0 * sin(minf(k * 1.6, 1.0) * PI * 0.5) * (1.0 - k * 0.5)
		var w := radius * 0.45
		n.draw_circle(at, radius * (0.6 + 0.4 * k), Color(col, 0.18 * a))
		n.draw_arc(at, radius * (0.6 + 0.5 * k), 0.0, TAU, 32, Color(col.lightened(0.4), 0.7 * a), 2.0, true)
		# The jet: a column of water up the screen, white at its heart.
		var jet := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w * 0.55, -h), at + Vector2(0, -h - 10.0), at + Vector2(w * 0.55, -h), at + Vector2(w, 0)])
		n.draw_colored_polygon(jet, Color(col.lightened(0.15), 0.55 * a))
		n.draw_line(at, at + Vector2(0, -h), Color(1, 1, 1, 0.7 * a), 3.0, true)
		for i in 7:
			var ang := -PI * 0.5 + (float(i) - 3.0) * 0.35
			var fly := Vector2.from_angle(ang) * (h * 0.4 + 30.0 * k) + Vector2(0, 60.0 * k * k)
			n.draw_circle(at + Vector2(0, -h * 0.8) + fly, 2.5, Color(1, 1, 1, 0.7 * a))
	_lasting(main, 0.55, Callable(), paint)
	main.fx_burst(at, Vector2.UP, col, 14, 260.0)
	main.light_flash(at, col, 1.2, 1.2, 0.3)
	main.sfx("hit_slime", 0.7)
	main.sfx("gust", 1.2, -6.0)
	main.shake(3.0)


# --- Warden --------------------------------------------------------------------------------

## Bulwark: a curved wall of water where you stand, across your aim. The
## monsters' shots that reach it are stopped, and foes walking into it from
## the far side are held back. It stays where it was raised.
static func _bulwark(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var radius := float(bond.stat("radius"))
	var half := deg_to_rad(float(bond.stat("arc")))
	var center: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var on_wall := func(pos: Vector2, band: float) -> bool:
		var rel := pos - center
		return absf(rel.length() - radius) <= band and absf(aim.angle_to(rel)) <= half + 0.1
	var tick := func(_n, delta: float):
		for s in _foe_shots(main):
			var prev: Vector2 = s.position - s.vel * delta
			var crossed: bool = (prev.distance_to(center) - radius) * (s.position.distance_to(center) - radius) <= 0.0
			if on_wall.call(s.position, 12.0) or (crossed and absf(aim.angle_to(s.position - center)) <= half + 0.1):
				main.fx_burst(s.position, -s.vel.normalized(), WATER, 7, 170.0)
				main.sfx("hit_slime", 1.4, -8.0)
				s.queue_free()
		for e in main.targets():
			var rel: Vector2 = e.global_position - center
			if absf(aim.angle_to(rel)) > half + 0.1:
				continue
			var d := rel.length()
			if d < radius + e.radius + 4.0 and d > radius - 16.0:
				if e.knock.dot(rel.normalized()) < 160.0:
					e.knock = rel.normalized() * 180.0
	var paint := func(n):
		var a: float = n.fade(0.4)
		var from := aim.angle() - half
		var to := aim.angle() + half
		n.draw_arc(center, radius, from, to, 28, Color(WATER.darkened(0.15), 0.4 * a), 12.0, true)
		n.draw_arc(center, radius + 3.0, from, to, 28, Color(col.lightened(0.35), 0.85 * a), 2.0, true)
		n.draw_arc(center, radius - 4.0, from, to, 28, Color(WATER.lightened(0.3), 0.7 * a), 1.5, true)
		for k in 7:
			var u := fmod(n.age * 0.6 + float(k) / 7.0, 1.0)
			var ang := lerpf(from, to, u)
			var pos := center + Vector2.from_angle(ang) * (radius + sin(n.age * 5.0 + k) * 3.0)
			n.draw_circle(pos, 2.0, Color(1, 1, 1, 0.65 * a))
		for k in 2:
			var ang2 := from if k == 0 else to
			var pos2 := center + Vector2.from_angle(ang2) * radius
			n.draw_circle(pos2 + Vector2(0, 4.0 + 6.0 * fmod(n.age * 2.0 + k * 0.5, 1.0)), 1.8, Color(WATER.lightened(0.4), 0.7 * a))
	_lasting(main, float(bond.stat("duration")), tick, paint)
	main.fx_burst(center + aim * radius, aim, WATER, 14, 220.0)
	main.light_flash(center + aim * radius, col, 1.1, 1.0, 0.3)
	main.sfx("hit_slime", 0.8)
	main.sfx("parry", 0.6, -8.0)


## Warden's Mirrored: Barrier as it is (without today's burst), and while
## it holds, the monsters' shots that reach it fly back at their shooter,
## `mirror` times as hard.
static func _mirrored(bond, sp: Dictionary, p) -> void:
	bond._cast_type(p)
	var main = p.main
	var col: Color = bond.color()
	var mult := float(bond.spell_stat(sp, "mirror"))
	var st := {"flash": 0.0}
	var tick := func(n, delta: float):
		st["flash"] = maxf(0.0, st["flash"] - delta)
		if p == null or not is_instance_valid(p) or p.dead or (p.barrier_hp <= 0.0 and n.age > 0.1):
			n.finish()
			return
		for s in _foe_shots(main):
			if s.position.distance_to(p.global_position) > p.radius + 20.0:
				continue
			s.reflected = true
			s.friendly = true
			s.dmg *= mult
			s.force = 220.0
			s.life = 2.0
			s.vel = -s.vel * 1.15
			st["flash"] = 0.25
			main.fx_burst(s.position, s.vel.normalized(), col, 8, 200.0)
			main.fx_text(p.global_position + Vector2(0, -36), TEXT["mirrored"], col)
			main.sfx("parry", 1.4, -6.0)
	var paint := func(n):
		if p == null or not is_instance_valid(p):
			return
		var c: Vector2 = p.global_position
		var r: float = p.radius + 16.0
		var a: float = 0.45 + 0.55 * clampf(st["flash"] / 0.25, 0.0, 1.0)
		# Silver facets turning slowly over the barrier's dome: it throws shots back.
		for k in 6:
			var ang: float = n.age * 0.8 + float(k) * TAU / 6.0
			n.draw_arc(c, r, ang, ang + 0.6, 6, Color(0.9, 0.95, 1.0, 0.55 * a), 2.0, true)
			n.draw_line(c + Vector2.from_angle(ang + 0.3) * (r - 4.0), c + Vector2.from_angle(ang + 0.3) * (r + 4.0), Color(col.lightened(0.5), 0.6 * a), 1.5, true)
	_lasting(main, float(bond.spell_stat(sp, "duration")) + 0.2, tick, paint)


## Tidebreak: for a while, every parry made while your barrier holds sends
## an aimed wave out (main.gd add_wave, as Tidal Surge's). It raises a thin
## barrier if none holds. (No parry hook in player.gd: it watches the
## parry's flash, player.gd parry_flash, which every parry sets.)
static func _tidebreak(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dur := float(bond.stat("duration"))
	if p.barrier_hp <= 0.0:
		p.raise_barrier(float(bond.stat("shield")) * bond.spell_power(sp), dur, bond._burst_known(), col)
	var width := float(bond.stat("width"))
	var travel := float(bond.stat("travel"))
	var push := float(bond.stat("push"))
	var dmg: float = bond.damage()
	var st := {"last": p.parry_flash, "swell": 0.0}
	var tick := func(n, delta: float):
		st["swell"] = maxf(0.0, st["swell"] - delta)
		if p == null or not is_instance_valid(p) or p.dead:
			n.finish()
			return
		if p.parry_flash > float(st["last"]) + 0.05 and p.barrier_hp > 0.0:
			main.add_wave(p.global_position, p.aim, width, travel, dmg, push, false, WATER)
			main.fx_text(p.global_position + Vector2(0, -48), TEXT["tidebreak"], col)
			main.sfx("hit_slime", 0.6)
			main.sfx("gust", 0.8, -4.0)
			main.shake(4.0)
			st["swell"] = 0.4
		st["last"] = p.parry_flash
	var paint := func(n):
		if p == null or not is_instance_valid(p):
			return
		var c: Vector2 = p.global_position
		var a: float = n.fade(0.5) * (0.6 if p.barrier_hp > 0.0 else 0.25)
		var r: float = p.radius + 12.0 + 10.0 * st["swell"]
		# Water circling the climber, and a crest on the side you face.
		for k in 3:
			var ang: float = n.age * (2.0 + k * 0.6) + k * 2.0
			n.draw_arc(c, r + k * 3.0, ang, ang + 1.4, 12, Color((WATER if k < 2 else col).lightened(0.15 * k), 0.7 * a), 2.0, true)
		var side: Vector2 = p.aim.orthogonal()
		var crest: Vector2 = c + p.aim * (r + 6.0)
		n.draw_line(crest - side * 9.0, crest + side * 9.0, Color(1, 1, 1, 0.8 * a + 0.2 * st["swell"]), 2.0, true)
	_lasting(main, dur, tick, paint)
	main.fx_ring(p.global_position, col, 40.0, 0.35, 3.0)
	main.sfx("hit_slime", 0.9, -4.0)
	main.sfx("parry", 0.7, -8.0)


# --- Deepcaller ------------------------------------------------------------------------------

## Leech: clings to the foe you aim at; every second it takes `damage` and
## you drink `heal` of it back. Each cast is its own leech.
static func _leech(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var target = bond._target_in_aim(p, float(bond.stat("reach")))
	if target == null:
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["no_target"], col)
		return
	var dmg: float = bond.damage()
	var heal := float(bond.stat("heal"))
	# (The foe is held in `st`: a lambda mustn't capture a foe that may be freed.)
	var st := {"tick": 1.0, "drop": -1.0, "e": target}
	var tick := func(n, delta: float):
		if not _alive(st["e"]):
			n.finish()
			return
		st["tick"] -= delta
		st["drop"] -= delta
		if st["tick"] <= 0.0:
			st["tick"] = 1.0
			st["drop"] = 0.35
			st["e"].take_hit(dmg, Vector2.ZERO, 0.0)
			if _alive(p):
				p.hp = minf(p.max_health(), p.hp + dmg * heal * p.heal_mult())
	var paint := func(n):
		var e = st["e"]
		if not _alive(e):
			return
		var a: float = n.fade(0.4)
		var at: Vector2 = e.global_position + Vector2(0, -e.radius * 0.4)
		var wob := sin(n.age * 6.0) * 1.5
		n.draw_circle(at, 7.0 + wob, Color(0.06, 0.05, 0.07, 0.6 * a))
		n.draw_circle(at, 5.5 + wob, Color(col, 0.95 * a))
		n.draw_circle(at + Vector2(-1.5, -2.0), 1.8, Color(1, 1, 1, 0.7 * a))
		# A drop of what it drank, carried back to you.
		if st["drop"] > 0.0 and _alive(p):
			var k: float = 1.0 - st["drop"] / 0.35
			var pos: Vector2 = at.lerp(p.global_position, k) + Vector2(0, -sin(k * PI) * 18.0)
			n.draw_circle(pos, 3.0, Color(col.lightened(0.3), 0.9))
			n.draw_circle(pos, 6.0, Color(col, 0.25))
	_lasting(main, float(bond.stat("duration")), tick, paint)
	main.fx_bolt([p.global_position, target.global_position], col)
	main.fx_text(target.global_position + Vector2(0, -target.radius - 22.0), TEXT["leeched"], col)
	main.sfx("hit_slime", 1.2, -4.0)


## Drown: the foe you aim at is pulled under: `damage`, plus `missing` of
## the health it has lost (at most `most` more), and you drink `heal` of it.
## A foe below half health is also held (`stun`, half for a beast).
static func _drown(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var e = bond._target_in_aim(p, float(bond.stat("reach")))
	if e == null:
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["no_target"], col)
		return
	var extra: float = minf(float(bond.stat("most")), float(bond.stat("missing")) * maxf(0.0, e.max_hp - e.hp))
	var dmg: float = bond.damage() + extra * bond.spell_power(sp) * bond.flow_power
	var hurt: bool = e.hp < e.max_hp * 0.5
	var at: Vector2 = e.global_position
	var r: float = e.radius
	e.take_hit(dmg, Vector2.ZERO, 0.0, true)
	if hurt and _alive(e):
		e.stagger(float(bond.stat("stun")) * (BOSS_SHARE if e.is_boss() else 1.0))
		main.fx_text(at + Vector2(0, -r - 22.0), TEXT["drowned"], col)
	p.hp = minf(p.max_health(), p.hp + dmg * float(bond.stat("heal")) * p.heal_mult())
	var held := {"e": e}  # (a lambda mustn't capture a foe that may be freed)
	var paint := func(n):
		var k: float = clampf(n.age / n.total, 0.0, 1.0)
		var a: float = 1.0 - k
		var c: Vector2 = held["e"].global_position if _alive(held["e"]) else at
		# Water closes over the foe in a tightening whirl; bubbles rise from it.
		for i in 3:
			var rr: float = (r + 26.0) * (1.0 - k * 0.6) - i * 6.0
			var st: float = -n.age * (6.0 + i) + i * 2.0
			n.draw_arc(c, maxf(rr, 4.0), st, st + 3.6, 20, Color(col.lightened(0.15 * i), 0.8 * a), 3.0 - i * 0.6, true)
		n.draw_circle(c, r + 4.0, Color(col.darkened(0.3), 0.3 * a))
		for i in 6:
			var u := fmod(k * 1.8 + float(i) / 6.0, 1.0)
			n.draw_arc(c + Vector2(sin(i * 2.7) * r * 0.7, -u * 34.0), 2.0 + i % 3, 0.0, TAU, 10, Color(1, 1, 1, 0.7 * a * (1.0 - u)), 1.2, true)
	_lasting(main, 0.7, Callable(), paint)
	main.fx_bolt([at, p.global_position], col)
	main.fx_burst(at, Vector2.UP, col, 14, 220.0)
	main.light_flash(at, col, 1.2, 1.2, 0.35)
	main.sfx("hit_slime", 0.5)
	main.sfx("zap", 0.5, -6.0)
	main.hitstop(0.05)
	if bond._overdrawn():
		p.hp = maxf(1.0, p.hp - 6.0)  # an overdrawn drain drinks from you too, like Undertow
