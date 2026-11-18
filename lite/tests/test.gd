extends SceneTree
## Six Towers LITE's test. A simple bot plays a whole first climb (it finds
## its way round walls, solves the puzzles by going where the guide points,
## and can't be hurt: being hurt has checks of its own) up to the Regard on
## floor 3 and the beast on floor 6. Then: every layout and its puzzle, portals,
## the secret treasure room, losing the run, hearts carrying over, harder
## monsters and beasts, mark upgrades and their effects, play style choosing
## where marks go, roll and parry, the weapons, tower locks, the climber
## screen (treasure too), the save, the words, the voice and every sound.
## Run from the lite folder:
##   godot --headless -s tests/test.gd

const Data := preload("res://scripts/data.gd")
const Save := preload("res://scripts/save.gd")
const Art := preload("res://scripts/art.gd")
const Creatures := preload("res://scripts/creatures.gd")
const Look := preload("res://scripts/look.gd")
const FloorMap := preload("res://scripts/floor_map.gd")
const GearLook := preload("res://scripts/gear_look.gd")

var g
var failures := 0
var failed: Array = []


func _init() -> void:
	Engine.set_meta("lite_test", true)  # (its own save file: save.gd path)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		failed.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("Six Towers LITE")
	DirAccess.remove_absolute(Save.path())
	g = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await _frames(3)
	_check(g.screen != null and g.screen.has_method("suggested") and g.screen.suggested() == "gryphon", "home: the guide points at the first tower")
	_check(g.screen.unlocked(0) and not g.screen.unlocked(1), "only the first tower is open at first")
	_layout_test()
	await _climb_test()
	await _puzzle_test()
	await _fall_test()
	await _harder_test()
	await _upgrade_test()
	_play_style_test()
	await _combat_test()
	await _climber_screen_test()
	_save_test()
	_words_test()
	_sound_test()
	g.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(Save.path())
	print("PASSED (0 failures)" if failures == 0 else "FAILED (%d failures)" % failures)
	for f in failed:
		print("  FAILED: ", f)
	quit(1 if failures > 0 else 0)


## Drives a climb's frames by hand (no real time): `steps` of `dt`, the bot
## going for the nearest monster (or what the guide points at once the room is
## clear) round the walls and swinging all the while. Somewhere it can't walk
## to (another portal island) it hops to. It can't be hurt.
func _drive(c, steps: int, until: Callable, dt := 0.05) -> void:
	c.set_process(false)
	var field := {}
	var goal_was := Vector2(-1, -1)
	for i in steps:
		if until.call():
			return
		if g.upgrades != null:
			g.upgrades.pick(g.upgrades.choices[0])
			g.upgrades.picked_t = 2.0
			g.upgrades._process(0.0)
		c.safe_t = maxf(c.safe_t, 0.3)
		var goal: Vector2 = c.stair_pos
		if c.in_secret:
			goal = c.map.back_portal
		elif not c.monsters.is_empty():
			var near: Dictionary = c.monsters[0]
			for m in c.monsters:
				if c.pos.distance_to(m["pos"]) < c.pos.distance_to(near["pos"]):
					near = m
			goal = near["pos"]
		elif c.guide_goal() != Vector2.ZERO:
			goal = c.guide_goal()
		if i % 8 == 0 or goal.distance_to(goal_was) > 40.0:
			field = c.map.distances(goal)
			goal_was = goal
		var here: Vector2i = c.map.cell_of(c.pos)
		var near_goal: float = 60.0 if not c.monsters.is_empty() else 4.0
		if not field.has(here) and not c.map.solid(c.map.cell_of(goal)):
			c.pos = c.map.collide(goal + Vector2(0, 50), c.PLAYER_R)  # (a hop to another island)
		var to: Vector2 = goal if c.map.line_clear(c.pos, goal) else c.map.next_step(c.pos, field)
		var d: Vector2 = to - c.pos
		c.pad.move = d.normalized() if c.pos.distance_to(goal) > near_goal else Vector2.ZERO
		c.pad.attack_held = true
		c._step(dt)
		c.pad.consume()
		if i % 40 == 0:
			await _frames(1)


func _layout_test() -> void:
	for nm in FloorMap.LAYOUTS:
		var m = FloorMap.new()
		m.load_layout(nm, true)
		_check(m.grid.size() == FloorMap.ROWS and m.grid[0].size() == FloorMap.COLS, "layout %s is 30 by 16" % nm)
		for pt in m.portals:
			_check(int(pt["to"]) >= 0, "...%s's portals come in pairs" % nm)
		if nm == "treasure":
			_check(m.chests.size() == 1 and m.back_portal != Vector2.ZERO, "the treasure room has a chest and a way back")
			continue
		var spots: Array = m.spawn_spots(320.0)
		_check(spots.size() >= 8, "...%s has room for monsters (%d spots)" % [nm, spots.size()])
		if m.stair == Vector2.ZERO:
			continue
		m.gate_open = true
		_check(m.distances(m.start, true).has(m.cell_of(m.stair)), "...%s's stair can be reached (with the gate open)" % nm)
		if not m.gate_cells.is_empty():
			m.gate_open = false
			_check(not m.distances(m.start, true).has(m.cell_of(m.stair)) and m.puzzle != "", "...and not before its puzzle (%s) opens the gate" % m.puzzle)
	for i in Data.FLOORS.size() + 1:
		_check(not FloorMap.names_for(i).is_empty(), "floor %d has layouts" % (i + 1))


func _climb_test() -> void:
	g.start_climb("gryphon")
	await _frames(2)
	var c = g.screen
	_check(Data.FLOORS.size() + 1 == 6 and Data.REGARD_FLOOR == 3, "a climb is six floors; the first climb's Regard comes on floor 3")
	_check(c.floor_i == 0 and c.monsters.size() == Data.FLOORS[0] and c.hearts == Data.HEARTS, "a climb starts on floor 1 with its monsters and every heart")
	_check(c.map != null and c.map.name != "", "the floor is laid out from a map (%s)" % c.map.name)
	_check(c.banner == Data.TEXT["floor"] % "1", "big words say which floor (\"%s\")" % c.banner)
	_check(g.save.marks.is_empty(), "the first climb has no magic")
	await _drive(c, 4000, func(): return c.phase == "clear")
	_check(c.phase == "clear" and c.carried() > 0.0, "the bot clears floor 1, and the monsters' sparkles fly into the climber")
	await _drive(c, 1500, func(): return c.floor_i == 1)
	_check(c.floor_i == 1 and c.carried() == 0.0 and g.save.spare > 0.0, "the stair banks the sparkles (with no mark yet they wait for the first) and climbs on")
	_check(not g.save.soak.is_empty(), "...and the body soaks up some by play style (%s)" % [g.save.soak.keys()])
	await _drive(c, 14000, func(): return c.phase == "regard")
	_check(c.phase == "regard" and c.floor_i == 2 and not c.regard_beat and c.regard_new, "after floor 3, the Gryphon takes notice: the Regard")
	var part: String = g.save.marks.get("air", {}).get("part", "")
	_check(g.save.marks.has("air") and part != "" and float(g.save.marks["air"]["grown"]) > 0.0, "it marks the body (the %s, by play style) with Air, grown by what was banked" % part)
	_check(not g.save.beaten.has("gryphon"), "...but it isn't beaten yet (no crown)")
	c.phase_t = 3.0
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	c._input(tap)
	_check(c.floor_i == 3 and c.phase == "fight" and c.chosen == "air", "OK goes on to floor 4, with the new magic ready")
	await _drive(c, 20000, func(): return c.beast_floor())
	_check(c.beast_floor() and c.floor_i == 5 and c.monsters.size() == 1 and c.monsters[0]["beast"], "floor 6 is the beast's")
	_check(int(c.monsters[0]["max"]) == Data.BEAST_HP, "the Gryphon (the first beast) has %d health" % Data.BEAST_HP)
	await _drive(c, 20000, func(): return c.phase == "clear")
	_check(c.phase == "clear" and c.monsters.is_empty() and c.beast_called, "the bot beats the Gryphon (it called its monsters at half health)")
	await _drive(c, 1500, func(): return c.phase == "regard")
	_check(c.phase == "regard" and c.regard_beat and not c.regard_new, "its stair: the beast beaten")
	_check(g.save.beaten.has("gryphon"), "the Gryphon counts as beaten (its crown)")
	_check(g.save.found.has("watchers_helm") and g.save.worn.get("head", "") == "watchers_helm", "...and it leaves its treasure, worn at once (%s)" % [g.save.found])
	g.go_home("gryphon")
	await _frames(2)
	_check(g.screen.suggested() == "kraken" and g.screen.unlocked(1) and not g.screen.unlocked(2), "back home: the Kraken's tower opens, the next stays locked")
	_check(g.screen.bubble_text() == Data.TEXT["hooray"], "the climber says \"%s\"" % Data.TEXT["hooray"])


func _open_room(c) -> void:
	c.set_process(false)
	c.map = FloorMap.new()
	c.map.load_layout("arena", false)
	c.pillars = c.map.pillars
	c.pos = Vector2(640, 520)
	c.field = c.map.distances(c.pos)


func _puzzle_test() -> void:
	g.start_climb("gryphon")
	await _frames(2)
	var c = g.screen
	c.set_process(false)
	for kind in ["plates", "lever", "fires"]:
		var m = FloorMap.new()
		m.load_layout(kind, false)
		c.map = m
		c.stair_pos = m.stair
		c.monsters.clear()
		c.phase = "clear"
		_check(not m.gate_open and m.puzzle == kind, "%s: the gate starts shut" % kind)
		_check(c.guide_goal() != m.stair, "...and the guide points at the puzzle first")
		var guard := 0
		while not m.gate_open and guard < 10:
			guard += 1
			var goal: Vector2 = c.guide_goal()
			if kind == "plates":
				c.pos = goal
				c._update_map(0.05)
			else:
				c.pos = m.collide(goal + Vector2(0, 50), c.PLAYER_R)
				c.swing_dir = (goal - c.pos).normalized()
				c.swing_cd = 0.0
				c.facing = c.swing_dir
				c._swing()
		_check(m.gate_open, "...solving it opens the gate")
		_check(c.guide_goal() == m.stair, "...then the guide points at the stair")
	# An arrow lights a brazier from afar.
	var fm = FloorMap.new()
	fm.load_layout("fires", false)
	c.map = fm
	c.swap_weapon("bow")
	c.pos = fm.collide(fm.fires[0]["pos"] + Vector2(200, 0), c.PLAYER_R)
	c.arrows = [{"pos": fm.fires[0]["pos"] + Vector2(60, 0), "vel": Vector2(-720, 0), "life": 1.0}]
	for k in 10:
		c._update_arrows(0.02)
	_check(fm.fires[0]["lit"], "an arrow lights a brazier")
	c.swap_weapon("sword")
	# Portals: step in one, come out of the other.
	var pm = FloorMap.new()
	pm.load_layout("islands", false)
	c.map = pm
	var a: Dictionary = pm.portals[0]
	var b: Dictionary = pm.portals[int(a["to"])]
	c.pos = a["pos"]
	c.portal_cd = 0.0
	c.roll_t = 0.0
	c._update_map(0.05)
	_check(c.pos.distance_to(b["pos"]) < 60.0, "a portal takes you to its pair")
	_check(not pm.distances(pm.start).has(pm.cell_of(pm.stair)) and pm.distances(pm.start, true).has(pm.cell_of(pm.stair)), "on the islands, only the portals lead to the stair")
	# The secret: a cracked wall, a portal behind it, a treasure room with a chest.
	var sm = FloorMap.new()
	sm.load_layout("hall", true)
	c.map = sm
	c.monsters.clear()
	c.phase = "clear"
	var ck: Dictionary = sm.cracks[0]
	_check(sm.solid(ck["cell"]), "the cracked wall is solid")
	c.pos = sm.collide(ck["pos"] + Vector2(50, 40), c.PLAYER_R)
	c.swing_dir = (ck["pos"] - c.pos).normalized()
	c.facing = c.swing_dir
	c.swing_cd = 0.0
	c._swing()
	_check(ck["broken"] and not sm.solid(ck["cell"]), "a hit breaks it, opening a secret portal")
	var found_before: int = g.save.found.size()
	c.pos = ck["pos"]
	c.portal_cd = 0.0
	c._update_map(0.05)
	_check(c.in_secret and c.map.name == "treasure", "the secret portal leads to a treasure room")
	c.pos = c.map.chests[0]["pos"] + Vector2(0, 40)
	c._update_map(0.05)
	_check(c.map.chests[0]["open"] and g.save.found.size() == found_before + 1, "its chest holds a treasure (%s)" % c.found_treasure)
	var got: String = c.found_treasure
	_check(g.save.worn.values().has(got), "...worn at once")
	c.pos = c.map.back_portal
	c.portal_cd = 0.0
	c._update_map(0.05)
	_check(not c.in_secret and c.map == sm, "its portal leads back to the floor as it was")
	g.go_home()
	await _frames(1)


func _fall_test() -> void:
	g.start_climb("gryphon")
	await _frames(2)
	var c = g.screen
	c.set_process(false)
	var grown := float(g.save.marks["air"]["grown"])
	c.bag = {"air": 5.0}
	c.barrier_t = 0.0
	c.safe_t = 0.0
	c.hearts = 1
	c._hurt_player(c.pos + Vector2(10, 0))
	_check(c.phase == "fallen" and c.banner == Data.TEXT["lost"], "losing the last heart ends the climb (\"%s\")" % c.banner)
	for k in int(Data.FALL_WAIT / 0.05) + 4:
		if g.screen != c:
			break
		c._step(0.05)
	await _frames(2)
	_check(g.screen.has_method("suggested"), "...and goes home")
	_check(float(g.save.marks["air"]["grown"]) == grown, "...keeping what was banked (what was carried is lost)")
	# Hearts carry over; a stair gives some back.
	g.start_climb("gryphon")
	await _frames(2)
	c = g.screen
	c.set_process(false)
	c.hearts = 2
	c.monsters.clear()
	c.phase = "clear"
	c.pos = c.stair_pos
	c.sparks.clear()
	c._step(0.05)
	c.phase_t = 5.0
	c._step(0.05)
	_check(c.floor_i == 1 and c.hearts == 2 + Data.HEARTS_AT_STAIR, "hearts carry to the next floor, and the stair gives %d back" % Data.HEARTS_AT_STAIR)
	g.go_home()
	await _frames(1)


func _harder_test() -> void:
	g.start_climb("kraken")
	await _frames(2)
	var c = g.screen
	c.set_process(false)
	c._start_floor(0)
	var low: Dictionary = c.monsters[1]
	var low_n: int = c.monsters.size()
	c._start_floor(4)
	var high: Dictionary = c.monsters[1]
	_check(c.monsters.size() > low_n, "more monsters higher up (%d, then %d)" % [low_n, c.monsters.size()])
	_check(int(high["hp"]) > int(low["hp"]) and float(high["speed"]) > float(low["speed"]) and float(high["windup"]) < float(low["windup"]), "monsters on floor 5 have more health, are faster and strike sooner (hp %d/%d)" % [low["hp"], high["hp"]])
	_check(float(high["windup"]) >= Data.MIN_WINDUP, "...but still give fair warning (%.2f s)" % float(high["windup"]))
	_check(c.monsters[0]["elite"] and int(c.monsters[0]["hp"]) > int(high["hp"]), "...and one is an elite")
	# Throws come three at once higher up.
	_open_room(c)
	var sh: Dictionary = {}
	for m in c.monsters:
		if m["kind"] == "shooter":
			sh = m
	if not sh.is_empty():
		c.monsters = [sh]
		sh["pos"] = c.pos + Vector2(0, -300)
		sh["state"] = "windup"
		sh["t"] = 0.0
		c.orbs.clear()
		c._shooter(sh, 0.01, Vector2.DOWN, 300.0, Vector2.DOWN, true)
		_check(c.orbs.size() == 3, "throwers throw three at once higher up")
	# The beast: tougher in later towers, fiercer at half health, and it leaps.
	c._start_floor(5)
	var b: Dictionary = c.monsters[0]
	_check(int(b["max"]) == Data.BEAST_HP + Data.BEAST_HP_STEP, "the Kraken (the second beast) is tougher: %d health" % int(b["max"]))
	_open_room(c)
	b["state"] = "walk"
	b["hp"] = int(b["max"]) / 2 + 1
	c._damage(b, 2, Vector2.ZERO)
	_check(b["fury"] and c.beast_called, "at half health it gets fierce and calls its monsters")
	c.monsters = [b]
	b["pos"] = c.pos + Vector2(0, -200)
	b["next"] = "slam"
	b["state"] = "walk"
	b["t"] = 0.0
	c._beast(b, 0.01, Vector2.DOWN, 200.0, Vector2.DOWN, true)
	_check(b["state"] == "windup" and b["slam_at"] == c.pos, "its leap marks where you stand")
	b["t"] = 0.0
	c._beast(b, 0.01, Vector2.DOWN, 200.0, Vector2.DOWN, true)
	c.safe_t = 0.0
	c.barrier_t = 0.0
	c.parry_t = 0.0
	c.roll_t = 0.3  # (rolling as it lands)
	var h: int = c.hearts
	for k in 12:
		c._beast(b, 0.05, Vector2.DOWN, 10.0, Vector2.DOWN, true)
	_check(b["state"] == "rest" and c.hearts == h, "a roll gets away from its landing")
	b["next"] = "slam"
	b["state"] = "walk"
	b["t"] = 0.0
	c._beast(b, 0.01, Vector2.DOWN, 200.0, Vector2.DOWN, true)
	b["t"] = 0.0
	c._beast(b, 0.01, Vector2.DOWN, 200.0, Vector2.DOWN, true)
	c.roll_t = 0.0
	c.safe_t = 0.0
	for k in 12:
		c._beast(b, 0.05, Vector2.DOWN, 10.0, Vector2.DOWN, true)
	_check(c.hearts == h - 1, "standing in its circle costs a heart")
	g.go_home()
	await _frames(1)


func _upgrade_test() -> void:
	g.save.pending_ups.clear()
	var e := "air"
	var before: int = g.save.star(e)
	var need := float(Data.STAR_AT[before]) - float(g.save.marks[e]["grown"]) + 1.0
	g.save.grow(e, need)
	_check(g.save.star(e) == before + 1 and g.save.pending_ups == [e], "a new star queues an upgrade to pick")
	g.show_upgrades()
	await _frames(2)
	var up = g.upgrades
	_check(up != null and up.choices.size() == 2, "the pick shows two choices: %s" % [up.choices if up != null else []])
	var choice: String = up.choices[0]
	up.pick(choice)
	up.picked_t = 2.0
	up._process(0.0)
	await _frames(2)
	_check(g.save.ups(e, choice) == 1 and g.save.pending_ups.is_empty() and g.upgrades == null, "picking one keeps it (%s) and closes the pick" % choice)
	for st in range(2, Data.STAR_MAX + 1):
		for id in Data.upgrade_choices(e, st):
			_check(Data.UPGRADE_INFO.has(id), "star %d's upgrade %s has a word and a picture" % [st, id])
	# Their effects, in the open arena.
	g.start_climb("gryphon")
	await _frames(2)
	var c = g.screen
	_open_room(c)
	var m: Dictionary = c.monsters[0]
	c.monsters = [m]
	m["pos"] = c.pos + Vector2(0, -120)
	m["state"] = "walk"
	m["stun"] = 0.0
	g.save.marks[e]["ups"] = []
	var base: float = c.recharge_of(e)
	var dmg0: int = c._mdmg(e, g.save.star(e))
	g.save.marks[e]["ups"] = ["power", "quick", "air_a"]
	_check(c._mdmg(e, g.save.star(e)) == dmg0 + 1, "Stronger! adds damage")
	_check(c.recharge_of(e) < base, "Faster! recharges sooner")
	m["hp"] = 99
	c.chosen = e
	c.recharge[e] = 0.0
	c._cast()
	_check(m["stun"] > 0.0 and int(m["hp"]) < 99, "Zap stuns! stuns what the lightning hits")
	g.save.marks[e]["ups"] = []
	g.go_home()
	await _frames(1)
	g.close_upgrades()


func _play_style_test() -> void:
	var s = Save.new()
	s.bank({"air": 10.0}, {"legs": 5.0})
	_check(float(s.soak.get("legs", 0.0)) > 0.0 and s.soak.size() == 1, "rolling fills the legs (play style)")
	s.weapon_use = {"dagger": 30.0, "sword": 3.0}
	_check(s.favourite() == "dagger", "the most used weapon is the favourite")
	var t = Save.new()
	t.weapon_use = {"dagger": 30.0}
	t.bank({"air": 10.0}, {"back": 1.0, "hand": 1.0})
	_check(float(t.soak["back"]) > float(t.soak["hand"]), "the favourite weapon's part fills faster")
	_check(s.regard("kraken") and s.marks["water"]["part"] == "legs", "a new mark goes on the fullest part (the legs, not the Kraken's usual heart)")
	var u = Save.new()
	u.marks = {"fire": {"part": "hand", "grown": 0.0, "ups": []}}
	u.bank({"water": 10.0}, {"hand": 1.0})
	_check(is_equal_approx(float(u.marks["fire"]["grown"]), 10.0 * Data.BODY_SHARE + 10.0 * (1.0 - Data.BODY_SHARE) * Data.OTHER_SHARE), "a marked part grows its mark from play style too")


func _lunger(c) -> Dictionary:
	var m: Dictionary = c.monsters[0]
	m["state"] = "lunge"
	m["t"] = 0.2
	m["stun"] = 0.0
	m["kind"] = "walker"
	m["pos"] = c.pos + Vector2(0, -(m["r"] + c.PLAYER_R))
	m["dir"] = Vector2.DOWN
	return m


func _walk(c, m: Dictionary) -> void:
	c._walker(m, 0.01, Vector2.DOWN, 10.0, Vector2.DOWN, true)


func _combat_test() -> void:
	g.start_climb("wyvern")
	await _frames(2)
	var c = g.screen
	_open_room(c)
	for m in c.monsters:
		m["state"] = "walk"
	c.monsters = [c.monsters[0]]
	c.safe_t = 0.0
	c.hearts = Data.HEARTS
	c.pad.roll_pressed = true
	c._update_player(0.01)
	c.pad.consume()
	_check(c.roll_t > 0.0, "Roll starts a roll")
	var h: int = c.hearts
	c._hurt_player(c.pos + Vector2(10, 0))
	_check(c.hearts == h, "...and a hit during a roll is dodged")
	c.roll_t = 0.0
	c.safe_t = 0.0
	c.pad.parry_pressed = true
	c._update_player(0.01)
	c.pad.consume()
	_check(c.parry_t > 0.0 and Data.PARRY_WINDOW > 0.32, "Parry opens a window (wider than the full game's)")
	var m := _lunger(c)
	_walk(c, m)
	_check(c.hearts == h and m["stun"] > 0.0, "a lunge into a parry is blocked, and the monster is stunned")
	_check(c.parry_cd <= 0.0, "...and the parry is ready again at once")
	c.safe_t = 0.0
	c.parry_t = Data.PARRY_WINDOW
	c.orbs.clear()
	c._throw(c.pos + c.BODY + Vector2(0, -20), Vector2.DOWN)
	c._update_orbs(0.01)
	_check(c.orbs.size() == 1 and c.orbs[0]["mine"] and c.hearts == h, "a parried throw turns back")
	var target: Dictionary = c.monsters[0]
	target["pos"] = c.orbs[0]["pos"] + c.orbs[0]["vel"].normalized() * 30.0 - c.BODY * 0.5
	target["state"] = "walk"
	target["hp"] = 50
	for k in 10:
		c._update_orbs(0.02)
	_check(int(target["hp"]) < 50, "...and hurts the monster it hits")
	c.parry_t = 0.0
	c.parry_cd = 0.0
	c.safe_t = 0.0
	m = _lunger(c)
	_walk(c, m)
	_check(c.hearts == h - 1, "a lunge that isn't parried or rolled away costs a heart")
	c.swap_weapon("sword")
	var seen := []
	for k in Data.WEAPON_ORDER.size():
		seen.append(c.weapon)
		c.swap_weapon()
	_check(seen == Data.WEAPON_ORDER and c.weapon == "sword", "Swap goes round the weapons: %s" % [seen])
	c.swap_weapon("hammer")
	_check(g.save.weapon == "hammer" and c.banner == "Hammer", "the weapon in hand is saved, and its name shows")
	c.safe_t = 5.0
	m["state"] = "walk"
	m["stun"] = 0.0
	m["hp"] = 99
	m["pos"] = c.pos + Vector2(0, -60)
	c.swing_cd = 0.0
	c._swing()
	_check(int(m["hp"]) == 99 - int(Data.WEAPONS["hammer"]["damage"]) and m["stun"] > 0.0, "the hammer hits hard and stuns")
	_check(float(g.save.weapon_use.get("hammer", 0.0)) > 0.0, "...and its hits count toward the favourite weapon")
	c.swap_weapon("bow")
	m["pos"] = c.pos + Vector2(0, -400)
	m["kv"] = Vector2.ZERO
	var before: int = m["hp"]
	c.swing_cd = 0.0
	c._swing()
	_check(c.arrows.size() == 1, "the bow shoots an arrow at the nearest monster")
	for k in 40:
		c._update_arrows(0.02)
	_check(int(m["hp"]) < before and c.arrows.is_empty(), "...that hits it from afar")
	c.swap_weapon("sword")
	# Walls: a monster out of sight goes round them; throws stop at them.
	var wm = FloorMap.new()
	wm.load_layout("islands", false)
	c.map = wm
	_check(not wm.line_clear(Vector2(640, 600), Vector2(640, 100)), "walls block sight")
	_check(wm.blocked(wm.center(Vector2i(5, 4))), "...and throws")
	g.go_home()
	await _frames(1)


func _climber_screen_test() -> void:
	g.open_climber()
	await _frames(3)
	var s = g.screen
	_check(s.has_method("_tab") and s.tab == "marks", "the climber screen opens on Marks")
	s._tab("weapons")
	s._pick_weapon("dagger")
	_check(s.tab == "weapons" and g.save.weapon == "dagger", "Weapons: tapping one holds it")
	s._tab("look")
	s._group("hair")
	var app: Dictionary = Look.normalized(g.save.app).duplicate()
	s._step_look("hair_color", 1)
	_check(String(g.save.app["hair_color"]) != String(app["hair_color"]), "Look: the arrows change the hair colour")
	s._random_look()
	_check(not g.save.app.is_empty(), "...and the die picks a whole new look")
	s._tab("treasure")
	await _frames(2)
	var id: String = g.save.found[0]
	var slot: String = g.save.slot_of(id)
	g.save.worn[slot] = id
	s._toggle_wear(id)
	_check(not g.save.worn.has(slot), "Treasure: tapping a worn treasure takes it off")
	s._toggle_wear(id)
	_check(g.save.worn.get(slot, "") == id, "...and tapping it again wears it")
	_check(g.worn_gear().size() + (1 if g.worn_skin() != "" else 0) == g.save.worn.size(), "what's worn shows on the climber")
	for k in Data.TREASURES:
		var tr: Dictionary = Data.TREASURES[k]
		_check(tr["kind"] == "skin" and GearLook.SKINS.has(tr["piece"]) or GearLook.catalog().has(tr["piece"]), "the treasure %s (%s) can be drawn" % [k, tr["word"]])
	await _frames(3)
	var loaded = Save.load_save()
	_check(loaded.weapon == "dagger" and String(loaded.app.get("hair_color", "")) == String(g.save.app["hair_color"]), "the weapon and the look are saved")
	for row in Look.kid_rows():
		_check(Data.LOOK_WORDS.has(row["key"]), "the Look choice %s has a word" % row["key"])
	s._back()
	await _frames(1)
	_check(g.screen.has_method("suggested"), "Back goes home")
	for tw in Data.ORDER:
		_check(Creatures.is_beast(tw) and Creatures.radius(tw) > 20.0, "the %s is drawn as in the full game" % tw)
	for mid in Data.MONSTERS:
		_check(Creatures.KINDS.has(mid), "the %s is drawn as in the full game" % mid)


func _save_test() -> void:
	g.save.soak = {"legs": 4.0}
	g.save.pending_ups = ["air"]
	g.save.marks["air"]["ups"] = ["power"]
	g.save.save()
	var s = Save.load_save()
	_check(s.marks.size() == g.save.marks.size() and s.beaten.size() == g.save.beaten.size() and s.seen.size() == g.save.seen.size(), "the save keeps marks, beaten beasts and the guide's moments")
	_check(s.found == g.save.found and s.worn == g.save.worn, "...treasures found and worn")
	_check(float(s.soak.get("legs", 0.0)) == 4.0 and s.pending_ups == ["air"] and s.ups("air", "power") == 1, "...play style, upgrades and picks still to make")
	g.save.pending_ups.clear()
	g.save.marks["air"]["ups"] = []
	for e in Data.MAGIC:
		_check(Data.MAGIC[e].has("bond") and Data.TOWERS.values().any(func(tw): return tw["essence"] == e), "%s's magic is based on a bond (%s) and comes from a tower" % [e, Data.MAGIC[e].get("bond", "?")])


func _words_test() -> void:
	for k in Data.TEXT:
		_check(String(Data.TEXT[k]).split(" ").size() <= 5, "the words stay short: \"%s\"" % Data.TEXT[k])
	for e in Data.MAGIC:
		_check(String(Data.MAGIC[e].get("word", "")).length() in range(2, 8), "%s's button says \"%s\"" % [e, Data.MAGIC[e].get("word", "")])
	_check(Art.font() != null and Art.font() != ThemeDB.fallback_font, "the words use Andika, the reading font")
	var lines: Array = Data.spoken()
	for k in ["hint_move", "hint_plates", "open", "treasure", "lost"]:
		_check(lines.has(Data.TEXT[k]), "\"%s\" is among the spoken lines" % Data.TEXT[k])
	if not g.voice_clips.is_empty():
		var missing: Array = lines.filter(func(l): return not g.voice_clips.has(l))
		_check(missing.is_empty(), "every spoken line has a natural voice clip %s" % [missing.slice(0, 5)])
		var any: String = g.voice_clips.values()[0]
		_check(ResourceLoader.exists(any), "...and the clips are there (%s)" % any)


## Every sound the game plays is in its sound list (sounds.gd).
func _sound_test() -> void:
	var names := {}
	var re := RegEx.new()
	re.compile("sfx\\(\"([a-z_]+)\"")
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string("res://scripts/" + f)):
				if not m.get_string(1).ends_with("_"):  # (a name built in code: checked below)
					names[m.get_string(1)] = true
	for id in Data.MONSTERS:
		names["hurt_" + id] = true
		names["kill_" + id] = true
	for tw in Data.ORDER:
		for k in ["hurt_", "kill_", "roar_", "warn_"]:
			names[k + tw] = true
	for e in Data.MAGIC:
		names[Data.MAGIC[e]["sound"]] = true
	# A few monsters have no warning cry in the full game either: they stay quiet.
	var missing: Array = names.keys().filter(func(n): return not g.audio.has_sound(n) and not String(n).begins_with("warn_"))
	_check(missing.is_empty(), "every sound it plays is there %s" % [missing])
	_check(g.audio.music != null and g.audio.music.playing, "the music plays")
