extends RefCounted
## Your car's Loadout and stash, and the store's buying and selling with
## them (train.gd, loadout_page.gd, stash_page.gd, train_page.gd), and worn
## gear drawn on the climber (gear_look.gd): equipping from the pack and the
## stash, taking off, moving between them, sorting and filtering, the stash's
## room, old saves, buying into the pack or stash (or wearing it at once),
## selling from either, comparing with what you wear, what goes on as you
## depart, and the drawing for every slot and weapon. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")
const GearLook := preload("res://scripts/gear_look.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Weapons := preload("res://scripts/weapons.gd")
const D := preload("res://scripts/draw_util.gd")
const TestRun := preload("res://scripts/test_run.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _setup()
	_saves()
	_equip_rules()
	_rings_and_packs()
	_departing()
	_sorting()
	_store_rules()
	_compare()
	_drawing()
	await _screens()
	await _store_screen()
	await _fits()
	var menu = _main().menu
	menu.close()
	t.paused = false
	_main().on_train = false


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A slot on the page (not in the car behind it) with this key, or null.
func _box_slot(key: String):
	for b in _main().menu.box.find_children("*", "Button", true, false):
		if b.get_meta("slot", "") == key and b.is_visible_in_tree():
			return b
	return null


func _setup() -> void:
	print("the Loadout and stash")
	await t._fresh_main()
	var m = _main()
	m.touch._set_active(false)
	m.pad._set_active(false)
	m.grant_test_bonds()
	m.profile.regarded = true
	m.first_climb = false
	_reset()


## A climber on the train with nothing chosen, an empty pack and stash.
func _reset() -> void:
	var prof = _main().profile
	prof.pack = []
	prof.chest = []
	prof.wear = {}
	prof.heirlooms = {}
	prof.vessels = []
	prof.crystals = []
	Train.dress(prof, _main().player)


func _saves() -> void:
	var prof = _main().profile
	_check(Train.CHEST_SIZE >= 40, "the stash holds %d pieces (it held 8)" % Train.CHEST_SIZE)
	var path := TestRun.path("user://loadout_test.cfg")
	# An old save: a chest of 8, no Loadout.
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	var eight: Array = []
	for i in 8:
		eight.append(G.code(G.make("leather_cap")))
	old.set_value("train", "chest", eight)
	old.set_value("train", "pack", [G.code(G.make("axe"))])
	old.save(path)
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.chest.size() == 8 and again.pack.size() == 1 and again.wear.is_empty(), "an old save loads unchanged: its 8 stash pieces, its pack, nothing chosen to wear")
	# A Loadout saves and loads; a ring in a slot it can't go in is dropped.
	again.wear = {"armor": G.make("plate"), "ring2": G.make("garnet_ring", "fine")}
	again.saving = true
	again.save()
	var cfg := ConfigFile.new()
	cfg.load(path)
	var w: Dictionary = cfg.get_value("train", "wear", {})
	w["helm"] = G.make("garnet_ring", "fine")
	cfg.set_value("train", "wear", w)
	cfg.save(path)
	var back = load("res://scripts/profile.gd").new()
	back.save_path = path
	back.load_save()
	_check(back.wear.size() == 2 and G.base_id(back.wear["armor"]) == "plate" and G.base_id(back.wear["ring2"]) == "garnet_ring", "what you chose to wear is saved and loads again (a misplaced piece is dropped): %s" % [back.wear.keys()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH


func _equip_rules() -> void:
	print("the Loadout: wearing from the pack and the stash")
	var m = _main()
	var prof = m.profile
	var p = m.player
	_reset()
	prof.pack = [G.make("leather"), G.make("axe")]
	prof.chest = [G.make("plate"), G.make("iron_helm", "fine", ["vigor"])]
	_check(Train.equip(prof, p, "pack", 0) == "" and G.base_id(prof.wear.get("armor", {})) == "leather" and prof.pack.size() == 1, "a pack piece is chosen to wear: it leaves the pack")
	_check(p.gear_id("armor") == "leather" and p.protection() > 0.1, "...and the climber on the train wears it (their numbers too)")
	_check(Train.equip(prof, p, "chest", 0) == "" and G.base_id(prof.wear["armor"]) == "plate" and prof.chest.size() == 2 and G.base_id(prof.chest[0]) == "leather",
		"wearing a stash piece in the same slot sends the old one back to the stash, where it came from")
	_check(Train.unequip(prof, p, "armor", "pack") == "" and not prof.wear.has("armor") and G.base_id(prof.pack.back()) == "plate" and p.gear_id("armor") == "", "taking it off into the pack")
	_check(Train.equip(prof, p, "pack", prof.pack.size() - 1) == "" and Train.unequip(prof, p, "armor", "chest") == "" and G.base_id(prof.chest.back()) == "plate", "...or into the stash")
	# An heirloom: wearing over it leaves it yours, waiting on the train.
	prof.heirlooms["melee"] = G.make("spear", "fine", ["edges"])
	Train.dress(prof, p)
	_check(p.gear_id("melee") == "spear" and Train.setoff(prof)["melee"]["from"] == "heir", "your heirloom is worn in its slot")
	var axe_i: int = prof.pack.find(prof.pack.filter(func(g): return G.base_id(g) == "axe")[0])
	_check(Train.equip(prof, p, "pack", axe_i) == "" and p.gear_id("melee") == "axe" and G.base_id(prof.heirlooms["melee"]) == "spear", "wearing an axe over it: the heirloom stays yours")
	_check(not prof.pack.any(func(g): return G.base_id(g) == "spear") and not prof.chest.any(func(g): return G.base_id(g) == "spear"), "...it isn't copied into the pack or stash")
	_check(Train.unequip(prof, p, "melee", "pack") == "" and p.gear_id("melee") == "spear", "taking the axe off puts the heirloom back on")
	# Moving between pack and stash; the stash's room.
	_reset()
	prof.pack = [G.make("dagger")]
	_check(Train.move(prof, p, "pack", 0) == "" and prof.chest.size() == 1 and prof.pack.is_empty(), "a piece moves from the pack to the stash")
	_check(Train.move(prof, p, "chest", 0) == "" and prof.pack.size() == 1, "...and back")
	for i in Train.CHEST_SIZE:
		prof.chest.append(G.make("leather_cap"))
	_check(Train.move(prof, p, "pack", 0) == Train.TEXT["chest_full"] and prof.pack.size() == 1, "a full stash takes no more")
	prof.wear = {"helm": G.make("iron_helm")}
	prof.pack = [G.make("axe"), G.make("axe"), G.make("axe"), G.make("axe")]
	_check(Train.unequip(prof, p, "helm") == Train.TEXT["no_room"] and prof.wear.has("helm"), "with the pack and stash both full, nothing can be taken off")
	_reset()


func _rings_and_packs() -> void:
	var m = _main()
	var prof = m.profile
	var p = m.player
	_reset()
	prof.chest = [G.make("garnet_ring", "fine"), G.make("jade_ring", "fine"), G.make("silver_ring", "fine")]
	Train.equip(prof, p, "chest", 0)
	Train.equip(prof, p, "chest", 0)
	_check(prof.wear.has("ring1") and prof.wear.has("ring2") and prof.chest.size() == 1, "two rings go on both hands")
	_check(Train.equip(prof, p, "chest", 0, "ring2") == "" and G.base_id(prof.wear["ring2"]) == "silver_ring" and G.base_id(prof.chest[0]) == "jade_ring", "a third ring in place of the second: the second goes back")
	# A Climber's Pack holds 2 more; with them full it can't come off.
	_reset()
	prof.chest = [G.make("climbers_pack"), G.make("satchel")]
	_check(Train.equip(prof, p, "chest", 0) == "" and p.pack_size() == 6 and Train.pack_room(prof, p) == 6, "wearing a Climber's Pack: the pack holds 6")
	for i in 6:
		prof.pack.append(G.make("dagger"))
	_check(Train.unequip(prof, p, "backpack", "chest") == Train.TEXT["pack_shrinks"] and prof.wear.has("backpack"), "...and with 6 in it, it can't come off (the pack would hold too little)")
	_check(Train.equip(prof, p, "chest", 0) == Train.TEXT["pack_shrinks"] and G.base_id(prof.wear["backpack"]) == "climbers_pack", "...nor be swapped for a satchel")
	prof.pack.resize(4)
	_check(Train.equip(prof, p, "chest", 0) == "" and G.base_id(prof.wear["backpack"]) == "satchel" and p.pack_size() == 4, "with 4 in it, the satchel can go on")
	_reset()


func _departing() -> void:
	print("the Loadout: what goes on as you depart")
	var m = _main()
	var prof = m.profile
	var p = m.player
	_reset()
	prof.heirlooms["chest"] = G.make("padded")
	prof.wear = {"armor": G.make("chain", "fine", ["breath"]), "melee": G.make("sword")}
	prof.pack = [G.make("leather_cap"), G.make("sword", "fine", ["edges"]), G.make("axe")]
	var so := Train.setoff(prof)
	_check(so["armor"]["from"] == "wear" and so["helm"]["from"] == "pack" and so["melee"]["from"] == "wear" and so["ranged"]["from"] == "start",
		"the Loadout says what you'll set off in: what you chose, a pack piece for an empty slot, the starting bow")
	m.player.items = m.Items.START.duplicate()
	Train.pack_up(prof, p)
	_check(p.gear_id("armor") == "chain" and G.rarity(p.gear["armor"]) == "fine", "departing: the chosen chain mail goes on over the heirloom padding")
	_check(p.gear_id("melee") == "sword" and G.rarity(p.gear["melee"]) == "common" and p.gear_id("helm") == "leather_cap", "...the chosen sword stays in hand (a pack sword doesn't take its place); the cap fills the empty helm")
	_check(p.pack.size() == 2 and prof.wear.is_empty() and prof.pack.is_empty(), "...the rest go up in the pack, and the Loadout is cleared")
	_check(G.base_id(prof.heirlooms["chest"]) == "padded", "...and the heirloom is still yours")
	p.pack = []
	p.wear_set(G.start_gear())
	_reset()


func _sorting() -> void:
	var list: Array = [G.make("leather_cap"), G.make("sword", "rare", ["edges", "venom"]), G.make("garnet_ring", "fine"), G.make("plate"), G.make("soft_boots")]
	_check(Train.sorted_indices(list, "newest") == [4, 3, 2, 1, 0], "the stash sorts newest first")
	var by_r: Array = Train.sorted_indices(list, "rarity")
	_check(by_r[0] == 1 and by_r[1] == 2, "...by rarity (the Rare sword, then the Fine ring): %s" % [by_r])
	var by_s: Array = Train.sorted_indices(list, "slot")
	_check(by_s[0] == 1 and by_s[1] == 3 and by_s.back() == 2, "...by slot (weapons, chest... rings last): %s" % [by_s])
	var by_p: Array = Train.sorted_indices(list, "price")
	_check(Train.gear_sell(list[by_p[0]]) >= Train.gear_sell(list[by_p[1]]) and Train.gear_sell(list[by_p[1]]) >= Train.gear_sell(list[by_p.back()]), "...by price, dearest first")
	var by_k: Array = Train.sorted_indices(list, "kind")
	var kinds: Array = Train.Essence.KINDS.keys()
	var ok := true
	for i in by_k.size() - 1:
		ok = ok and kinds.find(Train.gear_kind(list[by_k[i]])) <= kinds.find(Train.gear_kind(list[by_k[i + 1]]))
	_check(ok, "...by essence")
	_check(Train.sorted_indices(list, "newest", "boots") == [4] and Train.sorted_indices(list, "newest", "all", "water") == [2], "it filters by slot and by essence")


func _store_rules() -> void:
	print("the store: buying into the pack or stash, selling from either")
	var m = _main()
	var prof = m.profile
	var p = m.player
	_reset()
	prof.store = {}
	Train.stock(prof)
	for k in Train.Essence.KINDS:
		prof.add_crystal(k, 500)
	var rack: Array = Train.outfit(prof)
	var g0: Dictionary = rack[0]
	var kind := Train.gear_kind(g0)
	var before: float = prof.crystal_total(kind)
	_check(Train.buy_gear(prof, p, 0, "chest") == "" and prof.chest.size() == 1 and G.same(prof.chest[0], g0) and prof.crystal_total(kind) == before - Train.gear_price(g0), "a rack piece bought into the stash, for its price")
	var g1: Dictionary = rack[1]
	_check(Train.buy_gear(prof, p, 1, "pack") == "" and prof.pack.size() == 1 and G.same(prof.pack[0], g1), "...one into the pack")
	var g2: Dictionary = rack[2]
	var slot2 := Train.wear_slot_for(prof, p, g2)
	_check(Train.buy_gear(prof, p, 2, "wear") == "" and G.same(prof.wear.get(slot2, {}), g2) and prof.pack.size() == 1, "...one bought and worn at once")
	_check(Train.buy_gear(prof, p, 0, "pack") == Train.TEXT["today_sold"] and Train.outfit(prof)[0].is_empty(), "a sold space can't be bought again")
	for i in Train.CHEST_SIZE:
		prof.chest.append(G.make("leather_cap"))
	_check(Train.buy_room(prof, p, rack[3], "chest") == Train.TEXT["chest_full"] and Train.buy_gear(prof, p, 3, "chest") == Train.TEXT["chest_full"], "a full stash can't take a bought piece")
	prof.chest = [G.make("iron_helm", "rare", ["vigor", "calm"])]
	prof.pack = [G.make("leather_cap")]
	var stone: float = prof.crystal_total("stone")
	var got_c := Train.gear_sell(prof.chest[0])
	_check(Train.sell(prof, "chest", 0) != "" and prof.chest.is_empty() and prof.crystal_total("stone") == stone + got_c, "selling from the stash: a crystal of its kind (%d Stone)" % got_c)
	var got_p := Train.gear_sell(prof.pack[0])
	_check(Train.sell(prof, "pack", 0) != "" and prof.pack.is_empty() and prof.crystal_total("stone") == stone + got_c + got_p, "...and from the pack")
	_check(Train.rack_shows(prof, p, G.make("axe"), "weapons") and not Train.rack_shows(prof, p, G.make("axe"), "armour") and Train.rack_shows(prof, p, G.make("plate"), "armour"), "the rack's filter shows weapons, or armour")
	_reset()


func _compare() -> void:
	var m = _main()
	var prof = m.profile
	var p = m.player
	_reset()
	_check(Train.versus(prof, p, G.make("sword", "rare", ["edges", "venom"])) > 0, "a Rare sword beats the starting sword")
	_check(Train.versus(prof, p, G.make("sword")) == 0, "the very same piece is neither better nor worse")
	_check(Train.versus(prof, p, G.make("leather_cap")) > 0 and Train.worn_against(prof, p, G.make("leather_cap")) == null, "anything beats an empty helm (it's set against nothing)")
	prof.wear = {"helm": G.make("iron_helm", "rare", ["vigor", "calm"])}
	Train.dress(prof, p)
	_check(Train.versus(prof, p, G.make("cloth_hood")) < 0, "a plain hood is worse than the Rare helm you'll wear")
	var rows: Array = G.compare(G.make("cloth_hood"), Train.worn_against(prof, p, G.make("cloth_hood")))
	_check(rows.any(func(r): return int(r[3]) < 0) and rows.any(func(r): return int(r[3]) > 0), "...its card sets each number against it, better and worse")
	_reset()


func _drawing() -> void:
	print("gear on the climber: every slot and weapon drawn")
	var base: Dictionary = Appearance.look(Appearance.DEFAULTS)
	var ok := true
	var sizes := {}
	var plain := D.Batch.new()
	Appearance.draw_front(plain, GearLook.dressed(base, G.start_gear()))
	var ids: Array = G.PIECE_ORDER + G.ARMOR_ORDER.filter(func(a): return a != "") + Weapons.WEAPONS.keys().filter(func(w): return w != "fists")
	for n in G.NAMED_ORDER:
		ids.append("named:" + n)
	for id in ids:
		var g: Dictionary = G.make_named(id.substr(6)) if id.begins_with("named:") else G.make(id, "rare" if id.length() % 2 == 0 else "")
		if g.is_empty():
			ok = false
			continue
		var gear: Dictionary = G.start_gear()
		var slot: String = G.carry_slots(G.slot_of(g))[0]
		gear[slot] = g
		var lk := GearLook.dressed(base, gear, G.base_id(g) if slot in ["melee", "ranged"] else "")
		var b := D.Batch.new()
		Appearance.draw_front(b, lk)
		var tb := D.Batch.new()
		for f in [Vector2.RIGHT, Vector2.DOWN, Vector2(-1, -1).normalized()]:
			Appearance.draw_legs(tb, Vector2.ZERO, f, f.orthogonal(), D.LIGHT_DIR, lk, 0.5)
			GearLook.tower_back(tb, Vector2.ZERO, f, f.orthogonal(), D.LIGHT_DIR, lk)
			GearLook.tower_chest(tb, Vector2.ZERO, f, f.orthogonal(), D.LIGHT_DIR, lk, 1.0)
			GearLook.tower_head(tb, Vector2.ZERO, f, f.orthogonal(), D.LIGHT_DIR, lk, 1.0)
			GearLook.ring_glint(tb, Vector2.ZERO, lk)
		sizes[id] = b.size()
		ok = ok and b.size() > 0 and tb.size() > 0
	_check(ok, "the front figure and the tower's layers draw every worn piece, armour, weapon and named piece (%d)" % ids.size())
	var changed: Array = ids.filter(func(id): return sizes.get(id, 0) != plain.size())
	_check(changed.size() >= ids.size() - 2, "...and the drawing changes with each piece (%d of %d differ from bare): %s" % [changed.size(), ids.size(), ids.filter(func(id): return not (id in changed))])
	# The climber in the tower and the mirror image dress the same way.
	var p = _main().player
	var keep: Dictionary = p.gear.duplicate()
	var g := G.start_gear()
	g["armor"] = G.make("plate")
	g["helm"] = G.make("feathered_cap")
	g["backpack"] = G.make("climbers_pack")
	g["amulet"] = G.make("bone_charm")
	p.wear_set(g)
	var lk: Dictionary = p.appearance_look.duplicate()
	p._piece_look(lk, true)
	p._armor_look(lk)
	p._piece_look(lk, false)
	_check(lk["head"] == "cap" and lk["pack"] == "pack" and lk["amulet"] and lk["armor_w"] == "plate" and not lk["hood_up"], "the climber in the tower is dressed: a cap over the plate's helm (the hood down), the pack, the amulet")
	var mirror_lk: Dictionary = load("res://scripts/mirror.gd").climber_look(p)
	_check(mirror_lk["head"] == "cap" and mirror_lk["pack"] == "pack", "...and their mirror image the same way")
	var dl: Dictionary = _main().dressed_look()
	_check(dl.get("gear_on", false) and dl["armor_w"] == "plate", "the climber screen's figure wears it too")
	p.wear_set(keep)


func _screens() -> void:
	print("the Loadout and stash screens")
	var m = _main()
	var prof = m.profile
	var p = m.player
	var menu = m.menu
	_reset()
	prof.pack = [G.make("axe"), G.make("leather_gloves", "fine", ["edges"])]
	prof.chest = [G.make("iron_helm", "rare", ["vigor", "calm"]), G.make("plate"), G.make("soft_boots")]
	prof.supplies = {"draught": 1}
	m.await_tower()
	m.open_train()
	await t._frames(3)
	var car: Array = t._car_buttons("car_page", "loadout")
	_check(car.size() == 1 and t._car_buttons("slot", "worn:armor").size() == 1 and t._car_buttons("car_page", "stash").size() == 1, "your car: what you'll wear on the wardrobe, and buttons to the Loadout and the stash")
	if car.size() == 1:
		car[0].pressed.emit()
		await t._frames(3)
	_check(menu.page == "loadout" and menu.rail.visible, "the Loadout opens beside the rail")
	var doll: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("slot", "")).begins_with("worn:"))
	_check(doll.size() == 12, "a paper doll of every slot (%d)" % doll.size())
	var packs: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("slot", "")).begins_with("pack:"))
	_check(packs.size() == p.pack_size(), "the pack shows its %d spaces" % p.pack_size())
	var labels: Array = t._all_labels(menu.box).map(func(l): return l.text)
	_check(labels.any(func(s): return s.to_lower() == (menu.loadout_page.TEXT["pack_head"] % [2, p.pack_size()]).to_lower()), "...under a heading that says it goes up the tower")
	# Choose a stash helm and wear it from its card.
	var helm = _box_slot("chest:0")
	_check(helm != null and helm.better > 0, "the stash's Rare helm shows a green arrow (better than what you wear)")
	menu._show_details("chest:0")
	await t._frames(1)
	var wear: Array = t._all_buttons(menu.details).filter(func(b): return b.get_meta("equip", "") == "chest:0")
	_check(wear.size() == 1, "its card: Wear it")
	if wear.size() == 1:
		wear[0].pressed.emit()
		await t._frames(3)
	_check(G.base_id(prof.wear.get("helm", {})) == "iron_helm" and menu.page == "loadout" and menu.inv_sel == "worn:helm", "pressing it wears the helm; the card follows it to the doll (%s, %s, %s)" % [prof.wear.keys(), menu.inv_sel, menu.toast])
	_check(t._all_labels(menu.details).any(func(l): return l.text == menu.loadout_page.TEXT["from_wear"]), "...and the card says it goes on as you set off")
	var off: Array = t._all_buttons(menu.details).filter(func(b): return b.get_meta("unequip", "") == "helm:chest")
	if off.size() == 1:
		off[0].pressed.emit()
		await t._frames(3)
	_check(not prof.wear.has("helm") and prof.chest.any(func(g): return G.base_id(g) == "iron_helm"), "Take it off: into your stash")
	# A second press on a pack piece moves it across.
	menu._slot_pressed("pack:0")
	await t._frames(1)
	menu._slot_pressed("pack:0")
	await t._frames(3)
	_check(prof.pack.size() == 1 and G.base_id(prof.chest.back()) == "axe", "a second press on a pack piece moves it into the stash")
	# The worn slot's card offers what fits.
	menu._show_details("worn:armor")
	await t._frames(1)
	var fits: Array = t._all_buttons(menu.details).filter(func(b): return String(b.get_meta("equip", "")).begins_with("chest:"))
	_check(fits.size() == 1, "an empty chest slot's card offers the plate in your stash")
	# Q / E to the stash.
	menu._cycle(1)
	await t._frames(3)
	_check(menu.page == "stash", "E (RB) goes to the stash tab")
	var cells: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("slot", "")).begins_with("chest:"))
	_check(cells.size() == Train.CHEST_SIZE, "the stash shows every space (%d)" % cells.size())
	var sorter: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cycler", "") == "sort")
	_check(sorter.size() == 1, "the stash's sort")
	menu.stash_page.SORT = "newest"
	menu.stash_page.SLOT = "all"
	if sorter.size() == 1:
		sorter[0].change(1)  # (Right, or a tap on its right half)
		await t._frames(3)
	_check(menu.stash_page.SORT == "rarity", "...Right on it sorts by rarity")
	var order: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("slot", "")).begins_with("chest:") and not b.empty).map(func(b): return b.get_meta("slot"))
	print("    stash order: ", order, " chest: ", prof.chest.map(func(g): return G.display(g)))
	_check(order.size() == prof.chest.size() and not order.is_empty() and order[0] == "chest:%d" % prof.chest.find(prof.chest.filter(func(g): return G.rarity(g) == "rare")[0]), "...the Rare helm first: %s" % [order])
	var filt: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cycler", "") == "slot")
	if filt.size() == 1:
		filt[0].tap_at(filt[0].get_global_rect().end - Vector2(4, 4))
		await t._frames(3)
	_check(menu.stash_page.SLOT == "melee" and menu.box.find_children("*", "Button", true, false).filter(func(b): return String(b.get_meta("slot", "")).begins_with("chest:")).size() == 1, "a tap on the slot filter shows only melee weapons (the axe)")
	menu.stash_page.SORT = "newest"
	menu.stash_page.SLOT = "all"
	menu.stash_page.KIND = "all"
	menu.close()
	await t._frames(2)
	_check(menu.page == "train" and menu.train_car == "personal", "closing goes back to your car")
	# On the train, the inventory is the Loadout.
	menu.open("inventory", true)
	await t._frames(2)
	_check(menu.page == "loadout", "on the train the inventory opens the Loadout (the pack and stash are the train's)")
	menu.close()
	await t._frames(2)


func _store_screen() -> void:
	print("the store car: compare, filter, buy into the pack or stash, sell from either")
	var m = _main()
	var prof = m.profile
	var menu = m.menu
	_reset()
	prof.store = {}
	Train.stock(prof)
	for k in Train.Essence.KINDS:
		prof.add_crystal(k, 300)
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = "outfit:0"
	menu.open("train")
	await t._frames(3)
	var buys: Array = t._car_buttons("buy", "outfit:0") + t._car_buttons("buy", "outfit:0:chest") + t._car_buttons("buy", "outfit:0:wear")
	_check(buys.size() == 3 and buys.all(func(b): return not b.disabled), "a rack piece's card: buy into your pack, into your stash, or buy and wear it")
	var g0: Dictionary = Train.outfit(prof)[0]
	if buys.size() == 3:
		buys[1].pressed.emit()
		await t._frames(3)
	_check(prof.chest.size() == 1 and G.same(prof.chest[0], g0), "Buy: into your stash")
	var labels: Array = t._all_labels(menu).map(func(l): return l.text)
	_check(labels.any(func(s): return s.contains(Train.TEXT["moved_chest"] % G.display(g0))), "...and the card says where it went")
	var rack_f: Array = t._car_buttons("store_filter", "rack")
	_check(rack_f.size() == 1, "the rack's filter")
	if rack_f.size() == 1:
		rack_f[0].change(2)  # (to Weapons)
		await t._frames(3)
	var shown: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return String(b.get_meta("slot", "")).begins_with("outfit:"))
	_check(menu.train_page.rack_filter == "weapons" and shown.all(func(b): return b.rec != null and G.slot_of(b.rec) in ["melee", "ranged"]), "...Weapons shows only weapons (%d)" % shown.size())
	menu.train_page.rack_filter = "all"
	# Selling: from the pack or the stash.
	prof.pack = [G.make("leather_cap")]
	menu.train_store = "sell"
	menu.inv_sel = ""
	menu.open("train")
	await t._frames(3)
	var from: Array = t._car_buttons("store_filter", "from")
	_check(from.size() == 1 and t._car_buttons("slot", "pack:0").size() == 1 and t._car_buttons("slot", "chest:0").size() == 1, "selling shows your pack and your stash, with where to sell from")
	if from.size() == 1:
		from[0].change(2)  # (Your stash)
		await t._frames(3)
	_check(menu.train_page.sell_from == "chest" and t._car_buttons("slot", "pack:0").is_empty() and t._car_buttons("slot", "chest:0").size() == 1, "...only the stash")
	menu.inv_sel = "chest:0"
	menu.open("train")
	await t._frames(2)
	var sell: Array = t._car_buttons("sell", "chest:0")
	for i in 2:
		if sell.size() == 1:
			sell[0].pressed.emit()
			await t._frames(3)
			sell = t._car_buttons("sell", "chest:0")
	_check(prof.chest.is_empty(), "a stash piece sells (asking once first)")
	menu.train_page.sell_from = "all"
	menu.train_store = "shop"
	menu.train_car = "personal"
	menu.close()
	await t._frames(2)


func _fits() -> void:
	print("the Loadout, stash and store fit at every Interface size")
	var m = _main()
	var prof = m.profile
	var menu = m.menu
	var U = load("res://scripts/ui.gd")
	var M = menu.get_script()
	_reset()
	prof.pack = [G.make("axe"), G.make("leather_gloves", "fine", ["edges"])]
	for i in 14:
		prof.chest.append(G.make(["plate", "leather_cap", "garnet_ring", "longbow", "chain_leggings"][i % 5]))
	prof.wear = {"armor": G.make("plate"), "backpack": G.make("climbers_pack")}
	prof.supplies = {"draught": 1, "flare": 1}
	var was_size: Vector2i = t.root.size
	var keep_ui: String = M.settings["ui_size"]
	m.await_tower()
	m.open_train()
	await t._frames(2)
	var problems: Array = []
	for sz in [Vector2i(1280, 720), Vector2i(800, 400), Vector2i(740, 360), Vector2i(915, 412)]:
		t.root.size = sz
		var phone: bool = sz.x != 1280
		for ui in U.UI_SIZE_ORDER:
			menu._set_setting("ui_size", ui)
			m.touch._set_active(phone)
			await t._frames(2)
			var view: Rect2 = t.root.get_visible_rect()
			for pg in ["loadout", "stash"]:
				menu.inv_sel = ""
				menu.open(pg, true)
				await t._frames(3)
				problems.append_array(t._fit_problems("%s %s %dx%d" % [pg, ui, sz.x, sz.y], menu.panel, view))
			menu.close()
			await t._frames(1)
			for st in ["shop", "sell"]:
				menu.train_car = "store"
				menu.train_store = st
				menu.open("train")
				await t._frames(2)
				menu.train_page.go_to(menu.train_page._index("store"))
				await t._train_settled()
				await t._frames(2)
				problems.append_array(t._fit_problems("store %s %s %dx%d" % [st, ui, sz.x, sz.y], menu.train_page.car_scrolls["store"], menu.train_view.get_global_rect()))
			menu.close()
			await t._frames(1)
	_check(problems.is_empty(), "the Loadout, stash and store fit or scroll at every Interface size, on a computer and three phones (%d problems): %s" % [problems.size(), problems.slice(0, 8)])
	for pr in problems.slice(0, 60):
		print("    ", pr)
	t.root.size = was_size
	menu._set_setting("ui_size", keep_ui)
	m.touch._set_active(false)
	menu.train_store = "shop"
	menu.train_car = "personal"
	await t._frames(2)
	_reset()
