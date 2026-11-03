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
	_check(brow.get("id", "") == "tidecaller", "the dominant essence (Water) picks the bond: %s" % brow.get("id", ""))
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
	main.gather_essence("air", 10.0, p.global_position)
	main.floor_num = 3
	for e in main.enemies():
		e.take_hit(9999.0, Vector2.RIGHT, 0.0)
	await _frames(3)
	_check(main.stair_open, "floor 3's stair opens")
	p.global_position = main.stair_pos
	await _wait(1.0)
	_check(not main.regard.is_empty() and not main.regard["fell"], "taking the top stair brings the Regard")
	var legs: Dictionary = main.profile.bonds.get("legs", {})
	_check(legs.get("id", "") == "windwalker" and not legs.get("faint", true), "a full Windwalker mark on the legs")

	print("a second mark")
	main.first_climb = false
	main.profile.soak["heart"] = 200.0
	main.run_essence = {"iron": 20.0}
	main.floor_num = 4
	main._arrive()
	await _frames(2)
	_check(main.profile.bonds.has("heart"), "a soaked body part takes a new mark at the stair")
	_check(main.player.bonds.has("heart"), "the climber carries it")


func _spell_tests() -> void:
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
	p.global_position = knight.global_position + Vector2(gap, 0)
	knight.set_physics_process(true)
	var glinted := false
	for i in 200:
		await process_frame
		if knight.glinted and knight.state == wind_state:
			glinted = true
			break
	if delay > 0.0:
		await _wait(delay)
	p._try_parry()
	var stun := 0.0
	var until := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < until:
		await process_frame
		stun = maxf(stun, knight.stun)
	var result := {"glinted": glinted, "parried": stun > 0.0, "stun": stun, "hurt": p.hp < p.MAX_HP}
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
	_check(r4["glinted"] and r4["parried"] and not r4["hurt"], "parrying a slime's pounce on the glint works")
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
		e.take_hit(999.0, Vector2.RIGHT, 200.0)
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
	for i in 3:
		main._arrive()
	await _frames(3)
	_check(main.floor_num == 5, "climbed to floor 5")
	main.profile.bonds["hand"]["xp"] = 170.0
	main._give_bonds()
	_check(p.bonds["hand"].step == 3, "enough banked essence grows a mark to step 3")
	_check(p.bonds["hand"].stat("leaps") == 6, "step 3 Chain Lightning leaps 6 times")
	var foes5: Array = main.enemies()
	_check(foes5.size() >= 4, "floor 5 has more monsters (%d)" % foes5.size())
	_check(foes5[0].max_hp > EnemyHP.get(foes5[0].kind, 0.0), "monsters are tougher higher up")
	var inside := true
	for e in foes5:
		inside = inside and main.room.has_point(e.global_position)
	_check(inside, "monsters spawn inside the room")

	await _regard_tests()
	await _spell_tests()

	print("\n%s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	# Free the room (and its music) before quitting, so nothing leaks at exit.
	main.queue_free()
	await _frames(2)
	quit(1 if failures > 0 else 0)
