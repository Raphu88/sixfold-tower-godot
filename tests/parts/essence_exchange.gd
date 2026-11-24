extends RefCounted
## Crystals of a kind you can't use (train.gd ANY_GOODS, bench.gd EXCHANGE):
## everyday goods on Joel's shelf take any kind of essence (the kinds held
## most first, noted, put back exactly), tinctures, gear and the bench keep
## their own kinds; the Workshop's Exchange trades one kind for another at
## 3 for 2, previews the trade, asks first for a big one, never goes below
## zero; nothing bought with any kind sells, breaks or comes home as more
## (or as another kind at a better rate than the Exchange); the Entity's
## first-time words, topic and hover help; the Exchange fits 800x400 and a
## computer, by keys too; no banned words. Run by smoke_test.gd (_part_tests).

const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Guide := preload("res://scripts/guide.gd")
const Out := preload("res://scripts/outfitter.gd")
const UI := preload("res://scripts/ui.gd")
const Menu := preload("res://scripts/menu.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("Everyday goods take any essence, and the Workshop's Exchange")
	_rules()
	await t._fresh_main()
	t.paused = false
	await _buying()
	await _in_the_car()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## Held essence, every kind.
func _held(prof) -> float:
	return float(prof.crystals_held())


# --- the rules -----------------------------------------------------------------------------------

func _rules() -> void:
	var wrong: Array = []
	for id in Train.supplies():
		var p: Array = Train.item_price(id)
		var any: bool = p[0] == Train.ANY
		if Flow.is_tincture(id) == any:
			wrong.append(id)
	_check(wrong.is_empty() and Train.supplies().size() >= 18, "every everyday good on the shelf takes any essence, every tincture keeps its own kind (wrong: %s)" % [wrong])
	_check(Train.item_price("tincture_fire")[0] == "fire" and not Train.everyday("tincture_fire") and not Train.everyday("vessel"), "a tincture (and the vessel) keeps its own kind")
	_check(Train.item_price("draught") == [Train.ANY, int(Train.SUPPLY_PRICE["draught"])] and Train.item_price("tonic")[1] == int(Items.ITEMS["tonic"]["value"]["water"])
		and Train.item_price("scroll") == [Train.ANY, int(Train.ANY_PRICE["scroll"])], "...at the same amounts as before (a Healing Vial %d, a tonic %d, the scroll %d)" % [Train.item_price("draught")[1], Train.item_price("tonic")[1], Train.item_price("scroll")[1]])
	_check(Train.home_kind("draught") == "stone" and Train.price_text(Train.ANY, 3) == "3 of any kind", "its own kind is kept for breaking; its price reads \"3 of any kind\"")
	var gear_any: Array = []
	for id in ["sword", "shortbow", "leather", "satchel", "lucky_knot", "buckler"]:
		if Gear.PIECES.has(id) and Train.gear_kind(Gear.make(id)) == Train.ANY:
			gear_any.append(id)
	_check(gear_any.is_empty(), "gear and charms keep their own kinds (%s)" % [gear_any])
	var brew_any: Array = Bench.BREW.keys().filter(func(id): return Bench.BREW[id].has(Train.ANY))
	_check(brew_any.is_empty(), "the bench's brewing keeps its own kinds")
	# The exchange's numbers.
	_check(int(Bench.EXCHANGE["give"]) == 3 and int(Bench.EXCHANGE["get"]) == 2, "the Exchange starts at 3 for 2 (in data: bench.gd EXCHANGE)")
	_check(Bench.exchange_get(30) == 20 and Bench.exchange_get(3) == 2 and Bench.exchange_get(5) == 2 and Bench.exchange_get(0) == 0, "30 makes 20, 3 makes 2, whole lots only")
	_check(Bench.exchange_amount(31, 90) == 30 and Bench.exchange_amount(1, 90) == 3 and Bench.exchange_amount(60, 39) == 39 and Bench.exchange_amount(30, 0) == 3, "the amount keeps to whole lots, at least one, at most what you hold")
	_check(Bench.exchange_text("fire", "stone", 30) == "Give 30 Fire, get 20 Stone", "the preview reads \"%s\"" % Bench.exchange_text("fire", "stone", 30))
	_check(Bench.exchange_asks(int(Bench.EXCHANGE["big"])) and not Bench.exchange_asks(30), "a trade of %d or more asks first; 30 doesn't" % int(Bench.EXCHANGE["big"]))
	_check(Bench.COUNTERS.any(func(c): return c[0] == "exchange") and not "exchange" in Bench.CRAFTED, "the Exchange is a Workshop counter, open to anyone")


# --- buying, putting back, breaking and the belt ---------------------------------------------------

func _buying() -> void:
	print("everyday goods: paying with any kind")
	var main = t.main
	var prof = main.profile
	var p = main.player
	prof.supplies = {}
	prof.supply_paid = {}
	prof.crystals = []
	prof.add_crystal("fire", 10.0)
	var price := int(Train.supply_price(prof, "draught")[1])
	_check(Train.buy_supply(prof, p, "draught") == "" and prof.crystal_total("fire") == 10.0 - price and Train.last_paid(prof, "draught") == {"fire": float(price)},
		"a Healing Vial bought with Fire alone: %d Fire taken, and noted" % price)
	prof.add_crystal("stone", 20.0)
	var sp := int(Train.supply_price(prof, "stamina")[1])
	_check(Train.buy_supply(prof, p, "stamina") == "" and prof.crystal_total("stone") == 20.0 - sp and prof.crystal_total("fire") == 10.0 - price,
		"a Stamina Vial takes the kind held most (Stone, not Fire)")
	_check(Train.put_back(prof, "stamina") and prof.crystal_total("stone") == 20.0, "put back: exactly what it took comes back")
	# A mix of kinds.
	prof.crystals = []
	prof.add_crystal("fire", 2.0)
	prof.add_crystal("water", 2.0)
	prof.supplies = {}
	prof.supply_paid = {}
	var before := _held(prof)
	var dp := int(Train.supply_price(prof, "draught")[1])
	var ok := Train.buy_supply(prof, p, "draught") == ""
	var paid: Dictionary = Train.last_paid(prof, "draught")
	var sum := 0.0
	for k in paid:
		sum += float(paid[k])
	_check(ok and sum == float(dp) and _held(prof) == before - dp and paid.size() == 2, "short of one kind, it takes a mix (%s), no more than the price" % [paid])
	prof.crystals = []
	prof.add_crystal("air", 1.0)
	_check(Train.buy_supply(prof, p, "draught") == Train.TEXT["needs_any"] % (dp - 1) and prof.crystal_total("air") == 1.0, "with too little it says how much more, of any kind, and takes nothing")
	# Gear still needs its own kind.
	prof.crystals = []
	prof.add_crystal("fire", 500.0)
	var g := Gear.make("sword")
	var gk := Train.gear_kind(g)
	_check(gk != "fire" and Train.short_of(prof, gk, Train.buy_price(prof, g)) != "", "a %s still needs %s: 500 Fire doesn't buy it" % [Gear.display(g), Essence.display(gk)])
	# Breaking a bought one down at the bench: what was paid, in what paid.
	prof.supplies = {}
	prof.supply_paid = {}
	prof.crystals = []
	prof.add_crystal("fire", 100.0)
	Train.buy_supply(prof, p, "tonic")
	var tp := int(Train.supply_price(prof, "tonic")[1])
	var bv: Array = Bench.break_value(prof, "supply:tonic")
	_check(bv[0] == "fire" and int(bv[1]) <= int(floor(tp * Train.SELL_SHARE)) and int(bv[1]) >= 1, "a tonic bought with Fire breaks down for %d Fire, not Water (paid %d)" % [int(bv[1]), tp])
	var held_before := _held(prof)
	Bench.break_down(prof, "supply:tonic")
	_check(_held(prof) < held_before + tp and prof.crystal_total("water") == 0.0, "...so buying and breaking it down never gains essence")
	# The loop sweep: every everyday good, at the most he takes off.
	var loops: Array = []
	var cap := float(Out.FX["discount_cap"])
	for id in Train.supplies():
		if not Train.everyday(id):
			continue
		var amount := int(Train.item_price(id)[1])
		var cheapest := maxi(1, int(round(float(amount) * (1.0 - cap))))
		var note := {"air": float(cheapest)}  # (paid in a kind it isn't worth)
		prof.supplies = {id: 1}
		prof.supply_paid = {id: [note]}
		var back: Array = Train.item_sell(id, prof)
		if back[0] != "air" or int(back[1]) > cheapest:
			loops.append("%s breaks for %s from %d" % [id, back, cheapest])
		prof.belt_paid = {id: [note]}
		var home: Dictionary = Train.belt_worth(prof, {id: 1})
		var got := 0.0
		for k in home:
			got += float(home[k])
			if k != "air":
				loops.append("%s comes home as %s" % [id, k])
		if int(round(got)) > cheapest:
			loops.append("%s comes home as %.1f from %d" % [id, got, cheapest])
	prof.supplies = {}
	prof.supply_paid = {}
	prof.belt_paid = {}
	_check(loops.is_empty(), "no loop: no everyday good, even at the deepest discount, breaks down or comes home as more than it cost, or as another kind (%s)" % [loops])
	# Found ones still break at half their worth.
	var w: Dictionary = Train.belt_worth(prof, {"draught": 1})
	_check(w == Items.break_value({"draught": 1}), "a found Healing Vial still breaks at half its worth (%s)" % [w])
	# Packed, carried up and left unused: home as what paid.
	prof.crystals = []
	prof.add_crystal("fire", 100.0)
	Train.buy_supply(prof, p, "tonic")
	var tonic_paid: Dictionary = Train.last_paid(prof, "tonic")
	Train.pack_up(prof, p)
	_check(prof.belt_paid.get("tonic", []) == [tonic_paid] and p.item_count("tonic") >= 1, "setting off, the tonic goes on the belt and what it cost goes with it")
	var fire_before: float = prof.crystal_total("fire")
	var water_before: float = prof.crystal_total("water")
	main.belt_broken = false
	var line: String = main.break_belt()
	_check(prof.crystal_total("water") == water_before and prof.crystal_total("fire") > fire_before and prof.crystal_total("fire") - fire_before <= float(tp) * Items.BREAK_SHARE + 0.5 and prof.belt_paid.is_empty(),
		"left unused at the end of a climb, it breaks back into Fire (half what it cost), not Water: %s" % line)
	# The Exchange.
	prof.crystals = []
	prof.add_crystal("fire", 90.0)
	var total := _held(prof)
	_check(Bench.exchange(prof, "fire", "stone", 30) == "" and prof.crystal_total("fire") == 60.0 and prof.crystal_total("stone") == 20.0, "the Exchange: 30 Fire for 20 Stone")
	_check(_held(prof) < total, "...and a trade always ends with less essence than it began")
	var why := Bench.exchange(prof, "fire", "stone", 90)
	_check(why == String(Bench.EXCHANGE_TEXT["short"]) % [30, "Fire"] and prof.crystal_total("fire") == 60.0 and prof.crystal_total("stone") == 20.0, "it can't give more than you hold: \"%s\", nothing taken" % why)
	_check(Bench.exchange(prof, "fire", "fire", 3) != "" and Bench.exchange(prof, "fire", "stone", 4) != "" and Bench.exchange(prof, "water", "stone", 3) != "", "nor the same kind, nor a broken lot, nor a kind you hold none of")
	_check(Bench.exchange(prof, "fire", "stone", 60) == "" and prof.crystal_total("fire") == 0.0 and prof.crystal_count("fire") == 0 and prof.crystal_total("stone") == 60.0, "giving it all empties the crystal, never below zero")
	# A trade back loses again: no loop.
	_check(Bench.exchange(prof, "stone", "fire", 60) == "" and prof.crystal_total("fire") == 40.0 and prof.crystal_total("stone") == 0.0, "and trading it back loses again (90 Fire became 40)")


# --- in the Workshop ---------------------------------------------------------------------------

func _exchange_root():
	return t.main.menu.train_page.roots.get("workshop")


func _preview() -> String:
	var root = _exchange_root()
	if root == null:
		return ""
	for l in t._all_labels(root):
		if l.has_meta("exchange_preview") and not l.is_queued_for_deletion():
			return String(l.text)
	return ""


func _btn(meta: String, val):
	var list: Array = t._car_buttons(meta, val).filter(func(b): return not b.is_queued_for_deletion())
	return list[0] if list.size() == 1 else null


func _in_the_car() -> void:
	print("the Exchange in the Workshop car")
	var main = t.main
	var prof = main.profile
	var keep_guide: Dictionary = Guide.state.duplicate(true)
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	main.touch._set_active(false)
	main.pad._set_active(false)
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	prof.crystals = []
	prof.add_crystal("fire", 120.0)
	prof.add_crystal("water", 5.0)
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	menu.train_page.exchange_tip = ""
	menu.train_page.x_to = "stone"
	menu.train_page.x_amount = 30
	menu.train_car = "workshop"
	menu.train_bench = "exchange"
	menu.inv_sel = ""
	menu.open("train")
	await t._frames(4)
	_check(menu.inv_sel == "bench:x:fire", "the Exchange opens on the crystal you hold most of (%s)" % menu.inv_sel)
	var root = _exchange_root()
	var tips: Array = t._all_labels(root).filter(func(l): return l.has_meta("entity") and l.get_meta("entity") == "exchange")
	_check(tips.size() == 1 and Guide.told("exchange"), "the first time there, the Entity explains it")
	var slots: Array = root.find_children("*", "", true, false).filter(func(n): return n.has_meta("slot") and String(n.get_meta("slot")).begins_with("bench:x:"))
	_check(slots.size() == 6, "six crystals to give, one of each kind")
	_check(_preview() == "Give 30 Fire, get 20 Stone", "the card previews the trade: \"%s\"" % _preview())
	# Steps.
	var plus = _btn("exchange_step", "+30")
	if plus != null:
		plus.pressed.emit()
		await t._frames(3)
	_check(_preview() == "Give 60 Fire, get 40 Stone", "+30: \"%s\"" % _preview())
	var minus = _btn("exchange_step", "-3")
	if minus != null:
		minus.pressed.emit()
		await t._frames(3)
	_check(_preview() == "Give 57 Fire, get 38 Stone", "-3: \"%s\"" % _preview())
	var get_air = _btn("exchange_to", "air")
	if get_air != null:
		get_air.pressed.emit()
		await t._frames(3)
	_check(_preview() == "Give 57 Fire, get 38 Air" and menu.inv_sel == "bench:x:fire", "choosing Air to get: \"%s\"" % _preview())
	_check(_btn("exchange_to", "fire") == null, "the kind you give isn't offered to get")
	# A small trade is made at once.
	minus = _btn("exchange_step", "-30")
	if minus != null:
		minus.pressed.emit()
		await t._frames(3)
	var trade = _btn("exchange_do", "fire")
	_check(trade != null and not trade.disabled and not trade.has_meta("asks"), "a trade of 27 is made at once")
	if trade != null:
		trade.pressed.emit()
		await t._frames(3)
	_check(prof.crystal_total("fire") == 93.0 and prof.crystal_total("air") == 18.0 and not menu.asking(), "...27 Fire for 18 Air (fire %d, air %d)" % [int(prof.crystal_total("fire")), int(prof.crystal_total("air"))])
	_check(String(menu.toast).contains("27 Fire") and String(menu.toast).contains("18 Air"), "...and it says what was traded: %s" % menu.toast)
	# A big trade asks first.
	var all_b = _btn("exchange_step", "all")
	if all_b != null:
		all_b.pressed.emit()
		await t._frames(3)
	_check(_preview() == "Give 93 Fire, get 62 Air", "All: \"%s\"" % _preview())
	trade = _btn("exchange_do", "fire")
	_check(trade != null and trade.has_meta("asks"), "a trade of 93 asks first")
	if trade != null:
		trade.pressed.emit()
		await t._frames(2)
	_check(menu.asking() and prof.crystal_total("fire") == 93.0, "...the confirmation pop-up opens, nothing traded yet")
	await t._confirm(false)
	await t._frames(2)
	_check(prof.crystal_total("fire") == 93.0, "Cancel trades nothing")
	trade = _btn("exchange_do", "fire")
	if trade != null:
		trade.pressed.emit()
		await t._frames(2)
	await t._confirm(true)
	await t._frames(3)
	_check(prof.crystal_total("fire") == 0.0 and prof.crystal_total("air") == 80.0, "Confirm trades it: all the Fire for 62 Air (air %d)" % int(prof.crystal_total("air")))
	# Nothing left to give: the button says why.
	menu.inv_sel = "bench:x:fire"
	menu.open("train")
	await t._frames(3)
	trade = _btn("exchange_do", "fire")
	_check(trade != null and trade.disabled, "with no Fire left, Trade can't be pressed")
	# Hover help.
	var helps := {}
	for meta in [["exchange_to", "stone"], ["exchange_step", "+3"], ["exchange_step", "all"], ["exchange_do", "fire"], ["bench_tab", "exchange"]]:
		var b = _btn(meta[0], meta[1])
		helps[meta[0] + ":" + str(meta[1])] = Help.explain(menu, b) if b != null and not Help.missing(b) else ""
	root = _exchange_root()
	var slot = root.find_children("*", "", true, false).filter(func(n): return n.has_meta("slot") and n.get_meta("slot") == "bench:x:air" and not n.is_queued_for_deletion())
	helps["slot"] = Help.explain(menu, slot[0]) if slot.size() == 1 and not Help.missing(slot[0]) else ""
	var empty_help: Array = helps.keys().filter(func(k): return String(helps[k]) == "" or String(helps[k]).contains("{"))
	_check(empty_help.is_empty() and String(helps["slot"]).contains("80") and String(helps["exchange_do:fire"]).contains("Give"), "every Exchange button has the Entity's hover help, filled in (%s)" % [helps])
	# The keys: a crystal, then the card's buttons.
	menu.nav_keys = true
	root = _exchange_root()
	var air_slot = root.find_children("*", "", true, false).filter(func(n): return n.has_meta("slot") and n.get_meta("slot") == "bench:x:air" and not n.is_queued_for_deletion())
	if air_slot.size() == 1:
		air_slot[0].grab_focus()
		await t._frames(2)
		air_slot[0].pressed.emit()
		await t._frames(3)
	var focus = t.root.gui_get_focus_owner()
	_check(menu.inv_sel == "bench:x:air" and focus != null and (focus.has_meta("exchange_to") or focus.has_meta("exchange_step") or focus.has_meta("exchange_do")), "by the keys: a crystal chosen, the focus goes onto its card's buttons (%s)" % (focus.text if focus is Button else str(focus)))
	menu.nav_keys = false
	t.root.gui_release_focus()
	# Fits: a computer and an 800x400 phone.
	var problems: Array = []
	for cfg in [["a computer", Vector2i(1280, 720), false], ["a computer, wide", Vector2i(1920, 1080), false], ["an 800x400 phone", Vector2i(800, 400), true]]:
		t.root.size = cfg[1]
		main.touch._set_active(cfg[2])
		main.apply_view_scale()
		prof.add_crystal("fire", 60.0)
		menu.inv_sel = "bench:x:fire"
		menu.open("train")
		await t._frames(5)
		menu.train_page.reveal_card()  # (on a phone the card stands below, as every counter's: the car scrolls to it)
		await t._frames(2)
		var plac = menu.train_page.card_scrolls.get("workshop")
		var pane = menu.train_page.car_scrolls.get("workshop")
		var view: Rect2 = t.root.get_visible_rect()
		var top = pane if pane != null and is_instance_valid(pane) and menu.train_page._can_scroll(pane) else plac
		if top != null and is_instance_valid(top):
			problems.append_array(t._fit_problems(cfg[0], top, view))
		if plac != null and is_instance_valid(plac) and not view.grow(1.0).intersects(plac.get_global_rect()):
			problems.append("%s: the card can't be scrolled into view" % cfg[0])
		var buttons: Array = t._all_buttons(_exchange_root()).filter(func(b): return b.is_visible_in_tree() and not b.is_queued_for_deletion() and (b.has_meta("exchange_to") or b.has_meta("exchange_step") or b.has_meta("exchange_do")))
		if buttons.size() != 11:
			problems.append("%s: %d Exchange buttons" % [cfg[0], buttons.size()])
		for b in buttons:
			if b.size.y < 34.0 or b.size.x < 34.0:
				problems.append("%s: '%s' too small to touch (%s)" % [cfg[0], b.text, b.size])
			var r: Rect2 = b.get_global_rect()
			if r.position.x < view.position.x - 1.0 or r.end.x > view.end.x + 1.0:
				problems.append("%s: '%s' off screen across" % [cfg[0], b.text])
	_check(problems.is_empty(), "the Exchange fits a computer, a wide window and an 800x400 phone, every button big enough to touch (%s)" % [problems])
	main.touch._set_active(false)
	t.root.size = was
	main.apply_view_scale()
	menu.close()
	await t._frames(2)
	main.on_train = false
	Engine.remove_meta("sixfold_tips")
	Guide.state = keep_guide
	Guide.queue.clear()
	Guide.held.clear()
	Entity.gone.clear()
	t.paused = false
	await t._frames(1)


# --- the Entity's words ----------------------------------------------------------------------------

func _words() -> void:
	print("everyday goods and the Exchange: the Entity's words")
	var TP = load("res://scripts/train_page.gd")
	_check(Entity.TIPS.has("exchange") and Entity.TIPS.has("any_goods") and String(Entity.TIPS["exchange"]["group"]) == "train", "the Entity has a first-time word for the Exchange and for everyday goods (in the Library too)")
	_check(Talk.DIALOGUE.has("how_exchange") and "how_exchange" in Talk.DIALOGUE["how"]["choices"] and "how_exchange" in Talk.DIALOGUE["how_shop"]["choices"], "\"How does it work?\" answers \"Crystals I can't use, and the Exchange?\"")
	var line := Talk.fill(String(Talk.DIALOGUE["how_exchange"]["lines"][0]), Talk._fact_rules())
	_check(not line.contains("{") and line.contains("3") and line.contains("2") and line.contains("a third"), "...with the rate read from its table: %s" % line.left(120))
	var shop := String(Talk.DIALOGUE["how_shop"]["lines"][0])
	_check(shop.contains("any kind"), "the shop topic says everyday goods take any kind")
	_check(String(Entity.TIPS["store"]["more"]).contains("any kind") and String(Entity.TIPS["store"]["more"]).contains("Exchange"), "the store's Archive entry tells of both")
	for k in ["bench_tab:exchange", "slot:bench:x", "exchange_to", "exchange_step", "exchange_step:all", "exchange_do", "exchange_do:big"]:
		_check(Help.HELP.has(k), "hover help: %s" % k)
	_check(String(Help.HELP["slot:supply"]).contains("{any}") and String(Help.TEXT["any_kind"]).contains("Any kind"), "a supply's hover help says any kind pays for it")
	_check(Train.OUTFITTER.has("any") and String(Train.OUTFITTER["any"][2]).contains("Exchange"), "%s has words about it" % load("res://scripts/outfitter_name.gd").NAME)
	var words := JSON.stringify([Entity.TIPS["exchange"], Entity.TIPS["any_goods"], Entity.TIPS["store"], Talk.DIALOGUE["how_exchange"], Talk.DIALOGUE["how_shop"],
		Bench.EXCHANGE_TEXT, Bench.TEXT["notes"], Train.OUTFITTER["any"], Train.TEXT, Help.HELP]).to_lower()
	var found: Array = BANNED.filter(func(w): return RegEx.create_from_string("\\b" + w + "s?\\b").search(words) != null)
	_check(found.is_empty(), "none of the owner's banned words (%s)" % [found])
	_check(not words.contains("{outfitter}"), "no {outfitter} left unfilled")
