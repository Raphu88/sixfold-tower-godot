extends RefCounted
## Basic training as ONE SESSION (tutorial.gd, arena.gd "basics",
## station_page.gd's basic tile and card): every step present, in order, and
## covering the whole basic moveset (walking, jumping with one moving jump,
## rolling, striking, the finisher, swapping to the bow, the full draw, the
## off-hand wand, powering it, parrying, blocking with a shield, the belt and
## its wheel); the session run from its first step to its last without
## leaving the arena, each step advancing only on its own action (the wrong
## weapon, a weak shot, a standing jump, an item used without the wheel
## don't count); done, the six old parts marked done, renown once, the first
## tournament open; left part way, Resume from that step and Start over;
## skipping (refused for a first-timer before the Grace, allowed after);
## the prompts in keys, controller buttons and touch buttons; the Entity's
## words and button help; no banned words. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const Tutorial := preload("res://scripts/tutorial.gd")
const Stations := preload("res://scripts/stations.gd")
const Training := preload("res://scripts/training.gd")
const Travel := preload("res://scripts/travel.gd")
const Renown := preload("res://scripts/renown.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Offhand := preload("res://scripts/offhand.gd")
const ItemPool := preload("res://scripts/item_pool.gd")
const Gear := preload("res://scripts/gear.gd")
const Registry := preload("res://scripts/data_registry.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const ORDER := ["walk", "jump", "roll", "strike", "finisher", "swap", "shoot", "offhand", "power", "parry", "block", "belt"]

var t


func run(smoke) -> void:
	t = smoke
	print("tutorial: basic training as one session")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	_steps()
	await _whole(main)
	await _leave_and_resume(main)
	await _skip(main)
	_prompts(main)
	_words(main)
	main.menu.station_page.station = ""
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


func _buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


func _phys(n := 2) -> void:
	for i in n:
		await t.physics_frame


func _wait_done(main, seconds := 8.0) -> void:
	await t._until(func(): return not main.arena.on, seconds)
	await t._frames(3)


## Back at the gym's card for basic training.
func _to_gym(main) -> void:
	main.menu.go_station(Travel.home(main.profile), "gym")
	await t._frames(3)


# --- the steps -----------------------------------------------------------------------------

func _steps() -> void:
	var ids: Array = Tutorial.step_ids()
	t._check(ids == ORDER, "basic training's steps, in order: %s" % [ids])
	t._check(Tutorial.count() % 6 == 0, "...a count by sixes (%d)" % Tutorial.count())
	var kinds: Array = Tutorial.STEPS.map(func(d): return String(d["kind"]))
	for k in ["posts", "jump", "roll", "strike", "finisher", "swap", "shoot", "wand", "power", "parry", "block", "belt"]:
		t._check(kinds.has(k), "a step watches for: %s" % k)
	for d in Tutorial.STEPS:
		var ok: bool = String(d.get("name", "")) != "" and String(d.get("goal", "")).contains("{") and String(d.get("say", "")).length() > 40 and String(d.get("hint", "")).contains("{")
		t._check(ok, "%s: a name, a goal and a hint in your keys, and the Entity's word" % d["id"])
	t._check(Tutorial.STEPS.filter(func(d): return String(d.get("lend", "")) != "").size() >= 2, "it lends an off-hand wand and a shield for their steps")


# --- one session, start to end ---------------------------------------------------------------

func _whole(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	prof.home = "kraken"
	prof.station = ""
	Renown.state(prof)["lessons"] = {}
	Renown.state(prof).erase("tutorial")
	Training.require(prof)
	main.await_tower()
	main.open_train()
	menu.go_station(Travel.home(prof))
	await t._frames(3)
	t._check(menu.page == "station" and menu.station_page.stop == "gym" and String(menu.station_page.picks.get("gym", "")) == "basics:basics", "a new climber's station opens on basic training")
	var tiles: Array = t._all_buttons(menu.box).filter(func(b): return b.has_meta("pick") and String(b.get_meta("pick")).begins_with("lesson:"))
	t._check(_buttons(menu, "pick", "basics:basics").size() == 1 and tiles.is_empty(), "the gym has one basic training tile, not separate lessons")
	var want_skip := Tutorial.can_skip(prof)
	t._check(want_skip == (Training.can_skip(prof) or Tutorial.experienced()) and not Training.can_skip(prof), "before the Grace only an experienced player may skip it")
	t._check(_buttons(menu, "station_do", "skip").size() == (1 if want_skip else 0), "...and the card shows Skip only then")
	var begin: Array = _buttons(menu, "station_do", "begin")
	t._check(begin.size() == 1 and not Help.missing(begin[0]), "the card has Begin, which explains itself")
	var renown0 := Renown.points(prof)
	var dens0 := _density(prof)
	if begin.size() == 1:
		begin[0].pressed.emit()
	await t._frames(3)
	var p = main.player
	t._check(arena.on and String(arena.ev.get("type", "")) == "basics" and arena.tut != null and arena.tut.i == 0 and not main.on_train and not menu.is_open(), "Begin: the session starts in the arena at its first step")
	p.iframes = 999.0
	p.mouse_aim = false
	var stayed := true
	for k in ORDER.size():
		var id: String = ORDER[k]
		var tut = arena.tut
		var here: bool = arena.on and tut != null and tut.i == k
		t._check(here, "step %d is %s" % [k + 1, id])
		if not here:
			return
		var chip: Array = main.hud.status_chips().filter(func(c): return String(c.get("id", "")) == "arena")
		t._check(not chip.is_empty() and String(chip[0]["text"]).contains("Step %d of %d" % [k + 1, ORDER.size()]) and not String(chip[0]["text"]).contains("{"), "%s: the line at the top says the step and what to do, in your keys (%s)" % [id, chip[0]["text"] if not chip.is_empty() else ""])
		await _do(main, id)
		await _phys(3)
		if k < ORDER.size() - 1:
			t._check(arena.on and arena.tut != null and arena.tut.i == k + 1, "%s: done, on to the next step at once" % id)
		stayed = stayed and arena.on and not main.on_train and not menu.is_open()
		if not arena.on:
			break
	t._check(stayed, "the whole session ran in one sitting: never back to the menu between steps")
	t._check(arena.done, "the last step done ends the session")
	await _wait_done(main)
	p.iframes = 0.0
	t._check(bool(Tutorial.state(prof)["done"]) and Tutorial.passed(prof) and Training.basic_done(prof), "basic training is done, and remembered")
	t._check(Stations.LESSON_ORDER.all(func(id): return Stations.lesson_state(prof, id) == 1), "...every part of the old basic training marked done")
	t._check(Renown.points(prof) == renown0 + Stations.LESSON_REWARD, "...its renown paid once (%d)" % (Renown.points(prof) - renown0))
	t._check(Stations.why_not(prof, "first", "first", "kraken") == "", "...and the first tournament opens")
	var want := Tutorial.STEP_ESSENCE * Tutorial.count() * float(Training.RATES["basics"]["rate"])
	t._check(absf((_density(prof) - dens0) - want) < 0.5 and prof.bonds.is_empty(), "the steps gave a quarter of the usual essence, into the body (%.1f of %.1f)" % [_density(prof) - dens0, want])
	t._check(menu.page == "station" and menu.station_page.stop == "gym" and not menu.station_page.lines.is_empty(), "back at Training, the result on its card")
	t._check(Offhand.piece(p).is_empty(), "nothing lent is kept")


func _density(prof) -> float:
	var n := 0.0
	for k in prof.density:
		n += float(prof.density[k])
	return n


## Does one step's action (the way the game's own buttons would leave it),
## after checking that the wrong thing doesn't count.
func _do(main, id: String) -> void:
	var arena = main.arena
	var tut = arena.tut
	var p = main.player
	p.sta = p.max_sta
	match id:
		"walk":
			t._check(arena.posts.size() == 3, "walk: three posts to touch")
			for at in arena.posts.duplicate():
				p.global_position = at
				await _phys()
		"jump":
			for i in 2:
				p.jump_vel = Vector2.ZERO
				p.jump_t = 0.3
				await _phys()
				p.jump_t = 0.0
				await _phys()
			t._check(tut.i == 1 and tut.n == 2, "jump: two standing jumps aren't enough; one must move")
			p.jump_vel = Vector2(120, 0)
			p.jump_t = 0.3
			await _phys()
			p.jump_t = 0.0
		"roll":
			t._check(tut.foes().size() == 1 and String(tut.foes()[0].kind) == "archer", "roll: an archer shoots, so the arrows can pass through you")
			for i in 2:
				p.roll_t = 0.3
				await _phys()
				p.roll_t = 0.0
				await _phys()
		"strike":
			t._check(tut.foes().is_empty() and arena.dummies.size() == 2, "strike: the archer gone, two dummies close by")
			p.weapon = "shortbow"
			arena.dummies[0].take_hit(1.0, Vector2.ZERO)
			await _phys()
			t._check(tut.n == 0, "strike: a bow's hit doesn't count")
			p.weapon = "sword"
			_face(p, arena.dummies[0])
			for i in 2:
				p.attack_cd = 0.0
				p._melee()
				await _phys()
		"finisher":
			_face(p, arena.dummies[0])
			p.combo = 0
			p.combo_t = 0.0
			for i in 2:
				p.attack_cd = 0.0
				p._melee()
				_face(p, arena.dummies[0])
				await _phys()
			t._check(tut.i == 4 and tut.n == 0, "finisher: plain blows aren't a finisher")
			p.attack_cd = 0.0
			p._melee()
			await _phys()
		"swap":
			t._check(arena.dummies.is_empty(), "swap: the dummies put away")
			p.weapon = Gear.base_id(p.gear["ranged"])
		"shoot":
			t._check(arena.dummies.size() == 2 and arena.dummies[0].position.y < main.OPEN_ROOM.position.y + 120.0, "shoot: two far dummies")
			p.last_draw_full = false
			arena.dummies[0].take_hit(1.0, Vector2.ZERO)
			await _phys()
			t._check(tut.n == 0, "shoot: a weak shot doesn't count")
			p.global_position = arena.dummies[0].position + Vector2(0, 120)
			p.aim = Vector2.UP
			p.drawing = true
			p.draw_t = 5.0
			p.release_draw()
			await t._until(func(): return tut.i != 6, 3.0)
		"offhand":
			t._check(Offhand.use_of(Offhand.piece(p)) == "wand", "offhand: a wand is lent")
			Offhand.cast(p)
			await _phys()
			t._check(tut.i == 7, "offhand: with the bow in hand the off-hand is put away")
			p.weapon = "sword"
			p.off_cd = 0.0
			Offhand.cast(p)
			await _phys()
		"power":
			t._check(ItemPool.carried(main) >= float(Tutorial.STEPS[8]["carry"]) - 0.01, "power: a little essence is carried to power with")
			p.off_cd = 0.0
			t._check(ItemPool.prime(p) == "offhand", "power: holding the off-hand button primes the wand")
			Offhand.cast(p)
			await _phys()
		"parry":
			var foes: Array = tut.foes()
			t._check(foes.size() == 1 and String(foes[0].kind) == "knight" and float(foes[0].dmg) > 0.0, "parry: a soft knight whose blows glint first")
			for i in 2:
				p.on_parry.emit(null, false)
			await _phys()
		"block":
			t._check(Offhand.use_of(Offhand.piece(p)) == "shield", "block: the wand swapped for a shield")
			var foes: Array = tut.foes()
			if foes.is_empty():
				return
			var k = foes[0]
			p.aim = (k.global_position - p.global_position).normalized()
			p.parry_t = 0.0
			p.attack_cd = 0.0
			p.roll_t = 0.0
			p.jump_t = 0.0
			p.cast_t = 0.0
			p.guard_force = true
			var left: float = Offhand.block(p, 10.0, k)
			p.guard_force = false
			t._check(left >= 0.0 and left < 10.0, "block: held parry with a shield cuts the blow (%.1f of 10)" % left)
			await _phys()
		"belt":
			t._check(p.hp < p.max_health() and p.item_count("draught") >= 1 and p.item_count("stamina") >= 1, "belt: hurt a little, with vials on the belt")
			p.item_sel = "stamina"
			p.use_item()
			await _phys()
			t._check(tut.i == 11, "belt: an item used without the wheel isn't enough")
			p.ring_open = true
			await _phys()
			p.ring_open = false
			p.item_sel = "draught"
			p.use_item()
			await _phys()


func _face(p, d) -> void:
	p.global_position = d.position + Vector2(0, 30)
	p.aim = Vector2.UP


# --- leaving part way, resuming, starting over ---------------------------------------------------

func _leave_and_resume(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	Renown.state(prof).erase("tutorial")
	await _to_gym(main)
	var begin: Array = _buttons(menu, "station_do", "begin")
	t._check(begin.size() == 1 and begin[0].text == Tutorial.TEXT["again"], "done, the card offers to go through it again")
	Tutorial.state(prof)["done"] = false
	if begin.size() == 1:
		begin[0].pressed.emit()
	await t._frames(3)
	var p = main.player
	for at in arena.posts.duplicate():
		p.global_position = at
		await _phys()
	await _phys(2)
	t._check(arena.on and arena.tut.i == 1, "the first step done, on to the second")
	menu.open("pause")
	await t._frames(2)
	var leave: Array = t._all_buttons(menu.box).filter(func(bb): return bb.has_meta("give_up"))
	t._check(leave.size() == 1 and leave[0].text == Tutorial.TEXT["leave"], "the pause menu can leave, keeping the place")
	if leave.size() == 1:
		leave[0].pressed.emit()
	await t._frames(3)
	t._check(not arena.on and menu.page == "station" and Tutorial.resume_step(prof) == 1, "left part way: back at the gym, the place kept (step %d)" % (Tutorial.resume_step(prof) + 1))
	t._check(Tutorial.tile_line(prof).contains("2"), "the tile says which step is next (%s)" % Tutorial.tile_line(prof))
	var resume: Array = _buttons(menu, "station_do", "begin")
	var restart: Array = _buttons(menu, "station_do", "restart")
	t._check(resume.size() == 1 and resume[0].text == String(Tutorial.TEXT["resume"]) % 2 and restart.size() == 1, "the card offers Resume from step 2 and Start over")
	t._check(restart.size() == 1 and not Help.missing(restart[0]), "...Start over explains itself")
	if resume.size() == 1:
		resume[0].pressed.emit()
	await t._frames(3)
	t._check(arena.on and arena.tut != null and arena.tut.i == 1, "Resume: back in at the step it stopped before")
	arena.give_up()
	await t._frames(3)
	restart = _buttons(menu, "station_do", "restart")
	if restart.size() == 1:
		restart[0].pressed.emit()
	await t._frames(3)
	t._check(arena.on and arena.tut != null and arena.tut.i == 0, "Start over: from the first step")
	arena.give_up()
	await t._frames(3)
	Tutorial.state(prof)["done"] = true
	Tutorial.state(prof)["step"] = 0


# --- skipping ------------------------------------------------------------------------------------

func _skip(main) -> void:
	var prof = main.profile
	var menu = main.menu
	# A first-timer before the Grace: refused (unless they've made a climber before).
	Renown.state(prof).erase("tutorial")
	Renown.state(prof)["lessons"] = {}
	if not Tutorial.experienced():
		var said: Array = Tutorial.skip(prof)
		t._check(not Tutorial.passed(prof) and said == [Training.TEXT["no_skip"]], "a first-timer can't skip it before the Grace")
	# After the Grace (or a climber not held to it): Skip on the card.
	Training.state(prof)["grace"] = true
	await _to_gym(main)
	var skip: Array = _buttons(menu, "station_do", "skip")
	t._check(skip.size() == 1 and not Help.missing(skip[0]), "after the Grace the card has Skip, which explains itself")
	var pts := Renown.points(prof)
	if skip.size() == 1:
		skip[0].pressed.emit()
	await t._frames(2)
	t._check(menu.asking() and menu.pop.text_l.text.contains("Trainee") and not Tutorial.passed(prof), "Skip asks first, warning that it forfeits the Trainee title")
	await t._confirm(true)
	await t._frames(2)
	t._check(Tutorial.passed(prof) and bool(Tutorial.state(prof)["skipped"]) and Stations.lessons_done(prof), "skipped: behind the climber, the old parts marked")
	t._check(not Tutorial.earned_title(prof) and not Renown.grantable(prof, "trainee"), "...but no Trainee title: it's earned by finishing, not skipping")
	t._check(Renown.points(prof) == pts + Stations.LESSON_REWARD, "...the set's renown paid (once: it was cleared for this check)")
	t._check(_buttons(menu, "station_do", "begin").size() == 1, "...and it can still be gone through")


# --- prompts: keys, a controller, touch ----------------------------------------------------------

func _prompts(_main) -> void:
	for d in Tutorial.STEPS:
		var keys := Entity.fill_keys(String(d["say"]) + " " + String(d["goal"]) + " " + String(d["hint"]), "keys")
		var pad := Entity.fill_keys(String(d["say"]) + " " + String(d["goal"]) + " " + String(d["hint"]), "pad")
		var touch := Entity.fill_keys(String(d["say"]) + " " + String(d["goal"]) + " " + String(d["hint"]), "touch")
		t._check(not keys.contains("{") and not pad.contains("{") and not touch.contains("{"), "%s: every key named for keys, a controller and touch" % d["id"])
		t._check(keys != touch, "%s: touch players get their own buttons" % d["id"])
	var touch_words := {"roll": "Roll", "jump": "Jump", "parry": "Parry", "swap": "Swap", "offhand": "Off-hand", "belt": "Item"}
	for id in touch_words:
		var d: Dictionary = Tutorial.STEPS[ORDER.find(id)]
		t._check(Entity.fill_keys(String(d["say"]), "touch").contains(touch_words[id]), "%s: the touch prompt names the %s button" % [id, touch_words[id]])
	var pad_line := Entity.fill_keys(String(Tutorial.STEPS[ORDER.find("roll")]["say"]), "pad")
	t._check(pad_line.contains("B"), "a controller's prompt names its button (%s)" % pad_line.left(40))


# --- the Entity, help, the Data editor, words -----------------------------------------------------

func _words(main) -> void:
	t._check(String(Entity.TIPS["basic_training"]["tip"]).contains("One session") and String(Entity.TIPS["basic_training"]["tip"]).length() <= 170, "the Entity's first word on basic training says it's one session")
	var said := Talk.line_for(main, "how_training")
	t._check(said.contains(str(Tutorial.count())) and said.contains("parry") and not said.contains("{"), "'How does it work?' explains the one session")
	for k in ["pick:basics", "station_do:begin", "station_do:restart", "station_do:skip"]:
		t._check(Help.HELP.has(k), "button help: %s" % k)
	var tables: Array = []
	for s in Registry.SECTIONS:
		tables.append_array(s.get("tables", []))
	t._check(tables.has("tutorial/STEPS") and tables.has("tutorial/TEXT"), "its steps and words are in the Data editor")
	var all := JSON.stringify([Tutorial.STEPS, Tutorial.TEXT, Entity.TIPS["basic_training"], Entity.TIPS["training"]]).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	t._check(re.search(all) == null, "no banned words in basic training")
	var readme := FileAccess.get_file_as_string("res://README.md")
	t._check(readme.contains("Basic training: one session"), "the README explains the one session")
