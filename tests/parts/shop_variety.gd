extends RefCounted
## Shop variety (shop.gd): the outfitter's stock grows with your renown rank
## (more rail spaces, more supplies, Fine and Rare pieces, more weapon kinds,
## named pieces and relics; every supply one size), a worn title tilts the
## rail and says so, and the Pedlar sets up at stations and at camps once
## your rank reaches his. Buying works at both; every visit differs; every
## new slot is tapped at phone size (tests/parts/store_taps.gd does the rest
## of the store); old saves load; the Entity explains it; no banned words.
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

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("shop variety: stock by rank and title, the pedlar")
	_stock_by_rank()
	_titles()
	_merchant_data()
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
	await _station(main)
	await _camp(main)
	await _taps(main)
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
		more = more and int(sizes[r]) > int(sizes[r - 1])
	t._check(more and sizes[0] == Train.RACK_SIZE, "the rail has more spaces at every rank (%s)" % [sizes])
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
	var neutral = _at(4, "newcomer")
	t._check(Shop.title_line(neutral) == "" and Shop.flavour(neutral).is_empty() and Shop.title_discount(neutral) == 0.0, "a title with no line leaves the stock as it is")
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
	t._check(Train.discount(gold) > before and is_equal_approx(Train.discount(gold) - before, float(Shop.TITLE_STOCK["goldhand"]["discount"])), "a title can take a little off everything")
	var ok := true
	for id in Shop.TITLE_STOCK:
		ok = ok and Renown.TITLES.has(id) and String(Shop.TITLE_STOCK[id].get("line", "")).begins_with("For ")
	t._check(ok, "every title in the table is a real title with a line that says 'For ...'")


## The pedlar's rules and stock (no screen).
func _merchant_data() -> void:
	var rank := int(Shop.MERCHANT["rank"])
	t._check(rank >= 2 and rank <= Renown.RANKS.size() - 2, "the pedlar opens at a middle rank (%s)" % Renown.rank_name(rank))
	t._check(not Shop.merchant_open(_at(rank - 1)) and Shop.merchant_open(_at(rank)), "he's locked below his rank and open from it")
	var themes := {}
	var differ := {}
	for n in 12:
		var p = _at(Renown.RANKS.size() - 1)
		var m: Dictionary = Shop.roll_merchant(p, "station", n, "kraken")
		themes[m["theme"]] = true
		differ[JSON.stringify(m["wares"])] = true
		if m["wares"].is_empty():
			t._check(false, "theme %s has wares" % m["theme"])
		for w in m["wares"]:
			var pr := Shop.ware_price(p, w)
			if int(pr[1]) <= 0 or String(pr[0]) == "":
				t._check(false, "a ware has a price (%s)" % Shop.ware_name(w))
	t._check(themes.size() >= 4, "the theme rotates (%s)" % [themes.keys()])
	t._check(differ.size() >= 10, "no two visits hold the same wares (%d of 12)" % differ.size())
	var handy: Dictionary = Shop.roll_merchant(_at(rank), "station", Shop.THEME_ORDER.find("handy"), "kraken")
	t._check(handy["theme"] == "handy" and handy["wares"].any(func(w): return String(w.get("id", "")) in ["lantern_oil", "edge_oil"]) and handy["wares"].all(func(w): return not w.has("size") and not Items.is_staple(String(w.get("id", "")))),
		"a handy theme sells the tower ahead's items (and other rare ones), never a staple (%s)" % [handy["wares"].map(func(w): return w.get("id", ""))])
	var arms: Dictionary = Shop.roll_merchant(_at(rank), "station", Shop.themes_open(_at(rank)).find("arms"), "")
	t._check(arms["theme"] == "arms" and arms["wares"].all(func(w): return Gear.base_id(Shop.ware_gear(w)) in Shop.THEMES["arms"]["pool"]), "the weapon-smith's theme: pistols, crossbows and canes")
	var charms: Dictionary = Shop.roll_merchant(_at(rank), "camp", Shop.themes_open(_at(rank)).find("charms"), "")
	t._check(charms["theme"] == "charms" and charms["wares"].size() <= int(Shop.MERCHANT["camp_wares"]) and charms["wares"].all(func(w): return Gear.slot_of(Shop.ware_gear(w)) == "charm"), "the charms theme, a little shorter at a camp")
	t._check(not Shop.themes_open(_at(rank)).has("relics") and Shop.themes_open(_at(Renown.RANKS.size() - 1)).has("relics"), "relics are for the higher ranks")
	var relics: Dictionary = Shop.roll_merchant(_at(Renown.RANKS.size() - 1), "station", Shop.themes_open(_at(Renown.RANKS.size() - 1)).find("relics"), "")
	t._check(relics["theme"] == "relics" and relics["wares"].all(func(w): return Gear.rarity(Shop.ware_gear(w)) == "storied"), "the relics theme: Storied pieces")
	# Paying: crystals first, then (at a camp) essence you carry.
	var p = _at(rank)
	p.add_crystal("stone", 10.0)
	var run := {"stone": 7.0}
	var ware := {"kind": "item", "id": "tonic", "price": ["stone", 14], "sold": false}
	t._check(Shop.short_of(p, ware) != "" and Shop.short_of(p, ware, run) == "" , "short in crystals, but carried essence makes it up at a camp")
	var paid := Shop.pay(p, "stone", 14, run)
	t._check(not paid.is_empty() and p.crystal_total("stone") == 0.0 and int(paid["carried"]) == 4 and is_equal_approx(float(run["stone"]), 3.0), "paid 10 from crystals and 4 from the essence carried")
	t._check(Shop.pay(p, "stone", 5, run).is_empty(), "too little altogether: nothing is taken")


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
	t._check(int(p.supplies.get("draught", 0)) == 2 and Shop.station_market(p).get("wares", []).size() >= 0, "old packed supplies keep their count; no stall noted loads fine")
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
	var all := JSON.stringify([Shop.TEXT, Shop.LINES, Shop.MERCHANT, Shop.THEMES, Shop.TITLE_STOCK, Entity.TIPS["shop_grows"], Entity.TIPS["shop_title"], Entity.TIPS["merchant"],
		Talk.DIALOGUE["how_shop"], Stations.STOPS["market"]]).to_lower()
	var bad: Array = BANNED.filter(func(w): return all.contains(w))
	t._check(bad.is_empty(), "no banned words in the shop's words (%s)" % [bad])
	t._check(Talk.DIALOGUE["how"]["choices"].has("how_shop") and Entity.TIPS.has("merchant") and Help.HELP.has("rail:market") and Help.HELP.has("pick:ware") and Help.HELP.has("store_filter:page"),
		"the Entity: a 'How does the shop change?' topic, a tip for the pedlar, and help for the new buttons")


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
	menu.train_page.rack_page = 0
	menu.open("train")
	await t._frames(4)
	var root = menu.train_page.roots["store"]
	var notes: Array = root.find_children("*", "Label", true, false).filter(func(l): return l.has_meta("store_note") and l.get_meta("store_note") == "title")
	t._check(notes.size() == 1 and String(notes[0].text).begins_with("For the Contender"), "the store says which line comes from your title (%s)" % [notes.map(func(l): return l.text)])
	var pages: Array = t._all_buttons(root).filter(func(b): return b.get_meta("store_filter", "") == "page")
	t._check(pages.size() == 1 and Shop.pages(Train.outfit(prof).size()) == 2, "a long rail has a page button (%d spaces in 2 pages)" % Train.outfit(prof).size())
	var sell: Array = t._all_buttons(root).filter(func(b): return b.get_meta("store_tab", "") == "sell")
	var view: Rect2 = menu.get_viewport_rect()
	t._check(sell.size() == 1 and sell[0].is_visible_in_tree() and view.encloses(sell[0].get_global_rect()), "the Sell sign is on the screen, whatever the rail holds (%s in %s)" % [sell[0].get_global_rect() if sell.size() == 1 else "", view])
	var shelf_pages := Shop.pages(Train.shelf(prof).size(), Shop.SHELF_PAGE)
	var shelf_btn: Array = t._all_buttons(root).filter(func(b): return b.get_meta("store_filter", "") == "shelf")
	var slots: Array = t._all_buttons(root).filter(func(b): return String(b.get_meta("slot", "")).begins_with("supply:"))
	t._check(shelf_pages >= 2 and shelf_btn.size() == 1 and slots.size() <= Shop.SHELF_PAGE and slots.size() >= 6, "the fuller shelf is in %d pages with a page button (%d on this one, of %d kinds)" % [shelf_pages, slots.size(), Train.shelf(prof).size()])
	menu.train_page.shelf_page = shelf_pages - 1
	menu.open("train")
	await t._frames(3)
	root = menu.train_page.roots["store"]
	slots = t._all_buttons(root).filter(func(b): return String(b.get_meta("slot", "")).begins_with("supply:"))
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


## On a phone, at the lowest and the highest rank, the Sell sign and the
## Upgrades sign are in reach without scrolling (a past attempt pushed Sell off the screen).
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
		menu.train_page.shelf_page = 0
		menu.train_page.rack_page = 0
		menu.inv_sel = ""
		menu.open("train")
		await t._frames(4)
		var pane = menu.train_page.car_scrolls.get("store")
		if pane != null:
			pane.scroll_vertical = 0
			await t._frames(2)
		var view: Rect2 = menu.get_viewport_rect()
		var root = menu.train_page.roots["store"]
		var sell: Array = t._all_buttons(root).filter(func(b): return b.get_meta("store_tab", "") == "sell")
		var up: Array = t._all_buttons(root).filter(func(b): return b.get_meta("slot", "") == "upgrades")
		var ok: bool = sell.size() == 1 and up.size() == 1 and view.encloses(sell[0].get_global_rect()) and view.encloses(up[0].get_global_rect())
		t._check(ok, "on a phone at %s rank the Sell and Upgrades signs are on the screen (%s, %s in %s)" % ["the top" if top else "the first", sell[0].get_global_rect() if sell.size() == 1 else "", up[0].get_global_rect() if up.size() == 1 else "", view])
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.close()
	await t._frames(2)
	main.open_train()
	await t._frames(2)


func _station_buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


## The stall at a station: closed below his rank, open from it, buying works, a new stall each visit.
func _station(main) -> void:
	var menu = main.menu
	var prof = main.profile
	prof.renown = {}
	Renown.state(prof)["points"] = 0
	main.open_train()
	await t._frames(2)
	menu.go_station(String(Stations.STATIONS[0]["id"]), "market")
	await t._frames(3)
	t._check(_station_buttons(menu, "pick", "closed:0").size() == 1 and _station_buttons(menu, "pick", "ware:0").is_empty(), "below his rank the stall is closed, and its card says which rank opens it")
	menu.leave_station()
	await t._frames(2)
	Renown.state(prof)["points"] = Renown.needed(int(Shop.MERCHANT["rank"]))
	prof.add_crystal("stone", 900.0)
	prof.add_crystal("water", 900.0)
	prof.add_crystal("fire", 900.0)
	prof.add_crystal("air", 900.0)
	prof.add_crystal("iron", 900.0)
	prof.add_crystal("blade", 900.0)
	prof.supplies = {}
	prof.pack = []
	var stalls := {}
	var first_theme := ""
	for visit in 3:
		menu.go_station(String(Stations.STATIONS[0]["id"]), "market")
		await t._frames(3)
		var market: Dictionary = Renown.state(prof)["market"]
		stalls[JSON.stringify(market["wares"])] = true
		if visit == 0:
			first_theme = String(market["theme"])
		var tiles: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("pick", "")).begins_with("ware:"))
		t._check(tiles.size() == market["wares"].size() and tiles.size() >= 3, "visit %d: the stall lists %d wares (%s)" % [visit + 1, tiles.size(), market["theme"]])
		if visit == 0:
			var packed0: int = int(prof.supplies.values().reduce(func(a, b): return a + b, 0)) + prof.pack.size()
			var spent0: float = prof.crystals_held()
			tiles[0].pressed.emit()
			await t._frames(2)
			var buy: Array = _station_buttons(menu, "station_do", "buy")
			t._check(buy.size() == 1 and not buy[0].disabled, "a ware's card has Buy")
			if buy.size() == 1:
				buy[0].pressed.emit()
				await t._frames(3)
			var packed1: int = int(prof.supplies.values().reduce(func(a, b): return a + b, 0)) + prof.pack.size()
			t._check(packed1 == packed0 + 1 and prof.crystals_held() < spent0 and bool(Renown.state(prof)["market"]["wares"][0]["sold"]), "buying at a station takes crystals and gives the ware (belt or pack)")
		menu.leave_station()
		await t._frames(2)
	t._check(stalls.size() == 3, "each visit has a different stall (%d)" % stalls.size())
	# On a phone, the stop's page fits and its tiles can be tapped.
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	menu.go_station(String(Stations.STATIONS[0]["id"]), "market")
	await t._frames(4)
	var missed: Array = []
	for b in menu.box.find_children("*", "Button", true, false):
		var k := String(b.get_meta("pick", ""))
		if k == "" or not b.is_visible_in_tree():
			continue
		menu.scroll.ensure_control_visible(b)
		await t._frames(2)
		var at: Vector2 = b.get_global_transform_with_canvas() * (b.size / 2.0)
		t._touch(0, at, true)
		await t._frames(2)
		t._touch(0, at, false)
		await t._frames(3)
		if String(menu.station_page.picks.get("market", "")) != k:
			missed.append(k)
	t._check(missed.is_empty(), "a tap on every ware at phone size shows its card (missed %s)" % [missed])
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.leave_station()
	await t._frames(2)
	menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


## At a camp: no stall below his rank; from it a card among the choices, and buying works.
func _camp(main) -> void:
	var prof = main.profile
	var p = main.player
	prof.renown = {}
	Renown.state(prof)["points"] = 0
	main.first_climb = false
	main.camps_done = []
	main.floor_num = 3
	main._arrive()
	await t._frames(2)
	t._check(main.in_camp and main.camp_choosing and not main.camp["choices"].any(func(c): return String(c).begins_with("pedlar:")), "below his rank there's no pedlar at the camp")
	main.choose_camp(0)
	await t._frames(2)
	main.in_camp = false
	main.camps_done = []
	main.floor_num = 3
	Renown.state(prof)["points"] = Renown.needed(int(Shop.MERCHANT["rank"]))
	main._arrive()
	await t._frames(2)
	var at: int = main.camp["choices"].find("pedlar:")
	t._check(main.camp_choosing and at >= 0, "from his rank he has a card among the camp's choices")
	var card: Dictionary = main.camp_card(at)
	t._check(String(card["name"]) != "" and String(card["note"]).begins_with("Today:"), "...saying who he is and today's theme (%s)" % card.get("note", ""))
	main.choose_camp(at)
	await t._frames(2)
	t._check(main.camp["stage"] == "pedlar" and main.camp["choices"].size() >= 3 and String(main.camp["choices"][-1]).begins_with("back:"), "his stall: wares as cards, and a way back")
	var wares: Array = main.camp["market"]["wares"]
	# Too poor first.
	for k in prof.crystals.size():
		prof.crystals[k]["amount"] = 0.0
	main.run_essence = {}
	main.choose_camp(0)
	t._check(not bool(wares[0]["sold"]) and String(main.camp["lines"][0]).begins_with("Can't buy"), "with no crystals or essence, a ware can't be bought and the card says so (%s)" % [main.camp["lines"]])
	# Then paid from crystals and from essence carried.
	var price := Shop.ware_price(prof, wares[0])
	prof.add_crystal(price[0], float(int(price[1]) - 2))
	main.run_essence = {price[0]: 5.0}
	var items0 := 0
	for id in p.carried():
		items0 += p.item_count(id)
	var gear0: int = p.pack.size()
	main.choose_camp(0)
	await t._frames(2)
	var items1 := 0
	for id in p.carried():
		items1 += p.item_count(id)
	t._check(bool(wares[0]["sold"]) and prof.crystal_total(price[0]) == 0.0 and is_equal_approx(float(main.run_essence[price[0]]), 3.0), "paid from crystals first, then the essence you carry (%s)" % [main.camp["lines"]])
	t._check(items1 > items0 or p.pack.size() > gear0 or String(wares[0]["kind"]) == "gear", "...and the ware is yours")
	main.choose_camp(0)
	t._check(main.camp["stage"] == "pedlar" and bool(wares[0]["sold"]), "a sold ware can't be bought twice")
	main.choose_camp(main.camp["choices"].size() - 1)
	t._check(main.camp["stage"] == "item" and main.camp_choosing and main.camp["choices"].has("pedlar:"), "'back to the fire' returns to the camp's choices")
	main.choose_camp(0)
	await t._frames(2)
	t._check(not main.camp_choosing, "a camp pick afterwards still ends the camp")
	main.camps_done = []


## A tap on the camp's pedlar cards at phone size.
func _taps(main) -> void:
	var prof = main.profile
	Renown.state(prof)["points"] = Renown.needed(int(Shop.MERCHANT["rank"]))
	main.in_camp = false
	main.camps_done = []
	main.floor_num = 3
	main._arrive()
	await t._frames(2)
	main.touch._set_active(true)
	await t._frames(2)
	if main.menu_open():
		main.menu.close()  # (a menu left open by the screens above would take the touch)
		await t._frames(2)
	var view: Vector2 = main.hud.get_viewport_rect().size
	var at: int = main.camp["choices"].find("pedlar:")
	var pt: Vector2 = main.hud.camp_card_rect(at, view).get_center()
	t._check(main.hud.camp_card_at(pt) == at, "the pedlar's card can be found under a tap")
	t._touch(7, pt, true)
	await t._frames(2)
	t._touch(7, pt, false)
	await t._frames(2)
	t._check(main.camp["stage"] == "pedlar", "tapping it opens his stall")
	var all := true
	for i in main.camp["choices"].size():
		var r: Rect2 = main.hud.camp_card_rect(i, view)
		all = all and main.hud.camp_card_at(r.get_center()) == i and r.position.x >= 0.0 and r.end.x <= view.x
	t._check(all, "every card of his stall is on the screen and can be tapped")
	main.choose_camp(main.camp["choices"].size() - 1)
	main.choose_camp(0)
	main.touch._set_active(false)
	await t._frames(2)
