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
	door = main.door_view.list.filter(func(d): return d["lock"] == "")[0]
	for e in main.enemies():
		e.set_physics_process(false)
	p.global_position = main.player_start
	main.door_view.monster_t = 99.0  # (a new monster starts awake: hold the check a moment)
	var foe = await _spawn("slime", door["rect"].get_center() + door["out"] * 50.0)
	foe.set_physics_process(false)
	foe.aware = false
	main.door_view.monster_t = 0.0
	await _wait(0.3)
	var shut: bool = not door["open"]
	foe.aware = true
	await _wait(0.3)
	_check(shut and door["open"], "a sleeping monster leaves a door shut; an awake one opens it")
	foe.queue_free()
	# Entering a themed room shows its name and rule, once.
	for e in main.enemies():
		e.queue_free()
	await _frames(1)
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
			for d in main.door_view.list:
				ok_clear = ok_clear and not d["rect"].has_point(c)
			if not plan.get("puzzle", {}).is_empty():
				ok_clear = ok_clear and not plan["puzzle"]["room"].has_point(c)
			ok_clear = ok_clear and c.distance_to(main.player_start) > 80.0 and c.distance_to(main.stair_pos) > 60.0
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
	await _wait(float(Traps.KINDS["miasma"]["warn"]) + float(Traps.KINDS["miasma"]["fire"]))
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
	# A test puzzle of each hand-made kind, laid out in the start room.
	var c: Vector2 = main.player_start + Vector2(0, -120)
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
	_check(first != null and _menu_button("New climber") == null, "a new climber is offered the first climb (and nothing to lose)")
	_check(_menu_button("Climber") != null and _menu_button("Settings") != null and _menu_button("Dev tools") != null, "the title has Climber, Settings and Dev tools")
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
	# Body and Settings open over the title's backdrop; Back returns.
	_menu_button("Climber").pressed.emit()
	await _frames(2)
	_check(menu.page == "climber" and menu.backdrop.visible and not menu.backdrop.show_name, "Climber opens over the title backdrop")
	_menu_button("Back").pressed.emit()
	await _frames(2)
	_check(menu.page == "title" and menu.backdrop.show_name, "...and Back returns to the title")
	# Phones: a tap on a title button works (and switches to the phone layout).
	await _tap_at(_menu_button("Settings").get_global_rect().get_center())
	_check(menu.page == "settings" and menu.backdrop.visible, "tapping Settings on a phone opens it over the title")
	_check(main.touch.active and is_equal_approx(root.content_scale_factor, 1.5), "...and the phone layout is on")
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
	# A climber with marks: Continue, a status line and New climber.
	main.grant_test_bonds()
	menu.open("title")
	await _frames(2)
	var cont := _menu_button("Continue")
	_check(cont != null and _menu_button("New climber") != null, "a marked climber sees Continue and New climber")
	var status := false
	for l in menu.find_children("*", "Label", true, false):
		if l.text.begins_with("Marks: ") and "Best floor" in l.text:
			status = true
	_check(status, "the title shows marks carried and best floor")
	_menu_button("New climber").pressed.emit()
	await _frames(2)
	_check(menu.page == "confirm_new" and menu.backdrop.visible, "New climber asks over the title backdrop")
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
	await _wait(0.15)
	_touch(4, item_btn["c"], false)
	await _frames(2)
	_check(p.item_count("draught") == 0, "tapping the item button uses the item")
	p.add_item("draught")
	p.add_item("tonic")
	p.item_sel = "draught"
	var next_btn: Dictionary = buttons[ids.find("item_next")]
	_touch(5, next_btn["c"], true)
	await _wait(0.15)
	_touch(5, next_btn["c"], false)
	await _frames(2)
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
	_check(p.weapon == "sword" and p.gear["melee"] == "sword" and p.gear["ranged"] == "shortbow" and p.gear["armor"] == "", "every climb starts with a sword, a shortbow and no armor")
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
	var old: String = p.take_gear("crossbow")
	_check(old == "longbow" and p.weapon == "crossbow" and p.gear["ranged"] == "crossbow", "taking a crossbow puts it in the ranged slot and in hand")
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
		p.gear["armor"] = id
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
	p.gear["armor"] = "plate"
	p.hp = 100.0
	p.poison(0.6)
	await _wait(0.75)
	_check(p.hp <= 98.0, "poison isn't reduced by armor (%.1f)" % p.hp)
	p.poison_t = 0.0
	p.gear["armor"] = ""

	print("finding gear")
	p.hp = p.MAX_HP
	p.global_position = spot
	# Walking over gear with an empty slot takes it.
	main.drop_gear(spot, "chain")
	await physics_frame
	await physics_frame
	_check(p.gear["armor"] == "chain" and main.gear_drops.is_empty(), "walking over armor with none on puts it on")
	# Otherwise a prompt compares it, and Y swaps (dropping your old piece).
	main.drop_gear(spot + Vector2(4, 0), "axe")
	await physics_frame
	await physics_frame
	_check(p.gear["melee"] == "sword" and not main.gear_here.is_empty() and main.gear_here["id"] == "axe", "with the slot full, gear waits for you to take it")
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await _frames(2)
	_check(p.gear["melee"] == "axe" and p.weapon == "axe", "pressing Y takes the axe into your hand")
	var dropped: Array = main.gear_drops.filter(func(d): return d["id"] == "sword")
	_check(main.gear_drops.size() == 1 and dropped.size() == 1 and dropped[0]["pos"].distance_to(p.global_position) < 6.0, "...and your sword is dropped where you stand")
	_check(main.take_gear_here() and p.gear["melee"] == "sword", "you can swap straight back")
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
	_check(favoured > 180, "archers favour bows, crossbows and leather (%d of 400)" % favoured)
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
		var cg: String = main.cache.get("gear", "")
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
	var gid: String = String(gear_cards[0]).substr(5)
	_check(card.get("gear", "") == gid and card["name"] == G.display(gid), "its card shows the gear")
	var slot: String = G.slot_of(gid)
	var had: String = p.gear[slot]
	main.choose_camp(gi)
	_check(p.gear[slot] == gid and not main.camp_choosing, "taking the gear card carries it (%s)" % gid)
	if had != "":
		_check(main.gear_drops.size() == 1 and main.gear_drops[0]["id"] == had, "...and leaves your old %s by the fire" % had)

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
	_check(p.gear["melee"] == "mace" and main.gear_drops.size() == 1 and main.gear_drops[0]["id"] == "sword", "tapping Take swaps for the mace and drops the sword")
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
	_check("CARRIED" in labels and "Mace" in labels and "Shortbow" in labels and "No armor" in labels, "the inventory lists your gear")
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
		_check(p.gear["armor"] == "plate" and p.gear["melee"] == "war_hammer" and p.weapon == "war_hammer", "...and pressing them does")
	main.menu.close()
	await _frames(2)


func _heirloom_tests() -> void:
	print("heirlooms")
	await _fresh_main()
	var p = main.player
	var G = main.Gear
	var slots: Array = G.HEIRLOOM_SLOTS.map(func(s): return s["id"])
	for want in ["melee", "ranged", "chest", "boots", "gloves", "helm", "legs", "rings", "amulet", "cloak", "backpack"]:
		_check(want in slots, "heirloom slot: %s" % want)
	_check(G.heirloom_slot("plate") == "chest" and G.heirloom_slot("axe") == "melee" and G.heirloom_slot("crossbow") == "ranged", "armor is a chest heirloom, weapons melee or ranged")
	_check(G.gear_slot_for("boots") == "", "the planned slots hold nothing yet")
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
	_check(main.camp_card(ci)["gear"] == "axe" and "melee" in main.camp_card(ci)["note"], "a card names the slot it fills")
	main.touch._set_active(true)
	await _frames(2)
	var size: Vector2 = main.hud.get_viewport_rect().size
	var at: Vector2 = main.hud.camp_card_rect(ci, size).get_center()
	_touch(7, at, true)
	await _frames(2)
	_touch(7, at, false)
	await _frames(2)
	_check(not main.camp_choosing and main.profile.heirlooms.get("melee", "") == "axe", "tapping the axe keeps it as the melee heirloom")
	# A new climb starts with it.
	var q = load("res://scripts/player.gd").new()
	q.main = main
	q.use_heirlooms(main.profile.heirlooms)
	_check(q.gear["melee"] == "axe" and q.weapon == "axe" and q.gear["ranged"] == "shortbow" and q.gear["armor"] == "", "the next climb begins with the heirloom, the rest as usual")
	q.free()
	# The next survived climb: the axe is already an heirloom, so it isn't offered again.
	main.heirloom_offered = false
	main.victory = {"t": 3.0, "beast": "test", "lines": []}
	main.end_regard()
	_check(not ("heir:axe" in main.camp["choices"]), "an heirloom already kept isn't offered again")
	ci = main.camp["choices"].find("heir:chain")
	_check("new chest" in main.camp_card(ci)["note"], "...and an empty slot says so")
	main.choose_camp(ci)
	_check(main.profile.heirlooms.get("chest", "") == "chain" and main.profile.heirlooms.get("melee", "") == "axe", "a second heirloom in another slot keeps the first")
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
	# The inventory shows the heirlooms and the planned slots; so does the climber screen's Record.
	main.menu.open("inventory")
	await _frames(2)
	var texts: Array = _all_labels(main.menu).map(func(l): return l.text)
	_check("HEIRLOOMS" in texts, "the inventory has an Heirlooms section")
	var chest = _slot("heir:chest")
	var pack = _slot("heir:backpack")
	_check(chest != null and chest.id == "chain" and not chest.locked and "Backpack" in texts and pack != null and pack.locked, "...with the kept chest and the planned slots, locked")
	pack.focus_entered.emit()
	await _frames(1)
	texts = _all_labels(main.menu).map(func(l): return l.text)
	_check(texts.any(func(t): return t.begins_with("Planned")), "...and a planned slot says it's planned")
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
	_check(p.item_count(first) > 0 if not first.begins_with("gear:") else p.gear.values().has(first.substr(5)), "...the one that was highlighted (%s)" % first)
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
	main.menu.open("settings")
	await _frames(2)
	focus = main.menu.get_viewport().gui_get_focus_owner()
	_check(focus is HSlider, "the settings page starts on the music slider")
	var music: float = main.menu.settings["music"]
	await _key_tap(KEY_LEFT)
	_check(main.menu.settings["music"] < music, "left turns the music down")
	main.menu._set_setting("music", music)
	await _pad_tap(JOY_BUTTON_B)
	_check(main.menu.page == "pause", "B goes back a page")
	await _pad_tap(JOY_BUTTON_A)
	_check(not main.menu_open() and not paused, "A presses the focused button (Resume)")
	await _frames(2)
	main.menu.open("controls")
	await _frames(2)
	var texts: Array = _all_labels(main.menu).map(func(l): return l.text)
	_check("Controller" in texts and texts.any(func(t): return "hold LB" in t), "the Controls page lists the controller")
	await _key_tap(KEY_ESCAPE)
	_check(main.menu.page == "pause", "Esc goes back from a page to the pause menu")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open(), "...and closes it")
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
	await _chimera_tower_tests()
	await _spell_tests()
	await _menu_tests()
	await _screen_tests()
	await _mark_page_tests()
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
	await _chimera_bond_tests()
	await _body_part_tests()
	await _item_tests()
	await _camp_tests()
	await _wing_tests()
	await _lock_tests()
	await _gear_tests()
	await _heirloom_tests()
	await _controls_tests()
	await _performance_tests()
	await _lighting_tests()
	await _foe_list_tests()
	await _slim_hud_tests()

	print("\n%s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
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
	await _frames(2)
	var fi: int = vd.y * main.grid_size.x + vd.x
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
	var held0: int = main.profile.crystals.size()
	main.choose_camp(0)
	_check(not main.camp_choosing and main.profile.crystals.size() == held0 + 1, "choosing a crystal card keeps the crystal")
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
		held0 = main.profile.crystals.size()
		p.global_position = w["drop"]["pos"]
		await _frames(3)
		_check(main.profile.crystals.size() == held0 + 1, "walking over it keeps the crystal")
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
	_check(p.gear["melee"] == "axe", "a gear card is taken into its slot")
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
	_check(main.profile.crystal_count("air") == 0 and main.profile.bonds["hand"]["xp"] > xp0 and not lines.is_empty(), "consuming a crystal banks its essence into your marks (%s)" % [lines])
	_check(main.consume_crystal("air").is_empty(), "(none left: nothing happens)")

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
	p.item_sel = "scroll"
	_check(not p.use_item() and main.victory.is_empty() and main.banner.get("title", "") == main.Items.RECALL["ask_title"], "using the scroll asks first")
	_check(p.use_item(), "...and a second use reads it")
	_check(not main.victory.is_empty() and main.victory.get("recall", false), "reading it ends the climb safely")
	_check(main.profile.crystal_count("fire") == 1 and int(main.profile.crystal_total("fire")) == 23 and main.profile.crystal_count("air") == 1, "unbanked essence settles into crystals, one per kind")
	_check(main.run_essence.is_empty() and p.item_count("scroll") == 0 and main.profile.soak.get("back", 0.0) >= 4.0, "the scroll is used up, and nothing else is lost")
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
	d = await _locked_floor("carried")
	if not d.is_empty():
		var carrier = main.enemies().filter(func(e): return e.has_meta("key"))
		_check(carrier.size() == 1, "one monster carries the key")
		if carrier.size() == 1:
			var at: Vector2 = carrier[0].global_position
			_slay(carrier[0])
			await _frames(2)
			_check(main.door_view.keys.any(func(x): return x["lock_id"] == d["lock_id"] and x["pos"] == at), "slain, it drops the key")
	main.door_view.open_all()
	_check(main.door_view.locked_count() == 0, "(the dev tool's Open all opens locked doors too)")

	# Lock-in rooms.
	var li := -1
	for n in 80:
		main._start_floor(3 + n % 6)
		await _frames(1)
		for i in main.door_view.lock_rooms:
			var rect: Rect2 = main.room_info[i]["rect"]
			if main.enemies().any(func(e): return rect.grow(-40.0).has_point(e.global_position)):
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
		await _frames(4)
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
		if main.door_view.lock_rooms.is_empty():
			continue
		var i: int = main.door_view.lock_rooms.keys()[0]
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
	var want := ["Resume", "Settings", "Controls", "Dev tools", "Restart this climb", "New climber", "Exit to title"]
	var have: Array = _all_buttons(menu).map(func(b): return b.text)
	var missing := want.filter(func(t): return not (t in have))
	_check(missing.is_empty(), "...with Resume, Settings, Controls, Dev tools, Restart, New climber and Exit (missing %s)" % [missing])
	_check(have.any(func(t): return t.begins_with("Climber")) and have.any(func(t): return t.begins_with("Inventory")), "...and Climber and Inventory")
	_check(("Quit game" in have) == menu.can_quit() and menu.can_quit() != OS.has_feature("web"), "Quit game only where the game can be quit (not on the web)")
	_menu_button("New climber").pressed.emit()
	await _frames(1)
	_check(menu.page == "confirm_new", "New climber asks first")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "pause", "...and Esc cancels back to the pause menu")
	for b in _all_buttons(menu):
		if b.text.begins_with("Inventory"):
			b.pressed.emit()
	await _frames(1)
	_check(menu.page == "inventory" and _menu_button("Back") != null, "the pause menu opens the inventory, with Back")
	await _key_tap(KEY_ESCAPE)
	_check(menu.page == "pause", "...and Esc goes back to the pause menu")
	await _key_tap(KEY_ESCAPE)
	_check(not main.menu_open() and not paused, "Esc on the pause menu resumes")

	# Tab: the climber screen.
	await _key_tap(KEY_TAB)
	_check(menu.page == "climber" and paused, "Tab opens the climber screen and pauses")
	_check(_menu_button("Close") != null, "...with Close (not Back)")
	var cards: Array = menu.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == M.MarkCard)
	_check(cards.size() == 6 and menu.find_children("*", "Control", true, false).any(func(c): return c.get_script() == M.BodyView), "...the body and a card for each of the six parts")
	var tabs: Array = _all_buttons(menu).filter(func(b): return b.has_meta("tab"))
	_check(tabs.size() == 3, "...and three tabs")
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
	_check(draught != null and draught.count == 1 and _slot("item:tonic").count == 1 and _slot("item:vial").count == 0, "...items with their counts")
	var planned := 0
	for hs in main.Gear.HEIRLOOM_SLOTS:
		var s = _slot("heir:" + hs["id"])
		if s != null and s.locked:
			planned += 1
	_check(planned == 8 and not _slot("heir:melee").locked, "...and every heirloom slot, the eight planned ones locked")
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
	_menu_button("Exit to title").pressed.emit()
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
	_check(menu.scroll.get_v_scroll_bar().max_value <= menu.scroll.size.y + 2.0, "on a phone the inventory fits without scrolling")
	menu.close()
	await _frames(2)
	main.touch._set_active(false)
	p.touch_aim = false

	# The HUD size setting.
	menu.open("settings")
	await _frames(1)
	var sizes: Array = _all_buttons(menu).filter(func(b): return b.has_meta("choice"))
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
	_check(p.gear["melee"] == "axe" and menu.page == "inventory", "...which swaps it for your weapon")
	menu.close()
	main.gear_drops.clear()
	await _frames(2)
