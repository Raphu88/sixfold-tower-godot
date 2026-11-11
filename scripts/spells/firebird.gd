extends RefCounted
## The Firebird's tower (Fire): its bonds' fork alternatives, and the code
## that runs them. The content contract is at the top of library.gd; the
## worked example is scripts/spells/gryphon.gd (Stormcaller).
##
##   Flame Contractor: step 2 Fire Wall or BLAZING TRAIL (burning ground
##     wherever you walk); step 3 Charged or QUICKFIRE (the library's Quick);
##     step 4 Cluster Blast or DETONATE (every patch of your burning ground
##     bursts at once).
##   Flamewing: step 2 Wingburst or CINDER DIVE (a dive through foes that
##     spends the aura's heat); step 3 Growing or BROAD (the library's Wide);
##     step 4 Warmth or HEAT HAZE (the aura burns away shots).
##   Rekindler: step 2 Desperation or FLASHPOINT (spend health in a burst
##     of fire); step 3 Spreading or DEEP BURN (the library's Charged: lose
##     more, regain more); step 4 Pyre Oath or BACKDRAFT (blows you take
##     burst into fire).
##
## Hooks worked around here (bond.gd and player.gd are left alone): Firebird
## Form makes Wingburst free by its type, so Cinder Dive gives its own cost
## back in the form; Rekindle's payback (twice what you lost) lives in
## player.gd, so Deep Burn adds its extra share itself when the burn ends.
##
## What these spells leave in the world for a while is drawn by a Lasting
## node (spawn() below; chimera.gd uses it too). A new floor clears it.

const FX := preload("res://scripts/spell_fx.gd")

static var FORKS := {
	"flame_contractor": {
		"change": {"name": "Charged", "says": "Fireball charges: a longer wind-up and a much bigger explosion"},
		2: {"id": "blazing_trail", "name": "Blazing Trail", "type": "blazing_trail", "learn": 2,
			"desc": "for 4 seconds you leave a trail of burning ground wherever you walk (it burns foes, not you)",
			"steps": {
				2: {"cost": 10.0, "windup": 0.2, "duration": 4.0, "burns": 2.5, "gap": 30.0},
				4: {"duration": 5.0},
			}},
		3: {"id": "quickfire", "variation": "quick", "name": "Quickfire",
			"desc": "Fireball winds up in half the time and costs 8, a little weaker",
			"steps": {3: {"damage": 19.0, "cost": 8.0}}},
		4: {"id": "detonate", "name": "Detonate", "type": "detonate", "learn": 4,
			"desc": "every patch of your burning ground bursts at once (up to 6 bursts); with none, one bigger burst at your aim",
			"steps": {
				4: {"cost": 12.0, "windup": 0.3, "damage": 12.0, "radius": 50.0, "bursts": 6},
				5: {"damage": 15.0},
			}},
	},
	"flamewing": {
		"change": {"name": "Growing", "says": "Heat Aura grows hotter the longer it burns"},
		2: {"id": "cinder_dive", "name": "Cinder Dive", "type": "cinder_dive", "learn": 2,
			"desc": "dive through the foes along your aim in a streak of fire, setting each one burning; the aura's built-up heat makes it hotter (free in Firebird Form)",
			"steps": {
				2: {"cost": 10.0, "windup": 0.15, "damage": 10.0, "dist": 150.0, "burn": 2.0, "burn_time": 3.0},
				4: {"damage": 13.0},
				5: {"damage": 16.0},
			}},
		3: {"id": "broad", "variation": "wide", "name": "Broad",
			"desc": "Heat Aura reaches 40% farther from the start, a little weaker",
			"steps": {3: {"damage": 3.8}}},
		4: {"id": "heat_haze", "name": "Heat Haze", "type": "heat_haze", "learn": 4,
			"desc": "for 8 seconds your aura burns away the shots that enter it and sets the foes in it burning (it lights the aura if it's off)",
			"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 8.0, "burn": 2.0}}},
	},
	"rekindler": {
		"change": {"name": "Spreading", "says": "foes near you burn too while you rekindle"},
		2: {"id": "flashpoint", "name": "Flashpoint", "type": "flashpoint", "learn": 2,
			"desc": "spend a tenth of your health in a burst of fire around you; the lower your health, the harder it hits",
			"steps": {
				2: {"cost": 9.0, "windup": 0.15, "price": 0.1, "damage": 10.0, "radius": 90.0},
				4: {"damage": 12.0},
				5: {"damage": 14.0},
			}},
		3: {"id": "deep_burn", "variation": "charged", "name": "Deep Burn",
			"desc": "Rekindle winds up longer and burns deeper: you lose a third more, and regain two and a half times what you lost",
			"steps": {3: {"deep": 0.05, "payback": 0.5}}},
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
	"deep_burn": "Deep Burn +%d",
	"backdraft": "Backdraft",
}


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


## Rekindler's Deep Burn: Rekindle as it is, burning deeper, then the extra
## share back when the burn ends. Quickfire and Broad are the library's own
## Quick and Wide (they change numbers only), so they fall through.
static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool:
	if String(bond.id) != "rekindler" or String(alt.get("id", "")) != "deep_burn":
		return false
	bond._cast_type(p)
	var main = p.main
	p.rekindle_loss += p.max_hp * float(bond.spell_stat(sp, "deep"))
	var payback := float(bond.spell_stat(sp, "payback"))
	var token := int(p.get_meta("deep_burn", 0)) + 1
	p.set_meta("deep_burn", token)
	FX.later(main, float(p.rekindle_total) + 0.1, func():
		if not is_instance_valid(p) or p.dead or int(p.get_meta("deep_burn", 0)) != token:
			return
		if p.rekindle_t <= 0.0 and p.rekindle_fought and p.rekindle_lost > 0.0:
			var extra: float = p.rekindle_lost * payback
			p.hp = minf(p.max_health(), p.hp + extra)
			main.fx_text(p.global_position + Vector2(0, -58), TEXT["deep_burn"] % int(extra), bond.color()))
	return true


# --- what stays a while ------------------------------------------------------------

## The drawing (and ticking) of a spell that stays a while. tick(n, delta)
## returns false to end it early; paint(n) draws with n.draw_*. n.age counts
## up to n.life; n.data holds the spell's own state. It sits over the
## darkness like the library's spell effects, and it watches a SpellFx
## timer so a new floor (SpellFx.clear) ends it too.
class Lasting extends Node2D:
	var life := 1.0
	var age := 0.0
	var data := {}
	var tick := Callable()
	var paint := Callable()
	var fx
	var sentinel := {}

	func _ready() -> void:
		z_as_relative = false
		z_index = 46

	func alive() -> bool:
		if fx == null or not is_instance_valid(fx):
			return false
		for tm in fx.timers:
			if is_same(tm, sentinel):
				return true
		return false

	func finish() -> void:
		if fx != null and is_instance_valid(fx):
			for i in fx.timers.size():
				if is_same(fx.timers[i], sentinel):
					fx.timers.remove_at(i)
					break
		queue_free()

	func _process(delta: float) -> void:
		if is_queued_for_deletion():
			return
		if not alive():
			queue_free()
			return
		age += delta
		if tick.is_valid() and not bool(tick.call(self, delta)):
			finish()
			return
		if age >= life:
			finish()
			return
		queue_redraw()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

	## 1 while it lasts, easing to 0 over its last `tail` seconds.
	func fade(tail := 0.35) -> float:
		return clampf((life - age) / tail, 0.0, 1.0)


## Something a spell leaves in the world for `seconds` (see Lasting).
static func spawn(main, seconds: float, tick: Callable, paint: Callable, data := {}) -> Node2D:
	var n := Lasting.new()
	n.life = seconds
	n.tick = tick
	n.paint = paint
	n.data = data
	n.fx = FX.of(main)
	FX.later(main, 1.0e9, func(): pass)  # (the sentinel: SpellFx.clear drops it)
	n.sentinel = n.fx.timers.back()
	main.add_child(n)
	return n


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
	# Free in Firebird Form, as Wingburst is (unless the cast was free anyway).
	var weave := int(p.gfx("spellweave"))
	var was_free: bool = main.in_sigil(start) or (weave > 0 and p.spells_cast % weave == 0)
	if p.firebird_t > 0.0 and not bond._overdrawn() and not was_free:
		bond.essence = minf(bond.capacity(), bond.essence + bond.cost())
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
