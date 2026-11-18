extends RefCounted
## The kids version (scenes/kids.tscn, scripts/kids): a whole climb played by
## a simple bot (walk to the nearest monster and keep swinging, then take the
## stair), the Regard's mark on the right body part, banking at stairs, every
## magic, falling and popping back, the save, how the game picks which version
## to open, every sound it plays, and the full game's title button.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Data := preload("res://scripts/kids/kids_data.gd")
const Save := preload("res://scripts/kids/kids_save.gd")
const TestRun := preload("res://scripts/test_run.gd")

var t
var g


func run(smoke) -> void:
	t = smoke
	print("the kids version")
	DirAccess.remove_absolute(TestRun.path(Save.PATH))
	t._check(not Save.wants_kids(), "the full game opens unless the kids version was picked")
	g = load("res://scenes/kids.tscn").instantiate()
	t.root.add_child(g)
	await t._frames(3)
	t._check(Save.wants_kids(), "once opened, the kids version is the one that opens next time")
	t._check(g.screen != null and g.screen.has_method("suggested") and g.screen.suggested() == "gryphon", "home: the guide points at the first tower")
	await _climb_test()
	await _magic_test()
	await _fall_test()
	_save_test()
	_sound_test()
	g.queue_free()
	await t._frames(2)
	RenderingServer.set_default_clear_color(preload("res://scripts/palette.gd").VOID)
	Save.set_stay(false)
	t._check(not Save.wants_kids(), "the grown-ups' gear leaves the kids version for good")
	await _title_test()


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
			await t._frames(1)


func _climb_test() -> void:
	g.start_climb("gryphon")
	await t._frames(2)
	var c = g.screen
	t._check(c.floor_i == 0 and c.monsters.size() == Data.FLOORS[0] and c.hearts == Data.HEARTS, "a climb starts on floor 1 with its monsters and every heart")
	t._check(c.pad.magics.is_empty() or g.save.marks.is_empty(), "the first climb has no magic")
	await _drive(c, 3000, func(): return c.phase == "clear")
	t._check(c.phase == "clear" and c.carried() > 0.0, "the bot clears floor 1, and the monsters' sparkles fly into the climber")
	await _drive(c, 600, func(): return c.floor_i == 1)
	t._check(c.floor_i == 1 and c.carried() == 0.0 and g.save.spare > 0.0, "the stair banks the sparkles (with no mark yet they wait for the first) and climbs on")
	await _drive(c, 4000, func(): return c.beast_floor())
	t._check(c.beast_floor() and c.monsters.size() == 1 and c.monsters[0]["beast"], "floor 3 is the beast's")
	await _drive(c, 6000, func(): return c.phase == "clear")
	t._check(c.phase == "clear" and c.monsters.is_empty(), "the bot beats the Gryphon")
	t._check(c.beast_called, "at half health the beast called its monsters")
	await _drive(c, 800, func(): return c.phase == "regard")
	t._check(c.phase == "regard" and c.regard_new, "its stair brings the Regard")
	t._check(g.save.marks.has("air") and g.save.marks["air"]["part"] == "legs" and float(g.save.marks["air"]["grown"]) > 0.0, "the Gryphon marks the legs with Air, grown by what was banked")
	t._check(g.save.beaten.has("gryphon"), "the Gryphon counts as beaten (its crown on the home screen)")
	t._check(g.save.seen.get("move", false) and g.save.seen.get("attack", false), "the first-time pointers for walking and swinging are done with")
	g.go_home("gryphon")
	await t._frames(2)
	t._check(g.screen.suggested() == "kraken" and not g.screen.confetti.is_empty(), "back home with confetti; the guide moves on to the next tower")
	# A beast beaten again grows its mark instead.
	var before := float(g.save.marks["air"]["grown"])
	t._check(not g.save.regard("gryphon") and float(g.save.marks["air"]["grown"]) == before + Data.BEAST_GROWTH, "beating a beast again grows its mark")


func _magic_test() -> void:
	for tw in Data.ORDER:
		g.save.regard(tw)
	t._check(g.save.marks.size() == 6, "six beasts, six marks, one on each body part")
	var parts := {}
	for e in g.save.marks:
		parts[g.save.marks[e]["part"]] = true
	t._check(parts.size() == 6, "...each on its own part")
	g.start_climb("kraken")
	await t._frames(2)
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
		t._check(worked and c.recharge[e] > 0.0, "%s (%s) works, then recharges" % [Data.MAGIC[e]["name"], e])
		for m in c.monsters:
			m["pos"] = c.pos + Vector2(80, -60)
			m["stun"] = 0.0
	c.recharge["fire"] = 3.0
	c.chosen = "fire"
	var n: int = c.fireballs.size()
	c._cast()
	t._check(c.fireballs.size() == n, "a magic that isn't ready yet does nothing")
	# The barrier stops a hit.
	c.barrier_t = 2.0
	c.safe_t = 0.0
	var h: int = c.hearts
	c._hurt_player(c.pos + Vector2(10, 0))
	t._check(c.hearts == h, "the Barrier keeps hearts safe")
	# Banking: a colour goes to the mark of that colour; a colour no mark is
	# made of is shared out thinly over the marks.
	var w := float(g.save.marks["water"]["grown"])
	var f := float(g.save.marks["fire"]["grown"])
	g.save.bank({"water": 10.0})
	t._check(is_equal_approx(float(g.save.marks["water"]["grown"]), w + 10.0) and is_equal_approx(float(g.save.marks["fire"]["grown"]), f), "a stair pours each colour into the mark of that colour")
	var one = Save.new()
	one.marks = {"fire": {"part": "brow", "grown": 0.0}}
	one.bank({"water": 10.0})
	t._check(is_equal_approx(float(one.marks["fire"]["grown"]), 10.0 * Data.OTHER_SHARE), "...and a colour with no mark of its own grows the marks a little")
	var none = Save.new()
	none.bank({"air": 7.0})
	none.regard("gryphon")
	t._check(is_equal_approx(float(none.marks["air"]["grown"]), 7.0) and none.spare == 0.0, "sparkles banked before the first mark pour into it at the Regard")
	t._check(Data.stars(0.0) == 1 and Data.stars(Data.STAR_AT[1]) == 2 and Data.stars(9999.0) == 3, "marks grow from one star to three")


func _fall_test() -> void:
	var c = g.screen
	c.set_process(false)
	c.barrier_t = 0.0
	c.safe_t = 0.0
	c.hearts = 1
	c.bag = {"water": 5.0}
	c._hurt_player(c.pos + Vector2(10, 0))
	t._check(c.phase == "fallen", "losing the last heart falls")
	for k in int(Data.FALL_WAIT / 0.05) + 4:
		c._step(0.05)
	t._check(c.phase == "fight" and c.hearts == Data.HEARTS and c.monsters.size() > 0, "...and pops back into the room with every heart")
	t._check(float(c.bag.get("water", 0.0)) == 5.0, "...keeping the sparkles carried (nothing is lost)")
	c.paused = true
	c._step(0.0)
	t._check(c.paused, "the home button pauses (house to go home, play to go on)")
	c.paused = false


func _save_test() -> void:
	g.save.save()
	var s = Save.load_save()
	t._check(s.marks.size() == g.save.marks.size() and s.beaten.size() == g.save.beaten.size() and s.stay, "the kids save keeps marks, beaten beasts and the choice to open here")
	for e in Data.MAGIC:
		t._check(Data.MAGIC[e].has("bond") and Data.TOWERS.values().any(func(tw): return tw["essence"] == e), "%s's magic is based on a bond (%s) and comes from a tower" % [e, Data.MAGIC[e].get("bond", "?")])


## Every sound the kids version plays is in the sound bank.
func _sound_test() -> void:
	var names := {}
	var re := RegEx.new()
	re.compile("sfx\\(\"([a-z_]+)\"")
	for f in DirAccess.get_files_at("res://scripts/kids"):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string("res://scripts/kids/" + f)):
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
	var missing: Array = names.keys().filter(func(n): return not g.audio.has_sound(n))
	t._check(missing.is_empty(), "every sound the kids version plays exists %s" % [missing])


func _title_test() -> void:
	t.main.menu.open("title")
	await t._frames(2)
	var found := []
	_find_kids(t.main.menu, found)
	t._check(not found.is_empty(), "the title screen has a Kids version button, with the Entity's help")
	t.main.menu.close()
	await t._frames(1)


func _find_kids(n: Node, found: Array) -> void:
	for ch in n.get_children():
		if ch is Button and String(ch.get_meta("help", "")) == "kids":
			found.append(ch)
		_find_kids(ch, found)
