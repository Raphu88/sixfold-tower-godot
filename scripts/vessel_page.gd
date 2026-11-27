extends RefCounted
## The vessel on the train's pages (vessel.gd holds its rules and words):
##   your car     vessels sit in your storage chest, after its pieces; a
##                vessel's card packs it for your next climb (or leaves it),
##                and an empty one's sets what it catches (raw or core)
##   store car    Sell lists them too, but the outfitter doesn't buy them:
##                the cities do (a Noble's contract, contracts.gd ASK)
##   workshop     the bench's Vessel counter (a Rune Artist): brew one, or
##                work a full vessel of core essence into a piece (a core
##                rune, +4, or a deep rune); raw essence becomes tinctures
##                on the Tinctures counter (train_page.gd _tincture_card)
## and a row in the dev tools. `tp` is the train page (train_page.gd), whose
## building blocks and card helpers these use.

const Vessel := preload("res://scripts/vessel.gd")
const Bench := preload("res://scripts/bench.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")
const StorageView := preload("res://scripts/storage_view.gd")
const UI := preload("res://scripts/ui.gd")

static var V := Vessel.TEXT


## A slot for a vessel in a grid (key "vessel:<i>", or the bench's own keys).
static func slot(tp, parent: Node, key: String, v: Dictionary, side := 0.0):
	var s = tp.m._slot(parent, key, side if side > 0.0 else StorageView.cell(tp._small()), "")  # (a stash slot's size)
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


## A vessel's card: in your car, pack it or leave it, and (empty) set what it
## catches; at the store, a word that the cities buy them, not the outfitter.
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
		m._detail_text(V["no_trade"], UI.DIM)
		return
	m._detail_text(Vessel.catch_line(v), UI.TEXT)
	if Vessel.fill(v) <= 0.0:
		var other := "core" if Vessel.is_raw(v) else "raw"
		var cb: Button = m._button(V["catch_" + other], _catch.bind(tp, i, other), m.details)
		cb.custom_minimum_size.y = 38
		cb.set_meta("help", "vessel_catch")
	var packed: bool = bool(v.get("packed", false))
	m._detail_text(V["packed"] if packed else V["in_chest"], UI.DIM)
	var b: Button = m._button(V["leave"] if packed else V["take"], _toggle.bind(tp, i), m.details)
	b.custom_minimum_size.y = 40
	b.set_meta("vessel_pack", i)
	m._detail_text(V["uses_raw"] % int(Vessel.RAW["per_tincture"]) if Vessel.is_raw(v) else V["uses_core"], UI.FAINT)
	m._detail_text(V["lore"], UI.FAINT)


## Sets what an empty vessel in the chest catches.
static func _catch(tp, i: int, c: String) -> void:
	if Vessel.set_chest_catch(tp._prof(), i, c):
		if tp.m.main != null:
			tp.m.main.tip("vessel_raw" if c == "raw" else "vessel")
		tp._done(V["switched"] % (V["raw_word"] if c == "raw" else V["core_word"]), "", "ui_confirm")


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
		tp._done(Train.TEXT["cant"] % why, "", "denied")


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
		m._detail_text(V["brew_desc"], UI.TEXT)
		var why: String = tp._cost_lines(Vessel.brew_cost(prof), Bench.TEXT["cost"])
		tp._crafter_line(Vessel.BREW)
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
	tp._trait_list(g)
	var full: int = Vessel.full_list(prof).size()
	tp._crafter_line({}, Vessel.work_fee(prof, arg))
	m._detail_text(V["full_count"] % full, UI.GOLD if full > 0 else UI.DIM)
	# A core rune: Making's or Unmaking's, from a full vessel of it.
	for kind in Secret.KINDS:
		var runes: Array = Vessel.core_runes(String(kind))
		if runes.is_empty():
			continue
		m._detail_text(V["core_head"] % [Secret.display(String(kind)), int(Vessel.CORE["floors"])], Secret.color(String(kind)).lightened(0.2) if Vessel.full_of_kind(prof, String(kind)) >= 0 else UI.DIM)
		for rune in runes:
			var d: Dictionary = Gear.CORE_RUNES[rune]
			var cwhy := Vessel.core_rune_why(prof, arg, rune)
			var ctext: String = V["core_rune"] % [d["short"], Gear.core_text(rune).get_slice(": ", 1)]
			var cb: Button = tp._ask_button(m.details, ctext, V["core_rune_ask"] % [d["name"], Secret.display(String(kind)), int(Vessel.CORE["floors"])], "vcore:" + rune, cwhy, "bench_do", "vcore:" + rune)
			cb.add_theme_color_override("font_color", Color(d["color"]))
			cb.set_meta("help", "core_rune")
	if g.has("core"):
		m._detail_text(V["core_replaces"], UI.DIM)
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
	tp._why_line(rwhy if rwhy != V["deep_has"] else "")


static func _brew(tp) -> void:
	var why := Vessel.brew(tp._prof())
	if why == "":
		tp._done(V["brewed"], "", "brew")
	else:
		tp._done(Bench.TEXT["cant"] % why, "", "denied")


## Does a vessel choice on a piece (asked twice, from train_page.gd
## _bench_do): "vtemper" or "vrune:<rune>". Returns [why, said].
static func bench_do(prof, thing: String, ask: String, before: String) -> Array:
	if ask == "vtemper":
		var why := Vessel.deep_temper(prof, thing)
		return [why, V["deep_tempered"] % Gear.display(Bench.piece(prof, thing))]
	if ask.begins_with("vcore:"):
		var crune := ask.get_slice(":", 1)
		var cwhy := Vessel.core_rune(prof, thing, crune)
		return [cwhy, V["core_inscribed"] % [Gear.CORE_RUNES.get(crune, {}).get("name", ""), before]]
	var rune := ask.get_slice(":", 1)
	var why := Vessel.deep_rune(prof, thing, rune)
	return [why, V["deep_inscribed"] % [Gear.LASTING_RUNES.get(Vessel.deep_id(rune), {}).get("name", ""), before]]


# --- dev tools ---------------------------------------------------------------------------------

static func dev_row(menu) -> void:
	var row: HBoxContainer = menu._row()
	row.add_child(menu._label(V["dev"], 120.0, UI.DIM))
	menu._button(V["dev_empty"], _dev_give.bind(menu, false), row)
	menu._button(V["dev_full"], _dev_give.bind(menu, true), row)
	menu._button(V["dev_raw"], _dev_give.bind(menu, true, true), row)


## Dev: a vessel on your belt (or, with no room or on the train, in your chest).
## A full one holds the core essence that isn't your path (Unmaking without
## one), or (`raw`) the tower's own raw essence.
static func _dev_give(menu, full: bool, raw := false) -> void:
	var main = menu.main
	var kind: String = "unmaking"
	if main.profile.path == "unmaking":
		kind = "life"
	if raw:
		kind = String(main.tower_data().get("essence", "fire")) if main.has_method("tower_data") else "fire"
	var v := Vessel.make(kind, Vessel.CAPACITY) if full else Vessel.make("", 0.0, Vessel.default_catch(main.profile))
	if main.on_train or not Vessel.give(main, v):
		main.profile.vessels.append(v)
		main.profile.save()
	menu._say(V["dev_given"] % Vessel.state_text(v))
