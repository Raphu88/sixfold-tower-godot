extends RefCounted
## Joel, the outfitter (outfitter_name.gd), and his upgrade tree folded
## or open in the Outfitter's Car (store_page.gd): his name is in one place
## and fills every line that names him; on a wide window the tree starts
## folded to its Upgrades sign, so it doesn't fill the car, and Joel is
## drawn big in the room it leaves; the sign opens and folds it (the keys,
## a controller and a finger reach it, the Entity explains it) and the
## choice is saved with the settings; buying still works folded; the page
## still fits a phone; no banned words. Run by smoke_test.gd (_part_tests).

const Train := preload("res://scripts/train.gd")
const Out := preload("res://scripts/outfitter.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Travel := preload("res://scripts/travel.gd")
const Titles := preload("res://scripts/titles.gd")
const Items := preload("res://scripts/items.gd")
const Vessel := preload("res://scripts/vessel.gd")
const EssenceFlow := preload("res://scripts/essence_flow.gd")
const Offhand := preload("res://scripts/offhand.gd")
const TrainView := preload("res://scripts/train_view.gd")
const TestRun := preload("res://scripts/test_run.gd")
const Menu := preload("res://scripts/menu.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("Joel, the outfitter: his name, and his upgrade tree folded or open")
	_words()
	_saved()
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	var was: Vector2i = t.root.size
	var had: bool = bool(Menu.settings["store_upgrades"])
	await _wide(main)
	await _phone(main)
	Menu.settings["store_upgrades"] = had
	main.touch._set_active(false)
	t.root.size = was
	main.apply_view_scale()
	if is_instance_valid(main.menu):
		main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


# --- his name, in one place ----------------------------------------------------------------------

func _words() -> void:
	var n: String = OutfitterName.NAME
	t._check(n == "Joel", "the outfitter is named Joel, in one place (outfitter_name.gd)")
	var tables := [Entity.TIPS, Help.HELP, Help.COMMENTS, Talk.DIALOGUE, Talk.HINTS, Talk.TEXT, Train.TEXT, Train.OUTFITTER, Out.TEXT,
		Travel.TOURS, Titles.TEXT, Titles.GROUPS, Items.CRYSTAL, Vessel.TEXT, EssenceFlow.TEXT, Offhand.TEXT]
	var all := JSON.stringify(tables)
	t._check(not all.contains(OutfitterName.KEY), "no line is left with {outfitter} unfilled")
	t._check(String(Train.OUTFITTER["tag"]).contains(n) and String(Train.OUTFITTER["name"]) == n, "his tag over his words names him (%s)" % Train.OUTFITTER["tag"])
	t._check(String(Entity.TIPS["store"]["tip"]).contains(n) and String(Entity.TIPS["shop_tree"]["name"]).contains(n) and String(Help.HELP["store_tab:tree"]).contains(n),
		"the Entity names him in its tip, its topic and its hover help")
	t._check(String(Entity.TIPS["store"]["more"]).contains(Train.TEXT["upgrades_fold"]) and String(Entity.TIPS["shop_tree"]["more"]).contains(Train.TEXT["upgrades_fold"]) and String(Talk.DIALOGUE["how_shop_tree"]["lines"][0]).contains(Train.TEXT["upgrades_fold"]),
		"the Entity's store topic, the tree's topic and \"How does his upgrade tree work?\" tell of the Upgrades sign")
	t._check(Help.HELP.has("store_upgrades:open") and Help.HELP.has("store_upgrades:close") and String(Help.HELP["store_upgrades:open"]).contains(n),
		"the Entity explains the Upgrades sign, folded and open")
	t._check(not all.to_lower().contains("the outfitter's upgrades"), "no line calls him only \"the outfitter\" where it names him")
	var low := JSON.stringify([Entity.TIPS["store"], Entity.TIPS["shop_tree"], Talk.DIALOGUE["how_shop_tree"], Help.HELP["store_upgrades:open"], Help.HELP["store_upgrades:close"],
		Train.OUTFITTER, Train.TEXT["upgrades_fold"], Train.TEXT["upgrades_count"], n]).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")s?\\b")
	t._check(re.search(low) == null, "no banned words in Joel's words or the fold's")


## The choice is saved with the settings, and an odd value loads folded.
func _saved() -> void:
	var had: bool = bool(Menu.settings["store_upgrades"])
	t._check(Menu.settings.has("store_upgrades"), "the settings keep the Upgrades sign's choice (folded by default: %s)" % [not had])
	var path := TestRun.path("user://joel_settings.cfg")
	Menu.settings["store_upgrades"] = true
	Menu.save_settings_to(path)
	Menu.settings["store_upgrades"] = false
	Menu.load_settings_from(path)
	t._check(Menu.settings["store_upgrades"] == true, "opened, the tree stays open after a restart (saved with the settings)")
	var odd := ConfigFile.new()
	odd.set_value("settings", "store_upgrades", "yes please")
	odd.save(path)
	Menu.load_settings_from(path)
	t._check(Menu.settings["store_upgrades"] == false, "...and anything odd in the file loads folded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Menu.settings["store_upgrades"] = had


# --- on screen -----------------------------------------------------------------------------------

func _open_store(main, sel := "") -> void:
	var menu = main.menu
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = sel
	menu.train_sel["store"] = sel
	menu.open("train")
	await t._frames(3)
	menu.train_page.go_to(menu.train_page._index("store"))
	await t._train_settled()
	await t._frames(3)


func _tree_nodes(menu) -> Array:
	return t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get_meta("slot", "")).begins_with("tree:") and b.is_visible_in_tree())


## A wide computer window (1920 x 1080): folded by default, Joel big; the
## sign opens and folds the tree; buying works folded.
func _wide(main) -> void:
	var menu = main.menu
	var prof = main.profile
	t.root.size = Vector2i(1920, 1080)
	main.apply_view_scale()
	main.open_train()
	await t._frames(2)
	for k in ["air", "water", "iron", "fire", "stone", "blade"]:
		prof.add_crystal(k, 100.0)
	prof.store = {}
	Train.stock(prof)
	Menu.settings["store_upgrades"] = false
	await _open_store(main)
	var sp = menu.train_page.store
	var room: Control = menu.train_view.rooms["store"]
	var area: Rect2 = room.get_global_rect()
	t._check(sp.tree_beside and not sp.upgrades_open and sp.tree_view == null and _tree_nodes(menu).is_empty(), "a wide window: the tree starts folded beside the goods (no nodes showing)")
	var sign: Button = sp.fold_sign
	var ok_sign: bool = sign != null and is_instance_valid(sign) and sign.is_visible_in_tree()
	t._check(ok_sign and String(sign.get_meta("store_upgrades", "")) == "open" and sign.text.contains(Train.TEXT["upgrades_fold"]), "...folded to its Upgrades sign (%s)" % (sign.text if ok_sign else "none"))
	if not ok_sign:
		return
	t._check(sign.get_global_rect().size.y <= 70.0 and sign.get_global_rect().size.y < area.size.y * 0.2, "...which is only a header, not the car's height (%s of %s)" % [sign.get_global_rect().size.y, area.size.y])
	t._check(sign.focus_mode == Control.FOCUS_ALL and sign.size.y >= 36.0 and menu.get_viewport_rect().encloses(sign.get_global_rect()), "...on the screen, big enough for a finger, and the keys and a controller reach it")
	t._check(not Help.missing(sign) and Help.explain(menu, sign).contains(OutfitterName.NAME), "...and the Entity explains it (%s)" % Help.explain(menu, sign))
	var joel_big = sp.joel
	t._check(joel_big != null and is_instance_valid(joel_big) and joel_big.get_script() == TrainView.Outfitter and joel_big.get_global_rect().size.y > area.size.y * 0.3,
		"folded, Joel is drawn big in the room it leaves (%s)" % (joel_big.get_global_rect() if joel_big != null and is_instance_valid(joel_big) else "none"))
	var r_folded: float = joel_big.head_radius() if joel_big != null and is_instance_valid(joel_big) else 0.0
	var names: Array = t._all_labels(menu.train_page.roots["store"]).map(func(l): return String(l.text))
	t._check(names.any(func(s): return s.contains(OutfitterName.NAME)), "the car names him: Joel")
	var goods: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get_meta("slot", "")).begins_with("supply:"))
	t._check(goods.size() == Train.shelf(prof).size(), "folded, the goods are all still there (%d supplies)" % goods.size())
	# Open it.
	sign.pressed.emit()
	await t._frames(4)
	sp = menu.train_page.store
	t._check(Menu.settings["store_upgrades"] == true and sp.upgrades_open and _tree_nodes(menu).size() == Out.all_ids().size(), "pressed, the sign opens the tree under him, and the choice is kept (%d nodes)" % _tree_nodes(menu).size())
	var sign2: Button = sp.fold_sign
	t._check(sign2 != null and is_instance_valid(sign2) and String(sign2.get_meta("store_upgrades", "")) == "close" and not Help.missing(sign2), "...its sign now folds it, and the Entity explains that")
	var joel_small = sp.joel
	var r_open: float = joel_small.head_radius() if joel_small != null and is_instance_valid(joel_small) else 0.0
	t._check(r_folded > r_open * 2.0 and r_open > 0.0, "Joel is drawn much bigger folded than open (head %.0f against %.0f)" % [r_folded, r_open])
	# Fold it again, with a click where it is.
	if sign2 != null and is_instance_valid(sign2):
		sign2.pressed.emit()
		await t._frames(4)
	sp = menu.train_page.store
	t._check(Menu.settings["store_upgrades"] == false and not sp.upgrades_open and _tree_nodes(menu).is_empty(), "pressed again, it folds, and that's kept too")
	# A node's card asked for shows the tree; folding puts the goods' card back.
	await _open_store(main, "tree:fair_price")
	sp = menu.train_page.store
	t._check(sp.upgrades_open and menu.inv_sel == "tree:fair_price", "a node's card asked for opens the tree to show it")
	if sp.fold_sign != null and is_instance_valid(sp.fold_sign):
		sp.fold_sign.pressed.emit()
		await t._frames(4)
	t._check(not menu.train_page.store.upgrades_open and not String(menu.inv_sel).begins_with("tree:"), "...and folding it shows the goods' card instead (%s)" % menu.inv_sel)
	# Buying, folded.
	var id := String(Train.shelf(prof)[0])
	prof.supplies.erase(id)
	await _open_store(main, "supply:" + id)
	var buy: Array = t._car_buttons("buy", id)
	if buy.size() == 1 and not buy[0].disabled:
		buy[0].pressed.emit()
		await t._frames(3)
	t._check(int(prof.supplies.get(id, 0)) == 1 and not menu.train_page.store.upgrades_open, "folded, buying still works (%s: %d packed; %d Buy buttons)" % [Items.item_name(id), int(prof.supplies.get(id, 0)), buy.size()])


## A phone (800 x 400): the store still fits, Joel too, the tree behind its sign.
func _phone(main) -> void:
	var menu = main.menu
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	main.apply_view_scale()
	await _open_store(main)
	var sp = menu.train_page.store
	var view: Rect2 = menu.get_viewport_rect()
	var root = menu.train_page.roots["store"]
	var sign: Array = t._car_buttons("store_tab", "tree")
	t._check(not sp.tree_beside and sign.size() == 1 and view.encloses(sign[0].get_global_rect()), "on a phone the tree is behind its sign, on the screen")
	var said: Array = root.find_children("*", "HBoxContainer", true, false).filter(func(r): return r.has_meta("outfitter_line"))
	t._check(said.size() == 1 and view.encloses(said[0].get_global_rect()) and t._all_labels(said[0]).any(func(l): return String(l.text).contains(OutfitterName.NAME)), "...and his words, naming him, are on it too")
	var joel = sp.joel
	var fits: bool = joel == null or not is_instance_valid(joel) or view.grow(1.0).encloses(joel.get_global_rect())
	t._check(fits, "...and Joel fits on it (%s)" % (joel.get_global_rect() if joel != null and is_instance_valid(joel) else "not drawn"))
	if not sign.is_empty():
		await t._tap_at(sign[0].get_global_rect().get_center())
		await t._frames(3)
	t._check(menu.train_store == "tree" and _tree_nodes(menu).size() == Out.all_ids().size(), "a tap on it shows the tree")
	menu.train_store = "shop"
	main.touch._set_active(false)
