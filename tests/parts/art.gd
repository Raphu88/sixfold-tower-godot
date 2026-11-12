extends RefCounted
## The tree's art and treats (Phase B): the body map drawn for marked and
## Unbound climbers with every kind of bud, choosing a part and a bud by
## touch, keys and controller, the links between Abilities and the Tree,
## the glyphs on the cards, the star in Your Car's window, and the book
## fitting a phone at every Interface size. Run by smoke_test.gd (_part_tests).

const Book := preload("res://scripts/book.gd")
const TreeView := preload("res://scripts/tree_view.gd")
const Card := preload("res://scripts/grimoire_card.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _drawn()
	await _glyphs()
	await _select_touch()
	await _select_keys()
	await _select_pad()
	await _links()
	await _sky_star()
	await _fits()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A marked climber: Stormcaller on the hand at step 3 (two forks ready),
## Windwalker on the legs, Warden on the brow at step 4.
func _marked() -> void:
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.add_bond("brow", "warden", false)
	main.profile.bonds["hand"]["xp"] = 500.0
	main.profile.bonds["brow"]["xp"] = 1000.0
	main._give_bonds()
	for e in main.enemies():
		e.set_physics_process(false)


## An Unbound climber: the hand at level 7 (Split chosen at 2, so Quick can
## be learned; the level-6 fork ready), the legs at 4, the hand strained hot.
func _unbound() -> void:
	await t._ub_fresh()
	var main = _main()
	var prof = main.profile
	var U = load("res://scripts/unbound.gd")
	prof.part_density = {"hand": {"blade": U.LEVELS[6]}, "legs": {"air": U.LEVELS[3]}}
	load("res://scripts/tree.gd").choose(prof, "unbound:hand:2", "split")
	main._give_bonds()
	main.touch._set_active(false)
	main.pad._set_active(false)


func _open_tree(part := "", sel := "") -> void:
	var menu = _main().menu
	for m in ["tree_part", "tree_sel", "tree_arm"]:
		if menu.has_meta(m):
			menu.remove_meta(m)
	if part != "":
		menu.set_meta("tree_part", part)
	if sel != "":
		menu.set_meta("tree_sel", sel)
	menu.climber_tab = "tree"
	menu.open("climber", true)
	await t._frames(4)


func _map():
	var found: Array = _main().menu.box.find_children("*", "Control", true, false).filter(func(c): return c is TreeView.TreeMap)
	return found[0] if not found.is_empty() else null


func _buds() -> Array:
	return _main().menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("bud"))


func _bud(key_end: String):
	var b: Array = _buds().filter(func(b): return String(b.get_meta("bud")).ends_with(key_end))
	return b[0] if not b.is_empty() else null


func _part_node(part: String):
	var n: Array = _main().menu.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("tree_part", "") == part)
	return n[0] if not n.is_empty() else null


func _focus():
	return _main().menu.get_viewport().gui_get_focus_owner()


func _drawn() -> void:
	print("the tree's art: the body map, marked")
	await _marked()
	var main = _main()
	var TR = load("res://scripts/tree.gd")
	await _open_tree()
	var map = _map()
	_check(map != null and map.part == "hand", "the Tree is one body map, on the hand (a fork is ready there)")
	if map == null:
		return
	_check(map.still != null and not map.still.every_frame and map.live != null and map.live.every_frame, "...drawn in two layers: what doesn't move once, what glows each frame")
	_check(map.conn.size() > 10 and map.trunk.size() == map.rows.size() and map.twigs.size() == map.buds.size(), "...a branch grows from the mark to a root, a trunk piece to each node, a twig to each bud")
	var states := {}
	for b in _buds():
		states[b.get_meta("bud_state")] = true
	_check(states.has("in_use") and states.has("available") and states.has("locked") and states.has("placeholder") and states.has("owned"),
		"buds for every state of a marked tree: yours, in use, a ready choice, locked, coming later (%s)" % [states.keys()])
	var locked = _bud("|lightning_rod")
	_check(locked != null and locked.aux == TR.TEXT["needs_step"] % 4, "a locked bud says what opens it (%s)" % (locked.aux if locked != null else ""))
	var later: Array = _buds().filter(func(b): return String(b.option.get("kind", "")) == "later")
	_check(later.size() == 1 and later[0].aux.contains("6") and later[0].aux.contains("10"), "the steps still to come share one faint bud (%s)" % (later[0].aux if later.size() == 1 else ""))
	_check(map.parts.size() == 6 and map.parts["hand"].ready_fork and map.parts["hand"].on, "a node on each part; the hand's pulses (a ready fork) and is the chosen one")
	await t._frames(3)
	TR.choose(main.profile, "mark:stormcaller:2", "ball_lightning")
	main._give_bonds()
	await _open_tree("hand")
	_check(_bud("|overcharge") != null and _bud("|overcharge").get_meta("bud_state") == "passed" and _bud("|ball_lightning").get_meta("bud_state") == "owned", "once chosen: Ball Lightning is yours, Overcharge passed on (faded)")
	await _open_tree("throat")
	_check(_map() != null and _map().conn.is_empty() and _map().note != null and _buds().is_empty(), "an unmarked part: no branch, a few words instead")
	await _open_tree("brow")
	_check(_map() != null and _map().affinity == "water" and _map().buds.size() >= 9, "the brow's Warden tree, in its own colour and emblem")

	print("the tree's art: the body map, Unbound")
	await _unbound()
	main = _main()
	main.unbound.strain["hand"] = 90.0
	await _open_tree("hand")
	map = _map()
	_check(map != null and map.unbound and map.conn.size() > 10, "an Unbound part grows a vein of raw essence")
	states = {}
	for b in _buds():
		states[b.get_meta("bud_state")] = true
	# ("Coming later" only shows while some piece is still unwritten; with the whole set built there may be none.)
	_check(states.has("owned") and states.has("learnable") and states.has("available") and states.has("locked"),
		"buds for every state of an Unbound tree: yours, learnable again, a ready choice, locked, coming later (%s)" % [states.keys()])
	_check(_buds().any(func(b): return String(b.get_meta("bud")).begins_with("fx:")), "...and its essences' effects")
	var quick = _bud("|quick")
	_check(quick != null and quick.aux == TreeView.TEXT["learn_bud"] % TR.skipped_cost(2), "a passed side shows what learning it costs (%s)" % (quick.aux if quick != null else ""))
	await t._frames(6)  # (the hot vein flickers: drawn without errors)
	main.unbound.strain["hand"] = 0.0


func _glyphs() -> void:
	print("the tree's art: the glyphs")
	var L = load("res://scripts/library.gd")
	var B = load("res://scripts/bonds.gd")
	var all_forms := true
	for id in L.FORMS:
		if Card.form_glyph(id) == "":
			all_forms = false
	_check(all_forms, "every form has a glyph (written or not)")
	var all_vars := true
	for id in L.VARIATIONS:
		if Card.variation_glyph(id) == "":
			all_vars = false
	_check(all_vars, "every variation has a glyph")
	var spells := 0
	var drawn := 0
	for b in B.BONDS:
		for sp in B.BONDS[b]["spells"]:
			spells += 1
			if Card.spell_glyph(sp) != "":
				drawn += 1
	_check(drawn == spells, "every bond spell gets a glyph from its type, words or numbers (%d of %d)" % [drawn, spells])
	_check(Card.glyph_for({"form": "volley"}) == "fan" and Card.glyph_for({"form": "shout"}) == "cone" and Card.glyph_for({"form": "shell"}) == "shield"
		and Card.glyph_for({"form": "push"}) == "burst", "a fan of bolts, a cone, a shell, a burst")
	# New content gets a picture from its data alone.
	_check(Card.spell_glyph({"type": "made_up", "desc": "a wall of thorns rises in front of you"}) == "wall", "a new spell's line: 'a wall of thorns' is a wall")
	_check(Card.spell_glyph({"type": "made_up2", "desc": "", "steps": {1: {"radius": 80.0, "damage": 5.0}}}) == "ring", "...with no telling words, its numbers: a radius is a ring")
	_check(Card.from_words("A slow ring that rolls outward from you") == "ring" and Card.from_words("A narrow beam you hold for a second") == "beam", "the placeholders' forms read as a ring and a beam")
	_check(Card.effect_glyph("burn") == "flame" and Card.effect_glyph("spark") == "zig", "effects: Burn a flame, Spark a zigzag")
	# Every glyph draws.
	var c := Card.Drawing.new()
	c.size = Vector2(40, 40)
	_main().menu.add_child(c)
	var names := {}
	for k in Card.GLYPHS:
		names[Card.GLYPHS[k]] = true
	for w in Card.WORDS:
		names[w[1]] = true
	for k in Card.KIND_GLYPHS:
		names[Card.KIND_GLYPHS[k]] = true
	c.set_meta("names", names.keys())
	c.draw.connect(func():
		for g in c.get_meta("names"):
			Card.Drawing.draw_glyph(c, g, Vector2(20, 20), 12.0, Color.WHITE))
	c.queue_redraw()
	await t._frames(2)
	_check(names.size() >= 30, "%d glyphs drawn" % names.size())
	c.queue_free()


func _select_touch() -> void:
	print("the tree's art: by touch")
	await _marked()
	var main = _main()
	var menu = main.menu
	main.touch._set_active(true)
	await _open_tree("hand")
	var legs = _part_node("legs")
	if legs != null:
		await t._tap_at(legs.get_global_rect().get_center())
		await t._frames(3)
	_check(menu.get_meta("tree_part", "") == "legs" and _map() != null and _map().part == "legs", "a tap on the legs shows their tree")
	var b = _bud("|gale_lift")
	if b != null:
		menu.scroll.ensure_control_visible(b)  # (a finger scrolls the page to it)
		await t._frames(2)
		await t._tap_at(b.get_global_rect().get_center())
		await t._frames(3)
	var card: Array = menu.find_children("*", "Button", true, false).filter(func(c): return c.has_meta("tree_card"))
	_check(menu.get_meta("tree_sel", "").ends_with("|gale_lift") and card.size() == 1 and card[0].get_meta("tree_card") == "gale_lift", "a tap on a bud reads its grimoire card")
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)


func _select_keys() -> void:
	print("the tree's art: by keys")
	await _marked()
	var main = _main()
	var menu = main.menu
	await _open_tree("hand")
	var hand = _part_node("hand")
	hand.grab_focus()
	await t._frames(1)
	await t._key_tap(KEY_DOWN)
	_check(_focus() != null and _focus().get_meta("tree_part", "") == "legs", "Down from the hand: the legs (the parts, top to bottom)")
	await t._key_tap(KEY_UP)
	await t._key_tap(KEY_UP)
	_check(_focus() != null and _focus().get_meta("tree_part", "") == "back", "Up twice: the back")
	_part_node("hand").grab_focus()
	await t._frames(1)
	await t._key_tap(KEY_RIGHT)
	var f = _focus()
	_check(f != null and String(f.get_meta("bud", "")) == String(menu.get_meta("tree_sel", _map().sel)), "Right from the part: onto its branch, on the chosen bud (%s)" % (f.get_meta("bud", "") if f != null else ""))
	await t._key_tap(KEY_DOWN)
	f = _focus()
	_check(f != null and String(f.get_meta("bud", "")).ends_with("|change"), "Down along the branch: the next line (Branching Storm, today's step-3 side) (%s)" % (f.get_meta("bud", "") if f != null else ""))
	await t._key_tap(KEY_UP)
	await t._key_tap(KEY_UP)
	f = _focus()
	_check(f != null and String(f.get_meta("bud", "")).ends_with("|overcharge"), "Up twice: Overcharge, the fork's other side (%s)" % (f.get_meta("bud", "") if f != null else ""))
	await t._key_tap(KEY_LEFT)
	_check(_focus() != null and _focus().get_meta("tree_part", "") == "hand", "Left off the branch: back to its part")
	await t._key_tap(KEY_RIGHT)
	await t._key_tap(KEY_UP)
	await t._key_tap(KEY_ENTER)
	await t._frames(2)
	_check(String(menu.get_meta("tree_sel", "")).ends_with("|overcharge") or String(menu.get_meta("tree_sel", "")).ends_with("|chain_lightning"), "Enter reads the bud (%s)" % menu.get_meta("tree_sel", ""))
	var card: Array = menu.find_children("*", "Button", true, false).filter(func(c): return c.has_meta("tree_card"))
	_check(card.size() == 1 and String(menu.get_meta("tree_sel", "")).ends_with("|" + String(card[0].get_meta("tree_card"))), "...its card shows")
	menu.close()
	await t._frames(2)


func _select_pad() -> void:
	print("the tree's art: by controller")
	await _marked()
	var main = _main()
	var menu = main.menu
	main.pad._set_active(true)
	await _open_tree("hand")
	_part_node("hand").grab_focus()
	await t._frames(1)
	await t._pad_tap(JOY_BUTTON_DPAD_UP)
	_check(_focus() != null and _focus().get_meta("tree_part", "") == "back", "the d-pad walks the parts (up: the back)")
	await t._pad_tap(JOY_BUTTON_A)
	await t._frames(2)
	_check(menu.get_meta("tree_part", "") == "back" and _map() != null and _map().part == "back", "A on a part shows its tree")
	_part_node("legs").grab_focus()
	await t._frames(1)
	await t._pad_tap(JOY_BUTTON_A)
	await t._frames(2)
	_check(_map() != null and _map().part == "legs", "...the legs'")
	await t._pad_tap(JOY_BUTTON_DPAD_RIGHT)
	var f = _focus()
	_check(f != null and String(f.get_meta("bud", "")).ends_with("|gale_lift"), "Right onto the branch (%s)" % (f.get_meta("bud", "") if f != null else ""))
	await t._pad_tap(JOY_BUTTON_DPAD_DOWN)
	f = _focus()
	var key := String(f.get_meta("bud", "")) if f != null else ""
	await t._pad_tap(JOY_BUTTON_A)
	await t._frames(2)
	_check(key != "" and String(menu.get_meta("tree_sel", "")) == key, "down along it and A reads that bud (%s)" % key)
	main.pad._set_active(false)
	menu.close()
	await t._frames(2)


func _links() -> void:
	print("the tree's art: Abilities and the Tree, both ways")
	await _marked()
	var main = _main()
	var menu = main.menu
	menu.climber_tab = "abilities"
	menu.open("climber", true)
	await t._frames(3)
	var links: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("map_link"))
	var spells: Array = load("res://scripts/abilities.gd").entries(main).filter(func(e): return e["kind"] in ["spell", "mark"])
	_check(links.size() == spells.size(), "every Abilities entry has 'On the body map' (%d of %d)" % [links.size(), spells.size()])
	var cl: Array = links.filter(func(b): return String(b.get_meta("map_link")).ends_with("|chain_lightning"))
	if not cl.is_empty():
		cl[0].pressed.emit()
		await t._frames(3)
	_check(menu.page == "climber" and menu.climber_tab == "tree" and String(menu.get_meta("tree_sel", "")) == "mark:stormcaller:1|chain_lightning", "Chain Lightning's link turns to the Tree with its bud chosen")
	var bud = _bud("|chain_lightning")
	_check(bud != null and bud.flash_until > Time.get_ticks_msec() and bud.selected, "...and that bud glows a moment")
	var back: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_link", "") == "chain_lightning")
	_check(back.size() == 1, "its card has 'In your abilities'")
	if back.size() == 1:
		back[0].pressed.emit()
		await t._frames(3)
	var cards: Array = menu.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("ability", "") == "chain_lightning" and b.get_meta("grimoire", false))
	_check(menu.climber_tab == "abilities" and cards.size() == 1 and cards[0].selected, "...which turns back to Abilities, Chain Lightning picked out")
	# A step-3 change is part of the spell it changes; a passed side is in no entry.
	await _open_tree("hand", "mark:stormcaller:3|change")
	_check(t._all_buttons(menu).any(func(b): return b.get_meta("tree_link", "") == "chain_lightning"), "Branching Storm (today's step-3 side) links to Chain Lightning")
	await _open_tree("hand", "mark:stormcaller:2|ball_lightning")
	_check(not t._all_buttons(menu).any(func(b): return b.has_meta("tree_link")), "a side not chosen yet isn't in your abilities")
	# The Unbound: a technique links to its form's bud, and back.
	await _unbound()
	main = _main()
	menu = main.menu
	menu.climber_tab = "abilities"
	menu.open("climber", true)
	await t._frames(3)
	links = menu.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("map_link"))
	var techs: Array = load("res://scripts/abilities.gd").entries(main).filter(func(e): return e["kind"] == "technique")
	_check(links.size() == techs.size() and techs.size() > 0, "every technique links to the body map (%d of %d)" % [links.size(), techs.size()])
	var first: Dictionary = techs[0] if not techs.is_empty() else {}
	var mine: Array = links.filter(func(b): return String(b.get_meta("map_link")).begins_with(String(first.get("tech", {}).get("part", "?"))))
	if not mine.is_empty():
		mine[0].pressed.emit()
		await t._frames(3)
	_check(menu.climber_tab == "tree" and String(menu.get_meta("tree_sel", "")).ends_with("|" + String(first.get("tech", {}).get("shape", "?"))), "%s's link opens its part's tree on its form (%s)" % [first.get("name", ""), menu.get_meta("tree_sel", "")])
	back = t._all_buttons(menu).filter(func(b): return b.get_meta("tree_link", "") == String(first.get("id", "")))
	_check(back.size() == 1, "...and the form's card links back to that technique")
	menu.close()
	await t._frames(2)


func _sky_star() -> void:
	print("the tree's art: the star in the window")
	await _marked()
	var main = _main()
	var menu = main.menu
	main.touch._set_active(true)
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.train_car = "personal"
	menu.open("train")
	await t._wait(0.7)
	var v = menu.train_view
	var star = v.sky_star
	_check(star != null and is_instance_valid(star) and star.is_visible_in_tree(), "a fork is ready: a new star shines in Your Car's window")
	var books: Array = t._car_buttons("book", true)
	_check(books.size() == 1 and books[0].ready_star, "...and the book on its cushion keeps its gilt mote")
	if star != null and is_instance_valid(star):
		var view: Rect2 = t.root.get_visible_rect()
		_check(view.encloses(star.get_global_rect()) and star.get_global_rect().size.x >= 40.0, "...on screen, big enough to tap")
		await t._tap_at(star.get_global_rect().get_center())
		await t._frames(3)
	_check(menu.page == "climber" and menu.climber_tab == "tree" and menu.get_meta("tree_part", "") == "hand", "tapping it opens the book's Tree on the hand")
	# Nothing to choose: no star.
	var TR = load("res://scripts/tree.gd")
	for node_id in TR.ready_forks(main.profile):  # (every fork ready now, whatever the tower files have written)
		TR.choose(main.profile, node_id, TR.available(main.profile, node_id)[0])
	menu.close()
	await t._frames(2)
	main.open_train()
	await t._frames(2)
	menu.train_car = "personal"
	menu.open("train")
	await t._wait(0.7)
	star = v.sky_star
	_check(not TR.is_fork_ready(main.profile) and (star == null or not is_instance_valid(star) or not star.visible), "with every choice made, the star is gone (%s)" % [TR.ready_forks(main.profile)])
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)


func _fits() -> void:
	print("the tree's art: fitting a phone")
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
			main.profile.part_density = {"hand": {"blade": 400.0}, "legs": {"air": 120.0}}
			main._give_bonds()
		for ui in U.UI_SIZE_ORDER:
			menu._set_setting("ui_size", ui)
			await t._frames(2)
			for page in [["tree", "hand"], ["tree", "brow"], ["tree", "legs"], ["abilities", ""]]:
				menu.climber_tab = page[0]
				for m in ["tree_sel", "tree_part"]:
					if menu.has_meta(m):
						menu.remove_meta(m)
				if page[1] != "":
					menu.set_meta("tree_part", page[1])
				menu.open("climber")
				await t._frames(4)
				var view: Rect2 = t.root.get_visible_rect()
				var where := "%s %s %s %s" % [who, ui, page[0], page[1]]
				problems.append_array(t._fit_problems(where, menu.panel, view))
				var map = _map()
				if map != null:
					var mr: Rect2 = map.get_global_rect()
					for b in map.buds.values():
						if b.visible and (b.get_global_rect().end.x > mr.end.x + 1.0 or b.get_global_rect().position.x < mr.position.x - 1.0):
							problems.append("%s: bud '%s' past the map's edge" % [where, b.text])
					if map.lay.get("h", 0.0) > map.size.y + 1.0:
						problems.append("%s: the map's height isn't its layout's" % where)
	_check(problems.is_empty(), "the body map and Abilities with its links fit at every Interface size on 800x400, marked and Unbound (%d problems): %s" % [problems.size(), problems.slice(0, 8)])
	menu.close()
	menu._set_setting("ui_size", keep)
	main.touch._set_active(false)
	t.root.size = was_size
	await t._frames(2)
