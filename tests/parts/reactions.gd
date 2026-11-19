extends RefCounted
## States, reactions and synergies (reactions.gd, synergies.gd): the old
## fields are the states; every reaction fires from real casts and does its
## thing; each named synergy works, and any two marks lend each other their
## traits; the Unbound's essences leave states and react;
## old saves load; the climber-side switch stays off; the book, the Library
## and the Data editor show them. Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")
const R := preload("res://scripts/reactions.gd")
const PA := preload("res://scripts/synergies.gd")

var t
var P = load("res://scripts/profile.gd")
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	# (The reactions on their own first: the traits marks lend each other set
	# off reactions of their own, which _lent tests.)
	var lent: Dictionary = PA.TRAITS
	PA.TRAITS = {}
	await _states()
	await _conduct()
	await _steam()
	await _fumes()
	await _crater()
	await _skybolt()
	await _hemorrhage()
	await _smoulder()
	await _ambush()
	PA.TRAITS = lent
	await _named_tempest_dust_steel()
	await _named_fire()
	await _named_body()
	await _named_hunt()
	await _menagerie()
	await _scald_steel()
	await _lent()
	await _unbound()
	await _saves()
	await _climber_on()
	await _pages()
	await _data()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber with these marks ({part: bond id}) at `step`, alone,
## facing open floor.
func _marked(marks: Dictionary, step := 1) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.regarded = true
	main.first_climb = false
	var bonds := {}
	for part in marks:
		bonds[part] = {"id": marks[part], "xp": float(P.STEP_XP[step - 1]), "faint": false, "debt": 0.0}
	main.profile.bonds = bonds
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	main.grafts.clear()
	main.graft_order.clear()
	main.graft_drops.clear()
	await t._frames(2)
	var p = main.player
	p.iframes = 999.0
	p.global_position = main.room.get_center()
	dir = Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var open := true
		for k in range(1, 16):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


## A foe that stands still where the test puts it (its states still land).
func _foe(at: Vector2, hp := 400.0, kind := "slime"):
	var e = t.main.spawn_enemy(kind, at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = true
	e.notice_t = 0.0
	return e


## Casts the spell `spell_id` from the mark on `part`, as the climber does.
func _cast(part: String, spell_id: String) -> void:
	var main = t.main
	var p = main.player
	var b = p.bonds[part]
	b.select(b.spells().map(func(sp): return sp["id"]).find(spell_id))
	b.essence = b.capacity()
	b.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p.aim = dir
	p._try_cast(part)
	await t._wait(b.windup() + 0.1)
	for i in 120:
		if p.cast_t <= 0.0:
			break
		await t._frames(1)


func _fired(id: String) -> int:
	return int(R.FIRED.get(id, 0))


## Waits until a reaction has fired more than `before` times (at most `secs`).
func _until_fired(id: String, before: int, secs := 1.5) -> void:
	await t._until(func(): return _fired(id) > before, secs)


# --- the states ------------------------------------------------------------------

func _states() -> void:
	print("states: one place for every timed state")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	var e = _foe(p.global_position + dir * 120.0)
	var depth = R.RULES["depth"]
	R.RULES["depth"] = 0  # (no reactions while every state is put on one foe)
	e.charged = 3.0
	_check(R.has(e, "charged") and is_equal_approx(float(e.states["charged"]), 3.0), "a foe's old charge is its 'charged' state (one dictionary)")
	e.chill_t = 2.0
	e.lost_t = 1.0
	e.ignite(2.0, 2.0)
	e.add_venom(2)
	e.soak(2.0)
	e.bleed(1.0, 2.0)
	e.lift(1.0)
	var held: Array = R.held(e)
	_check(held.size() == 8, "chill, lost track, burning, venom, soaked, bleeding and airborne are all states too (%s)" % [held])
	for s in ["charged", "airborne", "soaked", "burning", "poisoned", "bleeding", "slowed", "unseen"]:
		_check(s in held, "...%s" % s)
	R.RULES["depth"] = depth
	R.clear(e, "poisoned")
	_check(e.venom == 0 and not R.has(e, "poisoned"), "a state can be taken away (poison: its stacks go)")
	e.queue_free()
	# Bleeding hurts every half second, like burning.
	var b = _foe(p.global_position + dir * 120.0, 100.0)
	b.set_physics_process(true)
	b.speed = 0.0
	b.bleed(4.0, 2.0)
	await t._wait(0.7)
	_check(b.hp < 100.0 and b.hp >= 100.0 - 4.0 * 3.0, "bleeding hurts every half second (%.0f)" % b.hp)
	await t._wait(1.8)
	_check(not R.has(b, "bleeding"), "...and runs out")
	# A pool on the floor soaks a walking foe.
	b.global_position = p.global_position + dir * 160.0
	main.puddles.append({"pos": b.global_position, "r": 40.0})
	await t._until(func(): return R.has(b, "soaked"), 1.0)
	_check(R.has(b, "soaked"), "standing in water soaks a foe")
	main.puddles.pop_back()
	b.queue_free()
	await t._frames(1)


# --- every reaction from real casts ------------------------------------------------

func _conduct() -> void:
	print("reactions: Conduct (Undertow soaks, Chain Lightning charges)")
	await _marked({"hand": "deepcaller", "legs": "stormcaller"}, 2)  # (Chain Lightning comes at step 2)
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 70.0)
	var b = _foe(p.global_position + dir * 70.0 + dir.orthogonal() * 60.0)
	var far = _foe(p.global_position - dir * 260.0 + dir.orthogonal() * 120.0)
	await _cast("hand", "undertow")  # (drains the nearest two: both soaked)
	_check(R.has(a, "soaked") and R.has(b, "soaked") and not R.has(far, "soaked"), "Undertow soaks the foes it drains")
	var before := _fired("conduct")
	R.clear(b, "soaked")
	b.soak(4.0)
	far.queue_free()
	var hp_b: float = b.hp
	await _cast("legs", "chain_lightning")
	await _until_fired("conduct", before)
	_check(_fired("conduct") > before, "Chain Lightning on a soaked foe: Conduct")
	_check(not R.has(a, "soaked") and not R.has(b, "soaked"), "...it dries every soaked foe it jumps to")
	_check(b.hp < hp_b and b.stun > 0.0, "...which is struck and stunned (%.1f s)" % b.stun)


func _steam() -> void:
	print("reactions: Steam (soaked, then a Fireball)")
	await _marked({"hand": "deepcaller", "legs": "flame_contractor"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 140.0)
	await _cast("hand", "undertow")
	_check(R.has(a, "soaked"), "the foe is soaked")
	var before := _fired("steam")
	await _cast("legs", "fireball")
	await _until_fired("steam", before)
	_check(_fired("steam") > before, "a Fireball on a soaked foe: Steam")
	_check(not R.has(a, "soaked") and not R.has(a, "burning"), "...the water and the fire both go")
	await t._wait(0.4)
	_check(is_instance_valid(a) and a.lost_t > 0.0, "...and a foe in the cloud loses track of you")


func _fumes() -> void:
	print("reactions: Fumes (Venom Spit, then a Fireball)")
	await _marked({"hand": "venomist", "legs": "flame_contractor"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 150.0, 999.0)
	var n = _foe(p.global_position + dir * 150.0 + dir.orthogonal() * 85.0, 999.0)
	await _cast("hand", "venom_spit")
	await t._until(func(): return a.venom > 0, 1.0)
	_check(a.venom > 0 and n.venom == 0, "Venom Spit poisons the foe it hits")
	var before := _fired("fumes")
	main.player.bonds["legs"].select(0)
	# (only the first foe catches the fire: the neighbour stands outside the blast)
	R.apply(main, a, "burning", 3.0, "test")
	await _until_fired("fumes", before)
	_check(_fired("fumes") > before, "fire on a poisoned foe: Fumes")
	_check(n.venom > 0 and R.has(n, "burning"), "...the poison spreads to its neighbour as burning gas (%d stacks)" % n.venom)
	# And from a real Fireball.
	var c = _foe(p.global_position - dir * 10.0 + dir.orthogonal() * 200.0, 999.0)
	c.add_venom(3)
	c.global_position = p.global_position + dir * 150.0 + dir.orthogonal() * -10.0
	a.reacted.clear()
	c.reacted.clear()
	before = _fired("fumes")
	await _cast("legs", "fireball")
	await _until_fired("fumes", before)
	_check(_fired("fumes") > before, "...and a real Fireball sets it off")


func _crater() -> void:
	print("reactions: Crater (Gale Lift, then Quake)")
	await _marked({"hand": "windwalker", "legs": "sandshaper"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 50.0, 999.0)
	await _cast("hand", "gale_lift")
	_check(R.has(a, "airborne"), "Gale Lift throws the foe into the air")
	var n = _foe(p.global_position + dir * 50.0 + dir.orthogonal() * 50.0, 999.0)
	var before := _fired("crater")
	var hp_a: float = a.hp
	await _cast("legs", "quake")
	await _until_fired("crater", before)
	_check(_fired("crater") > before, "a Quake on a foe in the air: Crater")
	_check(hp_a - a.hp > R.num("crater", "damage") * 0.9, "...a big hit (%.0f)" % (hp_a - a.hp))
	_check(n.stun > 0.0 and n.hp < 999.0, "...and its neighbour is knocked down")


func _skybolt() -> void:
	print("reactions: Skybolt (Chain Lightning, then Gale Lift)")
	await _marked({"hand": "stormcaller", "legs": "windwalker"}, 2)  # (Chain Lightning comes at step 2)
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 60.0, 999.0)
	await _cast("hand", "chain_lightning")
	_check(R.has(a, "charged"), "Chain Lightning charges the foe")
	var before := _fired("skybolt")
	var hp_a: float = a.hp
	await _cast("legs", "gale_lift")
	await _until_fired("skybolt", before)
	_check(_fired("skybolt") > before, "lifting a charged foe: Skybolt")
	_check(hp_a - a.hp >= R.num("skybolt", "damage") * 0.9 and not R.has(a, "airborne") and not R.has(a, "charged"), "...a bolt from above, and it falls")


func _hemorrhage() -> void:
	print("reactions: Hemorrhage (Sever, then Undertow)")
	await _marked({"hand": "surgeon", "legs": "deepcaller"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 60.0, 999.0)
	await _cast("legs", "undertow")
	var plain: float = 999.0 - a.hp
	a.hp = 999.0
	await _cast("hand", "sever")
	_check(R.has(a, "bleeding"), "Sever makes the foe bleed")
	var before := _fired("hemorrhage")
	a.hp = 999.0
	await _cast("legs", "undertow")
	_check(_fired("hemorrhage") > before, "draining a bleeding foe: Hemorrhage")
	_check(999.0 - a.hp >= plain * 1.8, "...the drain doubled (%.0f vs %.0f)" % [999.0 - a.hp, plain])


func _smoulder() -> void:
	print("reactions: Smoulder (Sever slows, then a Fireball)")
	await _marked({"hand": "surgeon", "legs": "flame_contractor"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 60.0, 999.0)
	await _cast("hand", "sever")
	_check(R.has(a, "slowed"), "Sever slows the foe")
	var before := _fired("smoulder")
	a.global_position = p.global_position + dir * 140.0
	await _cast("legs", "fireball")
	await _until_fired("smoulder", before)
	_check(_fired("smoulder") > before, "fire on a slowed foe: Smoulder")
	_check(a.burn_t > float(R.STATES["burning"]["seconds"]) * 1.5, "...the burn lasts twice as long (%.1f s)" % a.burn_t)


func _ambush() -> void:
	print("reactions: Ambush (Smoke Veil, then Venom Spit)")
	await _marked({"hand": "ashwalker", "legs": "venomist"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 100.0, 999.0)
	await _cast("hand", "smoke_veil")
	main.smokes[-1]["pos"] = a.global_position
	await t._until(func(): return R.has(a, "unseen"), 1.0)
	_check(R.has(a, "unseen"), "in the smoke the foe loses sight of you")
	var before := _fired("ambush")
	main.smokes.clear()
	var stacks := int(main.player.bonds["legs"].stat("stacks"))
	await _cast("legs", "venom_spit")
	await _until_fired("ambush", before)
	_check(_fired("ambush") > before, "poison on a foe that can't see you: Ambush")
	_check(a.venom >= stacks + int(R.num("ambush", "stacks")), "...5 more stacks (%d)" % a.venom)
	# Smoke on a foe that's already poisoned is no ambush (it would give you away).
	var b = _foe(p.global_position + dir * 100.0 + dir.orthogonal() * 60.0, 999.0)
	b.add_venom(2)
	before = _fired("ambush")
	b.lose_track(3.0, null)
	_check(_fired("ambush") == before and R.has(b, "unseen"), "...but smoke on a foe already poisoned is not, and it stays lost")


# --- named synergies ----------------------------------------------------------------

func _named_tempest_dust_steel() -> void:
	print("synergies: Tempest, Dust Devil, Whirling Steel")
	await _marked({"hand": "tidecaller", "legs": "stormcaller"})
	var main = t.main
	var p = main.player
	_check(PA.held(p) == ["tempest"], "Stormcaller and Tidecaller hold Tempest")
	_check("tempest" in main.profile.synergies_formed, "...announced and remembered the first time it forms")
	var a = _foe(p.global_position + dir * 50.0, 999.0)
	var before := _fired("conduct")
	await _cast("hand", "tidal_surge")
	_check(R.has(a, "charged"), "Tempest: Tidal Surge leaves the foe charged as well as soaked")
	_check(_fired("conduct") > before, "...so the wave sets off Conduct")
	var n0: int = main.profile.synergies_formed.size()
	main._give_bonds()
	_check(main.profile.synergies_formed.size() == n0, "...and is announced only once")
	# Dust Devil.
	await _marked({"hand": "windwalker", "legs": "sandshaper"})
	main = t.main
	p = main.player
	var q = _foe(p.global_position + dir * 50.0, 999.0)
	await _cast("legs", "quake")
	_check(R.has(q, "airborne"), "Dust Devil: Quake throws foes up")
	q.airborne = 0.0
	q.global_position = p.global_position + dir * 60.0
	await _cast("hand", "gale_lift")
	q.airborne = 0.0
	var hp_q: float = q.hp
	await t._until(func(): return R.has(q, "bleeding"), 1.5)
	_check(R.has(q, "bleeding") and q.hp < hp_q, "...Gale Lift leaves shards that cut what walks over them")
	# Whirling Steel.
	await _marked({"hand": "blade_forger", "legs": "windwalker"})
	main = t.main
	p = main.player
	var s = _foe(p.global_position + dir * 90.0, 999.0)
	var k = _foe(p.global_position + dir * 90.0 + dir.orthogonal() * 40.0, 999.0, "knight")
	await _cast("hand", "conjured_blades")
	await t._until(func(): return R.has(s, "airborne"), 1.0)
	_check(R.has(s, "airborne"), "Whirling Steel: conjured blades lift a light foe")
	_check(not R.has(k, "airborne"), "...but not a heavy one (a knight)")


func _named_fire() -> void:
	print("synergies: Forge Runes, Wildfire")
	await _marked({"hand": "flameblade", "legs": "rune_artist"})
	var main = t.main
	var p = main.player
	var a = _foe(p.global_position + dir * 40.0, 999.0)
	await _cast("hand", "kindle_blade")
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p.aim = dir
	p._melee()
	_check(R.has(a, "burning"), "a kindled strike sets the foe burning")
	var forge: Array = main.runes.filter(func(r): return r.get("forge", false))
	_check(forge.size() == 1, "Forge Runes: it leaves a small fire rune")
	a.burn_t = 0.0
	var hp_a: float = a.hp
	await t._until(func(): return main.runes.filter(func(r): return r.get("forge", false)).is_empty(), 2.0)
	_check(a.hp < hp_a and R.has(a, "burning"), "...which goes off under a foe and burns it")
	# Wildfire.
	await _marked({"hand": "flame_contractor", "legs": "flamewing"})
	main = t.main
	p = main.player
	await _cast("legs", "heat_aura")
	_check(p.aura_part == "legs", "the Heat Aura burns")
	var f = _foe(p.global_position + dir * 260.0, 999.0)
	main.add_flame(f.global_position, 30.0, 3.0, true)
	p.aura_heat = 0.0
	await t._wait(1.2)
	_check(R.has(f, "burning"), "burning ground sets a foe burning")
	_check(p.aura_heat > 0.0, "Wildfire: burning ground far from you feeds the aura's heat (%.0f)" % p.aura_heat)


func _named_body() -> void:
	print("synergies: Undying, Bloodletter, Toxic Precision")
	await _marked({"hand": "warden", "legs": "rekindler"})
	var main = t.main
	var p = main.player
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.hp = 5.0
	p.receive_attack(999.0, null, true)
	_check(p.ember_t > 0.0 and not p.dead, "Last Ember keeps the climber standing")
	_check(p.barrier_hp > 0.0, "Undying: ...and raises a barrier (%.0f)" % p.barrier_hp)
	p.ember_t = 0.0
	p.iframes = 999.0
	# Bloodletter.
	await _marked({"hand": "deepcaller", "legs": "surgeon"})
	main = t.main
	p = main.player
	var a = _foe(p.global_position + dir * 60.0, 999.0)
	p.hp = 10.0
	await _cast("hand", "undertow")
	var plain: float = p.hp - 10.0
	await _cast("legs", "sever")
	_check(R.has(a, "bleeding"), "Sever: the foe bleeds")
	p.hp = 10.0
	await _cast("hand", "undertow")
	var bled: float = p.hp - 10.0
	_check(bled >= plain * 3.5, "Bloodletter: draining a bleeding foe heals double, on top of Hemorrhage (%.0f vs %.0f)" % [bled, plain])
	# Toxic Precision.
	await _marked({"hand": "venomist", "legs": "surgeon"})
	main = t.main
	p = main.player
	var v = _foe(p.global_position + dir * 60.0, 999.0)
	await _cast("legs", "sever")
	_check(v.venom >= int(PA.num("toxic_precision", "stacks")), "Toxic Precision: Sever adds 3 poison stacks (%d)" % v.venom)


func _named_hunt() -> void:
	print("synergies: Ambusher")
	await _marked({"hand": "hunter", "legs": "ashwalker"})
	var main = t.main
	var p = main.player
	var seen = _foe(p.global_position + dir * 160.0, 9999.0)
	await _cast("hand", "piercing_shot")
	await t._until(func(): return seen.hp < 9999.0, 1.0)
	var plain: float = 9999.0 - seen.hp
	seen.queue_free()
	await t._frames(1)
	var hid = _foe(p.global_position + dir * 160.0, 9999.0)
	hid.lose_track(5.0, null)
	await _cast("hand", "piercing_shot")
	await t._until(func(): return hid.hp < 9999.0, 1.0)
	var unseen: float = 9999.0 - hid.hp
	# (Ashwalker's own Unseen Strike triples it; the synergy's weak point doubles that)
	_check(unseen >= plain * 3.0 * PA.num("ambusher", "mult") * 0.9, "Ambusher: an unseen shot strikes a weak point (%.0f vs %.0f)" % [unseen, plain])


func _menagerie() -> void:
	print("synergies: Menagerie")
	await _marked({"hand": "covenant", "legs": "grafter"})
	var main = t.main
	var p = main.player
	_check(PA.has(p, "menagerie"), "Covenant and Grafter hold Menagerie")
	var target = _foe(p.global_position + dir * 90.0, 999.0)
	_check(is_equal_approx(PA.ally_strike(main, null, target, 10.0), 10.0), "with no graft, a creature's blow is its own")
	main.add_graft("knight")
	_check(is_equal_approx(PA.ally_strike(main, null, target, 10.0), 10.0 * PA.num("menagerie", "hand")), "a hand graft: your creatures hit harder")
	# A creature out in the room strikes with it.
	var ally = main.spawn_ally("familiar", target.global_position - dir * 30.0, 1, 10.0)
	ally.ally_target = target
	ally.ally_cd = 0.0
	ally.global_position = target.global_position - dir * (target.radius + ally.radius + 4.0)
	var hp0: float = target.hp
	await t._until(func(): return target.hp < hp0, 1.5)
	_check(hp0 - target.hp >= ally.dmg * PA.num("menagerie", "hand") * 0.95, "...a creature's blow carries the graft's power (%.1f, its own %.1f)" % [hp0 - target.hp, ally.dmg])
	main.graft_order.clear()
	main.grafts.clear()
	main.add_graft("ram")
	_check(is_equal_approx(PA.ally_tick(main, ally, 0.0), PA.num("menagerie", "legs")), "a legs graft: they move faster")
	main.add_graft("thornhound")  # (a second legs graft can't bind: the ram's stays newest)
	main.graft_order.clear()
	main.grafts.clear()
	main.add_graft("scorpling")
	var v0: int = target.venom
	PA.ally_strike(main, ally, target, 1.0)
	_check(target.venom > v0, "a back graft: their blows poison")
	ally.queue_free()


func _scald_steel() -> void:
	print("synergies: Scald, Lightning Steel")
	await _marked({"hand": "tidecaller", "legs": "flame_contractor"})
	var main = t.main
	var p = main.player
	_check(PA.held(p) == ["scald"], "Tidecaller and Flame Contractor hold Scald")
	var a = _foe(p.global_position + dir * 200.0, 999.0)
	var b = _foe(p.global_position + dir * 200.0 + dir.orthogonal() * 40.0, 999.0)
	a.soak(4.0)
	main.add_flame(a.global_position, 20.0, 3.0, true)
	await t._until(func(): return R.has(a, "unseen"), 1.5)
	_check(R.has(a, "unseen") and R.has(b, "unseen") and a.hp < 999.0, "Scald: your burning ground under a soaked foe bursts into steam that blinds it and the foes beside it")
	_check(not R.has(a, "soaked"), "...and dries it off")
	# Lightning Steel.
	await _marked({"hand": "blade_forger", "legs": "stormcaller"})
	main = t.main
	p = main.player
	_check(PA.held(p) == ["lightning_steel"] and PA.lent(p, "blade_forger").is_empty(), "Stormcaller and Blade Forger hold Lightning Steel (and lend no traits: it takes their place)")
	var s = _foe(p.global_position + dir * 90.0, 999.0)
	await _cast("hand", "conjured_blades")
	await t._until(func(): return R.has(s, "charged"), 1.0)
	_check(R.has(s, "charged"), "Lightning Steel: a conjured blade that strikes leaves its foe charged")
	await t._wait(1.5)  # (the cast's blades are gone)
	var side: Vector2 = dir.orthogonal()
	var at: Vector2 = p.global_position + dir * 160.0
	var b1 = main.spawn_player_arrow(at, Vector2.ZERO, 0.0, 0.0, false)
	b1.style = "blade"
	b1.life = 5.0
	var b2 = main.spawn_player_arrow(at + side * 150.0, Vector2.ZERO, 0.0, 0.0, false)
	b2.style = "blade"
	b2.life = 5.0
	var mid = _foe(at + side * 75.0, 999.0)
	var n: int = PA.conduct(main, b1, null)
	_check(n >= 1 and mid.hp < 999.0 and R.has(mid, "charged"), "...and lightning leaps between your blades, striking and charging the foes along the bolt (%d)" % n)
	b1.queue_free()
	b2.queue_free()


func _lent() -> void:
	print("synergies: lent traits")
	await _marked({"hand": "stormcaller", "legs": "venomist"})
	var main = t.main
	var p = main.player
	_check(PA.held(p).is_empty() and PA.lent(p, "stormcaller") == ["venomist"] and PA.lent(p, "venomist") == ["stormcaller"], "two marks with no named synergy lend each other their traits")
	_check("lent" in main.profile.synergies_formed, "...and the first time they do, it's remembered (the Entity's first-time tip)")
	var a = _foe(p.global_position + dir * 80.0, 999.0)
	await _cast("hand", "call_lightning")
	_check(a.venom >= int(PA.TRAITS["venomist"]["stacks"]) and a.hp < 999.0, "Venomist lends Venom: Call Lightning's bolt adds a stack of poison (%d)" % a.venom)
	a.charged = 0.0
	a.overcharge_t = 0.0
	await _cast("legs", "venom_spit")
	await t._until(func(): return R.has(a, "charged"), 1.0)
	_check(R.has(a, "charged"), "Stormcaller lends Charge: Venom Spit's shot leaves the foe charged")
	# A kill: Rekindler lends Ember heart.
	await _marked({"hand": "stormcaller", "legs": "rekindler"})
	main = t.main
	p = main.player
	var weak = _foe(p.global_position + dir * 80.0, 2.0)
	p.hp = 10.0
	await _cast("hand", "call_lightning")
	_check((not is_instance_valid(weak) or weak.dead) and p.hp > 10.0, "Rekindler lends Ember heart: a spell's kill heals you a little (+%.0f)" % (p.hp - 10.0))
	# A casting trait: Warden lends Guard.
	await _marked({"hand": "hunter", "legs": "warden"})
	main = t.main
	p = main.player
	p.barrier_hp = 0.0
	await _cast("hand", "piercing_shot")
	_check(p.barrier_hp >= float(PA.TRAITS["warden"]["shield"]) * 0.99 or p.barrier_t > 0.0, "Warden lends Guard: casting raises a thin barrier (%.0f)" % p.barrier_hp)
	# A named pair lends nothing; a third mark lends to both.
	await _marked({"hand": "stormcaller", "legs": "tidecaller", "heart": "surgeon"})
	p = t.main.player
	_check(PA.lent(p, "stormcaller") == ["surgeon"] and PA.lent(p, "surgeon").size() == 2, "a named synergy takes the place of its pair's lent traits; a third mark still lends to both (%s)" % [PA.lent(p, "stormcaller")])
	_check(PA.TRAITS.values().all(func(tr): return String(tr["says"]) != "" and String(tr["name"]) != ""), "every lent trait has a name and says what it does")


# --- the Unbound ----------------------------------------------------------------------

func _unbound() -> void:
	print("states: the Unbound's essences leave them, and react")
	await t._ub_fresh()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	var p = main.player
	p.iframes = 9999.0
	p.mouse_aim = false
	p.aim = Vector2.RIGHT
	main.unbound.waver_chance = 0.0
	p.global_position = main.room.get_center()
	var T = load("res://scripts/technique.gd")
	var a = _foe(p.global_position + Vector2(40, 0), 999.0)
	T.cast({"part": "hand", "shape": "strike", "kinds": ["water"]}, p, 1.0, main.unbound)
	_check(R.has(a, "soaked") and R.has(a, "slowed"), "a Water strike soaks and slows")
	var before := _fired("steam")
	T.cast({"part": "hand", "shape": "strike", "kinds": ["fire"]}, p, 1.0, main.unbound)
	_check(_fired("steam") > before, "...and a Fire strike on it makes Steam")
	a.reacted.clear()
	T.cast({"part": "hand", "shape": "strike", "kinds": ["blade"]}, p, 1.0, main.unbound)
	_check(R.has(a, "bleeding"), "a Blade strike makes it bleed")
	before = _fired("smoulder")
	T.cast({"part": "hand", "shape": "strike", "kinds": ["fire", "water"]}, p, 1.0, main.unbound)
	_check(_fired("smoulder") > before, "Fire led with Water: burning and slowed meet, Smoulder")
	# Spark (Air) charges; on a soaked foe it Conducts.
	a.reacted.clear()
	var b = _foe(p.global_position + Vector2(40, 60), 999.0)
	a.soak(4.0)
	before = _fired("conduct")
	T.cast({"part": "hand", "shape": "strike", "kinds": ["air"], "effects": {"air": "spark"}}, p, 1.0, main.unbound)
	_check(R.has(b, "charged") or _fired("conduct") > before, "a Spark leaves foes charged")
	_check(_fired("conduct") > before, "...and on a soaked foe, Conduct")
	# Lifeline drains: on a bleeding foe, Hemorrhage.
	a.bleed(1.0, 4.0)
	before = _fired("hemorrhage")
	var E = load("res://scripts/spells/unbound_effects.gd")
	E.hit_effect("lifeline", p, a, 1.0, 1.0, main.unbound)
	await t._wait(0.7)
	_check(_fired("hemorrhage") > before, "a Lifeline drinking from a bleeding foe: Hemorrhage")


# --- saves, the climber, pages, data -------------------------------------------------

func _saves() -> void:
	print("synergies: old saves")
	var path := TestRun.path("user://smoke_synergies.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "bonds", {"hand": {"id": "stormcaller", "xp": 200.0, "faint": false, "debt": 0.0}, "legs": {"id": "tidecaller", "xp": 0.0, "faint": false, "debt": 0.0}})
	cfg.set_value("profile", "pacts", ["slime"])
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	_check(old.synergies_formed == [] and old.pacts == ["slime"] and old.bonds.size() == 2, "an old save loads: no synergies formed yet, Covenant's bound kinds kept")
	old.saving = true
	old.synergies_formed = ["tempest"]
	old.save()
	var again = P.new()
	again.saving = false
	again.save_path = path
	again.load_save()
	_check(again.synergies_formed == ["tempest"], "synergies formed are saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## (Was "the climber side stays off": the owner switched monsters' states
## on the climber on, so this now checks it's on, and that the switch still
## turns it all off.)
func _climber_on() -> void:
	print("states: the climber side is on (and its switch still works)")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	_check(R.CLIMBER["enabled"] == true, "monsters giving the climber states is on (the owner said yes)")
	main.puddles = []  # (no pool underfoot: fire on a soaked climber would turn to Steam)
	p.states.clear()
	p.barrier_hp = 0.0
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.hp = p.max_health()
	var th = _foe(p.global_position + dir * 40.0, 50.0, "cinder")
	# Switched off (in the Data editor), a cinder's blow leaves nothing.
	R.CLIMBER["enabled"] = false
	p.receive_attack(2.0, th)
	_check(p.states.is_empty() and R.apply(main, p, "burning", 3.0, th).is_empty(), "...switched off, a cinder's blow leaves nothing, and nothing can be put on the climber")
	R.CLIMBER["enabled"] = true
	p.hurt_t = 0.0
	p.iframes = 0.0  # (the first blow's grace must not swallow this one)
	p.parry_t = 0.0
	var hp_was: float = p.hp
	var why := "hurt_t %.2f iframes %.2f parry %.2f unbreak %.2f absorb %.2f barrier %.1f th %s" % [p.hurt_t, p.iframes, p.parry_t, p.unbreak_t, p.absorb_t, p.barrier_hp, th.kind if is_instance_valid(th) else "gone"]
	p.receive_attack(2.0, th)
	var on: bool = R.has(p, "burning")
	why += " | hp %.1f->%.1f states %s" % [hp_was, p.hp, p.states]
	R.CLIMBER["enabled"] = false
	p.set_physics_process(true)  # (an earlier screen may have left the climber still; the clearing runs in its physics step)
	t.paused = false
	await t._until(func(): return p.states.is_empty(), 1.0)
	_check(on and p.states.is_empty(), "...on, a cinder's blow sets you burning; switched off, it's gone (%s; after %s)" % [why, p.states])
	R.CLIMBER["enabled"] = true
	p.iframes = 999.0


func _pages() -> void:
	print("synergies: the book and the Library")
	await _marked({"hand": "hunter", "legs": "ashwalker"})
	var main = t.main
	var menu = main.menu
	menu.climber_tab = "marks"
	menu.open("climber", true)
	await t._frames(3)
	var shown: Array = menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("synergies"))
	_check(not shown.is_empty() and "ambusher" in shown[0].get_meta("synergies"), "the book's Marks section lists the named synergies held")
	menu.close()
	await t._frames(2)
	menu.open("library")
	await t._frames(3)
	var shelf: Array = menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("synergy_shelf"))
	var known: Array = menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("synergy") and n.get_meta("synergy") == "ambusher")
	var locked: Array = menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("synergy_locked"))
	_check(shelf.size() == 1 and known.size() == 1 and locked.size() == PA.SYNERGIES.size() - 1, "the Library lists the named synergies formed, the rest as ???")
	# Two marks with no named synergy: the book lists what each lends the other.
	await _marked({"hand": "stormcaller", "legs": "venomist", "heart": "hunter"})
	main = t.main
	menu = main.menu
	menu.climber_tab = "marks"
	menu.open("climber", true)
	await t._frames(3)
	var lent: Array = menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("lent"))
	_check(not lent.is_empty() and lent[0].get_meta("lent").size() == 6, "the book's Marks section lists the traits your marks lend each other (%d)" % (lent[0].get_meta("lent").size() if not lent.is_empty() else 0))
	var words: Array = menu.find_children("*", "Label", true, false).map(func(l): return String(l.text))
	_check(words.any(func(w): return w.contains("Stormcaller's spells take Venom from Venomist")), "...in words: whose spells take which trait from which mark")
	menu.close()
	await t._frames(2)
	var G = load("res://scripts/guide.gd")
	var En = load("res://scripts/entity.gd")
	_check(En.TIPS.has("synergies") and En.TIPS.has("reactions") and not En.TIPS.has("pacts"), "the Entity has tips for reactions and synergies")
	var said: String = String(En.TIPS["synergies"]["more"])
	_check(PA.SYNERGIES.values().all(func(d): return said.contains(String(d["name"]))), "...and its synergies tip names all twelve named synergies")
	var Talk = load("res://scripts/entity_talk.gd")
	_check("how_synergies" in Talk.DIALOGUE["how"]["choices"] and Talk.shows(main, "how_synergies") and not Talk.line_for(main, "how_synergies").contains("{"), "\"How do synergies work?\" is under \"How do things work here?\"")


func _data() -> void:
	print("states: in data, in the Data editor")
	var Reg = load("res://scripts/data_registry.gd")
	for sec in ["reactions_words", "reactions_numbers", "reactions_colours"]:
		_check(not Reg.fields_in(sec).is_empty(), "the Data editor lists %s" % sec)
	var paths: Array = Reg.fields_in("reactions_numbers").map(func(f): return f["path"])
	_check("reactions/REACTIONS/conduct/radius" in paths and "reactions/CLIMBER/enabled" in paths and "synergies/SYNERGIES/tempest/charged" in paths and "synergies/TRAITS/venomist/stacks" in paths, "...a reaction's reach, the climber switch, a named synergy's number and a lent trait's among them")
	var missing: Array = []
	for id in R.REACTIONS:
		if not t.main.audio.has_sound(String(R.REACTIONS[id]["sound"])):
			missing.append(id)
		for s in R.REACTIONS[id]["states"]:
			if not R.STATES.has(s):
				missing.append(id + ":" + s)
	_check(missing.is_empty(), "every reaction's sound is in the bank and its states exist (%s)" % [missing])
	var bad: Array = []
	for id in PA.SYNERGIES:
		for b in PA.SYNERGIES[id]["bonds"]:
			if not load("res://scripts/bonds.gd").BONDS.has(b):
				bad.append(id)
	var pairs := {}
	for id in PA.SYNERGIES:
		var pr: Array = PA.SYNERGIES[id]["bonds"].duplicate()
		pr.sort()
		pairs[str(pr)] = true
	_check(bad.is_empty() and PA.SYNERGIES.size() == 12 and pairs.size() == 12, "twelve named synergies, each of two real bonds, no pair twice")
	var all_bonds: Array = load("res://scripts/bonds.gd").BONDS.keys()
	_check(PA.TRAITS.size() == 18 and all_bonds.all(func(b): return PA.TRAITS.has(b)), "every one of the 18 marks lends a trait")
	var words := ""
	for tbl in [R.STATES, R.REACTIONS, PA.SYNERGIES, PA.TRAITS, PA.TEXT]:
		words += var_to_str(tbl).to_lower()
	var banned: Array = ["attunement", "spire", "trial", "judgment", "mana", "pact"].filter(func(w): return words.contains(w))
	_check(banned.is_empty(), "no banned words in the states, reactions and synergies (nor the old word, pact)")
