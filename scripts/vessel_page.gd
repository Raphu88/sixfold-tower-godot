extends RefCounted
## The vessel on the train's pages (vessel.gd holds its rules and words):
##   your car     vessels sit in your storage chest, after its pieces; a
##                vessel's card packs it for your next climb (or leaves it)
##   store car    Sell to the outfitter lists them too: a full vessel trades
##                for a crystal of one kind you choose, or some of every kind
##   workshop     the bench's Vessel counter (a Rune Artist): brew one, or
##                work a full one into a piece (+4, or a deep rune)
## and a row in the dev tools. `tp` is the train page (train_page.gd), whose
## building blocks and card helpers these use.

const Vessel := preload("res://scripts/vessel.gd")
const Bench := preload("res://scripts/bench.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")
const UI := preload("res://scripts/ui.gd")

const V := Vessel.TEXT


## A slot for a vessel in a grid (key "vessel:<i>", or the bench's own keys).
static func slot(tp, parent: Node, key: String, v: Dictionary, side := 0.0):
	var s = tp.m._slot(parent, key, side if side > 0.0 else tp._cell(), "")
	s.kind = "vessel"
	s.id = Vessel.code(v)
	s.tint = Vessel.color(v)
	s.on = bool(v.get("packed", false))  # (gilded: packed for your next climb)
	if s.on:
		s.corner = V["packed_tag"]
	return s


## Your vessels, after the chest's pieces in its grid. Returns their keys.
static func chest_slots(tp, grid: Node) -> Array:
	var keys: Array = []
	var list: Array = tp._prof().vessels
	for i in list.size():
		keys.append(slot(tp, grid, "vessel:%d" % i, list[i]).get_meta("slot"))
	return keys


## A vessel's card: in your car, pack it or leave it; at the store, trade it.
static func card(tp, i: int) -> void:
	var prof = tp._prof()
	var m = tp.m
	if i < 0 or i >= prof.vessels.size():
		tp._head("empty", "", "Empty space", UI.DIM)
		return
	var v: Dictionary = prof.vessels[i]
	tp._head("vessel", Vessel.code(v), Vessel.title(), Vessel.color(v).lightened(0.25) if Vessel.fill(v) > 0.0 else UI.GOLD)
	m._detail_text(V["desc_state"] % Vessel.state_text(v), Vessel.color(v).lightened(0.3) if Vessel.fill(v) > 0.0 else UI.TEXT)
	if m.train_car == "store":
		_trade(tp, i, v)
		return
	var packed: bool = bool(v.get("packed", false))
	m._detail_text(V["packed"] if packed else V["in_chest"], UI.DIM)
	var b: Button = m._button(V["leave"] if packed else V["take"], _toggle.bind(tp, i), m.details)
	b.custom_minimum_size.y = 40
	b.set_meta("vessel_pack", i)
	m._detail_text(V["uses"], UI.FAINT)


static func _toggle(tp, i: int) -> void:
	var prof = tp._prof()
	if i >= prof.vessels.size():
		return
	if bool(prof.vessels[i].get("packed", false)):
		Vessel.unpack(prof, i)
		tp._done(V["left"], "", "ui_back")
		return
	var why := Vessel.pack(prof, tp._player(), i)
	if why == "":
		tp._done(V["took"], "", "ui_confirm")
	else:
		tp._done(Train.TEXT["cant"] % why, "", "ui_back")


## The outfitter's offer for a full vessel: a crystal of one kind, or some of
## every kind. Each asks once ("Press again" / "Tap again").
static func _trade(tp, i: int, v: Dictionary) -> void:
	var m = tp.m
	if not Vessel.is_full(v):
		m._detail_text(V["trade_full_only"], UI.DIM)
		return
	m._detail_text(V["trade_title"], UI.GOLD)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	m.details.add_child(grid)
	for k in Essence.KINDS:
		var text: String = V["trade_one"] % [int(Vessel.TRADE["one"]), Essence.display(k)]
		var b := _trade_button(tp, grid, i, k, text)
		b.add_theme_color_override("font_color", Essence.color(k).lightened(0.2))
	var mixed: String = V["trade_mixed"] % [int(Vessel.TRADE["each"]), int(Vessel.TRADE["each"]) * Essence.KINDS.size()]
	_trade_button(tp, m.details, i, "mixed", mixed)


static func _trade_button(tp, parent: Node, i: int, choice: String, text: String) -> Button:
	var m = tp.m
	var ask := "vessel:%d|%s" % [i, choice]
	var asking: bool = m.sell_ask == ask
	var b: Button = m._button(m.Nav.fill(V["trade_ask"] % text, m.main) if asking else text, _do_trade.bind(tp, i, choice), parent)
	b.custom_minimum_size.y = 38
	b.clip_text = true
	b.set_meta("vessel_trade", choice)
	if asking:
		m._primary(b)
	return b


static func _do_trade(tp, i: int, choice: String) -> void:
	var m = tp.m
	var ask := "vessel:%d|%s" % [i, choice]
	if m.sell_ask != ask:
		m.sell_ask = ask
		m.toast = ""
		m.open("train")
		return
	m.sell_ask = ""
	var got := Vessel.trade(tp._prof(), i, choice)
	if got != "":
		m.inv_sel = ""
		tp._done(V["traded"] % got, Train.line("sold"), "pickup")


# --- the bench's Vessel counter --------------------------------------------------------------

## What the counter lists: a vessel to brew, then the pieces a full one can
## be worked into. Returns their keys.
static func bench_list(tp, parent: Node) -> Array:
	var prof = tp._prof()
	var keys: Array = []
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	keys.append(slot(tp, row, "bench:vbrew", Vessel.make()).get_meta("slot"))
	var full: int = Vessel.full_list(prof).size()
	var l := Label.new()
	l.text = V["brew_title"] + "\n" + V["full_count"] % full
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UI.GOLD if full > 0 else UI.DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	keys.append_array(tp._bench_pieces(parent, func(_g): return true))
	return keys


## The counter's card: the brewing card, or a piece's (temper past +3, a deep rune).
static func bench_card(tp, arg: String) -> void:
	var prof = tp._prof()
	var m = tp.m
	if arg == "vbrew":
		tp._head("vessel", Vessel.code(Vessel.make()), V["brew_title"], UI.GOLD)
		tp._lock_line("vessel")
		m._detail_text(V["brew_desc"], UI.TEXT)
		var why: String = tp._cost_lines(Vessel.BREW, Bench.TEXT["cost"])
		if why == "":
			why = Vessel.brew_why(prof)
		var b: Button = m._button(V["brew"], _brew.bind(tp), m.details)
		b.custom_minimum_size.y = 40
		b.disabled = why != ""
		b.set_meta("vessel_brew", true)
		tp._why_line(why)
		m._detail_text(V["deep_note"] % Gear.MAX_RANK, UI.FAINT)
		return
	var g: Dictionary = tp._bench_head(arg)
	if g.is_empty():
		return
	tp._lock_line("vessel")
	tp._trait_list(g)
	var full: int = Vessel.full_list(prof).size()
	m._detail_text(V["full_count"] % full, UI.GOLD if full > 0 else UI.DIM)
	# One rank past the limit.
	var k := int(g["rank"])
	var why := Vessel.deep_temper_why(prof, arg)
	if Bench.temperable(g):
		var to := Gear.RANK_CAP
		m._detail_text(V["deep_temper_head"], UI.DIM)
		var tb: Button = tp._ask_button(m.details, V["deep_temper"] % to, V["deep_temper_ask"] % to, "vtemper", why, "bench_do", "vtemper")
		tb.add_theme_color_override("font_color", UI.GOLD)
		if why != "" and k >= Gear.MAX_RANK:
			tp._why_line(why)
		elif k < Gear.MAX_RANK:
			m._detail_text(V["deep_only"] % Gear.MAX_RANK + ".", UI.DIM)
	# A deep rune.
	var rwhy := ""
	m._detail_text(V["deep_rune_head"], UI.DIM)
	for rune in Vessel.deep_runes():
		var d: String = Vessel.deep_id(rune)
		var dr: Dictionary = Gear.LASTING_RUNES[d]
		rwhy = Vessel.deep_rune_why(prof, arg, rune)
		var short: String = Gear.LASTING_RUNES[rune]["short"]
		var text: String = V["deep_rune"] % [short, String(dr["desc"]) % Gear.amount_text(float(dr["value"]))]
		var b: Button = tp._ask_button(m.details, text, V["deep_rune_ask"] % short, "vrune:" + rune, rwhy, "bench_do", "vrune:" + rune)
		b.add_theme_color_override("font_color", Color(Gear.LASTING_RUNES[d]["color"]).lightened(0.1))
	if g.has("rune"):
		m._detail_text(Bench.TEXT["replaces_rune"], UI.DIM)
	tp._why_line(rwhy if rwhy != V["deep_has"] else "")  # (the Rune Artist's line is said once, above)


static func _brew(tp) -> void:
	var why := Vessel.brew(tp._prof())
	if why == "":
		tp._done(V["brewed"], "", "pickup")
	else:
		tp._done(Bench.TEXT["cant"] % why, "", "ui_back")


## Does a vessel choice on a piece (asked twice, from train_page.gd
## _bench_do): "vtemper" or "vrune:<rune>". Returns [why, said].
static func bench_do(prof, thing: String, ask: String, before: String) -> Array:
	if ask == "vtemper":
		var why := Vessel.deep_temper(prof, thing)
		return [why, V["deep_tempered"] % Gear.display(Bench.piece(prof, thing))]
	var rune := ask.get_slice(":", 1)
	var why := Vessel.deep_rune(prof, thing, rune)
	return [why, V["deep_inscribed"] % [Gear.LASTING_RUNES.get(Vessel.deep_id(rune), {}).get("name", ""), before]]


# --- dev tools ---------------------------------------------------------------------------------

static func dev_row(menu) -> void:
	var row: HBoxContainer = menu._row()
	row.add_child(menu._label(V["dev"], 120.0, UI.DIM))
	menu._button(V["dev_empty"], _dev_give.bind(menu, false), row)
	menu._button(V["dev_full"], _dev_give.bind(menu, true), row)


## Dev: a vessel on your belt (or, with no room or on the train, in your chest).
## A full one holds the essence that isn't your path (Unmaking without one).
static func _dev_give(menu, full: bool) -> void:
	var main = menu.main
	var kind: String = "unmaking"
	if main.profile.path == "unmaking":
		kind = "life"
	var v := Vessel.make(kind, Vessel.CAPACITY) if full else Vessel.make()
	if main.on_train or not Vessel.give(main, v):
		main.profile.vessels.append(v)
		main.profile.save()
	menu._say(V["dev_given"] % Vessel.state_text(v))
