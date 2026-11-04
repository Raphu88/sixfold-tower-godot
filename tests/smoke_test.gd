extends SceneTree
## Headless smoke test: loads the room and drives the climber through every
## action (combo, riposte, parry, arrow reflect, roll dodge, both casts,
## overdraw, getting hurt, dying) so script errors surface without a player.
##
## Run: godot --headless -s tests/smoke_test.gd

var main
var failures := 0
const EnemyHP := {"slime": 24.0, "archer": 18.0, "knight": 48.0}


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


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
	main.profile.soak["heart"] = 200.0
	main.run_essence = {"iron": 20.0}
	main.floor_num = 4
	main._arrive()
	await _frames(2)
	_check(main.profile.bonds.has("heart"), "a soaked body part takes a new mark at the stair")
	_check(main.player.bonds.has("heart"), "the climber carries it")


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
	# Hold to pick: holding the key opens the ring (time slows); pointing picks.
	Input.action_press("cast_legs")
	await _wait(0.4)
	_check(p.pick_open and main.slowmo, "holding a mark's key opens its spell ring and slows time")
	p.pick_dir_override = Vector2(1, 0) * 60.0  # points at the second spell (of four, from the top, clockwise)
	await _wait(0.1)
	Input.action_release("cast_legs")
	await _frames(3)
	_check(p.bonds["legs"].selected == 1 and p.bonds["legs"].spell_name() == "Crosswind", "pointing right picks Crosswind: %s" % p.bonds["legs"].spell_name())
	_check(not main.slowmo, "letting go closes the ring")
	main.set_slowmo(false)
	Engine.time_scale = 1.0
	await _settle()
	# Bodies and passives.
	_check(main.player_glow.texture_scale > 2.0, "Keen Eyes: the Hunter sees farther")
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
	main._start_floor(5)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "gryphon", "floor 5 of the Gryphon's tower is the Gryphon")
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
	main._start_floor(5)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "kraken", "floor 5 of the Kraken's tower is the Kraken")
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
	await _frames(2)
	Input.action_release("jump")
	_check(p.in_air() and p.sta < p.MAX_STA, "Z jumps, for a little stamina")
	# In the air, a chasm and burning floor can't touch you.
	main.set_chasms([Rect2(p.global_position + Vector2(-20, -20), Vector2(40, 40))])
	var hp0: float = p.hp
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0}]
	await _wait(0.2)
	_check(p.hp == hp0, "...and while you're in the air, chasms and fire can't touch you")
	main.flames = []
	await _wait(0.5)
	_check(not p.in_air(), "you land again")
	_check(p.hp < hp0, "landing in a chasm: you fall and lose some health")
	_check(not main.in_chasm(p.global_position), "...and climb back out where you last stood")
	main.set_chasms([])
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
		for r in plan["chasms"]:
			ok = ok and not r.grow(60.0).has_point(main.player_start)
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
	for pg in ["title", "pause", "settings", "controls", "confirm_new", "dev"]:
		menu.open(pg)
		await _frames(1)
	_check(menu.page == "dev" and paused, "every menu page opens")
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
	main.dev_floor(5)
	await _frames(2)
	_check(main.floor_num == 5 and main.enemies().size() == 1 and main.enemies()[0].kind == "kraken", "...jumps to the beast")
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
	# Settings.
	menu._set_setting("sounds", 0.0)
	_check(main.audio.sound_level == 0.0, "the sounds slider sets the volume")
	menu._set_setting("sounds", 1.0)
	menu.close()
	_check(not paused and not main.menu_open(), "closing the menu resumes")


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
	main._start_floor(5)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "wyvern", "floor 5 of the Wyvern's tower is the Wyvern")
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
	main._start_floor(5)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "manticore", "floor 5 of the Manticore's tower is the Manticore")
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
	main._start_floor(5)
	await _frames(3)
	var foes: Array = main.enemies()
	_check(foes.size() == 1 and foes[0].kind == "firebird" and main.chasms.is_empty(), "floor 5 of the Firebird's tower is the Firebird, in an open hall")
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
	_check(counts["wyvern"]["knight"] > counts["gryphon"]["knight"], "the Wyvern's tower has more knights (%d vs %d)" % [counts["wyvern"]["knight"], counts["gryphon"]["knight"]])
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
	_check(main.new_climber_t > 0.0 and main.banner.get("title", "") == "NEW CLIMBER?", "a first press asks to confirm")
	_check(not main.profile.bonds.is_empty(), "one press changes nothing yet")
	await _frames(2)
	Input.action_press("new_climber")
	await _frames(2)
	Input.action_release("new_climber")
	_check(main.profile.bonds.is_empty() and not main.profile.regarded, "a second press starts a new climber: no marks")

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
	p._equip("bow")
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
	# A hit during its wind-up makes it flinch and cancels the pounce.
	slime.state = "wind"
	slime.state_t = 0.5
	slime.glinted = false
	main.request_attack(slime)
	slime.take_hit(1.0, Vector2.RIGHT, 50.0)
	_check(slime.state != "wind" and slime.flinch > 0.0, "hitting a winding slime cancels its pounce")
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
	# Skip ahead a few floors.
	for i in 2:
		main._arrive()
	await _frames(3)
	_check(main.floor_num == 4, "climbed to floor 4")
	main.profile.bonds["hand"]["xp"] = 170.0
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
	await _spell_tests()
	await _menu_tests()
	await _jump_tests()
	await _wyvern_bond_tests()
	await _manticore_bond_tests()
	await _firebird_bond_tests()
	await _body_part_tests()

	print("\n%s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	# Free the room (and its music) before quitting, so nothing leaks at exit.
	main.queue_free()
	await _frames(2)
	quit(1 if failures > 0 else 0)
