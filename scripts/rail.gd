extends Control
## The menu's left rail (menu.gd): a column down the left of the screen
## that the pause menu, the climber screen, the inventory, the Library,
## Settings & Controls and the dev tools all share, so moving between them
## is one press. At the top, who you are: your name, where you are (the
## tower and floor, or the train) and your six marks as small medallions.
## That block is itself a button: it opens the climber screen, and it's the
## rail's first stop for the keys and the controller. Then the pages; at
## the bottom Exit.
##
## Keys and controller: up and down move along the rail and show each page
## as you go; Right, Enter or A goes into the page; Left from a page comes
## back to the page's own item; Esc, B or a right-click comes back to the
## rail, and from the rail closes the menu. Mouse: hovering moves the focus,
## a click goes in. Touch: tap an item. On a phone the rail narrows to icons
## with short names. (menu.gd _nav and nav.gd do the moving.)
##
## On the train the rail is always there, and it's the train's own
## navigation, in the owner's order: who you are (the climber screen), the
## six cars front to back (choosing one moves the train there, and the light
## follows the train when you swipe or press Q / E), then Dev Tools (a page
## beside it), Exit to Title Station and, on a computer, Quit game. The rail
## stays put between a car and a page: only its light moves.
##
## A second look for the train's rail, behind a dev-tools toggle (menu.gd
## settings "train_rail"): the same items, order and behaviour, drawn as the
## train itself standing on end: the engine at the top with its smokestack
## and cowcatcher, each car below it joined by couplings and running on a
## track down the left edge, the station's sign over the engine and a
## platform under the last car holding the other items.
##
## The words live in CLIMBER, ITEMS, TRAIN_CARS, TRAIN_PAGES, FOOT,
## TRAIN_FOOT, FOOT_QUIT and TEXT.

const UI := preload("res://scripts/ui.gd")
const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")
const Train := preload("res://scripts/train.gd")
const Art := preload("res://scripts/train_art.gd")
const ArrangeUI := preload("res://scripts/arrange_ui.gd")
const Stations := preload("res://scripts/stations.gd")
const StationView := preload("res://scripts/station_view.gd")
const Renown := preload("res://scripts/renown.gd")

## The identity block at the top (a button: the climber screen): [id, name,
## short name, line, icon].
const CLIMBER := ["climber", "Climber", "Climber", "Abilities, marks, essence, record", "climber"]
## The pages in a climb (the pause menu): [id, name, short name (a phone), a
## line under the name (a computer), icon]. The icons are drawn in ui.gd
## draw_icon, or below (car_icon). Library and Settings & Controls carry the
## train's names, as single pages here.
const ITEMS := [
	["resume", "Resume", "Resume", "Back to the climb", "resume"],
	["inventory", "Inventory", "Bag", "Gear, items, heirlooms", "inventory"],
	["library", "Library", "Library", "What the Entity told you", "book"],
	["settings", "Settings & Controls", "Settings", "Sound, screen, every key", "lever"],
	["dev", "Dev Tools", "Dev", "For testing", "dev"],
]
## On the train the rail lists the cars, front to back: [short name (a
## phone), a line under the name (a computer), icon]. Their full names are
## train.gd CARS; the icons are drawn below (car_icon).
const TRAIN_CARS := {
	"engine": ["Engine", "Choose a tower, depart", "engine"],
	"store": ["Outfitter", "Supplies, outfit, selling", "scales"],
	"personal": ["Your Car", "Loadout, pack, stash", "bed"],
	"workshop": ["Workshop", "The bench", "anvil"],
	"library": ["Library", "What the Entity told you", "book"],
	"settings": ["Settings", "Sound, screen, every key", "lever"],
}
## ...then these pages, under a rule (opened beside the rail).
const TRAIN_PAGES := ["dev"]
## Along the bottom, in a climb...
const FOOT := [
	["exit", "Exit to Title", "Exit", "", "exit"],
]
## ...and on the train.
const TRAIN_FOOT := [
	["exit", "Exit to Title Station", "Station", "", "station"],
]
## At a station (stations.gd): its stops are the rail's items, then this at
## the foot (the train waits at the platform).
const STATION_FOOT := [["leave_station", "Back to the train", "Train", "", "train"]]
## On the train on a computer, under them (the train has no pause page to
## hold it; a browser or a phone can't quit, menu.gd can_quit).
const FOOT_QUIT := ["quit", "Quit game", "Quit", "", "quit"]
const TEXT := {
	"unnamed": "Unnamed climber",
	"on_train": "On the train",
	"first_climb": "The first climb",
	"place": "%s  ·  floor %d",
	"practice": "Practice",  # (the practice room: practice.gd)
	"hint_keys": "↑ ↓ choose   → enter   Esc close",
	"hint_pad": "↑ ↓ choose   {a} enter   {b} close",
	"hint_keys_train": "↑ ↓ choose   → enter   Q E cars",
	"hint_pad_train": "↑ ↓ choose   {a} enter   {lb} {rb} cars",
	"hint_keys_station": "↑ ↓ choose   → enter   Q E stops",
	"hint_pad_station": "↑ ↓ choose   {a} enter   {lb} {rb} stops",
	"station": "Title Station",  # the sign over the engine, the train on end
}

## Widths: a computer, and a phone (drawn 1.5x, so in its own units).
const WIDE := 236.0
const NARROW := 132.0
## On the train, the smallest the cars' rows get: [phone, computer] (a
## phone's at the old 1.5x scale: a bigger Interface size lets them go
## shorter in view px, as they're as tall on the glass, down to ROW_FLOOR;
## see row_min)...
const ROW_MIN := [30.0, 36.0]
const ROW_FLOOR := 24.0
## Below this view height the column packs tighter (and scrolls if it must).
const SHORT_H := 340.0
## ...and the tallest; the train on end: its cars.
const ROW_MAX := [38.0, 46.0]
const END_MAX := [52.0, 66.0]
const ENGINE_EXTRA := 0.9

var menu  # menu.gd
var narrow := false
var buttons: Array = []  # the rail's items, top to bottom: who you are, the pages (or cars), the foot
var current := ""  # the item lit as the page you're on
var at_car := ""  # on the train: the car you're in (marked while a page shows)
var on_train := false
var on_end := false  # the train's rail drawn as the train standing on end
var at_station := ""  # the station you're at ("" on the train): its stops are the items
var ident: RailIdent
var list: VBoxContainer
var pane: ScrollContainer  # holds the column; scrolls on a short screen
var foot_box: VBoxContainer
var hint: Label
var _built_for := ""  # what the items were built for (train / climb, wide / narrow, touch, look)
var _built_pad := false  # ...and the keys' names they show (a controller, a PlayStation one)
var _built_ps := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## How wide the rail is on this screen (wider or narrower if Arrange mode
## resized it: arrange_ui.gd).
static func width_for(compact: bool) -> float:
	return (NARROW if compact else WIDE) * ArrangeUI.rail_width_k()


## The look chosen for the train's rail in dev tools: "menu" or "end".
func _look() -> String:
	if menu == null:
		return "menu"
	return str(menu.settings.get("train_rail", "menu"))


## Builds (or refreshes) the rail for the page showing.
func refresh(page_item: String, train: bool, compact: bool, touch: bool, pad: bool, ps: bool) -> void:
	var st: String = menu.station_page.station if train and menu != null and menu.has_method("at_station") and menu.at_station() else ""
	var key := "%s %s %s %s %s %s %s" % [train, compact, touch, _look(), _short(), st, Renown.worn_title(menu.main.profile) != "" if menu != null and menu.main != null and menu.main.profile != null else false]
	on_train = train
	narrow = compact
	at_station = st
	on_end = train and _look() == "end" and st == ""
	if key != _built_for or buttons.is_empty():
		_built_for = key
		_build(touch, pad, ps)
	elif pad != _built_pad or ps != _built_ps:
		# Only the keys' names changed (a controller picked up or put down):
		# rename them in place, so the item you're on keeps the focus and the
		# first press of the new device still lands on it.
		for b in buttons:
			b.key_hint = _key_for(b.id, touch, pad, ps)
		if hint != null:
			hint.text = _hint_text(pad, ps)
	_built_pad = pad
	_built_ps = ps
	current = page_item
	at_car = menu.train_car if train and menu != null else ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	for b in buttons:
		b.mouse_filter = Control.MOUSE_FILTER_STOP  # (closing the menu turned them off)
		b.on = b.id == current
		b.queue_redraw()
	queue_redraw()


func _build(touch: bool, pad: bool, ps: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	buttons.clear()
	# The column of items, in a pane that scrolls if a short screen (a big
	# Interface size) can't hold them all; a drag on the rail scrolls it.
	pane = ScrollContainer.new()
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	pane.follow_focus = true
	pane.mouse_filter = Control.MOUSE_FILTER_PASS
	var side := 8.0 if narrow else 14.0
	pane.offset_left = side
	pane.offset_right = -side - 3.0
	pane.offset_top = 8.0 if narrow else 20.0
	pane.offset_bottom = -(6.0 if narrow else 14.0)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4 if narrow else 10)
	if on_train:
		# (six cars as well as the pages: everything packs a little closer)
		pane.offset_top = 6.0 if narrow else 16.0
		pane.offset_bottom = -(4.0 if narrow else 10.0)
		col.add_theme_constant_override("separation", 2 if narrow else 6)
	if on_end:
		# The train on end: a track down the left edge, the cars on it.
		pane.offset_left = 4.0 if narrow else 8.0
		pane.offset_right = -(5.0 if narrow else 9.0)
		pane.offset_top = 4.0 if narrow else 10.0
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pane)
	pane.add_child(col)
	if _short():
		col.add_theme_constant_override("separation", 1)
	# Who you are: a button for the climber screen, the first stop.
	ident = RailIdent.new()
	ident.rail = self
	_setup(ident, CLIMBER, _key_for("climber", touch, pad, ps))
	ident.custom_minimum_size.y = 62.0 if narrow else 112.0
	if on_train:
		ident.eyebrow = not narrow  # (a phone: the cars below say where you are)
		ident.custom_minimum_size.y = 40.0 if narrow else 104.0
	if on_end:
		ident.custom_minimum_size.y = 46.0 if narrow else 96.0
	if menu != null and menu.main != null and menu.main.profile != null and Renown.worn_title(menu.main.profile) != "":
		ident.custom_minimum_size.y += 10.0 if narrow else 16.0  # (the title worn, under the name)
	col.add_child(ident)
	buttons.append(ident)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 1 if narrow else 3)
	if on_end:
		list.add_theme_constant_override("separation", 8 if narrow else 12)  # (the couplings between cars)
		list.sort_children.connect(queue_redraw)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(list)
	var foot_items: Array = (TRAIN_FOOT if on_train else FOOT).duplicate()
	if at_station != "":
		foot_items = STATION_FOOT.duplicate()
		for stop in Stations.stops(at_station):
			var info: Dictionary = Stations.STOPS.get(stop, {})
			var b := _item(list, [stop, String(info.get("name", stop)), String(info.get("short", stop)), String(info.get("line", "")), stop], "")
			b.row = true
	elif on_train:
		_train_items(list, touch, pad, ps)
		if menu != null and menu.can_quit():
			foot_items.append(FOOT_QUIT)
	else:
		for it in ITEMS:
			_item(list, it, _key_for(it[0], touch, pad, ps))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	foot_box = VBoxContainer.new()
	foot_box.add_theme_constant_override("separation", 1 if narrow else 2)
	foot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot_box)
	if on_end:
		# The platform under the last car: Dev Tools, then the way out.
		foot_box.sort_children.connect(queue_redraw)
		var edge := Control.new()
		edge.custom_minimum_size.y = 8.0 if narrow else 12.0
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot_box.add_child(edge)
		var on_platform: Array = []
		for id in TRAIN_PAGES:
			for it in ITEMS:
				if it[0] == id:
					on_platform.append(it)
		on_platform.append_array(foot_items)
		var parent: Container = foot_box
		if narrow:
			# A phone: the platform's signs side by side, each its icon over its name.
			parent = HBoxContainer.new()
			parent.add_theme_constant_override("separation", 3)
			parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			foot_box.add_child(parent)
		for it in on_platform:
			var b := _item(parent, it, "")
			b.small = true
			b.custom_minimum_size.y = 30.0
			if narrow:
				b.tile = true
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.custom_minimum_size.y = 40.0
	else:
		var sep := RailRule.new()
		sep.custom_minimum_size.y = 6.0 if narrow else 9.0
		foot_box.add_child(sep)
		for it in foot_items:
			var b := _item(foot_box, it, "")
			b.small = true
			if on_train:
				b.custom_minimum_size.y = 36.0 if narrow else 32.0
	hint = null
	if not narrow and not touch:
		hint = Label.new()
		hint.text = _hint_text(pad, ps)
		UI.style_label(hint, "body", 12, Color(UI.FAINT, 0.9))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.custom_minimum_size.x = 60.0
		col.add_child(hint)
	# Up and down stay on the rail (and wrap round); left stays put.
	for i in buttons.size():
		var b: Control = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
		b.focus_neighbor_left = b.get_path_to(b)
	_fit_rows.call_deferred()
	queue_redraw()


## On the train, the cars' rows share the height left over, so they all fit
## any screen without a scroll: as tall as a computer's usual rows where
## there's room, down to ROW_MIN (a phone's landscape screen). (The train on
## end: its cars grow taller, to END_MAX, so the train fills the rail.)
func _fit_rows() -> void:
	if not is_inside_tree() or not on_train or list == null:
		return
	var rows: Array = buttons.filter(func(b): return b.row)
	if rows.is_empty():
		return
	var k := 1 if not narrow else 0
	var want: float = END_MAX[k] if on_end else ROW_MAX[k]
	var lo := row_min()
	var h := size.y if size.y > 0.0 else get_viewport_rect().size.y
	var col: Control = list.get_parent()
	var fixed := 0.0  # everything but the rows, at their smallest
	for c in col.get_children():
		if c != list:
			fixed += c.get_combined_minimum_size().y
	fixed += col.get_theme_constant("separation") * (col.get_child_count() - 1)
	fixed += pane.offset_top - pane.offset_bottom
	for c in list.get_children():
		if not rows.has(c):
			fixed += c.get_combined_minimum_size().y
	fixed += list.get_theme_constant("separation") * (list.get_child_count() - 1)
	# (the train on end: the engine stands half as tall again as a car)
	var share := rows.size() + (ENGINE_EXTRA if on_end else 0.0)
	var each := clampf(floorf((h - fixed) / share), lo, maxf(want, lo))
	for b in rows:
		var want_h := floorf(each * (1.0 + ENGINE_EXTRA)) if on_end and b.id == "engine" else each
		if b.custom_minimum_size.y != want_h:
			b.custom_minimum_size.y = want_h
	queue_redraw()


## The shortest a car's row gets on this screen (see ROW_MIN).
func row_min() -> float:
	if not narrow:
		return ROW_MIN[1]
	var csf := get_tree().root.content_scale_factor if is_inside_tree() else 1.5
	return maxf(ROW_FLOOR, ROW_MIN[0] * 1.5 / maxf(csf, 1.5))


## A short screen (a phone at a big Interface size): the column packs tighter.
func _short() -> bool:
	return is_inside_tree() and get_viewport_rect().size.y < SHORT_H


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and on_train:
		_fit_rows.call_deferred()


## The line of keys under the rail (on a computer).
func _hint_text(pad: bool, ps: bool) -> String:
	if at_station != "":
		return Controls.pad_text(TEXT["hint_pad_station"], ps) if pad else TEXT["hint_keys_station"]
	if on_train:
		return Controls.pad_text(TEXT["hint_pad_train"], ps) if pad else TEXT["hint_keys_train"]
	return Controls.pad_text(TEXT["hint_pad"], ps) if pad else TEXT["hint_keys"]


## The train's rail: its cars, front to back, then a rule and the pages
## (the train on end puts the pages on its platform, with the foot).
func _train_items(parent: Node, touch: bool, pad: bool, ps: bool) -> void:
	for c in Train.CARS:
		var row: Array = TRAIN_CARS.get(c[0], [c[1], "", "car"])
		var b := _item(parent, [c[0], c[1], row[0], row[1], row[2]], "")
		b.row = true
		b.car = true
	if on_end:
		return
	var sep := RailRule.new()
	sep.custom_minimum_size.y = 6.0 if narrow else 12.0
	parent.add_child(sep)
	for id in TRAIN_PAGES:
		for it in ITEMS:
			if it[0] == id:
				var b := _item(parent, it, _key_for(id, touch, pad, ps))
				b.custom_minimum_size.y = 36.0 if narrow else 40.0


## True for a car's item on the train's rail.
## Where the climber is, over their name: on the train, in the practice
## room (practice.gd), or a tower and floor.
func place_text(main) -> String:
	if main.on_train and at_station != "":
		var st: Dictionary = Stations.station(at_station)
		return String(st.get("short", "")) if narrow else String(st.get("name", ""))
	if main.on_train:
		return TEXT["on_train"] if not on_end else TEXT["station"]
	if main.get("arena") != null and main.arena.on:
		return Stations.stop_name(String(main.arena.ev.get("stop", "arena")))
	if main.get("practice") != null and main.practice.on:
		return TEXT["practice"]
	if main.has_method("tower_data"):
		var td: Dictionary = main.tower_data()
		return TEXT["place"] % [td.get("short", td["name"]) if narrow else td["name"], main.floor_num]
	return ""


static func is_car(id: String) -> bool:
	return TRAIN_CARS.has(id)


## Lights an item (the page or car showing) without building anything again;
## on the train, `car` is the car you're in.
func light(id: String, car := "") -> void:
	current = id
	at_car = car
	for b in buttons:
		b.on = b.id == current
		b.queue_redraw()
	queue_redraw()


## The key that opens a page directly, shown faintly beside it (not on a phone).
func _key_for(id: String, touch: bool, pad: bool, ps: bool) -> String:
	if touch:
		return ""
	match id:
		"climber":
			return Controls.pad_text("{back}", ps) if pad else "Tab"
		"inventory":
			return "" if pad else "I"  # (the d-pad moves the focus in a menu: nothing to show)
		"resume":
			return Controls.pad_text("{start}", ps) if pad else "Esc"
	return ""


func _setup(b, row: Array, key: String) -> void:
	b.id = row[0]
	b.text = row[1]
	b.short = row[2]
	b.sub = row[3]
	b.icon_id = row[4]
	b.key_hint = key
	b.set_meta("rail", row[0])
	b.pressed.connect(func(): menu.rail_pressed(b.id))
	b.focus_entered.connect(func(): menu.rail_focused(b.id))


func _item(parent: Node, row: Array, key: String) -> RailItem:
	var b := RailItem.new()
	b.rail = self
	_setup(b, row, key)
	b.custom_minimum_size = Vector2(0, (38.0 if narrow else 46.0))  # (a phone: still big enough to tap)
	parent.add_child(b)
	buttons.append(b)
	return b


## The button for an item, or null.
func button(id: String) -> Control:
	for b in buttons:
		if b.id == id:
			return b
	return null


## True while one of the rail's items has the keyboard and controller focus.
func has_focus_inside() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and buttons.has(f)


## Focus the item lit for the page showing (or the first).
func focus_current() -> void:
	var b := button(current)
	if b == null and not buttons.is_empty():
		b = buttons[0]
	if b != null and b.is_inside_tree():
		menu._rail_grab = true
		b.grab_focus()
		menu._rail_grab = false


## True while the keys' focus should show on an item (on a phone nothing
## shows a focus outline).
func shows_focus(b: Control) -> bool:
	return b.has_focus() and not (menu != null and menu.main != null and menu.main.touch_active)


## The rail's slab: darker than the page, lit faintly at the top, with a
## thin line and a gilt hairline down its right edge. The train on end adds
## its track down the left edge, the couplings between the cars and the
## platform under the last car.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)])
	draw_polygon(pts, PackedColorArray([Color(0.1, 0.086, 0.14, 0.97), Color(0.1, 0.086, 0.14, 0.97), Color(0.045, 0.038, 0.065, 0.97), Color(0.045, 0.038, 0.065, 0.97)]))
	# A soft violet light from the top.
	var gh := minf(size.y * 0.4, 260.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, gh), Vector2(0, gh)]),
		PackedColorArray([Color(UI.VIOLET, 0.07), Color(UI.VIOLET, 0.07), Color(UI.VIOLET, 0.0), Color(UI.VIOLET, 0.0)]))
	if on_end:
		_draw_end()
	draw_line(Vector2(size.x - 0.5, 0), Vector2(size.x - 0.5, size.y), Color(UI.LINE_HI, 0.8), 1.0)
	draw_line(Vector2(size.x - 3.5, 0), Vector2(size.x - 3.5, size.y), Color(UI.GILT, 0.14), 1.0)


## Where an item stands, in the rail's own space.
func _rect_of(c: Control) -> Rect2:
	var inv := get_global_transform().affine_inverse()
	var gr := c.get_global_rect()
	return Rect2(inv * gr.position, inv.basis_xform(gr.size))


## The train on end, behind its cars: the track (two iron rails on sleepers)
## from the engine's nose down to the platform, a coupling between each two
## cars, and the platform's boards with a painted edge.
func _draw_end() -> void:
	var cars: Array = buttons.filter(func(b): return b.car)
	if cars.is_empty() or foot_box == null:
		return
	var b := UI.Draw.Batch.new()
	var first: Rect2 = _rect_of(cars[0])
	var plat := _rect_of(foot_box)
	var lane := RailItem.lane(narrow)
	var x0 := first.position.x + lane * 0.5 - 3.0
	var top := first.position.y - 2.0
	var bottom := plat.position.y + 4.0
	# The sleepers, then the two rails.
	var y := top
	while y < bottom:
		b.rect(Rect2(x0 - 3.0, y, 12.0, 2.5), Color(0.2, 0.13, 0.08, 0.9))
		y += 7.0
	for rx in [x0, x0 + 5.0]:
		b.rect(Rect2(rx, top, 1.6, bottom - top), Color(0.42, 0.4, 0.45))
		b.rect(Rect2(rx, top, 0.6, bottom - top), Color(0.8, 0.78, 0.85, 0.6))
	# The couplings: a dark draw-bar and a brass link between two cars.
	for i in cars.size() - 1:
		var a: Rect2 = _rect_of(cars[i])
		var c: Rect2 = _rect_of(cars[i + 1])
		var cx := a.position.x + lane + (a.size.x - lane) * 0.42
		var y0 := a.end.y - 3.0
		var y1 := c.position.y + 3.0
		b.rect(Rect2(cx - 2.5, y0, 5.0, y1 - y0), Art.OUTLINE)
		b.rect(Rect2(cx - 1.5, y0, 3.0, y1 - y0), Art.IRON.lightened(0.25))
		var mid := (y0 + y1) * 0.5
		b.rect(Rect2(cx - 4.0, mid - 1.6, 8.0, 3.2), Art.OUTLINE)
		b.rect(Rect2(cx - 3.2, mid - 1.0, 6.4, 2.0), Art.GILT.darkened(0.15))
		# (and a bellows between them, on the roof side)
		var bx: float = a.end.x - RailItem.ROOF[1 if not narrow else 0] - 14.0
		b.rect(Rect2(bx, y0, 10.0, y1 - y0), Color(0.08, 0.06, 0.08))
		for k in 3:
			b.rect(Rect2(bx, y0 + (y1 - y0) * (k + 0.5) / 3.0, 10.0, 0.8), Color(0.3, 0.25, 0.3))
	# The platform: boards, lit by a lamp, with a pale painted edge.
	var pr := Rect2(0.0, plat.position.y + 2.0, size.x - 4.0, size.y - plat.position.y - 2.0)
	Art.vgrad(b, pr, Color(0.2, 0.15, 0.12), Color(0.08, 0.06, 0.06))
	var py := pr.position.y + 6.0
	var row := 0
	while py < pr.end.y:
		b.rect(Rect2(pr.position.x, py, pr.size.x, 1.0), Color(0, 0, 0, 0.45))
		var px := 18.0 + 37.0 * Art.rnd(row)
		while px < pr.end.x:
			b.rect(Rect2(px, py - 9.0, 1.0, 9.0), Color(0, 0, 0, 0.3))
			px += 64.0
		py += 10.0
		row += 1
	b.rect(Rect2(pr.position.x, pr.position.y, pr.size.x, 3.0), Color(0.86, 0.8, 0.62, 0.85))
	b.rect(Rect2(pr.position.x, pr.position.y + 3.0, pr.size.x, 2.0), Color(0, 0, 0, 0.5))
	Art.light(b, Vector2(pr.size.x * 0.5, pr.position.y + 4.0), Vector2(pr.size.x * 0.7, 40.0), Color(Art.LAMP, 0.12))
	# The end of the line: buffers past the last car, where the track meets the platform.
	var bf := Vector2(x0 + 2.5, plat.position.y - 1.0)
	b.rect(Rect2(bf.x - 6.0, bf.y - 4.0, 12.0, 5.0), Art.OUTLINE)
	b.rect(Rect2(bf.x - 5.0, bf.y - 3.0, 10.0, 3.0), Color(0.55, 0.12, 0.1))
	b.flush(self)


## The train's cars' icons, and the rail's own, drawn like ui.gd draw_icon
## (on a 20 x 20 grid around the centre, in lines of width `w`): the engine a
## locomotive, your car a bed, the outfitter's a pair of scales, the workshop
## an anvil and hammer, the Library a bound book, Settings & Controls a
## signal lever, Exit to Title Station a station lamp (and Quit game's power
## switch). False for any other icon (ui.gd draws those).
static func car_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, w := 1.6) -> bool:
	if StationView.icon(ci, id, c, s, col, w):
		return true  # (a station's stops: station_view.gd)
	var u := s / 10.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"engine":  # a locomotive facing left: boiler, cab and its window, chimney, wheels, cowcatcher
			ci.draw_polyline(PackedVector2Array([P.call(-9, 4), P.call(-9, -2.5), P.call(2, -2.5), P.call(2, -8), P.call(9, -8), P.call(9, 4), P.call(-9, 4)]), col, w, true)
			ci.draw_rect(Rect2(P.call(4.2, -5.8), Vector2(2.8, 2.6) * u), Color(col, 0.55))
			ci.draw_polyline(PackedVector2Array([P.call(-6.8, -2.5), P.call(-6.8, -6.5), P.call(-8, -8.5), P.call(-3.6, -8.5), P.call(-4.8, -6.5), P.call(-4.8, -2.5)]), col, w, true)
			ci.draw_line(P.call(-1.5, -2.5), P.call(-1.5, 4), Color(col, 0.55), maxf(1.0, w * 0.7), true)
			ci.draw_line(P.call(-9, 4), P.call(-10.5, 7.5), col, w, true)
			ci.draw_arc(P.call(-4.5, 6.6), 2.2 * u, 0, TAU, 12, col, w, true)
			ci.draw_arc(P.call(4.5, 6.6), 2.2 * u, 0, TAU, 12, col, w, true)
		"bed":  # a bed: a tall headboard, a pillow, the blanket and a low footboard
			ci.draw_line(P.call(-9, -7), P.call(-9, 8), col, w, true)
			ci.draw_line(P.call(9, -1), P.call(9, 8), col, w, true)
			ci.draw_polyline(PackedVector2Array([P.call(-9, 4), P.call(9, 4)]), col, w, true)
			ci.draw_polyline(PackedVector2Array([P.call(-9, -7), P.call(-7, -8), P.call(-7, 1)]), col, w, true)
			var pillow := PackedVector2Array()
			for i in 13:
				var a := TAU * i / 12.0
				pillow.append(P.call(-4.5, -1.5) + Vector2(cos(a) * 2.6, sin(a) * 1.5) * u)
			ci.draw_polyline(pillow, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.5, 0), P.call(9, 0), P.call(9, 4), P.call(-1.5, 4)]), Color(col, 0.4))
			ci.draw_line(P.call(-1.5, 0), P.call(9, 0), col, w, true)
		"scales":  # a balance: the post on its foot, the beam, two hanging pans
			ci.draw_line(P.call(0, -8), P.call(0, 8), col, w, true)
			ci.draw_line(P.call(-4, 8.5), P.call(4, 8.5), col, w, true)
			ci.draw_line(P.call(-8, -5), P.call(8, -5), col, w, true)
			ci.draw_circle(P.call(0, -8.5), 1.2 * u, col)
			for sx in [-1.0, 1.0]:
				var top: Vector2 = P.call(7.5 * sx, -5)
				ci.draw_line(top, P.call(7.5 * sx - 3.5, 2), Color(col, 0.8), maxf(1.0, w * 0.75), true)
				ci.draw_line(top, P.call(7.5 * sx + 3.5, 2), Color(col, 0.8), maxf(1.0, w * 0.75), true)
				ci.draw_arc(P.call(7.5 * sx, 2), 3.6 * u, 0.0, PI, 10, col, w, true)
		"quit":  # a power switch: a broken ring and a stroke down into it
			ci.draw_arc(c, 7.5 * u, -PI * 0.5 + 0.7, PI * 1.5 - 0.7, 18, col, w, true)
			ci.draw_line(P.call(0, -10), P.call(0, -2), col, w, true)
		"anvil":  # an anvil, its horn to the left, a hammer resting above it
			ci.draw_polyline(PackedVector2Array([P.call(-10, -1), P.call(-6, -3), P.call(8, -3), P.call(8, 0.5), P.call(4, 0.5),
				P.call(3, 4), P.call(7, 8), P.call(-5, 8), P.call(-1, 4), P.call(-2, 0.5), P.call(-5, 0.5), P.call(-10, -1)]), col, w, true)
			ci.draw_line(P.call(-1, -9.5), P.call(7, -5.5), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-3, -9), P.call(-1.5, -11.5), P.call(1.5, -9.5), P.call(0, -7)]), col)
		"book":  # a bound book standing a little turned: its cover, the spine's bands, a clasp and a ribbon
			ci.draw_polyline(PackedVector2Array([P.call(-6, -9), P.call(7, -9), P.call(7, 9), P.call(-6, 9), P.call(-6, -9)]), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-9, -8), P.call(-6, -9), P.call(-6, 9), P.call(-9, 8)]), Color(col, 0.55))
			for y in [-5.5, 5.5]:
				ci.draw_line(P.call(-9, y), P.call(-6, y), col, maxf(1.0, w * 0.8), true)
			ci.draw_rect(Rect2(P.call(-2.5, -5), Vector2(6.5, 4.5) * u), Color(col, 0.35))
			ci.draw_line(P.call(7, -1), P.call(9.5, -1), col, w, true)
			ci.draw_line(P.call(9.5, -2.5), P.call(9.5, 0.5), col, w, true)
			ci.draw_polyline(PackedVector2Array([P.call(2, 9), P.call(2, 12), P.call(3.2, 10.8), P.call(4.4, 12), P.call(4.4, 9)]), Color(col, 0.8), maxf(1.0, w * 0.7), true)
		"lever":  # a signal lever in its quadrant: the toothed arc, the lever leaning, its handle and latch
			ci.draw_arc(P.call(0, 8), 9.0 * u, PI * 1.15, PI * 1.85, 14, col, w, true)
			for k in 5:
				var a := PI * 1.18 + PI * 0.64 * k / 4.0
				ci.draw_line(P.call(0, 8) + Vector2.from_angle(a) * 9.0 * u, P.call(0, 8) + Vector2.from_angle(a) * 7.2 * u, Color(col, 0.7), maxf(1.0, w * 0.6), true)
			ci.draw_line(P.call(-1, 9), P.call(4.5, -8), col, w * 1.15, true)
			ci.draw_circle(P.call(4.9, -9.2), 2.0 * u, col)
			ci.draw_line(P.call(1.2, 2), P.call(3.4, 2.7), col, w, true)
			ci.draw_line(P.call(-7, 9.5), P.call(7, 9.5), col, w, true)
		"station":  # a platform lamp on its post, its light, and a sign hung from its arm
			ci.draw_line(P.call(-3, -6), P.call(-3, 10), col, w, true)
			ci.draw_line(P.call(-6, 10), P.call(0, 10), col, w, true)
			ci.draw_polyline(PackedVector2Array([P.call(-6, -6), P.call(-3, -10), P.call(0, -6), P.call(-6, -6)]), col, w, true)
			ci.draw_circle(P.call(-3, -4.5), 1.6 * u, Color(col, 0.8))
			ci.draw_line(P.call(-3, -1), P.call(6, -1), col, w, true)
			ci.draw_rect(Rect2(P.call(1.5, 1.5), Vector2(8, 5) * u), Color(col, 0.35))
			ci.draw_polyline(PackedVector2Array([P.call(1.5, 1.5), P.call(9.5, 1.5), P.call(9.5, 6.5), P.call(1.5, 6.5), P.call(1.5, 1.5)]), col, maxf(1.0, w * 0.8), true)
			ci.draw_line(P.call(3, -1), P.call(3, 1.5), Color(col, 0.7), 1.0, true)
			ci.draw_line(P.call(8, -1), P.call(8, 1.5), Color(col, 0.7), 1.0, true)
		_:
			return false
	return true


## An item's look as it's pressed, pointed at, chosen or lit, shared by the
## rail's items and the identity block: a gilt wash for the page you're on,
## a faint light under the mouse, a gilt ring for the keys' focus.
static func draw_state(ci: CanvasItem, r: Rect2, on: bool, hot: bool, focus: bool) -> void:
	if on:
		var pts := UI.rounded(r, 7.0)
		var cols := PackedColorArray()
		for p in pts:
			var k := p.x / maxf(r.size.x, 1.0)
			cols.append(Color(UI.GILT, lerpf(0.26, 0.05, k)))
		ci.draw_polygon(pts, cols)
		var loop := UI.rounded(r.grow(-0.5), 7.0)
		loop.append(loop[0])
		ci.draw_polyline(loop, Color(UI.GILT, 0.45), 1.0, true)
		ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 6, 2.5, r.size.y - 12), UI.GILT_HI)
	elif hot:
		ci.draw_polygon(UI.rounded(r, 7.0), PackedColorArray([Color(1, 1, 1, 0.045)]))
	if focus:
		var loop := UI.rounded(r.grow(-1.0), 7.0)
		loop.append(loop[0])
		ci.draw_polyline(loop, Color(UI.GILT, 0.25), 5.0, true)
		ci.draw_polyline(loop, UI.GILT_HI, 1.6, true)


## A page's item on the rail: an icon, its name (and a line under it on a
## computer), and the key that opens it; lit gilt for the page you're on.
## The train on end draws a car instead (and its platform's signs).
class RailItem extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	## The train on end: how wide the wheels' lane is down the left, and the
	## roof down the right: [phone, computer].
	const LANE := [11.0, 15.0]
	const ROOF := [6.0, 9.0]
	## Each car's paint, the train on end (the rooms' own colours, train_art.gd).
	const PAINT := {
		"engine": Color(0.1, 0.19, 0.17), "store": Color(0.09, 0.2, 0.16), "personal": Color(0.32, 0.09, 0.15),
		"workshop": Color(0.33, 0.2, 0.12), "library": Color(0.15, 0.11, 0.25), "settings": Color(0.08, 0.17, 0.23),
	}
	var rail
	var id := ""
	var short := ""
	var sub := ""
	var icon_id := ""
	var key_hint := ""
	var on := false
	var small := false
	var row := false  # one of the train's cars (its height set to fit, rail._fit_rows)
	var car := false  # one of the train's cars
	var tile := false  # a phone's foot: the icon over the short name

	static func lane(narrow: bool) -> float:
		return LANE[0 if narrow else 1]

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))  # (the name is drawn below, with the icon)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _icon(at: Vector2, s: float, col: Color, w: float) -> void:
		if not rail.car_icon(self, icon_id, at, s, col, w):
			UI.draw_icon(self, icon_id, at, s, col, w)

	func _draw() -> void:
		if rail.on_end and car:
			_draw_car()
			return
		if rail.on_end:
			_draw_sign()
			return
		var narrow: bool = rail.narrow
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() or button_pressed
		rail.draw_state(self, r, on, hot, rail.shows_focus(self))
		if not on and id == rail.at_car:
			# The car you're in, while a page shows beside the rail: a dim bar,
			# where you'll be when the page closes.
			draw_rect(Rect2(1, 8, 2.0, size.y - 16), Color(UI.GILT, 0.55))
		var lit := on or has_focus() or hot
		var ic := Color(UI.GILT_HI) if on else (UI.TEXT if lit else Color(UI.DIM, 0.95))
		var tc := UI.TEXT if lit else Color(UI.DIM.lerp(UI.TEXT, 0.35))
		if small and not lit:
			ic = Color(UI.DIM, 0.8)
			tc = UI.DIM
		if tile:
			# The icon over the short name, centred.
			_icon(Vector2(size.x * 0.5, size.y * 0.5 - 6.0), 6.5, ic, 1.4)
			UI.draw_label(self, Vector2(0, size.y * 0.5 + 13.0), short, 12, tc, HORIZONTAL_ALIGNMENT_CENTER, size.x)  # (a label: the gothic face)
			return
		var isz := 7.5 if narrow else (8.0 if small else 9.5)
		var ix := 15.0 if narrow else 20.0
		_icon(Vector2(ix, size.y * 0.5), isz, ic, 1.5 if narrow else 1.7)
		var x := ix + (14.0 if narrow else 20.0)
		var w := size.x - x - 6.0
		# The item's name is a label (the gothic face); what it holds, under
		# it, is text.
		var label: String = short if narrow else text
		var fs := 15 if narrow else (16 if small else 18)
		if key_hint != "" and not narrow:
			w -= 26.0
		if narrow or sub == "" or small or size.y < 40.0:
			UI.draw_label(self, Vector2(x, size.y * 0.5 + fs * 0.32), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w)
		else:
			UI.draw_label(self, Vector2(x, size.y * 0.5 - 1.0), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w)
			UI.draw_text(self, UI.font("body"), Vector2(x, size.y * 0.5 + 14.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color(UI.DIM, 0.85 if lit else 0.7))
		if key_hint != "" and not narrow:
			var mono := UI.font("mono")
			UI.draw_text(self, mono, Vector2(0, size.y * 0.5 - (1.0 if sub != "" and not small and size.y >= 40.0 else -4.0)), key_hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8.0, 11, Color(UI.FAINT, 0.95))

	## The train on end: this car, seen from the side and stood on its end
	## (its wheels on the track down the left, its roof down the right): a
	## painted body with a lined panel, arched windows lit along it, its icon
	## and name on its side. The engine, taller, has its boiler at the top
	## with the smokestack, dome and headlamp, the cowcatcher over the wheels,
	## driving wheels joined by a rod, and its cab below. Lit gilt for the car
	## you're in.
	func _draw_car() -> void:
		var narrow: bool = rail.narrow
		var b := UI.Draw.Batch.new()
		var k := 0 if narrow else 1
		var ln: float = LANE[k]
		var roof: float = ROOF[k]
		var hot := is_hovered() or button_pressed
		var focus: bool = rail.shows_focus(self)
		var paint: Color = PAINT.get(id, Color(0.2, 0.12, 0.1))
		if hot or focus:
			paint = paint.lightened(0.1)
		var engine := id == "engine"
		var front := (12.0 if narrow else 16.0) if engine else 0.0  # the engine's nose: the cowcatcher and lamp
		var body := Rect2(ln, front + 1.0, size.x - ln - roof - (10.0 if engine else 2.0), size.y - front - 2.0)
		# The wheels on the track (the engine's are drawn with it).
		if not engine:
			var wr := ln * 0.5
			for fy in [0.24, 0.76]:
				var wc := Vector2(ln * 0.5 + 0.5, body.position.y + body.size.y * fy)
				b.rect(Rect2(wc.x - 1.0, wc.y - wr * 1.6, ln * 0.5 + 2.0, wr * 3.2), Art.OUTLINE)  # (the bogie's frame)
				_wheel(b, wc, wr)
		var outer := body.grow(1.2)
		var lit_cab := Rect2()
		if engine:
			lit_cab = _engine(b, body, front, narrow)
		else:
			# The body: an outline, its paint shading from the roof, a sunk
			# panel lined in gilt.
			b.polygon(UI.rounded(outer, 4.0), Art.OUTLINE)
			b.polygon(UI.rounded(body, 3.5), paint)
			Art.hgrad(b, body.grow(-1.5), Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.06))
			b.rect(Rect2(body.position.x, body.position.y + 3.0, body.size.x, 1.0), Color(1, 1, 1, 0.08))
			var panel := body.grow(-3.5)
			b.path(UI.rounded(panel, 2.5), Color(Art.GILT, 0.55 if not on else 0.95), 1.0, true)
			# The roof down the right: dark, overhanging both ends, a lit ridge.
			var rf := Rect2(body.end.x - 1.0, body.position.y - 1.5, roof, body.size.y + 3.0)
			b.polygon(UI.rounded(rf.grow(0.8), 2.5), Art.OUTLINE)
			Art.hgrad(b, rf, Color(0.36, 0.31, 0.32), Color(0.14, 0.12, 0.14))
			b.rect(Rect2(rf.position.x + 1.5, rf.position.y + 2.0, 1.0, rf.size.y - 4.0), Color(1, 1, 1, 0.25))
			b.rect(Rect2(rf.position.x + roof * 0.55, rf.position.y + 6.0, 1.0, rf.size.y - 12.0), Color(0, 0, 0, 0.35))  # (the clerestory's edge)
			# The windows, arched and lit, in a column along the roof side.
			var n := clampi(int((body.size.y - 8.0) / (20.0 if not narrow else 16.0)), 1, 3)
			var ww := 7.0 if narrow else 10.0
			var wx := body.end.x - ww - 4.0
			var wh := ((body.size.y - 10.0) - (n - 1) * 5.0) / n
			for i in n:
				_window(b, Rect2(wx, body.position.y + 5.0 + i * (wh + 5.0), ww, wh), hot or focus)
		b.flush(self)
		# The car you're in: a gilt ring round the body; the keys' focus: a bright one.
		if on or id == rail.at_car:
			var loop := UI.rounded(outer.grow(1.0), 5.0)
			loop.append(loop[0])
			draw_polyline(loop, Color(UI.GILT_HI, 0.95 if on else 0.45), 1.6 if on else 1.0, true)
		if focus:
			var loop := UI.rounded(outer.grow(2.5), 6.0)
			loop.append(loop[0])
			draw_polyline(loop, Color(UI.GILT, 0.3), 5.0, true)
			draw_polyline(loop, UI.GILT_HI, 1.6, true)
		# Its icon and name on its side (the engine's on its cab).
		var area := lit_cab if engine else Rect2(body.position, Vector2(body.size.x - (7.0 if narrow else 10.0) - 7.0, body.size.y))
		var lit := on or focus or hot
		var tc := Color(1.0, 0.94, 0.8) if lit else Color(0.93, 0.85, 0.7)
		var ic := Color(UI.GILT_HI) if on else tc
		var ax := area.position.x + (10.0 if narrow else 14.0)
		var cy := area.position.y + area.size.y * 0.5
		var isz := 6.5 if narrow else 8.5
		_icon(Vector2(ax, cy), isz, ic, 1.4 if narrow else 1.6)
		var x := ax + isz + (5.0 if narrow else 9.0)
		var w := area.end.x - x - 2.0
		var label: String = short if narrow else text
		var fs := 14 if narrow else 17
		if narrow or sub == "" or area.size.y < 44.0:
			UI.draw_label(self, Vector2(x, cy + fs * 0.32), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w, 3, Color(0, 0, 0, 0.55))
		else:
			UI.draw_label(self, Vector2(x, cy - 1.0), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w, 3, Color(0, 0, 0, 0.55))
			UI.draw_text(self, UI.font("body"), Vector2(x, cy + 13.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w, 12, Color(0.85, 0.78, 0.66, 0.85 if lit else 0.65))

	## A wheel on the track: iron, a bright tyre, red spokes and a brass hub.
	func _wheel(b, c: Vector2, r: float) -> void:
		b.circle(c, r + 1.0, Art.OUTLINE, 14)
		b.circle(c, r, Color(0.5, 0.48, 0.52), 14)
		b.circle(c, r * 0.78, Color(0.16, 0.06, 0.06), 14)
		for a in 4:
			var d := Vector2.from_angle(PI * 0.25 * a + 0.3)
			b.line(c - d * r * 0.75, c + d * r * 0.75, Color(0.62, 0.14, 0.1), maxf(1.0, r * 0.18))
		b.circle(c, r * 0.3, Art.GILT.darkened(0.1), 8)

	## A small arched window, lit warm (brighter for the car you're in).
	func _window(b, w: Rect2, hot: bool) -> void:
		var glow := 1.0 if on else (0.85 if hot else 0.66)
		var arch := PackedVector2Array()
		var half := w.size.x * 0.5
		var c := Vector2(w.get_center().x, w.position.y + half)
		for i in 9:
			arch.append(c + Vector2.from_angle(PI + PI * i / 8.0) * half)
		arch.append(w.end)
		arch.append(Vector2(w.position.x, w.end.y))
		var frame := PackedVector2Array()
		for p in arch:
			frame.append(p + (p - w.get_center()).normalized() * 1.3)
		b.polygon(frame, Art.GILT.darkened(0.35))
		b.polygon(arch, Color(Art.LAMP.lerp(Color(1.0, 0.9, 0.7), 0.3), glow))
		b.rect(Rect2(w.position.x, w.end.y - w.size.y * 0.35, w.size.x, w.size.y * 0.35), Color(Art.LAMP.darkened(0.3), 0.5 * glow))
		b.rect(Rect2(c.x - 0.5, c.y, 1.0, w.end.y - c.y), Color(Art.OUTLINE, 0.6))
		if on:
			Art.light(b, w.get_center(), Vector2(w.size.x * 2.0, w.size.y * 0.9), Color(Art.LAMP, 0.18))

	## The engine, front up: the cowcatcher and headlamp at its nose, the
	## boiler (dark, banded in brass) with the smokestack and dome out of its
	## roof side, three driving wheels joined by a rod and a small pony wheel,
	## and the cab below with its lit window. Returns the cab's side (for its
	## name).
	func _engine(b, body: Rect2, front: float, narrow: bool) -> Rect2:
		var u := 0.72 if narrow else 1.0
		var ln: float = LANE[0 if narrow else 1]
		var roof: float = ROOF[0 if narrow else 1]
		var split := body.position.y + body.size.y * 0.6  # where the boiler meets the cab
		var steel: Color = PAINT["engine"]
		if is_hovered() or has_focus():
			steel = steel.lightened(0.1)
		# The wheels: a pony wheel near the nose, three drivers, the rod.
		_wheel(b, Vector2(ln * 0.5 + 0.5, body.position.y + body.size.y * 0.1), ln * 0.36)
		var dr := ln * 0.56
		var ys: Array = []
		for i in 3:
			ys.append(body.position.y + body.size.y * (0.33 + 0.24 * i))
		for y in ys:
			_wheel(b, Vector2(ln * 0.5 + 0.5, y), dr)
		b.line(Vector2(ln * 0.5 + 2.0, ys[0]), Vector2(ln * 0.5 + 2.0, ys[2]), Art.OUTLINE, 3.6 * u)
		b.line(Vector2(ln * 0.5 + 2.0, ys[0]), Vector2(ln * 0.5 + 2.0, ys[2]), Color(0.75, 0.72, 0.7), 2.0 * u)
		# The running board under the boiler, along the wheels.
		b.rect(Rect2(body.position.x - 2.0, body.position.y + 2.0, 3.0, body.size.y - 4.0), Art.OUTLINE)
		# The boiler: a long cylinder from the nose to the cab, lower than the
		# cab (so it stands narrower here, on the wheels' side), its roof side lit.
		var bw := body.size.x * 0.52
		var boiler := Rect2(body.position.x, body.position.y + 1.0, bw, split - body.position.y + 2.0)
		b.polygon(UI.rounded(boiler.grow(1.2), 5.0), Art.OUTLINE)
		b.polygon(UI.rounded(boiler, 4.5), steel)
		Art.hgrad(b, boiler.grow(-1.0), Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.1))
		b.rect(Rect2(boiler.end.x - bw * 0.3, boiler.position.y + 3.0, 2.0, boiler.size.y - 6.0), Color(1, 1, 1, 0.16))
		# The smokebox at its nose: black, a riveted ring.
		var smoke := Rect2(boiler.position.x, boiler.position.y, bw, 10.0 * u)
		b.polygon(UI.rounded(smoke, 4.0), Color(0.06, 0.06, 0.07))
		b.rect(Rect2(smoke.position.x, smoke.end.y, bw, 1.5), Art.OUTLINE)
		for kr in 4:
			b.circle(Vector2(smoke.position.x + bw * (kr + 0.5) / 4.0, smoke.end.y - 2.5 * u), 0.9, Color(0.6, 0.6, 0.65), 6)
		# Brass bands round the boiler.
		for kb in 3:
			var by := smoke.end.y + (boiler.end.y - smoke.end.y) * (0.2 + 0.3 * kb)
			b.rect(Rect2(boiler.position.x + 1.0, by, bw - 2.0, 2.2 * u), Art.GILT.darkened(0.05))
			b.rect(Rect2(boiler.position.x + 1.0, by + 2.2 * u, bw - 2.0, 0.8), Color(0, 0, 0, 0.45))
		# The smokestack, standing up off the boiler (out to its roof side)
		# just behind the smokebox, flared at its top; smoke drifting off.
		var sy := smoke.end.y + 5.0 * u
		var reach := body.size.x * 0.2
		var stack := Rect2(boiler.end.x, sy - 4.0 * u, reach - 3.0 * u, 8.0 * u)
		b.rect(stack.grow(1.0), Art.OUTLINE)
		Art.vgrad(b, stack, Color(0.24, 0.22, 0.24), Color(0.07, 0.06, 0.07))
		var lip := Rect2(stack.end.x - 1.0, sy - 6.5 * u, 4.0 * u, 13.0 * u)
		b.rect(lip.grow(1.0), Art.OUTLINE)
		Art.vgrad(b, lip, Color(0.32, 0.29, 0.32), Color(0.1, 0.09, 0.1))
		b.rect(Rect2(lip.position.x + 1.0, lip.position.y + 1.0, 1.0, lip.size.y - 2.0), Art.GILT.darkened(0.15))
		for kp in 3:
			b.circle(Vector2(lip.end.x + (3.0 + kp * 3.5) * u, sy - (2.0 + kp * 4.0) * u), (2.2 + kp * 1.4) * u, Color(0.75, 0.72, 0.8, 0.3 - kp * 0.08), 10)
		# The brass steam dome, and the sand box behind it, on the boiler's top.
		var dome := Vector2(boiler.end.x, boiler.position.y + boiler.size.y * 0.56)
		b.polygon(Art.oval(dome, Vector2(reach * 0.5, 6.5 * u), 16), Art.OUTLINE)
		b.polygon(Art.oval(dome, Vector2(reach * 0.5 - 1.0, 5.5 * u), 16), Art.GILT.darkened(0.1))
		b.rect(Rect2(dome.x - reach * 0.5, dome.y - 7.0 * u, reach * 0.4, 14.0 * u), steel.darkened(0.2))
		b.circle(dome + Vector2(reach * 0.22, -2.0 * u), 1.4 * u, Art.GILT_HI, 6)
		var sand := Vector2(boiler.end.x, boiler.position.y + boiler.size.y * 0.8)
		b.rect(Rect2(sand.x - 1.0, sand.y - 4.0 * u, reach * 0.55, 8.0 * u).grow(1.0), Art.OUTLINE)
		Art.hgrad(b, Rect2(sand.x - 1.0, sand.y - 4.0 * u, reach * 0.55, 8.0 * u), steel, steel.lightened(0.15))
		# The headlamp on the nose, glowing, its light thrown ahead.
		var lamp := Vector2(boiler.get_center().x, body.position.y - front * 0.42)
		Art.light(b, lamp + Vector2(0, -front * 0.3), Vector2(front * 1.9, front * 1.1), Color(Art.LAMP, 0.32))
		var lh := Rect2(lamp.x - 5.5 * u, lamp.y - 4.0 * u, 11.0 * u, front * 0.42 + 6.0 * u)
		b.rect(lh.grow(1.0), Art.OUTLINE)
		b.rect(lh, Color(0.14, 0.13, 0.14))
		b.circle(lamp, 3.6 * u, Color(1.0, 0.92, 0.65), 12)
		# The cowcatcher over the wheels: red slats fanning up to a point.
		var base_y := body.position.y + 4.0
		var tip := Vector2(1.0, 1.0)
		var cw := boiler.position.x + bw * 0.25
		b.polygon(PackedVector2Array([Vector2(0.0, base_y), Vector2(cw, base_y), tip]), Art.OUTLINE)
		for ks in 5:
			var t := (ks + 0.5) / 5.0
			b.line(Vector2(lerpf(0.5, cw - 1.0, t), base_y - 0.8), tip.lerp(Vector2(cw * 0.5, tip.y + 3.0), t * 0.5), Color(0.75, 0.17, 0.12), 1.3)
		b.line(Vector2(0.0, base_y), Vector2(cw, base_y), Color(0.75, 0.17, 0.12), 2.2)
		# The cab: the full width, its roof overhanging, a lit window, and the
		# whistle on its front.
		var cab := Rect2(body.position.x, split, body.size.x + 6.0, body.end.y - split)
		b.polygon(UI.rounded(cab.grow(1.2), 4.0), Art.OUTLINE)
		b.polygon(UI.rounded(cab, 3.5), steel.lightened(0.05))
		Art.hgrad(b, cab.grow(-1.5), Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.07))
		b.path(UI.rounded(cab.grow(-3.5), 2.5), Color(Art.GILT, 0.55 if not on else 0.95), 1.0, true)
		var rf := Rect2(cab.end.x - 1.0, cab.position.y - 3.0, roof + 2.0, cab.size.y + 4.0)
		b.polygon(UI.rounded(rf.grow(0.8), 2.5), Art.OUTLINE)
		Art.hgrad(b, rf, Color(0.36, 0.31, 0.32), Color(0.14, 0.12, 0.14))
		b.rect(Rect2(rf.position.x + 1.5, rf.position.y + 2.0, 1.0, rf.size.y - 4.0), Color(1, 1, 1, 0.25))
		var wh := Vector2(cab.end.x - 4.0, cab.position.y - 1.0)
		b.rect(Rect2(wh.x - 2.0, wh.y - 5.0 * u, 3.0 * u, 6.0 * u), Art.GILT.darkened(0.1))
		var ww := 8.0 if narrow else 11.0
		_window(b, Rect2(cab.end.x - ww - 5.0, cab.position.y + 5.0, ww, minf(cab.size.y - 10.0, 22.0)), is_hovered() or has_focus())
		return Rect2(cab.position.x, cab.position.y, cab.size.x - ww - 7.0, cab.size.y)

	## The train on end: an item on the platform, an enamel sign on a post
	## (on a phone, side by side: the icon over the name).
	func _draw_sign() -> void:
		var r := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
		var hot := is_hovered() or button_pressed
		var focus: bool = rail.shows_focus(self)
		var lit := on or hot or focus
		var plate := Color(0.09, 0.14, 0.27) if id != "quit" else Color(0.27, 0.08, 0.08)
		if lit:
			plate = plate.lightened(0.12)
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
		var pts := UI.rounded(r, 4.0)
		draw_polygon(pts, PackedColorArray([plate]))
		var loop := UI.rounded(r.grow(-2.0), 3.0)
		loop.append(loop[0])
		draw_polyline(loop, Color(0.92, 0.88, 0.76, 0.85 if lit else 0.6), 1.0, true)
		if focus:
			var f := UI.rounded(r.grow(1.0), 5.0)
			f.append(f[0])
			draw_polyline(f, Color(UI.GILT, 0.3), 5.0, true)
			draw_polyline(f, UI.GILT_HI, 1.6, true)
		elif on:
			var f := UI.rounded(r.grow(0.5), 5.0)
			f.append(f[0])
			draw_polyline(f, UI.GILT_HI, 1.4, true)
		var tc := Color(0.98, 0.95, 0.86) if lit else Color(0.88, 0.85, 0.76)
		if tile:
			_icon(Vector2(size.x * 0.5, size.y * 0.5 - 6.0), 6.0, tc, 1.3)
			UI.draw_label(self, Vector2(0, size.y * 0.5 + 12.0), short, 12, tc, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			return
		_icon(Vector2(r.position.x + 16.0, size.y * 0.5), 7.5, tc, 1.5)
		UI.draw_label(self, Vector2(r.position.x + 32.0, size.y * 0.5 + 5.0), text, 15, tc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0)


## The thin rule over the rail's foot.
class RailRule extends Control:
	const UI := preload("res://scripts/ui.gd")

	func _draw() -> void:
		var y := size.y * 0.5
		draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(size.x * 0.5, y), Vector2(size.x, y)]),
			PackedColorArray([Color(UI.LINE_HI, 0.0), Color(UI.LINE_HI, 0.8), Color(UI.LINE_HI, 0.0)]), 1.0, true)


## Who you are, at the top of the rail: your name in the display face, where
## you are, and your six marks as small medallions (an empty socket for a
## part with no mark yet). A button: it opens the climber screen (its key,
## Tab, shown faintly at its corner on a computer). The train on end hangs
## it on the station's sign over the engine.
class RailIdent extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	const Bonds := preload("res://scripts/bonds.gd")
	const ProfileScript := preload("res://scripts/profile.gd")
	var rail
	var id := "climber"
	var short := ""
	var sub := ""
	var icon_id := ""
	var key_hint := ""
	var on := false
	var row := false
	var car := false
	var eyebrow := true  # where you are, in small capitals over the name

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))  # (drawn below)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var m = rail.menu
		if m == null or m.main == null or m.main.profile == null:
			return
		var main = m.main
		var prof = main.profile
		var narrow: bool = rail.narrow
		var hot := is_hovered() or button_pressed
		var focus: bool = rail.shows_focus(self)
		var x := 4.0 if narrow else 8.0
		var w := size.x - x - 4.0
		var y := 0.0
		if rail.on_end:
			# The station's sign: a walnut board in a gilt frame, on two posts.
			var board := Rect2(2.0, 1.0, size.x - 4.0, size.y - (8.0 if narrow else 12.0))
			for px in [board.position.x + board.size.x * 0.22, board.end.x - board.size.x * 0.22]:
				draw_rect(Rect2(px - 2.0, board.end.y - 2.0, 4.0, size.y - board.end.y + 2.0), Art.OUTLINE)
				draw_rect(Rect2(px - 1.2, board.end.y - 2.0, 2.4, size.y - board.end.y + 2.0), Art.WALNUT.lightened(0.1))
			draw_rect(Rect2(board.position + Vector2(2, 3), board.size), Color(0, 0, 0, 0.4))
			draw_rect(board, Art.OUTLINE)
			draw_rect(board.grow(-1.0), Art.GILT.darkened(0.3 if not (hot or focus or on) else 0.05))
			draw_rect(board.grow(-3.0), Color(0.14, 0.085, 0.06) if not hot else Color(0.18, 0.11, 0.08))
			x = board.position.x + (6.0 if narrow else 10.0)
			w = board.size.x - (12.0 if narrow else 20.0)
			y = board.position.y + (2.0 if narrow else 4.0)
			if focus:
				var loop := UI.rounded(board.grow(1.5), 3.0)
				loop.append(loop[0])
				draw_polyline(loop, Color(UI.GILT, 0.3), 5.0, true)
				draw_polyline(loop, UI.GILT_HI, 1.6, true)
		else:
			rail.draw_state(self, Rect2(Vector2.ZERO, size), on, hot, focus)
			x += 6.0 if on else 0.0
		var name: String = str(prof.appearance.get("name", ""))
		if name == "":
			name = rail.TEXT["unnamed"]
		var place: String = rail.place_text(main)
		# Where you are, a small gothic label over the name (the old game's eyebrow).
		var es := 11 if narrow else 14
		var place_col: Color = UI.GOLD
		if not main.on_train and main.has_method("tower_data"):
			var ess = main.tower_data().get("essence", "")
			var Essence = load("res://scripts/essence.gd")
			if ess != "":
				place_col = Essence.color(ess).lerp(UI.TEXT, 0.25)
		if eyebrow:
			y += es + 2.0
			UI.draw_eyebrow(self, Vector2(x, y), _fit(UI.font("eyebrow"), UI.titled(place), w - (30.0 if key_hint != "" else 0.0), es), place_col, es)
		if key_hint != "" and not narrow:
			UI.draw_text(self, UI.font("mono"), Vector2(0, (y if eyebrow else 14.0)), key_hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8.0, 11, Color(UI.FAINT, 0.95))
		var ns := 18 if narrow else 30
		y += ns * (0.95 if narrow else 1.0) + 2.0
		var nc: Color = UI.GILT_HI if (on or hot or focus) else UI.GOLD
		UI.draw_title(self, Vector2(x, y), _fit(UI.font("display"), name, w, ns), ns, nc, HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
		# The title worn (renown.gd), under the name.
		var worn: String = load("res://scripts/renown.gd").worn_title(prof)
		if worn != "":
			var tsz := 12 if narrow else 17
			y += tsz + (1.0 if narrow else 3.0)
			UI.draw_text(self, UI.font("italic"), Vector2(x, y), _fit(UI.font("italic"), worn, w, tsz), HORIZONTAL_ALIGNMENT_LEFT, w, tsz, Color(UI.GILT_HI if (on or hot or focus) else UI.GOLD, 0.92))
		# The six marks.
		var r := 6.5 if narrow else 10.0
		if rail.on_end and narrow:
			r = 5.5
		var gap := (w - r * 2.0 * 6.0) / 5.0 if narrow else 7.0
		var cy := y + r + (8.0 if narrow else 12.0)
		if rail.on_end and narrow:
			cy = y + r + 4.0
		var b := UI.Draw.Batch.new()
		var i := 0
		for part in Bonds.PARTS:
			var c := Vector2(x + r + i * (r * 2.0 + gap), cy)
			var info: Dictionary = prof.bonds.get(part, {})
			if info.is_empty():
				UI.socket_into(b, c, r * 0.82)
			else:
				var data: Dictionary = Bonds.BONDS[info["id"]]
				UI.medallion_into(b, c, r, data["color"], data["affinity"], 1.0, 0, 0.35 if not info.get("faint", false) else 0.0, info.get("faint", false))
			i += 1
		b.flush(self)
		if not narrow and not rail.on_end:
			var line := "%d of 6 marks  ·  best floor %d" % [prof.bonds.size(), prof.best_floor]
			UI.draw_text(self, UI.font("body"), Vector2(x, cy + r + 18.0), line, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)

	static func _fit(f: Font, t: String, w: float, fs: int) -> String:
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return t
		while t.length() > 3 and f.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			t = t.left(t.length() - 1)
		return t + "..."
