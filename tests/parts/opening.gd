extends RefCounted
## The opening (opening.gd draws it; start_pages.gd builds its words and
## buttons; new_start.gd opening_due decides when it plays by itself): the
## first launch on a device plays it, then the title, then New Climber goes
## to the name; later launches go straight to the title, and the title's
## "The opening" plays it again; each of the six screens draws its scene
## and shows its words; Skip, Back and Esc; Next by Enter, A, a tap and a
## click on the picture; one toll of the story track for each screen; it
## fits a phone and a big screen; the Entity explains it; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const NewStart := preload("res://scripts/new_start.gd")
const StartPages := preload("res://scripts/start_pages.gd")
const Slots := preload("res://scripts/slots.gd")
const Help := preload("res://scripts/entity_help.gd")
const Entity := preload("res://scripts/entity.gd")
const Music := preload("res://scripts/music.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Particles := preload("res://scripts/particles.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var main
var menu


func run(smoke) -> void:
	t = smoke
	print("opening: the illustrated opening, then the title, then a new climber")
	await t._fresh_main()
	main = t.main
	menu = main.menu
	main.touch._set_active(false)
	main.pad._set_active(false)
	await _launch()
	await _screens()
	await _advance()
	await _music()
	await _fits()
	_words()
	StartPages.reset()
	menu.close()
	main.touch._set_active(false)
	main.pad._set_active(false)
	await t._frames(2)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _buttons() -> Array:
	return menu.box.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.is_queued_for_deletion())


func _button_with(meta: String) -> Button:
	for b in _buttons():
		if b.has_meta(meta):
			return b
	return null


func _set_start(made: int, seen: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Slots.settings_path())
	cfg.set_value("start", "made", made)
	if seen:
		cfg.set_value("start", "opening_seen", true)
	elif cfg.has_section_key("start", "opening_seen"):
		cfg.erase_section_key("start", "opening_seen")
	cfg.save(Slots.settings_path())


# --- the flow: first launch, later launches, the title's button -------------------------

func _launch() -> void:
	print("opening: when it plays")
	var made_was := NewStart.made()
	var slots := Slots.any()
	_set_start(0, false)
	_check(NewStart.opening_due() == (not slots), "a device's first launch (no climber made, none kept, never seen) is due the opening")
	if slots:
		print("  (a climber is kept in this run's slots: the first launch is checked by hand)")
	# The first launch: the opening, before the title.
	main.profile.created = false
	if not slots:
		StartPages.launch(menu)
	else:
		StartPages.play_opening(menu)
	await t._frames(3)
	_check(menu.page == "intro" and StartPages.line == 0 and menu.opening.visible and not menu.backdrop.visible and not menu.shade.visible,
		"the first launch opens on the opening: its own scene, not the title's")
	var seen := 0
	for i in 8:
		if menu.page != "intro":
			break
		seen += 1
		var nx := _button_with("intro_next")
		if nx == null:
			break
		nx.pressed.emit()
		await t._frames(1)
	_check(seen == 6 and menu.page == "title" and not menu.opening.visible, "...six screens, then the title (%d screens)" % seen)
	_check(not NewStart.opening_due(), "...and once seen it doesn't play by itself again")
	# New Climber: straight to the name, not the opening again.
	var nc: Button = null
	for b in _buttons():
		if b.text == NewStart.TEXT["new_climber"]:
			nc = b
	_check(nc != null, "the title offers New Climber")
	if nc != null:
		nc.pressed.emit()
		await t._frames(2)
	_check(menu.page == "create_name", "New Climber leads into making the climber, without the opening (%s)" % menu.page)
	menu.go_back()
	await t._frames(2)
	_check(menu.page == "title", "...and Back from the name returns to the title")
	# Later launches: the title, whether seen, or a returning player's.
	StartPages.launch(menu)
	await t._frames(2)
	_check(menu.page == "title", "a later launch goes straight to the title")
	_set_start(1, false)
	_check(not NewStart.opening_due(), "a returning player who made a climber here is never sent through it")
	StartPages.launch(menu)
	await t._frames(2)
	_check(menu.page == "title", "...the title for them too")
	# The title's button plays it again; Skip goes back to the title.
	var op := _button_with("opening")
	_check(op != null and op.text == NewStart.TEXT["opening"] and not Help.missing(op), "the title has \"%s\", explained by the Entity" % NewStart.TEXT["opening"])
	if op != null:
		op.pressed.emit()
		await t._frames(2)
	_check(menu.page == "intro" and StartPages.line == 0, "...which plays the opening from its first screen")
	var sk := _button_with("intro_skip")
	_check(sk != null and not Help.missing(sk), "the opening has Skip (explained)")
	if sk != null:
		sk.pressed.emit()
		await t._frames(2)
	_check(menu.page == "title", "Skip goes to the title")
	# Start over (a new climber in this slot) skips it too.
	main.new_climber()
	await t._frames(2)
	_check(menu.page == "create_name", "starting a climber over skips the opening")
	menu.open("title")
	await t._frames(1)
	_set_start(made_was, true)


# --- the six screens --------------------------------------------------------------------

func _screens() -> void:
	print("opening: the six screens")
	var view = menu.opening
	var keep: String = Particles.level
	for level in ["medium", "low"]:
		Particles.level = level
		var ok := true
		var said := true
		var layered := true
		for i in 6:
			StartPages.line = i
			menu.open("intro")
			await t._frames(2)
			for at in [0.2, 2.5, 6.0, 12.0]:
				view.t = at
				var before: int = view.draws
				view.queue_redraw()
				await t._frames(2)
				ok = ok and view.draws > before and view.line == i
			# Painted in layers, which the slow camera moves at different
			# speeds (the near ones more than the sky).
			var near: Transform2D = view._cam(1.0)
			var far: Transform2D = view._cam(0.1)
			layered = layered and view.layers >= 3 and not near.is_equal_approx(far)
			var bubble: Control = null
			for c in menu.box.find_children("*", "Control", true, false):
				if c.has_meta("intro_line"):
					bubble = c
			said = said and bubble != null and int(bubble.get_meta("intro_line")) == i and String(bubble.get_meta("entity_line", "")) == Pronouns.fill(String(NewStart.INTRO[i][1]))
		_check(ok, "each of the six screens draws its scene, from the dark to its end (Effects %s)" % level)
		_check(said, "...each with its own words, the Entity's (Effects %s)" % level)
		_check(layered, "...each painted in layers that a slow camera moves at different speeds (Effects %s)" % level)
	Particles.level = keep
	# Each screen starts from the dark; a tap right after a change waits.
	StartPages.line = 2
	menu.open("intro")
	await t._frames(1)
	_check(view.t < 0.3 and not view.can_tap(), "a new screen starts over, and a tap straight away doesn't skip it")
	menu.open("title")
	await t._frames(1)


# --- moving on: Enter, A, a tap, a click; Back and Esc ----------------------------------

func _advance() -> void:
	print("opening: Enter, A, a tap and a click go on")
	var view = menu.opening
	StartPages.line = 0
	menu.open("intro")
	await t._frames(3)
	var f: Control = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.has_meta("intro_next"), "keyboard: Next has the focus")
	await t._key_tap(KEY_ENTER)
	await t._frames(2)
	_check(menu.page == "intro" and StartPages.line == 1, "Enter goes on (screen %d)" % (StartPages.line + 1))
	f = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.has_meta("intro_next"), "...and the next screen starts on Next again")
	main.pad._set_active(true)
	await t._frames(2)
	await t._pad_tap(JOY_BUTTON_A)
	await t._frames(2)
	_check(StartPages.line == 2, "the controller's A goes on (screen %d)" % (StartPages.line + 1))
	main.pad._set_active(false)
	# A tap on the picture (a phone).
	main.touch._set_active(true)
	await t._frames(2)
	view.t = 2.0
	var vs: Vector2 = menu.get_viewport_rect().size
	await t._tap_at(Vector2(vs.x * 0.5, vs.y * 0.18))
	_check(StartPages.line == 3, "a tap on the picture goes on (screen %d)" % (StartPages.line + 1))
	await t._tap_at(Vector2(vs.x * 0.5, vs.y * 0.18))
	_check(StartPages.line == 3, "...but not a second tap straight after (screen %d)" % (StartPages.line + 1))
	main.touch._set_active(false)
	await t._frames(2)
	# A click on the picture.
	view.t = 2.0
	vs = menu.get_viewport_rect().size
	var at: Vector2 = t._to_window(Vector2(vs.x * 0.5, vs.y * 0.18))
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = down
		Input.parse_input_event(ev)
		await t._frames(2)
	_check(StartPages.line == 4, "a click on the picture goes on (screen %d)" % (StartPages.line + 1))
	# Back a screen, then Esc back to the title from the first.
	var bk: Button = null
	for b in _buttons():
		if b.text == NewStart.TEXT["back"]:
			bk = b
	_check(bk != null and not Help.missing(bk), "Back is offered after the first screen")
	if bk != null:
		bk.pressed.emit()
		await t._frames(2)
	_check(StartPages.line == 3, "Back goes back a screen")
	StartPages.line = 0
	menu.open("intro")
	await t._frames(2)
	_check(_buttons().all(func(b): return b.text != NewStart.TEXT["back"]), "the first screen has no Back button")
	await t._key_tap(KEY_ESCAPE)
	await t._frames(2)
	_check(menu.page == "title", "Esc on the first screen goes to the title")
	# The last screen's button goes to the title.
	StartPages.line = 5
	menu.open("intro")
	await t._frames(2)
	var last := _button_with("intro_next")
	_check(last != null and last.text == NewStart.TEXT["intro_go"] and _button_with("intro_skip") == null, "the last screen ends in %s, without Skip" % NewStart.TEXT["intro_go"])
	if last != null:
		last.pressed.emit()
		await t._frames(2)
	_check(menu.page == "title", "...which goes to the title")


# --- the music: the story track, a toll for each screen ---------------------------------

func _music() -> void:
	print("opening: the story music, a toll a screen")
	var A = main.audio
	A.director_on = false
	A.director = Music.new()
	StartPages.line = 0
	menu.open("intro")
	await t._frames(1)
	A.set_mood(A.director.update(main, 0.5), 0.0)
	await t._frames(2)
	var p: AudioStreamPlayer = A.tracks["story"]["player"] if A.tracks.has("story") else null
	_check(A.mood == "story" and A.track_playing() == "story", "the opening plays the story track (%s)" % A.track_playing())
	_check(p != null and A.toll_at == 0 and p.get_playback_position() < A.TOLL_EVERY, "...the first screen on the first toll")
	if p != null:
		p.seek(A.TOLL_EVERY - 0.03)
		await t._frames(2)
		_check(p.stream_paused, "...and it waits there once the toll has rung, before the next")
		StartPages._intro_next(menu)
		await t._frames(2)
		var at := p.get_playback_position()
		_check(A.toll_at == 1 and not p.stream_paused and at >= A.TOLL_EVERY - 0.05 and at < A.TOLL_EVERY * 2.0, "the next screen rings the second toll (%.1f s)" % at)
		StartPages.line = 5
		menu.open("intro")
		await t._frames(2)
		p.seek(A.TOLL_EVERY * 6.0 - 0.03)
		await t._frames(2)
		_check(A.toll_at == 5 and not p.stream_paused, "the sixth screen's toll carries on into the music")
	menu.open("title")
	await t._frames(1)
	A.set_mood(A.director.update(main, 0.5), 0.0)
	_check(A.mood == "menu", "back on the title, the title's music")
	A.director_on = true


# --- sizes ------------------------------------------------------------------------------

func _fits() -> void:
	print("opening: a phone and a big screen")
	var was: Vector2i = t.root.size
	var problems: Array = []
	var stage_ok := true
	for sz in [Vector2i(800, 400), Vector2i(844, 390), Vector2i(1920, 1080)]:
		t.root.size = sz
		main.touch._set_active(sz.y < 500)
		await t._frames(2)
		for i in 6:
			StartPages.line = i
			menu.open("intro")
			await t._frames(3)
			problems.append_array(t._fit_problems("intro %d %dx%d" % [i + 1, sz.x, sz.y], menu.panel, t.root.get_visible_rect()))
			var vs: Vector2 = menu.get_viewport_rect().size
			stage_ok = stage_ok and menu.opening.stage_height() >= vs.y * 0.4
		menu.open("title")
		await t._frames(3)
		problems.append_array(t._fit_problems("title %dx%d" % [sz.x, sz.y], menu.panel, t.root.get_visible_rect()))
	_check(problems.is_empty(), "the opening and the title fit a phone and a big screen (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	_check(stage_ok, "...with room for the picture above the words")
	main.touch._set_active(false)
	t.root.size = was
	await t._frames(2)


func _words() -> void:
	_check(Entity.TIPS.has("intro") and String(Entity.TIPS["intro"]["tip"]).length() > 40, "the Entity explains the opening the first time (its tip)")
	var Reg = load("res://scripts/data_registry.gd")
	_check(String(Reg.field("opening/OPENING/fps").get("kind", "")) == "number" and String(Reg.field("new_start/TEXT/opening").get("kind", "")) == "text", "the opening's numbers and words are in the Data editor")
	var text := (JSON.stringify(NewStart.INTRO) + JSON.stringify(NewStart.TEXT) + JSON.stringify(Entity.TIPS["intro"])
		+ String(Help.HELP.get("start:opening", "")) + String(Help.HELP.get("start:intro_skip", "")) + String(Help.HELP.get("start:intro_go", ""))).to_lower()
	var found: Array = BANNED.filter(func(w): return text.contains(w))
	_check(found.is_empty(), "no banned words in the opening (%s)" % [found])
