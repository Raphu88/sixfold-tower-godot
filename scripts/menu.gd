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
const SecretPage := preload("res://scripts/secret_page.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const Train := preload("res://scripts/train.gd")
const TrainPage := preload("res://scripts/train_page.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Secret := preload("res://scripts/secret.gd")
const Appearance := preload("res://scripts/appearance.gd")
const AppearancePage := preload("res://scripts/appearance_page.gd")
const Makers := preload("res://scripts/makers.gd")
const Unbound := preload("res://scripts/unbound.gd")
const TechniquePage := preload("res://scripts/technique_page.gd")
const ClimbersPage := preload("res://scripts/climbers_page.gd")
const Slots := preload("res://scripts/slots.gd")
const RailScript := preload("res://scripts/rail.gd")

const GOLD := UI.GOLD
const TEXT := UI.TEXT
const DIM := UI.DIM
const FAINT := UI.FAINT
const SETTINGS_PATH := "user://sixfold.cfg"

## How wide each page's panel is (it shrinks to fit a small screen).
const WIDTHS := {"pause": 440.0, "settings": 520.0, "controls": 660.0, "confirm_new": 440.0,
	"dev": 660.0, "climber": 800.0, "inventory": 800.0, "mark": 800.0, "train": 860.0,
	"create": 960.0, "appearance": 960.0, "techniques": 720.0, "climbers": 860.0}
## The climber screen's tabs: [id, name].
const CLIMBER_TABS := [["marks", "Marks"], ["essence", "Essence"], ["record", "Record"], ["archive", "Archive"]]
## Below this screen height (a phone, drawn 1.5x) the pages tighten up to fit.
const COMPACT_H := 600.0

## Settings, kept between sessions (in the settings file, shared by every climber: slots.gd).
## "condense": the share of banked essence that condenses into crystals at a
## stair, in percent (train.gd CONDENSE_CHOICES).
static var settings := {"music": 0.8, "sounds": 1.0, "shake": true, "help": false, "hud_scale": "normal", "climber_tab": "marks", "lighting": "",
	"condense": Train.CONDENSE_DEFAULT}
static var settings_loaded := false

var main
var page := ""  # "" when closed
var box: VBoxContainer  # the current page's contents
var panel: PanelContainer
var scroll: ScrollContainer
## Below the scroll area: Close/Back on the tall pages, so it's always on screen.
var foot: VBoxContainer
const PINNED_FOOTER := ["climber", "inventory", "mark", "train"]
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
var inv_view := "worn"  # the inventory's doll: what you wear ("worn") or your "heirlooms"
var details: VBoxContainer  # the inventory's details pane
var archive_open := ""  # the Archive entry shown open (a tip id)
# The train (train_view.gd draws its cars; train_page.gd puts their things in them).
var train_view: Control
var train_page  # builds the train's cars (train_page.gd)
var train_car := Train.HOME  # the car you're in
var train_sel := {}  # car -> the slot whose card shows there
var train_store := "shop"  # the store car: its shelves ("shop") or selling ("sell")
var train_bench := "brew"  # the workshop car's counter (bench.gd)
var train_tower := ""  # the engine: the tower chosen for the next climb
var bench_pick := 0  # Retrait: which of a piece's traits to replace
var sell_ask := ""  # a piece asked to be sold: a second press sells it
var train_say := ""  # the outfitter's (or the Entity's) answer to the last choice
# The appearance editor (appearance_page.gd): "create" for a new climber,
# "appearance" later; where Back from "appearance" goes ("climber", else the usual).
var look_page
var look_from := ""
# The left rail (rail.gd) the in-game pages share: who you are, the pages,
# Start over and Exit. RAIL_PAGES show it; RAIL_ROOTS are the pages it
# opens (the others are pages within them: a mark, controller setup, the
# Start over question).
var rail
const RAIL_PAGES := ["pause", "climber", "mark", "inventory", "settings", "padsetup", "controls", "dev", "confirm_new"]
const RAIL_ROOTS := ["pause", "climber", "inventory", "settings", "controls", "dev"]
var climber_main := "marks"  # the climber screen's last tab other than the Archive
var nav_keys := false  # the last thing pressed was a key or the controller (not a click or tap)
var _rail_focus := false  # after building the page, put the focus back on the rail
var _focus_now: Control = null  # what has the keys' focus (to tell a step onto the rail from the page)
var _rail_grab := false  # the menu itself is moving the focus onto the rail
var _rail_refused := false  # a step from the page onto the rail, other than Left, was turned back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	backdrop = TitleScript.new()
	backdrop.hide()
	add_child(backdrop)
	train_view = TrainView.new()
	train_view.hide()
	add_child(train_view)
	train_page = TrainPage.new(self)
	look_page = AppearancePage.new(self, func(b, lk): BodyView._figure(b, lk))
	shade = ColorRect.new()
	shade.color = UI.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	rail = RailScript.new()
	rail.menu = self
	rail.hide()
	add_child(rail)
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
	get_viewport().gui_focus_changed.connect(func(_c): if page != "" and main != null: main.sfx("ui_move"))
	get_viewport().gui_focus_changed.connect(_focus_changed)
	load_settings()
	if CLIMBER_TABS.any(func(t): return t[0] == settings["climber_tab"]) or settings["climber_tab"] == SecretPage.TAB[0]:
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
	if event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		nav_keys = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		nav_keys = false
	if page == "" or _typing():
		return
	# Q and E (LB and RB): the climber screen's tabs, or the next mark.
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Q or event.keycode == KEY_E):
		if _cycle(1 if event.keycode == KEY_E else -1):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.device == Controls.PAD_DEVICE and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		if _cycle(1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1):
			get_viewport().set_input_as_handled()
		return
	# The train: swipes, drags, the wheel and Left / Right move along it (train_page.gd).
	if page == "train":
		if train_page.input(event):
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
	if rail.visible:
		for c in rail.find_children("*", cls, true, false):
			var ctl: Control = c
			if ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
				found = ctl
	return found


func _tap(pos: Vector2) -> void:
	var b = _control_at(pos, "BaseButton")
	if b == null and _control_at(pos, "LineEdit") != null and page in ["create", "appearance"]:
		look_page.edit_name()  # (the appearance page's name)
		return
	if b == null or b.disabled:
		return
	if b.has_method("tap_at"):
		b.tap_at(pos)  # (an option row: its arrows and swatches)
	elif b.toggle_mode:
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
	if _typing():
		# Typing a name: the keys are letters, not shortcuts (Esc leaves the field).
		if Input.is_action_just_pressed("ui_cancel"):
			look_page._focus_rows()
		_layout()
		return
	if page == "create":
		pass  # a new climber's look: only Begin leaves it (like the title)
	elif Input.is_action_just_pressed("pause"):
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


## A name is being typed (the appearance page's name field has the keys).
func _typing() -> bool:
	return page != "" and is_inside_tree() and get_viewport().gui_get_focus_owner() is LineEdit


## Q/E or LB/RB: the next climber tab, or the next mark on the detail page.
## True if it did something.
func _cycle(by: int) -> bool:
	if page == "train":
		return train_page.cycle(by)
	if page == "create" or page == "appearance":
		look_page.turn(by)  # the preview turns
		return true
	if page == "climber":
		var ids: Array = climber_tabs().map(func(t): return t[0])
		_set_climber_tab(ids[(ids.find(climber_tab) + by + ids.size()) % ids.size()])
		return true
	if page == "mark":
		var order := mark_order()
		open_mark(order[(order.find(mark_part) + by + order.size()) % order.size()])
		return true
	return false


## Tab and I: open the climber screen or the inventory, or close it again.
func toggle(which: String) -> void:
	if which == "inventory" and _on_train():
		# On the train, I (the Bag) opens your car: your heirlooms and chest.
		if page == "train" and train_car == Train.HOME:
			return
		if page == "train":
			train_page.go_to(train_page._index(Train.HOME))
		elif page == "" or page == "climber" or page == "inventory":
			train_car = Train.HOME
			open("train")
		return
	if page == "create":
		return
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
	if main != null and page != "": main.sfx("ui_back")
	if page in RAIL_ROOTS and rail_showing():
		# In a page: back to the rail. On the rail (or a page opened by its
		# own key, or on a phone): close.
		var f := get_viewport().gui_get_focus_owner()
		if opened_direct or f == null or rail.has_focus_inside() or (main != null and main.touch_active):
			close()
		else:
			rail.focus_current()
		return
	if page == "train":
		open("pause")  # (the train has no Back: Esc opens the menu)
	elif page == "confirm_new":
		open(confirm_back)
	elif page == "padsetup":
		open("settings")
	elif page == "mark":
		focus_part = mark_part
		open("climber", opened_direct)
	elif page == "create":
		return  # (Begin is the way on)
	elif page == "appearance" and look_from == "climber":
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
	if _on_train():
		return "train"
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
		# The rail down the left (in-game pages); the page sits in the rest.
		var rw := 0.0
		if rail.visible:
			rw = RailScript.width_for(compact())
			rail.position = Vector2.ZERO
			rail.size = Vector2(rw, s.y)
		center.position = Vector2(rw, 0)
		center.size = Vector2(s.x - rw, s.y)
		var edge := 12.0 if compact() else 32.0  # space kept around the panel
		var pad := 24.0 if compact() else 44.0  # the panel's own margins
		var h := minf(_wanted_height(), s.y - edge - pad)
		if page in PINNED_FOOTER:
			# The same size on every tab (Close or Back below, if there is one).
			var fh := FOOT_H if foot.get_child_count() > 0 else 0.0
			h = minf(maxf(_wanted_height(), 520.0 - fh), s.y - edge - pad - fh)
		scroll.custom_minimum_size = Vector2(minf(float(WIDTHS.get(page, 560.0)), s.x - rw - edge - pad), h)
		panel.pivot_offset = panel.size * 0.5


## Between climbs, on the train (main.gd on_train).
func _on_train() -> bool:
	return main != null and main.on_train


## The rail shows on the in-game pages (not on the title or pages opened from it).
func rail_showing() -> bool:
	return page in RAIL_PAGES and not opened_from_title and main != null and main.profile != null


## The rail's item lit for the page showing.
func rail_item() -> String:
	match page:
		"pause":
			return "resume"
		"climber", "mark":
			return "archive" if climber_tab == "archive" and page == "climber" else "climber"
		"padsetup":
			return "settings"
		"confirm_new":
			return "over"
	return page


## Keys and controller: from the page, only Left steps onto the rail (up
## and down stay in the page, even where the rail is the nearest thing).
func _focus_changed(c: Control) -> void:
	var before := _focus_now
	_focus_now = c
	_rail_refused = false
	if page == "" or not rail.visible or _rail_grab or not nav_keys or c == null or not rail.buttons.has(c):
		return
	if before == null or not is_instance_valid(before) or rail.buttons.has(before) or not before.is_visible_in_tree():
		return
	if Input.is_action_pressed("ui_left"):
		return
	# Up or down found the rail nearer than the page's next thing: go on
	# within the page instead (or stay put at its end).
	_rail_refused = true
	var dir := 1 if Input.is_action_pressed("ui_down") else (-1 if Input.is_action_pressed("ui_up") else 0)
	var to: Control = _next_in_page(before, dir) if dir != 0 else null
	if to == null:
		to = before
	(func(): if is_instance_valid(to) and to.is_visible_in_tree(): to.grab_focus()).call_deferred()


## The page's nearest focusable control above (dir -1) or below (dir 1) one, or null.
func _next_in_page(from: Control, dir: int) -> Control:
	var fr := from.get_global_rect()
	var best: Control = null
	var best_d := INF
	for c in focusables():
		if c == from or not c.is_visible_in_tree() or c.focus_mode == Control.FOCUS_NONE:
			continue
		var r: Rect2 = c.get_global_rect()
		var dy := (r.get_center().y - fr.get_center().y) * dir
		if dy <= 4.0:
			continue
		var d := dy + absf(r.get_center().x - fr.get_center().x) * 2.0
		if d < best_d:
			best_d = d
			best = c
	return best


## Keys and controller moved onto a rail item: show its page as you pass
## (the focus stays on the rail). Clicks and taps press instead.
func rail_focused(id: String) -> void:
	if _rail_refused:
		return
	if not nav_keys or page == "" or id == rail_item() or id in ["over", "exit"]:
		return
	if id == "inventory" and _on_train():
		return  # (your car is on the train itself: only a press goes there)
	_rail_focus = true
	_rail_go(id, true)


## A rail item pressed (Enter, A, a click or a tap): its page, and into it.
func rail_pressed(id: String) -> void:
	if id == rail_item() and id in ["climber", "inventory", "archive", "settings", "controls", "dev"]:
		_focus_page_start()
		return
	_rail_focus = false
	_rail_go(id, false)


func _rail_go(id: String, preview: bool) -> void:
	opened_direct = false
	match id:
		"resume":
			if preview:
				open("pause")
			else:
				close()
		"climber":
			if climber_tab == "archive":
				climber_tab = climber_main
			open("climber")
		"archive":
			open_archive()
		"inventory":
			if _on_train():
				train_car = Train.HOME  # (your car: your chest and heirlooms)
				open("train")
			else:
				open("inventory")
		"settings", "controls", "dev":
			open(id)
		"over":
			_ask_new("pause" if page == "confirm_new" else (page if page in RAIL_ROOTS else "pause"))
		"exit":
			exit_to_title()


## Keys and controller: onto the page's starting point (from the rail).
func _focus_page_start() -> void:
	var list := focusables()
	if list.is_empty():
		return
	var i := _first_focus(page, list)
	if i >= 0 and i < list.size():
		list[i].grab_focus()
		if main != null: main.sfx("ui_confirm")


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
	train_page.was_open = page == "train" and which == "train"  # (a new car slides into view)
	# Rebuilding the same page (a dev button, a toast): keep the focus where it was.
	var keep := -1
	var on_rail: bool = _rail_focus or (which == page and rail.visible and rail.has_focus_inside())
	_rail_focus = false
	if which == page and is_inside_tree():
		keep = focusables().find(get_viewport().gui_get_focus_owner())
	if was_closed:
		opened_from_title = which == "title"
		opened_direct = direct
	elif which == "title":
		opened_from_title = true
		opened_direct = false
	elif which == "pause" or which == "train":
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
	backdrop.visible = which == "title" or which == "create" or (opened_from_title and which != "pause")
	backdrop.show_name = which == "title"
	# The train is its own page (its cars fill the screen), and stands behind
	# the pages opened from it.
	train_view.visible = _on_train() and not backdrop.visible
	center.visible = which != "train"
	shade.visible = which != "title" and which != "train"
	shade.color.a = 0.6 if backdrop.visible else (0.62 if train_view.visible else UI.SHADE.a)
	if which == "pause" and was_closed:
		on_rail = true  # (the pause menu starts on the rail, on Resume)
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
	if keep < 0 or which == "mark":
		scroll.scroll_vertical = 0  # (another mark starts at its top)
	if main != null and which != "title" and keep < 0: main.sfx(("ui_bag" if which == "inventory" else "ui_open") if was_closed else "ui_confirm")
	call("_page_" + which)
	var list := focusables()
	var first := _first_focus(which, list) if not list.is_empty() else -1
	focus_part = ""  # (used once: back from a mark's page, on its card)
	rail.visible = rail_showing()
	if rail.visible:
		rail.refresh(rail_item(), _on_train(), compact(), main.touch_active, main.pad_active, main.pad_ps)
		_link_rail(list[first] if first >= 0 else null)
	_layout()
	# Keyboard and controller: start on the first button (or slider), or the
	# page's own starting point; or stay on the rail.
	if rail.visible and (on_rail or list.is_empty()):
		rail.focus_current.call_deferred()
		return
	if not list.is_empty():
		var at: int = keep if keep >= 0 and keep < list.size() else first
		if which == "train":
			# (never onto another slot than the one whose card shows; on a
			# phone, nothing: there's no focus to show)
			if list[at].get_meta("slot", inv_sel) != inv_sel:
				at = first
			if main != null and main.touch_active:
				at = -1
		if at >= 0:
			_focus_later.call_deferred(list[at])


## Right from the rail goes into the page (its starting point).
func _link_rail(target: Control) -> void:
	for b in rail.buttons:
		b.focus_neighbor_right = b.get_path_to(target) if target != null else b.get_path_to(b)


## Where the keys start on a page: the first button, or the page's own
## starting point.
func _first_focus(which: String, list: Array) -> int:
	var first := 0
	if true:
		if which == "climber":
			first = maxi(0, climber_tabs().map(func(t): return t[0]).find(climber_tab))
			if focus_part != "":
				# Back from a mark's page: on its card again.
				first = maxi(first, list.map(func(b): return b.get_meta("part", "")).find(focus_part))
		elif which == "mark":
			first = maxi(0, list.map(func(b): return b.get_meta("back", false)).find(true))
		elif which == "inventory":
			first = maxi(0, list.map(func(b): return b.get_meta("slot", "")).find(inv_sel))
		elif which == "train":
			first = train_page.first_focus(list)
		elif which == "create" or which == "appearance":
			first = maxi(0, list.find(look_page.first_focus))
		elif which == "climbers":
			# (on the current climber's card)
			first = maxi(0, list.map(func(b): return b.get_meta("climber_slot", 0)).find(Slots.current()))
	return first


## Focus a control next frame, if the page it's on is still showing.
func _focus_later(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and not c.is_queued_for_deletion():
		c.grab_focus()


func close() -> void:
	if page == "":
		return
	if _on_train():
		# Between climbs, closing a page returns to the train; only departing
		# for a tower (main.gd depart) leaves it.
		if page != "train":
			open("train")
		return
	if main != null: main.sfx("ui_close")
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


## The page's buttons and sliders, top to bottom (on the train: the car you're in).
func focusables() -> Array:
	if page == "train":
		return train_page.focusables()
	var list: Array = []
	_collect_focus(box, list)
	_collect_focus(foot, list)
	return list


func _collect_focus(n: Node, list: Array) -> void:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is BaseButton or c is HSlider:
			if not c.has_meta("close"):  # (a page's Close: Esc does the same, so the keys skip it)
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
	if Slots.any():
		# The climber picker (climbers_page.gd), naming the current climber.
		var cb := _button(ClimbersPage.button_text(prof, Slots.current()), open.bind("climbers"))
		cb.set_meta("climbers", true)
		_title_button(cb)
	_title_button(_button("Settings", open.bind("settings")))
	_title_button(_button("Dev tools", open.bind("dev")))
	if prof.regarded:
		_title_button(_button(ClimbersPage.TEXT["over"], _ask_new.bind("title")))
	_gap(2)
	_text(_title_status(), DIM, true)
	var l: Label = box.get_child(box.get_child_count() - 1)
	l.add_theme_font_size_override("font_size", 15)
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


## The title's buttons: see-through violet over the sky, edged in gilt;
## the first one gilded (Grenze Gotisch, like the old title's main button).
func _title_button(b: Button, primary := false) -> void:
	b.custom_minimum_size.y = 42.0 if primary else 36.0
	b.add_theme_font_size_override("font_size", 22 if primary else 18)
	for state in ["normal", "hover", "pressed"]:
		var st: StyleBox
		if primary:
			st = UI.primary_box("hover" if state == "hover" else "normal")
		else:
			var o := UI.Ornate.new()
			o.radius = 6.0
			o.highlight = true
			o.top = Color(0.16, 0.14, 0.21, 0.82 if state == "normal" else 0.92)
			o.bottom = Color(0.08, 0.07, 0.11, 0.82 if state == "normal" else 0.92)
			o.edge = Color(GOLD, 0.24 if state == "normal" else 0.55)
			if state == "pressed":
				o.top = Color(UI.BUTTON_DOWN, 0.95)
				o.bottom = Color(UI.BUTTON_DOWN, 0.95)
			_button_margins(o)
			st = o
		b.add_theme_stylebox_override(state, st)
	if primary:
		b.add_theme_font_override("font", UI.font("display"))
		b.add_theme_color_override("font_color", UI.GILT_HI)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.75))
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.93, 0.75))


## The pause menu: the rail's home page. The climb you're on (the tower,
## the floor, what you've gathered and your marks), and Restart this climb
## (and Quit game on a computer). Resume, the other pages, Start over and
## Exit are on the rail.
func _page_pause() -> void:
	if _on_train():
		_header(Train.TEXT["title"], "", "Menu")
	else:
		_header("Paused", "", "%s  ·  floor %d" % [main.tower_data()["name"], main.floor_num])
	var g := _grid(2, 10, 4 if compact() else 6)
	if _on_train():
		var nt: Dictionary = Towers.TOWERS.get(train_tower, {})
		if not nt.is_empty():
			_pair(g, "Next climb", nt["name"], Essence.color(nt["essence"]).lerp(TEXT, 0.25))
	else:
		var t: Dictionary = main.tower_data()
		_pair(g, "Tower", t["name"], Essence.color(t["essence"]).lerp(TEXT, 0.25))
		_pair(g, "Floor", "%d   (best %d)" % [main.floor_num, main.profile.best_floor])
		var gathered: Array = []
		for k in main.run_essence:
			if float(main.run_essence[k]) >= 1.0:
				gathered.append("%d %s" % [int(main.run_essence[k]), Essence.display(k)])
		_pair(g, "Unbanked", ",  ".join(gathered) if not gathered.is_empty() else "nothing yet", TEXT if not gathered.is_empty() else FAINT)
	var marks: Array = []
	for part in mark_order():
		if main.profile.bonds.has(part):
			var info: Dictionary = main.profile.bonds[part]
			marks.append("%s %d" % [Bonds.BONDS[info["id"]]["name"], ProfileScript.step_for_xp(float(info["xp"]))])
	_pair(g, "Marks", ",  ".join(marks) if not marks.is_empty() else "none yet", TEXT if not marks.is_empty() else FAINT)
	_gap(4)
	var row := _grid(2)
	if not _on_train():
		_button("Restart this climb", _restart, row)
	if can_quit():
		_button("Quit game", _quit_game, row)
	if row.get_child_count() == 0:
		row.queue_free()


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
	_header("Settings", "", "Menu")
	_entity_says("settings")
	_slider("Music", "music")
	_slider("Sounds", "sounds")
	_toggle("Screen shake", "shake")
	_toggle("Controls list on screen (H)", "help")
	_choice("HUD size", "hud_scale", [["small", "Small"], ["normal", "Normal"], ["large", "Large"]])
	_choice("Lighting", "lighting", [["low", "Low"], ["medium", "Medium"], ["high", "High"]])
	_choice(Train.TEXT["condense_setting"], "condense", Train.CONDENSE_CHOICES)
	_note(Train.TEXT["condense_note"])
	_guide_settings()
	_pad_settings()
	_footer()


# --- controller setup (pad_setup.gd) ---

func _pad_settings() -> void:
	var PadSetup = load("res://scripts/pad_setup.gd")
	_button(PadSetup.TEXT["settings_button"], open.bind("padsetup")).set_meta("setting", "padsetup")


## Settings -> Controller setup: records a controller's layout (pad_setup.gd).
func _page_padsetup() -> void:
	var PadSetup = load("res://scripts/pad_setup.gd")
	_header(PadSetup.TEXT["title"], "")
	var setup = PadSetup.new()
	setup.main = main
	setup.menu = self
	box.add_child(setup)
	_footer()


## A row of buttons for a setting with a few values; the current one gilded.
func _choice(text: String, key: String, values: Array) -> void:
	var row := _row()
	row.add_child(UI.style_label(_label(text, 120.0), "display", 18, TEXT))
	for v in values:
		var b := _button(v[1], func():
			_set_setting(key, v[0])
			open(page), row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("choice", v[0])
		b.set_meta("choice_key", key)
		if str(settings[key]) == v[0]:
			_primary(b)


func _page_controls() -> void:
	_header("Controls", "", "Menu")
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
			if i == 0:
				UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW, Color(GOLD, 0.75))  # (the columns' heads)
			elif c == 0:
				UI.style_label(l, "display", 17, TEXT)  # (the action's name: a label)
			else:
				UI.style_label(l, "mono", 13, GOLD)  # (keys and buttons)
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
	var who: String = prof.appearance.get("name", "")
	_header(who if who != "" else "Climber", _climber_line(), "Climber")
	var tabs := climber_tabs()
	_tabs(tabs, climber_tab if tabs.any(func(t): return t[0] == climber_tab) else "marks", _set_climber_tab)
	match climber_tab if tabs.any(func(t): return t[0] == climber_tab) else "marks":
		"core":
			SecretPage.build(self)
		"essence":
			_climber_essence(prof)
		"record":
			_climber_record(prof)
		"archive":
			_climber_archive()
		_:
			_climber_marks(prof)
	_footer()


## The climber screen's tabs: a secret bond adds its Core tab (secret_page.gd).
func climber_tabs() -> Array:
	var tabs: Array = CLIMBER_TABS.duplicate()
	if main != null and main.profile != null and main.SecretBonds.has_bond(main.profile):
		tabs.append(SecretPage.TAB)
	return tabs


func _set_climber_tab(id: String) -> void:
	climber_tab = id
	if id != "archive":
		climber_main = id
	if settings["climber_tab"] != id:
		settings["climber_tab"] = id  # remembered for next time
		save_settings()
	open("climber", opened_direct)


func _climber_line() -> String:
	var prof = main.profile
	if Unbound.is_on(prof):
		return TechniquePage.climber_line(prof)  # (the Unbound: their stage)
	var marks: int = prof.bonds.size()
	var line := "%d of 6 marks  ·  %d %s  ·  best floor %d" % [marks, prof.climbs, "climb" if prof.climbs == 1 else "climbs", prof.best_floor]
	var wound: String = main.proving.wound_text() if main.proving != null else ""  # (the Proving's lingering wound)
	return line + ("  ·  " + wound if wound != "" else "")


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
	# The figure, and Appearance under it (appearance_page.gd).
	var fig := VBoxContainer.new()
	fig.add_theme_constant_override("separation", 4)
	row.add_child(fig)
	var view := BodyView.new()
	view.main = main
	view.custom_minimum_size = Vector2(292, 0) if small else Vector2(310, 0)
	fig.add_child(view)
	var look_b := _button(Appearance.TEXT["button"], open_appearance.bind("climber"), fig)
	look_b.custom_minimum_size.y = 40.0
	look_b.set_meta("appearance", true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	if Unbound.is_on(prof):
		TechniquePage.climber(self, grid)  # (the Unbound: each part's raw density, level and gift)
	for part in (mark_order() if not Unbound.is_on(prof) else []):
		var card := MarkCard.new()
		card.main = main
		card.part = part
		card.set_meta("part", part)
		card.custom_minimum_size = Vector2(0, 76.0 if small else 104.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(open_mark.bind(part))
		grid.add_child(card)
	view.custom_minimum_size.y = (76.0 if small else 104.0) * 3.0 + 16.0 - 44.0
	var core_line: String = Makers.core_text(prof)
	if core_line != "":
		_text(core_line, Makers.core_color(prof).lightened(0.2), true)  # (a secret bond: makers.gd)
	if small:
		return
	if Unbound.is_on(prof):
		_note(TechniquePage.TEXT["climber_note"])
	elif prof.bonds.is_empty():
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
	# Your path's flow (secret.gd), in your shadow: only a faint sign before
	# its first step.
	if prof.path != "":
		var fv := FlowView.new()
		fv.main = main
		fv.custom_minimum_size = Vector2(0, FlowView.height(prof.flow_step(), compact()))
		box.add_child(fv)
	if not compact():
		_note("Every bit of essence you bank at a stair settles in you as density, in the body parts that earned it. Each type gives a small passive bonus that grows ever slower, up to %d%%." % int(round(prof.ATTRIBUTE_CAP * 100.0)))


## Record: the climb you're on and your record on the left, your heirlooms
## on the right.
func _climber_record(prof) -> void:
	_entity_says("record", Entity.TEXT["record_title"].to_upper())
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
	if compact():
		r.columns = 4  # (a phone: two to a row, so the tab fits)
	_pair(r, "Climbs", "%d" % prof.climbs)
	_pair(r, "Best floor", "%d" % prof.best_floor)
	_pair(r, "Marks", "%d of 6" % prof.bonds.size())
	if not prof.pacts.is_empty():
		_pair(r, "Pacts", "%d bound" % prof.pacts.size())
	_record_counts(prof, r, left)
	_section("Heirlooms", right)
	# Only the slots holding one (there are eleven), two to a row.
	var hg := GridContainer.new()
	hg.columns = 2
	hg.add_theme_constant_override("h_separation", 16)
	hg.add_theme_constant_override("v_separation", 4)
	right.add_child(hg)
	var kept_n := 0
	for hs in Gear.HEIRLOOM_SLOTS:
		for hg_rec in Gear.heirloom_pieces(prof.heirlooms, hs["id"]):
			kept_n += 1
			var hr := HBoxContainer.new()
			hr.add_theme_constant_override("separation", 8)
			hg.add_child(hr)
			var icon := SlotIcon.new()
			icon.kind = "gear"
			icon.id = Gear.base_id(hg_rec)
			icon.rec = hg_rec
			icon.tint = Gear.color(hg_rec)
			icon.custom_minimum_size = Vector2(32, 32)
			hr.add_child(icon)
			var names := VBoxContainer.new()
			names.add_theme_constant_override("separation", -2)
			names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hr.add_child(names)
			names.add_child(_small_label(hs["name"], DIM))
			names.add_child(_label(Gear.display(hg_rec), 0.0, Gear.color(hg_rec).lightened(0.1)))
	if kept_n == 0:
		right.add_child(_label("none yet", 0.0, FAINT))
	_record_towers(prof, right)
	var note := Label.new()
	note.text = "Survive a climb and you keep one piece you wore as an heirloom (or both your rings); every climb begins with them. The Inventory's Heirlooms view shows every slot."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 200.0
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", FAINT)
	right.add_child(note)


# --- the Entity: the Archive, the record, settings -----------------------------------

## The Entity's face and a line (entity.gd LINES) at the top of a page. The
## line stays the same while you're on this floor of this climb.
func _entity_says(key: String, heading := "") -> void:
	var seed: int = 0 if main == null else main.floor_num + main.profile.climbs * 7
	# (Just after a choice here, it answers that instead.)
	var said := Entity.says(toast if toast != "" else Entity.line(key, seed), 34.0 if compact() else 44.0, heading)
	said.set_meta("entity", key)
	box.add_child(said)
	_gap(0 if compact() else 2)


## The pause menu's Archive: the climber screen on its Archive tab.
func open_archive() -> void:
	climber_tab = "archive"
	open("climber")


## The Archive: everything the Entity has told you, by subject. Each entry
## is a button; choose it to read the Entity's line and a fuller account.
## Subjects not met yet show as ???.
func _climber_archive() -> void:
	# (the Makers' tips count only once heard: before then nothing hints at them)
	var listed: Array = Entity.TIPS.keys().filter(func(k): return Entity.TIPS[k]["group"] != "forbidden" or Guide.known(k))
	var total := listed.size()
	var heard: int = listed.filter(func(k): return Guide.known(k)).size()
	_entity_says("archive", "%s  ·  %s" % [Entity.TEXT["tag"], Entity.TEXT["heard"] % [heard, total]])
	var mode := "keys"
	if main != null and main.touch_active:
		mode = "touch"
	elif main != null and main.pad_active:
		mode = "pad"
	var ps: bool = main != null and main.pad_ps
	for g in Entity.GROUPS:
		var ids: Array = Entity.ordered(g[0])
		# What you've met first, then the rest as ???.
		ids = ids.filter(func(k): return Guide.known(k)) + ids.filter(func(k): return not Guide.known(k))
		_section(g[1])
		var grid := _grid(2, 6, 4)
		for id in ids:
			if not Guide.known(id):
				var l := _label(Entity.TEXT["locked"], 0.0, FAINT)
				l.custom_minimum_size.y = 32.0
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				var st := UI.box(Color(UI.VOID, 0.45), Color(UI.LINE, 0.6), 6)
				st.content_margin_left = 14.0
				l.add_theme_stylebox_override("normal", st)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.set_meta("archive_locked", id)
				grid.add_child(l)
				continue
			var e: Dictionary = Entity.TIPS[id]
			var b := _button(("v  " if archive_open == id else ">  ") + e["name"], _archive_toggle.bind(id), grid)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 32.0
			b.set_meta("archive", id)
			if archive_open == id:
				_primary(b)
		if archive_open != "" and archive_open in ids:
			var e: Dictionary = Entity.TIPS[archive_open]
			var said := Entity.says(Entity.fill_keys(e["tip"], mode, ps), 30.0, String(e["name"]).to_upper())
			said.set_meta("archive_open", archive_open)
			box.add_child(said)
			_rich(Entity.fill_keys(e["more"], mode, ps), UI.SIZE_BODY, DIM)
	_maker_shelves(mode, ps)
	_gap(4)
	var row := _grid(2)
	_button(Entity.TEXT["replay"], _replay_tips, row)
	var tog := CheckButton.new()
	tog.text = "Guide tips"
	tog.button_pressed = Guide.tips_on()
	tog.custom_minimum_size.y = 38
	tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tog.toggled.connect(_set_tips)
	row.add_child(tog)


## The forbidden shelf (makers.gd): a shelf for each Maker whose first
## fragment you've found (or that you've met), with its fragments (their
## words redacted) and how many; then the Entity's tips about them. Nothing
## shows before then. The Entity speaks of its siblings (redacted) only once
## you've met one.
func _maker_shelves(mode: String, ps: bool) -> void:
	var prof = main.profile
	var shown: Array = Makers.ORDER.filter(func(m): return Makers.shelf_shown(prof, m))
	if shown.is_empty():
		return
	_section(Makers.TEXT["shelf"])
	var st: Dictionary = Makers.state(prof)
	var met_any: bool = Makers.has_met(prof)
	var c: Dictionary = Makers.core(prof)
	for m in shown:
		var d: Dictionary = Makers.MAKERS[m]
		var col: Color = d["color"]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.box(Color(col.darkened(0.88), 0.7), Color(col, 0.35), 6, 1, 10.0))
		pc.set_meta("shelf", m)
		box.add_child(pc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		pc.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		v.add_child(head)
		var icon := Makers.SignIcon.new()
		icon.maker = m
		icon.custom_minimum_size = Vector2(30, 30)
		head.add_child(icon)
		var frags: Array = st["fragments"].filter(func(f): return f.get("maker", "") == m)
		var title := UI.style_label(_label(d["Name"], 0.0, col.lightened(0.2)), "display", 19, col.lightened(0.2))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(_label(Makers.TEXT["shelf_count"] % [frags.size(), "fragment" if frags.size() == 1 else "fragments"], 0.0, DIM))
		if met_any:
			v.add_child(_entity_redacted(d["entity"][0]))
		var words: Array = d["fragments"]
		for i in frags.size():
			var f: Dictionary = frags[i]
			var tw: String = Towers.TOWERS.get(f.get("tower", ""), {}).get("short", String(f.get("tower", "")).capitalize())
			v.add_child(_small_label(Makers.TEXT["fragment_where"] % [i + 1, tw, int(f.get("floor", 0))], FAINT))
			var r := Makers.Redacted.new()
			r.text = words[int(f.get("n", i)) % words.size()]
			r.color = Color(col.lightened(0.1), 0.8)
			r.font_size = 15.0  # (an inscription: the fine italic)
			r.set_meta("fragment_text", r.text)
			v.add_child(r)
		var bits: Array = []
		var met := int(st["met"].get(m, 0))
		var turned := int(st["turned"].get(m, 0))
		if met > 0:
			bits.append(Makers.TEXT["met"] % [met, "time" if met == 1 else "times"])
		if turned > 0:
			bits.append(Makers.TEXT["turned"] % [turned, "time" if turned == 1 else "times"])
		if c.get("maker", "") == m:
			bits.append(Makers.TEXT["core"] % [Makers.SECRET_BONDS[c["bond"]]["name"], int(c.get("depth", 1))])
		if not bits.is_empty():
			v.add_child(_small_label("  ·  ".join(bits), DIM))
	# The Entity's tips about them (fragments, glimpses, meetings, the core mark).
	var known: Array = Entity.ordered("forbidden").filter(func(k): return Guide.known(k))
	if known.is_empty():
		return
	var grid := _grid(2, 6, 4)
	for id in known:
		var b := _button(("v  " if archive_open == id else ">  ") + Entity.TIPS[id]["name"], _archive_toggle.bind(id), grid)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 32.0
		b.set_meta("archive", id)
		if archive_open == id:
			_primary(b)
	if archive_open in known:
		var e: Dictionary = Entity.TIPS[archive_open]
		var said := Entity.says(Entity.fill_keys(e["tip"], mode, ps), 30.0, String(e["name"]).to_upper())
		said.set_meta("archive_open", archive_open)
		box.add_child(said)
		_rich(Entity.fill_keys(e["more"], mode, ps), UI.SIZE_BODY, DIM)


## The Entity speaking of a sibling: its face and a bubble of redacted words.
func _entity_redacted(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := Entity.Face.new()
	f.custom_minimum_size = Vector2(40, 30)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(f)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.entity_bubble(8.0))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bubble)
	var r := Makers.Redacted.new()
	r.text = text
	r.color = Color(Entity.GLOW, 0.8)
	r.font_size = 15.0
	bubble.add_child(r)
	row.set_meta("entity_sibling", text)
	return row


func _archive_toggle(id: String) -> void:
	archive_open = "" if archive_open == id else id
	open("climber", opened_direct)


## Settings: the Entity's tips on or off, and Replay.
func _guide_settings() -> void:
	var tog := CheckButton.new()
	tog.text = Entity.TEXT["tips_setting"]
	tog.button_pressed = Guide.tips_on()
	tog.custom_minimum_size.y = 38
	tog.toggled.connect(_set_tips)
	tog.set_meta("setting", "tips")
	box.add_child(tog)
	_button(Entity.TEXT["replay"], _replay_tips)


func _set_tips(on: bool) -> void:
	Guide.set_on(on)
	_say(Entity.line("tips_on" if on else "tips_off"))


func _replay_tips() -> void:
	Guide.replay()
	if not Guide.tips_on():
		Guide.set_on(true)
	_say(Entity.line("replay"))


## The record's counters (profile.gd record), under "Your record".
func _record_counts(prof, grid: GridContainer, _parent: Node) -> void:
	_pair(grid, "Floors climbed", "%d" % prof.count("floors"))
	_pair(grid, "Monsters slain", "%d" % prof.count("slain"))
	_pair(grid, "Beasts slain", "%d" % prof.count("beasts"))
	_pair(grid, "Falls", "%d" % prof.count("deaths"))
	_pair(grid, "Puzzles solved", "%d" % prof.count("puzzles"))
	_pair(grid, "Essence banked", "%d" % prof.count("essence"))
	_pair(grid, "Heirlooms kept", "%d" % prof.count("heirlooms"))
	if prof.count("falls") > 0:
		_pair(grid, "Fell through chasms", "%d" % prof.count("falls"))
	if prof.former > 0:
		_pair(grid, "Climbers before you", "%d" % prof.former, Entity.GLOW)


## Best floor and beasts slain in each tower.
func _record_towers(prof, parent: Node) -> void:
	_section("By tower", parent)
	var g := _grid_in(parent)
	var best: Dictionary = prof.record.get("best", {})
	var by: Dictionary = prof.record.get("beasts_by", {})
	for id in Towers.ORDER:
		var t: Dictionary = Towers.TOWERS[id]
		var b := int(best.get(id, 0))
		var text := "not climbed" if b == 0 else "best floor %d" % b
		if int(by.get(id, 0)) > 0:
			text += "  ·  beast slain" + (" x%d" % int(by[id]) if int(by[id]) > 1 else "")
		_pair(g, t["short"], text, Essence.color(t["essence"]) if b > 0 else FAINT)


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
	pc.add_theme_stylebox_override("panel", UI.card(Color(col, 0.55), false, 10.0))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_stretch_ratio = 1.0
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	pc.add_child(v)
	var t := _small_label(title, Color(GOLD, 0.7))
	UI.style_label(t, "eyebrow", UI.SIZE_EYEBROW, Color(GOLD, 0.75))
	v.add_child(t)
	var n := _label(eff["name"], 0.0, col.lightened(0.15))
	UI.style_label(n, "display", 21, col.lightened(0.15))
	v.add_child(n)
	var d := Label.new()
	d.text = _sentence(eff["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 160.0
	d.add_theme_font_size_override("font_size", 15)
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
	var st := UI.card(Color(col, 0.7) if known else Color(0, 0, 0, 0), known, 10.0)
	if not known:
		st.top = Color(0.085, 0.076, 0.11, 0.85)
		st.bottom = Color(0.07, 0.062, 0.09, 0.85)
	pc.add_theme_stylebox_override("panel", st)
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
	UI.style_label(name, "display", 19, col.lightened(0.2) if known else DIM)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var tag := _small_label("learned  ·  step %d" % learn if known else "learned at step %d" % learn, UI.GOOD if known else FAINT)
	tag.add_theme_font_size_override("font_size", 14)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tag)
	var d := Label.new()
	d.text = _sentence(sp["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 200.0
	d.add_theme_font_size_override("font_size", 15)
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
	_header("Inventory", "Gear and items last one climb; heirlooms stay with you.", "Climber")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4 if compact() else 6)
	row.add_child(left)
	var keys: Array = []
	var cell := 52.0 if compact() else 58.0  # slot sizes (smaller on a phone)
	var heirs := inv_view == "heirlooms"
	var packed := inv_view == "pack" and p != null

	# The paper doll: what you wear (or your heirlooms), laid out like a body;
	# or your pack's spare pieces.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	left.add_child(head)
	var pack_name := "Pack" + (" %d" % p.pack.size() if p != null and not p.pack.is_empty() else "")
	for v in [["worn", "Worn"], ["pack", pack_name], ["heirlooms", "Heirlooms"]]:
		var t := _button(v[1], _inv_view.bind(v[0]), head)
		t.custom_minimum_size = Vector2(80.0 if v[0] != "pack" else 70.0, 28.0 if compact() else 30.0)
		t.add_theme_font_size_override("font_size", 15)
		t.set_meta("view", v[0])
		_tab_look(t, v[0] == inv_view)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 14)
	left.add_child(doll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	doll.add_child(grid)
	var caption := not compact()
	if packed:
		# The pack: spare pieces (they come down to the train if you survive).
		for i in maxi(p.pack_size(), p.pack.size()):
			var g = p.pack[i] if i < p.pack.size() else null
			var ps := _slot(grid, "pack:%d" % i, cell, (Gear.short(g) if g != null else "Empty") if caption else "")
			ps.kind = "gear"
			ps.id = Gear.base_id(g) if g != null else ""
			ps.rec = g
			ps.empty = g == null
			ps.tint = Gear.color(g) if g != null else FAINT
			ps.wear = Gear.condition(g) if g != null and Gear.wears(g) else -1.0
			keys.append(ps.get_meta("slot"))
		var pl := _small_label("%d of %d spaces" % [p.pack.size(), p.pack_size()], DIM)
		left.add_child(pl)
	else:
		for r in Gear.DOLL:
			for slot in r:
				var s := _heir_cell(grid, slot, cell, caption) if heirs else _worn_cell(grid, p, slot, cell, caption)
				keys.append(s.get_meta("slot"))
	# Beside the doll: fists (weapon slot 1), the off-hand (kept for later),
	# gear at your feet and a camp's rune.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	doll.add_child(side)
	if not heirs and not packed:
		var fs := _slot(side, "gear:fists", cell, "Fists" if caption else "")
		fs.kind = "gear"
		fs.id = "fists"
		fs.on = p.weapon == "fists"
		fs.tint = Gear.color("fists")
		fs.corner = "1"
		keys.append("gear:fists")
	if not packed:
		var off := _slot(side, "heir:offhand" if heirs else "gear:offhand", cell, Gear.SLOT_NAMES["offhand"] if caption else "")
		off.kind = "heir" if heirs else "gear"
		off.locked = true
		off.slot_name = Gear.SLOT_NAMES["offhand"]
		keys.append(off.get_meta("slot"))
	if not heirs and not main.gear_here.is_empty():
		# Gear at your feet: set against what you wear in its slot.
		var fl := _slot(side, "floor", cell, "At your feet" if caption else "")
		fl.kind = "floor"
		fl.id = main.gear_here["id"]
		fl.rec = main.gear_here.get("rec", null)
		fl.tint = Gear.color(fl.id)
		keys.append("floor")
	var rune: String = p.camp_rune if p != null else ""
	if not heirs and not packed and rune != "":
		var rs := _slot(side, "rune", cell, Items.CAMP_RUNES[rune]["name"].replace("Rune of ", "") if caption else "")
		rs.kind = "rune"
		rs.id = rune
		rs.tint = Items.CAMP_RUNES[rune]["color"]
		keys.append("rune")

	# The belt: a cell for each kind it holds (4, or 5 with a Belt Pouch or
	# Climber's Pack), the items you carry first.
	var have: Array = p.carried() if p != null else []
	var kinds: int = p.belt_kinds() if p != null else Items.BELT_KINDS
	_section("Belt  ·  %d of %d kinds" % [have.size(), kinds], left)
	var item_row := _slot_row(left)
	var sel: String = p.selected_item() if p != null else ""
	for i in maxi(kinds, have.size()):
		if i < have.size():
			var id: String = have[i]
			var s := _slot(item_row, "item:" + id, cell, Items.ITEMS[id]["short"] if caption else "")
			s.kind = "item"
			s.id = id
			s.count = p.item_count(id)
			s.on = id == sel
			keys.append(s.get_meta("slot"))
		else:
			var e := _slot(item_row, "belt:%d" % i, cell, "Empty" if caption else "")
			e.kind = "belt"
			e.empty = true
			keys.append(e.get_meta("slot"))

	# Essence crystals: kept between climbs (the profile), consumed to bank.
	# (On the right, over the details, so the screen fits a phone.)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("Essence crystals", right)
	var crystal_row := _slot_row(right)
	crystal_row.add_theme_constant_override("separation", 4)
	for kind in Essence.KINDS:
		var n: int = main.profile.crystal_count(kind)
		var s := _slot(crystal_row, "crystal:" + kind, (36.0 if compact() else 40.0), "" if compact() else Essence.display(kind))
		s.kind = "crystal"
		s.id = kind
		s.count = int(main.profile.crystal_total(kind))  # (one crystal of each kind: how much it holds)
		s.empty = n <= 0
		s.tint = Essence.color(kind)
		keys.append(s.get_meta("slot"))

	# The details of the focused slot.
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), UI.SLOT_EDGE, 8, 1, 12.0 if compact() else 14.0))
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dpanel.custom_minimum_size.x = 260.0
	row.add_child(right)
	right.add_child(dpanel)
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 4 if compact() else 6)
	dpanel.add_child(details)
	if not (inv_sel in keys):
		inv_sel = "heir:melee" if heirs else ("pack:0" if packed else "gear:" + _hand_slot(p))
	_show_details(inv_sel)
	_footer()


## A cell of the doll showing what you wear in a carried slot.
func _worn_cell(parent: Node, p, slot: String, side: float, caption: bool) -> Slot:
	var g = p.gear.get(slot, {})
	var has: bool = Gear.is_gear(g)
	var name: String = Gear.SLOT_NAMES.get(slot, slot)
	var cap := ""
	if caption:
		cap = (String(Gear.info(g).get("name", "")) if slot in ["melee", "ranged"] else Gear.short(g)) if has else ("No armor" if slot == "armor" else name)
	var s := _slot(parent, "gear:" + slot, side, cap)
	s.kind = "gear"
	s.id = Gear.base_id(g)
	s.rec = g if has else null
	s.slot_name = name
	s.on = has and s.id == p.weapon
	s.empty = not has and slot != "armor"
	s.tint = Gear.color(g) if has else FAINT
	s.corner = {"melee": "2", "ranged": "3"}.get(slot, "")
	s.wear = Gear.condition(g) if Gear.wears(g) else -1.0
	s.kept = has and _is_heirloom(g)
	return s


## A cell of the doll showing your heirloom for a slot (Rings: one of two).
func _heir_cell(parent: Node, slot: String, side: float, caption: bool) -> Slot:
	var hs := Gear.heirloom_slot_for_carry(slot)
	var idx := 1 if slot == "ring2" else 0
	var pieces: Array = Gear.heirloom_pieces(main.profile.heirlooms, hs)
	var g = pieces[idx] if idx < pieces.size() else null
	var key := "heir:" + hs + (":%d" % idx if hs == "rings" else "")
	var name: String = Gear.SLOT_NAMES.get(slot, slot)
	var s := _slot(parent, key, side, (Gear.short(g) if g != null else name) if caption else "")
	s.kind = "heir"
	s.id = Gear.base_id(g) if g != null else ""
	s.rec = g
	s.slot_id = hs
	s.slot_name = name
	s.locked = Gear.heirloom_planned(hs)
	s.empty = g == null
	s.tint = Gear.color(g) if g != null else FAINT
	return s


## Is this worn piece one of your heirlooms (the same piece, any wear)?
func _is_heirloom(g) -> bool:
	for k in Gear.heirloom_pieces(main.profile.heirlooms, Gear.heirloom_slot(g)):
		if Gear.same(k, g):
			return true
	return false


func _inv_view(view: String) -> void:
	inv_view = view
	inv_sel = ""
	open("inventory", opened_direct)


func _hand_slot(p) -> String:
	if p == null:
		return "melee"
	for k in ["melee", "ranged"]:
		if p.gear_id(k) == p.weapon:
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
	l.custom_minimum_size.x = side + 10.0
	UI.style_label(l, "display", 14, DIM)  # (what's in it, by name: a label)
	cell.add_child(l)
	return s


## A tap or Enter on a slot shows it; on an item, a second press uses it.
func _slot_pressed(key: String) -> void:
	if key == inv_sel and key.begins_with("item:"):
		_use_item(key.substr(5))
		return
	_show_details(key)


## Where each carried slot is, in words.
const WHERE := {
	"fists": "Slot 1: always with you", "melee": "Slot 2: your melee weapon", "ranged": "Slot 3: your ranged weapon",
	"armor": "Chest", "ring1": "Ring (left hand)", "ring2": "Ring (right hand)",
}


func _show_details(key: String) -> void:
	if details == null or not is_instance_valid(details):
		return
	var changed := key != inv_sel or details.get_child_count() == 0
	inv_sel = key
	for s in (train_page.slot_root() if page == "train" else box).find_children("*", "Button", true, false):
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
	if page == "train" and kind != "heir":
		train_page.details(key)
		return
	match kind:
		"gear":
			if arg == "offhand":
				_detail_head("lock", null, Gear.SLOT_NAMES["offhand"], DIM)
				_detail_text("Kept for later: off-hand pieces will change how you parry.", DIM)
				return
			var g = "fists" if arg == "fists" else p.gear.get(arg, {})
			var has: bool = arg == "fists" or Gear.is_gear(g)
			var none := "No armor" if arg == "armor" else "Empty"
			_detail_head("gear" if has or arg == "armor" else "empty", g if has else "", Gear.display(g) if has else none, Gear.color(g) if has else DIM)
			var weaponish: bool = arg in ["fists", "melee", "ranged"]
			if weaponish:
				var where: String = WHERE[arg]
				if has and Gear.base_id(g) == p.weapon:
					where += "  ·  in hand"
				_detail_text(where, DIM)
			elif not has:
				_detail_text(WHERE.get(arg, Gear.SLOT_NAMES.get(arg, arg)), DIM)
			if not has:
				if arg != "armor":
					_detail_text("Nothing here yet. Slain monsters, caches, camps and vaults may give you a piece for it.", DIM)
					return
			elif arg != "fists":
				_detail_lines(g, "" if weaponish else WHERE.get(arg, Gear.SLOT_NAMES.get(arg, arg)))
			var other = _compare_with(p, arg, g)
			_detail_stats(g if has else "", other)
			if arg in ["armor", "helm", "legs"] and p.protection() > 0.0:
				_detail_text("All you wear takes %d%% off a blow (at most %d%%)." % [int(round(p.protection() * 100.0)), int(round(Gear.PROTECTION_CAP * 100.0))], DIM)
			if arg != "fists" and Gear.is_gear(other):
				var pl := Gear.plays_like(g, other)
				if pl != "":
					_detail_text(pl.replace("Compared with yours", "Against %s" % Gear.display(other).to_lower()), DIM)
		"belt":
			_detail_head("empty", "", "Empty belt slot", DIM)
			_detail_text("Your belt holds %d kinds of item, up to %d of each (the recall scroll is one). A Belt Pouch or a Climber's Pack holds one more kind; a Satchel one more of each." % [p.belt_kinds(), p.max_stack("draught")], DIM)
			_detail_text("Hold %s to open a ring of your belt items: time slows; point at one and let go to use it." % _item_key(), DIM)
		"item":
			var n: int = p.item_count(arg)
			var data: Dictionary = Items.ITEMS[arg]
			_detail_head("item", arg, data["name"], Items.color(arg))
			_detail_text(String(data["desc"]).left(1).to_upper() + String(data["desc"]).substr(1) + ".", TEXT)
			if arg == "vessel":  # (what it holds, and that it comes home whole)
				var V = load("res://scripts/vessel.gd")
				_detail_text(V.TEXT["desc_state"] % V.state_text(V.carried(p)), V.color(V.carried(p)).lightened(0.3))
				_detail_text(V.TEXT["hud_lines"][1], DIM)
			_detail_text("Carrying %d of %d%s" % [n, p.max_stack(arg), "  ·  your quick item" if arg == p.selected_item() and n > 0 else ""], DIM)
			if data.has("kind"):
				_detail_text("%s essence  ·  unused at the end of a survived climb, it breaks into a crystal" % Essence.display(data["kind"]), Color(Essence.color(data["kind"]), 0.9))
			if arg == "vessel":
				return  # (nothing to use: it fills as great foes fall)
			var use := _button("Read it" if arg == "scroll" else "Use", _use_item.bind(arg), details)
			use.disabled = n <= 0 or p.dead
			if n > 0 and arg != p.selected_item():
				_button("Make it your quick item", _pick_item.bind(arg), details)
		"heir":
			var pieces: Array = Gear.heirloom_pieces(main.profile.heirlooms, arg)
			var idx := int(key.get_slice(":", 2)) if key.get_slice_count(":") > 2 else 0
			var g = pieces[idx] if idx < pieces.size() else null
			var title := Gear.heirloom_slot_name(arg) + " heirloom"
			if Gear.heirloom_planned(arg):
				_detail_head("lock", null, title, DIM)
				_detail_text("Kept for later: off-hand pieces aren't in the tower yet.", DIM)
			elif g == null:
				_detail_head("heir", null, title, DIM)
				_detail_text("Empty. Survive a climb and you may keep the piece you wear here." if arg != "rings" else "Empty. Survive a climb and you may keep the rings you wear: both together.", DIM)
			else:
				_detail_head("gear", g, Gear.display(g), Gear.color(g))
				_detail_text("%s heirloom: every climb begins with it%s." % [Gear.heirloom_slot_name(arg), " (both rings are kept together)" if arg == "rings" else ""], DIM)
				_detail_lines(g)
				_detail_stats(g, null)
		"floor":
			if main.gear_here.is_empty():
				return
			var fg = main.gear_here.get("rec", main.gear_here["id"])
			var gslot := Gear.slot_of(fg)
			var into: String = p.slot_for(fg)
			var held = p.gear.get(into, {})
			var has_held: bool = Gear.is_gear(held)
			_detail_head("gear", fg, Gear.display(fg), Gear.color(fg))
			_detail_text("On the floor at your feet, for your %s slot." % Gear.SLOT_NAMES.get(gslot, gslot).to_lower(), DIM)
			_detail_lines(fg)
			_detail_stats(fg, held if has_held else ("" if gslot == "armor" else null))
			if has_held:
				var pl := Gear.plays_like(fg, held)
				if pl != "":
					_detail_text(pl, DIM)
			var rings: Array = Gear.carry_slots(gslot)
			if rings.size() > 1 and rings.all(func(s): return p.gear_id(s) != ""):
				# Two rings on: choose which one to take off.
				for s in rings:
					var b := _button("Swap for your %s" % Gear.display(p.gear[s]), _take_floor.bind(s), details)
					b.disabled = p.dead
			else:
				var old_goes := ("  (your %s goes in your pack)" if p.pack_room() else "  (drops your %s)") % Gear.display(held) if has_held else ""
				var take := _button("Take it" + old_goes, _take_floor.bind(""), details)
				take.disabled = p.dead
			var into_pack := _button("Into your pack" + ("" if p.pack_room() else "  (it's full)"), _pack_floor, details)
			into_pack.disabled = p.dead or not p.pack_room()
		"pack":
			var i := int(arg)
			if i >= p.pack.size():
				_detail_head("empty", "", "Empty pack space", DIM)
				_detail_text("Your pack carries %d spare pieces (a Climber's Pack holds more). Swap gear and your old piece goes in here while there's room. Survive the climb, or read a recall scroll, and your pack comes down to the train with you; fall, and it's lost." % p.pack_size(), DIM)
				return
			var pg = p.pack[i]
			var pslot := Gear.slot_of(pg)
			var pinto: String = p.slot_for(pg)
			var pheld = p.gear.get(pinto, {})
			var pworn: bool = Gear.is_gear(pheld)
			_detail_head("gear", pg, Gear.display(pg), Gear.color(pg))
			_detail_text("In your pack, for your %s slot. It comes down to the train with you if you survive." % Gear.SLOT_NAMES.get(pslot, pslot).to_lower(), DIM)
			var prings: Array = Gear.carry_slots(pslot)
			if prings.size() > 1 and prings.all(func(sl): return p.gear_id(sl) != ""):
				for sl in prings:
					var sb := _button("Wear it for your %s" % Gear.display(p.gear[sl]), _wear_pack.bind(i, sl), details)
					sb.disabled = p.dead
			else:
				var wb := _button("Wear it" + ("  (your %s goes in your pack)" % Gear.display(pheld) if pworn else ""), _wear_pack.bind(i, ""), details)
				wb.disabled = p.dead
			var db := _button("Drop it here", _drop_pack.bind(i), details)
			db.disabled = p.dead
			_detail_lines(pg)
			_detail_stats(pg, pheld if pworn else ("" if pslot == "armor" else null))
			if pworn:
				var ppl := Gear.plays_like(pg, pheld)
				if ppl != "":
					_detail_text(ppl, DIM)
		"crystal":
			var n: int = main.profile.crystal_count(arg)
			var col: Color = Essence.color(arg)
			_detail_head("crystal", arg, Items.CRYSTAL["name"] % Essence.display(arg), col)
			var held := int(main.profile.crystal_total(arg))
			if n <= 0:
				_detail_text(Items.CRYSTAL["none"], DIM)
			else:
				_detail_text(_sentence(Items.CRYSTAL["desc"] % [held, Essence.display(arg).to_lower()]), TEXT)
				_detail_text(Items.CRYSTAL["held"] % held, DIM)
			var step := int(Items.CRYSTAL["step"])
			var eat := _button(Items.CRYSTAL["consume"] % (step if n <= 0 else mini(step, held)), _consume_crystal.bind(arg), details)
			eat.disabled = n <= 0
		"rune":
			var r: Dictionary = Items.CAMP_RUNES.get(p.camp_rune, {})
			_detail_head("rune", p.camp_rune, r.get("name", "Rune"), r.get("color", GOLD))
			_detail_text(String(r.get("desc", "")).left(1).to_upper() + String(r.get("desc", "")).substr(1) + ".", TEXT)
			_detail_text("Inscribed at a camp; it lasts the rest of this climb.", DIM)
	if toast != "":
		_detail_text(toast, GOLD)


## What to set a worn piece against: gear lying at your feet for the same
## slot, else what every climb starts with (null for nothing).
func _compare_with(p, slot: String, g):
	if not main.gear_here.is_empty() and p.slot_for(main.gear_here["id"]) == slot and Gear.slot_of(main.gear_here["id"]) != "fists":
		return main.gear_here.get("rec", main.gear_here["id"])
	var start := {"melee": Weapons.START_MELEE, "ranged": Weapons.START_RANGED, "armor": ""}
	if start.has(slot) and start[slot] != Gear.base_id(g):
		return Gear.make(start[slot]) if start[slot] != "" else ""
	return null


func _detail_head(kind: String, id, title: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	details.add_child(row)
	var icon := SlotIcon.new()
	icon.kind = kind
	icon.id = Gear.base_id(id) if kind == "gear" else (String(id) if id != null else "")
	icon.rec = id if kind == "gear" else null
	icon.tint = col
	icon.custom_minimum_size = Vector2(44, 44) if compact() else Vector2(48, 48)
	row.add_child(icon)
	var l := Label.new()
	l.text = title
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_label(l, "display", 23 if compact() else 25, col.lightened(0.15))
	row.add_child(l)


func _detail_text(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 220.0
	l.add_theme_font_size_override("font_size", 14 if compact() else 15)
	l.add_theme_color_override("font_color", col)
	details.add_child(l)


## A piece's plain lines: what it does, then its rarity, slot and condition
## (and a warning when it's badly worn).
func _detail_lines(g, slot_label := "") -> void:
	var lines: Array = Gear.describe(g)
	if slot_label != "" and lines.size() > 1:
		lines[1] = slot_label + "  ·  " + String(lines[1])
	for i in lines.size():
		var col := TEXT if i == 0 else (UI.BAD if i >= 2 else DIM)
		if i == 1 and not Gear.wears(Gear.rec(g)):
			col = Color(Gear.RARITIES[Gear.rarity(g)]["color"], 0.9)
		_detail_text(lines[i], col)
		if i == 0:
			# Its traits, each in its essence's colour.
			for t in Gear.trait_lines(g):
				_detail_text(t[0], Color(t[1], 0.95))


## A piece's numbers; against `other` (null for nothing to set it against),
## with arrows: up and green where it's better, down and red where worse.
func _detail_stats(g, other) -> void:
	var against: bool = other != null
	var rows: Array = Gear.compare(g, other, 6) if against else []
	if not against:
		for st in Gear.stats(g):
			rows.append([st[0], st[1], "", 0, st[4] if st.size() > 4 else ""])
	if rows.is_empty():
		return
	# Numbers your gear has pushed to their caps say so.
	var capped: Array = Gear.capped_keys(main.player.gear) if main.player != null else []
	for r in rows:
		if r.size() > 4 and String(r[4]) in capped:
			r[0] = Gear.TEXT["capped"] % r[0]
	var grid := GridContainer.new()
	grid.columns = 3 if against else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1 if compact() else 2)
	details.add_child(grid)
	if against:
		grid.add_child(_label("", 0.0, DIM))
		grid.add_child(_small_label("this", DIM))
		var oname := "no armor" if Gear.base_id(other) == "" and Gear.slot_of(g) == "armor" else Gear.display(other).to_lower()
		grid.add_child(_small_label(oname, DIM))
	for r in rows:
		grid.add_child(_small_label(r[0], TEXT))
		var sign: int = r[3]
		var col := UI.GOOD if sign > 0 else (UI.BAD if sign < 0 else TEXT)
		var cellbox := HBoxContainer.new()
		cellbox.add_theme_constant_override("separation", 3)
		cellbox.add_child(_small_label(r[1], col))
		if sign != 0:
			var ar := CompareArrow.new()
			ar.up = sign > 0
			ar.tint = col
			ar.custom_minimum_size = Vector2(9, 9)
			ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cellbox.add_child(ar)
		grid.add_child(cellbox)
		if against:
			grid.add_child(_small_label(r[2], DIM))


func _small_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	return l


## The item button for the device in use, in words.
func _item_key() -> String:
	if main.touch_active:
		return "the Item button"
	if main.pad_active:
		return "%s or the d-pad down" % Controls.pad_name("x", main.pad_ps)
	return "G"


func _use_item(id: String) -> void:
	var p = main.player
	if p == null or p.item_count(id) <= 0:
		return
	var before: String = p.item_sel
	p.item_sel = id
	if p.use_item():
		toast = "Used: %s" % Items.ITEMS[id]["name"]
	else:
		toast = Items.RECALL["ask_menu"] if id == "scroll" and main.recall_ask_t > 0.0 else "It would do nothing now."
		if id == "scroll" and main.first_climb:
			toast = Items.RECALL["first_climb"]
		p.item_sel = before
	toast_t = 2.0
	if not main.victory.is_empty():
		return  # (the scroll was read: the climb is over and the menu closed)
	open("inventory", opened_direct)


func _consume_crystal(kind: String) -> void:
	var lines: Array = main.consume_crystal(kind)
	toast = " ".join(lines) if not lines.is_empty() else ""
	toast_t = 3.0
	open("inventory", opened_direct)


func _take_floor(into := "") -> void:
	if main.take_gear_here(into):
		inv_sel = "gear:" + _hand_slot(main.player)
	open("inventory", opened_direct)


func _pack_floor() -> void:
	if main.pack_gear_here():
		inv_view = "pack"
		inv_sel = "pack:%d" % (main.player.pack.size() - 1)
	open("inventory", opened_direct)


func _wear_pack(i: int, into: String) -> void:
	if main.wear_from_pack(i, into):
		inv_sel = "pack:%d" % i
	open("inventory", opened_direct)


func _drop_pack(i: int) -> void:
	main.drop_from_pack(i)
	open("inventory", opened_direct)


func _pick_item(id: String) -> void:
	main.player.item_sel = id
	open("inventory", opened_direct)


# --- the train ---------------------------------------------------------------------

## Between climbs: the train's cars (train_page.gd builds them, in train_view.gd's rooms).
func _page_train() -> void:
	train_page.build()


# --- the dev tool ------------------------------------------------------------------

func _ask_new(back: String) -> void:
	confirm_back = back
	open("confirm_new")


## Start over: this climber only (their slot starts again; the others are kept).
func _page_confirm_new() -> void:
	var CT: Dictionary = ClimbersPage.TEXT
	var who: String = str(main.profile.appearance.get("name", ""))
	_header(CT["over_title"], "")
	_text(CT["over_text"] % (who if who != "" else CT["over_this"]), TEXT, true)
	_gap()
	var row := _grid(2)
	_button(CT["over"], _new_climber, row)
	_button(CT["cancel"], open.bind(confirm_back), row)


func _page_dev() -> void:
	_header("Dev tools", "For testing. Changes to marks are saved.", "Menu")

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

	_section("Puzzles (every floor of rooms gets this kind)")
	var zrow := _grid(3, 6)
	var Catalog = load("res://scripts/puzzles/catalog.gd")
	var zb := _button("Usual mix", _dev_puzzle.bind(""), zrow)
	zb.disabled = Catalog.forced == ""
	for kind in Catalog.TYPES:
		var kb := _button(Catalog.display_name(kind, main.tower), _dev_puzzle.bind(kind), zrow)
		kb.disabled = Catalog.forced == kind

	_section("Practice a beast (full health)")
	var brow := _grid(3, 6)
	for id in Towers.ORDER:
		if Towers.TOWERS[id].has("beast_kind"):
			_button(Towers.TOWERS[id]["short"], _dev_beast.bind(id), brow)

	_section("Spawn a monster")
	var grid := _grid(4, 6)
	for kind in EnemyScript.TYPES.keys().filter(func(k): return k != "familiar"):
		_button(kind.capitalize(), _dev_spawn.bind(kind), grid)

	_section("Mirror images (mirror.gd)")
	var irow := _row()
	_button("Spawn a mirror image", _dev_spawn.bind(main.MirrorScript.THEME), irow)
	var mb := _button("Mirror room on the next floor", _dev_mirror_room, irow)
	mb.disabled = main.MirrorScript.force

	_section("Gear (give yourself any weapon, armor or piece)")
	var ggrid := _grid(4, 6)
	var worn: Array = p.carried_gear()
	for id in Weapons.ORDER:
		if id != "fists":
			var gb := _button(Weapons.WEAPONS[id]["name"], _dev_gear.bind(id), ggrid)
			gb.disabled = id in worn
	for id in Gear.ARMOR_ORDER:
		var ab := _button(Gear.ARMOR[id]["name"], _dev_gear.bind(id), ggrid)
		ab.disabled = id == p.gear_id("armor")
	for id in Gear.PIECE_ORDER:
		var pb := _button(Gear.PIECES[id]["name"], _dev_gear.bind(id), ggrid)
		pb.disabled = id in worn and Gear.slot_of(id) != "ring"
	_button("Take off the pieces", _dev_strip, ggrid)

	_section("Finds (dropped at your feet) and named pieces")
	var fgrid := _grid(4, 6)
	for r in ["fine", "rare", "storied"]:
		_button("A %s find" % Gear.RARITIES[r]["name"], _dev_find.bind(r), fgrid)
	for n in Gear.NAMED_ORDER:
		_button(Gear.NAMED[n]["name"], _dev_named.bind(n), fgrid)

	_section("Items (onto your belt)")
	var igrid := _grid(4, 6)
	for id in Items.ORDER:
		var ib := _button(Items.ITEMS[id]["name"], _dev_item.bind(id), igrid)
		ib.disabled = p.item_room(id) != ""
	_button("Empty the belt", _dev_empty_belt, igrid)

	_section("Secret essences (your path and its flow)")
	var srow := _row()
	var prof = main.profile
	srow.add_child(_label("%s  ·  %d banked  ·  step %d" % [Secret.display(prof.path) if prof.path != "" else "no path", int(prof.flow), prof.flow_step()], 230.0, GOLD if prof.path != "" else DIM))
	for k in Secret.ORDER:
		var pb := _button(Secret.display(k), _dev_path.bind(k), srow)
		pb.disabled = prof.path == k
	var frow2 := _row()
	for fb in [_button("+25 flow", _dev_flow.bind(25.0), frow2), _button("+100 flow", _dev_flow.bind(100.0), frow2), _button("Reset path", _dev_reset_path, frow2)]:
		fb.disabled = prof.path == ""
	_button("Show the choice", _dev_offer_path, frow2)
	load("res://scripts/vessel_page.gd").dev_row(self)  # an empty or a full vessel
	_dev_makers()

	SecretPage.dev_section(self)  # the secret bonds: grant one at depth 1 or 2, or clear it
	TechniquePage.dev_section(self)  # the Unbound (technique_page.gd)

	_section("Cheats")
	var crow := _row()
	_button("No dying: %s" % ("on" if main.dev_no_death else "off"), _toggle_no_death, crow)
	_button("Heal", _heal, crow)
	_button("Clear the room", _clear_room, crow)
	if main.trap_view != null:
		_button("Show traps: %s" % ("on" if main.trap_view.show_all else "off"), _toggle_traps, crow)
	var prow := _row()
	_button("Speed readout: %s" % ("on" if main.hud.show_perf else "off"), _toggle_perf, prow)
	if toast != "":
		_text(toast, GOLD, true)
	_footer()


# --- actions -----------------------------------------------------------------

## Dev tools for the Makers (makers.gd), to try them on the phone.
func _dev_makers() -> void:
	var mk = main.makers
	if mk == null:
		return
	_section("The Makers (fragments, interest, meetings)")
	var prof = main.profile
	var bits: Array = ["Fragments %d (%d needed)" % [Makers.fragment_count(prof), int(Makers.REVEAL["fragments"])]]
	for m in Makers.ORDER:
		bits.append("%s %d / %d" % [Makers.MAKERS[m]["short"], int(mk.interest(m)), int(mk.threshold(m))])
	var c: Dictionary = Makers.core(prof)
	if not c.is_empty():
		bits.append("core: " + Makers.SECRET_BONDS[c["bond"]]["Name"])
	_text("  ·  ".join(bits), DIM)
	var row := _grid(4, 6)
	_button("Add a fragment", _dev_fragment, row)
	for m in Makers.ORDER:
		_button("+100 %s" % Makers.MAKERS[m]["short"], _dev_interest.bind(m), row)
	var row2 := _grid(4, 6)
	_button("Meet a Maker now", _dev_meet, row2)
	_button("A glimpse now", _dev_glimpse, row2)
	_button("A fragment on this floor", _dev_place_fragment, row2)
	_button("Clear the Makers", _dev_clear_makers, row2)


func _dev_fragment() -> void:
	var m: String = main.makers.dev_fragment()
	_say("A fragment of %s (%d found)" % [Makers.MAKERS[m]["name"], Makers.fragment_count(main.profile)])


func _dev_interest(m: String) -> void:
	main.makers.dev_interest(m, 100.0)
	_say("%s: interest %d" % [Makers.MAKERS[m]["Name"], int(main.makers.interest(m))])


func _dev_meet() -> void:
	if main.makers.dev_meet() == "":
		_say("No Maker to meet")
		return
	close()  # (it shows itself once the menu has closed)


func _dev_glimpse() -> void:
	main.makers.start_glimpse(main.makers.dev_choice(), Makers.GLIMPSE["kinds"][randi() % Makers.GLIMPSE["kinds"].size()])
	close()


func _dev_place_fragment() -> void:
	var mk = main.makers
	mk.setup_floor(true)
	if mk.fragment.is_empty():
		_say("No secret room or vault on this floor")
	else:
		_say("A fragment waits in this floor's %s" % ("secret room" if mk.fragment["src"] == "secret" else "vault"))


func _dev_clear_makers() -> void:
	main.makers.dev_clear()
	_say("The Makers forget you")

func _leave_title() -> void:
	if not main.profile.created:
		open("create")  # a new climber chooses a look first
		return
	Engine.set_meta("sixfold_title_seen", true)
	close()


## The climber picker (climbers_page.gd): six slots, from the title.
func _page_climbers() -> void:
	ClimbersPage.build(self)


## The title with the climber picker over it (after deleting the current climber).
func open_climbers() -> void:
	open("title")
	open("climbers")


## The climber picker's figure: the climber screen's drawing in a slot's
## look, with a soft light on each mark in its bond's colour.
func figure_into(b, look: Dictionary, bonds: Dictionary) -> void:
	BodyView._figure(b, look)
	for part in bonds:
		var info: Dictionary = bonds[part]
		if not BodyView.SPOTS.has(part) or not Bonds.BONDS.has(info.get("id", "")):
			continue
		var col: Color = Bonds.BONDS[info["id"]]["color"]
		var a := 0.5 if bool(info.get("faint", false)) else 1.0
		UI.glow_into(b, BodyView.SPOTS[part], 22.0, col, 1.6 * a)
		b.dot(BodyView.SPOTS[part], 6.0, Color(col.lightened(0.35), 0.9 * a))


## The appearance editor (appearance_page.gd): a new climber's, ending in Begin...
func _page_create() -> void:
	look_from = ""
	look_page.build("create")


## ...or later, from the climber screen or your car on the train.
func _page_appearance() -> void:
	look_page.build("edit")


## The Unbound's techniques (technique_page.gd), from your car on the train.
func _page_techniques() -> void:
	TechniquePage.build(self)


## Opens the appearance editor; Back returns to `from` ("climber", or the
## usual place: the train, the pause menu or the title).
func open_appearance(from := "") -> void:
	look_from = from
	open("appearance", opened_direct if from == "climber" else true)


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


func _dev_puzzle(kind: String) -> void:
	main.dev_puzzle(kind)
	_say("Puzzles: %s (floor %d)" % [kind.capitalize() if kind != "" else "the usual mix", main.floor_num])


func _dev_spawn(kind: String) -> void:
	main.dev_spawn(kind)
	_say("Spawned: %s" % kind.capitalize())


func _dev_mirror_room() -> void:
	main.MirrorScript.force = true
	_say(main.MirrorScript.TEXT["forced"])


func _dev_gear(id: String) -> void:
	main.dev_give_gear(id)
	_say("Now carrying: %s" % Gear.display(id))


func _dev_find(r: String) -> void:
	var g: Dictionary = main.find_gear("", 0, r)
	main.drop_gear(main.player.global_position + Vector2(0, 30), g, true)
	_say("At your feet: %s" % Gear.display(g))


func _dev_named(n: String) -> void:
	var g: Dictionary = Gear.make_named(n)
	main.drop_gear(main.player.global_position + Vector2(0, 30), g, true)
	_say("At your feet: %s" % Gear.display(g))


func _dev_item(id: String) -> void:
	main.player.add_item(id)
	_say("On your belt: %s (%d)" % [Items.ITEMS[id]["name"], main.player.item_count(id)])


func _dev_empty_belt() -> void:
	main.player.items = {}
	main.player.item_sel = ""
	_say("Your belt is empty")


func _dev_strip() -> void:
	for slot in Gear.PIECE_SLOTS:
		main.dev_give_gear("-" + slot)
	_say("Took off every piece but the weapons and the chest")


func _toggle_no_death() -> void:
	main.dev_no_death = not main.dev_no_death
	open("dev")


## The dev readout: frame rate, frame time, draw calls, nodes, monsters, traps and lights.
func _toggle_perf() -> void:
	main.hud.show_perf = not main.hud.show_perf
	Engine.set_meta("sixfold_perf", main.hud.show_perf)  # (kept across a restart)
	open("dev")


func _toggle_traps() -> void:
	main.trap_view.show_all = not main.trap_view.show_all
	open("dev")


func _dev_path(kind: String) -> void:
	main.dev_set_path(kind)
	_say("Path: %s" % Secret.display(kind))


func _dev_flow(amount: float) -> void:
	main.dev_add_flow(amount)
	_say("Flow %d (step %d)" % [int(main.profile.flow), main.profile.flow_step()])


func _dev_reset_path() -> void:
	main.reset_path()
	_say("Path reset")


func _dev_offer_path() -> void:
	main.reset_path()
	close()
	main.offer_path()


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
	load_settings_from(SETTINGS_PATH)


static func load_settings_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	settings["condense"] = str(settings["condense"])
	if not Train.CONDENSE_CHOICES.any(func(c): return c[0] == settings["condense"]):
		settings["condense"] = Train.CONDENSE_DEFAULT  # (an old or broken save: the default share)


static func save_settings() -> void:
	if Engine.has_meta("sixfold_test"):
		return
	save_settings_to(SETTINGS_PATH)


static func save_settings_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(path)


func apply_settings() -> void:
	if main == null:
		return
	if main.audio != null:
		main.audio.set_levels(float(settings["music"]), float(settings["sounds"]))
	if main.hud != null:
		main.hud.show_help = bool(settings["help"])
		main.hud.hud_scale = float(UI.HUD_SCALES.get(str(settings["hud_scale"]), 1.0))
	if main.lighting != null:
		# Lighting quality: unset, it starts on what suits the device (lighting.gd).
		if not main.lighting.QUALITY.has(str(settings["lighting"])):
			settings["lighting"] = main.lighting.default_quality()
		main.lighting.set_quality(str(settings["lighting"]))


func _set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	apply_settings()


# --- building blocks -----------------------------------------------------------

## A page's heading: an eyebrow (a small gothic label: where it belongs), the
## title in the display face, a line under it, and an ornamental rule. On a
## rail page, Close sits at its right (a phone: the title and its line share
## one row, to save height).
func _header(text: String, sub: String, eyebrow := "") -> void:
	text = UI.title_case(text)
	var small := compact() and page != "title"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# (Grenze Gotisch's line is tall for its letters: the lines overlap a little)
	col.add_theme_constant_override("separation", -6 if small else -9)
	row.add_child(col)
	if eyebrow != "" and not small:
		var e := Label.new()
		e.text = eyebrow
		UI.style_label(e, "eyebrow", UI.SIZE_EYEBROW, Color(GOLD, 0.75))
		col.add_child(e)
	var l := Label.new()
	l.text = text
	UI.style_label(l, "display", 26 if small else UI.SIZE_HEADING, GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	if small:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		col.add_child(line)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(l)
		if sub != "":
			var s := _label(sub, 0.0, DIM)
			UI.style_label(s, "body", 14, DIM)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.clip_text = true
			s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(s)
	else:
		col.add_child(l)
		if sub != "":
			var s := Label.new()
			s.text = sub
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s.custom_minimum_size.x = 360.0
			UI.style_label(s, "body", UI.SIZE_BODY, DIM)
			col.add_child(s)
	if rail_showing() and page in RAIL_ROOTS:
		# Close, and the key that does the same.
		var right := HBoxContainer.new()
		right.add_theme_constant_override("separation", 8)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER if small else Control.SIZE_SHRINK_BEGIN
		row.add_child(right)
		var hint := ""
		if main != null and not main.touch_active:
			var key := "Esc"
			if page == "climber" and opened_direct:
				key = "Tab"
			elif page == "inventory" and opened_direct:
				key = "I"
			hint = Controls.pad_text("{b}", main.pad_ps) if main.pad_active else key
		if hint != "":
			var hl := _key_hint(hint)
			hl.custom_minimum_size.x = 0.0
			right.add_child(hl)
		var b := _button("Close", close, right)
		b.custom_minimum_size = Vector2(88.0 if small else 96.0, 32.0 if small else 34.0)
		b.add_theme_font_size_override("font_size", 15)
		b.set_meta("back", true)
		b.set_meta("close", true)
		b.focus_mode = Control.FOCUS_NONE
	_rule()


func _rule() -> void:
	var r := Rule.new()
	r.custom_minimum_size.y = 8.0 if compact() else 12.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)


## A double rule with a gilt diamond in the middle (ui.gd draw_divider).
class Rule extends Control:
	const UI := preload("res://scripts/ui.gd")

	func _draw() -> void:
		UI.draw_divider(self, Vector2(0, size.y * 0.5 - 1.5), Vector2(size.x, size.y * 0.5 - 1.5), Color(UI.GOLD, 0.7))


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
		b.custom_minimum_size = Vector2(112.0, 32.0) if compact() else Vector2(124.0, 34.0)
		b.add_theme_font_size_override("font_size", 16 if compact() else 17)
		b.set_meta("tab", t[0])
		_tab_look(b, t[0] == current)
	if keys[1] != "":
		row.add_child(_key_hint(keys[1]))
	_gap(0 if compact() else 2)


func _key_hint(key: String) -> Label:
	var l := _label(key, 30.0, FAINT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(l, "mono", 11, FAINT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## A tab: a pill, the chosen one washed in gilt with a gilt edge.
func _tab_look(b: Button, on: bool) -> void:
	for state in ["normal", "hover", "pressed"]:
		var bg := Color(1, 1, 1, 0.035)
		var edge := Color(UI.LINE_HI, 0.55)
		if on:
			bg = Color(UI.GILT, 0.2 if state == "normal" else 0.28)
			edge = Color(UI.GILT, 0.75)
		elif state != "normal":
			bg = Color(1, 1, 1, 0.07)
			edge = Color(UI.GILT, 0.45)
		var st := UI.box(bg, edge, 16)
		_button_margins(st)
		b.add_theme_stylebox_override(state, st)
	var f := UI.focus_box()
	(f as StyleBoxFlat).set_corner_radius_all(18)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_color_override("font_color", GOLD if on else DIM)
	b.add_theme_color_override("font_hover_color", GOLD if on else TEXT)
	b.add_theme_color_override("font_focus_color", GOLD if on else TEXT)


## The gilded look of the main button on a page (or the current tab).
func _primary(b: Button) -> void:
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, UI.primary_box(state))
	b.add_theme_color_override("font_color", UI.GILT_HI)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.93, 0.75))


## The bottom of a page: Back (or Close, for a screen opened by its key) and
## which key does the same.
func _footer() -> void:
	if rail_showing() and page in RAIL_ROOTS:
		return  # (the rail and the header's Close do this)
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
		UI.style_label(l, "mono", 11, FAINT)
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
	l.text = text
	UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW + 1, Color(GOLD, 0.82))
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
	grid.add_child(UI.style_label(_label(name, 130.0, DIM), "display", 17, DIM))  # (a label: gothic)
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
	var name_label := UI.style_label(_label(text, 120.0), "display", 18, TEXT)
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


static func _button_margins(s: StyleBox) -> void:
	UI.button_margins(s)


func _make_theme() -> Theme:
	UI.setup_fonts()
	return UI.theme()  # (ui.gd: the fonts, buttons, toggles, sliders and scroll bars)


# --- drawn parts -----------------------------------------------------------------------

## An inventory slot: a square button with its icon drawn in code. The one
## in hand (or the quick item) is gilded; empty slots are dim; planned ones
## are locked.
class Slot extends Button:
	const Gear := preload("res://scripts/gear.gd")
	const Essence := preload("res://scripts/essence.gd")
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
	var rec = null  # gear: the record, so wear shows (cracks and a condition bar)
	var slot_name := ""  # gear and heirlooms: shown faintly in an empty slot
	var wear := -1.0  # a Common piece's condition, 0 to 1 (-1: doesn't wear)
	var kept := false  # gear you wear that is also your heirloom
	var price := 0  # the train's store: a price, drawn as a gem and a number
	var price_kind := ""
	var price_ok := true  # false: you can't pay it (the number is red)

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
		# A slot's name is a label (the gothic face); counts and prices are
		# numbers (tabular figures).
		var font := UI.font("mono")
		var label := UI.font("display")
		var c := size / 2.0
		var s := size.x * 0.33
		# A soft inner light behind what's in the slot, in its colour.
		if not empty and not locked:
			var b := UI.Draw.Batch.new()
			UI.glow_into(b, c, size.x * 0.46, tint if kind != "item" else Items.color(id), 0.7 if on else 0.45)
			b.flush(self)
		if picked:
			draw_rect(Rect2(Vector2(4, size.y - 4), Vector2(size.x - 8, 2)), Color(UI.GOLD, 0.85))
		# Gear better than Common: edged in its rarity's colour.
		if rec != null and kind in ["gear", "heir", "floor"] and Gear.rarity(rec) != "common":
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(Gear.rarity_color(rec), 0.8), false, 1.5)
		if locked:
			UI.draw_lock(self, c + (Vector2(0, -5) if slot_name != "" else Vector2.ZERO), s * 0.7, Color(UI.FAINT, 0.8))
			if slot_name != "":
				draw_string(label, Vector2(0, size.y - 6.0), slot_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(UI.FAINT, 0.9))
			return
		match kind:
			"gear", "heir", "floor":
				if id != "" or (kind == "gear" and not empty):
					Gear.draw_icon(self, rec if rec != null else id, c, s, tint if not empty else Color(tint, 0.3))
				elif slot_name != "":
					draw_string(label, Vector2(0, c.y + 5.0), slot_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(UI.FAINT, 0.9))
				else:
					draw_arc(c, s * 0.55, 0.0, TAU, 24, Color(UI.FAINT, 0.45), 1.5, true)
				if wear >= 0.0:
					var wb := UI.Draw.Batch.new()
					UI.wear_into(wb, Rect2(Vector2(6, size.y - 8), Vector2(size.x - 12, 3)), wear)
					wb.flush(self)
				if kept:
					var kb := UI.Draw.Batch.new()
					UI.gem_into(kb, Vector2(size.x - 8, 8), 3.5, UI.GOLD)
					kb.flush(self)
			"item":
				Items.draw_icon(self, id, c + Vector2(0, -1), s, 1.0 if count > 0 else 0.22)
				if count >= 0:
					var t := str(count)
					var fs := 16
					var at := Vector2(size.x - 6.0 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, size.y - 6.0)
					draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
					draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD if on else (UI.TEXT if count > 0 else UI.FAINT))
			"belt":
				for k in 8:
					var a0 := TAU * k / 8.0
					draw_arc(c, s * 0.55, a0, a0 + TAU / 16.0, 4, Color(UI.FAINT, 0.5), 1.5, true)
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
			"vessel":  # (id: the vessel's code, vessel.gd)
				var V = load("res://scripts/vessel.gd")
				V.draw_icon(self, c + Vector2(0, -1), s, V.decode(id))
			"crystal":
				Items.draw_crystal_icon(self, tint, c, s, 1.0 if count > 0 else 0.22)
				if count > 0:
					var t := str(count)
					var at := Vector2(size.x - 5.0 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, size.y - 5.0)
					draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
					draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT)
		if corner != "":
			draw_string(font, Vector2(5, 13), corner.get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.GOLD if on else UI.DIM)
		if on and kind == "item":
			draw_string(label, Vector2(5, size.y - 5.0), "Quick", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.GOLD)
		if kind == "floor":
			draw_string(label, Vector2(5, 14), "New", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.GOLD)
		if price > 0:
			var gb := UI.Draw.Batch.new()
			if price_kind == "any":  # (train.gd ANY: any kind: a gold gem flanked by two small ones)
				UI.gem_into(gb, Vector2(6, 11), 3.0, Essence.color("fire"))
				UI.gem_into(gb, Vector2(12, 11), 3.0, Essence.color("water"))
				UI.gem_into(gb, Vector2(9, 7), 4.0, UI.GOLD)
			else:
				UI.gem_into(gb, Vector2(9, 9), 4.5, Essence.color(price_kind))
			gb.flush(self)
			var pt := str(price)
			draw_string_outline(font, Vector2(16, 14), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(16, 14), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.TEXT if price_ok else UI.BAD)


## The big icon at the top of the inventory's details (and the record's heirlooms).
class SlotIcon extends Control:
	const Gear := preload("res://scripts/gear.gd")
	const Items := preload("res://scripts/items.gd")
	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var id := ""
	var rec = null  # gear: the record (wear shows as cracks)
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
				Gear.draw_icon(self, rec if rec != null else id, c, s, tint)
			"item":
				Items.draw_icon(self, id, c, s)
			"rune":
				Items.draw_rune_icon(self, tint, c, s)
			"vessel":
				var V = load("res://scripts/vessel.gd")
				V.draw_icon(self, c, s, V.decode(id))
			"crystal":
				Items.draw_crystal_icon(self, tint, c, s)
			"lock":
				UI.draw_lock(self, c, s * 0.7, UI.FAINT)
			_:
				draw_arc(c, s * 0.55, 0.0, TAU, 24, Color(UI.FAINT, 0.5), 1.5, true)


## A small arrow beside a compared number: up (better) or down (worse).
class CompareArrow extends Control:
	const UI := preload("res://scripts/ui.gd")
	var up := true
	var tint := Color.WHITE

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		UI.arrow_into(b, size / 2.0, minf(size.x, size.y) * 0.45, up, tint)
		b.flush(self)


## The climber, drawn like the one in the tower (hooded, cloaked, outlined
## and shaded) but facing you, with each mark glowing on its body part in
## the bond's colour and a thin ring of the essence settled there. Unmarked
## parts are dark sockets; where the next mark is forming, a gold one.
class BodyView extends Control:
	const Bonds := preload("res://scripts/bonds.gd")
	const UnboundRef := preload("res://scripts/unbound.gd")
	const MakersRef := preload("res://scripts/makers.gd")
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
		var font := UI.font("display")
		var k := minf(size.y / 292.0, size.x / 316.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4.0 * k)
		var t := Time.get_ticks_msec() / 1000.0
		draw_set_transform(c, 0.0, Vector2(k, k))
		var b := UI.Draw.Batch.new()
		_backdrop(b)
		_figure(b, main.climber_look)
		MakersRef.core_figure_into(b, main.profile, SPOTS, t)  # (a core mark, beneath the marks)
		var unbound: bool = UnboundRef.is_on(main.profile)
		for part in ORDER:
			if unbound:
				_veins(b, part, t)  # (the Unbound: veins of raw essence)
			else:
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
			if UnboundRef.is_on(prof):
				sub = "level %d" % UnboundRef.level(prof, part)
				sub_col = _vein_col(part, t)
			elif not info.is_empty():
				var data: Dictionary = Bonds.BONDS[info["id"]]
				sub = data["name"]
				sub_col = data["color"] if not info.get("faint", false) else Color(data["color"], 0.6)
			elif main.player != null and prof.bonds.size() < 6 and main.leading_part() == part:
				sub = "forming"
				sub_col = Color(UI.GOLD, 0.8)
			if part == "back":
				name = "Back (behind)"
			# The part and its mark are names (the gothic face); "unmarked" and
			# the like are plain words.
			var sf: Font = font if not info.is_empty() else UI.font("body")
			var small := k < 0.8
			var ns := 15 if small else 16
			var ss := 13 if small else 14
			var w1 := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
			var w2 := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
			var x1 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w1
			var x2 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w2
			draw_string_outline(font, Vector2(x1, ly + 3.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(x1, ly + 3.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, UI.TEXT if not info.is_empty() else UI.DIM)
			draw_string(sf, Vector2(x2, ly + (15.0 if small else 18.0)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, sub_col)

	func _backdrop(b) -> void:
		for i in 6:
			b.dot(Vector2(0, -12), 150.0 - i * 20.0, Color(0.55, 0.5, 0.7, 0.022))
		var prof = main.profile
		if prof.path != "":
			# Your shadow holds your path's flow (secret.gd): faint before its first step.
			Secret.draw_shadow(b, Vector2(0, 124), 38.0, prof.path, prof.flow_step(), Time.get_ticks_msec() * 0.001, 1.0, 0.24)
			return
		b.polygon(UI._oval(Vector2(0, 126), Vector2(74, 12), 24), Color(0, 0, 0, 0.3))
		b.polygon(UI._oval(Vector2(0, 126), Vector2(48, 7), 24), Color(0, 0, 0, 0.3))

	static func _p(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, pts.size(), 2):
			out.append(Vector2(pts[i], pts[i + 1]))
		return out

	## The figure, in a frame about 290 tall centred on the waist. Lit from
	## the top-left: the left side of each piece is paler, the right darker.
	## Its colours, hair and hood come from `look` (appearance.gd look(); the
	## appearance page's preview draws it too).
	static func _figure(b, look: Dictionary) -> void:
		var cloak: Color = look["cloak"]
		var tunic: Color = look["tunic"]
		var skin: Color = look["skin"]
		var boot: Color = look["boot"]
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
		# The head: the hood up (the face in its shadow) or down (appearance.gd).
		Appearance.draw_front_head(b, look)

	## The Unbound: veins of raw essence from the part, in its main colour,
	## more and brighter with its level; hot with strain; raw essence after an eruption.
	func _veins(b, part: String, t: float) -> void:
		var prof = main.profile
		var at: Vector2 = SPOTS[part]
		var lv := UnboundRef.level(prof, part)
		var col := _vein_col(part, t)
		UI.glow_into(b, at, 10.0 + 2.2 * lv, col, 0.35 + 0.12 * lv)
		var n := 3 + lv
		var length := 8.0 + 1.6 * lv
		for i in n:
			var ang := float(i) * 2.399 + float(hash(part) % 40) * 0.1
			var p0 := at
			var p1 := at + Vector2.from_angle(ang) * length * 0.5 + Vector2.from_angle(ang + 1.5) * 2.5
			var p2 := at + Vector2.from_angle(ang + 0.3) * length
			var p3 := p1 + Vector2.from_angle(ang - 0.9) * length * 0.35
			b.line(p0, p1, Color(col, 0.75), 1.8)
			b.line(p1, p2, Color(col, 0.55), 1.3)
			b.line(p1, p3, Color(col, 0.4), 1.0)
		b.dot(at, 3.0 + 0.3 * lv, col.lightened(0.3))
		var run = main.unbound
		if run != null and run.glow.has(part):
			for i in 6:
				var ma := t * 3.0 + float(i) * TAU / 6.0
				b.dot(at + Vector2.from_angle(ma) * 14.0, 2.0, Color(0.92, 0.9, 1.0, 0.85))

	func _vein_col(part: String, t: float) -> Color:
		var run = main.unbound
		if run != null:
			return run.vein_color(main.profile, part, t)
		return UI.TEXT

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
		var col: Color = Bonds.BONDS[info["id"]]["color"] if not info.is_empty() else Color(0, 0, 0, 0)
		var normal := UI.card(Color(col, 0.8) if not info.is_empty() else Color(0, 0, 0, 0))
		if info.is_empty():
			normal.top = Color(0.09, 0.08, 0.115, 0.92)
			normal.bottom = Color(0.07, 0.062, 0.09, 0.92)
		var hover := UI.card(UI.GOLD)
		hover.top = Color(0.16, 0.14, 0.2, 0.98)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("focus", UI.focus_box())

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
		draw_string(font, Vector2(size.x - 16.0, h * 0.5 + 5.0), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.FAINT)
		var name: String = Bonds.PART_NAMES[part]
		if info.is_empty():
			var lead := ""
			if main.player != null and prof.bonds.size() < 6:
				lead = main.leading_part()
			var b := UI.Draw.Batch.new()
			UI.socket_into(b, mc, r * 0.78, main.soak_fraction(part) if lead == part else 0.0)
			b.flush(self)
			UI.draw_label(self, Vector2(x, h * 0.5 - 4.0), name, 19, UI.DIM)
			# How much it has soaked up (on the first climb, against the part
			# you've used most); the leader is where the next mark forms.
			var soak: float = main.soak_fraction(part)
			if main.first_climb:
				soak = main.part_soak(part) / maxf(main.part_soak(lead) if lead != "" else 0.0, 1.0)
			var bar_y := h * 0.5 + 20.0
			if lead == part:
				var forming := "your mark is forming" if main.first_climb else "your next mark is forming"
				draw_string(font, Vector2(x, h * 0.5 + 13.0), forming, HORIZONTAL_ALIGNMENT_LEFT, w + 10.0, 13, UI.GOLD)
				var bid: String = main.predicted_bond()
				if bid != "" and tall:
					var bi: Dictionary = Bonds.BONDS[bid]
					draw_string(font, Vector2(x, h * 0.5 + 28.0), "would be %s" % bi["name"], HORIZONTAL_ALIGNMENT_LEFT, w + 10.0, 13, bi["color"])
					bar_y = h * 0.5 + 34.0
			else:
				draw_string(font, Vector2(x, h * 0.5 + 13.0), "unmarked", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.FAINT)
			if main.player != null:
				UI.draw_bar(self, Rect2(Vector2(x, bar_y), Vector2(w, 6)), soak, UI.GOLD if lead == part else Color(0.6, 0.57, 0.66))
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
		grow = _fit(font, grow, w, 13)
		UI.draw_medallion(self, mc, r, col, data["affinity"], k, step, 0.0, faint)
		UI.draw_label(self, Vector2(x, y + 17.0), data["name"], 20, col.lightened(0.12), HORIZONTAL_ALIGNMENT_LEFT, w)
		var sub := "%s  ·  %s" % [name, "faint" if faint else "step %d" % step]
		draw_string(font, Vector2(x, y + 31.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)
		UI.draw_bar(self, Rect2(Vector2(x, y + 38.0), Vector2(w, 6.0)), k, col)
		draw_string(font, Vector2(x, y + 57.0), grow, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.FAINT if not faint else Color(UI.BAD, 0.85))
		if tall:
			var known: Array = data["spells"].filter(func(sp): return int(sp["learn"]) <= step).map(func(sp): return sp["name"])
			var line := "%d of %d spells: %s" % [known.size(), data["spells"].size(), ", ".join(known)]
			draw_string(font, Vector2(x, y + 75.0), _fit(font, line, w, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)

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
			UI.draw_title(self, Vector2(x, 42), Bonds.PART_NAMES[part], 34, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 0.4)
			draw_string(font, Vector2(x, 62), "Unmarked  ·  cast key %s" % Bonds.PART_KEYS[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.FAINT)
			UI.draw_bar(self, Rect2(Vector2(x, 76), Vector2(w, 9)), soak, UI.GOLD)
			draw_string(font, Vector2(x, 104), "Soaked: %d%%%s" % [int(round(soak * 100.0)), "  ·  the next mark forms here" if lead == part else ""], HORIZONTAL_ALIGNMENT_LEFT, w, 14, UI.GOLD if lead == part else UI.DIM)
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
		UI.draw_title(self, Vector2(x, 42), data["name"], 34, col.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.5)
		var sub := "%s mark  ·  %s essence  ·  %s" % [Bonds.PART_NAMES[part], Essence.display(data["affinity"]), "faint" if faint else "step %d of 5" % step]
		draw_string(font, Vector2(x, 60), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 15, UI.DIM)
		UI.draw_bar(self, Rect2(Vector2(x, 70), Vector2(w, 9)), k, col)
		draw_string(font, Vector2(x, 96), grow, HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(UI.BAD, 0.9) if faint else UI.TEXT)
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
			draw_string(font, p + Vector2(-8, 4), str(s + 1), HORIZONTAL_ALIGNMENT_CENTER, 16, 13, UI.OUTLINE if s + 1 <= step else UI.DIM)
			var need := "start" if s == 0 else "%d" % int(ProfileScript.STEP_XP[s])
			draw_string(font, p + Vector2(-30, 23), need, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, UI.FAINT)


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
## The Essence tab's flow (secret.gd): your shadow holding your path's
## essence, its step, what each step does and how much to the next. Before
## the first step, only a faint sign.
class FlowView extends Control:
	const Secret := preload("res://scripts/secret.gd")
	const UI := preload("res://scripts/ui.gd")
	var main

	static func height(step: int, small: bool) -> float:
		if step <= 0:
			return 60.0
		return 132.0 if small else 150.0

	func _process(_delta: float) -> void:
		queue_redraw()  # the shadow lives

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var prof = main.profile
		var path: String = prof.path
		var st: int = prof.flow_step()
		var col := Secret.color(path)
		var light: Color = Secret.KINDS[path]["light"]
		var t := Time.get_ticks_msec() * 0.001
		var b := UI.Draw.Batch.new()
		b.rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.025))
		b.rect(Rect2(Vector2.ZERO, Vector2(2.0, size.y)), Color(col, 0.6))
		var sw := minf(150.0, size.x * 0.28)
		var sc := Vector2(sw * 0.5 + 10.0, size.y * 0.55)
		var rr := minf(sw * 0.17, 24.0)
		Secret.draw_shadow(b, sc + Vector2(0, 18), rr, path, st, t, 1.0 if st > 0 else 0.7)
		if st > 0:
			Secret.draw_figure(b, sc + Vector2(0, 18), rr * 2.6, col, t)
		b.flush(self)
		var x := sw + 24.0
		var w := size.x - x - 8.0
		if st <= 0:
			draw_string(font, Vector2(x, size.y * 0.5 + 5.0), Secret.TEXT["faint_sign"] % [Secret.display(path), int(Secret.STEPS[0])], HORIZONTAL_ALIGNMENT_LEFT, w, 15, Color(col, 0.75))
			return
		# The path and its step (a label: gothic), then its motto (an inscription).
		var head := "%s  ·  Step %d of %d" % [Secret.display(path), st, Secret.STEPS.size()]
		UI.draw_label(self, Vector2(x, 19), head, 18, light, HORIZONTAL_ALIGNMENT_LEFT, w)
		var hw := UI.font("display").get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16.0
		UI.draw_inscription(self, Vector2(x + hw, 19), Secret.KINDS[path]["motto"], 17, Color(col.lightened(0.15), 0.9), HORIZONTAL_ALIGNMENT_LEFT, maxf(w - hw, 10.0))
		var small := size.y < 140.0
		var y := 38.0
		var lh := 17.0 if small else 20.0
		for i in Secret.STEPS.size():
			var on := i < st
			var pc := Vector2(x + 7.0, y - 4.0)
			draw_circle(pc, 6.5, Color(col, 0.55 if on else 0.12))
			draw_string(font, pc + Vector2(-7, 4), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 14, 12, light if on else UI.FAINT)
			draw_string(font, Vector2(x + 20.0, y), "%s  (%d)" % [Secret.STEP_TEXT[path][i], int(Secret.STEPS[i])], HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 14 if not small else 13, UI.TEXT if on else UI.FAINT)
			y += lh
		var need: float = Secret.next_need(prof.flow)
		var line: String = Secret.TEXT["next"] % [int(prof.flow), int(ceil(need - prof.flow)), st + 1] if need > 0.0 else Secret.TEXT["full"] % int(prof.flow)
		if main.run_flow >= 0.5:
			line += "  ·  " + Secret.TEXT["unbanked"] % int(main.run_flow)
		draw_string(font, Vector2(x, y + 4.0), line, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)


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
		var texts: Array = []  # [pos, text, size, colour, align width, font (default body)]
		var gothic := UI.font("display")  # (heads and names)
		var mono := UI.font("mono")  # (numbers)
		var head_col := Color(UI.GOLD, 0.7)
		texts.append([Vector2(0, 12), "Density and Attributes", 15, head_col, -1.0, gothic])
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
			texts.append([Vector2(34, cy + 5), Essence.display(kind), 18, col, -1.0, gothic])
			texts.append([Vector2(88, cy + 5), attr["name"], 14, UI.TEXT, -1.0])
			texts.append([Vector2(150, cy + 5), "%d" % int(prof.density.get(kind, 0.0)), 14, UI.DIM, 44.0, mono])
			var bx := 206.0
			var bw := maxf(left_w - bx - 150.0, 60.0)
			UI.bar_into(b, Rect2(Vector2(bx, cy - 3.5), Vector2(bw, 7.0)), clampf(bonus / prof.ATTRIBUTE_CAP, 0.0, 1.0), col)
			var bt := "+%.1f%% %s" % [bonus * 100.0, attr["bonus"]]
			texts.append([Vector2(bx + bw + 10.0, cy + 5), bt, 12, UI.GOLD if bonus > 0.001 else UI.FAINT, -1.0])
			y += row_h
		# Right: settled in the body, and unbanked.
		var rx := left_w + 22.0
		var rw := size.x - rx
		texts.append([Vector2(rx, 12), "Settled in Your Body", 15, head_col, -1.0, gothic])
		var most := 1.0
		for part in Bonds.PARTS:
			most = maxf(most, _total(prof, part))
		var py := 26.0
		var step := 20.0 if small else 24.0
		for part in Bonds.PARTS:
			texts.append([Vector2(rx, py + 11), Bonds.PART_NAMES[part], 15, UI.TEXT if prof.bonds.has(part) else UI.DIM, -1.0, gothic])
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
			texts.append([Vector2(bar.end.x + 4, py + 11), "%d" % int(_total(prof, part)), 13, UI.DIM, 34.0, mono])
			py += step
		py += 10.0
		texts.append([Vector2(rx, py + 10), "Unbanked This Climb", 15, head_col, -1.0, gothic])
		py += 30.0
		var x := rx
		var any := false
		for kind in KINDS:
			var amt: float = main.run_essence.get(kind, 0.0)
			if amt <= 0.0:
				continue
			any = true
			UI.gem_into(b, Vector2(x + 7, py - 4), 6.5, Essence.color(kind))
			texts.append([Vector2(x + 18, py + 1), "%d %s" % [int(amt), Essence.display(kind)], 14, UI.TEXT, -1.0])
			x += 92.0
			if x + 80.0 > size.x:
				x = rx
				py += 20.0
		b.flush(self)
		for tx in texts:
			var f: Font = tx[5] if tx.size() > 5 else font
			if tx[4] > 0.0:
				draw_string(f, tx[0], tx[1], HORIZONTAL_ALIGNMENT_RIGHT, tx[4], tx[2], tx[3])
			else:
				draw_string(f, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tx[2], tx[3])
		if not any:
			draw_multiline_string(font, Vector2(rx, py + 1), "None yet: slain monsters leave essence; bank it at the stair.", HORIZONTAL_ALIGNMENT_LEFT, rw, 14, -1, UI.FAINT)
		else:
			draw_string(font, Vector2(rx, py + 22), "lost if you fall before the stair", HORIZONTAL_ALIGNMENT_LEFT, rw, 13, UI.FAINT)

	func _total(prof, part: String) -> float:
		var t := 0.0
		var pd: Dictionary = prof.part_density.get(part, {})
		for k in pd:
			t += float(pd[k])
		return t
