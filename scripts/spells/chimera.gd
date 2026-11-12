extends RefCounted
## The Chimera's tower (Blade): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd; the
## worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Covenant: step 2 Command or RALLY (heal and spur every creature);
##     step 3, Bind and Call becomes PACK CALL (two creatures, a little
##     weaker, that hunt as a pack) or CHAMPION BOND (one creature that grows
##     with every kill it makes this floor); step 4 Exchange or RELEASE (a
##     creature bursts, hurting foes and healing you).
##   Grafter: step 2 Mimic or HARVEST (a weakened foe always leaves a
##     graft); step 3, Graft Burst becomes HUNGRY FLESH (each graft's effect,
##     and it tears a graft from a foe below half health) or FLESH SHELL (it
##     grows a shell, thicker for every graft); step 4 Shed or BUD (your
##     newest graft grows into a creature of its kind).
##   Surgeon: step 2 Mend or BLOODLETTING (a bleed that heals you); step 3,
##     Sever becomes VIVISECT (a weak point: your next 3 hits on that foe are
##     critical) or ARTERIAL CUT (it bleeds hard); step 4 Transfer or
##     ANESTHETIZE (a foe sleeps until struck).
##
## Step 3's first side keeps the old choice id "change", its second side the
## old id in FORKS[bond][3] (mighty, echoing, chained), so old saves map by
## themselves. The first side runs in cast_change(), the second in
## cast_variation(). The step-5 spells' Apex upgrades are in bonds.gd;
## Chimera Form's grafts that fire on their own are grafts_awake() below.
##
## The kin book, the retinue and the grafts are bond.gd's and main.gd's, as
## before: these spells only use them (main.allies(), spawn_ally, grafts).
## What stays a while is spell_fx.gd's shared Lasting node (firebird.gd spawn()).

const FX := preload("res://scripts/spell_fx.gd")
const Fire := preload("res://scripts/spells/firebird.gd")

static var FORKS := {
	"covenant": {
		"change": {"name": "Pack Call", "says": "each Call brings two creatures, each a little weaker, that hunt as a pack: each hits harder for every packmate near it",
			"reach": 150.0},
		2: {"id": "rally", "name": "Rally", "type": "rally", "learn": 2,
			"desc": "your creatures are healed a third and stay 4 seconds longer; for 8 seconds they move faster and hit a third again as hard",
			"steps": {2: {"cost": 6.0, "windup": 0.1, "duration": 8.0, "heal": 0.35, "might": 1.35, "haste": 1.3, "extend": 4.0}}},
		3: {"id": "mighty", "name": "Champion Bond", "transform": true,
			"desc": "Call brings one champion, half again as strong, that grows with every kill it makes this floor",
			"steps": {3: {"might": 1.5, "grow": 0.25, "grow_most": 2.5}}},
		4: {"id": "release", "name": "Release", "type": "release", "learn": 4,
			"desc": "release your nearest creature in a burst that hurts the foes around it and heals you",
			"steps": {4: {"cost": 8.0, "windup": 0.15, "damage": 12.0, "radius": 85.0, "heal": 0.3}}},
	},
	"grafter": {
		"change": {"name": "Hungry Flesh", "says": "each graft adds its own effect to Graft Burst, and the burst tears a graft from a foe below half health"},
		2: {"id": "harvest", "name": "Harvest", "type": "harvest", "learn": 2,
			"desc": "cut the foe you aim at; one below a third of its health is slain and always leaves a graft",
			"steps": {
				2: {"cost": 9.0, "windup": 0.2, "damage": 14.0, "reach": 130.0, "below": 0.33},
				4: {"damage": 18.0},
			}},
		3: {"id": "echoing", "name": "Flesh Shell", "transform": true,
			"desc": "Graft Burst grows a shell of flesh around you, thicker for every graft you carry",
			"steps": {3: {"shell": 16.0, "per_shell": 6.0, "shell_time": 6.0}}},
		4: {"id": "graft_bud", "name": "Bud", "type": "graft_bud", "learn": 4,
			"desc": "your newest graft buds into a creature of its kind that fights beside you for 15 seconds (one at a time); with no graft, a lump of your own flesh buds for 6",
			"steps": {4: {"cost": 10.0, "windup": 0.3, "duration": 15.0, "bare_kind": "slime", "bare": 0.4}}},
	},
	"surgeon": {
		"change": {"name": "Vivisect", "says": "the cut finds a weak point: your next 3 hits on that foe are critical"},
		2: {"id": "bloodletting", "name": "Bloodletting", "type": "bloodletting", "learn": 2,
			"desc": "open a vein on the foe you aim at: it bleeds for 6 seconds, and you heal for 40% of what it loses",
			"steps": {
				2: {"cost": 10.0, "windup": 0.25, "damage": 2.5, "duration": 6.0, "reach": 130.0, "share": 0.4},
				4: {"damage": 3.2},
				5: {"damage": 4.0},
			}},
		3: {"id": "chained", "name": "Arterial Cut", "transform": true,
			"desc": "the cut opens an artery and bleeds hard (more than three times as much)",
			"steps": {3: {"bleed": 0.5}}},
		4: {"id": "anesthetize", "name": "Anesthetize", "type": "anesthetize", "learn": 4,
			"desc": "the foe you aim at falls asleep for 4 seconds (less for a beast); the blow that wakes it strikes half again as hard",
			"steps": {4: {"cost": 10.0, "windup": 0.25, "damage": 4.0, "sleep": 4.0, "reach": 150.0}}},
	},
}

## The few words these spells show in the world.
static var TEXT := {
	"no_creature": "no creature to rally",
	"no_release": "no creature to release",
	"no_one": "no one in reach",
	"harvested": "Harvested: %s",
	"bud": "Bud: %s",
	"bud_bare": "Bud: your own flesh",
	"crippled": "Crippled",
	"asleep": "Asleep",
	"woken": "Woken!",
	"champion": "Champion: %d kills",
	"torn": "Torn: %s",
	"shell": "Shell %d",
	"artery": "Artery cut",
	"weak": "Weak point",
	"awake": "%s graft",
}
## Chimera Form's Apex: how far a graft that fires by itself looks for a foe.
static var AWAKE := {"reach": 170.0}

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


## Step 3's first side, a Transformation: Pack Call and Hungry Flesh run here.
## Vivisect is Sever's own numbers (bond.gd _sever marks the weak point with
## weak_point() below), so it falls through.
static func cast_change(bond, sp: Dictionary, p) -> bool:
	match String(bond.id):
		"covenant":
			_pack_call(bond, sp, p)
			return true
		"grafter":
			_hungry_flesh(bond, sp, p)
			return true
	return false


## Step 3's second side, a Transformation: Champion Bond, Flesh Shell, Arterial Cut.
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	match [String(bond.id), String(alt.get("id", ""))]:
		["covenant", "mighty"]:
			_champion(bond, sp, p)
			return true
		["grafter", "echoing"]:
			_flesh_shell(bond, sp, p)
			return true
		["surgeon", "chained"]:
			_arterial(bond, sp, p)
			return true
	return false


# --- the Transformations ---------------------------------------------------------------

## The creatures a cast just called (those out now that weren't before).
static func _called(main, before: Array) -> Array:
	return main.allies().filter(func(a): return not a in before and not a.dead)


## Pack Call: Bind and Call as ever (two creatures from step 3), each a little
## weaker, hunting as a pack: a blow lands harder for every packmate near it.
static func _pack_call(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var before: Array = main.allies()
	bond._cast_type(p)
	var power := float(bond.spell_stat(sp, "power"))
	var pack := float(bond.spell_stat(sp, "pack"))
	var reach := float(FORKS["covenant"]["change"]["reach"])
	for a in _called(main, before):
		a.max_hp *= power
		a.hp = a.max_hp
		a.dmg *= power
		a.set_meta("pack", true)
		a.set_meta("ally_strike", func(me, _target, blow: float) -> float:
			var mates := 0
			for o in main.allies():
				if o != me and not o.dead and o.has_meta("pack") and o.global_position.distance_to(me.global_position) < reach:
					mates += 1
			return blow * (1.0 + pack * mates))
	# The pack's bond: faint lines between packmates that hunt together.
	var tick := func(_n, _d: float) -> bool:
		return main.allies().filter(func(a): return a.has_meta("pack")).size() > 0
	var paint := func(n):
		var packed: Array = main.allies().filter(func(a): return a.has_meta("pack") and not a.dead)
		for i in packed.size():
			for j in range(i + 1, packed.size()):
				var a = packed[i]
				var b = packed[j]
				if a.global_position.distance_to(b.global_position) < reach:
					n.draw_line(a.global_position, b.global_position, Color(col, 0.22 + 0.08 * sin(n.age * 4.0)), 1.5, true)
	if not main.allies().filter(func(a): return a.has_meta("pack")).is_empty() and not _has_lasting(main, "pack_lines"):
		var node = Fire.spawn(main, INF, tick, paint, {"pack_lines": true})
		node.z_index = 11  # (on the floor, under the creatures)


static func _has_lasting(main, key: String) -> bool:
	var fx = FX.of(main)
	return fx != null and fx.lastings.any(func(l): return is_instance_valid(l) and l.data.has(key))


## Champion Bond: Bind and Call as ever (one creature), half again as strong;
## each kill it makes this floor grows it (and any champion called later on
## the floor starts that big). A new floor forgets the kills (it clears the
## Lasting that counts them).
static func _champion(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var before: Array = main.allies()
	bond._cast_type(p)
	var might := float(bond.spell_stat(sp, "might"))
	var grow := float(bond.spell_stat(sp, "grow"))
	var most := float(bond.spell_stat(sp, "grow_most"))
	var tally = _champion_tally(main)
	for a in _called(main, before):
		a.set_meta("champion_base", [a.max_hp, a.dmg])
		var size_up := func(c) -> void:
			var k: float = might * minf(1.0 + grow * int(tally.data["kills"]), most)
			var base: Array = c.get_meta("champion_base")
			var was: float = c.max_hp
			c.max_hp = base[0] * k
			c.hp = minf(c.max_hp, c.hp + (c.max_hp - was))
			c.dmg = base[1] * k
			c.scale = Vector2.ONE * minf(1.1 + 0.1 * int(tally.data["kills"]), 1.6)
		size_up.call(a)
		a.hp = a.max_hp
		a.set_meta("ally_kill", func(me, _foe) -> void:
			tally.data["kills"] = int(tally.data["kills"]) + 1
			size_up.call(me)
			main.fx_text(me.global_position + Vector2(0, -me.radius - 30.0), TEXT["champion"] % int(tally.data["kills"]), col)
			main.fx_ring(me.global_position, col, me.radius + 16.0, 0.35, 3.0))
		var tick := func(n, _d: float) -> bool:
			var c = n.data["a"]  # (kept in the data, not captured: it may be gone by now)
			return is_instance_valid(c) and not c.dead
		var paint := func(n):
			var c = n.data["a"]
			var at: Vector2 = c.global_position
			var t: float = n.age
			var rr: float = c.radius * c.scale.x
			n.draw_arc(at + Vector2(0, rr * 0.6), rr * 1.3, 0.0, TAU, 28, Color(col, 0.4 + 0.15 * sin(t * 4.0)), 2.0, true)
			for k in 3:  # a crown of three points over it
				var x := (k - 1) * 6.0
				var top: float = -rr * 1.2 - 12.0 - (4.0 if k == 1 else 0.0)
				n.draw_line(at + Vector2(x, -rr * 1.2 - 4.0), at + Vector2(x, top), Color(col.lightened(0.4), 0.85), 2.0, true)
		Fire.spawn(main, float(a.ally_t) + 1.0, tick, paint, {"a": a})
		main.fx_ring(a.global_position, col, 44.0, 0.45, 4.0)
		main.light_flash(a.global_position, col, 1.5, 1.6, 0.35)
	main.sfx("crit", 0.9, -6.0)


## The floor's count of a champion's kills (a Lasting that a new floor clears).
static func _champion_tally(main):
	var fx = FX.of(main)
	for l in fx.lastings:
		if is_instance_valid(l) and l.data.has("champion_kills"):
			return l
	var node = FX.lasting(main, INF, Callable(), Callable(), {"champion_kills": true, "kills": 0})
	return node


## Hungry Flesh: Graft Burst as ever (each graft's effect too); then it tears
## a graft from the weakest foe it caught below `tear` of its health (not a
## beast): that foe is struck again, and the graft binds to you at once if
## its body part is free (else the torn flesh mends you a little).
static func _hungry_flesh(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var n: int = main.grafts.size()
	var r: float = float(bond.spell_stat(sp, "radius")) + float(bond.spell_stat(sp, "per_graft_radius")) * n + (40.0 if main.grafts.has("throat") else 0.0)
	var at: Vector2 = p.global_position
	var caught: Array = main.targets().filter(func(e): return e.global_position.distance_to(at) < r + e.radius)
	bond._cast_type(p)
	var below := float(bond.spell_stat(sp, "tear"))
	var torn = null
	for e in caught:
		if not is_instance_valid(e) or e.dead or e.is_boss() or e.mirror or e.shade or e.hp > e.max_hp * below:
			continue
		if torn == null or e.hp / e.max_hp < torn.hp / torn.max_hp:
			torn = e
	if torn == null:
		return
	var kind: String = torn.kind
	var where: Vector2 = torn.global_position
	torn.take_hit(bond.damage(), (where - at).normalized(), 160.0, true)
	if main.add_graft(kind):
		main.fx_text(where + Vector2(0, -40), TEXT["torn"] % kind, col)
	else:
		p.mend_by(4.0 * p.heal_mult())
	# A strand of flesh, torn from it back to you.
	var paint := func(nd):
		if not is_instance_valid(p):
			return
		var k := clampf(nd.age / 0.25, 0.0, 1.0)
		var to: Vector2 = p.global_position
		var pts := PackedVector2Array()
		for i in 9:
			var u := k * i / 8.0
			pts.append(where.lerp(to, u) + (to - where).orthogonal().normalized() * sin(u * TAU * 1.5) * 8.0)
		nd.draw_polyline(pts, Color(col.darkened(0.1), 0.9 * nd.fade(0.2)), 3.0, true)
		nd.draw_circle(where.lerp(to, k), 5.0, Color(BLOOD, 0.9 * nd.fade(0.2)))
	Fire.spawn(main, 0.45, Callable(), paint, {})
	main.fx_burst(where, (at - where).normalized(), BLOOD, 12, 240.0)
	main.sfx("hit_slime", 0.7)


## Flesh Shell: Graft Burst as ever, and the flesh closes over you as a
## barrier: `shell`, and `per_shell` more for every graft you carry.
static func _flesh_shell(bond, sp: Dictionary, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	bond._cast_type(p)
	var shield: float = (float(bond.spell_stat(sp, "shell")) + float(bond.spell_stat(sp, "per_shell")) * main.grafts.size()) * minf(bond.power(), 1.0)
	p.raise_barrier(shield, float(bond.spell_stat(sp, "shell_time")), false, col)
	main.fx_text(p.global_position + Vector2(0, -58), TEXT["shell"] % int(round(shield)), col)
	var paint := func(n):
		if not is_instance_valid(p):
			return
		var at: Vector2 = p.global_position
		var f: float = n.fade(0.3)
		for i in 10:  # plates of flesh closing over you
			var a: float = TAU * i / 10.0 + n.age
			var k := clampf(n.age / 0.3, 0.0, 1.0)
			n.draw_arc(at, (p.radius + 8.0) * k + 2.0, a, a + 0.5, 6, Color(col.darkened(0.15), 0.85 * f), 4.0, true)
	Fire.spawn(main, 0.6, Callable(), paint, {})


## Arterial Cut: Sever as ever, bleeding hard (its "bleed" share, bond.gd _sever).
static func _arterial(bond, _sp: Dictionary, p) -> void:
	var main = p.main
	var t = bond._target_in_aim(p, 130.0)
	bond._cast_type(p)
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var at: Vector2 = t.global_position
	main.fx_burst(at, Vector2.UP, BLOOD, 16, 220.0)
	main.fx_text(at + Vector2(0, -t.radius - 44.0), TEXT["artery"], BLOOD)


## Vivisect (bond.gd _sever): a weak point on the foe; your next `crits` hits
## on it are critical (`crit` times as hard: player.gd _strike), for `weak_time`.
static func weak_point(bond, p, t) -> void:
	var main = p.main
	var col: Color = bond.color()
	var wp := {"n": int(bond.stat("crits")), "mult": float(bond.stat("crit")), "until": Time.get_ticks_msec() * 0.001 + float(bond.stat("weak_time"))}
	t.set_meta("weak_point", wp)
	main.fx_text(t.global_position + Vector2(0, -t.radius - 44.0), TEXT["weak"], col)
	var tick := func(n, _d: float) -> bool:
		var f = n.data["foe"]  # (kept in the data, not captured: it may be gone by now)
		return is_instance_valid(f) and not f.dead and f.has_meta("weak_point") and f.get_meta("weak_point") == wp
	var paint := func(n):
		var f = n.data["foe"]
		var at: Vector2 = f.global_position
		var rr: float = f.radius + 7.0
		var spin: float = n.age * 1.5
		for k in 4:  # a fine sighting mark over the weak point
			var a: float = spin + TAU * k / 4.0
			n.draw_line(at + Vector2.from_angle(a) * rr, at + Vector2.from_angle(a) * (rr + 6.0), Color(col, 0.85), 1.5, true)
		for k in int(wp["n"]):  # one pip for each critical hit left
			n.draw_circle(at + Vector2(-6.0 + 6.0 * k, -rr - 8.0), 2.0, Color(BLOOD, 0.9))
	Fire.spawn(main, float(bond.stat("weak_time")), tick, paint, {"foe": t})


# --- Chimera Form's Apex: the grafts awake ------------------------------------------------

## For as long as Chimera Form lasts, every `every` seconds the next graft you
## carry uses its power by itself (the same powers as Mimic, aimed at the
## nearest foe, without moving you).
static func grafts_awake(bond, p) -> void:
	var main = p.main
	var col: Color = bond.color()
	var every := float(bond.stat("every"))
	var dmg: float = bond.damage()
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(p) or p.dead or p.chimera_t <= 0.0:
			return false
		n.data["t"] -= d
		if n.data["t"] > 0.0 or main.graft_order.is_empty():
			return true
		n.data["t"] = every
		var order: Array = main.graft_order
		var part: String = order[int(n.data["i"]) % order.size()]
		n.data["i"] = int(n.data["i"]) + 1
		_graft_power(main, p, part, dmg, col)
		return true
	Fire.spawn(main, float(p.chimera_t), tick, Callable(), {"t": 0.2, "i": 0})


## One graft's power, by itself (grafts_awake).
static func _graft_power(main, p, part: String, dmg: float, col: Color) -> void:
	var at: Vector2 = p.global_position
	var near = null
	var best: float = float(AWAKE["reach"])
	for e in main.targets():
		var d: float = e.global_position.distance_to(at)
		if d < best + e.radius:
			best = d
			near = e
	match part:
		"hand":  # a heavy blow on the nearest foe
			if near != null:
				near.take_hit(dmg * 1.5, (near.global_position - at).normalized(), 300.0, true)
				main.fx_bolt([at, near.global_position], col)
		"legs":  # a raking kick that staggers
			if near != null:
				near.take_hit(dmg, (near.global_position - at).normalized(), 160.0)
				near.stagger(0.3 * (0.5 if near.is_boss() else 1.0))
				main.fx_bolt([at, near.global_position], col)
		"heart":  # mends flesh
			p.mend_by(dmg * 0.5 * p.heal_mult())
		"brow":  # a shriek that staggers the foes near you
			for e in main.targets():
				if e.global_position.distance_to(at) < 90.0 + e.radius:
					e.stagger(0.8 * (0.5 if e.is_boss() else 1.0))
		"throat":  # a burst of sparks
			for e in main.targets():
				var to: Vector2 = e.global_position - at
				if to.length() < 120.0 + e.radius:
					e.take_hit(dmg * 0.8, to.normalized(), 180.0)
		"back":  # a sting that poisons
			if near != null:
				near.take_hit(dmg, Vector2.ZERO, 0.0)
				if not near.dead:
					near.add_venom(2)
				main.fx_bolt([at, near.global_position], col)
	main.fx_text(at + Vector2(0, -50), TEXT["awake"] % part, col)
	main.fx_ring(at, col, 30.0, 0.25, 2.0)
	main.sfx("gust", 1.2, -8.0)


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
			main.graft_drops.append({"pos": at, "kind": kind, "t": float(main.GRAFT_DROP["life"])})
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
	# With no graft, a lump of your own flesh buds instead: `bare_kind`, for `bare` of the time.
	var bare: bool = main.graft_order.is_empty()
	var kind: String = String(bond.stat("bare_kind")) if bare else String(main.grafts[main.graft_order[-1]])
	if not load("res://scripts/enemy.gd").TYPES.has(kind):
		kind = "slime"
	for a in main.allies():
		if a.has_meta("graft_bud"):
			a._fade_ally()
	var seconds: float = float(bond.stat("duration")) * (float(bond.stat("bare")) if bare else 1.0) * (0.5 if bond._overdrawn() else 1.0)  # overdrawn: it withers sooner
	var a = main.spawn_ally(kind, p.global_position + p.aim * 44.0, bond.step, seconds)
	a.set_meta("graft_bud", true)
	main.fx_text(a.global_position + Vector2(0, -a.radius - 26.0), TEXT["bud_bare"] if bare else TEXT["bud"] % kind, col)
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
	if is_instance_valid(t) and not t.dead:  # (it bleeds: reactions.gd; the thread does the damage)
		load("res://scripts/reactions.gd").apply(main, t, "bleeding", float(bond.stat("duration")), bond, -1.0)
	var tick := func(n, d: float) -> bool:
		if not is_instance_valid(t) or t.dead or not is_instance_valid(p) or p.dead:
			return false
		n.data["at"] = t.global_position
		n.data["tick"] -= d
		if n.data["tick"] <= 0.0:
			n.data["tick"] = 0.5
			t.take_hit(dmg, Vector2.ZERO, 0.0)
			var heal: float = dmg * share * (1.3 if p.has_bond("surgeon") else 1.0) * p.heal_mult() * bond.bleeding_near_mult(p)  # (Diagnosis III)
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
