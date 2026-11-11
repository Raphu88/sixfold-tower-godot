extends RefCounted
## The Gryphon's tower (Air): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd.
##
## WORKED EXAMPLE: Stormcaller.
##   Step 2: Overcharge (today's) or Ball Lightning: a slow orb that sparks
##     each foe it passes, and every second lightning leaps from it.
##   Step 3: Forked (today's change: Chain Lightning leaps 2 more times and
##     stuns) or Lingering: the last leap leaves a charged patch.
##   Step 4: Lightning Rod (today's) or Thunderclap (not written yet: it
##     shows as "Coming later" and can't be chosen).
## Windwalker and Hunter: their alternatives are still to come.

const FX := preload("res://scripts/spell_fx.gd")

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
		4: {"id": "thunderclap", "name": "Thunderclap", "placeholder": true, "learn": 4,
			"desc": "a burst that stuns every charged foe"},
	},
	"windwalker": {
		"change": {"name": "Widened", "says": "Gale Lift lifts every foe in a wide cone"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"hunter": {
		"change": {"name": "Charged", "says": "a longer wind-up charges Piercing Shot for triple damage"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
}


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"ball_lightning":
			_ball_lightning(bond, p)
			return true
	return false


## Stormcaller's Lingering: Chain Lightning as it is, then the patch where its last leap struck.
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	if String(bond.id) != "stormcaller" or String(alt.get("id", "")) != "lingering":
		return false
	bond.last_point = null
	bond._cast_type(p)
	if bond.last_point == null:
		return true
	var main = p.main
	var dmg: float = float(bond.spell_stat(sp, "patch_damage")) * bond.spell_power(sp) * bond.flow_power
	var col: Color = bond.color()
	FX.field(main, bond.last_point, float(bond.spell_stat(sp, "patch_radius")), float(bond.spell_stat(sp, "patch")), 0.5, col, func(foes: Array):
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				e.charged = maxf(e.charged, 3.0)
				e.take_hit(dmg, Vector2.ZERO, 0.0))
	return true


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
	main.sfx("zap", 0.7, -3.0)
