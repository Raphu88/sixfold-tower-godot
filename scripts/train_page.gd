extends RefCounted
## The train between climbs (menu.gd's "train" page): you walk along it
## from car to car, and each car's things are part of its room (drawn by
## train_view.gd). Front to back: the engine (choose the next tower on its
## board, pull the lever to depart), your car (the heirloom wardrobe, your
## pack and the storage chest), the store car (the outfitter behind his
## counter: shelves of supplies, the outfit rail, today's piece in a glass
## case, and selling) and the workshop (the bench). It opens on your car.
##
## Scrolling: swipe or drag the train (it follows, then settles on the
## nearest car), the mouse wheel, Q / E or LB / RB, Left / Right (or the
## d-pad and stick) past the last thing in a car, the arrows at the screen's
## edges, or a car's name along the top. A choice's card is a brass-framed
## placard in the car. Your crystals sit along the bottom, with Menu.
##
## Every car is built at once (so the next one shows as you scroll), but
## only the car you're in answers taps, clicks and the keys. Its slots and
## buttons are the menu's own (m._slot, m.details), so mouse, keyboard,
## controller and touch all work as in the inventory. The words, prices and
## rules live in train.gd and bench.gd.

const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")
const VesselPage := preload("res://scripts/vessel_page.gd")

const T := Train.TEXT
## The first time each car shows, the Entity's tips for it (entity.gd TIPS).
const CAR_TIPS := {"personal": ["chest"], "store": ["store"], "workshop": ["bench", "enchant"]}
const B := Bench.TEXT
## A touch or drag this far is a swipe, not a tap.
const SWIPE := 14.0
## A swipe past this share of the screen (or this fast, in screens a second) goes to the next car.
const SWIPE_CAR := 0.15
const FLICK := 0.9
const WHEEL_GAP := 220  # ms between cars on the mouse wheel (a trackpad sends many)
const STICK_GAP := 260  # ms between cars on the stick

var m  # the menu (menu.gd)
var tips := {}  # car -> the Entity's tip said there this visit (kept while the page rebuilds)
var view  # the drawn train (m.train_view)
var roots := {}  # car -> its things (a VBoxContainer in its room)
var cards := {}  # car -> its placard's contents (m.details while you're in that car)
var card_scrolls := {}  # car -> the placard's ScrollContainer
var names: Array = []  # the cars' names along the top (buttons)
var was_open := false  # (set by menu.gd: the train was already showing, so a new car slides into view)
# A swipe or drag along the train.
var drag_axis := ""  # "" undecided, "x" moving the train, "y" scrolling a card
var drag_from := Vector2.ZERO
var drag_last := Vector2.ZERO
var drag_start := 0.0  # where the train stood
var drag_moved := 0.0
var drag_scroll: ScrollContainer = null
var drag_samples: Array = []  # [msec, x] for the flick's speed
var mouse_down := false
var held_button: BaseButton = null  # the button a mouse drag began on, held off till it ends
var wheel_at := 0
var stick_at := 0


func _init(menu) -> void:
	m = menu


func _prof():
	return m.main.profile


func _player():
	return m.main.player


func _ids() -> Array:
	return Train.CARS.map(func(c): return c[0])


func _index(car: String) -> int:
	return _ids().find(car)


func _small() -> bool:
	return m.compact()


func _cell() -> float:
	return 50.0 if _small() else 56.0


# --- the page ---------------------------------------------------------------------

## Builds every car's things into its room, and the bands over them. The
## card (m.details) and choice (m.inv_sel) are each car's own; while one car
## is built, m.train_car names it (the cards read it), then it's put back.
func build() -> void:
	var prof = _prof()
	Train.stock(prof)
	view = m.train_view
	view.refresh()
	if not view.laid_out.is_connected(_relaid):
		view.laid_out.connect(_relaid)
	var cur: String = m.train_car
	if _index(cur) < 0:
		cur = Train.HOME
	if not Towers.TOWERS.has(m.train_tower):
		m.train_tower = prof.last_tower if Towers.TOWERS.has(prof.last_tower) else Towers.ORDER[0]
	m.train_sel[cur] = m.inv_sel
	view.clear_content()
	roots.clear()
	cards.clear()
	card_scrolls.clear()
	var toast: String = m.toast
	var ask: String = m.sell_ask
	var pick: int = m.bench_pick
	for c in _ids():
		var here: bool = c == cur
		m.train_car = c
		m.inv_sel = m.train_sel.get(c, "")
		m.toast = toast if here else ""
		m.sell_ask = ask if here else ""
		m.bench_pick = pick if here else 0
		m.details = null
		var root := VBoxContainer.new()
		root.add_theme_constant_override("separation", 6 if _small() else 10)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.rooms[c].area.add_child(root)
		roots[c] = root
		_speech(root, c, here)
		match c:
			"engine":
				_engine(root)
			"store":
				_store(root)
			"workshop":
				_workshop(root)
			_:
				_personal(root)
		m.train_sel[c] = m.inv_sel
		cards[c] = m.details
		if here:
			ask = m.sell_ask
			pick = m.bench_pick
	m.train_car = cur
	m.toast = toast
	m.sell_ask = ask
	m.bench_pick = pick
	m.inv_sel = m.train_sel.get(cur, "")
	m.details = cards.get(cur)
	_chrome()
	view.go(_index(cur), was_open)
	view.fit_hook = fit_cards
	_interactive()
	for r in view.rooms.values():
		r.fit()


## The screen changed size (turned, or fullscreen): build the cars again.
func _relaid() -> void:
	if m.page == "train":
		m.open("train")


## Only the car you're in answers: its buttons take the focus, the mouse
## and taps; the others (seen while scrolling) are just drawn.
func _interactive() -> void:
	for c in roots:
		var on: bool = c == m.train_car
		for b in roots[c].find_children("*", "BaseButton", true, false):
			b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
			b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		var sc: ScrollContainer = card_scrolls.get(c)
		if sc != null:
			sc.mouse_filter = Control.MOUSE_FILTER_PASS if on else Control.MOUSE_FILTER_IGNORE


## The car you're in: its buttons and slots, top to bottom (menu.gd focusables).
func focusables() -> Array:
	var list: Array = []
	if roots.has(m.train_car) and is_instance_valid(roots[m.train_car]):
		m._collect_focus(roots[m.train_car], list)
	return list


## Where the keys start in a car: the chosen slot, the chosen tower, else the first.
func first_focus(list: Array) -> int:
	for i in list.size():
		var b: Control = list[i]
		if (m.inv_sel != "" and b.get_meta("slot", "") == m.inv_sel) or (m.train_car == "engine" and b.get_meta("tower", "") == m.train_tower):
			return i
	return 0


## The root the inventory's slot highlighting looks in (menu.gd _show_details).
func slot_root() -> Node:
	return roots.get(m.train_car, m.box)


## Q / E or LB / RB: the next car along. True if it did something.
func cycle(by: int) -> bool:
	go_to(_index(m.train_car) + by)
	return true


## Moves to car `i` (sliding there). At either end the train only rocks.
func go_to(i: int, from_drag := false) -> void:
	var list := _ids()
	var cur := _index(m.train_car)
	if i < 0 or i >= list.size() or i == cur:
		if from_drag:
			view.go(cur)
		elif i != cur:
			view.bump(signi(i - cur))
		return
	m.train_sel[m.train_car] = m.inv_sel
	m.train_car = list[i]
	m.toast = ""
	m.sell_ask = ""
	m.train_say = ""
	m.main.sfx("ui_move", 0.8, -4.0, 0.0)
	view.go(i)
	m.inv_sel = m.train_sel.get(m.train_car, "")
	if not tips.has(m.train_car):
		# The first time here this visit: the Entity may have something to say.
		m.open("train")
		return
	m.details = cards.get(m.train_car)
	_interactive()
	_chrome()
	if m.main.touch_active:
		m.get_viewport().gui_release_focus()
	else:
		var focus := focusables()
		if not focus.is_empty():
			m._focus_later.call_deferred(focus[first_focus(focus)])


## Who speaks at the top of a car: the Entity's tip the first time you're
## there (the train itself, then the chest, the store, the bench), or in
## your car the Entity's line (not on a phone, to save room). The outfitter
## speaks for himself, behind his counter.
func _speech(root: Node, car: String, here: bool) -> void:
	if here and not tips.has(car):
		var said: String = m.main.tip_now("train")
		for id in CAR_TIPS.get(car, []):
			var own: String = m.main.tip_now(id)
			said = own if said == "" else (said + "\n" + own if own != "" else said)
		tips[car] = said
	var face := 30.0 if _small() else 40.0
	if String(tips.get(car, "")) != "":
		var mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
		var row = Entity.says(Entity.fill_keys(tips[car], mode, m.main.pad_ps), face)
		row.set_meta("entity", car)
		root.add_child(row)
	elif car == "personal" and not _small():
		root.add_child(Entity.says(Entity.line("train", _prof().climbs), face))


## The outfitter says something: a brass-edged bubble (his face beside it,
## unless he's drawn in the room already).
static func outfitter_says(text: String, face := 40.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face > 0.0:
		var f := TrainView.OutfitterFace.new()
		f.custom_minimum_size = Vector2(face + 12.0, face)
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(f)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", brass_box(10.0, 9.0))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	bubble.add_child(col)
	var tag := Label.new()
	tag.text = Train.OUTFITTER["tag"]
	UI.style_label(tag, "eyebrow", 14, Color(TrainView.OutfitterFace.BRASS, 0.95))
	col.add_child(tag)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120.0
	l.add_theme_font_size_override("font_size", UI.SIZE_BODY)
	l.add_theme_color_override("font_color", Color(0.98, 0.9, 0.76))
	col.add_child(l)
	row.set_meta("outfitter_line", text)
	return row


# --- building blocks ----------------------------------------------------------------

## The row a car's things stand in, centred, filling the room's height.
func _main_row(root: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14 if _small() else 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	return row


## A piece of furniture (train_view.gd Furnish) holding a column of things.
func _furnish(parent: Node, kind: String) -> VBoxContainer:
	var f := TrainView.Furnish.new(kind, _small())
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(f)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3 if _small() else 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(col)
	return col


## A brass-lettered name on a piece of furniture (a small gothic label).
func _tag(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", 13 if _small() else 14, UI.GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _grid(parent: Node, columns: int, follow := true) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6 if not _small() else 5)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	if follow:
		var f = parent.get_parent()
		if f is TrainView.Furnish:
			f.follow(g)
	return g


## The placard beside a car's things: the card of what's chosen (the menu's
## own m.details), in a brass frame, scrolling if it's long.
func _card(row: Node, keys: Array, fallback: String) -> void:
	var plac := TrainView.Furnish.new("placard", _small())
	plac.custom_minimum_size.x = 320.0 if _small() else 380.0
	plac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plac)
	var sc := _card_scroll(plac)
	m.details = VBoxContainer.new()
	m.details.add_theme_constant_override("separation", 4 if _small() else 6)
	m.details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(m.details)
	m.details.minimum_size_changed.connect(_fit_card.bind(m.train_car), CONNECT_DEFERRED)
	if not (m.inv_sel in keys):
		m.inv_sel = fallback if fallback in keys else (keys[0] if not keys.is_empty() else "")
	m._show_details(m.inv_sel)


## A placard is as tall as what it says, up to the room's height (then it scrolls).
func _fit_card(car: String) -> void:
	var sc: ScrollContainer = card_scrolls.get(car)
	if sc == null or not is_instance_valid(sc) or sc.get_child_count() == 0:
		return
	var row: Control = sc.get_parent().get_parent()
	var want: float = sc.get_child(0).get_combined_minimum_size().y
	var room := maxf(row.size.y - 30.0, 80.0)
	sc.custom_minimum_size.y = clampf(want, 60.0, room)


func fit_cards() -> void:
	for c in card_scrolls:
		_fit_card(c)


func _card_scroll(parent: Node) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.focus_mode = Control.FOCUS_NONE
	sc.custom_minimum_size.y = 80.0
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bar := sc.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", UI.box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 3))
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(st, UI.box(Color(UI.TRAIN_BRASS, 0.75 if st == "grabber" else 1.0), Color(0, 0, 0, 0), 3))
	parent.add_child(sc)
	card_scrolls[m.train_car] = sc
	return sc


## A slot for a piece of gear (or an empty space) in a grid.
func _gear_slot(parent: Node, key: String, g, empty_name: String) -> Object:
	var has := Gear.is_gear(g)
	var s = m._slot(parent, key, _cell(), "")
	s.kind = "gear"
	s.id = Gear.base_id(g) if has else ""
	s.rec = g if has else null
	s.empty = not has
	s.slot_name = empty_name if not has else Gear.SLOT_NAMES.get(Gear.slot_of(g), "")
	s.tint = Gear.color(g) if has else UI.FAINT
	s.wear = Gear.condition(g) if has and Gear.wears(g) else -1.0
	return s


func _note(parent: Node, text: String, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width if width > 0.0 else 4.0 * _cell() + 18.0
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UI.DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A price drawn on a slot: a gem of its kind and the number (red if you
## can't pay it).
func _price_on(s, kind: String, amount: int, show: bool) -> void:
	if not show or amount <= 0:
		return
	s.price = amount
	s.price_kind = kind
	s.price_ok = Train.short_of(_prof(), kind, amount) == ""


# --- the engine ---------------------------------------------------------------------

## The cab: the destination board (a plaque for each tower: its essence and
## your best floor there), and a placard for the chosen one with what goes
## with you, what a fall costs, and the lever.
func _engine(root: Node) -> void:
	var prof = _prof()
	var small := _small()
	var row := _main_row(root)
	var board := _furnish(row, "board")
	var h := Label.new()
	h.text = UI.title_case(T["depart_title"])
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(h, "display", 24 if small else 28, UI.GOLD)
	board.add_child(h)
	if not small:
		var sub := _note(board, T["depart_sub"], 10.0)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := _grid(board, 3, false)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in Towers.ORDER:
		var b := TowerCard.new()
		b.tower = id
		b.last = id == prof.last_tower
		b.chosen = id == m.train_tower
		b.best = int(prof.record.get("best", {}).get(id, 0))
		b.custom_minimum_size = Vector2(148.0, 58.0) if small else Vector2(196.0, 74.0)
		b.set_meta("tower", id)
		b.pressed.connect(_choose_tower.bind(id))
		grid.add_child(b)
	# The chosen tower's placard, with the lever.
	var plac := TrainView.Furnish.new("placard", small)
	plac.custom_minimum_size.x = 270.0 if small else 330.0
	plac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plac)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3 if small else 6)
	plac.add_child(col)
	var tw: Dictionary = Towers.TOWERS[m.train_tower]
	_tag(col, T["next_climb"])
	var name := Label.new()
	name.text = tw["name"]
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_label(name, "display", 23 if small else 25, Color(tw["torch"]).lerp(UI.TEXT, 0.35))
	col.add_child(name)
	var ess := HBoxContainer.new()
	ess.add_theme_constant_override("separation", 10)
	col.add_child(ess)
	var tag := PriceTag.new()
	tag.kind = tw["essence"]
	tag.text_override = T["essence"] % Essence.display(tw["essence"])
	tag.custom_minimum_size = Vector2(ThemeDB.fallback_font.get_string_size(tag.text_override, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26.0, 20)
	ess.add_child(tag)
	var best := int(prof.record.get("best", {}).get(m.train_tower, 0))
	var bl := Label.new()
	bl.text = (T["best"] % best) if best > 0 else T["never"]
	bl.add_theme_font_size_override("font_size", 14)
	bl.add_theme_color_override("font_color", UI.DIM)
	ess.add_child(bl)
	if not small:
		_note(col, tw.get("blurb", ""), 10.0)
	var going: Array = prof.pack.map(func(g): return Gear.display(g))
	var n := 0
	for id in prof.supplies:
		n += int(prof.supplies[id])
	if n > 0:
		going.append("%d %s" % [n, "supply" if n == 1 else "supplies"])
	var vi: int = VesselPage.Vessel.packed_index(prof)
	if vi >= 0:  # (a vessel packed from the chest)
		going.append(VesselPage.V["going"] % VesselPage.Vessel.state_text(prof.vessels[vi]))
	var gl := _note(col, T["depart_pack"] % (", ".join(going) if not going.is_empty() else T["depart_none"]), 10.0)
	gl.add_theme_color_override("font_color", UI.TEXT)
	_note(col, T["depart_risk"], 10.0)
	var lever := TrainView.Lever.new()
	lever.word = T["lever"]
	lever.sub = T["lever_for"] % tw["short"]
	lever.custom_minimum_size = Vector2(130, 108) if small else Vector2(150, 140)
	lever.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lever.set_meta("depart", m.train_tower)
	lever.pressed.connect(_depart)
	col.add_child(lever)


func _choose_tower(id: String) -> void:
	if m.train_tower == id:
		return
	m.train_tower = id
	m.main.sfx("ui_confirm", 1.0, -4.0, 0.0)
	m.open("train")


func _depart() -> void:
	m.main.sfx("ui_confirm", 0.7, 0.0, 0.0)
	m.main.depart(m.train_tower)


# --- your car ---------------------------------------------------------------------

## Your heirlooms on the wardrobe (laid out like the inventory's paper
## doll), your pack, and the storage chest; the card beside them.
func _personal(root: Node) -> void:
	var prof = _prof()
	var row := _main_row(root)
	var keys: Array = []
	var doll := _furnish(row, "rack")
	_tag(doll, T["heirlooms"])
	var grid := _grid(doll, 3, false)
	grid.add_theme_constant_override("v_separation", 4)
	for r in Gear.DOLL:
		for slot in r:
			var s = m._heir_cell(grid, slot, _cell(), false)
			keys.append(s.get_meta("slot"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8 if _small() else 14)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	keys.append_array(_pack_and_chest(col))
	# The mirror (the climber screen), the trunk (the inventory) and how you look.
	var furniture := HBoxContainer.new()
	furniture.add_theme_constant_override("separation", 8)
	furniture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(furniture)
	for f in [["mirror", "climber"], ["trunk", "inventory"], ["looks", "appearance"]]:
		var label: String = T[f[0] + "_short"] if _small() else T[f[0]]
		var go: Callable = m.open_appearance.bind("") if f[1] == "appearance" else m.open.bind(f[1], true)
		var b: Button = m._button(label, go, furniture)
		b.custom_minimum_size.y = 40
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("car_page", f[1])
		b.clip_text = true
		_brass(b)
		# (three side by side: tighter margins so each name fits)
		b.add_theme_font_size_override("font_size", 15 if _small() else 16)
		var ratios: Dictionary = {"climber": 1.0, "inventory": 1.25, "appearance": 0.9} if _small() else {"climber": 1.0, "inventory": 1.12, "appearance": 1.3}
		b.size_flags_stretch_ratio = ratios[f[1]]
		for state in ["normal", "hover", "pressed"]:
			var st: StyleBox = b.get_theme_stylebox(state)
			st.content_margin_left = 5
			st.content_margin_right = 5
	if m.Unbound.is_on(prof):
		# The Unbound's techniques (technique_page.gd): built and named here.
		var tb: Button = m._button(T["techniques"], m.open.bind("techniques", true), col)
		tb.custom_minimum_size.y = 40
		tb.set_meta("car_page", "techniques")
		_brass(tb)
	_card(row, keys, "pack:0" if not prof.pack.is_empty() else "chest:0")


## Your pack's spaces and your chest's, 4 to a row. Returns their keys.
func _pack_and_chest(parent: Node, filled_only := false) -> Array:
	var prof = _prof()
	var keys: Array = []
	var size: int = _player().pack_size()
	if not filled_only or not prof.pack.is_empty():
		var pk := _furnish(parent, "pack")
		_tag(pk, T["pack"] % [prof.pack.size(), size])
		var pg := _grid(pk, 4)
		for i in maxi(size, prof.pack.size()):
			if filled_only and i >= prof.pack.size():
				break
			var s = _gear_slot(pg, "pack:%d" % i, prof.pack[i] if i < prof.pack.size() else null, "")
			keys.append(s.get_meta("slot"))
	if not filled_only or not prof.chest.is_empty() or not prof.vessels.is_empty():
		var ch := _furnish(parent, "chest")
		_tag(ch, T["chest"] % [prof.chest.size(), Train.CHEST_SIZE])
		var cg := _grid(ch, 4)
		for i in Train.CHEST_SIZE:
			if filled_only and i >= prof.chest.size():
				break
			var s = _gear_slot(cg, "chest:%d" % i, prof.chest[i] if i < prof.chest.size() else null, "")
			keys.append(s.get_meta("slot"))
		keys.append_array(VesselPage.chest_slots(self, cg))  # (vessels, after the pieces)
	return keys


# --- the store car ----------------------------------------------------------------

## The outfitter behind his counter (what he says over him, the Sell sign
## below); his shelves of supplies, the outfit rail and today's piece in a
## glass case; or, once you go to sell, what you brought down.
func _store(root: Node) -> void:
	var prof = _prof()
	var small := _small()
	var row := _main_row(root)
	var keys: Array = []
	var selling: bool = m.train_store == "sell"
	# The outfitter.
	var oc := VBoxContainer.new()
	oc.add_theme_constant_override("separation", 4)
	oc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	oc.custom_minimum_size.x = 150.0 if small else 200.0
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(oc)
	var line: String = m.train_say if m.train_say != "" else Train.line("greet", prof.climbs)
	if m.train_say == "" and not prof.last_pay.is_empty():
		# (just back from a climb: he mentions what he paid for it)
		line = Train.line("paid", prof.climbs) % Train.price_text(String(prof.last_pay["kind"]), int(prof.last_pay["amount"]))
	oc.add_child(outfitter_says(line, 0.0))
	var bust := TrainView.Outfitter.new()
	bust.custom_minimum_size = Vector2(0, 104.0 if small else 150.0)
	oc.add_child(bust)
	var sign_text: String = T["back_to_shelves"] if selling else T["sell_sign"]
	if small:
		sign_text = T["back_short"] if selling else T["sell_short"]
	var sign: Button = m._button(sign_text, _set_store.bind("shop" if selling else "sell"), oc)
	sign.custom_minimum_size.y = 40
	sign.set_meta("store_tab", "shop" if selling else "sell")
	sign.clip_text = true
	_brass(sign)
	# The goods.
	var goods := VBoxContainer.new()
	goods.add_theme_constant_override("separation", 6 if small else 12)
	goods.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goods.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(goods)
	if selling:
		_tag(goods, T["sell_title"])
		if prof.pack.is_empty() and prof.chest.is_empty() and prof.vessels.is_empty():
			_note(goods, T["nothing_to_sell"])
		else:
			keys.append_array(_pack_and_chest(goods, true))
			if not small:
				_note(goods, T["sell_note"] % int(round(Train.SELL_SHARE * 100.0)))
	else:
		var shelf := _furnish(goods, "shelf")
		_tag(shelf, T["shelves"])
		var sg := _grid(shelf, 6)
		for id in Train.supplies():
			var price := Train.item_price(id)
			var packed := int(prof.supplies.get(id, 0))
			var s = m._slot(sg, "supply:" + id, _cell(), "")
			s.kind = "item"
			s.id = id
			s.count = packed if packed > 0 else -1
			_price_on(s, price[0], price[1], true)
			keys.append(s.get_meta("slot"))
		var low := HBoxContainer.new()
		low.add_theme_constant_override("separation", 10 if small else 16)
		low.mouse_filter = Control.MOUSE_FILTER_IGNORE
		goods.add_child(low)
		var rail := _furnish(low, "rail")
		_tag(rail, T["rail"])
		var rg := _grid(rail, 4)
		rg.add_theme_constant_override("v_separation", 16)
		rail.add_theme_constant_override("separation", 14)
		var rack := Train.outfit(prof)
		for i in rack.size():
			var g: Dictionary = rack[i]
			var s = _gear_slot(rg, "outfit:%d" % i, g, "Sold")
			s.wear = -1.0
			_price_on(s, Train.gear_kind(g), Train.gear_price(g), not g.is_empty())
			keys.append(s.get_meta("slot"))
		var case := _furnish(low, "case")
		case.get_parent().size_flags_vertical = Control.SIZE_SHRINK_END
		_tag(case, T["case"])
		var g := Train.today(prof)
		var ts = _gear_slot(case, "today", g, "Sold")
		ts.wear = -1.0
		ts.custom_minimum_size = Vector2(_cell(), _cell()) * 1.3
		_price_on(ts, Train.gear_kind(g), Train.gear_price(g), not g.is_empty())
		keys.append("today")
	if keys.is_empty():
		m.details = null
		return
	_card(row, keys, "")


func _set_store(id: String) -> void:
	m.train_store = id
	m.inv_sel = ""
	m.sell_ask = ""
	m.toast = ""
	m.open("train")


## A button in brass (a sign, a drawer's label); `on` lights it (the counter in use).
## The train's buttons: a dark walnut face, lit along the top, in a brass
## rim (gilded for the one that's on).
func _brass(b: Button, on := false) -> void:
	for state in ["normal", "hover", "pressed"]:
		var st := UI.Ornate.new()
		st.radius = 5.0
		st.highlight = state != "pressed"
		st.drop = state != "pressed"
		st.top = Color(0.27, 0.17, 0.09) if state == "normal" else (Color(0.35, 0.23, 0.12) if state == "hover" else Color(0.2, 0.13, 0.07))
		st.bottom = Color(0.15, 0.09, 0.05) if state == "normal" else (Color(0.21, 0.14, 0.07) if state == "hover" else Color(0.3, 0.2, 0.1))
		if on:
			st.top = Color(0.56, 0.4, 0.17) if state != "hover" else Color(0.62, 0.45, 0.2)
			st.bottom = Color(0.36, 0.24, 0.1) if state != "hover" else Color(0.42, 0.29, 0.12)
		st.edge = UI.GILT_HI if on else Color(UI.TRAIN_BRASS, 0.85 if state != "normal" else 0.6)
		st.inner = Color(UI.TRAIN_BRASS, 0.18)
		m._button_margins(st)
		b.add_theme_stylebox_override(state, st)
	b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82) if on else Color(0.97, 0.86, 0.63))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.82))


## A brass-edged panel (the outfitter's bubble): walnut, warmer at the top.
static func brass_box(margin := 10.0, radius := 9.0) -> StyleBox:
	var st := UI.Ornate.new()
	st.top = Color(0.2, 0.13, 0.07, 0.96)
	st.bottom = Color(0.11, 0.07, 0.04, 0.96)
	st.edge = Color(UI.TRAIN_BRASS, 0.65)
	st.inner = Color(UI.TRAIN_BRASS, 0.15)
	st.glow = Color(1.0, 0.8, 0.5, 0.06)
	st.highlight = true
	st.radius = radius
	st.shadow = 6.0
	st.set_content_margin_all(margin)
	st.content_margin_top = margin * 0.6
	st.content_margin_bottom = margin * 0.7
	return st


# --- the workshop car -----------------------------------------------------------------

## The bench (bench.gd): its corner drawn over a cabinet of counters (two
## columns on a phone), what the chosen counter can work on, and the card.
## Counters only a Rune Artist can use are greyed for everyone else, but
## still show what they would do.
func _workshop(root: Node) -> void:
	var prof = _prof()
	var small := _small()
	var counter: String = m.train_bench
	var row := _main_row(root)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(side)
	var art := TrainView.Bench.new()
	art.lit = Bench.rune_artist(prof)
	art.custom_minimum_size = Vector2(170, 76) if small else Vector2(210, 128)
	side.add_child(art)
	var drawers := _furnish(side, "drawers")
	var cg := _grid(drawers, 2 if small else 1)
	cg.add_theme_constant_override("v_separation", 4)
	_counters(cg, Vector2(80.0, 36.0) if small else Vector2(194.0, 34.0), 2 if small else 1)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4 if small else 6)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	var left := _furnish(mid, "plain")
	left.custom_minimum_size.x = 4.0 * _cell() + 18.0
	var keys: Array = []
	match counter:
		"brew":
			var grid := _grid(left, 4)
			for id in Bench.brews():
				var cost := Bench.brew_cost(prof, id)
				var s = m._slot(grid, "bench:item:" + id, _cell(), "")
				s.kind = "item"
				s.id = id
				var packed := int(prof.supplies.get(id, 0))
				s.count = packed if packed > 0 else -1
				var kind: String = cost.keys()[0]
				_price_on(s, kind, int(cost[kind]), true)
				keys.append(s.get_meta("slot"))
		"recall":
			var s = m._slot(left, "bench:item:scroll", _cell() * 1.4, "")
			s.kind = "item"
			s.id = "scroll"
			var packed := int(prof.supplies.get("scroll", 0))
			s.count = packed if packed > 0 else -1
			keys.append("bench:item:scroll")
		"break":
			keys = _bench_pieces(left, func(_g): return true, false)
			var packed: Array = Items.ORDER.filter(func(id): return int(prof.supplies.get(id, 0)) > 0)
			if not packed.is_empty():
				_tag(left, B["packed_items"])
				var grid := _grid(left, 4, false)
				for id in packed:
					var s = m._slot(grid, "bench:supply:" + id, _cell(), "")
					s.kind = "item"
					s.id = id
					s.count = int(prof.supplies[id])
					var v := Bench.break_value(prof, "supply:" + id)
					_price_on(s, v[0], v[1], true)
					keys.append(s.get_meta("slot"))
		"temper":
			keys = _bench_pieces(left, func(g): return Bench.temperable(g))
		"retrait":
			keys = _bench_pieces(left, func(g): return not g["traits"].is_empty())
		"join":
			keys = _bench_pieces(left, func(g): return Bench.joinable(g))
		"vessel":
			keys = VesselPage.bench_list(self, left)
		_:
			keys = _bench_pieces(left, func(_g): return true)
	if keys.is_empty():
		var empty: String = B["nothing_join"] if counter == "join" else (B["nothing_break"] if counter == "break" else B["nothing"])
		_note(left, empty)
		keys.append("bench:none")
	elif not small:
		_note(mid, B["notes"][counter])
	_card(row, keys, "")


## The bench's counter buttons, labelled drawers; the current one gilded,
## the ones only a Rune Artist can use greyed for anyone else. `names` 1:
## full names, 2: short.
func _counters(parent: Node, size: Vector2, names: int) -> void:
	var prof = _prof()
	for c in Bench.COUNTERS:
		var b: Button = m._button(c[names], _set_bench.bind(c[0]), parent)
		b.custom_minimum_size = size
		b.set_meta("bench_tab", c[0])
		b.add_theme_font_size_override("font_size", 15 if names == 2 else 16)
		var locked := Bench.locked(prof, c[0]) != ""
		_brass(b, c[0] == m.train_bench)
		if c[0] == m.train_bench:
			if locked:
				b.add_theme_color_override("font_color", Color(UI.GOLD, 0.7))
		elif locked:
			b.add_theme_color_override("font_color", UI.FAINT)
			b.add_theme_color_override("font_hover_color", UI.DIM)
		if locked:
			b.set_meta("greyed", true)


func _set_bench(id: String) -> void:
	m.train_bench = id
	m.inv_sel = ""
	m.sell_ask = ""
	m.toast = ""
	m.bench_pick = 0
	m.open("train")


## The pieces a counter can work on, in sections (your heirlooms, pack and
## chest), filtered by `fits` (a record -> bool). Returns their keys.
func _bench_pieces(parent: Node, fits: Callable, heirlooms := true) -> Array:
	var prof = _prof()
	var keys: Array = []
	var groups := {"heir": [], "pack": [], "chest": []}
	for ref in Bench.pieces(prof, heirlooms):
		var g := Bench.piece(prof, ref)
		if fits.call(g):
			groups[ref.get_slice(":", 0)].append(ref)
	for where in ["heir", "pack", "chest"]:
		if groups[where].is_empty():
			continue
		_tag(parent, {"heir": B["heirlooms"], "pack": B["pack"], "chest": B["chest"]}[where])
		var grid := _grid(parent, 4, false)
		for ref in groups[where]:
			var g := Bench.piece(prof, ref)
			var s = _gear_slot(grid, "bench:" + ref, g, "")
			s.kept = where == "heir"
			match m.train_bench:
				"temper":
					var cost := Bench.temper_cost(g)
					if not cost.is_empty():
						_price_on(s, cost.keys()[0], int(cost.values()[0]), true)
				"break":
					var v := Bench.break_value(prof, ref)
					_price_on(s, v[0], v[1], true)
			keys.append(s.get_meta("slot"))
	return keys


# --- over the cars: their names, the arrows, your crystals ---------------------------

## The bands over the train: the cars' names along the top (the one you're
## in gilded, a gold bar sliding under them as you go; tap one to go there),
## an arrow at each edge to the next car, and along the bottom your crystals
## (a gem and the essence held, for each kind) and Menu.
func _chrome() -> void:
	var ch: Control = view.chrome
	for c in ch.get_children():
		ch.remove_child(c)
		c.queue_free()
	var mg: Vector3 = view.margins()
	var small := _small()
	var cur := _index(m.train_car)
	var list := _ids()
	# Along the top.
	var top := TrainView.Band.new()
	top.at_top = true
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = mg.x
	ch.add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4 if small else 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_bottom = mg.x - 3.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(row)
	var keys := ["", ""]
	if not m.main.touch_active:
		keys = [Controls.pad_name("lb", m.main.pad_ps), Controls.pad_name("rb", m.main.pad_ps)] if m.main.pad_active else ["Q", "E"]
	if keys[0] != "":
		row.add_child(m._key_hint(keys[0]))
	names.clear()
	for i in list.size():
		var b := Button.new()
		b.text = Train.CARS[i][1]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(108.0 if small else 132.0, mg.x - 4.0)
		b.add_theme_font_override("font", UI.font("display"))
		b.add_theme_font_size_override("font_size", 19 if small else 22)
		b.add_theme_color_override("font_color", UI.GILT_HI if i == cur else Color(UI.TEXT, 0.72))
		b.add_theme_color_override("font_hover_color", UI.GOLD)
		b.add_theme_color_override("font_pressed_color", UI.GOLD)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("outline_size", 3)
		b.set_meta("car", list[i])
		b.pressed.connect(go_to.bind(i))
		row.add_child(b)
		names.append(b)
	if keys[1] != "":
		row.add_child(m._key_hint(keys[1]))
	var marker := TrainView.Marker.new()
	marker.view = view
	marker.slots = names
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ch.add_child(marker)
	# The arrows at the edges.
	for d in [-1, 1]:
		var j: int = cur + d
		if j < 0 or j >= list.size():
			continue
		var a := TrainView.EdgeArrow.new()
		a.dir = d
		a.car_name = Train.CARS[j][1]
		var w := mg.z - 10.0
		a.custom_minimum_size = Vector2(w, w * 1.6)
		a.size = a.custom_minimum_size
		var preset := Control.PRESET_CENTER_LEFT if d < 0 else Control.PRESET_CENTER_RIGHT
		a.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE, 5)
		a.set_meta("arrow", d)
		a.pressed.connect(go_to.bind(j))
		ch.add_child(a)
	# Along the bottom.
	var bottom := TrainView.Band.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -mg.y
	ch.add_child(bottom)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -mg.y + 5.0
	foot.offset_bottom = -4.0
	foot.offset_left = mg.z * 0.5
	foot.offset_right = -mg.z * 0.5
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(foot)
	var purse := Purse.new()
	purse.profile = _prof()
	purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(purse)
	var b: Button = m._button(T["menu"], m.open.bind("pause"), foot)
	b.custom_minimum_size = Vector2(96, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("menu", true)
	_brass(b)
	if not m.main.touch_active:
		var l: Label = m._label(Controls.pad_text("{start}", m.main.pad_ps) if m.main.pad_active else "Esc", 0.0, UI.FAINT)
		l.add_theme_font_size_override("font_size", 14)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(l)


# --- moving along: swipes, drags, the wheel and the keys ---------------------------------

## The menu hands the train its input first (menu.gd _input). True if it
## was used here.
func input(event: InputEvent) -> bool:
	if view == null:
		return false
	if event is InputEventScreenTouch:
		if event.index != 0:
			return true
		if event.pressed:
			_drag_begin(event.position)
		else:
			if drag_axis == "x":
				_drag_end()
			elif drag_moved < SWIPE:
				tap(event.position)
			drag_axis = ""
			drag_scroll = null
			# A phone: switch to the bigger phone layout (after the tap, so the
			# button doesn't move under the finger).
			if m.main != null and m.main.touch != null and not m.main.touch.active:
				m.main.touch._set_active(true)
		return true
	if event is InputEventScreenDrag:
		if event.index != 0:
			return true
		drag_moved += (event.position - drag_last).length()
		_drag_move(event.position, event.position - drag_last)
		drag_last = event.position
		return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				_drag_begin(event.position)
			else:
				mouse_down = false
				if drag_axis == "x":
					_drag_end()
				drag_axis = ""
				drag_scroll = null
				if held_button != null:
					_let_go.call_deferred(held_button)  # (after the GUI has seen the release)
					held_button = null
			return false
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var sc := _scroll_at(event.position)
			if sc != null and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _can_scroll(sc):
				return false  # (the card scrolls)
			var now := Time.get_ticks_msec()
			if now - wheel_at >= WHEEL_GAP:
				wheel_at = now
				cycle(1 if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1)
			return true
		return false
	if event is InputEventMouseMotion and mouse_down:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			mouse_down = false
			return false
		drag_moved += (event.position - drag_last).length()
		var was: String = drag_axis
		_drag_move(event.position, Vector2.ZERO)
		drag_last = event.position
		if drag_axis == "x" and was == "":
			# A drag that began on a button doesn't press it when let go.
			var b := _button_at(drag_from)
			if b != null and not b.disabled:
				held_button = b
				b.disabled = true
		return drag_axis == "x"
	# Left / Right past the last thing in this car: the next car.
	for side in [["ui_left", -1, SIDE_LEFT], ["ui_right", 1, SIDE_RIGHT]]:
		if event.is_action_pressed(side[0]):
			if event is InputEventJoypadMotion:
				var now := Time.get_ticks_msec()
				if now - stick_at < STICK_GAP:
					return _at_edge(side[2])
				if _at_edge(side[2]):
					stick_at = now
			if _at_edge(side[2]):
				cycle(side[1])
				return true
			return false
	return false


## True if the focus can't move further that way inside this car.
func _at_edge(side: int) -> bool:
	var f: Control = m.get_viewport().gui_get_focus_owner()
	if f == null or not _in_car(f):
		return true
	var n: Control = f.find_valid_focus_neighbor(side)
	return n == null or not _in_car(n)


func _in_car(c: Node) -> bool:
	var root = roots.get(m.train_car)
	return root != null and is_instance_valid(root) and (c == root or root.is_ancestor_of(c))


func _let_go(b: BaseButton) -> void:
	if is_instance_valid(b):
		b.disabled = false


func _drag_begin(at: Vector2) -> void:
	drag_from = at
	drag_last = at
	drag_moved = 0.0
	drag_axis = ""
	drag_start = view.pos
	drag_scroll = _scroll_at(at)
	drag_samples = [[Time.get_ticks_msec(), at.x]]


func _drag_move(at: Vector2, rel: Vector2) -> void:
	var d := at - drag_from
	if drag_axis == "" and drag_moved >= SWIPE:
		drag_axis = "x" if absf(d.x) > absf(d.y) else "y"
		if drag_axis == "x":
			view.dragging = true
			drag_start = view.pos
			drag_from = at  # (the train follows from here, without a jump)
	if drag_axis == "x":
		var n := _ids().size() - 1.0
		var raw: float = drag_start - (at.x - drag_from.x) / maxf(view.size.x, 1.0)
		if raw < 0.0:
			raw *= 0.3
		elif raw > n:
			raw = n + (raw - n) * 0.3
		view.pos = raw
		view.place()
		drag_samples.append([Time.get_ticks_msec(), at.x])
		if drag_samples.size() > 6:
			drag_samples.pop_front()
	elif drag_axis == "y" and drag_scroll != null and rel != Vector2.ZERO:
		drag_scroll.scroll_vertical -= int(rel.y)


## Let go of the train: it settles on the next car if it moved far (or
## fast) enough, else back on this one.
func _drag_end() -> void:
	view.dragging = false
	var speed := 0.0
	if drag_samples.size() >= 2:
		var a: Array = drag_samples[0]
		var z: Array = drag_samples[-1]
		var dt := maxf(float(z[0] - a[0]) / 1000.0, 0.016)
		speed = -(float(z[1]) - float(a[1])) / maxf(view.size.x, 1.0) / dt
	var moved: float = view.pos - drag_start
	var goal := roundi(drag_start)
	if moved > SWIPE_CAR or speed > FLICK:
		goal += 1
	elif moved < -SWIPE_CAR or speed < -FLICK:
		goal -= 1
	go_to(clampi(goal, 0, _ids().size() - 1), true)


## A tap: presses the button under it, in this car or over the train.
func tap(pos: Vector2) -> void:
	var b := _button_at(pos)
	if b == null or b.disabled:
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed  # (emits toggled)
	else:
		b.pressed.emit()


## The topmost button under a point: in the car you're in (not scrolled out
## of its card) or over the train.
func _button_at(pos: Vector2) -> BaseButton:
	var found: BaseButton = null
	var places: Array = [view.chrome]
	if roots.has(m.train_car) and is_instance_valid(roots[m.train_car]):
		places.push_front(roots[m.train_car])
	for place in places:
		for c in place.find_children("*", "BaseButton", true, false):
			var b: BaseButton = c
			if not b.is_visible_in_tree() or not b.get_global_rect().has_point(pos):
				continue
			var sc := _scroll_of(b)
			if sc != null and not sc.get_global_rect().has_point(pos):
				continue
			found = b
	return found


func _scroll_of(n: Node) -> ScrollContainer:
	var p := n.get_parent()
	while p != null and p != view:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## The card under a point (it scrolls when the finger or wheel moves up and down).
func _scroll_at(pos: Vector2) -> ScrollContainer:
	var sc: ScrollContainer = card_scrolls.get(m.train_car)
	if sc != null and is_instance_valid(sc) and sc.get_global_rect().has_point(pos):
		return sc
	return null


func _can_scroll(sc: ScrollContainer) -> bool:
	return sc.get_v_scroll_bar().max_value > sc.size.y + 1.0


# --- the bench's cards -----------------------------------------------------------------

func _bench_card(arg: String) -> void:
	var counter: String = m.train_bench
	if arg == "none":
		_head("empty", "", Bench.COUNTERS.filter(func(c): return c[0] == counter)[0][1], UI.DIM)
		_lock_line(counter)
		m._detail_text(B["notes"][counter], UI.DIM)
		return
	if arg.begins_with("item:"):
		_brew_card(arg.substr(5))
		return
	if arg.begins_with("supply:"):
		_break_card(arg)
		return
	match counter:
		"vessel":
			VesselPage.bench_card(self, arg)
		"temper":
			_temper_card(arg)
		"retrait":
			_retrait_card(arg)
		"join":
			_join_card(arg)
		"inscribe":
			_inscribe_card(arg)
		_:
			_break_card(arg)


## A plain line when only a Rune Artist could use this counter.
func _lock_line(counter: String) -> bool:
	var lock := Bench.locked(_prof(), counter)
	if lock != "":
		m._detail_text(lock, Color(0.72, 0.74, 1.0))
	return lock != ""


## A piece's heading on a bench card: its icon and name, where it is, and
## its traits (and rune).
func _bench_head(ref: String) -> Dictionary:
	var g := Bench.piece(_prof(), ref)
	if g.is_empty():
		_head("empty", "", "Empty space", UI.DIM)
		return g
	_head("gear", g, Gear.display(g), Gear.color(g))
	var where := ref.get_slice(":", 0)
	var line: String = B["where_heir"] if where == "heir" else (B["where_pack"] if where == "pack" else B["where_chest"])
	m._detail_text(line + "  ·  " + Gear.rarity_name(g), UI.DIM)
	return g


func _trait_list(g: Dictionary) -> void:
	for t in Gear.trait_lines(g):
		m._detail_text(t[0], Color(t[1], 0.95))


## Costs on a card, a gem and number for each kind; why you can't pay, in words.
func _cost_lines(cost: Dictionary, label: String) -> String:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	m.details.add_child(row)
	row.add_child(m._small_label(label, UI.DIM))
	for k in cost:
		var tag := PriceTag.new()
		tag.kind = k
		tag.amount = int(cost[k])
		tag.ok = Train.short_of(_prof(), k, int(cost[k])) == ""
		tag.custom_minimum_size = Vector2(96, 22)
		row.add_child(tag)
	return Bench.short_of(_prof(), cost)


## A bench button that asks first: the first press says "Tap again", the
## second does it. `ask` names this exact choice (m.sell_ask holds it).
func _ask_button(parent: Node, text: String, again: String, ask: String, why: String, meta: String, meta_val: String) -> Button:
	var full: String = m.inv_sel + "|" + ask
	var asking: bool = m.sell_ask == full
	var b: Button = m._button(again if asking else text, _ask.bind(full), parent)
	b.custom_minimum_size.y = 40
	b.disabled = why != ""
	b.set_meta(meta, meta_val)
	b.clip_text = true
	if asking and why == "":
		m._primary(b)
	return b


func _ask(full: String) -> void:
	if m.sell_ask != full:
		m.sell_ask = full
		m.toast = ""
		m.open("train")
		return
	m.sell_ask = ""
	_bench_do(full.get_slice("|", 0).substr(6), full.get_slice("|", 1))


## Why on a card, in red ("Can't: needs 12 more Fire"), unless it's the
## Rune Artist's line (shown already).
func _why_line(why: String) -> void:
	if why != "" and not why.begins_with(B["needs_rune_artist"].get_slice("%", 0)):
		m._detail_text(B["cant"] % why, UI.BAD)


func _brew_card(id: String) -> void:
	var prof = _prof()
	var p = _player()
	var data: Dictionary = Items.ITEMS[id]
	_head("item", id, data["name"], Items.color(id))
	var locked := false
	if id == "scroll":
		locked = _lock_line("recall")
	m._detail_text(String(data["desc"]).left(1).to_upper() + String(data["desc"]).substr(1) + ".", UI.TEXT)
	var why := _cost_lines(Bench.brew_cost(prof, id), B["cost"])
	if Bench.rune_artist(prof) and id != "scroll":
		m._detail_text(B["rune_artist_less"] % int(round((1.0 - Bench.RUNE_ARTIST_BREW) * 100.0)), UI.GOOD)
	var packed := int(prof.supplies.get(id, 0))
	m._detail_text(B["packed"] % [packed, p.max_stack(id)] if id != "scroll" else B["scroll_carry"], UI.DIM)
	if locked:
		why = Bench.locked(prof, "recall")
	elif why == "" and Train.supply_room(prof, p, id) <= 0:
		why = B["belt_full"] if id != "scroll" else B["scroll_carry"].to_lower().trim_suffix(".")
	var b: Button = m._button(B["brew"] if id != "scroll" else B["bind"], _brew.bind(id), m.details)
	b.custom_minimum_size.y = 40
	b.disabled = why != ""
	b.set_meta("brew", id)
	_why_line(why)
	if packed > 0:
		var back: Button = m._button(B["put_back"], _unbrew.bind(id), m.details)
		back.custom_minimum_size.y = 40
		back.set_meta("put_back", id)


func _temper_card(ref: String) -> void:
	var prof = _prof()
	var g := _bench_head(ref)
	if g.is_empty():
		return
	_lock_line("temper")
	var k := int(g["rank"])
	if k >= Gear.MAX_RANK:
		m._detail_text(B["rank_top"] % k, UI.GOLD)
		_trait_list(g)
		return
	m._detail_text(B["rank"] % [k, Gear.MAX_RANK], UI.GOLD if k > 0 else UI.DIM)
	# What the next rank does: each trait's number now and after.
	for t in g["traits"]:
		var now := Gear.amount_text(Gear.trait_amount(t, g["rarity"], k))
		m._detail_text("%s  (now %s)" % [Gear.trait_text(t, g["rarity"], k + 1), now], Color(Essence.color(Gear.TRAITS[t]["kind"]), 0.95))
	if Gear.slot_of(g) in ["melee", "ranged"]:
		var next := g.duplicate()
		next["rank"] = k + 1
		m._detail_text(B["weapon_rank"] % [Gear.amount_text(Gear.weapon_boost(next) - 1.0), k + 1] + "  (now %s)" % Gear.amount_text(Gear.weapon_boost(g) - 1.0), UI.TEXT)
	if g.has("rune"):
		m._detail_text(Gear.rune_text(g["rune"]), Color(Gear.LASTING_RUNES[g["rune"]]["color"], 0.95))
	_cost_lines(Bench.temper_cost(g), B["cost"])
	var why := Bench.temper_why(prof, ref)
	_ask_button(m.details, B["temper_to"] % (k + 1), B["temper_ask"] % (k + 1), "temper", why, "bench_do", "temper")
	_why_line(why)


func _retrait_card(ref: String) -> void:
	var prof = _prof()
	var g := _bench_head(ref)
	if g.is_empty():
		return
	_lock_line("retrait")
	var traits: Array = g["traits"]
	if traits.is_empty():
		m._detail_text(B["no_retrait"], UI.DIM)
		return
	m.bench_pick = clampi(m.bench_pick, 0, traits.size() - 1)
	_trait_list(g)
	if traits.size() > 1:
		var pick := HBoxContainer.new()
		pick.add_theme_constant_override("separation", 6)
		m.details.add_child(pick)
		pick.add_child(m._small_label(B["retrait_which"], UI.DIM))
		for i in traits.size():
			var b: Button = m._button(Gear.TRAITS[traits[i]]["short"], _pick_trait.bind(i), pick)
			b.custom_minimum_size = Vector2(0, 38)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.set_meta("retrait_pick", i)
			if i == m.bench_pick:
				m._primary(b)
	var opts := Bench.retrait_options(g, m.bench_pick)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	m.details.add_child(grid)
	var gives: Array = []
	for kind in Essence.KINDS:
		if not opts.has(kind):
			continue
		var cost := Bench.retrait_cost(g, kind)
		var amount := int(cost[kind])
		var why := Bench.retrait_why(prof, ref, m.bench_pick, kind)
		var name := Essence.display(kind)
		var b := _ask_button(grid, B["retrait_kind"] % [name, amount], B["retrait_ask"] % [name, amount], "retrait:%d:%s" % [m.bench_pick, kind], why, "retrait", kind)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", Essence.color(kind).lightened(0.2))
		var line: String = B["retrait_gives"] % [name, " or ".join(opts[kind].map(func(t): return Gear.TRAITS[t]["short"]))]
		var short := Train.short_of(prof, kind, amount)
		gives.append(line + (" (%s)" % short if short != "" else ""))
	if gives.is_empty():
		m._detail_text(B["cant"] % B["no_new_trait"], UI.BAD)
	else:
		m._detail_text("  ·  ".join(gives), UI.DIM)


func _join_card(ref: String) -> void:
	var prof = _prof()
	var g := _bench_head(ref)
	if g.is_empty():
		return
	_lock_line("join")
	_trait_list(g)
	if not Bench.joinable(g):
		m._detail_text(B["no_join"], UI.DIM)
		return
	_cost_lines(Bench.join_cost(g), B["cost"])
	var others := Bench.partners(prof, ref)
	if others.is_empty():
		m._detail_text(B["no_partner"], UI.DIM)
		return
	for o in others:
		var og := Bench.piece(prof, o)
		var why := Bench.join_why(prof, ref, o)
		var name := Gear.display(og)
		_ask_button(m.details, B["join_with"] % name, B["join_ask"] % name, "join:" + o, why, "join", o)
		var made := Bench.joined(g, og)
		var names: Array = made["traits"].map(func(t): return Gear.TRAITS[t]["short"])
		m._detail_text(B["join_makes"] % [Gear.info(made).get("name", ""), " and ".join(names)], UI.DIM)
	_why_line(Bench.join_why(prof, ref, others[0]))


func _inscribe_card(ref: String) -> void:
	var prof = _prof()
	var g := _bench_head(ref)
	if g.is_empty():
		return
	_lock_line("inscribe")
	_trait_list(g)
	if g.has("rune"):
		m._detail_text(B["replaces_rune"], UI.DIM)
	_cost_lines(Bench.INSCRIBE, B["cost"])
	var why := ""
	for rune in Gear.LASTING_RUNES:
		if g.get("rune", "") == rune or Gear.LASTING_RUNES[rune].get("deep", false):
			continue  # (a deep rune takes a full vessel: the Vessel counter)
		why = Bench.inscribe_why(prof, ref, rune)
		var text := Gear.rune_text(rune)
		var b := _ask_button(m.details, B["inscribe"] % text, B["inscribe_ask"] % text, "inscribe:" + rune, why, "inscribe", rune)
		b.add_theme_color_override("font_color", Color(Gear.LASTING_RUNES[rune]["color"]).lightened(0.1))
	_why_line(why)


func _break_card(thing: String) -> void:
	var prof = _prof()
	var v := Bench.break_value(prof, thing)
	if thing.begins_with("supply:"):
		var id := thing.substr(7)
		_head("item", id, Items.ITEMS[id]["name"], Items.color(id))
		m._detail_text(B["packed"] % [int(prof.supplies.get(id, 0)), _player().max_stack(id)], UI.DIM)
	else:
		var g := _bench_head(thing)
		if g.is_empty():
			return
		_trait_list(g)
		if thing.begins_with("heir:"):
			m._detail_text(B["break_heir"], UI.DIM)
			return
	_price_line(v[0], v[1], "Gives")
	var name := Essence.display(v[0])
	_ask_button(m.details, B["break_for"] % [v[1], name], B["break_ask"] % [v[1], name], "break", "", "bench_do", "break")
	if not m.compact():
		m._detail_text(B["notes"]["break"], UI.FAINT)


# --- the bench's actions -------------------------------------------------------------------

func _brew(id: String) -> void:
	var why := Bench.brew(_prof(), _player(), id)
	if why == "":
		_done(B["brewed"] % Items.ITEMS[id]["name"], "", "pickup")
	else:
		_done(B["cant"] % why, "", "ui_back")


func _unbrew(id: String) -> void:
	if Train.put_back(_prof(), id):
		_done(B["put_back_done"] % Items.ITEMS[id]["name"], "", "ui_back")


func _pick_trait(i: int) -> void:
	m.bench_pick = i
	m.sell_ask = ""
	m.toast = ""
	m.open("train")


## Does what a bench button asked (pressed twice): `thing` is the card's
## piece or item, `ask` the choice ("temper", "retrait:0:air", "join:pack:1",
## "inscribe:warding", "break").
func _bench_do(thing: String, ask: String) -> void:
	var prof = _prof()
	var what := ask.get_slice(":", 0)
	var before := Gear.display(Bench.piece(prof, thing)) if not thing.begins_with("supply:") else ""
	var why := ""
	var said := ""
	match what:
		"temper":
			why = Bench.temper(prof, thing)
			said = B["tempered"] % Gear.display(Bench.piece(prof, thing))
		"retrait":
			why = Bench.retrait(prof, thing, int(ask.get_slice(":", 1)), ask.get_slice(":", 2))
			said = B["retraited"] % [Gear.display(Bench.piece(prof, thing)), before]
		"join":
			var other := ask.substr(5)
			var keep := Bench.join_place(thing, other)
			why = Bench.join(prof, thing, other)
			if why == "":
				m.inv_sel = "bench:" + keep
				said = B["joined"] % Gear.display(Bench.piece(prof, keep))
		"inscribe":
			var rune := ask.get_slice(":", 1)
			why = Bench.inscribe(prof, thing, rune)
			said = B["inscribed"] % [Gear.LASTING_RUNES[rune]["name"], before]
		"vtemper", "vrune":
			var r: Array = VesselPage.bench_do(prof, thing, ask, before)  # (a full vessel worked into a piece)
			why = r[0]
			said = r[1]
		"break":
			var name: String = before if before != "" else Items.ITEMS[thing.substr(7)]["name"]
			var got := Bench.break_down(prof, thing)
			if got == "":
				return
			said = B["broke"] % [name, got]
	if why == "":
		_done(said, "", "pickup" if what == "break" else "armor_on")
	else:
		_done(B["cant"] % why, "", "ui_back")



# --- the detail card ------------------------------------------------------------------

## The card for a slot on the train (menu.gd _show_details hands these over;
## heirlooms use the inventory's own card).
func details(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	if key != m.sell_ask and not m.sell_ask.begins_with(key + "|"):
		m.sell_ask = ""
	match kind:
		"bench":
			_bench_card(key.substr(6))
		"pack", "chest":
			_piece_card(kind, int(arg))
		"supply":
			_supply_card(arg)
		"outfit":
			_offer_card(int(arg))
		"today":
			_offer_card(-1)
		"vessel":
			VesselPage.card(self, int(arg))


## A card's heading, then the answer to the last choice (in gold).
func _head(kind: String, id, title: String, col: Color) -> void:
	m._detail_head(kind, id, title, col)
	if m.toast != "":
		m._detail_text(m.toast, UI.GOLD)


## What a piece is set against: your heirloom for its slot, else what every
## climb starts with there (the sword, the bow, no armor), else nothing.
func _start_piece(g):
	var kept: Array = Gear.heirloom_pieces(_prof().heirlooms, Gear.heirloom_slot(g))
	if not kept.is_empty():
		return kept[0]
	match Gear.slot_of(g):
		"melee":
			return Gear.make(Weapons.START_MELEE)
		"ranged":
			return Gear.make(Weapons.START_RANGED)
		"armor":
			return ""
	return null


## A price on the card: a gem, the amount and its kind; then why you can't
## pay it, in words.
func _price_line(kind: String, amount: int, label := "") -> String:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	m.details.add_child(row)
	if label != "":
		row.add_child(m._small_label(label, UI.DIM))
	var tag := PriceTag.new()
	tag.kind = kind
	tag.amount = amount
	var why := Train.short_of(_prof(), kind, amount)
	tag.ok = why == ""
	tag.custom_minimum_size = Vector2(110, 22)
	if kind == Train.ANY:
		tag.text_override = Train.price_text(kind, amount)  # ("60 of any kind")
		tag.custom_minimum_size.x = 160.0
	row.add_child(tag)
	return why


func _piece_card(where: String, i: int) -> void:
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		_head("empty", "", "Empty space", UI.DIM)
		m._detail_text(T["chest_empty"] if where == "chest" else T["pack_empty"], UI.DIM)
		return
	var g = list[i]
	_head("gear", g, Gear.display(g), Gear.color(g))
	var selling: bool = m.train_car == "store"
	if not selling:
		m._detail_text(T["in_chest"] if where == "chest" else T["in_pack"], UI.DIM)
	var kind := Train.gear_kind(g)
	var got := Train.gear_sell(g)
	_price_line(kind, got, "Sells for")
	var key := "%s:%d" % [where, i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	m.details.add_child(row)
	var to_other := T["to_pack"] if where == "chest" else T["to_chest"]
	var full: bool = Train.pack_room(prof, _player()) <= 0 if where == "chest" else prof.chest.size() >= Train.CHEST_SIZE
	var mv: Button = m._button(to_other, _move.bind(where, i), row)
	mv.custom_minimum_size = Vector2(0, 40)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.disabled = full
	var sell: Button = m._button(T["sell_ask"] % [got, Essence.display(kind)] if m.sell_ask == key else T["sell_for"] % [got, Essence.display(kind)], _sell.bind(where, i), row)
	sell.custom_minimum_size = Vector2(0, 40)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.set_meta("sell", key)
	if m.sell_ask == key:
		m._primary(sell)
	if full:
		var said: String = T["chest_full"] if where == "pack" else T["pack_full"]
		m._detail_text(said.left(1).to_upper() + said.substr(1) + ".", UI.DIM)
	m._detail_lines(g, Gear.SLOT_NAMES.get(Gear.slot_of(g), ""))
	if not selling:
		m._detail_stats(g, _start_piece(g))


func _supply_card(id: String) -> void:
	var prof = _prof()
	var p = _player()
	var data: Dictionary = Items.ITEMS[id]
	_head("item", id, data["name"], Items.color(id))
	m._detail_text(String(data["desc"]).left(1).to_upper() + String(data["desc"]).substr(1) + ".", UI.TEXT)
	var price := Train.item_price(id)
	var why := _price_line(price[0], price[1])
	if price[0] == Train.ANY:
		m._detail_text(T["any_note"], UI.DIM)
	var packed := int(prof.supplies.get(id, 0))
	m._detail_text(T["packed"] % [packed, p.max_stack(id)], UI.DIM)
	if why == "" and Train.supply_room(prof, p, id) <= 0:
		why = T["belt_full"]
	var buy: Button = m._button(T["buy"], _buy_supply.bind(id), m.details)
	buy.custom_minimum_size.y = 40
	buy.disabled = why != ""
	buy.set_meta("buy", id)
	if why != "":
		m._detail_text(T["cant"] % why, UI.BAD)
	if packed > 0:
		var back: Button = m._button(T["put_back"], _put_back.bind(id), m.details)
		back.custom_minimum_size.y = 40
	if not m.compact():
		m._detail_text(T["supplies_note"], UI.FAINT)


## A piece on the rack (i), or today's piece (i = -1).
func _offer_card(i: int) -> void:
	var prof = _prof()
	var g: Dictionary = Train.today(prof) if i < 0 else Train.outfit(prof)[i]
	if g.is_empty():
		_head("empty", "", "Sold", UI.DIM)
		m._detail_text(T["today_sold"] if i < 0 else "Sold. The rack is filled again after your next climb.", UI.DIM)
		return
	_head("gear", g, Gear.display(g), Gear.color(g))
	var kind := Train.gear_kind(g)
	var cost := Train.gear_price(g)
	var why := _price_line(kind, cost)
	if why == "" and Train.pack_room(prof, _player()) <= 0:
		why = T["pack_full"]
	var buy: Button = m._button(T["buy"], _buy_gear.bind(i), m.details)
	buy.custom_minimum_size.y = 40
	buy.disabled = why != ""
	buy.set_meta("buy", "today" if i < 0 else "outfit:%d" % i)
	if why != "":
		m._detail_text(T["cant"] % why, UI.BAD)
	m._detail_lines(g, Gear.SLOT_NAMES.get(Gear.slot_of(g), ""))
	m._detail_stats(g, _start_piece(g))


# --- actions ------------------------------------------------------------------------

func _done(text: String, say: String, sound: String) -> void:
	m.toast = text
	m.toast_t = 3.0
	if say != "":
		m.train_say = say
	m.main.sfx(sound, 1.0, -4.0, 0.0)
	m.open("train")


func _buy_supply(id: String) -> void:
	var why := Train.buy_supply(_prof(), _player(), id)
	if why == "":
		var said: String = T["bought"] % Items.ITEMS[id]["name"]
		if Train.item_price(id)[0] == Train.ANY:
			said += "  ·  " + T["paid_with"] % Train.paid_text(Train.last_paid(_prof(), id))  # (which crystals it took)
		_done(said, Train.line("bought"), "pickup")
	else:
		_done(T["cant"] % why, Train.line("poor") if why.begins_with("needs") else "", "ui_back")


func _put_back(id: String) -> void:
	if Train.put_back(_prof(), id):
		_done(T["put_back_done"] % Items.ITEMS[id]["name"], Train.line("put_back"), "ui_back")


func _buy_gear(i: int) -> void:
	var prof = _prof()
	var g: Dictionary = Train.today(prof) if i < 0 else Train.outfit(prof)[i]
	var why := Train.buy_gear(prof, _player(), i)
	if why == "":
		m.inv_sel = "today" if i < 0 else "outfit:%d" % i
		_done(T["bought"] % Gear.display(g) + "  ·  " + T["moved_pack"] % Gear.display(g), Train.line("bought"), "armor_on")
	else:
		_done(T["cant"] % why, Train.line("poor") if why.begins_with("needs") else "", "ui_back")


func _move(where: String, i: int) -> void:
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		return
	var name := Gear.display(list[i])
	var why := Train.move(prof, _player(), where, i)
	if why == "":
		var to := "pack" if where == "chest" else "chest"
		m.inv_sel = "%s:%d" % [to, (prof.pack.size() if to == "pack" else prof.chest.size()) - 1]
		_done((T["moved_pack"] if to == "pack" else T["moved_chest"]) % name, "", "ui_confirm")
	else:
		_done(T["cant"] % why, "", "ui_back")


## Selling asks once: the button says "Tap again to sell", and a second
## press sells.
func _sell(where: String, i: int) -> void:
	var key := "%s:%d" % [where, i]
	if m.sell_ask != key:
		m.sell_ask = key
		m.toast = ""
		m.open("train")
		return
	m.sell_ask = ""
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		return
	var name := Gear.display(list[i])
	var got := Train.sell(prof, where, i)
	if got != "":
		_done(T["sold"] % [name, got], Train.line("sold"), "pickup")



# --- drawn parts --------------------------------------------------------------------------

## Your crystals along the bottom: for each kind, a gem and how much
## essence your crystals of that kind hold (dim when none).
class Purse extends Control:
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var profile

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var kinds: Array = Essence.KINDS.keys()
		var w := size.x / kinds.size()
		var b := UI.Draw.Batch.new()
		for i in kinds.size():
			var c := Vector2(w * i + 12.0, size.y * 0.5)
			var have: float = profile.crystal_total(kinds[i])
			UI.gem_into(b, c, 7.0, Color(Essence.color(kinds[i]), 1.0 if have > 0.0 else 0.3))
		b.flush(self)
		for i in kinds.size():
			var have: float = profile.crystal_total(kinds[i])
			var x := w * i + 23.0
			var col := UI.TEXT if have > 0.0 else UI.FAINT
			var mono := UI.font("mono")
			draw_string(mono, Vector2(x, size.y * 0.5 + 5.0), str(int(have)), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 15, col)
			if size.x > 430.0:
				var nw := mono.get_string_size(str(int(have)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(UI.font("display"), Vector2(x + nw + 4.0, size.y * 0.5 + 5.0), Essence.display(kinds[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 - nw, 15, UI.DIM)


## A price: a gem of its kind, the amount and the kind's name (red if you
## can't pay it); or the gem and other words (`text_override`).
class PriceTag extends Control:
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var amount := 0
	var ok := true
	var text_override := ""

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var b := UI.Draw.Batch.new()
		var t := text_override if text_override != "" else "%d %s" % [amount, Essence.display(kind)]
		if kind == "any":  # (train.gd ANY: crystals of any kind)
			UI.gem_into(b, Vector2(4, size.y * 0.5 + 3.0), 4.0, Essence.color("fire"))
			UI.gem_into(b, Vector2(12, size.y * 0.5 + 3.0), 4.0, Essence.color("water"))
			UI.gem_into(b, Vector2(8, size.y * 0.5 - 2.0), 5.0, UI.GOLD)
		else:
			UI.gem_into(b, Vector2(8, size.y * 0.5), 6.5, Essence.color(kind))
		b.flush(self)
		draw_string(font, Vector2(20, size.y * 0.5 + 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 16, UI.TEXT if ok else UI.BAD)


## A tower's plaque on the engine's destination board: enamel in a brass
## rim, its torch's colour along the top, its name, its essence (a gem) and
## your best floor there. The chosen one is lit in gold.
class TowerCard extends Button:
	const Towers := preload("res://scripts/towers.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var tower := ""
	var last := false
	var chosen := false
	var best := 0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed"]:
			var bg := Color(0.09, 0.13, 0.12) if state == "normal" else Color(0.13, 0.18, 0.16)
			if chosen:
				bg = Color(0.22, 0.17, 0.08) if state == "normal" else Color(0.28, 0.21, 0.1)
			var st := UI.box(bg, Color(UI.GOLD, 0.95) if chosen else Color(UI.TRAIN_BRASS, 0.5 if state == "normal" else 0.85), 5, 2 if chosen else 1)
			add_theme_stylebox_override(state, st)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var t: Dictionary = Towers.TOWERS[tower]
		draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 4)), Color(t["torch"], 0.8))
		var small := size.y < 64.0
		var name: String = t["short"]
		draw_string(UI.font("display"), Vector2(12, 28 if small else 34), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 21 if small else 23, UI.GILT_HI if chosen else UI.TEXT)
		var b := UI.Draw.Batch.new()
		var gy := 43.0 if small else 54.0
		UI.gem_into(b, Vector2(17, gy), 5.0, Essence.color(t["essence"]))
		b.flush(self)
		var sub: String = Essence.display(t["essence"])
		if best > 0:
			sub += "  ·  floor %d" % best
		if last and not small:
			sub += "  ·  last climbed"
		draw_string(font, Vector2(27, gy + 4.0), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 34.0, 13, UI.DIM)
