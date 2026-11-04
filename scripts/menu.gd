extends Control
## Menus: the title screen, the pause menu, settings, the controls list and
## the dev tool. Built from Godot's own buttons, so mouse, keyboard and touch
## all work. While a menu is open the game is paused.
##
## Esc or P (or the phone's Menu button) opens and closes the pause menu.

const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Towers := preload("res://scripts/towers.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

const GOLD := Color(0.95, 0.8, 0.5)
const TEXT := Color(0.86, 0.83, 0.9)
const DIM := Color(0.62, 0.59, 0.67)
const SETTINGS_PATH := "user://sixfold.cfg"

## Settings, kept between sessions (in the same file as the profile).
static var settings := {"music": 0.8, "sounds": 1.0, "shake": true, "help": false}
static var settings_loaded := false

var main
var page := ""  # "" when closed
var box: VBoxContainer  # the current page's contents
var panel: PanelContainer
var scroll: ScrollContainer
var toast := ""
var toast_t := 0.0
var confirm_back := ""  # the page "Cancel" returns to


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	hide()
	load_settings()
	apply_settings()


func is_open() -> bool:
	return page != ""


func _process(delta: float) -> void:
	toast_t -= delta
	if toast_t <= 0.0 and toast != "":
		toast = ""
		queue_redraw()
	if Input.is_action_just_pressed("pause"):
		if page == "":
			open("pause")
		elif page == "title":
			pass
		elif page == "pause":
			close()
		else:
			open("title" if _from_title() else "pause")
	# Keep the panel inside the screen (phones draw everything bigger).
	var s := get_viewport_rect().size
	scroll.custom_minimum_size = Vector2(minf(560.0, s.x - 40.0), minf(_wanted_height(), s.y - 40.0))


var opened_from_title := false


func _from_title() -> bool:
	return opened_from_title


func _wanted_height() -> float:
	return box.get_combined_minimum_size().y + 4.0


## Opens a page (pausing the game) or switches to another page.
func open(which: String) -> void:
	if which == "title":
		opened_from_title = true
	elif which == "pause":
		opened_from_title = false
	page = which
	show()
	get_tree().paused = true
	if main != null and main.touch != null:
		main.touch.release_all()
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	scroll.scroll_vertical = 0
	call("_page_" + which)
	# Keyboard players: start on the first button.
	for c in box.get_children():
		var b := _first_button(c)
		if b != null:
			b.grab_focus.call_deferred()
			break


func close() -> void:
	page = ""
	hide()
	get_tree().paused = false
	Engine.time_scale = 1.0


func _first_button(n: Node) -> Button:
	if n is Button:
		return n
	for c in n.get_children():
		var b := _first_button(c)
		if b != null:
			return b
	return null


# --- pages -------------------------------------------------------------------

func _page_title() -> void:
	_heading("SIXFOLD TOWER", 40)
	var prof = main.profile
	var sub := "A new climber. You bear no mark yet."
	if prof.regarded:
		var names: Array = []
		for part in Bonds.PARTS:
			if prof.bonds.has(part):
				names.append(Bonds.BONDS[prof.bonds[part]["id"]]["name"])
		sub = "Marks: %s  ·  best floor %d" % [", ".join(names) if not names.is_empty() else "none", prof.best_floor]
	_text(sub, DIM, true)
	_gap()
	_button("Begin your first climb" if not prof.regarded else "Climb", _leave_title)
	_button("Settings", open.bind("settings"))
	_button("Dev tools", open.bind("dev"))
	if prof.regarded:
		_button("New climber", _ask_new.bind("title"))


func _page_pause() -> void:
	_heading("PAUSED", 32)
	_text("%s  ·  floor %d" % [main.tower_data()["name"], main.floor_num], DIM, true)
	_gap()
	_button("Resume", close)
	_button("Restart this climb", _restart)
	_button("Settings", open.bind("settings"))
	_button("Controls", open.bind("controls"))
	_button("Dev tools", open.bind("dev"))
	_button("New climber", _ask_new.bind("pause"))
	_button("Quit to title", _quit_to_title)


func _page_settings() -> void:
	_heading("SETTINGS", 28)
	_slider("Music", "music")
	_slider("Sounds", "sounds")
	_toggle("Screen shake", "shake")
	_toggle("Keyboard controls panel", "help")
	_gap()
	_back()


func _page_controls() -> void:
	_heading("CONTROLS", 28)
	var rows := [
		["Move", "WASD or arrows"], ["Sprint", "Shift"], ["Roll", "Space"], ["Jump (over gaps)", "Z"],
		["Strike / draw the bow", "Left click or J"], ["Parry", "Right click or K"],
		["Weapon", "1 2 3 or the wheel"], ["Cast marks", "Q E F C X V  (hold to pick)"],
		["Menu", "Esc or P"], ["Restart", "R"], ["Music", "M"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	for r in rows:
		var a := Label.new()
		a.text = r[0]
		a.add_theme_color_override("font_color", TEXT)
		grid.add_child(a)
		var b := Label.new()
		b.text = r[1]
		b.add_theme_color_override("font_color", GOLD)
		grid.add_child(b)
	box.add_child(grid)
	_text("On a phone: the left side is a joystick, the buttons on the right attack, roll, parry, swap and cast. Hold a mark's button and slide to pick a spell.", DIM)
	_gap()
	_back()


func _ask_new(back: String) -> void:
	confirm_back = back
	open("confirm_new")


func _page_confirm_new() -> void:
	_heading("NEW CLIMBER?", 28)
	_text("Start over with no marks. All your marks and their growth will be lost.", TEXT, true)
	_gap()
	_button("Start over", _new_climber)
	_button("Cancel", open.bind(confirm_back))


func _page_dev() -> void:
	_heading("DEV TOOLS", 28)
	_text("For testing. Changes to marks are saved.", DIM, true)

	_section("Marks")
	var p = main.player
	for part in Bonds.PARTS:
		var row := _row()
		row.add_child(_label(Bonds.PART_NAMES[part], 70.0))
		var info: Dictionary = main.profile.bonds.get(part, {})
		var id: String = info.get("id", "")
		row.add_child(_small("<", _cycle_bond.bind(part, -1)))
		row.add_child(_label(Bonds.BONDS[id]["name"] if id != "" else "none", 150.0, GOLD if id != "" else DIM))
		row.add_child(_small(">", _cycle_bond.bind(part, 1)))
		if id != "":
			var step: int = p.bonds[part].step if p.bonds.has(part) else 1
			row.add_child(_small("-", _set_step.bind(part, step - 1)))
			row.add_child(_label("step %d" % step, 64.0))
			row.add_child(_small("+", _set_step.bind(part, step + 1)))
	var mrow := _row()
	_button("Fill essence", _fill, mrow)
	_button("Clear all marks", _clear_marks, mrow)

	_section("Climb")
	var trow := _row()
	for id in Towers.ORDER:
		var b := _button(Towers.TOWERS[id]["short"], _dev_tower.bind(id), trow)
		b.disabled = id == main.tower and not main.choosing_tower
	var frow := _row()
	frow.add_child(_label("Floor", 70.0))
	frow.add_child(_small("-", _dev_floor.bind(main.floor_num - 1)))
	frow.add_child(_label("%d" % main.floor_num, 40.0, GOLD))
	frow.add_child(_small("+", _dev_floor.bind(main.floor_num + 1)))
	var summit := int(main.tower_data().get("summit", 0))
	if summit > 0:
		_button("Go to %s" % main.beast_name(), _dev_floor.bind(summit), frow)

	_section("Spawn a monster")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for kind in EnemyScript.TYPES:
		_button(kind.capitalize(), _dev_spawn.bind(kind), grid)
	box.add_child(grid)

	_section("Cheats")
	var crow := _row()
	_button("No dying: %s" % ("on" if main.dev_no_death else "off"), _toggle_no_death, crow)
	_button("Heal", _heal, crow)
	_button("Clear the room", _clear_room, crow)
	if toast != "":
		_text(toast, GOLD, true)
	_gap()
	_back()


# --- actions -----------------------------------------------------------------

func _leave_title() -> void:
	Engine.set_meta("sixfold_title_seen", true)
	close()


func _restart() -> void:
	close()
	get_tree().reload_current_scene()


func _quit_to_title() -> void:
	close()
	if Engine.has_meta("sixfold_title_seen"):
		Engine.remove_meta("sixfold_title_seen")
	get_tree().reload_current_scene()


func _new_climber() -> void:
	close()
	main.new_climber()


func _back() -> void:
	_button("Back", open.bind("title" if _from_title() else "pause"))


func _cycle_bond(part: String, by: int) -> void:
	var ids: Array = [""]
	ids.append_array(Bonds.BONDS.keys())
	var cur: String = main.profile.bonds.get(part, {}).get("id", "")
	var i := (ids.find(cur) + by + ids.size()) % ids.size()
	main.dev_set_mark(part, ids[i], 1)
	open("dev")


func _set_step(part: String, step: int) -> void:
	var id: String = main.profile.bonds.get(part, {}).get("id", "")
	if id != "":
		main.dev_set_mark(part, id, clampi(step, 1, 5))
	open("dev")


func _fill() -> void:
	for b in main.player.bonds.values():
		b.essence = b.capacity()
		b.burned = false
	_say("Every mark is full")


func _clear_marks() -> void:
	for part in Bonds.PARTS:
		main.dev_set_mark(part, "", 1)
	_say("Marks cleared")


func _dev_tower(id: String) -> void:
	main.dev_tower(id)
	_say("Now in %s" % Towers.TOWERS[id]["name"])


func _dev_floor(n: int) -> void:
	main.dev_floor(maxi(n, 1))
	_say("Floor %d" % main.floor_num)


func _dev_spawn(kind: String) -> void:
	main.dev_spawn(kind)
	_say("Spawned: %s" % kind.capitalize())


func _toggle_no_death() -> void:
	main.dev_no_death = not main.dev_no_death
	open("dev")


func _heal() -> void:
	var p = main.player
	p.hp = p.max_hp
	p.sta = p.max_sta
	if p.dead:
		p.dead = false
		p.set_physics_process(true)
	_say("Healed")


func _clear_room() -> void:
	for e in main.enemies():
		e.submerged = false
		e.take_hit(99999.0, Vector2.ZERO, 0.0)
	_say("Room cleared")


func _say(text: String) -> void:
	toast = text
	toast_t = 2.0
	open(page)


# --- settings ----------------------------------------------------------------

static func load_settings() -> void:
	if settings_loaded:
		return
	settings_loaded = true
	if Engine.has_meta("sixfold_test"):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])


static func save_settings() -> void:
	if Engine.has_meta("sixfold_test"):
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if main == null:
		return
	if main.audio != null:
		main.audio.set_levels(float(settings["music"]), float(settings["sounds"]))
	if main.hud != null:
		main.hud.show_help = bool(settings["help"])


func _set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	apply_settings()


# --- building blocks -----------------------------------------------------------

func _heading(text: String, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	box.add_child(l)


func _section(text: String) -> void:
	_gap(4)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", DIM)
	box.add_child(l)


func _text(text: String, color: Color, centered := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300.0
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	box.add_child(l)


func _label(text: String, width: float, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_color_override("font_color", color)
	return l


func _gap(h := 6) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	box.add_child(c)


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	box.add_child(r)
	return r


func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(action)
	(parent if parent != null else box).add_child(b)
	return b


func _small(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(38, 38)
	b.pressed.connect(action)
	return b


func _slider(text: String, key: String) -> void:
	var row := _row()
	row.add_child(_label(text, 120.0))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(settings[key])
	s.custom_minimum_size = Vector2(220, 38)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v): _set_setting(key, v))
	row.add_child(s)


func _toggle(text: String, key: String) -> void:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = bool(settings[key])
	b.custom_minimum_size.y = 38
	b.toggled.connect(func(on): _set_setting(key, on))
	box.add_child(b)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.085, 0.11, 0.97)
	bg.border_color = Color(0.95, 0.8, 0.5, 0.35)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", bg)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		match state:
			"normal":
				s.bg_color = Color(0.16, 0.15, 0.19)
			"hover":
				s.bg_color = Color(0.22, 0.2, 0.26)
			"pressed":
				s.bg_color = Color(0.3, 0.25, 0.18)
			"focus":
				s.draw_center = false
				s.border_color = GOLD
				s.set_border_width_all(2)
			"disabled":
				s.bg_color = Color(0.3, 0.25, 0.18)
		t.set_stylebox(state, "Button", s)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color(1, 1, 1))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_color", "Label", TEXT)
	return t
