extends RefCounted
## The Firebird's and the Chimera's forks (scripts/spells/firebird.gd and
## chimera.gd): every new spell can be chosen at its fork, casts, does what
## it says and costs what it says; each step-3 variation changes the first
## spell; old saves keep today's spells. Run by smoke_test.gd (_part_tests).

const TOWERS := {
	"flame_contractor": "hand", "flamewing": "heart", "rekindler": "back",
	"covenant": "hand", "grafter": "legs", "surgeon": "brow",
}

var t
var TR = load("res://scripts/tree.gd")
var FX = load("res://scripts/spell_fx.gd")
var B = load("res://scripts/bonds.gd")


func run(smoke) -> void:
	t = smoke
	await _old_saves()
	await _all_forks_written()
	await _flame_contractor()
	await _flamewing()
	await _rekindler()
	await _covenant()
	await _grafter()
	await _surgeon()
	Engine.time_scale = 1.0


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber whose only mark is `bond_id` on its part, at the step `xp` gives.
func _bonded(bond_id: String, xp: float) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.add_bond(TOWERS[bond_id], bond_id, false)
	main.profile.bonds[TOWERS[bond_id]]["xp"] = xp
	main.profile.regarded = true
	main.first_climb = false
	main._give_bonds()
	main.player.iframes = 999.0
	for e in main.enemies():
		e.set_physics_process(false)


## Chooses `option` at the bond's fork at `step` (true if it could be chosen there).
func _choose(bond_id: String, step: int, option: String) -> bool:
	var main = t.main
	var node := "mark:%s:%d" % [bond_id, step]
	var offered: bool = option in TR.available(main.profile, node)
	var ok: bool = offered and TR.choose(main.profile, node, option)
	main._give_bonds()
	return ok


## The bond's mark, with `spell_id` selected and the mark full.
func _mark(bond_id: String, spell_id: String):
	var b = t.main.player.bonds[TOWERS[bond_id]]
	var i: int = b.spells().map(func(sp): return sp["id"]).find(spell_id)
	if i >= 0:
		b.select(i)
	b.essence = b.capacity()
	return b


## Casts the selected spell as the game does (pays, then casts). Returns the essence it took.
func _cast(b) -> float:
	var p = t.main.player
	var before: float = b.essence
	p.cast_part = b.part
	p.attack_cd = 0.0
	p._release_cast()
	return before - b.essence


## `n` foes with plenty of health, placed at `offsets` from the climber (the rest far away).
func _foes(offsets: Array) -> Array:
	var main = t.main
	var p = main.player
	var all: Array = main.enemies().duplicate()
	var out: Array = []
	for i in all.size():
		var e = all[i]
		if i < offsets.size():
			e.hp = 300.0
			e.max_hp = 300.0
			e.global_position = p.global_position + offsets[i]
			out.append(e)
		else:
			e.global_position = p.global_position + Vector2(-4000.0 - 60.0 * i, -4000.0)
	return out


func _old_saves() -> void:
	print("the Firebird's and Chimera's forks: old saves keep today's spells")
	for bond_id in TOWERS:
		await _bonded(bond_id, 1800.0)
		var main = t.main
		var b = main.player.bonds[TOWERS[bond_id]]
		var plain: Array = B.BONDS[bond_id]["spells"].map(func(sp): return sp["id"])
		_check(b.spells().map(func(sp): return sp["id"]) == plain, "%s at step 5 with no choices knows today's spells" % bond_id)
		var first: Dictionary = B.BONDS[bond_id]["spells"][0]
		var ch: Dictionary = first["steps"][3]
		var k: String = ch.keys()[0]
		b.select(0)
		var before = b.stat(k)
		TR.migrate(main.profile)
		main._give_bonds()
		b = main.player.bonds[TOWERS[bond_id]]
		b.select(0)
		var ids: Array = b.spells().map(func(sp): return sp["id"])
		_check(ids == plain and TR.mark_choice(main.profile, bond_id, 2) == plain[1] and TR.mark_choice(main.profile, bond_id, 3) == "change"
			and TR.mark_choice(main.profile, bond_id, 4) == plain[2] and b.stat(k) == before,
			"...an old save migrates to today's side of every fork (%s keeps %s = %s)" % [bond_id, k, str(before)])


func _all_forks_written() -> void:
	print("the Firebird's and Chimera's forks: every side written")
	var L = load("res://scripts/library.gd")
	for bond_id in TOWERS:
		for s in [2, 3, 4]:
			var alt: Dictionary = TR.fork_alt(bond_id, s)
			_check(L.built(alt) and String(alt.get("name", "")) != "" and String(alt.get("desc", "")) != "", "%s's step-%d alternative is written: %s" % [bond_id, s, alt.get("name", "?")])
			if s != 3:
				_check(int(alt.get("learn", 0)) == s and alt.has("type") and float(alt["steps"][s].get("cost", 0.0)) > 0.0, "...a spell learned at step %d with a cost" % s)
			else:
				_check(L.built(L.variation(String(alt.get("variation", "")))), "...a library variation (%s)" % alt.get("variation", "?"))
		var ch: Dictionary = L.MARK_FORKS[bond_id]["change"]
		_check(String(ch.get("name", "")) != "", "...today's step-3 change has a name (%s)" % ch.get("name", ""))
	var words := ""
	for bond_id in TOWERS:
		words += JSON.stringify(L.MARK_FORKS[bond_id]).to_lower()
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return w in words), "no banned words in the forks")


# --- the Firebird ---------------------------------------------------------------------

func _flame_contractor() -> void:
	print("the forks: Flame Contractor")
	await _bonded("flame_contractor", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("flame_contractor", 2, "blazing_trail"), "Blazing Trail can be chosen at step 2")
	var b = _mark("flame_contractor", "blazing_trail")
	_check(b.spell()["id"] == "blazing_trail" and not "fire_wall" in b.spells().map(func(sp): return sp["id"]), "...and replaces Fire Wall")
	var friendly := func(): return main.flames.filter(func(f): return f.get("friendly", false)).size()
	var paid := _cast(b)
	_check(is_equal_approx(paid, 10.0), "Blazing Trail costs 10 (%.1f)" % paid)
	var n0: int = friendly.call()
	for i in 8:
		p.global_position += Vector2(16, 0)
		await t._frames(2)
	_check(n0 >= 1 and friendly.call() >= n0 + 3, "...walking leaves burning ground behind you (%d -> %d patches)" % [n0, friendly.call()])
	# Step 3: Quickfire.
	main.profile.bonds["hand"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("flame_contractor", 3, "quickfire"), "Quickfire can be chosen at step 3")
	b = _mark("flame_contractor", "fireball")
	_check(is_equal_approx(b.windup(), 0.175) and is_equal_approx(b.cost(), 8.0) and is_equal_approx(float(b.stat("radius")), 55.0), "...Fireball winds up in half the time and costs 8, without Charged's bigger blast (%.3f s)" % b.windup())
	paid = _cast(b)
	var balls: Array = main.get_children().filter(func(c): return "explode_r" in c and c.style == "fireball")
	_check(is_equal_approx(paid, 8.0) and balls.size() == 1 and balls[0].explode_dmg < 19.0 and balls[0].explode_dmg > 14.0, "...and throws a fireball a little weaker (%.1f)" % (balls[0].explode_dmg if not balls.is_empty() else 0.0))
	# Step 4: Detonate.
	main.profile.bonds["hand"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("flame_contractor", 4, "detonate"), "Detonate can be chosen at step 4")
	main.flames.clear()
	var foes := _foes([Vector2(120, 0), Vector2(-120, 40)])
	for e in foes:
		main.add_flame(e.global_position + Vector2(8, 0), 18.0, 3.0, true)
	b = _mark("flame_contractor", "detonate")
	paid = _cast(b)
	await t._wait(0.4)
	_check(is_equal_approx(paid, 12.0), "Detonate costs 12 (%.1f)" % paid)
	_check(foes.all(func(e): return e.hp < 300.0 - 10.0), "...every patch of your burning ground bursts on the foes beside it (%s)" % [foes.map(func(e): return int(e.hp))])
	await t._frames(3)
	_check(main.flames.filter(func(f): return f.get("friendly", false) and f["t"] > 0.5).is_empty(), "...and the ground that burst is spent")
	main.flames.clear()
	var lone := _foes([Vector2(120, 0)])
	b.essence = b.capacity()
	_cast(b)
	await t._wait(0.3)
	_check(lone[0].hp < 300.0 - 14.0, "...with no burning ground, one bigger burst at your aim (%d)" % int(lone[0].hp))


func _flamewing() -> void:
	print("the forks: Flamewing")
	await _bonded("flamewing", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("flamewing", 2, "cinder_dive"), "Cinder Dive can be chosen at step 2")
	var b = _mark("flamewing", "cinder_dive")
	_check(not "wingburst" in b.spells().map(func(sp): return sp["id"]), "...and replaces Wingburst")
	var foe = _foes([Vector2(70, 0)])[0]
	var start: Vector2 = p.global_position
	p.aura_heat = 20.0
	var paid := _cast(b)
	_check(is_equal_approx(paid, 10.0), "Cinder Dive costs 10 (%.1f)" % paid)
	_check(p.global_position.x > start.x + 100.0, "...you dive along your aim (%.0f px)" % (p.global_position.x - start.x))
	_check(foe.hp <= 300.0 - 15.0 and foe.burn_t > 0.0 and p.aura_heat == 0.0, "...striking the foe you pass with the aura's heat and setting it burning (%.0f)" % foe.hp)
	p.firebird_t = 5.0
	b.essence = b.capacity()
	paid = _cast(b)
	_check(is_equal_approx(paid, 0.0), "...and it's free in Firebird Form, as Wingburst is (%.1f)" % paid)
	p.firebird_t = 0.0
	# Step 3: Broad.
	main.profile.bonds["heart"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("flamewing", 3, "broad"), "Broad can be chosen at step 3")
	b = _mark("flamewing", "heat_aura")
	_check(is_equal_approx(float(b.stat("radius")), 62.0 * 1.4) and not bool(b.stat("grows")), "...Heat Aura reaches 40%% farther and doesn't grow (%.1f)" % float(b.stat("radius")))
	_cast(b)
	_check(p.aura_part == "heart" and is_equal_approx(p.aura_r, 62.0 * 1.4) and p.aura_dmg < 3.8, "...and burns that wide, a little weaker (%.2f)" % p.aura_dmg)
	_cast(b)  # (off again)
	# Step 4: Heat Haze.
	main.profile.bonds["heart"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("flamewing", 4, "heat_haze"), "Heat Haze can be chosen at step 4")
	b = _mark("flamewing", "heat_haze")
	_check(not "warmth" in b.spells().map(func(sp): return sp["id"]), "...and replaces Warmth")
	foe = _foes([Vector2(50, 0)])[0]
	p.aura_part = ""
	paid = _cast(b)
	_check(is_equal_approx(paid, 10.0) and p.aura_part == "heart", "Heat Haze costs 10 and lights the aura (%.1f)" % paid)
	var shot = main.spawn_projectile(p.global_position + Vector2(-40, 0), Vector2.ZERO, 6.0)
	await t._frames(4)
	_check(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "...a shot that enters the aura burns away")
	_check(foe.burn_t > 0.0, "...and the foes in it are set burning")


func _rekindler() -> void:
	print("the forks: Rekindler")
	await _bonded("rekindler", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("rekindler", 2, "flashpoint"), "Flashpoint can be chosen at step 2")
	var b = _mark("rekindler", "flashpoint")
	_check(not "desperation" in b.spells().map(func(sp): return sp["id"]), "...and replaces Desperation")
	var foe = _foes([Vector2(60, 0)])[0]
	p.hp = p.max_hp
	var paid := _cast(b)
	_check(is_equal_approx(paid, 9.0), "Flashpoint costs 9 essence (%.1f)" % paid)
	_check(is_equal_approx(p.hp, p.max_hp * 0.9), "...and a tenth of your health (%.0f of %.0f)" % [p.hp, p.max_hp])
	var hit1: float = 300.0 - foe.hp
	_check(hit1 >= 10.0 and foe.burn_t > 0.0, "...bursting on the foes near you and setting them burning (%.1f)" % hit1)
	p.hp = p.max_hp * 0.3
	foe.hp = 300.0
	b.essence = b.capacity()
	_cast(b)
	_check(300.0 - foe.hp > hit1 * 1.5, "...harder the lower your health (%.1f)" % (300.0 - foe.hp))
	p.hp = 1.0
	b.essence = b.capacity()
	_cast(b)
	_check(p.hp == 1.0, "...never your last health")
	# Step 3: Deep Burn.
	main.profile.bonds["back"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("rekindler", 3, "deep_burn"), "Deep Burn can be chosen at step 3")
	b = _mark("rekindler", "rekindle")
	_check(is_equal_approx(b.windup(), 0.4) and not bool(b.stat("spread")), "...Rekindle winds up longer, and foes near you don't burn")
	p.hp = p.max_hp * 0.6
	paid = _cast(b)
	_check(is_equal_approx(paid, 8.0) and is_equal_approx(p.rekindle_loss, p.max_hp * 0.2), "...it costs 8 and burns deeper: a fifth of your health (%.1f)" % p.rekindle_loss)
	p.rekindle_fought = true
	Engine.time_scale = 5.0
	for i in 400:
		if p.rekindle_t <= 0.3:
			break
		await t._frames(1)
	var low: float = p.hp
	var lost: float = p.rekindle_lost
	await t._wait(0.25)
	for i in 300:  # (until the burn has ended and the payback landed: a busy machine runs the fight slower)
		if p.rekindle_t <= 0.0 and p.hp - low >= lost * 2.3:
			break
		await t._frames(1)
	Engine.time_scale = 1.0
	_check(lost > 0.0 and p.hp - low >= lost * 2.3, "...and pays back two and a half times what you lost (lost %.1f, back %.1f)" % [lost, p.hp - low])
	# Step 4: Backdraft.
	main.profile.bonds["back"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("rekindler", 4, "backdraft"), "Backdraft can be chosen at step 4")
	b = _mark("rekindler", "backdraft")
	_check(not "pyre_oath" in b.spells().map(func(sp): return sp["id"]), "...and replaces Pyre Oath")
	foe = _foes([Vector2(60, 0)])[0]
	p.hp = p.max_hp
	paid = _cast(b)
	_check(is_equal_approx(paid, 12.0), "Backdraft costs 12 (%.1f)" % paid)
	await t._frames(2)
	_check(foe.hp == 300.0, "...nothing happens until you're struck")
	p.hp -= 12.0
	await t._frames(3)
	_check(foe.hp < 300.0 - 10.0 and foe.burn_t > 0.0, "...a blow you take bursts into fire around you (%.0f)" % foe.hp)


# --- the Chimera ---------------------------------------------------------------------

func _covenant() -> void:
	print("the forks: Covenant")
	await _bonded("covenant", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("covenant", 2, "rally"), "Rally can be chosen at step 2")
	var b = _mark("covenant", "rally")
	_check(not "command" in b.spells().map(func(sp): return sp["id"]), "...and replaces Command")
	_foes([])
	var paid := _cast(b)
	_check(is_equal_approx(paid, 6.0) and main.allies().is_empty(), "Rally costs 6 (with no creature out it does nothing)")
	var ally = main.spawn_ally("slime", p.global_position + Vector2(-40, 0), 2, 30.0)
	ally.hp = ally.max_hp * 0.5
	var dmg0: float = ally.dmg
	var spd0: float = ally.speed
	b.essence = b.capacity()
	_cast(b)
	_check(is_equal_approx(ally.dmg, dmg0 * 1.5) and is_equal_approx(ally.speed, spd0 * 1.3) and ally.hp > ally.max_hp * 0.8 and ally.ally_t > 30.0,
		"...your creatures heal, stay longer, and hit harder and move faster (%.1f -> %.1f)" % [dmg0, ally.dmg])
	b.essence = b.capacity()
	_cast(b)
	_check(is_equal_approx(ally.dmg, dmg0 * 1.5), "...casting again doesn't stack")
	Engine.time_scale = 8.0
	await t._wait(1.2)
	Engine.time_scale = 1.0
	_check(is_instance_valid(ally) and is_equal_approx(ally.dmg, dmg0) and is_equal_approx(ally.speed, spd0), "...and it wears off after 8 seconds")
	# Step 3: Mighty (the pact book still works).
	main._start_floor(main.floor_num)
	await t._frames(2)
	for e in main.enemies():
		e.set_physics_process(false)
	main.profile.bonds["hand"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("covenant", 3, "mighty"), "Mighty can be chosen at step 3")
	b = _mark("covenant", "bind_and_call")
	_check(is_equal_approx(b.windup(), 1.2) and int(b.stat("count")) == 1, "...Call winds up longer and brings one creature")
	main.profile.pacts = ["knight"]
	_foes([])
	paid = _cast(b)
	var out: Array = main.allies()
	_check(is_equal_approx(paid, 14.0) and out.size() == 1 and out[0].kind == "knight", "...it costs 14 and calls from your retinue (%s)" % [out.map(func(a): return a.kind)])
	if out.size() == 1:
		_check(is_equal_approx(out[0].max_hp, (30.0 + 15.0 * 3) * 1.8) and is_equal_approx(out[0].dmg, (4.0 + 3.0 * 3) * 1.8), "...nearly twice as strong (%.0f health)" % out[0].max_hp)
	var weak = _foes([Vector2(60, 0)])[0]
	var kind: String = weak.kind
	main.profile.pacts = []
	weak.hp = weak.max_hp * 0.2
	b.essence = b.capacity()
	_cast(b)
	_check(kind in main.profile.pacts and weak.dead, "...and binding into the pact book works as before")
	# Step 4: Release.
	main.profile.bonds["hand"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("covenant", 4, "release"), "Release can be chosen at step 4")
	b = _mark("covenant", "release")
	_check(not "exchange" in b.spells().map(func(sp): return sp["id"]), "...and replaces Exchange")
	for a in main.allies():
		a._fade_ally()
	await t._frames(2)
	var foe = _foes([Vector2(100, 0)])[0]
	ally = main.spawn_ally("slime", foe.global_position + Vector2(-30, 0), 4, 30.0)
	ally.set_physics_process(false)
	p.hp = p.max_hp * 0.5
	var hp0: float = p.hp
	paid = _cast(b)
	_check(is_equal_approx(paid, 8.0), "Release costs 8 (%.1f)" % paid)
	_check(ally.dead and foe.hp < 300.0 - 12.0 and p.hp > hp0, "...your creature bursts, hurting the foe beside it (%.0f) and healing you (+%.0f)" % [foe.hp, p.hp - hp0])


func _grafter() -> void:
	print("the forks: Grafter")
	await _bonded("grafter", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("grafter", 2, "harvest"), "Harvest can be chosen at step 2")
	var b = _mark("grafter", "harvest")
	_check(not "mimic" in b.spells().map(func(sp): return sp["id"]), "...and replaces Mimic")
	var foe = _foes([Vector2(60, 0)])[0]
	var paid := _cast(b)
	_check(is_equal_approx(paid, 9.0) and foe.hp < 300.0 - 10.0 and not foe.dead, "Harvest costs 9 and cuts a healthy foe (%.0f)" % foe.hp)
	foe.hp = foe.max_hp * 0.2
	var kind: String = foe.kind
	main.graft_drops.clear()
	b.essence = b.capacity()
	_cast(b)
	_check(foe.dead and main.graft_drops.size() == 1 and main.graft_drops[0]["kind"] == kind, "...a weakened foe is slain and always leaves a graft (%s)" % kind)
	p.global_position = main.graft_drops[0]["pos"]
	await t._wait(0.2)
	_check(main.grafts.size() == 1, "...which binds when you walk over it, as ever")
	# Step 3: Echoing.
	main.profile.bonds["legs"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("grafter", 3, "echoing"), "Echoing can be chosen at step 3")
	b = _mark("grafter", "graft_burst")
	_check(not bool(b.stat("effects")), "...Graft Burst doesn't take Manifold's effects")
	foe = _foes([Vector2(50, 0)])[0]
	paid = _cast(b)
	var first: float = 300.0 - foe.hp
	_check(is_equal_approx(paid, 10.0) and first > 0.0, "...it costs 10 and bursts at once (%.1f)" % first)
	await t._wait(1.2)
	var second: float = 300.0 - foe.hp - first
	_check(second > 0.0 and second < first, "...then again a second later, weaker (%.1f)" % second)
	# Step 4: Bud.
	main.profile.bonds["legs"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("grafter", 4, "graft_bud"), "Bud can be chosen at step 4")
	b = _mark("grafter", "graft_bud")
	_check(not "shed" in b.spells().map(func(sp): return sp["id"]), "...and replaces Shed")
	main.grafts.clear()
	main.graft_order.clear()
	paid = _cast(b)
	_check(is_equal_approx(paid, 10.0) and main.allies().is_empty(), "Bud costs 10 (with no graft it does nothing)")
	main.add_graft("bat")
	b.essence = b.capacity()
	_cast(b)
	var buds: Array = main.allies()
	_check(buds.size() == 1 and buds[0].kind == "bat" and buds[0].ally_t <= 15.0, "...your newest graft buds into a creature of its kind for 15 seconds (%s)" % [buds.map(func(a): return a.kind)])
	b.essence = b.capacity()
	_cast(b)
	await t._frames(2)
	_check(main.allies().size() == 1, "...one at a time")
	_check(main.grafts.has("legs"), "...and the graft stays yours")


func _surgeon() -> void:
	print("the forks: Surgeon")
	await _bonded("surgeon", 150.0)
	var main = t.main
	var p = main.player
	p.aim = Vector2.RIGHT
	_check(_choose("surgeon", 2, "bloodletting"), "Bloodletting can be chosen at step 2")
	var b = _mark("surgeon", "bloodletting")
	_check(not "mend" in b.spells().map(func(sp): return sp["id"]), "...and replaces Mend")
	var foe = _foes([Vector2(60, 0)])[0]
	p.hp = p.max_hp * 0.5
	var hp0: float = p.hp
	var paid := _cast(b)
	_check(is_equal_approx(paid, 10.0) and foe.hp < 300.0, "Bloodletting costs 10 and cuts the foe you aim at (%.0f)" % foe.hp)
	var cut: float = foe.hp
	await t._wait(1.3)
	_check(foe.hp < cut - 2.0 and p.hp > hp0, "...it bleeds, and you heal for part of it (%.0f -> %.0f, +%.1f)" % [cut, foe.hp, p.hp - hp0])
	# Step 3: Chained.
	main.profile.bonds["brow"]["xp"] = 450.0
	main._give_bonds()
	_check(_choose("surgeon", 3, "chained"), "Chained can be chosen at step 3")
	b = _mark("surgeon", "sever")
	var pair := _foes([Vector2(70, 0), Vector2(160, 30)])
	for e in pair:
		e.cripple_t = 0.0
	paid = _cast(b)
	_check(is_equal_approx(paid, 8.0) and pair[0].cripple_t > 0.0 and pair[1].cripple_t > 0.0 and pair[0].disarm_t <= 0.0, "...Sever costs 8 and cripples the foe you aim at and the one near it")
	_check(300.0 - pair[1].hp < 300.0 - pair[0].hp, "...the second a little weaker")
	# Step 4: Anesthetize.
	main.profile.bonds["brow"]["xp"] = 1000.0
	main._give_bonds()
	_check(_choose("surgeon", 4, "anesthetize"), "Anesthetize can be chosen at step 4")
	b = _mark("surgeon", "anesthetize")
	_check(not "transfer" in b.spells().map(func(sp): return sp["id"]), "...and replaces Transfer")
	foe = _foes([Vector2(80, 0)])[0]
	foe.stun = 0.0
	paid = _cast(b)
	_check(is_equal_approx(paid, 10.0) and foe.stun >= 3.9, "Anesthetize costs 10 and puts the foe to sleep (%.1f s)" % foe.stun)
	await t._wait(0.25)
	var before: float = foe.hp
	foe.take_hit(20.0, Vector2.ZERO, 0.0)
	await t._frames(3)
	_check(foe.stun <= 0.0 and before - foe.hp >= 29.0, "...the blow that wakes it strikes half again as hard (%.0f)" % (before - foe.hp))
