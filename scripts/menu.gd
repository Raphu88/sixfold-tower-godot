extends Control
## Menus: the title screen, the pause menu, settings, the controls list and
## the dev tool. Built from Godot's own buttons, so mouse, keyboard and touch
## all work. While a menu is open the game is paused.
##
## Esc or P (or the phone's Menu button, or Start on a controller) opens and
## closes the pause menu. Arrow keys, the d-pad or the left stick move between
## buttons; Enter, Space or A presses one; Esc or B goes back.

const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Towers := preload("res://scripts/towers.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TitleScript := preload("res://scripts/title.gd")
const Gear := preload("res://scripts/gear.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Controls := preload("res://scripts/controls.gd")

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
var backdrop: Control  # the title screen's drawing (title.gd), behind the title and its pages
var shade: ColorRect
var center: CenterContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	backdrop = TitleScript.new()
	backdrop.hide()
	add_child(backdrop)
	shade = ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_LEFT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # keys and controller: long pages scroll to the focused button
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


# --- touch -----------------------------------------------------------------------
# The project doesn't turn touches into mouse clicks (the on-screen controls
# read touches directly), so Godot's buttons never see a tap. The menu reads
# touches itself: a tap presses the button under it, a drag scrolls the page,
# and touching a slider sets it.

var touch_from := Vector2.ZERO
var touch_moved := 0.0
var touch_slider: HSlider = null


func _input(event: InputEvent) -> void:
	if page == "":
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			touch_from = event.position
			touch_moved = 0.0
			touch_slider = _control_at(event.position, "HSlider")
			if touch_slider != null:
				_slide_to(touch_slider, event.position)
		else:
			if touch_slider == null and touch_moved < 14.0:
				_tap(event.position)
			touch_slider = null
			# A phone: switch to the bigger phone layout (after the tap, so the
			# button doesn't move under the finger).
			if main != null and main.touch != null and not main.touch.active:
				main.touch._set_active(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		touch_moved += event.relative.length()
		if touch_slider != null:
			_slide_to(touch_slider, event.position)
		elif touch_moved >= 14.0:
			scroll.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()


## The topmost visible control of a class under a point, or null.
func _control_at(pos: Vector2, cls: String) -> Control:
	var found: Control = null
	for c in box.find_children("*", cls, true, false):
		var ctl: Control = c
		if ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos) and scroll.get_global_rect().has_point(pos):
			found = ctl
	return found


func _tap(pos: Vector2) -> void:
	var b = _control_at(pos, "BaseButton")
	if b == null or b.disabled:
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed  # (emits toggled)
	else:
		b.pressed.emit()


func _slide_to(sl: HSlider, pos: Vector2) -> void:
	var r := sl.get_global_rect()
	var k := clampf((pos.x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)
	sl.value = sl.min_value + k * (sl.max_value - sl.min_value)


func _process(delta: float) -> void:
	toast_t -= delta
	if toast_t <= 0.0 and toast != "":
		toast = ""
		queue_redraw()
	if Input.is_action_just_pressed("pause"):
		if page == "":
			# (once the Regard or the victory screen has played, Start moves on instead)
			if main == null or not (main.overlay_done() or main.overlay_closed_frame == Engine.get_process_frames()):
				open("pause")
		elif page == "title":
			pass
		elif page == "pause":
			close()
		else:
			open("title" if _from_title() else "pause")
	elif page != "" and Input.is_action_just_pressed("ui_cancel"):
		# Esc or B: back a page (Esc is also "pause", handled above).
		if page == "pause":
			close()
		elif page == "confirm_new":
			open(confirm_back)
		elif page != "title":
			open("title" if _from_title() else "pause")
	_layout()


## Keeps the panel inside the screen (phones draw everything bigger). On the
## title the buttons sit in the column under the name, left of the tower.
func _layout() -> void:
	var s := get_viewport_rect().size
	if page == "title":
		backdrop.menu_h = _wanted_height()
		var r: Rect2 = backdrop.menu_rect(s)
		center.position = r.position
		center.size = r.size
		scroll.custom_minimum_size = Vector2(minf(300.0, r.size.x - 40.0), minf(_wanted_height(), r.size.y))
	else:
		center.position = Vector2.ZERO
		center.size = s
		scroll.custom_minimum_size = Vector2(minf(560.0, s.x - 40.0), minf(_wanted_height(), s.y - 40.0))


## True while the title screen (or a page opened from it) covers the game.
func backdrop_showing() -> bool:
	return is_open() and backdrop.visible


var opened_from_title := false


func _from_title() -> bool:
	return opened_from_title


func _wanted_height() -> float:
	return box.get_combined_minimum_size().y + 4.0


## Opens a page (pausing the game) or switches to another page.
func open(which: String) -> void:
	# Rebuilding the same page (a dev button, a toast): keep the focus where it was.
	var keep := -1
	if which == page and is_inside_tree():
		keep = focusables().find(get_viewport().gui_get_focus_owner())
	if which == "title":
		opened_from_title = true
	elif which == "pause":
		opened_from_title = false
	page = which
	show()
	# The title's drawing stays behind the pages opened from it.
	backdrop.visible = which == "title" or (opened_from_title and which != "pause")
	backdrop.show_name = which == "title"
	shade.visible = which != "title"
	shade.color.a = 0.6 if backdrop.visible else 0.78
	if which == "title":
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		panel.remove_theme_stylebox_override("panel")
	get_tree().paused = true
	if main != null and main.touch != null:
		main.touch.release_all()
	if main != null and main.pad != null:
		main.pad.release_all()
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	scroll.scroll_vertical = 0
	call("_page_" + which)
	_layout()
	# Keyboard and controller: start on the first button (or slider).
	var list := focusables()
	if not list.is_empty():
		list[keep if keep >= 0 and keep < list.size() else 0].grab_focus.call_deferred()


func close() -> void:
	page = ""
	hide()
	get_tree().paused = false
	Engine.time_scale = 1.0


## The page's buttons and sliders, top to bottom.
func focusables() -> Array:
	var list: Array = []
	_collect_focus(box, list)
	return list


func _collect_focus(n: Node, list: Array) -> void:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is BaseButton or c is HSlider:
			list.append(c)
		else:
			_collect_focus(c, list)


# --- pages -------------------------------------------------------------------

## The title screen: the drawing (title.gd) shows the name; these are its
## buttons and a line about the climber.
func _page_title() -> void:
	var prof = main.profile
	var primary := _button("Begin your first climb" if not prof.regarded else "Continue", _leave_title)
	_title_button(primary, true)
	_title_button(_button("Body", open.bind("body")))
	_title_button(_button("Settings", open.bind("settings")))
	_title_button(_button("Dev tools", open.bind("dev")))
	if prof.regarded:
		_title_button(_button("New climber", _ask_new.bind("title")))
	_gap(2)
	_text(_title_status(), DIM, true)
	var l: Label = box.get_child(box.get_child_count() - 1)
	l.add_theme_font_size_override("font_size", 13)
	l.custom_minimum_size.x = 0.0


## Marks carried and best floor (or a word for a new climber).
func _title_status() -> String:
	var prof = main.profile
	if not prof.regarded:
		return "A new climber. You bear no mark yet."
	var names: Array = []
	for part in Bonds.PARTS:
		if prof.bonds.has(part):
			names.append(Bonds.BONDS[prof.bonds[part]["id"]]["name"])
	return "Marks: %s\nBest floor %d" % [", ".join(names) if not names.is_empty() else "none", prof.best_floor]


## The title's buttons: see-through over the sky, the first one gilded.
func _title_button(b: Button, primary := false) -> void:
	b.custom_minimum_size.y = 40.0 if primary else 36.0
	b.add_theme_font_size_override("font_size", 18 if primary else 16)
	for state in ["normal", "hover", "pressed"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(6)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		st.set_border_width_all(1)
		var bg := Color(0.24, 0.17, 0.09, 0.88) if primary else Color(0.08, 0.075, 0.11, 0.72)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = Color(0.3, 0.25, 0.18, 0.95)
		st.bg_color = bg
		st.border_color = Color(GOLD, 0.75 if primary else 0.22)
		b.add_theme_stylebox_override(state, st)
	if primary:
		b.add_theme_color_override("font_color", GOLD)


func _page_pause() -> void:
	_heading("PAUSED", 32)
	_text("%s  ·  floor %d" % [main.tower_data()["name"], main.floor_num], DIM, true)
	_gap()
	_button("Resume", close)
	_button("Restart this climb", _restart)
	_button("Body", open.bind("body"))
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
	_toggle("Controls panel (H, or D-pad up)", "help")
	_gap()
	_back()


func _page_controls() -> void:
	_heading("CONTROLS", 28)
	var ps: bool = main != null and main.pad_ps
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	var rows: Array = [["", "Keyboard and mouse", "Controller"]]
	rows.append_array(Controls.HELP)
	for i in rows.size():
		var r: Array = rows[i]
		for c in 3:
			var l := Label.new()
			l.text = Controls.pad_text(r[c], ps) if c == 2 else r[c]
			if c == 0 and i > 0:
				l.text = l.text.left(1).to_upper() + l.text.substr(1)
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", DIM if i == 0 else (TEXT if c == 0 else GOLD))
			grid.add_child(l)
	box.add_child(grid)
	_text(Controls.pad_text("Controller casts: hold {lb} and press {x} hand, {a} legs, {b} heart, {y} brow, {rb} throat or {rt} back. Aim with the right stick; let go of it and you aim at the nearest monster, or the way you move. Hold {back} to restart. In menus and on the cards: d-pad or stick to choose, {a} to take, {b} to go back.", ps), DIM)
	_text("On a phone: the left side is a joystick, the buttons on the right attack, roll, parry, swap and cast; Item uses your item and the small arrow beside it picks the next; Take appears while you stand on gear. Hold a mark's button and slide to pick a spell.", DIM)
	_gap()
	_back()


## Your body: the six parts with their marks, and the essence density that
## has settled in you (each essence type is an attribute with a small bonus).
func _page_body() -> void:
	_heading("BODY", 28)
	var view := BodyView.new()
	view.main = main
	view.custom_minimum_size = Vector2(500, 230)
	box.add_child(view)
	_section("Essence density")
	var prof = main.profile
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	for kind in ["air", "blade", "stone", "iron", "fire", "water"]:
		var attr: Dictionary = prof.ATTRIBUTES[kind]
		grid.add_child(_label("%s  (%s)" % [main.Essence.display(kind), attr["name"]], 150.0, main.Essence.color(kind)))
		grid.add_child(_label("%d" % int(prof.density.get(kind, 0.0)), 50.0, TEXT))
		grid.add_child(_label("+%.1f%% %s" % [prof.attribute(kind) * 100.0, attr["bonus"]], 200.0, GOLD if prof.attribute(kind) > 0.001 else DIM))
	box.add_child(grid)
	_text("Every bit of essence you bank at a stair settles in you as density, in the body parts that earned it. Each type gives a small passive bonus (up to 12%).", DIM)
	_page_body_gear()
	_gap()
	_back()


## The Body page's Gear section: what you carry this climb, with key stats.
func _page_body_gear() -> void:
	_section("Gear")
	var p = main.player
	if p == null:
		return
	var rows: Array = [["1  Fists", "fists"], ["2  Melee", p.gear["melee"]], ["3  Ranged", p.gear["ranged"]], ["Armor", p.gear["armor"]]]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	for r in rows:
		var id: String = r[1]
		var empty: bool = id == "" and r[0] != "Armor"
		grid.add_child(_label(r[0], 80.0, DIM))
		grid.add_child(_label(Gear.display(id) if not empty else "empty", 120.0, GOLD if id == p.weapon or (r[0] == "Armor" and id != "") else TEXT))
		var stats := _label(Gear.summary(id) if not empty else "", 300.0, TEXT)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(stats)
	box.add_child(grid)
	_text("Gear lasts one climb: every climb starts with a sword, a shortbow and no armor, unless you hold an heirloom for that slot. Monsters sometimes drop gear, caches can hold it, and the camp offers a piece. Walk over it to see how it compares; press Y (or tap Take) to swap.", DIM)
	_page_body_heirlooms()


## The Body page's Heirlooms: gear kept from survived climbs, one per slot,
## and the slots still to come.
func _page_body_heirlooms() -> void:
	_section("Heirlooms")
	var kept: Dictionary = main.profile.heirlooms if main.profile != null else {}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	for s in Gear.HEIRLOOM_SLOTS:
		var planned: bool = s.get("planned", false)
		grid.add_child(_label(s["name"], 80.0, DIM))
		var id: String = kept.get(s["id"], "")
		var shown := Gear.HEIRLOOM_TEXT["planned"] if planned else (Gear.display(id) if id != "" else "none")
		grid.add_child(_label(shown, 200.0, GOLD if id != "" else DIM))
	box.add_child(grid)
	_text("Survive a climb and you keep one piece you carried as an heirloom. Every climb begins with your heirlooms, one per slot.", DIM)


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

	_section("Practice a beast (full health)")
	var brow := GridContainer.new()
	brow.columns = 3
	brow.add_theme_constant_override("h_separation", 6)
	brow.add_theme_constant_override("v_separation", 6)
	for id in Towers.ORDER:
		if Towers.TOWERS[id].has("beast_kind"):
			_button(Towers.TOWERS[id]["short"], _dev_beast.bind(id), brow)
	box.add_child(brow)

	_section("Spawn a monster")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for kind in EnemyScript.TYPES.keys().filter(func(k): return k != "familiar"):
		_button(kind.capitalize(), _dev_spawn.bind(kind), grid)
	box.add_child(grid)

	_section("Gear (give yourself any weapon or armor)")
	var ggrid := GridContainer.new()
	ggrid.columns = 4
	ggrid.add_theme_constant_override("h_separation", 6)
	ggrid.add_theme_constant_override("v_separation", 6)
	for id in Weapons.ORDER:
		if id != "fists":
			var gb := _button(Weapons.WEAPONS[id]["name"], _dev_gear.bind(id), ggrid)
			gb.disabled = id == p.gear["melee"] or id == p.gear["ranged"]
	for id in Gear.ARMOR_ORDER:
		var ab := _button(Gear.ARMOR[id]["name"], _dev_gear.bind(id), ggrid)
		ab.disabled = id == p.gear["armor"]
	box.add_child(ggrid)

	_section("Cheats")
	var crow := _row()
	_button("No dying: %s" % ("on" if main.dev_no_death else "off"), _toggle_no_death, crow)
	_button("Heal", _heal, crow)
	_button("Clear the room", _clear_room, crow)
	if main.trap_view != null:
		_button("Show traps: %s" % ("on" if main.trap_view.show_all else "off"), _toggle_traps, crow)
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


func _dev_beast(id: String) -> void:
	main.dev_beast(id)
	close()  # straight into the fight


func _dev_spawn(kind: String) -> void:
	main.dev_spawn(kind)
	_say("Spawned: %s" % kind.capitalize())


func _dev_gear(id: String) -> void:
	main.dev_give_gear(id)
	_say("Now carrying: %s" % Gear.display(id))


func _toggle_no_death() -> void:
	main.dev_no_death = not main.dev_no_death
	open("dev")


func _toggle_traps() -> void:
	main.trap_view.show_all = not main.trap_view.show_all
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
	var name_label := _label(text, 120.0)
	row.add_child(name_label)
	var s := HSlider.new()
	# Keys and controller: a focused slider lights up gold (left and right move it).
	s.focus_entered.connect(func():
		name_label.add_theme_color_override("font_color", GOLD)
		s.modulate = Color(1.0, 0.85, 0.55))
	s.focus_exited.connect(func():
		name_label.add_theme_color_override("font_color", TEXT)
		s.modulate = Color.WHITE)
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
		if state == "focus":
			# Keys and controller: the focused toggle or slider is outlined in gold too.
			t.set_stylebox("focus", "CheckButton", s)
			t.set_stylebox("focus", "HSlider", s)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color(1, 1, 1))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_color", "Label", TEXT)
	return t



## A drawing of the climber's body: the six parts, each marked or not, and
## how much essence has settled in each.
class BodyView extends Control:
	var main

	const SPOTS := {
		"brow": Vector2(0, -88), "throat": Vector2(0, -58), "heart": Vector2(-10, -30),
		"hand": Vector2(-52, 0), "back": Vector2(26, -24), "legs": Vector2(-14, 60),
	}

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var c := Vector2(110, size.y * 0.5 + 6)
		var skin := Color(0.32, 0.3, 0.36)
		# A simple figure: head, body, arms and legs.
		draw_circle(c + Vector2(0, -92), 18.0, skin)
		draw_rect(Rect2(c + Vector2(-22, -70), Vector2(44, 74)), skin)
		draw_line(c + Vector2(-22, -62), c + Vector2(-52, 0), skin, 10.0)
		draw_line(c + Vector2(22, -62), c + Vector2(52, 0), skin, 10.0)
		draw_line(c + Vector2(-12, 4), c + Vector2(-16, 80), skin, 12.0)
		draw_line(c + Vector2(12, 4), c + Vector2(16, 80), skin, 12.0)
		var prof = main.profile
		var parts: Array = ["brow", "throat", "heart", "back", "hand", "legs"]  # top to bottom, as on the body
		var y := 18.0
		for part in parts:
			var at: Vector2 = c + SPOTS[part]
			var info: Dictionary = prof.bonds.get(part, {})
			var col := Color(0.55, 0.55, 0.6)
			var label := "unmarked"
			if not info.is_empty():
				var data: Dictionary = main.BondScript.Bonds.BONDS[info["id"]]
				col = data["color"]
				label = "%s, step %d%s" % [data["name"], prof.step_for_xp(float(info["xp"])), " (faint)" if info["faint"] else ""]
			# Settled essence: a ring per type, sized by its share.
			var pd: Dictionary = prof.part_density.get(part, {})
			var total := 0.0
			for k in pd:
				total += float(pd[k])
			var r := 6.0 + minf(total / 60.0, 10.0)
			if total > 0.0:
				var a0 := -PI / 2.0
				for k in pd:
					var sweep := TAU * float(pd[k]) / total
					draw_arc(at, r + 3.0, a0, a0 + sweep, 16, main.Essence.color(k), 3.0)
					a0 += sweep
			draw_circle(at, 6.0, col if not info.is_empty() else Color(col, 0.5))
			# The list on the right.
			var lx := 240.0
			draw_string(font, Vector2(lx, y + 14), main.BondScript.Bonds.PART_NAMES[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.8, 0.5))
			draw_string(font, Vector2(lx + 70, y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - lx - 70, 14, col if not info.is_empty() else Color(0.62, 0.59, 0.67))
			draw_string(font, Vector2(lx + 70, y + 30), "%d essence settled" % int(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.59, 0.67))
			draw_line(c + SPOTS[part], Vector2(lx - 8, y + 10), Color(col, 0.25), 1.0)
			y += 36.0
