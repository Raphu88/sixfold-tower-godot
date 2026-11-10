extends SceneTree
## Headless smoke test: loads the room and drives the climber through every
## action (combo, riposte, parry, arrow reflect, roll dodge, both casts,
## overdraw, getting hurt, dying) so script errors surface without a player.
##
## Run: godot --headless -s tests/smoke_test.gd

var main
var failures := 0
var failed: Array = []  # what failed, listed again at the end (a long log may lose its start)
const EnemyHP := {"slime": 24.0, "archer": 18.0, "knight": 48.0}


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		failed.append(what)
		print("  FAIL ", what)


## All the essence a profile holds in crystals, every kind.
func _purse(prof) -> float:
	var t := 0.0
	for c in prof.crystals:
		t += float(c["amount"])
	return t


## Sound names the code plays that the sound bank lacks (each would be a
## silent call): every sfx("name") in the scripts, and the sounds named in
## weapon, armor and monster data (with each weapon's "_heavy" finisher).
func _silent_sounds() -> Array:
	var names := {}
	var re := RegEx.new()
	re.compile("sfx\\(\"([a-z_]+)\"")
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + f)
		for m in re.search_all(text):
			names[m.get_string(1)] = true
	var W := preload("res://scripts/weapons.gd")
	for id in W.WEAPONS:
		var w: Dictionary = W.WEAPONS[id]
		for k in ["sound", "hit_sound", "equip"]:
			if w.has(k):
				names[w[k]] = true
		if w.has("sound") and not String(w["sound"]).ends_with("_heavy"):
			names[w["sound"] + "_heavy"] = true
	var G := preload("res://scripts/gear.gd")
	for id in G.ARMOR:
		if G.ARMOR[id].has("step"):
			names[G.ARMOR[id]["step"]] = true
	var E := preload("res://scripts/enemy.gd")
	for kind in E.MATERIAL:
		if E.MATERIAL[kind] != "":
			names[E.MATERIAL[kind]] = true
	var missing: Array = []
	for n in names:
		if not main.audio.has_sound(n):
			missing.append(n)
	return missing


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Kill a monster outright (a lurker is pulled up from the water first).
func _slay(e) -> void:
	e.submerged = false
	e.take_hit(99999.0, Vector2.ZERO, 0.0)


## A brand-new room with a fresh profile: a bondless first climb.
func _fresh_main() -> void:
	main.queue_free()
	await _frames(2)
	Engine.time_scale = 1.0
	paused = false  # (a page an earlier test left open must not freeze the new game)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	main.player.mouse_aim = false
	for e in main.enemies():
		e.set_physics_process(false)


func _regard_tests() -> void:
	print("the Regard")
	await _fresh_main()
	var p = main.player
	_check(main.first_climb and p.bonds.is_empty(), "the first climb starts bondless")
	# Parry a lot (the brow soaks most), gather Water essence, then fall.
	for i in 6:
		main.add_soak("brow", 5.0)
	main.add_soak("hand", 3.0)
	main.gather_essence("water", 12.0, p.global_position)
	main.gather_essence("air", 4.0, p.global_position)
	_check(main.soak_fraction("brow") > main.soak_fraction("hand"), "the most-used body part soaks the most")
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(9999.0, null)
	_check(p.dead and main.regard.is_empty(), "falling on the first climb...")
	await _wait(1.9)
	_check(not main.regard.is_empty() and main.regard["fell"], "...still brings the Regard")
	var brow: Dictionary = main.profile.bonds.get("brow", {})
	_check(not brow.is_empty(), "the most-used body part (brow) takes the mark")
	_check(brow.get("id", "") == "warden", "Water essence on the brow makes the brow's own bond, Warden: %s" % brow.get("id", ""))
	_check(brow.get("faint", false), "a mark taken in defeat is faint")
	# A faint mark owes essence before it grows.
	var lines: Array = main.profile.bank({"water": 30.0}, {})
	_check(main.profile.bonds["brow"]["faint"] and main.profile.bonds["brow"]["xp"] == 0.0, "a faint mark doesn't grow until it catches up")
	lines = main.profile.bank({"water": 40.0}, {})
	_check(not main.profile.bonds["brow"]["faint"], "enough essence and the mark is no longer faint")
	_check(main.profile.bonds["brow"]["xp"] > 0.0, "the overflow starts it growing")
	await _wait(3.2)
	_check(main.regard_done(), "the Regard can be dismissed after it plays")

	print("reaching the top")
	await _fresh_main()
	p = main.player
	for i in 5:
		main.add_soak("legs", 3.0)
	main.gather_essence("air", 30.0, p.global_position)
	_check(main.leading_part() == "legs", "the HUD's leading part is the most-used one")
	var predicted: String = main.predicted_bond()
	_check(predicted == "windwalker", "the HUD predicts the bond: %s" % predicted)
	# The essence decides the bond; play style only breaks ties between
	# bonds of the same essence. No bond has a home body part.
	var dodgy := {"legs": 10.0}
	_check(main.profile.choose_bond({"air": 6.0, "water": 4.0}, dodgy) == "windwalker", "mostly Air and lots of dodging: Windwalker")
	_check(main.profile.choose_bond({"water": 6.0, "air": 4.0}, dodgy) == "tidecaller", "mostly Water and lots of dodging: Tidecaller")
	_check(main.profile.choose_bond({"air": 10.0}, {"brow": 10.0}) == "hunter", "Air and lots of parrying: Hunter")
	_check(main.profile.choose_bond({"air": 10.0}, {"hand": 10.0}) == "stormcaller", "Air and lots of striking: Stormcaller")
	_check(main.profile.choose_bond({"iron": 10.0}, dodgy) == "rune_artist", "Iron and lots of dodging: Rune Artist (the essence wins over play style)")
	_check(main.profile.choose_bond({"iron": 10.0}, {"hand": 10.0}) == "blade_forger", "Iron and lots of striking: Blade Forger")
	_check(main.profile.choose_bond({"fire": 10.0}, {"hand": 10.0}) == "flameblade", "Fire and lots of striking: Flameblade")
	_check(main.profile.choose_bond({"fire": 10.0}, dodgy) == "ashwalker", "Fire and lots of dodging: Ashwalker")
	_check(main.profile.choose_bond({"stone": 10.0}, {"heart": 10.0, "throat": 4.0}) == "sandshaper", "Stone and lots of enduring: Sandshaper")
	main.floor_num = 3
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	_check(main.stair_open, "floor 3's stair opens")
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.regard.is_empty() and not main.regard["fell"], "taking the top stair brings the Regard")
	var legs: Dictionary = main.profile.bonds.get("legs", {})
	_check(legs.get("id", "") == "windwalker" and not legs.get("faint", true), "a full Windwalker mark on the legs")
	_check(legs.get("id", "") == predicted, "the Regard grants what the HUD predicted")

	print("a second mark")
	main.first_climb = false
	var PS = main.ProfileScript
	main.profile.soak["heart"] = PS.NEW_MARK_SOAK
	main.run_essence = {"iron": 20.0}
	main.floor_num = 4
	main._arrive()
	await _frames(2)
	_check(not main.profile.bonds.has("heart"), "a full body part waits: no new mark at an ordinary stair")
	main.floor_num = int(main.tower_data().get("summit", 12))
	main._arrive()
	await _frames(2)
	_check(main.profile.bonds.has("heart"), "at a summit the beast takes notice: the full part takes a new mark")
	_check(main.player.bonds.has("heart"), "the climber carries it")
	main.profile.soak["throat"] = PS.NEW_MARK_SOAK
	_check(main.summit_mark().is_empty() and not main.profile.bonds.has("throat"), "at most one new mark a climb")
	main.victory = {}
	main.player.set_physics_process(true)
	# A battery: the fuller a part, and the more marks you carry, the slower it fills.
	main.profile.soak = {"back": 0.0, "throat": PS.NEW_MARK_SOAK * 0.5}
	main.profile.bank({}, {"back": 100.0, "throat": 100.0})
	var empty_gain: float = main.profile.soak["back"]
	var half_gain: float = main.profile.soak["throat"] - PS.NEW_MARK_SOAK * 0.5
	_check(empty_gain > 0.0 and half_gain < empty_gain * 0.6, "a half-full part fills slower than an empty one (%.1f vs %.1f)" % [half_gain, empty_gain])
	_check(empty_gain <= 100.0 * PS.SOAK_RATE + 0.01, "a part soaks up only part of what it does")
	# The Proving's gift: one mark grows a step.
	var before_step: int = PS.step_for_xp(float(main.profile.bonds["legs"]["xp"]))
	main.climb_soak["legs"] = 999.0
	var raised: String = main.proving_raise()
	_check(raised != "" and PS.step_for_xp(float(main.profile.bonds["legs"]["xp"])) == before_step + 1, "winning the Proving raises a mark a step (%s)" % raised)


## Gives the test climber a mark at a given step.
func _mark(part: String, id: String, step: int) -> void:
	main.profile.add_bond(part, id, false)
	main.profile.bonds[part]["xp"] = main.ProfileScript.STEP_XP[step - 1]
	main.profile.regarded = true
	main.first_climb = false
	main._give_bonds()
	main.player.bonds[part].essence = 999.0


func _cast(part: String, spell_id: String) -> void:
	var b = main.player.bonds[part]
	for i in b.spells().size():
		if b.spells()[i]["id"] == spell_id:
			b.select(i)
	b.essence = 999.0
	b.cast(main.player)


func _gryphon_tests() -> void:
	print("the Gryphon's bonds")
	await _fresh_main()
	var p = main.player
	_mark("hand", "stormcaller", 1)
	_check(p.bonds["hand"].spells().size() == 1, "a step 1 Stormcaller knows one spell")
	_mark("hand", "stormcaller", 5)
	_mark("legs", "windwalker", 5)
	_mark("brow", "hunter", 5)
	_check(p.bonds["hand"].spells().size() == 4 and p.bonds["legs"].spells().size() == 4 and p.bonds["brow"].spells().size() == 4, "at step 5 each Gryphon bond knows four spells")
	_check(main.ProfileScript.Bonds.step_note("windwalker", 2) == "learns Crosswind", "growing a step names the spell learned")
	# Hold to pick: holding the key opens the ring (time stops); pointing picks.
	Input.action_press("cast_legs")
	await _wait(0.4)
	_check(p.pick_open and main.slowmo and Engine.time_scale == 0.0, "holding a mark's key opens its spell ring and stops time (%.2f)" % Engine.time_scale)
	p.pick_dir_override = Vector2(1, 0) * 60.0  # points at the second spell (of four, from the top, clockwise)
	await _wait(0.1)
	Input.action_release("cast_legs")
	await _frames(3)
	_check(p.bonds["legs"].selected == 1 and p.bonds["legs"].spell_name() == "Crosswind", "pointing right picks Crosswind: %s" % p.bonds["legs"].spell_name())
	_check(not main.slowmo and Engine.time_scale == 1.0, "letting go closes the ring, and time runs again")
	main.set_slowmo(false)
	Engine.time_scale = 1.0
	await _settle()
	# Bodies and passives.
	_check(main.lighting.player_reach() > main.lighting.PLAYER_REACH, "Keen Eyes: the Hunter sees farther")
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._try_attack()
	_check(p.attack_cd < 0.4, "Quick Nerves: strikes recover faster (%.2f)" % p.attack_cd)
	await _settle()

	# Stormcaller.
	var a = await _spawn("slime", p.global_position + Vector2(90, 0))
	var b2 = await _spawn("slime", p.global_position + Vector2(180, 20))
	a.hp = 5.0
	b2.hp = 999.0
	_cast("hand", "overcharge")
	_check(a.overcharge_t > 0.0, "Overcharge charges the foe in your aim")
	a.take_hit(99.0, Vector2.ZERO)
	_check(b2.hp < 999.0, "when it dies, lightning leaps to the foes nearby")
	b2.hp = 999.0
	_cast("hand", "thunderhead")
	_check(p.thunderhead_t > 0.0, "Thunderhead starts")
	_cast("hand", "lightning_rod")
	_check(not main.rod.is_empty(), "Lightning Rod plants a rod")
	_cast("hand", "chain_lightning")
	_check(b2.hp < 999.0, "Chain Lightning strikes (bending through the rod)")
	await _settle()
	# Windwalker.
	b2.hp = 999.0
	b2.global_position = p.global_position + Vector2(80, 0)
	p.aim = Vector2.RIGHT
	_cast("legs", "gale_lift")
	_check(b2.airborne > 0.0, "Gale Lift lifts")
	var hp_b: float = b2.hp
	_cast("legs", "downdraft")
	_check(b2.airborne <= 0.0 and b2.hp < hp_b, "Downdraft slams the airborne foe down")
	main.walls.clear()
	b2.global_position = p.global_position + Vector2(0, 200)  # out of the arrow's path
	_cast("legs", "crosswind")
	_check(main.walls.size() == 1, "Crosswind raises a wall of wind")
	var arrow = main.spawn_projectile(p.global_position + Vector2(140, 0), Vector2(-260, 0), 8.0)
	await _wait(0.5)
	_check(is_instance_valid(arrow) and arrow.reflected, "the wall turns an enemy arrow back")
	_cast("legs", "eye_of_the_storm")
	await _wait(0.3)
	_check(main.cyclones.size() == 1, "Eye of the Storm raises a cyclone")
	await _settle()
	# Hunter.
	main.cyclones.clear()
	main.walls.clear()
	var c = await _spawn("slime", p.global_position + Vector2(300, 0))
	c.hp = 999.0
	b2.global_position = p.global_position + Vector2(200, 0)
	b2.airborne = 0.0
	b2.hp = 999.0
	p.aim = Vector2.RIGHT
	_cast("brow", "piercing_shot")
	await _wait(0.6)
	_check(b2.hp < 999.0 and c.hp < 999.0, "Piercing Shot pierces a line of foes")
	_check(999.0 - b2.hp >= 30.0, "at step 3+ the charged shot deals triple damage (%d)" % int(999.0 - b2.hp))
	_check(p.quarry == b2 or p.quarry == c, "Quarry remembers the last foe struck")
	_cast("brow", "track")
	_check(main.track_t > 0.0, "Track reveals the foes")
	_cast("brow", "hawks_eye")
	var hp_c: float = c.hp
	p.ranged_hit(c, 10.0, Vector2.RIGHT, 0.0, false)
	_check(hp_c - c.hp >= 20.0, "Hawk's Eye doubles arrow damage")
	c.global_position = p.global_position + Vector2(190, 0)
	hp_c = c.hp
	_cast("brow", "rain_of_arrows")
	await _wait(1.5)
	_check(c.hp < hp_c, "Rain of Arrows hits foes in the marked area")


func _kraken_bond_tests() -> void:
	print("the Kraken's bonds")
	await _fresh_main()
	var p = main.player
	_mark("legs", "tidecaller", 5)
	_mark("brow", "warden", 5)
	_mark("heart", "deepcaller", 5)
	_check(p.bonds["legs"].spells().size() == 4 and p.bonds["brow"].spells().size() == 4 and p.bonds["heart"].spells().size() == 4, "at step 5 each Kraken bond knows four spells")
	p.aim = Vector2.RIGHT
	# Warden.
	var k = await _spawn("knight", p.global_position + Vector2(40, 0))
	k.hp = 999.0
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	_cast("brow", "barrier")
	_check(p.barrier_hp > 0.0, "Barrier raises a shell")
	p.receive_attack(14.0, k)
	_check(p.hp == p.MAX_HP, "the barrier absorbs the blow")
	var shell: float = p.barrier_hp
	_cast("brow", "absorb")
	p.receive_attack(20.0, k)
	_check(p.hp == p.MAX_HP and p.barrier_hp > shell, "Absorb stores a hit in the barrier")
	var hp_k: float = k.hp
	p.absorb_t = 0.0
	p._break_barrier()
	_check(k.hp < hp_k, "at step 3+ a breaking barrier bursts with what it absorbed")
	_cast("brow", "challenge")
	_check(k.challenged_t > 0.0, "Challenge marks nearby foes")
	hp_k = k.hp
	k.take_hit(10.0, Vector2.ZERO)
	_check(hp_k - k.hp >= 15.0, "challenged foes take more damage")
	_cast("brow", "unbreakable")
	p.hurt_t = 0.0
	p.receive_attack(50.0, k)
	_check(p.hp == p.MAX_HP and not p._try_attack() or p.hp == p.MAX_HP, "Unbreakable: no damage")
	p.unbreak_t = 0.0
	# Deepcaller.
	p.hp = 60.0
	_cast("heart", "undertow")
	_check(p.hp > 60.0 and k.hp < hp_k, "Undertow drains a foe and heals you")
	_cast("heart", "anchor")
	_check(p.anchor_target == k, "Anchor tethers the foe in your aim")
	for b in p.bonds.values():
		b.essence = 0.0
	p.bonds["heart"].select(2)
	p.bonds["heart"].essence = 99.0
	p.bonds["heart"].cast(p)
	_check(p.bonds["legs"].essence > 0.0, "Siphon refills your other marks")
	_cast("heart", "drink_deep")
	var hp_k2: float = k.hp
	await _wait(1.0)
	_check(p.drink_target == k and k.hp < hp_k2, "Drink Deep drains over time")
	p.drink_t = 0.0
	p.anchor_t = 0.0
	# Tidecaller.
	k.global_position = p.global_position + Vector2(60, 0)
	k.set_physics_process(true)
	k.stun = 0.0
	k.state = "recover"
	k.state_t = 9.0
	_cast("legs", "carry")
	await _wait(1.6)
	_check(k.stun > 0.0 or k.global_position.x > p.global_position.x + 200.0, "Carry sweeps a foe away and breaks it against a wall")
	k.global_position = p.global_position + Vector2(220, 0)
	_cast("legs", "riptide")
	await _wait(0.3)
	_check(k.global_position.distance_to(p.global_position) < 200.0, "Riptide pulls a foe in a line toward you")
	_cast("legs", "maelstrom")
	_check(main.maelstroms.size() == 1, "Maelstrom opens a whirlpool")
	main.maelstroms.clear()
	_cast("legs", "tidal_surge")
	_check(main.waves.size() >= 1, "at step 3+ Tidal Surge is an aimed, travelling wave")
	k.set_physics_process(false)
	# Bodies and water.
	main.puddles = [{"pos": p.global_position, "r": 60.0}]
	_check(main.water_slow(p.global_position, false) < 1.0 and main.water_slow(p.global_position, true) == 1.0, "water slows you, unless you're Waterborn")
	main.puddles = []


func _gryphon_tower_tests() -> void:
	print("the Gryphon's tower")
	await _fresh_main()
	var p = main.player
	main.tower = "gryphon"
	var seen := {}
	for n in 30:
		var plan: Dictionary = main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["gryphon"])
		for m in plan["monsters"]:
			seen[m[0]] = true
	_check(seen.has("bat") and seen.has("thunderling"), "the Gryphon's tower has bats and thunderlings")
	var kplan_kinds := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["kraken"])["monsters"]:
			kplan_kinds[m[0]] = true
	_check(not kplan_kinds.has("bat"), "...and other towers don't")
	# Thunderling: its ring of lightning can't be parried.
	var th = await _spawn("thunderling", p.global_position + Vector2(60, 0))
	th.hp = 999.0
	var r1: Dictionary = await _parry_test(th, 0.0, "wind_spark", 60.0)
	_check(r1["glinted"] and r1["hurt"] and not r1["parried"], "a thunderling's ring of lightning can't be parried")
	th.queue_free()
	await _frames(2)
	# Bat: its swoop glints and can be parried.
	var bat = await _spawn("bat", p.global_position + Vector2(120, 0))
	bat.hp = 999.0
	bat.state = "hover"
	var r2: Dictionary = await _parry_test(bat, 0.0, "wind", 160.0)  # from far: the glint comes earlier
	_check(r2["glinted"] and r2["parried"] and not r2["hurt"], "a bat's swoop can be parried on the glint %s" % str(r2))
	bat.queue_free()
	await _settle()

	print("the Gryphon")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "gryphon", "floor %d, the summit of the Gryphon's tower, is the Gryphon" % main.Towers.SUMMIT)
	var g = foes[0]
	g.set_physics_process(false)
	g.lift(2.0)
	_check(g.airborne <= 0.0 and g.stun > 0.0, "the Gryphon is too heavy to lift: only staggered")
	g.stun = 0.0
	g.state = "wind_rake"
	g.state_t = 0.3
	g.take_hit(5.0, Vector2.RIGHT, 200.0, true)
	_check(g.state == "wind_rake" and g.flinch <= 0.0, "hits don't interrupt the Gryphon")
	var hp_before: float = g.hp
	g.take_hit(g.hp - g.max_hp * 0.45, Vector2.ZERO)
	g.set_physics_process(true)
	g.state = "recover"
	g.state_t = 5.0
	await _wait(0.2)
	_check(main.enemies().filter(func(e): return e.kind == "bat").size() == 2, "below half health it calls two bats")
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	_check(main.stair_open, "the beast's fall opens the stair")
	p.hp = p.MAX_HP
	p.dead = false
	p.set_physics_process(true)
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "taking the summit stair completes the climb")
	await _wait(2.8)
	_check(main.overlay_done(), "the victory screen can be dismissed")
	main.victory = {}


func _kraken_tower_tests() -> void:
	print("the Kraken's tower")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var seen := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["kraken"])["monsters"]:
			seen[m[0]] = true
	_check(seen.has("lurker") and seen.has("shellback"), "the Kraken's tower has lurkers and shellbacks")
	# Lurker: can't be struck under the water, can be once it rises.
	var lk = await _spawn("lurker", p.global_position + Vector2(200, 0))
	_check(lk.submerged and not main.targets().has(lk), "a lurker under the water can't be targeted")
	var hp0: float = lk.hp
	lk.take_hit(5.0, Vector2.RIGHT)
	_check(lk.hp == hp0, "...or struck")
	lk.state = "up"
	lk.state_t = 1.0
	lk._physics_process(0.016)
	lk.take_hit(5.0, Vector2.RIGHT)
	_check(lk.hp < hp0 and main.targets().has(lk), "once it rises it can be")
	lk.queue_free()
	# Shellback: the shell blocks from the front, not from behind.
	var sb = await _spawn("shellback", p.global_position + Vector2(200, 0))
	sb.face = Vector2.LEFT
	var full: float = sb.hp
	sb.take_hit(10.0, Vector2.RIGHT)  # struck from the front (the blow travels right, into its face)
	var front: float = full - sb.hp
	sb.hp = full
	sb.take_hit(10.0, Vector2.LEFT)  # struck from behind
	var back: float = full - sb.hp
	_check(front < back * 0.5, "a shellback's shell blocks blows from the front (%.1f vs %.1f)" % [front, back])
	sb.queue_free()
	await _frames(2)

	print("the Kraken")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "kraken", "floor %d, the summit of the Kraken's tower, is the Kraken" % main.Towers.SUMMIT)
	var k = foes[0]
	k.set_physics_process(false)
	# The sweep is parryable; the slam is not.
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.parry_cd = 0.0
	p.knock = Vector2.ZERO
	p.velocity = Vector2.ZERO
	p.global_position = k.global_position + Vector2(120, 0)
	main.attackers.clear()
	main.request_attack(k)
	k._begin_wind("wind_sweep", 0.7)
	k.set_physics_process(true)
	var give_up := Time.get_ticks_msec() + 2000
	while not k.glinted and Time.get_ticks_msec() < give_up:
		await physics_frame
	var glinted: bool = k.glinted
	p._try_parry()
	var swept_stun := 0.0
	var until := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < until:
		await process_frame
		swept_stun = maxf(swept_stun, k.stun)
	k.set_physics_process(false)
	_check(glinted and swept_stun > 0.0 and p.hp == p.MAX_HP, "the Kraken's sweep can be parried on the glint")
	k.stun = 0.0
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	k.stun = 0.0
	k.slam_spots = [p.global_position]
	k._begin_wind("wind_slam", 0.2)
	k.set_physics_process(true)
	await _wait(0.12)
	p._try_parry()
	await _wait(0.3)
	k.set_physics_process(false)
	_check(p.hp < p.MAX_HP and k.stun <= 0.0, "its slam can't be parried")
	# Halfway down it calls lurkers.
	k.take_hit(k.hp - k.max_hp * 0.45, Vector2.ZERO)
	k.state = "recover"
	k.state_t = 5.0
	k.set_physics_process(true)
	await _wait(0.2)
	_check(main.enemies().filter(func(e): return e.kind == "lurker").size() == 2, "below half health it calls two lurkers")
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	_check(main.stair_open, "the Kraken's fall opens the stair")
	p.hp = p.MAX_HP
	p.dead = false
	p.set_physics_process(true)
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "taking the summit stair completes the climb")
	await _wait(2.8)
	main.victory = {}


func _body_part_tests() -> void:
	print("six body parts")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	_check(main.BondScript.Bonds.PARTS.size() == 6 and InputMap.has_action("cast_throat") and InputMap.has_action("cast_back"), "six body parts, each with a cast key")
	# The throat: one swing that catches two foes.
	p.global_position = Vector2(600, 400)
	p.aim = Vector2.RIGHT
	var a = await _spawn("slime", p.global_position + Vector2(30, -8))
	var b = await _spawn("slime", p.global_position + Vector2(30, 8))
	a.hp = 999.0
	b.hp = 999.0
	var t0: float = main.part_soak("throat")
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._melee()
	_check(main.part_soak("throat") > t0, "a swing that hits two foes soaks into the throat")
	a.queue_free()
	b.queue_free()
	# The back: a backstab hits harder and soaks into the back.
	var k = await _spawn("knight", p.global_position + Vector2(30, 0))
	k.hp = 9999.0
	k.max_hp = 9999.0
	k.face = Vector2.LEFT  # looking at you
	var hp0: float = k.hp
	p._strike(k, 10.0, Vector2.RIGHT, 0.0, false)
	var front: float = hp0 - k.hp
	var b0: float = main.part_soak("back")
	k.face = Vector2.RIGHT  # looking away
	hp0 = k.hp
	p._strike(k, 10.0, Vector2.RIGHT, 0.0, false)
	var behind: float = hp0 - k.hp
	_check(behind > front * 1.4, "a backstab hits harder (%.0f vs %.0f)" % [behind, front])
	_check(main.part_soak("back") > b0, "...and soaks into the back")
	b0 = main.part_soak("back")
	k.face = Vector2.LEFT
	k.hp = 5.0
	p._strike(k, 10.0, Vector2.RIGHT, 0.0, false)
	_check(k.dead and main.part_soak("back") > b0, "a finishing blow soaks into the back")
	# A spell that hits several foes soaks into the throat too.
	_mark("hand", "stormcaller", 1)
	for i in 3:
		var s = await _spawn("slime", p.global_position + Vector2(60 + 30 * i, 0))
		s.hp = 999.0
	t0 = main.part_soak("throat")
	p.cast_part = "hand"
	p._release_cast()
	_check(main.part_soak("throat") > t0, "a spell that hits several foes soaks into the throat")
	# Marks can sit on the new parts.
	main.dev_set_mark("throat", "warden", 2)
	main.dev_set_mark("back", "hunter", 1)
	_check(p.bonds.has("throat") and p.bonds.has("back"), "the throat and back can hold marks")


func _wyvern_bond_tests() -> void:
	print("the Wyvern's bonds")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_mark("hand", "blade_forger", 5)
	_mark("heart", "flameblade", 5)
	_mark("brow", "rune_artist", 5)
	var ok := true
	for part in ["hand", "heart", "brow"]:
		ok = ok and p.bonds[part].spells().size() == 4
	_check(ok, "at step 5 each Wyvern bond knows four spells")
	var proj := func(): return main.get_children().filter(func(c): return "return_to" in c and c.friendly)

	# Blade Forger.
	p._equip("sword")
	var reach: float = p.wdata()["combo"][0]["range"]
	var far = await _spawn("slime", p.global_position + Vector2(reach * 1.15 + 13.0, 0))
	far.hp = 999.0
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._melee()
	_check(far.hp < 999.0, "Long Edge: strikes reach farther")
	far.queue_free()
	await _frames(1)
	p._equip("fists")
	var before: int = proj.call().size()
	_cast("hand", "conjured_blades")
	_check(proj.call().size() - before == 7, "Weapon Memory: with fists, Conjured Blades throws more, smaller blades (%d)" % (proj.call().size() - before))
	p._equip("sword")
	for c in proj.call():
		c.queue_free()
	await _frames(1)
	_cast("hand", "recall")
	var thrown: Array = proj.call()
	await _wait(0.6)
	_check(thrown.size() == 3 and thrown.any(func(c): return is_instance_valid(c) and c.returning), "Recall: the blades turn back toward you")
	for c in proj.call():
		c.queue_free()
	var near = await _spawn("slime", p.global_position + Vector2(40, 0))
	near.hp = 999.0
	_cast("hand", "bladeward")
	await _wait(0.5)
	_check(p.bladeward_t > 0.0 and near.hp < 999.0, "Bladeward: orbiting blades cut a foe that comes close")
	near.queue_free()
	p.bladeward_t = 0.0
	await _frames(1)
	before = proj.call().size()
	_cast("hand", "thousand_edges")
	_check(proj.call().size() - before >= 14, "Thousand Edges: a storm of blades")
	for c in proj.call():
		c.queue_free()

	# Flameblade.
	var chain: Array = p.wdata()["combo"]
	p.combo = chain.size() - 1
	p.combo_t = 1.0
	p.attack_cd = 0.0
	p._melee()
	_check(is_equal_approx(p.attack_cd, chain[0]["recover"] * 1.0), "Hot Blood: even the finisher recovers fast")
	var dummy = await _spawn("knight", p.global_position + Vector2(30, 0))
	dummy.hp = 9999.0
	dummy.max_hp = 9999.0
	p.heat = 0.0
	for i in 4:
		p.attack_cd = 0.0
		p._melee()
	_check(p.heat >= 40.0, "Heat builds with each strike in a row (%d)" % int(p.heat))
	var hp0: float = dummy.hp
	p.heat = 0.0
	p.combo = 0
	p.combo_t = 0.0
	p.attack_cd = 0.0
	p._melee()
	var cold: float = hp0 - dummy.hp
	hp0 = dummy.hp
	p.heat = 100.0
	p.combo = 0
	p.combo_t = 0.0
	p.attack_cd = 0.0
	p._melee()
	var hot: float = hp0 - dummy.hp
	_check(hot > cold * 1.3, "...and a hot weapon hits harder (%.0f vs %.0f)" % [hot, cold])
	_cast("heart", "kindle_blade")
	_check(p.kindle_t > 0.0, "Kindle Blade sets the weapon burning")
	p.kindle_t = 0.5
	p.attack_cd = 0.0
	p._melee()
	_check(p.kindle_t >= 2.0, "...and at step 3+ landing strikes keeps it burning")
	var waves0: int = main.waves.size()
	_cast("heart", "flame_lash")
	_check(main.waves.size() == waves0 + 1, "Flame Lash throws a wave of fire")
	main.waves.clear()
	_cast("heart", "searing_parry")
	hp0 = dummy.hp
	p.parry_t = 0.3
	p.aim = Vector2.RIGHT
	p.receive_attack(10.0, dummy)
	_check(dummy.hp < hp0, "Searing Parry: a parry while kindled explodes against the attacker")
	p.heat = 100.0
	hp0 = dummy.hp
	_cast("heart", "overheat")
	_check(hp0 - dummy.hp >= 50.0 and p.heat == 0.0, "Overheat releases all the heat in one blow (%.0f)" % (hp0 - dummy.hp))
	dummy.queue_free()
	p.kindle_t = 0.0
	await _frames(1)

	# Rune Artist.
	var b = p.bonds["hand"]
	b.select(0)
	p.cast_part = ""
	p._try_cast("hand")
	_check(p.cast_total < b.windup(), "Steady Mind: every spell winds up faster")
	p.cast_t = 0.0
	_cast("brow", "rune_trap")
	p.aim = Vector2.UP
	_cast("brow", "rune_trap")
	_check(main.runes.size() == 2, "Rune Trap lays runes")
	var walker = await _spawn("slime", p.global_position + Vector2(0, 200))
	walker.hp = 999.0
	walker.global_position = main.runes[0]["pos"]
	main._update_runes(0.016)
	_check(walker.hp < 999.0 and main.runes.is_empty(), "a foe on a rune sets it off, and Linked Runes sets off the rest")
	walker.queue_free()
	p.aim = Vector2.RIGHT
	_cast("brow", "inscribe")
	_check(p.rune_gear == "sharpness", "Inscribe writes Sharpness on your gear")
	_cast("brow", "inscribe")
	_check(p.rune_gear == "warding", "...and casting again changes it to Warding")
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(20.0, null)
	_check(is_equal_approx(p.MAX_HP - p.hp, 15.0), "Warding: you take less damage")
	p.rune_gear = ""
	var intruder = await _spawn("slime", p.global_position + Vector2(20, 0))
	_cast("brow", "ward_circle")
	main._update_runes(0.016)
	_check(intruder.global_position.distance_to(p.global_position) >= 75.0, "Ward Circle: foes can't stand inside it")
	intruder.queue_free()
	main.wards.clear()
	_cast("brow", "grand_sigil")
	var hb = p.bonds["hand"]
	hb.select(0)
	hb.essence = 0.0
	hb.burned = false
	p.cast_part = "hand"
	p._release_cast()
	_check(not hb.burned, "Grand Sigil: spells cast inside it cost nothing")
	main.sigils.clear()


func _manticore_bond_tests() -> void:
	print("the Manticore's bonds")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_mark("heart", "sandshaper", 5)
	_mark("hand", "venomist", 5)
	_mark("back", "ashwalker", 5)
	var ok := true
	for part in ["heart", "hand", "back"]:
		ok = ok and p.bonds[part].spells().size() == 4
	_check(ok, "at step 5 each Manticore bond knows four spells")

	# Sandshaper.
	var k = await _spawn("knight", p.global_position + Vector2(40, 0))
	k.hp = 9999.0
	k.max_hp = 9999.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.knock = Vector2.ZERO
	p.receive_attack(5.0, k)
	_check(p.knock == Vector2.ZERO, "Rooted Stance: you aren't knocked back")
	main.puddles = [{"pos": p.global_position, "r": 60.0}]
	_check(main.water_slow(p.global_position, p.has_bond("tidecaller") or p.has_bond("sandshaper")) == 1.0, "...or slowed by water")
	main.puddles = []
	var hp0: float = k.hp
	_cast("heart", "quake")
	_check(k.hp < hp0 and main.rubble.size() == 1 and main.stone_walls.size() >= 8, "Quake hurts nearby foes, leaves rubble, and at step 3+ throws up a ring of walls")
	_check(main.rubble_slow(p.global_position) < 1.0, "rubble slows foes")
	main._start_floor(main.floor_num)
	await _frames(2)
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_cast("heart", "sand_wall")
	_check(main.stone_walls.size() >= 6, "Sand Wall raises a wall")
	var arrow = main.spawn_projectile(p.global_position + Vector2(140, 0), Vector2(-300, 0), 8.0)
	p.hp = p.MAX_HP
	await _wait(0.5)
	_check(not is_instance_valid(arrow) and p.hp == p.MAX_HP, "...that stops a monster's shot")
	var small = await _spawn("slime", p.global_position + Vector2(150, 0))
	_cast("heart", "sinkhole")
	await _frames(2)
	_check(not is_instance_valid(small) or small.dead, "Sinkhole swallows a small foe")
	var big = await _spawn("knight", p.global_position + Vector2(150, 0))
	big.hp = 9999.0
	_cast("heart", "sinkhole")
	_check(big.stun > 0.0, "...and traps a large one")
	big.queue_free()
	var before: int = main.stone_walls.size()
	_cast("heart", "fault_line")
	_check(main.stone_walls.size() > before + 10, "Fault Line splits the floor")
	main._start_floor(main.floor_num)
	await _frames(2)
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT

	# Venomist.
	var v = await _spawn("knight", p.global_position + Vector2(30, 0))
	v.hp = 9999.0
	v.max_hp = 9999.0
	p._strike(v, 1.0, Vector2.RIGHT, 0.0, false)
	_check(v.venom >= 1, "Venom Glands: weapon strikes poison")
	var t1: float = v.venom_t
	v.add_venom(2)
	_check(v.venom >= 3 and v.venom_t > t1, "Toxin Build: poison stacks, and lasts longer with each stack")
	hp0 = v.hp
	v.set_physics_process(true)
	await _wait(1.1)
	v.set_physics_process(false)
	_check(v.hp < hp0, "poison hurts over time")
	v.venom = 0
	var line: Array = []
	for i in 2:
		var s = await _spawn("knight", p.global_position + Vector2(90 + 40 * i, 0))
		s.hp = 9999.0
		line.append(s)
	_cast("hand", "venom_spit")
	await _wait(0.4)
	_check(line[0].venom >= 5 and line[1].venom >= 5, "Venom Spit poisons, and at step 3+ pierces through")
	_cast("hand", "toxic_cloud")
	_check(main.clouds.size() == 1, "Toxic Cloud lingers")
	main.clouds.clear()
	_cast("hand", "neurotoxin")
	p._strike(line[0], 1.0, Vector2.RIGHT, 0.0, false)
	_check(line[0].stun >= 1.5, "Neurotoxin: the next hit on a poisoned foe paralyzes it")
	hp0 = line[1].hp
	var left: float = line[1].venom_left()
	_cast("hand", "virulence")
	_check(line[1].venom == 0 and hp0 - line[1].hp >= left * 0.99, "Virulence: all the poison at once (%.0f)" % (hp0 - line[1].hp))
	for s in line:
		s.queue_free()
	v.queue_free()
	await _frames(2)

	# Ashwalker.
	var a = await _spawn("knight", p.global_position + Vector2(30, 0))
	a.hp = 9999.0
	a.max_hp = 9999.0
	a.notice_t = 0.0
	a.face = Vector2.LEFT
	hp0 = a.hp
	p._strike(a, 10.0, Vector2.RIGHT, 0.0, false)
	var seen_dmg: float = hp0 - a.hp
	a.notice_t = 1.0
	hp0 = a.hp
	p._strike(a, 10.0, Vector2.RIGHT, 0.0, false)
	_check(hp0 - a.hp > seen_dmg * 2.5, "Unseen Strike: a foe that hasn't noticed you takes triple damage")
	_check(a.notice_t <= 0.0, "...and notices you")
	_cast("back", "smoke_veil")
	main._update_ground(0.016)
	_check(a.is_lost(30.0), "Smoke Veil: foes inside lose track of you")
	hp0 = a.hp
	_cast("back", "smoke_veil")
	_check(a.hp < hp0 and main.smokes.is_empty(), "...and at step 3+ casting again ignites it")
	a.lost_t = 0.0
	p.global_position = Vector2(700, 400)
	_cast("back", "afterimage")
	p.global_position = Vector2(500, 400)
	main._update_ground(0.016)
	_check(a.is_lost(200.0) and a.lure != null, "Afterimage: nearby foes go after the ash copy")
	main.decoys.clear()
	a.lost_t = 0.0
	a.lure = null
	_cast("back", "vanish")
	_check(a.is_lost(30.0), "Vanish: every foe loses you")
	p._strike(a, 1.0, Vector2.RIGHT, 0.0, false)
	_check(p.vanish_t <= 0.0, "...until you strike")
	a.lost_t = 0.0
	_cast("back", "ashfall")
	_check(a.is_lost(300.0) and not a.is_lost(60.0), "Ashfall: foes lose you once you're out of reach")
	main.ashfall_t = 0.0
	var g = await _spawn("gryphon", p.global_position + Vector2(200, 0))
	g.lose_track(5.0, null)
	_check(not g.is_lost(200.0), "beasts never lose track of you")
	g.queue_free()
	a.queue_free()


func _rooms_tests() -> void:
	print("rooms and corridors")
	await _fresh_main()
	var p = main.player
	main.profile.regarded = true
	main.first_climb = false
	var ok_reach := true
	var ok_monsters := true
	var ok_rooms := true
	for n in 8:
		main._start_floor(2 + n % 3)
		await _frames(1)
		ok_rooms = ok_rooms and main.layout_on and main.layout_rooms.size() >= 6
		main.open_all_doors()
		var path: PackedVector2Array = main.astar.get_point_path(main._tile_of(main.player_start), main._tile_of(main.stair_pos))
		ok_reach = ok_reach and path.size() > 1 and not main.is_solid(main.player_start) and not main.is_solid(main.stair_pos)
		for e in main.enemies():
			ok_monsters = ok_monsters and not main.is_solid(e.global_position)
	_check(ok_rooms, "floors above the first are 6 or more rooms joined by corridors")
	_check(ok_reach, "the stair can always be reached from the start (doors open)")
	_check(ok_monsters, "monsters stand in rooms, never inside walls")
	# (One that sees you can rouse its neighbours, so check the farthest: it still waits.)
	var far_foe = null
	for e in main.enemies():
		if far_foe == null or e.global_position.distance_to(p.global_position) > far_foe.global_position.distance_to(p.global_position):
			far_foe = e
	_check(far_foe == null or not far_foe.aware or far_foe.global_position.distance_to(p.global_position) < 460.0, "monsters wait in their rooms until they see you")
	await _plan_tests()
	# Walls block sight and shots.
	var a: Vector2 = main.layout_rooms[0].get_center()
	var far: Vector2 = main.layout_rooms[-1].get_center()
	var blocked := false
	for x in main.grid_size.x:
		for y in main.grid_size.y:
			if main._is_solid_tile(x, y) and main._near_walkable(x, y):
				blocked = true
	_check(blocked and main.is_solid(main.room.position + Vector2(5, 5)) == main._is_solid_tile(0, 0), "the area between rooms is solid")
	# (a tile deep inside a wall, so the shot can't slip out before it's stopped)
	var wall_at := Vector2.ZERO
	for x in main.grid_size.x:
		for y in main.grid_size.y:
			if wall_at == Vector2.ZERO and main._is_solid_tile(x, y) and not main._near_walkable(x, y):
				wall_at = main.room.position + Vector2(x * 40 + 20, y * 40 + 20)
	var shot = main.spawn_projectile(wall_at, Vector2(10, 0), 5.0)
	for i in 3:
		await physics_frame  # (shots move on the physics tick)
	await _frames(1)
	_check(not is_instance_valid(shot), "walls stop shots")
	var dir: Vector2 = main.path_dir(a, far)
	_check(dir.length() > 0.9, "monsters can find a way around walls")
	# Floor 1 and the beast's floor stay single open rooms.
	main._start_floor(1)
	await _frames(1)
	_check(not main.layout_on and main.room == main.OPEN_ROOM, "floor 1 is a single open room")
	main.dev_beast("gryphon")
	await _frames(1)
	_check(not main.layout_on, "...and so is the beast's floor")


## The floor plan (floors.gd): a spine of rooms with jobs, branches off it,
## kept cells, corridors that meet rooms at their walls, a grid that grows
## with height, room themes (themes.gd) and doors (doors.gd).
func _plan_tests() -> void:
	print("floor plans, themes and doors")
	var F = main.Floors
	var T = main.Themes
	var ok_count := true
	var ok_spine := true
	var ok_branch := true
	var ok_kept := true
	var ok_edges := true
	var ok_corr := true
	var ok_theme_fixed := true
	var ok_first_good := true
	var ok_den := true
	var ok_no_repeat := true
	var ok_cap := true
	var ok_door_rule := true
	var ok_chasm := true
	var doors_total := 0
	var kinds := {}
	var sizes := {}
	for n in 36:
		var fl: int = [2, 3, 5, 7, 10, 11][n % 6]
		var tid: String = main.Towers.ORDER[n % 6]
		var plan: Dictionary = F.rooms_floor(fl, main.Towers.TOWERS[tid])
		var infos: Array = plan["room_info"]
		ok_count = ok_count and infos.size() >= 6 and infos.size() <= 12
		var roles := {}
		for ri in infos:
			roles[ri["role"]] = roles.get(ri["role"], 0) + 1
		ok_spine = ok_spine and roles.get("entrance", 0) == 1 and roles.get("stair", 0) == 1 and roles.get("gallery", 0) == 1 and roles.get("guard", 0) >= 1
		ok_spine = ok_spine and infos[0]["role"] == "entrance"
		ok_branch = ok_branch and roles.get("branch", 0) >= 2
		if fl >= 2:
			ok_kept = ok_kept and plan["wings"].size() + roles.get("branch", 0) >= 2
		sizes[fl] = maxf(float(sizes.get(fl, 0.0)), plan["arena"].size.x * plan["arena"].size.y)
		# The puzzle lives in the gallery.
		var gal: Dictionary = infos.filter(func(ri): return ri["role"] == "gallery")[0]
		ok_theme_fixed = ok_theme_fixed and not plan["puzzle"].is_empty() and gal["rect"] == plan["puzzle"]["room"]
		# Corridors run between rooms, never through one, and meet them only at their walls.
		for c in plan["corridors"]:
			ok_corr = ok_corr and (c.size.x == 80.0 or c.size.y == 80.0)
			for ri in infos:
				var inner: Rect2 = ri["rect"].grow(-1.0)
				ok_edges = ok_edges and not inner.intersects(c)
		# Themes by the rules.
		var bad := 0
		var seen := {}
		var free_i := 0
		for i in infos.size():
			var ri: Dictionary = infos[i]
			var th: String = ri["theme"]
			match String(ri["role"]):
				"entrance":
					ok_theme_fixed = ok_theme_fixed and th == "arrival"
				"stair":
					ok_theme_fixed = ok_theme_fixed and th == "landing"
				"gallery":
					ok_theme_fixed = ok_theme_fixed and th == "puzzle_" + plan["puzzle"]["type"]
			var kind: String = T.get_theme(th)["kind"]
			kinds[kind] = true
			if kind == "bad":
				bad += 1
				ok_no_repeat = ok_no_repeat and not seen.has(th)
				seen[th] = true
			var towers: Array = T.get_theme(th)["towers"]
			ok_no_repeat = ok_no_repeat and (towers.is_empty() or tid in towers)
		ok_cap = ok_cap and bad <= (2 if fl <= 1 else (3 if fl <= 3 else 4)) + (1 if plan["chasms"].size() > 0 else 0)
		ok_den = ok_den and "den" in plan["themes"]
		ok_first_good = ok_first_good and plan["themes"].any(func(t): return T.get_theme(t)["kind"] == "good")
		# Doors: never into the start room, each in a doorway two tiles wide.
		for d in plan["doors"]:
			doors_total += 1
			ok_door_rule = ok_door_rule and d["room"] != 0 and d["tiles"].size() == 2
		if tid == "firebird":
			ok_chasm = ok_chasm and plan["chasms"].size() > 0
	_check(ok_count, "a floor of rooms has 6 to 12 rooms")
	_check(ok_spine, "a spine of rooms with jobs: the entrance, guard rooms, the gallery and the stair hall")
	_check(ok_branch and ok_kept, "branch rooms hang off the spine, and cells are kept for sealed wings")
	_check(sizes[11] > sizes[3] and F.arena_for(11).size.x > F.arena_for(3).size.x, "floors grow with height (%d vs %d px²)" % [sizes[11], sizes[3]])
	_check(ok_corr and ok_edges, "corridors are two tiles wide and meet rooms at their walls, never cutting through them")
	_check(ok_theme_fixed, "the start is the Arrival Hall, the stair room the Landing, and the gallery holds the floor's puzzle")
	_check(ok_den and ok_first_good, "every floor has a good room and a den")
	_check(ok_no_repeat and ok_cap, "no bad theme twice a floor, bad rooms capped, other towers' themes kept out")
	_check(kinds.has("good") and kinds.has("bad") and kinds.has("mixed"), "good, bad and mixed rooms all turn up")
	_check(ok_door_rule and doors_total > 36, "doors fill doorways, never into the start room (%d over 36 floors)" % doors_total)
	_check(ok_chasm, "the Firebird's floors always have a chasm to jump")
	# Doors in the game: solid, blocking sight and the way, until you walk up.
	var p = main.player
	var door := {}
	for n in 20:
		main._start_floor(3 + n % 4)
		await _frames(1)
		if main.door_view.list.any(func(d): return d["lock"] == ""):
			door = main.door_view.list.filter(func(d): return d["lock"] == "")[0]  # (not a locked one: see _lock_tests)
			break
	for e in main.enemies():
		e.set_physics_process(false)
		e.aware = false
	_check(not door.is_empty(), "floors of rooms have doors")
	var t0: Vector2i = door["tiles"][0]
	var dc: Vector2 = door["rect"].get_center()
	var out: Vector2 = door["out"]
	var before: Vector2 = dc + out * 80.0  # in the corridor, outside the room
	var inside: Vector2 = dc - out * 80.0  # just inside the room
	_check(main.is_solid(dc) and main.astar.is_point_solid(t0), "a closed door is a solid tile, on the path grid too")
	_check(not main.clear_line(before, inside), "a closed door blocks sight")
	p.global_position = before
	await _frames(3)
	var vis_i: int = main._tile_of(inside).y * main.grid_size.x + main._tile_of(inside).x
	_check(main.fog.vis[vis_i] == 0, "...so the room behind it stays dark")
	# Walk into it: it stops you, then swings open.
	p.global_position = dc + out * 72.0
	p.velocity = Vector2.ZERO
	await _frames(2)
	var key := "move_up" if out == Vector2.DOWN else ("move_down" if out == Vector2.UP else ("move_left" if out == Vector2.RIGHT else "move_right"))
	_check(not door["open"], "doors stay shut until someone comes close")
	Input.action_press(key)
	await _wait(0.4)
	Input.action_release(key)
	await _frames(2)
	_check(door["open"] and not main.is_solid(dc) and not main.astar.is_point_solid(t0), "walking up to a door opens it")
	p.global_position = before
	await _frames(3)
	_check(main.fog.vis[vis_i] == 1, "opening a door reveals the room behind it")
	_check(main.door_view.closed_count() < main.door_view.list.size(), "(and it stays open)")
	# A door's look hints at the room (never the reward).
	var styles := {}
	var ok_style := true
	for n in 30:
		main.tower = main.Towers.ORDER[n % 6]
		main._start_floor(3 + n % 8)
		await _frames(1)
		for d in main.door_view.list:
			styles[d["style"]] = true
			ok_style = ok_style and (d["fixed"] != "" or d["style"] == T.get_theme(main.room_themes[d["room"]])["door"])  # (a wing's door is always sealed)
	main.tower = "kraken"
	_check(ok_style and styles.size() >= 5, "doors come in styles that hint at the room behind (%s)" % [styles.keys()])
	# Awake monsters open doors too.
	for n in 20:
		main._start_floor(4)
		await _frames(1)
		if main.door_view.list.any(func(d): return d["lock"] == ""):
			break
	# (A door no one has opened yet; every other monster asleep and still, so
	# only the test's own monster can open it.)
	var unlocked: Array = main.door_view.list.filter(func(d): return d["lock"] == "" and not d["open"])
	door = unlocked[0] if not unlocked.is_empty() else main.door_view.list.filter(func(d): return d["lock"] == "")[0]
	for e in main.enemies():
		e.set_physics_process(false)
		e.aware = false
	p.global_position = main.player_start
	main.traps = []  # (no trap may catch the test's monster on its way)
	main.door_view.monster_t = 99.0  # (a new monster starts awake: hold the check a moment)
	var foe = await _spawn("slime", door["rect"].get_center() + door["out"] * 50.0)
	foe.max_hp = 9999.0
	foe.hp = 9999.0
	foe.set_physics_process(false)
	foe.aware = false
	main.door_view.monster_t = 0.0
	await _wait(0.3)
	var shut: bool = not door["open"]
	foe.aware = true
	for i in 20:  # (doors look for monsters a few times a second)
		if door["open"]:
			break
		await _wait(0.1)
	_check(shut and door["open"], "a sleeping monster leaves a door shut; an awake one opens it (shut while asleep: %s, open once awake: %s, monster still there: %s)" % [shut, door["open"], is_instance_valid(foe)])
	if is_instance_valid(foe) and not foe.is_queued_for_deletion():
		foe.queue_free()
	# Entering a themed room shows its name and rule, once.
	for e in main.enemies():
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	await _frames(2)
	var ti := -1
	for i in main.room_info.size():
		if main.room_themes[i] in ["den", "landing"] or T.get_theme(main.room_themes[i])["kind"] == "good":
			ti = i
			break
	main.banner = {}
	p.global_position = main.player_start
	await _frames(2)
	var name: String = String(T.get_theme(main.room_themes[ti])["name"]).to_upper()
	p.global_position = main.room_info[ti]["rect"].get_center() + Vector2(0, 30)
	await _frames(2)
	_check(main.banner.get("title", "") == name and main.banner["lines"][0] == T.get_theme(main.room_themes[ti])["sub"], "walking into a themed room shows its name and rule (%s)" % name)
	main.banner = {}
	p.global_position = main.player_start
	await _frames(2)
	p.global_position = main.room_info[ti]["rect"].get_center() + Vector2(0, 30)
	await _frames(2)
	_check(main.banner.is_empty(), "...only the first time")
	# Themed floors: tints drawn into the room's floor squares.
	_check(main.room_view.looks.size() == main.room_info.size(), "each room's theme is drawn on its floor")
	# A healing spring heals until it runs dry.
	var sp := {}
	for n in 40:
		main._start_floor(2 + n % 6)
		await _frames(1)
		if not main.springs.is_empty():
			sp = main.springs[0]
			break
	for e in main.enemies():
		e.queue_free()
	_check(not sp.is_empty(), "some floors have a healing spring")
	if not sp.is_empty():
		p.hp = 20.0
		p.global_position = sp["pos"]
		await _wait(0.5)
		_check(p.hp > 25.0 and sp["left"] < F.SPRING["heal"], "standing in a healing spring heals you (%d)" % int(p.hp))
		p.hp = 1.0
		await _wait(F.SPRING["heal"] / F.SPRING["rate"] + 1.0)
		var dry: float = p.hp
		p.hp = 1.0
		await _wait(0.4)
		_check(sp["left"] <= 0.0 and p.hp == 1.0 and dry > 30.0, "...until it runs dry")
		p.hp = p.max_health()
	# A restless crypt's dead rise when you walk in.
	var ci := -1
	for n in 40:
		main._start_floor(4 + n % 6)
		await _frames(1)
		ci = main.room_themes.find("crypt")
		if ci >= 0:
			break
	if ci >= 0:
		for e in main.enemies():
			e.queue_free()
		await _frames(1)
		var total: int = main.floor_total
		p.global_position = main.room_info[ci]["rect"].get_center()
		await _frames(2)
		_check(main.enemies().size() >= 1 and main.floor_total >= total + 1 and main.enemies().all(func(e): return e.aware), "walking into a crypt raises its dead (%d)" % main.enemies().size())


## Cover walls, cache rooms with essence caches, and door frames.
func _terrain_tests() -> void:
	print("terrain inside rooms")
	await _fresh_main()
	var p = main.player
	main.profile.regarded = true
	main.first_climb = false
	var blocks := 0
	var blocks_solid := true
	var reach := true
	var doors := 0
	var doors_solid := true
	var sides := 0
	var floors := 0
	var block: Rect2
	for n in 30:
		main._start_floor(2 + n % 3)
		await _frames(1)
		floors += 1
		for b in main.layout_blocks:
			blocks += 1
			block = b
			for t in main._tiles_in(b):
				blocks_solid = blocks_solid and main._is_solid_tile(t.x, t.y)
		main.open_all_doors()
		var from: Vector2i = main._tile_of(main.player_start)
		var goals: Array = [main.stair_pos]
		for e in main.enemies():
			goals.append(e.global_position)
		if not main.cache.is_empty():
			goals.append(main.cache["pos"])
		for g in goals:
			reach = reach and not main.astar.get_id_path(from, main._tile_of(g)).is_empty()
		doors += main.room_view.doors.size()
		for d in main.room_view.doors:
			doors_solid = doors_solid and main.is_solid(d.get_center())
		if main.side_room.has_area():
			sides += 1
			if n >= 20:  # stop on a floor with a cache once enough are counted
				break
	_check(blocks > 0 and blocks_solid, "low cover walls stand inside rooms and are solid tiles (%d)" % blocks)
	_check(reach, "the stair, every monster and every cache stay reachable from the start")
	_check(doors > 0 and doors_solid, "door frames stand on the walls beside corridor openings")
	_check(sides > 0 and sides < floors, "cache rooms appear on some floors but not all (%d of %d)" % [sides, floors])
	# Cover blocks sight and shots.
	for n in 20:
		if not main.layout_blocks.is_empty():
			break
		main._start_floor(3)
		await _frames(1)
	for e in main.enemies():
		e.set_physics_process(false)
	block = main.layout_blocks[0]
	var across := Vector2(0, 70) if block.size.x > block.size.y else Vector2(70, 0)
	var c := block.get_center()
	_check(not main.clear_line(c - across, c + across), "cover blocks line of sight")
	var shot = main.spawn_projectile(c - across, across.normalized() * 400.0, 5.0)
	await _wait(0.5)
	_check(not is_instance_valid(shot), "cover stops shots")
	if not main.side_room.has_area():
		for n in 30:
			main._start_floor(3)
			await _frames(1)
			if main.side_room.has_area():
				break
	for e in main.enemies():
		e.set_physics_process(false)
	_check(not main.cache.is_empty() and main.side_room.has_point(main.cache["pos"]), "a cache room holds an essence cache")
	var kind: String = main.cache["kind"]
	var before := float(main.run_essence.get(kind, 0.0))
	p.global_position = main.cache["pos"] + Vector2(0, 70)
	await _frames(2)
	_check(not main.cache["taken"], "the cache stays shut until you walk onto it")
	p.global_position = main.cache["pos"]
	await _frames(2)
	var got := float(main.run_essence.get(kind, 0.0)) - before
	_check(main.cache["taken"] and is_equal_approx(got, main.cache["amount"]) and got > 0.0, "walking onto the cache gives a burst of the tower's essence (+%d)" % int(got))
	await _frames(2)
	_check(is_equal_approx(float(main.run_essence.get(kind, 0.0)) - before, got), "...only once")
	_check(main.Floors.cache_amount(4) > main.Floors.cache_amount(2), "caches hold more essence on higher floors")
	# Floor 1 stays a plain open room.
	main._start_floor(1)
	await _frames(1)
	_check(main.layout_blocks.is_empty() and main.cache.is_empty() and main.room_view.doors.is_empty() and main.door_view.list.is_empty(), "floor 1 has no cover, cache room or doors")


func _trap_tests() -> void:
	print("traps")
	await _fresh_main()
	var p = main.player
	var Traps = main.Traps
	main.profile.regarded = true
	main.first_climb = false
	# Each trap theme builds its own pattern out of a room that fits it.
	await _trap_theme_tests()
	# Floors of rooms: traps laid on purpose, and fairly.
	var ok_spot := true
	var ok_clear := true
	var ok_good := true
	var ok_route := true
	var ok_rooms := true
	var ok_beat := true
	var ok_patch := true
	var ok_count := true
	var ok_foes := true
	var ok_pits := true
	var ok_ring := true
	var rings := 0
	var plates := 0
	var total := 0
	var themes_seen := {}
	var floors_with_room := 0
	var blocked := 0
	var guarded := 0
	for n in 24:
		main.tower = main.Towers.ORDER[n % 6]
		main._start_floor([2, 3, 4, 6, 8, 11][(n / 6 + n) % 6])
		for e in main.enemies():
			e.set_physics_process(false)
		var plan: Dictionary = main.floor_plan
		var list: Array = main.traps
		total += list.size()
		ok_count = ok_count and list.size() >= 2
		var haz := {}
		for tr in list:
			for t in Traps.cover(tr):
				haz[t] = true
			var pos: Vector2 = tr["pos"]
			ok_spot = ok_spot and not main.is_solid(pos) and not main.in_chasm(pos)
			if Traps.KINDS[tr["kind"]]["shape"] == "lane":
				for i in int(tr["len"]):
					ok_spot = ok_spot and not main.is_solid(pos + tr["dir"] * main.Floors.CELL * i)
			if tr.get("guard", false):
				rings += 1
				var off: Vector2i = Traps.tile_of(pos) - Traps.tile_of(main.cache["pos"])
				ok_ring = ok_ring and maxi(absi(off.x), absi(off.y)) == 2
			elif tr["trigger"] == "plate" and not tr.has("room"):
				plates += 1
			if not tr.get("guard", false):
				for r in plan.get("safe_rooms", []):
					ok_good = ok_good and not r.has_point(pos)
		ok_patch = ok_patch and list.filter(func(t): return t.get("patch", false)).size() <= 12
		# Nothing reaches the start, the stair, a door or the puzzle room.
		for t in haz:
			var c: Vector2 = Traps.centre(t)
			var why := ""
			for d in main.door_view.list:
				if d["rect"].has_point(c):
					why = "a door"
			if not plan.get("puzzle", {}).is_empty() and plan["puzzle"]["room"].has_point(c):
				why = "the puzzle room"
			if c.distance_to(main.player_start) <= 80.0:
				why = "the start"
			if c.distance_to(main.stair_pos) <= 60.0:
				why = "the stair"
			if why != "":
				ok_clear = false
				var tr_at: Array = list.filter(func(x): return t in Traps.cover(x))
				print("    a trap reaches %s: %s floor %d, %s" % [why, main.tower, main.floor_num, str(tr_at.map(func(x): return [x["kind"], x.get("room", -1), x.get("patch", false), x.get("trigger", "")]))])
		# A route with no trap on it from the start to the stair and the puzzle room.
		var goals: Array = [[main.stair_pos]]
		if not plan.get("puzzle", {}).is_empty():
			var pr: Rect2 = plan["puzzle"]["room"]
			var pts: Array = []
			for y in int(pr.size.y / main.Floors.CELL):
				for x in int(pr.size.x / main.Floors.CELL):
					pts.append(pr.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * main.Floors.CELL)
			goals.append(pts)
		# Traps may block the way, but never for good: a route exists over
		# tiles that each have a safe moment (time it, roll or jump).
		ok_route = ok_route and _trap_free_route(Traps.hard_tiles(list), goals)
		blocked += 0 if _trap_free_route(haz, goals) else 1
		# From floor 4, monsters wait among the traps.
		if main.floor_num >= 4:
			for i in main.room_themes.size():
				if Traps.THEME_KINDS.has(main.room_themes[i]):
					var rr: Rect2 = main.room_info[i]["rect"]
					guarded += 1 if plan["monsters"].any(func(m): return rr.has_point(m[1])) else 0
		# Each trap room holds its own pattern, on one shared beat.
		var has_room := false
		for i in main.room_themes.size():
			var theme: String = main.room_themes[i]
			if not Traps.THEME_KINDS.has(theme):
				continue
			has_room = true
			themes_seen[theme] = true
			var group: Array = list.filter(func(t): return int(t.get("room", -1)) == i)
			ok_rooms = ok_rooms and not group.is_empty()
			var cycles := {}
			for tr in group:
				ok_rooms = ok_rooms and tr["kind"] in Traps.THEME_KINDS[theme]
				if tr["trigger"] == "timed":
					cycles[snappedf(Traps.val(tr, "cycle"), 0.001)] = true
			ok_beat = ok_beat and cycles.size() <= 1
		floors_with_room += 1 if has_room else 0
		# No monster waits on a trap tile; nothing that matters sits in a chasm.
		for m in plan["monsters"]:
			ok_foes = ok_foes and not haz.has(Traps.tile_of(m[1]))
		ok_pits = ok_pits and not main.in_chasm(main.player_start) and not main.in_chasm(main.stair_pos)
		if not main.cache.is_empty():
			ok_pits = ok_pits and not main.in_chasm(main.cache["pos"])
		for sp in main.springs:
			ok_pits = ok_pits and not main.in_chasm(sp["pos"])
	_check(ok_count and total >= 100, "every floor of rooms gets traps (%d over 24 floors)" % total)
	_check(floors_with_room >= 20 and themes_seen.size() >= 6, "nearly every floor has a trap room (%d of 24), in many themes (%s)" % [floors_with_room, themes_seen.keys()])
	_check(ok_rooms and ok_beat, "each trap room holds its own theme's pattern, all on one shared beat")
	_check(ok_spot, "traps never sit on a wall or a chasm, and lanes never run into a wall")
	_check(ok_clear, "nothing reaches the start, the stair, a door or the puzzle room")
	_check(ok_good, "good rooms stay clear (but for the spikes guarding a cache)")
	_check(ok_ring and rings > 0, "spikes ring the cache's urn two tiles out (%d)" % rings)
	_check(ok_route, "the stair and the puzzle room can always be reached by timing it: no tile on the way is never safe")
	_check(blocked > 0, "but traps may block the way: on %d of 24 floors the stair can't be reached without crossing one" % blocked)
	_check(guarded > 0, "monsters wait among the traps from floor 4 (%d rooms)" % guarded)
	_check(ok_patch, "at most two spike patches in the corridors a floor")
	_check(plates > 0, "loose plates still turn up (%d)" % plates)
	_check(ok_foes, "no monster waits on a trap")
	_check(ok_pits, "nothing that matters sits in a chasm")
	# Higher floors: a quicker beat.
	_check(Traps.pace(11) < Traps.pace(2) and Traps.difficulty(11) == 1.0, "the beat quickens with height")
	main.tower = "kraken"
	main._start_floor(1)
	await _frames(1)
	_check(main.traps.is_empty(), "floor 1 has no traps")
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	# Every kind warns before it hurts, hurts whoever stands in it, and can be avoided.
	var spot: Vector2 = main.room.get_center() + Vector2(0, 80)
	for kind in Traps.KINDS:
		var k: Dictionary = Traps.KINDS[kind]
		var tr: Dictionary = Traps.make(spot, kind, false, 2)
		main.traps = [tr]
		main.flames.clear()
		main.trap_view.reset()
		p.global_position = spot
		p.velocity = Vector2.ZERO
		p.knock = Vector2.ZERO
		p.hp = p.max_health()
		p.hurt_t = 0.0
		p.iframes = 0.0
		var hp0: float = p.hp
		if k["trigger"] == "timed":
			tr["timer"] = 0.05
		await _wait(0.12)
		_check(tr["state"] == "warn" and p.hp == hp0, "%s: warns first (%s) and hasn't hurt yet" % [kind, k["trigger"]])
		await _wait(float(k["warn"]) + 0.12)
		_check(p.hp < hp0, "%s: standing in it when it fires hurts (%d)" % [kind, int(hp0 - p.hp)])
		if kind in ["gust", "sluice"]:
			_check(p.global_position.distance_to(spot) > 10.0 or p.knock.length() > 0.0, "%s: shoves you off it" % kind)
		if kind == "sluice":
			_check(p.trap_slow < 1.0, "sluice: the water slows you")
		if kind == "thorns":
			_check(p.trap_slow == 0.0, "thorns: the snare holds you")
			p.roll_t = 0.1
			await physics_frame
			await physics_frame
			_check(p.trap_slow == 1.0, "thorns: a roll breaks free")
		if kind == "ember":
			_check(not main.flames.is_empty(), "ember: leaves the floor burning")
		# Step away before it fires: safe.
		p.global_position = spot + Vector2(130, 0)  # (out of a lingering gas cloud)
		await _wait(float(k.get("rest", 0.0)) + 0.6)
		tr["state"] = "warn"
		tr["timer"] = 0.15
		tr["hit"] = []
		main.flames.clear()
		p.global_position = spot + Vector2(130, 0)
		p.hurt_t = 0.0
		p.hp = p.max_health()
		hp0 = p.hp
		await _wait(float(k["fire"]) + 0.3)
		_check(p.hp == hp0, "%s: stepping away avoids it" % kind)
		# Rolling through it when it fires: safe.
		tr["state"] = "warn"
		tr["timer"] = 0.05
		tr["hit"] = []
		p.global_position = spot
		p.hurt_t = 0.0
		p.dodge_cd = 0.0
		p.iframes = 2.0
		await _wait(0.2)
		_check(p.hp == hp0 and tr["state"] == "fire", "%s: rolling through it avoids it" % kind)
		p.iframes = 0.0
		await _wait(float(k["fire"]) + 0.1)
		# Jumping: over plates and the ember burst, but not into a jet of fire or water.
		tr["state"] = "warn"
		tr["timer"] = 0.05
		tr["hit"] = []
		main.flames.clear()
		p.global_position = spot
		p.knock = Vector2.ZERO
		p.hurt_t = 0.0
		p.hp = p.max_health()
		hp0 = p.hp
		p.jump_vel = Vector2.ZERO
		p.jump_total = 3.0
		p.jump_t = 3.0
		await _wait(0.2)
		if "jump" in k["avoid"]:
			_check(p.hp == hp0, "%s: jumping over it avoids it" % kind)
		else:
			_check(p.hp < hp0, "%s: jumping doesn't help" % kind)
		p.jump_t = 0.0
		main.trap_view.reset()
		await _wait(float(k["fire"]) + 0.1)
	# Traps hurt badly: at least a sixth of your health for most kinds.
	_check(Traps.make(spot, "flame", false, 2)["dmg"] >= 24.0 and Traps.make(spot, "spikes", false, 2)["dmg"] >= 24.0, "traps hurt badly (they're telegraphed, so a hit is your fault)")
	# Every trap glints just before it fires.
	var gl: Dictionary = Traps.make(spot, "flame", false, 2)
	gl["dir"] = Vector2.RIGHT
	main.traps = [gl]
	p.global_position = spot + Vector2(0, 200)
	gl["timer"] = 0.02
	await _wait(float(Traps.KINDS["flame"]["warn"]) - Traps.GLINT_LEAD + 0.08)
	_check(gl["state"] == "warn" and gl["glint"], "a trap glints a moment before it fires")
	# A lane reaches along its tiles, not around its nozzle.
	gl["len"] = 3
	_check(main.trap_view.touches(gl, spot + Vector2(80, 0), 10.0) and not main.trap_view.touches(gl, spot + Vector2(-60, 0), 10.0), "a flame jet burns the whole lane it points along, and nothing behind it")
	# Dodging a trap feeds the legs only once per trap.
	var farm: Dictionary = Traps.make(spot, "flame", false, 2)
	main.traps = [farm]
	p.global_position = spot
	p.iframes = 5.0
	p.dodge_cd = 0.0
	var legs0: float = main.run_soak.get("legs", 0.0)
	for i in 2:
		farm["state"] = "warn"
		farm["timer"] = 0.02
		farm["hit"] = []
		p.dodge_cd = 0.0
		await _wait(0.12)
	var legs1: float = main.run_soak.get("legs", 0.0)
	_check(farm["dodged"] and legs1 - legs0 <= 4.5, "rolling through a trap counts as a dodge once per trap, so it can't be farmed (%.1f)" % (legs1 - legs0))
	p.iframes = 0.0
	await _wait(1.2)
	# Gas: keeps hurting while you stay in the cloud; hidden, but it hisses and glows when set off.
	var gas: Dictionary = Traps.make(spot, "gas", true, 2)
	main.traps = [gas]
	p.global_position = spot
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	await _wait(0.1)
	_check(gas["state"] == "warn" and main.trap_view.visibility(gas) == 1.0, "a hidden gas vent shows itself the moment it's set off")
	await _wait(0.6)
	var g1: float = p.hp
	await _wait(1.1)
	_check(p.hp < g1 - 8.0, "staying in a gas cloud keeps hurting (%d)" % int(g1 - p.hp))
	p.global_position = spot + Vector2(200, 0)
	var g2: float = p.hp
	await _wait(0.8)
	_check(p.hp == g2, "...and getting out of it stops the harm")
	main.traps = []
	await _wait(0.2)
	# A snare's rustle wakes sleeping monsters nearby.
	var sleeper = await _spawn("slime", spot + Vector2(150, 0))
	sleeper.set_physics_process(false)
	sleeper.aware = false
	var sn2: Dictionary = Traps.make(spot, "thorns", false, 2)
	main.traps = [sn2]
	p.global_position = spot
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.hp = p.max_health()
	await _wait(float(Traps.KINDS["thorns"]["warn"]) + 0.2)
	_check(sleeper.aware, "a bramble snare's rustle wakes the pack nearby")
	sleeper.queue_free()
	main.traps = []
	main.trap_view.reset()
	await _wait(1.6)
	# A plate isn't set off from the air.
	var plate: Dictionary = Traps.make(spot, "spikes", false, 2)
	main.traps = [plate]
	p.global_position = spot
	p.jump_total = 1.0
	p.jump_t = 1.0
	for i in 4:
		await physics_frame
	_check(plate["state"] == "idle", "jumping over a spike plate doesn't set it off")
	p.jump_t = 0.0
	p.global_position = spot + Vector2(200, 0)
	# Monsters that wander onto a plate set it off and get caught.
	var sl = await _spawn("slime", spot)
	var shp: float = sl.hp
	for i in 3:
		await physics_frame
	_check(plate["state"] == "warn", "a monster stepping on a spike plate sets it off")
	await _wait(0.6)
	_check(not is_instance_valid(sl) or sl.hp < shp, "...and the spikes catch it")
	if is_instance_valid(sl):
		sl.queue_free()
	var snare: Dictionary = Traps.make(spot, "thorns", false, 2)
	main.traps = [snare]
	var th = await _spawn("knight", spot)
	await _wait(0.8)
	_check(th.stun > 0.0, "a thorn snare holds a monster too")
	th.queue_free()
	# Hidden traps are faint; the Hunter's Keen Eyes sees them.
	var hidden: Dictionary = Traps.make(spot, "spikes", true, 2)
	main.traps = [hidden]
	p.global_position = spot + Vector2(200, 0)
	await _frames(1)
	_check(main.trap_view.visibility(hidden) < 0.5 and not main.trap_view.seen(hidden), "hidden traps are hard to see (%s, %.2f)" % [hidden["state"], main.trap_view.visibility(hidden)])
	_check(main.trap_view.visibility(Traps.make(spot, "spikes", false, 2)) == 1.0, "...other traps are plain to see")
	_mark("brow", "hunter", 1)
	_check(main.trap_view.seen(hidden), "Keen Eyes (the Hunter's Body) spots hidden traps")
	_check("trap" in main.BondScript.Bonds.BONDS["hunter"]["body"]["desc"], "...and its description says so")
	main.traps = []
	main.trap_view.reset()
	# Darts: the slot's eye glows red 0.4 s before it fires, then the dart flies.
	var dart: Dictionary = Traps.make(spot, "dart", false, 2)
	dart["dir"] = Vector2.RIGHT
	dart["len"] = 5
	Traps.fit(dart)
	dart["timer"] = 0.05
	main.traps = [dart]
	p.global_position = spot + Vector2(80, 0)
	p.velocity = Vector2.ZERO
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	var dhp: float = p.hp
	await _wait(0.15)
	var tell: float = main.trap_view.tell(dart)
	var faint: bool = tell > 0.0 and tell < 0.5 and main.trap_view.glow_list().is_empty()
	_check(dart["state"] == "warn" and p.hp == dhp and faint and is_equal_approx(float(Traps.KINDS["dart"]["warn"]), 0.4), "a dart slot gives only a faint tell 0.4 s before it fires (its eye dimly reddening, no flash); nothing hurts yet")
	await _wait(0.17)
	var eye: bool = main.trap_view.glow_list().any(func(l): return l[0].distance_to(Traps.slot_of(dart)) < 2.0)
	_check(dart["state"] == "warn" and eye, "...and its eye catches the light just before the shot")
	await _wait(0.33)
	_check(p.hp < dhp, "...then its dart flies down the lane and hurts (%d)" % int(dhp - p.hp))
	# A dart only hurts where it is: once it has passed, the lane is safe.
	dart["state"] = "warn"
	dart["timer"] = 0.02
	dart["hit"] = []
	p.global_position = spot + Vector2(40, 0)
	await _wait(0.25)
	var mid: Vector2 = Traps.front_of(dart)
	_check(dart["state"] == "fire" and not main.trap_view.touches(dart, spot, 10.0) and main.trap_view.touches(dart, mid, 10.0), "a dart hurts only where it is in its flight, not all along its lane")
	main.traps = []
	await _wait(0.4)
	# Subtle tells: a warning spike row gives no light and only a faint tell;
	# a hidden plate gives less time than a visible one.
	var quiet: Dictionary = Traps.make(spot + Vector2(0, 200), "spikes", false, 2)
	quiet["state"] = "warn"
	quiet["timer"] = 0.4
	main.traps = [quiet]
	_check(main.trap_view.glow_list().is_empty() and main.trap_view.tell(quiet) < 0.5 and not Traps.KINDS["spikes"].get("glint", true), "spikes warn with only a click and the tips peeking: no glow, no glint")
	_check(Traps.val(Traps.make(spot, "spikes", true, 2), "warn") < Traps.val(Traps.make(spot, "spikes", false, 2), "warn"), "a hidden plate gives you less time to react")
	main.traps = []
	# The Furnace: its two halves take turns, so one side is always safe.
	var furnace: Array = _built_theme("furnace")
	var fg: Array = furnace[2]
	main.traps = fg
	p.global_position = Vector2(-9000, -9000)
	var both := false
	var fired := [false, false]
	var side_a: Vector2 = fg[0]["dir"] if not fg.is_empty() else Vector2.ZERO
	var cycle: float = Traps.val(fg[0], "cycle") if not fg.is_empty() else 1.0
	for step in int(cycle * 2.5 / 0.02):
		var fire_a := false
		var fire_b := false
		for tr in fg:
			main.trap_view._tick_trap(tr, 0.02)
			if tr["state"] == "fire":
				if tr["dir"] == side_a:
					fire_a = true
				else:
					fire_b = true
		both = both or (fire_a and fire_b)
		fired[0] = fired[0] or fire_a
		fired[1] = fired[1] or fire_b
	main.traps = []
	_check(not fg.is_empty() and not both and fired[0] and fired[1], "the Furnace's two halves fire in turns, never together: one side is always safe")
	_check(String(main.Themes.THEMES["furnace"]["sub"]).to_lower().contains("one side is always safe"), "...and its rule says so")
	await _wait(0.2)
	# Gas kills a climber who lingers in it.
	var cloud: Dictionary = Traps.make(spot, "miasma", false, 2)
	cloud["timer"] = 0.02
	main.traps = [cloud]
	p.global_position = spot
	p.velocity = Vector2.ZERO
	p.hp = 30.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	await _until(func(): return p.dead or p.hp <= 0.0, float(Traps.KINDS["miasma"]["warn"]) + float(Traps.KINDS["miasma"]["fire"]) + 2.0)
	_check(p.dead or p.hp <= 0.0, "a gas cloud kills a climber who lingers in it")
	main.traps = []
	await _fresh_main()


## A set piece of trap theme `theme` built in a room that fits it, on floor
## `fl`: [the floor's grid (traps.gd), the room, the traps] ([] traps if no
## room fit in many tries).
func _built_theme(theme: String, fl := 6) -> Array:
	var Traps = main.Traps
	var F = main.Floors
	var T = main.Themes
	var th: Dictionary = T.THEMES[theme]
	var tid: String = th["towers"][0] if not th["towers"].is_empty() else "wyvern"
	var tower: Dictionary = main.Towers.TOWERS[tid]
	for attempt in 40:
		var plan: Dictionary = F.rooms_floor(fl, tower)
		for i in plan["room_info"].size():
			var ri: Dictionary = plan["room_info"][i]
			if not (ri["role"] in ["guard", "branch"]) or T.get_theme(ri["theme"])["kind"] == "good":
				continue
			if not T.fits(theme, {"size": Vector2i(ri["rect"].size / F.CELL), "rows": ri["rows"]}, tid, tower):
				continue
			var ctx: Dictionary = Traps.context(plan)
			var got: Array = Traps.build_theme(ctx, i, theme, fl)
			if not got.is_empty():
				return [ctx, Traps._room(ctx, i), got]
	return [{}, {}, []]


## Each trap theme's set piece makes sense for the theme and its room.
func _trap_theme_tests() -> void:
	var Traps = main.Traps
	var T = main.Themes
	for theme in Traps.THEME_KINDS:
		var res: Array = _built_theme(theme)
		var ctx: Dictionary = res[0]
		var R: Dictionary = res[1]
		var g: Array = res[2]
		var ok: bool = not g.is_empty()
		var what := ""
		var timers := {}
		var dirs := {}
		for tr in g:
			ok = ok and tr["kind"] in Traps.THEME_KINDS[theme]
			if tr["trigger"] == "timed":
				timers[snappedf(fposmod(float(tr["timer"]), Traps.val(tr, "cycle")), 0.01)] = true
			if Traps.KINDS[tr["kind"]]["shape"] == "lane":
				dirs[Vector2i(tr["dir"].round())] = true
		var cycle: float = Traps.val(g[0], "cycle") if ok else 1.0
		var along := func(tr: Dictionary) -> int:
			var l: Vector2i = Traps.tile_of(tr["pos"]) - R["t0"]
			return l.x if R["horiz"] else l.y
		var path := {}
		if ok:
			for pth in ctx["paths"]:
				path[Traps.tile_of(pth[1].get_center())] = true
		match theme:
			"spikes":
				# Each row lies across the short side and has its own beat.
				var rows := {}
				for tr in g:
					var key := snappedf(float(tr["timer"]), 0.01)
					if not rows.has(key):
						rows[key] = {}
					rows[key][along.call(tr)] = true
				for key in rows:
					ok = ok and rows[key].size() == 1
				ok = ok and rows.size() >= 2
				what = "rows across the short side, each a beat behind the last (%d rows)" % rows.size()
			"darts":
				# Slots in the two facing long walls, half a cycle apart, a wall behind each.
				ok = ok and dirs.size() == 2 and dirs.has(R["B"]) and dirs.has(-R["B"])
				var offs: Array = timers.keys()
				ok = ok and offs.size() == 2 and is_equal_approx(snappedf(absf(offs[0] - offs[1]), 0.01), snappedf(cycle * 0.5, 0.01))
				for tr in g:
					var k: Vector2i = Traps.tile_of(Traps.slot_of(tr))
					ok = ok and ctx["solid"][k.y * ctx["gs"].x + k.x] == 1
				what = "slots in both long walls, firing across, the two walls half a cycle apart (%d slots)" % g.size()
			"furnace":
				# Vents at both ends firing toward the middle, half a cycle apart; a middle line never burns.
				ok = ok and dirs.size() == 2 and dirs.has(R["A"]) and dirs.has(-R["A"])
				var offs: Array = timers.keys()
				ok = ok and offs.size() == 2 and Traps.val(g[0], "fire") <= cycle * 0.5
				var burned := {}
				for tr in g:
					for t in Traps.cover(tr):
						var l: Vector2i = t - R["t0"]
						burned[l.x if R["horiz"] else l.y] = true
				var safe_line := false
				for a in range(1, R["L"] - 1):
					safe_line = safe_line or not burned.has(a)
				ok = ok and safe_line
				what = "vents at both ends take turns; a line across the middle never burns (%d vents)" % g.size()
			"windhall":
				# Gusts all blow one way, toward a line of spikes along the wall.
				var gusts: Array = g.filter(func(t): return t["kind"] == "gust")
				var spikes := {}
				for tr in g:
					if tr["kind"] == "spikes":
						spikes[Traps.tile_of(tr["pos"])] = true
				var gdirs := {}
				var onto := 0
				for tr in gusts:
					gdirs[Vector2i(tr["dir"].round())] = true
					if spikes.has(Traps.tile_of(Traps.lane_end(tr) + tr["dir"] * main.Floors.CELL)):
						onto += 1
				ok = ok and gusts.size() >= 2 and gdirs.size() == 1 and spikes.size() >= 3 and onto * 2 >= gusts.size()
				what = "gusts blow one way, onto a wall of spikes (%d gusts, %d onto spikes)" % [gusts.size(), onto]
			"sluice":
				# Sweeps along the hall, all from one end, the rows half a cycle apart.
				var offs: Array = timers.keys()
				ok = ok and dirs.size() == 1 and (dirs.has(R["A"]) or dirs.has(-R["A"])) and offs.size() == 2
				what = "water sweeps along the hall from one end, rows taking turns (%d rows)" % g.size()
			"emberfall":
				ok = ok and g.size() >= 3 and timers.size() >= 2 and g.all(func(t): return t.has("burn_t"))
				what = "marks land in waves and leave the floor burning (%d marks, %d beats)" % [g.size(), timers.size()]
			"bramble":
				ok = ok and path.size() >= 3 and g.size() >= 6
				for tr in g:
					ok = ok and not path.has(Traps.tile_of(tr["pos"]))
				what = "snares fill the brambles; a winding path stays clear (%d snares, path %d)" % [g.size(), path.size()]
			"miasma":
				ok = ok and path.size() >= 3 and g.size() >= 2 and timers.size() >= 2
				for tr in g:
					for t in Traps.cover(tr):
						ok = ok and not path.has(t)
				what = "vents breathe in turn; their clouds never reach the clean path (%d vents)" % g.size()
		_check(ok, "%s: %s" % [T.THEMES[theme]["name"], what])
	# Every trap room says what it is: a rule, and a hazard door with its sigil.
	var ok_text := true
	for theme in Traps.THEME_KINDS:
		var t: Dictionary = T.THEMES[theme]
		ok_text = ok_text and String(t["sub"]).length() > 20 and t["door"] == "hazard" and main.door_view.SIGIL_COLORS.has(t.get("sigil", ""))
	_check(ok_text, "every trap room has a rule and a hazard door bearing its sigil")


## Whether a route from the start reaches each group of `goals` (any point
## of a group) without stepping on a tile in `haz`. Walls and pillars block,
## closed doors open; chasms are jumped.
func _trap_free_route(haz: Dictionary, goals: Array) -> bool:
	var Traps = main.Traps
	var gs: Vector2i = main.grid_size
	var doors := {}
	for d in main.door_view.list:
		for t in d["tiles"]:
			doors[t] = true
	var pillar := {}
	for pl in main.pillars:
		pillar[Traps.tile_of(pl["pos"])] = true
	var start: Vector2i = Traps.tile_of(main.player_start)
	var seen := {start: true}
	var q: Array = [start]
	var i := 0
	while i < q.size():
		var t: Vector2i = q[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var u: Vector2i = t + d
			if seen.has(u) or u.x < 0 or u.y < 0 or u.x >= gs.x or u.y >= gs.y:
				continue
			if haz.has(u) or pillar.has(u):
				continue
			if main.is_solid(Traps.centre(u)) and not doors.has(u):
				continue
			seen[u] = true
			q.append(u)
	for group in goals:
		var any := false
		for pos in group:
			any = any or seen.has(Traps.tile_of(pos))
		if not any:
			return false
	return true


func _room_fog_tests() -> void:
	print("hand-made rooms and fog")
	var Rooms = load("res://scripts/rooms.gd")
	var F = main.Floors
	var ok_shape := true
	var ok_fit := true
	var ok_stair := true
	for r in Rooms.ROOMS:
		var g: Array = r["grid"]
		var w: int = String(g[0]).length()
		for row in g:
			ok_shape = ok_shape and String(row).length() == w
			for ch in String(row):
				ok_shape = ok_shape and ch in Rooms.CHARS
		var sz: Vector2i = Rooms.size_of(r)
		ok_fit = ok_fit and sz.x <= Rooms.MAX_SIZE.x and sz.y <= Rooms.MAX_SIZE.y and sz.x <= F.CELL_TILES.x - 2 and sz.y <= F.CELL_TILES.y - 2
		if r["role"] == "stair":
			var top: String = g[0]
			var mid: int = w / 2
			ok_stair = ok_stair and top.substr(mid - 1, 3) == "..."
	_check(ok_shape, "every hand-made room is a neat grid of known tiles")
	_check(ok_fit, "every hand-made room fits its cell of the floor")
	_check(ok_stair, "stair rooms keep the stair's spot clear")
	_check(Rooms.for_role("combat", 3).size() >= 8 and Rooms.for_role("start", 2).size() >= 2 and Rooms.for_role("stair", 2).size() >= 2, "enough rooms of each kind for variety")
	var flip: Array = Rooms.flipped({"grid": ["#..", "..."]}, true, true)
	_check(flip == ["...", "..#"], "rooms can be flipped both ways")
	_check(Rooms.prepare(["#..", "...", ".#."]) == ["X..", "...", "X#."] or Rooms.prepare(["#..", "...", ".#."]) == ["X..", "...", ".X."], "walls on a room's edge become its outline")
	var ok_carve := true
	for shape in Rooms.SHAPES:
		var rows: Array = Rooms.prepare(Rooms.carve(shape, Vector2i(11, 9)))
		ok_carve = ok_carve and rows.size() == 9 and String(rows[0]).length() == 11
		for side in 4:
			ok_carve = ok_carve and not Rooms.door_slots(rows, side).is_empty()
	_check(ok_carve, "every carved shape can take a doorway on each side")
	# Floors are built from them, with no room twice on a floor.
	await _fresh_main()
	main.profile.regarded = true
	main.first_climb = false
	var ok_ids := true
	var ok_reach := true
	for n in 6:
		var plan: Dictionary = F.rooms_floor(2 + n % 3, main.Towers.TOWERS["firebird"] if n % 2 == 0 else main.Towers.TOWERS["kraken"])
		var ids: Array = plan.get("room_ids", [])
		var made: Array = ids.filter(func(id): return not String(id).begins_with("carved_"))
		var uniq := {}
		for id in made:
			uniq[id] = true
		ok_ids = ok_ids and ids.size() == plan["rooms"].size() and uniq.size() == made.size() and made.size() >= 1
	for n in 4:
		main.tower = main.Towers.ORDER[n]
		main._start_floor(3)
		for e in main.enemies():
			e.set_physics_process(false)
		main.open_all_doors()
		var from: Vector2i = main._tile_of(main.player_start)
		var to: Vector2i = main._tile_of(main.stair_pos)
		ok_reach = ok_reach and not main.astar.get_id_path(from, to).is_empty()
	_check(ok_ids, "each floor mixes hand-made rooms (none twice on a floor) with carved ones")
	_check(ok_reach, "the stair can always be reached through the rooms")
	# Fog: you see what your climber can see.
	var fog = main.fog
	var p = main.player
	await _frames(2)
	_check(fog.visible and fog.sees(p.global_position), "floors of rooms have line-of-sight fog, and you see where you stand")
	var far := Vector2.ZERO
	for x in main.grid_size.x:
		for y in main.grid_size.y:
			var pos: Vector2 = main.room.position + Vector2(x, y) * F.CELL + Vector2(20, 20)
			if far == Vector2.ZERO and not main.is_solid(pos) and pos.distance_to(p.global_position) > 900.0:
				far = pos
	_check(far != Vector2.ZERO and not fog.sees(far), "far rooms are hidden in the fog")
	var i0: int = main._tile_of(p.global_position).y * main.grid_size.x + main._tile_of(p.global_position).x
	p.global_position = far
	await _frames(3)
	_check(fog.sees(far) and fog.seen[i0] == 1 and fog.vis[i0] == 0, "where you've been stays mapped once you leave it")
	var foe = await _spawn("slime", main.player_start)
	foe.set_physics_process(false)
	await _frames(2)
	_check(not foe.visible, "monsters out of sight are hidden")
	p.global_position = main.player_start + Vector2(40, 0)
	await _frames(3)
	_check(foe.visible, "...and appear when you see them")
	foe.queue_free()
	main._start_floor(1)
	await _frames(2)
	_check(not fog.visible, "single-room floors have no fog")


func _puzzle_tests() -> void:
	print("puzzles and the stair's ward")
	var F = main.Floors
	var C = load("res://scripts/puzzles/catalog.gd")
	var ok_all := true
	for n in 12:
		var plan: Dictionary = F.rooms_floor(2 + n % 4, main.Towers.TOWERS[main.Towers.ORDER[n % 6]])
		ok_all = ok_all and not plan.get("puzzle", {}).is_empty()
	_check(ok_all, "every floor of rooms has a puzzle room")
	# Which kind: every kind turns up; each tower leans to its own.
	var picks := {}
	var sig := {}
	for n in 600:
		var tid: String = main.Towers.ORDER[n % 6]
		var k: String = C.pick(2 + n % 10, tid)
		picks[k] = true
		if C.SIGNATURE.get(tid, "") == k:
			sig[tid] = int(sig.get(tid, 0)) + 1
	_check(picks.size() == C.TYPES.size(), "every kind of puzzle turns up (%s)" % [picks.keys()])
	_check(int(sig.get("gryphon", 0)) > 35 and int(sig.get("wyvern", 0)) > 35 and int(sig.get("manticore", 0)) > 35,
		"the Gryphon favours mirrors, the Wyvern the crumbling path, the Manticore the statues (%s of 100 each)" % [sig])
	_check(C.tier_for(2) == 1 and C.tier_for(3) == 1 and C.tier_for(4) == 2 and C.tier_for(8) == 2 and C.tier_for(9) == 3 and C.tier_for(11) == 3,
		"tiers: 1 on floors 2-3, 2 on 4-8, 3 on 9-11")
	_check(C.mode_for(3) == "quiet" and C.mode_for(C.PRESSURE_FROM) == "pressure", "quiet mode low down, pressure mode higher up")
	# Every kind can be forced onto a floor, at the floor's tier, in its own themed hall.
	var ok_forced := true
	for kind in C.TYPES:
		C.forced = kind
		for fl in [2, 5, 9]:
			var plan: Dictionary = F.rooms_floor(fl, main.Towers.TOWERS[main.Towers.ORDER[fl % 6]])
			var pz: Dictionary = plan.get("puzzle", {})
			ok_forced = ok_forced and pz.get("type", "") == kind and int(pz.get("tier", 0)) == C.tier_for(fl) and pz.get("mode", "") == C.mode_for(fl)
			var gi: int = plan["room_info"].map(func(ri): return ri["role"]).find("gallery")
			ok_forced = ok_forced and plan["themes"][gi] == "puzzle_" + kind
			if not (kind in C.PREFAB):
				ok_forced = ok_forced and not pz.get("entrances", []).is_empty()
	C.forced = ""
	_check(ok_forced, "each kind can be laid out on floors 2, 5 and 9, at the floor's tier, in a hall themed for it, with its doorways known")
	_puzzle_generator_tests()

	await _fresh_main()
	main.profile.regarded = true
	main.first_climb = false
	main.dev_no_death = true
	var p = main.player
	var pz = main.puzzle
	main._start_floor(3)
	for e in main.enemies():
		e.set_physics_process(false)
	await _frames(2)
	_check(main.ward and pz.active(), "a floor of rooms starts with its stair warded")
	# The stair stays shut however many monsters fall.
	for e in main.enemies():
		_slay(e)
	await _frames(4)
	_check(not main.stair_open, "killing every monster doesn't open a warded stair")
	# The puzzle can always be reached: no rail or gate cuts off the stair.
	main.open_all_doors()
	var from: Vector2i = main._tile_of(main.player_start)
	_check(not main.astar.get_id_path(from, main._tile_of(main.stair_pos)).is_empty(), "the stair can still be reached past the puzzle's rails and gates")
	# A test puzzle of each hand-made kind, laid out in the start room. (Some
	# start rooms have a wall there: lay the floor out again until it's open.)
	var c: Vector2 = main.player_start + Vector2(0, -120)
	var is_open := func(at: Vector2) -> bool:
		for dx in range(-160, 161, 40):
			for dy in range(-200, 161, 40):
				if main.is_solid(at + Vector2(dx, dy)):
					return false
		for tr in main.traps:
			if tr["pos"].distance_to(at) <= 260.0:
				return false
		return true
	var found := false
	for attempt in 40:
		# (The start, or the middle of any room on this floor.)
		var spots: Array = [main.player_start + Vector2(0, -120)]
		for info in main.room_info:
			spots.append(info["rect"].get_center())
		for at in spots:
			if is_open.call(at):
				c = at
				found = true
				break
		if found:
			break
		main._start_floor(3)
		for e in main.enemies():
			e.queue_free()
		await _frames(1)
	_check(found, "(found an open patch of floor for the test puzzles)")
	for e in main.enemies():
		if e.global_position.distance_to(c) < 420.0:
			e.queue_free()
	await _frames(1)
	var tile := func(v: Vector2) -> Vector2: return main.room.position + (Vector2(main._tile_of(v)) + Vector2(0.5, 0.5)) * F.CELL
	# Eyes: arrows and strikes light them; all lit solves it.
	var e1: Vector2 = tile.call(c + Vector2(-80, 0))
	var e2: Vector2 = tile.call(c + Vector2(80, 0))
	var gate_r := Rect2(tile.call(c + Vector2(0, 80)) - Vector2(20, 20), Vector2(40, 40))
	pz.setup({"type": "eyes", "tier": 1, "mode": "", "eyes": [e1, e2], "gates": [gate_r], "rewards": [gate_r.get_center() + Vector2(0, 40)], "room": main.room})
	main.ward = true
	main.stair_open = false
	_check(pz.gates.size() == 1 and not pz.gates[0]["open"], "the gate starts shut")
	p.global_position = e1 + Vector2(0, 50)
	p.aim = Vector2.UP
	_check(pz.aim_point(p.global_position, 380.0) != Vector2.INF, "with no foe near, auto-aim finds the puzzle's eye")
	_check(pz.strike(p.global_position, Vector2.UP, 50.0, 60.0) == 1 and pz.cur.eyes[0]["lit"] > 0.0, "a strike lights an eye")
	var arrow = main.spawn_projectile(e2 + Vector2(-120, 0), Vector2(400, 0), 5.0)
	arrow.friendly = true
	await _wait(0.5)
	_check(pz.cur.eyes[1]["lit"] > 0.0 and not is_instance_valid(arrow), "an arrow lights an eye (and stops there)")
	await _frames(2)
	_check(pz.solved and not main.ward and main.stair_open, "lighting every eye lifts the ward and opens the stair")
	_check(pz.gates[0]["open"], "...and opens the gate to the reward")
	# Harder eyes go dark again unless they're all lit together.
	pz.setup({"type": "eyes", "tier": 2, "mode": "", "eyes": [e1, e2], "room": main.room})
	main.ward = true
	main.stair_open = false
	pz.shot(e1)
	_check(pz.cur.eyes[0]["lit"] > 0.0, "a harder eye lights...")
	await _wait(pz.cur.EYE_WINDOW + 0.3)
	_check(pz.cur.eyes[0]["lit"] <= 0.0 and not pz.solved, "...but goes dark again if the others aren't lit in time")
	pz.shot(e1)
	pz.shot(e2)
	await _frames(2)
	_check(pz.solved, "lit together, they solve it")
	pz.setup({"type": "eyes", "tier": 3, "mode": "", "eyes": [e1, e2], "room": main.room})
	_check(pz.cur.window() < pz.cur.EYE_WINDOW, "tier 3 eyes stay lit for less time")
	# Stormcaller's Static (a shortcut): waking one eye sparks the next.
	main.grant_test_bonds()
	pz.setup({"type": "eyes", "tier": 2, "mode": "", "eyes": [e1, e2], "room": main.room})
	main.ward = true
	pz.shot(e1)
	await _frames(2)
	_check(pz.solved, "Stormcaller's Static: one eye's spark wakes the other")
	for part in ["hand", "legs"]:
		main.dev_set_mark(part, "", 1)
	# Plates: need a weight (a block or a monster), not the climber.
	var pl: Vector2 = tile.call(c + Vector2(0, 0))
	var blk: Vector2 = pl + Vector2(-80, 0)
	var lev: Vector2 = pl + Vector2(0, 80)
	pz.setup({"type": "plates", "tier": 1, "plates": [pl], "pushers": [blk], "levers": [lev], "room": main.room})
	main.ward = true
	main.stair_open = false
	p.global_position = pl
	await _frames(3)
	_check(not pz.cur.plates[0]["down"], "the climber is too light to hold a plate down")
	p.global_position = pl + Vector2(0, 120)
	var b: Dictionary = pz.cur.blocks[0]
	_check(pz.cur.slide(b, Vector2.RIGHT) and b["pos"].distance_to(pl + Vector2(-40, 0)) < 1.0, "a block slides a tile")
	pz.strike(lev + Vector2(0, 40), Vector2.UP, 50.0, 60.0)
	_check(b["pos"] == b["home"], "the lever puts the blocks back")
	# Leaning on it pushes it.
	p.global_position = blk + Vector2(-34, 0)
	Input.action_press("move_right")
	await _wait(0.75)
	Input.action_release("move_right")
	_check(b["pos"].x > blk.x + 30.0, "walking into a block pushes it (%s)" % [b["pos"] - blk])
	pz.cur.slide(b, Vector2.RIGHT)
	await _frames(3)
	_check(pz.cur.plates[0]["down"] and pz.solved and main.stair_open, "a block on the plate solves it and lifts the ward")
	# A monster can hold a plate down too.
	pz.setup({"type": "plates", "tier": 2, "plates": [pl], "room": main.room})
	main.ward = true
	var holder = await _spawn("knight", pl)
	holder.set_physics_process(false)
	await _frames(3)
	_check(pz.solved, "a monster standing on a plate holds it down")
	holder.queue_free()
	await _frames(1)
	# Sandshaper's Rooted Stance (a shortcut): heavy enough yourself.
	_mark("legs", "sandshaper", 1)
	pz.setup({"type": "plates", "tier": 2, "plates": [pl], "room": main.room})
	main.ward = true
	p.global_position = pl
	await _frames(3)
	_check(pz.solved, "Sandshaper's Rooted Stance: you hold a plate down yourself")
	main.dev_set_mark("legs", "", 1)
	pz.clear()
	main.ward = false
	await _statue_tests()
	await _mirror_tests()
	await _crumble_tests()
	await _ice_tests()
	await _essence_lock_tests()
	await _memory_puzzle_tests()
	main.dev_no_death = false


## The generators, on a plain room, over many seeds: always solvable (by
## each kind's own solver) and harder by tier.
func _puzzle_generator_tests() -> void:
	var S = load("res://scripts/puzzles/statues.gd")
	var M = load("res://scripts/puzzles/mirrors.gd")
	var K = load("res://scripts/puzzles/crumble.gd")
	var rows: Array = []
	for y in 10:
		rows.append("............")
	var ctx := {"rows": rows, "reserved": {}, "features": {}}
	var rect := Rect2(0, 0, 480, 400)
	var to_tile := func(v: Vector2) -> Vector2i: return Vector2i(((v - rect.position) / 40.0).floor())
	var blocked := func(t: Vector2i) -> bool: return t.x < 0 or t.y < 0 or t.x >= 12 or t.y >= 10
	for tier in [1, 2, 3]:
		# Three Statues: exactly one plate fits; tier 3 says two things each.
		var ok_s := true
		var ok_meta := true
		for n in 40:
			var s: Dictionary = S.make(rect, 2, tier, ctx)
			ok_s = ok_s and not s.is_empty()
			if s.is_empty():
				continue
			var doors: Array = S.solve_doors(s["statements"], tier)
			ok_s = ok_s and doors.size() == 1 and doors[0] == s["answer"] and s["statues"].size() == 3 and s["plates"].size() == 3
			for st in s["statements"]:
				ok_s = ok_s and st.size() == (2 if tier >= 3 else 1)
			if tier == 2:
				var meta := false
				for st in s["statements"]:
					for one in st:
						meta = meta or String(one[0]) in ["other_liar", "other_true"]
				ok_meta = ok_meta and meta
		_check(ok_s and ok_meta, "Three Statues, tier %d: 40 riddles, each with exactly one right plate%s" % [tier, " (two statements each, one statue alternating)" if tier == 3 else (" (one about another's honesty)" if tier == 2 else "")])
		# Beam and Mirrors: scrambled, and the solver brings the beam home.
		var ok_m := true
		for n in 40:
			var m: Dictionary = M.make(rect, 2, tier, ctx)
			ok_m = ok_m and not m.is_empty()
			if m.is_empty():
				continue
			var mir: Array = m["mirrors"].map(func(q): return {"tile": to_tile.call(q["pos"]), "o": q["o"], "fixed": q["fixed"]})
			var e: Vector2i = to_tile.call(m["emitter"])
			var tg: Vector2i = to_tile.call(m["receiver"])
			ok_m = ok_m and not M.trace(e, m["dir"], tg, mir, blocked)["hit"]
			ok_m = ok_m and not M.solve(e, m["dir"], tg, mir, blocked).is_empty()
			var fixed: int = mir.filter(func(q): return q["fixed"]).size()
			ok_m = ok_m and mir.size() == int(M.MIRRORS[tier]) + int(M.DECOYS[tier]) and fixed == (1 if tier >= 3 else 0)
			var answer: Array = m["mirrors"].map(func(q): return q["answer"])
			for i in mir.size():
				mir[i]["o"] = answer[i]
			ok_m = ok_m and M.trace(e, m["dir"], tg, mir, blocked)["hit"]
		_check(ok_m, "Beam and Mirrors, tier %d: 40 layouts, %d mirrors (+%d decoys), scrambled, always solvable" % [tier, M.MIRRORS[tier], M.DECOYS[tier]])
		# The Crumbling Path: a route over every stone, from the edge.
		var ok_k := true
		for n in 40:
			var k: Dictionary = K.make(rect, 2, tier, ctx)
			ok_k = ok_k and not k.is_empty()
			if k.is_empty():
				continue
			var g: Array = K.GRID[tier]
			ok_k = ok_k and k["cols"] == g[0] and k["rows"] == g[1] and k["holes"].size() == g[2] and k["cells"].size() == g[0] * g[1] - g[2]
			var path: Array = K.hamilton_path(k["cells"], k["cols"], k["rows"])
			ok_k = ok_k and path.size() == k["cells"].size()
			for i in range(1, path.size()):
				ok_k = ok_k and absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y) == 1
		_check(ok_k, "The Crumbling Path, tier %d: 40 grids of %dx%d with %d holes, each crossable stone by stone" % [tier, K.GRID[tier][0], K.GRID[tier][1], K.GRID[tier][2]])
	# A grid with no route at all is turned down.
	var cells: Array = []
	for y in 3:
		for x in 3:
			if Vector2i(x, y) != Vector2i(1, 0):
				cells.append(Vector2i(x, y))
	_check(K.hamilton_path(cells, 3, 3).is_empty(), "the path's search turns down a grid no route can cross")


## A floor of rooms with this kind of puzzle, its monsters gone, doors open.
func _puzzle_floor(kind: String, fl: int) -> void:
	var C = load("res://scripts/puzzles/catalog.gd")
	C.forced = kind
	main._start_floor(fl)
	C.forced = ""
	for e in main.enemies():
		e.queue_free()
		e.remove_from_group("enemies")
	main.foes_changed()
	main.open_all_doors()
	await _frames(3)


func _clear_foes() -> void:
	for e in main.enemies():
		e.queue_free()
		e.remove_from_group("enemies")
	main.foes_changed()
	await _frames(2)


func _statue_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	await _puzzle_floor("statues", 3)
	var S = pz.cur
	_check(pz.kind == "statues" and pz.tier == 1 and pz.mode == "quiet" and S.statements.size() == 3, "a statue hall on floor 3: tier 1, quiet")
	# Quiet: a monster in the room keeps the statues asleep (as when the floor begins).
	pz.awake = false
	var guard = await _spawn("slime", pz._spot())
	await _wait(0.4)
	var wrong: int = (S.answer + 1) % 3
	p.global_position = S.plates[wrong]["pos"]
	await _wait(1.3)
	_check(not pz.awake and not pz.locked and not pz.solved, "quiet: the statues sleep (and the plates do nothing) while a monster stands in their room")
	guard.queue_free()
	guard.remove_from_group("enemies")
	main.foes_changed()
	p.global_position = S.plaque
	await _wait(0.4)
	_check(pz.awake, "...and wake once the guards are dead")
	# A wrong plate fails: an ambush, then the riddle starts again.
	var before: int = main.enemies().size()
	p.global_position = S.plates[wrong]["pos"]
	await _wait(1.3)
	_check(pz.locked and not pz.solved and main.ward and main.enemies().size() > before, "a wrong plate fails the test: an ambush, and the ward holds")
	_check(pz.aim_point(p.global_position, 380.0) == Vector2.INF and pz.strike(p.global_position, Vector2.UP, 60.0, 60.0) == 0, "...and nothing in the test answers while the ambush is on")
	p.global_position = S.plaque
	for e in pz.ambushers:
		_slay(e)
	await _wait(0.3)
	_check(not pz.locked and not pz.solved, "once the ambush is beaten, the test begins again")
	_check(S.solve_doors(S.statements, 1) == [S.answer], "...with a new riddle that still has exactly one answer")
	# It never locks: even an ambush left alive gives way to a reset in time.
	pz.fail("test")
	pz.lock_t = pz.LOCK_MAX
	await _frames(3)
	_check(not pz.locked, "an ambush never keeps the test shut for good (reset after %d s)" % int(pz.LOCK_MAX))
	await _clear_foes()
	await _wait(0.4)
	p.global_position = S.plates[S.answer]["pos"]
	await _wait(1.3)
	_check(pz.solved and not main.ward and main.stair_open, "the right plate solves it: the ward lifts and the stair opens")
	# Tier 2: the room seals behind you.
	await _puzzle_floor("statues", 5)
	S = pz.cur
	var entr: Array = pz.spec.get("entrances", [])
	_check(pz.tier == 2 and not entr.is_empty(), "a statue hall on floor 5 knows its doorways")
	p.global_position = S.plaque
	await _wait(0.3)
	_check(pz.sealed and pz.seal_bodies.size() == entr.size() and main.astar.is_point_solid(main._tile_of(entr[0].get_center())), "stepping in seals the doorways")
	pz.fail("test")
	_check(not pz.sealed, "a failure opens the seal (fight or run)")
	pz.lock_t = pz.LOCK_MAX
	await _frames(3)
	await _clear_foes()
	await _wait(0.4)
	_check(pz.sealed and pz.awake, "after the reset, the room closes again")
	p.global_position = S.plates[S.answer]["pos"]
	await _wait(1.3)
	_check(pz.solved and not pz.sealed and not main.astar.is_point_solid(main._tile_of(entr[0].get_center())), "solving it opens the seal for good")
	# Hunter's Keen Eyes (a shortcut): the liars show after a few moments.
	await _puzzle_floor("statues", 4)
	S = pz.cur
	_mark("brow", "hunter", 1)
	p.global_position = S.plaque
	await _wait(S.KEEN_TIME + 0.5)
	_check(S.keen and not S.liars.is_empty(), "Hunter's Keen Eyes: the lying statues show themselves")
	main.dev_set_mark("brow", "", 1)
	# Tier 3, pressure: two statements each, and monsters keep coming.
	await _puzzle_floor("statues", 9)
	S = pz.cur
	_check(pz.tier == 3 and pz.mode == "pressure" and S.statements[0].size() == 2, "floor 9: two statements each, in pressure mode")
	p.global_position = S.plaque
	await _wait(0.3)
	pz.press_t = 0.0
	await _frames(3)
	_check(pz.pressers.size() == 1 and pz.awake, "pressure: a monster arrives while you think, and the statues still speak")
	await _clear_foes()


func _mirror_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	await _puzzle_floor("mirrors", 5)
	var M = pz.cur
	_check(pz.kind == "mirrors" and M.mirrors.size() == 5 and not M.hit, "a mirror hall on floor 5: 4 mirrors and a decoy, the beam not yet home")
	var m: Dictionary = M.mirrors.filter(func(q): return not q["fixed"])[0]
	p.global_position = m["pos"] + Vector2(0, 50)
	await _wait(0.4)
	var aim: Vector2 = pz.aim_point(p.global_position, 150.0)
	_check(M.mirrors.any(func(q): return q["pos"] == aim), "with no foe near, auto-aim finds a mirror")
	var o0: String = m["o"]
	_check(pz.strike(p.global_position, Vector2.UP, 50.0, 60.0) >= 1 and m["o"] != o0, "a strike turns a mirror")
	await _wait(0.4)
	var arrow = main.spawn_projectile(m["pos"] + Vector2(-26, 0), Vector2(400, 0), 5.0)
	arrow.friendly = true
	await _wait(0.5)
	_check(m["o"] == o0 and not is_instance_valid(arrow), "an arrow turns a mirror (and stops there)")
	await _wait(0.4)
	# Windwalker's Crosswind (a shortcut): its wall of wind turns the mirrors it passes.
	main.walls.append({"a": m["pos"] + Vector2(-60, 0), "b": m["pos"] + Vector2(60, 0), "t": 1.0, "color": Color.WHITE})
	await _frames(3)
	_check(m["o"] != o0, "Crosswind turns a mirror it passes")
	main.walls.clear()
	# The answer: the beam reaches the sigil, holds, and the ward lifts.
	for i in M.mirrors.size():
		M.mirrors[i]["o"] = pz.spec["mirrors"][i]["answer"]
	M._retrace()
	_check(M.hit, "facing the mirrors right carries the beam to the sigil")
	await _wait(M.HOLD + 0.3)
	_check(pz.solved and main.stair_open and not main.ward, "the beam held on the sigil solves it and lifts the ward")
	_check(M.light_id >= 0 and main.lighting.lights.has(M.light_id), "the lit sigil adds its light to the darkness")
	# Tier 3: one grey mirror won't turn.
	await _puzzle_floor("mirrors", 9)
	M = pz.cur
	var fixed: Array = M.mirrors.filter(func(q): return q["fixed"])
	_check(M.mirrors.size() == 7 and fixed.size() == 1, "floor 9: 5 mirrors, 2 decoys, one fixed")
	var fo: String = fixed[0]["o"]
	pz.strike(fixed[0]["pos"] + Vector2(0, 40), Vector2.UP, 50.0, 60.0)
	pz.shot(fixed[0]["pos"])
	_check(fixed[0]["o"] == fo and not pz.aim_point(fixed[0]["pos"] + Vector2(0, 30), 60.0) == fixed[0]["pos"], "the fixed mirror can't be turned (nor is it aimed at)")
	pz.clear()
	main.ward = false


func _crumble_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	await _puzzle_floor("crumble", 5)
	var K = pz.cur
	_check(pz.kind == "crumble" and K.stones.size() == 19 and K.holes.size() == 1, "a crumbling path on floor 5: 5x4 stones, one hole")
	var path: Array = K.hamilton_path(K.stones.keys(), K.cols, K.rows_n)
	_check(path.size() == K.stones.size(), "a route over every stone exists")
	var step := func(t: Vector2i) -> void:
		p.global_position = K.stone_center(t)
	# Back onto a lit stone: it crumbles, hurts, and the path goes dark.
	step.call(path[0])
	await _wait(0.06)
	step.call(path[1])
	await _wait(0.06)
	_check(K.lit_count() == 2, "each stone lights as you step on it")
	var hp: float = p.hp
	p.iframes = 0.0
	step.call(path[0])
	await _wait(0.06)
	_check(K.lit_count() == 0 and p.hp < hp, "stepping back on a lit stone hurts and puts the path out")
	# A break in the path (a jump to a stone not beside the last) puts it out too.
	p.global_position = K.origin + Vector2(-60, -60)
	await _wait(0.1)
	K.reset()
	step.call(path[0])
	await _wait(0.06)
	step.call(path[2])
	await _wait(0.06)
	_check(K.lit_count() == 0, "a break in the path puts it out")
	# Wandering off the grid does too.
	p.global_position = K.origin + Vector2(-60, -60)
	await _wait(0.1)
	K.reset()
	step.call(path[0])
	await _wait(0.06)
	p.global_position = K.origin + Vector2(-60, -60)
	await _wait(K.OFF_GRACE + 0.2)
	_check(K.lit_count() == 0, "wandering off the stones puts them out")
	# Flamewing's Phoenix Glide (a shortcut): a glide passes over a lit stone unfelt.
	_mark("back", "flamewing", 1)
	K.reset()
	step.call(path[0])
	await _wait(0.06)
	step.call(path[1])
	await _wait(0.06)
	p.jump_t = 0.3
	p.jump_total = 0.42
	step.call(path[0])
	await _wait(0.06)
	_check(K.lit_count() == 2, "Phoenix Glide: gliding over a lit stone doesn't break it")
	p.global_position = K.origin + Vector2(-60, -60)
	main.dev_set_mark("back", "", 1)
	await _wait(0.4)
	await _wait(K.OFF_GRACE + 0.2)
	K.reset()
	# Every stone once: solved.
	for t in path:
		step.call(t)
		await _wait(0.04)
	_check(pz.solved and main.stair_open and not main.ward, "stepping on every stone once solves it and lifts the ward")
	# Higher up: a bigger grid with more holes.
	await _puzzle_floor("crumble", 9)
	_check(pz.cur.stones.size() == 28 and pz.cur.holes.size() == 2, "floor 9: 6x5 stones, two holes")
	await _puzzle_floor("crumble", 2)
	_check(pz.cur.stones.size() == 15 and pz.cur.holes.is_empty(), "floor 2: 5x3 stones, no holes")
	pz.clear()
	main.ward = false


const MOVE_KEYS := {Vector2i(1, 0): "move_right", Vector2i(-1, 0): "move_left", Vector2i(0, 1): "move_down", Vector2i(0, -1): "move_up"}


## Holds a direction until the ice starts a slide, lets go, and waits for it to end.
func _ice_slide(I, d: Vector2i) -> void:
	var act: String = MOVE_KEYS[d]
	Input.action_press(act)
	var until := Time.get_ticks_msec() + 600
	while I.slide_dir == Vector2i.ZERO and Time.get_ticks_msec() < until:
		await physics_frame
	Input.action_release(act)
	until = Time.get_ticks_msec() + 3000
	while I.slide_dir != Vector2i.ZERO and Time.get_ticks_msec() < until:
		await physics_frame
	for k in 4:
		await physics_frame


func _ice_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	await _puzzle_floor("ice", 2)
	var I = pz.cur
	_check(pz.kind == "ice" and pz.tier == 1 and I.need >= 2 and I.need <= 5 and not I.rocks.has(I.dais),
		"an Ice Hall on floor 2: tier 1, its dais needs 2 to 5 slides (%d)" % I.need)
	var plan_room: Rect2 = pz.room
	_check(plan_room.encloses(I.field_rect()) and plan_room.grow(-38.0).encloses(I.field_rect()), "the ice fills the hall but for a ring of floor")
	var route: Array = I.route(I.cols, I.rows_n, I.rocks, I.dais)
	_check(route.size() - 1 == I.need, "the solver's shortest line of slides reaches the dais in %d" % I.need)
	await _wait(0.4)  # (quiet: the dais wakes once no guard stands in the hall)
	# Off the ice, you walk as ever; step on and you slide to a rock.
	p.global_position = I.center(route[0])
	await _frames(2)
	_check(not I.on_ice(p.global_position) and not pz.steer(p, 0.016), "on the ring of floor you walk as usual")
	await _ice_slide(I, route[1])
	var first: Vector2i = I.slide_from(route[0], route[1], I.cols, I.rows_n, I.rocks)
	_check(I.on_ice(p.global_position) and I.grid(p.global_position) == first and p.global_position.distance_to(I.center(first)) < 3.0,
		"stepping onto the ice slides you along the grid until a rock stops you")
	# No rolling or jumping on the ice.
	p.sta = p.max_sta
	_check(p._try_roll(Vector2.RIGHT) and p.roll_t <= 0.0 and p._try_jump(Vector2.RIGHT) and not p.in_air(), "no rolling or jumping on the ice")
	# A blow sends you sliding the way it pushed.
	var at: Vector2i = first
	var push := Vector2i.ZERO
	for d in I.DIRS:
		var t: Vector2i = I.slide_from(at, d, I.cols, I.rows_n, I.rocks)
		if t != at and t != I.EXIT and t != I.dais:
			push = d
			break
	if push != Vector2i.ZERO:
		p.knock = Vector2(push) * 200.0
		for k in 2:
			await physics_frame
		_check(I.slide_dir == push, "a blow on the ice starts a slide the way it pushed")
		var until := Time.get_ticks_msec() + 3000
		while I.slide_dir != Vector2i.ZERO and Time.get_ticks_msec() < until:
			await physics_frame
		await _frames(2)
	# Sliding off the edge puts you back on the floor (the way back to the start).
	at = I.grid(p.global_position)
	var off: Array = I.way_off(I.cols, I.rows_n, I.rocks, at)
	_check(not off.is_empty(), "from wherever you stop, some line of slides leads off the ice")
	off = I.way_off(I.cols, I.rows_n, I.rocks, at, I.dais)  # (one that doesn't stop on the dais)
	if not off.is_empty() and at != I.dais:
		for d in off:
			await _ice_slide(I, d)
		_check(not I.on_ice(p.global_position) and pz.room.has_point(p.global_position) and not pz.solved, "sliding off the edge leaves you on the floor, to try again")
	# A monster in your lane stops you short, on a tile.
	p.global_position = I.center(route[0])
	await _frames(2)
	var lane: Array = []
	var t0: Vector2i = route[0] + route[1]
	while I.in_field(t0) and not I.rocks.has(t0):
		lane.append(t0)
		t0 += route[1]
	if lane.size() >= 3:
		var foe = await _spawn("knight", I.center(lane[2]))
		foe.weight = 1000.0  # (a sliding climber shoves light monsters along)
		await _ice_slide(I, route[1])
		await _wait(0.15)
		var g: Vector2i = I.grid(p.global_position)
		_check(I.on_ice(p.global_position) and g in [lane[0], lane[1]] and p.global_position.distance_to(I.center(g)) < 4.0,
			"a monster in your lane stops you short, on the middle of a tile")
		foe.queue_free()
		main.foes_changed()
		await _frames(2)
	# The solver's line of slides, from the floor: solved.
	p.global_position = I.center(route[0])
	await _frames(2)
	for i in range(1, route.size()):
		await _ice_slide(I, route[i])
	await _wait(0.1)
	_check(pz.solved and main.stair_open and not main.ward, "the solver's slides, keyed in, end on the dais: solved, the ward lifts")
	# Higher up the dais needs more slides.
	await _puzzle_floor("ice", 9)
	_check(pz.cur.need >= 4, "floor 9: the dais needs at least 4 slides (%d)" % pz.cur.need)
	pz.clear()
	main.ward = false


## Waits (in physics ticks) until `cond` holds, at most `seconds`.
func _until(cond: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < until:
		await physics_frame


func _essence_lock_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	var E = load("res://scripts/essence.gd")
	await _puzzle_floor("lock", 3)
	var L = pz.cur
	var a: String = L.answers[0] if not L.answers.is_empty() else ""
	_check(pz.kind == "lock" and pz.tier == 1 and L.answers.size() == 1 and L.decoys.size() == 2 and not (a in L.decoys)
		and E.KINDS.has(a) and L.riddles[0] in L.RIDDLES[a], "an Essence Lock on floor 3: a riddle for one essence, two decoys")
	await _wait(0.35)  # (quiet: it wakes once no guard stands in the room)
	# Well inside, foes appear glowing in the answer and the decoys.
	p.global_position = pz.room.get_center() + Vector2(0, 60)
	await _until(func(): return L.spawned, 1.0)
	var kinds: Array = L.glowing.map(func(g): return g["kind"])
	kinds.sort()
	var want: Array = L.answers + L.decoys
	want.sort()
	_check(L.glowing.size() == 3 and kinds == want, "well inside, three foes appear, glowing in the answer and the decoys")
	# A slain decoy leaves a spark; carried to the lock, it brings the hunters.
	var decoy: Dictionary = L.glowing.filter(func(g): return g["kind"] != a)[0]
	decoy["e"].set_physics_process(false)
	_slay(decoy["e"])
	await _until(func(): return not L.sparks.is_empty(), 1.0)
	_check(L.sparks.size() == 1 and L.sparks[0]["kind"] == decoy["kind"], "a slain glowing foe leaves a spark of its essence")
	p.global_position = L.sparks[0]["pos"]
	await _until(func(): return L.carried != "", 0.5)
	_check(L.carried == decoy["kind"] and L.sparks.is_empty(), "walking over a spark carries it")
	p.global_position = L.lock + Vector2(0, 34)
	await _until(func(): return pz.locked, 0.5)
	_check(pz.locked and not pz.ambushers.is_empty() and not pz.solved and L.carried == "", "the wrong spark at the lock: the beast sends hunters")
	for e in pz.ambushers:
		_slay(e)
	await _until(func(): return not pz.locked, 1.0)
	_check(not pz.locked and L.step == 0 and not L.spawned and L.glowing.is_empty() and L.answers.size() == 1, "the hunters beaten, the lock asks anew (the old glow crumbles)")
	# The right spark opens it.
	p.global_position = pz.room.get_center() + Vector2(0, 60)
	await _until(func(): return L.spawned, 1.0)
	a = L.answers[0]
	var right: Array = L.glowing.filter(func(g): return g["kind"] == a)
	_check(right.size() == 1, "...with new glowing foes")
	if right.size() == 1:
		_slay(right[0]["e"])
		await _until(func(): return not L.sparks.is_empty(), 1.0)
		p.global_position = L.sparks[0]["pos"]
		await _until(func(): return L.carried != "", 0.5)
		p.global_position = L.lock + Vector2(0, 34)
		await _until(func(): return pz.solved, 0.5)
	_check(pz.solved and main.stair_open and not main.ward, "the right spark at the lock: solved, the ward lifts")
	await _clear_foes()
	# Higher up: two or three essences, in order. A spell from a mark of the
	# right essence answers at once; a wrong one only doesn't answer.
	await _puzzle_floor("lock", 9)
	L = pz.cur
	_check(L.answers.size() >= 2 and L.answers.size() <= 3 and L.decoys.size() == 2 and L.riddles.size() == L.answers.size(),
		"floor 9: the lock wants %d essences, in order" % L.answers.size())
	await _wait(0.35)
	var B = load("res://scripts/bonds.gd")
	var bond_of := func(k: String) -> String:
		for id in B.BONDS:
			if B.BONDS[id]["affinity"] == k:
				return id
		return ""
	p.global_position = L.lock + Vector2(0, 40)
	var wrong: String = L.decoys[0]
	_check(not pz.offer(wrong, p.global_position, "item") and L.step == 0 and not pz.locked, "an item of the wrong essence doesn't answer (and brings no hunters)")
	var id: String = bond_of.call(L.answers[0])
	_mark("hand", id, 1)
	p.bonds["hand"].essence = 999.0
	p.attack_cd = 0.0
	p._try_cast("hand")
	await _until(func(): return L.step >= 1, 2.0)
	_check(L.step == 1, "a spell from a mark of the first essence (%s), cast beside the lock, answers it" % id)
	main.dev_set_mark("hand", "", 1)
	# An item of the next essence, used there, answers the next.
	var item := ""
	for it in main.Items.ORDER:
		if main.Items.ITEMS[it].get("kind", "") == L.answers[1]:
			item = it
			break
	p.items[item] = 1
	p.hp = p.max_health() * 0.5  # (so a healing item has work to do)
	p.item_sel = item
	p.use_item()
	_check(L.step == 2, "an item of the next essence (%s), used beside it, answers the next" % item)
	# A strike from a weapon of the essence answers too (the Cinder Axe is Fire).
	var G = load("res://scripts/gear.gd")
	var old_melee = p.gear["melee"]
	var old_weapon: String = p.weapon
	p.gear["melee"] = G.make_named("cinder_axe")
	p.weapon = G.base_id(p.gear["melee"])
	var fire_ok: bool = "fire" in L.weapon_kinds()
	if L.step < L.answers.size():
		L.answers[L.step] = "fire"  # (the test's own riddle, for this one)
		var before: int = L.step
		pz.strike(p.global_position, (L.lock - p.global_position).normalized(), 80.0, 60.0)
		fire_ok = fire_ok and L.step == before + 1
	_check(fire_ok, "a strike on the lock from a weapon of the essence asked for answers it")
	p.gear["melee"] = old_melee
	p.weapon = old_weapon
	while L.step < L.answers.size():
		pz.offer(L.answers[L.step], L.lock, "bond")
	_check(pz.solved, "every essence given, in order: solved")
	await _clear_foes()
	pz.clear()
	main.ward = false


func _memory_puzzle_tests() -> void:
	var p = main.player
	var pz = main.puzzle
	await _puzzle_floor("memory", 3)
	var M = pz.cur
	var signs: Array = M.pedestals.map(func(q): return q["sign"])
	_check(pz.kind == "memory" and pz.tier == 1 and M.pedestals.size() == 3 and M.order.size() == 3 and M.murals.size() == 3
		and M.order.all(func(sg): return sg in signs), "a Hall of Pedestals on floor 3: three pedestals, three signs to order, three murals")
	var rooms_used := {}
	var ok_m := true
	for i in M.murals.size():
		var m: Dictionary = M.murals[i]
		rooms_used[m["room"]] = true
		ok_m = ok_m and m["room"] != pz.room and m["n"] == i + 1 and m["sign"] == M.order[i] and main.is_solid(m["pos"]) and not main.is_solid(m["pos"] + Vector2(0, 30))
	_check(ok_m and rooms_used.size() == 3, "each mural is set in the north wall of a different room (never the hall), numbering a sign")
	_check(M.murals.all(func(m): return m["seen"] == m["room"].has_point(p.global_position) or not m["seen"]) and M.murals.any(func(m): return not m["seen"]),
		"murals in rooms you haven't been to are not seen yet")
	await _wait(0.35)  # (quiet: the pedestals wake once no guard stands in the hall)
	# Walking into a mural's room notices it; the hall's panel counts them.
	for m in M.murals:
		p.global_position = m["pos"] + Vector2(0, 60)
		await _until(func(): return m["seen"], 0.5)
	_check(M.found() == 3, "walking up to each mural notices it (%d of 3)" % M.found())
	p.global_position = pz.room.get_center() + Vector2(0, 80)
	await _frames(2)
	var panel: Array = M.panels()
	_check(not panel.is_empty() and (M.TEXT["found"] % [3, 3]) in panel[0]["lines"], "the hall's panel counts the murals found")
	var ped_of := func(sg: String) -> Dictionary:
		for q in M.pedestals:
			if q["sign"] == sg:
				return q
		return {}
	# The wrong pedestal first: dark, and hunters.
	var wrong: Dictionary = ped_of.call(M.order[1])
	_check(pz.shot(wrong["pos"]) and pz.locked and not pz.ambushers.is_empty() and M.lit_n == 0, "lighting a pedestal out of order brings hunters (an arrow stops at a pedestal)")
	for e in pz.ambushers:
		_slay(e)
	await _until(func(): return not pz.locked, 1.0)
	_check(not pz.locked and M.lit_n == 0, "the hunters beaten, the pedestals can be tried again")
	# A strike lights the one beside you; then the rest in the murals' order.
	var first: Dictionary = ped_of.call(M.order[0])
	p.global_position = first["pos"] + Vector2(0, 34)
	await _frames(2)
	_check(pz.strike(p.global_position, Vector2.UP, 60.0, 60.0) == 1 and first["lit"] and M.lit_n == 1, "a strike lights the pedestal in front of you")
	for k in range(1, M.order.size()):
		pz.shot(ped_of.call(M.order[k])["pos"])
	_check(pz.solved and main.stair_open and not main.ward, "lit in the murals' order: solved, the ward lifts")
	# Higher up: four signs, then a fifth pedestal no mural shows.
	await _puzzle_floor("memory", 5)
	_check(pz.cur.order.size() == 4 and pz.cur.pedestals.size() == 4 and pz.cur.murals.size() == 4, "floor 5: four signs and four murals")
	await _puzzle_floor("memory", 9)
	M = pz.cur
	var extra: Array = M.pedestals.filter(func(q): return not (q["sign"] in M.order))
	_check(M.order.size() == 4 and M.pedestals.size() == 5 and extra.size() == 1, "floor 9: four murals and a fifth pedestal whose sign no mural shows")
	pz.clear()
	main.ward = false


func _jump_tests() -> void:
	print("jumping and chasms")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.sta = p.MAX_STA
	await _frames(1)
	Input.action_press("jump")
	var until := Time.get_ticks_msec() + 500
	while not p.in_air() and Time.get_ticks_msec() < until:
		await physics_frame
	Input.action_release("jump")
	_check(p.in_air() and p.sta < p.MAX_STA, "Z jumps, for a little stamina")
	# In the air, a chasm and burning floor can't touch you.
	main.set_chasms([Rect2(p.global_position + Vector2(-20, -20), Vector2(40, 40))])
	var hp0: float = p.hp
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0}]
	await _wait(0.2)
	_check(p.hp == hp0, "...and while you're in the air, chasms and fire can't touch you")
	main.flames = []
	main.floor_num = 3
	await _wait(0.5)
	_check(p.hp == hp0, "landing in a chasm doesn't hurt...")
	await _wait(1.4)
	_check(main.floor_num == 2 and not main.in_chasm(p.global_position) and not main.climbing, "...it drops you to the floor below (floor %d)" % main.floor_num)
	_check(main.banner.get("title", "") == main.FALL_TEXT["title"], "...and says so")
	main.set_chasms([])
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	# Walking monsters can't enter chasms; fliers can.
	var k = await _spawn("knight", p.global_position + Vector2(200, 0))
	var b = await _spawn("bat", p.global_position + Vector2(200, 60))
	_check(k.collision_mask & 16 and not (b.collision_mask & 16), "walking monsters can't step into chasms; bats fly over")
	k.queue_free()
	b.queue_free()
	# Towers with chasms lay them out clear of the start.
	var ok := true
	for n in 20:
		var plan: Dictionary = main.Floors.build(3, main.room, main.player_start, {"chasms": true})
		ok = ok and plan["chasms"].size() >= 1
		var st: Vector2 = plan.get("start", main.player_start)
		for r in plan["chasms"]:
			ok = ok and not r.grow(60.0).has_point(st)
		for m in plan["monsters"]:
			for r in plan["chasms"]:
				ok = ok and not r.has_point(m[1])
	_check(ok, "chasms are laid out clear of the start and the monsters")


func _firebird_bond_tests() -> void:
	print("the Firebird's bonds")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_mark("throat", "flame_contractor", 5)
	_mark("heart", "flamewing", 5)
	_mark("back", "rekindler", 5)
	var ok := true
	for part in ["throat", "heart", "back"]:
		ok = ok and p.bonds[part].spells().size() == 4
	_check(ok, "at step 5 each Firebird bond knows four spells")

	# Flame Contractor.
	var k = await _spawn("knight", p.global_position + Vector2(150, 0))
	k.hp = 9999.0
	k.max_hp = 9999.0
	var hp0: float = k.hp
	_cast("throat", "fireball")
	await _wait(0.5)
	_check(k.hp < hp0, "Fireball explodes on impact")
	main.flames = []
	_cast("throat", "fire_wall")
	_check(main.flames.size() >= 5 and main.flames[0]["friendly"], "Fire Wall lays a line of your own fire")
	p.hp = p.MAX_HP
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0, "friendly": true, "tick": 0.0}]
	await _wait(0.7)
	_check(p.hp == p.MAX_HP, "...which burns foes, not you")
	main.flames = []
	hp0 = k.hp
	_cast("throat", "cluster_blast")
	await _wait(0.5)
	_check(hp0 - k.hp > 20.0, "Cluster Blast splits into three explosions (%.0f)" % (hp0 - k.hp))
	hp0 = k.hp
	_cast("throat", "meteor")
	await _wait(0.8)
	_check(k.hp < hp0 - 30.0, "Meteor: a great explosion at your aim")
	var weak = await _spawn("slime", p.global_position + Vector2(100, 60))
	main.flames = []
	main.explode(weak.global_position, 40.0, 999.0, Color(1, 0.5, 0.2))
	_check(main.flames.size() == 1, "Kindled: a foe your fire kills leaves burning ground")
	main.flames = []
	var cb = p.bonds["throat"]
	cb.select(0)
	cb.essence = 999.0
	p.cast_part = ""
	p._try_cast("throat")
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	_check(p.velocity.length() > 10.0, "Casting Stride: you can walk while a spell winds up")
	await _wait(0.8)
	k.queue_free()
	await _frames(1)

	# Flamewing.
	var near = await _spawn("knight", p.global_position + Vector2(40, 0))
	near.hp = 9999.0
	near.max_hp = 9999.0
	hp0 = near.hp
	_cast("heart", "heat_aura")
	var es0: float = p.bonds["heart"].essence
	await _wait(1.1)
	_check(p.aura_part == "heart" and near.hp < hp0 and p.bonds["heart"].essence < es0, "Heat Aura burns foes near you and drains its mark")
	_check(p.aura_heat > 0.0, "...and builds heat")
	hp0 = near.hp
	_cast("heart", "wingburst")
	_check(near.hp < hp0 and p.aura_heat == 0.0, "Wingburst releases the heat as burning wings")
	p.hp = 50.0
	_cast("heart", "warmth")
	p.bonds["heart"].essence = 999.0
	await _wait(1.0)
	_check(p.hp > 50.0, "Warmth: your aura restores your health")
	_cast("heart", "firebird_form")
	var hb = p.bonds["heart"]
	for i in hb.spells().size():
		if hb.spells()[i]["type"] == "wingburst":
			hb.select(i)
	hb.essence = 0.0
	hb.burned = false
	p.cast_part = "heart"
	p._release_cast()
	_check(p.firebird_t > 0.0 and not hb.burned, "Firebird Form: Wingburst costs nothing")
	_cast("heart", "heat_aura")
	_check(p.aura_part == "", "casting Heat Aura again turns it off")
	near.queue_free()
	p.hp = p.MAX_HP
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0}]
	await _wait(0.7)
	_check(p.hp == p.MAX_HP, "Fireproof: burning floor doesn't hurt you")
	main.flames = []
	p.sta = p.MAX_STA
	await _frames(1)
	Input.action_press("jump")
	await _wait(0.6)
	var gliding: bool = p.in_air()
	Input.action_release("jump")
	_check(gliding, "Phoenix Glide: holding jump keeps you in the air longer")
	await _wait(0.5)

	# Rekindler.
	p.hp = p.MAX_HP * 0.3
	_check(p._stubborn(), "Stubborn Heart: below a third of your health")
	p.hp = p.MAX_HP
	var dummy = await _spawn("knight", p.global_position + Vector2(30, 0))
	dummy.hp = 9999.0
	dummy.max_hp = 9999.0
	_cast("back", "rekindle")
	await _wait(1.2)
	_check(p.hp < p.MAX_HP, "Rekindle: you burn")
	var low: float = p.hp
	p._strike(dummy, 1.0, Vector2.RIGHT, 0.0, false)
	p.rekindle_t = 0.01
	await _wait(0.4)
	_check(p.hp > low, "...then regain more than you lost if you kept fighting")
	p.hp = 5.0
	_cast("back", "desperation")
	var hp_d: float = dummy.hp
	p.attack_cd = 0.0
	p.combo = 0
	p.combo_t = 0.0
	p._melee()
	var low_hit: float = hp_d - dummy.hp
	p.hp = p.MAX_HP
	hp_d = dummy.hp
	p.attack_cd = 0.0
	p.combo = 0
	p.combo_t = 0.0
	p._melee()
	_check(low_hit > (hp_d - dummy.hp) * 1.5, "Desperation: the lower your health, the harder you strike")
	p.desperate_t = 0.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.ember_used = true
	_cast("back", "pyre_oath")
	hp_d = dummy.hp
	p.receive_attack(9999.0, null)
	_check(not p.dead and p.hp == 1.0 and dummy.hp < hp_d, "Pyre Oath: a killing blow makes you explode instead")
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	_cast("back", "phoenix_heart")
	p.receive_attack(9999.0, null)
	_check(not p.dead and p.hp >= 1.0, "Phoenix Heart: you can't drop below 1 health")
	p.phoenix_t = 0.0
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.ember_used = false
	p.receive_attack(9999.0, null)
	_check(not p.dead and p.ember_t > 0.0, "Last Ember: a killing blow leaves you burning at 1 health")
	p._strike(dummy, 1.0, Vector2.RIGHT, 0.0, false)
	await _wait(3.2)
	_check(not p.dead, "...and landing a hit keeps you standing")
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	_check(p.dead, "...but only once per floor")
	dummy.queue_free()


## A killing blow to the climber (no dodge, no parry).
func _kill_blow(p) -> void:
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.receive_attack(9999.0, null)


## The Proving: floor 6 of every tower (proving.gd).
func _proving_tests() -> void:
	print("the Proving")
	await _fresh_main()
	main.grant_test_bonds()
	var pv = main.proving
	var p = main.player
	var prof = main.profile
	var G = main.Gear
	var TW: Dictionary = main.Towers.TOWERS
	for e in main.enemies():
		e.queue_free()
	_check(not pv.enabled, "tests keep floor 6 a planned floor unless they ask for the Proving")
	pv.enabled = true
	_check(prof.FIRST_CLIMB_FLOORS < main.Towers.PROVING["floor"], "the bondless first climb ends below the Proving")
	main.first_climb = true
	main._start_floor(6)
	_check(not pv.on and not main.floor_plan.get("proving", false), "floor 6 on the first climb is never the Proving")
	main.first_climb = false
	# Every tower: the fixed layout, its gauntlet, and a way through it by timing.
	var ok_layout := true
	var ok_cross := true
	var bad: Array = []
	for tid in main.Towers.ORDER:
		main.tower = tid
		main._start_floor(6)
		await _frames(1)
		var styles: Array = main.door_view.list.map(func(d): return d["style"])
		var ok: bool = pv.on and main.room_info.size() == pv.LAYOUT.size() and main.enemies().is_empty() and main.ward and not main.stair_open \
			and main.room_themes[pv.rooms["gauntlet"]] == TW[tid]["gauntlet"] and main.traps.is_empty() \
			and ["proving", "lethal", "crown", "shade"].all(func(s): return s in styles)
		pv.choose("ordinary")
		var gi: int = pv.rooms["gauntlet"]
		ok = ok and main.traps.size() >= 2 and main.traps.all(func(tr): return int(tr.get("room", -1)) == gi)
		if not ok:
			bad.append(tid)
		ok_layout = ok_layout and ok
		ok_cross = ok_cross and _trap_free_route(main.Traps.hard_tiles(main.traps), [[main.stair_pos], [pv.prize["pos"]]])
	_check(ok_layout, "floor 6 is the Proving's own layout in every tower: a sealed stair, two doors and the tower's own gauntlet (bad: %s)" % [bad])
	_check(ok_cross, "every gauntlet can be crossed by timing: no tile on the way is never safe")
	main.dev_floor(6)
	_check(pv.on, "the dev tools' floor 6 is the Proving")

	print("losing the Proving")
	main.tower = "kraken"
	main._start_floor(6)
	await _frames(1)
	pv.choose("ordinary")
	main.run_essence = {"water": 30.0, "air": 10.0}
	p.hp = 20.0
	_kill_blow(p)
	_check(not p.dead and pv.casting and p.hp >= 1.0, "a killing blow in the Proving doesn't kill: the tower takes your measure")
	pv.cast_down()
	_check(main.floor_num == 5 and not pv.on and not main.floor_plan.get("proving", false) and not p.dead, "...and casts you down to a fresh floor 5")
	_check(is_equal_approx(float(main.run_essence.get("water", 0.0)), 15.0) and is_equal_approx(float(main.run_essence.get("air", 0.0)), 5.0), "...keeping half your unbanked essence")
	_check(p.wound > 0.0 and is_equal_approx(p.max_health(), p.max_hp * (1.0 - pv.CAST_DOWN["wound"])) and p.hp <= p.max_health(), "...with a lingering wound: less max health")
	_check(main.menu._climber_line().contains(pv.TEXT["wound_tag"]), "the climber screen shows the wound")
	main._arrive()
	_check(main.floor_num == 6 and pv.on and p.wound > 0.0, "the wound lingers back up on floor 6")
	main._arrive()
	_check(main.floor_num == 7 and p.wound == 0.0 and pv.wound_text() == "" and is_equal_approx(p.max_health(), p.max_hp), "...and closes on reaching floor 7")
	await _until(func(): return not main.climbing and main.fade <= 0.0, 5.0)

	print("winning the Proving")
	var tid := "gryphon"
	var tw: Dictionary = TW[tid]
	main.tower = tid
	prof.provings = {}
	main._start_floor(6)
	await _frames(1)
	var ld: Dictionary = main.door_view.list.filter(func(d): return d["lock"] in ["lethal", "lethal_sealed"])[0]
	_check(ld["lock"] == "lethal_sealed" and not pv.lethal_open(), "the Lethal door stays sealed until the Proving is won in this tower")
	main.door_view._bump(ld)
	_check(pv.mode == "" and ld["lock"] == "lethal_sealed", "...bumping it only says so")
	var od: Dictionary = main.door_view.list.filter(func(d): return d["lock"] == "proving")[0]
	p.global_position = od["rect"].get_center() + Vector2(0, 40)
	await _until(func(): return pv.mode != "", 3.0)
	_check(pv.mode == "ordinary" and pv.tier == 0 and od["open"] and ld["lock"] == "proving_shut", "walking up to the Proving's door takes it; the other door bars")
	main.traps = []
	var rect := func(st: String) -> Rect2: return main.room_info[pv.rooms[st]]["rect"]
	p.global_position = rect.call("gauntlet").get_center()
	await _until(func(): return pv.sealed.has("gauntlet"), 3.0)
	var gate: Array = main.floor_plan["gauntlet_gates"][0]
	_check(pv.sealed.has("gauntlet") and main.is_solid(main.Traps.centre(gate[0])), "the gauntlet shuts behind you")
	for d in main.door_view.list:
		if d["style"] in ["crown", "shade"]:
			main.door_view.open_door(d, true)
	p.global_position = rect.call("sentinel").get_center()
	await _until(func(): return pv.sentinel != null, 3.0)
	var s = pv.sentinel
	var adds: Array = pv.mobs.slice(1)
	_check(s != null and s.champion and s.kind == tw["sentinel"] and tw["weights"].has(s.kind), "the sentinel is a champion of the tower's own (%s)" % (s.kind if s != null else "none"))
	_check(adds.size() == int(pv.TIERS[0]["adds"]) and adds.all(func(e): return e.kind == tw["sentinel_adds"]) and not main.door_view.lock_status().is_empty(), "...with its adds, behind shut doors")
	for e in main.enemies():
		e.set_physics_process(false)
	var crystals0: float = prof.crystal_total(tw["essence"])
	for e in pv.mobs:
		_slay(e)
	await _until(func(): return pv.sealed.has("sentinel_done"), 3.0)
	_check(main.door_view.lock_status().is_empty() and prof.crystal_total(tw["essence"]) > crystals0, "its fall opens the doors and leaves an essence crystal")
	p.global_position = rect.call("shadow").get_center()
	await _until(func(): return pv.shadow != null, 3.0)
	var sh = pv.shadow
	var full: float = main.EnemyScript.TYPES[tw["beast_kind"]]["hp"] * main.Floors.toughness(main.Towers.SUMMIT).x
	_check(sh != null and sh.kind == tw["beast_kind"] and sh.shade and sh.is_boss() and absf(sh.max_hp - full * float(pv.TIERS[0]["shadow_hp"])) < 1.0 and sh.max_hp < full * 0.5,
		"the shadow is the tower's beast at reduced health (%d of %d)" % [int(sh.max_hp) if sh != null else 0, int(full)])
	sh.set_physics_process(false)
	var beasts0: int = prof.count("beasts")
	_slay(sh)
	await _until(func(): return pv.stage == "won", 3.0)
	var prize_door: Dictionary = main.door_view.list.filter(func(d): return d["room"] == pv.rooms["prize"])[0]
	_check(prof.proving_wins(tid) == 1 and prof.count("beasts") == beasts0, "the shadow's fall wins the Proving (not a beast slain), and the win is recorded")
	_check(main.stair_open and not main.ward and prize_door["lock"] == "" and prize_door["open"], "...the reliquary and the stair open")
	p.global_position = pv.prize["pos"]
	await _until(func(): return main.camp_choosing, 3.0)
	var choices: Array = main.camp.get("choices", [])
	_check(choices.size() == 3 and choices.all(func(c): return String(c).begins_with("gear:") and G.slot_of(String(c).substr(5)) in ["ring", "amulet"] \
		and G.rarity_rank(G.rarity(G.rec(String(c).substr(5)))) >= G.rarity_rank("rare")), "the prize: a choice of three Rare relics, rings and amulets")
	var pick: Dictionary = G.rec(String(choices[0]).substr(5))
	main.choose_camp(0)
	_check(not main.camp_choosing and (p.gear.values() + p.pack).any(func(g): return G.same(g, pick)), "taking one gives it to you")
	# A recall scroll still works in the Proving.
	main.read_recall()
	_check(main.victory.get("recall", false), "a recall scroll can be read in the Proving")
	main.victory = {}
	p.set_physics_process(true)

	main._start_floor(6)
	_check(not pv.on, "once won, a fall back to floor 6 finds an ordinary floor (one Proving a climb)")
	print("a later climb: harder, and the Lethal Proving")
	pv.won_climb = false  # (a new climb)
	main._start_floor(6)
	await _frames(1)
	ld = main.door_view.list.filter(func(d): return d["lock"] in ["lethal", "lethal_sealed"])[0]
	_check(ld["lock"] == "lethal" and pv.ordinary_tier() == 1, "after a win, the Lethal door opens and the Proving rises a tier")
	var t0: Dictionary = pv.TIERS[0]
	var t1: Dictionary = pv.TIERS[1]
	_check(t1["trap_floor"] > t0["trap_floor"] and t1["sentinel_hp"] > t0["sentinel_hp"] and t1["shadow_hp"] > t0["shadow_hp"] and t1["rank"] > t0["rank"], "a higher tier: a faster gauntlet, a tougher sentinel, a stronger shadow, a better prize")
	main.door_view._bump(ld)
	_check(pv.mode == "", "one bump of the Lethal door only asks")
	var lean := func() -> bool:
		main.door_view._bump(ld)
		return pv.mode != ""
	await _until(lean, 4.0)
	_check(pv.mode == "lethal" and pv.tier == 1 + pv.LETHAL_STEP, "leaning on it takes the Lethal Proving, a tier above")
	p.hp = 20.0
	_kill_blow(p)
	_check(p.dead and not pv.casting and main.floor_num == 6, "a death in the Lethal Proving is a real death")

	print("saving Provings won")
	var path := "user://smoke_proving_test.cfg"
	prof.provings = {"kraken": 2, "gryphon": 1}
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.proving_wins("kraken") == 2 and again.proving_wins("gryphon") == 1 and again.proving_wins("wyvern") == 0, "Provings won are saved and load again")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.provings.is_empty(), "an old save loads with no Provings won")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH


func _chimera_bond_tests() -> void:
	print("the Chimera's bonds")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_mark("hand", "covenant", 5)
	_mark("heart", "grafter", 5)
	_mark("brow", "surgeon", 5)
	var ok := true
	for part in ["hand", "heart", "brow"]:
		ok = ok and p.bonds[part].spells().size() == 4
	_check(ok, "at step 5 each Chimera bond knows four spells")

	# Covenant.
	_cast("hand", "bind_and_call")
	_check(main.allies().size() == 2 and main.allies()[0].kind == "familiar", "Call with an empty pact book brings spirit familiars (two at step 3+)")
	for a in main.allies():
		a.queue_free()
	await _frames(2)
	var weak = await _spawn("knight", p.global_position + Vector2(100, 0))
	weak.hp = weak.max_hp * 0.2
	_cast("hand", "bind_and_call")
	await _frames(2)
	_check("knight" in main.profile.pacts and (not is_instance_valid(weak) or weak.dead), "Bind: a monster below a quarter of its health joins your pact book")
	_cast("hand", "bind_and_call")
	await _frames(1)
	_check(main.allies().size() == 2 and main.allies()[0].kind == "knight", "...and Call brings your bound creatures")
	_cast("hand", "bind_and_call")
	_check(main.allies().size() == 3, "never more than three creatures out at once")
	var foe = await _spawn("slime", p.global_position + Vector2(90, 0))
	foe.hp = 999.0
	foe.max_hp = 999.0
	_cast("hand", "command")
	_check(main.allies().all(func(a): return a.ally_target == foe), "Command sends every creature at the foe you aim at")
	await _wait(1.2)
	_check(foe.hp < 999.0, "...and they attack it")
	var near: Vector2 = main.allies()[0].global_position
	_cast("hand", "exchange")
	_check(p.global_position.distance_to(near) < 30.0, "Exchange swaps you with a creature")
	# Monsters fight your creatures too.
	var a0 = main.allies()[0]
	a0.global_position = foe.global_position + Vector2(30, 0)
	p.global_position = foe.global_position + Vector2(-300, 0)
	_check(foe._foe(p) == a0, "monsters turn on a creature that's closer than you")
	var hp_a: float = a0.hp
	a0.receive_attack(5.0, foe)
	_check(a0.hp < hp_a, "...and can hurt it")
	foe.queue_free()
	for a in main.allies():
		a.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	main.profile.pacts = ["knight", "slime", "archer"]
	_cast("hand", "grand_call")
	_check(main.allies().size() == 3 and p.bonds["hand"].essence == 0.0, "Grand Call: every creature in your book at once, draining the mark")
	_check(p.has_bond("covenant"), "(Pack Stride and Kinship come with the mark)")
	main._start_floor(main.floor_num)
	await _frames(2)
	_check(main.allies().is_empty(), "calls end on a new floor")
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	main.profile.pacts = []

	# Grafter.
	_check(main.add_graft("knight") and main.grafts.get("hand", "") == "knight", "a knight's graft binds to your hand")
	_check(not main.add_graft("smith"), "...and only one graft per body part")
	main.add_graft("bat")
	var dummy = await _spawn("knight", p.global_position + Vector2(30, 0))
	dummy.hp = 9999.0
	dummy.max_hp = 9999.0
	var hp0: float = dummy.hp
	p.combo = 0
	p.combo_t = 0.0
	p.attack_cd = 0.0
	p._melee()
	var with_graft: float = hp0 - dummy.hp
	main.grafts.erase("hand")
	hp0 = dummy.hp
	p.combo = 0
	p.combo_t = 0.0
	p.attack_cd = 0.0
	p._melee()
	var without: float = hp0 - dummy.hp
	main.grafts["hand"] = "knight"
	_check(with_graft > without * 1.15, "Adaptive Flesh: a hand graft strengthens your strikes (%.1f vs %.1f)" % [with_graft, without])
	main.graft_drops = [{"pos": p.global_position, "kind": "slime", "t": 5.0}]
	main._update_grafts(0.016)
	_check(main.grafts.has("heart") and main.graft_drops.is_empty(), "walking over a graft binds it")
	hp0 = dummy.hp
	_cast("heart", "graft_burst")
	_check(hp0 - dummy.hp >= 14.0 + 15.0, "Graft Burst hits harder for every graft (%.0f)" % (hp0 - dummy.hp))
	p.hp = 50.0
	_cast("heart", "mimic")  # newest graft: the slime's heart, which mends
	_check(p.hp > 50.0, "Mimic uses your newest graft's power")
	p.bonds["heart"].burned = true
	_cast("heart", "shed")
	_check(not main.grafts.has("heart") and not p.bonds["heart"].burned, "Shed casts off a graft and heals its body part's burn")
	_cast("heart", "chimera_form")
	_check(p.chimera_t > 0.0 and p.graft("hand") == 2.0, "Chimera Form doubles every graft's power")
	p.chimera_t = 0.0
	dummy.queue_free()
	await _frames(1)

	# Surgeon.
	var t = await _spawn("knight", p.global_position + Vector2(60, 0))
	t.hp = 9999.0
	t.max_hp = 9999.0
	_check(t.WEAKNESS.has("knight"), "Diagnosis knows what each foe is weak to")
	_cast("brow", "sever")
	_check(t.cripple_t > 0.0, "Sever cripples a foe")
	_cast("brow", "sever")
	_check(t.disarm_t > 0.0 and not main.request_attack(t), "...and at step 3+ a crippled foe is disarmed: it can't attack")
	t.cripple_t = 0.0
	t.disarm_t = 0.0
	p.hp = 40.0
	p.poison_t = 3.0
	_cast("brow", "mend")
	_check(p.hp > 40.0 + 40.0 and p.poison_t <= 0.0, "Mend heals (more with Steady Hands) and cures poison")
	p.bonds["heart"].burned = true
	p.poison_t = 3.0
	_cast("brow", "transfer")
	_check(not p.bonds["heart"].burned and p.poison_t <= 0.0 and t.venom > 0, "Transfer moves your burns and poison onto a foe")
	t.hp = t.max_hp * 0.6
	_cast("brow", "amputate")
	_check(t.disarm_t <= 0.0, "Amputate needs a foe below half health")
	t.hp = t.max_hp * 0.4
	_cast("brow", "amputate")
	_check(t.cripple_t > 1000.0 and t.disarm_t > 1000.0, "...then cripples and disarms it for the rest of the fight")
	t.queue_free()


func _menu_tests() -> void:
	print("menus and the dev tool")
	await _fresh_main()
	var p = main.player
	var menu = main.menu
	_check(menu != null and not main.menu_open(), "tests skip the title screen")
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	_check(main.menu_open() and menu.page == "pause" and paused, "Esc opens the pause menu and pauses the game")
	await _frames(3)
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	_check(not main.menu_open() and not paused, "Esc again resumes")
	# Every page builds without errors.
	for pg in ["title", "pause", "settings", "controls", "confirm_new", "dev", "climber", "inventory"]:
		menu.open(pg)
		await _frames(1)
	_check(menu.page == "inventory" and paused, "every menu page opens")
	for t in menu.CLIMBER_TABS:
		menu.climber_tab = t[0]
		menu.open("climber")
		await _frames(1)
	menu.climber_tab = "marks"
	_check(menu.page == "climber", "every climber tab opens")
	menu.open("dev")
	await _frames(1)
	# Dev tool: marks at any step, on any part.
	main.dev_set_mark("heart", "deepcaller", 4)
	_check(p.bonds.has("heart") and p.bonds["heart"].id == "deepcaller" and p.bonds["heart"].step == 4, "the dev tool puts a bond on a part at a step")
	_check(not main.first_climb and main.profile.regarded, "...which ends the bondless first climb")
	menu._cycle_bond("hand", 1)
	_check(p.bonds.has("hand"), "cycling a part's bond gives it one")
	main.dev_set_mark("hand", "", 1)
	_check(not p.bonds.has("hand"), "...and a mark can be removed")
	var n0: int = main.enemies().size()
	main.dev_spawn("shellback")
	_check(main.enemies().size() == n0 + 1, "the dev tool spawns monsters")
	main.dev_floor(main.Towers.SUMMIT)
	await _frames(2)
	_check(main.floor_num == 12 and main.enemies().size() == 1 and main.enemies()[0].kind == "kraken", "...jumps to the beast")
	main.dev_tower("gryphon")
	await _frames(2)
	_check(main.tower == "gryphon" and main.floor_num == 1, "...and moves to another tower")
	# Buttons on the dev page work.
	var heal: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Heal":
			heal = b
	p.hp = 10.0
	if heal != null:
		heal.pressed.emit()
	_check(p.hp == p.max_hp, "the Heal button heals")
	main.dev_no_death = true
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(9999.0, null)
	_check(not p.dead and p.hp >= 1.0, "no dying: a killing blow leaves you at 1")
	main.dev_no_death = false
	# Phones: menu buttons answer taps (touches aren't turned into clicks).
	menu.open("pause")
	await _frames(2)
	var resume: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Resume":
			resume = b
	var at: Vector2 = resume.get_global_rect().get_center()
	_touch(0, at, true)
	await _frames(2)
	_touch(0, at, false)
	await _frames(2)
	_check(not main.menu_open() and not paused, "tapping Resume on a phone closes the menu")
	main.touch._set_active(false)
	p.touch_aim = false
	menu.open("dev")
	await _frames(1)
	# Settings.
	menu._set_setting("sounds", 0.0)
	_check(main.audio.sound_level == 0.0, "the sounds slider sets the volume")
	menu._set_setting("sounds", 1.0)
	menu.close()
	_check(not paused and not main.menu_open(), "closing the menu resumes")


## A button on the menu with this text, or null.
func _menu_button(text: String) -> Button:
	for b in main.menu.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _tap_at(pos: Vector2) -> void:
	_touch(0, pos, true)
	await _frames(2)
	_touch(0, pos, false)
	await _frames(2)


func _title_tests() -> void:
	print("the title screen")
	await _fresh_main()
	var menu = main.menu
	# A fresh start: the title shows over a climb waiting for its tower.
	main.choosing_tower = true
	menu.open("title")
	await _frames(3)
	_check(menu.page == "title" and menu.backdrop != null and menu.backdrop.visible and menu.backdrop.get_script() == load("res://scripts/title.gd"), "the title page builds its drawn backdrop")
	_check(menu.backdrop.get_child_count() == 3 and menu.backdrop.motes.size() <= 40, "...in three layers with a few dozen motes")
	_check(main.title_showing() and main.menu_open(), "the HUD and touch controls hide while the title shows")
	var first := _menu_button("Begin your first climb")
	_check(first != null and _menu_button("Start over") == null, "a new climber is offered the first climb (and nothing to lose)")
	_check(_menu_button("Climber") == null and _menu_button("Settings") != null and _menu_button("Dev tools") != null, "the title has Settings and Dev tools (the climber screen is in the pause menu)")
	_check(first != null and first.has_focus(), "keyboard: the first button has focus")
	var vis := root.get_visible_rect()
	var inside := true
	for b in menu.find_children("*", "Button", true, false):
		inside = inside and vis.encloses(b.get_global_rect())
	_check(inside, "every title button is on screen")
	# Esc does nothing on the title.
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	await _frames(2)
	_check(menu.page == "title" and paused, "Esc does nothing on the title")
	# Pages open over the title's backdrop; Back returns.
	_menu_button("Dev tools").pressed.emit()
	await _frames(2)
	_check(menu.page == "dev" and menu.backdrop.visible and not menu.backdrop.show_name, "Dev tools opens over the title backdrop")
	_menu_button("Back").pressed.emit()
	await _frames(2)
	_check(menu.page == "title" and menu.backdrop.show_name, "...and Back returns to the title")
	# Phones: a tap on a title button works (and switches to the phone layout).
	await _tap_at(_menu_button("Settings").get_global_rect().get_center())
	_check(menu.page == "settings" and menu.backdrop.visible, "tapping Settings on a phone opens it over the title")
	_check(main.touch.active and is_equal_approx(root.content_scale_factor, 1.5), "...and the phone layout is on")
	menu.scroll.ensure_control_visible(_menu_button("Back"))  # (a long page scrolls to it, as a finger would)
	await _frames(2)
	await _tap_at(_menu_button("Back").get_global_rect().get_center())
	_check(menu.page == "title", "tapping Back returns to the title")
	await _frames(2)
	vis = root.get_visible_rect()
	inside = true
	for b in menu.find_children("*", "Button", true, false):
		inside = inside and vis.encloses(b.get_global_rect())
	_check(inside, "every title button fits the phone layout")
	# The pause menu doesn't show the title's backdrop.
	menu.open("pause")
	await _frames(1)
	_check(not menu.backdrop.visible and not main.title_showing(), "the pause menu has no title backdrop")
	menu.open("title")
	await _frames(2)
	# Tapping Begin leaves the title for the tower choice.
	await _tap_at(_menu_button("Begin your first climb").get_global_rect().get_center())
	_check(not main.menu_open() and not paused and not main.title_showing(), "tapping Begin leaves the title")
	_check(main.choosing_tower and Engine.has_meta("sixfold_title_seen"), "...and shows the tower choice")
	Engine.remove_meta("sixfold_title_seen")
	main.touch._set_active(false)
	main.player.touch_aim = false
	# A climber with marks: Continue, a status line and Start over.
	main.grant_test_bonds()
	menu.open("title")
	await _frames(2)
	var cont := _menu_button("Continue")
	_check(cont != null and _menu_button("Start over") != null, "a marked climber sees Continue and Start over")
	var status := false
	for l in menu.find_children("*", "Label", true, false):
		if l.text.begins_with("Marks: ") and "Best floor" in l.text:
			status = true
	_check(status, "the title shows marks carried and best floor")
	_menu_button("Start over").pressed.emit()
	await _frames(2)
	_check(menu.page == "confirm_new" and menu.backdrop.visible, "Start over asks over the title backdrop")
	_menu_button("Cancel").pressed.emit()
	await _frames(2)
	_check(menu.page == "title", "...and Cancel returns to the title")
	_menu_button("Continue").pressed.emit()
	await _frames(2)
	_check(not main.menu_open() and main.choosing_tower, "Continue leaves the title for the tower choice")
	Engine.remove_meta("sixfold_title_seen")
	main.choose_tower("kraken")
	await _frames(2)


func _wyvern_tower_tests() -> void:
	print("the Wyvern's tower")
	await _fresh_main()
	var p = main.player
	main.dev_tower("wyvern")
	await _frames(2)
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var seen := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["wyvern"])["monsters"]:
			seen[m[0]] = true
	_check(seen.has("cinder") and seen.has("smith"), "the Wyvern's tower has cinders and smiths")
	# Fire essence: cinders drop it.
	var c = await _spawn("cinder", p.global_position + Vector2(200, 0))
	var fire0: float = main.run_essence.get("fire", 0.0)
	_slay(c)
	await _frames(2)
	_check(main.run_essence.get("fire", 0.0) > fire0, "cinders drop Fire essence")
	# Smith: its hammer can be parried, and it leaves the floor burning.
	var sm = await _spawn("smith", p.global_position + Vector2(200, 0))
	sm.hp = 999.0
	var r1: Dictionary = await _parry_test(sm, 0.0, "wind_hammer", 58.0)
	_check(r1["glinted"] and r1["parried"] and not r1["hurt"], "a smith's hammer can be parried on the glint %s" % str(r1))
	_check(main.flames.size() >= 1, "...and leaves the floor burning")
	# Standing in fire burns.
	p.hp = p.MAX_HP
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0}]
	await _wait(0.8)
	_check(p.hp < p.MAX_HP, "standing in fire burns")
	main.flames = []
	sm.queue_free()
	await _frames(2)

	print("the Wyvern")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "wyvern", "floor %d, the summit of the Wyvern's tower, is the Wyvern" % main.Towers.SUMMIT)
	var w = foes[0]
	w.set_physics_process(false)
	# Its breath can't be parried.
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.knock = Vector2.ZERO
	p.global_position = w.global_position + Vector2(140, 0)
	w.stun = 0.0
	main.attackers.clear()
	main.request_attack(w)
	w._begin_wind("wind_breath", 0.2)
	w.set_physics_process(true)
	await _wait(0.12)
	p._try_parry()
	await _wait(0.3)
	w.set_physics_process(false)
	_check(p.hp < p.MAX_HP and w.stun <= 0.0, "its fire breath can't be parried")
	_check(main.flames.size() >= 3, "...and sets the floor alight")
	main.flames = []
	# Halfway down it calls cinders.
	w.take_hit(w.hp - w.max_hp * 0.45, Vector2.ZERO)
	w.state = "recover"
	w.state_t = 5.0
	w.set_physics_process(true)
	await _wait(0.2)
	_check(main.enemies().filter(func(e): return e.kind == "cinder").size() == 2, "below half health it calls two cinders")
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	p.hp = p.MAX_HP
	p.dead = false
	p.set_physics_process(true)
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "beating the Wyvern completes the climb")
	await _wait(2.8)
	main.victory = {}


func _manticore_tower_tests() -> void:
	print("the Manticore's tower")
	await _fresh_main()
	var p = main.player
	main.dev_tower("manticore")
	await _frames(2)
	_check(main.tower == "manticore" and main.tower_data()["essence"] == "stone", "the Manticore's tower: Stone essence")
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var seen := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["manticore"])["monsters"]:
			seen[m[0]] = true
	_check(seen.has("scorpling") and seen.has("ram"), "the Manticore's tower has scorplings and rams")
	# Scorpling: its sting can be parried; a sting that lands poisons.
	var sc = await _spawn("scorpling", p.global_position + Vector2(200, 0))
	sc.hp = 999.0
	var r1: Dictionary = await _parry_test(sc, 0.0, "wind_sting", 45.0)
	_check(r1["glinted"] and r1["parried"] and not r1["hurt"], "a scorpling's sting can be parried on the glint %s" % str(r1))
	_check(p.poison_t <= 0.0, "...and a parried sting doesn't poison")
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	sc._sting(p, 5.0)
	_check(p.poison_t > 0.0, "a sting that lands poisons you")
	var hp1: float = p.hp
	await _wait(1.2)
	_check(p.hp < hp1, "...and poison hurts over time")
	p.poison_t = 0.0
	sc.queue_free()
	await _frames(1)
	# Ram: the charge can be parried; charging into a wall stuns it.
	var ram = await _spawn("ram", p.global_position + Vector2(200, 0))
	ram.hp = 999.0
	var r2: Dictionary = await _parry_test(ram, 0.0, "wind_charge", 150.0)
	_check(r2["glinted"] and r2["parried"] and not r2["hurt"], "a ram's charge can be parried on the glint %s" % str(r2))
	ram.stun = 0.0
	ram.global_position = Vector2(main.room.position.x + 60.0, 400.0)
	ram.lunge_dir = Vector2.LEFT
	ram.state = "charge"
	ram.state_t = 0.6
	p.global_position = Vector2(main.room.position.x + 400.0, 200.0)
	ram.set_physics_process(true)
	await _wait(0.3)
	ram.set_physics_process(false)
	_check(ram.stun > 0.0, "a ram that charges into a wall is stunned")
	ram.queue_free()
	await _frames(1)

	print("the Manticore")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "manticore", "floor %d, the summit of the Manticore's tower, is the Manticore" % main.Towers.SUMMIT)
	var m = foes[0]
	m.set_physics_process(false)
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.knock = Vector2.ZERO
	p.global_position = m.global_position + Vector2(90, 0)
	main.attackers.clear()
	main.request_attack(m)
	m._begin_wind("wind_roar", 0.2)
	m.set_physics_process(true)
	await _wait(0.12)
	p._try_parry()
	await _wait(0.3)
	m.set_physics_process(false)
	_check(p.hp < p.MAX_HP and m.stun <= 0.0, "its roar can't be parried")
	# Its tail spikes poison.
	m._begin_wind("wind_spikes", 0.01)
	m.lunge_dir = Vector2.RIGHT
	m.glinted = true
	m._manticore(0.02, Vector2.RIGHT, 90.0, p)
	var spikes: Array = main.get_children().filter(func(c): return "return_to" in c and c.style == "spike")
	_check(spikes.size() == 3 and spikes[0].poison > 0.0, "its tail spikes carry poison")
	for s in spikes:
		s.queue_free()
	m.take_hit(m.hp - m.max_hp * 0.45, Vector2.ZERO)
	m.state = "recover"
	m.state_t = 5.0
	m.set_physics_process(true)
	await _wait(0.2)
	_check(main.enemies().filter(func(e): return e.kind == "scorpling").size() == 2, "below half health it calls two scorplings")
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	p.hp = p.MAX_HP
	p.dead = false
	p.poison_t = 0.0
	p.set_physics_process(true)
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "beating the Manticore completes the climb")
	await _wait(2.8)
	main.victory = {}


func _firebird_tower_tests() -> void:
	print("the Firebird's tower")
	await _fresh_main()
	var p = main.player
	main.dev_tower("firebird")
	await _frames(2)
	main.dev_floor(3)
	await _frames(2)
	_check(main.tower == "firebird" and main.chasms.size() >= 1, "the Firebird's tower has chasms (%d)" % main.chasms.size())
	main.dev_floor(1)  # back to the open first floor for the tests below
	await _frames(2)
	main.set_chasms([])
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var seen := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["firebird"])["monsters"]:
			seen[m[0]] = true
	_check(seen.has("wisp") and seen.has("bloomcap"), "the Firebird's tower has wisps and bloomcaps")
	p.global_position = Vector2(500, 400)
	var w = await _spawn("wisp", p.global_position + Vector2(140, 0))
	w.hp = 999.0
	var r1: Dictionary = await _parry_test(w, 0.0, "wind", 140.0)
	_check(r1["glinted"] and r1["parried"] and not r1["hurt"], "a wisp's dart can be parried on the glint %s" % str(r1))
	w.queue_free()
	main.flames = []
	await _settle()
	# Bloomcap: its spores can't be parried, but you can step out (or jump).
	var bc = await _spawn("bloomcap", p.global_position + Vector2(220, 0))
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	main.attackers.clear()
	main.request_attack(bc)
	bc._begin_wind("wind_lob", 0.3)
	bc.set_physics_process(true)
	await _wait(0.15)
	p._try_parry()
	await _wait(0.3)
	_check(p.hp < p.MAX_HP and main.flames.size() >= 1, "a bloomcap's spores can't be parried, and leave the floor burning")
	main.flames = []
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	main.attackers.clear()
	main.request_attack(bc)
	bc._begin_wind("wind_lob", 0.6)
	await _wait(0.45)
	p.global_position += Vector2(0, 120)  # step out of the circle after it locks on
	await _wait(0.4)
	_check(p.hp == p.MAX_HP, "...but stepping out of the circle in time avoids them")
	bc.set_physics_process(false)
	bc.queue_free()
	main.flames = []
	await _frames(1)

	print("the Firebird")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "firebird" and main.chasms.is_empty(), "the summit of the Firebird's tower is the Firebird, in an open hall")
	var fb = foes[0]
	fb.set_physics_process(false)
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.knock = Vector2.ZERO
	p.global_position = fb.global_position + Vector2(150, 0)
	main.attackers.clear()
	main.request_attack(fb)
	fb.storm_spots = [p.global_position]
	fb._begin_wind("wind_storm", 0.2)
	fb.set_physics_process(true)
	await _wait(0.12)
	p._try_parry()
	await _wait(0.3)
	fb.set_physics_process(false)
	_check(p.hp < p.MAX_HP and fb.stun <= 0.0, "its firestorm can't be parried")
	main.flames = []
	# It rises once from its ashes.
	fb.take_hit(fb.hp + 10.0, Vector2.ZERO)
	_check(not fb.dead and fb.state == "ashes", "the first time it falls, it burns to ashes")
	var hp_ash: float = fb.hp
	fb.take_hit(50.0, Vector2.ZERO)
	_check(fb.hp == hp_ash, "...where it can't be hurt")
	fb.set_physics_process(true)
	await _wait(2.5)
	fb.set_physics_process(false)
	_check(fb.state != "ashes" and fb.hp >= fb.max_hp * 0.39, "...then it rises again at 40% health")
	_check(main.enemies().filter(func(e): return e.kind == "wisp").size() == 2, "below half health it calls two wisps")
	for e in main.enemies():
		if e != fb:
			_slay(e)
	fb.take_hit(fb.hp + 10.0, Vector2.ZERO)
	await _frames(3)
	_check(not is_instance_valid(fb) or fb.dead, "the second time, it stays down")
	p.hp = p.MAX_HP
	p.dead = false
	p.set_physics_process(true)
	main.flames = []
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "beating the Firebird completes the climb")
	await _wait(2.8)
	main.victory = {}


func _chimera_tower_tests() -> void:
	print("the Chimera's tower")
	await _fresh_main()
	var p = main.player
	main.dev_tower("chimera")
	await _frames(2)
	_check(main.tower_data()["essence"] == "blade" and main.Towers.ORDER.size() == 6, "the Chimera's tower: Blade essence, the sixth tower")
	var r0: Rect2 = main.hud.tower_card_rect(0, Vector2(1280, 720))
	var r5: Rect2 = main.hud.tower_card_rect(5, Vector2(1280, 720))
	_check(r5.position.y > r0.end.y, "six tower cards sit in two rows")
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var seen := {}
	for n in 30:
		for m in main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS["chimera"])["monsters"]:
			seen[m[0]] = true
	_check(seen.has("thornhound") and seen.has("mongrel"), "the Chimera's tower has thornhounds and mongrels")
	p.global_position = Vector2(500, 400)
	var h = await _spawn("thornhound", p.global_position + Vector2(100, 0))
	h.hp = 999.0
	var r1: Dictionary = await _parry_test(h, 0.0, "wind", 100.0)
	_check(r1["glinted"] and r1["parried"] and not r1["hurt"], "a thornhound's leap can be parried on the glint %s" % str(r1))
	h.queue_free()
	await _frames(1)
	var m = await _spawn("mongrel", p.global_position + Vector2(100, 0))
	m.hp = 999.0
	var r2: Dictionary = await _parry_test(m, 0.0, "wind_bite", 55.0)
	_check(r2["glinted"] and r2["parried"] and not r2["hurt"], "a mongrel's bite can be parried on the glint %s" % str(r2))
	m.queue_free()
	await _frames(1)

	print("the Chimera")
	main.profile.regarded = true
	main.first_climb = false
	main._start_floor(main.Towers.SUMMIT)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "chimera", "floor %d, the summit of the Chimera's tower, is the Chimera" % main.Towers.SUMMIT)
	var c = foes[0]
	c.set_physics_process(false)
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.knock = Vector2.ZERO
	p.global_position = c.global_position + Vector2(140, 0)
	main.attackers.clear()
	main.request_attack(c)
	c._begin_wind("wind_breath", 0.2)
	c.set_physics_process(true)
	await _wait(0.12)
	p._try_parry()
	await _wait(0.3)
	c.set_physics_process(false)
	_check(p.hp < p.MAX_HP and c.stun <= 0.0, "its lion's breath can't be parried")
	main.flames = []
	# The goat's charge stuns it against a wall.
	c.global_position = Vector2(main.room.position.x + 80.0, 400.0)
	c.lunge_dir = Vector2.LEFT
	c.swoop_speed = 480.0
	c.state = "charge"
	c.state_t = 0.6
	p.global_position = Vector2(main.room.position.x + 400.0, 250.0)
	c.set_physics_process(true)
	await _wait(0.3)
	c.set_physics_process(false)
	_check(c.stun > 0.0, "its goat's charge into a wall stuns it")
	c.stun = 0.0
	c.take_hit(c.hp - c.max_hp * 0.45, Vector2.ZERO)
	c.state = "recover"
	c.state_t = 5.0
	c.set_physics_process(true)
	await _wait(0.2)
	_check(main.enemies().filter(func(e): return e.kind == "thornhound").size() == 2, "below half health it calls two thornhounds")
	for e in main.enemies():
		_slay(e)
	await _frames(3)
	p.hp = p.MAX_HP
	p.dead = false
	p.poison_t = 0.0
	p.set_physics_process(true)
	main.flames = []
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.victory.is_empty(), "beating the Chimera completes the climb")
	await _wait(2.8)
	main.victory = {}


func _bugfix_tests() -> void:
	print("fixes from the bug hunt")
	await _fresh_main()
	var p = main.player
	# A fall on the first climb grants the faint mark at once (a restart keeps it).
	p.hp = 1.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	main.add_soak("hand", 5.0)
	p.receive_attack(999.0, null)
	_check(p.dead and main.profile.regarded and main.profile.bonds.size() == 1, "falling on the first climb saves the faint mark right away")
	await _fresh_main()
	p = main.player
	main.profile.regarded = true
	main.first_climb = false
	# Teleports and spawns never land inside the solid ground between rooms.
	main._start_floor(3)
	await _frames(1)
	var r0: Rect2 = main.layout_rooms[0]
	var from: Vector2 = r0.get_center()
	var into_rock: Vector2 = Vector2(main.room.position.x + 10.0, main.room.position.y + 10.0)
	if not main.is_solid(into_rock):
		into_rock = from + Vector2(r0.size.x, 0)
	var safe: Vector2 = main.walkable_point(from, into_rock)
	_check(not main.is_solid(safe), "a teleport toward solid ground stops on open floor")
	p.global_position = from
	var a = main.spawn_ally("familiar", into_rock, 1, 5.0)
	_check(not main.is_solid(a.global_position), "a called creature never appears inside a wall")
	# Last Ember doesn't follow you up the stair; nor do grafts on the floor.
	p.ember_t = 2.0
	main.graft_drops = [{"pos": from, "kind": "slime", "t": 10.0}]
	main._start_floor(2)
	await _frames(1)
	_check(p.ember_t == 0.0 and main.graft_drops.is_empty(), "a new floor clears Last Ember and grafts left behind")
	# Nothing can hit you while you take the stair.
	main._climb()
	_check(p.iframes >= 1.5, "taking the stair makes you untouchable for the fade")
	await _wait(1.5)
	# Phones: lifting a thumb during a big screen releases everything.
	Input.action_press("move_right")
	main.choosing_tower = true
	main.touch._set_active(true)
	_touch(0, Vector2(100, 100), true)
	await _frames(1)
	_touch(0, Vector2(100, 100), false)
	await _frames(1)
	_check(not Input.is_action_pressed("move_right"), "a held direction is released when a big screen takes the touch")
	main.choosing_tower = false
	main.touch._set_active(false)
	p.touch_aim = false


func _density_tests() -> void:
	print("essence density")
	await _fresh_main()
	var p = main.player
	var prof = main.profile
	_check(prof.attribute("air") == 0.0, "a new climber has no density")
	prof.bank({"air": 300.0, "stone": 100.0}, {"legs": 3.0, "hand": 1.0})
	_check(prof.density.get("air", 0.0) == 300.0, "banked essence becomes density, by type")
	_check(prof.part_density["legs"]["air"] > prof.part_density["hand"]["air"] * 2.5, "...settling in the body parts that earned it")
	var b: float = prof.attribute("air")
	_check(b > 0.0 and b < prof.ATTRIBUTE_CAP, "each type gives a small bonus (%.1f%%)" % (b * 100.0))
	prof.density["air"] = 1000000.0
	_check(prof.attribute("air") <= prof.ATTRIBUTE_CAP, "...that never passes the cap")
	prof.density["air"] = 600.0
	prof.density["blade"] = 600.0
	prof.density["stone"] = 600.0
	main._give_bonds()
	_check(p.attr_speed > 1.05 and p.attr_strength > 1.05 and p.max_hp > p.MAX_HP, "Air speeds you up, Blade strengthens strikes, Stone adds health")
	prof.density = {}
	prof.part_density = {}
	main._give_bonds()
	_check(p.max_hp == p.MAX_HP and p.attr_speed == 1.0, "(no density, no bonus)")


func _combat_feel_tests() -> void:
	print("combat feel")
	await _fresh_main()
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	# Mashing runs you out of stamina.
	p._equip("sword")
	p.sta = p.MAX_STA
	for i in 6:
		p.attack_cd = 0.0
		p._melee()
	_check(p.sta < 15.0, "six sword swings in a row leave you winded (%d stamina)" % int(p.sta))
	# After an attack, a monster is open: hits deal more.
	var k = await _spawn("knight", p.global_position + Vector2(40, 0))
	k.hp = 9999.0
	k.max_hp = 9999.0
	var hp0: float = k.hp
	k.take_hit(10.0, Vector2.ZERO)
	var plain: float = hp0 - k.hp
	k.glinted = true
	k._end_attack("recover", 1.0)
	_check(k.open_t > 0.0, "finishing an attack leaves a monster open")
	hp0 = k.hp
	k.take_hit(10.0, Vector2.ZERO)
	_check(hp0 - k.hp > plain * 1.5, "hits on an open monster deal more (%.0f vs %.0f)" % [hp0 - k.hp, plain])
	k.queue_free()


## The room is drawn in squares that are rebuilt (not piled up) on every
## floor, and climbing floor after floor leaves nothing behind.
func _performance_tests() -> void:
	print("performance")
	await _fresh_main()
	var rv = main.room_view
	await _frames(2)
	var squares: int = rv.chunk_items.size()
	_check(squares > 10, "the room is drawn in squares (%d)" % squares)
	rv.queue_redraw()
	await _frames(2)
	_check(rv.chunk_items.size() == squares, "redrawing the room replaces its squares")
	_check(rv.tint == rv.self_modulate, "the squares wear the tower's stone colour")
	main.dev_floor(1)
	await _frames(5)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for rep in 2:
		for f in [2, 3, 4]:
			main.dev_floor(f)
			await _frames(3)
	main.dev_floor(1)
	await _frames(5)
	var after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check(after <= nodes + 4, "six floors later nothing is left behind (%d nodes, was %d)" % [after, nodes])
	_check(rv.chunk_items.size() == squares, "floor 1's room has the same squares again")


func _lighting_tests() -> void:
	print("lighting: one darkness layer")
	await _fresh_main()
	for f in main.enemies():
		f.set_physics_process(false)
	var lt = main.lighting
	await _frames(3)
	var lights2d: Array = main.find_children("*", "PointLight2D", true, false)
	var mods: Array = main.find_children("*", "CanvasModulate", true, false)
	_check(lights2d.is_empty() and mods.is_empty(), "no 2D light nodes and no CanvasModulate: the darkness is one layer")
	_check(lt.material is ShaderMaterial and lt.z_index == 40, "the darkness layer is a single shader rect over the world")
	var layers: Array = main.find_children("*", "", true, false).filter(func(n): return n.get_script() == lt.get_script())
	_check(layers.size() == 1, "...and there's only one")
	_check(lt.on_screen >= 2 and lt.on_screen <= lt.MAX_LIGHTS, "the climber's glow and the torches light it (%d lights)" % lt.on_screen)
	# The registry: lights come and go.
	var before: int = lt.on_screen
	var id: int = lt.add_light(main.player.global_position + Vector2(40, 0), 120.0, Color(0.5, 0.8, 1.0), 0.8, 0.2)
	await _frames(2)
	_check(lt.on_screen == before + 1, "a registered light reaches the shader")
	lt.remove_light(id)
	await _frames(2)
	_check(lt.on_screen == before, "...and leaves when removed")
	var far_id: int = lt.add_light(main.player.global_position + Vector2(9000, 0), 100.0, Color.WHITE)
	await _frames(2)
	_check(lt.on_screen == before, "a light far off screen isn't sent")
	lt.remove_light(far_id)
	var holder := Node2D.new()
	main.add_child(holder)
	lt.add_light(Vector2.ZERO, 100.0, Color.WHITE, 0.8, 0.0, holder)
	holder.global_position = main.player.global_position
	await _frames(2)
	_check(lt.on_screen == before + 1, "a light can follow a node...")
	holder.queue_free()
	await _frames(3)
	_check(lt.on_screen == before and lt.lights.is_empty(), "...and goes when the node does (%d, was %d, %d left)" % [lt.on_screen, before, lt.lights.size()])
	# Flashes fade and expire.
	main.light_flash(main.player.global_position, Color(1, 0.8, 0.4), 1.5, 1.6, 0.2)
	await _frames(1)
	_check(lt.flashes.size() == 1 and lt.on_screen == before + 1, "a light flash lights the darkness (%d, %d)" % [lt.flashes.size(), lt.on_screen])
	await _wait(0.35)
	await _frames(2)
	_check(lt.flashes.is_empty() and lt.on_screen == before, "...and expires")
	for i in 40:
		main.light_flash(main.player.global_position, Color.WHITE, 1.0, 1.0, 5.0)
	_check(lt.flashes.size() == lt.MAX_FLASHES, "flashes are capped (%d)" % lt.flashes.size())
	await _frames(2)
	_check(lt.on_screen <= lt.MAX_LIGHTS, "never more lights than the shader takes")
	lt.flashes.clear()
	# The stair glows once open; each tower has its own darkness colour.
	main.stair_open = true
	await _frames(2)
	var at_stair: Array = lt.live_lights().filter(func(l): return l[0].distance_to(main.stair_pos) < 1.0)
	_check(at_stair.size() == 1 and at_stair[0][1] > 150.0, "the open stair is lit")
	main.stair_open = false
	main.dev_tower("wyvern")
	await _frames(2)
	_check(lt.dark_color == main.Palette.TOWER_FOG["wyvern"], "each tower has its own darkness colour")
	# Fog: drawn by the darkness layer from fog.gd's texture.
	main.dev_floor(2)
	await _frames(1)
	for f in main.enemies():
		f.set_physics_process(false)
	await _frames(2)
	_check(main.fog.visible and main.fog.tex != null and lt.mat.get_shader_parameter("fog_on") == true, "the darkness layer draws the line-of-sight fog")
	_check(main.fog.tex.get_image().get_format() == Image.FORMAT_L8, "...from a one-byte-per-tile texture")
	var looks: int = main.fog.looks
	main.player.global_position += Vector2(40, 0)
	await _frames(1)
	main.player.global_position += Vector2(40, 0)
	await _frames(1)
	_check(main.fog.looks - looks <= 2, "sight isn't worked out every frame (%d)" % (main.fog.looks - looks))
	# World words go above the darkness.
	_check(main.fx.labels.z_index > lt.z_index and not main.fx.labels.z_as_relative, "floating words are drawn above the darkness")
	main.dev_floor(1)
	await _frames(2)
	_check(not lt.mat.get_shader_parameter("fog_on"), "no fog on single-room floors")


## Builds a wall two tiles thick across the biggest room, from wall to wall
## (by setting main.solid, as a door closing does), with clear floor on a
## row either side of it. Returns [tile west of it, tile east of it, the
## wall's grid indices], or [] if no row is clear.
func _carve_wall() -> Array:
	var c: float = main.Floors.CELL
	var best: Rect2 = main.room_info[0]["rect"]
	for info in main.room_info:
		if info["rect"].get_area() > best.get_area():
			best = info["rect"]
	var t0: Vector2i = main._tile_of(best.position + Vector2(1, 1))
	var t1: Vector2i = main._tile_of(best.end - Vector2(1, 1))
	var mx := (t0.x + t1.x) / 2
	for y in range(t0.y + 1, t1.y):
		var clear := true
		for x in range(mx - 4, mx + 6):
			var mid: Vector2 = main.room.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * c
			if main._is_solid_tile(x, y) or main.pillars.any(func(pl): return pl["pos"].distance_to(mid) < pl["r"] + 30.0):
				clear = false
		if not clear:
			continue
		var wall: Array = []
		for wy in range(t0.y - 1, t1.y + 2):
			for wx in [mx, mx + 1]:
				var i: int = wy * main.grid_size.x + wx
				if main.solid[i] == 0:
					wall.append(i)
					main.solid[i] = 1
		return [Vector2i(mx - 2, y), Vector2i(mx + 3, y), wall]
	return []


func _tile_mid(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * main.Floors.CELL


## Shadows, spotlights, glow and the Lighting setting (lighting.gd).
func _shadow_tests() -> void:
	print("lighting: shadows, spotlights, glow and quality")
	await _fresh_main()
	var lt = main.lighting
	var menu = main.menu
	_check(lt.quality == lt.default_quality() and lt.quality == "high", "a computer starts on High lighting (%s)" % lt.quality)
	_check(lt.default_quality() in ["medium", "high"], "...a phone or a browser on Medium")
	# Spotlights: lit inside the cone, dark behind it (shadows off, so only the cone counts).
	lt.set_quality("low")
	var p: Vector2 = main.player.global_position
	var spot: int = lt.add_spot(p, Vector2.RIGHT, 60.0, 220.0, Color.WHITE, 0.9)
	var omni: int = lt.add_light(p, 220.0, Color.WHITE, 0.9)
	await _frames(2)
	_check(lt.light_at(spot, p + Vector2(110, 0)) > 0.4 and lt.light_at(spot, p + Vector2(110, 25)) > 0.3, "a spotlight lights inside its cone (%.2f)" % lt.light_at(spot, p + Vector2(110, 0)))
	_check(lt.light_at(spot, p + Vector2(-110, 0)) < 0.02 and lt.light_at(spot, p + Vector2(0, -110)) < 0.02, "...and not behind it or beside it")
	_check(lt.light_at(omni, p + Vector2(-110, 0)) > 0.4, "a plain light still shines all round")
	var sent: int = lt.on_screen
	lt.remove_light(spot)
	lt.remove_light(omni)
	await _frames(2)
	_check(lt.on_screen == sent - 2, "spotlights go to the shader like any light")
	# Low: no glow, the plain shader.
	_check(not lt.glow_layer.visible and lt.blooms.is_empty(), "Low draws no glow")
	_check(not lt.mat.shader.code.contains("#define SHADOWS"), "Low uses the plain darkness (no shadows)")
	# A floor of rooms: a light beside a wall.
	var pair := []
	for attempt in 6:  # (a random floor's biggest room can be too cluttered for the wall; plan another)
		main.dev_floor(2)
		await _frames(2)
		for e in main.enemies():
			e.set_physics_process(false)
		pair = _carve_wall()
		if not pair.is_empty():
			break
	_check(not pair.is_empty(), "a wall can be built across a room")
	if pair.is_empty():
		return
	var pa := _tile_mid(pair[0])
	var pb := _tile_mid(pair[1])
	main.player.global_position = pa + Vector2(0, 4)
	main.cam_prev = main.player.global_position
	main.cam_curr = main.player.global_position
	main.camera.reset_smoothing()
	var id: int = lt.add_light(pa, 300.0, Color.WHITE, 0.9)
	await _frames(3)
	_check(lt.light_at(id, pb) > 0.3, "on Low a light shines through the wall (%.2f)" % lt.light_at(id, pb))
	for q in ["high", "medium"]:
		lt.set_quality(q)
		await _until(func(): return lt.lights[id].has("sh_key") and lt.shadow_at(pa, 300.0, pb) >= 0.0, 2.0)
		_check(lt.mat.shader.code.contains("#define SHADOWS"), "%s draws shadows" % q)
		_check(lt.light_at(id, pb) < 0.03, "on %s a light behind a wall doesn't light the far side (%.2f)" % [q, lt.light_at(id, pb)])
		_check(lt.light_at(id, pa + Vector2(-30, 0)) > 0.5, "...but lights its own side (%.2f)" % lt.light_at(id, pa + Vector2(-30, 0)))
	# A light that stays put isn't worked out again; a wall that opens is.
	var slot: int = lt.slot_of(id)
	var cast_at: int = lt.slot_cast_frame(slot)
	await _frames(8)
	_check(slot >= 0 and lt.slot_of(id) == slot and lt.slot_cast_frame(slot) == cast_at, "a still light's shadow is worked out once")
	for i in pair[2]:
		main.solid[i] = 0
	await _until(func(): return lt.light_at(id, pb) > 0.3, 2.0)
	_check(lt.light_at(id, pb) > 0.3, "a wall opening (a door) lets the light through (%.2f)" % lt.light_at(id, pb))
	for i in pair[2]:
		main.solid[i] = 1
	await _until(func(): return lt.light_at(id, pb) < 0.03, 2.0)
	_check(lt.light_at(id, pb) < 0.03, "...and closing stops it again")
	lt.set_quality("high")
	await _until(func(): return lt.climber_light.has("sh_key"), 2.0)
	_check(lt.climber_light.has("sh_key"), "on High the climber's own light casts shadows")
	for i in pair[2]:
		main.solid[i] = 0
	lt.remove_light(id)
	# Glow: halos on bright things, one draw for all of them.
	lt.set_quality("high")
	var bright: int = lt.add_light(pa, 120.0, Color(0.5, 0.8, 1.0), 0.8, 0.3)
	main.light_flash(pa + Vector2(-20, 10), Color(1.0, 0.6, 0.3), 1.2, 1.6, 2.0)
	await _until(func(): return lt.blooms.any(func(b): return b[0].distance_to(pa) < 1.0), 2.0)
	_check(lt.glow_layer.visible and lt.blooms.any(func(b): return b[0].distance_to(pa) < 1.0), "a bright light glows (%d halos)" % lt.blooms.size())
	_check(lt.blooms.any(func(b): return b[0].distance_to(pa + Vector2(-20, 10)) < 1.0), "...and so does a spell's flash")
	main.gather_essence("fire", 120.0, pa + Vector2(30, 0))
	await _frames(2)
	_check(lt.blooms.size() <= lt.BLOOM_MAX and lt.blooms.size() > 3, "essence motes glow, within a cap (%d halos)" % lt.blooms.size())
	_check(lt.get_children() == [lt.glow_layer] and lt.glow_layer.get_child_count() == 0, "the darkness and the glow are two canvas items: two draw calls")
	lt.remove_light(bright)
	lt.flashes.clear()
	# The cap: never more lights than the shader takes, never more shadows than the atlas holds.
	var many: Array = []
	for i in 70:
		many.append(lt.add_light(pa + Vector2(randf_range(-200, 200), randf_range(-150, 150)), 90.0, Color.WHITE, 0.5))
	await _frames(12)
	_check(lt.on_screen <= lt.MAX_LIGHTS and lt.on_screen > 20, "70 lights: the shader still gets at most %d (%d)" % [lt.MAX_LIGHTS, lt.on_screen])
	_check(lt._key_slot.size() <= lt.SLOT_COLS * lt.SLOT_ROWS, "...and the shadow atlas holds at most %d" % (lt.SLOT_COLS * lt.SLOT_ROWS))
	for m in many:
		lt.remove_light(m)
	# Settings -> Lighting: saved, loaded, and it changes the lighting.
	menu.open("settings")
	await _frames(1)
	var rows: Array = _all_buttons(menu).filter(func(b): return b.get_meta("choice_key", "") == "lighting")
	_check(rows.size() == 3, "Settings offers Low, Medium and High lighting")
	rows[0].pressed.emit()
	await _frames(2)
	_check(menu.settings["lighting"] == "low" and lt.quality == "low", "choosing Low switches the lighting to Low")
	menu.close()
	await _frames(2)
	var path := "user://test_lighting.cfg"
	menu.save_settings_to(path)
	menu.settings["lighting"] = "high"
	menu.load_settings_from(path)
	_check(menu.settings["lighting"] == "low", "the lighting setting is saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	menu._set_setting("lighting", "medium")
	_check(lt.quality == "medium" and lt.QUALITY["medium"]["cast_ms"] < lt.QUALITY["high"]["cast_ms"], "Medium works shadows out more slowly than High")
	_check(lt.QUALITY["high"]["climber"] and not lt.QUALITY["medium"]["climber"], "...and only High gives the climber's own light a shadow")
	menu._set_setting("lighting", "high")
	main.dev_floor(1)
	await _frames(2)


func _foe_list_tests() -> void:
	print("the monster list, remembered per frame")
	await _fresh_main()
	await _frames(2)
	var n: int = main.enemies().size()
	_check(is_same(main.enemies(), main.enemies()), "asking twice in a frame gives the same list")
	var e = main.spawn_enemy("slime", main.player.global_position + Vector2(120, 0))
	_check(main.enemies().has(e) and main.enemies().size() == n + 1, "a monster spawned this frame is in the list at once")
	_check(main.targets().has(e), "...and can be aimed at")
	e.submerged = true
	_check(not main.targets().has(e) and main.enemies().has(e), "a lurker under the water drops out of targets()")
	e.submerged = false
	_check(main.targets().has(e), "...and comes back when it surfaces")
	e.take_hit(99999.0, Vector2.ZERO, 0.0)
	_check(not main.enemies().has(e) and main.enemies().size() == n, "a dead monster leaves the list the same frame")
	var e2 = main.spawn_enemy("slime", main.player.global_position + Vector2(-120, 0))
	_check(main.enemies().has(e2), "another spawn...")
	main.remove_child(e2)
	_check(not main.enemies().has(e2), "...and a removed one leaves the list")
	e2.free()
	await _frames(2)
	_check(main.enemies().all(func(f): return is_instance_valid(f) and not f.dead), "the list holds only living monsters")
	# Paths: only a few monsters look for one each tick.
	var turns := 0
	for i in 10:
		if main.take_path_turn():
			turns += 1
	_check(turns <= main.PATHS_PER_TICK, "at most %d path searches a tick (%d)" % [main.PATHS_PER_TICK, turns])


func _slim_hud_tests() -> void:
	print("the slim HUD")
	await _fresh_main()
	for f in main.enemies():
		f.set_physics_process(false)
	main.grant_test_bonds()
	var p = main.player
	var hud = main.hud
	await _frames(3)
	_check(hud.core != null and hud.core.get_parent() == hud.get_parent() and hud.core.get_index() < hud.get_index(), "the HUD's always-there part is its own layer, under the fading bits")
	var titles: Array = hud.tips.map(func(t): return t[1])
	_check(titles.any(func(t): return t.begins_with("Health")) and main.Gear.display(p.weapon) in titles and titles.any(func(t): return t.begins_with("Stormcaller")), "always there: health and stamina, the weapon in hand, the marks")
	_check(not titles.any(func(t): return t in ["Fists", "Shortbow", "No armor"]), "...but not every weapon slot or the armor")
	# Drawn once, again only when something changes.
	await _wait(1.0)
	var drawn: int = hud.core_redraws
	await _frames(10)
	_check(hud.core_redraws == drawn, "the HUD isn't redrawn while nothing changes")
	p.hp -= 10.0
	await _frames(2)
	_check(hud.core_redraws > drawn, "...and is when health changes")
	await _wait(1.5)
	hud.floor_t = 0.0
	hud.hints_t = 0.0
	hud.stair_t = 0.0
	hud.essence_t = 0.0
	main.banner = {}
	await _frames(3)
	var top: int = hud.top_redraws
	await _frames(10)
	_check(hud.top_redraws <= top + 1, "the fading layer rests when nothing fades (%d redraws)" % (hud.top_redraws - top))
	# Poison turns the health bar green: being poisoned changes what the core shows.
	var sig0: Array = hud._core_signature()
	p.poison_t = 3.0
	_check(hud._core_signature() != sig0, "being poisoned redraws the HUD (its health bar turns green)")
	p.poison_t = 0.0
	# The gilt pieces are built as plain strips (no round joints), so they stay cheap.
	var strip = load("res://scripts/draw_util.gd").Batch.new()
	hud.UI.ring_into(strip, Vector2.ZERO, 10.0, 2.0, Color.WHITE, 0.0, TAU, 12)
	hud.UI.gauge_into(strip, Rect2(0, 0, 100, 12), 0.5, Color.RED, 0.7)
	_check(strip.size() > 72 and strip.size() < 600, "the HUD's rings and gauges are a few triangles each (%d points)" % strip.size())
	# Fading notices.
	main.gather_essence("water", 5.0, p.global_position)
	await _frames(2)
	_check(hud.essence_t > 0.0, "picking up essence shows the gem counter")
	var ranged: String = p.slots()[2]
	p._equip(ranged)
	await _frames(2)
	_check(p.weapon == ranged and hud.swap_t > 0.0, "swapping weapons pops up the weapon row")
	p._equip("sword")
	main.dev_floor(2)
	await _frames(2)
	_check(hud.floor_t > 0.0, "a new floor shows its title for a moment")
	# The moved panels are on the climber screen and in the inventory.
	var menu = main.menu
	menu.open("inventory", true)
	await _frames(2)
	_check(_slot("gear:fists") != null and _slot("gear:ranged") != null and _slot("gear:armor") != null, "every weapon slot and the armor are in the inventory")
	menu.close()
	await _frames(2)
	menu.climber_tab = "marks"
	menu.open("climber", true)
	await _frames(3)
	var cards: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("part"))
	_check(cards.size() == 6 and cards.any(func(c): return not main.profile.bonds.has(c.get_meta("part"))), "where the next mark forms is on the climber screen's Marks tab")
	menu.close()
	await _frames(2)
	menu.climber_tab = "essence"
	menu.open("climber", true)
	await _frames(2)
	_check(menu.page == "climber" and menu.climber_tab == "essence", "...and the attributes on its Essence tab")
	menu.close()
	await _frames(2)
	# Phone size: still small and clear, the buttons redrawn only on change.
	main.touch._set_active(true)
	await _frames(3)
	var t0: int = main.touch.redraws
	await _frames(10)
	_check(main.touch.redraws <= t0 + 1, "the touch buttons aren't redrawn every frame (%d)" % (main.touch.redraws - t0))
	await _frames(2)
	var size: Vector2 = hud.get_viewport_rect().size
	var right_edge := 0.0
	for t in hud.tips:
		right_edge = maxf(right_edge, t[0].end.x * hud.hud_scale)
	_check(right_edge < size.x * 0.45, "on a phone the HUD keeps to the top left (%.0f of %.0f)" % [right_edge, size.x])
	main.touch._set_active(false)
	await _frames(2)
	# The dev readout.
	hud.show_perf = true
	await _wait(0.3)
	_check(hud.perf_text.size() >= 5 and String(hud.perf_text[0]).contains("fps") and String(hud.perf_text[4]).contains("lights"), "the dev speed readout shows fps, draw calls, nodes, monsters, traps and lights")
	hud.show_perf = false


func _tower_tests() -> void:
	print("towers and the early stair")
	await _fresh_main()
	var p = main.player
	_check(main.tower == "kraken" and main.beast_name() == "the Kraken", "tests climb the Kraken's tower")
	# The stair opens once three of the four are down; the gong waits for the last.
	var foes: Array = main.enemies()
	for i in 3:
		_slay(foes[i])
	await _frames(3)
	_check(main.stair_open and not main.cleared, "the stair opens with one foe left")
	_check(main.run_essence.get("water", 0.0) >= 3.0 * main.Towers.ESSENCE_BONUS, "every kill gives a little of the tower's essence")
	_slay(foes[3])
	await _frames(3)
	_check(main.cleared, "the last kill clears the floor")
	# Towers change the monster mix on higher floors.
	var counts := {}
	for id in ["gryphon", "kraken", "wyvern"]:
		var c := {"slime": 0, "archer": 0, "knight": 0}
		for n in 30:
			var plan: Dictionary = main.Floors.build(4, main.room, main.player_start, main.Towers.TOWERS[id])
			for m in plan["monsters"]:
				c[m[0]] = c.get(m[0], 0) + 1
		counts[id] = c
	_check(counts["gryphon"]["archer"] > counts["kraken"]["archer"], "the Gryphon's tower has more archers (%d vs %d)" % [counts["gryphon"]["archer"], counts["kraken"]["archer"]])
	var wet: int = counts["kraken"]["slime"] + counts["kraken"].get("lurker", 0)
	_check(wet > counts["wyvern"]["slime"], "the Kraken's tower has more water creatures (%d vs %d)" % [wet, counts["wyvern"]["slime"]])
	var iron: int = counts["wyvern"]["knight"] + counts["wyvern"].get("smith", 0)  # (knights also stand guard in every tower, so count its smiths too)
	_check(iron > counts["gryphon"]["knight"] + counts["gryphon"].get("smith", 0), "the Wyvern's tower has more knights and smiths (%d vs %d)" % [iron, counts["gryphon"]["knight"] + counts["gryphon"].get("smith", 0)])
	# Choosing a tower restyles the room and restarts floor 1 there.
	main.choosing_tower = true
	main.choose_tower("wyvern")
	await _frames(2)
	_check(main.tower == "wyvern" and not main.choosing_tower and main.floor_num == 1, "choosing the Wyvern's tower starts its floor 1")
	_check(main.enemies().filter(func(e): return e.kind == "knight").size() == 2, "the Wyvern's floor 1 has two knights")
	_check(main.profile.last_tower == "wyvern", "the choice is remembered")


func _spell_tests() -> void:
	print("new climber")
	main.regard = {}  # (still showing from the test above; it ignores other keys)
	main.grant_test_bonds()
	_check(not main.profile.bonds.is_empty(), "(the climber has marks)")
	await _frames(1)  # press at the start of a frame, before the room reads input
	Input.action_press("new_climber")
	await _frames(2)
	Input.action_release("new_climber")
	_check(main.new_climber_t > 0.0 and main.banner.get("title", "") == "START OVER?", "a first press asks to confirm")
	_check(not main.profile.bonds.is_empty(), "one press changes nothing yet")
	await _frames(2)
	Input.action_press("new_climber")
	await _frames(2)
	Input.action_release("new_climber")
	_check(main.profile.bonds.is_empty() and not main.profile.regarded, "a second press starts a new climber: no marks")
	_check(main.menu.page == "create", "...who chooses a look first (the creation page)")
	main.menu.look_page.begin()  # (Begin: the game runs on)
	Engine.remove_meta("sixfold_title_seen")
	await _frames(1)

	print("new spells")
	await _fresh_main()
	var p = main.player
	main.profile.add_bond("heart", "tidecaller", false)
	main.profile.add_bond("hand", "blade_forger", false)
	main.profile.regarded = true
	main.first_climb = false
	main._give_bonds()
	var foe = await _spawn("slime", p.global_position + Vector2(60, 0))
	foe.hp = 999.0
	foe.set_physics_process(true)  # so the push can move it
	var before: Vector2 = foe.global_position
	p.bonds["heart"].essence = 99.0
	p.bonds["heart"].cast(p)
	await _wait(0.3)
	_check(foe.hp < 999.0 and foe.global_position.distance_to(p.global_position) > before.distance_to(p.global_position), "Tidal Surge hurts and hurls foes away")
	foe.global_position = p.global_position + Vector2(120, 0)
	p.aim = Vector2.RIGHT
	var hp1: float = foe.hp
	p.bonds["hand"].cast(p)
	var blades: int = main.get_children().filter(func(c): return "style" in c and c.style == "blade").size()
	_check(blades == 3, "Conjured Blades fires three blades (%d)" % blades)
	await _wait(0.5)
	_check(foe.hp < hp1, "the blades strike")
	await _kraken_bond_tests()



func _item_tests() -> void:
	print("items")
	await _fresh_main()
	var p = main.player
	var Items = main.Items
	_check(p.item_count("draught") == 1 and p.carried() == ["draught"], "every climb starts with one healing draught")
	_check(InputMap.has_action("use_item") and InputMap.has_action("item_next"), "use item (G) and next item (T) are bound")
	# The healing draught heals over a moment, not all at once.
	p.hp = 50.0
	_check(p.use_item(), "the draught can be drunk")
	_check(p.item_count("draught") == 0 and p.carried().is_empty(), "...and is used up")
	_check(p.hp < 55.0, "...it doesn't heal all at once")
	await _wait(0.7)
	var mid: float = p.hp
	_check(mid > 52.0 and mid < 89.0, "...it heals over a moment (%.0f after 0.7 s)" % mid)
	await _wait(1.3)
	_check(absf(p.hp - 90.0) < 1.0, "a draught heals 40 health in about 1.5 s (%.0f)" % p.hp)
	_check(not p.use_item(), "with nothing left, nothing happens")
	# Stacks are capped.
	for i in 5:
		p.add_item("draught")
	_check(p.item_count("draught") == Items.MAX_STACK, "you carry at most %d of an item" % Items.MAX_STACK)
	p.hp = p.max_health()
	_check(not p.use_item() and p.item_count("draught") == Items.MAX_STACK, "a draught isn't wasted at full health")
	# The cleansing tonic: poison and burns.
	_mark("hand", "stormcaller", 2)
	p.add_item("tonic")
	p.item_sel = "tonic"
	p.bonds["hand"].burned = true
	p.poison(5.0)
	_check(p.use_item(), "the tonic can be drunk")
	_check(not p.bonds["hand"].burned and p.poison_t <= 0.0, "the cleansing tonic cures poison and heals burned body parts")
	# The essence vial fills every mark.
	_mark("legs", "windwalker", 2)
	p.bonds["hand"].essence = 0.0
	p.bonds["legs"].essence = 1.0
	p.add_item("vial")
	p.item_sel = "vial"
	_check(p.use_item(), "the essence vial can be used")
	_check(p.bonds["hand"].essence >= p.bonds["hand"].capacity() - 0.01 and p.bonds["legs"].essence >= p.bonds["legs"].capacity() - 0.01, "the essence vial fills every mark")
	p.add_item("vial")
	p.item_sel = "vial"
	_check(not p.use_item() and p.item_count("vial") == 1, "...and isn't wasted while they're full")
	# The smoke bomb hides you.
	p.add_item("smoke")
	p.item_sel = "smoke"
	var clouds: int = main.smokes.size()
	_check(p.use_item() and main.smokes.size() == clouds + 1, "the smoke bomb leaves a cloud monsters lose you in")
	# Cycling: T picks the next item you carry.
	p.item_sel = "draught"
	p.cycle_item()
	_check(p.selected_item() == "vial", "the next-item key moves on to the next item you carry (%s)" % p.selected_item())
	p.cycle_item()
	_check(p.selected_item() == "draught", "...and wraps around")
	# G uses the selected item through the input action.
	p.hp = 60.0
	var have: int = p.item_count("draught")
	Input.action_press("use_item")
	await physics_frame
	await physics_frame
	Input.action_release("use_item")
	await _frames(2)
	_check(p.item_count("draught") == have - 1, "pressing G uses the selected item")
	await _wait(1.7)
	# Drops: slain monsters sometimes leave an item.
	main.item_drop_chance = 1.0
	p.items = {}
	var slime = await _spawn("slime", p.global_position + Vector2(140, 0))
	_slay(slime)
	main.item_drop_chance = Items.DROP_CHANCE
	_check(main.item_drops.size() == 1, "a slain monster can leave an item")
	if main.item_drops.size() == 1:
		var id: String = main.item_drops[0]["id"]
		p.global_position = main.item_drops[0]["pos"]
		await _wait(0.3)
		_check(p.item_count(id) == 1 and main.item_drops.is_empty(), "walking over it picks it up (%s)" % id)
	main.item_drop_chance = 0.0
	var other = await _spawn("slime", p.global_position + Vector2(140, 0))
	_slay(other)
	_check(main.item_drops.is_empty(), "(no drop when the dice say no)")
	main.item_drop_chance = Items.DROP_CHANCE
	await _wait(0.3)

	print("Steady Hands and items")
	await _fresh_main()
	p = main.player
	p.hp = 20.0
	p.use_item()
	var plain_amount: float = p.heal_left
	var plain_time: float = p.heal_left / p.heal_rate
	p.heal_left = 0.0
	_mark("brow", "surgeon", 2)
	p.hp = 20.0
	p.add_item("draught")
	p.use_item()
	var steady_amount: float = p.heal_left
	var steady_time: float = p.heal_left / p.heal_rate
	_check(steady_amount >= plain_amount * 1.29, "Steady Hands: healing items heal 30%% more (%.0f vs %.0f)" % [steady_amount, plain_amount])
	_check(steady_time < plain_time - 0.3, "...and work faster (%.2f s vs %.2f s)" % [steady_time, plain_time])
	p.heal_left = 0.0

	print("the item button on a phone")
	await _fresh_main()
	p = main.player
	_mark("hand", "stormcaller", 1)
	_mark("legs", "windwalker", 1)
	_mark("heart", "deepcaller", 1)
	_mark("brow", "warden", 1)
	_mark("throat", "flameblade", 1)
	_mark("back", "ashwalker", 1)
	main.touch._set_active(true)
	await _frames(2)
	main.touch._layout()
	var buttons: Array = main.touch.buttons
	var ids: Array = buttons.map(func(b): return b["id"])
	_check("item" in ids and "item_next" in ids, "the phone layout has an item button and a next-item button")
	var clear := true
	var view: Vector2 = main.touch.get_viewport_rect().size
	for b in buttons:
		if not (b["id"] in ["item", "item_next"]):
			continue
		clear = clear and Rect2(Vector2.ZERO, view).has_point(b["c"])
		for o in buttons:
			if o != b and b["c"].distance_to(o["c"]) < b["r"] + o["r"] + 2.0:
				clear = false
				print("    overlaps: ", b["id"], " and ", o["id"])
	_check(clear, "the item buttons are on screen and don't overlap any other button, even with six marks")
	p.hp = 60.0
	var item_btn: Dictionary = buttons[ids.find("item")]
	_touch(4, item_btn["c"], true)
	await _wait(0.1)  # (a tap: much longer, on a slow machine, opens the item ring)
	_touch(4, item_btn["c"], false)
	await _wait(0.12)
	_check(p.item_count("draught") == 0, "tapping the item button uses the item")
	p.add_item("draught")
	p.add_item("tonic")
	p.item_sel = "draught"
	var next_btn: Dictionary = buttons[ids.find("item_next")]
	_touch(5, next_btn["c"], true)
	await _wait(0.1)
	_touch(5, next_btn["c"], false)
	await _wait(0.12)
	_check(p.selected_item() == "tonic", "tapping the small arrow picks the next item")
	main.touch._set_active(false)
	await _frames(2)


func _camp_tests() -> void:
	print("camps")
	await _fresh_main()
	var p = main.player
	var Items = main.Items
	main.floor_num = 3
	_check(not main._camp_due(), "no camp on the bondless first climb")
	_mark("hand", "stormcaller", 1)
	main.floor_num = 2
	main._arrive()
	_check(main.floor_num == 3 and not main.in_camp, "floor 2's stair leads on to floor 3")
	p.hp = 30.0
	p.bonds["hand"].burned = true
	main._arrive()
	await _frames(2)
	_check(main.in_camp and main.camp_choosing, "floor 3's stair leads to a camp")
	_check(main._floor_title() == "CAMP", "the HUD says CAMP")
	_check(main.enemies().is_empty(), "the camp is safe: no monsters")
	_check(main.campfire != null and is_instance_valid(main.campfire), "the camp has a campfire")
	_check(p.hp == p.max_health() and not p.bonds["hand"].burned, "a full rest by the fire")
	var item_cards: Array = main.camp["choices"].filter(func(c): return not String(c).begins_with("gear:"))
	_check(item_cards.size() == Items.CAMP_CHOICES, "three items to choose from")
	_check(main.camp["choices"].size() == Items.CAMP_CHOICES + 1, "...and a piece of gear")
	var distinct := {}
	for c in main.camp["choices"]:
		distinct[c] = true
	_check(distinct.size() == Items.CAMP_CHOICES + 1, "...all different")
	var pick: String = main.camp["choices"][1]
	var had: int = p.item_count(pick)
	Input.action_press("weapon_2")
	await _frames(2)
	Input.action_release("weapon_2")
	await _frames(2)
	_check(p.item_count(pick) == had + 1 and not main.camp_choosing, "pressing 2 takes the second item (%s)" % pick)
	_check(p.is_physics_processing(), "then you're free to walk")
	await _frames(3)
	_check(main.stair_open, "the camp's stair is open")
	p.global_position = main.stair_pos
	await _wait(1.6)
	_check(main.floor_num == 4 and not main.in_camp and main.campfire == null, "the camp's stair leads on to floor 4")
	_check(main.enemies().size() > 0, "floor 4 has monsters again")
	main._arrive()
	_check(main.floor_num == 5 and not main.in_camp, "floor 4 leads straight on to floor 5")
	_check(main.Towers.SUMMIT == 12 and main.Towers.PROVING["floor"] == 6, "towers are 12 floors tall, with the Proving on floor 6")
	main.floor_num = 9
	main._arrive()
	await _frames(2)
	_check(main.in_camp and main.camp_choosing, "floor 9's stair leads to a second camp")
	main.choose_camp(0)
	await _frames(2)
	main._arrive()
	_check(main.floor_num == 10 and not main.in_camp, "the second camp's stair leads on to floor 10 (camps aren't floors)")
	main.floor_num = 9
	main._arrive()
	_check(main.floor_num == 10 and not main.in_camp, "each camp comes once a climb")

	print("Runesmith at a camp")
	await _fresh_main()
	p = main.player
	_mark("hand", "rune_artist", 2)
	main.floor_num = 3
	main._arrive()
	await _frames(2)
	_check(main.camp_choosing and main.camp["stage"] == "item", "a Rune Artist picks an item first")
	main.choose_camp(0)
	_check(main.camp_choosing and main.camp["stage"] == "rune" and main.camp["choices"].size() == 4, "then Runesmith offers three gear runes or a crafted item")
	# Tap the Warding card on the phone.
	main.touch._set_active(true)
	await _frames(2)
	var view: Vector2 = main.hud.get_viewport_rect().size
	var at: Vector2 = main.hud.camp_card_rect(1, view).get_center()
	_check(main.hud.camp_card_at(at) == 1, "the cards can be found under a tap")
	_touch(6, at, true)
	await _frames(2)
	_touch(6, at, false)
	await _frames(2)
	_check(not main.camp_choosing and p.rune_gear == "warding", "tapping the Warding card inscribes it on your gear (%s)" % p.rune_gear)
	main.touch._set_active(false)
	await _frames(2)
	main._arrive()
	_check(main.floor_num == 4 and p.rune_gear == "warding", "a camp's rune lasts past the next stair")
	main._arrive()
	_check(main.floor_num == 5 and p.rune_gear == "warding", "...for the rest of the climb")
	# Or craft an item instead.
	await _fresh_main()
	p = main.player
	_mark("hand", "rune_artist", 2)
	main.floor_num = 3
	main._arrive()
	main.choose_camp(0)
	var craft: String = String(main.camp["choices"][3]).substr(6)
	var before: int = p.item_count(craft)
	main.choose_camp(3)
	_check(p.item_count(craft) == mini(before + 1, Items.MAX_STACK) and p.rune_gear == "", "Runesmith can craft one more item instead (%s)" % craft)
	# Without Runesmith, one pick and you're done.
	await _fresh_main()
	p = main.player
	_mark("hand", "stormcaller", 2)
	main.floor_num = 3
	main._arrive()
	main.choose_camp(2)
	_check(not main.camp_choosing, "without Runesmith a camp offers just the one pick")


## A practice dummy: a slime that faces the climber, with plenty of health.
func _dummy(pos: Vector2):
	var d = await _spawn("slime", pos)
	d.hp = 999.0
	d.max_hp = 999.0
	d.face = (main.player.global_position - pos).normalized()
	return d


## One fresh swing (or the next in the chain if `chain` is set); hit-pause
## is cleared so the next swing is measured cleanly.
func _swing(chain := false) -> void:
	var p = main.player
	p.attack_cd = 0.0
	p.lunge_t = 0.0
	if not chain:
		p.combo_t = 0.0
	p._melee()
	Engine.time_scale = 1.0
	main.hitstop_until = 0


func _gear_tests() -> void:
	print("weapons")
	await _fresh_main()
	var p = main.player
	var W = p.Weapons
	var G = main.Gear
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var spot := Vector2(500, 400)
	p.global_position = spot
	p.aim = Vector2.RIGHT
	_check(p.weapon == "sword" and p.gear_id("melee") == "sword" and p.gear_id("ranged") == "shortbow" and p.gear_id("armor") == "", "every climb starts with a sword, a shortbow and no armor")
	_check(G.SLOTS.all(func(sl): return sl in ["melee", "ranged"] or p.gear_id(sl) == ""), "...and nothing in the other slots")
	_check(p.slots() == ["fists", "sword", "shortbow"], "slots: 1 fists, 2 melee, 3 ranged")
	_check(InputMap.has_action("interact"), "taking gear (Y) is bound")
	var y_bound := false
	for ev in InputMap.action_get_events("interact"):
		y_bound = y_bound or (ev is InputEventKey and ev.physical_keycode == KEY_Y)
	_check(y_bound, "...to the Y key")
	# Every melee weapon swings, lands and deals sensible damage.
	var dealt := {}
	var cost := {}
	var recover := {}
	var all_ok := true
	for id in W.ORDER:
		if W.WEAPONS[id]["kind"] != "melee":
			continue
		p._equip(id)
		p.global_position = spot
		var d = await _dummy(spot + Vector2(30, 0))
		p.sta = p.MAX_STA
		_swing()
		dealt[id] = 999.0 - d.hp
		cost[id] = p.MAX_STA - p.sta
		recover[id] = p.attack_cd
		var want: float = p.STRIKE_DAMAGE * float(W.WEAPONS[id]["combo"][0]["dmg"]) * p.attr_strength
		if not (absf(dealt[id] - want) < 0.6 and dealt[id] >= 3.0 and dealt[id] <= 30.0):
			all_ok = false
			print("    %s dealt %.1f (wanted %.1f)" % [id, dealt[id], want])
		d.queue_free()
		await _frames(1)
	_check(all_ok, "every melee weapon swings and lands sensible damage (%s)" % str(dealt))
	_check(dealt["greatsword"] > dealt["axe"] and dealt["axe"] > dealt["sword"] and dealt["sword"] > dealt["dagger"], "heavier weapons hit harder: greatsword > axe > sword > dagger")
	_check(dealt["war_hammer"] > dealt["greatsword"], "the war hammer hits hardest of all (%.0f)" % dealt["war_hammer"])
	_check(cost["war_hammer"] > cost["greatsword"] and cost["greatsword"] > cost["axe"] and cost["axe"] > cost["sword"] and cost["sword"] > cost["dagger"], "...and costs more stamina: %s" % str(cost))
	_check(recover["dagger"] < recover["sword"] and recover["sword"] < recover["greatsword"] and recover["greatsword"] < recover["war_hammer"], "the dagger recovers fastest, the hammer slowest: %s" % str(recover))
	# Each chain ends in a heavy finisher.
	var finishers := true
	for id in W.ORDER:
		if W.WEAPONS[id]["kind"] == "melee":
			finishers = finishers and bool(W.WEAPONS[id]["combo"][-1]["heavy"])
	_check(finishers, "every melee chain ends in a heavy finisher")
	# The spear reaches farther than the sword.
	var far = await _dummy(spot + Vector2(78, 0))
	p.global_position = spot
	p._equip("sword")
	_swing()
	var sword_far: float = 999.0 - far.hp
	p.global_position = spot
	p._equip("spear")
	_swing()
	var spear_far: float = 999.0 - far.hp - sword_far
	_check(sword_far == 0.0 and spear_far > 0.0, "the spear reaches a foe the sword can't (%.0f vs %.0f)" % [spear_far, sword_far])
	_check(W.WEAPONS["spear"]["combo"][0]["arc"] < W.WEAPONS["sword"]["combo"][0]["arc"] and W.WEAPONS["greatsword"]["combo"][0]["arc"] > W.WEAPONS["axe"]["combo"][0]["arc"], "the spear is narrow, the greatsword sweeps widest")
	far.queue_free()
	# The axe's and greatsword's wide arcs catch a foe off to the side.
	var wide = await _dummy(spot + Vector2(10, 40))  # about 76 degrees off your aim
	p.global_position = spot
	p._equip("sword")
	_swing()
	var sword_side: float = 999.0 - wide.hp
	p.global_position = spot
	p._equip("greatsword")
	_swing()
	_check(sword_side == 0.0 and 999.0 - wide.hp > 0.0, "the greatsword's sweep catches a foe beside you that the sword misses")
	wide.queue_free()
	await _frames(1)
	# The dagger: a bigger backstab.
	var back = await _dummy(spot + Vector2(30, 0))
	back.face = Vector2.RIGHT  # facing away
	p.global_position = spot
	p._equip("dagger")
	_swing()
	var dagger_back: float = 999.0 - back.hp
	back.hp = 999.0
	p.global_position = spot
	p._equip("sword")
	_swing()
	var sword_back: float = 999.0 - back.hp
	var dagger_ratio: float = dagger_back / dealt["dagger"]
	var sword_ratio: float = sword_back / dealt["sword"]
	_check(dagger_ratio > sword_ratio + 0.3, "dagger backstabs bite deeper (x%.1f vs the sword's x%.1f)" % [dagger_ratio, sword_ratio])
	back.queue_free()
	await _frames(1)
	# Maces and hammers rock a monster out of its wind-up; a sword's light hit doesn't.
	for id in ["sword", "mace"]:
		var foe = await _dummy(spot + Vector2(30, 0))
		foe.state = "wind"
		foe.state_t = 0.5
		foe.glinted = false
		foe.flinch_cd = 0.0
		main.attackers.clear()
		main.request_attack(foe)
		p.global_position = spot
		p._equip(id)
		_swing()
		if id == "sword":
			_check(foe.state == "wind", "a sword's light hit doesn't stop a wind-up")
		else:
			_check(foe.state != "wind", "...but even a mace's first blow rocks the monster out of it")
		foe.queue_free()
		await _frames(1)
	# The war hammer's finisher staggers.
	var anvil = await _dummy(spot + Vector2(30, 0))
	p.global_position = spot
	p._equip("war_hammer")
	_swing()
	_check(anvil.stun <= 0.0, "the hammer's first blow doesn't stagger")
	p.global_position = spot
	_swing(true)
	_check(p.swing["heavy"] and anvil.stun > 0.0, "the war hammer's finisher staggers (%.2f s)" % anvil.stun)
	anvil.queue_free()
	await _frames(1)

	print("bows and the crossbow")
	_check(W.WEAPONS["longbow"]["draw_time"] > W.WEAPONS["shortbow"]["draw_time"] and W.WEAPONS["longbow"]["dmg_max"] > W.WEAPONS["shortbow"]["dmg_max"], "the longbow draws slower and hits harder")
	_check(W.WEAPONS["longbow"]["move_mult"] < W.WEAPONS["shortbow"]["move_mult"], "...and you walk slower while drawing it")
	var ranges: Array = []
	for id in ["shortbow", "longbow"]:
		ranges.append(float(W.WEAPONS[id]["speed_max"]) * float(W.WEAPONS[id]["life"]))
	_check(ranges[1] > ranges[0], "...and its arrows fly farther (%d vs %d)" % [int(ranges[1]), int(ranges[0])])
	var shot_dmg := {}
	for id in ["shortbow", "longbow"]:
		p.take_gear(id)
		var target = await _dummy(spot + Vector2(150, 0))
		p.global_position = spot
		p.aim = Vector2.RIGHT
		p.attack_cd = 0.0
		p.sta = p.MAX_STA
		_check(p._try_attack() and p.drawing, "the %s draws" % id)
		p.draw_t = 2.0
		p.release_draw()
		await _wait(0.4)
		shot_dmg[id] = 999.0 - target.hp
		target.queue_free()
		await _frames(1)
	_check(shot_dmg["shortbow"] > 0.0 and shot_dmg["longbow"] > shot_dmg["shortbow"], "both bows hit; a full longbow shot hits harder (%s)" % str(shot_dmg))
	# The crossbow: press to fire, then a reload you can't skip.
	var old: Dictionary = p.take_gear("crossbow")
	_check(G.base_id(old) == "longbow" and p.weapon == "crossbow" and p.gear_id("ranged") == "crossbow", "taking a crossbow puts it in the ranged slot and in hand (and hands back the longbow's record)")
	var mark = await _dummy(spot + Vector2(160, 0))
	p.global_position = spot
	p.aim = Vector2.RIGHT
	p.attack_cd = 0.0
	p.reload_t = 0.0
	p.sta = p.MAX_STA
	var bolts := func(): return main.get_children().filter(func(c): return "style" in c and c.friendly and c.style == "bolt")
	_check(p._try_attack() and not p.drawing, "the crossbow fires at once (no drawing)")
	_check(bolts.call().size() == 1 and bolts.call()[0].heavy, "...a heavy bolt")
	_check(p.reload_t > 1.0, "...then it must reload (%.2f s)" % p.reload_t)
	await _wait(0.35)
	_check(999.0 - mark.hp >= 20.0, "the bolt hits hard (%.0f)" % (999.0 - mark.hp))
	p.attack_cd = 0.0
	_check(not p._try_attack() and bolts.call().is_empty(), "no second bolt while reloading")
	# You can walk while it reloads.
	var x0: float = p.global_position.x
	Input.action_press("move_down")
	await _wait(0.2)
	Input.action_release("move_down")
	_check(p.reload_t > 0.0 and p.global_position.y > spot.y + 10.0, "you can walk while reloading (%.0f px)" % (p.global_position.y - spot.y))
	await _wait(0.8)
	_check(p.reload_t <= 0.0, "the reload finishes after about 1.1 s")
	p.global_position = spot
	p.aim = Vector2.RIGHT
	p.attack_cd = 0.0
	_check(p._try_attack() and bolts.call().size() == 1, "then it fires again")
	await _wait(0.3)
	# Hunter: Hawk's Eye and Quarry work with bolts too.
	_mark("brow", "hunter", 5)
	p = main.player
	p.reload_t = 0.0
	p.attack_cd = 0.0
	mark.hp = 999.0
	p.quarry = null
	p.global_position = spot
	p.aim = Vector2.RIGHT
	_cast("brow", "hawks_eye")
	p._try_attack()
	await _wait(0.35)
	_check(999.0 - mark.hp >= float(W.WEAPONS["crossbow"]["dmg"]) * 1.9, "Hawk's Eye doubles a crossbow bolt (%.0f)" % (999.0 - mark.hp))
	_check(p.quarry == mark, "Quarry remembers the foe a bolt struck")
	p.hawk_t = 0.0
	var proj := func(): return main.get_children().filter(func(c): return "return_to" in c and c.friendly)
	mark.queue_free()
	await _wait(0.3)
	for c in proj.call():
		c.queue_free()
	await _frames(1)
	# Blade Forger's Weapon Memory takes after any weapon's class.
	_mark("hand", "blade_forger", 5)
	var counts := {}
	var speeds := {}
	for id in ["dagger", "sword", "greatsword", "crossbow"]:
		p._equip(id)
		var before: Array = proj.call()
		_cast("hand", "conjured_blades")
		var thrown: Array = proj.call().filter(func(c): return not (c in before))
		counts[id] = thrown.size()
		speeds[id] = thrown[0].vel.length() if not thrown.is_empty() else 0.0
		for c in proj.call():
			c.queue_free()
		await _frames(1)
	_check(counts["dagger"] == counts["sword"] + 2 and counts["greatsword"] == counts["sword"] - 1, "Weapon Memory: a dagger throws more blades, a greatsword fewer (%s)" % str(counts))
	_check(speeds["crossbow"] > speeds["sword"] + 100.0, "...and a crossbow throws fast darts (%.0f vs %.0f)" % [speeds["crossbow"], speeds["sword"]])

	print("armor")
	await _fresh_main()
	p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	var taken := {}
	var roll_cost := {}
	var roll_speed := {}
	for id in G.ARMOR_ORDER:
		p.gear["armor"] = G.make(id)
		p.hp = p.MAX_HP
		p.hurt_t = 0.0
		p.iframes = 0.0
		p.parry_t = 0.0
		p.receive_attack(20.0, null)
		taken[id] = p.MAX_HP - p.hp
		p.sta = p.MAX_STA
		p.roll_cd = 0.0
		p.attack_cd = 0.0
		p._try_roll(Vector2.RIGHT)
		roll_cost[id] = p.MAX_STA - p.sta
		roll_speed[id] = p.roll_speed
		p.roll_t = 0.0
		p.iframes = 0.0
	_check(absf(taken[""] - 20.0) < 0.01 and absf(taken["plate"] - 13.0) < 0.01, "armor cuts a landed hit: 20 without, 13 in plate (%s)" % str(taken))
	_check(taken["padded"] > taken["leather"] and taken["leather"] > taken["chain"] and taken["chain"] > taken["plate"], "heavier armor protects more")
	_check(roll_cost["plate"] > roll_cost["chain"] and roll_cost["chain"] > roll_cost["leather"] and roll_cost["leather"] > roll_cost[""], "heavier armor makes rolls cost more (%s)" % str(roll_cost))
	_check(roll_speed["plate"] < roll_speed[""], "...and carry you less far")
	_check(G.ARMOR["plate"]["regen"] < 1.0 and G.ARMOR["plate"]["walk"] < 1.0, "plate slows your stamina and your walk a little")
	# Poison ticks past armor.
	p.gear["armor"] = G.make("plate")
	p.hp = 100.0
	p.poison(0.6)
	await _wait(0.75)
	_check(p.hp <= 98.0, "poison isn't reduced by armor (%.1f)" % p.hp)
	p.poison_t = 0.0
	p.gear["armor"] = {}

	print("finding gear")
	p.hp = p.MAX_HP
	p.global_position = spot
	# Walking over gear with an empty slot takes it.
	main.drop_gear(spot, "chain")
	await physics_frame
	await physics_frame
	_check(p.gear_id("armor") == "chain" and main.gear_drops.is_empty(), "walking over armor with none on puts it on")
	# Otherwise a prompt compares it, and Y swaps (dropping your old piece).
	main.drop_gear(spot + Vector2(4, 0), "axe")
	await physics_frame
	await physics_frame
	_check(p.gear_id("melee") == "sword" and not main.gear_here.is_empty() and main.gear_here["id"] == "axe" and G.base_id(main.gear_here["rec"]) == "axe", "with the slot full, gear waits for you to take it")
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await _frames(2)
	_check(p.gear_id("melee") == "axe" and p.weapon == "axe", "pressing Y takes the axe into your hand")
	_check(main.gear_drops.is_empty() and p.pack.size() == 1 and G.base_id(p.pack[0]) == "sword", "...and your sword goes in your pack")
	# With a full pack, your old piece is dropped where you stand instead.
	p.pack = [G.make("dagger"), G.make("mace"), G.make("spear"), G.make("padded")]
	main.drop_gear(spot + Vector2(4, 0), "sword")
	await physics_frame
	await physics_frame
	_check(main.take_gear_here() and p.gear_id("melee") == "sword", "you can swap straight back")
	var dropped: Array = main.gear_drops.filter(func(d): return d["id"] == "axe")
	_check(main.gear_drops.size() == 1 and dropped.size() == 1 and dropped[0]["pos"].distance_to(p.global_position) < 6.0, "...and with your pack full, the axe is dropped where you stand")
	p.pack = []
	main.gear_drops.clear()
	await physics_frame
	_check(main.gear_here.is_empty() and not main.take_gear_here(), "with no gear underfoot, Y does nothing")
	# 1, 2 and 3 pick the weapons in your slots.
	p.take_gear("longbow")
	p._equip("fists")
	await _wait(0.1)
	Input.action_press("weapon_3")
	await physics_frame
	await physics_frame
	Input.action_release("weapon_3")
	await _wait(0.1)
	_check(p.weapon == "longbow", "key 3 switches to the ranged weapon you carry (%s)" % p.weapon)
	Input.action_press("weapon_2")
	await physics_frame
	await physics_frame
	Input.action_release("weapon_2")
	await _wait(0.1)
	_check(p.weapon == "sword", "key 2 to the melee one (%s)" % p.weapon)
	# Drops.
	main.gear_drop_chance = 1.0
	main.item_drop_chance = 0.0
	var knight = await _spawn("knight", spot + Vector2(200, 0))
	_slay(knight)
	main.gear_drop_chance = G.DROP_CHANCE
	main.item_drop_chance = main.Items.DROP_CHANCE
	_check(main.gear_drops.size() == 1 and G.is_gear(main.gear_drops[0]["id"]), "a slain monster can drop gear (%s)" % (main.gear_drops[0]["id"] if not main.gear_drops.is_empty() else "none"))
	_check(G.DROP_CHANCE <= 0.05, "gear drops are rare (%d%%)" % int(G.DROP_CHANCE * 100.0))
	var favoured := 0
	for i in 400:
		if G.random_gear("archer") in G.FAVOUR["archer"]:
			favoured += 1
	# (Unfavoured, these would be about one drop in six; there are many more kinds of gear now.)
	_check(favoured > 140, "archers favour bows, crossbows, leather and caps (%d of 400)" % favoured)
	var never := true
	for i in 200:
		never = never and not (G.random_gear("", ["sword", "shortbow"]) in ["sword", "shortbow", "fists", ""])
	_check(never, "drops leave out what you carry")
	main.gear_drops.clear()
	# A side room's cache can hold gear.
	main.gear_cache_chance = 1.0
	for n in 30:
		main._start_floor(3)
		await _frames(1)
		if not main.cache.is_empty():
			break
	main.gear_cache_chance = G.CACHE_CHANCE
	for e in main.enemies():
		e.set_physics_process(false)
	_check(not main.cache.is_empty() and main.cache.has("gear"), "a side room's cache can hold a piece of gear")
	if not main.cache.is_empty():
		p.global_position = main.cache["pos"]
		await _frames(3)
		var cg: String = G.base_id(main.cache.get("gear", ""))
		var left: bool = main.gear_drops.size() == 1 and main.gear_drops[0]["id"] == cg
		_check(main.cache["taken"] and (left or cg in p.carried_gear()), "opening it leaves the gear on the floor (%s)" % cg)

	print("gear at a camp")
	await _fresh_main()
	p = main.player
	_mark("hand", "stormcaller", 1)
	main.floor_num = 3
	main._arrive()
	await _frames(2)
	var gear_cards: Array = main.camp["choices"].filter(func(c): return String(c).begins_with("gear:"))
	_check(main.camp_choosing and gear_cards.size() == 1, "the camp also offers a piece of gear (%s)" % str(gear_cards))
	var gi: int = main.camp["choices"].find(gear_cards[0])
	var card: Dictionary = main.camp_card(gi)
	var gcode: String = String(gear_cards[0]).substr(5)
	var gid: String = G.base_id(gcode)
	_check(G.base_id(card.get("gear", {})) == gid and card["name"] == G.display(gcode), "its card shows the gear")
	_check(String(G.SLOT_NAMES.get(G.slot_of(gid), "")) in card["note"], "...and names its slot (%s)" % card["note"])
	var slot: String = p.slot_for(gid)
	var had: String = p.gear_id(slot)
	main.choose_camp(gi)
	_check(p.gear_id(slot) == gid and not main.camp_choosing, "taking the gear card carries it (%s)" % gid)
	if had != "":
		var camp_dropped: bool = main.gear_drops.size() == 1 and main.gear_drops[0]["id"] == had
		var camp_packed: bool = p.pack.any(func(g): return G.base_id(g) == had)
		_check(camp_dropped or camp_packed, "...and puts your old %s in your pack, or leaves it by the fire" % had)

	print("the Take button on a phone")
	await _fresh_main()
	p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	_mark("hand", "stormcaller", 1)
	_mark("legs", "windwalker", 1)
	_mark("heart", "deepcaller", 1)
	_mark("brow", "warden", 1)
	_mark("throat", "flameblade", 1)
	_mark("back", "ashwalker", 1)
	p = main.player
	p.global_position = spot
	main.touch._set_active(true)
	await _frames(2)
	main.touch._layout()
	var ids: Array = main.touch.buttons.map(func(b): return b["id"])
	_check(not ("take" in ids), "no Take button away from gear")
	main.drop_gear(spot, "mace")
	await physics_frame
	await physics_frame
	main.touch._layout()
	var buttons: Array = main.touch.buttons
	ids = buttons.map(func(b): return b["id"])
	_check("take" in ids, "standing on gear shows the Take button")
	var take: Dictionary = buttons[ids.find("take")] if "take" in ids else {}
	var clear := not take.is_empty()
	var view: Vector2 = main.touch.get_viewport_rect().size
	if clear:
		clear = Rect2(Vector2.ZERO, view).has_point(take["c"]) and take["c"].x > view.x * 0.5
		for o in buttons:
			if o != take and take["c"].distance_to(o["c"]) < take["r"] + o["r"] + 2.0:
				clear = false
				print("    overlaps: take and ", o["id"])
	_check(clear, "the Take button is on the right, on screen, clear of every other button (six marks)")
	if not take.is_empty():
		_touch(7, take["c"], true)
		await _wait(0.15)
		_touch(7, take["c"], false)
		await _frames(2)
	_check(p.gear_id("melee") == "mace" and main.gear_drops.is_empty() and not p.pack.is_empty() and G.base_id(p.pack.back()) == "sword", "tapping Take swaps for the mace (the sword goes in your pack)")
	p.pack = []
	main.gear_drops.clear()
	await physics_frame
	await physics_frame
	main.touch._layout()
	_check(not ("take" in main.touch.buttons.map(func(b): return b["id"])), "the Take button goes away once there's no gear underfoot")
	main.touch._set_active(false)
	await _frames(2)

	print("gear in the menus")
	main.menu.open("inventory")
	await _frames(2)
	var labels: Array = _all_labels(main.menu).map(func(l): return l.text)
	_check(labels.any(func(t): return String(t).begins_with("Belt")) and "Mace" in labels and "Shortbow" in labels and "No armor" in labels, "the inventory lists your gear")
	main.menu.open("dev")
	await _frames(2)
	var dev_buttons: Array = _all_buttons(main.menu)
	var plate_btn: Array = dev_buttons.filter(func(b): return b.text == "Plate Armor")
	var hammer_btn: Array = dev_buttons.filter(func(b): return b.text == "War Hammer")
	_check(plate_btn.size() == 1 and hammer_btn.size() == 1, "the dev tools can give any weapon or armor")
	if plate_btn.size() == 1 and hammer_btn.size() == 1:
		plate_btn[0].pressed.emit()
		await _frames(1)
		_all_buttons(main.menu).filter(func(b): return b.text == "War Hammer")[0].pressed.emit()
		await _frames(1)
		_check(p.gear_id("armor") == "plate" and p.gear_id("melee") == "war_hammer" and p.weapon == "war_hammer", "...and pressing them does")
	var cap_btn: Array = _all_buttons(main.menu).filter(func(b): return b.text == "Leather Cap")
	_check(cap_btn.size() == 1, "...and any worn piece")
	if cap_btn.size() == 1:
		cap_btn[0].pressed.emit()
		await _frames(1)
		_check(p.gear_id("helm") == "leather_cap", "...which it puts on")
	main.menu.close()
	await _frames(2)


func _heirloom_tests() -> void:
	print("heirlooms")
	await _fresh_main()
	var p = main.player
	var G = main.Gear
	var slots: Array = G.HEIRLOOM_SLOTS.map(func(s): return s["id"])
	for want in ["melee", "ranged", "chest", "boots", "gloves", "helm", "legs", "rings", "amulet", "cloak", "backpack", "offhand"]:
		_check(want in slots, "heirloom slot: %s" % want)
	_check(G.heirloom_slot("plate") == "chest" and G.heirloom_slot("axe") == "melee" and G.heirloom_slot("crossbow") == "ranged", "armor is a chest heirloom, weapons melee or ranged")
	_check(G.heirloom_slot("iron_helm") == "helm" and G.heirloom_slot("garnet_ring") == "rings" and G.heirloom_slot("satchel") == "backpack", "a helm is a helm heirloom, a ring a Rings heirloom")
	_check(G.gear_slot_for("boots") == "boots" and G.gear_slot_for("offhand") == "" and G.heirloom_planned("offhand"), "the worn slots are real; the off-hand is kept for later")
	# Surviving a climb offers the carried gear as heirlooms.
	p.take_gear("axe")
	p.take_gear("chain")
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	_check(main.camp_choosing and main.camp["stage"] == "heirloom", "dismissing the victory screen offers an heirloom")
	_check(main.victory.is_empty(), "...in place of the victory screen")
	var picks: Array = main.camp["choices"]
	_check(picks.size() == 4 and "heir:axe" in picks and "heir:shortbow" in picks and "heir:chain" in picks and "heir:" in picks, "one card per carried piece, and one to keep nothing (%s)" % [picks])
	var ci: int = picks.find("heir:axe")
	_check(G.base_id(main.camp_card(ci)["gear"]) == "axe" and "melee" in main.camp_card(ci)["note"], "a card names the slot it fills")
	main.touch._set_active(true)
	await _frames(2)
	var size: Vector2 = main.hud.get_viewport_rect().size
	var at: Vector2 = main.hud.camp_card_rect(ci, size).get_center()
	_touch(7, at, true)
	await _frames(2)
	_touch(7, at, false)
	await _frames(2)
	_check(not main.camp_choosing and G.base_id(main.profile.heirlooms.get("melee", {})) == "axe", "tapping the axe keeps it as the melee heirloom")
	_check(main.profile.heirlooms["melee"] is Dictionary and main.profile.heirlooms["melee"].get("wear", 0.0) == 1.0, "...as a record, in full repair")
	# A new climb starts with it.
	var q = load("res://scripts/player.gd").new()
	q.main = main
	q.use_heirlooms(main.profile.heirlooms)
	_check(q.gear_id("melee") == "axe" and q.weapon == "axe" and q.gear_id("ranged") == "shortbow" and q.gear_id("armor") == "", "the next climb begins with the heirloom, the rest as usual")
	q.free()
	# The next survived climb: the axe is already an heirloom, so it isn't offered again.
	main.heirloom_offered = false
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	_check(not ("heir:axe" in main.camp["choices"]), "an heirloom already kept isn't offered again")
	ci = main.camp["choices"].find("heir:chain")
	_check("new chest" in main.camp_card(ci)["note"], "...and an empty slot says so")
	main.choose_camp(ci)
	_check(G.base_id(main.profile.heirlooms.get("chest", {})) == "chain" and G.base_id(main.profile.heirlooms.get("melee", {})) == "axe", "a second heirloom in another slot keeps the first")
	# Keep nothing new.
	main.heirloom_offered = false
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	main.choose_camp(main.camp["choices"].find("heir:"))
	_check(main.profile.heirlooms.size() == 2 and not main.camp_choosing, "keeping nothing new leaves the heirlooms as they are")
	# Falling isn't surviving: a fallen Regard offers nothing.
	main.heirloom_offered = false
	main.regard = {"fell": true, "part": "hand", "id": "", "t": 4.0}
	main.end_regard()
	_check(not main.camp_choosing, "a fall on the first climb offers no heirloom")
	main.regard = {}
	# The inventory's Heirlooms view shows them on the doll, the off-hand kept for later;
	# so does the climber screen's Record.
	main.menu.open("inventory")
	await _frames(2)
	var view_btn: Array = _all_buttons(main.menu).filter(func(b): return b.get_meta("view", "") == "heirlooms")
	_check(view_btn.size() == 1, "the inventory can show your heirlooms")
	if view_btn.size() == 1:
		view_btn[0].pressed.emit()
		await _frames(2)
	var texts: Array = _all_labels(main.menu).map(func(l): return l.text)
	var chest = _slot("heir:chest")
	var pack = _slot("heir:backpack")
	var off = _slot("heir:offhand")
	_check(chest != null and chest.id == "chain" and not chest.locked and "Backpack" in texts and pack != null and not pack.locked and pack.empty, "...with the kept chest and the empty slots")
	_check(off != null and off.locked, "...and the off-hand, locked")
	off.focus_entered.emit()
	await _frames(1)
	texts = _all_labels(main.menu).map(func(l): return l.text)
	_check(texts.any(func(t): return t.begins_with("Kept for later")), "...which says it's kept for later")
	main.menu.inv_view = "worn"
	main.menu.climber_tab = "record"
	main.menu.open("climber")
	await _frames(2)
	texts = _all_labels(main.menu).map(func(l): return l.text)
	_check("Chain Mail" in texts and "Axe" in texts, "the climber screen's Record lists the heirlooms")
	main.menu.climber_tab = "marks"
	main.menu.close()
	await _frames(2)
	# A new climber forgets them.
	main.profile.reset()
	_check(main.profile.heirlooms.is_empty(), "a new climber has no heirlooms")


## Gear records, the worn slots (helm to backpack), the protection cap,
## wear on Common pieces, the heirloom choice with the new slots and two
## rings, and the inventory's paper doll.
func _gear_slot_tests() -> void:
	print("gear records")
	await _fresh_main()
	var p = main.player
	var G = main.Gear
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	# Records: an old plain id becomes a fresh record; codes round-trip.
	var r: Dictionary = G.rec("axe")
	_check(r.get("base", "") == "axe" and r.get("rarity", "") == "common" and r.get("traits", null) == [] and r.get("rank", -1) == 0 and r.get("wear", 0.0) == 1.0, "an old id becomes a record: base, rarity, traits, rank, wear (%s)" % [r])
	_check(not G.make("garnet_ring").has("wear") and G.make("garnet_ring")["rarity"] == "fine", "rings and amulets are Fine and carry no wear")
	_check(G.rec("") == {} and G.rec("nonsense") == {} and G.rec({}) == {}, "nothing (or something unknown) is an empty record")
	var fancy: Dictionary = G.rec("axe;fine;2;edges")
	_check(fancy["rarity"] == "fine" and fancy["rank"] == 2 and fancy["traits"] == ["edges"] and not fancy.has("wear"), "a card code keeps rarity, rank and traits (for later steps)")
	_check(G.code(fancy) == "axe;fine;2;edges" and G.code(G.make("axe")) == "axe" and G.same(G.rec(G.code(fancy)), fancy), "...and codes round-trip")
	_check(G.base_id(G.make("chain")) == "chain" and G.base_id("chain") == "chain" and G.display(G.make("chain")) == "Chain Mail", "every helper takes a record or a plain id")
	# Old saves: heirlooms kept as plain ids convert on load (and bad ones are dropped).
	var old_save := {"melee": "axe", "chest": "chain", "helm": "nonsense", "boots": "axe", "rings": "garnet_ring", "offhand": "dagger"}
	var conv: Dictionary = G.load_heirlooms(old_save)
	_check(conv.has("melee") and conv["melee"] is Dictionary and conv["melee"]["base"] == "axe" and conv["chest"]["base"] == "chain", "old saved heirlooms (plain ids) become records")
	_check(not conv.has("helm") and not conv.has("boots") and not conv.has("offhand"), "...unknown pieces, pieces in the wrong slot and the off-hand are dropped (%s)" % [conv.keys()])
	_check(conv.get("rings", []) is Array and conv["rings"].size() == 1 and conv["rings"][0]["base"] == "garnet_ring", "...and a lone ring becomes the Rings list")
	# Records survive the save file (ConfigFile) and load back the same.
	var cfg := ConfigFile.new()
	var kept := {"melee": G.make("axe"), "helm": G.make("iron_helm"), "rings": [G.make("garnet_ring"), G.make("iron_band")]}
	cfg.set_value("profile", "heirlooms", kept)
	cfg.save("user://items_test.cfg")
	var cfg2 := ConfigFile.new()
	cfg2.load("user://items_test.cfg")
	var back: Dictionary = G.load_heirlooms(cfg2.get_value("profile", "heirlooms", {}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://items_test.cfg"))
	_check(G.same(back["melee"], kept["melee"]) and G.same(back["helm"], kept["helm"]) and back["rings"].size() == 2, "heirloom records save and load back the same")
	# A climb starts from plain-id heirlooms too.
	var q = load("res://scripts/player.gd").new()
	q.main = main
	q.use_heirlooms({"melee": "spear", "rings": ["garnet_ring", "iron_band"], "helm": G.make("leather_cap")})
	_check(q.gear_id("melee") == "spear" and q.gear_id("ring1") == "garnet_ring" and q.gear_id("ring2") == "iron_band" and q.gear_id("helm") == "leather_cap", "a climb starts with old or new heirlooms in their slots, both rings on")
	q.free()

	print("the worn slots")
	_check(G.DOLL.size() == 4 and G.DOLL[0] == ["helm", "amulet", "cloak"] and G.DOLL[1] == ["melee", "armor", "ranged"] and G.DOLL[2] == ["ring1", "gloves", "ring2"] and G.DOLL[3] == ["backpack", "legs", "boots"], "the doll: helm amulet cloak / melee chest ranged / ring gloves ring / backpack legs boots")
	var pieces_by_slot := {}
	for id in G.PIECES:
		var sl: String = G.PIECES[id]["slot"]
		pieces_by_slot[sl] = pieces_by_slot.get(sl, 0) + 1
	_check(G.PIECE_SLOTS.all(func(sl): return pieces_by_slot.get(sl, 0) >= 2), "every worn slot has pieces (%s)" % [pieces_by_slot])
	var common := 0
	for id in G.PIECES:
		if G.PIECES[id].get("rarity", "common") == "common":
			common += 1
	_check(common == 16, "the sixteen Common pieces (%d)" % common)
	var words := ""
	for id in G.PIECES:
		words += " " + String(G.PIECES[id]["name"]) + " " + String(G.PIECES[id]["desc"])
	words = words.to_lower()
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return words.contains(w)), "no borrowed words in the pieces' text")
	# Health: Leather Cap +8, Bone Charm +10.
	var hp0: float = p.max_hp
	p.take_gear("leather_cap")
	_check(is_equal_approx(p.max_hp, hp0 + 8.0) and is_equal_approx(p.hp, hp0 + 8.0), "a Leather Cap: +8 max health (%.0f)" % p.max_hp)
	p.take_gear("bone_charm")
	_check(is_equal_approx(p.max_hp, hp0 + 18.0) and p.gear_id("amulet") == "bone_charm", "...a Bone Charm on top: +10 more (%.0f)" % p.max_hp)
	main.dev_give_gear("-amulet")
	_check(is_equal_approx(p.max_hp, hp0 + 8.0) and p.hp <= p.max_hp, "taking it off takes the health away again")
	# Stamina: Padded Trousers +10.
	p.take_gear("padded_trousers")
	_check(is_equal_approx(p.max_sta, p.MAX_STA + 10.0), "Padded Trousers: +10 max stamina (%.0f)" % p.max_sta)
	p.sta = 0.0
	p.sta_delay = 0.0
	for i in 60:
		p._tick_timers(0.1)
	_check(p.sta > p.MAX_STA + 5.0, "...and stamina refills past the old 100 (%.0f)" % p.sta)
	# Protection: an Iron Helm (heavy) and Chain Leggings (heavy).
	p.take_gear("iron_helm")
	_check(absf(p.protection() - 0.06) < 0.001, "an Iron Helm: 6%% damage taken off (%.2f)" % p.protection())
	var cost := {}
	for setup in [["none", []], ["heavy2", ["iron_helm", "chain_leggings"]]]:
		main.dev_give_gear("-helm")
		main.dev_give_gear("-legs")
		for id in setup[1]:
			p.take_gear(id)
		p.sta = p.max_sta
		p.roll_cd = 0.0
		p.attack_cd = 0.0
		p._try_roll(Vector2.RIGHT)
		cost[setup[0]] = p.max_sta - p.sta
		p.roll_t = 0.0
		p.iframes = 0.0
	_check(absf(cost["heavy2"] / cost["none"] - 1.06) < 0.005, "two heavy pieces make a roll cost 6%% more (%s)" % [cost])
	_check(absf(p.protection() - 0.11) < 0.001, "the helm's and leggings' protection add up (%.2f)" % p.protection())
	# The 50% cap: plate, helm and chain leggings make 46%; anything past 50% is capped.
	p.take_gear("plate")
	_check(absf(p.protection() - 0.46) < 0.001, "plate, an iron helm and chain leggings: 46%% (%.2f)" % p.protection())
	p.hp = p.max_hp
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	var before: float = p.hp
	p.receive_attack(20.0, null)
	_check(absf((before - p.hp) - 10.8) < 0.05, "...a 20-damage blow lands for 10.8 (%.1f)" % (before - p.hp))
	_check(absf(G.protection(p.gear, {"reduce": 0.4}) - G.PROTECTION_CAP) < 0.001 and G.PROTECTION_CAP == 0.5, "protection is capped at 50%")
	main.dev_give_gear("")
	main.dev_give_gear("-helm")
	main.dev_give_gear("-legs")
	# Strikes: Leather Gloves +4%, Garnet Rings +4% each (both rings count).
	var dealt := {}
	var stam := {}
	for setup in [["none", []], ["gloves", ["leather_gloves"]], ["rings", ["garnet_ring", "garnet_ring"]], ["wraps", ["grip_wraps"]]]:
		main.dev_give_gear("-gloves")
		main.dev_give_gear("-ring")
		for id in setup[1]:
			p.take_gear(id)
		p._equip("sword")
		p.global_position = Vector2(500, 400)
		p.aim = Vector2.RIGHT
		var d = await _dummy(Vector2(530, 400))
		p.sta = p.max_sta
		_swing()
		dealt[setup[0]] = 999.0 - d.hp
		stam[setup[0]] = p.max_sta - p.sta
		d.queue_free()
		await _frames(1)
	_check(p.gear_id("gloves") == "grip_wraps" and absf(dealt["gloves"] / dealt["none"] - 1.04) < 0.01, "Leather Gloves: strikes hit 4%% harder (%s)" % [dealt])
	_check(absf(dealt["rings"] / dealt["none"] - 1.08) < 0.01, "two Garnet Rings: both count, 8% harder")
	_check(absf(stam["wraps"] / stam["none"] - 0.94) < 0.01, "Grip Wraps: strike chains cost 6%% less stamina (%s)" % [stam])
	main.dev_give_gear("-ring")
	# Gauntlets: harder strikes, a shorter parry window.
	p.take_gear("gauntlets")
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	p._try_parry()
	_check(absf(p.parry_window - p.PARRY_WINDOW * 0.95) < 0.001 and absf(p.gfx("strike") - 0.07) < 0.001, "Gauntlets: +7% strikes, a 5% shorter parry window")
	p.parry_t = 0.0
	main.dev_give_gear("-gloves")
	# Leather Leggings: rolls carry 5% farther.
	var reach := {}
	for setup in [["none", ""], ["leggings", "leather_leggings"]]:
		main.dev_give_gear("-legs")
		if setup[1] != "":
			p.take_gear(setup[1])
		p.sta = p.max_sta
		p.roll_cd = 0.0
		p.attack_cd = 0.0
		p._try_roll(Vector2.RIGHT)
		reach[setup[0]] = p.roll_speed
		p.roll_t = 0.0
		p.iframes = 0.0
	_check(absf(reach["leggings"] / reach["none"] - 1.05) < 0.005, "Leather Leggings: rolls carry 5% farther")
	main.dev_give_gear("-legs")
	# Boots: Soft Boots walk faster; Climbing Boots jump free and farther; Hobnail Boots stand firm.
	p.take_gear("soft_boots")
	_check(absf(p.gfx("walk") - 0.04) < 0.001, "Soft Boots: you walk 4% faster")
	p.take_gear("climbing_boots")
	p.sta = 50.0
	p.roll_t = 0.0
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p._try_jump(Vector2.RIGHT)
	_check(p.sta == 50.0 and absf(p.jump_vel.length() - p.WALK * 1.1) < 0.5, "Climbing Boots: a jump costs no stamina and carries 10% farther")
	p.jump_t = 0.0
	p.take_gear("hobnail_boots")
	var brute = await _spawn("knight", p.global_position + Vector2(40, 0))
	for dmg in [10.0, 20.0]:
		p.hurt_t = 0.0
		p.iframes = 0.0
		p.parry_t = 0.0
		p.knock = Vector2.ZERO
		p.receive_attack(dmg, brute)
		if dmg < G.LIGHT_BLOW:
			_check(p.knock == Vector2.ZERO, "Hobnail Boots: a light blow can't knock you back")
		else:
			_check(p.knock != Vector2.ZERO, "...a heavy one still does")
	_check(absf(p.gfx("walk") + 0.03) < 0.001 and p.gfx("heavy") == 1.0, "...and they slow you 3% and are heavy")
	brute.queue_free()
	main.dev_give_gear("-boots")
	p.hp = p.max_hp
	# Cloaks: the Travel Cloak shortens poison; the Dusk Cloak keeps monsters slower to notice you.
	p.take_gear("travel_cloak")
	p.poison_t = 0.0
	p.poison(4.0)
	_check(absf(p.poison_t - 3.0) < 0.01, "a Travel Cloak: poison wears off 25%% sooner (%.2f s)" % p.poison_t)
	p.poison_t = 0.0
	p.take_gear("dusk_cloak")
	var slowest := 99.0
	for i in 8:
		var k = await _spawn("knight", Vector2(900, 400))
		slowest = minf(slowest, k.notice_t)
		k.queue_free()
	_check(slowest >= 1.2 * 1.2 - 0.01, "a Dusk Cloak: monsters notice you 20%% later (at least %.2f s)" % slowest)
	main.dev_give_gear("-cloak")
	# The Cloth Hood: your light reaches farther.
	var reach0: float = main.lighting.player_reach()
	p.take_gear("cloth_hood")
	_check(absf(main.lighting.player_reach() / reach0 - 1.1) < 0.001, "a Cloth Hood: your light reaches 10% farther")
	main.dev_give_gear("-helm")
	# The Satchel: one more of each item (the recall scroll stays one).
	p.take_gear("satchel")
	_check(p.max_stack("draught") == 4 and p.max_stack("scroll") == 1, "a Satchel: carry 4 of each item (the scroll stays one)")
	for i in 5:
		p.add_item("tonic")
	_check(p.item_count("tonic") == 4, "...and you can (%d tonics)" % p.item_count("tonic"))
	main.dev_give_gear("-backpack")
	_check(p.max_stack("draught") == 3, "without it, back to 3")
	# The Ember Charm: spells hit harder; the Iron Band: stamina refills faster.
	_mark("hand", "stormcaller", 1)
	p = main.player
	var pw0: float = p.bonds["hand"].power()
	p.take_gear("ember_charm")
	_check(absf(p.bonds["hand"].power() / pw0 - 1.06) < 0.001, "an Ember Charm: spells hit 6% harder")
	p.take_gear("iron_band")
	_check(absf(p.gfx("regen") - 0.05) < 0.001 and p.gear_id("ring1") == "iron_band", "an Iron Band: stamina refills 5% faster")
	# Drops: any slot, modest chances; no rings or amulets on the first climb;
	# the Belt Pouch now that the belt exists; pieces Rare by nature only with a Rare roll.
	var slots_seen := {}
	var trinket_first := false
	var pouch := false
	var rare_natural := false
	for i in 1500:
		var id: String = G.random_gear("")
		slots_seen[G.slot_of(id)] = true
		pouch = pouch or id == "belt_pouch"
		rare_natural = rare_natural or G.natural_rarity(id) == "rare"
		trinket_first = trinket_first or G.slot_of(G.random_gear("", [], false)) in ["ring", "amulet"]
	_check(["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring", "backpack"].all(func(sl): return slots_seen.has(sl)), "drops can be any slot (%s)" % [slots_seen.keys()])
	_check(not trinket_first and pouch and not rare_natural, "no rings or amulets on the first climb; the Belt Pouch is found; Rare pieces need a Rare roll")
	_check(G.DROP_CHANCE <= 0.05 and G.CACHE_CHANCE <= 0.4, "drop chances stay modest")

	print("wear")
	await _fresh_main()
	p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.take_gear("leather_gloves")
	p.take_gear("garnet_ring")
	_check(G.wears(p.gear["gloves"]) and not G.wears(p.gear["ring1"]) and G.wears(p.gear["melee"]), "Common pieces wear (gloves, the sword); a Fine ring doesn't")
	var d = await _dummy(Vector2(530, 400))
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	_swing()
	_check(p.gear["melee"]["wear"] < 1.0 and p.gear["gloves"]["wear"] < 1.0, "a landed strike wears the weapon and gloves a little")
	d.queue_free()
	await _frames(1)
	p.gear["gloves"]["wear"] = 0.26
	p.refresh_gear()
	var full: float = p.gfx("strike")
	p.wear_gear("strike", 20.0)
	_check(G.is_worn(p.gear["gloves"]) and absf(p.gfx("strike") - (full - 0.02)) < 0.001, "badly worn (25%%), a piece's bonus halves (%.3f -> %.3f)" % [full, p.gfx("strike")])
	_check(G.describe(p.gear["gloves"]).any(func(l): return String(l).begins_with("Badly worn")), "...and its card says so")
	p.wear_gear("strike", 1000.0)
	_check(p.gear_id("gloves") == "" and p.gear_id("ring1") == "garnet_ring", "worn out, it breaks; the ring is untouched")
	var fine_gloves: Dictionary = G.make("leather_gloves", "fine")
	p.take_gear(fine_gloves)
	p.wear_gear("strike", 1000.0)
	_check(p.gear_id("gloves") == "leather_gloves" and not fine_gloves.has("wear"), "a piece better than Common never wears")
	_check(p.gear_id("melee") == "" and p.weapon == "fists", "(the sword wore out with them: you fight with your fists)")
	# A badly worn weapon hits softer; a broken one leaves you your fists.
	p.take_gear("sword")
	p.gear["melee"]["wear"] = 0.2
	main.dev_give_gear("-gloves")
	main.dev_give_gear("-ring")
	var d2 = await _dummy(Vector2(530, 400))
	p.global_position = Vector2(500, 400)
	_swing()
	var worn_hit: float = 999.0 - d2.hp
	_check(absf(worn_hit - p.STRIKE_DAMAGE * p.attr_strength * G.WORN_WEAPON) < 0.6, "a badly worn sword hits 25%% softer (%.1f)" % worn_hit)
	d2.queue_free()
	p.gear["melee"]["wear"] = 0.0005
	p.wear_gear("strike")
	_check(p.gear_id("melee") == "" and p.weapon == "fists", "a sword worn out breaks, and you fight with your fists")
	p.take_gear("sword")
	_check(G.heirloom_copy(G.rec({"base": "axe", "wear": 0.1})).get("wear", 0.0) == 1.0, "an heirloom is kept in full repair")
	# Hits wear the chest, helm, legs and cloak; rolls wear boots.
	p.take_gear("leather")
	p.take_gear("iron_helm")
	p.take_gear("soft_boots")
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(5.0, null)
	_check(p.gear["armor"]["wear"] < 1.0 and p.gear["helm"]["wear"] < 1.0 and p.gear["boots"]["wear"] == 1.0, "a blow that lands wears the chest and helm, not the boots")
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p._try_roll(Vector2.RIGHT)
	_check(p.gear["boots"]["wear"] < 1.0, "a roll wears the boots")

	print("heirlooms in every slot")
	await _fresh_main()
	p = main.player
	for id in ["axe", "chain", "leather_cap", "leather_gloves", "padded_trousers", "soft_boots", "travel_cloak", "bone_charm", "garnet_ring", "iron_band", "satchel"]:
		p.take_gear(id)
	_check(p.gear_id("ring1") == "garnet_ring" and p.gear_id("ring2") == "iron_band", "a second ring goes on the other hand")
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	var picks: Array = main.camp["choices"]
	_check(main.camp_choosing and picks.size() == 12, "survived: a card for every slot you fill, and keep nothing (%d)" % picks.size())
	_check("heir:rings" in picks and not ("heir:garnet_ring" in picks) and not ("heir:iron_band" in picks), "...the rings on one card, kept together")
	var ri: int = picks.find("heir:rings")
	var rcard: Dictionary = main.camp_card(ri)
	_check("Garnet Ring" in rcard["desc"] and "Iron Band" in rcard["desc"] and "rings" in rcard["note"], "...which names both rings")
	# Twelve cards fit the screen in two rows, on a computer and a phone.
	for touch in [false, true]:
		main.touch._set_active(touch)
		await _frames(2)
		var size: Vector2 = main.hud.get_viewport_rect().size
		var fit := true
		for i in picks.size():
			var cr: Rect2 = main.hud.camp_card_rect(i, size)
			fit = fit and Rect2(Vector2.ZERO, size).encloses(cr)
			for j in picks.size():
				if j != i and cr.intersects(main.hud.camp_card_rect(j, size)):
					fit = false
		_check(fit and main.hud.camp_per_row() == 6, "...twelve cards in two rows, all on screen, none overlapping (%s)" % ("phone" if touch else "computer"))
	main.touch._set_active(false)
	await _frames(1)
	# Keys: down moves to the second row.
	main.card_focus = 0
	await _key_tap(KEY_DOWN)
	_check(main.card_focus == 6, "down moves to the second row of cards (%d)" % main.card_focus)
	main.choose_camp(ri)
	var kept_rings: Array = G.heirloom_pieces(main.profile.heirlooms, "rings")
	_check(kept_rings.size() == 2 and kept_rings.map(func(k): return k["base"]) == ["garnet_ring", "iron_band"], "taking it keeps both rings as the Rings heirloom")
	var q2 = load("res://scripts/player.gd").new()
	q2.main = main
	q2.use_heirlooms(main.profile.heirlooms)
	_check(q2.gear_id("ring1") == "garnet_ring" and q2.gear_id("ring2") == "iron_band" and q2.gear_id("helm") == "", "the next climb begins with both rings on")
	q2.free()
	main.heirloom_offered = false
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	picks = main.camp["choices"]
	_check(not ("heir:rings" in picks) and "heir:leather_cap" in picks, "rings already kept aren't offered again; the helm still is")
	main.choose_camp(picks.find("heir:leather_cap"))
	_check(G.base_id(main.profile.heirlooms.get("helm", {})) == "leather_cap" and G.heirloom_pieces(main.profile.heirlooms, "rings").size() == 2, "a helm heirloom joins them")
	main.heirloom_offered = false
	main.camp_choosing = false

	print("the paper doll")
	await _fresh_main()
	p = main.player
	for id in ["axe", "iron_helm", "garnet_ring", "leather_gloves", "hobnail_boots"]:
		p.take_gear(id)
	p.gear["gloves"]["wear"] = 0.4
	main.profile.heirlooms = {"melee": G.make("axe")}
	main.drop_gear(p.global_position, "dagger")
	await physics_frame
	await physics_frame
	var menu = main.menu
	for touch in [false, true]:
		main.touch._set_active(touch)
		await _frames(2)
		menu.open("inventory", true)
		await _frames(3)
		var cells := {}
		var all_there := true
		for row in G.DOLL:
			for sl in row:
				var c = _slot("gear:" + sl)
				all_there = all_there and c != null
				if c != null:
					cells[sl] = c.get_global_rect()
		_check(all_there and _slot("gear:fists") != null and _slot("gear:offhand") != null and _slot("floor") != null, "the doll has every slot, fists, the off-hand and the gear at your feet (%s)" % ("phone" if touch else "computer"))
		if all_there:
			var rows_ok: bool = cells["helm"].position.y < cells["melee"].position.y and cells["melee"].position.y < cells["ring1"].position.y and cells["ring1"].position.y < cells["backpack"].position.y
			var cols_ok: bool = cells["helm"].position.x < cells["amulet"].position.x and cells["amulet"].position.x < cells["cloak"].position.x and absf(cells["armor"].position.x - cells["amulet"].position.x) < 1.0 and absf(cells["gloves"].position.x - cells["legs"].position.x) < 1.0
			var view: Rect2 = main.get_viewport().get_visible_rect()
			var on_screen := true
			for sl in cells:
				on_screen = on_screen and view.encloses(cells[sl])
			_check(rows_ok and cols_ok and on_screen, "...laid out like a body, all on screen")
		var gl = _slot("gear:gloves")
		_check(gl != null and gl.id == "leather_gloves" and absf(gl.wear - 0.4) < 0.001 and _slot("gear:ring1").wear < 0.0, "worn Commons show their condition; rings don't")
		_check(_slot("gear:melee").kept and not _slot("gear:helm").kept, "a worn heirloom is marked")
		_slot("floor").focus_entered.emit()
		await _frames(1)
		var texts: Array = _all_labels(menu).map(func(l): return l.text)
		_check(texts.any(func(t): return t.begins_with("Compared with yours")), "a weapon at your feet says how it plays against yours")
		var arrows: Array = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == load("res://scripts/menu.gd").CompareArrow)
		_check(arrows.size() >= 2 and arrows.any(func(a): return a.up) and arrows.any(func(a): return not a.up), "...with up and down arrows (%d)" % arrows.size())
		_slot("gear:gloves").focus_entered.emit()
		await _frames(1)
		texts = _all_labels(menu).map(func(l): return l.text)
		_check(texts.any(func(t): return t.contains("Condition 40%")), "a worn piece's card shows its condition")
		menu.close()
		await _frames(2)
	main.touch._set_active(false)
	# Two rings on: taking a ring from the floor asks which one to swap.
	main.gear_drops.clear()
	p.take_gear("iron_band")
	main.drop_gear(p.global_position, "garnet_ring")
	await physics_frame
	await physics_frame
	menu.open("inventory", true)
	await _frames(2)
	_slot("floor").focus_entered.emit()
	await _frames(1)
	var swaps: Array = _all_buttons(menu).filter(func(b): return b.text.begins_with("Swap for your"))
	_check(swaps.size() == 2, "with two rings on, a ring at your feet offers to swap either")
	if swaps.size() == 2:
		swaps[1].pressed.emit()
		await _frames(2)
	_check(p.gear_id("ring1") == "garnet_ring" and p.gear_id("ring2") == "garnet_ring" and main.gear_drops.is_empty() and p.pack.size() == 1 and G.base_id(p.pack[0]) == "iron_band", "...and swapping the second leaves the first on (the iron band goes in your pack)")
	p.pack = []
	menu.close()
	main.gear_drops.clear()
	await _frames(2)
	# The floor prompt names the slot.
	p.take_gear("dusk_cloak")
	main.drop_gear(p.global_position, "travel_cloak")
	await physics_frame
	await physics_frame
	_check(not main.gear_here.is_empty() and G.SLOT_NAMES[G.slot_of(main.gear_here["id"])] == "Cloak", "a cloak on the floor waits for you, for the cloak slot")
	main.gear_drops.clear()
	# The Entity explains the worn slots the first time one is found.
	_check(load("res://scripts/entity.gd").TIPS.has("gear_slots") and load("res://scripts/entity.gd").TIPS["gear_slots"]["group"] == "gear", "the Entity has a tip for the worn slots")
	Engine.set_meta("sixfold_tips", true)
	main.GuideScript.forget()
	main.drop_gear(p.global_position + Vector2(200, 0), "gauntlets")
	_check(main.GuideScript.queue.any(func(t): return t.get("id", "") == "gear_slots"), "finding a worn piece queues it")
	Engine.remove_meta("sixfold_tips")
	main.GuideScript.forget()
	main.GuideScript.queue.clear()
	main.gear_drops.clear()


func _rarity_tests() -> void:
	print("rarities and traits")
	await _fresh_main()
	var p = main.player
	var G = main.Gear
	var Essence = main.Essence
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	# Rarity by floor: the odds table, checked by rolling (tolerance 3.5 points).
	var n := 4000
	for setup in [[2, 0], [5, 0], [8, 0], [11, 0], [2, 1], [11, 1]]:
		var fl: int = setup[0]
		var counts := {"common": 0, "fine": 0, "rare": 0, "storied": 0}
		for i in n:
			var r: String = G.roll_rarity(fl, setup[1])
			counts[r] = counts.get(r, 0) + 1
		var want: Dictionary = G.rarity_odds(fl, setup[1])
		var close := true
		for r in want:
			var expect := float(want[r]) / 100.0
			if r == "storied" and fl < G.STORIED_FROM:
				expect = 0.0
			if r == "rare" and fl < G.STORIED_FROM:
				expect += float(want.get("storied", 0)) / 100.0
			if absf(float(counts.get(r, 0)) / n - expect) > 0.035:
				close = false
		_check(close, "floor %d%s: rarities follow the odds (%s)" % [fl, " (a row higher)" if setup[1] > 0 else "", counts])
	_check(G.rarity_odds(2, 1) == G.rarity_odds(5, 0) and G.rarity_odds(11, 1)["storied"] > G.rarity_odds(11, 0)["storied"], "vaults, caches and camps roll one row higher")
	var storied_low := false
	var at_least_ok := true
	for i in 600:
		storied_low = storied_low or G.roll_rarity(5, 1) == "storied"
		at_least_ok = at_least_ok and G.rarity_rank(G.roll_rarity(1, 0, "rare")) >= G.rarity_rank("rare")
	_check(not storied_low and at_least_ok, "Storied finds only from floor 7; a floor on rarity holds (the floor-9 camp's Rare)")
	# Traits: each has an essence kind and fits only its slots; finds roll the right number of fitting traits.
	var trait_ok := true
	for t in G.TRAITS:
		var d: Dictionary = G.TRAITS[t]
		trait_ok = trait_ok and Essence.KINDS.has(d["kind"]) and not d["slots"].is_empty() and float(d["rare"]) > float(d["fine"])
		for sl in d["slots"]:
			trait_ok = trait_ok and sl in ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring"]
	_check(trait_ok and G.TRAITS.size() == 14, "fourteen traits, each tied to an essence and to the slots it suits")
	var kinds_seen := {}
	for t in G.TRAITS:
		kinds_seen[G.TRAITS[t]["kind"]] = true
	_check(kinds_seen.size() == 6, "every essence has its traits (%s)" % [kinds_seen.keys()])
	var fits := true
	var right_count := true
	var by_rarity := {}
	for i in 900:
		var g: Dictionary = G.roll_gear("", [], true, 11, "kraken", 1)
		by_rarity[g["rarity"]] = by_rarity.get(g["rarity"], 0) + 1
		var tr: Array = g["traits"]
		var uniq := {}
		for t in tr:
			uniq[t] = true
			fits = fits and G.TRAITS.has(t) and G.trait_slot(g) in G.TRAITS[t]["slots"]
		fits = fits and uniq.size() == tr.size()
		var want_n: int = G.trait_count(g["base"], g["rarity"], String(g.get("named", "")))
		right_count = right_count and tr.size() == mini(want_n, G.traits_for(G.trait_slot(g)).size())
	_check(fits, "rolled traits always fit their slot, never twice on one piece")
	_check(right_count, "Fine pieces carry one trait, Rare two (rings and amulets one fewer), named pieces one (%s)" % [by_rarity])
	_check(G.trait_count("leather_gloves", "fine") == 1 and G.trait_count("leather_gloves", "rare") == 2 and G.trait_count("garnet_ring", "fine") == 0 and G.trait_count("garnet_ring", "rare") == 1, "...counted by natural rarity")
	# Names.
	var fg: Dictionary = G.make("leather_gloves", "fine", ["edges"])
	_check(G.display(fg) == "Fine Leather Gloves of Edges", "names: %s" % G.display(fg))
	_check(G.display(G.make("iron_helm", "rare", ["vigor", "calm"])) == "Rare Iron Helm of Vigor", "...and %s" % G.display(G.make("iron_helm", "rare", ["vigor", "calm"])))
	_check(G.display(G.make("garnet_ring")) == "Garnet Ring" and G.display(G.make("garnet_ring", "rare", ["calm"])) == "Rare Garnet Ring of Calm" and G.display("axe") == "Axe", "a ring is Fine by nature (no prefix); Common pieces keep their plain names")
	var trident: Dictionary = G.make_named("coral_trident")
	_check(G.display(trident) == "Coral Trident" and trident["base"] == "spear" and trident["rarity"] == "rare" and trident["traits"].size() == 1, "a named piece keeps its own name (and one trait)")
	_check(G.same(G.rec(G.code(trident)), trident) and G.display(G.code(trident)) == "Coral Trident", "...and its card code round-trips")
	# Never wear: anything with a trait, anything better than Common.
	_check(not G.make("leather_gloves", "common", ["edges"]).has("wear") and not fg.has("wear") and not trident.has("wear") and G.make("leather_gloves").has("wear"), "only plain Common pieces wear: trait pieces never do")
	p.take_gear(fg)
	p.wear_gear("strike", 5000.0)
	_check(p.gear_id("gloves") == "leather_gloves" and G.condition(p.gear["gloves"]) == 1.0, "...however hard they're used")
	# Tower pieces only in their own tower; Storied only from floor 7.
	_check(G.named_pool("rare", "kraken") == ["coral_trident", "barnacle_mail"] and G.named_pool("rare", "gryphon") == ["stormstring"], "tower pieces only come from their own tower")
	var wrong_tower := false
	var storied_early := false
	var named_seen := {}
	for i in 1500:
		var g: Dictionary = G.roll_gear("", [], true, 11, "gryphon", 1)
		if g.has("named"):
			named_seen[g["named"]] = true
			wrong_tower = wrong_tower or (G.NAMED[g["named"]].has("tower") and G.NAMED[g["named"]]["tower"] != "gryphon")
		storied_early = storied_early or G.rarity(G.roll_gear("", [], true, 5, "gryphon", 1)) == "storied"
	_check(not wrong_tower and named_seen.has("stormstring"), "in the Gryphon's tower only the Gryphon's piece turns up (%s)" % [named_seen.keys()])
	_check(not storied_early and named_seen.keys().any(func(k): return G.NAMED[k]["rarity"] == "storied"), "Storied pieces turn up high in the tower, never below floor 7")
	# Caps: strikes stop at +25%, health at +40.
	main.dev_give_gear("-gloves")
	p.take_gear(G.make("gauntlets", "rare", ["edges", "riposte"]))
	p.take_gear(G.make("garnet_ring", "rare", ["edges"]))
	p.take_gear(G.make("garnet_ring", "rare", ["edges"]))
	var raw: float = G.total_effects(p.gear, true)["strike"]
	_check(raw > G.CAPS["strike"] + 0.05 and absf(p.gfx("strike") - G.CAPS["strike"]) < 0.0001 and "strike" in G.capped_keys(p.gear), "gear's strike bonus stops at +25%% (%.2f raw)" % raw)
	var hp0: float = p.base_hp
	for id in ["iron_helm", "chain_leggings", "travel_cloak"]:
		p.take_gear(G.make(id, "rare", ["vigor"]))
	p.take_gear(G.make_named("heartstone"))
	p.take_gear(G.make("chain", "rare", ["vigor"]))
	_check(absf(p.max_hp - (hp0 + G.CAPS["health"])) < 0.01 and "health" in G.capped_keys(p.gear), "...health at +40 (%.0f)" % p.max_hp)
	var menu = main.menu
	menu.open("inventory", true)
	await _frames(2)
	_slot("gear:gloves").focus_entered.emit()
	await _frames(1)
	var texts: Array = _all_labels(menu).map(func(l): return l.text)
	_check(texts.any(func(t): return t.contains("(capped)")), "the inventory shows \"(capped)\" beside a capped number")
	_check(texts.any(func(t): return t.begins_with("of Edges:")) and texts.any(func(t): return t.begins_with("of the Riposte:")), "a Rare piece's card lists both its traits")
	_check(_slot("gear:gloves") != null and _slot("gear:gloves").rec != null and G.rarity(_slot("gear:gloves").rec) == "rare", "...and its slot knows its rarity (edged in its colour)")
	menu.close()
	await _frames(2)
	# A weapon's rarity: a Fine sword hits 5% harder, a Rare one 10%.
	for id in G.PIECE_SLOTS:
		main.dev_give_gear("-" + id)
	var dealt := {}
	for r in ["common", "fine", "rare"]:
		p.take_gear(G.make("sword", r))
		p._equip("sword")
		p.global_position = Vector2(500, 400)
		p.aim = Vector2.RIGHT
		var d = await _dummy(Vector2(530, 400))
		_swing()
		dealt[r] = 999.0 - d.hp
		d.queue_free()
		await _frames(1)
	_check(absf(dealt["fine"] / dealt["common"] - 1.05) < 0.01 and absf(dealt["rare"] / dealt["common"] - 1.10) < 0.01, "Fine weapons hit 5%% harder, Rare 10%% (%s)" % [dealt])
	# Traits do what they say: of Edges, of Calm, of Rolling, of the Hunt, of the Riposte.
	p.take_gear(G.make("leather_gloves", "fine", ["edges"]))
	_check(absf(p.gfx("strike") - 0.07) < 0.0001, "of Edges on Leather Gloves: 4% + 3% strikes")
	p.take_gear(G.make("iron_helm", "rare", ["calm"]))
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	p._try_parry()
	_check(absf(p.parry_window - p.PARRY_WINDOW * 1.08) < 0.001, "of Calm (Rare): the parry window 8% longer")
	p.parry_t = 0.0
	var cost := {}
	for setup in [["none", ""], ["rolling", "rolling"]]:
		main.dev_give_gear("-boots")
		if setup[1] != "":
			p.take_gear(G.make("soft_boots", "rare", [setup[1]]))
		p.sta = p.max_sta
		p.roll_cd = 0.0
		p.attack_cd = 0.0
		p._try_roll(Vector2.RIGHT)
		cost[setup[0]] = p.max_sta - p.sta
		p.roll_t = 0.0
		p.iframes = 0.0
	_check(absf(cost["rolling"] / cost["none"] - 0.92) < 0.005, "of Rolling (Rare): rolls cost 8%% less (%s)" % [cost])
	# of Thorns: a foe striking you up close takes some back.
	p.take_gear(G.make("leather", "rare", ["thorns"]))
	var brute = await _spawn("knight", p.global_position + Vector2(40, 0))
	var bhp: float = brute.hp
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(5.0, brute)
	_check(absf((bhp - brute.hp) - 5.0) < 0.01, "of Thorns (Rare): a foe that strikes you up close takes 5 (%.1f)" % (bhp - brute.hp))
	brute.queue_free()
	# of Footing: burning floor hurts less.
	p.take_gear(G.make("leather_leggings", "rare", ["footing"]))
	main.dev_give_gear("-cloak")
	p.hp = 100.0
	p.fire_t = 0.5
	p.iframes = 0.0
	p.stand_in_fire(0.01)
	_check(absf((100.0 - p.hp) - 3.0) < 0.01, "of Footing (Rare): burning floor hurts 25%% less (%.1f)" % (100.0 - p.hp))
	# of Embers: a strike can set the foe burning.
	var burner = await _dummy(Vector2(530, 400))
	burner.ignite(2.0, 2.0)
	var bhp2: float = burner.hp
	burner.set_physics_process(true)
	await _wait(0.6)
	_check(burner.hp < bhp2 and burner.burn_t > 0.0, "a burning foe takes damage every half second")
	burner.queue_free()
	# Named weapons: a Coral Trident slows; a Sunsteel Blade heals on a kill.
	p.take_gear(G.make_named("coral_trident"))
	p._equip("spear")
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	var cold = await _dummy(Vector2(540, 400))
	_swing()
	_check(cold.chill_t > 1.0, "a Coral Trident's hit slows the foe")
	cold.queue_free()
	p.take_gear(G.make_named("sunsteel_blade"))
	p._equip("sword")
	p.hp = 50.0
	var weak = await _dummy(Vector2(530, 400))
	weak.hp = 1.0
	_swing()
	_check(weak.dead and p.hp >= 53.9, "a Sunsteel Blade's kill heals you 4 (%.0f)" % p.hp)
	await _frames(1)
	# Comparing: traits count; "plays like" names the traits a weapon adds.
	var rows: Array = G.compare(G.make("leather_gloves", "fine", ["edges"]), G.make("leather_gloves"))
	_check(rows.any(func(r): return r[0] == "Strikes" and r[3] > 0), "comparing: a trait shows as a better number")
	var pl: String = G.plays_like(G.make("sword", "rare", ["embers", "edges"]), G.make("sword"))
	_check(pl.contains("adds Embers") and pl.contains("hits harder"), "\"plays like\" names traits and the rarity's harder hits: %s" % pl)
	_check(G.plays_like(G.make("sword"), G.make("sword", "fine", ["riposte"])).contains("loses Riposte"), "...and what yours had that this one lacks")
	# Drops: a Rare find fades in a notice; the floor label is in its colour.
	main.loot_notice = {}
	main.drop_gear(p.global_position + Vector2(200, 0), G.make("axe", "rare", ["edges", "riposte"]), true)
	_check(not main.loot_notice.is_empty() and String(main.loot_notice["text"]).begins_with("RARE:") and main.loot_notice["color"] == G.RARITIES["rare"]["color"], "a Rare find fades in a notice: %s" % main.loot_notice.get("text", ""))
	main.loot_notice = {}
	main.drop_gear(p.global_position + Vector2(200, 30), G.make("axe", "fine", ["edges"]), true)
	main.drop_gear(p.global_position + Vector2(200, 60), G.make("dagger", "rare", ["edges"]))
	_check(main.loot_notice.is_empty(), "...not a Fine one, nor your own old piece left on the floor")
	_check(G.rarity_color(G.make("axe", "fine", ["edges"])) == G.RARITIES["fine"]["color"] and G.NOTICE_FROM == "rare", "floor labels, slots, cards and glints use the rarity's colour")
	main.gear_drops.clear()
	# A camp's gear rolls a row higher; the floor-9 camp's is Rare.
	var camp_rare := true
	for i in 40:
		camp_rare = camp_rare and G.rarity_rank(G.rarity(main.find_gear("", 1, "rare"))) >= G.rarity_rank("rare")
	_check(camp_rare, "the floor-9 camp's gear is Rare (or better)")
	# Words: none of the borrowed ones.
	var words := ""
	for t in G.TRAITS:
		words += " " + G.TRAITS[t]["name"] + " " + G.TRAITS[t]["desc"]
	for k in G.NAMED:
		words += " " + G.NAMED[k]["name"] + " " + G.NAMED[k]["desc"]
	words = words.to_lower()
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return words.contains(w)), "no borrowed words in traits and named pieces")


func _belt_tests() -> void:
	print("the belt")
	await _fresh_main()
	var p = main.player
	var Items = main.Items
	var G = main.Gear
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	_check(p.belt_kinds() == 4 and Items.BELT_KINDS == 4 and p.max_stack("fire_flask") == 3, "the belt holds 4 kinds, 3 of each")
	p.items = {}
	for id in ["draught", "tonic", "smoke", "fire_flask"]:
		p.add_item(id)
	_check(p.carried().size() == 4 and not p.add_item("edge_oil") and p.item_room("edge_oil") == "belt", "a fifth kind doesn't fit a full belt")
	for i in 5:
		p.add_item("tonic")
	_check(p.item_count("tonic") == 3 and p.item_room("tonic") == "stack", "...and a stack stops at 3")
	p.take_gear("satchel")
	_check(p.max_stack("tonic") == 4 and p.max_stack("scroll") == 1 and p.belt_kinds() == 4, "a Satchel: 4 of each (the recall scroll stays one)")
	p.take_gear("belt_pouch")
	_check(p.belt_kinds() == 5 and p.max_stack("tonic") == 3 and p.add_item("edge_oil"), "a Belt Pouch: a fifth kind")
	p.take_gear(G.make("climbers_pack"))
	_check(p.belt_kinds() == 5 and p.max_stack("tonic") == 4 and p.max_stack("scroll") == 1 and G.rarity(p.gear["backpack"]) == "rare", "a Climber's Pack (Rare): a fifth kind and 4 of each")
	main.dev_give_gear("-backpack")
	p.items.erase("edge_oil")
	p.items["tonic"] = 3
	# The take card: stepping on a fifth kind with a full belt.
	main.item_drops.append({"pos": p.global_position, "id": "haste", "t": 40.0})
	await physics_frame
	await physics_frame
	_check(main.camp_choosing and main.camp.get("stage", "") == "belt" and main.camp["choices"].size() == 5, "stepping on a fifth kind shows the take card: a stack to swap out for each kind, or leave it")
	var leave: Dictionary = main.camp_card(4)
	var swap: Dictionary = main.camp_card(main.camp["choices"].find("belt:tonic"))
	_check(leave["name"] == Items.BELT["leave_name"] and swap["name"].contains("Tonic") and swap["item"] == "tonic", "...its cards name the stack and the choice to leave it")
	main.choose_camp(main.camp["choices"].find("belt:"))
	await physics_frame
	await physics_frame
	_check(not main.camp_choosing and p.item_count("haste") == 0 and main.item_drops.size() == 1, "leaving it: the belt is unchanged and it waits on the floor")
	await _frames(3)
	_check(not main.camp_choosing, "...and standing there doesn't ask again")
	p.global_position += Vector2(80, 0)
	await physics_frame
	await physics_frame
	p.global_position -= Vector2(80, 0)
	await physics_frame
	await physics_frame
	_check(main.camp_choosing and main.camp.get("stage", "") == "belt", "stepping off and back on asks again")
	main.choose_camp(main.camp["choices"].find("belt:tonic"))
	await physics_frame
	await physics_frame
	_check(p.item_count("haste") == 1 and p.item_count("tonic") == 0 and main.item_drops.filter(func(d): return d["id"] == "tonic").size() == 3, "swapping a stack out: the new item is on your belt, the old stack at your feet")
	await _frames(3)
	_check(not main.camp_choosing and p.item_count("tonic") == 0, "...and the dropped stack waits until you step away")
	main.item_drops.clear()
	# A camp's item with a full belt is left at your feet.
	var said: String = main._take_item("salts", "Took")
	_check(said.begins_with("Belt full") and main.item_drops.size() == 1 and main.item_drops[0]["id"] == "salts", "a card's item with a full belt waits at your feet: %s" % said)
	main.item_drops.clear()

	print("the new consumables")
	p.items = {}
	_check(Items.ORDER.size() == 13 and ["fire_flask", "edge_oil", "warding_oil", "haste", "stoneskin", "salts", "flare"].all(func(id): return Items.ITEMS.has(id) and Items.ITEMS[id].has("kind") and Items.ITEMS[id].has("value")), "seven new consumables, each with its essence and worth")
	# Fire Flask: thrown at your aim, it bursts and leaves burning floor.
	main.floor_num = 3
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	var foe = await _dummy(Vector2(640, 400))
	p.add_item("fire_flask")
	p.item_sel = "fire_flask"
	var fl0: int = main.flames.size()
	_check(p.use_item() and main.flasks.size() == 1, "a Fire Flask is thrown")
	_check(main.flasks[0]["to"].distance_to(Vector2(660, 400)) < 10.0, "...where you aim (%s)" % main.flasks[0]["to"])
	# (the burning floor it leaves bites at once too: 3 a tick)
	while not main.flasks.is_empty():
		await physics_frame
	var burst: float = 999.0 - foe.hp
	var want_dmg: float = 30.0 * 1.2
	_check(burst >= want_dmg - 0.5 and burst <= want_dmg + 3.5, "...it bursts for 30 (+10%% a floor): %.1f on floor 3" % burst)
	_check(main.flames.size() > fl0 and main.flames.back()["friendly"], "...and leaves burning floor that burns foes, not you")
	foe.queue_free()
	_mark("hand", "flame_contractor", 1)
	p = main.player
	p.add_item("fire_flask")
	p.item_sel = "fire_flask"
	p.use_item()
	_check(absf(main.flasks[0]["r"] - Items.ITEMS["fire_flask"]["radius"] * 1.5) < 0.01, "Flame Contractor: Fire Flasks burst 50% wider")
	await _wait(0.6)
	# Edge Oil: strikes 25% harder.
	var dealt := {}
	for oil in [false, true]:
		p.edge_t = 0.0
		if oil:
			p.add_item("edge_oil")
			p.item_sel = "edge_oil"
			p.use_item()
		p._equip("sword")
		p.global_position = Vector2(500, 400)
		var d = await _dummy(Vector2(530, 400))
		_swing()
		dealt[oil] = 999.0 - d.hp
		d.queue_free()
		await _frames(1)
	_check(absf(dealt[true] / dealt[false] - 1.25) < 0.01 and p.edge_t > 15.0, "Edge Oil: strikes hit 25%% harder for 20 s (%s)" % [dealt])
	# Flameblade: Edge Oil builds heat twice as fast.
	_mark("throat", "flameblade", 1)
	p = main.player
	var heats := {}
	for oil in [false, true]:
		p.edge_t = 20.0 if oil else 0.0
		p.heat = 0.0
		p.kindle_t = 0.0
		p._strikes_landed(1)
		heats[oil] = p.heat
	_check(absf(heats[true] - 2.0 * heats[false]) < 0.01, "Flameblade: Edge Oil builds heat twice as fast (%s)" % [heats])
	# Warding Oil: a barrier, and traps can't hurt you while it holds.
	p.add_item("warding_oil")
	p.item_sel = "warding_oil"
	_check(p.use_item() and absf(p.barrier_hp - 25.0) < 0.01 and p.ward_oil_t > 14.0, "Warding Oil: a 25-point barrier for 15 s")
	var tr := {"kind": "spikes", "dmg": 26.0, "pos": p.global_position, "dir": Vector2.RIGHT}
	p.hp = 100.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	main.trap_view._catch_player(tr, main.trap_view.KINDS["spikes"])
	_check(p.hp == 100.0 and absf(p.barrier_hp - 25.0) < 0.01, "...traps can't hurt you while it holds")
	p.barrier_hp = 0.0
	p.ward_oil_t = 0.0
	p.hurt_t = 0.0
	main.trap_view._catch_player(tr, main.trap_view.KINDS["spikes"])
	_check(p.hp < 100.0, "(without it, they do)")
	p.hp = p.max_health()
	# Haste Draught: rolls 30% cheaper, a quicker walk.
	var rc := {}
	for haste in [false, true]:
		p.haste_t = 10.0 if haste else 0.0
		p.sta = p.max_sta
		p.roll_cd = 0.0
		p.attack_cd = 0.0
		p._try_roll(Vector2.RIGHT)
		rc[haste] = p.max_sta - p.sta
		p.roll_t = 0.0
		p.iframes = 0.0
	_check(absf(rc[true] / rc[false] - 0.7) < 0.005, "Haste Draught: rolls cost 30%% less (%s)" % [rc])
	var walked := {}
	for haste in [false, true]:
		p.haste_t = 10.0 if haste else 0.0
		p.velocity = Vector2.ZERO
		p.knock = Vector2.ZERO
		p.global_position = Vector2(500, 400)
		Input.action_press("move_right")
		await physics_frame
		await physics_frame
		walked[haste] = p.velocity.x
		Input.action_release("move_right")
		await physics_frame
	_check(absf(walked[true] / walked[false] - 1.25) < 0.02, "...and you walk 25%% faster (%s)" % [walked])
	p.haste_t = 0.0
	p.add_item("haste")
	p.item_sel = "haste"
	_check(p.use_item() and p.haste_t > 9.0, "...for 10 s")
	p.haste_t = 0.0
	# Stoneskin: 20% off, within the 50% cap; no knockback.
	for id in G.PIECE_SLOTS:
		main.dev_give_gear("-" + id)
	main.dev_give_gear("")
	p.add_item("stoneskin")
	p.item_sel = "stoneskin"
	_check(p.use_item() and absf(p.protection() - 0.2) < 0.001, "Stoneskin Draught: 20% damage taken off")
	p.take_gear("plate")
	_check(absf(p.protection() - 0.5) < 0.001, "...and it counts toward the 50% cap (plate 35% + 20% = 50%)")
	var knocker = await _spawn("knight", p.global_position + Vector2(40, 0))
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.knock = Vector2.ZERO
	p.receive_attack(30.0, knocker)
	_check(p.knock == Vector2.ZERO, "...and blows can't knock you back")
	knocker.queue_free()
	p.stone_t = 0.0
	main.dev_give_gear("")
	p.hp = p.max_health()
	# Second Wind Salts: stamina full at once, refilling 50% faster.
	p.sta = 10.0
	p.add_item("salts")
	p.item_sel = "salts"
	_check(p.use_item() and p.sta == p.max_sta, "Second Wind Salts: stamina full at once")
	var gain := {}
	for salts in [false, true]:
		p.salts_t = 8.0 if salts else 0.0
		p.sta = 0.0
		p.sta_delay = 0.0
		p._tick_timers(0.1)
		gain[salts] = p.sta
	_check(absf(gain[true] / gain[false] - 1.5) < 0.01, "...and it refills 50%% faster for 8 s (%s)" % [gain])
	p.salts_t = 0.0
	# Flare Powder: lights the room; hidden things nearby glint.
	p.add_item("flare")
	p.item_sel = "flare"
	_check(p.use_item() and absf(main.flare_t - 20.0) < 0.1 and main.flare_light >= 0, "Flare Powder lights the room for 20 s")
	_check(main.flare_reveals(p.global_position + Vector2(200, 0)) and not main.flare_reveals(p.global_position + Vector2(900, 0)), "...hidden traps and secret walls nearby glint (not far off)")
	_mark("brow", "hunter", 1)
	p = main.player
	p.add_item("flare")
	p.item_sel = "flare"
	p.use_item()
	_check(absf(main.flare_t - 40.0) < 0.1, "Hunter: a Flare lasts twice as long")
	# Smoke Bomb: an Ashwalker's lasts twice as long.
	_mark("back", "ashwalker", 1)
	p = main.player
	p.add_item("smoke")
	p.item_sel = "smoke"
	p.use_item()
	_check(absf(main.smokes.back()["t"] - Items.ITEMS["smoke"]["duration"] * 2.0) < 0.1, "Ashwalker: Smoke Bombs last twice as long")

	print("the item ring")
	await _fresh_main()
	p = main.player
	for e in main.enemies():
		e.queue_free()
	await _frames(2)
	p.items = {}
	for id in ["draught", "tonic", "haste"]:
		p.add_item(id)
	p.item_sel = "draught"
	p.hp = 60.0
	# A tap uses the quick item and never opens the ring.
	Input.action_press("use_item")
	await physics_frame
	await physics_frame
	Input.action_release("use_item")
	await physics_frame
	await physics_frame
	_check(p.item_count("draught") == 0 and not p.ring_open and Engine.time_scale == 1.0, "a tap of G uses the quick item; the ring stays shut")
	p.add_item("draught")
	p.heal_left = 0.0
	# A hold opens the ring (time stops); pointing picks; letting go uses it.
	p.mouse_aim = false
	Input.action_press("use_item")
	await _wait(0.4)
	_check(p.ring_open and main.slowmo and Engine.time_scale == 0.0, "holding G opens the ring of belt items, and time stops")
	var have: Array = p.carried()
	var target := have.find("haste")
	p.item_dir_override = Vector2.from_angle(-PI / 2.0 + TAU * target / have.size()) * 60.0
	await physics_frame
	await physics_frame
	_check(p.ring_index == target, "pointing picks an item in the ring (%d)" % p.ring_index)
	Input.action_release("use_item")
	await physics_frame
	await physics_frame
	_check(p.item_count("haste") == 0 and p.haste_t > 0.0 and not p.ring_open and not main.slowmo and p.item_count("draught") == 1, "letting go uses that item, the ring closes and time runs again")
	# The d-pad down (T): a tap picks the next item; a hold opens the ring.
	p.add_item("haste")
	p.item_sel = "draught"
	Input.action_press("item_next")
	await physics_frame
	await physics_frame
	Input.action_release("item_next")
	await physics_frame
	await physics_frame
	_check(p.selected_item() != "draught" and p.item_count("draught") == 1 and not p.ring_open, "a tap of the d-pad down picks the next item (%s)" % p.selected_item())
	Input.action_press("item_next")
	await _wait(0.4)
	_check(p.ring_open, "holding the d-pad down opens the ring too")
	Input.action_release("item_next")
	await physics_frame
	await physics_frame
	p.heal_left = 0.0
	# On a phone: hold the Item button, slide, let go.
	p.items = {"draught": 1, "tonic": 1, "haste": 1}
	p.item_sel = "draught"
	p.haste_t = 0.0
	main.touch._set_active(true)
	await _frames(2)
	main.touch._layout()
	var btn: Dictionary = main.touch.buttons.filter(func(b): return b["id"] == "item")[0]
	_touch(6, btn["c"], true)
	await _wait(0.4)
	_check(p.ring_open, "holding the phone's Item button opens the ring")
	have = p.carried()
	target = have.find("haste")
	_drag(6, btn["c"] + Vector2.from_angle(-PI / 2.0 + TAU * target / have.size()) * 50.0)
	await physics_frame
	await physics_frame
	_touch(6, btn["c"] + Vector2.from_angle(-PI / 2.0 + TAU * target / have.size()) * 50.0, false)
	await physics_frame
	await physics_frame
	_check(p.item_count("haste") == 0 and p.item_count("draught") == 1 and not p.ring_open, "sliding to an item and letting go uses it")
	main.touch._set_active(false)
	await _frames(2)
	# The Entity explains the belt and the ring.
	var Entity = load("res://scripts/entity.gd")
	_check(Entity.TIPS.has("rarity") and Entity.TIPS.has("belt") and Entity.TIPS.has("item_ring"), "the Entity has tips for rarities, the belt and the item ring")

	print("the belt at the end of a climb")
	await _fresh_main()
	p = main.player
	p.items = {"draught": 2, "fire_flask": 1}
	var stone0: float = main.profile.crystal_total("stone")
	var fire0: float = main.profile.crystal_total("fire")
	var line: String = main.break_belt()
	_check(absf(main.profile.crystal_total("stone") - stone0 - 12.0) < 0.01 and absf(main.profile.crystal_total("fire") - fire0 - 6.0) < 0.01, "unused belt items break into crystals at half their worth: %s" % line)
	_check(p.items.is_empty() and main.break_belt() == "", "...once (the belt is empty after)")
	# Surviving the first climb's Regard breaks it too; falling doesn't.
	await _fresh_main()
	p = main.player
	p.items = {"tonic": 2}
	var water0: float = main.profile.crystal_total("water")
	var rpay: float = float(main.Train.climb_pay(main.floor_num, main.climb_best0)) if main.tower_data()["essence"] == "water" else 0.0  # (the outfitter's pay, in the tower's kind)
	main._begin_regard(false)
	_check(absf(main.profile.crystal_total("water") - water0 - 10.0 - rpay) < 0.01, "reaching the Regard alive breaks the belt into crystals")
	await _fresh_main()
	p = main.player
	p.items = {"tonic": 2}
	water0 = main.profile.crystal_total("water")
	rpay = float(main.Train.climb_pay(main.floor_num, main.climb_best0)) if main.tower_data()["essence"] == "water" else 0.0
	main._begin_regard(true)
	_check(main.profile.crystal_total("water") == water0 + rpay, "falling loses it (only the outfitter's pay comes)")
	Engine.time_scale = 1.0


## A controller button, as the game would get it from a real pad.
func _pad_button(button: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _pad_axis(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _key_tap(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _pad_tap(button: int) -> void:
	_pad_button(button, true)
	await _frames(2)
	_pad_button(button, false)
	await _frames(2)


func _controls_tests() -> void:
	print("keyboard and controller")
	await _fresh_main()
	main.touch._set_active(false)
	var p = main.player
	var C = main.Controls
	# Every action has a key (or a mouse button), and no key does two things.
	var gameplay := ["move_up", "move_down", "move_left", "move_right", "roll", "jump", "attack", "parry",
		"cast_hand", "cast_legs", "cast_heart", "cast_brow", "cast_throat", "cast_back", "use_item", "item_next",
		"interact", "restart", "toggle_music", "toggle_help", "new_climber", "weapon_1", "weapon_2", "weapon_3",
		"weapon_next", "weapon_prev", "pause", "climber", "inventory"]
	var keys := {}
	var all_keyed := true
	var clash := ""
	for a in gameplay:
		var has_key := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_key = true
			if ev is InputEventKey:
				if keys.has(ev.physical_keycode) and keys[ev.physical_keycode] != a:
					clash = "%s and %s" % [keys[ev.physical_keycode], a]
				keys[ev.physical_keycode] = a
		all_keyed = all_keyed and has_key
	_check(all_keyed, "every action has a key or mouse button")
	_check(clash == "", "no key is bound to two actions %s" % clash)
	# ...and every action but music, new climber, the controls panel and the number keys has a controller button.
	var on_pad: Array = C.PAD.values() + C.PAD_CAST.values() + [C.PAD_BACK_TAP]
	var missing: Array = gameplay.filter(func(a): return not (a in on_pad) and not a.begins_with("move_") \
		and not a.begins_with("weapon_") and a != "toggle_music" and a != "new_climber" and a != "toggle_help")
	_check(missing.is_empty(), "every action is on the controller (missing: %s)" % [missing])
	_check("weapon_next" in on_pad and "weapon_prev" in on_pad, "...weapons cycle with the d-pad and RB")
	_check(InputMap.action_has_event("move_left", C._axis(JOY_AXIS_LEFT_X, -1.0)) and InputMap.action_has_event("aim_up", C._axis(JOY_AXIS_RIGHT_Y, -1.0)), "the left stick moves, the right stick aims")
	_check(InputMap.action_has_event("ui_accept", C._button(JOY_BUTTON_A)) and InputMap.action_has_event("ui_cancel", C._button(JOY_BUTTON_B)), "A confirms and B goes back in menus")
	_check(C.PAD_CAST.size() == 6 and C.PART_PAD.size() == 6, "six casts with LB held, one per body part")

	print("controller buttons")
	_check(not main.pad_active and not p.stick_aim, "the keyboard is in charge to begin with")
	_pad_button(JOY_BUTTON_B, true)
	await _frames(2)
	_check(Input.is_action_pressed("roll"), "B rolls")
	_check(main.pad_active and p.stick_aim, "a controller press switches to controller prompts and stick aim")
	_pad_button(JOY_BUTTON_B, false)
	await _frames(2)
	_check(not Input.is_action_pressed("roll"), "letting go of B lets go of roll")
	_pad_button(JOY_BUTTON_X, true)
	await _frames(1)
	_check(Input.is_action_pressed("use_item") and not Input.is_action_pressed("cast_hand"), "X uses your item")
	_pad_button(JOY_BUTTON_X, false)
	# Hold LB: the face buttons cast.
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_pad_button(JOY_BUTTON_X, true)
	await _frames(1)
	_check(Input.is_action_pressed("cast_hand") and not Input.is_action_pressed("use_item"), "LB + X casts the hand's mark (not the item)")
	_pad_button(JOY_BUTTON_X, false)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(1)
	_check(Input.is_action_pressed("cast_back") and not Input.is_action_pressed("attack"), "LB + RT casts the back's mark")
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await _frames(1)
	_check(not Input.is_action_pressed("cast_back") and not Input.is_action_pressed("cast_hand"), "letting go ends the casts' holds")
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.2)
	await _frames(1)
	_check(not Input.is_action_pressed("attack"), "a light touch on RT does nothing")
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await _frames(1)
	_check(Input.is_action_pressed("attack"), "RT strikes (and holds to draw a bow)")
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(1)
	_check(Input.is_action_pressed("parry"), "LT parries")
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	# A menu opening lets go of what the controller held.
	main.menu.open("pause")
	await _frames(2)
	_check(not Input.is_action_pressed("attack"), "opening the menu lets go of a held RT")
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(1)
	main.menu.close()
	await _frames(2)
	# Weapons on the d-pad.
	p.pending_weapon = ""
	var w0: String = p.weapon
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(p.pending_weapon != "" and p.pending_weapon != w0 or p.weapon != w0, "d-pad right picks the next weapon")
	await _settle()

	print("stick aim")
	for e in main.enemies():
		e.global_position = p.global_position + Vector2(2000, 2000)  # out of auto-aim's reach
	p.attack_cd = 0.0
	p.parry_t = 0.0
	_pad_axis(JOY_AXIS_RIGHT_X, -1.0)
	await _frames(3)
	_check(p.aim.x < -0.95, "the right stick aims (%s)" % p.aim)
	_pad_axis(JOY_AXIS_RIGHT_X, 0.1)
	await _frames(1)
	_check(Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down") == Vector2.ZERO, "a stick resting near the middle doesn't aim (deadzone)")
	_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	_pad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(1)
	_check(Input.get_action_strength("move_right") > 0.9, "the left stick moves")
	await _frames(12)
	_check(p.aim.x > 0.5, "let go of the right stick and you aim the way you move (%s)" % p.aim)
	_pad_axis(JOY_AXIS_LEFT_X, 0.1)
	await _frames(1)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "...and a resting left stick doesn't drift")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	var dummy = await _dummy(p.global_position + Vector2(0, -90))
	await _frames(12)
	_check(p.aim.y < -0.8, "with no stick, you aim at the nearest monster (%s)" % p.aim)
	_slay(dummy)

	print("prompts follow the device")
	var hud = main.hud
	_check(hud._say("keys", "pad {a}", "tap") == "pad A", "controller prompts after a controller press")
	_check(hud._say(main.Gear.TEXT["take_key"], main.Gear.TEXT["take_pad"], main.Gear.TEXT["take_tap"]) == "Y  take it", "the gear prompt names Y")
	_check(C.pad_text("{a} {start}", true) == "Cross Options", "PlayStation pads get PlayStation names")
	_check(hud._card_hint(main.card_focus) == "Press A", "the highlighted card says Press A")
	await _key_tap(KEY_W)
	_check(not main.pad_active and not p.stick_aim, "a key press hands back to the keyboard (and the mouse aims)")
	_check(hud._say("keys", "pad {a}", "tap") == "keys", "keyboard prompts again")
	_check(hud._card_hint(0).begins_with("Press 1"), "cards say Press 1 for the keyboard")
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(main.pad_active, "the controller again")
	_touch(3, Vector2(300, 300), true)
	await _frames(2)
	_touch(3, Vector2(300, 300), false)
	await _frames(2)
	_check(main.touch_active and not main.pad_active and hud._say("keys", "pad", "tap") == "tap", "a touch switches to touch wording")
	_pad_button(JOY_BUTTON_Y, true)
	await _frames(2)
	_check(not main.touch_active and main.pad_active, "a controller press turns the touch controls off")
	_check(Input.is_action_pressed("interact"), "...and still does its job (Y takes gear)")
	_pad_button(JOY_BUTTON_Y, false)
	await _settle()

	print("card screens with keys and controller")
	main._enter_camp([])
	await _frames(2)
	_check(main.camp_choosing and main.card_focus == 0, "a camp starts on the first card")
	var picks: Array = main.camp["choices"].duplicate()
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(main.card_focus == 1, "d-pad right moves to the next card")
	await _key_tap(KEY_LEFT)
	_check(main.card_focus == 0, "the left arrow moves back")
	await _key_tap(KEY_LEFT)
	_check(main.card_focus == picks.size() - 1, "...and wraps around")
	Input.action_press("ui_right")
	await _frames(2)
	Input.action_release("ui_right")
	await _frames(1)
	_check(main.card_focus == 0, "ui_right wraps to the first")
	await _pad_tap(JOY_BUTTON_A)
	_check(not main.camp_choosing, "A takes the highlighted camp card")
	var first: String = picks[0]
	_check(p.item_count(first) > 0 if not first.begins_with("gear:") else p.carried_gear().has(main.Gear.base_id(first.substr(5))), "...the one that was highlighted (%s)" % first)
	await _frames(2)
	# Choosing a tower: two rows of three.
	main.choosing_tower = true
	main.card_focus = 0
	await _key_tap(KEY_RIGHT)
	await _key_tap(KEY_DOWN)
	_check(main.card_focus == 4, "right then down moves along the tower cards (%d)" % main.card_focus)
	await _key_tap(KEY_ENTER)
	_check(not main.choosing_tower and main.tower == main.Towers.ORDER[4], "Enter takes the highlighted tower")
	await _frames(2)
	# The victory screen: A moves on, to the heirloom cards.
	main.heirloom_offered = false
	p.take_gear("axe")
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	await _frames(2)
	await _pad_tap(JOY_BUTTON_A)
	_check(main.victory.is_empty() and main.camp_choosing and main.camp["stage"] == "heirloom", "A dismisses the victory screen")
	var none_i: int = main.camp["choices"].find("heir:")
	for i in 8:
		if main.card_focus == none_i:
			break
		await _key_tap(KEY_RIGHT)
	Input.action_press("ui_accept")
	await _frames(2)
	Input.action_release("ui_accept")
	_check(not main.camp_choosing and main.profile.heirlooms.is_empty(), "the heirloom cards take arrows and Enter too")
	main.heirloom_offered = false
	main.regard = {"fell": false, "part": "hand", "id": "stormcaller", "t": 4.0}
	await _frames(2)
	await _pad_tap(JOY_BUTTON_START)
	_check(main.regard.is_empty() and main.camp_choosing, "Start dismisses the Regard once it has played")
	_check(not main.menu_open(), "...instead of opening the menu")
	main.choose_camp(main.camp["choices"].find("heir:"))
	await _frames(2)

	print("menus with keys and controller")
	await _pad_tap(JOY_BUTTON_START)
	_check(main.menu_open() and main.menu.page == "pause", "Start opens the pause menu")
	await _frames(2)
	var focus: Control = main.menu.get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text == "Resume", "the first button has the focus")
	await _pad_tap(JOY_BUTTON_DPAD_DOWN)
	focus = main.menu.get_viewport().gui_get_focus_owner()
	_check(focus is Button and (focus.text.begins_with("Climber") or focus.text.begins_with("Inventory")), "d-pad down moves the focus")
	await _key_tap(KEY_UP)
	focus = main.menu.get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text == "Resume", "the up arrow moves it back")
	_check(not Input.is_action_pressed("item_next"), "the d-pad in a menu doesn't reach the game")
	main.menu.settings_tab = "settings"
	main.menu.open("settings")
	await _frames(2)
	focus = main.menu.get_viewport().gui_get_focus_owner()
	_check(focus is HSlider, "the settings page starts on the music slider")
	var music: float = main.menu.settings["music"]
	await _key_tap(KEY_LEFT)
	_check(main.menu.settings["music"] < music, "left turns the music down")
	main.menu._set_setting("music", music)
	await _pad_tap(JOY_BUTTON_B)
	_check(main.menu.page == "settings" and main.menu.rail.button("settings").has_focus(), "B goes back to the rail")
	for i in 3:
		await _pad_tap(JOY_BUTTON_DPAD_UP)
	_check(main.menu.rail.button("resume").has_focus() and main.menu.page == "pause", "...up the rail to Resume")
	await _pad_tap(JOY_BUTTON_A)
	_check(not main.menu_open() and not paused, "A presses the focused button (Resume)")
	await _frames(2)
	main.menu.open("controls")
	await _frames(2)
	var texts: Array = _all_labels(main.menu).map(func(l): return l.text)
	_check("Controller" in texts and texts.any(func(t): return "hold LB" in t), "the Controls page lists the controller")
	_check(main.menu.rail.button("settings").has_focus(), "a page with nothing to press keeps the focus on the rail (Settings & Controls lit)")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open(), "...so Esc closes it")
	await _frames(2)

	print("restart is held")
	Input.action_press("restart")
	await _wait(0.35)
	_check(main.restart_armed and main.banner.get("title", "") == "RESTART?", "pressing restart asks you to keep holding")
	Input.action_release("restart")
	await _frames(2)
	_check(not main.restart_armed and main.restart_t < main.RESTART_HOLD, "a quick press doesn't restart")
	_pad_button(JOY_BUTTON_BACK, true)
	await _wait(1.0)
	_check(main.restart_t >= main.RESTART_HOLD and not main.restart_armed, "holding View restarts")
	_pad_button(JOY_BUTTON_BACK, false)
	await _frames(2)
	await _key_tap(KEY_W)  # (back to the keyboard)


## A raw controller button or axis, from a pretend controller (pad.gd
## test_joys), as a browser that doesn't report the standard layout sends it.
func _raw_button(device: int, button: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _raw_axis(device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


## One step of the controller setup: press (or push) something, let go, and
## wait until the screen has moved on (or shown why not).
func _setup_step(setup, press: Callable, release: Callable) -> void:
	var at: int = setup.step
	var st: String = setup.state
	var said: String = setup.note
	press.call()
	await _frames(1)
	release.call()
	await _until(func(): return not is_instance_valid(setup) or setup.step != at or setup.state != st or (setup.note != said and setup.held == ""), 2.0)


func _pad_layout_tests() -> void:
	print("controllers the browser scrambles")
	await _fresh_main()
	main.touch._set_active(false)
	var pad = main.pad
	var P = pad.get_script()
	var C = main.Controls
	P.layouts.clear()
	P.offered.clear()
	_check(C.WEB_STANDARD_FIX.contains("lefttrigger:+a6") and C.WEB_STANDARD_FIX.contains("righttrigger:+a7"), "on the web, standard pads' triggers are read from axes 6 and 7 (Godot 4.3's own layout lost them)")
	var stray := false
	for a in ["ui_up", "ui_left", "ui_accept", "ui_cancel", "move_left", "aim_up", "dismiss_tip"]:
		for ev in InputMap.action_get_events(a):
			if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) and ev.device != C.PAD_DEVICE:
				stray = true
	_check(not stray, "the input map (Godot's menu actions too) listens only to the game's controller, never to raw numbers")
	_check(P.parse_source("a2+@-1") == {"t": "a", "i": 2, "s": 1.0, "r": -1.0} and is_equal_approx(P.parse_source("h9=-0.43")["v"], -0.43) and P.parse_source("b12")["i"] == 12 and P.parse_source("q1").is_empty(), "layouts read back from text")
	_check(P.hat_on(-0.71, -1.0) and P.hat_on(1.0, -1.0) and not P.hat_on(0.14, -1.0) and not P.hat_on(1.28, -1.0), "a hat d-pad: up counts its diagonals, not down or rest")

	# An Xbox pad Firefox reports raw on Linux: the guessed layout.
	P.test_joys[5] = {"name": "045e-0b13-Xbox Wireless Controller", "guid": "Linux045e0b13", "known": false}
	_raw_axis(5, 2, -1.0)  # (the triggers rest at -1)
	_raw_axis(5, 5, -1.0)
	_raw_button(5, 2, true)
	await _frames(1)
	_check(pad._dev(5)["kind"] == "guessed" and Input.is_action_pressed("use_item"), "an unknown Xbox pad gets the raw Xbox layout: X uses your item")
	_check(main.pad_active, "...and counts as the controller in use")
	_check(pad.offers == 1, "the first press offers the controller setup (the Entity)")
	_raw_button(5, 2, false)
	_raw_button(5, 3, true)
	await _frames(1)
	_check(Input.is_action_pressed("interact") and not Input.is_action_pressed("use_item"), "Y takes gear")
	_raw_button(5, 3, false)
	_raw_button(5, 0, true)
	await _frames(1)
	_check(Input.is_action_pressed("jump") and pad.offers == 1, "A jumps (and the offer isn't made twice)")
	_raw_button(5, 0, false)
	_raw_button(5, 4, true)
	await _frames(1)
	_check(not Input.is_action_pressed("restart") and pad.cast_held, "LB (raw 4) is the cast button, not View (Godot's 4)")
	_raw_button(5, 0, true)
	await _frames(1)
	_check(Input.is_action_pressed("cast_legs"), "LB + A casts the legs' mark")
	_raw_button(5, 0, false)
	_raw_button(5, 4, false)
	_raw_button(5, 5, true)
	await _frames(1)
	_check(Input.is_action_pressed("weapon_next"), "RB (raw 5) picks the next weapon")
	_raw_button(5, 5, false)
	await _frames(1)
	_check(not Input.is_action_pressed("parry") and not Input.is_action_pressed("attack"), "triggers resting at -1 are let go")
	_raw_axis(5, 2, 1.0)
	_raw_axis(5, 5, 0.9)
	await _frames(1)
	_check(Input.is_action_pressed("parry") and Input.is_action_pressed("attack"), "LT (axis 2) parries, RT (axis 5) strikes")
	_raw_axis(5, 2, -1.0)
	_raw_axis(5, 5, -1.0)
	_raw_axis(5, 7, 1.0)
	await _frames(1)
	_check(not Input.is_action_pressed("parry") and not Input.is_action_pressed("attack") and Input.is_action_pressed("item_next"), "...back at -1 they let go; d-pad down (axis 7) picks the next item")
	_raw_axis(5, 7, 0.0)
	_raw_axis(5, 1, -1.0)
	_raw_axis(5, 4, 1.0)
	await _frames(1)
	_check(Input.get_action_strength("move_up") > 0.9 and Input.get_action_strength("aim_down") > 0.9 and Input.get_action_strength("aim_right") == 0.0, "the left stick moves; the right stick is axes 3 and 4 (not the left trigger)")
	_raw_axis(5, 1, 0.0)
	_raw_axis(5, 4, 0.0)
	await _frames(1)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "...and both let go")
	# On Windows or a Mac: the Bluetooth order, with its gaps.
	P.test_joys[6] = {"name": "045e-02fd-Xbox Wireless Controller", "guid": "Windows045e02fd", "known": false}
	_raw_button(6, 3, true)
	await _frames(1)
	_check(Input.is_action_pressed("use_item"), "on Windows, X is raw 3 (the Bluetooth order)")
	_raw_button(6, 3, false)
	_check(pad.offers == 2, "...a second unknown pad is offered it too")
	# A pad the browser calls standard (or Godot knows): straight through.
	P.test_joys[8] = {"name": "Xbox 360 Controller (XInput STANDARD GAMEPAD)", "guid": "standard", "known": true}
	_raw_button(8, JOY_BUTTON_X, true)
	_raw_axis(8, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(1)
	_check(pad._dev(8)["kind"] == "known" and Input.is_action_pressed("use_item") and Input.is_action_pressed("attack"), "a standard pad passes straight through")
	_raw_button(8, JOY_BUTTON_X, false)
	_raw_axis(8, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(1)
	_check(not Input.is_action_pressed("use_item") and not Input.is_action_pressed("attack"), "...and lets go")
	_check(pad.offers == 2, "a known pad isn't offered the setup")
	await _settle()

	# The setup screen, with a scrambled pad that isn't an Xbox one.
	P.test_joys[7] = {"name": "Generic USB Joystick", "guid": "Windows00790006", "known": false}
	_raw_axis(7, 5, -1.0)  # a trigger at rest
	_raw_axis(7, 9, 1.28)  # a hat d-pad at rest
	main.menu.open("settings")
	await _frames(2)
	var open_btn = _all_buttons(main.menu).filter(func(b): return b.get_meta("setting", "") == "padsetup")
	_check(open_btn.size() == 1, "Settings has Controller setup")
	if open_btn.is_empty():
		return
	open_btn[0].pressed.emit()
	await _frames(2)
	var found: Array = main.menu.box.get_children().filter(func(c): return c.get_script() == load("res://scripts/pad_setup.gd"))
	_check(main.menu.page == "padsetup" and found.size() == 1, "...which opens its page")
	if found.is_empty():
		return
	var setup = found[0]
	_check(setup.state == "pick" and pad.capture.is_valid(), "it starts by asking for any button (and the controller's presses go to it)")
	_raw_button(7, 9, true)
	await _frames(1)
	_raw_button(7, 9, false)
	_check(setup.state == "step" and setup.device == 7 and setup.step == 0, "any button begins, for that controller")
	var prompt: Array = _all_labels(setup).filter(func(l): return l.get_meta("prompt", false))
	_check(not prompt.is_empty() and prompt[0].text == "Press the button you want for Jump", "the first prompt: Jump")
	var tap := func(b: int): return [func(): _raw_button(7, b, true), func(): _raw_button(7, b, false)]
	var push := func(a: int, v: float, back: float): return [func(): _raw_axis(7, a, v), func(): _raw_axis(7, a, back)]
	var t: Array = tap.call(5)
	await _setup_step(setup, t[0], t[1])  # Jump: 5
	t = tap.call(6)
	await _setup_step(setup, t[0], t[1])  # Roll: 6
	t = push.call(1, -1.0, 0.0)
	await _setup_step(setup, t[0], t[1])  # move up: axis 1 -
	t = push.call(1, 1.0, 0.0)
	await _setup_step(setup, t[0], t[1])
	_check(setup.step == 3 and setup.note.contains("already"), "the moving stick's other way can't be 'right' too")
	t = push.call(0, 1.0, 0.0)
	await _setup_step(setup, t[0], t[1])  # move right: axis 0 +
	t = push.call(3, -1.0, 0.0)
	await _setup_step(setup, t[0], t[1])  # aim up: axis 3 -
	t = push.call(2, 1.0, 0.0)
	await _setup_step(setup, t[0], t[1])  # aim right: axis 2 +
	t = tap.call(2)
	await _setup_step(setup, t[0], t[1])  # X: 2 (then redo it)
	t = tap.call(6)
	await _setup_step(setup, t[0], t[1])  # Roll's button: back a step
	_check(setup.step == 6 and not setup.got.has("x"), "the Roll button goes back a step")
	t = tap.call(4)
	await _setup_step(setup, t[0], t[1])  # X: 4
	t = tap.call(4)
	await _setup_step(setup, t[0], t[1])
	_check(setup.step == 7 and setup.note.contains("already"), "a button already given can't be given again")
	t = tap.call(7)
	await _setup_step(setup, t[0], t[1])  # Y: 7
	t = push.call(5, 1.0, -1.0)
	await _setup_step(setup, t[0], t[1])  # RT: axis 5 from -1
	t = tap.call(8)
	await _setup_step(setup, t[0], t[1])  # LT: a button
	t = tap.call(1)
	await _setup_step(setup, t[0], t[1])  # RB
	t = tap.call(0)
	await _setup_step(setup, t[0], t[1])  # LB
	for v in [-1.0, 0.14, 0.71, -0.43]:  # the d-pad on one hat axis
		t = push.call(9, v, 1.28)
		await _setup_step(setup, t[0], t[1])
	t = tap.call(11)
	await _setup_step(setup, t[0], t[1])  # Start
	t = tap.call(10)
	await _setup_step(setup, t[0], t[1])  # View
	_check(setup.step == setup.STEPS.size() - 1, "one step left (%d)" % setup.step)
	t = tap.call(5)
	await _setup_step(setup, t[0], t[1])  # the Jump button skips the last
	_check(setup.state == "done" and not pad.capture.is_valid(), "the setup finishes and lets the controller go")
	var L: Dictionary = P.layouts.get("Windows00790006|Generic USB Joystick", {})
	_check(L.get("a") == "b5" and L.get("ly") == "a1-" and L.get("lx") == "a0+" and L.get("rt") == "a5+@-1" and L.get("lt") == "b8" and L.get("up") == "h9=-1.00" and L.get("right") == "h9=-0.43", "it saved what was pressed, per controller (%s)" % [L])
	_check(L.get("rs", "") != "b8", "a skipped step keeps its default only if that input is free")
	_check(_all_labels(setup).any(func(l): return l.text == "axis 5 +"), "the page lists what was recorded")
	_check(setup.readout_lines().contains("Generic USB Joystick") and setup.readout_lines().contains("9: +1.28"), "the readout shows the raw axes arriving")
	_raw_button(7, 5, true)
	await _frames(1)
	_raw_button(7, 5, false)
	await _until(func(): return main.menu.page == "settings", 1.0)
	_check(main.menu.page == "settings", "the new layout works at once: its A presses Done (%s)" % main.menu.page)
	main.menu.close()
	await _frames(2)
	_raw_button(7, 4, true)
	_raw_axis(7, 5, 1.0)
	_raw_axis(7, 9, 0.14)
	_raw_axis(7, 1, -1.0)
	await _frames(1)
	_check(Input.is_action_pressed("use_item") and Input.is_action_pressed("attack") and Input.is_action_pressed("item_next") and Input.get_action_strength("move_up") > 0.9, "in play, the recorded layout is used (X, RT, hat d-pad, stick)")
	_raw_button(7, 4, false)
	_raw_axis(7, 5, -1.0)
	_raw_axis(7, 9, 1.28)
	_raw_axis(7, 1, 0.0)
	_raw_button(7, 0, true)
	_raw_button(7, 5, true)
	await _frames(1)
	_check(Input.is_action_pressed("cast_legs") and not Input.is_action_pressed("item_next"), "its LB + A casts")
	_raw_button(7, 5, false)
	_raw_button(7, 0, false)
	await _frames(1)
	_check(not Input.is_action_pressed("use_item") and not Input.is_action_pressed("attack") and Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "...and everything lets go")
	await _settle()
	# Reset to default: back to the raw numbers.
	pad.reset_layout(7)
	_check(not P.layouts.has("Windows00790006|Generic USB Joystick") and pad._dev(7)["kind"] == "raw", "Reset to default forgets the setup")
	_raw_button(7, 2, true)
	await _frames(1)
	_check(Input.is_action_pressed("use_item"), "...and the raw numbers pass straight through again")
	_raw_button(7, 2, false)
	await _frames(1)
	# Saved and loaded.
	var path := "user://pad_test.cfg"
	P.layouts = {"standard|Pad": {"a": "b1", "lt": "a2+@-1"}}
	P.offered = {"standard|Pad": true}
	P.save_layouts(path)
	P.layouts = {}
	P.offered = {}
	P.load_layouts(path)
	_check(P.layouts.get("standard|Pad", {}).get("lt") == "a2+@-1" and P.offered.has("standard|Pad"), "layouts save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	P.layouts = {}
	P.offered = {}
	P.load_layouts(path)
	_check(P.layouts.is_empty(), "no save: no layouts (the defaults)")
	P.test_joys.clear()
	pad.devs.clear()
	await _frames(2)


func _all_labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_labels(c))
	return out


func _all_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_buttons(c))
	return out


func _spawn(kind: String, pos: Vector2):
	var e = main.EnemyScript.new()
	e.setup(kind, main)
	e.position = pos
	main.add_child(e)
	await _frames(1)
	e.set_physics_process(false)
	return e


## Lets the knight attack the climber and presses parry `delay` seconds
## after its glint. Reports what happened.
func _parry_test(knight, delay: float, wind_state := "wind_slash", gap := 50.0) -> Dictionary:
	var p = main.player
	await _settle()
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_cd = 0.0
	p.parry_t = 0.0
	p.attack_cd = 0.0
	knight.stun = 0.0
	knight.flinch = 0.0
	knight.state = "chase" if knight.kind == "knight" else "approach"
	knight.state_t = 0.0
	knight.glinted = false
	main.attackers.clear()
	p.knock = Vector2.ZERO  # no sliding left over from an earlier hit
	p.velocity = Vector2.ZERO
	p.global_position = knight.global_position + Vector2(gap, 0)
	knight.set_physics_process(true)
	var glinted := false
	var give_up := Time.get_ticks_msec() + 3000  # watch for the glint for up to 3 real seconds
	while Time.get_ticks_msec() < give_up:
		await physics_frame  # every game tick, so the press comes right after the glint
		if knight.glinted and knight.state == wind_state:
			glinted = true
			break
	if delay > 0.0:
		await _wait(delay)
	p._try_parry()
	var pressed := Engine.get_physics_frames()
	var landed := -1
	var stun := 0.0
	var until := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < until:
		await physics_frame
		stun = maxf(stun, knight.stun)
		if landed < 0 and (knight.stun > 0.0 or p.hp < p.MAX_HP):
			landed = Engine.get_physics_frames() - pressed
	var result := {"glinted": glinted, "parried": stun > 0.0, "stun": stun, "hurt": p.hp < p.MAX_HP, "ticks": landed}
	knight.set_physics_process(false)
	knight.stun = 0.0
	return result


## Touch events arrive in window pixels; convert from game-view pixels.
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func _touch(index: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _to_window(pos)
	ev.pressed = down
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _to_window(pos)
	Input.parse_input_event(ev)


## Waits in real time (headless frames can run much faster than 60 fps).
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _settle() -> void:
	# Let hit-pause end on its own, then wait out cooldowns.
	await _wait(0.25)
	await _wait(0.75)


func _run() -> void:
	Engine.set_meta("sixfold_test", true)  # a fresh profile; never touches the real save
	_clear_slots()  # (no test climbers left from an earlier run)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(1)
	main.grant_test_bonds()  # most checks below need two marks to work with
	await _frames(5)
	var p = main.player
	p.mouse_aim = false
	var foes: Array = main.enemies()
	_check(foes.size() == 4, "room spawns 4 monsters")
	_check(main.audio.streams.size() >= 30 and main.audio.has_sound("hit"), "sounds loaded (%d)" % main.audio.streams.size())
	var silent := _silent_sounds()
	_check(silent.is_empty(), "every sound the code plays is in the sound bank (missing: %s)" % ", ".join(silent))
	for i in 12:  # a busy frame: the same hit a dozen times
		main.audio.last_played.erase("hit")
		main.audio.play("hit")
	_check(main.audio.playing_count("hit") <= main.audio.MAX_SAME, "one sound never stacks more than %d copies (%d)" % [main.audio.MAX_SAME, main.audio.playing_count("hit")])

	# Freeze the monsters so the test controls the fight.
	for e in foes:
		e.set_physics_process(false)
	var knight = foes.filter(func(e): return e.kind == "knight")[0]
	var slime = foes.filter(func(e): return e.kind == "slime")[0]

	print("combo")
	p.global_position = slime.global_position - Vector2(30, 0)
	p.aim = Vector2.RIGHT
	var hp0: float = slime.hp
	var sta0: float = p.sta
	_check(p._try_attack(), "first strike")
	_check(slime.hp < hp0, "strike damages")
	_check(p.sta < sta0, "strike costs stamina")
	_check(Engine.time_scale < 1.0, "hit-pause on hit")
	_check(slime.squash > 0.0, "target squashes")
	_check(not p._try_attack(), "can't strike again mid-recovery")
	_check(p.bonds["hand"].essence > 0.0, "hand fills on hit")
	await _wait(0.25)
	_check(Engine.time_scale == 1.0, "hit-pause ends")
	await _settle()

	print("parry and riposte")
	p.global_position = knight.global_position - Vector2(40, 0)
	p.aim = Vector2.RIGHT
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	p._try_parry()
	p.receive_attack(14.0, knight)
	_check(knight.stun > 0.0, "parried knight is staggered")
	_check(p.hp == p.MAX_HP, "parry takes no damage")
	_check(p.parry_flash > 0.0, "parry flash shown")
	await _settle()
	var khp: float = knight.hp
	p.combo_t = 0.0
	p._try_attack()
	_check(khp - knight.hp >= p.STRIKE_DAMAGE * 2.5 - 0.01, "riposte deals critical damage")
	await _settle()

	print("arrow reflect")
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	var arrow = main.spawn_projectile(p.global_position + Vector2(20, 0), Vector2(-260, 0), 8.0)
	p._try_parry()
	p.receive_attack(8.0, arrow)
	_check(arrow.reflected, "parried arrow is reflected")
	await _settle()

	print("roll and dodge")
	p.sta = p.MAX_STA
	p.roll_cd = 0.0
	var legs0: float = p.bonds["legs"].essence
	_check(p._try_roll(Vector2.UP), "roll starts")
	_check(p.iframes > 0.0, "roll grants i-frames")
	p.receive_attack(10.0, slime)
	_check(p.bonds["legs"].essence > legs0, "legs fill on dodge")
	await _wait(0.1)
	_check(p.modulate.a < 0.9, "rolling turns the climber see-through (%.2f)" % p.modulate.a)
	await _wait(0.1)
	_check(main.fx.ghosts.size() > 0, "afterimages while invulnerable")
	await _settle()

	print("casts and overdraw")
	for part in ["hand", "legs"]:
		p.bonds[part].essence = 0.0
		p.attack_cd = 0.0
		p.global_position = slime.global_position - Vector2(60, 0)
		p.aim = Vector2.RIGHT
		p._try_cast(part)
		await _wait(0.6)
		_check(p.bonds[part].burned, "%s overdraw burns" % part)
		await _settle()
	# Overdrawing an already-burned mark tears it: it costs health.
	var hp_before: float = p.hp
	p.bonds["hand"].essence = 0.0
	var paid: String = p.bonds["hand"].pay()
	_check(paid == "torn" and p.bonds["hand"].overdraw_mult < 1.0, "overdrawing a burned mark tears it, and the cast is weaker")
	p.bonds["hand"].essence = 0.0
	p.attack_cd = 0.0
	p._try_cast("hand")
	await _wait(0.6)
	_check(p.hp < hp_before, "a torn mark costs health (%.0f -> %.0f)" % [hp_before, p.hp])
	_check(p.bonds["hand"].overdraw_mult == 1.0, "only the overdrawn cast is weakened")
	p.hp = p.MAX_HP
	await _settle()

	print("bodies don't overlap")
	slime.airborne = 0.0  # left lifted by the Gale Lift test (its timers are frozen)
	slime.stun = 0.0
	p.global_position = slime.global_position + Vector2(2, 0)
	await _wait(0.1)
	var gap: float = p.global_position.distance_to(slime.global_position)
	_check(gap >= p.radius + slime.radius - 1.0, "climber and slime pushed apart (%.1f px)" % gap)
	await _settle()

	print("fists")
	p._equip("fists")
	_check(p.weapon == "fists", "equip fists")
	p.global_position = slime.global_position - Vector2(30, 0)
	p.aim = Vector2.RIGHT
	slime.hp = 999.0
	p.sta = p.MAX_STA
	for i in 4:
		p.attack_cd = 0.0
		p.lunge_t = 0.0
		p.global_position = slime.global_position - Vector2(30, 0)
		p._try_attack()
		Engine.time_scale = 1.0
		main.hitstop_until = 0
	_check(p.swing["heavy"], "fourth punch is a heavy finisher")
	_check(slime.hp < 999.0, "punches land")
	slime.hp = slime.max_hp
	await _settle()

	print("bow")
	p._equip("shortbow")
	p.attack_cd = 0.0
	p.sta = p.MAX_STA
	p.global_position = slime.global_position - Vector2(150, 0)
	p.aim = Vector2.RIGHT
	var shp: float = slime.hp
	_check(p._try_attack(), "start drawing")
	_check(p.drawing, "bow is drawn")
	p.draw_t = 1.0
	p.release_draw()
	_check(not p.drawing, "arrow loosed")
	var shots: Array = main.get_children().filter(func(c): return "friendly" in c and c.friendly)
	_check(shots.size() == 1 and shots[0].pierce, "full draw fires a piercing arrow")
	await _wait(0.5)
	_check(slime.hp < shp, "arrow hits the slime")
	p._equip("sword")
	await _settle()

	print("touch controls")
	var touch = main.get_children().filter(func(c): return c is CanvasLayer)[0].get_children().filter(func(c): return "stick_touch" in c)[0]
	var screen: Vector2 = touch.get_viewport_rect().size
	_touch(0, Vector2(200, screen.y - 200), true)
	await _frames(1)
	_check(main.touch_active and p.touch_aim, "first touch turns on touch controls")
	# The joystick: a light tilt is full walking speed; there is no sprint.
	touch.stick_origin = Vector2(200, 300)
	touch.stick_pos = Vector2(230, 300)
	touch._update_stick()
	_check(is_equal_approx(Input.get_action_strength("move_right"), 1.0), "half a tilt on the joystick walks at full speed")
	_check(not InputMap.has_action("sprint"), "there is no sprint")
	touch.stick_pos = Vector2(400, 300)
	touch._update_stick()
	_check(touch.stick_origin.distance_to(touch.stick_pos) <= touch.FOLLOW_RADIUS + 0.5, "past the ring the stick follows your thumb")
	touch._set_move(Vector2.ZERO)
	_check(Input.get_action_strength("move_right") == 0.0, "letting go stops")
	# (put the stick back where the thumb went down)
	touch.stick_origin = Vector2(200, screen.y - 200)
	touch.stick_pos = touch.stick_origin
	var before: Vector2 = p.global_position
	_drag(0, Vector2(280, screen.y - 200))
	await _frames(1)
	await _wait(0.3)
	_check(p.global_position.x > before.x + 5.0, "joystick moves the climber (%.0f px)" % (p.global_position.x - before.x))
	_touch(0, Vector2(280, screen.y - 200), false)
	await _wait(0.1)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "letting go stops moving")
	p.attack_cd = 0.0
	p.combo_t = 0.0
	var cd0: float = p.attack_cd
	touch._layout()
	var atk: Vector2 = touch.buttons[0]["c"]
	_touch(1, atk, true)
	await _wait(0.1)
	_touch(1, atk, false)
	_check(p.combo > 0 or p.attack_cd > cd0, "attack button swings")
	await _settle()
	# A key press hands control back to keyboard and mouse.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	key.pressed = false
	Input.parse_input_event(key)
	_check(not main.touch_active, "keyboard turns touch controls off")
	p.touch_aim = false
	await _settle()

	print("combat rhythm")
	# Fresh monsters for this part (earlier parts may have slain the first ones).
	# (in the empty left part of the room, away from the frozen floor-1 monsters)
	knight = await _spawn("knight", main.room.position + Vector2(160, 150))
	slime = await _spawn("slime", main.room.position + Vector2(160, 420))
	knight.hp = 999.0
	knight.max_hp = 999.0
	knight.stun = 0.0
	knight.flinch = 0.0
	slime.hp = 999.0
	slime.airborne = 0.0
	# Parry on the glint: always works.
	var r1: Dictionary = await _parry_test(knight, 0.0)
	_check(r1["glinted"], "the knight glints before striking")
	_check(r1["parried"] and not r1["hurt"], "parrying on the glint parries (stun %.2f)" % r1["stun"])
	# A beat after the glint: perfect.
	var r2: Dictionary = await _parry_test(knight, 0.14)
	_check(r2["parried"] and r2["stun"] > 1.2, "parrying just after the glint is perfect (stun %.2f)" % r2["stun"])
	# Too late: you get hit.
	var r3: Dictionary = await _parry_test(knight, 0.4)
	_check(r3["hurt"], "parrying too late gets you hit")
	knight.set_physics_process(false)
	knight.stun = 0.0
	# The slime's pounce from a distance: the glint still gives the same timing.
	var r4: Dictionary = await _parry_test(slime, 0.0, "wind", 100.0)
	_check(r4["glinted"] and r4["parried"] and not r4["hurt"], "parrying a slime's pounce on the glint works %s" % str(r4))
	slime.set_physics_process(false)
	slime.stun = 0.0
	# Touching a slime is harmless now; only its pounce hurts.
	p.hp = p.MAX_HP
	p.hurt_t = 0.0
	p.iframes = 0.0
	slime.state = "rest"
	slime.state_t = 5.0
	slime.set_physics_process(true)
	p.global_position = slime.global_position + Vector2(slime.radius + p.radius, 0)
	await _wait(0.5)
	_check(p.hp == p.MAX_HP, "touching a resting slime doesn't hurt")
	# Poise: a light hit doesn't stop a wind-up (read the glint instead);
	# a heavy hit (a finisher) does.
	slime.state = "wind"
	slime.state_t = 0.5
	slime.glinted = false
	slime.flinch_cd = 0.0
	main.request_attack(slime)
	slime.take_hit(1.0, Vector2.RIGHT, 50.0)
	_check(slime.state == "wind" and slime.flinch <= 0.0, "a light hit doesn't stop a monster's wind-up")
	slime.take_hit(1.0, Vector2.RIGHT, 50.0, true)
	_check(slime.state != "wind" and slime.flinch > 0.0, "...but a heavy hit cancels it")
	slime.hp = slime.max_hp
	slime.flinch = 0.0
	slime.flinch_cd = 0.0
	slime.take_hit(1.0, Vector2.RIGHT, 50.0)
	var first_flinch: bool = slime.flinch > 0.0
	slime.flinch = 0.0
	slime.take_hit(1.0, Vector2.RIGHT, 50.0)
	_check(first_flinch and slime.flinch <= 0.0, "light hits flinch a monster only now and then (no stun-locking)")
	slime.hp = slime.max_hp
	slime.set_physics_process(false)
	# Turns: never more than two attacking at once.
	for e in main.enemies():
		e.set_physics_process(true)
		e.state_t = 0.0
		e.stun = 0.0
		e.flinch = 0.0
		e.hp = 999.0
	p.global_position = main.room.get_center()
	p.hp = 9999.0
	var most := 0
	for i in 90:
		await _frames(2)
		most = maxi(most, main.attackers.size())
		var attacking: int = main.enemies().filter(func(e): return e.is_attacking()).size()
		most = maxi(most, attacking)
	_check(most <= 2, "at most two monsters attack at once (saw %d)" % most)
	for e in main.enemies():
		e.set_physics_process(false)
	p.hp = p.MAX_HP
	await _settle()

	print("hurt and death")
	p.iframes = 0.0
	p.parry_t = 0.0
	p.hurt_t = 0.0
	var hp1: float = p.hp
	p.receive_attack(10.0, slime)
	_check(p.hp < hp1, "monster attack hurts")
	_check(main.hurt_flash > 0.0, "hurt flash shown")
	p.hurt_t = 0.0
	p.receive_attack(999.0, slime)
	_check(p.dead, "climber can die")
	await _settle()

	print("clear the room")
	for e in main.enemies():
		_slay(e)
	await _frames(5)
	await _settle()
	_check(main.cleared, "room clears")
	_check(main.stair_open, "clearing opens the stair")

	print("the climb")
	var unbanked := 0.0
	for k in main.run_essence:
		unbanked += main.run_essence[k]
	_check(unbanked > 0.0, "slain monsters leave essence (%d unbanked)" % int(unbanked))
	var xp0: float = main.profile.bonds["hand"]["xp"]
	p.dead = false
	p.hp = 20.0
	p.set_physics_process(true)
	p.bonds["hand"].burned = true
	p.global_position = main.stair_pos
	await _wait(1.6)
	_check(main.floor_num == 2, "walking onto the stair climbs to floor 2")
	_check(not main.climbing and main.fade < 0.05, "the fade finishes")
	_check(not p.bonds["hand"].burned, "burns heal at the stair")
	_check(p.hp > 20.0, "resting at the stair restores health")
	_check(not main.stair_open, "the new floor's stair starts sealed")
	_check(main.enemies().size() >= 3, "floor 2 has monsters (%d)" % main.enemies().size())
	_check(main.best_floor >= 2, "best floor recorded")
	_check(main.run_essence.is_empty(), "the stair banks your essence")
	_check(main.profile.bonds["hand"]["xp"] > xp0, "banked essence strengthens your marks")
	# Skip ahead a few floors (floor 3's stair leads to the camp first).
	for i in 3:
		main._arrive()
	await _frames(3)
	_check(main.floor_num == 4, "climbed to floor 4")
	main.profile.bonds["hand"]["xp"] = main.ProfileScript.STEP_XP[2] + 10.0
	main._give_bonds()
	_check(p.bonds["hand"].step == 3, "enough banked essence grows a mark to step 3")
	_check(p.bonds["hand"].stat("leaps") == 6, "step 3 Chain Lightning leaps 6 times")
	var foes5: Array = main.enemies()
	_check(foes5.size() >= 4, "floor 4 has more monsters (%d)" % foes5.size())
	_check(foes5[0].max_hp > EnemyHP.get(foes5[0].kind, 0.0), "monsters are tougher higher up")
	var inside := true
	for e in foes5:
		inside = inside and main.room.has_point(e.global_position)
	_check(inside, "monsters spawn inside the room")

	await _regard_tests()
	await _tower_tests()
	await _gryphon_tests()
	await _gryphon_tower_tests()
	await _kraken_tower_tests()
	await _wyvern_tower_tests()
	await _manticore_tower_tests()
	await _firebird_tower_tests()
	await _chimera_tower_tests()
	await _spell_tests()
	await _menu_tests()
	await _screen_tests()
	await _mark_page_tests()
	await _entity_tests()
	await _title_tests()
	await _combat_feel_tests()
	await _density_tests()
	await _bugfix_tests()
	await _jump_tests()
	await _rooms_tests()
	await _terrain_tests()
	await _trap_tests()
	await _room_fog_tests()
	await _puzzle_tests()
	await _wyvern_bond_tests()
	await _manticore_bond_tests()
	await _firebird_bond_tests()
	await _proving_tests()
	await _secret_tests()
	await _secret_bond_tests()
	await _secret_deep_tests()
	await _chimera_bond_tests()
	await _body_part_tests()
	await _item_tests()
	await _camp_tests()
	await _wing_tests()
	await _maker_tests()
	await _mirror_image_tests()
	await _lock_tests()
	await _gear_tests()
	await _heirloom_tests()
	await _gear_slot_tests()
	await _rarity_tests()
	await _belt_tests()
	await _train_tests()
	await _lost_tests()
	await _bench_tests()
	await _economy_tests()
	await _vessel_tests()
	await _controls_tests()
	await _pad_layout_tests()
	await _performance_tests()
	await _lighting_tests()
	await _shadow_tests()
	await _foe_list_tests()
	await _slim_hud_tests()
	await _appearance_tests()
	await _unbound_tests()
	await _rail_tests()
	await _train_rail_tests()
	await _nav_tests()
	await _switch_tests()
	await _rail_line_tests()
	await _climber_slot_tests()
	await _data_editor_tests()
	await _icon_tests()
	await _arrange_tests()

	print("\n%s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	for f in failed:
		print("  FAILED: ", f)
	# Free the room (and its music) before quitting, so nothing leaks at exit.
	main.queue_free()
	await _frames(2)
	quit(1 if failures > 0 else 0)


## A floor of rooms with a sealed wing (and a secret room, if `secret`), its monsters gone.
func _wing_floor(secret := false, content := "") -> bool:
	for n in 80:
		main._start_floor(3 + n % 6)
		await _frames(1)
		var W = main.wings
		if W.wings.is_empty():
			continue
		if secret and (W.secrets.is_empty() or (content != "" and W.secrets[0]["content"] != content)):
			continue
		for e in main.enemies():
			e.queue_free()
		await _frames(2)
		main.banner = {}
		return true
	return false


## Walks the climber into a wing and on to its waves (frozen as they come).
func _enter_wing(w: Dictionary) -> void:
	var p = main.player
	main.open_all_doors()
	p.global_position = w["rect"].get_center()
	await _frames(3)


func _slay_waves(w: Dictionary) -> void:
	var W = main.wings
	for i in 200:
		if w["state"] != "waves":
			return
		for e in W._alive(w["mobs"]):
			_slay(e)
		await _wait(0.1)


func _wing_tests() -> void:
	print("sealed wings, vaults, secret rooms, the recall scroll and crystals")
	await _fresh_main()
	main.grant_test_bonds()
	var F = main.Floors
	var W = main.wings
	var p = main.player
	p.iframes = 0.0
	# Plans: each kept cell that has room gets its wing or secret, inside the cell.
	var made := 0
	var secrets := 0
	var ok_cell := true
	var ok_size := true
	var ok_apart := true
	var ok_secret := true
	var contents := {}
	for n in 40:
		var plan: Dictionary = F.rooms_floor(2 + n % 10, main.Towers.TOWERS[main.Towers.ORDER[n % 6]])
		for w in plan["wings"]:
			made += 1
			ok_cell = ok_cell and w["area"].encloses(w["rect"]) and w["area"].encloses(w["alcove"])
			var t: Rect2i = w["tiles"]
			ok_size = ok_size and t.size.x >= 9 and t.size.x <= 11 and t.size.y >= 7 and t.size.y <= 9 and w["alcove"].size == Vector2(F.CELL, F.CELL) * 3.0
			for r in plan["rooms"]:
				ok_apart = ok_apart and not r.intersects(w["rect"].grow(F.CELL)) and not r.intersects(w["alcove"].grow(F.CELL))
		for s in plan["secrets"]:
			secrets += 1
			contents[s["content"]] = true
			ok_secret = ok_secret and s["area"].encloses(s["rect"]) and minf(s["corridor"].size.x, s["corridor"].size.y) == F.CELL and s["mouth"].size() == 1
	_check(made >= 30 and ok_cell and ok_apart, "sealed wings are carved in the kept cells, apart from every room (%d over 40 floors)" % made)
	_check(ok_size, "a wing room is 9-11 by 7-9 tiles, with a 3x3 vault alcove cut into its wall")
	_check(secrets >= 8 and ok_secret and contents.size() >= 2, "secret rooms are carved in kept cells, joined by a passage one tile wide (%d, holding %s)" % [secrets, contents.keys()])

	# In the tower: the vault's seal shows from the moment you see it.
	_check(await _wing_floor(true), "floors have sealed wings and secret rooms")
	var w: Dictionary = W.wings[0]
	var vd: Vector2i = w["vault_door"]
	_check(main.is_solid(w["seal_pos"]) and main.astar.is_point_solid(vd), "the vault door is shut: a solid tile, on the path grid too")
	_check(main.lighting.lights.has(w["light"]), "light leaks out from under the seal (a light in the registry)")
	var wd: Dictionary = main.door_view.door_at(w["door"][0])
	_check(not wd.is_empty() and wd["style"] == "sealed", "the wing's doorway has a sealed door (the watching eye)")
	main.open_all_doors()
	var inside: Vector2 = W._tile_rect(w["door"]).get_center() - Vector2(w["out"]) * 34.0
	p.global_position = inside
	await _frames(3)
	main.camera.reset_smoothing()
	var fi: int = vd.y * main.grid_size.x + vd.x
	for k in 20:  # (the fog looks again up to 12 times a second; slower on a busy machine)
		await _wait(0.1)
		if main.fog.vis[fi] == 1 and w["seal_pos"] in W._anim_points(w):
			break
	_check(main.fog.vis[fi] == 1 and w["seal_pos"] in W._anim_points(w), "stepping into the doorway, the seal is in sight, and drawn pulsing")
	_check(w["state"] == "idle", "...and the wing stays open until you're really inside")
	# Walk in: the way shuts behind you.
	w["condition"] = "untouched"
	w["fail"] = "lesser"
	await _enter_wing(w)
	var gate: Vector2 = W._tile_rect(w["door"]).get_center()
	_check(w["state"] == "closing" and main.is_solid(gate) and main.astar.is_point_solid(w["door"][0]), "walking in shuts the way behind you (solid, on the path grid)")
	_check(main.banner.get("lines", [""])[0] == W.TEXT["sealed"], "...with its banner: %s" % main.banner.get("lines", [""])[0])
	p.global_position = gate - Vector2(w["out"]) * 60.0
	await _frames(2)
	p.global_position = gate + Vector2(w["out"]) * 70.0
	await _frames(2)
	_check(main.is_solid(gate), "(a sealed doorway stays shut)")
	p.global_position = w["rect"].get_center()
	await _wait(float(W.WAVES["close_time"]) + float(W.WAVES["rule_time"]) + 0.3)
	_check(w["state"] == "waves" and not W._alive(w["mobs"]).is_empty() and W.challenge_live(), "then the Regard states its rule and the waves come (%d)" % W._alive(w["mobs"]).size())
	_check(W._alive(w["mobs"]).all(func(e): return w["rect"].grow(4.0).has_point(e.global_position) and e.aware), "the waves appear inside the wing, awake")
	_check(not W.status().is_empty() and W.status()["ok"], "the HUD shows the rule, kept")
	for e in W._alive(w["mobs"]):
		e.set_physics_process(false)
	await _slay_waves(w)
	await _frames(2)
	_check(w["vault"] == "open" and not main.is_solid(gate) and not main.is_solid(w["seal_pos"]), "beat the waves keeping the rule: the vault opens, and the way out")
	# The pedestal: walk up and choose.
	p.global_position = w["pedestal"] + Vector2(0, 6)
	await _frames(3)
	_check(main.camp_choosing and main.camp["stage"] == "vault" and main.camp["choices"].size() == 3, "the vault's pedestal offers three cards")
	var crystal_cards: Array = main.camp["choices"].filter(func(c): return String(c).begins_with("crystal:"))
	_check(crystal_cards.size() == 2 and crystal_cards[0].get_slice(":", 1) != crystal_cards[1].get_slice(":", 1), "two of them are essence crystals of different kinds")
	var card: Dictionary = main.camp_card(0)
	_check(card.has("crystal") and String(card["name"]).ends_with("Crystal"), "a crystal card reads as one (%s)" % card.get("name", ""))
	var card0: String = main.camp["choices"][0]
	var held0: float = main.profile.crystal_total(card0.get_slice(":", 1))
	main.choose_camp(0)
	_check(not main.camp_choosing and is_equal_approx(main.profile.crystal_total(card0.get_slice(":", 1)), held0 + round(float(card0.get_slice(":", 2)))), "choosing a crystal card keeps the crystal (combined with your crystal of that kind)")
	p.global_position = w["pedestal"] + Vector2(0, 6)
	await _frames(3)
	_check(not main.camp_choosing, "(a pedestal gives once)")
	# A rule broken, the lesser way: the vault opens with less.
	_check(await _wing_floor(), "another wing")
	w = W.wings[0]
	w["condition"] = "untouched"
	w["fail"] = "lesser"
	await _enter_wing(w)
	await _wait(float(W.WAVES["close_time"]) + float(W.WAVES["rule_time"]) + 0.3)
	for e in W._alive(w["mobs"]):
		e.set_physics_process(false)
	p.hits_taken += 1  # struck
	await _frames(2)
	_check(w["broken"] and not W.status()["ok"], "taking a hit breaks a \"take no hit\" rule")
	gate = W._tile_rect(w["door"]).get_center()
	_check(main.is_solid(gate), "...but the way stays shut until the waves are beaten")
	await _slay_waves(w)
	await _frames(2)
	_check(w["vault"] == "lesser" and not main.is_solid(gate), "then the vault opens with a lesser prize, and the way out")
	_check(W.vault_choices(true).size() == 2, "a lesser prize is two cards")
	# A rule broken, the champion's way: the way reopens when it falls; the vault stays dark.
	_check(await _wing_floor(), "a third wing")
	w = W.wings[0]
	w["condition"] = "swift"
	w["fail"] = "champion"
	await _enter_wing(w)
	await _wait(float(W.WAVES["close_time"]) + float(W.WAVES["rule_time"]) + 0.3)
	for e in W._alive(w["mobs"]):
		e.set_physics_process(false)
	w["clock"] = float(w["limit"]) + 1.0  # too slow
	await _frames(2)
	var champ = w.get("champ")
	_check(w["broken"] and w["state"] == "champion" and champ != null and champ.champion, "breaking a \"be quick\" rule brings the tower's champion")
	if champ != null:
		champ.set_physics_process(false)
		var base: float = champ.TYPES[champ.kind]["hp"]
		_check(champ.max_hp > base * 3.0 and champ.dmg > champ.TYPES[champ.kind]["dmg"], "a champion is a tougher %s (%d health)" % [champ.kind, int(champ.max_hp)])
	gate = W._tile_rect(w["door"]).get_center()
	_check(main.is_solid(gate), "...and the way stays shut while it stands")
	for e in W._alive(w["mobs"]):
		_slay(e)
	if champ != null:
		_slay(champ)
	await _frames(3)
	_check(w["vault"] == "dark" and not main.is_solid(gate) and main.is_solid(w["seal_pos"]), "its fall reopens the way; the vault stays locked for good")
	_check(w.has("drop"), "the champion leaves an essence crystal")
	if w.has("drop"):
		held0 = main.profile.crystal_total(w["drop"]["kind"])
		p.global_position = w["drop"]["pos"]
		await _frames(3)
		_check(main.profile.crystal_total(w["drop"]["kind"]) > held0, "walking over it keeps the crystal")
	# Never trapped: a puzzle host's answer, or the room giving up.
	_check(await _wing_floor(), "a fourth wing")
	w = W.wings[0]
	await _enter_wing(w)
	W.wing_solved(w["id"])
	gate = W._tile_rect(w["door"]).get_center()
	_check(w["vault"] == "open" and not main.is_solid(gate), "a puzzle host can answer a wing: wing_solved() opens the vault and the way")
	_check(await _wing_floor(), "a fifth wing")
	w = W.wings[0]
	await _enter_wing(w)
	await _wait(float(W.WAVES["close_time"]) + float(W.WAVES["rule_time"]) + 0.3)
	for e in W._alive(w["mobs"]):
		e.set_physics_process(false)
	w["clock"] = W.FAILSAFE + 1.0
	await _frames(2)
	gate = W._tile_rect(w["door"]).get_center()
	_check(w["state"] == "done" and not main.is_solid(gate), "a question that runs too long gives up: the way always reopens")
	main.banner = {}

	# Vault rewards: crystals, gear, a recall scroll, an item.
	var kinds := {}
	for i in 80:
		for c in W.vault_choices(false):
			kinds[String(c).get_slice(":", 0)] = true
	_check(kinds.has("crystal") and kinds.has("gear") and kinds.has("scroll"), "vault cards: crystals, gear, a recall scroll or an item (%s)" % [kinds.keys()])
	main._take_vault_pick("gear:axe")
	_check(p.gear_id("melee") == "axe", "a gear card is taken into its slot")
	_check(p.add_item("scroll") and not p.add_item("scroll") and p.item_count("scroll") == 1, "you carry only one recall scroll")
	var offered := false
	for i in 80:
		offered = offered or "scroll" in W.vault_choices(false)
	_check(not offered, "...so a vault doesn't offer another while you carry one")
	_check(p.selected_item() != "scroll", "(a scroll never takes the quick item from another)")
	var hidden: Array = W.hidden_crystals()
	_check(hidden.size() == 3 and hidden.all(func(c): return String(c).begins_with("crystal:")), "a hidden crystal choice offers three kinds")

	# Consuming a crystal banks its essence into you.
	main.profile.crystals = []
	main.profile.add_crystal("air", 40.0)
	var xp0: float = main.profile.bonds["hand"]["xp"]
	var lines: Array = main.consume_crystal("air")
	var step := float(main.Items.CRYSTAL["step"])
	_check(main.profile.crystal_total("air") == 40.0 - step and main.profile.bonds["hand"]["xp"] > xp0 and not lines.is_empty(), "consuming banks a step of a crystal's essence into your marks (%s)" % [lines])
	for i in 10:
		main.consume_crystal("air")
	_check(main.profile.crystal_count("air") == 0 and main.consume_crystal("air").is_empty(), "(all of it consumed: none left, nothing happens)")

	# Secret rooms.
	_check(await _wing_floor(true, ""), "a floor with a secret room")
	var s: Dictionary = W.secrets[0]
	var mouth: Vector2i = s["mouth"][0]
	var mc: Vector2 = W._tile_center(mouth)
	var into: Vector2 = s["into"]
	var deep: Vector2 = s["rect"].get_center()
	_check(main.is_solid(mc) and main.is_solid(deep), "a secret room is solid rock to sight and paths until it opens")
	p.global_position = mc - into * 40.0
	await _frames(4)
	var di: int = main._tile_of(deep).y * main.grid_size.x + main._tile_of(deep).x
	_check(main.fog.vis[di] == 0, "standing at its wall, the room behind stays hidden in the fog")
	s["dust_t"] = 0.01
	await _frames(3)
	_check(s["dust_t"] > 1.0, "dust drifts down near it now and then")
	main.audio.last_played.erase("hit_blunt")
	var k0: int = W.knocks
	p.aim = into
	await _swing()
	_check(W.knocks == k0 + 1 and main.audio.last_played.has("hit_blunt"), "striking it gives a hollow knock")
	var plain: bool = W.keen_outlined(s)
	main.profile.add_bond("brow", "hunter", false)
	main._give_bonds()
	main.camera.reset_smoothing()
	await _frames(2)
	_check(not plain and W.keen_outlined(s) and W._anim_on_screen(), "Hunter's Keen Eyes outline it (others see a plain wall)")
	# Lean into it.
	var key := "move_down" if into == Vector2.DOWN else ("move_up" if into == Vector2.UP else ("move_right" if into == Vector2.RIGHT else "move_left"))
	p.global_position = mc - into * 34.0
	await _frames(2)
	Input.action_press(key)
	await _wait(0.3)
	var early: bool = s["open"]
	await _wait(0.9)
	Input.action_release(key)
	await _frames(2)
	_check(not early and s["open"], "leaning into it for a moment grinds it open")
	_check(not main.is_solid(mc) and not main.is_solid(deep) and not main.astar.is_point_solid(mouth), "...a passage and a room, open to walk and to the path grid")
	p.global_position = W._tile_center(s["door"][0]) + into * 30.0
	await _frames(4)
	_check(main.fog.vis[di] == 1, "...and in sight once you step in")
	# A Tithe Door asks for unbanked essence.
	if await _wing_floor(true, "tithe"):
		s = W.secrets[0]
		W._open_secret(s)
		_check(main.is_solid(s["seal_pos"]), "a Tithe Door stands shut in its secret room")
		main.run_essence = {"fire": 5.0}
		_check(not W.pay_tithe(s) and s["vault"] == "sealed", "it won't open for less than it asks (%d)" % int(s["cost"]))
		main.run_essence = {"fire": float(s["cost"]) * 0.5 + 4.0, "air": float(s["cost"]) * 0.5}
		_check(W.pay_tithe(s) and s["vault"] == "open" and not main.is_solid(s["seal_pos"]), "paid, it opens")
		var left := 0.0
		for k2 in main.run_essence:
			left += main.run_essence[k2]
		_check(absf(left - 4.0) < 0.01, "the tithe comes out of your unbanked essence (%.1f left)" % left)
	main.run_essence = {}

	# The recall scroll: leave safely, unbanked essence turned to crystals.
	main.banner = {}
	main.camp_choosing = false
	p.set_physics_process(true)
	main.profile.crystals = []
	main.run_essence = {"fire": 23.4, "air": 5.0}
	main.run_soak = {"back": 4.0}
	p.items = {"scroll": 1}  # (other belt items would break into crystals too)
	p.item_sel = "scroll"
	main.climb_paid = false
	var tk: String = main.tower_data()["essence"]
	var pay: int = main.Train.climb_pay(main.floor_num, main.climb_best0)
	_check(not p.use_item() and main.victory.is_empty() and main.banner.get("title", "") == main.Items.RECALL["ask_title"], "using the scroll asks first")
	_check(p.use_item(), "...and a second use reads it")
	_check(not main.victory.is_empty() and main.victory.get("recall", false), "reading it ends the climb safely")
	var fire_pay := pay if tk == "fire" else 0
	var air_pay := pay if tk == "air" else 0
	_check(main.profile.crystal_count("fire") == 1 and int(main.profile.crystal_total("fire")) == 23 + fire_pay and int(main.profile.crystal_total("air")) == 5 + air_pay, "unbanked essence settles into crystals, one per kind")
	_check(pay > 0 and int(main.profile.crystal_total(tk)) >= pay and main.victory["lines"].has(main.pay_line) and main.pay_line.contains(str(pay)), "a recall is paid for too: %s" % main.pay_line)
	_check(main.run_essence.is_empty() and p.item_count("scroll") == 0 and main.profile.soak.get("back", 0.0) > 0.0, "the scroll is used up, and nothing else is lost")
	main.victory["t"] = 9.0
	main.end_regard()
	_check(not main.camp_choosing and not main.heirloom_offered, "no heirloom choice after a recall (the climb wasn't won)")
	main.victory = {}
	# On the first climb the words won't come.
	await _fresh_main()
	main.player.add_item("scroll")
	main.player.item_sel = "scroll"
	main.player.use_item()
	main.player.use_item()
	_check(main.victory.is_empty() and main.player.item_count("scroll") == 1, "the scroll can't be read before the Regard")


## A floor with a locked door of this kind (its monsters gone unless `keep`), or {}.
func _locked_floor(kind: String, keep := false) -> Dictionary:
	for n in 120:
		main._start_floor(3 + n % 8)
		await _frames(1)
		var locked: Array = main.door_view.list.filter(func(d): return d["lock"] == kind)
		if locked.is_empty():
			continue
		if not keep:
			for e in main.enemies():
				if not e.has_meta("key"):
					e.queue_free()
		await _frames(2)
		main.banner = {}
		return locked[0]
	return {}


func _lock_tests() -> void:
	print("locked doors and lock-in rooms")
	await _fresh_main()
	main.grant_test_bonds()
	var F = main.Floors
	var p = main.player
	# Plans: locks only off the main route, opened from the main route.
	var kinds := {}
	var ok_off := true
	var ok_host := true
	var floors_locked := 0
	for n in 60:
		var plan: Dictionary = F.rooms_floor(3 + n % 9, main.Towers.TOWERS[main.Towers.ORDER[n % 6]])
		var infos: Array = plan["room_info"]
		if not plan["locks"].is_empty():
			floors_locked += 1
		for d in plan["doors"]:
			if d.get("lock", "") != "":
				kinds[d["lock"]] = true
				ok_off = ok_off and infos[d["room"]]["role"] == "branch"
		for l in plan["locks"]:
			if l.has("pos"):
				var host := -1
				for i in infos.size():
					if infos[i]["rect"].has_point(l["pos"]):
						host = i
				ok_host = ok_host and host >= 0 and infos[host]["role"] in ["guard", "stair", "entrance"]
			if l.has("carrier"):
				var mp: Vector2 = plan["monsters"][l["carrier"]][1]
				ok_host = ok_host and infos.any(func(ri): return ri["role"] in ["guard", "stair"] and ri["rect"].has_point(mp))
	_check(floors_locked >= 25 and kinds.size() >= 3, "most floors have a locked door, of several kinds (%d of 60: %s)" % [floors_locked, kinds.keys()])
	_check(ok_off, "only doors off the main route are locked (branch rooms and wings)")
	_check(ok_host, "keys, levers and key carriers wait on the main route, reachable without passing the lock")
	# The stair is always reachable with the locked doors still shut; so are their keys and levers.
	var ok_reach := true
	for n in 16:
		main._start_floor(3 + n % 8)
		await _frames(1)
		for d in main.door_view.list:
			if d["lock"] == "" and not d["open"]:
				main.door_view.open_door(d, true)
		var from: Vector2i = main._tile_of(main.player_start)
		var goals: Array = [main.stair_pos]
		for k in main.door_view.keys + main.door_view.levers:
			goals.append(k["pos"])
		for e in main.enemies():
			if e.has_meta("key"):
				goals.append(e.global_position)
		for g in goals:
			ok_reach = ok_reach and not main.astar.get_id_path(from, main._tile_of(g)).is_empty()
	_check(ok_reach, "with locked doors still shut, the stair and every key and lever can be reached")
	# A key lying in another room.
	var d: Dictionary = await _locked_floor("key")
	_check(not d.is_empty(), "a floor with a door locked by a key")
	if not d.is_empty():
		var dc: Vector2 = d["rect"].get_center()
		var out: Vector2 = d["out"]
		_check(main.is_solid(dc) and main.astar.is_point_solid(d["tiles"][0]), "a locked door is solid, on the path grid too")
		var b0: int = main.door_view.bumps
		main.door_view.bump_t = 0.0
		p.global_position = dc + out * 50.0
		await _frames(3)
		_check(not d["open"] and main.door_view.bumps == b0 + 1 and main.banner.get("title", "") == "LOCKED", "bumping it: it stays shut and says it's locked, and how it opens")
		var foe = await _spawn("slime", dc + out * 50.0)
		foe.aware = true
		main.door_view.monster_t = 0.0
		p.global_position = main.player_start
		await _wait(0.3)
		_check(not d["open"], "monsters can't open a locked door either")
		foe.queue_free()
		var k: Dictionary = main.door_view.keys.filter(func(x): return x["lock_id"] == d["lock_id"])[0]
		p.global_position = k["pos"]
		await _frames(3)
		_check(k["taken"] and d["lock_id"] in main.door_view.held, "walking over the key picks it up")
		p.global_position = dc + out * 50.0
		await _frames(3)
		_check(d["open"] and not main.is_solid(dc), "with the key, the door opens")
	# A lever elsewhere.
	d = await _locked_floor("lever")
	_check(not d.is_empty(), "a floor with a door barred by a lever")
	if not d.is_empty():
		var l: Dictionary = main.door_view.levers.filter(func(x): return x["lock_id"] == d["lock_id"])[0]
		p.global_position = l["pos"] + Vector2(-30, 0)
		p.aim = Vector2.RIGHT
		await _frames(2)
		await _swing()
		_check(l["pulled"] and d["lock"] == "" and main.banner.get("title", "") == main.door_view.LOCK_TEXT["lever_title"], "striking the lever lifts the bars, with a banner")
		p.global_position = d["rect"].get_center() + d["out"] * 50.0
		await _frames(3)
		_check(d["open"], "...and the door opens when you come")
	# The floor's puzzle.
	d = await _locked_floor("puzzle")
	if not d.is_empty():
		main.lift_ward()
		_check(d["lock"] == "", "a warded door opens when the floor's puzzle is solved")
	# A monster carries the key.
	var carrier: Array = []
	for attempt in 3:  # (a rare floor loses its carrier before the test looks, e.g. to a trap; plan another)
		d = await _locked_floor("carried")
		if d.is_empty():
			break
		carrier = main.enemies().filter(func(e): return e.has_meta("key") and int(e.get_meta("key")) == int(d["lock_id"]))
		if carrier.size() == 1:
			break
	if not d.is_empty():
		_check(carrier.size() == 1, "one monster carries the key (%d)" % carrier.size())
		if carrier.size() == 1:
			var at: Vector2 = carrier[0].global_position
			_slay(carrier[0])
			await _frames(2)
			_check(main.door_view.keys.any(func(x): return x["lock_id"] == d["lock_id"] and x["pos"].distance_to(at) < 48.0), "slain, it drops the key where it fell")
	main.door_view.open_all()
	_check(main.door_view.locked_count() == 0, "(the dev tool's Open all opens locked doors too)")

	# Lock-in rooms.
	var li := -1
	for n in 80:
		main._start_floor(3 + n % 6)
		await _frames(1)
		for i in main.door_view.lock_rooms:
			var rect: Rect2 = main.room_info[i]["rect"]
			# (A monster standing in a doorway keeps it from shutting, rightly;
			# and a room you start in was entered long ago.)
			var gates_clear := true
			for g in main.door_view.lock_rooms[i]["gates"]:
				var gr: Rect2 = main.door_view._tiles_rect(g).grow(40.0)
				gates_clear = gates_clear and not main.enemies().any(func(e): return gr.has_point(e.global_position))
			if gates_clear and not rect.grow(40.0).has_point(main.player_start) and main.enemies().any(func(e): return rect.grow(-40.0).has_point(e.global_position)):
				li = i
				break
		if li >= 0:
			break
	_check(li >= 0, "some rooms lock you in (%s)" % (main.room_themes[li] if li >= 0 else "none"))
	if li >= 0:
		var lr: Dictionary = main.door_view.lock_rooms[li]
		var rect: Rect2 = main.room_info[li]["rect"]
		main.open_all_doors()
		for e in main.enemies():
			e.set_physics_process(false)
		main.banner = {}
		p.global_position = rect.get_center()
		await _until(func(): return lr["state"] == "shut", 2.0)
		await _frames(2)
		var gate: Vector2 = main.door_view._tiles_rect(lr["gates"][0]).get_center()
		_check(lr["state"] == "shut" and main.is_solid(gate) and main.astar.is_point_solid(lr["gates"][0][0]), "stepping in shuts its doorways (solid, on the path grid)")
		_check(main.banner.get("title", "") == main.door_view.LOCK_TEXT["shut_title"] and not main.door_view.lock_status().is_empty(), "...with a slam, a banner and the foes left on screen")
		for e in lr["mobs"]:
			_slay(e)
		await _wait(0.4)
		_check(lr["state"] == "done" and not main.is_solid(gate), "they open once its monsters are dead")
		p.global_position = main.player_start
		await _frames(2)
		p.global_position = rect.get_center()
		await _frames(3)
		_check(not main.is_solid(gate), "(and stay open)")
	# A lock-in room with nobody in it never shuts.
	var empty_ok := false
	for n in 40:
		main._start_floor(3 + n % 6)
		await _frames(1)
		# (a restless crypt raises its own foes as you walk in: not an empty room)
		var calm: Array = main.door_view.lock_rooms.keys().filter(func(k): return k >= main.room_themes.size() or main.room_themes[k] != "crypt")
		if calm.is_empty():
			continue
		var i: int = calm[0]
		for e in main.enemies():
			e.queue_free()
		await _frames(2)
		main.open_all_doors()
		p.global_position = main.room_info[i]["rect"].get_center()
		await _frames(4)
		var lr: Dictionary = main.door_view.lock_rooms[i]
		empty_ok = lr["state"] == "done" and not lr["gates"].any(func(g): return main.is_solid(main.door_view._tiles_rect(g).get_center()))
		break
	_check(empty_ok, "a lock-in room with no monsters left never shuts you in")


## The inventory slot with this key ("gear:melee", "item:draught", "heir:helm"...), or null.
func _slot(key: String):
	for b in main.menu.find_children("*", "Button", true, false):
		if b.get_meta("slot", "") == key and b.is_visible_in_tree():
			return b
	return null


## Esc's pause menu, Tab's climber screen and I's inventory, by keys,
## controller and touch.
func _screen_tests() -> void:
	print("pause, climber and inventory screens")
	await _fresh_main()
	var M = load("res://scripts/menu.gd")
	main.touch._set_active(false)
	var p = main.player
	var menu = main.menu
	main.grant_test_bonds()
	p.take_gear("axe")
	p.add_item("tonic")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "pause" and paused, "Esc opens the pause menu")
	var want := ["Climber", "Resume", "Inventory", "Library", "Settings & Controls", "Dev Tools", "Restart this climb", "Exit to Title"]
	var have: Array = _all_buttons(menu).map(func(b): return b.text)
	var missing := want.filter(func(t): return not (t in have))
	_check(missing.is_empty(), "...with who you are (Climber), Resume, Inventory, Library, Settings & Controls, Dev Tools, Restart and Exit to Title (missing %s)" % [missing])
	_check(("Quit game" in have) == menu.can_quit() and menu.can_quit() != OS.has_feature("web"), "Quit game only where the game can be quit (not on the web)")
	_check(not have.any(func(t): return t.begins_with("Start over")), "...and no Start over beside them (it's in Settings & Controls)")
	menu.open("settings")
	await _frames(2)
	var over_b: Array = menu.focusables().filter(func(b): return b.has_meta("over"))
	_check(over_b.size() == 1 and over_b[0].text == main.Train.TEXT["over"], "Settings & Controls has Start over this climber, set apart at its foot")
	if not over_b.is_empty():
		over_b[0].pressed.emit()
	await _frames(1)
	_check(menu.page == "confirm_new", "Start over asks first")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "settings", "...and Esc cancels back to Settings & Controls")
	menu.open("pause")
	await _frames(1)
	for b in _all_buttons(menu):
		if b.text.begins_with("Inventory"):
			b.pressed.emit()
	await _frames(1)
	_check(menu.page == "inventory" and menu.rail.visible and menu.rail.current == "inventory" and _menu_button("Close") != null, "the pause menu's rail opens the inventory beside it, with Close")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "inventory" and menu.rail.has_focus_inside(), "...and Esc goes back to the rail")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open() and not paused, "Esc on the rail resumes")

	# Tab: the climber screen.
	await _key_tap(KEY_TAB)
	_check(menu.page == "climber" and paused, "Tab opens the climber screen and pauses")
	_check(_menu_button("Close") != null, "...with Close (not Back)")
	var cards: Array = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == M.MarkCard)
	_check(cards.size() == 6 and menu.find_children("*", "Control", true, false).any(func(c): return c.get_script() == M.BodyView), "...the body and a card for each of the six parts")
	var tabs: Array = _all_buttons(menu).filter(func(b): return b.has_meta("tab"))
	_check(tabs.size() == menu.CLIMBER_TABS.size() and tabs.size() == 3, "...and its tabs (Marks, Essence, Record; the Archive is the Library now)")
	tabs[1].pressed.emit()
	await _frames(1)
	_check(menu.climber_tab == "essence" and menu.find_children("*", "Control", true, false).any(func(c): return c.get_script() == M.EssenceView), "the Essence tab shows density and attributes")
	menu.climber_tab = "marks"
	await _key_tap(KEY_I)
	_check(menu.page == "inventory", "I from the climber screen switches to the inventory")
	await _key_tap(KEY_TAB)
	_check(menu.page == "climber", "...and Tab back")
	await _key_tap(KEY_TAB)
	_check(not main.menu_open() and not paused, "Tab again closes it")
	await _key_tap(KEY_TAB)
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open() and not paused, "Esc closes a screen opened with Tab")

	# I: the inventory.
	await _key_tap(KEY_I)
	_check(menu.page == "inventory" and paused, "I opens the inventory and pauses")
	var melee = _slot("gear:melee")
	_check(_slot("gear:fists") != null and melee != null and melee.id == "axe" and melee.on and _slot("gear:ranged").id == "shortbow" and _slot("gear:armor") != null, "...carried gear in slots: fists, the axe in hand, the bow, armor")
	var draught = _slot("item:draught")
	_check(draught != null and draught.count == 1 and _slot("item:tonic").count == 1 and _slot("item:vial") == null, "...the belt's items with their counts")
	_check(_slot("belt:2") != null and _slot("belt:3") != null and _slot("belt:4") == null, "...and its two empty cells (a belt of 4 kinds)")
	_check(_slot("gear:offhand") != null and _slot("gear:offhand").locked, "...the off-hand kept for later, locked")
	menu._inv_view("heirlooms")
	await _frames(2)
	var planned := 0
	var heir_cells := 0
	for b in menu.find_children("*", "Button", true, false):
		if String(b.get_meta("slot", "")).begins_with("heir:") and b.is_visible_in_tree():
			heir_cells += 1
			if b.locked:
				planned += 1
	_check(heir_cells == 13 and planned == 1 and not _slot("heir:melee").locked, "...and the Heirlooms view: every slot on the doll, only the off-hand locked (%d cells)" % heir_cells)
	menu._inv_view("worn")
	await _frames(2)
	_check(_slot("rune") == null, "no rune slot without a camp rune")
	_slot("item:draught").focus_entered.emit()
	await _frames(1)
	var use: Button = _menu_button("Use")
	_check(use != null and not use.disabled, "an item's details offer Use")
	p.hp = p.max_hp * 0.5
	use.pressed.emit()
	await _frames(1)
	_check(p.item_count("draught") == 0 and menu.page == "inventory", "Use drinks the draught from the inventory")
	await _key_tap(KEY_I)
	_check(not main.menu_open() and not paused, "I again closes it")
	p.camp_rune = "warding"
	await _key_tap(KEY_I)
	_check(_slot("rune") != null and _slot("rune").id == "warding", "a camp rune shows in its own slot")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open(), "Esc closes the inventory")
	p.camp_rune = ""

	# Controller: a short press of View is the climber screen, d-pad up the inventory.
	await _pad_tap(JOY_BUTTON_BACK)
	await _frames(2)
	_check(menu.page == "climber" and not main.restart_armed, "a short press of View opens the climber screen (no restart)")
	await _pad_tap(JOY_BUTTON_BACK)
	await _frames(2)
	_check(not main.menu_open(), "...and again closes it")
	await _pad_tap(JOY_BUTTON_DPAD_UP)
	_check(menu.page == "inventory" and paused, "d-pad up opens the inventory")
	await _pad_tap(JOY_BUTTON_B)
	_check(not main.menu_open() and not paused, "...and B closes it")
	await _pad_tap(JOY_BUTTON_START)
	_check(menu.page == "pause", "Start opens the pause menu")
	await _pad_tap(JOY_BUTTON_START)
	_check(not main.menu_open(), "...and closes it")
	await _key_tap(KEY_W)

	# Touch: Climber and Bag buttons at the top, beside Menu.
	main.touch._set_active(true)
	await _frames(2)
	main.touch._layout()
	var ids: Array = main.touch.buttons.map(func(b): return b["id"])
	_check("climber" in ids and "inventory" in ids and "menu" in ids, "phones get Climber and Bag buttons beside Menu")
	var view: Vector2 = main.touch.get_viewport_rect().size
	var clear := true
	for id in ["climber", "inventory"]:
		var b: Dictionary = main.touch.buttons[ids.find(id)]
		if not Rect2(Vector2.ZERO, view).has_point(b["c"]) or b["c"].y > view.y * 0.2 or b["c"].x < view.x * 0.5:
			clear = false
		for o in main.touch.buttons:
			if o != b and b["c"].distance_to(o["c"]) < b["r"] + o["r"] + 2.0:
				clear = false
				print("    overlaps: ", id, " and ", o["id"])
	_check(clear, "...at the top right, clear of every other button")
	var cb: Dictionary = main.touch.buttons[ids.find("climber")]
	await _tap_at(cb["c"])
	_check(menu.page == "climber" and paused, "tapping Climber opens the climber screen")
	await _tap_at(_menu_button("Close").get_global_rect().get_center())
	await _frames(2)
	_check(not main.menu_open() and not paused, "...and tapping Close shuts it")
	main.touch._layout()
	var ib: Dictionary = main.touch.buttons[ids.find("inventory")]
	await _tap_at(ib["c"])
	_check(menu.page == "inventory", "tapping Bag opens the inventory")
	await _tap_at(_slot("item:tonic").get_global_rect().get_center())
	_check(menu.inv_sel == "item:tonic", "tapping a slot shows its details")
	await _tap_at(_menu_button("Close").get_global_rect().get_center())
	await _frames(2)
	_check(not main.menu_open(), "...and Close shuts the inventory")
	main.touch._set_active(false)
	p.touch_aim = false

	# Exit goes back to the title.
	menu.open("pause")
	await _frames(1)
	Engine.set_meta("sixfold_title_seen", true)
	_menu_button("Exit to Title").pressed.emit()
	await _frames(2)
	_check(menu.page == "title" and not Engine.has_meta("sixfold_title_seen"), "Exit goes back to the title screen")
	menu.close()
	await _frames(2)


## The spell cards on a mark's page (each carries its spell id and learn step).
func _spell_cards() -> Array:
	return main.menu.find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("spell") and c.is_visible_in_tree())


## A mark's detail page (by mouse, keys, controller and touch), the HUD size
## setting, the remembered climber tab, the HUD's tooltips and quick item,
## and gear at your feet in the inventory.
func _mark_page_tests() -> void:
	print("mark pages, HUD size and menu comforts")
	await _fresh_main()
	var M = load("res://scripts/menu.gd")
	main.touch._set_active(false)
	var p = main.player
	var menu = main.menu
	main.grant_test_bonds()  # Stormcaller on the hand and Windwalker on the legs, both at step 1
	await _key_tap(KEY_TAB)
	menu._set_climber_tab("marks")
	await _frames(1)
	var cards: Array = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == M.MarkCard)
	_check(cards.size() == 6 and cards.all(func(c): return c is Button and c.focus_mode == Control.FOCUS_ALL), "the mark cards are buttons you can focus")
	var hand = cards.filter(func(c): return c.part == "hand")[0]
	hand.pressed.emit()
	await _frames(2)
	_check(menu.page == "mark" and menu.mark_part == "hand" and paused, "pressing a mark's card opens its page")
	var data: Dictionary = main.BondScript.Bonds.BONDS["stormcaller"]
	var spells := _spell_cards()
	_check(spells.size() == data["spells"].size(), "...listing every spell, learned or not (%d of %d)" % [spells.size(), data["spells"].size()])
	var right := true
	for i in spells.size():
		var sp: Dictionary = data["spells"][i]
		if spells[i].get_meta("spell") != sp["id"] or spells[i].get_meta("learn") != int(sp["learn"]) or spells[i].get_meta("locked") != (int(sp["learn"]) > 1):
			right = false
	_check(right, "...each with the step that teaches it, the ones past step 1 locked")
	var texts: Array = _all_labels(menu).map(func(l): return l.text)
	_check("learned at step 4" in texts and "learned at step 5" in texts and "Quick Nerves" in texts and "Static" in texts, "...saying 'learned at step N', with the body and passive effects")
	var rich: Array = menu.find_children("*", "RichTextLabel", true, false).map(func(r): return r.text)
	_check(rich.any(func(t): return t.contains("Cost 12 essence") and t.contains("Wind-up 0.45 s")), "...the cost and wind-up of each spell")
	_check(rich.any(func(t): return t.contains("Step 3:") and t.contains("leaps 2 more times")), "...and what later steps change")
	_check(_menu_button("Back") != null, "...with Back")
	menu.scroll.scroll_vertical = 200
	await _key_tap(KEY_E)
	_check(menu.page == "mark" and menu.mark_part != "hand" and menu.scroll.scroll_vertical == 0, "E shows the next mark, from its top")
	await _key_tap(KEY_Q)
	_check(menu.mark_part == "hand", "...and Q the one before")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "climber" and menu.climber_tab == "marks", "Esc goes back to the Marks tab")
	await _frames(2)
	var focus: Control = menu.get_viewport().gui_get_focus_owner()
	_check(focus != null and focus.get_meta("part", "") == "hand", "...with the hand's card focused again")
	# Keyboard: Enter on the focused card.
	await _key_tap(KEY_ENTER)
	_check(menu.page == "mark" and menu.mark_part == "hand", "Enter on a focused card opens its page")
	await _key_tap(KEY_TAB)
	_check(not main.menu_open() and not paused, "Tab on a mark's page closes the climber screen")
	# An unmarked part shows what's forming there, and has no spells to list.
	main.add_soak("throat", 5.0)
	menu.open("climber", true)
	menu.open_mark("throat")
	await _frames(2)
	texts = _all_labels(menu).map(func(l): return l.text)
	_check(menu.page == "mark" and _spell_cards().is_empty() and texts.any(func(t): return t.contains("soaks up essence")), "an unmarked part's page says what soaks into it")
	rich = menu.find_children("*", "RichTextLabel", true, false).map(func(r): return r.text)
	_check(rich.any(func(t): return t.contains("forming here")), "...and that the next mark is forming there")
	menu.close()
	await _frames(2)
	# Controller: A on a focused card opens it, B goes back.
	await _pad_tap(JOY_BUTTON_BACK)
	await _frames(2)
	_check(menu.page == "climber", "View opens the climber screen")
	var pcard = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == M.MarkCard and c.part == "legs")[0]
	pcard.grab_focus()
	await _frames(1)
	await _pad_tap(JOY_BUTTON_A)
	_check(menu.page == "mark" and menu.mark_part == "legs", "A on a focused card opens its page")
	await _pad_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(menu.mark_part != "legs", "RB shows the next mark")
	await _pad_tap(JOY_BUTTON_B)
	_check(menu.page == "climber", "B goes back to the cards")
	await _pad_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(menu.climber_tab == "essence", "RB switches the climber screen's tab")
	await _pad_tap(JOY_BUTTON_B)
	_check(not main.menu_open(), "...and B closes it")
	await _key_tap(KEY_W)
	# The tab is remembered, even by a fresh room.
	_check(menu.settings["climber_tab"] == "essence", "the last climber tab is remembered")
	await _fresh_main()
	main.touch._set_active(false)
	_check(main.menu.climber_tab == "essence", "...and a new room opens the climber screen on it")
	main.menu._set_climber_tab("marks")
	main.menu.close()
	menu = main.menu
	p = main.player
	main.grant_test_bonds()
	# Touch: tap a card, then Back.
	main.touch._set_active(true)
	await _frames(2)
	menu.open("climber", true)
	await _frames(3)
	var tcard = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == M.MarkCard and c.part == "hand")[0]
	var box_rect: Rect2 = menu.scroll.get_global_rect()
	_check(box_rect.has_point(tcard.get_global_rect().get_center()) and menu.scroll.get_v_scroll_bar().max_value <= menu.scroll.size.y + 2.0, "on a phone the Marks tab fits without scrolling")
	await _tap_at(tcard.get_global_rect().get_center())
	_check(menu.page == "mark" and menu.mark_part == "hand", "tapping a mark's card opens its page")
	await _tap_at(_menu_button("Back").get_global_rect().get_center())
	_check(menu.page == "climber", "...and tapping Back returns to the cards")
	menu.open("inventory", true)
	await _frames(3)
	_check(menu.scroll.get_v_scroll_bar().max_value <= menu.scroll.size.y + 2.0, "on a phone the inventory fits without scrolling (%d in %d)" % [menu.scroll.get_v_scroll_bar().max_value, menu.scroll.size.y])
	menu.close()
	await _frames(2)
	main.touch._set_active(false)
	p.touch_aim = false

	# The HUD size setting.
	menu.open("settings")
	await _frames(1)
	var sizes: Array = _all_buttons(menu).filter(func(b): return b.has_meta("choice") and b.get_meta("choice_key", "") == "hud_scale")
	_check(sizes.size() == 3, "Settings offers three HUD sizes")
	sizes[2].pressed.emit()
	await _frames(2)
	_check(menu.settings["hud_scale"] == "large" and is_equal_approx(main.hud.hud_scale, 1.2), "Large draws the HUD bigger")
	menu.close()
	await _frames(3)
	menu._set_setting("hud_scale", "small")
	_check(is_equal_approx(main.hud.hud_scale, 0.85), "...Small smaller")
	await _frames(2)
	menu._set_setting("hud_scale", "normal")
	_check(is_equal_approx(main.hud.hud_scale, 1.0), "...and Normal as it was")

	# The HUD: tooltips for the weapon in hand, the quick item and the marks;
	# the other items are in the inventory.
	p.add_item("tonic")
	p.add_item("draught")
	main.hud.core.queue_redraw()
	await _frames(2)
	var titles: Array = main.hud.tips.map(func(t): return t[1])
	var quick: String = p.selected_item()
	var other: String = "tonic" if quick != "tonic" else "draught"
	_check(p.weapon == "sword" and "Sword" in titles and main.Items.ITEMS[quick]["name"] in titles and titles.any(func(t): return t.begins_with("Stormcaller")), "the HUD's weapon, quick item and marks have tooltips")
	_check(not (main.Items.ITEMS[other]["name"] in titles), "...and only the quick item is on the HUD")
	menu.open("inventory", true)
	await _frames(2)
	var tonic = _slot("item:" + other)
	_check(tonic != null and tonic.count >= 1, "...the other items are in the inventory")
	menu.close()
	await _frames(2)

	# Gear at your feet shows in the inventory, set against yours, and can be taken.
	main.drop_gear(p.global_position, "axe")
	await physics_frame
	await physics_frame
	menu.open("inventory", true)
	await _frames(2)
	var fl = _slot("floor")
	_check(fl != null and fl.id == "axe", "gear at your feet has a slot in the inventory")
	fl.focus_entered.emit()
	await _frames(1)
	var take: Button = null
	for b in _all_buttons(menu):
		if b.text.begins_with("Take it"):
			take = b
	_check(take != null and texts.size() > 0, "...with Take it")
	if take != null:
		take.pressed.emit()
	await _frames(2)
	_check(p.gear_id("melee") == "axe" and menu.page == "inventory", "...which swaps it for your weapon")
	menu.close()
	main.gear_drops.clear()
	await _frames(2)


## Waits until the Entity's bubble shows (or a second passes).
func _until_bubble() -> void:
	for i in 120:
		if main.entity.showing() and main.entity.leaving <= 0.0:
			return
		await process_frame


## Waits until the Entity's bubble has gone.
func _until_no_bubble() -> void:
	for i in 120:
		if not main.entity.showing():
			return
		await process_frame


## The Entity: tips the first time each system is met (queued, once per
## save, off in Settings, replayed), dismissed by key, tap, click or the
## right stick; the Archive and the Record it presents; its pages.
func _entity_tests() -> void:
	print("the Entity: tips, the Archive and the Record")
	var Guide = load("res://scripts/guide.gd")
	var Entity = load("res://scripts/entity.gd")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	var p = main.player
	var menu = main.menu
	_check(not main.tip("glint") and Guide.queue.is_empty(), "tests keep the Entity quiet unless they ask")
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	_check(main.entity != null and main.entity.get_parent() == main.touch.get_parent(), "the Entity's bubble sits in the HUD layer, over the touch buttons")
	# Every tip has a name, a short line and a fuller account; groups exist; no stray words.
	var groups: Array = Entity.GROUPS.map(func(g): return g[0]) + ["forbidden"]  # (the Makers' tips: shown on their shelf once met)
	var bad: Array = []
	for id in Entity.TIPS:
		var e: Dictionary = Entity.TIPS[id]
		if not (e["group"] in groups) or String(e["tip"]).length() > 170 or String(e["more"]).length() < 60 or String(e["name"]) == "":
			bad.append(id)
		for w in ["attunement", "spire", "trial", "judgment", "mana"]:
			if (String(e["tip"]) + " " + String(e["more"])).to_lower().contains(w):
				bad.append(id + ":" + w)
	_check(bad.is_empty(), "every tip has a group, a short line and a fuller account (bad: %s)" % [bad])
	var need := ["move", "glint", "essence", "bank", "regard", "ward", "puzzle_eyes", "puzzle_plates", "traps", "trap_room", "hidden_trap",
		"doors", "door_locked", "fog", "camp", "gear", "heirloom", "items", "climber", "inventory", "chasm_fall", "beast", "death", "proving", "new_mark"]
	_check(need.all(func(id): return Entity.TIPS.has(id)), "tips cover every system the climber meets")
	_check(Entity.resolve("puzzle_mirrors") == "puzzle" and Entity.resolve("door_iron") == "door" and Entity.resolve("nonsense") == "", "a new kind falls back to its general tip")
	_check(Entity.fill_keys("{roll} or {parry}", "keys") == "Space or right click or K" and Entity.fill_keys("{roll}", "touch") == "Roll", "tips name the keys or buttons in use")
	var said: String = Entity.line("death", 0, {"floor": 4, "beast": "the Wyvern"})
	_check(not said.contains("{"), "a moment's line is filled in: %s" % said)

	# Registry: queued, one at a time, shown once.
	_check(main.tip("glint"), "a new system queues its tip")
	_check(not main.tip("glint"), "...only once while it waits")
	await _until_bubble()
	_check(main.entity.showing() and main.entity.current["id"] == "glint", "the Entity shows it in a bubble")
	_check(Guide.told("glint") and Guide.known("glint"), "...and the Archive entry unlocks")
	_check(main.entity.current["text"].contains("glint"), "the bubble says the tip")
	_check(main.entity.rect.position.x > main.get_viewport().get_visible_rect().size.x * 0.5 and main.entity.rect.position.y < 120.0, "the bubble sits top right")
	_check(not main.tip("glint"), "a tip already said isn't said again")
	_check(not Guide.known("essence"), "unmet systems stay locked in the Archive")
	main.tip("essence")
	main.tip("bank")
	await _frames(5)
	_check(main.entity.current["id"] == "glint" and Guide.queue.size() == 2, "other tips wait their turn (at most one bubble)")
	_check(not paused and p.is_physics_processing(), "a bubble never stops the game")
	# Dismiss with Enter (the dismiss_tip action).
	await _key_tap(KEY_ENTER)
	await _until_no_bubble()
	_check(not main.entity.showing(), "Enter dismisses the tip")
	await _until_bubble()
	_check(main.entity.current.get("id", "") == "essence", "...and the next one follows")
	# A click on the bubble.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _to_window(main.entity.rect.get_center())
	Input.parse_input_event(click)
	await _frames(2)
	var up: InputEventMouseButton = click.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _until_no_bubble()
	_check(not main.entity.showing(), "a click on the bubble dismisses it")
	_check(main.entity.ate_click() or Time.get_ticks_msec() - main.entity.ate_at < 1000, "...and the click is taken by the bubble, not the sword")
	# A tap on the bubble (a phone), clear of the touch buttons.
	main.touch._set_active(true)
	await _until_bubble()
	_check(main.entity.current.get("id", "") == "bank", "the third tip shows")
	await _wait(0.4)  # (once it has slid in)
	var r: Rect2 = main.entity.rect
	main.touch._layout()
	var covers := false
	for b in main.touch.buttons:
		if not (b["id"] in main.touch.TOP_BAR) and r.grow(4.0).intersects(Rect2(b["c"] - Vector2(b["r"], b["r"]), Vector2(b["r"], b["r"]) * 2.0)):
			covers = true
	_check(not covers and r.position.y > 50.0, "on a phone the bubble sits under the menu buttons, clear of the action buttons")
	var vs: Vector2 = main.entity.get_viewport_rect().size
	_check(r.end.x <= vs.x and r.position.x >= vs.x * 0.3, "...on the right, away from the joystick (%s in %s)" % [r, vs])
	await _tap_at(r.get_center())
	await _until_no_bubble()
	_check(not main.entity.showing() and main.touch.held.is_empty() and main.touch.stick_touch < 0, "a tap dismisses it (and the touch controls don't take it)")
	main.touch._set_active(false)
	# The right stick (RS / R3) on a controller.
	main.tip("items")
	await _until_bubble()
	await _pad_tap(JOY_BUTTON_RIGHT_STICK)
	await _until_no_bubble()
	_check(not main.entity.showing(), "pressing the right stick dismisses it")
	main.pad._set_active(false)
	# Left alone, it fades by itself.
	main.tip("inventory")
	await _until_bubble()
	main.entity.shown_t = main.entity.life
	await _until_no_bubble()
	_check(not main.entity.showing(), "a tip fades by itself after a few seconds")
	# Under a menu it waits.
	main.tip("camp")
	menu.open("pause")
	await _frames(10)
	_check(not main.entity.showing() and Guide.queue.size() == 1, "no bubble while a menu is open; the tip waits")
	menu.close()
	await _until_bubble()
	_check(main.entity.current.get("id", "") == "camp", "...and shows once the menu closes")
	main.entity.dismiss()
	await _until_no_bubble()

	# Off in Settings: quiet, but the Archive still fills in. Replay.
	Guide.set_on(false)
	_check(not main.tip("gas") and Guide.queue.is_empty(), "tips off: the Entity stays quiet")
	_check(Guide.known("gas") and not Guide.told("gas"), "...but the Archive entry still unlocks")
	Guide.say("death", {"floor": 3})
	await _frames(10)
	_check(not main.entity.showing(), "...and says nothing at moments either")
	Guide.set_on(true)
	Guide.replay()
	_check(not Guide.told("glint") and Guide.known("glint"), "replay: the tips are said again, the Archive keeps them")
	_check(main.tip("glint"), "...so a tip already met queues again")
	Guide.queue.clear()
	# Moments: the tip first, a short line after.
	Guide.moment("proving", "proving")
	_check(Guide.queue.size() == 1 and Guide.queue[0]["id"] == "proving", "a moment's first time is its tip")
	await _until_bubble()
	main.entity.dismiss()
	await _until_no_bubble()
	Guide.moment("proving", "proving")
	_check(Guide.queue.size() == 1 and Guide.queue[0]["kind"] == "say", "...and a short line after that")
	Guide.queue.clear()

	# Hooks in the game: greeting, essence, rooms, a fall.
	Guide.forget()
	main._greet()
	_check(Guide.queue.size() >= 2 and Guide.queue[0]["id"] == "entity" and Guide.queue[1]["id"] == "move", "a climb begins: the Entity introduces itself, then the first steps")
	main.gather_essence("water", 2.0, p.global_position)
	_check(Guide.queue.any(func(q): return q["id"] == "essence"), "gathering essence brings the essence tip")
	main.tip("puzzle_mirrors")
	_check(Guide.queue.any(func(q): return q["id"] == "puzzle"), "a puzzle kind without its own tip gets the general one")
	Guide.queue.clear()
	main.entity.current = {}

	# The record: counters the Entity keeps.
	var prof = main.profile
	var slain0: int = prof.count("slain")
	var foe = main.enemies()[0]
	_slay(foe)
	await _frames(2)
	_check(prof.count("slain") == slain0 + 1, "the record counts monsters slain")
	var floors0: int = prof.count("floors")
	main.grant_test_bonds()
	main._arrive()
	await _frames(2)
	_check(prof.count("floors") == floors0 + 1 and int(prof.record["best"].get(main.tower, 0)) == main.floor_num, "...floors climbed and the best floor of each tower")
	main.lift_ward()
	_check(prof.count("puzzles") >= 1, "...puzzles solved")
	main.dev_beast("gryphon")
	await _frames(2)
	Guide.queue.clear()
	_slay(main.enemies()[0])
	await _frames(2)
	_check(prof.count("beasts") == 1 and int(prof.record["beasts_by"].get("gryphon", 0)) == 1, "...beasts slain, by tower")
	_check(Guide.queue.any(func(q): return q["kind"] == "say" and q["key"] == "beast_slain"), "a beast slain: the Entity has a word")
	Guide.queue.clear()
	p.dead = false
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	var deaths0: int = prof.count("deaths")
	p.receive_attack(99999.0, null)
	_check(p.dead and prof.count("deaths") == deaths0 + 1, "...and falls")
	_check(Guide.queue.any(func(q): return q["id"] == "death"), "the first fall: the Entity's tip")
	Guide.queue.clear()
	main.entity.current = {}

	# The pages: the Archive, the Record and Settings, presented by the Entity.
	Guide.forget()
	for id in ["entity", "move", "glint", "ward"]:
		Guide.state["known"][id] = true
	menu.open("pause")
	await _frames(2)
	_check(_menu_button("Library") != null, "the pause menu has the Library")
	_menu_button("Library").pressed.emit()
	await _frames(2)
	_check(menu.page == "library", "...which opens the Archive beside the rail")
	var entries: Array = menu.focusables().filter(func(b): return b.has_meta("archive"))
	var locked: Array = menu.find_children("*", "Label", true, false).filter(func(l): return l.has_meta("archive_locked"))
	var hidden: int = Entity.TIPS.keys().filter(func(k): return Entity.TIPS[k]["group"] == "forbidden").size()
	var always: int = Entity.TIPS.keys().filter(func(k): return Entity.TIPS[k].get("always", false)).size()  # (the creator tools: readable before they're met)
	_check(entries.size() == 4 + always and locked.size() == Entity.TIPS.size() - hidden - 4 - always, "met entries are buttons, the rest ??? (%d, %d)" % [entries.size(), locked.size()])
	_check(menu.find_children("*", "", true, false).any(func(c): return c.get_meta("entity", "") == "archive"), "the Entity presents the Archive")
	entries[2].grab_focus()
	await _frames(1)
	await _key_tap(KEY_ENTER)
	await _frames(2)
	_check(menu.archive_open == "glint", "keys open an entry")
	var open_says: Array = menu.find_children("*", "", true, false).filter(func(c): return c.get_meta("archive_open", "") == "glint")
	_check(not open_says.is_empty() and open_says[0].get_meta("entity_line", "").contains("glint"), "...showing the Entity's tip and a fuller account")
	_check(menu.focusables().any(func(b): return b.has_meta("archive") and b.has_focus()), "...and the focus stays on the entries")
	var before = get_root().gui_get_focus_owner()
	await _key_tap(KEY_DOWN)
	var after = get_root().gui_get_focus_owner()
	_check(after != null and after != before and after in menu.focusables(), "the arrows move through the entries")
	menu.climber_tab = "record"
	menu.open("climber")
	await _frames(2)
	var texts: Array = _all_labels(menu).map(func(l): return l.text)
	_check(menu.find_children("*", "", true, false).any(func(c): return c.get_meta("entity", "") == "record"), "the Entity presents the Record")
	_check("Monsters slain" in texts and "Beasts slain" in texts and "Falls" in texts and "By Tower" in texts and "Kraken" in texts, "...with its counters and each tower's best floor")
	menu.open("settings")
	await _frames(2)
	_check(menu.find_children("*", "", true, false).any(func(c): return c.get_meta("entity", "") == "settings"), "the Entity presents Settings")
	var tog: Array = menu.focusables().filter(func(b): return b.get_meta("setting", "") == "tips")
	var sliders: Array = menu.focusables().filter(func(b): return b is HSlider)
	_check(tog.size() == 1 and _menu_button(Entity.TEXT["replay"]) != null and sliders.size() == 2 and _menu_button("Normal") != null, "Settings has the guide tips toggle and Replay (and keeps the rest)")
	tog[0].button_pressed = false
	await _frames(2)
	_check(not Guide.tips_on(), "...the toggle turns tips off")
	var tog2: Array = menu.focusables().filter(func(b): return b.get_meta("setting", "") == "tips")
	_check(tog2.size() == 1 and not tog2[0].button_pressed, "...and shows it")
	_menu_button(Entity.TEXT["replay"]).pressed.emit()
	await _frames(2)
	_check(Guide.tips_on() and Guide.state["told"].is_empty(), "Replay turns them back on and forgets what was said")
	_check(menu.find_children("*", "", true, false).any(func(c): return c.get_meta("entity_line", "") == Entity.line("replay")), "...and the Entity answers")
	menu.close()
	await _frames(2)
	Guide.forget()
	Engine.remove_meta("sixfold_tips")
	main.entity.current = {}


## Money (the owner's three fixes, and the recall scroll): a share of what's
## banked at a stair condenses into crystals (a setting); the outfitter pays
## for every climb, a fall too; Commons and basic supplies cost half; the
## recall scroll is always on the shelf and takes crystals of any kind.
func _economy_tests() -> void:
	print("money: condensing, the outfitter's pay, cheaper commons, the recall scroll")
	await _fresh_main()
	var T = main.Train
	var G = main.Gear
	var PS = main.ProfileScript
	var M = main.MenuScript
	var U = load("res://scripts/unbound.gd")
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	var setting0 = M.settings["condense"]
	main.grant_test_bonds()
	# Condensing at a stair: the set share, per kind; only the rest is banked.
	M.settings["condense"] = T.CONDENSE_DEFAULT
	var share: float = T.condense_share(M.settings)
	_check(is_equal_approx(share, 0.2), "condensing starts at 20%")
	prof.crystals = []
	var twin = PS.new()
	twin.saving = false
	twin.bonds = prof.bonds.duplicate(true)
	var dens0 := float(prof.density.get("water", 0.0))
	main.floor_num = 2
	main.run_essence = {"water": 50.0, "air": 7.0}
	main.run_soak = {}
	main._arrive()
	var cw := floorf(50.0 * share)
	var ca := floorf(7.0 * share)
	_check(prof.crystal_total("water") == cw and prof.crystal_total("air") == ca and prof.crystal_count("water") == 1, "a stair condenses %d%% of each kind into crystals (%s)" % [int(share * 100.0), prof.crystals])
	_check(is_equal_approx(float(prof.density.get("water", 0.0)) - dens0, 50.0 - cw), "...and banks only the rest")
	twin.bank({"water": 50.0 - cw, "air": 7.0 - ca}, {})
	_check(is_equal_approx(prof.bonds["hand"]["xp"], twin.bonds["hand"]["xp"]) and is_equal_approx(prof.bonds["legs"]["xp"], twin.bonds["legs"]["xp"]) and prof.bonds["legs"]["xp"] > 0.0, "marks grow from the banked part only")
	var want: String = T.TEXT["banked"] % int(57.0 - cw - ca) + "  ·  " + T.TEXT["condensed"] % int(cw + ca)
	_check(main.banner.get("lines", []).has(want), "the stair's banner says so: %s" % want)
	# The Unbound: the share is taken before essence pools raw in a part.
	var ub = PS.new()
	ub.saving = false
	U.become(ub)
	var cond: Dictionary = ub.condense({"blade": 40.0}, share)
	ub.bank(cond["keep"], {})
	var part: String = U.part_for(ub, "blade")
	_check(ub.crystal_total("blade") == floorf(40.0 * share) and is_equal_approx(float(ub.part_density.get(part, {}).get("blade", 0.0)), 40.0 - floorf(40.0 * share)), "the Unbound condense the same share; only the rest pools raw in the %s" % part)
	# The setting: on the Settings page, saved with the settings.
	menu.open("settings")
	await _frames(2)
	var row: Array = _all_buttons(menu).filter(func(b): return b.get_meta("choice_key", "") == "condense")
	_check(row.size() == T.CONDENSE_CHOICES.size(), "Settings has a row for the share (%d choices)" % row.size())
	var b35: Array = row.filter(func(b): return b.get_meta("choice", "") == "35")
	if b35.size() == 1:
		b35[0].pressed.emit()
		await _frames(2)
	_check(M.settings["condense"] == "35" and is_equal_approx(T.condense_share(M.settings), 0.35), "choosing 35% changes the share")
	menu.close()
	var path := "user://smoke_condense_test.cfg"
	M.save_settings_to(path)
	M.settings["condense"] = "20"
	M.load_settings_from(path)
	_check(M.settings["condense"] == "35", "...and it's saved with the settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	M.settings["condense"] = "0"
	prof.crystals = []
	main.player.set_physics_process(true)
	main.floor_num = 4
	main.run_essence = {"water": 30.0}
	main._arrive()
	_check(prof.crystals.is_empty(), "at 0% nothing condenses")
	M.settings["condense"] = T.CONDENSE_DEFAULT
	# The outfitter pays for a fall: per floor reached, more past your best.
	await _fresh_main()
	prof = main.profile
	p = main.player
	main.grant_test_bonds()
	main.tower = "kraken"
	main._note_climb_start()
	main.floor_num = 6
	prof.crystals = []
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	var first_pay: int = T.climb_pay(6, 0)
	_check(p.dead and prof.crystal_total("water") == float(first_pay) and first_pay == 6 * int(T.CLIMB_PAY["per_floor"]) + 6 * int(T.CLIMB_PAY["per_best"]), "a fall on floor 6 (a new best) still pays %d Water" % first_pay)
	_check(main.pay_line.contains(str(first_pay)) and main.pay_line.begins_with(T.TEXT["pay"].get_slice("%", 0)), "...said on the fall screen: %s" % main.pay_line)
	prof.note_floor("kraken", 6)
	main._note_climb_start()
	main.floor_num = 6
	_check(main.climb_best0 == 6 and main.pay_climb() != "" and int(prof.last_pay["amount"]) == T.climb_pay(6, 6) and T.climb_pay(6, 6) < first_pay, "the same floor again pays less (%d): a new best floor pays more" % T.climb_pay(6, 6))
	# A starting climber after one short fall can afford a Common piece or a supply in that tower's kind.
	for t in main.Towers.ORDER:
		var kind: String = main.Towers.TOWERS[t]["essence"]
		var cheapest := 9999
		for id in T.supplies():
			var pr: Array = T.item_price(id)
			if pr[0] == kind:
				cheapest = mini(cheapest, int(pr[1]))
		for id in T.common_pool():
			var g = G.make(id)
			if T.gear_kind(g) == kind:
				cheapest = mini(cheapest, T.gear_price(g))
		_check(T.climb_pay(3, 0) >= cheapest, "a first fall on floor 3 of the %s pays %d %s: enough for something at %d" % [t, T.climb_pay(3, 0), kind, cheapest])
	# The summit pays too.
	main.player.dead = false
	main.player.hp = main.player.max_hp
	main._note_climb_start()
	main.floor_num = int(main.tower_data().get("summit", 12))
	main.run_essence = {}
	main._arrive()
	await _frames(2)
	_check(not main.victory.is_empty() and main.pay_line != "" and main.victory["lines"].has(main.pay_line), "the summit is paid for: %s" % main.pay_line)
	main.victory = {}
	# The first climb's Regard pays too (money for the first train).
	await _fresh_main()
	prof = main.profile
	var fk: String = main.tower_data()["essence"]
	main.floor_num = PS.FIRST_CLIMB_FLOORS
	main.run_essence = {}
	main._arrive()
	await _frames(2)
	_check(not main.regard.is_empty() and prof.crystal_total(fk) >= T.climb_pay(PS.FIRST_CLIMB_FLOORS, 0) and main.pay_line != "", "the first climb's Regard is paid for: %s" % main.pay_line)
	main.regard = {}
	# Cheaper commons: about half; Fine stays at its old price (4x the new Common).
	var halves := true
	var fines := true
	for id in T.common_pool():
		var base := float(T.BASE_PRICE.get(G.make(id)["base"], T.DEFAULT_PRICE))
		var c: int = T.gear_price(G.make(id))
		halves = halves and absf(c - base * 0.5) <= 0.5
		var f: int = T.gear_price(G.make(id, "fine", []))
		fines = fines and f == int(round(base * 2.0)) and absf(f - 4.0 * c) <= 2.0
	_check(halves, "every Common piece costs half its old price")
	_check(fines, "a Fine piece keeps its old price: about 4x its Common")
	var basic := true
	for id in T.SUPPLY_PRICE:
		var worth := int(main.Items.ITEMS[id]["value"][main.Items.ITEMS[id]["kind"]])
		basic = basic and T.item_price(id)[1] == int(round(worth / 2.0)) and int(load("res://scripts/bench.gd").BREW[id].values()[0]) < T.item_price(id)[1]
	_check(basic, "basic supplies cost half their worth, and the bench brews them a little cheaper still")
	_check(T.item_price("vial")[1] == int(main.Items.ITEMS["vial"]["value"]["water"]), "rarer brews keep their price")
	# The recall scroll: always on the shelf, paid in crystals of any kind.
	prof.regarded = true
	main.first_climb = false
	prof.crystals = []
	prof.supplies = {}
	prof.supply_paid = {}
	p = main.player
	p.items = {"draught": 1}
	main.await_tower()
	main.open_train()
	menu = main.menu
	var price: Array = T.item_price("scroll")
	_check(price[0] == T.ANY and T.supplies().has("scroll") and T.price_text(price[0], price[1]) == "%d of any kind" % price[1], "the store always sells a recall scroll, for %s" % T.price_text(price[0], price[1]))
	prof.add_crystal("water", 35.0)
	prof.add_crystal("fire", 20.0)
	prof.add_crystal("air", 10.0)
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = "supply:scroll"
	menu.open("train")
	await _frames(2)
	var buy: Array = _car_buttons("buy", "scroll")
	_check(_car_buttons("slot", "supply:scroll").size() == 1 and buy.size() == 1 and not buy[0].disabled, "its shelf slot and Buy (no one kind covers %d, but together they do)" % price[1])
	if buy.size() == 1:
		buy[0].pressed.emit()
		await _frames(2)
	var paid: Dictionary = T.last_paid(prof, "scroll")
	var paid_sum := 0.0
	for k in paid:
		paid_sum += float(paid[k])
	_check(int(prof.supplies.get("scroll", 0)) == 1 and paid_sum == float(price[1]) and prof.crystals_held() == 65.0 - price[1], "bought with a mix of kinds: %s, %d in all" % [paid, int(paid_sum)])
	_check(paid.get("water", 0.0) == 35.0 and paid.get("fire", 0.0) == 20.0, "...the biggest crystals first")
	var labels: Array = _all_labels(menu).map(func(l): return l.text)
	_check(labels.any(func(t): return t.contains(T.TEXT["paid_with"] % T.paid_text(paid))), "...and the card says which it took")
	_check(_car_buttons("slot", "supply:scroll").size() == 1, "the scroll stays on the shelf after buying")
	prof.store = {}
	T.stock(prof)
	_check(T.supplies().has("scroll"), "...and after the rack is filled again")
	_check(T.put_back(prof, "scroll") and prof.crystal_total("water") == 35.0 and prof.crystal_total("fire") == 20.0 and prof.crystal_total("air") == 10.0, "putting it back returns the same mix")
	prof.crystals = []
	prof.add_crystal("water", 30.0)
	prof.add_crystal("fire", float(price[1]) - 31.0)
	_check(T.buy_supply(prof, p, "scroll") == T.TEXT["needs_any"] % 1 and prof.crystals_held() == float(price[1]) - 1.0 and not prof.supplies.has("scroll"), "one short in all: it can't be bought, and nothing is taken")
	menu.open("train")
	await _frames(2)
	buy = _car_buttons("buy", "scroll")
	_check(buy.size() == 1 and buy[0].disabled, "...its Buy is off")
	menu.close()
	M.settings["condense"] = setting0
	paused = false  # (the train's menu pauses the tree; the next test needs it running)


## The buttons and slots in the train's car you're in (the other cars are
## built too, so the next one shows while scrolling), with a meta.
func _car_buttons(meta: String, val) -> Array:
	var root = main.menu.train_page.roots.get(main.menu.train_car)
	if root == null:
		return []
	return _all_buttons(root).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


## Waits until the train has settled on the car you're in.
func _train_settled() -> void:
	var v = main.menu.train_view
	await _until(func(): return v.pos == float(v.target), 3.0)


## A finger drawn across the screen, from `a` to `b`, in a few moves
## (`slow`: seconds between them, for a slow drag rather than a flick).
func _swipe(a: Vector2, b: Vector2, slow := 0.0) -> void:
	_touch(0, a, true)
	await _frames(1)
	for i in 6:
		_drag(0, a.lerp(b, (i + 1) / 6.0))
		if slow > 0.0:
			await _wait(slow)
		else:
			await _frames(1)
	_touch(0, b, false)
	await _frames(2)


## The train between climbs (train.gd, train_page.gd, train_view.gd): the
## pack of spare pieces, the train opening after a climb on your own car,
## its rail down the left (the cars, then the pages), moving along it (the
## rail, keys, a swipe, the wheel), the store (buying
## with change, a price you can't pay, putting back, today's piece,
## selling), the chest and its save, the engine where you choose the tower
## and depart, and a fall after the Regard bringing you back to the train.
func _train_tests() -> void:
	print("the train")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	var T = main.Train
	var G = main.Gear
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	# Before the Regard, a new climb starts at the tower choice; no train.
	main.await_tower()
	_check(main.choosing_tower and not main.on_train, "before the Regard a climb starts at the tower choice, not the train")
	main.choosing_tower = false
	main.grant_test_bonds()
	p.set_physics_process(true)
	# The pack: 4 spare pieces; a swap puts your old piece in it.
	_check(p.pack_size() == 4 and p.pack.is_empty(), "the climber carries a pack of 4 spare pieces")
	main.drop_gear(p.global_position, G.make("axe"))
	main._update_gear_drops()
	_check(not main.gear_here.is_empty(), "standing on an axe with a sword in hand...")
	main.take_gear_here()
	_check(p.gear_id("melee") == "axe" and p.pack.size() == 1 and G.base_id(p.pack[0]) == "sword", "...taking it puts the old sword in your pack")
	p.take_gear(G.make("climbers_pack"))
	_check(p.pack_size() == 6, "a Climber's Pack holds two more")
	# The inventory's Pack view shows it; a pack piece can be worn again.
	menu.inv_view = "pack"
	menu.open("inventory")
	await _frames(2)
	_check(_slot("pack:0") != null and _slot("pack:0").id == "sword" and _slot("pack:5") != null, "the inventory shows the pack's spaces")
	menu._wear_pack(0, "")
	_check(p.gear_id("melee") == "sword" and G.base_id(p.pack[0]) == "axe", "wearing a pack piece swaps it with what you wore")
	menu.inv_view = "worn"
	menu.close()
	await _frames(2)
	# Reading a recall scroll brings the pack down to the train.
	main.read_recall()
	_check(prof.pack.size() == 1 and G.base_id(prof.pack[0]) == "axe" and p.pack.is_empty(), "leaving the tower brings the pack home")
	_check(main.victory.get("lines", []).any(func(l): return String(l).begins_with("Your pack comes down")), "...and the screen says so")
	main.victory = {}
	# (A new climb is a fresh scene: start gear and the starting draught.)
	p.gear = G.start_gear()
	p.refresh_gear()
	p.items = main.Items.START.duplicate()
	# After the Regard, the next climb waits on the train.
	main.await_tower()
	_check(main.on_train and main.choosing_tower, "after the Regard, a new climb waits on the train")
	main.open_train()
	await _frames(3)
	var view = menu.train_view
	_check(menu.page == "train" and view.visible and paused and not menu.center.visible, "the train fills the screen: its cars are the menu")
	_check(menu.train_car == "personal" and view.pos == 2.0, "it opens on your own car")
	var rail = menu.rail
	var R = load("res://scripts/rail.gd")
	var rail_ids: Array = rail.buttons.map(func(b): return b.id)
	_check(rail.visible and rail_ids.slice(0, 7) == ["climber", "engine", "store", "personal", "workshop", "library", "settings"], "the rail shows on the train: who you are, then the six cars front to back (%s)" % [rail_ids])
	_check(rail_ids.slice(7) == (["dev", "exit", "quit"] if menu.can_quit() else ["dev", "exit"]) and rail.button("resume") == null, "...then Dev Tools, Exit to Title Station and (on a computer) Quit game (%s)" % [rail_ids.slice(7)])
	_check(rail.current == "personal" and rail.button("personal").on, "...your car lit")
	_check(view.get_global_rect().position.x >= rail.size.x - 0.5 and absf(view.get_global_rect().end.x - menu.get_viewport_rect().size.x) < 1.0, "the cars fill the screen right of the rail")
	var top_things: Array = _all_buttons(view.chrome).filter(func(b): return b.has_meta("car") or b.has_meta("arrow") or b.has_meta("menu"))
	var top_bands: Array = view.chrome.get_children().filter(func(c): return c.get("at_top") == true)
	_check(top_things.is_empty() and top_bands.is_empty() and _menu_button("Menu") == null, "no strip of car names along the top, no edge arrows and no Menu button")
	_check(_car_buttons("slot", "heir:melee").size() == 1 and _car_buttons("slot", "chest:0").size() == 1, "your car holds the heirloom wardrobe and the chest")
	# ...and the climber screen and the inventory, which come back to your car.
	var car_pages: Array = _car_buttons("car_page", "climber") + _car_buttons("car_page", "inventory")
	_check(car_pages.size() == 2, "your car has buttons for the climber screen and the inventory")
	if car_pages.size() == 2:
		car_pages[1].pressed.emit()
		await _frames(2)
		var inv_ok: bool = menu.page == "inventory"
		menu.close()
		await _frames(2)
		var back_ok: bool = menu.page == "train" and menu.train_car == "personal"
		car_pages = _car_buttons("car_page", "climber")
		if not car_pages.is_empty():
			car_pages[0].pressed.emit()
			await _frames(2)
		var cl_ok: bool = menu.page == "climber"
		menu.close()
		await _frames(2)
		_check(inv_ok and cl_ok and back_ok and menu.page == "train" and menu.train_car == "personal", "...each opens its page, and closing it goes back to your car")
	_check(not prof.store.get("outfit", []).is_empty() and prof.store.get("today", "") != "", "the store has an outfit rack and today's piece")
	var today: Dictionary = T.today(prof)
	_check(G.rarity(today) in ["fine", "rare"], "today's piece is Fine or Rare (%s)" % G.display(today))
	# Keys: E the next car (the train slides there, the rail's light
	# follows), Q back; up and down on the rail move along it too.
	await _key_tap(KEY_E)
	_check(menu.train_car == "workshop", "E moves to the next car")
	await _train_settled()
	_check(view.pos == 3.0 and view.strip.position.x == -3.0 * view.size.x, "...and the train slides along to it")
	_check(rail.current == "workshop" and rail.button("workshop").on and not rail.button("personal").on, "...and the rail's light follows")
	await _key_tap(KEY_Q)
	_check(menu.train_car == "personal", "Q moves back")
	rail.focus_current()
	await _frames(1)
	await _key_tap(KEY_UP)
	await _key_tap(KEY_UP)
	_check(menu.train_car == "engine" and rail.button("engine").has_focus() and menu.page == "train", "Up on the rail moves onto the Outfitter's Car, then the engine, and the train slides there (the focus stays on the rail)")
	await _key_tap(KEY_UP)
	_check(menu.page == "climber" and rail.button("climber").has_focus(), "...Up again reaches who you are, and shows the climber screen beside the rail")
	await _key_tap(KEY_DOWN)
	_check(menu.page == "train" and menu.train_car == "engine" and rail.button("engine").has_focus(), "...and Down goes back onto the engine")
	rail.button("engine").grab_focus()
	await _frames(1)
	# Right goes into the car; Left at its edge comes back to the rail; Esc too.
	await _key_tap(KEY_RIGHT)
	var f = menu.get_viewport().gui_get_focus_owner()
	_check(menu.page == "train" and f != null and not rail.buttons.has(f) and menu.train_page._in_car(f), "Right on the rail goes into the car")
	for i in 6:
		await _key_tap(KEY_LEFT)
		if rail.has_focus_inside():
			break
	_check(rail.button("engine").has_focus() and menu.train_car == "engine", "...and Left from inside it comes back to the rail, on that car")
	await _key_tap(KEY_ENTER)
	f = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and menu.train_page._in_car(f), "Enter on the car you're in goes into it")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "train" and rail.button("engine").has_focus(), "Esc from inside a car comes back to the rail")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "train" and main.menu_open() and rail.button("engine").has_focus(), "...and Esc on the rail does nothing more (the train stays)")
	# A controller: RB / LB move along (the light and the focus follow on
	# the rail), A goes into the car, B comes back to the rail.
	await _pad_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(menu.train_car == "store" and rail.button("store").has_focus(), "RB moves to the next car, the rail's focus following")
	await _pad_tap(JOY_BUTTON_A)
	f = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and menu.train_page._in_car(f), "A on the rail goes into the car")
	await _pad_tap(JOY_BUTTON_B)
	_check(rail.button("store").has_focus() and menu.page == "train", "...and B comes back to the rail")
	await _pad_tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(menu.train_car == "engine" and rail.button("engine").has_focus(), "LB moves back")
	main.pad._set_active(false)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = _to_window(Vector2(view.size.x * 0.5, view.size.y - 20.0))
	Input.parse_input_event(wheel)
	await _frames(2)
	_check(menu.train_car == "store", "the mouse wheel moves along too")
	await _train_settled()
	# Choosing a car on the rail moves the train there.
	menu.nav_keys = false
	rail.button("workshop").pressed.emit()
	await _frames(2)
	_check(menu.train_car == "workshop" and view.target == 3 and rail.current == "workshop", "choosing a car on the rail moves the train there")
	await _train_settled()
	# Who you are opens the climber screen beside the same rail; Back returns to the car you were on.
	var rail_before = rail.buttons[0]
	rail.button("climber").pressed.emit()
	await _frames(2)
	_check(menu.page == "climber" and rail.visible and rail.buttons[0] == rail_before and rail.button("climber") == rail.ident and rail.current == "climber" and rail.at_car == "workshop", "who you are, at the top of the rail, opens the climber screen beside the same rail (not built again), the car you were on marked")
	_check(menu.panel.get_global_rect().position.x >= rail.size.x - 0.5, "...the page right of the rail")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "train" and menu.train_car == "workshop" and rail.buttons[0] == rail_before and rail.current == "workshop", "...and Esc returns to the car you were on")
	rail.button("dev").pressed.emit()
	await _frames(2)
	_check(menu.page == "dev" and rail.current == "dev" and rail.at_car == "workshop", "Dev Tools opens beside the rail too")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "workshop", "...and Back returns to the car")
	rail.button("climber").pressed.emit()
	await _frames(2)
	menu.nav_keys = false
	rail.button("store").pressed.emit()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "store", "choosing a car from a page goes back to the train, on that car")
	rail.button("engine").grab_focus()
	await _frames(1)
	await _key_tap(KEY_DOWN)
	_check(menu.page == "train" and menu.train_car == "store" and rail.button("store").has_focus(), "moving down the rail onto a car slides there")
	rail.button("engine").grab_focus()
	await _frames(1)
	await _key_tap(KEY_UP)
	_check(menu.page == "climber" and rail.button("climber").has_focus() and rail.at_car == "engine", "...and up onto who you are shows the climber screen (the focus stays on the rail)")
	await _key_tap(KEY_ESCAPE)
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "engine" and rail.button("climber").has_focus(), "...and Esc there returns to the car, the focus back on who you are")
	var gone: Array = ["inventory", "archive", "controls", "over", "resume"].filter(func(id): return rail.button(id) != null)
	_check(gone.is_empty() and rail.button("settings") != null and R.is_car("settings") and R.is_car("library"), "the train's rail has no separate Inventory, Archive, Controls or Start over: Library and Settings & Controls are cars (%s)" % [gone])
	menu.toggle("inventory")
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "personal", "I on the train opens your car")

	# Crystals of a kind combine into one; buying takes from it.
	prof.crystals = []
	prof.add_crystal("stone", 5.0)
	prof.add_crystal("stone", 10.0)
	prof.add_crystal("stone", 40.0)
	_check(prof.crystal_count("stone") == 1 and prof.crystal_total("stone") == 55.0, "same-kind crystals combine into one crystal (%s)" % [prof.crystals])
	var dprice: int = T.item_price("draught")[1]
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = "supply:draught"
	menu.open("train")
	await _frames(2)
	_check(_car_buttons("slot", "outfit:0").size() == 1 and _car_buttons("slot", "today").size() == 1, "the store car: the outfitter's shelves, the outfit rail and today's piece")
	var buy: Array = _car_buttons("buy", "draught")
	_check(buy.size() == 1 and not buy[0].disabled, "a Healing Draught can be bought")
	if buy.size() == 1:
		buy[0].pressed.emit()
		await _frames(2)
	_check(int(prof.supplies.get("draught", 0)) == 1, "buying packs it for the next climb")
	_check(prof.crystal_total("stone") == 55.0 - dprice and prof.crystal_count("stone") == 1, "%d Stone paid from your Stone crystal (%s)" % [dprice, prof.crystals])
	var labels: Array = _all_labels(menu).map(func(l): return l.text)
	_check(labels.any(func(t): return t.begins_with("Bought: Healing Draught")), "...and the card says so")
	# A price you can't pay says why.
	menu.inv_sel = "supply:vial"
	menu.open("train")
	await _frames(2)
	labels = _all_labels(menu).map(func(l): return l.text)
	buy = _car_buttons("buy", "vial")
	_check(buy.size() == 1 and buy[0].disabled and labels.any(func(t): return t.contains("needs 20 more Water")), "a price you can't pay says why: needs 20 more Water")
	_check(T.buy_supply(prof, p, "vial") == "needs 20 more Water" and not prof.supplies.has("vial"), "...and buying it does nothing")
	# The belt's room: the starting draught plus what's packed, up to 3.
	_check(T.supply_room(prof, p, "draught") == 1, "the belt holds 3 draughts: 1 to start, 1 packed, room for 1")
	_check(T.put_back(prof, "draught") and prof.crystal_total("stone") == 55.0 and not prof.supplies.has("draught"), "putting it back returns the full price")
	# Today's piece goes in your pack.
	var kind: String = T.gear_kind(today)
	var cost: int = T.gear_price(today)
	prof.add_crystal(kind, float(cost))
	var before: float = prof.crystal_total(kind)
	prof.pack = []
	_check(T.buy_gear(prof, p, -1) == "", "today's piece can be bought")
	_check(prof.pack.size() == 1 and G.same(prof.pack[0], today) and prof.crystal_total(kind) == before - cost and T.today(prof).is_empty(), "...into your pack, for its price (%d %s)" % [cost, kind])
	# Selling: a crystal of its kind at 40% of its price (asks once first).
	prof.pack = [G.make("leather_cap"), G.make("iron_helm", "rare", ["vigor", "calm"])]
	var cap_sell := maxi(1, int(round(round(float(T.BASE_PRICE["leather_cap"]) * T.RARITY_PRICE["common"]) * T.SELL_SHARE)))
	_check(T.gear_kind(prof.pack[0]) == "stone" and T.gear_sell(prof.pack[0]) == cap_sell, "a Leather Cap sells for %d Stone" % cap_sell)
	_check(T.gear_kind(prof.pack[1]) == "stone" and T.gear_price(prof.pack[1]) == 56 and T.gear_sell(prof.pack[1]) == 22, "a Rare Iron Helm of Vigor: 56 Stone, sells for 22")
	var sign: Array = _car_buttons("store_tab", "sell")
	_check(sign.size() == 1, "the outfitter's sign: sell to him")
	if sign.size() == 1:
		sign[0].pressed.emit()
		await _frames(2)
	_check(menu.train_store == "sell", "...shows what you brought down")
	menu.inv_sel = "pack:0"
	menu.open("train")
	await _frames(2)
	var stone: float = prof.crystal_total("stone")
	var sell: Array = _car_buttons("sell", "pack:0")
	if sell.size() == 1:
		sell[0].pressed.emit()
		await _frames(2)
	_check(prof.pack.size() == 2, "the first press on Sell only asks")
	sell = _car_buttons("sell", "pack:0")
	if sell.size() == 1:
		sell[0].pressed.emit()
		await _frames(2)
	_check(prof.pack.size() == 1 and prof.crystal_total("stone") == stone + cap_sell, "the second sells it: %d Stone into your crystal" % cap_sell)
	menu.train_store = "shop"
	# The chest: keep a piece; it's saved with the profile (old saves load without one).
	_check(T.move(prof, p, "pack", 0) == "" and prof.chest.size() == 1 and prof.pack.is_empty(), "a piece moves from your pack to the chest")
	prof.supplies = {"tonic": 2}
	var path := "user://smoke_train_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.chest.size() == 1 and G.same(again.chest[0], prof.chest[0]) and int(again.supplies.get("tonic", 0)) == 2 and again.store.has("outfit"), "the chest, supplies and stock are saved and load again")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.regarded and again.chest.is_empty() and again.pack.is_empty() and again.supplies.is_empty() and again.store.is_empty(), "an old save loads with an empty chest")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	_check(T.move(prof, p, "chest", 0) == "" and prof.pack.size() == 1, "...and back into your pack")
	# A phone: big enough to touch; swipe along; tap the engine, a tower, the lever.
	# (A phone-shaped screen, landscape: the headless window is square, where
	# the cars shrink to fit and every size depends on the font.)
	var was_size: Vector2i = root.size
	root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	await _frames(2)
	menu.train_car = "personal"
	menu.open("train")
	await _frames(3)
	var small: Array = _all_buttons(view).filter(func(b): return b.is_visible_in_tree() and b.get_global_rect().size.y < 35.9)
	_check(small.is_empty(), "on a phone every button on the train is at least 36 tall (54 px): %s" % [small.map(func(b): return b.text)])
	var sel0: String = menu.inv_sel
	var mid: float = view.size.y * 0.5
	# It fits a phone: the narrow rail, every car and page and its foot on
	# screen, the cars in the rest, and everything in a car inside it.
	var vis: Rect2 = menu.get_viewport_rect()
	var off_rail: Array = rail.buttons.filter(func(b): return not vis.encloses(b.get_global_rect().grow(-0.5)) or b.get_global_rect().size.y < R.ROW_MIN[0] - 0.5)
	_check(rail.narrow and off_rail.is_empty() and rail.buttons.size() == 1 + 6 + R.TRAIN_PAGES.size() + R.TRAIN_FOOT.size() + (1 if menu.can_quit() else 0), "on a phone (800 x 400) the narrow rail fits who you are, its six cars, Dev Tools and its foot: %s" % [off_rail.map(func(b): return b.id)])
	_check(rail.size.x <= vis.size.x * 0.16 and absf(view.get_global_rect().position.x - rail.size.x) < 1.0, "...and the cars fill the rest (%.0f of %.0f)" % [rail.size.x, vis.size.x])
	var outside: Array = []
	for car in ["engine", "store", "personal", "workshop", "library", "settings"]:
		menu.train_page.go_to(menu.train_page._index(car))
		await _train_settled()
		await _frames(2)
		var vr: Rect2 = view.get_global_rect()
		for b in _all_buttons(menu.train_page.roots[car]):
			if b.is_visible_in_tree() and not vr.grow(0.5).encloses(b.get_global_rect()) and menu.train_page._scroll_of(b) == null:
				outside.append("%s %s" % [car, b.text])
	_check(outside.is_empty(), "...and every car's furniture and placard stay inside the car view: %s" % [outside])
	menu.train_page.go_to(menu.train_page._index("personal"))
	await _train_settled()
	# Mid-swipe, the rail's light is on the car nearest the middle.
	_touch(0, Vector2(view.global_position.x + view.size.x * 0.9, mid), true)
	await _frames(1)
	for i in 8:
		_drag(0, Vector2(view.global_position.x + view.size.x * (0.9 - 0.09 * (i + 1)), mid))
		await _frames(1)
	var mid_light: String = rail.current
	var mid_car: String = menu.train_car
	_touch(0, Vector2(view.global_position.x + view.size.x * 0.18, mid), false)
	await _frames(2)
	_check(mid_light == "workshop" and mid_car == "personal", "mid-swipe the rail's light moves to the car coming into view (%s, still in %s)" % [mid_light, mid_car])
	await _train_settled()
	menu.train_page.go_to(menu.train_page._index("personal"))
	await _train_settled()
	await _swipe(Vector2(view.size.x * 0.62, mid), Vector2(view.size.x * 0.3, mid))
	_check(menu.train_car == "workshop" and view.target == 3, "a swipe to the left goes to the next car")
	_check(rail.current == "workshop" and rail.button("workshop").on and not rail.button("personal").on, "...and the rail's light follows it")
	_check(menu.train_sel.get("personal", "") == sel0, "...and doesn't press what it began on")
	await _train_settled()
	await _swipe(Vector2(view.size.x * 0.4, mid), Vector2(view.size.x * 0.52, mid), 0.05)
	await _train_settled()
	_check(menu.train_car == "workshop" and view.pos == 3.0, "a short one settles back on the same car")
	await _swipe(Vector2(view.size.x * 0.3, mid), Vector2(view.size.x * 0.62, mid))
	_check(menu.train_car == "personal", "a swipe to the right goes back")
	await _tap_at(rail.button("engine").get_global_rect().get_center())
	_check(menu.train_car == "engine", "tapping the engine on the rail goes there")
	await _train_settled()
	prof.supplies = {"tonic": 1}
	p.gear = G.start_gear()
	p.refresh_gear()
	prof.pack = [G.make("leather_cap"), G.make("dagger"), G.make("chain")]
	menu.open("train")
	await _frames(2)
	var cards: Array = _car_buttons("tower", "wyvern")
	_check(cards.size() == 1 and _all_buttons(menu.train_page.roots["engine"]).filter(func(b): return b.has_meta("tower")).size() == 6, "the engine's board: a plaque for each tower")
	if cards.size() == 1:
		await _tap_at(cards[0].get_global_rect().get_center())
	_check(menu.train_tower == "wyvern" and main.on_train, "tapping a plaque chooses that tower (still on the train)")
	var lever: Array = _car_buttons("depart", "wyvern")
	_check(lever.size() == 1, "...and the lever departs for it")
	if lever.size() == 1:
		await _tap_at(lever[0].get_global_rect().get_center())
	_check(not main.on_train and not main.choosing_tower and main.tower == "wyvern" and not menu.is_open(), "pulling the lever departs for the chosen tower")
	_check(p.gear_id("helm") == "leather_cap" and p.gear_id("melee") == "dagger" and p.gear_id("armor") == "chain", "pieces in your pack go on as you enter (the dagger in place of the starting sword)")
	_check(p.item_count("tonic") == 1 and prof.pack.is_empty() and prof.supplies.is_empty() and prof.store.is_empty(), "supplies go on your belt; the store restocks next visit")
	main.touch._set_active(false)
	root.size = was_size
	# A fall after the Regard: the fall screen for a moment, then back on the
	# train, on your own car (a confirm key goes at once; alone, it waits).
	menu.train_car = "engine"
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	await _frames(2)
	_check(p.dead and main.fallen() and not main.on_train, "after the Regard a fall shows the fall screen first")
	await _key_tap(KEY_ENTER)
	_check(not main.on_train, "...a press in its first moment doesn't skip it (%.2f s)" % main.fall_t)
	await _until(func(): return main.fall_t >= main.FALL_GRACE, 3.0)
	await _key_tap(KEY_ENTER)
	await _until(func(): return main.on_train, 2.0)
	_check(main.on_train and menu.page == "train" and menu.train_car == "personal", "...then Enter goes back to the train, on your own car")
	main.depart("kraken")
	await _frames(2)
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(99999.0, null)
	await _frames(2)
	main.fall_t = main.FALL_WAIT - 0.1
	await _until(func(): return main.on_train, 3.0)
	_check(main.on_train and menu.page == "train", "...and on its own after %d seconds" % int(main.FALL_WAIT))
	main.depart("kraken")
	await _frames(2)
	# The first climb's fall leads to the Regard, never the train.
	await _fresh_main()
	main.player.receive_attack(99999.0, null)
	await _frames(5)
	_check(main.player.dead and not main.fallen() and not main.on_train and main.regard_pending, "a fall on the bondless first climb goes to the Regard, not the train")


## Falling (lost.gd): the pack and belt are lost and remembered, the weapon
## in hand by chance, never an heirloom; a later floor of the tower may hold
## a lost cache that gives them back; the lost list is saved.
func _lost_tests() -> void:
	print("falling and lost things")
	await _fresh_main()
	var G = main.Gear
	var L = main.Lost
	var Entity = load("res://scripts/entity.gd")
	var prof = main.profile
	var p = main.player
	main.grant_test_bonds()
	main.tower = "kraken"
	main.floor_num = 5
	var crystals0: float = _purse(prof)
	main.climb_best0 = 3
	main.climb_paid = false
	p.pack = [G.make("leather_cap"), G.make("dagger"), G.make("chain")]
	p.take_gear(G.make_named("coral_trident"))
	_check(p.weapon == "spear" and not p.carried().is_empty(), "a Coral Trident in hand, three pieces in the pack, items on the belt")
	main.weapon_loss_chance = 1.0  # (force the weapon's chance)
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	_check(p.dead and prof.lost.size() == 4, "a fall loses the pack's three pieces and the weapon in hand (%d remembered)" % prof.lost.size())
	_check(prof.lost.all(func(e): return e["tower"] == "kraken" and int(e["floor"]) == 5), "...remembered with the tower and floor where they fell")
	_check(G.named_id(prof.lost[3]["rec"]) == "coral_trident", "...the weapon among them")
	var fall_pay: int = main.Train.climb_pay(5, 3)
	_check(fall_pay == 2 * 5 + 3 * 2 or main.Train.CLIMB_PAY != {"per_floor": 2, "per_best": 3}, "(the pay: %d for floor 5, 2 floors past a best of 3)" % fall_pay)
	_check(is_equal_approx(_purse(prof), crystals0 + fall_pay) and is_equal_approx(prof.crystal_total("water"), float(fall_pay)), "the belt is lost, not broken into crystals; the outfitter pays %d Water for the climb" % fall_pay)
	_check(main.pay_line == main.Train.TEXT["pay"] % main.Train.price_text("water", fall_pay) and prof.last_pay.get("amount", 0.0) == float(fall_pay), "...said on the fall screen: %s" % main.pay_line)
	var note: String = main.fall_note[0] if not main.fall_note.is_empty() else ""
	_check(note == "Lost on the way down: your pack (3 pieces), your belt, your Coral Trident", "the fall screen says what was lost: %s" % note)
	_check(Entity.TIPS.has("fall_loss") and Entity.TIPS.has("lost_cache"), "the Entity has tips for a fall's losses and a lost cache")
	# Without the chance, the weapon stays; an heirloom in hand is never lost.
	p.dead = false
	p.hp = p.max_hp
	p.pack = []
	p.take_gear(G.make("mace"))
	main.weapon_loss_chance = 0.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(99999.0, null)
	_check(p.dead and prof.lost.size() == 4 and main.fall_note[0] == "Lost on the way down: your belt", "without the chance the weapon isn't lost (%s)" % [main.fall_note])
	p.dead = false
	p.hp = p.max_hp
	prof.heirlooms["melee"] = G.make("greatsword")
	p.use_heirlooms(prof.heirlooms)
	main.weapon_loss_chance = 1.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(99999.0, null)
	_check(p.dead and p.weapon == "greatsword" and prof.lost.size() == 4 and G.base_id(prof.heirlooms.get("melee", {})) == "greatsword", "an heirloom in hand is never lost")
	# Only the last KEEP pieces are remembered.
	L.remember(prof, [G.make("axe"), G.make("plate"), G.make("longbow")], "gryphon", 9)
	_check(prof.lost.size() == L.KEEP and prof.lost[0]["rec"]["base"] == "dagger", "only the last %d lost pieces are remembered" % L.KEEP)
	L.remember(prof, [G.make("leather_cap")], "kraken", 5)
	# A later climb of the tower: a floor near where they fell holds a lost cache.
	p.dead = false
	p.hp = p.max_hp
	p.set_physics_process(true)
	p.pack = []
	main.lost_cache_chance = 1.0
	main._start_floor(4)
	await _clear_foes()
	var lc: Dictionary = main.lost_cache
	_check(not lc.is_empty() and lc["entries"].size() == 3, "a floor near where things fell holds a lost cache (of up to 3 pieces)")
	if lc.is_empty():
		return
	var room := -1
	for i in main.room_info.size():
		if main.room_info[i]["rect"].has_point(lc["pos"]):
			room = i
	var feature: String = main.Themes.get_theme(main.floor_plan["themes"][room])["feature"] if room >= 0 else "?"
	_check(room >= 0 and main.room_info[room]["role"] != "gallery" and feature in L.ROOM_FEATURES + L.FALLBACK_FEATURES, "...in an ordinary room (%s)" % feature)
	_check(main.traps.all(func(tr): return tr["pos"].distance_to(lc["pos"]) > 50.0), "...with no trap on it")
	_check(main.room_view.lost_cache == lc, "...drawn in the room")
	var lost0: int = prof.lost.size()
	p.global_position = lc["pos"] + Vector2(0, 70)
	p.reset_physics_interpolation()
	main.cam_prev = p.global_position
	main.cam_curr = p.global_position
	await _until(func(): return main.lighting.live_lights().any(func(l): return l[0].distance_to(lc["pos"]) < 1.0), 2.0)
	_check(main.lighting.live_lights().any(func(l): return l[0].distance_to(lc["pos"]) < 1.0), "...and faintly lit")
	p.global_position = lc["pos"]
	await _until(func(): return lc["taken"], 3.0)
	_check(lc["taken"] and p.pack.size() == 3, "walking onto it puts the pieces back in your pack (%d)" % p.pack.size())
	_check(prof.lost.size() == lost0 - 3, "...and they're no longer lost (%d left)" % prof.lost.size())
	_check(p.pack.any(func(g): return G.named_id(g) == "coral_trident"), "...the Coral Trident among them")
	# With a full pack, what doesn't fit is left at your feet.
	p.pack = []
	for i in p.pack_size():
		p.pack.append(G.make("padded"))
	prof.lost = []
	L.remember(prof, [G.make("war_hammer")], "kraken", 4)
	main._start_floor(4)
	await _clear_foes()
	lc = main.lost_cache
	if not lc.is_empty():
		main._open_lost_cache()
	_check(not lc.is_empty() and main.gear_drops.any(func(d): return d["id"] == "war_hammer") and prof.lost.is_empty(), "with a full pack, a found piece is left at your feet")
	# Another tower's lost things never turn up here.
	L.remember(prof, [G.make("axe")], "wyvern", 4)
	main._start_floor(4)
	_check(main.lost_cache.is_empty(), "lost things only turn up in the tower where they fell")
	# Saved with the profile; old saves load with nothing lost.
	var path := "user://smoke_lost_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.lost.size() == 1 and G.base_id(again.lost[0]["rec"]) == "axe" and again.lost[0]["tower"] == "wyvern" and int(again.lost[0]["floor"]) == 4, "the lost list is saved and loads again")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.regarded and again.lost.is_empty(), "an old save loads with nothing lost")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	main.lost_cache_chance = 0.0


## The bench in the workshop car (bench.gd): anyone brews (packed for the
## next climb, deducted as the store pays); only a Rune Artist tempers,
## retraits, joins, inscribes and binds a recall scroll (carry 1); breaking
## down gives a crystal; the new fields save and load.
func _bench_tests() -> void:
	print("the bench")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var B = load("res://scripts/bench.gd")
	var T = main.Train
	var G = main.Gear
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	prof.crystals = []
	prof.pack = []
	prof.chest = []
	prof.heirlooms = {}
	prof.supplies = {}
	prof.supply_paid = {}
	main.await_tower()
	main.open_train()
	menu.train_car = "workshop"
	var bench_buttons := func(meta: String, val) -> Array:
		return _all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.has_meta(meta) and b.get_meta(meta) == val)
	# Brewing: anyone can. It costs a little less than the store, is paid in
	# crystals (change back as one) and is packed for the next climb.
	prof.add_crystal("stone", 25.0)
	menu.train_bench = "brew"
	menu.inv_sel = "bench:item:draught"
	menu.open("train")
	await _frames(2)
	var tabs: Array = _all_buttons(menu).filter(func(b): return b.get_meta("bench_tab", "") != "")
	_check(tabs.map(func(b): return b.get_meta("bench_tab")) == ["brew", "temper", "retrait", "join", "break", "inscribe", "recall", "vessel"], "the bench's counters: brew, temper, retrait, join, break down, inscribe, recall scroll, vessel")
	var brew: Array = bench_buttons.call("brew", "draught")
	_check(brew.size() == 1 and not brew[0].disabled, "anyone can brew a Healing Draught")
	if brew.size() == 1:
		brew[0].pressed.emit()
		await _frames(2)
	var brew_d: int = int(B.BREW["draught"]["stone"])
	_check(brew_d < int(T.item_price("draught")[1]) and int(prof.supplies.get("draught", 0)) == 1 and prof.crystal_total("stone") == 25.0 - brew_d and prof.crystal_count("stone") == 1, "brewing it costs %d Stone, less than the store, and packs it (%s)" % [brew_d, prof.crystals])
	_check(T.put_back(prof, "draught") and prof.crystal_total("stone") == 25.0 and not prof.supplies.has("draught"), "putting it back returns what was paid")
	# Not a Rune Artist: tempering is greyed, and says why.
	prof.heirlooms["melee"] = G.make("spear", "fine", ["edges"])
	prof.add_crystal("blade", 200.0)
	menu.train_bench = "temper"
	menu.inv_sel = "bench:heir:melee"
	menu.open("train")
	await _frames(2)
	var tab: Array = bench_buttons.call("bench_tab", "temper")
	var labels: Array = _all_labels(menu).map(func(l): return l.text)
	var temper: Array = bench_buttons.call("bench_do", "temper")
	_check(tab.size() == 1 and tab[0].has_meta("greyed") and temper.size() == 1 and temper[0].disabled, "without the Rune Artist's mark, Temper is greyed and its button off")
	_check(labels.any(func(t): return t.begins_with("Only a Rune Artist can temper")), "...and the card says a Rune Artist could do it")
	_check(B.temper(prof, "heir:melee").contains("Rune Artist") and int(B.piece(prof, "heir:melee")["rank"]) == 0 and prof.crystal_total("blade") == 200.0, "...and tempering does nothing")
	# A Rune Artist tempers: asks once, then the rank and its numbers go up.
	prof.add_bond("brow", "rune_artist", false)
	var strike0: float = G.effects(prof.heirlooms["melee"])["strike"]
	var power0: float = G.weapon_power(prof.heirlooms["melee"])
	menu.open("train")
	await _frames(2)
	temper = bench_buttons.call("bench_do", "temper")
	_check(temper.size() == 1 and not temper[0].disabled and not bench_buttons.call("bench_tab", "temper")[0].has_meta("greyed"), "a Rune Artist can temper")
	if temper.size() == 1:
		temper[0].pressed.emit()
		await _frames(2)
	_check(int(B.piece(prof, "heir:melee")["rank"]) == 0, "the first press only asks")
	temper = bench_buttons.call("bench_do", "temper")
	if temper.size() == 1:
		temper[0].pressed.emit()
		await _frames(2)
	var spear: Dictionary = prof.heirlooms["melee"]
	_check(int(spear["rank"]) == 1 and prof.crystal_total("blade") == 180.0 and G.display(spear).ends_with("+1"), "the second tempers it to +1 for 20 Blade (%s)" % G.display(spear))
	_check(is_equal_approx(G.effects(spear)["strike"], strike0 * 1.25) and is_equal_approx(G.weapon_power(spear), power0 * 1.04), "+1: its trait 25% stronger, the spear 4% harder")
	_check(B.temper(prof, "heir:melee").contains("density"), "+2 needs Blade density settled in you")
	prof.density["blade"] = 100.0
	_check(B.temper(prof, "heir:melee") == "" and int(prof.heirlooms["melee"]["rank"]) == 2 and prof.crystal_total("blade") == 135.0, "with 100 density, +2 costs 45 Blade")
	# Retrait: the crystal paid chooses the new trait's essence.
	prof.chest = [G.make("iron_helm", "rare", ["vigor", "calm"])]
	prof.add_crystal("fire", 30.0)
	_check(B.retrait(prof, "chest:0", 0, "blade") != "", "no Blade trait fits a helm: nothing to swap to")
	_check(B.retrait(prof, "chest:0", 0, "fire") == "", "a Rune Artist retraits the helm's first trait with Fire")
	var helm: Dictionary = B.piece(prof, "chest:0")
	_check(G.TRAITS[helm["traits"][0]]["kind"] == "fire" and helm["traits"][1] == "calm" and prof.crystal_total("fire") == 0.0, "...a Fire trait in place of Vigor, Calm kept, 30 Fire paid on a Rare (%s)" % [helm["traits"]])
	# Join: two Fine gloves become one Rare with a trait from each.
	prof.pack = [G.make("leather_gloves", "fine", ["edges"]), G.make("grip_wraps", "fine", ["riposte"])]
	_check(B.partners(prof, "pack:0") == ["pack:1"], "Fine gloves can be joined with other Fine gloves")
	_check(B.join(prof, "pack:0", "pack:1") == "" and prof.pack.size() == 1, "joining them leaves one piece")
	var j: Dictionary = prof.pack[0]
	_check(j["rarity"] == "rare" and j["traits"] == ["edges", "riposte"] and G.base_id(j) == "leather_gloves" and prof.crystal_total("blade") == 105.0, "...a Rare pair with Edges and Riposte, for 30 Blade (%s)" % G.display(j))
	_check(not G.wears(j) and not G.wears(spear), "pieces with traits never wear")
	# Break down: a crystal of its kind, as the store's Sell gives.
	prof.pack.append(G.make("axe"))
	var axe_v: int = T.gear_sell(G.make("axe"))
	_check(B.break_down(prof, "pack:1") == "%d Blade" % axe_v and prof.crystal_total("blade") == 105.0 + axe_v and prof.pack.size() == 1, "breaking down an axe gives %d Blade, as the store's Sell" % axe_v)
	T.pack_supply(prof, "tonic", {"water": 8})
	var tonic_v := maxi(1, int(round(float(T.item_price("tonic")[1]) * T.SELL_SHARE)))
	_check(B.break_down(prof, "supply:tonic") == "%d Water" % tonic_v and prof.crystal_total("water") == float(tonic_v) and not prof.supplies.has("tonic"), "a packed tonic breaks into %d Water" % tonic_v)
	# Inscribe: a lasting rune, its effect in the gear's numbers and drawn on its icon.
	prof.add_crystal("iron", 25.0)
	var strike2: float = G.effects(prof.heirlooms["melee"])["strike"]
	_check(B.inscribe(prof, "heir:melee", "sharpness") == "" and prof.crystal_total("iron") == 0.0, "a Rune Artist inscribes a lasting Rune of Sharpness for 25 Iron")
	_check(is_equal_approx(G.effects(prof.heirlooms["melee"])["strike"], strike2 + 0.1), "...strikes 10% harder from that piece")
	_check(G.rune_strokes("sharpness") == G.rune_strokes("sharpness") and G.rune_strokes("sharpness").size() >= 3 and G.rune_strokes("sharpness") != G.rune_strokes("warding"), "a rune's strokes are hashed from its id")
	# The recall scroll: only a Rune Artist binds one, and you carry one.
	prof.add_crystal("air", 60.0)
	prof.add_crystal("water", 60.0 - prof.crystal_total("water"))
	var ra: Dictionary = prof.bonds["brow"]
	prof.bonds.erase("brow")
	_check(B.brew(prof, p, "scroll").contains("Rune Artist") and not prof.supplies.has("scroll"), "only a Rune Artist can bind a recall scroll")
	prof.bonds["brow"] = ra
	_check(B.brew(prof, p, "scroll") == "" and int(prof.supplies["scroll"]) == 1 and prof.crystal_total("air") == 30.0 and prof.crystal_total("water") == 30.0, "a Rune Artist binds one for 30 Air and 30 Water")
	_check(B.brew(prof, p, "scroll") != "" and int(prof.supplies["scroll"]) == 1, "...and carries only one")
	# A phone: every counter and card button big enough to touch.
	main.touch._set_active(true)
	menu.train_bench = "retrait"
	menu.inv_sel = "bench:chest:0"
	menu.open("train")
	await _frames(3)
	var small: Array = _all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.size.y < 36.0)
	_check(small.is_empty() and bench_buttons.call("retrait", "water").size() == 1, "on a phone every bench button is at least 36 tall: %s" % [small.map(func(b): return b.text)])
	main.touch._set_active(false)
	# Saved and loaded: ranks, runes and what packed supplies cost.
	var path := "user://smoke_bench_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	var m2: Array = G.heirloom_pieces(again.heirlooms, "melee")
	_check(m2.size() == 1 and int(m2[0]["rank"]) == 2 and m2[0].get("rune", "") == "sharpness" and G.same(again.pack[0], prof.pack[0]), "tempering, runes and joined pieces are saved and load again")
	_check(int(again.supplies.get("scroll", 0)) == 1 and again.supply_paid.get("scroll", []) == [{"air": 30, "water": 30}], "...and what a packed supply cost")
	_check(G.rec(G.code(m2[0])).get("rune", "") == "sharpness" and G.rec("spear;fine;0;edges").get("rune", "") == "", "a rune survives a piece's short code; old codes have none")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	# Leave the train (it pauses the game) for the tests after.
	main.depart("kraken")
	await _frames(2)
	_check(not paused and not menu.is_open(), "departing leaves the train")


## A monster beside the climber that waits (no physics), at full health.
func _still(kind: String, at: Vector2):
	var e = await _spawn(kind, at)
	e.state_t = 99.0
	e.aware = true
	return e


## The secret essences, Life and Unmaking (secret.gd): who leaves them, the
## path choice, the flow (gathered, passing through, banked, lost) and what
## each step does.
func _secret_tests() -> void:
	print("the secret essences")
	await _fresh_main()
	main.grant_test_bonds()
	var S = load("res://scripts/secret.gd")
	var E = load("res://scripts/essence.gd")
	var p = main.player
	var prof = main.profile
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	main.tower = "kraken"
	main.floor_num = 4
	_check(not main.secret_on, "tests keep the secret essences off unless they ask")
	main.secret_on = true
	_check(S.ORDER.all(func(k): return not E.KINDS.has(k)), "Life and Unmaking are not among the six kinds (crystals, the bench, prices and density never list them)")
	# Who leaves what.
	var beast: Dictionary = S.drop("beast", "kraken", 12)
	var shadow: Dictionary = S.drop("shadow", "kraken", 6)
	var shadow12: Dictionary = S.drop("shadow", "kraken", 12)
	var mirror: Dictionary = S.drop("mirror", "kraken", 6)
	_check(beast["life"] > beast["unmaking"] and beast["unmaking"] > 0.0, "a tower beast leaves mostly Life, some Unmaking")
	_check(shadow12["life"] < beast["life"] and shadow12["unmaking"] < beast["unmaking"] and shadow["life"] > shadow["unmaking"], "the Proving's shadow: the same split, less")
	_check(mirror["unmaking"] > mirror["life"], "a mirror image (for later) leaves mostly Unmaking")
	_check(S.drop("champion", "kraken", 8).keys() == ["life"] and S.drop("champion", "gryphon", 8).keys() == ["unmaking"], "a champion leaves a little of one kind, by tower")
	_check(S.drop("champion", "kraken", 10)["life"] > S.drop("champion", "kraken", 2)["life"] and S.drop("champion", "kraken", 2)["life"] < shadow["life"], "...more higher up, and less than a shadow")
	_check(S.drop("", "kraken", 8).is_empty(), "an ordinary monster leaves none")
	# An ordinary monster: nothing.
	var slime = await _still("slime", p.global_position + Vector2(90, 0))
	_check(S.great_foe(slime) == "", "a slime isn't a great foe")
	_slay(slime)
	await _frames(1)
	_check(not main.camp_choosing and main.secret_pending.is_empty() and main.run_flow == 0.0, "an ordinary monster's fall: no secret essence")
	# The first great foe opens the choice; its essence waits.
	var champ = await _still("knight", p.global_position + Vector2(90, 0))
	champ.make_champion()
	_check(S.great_foe(champ) == "champion", "a champion is a great foe")
	_slay(champ)
	await _frames(1)
	_check(main.camp_choosing and main.camp.get("stage", "") == "path" and main.secret_pending.size() == 1 and main.secret_pending[0]["kind"] == "life",
		"the first great foe's fall stops on the path choice; its Life waits")
	_check(not p.is_physics_processing() and main.camp["choices"] == ["path:life", "path:unmaking"], "...the game waits on two cards: Life and Unmaking")
	await _frames(2)
	var hud = main.hud
	var vs: Vector2 = hud.get_viewport_rect().size
	_check(hud.camp_card_at(hud.path_card_rect(1, vs).get_center()) == 1 and hud.camp_card_rect(0, vs) == hud.path_card_rect(0, vs), "the cards are where taps and clicks find them")
	main.choose_camp(1)
	_check(prof.path == "" and int(main.camp.get("armed", -1)) == -1, "a press in its first moment can't choose (a tap meant for the fight)")
	main.camp["t"] = 5.0
	main.choose_camp(1)
	_check(prof.path == "" and main.camp_choosing and int(main.camp["armed"]) == 1, "the first press only picks a card (it's for good)")
	main.choose_camp(0)
	_check(prof.path == "" and int(main.camp["armed"]) == 0, "...pressing the other picks that one instead")
	main.choose_camp(0)
	_check(prof.path == "life" and not main.camp_choosing and p.is_physics_processing(), "a second press on it lets Life in; the game goes on")
	_check(main.run_flow > 0.0 and main.secret_pending.is_empty(), "what waited soaks in at once (%.1f)" % main.run_flow)
	_check(p.flow_path == "life" and p.flow_step == 0, "the climber carries the path (no step yet)")
	# Afterwards: only the path's essence soaks in; the other passes through.
	var f0: float = main.run_flow
	var motes0: int = main.fx.motes_list.size()
	main.rise_secret("unmaking", 9.0, p.global_position + Vector2(120, 0))
	_check(is_equal_approx(main.run_flow, f0), "Unmaking isn't gathered once Life is your path")
	_check(main.fx.motes_list.size() > motes0 and main.fx.motes_list.slice(motes0).all(func(m): return m.get("through", false)), "...it rises and passes through you")
	await _until(func(): return main.fx.motes_list.any(func(m): return m.has("out")), 4.0)
	_check(main.fx.motes_list.any(func(m): return m.has("out")), "...and streaks out the far side")
	main.rise_secret("life", 9.0, p.global_position + Vector2(120, 0))
	_check(is_equal_approx(main.run_flow, f0 + 9.0), "Life still soaks in")
	# A tower beast: both rise, Life soaks in, Unmaking passes through.
	var bst = await _still("kraken", p.global_position + Vector2(200, 0))
	_check(S.great_foe(bst) == "beast", "a tower's beast is a great foe")
	var f1: float = main.run_flow
	_slay(bst)
	await _frames(1)
	_check(is_equal_approx(main.run_flow, f1 + S.drop("beast", "kraken", 4)["life"]), "a beast's Life soaks in, its Unmaking passes")
	var sh = main.proving.make_shadow("kraken", main.proving.TIERS[0])
	sh.position = p.global_position + Vector2(200, 0)
	main.add_child(sh)
	await _frames(1)
	sh.set_physics_process(false)
	var f2: float = main.run_flow
	var sh_is: String = S.great_foe(sh)
	_slay(sh)
	await _frames(1)
	_check(sh_is == "shadow" and is_equal_approx(main.run_flow, f2 + S.drop("shadow", "kraken", 4)["life"]), "the Proving's shadow leaves its own, smaller share")
	await _until(func(): return main.enemies().is_empty(), 2.0)
	# Banked at the stair.
	var carried: float = main.run_flow
	main._arrive()
	_check(is_equal_approx(prof.flow, carried) and main.run_flow == 0.0, "the stair banks the flow (%.1f)" % prof.flow)
	_check(main.banner.get("lines", []).any(func(l): return String(l).begins_with("Banked %d Life" % int(round(carried)))), "...and says so")
	await _until(func(): return not main.climbing and main.fade <= 0.0, 5.0)
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	# Lost on a fall (what's banked stays).
	var banked: float = prof.flow
	main.run_flow = 7.0
	_kill_blow(p)
	_check(p.dead and main.run_flow == 0.0 and is_equal_approx(prof.flow, banked), "a fall loses the flow you carried; the banked flow stays")
	p.dead = false
	p.hp = p.max_hp
	p.set_physics_process(true)
	main.fall_t = -1.0
	# The HUD gem only from the first step.
	prof.flow = 10.0
	main._give_bonds()
	await _frames(3)
	_check(not main.flow_shown() and not hud.tips.any(func(t): return String(t[1]).begins_with("Life")), "no gem on the HUD before the first step")
	main.dev_add_flow(15.0)
	await _frames(3)
	_check(main.flow_shown() and p.flow_step == 1 and hud.tips.any(func(t): return String(t[1]).begins_with("Life")), "at 25 banked, Life's gem joins the HUD")
	# Life, step by step.
	_check(is_equal_approx(p.flow_regen, S.EFFECTS["life"]["regen"][0]) and p.flow_mend == 0.0 and p.heal_mult() == 1.0 and not p.flow_refuse, "Life step 1: health regrows, nothing more yet")
	p.hp = 50.0
	await _until(func(): return p.hp > 50.5, 3.0)
	_check(p.hp > 50.5, "...and it does regrow")
	main.dev_add_flow(50.0)
	_check(p.flow_step == 2 and p.flow_mend > 0.0, "Life step 2 at 75")
	p.hp = 40.0
	var hp_kill: float = p.hp
	var s2 = await _still("slime", p.global_position + Vector2(120, 0))
	_slay(s2)
	_check(p.hp >= hp_kill + p.flow_mend - 0.01, "a kill mends you (+%d)" % int(p.flow_mend))
	main.dev_add_flow(75.0)
	_check(p.flow_step == 3 and p.heal_mult() > 1.3, "Life step 3 at 150: healing much stronger")
	p.heal_left = 0.0
	main.Items._heal_over_time(p, main.Items.ITEMS["draught"], false)
	_check(is_equal_approx(p.heal_left, float(main.Items.ITEMS["draught"]["heal"]) * p.heal_mult()), "...a draught heals %d, not %d" % [int(p.heal_left), int(main.Items.ITEMS["draught"]["heal"])])
	p.heal_left = 0.0
	main.dev_add_flow(150.0)
	_check(p.flow_step == 4 and p.flow_refuse, "Life step 4 at 300")
	p.hp = 10.0
	var near = await _still("slime", p.global_position + Vector2(40, 0))
	_kill_blow(p)
	_check(not p.dead and absf(p.hp - p.max_health() * S.REFUSE_HEALTH) < 1.0, "a killing blow leaves you standing at low health (%d)" % int(p.hp))
	_check(near.knock.length() > 100.0 and near.stun > 0.0, "...in a burst that throws back the monsters near you")
	p.hp = 10.0
	_kill_blow(p)
	_check(p.dead, "...once a floor")
	p.dead = false
	p.hp = p.max_hp
	p.set_physics_process(true)
	main.fall_t = -1.0
	near.queue_free()
	# Unmaking (reset first: the dev tools' hook for the Developer mark later).
	var plain_hp: float = p.max_hp
	main.reset_path()
	_check(prof.path == "" and prof.flow == 0.0 and p.flow_path == "" and is_equal_approx(p.max_hp, plain_hp), "reset_path clears the path and all its flow")
	main.dev_set_path("unmaking")
	main.dev_add_flow(25.0)
	_check(p.flow_step == 1 and is_equal_approx(p.max_hp, roundf(plain_hp * S.EFFECTS["unmaking"]["health"][0])) and p.hp <= p.max_health(), "Unmaking step 1: less max health (%d of %d)" % [int(p.max_hp), int(plain_hp)])
	var dummy = await _still("knight", p.global_position + Vector2(200, 0))
	dummy.face = Vector2.LEFT  # (facing the climber: no backstab)
	var dh: float = dummy.hp
	p._strike(dummy, 10.0, Vector2.RIGHT, 0.0, false)
	_check(absf((dh - dummy.hp) - 10.0 * S.EFFECTS["unmaking"]["damage"][0]) < 0.05, "...and more damage (%.1f from a 10 blow)" % (dh - dummy.hp))
	_check(p.bonds["hand"].flow_power == S.EFFECTS["unmaking"]["damage"][0], "...spells too")
	main.dev_add_flow(50.0)
	_check(p.flow_step == 2 and p.flow_erode > 0.0 and p.max_hp < plain_hp * S.EFFECTS["unmaking"]["health"][0], "Unmaking step 2: the trade grows, and the aura")
	dummy.global_position = p.global_position + Vector2(30, 0)
	dummy.aware = true
	var asleep = await _still("knight", p.global_position + Vector2(-30, 0))
	asleep.aware = false
	dh = dummy.hp
	var sh0: float = asleep.hp
	p._erode_t = 0.0
	await _until(func(): return dummy.hp < dh, 3.0)
	_check(dummy.hp < dh and asleep.hp == sh0, "the aura erodes an awake monster beside you, not a sleeping one")
	asleep.queue_free()
	main.dev_add_flow(75.0)
	_check(p.flow_step == 3 and p.flow_pierce, "Unmaking step 3: strikes ignore armour")
	var shell = await _still("shellback", p.global_position + Vector2(60, 0))
	shell.face = Vector2.LEFT  # facing the climber: its shell in front
	var shp: float = shell.hp
	p._strike(shell, 10.0, Vector2.RIGHT, 0.0, false)
	_check(absf((shp - shell.hp) - 10.0 * S.EFFECTS["unmaking"]["damage"][2]) < 0.05, "a shellback's shell doesn't turn the blow (%.1f)" % (shp - shell.hp))
	dummy.flinch = 0.0
	dummy.flinch_cd = 0.0
	dummy.state = "recover"
	p._strike(dummy, 1.0, Vector2.RIGHT, 0.0, false)
	_check(dummy.flinch > 0.0, "...and a knight's guard doesn't shrug off a light one")
	shell.queue_free()
	main.dev_add_flow(150.0)
	_check(p.flow_step == 4 and p.flow_undo > 0.0, "Unmaking step 4 at 300")
	var a = await _still("slime", p.global_position + Vector2(150, 0))
	var b = await _still("knight", p.global_position + Vector2(185, 0))
	var bh: float = b.hp
	_slay(a)
	_check(b.hp < bh, "a slain foe comes apart and hurts the monster beside it (%d)" % int(bh - b.hp))
	await _frames(2)
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	# Its shadow, drawn every frame, and the climber screen.
	p.queue_redraw()
	await _frames(3)
	main.menu.climber_tab = "essence"
	main.menu.open("climber")
	await _frames(2)
	var flows: Array = main.menu.box.get_children().filter(func(c): return c.get_script() == main.MenuScript.FlowView)
	_check(flows.size() == 1, "the climber screen shows the flow")
	main.menu.close()
	main.menu.open("dev")
	await _frames(1)
	_check(_menu_button("Reset path") != null and _menu_button("+25 flow") != null, "the dev tools can set the path, add flow and reset it")
	main.menu.close()
	# Saved, and old saves load.
	var path := "user://smoke_secret_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.path == "unmaking" and is_equal_approx(again.flow, prof.flow), "the path and the flow are saved and load again")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.path == "" and again.flow == 0.0, "an old save loads with no path")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	main.reset_path()
	main.secret_on = false

	# A recall scroll keeps crystals, but the flow you carried is lost.
	var banked_before: float = main.profile.flow
	main.run_flow = 7.0
	main.read_recall()
	_check(main.run_flow == 0.0 and is_equal_approx(main.profile.flow, banked_before), "a recall scroll loses the flow you carried (what's banked stays)")
	main.victory = {}




## The climber's looks (appearance.gd, appearance_page.gd): today's look by
## default, the creation page for a new climber and the first launch, the
## rows by keys, controller and taps, the name, Begin; the Appearance buttons
## on the climber screen and in your car; what the tower and the climber
## screen draw from; the save, old saves and odd ones.
func _appearance_tests() -> void:
	print("appearance: the new climber's looks")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	var A = load("res://scripts/appearance.gd")
	var P = load("res://scripts/palette.gd")
	var menu = main.menu
	var prof = main.profile
	var p = main.player
	var d: Dictionary = A.look(A.DEFAULTS)
	_check(d["cloak"] == P.CLIMBER_CLOAK and d["skin"] == P.CLIMBER_SKIN and d["tunic"] == P.CLIMBER_TUNIC and d["hair"] == P.CLIMBER_HAIR and d["boot"] == P.CLIMBER_BOOT and d["eyes"] == P.OUTLINE and d["hood_up"] and d["hair_style"] == "short", "the default look is the climber's look from before (teal hood up, brown hair and tunic)")
	_check(prof.appearance == A.DEFAULTS and p.appearance_look == d and main.climber_look == d, "a climber with no choice yet wears it, in the tower and on the climber screen")
	var sizes_ok: bool = A.OPTIONS["skin"].size() >= 6 and A.OPTIONS["skin"].size() <= 8 and A.OPTIONS["cloak"].size() >= 8 and A.OPTIONS["cloak"].size() <= 10 and A.OPTIONS["hair"].size() >= 5
	for key in A.OPTIONS:
		sizes_ok = sizes_ok and A.index_of(key, A.DEFAULTS[key]) >= 0
	_check(sizes_ok, "the options are data: 6-8 skins, 8-10 cloaks, five hair styles, each default among them")
	# New climber: the creation page opens before the first climb.
	main.new_climber()
	await _until(func(): return menu.page == "create", 2.0)
	_check(menu.page == "create" and not prof.created and menu.backdrop.visible, "New climber opens the creation page (over the title's sky) before the first climb")
	var page = menu.look_page
	_check(page.view != null and page.view.doll != null and page.view.doll.get_script() == p.get_script() and page.view.doll.appearance_look == main.climber_look, "...its preview is the tower's own drawing of the climber (a doll)")
	_check(page.view.doll.collision_layer == 0 and not page.view.doll.is_physics_processing(), "...which only draws (no body, no physics)")
	var vis := root.get_visible_rect()
	var inside := true
	for b in menu.find_children("*", "Button", true, false):
		if b.is_visible_in_tree():
			inside = inside and vis.encloses(b.get_global_rect())
	_check(inside, "every button on the creation page is on screen")
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	await _frames(2)
	_check(menu.page == "create", "Esc doesn't skip it (Begin is the way on)")
	# Keys and controller: start on the first row; Right / Left change it.
	var skin = page.rows["skin"]
	await _until(func(): return skin.has_focus(), 1.0)
	_check(skin.has_focus(), "keys and controller start on the first option (Skin)")
	await _key_tap(KEY_RIGHT)
	var want_skin: String = A.step(A.DEFAULTS, "skin", 1)
	_check(prof.appearance["skin"] == want_skin and main.climber_look["skin"] == A.color_of("skin", want_skin) and p.appearance_look["skin"] == A.color_of("skin", want_skin), "Right changes the focused option, kept and worn at once (tower and climber screen)")
	await _key_tap(KEY_LEFT)
	_check(prof.appearance["skin"] == A.DEFAULTS["skin"], "...and Left changes it back")
	await _key_tap(KEY_DOWN)
	_check(page.rows["hair"].has_focus(), "Down moves to the next option")
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(prof.appearance["hair"] == "long" and p.appearance_look["hair_style"] == "long", "the controller's d-pad changes it too (short to long hair)")
	main.pad._set_active(false)
	# Taps (a phone): a swatch picks itself, an arrow steps.
	main.touch._set_active(true)
	await _frames(3)
	var cl = page.rows["cloak"]
	var mid: Rect2 = cl._middle()
	var n: int = A.OPTIONS["cloak"].size()
	var ci: int = A.index_of("cloak", "crimson")
	await _tap_at(cl.get_global_transform() * Vector2(mid.position.x + mid.size.x / n * (ci + 0.5), cl.size.y * 0.5))
	_check(prof.appearance["cloak"] == "crimson" and main.climber_look["cloak"] == A.color_of("cloak", "crimson") and p.appearance_look["cloak"] == A.color_of("cloak", "crimson"), "a tap on a swatch picks it (a crimson cloak)")
	var hood = page.rows["hood"]
	await _frames(2)
	await _tap_at(hood.get_global_transform() * Vector2(hood.size.x - 20.0, hood.size.y * 0.5))
	_check(prof.appearance["hood"] == "down" and not p.appearance_look["hood_up"] and not main.climber_look["hood_up"], "a tap on an arrow steps it (hood down)")
	main.touch._set_active(false)
	var lk: Dictionary = p.appearance_look.duplicate()
	p._piece_look(lk, true)
	p._armor_look(lk)
	_check(lk["head"] == "bare" and A.crown(lk) == lk["hair"], "with the hood down the tower draws the head bare, the hair on show")
	lk = A.look(A.DEFAULTS)
	p._piece_look(lk, true)
	_check(lk["head"] == "hood", "...and with it up, the hood")
	# The name: the dice, and a typed name kept short; typing isn't shortcuts.
	page.roll_name()
	_check(prof.appearance["name"] in A.NAMES, "the dice picks a name")
	page.set_name("  A very long name for one climber  ")
	_check(prof.appearance["name"].length() <= A.NAME_MAX and prof.appearance["name"].begins_with("A very"), "a typed name is trimmed and kept short")
	page.name_edit.grab_focus()
	await _frames(1)
	await _key_tap(KEY_I)
	await _key_tap(KEY_E)
	_check(menu.page == "create" and page.name_edit.has_focus(), "typing in the name doesn't set off shortcuts (I, E)")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "create" and not page.name_edit.has_focus(), "Esc leaves the name field, not the page")
	var turned: float = page.view.want
	await _key_tap(KEY_E)
	_check(page.view.want > turned, "E (RB) turns the preview")
	var keep_name: String = prof.appearance["name"]
	page.randomise()
	_check(prof.appearance["name"] == keep_name and page.rows["cloak"].value == prof.appearance["cloak"], "Randomise rolls a look and keeps the name")
	_check(page.finish.text == A.TEXT["begin"], "the page ends in Begin")
	page.finish.pressed.emit()
	await _frames(2)
	_check(menu.page == "" and prof.created and main.climber_look == A.look(prof.appearance), "Begin makes the climber and goes on to the first climb")
	Engine.remove_meta("sixfold_title_seen")
	# The very first launch: no save, so Begin on the title opens it.
	var Prof = load("res://scripts/profile.gd")
	var none = Prof.new()
	none.save_path = "user://smoke_no_save_here.cfg"
	none.load_save()
	_check(not none.created and none.appearance == A.DEFAULTS, "with no save at all, a climber is still to be made, in today's look")
	prof.created = false
	menu.open("title")
	await _frames(2)
	_menu_button("Begin your first climb").pressed.emit()
	await _frames(2)
	_check(menu.page == "create" and menu.backdrop.visible, "the very first launch: Begin on the title opens the creation page")
	page.begin()
	await _frames(2)
	_check(menu.page == "" and prof.created, "...and Begin there starts the climb")
	Engine.remove_meta("sixfold_title_seen")
	# Later: Appearance on the climber screen, and back.
	main.choosing_tower = false
	menu.climber_tab = "marks"
	menu.open("climber")
	await _frames(2)
	var ab: Array = _all_buttons(menu).filter(func(b): return b.has_meta("appearance") and b.is_visible_in_tree())
	_check(ab.size() == 1, "the climber screen has an Appearance button")
	if ab.size() == 1:
		ab[0].pressed.emit()
		await _frames(2)
	_check(menu.page == "appearance" and page.finish.text.begins_with(A.TEXT["done"]), "...which opens the same editor, ending in Done")
	var tunic0: String = prof.appearance["tunic"]
	page.rows["tunic"].change(1)
	_check(prof.appearance["tunic"] != tunic0 and main.climber_look["tunic"] == A.color_of("tunic", prof.appearance["tunic"]), "a change there is kept, and the climber screen's figure draws from it")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "climber", "Back returns to the climber screen")
	menu.close()
	await _frames(2)
	# Save, load, old saves and odd ones.
	var path := "user://smoke_look_test.cfg"
	prof.appearance = A.normalized({"name": "Wren", "skin": "deep", "hair": "braid", "hair_color": "copper", "eyes": "green", "cloak": "plum", "tunic": "navy", "hood": "down"})
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = Prof.new()
	again.save_path = path
	again.load_save()
	_check(again.appearance == prof.appearance and again.created, "the look and the name are saved and load again")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = Prof.new()
	again.save_path = path
	again.load_save()
	_check(again.appearance == A.DEFAULTS and again.created, "a save from before looks loads as today's look, already made")
	old = ConfigFile.new()
	old.set_value("settings", "music", 0.5)
	old.set_value("look", "appearance", {"cloak": "nope", "skin": 42, "hair": "braid"})
	old.save(path)
	again = Prof.new()
	again.save_path = path
	again.load_save()
	_check(not again.created and again.appearance["cloak"] == "teal" and again.appearance["skin"] == "fair" and again.appearance["hair"] == "braid", "a file of settings only is a climber still to be made; unknown options fall back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	# The train: Your car's Appearance button, and closing returns to it.
	main.grant_test_bonds()
	main.await_tower()
	main.open_train()
	await _frames(3)
	var tb: Array = _car_buttons("car_page", "appearance")
	_check(tb.size() == 1, "your car on the train has an Appearance button")
	if tb.size() == 1:
		tb[0].pressed.emit()
		await _frames(2)
	_check(menu.page == "appearance", "...which opens the editor")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "personal", "...and Back returns to your car")
## The Makers (makers.gd, maker_view.gd): fragments in secret rooms and
## vaults, the forbidden shelf, interest, glimpses, the reveal, meetings,
## the core mark, the plea, redaction and saving.
func _maker_tests() -> void:
	print("the Makers")
	await _fresh_main()
	main.grant_test_bonds()
	var M = load("res://scripts/makers.gd")
	var mk = main.makers
	var prof = main.profile
	var p = main.player
	var W = main.wings
	# The Makers' words are written (any line may still be redacted, drawn as bars).
	var said: Array = []
	for m in M.ORDER:
		for k in ["speech", "good_reply", "bad_reply", "already", "plea_yes", "plea_no", "interrupt", "entity", "fragments"]:
			said.append_array(M.MAKERS[m][k])
	_check(said.size() > 40 and said.all(func(l): return not M.is_redacted(l) and String(l).length() > 8), "every Maker's line, fragment and the Entity's lines about them are written (%d lines)" % said.size())
	_check(M.is_redacted("▇▇▇ ▇▇▇▇") and M.ANSWERS.all(func(a): return not a["placeholder"] and not M.is_redacted(a["text"])), "the answers are written, and a line of bars still counts as redacted")
	var bars = load("res://scripts/draw_util.gd").Batch.new()
	var h: float = M.redact_into(bars, Vector2.ZERO, 60.0, "▇▇▇▇ ▇▇▇▇▇ ▇▇▇ ▇▇▇▇▇▇", Color.WHITE, 13.0)
	_check(bars.size() > 0 and h > 13.0 * 1.45, "redacted words draw as bars, wrapping (%.0f tall)" % h)
	# Nothing shows before anything is found.
	main.menu.open("library")
	await _frames(2)
	_check(main.menu.find_children("*", "", true, false).all(func(n): return not n.has_meta("shelf")), "before a fragment is found the Archive shows no shelf")
	main.menu.close()
	paused = false
	await _frames(1)

	# Fragments: only in a secret room or a vault, one a floor at most.
	mk.chance_override = 0.0
	main._start_floor(4)
	_check(mk.fragment.is_empty(), "most floors have no fragment")
	mk.chance_override = 1.0
	var placed := 0
	var ok := true
	for n in 8:
		main._start_floor(3 + n)
		var f: Dictionary = mk.fragment
		if f.is_empty():
			ok = ok and W.secrets.is_empty() and W.wings.all(func(w): return not w.has("alcove"))
			continue
		placed += 1
		var ref: Dictionary = f["ref"]
		var home: Rect2 = ref["rect"] if f["src"] == "secret" else ref["alcove"]
		ok = ok and f["src"] in ["secret", "vault"] and f["room"] == home and home.has_point(f["read_at"]) and not home.has_point(f["wall"])
		# Not on the main path: none of the floor's own rooms holds it.
		ok = ok and main.layout_rooms.all(func(r): return not r.has_point(f["read_at"]))
	_check(placed >= 4 and ok, "a fragment sits on the north wall of a secret room or a vault, never in the floor's rooms (%d of 8 floors)" % placed)
	var first_was: bool = main.first_climb
	main.first_climb = true
	main._start_floor(5)
	_check(mk.fragment.is_empty(), "never on the first climb")
	main.first_climb = first_was
	_check(await _wing_floor(true), "a floor with a secret room")
	if mk.fragment.is_empty() or mk.fragment["src"] != "secret":
		var spots: Array = mk.candidates().filter(func(c): return c["src"] == "secret")
		if not spots.is_empty():
			mk.clear_floor()
			mk.fragment = spots[0]
			mk.fragment["maker"] = "towers"
			mk.fragment["read"] = false
			mk.fragment["light"] = -1
	var fr: Dictionary = mk.fragment
	_check(not fr.is_empty() and fr["src"] == "secret" and not mk.fragment_open(), "a fragment in a secret room, hidden until it opens")
	if fr.is_empty():
		mk.chance_override = -1.0
		return
	var maker: String = fr["maker"]
	var col: Color = M.color(maker)
	p.global_position = fr["read_at"]
	await _frames(2)
	_check(not fr["read"], "...it can't be read through the rock")
	var tw0: float = mk.interest("towers")
	W._open_secret(fr["ref"])
	_check(mk.interest("towers") > tw0, "leaning a secret wall open draws the Maker of Towers' interest")
	var i0: float = mk.interest(maker)
	await _until(func(): return fr["read"], 2.0)
	_check(int(fr["light"]) >= 0 and main.lighting.lights.has(fr["light"]) and main.lighting.lights[fr["light"]]["color"] == col, "open, it glows faintly in its Maker's colour")
	_check(fr["read"] and M.fragment_count(prof) == 1 and M.fragment_count(prof, maker) == 1, "walking up to it reads it, and it's kept")
	_check(mk.interest(maker) >= i0 + M.WEIGHTS["fragment"][maker] + M.WEIGHTS["fragment_own"][maker] - 0.01, "knowledge feeds its Maker most (%.0f -> %.0f)" % [i0, mk.interest(maker)])
	await _frames(3)
	var sl: int = mk.shift_light
	_check(mk.shift_t > 0.0 and main.lighting.lights.has(sl) and main.lighting.lights[sl]["color"] == col and main.lighting.lights[sl]["k"] > 0.0, "the room's light shifts in its Maker's colour")
	_check(main.lighting.mat.get_shader_parameter("dark_color") != main.lighting.dark_color, "...the darkness tints toward it")
	_check(mk.quiet() and not main.entity.can_show(), "the Entity goes quiet (no tip bubble)")
	_check(main.banner.get("title", "") == M.TEXT["fragment_title"], "a short moment: the fragment's banner")
	# The forbidden shelf.
	main.menu.open("library")
	await _frames(2)
	var shelves: Array = main.menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("shelf"))
	var texts: Array = main.menu.find_children("*", "", true, false).filter(func(n): return n.has_meta("fragment_text"))
	_check(shelves.size() == 1 and shelves[0].get_meta("shelf") == maker and texts.size() == 1 and String(texts[0].get_meta("fragment_text")) in M.MAKERS[maker]["fragments"], "the Archive gains its Maker's shelf: one fragment, its words written")
	_check(main.menu.find_children("*", "", true, false).all(func(n): return not n.has_meta("entity_sibling")), "...the Entity says nothing of its siblings before you've met one")
	main.menu.close()
	paused = false
	mk.quiet_t = 0.0
	mk._end_shift()
	await _frames(1)

	# Interest, from the right events.
	var before := {}
	for m in M.ORDER:
		before[m] = mk.interest(m)
	var slime = await _spawn("slime", p.global_position + Vector2(160, 0))
	_slay(slime)
	await _frames(1)
	_check(mk.interest("creatures") > before["creatures"] and mk.interest("marks") == before["marks"], "a kill feeds the Maker of Creatures only")
	before["creatures"] = mk.interest("creatures")
	p.cast_part = "hand"
	p.bonds["hand"].burned = false
	p.bonds["hand"].essence = 100.0
	p._release_cast()
	_check(mk.interest("marks") >= before["marks"] + M.WEIGHTS["cast"]["marks"] + M.WEIGHTS["new_spell"]["marks"] - 0.01, "a spell cast (a new one this climb) feeds the Maker of Marks")
	before["marks"] = mk.interest("marks")
	p.bonds["hand"].burned = false
	p.bonds["hand"].essence = 100.0
	p._release_cast()
	_check(absf(mk.interest("marks") - before["marks"] - M.WEIGHTS["cast"]["marks"]) < 0.01, "...the same spell again, less (variety counts)")
	before["marks"] = mk.interest("marks")
	before["towers"] = mk.interest("towers")
	main.lift_ward()
	_check(mk.interest("towers") > before["towers"] and mk.interest("marks") == before["marks"], "a puzzle solved feeds the Maker of Towers")
	for m in M.ORDER:
		before[m] = mk.interest(m)
	await _settle()
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.hp = p.max_health()
	p.receive_attack(10.0, null)
	_check(M.ORDER.all(func(m): return mk.interest(m) > before[m]), "a wound feeds all three (the body)")
	for m in M.ORDER:
		before[m] = mk.interest(m)
	mk.sync_body()
	prof.add_bond("brow", "hunter", false)
	mk.sync_body()
	_check(mk.interest("marks") >= before["marks"] + M.WEIGHTS["mark"]["marks"] - 0.01, "a new mark taken feeds them, most the Maker of Marks")
	# No reveal under six fragments, however interested.
	while M.fragment_count(prof) < 5:
		mk.dev_fragment()
	for m in M.ORDER:
		M.state(prof)["interest"][m] = 0.0
	M.state(prof)["interest"]["marks"] = 99999.0
	_check(mk.ready_maker() == "", "no Maker reveals itself under six fragments, however interested (5 found)")
	mk.on_arrive()
	_check(mk.pending == "", "...a stair brings no meeting")
	mk.dev_fragment()
	_check(mk.ready_maker() == "marks", "six fragments, and the most interested Maker past its threshold would show itself")
	M.state(prof)["interest"]["marks"] = 10.0
	_check(mk.ready_maker() == "", "...but not without the interest")
	# A glimpse.
	var g0 := int(M.state(prof)["glimpses"])
	mk.start_glimpse("towers", "shadow")
	_check(not mk.glimpse.is_empty() and mk.quiet() and int(M.state(prof)["glimpses"]) == g0 + 1, "a glimpse: a second shadow at the stair, and the Entity quiet")
	mk.glimpse = {}
	mk.quiet_t = 0.0

	# The meeting, with a stand-in for the secret essences' hooks.
	var fake_src := GDScript.new()
	fake_src.source_code = "extends RefCounted\nvar path := \"life\"\nvar resets := 0\nvar gained := {}\nfunc reset_path():\n\tresets += 1\nfunc gain_secret(kind, amount):\n\tgained[kind] = gained.get(kind, 0.0) + amount\n"
	fake_src.reload()
	var fake = fake_src.new()
	mk.hooks = fake
	M.state(prof)["interest"]["marks"] = 99999.0
	mk.start_meeting("marks")
	var v = mk.view
	_check(mk.meeting_live() and paused and not main.entity.can_show(), "a Maker shows itself: the game pauses, the Entity is quiet")
	v.t = 9.0
	await _until(func(): return v.stage == "speech", 2.0)
	v.t = 9.0
	v.advance()
	var ids: Array = v.options.map(func(o): return o["id"])
	_check(v.stage == "answer" and ids.size() == M.ANSWERS.size() + 1 and "plea" in ids, "...its speech, then the answers (and a plea, once you have a path)")
	await _frames(2)
	_check(v.card_at(v.card_rect(0).get_center()) == 0 and v.card_at(v.card_rect(ids.size() - 1).get_center()) == ids.size() - 1, "the cards are where taps and clicks find them")
	v.t = 9.0
	v.choose(ids.find("understand"))
	_check(v.stage == "verdict" and v.result.get("granted", "") == "developer", "a good answer grants its secret bond")
	var c: Dictionary = M.core(prof)
	_check(c.get("bond", "") == "developer" and c.get("maker", "") == "marks" and int(c.get("depth", 0)) == 1, "core mark = developer, depth 1")
	_check(prof.core_mark == "developer" and prof.core_depth == 1, "...kept as the profile's core_mark and core_depth")
	v.t = 9.0
	v.advance()
	await _frames(1)
	_check(not mk.meeting_live() and not paused, "the meeting ends and the game goes on")
	_check(fake.gained.get("life", 0.0) > 0.0 and fake.gained.get("unmaking", 0.0) > 0.0, "the Maker of Marks gives both secret essences through the hook")
	_check(M.core_text(prof) != "", "the core mark shows: %s" % M.core_text(prof))
	# A second Maker can't grant another.
	mk.interrupt_chance = 0.0
	mk.start_meeting("towers")
	v = mk.view
	v.stage = "answer"
	v.t = 9.0
	v.choose(v.options.map(func(o): return o["id"]).find("understand"))
	_check(v.result.get("granted", "") == "" and M.TEXT["one_only"] in v.result["lines"] and M.core(prof)["bond"] == "developer", "a second Maker can't grant another (one per climber)")
	v.t = 9.0
	v.advance()
	await _frames(1)
	# A bad answer turns it away.
	var th0: float = mk.threshold("creatures")
	mk.start_meeting("creatures")
	v = mk.view
	v.stage = "answer"
	v.t = 9.0
	v.choose(v.options.map(func(o): return o["id"]).find("take"))
	_check(not v.result["good"] and int(M.state(prof)["turned"].get("creatures", 0)) == 1 and mk.interest("creatures") < mk.threshold("creatures") and mk.threshold("creatures") > th0, "a bad answer turns it away: its interest drops, and it remembers")
	v.t = 9.0
	v.advance()
	await _frames(1)
	# Interrupted by the Maker whose core mark you carry.
	mk.interrupt_chance = 1.0
	mk.interrupt_way = "listen"
	mk.start_meeting("towers")
	v = mk.view
	v.t = 9.0
	await _until(func(): return v.stage == "speech", 2.0)
	v.t = 9.0
	v.advance()
	_check(v.stage == "interrupt" and v.interrupter == "marks", "with a core mark, its Maker may interrupt another's meeting")
	v.t = 9.0
	v.advance()
	_check(v.stage == "answer" and v.listening, "...it stays and listens")
	v.t = 9.0
	v.choose(0)
	_check(v.result.get("granted", "") == "" and M.core(prof)["bond"] == "developer", "...and no bond comes of it")
	v.t = 9.0
	v.advance()
	await _frames(1)
	mk.interrupt_way = "cut_short"
	var met0 := int(M.state(prof)["met"].get("towers", 0))
	mk.start_meeting("towers")
	v = mk.view
	v.stage = "speech"
	v.t = 9.0
	v.advance()
	v.t = 9.0
	v.advance()
	_check(v.stage == "verdict" and String(v.result["lines"][0]).contains("cuts the meeting short") and int(M.state(prof)["met"]["towers"]) == met0 + 1, "...or cuts it short")
	v.t = 9.0
	v.advance()
	await _frames(1)
	# The plea calls the reset hook.
	mk.interrupt_chance = 0.0
	mk.plea_force = 1
	mk.start_meeting("creatures")
	v = mk.view
	v.stage = "answer"
	v.t = 9.0
	v.choose(v.options.map(func(o): return o["id"]).find("plea"))
	_check(fake.resets == 1 and M.TEXT["plea_yes"] in v.result["lines"], "a plea for a change of path: if it agrees, the reset hook is called")
	v.t = 9.0
	v.advance()
	await _frames(1)
	mk.plea_force = 0
	mk.start_meeting("creatures")
	v = mk.view
	v.stage = "answer"
	v.t = 9.0
	v.choose(v.options.map(func(o): return o["id"]).find("plea"))
	_check(fake.resets == 1 and M.TEXT["plea_no"] in v.result["lines"], "...it can refuse")
	v.t = 9.0
	v.advance()
	await _frames(1)
	mk.plea_force = -1
	mk.hooks = main
	_check(mk.current_path() != "" or mk.answers().all(func(o): return o["id"] != "plea"), "no plea without a path")
	# After the stair: the reveal comes in the quiet.
	M.state(prof)["interest"]["towers"] = 99999.0
	mk.meetings_climb = 0
	mk.on_arrive()
	_check(mk.pending == "towers", "past six fragments and its threshold, a Maker comes after the stair")
	await _until(func(): return mk.meeting_live(), 3.0)
	_check(mk.meeting_live() and paused, "...and shows itself")
	mk.end_meeting({})
	await _frames(1)
	# The core mark on the climber and on the climber screen.
	p.queue_redraw()
	main.menu.climber_tab = "marks"
	main.menu.open("climber")
	await _frames(2)
	var labels: Array = main.menu.find_children("*", "Label", true, false).filter(func(l): return l.text == M.core_text(prof))
	_check(labels.size() == 1, "the climber screen names the core mark")
	main.menu.open("library")
	await _frames(2)
	_check(main.menu.find_children("*", "", true, false).any(func(n): return n.has_meta("entity_sibling") and not M.is_redacted(n.get_meta("entity_sibling"))), "once you've met one, the Entity speaks of its siblings")
	main.menu.close()
	paused = false
	await _frames(1)
	# Saved with the profile; old saves load.
	var path := "user://makers_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	var P = load("res://scripts/profile.gd")
	var back = P.new()
	back.save_path = path
	back.load_save()
	var bs: Dictionary = M.state(back)
	_check(bs["fragments"].size() == M.fragment_count(prof) and back.core_mark == "developer" and back.core_depth == 1 and M.core(back).get("bond", "") == "developer" and int(bs["turned"].get("creatures", 0)) == 1 and is_equal_approx(float(bs["interest"]["towers"]), mk.interest("towers")), "fragments, interest, meetings and the core mark are saved")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	var older = P.new()
	older.save_path = path
	older.load_save()
	var os: Dictionary = M.state(older)
	_check(os["fragments"].is_empty() and M.core(older).is_empty() and older.core_mark == "" and older.core_depth == 0 and float(os["interest"]["marks"]) == 0.0, "an old save loads with the Makers empty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.saving = false
	prof.save_path = P.SAVE_PATH
	mk.chance_override = -1.0
	mk.interrupt_chance = M.INTERRUPT["chance"]
	mk.interrupt_way = ""
## A mirror image of the climber (mirror.gd): what it copies, its
## telegraphed attacks, its guard and roll, the mirror room that seals
## until it falls, its secret essence, and where mirror rooms may appear.
func _mirror_image_tests() -> void:
	print("mirror images")
	var M = load("res://scripts/mirror.gd")
	var S = load("res://scripts/secret.gd")
	var Tw = load("res://scripts/towers.gd")
	await _fresh_main()
	_check(M.climb_ok == false, "the bondless first climb plans no mirror rooms (climb_ok %s)" % M.climb_ok)
	# Where they may appear, and how often.
	var never := true
	for fl in [1, 2, 3, int(Tw.PROVING["floor"]), int(Tw.SUMMIT)]:
		for i in 400:
			never = never and not M.wants_room(fl, false)
	for i in 400:
		never = never and not M.wants_room(8, true)
	_check(never, "never on floors 1-3, the Proving's floor, the summit or the first climb")
	var hits := 0
	for i in 3000:
		if M.wants_room(7, false):
			hits += 1
	var share := float(hits) / 3000.0
	_check(absf(share - float(M.ROOM["chance"])) < 0.04, "about %d%% of floors from %d up hold one (%.1f%%)" % [roundi(100.0 * M.ROOM["chance"]), M.ROOM["from"], 100.0 * share])
	_check(M.wants_room(2, true, true) and not M.wants_room(6, false, true), "the dev tool forces one on any planned floor, never the Proving's")
	var F = load("res://scripts/floors.gd")
	var T = load("res://scripts/themes.gd")
	var none := true
	for i in 10:
		none = none and not (M.THEME in F.rooms_floor(7, Tw.TOWERS[Tw.ORDER[i % 6]]).get("themes", []))
	_check(none, "a floor planned on the first climb has none")
	M.climb_ok = true
	M.force = true
	var kept := true
	for i in 12:
		var plan: Dictionary = F.rooms_floor(5, Tw.TOWERS[Tw.ORDER[i % 6]])
		var th: Array = plan.get("themes", [])
		var at := th.find(M.THEME)
		kept = kept and at >= 0 and plan["room_info"][at]["role"] == "branch" and "den" in th and th.any(func(t): return T.get_theme(t)["kind"] == "good") \
			and not plan["monsters"].any(func(m): return plan["room_info"][at]["rect"].has_point(m[1]))
	M.force = false
	M.climb_ok = false
	_check(kept, "a mirror room takes a branch room, empty of monsters, and the floor keeps its good room and den")
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	main.floor_num = 5
	var p = main.player
	p.set_physics_process(false)
	main.dev_give_gear("plate")
	_check(p.protection() > 0.0, "(the climber wears plate)")
	# Built from the climber.
	var e = M.spawn(main, p.global_position + Vector2(70, 0))
	await _frames(1)
	e.set_physics_process(false)
	_check(e.mirror and S.great_foe(e) == "mirror", "a mirror image is a great foe (mirror)")
	_check(e.w_id == p.weapon and e.chain.size() == mini(3, p.wdata()["combo"].size()) and not e.ranged, "it carries the weapon in your hand (%s) and its chain" % e.w_id)
	_check(is_equal_approx(e.armor, p.protection()), "it wears your armor (%.2f)" % e.armor)
	var names: Array = e.spells.map(func(s): return s["name"])
	_check(e.spells.size() == 2 and "Chain Lightning" in names and "Gale Lift" in names, "it casts your marks' spells: %s" % ", ".join(names))
	_check(e.marks.size() == p.bonds.size(), "your marks show on it")
	_check(e.max_hp > 100.0 and e.max_hp < 3.5 * 48.0 * main.Floors.toughness(5).x, "a mini-boss's health, below a champion's (%d)" % int(e.max_hp))
	var hp0: float = e.hp
	e.state = "chase"
	e.take_hit(20.0, Vector2.ZERO)
	_check(absf((hp0 - e.hp) - 20.0 * (1.0 - e.armor)) < 0.5, "your armor takes the edge off blows on it")
	# Its guard turns a light blow from the front and answers; a finisher breaks through.
	e.face = Vector2.LEFT
	e.state = "guard"
	e.state_t = 1.0
	hp0 = e.hp
	e.take_hit(10.0, Vector2.RIGHT)
	_check(e.hp == hp0 and e.state == "wind_swing", "its guard turns a light blow aside, and it answers with a telegraphed swing")
	e._end_attack("guard", 1.0)
	e.take_hit(10.0, Vector2.RIGHT, 140.0, true)
	_check(e.hp < hp0, "a finisher breaks its guard")
	e.state = "roll"
	hp0 = e.hp
	e.take_hit(10.0, Vector2.RIGHT)
	_check(e.hp == hp0, "a rolling mirror image can't be hit")
	main.release_attack(e)
	# Telegraphed: a wind-up and a glint before any blow lands.
	e.state = "chase"
	e.flinch = 0.0
	e.stun = 0.0
	e.global_position = p.global_position + Vector2(36, 0)
	e.spell_t = 99.0
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	var php: float = p.hp
	e.set_physics_process(true)
	await _until(func(): return e.state == "wind_swing" or p.hp < php, 3.0)
	_check(e.state == "wind_swing" and p.hp == php, "its swing starts with a wind-up, before any damage")
	await _until(func(): return e.glinted or p.hp < php, 2.0)
	var glint_at := Time.get_ticks_msec()
	_check(e.glinted and p.hp == php, "...then the glint, still before the blow")
	await _until(func(): return p.hp < php, 2.0)
	var lead := (Time.get_ticks_msec() - glint_at) / 1000.0
	_check(p.hp < php and lead > 0.15, "...and the blow lands after it (%.2f s)" % lead)
	e.set_physics_process(false)
	main.release_attack(e)
	# A spell: its telegraph first.
	var bi: int = e.spells.map(func(s): return s["shape"]).find("blast")
	e.spell_i = maxi(bi, 0)
	e.spell_t = 0.0
	e._end_attack("chase", 0.0)
	e.global_position = p.global_position + Vector2(170, 0)
	p.hp = p.max_health()
	p.hurt_t = 0.0
	php = p.hp
	e.set_physics_process(true)
	await _until(func(): return e.state == "wind_spell" or p.hp < php, 3.0)
	_check(e.state == "wind_spell" and p.hp == php, "its spell (%s) is telegraphed before it lands" % e.spells[e.spell_i]["name"])
	await _until(func(): return e.state != "wind_spell", 2.0)
	_check(p.hp < php, "...and the blast hurts if you stay in it")
	e.set_physics_process(false)
	e.queue_free()
	main.release_attack(e)
	# A bow.
	p.weapon = "shortbow"
	var b = M.spawn(main, p.global_position + Vector2(200, 0))
	await _frames(1)
	_check(b.ranged and b.chain.is_empty() and b.shot_damage() > 0.0, "with a bow in your hand, it shoots")
	b.state = "chase"
	b.state_t = 0.0
	b.spell_t = 99.0
	await _until(func(): return b.state == "wind_shot", 3.0)
	_check(b.state == "wind_shot", "...drawing first, its aim line showing")
	b.queue_free()
	p.weapon = "sword"
	await _frames(1)
	main.release_attack(b)
	_check(main.dev_spawn("mirror").mirror, "the dev tool spawns a mirror image")
	for o in main.enemies():
		o.queue_free()
	await _frames(1)

	print("the mirror room")
	main.secret_on = true
	main.tower = "kraken"
	M.force = true
	var mi := -1
	for n in 20:
		main._start_floor(5)
		await _frames(1)
		mi = main.room_themes.find(M.THEME)
		if mi >= 0:
			break
	_check(mi >= 0 and not M.force, "the dev tool's mirror room is planned on the next floor (and the force spent)")
	if mi < 0:
		return
	var info: Dictionary = main.room_info[mi]
	var rect: Rect2 = info["rect"]
	_check(info["role"] == "branch", "a mirror room is a branch room, off the way to the stair")
	_check(not main.floor_plan["monsters"].any(func(m): return rect.has_point(m[1])), "no ordinary monsters wait in it")
	var door: Array = main.door_view.list.filter(func(d): return d["room"] == mi)
	_check(not door.is_empty() and door[0]["style"] == "mirror", "its door bears the mirror")
	_check(main.door_view.lock_rooms.has(mi), "it is a lock-in room")
	for o in main.enemies():
		o.queue_free()
	await _frames(1)
	main.open_all_doors()
	main.banner = {}
	p.global_position = rect.get_center() + Vector2(0, rect.size.y * 0.3)
	await _until(func(): return main.enemies().any(func(o): return o.mirror), 2.0)
	var img: Array = main.enemies().filter(func(o): return o.mirror)
	_check(img.size() == 1, "walking in, its mirror image steps out of the glass")
	if img.is_empty():
		return
	var m = img[0]
	m.set_physics_process(false)
	await _until(func(): return main.door_view.lock_rooms[mi]["state"] == "shut", 2.0)
	_check(main.door_view.lock_rooms[mi]["state"] == "shut", "...and the doors shut behind you")
	var crystals: float = main.profile.crystal_total(main.tower_data()["essence"])
	_check(main.profile.path == "", "(no path yet)")
	_slay(m)
	await _frames(1)
	var pend := {}
	for s in main.secret_pending:
		pend[s["kind"]] = float(pend.get(s["kind"], 0.0)) + float(s["amount"])
	_check(main.camp_choosing and main.camp.get("stage", "") == "path", "its fall opens the path choice (a great foe)")
	_check(pend.get("unmaking", 0.0) > pend.get("life", 0.0) and pend.get("life", 0.0) > 0.0, "it leaves mostly Unmaking, some Life")
	_check(main.profile.crystal_total(main.tower_data()["essence"]) > crystals, "...and an essence crystal")
	main.camp["t"] = 5.0
	main.choose_camp(1)
	main.choose_camp(1)
	await _until(func(): return main.door_view.lock_rooms[mi]["state"] == "done", 2.0)
	_check(main.door_view.lock_rooms[mi]["state"] == "done", "the doors open once it falls")
	_check(main.GuideScript.Entity.TIPS.has("mirror") and main.GuideScript.Entity.ROOM_TIPS.get("mirror", "") == "mirror", "the Entity has a tip for it")
	main.secret_on = false
	M.force = false
	M.climb_ok = true
## The three secret bonds (secret_bonds.gd, secret_tools.gd, secret_page.gd):
## the tool ring, every depth 1 and 2 tool, costs, growth, the Core tab, save.
func _secret_bond_tests() -> void:
	print("the secret bonds")
	await _fresh_main()
	main.grant_test_bonds()
	var SB = load("res://scripts/secret_bonds.gd")
	var T = main.secret_tools
	var p = main.player
	var prof = main.profile
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	p.mouse_aim = false
	p.iframes = 9999.0
	# No secret bond: no ring, no Tools button, no Core tab.
	_check(T != null and not T.ring_ready() and SB.ring_tools(prof).is_empty(), "no secret bond: no tools")
	Input.action_press("tool_ring")
	await _until(func(): return T.ring_open, 0.45)
	_check(not T.ring_open, "...holding the tool button opens nothing")
	Input.action_release("tool_ring")
	await _frames(2)
	main.touch._layout()
	_check(not main.touch.buttons.any(func(b): return b["id"] == "tools"), "...and no Tools button on a phone")
	_check(not main.menu.climber_tabs().any(func(t): return t[0] == "core"), "...and no Core tab")
	# The ring's tools at depths 1 and 2.
	var want := {"developer": [["dev_inspect"], ["dev_inspect", "dev_tune"]], "designer": [["des_inspect"], ["des_inspect", "des_switch"]],
		"manipulator": [["man_inspect"], ["man_inspect", "man_calm", "man_feud"]]}
	var right := true
	for bond in want:
		for d in [1, 2]:
			SB.grant(prof, bond, d)
			right = right and SB.ring_tools(prof) == want[bond][d - 1]
	_check(right, "each bond's ring shows its depth 1 tool, then its depth 2 tools too")
	_check(SB.CAP == 5 and SB.ORDER.all(func(bd): return range(1, 6).all(func(d): return SB.RING[bd].any(func(id): return int(SB.TOOLS[id]["depth"]) == d))), "every depth from 1 to 5 is built, each with its tools")
	SB.grant(prof, "manipulator", 2)
	_check(T.ring_ready() and main.menu.climber_tabs().any(func(t): return t[0] == "core"), "with a secret bond: the tools and a Core tab")
	main.touch._layout()
	_check(main.touch.buttons.any(func(b): return b["id"] == "tools" and b["action"] == "tool_ring"), "...and a Tools button on a phone")
	# Hold to open the ring (time stops), point, let go to use.
	Input.action_press("tool_ring")
	await _until(func(): return T.ring_open, 1.0)
	_check(T.ring_open and main.slowmo and Engine.time_scale == 0.0, "holding the tool button opens the ring; time stops")
	await _frames(3)
	T.ring_index = 0
	T.dir_override = Vector2(0, -60)  # (pointing up: the first tool)
	Input.action_release("tool_ring")
	await _until(func(): return not T.ring_open, 1.0)
	_check(not T.ring_open and not main.slowmo and T.message != "", "letting go uses the pointed tool (here: nothing to aim at: %s)" % T.message)
	# A controller: LB + LT holds the ring (not parry).
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(2)
	_check(Input.is_action_pressed("tool_ring") and not Input.is_action_pressed("parry"), "LB + LT holds the tool ring on a controller")
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await _frames(2)
	main.pad._set_active(false)
	T.holding = false

	print("the Manipulator")
	var slime = await _spawn("slime", p.global_position + Vector2(150, 0))
	slime.aware = true
	# Costs: blocked when short, paid from what you carry.
	main.run_essence = {}
	main.run_flow = 0.0
	_check(not T.use("man_inspect", slime) and T.message.begins_with("Needs") and T.inspected.is_empty(), "a tool you can't pay for says what's missing (%s)" % T.message)
	main.run_essence = {"water": 10.0}
	_check(T.use("man_inspect", slime) and slime in T.inspected, "Inspect reads a monster")
	_check(is_equal_approx(float(main.run_essence.get("water", 0.0)), 10.0 - 1.0 - 1.0 * SB.SUBSTITUTE), "...paid in essence: its essence, and 3 for each Life you don't carry (%.1f left)" % float(main.run_essence.get("water", 0.0)))
	var nx: Dictionary = SB.predict(slime, slime.global_position.distance_to(p.global_position))
	_check(not slime.is_attacking() and nx.get("name", "") == "Pounce" and not nx["now"], "its next attack shows before it starts: %s" % nx.get("name", ""))
	slime.state_t = 0.0
	slime.set_physics_process(true)
	await _until(func(): return slime.state == "wind", 6.0)
	var lines: Array = SB.monster_lines(slime, slime.global_position.distance_to(p.global_position), main.floor_num, main.tower)
	_check(slime.state == "wind" and String(lines[-1]).begins_with("Now: Pounce"), "...and it is the attack it winds up: %s" % lines[-1])
	_check(String(lines[0]).begins_with("Slime") and lines.any(func(l): return String(l).begins_with("carries")), "the readout: its numbers and the essence it carries")
	slime.queue_free()
	# Calm: it ignores you until struck.
	prof.path = "life"
	main.run_flow = 5.0
	main.run_essence = {"water": 30.0}
	var kn = await _spawn("knight", p.global_position + Vector2(55, 0))
	kn.aware = true
	_check(T.use("man_calm", kn) and kn.calm, "Calm sets a monster calm")
	_check(is_equal_approx(main.run_flow, 2.0) and is_equal_approx(float(main.run_essence["water"]), 28.0), "...paid with Life you carry, then essence")
	kn.set_physics_process(true)
	var hp0: float = p.hp
	await _until(func(): return kn.is_attacking(), 1.2)
	_check(not kn.is_attacking() and p.hp == hp0, "a calm monster beside you doesn't attack")
	p._strike(kn, 1.0, Vector2.RIGHT, 0.0, false)
	_check(not kn.calm, "...until it's struck")
	await _until(func(): return kn.is_attacking(), 4.0)
	_check(kn.is_attacking(), "...then it comes for you")
	kn.queue_free()
	var champ = await _spawn("knight", p.global_position + Vector2(80, 0))
	champ.make_champion()
	_check(not T.use("man_calm", champ) and T.message == SB.TEXT["resists"] and is_equal_approx(float(main.run_essence["water"]), 28.0), "a great foe won't answer (and nothing is paid)")
	champ.queue_free()
	# Set against each other: they fight.
	var k1 = await _spawn("knight", p.global_position + Vector2(300, 0))
	var k2 = await _spawn("knight", p.global_position + Vector2(350, 0))
	main.run_essence = {"water": 40.0}
	_check(T.use("man_feud", k1) and k1.feud == k2 and k2.feud == k1 and T.feuds == 2, "Set against pairs a monster with the one nearest it")
	k1.set_physics_process(true)
	k2.set_physics_process(true)
	await _until(func(): return k1.hp < k1.max_hp or k2.hp < k2.max_hp, 6.0)
	_check(k1.hp < k1.max_hp or k2.hp < k2.max_hp, "...and they fight each other (%d, %d)" % [int(k1.hp), int(k2.hp)])
	k1.queue_free()
	k2.queue_free()
	await _frames(2)

	print("the Developer")
	SB.grant(prof, "developer", 2)
	main._give_bonds()
	main.run_essence = {"water": 40.0}
	main.run_flow = 3.0
	var b = p.bonds["hand"]
	var sp: Dictionary = b.spell()
	var rows: Array = SB.spell_numbers(b, sp)
	var row_of := func(rs: Array, name: String) -> String:
		for r in rs:
			if r[0] == name:
				return r[1]
		return ""
	_check(row_of.call(rows, "Damage") == SB._num(b.damage()) and row_of.call(rows, "Cost") == "%s essence" % SB._num(b.cost())
		and row_of.call(rows, "Wind-up") == "%s s" % SB._num(b.windup()) and row_of.call(rows, "Reach") == SB._num(float(b.stat("reach"))), "Inspect's numbers are the spell's real numbers (%s)" % [rows])
	b.flow_power = 1.3
	_check(row_of.call(SB.spell_numbers(b, sp), "Damage") == SB._num(b.damage()) and b.damage() > float(b.stat("damage")), "...with what changes them counted (%s)" % SB._num(b.damage()))
	b.flow_power = 1.0
	_check(SB.step_adds(sp).size() == sp["steps"].size() and String(SB.step_adds(sp)[1]).begins_with("Step 2"), "...and what each step adds")
	_check(T.use("dev_inspect") and T.panel == "spells" and T.paid.has("dev_inspect"), "Inspect opens the spells' panel, for the floor")
	var left: float = float(main.run_essence["water"])
	_check(T.use("dev_inspect") and T.panel == "" and float(main.run_essence["water"]) == left, "...again: closes it, free")
	_check(not T.use("dev_tune") and T.message.contains("between climbs"), "Tune waits for the train")
	await _frames(2)
	# Tune: power, cost or a quicker wind-up, paid in crystals, kept.
	var base_dmg: float = b.damage()
	var base_cost: float = b.cost()
	var base_wind: float = b.windup()
	_check(SB.set_tune(prof, sp["id"], "power") != "", "Tune needs crystal essence")
	prof.add_crystal("water", 30.0)
	_check(SB.set_tune(prof, sp["id"], "power") == "" and is_equal_approx(SB.crystals_held(prof), 30.0 - SB.TUNE_COST), "a change costs crystal essence")
	main._give_bonds()
	b = p.bonds["hand"]
	_check(is_equal_approx(b.damage(), base_dmg * SB.TUNE["power"]["power"]) and is_equal_approx(b.cost(), base_cost), "Power: more damage, the same cost")
	SB.set_tune(prof, sp["id"], "cost")
	main._give_bonds()
	b = p.bonds["hand"]
	_check(is_equal_approx(b.cost(), base_cost * SB.TUNE["cost"]["cost"]) and is_equal_approx(b.damage(), base_dmg), "Thrift: less cost")
	SB.set_tune(prof, sp["id"], "quick")
	main._give_bonds()
	b = p.bonds["hand"]
	_check(is_equal_approx(b.windup(), base_wind * SB.TUNE["quick"]["windup"]), "Quick: a quicker wind-up")
	# On the train: the Core tab's Tune buttons, and a change of path.
	prof.add_crystal("water", 40.0)
	main.on_train = true
	prof.path = "unmaking"
	prof.flow = 80.0
	main._give_bonds()
	main.menu.climber_tab = "core"
	main.menu.open("climber")
	await _frames(2)
	var tb: Button = null
	for c in main.menu.find_children("*", "Button", true, false):
		if c.has_meta("tune") and c.get_meta("tune") == [sp["id"], "power"]:
			tb = c
	_check(tb != null and not tb.disabled, "the Core tab shows Tune for each spell on the train")
	if tb != null:
		tb.pressed.emit()
		await _frames(1)
	_check(String(prof.core_tune.get(sp["id"], "")) == "power", "...a press sets it")
	var pb: Button = null
	for c in main.menu.find_children("*", "Button", true, false):
		if c.has_meta("path_change"):
			pb = c
	_check(pb != null and not pb.disabled, "the Developer can let your path go on the train")
	if pb != null:
		pb.pressed.emit()
		await _frames(1)
	_check(prof.path == "unmaking", "...a first press only asks")
	for c in main.menu.find_children("*", "Button", true, false):
		if c.has_meta("path_change"):
			c.pressed.emit()
	await _frames(1)
	_check(prof.path == "" and prof.flow == 0.0 and main.run_flow == 0.0, "...a second: all of the path's flow is gone, and a new path starts from nothing")
	_check(main.menu.find_children("*", "Control", true, false).any(func(c): return c.get_script() == load("res://scripts/secret_page.gd").Drain), "...shown flowing out of the shadow")
	main.on_train = false
	main.menu.close()
	main.menu.remove_meta("path_drain")

	print("the Designer")
	var ok: bool = await _wing_floor(true)
	_check(ok, "a floor of rooms with a secret wall")
	SB.grant(prof, "designer", 2)
	prof.path = "unmaking"
	main.run_flow = 20.0
	main.run_essence = {"water": 40.0}
	main.player.iframes = 9999.0
	_check(T.use("des_inspect") and T.panel == "plan" and T.plan_tex != null, "Inspect opens the floor's plan")
	_check(is_equal_approx(main.run_flow, 18.0), "...paid with Unmaking you carry")
	var entries: Array = SB.plan_entries(main)
	var count := func(t: String) -> int: return entries.filter(func(e): return e["type"] == t).size()
	_check(count.call("trap") == main.traps.size() and count.call("door") == main.door_view.list.size() and count.call("secret") == main.wings.secrets.size()
		and count.call("room") == main.room_info.size() and count.call("secret") > 0, "the plan lists every trap, door, secret wall and room (%d, %d, %d, %d)" % [count.call("trap"), count.call("door"), count.call("secret"), count.call("room")])
	_check(entries.filter(func(e): return e["type"] == "trap").all(func(e): return String(e["text"]).contains("warns")), "...every trap with its timing")
	var rewards: Array = ["cache", "crystal", "tithe", "gear", "spring", "camp", "forge", "oasis", "pyre", "nest", "aerie", "tidepool"]
	var told: Array = entries.map(func(e): return String(e["text"]).to_lower() + " " + String(e.get("room_text", "")).to_lower())
	_check(not told.any(func(t): return rewards.any(func(w): return t.contains(w))), "...and never a reward")
	await _frames(3)  # (the plan and the readouts draw)
	# Switch a trap off and on.
	var tr: Dictionary = main.traps.filter(func(x): return String(x.get("trigger", "")) == "timed")[0] if main.traps.any(func(x): return String(x.get("trigger", "")) == "timed") else main.traps[0]
	main.player.global_position = tr["pos"] + Vector2(160, 0)
	_check(T.use("des_switch", {"trap": tr}) and tr.get("off", false) and tr["state"] == "idle", "Switch turns a trap off")
	var tt: float = float(tr["timer"])
	await _frames(4)
	_check(float(tr["timer"]) == tt and tr["state"] == "idle", "...it rests")
	_check(T.use("des_switch", {"trap": tr}) and not tr.get("off", false), "...and on again")
	# Open and shut a door at a distance.
	var doors: Array = main.door_view.list.filter(func(d): return String(d["lock"]) == "" and String(d.get("fixed", "")) == "")
	_check(not doors.is_empty(), "the floor has an unlocked door")
	if not doors.is_empty():
		var d: Dictionary = doors[0]
		main.player.global_position = d["rect"].get_center() + Vector2(0, 200) if not main.is_solid(d["rect"].get_center() + Vector2(0, 200)) else main.player_start
		for e in main.enemies():
			e.queue_free()
		await _frames(1)
		if not d["open"]:
			_check(T.use("des_switch", {"door": d}) and d["open"], "Switch opens a door from afar")
		_check(T.use("des_switch", {"door": d}) and not d["open"] and float(d["held"]) > 0.0 and main.is_solid(d["rect"].get_center()), "...and shuts it again; it holds")
		main.player.global_position = d["rect"].get_center() + Vector2(d["out"]) * 30.0
		await _frames(3)
		_check(not d["open"], "...nobody opens a held door")
	main.run_essence = {}
	main.run_flow = 0.0
	_check(not T.use("des_switch", {"trap": tr}) and not tr.get("off", false), "with nothing to pay, nothing switches")
	T.panel = ""

	print("secret bond growth")
	SB.grant(prof, "designer", 1)
	prof.core_xp = {}
	_check(SB.on_bank(prof, {"water": 100.0}, 30.0, "unmaking").is_empty() and SB.depth_of(prof) == 1, "the Designer grows from banked Unmaking only")
	var grew: Array = SB.on_bank(prof, {}, 30.0, "unmaking")
	_check(SB.depth_of(prof) == 2 and grew.size() == 1 and String(grew[0]).contains("Switch"), "...60 banked: depth 2 (%s)" % [grew])
	grew = SB.on_bank(prof, {}, 100.0, "unmaking")
	_check(SB.depth_of(prof) == 3 and grew.size() == 1 and String(grew[0]).contains("Edit"), "...150 banked: depth 3, Edit (%s)" % [grew])
	grew = SB.on_bank(prof, {}, 320.0, "unmaking")
	_check(SB.depth_of(prof) == 5 and grew.size() == 2 and String(grew[1]).contains("Build") and SB.next_lines(prof).has(SB.TEXT["full"]), "...450: depths 4 and 5 at once (%s), and every depth reached" % [grew])
	SB.on_bank(prof, {}, 900.0, "unmaking")
	_check(SB.depth_of(prof) == 5, "...and never deeper than 5")
	SB.grant(prof, "manipulator", 1)
	SB.on_bank(prof, {}, 70.0, "unmaking")
	_check(SB.depth_of(prof) == 1, "the Manipulator doesn't grow from Unmaking")
	SB.on_bank(prof, {}, 70.0, "life")
	_check(SB.depth_of(prof) == 2, "...it grows from Life")
	SB.grant(prof, "developer", 1)
	SB.on_bank(prof, {"water": 300.0, "air": 200.0}, 10.0, "life")
	_check(SB.depth_of(prof) == 1 and SB.next_lines(prof).any(func(l): return String(l).contains("Mastery")), "the Developer needs essence of every kind and one thing more")
	for part in ["hand", "legs", "heart"]:
		prof.bonds[part] = {"id": ["stormcaller", "windwalker", "warden"][["hand", "legs", "heart"].find(part)], "xp": main.ProfileScript.STEP_XP[4], "faint": false, "debt": 0.0}
	SB.grow(prof)
	_check(SB.depth_of(prof) == 2, "...three bonds at step 5 are enough")
	prof.bonds.erase("heart")
	prof.bonds["hand"]["xp"] = 0.0
	prof.bonds["legs"]["xp"] = 0.0
	# The Core tab and the dev tools.
	main.menu.climber_tab = "core"
	main.menu.open("climber")
	await _frames(2)
	var text := ""
	for c in main.menu.find_children("*", "Label", true, false):
		text += c.text + "\n"
	for c in main.menu.find_children("*", "RichTextLabel", true, false):
		text += c.get_parsed_text() + "\n"
	_check(text.contains("Developer") and text.contains("Inspect") and text.contains("Tune") and text.contains("Growth"), "the Core tab: the bond, its depth, its tools and growth")
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return text.to_lower().contains(w)), "...in the game's own words")
	main.menu.close()
	main.menu.open("dev")
	await _frames(1)
	_check(_menu_button("Designer 2") != null and _menu_button("Clear the secret bond") != null, "the dev tools grant each secret bond at depth 1 or 2, or clear it")
	_menu_button("Manipulator 1").pressed.emit()
	await _frames(1)
	_check(SB.bond_of(prof) == "manipulator" and SB.depth_of(prof) == 1, "...and they work")
	main.menu.close()
	# Saved, and old saves load without one.
	SB.grant(prof, "developer", 2)
	prof.core_tune = {"chain_lightning": "quick"}
	prof.core_xp = {"essence": 12.0}
	var path := "user://smoke_sbond_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.core_mark == "developer" and again.core_depth == 2 and again.core_tune.get("chain_lightning", "") == "quick" and float(again.core_xp.get("essence", 0.0)) == 12.0, "the secret bond, its depth, growth and Tune are saved")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.core_mark == "" and again.core_depth == 0 and SB.bond_of(again) == "", "an old save loads with no secret bond")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	SB.clear(prof)
	main._give_bonds()
	p.iframes = 0.0


## Takes a card on the Unbound's choice: a refusal needs a second press after a moment.
func _ub_take(i: int) -> void:
	main.camp["t"] = 9.0
	main.choose_camp(i)
	if main.camp_choosing and main.camp.get("stage", "") == "unbind":
		main.choose_camp(i)


## An Unbound climber on a fresh floor: no monsters, nothing hurting.
func _ub_fresh() -> void:
	await _fresh_main()
	paused = false  # (a menu left open by an earlier test pauses the tree)
	var prof = main.profile
	main.unbound.Unbound.become(prof)
	prof.regarded = true
	main.first_climb = false
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	await _frames(2)


func _unbound_tests() -> void:
	var U = load("res://scripts/unbound.gd")
	var T = load("res://scripts/technique.gd")
	var TP = load("res://scripts/technique_page.gd")
	print("the Unbound: refusing at the Regard")
	await _fresh_main()
	paused = false
	var p = main.player
	var prof = main.profile
	for i in 5:
		main.add_soak("legs", 3.0)
	main.gather_essence("air", 30.0, p.global_position)
	main.floor_num = 3
	main._begin_regard(false)
	_check(prof.bonds.has("legs") and not main.regard.is_empty(), "the Regard marks the most-used part, as before")
	main.regard["t"] = 9.0
	main.end_regard()
	_check(main.camp_choosing and main.camp.get("stage", "") == "unbind" and main.camp["choices"] == ["unbind:accept", "unbind:refuse"], "dismissing it asks first: accept the mark, or refuse it")
	_check(main.camp_card(1)["name"] == U.TEXT["refuse_name"] and main.camp_card(0)["desc"].contains("Windwalker"), "the cards say what each choice means")
	main.camp["t"] = 0.1
	main.choose_camp(1)
	_check(main.camp_choosing and int(main.camp.get("armed", -1)) == -1, "a press in its first moment can't refuse")
	main.camp["t"] = 9.0
	main.choose_camp(1)
	_check(main.camp_choosing and int(main.camp["armed"]) == 1 and not U.is_on(prof), "the first press only arms the refusal")
	main.choose_camp(1)
	_check(U.is_on(prof) and prof.bonds.is_empty() and main.camp.get("stage", "") != "unbind", "refusing makes you Unbound and no mark is taken")
	_check(p.bonds.size() == 6 and p.bonds.values().all(func(b): return "tech" in b), "an Unbound carries six techniques, one on each mark button")
	main.camp_choosing = false
	main.camp = {}
	# Accepting changes nothing.
	await _fresh_main()
	prof = main.profile
	main.add_soak("hand", 5.0)
	main.gather_essence("blade", 20.0, main.player.global_position)
	main._begin_regard(false)
	main.regard["t"] = 9.0
	main.end_regard()
	_ub_take(0)
	_check(not U.is_on(prof) and prof.bonds.has("hand") and main.camp.get("stage", "") != "unbind", "accepting keeps the mark")
	main.camp_choosing = false
	main.camp = {}

	print("the Unbound: a broken barrier on the first climb, and the Regard refuses")
	await _fresh_main()
	paused = false
	p = main.player
	prof = main.profile
	var run = main.unbound
	_check(main.first_climb, "(a first climb)")
	await _puzzle_floor("plates", 3)
	_check(main.ward and run.barriers().any(func(b): return b["kind"] == "stair"), "a warded stair is a barrier")
	var stair: Dictionary = run.barriers().filter(func(b): return b["kind"] == "stair")[0]
	p.iframes = 9999.0
	p._equip("fists")
	p.global_position = main.stair_pos + Vector2(-p.radius - 28.0, 0)
	p.aim = Vector2.RIGHT
	await _frames(2)
	_check(not run.barrier_in_reach(p).is_empty(), "standing at it, facing it, it's in reach")
	main.run_essence = {"air": 40.0}
	var puzzles0: int = prof.count("puzzles")
	Input.action_press("attack")
	await _until(func(): return U.state(prof)["found"], 2.0)
	Input.action_release("attack")
	_check(U.state(prof)["found"] and int(run.hits.get("stair", -1)) == 0 and main.ward and not run.broke_rules, "the first barrier struck (a held strike) only shudders: the warning")
	await _frames(2)
	var hp0: float = p.hp
	_check(run.punch(stair) == "crack", "then each blow cracks it")
	_check(is_equal_approx(float(main.run_essence.get("air", 0.0)), 40.0 - run.FISTS["drain"]), "each blow drains unbanked essence (%.1f left)" % float(main.run_essence.get("air", 0.0)))
	_check(p.hp < hp0, "...and hurts your hands")
	var res := ""
	for i in 6:
		res = run.punch(stair)
		if res == "broke":
			break
	_check(res == "broke" and not main.ward and main.stair_open and main.puzzle.solved, "enough blows break it: the stair opens")
	_check(prof.count("puzzles") == puzzles0, "a punched stair isn't a solved puzzle")
	_check(float(main.run_essence.get("air", 0.0)) <= 40.0 - run.FISTS["drain"] * run.BLOWS["stair"] + 0.01, "...and gives no puzzle bonus (%.1f essence)" % float(main.run_essence.get("air", 0.0)))
	_check(run.broke_rules and not U.state(prof).has("broken"), "one barrier broken on the first climb breaks the tower's rules (no count kept)")
	# A lock-in room's shut doorway.
	var tile: Vector2i = main._tile_of(p.global_position + Vector2(0, 60))
	var lr := {"state": "armed", "gates": [[tile]], "bodies": [], "mobs": [], "t": 0.0}
	main.door_view.lock_rooms[777] = lr
	var held = await _spawn("slime", p.global_position + Vector2(200, 200))
	main.door_view._shut(lr, [held])
	var gate: Array = run.barriers().filter(func(b): return b["kind"] == "gate")
	_check(not gate.is_empty(), "a lock-in room's shut doorway is a barrier")
	main.run_essence = {"water": 20.0}
	for i in run.BLOWS["gate"]:
		res = run.punch(gate[0])
	_check(res == "broke" and lr["state"] == "done", "...and punching through opens it")
	main.door_view.lock_rooms.erase(777)
	held.queue_free()
	# The Regard: refused, no choice.
	for i in 5:
		main.add_soak("hand", 3.0)
	main.gather_essence("blade", 20.0, p.global_position)
	main.floor_num = 3
	main._begin_regard(false)
	_check(main.regard.get("refused", false) and U.is_on(prof) and prof.bonds.is_empty() and prof.regarded, "at the Regard the beast refuses to mark you: no mark, and you are Unbound")
	_check(p.bonds.size() == 6 and p.bonds.values().all(func(b): return "tech" in b), "...carrying six techniques")
	main.regard["t"] = 9.0
	main.end_regard()
	_check(not (main.camp_choosing and main.camp.get("stage", "") == "unbind"), "...and no choice is offered")
	main.camp_choosing = false
	main.camp = {}
	main.regard = {}

	print("the Unbound: a fall on the first climb with a barrier broken is refused too")
	await _fresh_main()
	main.unbound.broke_rules = true
	main._grant_regard(true)
	_check(U.is_on(main.profile) and main.profile.bonds.is_empty() and main.regard_mark.get("refused", false), "fallen, still refused: Unbound, no faint mark")

	print("the Unbound: a punched vault is empty")
	await _fresh_main()
	paused = false
	p = main.player
	prof = main.profile
	run = main.unbound
	p.iframes = 9999.0
	if await _wing_floor():
		var W = main.wings
		var w: Dictionary = W.wings[0]
		await _enter_wing(w)
		var vb: Array = run.barriers().filter(func(b): return b["kind"] == "vault")
		_check(not vb.is_empty(), "a vault's seal is a barrier")
		main.run_essence = {"fire": 30.0}
		U.state(prof)["found"] = true
		res = ""
		for i in run.BLOWS["vault"]:
			res = run.punch(vb[0])
		_check(res == "broke" and w["vault"] == "taken" and w["state"] in ["done", "idle"] and run.broke_rules, "punching it skips the room's question (and breaks the rules on a first climb)")
		p.global_position = w["pedestal"]
		await _frames(3)
		_check(not main.camp_choosing, "...and the vault is empty: nothing to choose")
		for e in main.enemies():
			e.queue_free()
		await _frames(1)
	else:
		_check(false, "found a floor with a sealed wing")

	print("the Unbound: no barrier route after the first climb")
	await _fresh_main()
	main.grant_test_bonds()
	prof = main.profile
	p = main.player
	run = main.unbound
	U.state(prof)["found"] = true
	await _puzzle_floor("plates", 3)
	var st2: Array = run.barriers().filter(func(b): return b["kind"] == "stair")
	res = ""
	for i in 8:
		res = run.punch(st2[0]) if not st2.is_empty() else ""
	_check(res == "holds" and main.ward and not run.broke_rules, "a marked climber's fists only make a barrier shudder: it holds")
	prof.soak["heart"] = prof.NEW_MARK_SOAK
	main.run_essence = {"iron": 10.0}
	main.floor_num = int(main.tower_data().get("summit", 12))
	main._arrive()
	await _frames(2)
	_check(main.camp.get("stage", "") != "unbind" and not U.is_on(prof), "a summit never offers the refusal: a marked climber can't become Unbound")
	main.camp_choosing = false
	main.camp = {}
	main.victory = {}
	U.become(prof)  # (the parts and pages below are an Unbound's)

	print("the Unbound: raw essence in the parts")
	prof.part_density = {}
	prof.path = ""
	prof.bank({"fire": 10.0, "air": 6.0}, {"hand": 5.0})
	_check(float(prof.part_density.get("brow", {}).get("fire", 0.0)) == 10.0 and float(prof.part_density.get("legs", {}).get("air", 0.0)) == 6.0, "banked essence pools in its natural part (Fire the brow, Air the legs)")
	_check(not prof.part_density.has("hand"), "...not where you used your body")
	U.route(prof, "fire", "hand")
	prof.bank({"fire": 10.0}, {})
	_check(float(prof.part_density["hand"]["fire"]) == 10.0 and float(prof.part_density["brow"]["fire"]) == 10.0, "routing sends a kind to another part from then on")
	var raw_heart: float = U.raw(prof, "heart")
	prof.path = "life"
	prof.flow = 30.0
	_check(U.PARTS.all(func(pt): return U.raw(prof, pt) >= 30.0) and U.raw(prof, "heart") == raw_heart + 30.0, "the path's essence flows through every part")
	_check(U.level_for(0.0) == 1 and U.level_for(U.LEVELS[3]) == 4 and U.level_for(99999.0) == 10, "levels 1 to 10 from raw density")
	prof.part_density = {"hand": {"blade": 3300.0}}
	prof.flow = 0.0
	_check(U.stage_name(prof) == "Unbound" and U.stage(prof) == 10, "the stages, by total raw density: the last is Unbound")
	prof.part_density = {}
	_check(U.stage_name(prof) == "Stir", "...the first is Stir")
	prof.path = ""

	print("the Unbound: building techniques")
	var t := {"name": "", "part": "throat", "shape": "shout", "kinds": ["fire", "air"]}
	var desc: String = T.describe(t)
	_check(desc.begins_with("A shout in a cone") and desc.contains("burns") and desc.contains("a little reaches farther"), "a part and essences: the part gives the shape, the first leads, the others flavour (%s)" % desc)
	var cost: Dictionary = T.cost(t)
	_check(is_equal_approx(cost["fire"], T.COST[1] * 2.0 / 3.0) and is_equal_approx(cost["air"], T.COST[1] / 3.0), "a boost is paid in those essences, the lead counting double")
	_check(T.charge(t) > T.charge({"part": "throat", "shape": "shout", "kinds": ["fire"]}), "more kinds take more filling")
	_check(T.strain(t) > T.strain({"part": "throat", "shape": "shout", "kinds": ["fire"]}), "every extra kind adds strain")
	var one := {"name": "", "part": "hand", "shape": "bolt", "kinds": ["fire"]}
	_check(TP.cycle_gem(prof, one, 1)["kinds"].size() == 1, "at level 1 a part combines one essence")
	prof.part_density = {"hand": {"blade": U.LEVELS[U.KINDS_AT[1] - 1]}}
	var two: Dictionary = TP.cycle_gem(prof, one, 1)
	_check(two["kinds"].size() == 2 and two["kinds"][1] != "fire" and TP.cycle_gem(prof, two, 2)["kinds"].size() == 2, "at level %d two, not yet three" % U.KINDS_AT[1])
	_check(TP.cycle_gem(prof, one, 0)["kinds"][0] != "fire", "tapping a gem cycles its essence")
	_check(not ("life" in U.kinds_for(prof)) and not ("unmaking" in U.kinds_for(prof)), "without a path, no secret essence to build with")
	prof.path = "unmaking"
	_check("unmaking" in U.kinds_for(prof) and not ("life" in U.kinds_for(prof)), "only your own path's secret essence")
	prof.path = ""
	var sh: Dictionary = TP.cycle_shape(prof, one)
	_check(sh["part"] == "legs" and sh["shape"] == "dash" and sh["kinds"].size() == 1, "tapping the part cycles its shape (and part)")

	print("the Unbound: casting, filling, boosting and strain")
	await _ub_fresh()
	p = main.player
	prof = main.profile
	run = main.unbound
	p.iframes = 9999.0
	run.waver_chance = 0.0
	main.touch._layout()
	_check(main.touch.buttons.filter(func(b): return String(b["id"]).begins_with("cast_")).size() == 6, "six cast buttons on a phone")
	var slime = await _spawn("slime", p.global_position + Vector2(36, 0))
	slime.hp = 999.0
	slime.max_hp = 999.0
	U.state(prof)["techs"][0] = T.recipe("rending_strike")
	main._give_bonds()
	var hb = p.bonds["hand"]
	_check(hb.essence == 0.0 and hb.essence < hb.cost(), "a technique starts empty, like a mark")
	var fills := 0
	while hb.essence < hb.capacity() and fills < 40:
		p._part_action("hand", 0.5, 6.0)  # (a weapon strike landing)
		fills += 1
	_check(hb.essence >= hb.cost() and fills > 1, "the hand's strikes fill a hand technique (%d strikes to %d)" % [fills, int(hb.capacity())])
	p._part_action("legs", 4.0, 10.0)
	_check(p.bonds["legs"].essence > 0.0 and p.bonds["heart"].essence == 0.0, "each part's actions fill its own techniques")
	p.aim = Vector2.RIGHT
	main.run_essence = {}
	main.run_flow = 0.0
	p.attack_cd = 0.0
	p._try_cast("hand")
	await _until(func(): return run.strain_of("hand") > 0.0, 2.0)
	var cold: float = 999.0 - slime.hp
	_check(is_equal_approx(run.strain_of("hand"), T.STRAIN[0]) and cold > 0.0 and run.boosts == 0, "full, it casts with no essence carried: it strains its part (%d) and hits (%.0f)" % [run.strain_of("hand"), cold])
	_check(p.bonds["hand"].essence < 0.01, "...and the cast takes its fill")
	# Carried essence boosts a cast, and is spent.
	run.dots.clear()
	slime.hp = 999.0
	run.strain["hand"] = 0.0
	p.bonds["hand"].essence = p.bonds["hand"].capacity()
	main.run_essence = {"blade": 10.0}
	run.cast(p.bonds["hand"], p)
	var boosted: float = 999.0 - slime.hp
	_check(run.boosts == 1 and is_equal_approx(float(main.run_essence.get("blade", 0.0)), 10.0 - T.COST[0]) and boosted > cold * 1.3, "carrying its essence, a cast spends it and hits harder (%.0f vs %.0f)" % [boosted, cold])
	_check(is_equal_approx(run.strain_of("hand"), T.STRAIN[0]), "...a boost adds no strain")
	U.state(prof)["boost"] = false
	run.dots.clear()
	p.bonds["hand"].essence = p.bonds["hand"].capacity()
	run.cast(p.bonds["hand"], p)
	_check(run.boosts == 1 and is_equal_approx(float(main.run_essence.get("blade", 0.0)), 10.0 - T.COST[0]), "switched off, carried essence is kept")
	U.state(prof)["boost"] = true
	# Cast before it's full: more strain.
	run.dots.clear()
	run.strain["hand"] = 0.0
	p.bonds["hand"].essence = 0.0
	main.run_essence = {}
	run.cast(p.bonds["hand"], p)
	_check(is_equal_approx(run.strain_of("hand"), T.STRAIN[0] + T.EMPTY_STRAIN), "cast empty, the missing fill adds strain (%.0f)" % run.strain_of("hand"))
	run.dots.clear()
	slime.hp = 999.0
	run.strain["hand"] = 75.0
	p.bonds["hand"].essence = p.bonds["hand"].capacity()
	run.cast(p.bonds["hand"], p)
	var hot: float = 999.0 - slime.hp
	_check(hot > cold * 1.1, "above %d it hits harder (%.0f vs %.0f)" % [run.HOT, hot, cold])
	run.dots.clear()
	slime.hp = 999.0
	run.waver_chance = 1.0
	run.strain["hand"] = 75.0
	p.aim = Vector2.RIGHT
	p.bonds["hand"].essence = p.bonds["hand"].capacity()
	run.cast(p.bonds["hand"], p)
	_check(999.0 - slime.hp < hot * 0.75, "...but it may waver")
	run.waver_chance = 0.0
	run.dots.clear()
	# Strain fades while you don't cast from the part.
	run.strain["hand"] = 50.0
	run.idle["hand"] = run.STRAIN_REST
	await _until(func(): return run.strain_of("hand") < 47.0, 2.0)
	_check(run.strain_of("hand") < 47.0, "strain fades while you don't cast")
	p.bonds["hand"].essence = 3.0
	main._give_bonds()
	_check(is_equal_approx(p.bonds["hand"].essence, 3.0), "a technique keeps its fill when the climber's bonds are rebuilt (a stair)")
	# 100: it erupts.
	p.hp = p.max_health()
	var hp1: float = p.hp
	run.strain["hand"] = 95.0
	p.bonds["hand"].essence = p.bonds["hand"].capacity()
	run.cast(p.bonds["hand"], p)
	_check(run.is_dark("hand") and p.hp < hp1 - p.max_health() * 0.4 and not p.dead, "at 100 it erupts: badly hurt, the part dark")
	_check(p.bonds["hand"].blocked(), "...nothing from it can be cast")
	p.attack_cd = 0.0
	_check(p._try_cast("hand") and p.cast_t <= 0.0, "...pressing its button does nothing")
	_check(run.glow.has("hand"), "...and raw essence shows on the part")
	p.hp = 10.0
	run.add_strain("legs", 100.0)
	_check(p.dead, "an eruption can kill")
	await _frames(2)

	print("the Unbound: the Developer goes back")
	await _ub_fresh()
	prof = main.profile
	prof.part_density = {"heart": {"iron": 200.0}, "hand": {"blade": 40.0}}
	_check(not U.can_return(prof), "being Unbound is for good")
	prof.core_mark = "developer"
	prof.core_depth = 1
	_check(U.can_return(prof), "...unless you hold the Developer")
	var got: Dictionary = U.return_to_marks(prof)
	_check(not U.is_on(prof) and prof.bonds.has("heart") and got["part"] == "heart", "the beasts mark you again: raw essence settles into a bond on the densest part (%s)" % got.get("id", ""))
	_check(float(prof.soak.get("hand", 0.0)) > 0.0, "...and the rest makes later marks come sooner")
	prof.core_mark = ""
	prof.core_depth = 0

	print("the Unbound: condensing at a summit")
	await _ub_fresh()
	prof = main.profile
	# Once Unbound: raw essence, from a step away, costs essence and doesn't hurt.
	p = main.player
	run = main.unbound
	var tile2: Vector2i = main._tile_of(p.global_position + Vector2(0, 80))
	var lr2 := {"state": "armed", "gates": [[tile2]], "bodies": [], "mobs": [], "t": 0.0}
	main.door_view.lock_rooms[778] = lr2
	var held2 = await _spawn("slime", p.global_position + Vector2(200, 200))
	main.door_view._shut(lr2, [held2])
	var g2: Dictionary = run.barriers().filter(func(b): return b["kind"] == "gate")[0]
	p.aim = Vector2.DOWN
	p._equip("fists")
	_check(not run.barrier_in_reach(p).is_empty(), "the Unbound reach a barrier from a step away")
	main.run_essence = {"stone": 20.0}
	var hp2: float = p.hp
	_check(run.punch(g2) == "crack" and p.hp == hp2 and is_equal_approx(float(main.run_essence.get("stone", 0.0)), 20.0 - run.FISTS["raw_cost"]) and int(run.hits[g2["id"]]) == run.FISTS["raw_blows"], "raw essence: it costs essence, not health, and cracks faster")
	main.door_view.lock_rooms.erase(778)
	held2.queue_free()
	main.floor_num = int(main.tower_data().get("summit", 12))
	main._arrive()
	await _frames(2)
	_check(main.camp_choosing and main.camp.get("stage", "") == "condense" and main.camp["choices"].size() == 6 and prof.bonds.is_empty(), "at a summit the Unbound take no mark: they choose a part to condense into")
	var kind: String = main.tower_data().get("essence", "air")
	main.choose_camp(2)
	_check(float(prof.part_density.get(U.PARTS[2], {}).get(kind, 0.0)) == U.CONDENSE and not main.victory.is_empty(), "the tower's essence condenses there, then the victory")
	main.victory = {}

	print("the Unbound: pages")
	main.on_train = true
	main.menu.open("techniques")
	await _frames(2)
	var gem: Button = null
	for b in main.menu.focusables():
		if b.get_meta("tech_gem", -1) == 0:
			gem = b
	var before: String = String(U.state(prof)["techs"][0]["kinds"][0])
	var found_gem := gem != null
	if found_gem:
		gem.pressed.emit()
		await _frames(2)
	_check(found_gem and String(U.state(prof)["techs"][0]["kinds"][0]) != before, "the technique page: tapping a gem changes it")
	main.menu.open("climber")
	await _frames(2)
	_check(main.menu._climber_line().begins_with("Unbound") and main.menu._climber_line().contains(U.stage_name(prof)), "the climber screen shows the stage")
	main.menu.close()
	main.on_train = false

	print("the Unbound: saved")
	var path := "user://smoke_unbound_test.cfg"
	U.state(prof)["boost"] = false
	prof.unbound["broken"] = 2  # (an old save's barrier count)
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(U.is_on(again) and not U.state(again)["boost"] and T.valid(U.state(again)["techs"][1]), "the Unbound, their techniques and the boost switch are saved")
	_check(not U.state(again).has("broken"), "an old save's barrier count is dropped")
	U.state(prof)["boost"] = true
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "bonds", {"hand": {"id": "stormcaller", "xp": 0.0, "faint": false, "debt": 0.0}})
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(not U.is_on(again) and again.bonds.has("hand") and not U.state(again).has("broken") and U.state(again)["boost"], "an old save loads as a marked climber")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH


## An open spot to tear a rift from whose plan `pred` likes (outside `avoid`):
## {pos, plan}, or {} if none of a sample of the floor's open tiles will do.
func _rift_start(R, pred: Callable, avoid: Rect2) -> Dictionary:
	var gs: Vector2i = main.grid_size
	var open: Array = []
	for y in range(2, gs.y - 2, 2):
		for x in range(2, gs.x - 2, 2):
			if not main._is_solid_tile(x, y):
				open.append(Vector2i(x, y))
	open.shuffle()
	for t in open.slice(0, 160):
		var pos: Vector2 = R._center(t)
		if avoid.size != Vector2.ZERO and avoid.has_point(pos):
			continue
		var pl: Dictionary = R.plan_from(pos)
		if R.worth(pl) and pred.call(pl):
			return {"pos": pos, "plan": pl}
	return {}


## The floor a rift tore is whole: solid nowhere on it (and off the path grid),
## no wall collision over it, and rock it bared has collision of its own.
func _rift_ok(R) -> bool:
	var C: float = main.Floors.CELL
	var rects: Array = []
	for b in main.layout_bodies:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and b.get_child_count() > 0 and b.get_child(0).shape is RectangleShape2D:
			var sh: RectangleShape2D = b.get_child(0).shape
			rects.append(Rect2(b.position - sh.size * 0.5, sh.size))
	for t in R.tiles:
		if main._is_solid_tile(t.x, t.y) or main.astar.is_point_solid(t):
			return false
		var c: Vector2 = R._center(t)
		if rects.any(func(r): return r.has_point(c)):
			return false
	for t in R.torn:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if R.tiles.has(n) or not main._is_solid_tile(n.x, n.y) or n.x < 0 or n.y < 0 or n.x >= main.grid_size.x or n.y >= main.grid_size.y or R._owned(n):
				continue
			var c2: Vector2 = main.room.position + (Vector2(n) + Vector2(0.5, 0.5)) * C
			if not rects.any(func(r): return r.has_point(c2)):
				return false
	return true


## The index of a card the secret tools show (by its id), or -1.
func _sb_card(id: String) -> int:
	var D = main.secret_tools.deep
	for i in D.cards.size():
		if String(D.cards[i].get("id", "")) == id:
			return i
	return -1


## A floor of rooms with a timed trap room, its monsters gone.
func _sb_trap_floor() -> bool:
	for n in 40:
		main._start_floor(4 + n % 4)
		await _frames(1)
		if main.traps.any(func(t): return String(t.get("trigger", "")) == "timed" and int(t.get("room", -1)) >= 0):
			await _clear_foes()
			main.banner = {}
			return true
	return false


## The secret bonds' depth 3 to 5 tools (secret_deep.gd): every tool works
## and is paid for, its limits hold, the tower stays safe, growth and saving.
func _secret_deep_tests() -> void:
	print("the secret bonds, depths 3 to 5")
	await _fresh_main()
	main.grant_test_bonds()
	var SB = load("res://scripts/secret_bonds.gd")
	var Tr = load("res://scripts/traps.gd")
	var T = main.secret_tools
	var D = T.deep
	var p = main.player
	var prof = main.profile
	await _clear_foes()
	p.mouse_aim = false
	p.iframes = 9999.0
	var right := true
	for bond in SB.ORDER:
		SB.grant(prof, bond, 5)
		right = right and SB.ring_tools(prof) == SB.RING[bond]
		SB.grant(prof, bond, 3)
		right = right and SB.ring_tools(prof).size() == SB.RING[bond].size() - 2
	_check(right, "the ring gains a tool at each of depths 3, 4 and 5")

	print("the Developer's Edit")
	SB.grant(prof, "developer", 3)
	prof.crystals = []
	main._give_bonds()
	var b = p.bonds["hand"]
	var sp: Dictionary = b.spell()
	var reach0: float = float(b.stat("reach"))
	var dmg0: float = b.damage()
	_check(SB.set_edit(prof, sp["id"], "reach", 1) == SB.TEXT["edit_lower_first"], "Edit: a number only rises when another falls")
	_check(SB.set_edit(prof, sp["id"], "power", -1) == "", "...lowering one is free")
	_check(SB.set_edit(prof, sp["id"], "reach", 1) != "", "...raising one costs crystal essence")
	prof.add_crystal("water", 20.0)
	_check(SB.set_edit(prof, sp["id"], "reach", 1) == "" and is_equal_approx(SB.crystals_held(prof), 20.0 - SB.EDIT_COST), "...paid from crystals")
	_check(SB.set_edit(prof, sp["id"], "reach", 1) == SB.TEXT["edit_lower_first"], "...and the budget holds (points add up to zero)")
	main._give_bonds()
	b = p.bonds["hand"]
	_check(is_equal_approx(float(b.stat("reach")), reach0 * (1.0 + SB.EDIT_POINT)) and is_equal_approx(b.damage(), dmg0 * (1.0 - SB.EDIT_POINT)), "more reach for less damage (%.1f, %.1f)" % [float(b.stat("reach")), b.damage()])
	var rows: Array = SB.spell_numbers(b, sp)
	_check(rows.any(func(r): return r[0] == "Reach" and r[1] == SB._num(reach0 * (1.0 + SB.EDIT_POINT))), "...shown in Inspect's numbers")
	main.on_train = true
	main.menu.climber_tab = "core"
	main.menu.open("climber")
	await _frames(2)
	var eb: Button = null
	for c in main.menu.find_children("*", "Button", true, false):
		if c.has_meta("edit") and c.get_meta("edit") == [sp["id"], "speed", -1]:
			eb = c
	_check(eb != null and not eb.disabled, "the Core tab edits each spell on the train")
	if eb != null:
		eb.pressed.emit()
		await _frames(1)
	_check(int(prof.core_edit.get(sp["id"], {}).get("speed", 0)) == -1, "...a press moves a point")
	main.on_train = false
	main.menu.close()

	print("the Developer's Splice")
	SB.grant(prof, "developer", 4)
	main._give_bonds()
	prof.path = ""
	main.run_flow = 0.0
	main.run_essence = {"water": 100.0}
	_check(T.use("dev_splice") and main.camp_choosing and main.camp["stage"] == "secret" and D.cards_tool == "splice1", "Splice opens its cards: which spell")
	main.choose_camp(_sb_card("hand"))
	_check(D.cards_tool == "dev_splice" and float(main.run_essence["water"]) == 100.0, "...then whose behaviour (nothing paid yet)")
	main.choose_camp(_sb_card("legs"))
	var paid1: float = 100.0 - float(main.run_essence.get("water", 0.0))
	_check(not main.camp_choosing and D.splice.get("effect", "") == SB.splice_effect("windwalker") and paid1 > 0.0, "...a mark's card splices it, paid (%.0f essence)" % paid1)
	var slime = await _spawn("slime", p.global_position + Vector2(150, 0))
	b = p.bonds["hand"]
	b.essence = 999.0
	p.aim = Vector2.RIGHT
	p.cast_part = "hand"
	p._release_cast()
	_check(D.splices >= 1 and slime.knock.x > 0.0, "a spliced Chain Lightning also throws back what it strikes (%d, %.0f)" % [D.splices, slime.knock.x])
	T.use("dev_splice")
	main.choose_camp(_sb_card("hand"))
	main.choose_camp(_sb_card("legs"))
	_check(D.splice.get("part", "") == "hand" and 100.0 - float(main.run_essence.get("water", 0.0)) > paid1 * 1.5, "one splice at a time: a new one replaces it, paid again")
	var left: float = float(main.run_essence.get("water", 0.0))
	T.use("dev_splice")
	main.choose_camp(D.cards.size() - 1)
	_check(not main.camp_choosing and float(main.run_essence.get("water", 0.0)) == left, "...Leave it closes the cards, nothing paid")
	slime.queue_free()

	print("the Developer's Write")
	SB.grant(prof, "developer", 5)
	main.run_essence = {"water": 200.0}
	var foe = await _spawn("slime", p.global_position + Vector2(60, 0))
	foe.max_hp = 999.0
	foe.hp = 999.0
	_check(T.use("dev_write") and D.cards_tool == "write1" and _sb_card("water") >= 0, "Write offers the essences of bonds you don't hold")
	main.choose_camp(_sb_card("water"))
	main.choose_camp(_sb_card("tidecaller"))
	_check(D.cards_tool == "dev_write" and _sb_card("tidal_surge") >= 0 and _sb_card("riptide") < 0, "...a bond's spells at your best step (step 1: %d cards)" % D.cards.size())
	main.choose_camp(_sb_card("tidal_surge"))
	_check(D.once.has("dev_write") and foe.hp < 999.0 and float(main.run_essence.get("water", 0.0)) < 200.0, "...casts a spell you don't have, paid (%.0f)" % foe.hp)
	_check(not T.use("dev_write") and T.message == SB.TEXT["once_floor"], "Write: once a floor")
	foe.queue_free()
	# Moving marks on the train.
	main.on_train = true
	prof.add_crystal("water", 40.0)
	_check(SB.move_mark(prof, "legs", "heart") == "" and prof.bonds.has("heart") and not prof.bonds.has("legs") and prof.bonds["heart"]["id"] == "windwalker", "Write moves a mark to a free body part on the train")
	_check(SB.move_mark(prof, "heart", "hand") == "" and prof.bonds["hand"]["id"] == "windwalker" and prof.bonds["heart"]["id"] == "stormcaller", "...or swaps two")
	main.menu.climber_tab = "core"
	main.menu.open("climber")
	await _frames(2)
	var mb: Button = null
	for c in main.menu.find_children("*", "Button", true, false):
		if c.has_meta("move_mark") and c.get_meta("move_mark") == ["heart", "legs"]:
			mb = c
	_check(mb != null and not mb.disabled, "...from the Core tab")
	if mb != null:
		mb.pressed.emit()
		await _frames(1)
	main._give_bonds()
	_check(p.bonds.has("legs") and p.bonds["legs"].id == "stormcaller" and not p.bonds.has("heart"), "...and the bond goes with it")
	SB.move_mark(prof, "hand", "heart")
	SB.move_mark(prof, "legs", "hand")
	SB.move_mark(prof, "heart", "legs")
	main.on_train = false
	main.menu.close()

	print("the Developer's bribe")
	SB.grant(prof, "developer", 2)
	prof.core_xp = {"essence": 1000.0}
	prof.crystals = []
	prof.add_crystal("water", 130.0)
	SB.grow(prof)
	_check(SB.depth_of(prof) == 2, "depth 3 waits for one thing more than essence")
	SB.bribe_force = 0
	var res: Dictionary = SB.offer_bribe(prof, "crystals", main.Gear)
	_check(not res["ok"] and is_equal_approx(SB.crystals_held(prof), 130.0) and int(SB.bribe_state(prof).get("refused", 0)) == 1, "the Maker of Marks may refuse a bribe: nothing taken, remembered")
	SB.bribe_force = 1
	res = SB.offer_bribe(prof, "crystals", main.Gear)
	_check(res["ok"] and is_equal_approx(SB.crystals_held(prof), 10.0) and int(SB.bribe_state(prof).get("for", 0)) == 3, "...or take it: it counts for the next depth")
	SB.grow(prof)
	_check(SB.depth_of(prof) == 3 and not SB.also_status(prof)["bribe"][0], "...which it grants (and the bribe is spent)")
	prof.chest.append(main.Gear.make("cloth_hood", "regarded"))
	var offers: Array = SB.bribe_offers(prof, main.Gear)
	_check(offers.any(func(o): return String(o["id"]).begins_with("chest:") and o["ok"]) and offers.any(func(o): return o["id"] == "vessel" and not o["ok"]), "a Regarded piece can be offered (a vessel is greyed with none in the chest)")
	res = SB.offer_bribe(prof, "chest:%d" % (prof.chest.size() - 1), main.Gear)
	_check(res["ok"] and not prof.chest.any(func(g): return main.Gear.rarity(g) == "regarded"), "...and is taken when accepted")
	SB.bribe_force = -1
	_check(SB.bribe_odds(prof) < float(SB.BRIBE["agree"]), "...each bribe makes the next less likely (%.2f)" % SB.bribe_odds(prof))
	main.on_train = true
	prof.makers["bribe"]["for"] = 0
	main.menu.climber_tab = "core"
	main.menu.open("climber")
	await _frames(2)
	_check(main.menu.find_children("*", "Button", true, false).any(func(c): return c.has_meta("bribe")), "the Core tab offers a bribe on the train")
	main.on_train = false
	main.menu.close()

	print("the Designer's Edit")
	var ok: bool = await _sb_trap_floor()
	_check(ok, "a floor of rooms with a timed trap room")
	SB.grant(prof, "designer", 5)
	prof.path = "unmaking"
	main.run_flow = 200.0
	main.run_essence = {"water": 300.0}
	var hard0: int = Tr.hard_tiles(main.traps).size()
	var tr: Dictionary = main.traps.filter(func(t): return String(t.get("trigger", "")) == "timed" and int(t.get("room", -1)) >= 0)[0]
	var room := int(tr["room"])
	var cyc: float = Tr.val(tr, "cycle")
	p.global_position = tr["pos"] + Vector2(0, 120) if not main.is_solid(tr["pos"] + Vector2(0, 120)) else tr["pos"]
	var flow0: float = main.run_flow
	_check(T.use("des_edit", {"trap": tr}) and _sb_card("retime") >= 0, "Edit offers to re-time the trap room you aim at")
	main.choose_camp(_sb_card("retime"))
	_check(D.retimed.has(room) and is_equal_approx(Tr.val(tr, "cycle"), cyc * SB.RETIME) and main.run_flow < flow0, "...its beat slows, paid with Unmaking")
	_check(Tr.hard_tiles(main.traps).size() <= hard0, "...and it stays crossable by timing (%d hard tiles, %d before)" % [Tr.hard_tiles(main.traps).size(), hard0])
	var movable: Array = main.traps.filter(func(t): return Tr.KINDS[t["kind"]]["shape"] != "lane" and not t.get("own", false))
	var moved_ok := true
	var moved_any := false
	var why_not := ""
	for t2 in movable:
		if moved_any:
			break
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var from: Vector2 = t2["pos"]
			if moved_any:
				break
			if D.move_trap(t2, dv) == "":
				why_not = "%s -> %s, %d hard" % [from, t2["pos"], Tr.hard_tiles(main.traps).size()]
				moved_any = true
				var steps: float = from.distance_to(t2["pos"]) / Tr.C
				moved_ok = moved_ok and steps <= SB.MOVE_TILES + 0.01 and not main.is_solid(t2["pos"]) and Tr.hard_tiles(main.traps).size() <= hard0
	_check(moved_any and moved_ok, "Move shifts a trap up to %d tiles to open floor, never leaving a tile with no safe moment (%d traps, %s)" % [SB.MOVE_TILES, movable.size(), why_not])
	# Raise and sink walls.
	var spot := Vector2.ZERO
	for info in main.room_info:
		var c: Vector2 = info["rect"].get_center()
		if not main.is_solid(c) and info["rect"].size.x >= 6 * Tr.C:
			var ctx: Dictionary = D._trap_ctx()
			p.global_position = c + Vector2(-2.5 * Tr.C, 0)
			p.aim = Vector2.RIGHT
			if not D._stretch(SB.RAISE_AHEAD, SB.RAISE_LEN, ctx).is_empty():
				spot = p.global_position
				break
	_check(spot != Vector2.ZERO, "an open room to raise a wall in")
	p.aim = Vector2.RIGHT
	var tiles: Array = D._stretch(SB.RAISE_AHEAD, SB.RAISE_LEN, D._trap_ctx())
	var could: Array = D._reachable(D._goals())
	_check(D.raise_wall(SB.WALL_TIME, "raise") == "" and main._is_solid_tile(tiles[0].x, tiles[0].y) and main.astar.is_point_solid(tiles[0]), "Raise: a stretch of wall rises (solid for bodies, sight and paths)")
	var can: Array = D._reachable(D._goals())
	_check(range(could.size()).all(func(i): return can[i] or not could[i]), "...never shutting the stair away (%s, %s)" % [could, can])
	D.walls[-1]["t"] = 0.05
	await _until(func(): return D.walls.is_empty(), 1.0)
	_check(D.walls.is_empty() and not main._is_solid_tile(tiles[0].x, tiles[0].y), "...and sinks again in time (%d walls)" % D.walls.size())
	var sealed: Array = D._sealed_areas()
	var safe := true
	var thin: Array = []
	var gs: Vector2i = main.grid_size
	for y in gs.y:
		for x in gs.x:
			for dv in [Vector2i(1, 0), Vector2i(0, 1)]:
				var t3 := Vector2i(x, y)
				var run: Array = D.sinkable(t3, dv) if main._is_solid_tile(x, y) else []
				if run.is_empty():
					continue
				thin.append([t3, dv, run])
				for w in run + [run[-1] + dv]:
					var edge: bool = w.x < 1 or w.y < 1 or w.x > gs.x - 2 or w.y > gs.y - 2
					safe = safe and run.size() <= SB.SINK_THICK and not (edge and w in run) and not sealed.any(func(r): return r.has_point(D._tile_center(w)))
	_check(safe, "Sink never opens the outer wall, a sealed wing, a secret room or the puzzle's room (%d thin walls)" % thin.size())
	if not thin.is_empty():
		var t4: Vector2i = thin[0][0]
		var d4: Vector2i = thin[0][1]
		p.global_position = D._tile_center(t4 - d4)
		p.aim = Vector2(d4)
		var run4: Array = D.sink_tiles()
		_check(run4 == thin[0][2] and D.sink_wall(run4) == "" and not main._is_solid_tile(t4.x, t4.y), "Sink: a thin wall in front of you opens (%d tiles)" % run4.size())
		D.walls[-1]["t"] = 0.05
		p.global_position = D._tile_center(t4 - d4 * 2)
		await _until(func(): return D.walls.is_empty(), 1.0)
		_check(main._is_solid_tile(t4.x, t4.y), "...and closes again")

	print("the Designer's Reroll")
	p.global_position = main.stair_pos + Vector2(0, 400)
	_check(not T.use("des_reroll") and T.message == SB.TEXT["reroll_far"], "Reroll is used at the stair")
	p.global_position = main.stair_pos + Vector2(0, 60)
	_check(T.use("des_reroll") and D.cards_tool == "reroll1" and D.cards.size() == 3, "...two puzzles to choose from")
	var pz: String = D.cards[0]["id"]
	main.choose_camp(0)
	_check(D.cards_tool == "des_reroll" and D.cards.size() == 3, "...then two leans for the rooms")
	var lean: String = D.cards[1]["id"]
	main.choose_camp(1)
	_check(D.reroll_next.get("puzzle", "") == pz and D.reroll_next.get("lean", "") == lean and D.once.has("des_reroll"), "...the choice waits for the next floor")
	_check(not T.use("des_reroll") and T.message == SB.TEXT["once_floor"], "...once a floor")
	var nxt: int = main.floor_num + 1
	main._start_floor(nxt)
	await _frames(1)
	_check(D.lean_used.get("got", "") == pz and D.lean_used.get("lean", "") == lean and D.reroll_next.is_empty() and load("res://scripts/themes.gd").lean.is_empty(), "the next floor is planned with the chosen puzzle (%s) and lean (%s)" % [D.lean_used.get("got", ""), lean])
	main.floor_num = 11
	_check(not D.next_rerollable(), "...never the summit's floor")
	main.floor_num = nxt

	print("the Designer's Build")
	await _clear_foes()
	main.run_flow = 200.0
	main.run_essence = {"water": 300.0}
	var spot2 := Vector2.ZERO
	for info in main.room_info:
		var c2: Vector2 = info["rect"].get_center()
		p.global_position = c2 + Vector2(-2.5 * Tr.C, 0)
		p.aim = Vector2.RIGHT
		if not main.is_solid(p.global_position) and not D._stretch(SB.BUILD_AHEAD, SB.RAISE_LEN, D._trap_ctx()).is_empty():
			spot2 = p.global_position
			break
	_check(spot2 != Vector2.ZERO, "an open room to build in")
	var n_traps: int = main.traps.size()
	_check(T.use("des_build") and _sb_card("trap") >= 0 and _sb_card("rift") >= 0, "Build offers a trap, a wall, a gate and a rift")
	main.choose_camp(_sb_card("trap"))
	var own: Array = main.traps.filter(func(t): return t.get("own", false))
	_check(main.traps.size() == n_traps + 1 and own.size() == 1 and D.builds == 1, "...a trap of your own")
	if not own.is_empty():
		p.global_position = own[0]["pos"]
		var stepped_me: bool = main.trap_view._stepped_on(own[0])
		var mon = await _spawn("slime", own[0]["pos"])
		var stepped_it: bool = main.trap_view._stepped_on(own[0])
		mon.queue_free()
		_check(not stepped_me and stepped_it, "...that only monsters set off")
	var gate_ok := false
	for info in main.room_info:
		for off in [Vector2(-2.5 * Tr.C, Tr.C), Vector2(-2.5 * Tr.C, -Tr.C), Vector2(-1.5 * Tr.C, 0)]:
			p.global_position = info["rect"].get_center() + off
			p.aim = Vector2.RIGHT
			if not gate_ok and not main.is_solid(p.global_position):
				gate_ok = D.build("gate") == ""
	_check(gate_ok and D.gates.size() == 1 and D.gates[0]["body"].collision_layer == 8 and main.astar.is_point_solid(D.gates[0]["tiles"][0]), "a gate: monsters can't pass (and go around); you can")
	for info in main.room_info:
		if D.builds >= SB.BUILD_MAX:
			break
		p.global_position = info["rect"].get_center() + Vector2(0, Tr.C)
		p.aim = Vector2.LEFT
		if not main.is_solid(p.global_position):
			D.build("wall")
	_check(D.builds == SB.BUILD_MAX and D.build("wall") == SB.TEXT["build_max"], "builds are limited to %d a floor (%d built)" % [SB.BUILD_MAX, D.builds])
	print("the Designer's rift")
	var R = D.rift
	var far: Dictionary = _rift_start(R, func(pl): return pl["tiles"].keys().filter(func(t): return main._is_solid_tile(t.x, t.y)).size() >= 8, Rect2())
	if not far.is_empty():
		spot2 = far["pos"]  # (somewhere with plenty of rock between it and the stair)
	p.global_position = spot2
	var a0: Vector2i = main._tile_of(spot2)
	var s0: Vector2i = main._tile_of(main.stair_pos)
	var pl0: Dictionary = R.plan_from(spot2)
	var rock0: int = pl0["tiles"].keys().filter(func(t): return main._is_solid_tile(t.x, t.y)).size()
	_check(rock0 > 0 or R.worth(pl0), "(the stair lies through rock from here: %d tiles)" % rock0)
	_check(D.build("rift") == "" and D.rift_used and not R.tiles.is_empty(), "a rift tears through the floor to the stair (%d tiles, %d of them rock)" % [R.tiles.size(), R.torn.size()])
	_check(_rift_ok(R), "...solid nowhere along it, no wall's collision on it, and rock beside it has its own")
	var way: Array = main.astar.get_id_path(a0, s0)
	_check(not way.is_empty(), "...and the path grid walks it to the stair (%d steps)" % way.size())
	var gsz: Vector2i = main.grid_size
	_check(R.tiles.keys().all(func(t): return t.x >= 1 and t.y >= 1 and t.x <= gsz.x - 2 and t.y <= gsz.y - 2), "...never the floor's outer wall")
	_check(D.build("rift") == SB.TEXT["once_climb"], "once a climb")
	main._start_floor(main.floor_num + 1)
	await _frames(1)
	_check(R.tiles.is_empty() and D.build("rift") == SB.TEXT["once_climb"], "...a new floor forgets the rift, not that it was torn")
	main.floor_plan["proving"] = true
	D.rift_used = false
	_check(D.build("rift") != "" and R.tiles.is_empty(), "never on the Proving's floor")
	main.floor_plan["proving"] = false
	# Through a vault, a locked door and traps: each opened, what it held taken.
	var need := {"vault": true, "door": true, "trap": true}
	for n in 40:
		if need.is_empty():
			break
		main._start_floor(3 + n % 6)
		await _frames(1)
		await _clear_foes()
		main.banner = {}
		D.rift_used = false  # (as a new climb would)
		var W = main.wings
		var locked: Array = main.door_view.list.filter(func(d): return String(d["lock"]) != "" and int(d["room"]) >= 0)
		var got := {}
		if need.has("vault") and not W.wings.is_empty():
			var w: Dictionary = W.wings[0]
			got = _rift_start(R, func(pl): return pl["tiles"].keys().any(func(t): return w["rect"].has_point(R._center(t))), w["rect"].grow(Tr.C * 2.0))
			if not got.is_empty():
				p.global_position = got["pos"]
				_check(D.build("rift") == "" and w["vault"] == "taken" and w["state"] == "done" and not main.is_solid(R._center(w["vault_door"])), "a rift through a sealed wing opens its vault, empty")
				_check(("vault:%s" % str(w["id"])) in R.taken and SB.TEXT["rift_vault"] in main.banner.get("lines", []), "...and says so: %s" % SB.TEXT["rift_vault"])
				p.global_position = w["pedestal"]
				await _frames(3)
				_check(not main.camp_choosing, "...its pedestal holds nothing to choose")
				main.camp_choosing = false
				need.erase("vault")
				continue
		if need.has("door") and not locked.is_empty():
			var d: Dictionary = locked[0]
			var rr: Rect2 = main.room_info[int(d["room"])]["rect"]
			got = _rift_start(R, func(pl): return pl["tiles"].keys().any(func(t): return t in d["tiles"] or rr.has_point(R._center(t))), rr.grow(Tr.C))
			if not got.is_empty():
				var had_cache: bool = not main.cache.is_empty() and rr.has_point(main.cache["pos"])
				p.global_position = got["pos"]
				_check(D.build("rift") == "" and String(d["lock"]) == "" and ("door:%d" % int(d["lock_id"])) in R.taken, "a rift through a locked door (or its room): the lock is gone")
				_check(not d["tiles"].any(func(t): return main._is_solid_tile(t.x, t.y)) and (not had_cache or main.cache["taken"]), "...the way is open, and what lay behind it is taken (cache: %s)" % had_cache)
				need.erase("door")
				continue
		if need.has("trap") and not main.traps.is_empty():
			got = _rift_start(R, func(pl): return main.traps.any(func(tr): return pl["tiles"].has(main._tile_of(tr["pos"]))), Rect2())
			if not got.is_empty():
				p.global_position = got["pos"]
				var on_it: int = main.traps.filter(func(tr): return got["plan"]["tiles"].has(main._tile_of(tr["pos"]))).size()
				_check(D.build("rift") == "" and R.traps_gone == on_it and on_it > 0 and not main.traps.any(func(tr): return R.tiles.has(main._tile_of(tr["pos"]))), "a rift through a trap room destroys the traps on it (%d)" % on_it)
				_check(_rift_ok(R), "...and the floor it tore is whole: walls, paths and collision")
				need.erase("trap")
	_check(need.is_empty(), "found floors for a rift through a vault, a locked door and traps (left: %s)" % [need.keys()])
	main._start_floor(main.floor_num + 1)
	await _frames(1)
	print("the Manipulator")
	await _clear_foes()
	SB.grant(prof, "manipulator", 5)
	prof.path = "life"
	main.run_flow = 200.0
	main.run_essence = {"water": 300.0}
	p.global_position = main.player_start
	var kn = await _spawn("knight", p.global_position + Vector2(120, 0))
	var sp0: float = kn.speed
	_check(T.use("man_edit", kn) and _sb_card("slow") >= 0 and D.cards.any(func(c): return String(c.get("id", "")).begins_with("turn:")), "Edit offers tunings and weaker kinds of its tower")
	main.choose_camp(_sb_card("slow"))
	_check(is_equal_approx(kn.speed, sp0 * SB.MEDIT["slow"]["speed"]) and main.run_flow < 200.0, "...Slower, paid with Life")
	T.use("man_edit", kn)
	main.choose_camp(_sb_card("short"))
	_check(kn.reach_k == SB.MEDIT["short"]["reach"], "...Half its reach")
	_check(not T.use("man_edit", kn) and T.message == SB.TEXT["medit_max"], "...within its budget (%d changes)" % SB.MEDIT_MAX)
	var kn2 = await _spawn("knight", p.global_position + Vector2(-120, 0))
	var kn2_at: Vector2 = kn2.global_position
	T.use("man_edit", kn2)
	var turn_i := -1
	for i in D.cards.size():
		if String(D.cards[i].get("id", "")).begins_with("turn:"):
			turn_i = i
	var into: String = String(D.cards[turn_i]["id"]).substr(5) if turn_i >= 0 else ""
	main.choose_camp(turn_i)
	await _frames(1)
	var turned: Array = main.enemies().filter(func(e): return e.kind == into and e.has_meta("sb_edits") and "turned" in e.get_meta("sb_edits") and e.global_position.distance_to(kn2_at) < 80.0)
	_check(turn_i >= 0 and (not is_instance_valid(kn2) or kn2.dead), "...or turns it into a weaker kind")
	_check(not turned.is_empty(), "...standing where it stood (%s)" % into)
	var champ = await _spawn("knight", p.global_position + Vector2(0, 100))
	champ.make_champion()
	_check(not T.use("man_edit", champ) and T.message == SB.TEXT["resists"], "great foes won't answer")
	champ.queue_free()
	await _clear_foes()

	print("the Manipulator's Reroll")
	main._start_floor(4)
	await _frames(1)
	# Rooms not yet entered, with monsters asleep, farthest first (so nothing new wakes at the sight of you).
	var cands: Array = []
	for i in main.room_info.size():
		if not main.room_entered.has(i) and D.room_pack(i).size() >= 1:
			cands.append(i)
	var pp0: Vector2 = main.player.global_position
	cands.sort_custom(func(a, b): return main.room_info[a]["rect"].get_center().distance_to(pp0) > main.room_info[b]["rect"].get_center().distance_to(pp0))
	_check(not cands.is_empty(), "a room not yet entered, with monsters asleep")
	var ri := -1
	var n_old := 0
	main.run_flow = 200.0
	main.run_essence = {"water": 300.0}
	for i in cands:  # (a pack with no other mix of the tower's monsters about as strong offers nothing; try the next room)
		n_old = D.room_pack(i).size()
		if T.use("man_reroll", i) and D.cards_tool == "man_reroll" and D.cards.size() >= 2:
			ri = i
			break
	if not cands.is_empty():
		_check(ri >= 0, "Reroll shows the packs it could hold (%d cards; %s)" % [D.cards.size(), T.message])
	if ri >= 0:
		var want: Array = D.cards[0]["kinds"].duplicate()
		var before_ids: Array = main.enemies().map(func(e): return e.get_instance_id())
		main.choose_camp(0)
		await _frames(1)
		# The new pack is exactly the monsters that weren't there before (a neighbour room's sleepers don't count).
		var made: Array = main.enemies().filter(func(e): return not before_ids.has(e.get_instance_id()))
		var now: Array = made.map(func(e): return e.kind)
		now.sort()
		want.sort()
		var asleep: bool = made.all(func(e): return not e.aware)
		_check(now == want and asleep and D.rerolled.has(ri), "...and the room holds the chosen pack, asleep (%s, wanted %s, was %d)" % [now, want, n_old])
		_check(not T.use("man_reroll", ri), "...once a room")
	await _clear_foes()

	print("the Manipulator's Build")
	main.run_flow = 200.0
	main.run_essence = {"water": 300.0}
	p.global_position = main.player_start
	var sl = await _spawn("slime", p.global_position + Vector2(100, 0))
	_check(T.use("man_build", sl) and D.cards_tool == "man_build" and D.cards.size() >= 2, "Build offers a second kind's attack")
	var sec: String = D.cards[0]["id"]
	main.choose_camp(0)
	await _frames(1)
	_check(sl.ally and sl in main.allies() and not sl in main.enemies() and D.built == sl and D.built_second == sec, "...the monster is rewritten into your own (with %s)" % sec)
	var other = await _spawn("slime", p.global_position + Vector2(-100, 0))
	_check(not T.use("man_build", other) and T.message == SB.TEXT["mbuild_one"], "...one at a time")
	other.global_position = sl.global_position + Vector2(40, 0)
	other.max_hp = 500.0
	other.hp = 500.0
	D.second_attack(other)
	_check(other.hp < 500.0, "...and it uses its second attack on a foe (%.0f)" % other.hp)
	await _clear_foes()
	main._start_floor(main.floor_num + 1)
	await _frames(1)
	_check(D.built == null and main.allies().is_empty(), "...for the floor")

	print("secret bonds, saved")
	SB.grant(prof, "developer", 5)
	prof.core_edit = {"chain_lightning": {"reach": 1, "power": -1}}
	var mk: Dictionary = prof.makers
	mk["bribe"] = {"offered": 2, "for": 0}
	var path := "user://smoke_sdeep_test.cfg"
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.core_depth == 5 and int(again.core_edit.get("chain_lightning", {}).get("reach", 0)) == 1 and int(SB.bribe_state(again).get("offered", 0)) == 2, "depth 5, the Edit and the bribes remembered are saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	main.menu.open("dev")
	await _frames(1)
	_check(_menu_button("Manipulator 5") != null and _menu_button("Developer 3") != null, "the dev tools grant depths 3 to 5")
	main.menu.close()
	SB.clear(prof)
	main._give_bonds()
	p.iframes = 0.0


## The vessel (vessel.gd): it catches the secret essence that isn't your
## path, comes home whole (lost on a fall), is brewed by a Rune Artist or
## found in a vault, and a full one is traded, worked at the bench, or
## offered (a plea, the Developer's bribe). Saved with the chest.
func _vessel_tests() -> void:
	print("the vessel")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var V = load("res://scripts/vessel.gd")
	var Items = main.Items
	var T = main.Train
	var B = load("res://scripts/bench.gd")
	var G = main.Gear
	var SB = main.SecretBonds
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
	_check(Items.ITEMS.has("vessel") and Items.max_stack("vessel") == 1 and not ("vessel" in T.supplies()) and not ("vessel" in B.brews()) and Items.random_item(true, [], false) != "vessel",
		"the vessel is an item of its own: one at a time, never sold, brewed with the rest or dropped")
	prof.path = "life"
	var at: Vector2 = p.global_position + Vector2(120, 0)
	# Without a vessel the other essence passes through.
	var m0: int = main.fx.motes_list.size()
	main.rise_secret("unmaking", 9.0, at)
	_check(main.fx.motes_list.slice(m0).any(func(m): return m.get("through", false)) and V.carried(p).is_empty(), "without a vessel, Unmaking passes through you")
	# With one it's caught, up to what it holds; your path's essence isn't touched.
	_check(V.give(main, {}) and p.item_count("vessel") == 1 and V.carried(p)["amount"] == 0.0, "a vessel goes on the belt, empty")
	m0 = main.fx.motes_list.size()
	var f0: float = main.run_flow
	main.rise_secret("unmaking", 12.0, at)
	var curls: Array = main.get_children().filter(func(c): return c.has_method("rise") and "motes" in c)
	_check(is_equal_approx(V.carried(p)["amount"], 12.0) and V.carried(p)["kind"] == "unmaking" and main.fx.motes_list.size() == m0 and is_equal_approx(main.run_flow, f0),
		"with one, the Unmaking is caught (12), none passes, the flow is untouched")
	_check(curls.size() == 1, "...its streak rises toward you")
	if curls.size() == 1:
		var c = curls[0]
		await _until(func(): return not is_instance_valid(c) or c.motes.any(func(m): return m["curl"] >= 0.0), 3.0)
		_check(is_instance_valid(c) and c.motes.any(func(m): return m["curl"] >= 0.0), "...and curls into the vessel at your hip")
	main.rise_secret("life", 9.0, at)
	_check(is_equal_approx(main.run_flow, f0 + 9.0) and is_equal_approx(V.carried(p)["amount"], 12.0), "your path's Life still soaks into you, not the vessel")
	m0 = main.fx.motes_list.size()
	main.rise_secret("unmaking", 25.0, at)
	_check(V.full_on_belt(p) and is_equal_approx(V.carried(p)["amount"], V.CAPACITY) and main.fx.motes_list.slice(m0).any(func(m): return m.get("through", false)),
		"it fills to %d; the rest passes through" % int(V.CAPACITY))
	_check(Items.use("vessel", p) == false and p.item_count("vessel") == 1, "using it only says what it holds")
	var full_kind: String = V.carried(p)["kind"]
	prof.path = ""
	_check(is_equal_approx(V.capture(main, "life", 5.0, at), 5.0), "before a path is chosen it catches nothing")
	prof.path = "life"
	for k in 3:
		p.add_item(["draught", "tonic", "smoke"][k])
	main.offer_belt_swap({"id": "flare", "pos": p.global_position, "t": 10.0})
	var swap_choices: Array = main.camp.get("choices", [])
	main._take_belt_pick("belt:")
	_check(not ("belt:vessel" in swap_choices) and swap_choices.size() >= 2, "a full belt's swap card never offers the vessel (what it holds would spill)")
	# It comes home on a survived climb or a recall, and isn't broken into crystals.
	prof.crystals = []
	prof.vessels = []
	main.belt_broken = false
	var broke: String = main.break_belt()
	_check(p.item_count("vessel") == 1 and broke != "" and prof.crystal_total("stone") > 0.0, "the belt breaks into crystals, the vessel aside")
	var home: String = V.bring_home(main)
	_check(prof.vessels.size() == 1 and V.is_full(prof.vessels[0]) and prof.vessels[0]["kind"] == full_kind and p.item_count("vessel") == 0 and home.contains("comes home"),
		"...it comes home to your chest, full (%s)" % home)
	V.give(main, V.make("unmaking", 7.0))
	main.belt_broken = false
	main.read_recall()
	_check(prof.vessels.size() == 2 and is_equal_approx(prof.vessels[1]["amount"], 7.0) and main.victory.get("lines", []).any(func(l): return String(l).contains("vessel")),
		"a recall scroll brings it home too, partly filled")
	main.victory = {}
	p.set_physics_process(true)
	# Lost with the belt on a fall.
	V.give(main, V.make("unmaking", 20.0))
	main.on_player_died()
	_check(p.item_count("vessel") == 0 and prof.vessels.size() == 2 and main.fall_note.any(func(l): return String(l).contains("vessel")), "a fall loses it with the belt, and says so")
	# Packed from the chest, it goes up on the belt.
	p.items = {}
	_check(V.pack(prof, p, 1) == "" and V.packed_index(prof) == 1, "a vessel in the chest can be packed for the next climb")
	_check(T.supply_room(prof, p, "draught") > 0, "(it leaves room for the rest of the belt)")
	T.pack_up(prof, p)
	_check(p.item_count("vessel") == 1 and is_equal_approx(V.carried(p)["amount"], 7.0) and prof.vessels.size() == 1, "...and departing puts it on your belt, still holding 7")
	p.items.erase("vessel")
	p.vessel = {}
	# A Rune Artist brews one; nobody else can.
	prof.vessels = []
	for k in V.BREW:
		prof.add_crystal(k, float(V.BREW[k]))
	_check(V.brew(prof).contains("Rune Artist") and prof.vessels.is_empty(), "only a Rune Artist can brew a vessel")
	prof.add_bond("brow", "rune_artist", false)
	_check(V.brew(prof) == "" and prof.vessels.size() == 1 and V.fill(prof.vessels[0]) == 0.0 and prof.crystal_total("iron") == 0.0, "a Rune Artist brews one (%s), empty, into the chest" % B.cost_text(V.BREW))
	# Very rarely, a vault offers one.
	V.vault_force = 1.0
	var cards: Array = main.wings.vault_choices(false)
	_check(cards.size() == 3 and cards[2] == "vessel", "a vault's third card can be a vessel")
	main.offer_vault(cards, "THE VAULT", [""])
	main._take_vault_pick("vessel")
	_check(p.item_count("vessel") == 1 and V.carried(p)["amount"] == 0.0, "...taken onto the belt, empty")
	_check(main.wings.vault_choices(false)[2] != "vessel", "...never while you carry one")
	p.items.erase("vessel")
	p.vessel = {}
	V.vault_force = 0.0
	_check(main.wings.vault_choices(false)[2] != "vessel", "(and only by chance)")
	V.vault_force = -1.0
	# The store: a full vessel trades for crystals of your choice.
	prof.vessels = [V.make("unmaking", V.CAPACITY), V.make("life", 10.0)]
	prof.crystals = []
	main.await_tower()
	main.open_train()
	menu.train_car = "store"
	menu.train_store = "sell"
	menu.inv_sel = "vessel:0"
	menu.open("train")
	await _frames(2)
	var trade := func(choice: String) -> Array:
		return _all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.get_meta("vessel_trade", "") == choice)
	var fire: Array = trade.call("fire")
	_check(fire.size() == 1 and trade.call("mixed").size() == 1, "the store's Sell lists the vessel: a crystal of one kind you choose, or some of every kind")
	if fire.size() == 1:
		fire[0].pressed.emit()
		await _frames(2)
		_check(prof.vessels.size() == 2, "the first press only asks")
		fire = trade.call("fire")
		if fire.size() == 1:
			fire[0].pressed.emit()
			await _frames(2)
	_check(prof.vessels.size() == 1 and prof.crystal_total("fire") == float(V.TRADE["one"]), "the second trades it for %d Fire" % int(V.TRADE["one"]))
	menu.inv_sel = "vessel:0"
	menu.open("train")
	await _frames(2)
	_check(trade.call("fire").is_empty(), "a vessel that isn't full can't be traded")
	prof.vessels[0] = V.make("life", V.CAPACITY)
	_check(V.trade(prof, 0, "mixed") != "" and prof.crystal_total("air") == float(V.TRADE["each"]) and prof.vessels.is_empty(), "...or %d of every kind" % int(V.TRADE["each"]))
	# The bench: a Rune Artist works a full vessel into a piece.
	prof.heirlooms["melee"] = G.make("spear", "fine", ["edges"], 3)
	prof.vessels = [V.make("unmaking", V.CAPACITY)]
	var strike3: float = G.effects(prof.heirlooms["melee"])["strike"]
	menu.train_car = "workshop"
	menu.train_bench = "vessel"
	menu.inv_sel = "bench:heir:melee"
	menu.open("train")
	await _frames(2)
	var deep := func() -> Array:
		return _all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.get_meta("bench_do", "") == "vtemper")
	var dt: Array = deep.call()
	_check(dt.size() == 1 and not dt[0].disabled, "the Vessel counter offers to temper a +3 piece past the limit")
	if dt.size() == 1:
		dt[0].pressed.emit()
		await _frames(2)
		dt = deep.call()
		if dt.size() == 1:
			dt[0].pressed.emit()
			await _frames(2)
	var spear: Dictionary = prof.heirlooms["melee"]
	_check(int(spear["rank"]) == G.RANK_CAP and prof.vessels.is_empty() and is_equal_approx(G.effects(spear)["strike"], strike3 * (1.0 + G.RANK_TRAIT * 4) / (1.0 + G.RANK_TRAIT * 3)),
		"...to +%d, using up the vessel (its trait a quarter more of its base)" % G.RANK_CAP)
	_check(V.deep_rune(prof, "heir:melee", "sharpness") != "" and not spear.has("rune"), "a deep rune needs a full vessel")
	prof.vessels = [V.make("life", V.CAPACITY)]
	var strike4: float = G.effects(prof.heirlooms["melee"])["strike"]
	_check(V.deep_rune(prof, "heir:melee", "sharpness") == "" and prof.heirlooms["melee"]["rune"] == "deep_sharpness" and prof.vessels.is_empty()
		and is_equal_approx(G.effects(prof.heirlooms["melee"])["strike"], strike4 + 0.2), "...with one, a deep rune at the spell's full strength (+20% strikes)")
	_check(B.inscribe(prof, "heir:melee", "deep_warding") != "", "the bench's own Inscribe can't cut a deep rune")
	main.on_train = false
	menu.close()
	paused = false
	await _frames(1)
	# An offering: a plea with the vessel is likelier, and the Maker keeps it.
	var mk = main.makers
	prof.path = "life"
	_check(not mk.answers().any(func(o): return o["id"] == "plea_vessel"), "no vessel, no offering card")
	V.give(main, V.make("unmaking", V.CAPACITY))
	var ids: Array = mk.answers().map(func(o): return o["id"])
	_check("plea" in ids and "plea_vessel" in ids, "carrying a full vessel, a meeting offers it with a plea")
	_check(mk.plea_odds("marks", true) > mk.plea_odds("marks", false), "...likelier to be granted (%.2f against %.2f)" % [mk.plea_odds("marks", true), mk.plea_odds("marks", false)])
	mk.plea_force = 0
	var res: Dictionary = mk.answer("marks", "plea_vessel")
	_check(p.item_count("vessel") == 0 and prof.path == "life" and mk.TEXT["vessel_taken"] in res["lines"], "refused, it still keeps the vessel")
	V.give(main, V.make("unmaking", V.CAPACITY))
	mk.plea_force = 1
	res = mk.answer("marks", "plea_vessel")
	_check(p.item_count("vessel") == 0 and prof.path == "" and res["good"], "granted: the path is cleared and the vessel is gone")
	mk.plea_force = -1
	# The Developer's bribe takes a full vessel from the chest.
	SB.grant(prof, "developer", 2)
	prof.vessels = [V.make("life", 12.0), V.make("unmaking", V.CAPACITY)]
	var offers: Array = SB.bribe_offers(prof, G)
	_check(offers.any(func(o): return o["id"] == "vessel:1" and o["ok"]) and not offers.any(func(o): return o["id"] == "vessel:0"), "the bribe offers a full vessel from the chest (not a partly filled one)")
	_check(SB.bribe_odds(prof, true) > SB.bribe_odds(prof), "...likelier taken than crystals")
	SB.bribe_force = 1
	res = SB.offer_bribe(prof, "vessel:1", G)
	_check(res["ok"] and prof.vessels.size() == 1 and not V.is_full(prof.vessels[0]) and int(SB.bribe_state(prof).get("for", 0)) == 3, "...accepted, it counts for the next depth and the vessel is gone")
	SB.bribe_force = -1
	SB.clear(prof)
	# Saved with the chest.
	var path := "user://smoke_vessel_test.cfg"
	prof.vessels = [V.make("life", V.CAPACITY), {"kind": "unmaking", "amount": 4.5, "packed": true}, {"kind": "nonsense", "amount": 9}]
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.vessels.size() == 3 and V.is_full(again.vessels[0]) and again.vessels[0]["kind"] == "life" and is_equal_approx(again.vessels[1]["amount"], 4.5)
		and again.vessels[1].get("packed", false) and again.vessels[2]["kind"] == "" and again.vessels[2]["amount"] == 0.0, "vessels are saved and load again (a broken one reads as empty)")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.vessels.is_empty(), "an old save loads with no vessels")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	prof.path = ""


## Removes every test slot file (slots.gd's test copies), so no test sees
## another's climbers.
func _clear_slots() -> void:
	var S = load("res://scripts/slots.gd")
	for i in range(1, S.MAX + 1):
		if FileAccess.file_exists(S.path(i)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(S.path(i)))
	for f in [S.settings_path(), S.backup_path()]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	S.forget()


## A climber saved straight into a slot's file (tests).
func _slot_climber(slot: int, name: String, bonds: Dictionary, crystal: Array):
	var S = load("res://scripts/slots.gd")
	var c = load("res://scripts/profile.gd").new()
	c.save_path = S.path(slot)
	c.created = true
	c.regarded = not bonds.is_empty()
	for part in bonds:
		c.add_bond(part, bonds[part], false)
	if not crystal.is_empty():
		c.add_crystal(crystal[0], crystal[1])
	c.appearance["name"] = name
	c.saving = true
	c.save()
	c.saving = false
	return c


## Climber slots (slots.gd): up to six climbers, each in their own file and
## kept apart (marks, crystals, train, look, the Entity's tips); settings
## shared; the slot played last remembered; deleting one removes only it; no
## seventh; an old single save moves into slot 1 whole; the picker by keys,
## a tap, an empty slot, Delete twice.
## The menu's left rail (rail.gd) and the interface's fonts (ui.gd).
func _rail_tests() -> void:
	print("the menu's rail and fonts")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var menu = main.menu
	var U = load("res://scripts/ui.gd")
	var R = load("res://scripts/rail.gd")
	# The fonts load, and the body font is everyone's default.
	var body: Font = U.font("body")
	_check(body != null and ThemeDB.fallback_font == body and U.font("display") != body and U.font("mono") != body and U.font("eyebrow") != null, "the interface's fonts load, the body font the default")
	_check(body.get_string_size("Wren", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 12.0 and U.font("display").get_string_size("Wren", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 12.0 and U.font("mono").get_string_size("12", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 8.0 and U.font("inscription").get_string_size("Wren", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 12.0, "...and measure real text (Grenze, Grenze Gotisch, Cormorant Garamond)")
	_check(U.title_case("THE KRAKEN'S TOWER") == "The Kraken's Tower" and U.title_case("RARE: Coral Trident") == "Rare: Coral Trident" and U.title_case("HUD size") == "HUD size", "gothic text is shown in mixed case, never shouted")
	_check(menu.theme != null and menu.theme.default_font == body, "the menus' theme uses the body font")
	# Esc opens the menu with its rail, the focus on Resume.
	await _key_tap(KEY_ESCAPE)
	await _frames(2)
	var rail = menu.rail
	_check(menu.page == "pause" and rail.visible and rail.buttons.size() == 1 + R.ITEMS.size() + R.FOOT.size(), "Esc opens the menu with the rail: who you are, its pages and Exit")
	_check(rail.buttons.map(func(b): return b.text) == ["Climber", "Resume", "Inventory", "Library", "Settings & Controls", "Dev Tools", "Exit to Title"], "...named as on the train: Climber (who you are), Resume, Inventory, Library, Settings & Controls, Dev Tools, Exit to Title (%s)" % [rail.buttons.map(func(b): return b.text)])
	_check(rail.button("resume") != null and rail.button("resume").has_focus() and rail.current == "resume", "...the focus on Resume, lit as the page showing")
	# Up and down move along the rail, showing each page as they go.
	await _key_tap(KEY_DOWN)
	_check(menu.page == "inventory" and rail.button("inventory").has_focus() and rail.current == "inventory", "Down moves to Inventory and shows it (the focus stays on the rail)")
	await _key_tap(KEY_DOWN)
	_check(menu.page == "library" and rail.button("library").has_focus(), "...Down again: the Library")
	await _key_tap(KEY_UP)
	await _key_tap(KEY_UP)
	await _key_tap(KEY_UP)
	_check(menu.page == "climber" and rail.button("climber") == rail.ident and rail.ident.has_focus() and rail.current == "climber", "Up from Resume reaches who you are, at the top, and shows the climber screen")
	await _key_tap(KEY_UP)
	_check(rail.button("exit").has_focus() and menu.page == "climber", "...Up again wraps round to Exit (the foot only acts when pressed)")
	await _key_tap(KEY_DOWN)
	# Right goes into the page; Esc comes back to the rail; Esc on the rail closes.
	await _key_tap(KEY_RIGHT)
	var f: Control = root.gui_get_focus_owner()
	_check(menu.page == "climber" and f != null and not rail.buttons.has(f) and f.has_meta("tab"), "Right goes into the page (onto its tabs)")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "climber" and rail.has_focus_inside() and rail.button("climber").has_focus() and main.menu_open(), "Esc goes back to the rail, the page still showing")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open() and not paused, "...and Esc on the rail closes the menu")
	# Enter on an item goes straight into its page.
	await _key_tap(KEY_ESCAPE)
	await _key_tap(KEY_DOWN)
	await _key_tap(KEY_ENTER)
	f = root.gui_get_focus_owner()
	_check(menu.page == "inventory" and f != null and not rail.buttons.has(f), "Enter on a rail item goes into its page")
	menu.close()
	await _frames(2)
	# Every item opens its page (clicks and the controller's A press them).
	menu.open("pause")
	await _frames(2)
	var want := {"climber": "climber", "inventory": "inventory", "library": "library", "settings": "settings", "dev": "dev"}
	var wrong: Array = []
	for id in want:
		rail.button(id).pressed.emit()
		await _frames(2)
		if menu.page != want[id] or rail.current != id or not rail.visible:
			wrong.append("%s opened %s" % [id, menu.page])
	_check(wrong.is_empty(), "every rail item opens its page, lit on the rail (%s)" % ", ".join(wrong))
	rail.button("library").pressed.emit()
	await _frames(2)
	_check(menu.page == "library" and menu.find_children("*", "", true, false).any(func(c): return c.get_meta("entity", "") == "archive"), "Library opens the Entity's Archive as one page")
	rail.button("climber").pressed.emit()
	await _frames(2)
	_check(menu.page == "climber" and not menu.climber_tabs().any(func(t): return t[0] == "archive"), "...and the climber screen has no Archive tab of its own")
	menu.open_mark("hand")
	await _frames(2)
	_check(menu.page == "mark" and rail.visible and rail.current == "climber", "a mark's page keeps the rail, Climber lit")
	rail.button("resume").pressed.emit()
	await _frames(2)
	_check(not main.menu_open(), "Resume closes the menu")
	# The keys that open a page directly still do, with the rail; Esc closes them at once.
	await _key_tap(KEY_I)
	_check(menu.page == "inventory" and rail.visible and rail.current == "inventory", "I opens the inventory with the rail")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open(), "...and Esc closes it at once")
	# Touch: a tap on a rail item, on a phone-sized screen (landscape, drawn 1.5x).
	var was_size: Vector2i = root.size
	root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	await _frames(3)
	menu.open("pause")
	await _frames(3)
	await _tap_at(rail.button("settings").get_global_rect().get_center())
	_check(menu.page == "settings" and rail.current == "settings", "tapping a rail item opens its page")
	await _tap_at(rail.button("library").get_global_rect().get_center())
	_check(menu.page == "library", "...and another")
	await _tap_at(rail.ident.get_global_rect().get_center())
	_check(menu.page == "climber", "...and tapping who you are opens the climber screen")
	# It fits a phone: a narrow rail of icons and short names, the page beside it.
	var vis: Rect2 = menu.get_viewport_rect()
	var fits := true
	for b in rail.buttons:
		fits = fits and vis.encloses(b.get_global_rect()) and b.size.y >= 36.0
	_check(fits and rail.narrow and rail.size.x <= vis.size.x * 0.16, "on a phone the rail is narrow and every item fits on screen (%.0f of %.0f wide)" % [rail.size.x, vis.size.x])
	for pg in ["climber", "inventory", "settings", "dev"]:
		menu.open(pg)
		await _frames(3)
		var pr: Rect2 = menu.panel.get_global_rect()
		if pr.position.x < rail.size.x - 1.0 or pr.end.x > vis.end.x + 1.0:
			fits = false
			print("    ", pg, " panel ", pr, " rail ", rail.size.x)
	_check(fits, "...and each page sits beside it, inside the screen")
	var close_b: Button = _menu_button("Close")
	_check(close_b != null and vis.encloses(close_b.get_global_rect()), "...with Close at the top")
	await _tap_at(close_b.get_global_rect().get_center())
	_check(not main.menu_open(), "tapping Close shuts the menu")
	main.touch._set_active(false)
	main.player.touch_aim = false
	root.size = was_size
	await _frames(3)
	# On a computer the rail is wide, with a line under each name.
	menu.open("pause")
	await _frames(2)
	_check(not rail.narrow and rail.size.x == R.WIDE and menu.panel.get_global_rect().position.x >= R.WIDE, "on a computer the rail is wide and the page sits right of it")
	menu.close()
	await _frames(2)
	# On the train the rail is always there: the cars, then the pages; no
	# Resume (and no pause page to go back to).
	main.profile.regarded = true
	main.open_train()
	await _frames(3)
	_check(menu.page == "train" and rail.visible and rail.button("resume") == null and rail.button("personal") != null and rail.button("personal").text == main.Train.CARS[2][1], "on the train the rail is always there, with the cars and no Resume")
	_check(rail.button("personal").has_focus(), "...the keys start on it, on your car")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train", "...and Esc there stays on the train")
	menu.nav_keys = false
	rail.button("settings").pressed.emit()
	await _frames(3)
	var brake: Array = _car_buttons("over", true)
	_check(menu.train_car == "settings" and brake.size() == 1, "Start over is in the Settings & Controls car")
	if not brake.is_empty():
		brake[0].pressed.emit()
	await _frames(2)
	_check(menu.page == "confirm_new" and rail.visible and rail.current == "settings", "Start over from the train asks first, beside the rail (Settings & Controls lit)")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "settings", "...and Cancel goes back to the train, on that car")


## The train's rail in the owner's order (rail.gd): who you are opens the
## climber screen; the six cars, the Library and Settings & Controls cars
## among them (the Archive and every setting working in them, Start over
## with its confirm); Q / E and swipes through all six in order; Exit to
## Title Station; Quit only on a computer; an 800 x 400 phone; the pause
## rail's names; and the dev tools' train on end, which still navigates.
func _train_rail_tests() -> void:
	print("the train's rail: the owner's order, the Library and Settings & Controls cars, the train on end")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var menu = main.menu
	var M = load("res://scripts/menu.gd")
	var R = load("res://scripts/rail.gd")
	var Guide = load("res://scripts/guide.gd")
	var Entity = load("res://scripts/entity.gd")
	var T = main.Train
	var keep_settings: Dictionary = M.settings.duplicate()
	main.profile.regarded = true
	main.await_tower()
	main.open_train()
	await _frames(3)
	var rail = menu.rail
	var view = menu.train_view
	var tp = menu.train_page
	var order := ["engine", "store", "personal", "workshop", "library", "settings"]
	_check(T.CARS.map(func(c): return c[0]) == order and T.CARS.map(func(c): return c[1]) == ["Engine", "Outfitter's Car", "Your Car", "Workshop", "Library", "Settings & Controls Car"], "the train's cars, front to back: Engine, Outfitter's Car, Your Car, Workshop, Library, Settings & Controls Car")
	var ids: Array = rail.buttons.map(func(b): return b.id)
	_check(ids.slice(0, 9) == ["climber"] + order + ["dev", "exit"], "the rail: who you are, the six cars, Dev Tools, Exit to Title Station (%s)" % [ids])
	_check(rail.button("exit").text == "Exit to Title Station" and rail.button("dev").text == "Dev Tools", "...named Exit to Title Station and Dev Tools")
	_check(rail.button("quit") != null if menu.can_quit() else rail.button("quit") == null, "Quit game only where the game can be quit (a computer: %s)" % menu.can_quit())
	_check(menu.can_quit() == not (OS.has_feature("web") or OS.has_feature("mobile")), "...never in a browser or on a phone")
	# Who you are: hover, focus and a press open the climber screen.
	_check(rail.ident is Button and rail.ident.focus_mode == Control.FOCUS_ALL and rail.buttons[0] == rail.ident, "who you are is a button, the rail's first stop")
	menu.nav_keys = false
	rail.ident.pressed.emit()
	await _frames(2)
	_check(menu.page == "climber" and rail.current == "climber" and rail.ident.on, "pressing it opens the climber screen beside the rail, lit")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train", "...and Back returns to the train")
	await _click_at(rail.ident.get_global_rect().get_center())
	_check(menu.page == "climber", "a click on it does too")
	menu.close()
	await _frames(2)
	# Q / E pass through all six cars in order, and back.
	menu.train_car = "engine"
	menu.open("train")
	await _frames(2)
	var seen: Array = [menu.train_car]
	for i in 5:
		await _key_tap(KEY_E)
		seen.append(menu.train_car)
	await _key_tap(KEY_E)
	_check(seen == order and menu.train_car == "settings", "E goes through all six cars in order, and stops at the last (%s)" % [seen])
	var back: Array = [menu.train_car]
	for i in 5:
		await _key_tap(KEY_Q)
		back.append(menu.train_car)
	_check(back == ["settings", "library", "workshop", "personal", "store", "engine"], "...and Q back through them (%s)" % [back])
	# Swipes too, on a phone (800 x 400).
	var was_size: Vector2i = root.size
	root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	await _frames(2)
	menu.train_car = "engine"
	menu.open("train")
	await _frames(3)
	await _train_settled()
	var mid: float = view.size.y * 0.5
	var swiped: Array = [menu.train_car]
	for i in 5:
		await _swipe(Vector2(view.global_position.x + view.size.x * 0.62, mid), Vector2(view.global_position.x + view.size.x * 0.3, mid))
		await _train_settled()
		swiped.append(menu.train_car)
	_check(swiped == order, "swiping left goes through all six cars in order (%s)" % [swiped])
	# It fits: the narrow rail, every item on screen and big enough to tap.
	var vis: Rect2 = menu.get_viewport_rect()
	var off: Array = rail.buttons.filter(func(b): return not vis.encloses(b.get_global_rect().grow(-0.5)) or b.get_global_rect().size.y < 29.5)
	_check(rail.narrow and off.is_empty(), "at 800 x 400 the rail fits who you are, the six cars, Dev and Station: %s" % [off.map(func(b): return b.id)])
	_check(R.TRAIN_CARS["store"][0] == "Outfitter" and R.TRAIN_CARS["settings"][0] == "Settings" and R.TRAIN_FOOT[0][2] == "Station", "...with short names: Outfitter, Your Car, Library, Settings, Dev, Station")
	var outside: Array = []
	for car in ["library", "settings"]:
		menu.train_car = car
		menu.open("train")
		await _train_settled()
		await _frames(4)
		var vr: Rect2 = view.get_global_rect()
		for b in _all_buttons(tp.roots[car]):
			if b.is_visible_in_tree() and not vr.grow(0.5).encloses(b.get_global_rect()) and tp._scroll_of(b) == null:
				outside.append("%s %s" % [car, b.text])
		var sc_rect: Rect2 = tp.card_scrolls[car].get_global_rect()
		if not vr.grow(0.5).encloses(sc_rect):
			outside.append("%s's panel" % car)
	_check(outside.is_empty(), "...and the Library's and Settings & Controls' furniture fit in the car (their lists scroll in their panels): %s" % [outside])
	# A slider set by a finger, in the car.
	menu.train_car = "settings"
	menu.settings_tab = "settings"
	menu.open("train")
	await _frames(4)
	var sliders: Array = tp.roots["settings"].find_children("*", "HSlider", true, false).filter(func(sl): return sl.is_visible_in_tree())
	if not sliders.is_empty():
		var sl: HSlider = sliders[0]
		var r: Rect2 = sl.get_global_rect()
		await _tap_at(Vector2(r.position.x + r.size.x * 0.25, r.get_center().y))
		_check(absf(float(M.settings["music"]) - 0.25) < 0.08 and menu.page == "train" and menu.train_car == "settings", "touching the music slider in the car sets it (%.2f), and doesn't move the train" % float(M.settings["music"]))
	else:
		_check(false, "the Settings & Controls car has sliders")
	main.touch._set_active(false)
	root.size = was_size
	await _frames(3)
	# The Library car: the Archive's shelves on the bookcase, read at the lectern.
	Guide.forget()
	for id in ["entity", "move", "glint", "ward", "train"]:
		Guide.state["known"][id] = true
	menu.train_car = "library"
	menu.library_shelf = ""
	menu.archive_open = ""
	menu.open("train")
	await _frames(3)
	var vols: Array = _car_buttons("shelf", "start")
	_check(_all_buttons(tp.roots["library"]).filter(func(b): return b.has_meta("shelf")).size() >= Entity.GROUPS.size(), "the Library's bookcase has a volume for each of the Archive's groups")
	_check(menu.library_shelf == "start" and vols.size() == 1 and vols[0].on, "...the first with something heard is open on the lectern")
	var entries: Array = _all_buttons(tp.roots["library"]).filter(func(b): return b.has_meta("archive"))
	var locked: Array = tp.roots["library"].find_children("*", "Label", true, false).filter(func(l): return l.has_meta("archive_locked"))
	_check(entries.size() == 3 and locked.size() == Entity.ordered("start").size() - 3, "the lectern shows that shelf's subjects: met ones as buttons, the rest ??? (%d, %d)" % [entries.size(), locked.size()])
	var glint: Array = _car_buttons("archive", "glint")
	if not glint.is_empty():
		glint[0].grab_focus()
		await _frames(1)
		await _key_tap(KEY_ENTER)
		await _frames(2)
	var says: Array = tp.roots["library"].find_children("*", "", true, false).filter(func(c): return c.get_meta("archive_open", "") == "glint")
	_check(menu.archive_open == "glint" and not says.is_empty() and menu.page == "train" and menu.train_car == "library", "opening a subject shows the Entity's tip and the fuller account, in the car")
	var f: Control = _focus_now()
	_check(f != null and f.get_meta("archive", "") == "glint", "...and the focus stays on it")
	var train_vol: Array = _car_buttons("shelf", "train")
	if not train_vol.is_empty():
		train_vol[0].pressed.emit()
		await _frames(2)
	_check(menu.library_shelf == "train" and _car_buttons("archive", "train").size() == 1, "another volume opens its own shelf on the lectern")
	_check(_car_buttons("archive", "glint").is_empty() and _all_buttons(tp.roots["library"]).any(func(b): return b.text == Entity.TEXT["replay"]), "...with Replay the tips there too")
	menu.close()
	menu.open_archive()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "library", "the Archive, asked for on the train, is the Library car")
	# The Settings & Controls car: a setting changes and saves; the Controls tab; Start over.
	menu.train_car = "settings"
	menu.settings_tab = "settings"
	menu.open("train")
	await _frames(3)
	var hud: Array = _all_buttons(tp.roots["settings"]).filter(func(b): return b.get_meta("choice_key", "") == "hud_scale" and b.get_meta("choice", "") == "large")
	_check(hud.size() == 1, "the Settings & Controls car holds the settings")
	if not hud.is_empty():
		hud[0].pressed.emit()
		await _frames(2)
	var path := "user://smoke_settings_car.cfg"
	M.save_settings_to(path)
	var cfg := ConfigFile.new()
	cfg.load(path)
	_check(M.settings["hud_scale"] == "large" and main.hud.hud_scale == float(main.menu.UI.HUD_SCALES["large"]) and cfg.get_value("settings", "hud_scale", "") == "large", "choosing HUD size Large there sets it, applies it and saves it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(menu.page == "train" and menu.train_car == "settings", "...staying in the car")
	var tog: Array = tp.roots["settings"].find_children("*", "CheckButton", true, false).filter(func(c): return c.is_visible_in_tree())
	_check(tog.size() >= 3 and _all_buttons(tp.roots["settings"]).any(func(b): return b.get_meta("setting", "") == "padsetup"), "...the toggles and Controller setup too")
	var ctab: Array = _car_buttons("panel_tab", "controls")
	if not ctab.is_empty():
		ctab[0].pressed.emit()
		await _frames(2)
	var labels: Array = _all_labels(tp.roots["settings"]).map(func(l): return l.text)
	_check(menu.settings_tab == "controls" and "Controller" in labels and labels.any(func(t): return "hold LB" in t), "its Controls tab lists every key and button")
	menu.settings_tab = "settings"
	var brake: Array = _car_buttons("over", true)
	_check(brake.size() == 1 and brake[0].text == T.TEXT["over"], "the emergency brake: Start over this climber")
	if not brake.is_empty():
		brake[0].pressed.emit()
	await _frames(2)
	_check(menu.page == "confirm_new" and _menu_button(load("res://scripts/climbers_page.gd").TEXT["cancel"]) != null, "...which asks first")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "settings" and main.profile.regarded, "...and Cancel goes back to the car, nothing lost")
	# Controller setup from the car comes back to it.
	var pads: Array = _all_buttons(tp.roots["settings"]).filter(func(b): return b.get_meta("setting", "") == "padsetup")
	if not pads.is_empty():
		pads[0].pressed.emit()
		await _frames(2)
	_check(menu.page == "padsetup" and rail.current == "settings", "Controller setup opens beside the rail, Settings & Controls lit")
	menu.go_back()
	await _frames(2)
	_check(menu.page == "train" and menu.train_car == "settings", "...and Back returns to the car")
	# Exit to Title Station.
	rail.button("exit").pressed.emit()
	await _frames(3)
	_check(menu.page == "title", "Exit to Title Station goes to the title")
	menu.close()
	await _frames(2)
	# The pause rail in a climb: the train's names, single pages.
	main.on_train = false
	main.choosing_tower = false
	menu.open("pause")
	await _frames(2)
	_check(rail.buttons.map(func(b): return b.id) == ["climber", "resume", "inventory", "library", "settings", "dev", "exit"], "the pause rail: who you are, Resume, Inventory, Library, Settings & Controls, Dev Tools, Exit")
	rail.button("settings").pressed.emit()
	await _frames(2)
	_check(menu.page == "settings" and menu.focusables().any(func(b): return b.has_meta("tab") and b.get_meta("tab") == "controls"), "Settings & Controls in a climb: one page, its two tabs")
	await _key_tap(KEY_E)
	_check(menu.settings_tab == "controls" and menu.page == "settings", "...E (or RB) switches to Controls")
	menu.settings_tab = "settings"
	menu.close()
	await _frames(2)
	# The train on end (dev tools): it switches, and still navigates.
	main.on_train = true
	menu.train_car = "personal"
	menu.open("dev")
	await _frames(2)
	var look: Array = menu.focusables().filter(func(b): return b.get_meta("choice_key", "") == "train_rail" and b.get_meta("choice", "") == "end")
	_check(look.size() == 1 and M.settings["train_rail"] == "menu", "dev tools: Train rail, a menu at first, or the train on end")
	if not look.is_empty():
		look[0].pressed.emit()
		await _frames(2)
	menu.close()
	await _frames(3)
	_check(M.settings["train_rail"] == "end" and rail.on_end and menu.page == "train", "...switched to the train on end")
	ids = rail.buttons.map(func(b): return b.id)
	_check(ids.slice(0, 9) == ["climber"] + order + ["dev", "exit"], "...the same items in the same order (%s)" % [ids])
	var cars: Array = rail.buttons.filter(func(b): return b.car)
	var stacked := true
	for i in cars.size() - 1:
		stacked = stacked and cars[i].get_global_rect().end.y <= cars[i + 1].get_global_rect().position.y
	_check(cars.size() == 6 and stacked and rail.button("engine").size.y > rail.button("store").size.y, "...the cars stacked under each other, the engine at the top and taller")
	rail.focus_current()
	await _frames(1)
	await _key_tap(KEY_DOWN)
	_check(menu.train_car == "workshop" and rail.button("workshop").has_focus(), "...Down on it moves to the next car")
	await _key_tap(KEY_E)
	_check(menu.train_car == "library" and rail.current == "library", "...E too, the light following")
	menu.nav_keys = false
	rail.button("engine").pressed.emit()
	await _frames(2)
	_check(menu.train_car == "engine", "...a click on a car goes there")
	rail.ident.pressed.emit()
	await _frames(2)
	_check(menu.page == "climber", "...and the station's sign opens the climber screen")
	menu.close()
	await _frames(2)
	root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	menu.open("train")
	await _frames(4)
	vis = menu.get_viewport_rect()
	off = rail.buttons.filter(func(b): return not vis.encloses(b.get_global_rect().grow(-0.5)) or b.get_global_rect().size.y < 29.5)
	_check(rail.narrow and rail.on_end and off.is_empty(), "...and fits at 800 x 400: %s" % [off.map(func(b): return b.id)])
	await _tap_at(rail.button("workshop").get_global_rect().get_center())
	_check(menu.train_car == "workshop", "...a tap on a car goes there")
	main.touch._set_active(false)
	root.size = was_size
	for k in keep_settings:
		M.settings[k] = keep_settings[k]
	menu.open("train")
	await _frames(2)
	_check(not rail.on_end, "...and back to the menu")
	menu.close()
	await _frames(2)


## The mouse, as the game would get it (a move, a button).
func _mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.relative = Vector2(6, 6)
	Input.parse_input_event(ev)


func _mouse_button(pos: Vector2, button: int, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)


func _focus_now() -> Control:
	return root.gui_get_focus_owner()


## The climber screen's tab button for `id`, or null.
func _tab_button(id: String) -> Button:
	for b in main.menu.focusables():
		if b.get_meta("tab", "") == id:
			return b
	return null


## The key names beside the climber screen's tabs ("Q" and "E", "LB" and
## "RB"), or none on a phone.
func _tab_keys() -> Array:
	var tab := _tab_button("marks")
	if tab == null:
		return []
	return tab.get_parent().get_children().filter(func(c): return c is Label).map(func(l): return l.text)


## A mouse click on a point of the game view.
func _click_at(pos: Vector2) -> void:
	_mouse_button(pos, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_mouse_button(pos, MOUSE_BUTTON_LEFT, false)
	await _frames(2)


## Picking up another device with a page open: its very first press counts
## (a button, the d-pad, a key, a click, a tap), and the page's prompts
## follow once it's let go (menu.gd input_changed; touch.gd).
func _switch_tests() -> void:
	print("switching device with a menu open: the first press counts")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.regarded = true
	var menu = main.menu
	var pad_keys: Array = [main.Controls.pad_name("lb", false), main.Controls.pad_name("rb", false)]
	# Keys -> controller: A on a focused page button.
	menu.climber_tab = "marks"
	menu.open("climber")
	await _frames(3)
	_check(_tab_keys() == ["Q", "E"], "with the keyboard the climber screen's tabs say Q and E (%s)" % [_tab_keys()])
	var tab := _tab_button("essence")
	tab.grab_focus()
	await _frames(1)
	_pad_button(JOY_BUTTON_A, true)
	await _frames(2)
	_check(main.pad_active and is_instance_valid(tab) and not tab.is_queued_for_deletion(), "A held after the keyboard: the controller takes over, and the page waits for the release")
	_pad_button(JOY_BUTTON_A, false)
	await _frames(3)
	_check(menu.climber_tab == "essence", "...the first A press takes effect (the Essence tab)")
	_check(_tab_keys() == pad_keys, "...and the prompts switch to the controller's words (%s)" % [_tab_keys()])
	_check(_focus_now() == _tab_button("essence"), "...with the focus still on the tab pressed")
	# Keys -> controller: the d-pad moves the focus on its first press.
	main.pad._set_active(false)
	await _frames(2)
	_check(_tab_keys() == ["Q", "E"], "back on the keyboard the tabs say Q and E again")
	_tab_button("essence").grab_focus()
	await _frames(1)
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_check(_focus_now() == _tab_button("record") and main.pad_active, "the d-pad's first press after the keyboard moves the focus (%s)" % [_focus_now()])
	_check(_tab_keys() == pad_keys, "...and the prompts switch to the controller's words")
	# A key held from the rail: the rail's item keeps the focus through the rebuild.
	main.pad._set_active(false)
	await _frames(2)
	menu._focus_rail(menu.rail.button("exit"))
	await _frames(1)
	await _pad_tap(JOY_BUTTON_DPAD_UP)
	await _frames(2)
	var on_rail: Control = _focus_now()
	_check(on_rail != null and menu.rail.buttons.has(on_rail) and on_rail.id == "dev" and menu.page == "dev", "on the rail, the d-pad's first press moves along it, and the focus stays there after the prompts change (%s)" % [on_rail.id if on_rail != null and menu.rail.buttons.has(on_rail) else on_rail])
	# Controller -> keys: Enter and the arrows work the first time.
	menu.climber_tab = "marks"
	menu.open("climber")
	await _frames(3)
	_check(main.pad_active and _tab_keys() == pad_keys, "with the controller the tabs say %s" % [pad_keys])
	_tab_button("essence").grab_focus()
	await _frames(1)
	await _key_tap(KEY_ENTER)
	await _frames(2)
	_check(not main.pad_active and menu.climber_tab == "essence", "after the controller, the first Enter takes effect")
	_check(_tab_keys() == ["Q", "E"], "...and the prompts switch back to the keys")
	main.pad._set_active(true)
	await _frames(2)
	_tab_button("essence").grab_focus()
	await _frames(1)
	await _key_tap(KEY_LEFT)
	await _frames(2)
	_check(_focus_now() == _tab_button("marks") and not main.pad_active, "after the controller, the first arrow moves the focus")
	# Controller -> mouse: the first click.
	main.pad._set_active(true)
	await _frames(2)
	await _click_at(_tab_button("record").get_global_rect().get_center())
	await _frames(2)
	_check(menu.climber_tab == "record" and not main.pad_active, "after the controller, the first click takes effect")
	_check(_tab_keys() == ["Q", "E"], "...and the prompts are the keyboard's")
	# Keys -> touch: the first tap, and the phone's layout after it.
	await _tap_at(_tab_button("essence").get_global_rect().get_center())
	await _frames(3)
	_check(menu.climber_tab == "essence", "the first tap after the keyboard takes effect")
	_check(main.touch_active and _tab_keys().is_empty(), "...then the menu switches to touch (no key names)")
	main.touch._set_active(false)
	menu.close()
	await _frames(2)
	# The card screens (drawn on the HUD each frame, never rebuilt): a camp.
	main._enter_camp([])
	await _frames(2)
	_check(main.camp_choosing and main.card_focus == 0 and not main.pad_active, "a camp's cards, with the keyboard")
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(main.card_focus == 1 and main.pad_active, "the d-pad's first press after the keyboard moves along a camp's cards")
	await _key_tap(KEY_LEFT)
	_check(main.card_focus == 0 and not main.pad_active, "...and the first arrow after the controller moves back")
	main.choose_camp(0)
	await _frames(2)

	# The train: a car's button, and a placard's.
	main.pad._set_active(false)
	main.await_tower()
	main.open_train()
	await _frames(3)
	menu.train_page.go_to(menu.train_page._index("workshop"))
	await _train_settled()
	await _frames(2)
	menu.train_bench = "brew"
	menu.open("train")
	await _frames(3)
	var hint_keys: String = menu.rail.hint.text if menu.rail.hint != null else ""
	var temper: Array = _car_buttons("bench_tab", "temper")
	if temper.size() == 1:
		temper[0].grab_focus()
		await _frames(1)
	await _pad_tap(JOY_BUTTON_A)
	await _frames(3)
	_check(menu.train_bench == "temper" and main.pad_active, "on the train, the first A after the keyboard works the bench's drawer")
	_check(menu.rail.hint != null and menu.rail.hint.text != hint_keys, "...and the rail's hint changes to the controller's words")
	var brew: Array = _car_buttons("bench_tab", "brew")
	if brew.size() == 1:
		brew[0].grab_focus()
		await _frames(1)
	await _key_tap(KEY_ENTER)
	await _frames(3)
	_check(menu.train_bench == "brew" and not main.pad_active, "...and the first Enter after the controller")
	_check(menu.rail.hint != null and menu.rail.hint.text == hint_keys, "...the hint back in the keys' words")


## The train's cars at a desktop's size and a phone's: no line of plain text
## (one with no panel or button behind it) crosses the brass rail along the
## wall or the skirting, and the workshop's note sits above the rail.
func _rail_line_tests() -> void:
	print("the train: nothing written across the brass rail")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var G = main.Gear
	var prof = main.profile
	prof.add_bond("brow", "rune_artist", false)
	for k in ["stone", "blade", "fire", "iron"]:
		prof.add_crystal(k, 30)
	prof.pack = [G.make("axe"), G.make("leather_gloves", "fine", ["edges"])]
	prof.chest = [G.make("grip_wraps", "fine", ["riposte"])]
	prof.supplies = {"draught": 1}
	var menu = main.menu
	var was_size: Vector2i = root.size
	main.await_tower()
	main.open_train()
	await _frames(3)
	for phone in [false, true]:
		root.size = Vector2i(800, 400) if phone else Vector2i(1280, 720)
		main.touch._set_active(phone)
		await _frames(3)
		var where := "on a phone (800 x 400)" if phone else "at 1280 x 720"
		var crossing: Array = []
		var note_ok := true
		var note_seen := false
		var states: Array = []
		for c in load("res://scripts/bench.gd").COUNTERS:
			states.append(["workshop", c[0], "shop"])
		states.append_array([["engine", "brew", "shop"], ["personal", "brew", "shop"], ["store", "brew", "shop"], ["store", "brew", "sell"], ["library", "brew", "shop"], ["settings", "brew", "shop"]])
		for st in states:
			menu.train_car = st[0]
			menu.train_bench = st[1]
			menu.train_store = st[2]
			menu.inv_sel = ""
			menu.open("train")
			await _frames(4)
			var tp = menu.train_page
			var room = menu.train_view.rooms[st[0]]
			var xf: Transform2D = room.get_global_transform()
			var u: float = room.u
			var rail := Vector2((xf * Vector2(0, room.wain - 4.0 * u)).y, (xf * Vector2(0, room.wain + 4.0 * u)).y)
			var skirt := Vector2((xf * Vector2(0, room.floor_y - 10.0 * u)).y, (xf * Vector2(0, room.floor_y)).y)
			for l in tp.roots[st[0]].find_children("*", "Label", true, false):
				if not l.is_visible_in_tree():
					continue
				var gx: Transform2D = l.get_global_transform()
				var top: float = (gx * Vector2.ZERO).y
				var bottom: float = (gx * Vector2(0, l.size.y)).y
				if l.has_meta("bench_note"):
					note_seen = true
					if bottom > rail.x:
						note_ok = false
						crossing.append("the %s note [%.0f-%.0f], rail at %.0f" % [st[1], top, bottom, rail.x])
					continue
				var backed := false
				var p = l.get_parent()
				while p != null and p != tp.roots[st[0]]:
					if p is PanelContainer or p is BaseButton:
						backed = true
					p = p.get_parent()
				if backed:
					continue
				if (top < rail.y and bottom > rail.x) or (top < skirt.y and bottom > skirt.x):
					crossing.append("%s %s: %s" % [st[0], st[1] if st[0] == "workshop" else st[2], l.text.left(30)])
		if not phone:
			_check(note_seen and note_ok, "%s the workshop's note sits above the brass rail, for every counter: %s" % [where, crossing])
		else:
			_check(note_ok, "%s the workshop's note (shown or not) never crosses the brass rail: %s" % [where, crossing])
		_check(crossing.is_empty(), "%s no plain text in any car crosses the brass rail or the skirting: %s" % [where, crossing])
	main.touch._set_active(false)
	root.size = was_size
	menu.train_bench = "brew"
	menu.train_store = "shop"
	menu.close()
	await _frames(2)


## How every menu answers keys, the mouse, a controller and touch (nav.gd):
## the same rules everywhere.
func _nav_tests() -> void:
	print("menu navigation: keys, mouse, controller and touch alike")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.regarded = true
	var menu = main.menu
	var rail = menu.rail
	var Nav = load("res://scripts/nav.gd")
	var p = main.player
	# Left from a page lands on the rail's item for that page, never another.
	menu.open("pause")
	await _frames(2)
	menu.open("inventory")
	await _frames(3)
	var melee = menu._slot_control("gear:melee")
	melee.grab_focus()
	await _frames(1)
	await _key_tap(KEY_LEFT)
	await _until(func(): return rail.has_focus_inside(), 1.0)
	_check(menu.page == "inventory" and rail.button("inventory").has_focus(), "Left from the inventory lands on its own rail item and the page stays (%s, %s)" % [menu.page, _focus_now()])
	menu.open("settings")
	await _frames(3)
	var ps_btn = _all_buttons(menu).filter(func(b): return b.get_meta("setting", "") == "padsetup")[0]
	ps_btn.grab_focus()
	await _frames(1)
	await _pad_tap(JOY_BUTTON_DPAD_LEFT)
	await _until(func(): return rail.has_focus_inside(), 1.0)
	_check(menu.page == "settings" and rail.button("settings").has_focus(), "...the d-pad too, from Settings")
	# Up and down in a page never touch the rail (no flash on the way).
	menu.open_mark("hand")
	await _frames(3)
	var seen: Array = []
	var watch := func(c): seen.append(c)
	root.gui_focus_changed.connect(watch)
	await _key_tap(KEY_UP)
	root.gui_focus_changed.disconnect(watch)
	_check(not seen.any(func(c): return rail.buttons.has(c)) and menu.page == "mark", "Up at a page's top stays in the page: the rail never takes the focus, even for a moment")
	# Holding a direction repeats, the same for keys, the d-pad and the stick.
	for how in ["key", "dpad", "stick"]:
		menu.close()
		await _frames(2)
		menu.open("pause")
		await _until(func(): return rail.button("resume").has_focus(), 1.0)
		if how == "key":
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_DOWN
			ev.keycode = KEY_DOWN
			ev.pressed = true
			Input.parse_input_event(ev)
		elif how == "dpad":
			_pad_button(JOY_BUTTON_DPAD_DOWN, true)
		else:
			_pad_axis(JOY_AXIS_LEFT_Y, 1.0)
		await _until(func(): return rail.button("library").has_focus(), 2.0)
		var got: bool = rail.button("library").has_focus()
		if how == "key":
			var up := InputEventKey.new()
			up.physical_keycode = KEY_DOWN
			up.keycode = KEY_DOWN
			Input.parse_input_event(up)
		elif how == "dpad":
			_pad_button(JOY_BUTTON_DPAD_DOWN, false)
		else:
			_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
		await _frames(3)
		_check(got, "holding %s down repeats along the rail" % {"key": "the arrow key", "dpad": "the d-pad", "stick": "the stick"}[how])
	main.pad._set_active(false)
	# The key's own repeats (the system's) don't add steps of their own.
	menu.close()
	await _frames(2)
	menu.open("pause")
	await _until(func(): return rail.button("resume").has_focus(), 1.0)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_DOWN
	k.keycode = KEY_DOWN
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(2)
	for i in 4:
		var e: InputEventKey = k.duplicate()
		e.echo = true
		Input.parse_input_event(e)
		await _frames(1)
	var k2: InputEventKey = k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)
	await _frames(2)
	_check(rail.button("inventory").has_focus(), "a quick press is one step, whatever the system's key repeat sends")
	# The stick wobbling past its deadzone is still one step (an appearance row).
	menu.open_appearance("climber")
	await _frames(3)
	main.pad._set_active(true)  # (the controller in use: its first press doesn't rebuild the page under it)
	await _frames(3)
	var rkey: String = menu.look_page.first_focus.key
	menu.look_page.rows[rkey].grab_focus()
	await _frames(1)
	var before: String = menu.look_page.rows[rkey].value
	for v in [0.6, 0.8, 1.0, 0.95, 1.0, 0.97, 1.0]:
		_pad_axis(JOY_AXIS_LEFT_X, v)
		await _frames(1)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	var A = load("res://scripts/appearance.gd")
	var after: String = menu.look_page.rows[rkey].value
	_check(after == A.step({rkey: before}, rkey, 1), "one push of the stick changes an appearance row by one, like the d-pad (%s -> %s)" % [before, after])
	main.pad._set_active(false)
	# Esc in a text box leaves the box, not the page; B the same.
	menu.look_page.name_edit.grab_focus()
	await _frames(1)
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "appearance" and not menu.look_page.name_edit.has_focus() and _focus_now() != null, "Esc in the name box leaves the box, not the page (%s)" % menu.page)
	menu.look_page.name_edit.grab_focus()
	await _frames(1)
	await _pad_tap(JOY_BUTTON_B)
	_check(menu.page == "appearance" and not menu.look_page.name_edit.has_focus(), "...and B the same")
	main.pad._set_active(false)
	# Back returns the focus to what opened the page.
	menu.open("climber")
	await _frames(3)
	_all_buttons(menu).filter(func(b): return b.has_meta("appearance"))[0].grab_focus()
	await _frames(1)
	await _key_tap(KEY_ENTER)
	await _until(func(): return menu.page == "appearance", 1.0)
	await _key_tap(KEY_ESCAPE)
	await _until(func(): return menu.page == "climber" and _focus_now() != null, 1.0)
	_check(menu.page == "climber" and _focus_now() != null and _focus_now().has_meta("appearance"), "back from Appearance, the focus is on the Appearance button again (%s)" % _focus_now())
	# Q / E move the focus onto the new tab.
	var tab = _all_buttons(menu).filter(func(b): return b.get_meta("tab", "") == menu.climber_tab)[0]
	tab.grab_focus()
	await _frames(1)
	await _key_tap(KEY_E)
	await _frames(2)
	_check(_focus_now() != null and _focus_now().get_meta("tab", "") == menu.climber_tab, "Q / E move the focus onto the tab they open (%s)" % menu.climber_tab)
	await _pad_tap(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	_check(_focus_now() != null and _focus_now().get_meta("tab", "") == menu.climber_tab, "...LB / RB too")
	main.pad._set_active(false)
	# The inventory's views switch with Q / E too.
	menu.open("inventory")
	await _frames(3)
	menu._slot_control("gear:melee").grab_focus()
	await _frames(1)
	var view0: String = menu.inv_view
	await _key_tap(KEY_E)
	_check(menu.inv_view != view0, "Q / E switch the inventory's views (%s -> %s)" % [view0, menu.inv_view])
	menu._inv_view("worn")
	await _frames(3)
	# Hover moves the focus.
	var heal = _all_buttons(menu).filter(func(b): return b.get_meta("slot", "") == "gear:armor")[0]
	_mouse_move(heal.get_global_rect().get_center())
	await _until(func(): return heal.has_focus(), 1.0)
	_check(heal.has_focus() and menu.inv_sel == "gear:armor", "the mouse over a slot moves the focus (and its card) there")
	_mouse_move(rail.button("settings").get_global_rect().get_center())
	await _until(func(): return rail.button("settings").has_focus(), 1.0)
	_check(rail.button("settings").has_focus() and menu.page == "inventory", "...and over a rail item, without opening its page")
	# A slot press opens its card: the focus goes to its first button; B comes back.
	for i in 2:
		p.add_item("draught")
	p.hp = p.max_hp * 0.5
	menu.open("inventory")
	await _frames(3)
	var dr = menu._slot_control("item:draught")
	dr.grab_focus()
	await _frames(1)
	var n0: int = p.item_count("draught")
	await _key_tap(KEY_ENTER)
	var f: Control = _focus_now()
	_check(f is Button and menu.details.is_ancestor_of(f) and f.text == "Use" and p.item_count("draught") == n0, "Enter on a slot puts the focus on its card's first button (Use), using nothing yet")
	await _pad_tap(JOY_BUTTON_B)
	_check(menu.page == "inventory" and menu._slot_control("item:draught").has_focus(), "B from the card comes back to its slot")
	main.pad._set_active(false)
	await _key_tap(KEY_ENTER)
	await _key_tap(KEY_ENTER)
	_check(p.item_count("draught") == n0 - 1, "...and a second press uses the item")
	# Mouse and touch: one press shows, a second uses (the same as the keys).
	p.hp = p.max_hp * 0.5
	menu.inv_sel = "gear:melee"
	menu.open("inventory")
	await _frames(3)
	n0 = p.item_count("draught")
	var at: Vector2 = menu._slot_control("item:draught").get_global_rect().get_center()
	_mouse_move(at)
	await _frames(2)
	_mouse_button(at, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_mouse_button(at, MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	_check(p.item_count("draught") == n0 and menu.inv_sel == "item:draught", "one click on an item shows it, using nothing")
	_mouse_button(at, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_mouse_button(at, MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	_check(p.item_count("draught") == n0 - 1, "...a second click uses it")
	# A right-click goes back one level.
	menu.open("pause")
	await _frames(2)
	menu.open("settings")
	await _frames(3)
	var sl = _focus_now()
	_check(sl is HSlider and not sl.scrollable, "the settings' sliders don't take the mouse wheel (the page scrolls)")
	_mouse_button(menu.panel.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, true)
	await _frames(1)
	_mouse_button(menu.panel.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	_check(menu.page == "settings" and rail.has_focus_inside(), "a right-click goes back one level (from the page to the rail)")
	# The Start over question starts on Cancel; Esc goes back to where you were.
	menu.open("settings")
	await _frames(2)
	var over_list: Array = menu.focusables().filter(func(b): return b.has_meta("over"))
	if not over_list.is_empty():
		over_list[0].grab_focus()
	await _frames(1)
	await _key_tap(KEY_ENTER)
	await _frames(2)
	_check(menu.page == "confirm_new" and _focus_now() != null and _focus_now().has_meta("cancel"), "Start over asks first, with the focus on Cancel")
	await _key_tap(KEY_ESCAPE)
	await _until(func(): return _focus_now() != null and _focus_now().has_meta("over"), 1.0)
	_check(menu.page == "settings" and _focus_now() != null and _focus_now().has_meta("over"), "...and Esc goes back onto Start over, nothing lost")
	menu.close()
	await _frames(2)
	# The store car: Enter on a shelf slot reaches its Buy; Left comes back.
	main.open_train()
	await _frames(4)
	menu.train_page.go_to(menu.train_page._index("store"))
	await _frames(6)
	var d = menu._slot_control("supply:draught")
	d.grab_focus()
	await _frames(1)
	await _key_tap(KEY_ENTER)
	f = _focus_now()
	_check(f is Button and menu.details.is_ancestor_of(f) and menu.inv_sel == "supply:draught", "in the store, Enter on a shelf puts the focus on that item's card (%s)" % (f.text if f is Button else f))
	await _key_tap(KEY_LEFT)
	_check(menu._slot_control("supply:draught") != null and menu._slot_control("supply:draught").has_focus(), "...and Left comes back to its slot")
	# B from a car goes back to the train's rail, on that car (the rail is
	# the train's menu); B there does nothing more.
	await _pad_tap(JOY_BUTTON_B)
	await _until(func(): return rail.button("store").has_focus(), 1.0)
	_check(menu.page == "train" and rail.button("store").has_focus(), "B in a car goes back to the train's rail, on that car")
	await _pad_tap(JOY_BUTTON_B)
	_check(menu.page == "train" and rail.button("store").has_focus(), "...and B on the rail stays there")
	# Hovering a car on the rail moves the focus but doesn't slide the train.
	_mouse_move(rail.button("workshop").get_global_rect().get_center() + Vector2(0, -6))  # (the first move hands control to the mouse)
	await _frames(2)
	_mouse_move(rail.button("workshop").get_global_rect().get_center())
	await _frames(2)
	_check(rail.button("workshop").has_focus() and menu.train_car == "store", "hovering a car on the rail moves the focus there, without moving the train")
	main.pad._set_active(false)
	menu.close()
	await _frames(3)
	main.on_train = false
	# The title's list wraps round.
	menu.open("title")
	await _frames(3)
	var tl: Array = menu.focusables()
	tl[0].grab_focus()
	await _frames(1)
	await _key_tap(KEY_UP)
	_check(tl[tl.size() - 1].has_focus(), "Up from the title's first button wraps round to the last")
	menu.close()
	await _frames(2)
	# Prompts follow the input.
	main.touch._set_active(true)
	_check(Nav.fill("{again} to sell", main) == "Tap again to sell", "on a phone a second press says Tap again")
	main.touch._set_active(false)
	_check(Nav.fill("{again} to sell", main) == "Press again to sell", "...and with keys or a controller, Press again")
	main.pad._set_active(true)
	menu.open("pause")
	await _frames(2)
	_check(rail.buttons.all(func(b): return not String(b.key_hint).contains("{")), "the rail's prompts show no raw placeholders with a controller")
	menu.open("climber")
	await _frames(3)
	main.pad._set_active(false)
	var shown := func(t: String): return _all_labels(menu).any(func(l): return l.text == t and l.is_visible_in_tree())
	await _until(func(): return shown.call("Q"), 1.0)
	_check(shown.call("Q") and not shown.call("LB"), "switching to the keyboard mid-page, the page's prompts change to keys at once")
	menu.close()
	await _frames(2)
	# On a phone, a tap doesn't leave a focus highlight on the page.
	main.touch._set_active(true)
	menu.open("pause")
	await _frames(2)
	await _tap_at(rail.button("settings").get_global_rect().get_center())
	_check(menu.page == "settings" and _focus_now() == null, "on a phone, tapping a page open leaves no focus highlight")
	menu.close()
	await _frames(2)
	main.touch._set_active(false)
	# Rings: time stops while one is open, and they draw over the touch buttons,
	# beside the thumb (never under it).
	_check(main.hud.rings != null and main.hud.rings.z_index > main.touch.z_index and main.hud.rings.z_index > 0, "the spell and item rings draw over the touch buttons")
	if main.secret_tools != null and main.secret_tools.ring_screen != null:
		_check(main.secret_tools.ring_screen.z_index > main.touch.z_index, "...and the tool ring too")
	var view := Vector2(800, 400)
	var ok := true
	for thumb in [Vector2(700, 300), Vector2(760, 360), Vector2(620, 380), Vector2(740, 120), Vector2(100, 300)]:
		var c: Vector2 = Nav.ring_center(thumb, 112.0, view, 46.0, 90.0)
		if c.distance_to(thumb) < 112.0 + 46.0 - 1.0:
			ok = false
			print("    ring at ", c, " covers the thumb at ", thumb)
	_check(ok, "on a phone a ring sits beside the thumb that holds its button, never under it")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	p = main.player
	p.mouse_aim = false
	p.add_item("tonic")
	p.add_item("haste")
	p.add_item("draught")
	Input.action_press("use_item")
	await _until(func(): return p.ring_open, 1.5)
	_check(p.ring_open and Engine.time_scale == 0.0, "an open ring stops time completely (%.2f)" % Engine.time_scale)
	Input.action_release("use_item")
	await _until(func(): return not p.ring_open, 1.5)
	_check(not p.ring_open and Engine.time_scale == 1.0, "...and letting go starts it again")


func _climber_slot_tests() -> void:
	print("climber slots")
	var S = load("res://scripts/slots.gd")
	var P = load("res://scripts/profile.gd")
	var A = load("res://scripts/appearance.gd")
	var G = load("res://scripts/gear.gd")
	var Guide = load("res://scripts/guide.gd")
	var CP = load("res://scripts/climbers_page.gd")
	var M = load("res://scripts/menu.gd")
	_clear_slots()
	await _fresh_main()
	var menu = main.menu
	main.touch._set_active(false)
	_check(S.path(1) != "user://climber_1.cfg" and S.settings_path() != "user://sixfold.cfg", "tests use their own slot files, never the real saves")
	_check(S.MAX == 6 and S.filled().is_empty() and S.first_empty() == 1 and S.current() == 1, "six slots, all empty at first, slot 1 current")
	# Two climbers, each in their own file.
	var a = _slot_climber(1, "Wren", {"hand": "stormcaller"}, ["fire", 40.0])
	a.chest = [G.rec("axe")]
	a.appearance["cloak"] = "crimson"
	a.best_floor = 5
	a.saving = true
	a.save()
	a.saving = false
	_slot_climber(2, "Bryn", {"legs": "windwalker", "brow": "warden"}, ["water", 7.0])
	_check(S.filled() == [1, 2] and S.first_empty() == 3, "two climbers fill slots 1 and 2")
	var a2 = S.peek(1)
	var b2 = S.peek(2)
	_check(a2.bonds.keys() == ["hand"] and a2.crystal_total("fire") == 40.0 and a2.chest.size() == 1 and a2.appearance["name"] == "Wren" and a2.appearance["cloak"] == "crimson" and a2.best_floor == 5, "slot 1 loads its own climber (marks, crystals, chest, look)")
	_check(b2.bonds.size() == 2 and b2.crystal_total("fire") == 0.0 and b2.crystal_total("water") == 7.0 and b2.chest.is_empty() and b2.appearance["name"] == "Bryn", "...and slot 2 its own")
	a2.saving = true
	a2.add_crystal("fire", 10.0)
	a2.save()
	_check(S.peek(1).crystal_total("fire") == 50.0 and S.peek(2).crystal_total("fire") == 0.0 and S.peek(2).crystal_total("water") == 7.0, "saving one climber leaves the other's file alone")
	# The Entity's tips and Archive, per climber; tips on or off, shared.
	Guide.state["told"] = {"move": true}
	Guide.state["known"] = {"move": true}
	Guide.save_to(S.path(1))
	Guide.state["on"] = false
	Guide.save_on(S.settings_path())
	Guide.load_from(S.settings_path(), S.path(2))
	_check(Guide.state["told"].is_empty() and Guide.state["known"].is_empty() and not Guide.state["on"], "a second climber hears the tips again (their own Archive), tips off is shared")
	Guide.load_from(S.settings_path(), S.path(1))
	_check(Guide.state["told"].has("move") and Guide.state["known"].has("move"), "...and the first remembers what was said")
	Guide.forget()
	Guide.loaded_from = ""
	# Settings live in the shared file, never in a climber's.
	var keep_condense = M.settings["condense"]
	M.settings["condense"] = "35"
	M.save_settings_to(S.settings_path())
	var c1 := ConfigFile.new()
	c1.load(S.path(1))
	_check(not c1.has_section("settings") and not c1.has_section_key("guide", "on") and c1.has_section_key("slot", "played"), "settings stay out of a climber's file (which notes when they last played)")
	# Switching swaps everything.
	main.switch_climber(2)
	await _frames(2)
	var prof = main.profile
	_check(S.current() == 2 and prof.save_path == S.path(2) and prof.appearance["name"] == "Bryn" and prof.bonds.size() == 2 and main.player.bonds.has("legs") and prof.crystal_total("fire") == 0.0, "switching to slot 2 plays its climber (marks, crystals)")
	_check(main.climber_look == A.look(prof.appearance) and prof.chest.is_empty() and M.settings["condense"] == "35", "...in their own look and train, the settings unchanged")
	Engine.remove_meta("sixfold_title_seen")
	S.forget()
	_check(S.current() == 2, "the slot played last is remembered")
	prof.saving = true
	prof.add_crystal("water", 3.0)
	prof.save()
	prof.saving = false
	_check(S.peek(2).crystal_total("water") == 10.0 and S.peek(1).crystal_total("water") == 0.0 and S.peek(1).crystal_total("fire") == 50.0, "the climber played saves only into their own slot")
	M.settings["condense"] = keep_condense
	# The title: Climbers, naming the current climber.
	main.choosing_tower = true
	menu.open("title")
	await _frames(2)
	var cb: Array = _all_buttons(menu).filter(func(x): return x.has_meta("climbers"))
	_check(cb.size() == 1 and cb[0].text == CP.TEXT["button_named"] % "Bryn", "the title has Climbers, naming the current climber")
	_check(_menu_button(CP.TEXT["over"]) != null and _menu_button("New climber") == null, "...and Start over (this climber only)")
	if cb.size() == 1:
		cb[0].pressed.emit()
	await _frames(2)
	var cards: Array = _all_buttons(menu).filter(func(x): return x.has_meta("climber_slot"))
	_check(menu.page == "climbers" and menu.backdrop.visible and cards.size() == 6, "Climbers opens the picker over the title: six slots")
	var dels: Array = _all_buttons(menu).filter(func(x): return x.has_meta("climber_delete"))
	_check(dels.size() == 2 and cards.filter(func(x): return x.prof == null).size() == 4, "...two climbers (each with Delete) and four empty")
	await _until(func(): return cards[1].has_focus(), 1.0)
	_check(cards[1].has_focus(), "keys and controller start on the current climber")
	await _key_tap(KEY_LEFT)
	_check(cards[0].has_focus(), "Left moves to the next card")
	await _key_tap(KEY_ENTER)
	await _frames(2)
	_check(S.current() == 1 and main.profile.appearance["name"] == "Wren" and main.profile.crystal_total("fire") == 50.0 and not menu.is_open(), "Enter on a card plays that climber")
	Engine.remove_meta("sixfold_title_seen")
	# A tap on an empty slot: a new climber there, who chooses a look first.
	main.touch._set_active(true)
	menu.open("title")
	await _frames(2)
	menu.open("climbers")
	await _frames(3)
	cards = _all_buttons(menu).filter(func(x): return x.has_meta("climber_slot"))
	var vis := root.get_visible_rect()
	_check(cards.all(func(x): return x.get_global_rect().position.x >= vis.position.x and x.get_global_rect().end.x <= vis.end.x), "on a phone the cards fit across the screen")
	menu.scroll.ensure_control_visible(cards[4])
	await _frames(2)
	await _tap_at(cards[4].get_global_rect().get_center())
	await _until(func(): return menu.page == "create", 1.0)
	_check(S.current() == 5 and menu.page == "create" and not main.profile.created and main.profile.bonds.is_empty() and main.profile.crystals.is_empty(), "a tap on an empty slot starts a new climber there: the appearance page")
	main.profile.saving = true  # (tests: let this climber save, into its test slot)
	menu.look_page.begin()
	main.profile.saving = false
	await _frames(2)
	_check(S.exists(5) and S.filled() == [1, 2, 5] and not main.profile.regarded, "...whose Begin saves them in that slot, for the bondless first climb")
	Engine.remove_meta("sixfold_title_seen")
	main.touch._set_active(false)
	# Six full: no seventh. Delete asks twice and removes only that climber.
	for i in [3, 4, 6]:
		_slot_climber(i, "C%d" % i, {}, [])
	_check(S.filled().size() == 6 and S.first_empty() == 0 and not main.switch_climber(7) and S.current() == 5, "with six climbers there's no empty slot, and no seventh")
	menu.open("title")
	menu.open("climbers")
	await _frames(2)
	cards = _all_buttons(menu).filter(func(x): return x.has_meta("climber_slot"))
	_check(cards.size() == 6 and cards.all(func(x): return x.prof != null), "...the picker shows six climbers")
	var del4: Array = _all_buttons(menu).filter(func(x): return int(x.get_meta("climber_delete", 0)) == 4)
	if del4.size() == 1:
		del4[0].pressed.emit()
	await _frames(2)
	del4 = _all_buttons(menu).filter(func(x): return int(x.get_meta("climber_delete", 0)) == 4)
	_check(S.exists(4) and del4.size() == 1 and del4[0].text == load("res://scripts/nav.gd").fill(CP.TEXT["delete_again"], main), "Delete asks again first (nothing is deleted yet)")
	if del4.size() == 1:
		del4[0].pressed.emit()
	await _frames(2)
	_check(not S.exists(4) and S.filled() == [1, 2, 3, 5, 6] and S.current() == 5 and menu.page == "climbers", "a second press deletes only that climber")
	_check(S.peek(1).crystal_total("fire") == 50.0 and S.peek(2).bonds.size() == 2, "...the others are untouched")
	# Deleting the climber being played: whoever played last is current.
	main.delete_climber(5)
	await _frames(2)
	_check(not S.exists(5) and S.exists(S.current()) and main.profile.save_path == S.path(S.current()) and menu.page == "climbers", "deleting the current climber moves on to another, on the picker")
	menu.close()
	Engine.remove_meta("sixfold_title_seen")
	# An old single save (from before slots) moves into slot 1, whole.
	_clear_slots()
	var old := ConfigFile.new()
	old.set_value("climb", "best_floor", 5)
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "bonds", {"brow": {"debt": 0.0, "faint": false, "id": "warden", "xp": 540.0}, "hand": {"debt": 0.0, "faint": false, "id": "stormcaller", "xp": 160.0}})
	old.set_value("profile", "climbs", 4)
	old.set_value("profile", "crystals", [{"kind": "fire", "amount": 30.0}])
	old.set_value("profile", "record", {"deaths": 1.0})
	old.set_value("profile", "path", "life")
	old.set_value("profile", "flow", 12.0)
	old.set_value("train", "chest", [G.rec("axe")])
	old.set_value("train", "supplies", {"tonic": 2})
	old.set_value("guide", "on", false)
	old.set_value("guide", "known", {"move": true, "train": true})
	old.set_value("guide", "told", {"move": true})
	old.set_value("makers", "state", {"interest": {"developer": 2}})
	old.set_value("look", "appearance", {"name": "Old", "cloak": "plum"})
	old.set_value("look", "created", true)
	old.set_value("unbound", "state", {"on": false})
	old.set_value("settings", "condense", "35")
	old.set_value("settings", "music", 0.4)
	old.set_value("pad", "layouts", {"Some pad": {"a": 1}})
	old.save(S.settings_path())
	S.forget()
	_check(S.current() == 1 and S.filled() == [1], "an old single save moves into slot 1")
	var raw := ConfigFile.new()
	raw.load(S.path(1))
	var same := true
	for sec in old.get_sections():
		for key in old.get_section_keys(sec):
			var climbers: bool = not (sec in ["settings", "pad"]) and not (sec == "guide" and key == "on")
			if climbers and raw.get_value(sec, key, null) != old.get_value(sec, key):
				same = false
			if not climbers and raw.has_section_key(sec, key):
				same = false
	_check(same, "...every value of the climber's untouched, and nothing shared in it")
	var m = S.peek(1)
	_check(m.created and m.regarded and m.bonds.size() == 2 and m.crystal_total("fire") == 30.0 and m.chest.size() == 1 and m.path == "life" and m.appearance["name"] == "Old" and m.climbs == 4 and m.best_floor == 5, "...and it loads as the same climber")
	var st := ConfigFile.new()
	st.load(S.settings_path())
	_check(st.get_value("settings", "condense", "") == "35" and st.has_section("pad") and st.get_value("guide", "on", true) == false and not st.has_section("profile") and not st.has_section("train") and not st.has_section_key("guide", "told"), "...the settings file keeps only what's shared (settings, controller, tips on or off)")
	var bak := ConfigFile.new()
	_check(bak.load(S.backup_path()) == OK and bak.get_value("profile", "climbs", 0) == 4 and bak.get_value("settings", "music", 0.0) == 0.4, "...and a copy of the old file is kept as it was")
	Guide.load_from(S.settings_path(), S.path(1))
	_check(Guide.state["told"].has("move") and Guide.state["known"].size() == 2 and not Guide.state["on"], "...with what the Entity had said")
	Guide.forget()
	Guide.loaded_from = ""
	var before := FileAccess.get_file_as_string(S.path(1))
	S.forget()
	S.migrate()
	_check(FileAccess.get_file_as_string(S.path(1)) == before and S.filled() == [1], "it moves only once")
	# A file of settings alone (no climber yet) makes no climber.
	_clear_slots()
	var only := ConfigFile.new()
	only.set_value("settings", "music", 0.5)
	only.save(S.settings_path())
	S.forget()
	_check(S.current() == 1 and S.filled().is_empty(), "a save with only settings makes no climber (a brand-new player)")
	_clear_slots()
	await _fresh_main()


## The item and gear icons (icon_art.gd): every one draws, a cached icon is
## the same picture moved, and finer gear glows in its rarity's colour.
func _icon_tests() -> void:
	print("icons")
	var Art = load("res://scripts/icon_art.gd")
	var I = load("res://scripts/items.gd")
	var G = load("res://scripts/gear.gd")
	var D = load("res://scripts/draw_util.gd")
	var empty: Array = []
	for id in I.ORDER:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			I.icon_into(b, id, Vector2.ZERO, s)
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [id, s])
	for id in G.PIECE_ORDER + G.Weapons.ORDER + ["padded", "leather", "chain", "plate"]:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			G.icon_into(b, id, Vector2.ZERO, s, G.color(id))
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [id, s])
	for n in G.NAMED_ORDER:
		var b = D.Batch.new()
		G.icon_into(b, G.make_named(n), Vector2.ZERO, 18.0, G.color(G.make_named(n)))
		if b.pts.is_empty():
			empty.append(n)
	_check(empty.is_empty(), "every item, weapon, piece and named piece draws an icon at HUD, slot and card size %s" % [empty])
	var a = D.Batch.new()
	G.icon_into(a, G.make("axe", "fine", ["edges"], 2, "", "sharpness"), Vector2.ZERO, 18.0, Color.WHITE)
	var m = D.Batch.new()
	G.icon_into(m, G.make("axe", "fine", ["edges"], 2, "", "sharpness"), Vector2(30, 40), 18.0, Color.WHITE)
	_check(a.pts.size() == m.pts.size() and m.pts[0].is_equal_approx(a.pts[0] + Vector2(30, 40)) and a.cols == m.cols, "a cached icon is the same picture, moved")
	var plain = D.Batch.new()
	G.icon_into(plain, G.make("sword"), Vector2.ZERO, 18.0, Color.WHITE)
	var glow = D.Batch.new()
	G.icon_into(glow, G.make("sword", "rare", ["edges", "hunt"]), Vector2.ZERO, 18.0, Color.WHITE)
	var blue: Color = G.rarity_color(G.make("sword", "rare"))
	_check(glow.pts.size() > plain.pts.size() and glow.cols[0].is_equal_approx(Color(blue, glow.cols[0].a)), "finer gear glows in its rarity's colour behind its icon; Common doesn't")
	var faded = D.Batch.new()
	G.icon_into(faded, G.make("sword"), Vector2.ZERO, 18.0, Color(1, 1, 1, 0.5))
	_check(faded.cols.size() == plain.cols.size() and is_equal_approx(faded.cols[faded.cols.size() - 1].a, plain.cols[plain.cols.size() - 1].a * 0.5), "a faded colour fades the icon")
	_check(Art.ol(10.5) < Art.ol(40.0) and Art.detail(10.5) == 0 and Art.detail(40.0) == 2, "outlines and detail scale with the icon's size")


## A mouse move with the left button held (Shift: Arrange mode places freely).
func _mouse_drag_to(pos: Vector2, shift := false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.relative = Vector2(6, 6)
	ev.shift_pressed = shift
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _near(a: Vector2, b: Vector2, by := 0.6) -> bool:
	return a.distance_to(b) <= by


## The touch button with this id (as touch.gd lays them out now).
func _touch_btn(id: String) -> Dictionary:
	main.touch._layout()
	for b in main.touch.buttons:
		if b["id"] == id:
			return b
	return {}


## The layout registry and Arrange mode (layout.gd, arrange.gd).
func _arrange_tests() -> void:
	print("the layout and Arrange mode")
	await _fresh_main()
	var L = load("res://scripts/layout.gd")
	var keep_paths := [L.user_path, L.project_path, L.write_project]
	L.user_path = "user://smoke_layout.cfg"
	L.project_path = "user://smoke_layout.json"  # (never the repository's own file)
	L.write_project = false
	for f in [L.user_path, L.project_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	L.clear_state()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var p = main.player
	p.add_item("tonic")
	for e in main.enemies():
		e.set_physics_process(false)
	await _frames(3)
	var hud = main.hud
	var view: Vector2 = hud.get_viewport_rect().size

	# The defaults are today's layout.
	_check(FileAccess.file_exists(L.PROJECT_PATH) and L.parse(FileAccess.get_file_as_string(L.PROJECT_PATH)) != null, "the shared defaults file (data/layout.json) is there and reads")
	_check(L.box("hud.bars", view) == Rect2(hud.BAR_X - 4, hud.BAR_Y - 4, hud.BAR_W + 8, 32) and L.box("hud.weapon", view) == Rect2(hud.BAR_X, hud.ROW_Y, hud.SLOT, hud.SLOT) \
		and L.box("hud.item", view) == Rect2(hud.BAR_X + hud.SLOT + 6, hud.ROW_Y, hud.SLOT, hud.SLOT), "the registry's defaults are the HUD's own places")
	_check(L.box("hud.stair", view) == Rect2(40, 104, view.x - 80, view.y - 144), "the stair arrow's ring is the screen less its margins")
	var all_still := true
	for id in L.ids("desktop") + L.ids("touch"):
		if L.xform(id, view) != Transform2D.IDENTITY:
			all_still = false
	_check(all_still, "with no arrangement nothing moves (every transform is the identity)")
	var wtip: Array = hud.tips.filter(func(t): return t[1] == main.Gear.display(p.weapon))
	_check(wtip.size() == 1 and wtip[0][0] == Rect2(hud.BAR_X, hud.ROW_Y, hud.SLOT, hud.SLOT), "the weapon's tooltip is where it always was")
	main.touch._set_active(true)
	await _frames(2)
	_check(L.active_set == "touch", "a touch switches to the phone's layout")
	var tv: Vector2 = main.touch.get_viewport_rect().size
	var old := {"attack": [Vector2(-130, -130), 62.0, true], "jump": [Vector2(-36, -36), 30.0, true], "item_next": [Vector2(-478, -48), 22.0, true],
		"fullscreen": [Vector2(-40, 40), 24.0, false], "inventory": [Vector2(-236, 40), 26.0, false], "cast_hand": [Vector2(-282, -222), 34.0, true], "cast_legs": [Vector2(-52, -262), 34.0, true]}
	var same := true
	for id in old:
		var b := _touch_btn(id)
		var corner: Vector2 = tv if old[id][2] else Vector2(tv.x, 0)
		if b.is_empty() or not _near(b["c"], corner + old[id][0] * 0.75, 0.01) or absf(b["r"] - old[id][1] * 0.75) > 0.01:
			same = false
			print("    moved: ", id, " ", b)
	_check(same, "the touch buttons are where they always were")
	_check(main.touch.stick_zone() == Rect2(0, 0, tv.x * 0.5, tv.y), "the joystick starts anywhere on the left half")

	# An arrangement moves an element, and its touch hit area goes with it.
	L.set_override("touch.attack", {"anchor": "bl", "x": 120.0, "y": -40.0, "scale": 1.0})
	var atk := _touch_btn("attack")
	var want := Vector2(120.0 + 46.5, tv.y - 40.0 - 46.5)
	_check(_near(atk["c"], want) and absf(atk["r"] - 46.5) < 0.01, "an arranged attack button sits where it was put (%s)" % atk["c"])
	await _frames(2)
	_touch(5, atk["c"], true)
	await _frames(2)
	_check(Input.is_action_pressed("attack"), "...and a tap there presses attack")
	_touch(5, atk["c"], false)
	await _frames(2)
	_check(not Input.is_action_pressed("attack") and main.touch.stick_touch == -1, "...and lets go (the joystick didn't take it)")
	_touch(5, tv + Vector2(-130, -130) * 0.75, true)
	await _frames(2)
	_check(not Input.is_action_pressed("attack"), "its old place doesn't press attack any more")
	_touch(5, tv + Vector2(-130, -130) * 0.75, false)
	await _frames(2)
	L.use_set("desktop")
	_check(not L.moved("touch.attack"), "the computer's layout keeps its own arrangement")
	L.use_set("touch")
	_check(L.moved("touch.attack"), "...and the phone's keeps the move")
	# The limits: on screen, and touch buttons tappable.
	L.set_override("touch.item_next", {"anchor": "br", "x": 900.0, "y": 900.0, "scale": 0.05})
	var nb: Rect2 = L.box("touch.item_next", tv)
	_check(nb.size.x * main.touch.PHONE_SCALE >= 44.0 - 0.01 and Rect2(Vector2.ZERO, tv).encloses(nb), "a touch button stays on screen and at least 44 px across on the phone (%s)" % nb)
	L.move_to("touch.jump", Rect2(-300, -300, 4, 4), tv)
	var jb: Rect2 = L.box("touch.jump", tv)
	_check(Rect2(Vector2.ZERO, tv).encloses(jb) and jb.size.x >= L.MIN_TOUCH - 0.01, "...however it's dragged")
	main.touch._set_active(false)
	await _frames(2)
	L.set_override("hud.weapon", {"anchor": "br", "x": -20.0, "y": -20.0, "scale": 2.0})
	await _frames(3)
	wtip = hud.tips.filter(func(t): return t[1] == main.Gear.display(p.weapon))
	_check(wtip.size() == 1 and _near(wtip[0][0].position, view - Vector2(88, 88)) and _near(wtip[0][0].size, Vector2(68, 68)), "an arranged HUD slot moves and scales, its tooltip with it (%s)" % [wtip[0][0] if wtip.size() > 0 else "none"])
	_check(_near(L.box("hud.weapon", Vector2(1000, 600)).end, Vector2(980, 580)), "pinned to a corner, it keeps its place on another screen size")
	hud.hud_scale = 1.2
	await _frames(3)
	wtip = hud.tips.filter(func(t): return t[1] == main.Gear.display(p.weapon))
	_check(wtip.size() == 1 and _near(wtip[0][0].end * 1.2, view - Vector2(24, 24), 1.0), "...and with a larger HUD size")
	hud.hud_scale = 1.0
	L.set_override("hud.weapon", {"anchor": "tl", "x": -5000.0, "y": -5000.0, "scale": 1.0})
	var wb: Rect2 = L.box("hud.weapon", view)
	_check(wb.end.x >= L.KEEP_ON - 0.01 and wb.end.y >= L.KEEP_ON - 0.01, "an element can't go wholly off screen")

	# Saving and loading: user://, the two sets apart.
	L.clear_state()
	L.use_set("desktop")
	L.set_override("hud.bars", {"anchor": "bl", "x": 10.0, "y": -10.0, "scale": 1.25})
	L.use_set("touch")
	L.set_override("touch.roll", {"anchor": "br", "x": -200.0, "y": -10.0, "scale": 1.5})
	L.use_set("desktop")
	_check(L.dirty(), "an unsaved change is noticed")
	var res: Dictionary = L.save()
	_check(res["user"] and res["project"] == null and not L.dirty() and FileAccess.file_exists(L.user_path), "Save writes user:// (and not the shared defaults outside the editor)")
	var cfg := ConfigFile.new()
	cfg.load(L.user_path)
	var cd: Dictionary = cfg.get_value("layout", "desktop", {})
	var ct: Dictionary = cfg.get_value("layout", "touch", {})
	_check(cd.has("hud.bars") and not cd.has("touch.roll") and ct.has("touch.roll") and not ct.has("hud.bars"), "the computer's and the phone's arrangements are saved apart")
	var snap: Dictionary = L.snapshot()
	L.clear_state()
	L.load_all(true)
	_check(L.snapshot() == snap and not L.dirty(), "...and load back the same")
	# Run from the editor, Save writes the shared defaults too.
	L.write_project = true
	res = L.save()
	_check(res["project"] == true and L.parse(FileAccess.get_file_as_string(L.project_path)) == snap, "from the editor, Save writes the shared defaults file too")
	cfg = ConfigFile.new()
	cfg.load(L.user_path)
	_check((cfg.get_value("layout", "desktop", {"x": 1}) as Dictionary).is_empty(), "...and the player's own file keeps only what differs from it")
	L.write_project = false
	L.load_all(true)
	_check(L.snapshot() == snap, "the shared defaults load as the starting arrangement")
	# Reset: back to the shared defaults (two presses in Arrange mode, below).
	L.set_override("hud.bars", {"anchor": "tl", "x": 300.0, "y": 300.0, "scale": 1.0})
	L.reset("hud.bars")
	_check(L.get_override("hud.bars") == snap["desktop"]["hud.bars"], "Reset this puts an element back to its default")
	L.set_override("hud.marks", {"anchor": "tl", "x": 300.0, "y": 300.0, "scale": 1.0})
	L.reset_all()
	_check(L.snapshot()["desktop"] == snap["desktop"], "Reset all puts them all back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(L.project_path))
	# Copy layout: valid JSON that loads back.
	L.restore(snap)
	var text: String = L.to_json()
	var parsed = JSON.parse_string(text)
	_check(parsed is Dictionary and int(parsed.get("format", 0)) == 1 and parsed["desktop"].has("hud.bars") and parsed["touch"].has("touch.roll"), "Copy layout gives valid JSON with both sets")
	L.clear_state()
	_check(L.load_json(text) and L.snapshot() == snap, "...that loads back the same arrangement")
	_check(not L.load_json("not a layout") and not L.load_json("{\"desktop\": {\"hud.bars\": {\"anchor\": \"nowhere\"}}}") and L.snapshot() == snap, "...and nonsense is refused")
	L.clear_state()

	# Arrange mode: opens from Dev tools and pauses.
	var ar = main.arrange
	var menu = main.menu
	menu.open("dev")
	await _frames(3)
	var ab := _menu_button("Arrange layout")
	_check(ab != null, "Dev tools has Arrange layout")
	if ab != null:
		ab.pressed.emit()
	await _frames(3)
	_check(ar.is_open and paused and not main.menu_open() and not menu.visible, "Arrange layout opens Arrange mode, pauses the game and hides the menu")
	_check(ar.redraws > 0 and ar.sel != "" and ar.toolbar()["buttons"].size() == 9, "it outlines the elements and shows its toolbar")
	# Drag by mouse: snaps to the grid.
	ar.sel = ""
	var wr: Rect2 = ar.screen_rect("hud.weapon")
	var from := wr.get_center()
	_mouse_button(from, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_check(ar.sel == "hud.weapon" and ar.drag.get("kind", "") == "move", "pressing on the weapon slot picks it up")
	_mouse_drag_to(from + Vector2(203, 157))
	await _frames(2)
	var moved: Rect2 = ar.screen_rect("hud.weapon")
	var on_grid: bool = (fmod(moved.position.x, 8.0) == 0.0 or ar.guides.any(func(g): return g[0] == "x")) and (fmod(moved.position.y, 8.0) == 0.0 or ar.guides.any(func(g): return g[0] == "y"))
	_check(on_grid and moved.position.distance_to(wr.position + Vector2(203, 157)) < 10.0, "dragging it moves it, onto the 8 px grid or a guide (%s)" % moved.position)
	# Near the centre line it sticks there, with a guide.
	_mouse_drag_to(from + Vector2(view.x * 0.5 - wr.get_center().x + 3.0, 157))
	await _frames(2)
	moved = ar.screen_rect("hud.weapon")
	_check(absf(moved.get_center().x - view.x * 0.5) < 0.01 and ar.guides.any(func(g): return g[0] == "x" and absf(g[1] - view.x * 0.5) < 0.01), "near the centre line it snaps to it and shows a guide")
	_mouse_drag_to(from + Vector2(203, 157) + Vector2(3, 3), true)
	await _frames(2)
	moved = ar.screen_rect("hud.weapon")
	_check(_near(moved.position, wr.position + Vector2(206, 160), 0.2), "Shift places it freely (%s)" % moved.position)
	_mouse_button(from + Vector2(206, 160), MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	_check(ar.drag.is_empty() and ar.guides.is_empty() and L.moved("hud.weapon"), "letting go drops it there")
	wtip = hud.tips.filter(func(t): return t[1] == main.Gear.display(p.weapon))
	_check(wtip.size() == 1 and _near(wtip[0][0].position, moved.position, 0.2), "the HUD redraws there while paused, its tooltip with it")
	# Scale by a corner handle (it keeps its shape).
	var corner: Vector2 = moved.end
	_mouse_button(corner, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_check(ar.drag.get("kind", "") == "scale", "pressing a corner handle starts scaling")
	_mouse_drag_to(corner + Vector2(34, 20))
	await _frames(2)
	_mouse_button(corner + Vector2(34, 20), MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	var scaled: Rect2 = ar.screen_rect("hud.weapon")
	_check(_near(scaled.size, Vector2(68, 68), 0.5) and _near(scaled.position, moved.position, 0.5), "pulling the corner doubles it, square, from the opposite corner (%s)" % scaled)
	ar.do_undo()
	_check(_near(ar.screen_rect("hud.weapon").size, Vector2(34, 34), 0.5), "Undo takes the scaling back")
	# Touch: the phone's layout, a finger drags a button.
	ar.switch_set()
	await _frames(3)
	_check(main.touch_active and L.active_set == "touch" and paused, "the toolbar switches to editing the phone's layout (still paused)")
	var rr: Rect2 = ar.screen_rect("touch.roll")
	_touch(0, rr.get_center(), true)
	await _frames(2)
	_drag(0, rr.get_center() + Vector2(-150, -40))
	await _frames(2)
	_touch(0, rr.get_center() + Vector2(-150, -40), false)
	await _frames(2)
	var roll := _touch_btn("roll")
	_check(ar.sel == "touch.roll" and roll["c"].distance_to(rr.get_center() + Vector2(-150, -40)) < 9.0, "a finger drags a touch button, and the button is there (%s)" % roll["c"])
	_check(L.get_override("touch.roll") != null and L.get_override("touch.roll")["anchor"] in ["br", "b", "r", "c", "bl", "l"], "...pinned by the nearest corner or edge")
	# Controller: the d-pad picks the next element, the left stick moves it.
	main.touch._set_active(false)
	ar.sel = L.ids()[0]
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(ar.sel == L.ids()[1], "the d-pad picks the next element (%s)" % ar.sel)
	await _pad_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _pad_tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(ar.sel == L.ids()[1], "RB and LB step along too")
	var before: Rect2 = ar.screen_rect(ar.sel)
	_pad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _wait(0.3)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(3)
	var after: Rect2 = ar.screen_rect(ar.sel)
	_check(after.position.x > before.position.x + 20.0, "the left stick moves it (%.0f -> %.0f)" % [before.position.x, after.position.x])
	_pad_axis(JOY_AXIS_RIGHT_Y, -1.0)
	await _wait(0.3)
	_pad_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await _frames(3)
	_check(ar.screen_rect(ar.sel).size.x > after.size.x * 1.1, "the right stick scales it")
	# Done with unsaved changes asks; Don't save goes back to the last save.
	await _pad_tap(JOY_BUTTON_A)
	_check(ar.is_open and ar.asking, "finishing with unsaved changes asks whether to save")
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	await _pad_tap(JOY_BUTTON_A)
	await _frames(3)
	_check(not ar.is_open and not L.dirty() and not L.moved("hud.weapon"), "Don't save closes it and forgets the changes")
	_check(menu.page == "dev" and menu.visible and paused, "...back on the Dev tools page")
	menu.close()
	await _frames(3)
	main.pad._set_active(false)
	# F2 in play opens it and closes it again.
	await _key_tap(KEY_F2)
	await _frames(2)
	_check(ar.is_open and paused, "F2 opens Arrange mode in play")
	await _key_tap(KEY_F2)
	await _frames(3)
	_check(not ar.is_open and not paused, "...and F2 again closes it (nothing changed, so it doesn't ask)")
	# Copy layout from the toolbar.
	ar.open()
	ar.sel = "hud.marks"
	ar.nudge_scale(0.25)
	ar.press("copy")
	_check(ar.copy_open and ar.copy_box != null and ar.copy_box.text == ar.copy_text and L.parse(ar.copy_text) != null and L.parse(ar.copy_text)["desktop"].has("hud.marks"), "Copy layout shows the arrangement's JSON in a box")
	ar._hide_copy()
	# The two-step reset.
	ar.press("reset_all")
	_check(L.moved("hud.marks") and ar.armed == "reset_all", "Reset all asks for a second press")
	ar.press("reset_all")
	_check(not L.moved("hud.marks"), "...and the second press resets")
	ar.press("done")
	await _frames(3)
	_check(not ar.is_open and not paused, "Done closes it (back as it was saved: nothing to ask)")
	# The Entity explains it, the first time (tips on), in Arrange mode's own card.
	var Guide = load("res://scripts/guide.gd")
	var Entity = load("res://scripts/entity.gd")
	_check(Guide.known("arrange") and Guide.known("arrange_save") and Guide.known("arrange_sets") and Entity.TIPS["arrange"]["group"] == "creator", "the creator tools' tips are readable in the Archive any time")
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	ar.open()
	_check(not ar.card.is_empty() and ar.card["ids"] == ["arrange"] and Guide.told("arrange"), "opening Arrange mode the first time, the Entity explains it")
	await _key_tap(KEY_ENTER)
	_check(ar.card.is_empty() and ar.is_open, "Enter closes the card (and not Arrange mode)")
	ar.press("save")
	_check(not ar.card.is_empty() and ar.card["ids"] == ["arrange_save"], "the first Save: the Entity says how saving becomes permanent")
	ar.card_next(true)
	ar.switch_set()
	_check(not ar.card.is_empty() and ar.card["ids"] == ["arrange_sets"], "the first switch: the phone and computer layouts are apart")
	await _pad_tap(JOY_BUTTON_B)
	_check(ar.card.is_empty(), "B closes it too")
	ar.switch_set()
	ar.press("help")
	_check(ar.card.get("ids", []) == ar.HELP, "the toolbar's ? shows it all again")
	ar.card_next()
	ar.card_next()
	_check(int(ar.card.get("i", -1)) == 2, "...a page at a time (Next)")
	ar.card_next()
	_check(ar.card.is_empty(), "...then closes")
	ar.close()
	await _frames(3)
	ar.open()
	_check(ar.card.is_empty(), "the second time it doesn't say it again")
	ar.close()
	await _frames(3)
	Guide.forget()
	ar.open()
	ar.card_next(true)
	ar.finish()
	_check(not ar.card.is_empty() and ar.card["ids"] == ["arrange_save"] and ar.is_open, "leaving without ever saving: it says how saving works first")
	ar.card_next(true)
	await _frames(3)
	_check(not ar.is_open, "...and then leaves")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	# Tidy up: the built-in layout, the real paths, nothing left on disk.
	L.clear_state()
	L.use_set("desktop")
	for f in [L.user_path, L.project_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	L.user_path = keep_paths[0]
	L.project_path = keep_paths[1]
	L.write_project = keep_paths[2]
## The Data editor (data_registry.gd, data_page.gd): the game's words,
## numbers and colours changed from inside the game, kept in a changes file.
func _data_editor_tests() -> void:
	print("the Data editor")
	await _fresh_main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var Reg = load("res://scripts/data_registry.gd")
	var Items = load("res://scripts/items.gd")
	var Train = load("res://scripts/train.gd")
	var Entity = load("res://scripts/entity.gd")
	var Guide = load("res://scripts/guide.gd")
	var UI = load("res://scripts/ui.gd")
	# With the project's file as shipped (no changes), nothing is changed.
	var shipped = JSON.parse_string(FileAccess.get_file_as_string("res://data/overrides.json"))
	_check(shipped is Dictionary and shipped.get("changes", null) is Dictionary and shipped["changes"].is_empty(), "the project's data/overrides.json ships with no changes")
	_check(Reg.started and Reg.applied.is_empty() and Reg.problems.is_empty() and not Reg.dirty, "...so the game starts exactly as the scripts have it")
	_check(Reg.local_path != Reg.LOCAL_PATH, "tests keep their changes away from the real file")
	# The tests' own files (the project's too: tests never write res://).
	Reg.project_path = "user://test_project_overrides.json"
	Reg.local_path = "user://test_overrides.json"
	Reg.project_write = 0
	for f in [Reg.project_path, Reg.local_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Reg.startup()
	var heal: float = Items.ITEMS["draught"]["heal"]
	var fields: Array = Reg.fields()
	_check(fields.size() > 2000 and Reg.sections_in("words").size() >= 8 and Reg.sections_in("numbers").size() >= 8 and Reg.sections_in("colours").size() >= 5, "the registry offers thousands of fields, in words, numbers and colours (%d)" % fields.size())
	var kinds := {}
	for f in fields:
		kinds[f["kind"]] = true
	_check(kinds.has("text") and kinds.has("number") and kinds.has("colour") and kinds.has("bool"), "...of every kind: words, numbers, colours and on/off")
	_check(Reg.field("items/ITEMS/draught/kind").is_empty() and Reg.field("items/ITEMS/draught/name")["kind"] == "text" and Reg.field("items/ITEMS/draught/heal")["kind"] == "number", "ids the code looks up aren't offered; names and numbers are")
	# Applying by path changes the table itself.
	_check(Reg.set_value("items/ITEMS/draught/heal", 45) == "" and is_equal_approx(Items.ITEMS["draught"]["heal"], 45.0), "a change by path writes into the table (items/ITEMS/draught/heal = 45)")
	_check(Reg.is_changed("items/ITEMS/draught/heal") and is_equal_approx(Reg.default_of("items/ITEMS/draught/heal"), heal) and Reg.dirty, "...and remembers the default")
	_check(Reg.set_value("ui/GOLD", "#ff8800") == "" and UI.GOLD.is_equal_approx(Color.html("#ff8800")) and main.menu.GOLD.is_equal_approx(UI.GOLD), "a single value too (ui/GOLD), and the menus' copy of it follows")
	_check(Reg.set_value("palette/TOWER_TINT/kraken", Color(0.5, 0.5, 0.5)) == "" and load("res://scripts/palette.gd").TOWER_TINT["kraken"].is_equal_approx(Color(0.5, 0.5, 0.5)), "...and a colour in a table")
	# Bad values are refused, and nothing changes.
	var name0: String = Items.ITEMS["draught"]["name"]
	_check(Reg.set_value("items/ITEMS/draught/heal", "lots") != "" and is_equal_approx(Items.ITEMS["draught"]["heal"], 45.0), "a number refuses words")
	_check(Reg.set_value("items/ITEMS/draught/name", 5) != "" and Items.ITEMS["draught"]["name"] == name0, "words refuse a number")
	_check(Reg.set_value("ui/DIM", "bluish") != "" and Reg.set_value("makers/PLEA_ODDS/vessel_back", 1) != "", "a colour refuses a non-colour; on/off refuses a number")
	_check(Reg.set_value("items/ITEMS/draught/kind", "fire") != "" and Reg.set_value("nope/TABLE/x", 1) != "" and Reg.set_value("items/ITEMS/nothing/heal", 1) != "", "ids, unknown tables and missing keys are refused")
	_check(Reg.set_value("entity/TEXT/heard", "heard them all") != "" and Reg.set_value("entity/TEXT/heard", "%d heard, of %d") == "", "words must keep their %d / %s blanks")
	_check(Reg.set_value("items/ITEMS/draught/heal", 99999) == "" and Items.ITEMS["draught"]["heal"] <= heal * 10.0 + 0.01, "numbers are kept within bounds (%s)" % Items.ITEMS["draught"]["heal"])
	_check(Reg.set_value("train/BASE_PRICE/dagger", 12.6) == "" and typeof(Train.BASE_PRICE["dagger"]) == TYPE_INT and Train.BASE_PRICE["dagger"] == 13, "a whole number stays whole")
	_check(Reg.banned_in("The mana of the spire") == ["mana", "spire"] and Reg.banned_in("An inspired manager") .is_empty(), "the owner's banned words are spotted (whole words only)")
	# Revert one, then all.
	Reg.revert("train/BASE_PRICE/dagger")
	_check(not Reg.is_changed("train/BASE_PRICE/dagger") and Train.BASE_PRICE["dagger"] == 10, "Default puts one field back")
	Reg.revert_all()
	_check(Reg.applied.is_empty() and is_equal_approx(Items.ITEMS["draught"]["heal"], heal) and UI.GOLD.is_equal_approx(Color(0.91, 0.75, 0.42)) and Reg.value("entity/TEXT/heard") == "%d of %d heard", "putting all back restores every table")
	# Search.
	var found: Array = Reg.search("BASE_PRICE dagger")
	_check(found.size() == 1 and found[0]["path"] == "train/BASE_PRICE/dagger", "search finds a field by its key")
	found = Reg.search("healing draught")
	_check(found.any(func(f): return f["path"] == "items/ITEMS/draught/name"), "...and by what it says")
	# Copy and paste: a round trip.
	Reg.set_value("items/ITEMS/draught/heal", 50)
	Reg.set_value("entity/TIPS/stair/tip", "Stairs: take them.")
	Reg.set_value("enemy/TYPES/slime/color", Color(1, 0, 0))
	var text: String = Reg.export_text()
	var parsed = JSON.parse_string(text)
	_check(parsed is Dictionary and parsed["format"] == 1 and parsed["changes"].size() == 3 and parsed["changes"]["enemy/TYPES/slime/color"] == "#ff0000ff", "Copy changes writes the changes file (%d)" % (parsed["changes"].size() if parsed is Dictionary else -1))
	Reg.revert_all()
	var r: Dictionary = Reg.import_text(text)
	_check(r["done"] == 3 and r["refused"].is_empty() and is_equal_approx(Items.ITEMS["draught"]["heal"], 50.0) and Entity.TIPS["stair"]["tip"] == "Stairs: take them." and load("res://scripts/enemy.gd").TYPES["slime"]["color"].is_equal_approx(Color.RED), "...and Paste changes takes it back in")
	r = Reg.import_text('{"changes": {"items/ITEMS/draught/heal": "lots", "nope/X/y": 1, "items/ITEMS/tonic/heal": 12}}')
	_check(r["done"] == 1 and r["refused"].size() == 2, "...refusing what doesn't fit and taking the rest")
	_check(Reg.import_text("not json")["error"] != "" and Reg.import_text("[1, 2]")["error"] != "", "...and saying so when it isn't a changes file")
	Reg.revert_all()
	# Saving and the two files: the project's, then this device's on top.
	Reg.set_value("train/CLIMB_PAY/per_floor", 7)
	_check(Reg.save() == Reg.local_path and FileAccess.file_exists(Reg.local_path) and not FileAccess.file_exists(Reg.project_path), "away from the Godot editor, Save writes this device's file")
	Reg.project_write = 1
	Reg.set_value("items/ITEMS/draught/heal", 55)
	_check(Reg.save() == Reg.project_path and not FileAccess.file_exists(Reg.local_path), "from the Godot editor it writes the project's file (and this device's is folded in)")
	var pf = JSON.parse_string(FileAccess.get_file_as_string(Reg.project_path))
	_check(pf is Dictionary and pf["changes"].get("train/CLIMB_PAY/per_floor") == 7 and pf["changes"].get("items/ITEMS/draught/heal") == 55, "...with every change in it")
	Reg.project_write = 0
	Reg.set_value("train/CLIMB_PAY/per_floor", 9)
	Reg.set_value("items/ITEMS/draught/heal", heal)  # (back to the default here: a reset of the project's change)
	Reg.save()
	Reg.revert_all()  # (as if the game started again: read both files)
	Reg.project_write = 0
	Reg.local.clear()
	Reg.startup()
	_check(Train.CLIMB_PAY["per_floor"] == 9 and is_equal_approx(Items.ITEMS["draught"]["heal"], heal), "at startup this device's changes go on top of the project's (and can put one back)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Reg.local_path))
	Reg.startup()
	_check(Train.CLIMB_PAY["per_floor"] == 7 and is_equal_approx(Items.ITEMS["draught"]["heal"], 55.0), "...without them, the project's own")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Reg.project_path))
	Reg.startup()
	_check(Reg.applied.is_empty() and Train.CLIMB_PAY["per_floor"] == 2 and is_equal_approx(Items.ITEMS["draught"]["heal"], heal), "...and without either, the scripts' own values")
	var bad := FileAccess.open(Reg.project_path, FileAccess.WRITE)
	bad.store_string('{"format": 1, "changes": {"items/ITEMS/draught/heal": "lots", "train/CLIMB_PAY/per_best": 4}}')
	bad.close()
	Reg.startup()
	_check(Train.CLIMB_PAY["per_best"] == 4 and is_equal_approx(Items.ITEMS["draught"]["heal"], heal) and Reg.problems.size() == 1, "a file with a bad entry still loads the rest, and says what it skipped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Reg.project_path))
	Reg.startup()
	# Live: a price in the store, a tip the Entity says.
	Reg.set_value("train/SUPPLY_PRICE/draught", 2)
	var menu = main.menu
	main.await_tower()
	main.open_train()
	await _frames(3)
	menu.train_car = "store"
	menu.open("train")
	await _frames(4)
	var slot: Control = null
	for b in menu.train_page.roots["store"].find_children("*", "BaseButton", true, false):
		if b.get_meta("slot", "") == "supply:draught":
			slot = b
	_check(slot != null and slot.price == 2, "a price changed in the editor shows in the store (%s)" % (slot.price if slot != null else "no slot"))
	menu.close()
	Engine.set_meta("sixfold_tips", true)
	var told: Dictionary = Guide.state["told"].duplicate()
	Guide.state["told"].erase("bank")
	Reg.set_value("entity/TIPS/bank/tip", "Banked. Every word of this is the owner's.")
	_check(Guide.tell("bank") == "Banked. Every word of this is the owner's.", "an Entity tip changed in the editor is what it says")
	# The page: from Dev tools, by keyboard, controller, mouse and touch.
	Guide.state["told"].erase("data_editor")
	Guide.state["told"].erase("data_save")
	Guide.state["told"].erase("data_restart")
	main.touch._set_active(false)
	menu.close()
	await _frames(2)
	menu.open("dev")
	await _frames(3)
	var eb: Button = _menu_button(menu.data_page.TEXT["button"])
	_check(eb != null, "Dev tools has an Edit game data button")
	eb.pressed.emit()
	await _frames(3)
	var dp = menu.data_page
	_check(menu.page == "data" and menu.rail.visible and menu.rail_item() == "dev", "...which opens the editor beside the rail")
	var said: Array = dp.said_box.get_children().filter(func(c): return c.get_meta("entity", "") == "data")
	_check(said.size() == 1 and Guide.told("data_editor"), "the first time, the Entity explains the editor")
	_check(["data_editor", "data_save", "data_restart"].all(func(k): return Entity.ordered("creator").has(k)) and Entity.GROUPS.any(func(g): return g == ["creator", "Creator tools"]), "...its words kept in the Archive, under Creator tools")
	dp.set_tab("numbers")
	await _frames(2)
	_check(menu.focusables().filter(func(b): return b.has_meta("data_section")).size() == Reg.sections_in("numbers").size(), "a tab lists its sections")
	dp.open_section("prices")
	await _frames(3)
	var slider: HSlider = null
	for c in menu.box.find_children("*", "HSlider", true, false):
		if c.get_meta("data_slider", "") == "train/BASE_PRICE/dagger":
			slider = c
	_check(slider != null and is_equal_approx(slider.value, 10.0), "a number shows on a slider")
	menu.nav_keys = true
	slider.grab_focus()
	await _frames(2)
	await _key_tap(KEY_RIGHT)
	_check(Train.BASE_PRICE["dagger"] == 11 and Reg.is_changed("train/BASE_PRICE/dagger"), "Right on its slider raises it (keyboard)")
	await _pad_tap(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_check(Train.BASE_PRICE["dagger"] == 12, "...and the d-pad (controller) (%d)" % Train.BASE_PRICE["dagger"])
	var reset: Button = null
	for b in menu.focusables():
		if b.get_meta("data_reset", "") == "train/BASE_PRICE/dagger":
			reset = b
	_check(reset != null and reset.visible and dp.rows["train/BASE_PRICE/dagger"]["name"].get_theme_color("font_color").is_equal_approx(UI.GOLD), "a changed field turns gilt and shows its Default button")
	await _pad_tap(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(3)
	_check(dp.tab == "words" and menu.page == "data", "LB switches tabs")
	dp.open_section("items_words")
	await _frames(3)
	var path := "items/ITEMS/draught/name"
	var le: LineEdit = _data_find("data_path", path)
	var edit: Button = _data_find("data_edit", path)
	_check(le != null and edit != null and le.focus_mode == Control.FOCUS_CLICK, "words show in a text box the keys step past, with an Edit button")
	edit.grab_focus()
	await _key_tap(KEY_ENTER)
	le = _data_find("data_path", path)
	_check(menu._typing() and le.has_focus(), "Enter on Edit goes into the box")
	le.text = "Draught of the Owner"
	await _key_tap(KEY_ENTER)
	await _frames(2)
	var on: Control = menu.get_viewport().gui_get_focus_owner()
	_check(Items.ITEMS["draught"]["name"] == "Draught of the Owner" and on != null and on.get_meta("data_edit", "") == path, "...and Enter keeps the new words, back on Edit")
	_data_find("data_edit", path).grab_focus()
	await _key_tap(KEY_ENTER)
	le = _data_find("data_path", path)
	le.text = "The mana draught"
	await _key_tap(KEY_ESCAPE)
	await _frames(2)
	_check(menu.page == "data" and not menu._typing() and Items.ITEMS["draught"]["name"] == "The mana draught", "Esc leaves the box (keeping it), not the page")
	_check(dp.rows[path]["note"].visible and dp.rows[path]["note"].text.contains("mana"), "...with a warning for a banned word")
	# Touch on a phone: tap a field's Default, tap a section.
	var was_size: Vector2i = root.size
	root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	await _frames(3)
	menu.open("data")
	await _frames(3)
	var rb: Button = null
	for b in menu.focusables():
		if b.get_meta("data_reset", "") == "items/ITEMS/draught/name":
			rb = b
	menu.scroll.ensure_control_visible(rb)
	await _frames(3)
	await _tap_at(rb.get_global_rect().get_center())
	_check(Items.ITEMS["draught"]["name"] == name0, "a tap on Default puts it back (touch)")
	dp.open_section("")
	await _frames(3)
	var sb: Button = null
	for b in menu.focusables():
		if b.get_meta("data_section", "") == "makers":
			sb = b
	menu.scroll.ensure_control_visible(sb)
	await _frames(3)
	await _tap_at(sb.get_global_rect().get_center())
	await _frames(2)
	_check(dp.section == "makers" and menu.page == "data", "a tap opens a section")
	var box_le: Control = null
	for c in menu.box.find_children("*", "LineEdit", true, false):
		if c.has_meta("data_path") and c.is_visible_in_tree():
			box_le = c
			break
	menu.scroll.ensure_control_visible(box_le)
	await _frames(3)
	await _tap_at(box_le.get_global_rect().get_center())
	_check(box_le.has_focus() and menu._typing(), "a tap on a text box goes into it (in a phone's browser, its own text box opens)")
	await _key_tap(KEY_ESCAPE)
	await _frames(2)
	_check(not menu._typing() and menu.page == "data", "...and Esc leaves it")
	# It fits a phone: nothing wider than the page, on every kind of field.
	var wide: Array = []
	for st in [["words", "entity"], ["numbers", "prices"], ["colours", "menu_colours"], ["looks", "looks"], ["changes", ""]]:
		dp.set_tab(st[0])
		if st[1] != "":
			dp.open_section(st[1])
		if st[0] == "colours":
			dp.toggle_colour("ui/GOLD")
		await _frames(3)
		var sr: Rect2 = menu.scroll.get_global_rect()
		if menu.box.get_combined_minimum_size().x > menu.scroll.size.x + 1.0:
			wide.append("%s %.0f > %.0f" % [st[0], menu.box.get_combined_minimum_size().x, menu.scroll.size.x])
		for c in menu.box.find_children("*", "Control", true, false):
			if (c is BaseButton or c is LineEdit or c is HSlider) and c.is_visible_in_tree() and c.get_global_rect().end.x > sr.end.x + 1.0:
				wide.append("%s %s" % [st[0], c.get_class()])
		if not menu.get_viewport_rect().encloses(menu.panel.get_global_rect().grow(-1.0)):
			wide.append("%s panel off screen" % st[0])
	_check(wide.is_empty(), "on a phone (800 x 400) the editor fits: %s" % [wide.slice(0, 6)])
	dp.toggle_colour("ui/GOLD")
	root.size = was_size
	main.touch._set_active(false)
	await _frames(3)
	# The Entity on Save and on a field that waits for a restart; the ? button.
	dp.set_tab("colours")
	dp.open_section("world_colours")
	await _frames(2)
	dp._apply("palette/VOID", "#101010")
	_check(dp.said.contains("starts again") and Guide.told("data_restart"), "a change that waits for a restart: the Entity says so")
	dp.save_now()
	_check(Guide.told("data_save") and dp.said == Entity.TIPS["data_save"]["tip"], "the first Save: the Entity says how to keep changes for good")
	dp.toggle_help()
	await _frames(2)
	var helps: Array = dp.said_box.get_children().filter(func(c): return c.has_meta("help_more"))
	_check(helps.size() == 3 and helps[1].text.contains("GitHub Desktop"), "the ? button shows the Entity's whole account again")
	dp.toggle_help()
	# My changes: listed, and put back with two presses.
	dp.set_tab("changes")
	await _frames(2)
	var n: int = Reg.applied.size()
	var rows: int = menu.box.find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("data_row")).size()
	_check(n >= 2 and rows == n, "My changes lists every change (%d of %d)" % [rows, n])
	var all: Button = null
	for b in menu.focusables():
		if b.has_meta("data_revert_all"):
			all = b
	all.pressed.emit()
	await _frames(2)
	_check(Reg.applied.size() == n and dp.ask_all, "...Put all back asks first")
	for b in menu.focusables():
		if b.has_meta("data_revert_all"):
			all = b
	all.pressed.emit()
	await _frames(2)
	_check(Reg.applied.is_empty() and Train.BASE_PRICE["dagger"] == 10 and load("res://scripts/palette.gd").VOID.is_equal_approx(Color(0.035, 0.03, 0.05)), "...and the second press puts everything back")
	# Back: to Dev tools, saved.
	Reg.set_value("train/BASE_PRICE/axe", 20)
	await _key_tap(KEY_ESCAPE)
	await _frames(2)
	_check(menu.page == "dev" and not Reg.dirty and FileAccess.file_exists(Reg.local_path), "Back returns to Dev tools, saving what wasn't saved")
	# Clean up: everything as it was.
	Reg.revert_all()
	Guide.state["told"] = told
	Engine.remove_meta("sixfold_tips")
	menu.close()
	for f in [Reg.project_path, Reg.local_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Reg.project_path = Reg.PROJECT_PATH
	Reg.project_write = -1
	Reg.startup()
	_check(Reg.applied.is_empty() and Train.BASE_PRICE["axe"] == 12, "the tests leave every table as the scripts have it")


## The Data editor's control with this meta and value (its page may have been rebuilt).
func _data_find(meta: String, value) -> Control:
	for c in main.menu.box.find_children("*", "Control", true, false):
		if c.has_meta(meta) and c.get_meta(meta) == value and not c.is_queued_for_deletion():
			return c
	return null
