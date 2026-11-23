extends RefCounted
## The Outfitter's Car reworked (store_page.gd, outfitter.gd, outfit_tree.gd):
## everything he offers on one page, with no filter and no pages, in four
## sections (Consumables, Weapons & armour, Charms, Sell); a list that
## scrolls when it doesn't fit (a phone, a big stock), every row tapped and
## bought at a phone's size; his upgrade tree, whose nodes open with renown
## rank and titles, are bought with crystals of any kind, and do what they
## say (prices, rare stock, gifts, word); the tree marks bought, open and
## locked nodes and its cards say what each does and what opens it; old
## saves keep the upgrades a rank used to unlock; the Entity explains it;
## no banned words. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Train := preload("res://scripts/train.gd")
const Shop := preload("res://scripts/shop.gd")
const Out := preload("res://scripts/outfitter.gd")
const Renown := preload("res://scripts/renown.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const TestRun := preload("res://scripts/test_run.gd")
const Registry := preload("res://scripts/data_registry.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Titles := preload("res://scripts/titles.gd")
const OutfitTree := preload("res://scripts/outfit_tree.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the outfitter's car: one page, a list, and his upgrade tree")
	_data()
	_opening()
	_prices()
	_stock()
	_gifts_and_word()
	_old_saves()
	_words()
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	await _one_page(main)
	await _tree_ui(main)
	await _phone(main)
	await _contract_hint(main)
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


## A climber at a rank (no saving), with crystals.
func _at(rank: int, crystals := 0.0):
	var p = ProfileScript.new()
	p.saving = false
	Renown.state(p)["points"] = Renown.needed(rank)
	for k in Essence.KINDS:
		if crystals > 0.0:
			p.add_crystal(k, crystals)
	return p


func _own(p, ids: Array) -> void:
	for id in ids:
		if not Out.state(p)["bought"].has(id):
			Out.state(p)["bought"].append(id)


# --- the tree's data ---------------------------------------------------------------------------

func _data() -> void:
	var bad: Array = []
	var cells := {}
	for id in Out.NODES:
		var n: Dictionary = Out.NODES[id]
		for k in ["branch", "rank", "cost", "needs", "title", "name", "desc", "say"]:
			if not n.has(k):
				bad.append("%s lacks %s" % [id, k])
		if not Out.COLUMNS.has(String(n.get("branch", ""))) or String(n.get("branch", "")) == "trunk":
			bad.append("%s: no such branch" % id)
		for p in n.get("needs", []):
			if not Out.NODES.has(String(p)) or int(Out.NODES[p]["rank"]) >= int(n["rank"]):
				bad.append("%s needs %s (missing, or not below it)" % [id, p])
		if String(n.get("title", "")) != "" and not Renown.TITLES.has(String(n["title"])):
			bad.append("%s: no such title %s" % [id, n["title"]])
		var cell := "%s:%d" % [n.get("branch", ""), int(n.get("rank", 0))]
		if cells.has(cell):
			bad.append("%s and %s share a place in the tree" % [id, cells[cell]])
		cells[cell] = id
		if int(n.get("rank", 0)) < 1 or int(n.get("rank", 0)) >= Renown.RANKS.size() or int(n.get("cost", 0)) <= 0:
			bad.append("%s: rank or cost out of range" % id)
	t._check(bad.is_empty(), "every node of the tree has a branch, a rank, a cost, what it needs, a name, what it does and his line (%s)" % [bad])
	t._check(Out.ORDER.size() == Out.NODES.size() and Out.ORDER.all(func(id): return Out.NODES.has(id)), "the tree's order lists every node once")
	var kinds := {}
	for id in Out.NODES:
		kinds[String(Out.NODES[id]["branch"])] = int(kinds.get(String(Out.NODES[id]["branch"]), 0)) + 1
	t._check(kinds.keys().size() == 4 and kinds.values().all(func(n): return n >= 4), "four branches (prices, stock, gifts, info), each with at least four nodes (%s)" % [kinds])
	var titled: Array = Out.ORDER.filter(func(id): return String(Out.NODES[id]["title"]) != "")
	t._check(titled.size() >= 3, "some nodes need a title (%s)" % [titled])
	t._check(Out.trunk_ids().size() == Renown.RANKS.size() and Out.all_ids().size() == Out.NODES.size() + Renown.RANKS.size(), "the trunk has a node for every rank")
	var ids: Array = Registry.SECTIONS.map(func(s): return String(s["id"]))
	var tables: Array = []
	for s in Registry.SECTIONS:
		tables.append_array(s.get("tables", []))
	t._check(ids.has("outfitter_words") and ids.has("outfitter_numbers") and tables.has("outfitter/NODES") and tables.has("outfitter/FX") and tables.has("outfitter/TEXT"),
		"the tree's words and numbers are in the Data editor")
	t._check(not ("UPGRADES" in Train) and not ("UPGRADE_FX" in Train) and not tables.has("train/UPGRADES"), "the old rank upgrades are gone: the tree is the one system")


# --- what opens a node ----------------------------------------------------------------------------

func _opening() -> void:
	var p = _at(0, 200.0)
	t._check(Out.ORDER.all(func(id): return Out.status(p, id) == "locked") and Out.status(p, "rank0") == "bought" and Out.status(p, "rank1") == "locked",
		"at the first rank every node is locked; the trunk shows the rank reached")
	t._check(Out.buy(p, "fair_price") != "" and not Out.owns(p, "fair_price"), "...and a locked node can't be bought")
	t._check(Out.locks(p, "fair_price").size() == 1 and String(Out.locks(p, "fair_price")[0]).contains(Renown.rank_name(1)), "its card says the rank it needs (%s)" % [Out.locks(p, "fair_price")])
	Renown.state(p)["points"] = Renown.needed(1)
	t._check(Out.status(p, "fair_price") == "open" and Out.status(p, "scroll_aside") == "locked", "the rank of %s opens each branch's first node" % Renown.rank_name(1))
	var poor = _at(1)
	t._check(Out.status(poor, "fair_price") == "open" and Out.why_not(poor, "fair_price").begins_with("needs") and Out.buy(poor, "fair_price") != "", "an open node needs its crystals")
	var had := int(p.crystals_held())
	t._check(Out.buy(p, "fair_price") == "" and Out.owns(p, "fair_price") and int(p.crystals_held()) == had - Out.cost("fair_price"), "bought with %d crystals of any kind, for good" % Out.cost("fair_price"))
	t._check(Out.buy(p, "fair_price") != "" and Out.bought_count(p) == 1, "...once")
	t._check(Out.status(p, "scroll_aside") == "locked" and Out.locks(p, "scroll_aside").any(func(l): return String(l).contains(Renown.rank_name(2))), "the next node waits for its rank")
	Renown.state(p)["points"] = Renown.needed(2)
	t._check(Out.status(p, "scroll_aside") == "open" and Out.status(p, "better_share") == "locked", "...then opens; the one after waits for it")
	# A node that needs a title: the title must be granted.
	var q = _at(Renown.OLD_RANKS[5], 500.0)
	_own(q, ["fair_price", "scroll_aside", "better_share", "regular"])
	t._check(Out.status(q, "old_friend") == "locked" and Out.locks(q, "old_friend").size() == 1 and String(Out.locks(q, "old_friend")[0]).contains(Renown.title_name("goldhand")),
		"a node that needs a title says which (%s)" % [Out.locks(q, "old_friend")])
	t._check(Titles.lines("goldhand").any(func(l): return String(l).to_lower().contains(Out.node_name("old_friend").to_lower())), "the title's card at the Noble names the node it opens (%s)" % [Titles.lines("goldhand")])
	Renown.state(q)["titles"] = ["goldhand"]
	t._check(Out.status(q, "old_friend") == "open" and Out.buy(q, "old_friend") == "", "...and opens once the Noble has granted it (wearing it isn't needed)")


# --- prices ------------------------------------------------------------------------------------------

func _prices() -> void:
	var p = _at(Renown.OLD_RANKS[6], 500.0)
	var g := Gear.make("plate", "fine", Gear.roll_traits("plate", "fine"))
	var full := Train.buy_price(p, g)
	var scroll := int(Train.supply_price(p, "scroll")[1])
	t._check(full == Train.gear_price(g) and scroll == int(Train.ANY_PRICE["scroll"]), "no node bought: his prices as they are")
	_own(p, ["fair_price"])
	t._check(Train.buy_price(p, g) == int(round(Train.gear_price(g) * 0.95)), "Fair prices: 5%% off (%d -> %d)" % [full, Train.buy_price(p, g)])
	_own(p, ["scroll_aside"])
	t._check(int(Train.supply_price(p, "scroll")[1]) == int(round(float(Out.FX["scroll_price"]) * 0.95)), "a scroll kept aside: 40 of any kind, less the discount (%d)" % int(Train.supply_price(p, "scroll")[1]))
	var sell_before := Train.gear_sell(g, p)
	_own(p, ["better_share"])
	t._check(Train.gear_sell(g, p) > sell_before and is_equal_approx(Out.sell_share(p), float(Out.FX["share"]["better_share"])), "a better share: he pays more when you sell (%d -> %d)" % [sell_before, Train.gear_sell(g, p)])
	p.pack = [g.duplicate(true)]
	var kind := Train.gear_kind(g)
	var before := float(p.crystal_total(kind))
	Train.sell(p, "pack", 0)
	t._check(int(p.crystal_total(kind) - before) == Train.gear_sell(g, p), "...and selling pays it")
	_own(p, ["regular"])
	t._check(is_equal_approx(Out.tree_discount(p), 0.1), "a regular's discount: 10%, in place of 5% (not both)")
	# With a worn title: they add up, to the cap at most.
	Renown.state(p)["titles"] = ["talked_of", "goldhand"]
	Renown.state(p)["worn"] = "talked_of"
	_own(p, ["old_friend"])
	var cap := float(Out.FX["discount_cap"])
	t._check(Train.discount(p) <= cap + 0.0001 and is_equal_approx(Train.discount(p), minf(cap, 0.15 + float(Titles.SOCIAL["talked_of"]["outfitter"]["discount"]))),
		"a worn title's discount adds to the tree's, %d%% at most (%.2f)" % [int(cap * 100.0), Train.discount(p)])
	t._check(is_equal_approx(Out.sell_share(p), float(Out.FX["share"]["old_friend"])), "an old friend's price: the best share counts")


# --- stock ---------------------------------------------------------------------------------------------

func _stock() -> void:
	var p = _at(Renown.OLD_RANKS[5], 500.0)
	var rack := Train.rack_size(p)
	var charms := Shop.charm_count(p)
	_own(p, ["wide_rack"])
	t._check(Train.rack_size(p) == rack + int(Out.FX["rack_extra"]), "a wider rack: two more pieces on the rail (%d -> %d)" % [rack, Train.rack_size(p)])
	_own(p, ["charm_tray"])
	t._check(Shop.charm_count(p) == charms + 1, "a charm tray: one more charm (%d -> %d)" % [charms, Shop.charm_count(p)])
	Train.stock(p)
	var tray: int = Train.outfit(p).filter(func(g): return Gear.is_gear(g) and Gear.slot_of(g) == "charm").size()
	t._check(tray == Shop.charm_count(p) and Array(p.store.get("kinds", [])).count("charm") == tray, "...and the tray holds them (%d), noted for the Charms section" % tray)
	t._check(Out.today_odds(p, Train.TODAY_ODDS) == Train.TODAY_ODDS, "without better stock, today's piece rolls as it did")
	_own(p, ["better_stock"])
	t._check(Out.today_odds(p, Train.TODAY_ODDS) == Out.STOCK_ODDS and Out.fine_floor(p) == int(Out.FX["rack_fine"]), "better stock: today's odds and Fine pieces on the rail")
	var low = _at(Renown.OLD_RANKS[5])
	var always := true
	var none_without := 0
	_own(p, ["rare_hook"])
	for i in 12:
		always = always and Train.roll_outfit(p).any(func(g): return Gear.rarity(g) == "rare" and Gear.slot_of(g) != "charm")
		none_without += 0 if Train.roll_outfit(_at(0)).any(func(g): return Gear.rarity(g) == "rare") else 1
	t._check(always and none_without == 12, "a Rare on the hook: a Rare piece hangs on every rail (and none at the first rank without it)")
	# The special order and the relic offered once.
	p.store = {}
	Train.stock(p)
	t._check(Train.hold(p, 0) == "?", "no special order without its node")
	_own(p, ["special_order"])
	var g0: Dictionary = Train.outfit(p)[0]
	t._check(Train.hold(p, 0) == "" and Gear.same(Train.order(p), g0), "the special order holds a piece for you")
	Renown.state(p)["points"] = Renown.needed(Renown.OLD_RANKS[6])
	Renown.state(p)["titles"] = ["beastfeller"]
	t._check(Out.unique(p).is_empty() and Out.buy(p, "relic_offer") == "", "a Beastfeller at the top rank buys a relic, offered once")
	var relic := Out.unique(p)
	t._check(not relic.is_empty() and Gear.rarity(relic) == "storied" and Gear.named_id(relic) != "", "...a Storied named piece waits in his case (%s)" % Gear.display(relic))
	p.add_crystal(Train.gear_kind(relic), float(Train.buy_price(p, relic)))
	p.chest = []
	t._check(Train.buy_gear(p, null, -3, "chest") == "" and p.chest.size() == 1 and Gear.same(p.chest[0], relic) and Out.unique(p).is_empty(), "...bought into the stash, it's gone from the case")
	Out._offer_relic(p)
	t._check(Out.unique(p).is_empty(), "...and never offered again")
	# Rank still opens weapons and the shelf (the trunk).
	t._check(Train.rack_size(_at(1)) > Train.rack_size(_at(0)) and Train.rack_size(_at(Renown.OLD_RANKS[6])) > Train.rack_size(_at(Renown.OLD_RANKS[3])), "the trunk: every rank adds rail spaces, free")


# --- gifts and word ---------------------------------------------------------------------------------------

func _gifts_and_word() -> void:
	var p = _at(Renown.OLD_RANKS[4], 300.0)
	p.last_tower = "kraken"
	p.climbs = 3
	var water := float(p.crystal_total("water"))
	p.store = {}
	Train.stock(p)
	t._check(Array(p.store.get("word", [])).is_empty() and float(p.crystal_total("water")) == water, "no gift nodes: no gifts")
	_own(p, ["staple_gift", "visit_gift"])
	p.store = {}
	Train.stock(p)
	t._check(float(p.crystal_total("water")) == water + float(Out.FX["visit_gift"]) and Array(p.store["word"]).any(func(w): return String(w).contains("Water")),
		"something for coming by: %d crystals of the tower you came from, and he says so" % int(Out.FX["visit_gift"]))
	Train.stock(p)
	t._check(float(p.crystal_total("water")) == water + float(Out.FX["visit_gift"]), "...once a visit")
	t._check(Out.belt_gifts(p) == ["draught"], "a vial for the road")
	_own(p, ["rank_gift"])
	Out.state(p)["gift_rank"] = Renown.rank(p)
	var stash: int = p.chest.size()
	p.store = {}
	Train.stock(p)
	t._check(p.chest.size() == stash, "a gift for each rank: nothing until you rise")
	Renown.state(p)["points"] = Renown.needed(Renown.OLD_RANKS[4] + 1)
	p.store = {}
	Train.stock(p)
	t._check(p.chest.size() == stash + 1 and Gear.rarity(p.chest[-1]) == "fine" and Array(p.store["word"]).any(func(w): return String(w).contains(Renown.rank_name(Renown.OLD_RANKS[4] + 1))),
		"...a Fine piece into your stash on a new rank, and he says for which")
	# Climbers' talk: a monster's weakness, into the Bestiary.
	var q = _at(Renown.OLD_RANKS[3], 300.0)
	q.last_tower = "kraken"
	q.climbs = 2
	_own(q, ["tower_tip", "best_buy", "weak_spot"])
	q.store = {}
	Train.stock(q)
	var told: Array = q.bestiary.keys().filter(func(k): return bool(q.bestiary[k].get("told", false)))
	t._check(told.size() == 1 and Array(q.store["word"]).any(func(w): return String(w).contains("Bestiary") and String(w).to_lower().contains(String(load("res://scripts/enemy.gd").WEAKNESS[String(told[0])]).to_lower() if not told.is_empty() else "?")),"climbers' talk: a monster's weakness each visit, in your Bestiary (%s)" % [told])
	t._check(Out.tower_line("kraken", Train.shelf(q)).contains(String(Towers.TOWERS["kraken"]["name"])), "word on the tower names it and what to pack (%s)" % Out.tower_line("kraken", Train.shelf(q)))
	t._check(Out.hint_line("the Locket", Vector2.ZERO, Vector2(100, -100)).contains("north-east") and Out.hint_line("x", Vector2.ZERO, Vector2(-50, 0)).contains("west"), "where it lies: the way from where you start")


# --- old saves -------------------------------------------------------------------------------------------

func _old_saves() -> void:
	for case in [[5, ["wide_rack", "scroll_aside", "better_stock", "regular", "special_order"]], [2, ["wide_rack", "scroll_aside"]], [0, []]]:
		var path := TestRun.path("user://outfitter_old.cfg")
		var cfg := ConfigFile.new()
		cfg.set_value("profile", "regarded", true)
		cfg.set_value("renown", "state", {"points": Renown.needed(Renown.OLD_RANKS[int(case[0])]), "order": ""})
		cfg.set_value("train", "store", {"outfit": ["", ""], "today": ""})
		cfg.save(path)
		var p = ProfileScript.new()
		p.saving = false
		p.save_path = path
		p.load_save()
		var got: Array = Out.state(p)["bought"].duplicate()
		got.sort()
		var want: Array = case[1].duplicate()
		want.sort()
		t._check(got == want, "an old save at the rank of %s keeps its upgrades as nodes of the tree (%s)" % [Renown.rank_name(Renown.OLD_RANKS[int(case[0])]), got])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p2 = _at(Renown.OLD_RANKS[5], 100.0)
	t._check(Train.upgraded(p2, "order") == false and Train.rack_size(p2) == Train.RACK_SIZE + Shop.rail_extra(p2), "a new climber at the same rank has bought nothing yet")
	_own(p2, ["special_order"])
	t._check(Train.upgraded(p2, "order"), "an old upgrade's id still names its node")
	# A save made now keeps its tree, and isn't given the old upgrades again.
	var path2 := TestRun.path("user://outfitter_new.cfg")
	p2.saving = true
	p2.save_path = path2
	p2.save()
	var p3 = ProfileScript.new()
	p3.saving = false
	p3.save_path = path2
	p3.load_save()
	t._check(Out.state(p3)["bought"] == ["special_order"], "a save made now loads with what it bought, nothing more (%s)" % [Out.state(p3)["bought"]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path2))


# --- words -------------------------------------------------------------------------------------------------

func _words() -> void:
	t._check(Entity.TIPS.has("shop_tree") and Talk.DIALOGUE.has("how_shop_tree") and Talk.DIALOGUE["how_shop"]["choices"].has("how_shop_tree"),
		"the Entity: a first word on the tree, and \"How does his upgrade tree work?\" under \"How does the shop change?\"")
	for k in ["store_tab:tree", "store_tab:shop", "slot:tree", "tree_buy", "slot:unique"]:
		t._check(Help.HELP.has(k), "the Entity explains %s" % k)
	t._check(not Help.HELP.keys().any(func(k): return String(k).begins_with("store_filter")) and not Help.HELP.has("slot:upgrades"), "no help left for the filter, the pages or the old Upgrades sign")
	var all := JSON.stringify([Out.NODES, Out.BRANCHES, Out.TEXT, Entity.TIPS["shop_tree"], Entity.TIPS["store"], Talk.DIALOGUE["how_shop"], Talk.DIALOGUE["how_shop_tree"], Train.TEXT]).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")s?\\b")
	t._check(re.search(all) == null, "no banned words in the store's and the tree's words (%s)" % (re.search(all).get_string() if re.search(all) != null else ""))


# --- on screen ---------------------------------------------------------------------------------------------

func _open_store(main, view := "shop", sel := "") -> void:
	var menu = main.menu
	menu.train_car = "store"
	menu.train_store = view
	menu.inv_sel = sel
	menu.train_sel["store"] = sel
	menu.open("train")
	await t._frames(3)
	menu.train_page.go_to(menu.train_page._index("store"))
	await t._train_settled()
	await t._frames(2)


func _furniture(menu) -> Array:
	return menu.train_page.roots["store"].find_children("*", "PanelContainer", true, false).filter(func(f): return f.get("kind") != null).map(func(f): return String(f.kind))


## At 1280 x 720: the four sections, everything at once, no filter or page;
## at the top rank too; the tree beside them.
func _one_page(main) -> void:
	var menu = main.menu
	var prof = main.profile
	var folded: bool = not bool(menu.settings["store_upgrades"])
	menu.settings["store_upgrades"] = true  # (the tree open under Joel: outfitter_joel.gd tests it folded)
	main.open_train()
	await t._frames(2)
	for rank in [0, Renown.RANKS.size() - 1]:
		prof.renown = {}
		Renown.state(prof)["points"] = Renown.needed(rank)
		prof.pack = [Gear.make("axe")]
		prof.chest = [Gear.make("leather_cap"), Gear.make("chain")]
		prof.store = {}
		Train.stock(prof)
		await _open_store(main)
		var root = menu.train_page.roots["store"]
		var kinds: Array = _furniture(menu)
		var heads: Array = t._all_labels(root).map(func(l): return String(l.text).to_lower())
		t._check(["shelf", "rail", "case", "tray", "plain", "ledger"].all(func(k): return kinds.has(k)) and [Train.TEXT["consumables"], Train.TEXT["weapons"], Train.TEXT["charms"], Train.TEXT["sell"]].all(func(h): return heads.has(String(h).to_lower())),
			"rank %d: the four sections (Consumables, Weapons & armour, Charms, Sell) and the tree, on one page (%s)" % [rank, kinds])
		var slots: Array = t._all_buttons(root).map(func(b): return String(b.get_meta("slot", "")))
		var rail_n := Train.outfit(prof).size()
		var all_rail: bool = range(rail_n).all(func(i): return slots.has("outfit:%d" % i))
		var all_shelf: bool = Train.shelf(prof).all(func(id): return slots.has("supply:" + String(id)))
		t._check(all_rail and all_shelf and slots.has("today") and slots.has("pack:0") and slots.has("chest:0") and slots.has("chest:1"),
			"rank %d: every rail piece (%d), every supply (%d), today's piece and every piece to sell show at once" % [rank, rail_n, Train.shelf(prof).size()])
		t._check(t._all_buttons(root).filter(func(b): return b.has_meta("store_filter")).is_empty(), "rank %d: no filter and no page buttons" % rank)
		var tree_n: int = slots.filter(func(s): return s.begins_with("tree:")).size()
		t._check(menu.train_page.store.tree_beside and tree_n == Out.all_ids().size(), "rank %d: the upgrade tree stands beside the goods on a computer (%d nodes)" % [rank, tree_n])
		if rank > 0:
			t._check(menu.train_page.store.listed and menu.train_page.store.goods_scroll != null, "the top rank's big stock is a list that scrolls")
	# A tight room: the list kicks in when the grids won't fit.
	prof.renown = {}
	prof.pack = []
	prof.chest = []
	prof.store = {}
	Train.stock(prof)
	await _open_store(main)
	var lean_listed: bool = menu.train_page.store.listed
	t._check(not lean_listed or menu.train_page.store._grid_height(prof, Train.shelf(prof).size(), 8, 1, 5, 330.0) > 0.0, "a lean stock on a computer: grids where they fit (listed: %s)" % lean_listed)
	if folded:
		menu.settings["store_upgrades"] = false


## The tree on screen: each node marked bought, open or locked; its card
## says what it does and what opens it; Buy buys it.
func _tree_ui(main) -> void:
	var menu = main.menu
	var prof = main.profile
	prof.renown = {}
	Renown.state(prof)["points"] = Renown.needed(2)
	for k in Essence.KINDS:
		prof.add_crystal(k, 100.0)
	Out.state(prof)["bought"] = ["wide_rack"]
	prof.store = {}
	Train.stock(prof)
	await _open_store(main, "shop", "tree:charm_tray")
	var tv = menu.train_page.store.tree_view
	t._check(tv != null and tv.buttons["wide_rack"].state == "bought" and tv.buttons["charm_tray"].state == "open" and tv.buttons["better_stock"].state == "locked" and tv.buttons["rank2"].state == "bought" and tv.buttons["rank3"].state == "locked",
		"the tree marks a node bought, open or locked")
	var up: Control = tv.buttons["charm_tray"].find_valid_focus_neighbor(SIDE_TOP) if tv != null else null
	var across: Control = tv.buttons["charm_tray"].find_valid_focus_neighbor(SIDE_RIGHT) if tv != null else null
	t._check(up != null and String(up.get_meta("slot", "")).begins_with("tree:") and up.position.y < tv.buttons["charm_tray"].position.y and across != null and String(across.get_meta("slot", "")).begins_with("tree:"), "the keys and a controller step from node to node (up: %s)" % (up.get_meta("slot", "") if up != null else "none"))
	var labels: Array = t._all_labels(menu.details).map(func(l): return l.text)
	t._check(labels.has(Out.node_desc("charm_tray")) and labels.any(func(s): return s.contains(Renown.rank_name(2))) and labels.any(func(s): return s.contains(Out.node_name("wide_rack"))),
		"its card says what it does and what opens it (%s)" % [labels])
	var buy: Array = t._car_buttons("tree_buy", "charm_tray")
	t._check(buy.size() == 1 and not buy[0].disabled and not Help.missing(buy[0]), "...with Buy, which the Entity explains")
	var had := int(prof.crystals_held())
	if buy.size() == 1:
		buy[0].pressed.emit()
		await t._frames(3)
	t._check(Out.owns(prof, "charm_tray") and int(prof.crystals_held()) == had - Out.cost("charm_tray") and menu.train_say == Out.line("charm_tray"), "Buy buys it, and he says his line (%s)" % menu.train_say)
	await _open_store(main, "shop", "tree:old_friend")
	labels = t._all_labels(menu.details).map(func(l): return l.text)
	t._check(labels.any(func(s): return s.contains(Renown.title_name("goldhand"))) and t._car_buttons("tree_buy", "old_friend").size() == 1 and t._car_buttons("tree_buy", "old_friend")[0].disabled,
		"a locked node's card names the title it needs, and its Buy is off")
	var nodes: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get_meta("slot", "")).begins_with("tree:"))
	t._check(not nodes.is_empty() and nodes.all(func(b): return not Help.missing(b) and Help.explain(menu, b).length() > 20), "the Entity explains every node (%s)" % (Help.explain(menu, nodes[0]) if not nodes.is_empty() else ""))
	# Info on the page: word on the tower and his pick.
	Out.state(prof)["bought"] = ["tower_tip", "best_buy"]
	prof.store = {}
	Train.stock(prof)
	await _open_store(main)
	var notes: Array = menu.train_page.roots["store"].find_children("*", "Label", true, false).filter(func(l): return l.has_meta("store_note")).map(func(l): return String(l.get_meta("store_note")))
	var tagged: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get("tag")) != "" if b.get("tag") != null else false).map(func(b): return String(b.tag))
	var pick := false
	for i in Train.outfit(prof).size():
		pick = pick or Train.versus(prof, main.player, Train.outfit(prof)[i]) > 0
	t._check(notes.has("tower") and (not pick or (notes.has("best") and tagged.has(Out.TEXT["best_tag"]))), "word on the tower and his pick for you show on the page (%s; %s)" % [notes, tagged])
	Out.state(prof)["bought"] = []


## A phone: the list, every row tapped and bought, the tree in its own view.
func _phone(main) -> void:
	var menu = main.menu
	var prof = main.profile
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	prof.renown = {}
	Renown.state(prof)["points"] = Renown.needed(Renown.RANKS.size() - 1)
	prof.store = {}
	Train.stock(prof)
	await _open_store(main)
	var sp = menu.train_page.store
	t._check(sp.listed and not sp.tree_beside, "on a phone the goods are a list, and the tree is its own view")
	var small_btns: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return b.is_visible_in_tree() and b.size.y < 36.0)
	t._check(small_btns.is_empty(), "...every row and button in the store big enough for a finger (%s)" % [small_btns.map(func(b): return String(b.get_meta("slot", b.text)))])
	var sign: Array = t._car_buttons("store_tab", "tree")
	var view: Rect2 = menu.get_viewport_rect()
	t._check(sign.size() == 1 and view.encloses(sign[0].get_global_rect()), "...behind the Upgrade tree sign, on the screen")
	if sign.size() == 1:
		await t._tap_at(sign[0].get_global_rect().get_center())
		await t._frames(3)
	var nodes: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get_meta("slot", "")).begins_with("tree:") and b.is_visible_in_tree())
	t._check(menu.train_store == "tree" and nodes.size() == Out.all_ids().size(), "a tap shows the tree (%d nodes)" % nodes.size())
	t._check(nodes.all(func(b): return b.size.y >= 36.0 and b.size.x >= 36.0), "...every node big enough for a finger (36 or more)")
	var node = nodes.filter(func(b): return b.get_meta("slot") == "tree:relic_offer")
	if not node.is_empty():
		await t._tap_at(node[0].get_global_transform_with_canvas() * (node[0].size / 2.0))
		await t._frames(3)
	t._check(menu.inv_sel == "tree:relic_offer", "a tap on a node shows its card (one near your rank, where the tree opens)")
	var back: Array = t._car_buttons("store_tab", "shop")
	if back.size() == 1:
		await t._tap_at(back[0].get_global_rect().get_center())
		await t._frames(3)
	t._check(menu.train_store == "shop" and t._car_buttons("store_tab", "tree").size() == 1, "and Goods comes back")
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.train_store = "shop"
	await t._frames(2)


## Where it lies: on a contract's floor, he has said which way the thing lies.
func _contract_hint(main) -> void:
	var C = load("res://scripts/contracts.gd")
	var prof = main.profile
	main.menu.close()
	main.await_tower()
	main.on_train = false
	t.paused = false
	await t._frames(2)
	Out.state(prof)["bought"] = ["contract_hint"]
	var o: Dictionary = C.roll(prof, "retrieve")
	o["tower"] = main.tower
	o["floor"] = 3
	C.data(prof)["active"] = [o]
	main._start_floor(3)
	await t._frames(2)
	for e in main.enemies():
		e.queue_free()
	t._check(not main.contracts.item.is_empty() and main.contracts.hint.contains(String(o["item"])) and Out.TEXT["compass"].any(func(d): return main.contracts.hint.contains(String(d))),
		"where it lies: on its floor he has said which way it lies (%s)" % main.contracts.hint)
	C.data(prof)["active"] = []
	Out.state(prof)["bought"] = []
	main.contracts.on_floor(1)
	main.open_train()
	await t._frames(2)
