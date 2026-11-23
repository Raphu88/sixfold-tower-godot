extends Control
## The one confirmation pop-up every menu uses before something that can't
## be undone or costs a lot (menu.gd ask): choosing a branch of the Tree for
## good, sealing a Node, breaking a mark's seal, Start over, selling, the
## bench's work, deleting a climber... It says what will happen, with
## Confirm (named for the action) and Cancel; the focus starts on Cancel.
##
## Mouse, keyboard, controller and touch all work: a click or tap on a
## button presses it; Left / Right (or Up / Down) move between the two;
## Enter, Space or A press; Esc, B, a right-click, the phone's back or a tap
## outside the card cancel. It's sized to fit a phone held sideways (an
## 800x400 screen) and grows no wider than MAX_W.
##
## It's flat (UI colours from ui.gd), drawn over the page and the train; the
## page under it stays as it was. While it shows, the menu hands it every
## press (menu.gd _input, _process, go_back).

const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"title": "Are you sure?",
	"confirm": "Confirm",
	"cancel": "Cancel",
}
const MAX_W := 460.0
const MIN_W := 240.0
## Space kept between the card and the screen's edge.
const EDGE := 16.0

var menu
var dim: ColorRect
var card: PanelContainer
var title_l: Label
var text_l: Label
var yes: Button
var no: Button
var _action: Callable
var _danger := false
var source_rect := Rect2()  # the button that opened it (the flash after Confirm lands there)
var _touch_from := Vector2.ZERO
var _touch_moved := 0.0
var _touch_on := false
var _back_click := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	dim = ColorRect.new()
	dim.color = Color(UI.SHADE, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_dim_input)
	add_child(dim)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := UI.box(UI.MENU_PANEL, Color(UI.GILT, 0.55), 8, 1, 16.0)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 10
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	title_l = Label.new()
	UI.style_label(title_l, "display", 20, UI.GOLD)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title_l)
	text_l = Label.new()
	UI.style_label(text_l, "body", 16, UI.TEXT)
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	no = Button.new()
	no.text = TEXT["cancel"]
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(cancel)
	no.set_meta("pop", "cancel")
	no.set_meta("help", "pop_cancel")
	row.add_child(no)
	yes = Button.new()
	yes.text = TEXT["confirm"]
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(confirm)
	yes.set_meta("pop", "confirm")
	yes.set_meta("help", "pop_confirm")
	row.add_child(yes)
	no.focus_neighbor_right = no.get_path_to(yes)
	no.focus_neighbor_left = no.get_path_to(yes)
	yes.focus_neighbor_left = yes.get_path_to(no)
	yes.focus_neighbor_right = yes.get_path_to(no)


## Shows it: `text` says what will happen, `confirm` names the action (its
## button), `action` runs on Confirm. `danger`: the Confirm button in red
## (it can't be undone). `title` over the words ("Are you sure?" if empty).
func open(text: String, confirm: String, action: Callable, danger := false, title := "") -> void:
	_action = action
	_danger = danger
	title_l.text = UI.title_case(title if title != "" else String(TEXT["title"]))
	text_l.text = text
	text_l.visible = text != ""
	yes.text = confirm if confirm != "" else String(TEXT["confirm"])
	no.text = String(TEXT["cancel"])
	_look()
	for c in [self, dim, card, yes, no]:
		c.mouse_filter = Control.MOUSE_FILTER_STOP  # (closing the menu turns every control's off)
	visible = true
	_touch_on = false
	_back_click = false
	fit()
	modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 1.0, UI.FADE_IN)
	tw.tween_property(card, "scale", Vector2.ONE, UI.FADE_IN * 1.4)
	# Keys and controller start on Cancel (the safe one); on a phone nothing
	# shows the focus.
	if menu != null and menu.main != null and menu.main.touch_active:
		if is_inside_tree():
			get_viewport().gui_release_focus()
	else:
		no.grab_focus.call_deferred()


func showing() -> bool:
	return visible


## Confirm: it closes, then the action runs.
func confirm() -> void:
	if not visible:
		return
	var act := _action
	close()
	if act.is_valid():
		act.call()


## Cancel (Esc, B, a tap outside...): it closes and nothing happens.
func cancel() -> void:
	if not visible:
		return
	close()
	if menu != null and menu.main != null:
		menu.main.sfx("ui_back")


func close() -> void:
	visible = false
	_action = Callable()
	_touch_on = false
	if menu != null and menu.has_method("pop_closed"):
		menu.pop_closed()


## Presses Confirm (true) or Cancel (false), as a click would (tests, taps).
func press(confirm_it: bool) -> void:
	if confirm_it:
		confirm()
	else:
		cancel()


## Sized and centred for the screen (a phone's is small: the words shrink a
## little, the buttons grow taller for a thumb).
func fit() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	var small := view.y < 600.0
	var touch: bool = menu != null and menu.main != null and menu.main.touch_active
	var w := clampf(view.x - EDGE * 2.0, MIN_W, MAX_W)
	text_l.add_theme_font_size_override("font_size", 15 if small else 16)
	title_l.add_theme_font_size_override("font_size", 18 if small else 20)
	for b in [yes, no]:
		b.custom_minimum_size = Vector2(0, 46 if touch else 40)
	text_l.custom_minimum_size.x = w - 32.0
	title_l.custom_minimum_size.x = w - 32.0
	card.custom_minimum_size = Vector2(w, 0)
	card.size = Vector2(w, 0)
	card.reset_size()
	var h := card.get_combined_minimum_size().y
	card.size = Vector2(w, h)
	card.position = ((view - card.size) * 0.5).floor()
	card.position.y = maxf(card.position.y, 4.0)
	card.pivot_offset = card.size * 0.5


func _process(_delta: float) -> void:
	if visible:
		var view := get_viewport_rect().size
		var want := ((view - card.size) * 0.5).floor()
		if card.position.distance_to(want) > 0.5 or card.size.x > view.x:
			fit()


func _look() -> void:
	if menu == null:
		return
	for b in [yes, no]:
		for state in ["normal", "hover", "pressed", "focus"]:
			b.remove_theme_stylebox_override(state)
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			b.remove_theme_color_override(c)
	if _danger:
		menu._danger(yes)
	else:
		menu._primary(yes)


## A click on the shade around the card: cancel.
func _dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cancel()
		accept_event()


## The menu hands it every input while it shows. True if it used it (the
## menu then stops it); mouse clicks go on to the buttons themselves.
func input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.index != 0:
			return true
		if event.pressed:
			_touch_on = true
			_touch_from = event.position
			_touch_moved = 0.0
		elif _touch_on:
			_touch_on = false
			if _touch_moved < 14.0:
				tap(event.position)
		return true
	if event is InputEventScreenDrag:
		if event.index == 0:
			_touch_moved = maxf(_touch_moved + event.relative.length(), (event.position - _touch_from).length())
		return true
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_XBUTTON1):
		if event.pressed:
			_back_click = true
		elif _back_click:
			_back_click = false
			cancel()
		return true
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return true  # (nothing under it scrolls)
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return false  # (the buttons and the shade take clicks themselves)
	return false


## A tap: the button under it, or outside the card, Cancel.
func tap(at: Vector2) -> void:
	if not visible:
		return
	if yes.get_global_rect().has_point(at):
		confirm()
	elif no.get_global_rect().has_point(at):
		cancel()
	elif not card.get_global_rect().has_point(at):
		cancel()


## Left / Right (or Up / Down): the other button.
func step() -> void:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f == no:
		yes.grab_focus()
	elif f == yes:
		no.grab_focus()
	else:
		no.grab_focus()
