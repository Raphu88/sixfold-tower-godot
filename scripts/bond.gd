extends RefCounted
## One bond: a named power marked on one body part.
## The body part decides how it fills; the bond's data (bonds.gd) decides
## its spell and how that spell grows with each step.

const Bonds := preload("res://scripts/bonds.gd")
const SecretBonds := preload("res://scripts/secret_bonds.gd")
const Library := preload("res://scripts/library.gd")
const TreeRules := preload("res://scripts/tree.gd")
## States and reactions (what a spell leaves on a foe), and named pacts.
const Reactions := preload("res://scripts/reactions.gd")
const Pacts := preload("res://scripts/pacts.gd")
## The Gryphon's and the Kraken's content files run their marks' passive
## ranks and Apex upgrades (taken_mult, on_kill, the great spells): loaded
## when needed, never preloaded (library.gd loads them as it starts).
static func gryphon() -> Script:
	return load("res://scripts/spells/gryphon.gd")


static func kraken() -> Script:
	return load("res://scripts/spells/kraken.gd")


## The Wyvern's and the Manticore's (their marks' Transformations, passive ranks and Apexes).
static func wyvern() -> Script:
	return load("res://scripts/spells/wyvern.gd")


static func manticore() -> Script:
	return load("res://scripts/spells/manticore.gd")

## What a mark's spells' blows are, while it casts (main.gd hit_kind), and
## the kinds a foe drenched by the Maelstrom's Apex takes double from.
const HIT_KINDS := {"stormcaller": "lightning"}
const DRENCH_KINDS := ["lightning", "frost"]
static var PART_NAMES := Bonds.PART_NAMES
const PART_FILLS := Bonds.PART_FILLS
const PART_BURN := Bonds.PART_BURN
const MAX_STEP := 5

var id: String
var part: String
var step := 1
var essence := 0.0
var burned := false
var faint := false  # a mark taken in defeat: weaker until it catches up
var overdraw_mult := 1.0  # set for an overdrawn cast: desperate casts are weaker
var attr_power := 1.0  # Fire density (Intellect): spells hit a little harder
var attr_fill := 1.0  # Water density (Spirit): marks fill a little faster
var gear_power := 1.0  # an Ember Charm and the like: spells hit a little harder (player.refresh_gear)
var flow_power := 1.0  # Unmaking's flow: spells deal more damage (player.set_flow)

## How strong an overdrawn cast is, and how much health per missing essence
## overdrawing an already-burned mark tears out of you.
const OVERDRAW_POWER := 0.7
const TEAR_HEALTH := 1.0




func _init(bond_id: String, body_part: String) -> void:
	id = bond_id
	part = body_part


func data() -> Dictionary:
	return Bonds.BONDS[id]


# --- spells ----------------------------------------------------------------------

var selected := 0  # which learned spell the mark's key casts


## The choices made on this bond's tree (tree.gd): step -> the side chosen
## (main.gd sets it from the profile). A fork not chosen yet uses today's side.
var choices := {}
## A variation's strength for the cast under way (library.gd run_mark_variation).
var var_power := 1.0
## Where the last Chain Lightning's last leap struck (Stormcaller's Living Bolt).
var last_point = null
## Static III: a charged foe died, so the next Chain Lightning costs nothing.
var refund := false


## The spells this bond knows at its current step, in the order learned (a
## fork's chosen side, or today's until it's chosen: tree.gd bond_spells).
func spells() -> Array:
	if choices.is_empty():
		return data()["spells"].filter(func(sp): return int(sp["learn"]) <= step)
	return TreeRules.bond_spells(id, step, choices)


## The step-3 variation in force on this bond's first spell ({} for today's change).
func alt_change() -> Dictionary:
	if step < 3 or choices.is_empty():
		return {}
	return TreeRules.alt_change(id, choices)


## True for the spell today's step-3 change applies to (the first spell).
static func is_changed_spell(sp: Dictionary) -> bool:
	return sp.get("changes", {}).has(3)


## The spell the mark's key casts.
func spell() -> Dictionary:
	var known := spells()
	return known[clampi(selected, 0, known.size() - 1)]


func select(i: int) -> void:
	selected = clampi(i, 0, spells().size() - 1)


## A value for the selected spell at the current step: the latest step at or
## below this one that sets it wins.
func stat(key: String):
	return spell_stat(spell(), key)


func spell_stat(sp: Dictionary, key: String):
	var steps: Dictionary = sp["steps"]
	var value = null
	# A step-3 variation chosen in place of today's change: its values, not the change's.
	var alt := alt_change() if is_changed_spell(sp) else {}
	var alt_steps: Dictionary = alt.get("steps", {})
	for s in range(1, step + 1):
		if not alt.is_empty() and s == 3:
			if alt_steps.has(3) and alt_steps[3].has(key):
				value = alt_steps[3][key]
			continue
		if steps.has(s) and steps[s].has(key):
			value = steps[s][key]
	if not alt.is_empty() and alt.has("variation"):
		value = Library.mark_stat(String(alt["variation"]), key, value)  # (Wide, Long, Quick...)
	if not edits.is_empty():
		value = SecretBonds.edit_stat(edits, sp["id"], key, value)  # the Developer's Edit
	return value


func display_name() -> String:
	return data()["name"]


func spell_name() -> String:
	return spell()["name"]


func spell_desc() -> String:
	return spell()["desc"]


func body_name() -> String:
	return data()["body"]["name"]


func passive_name() -> String:
	return data()["passive"]["name"]


## The passive's rank at this mark's step (1; II from step 3; III at step 5).
func passive_rank() -> int:
	return Bonds.passive_rank(step)


func color() -> Color:
	return data()["color"]


func capacity() -> float:
	return 30.0 + 10.0 * step


func cost() -> float:
	return spell_cost(spell())


## A faint mark's spells hit softer, and so do desperate (overdrawn) casts.
func power() -> float:
	return spell_power(spell())


func damage() -> float:
	return spell_damage(spell())


func windup() -> float:
	return spell_windup(spell())


## The same numbers for any of its spells (the Developer's Inspect reads
## these), with the Developer's Tune (`tunes`: spell id -> setting, set by
## main.gd from secret_bonds.gd) applied, and its Edit (`edits`: spell id
## -> {aspect: points}).
var tunes := {}
var edits := {}


## A cast's cost scaled for the moment (Runesmith III: inside your circles; player.gd sets it around a cast).
var cost_mult := 1.0


func spell_cost(sp: Dictionary) -> float:
	return float(spell_stat(sp, "cost")) * (1.25 if faint else 1.0) * cost_mult * SecretBonds.tune_mult(tunes, sp["id"], "cost")


func spell_power(sp: Dictionary) -> float:
	return (0.75 if faint else 1.0) * overdraw_mult * var_power * attr_power * gear_power * SecretBonds.tune_mult(tunes, sp["id"], "power") * SecretBonds.edit_mult(edits, sp["id"], "power")


func spell_damage(sp: Dictionary) -> float:
	var d = spell_stat(sp, "damage")
	return float(d if d != null else 0.0) * spell_power(sp) * flow_power


func spell_windup(sp: Dictionary) -> float:
	return float(spell_stat(sp, "windup")) * SecretBonds.tune_mult(tunes, sp["id"], "windup")


## What reaching `new_step` brings, in a few words (empty if nothing).
func step_note(new_step: int) -> String:
	return Bonds.step_note(id, new_step)


func fill(amount: float) -> void:
	essence = minf(capacity(), essence + amount * attr_fill)


## Pays for a cast. Returns "paid", "burned" (overdrawn: the body part burns)
## or "torn" (overdrawn again while burned: it costs health instead), and
## sets overdraw_mult for the cast. `missing` is how much essence was short.
var missing := 0.0


func pay(free := false) -> String:
	if refund and is_changed_spell(spell()):
		refund = false  # Static III: refunded
		free = true
	if free:  # Grand Sigil: spells cost nothing inside it
		overdraw_mult = 1.0
		missing = 0.0
		return "paid"
	if essence >= cost():
		essence -= cost()
		overdraw_mult = 1.0
		missing = 0.0
		return "paid"
	missing = cost() - essence
	essence = 0.0
	overdraw_mult = OVERDRAW_POWER
	if burned:
		return "torn"
	burned = true
	return "burned"


func cast(p) -> void:
	var sp := spell()
	var at: Vector2 = p.global_position
	var alt := alt_change() if is_changed_spell(sp) else {}
	var kind: String = HIT_KINDS.get(id, "")
	if kind != "":
		p.main.hit_kind = kind  # (what its blows are, while it casts: a drenched foe takes double, bond.gd taken_mult)
	if not alt.is_empty():
		Library.cast_mark_variation(self, sp, p, alt)  # (a step-3 variation: the tower's way, or the library's)
	elif not (step >= 3 and is_changed_spell(sp) and Library.cast_mark_change(self, sp, p)):  # (today's side: the tower's way, from step 3)
		_cast_type(p)
	if kind != "":
		p.main.hit_kind = ""
	Library.on_cast(p, {"by": "bond", "bond": self, "part": part, "at": at, "spell": sp})  # (content files may answer)


## Runs the selected spell by its type (a type this file doesn't know is a
## fork alternative's: its tower's file runs it, library.gd cast_spell).
func _cast_type(p) -> void:
	match spell()["type"]:
		"chain":
			_chain(p)
		"overcharge":
			_overcharge(p)
		"rod":
			_rod(p)
		"thunderhead":
			_thunderhead(p)
		"lift":
			_lift(p)
		"crosswind":
			_crosswind(p)
		"downdraft":
			_downdraft(p)
		"cyclone":
			_cyclone(p)
		"shot":
			_shot(p)
		"track":
			_track(p)
		"hawkeye":
			_hawkeye(p)
		"rain":
			_rain(p)
		"surge":
			_surge(p)
		"riptide":
			_riptide(p)
		"carry":
			_carry(p)
		"maelstrom":
			_maelstrom(p)
		"barrier":
			_barrier(p)
		"absorb":
			_absorb(p)
		"challenge":
			_challenge(p)
		"unbreakable":
			_unbreakable(p)
		"drain":
			_drain(p)
		"anchor":
			_anchor(p)
		"siphon":
			_siphon(p)
		"drink":
			_drink(p)
		"blades":
			_blades(p)
		"recall":
			_recall(p)
		"bladeward":
			_bladeward(p)
		"edges":
			_edges(p)
		"kindle":
			_kindle(p)
		"lash":
			_lash(p)
		"searing":
			_searing(p)
		"overheat":
			_overheat(p)
		"trap":
			_trap(p)
		"inscribe":
			_inscribe(p)
		"ward":
			_ward(p)
		"sigil":
			_sigil(p)
		"quake":
			_quake(p)
		"sandwall":
			_sandwall(p)
		"sinkhole":
			_sinkhole(p)
		"fault":
			_fault(p)
		"spit":
			_spit(p)
		"cloud":
			_cloud(p)
		"neuro":
			_neuro(p)
		"virulence":
			_virulence(p)
		"veil":
			_veil(p)
		"decoy":
			_decoy(p)
		"vanish":
			_vanish(p)
		"ashfall":
			_ashfall(p)
		"fireball":
			_fireball(p, 0)
		"cluster":
			_fireball(p, 3)
		"firewall":
			_firewall(p)
		"meteor":
			_meteor(p)
		"aura":
			_aura(p)
		"wingburst":
			_wingburst(p)
		"warmth":
			_warmth(p)
		"firebirdform":
			_firebird_form(p)
		"rekindle":
			_rekindle(p)
		"desperation":
			_desperation(p)
		"pyre":
			_pyre(p)
		"phoenix":
			_phoenix(p)
		"call":
			_call(p)
		"command":
			_command(p)
		"exchange":
			_exchange(p)
		"grandcall":
			_grand_call(p)
		"graftburst":
			_graft_burst(p, damage(), true)
		"mimic":
			_mimic(p)
		"shed":
			_shed(p)
		"chimeraform":
			_chimera_form(p)
		"sever":
			_sever(p)
		"mend":
			_mend(p)
		"transfer":
			_transfer(p)
		"amputate":
			_amputate(p)
		_:
			Library.cast_spell(self, spell(), p)


func _overdrawn() -> bool:
	return overdraw_mult < 1.0


func _chain(p) -> void:
	var main = p.main
	var leaps: int = int(stat("leaps")) * (2 if p.thunderhead_t > 0.0 else 1)
	var from: Vector2 = p.global_position
	var reach: float = stat("reach")
	var hit: Array = []
	var points: Array = [from]
	# Lightning Rod: when the chain runs out of foes in reach it leaps to a
	# planted rod (never a leap lost) and on from it, around corners; a chain
	# that ends near the rod strikes it too. Either way the rod beats at once.
	var rod: Dictionary = main.rod
	var rod_used := false
	while hit.size() < leaps:
		var best = null
		var best_d := reach
		for e in main.targets():
			if e in hit:
				continue
			var d: float = from.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			if not rod_used and not rod.is_empty() and from.distance_to(rod["pos"]) < (float(rod["link"]) if hit.is_empty() else maxf(float(stat("hop")), float(rod["reach"]))):
				rod_used = true
				from = rod["pos"]
				points.append(from)
				reach = maxf(float(stat("hop")), float(rod["reach"]))
				continue
			break
		hit.append(best)
		points.append(best.global_position)
		from = best.global_position
		reach = stat("hop")
	if not rod_used and not rod.is_empty() and not hit.is_empty() and from.distance_to(rod["pos"]) < float(rod["reach"]):
		rod_used = true
		points.append(rod["pos"])
	if rod_used:
		rod_beat(main, rod)
	if hit.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	last_point = points[-1]
	main.fx_bolt(points, color())
	for pt in points:
		main.light_flash(pt, color(), 1.0, 1.4, 0.3)
	main.sfx("zap")
	main.hitstop(0.07)
	main.shake(5.0)
	var stun: float = stat("stun")
	for e in hit:
		if not is_instance_valid(e) or e.dead:
			continue
		e.charged = 4.0
		if stun > 0.0:
			e.stagger(stun)
		e.take_hit(damage(), Vector2.ZERO)
	# Overdrawn, the last leap may jump back to you.
	if _overdrawn() and randf() < 0.5:
		main.fx_bolt([points[-1], p.global_position], color())
		p.hp = maxf(1.0, p.hp - 6.0)
		main.fx_text(p.global_position + Vector2(0, -50), "the chain jumps back! -6", Color(1.0, 0.4, 0.3))


# Charge one foe; when it dies, lightning leaps from it to every foe nearby.
func _overcharge(p) -> void:
	var main = p.main
	var target = _target_in_aim(p, 320.0)
	if target == null:
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	target.overcharge_t = stat("duration")
	target.overcharge_dmg = damage()
	target.overcharge_r = stat("radius")
	Reactions.apply(main, target, "charged", float(stat("duration")), self)
	main.fx_bolt([p.global_position, target.global_position], color())
	main.fx_ring(target.global_position, color(), 30.0, 0.3, 2.0)
	main.sfx("zap", 0.8, -4.0)


# Plant a rod where you aim. Every `beat` seconds it strikes the nearest
# `targets` foes within `radius` and charges them; your chains leap through
# it (Chain Lightning above); when it ends, every charged foe within
# `burst_radius` has its charge drawn out in a burst. A new rod replaces
# the old one (which bursts first).
func _rod(p) -> void:
	var main = p.main
	var sp := spell()
	if not main.rod.is_empty():
		rod_burst(main, main.rod)
	var at: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(stat("range")), 14.0)
	main.rod = {"pos": at, "t": float(stat("duration")), "total": float(stat("duration")), "reach": float(stat("reach")), "link": float(stat("link")),
		"radius": float(stat("radius")), "every": float(stat("beat")), "next": float(stat("beat")) * 0.5, "targets": int(stat("targets")),
		"damage": damage(), "burst": float(stat("burst")) * spell_power(sp) * flow_power, "burst_radius": float(stat("burst_radius")),
		"color": color(), "flash": 0.0}
	main.fx_ring(at, color(), 26.0, 0.3, 2.0)
	main.light_flash(at, color(), 0.9, 1.0, 0.3)
	main.sfx("equip_sword", 0.7, -2.0)


## The rod's time runs down; it beats on its rhythm and bursts at the end (main.gd ticks it).
static func tick_rod(main, delta: float) -> void:
	var rod: Dictionary = main.rod
	if rod.is_empty():
		return
	rod["t"] = float(rod["t"]) - delta
	rod["flash"] = float(rod.get("flash", 0.0)) + delta
	rod["next"] = float(rod.get("next", 0.0)) - delta
	if float(rod["next"]) <= 0.0 and float(rod["t"]) > 0.0:
		rod_beat(main, rod)
	if float(rod["t"]) <= 0.0:
		rod_burst(main, rod)
		main.rod = {}


## One beat: lightning from the rod to the nearest foes in its radius, each struck and charged.
static func rod_beat(main, rod: Dictionary) -> void:
	if rod.is_empty() or not rod.has("every"):
		return
	rod["next"] = float(rod["every"])
	rod["flash"] = 0.0
	var at: Vector2 = rod["pos"]
	var near: Array = main.targets().filter(func(e): return not e.dead and e.global_position.distance_to(at) <= float(rod["radius"]) + e.radius)
	near.sort_custom(func(a, b): return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	var col: Color = rod["color"]
	main.hit_kind = HIT_KINDS["stormcaller"]
	for e in near.slice(0, int(rod["targets"])):
		main.fx_bolt([at + Vector2(0, -28), e.global_position], col)
		e.charged = maxf(e.charged, 4.0)
		e.take_hit(float(rod["damage"]), Vector2.ZERO, 0.0)
	main.hit_kind = ""
	if not near.is_empty():
		main.light_flash(at, col, 0.9, 1.0, 0.2)
		main.sfx("zap", 1.3, -7.0)


## The rod's end: it draws the charge out of every charged foe near it, striking each.
static func rod_burst(main, rod: Dictionary) -> void:
	if rod.is_empty() or not rod.has("burst"):
		return
	var at: Vector2 = rod["pos"]
	var col: Color = rod["color"]
	var drawn := 0
	main.hit_kind = HIT_KINDS["stormcaller"]
	for e in main.targets():
		if e.dead or e.charged <= 0.0 or e.global_position.distance_to(at) > float(rod["burst_radius"]) + e.radius:
			continue
		e.charged = 0.0
		main.fx_bolt([e.global_position, at + Vector2(0, -28)], col)
		e.take_hit(float(rod["burst"]), (e.global_position - at).normalized(), 80.0)
		drawn += 1
	main.hit_kind = ""
	main.fx_ring(at, col, float(rod["burst_radius"]), 0.4, 4.0)
	main.light_flash(at, col, 1.6 if drawn > 0 else 0.8, 1.4, 0.3)
	if drawn > 0:
		main.sfx("thunder", 1.2, -6.0)
		main.shake(3.0)


# For a while, every chain leaps twice as many times; its Apex: every
# strike you land calls a bolt from above (player.gd _strike, gryphon.gd sky_bolt).
func _thunderhead(p) -> void:
	var main = p.main
	p.thunderhead_t = stat("duration")
	p.thunderhead_bolt = float(stat("bolt") if stat("bolt") != null else 0.0) * power() * flow_power
	main.fx_ring(p.global_position, color(), 80.0, 0.5, 4.0)
	main.light_flash(p.global_position, color(), 2.0, 1.6, 0.6)
	main.sfx("zap", 0.6)
	main.shake(4.0)


## The foe nearest to where you're aiming, within reach (or null).
func _target_in_aim(p, reach: float):
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


# A gust in front of you throws foes into the air, helpless.
func _lift(p) -> void:
	var main = p.main
	var half_arc := deg_to_rad(stat("arc"))
	var reach: float = stat("reach")
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	main.fx_cone(origin, aim, reach, half_arc, color())
	main.light_flash(origin + aim * reach * 0.5, color(), 1.4, 0.8, 0.35)
	main.sfx("gust", 0.9)
	var lifted := 0
	var dmg: float = damage()
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > half_arc:
			continue
		e.lift(stat("lift"))
		e.knock = aim * 120.0
		if dmg > 0.0:
			e.take_hit(dmg, aim, 60.0)
		if Pacts.has(p, "dust_devil"):
			_shards(main, e.global_position)
		lifted += 1
	if lifted == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing to lift", color())


## Dust Devil: shards of stone left on the floor that cut what walks over
## them (and set it bleeding).
static func _shards(main, at: Vector2) -> void:
	var pd: Dictionary = Pacts.PACTS["dust_devil"]
	var r := float(pd["radius"])
	var col: Color = pd["color"]
	var SpellFx = load("res://scripts/spell_fx.gd")
	SpellFx.field(main, at, r, float(pd["seconds"]), 0.5, col, func(foes: Array):
		for o in foes:
			if is_instance_valid(o) and not o.dead and o.airborne <= 0.0:
				o.take_hit(float(pd["damage"]), Vector2.ZERO, 0.0)
				Reactions.apply(main, o, "bleeding", 2.0, "dust devil", float(pd["bleed"])))
	var bits: Array = []
	for i in 7:
		bits.append([Vector2.from_angle(randf() * TAU) * randf() * r * 0.85, randf() * TAU])
	SpellFx.lasting(main, float(pd["seconds"]), Callable(), func(n):
		var a: float = n.fade(0.5)
		for b in bits:
			var c: Vector2 = at + b[0]
			var d := Vector2.from_angle(b[1])
			n.draw_colored_polygon(PackedVector2Array([c + d * 5.0, c + d.orthogonal() * 2.0, c - d * 3.0, c - d.orthogonal() * 2.0]), Color(col, 0.85 * a))
		n.draw_arc(at, r, 0.0, TAU, 28, Color(col, 0.25 * a), 1.2, true), {}, {"z": 11})


# A wave bursts out around you, hurling every foe in reach away. From step 3
# it is an aimed wave that travels forward.
func _surge(p) -> void:
	var main = p.main
	var origin: Vector2 = p.global_position
	if _overdrawn():
		p.knock = -p.aim * 300.0  # an overdrawn surge knocks you back too
	main.sfx("hit_slime", 0.6)
	main.sfx("gust", 0.7, -4.0)
	main.shake(5.0)
	if stat("aimed"):
		main.add_wave(origin, p.aim, stat("width"), stat("travel"), damage(), stat("push"), false, color(), {"states": {"soaked": _soak_time()}, "source": self})
		return
	var radius: float = stat("radius")
	main.fx_ring(origin, color(), radius, 0.45, 6.0)
	main.fx_ring(origin, Color(1, 1, 1, 0.8), radius * 0.6, 0.3, 2.0)
	main.fx_burst(origin, Vector2.ZERO, color(), 24, 320.0)
	main.light_flash(origin, color(), 1.6, 1.2, 0.4)
	var hit := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		if to.length() > radius + e.radius:
			continue
		var dir := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
		e.tide_push(dir * float(stat("push")))
		e.take_hit(damage(), dir, stat("push"))
		_soak(main, e, true)
		hit += 1
	if hit == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing in reach", color())


# Pull every foe in a line toward you.
func _riptide(p) -> void:
	var main = p.main
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var length: float = stat("length")
	var pulled := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - origin
		var along := to.dot(aim)
		if along < 0.0 or along > length or absf(to.dot(aim.orthogonal())) > stat("width") * 0.5 + e.radius:
			continue
		var pull := -aim * minf(along * 2.4, 520.0)
		e.tide_push(pull)
		e.take_hit(damage(), Vector2.ZERO)
		_soak(main, e, true)
		e.knock = pull
		pulled += 1
	main.fx_cone(origin, aim, length, deg_to_rad(6.0), color())
	main.sfx("gust", 0.6, -2.0)
	if pulled == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing in line", color())


# A wave sweeps up every foe in front of you for `travel`: each is struck as
# it's picked up (`damage`), drawn toward the wave's middle (`gather`), and
# foes carried into each other both take `collide` (each pair once, at most
# `max_collide` times a foe). A foe dashed against a wall takes `crash` on top
# (and Undercurrent's stun). Where the wave runs out, it lets them go.
func _carry(p) -> void:
	var k: float = spell_power(spell()) * flow_power
	p.main.add_wave(p.global_position, p.aim, stat("width"), stat("travel"), damage(), 0.0, true, color(),
		{"collide": float(stat("collide")) * k, "crash": float(stat("crash")) * k, "gather": float(stat("gather")), "max_collide": int(stat("max_collide")),
			"states": {"soaked": _soak_time()}, "source": self})
	p.main.sfx("hit_slime", 0.5)
	p.main.sfx("gust", 0.6)


# A whirlpool drags every foe in a wide area to its centre.
func _maelstrom(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.maelstroms.append({"pos": at, "r": stat("radius"), "t": stat("duration") * power(), "damage": damage(), "tick": 0.0, "color": color(),
		"drench": float(stat("drench") if stat("drench") != null else 0.0), "linger": float(stat("linger") if stat("linger") != null else 0.0)})  # (its Apex: kraken.gd drench)
	main.sfx("gust", 0.5)
	main.light_flash(at, color(), 1.8, 1.0, 0.5)


# A shell that absorbs damage (from step 3 it bursts when it breaks).
func _barrier(p) -> void:
	var dur: float = stat("duration") * (0.5 if _overdrawn() else 1.0)  # an overdrawn barrier cracks early
	p.raise_barrier(float(stat("shield")) * power(), dur, bool(stat("burst")), color())
	p.main.fx_ring(p.global_position, color(), 40.0, 0.35, 3.0)
	p.main.sfx("parry", 0.7, -6.0)


# For a moment every hit you take is stored in your barrier instead.
func _absorb(p) -> void:
	p.absorb_t = stat("duration")
	if p.barrier_t <= 0.0:
		p.raise_barrier(1.0, stat("duration") + 2.0, _burst_known(), color())
	p.main.fx_ring(p.global_position, color(), 30.0, 0.3, 2.0)
	p.main.sfx("charge", 1.4, -4.0)


func _burst_known() -> bool:
	for sp in spells():
		if sp["type"] == "barrier":
			return bool(spell_stat(sp, "burst"))
	return false


# Every foe nearby must come at you, and takes more damage from you.
func _challenge(p) -> void:
	var main = p.main
	var n := 0
	for e in main.targets():
		if e.global_position.distance_to(p.global_position) < stat("radius"):
			e.challenged_t = stat("duration")
			n += 1
	main.fx_ring(p.global_position, color(), stat("radius"), 0.5, 4.0)
	main.sfx("warn_knight", 0.8)
	main.shake(3.0)
	if n == 0:
		main.fx_text(p.global_position + Vector2(0, -34), "no one to challenge", color())


# For a few seconds you take no damage; its Apex: you may strike at half
# damage, and what it kept from you bursts out at the end (kraken.gd unbreakable).
func _unbreakable(p) -> void:
	p.unbreak_t = stat("duration")
	kraken().unbreakable(self, spell(), p)
	p.main.fx_ring(p.global_position, color(), 60.0, 0.5, 5.0)
	p.main.light_flash(p.global_position, color(), 1.4, 1.4, 0.5)
	p.main.sfx("parry", 0.5)


## The passives' ranks and the Maelstrom's Apex, on a blow a foe takes
## (enemy.gd take_hit): Static II (a charged foe takes more from
## everything), Quarry II (your Quarry takes more from you: player.gd
## quarry_fresh is a foe just struck the first time) and a drenched foe
## struck by lightning or frost (main.gd hit_kind).
static func taken_mult(main, e) -> float:
	var p = main.player if main != null else null
	if p == null or not is_instance_valid(p) or not p.has_method("passive_rank"):
		return 1.0
	var k := 1.0
	if Reactions.has(e, "charged") and p.passive_rank("stormcaller") >= 2:
		k *= 1.0 + Bonds.passive_num("stormcaller", 2, "more")
	if p.quarry == e and not p.quarry_fresh and p.passive_rank("hunter") >= 2:
		k *= 1.0 + Bonds.passive_num("hunter", 2, "more")
	if String(main.get("hit_kind")) in DRENCH_KINDS:
		k *= kraken().drenched(e)
	k *= manticore().blow_mult(main, e)  # (Corrosive: a poisoned foe takes more)
	return k


## A foe died (main.gd on_enemy_killed): Static III (a charged foe: the next
## Chain Lightning is free), Quarry III (your Quarry: the nearest foe
## becomes it and a shot comes back) and Pressure III (near you: you heal).
static func on_kill(main, e) -> void:
	var p = main.player
	if p == null or not is_instance_valid(p) or p.dead or not p.has_method("passive_rank"):
		return
	manticore().on_killed(main, e)  # (Toxin Build II: its poison passes on)
	if Reactions.has(e, "charged") and p.passive_rank("stormcaller") >= 3:
		for b in p.bonds.values():
			if b.id == "stormcaller" and not b.refund:
				b.refund = true
				main.fx_text(p.global_position + Vector2(0, -60), gryphon().TEXT["refunded"], b.color())
	if p.quarry == e and p.passive_rank("hunter") >= 3:
		var next = gryphon()._nearest_to(main, e.global_position, Bonds.passive_num("hunter", 3, "reach", 400.0), [e])
		p.quarry = next
		for b in p.bonds.values():
			if b.id == "hunter":
				b.essence = minf(b.capacity(), b.essence + b.spell_cost(b.data()["spells"][0]))
				main.fx_text(p.global_position + Vector2(0, -60), gryphon().TEXT["refilled"], b.color())
				if next != null:
					main.fx_text(next.global_position + Vector2(0, -next.radius - 22.0), gryphon().TEXT["quarry"], b.color())
	if p.passive_rank("deepcaller") >= 3 and e.global_position.distance_to(p.global_position) < float(PRESSURE_REACH):
		var heal: float = Bonds.passive_num("deepcaller", 3, "heal") * p.heal_mult()
		p.hp = minf(p.max_health(), p.hp + heal)
		main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(round(heal)), Color(0.5, 1.0, 0.6))


## How near a foe must be for a Deepcaller's Pressure (enemy.gd uses the same).
const PRESSURE_REACH := 150.0


## How long a water spell soaks what it touches (reactions.gd STATES).
static func _soak_time() -> float:
	return float(Reactions.STATES["soaked"]["seconds"])


## A water spell soaks the foe; Tempest (Stormcaller and Tidecaller): a
## Tidecaller's wave (`wave`) charges it as well.
func _soak(main, e, wave := false) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	Reactions.apply(main, e, "soaked", _soak_time(), self)
	if wave and Pacts.has(main.player, "tempest") and is_instance_valid(e) and not e.dead:
		Reactions.apply(main, e, "charged", Pacts.num("tempest", "charged"), "tempest")


## A Deepcaller's drain on one foe: its damage, doubled by Hemorrhage (a
## bleeding foe: reactions.gd).
func _drained(main, e) -> float:
	var dmg := damage()
	if "hemorrhage" in Reactions.apply(main, e, "drained", 0.0, self):
		dmg *= Reactions.num("hemorrhage", "mult")
	return dmg


## The foes nearest you, up to `count`, within `reach`.
func _nearest(p, count: int, reach: float) -> Array:
	var list: Array = p.main.targets().filter(func(e): return e.global_position.distance_to(p.global_position) < reach)
	list.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	return list.slice(0, count)


# Drag life out of the nearest foes and drink some of it back.
func _drain(p) -> void:
	var main = p.main
	var foes := _nearest(p, int(stat("targets")), stat("reach"))
	if foes.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no one in reach", color())
		return
	var total := 0.0
	var extra := 0.0  # Bloodletter: what bleeding foes give back again
	for e in foes:
		main.fx_bolt([e.global_position, p.global_position], color())
		var dmg := _drained(main, e)
		var bled: bool = Reactions.has(e, "bleeding")
		if is_instance_valid(e) and not e.dead:
			e.take_hit(dmg, Vector2.ZERO)
			_soak(main, e)
		total += dmg
		if bled and Pacts.has(p, "bloodletter"):
			extra += dmg * (Pacts.num("bloodletter", "heal") - 1.0)
	total += extra
	var heal: float = total * float(stat("heal")) * (1.5 if p.main.tower_data()["essence"] == "water" else 1.0) * p.heal_mult()
	p.hp = minf(p.max_health(), p.hp + heal)
	main.fx_text(p.global_position + Vector2(0, -40), "+%d" % int(heal), Color(0.5, 1.0, 0.6))
	main.sfx("zap", 0.5, -4.0)
	if _overdrawn():
		p.hp = maxf(1.0, p.hp - 6.0)  # an overdrawn Undertow drains you as well


# Tether a foe so it cannot move away from you.
func _anchor(p) -> void:
	var target = _target_in_aim(p, stat("reach"))
	if target == null:
		p.main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	p.anchor_target = target
	p.anchor_t = stat("duration")
	_soak(p.main, target)
	p.anchor_len = stat("length")
	p.main.sfx("equip_sword", 0.6, -2.0)


# Drain essence instead of health: it refills every mark you carry.
func _siphon(p) -> void:
	var main = p.main
	var foes := _nearest(p, int(stat("targets")), stat("reach"))
	if foes.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no one in reach", color())
		return
	for e in foes:
		main.fx_bolt([e.global_position, p.global_position], Color(0.6, 0.85, 1.0))
		var dmg := _drained(main, e)
		if is_instance_valid(e) and not e.dead:
			e.take_hit(dmg, Vector2.ZERO)
	for b in p.bonds.values():
		b.fill(float(stat("refill")) * foes.size())
	main.fx_text(p.global_position + Vector2(0, -40), "essence drawn", Color(0.6, 0.85, 1.0))
	main.sfx("zap", 0.6, -4.0)


# Channel a drain on one foe; it grows stronger every second it holds.
func _drink(p) -> void:
	var target = _target_in_aim(p, stat("reach"))
	if target == null:
		p.main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	p.drink_target = target
	p.drink_t = stat("duration")
	p.drink_age = 0.0
	p.drink_dmg = damage()
	p.drink_jump = float(stat("jump") if stat("jump") != null else 0.0)  # (its Apex: on a kill it jumps on, kraken.gd drink_jump)
	p.main.sfx("charge", 0.6)


# A fan of conjured blades that pierce through every foe in their path.
## Weapon Memory: conjured blades take after the weapon in your hand.
## Light weapons (fists, daggers): more, smaller knives; heavy ones: fewer,
## harder blades; bows and crossbows: fast, harder darts (weapons.gd MEMORY).
func _blade_shape(p) -> Dictionary:
	return p.Weapons.memory(p.weapon)


## Throws `count` blades (and Weapon Memory's extra) across `spread`; returns
## them. `sp`: the spell whose damage they carry (the selected one if {}).
func _throw_blades(p, count: int, spread: float, back := false, jitter := 0.0, sp := {}) -> Array:
	var main = p.main
	var shape := _blade_shape(p)
	var out: Array = []
	var dmg: float = spell_damage(sp) if not sp.is_empty() else damage()
	count = maxi(1, count + int(shape["extra"]))
	var aim: Vector2 = p.aim
	for i in count:
		var off := (float(i) - (float(count) - 1.0) / 2.0) * spread / maxf(1.0, float(count - 1)) * 2.0 if count > 1 else 0.0
		off += randf_range(-jitter, jitter)
		var dir := aim.rotated(off)
		var spd: float = float(shape["speed"]) * (randf_range(0.85, 1.1) if jitter > 0.0 else 1.0)
		var b = main.spawn_player_arrow(p.global_position + dir * (p.radius + 6.0), dir * spd, dmg * float(shape["mult"]), 120.0, true)
		b.style = "blade"
		b.tint = color()
		b.life = float(shape["life"])
		if back:
			b.return_to = p
			b.out_t = 0.4
		out.append(b)
	wyvern().arm_blades(self, p, out)  # (Weapon Memory II: they carry your weapon's traits)
	return out


func _blades(p) -> void:
	var main = p.main
	var aim: Vector2 = p.aim
	var thrown := _throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")) * (float(stat("count")) - 1.0) / 2.0)
	wyvern().conjured(self, p, thrown)  # (step 3: Embedded Steel or Weapon Echo)
	main.sfx("swing", 1.4)
	main.sfx("equip_sword", 1.3, -4.0)
	main.light_flash(p.global_position + aim * 30.0, color(), 1.0, 0.9, 0.25)


# A wall of wind across your path that turns enemy arrows back.
func _crosswind(p) -> void:
	var main = p.main
	var center: Vector2 = p.global_position + p.aim * 50.0
	var half: Vector2 = p.aim.orthogonal() * stat("length") * 0.5
	main.walls.append({"a": center - half, "b": center + half, "t": stat("duration"), "color": color()})
	main.sfx("gust", 1.1, -2.0)
	main.light_flash(center, color(), 1.0, 0.8, 0.3)


# Slam every foe in the air into the ground.
func _downdraft(p) -> void:
	var main = p.main
	var slammed := 0
	for e in main.targets():
		if e.airborne <= 0.0 or e.global_position.distance_to(p.global_position) > 420.0:
			continue
		Reactions.apply(main, e, "slam", 0.0, self)  # (Crater: slammed out of the air)
		if not is_instance_valid(e) or e.dead:
			slammed += 1
			continue
		e.airborne = 0.0
		main.fx_ring(e.global_position, color(), stat("radius"), 0.35, 4.0)
		main.fx_burst(e.global_position, Vector2.ZERO, Color(0.8, 0.75, 0.7), 12, 220.0)
		for o in main.targets():
			if o != e and o.global_position.distance_to(e.global_position) < stat("radius"):
				o.take_hit(float(stat("splash")) * power(), (o.global_position - e.global_position).normalized(), 120.0)
		e.take_hit(damage(), Vector2.ZERO, 0.0, true)
		slammed += 1
	if slammed == 0:
		main.fx_text(p.global_position + Vector2(0, -34), "nothing in the air", color())
	else:
		main.sfx("hit_heavy", 0.8)
		main.shake(7.0)
		main.hitstop(0.08)


# A cyclone that holds every foe inside it aloft.
func _cyclone(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.cyclones.append({"pos": at, "r": stat("radius"), "t": stat("duration") * power(), "color": color(),
		"steer": float(stat("steer") if stat("steer") != null else 0.0), "range": float(stat("range"))})  # (its Apex: you steer it, gryphon.gd steer_cyclone)
	main.sfx("gust", 0.6)
	main.light_flash(at, color(), 1.8, 1.2, 0.5)


# A long-range arrow of essence that pierces a whole line of foes.
func _shot(p) -> void:
	var main = p.main
	var dir: Vector2 = p.aim
	if _overdrawn():
		dir = dir.rotated(randf_range(-0.4, 0.4))  # an overdrawn shot flies wide
	var dmg := damage() * (3.0 if stat("charged") else 1.0)
	var b = main.spawn_player_arrow(p.global_position + dir * (p.radius + 8.0), dir * float(stat("speed")), dmg, 160.0, true)
	b.style = "essence"
	b.tint = color()
	b.life = 1.5
	main.sfx("bow", 1.3)
	main.light_flash(p.global_position + dir * 30.0, color(), 0.9, 1.0, 0.2)
	if stat("charged"):
		main.shake(4.0)


# Reveal every foe and where it is heading.
func _track(p) -> void:
	p.main.track_t = stat("duration")
	p.main.sfx("glint", 0.8, -4.0)
	p.main.fx_ring(p.global_position, color(), 160.0, 0.6, 2.0)


# For a few seconds, every arrow strikes a weak point.
func _hawkeye(p) -> void:
	p.hawk_t = stat("duration")
	p.main.sfx("ready", 0.8)
	p.main.fx_ring(p.global_position, color(), 50.0, 0.4, 3.0)


# Arrows fall on a marked area.
func _rain(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * stat("range")
	main.rains.append({"pos": at, "r": stat("radius"), "t": stat("duration"), "tick": 0.0, "damage": damage(), "color": color(),
		"follow": float(stat("follow") if stat("follow") != null else 0.0)})  # (its Apex: it follows your Quarry, gryphon.gd follow_quarry)
	main.sfx("bow", 0.8)


# --- Blade Forger --------------------------------------------------------------

# Blades fly out, then come back to you, cutting again on the way.
func _recall(p) -> void:
	_throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")), true)
	p.main.sfx("swing", 1.2)
	p.main.sfx("equip_sword", 1.1, -4.0)


# Blades circle you, cutting anything that comes close.
func _bladeward(p) -> void:
	p.bladeward_t = stat("duration")
	p.bladeward_dmg = damage()
	p.bladeward_r = stat("radius")
	p.bladeward_color = color()
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.35, 3.0)
	p.main.sfx("equip_sword", 1.4)


# A storm of blades fanning out toward your aim.
func _edges(p) -> void:
	var main = p.main
	var thrown := _throw_blades(p, int(stat("count")), deg_to_rad(stat("spread")) * 0.5, false, deg_to_rad(4.0))
	wyvern().edges(self, p, thrown)  # (its Apex: edges left on the floor)
	main.sfx("swing_heavy", 1.3)
	main.sfx("equip_sword", 0.9)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.6, 1.4, 0.35)
	main.shake(4.0)


# --- Flameblade --------------------------------------------------------------------

func _kindle(p) -> void:
	var brand = stat("brand")
	if p.kindle_t > 0.0 and brand != null and float(brand) > 0.0:
		wyvern().release_heat(p)  # (Brand: casting it again releases your heat)
	_light_kindle(p, spell())
	p.main.fx_ring(p.global_position + p.aim * 14.0, color(), 30.0, 0.3, 3.0)
	p.main.sfx("burn", 1.2, -4.0)
	p.main.light_flash(p.global_position, color(), 1.2, 1.2, 0.3)


## Kindles the weapon with Kindle Blade's numbers (`sp`): Forge Heart's heat
## cap, Brand's brands (wyvern.gd).
func _light_kindle(p, sp: Dictionary) -> void:
	p.kindle_t = float(spell_stat(sp, "duration"))
	p.kindle_dmg = spell_damage(sp)
	p.kindle_sustain = bool(spell_stat(sp, "sustain"))
	p.kindle_color = color()
	var cap = spell_stat(sp, "heat_cap")
	p.kindle_cap = float(cap) if cap != null else 100.0
	var brand = spell_stat(sp, "brand")
	p.kindle_brand = float(brand) if brand != null else 0.0


# A wave of fire thrown forward.
func _lash(p) -> void:
	var main = p.main
	main.add_wave(p.global_position + p.aim * (p.radius + 6.0), p.aim, stat("width"), stat("travel"), damage(), 70.0, false, color(),
		{"states": {"burning": float(Reactions.STATES["burning"]["seconds"])}, "source": self, "amount": maxf(1.0, damage() * 0.2)})
	main.sfx("swing_heavy", 1.1)
	main.sfx("burn", 1.0, -4.0)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.4, 1.4, 0.3)


# Kindles your weapon; while it burns, parries explode.
func _searing(p) -> void:
	p.kindle_t = maxf(p.kindle_t, stat("duration"))
	p.kindle_dmg = maxf(p.kindle_dmg, 3.0 * power())
	p.kindle_color = color()
	var cap = spell_stat(data()["spells"][0], "heat_cap")  # (Forge Heart holds for any kindling)
	p.kindle_cap = maxf(100.0, float(cap) if cap != null else 100.0)
	p.searing_dmg = damage()
	p.main.fx_ring(p.global_position, color(), 36.0, 0.35, 3.0)
	p.main.sfx("burn", 1.0, -4.0)


# All your heat, released in one blow in front of you.
func _overheat(p) -> void:
	var main = p.main
	var heat: float = p.heat
	var dmg: float = (float(stat("damage")) + heat * 0.5) * power()
	var reach: float = stat("reach")
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + e.radius and absf(p.aim.angle_to(to)) <= deg_to_rad(65.0):
			e.take_hit(dmg, to.normalized(), 260.0, true)
			if not e.dead:
				Reactions.apply(main, e, "burning", float(Reactions.STATES["burning"]["seconds"]), self)
			hits += 1
	wyvern().overheat(self, p, heat)  # (Brand's brands ignite; its Apex: a ring and Kindle Blade lit again)
	p.heat = 0.0
	main.fx_cone(p.global_position, p.aim, reach + 10.0, deg_to_rad(65.0), color())
	main.fx_text(p.global_position + Vector2(0, -40), "Overheat! %d" % int(dmg), color())
	main.sfx("crit", 0.8)
	main.sfx("burn", 0.8)
	main.light_flash(p.global_position + p.aim * 40.0, color(), 1.0 + heat / 60.0, 1.8, 0.4)
	main.shake(4.0 + heat / 15.0)
	main.hitstop(0.1)


# --- Rune Artist ----------------------------------------------------------------------

const MAX_RUNES := 3


func _trap(p) -> void:
	var main = p.main
	var at: Vector2 = p.global_position + p.aim * 50.0
	at = at.clamp(main.room.position + Vector2(20, 20), main.room.end - Vector2(20, 20))
	var cp = stat("creep_power")  # (Creeping Runes burst harder)
	var rune := {"pos": at, "r": 22.0, "blast": stat("blast"), "damage": damage() * (float(cp) if cp != null else 1.0), "linked": bool(stat("linked")), "color": color(), "t": 40.0}
	if rune["linked"] and stat("link_damage") != null:  # (Linked Runes: fire runs between them, main.gd _update_runes)
		rune["link"] = float(stat("link_damage")) * power() * flow_power
		rune["link_w"] = float(stat("link_width"))
		rune["link_fire"] = float(stat("link_fire")) if stat("link_fire") != null else 0.0
	main.runes.append(rune)
	while main.runes.size() > MAX_RUNES:
		main.runes.pop_front()
	wyvern().creep(self, p, rune)  # (Creeping Runes)
	main.fx_ring(at, color(), 26.0, 0.3, 2.0)
	main.sfx("ready", 0.7, -4.0)


const GEAR_RUNES := ["sharpness", "warding", "swiftness"]
const GEAR_NAMES := {"sharpness": "Sharpness: strikes hit harder", "warding": "Warding: you take less damage", "swiftness": "Swiftness: you move faster"}


func _inscribe(p) -> void:
	var i := (GEAR_RUNES.find(p.rune_gear) + 1) % GEAR_RUNES.size()
	p.rune_gear = GEAR_RUNES[i]
	p.main.fx_text(p.global_position + Vector2(0, -40), GEAR_NAMES[p.rune_gear], color())
	p.main.fx_ring(p.global_position, color(), 24.0, 0.3, 2.0)
	p.main.sfx("ready", 1.1, -4.0)


func _ward(p) -> void:
	p.main.wards.append({"pos": p.global_position, "r": stat("radius"), "t": stat("duration"), "color": color()})
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.4, 4.0)
	p.main.sfx("parry", 0.6, -4.0)


func _sigil(p) -> void:
	var sig := {"pos": p.global_position, "r": stat("radius"), "t": stat("duration"), "color": color()}
	p.main.sigils.append(sig)
	wyvern().follow_sigil(self, p, sig)  # (its Apex: it moves with you a while)
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.5, 5.0)
	p.main.light_flash(p.global_position, color(), 1.6, 2.0, 0.5)
	p.main.sfx("crit", 0.6, -4.0)


# --- Sandshaper ----------------------------------------------------------------------

## Points along a line across `dir`, centred on `center`, `spacing` apart.
static func _line_points(center: Vector2, dir: Vector2, length: float, spacing: float) -> Array:
	var pts: Array = []
	var n := int(length / spacing)
	var side := dir.orthogonal()
	for i in n + 1:
		pts.append(center + side * (float(i) - float(n) / 2.0) * spacing)
	return pts


func _quake(p) -> void:
	var main = p.main
	var r: float = stat("radius")
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() < r + e.radius:
			e.take_hit(damage(), to.normalized(), 160.0, true)  # (a heavy blow: a foe in the air is slammed, Crater)
			if not e.dead and not e.is_boss():
				e.stagger(0.4)
				if Pacts.has(p, "dust_devil"):  # Dust Devil (Windwalker and Sandshaper): it's thrown up
					e.lift(Pacts.num("dust_devil", "lift"))
			if not e.dead:
				manticore().upheave(self, e)  # (Upheaval: thrown into the air)
	main.rubble.append({"pos": p.global_position, "r": r, "t": 4.0})
	manticore().shatter(self, p, p.global_position, r)  # (Shatter: shards on the ground)
	if bool(stat("ring")):
		var ring: Array = []
		for i in 10:
			ring.append(p.global_position + Vector2.from_angle(TAU * i / 10.0) * (r + 6.0))
		main.add_stone_wall(ring, 9.0, 4.0)
	main.fx_ring(p.global_position, color(), r, 0.4, 6.0)
	main.fx_burst(p.global_position, Vector2.ZERO, color(), 20, 260.0)
	main.sfx("slam", 0.85)
	main.shake(7.0)
	if _overdrawn():
		p.stagger_self(0.4)  # an overdrawn quake knocks you down too


func _sandwall(p) -> void:
	var center: Vector2 = p.global_position + p.aim * 60.0
	p.main.add_stone_wall(_line_points(center, p.aim, stat("length"), 18.0), 11.0, stat("duration"))
	p.main.fx_burst(center, p.aim, color(), 14, 200.0)
	p.main.sfx("hit_heavy", 0.7, -4.0)
	p.main.shake(3.0)


func _sinkhole(p) -> void:
	var main = p.main
	var target = _target_in_aim(p, 280.0)
	var at: Vector2 = target.global_position if target != null else p.global_position + p.aim * 140.0
	main.pits.append({"pos": at, "r": 30.0, "t": 2.5})
	main.fx_ring(at, color(), 36.0, 0.4, 4.0)
	main.sfx("slam", 0.75)
	if target == null:
		return
	if target.radius <= 13.0 and not target.is_boss():
		main.fx_text(at + Vector2(0, -24), "Swallowed", color())
		target.submerged = false
		target.take_hit(99999.0, Vector2.ZERO, 0.0)
	else:
		main.fx_text(at + Vector2(0, -target.radius - 24), "Trapped", color())
		target.stagger(float(stat("trap")) * (0.5 if target.is_boss() else 1.0))


func _fault(p) -> void:
	var center: Vector2 = p.global_position + p.aim * 90.0
	manticore().bury(self, p, center)  # (its Apex: foes on the line are buried and crushed)
	p.main.add_stone_wall(_line_points(center, p.aim, stat("length"), 16.0), 9.0, stat("duration"), true)
	p.main.fx_burst(center, p.aim, color(), 20, 240.0)
	p.main.sfx("slam", 0.7)
	p.main.shake(6.0)


# --- Venomist ------------------------------------------------------------------------

func _spit(p) -> void:
	var main = p.main
	var b = main.spawn_player_arrow(p.global_position + p.aim * (p.radius + 6.0), p.aim * 520.0, damage(), 60.0, bool(stat("pierce")))
	b.style = "venom"
	b.tint = color()
	b.venom = int(stat("stacks"))
	manticore().bloom(self, b)  # (Bloom: a cloud where it lands)
	main.sfx("hit_slime", 1.4, -4.0)
	if _overdrawn():
		p.poison(1.5)  # an overdrawn spit poisons you briefly


func _cloud(p) -> void:
	var at: Vector2 = p.global_position + p.aim * 110.0
	p.main.clouds.append({"pos": at, "r": stat("radius"), "t": stat("duration"), "tick": 0.0, "color": color()})
	p.main.sfx("gust", 0.6, -4.0)


func _neuro(p) -> void:
	p.neuro_t = stat("duration")
	p.neuro_paralyze = stat("paralyze")
	p.main.fx_ring(p.global_position, color(), 26.0, 0.3, 2.0)
	p.main.sfx("ready", 1.3, -4.0)


# Every poisoned foe within `radius` bursts: all its poison still to come at
# once, plus `damage` for each stack. Then the venom leaps: each foe within
# `spread_radius` of a burst that wasn't poisoned itself takes `spread` of the
# most stacks that burst beside it. A foe that had `stagger_at` stacks or
# more is staggered (half as long for a beast).
func _virulence(p) -> void:
	var main = p.main
	var col := color()
	var per: float = damage()
	var burst: Array = []  # [foe, stacks, where]
	for e in main.targets():
		if e.venom > 0 and not e.dead and e.global_position.distance_to(p.global_position) <= float(stat("radius")) + e.radius:
			burst.append([e, int(e.venom), e.global_position])
	for b in burst:
		var e = b[0]
		var stacks: int = b[1]
		var dmg: float = e.venom_left() + per * stacks
		e.venom = 0
		e.venom_t = 0.0
		main.fx_text(e.global_position + Vector2(0, -e.radius - 30.0), "Virulence %d" % int(dmg), col)
		main.fx_burst(e.global_position, Vector2.ZERO, col, 12, 220.0)
		e.take_hit(dmg, Vector2.ZERO, 0.0)
		if is_instance_valid(e) and not e.dead and stacks >= int(stat("stagger_at")):
			e.stagger(float(stat("stagger")) * (0.5 if e.is_boss() else 1.0))
	var burst_foes: Array = burst.map(func(b): return b[0])
	for e in main.targets():
		if e.dead or e in burst_foes or e.venom > 0:
			continue
		var most := 0
		var from := Vector2.ZERO
		for b in burst:
			if int(b[1]) > most and e.global_position.distance_to(b[2]) <= float(stat("spread_radius")) + e.radius:
				most = int(b[1])
				from = b[2]
		var n := int(ceil(float(most) * float(stat("spread"))))
		if n > 0:
			e.add_venom(n)
			main.fx_bolt([from, e.global_position], col)
	manticore().refill(self, p, burst.size())  # (its Apex: each foe burst refills the mark)
	main.sfx("burn", 0.7)
	main.fx_ring(p.global_position, col, float(stat("radius")), 0.4, 3.0)
	main.light_flash(p.global_position, col, 1.6, 1.4, 0.3)
	if burst.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "nothing poisoned", col)


# --- Ashwalker ------------------------------------------------------------------------

func _veil(p) -> void:
	var main = p.main
	var sm := {"pos": p.global_position, "r": stat("radius"), "t": stat("duration")}
	main.smokes.append(sm)
	manticore().veil(self, p, sm)  # (step 3: Ember Smoke or Shroud Walk)
	main.sfx("gust", 0.5, -2.0)
	if _overdrawn():
		p.poison(1.0)  # an overdrawn veil chokes you as well


func _decoy(p) -> void:
	p.main.decoys.append({"pos": p.global_position, "t": stat("duration"), "aim": p.aim})
	p.main.fx_burst(p.global_position, Vector2.ZERO, Color(0.6, 0.55, 0.55), 12, 160.0)
	p.main.sfx("gust", 1.2, -4.0)


func _vanish(p) -> void:
	p.vanish_t = stat("duration")
	p.main.fx_burst(p.global_position, Vector2.ZERO, Color(0.5, 0.45, 0.45), 16, 180.0)
	p.main.sfx("gust", 1.4, -4.0)


func _ashfall(p) -> void:
	p.main.ashfall_t = stat("duration")
	p.main.sfx("gust", 0.4)
	p.main.light_flash(p.global_position, Color(0.6, 0.5, 0.45), 2.0, 1.0, 0.6)


# --- Flame Contractor -----------------------------------------------------------------

## Throws a fireball (returned: Sunfire and Seeker Flame shape it further, firebird.gd).
func _fireball(p, split: int) -> Node2D:
	var main = p.main
	var b = main.spawn_player_arrow(p.global_position + p.aim * (p.radius + 6.0), p.aim * 420.0, damage(), 80.0, false)
	b.style = "fireball"
	b.tint = color()
	b.explode_r = stat("radius")
	b.explode_dmg = damage()
	b.cluster = split
	b.life = 0.15 if _overdrawn() else 1.0  # an overdrawn fireball bursts early, close to you
	main.sfx("burn", 1.2, -4.0)
	return b


func _firewall(p) -> void:
	var center: Vector2 = p.global_position + p.aim * 70.0
	for pt in _line_points(center, p.aim, stat("length"), 26.0):
		p.main.add_flame(pt, 18.0, stat("duration"), true)
	p.main.sfx("burn", 0.9)
	p.main.light_flash(center, color(), 1.4, 1.2, 0.3)


func _meteor(p) -> void:
	var target = _target_in_aim(p, 300.0)
	var at: Vector2 = target.global_position if target != null else p.global_position + p.aim * 180.0
	p.main.meteors.append({"pos": at, "r": stat("radius"), "dmg": damage(), "t": 0.6, "color": color()})
	p.main.sfx("charge", 0.4)
	# Apex: it leaves a burning crater where it lands (firebird.gd).
	var crater = stat("crater")
	if crater != null and float(crater) > 0.0:
		load("res://scripts/spells/firebird.gd").crater(self, p, at, float(stat("radius")), float(crater), 0.6)


# --- Flamewing -----------------------------------------------------------------------

# Toggles the aura: on (it drains this mark's essence while it burns) or off.
func _aura(p) -> void:
	if p.aura_part != "":
		p.aura_part = ""
		p.main.fx_text(p.global_position + Vector2(0, -40), "Aura off", color())
		return
	p.aura_part = part
	p.aura_time = 0.0
	p.aura_dmg = damage()
	p.aura_r = stat("radius")
	p.aura_drain = stat("drain")
	p.aura_grows = bool(stat("grows"))
	# Furnace (step 3's first side): the heat builds over `ramp` seconds, `heat` times as fast, and slows.
	p.aura_ramp = float(stat("ramp")) if stat("ramp") != null else 10.0
	p.aura_heat_mult = float(stat("heat")) if stat("heat") != null else 1.0
	p.aura_peak = float(stat("peak")) if stat("peak") != null else 1.0
	p.aura_slow = stat("slow") == true
	p.aura_color = color()
	# Ember Wings (step 3's second side): the aura reaches out as wings (firebird.gd).
	if stat("wings") != null:
		load("res://scripts/spells/firebird.gd").ember_wings(self, p)
	p.main.fx_ring(p.global_position, color(), stat("radius"), 0.35, 3.0)
	p.main.sfx("burn", 1.0, -4.0)


func _wingburst(p) -> void:
	var main = p.main
	var r: float = stat("radius") * (1.5 if p.firebird_t > 0.0 else 1.0)
	var dmg: float = damage() + p.aura_heat * 0.5
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() < r + e.radius:
			e.take_hit(dmg, to.normalized(), 220.0, true)
			if not e.dead:
				Reactions.apply(main, e, "burning", float(Reactions.STATES["burning"]["seconds"]), self)
	p.aura_heat = 0.0
	main.fx_ring(p.global_position, color(), r, 0.4, 6.0)
	main.fx_burst(p.global_position, Vector2.ZERO, color(), 26, 340.0)
	main.light_flash(p.global_position, color(), 2.0, 2.0, 0.4)
	main.sfx("gust", 0.7)
	main.sfx("burn", 0.8)
	main.shake(6.0)
	if _overdrawn():
		p.hp = maxf(1.0, p.hp - 5.0)  # an overdrawn Wingburst sears you too
		main.fx_text(p.global_position + Vector2(0, -30), "-5", color())


func _warmth(p) -> void:
	p.warmth_t = stat("duration")
	p.warmth_heal = stat("heal")
	p.main.fx_ring(p.global_position, color(), 40.0, 0.35, 3.0)
	p.main.sfx("ready", 0.9, -4.0)


func _firebird_form(p) -> void:
	p.firebird_t = stat("duration")
	p.firebird_fly = stat("flight") == true  # Apex: you fly over chasms and hazards (player.gd flying)
	if p.aura_part == "":
		# Turn the aura on too, from whichever mark knows it.
		for b in p.bonds.values():
			if b.id == "flamewing":
				var keep: int = b.selected
				for i in b.spells().size():
					if b.spells()[i]["type"] == "aura":
						b.select(i)
						b._aura(p)
				b.select(keep)
	p.main.fx_ring(p.global_position, color(), 120.0, 0.5, 6.0)
	p.main.light_flash(p.global_position, color(), 2.4, 2.2, 0.6)
	p.main.sfx("crit", 0.6)


# --- Rekindler ----------------------------------------------------------------------

func _rekindle(p) -> void:
	var dur: float = stat("duration") * (1.4 if _overdrawn() else 1.0)  # overdrawn: burns longer
	p.rekindle_t = dur
	p.rekindle_total = dur
	p.rekindle_loss = p.max_hp * float(stat("loss"))
	p.rekindle_lost = 0.0
	p.rekindle_fought = false
	p.rekindle_spread = bool(stat("spread"))
	p.rekindle_tick = 0.0
	p.rekindle_per = 0.0  # (Bonfire and Cauterize set their own after: firebird.gd)
	p.rekindle_most = 0
	p.rekindle_shield = 0.0
	p.rekindle_burned.clear()
	p.main.fx_ring(p.global_position, color(), 30.0, 0.3, 3.0)
	p.main.sfx("burn", 1.0)


func _desperation(p) -> void:
	p.desperate_t = stat("duration")
	p.main.fx_ring(p.global_position, color(), 34.0, 0.3, 3.0)
	p.main.sfx("warn_knight", 1.3, -4.0)


func _pyre(p) -> void:
	p.pyre_t = stat("duration")
	p.pyre_dmg = damage()
	p.main.fx_ring(p.global_position, color(), 40.0, 0.35, 3.0)
	p.main.sfx("charge", 0.8)


func _phoenix(p) -> void:
	p.phoenix_t = stat("duration")
	# Apex: at its end you regain (this share of) the health it held back (player.gd).
	p.phoenix_regain = float(stat("regain")) if stat("regain") != null else 0.0
	p.phoenix_held = 0.0
	p.main.fx_ring(p.global_position, color(), 60.0, 0.45, 4.0)
	p.main.light_flash(p.global_position, color(), 1.8, 1.8, 0.4)
	p.main.sfx("crit", 0.7)


# --- Covenant ------------------------------------------------------------------------

const MAX_OUT := 3  # never more than three creatures out at once


## Aimed at a monster below a quarter of its health: binds its kind into the
## kin book (kept between climbs). Otherwise calls the next creature of
## your retinue (the first three kinds in the book; a spirit familiar until
## you've bound one).
func _call(p) -> void:
	var main = p.main
	var target = _target_in_aim(p, 240.0)
	if target != null and target.hp < target.max_hp * 0.25 and not target.is_boss() and not target.mirror:  # (a mirror image can't be bound)
		if not target.kind in main.profile.pacts:
			main.profile.pacts.append(target.kind)
			main.profile.save()
		main.fx_text(target.global_position + Vector2(0, -target.radius - 30.0), "Bound: %s" % target.kind, color())
		main.fx_ring(target.global_position, color(), 40.0, 0.4, 4.0)
		main.sfx("crit", 1.1, -4.0)
		target.submerged = false
		target.take_hit(99999.0, Vector2.ZERO, 0.0)
		return
	var retinue: Array = main.profile.pacts.slice(0, 3)
	if retinue.is_empty():
		retinue = ["familiar"]
	var seconds: float = stat("duration") * (0.5 if _overdrawn() else 1.0) * _stay()  # half-bound
	for i in int(stat("count")):
		if main.allies().size() >= MAX_OUT:
			break
		var kind: String = retinue[p.call_index % retinue.size()]
		p.call_index += 1
		main.spawn_ally(kind, p.global_position + p.aim.rotated(0.8 * (i - 0.5)) * 40.0, step, seconds)
	main.sfx("ready", 0.7)


func _command(p) -> void:
	var main = p.main
	var target = _target_in_aim(p, 320.0)
	for a in main.allies():
		a.ally_target = target
		a.ally_guard = target == null
	if target != null:
		main.fx_ring(target.global_position, color(), target.radius + 10.0, 0.3, 3.0)
		main.fx_text(target.global_position + Vector2(0, -target.radius - 30.0), "Attack!", color())
	else:
		main.fx_text(p.global_position + Vector2(0, -40), "Guard me", color())


func _exchange(p) -> void:
	var main = p.main
	var best = null
	var best_d := INF
	for a in main.allies():
		var d: float = a.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		main.fx_text(p.global_position + Vector2(0, -40), "no creature to swap with", color())
		return
	var here: Vector2 = p.global_position
	p.global_position = main.walkable_point(here, best.global_position, 14.0)
	best.global_position = here
	best.reset_physics_interpolation()  # (a swap, not a slide)
	main.fx_ring(here, color(), 24.0, 0.3, 3.0)
	main.fx_ring(p.global_position, color(), 24.0, 0.3, 3.0)
	main.sfx("gust", 1.3, -4.0)


func _grand_call(p) -> void:
	var main = p.main
	var kinds: Array = main.profile.pacts.slice(0, 6)
	if kinds.is_empty():
		kinds = ["familiar", "familiar"]
	# Apex: they arrive empowered (`might`), and it drains the whole mark only if `drains`.
	var might: float = float(stat("might")) if stat("might") != null else 1.0
	for i in kinds.size():
		var a = main.spawn_ally(kinds[i], p.global_position + Vector2.from_angle(TAU * i / kinds.size()) * 60.0, step, float(stat("duration")) * _stay())
		if might != 1.0:
			a.max_hp *= might
			a.hp = a.max_hp
			a.dmg *= might
			a.scale = Vector2.ONE * 1.15
			a.set_meta("empowered", true)
	if stat("drains") != false:
		essence = 0.0  # drains the whole mark
	main.light_flash(p.global_position, color(), 2.4, 2.0, 0.5)
	main.sfx("crit", 0.6)


## Kinship from rank II: your creatures stay longer (bonds.gd passive "stay").
func _stay() -> float:
	return Bonds.passive_num(id, 2, "stay", 1.0) if id == "covenant" and passive_rank() >= 2 else 1.0


# --- Grafter -----------------------------------------------------------------------

func _graft_burst(p, dmg: float, with_effects: bool) -> void:
	var main = p.main
	var n: int = main.grafts.size()
	var effects: bool = with_effects and bool(stat("effects"))
	var k: float = spell_power(spell()) * flow_power
	var r: float = float(stat("radius")) + float(stat("per_graft_radius")) * n + (40.0 if effects and main.grafts.has("throat") else 0.0)
	var total: float = dmg + float(stat("per_graft")) * k * n + (5.0 * k if effects and main.grafts.has("hand") else 0.0)
	var shove: float = float(stat("shove")) * (1.6 if effects and main.grafts.has("legs") else 1.0)
	for e in main.targets():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() < r + e.radius:
			var kind: String = e.kind
			var at: Vector2 = e.global_position
			var harvest: bool = not e.is_boss() and not e.mirror and not e.shade
			e.take_hit(total, to.normalized(), shove, true)
			if e.dead and harvest:
				graft_drop(main, at, kind)  # a foe the burst slays always leaves a graft
			if effects and not e.dead:
				if main.grafts.has("brow"):
					e.stagger(0.6)
				if main.grafts.has("back"):
					e.add_venom(2)
	if effects and main.grafts.has("heart"):
		p.hp = minf(p.max_health(), p.hp + 4.0 * n * p.heal_mult())
	main.fx_ring(p.global_position, color(), r, 0.4, 5.0)
	main.fx_burst(p.global_position, Vector2.ZERO, color(), 18 + 4 * n, 280.0)
	main.sfx("hit_heavy", 0.8)
	main.shake(4.0)
	# An overdrawn burst may make a graft reject.
	if _overdrawn() and not main.graft_order.is_empty() and randf() < 0.5:
		var lost: String = main.graft_order.pop_back()
		main.grafts.erase(lost)
		main.fx_text(p.global_position + Vector2(0, -44), "Your %s graft rejects" % lost, Color(0.9, 0.5, 0.5))


## Leaves a graft of `kind` where a foe fell, if its body part is still free
## and none lies there already (the Grafter's bursts, Harvest).
static func graft_drop(main, at: Vector2, kind: String) -> void:
	if main.grafts.has(main.graft_part(kind)):
		return
	if main.graft_drops.any(func(g): return g["pos"].distance_to(at) < 4.0):
		return
	main.graft_drops.append({"pos": at, "kind": kind, "t": float(main.GRAFT_DROP["life"])})


## Mimic: the newest graft's monster trick, once. With no graft, the trick of
## the foe nearest your aim (within `reach`).
func _mimic(p) -> void:
	var main = p.main
	var part := ""
	var kind := ""
	if not main.graft_order.is_empty():
		part = main.graft_order[-1]
		kind = main.grafts[part]
	else:
		var t = _target_in_aim(p, float(stat("reach")))
		if t == null:
			main.fx_text(p.global_position + Vector2(0, -40), "nothing to mimic", color())
			return
		kind = t.kind
		part = main.graft_part(kind)
		main.fx_bolt([p.global_position, t.global_position], color())
	var dmg := damage()
	match part:
		"hand":  # a heavy blow in front
			for e in main.targets():
				var to: Vector2 = e.global_position - p.global_position
				if to.length() < 80.0 + e.radius and absf(p.aim.angle_to(to)) < deg_to_rad(60.0):
					e.take_hit(dmg * 1.5, to.normalized(), 300.0, true)
			main.fx_cone(p.global_position, p.aim, 90.0, deg_to_rad(60.0), color())
		"legs":  # a swoop straight ahead, cutting through
			var start: Vector2 = p.global_position
			var end: Vector2 = main.walkable_point(start, start + p.aim * 130.0, 14.0)
			for e in main.targets():
				if Geometry2D.get_closest_point_to_segment(e.global_position, start, end).distance_to(e.global_position) < e.radius + 16.0:
					e.take_hit(dmg, p.aim, 160.0)
			p.global_position = end
			p.iframes = maxf(p.iframes, 0.2)
		"heart":  # mends flesh
			p.hp = minf(p.max_health(), p.hp + dmg * p.heal_mult())
		"brow":  # a stunning shriek
			for e in main.targets():
				if e.global_position.distance_to(p.global_position) < 90.0 + e.radius:
					e.stagger(1.2)
		"throat":  # a burst of sparks
			for e in main.targets():
				var to2: Vector2 = e.global_position - p.global_position
				if to2.length() < 120.0 + e.radius:
					e.take_hit(dmg * 0.8, to2.normalized(), 180.0)
		"back":  # slip behind the foe you aim at
			var t = _target_in_aim(p, 220.0)
			if t != null:
				p.global_position = main.walkable_point(t.global_position, t.global_position - t.face * (t.radius + p.radius + 6.0), 14.0)
				p.aim = t.face
	main.fx_text(p.global_position + Vector2(0, -40), "Mimic: %s" % kind, color())
	main.fx_ring(p.global_position, color(), 34.0, 0.3, 3.0)
	main.sfx("gust", 1.0, -4.0)


## Shed: cast off your newest graft in a burst that heals its part's burn.
## With no graft, a layer of skin: a lesser burst (`bare`) that heals the
## burn of the part this mark sits on.
func _shed(p) -> void:
	var main = p.main
	if main.graft_order.is_empty():
		burned = false
		main.fx_text(p.global_position + Vector2(0, -44), "Shed your skin", color())
		_graft_burst(p, damage() * float(stat("bare")), false)
		return
	var gone: String = main.graft_order.pop_back()
	main.grafts.erase(gone)
	if p.bonds.has(gone):
		p.bonds[gone].burned = false
	main.fx_text(p.global_position + Vector2(0, -44), "Shed your %s graft" % gone, color())
	_graft_burst(p, damage(), false)


func _chimera_form(p) -> void:
	p.chimera_t = stat("duration")
	p.main.fx_ring(p.global_position, color(), 60.0, 0.45, 5.0)
	p.main.sfx("crit", 0.7)
	# Apex: your grafts' powers fire on their own while it lasts (chimera.gd).
	if stat("every") != null and float(stat("every")) > 0.0:
		load("res://scripts/spells/chimera.gd").grafts_awake(self, p)


# --- Surgeon -----------------------------------------------------------------------

func _sever(p) -> void:
	var main = p.main
	var t = _target_in_aim(p, 130.0)
	if t == null:
		main.fx_text(p.global_position + Vector2(0, -40), "no one in reach", color())
		return
	t.take_hit(damage(), (t.global_position - p.global_position).normalized(), 60.0)
	if t.dead:
		main.sfx("swing", 1.6)
		return
	# The cut bleeds (reactions.gd), and slows it while it's crippled;
	# Toxic Precision (Venomist and Surgeon) adds poison.
	# (Arterial Cut, step 3's second side, bleeds harder: its own "bleed" share.)
	var bleed: float = float(stat("bleed")) if stat("bleed") != null else 0.15
	Reactions.apply(main, t, "bleeding", float(stat("duration")), self, maxf(1.0, damage() * bleed))
	Reactions.apply(main, t, "slowed", float(stat("duration")), self)
	if Pacts.has(p, "toxic_precision") and not t.dead:
		t.add_venom(int(Pacts.num("toxic_precision", "stacks")))
	if t.dead:
		main.sfx("swing", 1.6)
		return
	if bool(stat("disarm")) and t.cripple_t > 0.0:
		t.disarm_t = stat("duration")
		main.release_attack(t)
		main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), "Disarmed", color())
	else:
		t.cripple_t = stat("duration")
		main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), "Crippled", color())
	# Vivisect (step 3's first side): a weak point; your next hits on it are critical (player.gd _strike).
	if stat("crits") != null and int(stat("crits")) > 0:
		load("res://scripts/spells/chimera.gd").weak_point(self, p, t)
	main.sfx("swing", 1.6)


## Diagnosis from rank III: Mend and Bloodletting heal this much more (1 + a
## share for each bleeding foe near you).
static func bleeding_near_mult(p) -> float:
	var rank := 0
	for b in p.bonds.values():
		if b.id == "surgeon":
			rank = b.passive_rank()
	if rank < 3:
		return 1.0
	var reach := Bonds.passive_num("surgeon", 3, "mend_reach", 220.0)
	var n := 0
	for e in p.main.targets():
		if not e.dead and Reactions.has(e, "bleeding") and e.global_position.distance_to(p.global_position) < reach + e.radius:
			n += 1
	return 1.0 + Bonds.passive_num("surgeon", 3, "mend_per", 0.2) * n


func _mend(p) -> void:
	var main = p.main
	var amount: float = float(stat("heal")) * (1.3 if p.has_bond("surgeon") else 1.0) * p.heal_mult() * bleeding_near_mult(p)  # Steady Hands; Life's flow; Diagnosis III
	p.hp = minf(p.max_health(), p.hp + amount)
	p.poison_t = 0.0
	p.fire_t = 0.0
	for a in main.allies():
		if a.global_position.distance_to(p.global_position) < 140.0:
			a.hp = minf(a.max_hp, a.hp + amount)
	main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(amount), Color(0.6, 1.0, 0.7))
	main.fx_ring(p.global_position, color(), 40.0, 0.35, 3.0)
	main.sfx("ready", 0.9)
	if _overdrawn():
		p.poison(3.0)  # an overdrawn Mend opens a wound that bleeds before it closes


func _transfer(p) -> void:
	var main = p.main
	var t = _target_in_aim(p, 260.0)
	if t == null:
		main.fx_text(p.global_position + Vector2(0, -40), "no one to take it", color())
		return
	var moved := 0
	for b in p.bonds.values():
		if b.burned:
			b.burned = false
			t.take_hit(10.0, Vector2.ZERO, 0.0)
			t.add_venom(2)
			moved += 1
	if p.poison_t > 0.0:
		p.poison_t = 0.0
		t.add_venom(3)
		moved += 1
	main.fx_bolt([p.global_position, t.global_position], color())
	main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), "Transferred" if moved > 0 else "nothing to pass on", color())
	main.sfx("zap", 1.3, -4.0)


func _amputate(p) -> void:
	var main = p.main
	var t = _target_in_aim(p, 130.0)
	var below: float = float(stat("below")) if stat("below") != null else 0.5  # (its Apex: up to three quarters)
	if t == null or t.hp > t.max_hp * below:
		main.fx_text(p.global_position + Vector2(0, -40), "not wounded enough", color())
		return
	t.cripple_t = 9999.0
	t.disarm_t = 9999.0
	main.release_attack(t)
	main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), "Amputated", color())
	main.sfx("crit", 1.2)
