extends RefCounted
## The appearance editor (menu.gd's "create" and "appearance" pages): how
## the climber looks. A new climber meets it before the first climb (the
## very first launch, a new climber slot and Start over) as "create", ending in
## Begin; later the climber screen's Appearance button and the train's
## Your car open it as "appearance", ending in Done (or Back).
##
## On the left, a live preview: the climber as the tower draws it (a
## player.gd node used as a doll, scaled up, idling, turned with the Turn
## buttons, Q / E or LB / RB) and as the climber screen draws it (menu.gd
## BodyView._figure). On the right, the name (optional; the dice picks one),
## a row of tabs (appearance.gd TABS: Face, Hair, Body, Cloak, Extras) and
## the rows of the chosen tab (appearance.gd ROWS). The tabs are one control
## like a row: Left / Right (the d-pad or stick) on it change the tab, a
## click or tap picks one. Left / Right change the focused row, and a click
## or tap on its arrows or swatches does too. Up and down run through it all
## in one loop. Every change is kept at once (main.gd set_appearance). The
## options, tabs, colours and words are data in appearance.gd.

const Appearance := preload("res://scripts/appearance.gd")
const PlayerScript := preload("res://scripts/player.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")
static var T := Appearance.TEXT

var m  # the menu (menu.gd)
var figure: Callable  # draws the climber screen's figure: (batch, look)
var draft := {}  # the look being chosen (kept as it changes)
var said := ""  # the Entity's first-time tip on this page
var view: LookView
var rows := {}  # option key -> OptionRow (the chosen tab's)
var tab := ""  # the chosen tab (appearance.gd TABS; kept while the game runs)
var tabs: TabRow
var rows_box: VBoxContainer
var name_edit: LineEdit
var dice: Button
var rnd: Button
var tl: Button
var tr: Button
var finish: Button  # Begin or Done
var first_focus: Control  # where the keys and controller start


func _init(menu, draw_figure: Callable) -> void:
	m = menu
	figure = draw_figure


## Builds the page into the menu. `mode`: "create" (a new climber: Begin)
## or "edit" (later: Done).
func build(mode: String) -> void:
	var small: bool = m.compact()
	var creating := mode == "create"
	draft = Appearance.normalized(m.main.profile.appearance)
	rows = {}
	m._header(T["new_title"] if creating else T["edit_title"], T["new_sub"] if creating else T["edit_sub"])
	if creating and said == "":
		said = m.main.tip_now("appearance")
	var row_said: Control = null
	if creating and said != "":
		var key_mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
		row_said = Entity.says(Entity.fill_keys(said, key_mode, m.main.pad_ps), 30.0 if small else 38.0)
		row_said.set_meta("entity", "appearance")
		if not small:
			m.box.add_child(row_said)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14 if small else 20)
	m.box.add_child(row)
	# The preview, the turn buttons, Randomise and Begin / Done.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	if small and row_said != null:
		left.add_child(row_said)  # (a phone: beside the rows, so they all fit)
	view = LookView.new()
	view.figure = figure
	view.custom_minimum_size = Vector2(320, 224) if small else Vector2(380, 318)
	if small and row_said != null:
		view.custom_minimum_size.y = 150.0
	view.show_look(draft)
	left.add_child(view)
	var turns := HBoxContainer.new()
	turns.add_theme_constant_override("separation", 6)
	left.add_child(turns)
	tl = m._button(T["turn_left"], turn.bind(-1), turns)
	var hint := ""
	if not m.main.touch_active:
		hint = Controls.pad_name("lb", m.main.pad_ps) + " / " + Controls.pad_name("rb", m.main.pad_ps) if m.main.pad_active else "Q / E"
	if hint != "":
		turns.add_child(m._key_hint(hint))
	tr = m._button(T["turn_right"], turn.bind(1), turns)
	for b in [tl, tr]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 40.0
		b.set_meta("turn", true)
	var ends := HBoxContainer.new()
	ends.add_theme_constant_override("separation", 6)
	left.add_child(ends)
	rnd = m._button(T["randomise"], randomise, ends)
	finish = m._button(T["begin"] if creating else m._with_key(T["done"], "Esc", "{b}"), begin if creating else m.go_back, ends)
	for b in [rnd, finish]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 44.0
	m._primary(finish)
	finish.set_meta("finish", true)
	# The name and the option rows.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4 if small else 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	right.add_child(nr)
	var nl: Label = m._label(T["name"], 96.0 if small else 112.0, UI.DIM)
	nl.add_theme_font_size_override("font_size", 16)
	nr.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.text = draft["name"]
	name_edit.placeholder_text = T["name_hint"]
	name_edit.max_length = Appearance.NAME_MAX
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_stylebox_override("normal", UI.box(Color(UI.VOID, 0.95), UI.LINE_HI, 6, 1, 8.0))
	var focus := UI.box(Color(0.08, 0.07, 0.11), UI.GILT_HI, 6, 2, 8.0)
	focus.shadow_color = Color(UI.GILT, 0.3)
	focus.shadow_size = 5
	name_edit.add_theme_stylebox_override("focus", focus)
	name_edit.add_theme_color_override("font_color", UI.TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", UI.FAINT)
	name_edit.text_changed.connect(_name_changed)
	name_edit.text_submitted.connect(func(_t): _focus_rows())
	nr.add_child(name_edit)
	dice = m._button(T["name_dice"], roll_name, nr)
	dice.custom_minimum_size = Vector2(64, 40)
	# The tabs, then the chosen tab's rows (room kept for the longest tab,
	# so nothing below jumps when the tab changes).
	tabs = TabRow.new()
	tabs.custom_minimum_size = Vector2(0, 40.0 if small else 42.0)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.set_meta("option", "@tabs")
	tabs.set_meta("page", self)
	tabs.changed = show_tab
	tabs.pressed.connect(_focus_rows)  # Enter or A: into the tab's rows
	right.add_child(tabs)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4 if small else 6)
	var most := 0
	for t in Appearance.TABS:
		most = maxi(most, (t[2] as Array).size())
	var rh := _row_h()
	rows_box.custom_minimum_size.y = most * rh + (most - 1) * (4 if small else 6)
	right.add_child(rows_box)
	if tab == "" or Appearance.TABS.all(func(t): return t[0] != tab):
		tab = Appearance.TABS[0][0]
	show_tab(tab, false)
	tl.focus_neighbor_right = tl.get_path_to(tr)
	tr.focus_neighbor_left = tr.get_path_to(tl)
	rnd.focus_neighbor_right = rnd.get_path_to(finish)
	finish.focus_neighbor_left = finish.get_path_to(rnd)
	name_edit.focus_neighbor_right = name_edit.get_path_to(dice)
	dice.focus_neighbor_left = dice.get_path_to(name_edit)


func _row_h() -> float:
	return 40.0 if m.compact() else 44.0


## Shows a tab's rows (Left / Right on the tabs, a click or a tap on one).
## `sound`: a click as it changes.
func show_tab(id: String, sound := true) -> void:
	tab = id
	if view != null and is_instance_valid(view):
		view.for_tab(id)
	if tabs != null and is_instance_valid(tabs):
		tabs.value = id
		tabs.queue_redraw()
	if rows_box == null or not is_instance_valid(rows_box):
		return
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	rows = {}
	var keys: Array = []
	for t in Appearance.TABS:
		if t[0] == id:
			keys = t[2]
	var names := {}
	for r in Appearance.ROWS:
		names[r[0]] = r[1]
	for key in keys:
		var orow := OptionRow.new()
		orow.key = key
		orow.label = names.get(key, key)
		orow.value = draft.get(key, Appearance.DEFAULTS[key])
		orow.changed = _set_option
		orow.custom_minimum_size = Vector2(0, _row_h())
		orow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orow.set_meta("option", key)
		orow.pressed.connect(_to_finish)  # Enter or A: on to Begin / Done
		rows_box.add_child(orow)
		rows[key] = orow
	first_focus = rows[keys[0]] if not keys.is_empty() else tabs
	_link_focus()
	if sound:
		m.main.sfx("ui_move")


## Up and down run through everything in one loop (the tabs and the rows
## take Left and Right for themselves).
func _link_focus() -> void:
	var order: Array = [name_edit, dice, tabs]
	for c in rows_box.get_children():
		if rows.values().has(c):
			order.append(c)
	order.append_array([rnd, finish, tl, tr])
	for i in order.size():
		var c: Control = order[i]
		c.focus_neighbor_bottom = c.get_path_to(order[(i + 1) % order.size()])
		c.focus_neighbor_top = c.get_path_to(order[(i - 1 + order.size()) % order.size()])
		c.focus_next = c.focus_neighbor_bottom
		c.focus_previous = c.focus_neighbor_top


## Changes one option (a row's arrows, swatches or Left / Right).
func _set_option(key: String, id: String) -> void:
	draft[key] = id
	if tabs != null and is_instance_valid(tabs):
		tabs.queue_redraw()
	if rows.has(key) and is_instance_valid(rows[key]) and rows[key].value != id:
		rows[key].value = id
		rows[key].queue_redraw()
	_apply()
	m.main.sfx("ui_move")


func _name_changed(text: String) -> void:
	draft["name"] = Appearance.clean_name(text)
	_apply()


func _apply() -> void:
	m.main.set_appearance(draft)
	if view != null:
		view.show_look(draft)


## Randomise: a new look (the name stays).
func randomise() -> void:
	draft = Appearance.random(draft)
	_apply()
	if tabs != null and is_instance_valid(tabs):
		tabs.queue_redraw()  # (its dots: which tabs differ from today's look)
	for key in rows:
		rows[key].value = draft[key]
		rows[key].queue_redraw()
	m.main.sfx("ui_confirm")


## The dice: a name from appearance.gd NAMES.
func roll_name() -> void:
	set_name(Appearance.random_name(draft["name"]))
	m.main.sfx("ui_move")


func set_name(text: String) -> void:
	name_edit.text = Appearance.clean_name(text)
	_name_changed(name_edit.text)


## A tap on the name on a phone: in a browser, the browser's own text box
## (its keyboard comes with it); elsewhere the field takes the keys.
func edit_name() -> void:
	if OS.has_feature("web") and m.main.touch_active:
		var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(T["name"]), JSON.stringify(name_edit.text)], true)
		if v != null:
			set_name(str(v))
		return
	name_edit.grab_focus()


func turn(by: int) -> void:
	if view != null:
		view.turn(by)
	m.main.sfx("ui_move")


## Begin: the new climber is made, and the first climb waits.
func begin() -> void:
	m.main.profile.created = true
	m.main.set_appearance(draft)
	m.main.sfx("ui_confirm")
	Engine.set_meta("sixfold_title_seen", true)
	m.close()


func _to_finish() -> void:
	if is_instance_valid(finish):
		finish.grab_focus()


func _focus_rows() -> void:
	if is_instance_valid(first_focus):
		first_focus.grab_focus()


# --- the preview ------------------------------------------------------------------

## The climber, twice: as the tower draws it (a player.gd doll on a patch of
## floor, idling and turnable) and as the climber screen draws it.
class LookView extends Control:
	const Appearance := preload("res://scripts/appearance.gd")
	const PlayerScript := preload("res://scripts/player.gd")
	const UI := preload("res://scripts/ui.gd")
	const Palette := preload("res://scripts/palette.gd")
	const TURN := PI / 4.0
	var figure: Callable
	var doll  # a player.gd node, drawn only
	var look := {}
	var facing := PI * 0.3  # the doll's facing (down and right: its face shows)
	var want := PI * 0.3
	## The figure leans in on the face for the Face and Hair tabs (CLOSE_TABS), 0..1.
	const CLOSE_TABS := ["face", "hair"]
	const CLOSE_ZOOM := 2.3
	var close := 0.0
	var close_want := 0.0

	## Lean in on the face (or step back) for a tab.
	func for_tab(id: String) -> void:
		close_want = 1.0 if id in CLOSE_TABS else 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true  # (the figure, close up, is cut at the preview's edge)
		close = close_want
		doll = PlayerScript.new()
		add_child(doll)
		# A doll: no physics, no collisions, no marks (main is null); it only draws.
		doll.set_physics_process(false)
		doll.collision_layer = 0
		doll.collision_mask = 0
		doll.mouse_aim = false
		if not look.is_empty():
			doll.appearance_look = look
		_place()
		resized.connect(_place)

	## Wear a look (a saved appearance).
	func show_look(app: Dictionary) -> void:
		look = Appearance.look(app)
		if doll != null:
			doll.appearance_look = look
		queue_redraw()

	func turn(by: int) -> void:
		want += TURN * by

	func _place() -> void:
		if doll == null:
			return
		var r := _disc_r()
		doll.position = _doll_at() + Vector2(0, -r * 0.05)
		doll.scale = Vector2.ONE * (r / 28.0)

	func _doll_at() -> Vector2:
		return Vector2(size.x * 0.3, size.y * 0.5)

	func _disc_r() -> float:
		return minf(size.x * 0.27, size.y * 0.42)

	func _process(delta: float) -> void:
		facing = lerp_angle(facing, want, 1.0 - exp(-delta * 10.0))
		if absf(close - close_want) > 0.0005:
			close = lerpf(close, close_want, 1.0 - exp(-delta * 9.0))
			queue_redraw()  # (the figure leaning in or stepping back)
		if doll != null:
			doll.aim = Vector2.from_angle(facing)
			doll.queue_redraw()  # the cloak sways, idling

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		# The doll's patch of tower floor.
		var at := _doll_at()
		var r := _disc_r()
		b.dot(at, r + 6.0, Color(0, 0, 0, 0.25))
		b.dot(at, r, Palette.FLOOR.darkened(0.2))
		b.dot(at + Vector2(-r * 0.15, -r * 0.15), r * 0.75, Palette.FLOOR)
		for i in 3:
			b.line(at + Vector2(-r * 0.8, (i - 1) * r * 0.45), at + Vector2(r * 0.8, (i - 1) * r * 0.45), Color(Palette.FLOOR_GAP, 0.5), 1.0)
		b.dot(at, r * 0.95, Color(Palette.TORCH, 0.04))
		b.flush(self)
		# The figure as the climber screen draws it.
		if figure.is_valid() and not look.is_empty():
			var k := minf(size.y / 300.0, size.x * 0.4 / 140.0)
			var c := Vector2(size.x * 0.76, size.y * 0.5 + 6.0 * k)
			# Close up: the head (about y -100 on the figure) to the middle, bigger.
			var kc := k * CLOSE_ZOOM
			var cc := Vector2(size.x * 0.76, size.y * 0.5 + 92.0 * kc)
			var e := smoothstep(0.0, 1.0, close)
			k = lerpf(k, kc, e)
			c = c.lerp(cc, e)
			draw_set_transform(c, 0.0, Vector2(k, k))
			var fb := UI.Draw.Batch.new()
			fb.polygon(UI._oval(Vector2(0, 126), Vector2(62, 10), 24), Color(0, 0, 0, 0.3))
			figure.call(fb, look)
			fb.flush(self)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- the tabs --------------------------------------------------------------------

## The tabs (appearance.gd TABS) as one button, like an option row: Left and
## Right (the d-pad or stick) change the tab; a click or tap on one picks it;
## Enter or A goes into its rows. A small dot under a tab's name shows it
## holds something other than today's look.
class TabRow extends Button:
	const Appearance := preload("res://scripts/appearance.gd")
	const UI := preload("res://scripts/ui.gd")
	var value := ""
	var changed: Callable  # (tab id)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""

	func _ids() -> Array:
		return Appearance.TABS.map(func(t): return t[0])

	func change(by: int) -> void:
		var ids := _ids()
		choose(ids[(maxi(0, ids.find(value)) + by + ids.size()) % ids.size()])

	func choose(id: String) -> void:
		if id == value:
			return
		value = id
		queue_redraw()
		if changed.is_valid():
			changed.call(id)

	## A click or tap at a point on screen (menu.gd sends taps here).
	func tap_at(pos: Vector2) -> void:
		grab_focus()
		_hit(get_global_transform().affine_inverse() * pos)

	func _hit(p: Vector2) -> void:
		var ids := _ids()
		choose(ids[clampi(int(p.x / (size.x / ids.size())), 0, ids.size() - 1)])

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_hit(event.position)
			accept_event()
		elif event.is_action_pressed("ui_left", true):
			change(-1)
			accept_event()
		elif event.is_action_pressed("ui_right", true):
			change(1)
			accept_event()

	## True if a tab's rows hold anything but today's look.
	func _changed(t: Array, page) -> bool:
		if page == null:
			return false
		for key in t[2]:
			if str(page.draft.get(key, "")) != str(Appearance.DEFAULTS[key]):
				return true
		return false

	func _draw() -> void:
		var font := UI.font("display")
		var on := has_focus()
		var n := Appearance.TABS.size()
		var w := size.x / n
		var h := size.y
		var page = get_meta("page", null)
		draw_style_box(UI.box(Color(1, 1, 1, 0.03), Color(UI.GOLD, 0.3 if on else 0.08), 6), Rect2(Vector2.ZERO, size))
		for i in n:
			var t: Array = Appearance.TABS[i]
			var r := Rect2(w * i + 2.0, 3.0, w - 4.0, h - 6.0)
			var chosen: bool = t[0] == value
			if chosen:
				draw_style_box(UI.box(Color(UI.GOLD, 0.16 if on else 0.1), Color(UI.GOLD, 0.85 if on else 0.5), 5, 1 if not on else 2), r)
			var fs := UI.fit_size(font, String(t[1]), 16, r.size.x - 6.0)
			var col: Color = UI.GOLD if chosen and on else (UI.TEXT if chosen else UI.DIM)
			draw_string(font, Vector2(r.position.x, h * 0.5 + fs * 0.32), String(t[1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
			if _changed(t, page):
				draw_circle(Vector2(r.get_center().x, h - 7.0), 1.8, Color(UI.GOLD, 0.8) if chosen else UI.FAINT)
		if on:  # the arrows that change it, at either end
			for side in [-1.0, 1.0]:
				var c := Vector2(6.0 if side < 0.0 else size.x - 6.0, h * 0.5)
				draw_polyline(PackedVector2Array([c + Vector2(-2.5 * side, -4.0), c + Vector2(2.5 * side, 0.0), c + Vector2(-2.5 * side, 4.0)]), Color(UI.GOLD, 0.8), 1.6, true)


# --- an option row ------------------------------------------------------------------

## One option as a single button: its name, the arrows either side, and the
## choices between them (swatches for colours, else the choice's name). Left
## and Right change it; a click or tap on an arrow or a swatch too. Enter or
## A (pressed) goes on to Begin / Done.
class OptionRow extends Button:
	const Appearance := preload("res://scripts/appearance.gd")
	const UI := preload("res://scripts/ui.gd")
	const ARROW := 42.0
	var key := ""
	var label := ""
	var value := ""
	var changed: Callable  # (key, id)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""

	func _label_w() -> float:
		return clampf(size.x * 0.24, 92.0, 118.0)

	func change(by: int) -> void:
		value = Appearance.step({key: value}, key, by)
		queue_redraw()
		if changed.is_valid():
			changed.call(key, value)

	func choose(id: String) -> void:
		if id == value:
			return
		value = id
		queue_redraw()
		if changed.is_valid():
			changed.call(key, value)

	## A click or tap at a point on screen (menu.gd sends taps here).
	func tap_at(pos: Vector2) -> void:
		_hit(get_global_transform().affine_inverse() * pos)

	func _hit(p: Vector2) -> void:
		var lx := _label_w()
		if p.x >= lx - 4.0 and p.x < lx + ARROW + 2.0:
			change(-1)
		elif p.x > size.x - ARROW - 8.0:
			change(1)
		elif p.x > lx + ARROW and Appearance.has_colors(key):
			var list: Array = Appearance.OPTIONS[key]
			var mid := _middle()
			var i := clampi(int((p.x - mid.position.x) / (mid.size.x / list.size())), 0, list.size() - 1)
			choose(list[i][0])
		else:
			change(1)

	func _middle() -> Rect2:
		var lx := _label_w() + ARROW + 6.0
		return Rect2(lx, 0.0, size.x - lx - ARROW - 12.0, size.y)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_hit(event.position)
			accept_event()
		elif event.is_action_pressed("ui_left", true):
			change(-1)
			accept_event()
		elif event.is_action_pressed("ui_right", true):
			change(1)
			accept_event()

	func _draw() -> void:
		var font := get_theme_font("font")
		var h := size.y
		var lx := _label_w()
		var on := has_focus()
		var name := Appearance.option_name(key, value)
		var colors := Appearance.has_colors(key)
		# The option's name (and, for swatches, the choice's name under it).
		if colors:
			draw_string(font, Vector2(12, h * 0.5 - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, lx - 14.0, 16, UI.TEXT if on else UI.DIM)
			draw_string(font, Vector2(12, h * 0.5 + 13.0), name, HORIZONTAL_ALIGNMENT_LEFT, lx - 14.0, 13, UI.GOLD if on else UI.FAINT)
		else:
			draw_string(font, Vector2(12, h * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, lx - 14.0, 16, UI.TEXT if on else UI.DIM)
		# The arrows.
		for side in [-1.0, 1.0]:
			var r := Rect2(lx, 4.0, ARROW, h - 8.0) if side < 0.0 else Rect2(size.x - ARROW - 6.0, 4.0, ARROW, h - 8.0)
			draw_style_box(UI.box(Color(1, 1, 1, 0.05), Color(UI.GOLD, 0.35 if on else 0.1), 5), r)
			var c := r.get_center()
			var pts := PackedVector2Array([c + Vector2(-4.0 * side, -6.0), c + Vector2(4.0 * side, 0.0), c + Vector2(-4.0 * side, 6.0)])
			draw_polyline(pts, UI.GOLD if on else UI.DIM, 2.0, true)
		var mid := _middle()
		if colors:
			var list: Array = Appearance.OPTIONS[key]
			var cell := mid.size.x / list.size()
			var rad := clampf(cell * 0.3, 5.0, 10.0)
			for i in list.size():
				var at := Vector2(mid.position.x + cell * (i + 0.5), h * 0.5)
				var col: Color = list[i][2]
				var blank := Appearance.is_blank(key, list[i][0])  # (no trim; trousers like the tunic)
				if list[i][0] == value:
					draw_circle(at, rad + 4.5, UI.GOLD if on else Color(UI.GOLD, 0.7))
					draw_circle(at, rad + 3.0, UI.OUTLINE)
					if not blank:
						draw_circle(at, rad + 1.5, col)
				else:
					draw_circle(at, rad + 1.2, UI.OUTLINE)
					if not blank:
						draw_circle(at, rad, col)
						draw_circle(at + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.3, Color(1, 1, 1, 0.18))
				if blank:  # an empty swatch, struck through
					draw_arc(at, rad, 0.0, TAU, 20, UI.DIM, 1.4, true)
					draw_line(at + Vector2(-rad * 0.7, rad * 0.7), at + Vector2(rad * 0.7, -rad * 0.7), UI.DIM, 1.4, true)
		else:
			draw_string(font, Vector2(mid.position.x, h * 0.5 + 2.0), name, HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, 17, UI.GOLD if on else UI.TEXT)
			var list2: Array = Appearance.OPTIONS[key]
			var n := list2.size()
			for i in n:
				var at2 := Vector2(mid.get_center().x + (i - (n - 1) * 0.5) * 9.0, h * 0.5 + 11.0)
				draw_circle(at2, 2.2 if list2[i][0] == value else 1.6, UI.GOLD if list2[i][0] == value else UI.FAINT)
