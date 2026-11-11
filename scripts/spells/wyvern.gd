extends RefCounted
## The Wyvern's tower (Iron and Fire): its bonds' fork alternatives, and the
## code that runs them. The content contract is at the top of library.gd;
## the worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Blade Forger
##     Step 2: Recall (today's) or Tethered Blade: one heavy blade on an iron
##       chain skewers the first foe in its path and drags it to you.
##     Step 3: Five Blades (today's change) or Back to Back (Mirrored): the
##       fan also flies out behind you, each blade a little weaker.
##     Step 4: Bladeward (today's) or Falling Swords: three great swords hang
##       over the spot you aim at, then fall one after another.
##   Flameblade
##     Step 2: Flame Lash (today's) or Flame Wheel: a burning spin that
##       strikes every foe around you, sets them burning and heats your weapon.
##     Step 3: Sustained (today's change) or Ring of Embers (Lingering): the
##       floor around you burns while your weapon is kindled.
##     Step 4: Searing Parry (today's) or Blazing Lunge: you lunge through
##       foes along your aim, untouchable, burning each one you pass.
##   Rune Artist (the bench and the camps answer to the bond, not to a spell,
##   so its crafting works whichever side is chosen)
##     Step 2: Inscribe (today's) or Rune Brand: a rune on the foe you aim at
##       that bursts the next time it's hurt.
##     Step 3: Linked (today's change) or Afterglow (Lingering): a rune that
##       goes off leaves its glyph glowing, slowing and searing foes in it.
##     Step 4: Ward Circle (today's) or Binding Circle: a circle at your aim
##       that foes can walk into but not out of.
##
## What these spells leave in the world for a while is drawn by this file's
## own small node (Drawer, under main as "WyvernFx"): library.gd has no hook
## for a content file's own drawings, so it lives here, and like spell_fx.gd
## it forgets everything when a new floor starts.

const FX := preload("res://scripts/spell_fx.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")

static var FORKS := {
	"blade_forger": {
		"change": {"name": "Five Blades", "says": "Conjured Blades throws five blades"},
		2: {"id": "tethered_blade", "name": "Tethered Blade", "type": "tethered_blade", "learn": 2,
			"desc": "one heavy blade on an iron chain skewers the first foe in its path and drags it to you",
			"steps": {
				2: {"cost": 9.0, "windup": 0.3, "damage": 14.0, "range": 260.0, "speed": 640.0, "drag": 0.6, "stagger": 0.6},
				4: {"damage": 17.0},
				5: {"damage": 20.0},
			}},
		3: {"id": "back_to_back", "variation": "mirrored", "name": "Back to Back",
			"desc": "Conjured Blades also fans out behind you, each blade a little weaker",
			"steps": {3: {"count": 3}}},
		4: {"id": "falling_swords", "name": "Falling Swords", "type": "falling_swords", "learn": 4,
			"desc": "three great swords hang over the spot you aim at, then fall one after another, each striking hard where it lands",
			"steps": {
				4: {"cost": 14.0, "windup": 0.35, "damage": 16.0, "count": 3, "range": 150.0, "radius": 34.0, "delay": 0.7},
				5: {"damage": 20.0},
			}},
	},
	"flameblade": {
		"change": {"name": "Sustained", "says": "Kindle Blade lasts as long as you keep landing strikes"},
		2: {"id": "flame_wheel", "name": "Flame Wheel", "type": "flame_wheel", "learn": 2,
			"desc": "you spin with your burning weapon: every foe around you is struck and set burning, and each one heats your weapon",
			"steps": {
				2: {"cost": 9.0, "windup": 0.25, "damage": 9.0, "radius": 72.0, "burn": 1.5, "burning": 2.0, "heat": 12.0},
				4: {"damage": 11.0},
				5: {"damage": 13.0},
			}},
		3: {"id": "ring_of_embers", "variation": "lingering", "name": "Ring of Embers",
			"desc": "Kindle Blade also sets the floor around you burning for 4 seconds, scorching foes that cross it",
			"steps": {3: {"sustain": false, "embers": 4.0, "ember_ring": 58.0}}},
		4: {"id": "blazing_lunge", "name": "Blazing Lunge", "type": "blazing_lunge", "learn": 4,
			"desc": "you lunge along your aim through foes, untouchable, burning each one you pass; your weapon heats up",
			"steps": {
				4: {"cost": 10.0, "windup": 0.15, "damage": 15.0, "distance": 150.0, "burn": 2.0, "burning": 2.0, "heat": 30.0},
				5: {"damage": 19.0},
			}},
	},
	"rune_artist": {
		"change": {"name": "Linked", "says": "setting off one rune sets off them all"},
		2: {"id": "rune_brand", "name": "Rune Brand", "type": "rune_brand", "learn": 2,
			"desc": "brand the foe you aim at with a rune: the next time it is hurt, the rune bursts against it and the foes around it",
			"steps": {
				2: {"cost": 8.0, "windup": 0.3, "damage": 16.0, "blast": 55.0, "range": 300.0, "duration": 10.0},
				4: {"damage": 19.0},
				5: {"damage": 22.0},
			}},
		3: {"id": "afterglow", "variation": "lingering", "name": "Afterglow",
			"desc": "a Rune Trap that goes off leaves its glyph glowing for 3 seconds, slowing and searing foes in it",
			"steps": {3: {"linked": false, "glow": 3.0, "glow_damage": 3.0}}},
		4: {"id": "binding_circle", "name": "Binding Circle", "type": "binding_circle", "learn": 4,
			"desc": "a rune circle at your aim holds every foe in it: they can walk in but not out for 4 seconds",
			"steps": {4: {"cost": 14.0, "windup": 0.35, "duration": 4.0, "radius": 72.0, "range": 120.0}}},
	},
}

## Words these spells show in the world.
static var TEXT := {
	"no_target": "no target",
	"branded": "Branded",
	"bound": "Bound",
}


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"tethered_blade":
			_tethered_blade(bond, p)
		"falling_swords":
			_falling_swords(bond, p)
		"flame_wheel":
			_flame_wheel(bond, p)
		"blazing_lunge":
			_blazing_lunge(bond, p)
		"rune_brand":
			_rune_brand(bond, p)
		"binding_circle":
			_binding_circle(bond, p)
		_:
			return false
	return true


## The step-3 variations this file runs itself (Back to Back is the library's
## own Mirrored: it returns false and the library casts it).
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match String(alt.get("id", "")):
		"ring_of_embers":
			if String(bond.id) != "flameblade":
				return false
			_ring_of_embers(bond, sp, p)
			return true
		"afterglow":
			if String(bond.id) != "rune_artist":
				return false
			_afterglow(bond, sp, p)
			return true
	return false


# --- Blade Forger ---------------------------------------------------------------------

## Tethered Blade: the blade flies out along your aim; the first foe it meets
## is skewered (staggered) and dragged back to you along the chain (a beast is
## too heavy: it's only struck). Then the blade comes home. Weapon Memory: a
## heavier weapon makes it hit harder, a bow throws it faster.
static func _tethered_blade(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var shape: Dictionary = p.Weapons.memory(p.weapon)
	var dmg: float = bond.damage() * lerpf(1.0, float(shape["mult"]), 0.5)
	var speed: float = float(bond.stat("speed")) * float(shape["speed"]) / 560.0
	var st := {"pos": p.global_position + p.aim * (p.radius + 4.0), "dir": p.aim, "gone": 0.0, "phase": "out", "foe": null,
		"drag": float(bond.stat("drag")), "range": float(bond.stat("range")), "stagger": float(bond.stat("stagger"))}
	var tick := func(it: Dictionary, delta: float):
		if not is_instance_valid(p):
			it["done"] = true
			return
		match String(st["phase"]):
			"out":
				var step: float = speed * delta
				var next: Vector2 = st["pos"] + st["dir"] * step
				if main.is_solid(next) or float(st["gone"]) >= float(st["range"]):
					st["phase"] = "back"
					main.sfx("hit_armor", 1.3, -8.0)
					return
				st["pos"] = next
				st["gone"] += step
				for e in main.targets():
					if e.global_position.distance_to(next) <= e.radius + 7.0:
						e.take_hit(dmg, st["dir"], 0.0, true)
						main.fx_burst(e.global_position, -st["dir"], col, 10, 200.0)
						main.sfx("hit_stab", 0.9)
						main.hitstop(0.05)
						if e.dead or e.is_boss():
							st["phase"] = "back"
						else:
							e.stagger(float(st["stagger"]))
							st["foe"] = e
							st["phase"] = "drag"
							main.sfx("step_chain", 0.8, -2.0)
						break
			"drag":
				var e = st["foe"]
				st["drag"] -= delta
				if not is_instance_valid(e) or e.dead or float(st["drag"]) <= 0.0:
					st["phase"] = "back"
					return
				var to: Vector2 = p.global_position - e.global_position
				var stop: float = p.radius + e.radius + 14.0
				if to.length() <= stop:
					st["phase"] = "back"
					return
				e.move_and_collide(to.normalized() * minf(to.length() - stop, 560.0 * delta))
				st["pos"] = e.global_position - to.normalized() * e.radius
			"back":
				var home: Vector2 = p.global_position - st["pos"]
				if home.length() <= p.radius + 8.0:
					it["done"] = true
					return
				st["dir"] = -home.normalized()
				st["pos"] += home.normalized() * minf(home.length(), speed * 1.3 * delta)
	var paint := func(b, _it: Dictionary):
		if not is_instance_valid(p):
			return
		var from: Vector2 = p.global_position + (st["pos"] - p.global_position).normalized() * (p.radius * 0.6)
		var to: Vector2 = st["pos"]
		var d: Vector2 = to - from
		var n := int(d.length() / 7.0)
		b.line(from, to, Color(Palette.OUTLINE, 0.6), 3.4)
		for i in n:  # the chain: links of iron, every other one turned
			var at: Vector2 = from + d * (float(i) + 0.5) / maxf(1.0, float(n))
			b.circle(at, 2.2 if i % 2 == 0 else 1.6, Palette.STEEL.darkened(0.2 if i % 2 == 0 else 0.4), 10)
		var dir: Vector2 = st["dir"]
		var side := dir.orthogonal()
		b.circle(to, 10.0, Color(col, 0.18))
		b.poly(PackedVector2Array([to + dir * 15.0, to + side * 4.5, to - dir * 9.0, to - side * 4.5]), col.lightened(0.15), 1.2)
		b.line(to - dir * 7.0, to + dir * 12.0, Color(1, 1, 1, 0.85), 1.0)
		b.line(to - dir * 9.0 + side * 6.0, to - dir * 9.0 - side * 6.0, Palette.STEEL.darkened(0.35), 2.5)
	_add(main, 3.0, tick, paint, true)
	main.sfx("swing", 1.1)
	main.sfx("spell_blade", 1.0, -2.0)
	main.light_flash(p.global_position + p.aim * 30.0, col, 0.9, 0.9, 0.2)


## Falling Swords: the swords hang over the foe you aim at (or the spot
## `range` ahead), a little apart, and fall one after another; each strikes
## the foes under it hard and staggers them.
static func _falling_swords(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var dmg: float = bond.damage()
	var r := float(bond.stat("radius"))
	var count := maxi(1, int(bond.stat("count")))
	var delay := float(bond.stat("delay"))
	var target = _aimed(p, float(bond.stat("range")) + 110.0)
	var center: Vector2 = target.global_position if target != null else p.global_position + p.aim * float(bond.stat("range"))
	center = main.walkable_point(p.global_position, center, 10.0)
	for i in count:
		var spot := center + (Vector2.from_angle(TAU * i / count - PI * 0.5) * r * 0.8 if count > 1 else Vector2.ZERO)
		var land := delay + 0.16 * i
		var st := {"landed": false}
		var tick := func(it: Dictionary, _delta: float):
			if st["landed"] or float(it["age"]) < land:
				return
			st["landed"] = true
			for e in main.targets():
				var to: Vector2 = e.global_position - spot
				if to.length() <= r + e.radius:
					e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.ZERO, 160.0, true)
					if not e.dead and not e.is_boss():
						e.stagger(0.35)
			main.fx_ring(spot, col, r, 0.3, 4.0)
			main.fx_burst(spot, Vector2.ZERO, Palette.STEEL, 10, 220.0)
			main.light_flash(spot, col, 1.0, 1.4, 0.25)
			main.sfx("hit_heavy", 0.75 + 0.08 * i)
			main.sfx("equip_sword", 0.7, -6.0)
			main.shake(3.5)
		var paint := func(b, it: Dictionary):
			var age: float = it["age"]
			if not st["landed"]:
				var k := clampf(age / land, 0.0, 1.0)
				b.circle(spot, r, Color(col, 0.06 + 0.1 * k))
				b.arc(spot, lerpf(r + 14.0, r, k), 0.0, TAU, 32, Color(col, 0.35 + 0.4 * k), 1.5)
				_shadow(b, spot, 6.0 + 8.0 * k, 0.15 + 0.3 * k)
				var hang: Vector2 = spot + Vector2(0, -36.0 - 150.0 * (1.0 - k) * (1.0 - k))
				b.circle(hang + Vector2(0, 14), 14.0, Color(col, 0.16))
				_great_sword(b, hang, col, 1.0)
			else:
				var fade := clampf((float(it["t"])) / 0.3, 0.0, 1.0)
				_shadow(b, spot, 12.0, 0.4 * fade)
				_great_sword(b, spot + Vector2(0, -24), col, fade)
		_add(main, land + 0.6, tick, paint, true)
	main.sfx("spell_iron")
	main.sfx("charge", 0.7, -6.0)
	main.light_flash(center, col, 1.2, 1.0, 0.35)


## A great sword hanging point-down from its crossguard at `grip`.
static func _great_sword(b, grip: Vector2, col: Color, a: float) -> void:
	var tip := grip + Vector2(0, 26)
	var top := grip - Vector2(0, 10)
	b.line(top, tip, Color(Palette.OUTLINE, 0.6 * a), 7.0)
	b.polygon(PackedVector2Array([grip + Vector2(-3.2, 0), grip + Vector2(3.2, 0), tip + Vector2(0, 2)]), Color(Palette.STEEL.lightened(0.1), a))
	b.line(grip + Vector2(1.0, 1), tip + Vector2(0.4, -2), Color(1, 1, 1, 0.7 * a), 1.0)
	b.line(grip + Vector2(-8, 0), grip + Vector2(8, 0), Color(Palette.OUTLINE, a), 4.5)
	b.line(grip + Vector2(-7, 0), grip + Vector2(7, 0), Color(col.darkened(0.2), a), 2.5)
	b.line(grip, top, Color(Palette.WOOD.darkened(0.3), a), 3.0)
	b.circle(top, 2.6, Color(col, a), 12)
	b.circle(grip + Vector2(0, 8), 8.0, Color(col, 0.12 * a))


# --- Flameblade ---------------------------------------------------------------------------

## Flame Wheel: every foe within `radius` is struck and set burning (`burn`
## every half second for `burning` seconds); each foe struck heats the
## weapon by `heat` (Heat, the bond's passive).
static func _flame_wheel(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var r := float(bond.stat("radius"))
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= r + e.radius:
			e.take_hit(bond.damage(), to.normalized() if to.length() > 0.1 else p.aim, 150.0)
			e.ignite(float(bond.stat("burn")) * bond.power(), float(bond.stat("burning")))
			hits += 1
	p.heat = minf(100.0, p.heat + float(bond.stat("heat")) * hits)
	var start: float = p.aim.angle()
	var paint := func(b, it: Dictionary):
		if not is_instance_valid(p):
			return
		var k := clampf(float(it["age"]) / 0.3, 0.0, 1.0)
		var fade := clampf(float(it["t"]) / 0.15, 0.0, 1.0)
		var c: Vector2 = p.global_position
		var head := start + TAU * k
		b.circle(c, r, Color(col, 0.07 * fade))
		for j in 3:  # the wheel's trail, hotter toward its head
			var tail := head - 1.6 - 0.5 * j
			b.arc(c, r * (0.62 + 0.13 * j), tail, head, 18, Color(col.lightened(0.15 * j), (0.35 + 0.2 * j) * fade), 4.0 - j)
		for i in 7:  # flame tongues licking up off the rim
			var a := head - float(i) * 0.28
			var at := c + Vector2.from_angle(a) * r * 0.85
			var h := (10.0 - i) * (0.8 + 0.3 * sin(float(it["age"]) * 30.0 + i))
			b.line(at, at + Vector2(0, -h), Color(1.0, 0.65, 0.25, 0.75 * fade * (1.0 - i / 8.0)), 3.0)
		var tip := c + Vector2.from_angle(head) * r * 0.9
		b.circle(tip, 7.0, Color(col, 0.35 * fade))
		b.circle(tip, 3.5, Color(1.0, 0.92, 0.6, fade))
	_add(main, 0.45, Callable(), paint, true)
	main.sfx("swing_heavy", 0.9)
	main.sfx("spell_fire", 1.1, -2.0)
	main.light_flash(p.global_position, col, 1.4, 1.5, 0.3)
	if hits > 0:
		main.hitstop(0.04)
		main.shake(3.0)


## Ring of Embers: Kindle Blade as it is (no step-3 change), and eight patches
## of your own fire around you that burn foes (never you) for `embers` seconds.
static func _ring_of_embers(bond, sp: Dictionary, p) -> void:
	bond._cast_type(p)
	var main = p.main
	var r := float(bond.spell_stat(sp, "ember_ring"))
	var t := float(bond.spell_stat(sp, "embers"))
	for i in 8:
		main.add_flame(p.global_position + Vector2.from_angle(TAU * i / 8.0) * r, 16.0, t, true)
	main.fx_ring(p.global_position, bond.color(), r + 16.0, 0.35, 3.0)
	main.sfx("spell_fire", 0.85)


## Blazing Lunge: you lunge `distance` along your aim (stopping short of a
## wall), untouchable; every foe on the way is struck and set burning, and
## the weapon heats up by `heat`.
static func _blazing_lunge(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var to_pt: Vector2 = main.walkable_point(origin, origin + aim * float(bond.stat("distance")), 12.0)
	var hits := 0
	for e in main.targets():
		var seg := Geometry2D.get_closest_point_to_segment(e.global_position, origin, to_pt)
		if seg.distance_to(e.global_position) <= e.radius + p.radius + 8.0:
			e.take_hit(bond.damage(), aim, 200.0, true)
			e.ignite(float(bond.stat("burn")) * bond.power(), float(bond.stat("burning")))
			hits += 1
	var dist := origin.distance_to(to_pt)
	p.roll_dir = aim
	p.roll_t = 0.16
	p.roll_speed = dist / 0.16
	p.iframes = maxf(p.iframes, 0.24)
	p.ghost_t = 0.0
	p.heat = minf(100.0, p.heat + float(bond.stat("heat")))
	var paint := func(b, it: Dictionary):
		var k := clampf(float(it["t"]) / 0.5, 0.0, 1.0)
		var side := aim.orthogonal()
		b.line(origin, to_pt, Color(col, 0.22 * k), 26.0)
		b.line(origin, to_pt, Color(col.lightened(0.2), 0.6 * k), 10.0)
		b.line(origin, to_pt, Color(1.0, 0.9, 0.6, 0.9 * k), 3.0)
		b.circle(origin, 12.0 * k, Color(col, 0.3 * k))
		var n := int(dist / 16.0)
		for i in n:  # flames left standing along the path
			var at := origin.lerp(to_pt, (float(i) + 0.5) / maxf(1.0, float(n))) + side * sin(i * 2.3) * 6.0
			var h := (7.0 + 5.0 * sin(float(it["age"]) * 20.0 + i * 1.7)) * k
			b.line(at, at + Vector2(0, -h), Color(1.0, 0.6, 0.2, 0.85 * k), 3.0)
			b.circle(at + Vector2(0, -h), 1.6, Color(1.0, 0.9, 0.55, 0.9 * k), 8)
	_add(main, 0.5, Callable(), paint, true)
	main.sfx("swing_heavy", 1.2)
	main.sfx("spell_fire", 1.2)
	main.light_flash(to_pt, col, 1.3, 1.5, 0.3)
	if hits > 0:
		main.hitstop(0.05)
		main.shake(4.0)


# --- Rune Artist --------------------------------------------------------------------------

## Rune Brand: a rune on the foe nearest your aim. The moment it's hurt (by
## anything: a strike, a spell, its poison) the rune bursts against it and
## every foe within `blast`. A brand that's never set off fades after
## `duration`; a branded foe that dies bursts as it falls.
static func _rune_brand(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var target = _aimed(p, float(bond.stat("range")))
	if target == null:
		main.fx_text(p.global_position + Vector2(0, -34), TEXT["no_target"], col)
		return
	var dmg: float = bond.damage()
	var blast := float(bond.stat("blast"))
	var st := {"hp": float(target.hp), "pos": target.global_position, "foe": target}
	var burst := func(at: Vector2):
		for e in main.targets():
			var to: Vector2 = e.global_position - at
			if to.length() <= blast + e.radius:
				e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.ZERO, 180.0, true)
				if not e.dead:
					e.stagger(0.4)
		main.fx_ring(at, col, blast, 0.35, 5.0)
		main.fx_burst(at, Vector2.ZERO, col, 14, 260.0)
		main.light_flash(at, col, 1.3, 1.4, 0.3)
		main.sfx("zap", 0.85)
		main.shake(4.0)
	var tick := func(it: Dictionary, _delta: float):
		var e = st["foe"]
		if not is_instance_valid(e) or e.dead:
			it["done"] = true
			burst.call(st["pos"])
			return
		st["pos"] = e.global_position
		if float(e.hp) < float(st["hp"]) - 0.01:
			it["done"] = true
			burst.call(st["pos"])
			return
		st["hp"] = float(e.hp)
	var from: Vector2 = p.global_position
	var paint := func(b, it: Dictionary):
		var e = st["foe"]
		var at: Vector2 = st["pos"]
		var rr: float = (e.radius if is_instance_valid(e) else 12.0) + 8.0
		var age: float = it["age"]
		var a := clampf(age / 0.15, 0.0, 1.0) * clampf(float(it["t"]) / 0.6, 0.0, 1.0)
		if age < 0.2:  # the stroke of the brand, from your hand to the foe
			b.line(from, at, Color(col, 0.6 * (1.0 - age / 0.2)), 2.0)
		var spin := age * 1.4
		b.circle(at, rr, Color(col, 0.08 * a))
		b.arc(at, rr, 0.0, TAU, 28, Color(col, 0.8 * a), 2.0)
		for i in 3:  # three strokes of the rune, turning slowly
			var ra := spin + TAU * i / 3.0
			b.line(at + Vector2.from_angle(ra) * rr * 0.3, at + Vector2.from_angle(ra + 2.0) * rr * 0.85, Color(col.lightened(0.3), 0.85 * a), 2.0)
		b.circle(at + Vector2(0, -rr - 6.0), 2.5 + 0.8 * sin(age * 6.0), Color(col.lightened(0.4), 0.9 * a), 10)
	_add(main, float(bond.stat("duration")), tick, paint, true)
	main.fx_text(target.global_position + Vector2(0, -target.radius - 26.0), TEXT["branded"], col)
	main.sfx("spell_rune")
	main.sfx("glint", 0.9, -6.0)


## Afterglow: Rune Trap as it is (without Linked), and when that rune goes
## off its glyph keeps glowing for `glow` seconds: foes in it are chilled
## (walk slower) and seared (`glow_damage` every half second).
static func _afterglow(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var last = main.runes.back() if not main.runes.is_empty() else null
	bond._cast_type(p)
	if main.runes.is_empty() or is_same(main.runes.back(), last):
		return
	var rune: Dictionary = main.runes.back()
	var glow := float(bond.spell_stat(sp, "glow"))
	var dmg: float = float(bond.spell_stat(sp, "glow_damage")) * bond.spell_power(sp) * bond.flow_power
	var col: Color = bond.color()
	var tick := func(it: Dictionary, _delta: float):
		if rune.get("fire", false):
			it["done"] = true
			FX.field(main, rune["pos"], float(rune["blast"]) * 0.8, glow, 0.5, col, func(foes: Array):
				for e in foes:
					if is_instance_valid(e) and not e.dead:
						e.chill_t = maxf(e.chill_t, 0.7)
						e.take_hit(dmg, Vector2.ZERO, 0.0))
		elif not main.runes.any(func(x): return is_same(x, rune)):
			it["done"] = true  # (it faded, or a newer rune took its place)
	_add(main, float(rune.get("t", 40.0)) + 1.0, tick, Callable(), false)


## Binding Circle: a circle at your aim (short of a wall). Any foe inside it
## can't leave until it fades: it's held at the rim and chilled. A beast is
## too strong to hold: it's only chilled while inside.
static func _binding_circle(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var r := float(bond.stat("radius"))
	var center: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(bond.stat("range")), 14.0)
	var held := {}
	var tick := func(_it: Dictionary, _delta: float):
		for e in main.targets():
			var to: Vector2 = e.global_position - center
			var d := to.length()
			if d < r:
				e.chill_t = maxf(e.chill_t, 0.3)
				if not e.is_boss() and not held.has(e):
					held[e] = true
					main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["bound"], col)
			if held.has(e) and d > r - e.radius * 0.5:
				var back: Vector2 = center + to.normalized() * maxf(0.0, r - e.radius * 0.5)
				if not main.is_solid(back):
					e.global_position = back
				e.knock = -to.normalized() * 90.0
	var paint := func(b, it: Dictionary):
		var age: float = it["age"]
		var a := clampf(age / 0.2, 0.0, 1.0) * clampf(float(it["t"]) / 0.5, 0.0, 1.0)
		b.circle(center, r, Color(col, 0.07 * a))
		b.arc(center, r, 0.0, TAU, 48, Color(col, 0.8 * a), 3.0)
		b.arc(center, r * 0.62, -age * 0.6, -age * 0.6 + TAU, 36, Color(col, 0.35 * a), 1.5)
		for i in 12:  # teeth along the rim, pointing in: what's inside stays inside
			var ta := TAU * i / 12.0 + age * 0.5
			var tp := center + Vector2.from_angle(ta) * r
			b.line(tp, tp - Vector2.from_angle(ta) * 8.0, Color(col, 0.75 * a), 2.0)
		for i in 4:
			var ga := -age * 0.6 + TAU * i / 4.0
			b.circle(center + Vector2.from_angle(ga) * r * 0.62, 3.0, Color(col.lightened(0.3), 0.8 * a), 12)
	_add(main, float(bond.stat("duration")), tick, paint, false)
	main.fx_ring(center, col, r, 0.4, 4.0)
	main.light_flash(center, col, 1.2, 1.2, 0.35)
	main.sfx("spell_iron", 0.8)
	main.sfx("ready", 0.8, -6.0)


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


## A soft oval shadow, into a batch.
static func _shadow(b, pos: Vector2, r: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(pos + Vector2(cos(TAU * i / 20.0) * r, sin(TAU * i / 20.0) * r * 0.45))
	b.polygon(pts, Color(0, 0, 0, alpha))


## Something this file left in the world: `tick(item, delta)` each frame and
## `paint(batch, item)` each draw (either may be an empty Callable), for
## `seconds` or until item.done. `high` draws it over the darkness.
static func _add(main, seconds: float, tick: Callable, paint: Callable, high := false) -> Dictionary:
	var it := {"t": seconds, "age": 0.0, "done": false, "tick": tick, "paint": paint, "high": high}
	var n = Drawer.of(main)
	if n != null:
		n.items.append(it)
	return it


## This file's drawings and timed effects, under main. A new floor (a new
## floor plan) forgets them, as spell_fx.gd forgets its own.
class Drawer extends Node2D:
	const NAME := "WyvernFx"
	var items: Array = []
	var plan = null
	var air: Node2D

	static func of(main):
		if main == null or not is_instance_valid(main):
			return null
		var n = main.get_node_or_null(NAME)
		if n == null:
			n = Drawer.new()
			n.name = NAME
			n.plan = main.floor_plan
			main.add_child(n)
		return n

	func _ready() -> void:
		z_as_relative = false
		z_index = 11  # (on the floor, over the room's own drawings)
		air = Node2D.new()
		air.z_as_relative = false
		air.z_index = 46  # (over the darkness, like spell_fx.gd)
		air.draw.connect(func(): _paint(air, true))
		add_child(air)

	func _process(delta: float) -> void:
		var main = get_parent()
		if not is_same(main.floor_plan, plan):
			plan = main.floor_plan
			items.clear()
		for it in items.duplicate():
			it["t"] -= delta
			it["age"] += delta
			if (it["tick"] as Callable).is_valid() and not it["done"]:
				it["tick"].call(it, delta)
		items = items.filter(func(it): return float(it["t"]) > 0.0 and not it["done"])
		queue_redraw()
		air.queue_redraw()

	func _draw() -> void:
		_paint(self, false)

	func _paint(c: CanvasItem, high: bool) -> void:
		var b := Draw.Batch.new()
		for it in items:
			if bool(it["high"]) == high and (it["paint"] as Callable).is_valid():
				it["paint"].call(b, it)
		b.flush(c)
