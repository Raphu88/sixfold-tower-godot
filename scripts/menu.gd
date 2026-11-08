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
	"dev": 660.0, "climber": 780.0, "inventory": 780.0}
## The climber screen's tabs: [id, name].
const CLIMBER_TABS := [["marks", "Marks"], ["essence", "Essence"], ["record", "Record"]]
## The mark cards' width on the climber page (page less the body view), for their first height.
const CARD_W_GUESS := 548.0

## Settings, kept between sessions (in the same file as the profile).
static var settings := {"music": 0.8, "sounds": 1.0, "shake": true, "help": false}
static var settings_loaded := false

var main
var page := ""  # "" when closed
var box: VBoxContainer  # the current page's contents
var panel: PanelContainer
var scroll: ScrollContainer
## Below the scroll area: Close/Back on the tall pages, so it's always on screen.
var foot: VBoxContainer
const PINNED_FOOTER := ["climber", "inventory"]
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
var climber_tab := "marks"
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
	_layout()


## Tab and I: open the climber screen or the inventory, or close it again.
func toggle(which: String) -> void:
	if page == which:
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
		var h := minf(_wanted_height(), s.y - 32.0)
		if page == "climber" or page == "inventory":
			h = minf(maxf(_wanted_height(), 560.0), s.y - 32.0) - FOOT_H  # (the same size on every tab; Close sits below)
		scroll.custom_minimum_size = Vector2(minf(float(WIDTHS.get(page, 560.0)), s.x - 32.0), h)


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
	if was_closed:
		# A short fade in.
		if fade != null:
			fade.kill()
		modulate.a = 0.0
		fade = create_tween()
		fade.tween_property(self, "modulate:a", 1.0, UI.FADE_IN)
	# The title's drawing stays behind the pages opened from it.
	backdrop.visible = which == "title" or (opened_from_title and which != "pause")
	backdrop.show_name = which == "title"
	shade.visible = which != "title"
	shade.color.a = 0.6 if backdrop.visible else UI.SHADE.a
	if which == "title":
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
		elif which == "inventory":
			first = maxi(0, list.map(func(b): return b.get_meta("slot", "")).find(inv_sel))
		list[keep if keep >= 0 and keep < list.size() else first].grab_focus.call_deferred()


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
	_footer()


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
	open("climber", opened_direct)


func _climber_line() -> String:
	var prof = main.profile
	var marks: int = prof.bonds.size()
	return "%d of 6 marks  ·  %d %s  ·  best floor %d" % [marks, prof.climbs, "climb" if prof.climbs == 1 else "climbs", prof.best_floor]


## Marks: the body with its marks, and a card for each body part.
func _climber_marks(prof) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var view := BodyView.new()
	view.main = main
	view.custom_minimum_size = Vector2(210, 300)
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(view)
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 6)
	row.add_child(cards)
	# Marked parts first (as on the body, top to bottom), then the rest.
	var order: Array = BodyView.ORDER.filter(func(pt): return prof.bonds.has(pt))
	order.append_array(BodyView.ORDER.filter(func(pt): return not prof.bonds.has(pt)))
	for part in order:
		var card := MarkCard.new()
		card.main = main
		card.part = part
		card.custom_minimum_size = Vector2(0, card.height_for(CARD_W_GUESS) if prof.bonds.has(part) else 30.0)
		cards.add_child(card)
	if prof.bonds.is_empty():
		_note("Your first climb is bondless. Reach the top and the tower's beast takes notice: the body part you used most takes your first mark.")
	else:
		_note("Bonds grow across climbs from the essence you bank at each stair, up to step 5. Each step makes a mark's spells stronger, and some steps teach a new one.")


## Essence: density by type (each is an attribute with a small bonus), where
## it has settled in the body, and what you carry unbanked this climb.
func _climber_essence(prof) -> void:
	var view := EssenceView.new()
	view.main = main
	view.custom_minimum_size = Vector2(0, EssenceView.HEIGHT)
	box.add_child(view)
	_note("Every bit of essence you bank at a stair settles in you as density, in the body parts that earned it. Each type gives a small passive bonus that grows ever slower, up to %d%%." % int(round(prof.ATTRIBUTE_CAP * 100.0)))


## Record: climbs, best floor, the climb you're on, and your heirlooms.
func _climber_record(prof) -> void:
	_section("This climb")
	var g := _grid(2, 24, 4)
	var t: Dictionary = main.tower_data()
	_pair(g, "Tower", t["name"], Essence.color(t["essence"]))
	_pair(g, "Floor", "%d" % main.floor_num)
	_pair(g, "Essence", "%s" % Essence.display(t["essence"]), Essence.color(t["essence"]))
	_pair(g, "Kind of climb", "the bondless first climb" if main.first_climb else "a climb with your marks")
	_section("Your record")
	var r := _grid(2, 24, 4)
	_pair(r, "Climbs", "%d" % prof.climbs)
	_pair(r, "Best floor", "%d" % prof.best_floor)
	_pair(r, "Marks", "%d of 6" % prof.bonds.size())
	if not prof.pacts.is_empty():
		_pair(r, "Pacts", "%d bound" % prof.pacts.size())
	_section("Heirlooms")
	var h := _grid(2, 24, 4)
	for s in Gear.HEIRLOOM_SLOTS:
		if s.get("planned", false):
			continue
		var id: String = prof.heirlooms.get(s["id"], "")
		_pair(h, s["name"], Gear.display(id) if id != "" else "none", Gear.color(id) if id != "" else DIM)
	_note("Survive a climb and you keep one piece you carried as an heirloom; every climb begins with them. The Inventory shows every slot, the planned ones too.")


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

	_section("Carried", left)
	var gear_row := _slot_row(left)
	var hand: String = p.weapon if p != null else ""
	var carried := [["fists", "fists", "1  Fists"], ["melee", p.gear["melee"], "2  Melee"], ["ranged", p.gear["ranged"], "3  Ranged"], ["armor", p.gear["armor"], "Armor"]]
	for c in carried:
		var id: String = c[1]
		var s := _slot(gear_row, "gear:" + c[0], 64.0, Gear.display(id) if id != "" or c[0] == "armor" else "empty")
		s.kind = "gear"
		s.id = id
		s.on = id == hand and id != ""
		s.empty = id == "" and c[0] != "armor"
		s.tint = Gear.color(id) if id != "" else FAINT
		s.corner = c[2] if c[0] != "armor" else ""
		keys.append(s.get_meta("slot"))

	_section("Items", left)
	var item_row := _slot_row(left)
	var sel: String = p.selected_item() if p != null else ""
	for id in Items.ORDER:
		var n: int = p.item_count(id) if p != null else 0
		var s := _slot(item_row, "item:" + id, 64.0, Items.ITEMS[id]["short"])
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
		var s := _slot(grid, "heir:" + hs["id"], 50.0, hs["name"])
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
		var s := _slot(rr, "rune", 50.0, Items.CAMP_RUNES[rune]["name"].replace("Rune of ", ""))
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
	for t in list:
		var b := _button(t[1], choose.bind(t[0]), row)
		b.custom_minimum_size.x = 130.0
		b.set_meta("tab", t[0])
		if t[0] == current:
			_primary(b)
	_gap(2)


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
	var closing := _back_page() == ""
	var b := _button("Close" if closing else "Back", go_back, row)
	b.custom_minimum_size.x = 180.0
	var hint := ""
	if main != null and not main.touch_active:
		var key := "Esc"
		if page == "climber" and closing:
			key = "Tab / Esc"
		elif page == "inventory" and closing:
			key = "I / Esc"
		hint = Controls.pad_text("{b}", main.pad_ps) if main.pad_active else key
	if hint != "":
		var l := _label(hint, 0.0, FAINT)
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


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

	var kind := ""  # gear, item, heir or rune
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
		var s := size.x * 0.3
		if picked:
			draw_rect(Rect2(Vector2(3, size.y - 4), Vector2(size.x - 6, 2)), Color(UI.GOLD, 0.8))
		if locked:
			UI.draw_lock(self, c, s * 0.8, Color(UI.FAINT, 0.8))
			return
		match kind:
			"gear", "heir":
				if id != "" or (kind == "gear" and not empty):
					Gear.draw_icon(self, id, c, s, tint if not empty else Color(tint, 0.3))
				else:
					draw_arc(c, s * 0.6, 0.0, TAU, 20, Color(UI.FAINT, 0.5), 1.5, true)
			"item":
				Items.draw_icon(self, id, c + Vector2(0, -1), s, 1.0 if count > 0 else 0.18)
				if count >= 0:
					var t := str(count)
					var at := Vector2(size.x - 6.0 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, size.y - 6.0)
					draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.9))
					draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.GOLD if on else (UI.TEXT if count > 0 else UI.FAINT))
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
		if corner != "":
			draw_string(font, Vector2(5, 13), corner.get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOLD if on else UI.DIM)


## The big icon at the top of the inventory's details.
class SlotIcon extends Control:
	const Gear := preload("res://scripts/gear.gd")
	const Items := preload("res://scripts/items.gd")

	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var id := ""
	var tint := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, size.x * 0.5, Color(tint, 0.1))
		var s := size.x * 0.34
		match kind:
			"gear":
				Gear.draw_icon(self, id, c, s, tint)
			"item":
				Items.draw_icon(self, id, c, s)
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
			"lock":
				UI.draw_lock(self, c, s * 0.8, UI.FAINT)
			_:
				draw_arc(c, s * 0.6, 0.0, TAU, 20, Color(UI.FAINT, 0.6), 1.5, true)


## A drawing of the climber's body: the six parts, each marked or not, with
## a ring of the essence settled in each.
class BodyView extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var main

	const ORDER := ["brow", "throat", "heart", "back", "hand", "legs"]  # top to bottom, as on the body
	const SPOTS := {
		"brow": Vector2(0, -96), "throat": Vector2(0, -64), "heart": Vector2(-10, -36),
		"hand": Vector2(-56, 4), "back": Vector2(14, -18), "legs": Vector2(-14, 66),
	}

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4)
		var skin := Color(0.25, 0.235, 0.29)
		var edge := Color(0.36, 0.34, 0.41)
		draw_circle(c, size.x * 0.46, Color(1, 1, 1, 0.02))
		# A simple figure: head, body, arms and legs.
		draw_line(c + Vector2(-22, -66), c + Vector2(-56, 4), skin, 11.0)
		draw_line(c + Vector2(22, -66), c + Vector2(56, 4), skin, 11.0)
		draw_line(c + Vector2(-12, 2), c + Vector2(-16, 92), skin, 13.0)
		draw_line(c + Vector2(12, 2), c + Vector2(16, 92), skin, 13.0)
		var torso := Rect2(c + Vector2(-24, -74), Vector2(48, 80))
		draw_rect(torso, skin)
		draw_rect(torso, edge, false, 1.0)
		draw_circle(c + Vector2(0, -98), 19.0, skin)
		draw_arc(c + Vector2(0, -98), 19.0, 0.0, TAU, 32, edge, 1.0, true)
		var prof = main.profile
		for part in ORDER:
			var at: Vector2 = c + SPOTS[part]
			var info: Dictionary = prof.bonds.get(part, {})
			var col := Color(0.55, 0.55, 0.6, 0.5)
			if not info.is_empty():
				col = Bonds.BONDS[info["id"]]["color"]
			# Settled essence: a ring per type, sized by its share.
			var pd: Dictionary = prof.part_density.get(part, {})
			var total := 0.0
			for k in pd:
				total += float(pd[k])
			var r := 7.0
			if total > 0.0:
				var a0 := -PI / 2.0
				for k in pd:
					var sweep := TAU * float(pd[k]) / total
					draw_arc(at, r + 4.0, a0, a0 + sweep, 16, Essence.color(k), 3.0, true)
					a0 += sweep
			if not info.is_empty():
				draw_circle(at, r + 2.0, Color(col, 0.25))
				draw_circle(at, r * (0.6 if info.get("faint", false) else 1.0), col)
			else:
				draw_arc(at, r * 0.7, 0.0, TAU, 16, col, 1.5, true)
			# Its name beside it, outward.
			var right: bool = SPOTS[part].x >= 0.0 and part != "heart"
			var name: String = Bonds.PART_NAMES[part]
			var lx := at.x + (18.0 if right else -18.0 - font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
			draw_string(font, Vector2(lx, at.y + 4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.GOLD if not info.is_empty() else UI.FAINT)


## One body part on the climber screen: its bond, step and growth, its
## spells (those still to learn dimmed), and its body and passive effects.
class MarkCard extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const ProfileScript := preload("res://scripts/profile.gd")

	const UI := preload("res://scripts/ui.gd")
	var main
	var part := ""

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var info: Dictionary = prof.bonds.get(part, {})
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 6), r)
		var name: String = Bonds.PART_NAMES[part]
		if info.is_empty():
			draw_arc(Vector2(18, size.y / 2.0), 5.0, 0.0, TAU, 14, UI.FAINT, 1.5, true)
			draw_string(font, Vector2(34, size.y / 2.0 + 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.DIM)
			var note := "unmarked"
			var leading := ""
			if main.player != null and main.profile.bonds.size() < 6:
				leading = main.leading_part()
			if leading == part:
				note = "unmarked  ·  your next mark is forming here"
			draw_string(font, Vector2(100, size.y / 2.0 + 5), note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 12, UI.GOLD if leading == part else UI.FAINT)
			return
		var data: Dictionary = Bonds.BONDS[info["id"]]
		var col: Color = data["color"]
		var xp := float(info["xp"])
		var step := ProfileScript.step_for_xp(xp)
		var faint: bool = info.get("faint", false)
		# The sigil: the cast key in a ring of the bond's colour.
		var sc := Vector2(26, 28)
		draw_circle(sc, 16.0, Color(0, 0, 0, 0.5))
		draw_arc(sc, 16.0, 0.0, TAU, 32, Color(col, 0.5 if faint else 1.0), 3.0, true)
		draw_string(font, sc + Vector2(-16, 5), Bonds.PART_KEYS[part], HORIZONTAL_ALIGNMENT_CENTER, 32, 14, col)
		var x := 54.0
		draw_string(font, Vector2(x, 22), data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col.lightened(0.1))
		var nw := font.get_string_size(data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var sub := "%s  ·  %s" % [name, "faint" if faint else "step %d" % step]
		draw_string(font, Vector2(x + nw + 10, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
		# Growth toward the next step.
		var bar := Rect2(Vector2(x, 31), Vector2(minf(size.x - x - 150.0, 260.0), 5))
		draw_rect(bar, Color(1, 1, 1, 0.08))
		var k := 1.0
		var grow := "highest step"
		if faint:
			k = 1.0 - clampf(float(info.get("debt", 0.0)) / ProfileScript.FAINT_DEBT, 0.0, 1.0)
			grow = "%d essence more before it grows" % int(ceil(float(info.get("debt", 0.0))))
		elif step < ProfileScript.STEP_XP.size():
			var lo: float = ProfileScript.STEP_XP[step - 1]
			var hi: float = ProfileScript.STEP_XP[step]
			k = clampf((xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
			grow = "%d / %d to step %d" % [int(xp - lo), int(hi - lo), step + 1]
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(col, 0.6 if faint else 0.95))
		draw_string(font, Vector2(bar.end.x + 10, 37), grow, HORIZONTAL_ALIGNMENT_LEFT, size.x - bar.end.x - 16, 11, UI.DIM)
		# Spells: known ones bright, the rest dim with the step that teaches them.
		var sx := x
		draw_string(font, Vector2(sx, 60), "Spells", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
		sx += 44.0
		for sp in data["spells"]:
			var known := int(sp["learn"]) <= step
			var t: String = sp["name"] if known else "%s (step %d)" % [sp["name"], int(sp["learn"])]
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if sx + w > size.x - 8.0:
				break
			draw_string(font, Vector2(sx, 60), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT if known else UI.FAINT)
			sx += w + 14.0
		# Body and passive wrap onto more lines (the card grows to fit them).
		var tw := size.x - x - 52.0
		var by := 80.0
		var body_t := "%s: %s" % [data["body"]["name"], data["body"]["desc"]]
		draw_string(font, Vector2(x, by), "Body", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
		draw_multiline_string(font, Vector2(x + 44, by), body_t, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, -1, UI.DIM)
		by += _text_h(font, body_t, tw) + 3.0
		var pas_t := "%s: %s" % [data["passive"]["name"], data["passive"]["desc"]]
		draw_string(font, Vector2(x, by), "Passive", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
		draw_multiline_string(font, Vector2(x + 44, by), pas_t, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, -1, UI.DIM)

	## How tall the card must be at a width, for its wrapped text.
	func height_for(w: float) -> float:
		var info: Dictionary = main.profile.bonds.get(part, {})
		if info.is_empty():
			return 30.0
		var data: Dictionary = Bonds.BONDS[info["id"]]
		var font := ThemeDB.fallback_font
		var tw := w - 54.0 - 52.0
		var body_t := "%s: %s" % [data["body"]["name"], data["body"]["desc"]]
		var pas_t := "%s: %s" % [data["passive"]["name"], data["passive"]["desc"]]
		return ceilf(80.0 + _text_h(font, body_t, tw) + 3.0 + _text_h(font, pas_t, tw) + 8.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and main != null:
			var want := height_for(size.x)
			if absf(custom_minimum_size.y - want) > 1.0:
				custom_minimum_size.y = want

	static func _text_h(font: Font, t: String, w: float) -> float:
		return font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, 12).y


## The climber screen's Essence tab: each type's density and bonus, where
## it has settled in the body, and what you carry unbanked.
class EssenceView extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const Essence := preload("res://scripts/essence.gd")

	const UI := preload("res://scripts/ui.gd")
	const KINDS := ["air", "blade", "stone", "iron", "fire", "water"]
	const HEIGHT := 380.0
	var main

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var y := 6.0
		draw_string(font, Vector2(0, y + 10), "DENSITY AND ATTRIBUTES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.GOLD, 0.7))
		y += 22.0
		for kind in KINDS:
			var attr: Dictionary = prof.ATTRIBUTES[kind]
			var col := Essence.color(kind)
			var bonus: float = prof.attribute(kind)
			var r := Rect2(Vector2(0, y), Vector2(size.x, 30))
			draw_style_box(UI.box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.05), 5), r)
			draw_circle(Vector2(16, y + 15), 6.0, col)
			draw_string(font, Vector2(30, y + 20), Essence.display(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
			draw_string(font, Vector2(100, y + 20), attr["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT)
			draw_string(font, Vector2(190, y + 20), "%d" % int(prof.density.get(kind, 0.0)), HORIZONTAL_ALIGNMENT_RIGHT, 50, 14, UI.TEXT)
			var bar := Rect2(Vector2(260, y + 12), Vector2(maxf(size.x - 520.0, 120.0), 6))
			draw_rect(bar, Color(1, 1, 1, 0.07))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(bonus / prof.ATTRIBUTE_CAP, 0.0, 1.0), bar.size.y)), col)
			var t := "+%.1f%% %s" % [bonus * 100.0, attr["bonus"]]
			draw_string(font, Vector2(bar.end.x + 14, y + 20), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - bar.end.x - 18, 13, UI.GOLD if bonus > 0.001 else UI.FAINT)
			y += 34.0
		y += 10.0
		draw_string(font, Vector2(0, y + 10), "SETTLED IN YOUR BODY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.GOLD, 0.7))
		y += 20.0
		var most := 1.0
		for part in Bonds.PARTS:
			most = maxf(most, _total(prof, part))
		var colw := (size.x - 20.0) / 2.0
		for i in Bonds.PARTS.size():
			var part: String = Bonds.PARTS[i]
			var px := (i % 2) * (colw + 20.0)
			var py := y + (i / 2) * 22.0
			draw_string(font, Vector2(px, py + 12), Bonds.PART_NAMES[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT if prof.bonds.has(part) else UI.DIM)
			var bar := Rect2(Vector2(px + 64, py + 4), Vector2(colw - 120.0, 8))
			draw_rect(bar, Color(1, 1, 1, 0.06))
			var pd: Dictionary = prof.part_density.get(part, {})
			var bx := bar.position.x
			for k in KINDS:
				var w: float = bar.size.x * float(pd.get(k, 0.0)) / most
				if w > 0.0:
					draw_rect(Rect2(Vector2(bx, bar.position.y), Vector2(w, bar.size.y)), Essence.color(k))
					bx += w
			draw_string(font, Vector2(bar.end.x + 6, py + 12), "%d" % int(_total(prof, part)), HORIZONTAL_ALIGNMENT_RIGHT, 44, 12, UI.DIM)
		y += 3 * 22.0 + 14.0
		draw_string(font, Vector2(0, y + 10), "UNBANKED THIS CLIMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.GOLD, 0.7))
		y += 26.0
		var x := 0.0
		var any := false
		for kind in KINDS:
			var amt: float = main.run_essence.get(kind, 0.0)
			if amt <= 0.0:
				continue
			any = true
			draw_circle(Vector2(x + 6, y - 4), 5.0, Essence.color(kind))
			draw_string(font, Vector2(x + 16, y + 1), "%d %s" % [int(amt), Essence.display(kind)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT)
			x += 110.0
		if not any:
			draw_string(font, Vector2(0, y + 1), "None yet: slain monsters leave essence; bank it at the stair.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.FAINT)
		else:
			draw_string(font, Vector2(x + 6, y + 1), "lost if you fall before the stair", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.FAINT)

	func _total(prof, part: String) -> float:
		var t := 0.0
		var pd: Dictionary = prof.part_density.get(part, {})
		for k in pd:
			t += float(pd[k])
		return t
