extends RefCounted
## How banked essence flows (essence_flow.gd, profile.gd pour/drink): the
## split at a stair sums to what was banked and keeps its shares, and the
## stair's line says them; marks grow slower than they did when every mark
## took everything; eating a crystal flows the natural way (no crystal share,
## no steering); a tincture goes only where you choose (a mark, or an
## unmarked part); tinctures can be crafted, bought and found, used from the
## belt (the crystals page) and drunk on the train; a tincture left on the
## belt comes home packed; the Entity's first-time lines fire once; old
## settings move to the new default once; old saves load. Run by
## smoke_test.gd (_part_tests); `t` is the smoke test.

const Flow := preload("res://scripts/essence_flow.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Items := preload("res://scripts/items.gd")
const Guide := preload("res://scripts/guide.gd")
const Help := preload("res://scripts/entity_help.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const PS := preload("res://scripts/profile.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var M = load("res://scripts/menu.gd")


func run(smoke) -> void:
	t = smoke
	print("essence flow: the split, eating crystals, tinctures")
	await _split()
	await _stair_line()
	await _slower()
	await _eat()
	await _tinctures()
	await _found_bought_crafted()
	await _belt_and_page()
	await _train_page()
	await _entity()
	await _old_saves()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh(marks := true) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	if marks:
		main.grant_test_bonds()
	var prof = main.profile
	prof.crystals = []
	prof.soak = {}
	prof.density = {}
	prof.part_density = {}
	prof.tally = {}
	prof.supplies = {}
	prof.supply_paid = {}
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)


func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s


# --- the split ------------------------------------------------------------------------

func _split() -> void:
	await _fresh()
	var prof = t.main.profile
	var sh: Dictionary = Flow.shares(0.3)
	_check(is_equal_approx(float(sh["body"]) + float(sh["marks"]) + float(sh["crystals"]), 1.0) and is_equal_approx(float(sh["crystals"]), 0.3)
		and is_equal_approx(float(sh["body"]) / float(sh["marks"]), float(Flow.SPLIT["body"]) / float(Flow.SPLIT["marks"])),
		"the split's shares add up, the crystals at the setting and body and marks in their proportions (%s)" % sh)
	_check(Train.CONDENSE_DEFAULT == "30" and is_equal_approx(Flow.default_crystal_share(), 0.3), "the default crystal share is 30%")
	var xp0 := float(prof.bonds["hand"]["xp"]) + float(prof.bonds["legs"]["xp"])
	var out: Dictionary = prof.pour({"air": 100.0, "fire": 50.0}, {"heart": 2.0, "back": 1.0}, 0.3)
	var total := float(out["body"]) + float(out["marks"]) + float(out["crystals"])
	_check(is_equal_approx(total, 150.0) and is_equal_approx(float(out["total"]), 150.0), "the split sums to what was banked (%.1f of 150)" % total)
	_check(float(out["crystals"]) == 45.0 and prof.crystal_total("air") == 30.0 and prof.crystal_total("fire") == 15.0, "30%% condenses into crystals, per kind (%s)" % [prof.crystals])
	_check(is_equal_approx(float(out["body"]), 45.0) and is_equal_approx(float(out["marks"]), 60.0), "body and marks share the rest, 3 to 4 (%.1f, %.1f)" % [out["body"], out["marks"]])
	_check(is_equal_approx(_sum(prof.density), 45.0), "only the body's share settles as density (%.1f)" % _sum(prof.density))
	_check(float(prof.soak.get("heart", 0.0)) > float(prof.soak.get("back", 0.0)) and float(prof.soak.get("back", 0.0)) > 0.0 and not prof.soak.has("hand"),
		"the body's share soaks into the unmarked parts by what each did (%s)" % prof.soak)
	var xp1 := float(prof.bonds["hand"]["xp"]) + float(prof.bonds["legs"]["xp"])
	_check(xp1 > xp0, "the marks' share grows the marks")
	# Each kind to the marks of that kind: two Air marks share the Air; the
	# Fire (no Fire mark) spreads thin over both.
	_check(is_equal_approx(float(prof.bonds["hand"]["xp"]), float(prof.bonds["legs"]["xp"])), "two marks of one kind share it evenly")
	var want: float = (70.0 * 4.0 / 7.0 * PS.AFFINITY_WEIGHT * 0.5 + 35.0 * 4.0 / 7.0 * PS.OTHER_WEIGHT * 0.5) * PS.STEP_RATE * prof.body_drag()
	_check(absf(float(prof.bonds["hand"]["xp"]) - want) < 0.01, "a mark grows from its share: own kind %sx, others %sx (%.2f, want %.2f)" % [PS.AFFINITY_WEIGHT, PS.OTHER_WEIGHT, prof.bonds["hand"]["xp"], want])
	# No mark to take it (the first climb): the marks' share goes to the body.
	await _fresh(false)
	prof = t.main.profile
	out = prof.pour({"water": 100.0}, {"brow": 1.0}, 0.3)
	_check(float(out["marks"]) == 0.0 and is_equal_approx(float(out["body"]), 70.0), "with no mark, the marks' share goes to the body (%.1f)" % out["body"])
	# The Unbound: everything but the crystals pools raw.
	await t._ub_fresh()
	prof = t.main.profile
	var U = load("res://scripts/unbound.gd")
	var raw0: float = U.raw(prof, "legs")
	out = prof.pour({"air": 50.0}, {}, 0.3)
	_check(is_equal_approx(U.raw(prof, "legs") - raw0, 35.0) and prof.crystal_total("air") >= 15.0, "the Unbound: everything but the crystals pools raw in its part (%.1f)" % (U.raw(prof, "legs") - raw0))


func _stair_line() -> void:
	await _fresh()
	var main = t.main
	var keep = M.settings["condense"]
	M.settings["condense"] = Train.CONDENSE_DEFAULT
	main.floor_num = 2
	main.run_essence = {"air": 50.0}
	main.run_soak = {"heart": 4.0}
	main._arrive()
	await t._frames(2)
	var want: String = Flow.TEXT["split"] % [50, 15, 20, 15]
	var lines: Array = main.banner.get("lines", [])
	_check(lines.has(want), "the stair's line shows the three shares: \"%s\" (%s)" % [want, lines])
	_check(main.profile.crystal_total("air") == 15.0, "...and the crystals' share is there in your crystals")
	M.settings["condense"] = "0"
	main.floor_num = 4
	main.run_essence = {"air": 70.0}
	main._arrive()
	await t._frames(2)
	_check((main.banner.get("lines", []) as Array).has(Flow.TEXT["split"] % [70, 30, 40, 0]), "To crystals at 0%%: body and marks share it all (%s)" % [main.banner.get("lines", [])])
	M.settings["condense"] = keep


# --- slower than before -------------------------------------------------------------------

## The old way (before the split): 20% condensed, and every mark took all of
## the rest, own kind x AFFINITY_WEIGHT, others x OTHER_WEIGHT.
func _old_xp(essence: Dictionary, affinity: String, drag: float) -> float:
	var gain := 0.0
	for k in essence:
		var kept := float(essence[k]) - floorf(float(essence[k]) * 0.2)
		gain += kept * (PS.AFFINITY_WEIGHT if k == affinity else PS.OTHER_WEIGHT)
	return gain * PS.STEP_RATE * drag


func _slower() -> void:
	await _fresh(false)
	var main = t.main
	var prof = main.profile
	prof.add_bond("hand", "stormcaller", false)
	prof.regarded = true
	main.first_climb = false
	var climb := {"air": 440.0, "iron": 70.0, "water": 40.0}  # (a six-floor climb in the Gryphon's tower, about)
	var old := _old_xp(climb, "air", prof.body_drag())
	prof.pour(climb, {"hand": 3.0, "legs": 1.0}, Flow.default_crystal_share())
	var now := float(prof.bonds["hand"]["xp"])
	_check(now > 0.0 and now < old * 0.7, "the same essence grows a mark clearly slower than before (%.0f now, %.0f before)" % [now, old])
	print("    (a climb of %d essence: a mark grows %.0f, was %.0f; step 2 needs %d)" % [int(_sum(climb)), now, old, int(PS.STEP_XP[1])])
	# Two marks of different kinds no longer each take everything.
	prof.add_bond("legs", "tidecaller", false)
	prof.bonds["hand"]["xp"] = 0.0
	prof.pour(climb, {}, Flow.default_crystal_share())
	var water := float(prof.bonds["legs"]["xp"])
	var air := float(prof.bonds["hand"]["xp"])
	_check(air > water * 4.0, "a mark grows mostly from its own kind: Air for Stormcaller (%.0f), little for Tidecaller (%.0f)" % [air, water])


# --- eating a crystal ----------------------------------------------------------------------

func _eat() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	prof.add_crystal("air", 25.0)
	var xp0 := float(prof.bonds["hand"]["xp"])
	var lines: Array = main.consume_crystal("air")
	var step := float(Items.CRYSTAL["step"])
	_check(prof.crystal_total("air") == 25.0 - step, "eating takes %d from the crystal" % int(step))
	_check(not lines.is_empty() and String(lines[0]) == Flow.TEXT["ate"] % [int(step), "air", int(round(step * 3.0 / 7.0)), int(round(step * 4.0 / 7.0))],
		"it says where it went: %s" % [lines])
	_check(is_equal_approx(_sum(prof.density), step * 3.0 / 7.0), "the natural way: the body's share settles (%.2f)" % _sum(prof.density))
	_check(float(prof.bonds["hand"]["xp"]) > xp0, "...and the marks' share grows the marks")
	_check(prof.crystals_held() == 25.0 - step, "none of it condenses again (no crystal share)")
	_check(float(prof.soak.get("heart", 0.0)) > 0.0 and is_equal_approx(float(prof.soak.get("heart", 0.0)), float(prof.soak.get("back", 0.0))),
		"with nothing done, it soaks into the body evenly (no steering): %s" % prof.soak)


# --- tinctures ------------------------------------------------------------------------------

func _tinctures() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	_check(Flow.tinctures().size() == 6 and Flow.tinctures().all(func(id): return Items.ITEMS.has(id) and id in Items.ORDER and Items.ITEMS[id].get("tincture", false)),
		"a tincture of each kind is an item (belt-able)")
	_check(not Flow.tinctures().any(func(id): return id in [Items.random_item(true, [], true), Items.random_item(true)]), "the item table never hands one out")
	p.items["tincture_air"] = 2
	var hand0 := float(prof.bonds["hand"]["xp"])
	var legs0 := float(prof.bonds["legs"]["xp"])
	var lines: Array = main.drink_tincture("tincture_air", "legs")
	var want: float = float(Flow.TINCTURE["essence"]) * PS.AFFINITY_WEIGHT * float(Flow.TINCTURE["mark_boost"]) * PS.STEP_RATE * prof.body_drag()  # (concentrated: "mark_boost")
	_check(absf(float(prof.bonds["legs"]["xp"]) - legs0 - want) < 0.01 and float(prof.bonds["hand"]["xp"]) == hand0,
		"a tincture goes only to the chosen mark, its own kind counting fully (+%.1f; the other mark +%.1f)" % [float(prof.bonds["legs"]["xp"]) - legs0, float(prof.bonds["hand"]["xp"]) - hand0])
	_check(prof.soak.is_empty() and prof.density.is_empty() and p.item_count("tincture_air") == 1, "...nothing else gets any, and one is used up")
	_check(not lines.is_empty() and String(lines[0]).begins_with("Air Tincture"), "it says what it did: %s" % [lines])
	p.items["tincture_fire"] = 1
	hand0 = float(prof.bonds["hand"]["xp"])
	main.drink_tincture("tincture_fire", "hand")
	var other: float = float(Flow.TINCTURE["essence"]) * PS.OTHER_WEIGHT * float(Flow.TINCTURE["mark_boost"]) * PS.STEP_RATE * prof.body_drag()
	_check(absf(float(prof.bonds["hand"]["xp"]) - hand0 - other) < 0.01, "another kind counts only a little in a mark (+%.2f)" % (float(prof.bonds["hand"]["xp"]) - hand0))
	_check(main.drink_tincture("tincture_fire", "hand").is_empty(), "none left: nothing happens")
	p.items["tincture_stone"] = 1
	hand0 = float(prof.bonds["hand"]["xp"])
	main.drink_tincture("tincture_stone", "back")
	_check(float(prof.soak.get("back", 0.0)) > 0.0 and prof.soak.size() == 1 and float(prof.bonds["hand"]["xp"]) == hand0, "into an unmarked part: only its soak, toward a new mark (%s)" % prof.soak)
	_check(float(prof.tally.get("stone", 0.0)) == float(Flow.TINCTURE["essence"]), "...and it leans the next mark toward its kind")
	# A faint mark pays its debt first.
	prof.bonds["hand"]["faint"] = true
	prof.bonds["hand"]["debt"] = 500.0
	p.items["tincture_air"] = 1
	hand0 = float(prof.bonds["hand"]["xp"])
	main.drink_tincture("tincture_air", "hand")
	_check(float(prof.bonds["hand"]["xp"]) == hand0 and float(prof.bonds["hand"]["debt"]) < 500.0, "a faint mark pays down its debt first")
	prof.bonds["hand"]["faint"] = false
	prof.bonds["hand"]["debt"] = 0.0


func _found_bought_crafted() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	# Crafted at the Workshop.
	prof.add_crystal("fire", 100.0)
	var cost: Dictionary = Bench.tincture_cost(prof, "tincture_fire")
	_check(cost == {"fire": int(Flow.TINCTURE["craft"])}, "crafting one costs crystals of its kind (%s)" % cost)
	_check(Bench.craft_tincture(prof, p, "tincture_fire") == "" and int(prof.supplies.get("tincture_fire", 0)) == 1 and prof.crystal_total("fire") == 100.0 - float(cost["fire"]),
		"the Workshop crafts a tincture, packed for your next climb")
	_check(Bench.COUNTERS.any(func(c): return c[0] == "tincture") and not Bench.brews().any(func(id): return Flow.is_tincture(id)), "it has its own counter (not Brew's)")
	# Bought at the outfitter.
	prof.store = {}
	Train.stock(prof)
	var sold: Array = Train.supplies(prof).filter(func(id): return Flow.is_tincture(id))
	_check(sold.size() == int(Flow.TINCTURE["store_kinds"]) and not Train.supplies().any(func(id): return Flow.is_tincture(id)), "the outfitter stocks %d kinds of tincture this visit (%s)" % [sold.size(), sold])
	var id: String = sold[0]
	var price: Array = Train.supply_price(prof, id)
	prof.add_crystal(String(price[0]), float(price[1]))
	_check(Train.buy_supply(prof, p, id) == "" and int(prof.supplies.get(id, 0)) >= 1, "and sells one for %s" % Train.price_text(price[0], price[1]))
	# Found: a vault's card, a hidden cache, a monster's drop.
	var W = main.wings
	var keep_v := float(Flow.TINCTURE["vault_chance"])
	Flow.TINCTURE["vault_chance"] = 1000.0
	var vault: Array = W.vault_choices(false)
	Flow.TINCTURE["vault_chance"] = keep_v
	_check(vault.any(func(c): return Flow.is_tincture(String(c))), "a vault can offer a tincture (%s)" % [vault])
	var keep_h := float(Flow.TINCTURE["hidden_chance"])
	Flow.TINCTURE["hidden_chance"] = 1.0
	var hidden: Array = W.hidden_crystals()
	Flow.TINCTURE["hidden_chance"] = keep_h
	_check(Flow.is_tincture(String(hidden[2])), "a hidden cache can hold one (%s)" % [hidden])
	var keep_e := float(Items.DROPS["essence_chance"])
	Items.DROPS["essence_chance"] = 0.0  # (the drop table: no item, no essence, then the tincture's chance)
	_check(Items.kill_drop(5, true, "", 0.0, 1.0).has("tincture") and Items.kill_drop(5, true, "", 0.0, 0.0).is_empty() and float(Items.DROPS.get("tincture_chance", 0.0)) > 0.0,
		"the kill drop table holds the tincture's chance (DROPS tincture_chance)")
	_check(not Items.ITEMS["tincture_fire"].has("scale"), "tinctures come in one size, as every item does")
	main.tincture_drop_chance = 1.0
	main.item_drop_chance = 0.0
	main.gear_drop_chance = 0.0
	main.item_drops.clear()
	main.spawn_enemy("slime", p.global_position + Vector2(140, 0))
	await t._frames(2)
	for e in main.enemies():
		t._slay(e)
	await t._frames(3)
	_check(main.item_drops.any(func(d): return String(d["id"]) == "tincture_water"), "a slain monster can leave one of its essence (%s)" % [main.item_drops.map(func(d): return d["id"])])
	main.tincture_drop_chance = -1.0
	Items.DROPS["essence_chance"] = keep_e
	# A tincture left on the belt comes home packed.
	prof.supplies = {}
	p.items["tincture_iron"] = 2
	main.belt_broken = false
	main.break_belt()
	_check(int(prof.supplies.get("tincture_iron", 0)) == 2 and p.item_count("tincture_iron") == 0, "a tincture left on the belt comes home packed, not broken into crystals")
	var held: float = prof.crystals_held()
	_check(Train.put_back(prof, "tincture_iron") and prof.crystals_held() == held, "(a found one put back gives nothing for it)")


func _belt_and_page() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	p.items["tincture_blade"] = 1
	p.item_sel = "tincture_blade"
	p.use_item()
	await t._frames(3)
	_check(menu.page == "pour" and p.item_count("tincture_blade") == 1, "using a tincture from the belt asks where it goes (the crystals page), nothing used yet")
	var target: Button = null
	var seen := 0
	for b in menu.focusables():
		if b.has_meta("pour_part"):
			seen += 1
			if b.get_meta("pour_part") == "heart":
				target = b
	_check(seen == 6 and target != null, "its card lists all six body parts (%d; %s, %s)" % [seen, menu.inv_sel, menu.focusables().map(func(b): return b.get_meta("help", b.get_meta("slot", "?")))])
	var lacking: Array = menu.focusables().filter(func(b): return Help.missing(b)).map(func(b): return Help.words(b))
	_check(lacking.is_empty(), "every button on the page has the Entity's words (lacking: %s)" % [lacking])
	target.pressed.emit()
	await t._frames(3)
	_check(p.item_count("tincture_blade") == 0 and float(prof.soak.get("heart", 0.0)) > 0.0, "choosing the heart drinks it there")
	_check(menu.toast != "" and menu.page == "pour", "the page says what it did")
	menu.go_back()
	await t._frames(2)
	_check(menu.page == "", "Back returns to the climb")
	# The Inventory's crystal still eats.
	prof.add_crystal("water", 20.0)
	menu.open("climber", true)
	menu._set_climber_tab("essence")
	await t._frames(2)
	var open_b: Button = null
	for b in menu.focusables():
		if b.get_meta("help", "") == "pour:open":
			open_b = b
	_check(open_b != null, "the book's Essence ribbon opens Crystals and tinctures")
	if open_b != null:
		open_b.pressed.emit()
		await t._frames(2)
		menu._show_details("crystal:water")
		await t._frames(1)
		var eat: Button = null
		for b in menu.focusables():
			if b.get_meta("help", "") == "pour:eat":
				eat = b
		_check(eat != null, "a crystal's card has Eat")
		if eat != null:
			eat.pressed.emit()
			await t._frames(2)
			_check(prof.crystal_total("water") == 20.0 - float(Items.CRYSTAL["step"]), "Eat eats it")
		menu.go_back()
		await t._frames(2)
		_check(menu.page == "climber", "Back returns to the book")
	menu.close()
	await t._frames(2)


func _train_page() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	prof.add_crystal("air", 200.0)
	main.open_train()
	await t._frames(3)
	menu.train_car = "workshop"
	menu.train_bench = "tincture"
	menu.inv_sel = "bench:tincture:tincture_air"
	menu.train_sel["workshop"] = menu.inv_sel
	menu.open("train")
	await t._frames(3)
	var craft: Button = null
	for b in menu.focusables():
		if b.get_meta("help", "") == "tincture_craft":
			craft = b
	_check(craft != null and not craft.disabled, "the Workshop's tincture counter has Craft")
	if craft != null:
		craft.pressed.emit()
		await t._frames(3)
	_check(int(prof.supplies.get("tincture_air", 0)) == 1, "...which crafts one")
	var drink: Button = null
	for b in menu.focusables():
		if b.get_meta("help", "") == "tincture_drink":
			drink = b
	_check(drink != null, "a packed tincture can be drunk from there")
	if drink != null:
		drink.pressed.emit()
		await t._frames(3)
		_check(menu.page == "pour" and menu.inv_sel == "tincture:tincture_air", "...on the crystals page, its card first")
		var xp0 := float(prof.bonds["legs"]["xp"])
		for b in menu.focusables():
			if b.get_meta("pour_part", "") == "legs":
				b.pressed.emit()
				break
		await t._frames(3)
		_check(int(prof.supplies.get("tincture_air", 0)) == 0 and float(prof.bonds["legs"]["xp"]) > xp0, "drunk on the train, from what's packed, into the chosen mark")
		for i in 2:  # (from the card, Back first goes to its slot)
			if menu.page == "pour":
				menu.go_back()
				await t._frames(2)
		_check(menu.page == "train" and menu.train_bench == "tincture", "Back returns to the Workshop")
	menu.close()
	main.on_train = false
	await t._frames(2)


func _entity() -> void:
	await _fresh()
	var main = t.main
	var E = load("res://scripts/entity.gd")
	for id in ["bank", "split", "crystal_eat", "tincture", "earned_mark", "wing_watch", "maker_mark", "fall_mark"]:
		_check(E.TIPS.has(id), "the Entity has a tip for %s" % id)
	for id in ["split", "crystal_eat", "tincture", "earned_mark", "wing_watch", "maker_mark", "fall_mark"]:
		var text := (String(E.TIPS[id]["tip"]) + " " + String(E.TIPS[id]["more"])).to_lower()
		_check(not BANNED.any(func(w): return text.contains(w)), "no banned words in the %s tip" % id)
	# Once each: tell() says it the first time only.
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	_check(Guide.tell("tincture") != "" and Guide.tell("tincture") == "", "the first tincture's line is said once")
	_check(Guide.tell("crystal_eat") != "" and Guide.tell("crystal_eat") == "", "the first crystal eaten's line is said once")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	# The talk: the new topics, with live numbers.
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check(how.has("how_essence") and Talk.DIALOGUE["how_essence"]["choices"].has("how_flow") and Talk.DIALOGUE["how_essence"]["choices"].has("how_tinctures") and how.has("how_new_mark") and String(Talk.DIALOGUE["how_new_mark"]["ask"]) == "How do I earn a new mark?",
		"the Entity can say how essence flows, what tinctures are and how to earn a new mark")
	var flow_line: String = Talk.line_for(main, "how_flow")
	var sh: Dictionary = Flow.shares(Train.condense_share(M.settings))
	_check(flow_line.contains("%d%%" % int(round(float(sh["body"]) * 100.0))) and flow_line.contains("%d%%" % int(round(float(sh["marks"]) * 100.0))) and not flow_line.contains("{"),
		"its numbers come from the tables: %s" % flow_line)
	var earn: String = Talk.line_for(main, "how_new_mark")
	_check(earn.contains("floor %d" % int(Flow.EARNED["last_floor"])) and earn.contains("%d%%" % int(round(float(Flow.FALL_MARK["chance"]) * 100.0))), "how to earn a mark: %s" % earn)
	var tinct: String = Talk.line_for(main, "how_tinctures")
	_check(tinct.contains(str(int(Flow.TINCTURE["essence"]))) and tinct.contains(str(int(Flow.TINCTURE["craft"]))), "what tinctures are: %s" % tinct)
	for id in ["how_essence", "how_flow", "how_marks", "how_new_mark", "how_tinctures", "marks_grow", "train_money"]:
		var l: String = Talk.line_for(main, id).to_lower()
		_check(not BANNED.any(func(w): return l.contains(w)) and not l.contains("{"), "%s reads whole" % id)


func _old_saves() -> void:
	# Settings saved before the split, at the old default: the new default, once.
	var path := "user://test_old_settings.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "condense", "20")
	cfg.save(path)
	var keep = M.settings.duplicate()
	M.load_settings_from(path)
	_check(M.settings["condense"] == "30", "settings from before the split, at the old 20%%, move to the new default (%s)" % M.settings["condense"])
	cfg.set_value("settings", "condense", "20")
	cfg.set_value("settings", "split", true)
	cfg.save(path)
	M.load_settings_from(path)
	_check(M.settings["condense"] == "20", "a 20% chosen since stays 20%")
	cfg.set_value("settings", "condense", "35")
	cfg.erase_section_key("settings", "split")
	cfg.save(path)
	M.load_settings_from(path)
	_check(M.settings["condense"] == "30", "an old 35% (no longer a choice) loads as the default")
	for k in keep:
		M.settings[k] = keep[k]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A climber saved before the split loads, its marks and soak as they were.
	var prof = PS.new()
	prof.save_path = "user://test_old_profile.cfg"
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "bonds", {"hand": {"id": "stormcaller", "xp": 300.0, "faint": false, "debt": 0.0}})
	old.set_value("profile", "soak", {"back": 120.0})
	old.set_value("profile", "crystals", [{"kind": "air", "amount": 40.0}])
	old.set_value("train", "store", {"outfit": [], "today": ""})
	old.save(prof.save_path)
	prof.load_save()
	_check(float(prof.bonds["hand"]["xp"]) == 300.0 and float(prof.soak["back"]) == 120.0 and prof.crystal_total("air") == 40.0, "an old climber loads with its marks, soak and crystals")
	_check(Train.store_tinctures(prof).size() == int(Flow.TINCTURE["store_kinds"]), "an old store stocks its tinctures when first opened")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prof.save_path))
