extends RefCounted
## The Chimera's tower (Blade): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd; the
## worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Covenant: step 2 Command or RALLY (heal and spur every creature);
##     step 3 Paired or MIGHTY (the library's Charged: one creature, nearly
##     twice as strong); step 4 Exchange or RELEASE (a creature bursts,
##     hurting foes and healing you).
##   Grafter: step 2 Mimic or HARVEST (a weakened foe always leaves a
##     graft); step 3 Manifold or ECHOING (the library's Echo); step 4 Shed
##     or BUD (your newest graft grows into a creature of its kind).
##   Surgeon: step 2 Mend or BLOODLETTING (a bleed that heals you); step 3
##     Disarming or CHAINED (the library's Chain: Sever cripples a second
##     foe); step 4 Transfer or ANESTHETIZE (a foe sleeps until struck).
##
## The pact book, the retinue and the grafts are bond.gd's and main.gd's, as
## before: these spells only use them (main.allies(), spawn_ally, grafts).
## What stays a while is drawn by firebird.gd's Lasting node (spawn()).

const FX := preload("res://scripts/spell_fx.gd")
const Fire := preload("res://scripts/spells/firebird.gd")

static var FORKS := {
	"covenant": {
		"change": {"name": "Paired", "says": "each Call brings two creatures"},
		2: {"id": "rally", "name": "Rally", "type": "rally", "learn": 2,
			"desc": "your creatures are healed a third and stay 4 seconds longer; for 8 seconds they move faster and hit half again as hard",
			"steps": {2: {"cost": 6.0, "windup": 0.1, "duration": 8.0, "heal": 0.35, "might": 1.5, "haste": 1.3, "extend": 4.0}}},
		3: {"id": "mighty", "variation": "charged", "name": "Mighty",
			"desc": "Call winds up longer and calls one creature, nearly twice as strong",
			"steps": {3: {"might": 1.8}}},
		4: {"id": "release", "name": "Release", "type": "release", "learn": 4,
			"desc": "release your nearest creature in a burst that hurts the foes around it and heals you",
			"steps": {4: {"cost": 8.0, "windup": 0.15, "damage": 12.0, "radius": 85.0, "heal": 0.3}}},
	},
	"grafter": {
		"change": {"name": "Manifold", "says": "each graft adds its own effect to Graft Burst"},
		2: {"id": "harvest", "name": "Harvest", "type": "harvest", "learn": 2,
			"desc": "cut the foe you aim at; one below a third of its health is slain and always leaves a graft",
			"steps": {
				2: {"cost": 9.0, "windup": 0.2, "damage": 14.0, "reach": 130.0, "below": 0.33},
				4: {"damage": 18.0},
			}},
		3: {"id": "echoing", "variation": "echo", "name": "Echoing",
			"desc": "Graft Burst bursts again a second later, at half strength",
			"steps": {3: {"damage": 10.0}}},
		4: {"id": "graft_bud", "name": "Bud", "type": "graft_bud", "learn": 4,
			"desc": "your newest graft buds into a creature of its kind that fights beside you for 15 seconds (one at a time)",
			"steps": {4: {"cost": 10.0, "windup": 0.3, "duration": 15.0}}},
	},
	"surgeon": {
		"change": {"name": "Disarming", "says": "a foe already crippled is disarmed instead"},
		2: {"id": "bloodletting", "name": "Bloodletting", "type": "bloodletting", "learn": 2,
			"desc": "open a vein on the foe you aim at: it bleeds for 6 seconds, and you heal for half of what it loses",
			"steps": {
				2: {"cost": 10.0, "windup": 0.25, "damage": 2.5, "duration": 6.0, "reach": 130.0, "share": 0.5},
				4: {"damage": 3.2},
				5: {"damage": 4.0},
			}},
		3: {"id": "chained", "variation": "chain", "name": "Chained",
			"desc": "Sever leaps on to a second foe near the first and cripples it too, a little weaker",
			"steps": {3: {"damage": 10.0}}},
		4: {"id": "anesthetize", "name": "Anesthetize", "type": "anesthetize", "learn": 4,
			"desc": "the foe you aim at falls asleep for 4 seconds (less for a beast); the blow that wakes it strikes half again as hard",
			"steps": {4: {"cost": 10.0, "windup": 0.25, "damage": 4.0, "sleep": 4.0, "reach": 150.0}}},
	},
}

## The few words these spells show in the world.
static var TEXT := {
	"no_creature": "no creature to rally",
	"no_release": "no creature to release",
	"no_graft": "no graft to bud",
	"no_one": "no one in reach",
	"harvested": "Harvested: %s",
	"bud": "Bud: %s",
	"crippled": "Crippled",
	"asleep": "Asleep",
	"woken": "Woken!",
}

const BLOOD := Color(0.82, 0.12, 0.16)


## Runs this file's spells.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	match String(sp.get("type", "")):
		"rally":
			_rally(bond, p)
		"release":
			_release(bond, p)
		"harvest":
			_harvest(bond, p)
		"graft_bud":
			_bud(bond, p)
		"bloodletting":
			_bloodletting(bond, p)
		"anesthetize":
			_anesthetize(bond, p)
		_:
			return false
	return true


## Covenant's Mighty and Surgeon's Chained run here; Grafter's Echoing is the
## library's own Echo (it falls through).
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match [String(bond.id), String(alt.get("id", ""))]:
		["covenant", "mighty"]:
			_mighty(bond, sp, p)
			return true
		["surgeon", "chained"]:
			_chained(bond, p)
			return true
	return false


# --- Covenant ------------------------------------------------------------------------

## Rally: every creature out is healed and stays longer, and for a while
## moves faster and hits harder (casting again refreshes it, never stacks).
static func _rally(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var allies: Array = main.allies()
	if allies.is_empty():
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_creature"], col)
		return
	var token := Time.get_ticks_usec()
	var power: float = minf(bond.power(), 1.0)  # (a faint or overdrawn rally spurs less)
	for a in allies:
		a.hp = minf(a.max_hp, a.hp + a.max_hp * float(bond.stat("heal")) * power)
		a.ally_t += float(bond.stat("extend"))
		if not a.has_meta("rally_base"):
			a.set_meta("rally_base", [a.dmg, a.speed])
		var base: Array = a.get_meta("rally_base")
		a.dmg = base[0] * (1.0 + (float(bond.stat("might")) - 1.0) * power)
		a.speed = base[1] * float(bond.stat("haste"))
		a.set_meta("rally", token)
		main.fx_ring(a.global_position, col, a.radius + 10.0, 0.3, 3.0)
	var dur := float(bond.stat("duration"))
	FX.later(main, dur, func():
		for a in allies:
			if is_instance_valid(a) and a.has_meta("rally") and a.get_meta("rally") == token:
				var base: Array = a.get_meta("rally_base")
				a.dmg = base[0]
				a.speed = base[1]
				a.remove_meta("rally")
				a.remove_meta("rally_base"))
	var paint := func(n):
		var f: float = n.fade(0.5)
		for a in allies:
			if not is_instance_valid(a) or a.dead or not a.has_meta("rally") or a.get_meta("rally") != token:
				continue
			var at: Vector2 = a.global_position
			if n.age < 0.35 and is_instance_valid(p):  # the call goes out to each
				n.draw_line(p.global_position, p.global_position.lerp(at, n.age / 0.35), Color(col, 0.7), 2.0, true)
			var bob := sin(n.age * 6.0) * 2.0
			for k in 2:  # chevrons over its head: spurred on
				var y: float = -a.radius - 12.0 - k * 6.0 + bob
				n.draw_polyline(PackedVector2Array([at + Vector2(-6, y + 4), at + Vector2(0, y), at + Vector2(6, y + 4)]), Color(col.lightened(0.3), 0.85 * f), 2.0, true)
			n.draw_arc(at, a.radius + 5.0, 0.0, TAU, 24, Color(col, 0.35 * f), 1.5, true)
	Fire.spawn(main, dur, Callable(), paint, {})
	main.light_flash(p.global_position, col, 1.3, 1.4, 0.3)
	main.sfx("ready", 1.2)
	main.sfx("beast_call", 1.0, -2.0)


## Mighty: Bind and Call as it is (binding works as before); a creature it
## calls comes nearly twice as strong, and bigger.
static func _mighty(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var before: Array = main.allies()
	bond._cast_type(p)
	var might := float(bond.spell_stat(sp, "might"))
	for a in main.allies():
		if a in before:
			continue
		a.max_hp *= might
		a.hp = a.max_hp
		a.dmg *= might
		a.scale = Vector2.ONE * 1.2
		a.set_meta("mighty", true)
		var tick := func(_n, _d: float) -> bool:
			return is_instance_valid(a) and not a.dead
		var paint := func(n):
			var at: Vector2 = a.global_position
			var t: float = n.age
			n.draw_arc(at + Vector2(0, a.radius * 0.6), a.radius * 1.3, 0.0, TAU, 28, Color(col, 0.4 + 0.15 * sin(t * 4.0)), 2.0, true)
			for k in 3:  # a crown of three points over it
				var x := (k - 1) * 6.0
				var top: float = -a.radius * 1.2 - 12.0 - (4.0 if k == 1 else 0.0)
				n.draw_line(at + Vector2(x, -a.radius * 1.2 - 4.0), at + Vector2(x, top), Color(col.lightened(0.4), 0.85), 2.0, true)
		Fire.spawn(main, float(a.ally_t) + 1.0, tick, paint, {})
		main.fx_ring(a.global_position, col, 44.0, 0.45, 4.0)
		main.light_flash(a.global_position, col, 1.5, 1.6, 0.35)
	main.sfx("crit", 0.9, -6.0)


## Release: your nearest creature bursts; the more life it had left, the
## harder it hits, and a share of that life comes back to you.
static func _release(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var best = null
	var best_d := INF
	for a in main.allies():
		var d: float = a.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_release"], col)
		return
	var at: Vector2 = best.global_position
	var left: float = maxf(0.0, best.hp)
	var dmg: float = bond.damage() + left * 0.4 * bond.power()
	var r := float(bond.stat("radius"))
	for e in main.targets():
		var to: Vector2 = e.global_position - at
		if to.length() < r + e.radius:
			e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.ZERO, 280.0, true)
	var heal: float = left * float(bond.stat("heal")) * p.heal_mult()
	p.hp = minf(p.max_health(), p.hp + heal)
	main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(heal), Color(0.6, 1.0, 0.7))
	best._fade_ally()
	# The burst, and its life drifting back to you.
	var paint := func(n):
		var k := clampf(n.age / 0.3, 0.0, 1.0)
		var f: float = n.fade(0.3)
		n.draw_arc(at, r * (1.0 - pow(1.0 - k, 2.0)), 0.0, TAU, 36, Color(col, 0.75 * f), 3.0, true)
		if not is_instance_valid(p):
			return
		for i in 6:
			var u := clampf(n.age / 0.55 - i * 0.06, 0.0, 1.0)
			var side: Vector2 = (p.global_position - at).orthogonal().normalized() * sin(u * PI) * (12.0 if i % 2 == 0 else -12.0)
			n.draw_circle(at.lerp(p.global_position, u) + side, 3.0, Color(0.6, 1.0, 0.75, 0.9 * (1.0 - u * 0.6) * f))
	Fire.spawn(main, 0.6, Callable(), paint, {})
	main.fx_ring(at, col, r, 0.35, 5.0)
	main.fx_burst(at, Vector2.ZERO, col, 20, 300.0)
	main.light_flash(at, col, 1.8, 1.8, 0.35)
	main.sfx("hit_heavy", 0.8)
	main.sfx("beast_call", 1.15, -4.0)
	main.shake(4.0)


# --- Grafter -----------------------------------------------------------------------

## Harvest: a cut; a foe below a third of its health is slain and always
## leaves a graft where it fell (walk over it to bind it, as ever).
static func _harvest(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var t = bond._target_in_aim(p, float(bond.stat("reach")))
	if t == null:
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_one"], col)
		return
	var at: Vector2 = t.global_position
	var dir: Vector2 = (at - p.global_position).normalized()
	var reaped := false
	if t.hp <= t.max_hp * float(bond.stat("below")) and not t.is_boss() and not t.mirror and not t.shade:
		var kind: String = t.kind
		t.take_hit(t.hp + 1.0, Vector2.ZERO, 0.0)
		if not main.graft_drops.any(func(g): return g["pos"].distance_to(at) < 4.0):
			main.graft_drops.append({"pos": at, "kind": kind, "t": 20.0})
		main.fx_text(at + Vector2(0, -t.radius - 30.0), TEXT["harvested"] % kind, col)
		main.sfx("hit_slime", 0.8)
		reaped = true
	else:
		t.take_hit(bond.damage(), dir, 120.0)
	# A hooked cut: two curved strokes across it.
	var paint := func(n):
		var f: float = n.fade(0.25)
		var k := clampf(n.age / 0.12, 0.0, 1.0)
		var base := dir.angle()
		for s in [-1.0, 1.0]:
			var c: Vector2 = at + dir.orthogonal() * s * 6.0
			n.draw_arc(c, 18.0, base + s * 1.9, base + s * (1.9 - 2.4 * k), 14, Color(col.lightened(0.3), 0.9 * f), 3.0, true)
		if reaped:
			n.draw_circle(at, 8.0 + 14.0 * k, Color(col, 0.25 * f))
	Fire.spawn(main, 0.3, Callable(), paint, {})
	main.fx_burst(at, dir, col, 10, 220.0)
	main.sfx("swing", 1.3)


## Bud: your newest graft grows into a creature of that monster's kind, as
## strong as your mark's step, for a while (a new one replaces the old).
static func _bud(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	if main.graft_order.is_empty():
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_graft"], col)
		return
	var kind: String = main.grafts[main.graft_order[-1]]
	for a in main.allies():
		if a.has_meta("graft_bud"):
			a._fade_ally()
	var seconds: float = float(bond.stat("duration")) * (0.5 if bond._overdrawn() else 1.0)  # overdrawn: it withers sooner
	var a = main.spawn_ally(kind, p.global_position + p.aim * 44.0, bond.step, seconds)
	a.set_meta("graft_bud", true)
	main.fx_text(a.global_position + Vector2(0, -a.radius - 26.0), TEXT["bud"] % kind, col)
	# Tendrils grow from you to it.
	var from: Vector2 = p.global_position
	var to: Vector2 = a.global_position
	var paint := func(n):
		var k := clampf(n.age / 0.3, 0.0, 1.0)
		var f: float = n.fade(0.2)
		for s in [-1.0, 0.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 9:
				var u := k * i / 8.0
				pts.append(from.lerp(to, u) + (to - from).orthogonal().normalized() * sin(u * TAU + s) * 7.0 * s)
			n.draw_polyline(pts, Color(col.darkened(0.1), 0.85 * f), 2.5, true)
		n.draw_circle(to, 6.0 + 10.0 * k, Color(col, 0.25 * f))
	Fire.spawn(main, 0.45, Callable(), paint, {})
	main.light_flash(to, col, 1.3, 1.4, 0.3)
	main.sfx("spell_life", 0.9)
	main.sfx("ready", 0.8, -5.0)


# --- Surgeon -----------------------------------------------------------------------

## Bloodletting: a cut that bleeds every half second for a while; half of
## what it loses heals you (more with Steady Hands, and with Life's flow).
static func _bloodletting(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var t = bond._target_in_aim(p, float(bond.stat("reach")))
	if t == null:
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_one"], col)
		return
	var dmg: float = bond.damage()
	var share := float(bond.stat("share"))
	t.take_hit(dmg * 2.0, (t.global_position - p.global_position).normalized(), 60.0)
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(t) or t.dead or not is_instance_valid(p) or p.dead:
			return false
		n.data["at"] = t.global_position
		n.data["tick"] -= d
		if n.data["tick"] <= 0.0:
			n.data["tick"] = 0.5
			t.take_hit(dmg, Vector2.ZERO, 0.0)
			var heal: float = dmg * share * (1.3 if p.has_bond("surgeon") else 1.0) * p.heal_mult()
			p.hp = minf(p.max_health(), p.hp + heal)
		return true
	var paint := func(n):
		if not is_instance_valid(p) or not is_instance_valid(t):
			return
		var a: Vector2 = t.global_position
		var b: Vector2 = p.global_position
		var f: float = n.fade(0.4)
		var side: Vector2 = (b - a).orthogonal().normalized()
		n.draw_line(a, b, Color(col, 0.18 * f), 1.0, true)  # the thread
		for i in 7:  # drops flowing along it to you
			var u := fmod(n.age * 1.1 + i / 7.0, 1.0)
			n.draw_circle(a.lerp(b, u) + side * sin(u * PI) * 10.0, 2.4, Color(BLOOD, 0.9 * f))
		for i in 3:  # and dripping from the wound
			var u := fmod(n.age * 1.8 + i / 3.0, 1.0)
			n.draw_circle(a + Vector2((i - 1) * 5.0, t.radius * 0.4 + u * 10.0), 1.8, Color(BLOOD, (1.0 - u) * f))
	Fire.spawn(main, float(bond.stat("duration")), tick, paint, {"at": t.global_position, "tick": 0.5})
	main.fx_burst(t.global_position, Vector2.ZERO, BLOOD, 8, 160.0)
	main.sfx("swing", 1.6)
	main.sfx("spell_blade", 1.1, -2.0)


## Chained: Sever as it is, then the cut leaps to the foe nearest the first
## (within the library's Chain hop) and cripples it too, at Chain's power.
static func _chained(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var first = bond._target_in_aim(p, 130.0)
	var from: Vector2 = first.global_position if first != null else Vector2.ZERO
	bond._cast_type(p)
	if first == null:
		return
	var v: Dictionary = load("res://scripts/library.gd").variation("chain")
	var hop := float(v.get("hop", 170.0))
	var second = null
	var best := INF
	for e in main.targets():
		if e == first or e.dead:
			continue
		var d: float = e.global_position.distance_to(from)
		if d < hop and d < best:
			best = d
			second = e
	if second == null:
		return
	var to: Vector2 = second.global_position
	second.take_hit(bond.damage() * float(v.get("power", 0.6)), (to - from).normalized(), 60.0)
	second.cripple_t = maxf(second.cripple_t, float(bond.stat("duration")))
	main.fx_text(to + Vector2(0, -second.radius - 30.0), TEXT["crippled"], col)
	var paint := func(n):
		var k := clampf(n.age / 0.1, 0.0, 1.0)
		var f: float = n.fade(0.2)
		n.draw_line(from, from.lerp(to, k), Color(col, 0.85 * f), 2.0, true)
		var dir := (to - from).normalized()
		for c in [from, to]:  # a fine cross-cut where each was struck
			n.draw_line(c - dir.rotated(0.8) * 10.0, c + dir.rotated(0.8) * 10.0, Color(BLOOD, 0.8 * f), 2.0, true)
	Fire.spawn(main, 0.3, Callable(), paint, {})
	main.sfx("spell_blade", 1.2, -2.0)


## Anesthetize: a fine needle; the foe sleeps (it can't move or attack)
## until the time runs out or a real blow wakes it, and that blow strikes
## half again as hard. Bleeding and burning don't wake it.
static func _anesthetize(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var t = bond._target_in_aim(p, float(bond.stat("reach")))
	if t == null:
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["no_one"], col)
		return
	var from: Vector2 = p.global_position
	t.take_hit(bond.damage(), Vector2.ZERO, 0.0)
	if t.dead:
		return
	var sleep: float = float(bond.stat("sleep")) * (0.35 if t.is_boss() else 1.0) * minf(bond.power(), 1.0)
	t.stagger(sleep)
	t.aim_dir = Vector2.ZERO
	main.release_attack(t)
	main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), TEXT["asleep"], col)
	var tick := func(n, _d: float) -> bool:
		if not is_instance_valid(t) or t.dead:
			return false
		if n.age > 0.1 and t.hp < float(n.data["hp"]) - 4.5:
			var extra: float = (float(n.data["hp"]) - t.hp) * 0.5
			t.stun = 0.0
			main.fx_text(t.global_position + Vector2(0, -t.radius - 44.0), TEXT["woken"], col)
			t.take_hit(extra, Vector2.ZERO, 0.0)
			return false
		if n.age > 0.2 and t.stun <= 0.0:
			return false  # (it woke some other way)
		n.data["hp"] = t.hp
		return true
	var paint := func(n):
		if not is_instance_valid(t):
			return
		var at: Vector2 = t.global_position
		var f: float = n.fade(0.3)
		if n.age < 0.15:  # the needle
			n.draw_line(from, from.lerp(at, n.age / 0.15), Color(col.lightened(0.3), 0.9), 1.5, true)
		n.draw_arc(at, t.radius + 6.0, 0.0, TAU, 28, Color(0.65, 0.6, 0.9, 0.35 * f), 2.0, true)
		for i in 3:  # little z's drifting up
			var u := fmod(n.age * 0.6 + i / 3.0, 1.0)
			var s := 3.0 + 3.0 * u
			var c := at + Vector2(6.0 + i * 3.0 + sin(n.age * 2.0 + i) * 3.0, -t.radius - 10.0 - u * 24.0)
			var zc := Color(0.85, 0.85, 1.0, 0.9 * (1.0 - u) * f)
			n.draw_polyline(PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(-s, s), c + Vector2(s, s)]), zc, 1.5, true)
	Fire.spawn(main, sleep, tick, paint, {"hp": t.hp})
	main.sfx("swing", 1.9, -4.0)
	main.sfx("hiss", 1.6, -10.0)
