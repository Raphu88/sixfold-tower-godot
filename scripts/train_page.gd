extends RefCounted
## The train's page in the menus (menu.gd's "train" page), between climbs.
## A row of car tabs (Q / E or LB / RB switch them), the car's own content
## with a list on the left and a detail card on the right (like the
## inventory), and a bar along the bottom with your crystals and a Menu
## button. The words, prices and rules live in train.gd.
##
## Built from the menu's own pieces (its slots, buttons and detail card), so
## mouse, keyboard, controller and touch all work as in the inventory: focus
## or tap a slot for its card, then press the card's button.

const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")

const T := Train.TEXT
## The first time each car shows, the Entity's tip for it (entity.gd TIPS).
const CAR_TIPS := {"personal": "chest", "store": "store"}

var m  # the menu (menu.gd)
var tips := {}  # car -> the Entity's tip said there this visit (kept while the page rebuilds)


func _init(menu) -> void:
	m = menu


func _prof():
	return m.main.profile


func _player():
	return m.main.player


# --- the page ---------------------------------------------------------------------

func build() -> void:
	var prof = _prof()
	Train.stock(prof)
	if not m.compact():
		m._header(T["title"], "")
	_tab_row(Train.CARS, m.train_car, _set_car, "tab", Vector2(104.0, 38.0) if m.compact() else Vector2(140.0, 40.0))
	_speech()
	match m.train_car:
		"store":
			_store()
		"workshop":
			_workshop()
		"depart":
			_depart()
		_:
			_personal()
	m._footer()


## A row of tab buttons, the current one gilded; `meta` names them (tests,
## and the page's first focus). Q and E (LB and RB) switch the car tabs.
func _tab_row(list: Array, current: String, choose: Callable, meta: String, size: Vector2) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.box.add_child(row)
	var keys := ["", ""]
	if meta == "tab" and not m.main.touch_active and not m.compact():
		keys = [Controls.pad_name("lb", m.main.pad_ps), Controls.pad_name("rb", m.main.pad_ps)] if m.main.pad_active else ["Q", "E"]
	if keys[0] != "":
		row.add_child(m._key_hint(keys[0]))
	for t in list:
		var b: Button = m._button(t[1], choose.bind(t[0]), row)
		b.custom_minimum_size = size
		b.set_meta(meta, t[0])
		if meta != "tab":
			b.add_theme_font_size_override("font_size", 14)
		if t[0] == current:
			m._primary(b)
	if keys[1] != "":
		row.add_child(m._key_hint(keys[1]))


func _set_car(id: String) -> void:
	m.get_viewport().gui_release_focus()  # (the new car's tab takes the focus)
	m.train_car = id
	m.inv_sel = ""
	m.sell_ask = ""
	m.train_say = ""
	m.toast = ""
	m.open("train")


func _set_store(id: String) -> void:
	m.train_store = id
	m.inv_sel = ""
	m.sell_ask = ""
	m.toast = ""
	m.open("train")


func _set_side(id: String) -> void:
	m.train_side = id
	m.inv_sel = ""
	m.sell_ask = ""
	m.open("train")


## Q / E or LB / RB: the next car. True if it did something.
func cycle(by: int) -> bool:
	var ids: Array = Train.CARS.map(func(c): return c[0])
	_set_car(ids[(ids.find(m.train_car) + by + ids.size()) % ids.size()])
	return true


## Who speaks at the top of the car: the Entity's tip the first time (the
## train itself, then the chest and the store), the outfitter in the store
## car, or the Entity's line in your car (on a phone, only tips and the
## outfitter, to save room).
func _speech() -> void:
	var car: String = m.train_car
	if not tips.has(car):
		var said: String = m.main.tip_now("train")
		if CAR_TIPS.has(car):
			var own: String = m.main.tip_now(CAR_TIPS[car])
			said = own if said == "" else (said + "\n" + own if own != "" else said)
		tips[car] = said
	var mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
	var face := 30.0 if m.compact() else 40.0
	if String(tips[car]) != "":
		var row = Entity.says(Entity.fill_keys(tips[car], mode, m.main.pad_ps), face)
		row.set_meta("entity", car)
		m.box.add_child(row)
	elif car == "store":
		var line: String = m.train_say if m.train_say != "" else Train.line("greet", _prof().climbs)
		m.box.add_child(outfitter_says(line, face))
	elif car == "personal" and not m.compact():
		var row = Entity.says(Entity.line("train", _prof().climbs), face)
		m.box.add_child(row)


## The outfitter says something: his face, then a brass-edged bubble.
static func outfitter_says(text: String, face := 40.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := OutfitterFace.new()
	f.custom_minimum_size = Vector2(face + 12.0, face)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(f)
	var bubble := PanelContainer.new()
	var st := UI.box(Color(0.13, 0.095, 0.06, 0.95), Color(OutfitterFace.BRASS, 0.5), 10, 1, 10.0)
	st.content_margin_top = 6.0
	st.content_margin_bottom = 7.0
	bubble.add_theme_stylebox_override("panel", st)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	bubble.add_child(col)
	var tag := Label.new()
	tag.text = Train.OUTFITTER["tag"]
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(OutfitterFace.BRASS, 0.9))
	col.add_child(tag)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160.0
	l.add_theme_font_size_override("font_size", UI.SIZE_BODY + 1)
	l.add_theme_color_override("font_color", Color(0.98, 0.9, 0.76))
	col.add_child(l)
	row.set_meta("outfitter_line", text)
	return row


## A list on the left and the detail card on the right.
func _split() -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if m.compact() else 18)
	m.box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4 if m.compact() else 6)
	row.add_child(left)
	return [row, left]


## The detail card (the menu's own: m.details), right of `row`, showing `sel`.
func _card(row: Node, keys: Array, fallback: String) -> void:
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), UI.SLOT_EDGE, 8, 1, 10.0 if m.compact() else 14.0))
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dpanel.custom_minimum_size.x = 220.0 if m.compact() else 280.0
	row.add_child(dpanel)
	m.details = VBoxContainer.new()
	m.details.add_theme_constant_override("separation", 4 if m.compact() else 6)
	dpanel.add_child(m.details)
	if not (m.inv_sel in keys):
		m.inv_sel = fallback if fallback in keys else (keys[0] if not keys.is_empty() else "")
	m._show_details(m.inv_sel)


func _cell() -> float:
	return 52.0 if m.compact() else 56.0


func _grid(parent: Node, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g


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


# --- your car ---------------------------------------------------------------------

## Your heirlooms (the paper doll) and your chest and pack. On a phone the
## doll and the chest take turns (two small buttons switch).
func _personal() -> void:
	var prof = _prof()
	var small: bool = m.compact()
	if small:
		_tab_row([["chest", T["view_chest"]], ["heirlooms", T["view_heirlooms"]]], m.train_side, _set_side, "side", Vector2(110.0, 36.0))
	var parts := _split()
	var row: HBoxContainer = parts[0]
	var left: VBoxContainer = parts[1]
	var keys: Array = []
	var holder: Node = left
	if not small:
		holder = HBoxContainer.new()
		holder.add_theme_constant_override("separation", 18)
		left.add_child(holder)
	if not small or m.train_side == "heirlooms":
		var doll := VBoxContainer.new()
		doll.add_theme_constant_override("separation", 4)
		holder.add_child(doll)
		m._section(T["heirlooms"], doll)
		var grid := _grid(doll, 3)
		for r in Gear.DOLL:
			for slot in r:
				var s = m._heir_cell(grid, slot, _cell(), false)
				keys.append(s.get_meta("slot"))
	if not small or m.train_side == "chest":
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		holder.add_child(col)
		keys.append_array(_pack_and_chest(col))
	_card(row, keys, "pack:0" if not prof.pack.is_empty() else "chest:0")


## Your pack's spaces and your chest's, 4 to a row. Returns their keys.
func _pack_and_chest(parent: Node, filled_only := false) -> Array:
	var prof = _prof()
	var keys: Array = []
	var size: int = _player().pack_size()
	m._section(T["pack"] % [prof.pack.size(), size], parent)
	var pg := _grid(parent, 4)
	for i in maxi(size, prof.pack.size()):
		if filled_only and i >= prof.pack.size():
			break
		var s = _gear_slot(pg, "pack:%d" % i, prof.pack[i] if i < prof.pack.size() else null, "")
		keys.append(s.get_meta("slot"))
	m._section(T["chest"] % [prof.chest.size(), Train.CHEST_SIZE], parent)
	var cg := _grid(parent, 4)
	for i in Train.CHEST_SIZE:
		if filled_only and i >= prof.chest.size():
			break
		var s = _gear_slot(cg, "chest:%d" % i, prof.chest[i] if i < prof.chest.size() else null, "")
		keys.append(s.get_meta("slot"))
	return keys


# --- the store car ----------------------------------------------------------------

func _store() -> void:
	var prof = _prof()
	var small: bool = m.compact()
	_tab_row(Train.STORE_TABS, m.train_store, _set_store, "store_tab", Vector2(96.0, 36.0) if small else Vector2(128.0, 36.0))
	var parts := _split()
	var row: HBoxContainer = parts[0]
	var left: VBoxContainer = parts[1]
	var keys: Array = []
	match m.train_store:
		"outfit":
			var grid := _grid(left, 4)
			var rack := Train.outfit(prof)
			for i in rack.size():
				var g: Dictionary = rack[i]
				var s = _gear_slot(grid, "outfit:%d" % i, g, "Sold")
				s.wear = -1.0
				_price_on(s, Train.gear_kind(g), Train.gear_price(g), not g.is_empty())
				keys.append(s.get_meta("slot"))
			if not small:
				_note(left, T["outfit_note"])
		"today":
			var g := Train.today(prof)
			var s = _gear_slot(left, "today", g, "Sold")
			s.wear = -1.0
			s.custom_minimum_size = Vector2(_cell(), _cell()) * 1.4
			_price_on(s, Train.gear_kind(g), Train.gear_price(g), not g.is_empty())
			keys.append("today")
			_note(left, T["today_note"])
		"sell":
			if prof.pack.is_empty() and prof.chest.is_empty():
				_note(left, T["nothing_to_sell"])
			else:
				keys.append_array(_pack_and_chest(left, true))
		_:
			var grid := _grid(left, 4)
			for id in Train.supplies():
				var price := Train.item_price(id)
				var packed := int(prof.supplies.get(id, 0))
				var s = m._slot(grid, "supply:" + id, _cell(), "")
				s.kind = "item"
				s.id = id
				s.count = packed if packed > 0 else -1
				_price_on(s, price[0], price[1], true)
				keys.append(s.get_meta("slot"))
	if keys.is_empty():
		m.details = null
		return
	_card(row, keys, "")


## A price drawn on a slot: a gem of its kind and the number (red if you
## can't pay it).
func _price_on(s, kind: String, amount: int, show: bool) -> void:
	if not show or amount <= 0:
		return
	s.price = amount
	s.price_kind = kind
	s.price_ok = Train.short_of(_prof(), kind, amount) == ""


func _note(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 4.0 * _cell() + 18.0
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UI.DIM)
	parent.add_child(l)


# --- the workshop car -----------------------------------------------------------------

func _workshop() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.box.add_child(row)
	var lock := LockArt.new()
	lock.custom_minimum_size = Vector2(64, 64)
	row.add_child(lock)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var h := Label.new()
	h.text = T["workshop_title"]
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", UI.GOLD)
	col.add_child(h)
	var l := Label.new()
	l.text = T["workshop"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 260.0
	l.add_theme_color_override("font_color", UI.DIM)
	col.add_child(l)


# --- depart -----------------------------------------------------------------------------

## The tower choice: a card for each tower; choose one and the climb begins.
func _depart() -> void:
	var prof = _prof()
	var small: bool = m.compact()
	if not small:
		var h := Label.new()
		h.text = T["depart_title"]
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_font_size_override("font_size", 20)
		h.add_theme_color_override("font_color", UI.GOLD)
		m.box.add_child(h)
		m._text(T["depart_sub"], UI.DIM, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	m.box.add_child(grid)
	for id in Towers.ORDER:
		var b := TowerCard.new()
		b.tower = id
		b.last = id == prof.last_tower
		b.best = int(prof.record.get("best", {}).get(id, 0))
		b.custom_minimum_size = Vector2(0, 56.0 if small else 72.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("tower", id)
		b.pressed.connect(m.main.depart.bind(id))
		grid.add_child(b)
	var going: Array = prof.pack.map(func(g): return Gear.display(g))
	var n := 0
	for id in prof.supplies:
		n += int(prof.supplies[id])
	if n > 0:
		going.append("%d %s" % [n, "supply" if n == 1 else "supplies"])
	var l: Label = _small_text(T["depart_pack"] % (", ".join(going) if not going.is_empty() else T["depart_none"]), UI.TEXT)
	m.box.add_child(l)
	m.box.add_child(_small_text(T["depart_risk"], UI.DIM))


func _small_text(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 300.0
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	return l


# --- the detail card ------------------------------------------------------------------

## The card for a slot on the train (menu.gd _show_details hands these over;
## heirlooms use the inventory's own card).
func details(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	if key != m.sell_ask:
		m.sell_ask = ""
	match kind:
		"pack", "chest":
			_piece_card(kind, int(arg))
		"supply":
			_supply_card(arg)
		"outfit":
			_offer_card(int(arg))
		"today":
			_offer_card(-1)


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
		_done(T["bought"] % Items.ITEMS[id]["name"], Train.line("bought"), "pickup")
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


# --- the bar along the bottom ----------------------------------------------------------

## Your crystals (a gem and the essence held, for each kind), and Menu.
func footer() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.foot.add_child(row)
	var purse := Purse.new()
	purse.profile = _prof()
	purse.custom_minimum_size = Vector2(0, 36)
	purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(purse)
	var b: Button = m._button(T["menu"], m.open.bind("pause"), row)
	b.custom_minimum_size = Vector2(96, 40)
	if not m.main.touch_active:
		var l: Label = m._label(Controls.pad_text("{start}", m.main.pad_ps) if m.main.pad_active else "Esc", 0.0, UI.FAINT)
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


# --- drawn parts --------------------------------------------------------------------------

## Your crystals along the bottom: for each kind, a gem and how much
## essence your crystals of that kind hold (dim when none).
class Purse extends Control:
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var profile

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
			draw_string(font, Vector2(x, size.y * 0.5 + 5.0), str(int(have)), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 15, col)
			if size.x > 430.0:
				var nw := font.get_string_size(str(int(have)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(font, Vector2(x + nw + 4.0, size.y * 0.5 + 4.0), Essence.display(kinds[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 - nw, 11, UI.DIM)


## A price: a gem of its kind, the amount and the kind's name (red if you
## can't pay it).
class PriceTag extends Control:
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var amount := 0
	var ok := true

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var b := UI.Draw.Batch.new()
		UI.gem_into(b, Vector2(8, size.y * 0.5), 6.5, Essence.color(kind))
		b.flush(self)
		var t := "%d %s" % [amount, Essence.display(kind)]
		draw_string(font, Vector2(20, size.y * 0.5 + 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 14, UI.TEXT if ok else UI.BAD)


## A tower on the Depart car: its torch's colour along the top, its name,
## its essence (a gem) and your best floor there.
class TowerCard extends Button:
	const Towers := preload("res://scripts/towers.gd")
	const Essence := preload("res://scripts/essence.gd")
	const UI := preload("res://scripts/ui.gd")
	var tower := ""
	var last := false
	var best := 0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		if last:
			var st := UI.box(Color(0.24, 0.17, 0.09), Color(UI.GOLD, 0.6), 6)
			add_theme_stylebox_override("normal", st)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var t: Dictionary = Towers.TOWERS[tower]
		draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, 4)), Color(t["torch"], 0.75))
		var small := size.y < 64.0
		var name: String = t["short"] if small or size.x < 190.0 else t["name"]
		draw_string(font, Vector2(12, 26 if small else 30), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 16 if small else 17, UI.TEXT)
		var b := UI.Draw.Batch.new()
		var gy := 42.0 if small else 52.0
		UI.gem_into(b, Vector2(18, gy), 5.0, Essence.color(t["essence"]))
		b.flush(self)
		var sub: String = Essence.display(t["essence"])
		if best > 0:
			sub += "  ·  best floor %d" % best
		if last and not small:
			sub += "  ·  last climbed"
		draw_string(font, Vector2(28, gy + 4.0), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36.0, 11, UI.DIM)


## The workshop's padlock.
class LockArt extends Control:
	const UI := preload("res://scripts/ui.gd")

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, size.x * 0.48, Color(0.11, 0.1, 0.14))
		UI.draw_lock(self, c, size.x * 0.26, Color(0.85, 0.66, 0.36))


## The outfitter's face: an old climber with goggles pushed up on his brow,
## a grey moustache and a high brass-buttoned collar. Drawn in code.
class OutfitterFace extends Control:
	const BRASS := Color(0.86, 0.64, 0.3)
	const SKIN := Color(0.86, 0.68, 0.54)
	const HAIR := Color(0.78, 0.76, 0.74)
	const COAT := Color(0.32, 0.2, 0.14)
	const UI := preload("res://scripts/ui.gd")
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x - 12.0, size.y) * 0.42
		var c := Vector2(r * 1.2, size.y * 0.5)
		var b := UI.Draw.Batch.new()
		# A warm glow behind, then the collar and coat.
		UI.glow_into(b, c, r * 1.5, BRASS, 0.8)
		b.polygon(PackedVector2Array([c + Vector2(-r * 0.95, r * 1.15), c + Vector2(-r * 0.7, r * 0.55), c + Vector2(r * 0.7, r * 0.55), c + Vector2(r * 0.95, r * 1.15)]), COAT)
		b.dot(c + Vector2(-r * 0.2, r * 0.82), r * 0.07, BRASS)
		b.dot(c + Vector2(r * 0.2, r * 0.82), r * 0.07, BRASS)
		# The head, with grey hair at the sides.
		b.ball(c + Vector2(0, -r * 0.05), r * 0.62, SKIN)
		b.dot(c + Vector2(-r * 0.56, -r * 0.08), r * 0.18, HAIR)
		b.dot(c + Vector2(r * 0.56, -r * 0.08), r * 0.18, HAIR)
		# Goggles pushed up on his brow: a strap and two brass rims.
		b.rect(Rect2(c + Vector2(-r * 0.62, -r * 0.5), Vector2(r * 1.24, r * 0.14)), Color(0.22, 0.14, 0.1))
		for side in [-1.0, 1.0]:
			var g := c + Vector2(side * r * 0.24, -r * 0.44)
			b.dot(g, r * 0.2, Color(0.1, 0.08, 0.06))
			b.arc(g, r * 0.2, 0.0, TAU, 14, BRASS, maxf(1.2, r * 0.08))
			b.dot(g + Vector2(-r * 0.06, -r * 0.06), r * 0.05, Color(0.8, 0.9, 1.0, 0.7))
		# Eyes (blinking now and then), a big nose and a grey moustache.
		var open := 1.0 if fmod(t, 5.1) > 0.13 else 0.2
		for side in [-1.0, 1.0]:
			b.rect(Rect2(c + Vector2(side * r * 0.22 - r * 0.06, -r * 0.12 - r * 0.04 * open), Vector2(r * 0.12, r * 0.08 * open + 0.6)), Color(0.12, 0.08, 0.06))
		b.dot(c + Vector2(0, r * 0.08), r * 0.1, SKIN.darkened(0.15))
		b.polygon(PackedVector2Array([c + Vector2(-r * 0.42, r * 0.3), c + Vector2(-r * 0.1, r * 0.16), c + Vector2(0, r * 0.22),
			c + Vector2(r * 0.1, r * 0.16), c + Vector2(r * 0.42, r * 0.3), c + Vector2(r * 0.2, r * 0.3), c + Vector2(0, r * 0.26),
			c + Vector2(-r * 0.2, r * 0.3)]), HAIR)
		b.flush(self)
		# A tail toward the bubble.
		var tip := Vector2(size.x, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(1, -7), tip + Vector2(-9, 0), tip + Vector2(1, 7)]), Color(0.13, 0.095, 0.06, 0.95))
