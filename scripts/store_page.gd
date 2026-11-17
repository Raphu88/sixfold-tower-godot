extends RefCounted
## THE OUTFITTER'S CAR (the store), built into its room on the train
## (train_page.gd calls build; the cards for what's chosen stay there, but
## the upgrade tree's card is here).
##
## One page, no filters and no pages: everything this visit offers shows at
## once, in four sections, top to bottom:
##   Consumables         the supplies shelf (packed onto your belt)
##   Weapons & armour    the outfit rail, and today's piece in its glass case
##                       (with the special order and a relic offered once,
##                       from his upgrade tree)
##   Charms              his charm tray
##   Sell                your pack and your stash (storage_view.gd, the same
##                       look as everywhere): choose a piece, Sell on its card
## When all of it fits the room as grids it shows as grids; when it doesn't
## (a phone, or a big stock at a high rank) the buying sections become a
## compact LIST, a row per thing (its icon, name, price and the green or red
## arrow against what you'd wear), in a column that scrolls.
##
## Beside the goods: the outfitter (what he says) over his UPGRADE TREE
## (outfit_tree.gd, outfitter.gd), when the car is wide enough for it; on a
## narrower screen (a phone, a big Interface size) the tree is its own view
## of the car, behind the Upgrade tree sign under him. The placard (a
## choice's card) is on the right.

const Train := preload("res://scripts/train.gd")
const Shop := preload("res://scripts/shop.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const UI := preload("res://scripts/ui.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Renown := preload("res://scripts/renown.gd")
const Outfitter := preload("res://scripts/outfitter.gd")
const OutfitTree := preload("res://scripts/outfit_tree.gd")
const VesselPage := preload("res://scripts/vessel_page.gd")
const StorageView := preload("res://scripts/storage_view.gd")

## Sizes on a computer and on a phone ([computer, phone], view px).
const PLACARD := [340.0, 290.0]
const GAP := [16.0, 10.0]
const SIDE := [190.0, 140.0]  # the outfitter's column, with the tree in its own view
const TREE := [250.0, 330.0]  # the tree beside the goods: at least, at most
const GOODS_MIN := 330.0  # the goods beside the tree: at least this wide
const ROW_H := [36.0, 36.0]  # a list's rows (big enough for a finger)
## Room kept spare across the car (the car's own scroll bar, if a tall card brings it).
const SLACK := 18.0

var tp  # the train's page (train_page.gd)
var m  # the menu
var listed := false  # the last build showed the goods as a list
var tree_beside := false  # the last build had the tree beside the goods
var goods_scroll: ScrollContainer = null
var tree_view: Control = null


func _init(train_page) -> void:
	tp = train_page
	m = train_page.m


func _t(k: String) -> String:
	return String(Train.TEXT[k])


func _i(pair: Array) -> float:
	return float(pair[1] if tp._small() else pair[0])


## The room's size (train_view.gd Room's area).
func _area() -> Vector2:
	var r = tp.view.rooms.get("store") if tp.view != null else null
	return r.area.size if r != null and r.area.size.x > 0.0 else Vector2(1000, 600)


## Can the tree stand beside the goods and the placard?
func tree_fits() -> bool:
	if tp._small():
		return false
	return _area().x >= TREE[0] + GOODS_MIN + PLACARD[0] + GAP[0] * 2.0 + SLACK


# --- the page ------------------------------------------------------------------------------

func build(root: Node) -> void:
	var prof = tp._prof()
	var small: bool = tp._small()
	if m.train_store != "tree":
		m.train_store = "shop"  # (selling is a section of the one page now: "sell" shows it too)
	var area := _area()
	var gap := _i(GAP)
	var plac := _i(PLACARD)
	tree_beside = tree_fits()
	var view: String = "shop" if tree_beside else m.train_store
	var side := clampf(area.x - GOODS_MIN - plac - gap * 2.0 - SLACK, TREE[0], TREE[1]) if tree_beside else _i(SIDE)
	var tall := area.y - (70.0 if String(tp.tips.get("store", "")) != "" else 0.0) - 8.0
	var row: HBoxContainer = tp._main_row(root)
	row.add_theme_constant_override("separation", int(gap))
	var keys: Array = []
	goods_scroll = null
	tree_view = null
	# The outfitter: what he says, and his tree (or the sign to it).
	var oc := VBoxContainer.new()
	oc.add_theme_constant_override("separation", 4)
	oc.size_flags_vertical = Control.SIZE_SHRINK_CENTER if not tree_beside else Control.SIZE_SHRINK_BEGIN
	oc.custom_minimum_size.x = side
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(oc)
	var said := _line(prof)
	oc.add_child(tp.get_script().outfitter_says(said, 0.0 if small else 34.0))
	var said_h := UI.text_height(UI.font("body"), said, side - (60.0 if not small else 24.0), UI.SIZE_BODY) + 36.0
	for w in Array(prof.store.get("word", [])):
		var wl: Label = tp._note(oc, String(w), side)
		wl.add_theme_color_override("font_color", UI.GILT_HI)
		wl.add_theme_font_size_override("font_size", 12 if small else 13)
		wl.set_meta("store_note", "word")
		said_h += UI.text_height(UI.font("body"), String(w), side, 13) + 4.0
	if tree_beside:
		keys.append_array(_tree(oc, side, tall - said_h - 8.0))
	else:
		if not small or (tall > 300.0 and Array(prof.store.get("word", [])).is_empty()):  # (a phone: his bust only where his words leave room)
			var bust := TrainView.Outfitter.new()
			bust.custom_minimum_size = Vector2(0, 96.0 if small else 140.0)
			oc.add_child(bust)
		var to_tree: bool = view != "tree"
		var sign_text := _t("tree_short" if small else "tree_sign") if to_tree else _t("goods_short" if small else "goods_sign")
		var sign: Button = m._button(sign_text, tp._set_store.bind("tree" if to_tree else "shop"), oc)
		sign.custom_minimum_size.y = 40
		sign.set_meta("store_tab", "tree" if to_tree else "shop")
		UI.keep_text(sign)  # (its words whole: smaller, then wrapped, never cut)
		tp._brass(sign, not to_tree)
		if to_tree and not small:
			var nl: Label = tp._note(oc, Outfitter.TEXT["count"] % [Outfitter.bought_count(prof), Outfitter.ORDER.size()], side)
			nl.add_theme_font_size_override("font_size", 13)
			nl.set_meta("store_note", "tree")
	# The goods, or the tree in its own view: what's left of the room's width
	# beside the outfitter's column (as wide as its words need) and the placard.
	var goods_w := maxf(area.x - maxf(side, oc.get_combined_minimum_size().x) - plac - gap * 2.0 - SLACK, 220.0)
	if view == "tree":
		keys.append_array(_tree(row, goods_w, tall))
	else:
		keys.append_array(_goods(row, goods_w, tall))
	if keys.is_empty():
		m.details = null
		return
	tp._card(row, keys, _first(keys, view), plac)
	var csc: ScrollContainer = tp.card_scrolls.get("store")
	if csc != null:
		csc.set_meta("max_h", maxf(tall - 24.0, 120.0))  # (a long card scrolls in its placard, never makes the car taller)


## What he says: a line of yours just now, his pay for the last climb, or a greeting.
func _line(prof) -> String:
	if m.train_say != "":
		return m.train_say
	if not prof.last_pay.is_empty():
		return Train.line("paid", prof.climbs) % Train.price_text(String(prof.last_pay["kind"]), int(prof.last_pay["amount"]))
	return Train.line("greet", prof.climbs)


## What the placard shows first: the goods' first thing, or in the tree's
## view the first node you could buy (else your rank's).
func _first(keys: Array, view: String) -> String:
	if view != "tree":
		for k in keys:
			if not String(k).begins_with("tree:"):
				return k
		return ""
	var prof = tp._prof()
	for id in Outfitter.ORDER:
		if Outfitter.status(prof, id) == "open":
			return "tree:" + id
	return "tree:rank%d" % Renown.rank(prof)


# --- the goods -------------------------------------------------------------------------------

## The four sections, as grids if they fit `tall`, else as a list in a column that scrolls.
func _goods(row: Node, width: float, tall: float) -> Array:
	var prof = tp._prof()
	var small: bool = tp._small()
	var rack: Array = Train.outfit(prof)
	var kinds: Array = prof.store.get("kinds", [])
	var gear_i: Array = []
	var charm_i: Array = []
	for i in rack.size():
		var charm: bool = (String(kinds[i]) == "charm") if i < kinds.size() else (Gear.is_gear(rack[i]) and Gear.slot_of(rack[i]) == "charm")
		(charm_i if charm else gear_i).append(i)
	var shelf: Array = Train.shelf(prof)
	var cell: float = tp._cell()
	var cols := clampi(int((width - 28.0) / (cell + 6.0)), 3, 6)
	listed = _grid_height(prof, shelf.size(), gear_i.size(), charm_i.size(), cols, width) > tall
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6 if small else 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if listed:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		sc.focus_mode = Control.FOCUS_NONE
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.custom_minimum_size = Vector2(width, maxf(tall, 160.0))
		sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sc.set_meta("store_list", true)
		tp.get_script()._brass_bar(sc)
		row.add_child(sc)
		sc.add_child(col)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goods_scroll = sc
		tp.inner_scrolls["store"] = [sc]
	else:
		col.custom_minimum_size.x = width
		row.add_child(col)
		tp.inner_scrolls.erase("store")
	var row_w := width - (34.0 if listed else 0.0)
	var keys: Array = []
	keys.append_array(_consumables(col, shelf, cols, row_w))
	keys.append_array(_weapons(col, rack, gear_i, cols, row_w))
	keys.append_array(_charms(col, rack, charm_i, cols, row_w))
	keys.append_array(_sell(col, width))
	return keys


## How tall the goods are as grids (view px), to see whether they fit.
func _grid_height(prof, supplies: int, pieces: int, charms: int, cols: int, width: float) -> float:
	var small: bool = tp._small()
	var cell: float = tp._cell()
	var head := 22.0 if small else 26.0
	var frame := 24.0 if small else 30.0
	var rows := func(n: int, c: int, gap: float) -> float:
		return ceilf(float(maxi(n, 1)) / float(maxi(c, 1))) * (cell + gap)
	var h := 0.0
	h += head + frame + rows.call(supplies, cols, 6.0) + (18.0 if Outfitter.owns(prof, "tower_tip") or not Outfitter.belt_gifts(prof).is_empty() else 0.0)
	var rail_cols := maxi(cols - 2, 2)
	h += head + frame + maxf(rows.call(pieces, rail_cols, 16.0), cell * 1.3 + 40.0) + (18.0 if Shop.title_line(prof) != "" else 0.0) + (18.0 if Outfitter.owns(prof, "best_buy") else 0.0)
	h += head + frame + rows.call(charms, cols, 6.0)
	var sell_cols := maxi(int((width - 34.0 + StorageView.GAP) / (StorageView.cell(small) + StorageView.GAP)), 1)
	var sh := head + 20.0
	if not prof.pack.is_empty():
		sh += head + frame + ceilf(float(prof.pack.size()) / sell_cols) * (StorageView.cell(small) + StorageView.GAP)
	if not prof.chest.is_empty() or not prof.vessels.is_empty():
		sh += head + frame + ceilf(float(prof.chest.size() + prof.vessels.size()) / sell_cols) * (StorageView.cell(small) + StorageView.GAP)
	h += sh
	return h + (6.0 if small else 10.0) * 4.0


## A section's furniture and its sign.
func _section(parent: Node, kind: String, title: String) -> VBoxContainer:
	var f: VBoxContainer = tp._furnish(parent, kind)
	tp._tag(f, title)
	return f


## A note under a section's sign (gilt: his word on it).
func _word(f: Node, text: String, meta: String, width: float) -> void:
	var l: Label = tp._note(f, text, maxf(width - 30.0, 120.0))
	l.add_theme_font_size_override("font_size", 12 if tp._small() else 13)
	l.add_theme_color_override("font_color", UI.GILT_HI)
	l.set_meta("store_note", meta)


## Where a section's things go: a grid of slots, or (listed) one column of rows.
func _holder(f: Node, cols: int) -> GridContainer:
	var g: GridContainer = tp._grid(f, 1 if listed else cols, not listed)
	if listed:
		g.add_theme_constant_override("v_separation", 3)
	return g


## A slot made a row of the list (its name beside its icon).
func _as_row(s, name: String, width: float) -> void:
	if not listed:
		return
	s.line = name
	s.custom_minimum_size = Vector2(maxf(width - 30.0, 160.0), _i(ROW_H))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _consumables(col: Node, shelf: Array, cols: int, width: float) -> Array:
	var prof = tp._prof()
	var f := _section(col, "shelf", _t("consumables"))
	var handy: Array = []
	if Outfitter.owns(prof, "tower_tip"):
		handy = Outfitter.handy(m.train_tower, shelf)
		_word(f, Outfitter.tower_line(m.train_tower, shelf), "tower", width)
	var gifts: Array = Outfitter.belt_gifts(prof)
	if not gifts.is_empty():
		_word(f, Outfitter.TEXT["belt_gift"] % ", ".join(gifts.map(func(id): return Items.item_name(String(id)))), "gift", width)
	var g := _holder(f, cols)
	var keys: Array = []
	for id in shelf:
		var price := Train.supply_price(prof, String(id))
		var packed := int(prof.supplies.get(id, 0))
		var s = m._slot(g, "supply:" + String(id), tp._cell(), "")
		s.kind = "item"
		s.id = String(id)
		s.count = packed if packed > 0 else -1
		if handy.has(id):
			s.tag = Outfitter.TEXT["handy_tag"]
		tp._price_on(s, price[0], price[1], true)
		_as_row(s, Items.item_name(String(id)), width)
		keys.append(s.get_meta("slot"))
	return keys


func _weapons(col: Node, rack: Array, gear_i: Array, cols: int, width: float) -> Array:
	var prof = tp._prof()
	var p = tp._player()
	var keys: Array = []
	var low: BoxContainer = VBoxContainer.new() if listed else HBoxContainer.new()
	low.add_theme_constant_override("separation", 6 if listed else (10 if tp._small() else 14))
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(low)
	var rail := _section(low, "rail", _t("weapons"))
	var tline := Shop.title_line(prof)
	if tline != "":
		var tl: Label = tp._note(rail, tline, maxf(width - 140.0 if not listed else width - 30.0, 120.0))
		tl.add_theme_font_size_override("font_size", 12 if tp._small() else 13)
		tl.add_theme_color_override("font_color", UI.GILT_HI)
		tl.set_meta("store_note", "title")
	# His pick for you (his tree): the piece that beats yours by the most.
	var best := ""
	if Outfitter.owns(prof, "best_buy"):
		var top := 0
		var offers: Array = []
		for i in gear_i:
			offers.append(["outfit:%d" % i, rack[i]])
		offers.append(["today", Train.today(prof)])
		offers.append(["order", Train.order(prof)])
		offers.append(["unique", Outfitter.unique(prof)])
		var named := ""
		for o in offers:
			if Gear.is_gear(o[1]):
				var v := Train.versus(prof, p, o[1])
				if v > top:
					top = v
					best = String(o[0])
					named = Gear.display(o[1])
		if best != "":
			_word(rail, Outfitter.TEXT["best"] % named, "best", width - (0.0 if listed else 120.0))
	var g := _holder(rail, maxi(cols - 2, 2))
	if not listed:
		g.add_theme_constant_override("v_separation", 16)
		rail.add_theme_constant_override("separation", 14)
	for i in gear_i:
		var piece: Dictionary = rack[i]
		var s = _piece(g, "outfit:%d" % i, piece, "Sold", best, width)
		keys.append(s.get_meta("slot"))
	# The glass case: today's piece, the special order, a relic offered once.
	var case := _section(low, "case", _t("case"))
	if not listed:
		case.get_parent().size_flags_vertical = Control.SIZE_SHRINK_END
	var cg := _holder(case, 1)
	var ts = _piece(cg, "today", Train.today(prof), "Sold", best, width)
	if not listed:
		ts.custom_minimum_size = Vector2(tp._cell(), tp._cell()) * 1.3
	keys.append("today")
	if Outfitter.owns(prof, "special_order"):
		if not listed:
			tp._tag(case, _t("order"))
		var os = _piece(_holder(case, 1) if not listed else cg, "order", Train.order(prof), "Empty", best, width, _t("order"))
		keys.append(os.get_meta("slot"))
	var uq := Outfitter.unique(prof)
	if not uq.is_empty():
		if not listed:
			tp._tag(case, Outfitter.TEXT["unique"])
		var us = _piece(_holder(case, 1) if not listed else cg, "unique", uq, "", best, width)
		keys.append(us.get_meta("slot"))
	return keys


## A piece he offers, as a slot (or a row): its price, its arrow, "Best" if it's his pick.
func _piece(g: Node, key: String, piece: Dictionary, empty_name: String, best: String, width: float, none_name := "") -> Object:
	var prof = tp._prof()
	var s = tp._gear_slot(g, key, piece, empty_name)
	s.wear = -1.0
	tp._price_on(s, Train.gear_kind(piece), Train.buy_price(prof, piece), not piece.is_empty())
	if not piece.is_empty():
		s.better = signi(Train.versus(prof, tp._player(), piece))
	if key == best:
		s.tag = Outfitter.TEXT["best_tag"]
	_as_row(s, Gear.display(piece) if not piece.is_empty() else (none_name if none_name != "" else empty_name), width)
	return s


func _charms(col: Node, rack: Array, charm_i: Array, cols: int, width: float) -> Array:
	var keys: Array = []
	if charm_i.is_empty():
		return keys
	var f := _section(col, "tray", _t("charms"))
	var g := _holder(f, cols)
	for i in charm_i:
		var s = _piece(g, "outfit:%d" % i, rack[i], "Sold", "", width)
		keys.append(s.get_meta("slot"))
	return keys


## Sell: what you can sell him, your pack and your stash, the same grids as everywhere.
func _sell(col: Node, width: float) -> Array:
	var prof = tp._prof()
	var f := _section(col, "plain", _t("sell"))
	if prof.pack.is_empty() and prof.chest.is_empty() and prof.vessels.is_empty():
		tp._note(f, _t("nothing_to_sell"), maxf(width - 30.0, 120.0)).set_meta("store_note", "nothing")
		return []
	tp._note(f, _t("sell_how") % int(round(Outfitter.sell_share(prof) * 100.0)), maxf(width - 30.0, 120.0)).set_meta("store_note", "sell")
	return tp._pack_and_chest(col, true, tp._area_w() - width + (34.0 if listed else 0.0))


# --- the tree ----------------------------------------------------------------------------------

## The upgrade tree on its board, `width` across and about `tall` high (it
## scrolls if it must be taller).
func _tree(parent: Node, width: float, tall: float) -> Array:
	var prof = tp._prof()
	var small: bool = tp._small()
	var f := _section(parent, "ledger", "%s  ·  %s" % [Outfitter.TEXT["title"], Outfitter.TEXT["count"] % [Outfitter.bought_count(prof), Outfitter.ORDER.size()]])
	var inner := width - (21.0 if small else 28.0)
	var t := OutfitTree.new()
	t.setup(m, prof, inner, tall - (34.0 if small else 44.0), small)
	tree_view = t
	if t.custom_minimum_size.y > tall - 30.0 and tall > 120.0:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		sc.focus_mode = Control.FOCUS_NONE
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.custom_minimum_size = Vector2(inner + 10.0, maxf(tall - (34.0 if small else 44.0), 120.0))
		tp.get_script()._brass_bar(sc)
		f.add_child(sc)
		sc.add_child(t)
		var list: Array = tp.inner_scrolls.get("store", [])
		list.append(sc)
		tp.inner_scrolls["store"] = list
		# (start where your rank is: the tree grows upwards)
		var at: float = t.centers.get("rank%d" % Renown.rank(prof), Vector2.ZERO).y
		sc.set_deferred("scroll_vertical", int(maxf(at - sc.custom_minimum_size.y * 0.5, 0.0)))
	else:
		f.add_child(t)
	return t.keys


## A node's card: what it does, what unlocks it (each part met or not), its
## price and Buy; the trunk's: what your rank stocks.
func tree_card(id: String) -> void:
	var prof = tp._prof()
	if not Outfitter.exists(id):
		tp._head("empty", "", Outfitter.TEXT["title"], UI.DIM)
		return
	var st := Outfitter.status(prof, id)
	var tint: Color = OutfitTree.TINT.get(Outfitter.branch_of(id), UI.GOLD)
	tp._head("empty", "", Outfitter.node_name(id), tint.lightened(0.2))
	_medal_head(id, st, tint)
	if Outfitter.is_trunk(id):
		var rk := Outfitter.trunk_rank(id)
		m._detail_text(Outfitter.TEXT["trunk_rank"] % [rk + 1, Renown.RANKS.size(), Renown.needed(rk)], UI.DIM)
		m._detail_text(Outfitter.node_desc(id), UI.TEXT)
		m._detail_text(Outfitter.TEXT["reached"] if st == "bought" else Outfitter.TEXT["to_reach"] % [Renown.rank_name(rk), Renown.needed(rk)], UI.GOOD if st == "bought" else UI.DIM)
		m._detail_text(Outfitter.TEXT["trunk_note"] % Renown.points(prof), UI.FAINT)
		return
	m._detail_text(Outfitter.TEXT["branch"] % Outfitter.branch_name(Outfitter.branch_of(id)) + "  ·  " + Outfitter.TEXT[st if st != "open" else "ready"], UI.GOOD if st == "bought" else (UI.GOLD if st == "open" else UI.DIM))
	m._detail_text(Outfitter.node_desc(id), UI.TEXT)
	var missing := Outfitter.locks(prof, id)
	for need in Outfitter.requirements(id):
		var met: bool = not missing.has(need)
		m._detail_text((Outfitter.TEXT["needs_have"] if met else Outfitter.TEXT["needs"]) % need, UI.GOOD if met else UI.BAD)
	if Outfitter.FX["discount"].has(id) and Shop.title_discount(prof) > 0.0:
		m._detail_text(Outfitter.TEXT["title_too"] % int(round(Shop.title_discount(prof) * 100.0)) + " " + Outfitter.TEXT["cap_note"] % [int(round(Outfitter.discount(prof) * 100.0)), int(round(float(Outfitter.FX["discount_cap"]) * 100.0))], UI.DIM)
	if st == "bought":
		return
	var why: String = tp._price_line(Train.ANY, Outfitter.cost(id))
	m._detail_text(Outfitter.TEXT["price"] % Outfitter.cost(id), UI.DIM)
	var no := Outfitter.why_not(prof, id)
	var b: Button = m._button(Outfitter.TEXT["buy"], buy_node.bind(id), m.details)
	b.custom_minimum_size.y = 36 if tp._small() else 40
	UI.keep_text(b)
	b.disabled = no != ""
	b.set_meta("tree_buy", id)
	if no != "" and why != "":
		m._detail_text(Outfitter.TEXT["cant"] % why, UI.BAD)
	if not tp._small():
		m._detail_text(Outfitter.TEXT["how"], UI.FAINT)


## The card's heading shows the node's own medallion (not an empty slot).
func _medal_head(id: String, st: String, tint: Color) -> void:
	var row = m.details.get_child(0) if m.details.get_child_count() > 0 else null
	if row == null or row.get_child_count() == 0:
		return
	var old: Control = row.get_child(0)
	var md := OutfitTree.Medal.new()
	md.branch = Outfitter.branch_of(id)
	md.state = st
	md.tint = tint
	md.titled = String(Outfitter.NODES.get(id, {}).get("title", "")) != ""
	md.custom_minimum_size = old.custom_minimum_size
	md.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(md)
	row.move_child(md, 0)
	old.queue_free()
	row.remove_child(old)


func buy_node(id: String) -> void:
	var why := Outfitter.buy(tp._prof(), id)
	if why == "":
		m.inv_sel = "tree:" + id
		tp._done(Outfitter.TEXT["bought_toast"] % Outfitter.node_name(id), Outfitter.line(id), "buy")
	else:
		tp._done(Outfitter.TEXT["cant"] % why, Train.line("poor") if why.begins_with("needs") else "", "ui_back")
