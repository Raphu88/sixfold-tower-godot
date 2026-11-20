extends RefCounted
## Charms (charms.gd): worn in the one charm slot, never used up. A passive
## that's on while worn and off when removed; a charge that spends, stays
## spent and refills only by feeding it essence (unbanked in the tower,
## crystals at the bench); the special slots (an extra belt kind, an extra
## pack space, a safe pocket kept on a fall); crafted by a Rune Artist, sold
## by the outfitter, found in towers; old saves (the Wardbreaker consumable,
## the Ember Charm amulet) load; the Entity explains them; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const C := preload("res://scripts/charms.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Items := preload("res://scripts/items.gd")
const Lost := preload("res://scripts/lost.gd")
const D := preload("res://scripts/draw_util.gd")
const TestRun := preload("res://scripts/test_run.gd")
const Registry := preload("res://scripts/data_registry.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("charms")
	await t._fresh_main()
	_data()
	await _passives()
	await _charges()
	await _auras()
	await _special_slots()
	await _safe_pocket()
	await _where_from()
	_old_saves()
	await _cards_and_words()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber in the tower, bonded, charmless.
func _fresh_player():
	var m = _main()
	var p = m.player
	p.gear = G.start_gear()
	p.pack = []
	p.refresh_gear()
	p.dead = false
	p.hp = p.max_health()
	return p


func _data() -> void:
	var all: Array = C.all()
	_check(all.size() >= 10 and all.size() % 6 == 0, "ten or more charms, counted by sixes (%d)" % all.size())
	var kinds := {}
	var rar := {}
	var ok := true
	for id in all:
		var d: Dictionary = G.PIECES[id]
		var r := G.natural_rarity(id)
		rar[r] = true
		if r == "common":
			ok = ok and String(d.get("kind", "")) == "" and not G.enchanted(G.make(id))
		else:
			ok = ok and String(d.get("kind", "")) != "" and G.enchanted(G.make(id))
			kinds[d["kind"]] = true
		ok = ok and int(d.get("drop_weight", 0)) == 0 and d.has("desc") and d.has("name") and C.CRAFT.has(id) and Train.BASE_PRICE.has(id)
		ok = ok and not G.wears(G.make(id))
	_check(ok, "every charm: Common ones ordinary, Fine and Rare enchanted in their essence; never a plain drop; a craft cost and a price; never wears")
	_check(kinds.size() == 6, "charms across all six essences (%s)" % [kinds.keys()])
	_check(rar.has("common") and rar.has("fine") and rar.has("rare"), "Common, Fine and Rare charms")
	_check(all.filter(func(id): return C.charge_id(id) != "").size() >= 3, "some charms hold a charge")
	_check(G.heirloom_slot("lucky_knot") == "charm" and G.gear_slot_for("charm") == "charm" and "charm" in Train.WEAR_SLOTS and "charm" in G.SLOTS, "a charm slot to wear, keep as an heirloom and choose in the Loadout")
	# The Data editor knows the tables.
	var tables: Array = []
	for sec in Registry.SECTIONS:
		tables.append_array(sec.get("tables", []))
	_check(tables.has("charms/CHARGES") and tables.has("charms/TEXT") and tables.has("charms/CRAFT") and tables.has("charms/SHOP") and tables.has("charms/LOOT") and tables.has("gear/BAG"),
		"the charm and bag tables are in the Data editor")
	# No banned word in the new tables.
	var words: Array = [JSON.stringify(C.CHARGES), JSON.stringify(C.TEXT), JSON.stringify(Entity.TIPS.get("charm", {})), JSON.stringify(Entity.TIPS.get("bag_heavy", {})),
		JSON.stringify(Talk.DIALOGUE.get("how_charms", {})), JSON.stringify(Talk.DIALOGUE.get("how_bags", {})), JSON.stringify(G.BAG)]
	for id in all + ["satchel", "pack", "great_pack"]:
		words.append(JSON.stringify(G.PIECES[id]))
	var hits: Array = []
	for w in words:
		for b in BANNED:
			if b in String(w).to_lower():
				hits.append(b)
	_check(hits.is_empty(), "no banned words in the charm and bag tables (%s)" % [hits])
	# Every charm drawn in code, at every size.
	var empty: Array = []
	for id in all:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			G.icon_into(b, G.make(id), Vector2.ZERO, s, G.color(id))
			if b.pts.is_empty():
				empty.append("%s@%s" % [id, s])
	_check(empty.is_empty(), "every charm has its own icon (%s)" % [empty])
	# The consumable is gone from every table.
	_check(not Items.ITEMS.has("wardbreaker") and not ("wardbreaker" in Items.ORDER) and not Bench.BREW.has("wardbreaker") and not ("wardbreaker" in Train.supplies()),
		"the Wardbreaker is off the belt, the shelf and the bench's brews")


func _passives() -> void:
	var p = _fresh_player()
	var sta0: float = p.max_sta
	p.take_gear(G.make("lucky_knot"))
	_check(G.base_id(p.gear["charm"]) == "lucky_knot" and is_equal_approx(p.max_sta, sta0 + 12.0), "wearing a Lucky Knot: +12 max stamina (%.0f)" % p.max_sta)
	p.gear["charm"] = {}
	p.refresh_gear()
	_check(is_equal_approx(p.max_sta, sta0), "taking it off ends it (%.0f)" % p.max_sta)
	p.take_gear(G.make("feather_token"))
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p._try_roll(Vector2.RIGHT)
	var cd_charm: float = p.roll_cd
	p.gear["charm"] = {}
	p.refresh_gear()
	p.roll_t = 0.0
	p.roll_cd = 0.0
	p.sta = p.max_sta
	p._try_roll(Vector2.RIGHT)
	_check(cd_charm < p.roll_cd and cd_charm > float(load("res://scripts/combat.gd").CLIMBER["roll_time"]), "a Feather Token: you can roll again sooner (%.2f s, not %.2f s), never before the roll ends" % [cd_charm, p.roll_cd])
	p.roll_t = 0.0
	await t._frames(1)


func _charges() -> void:
	var m = _main()
	var p = _fresh_player()
	var knot := G.make("ashen_knot")
	_check(C.charge_max(knot) == 1 and C.charges(knot) == 1, "a fresh Ashen Knot holds its charge")
	p.take_gear(knot)
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(9999.0, null, true)
	_check(not p.dead and p.hp >= p.max_health() * 0.29 and C.charges(p.gear["charm"]) == 0, "its charge: a blow that would fell you leaves you standing, and the charge is spent (%.0f health)" % p.hp)
	await t._wait(0.6)
	_check(C.charges(p.gear["charm"]) == 0, "a spent charge stays spent: nothing refills it on its own")
	# Feeding it essence you haven't banked (the tower's inventory).
	m.run_essence = {"fire": 10.0, "air": 5.0}
	_check(C.refill_unbanked(m, p.gear["charm"]) != "" and C.charges(p.gear["charm"]) == 0, "too little unbanked essence: it isn't refilled")
	m.run_essence = {"fire": 30.0, "air": 10.0}
	var need := C.refill_amount(p.gear["charm"])
	_check(C.refill_unbanked(m, p.gear["charm"]) == "" and C.charges(p.gear["charm"]) == 1 and absf(C.unbanked(m) - (40.0 - need)) < 0.01,
		"feeding it %d unbanked essence refills it (%.0f left)" % [need, C.unbanked(m)])
	# The inventory's card offers it once it's spent.
	C.spend(p.gear["charm"])
	m.run_essence = {"fire": 60.0}
	m.menu.inv_sel = "gear:charm"
	m.menu.open("inventory")
	await t._frames(3)
	var feed: Array = m.menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("help", "") == "feed_charm")
	_check(feed.size() == 1 and not feed[0].disabled, "the inventory's charm card: Feed it unbanked essence")
	if feed.size() == 1:
		feed[0].pressed.emit()
		await t._frames(3)
	_check(C.charges(p.gear["charm"]) == 1 and C.unbanked(m) < 60.0, "...and pressing it refills the charge")
	m.menu.close()
	await t._frames(2)
	# On the train: the bench refills it with crystals of its kind (anyone).
	var prof = m.profile
	prof.crystals = []
	var spent := G.make("ashen_knot")
	spent["charge"] = 0
	prof.wear = {"charm": spent}
	var cost := Bench.refill_cost(spent)
	_check(cost == {"fire": C.refill_amount(spent)}, "the bench refills with crystals of the charm's kind (%s)" % [cost])
	_check(Bench.refill(prof, "wear:charm") != "" and C.charges(prof.wear["charm"]) == 0, "...not without the crystals")
	prof.add_crystal("fire", 100.0)
	_check(Bench.refill(prof, "wear:charm") == "" and C.charges(prof.wear["charm"]) == 1 and int(prof.crystal_total("fire")) == 100 - int(cost["fire"]), "...and with them it's charged again")
	_check(Bench.charm_refs(prof).has("wear:charm"), "the bench's Charms counter lists the charm you'll wear")
	prof.wear = {}
	# A charge kept on the record survives the save's round trip.
	var rec := G.rec({"base": "gale_charm", "rarity": "rare", "traits": [], "charge": 1})
	_check(C.charges(rec) == 1 and C.charge_max(rec) == 3, "a charm's charges are kept on its record")
	# The Mending Bead heals below a third; the Gale Charm's gust.
	p = _fresh_player()
	p.take_gear(G.make("mending_bead"))
	p.hp = p.max_health() * 0.5
	p.heal_left = 0.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(p.max_health() * 0.3, null, true)
	_check(p.heal_left > 0.0 and C.charges(p.gear["charm"]) == 1, "a Mending Bead: below a third of your health it heals you, one charge spent (%d left)" % C.charges(p.gear["charm"]))
	p.heal_left = 0.0
	p.hp = p.max_health()
	p.take_gear(G.make("gale_charm"))
	var foe = await t._spawn("slime", p.global_position + Vector2(50, 0))
	var x0: float = foe.global_position.x
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(4.0, foe)
	await t._frames(6)
	_check(C.charges(p.gear["charm"]) == 2 and (not is_instance_valid(foe) or foe.knock.length() > 50.0 or foe.global_position.x > x0 + 4.0), "a Gale Charm: a blow that lands on you hurls the foes around you back (one charge spent)")
	if is_instance_valid(foe):
		foe.queue_free()
	# A charm kept as an heirloom: what the climb spends stays spent on the heirloom.
	prof.heirlooms["charm"] = G.make("gale_charm")
	p.take_gear(G.heirloom_copy(prof.heirlooms["charm"]))
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(4.0, null, true)
	_check(C.charges(p.gear["charm"]) == 2 and C.charges(prof.heirlooms["charm"]) == 2, "a charm kept as an heirloom: a charge spent on the climb stays spent on the heirloom (it won't come back full by itself) (%d, %d)" % [C.charges(p.gear["charm"]), C.charges(prof.heirlooms["charm"])])
	prof.heirlooms.erase("charm")
	p.gear["charm"] = {}
	p.refresh_gear()


func _auras() -> void:
	var m = _main()
	var p = _fresh_player()
	p.take_gear(G.make("tide_shell"))
	p.charm_calm = 0.0
	p.charm_shield = 0.0
	await t._wait(0.3)
	_check(p.charm_shield <= 0.01, "a Tide Shell: no shield while the fight is fresh")
	p.charm_calm = 10.0
	await t._wait(2.5)
	_check(p.charm_shield >= 11.9, "...it grows back once you've gone a while without being hit (%.1f)" % p.charm_shield)
	var hp0: float = p.hp
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.receive_attack(8.0, null, true)
	_check(is_equal_approx(p.hp, hp0) and p.charm_shield < 5.0, "...and soaks a blow (health %.0f, shield %.1f)" % [p.hp, p.charm_shield])
	# The Ward Stone: the first blow in each room hurts half as much.
	p = _fresh_player()
	p.take_gear(G.make("ward_stone"))
	p.ward_room = ""
	var taken := []
	for i in 2:
		var h: float = p.hp
		p.hurt_t = 0.0
		p.iframes = 0.0
		p.receive_attack(20.0, null, true)
		taken.append(h - p.hp)
	_check(taken[0] < taken[1] * 0.6, "a Ward Stone: the first blow in a room hurts half as much, the next as usual (%s)" % [taken])
	p.ward_room = ""
	m.room_at = 999
	p.gear["charm"] = {}
	p.refresh_gear()


func _special_slots() -> void:
	var p = _fresh_player()
	var kinds0: int = p.belt_kinds()
	p.take_gear(G.make("belt_hook"))
	_check(p.belt_kinds() == kinds0 + 1, "a Belt Hook: one more kind of item on the belt (%d)" % p.belt_kinds())
	var size0 := int(G.BAG["none"])
	p.take_gear(G.make("pocket_clasp"))
	_check(p.pack_size() == size0 + 1 and p.belt_kinds() == kinds0, "a Pocket Clasp: one more pack space (%d), and the hook's gone" % p.pack_size())
	p.take_gear(G.make("satchel"))
	_check(p.pack_size() == 5, "...on top of a bag (a Satchel 4 + 1 = %d)" % p.pack_size())
	p.gear["charm"] = {}
	p.gear["backpack"] = {}
	p.refresh_gear()


func _safe_pocket() -> void:
	var m = _main()
	var prof = m.profile
	var p = _fresh_player()
	prof.pack = []
	prof.wear = {}
	prof.heirlooms = {}
	m.first_climb = false
	p.take_gear(G.make("keepers_purse"))
	p.take_gear(G.make("satchel"))
	_check(p.pack_size() == 5 and C.safe_pocket(p), "a Keeper's Purse: one more pack space and a safe pocket")
	p.pack = [G.make("longbow", "rare", ["hunt", "edges"]), G.make("axe"), G.make("plate")]
	var lost0: int = prof.lost.size()
	m.weapon_loss_chance = 0.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(9999.0, null, true)
	_check(p.dead, "a fall...")
	_check(prof.pack.size() == 1 and G.base_id(prof.pack[0]) == "longbow" and G.rarity(prof.pack[0]) == "rare", "...the safe pocket's piece comes home to the train (%s)" % [prof.pack.map(func(g): return G.base_id(g))])
	_check(G.base_id(prof.wear.get("charm", {})) == "keepers_purse", "...and so does the purse")
	_check(prof.lost.size() - lost0 == 2 and not prof.lost.any(func(e): return G.base_id(e["rec"]) == "longbow"), "...while the rest of the pack is lost (%d)" % (prof.lost.size() - lost0))
	m.weapon_loss_chance = Lost.WEAPON_CHANCE
	prof.pack = []
	prof.wear = {}
	await t._fresh_main()


func _where_from() -> void:
	var m = _main()
	var prof = m.profile
	prof.crystals = []
	prof.chest = []
	# A Rune Artist crafts one at the bench.
	prof.bonds = {}
	_check(Bench.craft(prof, "wardbreaker").begins_with("!") and prof.chest.is_empty(), "only a Rune Artist crafts a charm")
	prof.add_bond("brow", "rune_artist", false)
	_check(Bench.craft(prof, "wardbreaker").begins_with("!"), "...given the essence")
	prof.add_crystal("blade", 100.0)
	_check(Bench.craft(prof, "wardbreaker") == "chest" and prof.chest.size() == 1 and G.base_id(prof.chest[0]) == "wardbreaker" and int(prof.crystal_total("blade")) == 100 - int(C.CRAFT["wardbreaker"]["blade"]),
		"a Rune Artist crafts a Wardbreaker Charm into the stash, for its crystals")
	_check(Bench.COUNTERS.any(func(c): return c[0] == "charm") and Bench.locked(prof, "charm") == "", "the bench has a Charms counter, open to anyone (crafting asks for a Rune Artist)")
	# The outfitter sells them.
	var rack: Array = Train.roll_outfit(prof)
	var charms: Array = rack.filter(func(g): return C.is_charm(g))
	_check(charms.size() == int(C.SHOP["rack"]) and charms.all(func(g): return G.rarity_rank(G.rarity(g)) <= G.rarity_rank("fine")), "the outfitter's rail holds %d charm(s), Common or Fine" % charms.size())
	prof.store = {"outfit": rack.map(func(g): return G.code(g)), "today": ""}
	var at := -1
	for i in rack.size():
		if C.is_charm(rack[i]):
			at = i
	prof.add_crystal(C.kind(rack[at]), 200.0)
	prof.add_crystal("water", 200.0)
	var n0: int = prof.chest.size()
	_check(at >= 0 and Train.buy_gear(prof, m.player, at, "chest") == "" and prof.chest.size() == n0 + 1 and C.is_charm(prof.chest.back()), "...and you can buy one")
	# Found in towers: a vault, a secret room, a rare drop.
	for i in 20:
		var c := C.roll(4)
		if not C.is_charm(c) or G.rarity(c) == "storied":
			_check(false, "a found charm is a charm, never Storied (%s)" % [c])
			break
	await t._fresh_main()
	m = _main()
	m.grant_test_bonds()
	m.first_climb = false
	m.wings.charm_odds = 1.0
	var V = load("res://scripts/vessel.gd")
	var force: float = V.vault_force
	V.vault_force = 0.0  # (no vessel in the way)
	var vault: Array = m.wings.vault_choices(false)
	V.vault_force = force
	_check(String(vault[2]).begins_with("gear:") and C.is_charm(String(vault[2]).substr(5)), "a vault may hold a charm (%s)" % vault[2])
	var hidden: Array = m.wings.hidden_crystals()
	_check(hidden.size() == 4 and C.is_charm(String(hidden[3]).substr(5)), "...and a secret room's crystals")
	m.wings.charm_odds = 0.0
	m.gear_drop_chance = 0.0
	m.charm_drop_chance = 1.0
	var foe = await t._spawn("slime", m.player.global_position + Vector2(300, 0))
	var drops0: int = m.gear_drops.size()
	t._slay(foe)
	await t._frames(2)
	_check(m.gear_drops.size() == drops0 + 1 and C.is_charm(m.gear_drops.back()["rec"]), "...and now and then a slain monster leaves one")
	m.charm_drop_chance = 0.0
	m.gear_drop_chance = G.DROP_CHANCE
	# Charms come home like worn gear.
	var p = m.player
	p.take_gear(G.make("iron_brooch"))
	m.profile.wear = {}
	m.bring_worn_home()
	_check(G.base_id(m.profile.wear.get("charm", {})) == "iron_brooch", "a charm you wear comes home with you (a recall or a summit)")
	m.profile.wear = {}


func _old_saves() -> void:
	var path := TestRun.path("user://charms_test.cfg")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "heirlooms", {"amulet": "ember_charm"})
	old.set_value("train", "supplies", {"wardbreaker": 2, "draught": 1})
	old.set_value("train", "supply_paid", {"wardbreaker": [{"blade": 16}, {"blade": 10}], "draught": [{"stone": 3}]})
	old.set_value("train", "wear", {"amulet": G.make("ember_charm")})
	old.save(path)
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(not again.supplies.has("wardbreaker") and int(again.supplies.get("draught", 0)) == 1 and int(again.crystal_total("blade")) == 26,
		"an old save's packed Wardbreaker Charms load as the crystals paid for them (%d Blade)" % int(again.crystal_total("blade")))
	_check(G.base_id(again.heirlooms.get("charm", {})) == "ember_charm" and not again.heirlooms.has("amulet"), "an old Ember Charm heirloom (an amulet then) is the charm heirloom now")
	_check(G.base_id(again.wear.get("charm", {})) == "ember_charm" and not again.wear.has("amulet"), "...and one chosen to wear goes in the charm slot")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cards_and_words() -> void:
	var m = _main()
	_check(Entity.TIPS.has("charm") and Entity.TIPS.has("bag_heavy"), "the Entity's first-time moments: a charm, and a big bag slowing you")
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check(how.has("how_charms") and how.has("how_bags") and Talk.DIALOGUE.has("how_charms") and Talk.DIALOGUE.has("how_bags"), "\"How do charms work?\" and \"How do bags work?\" in the Entity's How do things work here?")
	for k in ["bench_tab:charm", "slot:bench:craft", "slot:bench:charm", "bench_do:refill", "bench_do:craft", "feed_charm"]:
		_check(Help.entry(k) != "", "the Entity explains %s" % k)
	# A charm's card names its charge and that it's never used up.
	var lines: Array = G.trait_lines(G.make("wardbreaker"))
	_check(lines.any(func(l): return String(l[0]).begins_with("Charge")), "a charm's card shows its charge")
	# The bench's Charms counter, on the train.
	var prof = m.profile
	prof.add_bond("brow", "rune_artist", false)
	for k in ["air", "water", "iron", "fire", "stone", "blade"]:
		prof.add_crystal(k, 200.0)
	var w := G.make("tide_shell")
	prof.wear = {"charm": G.make("wardbreaker")}
	prof.wear["charm"]["charge"] = 0
	prof.chest = [w]
	m.await_tower()
	m.open_train()
	await t._frames(3)
	var menu = m.menu
	menu.train_car = "workshop"
	menu.train_bench = "charm"
	menu.inv_sel = "bench:wear:charm"
	menu.open("train")
	await t._frames(4)
	var refill: Array = t._car_buttons("bench_do", "refill")
	_check(refill.size() == 1 and not refill[0].disabled, "the bench's Charms counter: Refill for a spent charm")
	if refill.size() == 1:
		refill[0].pressed.emit()
		await t._frames(2)
		refill = t._car_buttons("bench_do", "refill")
		if refill.size() == 1:
			refill[0].pressed.emit()
			await t._frames(2)
	_check(C.charges(prof.wear["charm"]) == 1, "...pressed twice, it's charged again")
	menu.inv_sel = "bench:craft:lucky_knot"
	menu.open("train")
	await t._frames(4)
	var n0: int = prof.chest.size()
	for i in 2:
		var cb: Array = t._car_buttons("bench_do", "craft")
		if cb.size() == 1:
			cb[0].pressed.emit()
			await t._frames(2)
	_check(prof.chest.size() == n0 + 1 and G.base_id(prof.chest.back()) == "lucky_knot", "...and Craft it makes a charm, into the stash")
	menu.close()
	await t._frames(2)
	prof.wear = {}
	prof.chest = []
