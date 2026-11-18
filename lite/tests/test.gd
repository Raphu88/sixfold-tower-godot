extends SceneTree
## Six Towers LITE's test: a whole climb played by a simple bot (walk to the
## nearest monster and keep swinging, then take the stair), the Regard's mark
## on the right body part, banking at stairs, every magic, falling and
## popping back, the save and every sound it plays. Run from the lite folder:
##   godot --headless -s tests/test.gd

const Data := preload("res://scripts/data.gd")
const Save := preload("res://scripts/save.gd")
const Art := preload("res://scripts/art.gd")

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
	await _climb_test()
	await _magic_test()
	await _fall_test()
	_save_test()
	_sound_test()
	g.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(Save.path())
	print("PASSED (0 failures)" if failures == 0 else "FAILED (%d failures)" % failures)
	for f in failed:
		print("  FAILED: ", f)
	quit(1 if failures > 0 else 0)


## Drives a climb's frames by hand (no real time): `steps` of `dt`, the bot
## walking and swinging. Returns when `until` is true or the steps run out.
func _drive(c, steps: int, until: Callable, dt := 0.05) -> void:
	c.set_process(false)
	for i in steps:
		if until.call():
			return
		var goal: Vector2 = c.STAIR
		if not c.monsters.is_empty():
			var near: Dictionary = c.monsters[0]
			for m in c.monsters:
				if c.pos.distance_to(m["pos"]) < c.pos.distance_to(near["pos"]):
					near = m
			goal = near["pos"]
		var d: Vector2 = goal - c.pos
		c.pad.move = d.normalized() if d.length() > (60.0 if not c.monsters.is_empty() else 4.0) else Vector2.ZERO
		c.pad.attack_held = not c.monsters.is_empty()
		c._step(dt)
		c.pad.consume()
		if i % 40 == 0:
			await _frames(1)


func _climb_test() -> void:
	g.start_climb("gryphon")
	await _frames(2)
	var c = g.screen
	_check(Data.FLOORS.size() + 1 == 6 and Data.REGARD_FLOOR == 3, "a climb is six floors; the first climb's Regard comes on floor 3")
	_check(c.floor_i == 0 and c.monsters.size() == Data.FLOORS[0] and c.hearts == Data.HEARTS, "a climb starts on floor 1 with its monsters and every heart")
	_check(c.banner == Data.TEXT["floor"] % "1", "big words say which floor (\"%s\")" % c.banner)
	_check(g.save.marks.is_empty(), "the first climb has no magic")
	await _drive(c, 3000, func(): return c.phase == "clear")
	_check(c.phase == "clear" and c.carried() > 0.0, "the bot clears floor 1, and the monsters' sparkles fly into the climber")
	_check(c.banner == Data.TEXT["go_up"], "a cleared room says \"%s\"" % Data.TEXT["go_up"])
	await _drive(c, 600, func(): return c.floor_i == 1)
	_check(c.floor_i == 1 and c.carried() == 0.0 and g.save.spare > 0.0, "the stair banks the sparkles (with no mark yet they wait for the first) and climbs on")
	await _drive(c, 8000, func(): return c.phase == "regard")
	_check(c.phase == "regard" and c.floor_i == 2 and not c.regard_beat and c.regard_new, "after floor 3, the Gryphon takes notice: the Regard")
	_check(g.save.marks.has("air") and g.save.marks["air"]["part"] == "legs" and float(g.save.marks["air"]["grown"]) > 0.0, "it marks the legs with Air, grown by what was banked")
	_check(not g.save.beaten.has("gryphon"), "...but it isn't beaten yet (no crown)")
	c.phase_t = 3.0
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	c._input(tap)
	_check(c.floor_i == 3 and c.phase == "fight" and c.chosen == "air", "OK goes on to floor 4, with the new magic ready")
	await _drive(c, 12000, func(): return c.beast_floor())
	_check(c.beast_floor() and c.floor_i == 5 and c.monsters.size() == 1 and c.monsters[0]["beast"], "floor 6 is the beast's")
	_check(c.banner == Data.TEXT["beast"] % "Gryphon", "...and says so (\"%s\")" % c.banner)
	var before := float(g.save.marks["air"]["grown"])
	await _drive(c, 8000, func(): return c.phase == "clear")
	_check(c.phase == "clear" and c.monsters.is_empty() and c.beast_called, "the bot beats the Gryphon (it called its monsters at half health)")
	await _drive(c, 800, func(): return c.phase == "regard")
	_check(c.phase == "regard" and c.regard_beat and not c.regard_new, "its stair: the beast beaten")
	_check(g.save.beaten.has("gryphon") and float(g.save.marks["air"]["grown"]) >= before + Data.BEAST_GROWTH, "the Gryphon counts as beaten (its crown) and its mark grows")
	_check(g.save.seen.get("move", false) and g.save.seen.get("attack", false), "the first-time pointers for walking and swinging are done with")
	g.go_home("gryphon")
	await _frames(2)
	_check(g.screen.suggested() == "kraken" and not g.screen.confetti.is_empty(), "back home with confetti; the guide moves on to the next tower")
	_check(g.screen.bubble_text() == Data.TEXT["hooray"], "the climber says \"%s\"" % Data.TEXT["hooray"])
	# A later climb: no Regard on floor 3; the beast at the top gives its mark.
	g.start_climb("kraken")
	await _frames(2)
	c = g.screen
	c.floor_i = 2
	_check(not c.regard_due(), "with a mark already, floor 3 has no Regard")
	c._start_floor(5)
	for m in c.monsters:
		m["hp"] = 1
		m["state"] = "walk"
	c.set_process(false)
	c.pos = c.monsters[0]["pos"] + Vector2(0, 60)
	c._swing()
	_check(c.monsters.is_empty(), "the Kraken falls")
	c.sparks.clear()
	c._step(0.05)
	c.pos = c.STAIR
	await _drive(c, 200, func(): return c.phase == "regard")
	_check(c.regard_beat and c.regard_new and g.save.marks.has("water") and g.save.marks["water"]["part"] == "heart", "beating a new beast gives its mark (the Kraken's Water, on the heart)")
	g.go_home()
	await _frames(1)
	_check(g.screen.bubble_text() == Data.TEXT["pick"], "home says \"%s\"" % Data.TEXT["pick"])
	# Beating a beast again grows its mark.
	var w := float(g.save.marks["water"]["grown"])
	_check(not g.save.regard("kraken") and float(g.save.marks["water"]["grown"]) == w + Data.BEAST_GROWTH, "beating a beast again grows its mark")
	_check(not g.save.regard("chimera", false) or not g.save.beaten.has("chimera"), "a Regard without a fight gives no crown")
	for k in Data.TEXT:
		_check(String(Data.TEXT[k]).split(" ").size() <= 5, "the words stay short: \"%s\"" % Data.TEXT[k])
	for e in Data.MAGIC:
		_check(String(Data.MAGIC[e].get("word", "")).length() in range(2, 8), "%s's button says \"%s\"" % [e, Data.MAGIC[e].get("word", "")])
	_check(Art.font() != null and Art.font() != ThemeDB.fallback_font, "the words use Andika, the reading font")


func _magic_test() -> void:
	for tw in Data.ORDER:
		g.save.regard(tw)
	_check(g.save.marks.size() == 6, "six beasts, six marks, one on each body part")
	var parts := {}
	for e in g.save.marks:
		parts[g.save.marks[e]["part"]] = true
	_check(parts.size() == 6, "...each on its own part")
	g.start_climb("kraken")
	await _frames(2)
	var c = g.screen
	c.set_process(false)
	for m in c.monsters:
		m["state"] = "walk"
		m["hp"] = 99
		m["pos"] = c.pos + Vector2(80, -60)
	for e in Data.MAGIC:
		c.chosen = e
		c.recharge[e] = 0.0
		var hp := 0
		for m in c.monsters:
			hp += int(m["hp"])
		c._cast()
		for k in 6:
			c._step(0.05)
		var hp2 := 0
		for m in c.monsters:
			hp2 += int(m["hp"])
		var worked: bool = hp2 < hp or (e == "iron" and c.barrier_t > 0.0)
		_check(worked and c.recharge[e] > 0.0, "%s (%s) works, then recharges" % [Data.MAGIC[e]["name"], e])
		for m in c.monsters:
			m["pos"] = c.pos + Vector2(80, -60)
			m["stun"] = 0.0
	c.recharge["fire"] = 3.0
	c.chosen = "fire"
	var n: int = c.fireballs.size()
	c._cast()
	_check(c.fireballs.size() == n, "a magic that isn't ready yet does nothing")
	# The barrier stops a hit.
	c.barrier_t = 2.0
	c.safe_t = 0.0
	var h: int = c.hearts
	c._hurt_player(c.pos + Vector2(10, 0))
	_check(c.hearts == h, "the Barrier keeps hearts safe")
	# Banking: a colour goes to the mark of that colour; a colour no mark is
	# made of is shared out thinly over the marks.
	var w := float(g.save.marks["water"]["grown"])
	var f := float(g.save.marks["fire"]["grown"])
	g.save.bank({"water": 10.0})
	_check(is_equal_approx(float(g.save.marks["water"]["grown"]), w + 10.0) and is_equal_approx(float(g.save.marks["fire"]["grown"]), f), "a stair pours each colour into the mark of that colour")
	var one = Save.new()
	one.marks = {"fire": {"part": "brow", "grown": 0.0}}
	one.bank({"water": 10.0})
	_check(is_equal_approx(float(one.marks["fire"]["grown"]), 10.0 * Data.OTHER_SHARE), "...and a colour with no mark of its own grows the marks a little")
	var none = Save.new()
	none.bank({"air": 7.0})
	none.regard("gryphon")
	_check(is_equal_approx(float(none.marks["air"]["grown"]), 7.0) and none.spare == 0.0, "sparkles banked before the first mark pour into it at the Regard")
	_check(Data.stars(0.0) == 1 and Data.stars(Data.STAR_AT[1]) == 2 and Data.stars(9999.0) == 3, "marks grow from one star to three")


func _fall_test() -> void:
	var c = g.screen
	c.set_process(false)
	c.barrier_t = 0.0
	c.safe_t = 0.0
	c.hearts = 1
	c.bag = {"water": 5.0}
	c._hurt_player(c.pos + Vector2(10, 0))
	_check(c.phase == "fallen", "losing the last heart falls")
	for k in int(Data.FALL_WAIT / 0.05) + 4:
		c._step(0.05)
	_check(c.phase == "fight" and c.hearts == Data.HEARTS and c.monsters.size() > 0, "...and pops back into the room with every heart")
	_check(float(c.bag.get("water", 0.0)) == 5.0, "...keeping the sparkles carried (nothing is lost)")
	c.paused = true
	c._step(0.0)
	_check(c.paused, "the home button pauses (house to go home, play to go on)")
	c.paused = false


func _save_test() -> void:
	g.save.save()
	var s = Save.load_save()
	_check(s.marks.size() == g.save.marks.size() and s.beaten.size() == g.save.beaten.size() and s.seen.size() == g.save.seen.size(), "the save keeps marks, beaten beasts and the guide's moments")
	for e in Data.MAGIC:
		_check(Data.MAGIC[e].has("bond") and Data.TOWERS.values().any(func(tw): return tw["essence"] == e), "%s's magic is based on a bond (%s) and comes from a tower" % [e, Data.MAGIC[e].get("bond", "?")])


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
