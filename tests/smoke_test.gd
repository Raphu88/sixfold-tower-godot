extends SceneTree
## Headless smoke test: loads the room and drives the climber through every
## action (combo, riposte, parry, arrow reflect, roll dodge, both casts,
## overdraw, getting hurt, dying) so script errors surface without a player.
##
## Run: godot --headless -s tests/smoke_test.gd

var main
var failures := 0


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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
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
	_check(not p.bonds["hand"].burned, "burns heal on clear")

	print("\n%s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	# Free the room (and its music) before quitting, so nothing leaks at exit.
	main.queue_free()
	await _frames(2)
	quit(1 if failures > 0 else 0)
