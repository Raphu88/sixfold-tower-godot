extends RefCounted
## Shop variety (shop.gd): the outfitter's stock grows with your renown rank
## (more rail spaces, more supplies, Fine and Rare pieces, more weapon kinds,
## named pieces and relics; every supply one size), a worn title tilts the
## rail and says so (its outfitter benefits, titles.gd, take some off). Every
## visit differs; every new slot is tapped at phone size
## (tests/parts/store_taps.gd does the rest of the store); old saves load;
## the Entity explains it; no banned words. (The Pedlar, at stations and
## camps, is gone: the Noble took his place, tests/parts/stations.gd. Its
## checks here were removed: _merchant_data, _station, _camp, _taps.)
## (The store is one page now, with no pages or filter: _store_ui checks the
## long rail and the full shelf show at once, and _phone_sell the Upgrade
## tree sign on a phone; tests/parts/outfitter.gd has the rest.)
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Shop := preload("res://scripts/shop.gd")
const Train := preload("res://scripts/train.gd")
const Renown := preload("res://scripts/renown.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Stations := preload("res://scripts/stations.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const TestRun := preload("res://scripts/test_run.gd")
const Registry := preload("res://scripts/data_registry.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Titles := preload("res://scripts/titles.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("shop variety: stock by rank and title")
	_stock_by_rank()
	_titles()
	_old_saves()
	_words()
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	await _store_ui(main)
	await _phone_sell(main)
	await _no_pedlar(main)
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


## A climber at a renown rank (no saving).
func _at(rank: int, worn := ""):
	var p = ProfileScript.new()
	p.saving = false
	Renown.state(p)["points"] = Renown.needed(rank)
	if worn != "":
		Renown.state(p)["titles"] = [worn]
		Renown.state(p)["worn"] = worn
	return p


func _kinds(keys: Array) -> int:
	var seen := {}
	for k in keys:
		seen[String(k)] = true
	return seen.size()


## More spaces, kinds and rarities as the rank rises; the weapons open
## in turn; named pieces and relics only high up.
func _stock_by_rank() -> void:
	var sizes: Array = []
	var kinds: Array = []
	for r in Renown.RANKS.size():
		var p = _at(r)
		sizes.append(Train.rack_size(p))
		var best := 0
		for i in 6:
			best = maxi(best, _kinds(Shop.roll_shelf(p)))
		kinds.append(best)
	var more := true
	for r in range(1, sizes.size()):
		more = more and int(sizes[r]) >= int(sizes[r - 1])
	for r in range(1, Renown.OLD_RANKS.size()):  # (the seven older ranks each add spaces; the five between them sometimes only a finer piece)
		more = more and int(sizes[Renown.OLD_RANKS[r]]) > int(sizes[Renown.OLD_RANKS[r - 1]])
	t._check(more and sizes[0] == Train.RACK_SIZE, "the rail never shrinks as the rank rises, and grows at each of the older ranks (%s)" % [sizes])
	t._check(int(kinds[-1]) > int(kinds[0]) + 5 and int(kinds[3]) > int(kinds[1]), "the shelf has more kinds of supply as rank rises (%s)" % [kinds])
	for r in Renown.RANKS.size():
		var p = _at(r)
		Train.stock(p)
		t._check(Train.outfit(p).size() >= 1 and Train.outfit(p).size() <= Train.rack_size(p), "rank %d: the rail fills (%d of %d spaces)" % [r, Train.outfit(p).size(), Train.rack_size(p)])
	# Always there: draughts, tonic, vial and the scroll.
	var low = _at(0)
	var always := true
	for i in 10:
		var sh: Array = Shop.roll_shelf(low)
		for id in Shop.SHELF_ALWAYS:
			always = always and sh.has(id)
	t._check(always, "the draughts, tonic, vial and recall scroll are always on the shelf")
	# One size: every shelf key is a plain item, at every rank, never twice.
	var plain := true
	for r in Renown.RANKS.size():
		for i in 6:
			var sh: Array = Shop.roll_shelf(_at(r))
			plain = plain and sh.all(func(k): return Items.ITEMS.has(String(k)) and sh.count(k) == 1)
	t._check(plain, "every supply on the shelf is one item, one size, at every rank")
	t._check(int(Shop.RANK_STOCK[-1]["kinds"]) <= 14, "the top shelf holds at most 14 kinds (it was padded to 18 kinds and 7 sizes)")
	# Rarities: nothing finer than Common at the start, Fine and Rare higher up.
	var fine_low := 0
	var rare_low := 0
	var fine_top := 0
	var rare_top := 0
	var named_low := 0
	var named_top := 0
	var relic_low := 0
	var relic_top := 0
	for i in 40:
		var lo = _at(0)
		for g in Train.roll_outfit(lo):
			fine_low += 1 if Gear.rarity(g) == "fine" and Gear.slot_of(g) != "charm" else 0
			rare_low += 1 if Gear.rarity(g) == "rare" and Gear.slot_of(g) != "charm" else 0
			named_low += 1 if Gear.named_id(g) != "" else 0
			relic_low += 1 if Gear.rarity(g) == "storied" else 0
		var hi = _at(Renown.RANKS.size() - 1)
		for g in Train.roll_outfit(hi):
			fine_top += 1 if Gear.rarity(g) == "fine" and Gear.slot_of(g) != "charm" else 0
			rare_top += 1 if Gear.rarity(g) == "rare" and Gear.slot_of(g) != "charm" and Gear.named_id(g) == "" else 0
			named_top += 1 if Gear.named_id(g) != "" and Gear.rarity(g) == "rare" else 0
			relic_top += 1 if Gear.rarity(g) == "storied" else 0
	t._check(fine_low == 0 and rare_low == 0 and fine_top > 20 and rare_top > 10, "better pieces on the rail with rank (Fine %d and Rare %d at the top, none at the start)" % [fine_top, rare_top])
	t._check(named_low == 0 and relic_low == 0 and named_top > 0 and relic_top > 0, "named pieces (%d) and relics (%d) hang on the rail only at high ranks" % [named_top, relic_top])
	# Weapons: pistols, crossbows and canes come in with rank.
	var guns_low := false
	var guns_mid := false
	var revolver_low := false
	var revolver_top := false
	for i in 60:
		for g in Train.roll_outfit(_at(0)):
			guns_low = guns_low or Gear.base_id(g) in ["flintlock", "crossbow", "cane", "sword_cane", "revolver", "greatsword"]
		for g in Train.roll_outfit(_at(int(Shop.WEAPON_RANK["flintlock"]))):
			guns_mid = guns_mid or Gear.base_id(g) in ["flintlock", "crossbow"]
			revolver_low = revolver_low or Gear.base_id(g) == "revolver"
		for g in Train.roll_outfit(_at(Renown.RANKS.size() - 1)):
			revolver_top = revolver_top or Gear.base_id(g) == "revolver"
	t._check(not guns_low and guns_mid and not revolver_low and revolver_top, "pistols, crossbows and canes hang on the rail from their rank on, the revolver later")
	# No two visits alike.
	var seen := {}
	for i in 8:
		var p = _at(4)
		Train.stock(p)
		seen[JSON.stringify([p.store["outfit"], p.store["shelf"]])] = true
	t._check(seen.size() >= 7, "every visit is different (%d different stocks in 8)" % seen.size())


## A worn title tilts the rail, says so, and may add an item or take a little off.
func _titles() -> void:
	var neutral = _at(4)
	t._check(Shop.title_line(neutral) == "" and Shop.flavour(neutral).is_empty() and Shop.title_discount(neutral) == 0.0, "no title worn leaves the stock as it is")
	var unknown = _at(4)
	Renown.state(unknown)["worn"] = "no_such_title"
	t._check(Shop.title_line(unknown) == "" and Shop.weight(unknown, "dagger") == 1.0, "an unknown title is neutral")
	var duel = _at(4, "contender")
	t._check(Shop.title_line(duel).begins_with("For the Contender"), "the Contender's line says it comes from the title (%s)" % Shop.title_line(duel))
	var blades := 0
	var blades_n := 0
	for i in 60:
		for g in Train.roll_outfit(duel):
			blades += 1 if Gear.base_id(g) in Shop.GROUPS["blades"] + Shop.GROUPS["guns"] else 0
		for g in Train.roll_outfit(neutral):
			blades_n += 1 if Gear.base_id(g) in Shop.GROUPS["blades"] + Shop.GROUPS["guns"] else 0
	t._check(blades > blades_n * 1.3, "a duel title hangs more blades and pistols (%d against %d)" % [blades, blades_n])
	var arena = _at(4, "ironclad")
	var armour := 0
	var armour_n := 0
	for i in 60:
		for g in Train.roll_outfit(arena):
			armour += 1 if Gear.slot_of(g) in ["armor", "helm", "gloves", "legs", "boots"] else 0
		for g in Train.roll_outfit(neutral):
			armour_n += 1 if Gear.slot_of(g) in ["armor", "helm", "gloves", "legs", "boots"] else 0
	t._check(armour > armour_n, "an arena title hangs more armour (%d against %d)" % [armour, armour_n])
	var shelf: Array = Shop.roll_shelf(duel)
	t._check(shelf.has(String(Shop.TITLE_STOCK["contender"]["item"])), "the Contender's title puts its own item on the shelf")
	var gold = _at(4, "goldhand")
	var before := Train.discount(neutral)
	t._check(Train.discount(gold) > before and is_equal_approx(Train.discount(gold) - before, float(Titles.SOCIAL["goldhand"]["outfitter"]["discount"])), "a title's outfitter benefit takes a little off everything")
	var ok := true
	for id in Shop.TITLE_STOCK:
		ok = ok and Renown.TITLES.has(id) and String(Shop.TITLE_STOCK[id].get("line", "")).begins_with("For ")
	t._check(ok, "every title in the table is a real title with a line that says 'For ...'")


func _old_saves() -> void:
	var path := TestRun.path("user://shop_old.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("train", "store", {"outfit": ["", ""], "today": ""})
	cfg.set_value("train", "supplies", {"draught": 2})
	cfg.save(path)
	var p = ProfileScript.new()
	p.save_path = path
	p.load_save()
	var shelf: Array = Train.shelf(p)
	t._check(shelf.has("draught") and shelf.has("scroll") and Train.supply_price(p, "draught")[1] > 0, "an old save's store (no shelf noted) still shows a shelf")
	Train.stock(p)
	t._check(p.store.has("shelf") or p.store.has("outfit"), "...and restocks")
	t._check(int(p.supplies.get("draught", 0)) == 2, "old packed supplies keep their count")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Packing and putting back count plain items.
	var q = _at(Renown.RANKS.size() - 1)
	Train.pack_supply(q, "tonic", {"water": 5})
	Train.pack_supply(q, "tonic", {"water": 5})
	t._check(int(q.supplies.get("tonic", 0)) == 2 and not q.store.has("sizes"), "packed supplies are counted, with no sizes noted")
	t._check(Train.unpack_supply(q, "tonic") == {"water": 5} and int(q.supplies.get("tonic", 0)) == 1, "putting one back returns what it cost")


## Every word the shop adds is in data, in the Data editor, with no banned words.
func _words() -> void:
	var ids: Array = Registry.SECTIONS.map(func(s): return String(s["id"]))
	t._check(ids.has("shop_words") and ids.has("shop_numbers"), "the shop's tables are in the Data editor")
	var all := JSON.stringify([Shop.TEXT, Shop.TITLE_STOCK, Entity.TIPS["shop_grows"], Entity.TIPS["shop_title"], Talk.DIALOGUE["how_shop"]]).to_lower()
	var bad: Array = BANNED.filter(func(w): return all.contains(w))
	t._check(bad.is_empty(), "no banned words in the shop's words (%s)" % [bad])
	t._check(Talk.DIALOGUE["how"]["choices"].has("how_shop") and Help.HELP.has("store_tab:tree") and not Help.HELP.has("store_filter:page"),
		"the Entity: a 'How does the shop change?' topic, and help for the new buttons (no page buttons)")
	t._check(not Entity.TIPS.has("merchant") and not Help.HELP.has("rail:market") and not Help.HELP.has("pick:ware") and not ("MERCHANT" in Shop) and not all.contains("pedlar"),
		"the Pedlar is gone: no tip, no help, no data")


# --- on screen -------------------------------------------------------------------------------

func _store_ui(main) -> void:
	var menu = main.menu
	var prof = main.profile
	prof.renown = {}
	prof.store = {}
	prof.supplies = {}
	prof.supply_paid = {}
	Renown.state(prof)["points"] = Renown.needed(Renown.RANKS.size() - 1)
	Renown.state(prof)["titles"] = ["contender"]
	Renown.state(prof)["worn"] = "contender"
	main.open_train()
	await t._frames(2)
	prof.store = {}
	Train.stock(prof)
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.open("train")
	await t._frames(4)
	var root = menu.train_page.roots["store"]
	var notes: Array = root.find_children("*", "Label", true, false).filter(func(l): return l.has_meta("store_note") and l.get_meta("store_note") == "title")
	t._check(notes.size() == 1 and String(notes[0].text).begins_with("For the Contender"), "the store says which line comes from your title (%s)" % [notes.map(func(l): return l.text)])
	var rail: Array = t._all_buttons(root).filter(func(b): return String(b.get_meta("slot", "")).begins_with("outfit:"))
	t._check(Train.outfit(prof).size() > 10 and rail.size() == Train.outfit(prof).size() and t._all_buttons(root).filter(func(b): return b.has_meta("store_filter")).is_empty(),
		"a long rail shows every piece at once, with no page button or filter (%d of %d)" % [rail.size(), Train.outfit(prof).size()])
	var slots: Array = t._all_buttons(root).filter(func(b): return String(b.get_meta("slot", "")).begins_with("supply:"))
	t._check(slots.size() == Train.shelf(prof).size() and slots.size() > 12, "the fuller shelf shows every kind at once (%d of %d)" % [slots.size(), Train.shelf(prof).size()])
	var rare: Array = []
	for b in slots:
		var sk := String(b.get_meta("slot")).substr(7)
		if Items.ITEMS.has(sk) and not Items.is_staple(sk) and sk != "scroll" and not sk.begins_with("tincture_"):
			rare.append(b)
	t._check(not rare.is_empty() and not slots.any(func(b): return String(b.get_meta("slot")).contains("@")), "rarer supplies are on the shelf's last page, each one plain item")
	# A rarer supply can be bought, and goes up the tower.
	prof.add_crystal("stone", 800.0)
	prof.add_crystal("water", 800.0)
	prof.add_crystal("fire", 800.0)
	prof.add_crystal("air", 800.0)
	prof.add_crystal("iron", 800.0)
	prof.add_crystal("blade", 800.0)
	var key: String = String(rare[0].get_meta("slot")).substr(7) if not rare.is_empty() else "tonic"
	var id := key
	menu.inv_sel = "supply:" + key
	menu.open("train")
	await t._frames(3)
	var buy: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return b.get_meta("buy", "") == key)
	t._check(buy.size() == 1 and not buy[0].disabled, "its card has Buy (%s)" % key)
	if buy.size() == 1:
		buy[0].pressed.emit()
		await t._frames(3)
	t._check(int(prof.supplies.get(id, 0)) == 1, "a %s is packed" % id)
	Train.pack_up(prof, main.player)
	t._check(main.player.item_count(id) >= 1, "...and it goes on your belt")
	main.open_train()
	await t._frames(2)


## On a phone, at the lowest and the highest rank, the Upgrade tree sign is
## in reach without scrolling, and the Sell section is on the store's page.
func _phone_sell(main) -> void:
	var menu = main.menu
	var prof = main.profile
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	for top in [false, true]:
		Renown.state(prof)["points"] = Renown.needed(Renown.RANKS.size() - 1) if top else 0
		prof.store = {}
		Train.stock(prof)
		menu.train_car = "store"
		menu.train_store = "shop"
		menu.inv_sel = ""
		menu.open("train")
		await t._frames(4)
		var pane = menu.train_page.car_scrolls.get("store")
		if pane != null:
			pane.scroll_vertical = 0
			await t._frames(2)
		var view: Rect2 = menu.get_viewport_rect()
		var root = menu.train_page.roots["store"]
		var up: Array = t._all_buttons(root).filter(func(b): return b.get_meta("store_tab", "") == "tree")
		var sell: Array = t._all_buttons(root).filter(func(b): return String(b.get_meta("slot", "")).begins_with("pack:") or String(b.get_meta("slot", "")).begins_with("chest:"))
		var ok: bool = up.size() == 1 and view.encloses(up[0].get_global_rect()) and (prof.pack.is_empty() and prof.chest.is_empty() or not sell.is_empty())
		t._check(ok, "on a phone at %s rank the Upgrade tree sign is on the screen, and the Sell section on the page (%s in %s; %d to sell)" % ["the top" if top else "the first", up[0].get_global_rect() if up.size() == 1 else "", view, sell.size()])
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.close()
	await t._frames(2)
	main.open_train()
	await t._frames(2)


func _station_buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


## The Pedlar is gone: no stop at a station, no card at a camp.
func _no_pedlar(main) -> void:
	var prof = main.profile
	Renown.state(prof)["points"] = Renown.needed(Renown.RANKS.size() - 1)
	t._check(not Stations.STATIONS.any(func(s): return Array(s.get("stops", [])).has("market")) and not Stations.STOPS.has("market"), "no station has the Pedlar's stall")
	main.in_camp = false
	main.camps_done = []
	main.floor_num = 3
	main._arrive()
	await t._frames(2)
	t._check(main.in_camp and not main.camp["choices"].any(func(c): return String(c).begins_with("pedlar:")), "a camp has no Pedlar's card, even at the top rank")
	main.choose_camp(0)
	await t._frames(2)
	main.camps_done = []
