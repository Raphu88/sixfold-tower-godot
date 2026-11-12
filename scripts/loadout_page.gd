extends RefCounted
## The Loadout (menu.gd's "loadout" page, opened from your car on the train):
## what you'll wear when you set off, and the pack that goes up the tower
## with you.
##
## On the left the climber, drawn large in what you'll wear (gear_look.gd),
## with a small picture of how you look in the tower; beside it a paper doll
## of every slot (gear.gd DOLL). Under them your pack (what goes up the
## tower: its spaces and how many it holds), your belt (supplies packed for
## the climb) and the best of your stash. Choose a slot or a piece and its
## card shows on the right: what it does, set against what you wear (better
## numbers green with an up arrow, worse red with a down arrow), and what you
## can do with it: wear it, take it off into your pack or stash, move it
## between them, or sell it. Pressing a pack or stash piece a second time
## moves it across in one press.
##
## The rules (train.gd): what you choose to wear goes on as you set off, over
## your heirloom or the starting piece in that slot (the heirloom waits on
## the train this climb, still yours); a piece left in your pack goes on in a
## slot nothing else is worn in. The stash never leaves the train.
##
## The stash screen (stash_page.gd) is this page's second tab, and builds on
## it: Q / E (LB / RB) or the tabs switch between them. The words live in
## TEXT (the Data editor: "The train and store").

const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Weapons := preload("res://scripts/weapons.gd")
const UI := preload("res://scripts/ui.gd")
const Appearance := preload("res://scripts/appearance.gd")
const GearLook := preload("res://scripts/gear_look.gd")
const VesselPage := preload("res://scripts/vessel_page.gd")

static var TEXT := {
	"title": "Loadout",
	"sub": "What you'll wear when you set off, and the pack that goes up the tower with you.",
	"eyebrow": "Your car",
	"tab_loadout": "Loadout",
	"tab_stash": "Stash",
	"wear_head": "What you'll wear",
	"pack_head": "Your pack  ·  goes up the tower  ·  %d of %d",
	"stash_head": "Stash  ·  stays on the train  ·  %d of %d",
	"stash_best": "Better than what you wear, in your stash",
	"stash_some": "In your stash (newest first)",
	"stash_none": "Your stash is empty. Pieces you keep there are safe on the train.",
	"belt_head": "Belt  ·  supplies packed for your next climb",
	"belt_none": "Nothing packed yet: the Outfitter's Car sells supplies and the bench brews them. Every climb starts with a Healing and a Stamina Draught.",
	"open_stash": "Open the stash",
	"goes_up": "Going up the tower: what you wear, your pack and your belt. Fall, and the pack and belt are lost. Survive, and your pack comes back down; what you wore stays in the tower unless you keep it as an heirloom.",
	"goes_up_short": "Up the tower: what you wear, your pack, your belt. Only the pack comes back down.",
	"from_heir": "Your heirloom: every climb begins with it.",
	"from_start": "What every climb starts with.",
	"from_wear": "Chosen to wear: it goes on as you set off.",
	"from_pack": "From your pack: it goes on as you set off, because nothing else is worn here.",
	"heir_waits": "Wear something else here and your heirloom waits on the train this climb (it stays yours).",
	"heir_away": "Your heirloom, %s, waits on the train this climb (it stays yours).",
	"empty_slot": "Nothing worn here. Choose a piece from your pack or stash to wear, or buy one in the Outfitter's Car.",
	"no_armor": "No armour",
	"empty": "Empty",
	"take_off_pack": "Take it off: into your pack",
	"take_off_chest": "Take it off: into your stash",
	"not_wear_chest": "Don't wear it: into your stash",
	"wear_instead": "Wear instead:",
	"wear_it": "Wear it",
	"wear_for": "Wear it in place of %s",
	"wear_from": "Wear: %s  (%s)",
	"from_pack_tag": "pack",
	"from_chest_tag": "stash",
	"worn_now": "Now wearing: %s",
	"took_off": "Taken off: %s",
	"in_pack": "In your pack: it goes up the tower with you as a spare.",
	"in_chest": "In your stash: safe on the train. It doesn't go up the tower.",
	"pack_auto": "Nothing is worn in its slot, so you'll put it on as you set off.",
	"press_again_chest": "Press it again to move it to your stash.",
	"press_again_pack": "Press it again to move it into your pack.",
	"same_as_worn": "The same as what you'll wear.",
	"versus_better": "Better than what you wear, on the whole",
	"versus_worse": "Worse than what you wear, on the whole",
	"versus_even": "Much like what you wear",
	"empty_pack": "An empty space in your pack. Your pack goes up the tower with you: fall, and what's in it is lost; survive, and it comes back down.",
	"empty_chest": "An empty space in your stash. Pieces kept here are safe on the train.",
	"supply_card": "Packed for your next climb: %d.",
	"put_back": "Put one back (what you paid comes back)",
	"offhand": "Kept for later: off-hand pieces will change how you parry.",
	"tag_heir": "Heir",
	"tag_pack": "Pack",
	"tag_wear": "Set",
}

var m  # the menu (menu.gd)


func _init(menu) -> void:
	m = menu


func _prof():
	return m.main.profile


func _player():
	return m.main.player


func _small() -> bool:
	return m.compact()


func _cell() -> float:
	return 50.0 if _small() else 56.0


## The selection (menu.gd inv_sel) this page starts on.
func default_sel() -> String:
	return "worn:armor"


# --- the page ---------------------------------------------------------------------

func build() -> void:
	var prof = _prof()
	m._header(TEXT["title"], TEXT["sub"], TEXT["eyebrow"])
	tabs("loadout")
	var keys: Array = []
	# The climber and the doll on the left, the pack, belt and stash under
	# them; the card on the right, the whole height.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if _small() else 20)
	row.set_meta("layout", "loadout.row")
	m.box.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8 if _small() else 14)
	col.add_child(top)
	# The climber, large, in what they'll wear.
	var fig := FigureView.new()
	fig.look = GearLook.dressed(m.main.climber_look, Train.setoff_gear(prof, _player()))
	fig.custom_minimum_size = Vector2(140, 200) if _small() else Vector2(230, 290)
	fig.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fig.set_meta("layout", "loadout.figure")
	top.add_child(fig)
	# The paper doll.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.set_meta("layout", "loadout.doll")
	top.add_child(left)
	_head_label(left, TEXT["wear_head"])
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	var so := Train.setoff(prof, _player())
	for r in Gear.DOLL:
		for slot in r:
			keys.append(_worn_cell(grid, slot, so).get_meta("slot"))
	# Under them: the pack, the belt, the stash.
	keys.append_array(pack_strip(col))
	keys.append_array(_belt_strip(col))
	keys.append_array(_stash_strip(col))
	var note: Label = m._label(TEXT["goes_up_short"] if _small() else TEXT["goes_up"], 0.0, UI.FAINT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13 if _small() else 14)
	note.custom_minimum_size.x = 300.0
	col.add_child(note)
	# The card.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	card_panel(right)
	finish(keys)


## The tabs: Loadout and Stash (Q / E, LB / RB switch them too).
func tabs(current: String) -> void:
	m._tabs([["loadout", TEXT["tab_loadout"]], ["stash", TEXT["tab_stash"]]], current, func(id): m.open(id, m.opened_direct))


## The card's panel (menu.gd details) in `parent`.
func card_panel(parent: Node) -> void:
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), UI.SLOT_EDGE, 8, 1, 10.0 if _small() else 14.0))
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dpanel.custom_minimum_size.x = 250.0 if _small() else 300.0
	dpanel.set_meta("layout", "loadout.card")
	parent.add_child(dpanel)
	m.details = VBoxContainer.new()
	m.details.add_theme_constant_override("separation", 4 if _small() else 6)
	dpanel.add_child(m.details)


## Shows the chosen slot's card (or the first one).
func finish(keys: Array) -> void:
	if not (m.inv_sel in keys):
		m.inv_sel = default_sel() if default_sel() in keys else (keys[0] if not keys.is_empty() else "")
	m._show_details(m.inv_sel)


func _head_label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW + (0 if _small() else 1), Color(UI.GOLD, 0.85))
	parent.add_child(l)
	return l


## A doll cell: what you'll wear in a slot, tagged by where it comes from.
func _worn_cell(parent: Node, slot: String, so: Dictionary):
	var e: Dictionary = so.get(slot, {})
	var g = e.get("rec", null)
	var caption := ""
	if not _small():
		caption = Gear.short(g) if g != null else (TEXT["no_armor"] if slot == "armor" else Gear.SLOT_NAMES.get(slot, slot))
	var s = m._slot(parent, "worn:" + slot, _cell(), caption)
	s.kind = "gear"
	s.id = Gear.base_id(g) if g != null else ""
	s.rec = g
	s.empty = g == null
	s.slot_name = Gear.SLOT_NAMES.get(slot, slot)
	s.tint = Gear.color(g) if g != null else UI.FAINT
	match String(e.get("from", "")):
		"heir":
			s.kept = true
		"pack":
			s.tag = TEXT["tag_pack"]
		"wear":
			s.tag = TEXT["tag_wear"]
	return s


## A cell for a piece in your pack or stash (or an empty space), its arrow
## saying whether it beats what you'd wear.
func piece_cell(parent: Node, where: String, i: int, side := 0.0):
	var list: Array = _prof().chest if where == "chest" else _prof().pack
	var g = list[i] if i < list.size() else null
	var s = m._slot(parent, "%s:%d" % [where, i], side if side > 0.0 else _cell(), "")
	s.kind = "gear"
	s.id = Gear.base_id(g) if g != null else ""
	s.rec = g
	s.empty = g == null
	s.tint = Gear.color(g) if g != null else UI.FAINT
	s.wear = Gear.condition(g) if g != null and Gear.wears(g) else -1.0
	if g != null:
		s.better = signi(Train.versus(_prof(), _player(), g))
		if where == "pack" and _auto_worn(i):
			s.tag = TEXT["tag_pack"]
	return s


## Is this pack piece one you'll put on as you set off (nothing else worn there)?
func _auto_worn(i: int) -> bool:
	for e in Train.setoff(_prof(), _player()).values():
		if e["from"] == "pack" and int(e.get("i", -1)) == i:
			return true
	return false


## Your pack: its spaces (how many it holds), heading saying it goes up.
func pack_strip(parent: Node) -> Array:
	var prof = _prof()
	var size: int = _player().pack_size()
	_head_label(parent, TEXT["pack_head"] % [prof.pack.size(), size])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_meta("layout", "loadout.pack")
	parent.add_child(row)
	var keys: Array = []
	for i in maxi(size, prof.pack.size()):
		keys.append(piece_cell(row, "pack", i).get_meta("slot"))
	return keys


## The belt: supplies packed for the climb (each a slot; its card can put one back).
func _belt_strip(parent: Node) -> Array:
	var prof = _prof()
	var keys: Array = []
	_head_label(parent, TEXT["belt_head"])
	if prof.supplies.is_empty():
		var l: Label = m._label(TEXT["belt_none"], 0.0, UI.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300.0
		l.add_theme_font_size_override("font_size", 14)
		parent.add_child(l)
		return keys
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for id in prof.supplies:
		var s = m._slot(row, "belt:" + String(id), _cell() * 0.86, "")
		s.kind = "item"
		s.id = String(id)
		s.count = int(prof.supplies[id])
		keys.append(s.get_meta("slot"))
	return keys


## The stash's best: pieces better than what you'd wear (else the newest),
## and the button to the stash screen.
func _stash_strip(parent: Node) -> Array:
	var prof = _prof()
	var keys: Array = []
	_head_label(parent, TEXT["stash_head"] % [prof.chest.size(), Train.CHEST_SIZE])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_meta("layout", "loadout.stash")
	parent.add_child(row)
	var idx: Array = []
	for i in prof.chest.size():
		if Train.versus(prof, _player(), prof.chest[i]) > 0:
			idx.append(i)
	idx.sort_custom(func(a, b): return Train.versus(prof, _player(), prof.chest[a]) > Train.versus(prof, _player(), prof.chest[b]))
	var label: String = TEXT["stash_best"]
	if idx.is_empty():
		idx = Train.sorted_indices(prof.chest, "newest")
		label = TEXT["stash_some"]
	var show := mini(idx.size(), 5)
	if prof.chest.is_empty():
		var l: Label = m._label(TEXT["stash_none"], 0.0, UI.DIM)
		l.add_theme_font_size_override("font_size", 14)
		row.add_child(l)
	else:
		var tip: Label = m._label(label, 0.0, UI.DIM)
		tip.add_theme_font_size_override("font_size", 13)
		parent.add_child(tip)
		parent.move_child(tip, row.get_index())
		for k in show:
			keys.append(piece_cell(row, "chest", idx[k]).get_meta("slot"))
	var b: Button = m._button(TEXT["open_stash"], func(): m.open("stash", m.opened_direct), row)
	b.custom_minimum_size = Vector2(0, _cell())
	b.set_meta("open_stash", true)
	return keys


# --- the cards ----------------------------------------------------------------------

func details(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	if key != m.sell_ask:
		m.sell_ask = ""
	match kind:
		"worn":
			_worn_card(arg)
		"pack", "chest":
			piece_card(kind, int(arg))
		"belt":
			_belt_card(arg)
		"vessel":
			VesselPage.card(self, int(arg))


func _head(kind: String, id, title: String, col: Color) -> void:
	m._detail_head(kind, id, title, col)
	if m.toast != "":
		m._detail_text(m.toast, UI.GOLD)


func _btn(text: String, action: Callable, meta: String = "", val = null) -> Button:
	var b: Button = m._button(text, action, m.details)
	b.custom_minimum_size.y = 36 if _small() else 40
	b.clip_text = true
	if meta != "":
		b.set_meta(meta, val)
	return b


## A worn slot's card: what you'll wear there and where it comes from; take
## it off, or wear something else (the pieces that fit from your pack and stash).
func _worn_card(slot: String) -> void:
	var prof = _prof()
	var p = _player()
	var e: Dictionary = Train.setoff(prof, p).get(slot, {})
	var g = e.get("rec", null)
	if g == null:
		_head("empty", "", TEXT["no_armor"] if slot == "armor" else "%s: %s" % [Gear.SLOT_NAMES.get(slot, slot), TEXT["empty"]], UI.DIM)
		m._detail_text(TEXT["empty_slot"], UI.DIM)
	else:
		_head("gear", g, Gear.display(g), Gear.color(g))
		var from := String(e.get("from", ""))
		m._detail_text(TEXT["from_" + from] if TEXT.has("from_" + from) else "", Color(UI.GOLD, 0.9) if from == "heir" else UI.DIM)
		match from:
			"wear":
				var full: bool = Train.pack_room(prof, p) <= 0
				var a := _btn(TEXT["take_off_pack"], _unequip.bind(slot, "pack"), "unequip", slot + ":pack")
				a.disabled = full
				var c := _btn(TEXT["take_off_chest"], _unequip.bind(slot, "chest"), "unequip", slot + ":chest")
				c.disabled = prof.chest.size() >= Train.CHEST_SIZE
				var heir: Array = Gear.heirloom_pieces(prof.heirlooms, Gear.heirloom_slot_for_carry(slot))
				var hi := 1 if slot == "ring2" else 0
				if hi < heir.size():
					m._detail_text(TEXT["heir_away"] % Gear.display(heir[hi]), Color(UI.GOLD, 0.85))
			"pack":
				var i := int(e.get("i", -1))
				var d := _btn(TEXT["not_wear_chest"], _move.bind("pack", i), "move", "pack:%d" % i)
				d.disabled = prof.chest.size() >= Train.CHEST_SIZE
			"heir":
				m._detail_text(TEXT["heir_waits"], UI.FAINT)
		m._detail_lines(g, Gear.SLOT_NAMES.get(slot, ""))
		m._detail_stats(g, null)
	# What else could go here.
	var fits: Array = []
	for where in ["pack", "chest"]:
		var list: Array = prof.pack if where == "pack" else prof.chest
		for i in list.size():
			if slot in Gear.carry_slots(Gear.slot_of(list[i])) and not (g != null and Gear.same(list[i], g)):
				fits.append([where, i, Train.versus(prof, p, list[i])])
	if fits.is_empty():
		return
	fits.sort_custom(func(a, b): return a[2] > b[2])
	m._detail_text(TEXT["wear_instead"], UI.DIM)
	for f in fits.slice(0, 6):
		var list2: Array = prof.pack if f[0] == "pack" else prof.chest
		var name: String = TEXT["wear_from"] % [Gear.display(list2[f[1]]), TEXT["from_pack_tag"] if f[0] == "pack" else TEXT["from_chest_tag"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		m.details.add_child(row)
		var b: Button = m._button(name, _equip.bind(f[0], f[1], slot), row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
		b.clip_text = true
		b.set_meta("equip", "%s:%d" % [f[0], f[1]])
		if f[2] != 0:
			var ar = m.CompareArrow.new()
			ar.up = f[2] > 0
			ar.tint = UI.GOOD if f[2] > 0 else UI.BAD
			ar.custom_minimum_size = Vector2(12, 12)
			ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ar)


## A piece in your pack or stash: set against what you'd wear; wear it, move
## it across, or sell it (asks once).
func piece_card(where: String, i: int) -> void:
	var prof = _prof()
	var p = _player()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		_head("empty", "", "Empty space", UI.DIM)
		m._detail_text(TEXT["empty_chest"] if where == "chest" else TEXT["empty_pack"], UI.DIM)
		return
	var g = list[i]
	_head("gear", g, Gear.display(g), Gear.color(g))
	m._detail_text(TEXT["in_chest"] if where == "chest" else TEXT["in_pack"], UI.DIM)
	if where == "pack" and _auto_worn(i):
		m._detail_text(TEXT["pack_auto"], Color(UI.GOLD, 0.85))
	var vs := Train.versus(prof, p, g)
	var against = Train.worn_against(prof, p, g)
	var same: bool = Gear.is_gear(against) and Gear.same(against, g)
	if same:
		m._detail_text(TEXT["same_as_worn"], UI.DIM)
	else:
		m._detail_text(TEXT["versus_better"] if vs > 0 else (TEXT["versus_worse"] if vs < 0 else TEXT["versus_even"]), UI.GOOD if vs > 0 else (UI.BAD if vs < 0 else UI.DIM))
	# Wear it (for rings: in place of either ring).
	var slots: Array = Gear.carry_slots(Gear.slot_of(g))
	var so := Train.setoff_gear(prof, p)
	if slots.size() > 1 and slots.all(func(sl): return Gear.is_gear(so.get(sl, {}))):
		for sl in slots:
			_btn(TEXT["wear_for"] % Gear.display(so[sl]), _equip.bind(where, i, sl), "equip", "%s:%d:%s" % [where, i, sl])
	else:
		_btn(TEXT["wear_it"], _equip.bind(where, i, ""), "equip", "%s:%d" % [where, i])
	var to_other: String = Train.TEXT["to_pack"] if where == "chest" else Train.TEXT["to_chest"]
	var full: bool = Train.pack_room(prof, p) <= 0 if where == "chest" else prof.chest.size() >= Train.CHEST_SIZE
	var mv := _btn(to_other, _move.bind(where, i), "move", "%s:%d" % [where, i])
	mv.disabled = full
	var kind := Train.gear_kind(g)
	var got := Train.gear_sell(g)
	var key := "%s:%d" % [where, i]
	var sell := _btn(m.Nav.fill(Train.TEXT["sell_ask"] % [got, Essence.display(kind)], m.main) if m.sell_ask == key else Train.TEXT["sell_for"] % [got, Essence.display(kind)], _sell.bind(where, i), "sell", key)
	if m.sell_ask == key:
		m._primary(sell)
	if not full and not _small():
		m._detail_text(TEXT["press_again_pack"] if where == "chest" else TEXT["press_again_chest"], UI.FAINT)
	m._detail_lines(g, Gear.SLOT_NAMES.get(Gear.slot_of(g), ""))
	m._detail_stats(g, against if not same else null)
	if Gear.is_gear(against) and not same:
		var pl := Gear.plays_like(g, against)
		if pl != "":
			m._detail_text(pl, UI.DIM)


func _belt_card(id: String) -> void:
	var prof = _prof()
	if not Items.ITEMS.has(id):
		return
	var data: Dictionary = Items.ITEMS[id]
	_head("item", id, data["name"], Items.color(id))
	m._detail_text(String(data["desc"]).left(1).to_upper() + String(data["desc"]).substr(1) + ".", UI.TEXT)
	m._detail_text(TEXT["supply_card"] % int(prof.supplies.get(id, 0)), UI.DIM)
	if int(prof.supplies.get(id, 0)) > 0:
		_btn(TEXT["put_back"], _put_back.bind(id), "put_back", id)


# --- actions ------------------------------------------------------------------------

## After a choice: the answer on the card (in gold), a sound, the page again.
func _done(text: String, _say: String, sound: String) -> void:
	m.toast = text
	m.toast_t = 3.0
	m.main.sfx(sound, 1.0, -4.0, 0.0)
	if m.page != "train":
		m._want_focus = {"meta": "slot", "value": m.inv_sel}  # (the keys stay on the chosen piece, not whatever took its place)
	m.open(m.page, m.opened_direct)


func _equip(where: String, i: int, into: String) -> void:
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		return
	var g = list[i]
	var why := Train.equip(prof, _player(), where, i, into)
	if why == "":
		var slot := into
		if slot == "":
			for sl in prof.wear:
				if Gear.same(prof.wear[sl], g):
					slot = sl
		m.inv_sel = "worn:" + slot if m.page == "loadout" else m.inv_sel
		_done(TEXT["worn_now"] % Gear.display(g), "", "armor_on")
	else:
		_done(Train.TEXT["cant"] % why, "", "ui_back")


func _unequip(slot: String, to: String) -> void:
	var g = _prof().wear.get(slot, null)
	if g == null:
		return
	var why := Train.unequip(_prof(), _player(), slot, to)
	if why == "":
		_done(TEXT["took_off"] % Gear.display(g), "", "ui_confirm")
	else:
		_done(Train.TEXT["cant"] % why, "", "ui_back")


## Moves a piece between pack and stash; the choice follows it.
func _move(where: String, i: int) -> void:
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i < 0 or i >= list.size():
		return
	var name := Gear.display(list[i])
	var why := Train.move(prof, _player(), where, i)
	if why == "":
		var to := "pack" if where == "chest" else "chest"
		var n: int = prof.pack.size() if to == "pack" else prof.chest.size()
		if not m.inv_sel.begins_with("worn:"):
			m.inv_sel = "%s:%d" % [to, n - 1]
		_done((Train.TEXT["moved_pack"] if to == "pack" else Train.TEXT["moved_chest"]) % name, "", "ui_confirm")
	else:
		_done(Train.TEXT["cant"] % why, "", "ui_back")


## Selling asks once ("Press again to sell"), then sells.
func _sell(where: String, i: int) -> void:
	var key := "%s:%d" % [where, i]
	if m.sell_ask != key:
		m.sell_ask = key
		m.toast = ""
		m.open(m.page, m.opened_direct)
		return
	m.sell_ask = ""
	var prof = _prof()
	var list: Array = prof.chest if where == "chest" else prof.pack
	if i >= list.size():
		return
	var name := Gear.display(list[i])
	var got := Train.sell(prof, where, i)
	if got != "":
		Train.dress(prof, _player())  # (a sold Climber's Pack: the pack's room)
		_done(Train.TEXT["sold"] % [name, got], "", "sell")


func _put_back(id: String) -> void:
	if Train.put_back(_prof(), id):
		_done(Train.TEXT["put_back_done"] % Items.ITEMS[id]["name"], "", "ui_back")


## A second press on a chosen pack or stash piece moves it across.
func quick(key: String) -> bool:
	var kind := key.get_slice(":", 0)
	if kind != "pack" and kind != "chest":
		return false
	var i := int(key.get_slice(":", 1))
	var list: Array = _prof().chest if kind == "chest" else _prof().pack
	if i >= list.size():
		return false
	_move(kind, i)
	return true


## Q / E (LB / RB): the other tab.
func cycle(_by: int) -> void:
	m.open("stash" if m.page == "loadout" else "loadout", m.opened_direct)


# --- drawn parts ----------------------------------------------------------------

## The climber, large and seen from the front, in what they'll wear (a
## dressed look: gear_look.gd), on a soft light; in the corner, a small
## picture of how they look in the tower (seen from above, as mirror.gd
## draws them).
class FigureView extends Control:
	const Appearance := preload("res://scripts/appearance.gd")
	const UI := preload("res://scripts/ui.gd")
	const Palette := preload("res://scripts/palette.gd")
	const Weapons := preload("res://scripts/weapons.gd")
	const Mirror := preload("res://scripts/mirror.gd")
	var look := {}
	var tower := true  # the small tower picture in the corner

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()  # (gear glints and the candle flicker)

	func _draw() -> void:
		if look.is_empty():
			return
		var k := minf(size.y / 300.0, size.x / 176.0)
		var c := Vector2(size.x * (0.44 if tower else 0.5), size.y * 0.47)
		var b := UI.Draw.Batch.new()
		for i in 6:
			b.dot(c + Vector2(0, -10.0 * k), (150.0 - i * 20.0) * k, Color(0.55, 0.5, 0.7, 0.025))
		b.flush(self)
		draw_set_transform(c, 0.0, Vector2(k, k))
		var fb := UI.Draw.Batch.new()
		fb.polygon(UI._oval(Vector2(0, 126), Vector2(66, 11), 24), Color(0, 0, 0, 0.32))
		Appearance.draw_front(fb, look)
		fb.flush(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not tower:
			return
		# How you look in the tower: a patch of floor, the climber from above.
		var r := clampf(size.x * 0.17, 18.0, 34.0)
		var at := Vector2(size.x - r - 2.0, size.y - r - 2.0)
		var tb := UI.Draw.Batch.new()
		tb.dot(at, r + 2.0, Color(0, 0, 0, 0.35))
		tb.dot(at, r, Palette.FLOOR.darkened(0.25))
		tb.dot(at + Vector2(-r * 0.15, -r * 0.15), r * 0.78, Palette.FLOOR.darkened(0.05))
		tb.flush(self)
		var s := r / 22.0
		draw_set_transform(at, 0.0, Vector2(s, s))
		var cb := UI.Draw.Batch.new()
		var f := Vector2(1, 0.6).normalized()
		var id: String = look.get("in_hand", "fists")
		var w := Weapons.info(id) if id != "" else Weapons.info("fists")
		Mirror.draw_climber(cb, look, {"f": f, "sd": f.orthogonal(), "t": Time.get_ticks_msec() * 0.001, "weapon": id if id != "" else "fists",
			"w": w, "armor": {"cloth": "padded", "mail": "chain"}.get(String(look.get("armor_w", "")), String(look.get("armor_w", ""))), "radius": 14.0})
		cb.flush(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
