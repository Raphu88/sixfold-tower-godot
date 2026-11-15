extends RefCounted
## Particles and light from enchanted weapons and spells (particles.gd): one
## drawer under the room; bursts spawn and expire; the cap holds under a flood;
## Settings -> Effects (Low, Medium, High) scales them; an enchanted weapon
## carries a small moving light and a stream, an ordinary one doesn't, and
## putting it away takes its light away; a cast flashes and its shot carries
## light; a burning foe gives off specks; a new floor clears them; a pause
## freezes them; every mark has a look; the Entity explains it; no borrowed
## words. Run by smoke_test.gd (_part_tests).

const Particles := preload("res://scripts/particles.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Mirror := preload("res://scripts/mirror.gd")
const M := preload("res://scripts/menu.gd")

var t
var keep_level := "medium"
var keep_setting := "medium"


func run(smoke) -> void:
	t = smoke
	print("particles and light from enchanted weapons and spells")
	keep_level = Particles.level
	keep_setting = String(M.settings["effects"])
	await _fresh()
	await _bursts()
	await _levels()
	await _weapon()
	await _ranged_and_others()
	await _spells()
	await _states()
	await _floor_and_pause()
	await _perf()
	await _words()
	Particles.set_level(keep_level)
	M.settings["effects"] = keep_setting


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	Particles.set_level("medium")
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)
	for e in t.main.enemies():
		e.queue_free()
	await t._frames(3)
	t.main.player.iframes = 999.0


func _pf():
	return t.main.particles


func _arm(named: String) -> void:
	var p = t.main.player
	p.gear["melee"] = Gear.make_named(named)
	p.weapon = Gear.base_id(p.gear["melee"])


## The lights (registered) that follow this node.
func _lights_of(node) -> Array:
	return t.main.lighting.lights.values().filter(func(l): return l["node"] == node)


func _bursts() -> void:
	var main = t.main
	var pf = _pf()
	_check(pf != null and pf.get_parent() == main, "one particle drawer sits under the room")
	_check(pf.z_index > main.lighting.z_index and pf.z_index < main.player.overlay.z_index, "...drawn over the darkness, under the telegraphs and spells")
	var at: Vector2 = main.player.global_position + Vector2(40, 0)
	var made := Particles.burst(main, at, "flare")
	_check(made > 0 and pf.count() == made, "a burst spawns its particles (%d)" % made)
	_check(Particles.burst(main, at, "no_such_preset") == 0, "an unknown preset makes nothing")
	_check(Particles.burst(main, at + Vector2(9000, 0), "flare") == 0, "a burst far off screen makes nothing")
	await t._wait(1.4)
	_check(pf.count() == 0, "...and they expire (%d left)" % pf.count())
	# The cap holds under a flood.
	for i in 400:
		Particles.burst(main, at, "crit")
	_check(pf.count() <= pf.cap() and pf.count() > 0, "a flood stays under the cap (%d of %d)" % [pf.count(), pf.cap()])
	for e in 5:
		Particles.emitter(main, main.player, "ember")
	await t._frames(5)
	_check(pf.count() <= pf.cap(), "...streams too")
	pf.reset()
	# Fewer per source when the screen is busy.
	var calm := 0
	for i in 20:
		pf.reset()
		calm += Particles.burst(main, at, "kill")
	pf.reset()
	for i in pf.cap() - 20:
		Particles.burst(main, at, "crit")
	var busy := 0
	for i in 20:
		busy += Particles.burst(main, at, "kill")
	_check(busy < calm, "a busy screen makes fewer per burst (%d against %d)" % [busy, calm])
	pf.reset()
	# A spark under a telegraph: the foes' overlay is above the particles.
	_check(pf.glow.material is CanvasItemMaterial and pf.glow.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "glowing specks are drawn additively")


func _levels() -> void:
	var main = t.main
	var pf = _pf()
	var at: Vector2 = main.player.global_position + Vector2(40, 0)
	var avg := {}
	for l in ["low", "medium", "high"]:
		Particles.set_level(l)
		var total := 0
		for i in 12:
			pf.reset()
			total += Particles.burst(main, at, "kill", 5.0)
		avg[l] = float(total) / 12.0
	_check(avg["low"] < avg["medium"] and avg["medium"] < avg["high"], "Low, Medium and High scale how many (%.1f, %.1f, %.1f)" % [avg["low"], avg["medium"], avg["high"]])
	_check(avg["low"] <= 8.0, "Low makes almost none")
	Particles.set_level("low")
	pf.reset()
	_check(Particles.burst(main, at, "crit") > 0, "...but an important flash still shows on Low")
	_check(Particles.EFFECTS["low"]["cap"] < Particles.EFFECTS["medium"]["cap"] and Particles.EFFECTS["medium"]["cap"] < Particles.EFFECTS["high"]["cap"], "the cap grows with the level")
	pf.reset()
	# The setting.
	Particles.set_level("medium")
	M.settings["effects"] = "high"
	main.menu.apply_settings()
	_check(Particles.level == "high", "Settings -> Effects sets the level")
	M.settings["effects"] = "medium"
	main.menu.apply_settings()
	_check(Particles.level == "medium" and M.settings["effects"] == "medium", "...Medium is the default")
	main.menu.open("settings")
	await t._frames(2)
	var rows: Array = t._all_buttons(main.menu).filter(func(b): return b.get_meta("choice_key", "") == "effects")
	_check(rows.size() == 3, "the Effects setting shows Low, Medium and High (%d)" % rows.size())
	var help := true
	for b in rows:
		help = help and Help.key_for(b) == "setting:effects"
	_check(help and Help.HELP.has("setting:effects"), "the Entity explains the Effects buttons")
	main.menu.close()
	await t._frames(2)


func _weapon() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	var lt = main.lighting
	# The starting weapon is ordinary.
	await t._frames(3)
	_check(Gear.enchant_kind(p.weapon_rec()) == "" and pf.wield_kind(p) == "", "an ordinary weapon shows nothing")
	_check(_lights_of(p).is_empty() and pf._wield.is_empty(), "...it has no light and no stream")
	var base_lights: int = lt.lights.size()
	# The Cinder Axe is Fire.
	_arm("cinder_axe")
	await t._frames(3)
	_check(pf.wield_kind(p) == "fire", "an enchanted weapon shows its essence (fire)")
	var mine := _lights_of(p)
	_check(mine.size() == 1 and lt.lights.size() == base_lights + 1, "...and carries a small light")
	_check(mine[0]["r"] < 120.0 and mine[0]["k"] < 0.6 and mine[0]["r"] < lt.player_reach() * 0.4, "...a small one (%d px)" % int(mine[0]["r"]))
	_check(mine[0].get("noshadow", false), "...with no shadow to work out")
	_check(pf.emitters.any(func(e): return e.preset == "ember" and e.live), "...and a stream of embers")
	var before: Vector2 = mine[0]["pos"]
	p.global_position += Vector2(60, 0)
	await t._frames(3)
	_check(_lights_of(p)[0]["pos"].distance_to(before) > 30.0, "the light moves with the weapon")
	p.global_position -= Vector2(60, 0)
	await t._wait(0.7)
	var seen: int = pf.spawned
	await t._wait(1.0)
	_check(pf.spawned > seen, "embers rise from it (%d more)" % (pf.spawned - seen))
	await t._frames(2)
	# The weapon's glow draws (over the darkness).
	_check(p.weapon_segment()[0].distance_to(p.global_position) < 60.0, "the weapon's place in the room is known")
	# Another essence changes it.
	_arm("coral_trident")  # water
	await t._frames(3)
	_check(pf.wield_kind(p) == "water" and _lights_of(p).size() == 1 and pf.emitters.any(func(e): return e.preset == "drip"), "a water weapon drips; its light is its own colour")
	_check(_lights_of(p)[0]["color"] == Essence.color("water"), "...in its essence colour")
	_arm("stinger_dagger")  # stone
	await t._frames(3)
	_check(pf.wield_kind(p) == "stone" and _lights_of(p).size() == 1, "a stone weapon glows and lights too (grit comes on blows)")
	# A blow throws sparks by essence.
	_arm("wyrmspine_mace")  # iron
	await t._frames(3)
	pf.reset()
	await t._frames(2)
	var foe = main.spawn_enemy("slime", p.global_position + Vector2(30, 0))
	foe.set_physics_process(false)
	foe.max_hp = 500.0
	foe.hp = 500.0
	await t._frames(1)
	pf.reset()
	p.aim = Vector2.RIGHT
	p._strike(foe, 3.0, Vector2.RIGHT, 100.0, false, "hit")
	_check(pf.count() > 0, "a blow throws a burst (%d)" % pf.count())
	var plain: int = pf.count()
	pf.reset()
	_check(Particles.burst(main, p.global_position, "spark", 2.0) > 0, "an iron weapon's sparks")
	p._strike(foe, 3.0, Vector2.RIGHT, 100.0, true, "hit")
	foe.stun = 1.0
	pf.reset()
	p._strike(foe, 3.0, Vector2.RIGHT, 100.0, true, "hit")
	_check(pf.count() >= plain, "a critical blow bursts bigger (%d against %d)" % [pf.count(), plain])
	foe.queue_free()
	pf.reset()
	# Removing the weapon removes its light.
	p.gear["melee"] = {}
	p.weapon = "fists"
	await t._frames(3)
	_check(_lights_of(p).is_empty() and pf._wield.is_empty() and lt.lights.size() == base_lights, "putting the weapon away takes its light and stream away")
	_check(not pf.emitters.any(func(e): return e.live and e.along != null), "...every stream stops")
	# On Low: the light stays, the specks go.
	Particles.set_level("low")
	_arm("cinder_axe")
	await t._frames(3)
	var s2: int = pf.spawned
	await t._wait(1.2)
	_check(_lights_of(p).size() == 1 and pf.spawned == s2, "on Low the weapon keeps its light and makes no specks")
	Particles.set_level("medium")
	# The Entity says it once.
	_check(Entity.TIPS.has("enchanted_weapon") and String(Entity.TIPS["enchanted_weapon"]["tip"]).begins_with("Enchanted: it shows its essence"), "the Entity has a first-time line for an enchanted weapon")
	p.gear["melee"] = {}
	p.weapon = "fists"
	await t._frames(2)


func _ranged_and_others() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	var lt = main.lighting
	# An enchanted bow's arrow has a trail and a light.
	p.gear["ranged"] = Gear.make_named("stormstring")
	p.weapon = Gear.base_id(p.gear["ranged"])
	await t._frames(3)
	_check(pf.wield_kind(p) == "air", "an enchanted bow shows its essence (air)")
	var arrow = main.spawn_player_arrow(p.global_position + Vector2(20, 0), Vector2(200, 0), 5.0, 100.0, false)
	arrow.weapon = true
	arrow.life = 0.6
	await t._frames(3)
	_check(not _lights_of(arrow).is_empty() and pf.emitters.any(func(e): return is_same(e.follow, arrow)), "its arrow carries a light and a coloured trail")
	# An ordinary bow's doesn't.
	p.gear["ranged"] = Gear.make("shortbow", "common")
	p.weapon = "shortbow"
	await t._frames(3)
	var plain = main.spawn_player_arrow(p.global_position + Vector2(20, 0), Vector2(200, 0), 5.0, 100.0, false)
	plain.weapon = true
	plain.life = 0.6
	await t._frames(3)
	_check(_lights_of(plain).is_empty() and not pf.emitters.any(func(e): return is_same(e.follow, plain)), "an ordinary bow's arrow stays plain")
	arrow.queue_free()
	plain.queue_free()
	p.gear["ranged"] = {}
	p.weapon = "fists"
	await t._frames(3)
	# A mirror image of an enchanted climber, and a rival with an enchanted weapon.
	_arm("sunsteel_blade")
	await t._frames(2)
	var m = Mirror.spawn(main, p.global_position + Vector2(120, 0))
	m.set_physics_process(false)
	await t._wait(0.4)
	_check(m.w_enchant == "fire" and pf.wield_kind(m) == "fire" and _lights_of(m).size() >= 2, "the mirror image wears the same look when the climber's weapon is enchanted")
	m.queue_free()
	await t._wait(0.4)
	_check(pf._wield.keys().all(func(id): return is_instance_valid(instance_from_id(id))), "...and its light goes with it")
	var rv = main.rivals
	var rec: Dictionary = rv.new_rival(3, "kraken")
	rec["gear"] = [Gear.code(Gear.make_named("coral_trident"))]
	rec["weapon"] = "spear"
	var data: Dictionary = rv.body_data(rec)
	_check(String(data.get("enchant", "")) == "water", "a rival's enchanted weapon is noted in its body (%s)" % data.get("enchant", ""))
	rec["gear"] = [Gear.code(Gear.make("spear", "common"))]
	_check(String(rv.body_data(rec).get("enchant", "x")) == "", "...an ordinary one isn't")
	p.gear["melee"] = {}
	p.weapon = "fists"
	await t._frames(2)


func _spells() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	var lt = main.lighting
	main.grant_test_bonds()
	await t._frames(3)
	main.profile.regarded = true
	var b = p.bonds["hand"]
	b.essence = b.capacity()
	p.aim = Vector2.RIGHT
	lt.flashes.clear()
	pf.reset()
	var before: int = lt.flashes.size()
	b.cast(p)
	_check(lt.flashes.size() > before, "a cast flashes light at the caster")
	_check(pf.count() > 0, "...and throws its sparks (%d)" % pf.count())
	# A fireball's shot carries light and a trail.
	pf.reset()
	var shot = main.spawn_player_arrow(p.global_position + Vector2(20, 0), Vector2(160, 0), 5.0, 100.0, false)
	shot.style = "fireball"
	shot.tint = Color(1.0, 0.55, 0.25)
	await t._frames(3)
	_check(not _lights_of(shot).is_empty() and pf.emitters.any(func(e): return is_same(e.follow, shot) and e.live), "a spell's bolt carries light and a trail as it flies")
	shot.queue_free()
	await t._frames(3)
	_check(_lights_of(shot).is_empty() or not is_instance_valid(shot), "...and the light ends with it")
	# A field and an orb carry light while they last.
	var Fx := preload("res://scripts/spell_fx.gd")
	var count0: int = lt.lights.size()
	var orb := Fx.orb(main, p.global_position + Vector2(60, 0), Vector2(30, 0), 0.8, 14.0, Color(0.95, 0.89, 0.42), func(_o, _d): pass)
	Fx.field(main, p.global_position + Vector2(-60, 0), 50.0, 0.8, 0.2, Color(0.5, 0.8, 1.0), func(_foes): pass)
	await t._frames(3)
	_check(lt.lights.size() >= count0 + 2, "an orb and a field each carry a little light (%d more)" % (lt.lights.size() - count0))
	await t._wait(1.2)
	await t._frames(3)
	_check(lt.lights.size() <= count0, "...and it goes when they end")
	# Lightning crackles along its arc.
	pf.reset()
	main.fx_bolt([p.global_position + Vector2(40, 0), p.global_position + Vector2(200, 30)], Color(0.95, 0.89, 0.42))
	_check(pf.count() > 0, "lightning crackles along its arc (%d)" % pf.count())
	# All eighteen marks, and their headline spells, have a look.
	var ok := true
	var lone := []
	for id in Bonds.BONDS:
		var d: Dictionary = Bonds.BONDS[id]
		var kind := String(d["affinity"])
		if not Particles.ESSENCE_FX.has(kind) or not Particles.BOND_FX.has(id):
			ok = false
			lone.append(id)
		for sp in d["spells"]:
			var ty := String(sp["type"])
			if int(sp.get("learn", 1)) in [1, 5] and not Particles.SPELL_FX.has(ty):
				ok = false
				lone.append(ty)
	_check(ok and Bonds.BONDS.size() == 18, "every one of the eighteen marks has a look, and each first and Apex spell is tuned %s" % [lone])
	var every := true
	for tbl in [Particles.BOND_FX, Particles.SPELL_FX, Particles.ESSENCE_FX]:
		for k in tbl:
			for f in ["p", "trail", "cast", "hit", "also"]:
				var v: Dictionary = tbl[k]
				if v.has(f) and not Particles.PRESETS.has(String(v[f])):
					every = false
					print("  missing preset ", v[f])
	_check(every, "every preset they name exists")
	# Each spell type of every mark casts into something without trouble.
	pf.reset()
	var made := 0
	for id in Bonds.BONDS:
		for sp in Bonds.BONDS[id]["spells"]:
			var kind := String(Bonds.BONDS[id]["affinity"])
			pf.cast_fx(p.global_position + Vector2(20, 0), Vector2.RIGHT, String(id), String(sp["type"]), kind, Bonds.BONDS[id]["color"], int(sp.get("learn", 1)) >= 5)
			made += pf.count()
			pf.reset()
	_check(made > 0, "every spell makes something")
	# The Unbound's casts have a look by their lead essence.
	pf.reset()
	Particles.on_technique_cast(main, p, "unmaking", "pull", Color(0.7, 0.55, 1.0))
	_check(pf.count() > 0, "an Unbound's technique makes specks by its lead essence")
	pf.reset()


func _states() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	var foe = main.spawn_enemy("slime", p.global_position + Vector2(60, 0))
	foe.set_physics_process(false)
	foe.global_position = p.global_position + Vector2(60, 0)
	foe.max_hp = 900.0
	foe.hp = 900.0
	await t._frames(3)
	pf.reset()
	var s0: int = pf.spawned
	await t._wait(0.8)
	_check(pf.spawned == s0, "a foe with no state gives off nothing")
	Reactions.apply(main, foe, "burning", 4.0, "test")
	await t._wait(1.2)
	_check(pf.spawned > s0, "a burning foe gives off embers (%d)" % (pf.spawned - s0))
	Reactions.clear(foe, "burning")
	Reactions.apply(main, foe, "bleeding", 4.0, "test")
	var s1: int = pf.spawned
	await t._wait(1.0)
	_check(pf.spawned > s1, "a bleeding one drips")
	Reactions.clear(foe, "bleeding")
	# The climber under a state too.
	p.states["charged"] = 3.0
	var s2: int = pf.spawned
	await t._wait(1.0)
	_check(pf.spawned > s2, "the climber, charged, crackles")
	p.states.erase("charged")
	# A reaction has a burst of its own.
	pf.reset()
	var s3: int = pf.spawned
	Reactions.apply(main, foe, "soaked", 4.0, "test")
	Reactions.apply(main, foe, "burning", 4.0, "test")  # steam
	_check(pf.spawned > s3 + 5, "a reaction bursts (%d)" % (pf.spawned - s3))
	# A kill.
	pf.reset()
	foe.queue_free()


func _floor_and_pause() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	_arm("cinder_axe")
	await t._frames(3)
	Particles.burst(main, p.global_position + Vector2(30, 0), "flare")
	var em := Particles.emitter(main, p, "ember")
	await t._frames(2)
	var n: int = pf.count()
	var age0: float = pf._age[0]
	t.paused = true
	await t._wait(0.4)
	_check(pf.count() == n and is_equal_approx(pf._age[0], age0), "a pause freezes every particle")
	t.paused = false
	await t._frames(3)
	_check(pf._age[0] != age0 or pf.count() != n, "...and they go on after it")
	em.stop()
	main._start_floor(2)
	_check(pf.count() == 0 and pf.emitters.is_empty() and pf._wield.is_empty() and _lights_of(p).is_empty(), "a new floor clears every particle, stream and light")
	await t._frames(4)
	_check(pf.wield_kind(p) == "fire", "...and the weapon lights up again on the new floor")
	p.gear["melee"] = {}
	p.weapon = "fists"
	await t._frames(2)


## How much a frame costs, at each level, under a flood: the numbers are printed
## (the owner's phone: Medium is the one that matters).
func _perf() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var pf = _pf()
	_arm("cinder_axe")
	var foes := []
	for i in 6:
		var f = main.spawn_enemy("slime", p.global_position + Vector2(40 + i * 12, -50 + i * 20))
		f.set_physics_process(false)
		f.max_hp = 9999.0
		f.hp = 9999.0
		Reactions.apply(main, f, "burning", 30.0, "test")
		foes.append(f)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var cost := {}
	for l in ["low", "medium", "high"]:
		Particles.set_level(l)
		pf.reset()
		var sum := 0.0
		var peak := 0
		for i in 60:
			for k in 6:
				Particles.burst(main, p.global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60)), "crit" if k % 2 == 0 else "ember_burst")
			Particles.emitter(main, p, "ember").stop()
			await t._frames(1)
			if i >= 20:
				sum += float(pf.cost_us)
				peak = maxi(peak, pf.count())
		cost[l] = [sum / 40.0, peak]
		print("  performance: Effects %s: %.0f us a frame, %d particles at most (cap %d)" % [l, cost[l][0], peak, pf.cap()])
	_check(cost["medium"][0] < 4000.0, "at Medium the particles cost under 4 ms a frame (%.0f us)" % cost["medium"][0])
	_check(cost["low"][1] <= Particles.EFFECTS["low"]["cap"] and cost["high"][1] <= Particles.EFFECTS["high"]["cap"], "no level goes over its cap")
	for f in foes:
		f.queue_free()
	pf.reset()
	Particles.set_level("medium")
	await t._frames(3)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check(nodes1 <= nodes0 + 2, "the particles add no nodes as they come and go (%d, was %d)" % [nodes1, nodes0])
	main.player.gear["melee"] = {}
	main.player.weapon = "fists"


func _words() -> void:
	var words: Array = []
	for k in Particles.TEXT:
		words.append(String(Particles.TEXT[k]))
	words.append(String(Entity.TIPS["enchanted_weapon"]["tip"]))
	words.append(String(Entity.TIPS["enchanted_weapon"]["more"]))
	words.append(String(Talk.DIALOGUE["how_glows"]["ask"]))
	words.append(String(Talk.DIALOGUE["how_glows"]["lines"][0]))
	words.append(String(Help.HELP["setting:effects"]))
	for l in Particles.EFFECTS:
		words.append(String(Particles.EFFECTS[l]["name"]))
	var text := " ".join(words).to_lower()
	var bad := ["attunement", "spire", "trial", "judgment", "mana"].filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(text) != null)
	_check(bad.is_empty(), "no borrowed words in the effects' words %s" % [bad])
	var src := FileAccess.get_file_as_string("res://scripts/particles.gd").to_lower()
	var bad2 := ["attunement", "spire", "trial", "judgment", "mana"].filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(src) != null)
	_check(bad2.is_empty(), "...nor in the script %s" % [bad2])
	_check(Talk.shows(t.main, "how_glows") and "how_glows" in Talk.DIALOGUE["how"]["choices"], "\"What are the glows and sparks?\" is under \"How do things work here?\"")
