extends Control
## Menus: the title screen, the pause menu, the climber screen, the
## inventory, settings, the controls list and the dev tool. Built from
## Godot's own buttons, so mouse, keyboard, controller and touch all work.
## While a menu is open the game is paused.
##
## Esc or P (Start on a controller, Menu on a phone) opens and closes the
## pause menu. Tab (a short press of View, the Climber button on a phone)
## opens the climber screen, and I (d-pad up, the Bag button on a phone) the
## inventory; the same key closes them. Arrow keys, the d-pad or the left
## stick move between buttons; Enter, Space or A presses one; Esc or B goes
## back (and closes the menu from the pause page or a screen opened by key).

const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Towers := preload("res://scripts/towers.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TitleScript := preload("res://scripts/title.gd")
const Gear := preload("res://scripts/gear.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Items := preload("res://scripts/items.gd")
const Controls := preload("res://scripts/controls.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")

const GOLD := UI.GOLD
const TEXT := UI.TEXT
const DIM := UI.DIM
const FAINT := UI.FAINT
const SETTINGS_PATH := "user://sixfold.cfg"

## How wide each page's panel is (it shrinks to fit a small screen).
const WIDTHS := {"pause": 440.0, "settings": 520.0, "controls": 660.0, "confirm_new": 440.0,
	"dev": 660.0, "climber": 800.0, "inventory": 800.0, "mark": 800.0}
## The climber screen's tabs: [id, name].
const CLIMBER_TABS := [["marks", "Marks"], ["essence", "Essence"], ["record", "Record"]]
## Below this screen height (a phone, drawn 1.5x) the pages tighten up to fit.
const COMPACT_H := 600.0

## Settings, kept between sessions (in the same file as the profile).
static var settings := {"music": 0.8, "sounds": 1.0, "shake": true, "help": false, "hud_scale": "normal", "climber_tab": "marks"}
static var settings_loaded := false

var main
var page := ""  # "" when closed
var box: VBoxContainer  # the current page's contents
var panel: PanelContainer
var scroll: ScrollContainer
## Below the scroll area: Close/Back on the tall pages, so it's always on screen.
var foot: VBoxContainer
const PINNED_FOOTER := ["climber", "inventory", "mark"]
const FOOT_H := 54.0
var toast := ""
var toast_t := 0.0
var confirm_back := ""  # the page "Cancel" returns to
var backdrop: Control  # the title screen's drawing (title.gd), behind the title and its pages
var shade: ColorRect
var center: CenterContainer
var fade: Tween
var opened_from_title := false
var opened_direct := false  # the climber screen or inventory, opened by its own key: Back closes
var climber_tab := "marks"  # the climber screen's tab (remembered between sessions)
var mark_part := ""  # the body part the mark detail page shows
var focus_part := ""  # back on the Marks tab: the card to focus
var inv_sel := ""  # the inventory slot whose details show ("gear:melee", "item:draught", ...)
var details: VBoxContainer  # the inventory's details pane


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	backdrop = TitleScript.new()
	backdrop.hide()
	add_child(backdrop)
	shade = ColorRect.new()
	shade.color = UI.SHADE
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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(scroll)
	foot = VBoxContainer.new()
	col.add_child(foot)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	hide()
	load_settings()
	if CLIMBER_TABS.any(func(t): return t[0] == settings["climber_tab"]):
		climber_tab = settings["climber_tab"]
	apply_settings()


## A short screen (a phone): pages tighten up so they fit without scrolling.
func compact() -> bool:
	return is_inside_tree() and get_viewport_rect().size.y < COMPACT_H


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
	# Q and E (LB and RB): the climber screen's tabs, or the next mark.
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Q or event.keycode == KEY_E):
		if _cycle(1 if event.keycode == KEY_E else -1):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		if _cycle(1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1):
			get_viewport().set_input_as_handled()
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
	for c in foot.find_children("*", cls, true, false):
		var ctl: Control = c
		if ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
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


# --- keys ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	toast_t -= delta
	if toast_t <= 0.0 and toast != "":
		toast = ""
	if Input.is_action_just_pressed("pause"):
		if page == "":
			# (once the Regard or the victory screen has played, Start moves on instead)
			if _can_open():
				open("pause")
		elif page != "title":
			go_back()
	elif page != "" and page != "title" and Input.is_action_just_pressed("ui_cancel"):
		go_back()  # Esc or B (Esc is also "pause", handled above)
	else:
		for which in ["climber", "inventory"]:
			if Input.is_action_just_pressed(which):
				toggle(which)
				break
	if page == "mark":
		# The detail page's text isn't focusable: up and down scroll it.
		var v := Input.get_axis("ui_up", "ui_down")
		if absf(v) > 0.2:
			scroll.scroll_vertical += int(v * 700.0 * delta)
	_layout()


## Q/E or LB/RB: the next climber tab, or the next mark on the detail page.
## True if it did something.
func _cycle(by: int) -> bool:
	if page == "climber":
		var ids: Array = CLIMBER_TABS.map(func(t): return t[0])
		_set_climber_tab(ids[(ids.find(climber_tab) + by + ids.size()) % ids.size()])
		return true
	if page == "mark":
		var order := mark_order()
		open_mark(order[(order.find(mark_part) + by + order.size()) % order.size()])
		return true
	return false


## Tab and I: open the climber screen or the inventory, or close it again.
func toggle(which: String) -> void:
	if page == which or (page == "mark" and which == "climber"):
		if opened_from_title:
			open("title")
		else:
			close()
	elif page == "":
		if _can_open() and not (main != null and main.overlay_showing()):
			open(which, true)
	elif page != "title" and page != "confirm_new":
		open(which, opened_direct)


func _can_open() -> bool:
	return main == null or not (main.overlay_done() or main.overlay_closed_frame == Engine.get_process_frames())


## Esc, B or the Back button: back a page, or out of the menu.
func go_back() -> void:
	if page == "confirm_new":
		open(confirm_back)
	elif page == "mark":
		focus_part = mark_part
		open("climber", opened_direct)
	elif page == "pause" or page == "":
		close()
	elif page != "title":
		var to := _back_page()
		if to == "":
			close()
		else:
			open(to)


## Where Back goes from this page: the title, the pause menu, or out ("").
func _back_page() -> String:
	if opened_from_title:
		return "title"
	if opened_direct:
		return ""
	return "pause"


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
	elif page != "":
		center.position = Vector2.ZERO
		center.size = s
		var edge := 12.0 if compact() else 32.0  # space kept around the panel
		var pad := 24.0 if compact() else 40.0  # the panel's own margins
		var h := minf(_wanted_height(), s.y - edge - pad)
		if page in PINNED_FOOTER:
			# The same size on every tab; Close sits below.
			h = minf(maxf(_wanted_height(), 520.0), s.y - edge - pad - FOOT_H)
		scroll.custom_minimum_size = Vector2(minf(float(WIDTHS.get(page, 560.0)), s.x - edge - pad), h)
		panel.pivot_offset = panel.size * 0.5


## True while the title screen (or a page opened from it) covers the game.
func backdrop_showing() -> bool:
	return is_open() and backdrop.visible


func _from_title() -> bool:
	return opened_from_title


func _wanted_height() -> float:
	return box.get_combined_minimum_size().y + 4.0


## Opens a page (pausing the game) or switches to another page. `direct`:
## opened by its own key (Tab, I), so Back closes it.
func open(which: String, direct := false) -> void:
	var was_closed := page == ""
	var switching := which != page or which == "climber" or which == "mark"  # (a new tab or mark too)
	# Rebuilding the same page (a dev button, a toast): keep the focus where it was.
	var keep := -1
	if which == page and is_inside_tree():
		keep = focusables().find(get_viewport().gui_get_focus_owner())
	if was_closed:
		opened_from_title = which == "title"
		opened_direct = direct
	elif which == "title":
		opened_from_title = true
		opened_direct = false
	elif which == "pause":
		opened_from_title = false
		opened_direct = false
	page = which
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if fade != null:
		fade.kill()
	if was_closed:
		# A short fade in, the panel easing up to full size.
		modulate.a = 0.0
		panel.scale = Vector2(0.97, 0.97)
		fade = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		fade.tween_property(self, "modulate:a", 1.0, UI.FADE_IN)
		fade.tween_property(panel, "scale", Vector2.ONE, UI.FADE_IN * 1.5)
	elif switching:
		# Another page: a quick fade between them.
		modulate.a = 1.0
		panel.scale = Vector2.ONE
		panel.modulate.a = 0.55
		fade = create_tween()
		fade.tween_property(panel, "modulate:a", 1.0, UI.FADE_IN * 0.8)
	else:
		modulate.a = 1.0
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
	# The title's drawing stays behind the pages opened from it.
	backdrop.visible = which == "title" or (opened_from_title and which != "pause")
	backdrop.show_name = which == "title"
	shade.visible = which != "title"
	shade.color.a = 0.6 if backdrop.visible else UI.SHADE.a
	if which == "title":
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	elif compact():
		var st := UI.menu_panel()
		st.set_content_margin_all(12.0)
		panel.add_theme_stylebox_override("panel", st)
	else:
		panel.remove_theme_stylebox_override("panel")
	get_tree().paused = true
	if main != null and main.touch != null:
		main.touch.release_all()
	if main != null and main.pad != null:
		main.pad.release_all()
	for c in box.get_children() + foot.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	details = null
	if keep < 0:
		scroll.scroll_vertical = 0
	call("_page_" + which)
	_layout()
	# Keyboard and controller: start on the first button (or slider), or the
	# page's own starting point.
	var list := focusables()
	if not list.is_empty():
		var first := 0
		if which == "climber":
			first = maxi(0, CLIMBER_TABS.map(func(t): return t[0]).find(climber_tab))
			if focus_part != "":
				# Back from a mark's page: on its card again.
				first = maxi(first, list.map(func(b): return b.get_meta("part", "")).find(focus_part))
				focus_part = ""
		elif which == "mark":
			first = maxi(0, list.map(func(b): return b.get_meta("back", false)).find(true))
		elif which == "inventory":
			first = maxi(0, list.map(func(b): return b.get_meta("slot", "")).find(inv_sel))
		_focus_later.call_deferred(list[keep if keep >= 0 and keep < list.size() else first])


## Focus a control next frame, if the page it's on is still showing.
func _focus_later(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and not c.is_queued_for_deletion():
		c.grab_focus()


func close() -> void:
	if page == "":
		return
	page = ""
	opened_direct = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	# A short fade out; nothing on it answers while it fades.
	get_viewport().gui_release_focus()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, UI.FADE_OUT)
	fade.parallel().tween_property(panel, "scale", Vector2(0.98, 0.98), UI.FADE_OUT)
	fade.tween_callback(func():
		if page == "":
			hide())


## The page's buttons and sliders, top to bottom.
func focusables() -> Array:
	var list: Array = []
	_collect_focus(box, list)
	_collect_focus(foot, list)
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
	_title_button(_button("Climber", open.bind("climber")))
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
		var bg := Color(0.24, 0.17, 0.09, 0.88) if primary else Color(0.08, 0.075, 0.11, 0.72)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = Color(UI.BUTTON_DOWN, 0.95)
		var st := UI.box(bg, Color(GOLD, 0.75 if primary else 0.22), 6)
		_button_margins(st)
		b.add_theme_stylebox_override(state, st)
	if primary:
		b.add_theme_color_override("font_color", GOLD)


func _page_pause() -> void:
	_header("PAUSED", "%s  ·  floor %d" % [main.tower_data()["name"], main.floor_num])
	_primary(_button("Resume", close))
	var grid := _grid(2)
	_button(_with_key("Climber", "Tab", "{back}"), open.bind("climber"), grid)
	_button(_with_key("Inventory", "I", "D-pad up"), open.bind("inventory"), grid)
	_button("Settings", open.bind("settings"), grid)
	_button("Controls", open.bind("controls"), grid)
	_button("Restart this climb", _restart, grid)
	_button("Dev tools", open.bind("dev"), grid)
	_gap(2)
	_button("New climber", _ask_new.bind("pause"))
	if can_quit():
		var row := _grid(2)
		_button("Exit to title", exit_to_title, row)
		_button("Quit game", _quit_game, row)
	else:
		_button("Exit to title", exit_to_title)


## A button's name with its key or controller button after it (none on a phone).
func _with_key(text: String, key: String, pad: String) -> String:
	if main == null or main.touch_active:
		return text
	if main.pad_active:
		return "%s   %s" % [text, Controls.pad_text(pad, main.pad_ps)]
	return "%s   %s" % [text, key]


## On a computer the game can be quit; in a browser or on a phone, Exit goes
## back to the title instead.
static func can_quit() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("mobile"))


func _page_settings() -> void:
	_header("SETTINGS", "")
	_slider("Music", "music")
	_slider("Sounds", "sounds")
	_toggle("Screen shake", "shake")
	_toggle("Controls list on screen (H)", "help")
	_choice("HUD size", "hud_scale", [["small", "Small"], ["normal", "Normal"], ["large", "Large"]])
	_footer()


## A row of buttons for a setting with a few values; the current one gilded.
func _choice(text: String, key: String, values: Array) -> void:
	var row := _row()
	row.add_child(_label(text, 120.0))
	for v in values:
		var b := _button(v[1], func():
			_set_setting(key, v[0])
			open(page), row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("choice", v[0])
		if str(settings[key]) == v[0]:
			_primary(b)


func _page_controls() -> void:
	_header("CONTROLS", "")
	var ps: bool = main != null and main.pad_ps
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	var rows: Array = [["", "Keyboard and mouse", "Controller"]]
	rows.append_array(Controls.HELP)
	for i in rows.size():
		var r: Array = rows[i]
		for c in 3:
			var l := Label.new()
			l.text = Controls.pad_text(r[c], ps) if c == 2 else r[c]
			if c == 0 and i > 0:
				l.text = l.text.left(1).to_upper() + l.text.substr(1)
			l.add_theme_font_size_override("font_size", 14 if i > 0 else 12)
			l.add_theme_color_override("font_color", DIM if i == 0 else (TEXT if c == 0 else GOLD))
			grid.add_child(l)
	box.add_child(grid)
	_gap(2)
	_note(Controls.pad_text("Controller casts: hold {lb} and press {x} hand, {a} legs, {b} heart, {y} brow, {rb} throat or {rt} back. Aim with the right stick; let go of it and you aim at the nearest monster, or the way you move. Press {back} for the climber screen, hold it to restart. In menus and on the cards: d-pad or stick to choose, {a} to take, {b} to go back.", ps))
	_note("On a phone: the left side is a joystick, the buttons on the right attack, roll, parry, swap and cast; Item uses your item and the small arrow beside it picks the next; Take appears while you stand on gear. Hold a mark's button and slide to pick a spell. Climber, Bag and Menu sit at the top right.")
	_footer()


# --- the climber screen ---------------------------------------------------------------

## The character sheet: marks on the body and each bond's growth, the essence
## settled in you (your attributes), and your record and heirlooms.
func _page_climber() -> void:
	var prof = main.profile
	_header("CLIMBER", _climber_line())
	_tabs(CLIMBER_TABS, climber_tab, _set_climber_tab)
	match climber_tab:
		"essence":
			_climber_essence(prof)
		"record":
			_climber_record(prof)
		_:
			_climber_marks(prof)
	_footer()


func _set_climber_tab(id: String) -> void:
	climber_tab = id
	if settings["climber_tab"] != id:
		settings["climber_tab"] = id  # remembered for next time
		save_settings()
	open("climber", opened_direct)


func _climber_line() -> String:
	var prof = main.profile
	var marks: int = prof.bonds.size()
	return "%d of 6 marks  ·  %d %s  ·  best floor %d" % [marks, prof.climbs, "climb" if prof.climbs == 1 else "climbs", prof.best_floor]


## The body parts in the order the cards show them: marked ones first (top
## to bottom, as on the body), then the rest.
func mark_order() -> Array:
	var prof = main.profile
	var order: Array = BodyView.ORDER.filter(func(pt): return prof.bonds.has(pt))
	order.append_array(BodyView.ORDER.filter(func(pt): return not prof.bonds.has(pt)))
	return order


## Marks: the climber with its marks glowing, and a card for each body part
## (press one for its page).
func _climber_marks(prof) -> void:
	var small := compact()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var view := BodyView.new()
	view.main = main
	view.custom_minimum_size = Vector2(292, 0) if small else Vector2(310, 0)
	row.add_child(view)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	for part in mark_order():
		var card := MarkCard.new()
		card.main = main
		card.part = part
		card.set_meta("part", part)
		card.custom_minimum_size = Vector2(0, 76.0 if small else 104.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(open_mark.bind(part))
		grid.add_child(card)
	view.custom_minimum_size.y = (76.0 if small else 104.0) * 3.0 + 16.0
	if small:
		return
	if prof.bonds.is_empty():
		_note("Your first climb is bondless. Reach the top and the tower's beast takes notice: the body part you used most takes your first mark.")
	else:
		_note("Bonds grow across climbs from the essence you bank at each stair, up to step 5. Choose a mark to see every spell, what each step brings, and its body and passive effects.")


## Essence: density by type (each is an attribute with a small bonus), where
## it has settled in the body, and what you carry unbanked this climb.
func _climber_essence(prof) -> void:
	var view := EssenceView.new()
	view.main = main
	view.custom_minimum_size = Vector2(0, EssenceView.height(compact()))
	box.add_child(view)
	if not compact():
		_note("Every bit of essence you bank at a stair settles in you as density, in the body parts that earned it. Each type gives a small passive bonus that grows ever slower, up to %d%%." % int(round(prof.ATTRIBUTE_CAP * 100.0)))


## Record: the climb you're on and your record on the left, your heirlooms
## on the right.
func _climber_record(prof) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	_section("This climb", left)
	var g := _grid_in(left)
	var t: Dictionary = main.tower_data()
	_pair(g, "Tower", t["name"], Essence.color(t["essence"]))
	_pair(g, "Floor", "%d" % main.floor_num)
	_pair(g, "Essence", "%s" % Essence.display(t["essence"]), Essence.color(t["essence"]))
	_pair(g, "Kind of climb", "the bondless first climb" if main.first_climb else "a climb with your marks")
	_section("Your record", left)
	var r := _grid_in(left)
	_pair(r, "Climbs", "%d" % prof.climbs)
	_pair(r, "Best floor", "%d" % prof.best_floor)
	_pair(r, "Marks", "%d of 6" % prof.bonds.size())
	if not prof.pacts.is_empty():
		_pair(r, "Pacts", "%d bound" % prof.pacts.size())
	_section("Heirlooms", right)
	for s in Gear.HEIRLOOM_SLOTS:
		if s.get("planned", false):
			continue
		var id: String = prof.heirlooms.get(s["id"], "")
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 10)
		right.add_child(hr)
		var icon := SlotIcon.new()
		icon.kind = "gear" if id != "" else "empty"
		icon.id = id
		icon.tint = Gear.color(id) if id != "" else FAINT
		icon.custom_minimum_size = Vector2(38, 38)
		hr.add_child(icon)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(names)
		names.add_child(_small_label(s["name"], DIM))
		var nl := _label(Gear.display(id) if id != "" else "none", 0.0, Gear.color(id).lightened(0.1) if id != "" else FAINT)
		names.add_child(nl)
	var note := Label.new()
	note.text = "Survive a climb and you keep one piece you carried as an heirloom; every climb begins with them. The Inventory shows every slot."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 200.0
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", FAINT)
	right.add_child(note)


func _grid_in(parent: Node) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 2)
	parent.add_child(g)
	return g


# --- a mark's page --------------------------------------------------------------------

## Opens the detail page for the mark on a body part (or what's forming there).
func open_mark(part: String) -> void:
	mark_part = part
	open("mark", opened_direct)


## A mark in detail: its emblem, growth and steps, its body and passive
## effects, and every spell, those not learned yet included (dimmed, with
## the step that teaches them). An unmarked part shows what is forming there.
func _page_mark() -> void:
	var info: Dictionary = main.profile.bonds.get(mark_part, {})
	var hero := MarkHero.new()
	hero.main = main
	hero.part = mark_part
	hero.custom_minimum_size = Vector2(0, 136.0 if compact() else 152.0)
	box.add_child(hero)
	if info.is_empty():
		_mark_unmarked()
	else:
		_mark_bond(info)
	_footer()


func _mark_bond(info: Dictionary) -> void:
	var data: Dictionary = Bonds.BONDS[info["id"]]
	var col: Color = data["color"]
	var step := ProfileScript.step_for_xp(float(info["xp"]))
	if info.get("faint", false):
		_rich("[color=#%s]Faint:[/color] taken in a fall, it must soak up %d more essence before it grows. Until then its spells cost a quarter more and hit a quarter softer." % [UI.BAD.to_html(false), int(ceil(float(info.get("debt", 0.0))))], 13, DIM)
	# Body and passive, side by side.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_effect_panel(row, "Body", data["body"], col)
	_effect_panel(row, "Passive", data["passive"], col)
	_section("Spells")
	_rich(_cast_line(), 12, DIM)
	var i := 0
	for sp in data["spells"]:
		i += 1
		_spell_card(sp, step, col, data["affinity"], i)
	_section("Steps")
	for s in range(1, ProfileScript.STEP_XP.size() + 1):
		var need := int(ProfileScript.STEP_XP[s - 1])
		var what: String = Bonds.step_note(info["id"], s) if s > 1 else "the mark takes hold"
		if what == "":
			what = "its spells grow stronger"
		var reached := s <= step
		var head := "Step %d" % s
		var c := GOLD if s == step else (TEXT if reached else FAINT)
		_rich("[color=#%s]%s[/color]  [color=#%s]%s[/color]  %s" % [c.to_html(false), head, FAINT.to_html(false),
			"from the start" if s == 1 else "%d essence banked" % need, what], 13, TEXT if reached else FAINT)


## A panel for the body or passive effect.
func _effect_panel(parent: Node, title: String, eff: Dictionary, col: Color) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(col, 0.22), 6, 1, 10.0))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_stretch_ratio = 1.0
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	pc.add_child(v)
	var t := _small_label(title.to_upper(), Color(GOLD, 0.7))
	t.add_theme_font_size_override("font_size", 11)
	v.add_child(t)
	var n := _label(eff["name"], 0.0, col.lightened(0.15))
	n.add_theme_font_size_override("font_size", 15)
	v.add_child(n)
	var d := Label.new()
	d.text = _sentence(eff["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 160.0
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", TEXT)
	v.add_child(d)


## How to cast this mark's spells, on every kind of input.
func _cast_line() -> String:
	var key: String = Bonds.PART_KEYS[mark_part]
	var ps: bool = main.pad_ps
	var pad := "%s + %s" % [Controls.pad_name("lb", ps), Controls.pad_name(Controls.PART_PAD[mark_part], ps)]
	var g := GOLD.to_html(false)
	return "Cast with [color=#%s]%s[/color] (keys), [color=#%s]%s[/color] (controller) or its mark's button (phone). With more than one spell learned, hold it and pick one." % [g, key, g, pad]


## One spell: its name and the step that teaches it, what it does, its cost
## and wind-up, and what each later step changes. Not learned yet: dimmed,
## locked, "learned at step N".
func _spell_card(sp: Dictionary, step: int, col: Color, affinity: String, index: int) -> void:
	var learn := int(sp["learn"])
	var known := learn <= step
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.04) if known else Color(1, 1, 1, 0.015),
		Color(col, 0.3) if known else Color(1, 1, 1, 0.06), 7, 1, 10.0))
	pc.set_meta("spell", sp["id"])
	pc.set_meta("learn", learn)
	pc.set_meta("locked", not known)
	box.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	var icon := SpellIcon.new()
	icon.col = col
	icon.affinity = affinity
	icon.locked = not known
	icon.index = index
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name := _label(sp["name"], 0.0, col.lightened(0.2) if known else DIM)
	name.add_theme_font_size_override("font_size", 16)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var tag := _small_label("learned  ·  step %d" % learn if known else "learned at step %d" % learn, UI.GOOD if known else FAINT)
	tag.add_theme_font_size_override("font_size", 12)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tag)
	var d := Label.new()
	d.text = _sentence(sp["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 200.0
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", TEXT if known else DIM)
	v.add_child(d)
	var at := step if known else learn
	var stats := _spell_stats(sp, at)
	if stats != "":
		_rich("%s%s" % ["" if known else "At step %d:  " % learn, stats], 12, DIM if known else FAINT, v)
	var changes := _spell_changes(sp, step)
	if changes != "":
		_rich(changes, 12, FAINT, v)


## A spell's numbers at a step (the latest step at or below it that sets each wins).
static func _spell_values(sp: Dictionary, at: int) -> Dictionary:
	var vals := {}
	var steps: Dictionary = sp["steps"]
	for s in range(1, at + 1):
		if steps.has(s):
			for k in steps[s]:
				vals[k] = steps[s][k]
	return vals


func _spell_stats(sp: Dictionary, at: int) -> String:
	var vals := _spell_values(sp, at)
	var bits: Array = []
	for k in ["cost", "windup"]:
		if vals.has(k):
			bits.append(_stat_text(k, vals[k]))
	for k in vals:
		if k != "cost" and k != "windup":
			var t := _stat_text(k, vals[k])
			if t != "":
				bits.append(t)
	return "  ·  ".join(bits)


## What each step after the one that teaches it changes (in numbers and words).
func _spell_changes(sp: Dictionary, step: int) -> String:
	var learn := int(sp["learn"])
	var steps: Dictionary = sp["steps"]
	var words: Dictionary = sp.get("changes", {})
	var at: Array = []
	for s in steps.keys() + words.keys():
		if int(s) > learn and not (int(s) in at):
			at.append(int(s))
	at.sort()
	var lines: Array = []
	for s in at:
		var bits: Array = []
		if words.has(s):
			bits.append(String(words[s]))
		if steps.has(s):
			for k in steps[s]:
				var t := _stat_text(k, steps[s][k])
				if t != "":
					bits.append(t.to_lower())
		var c := (GOLD if s == step else DIM) if s <= step else FAINT
		lines.append("[color=#%s]Step %d:[/color] %s" % [c.to_html(false), s, ", ".join(bits)])
	return "\n".join(lines)


## A spell value in words: "Cost 12 essence", "Wind-up 0.45 s", "Damage 10".
static func _stat_text(key: String, v) -> String:
	if v is bool:
		return key.capitalize() if v else ""
	if not (v is float or v is int):
		return ""
	var n := _num(float(v))
	match key:
		"cost":
			return "Cost %s essence" % n
		"windup":
			return "Wind-up %s s" % n
		"duration":
			return "Lasts %s s" % n
		"stun", "lift", "sustain":
			return "%s %s s" % [key.capitalize(), n]
		"arc":
			return "Arc %s°" % n
	return "%s %s" % [key.capitalize(), n]


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.001:
		return "%d" % int(roundf(f))
	return ("%.2f" % f).rstrip("0").rstrip(".")


static func _sentence(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1) + ("" if t.ends_with(".") else ".")


## An unmarked body part: what soaks into it and what would form there.
func _mark_unmarked() -> void:
	var prof = main.profile
	var fills: String = Bonds.PART_FILLS[mark_part].replace("fills when", "soaks up essence when")
	_section("Forming")
	_text("Your %s %s." % [Bonds.PART_NAMES[mark_part].to_lower(), fills], TEXT)
	var lead := ""
	if main.player != null and prof.bonds.size() < 6:
		lead = main.leading_part()
	if lead == mark_part:
		var bid: String = main.predicted_bond()
		var t := "Your next mark is forming here."
		if bid != "":
			var b: Dictionary = Bonds.BONDS[bid]
			t += " If it took now it would be [color=#%s]%s[/color], a bond of %s essence." % [b["color"].to_html(false), b["name"], Essence.display(b["affinity"])]
		_rich(t, 14, GOLD)
	if main.first_climb:
		_note("Your first climb is bondless. At the Regard the body part you used most takes your first mark, shaped by the essence you gathered.")
	else:
		_note("Essence you bank soaks into the parts that earned it. Once an unmarked part has soaked up enough, the next stair marks it; the bond it forms follows the essence you banked and the way you fought.")


## A wrapped line of text with [color] tags.
func _rich(bb: String, size: int, col: Color, parent: Node = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = 200.0
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", col)
	r.text = bb
	(parent if parent != null else box).add_child(r)
	return r


# --- the inventory --------------------------------------------------------------------

## What you carry this climb as a grid of slots (gear, items, heirlooms and a
## camp's rune), with the focused slot's details on the right.
func _page_inventory() -> void:
	var p = main.player
	_header("INVENTORY", "Gear and items last one climb; heirlooms stay with you.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var keys: Array = []
	var big := 52.0 if compact() else 64.0  # slot sizes (smaller on a phone)
	var little := 40.0 if compact() else 50.0

	_section("Carried", left)
	var gear_row := _slot_row(left)
	var hand: String = p.weapon if p != null else ""
	var carried := [["fists", "fists", "1  Fists"], ["melee", p.gear["melee"], "2  Melee"], ["ranged", p.gear["ranged"], "3  Ranged"], ["armor", p.gear["armor"], "Armor"]]
	for c in carried:
		var id: String = c[1]
		var s := _slot(gear_row, "gear:" + c[0], big, Gear.display(id) if id != "" or c[0] == "armor" else "empty")
		s.kind = "gear"
		s.id = id
		s.on = id == hand and id != ""
		s.empty = id == "" and c[0] != "armor"
		s.tint = Gear.color(id) if id != "" else FAINT
		s.corner = c[2] if c[0] != "armor" else ""
		keys.append(s.get_meta("slot"))
	if not main.gear_here.is_empty():
		# Gear at your feet: set against what you carry in its slot.
		var fid: String = main.gear_here["id"]
		var fs := _slot(gear_row, "floor", big, "At your feet")
		fs.kind = "floor"
		fs.id = fid
		fs.tint = Gear.color(fid)
		keys.append("floor")

	_section("Items", left)
	var item_row := _slot_row(left)
	var sel: String = p.selected_item() if p != null else ""
	for id in Items.ORDER:
		var n: int = p.item_count(id) if p != null else 0
		var s := _slot(item_row, "item:" + id, big, Items.ITEMS[id]["short"])
		s.kind = "item"
		s.id = id
		s.count = n
		s.empty = n <= 0
		s.on = id == sel and n > 0
		keys.append(s.get_meta("slot"))

	_section("Heirlooms", left)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	var kept: Dictionary = main.profile.heirlooms
	for hs in Gear.HEIRLOOM_SLOTS:
		var id: String = kept.get(hs["id"], "")
		var s := _slot(grid, "heir:" + hs["id"], little, "" if compact() else hs["name"])
		s.kind = "heir"
		s.id = id
		s.slot_id = hs["id"]
		s.locked = hs.get("planned", false)
		s.empty = id == ""
		s.tint = Gear.color(id) if id != "" else FAINT
		keys.append(s.get_meta("slot"))

	var rune: String = p.camp_rune if p != null else ""
	if rune != "":
		_section("Camp rune", left)
		var rr := _slot_row(left)
		var s := _slot(rr, "rune", little, Items.CAMP_RUNES[rune]["name"].replace("Rune of ", ""))
		s.kind = "rune"
		s.id = rune
		s.tint = Items.CAMP_RUNES[rune]["color"]
		keys.append("rune")

	# The details of the focused slot.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), UI.SLOT_EDGE, 8, 1, 14.0))
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.custom_minimum_size.x = 260.0
	row.add_child(side)
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	side.add_child(details)
	if not (inv_sel in keys):
		inv_sel = "gear:" + _hand_slot(p)
	_show_details(inv_sel)
	_footer()


func _hand_slot(p) -> String:
	if p == null:
		return "melee"
	for k in ["melee", "ranged"]:
		if p.gear[k] == p.weapon:
			return k
	return "fists"


func _slot_row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	return r


## One slot: a square button with its icon drawn in code, and its name below.
func _slot(parent: Node, key: String, side: float, caption: String) -> Slot:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	parent.add_child(cell)
	var s := Slot.new()
	s.custom_minimum_size = Vector2(side, side)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.set_meta("slot", key)
	s.focus_entered.connect(_show_details.bind(key))
	s.mouse_entered.connect(_show_details.bind(key))
	s.pressed.connect(_slot_pressed.bind(key))
	cell.add_child(s)
	if caption == "":
		return s
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size.x = side + 14.0
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", DIM)
	cell.add_child(l)
	return s


## A tap or Enter on a slot shows it; on an item, a second press uses it.
func _slot_pressed(key: String) -> void:
	if key == inv_sel and key.begins_with("item:"):
		_use_item(key.substr(5))
		return
	_show_details(key)


func _show_details(key: String) -> void:
	if details == null or not is_instance_valid(details):
		return
	var changed := key != inv_sel or details.get_child_count() == 0
	inv_sel = key
	for s in box.find_children("*", "Button", true, false):
		if s is Slot:
			s.picked = s.get_meta("slot", "") == key
			s.queue_redraw()
	if not changed:
		return
	for c in details.get_children():
		details.remove_child(c)
		c.queue_free()
	var p = main.player
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	match kind:
		"gear":
			var id: String = "fists" if arg == "fists" else p.gear[arg]
			_detail_head("gear", id, Gear.display(id) if id != "" else "empty", Gear.color(id) if id != "" else DIM)
			var where: String = {"fists": "Slot 1: always with you", "melee": "Slot 2: your melee weapon", "ranged": "Slot 3: your ranged weapon", "armor": "Armor"}[arg]
			if id == p.weapon:
				where += "  ·  in hand"
			_detail_text(where, DIM)
			if id != "" or arg == "armor":
				_detail_stats(id, _compare_with(p, arg, id))
		"item":
			var n: int = p.item_count(arg)
			var data: Dictionary = Items.ITEMS[arg]
			_detail_head("item", arg, data["name"], Items.color(arg))
			_detail_text(String(data["desc"]).left(1).to_upper() + String(data["desc"]).substr(1) + ".", TEXT)
			_detail_text("Carrying %d of %d%s" % [n, Items.MAX_STACK, "  ·  your quick item" if arg == p.selected_item() and n > 0 else ""], DIM)
			var use := _button("Use", _use_item.bind(arg), details)
			use.disabled = n <= 0 or p.dead
			if n > 0 and arg != p.selected_item():
				_button("Make it your quick item", _pick_item.bind(arg), details)
		"heir":
			var id: String = main.profile.heirlooms.get(arg, "")
			var planned := false
			for hs in Gear.HEIRLOOM_SLOTS:
				if hs["id"] == arg:
					planned = hs.get("planned", false)
			var title := Gear.heirloom_slot_name(arg) + " heirloom"
			if planned:
				_detail_head("lock", "", title, DIM)
				_detail_text("Planned: for gear that doesn't exist yet.", DIM)
			elif id == "":
				_detail_head("heir", "", title, DIM)
				_detail_text("Empty. Survive a climb and you may keep the piece you carry here.", DIM)
			else:
				_detail_head("gear", id, Gear.display(id), Gear.color(id))
				_detail_text("%s heirloom: every climb begins with it." % Gear.heirloom_slot_name(arg), DIM)
				_detail_stats(id, "")
		"floor":
			var fid: String = main.gear_here.get("id", "")
			if fid == "":
				return
			var gslot := Gear.slot_of(fid)
			var held: String = p.gear.get(gslot, "")
			_detail_head("gear", fid, Gear.display(fid), Gear.color(fid))
			_detail_text("On the floor at your feet, for your %s slot." % Gear.SLOT_NAMES.get(gslot, gslot).to_lower(), DIM)
			_detail_stats(fid, held if held != "" else "-")
			var take := _button("Take it" + ("  (drops your %s)" % Gear.display(held) if held != "" else ""), _take_floor, details)
			take.disabled = p.dead
		"rune":
			var r: Dictionary = Items.CAMP_RUNES.get(p.camp_rune, {})
			_detail_head("rune", p.camp_rune, r.get("name", "Rune"), r.get("color", GOLD))
			_detail_text(String(r.get("desc", "")).left(1).to_upper() + String(r.get("desc", "")).substr(1) + ".", TEXT)
			_detail_text("Inscribed at a camp; it lasts the rest of this climb.", DIM)
	if toast != "":
		_detail_text(toast, GOLD)


## What to set a carried piece against: gear lying at your feet for the same
## slot, else what every climb starts with.
func _compare_with(p, slot: String, id: String) -> String:
	if not main.gear_here.is_empty() and Gear.slot_of(main.gear_here["id"]) == slot:
		return main.gear_here["id"]
	var start := {"melee": Weapons.START_MELEE, "ranged": Weapons.START_RANGED, "armor": ""}
	if start.has(slot) and start[slot] != id:
		return start[slot]
	return "-"


func _detail_head(kind: String, id: String, title: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	details.add_child(row)
	var icon := SlotIcon.new()
	icon.kind = kind
	icon.id = id
	icon.tint = col
	icon.custom_minimum_size = Vector2(48, 48)
	row.add_child(icon)
	var l := Label.new()
	l.text = title
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col.lightened(0.15))
	row.add_child(l)


func _detail_text(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 220.0
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	details.add_child(l)


## A piece's numbers; against `other` (if not "-"), better in green, worse in red.
func _detail_stats(id: String, other: String) -> void:
	var g := GridContainer.new()
	g.columns = 3 if other != "-" and other != "" else 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 2)
	details.add_child(g)
	var mine: Array = Gear.stats(id)
	var theirs: Array = Gear.stats(other) if g.columns == 3 else []
	if g.columns == 3:
		g.add_child(_label("", 0.0, DIM))
		g.add_child(_small_label("this", DIM))
		g.add_child(_small_label(Gear.display(other).to_lower(), DIM))
	for i in mine.size():
		var row: Array = mine[i]
		g.add_child(_small_label(row[0], TEXT))
		var col := TEXT
		if i < theirs.size() and theirs[i][0] == row[0]:
			var diff: float = float(row[2]) - float(theirs[i][2])
			if absf(diff) > 0.0001:
				col = UI.GOOD if (diff > 0.0) == bool(row[3]) else UI.BAD
		g.add_child(_small_label(row[1], col))
		if g.columns == 3:
			g.add_child(_small_label(theirs[i][1] if i < theirs.size() else "", DIM))


func _small_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	return l


func _use_item(id: String) -> void:
	var p = main.player
	if p == null or p.item_count(id) <= 0:
		return
	var before: String = p.item_sel
	p.item_sel = id
	if p.use_item():
		toast = "Used: %s" % Items.ITEMS[id]["name"]
	else:
		toast = "It would do nothing now."
		p.item_sel = before
	toast_t = 2.0
	open("inventory", opened_direct)


func _take_floor() -> void:
	if main.take_gear_here():
		inv_sel = "gear:" + _hand_slot(main.player)
	open("inventory", opened_direct)


func _pick_item(id: String) -> void:
	main.player.item_sel = id
	open("inventory", opened_direct)


# --- the dev tool ------------------------------------------------------------------

func _ask_new(back: String) -> void:
	confirm_back = back
	open("confirm_new")


func _page_confirm_new() -> void:
	_header("NEW CLIMBER?", "")
	_text("Start over with no marks. All your marks and their growth will be lost, and your heirlooms with them.", TEXT, true)
	_gap()
	var row := _grid(2)
	_button("Start over", _new_climber, row)
	_button("Cancel", open.bind(confirm_back), row)


func _page_dev() -> void:
	_header("DEV TOOLS", "For testing. Changes to marks are saved.")

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
	var brow := _grid(3, 6)
	for id in Towers.ORDER:
		if Towers.TOWERS[id].has("beast_kind"):
			_button(Towers.TOWERS[id]["short"], _dev_beast.bind(id), brow)

	_section("Spawn a monster")
	var grid := _grid(4, 6)
	for kind in EnemyScript.TYPES.keys().filter(func(k): return k != "familiar"):
		_button(kind.capitalize(), _dev_spawn.bind(kind), grid)

	_section("Gear (give yourself any weapon or armor)")
	var ggrid := _grid(4, 6)
	for id in Weapons.ORDER:
		if id != "fists":
			var gb := _button(Weapons.WEAPONS[id]["name"], _dev_gear.bind(id), ggrid)
			gb.disabled = id == p.gear["melee"] or id == p.gear["ranged"]
	for id in Gear.ARMOR_ORDER:
		var ab := _button(Gear.ARMOR[id]["name"], _dev_gear.bind(id), ggrid)
		ab.disabled = id == p.gear["armor"]

	_section("Cheats")
	var crow := _row()
	_button("No dying: %s" % ("on" if main.dev_no_death else "off"), _toggle_no_death, crow)
	_button("Heal", _heal, crow)
	_button("Clear the room", _clear_room, crow)
	if main.trap_view != null:
		_button("Show traps: %s" % ("on" if main.trap_view.show_all else "off"), _toggle_traps, crow)
	if toast != "":
		_text(toast, GOLD, true)
	_footer()


# --- actions -----------------------------------------------------------------

func _leave_title() -> void:
	Engine.set_meta("sixfold_title_seen", true)
	close()


func _restart() -> void:
	close()
	get_tree().reload_current_scene()


## Exit: back to the title screen (the climb is left where it is: the next
## Continue starts a new one).
func exit_to_title() -> void:
	if Engine.has_meta("sixfold_title_seen"):
		Engine.remove_meta("sixfold_title_seen")
	if main != null and get_tree().current_scene == main:
		close()
		get_tree().reload_current_scene()
	else:
		open("title")  # (tests run the room outside a scene: show the title at once)


func _quit_game() -> void:
	get_tree().quit()


func _new_climber() -> void:
	close()
	main.new_climber()


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
		main.hud.hud_scale = float(UI.HUD_SCALES.get(str(settings["hud_scale"]), 1.0))


func _set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	apply_settings()


# --- building blocks -----------------------------------------------------------

## A page's heading, a line under it, and a thin gold rule.
func _header(text: String, sub: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UI.SIZE_HEADING)
	l.add_theme_color_override("font_color", GOLD)
	if compact() and page != "title":
		# A phone: the heading and its line share one row.
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		l.add_theme_font_size_override("font_size", 22)
		row.add_child(l)
		if sub != "":
			var s := _label(sub, 0.0, DIM)
			s.add_theme_font_size_override("font_size", 12)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(s)
		_rule()
		return
	box.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size.x = 300.0
		s.add_theme_font_size_override("font_size", UI.SIZE_BODY)
		s.add_theme_color_override("font_color", DIM)
		box.add_child(s)
	_rule()


func _rule() -> void:
	var r := ColorRect.new()
	r.color = Color(GOLD, 0.18)
	r.custom_minimum_size.y = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)


## Tabs: a row of buttons, the current one gilded.
func _tabs(list: Array, current: String, choose: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	# Q and E (LB and RB) switch tabs too: their keys either side.
	var keys := ["", ""]
	if main != null and not main.touch_active:
		keys = [Controls.pad_name("lb", main.pad_ps), Controls.pad_name("rb", main.pad_ps)] if main.pad_active else ["Q", "E"]
	if keys[0] != "":
		row.add_child(_key_hint(keys[0]))
	for t in list:
		var b := _button(t[1], choose.bind(t[0]), row)
		b.custom_minimum_size = Vector2(120.0, 34.0) if compact() else Vector2(130.0, 38.0)
		b.set_meta("tab", t[0])
		if t[0] == current:
			_primary(b)
	if keys[1] != "":
		row.add_child(_key_hint(keys[1]))
	_gap(0 if compact() else 2)


func _key_hint(key: String) -> Label:
	var l := _label(key, 30.0, FAINT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## The gilded look of the main button on a page (or the current tab).
func _primary(b: Button) -> void:
	for state in ["normal", "hover"]:
		var st := UI.box(Color(0.24, 0.17, 0.09) if state == "normal" else Color(0.3, 0.22, 0.12), Color(GOLD, 0.7), 6)
		_button_margins(st)
		b.add_theme_stylebox_override(state, st)
	b.add_theme_color_override("font_color", GOLD)


## The bottom of a page: Back (or Close, for a screen opened by its key) and
## which key does the same.
func _footer() -> void:
	var pinned: bool = page in PINNED_FOOTER
	if not pinned:
		_gap(4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	(foot if pinned else box).add_child(row)
	var closing := _back_page() == "" and page != "mark"
	var prev: Button = null
	var next: Button = null
	if page == "mark":
		# A mark's page: the marks either side of it, and Back to the cards.
		var order := mark_order()
		var i := order.find(mark_part)
		prev = _button("<   " + _part_title(order[(i - 1 + order.size()) % order.size()]), _cycle.bind(-1), row)
	var b := _button("Close" if closing else "Back", go_back, row)
	b.custom_minimum_size.x = 150.0 if page == "mark" else 180.0
	b.set_meta("back", true)
	if page == "mark":
		var order := mark_order()
		var i := order.find(mark_part)
		next = _button(_part_title(order[(i + 1) % order.size()]) + "   >", _cycle.bind(1), row)
		for x in [prev, next]:
			x.custom_minimum_size.x = 150.0
			x.clip_text = true
			x.add_theme_color_override("font_color", DIM)
	var hint := ""
	if main != null and not main.touch_active:
		var key := "Esc"
		if page == "climber" and closing:
			key = "Tab / Esc"
		elif page == "inventory" and closing:
			key = "I / Esc"
		elif page == "mark":
			key = "Esc  ·  Q / E"
		hint = Controls.pad_text("{b}" + ("  ·  {lb} / {rb}" if page == "mark" else ""), main.pad_ps) if main.pad_active else key
	if hint != "":
		var l := _label(hint, 0.0, FAINT)
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


## A body part's mark by name (its bond), or the part itself if unmarked.
func _part_title(part: String) -> String:
	var info: Dictionary = main.profile.bonds.get(part, {})
	return Bonds.BONDS[info["id"]]["name"] if not info.is_empty() else Bonds.PART_NAMES[part]


func _section(text: String, parent: Node = null) -> void:
	var to: Node = parent if parent != null else box
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	to.add_child(gap)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(GOLD, 0.7))
	to.add_child(l)


func _text(text: String, color: Color, centered := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300.0
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	box.add_child(l)


## A smaller, dimmer paragraph.
func _note(text: String) -> void:
	_text(text, DIM)
	var l: Label = box.get_child(box.get_child_count() - 1)
	l.add_theme_font_size_override("font_size", UI.SIZE_BODY)


func _label(text: String, width: float, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_color_override("font_color", color)
	return l


## A name and a value, in a two-column grid.
func _pair(grid: GridContainer, name: String, value: String, col := TEXT) -> void:
	grid.add_child(_label(name, 130.0, DIM))
	grid.add_child(_label(value, 0.0, col))


func _gap(h := 6) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	box.add_child(c)


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	box.add_child(r)
	return r


func _grid(columns: int, gap := 8, vgap := -1) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap if vgap < 0 else vgap)
	box.add_child(g)
	return g


func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	if parent is GridContainer:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


static func _button_margins(s: StyleBoxFlat) -> void:
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", UI.menu_panel())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		s.anti_aliasing = true
		_button_margins(s)
		match state:
			"normal":
				s.bg_color = UI.BUTTON
				s.border_color = Color(1, 1, 1, 0.05)
				s.set_border_width_all(1)
			"hover":
				s.bg_color = UI.BUTTON_HOVER
				s.border_color = Color(GOLD, 0.25)
				s.set_border_width_all(1)
			"pressed":
				s.bg_color = UI.BUTTON_DOWN
			"focus":
				s.draw_center = false
				s.border_color = GOLD
				s.set_border_width_all(2)
				s.set_expand_margin_all(1)
			"disabled":
				s.bg_color = Color(UI.BUTTON, 0.5)
		t.set_stylebox(state, "Button", s)
		if state == "focus":
			# Keys and controller: the focused toggle or slider is outlined in gold too.
			t.set_stylebox("focus", "CheckButton", s)
			t.set_stylebox("focus", "HSlider", s)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_color("font_focus_color", "Button", Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_color", "Label", TEXT)
	return t


# --- drawn parts -----------------------------------------------------------------------

## An inventory slot: a square button with its icon drawn in code. The one
## in hand (or the quick item) is gilded; empty slots are dim; planned ones
## are locked.
class Slot extends Button:
	const Gear := preload("res://scripts/gear.gd")
	const Items := preload("res://scripts/items.gd")
	const UI := preload("res://scripts/ui.gd")

	var kind := ""  # gear, item, heir, rune or floor
	var id := ""
	var slot_id := ""  # heirlooms: the slot
	var on := false
	var picked := false  # its details are showing
	var empty := false
	var locked := false
	var count := -1
	var tint := Color.WHITE
	var corner := ""  # a small label in the top left (the weapon key)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		var normal := UI.slot(on)
		var hover := UI.slot(on)
		hover.bg_color = hover.bg_color.lightened(0.06)
		hover.border_color = UI.GOLD if on else Color(UI.GOLD, 0.45)
		if kind == "floor":
			normal.border_color = Color(UI.GOLD, 0.6)
			normal.set_border_width_all(1)
			normal.draw_center = true
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("disabled", normal)
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.border_color = UI.GOLD
		f.set_border_width_all(2)
		f.set_corner_radius_all(7)
		f.set_expand_margin_all(3)
		add_theme_stylebox_override("focus", f)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var c := size / 2.0
		var s := size.x * 0.33
		# A soft inner light behind what's in the slot, in its colour.
		if not empty and not locked:
			var b := UI.Draw.Batch.new()
			UI.glow_into(b, c, size.x * 0.46, tint if kind != "item" else Items.color(id), 0.7 if on else 0.45)
			b.flush(self)
		if picked:
			draw_rect(Rect2(Vector2(4, size.y - 4), Vector2(size.x - 8, 2)), Color(UI.GOLD, 0.85))
		if locked:
			UI.draw_lock(self, c, s * 0.7, Color(UI.FAINT, 0.8))
			return
		match kind:
			"gear", "heir", "floor":
				if id != "" or (kind == "gear" and not empty):
					Gear.draw_icon(self, id, c, s, tint if not empty else Color(tint, 0.3))
				else:
					draw_arc(c, s * 0.55, 0.0, TAU, 24, Color(UI.FAINT, 0.45), 1.5, true)
			"item":
				Items.draw_icon(self, id, c + Vector2(0, -1), s, 1.0 if count > 0 else 0.22)
				if count >= 0:
					var t := str(count)
					var fs := 14
					var at := Vector2(size.x - 6.0 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, size.y - 6.0)
					draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
					draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD if on else (UI.TEXT if count > 0 else UI.FAINT))
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
		if corner != "":
			draw_string(font, Vector2(5, 13), corner.get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOLD if on else UI.DIM)
		if on and kind == "item":
			draw_string(font, Vector2(5, size.y - 5.0), "quick", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.GOLD)
		if kind == "floor":
			draw_string(font, Vector2(5, 13), "new", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.GOLD)


## The big icon at the top of the inventory's details (and the record's heirlooms).
class SlotIcon extends Control:
	const Gear := preload("res://scripts/gear.gd")
	const Items := preload("res://scripts/items.gd")
	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var id := ""
	var tint := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.5
		var b := UI.Draw.Batch.new()
		b.dot(c, r, UI.OUTLINE)
		b.dot(c, r - 1.5, Color(0.11, 0.1, 0.14))
		if kind != "lock" and kind != "empty" and kind != "heir":
			UI.glow_into(b, c, r * 0.95, tint if kind != "item" else Items.color(id), 0.9)
		b.arc(c, r - 1.5, PI * 1.05, PI * 1.6, 10, Color(1, 1, 1, 0.12), 1.5)
		b.flush(self)
		var s := size.x * 0.33
		match kind:
			"gear":
				Gear.draw_icon(self, id, c, s, tint)
			"item":
				Items.draw_icon(self, id, c, s)
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
			"lock":
				UI.draw_lock(self, c, s * 0.7, UI.FAINT)
			_:
				draw_arc(c, s * 0.55, 0.0, TAU, 24, Color(UI.FAINT, 0.5), 1.5, true)


## The climber, drawn like the one in the tower (hooded, cloaked, outlined
## and shaded) but facing you, with each mark glowing on its body part in
## the bond's colour and a thin ring of the essence settled there. Unmarked
## parts are dark sockets; where the next mark is forming, a gold one.
class BodyView extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	const Palette := preload("res://scripts/palette.gd")
	var main

	const ORDER := ["brow", "throat", "heart", "back", "hand", "legs"]  # top to bottom, as on the body
	## Where each mark sits on the figure (it's about 290 tall, centred).
	const SPOTS := {
		"brow": Vector2(0, -110), "throat": Vector2(0, -77), "heart": Vector2(-11, -47),
		"back": Vector2(24, -36), "hand": Vector2(-50, 9), "legs": Vector2(-11, 62),
	}
	const LEFT := ["heart", "hand", "legs"]  # labelled on the left
	const LABEL_Y := {"brow": -124, "throat": -84, "back": -40, "heart": -52, "hand": 8, "legs": 62}

	func _process(_delta: float) -> void:
		queue_redraw()  # the marks glow and pulse

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var k := minf(size.y / 292.0, size.x / 316.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4.0 * k)
		var t := Time.get_ticks_msec() / 1000.0
		draw_set_transform(c, 0.0, Vector2(k, k))
		var b := UI.Draw.Batch.new()
		_backdrop(b)
		_figure(b)
		for part in ORDER:
			_mark(b, part, t)
		b.flush(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Names beside the marks, on leader lines.
		var prof = main.profile
		for part in ORDER:
			var info: Dictionary = prof.bonds.get(part, {})
			var side := -1.0 if part in LEFT else 1.0
			var at: Vector2 = c + SPOTS[part] * k
			var ly: float = c.y + float(LABEL_Y[part]) * k
			var col_x := c.x + side * 78.0 * k
			var line_col := Color(1, 1, 1, 0.16)
			draw_polyline(PackedVector2Array([at + Vector2(side * 9.0 * k, 0), Vector2(col_x - side * 6.0, ly), Vector2(col_x, ly)]), line_col, 1.0, true)
			var name: String = Bonds.PART_NAMES[part]
			var sub := "unmarked"
			var sub_col := UI.FAINT
			if not info.is_empty():
				var data: Dictionary = Bonds.BONDS[info["id"]]
				sub = data["name"]
				sub_col = data["color"] if not info.get("faint", false) else Color(data["color"], 0.6)
			elif main.player != null and prof.bonds.size() < 6 and main.leading_part() == part:
				sub = "forming"
				sub_col = Color(UI.GOLD, 0.8)
			if part == "back":
				name = "Back (behind)"
			var w1 := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var x1 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w1
			var x2 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w2
			draw_string_outline(font, Vector2(x1, ly + 4.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(x1, ly + 4.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.TEXT if not info.is_empty() else UI.DIM)
			draw_string(font, Vector2(x2, ly + 17.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sub_col)

	func _backdrop(b) -> void:
		for i in 6:
			b.dot(Vector2(0, -12), 150.0 - i * 20.0, Color(0.55, 0.5, 0.7, 0.022))
		b.polygon(UI._oval(Vector2(0, 126), Vector2(74, 12), 24), Color(0, 0, 0, 0.3))
		b.polygon(UI._oval(Vector2(0, 126), Vector2(48, 7), 24), Color(0, 0, 0, 0.3))

	static func _p(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, pts.size(), 2):
			out.append(Vector2(pts[i], pts[i + 1]))
		return out

	## The figure, in a frame about 290 tall centred on the waist. Lit from
	## the top-left: the left side of each piece is paler, the right darker.
	func _figure(b) -> void:
		var cloak := Palette.CLIMBER_CLOAK
		var tunic := Palette.CLIMBER_TUNIC
		var skin := Palette.CLIMBER_SKIN
		var boot := Palette.CLIMBER_BOOT
		var leather := Color(0.3, 0.2, 0.13)
		# The cloak hangs behind, from the shoulders to below the knees.
		b.poly(_p([-30, -68, 30, -68, 46, -20, 56, 40, 64, 100, 48, 108, 30, 104, 14, 110, 0, 104, -14, 110, -30, 104, -48, 108, -64, 100, -56, 40, -46, -20]), cloak.darkened(0.22), 1.6)
		b.polygon(_p([-30, -68, -6, -68, -10, 104, -30, 104, -48, 108, -64, 100, -56, 40, -46, -20]), cloak.darkened(0.04))
		b.polygon(_p([38, -36, 46, -20, 56, 40, 64, 100, 48, 108, 44, 40]), cloak.darkened(0.4))
		b.polygon(_p([-21, 10, 21, 10, 27, 104, 14, 110, 0, 104, -14, 110, -27, 104]), cloak.darkened(0.58))
		for f in [[-40, 18, -52, 100], [-27, 30, -33, 104], [32, 24, 40, 100], [46, 30, 56, 98]]:
			b.line(Vector2(f[0], f[1]), Vector2(f[2], f[3]), Color(cloak.darkened(0.5), 0.75), 1.8)
		b.line(Vector2(-58, 50), Vector2(-62, 98), Color(cloak.lightened(0.3), 0.35), 1.4)
		# Legs and boots.
		for sg in [-1.0, 1.0]:
			var shade := 0.22 if sg < 0.0 else 0.38
			b.poly(_p([sg * 3, 10, sg * 17, 10, sg * 16, 96, sg * 4, 96]), tunic.darkened(shade), 1.4)
			b.poly(_p([sg * 2.5, 92, sg * 17.5, 92, sg * 18, 110, sg * 22, 124, sg * 1, 124, sg * 2, 110]), boot if sg < 0.0 else boot.darkened(0.25), 1.4)
			b.rect(Rect2(Vector2(minf(sg * 2.5, sg * 17.5), 92), Vector2(15, 4)), boot.lightened(0.22))
			b.line(Vector2(sg * 4, 121), Vector2(sg * 15, 121), Color(boot.lightened(0.3), 0.5), 1.2)
		# The tunic, a skirt below the belt, and the belt.
		b.poly(_p([-27, -66, 27, -66, 24, -24, 21, 16, -21, 16, -24, -24]), tunic.darkened(0.14), 1.6)
		b.polygon(_p([-27, -66, 1, -66, 1, 16, -21, 16, -24, -24]), tunic)
		b.polygon(_p([-7, -66, 7, -66, 0, -40]), tunic.darkened(0.42))
		b.poly(_p([-21, 14, 21, 14, 26, 38, -26, 38]), tunic.darkened(0.16), 1.4)
		b.polygon(_p([-21, 14, 0, 14, 0, 38, -26, 38]), tunic.darkened(0.04))
		b.rect(Rect2(-23.4, 4.6, 46.8, 11.8), UI.OUTLINE)
		b.rect(Rect2(-22, 6, 44, 9), leather)
		b.rect(Rect2(-22, 6, 44, 2.4), leather.lightened(0.2))
		b.rect(Rect2(-5.4, 3.6, 10.8, 13.8), UI.OUTLINE)
		b.rect(Rect2(-4, 5, 8, 11), UI.GOLD.darkened(0.2))
		b.rect(Rect2(-1.6, 7.4, 3.2, 6.2), leather)
		# Arms in their sleeves, hands out of the cloak.
		for sg in [-1.0, 1.0]:
			var sh := Vector2(sg * 28, -60)
			var el := Vector2(sg * 40, -24)
			var wr := Vector2(sg * 48, 1)
			var col := tunic if sg < 0.0 else tunic.darkened(0.2)
			b.stroke(sh, el, col, 13.0)
			b.stroke(el, wr, col, 11.0)
			b.line(sh + Vector2(-3.5, 1), el + Vector2(-4, 0), Color(col.lightened(0.25), 0.6), 2.0)
			b.stroke(wr - (wr - el).normalized() * 2.0, wr + (wr - el).normalized() * 1.5, tunic.darkened(0.45), 12.0)
			b.ball(Vector2(sg * 50, 9), 6.8, skin if sg < 0.0 else skin.darkened(0.14))
		# The mantle over the shoulders.
		b.poly(_p([-42, -50, -34, -68, -14, -80, 14, -80, 34, -68, 42, -50, 30, -42, 14, -50, 0, -46, -14, -50, -30, -42]), cloak.darkened(0.14), 1.6)
		b.polygon(_p([-42, -50, -34, -68, -14, -80, 0, -80, 0, -46, -14, -50, -30, -42]), cloak.lightened(0.06))
		b.polygon(_p([-37, -60, -28, -71, -14, -77, -24, -66]), Color(cloak.lightened(0.45), 0.5))
		# The hood, the face in its shadow.
		b.poly(_p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141]), cloak.darkened(0.18), 1.6)
		b.polygon(_p([0, -147, -13, -141, -23, -127, -27, -106, -23, -88, -12, -79, 0, -77, -5, -112]), cloak.darkened(0.0))
		b.polygon(_p([-19, -131, -9, -141, -3, -140, -13, -127]), Color(cloak.lightened(0.45), 0.5))
		b.polygon(UI._oval(Vector2(0, -103), Vector2(14.5, 18.0), 24), Color(0.04, 0.03, 0.05))
		b.polygon(UI._oval(Vector2(0, -99), Vector2(10.5, 13.0), 24), skin.darkened(0.52))
		b.polygon(UI._oval(Vector2(-0.6, -94.5), Vector2(8.6, 8.0), 20), skin.darkened(0.3))
		b.polygon(_p([-12, -108, -6, -116, 4, -117, 12, -108, 5, -112, -3, -110]), Palette.CLIMBER_HAIR.darkened(0.3))
		b.dot(Vector2(-4.2, -100), 1.5, UI.OUTLINE)
		b.dot(Vector2(4.2, -100), 1.5, UI.OUTLINE)
		b.ball(Vector2(0, -77), 3.4, UI.GOLD.darkened(0.15))

	func _mark(b, part: String, t: float) -> void:
		var prof = main.profile
		var at: Vector2 = SPOTS[part]
		var info: Dictionary = prof.bonds.get(part, {})
		# The essence settled here: a thin ring, a share for each type.
		var pd: Dictionary = prof.part_density.get(part, {})
		var total := 0.0
		for e in pd:
			total += float(pd[e])
		if info.is_empty():
			var lead: bool = main.player != null and prof.bonds.size() < 6 and main.leading_part() == part
			if lead:
				UI.glow_into(b, at, 22.0, UI.GOLD, 0.7 + 0.4 * sin(t * 3.0))
			UI.socket_into(b, at, 5.5, main.soak_fraction(part) if lead else 0.0)
		else:
			var data: Dictionary = Bonds.BONDS[info["id"]]
			var col: Color = data["color"]
			var faint: bool = info.get("faint", false)
			var pulse := 0.75 + 0.25 * sin(t * 2.2 + at.y * 0.05)
			UI.glow_into(b, at, 30.0 * (0.7 if faint else 1.0), col, (0.9 if faint else 1.8) * pulse)
			b.dot(at, 9.4, Color(UI.OUTLINE, 0.9))
			b.dot(at, 8.0, col.darkened(0.7))
			UI.emblem_into(b, at, 6.4 if not faint else 5.0, data["affinity"], col.lightened(0.12 * pulse), 0.0)
		if total > 0.0:
			var a0 := -PI / 2.0
			for e in pd:
				var sweep := TAU * float(pd[e]) / total
				b.arc(at, 12.5, a0 + 0.06, a0 + sweep - 0.06, 10, Essence.color(e), 2.2)
				a0 += sweep


## One body part on the climber screen, as a button: its mark's medallion
## (filling toward the next step), bond, step and growth. Press it for the
## mark's page. Unmarked parts show what's forming there.
class MarkCard extends Button:
	const Bonds := preload("res://scripts/bonds.gd")
	const ProfileScript := preload("res://scripts/profile.gd")
	const UI := preload("res://scripts/ui.gd")
	var main
	var part := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		var info: Dictionary = main.profile.bonds.get(part, {})
		var edge := Color(Bonds.BONDS[info["id"]]["color"], 0.3) if not info.is_empty() else Color(1, 1, 1, 0.06)
		var normal := UI.box(Color(0.1, 0.093, 0.125, 0.96) if not info.is_empty() else Color(0.085, 0.08, 0.105, 0.9), edge, 8)
		var hover := UI.box(Color(0.15, 0.135, 0.18, 0.98), Color(UI.GOLD, 0.55), 8)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.border_color = UI.GOLD
		f.set_border_width_all(2)
		f.set_corner_radius_all(9)
		f.set_expand_margin_all(2)
		add_theme_stylebox_override("focus", f)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var info: Dictionary = prof.bonds.get(part, {})
		var h := size.y
		var r := clampf(h * 0.27, 16.0, 26.0)
		var mc := Vector2(14.0 + r, h * 0.5 - 2.0)
		var x := mc.x + r + 12.0
		var w := size.x - x - 22.0
		var tall := h >= 90.0
		var y := h * 0.5 - (34.0 if tall else 26.0)
		draw_string(font, Vector2(size.x - 16.0, h * 0.5 + 5.0), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.FAINT)
		var name: String = Bonds.PART_NAMES[part]
		if info.is_empty():
			var lead := ""
			if main.player != null and prof.bonds.size() < 6:
				lead = main.leading_part()
			var b := UI.Draw.Batch.new()
			UI.socket_into(b, mc, r * 0.78, main.soak_fraction(part) if lead == part else 0.0)
			b.flush(self)
			draw_string(font, Vector2(x, h * 0.5 - 4.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.DIM)
			if lead == part:
				draw_string(font, Vector2(x, h * 0.5 + 13.0), "your next mark is forming", HORIZONTAL_ALIGNMENT_LEFT, w + 10.0, 11, UI.GOLD)
			else:
				draw_string(font, Vector2(x, h * 0.5 + 13.0), "unmarked", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
			return
		var data: Dictionary = Bonds.BONDS[info["id"]]
		var col: Color = data["color"]
		var xp := float(info["xp"])
		var step := ProfileScript.step_for_xp(xp)
		var faint: bool = info.get("faint", false)
		var k := 1.0
		var grow := "highest step"
		if faint:
			k = 1.0 - clampf(float(info.get("debt", 0.0)) / ProfileScript.FAINT_DEBT, 0.0, 1.0)
			grow = "faint: %d more to grow" % int(ceil(float(info.get("debt", 0.0))))
		elif step < ProfileScript.STEP_XP.size():
			var lo: float = ProfileScript.STEP_XP[step - 1]
			var hi: float = ProfileScript.STEP_XP[step]
			k = clampf((xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
			grow = "%d / %d to step %d" % [int(xp - lo), int(hi - lo), step + 1]
		grow = _fit(font, grow, w, 11)
		UI.draw_medallion(self, mc, r, col, data["affinity"], k, step, 0.0, faint)
		draw_string(font, Vector2(x, y + 16.0), data["name"], HORIZONTAL_ALIGNMENT_LEFT, w, 16, col.lightened(0.12))
		var sub := "%s  ·  %s" % [name, "faint" if faint else "step %d" % step]
		draw_string(font, Vector2(x, y + 31.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 11, UI.DIM)
		UI.draw_bar(self, Rect2(Vector2(x, y + 38.0), Vector2(w, 6.0)), k, col)
		draw_string(font, Vector2(x, y + 57.0), grow, HORIZONTAL_ALIGNMENT_LEFT, w, 11, UI.FAINT if not faint else Color(UI.BAD, 0.85))
		if tall:
			var known: Array = data["spells"].filter(func(sp): return int(sp["learn"]) <= step).map(func(sp): return sp["name"])
			var line := "%d of %d spells: %s" % [known.size(), data["spells"].size(), ", ".join(known)]
			draw_string(font, Vector2(x, y + 75.0), _fit(font, line, w, 11), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)

	static func _fit(font: Font, t: String, w: float, fs: int) -> String:
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return t
		while t.length() > 3 and font.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			t = t.left(t.length() - 1)
		return t + "..."


## The top of a mark's page: its medallion large and glowing, its name, the
## body part and essence, growth toward the next step, and the five steps
## with the banked essence each needs.
class MarkHero extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const ProfileScript := preload("res://scripts/profile.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var main
	var part := ""

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var info: Dictionary = prof.bonds.get(part, {})
		var t := Time.get_ticks_msec() / 1000.0
		var h := size.y
		var r := minf(h * 0.34, 50.0)
		var mc := Vector2(r + 28.0, h * 0.5)
		var x := mc.x + r + 30.0
		var w := minf(size.x - x - 10.0, 420.0)
		if info.is_empty():
			var lead := ""
			if main.player != null and prof.bonds.size() < 6:
				lead = main.leading_part()
			var soak: float = main.soak_fraction(part)
			var b := UI.Draw.Batch.new()
			if lead == part:
				UI.glow_into(b, mc, r * 1.3, UI.GOLD, 0.6 + 0.3 * sin(t * 2.5))
			UI.socket_into(b, mc, r * 0.8, soak if lead == part else 0.0)
			b.flush(self)
			draw_string(font, Vector2(x, 40), Bonds.PART_NAMES[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.DIM)
			draw_string(font, Vector2(x, 62), "Unmarked  ·  cast key %s" % Bonds.PART_KEYS[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.FAINT)
			UI.draw_bar(self, Rect2(Vector2(x, 76), Vector2(w, 9)), soak, UI.GOLD)
			draw_string(font, Vector2(x, 104), "Soaked: %d%%%s" % [int(round(soak * 100.0)), "  ·  the next mark forms here" if lead == part else ""], HORIZONTAL_ALIGNMENT_LEFT, w, 12, UI.GOLD if lead == part else UI.DIM)
			return
		var data: Dictionary = Bonds.BONDS[info["id"]]
		var col: Color = data["color"]
		var xp := float(info["xp"])
		var step := ProfileScript.step_for_xp(xp)
		var faint: bool = info.get("faint", false)
		var k := 1.0
		var grow := "The highest step: every spell learned."
		if faint:
			k = 1.0 - clampf(float(info.get("debt", 0.0)) / ProfileScript.FAINT_DEBT, 0.0, 1.0)
			grow = "Faint: %d more essence before it grows" % int(ceil(float(info.get("debt", 0.0))))
		elif step < ProfileScript.STEP_XP.size():
			var lo: float = ProfileScript.STEP_XP[step - 1]
			var hi: float = ProfileScript.STEP_XP[step]
			k = clampf((xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
			grow = "%d / %d essence to step %d  (%d banked in all)" % [int(xp - lo), int(hi - lo), step + 1, int(xp)]
		var gb := UI.Draw.Batch.new()
		UI.glow_into(gb, mc, r * 1.3, col, (0.9 if faint else 1.6) * (0.8 + 0.2 * sin(t * 2.0)))
		gb.flush(self)
		UI.draw_medallion(self, mc, r, col, data["affinity"], k, step, 0.0, faint)
		draw_string_outline(font, Vector2(x, 40), data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(x, 40), data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col.lightened(0.15))
		var sub := "%s mark  ·  %s essence  ·  %s" % [Bonds.PART_NAMES[part], Essence.display(data["affinity"]), "faint" if faint else "step %d of 5" % step]
		draw_string(font, Vector2(x, 60), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)
		UI.draw_bar(self, Rect2(Vector2(x, 70), Vector2(w, 9)), k, col)
		draw_string(font, Vector2(x, 96), grow, HORIZONTAL_ALIGNMENT_LEFT, w, 12, Color(UI.BAD, 0.9) if faint else UI.TEXT)
		# The five steps and the banked essence each needs.
		var ly := h - 24.0
		var gap := w / 4.0
		var b := UI.Draw.Batch.new()
		b.rect(Rect2(Vector2(x, ly - 1.0), Vector2(w, 2.0)), Color(1, 1, 1, 0.08))
		b.rect(Rect2(Vector2(x, ly - 1.0), Vector2(gap * (step - 1), 2.0)), Color(col, 0.7))
		for s in 5:
			var p := Vector2(x + gap * s, ly)
			var reached := s + 1 <= step
			b.dot(p, 8.6, UI.OUTLINE)
			b.dot(p, 7.2, col.darkened(0.25) if reached else Color(0.13, 0.12, 0.16))
			if reached:
				b.dot(p + Vector2(-1.5, -1.5), 4.2, Color(col.lightened(0.3), 0.6))
			if s + 1 == step:
				b.arc(p, 10.6, 0.0, TAU, 24, UI.GOLD, 1.6)
		b.flush(self)
		for s in 5:
			var p := Vector2(x + gap * s, ly)
			draw_string(font, p + Vector2(-8, 4), str(s + 1), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, UI.OUTLINE if s + 1 <= step else UI.DIM)
			var need := "start" if s == 0 else "%d" % int(ProfileScript.STEP_XP[s])
			draw_string(font, p + Vector2(-30, 23), need, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, UI.FAINT)


## A spell's little badge on a mark's page: the mark's emblem, or a lock
## for one not learned yet.
class SpellIcon extends Control:
	const UI := preload("res://scripts/ui.gd")
	var col := Color.WHITE
	var affinity := ""
	var locked := false
	var index := 1

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.5 - 3.0
		if locked:
			var b := UI.Draw.Batch.new()
			b.dot(c, r + 1.6, UI.OUTLINE)
			b.dot(c, r, Color(0.1, 0.095, 0.13))
			b.arc(c, r - 2.0, 0.0, TAU, 28, Color(col, 0.25), 2.0)
			UI.lock_into(b, c, r * 0.62, Color(UI.FAINT, 0.95))
			b.flush(self)
		else:
			UI.draw_medallion(self, c, r, col, affinity, 1.0, 0, 0.35, false)


## The climber screen's Essence tab: each type's density and bonus (left),
## where it has settled in the body and what you carry unbanked (right).
class EssenceView extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	const KINDS := ["air", "blade", "stone", "iron", "fire", "water"]
	var main

	static func height(small: bool) -> float:
		return 230.0 if small else 300.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var small := size.y < 260.0
		var row_h := 32.0 if small else 42.0
		var left_w := floorf(size.x * 0.58)
		var b := UI.Draw.Batch.new()
		var texts: Array = []  # [pos, text, size, colour, align width]
		var head_col := Color(UI.GOLD, 0.7)
		texts.append([Vector2(0, 12), "DENSITY AND ATTRIBUTES", 12, head_col, -1.0])
		var y := 22.0
		for kind in KINDS:
			var attr: Dictionary = prof.ATTRIBUTES[kind]
			var col := Essence.color(kind)
			var bonus: float = prof.attribute(kind)
			var r := Rect2(Vector2(0, y), Vector2(left_w, row_h - 4.0))
			b.rect(r, Color(1, 1, 1, 0.025))
			b.rect(Rect2(r.position, Vector2(2.0, r.size.y)), Color(col, 0.6))
			var cy := y + (row_h - 4.0) * 0.5
			UI.gem_into(b, Vector2(18, cy), 7.5, col)
			texts.append([Vector2(34, cy + 5), Essence.display(kind), 15, col, -1.0])
			texts.append([Vector2(88, cy + 5), attr["name"], 13, UI.TEXT, -1.0])
			texts.append([Vector2(150, cy + 5), "%d" % int(prof.density.get(kind, 0.0)), 13, UI.DIM, 44.0])
			var bx := 206.0
			var bw := maxf(left_w - bx - 150.0, 60.0)
			UI.bar_into(b, Rect2(Vector2(bx, cy - 3.5), Vector2(bw, 7.0)), clampf(bonus / prof.ATTRIBUTE_CAP, 0.0, 1.0), col)
			var bt := "+%.1f%% %s" % [bonus * 100.0, attr["bonus"]]
			texts.append([Vector2(bx + bw + 10.0, cy + 5), bt, 12, UI.GOLD if bonus > 0.001 else UI.FAINT, -1.0])
			y += row_h
		# Right: settled in the body, and unbanked.
		var rx := left_w + 22.0
		var rw := size.x - rx
		texts.append([Vector2(rx, 12), "SETTLED IN YOUR BODY", 12, head_col, -1.0])
		var most := 1.0
		for part in Bonds.PARTS:
			most = maxf(most, _total(prof, part))
		var py := 26.0
		var step := 20.0 if small else 24.0
		for part in Bonds.PARTS:
			texts.append([Vector2(rx, py + 11), Bonds.PART_NAMES[part], 12, UI.TEXT if prof.bonds.has(part) else UI.DIM, -1.0])
			var bar := Rect2(Vector2(rx + 56, py + 3), Vector2(rw - 96.0, 8))
			UI.capsule(b, bar.position.x - 1.4, bar.end.x + 1.4, bar.get_center().y, 5.4, UI.OUTLINE)
			UI.capsule(b, bar.position.x, bar.end.x, bar.get_center().y, 4.0, Color(0.14, 0.13, 0.17))
			var pd: Dictionary = prof.part_density.get(part, {})
			var bx := bar.position.x
			for e in KINDS:
				var ww: float = bar.size.x * float(pd.get(e, 0.0)) / most
				if ww > 0.5:
					b.rect(Rect2(Vector2(bx, bar.position.y), Vector2(ww, bar.size.y)), Essence.color(e))
					b.rect(Rect2(Vector2(bx, bar.position.y), Vector2(ww, 3.0)), Color(Essence.color(e).lightened(0.4), 0.5))
					bx += ww
			texts.append([Vector2(bar.end.x + 4, py + 11), "%d" % int(_total(prof, part)), 12, UI.DIM, 34.0])
			py += step
		py += 10.0
		texts.append([Vector2(rx, py + 10), "UNBANKED THIS CLIMB", 12, head_col, -1.0])
		py += 30.0
		var x := rx
		var any := false
		for kind in KINDS:
			var amt: float = main.run_essence.get(kind, 0.0)
			if amt <= 0.0:
				continue
			any = true
			UI.gem_into(b, Vector2(x + 7, py - 4), 6.5, Essence.color(kind))
			texts.append([Vector2(x + 18, py + 1), "%d %s" % [int(amt), Essence.display(kind)], 13, UI.TEXT, -1.0])
			x += 92.0
			if x + 80.0 > size.x:
				x = rx
				py += 20.0
		b.flush(self)
		for tx in texts:
			if tx[4] > 0.0:
				draw_string(font, tx[0], tx[1], HORIZONTAL_ALIGNMENT_RIGHT, tx[4], tx[2], tx[3])
			else:
				draw_string(font, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tx[2], tx[3])
		if not any:
			draw_multiline_string(font, Vector2(rx, py + 1), "None yet: slain monsters leave essence; bank it at the stair.", HORIZONTAL_ALIGNMENT_LEFT, rw, 12, -1, UI.FAINT)
		else:
			draw_string(font, Vector2(rx, py + 22), "lost if you fall before the stair", HORIZONTAL_ALIGNMENT_LEFT, rw, 11, UI.FAINT)

	func _total(prof, part: String) -> float:
		var t := 0.0
		var pd: Dictionary = prof.part_density.get(part, {})
		for k in pd:
			t += float(pd[k])
		return t
