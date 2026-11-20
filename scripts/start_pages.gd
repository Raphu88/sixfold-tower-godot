extends RefCounted
## A new climber's start, as menu pages (menu.gd's "intro", "create_name" and
## "quiz"; the look between them is appearance_page.gd's "create"), built
## with menu.gd's own helpers so mouse, keys, controller and touch all work.
##
##   New Climber (the title) -> intro -> create_name -> create -> quiz -> Begin
##
##   intro        a black screen: the Entity speaks new_start.gd INTRO, a line
##                at a time (Next, Back; Skip once a climber has been made
##                on this device)
##   create_name  the name (the Dice offers one) and pronouns (pronouns.gd),
##                with a line showing how others will speak of you
##   quiz         new_start.gd QUESTIONS, one at a time, then a summary of
##                what you'll begin with, Change answers and Begin
## Begin gives the answers' results (new_start.gd apply), makes the climber
## and takes them to their home station, where basic training and the first
## tournament earn the Noble's Grace before any climb (training.gd). Back (Esc, B, the Back
## buttons) goes a step back all the way to the title.
##
## Every word is in new_start.gd TEXT and INTRO (and the Entity's tips in
## entity.gd: "slots", "intro", "create_name", "questionnaire"); each button's
## explanation is entity_help.gd's "start:..." entries.

const NewStart := preload("res://scripts/new_start.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Entity := preload("res://scripts/entity.gd")
const UI := preload("res://scripts/ui.gd")
const Slots := preload("res://scripts/slots.gd")

static var T := NewStart.TEXT

## Where the start is: the intro's line, the question (QUESTIONS.size() is
## the summary) and the answers so far ({question id: answer id}).
static var line := 0
static var q := 0
static var picks := {}
static var name_edit: LineEdit = null
static var _after_name: Button = null


static func reset() -> void:
	line = 0
	q = 0
	picks = {}


## New Climber on the title: a new climber in this slot if it's empty, else
## in the first empty slot (with all six full, the Climbers page says so).
static func new_climber(m) -> void:
	var main = m.main
	if not main.profile.created:
		begin_start(m)
		return
	var slot := Slots.first_empty()
	if slot == 0:
		m.toast = T["full"]
		m.toast_t = 4.0
		m.open("climbers")
		return
	main.sfx("ui_confirm")
	main.switch_climber(slot)  # (the game starts again in that slot, on the introduction)


## The start of a new climber: the introduction.
static func begin_start(m) -> void:
	reset()
	m.open("intro")


## Back a step (Esc, B, a Back button).
static func back(m) -> void:
	match String(m.page):
		"intro":
			if line > 0:
				line -= 1
				m.open("intro")
			else:
				m.open("title")
		"create_name":
			line = NewStart.INTRO.size() - 1
			m.open("intro")
		"quiz":
			if q > 0:
				q -= 1
				m.open("quiz")
			else:
				m.open("create")


# --- the introduction ------------------------------------------------------------

static func build_intro(m) -> void:
	var main = m.main
	var small: bool = m.compact()
	var lines: Array = NewStart.INTRO
	line = clampi(line, 0, lines.size() - 1)
	m.backdrop.visible = false  # (a black screen: menu.gd open blacks out the shade)
	# The first time, the Entity's tip on the introduction itself (kept in the Archive).
	var told: String = main.tip_now("intro") if line == 0 else ""
	if told != "":
		var tip: Label = m._label(Entity.fill_keys(told, _mode(main), main.pad_ps), 0.0, UI.FAINT)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.custom_minimum_size.x = 300.0 if small else 520.0
		tip.add_theme_font_size_override("font_size", 14)
		m.box.add_child(tip)
	m._gap(6 if small else 30)
	var said: Control = Entity.says(String(lines[line][1]), 48.0 if small else 70.0, String(Entity.TEXT["tag"]), false)
	said.custom_minimum_size.x = 340.0 if small else 600.0
	said.set_meta("intro_line", line)
	m.box.add_child(said)
	m._gap(4 if small else 14)
	# Where you are: a dot for each line.
	var dots: Label = m._label(" ".join(range(lines.size()).map(func(i): return "●" if i == line else "○")), 0.0, UI.DIM)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.box.add_child(dots)
	m._gap(4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	m.box.add_child(row)
	if line > 0:
		var bk: Button = m._button(T["back"], back.bind(m), row)
		bk.set_meta("help", "start:intro_back")
		bk.custom_minimum_size.x = 120.0
	if NewStart.can_skip_intro() and line < lines.size() - 1:
		var sk: Button = m._button(T["intro_skip"], _end_intro.bind(m), row)
		sk.set_meta("help", "start:intro_skip")
		sk.custom_minimum_size.x = 120.0
	var last := line >= lines.size() - 1
	var nx: Button = m._button(T["intro_go"] if last else T["intro_next"], _intro_next.bind(m), row)
	nx.set_meta("help", "start:intro_go" if last else "start:intro_next")
	nx.set_meta("intro_next", true)
	nx.custom_minimum_size.x = 200.0 if last else 140.0
	m._primary(nx)


static func _intro_next(m) -> void:
	if line >= NewStart.INTRO.size() - 1:
		_end_intro(m)
		return
	line += 1
	m.open("intro")


static func _end_intro(m) -> void:
	line = 0
	m.open("create_name")


# --- the name and pronouns ---------------------------------------------------------

static func build_name(m) -> void:
	var main = m.main
	var small: bool = m.compact()
	var app: Dictionary = Appearance.normalized(main.profile.appearance)
	m._header(T["name_title"], T["name_sub"])
	var told: String = main.tip_now("create_name")
	if told != "":
		m.box.add_child(Entity.says(Entity.fill_keys(told, _mode(main), main.pad_ps), 30.0 if small else 40.0))
	# The name, and the Dice.
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	m.box.add_child(nr)
	var nl: Label = m._label(T["name"], 100.0 if small else 120.0, UI.DIM)
	nr.add_child(UI.style_label(nl, "display", 18, UI.DIM))
	name_edit = LineEdit.new()
	name_edit.text = String(app["name"])
	name_edit.placeholder_text = T["name_hint"]
	name_edit.max_length = Appearance.NAME_MAX
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_stylebox_override("normal", UI.box(Color(UI.VOID, 0.95), UI.LINE_HI, 6, 1, 8.0))
	var focus := UI.box(Color(0.08, 0.07, 0.11), UI.GILT_HI, 6, 2, 8.0)
	name_edit.add_theme_stylebox_override("focus", focus)
	name_edit.add_theme_color_override("font_color", UI.TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", UI.FAINT)
	name_edit.set_meta("help", "start:name")
	name_edit.text_changed.connect(func(t): _set_look(m, "name", Appearance.clean_name(t)))
	name_edit.text_submitted.connect(func(_t): focus_after_name(m))
	nr.add_child(name_edit)
	var dice: Button = m._button(T["dice"], func():
		var n := Appearance.random_name(String(name_edit.text))
		name_edit.text = n
		_set_look(m, "name", n)
		main.sfx("ui_move"), nr)
	dice.custom_minimum_size = Vector2(72, 40)
	dice.set_meta("help", "start:dice")
	_after_name = dice
	# The pronouns.
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	m.box.add_child(pr)
	pr.add_child(UI.style_label(m._label(T["pronouns"], 100.0 if small else 120.0, UI.DIM), "display", 18, UI.DIM))
	var mine := Pronouns.of_look(app)
	for c in Pronouns.CHOICES:
		var id := String(c[0])
		var b: Button = m._button(String(c[1]), func():
			_set_look(m, "pronouns", id)
			main.sfx("ui_move")
			m.open("create_name"), pr)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("help", "start:pronoun")
		b.set_meta("help_desc", Pronouns.fill_for(String(T["pronoun_help"]), id))
		b.set_meta("pronoun", id)
		if id == mine:
			m._primary(b)
	# How it reads.
	m._gap(2)
	var ex: Label = m._label(Pronouns.fill_for(String(T["pronoun_example"]), mine), 0.0, UI.DIM)
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.custom_minimum_size.x = 300.0
	ex.add_theme_font_size_override("font_size", 14 if small else 16)
	m.box.add_child(ex)
	m._gap(4 if small else 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	m.box.add_child(row)
	var bk: Button = m._button(T["back"], back.bind(m), row)
	bk.set_meta("help", "start:name_back")
	bk.custom_minimum_size.x = 140.0
	var nx: Button = m._button(T["next"], func():
		main.sfx("ui_confirm")
		m.open("create"), row)
	nx.set_meta("help", "start:name_next")
	nx.set_meta("name_next", true)
	nx.custom_minimum_size.x = 180.0
	m._primary(nx)


## One choice of the look changed (the name, the pronouns): kept at once.
static func _set_look(m, key: String, value: String) -> void:
	var app: Dictionary = Appearance.normalized(m.main.profile.appearance)
	app[key] = value
	m.main.set_appearance(app)


## A tap on the name on a phone: in a browser, the browser's own text box;
## elsewhere the field takes the keys.
static func edit_name(m) -> void:
	if name_edit == null or not is_instance_valid(name_edit):
		return
	if OS.has_feature("web") and m.main.touch_active:
		var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(T["name"]), JSON.stringify(name_edit.text)], true)
		if v != null:
			name_edit.text = Appearance.clean_name(str(v))
			_set_look(m, "name", name_edit.text)
		return
	name_edit.grab_focus()


## Out of the name (Enter, Esc): on to the Dice.
static func focus_after_name(m) -> void:
	if _after_name != null and is_instance_valid(_after_name):
		_after_name.grab_focus()


# --- the questionnaire -----------------------------------------------------------------

static func build_quiz(m) -> void:
	var main = m.main
	var small: bool = m.compact()
	var qs: Array = NewStart.QUESTIONS
	q = clampi(q, 0, qs.size())
	if q < qs.size():
		m._header(T["quiz_title"], T["quiz_sub"], T["question"] % [q + 1, qs.size()])
	else:
		m._header(T["quiz_title"], T["quiz_sub"])
	var told: String = main.tip_now("questionnaire") if q == 0 else ""
	if told != "":
		m.box.add_child(Entity.says(Entity.fill_keys(told, _mode(main), main.pad_ps), 30.0 if small else 38.0))
	if q < qs.size():
		var qd: Dictionary = qs[q]
		var qid := String(qd["id"])
		m.box.add_child(Entity.says(String(qd["ask"]), 34.0 if small else 46.0, String(Entity.TEXT["tag"]), false))
		var answers: Array = NewStart.answers(qd)
		var cols := 2 if answers.size() <= 4 or small else 3
		var grid: GridContainer = m._grid(cols, 8, 6 if small else 8)
		for a in answers:
			var aid := String(a["id"])
			var b: Button = m._button(String(a["name"]), _answer.bind(m, qid, aid), grid)
			b.custom_minimum_size.y = 40.0 if small else 46.0
			b.set_meta("help", "start:answer")
			b.set_meta("help_desc", String(a["help"]))
			b.set_meta("answer", aid)
			if String(picks.get(qid, "")) == aid:
				m._primary(b)
		# What the answer under the pointer gives, on a computer (the
		# Entity's bubble says it too; a phone holds a button for it).
		m._gap(2)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		m.box.add_child(row)
		var bk: Button = m._button(T["back"], back.bind(m), row)
		bk.set_meta("help", "start:quiz_back")
		bk.custom_minimum_size.x = 160.0
		return
	# The summary: what you'll begin with.
	var said := "\n".join(NewStart.summary(picks))
	m.box.add_child(Entity.says(said, 34.0 if small else 46.0, String(T["summary"]).to_upper(), false))
	m._gap(4)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	m.box.add_child(row2)
	var ch: Button = m._button(T["change"], func():
		q = 0
		m.open("quiz"), row2)
	ch.set_meta("help", "start:change")
	ch.custom_minimum_size.x = 170.0
	var go: Button = m._button(T["begin"], begin.bind(m), row2)
	go.set_meta("help", "start:begin")
	go.set_meta("begin", true)
	go.custom_minimum_size.x = 240.0
	m._primary(go)


static func _answer(m, qid: String, aid: String) -> void:
	picks[qid] = aid
	q += 1
	m.main.sfx("ui_confirm")
	m.open("quiz")


## Begin: the answers' results, the climber made, and the first climb in the home tower.
static func begin(m) -> void:
	var main = m.main
	var prof = main.profile
	if not NewStart.complete(picks):
		q = 0
		m.open("quiz")
		return
	NewStart.apply(prof, picks)
	load("res://scripts/training.gd").require(prof)  # (the towers wait for the Noble's Grace: training.gd)
	prof.created = true
	prof.save()
	NewStart.note_made()
	if main.player != null:
		main.player.use_heirlooms(prof.heirlooms)
		NewStart.dress(prof, main.player)
	main.apply_appearance()
	main.sfx("ui_confirm")
	Engine.set_meta("sixfold_title_seen", true)
	reset()
	m.close()
	if main.choosing_tower and not main.on_train:
		# To the home station: basic training and the first tournament come
		# before any climb (training.gd).
		prof.station = ""
		prof.last_tower = prof.home
		main.tower = prof.home
		main.open_train()
		m.go_station(load("res://scripts/travel.gd").home(prof))


static func _mode(main) -> String:
	return "touch" if main.touch_active else ("pad" if main.pad_active else "keys")
