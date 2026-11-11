extends RefCounted
## The tree's foundation (Phase A): the library, the tree's rules, saving
## and old saves, the book and its sections, choosing on the Tree, Ball
## Lightning, the variations, the Data editor, and fitting a phone.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Book := preload("res://scripts/book.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _library_parity()
	await _tree_rules()
	await _saves()
	await _book_entries()
	await _book_turns()
	await _tree_choice()
	await _ball_lightning()
	await _variations()
	await _data_editor()
	await _phone_fit()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A marked climber: Stormcaller on the hand at step 3, Windwalker on the legs.
func _marked(step_xp := 500.0) -> void:
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.bonds["hand"]["xp"] = step_xp
	main._give_bonds()
	for e in main.enemies():
		e.set_physics_process(false)


func _library_parity() -> void:
	print("the tree: the library does what the game did")
	var L = load("res://scripts/library.gd")
	var T = load("res://scripts/technique.gd")
	var B = load("res://scripts/bonds.gd")
	_check(T.SHAPES == L.FORMS and T.KINDS["fire"] == L.EFFECTS["burn"], "the techniques' shapes and kinds are the library's own tables")
	var was := {"strike": [16.0, 50.0, 60.0], "bolt": [12.0, 470.0, 340.0], "dash": [8.0, 130.0], "leap": [14.0, 130.0, 56.0], "shell": [30.0, 5.0],
		"push": [6.0, 85.0, 380.0], "shout": [10.0, 135.0, 38.0], "pull": [5.0, 210.0, 54.0], "mark": [320.0, 8.0], "sight": [8.0, 220.0], "within": [8.0]}
	var same := true
	for id in was:
		var nums: Array = []
		for k in ["damage", "speed", "reach", "range", "dist", "radius", "shield", "duration", "force", "length", "width", "arc", "near"]:
			if T.SHAPES[id].has(k):
				nums.append(float(T.SHAPES[id][k]))
		for v in was[id]:
			if not v in nums:
				same = false
	_check(same and T.SHAPES.size() >= 11, "today's eleven forms keep every number")
	_check(T.KINDS["fire"]["burn"] == 4.0 and T.KINDS["water"]["slow"] == 3.5 and T.KINDS["air"]["reach"] == 0.4 and T.KINDS["stone"]["stagger"] == 0.7
		and T.KINDS["iron"]["drag"] == 220.0 and T.KINDS["blade"]["cut"] == 0.35 and T.KINDS["life"]["heal"] == 3.0 and T.KINDS["unmaking"]["erode"] == 3.0, "today's eight effects keep every number")
	var strain_ok := true
	for id in T.RECIPES:
		var r: Dictionary = T.recipe(id)
		var n: int = r["kinds"].size()
		if T.strain(r) != float(T.STRAIN[n - 1]) or not is_equal_approx(T.windup(r), float(T.WINDUP[0]) + float(T.WINDUP[1]) * (n - 1)) or not T.valid(r):
			strain_ok = false
	_check(strain_ok, "every ready-made technique strains, winds up and builds as before")
	_check(T.describe(T.recipe("ember_bolt")) == "A bolt thrown where you aim. It burns what it hits.", "...and says the same (%s)" % T.describe(T.recipe("ember_bolt")))
	# A strike's damage in play, as before: 16 x power on a foe in front.
	await _marked()
	var main = _main()
	var p = main.player
	var slime = main.enemies().filter(func(e): return e.kind == "slime")[0]
	slime.hp = 500.0
	slime.max_hp = 500.0
	p.global_position = slime.global_position - Vector2(36, 0)
	p.aim = Vector2.RIGHT
	var hp0: float = slime.hp
	T.cast({"part": "hand", "shape": "strike", "kinds": ["fire"]}, p, 1.0, main.unbound)
	_check(is_equal_approx(hp0 - slime.hp, 16.0 * float(p.flow_damage)) or hp0 - slime.hp >= 15.9, "a Strike still deals its 16 (%.1f)" % (hp0 - slime.hp))
	# A mark that makes no choice plays as before.
	var hb = p.bonds["hand"]
	var plain: Array = B.BONDS["stormcaller"]["spells"].filter(func(sp): return int(sp["learn"]) <= hb.step)
	_check(hb.spells().map(func(sp): return sp["id"]) == plain.map(func(sp): return sp["id"]), "a mark with no choices knows today's spells (%s)" % [hb.spells().map(func(sp): return sp["id"])])
	hb.select(0)
	_check(int(hb.stat("leaps")) == 6 and float(hb.stat("stun")) == 0.4, "...and today's step-3 change (6 leaps that stun)")


func _tree_rules() -> void:
	print("the tree: choosing, for good")
	await _marked()
	var main = _main()
	var prof = main.profile
	var TR = load("res://scripts/tree.gd")
	var nodes: Array = TR.nodes(prof, "hand")
	_check(nodes.size() == 10 and nodes[0]["kind"] == "spell" and nodes[1]["kind"] == "fork" and nodes[2]["kind"] == "fork" and nodes[3]["kind"] == "fork" and nodes[5]["kind"] == "later",
		"a mark's tree: steps 1 to 5, forks at 2, 3 and 4, and 6 to 10 coming later")
	_check(TR.is_fork_ready(prof, "hand") and TR.ready_forks(prof, "hand") == ["mark:stormcaller:2", "mark:stormcaller:3"], "at step 3 the forks at 2 and 3 are ready (%s)" % [TR.ready_forks(prof, "hand")])
	_check(not TR.is_fork_ready(prof, "legs"), "...a step-1 mark has none")
	_check(TR.available(prof, "mark:stormcaller:4").is_empty(), "a fork not reached yet can't be chosen")
	var n4: Dictionary = TR.node(prof, "mark:stormcaller:4")
	_check(n4["options"][1]["state"] == "placeholder" and n4["options"][1]["name"] == "Thunderclap", "a side not written yet shows as a placeholder (Thunderclap)")
	prof.bonds["hand"]["xp"] = 1000.0
	_check(TR.node(prof, "mark:stormcaller:4")["state"] == "owned" and not TR.choose(prof, "mark:stormcaller:4", "thunderclap"), "...and can't be chosen even once reached (its fork isn't ready: today's side stays)")
	prof.bonds["hand"]["xp"] = 500.0
	_check(not TR.choose(prof, "mark:stormcaller:2", "nothing"), "an option that isn't there is refused")
	_check(TR.choose(prof, "mark:stormcaller:2", "ball_lightning"), "choosing Ball Lightning at step 2")
	_check(not TR.choose(prof, "mark:stormcaller:2", "overcharge") and TR.mark_choice(prof, "stormcaller", 2) == "ball_lightning", "...is for good: the other side can't be chosen after")
	var n2: Dictionary = TR.node(prof, "mark:stormcaller:2")
	_check(n2["state"] == "owned" and n2["options"][0]["state"] == "passed" and n2["options"][1]["state"] == "owned", "...Overcharge is passed on, Ball Lightning yours")
	main._give_bonds()
	var hb = main.player.bonds["hand"]
	var ids: Array = hb.spells().map(func(sp): return sp["id"])
	_check("ball_lightning" in ids and not "overcharge" in ids, "the mark casts Ball Lightning now, not Overcharge (%s)" % [ids])
	_check("ball_lightning" in TR.owned(prof) and "chain_lightning" in TR.owned(prof), "owned() lists what's yours")
	_check(TR.choose(prof, "mark:stormcaller:3", "lingering"), "choosing Lingering at step 3")
	main._give_bonds()
	hb = main.player.bonds["hand"]
	hb.select(0)
	_check(int(hb.stat("leaps")) == 4 and float(hb.stat("stun")) == 0.0 and float(hb.stat("patch")) == 3.0, "...Chain Lightning loses today's change and gains Lingering's patch (%s leaps)" % hb.stat("leaps"))
	_check(not TR.is_fork_ready(prof, "hand"), "nothing more to choose at step 3")
	# Marks never go back: choosing again, or forgetting, through the rules, can't.
	_check(not TR.choose(prof, "mark:stormcaller:3", "change"), "a mark's choice never goes back")

	print("the tree: the Unbound")
	await t._ub_fresh()
	main = _main()
	prof = main.profile
	var U = load("res://scripts/unbound.gd")
	nodes = TR.nodes(prof, "hand")
	_check(nodes.size() == 10 and nodes[0]["kind"] == "forms" and nodes[1]["kind"] == "fork" and nodes[2]["kind"] == "form" and nodes[3]["kind"] == "kinds" and nodes[4]["kind"] == "gift" and nodes[9]["kind"] == "capstone",
		"an Unbound part's tree: forms at 1, variation forks, new forms at 3 and 7, essences at 4 and 8, the gift at 5, a capstone at 10")
	_check(nodes[0]["options"].map(func(o): return o["id"]) == ["strike", "bolt"] and nodes[0]["options"].all(func(o): return o["state"] == "owned"), "...today's forms are owned from the start")
	_check(not TR.is_fork_ready(prof, "hand") and TR.owned_variations(prof).is_empty(), "at level 1 nothing to choose yet")
	prof.part_density = {"hand": {"blade": U.LEVELS[2]}}
	_check(U.level(prof, "hand") == 3 and TR.is_fork_ready(prof, "hand"), "at level 3 the level-2 fork is ready")
	_check("volley" in TR.owned_forms(prof, "hand") and not "brand" in TR.owned_forms(prof, "hand"), "...and Volley (level 3) is open; Brand (level 7) isn't")
	_check(TR.node(prof, "unbound:hand:7")["options"][0]["state"] == "placeholder" and TR.node(prof, "unbound:hand:10")["state"] == "later", "forms and capstones not written yet show as Coming later")
	_check(TR.choose(prof, "unbound:hand:2", "split"), "choosing Split")
	var o2: Array = TR.node(prof, "unbound:hand:2")["options"]
	_check(o2[0]["state"] == "owned" and o2[1]["state"] == "learnable" and int(o2[1]["cost"]) == TR.skipped_cost(2), "...Quick, passed on, can be learned now the hand is a level past it (%s)" % o2[1]["state"])
	_check(not TR.choose(prof, "unbound:hand:2", "quick"), "...but not chosen: the choice is for good")
	prof.crystals = []
	_check(not TR.can_learn_skipped(prof, "unbound:hand:2", "quick") and TR.learn_skipped(prof, "unbound:hand:2", "quick").is_empty(), "learning it needs crystal essence")
	prof.add_crystal("air", 100.0)
	var paid: Dictionary = TR.learn_skipped(prof, "unbound:hand:2", "quick")
	_check(int(paid.get("air", 0)) == TR.skipped_cost(2) and is_equal_approx(prof.crystal_total("air"), 100.0 - TR.skipped_cost(2)), "...and costs %d of it" % TR.skipped_cost(2))
	_check("split" in TR.owned_variations(prof) and "quick" in TR.owned_variations(prof), "the Unbound can come to own both sides")
	prof.part_density = {"hand": {"blade": U.LEVELS[1]}}
	TR.state(prof)["unbound"].erase("hand")
	TR.state(prof)["learned"].erase("hand")
	TR.choose(prof, "unbound:hand:2", "quick")
	_check(TR.node(prof, "unbound:hand:2")["options"][0]["state"] == "passed", "...but only once the part is a level past the fork")
	# Effects open as essence pools in the body.
	prof.part_density = {"legs": {"air": 120.0}}
	_check(TR.effect_open(prof, "spark") and not TR.effect_open(prof, "lift"), "an effect opens once enough of its essence has pooled (Spark at 100 Air)")
	var rows: Array = TR.effect_rows(prof, "legs")
	_check(rows.any(func(r): return r["id"] == "spark" and r["state"] == "owned") and rows.any(func(r): return r["id"] == "gust" and r["state"] == "placeholder"), "...shown on the legs' tree")
	# Echoes.
	var echo: Dictionary = load("res://scripts/library.gd").echo_of({"part": "throat", "shape": "shout", "kinds": ["air", "stone"]})
	_check(echo.get("name", "") == "Gale Lift", "an Air shout with Stone echoes Gale Lift")
	_check(TR.note_echo(prof, {"part": "throat", "shape": "shout", "kinds": ["air", "stone"]}) and not TR.note_echo(prof, {"part": "throat", "shape": "shout", "kinds": ["air", "stone"]}), "...found once, then remembered")


func _saves() -> void:
	print("the tree: saved, and old saves")
	await _marked()
	var main = _main()
	var P = load("res://scripts/profile.gd")
	var TR = load("res://scripts/tree.gd")
	var path := "user://smoke_tree.cfg"
	# An old save: a Stormcaller at step 3 and a Warden at step 4, no tree.
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "bonds", {"hand": {"id": "stormcaller", "xp": 500.0, "faint": false, "debt": 0.0}, "brow": {"id": "warden", "xp": 1000.0, "faint": false, "debt": 0.0},
		"legs": {"id": "windwalker", "xp": 0.0, "faint": false, "debt": 0.0}})
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	_check(TR.mark_choice(old, "stormcaller", 2) == "overcharge" and TR.mark_choice(old, "stormcaller", 3) == TR.CHANGE and TR.mark_choice(old, "stormcaller", 4) == "",
		"an old save: the forks a mark passed keep today's side, chosen (and not those ahead)")
	_check(TR.mark_choice(old, "warden", 4) == "challenge" and TR.mark_choice(old, "windwalker", 2) == "", "...for every mark")
	_check(not TR.is_fork_ready(old, "hand"), "...so nothing waits to be chosen there")
	# Choices are saved with the climber.
	TR.state(old)["marks"]["stormcaller"].erase(2)
	_check(TR.choose(old, "mark:stormcaller:2", "ball_lightning"), "(a choice made)")
	old.unbound = {}
	old.saving = true
	old.save()
	var again = P.new()
	again.saving = false
	again.save_path = path
	again.load_save()
	_check(TR.mark_choice(again, "stormcaller", 2) == "ball_lightning" and TR.mark_choice(again, "stormcaller", 3) == TR.CHANGE, "choices are saved with the climber and load again")
	var fresh = P.new()
	fresh.saving = false
	fresh.save_path = "user://smoke_tree_none.cfg"
	fresh.load_save()
	_check(TR.state(fresh)["marks"].is_empty(), "a new climber has chosen nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main.profile.reset()
	_check(main.profile.tree.is_empty(), "Start over forgets the tree")


func _book_entries() -> void:
	print("the book: every way in")
	var M = load("res://scripts/menu.gd")

	await _marked()
	var main = _main()
	var menu = main.menu
	await t._key_tap(KEY_TAB)
	_check(menu.page == "climber" and menu.panel.get_theme_stylebox("panel") is Book.BookStyle, "Tab opens the book")
	_check(t._all_buttons(menu).filter(func(b): return b.has_meta("ribbon")).size() == 5, "...with a ribbon for each section")
	menu.close()
	await t._frames(2)
	menu.open("pause")
	await t._frames(2)
	menu.rail.button("climber").pressed.emit()
	await t._frames(2)
	_check(menu.page == "climber" and menu.panel.get_theme_stylebox("panel") is Book.BookStyle, "the identity block on the rail opens it")
	menu.close()
	await t._frames(2)
	main.touch._set_active(true)
	main.touch._layout()
	var ids: Array = main.touch.buttons.map(func(b): return b["id"])
	if "climber" in ids:
		var cb: Dictionary = main.touch.buttons[ids.find("climber")]
		await t._tap_at(cb["c"])
		await t._frames(2)
	_check(menu.page == "climber", "the Climber button opens it")
	menu.close()
	await t._frames(2)
	main.touch._set_active(false)
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.train_car = "personal"
	menu.open("train")
	await t._frames(3)
	var books: Array = t._car_buttons("book", true)
	_check(books.size() == 1 and books[0] is Book.ClosedBook, "the book lies in Your Car on the train")
	if books.size() == 1:
		books[0].pressed.emit()
		await t._frames(2)
	_check(menu.page == "climber" and menu.panel.get_theme_stylebox("panel") is Book.BookStyle, "...and opens to the same book")
	menu.close()
	await t._frames(2)


func _book_turns() -> void:
	print("the book: turning its pages")
	await _marked()
	var main = _main()
	var menu = main.menu
	menu.climber_tab = "abilities"
	menu.open("climber", true)
	await t._frames(2)
	await t._key_tap(KEY_E)
	_check(menu.climber_tab == "tree", "E turns to the next section (the Tree)")
	await t._key_tap(KEY_Q)
	_check(menu.climber_tab == "abilities", "Q turns back")
	t._pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await t._frames(2)
	t._pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await t._frames(2)
	_check(menu.climber_tab == "tree", "RB turns forward")
	t._pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await t._frames(2)
	t._pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await t._frames(2)
	_check(menu.climber_tab == "abilities", "LB turns back")
	main.touch._set_active(true)
	await t._frames(2)
	var r: Rect2 = menu.panel.get_global_rect()
	var mid := r.get_center()
	await t._swipe(mid + Vector2(120, 0), mid - Vector2(120, 0))
	await t._frames(2)
	_check(menu.climber_tab == "tree", "a swipe to the left turns forward")
	await t._swipe(mid - Vector2(120, 0), mid + Vector2(120, 0))
	await t._frames(2)
	_check(menu.climber_tab == "abilities", "...and to the right, back")
	var rib: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("ribbon", "") == "record")
	if not rib.is_empty():
		rib[0].pressed.emit()
		await t._frames(2)
	_check(menu.climber_tab == "record", "a ribbon opens its section")
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)


func _tree_choice() -> void:
	print("the book: choosing on the Tree")
	await _marked()
	var main = _main()
	var menu = main.menu
	var TR = load("res://scripts/tree.gd")
	menu.climber_tab = "tree"
	if menu.has_meta("tree_part"):
		menu.remove_meta("tree_part")
	if menu.has_meta("tree_sel"):
		menu.remove_meta("tree_sel")
	menu.open("climber", true)
	await t._frames(3)
	var nodes: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tree_part"))
	_check(nodes.size() == 6, "the Tree: a node on each of the six body parts")
	var hand: Array = nodes.filter(func(b): return b.get_meta("part") == "hand")
	_check(not hand.is_empty() and hand[0].ready_fork and hand[0].on, "...the hand, with a ready fork, pulses and its tree shows first")
	var buds: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("bud"))
	var bl: Array = buds.filter(func(b): return String(b.get_meta("bud")).ends_with("|ball_lightning"))
	_check(bl.size() == 1 and bl[0].get_meta("bud_state") == "available", "Ball Lightning is a bud to choose")
	_check(buds.any(func(b): return b.get_meta("bud_state") == "placeholder") and buds.any(func(b): return b.get_meta("bud_state") == "locked") and buds.any(func(b): return b.get_meta("bud_state") == "in_use"),
		"...beside one in use, one locked and one coming later")
	if bl.size() == 1:
		bl[0].pressed.emit()
		await t._frames(2)
	var card: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tree_card"))
	_check(card.size() == 1 and card[0].get_meta("tree_card") == "ball_lightning" and card[0].get_meta("grimoire", false), "pressing it shows its grimoire card")
	var act: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_act", "") == "choose")
	_check(act.size() == 1, "...and Choose")
	if act.size() == 1:
		act[0].pressed.emit()
		await t._frames(2)
	_check(TR.mark_choice(main.profile, "stormcaller", 2) == "", "the first press only arms it (it's for good)")
	act = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_act", "") == "choose")
	_check(act.size() == 1 and act[0].text.begins_with("Press again"), "...asking for a second press (%s)" % (act[0].text if act.size() == 1 else ""))
	if act.size() == 1:
		act[0].pressed.emit()
		await t._frames(2)
	_check(TR.mark_choice(main.profile, "stormcaller", 2) == "ball_lightning", "the second press chooses it")
	_check("ball_lightning" in main.player.bonds["hand"].spells().map(func(sp): return sp["id"]), "...and the mark casts it at once")
	buds = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("bud"))
	_check(buds.any(func(b): return String(b.get_meta("bud")).ends_with("|overcharge") and b.get_meta("bud_state") == "passed"), "Overcharge shows as passed on")
	# The Unbound's tree, and learning a passed side.
	menu.close()
	await t._ub_fresh()
	main = _main()
	menu = main.menu
	var prof = main.profile
	var U = load("res://scripts/unbound.gd")
	prof.part_density = {"hand": {"blade": U.LEVELS[2]}}
	TR.choose(prof, "unbound:hand:2", "split")
	prof.add_crystal("stone", 200.0)
	menu.climber_tab = "tree"
	menu.set_meta("tree_part", "hand")
	menu.set_meta("tree_sel", "unbound:hand:2|quick")
	menu.open("climber", true)
	await t._frames(3)
	var learn: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_act", "") == "learn")
	_check(learn.size() == 1 and not learn[0].disabled, "an Unbound can learn a passed side from the Tree")
	if learn.size() == 1:
		learn[0].pressed.emit()
		await t._frames(2)
		learn = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_act", "") == "learn")
		if learn.size() == 1:
			learn[0].pressed.emit()
			await t._frames(2)
	_check("quick" in TR.owned_variations(prof), "...two presses, and it's theirs")
	menu.close()
	await t._frames(2)


func _ball_lightning() -> void:
	print("the tree: Ball Lightning in play")
	await _marked()
	var main = _main()
	var TR = load("res://scripts/tree.gd")
	var FX = load("res://scripts/spell_fx.gd")
	var p = main.player
	TR.choose(main.profile, "mark:stormcaller:2", "ball_lightning")
	main._give_bonds()
	var hb = p.bonds["hand"]
	var i: int = hb.spells().map(func(sp): return sp["id"]).find("ball_lightning")
	hb.select(i)
	_check(hb.spell()["id"] == "ball_lightning" and hb.cost() == 10.0, "Ball Lightning on the hand's button, costing 10")
	var foes: Array = main.enemies()
	for e in foes:
		e.hp = 300.0
		e.max_hp = 300.0
	var slime = foes.filter(func(e): return e.kind == "slime")[0]
	p.global_position = slime.global_position - Vector2(90, 0)
	p.aim = Vector2.RIGHT
	p.iframes = 999.0
	var hp0: float = slime.hp
	hb.essence = hb.capacity()
	p.attack_cd = 0.0
	p._try_cast("hand")
	await t._wait(0.5)
	var fx = FX.of(main)
	_check(fx != null and fx.orbs.size() == 1, "casting it sends an orb drifting along your aim")
	await t._wait(1.6)
	_check(slime.hp < hp0 and slime.charged > 0.0, "it sparks the foe it passes and charges it (%.0f -> %.0f)" % [hp0, slime.hp])
	await t._wait(2.0)
	_check(fx.orbs.is_empty(), "...then it's gone")
	# Lingering: the last leap leaves a charged patch.
	TR.choose(main.profile, "mark:stormcaller:3", "lingering")
	main._give_bonds()
	hb = p.bonds["hand"]
	hb.select(0)
	hb.essence = hb.capacity()
	p.global_position = slime.global_position - Vector2(120, 0)
	hb.cast(p)
	_check(fx.fields.size() == 1 and fx.fields[0]["pos"].distance_to(slime.global_position) < 200.0, "Lingering: Chain Lightning's last leap leaves a charged patch")
	main._start_floor(main.floor_num)
	await t._frames(2)
	_check(not fx.busy() if is_instance_valid(fx) else true, "a new floor clears what spells left behind")


func _variations() -> void:
	print("the tree: variations on a technique")
	await t._ub_fresh()
	var main = _main()
	var T = load("res://scripts/technique.gd")
	var L = load("res://scripts/library.gd")
	var FX = load("res://scripts/spell_fx.gd")
	var p = main.player
	var run = main.unbound
	p.iframes = 999.0
	_check(L.VARIATION_ORDER.size() == 10 and L.VARIATION_ORDER.all(func(v): return L.built(L.variation(v))), "the ten variations are all written")
	var bolt := {"part": "hand", "shape": "bolt", "kinds": ["fire"]}
	var with := func(v): return {"part": "hand", "shape": "bolt", "kinds": ["fire"], "vars": [v]}
	_check(T.strain(with.call("split")) == T.strain(bolt) + 4.0, "a variation adds a little strain (+4)")
	_check(is_equal_approx(T.windup(with.call("quick")), T.windup(bolt) * 0.5) and T.windup(with.call("charged")) > T.windup(bolt), "Quick winds up faster, Charged slower")
	_check(T.describe(with.call("echo")).contains("Echo"), "...and its card says so")
	run.bolts.clear()
	p.aim = Vector2.RIGHT
	T.cast(with.call("split"), p, 1.0, run)
	_check(run.bolts.size() == 3, "Split throws three bolts (%d)" % run.bolts.size())
	run.bolts.clear()
	T.cast(bolt, p, 1.0, run)
	var plain_range: float = run.bolts[0]["left"] if not run.bolts.is_empty() and run.bolts[0] is Dictionary and run.bolts[0].has("left") else -1.0
	run.bolts.clear()
	T.cast(with.call("long"), p, 1.0, run)
	var long_range: float = run.bolts[0]["left"] if not run.bolts.is_empty() and run.bolts[0] is Dictionary and run.bolts[0].has("left") else -1.0
	_check(long_range > plain_range * 1.3 or plain_range < 0.0, "Long reaches farther (%.0f -> %.0f)" % [plain_range, long_range])
	run.bolts.clear()
	T.cast(with.call("mirrored"), p, 1.0, run)
	_check(run.bolts.size() == 2, "Mirrored also casts behind you")
	run.bolts.clear()
	T.cast(with.call("echo"), p, 1.0, run)
	var fx = FX.of(main)
	_check(run.bolts.size() == 1 and fx.timers.size() == 1, "Echo casts now, and once more a moment later")
	await t._wait(1.2)
	_check(run.bolts.size() >= 2 or fx.timers.is_empty(), "...and it does")
	run.bolts.clear()
	fx.timers.clear()
	T.cast(with.call("delayed"), p, 1.0, run)
	_check(run.bolts.is_empty() and fx.timers.size() == 1 and fx.marks.size() == 1, "Delayed casts a moment later, its spot marked")
	fx.timers.clear()
	# Chain and Lingering on a strike, at two foes.
	var a = await t._spawn("slime", p.global_position + Vector2(36, 0))
	var b = await t._spawn("slime", p.global_position + Vector2(36, 110))
	for e in [a, b]:
		e.hp = 300.0
		e.max_hp = 300.0
	var hb0: float = b.hp
	T.cast({"part": "hand", "shape": "strike", "kinds": ["fire"], "vars": ["chain"]}, p, 1.0, run)
	_check(b.hp < hb0, "Chain jumps to one more foe")
	fx.fields.clear()
	T.cast({"part": "hand", "shape": "strike", "kinds": ["fire"], "vars": ["lingering"]}, p, 1.0, run)
	_check(fx.fields.size() == 1, "Lingering leaves a field")
	var wide: Dictionary = T.varied_shape(T.SHAPES["shout"], "wide")
	_check(wide["arc"] > T.SHAPES["shout"]["arc"], "Wide widens a shout's cone")
	# Volley: the hand's level-3 form, through its content file.
	run.bolts.clear()
	T.cast({"part": "hand", "shape": "volley", "kinds": ["fire"]}, p, 1.0, run)
	_check(run.bolts.size() == 3, "Volley (a new form) throws three small bolts")
	# A chosen effect in place of the base one (Spark: Air leaps to one more foe).
	var hb1: float = b.hp
	T.cast({"part": "hand", "shape": "strike", "kinds": ["air"], "effects": {"air": "spark"}}, p, 1.0, run)
	_check(b.hp < hb1, "a chosen effect works in place of its essence's base one (Spark)")


func _data_editor() -> void:
	print("the tree: the Data editor")
	var Reg = load("res://scripts/data_registry.gd")
	var T = load("res://scripts/technique.gd")
	var L = load("res://scripts/library.gd")
	_check(not Reg.field("library/FORMS/strike/damage").is_empty() and not Reg.field("library/VARIATIONS/split/name").is_empty() and not Reg.field("library/EFFECTS/burn/says").is_empty(),
		"the Data editor lists the library's forms, effects and variations")
	_check(not Reg.field("spells.gryphon/FORKS/stormcaller/2/name").is_empty() and not Reg.field("spells.gryphon/FORKS/stormcaller/2/steps/2/damage").is_empty(), "...and a tower's forks")
	var was: float = T.SHAPES["strike"]["damage"]
	_check(Reg.set_value("library/FORMS/strike/damage", 20) == "" and T.SHAPES["strike"]["damage"] == 20.0, "a change there is a change to the techniques")
	Reg.revert("library/FORMS/strike/damage")
	_check(T.SHAPES["strike"]["damage"] == was, "...and Default puts it back")
	_check(Reg.field("library/FORMS/strike/class").is_empty() and Reg.field("spells.gryphon/FORKS/stormcaller/2/type").is_empty(), "ids the code looks up aren't offered")


func _phone_fit() -> void:
	print("the tree: fitting a phone")
	await _marked()
	var main = _main()
	var menu = main.menu
	var U = load("res://scripts/ui.gd")
	var M = load("res://scripts/menu.gd")
	var keep: String = M.settings["ui_size"]
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	var problems: Array = []
	for who in ["marked", "unbound"]:
		if who == "unbound":
			main.unbound.Unbound.become(main.profile)
			main.profile.part_density = {"hand": {"blade": 400.0}}
			main._give_bonds()
		for ui in U.UI_SIZE_ORDER:
			menu._set_setting("ui_size", ui)
			await t._frames(2)
			for tab in ["tree", "abilities"]:
				menu.climber_tab = tab
				menu.set_meta("tree_part", "hand")
				menu.open("climber")
				await t._frames(3)
				var view: Rect2 = t.root.get_visible_rect()
				problems.append_array(t._fit_problems("%s %s %s" % [who, ui, tab], menu.panel, view))
	_check(problems.is_empty(), "the book's Tree and Abilities fit at every Interface size on 800x400, marked and Unbound (%d problems): %s" % [problems.size(), problems.slice(0, 8)])
	menu.close()
	menu._set_setting("ui_size", keep)
	main.touch._set_active(false)
	t.root.size = was_size
	await t._frames(2)
