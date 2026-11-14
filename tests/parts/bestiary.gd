extends RefCounted
## The Bestiary (bestiary.gd): every monster has an entry (a name, how it
## fights, a blank lore for the owner); an unmet one shows ???; seeing,
## fighting and slaying one raise its tier through the game's own calls
## and reveal the right lines; the record survives a save and an old save
## loads; the first meeting is told once a floor; the page opens from the
## menu and the train, and its tabs, volumes and tiles answer taps on a
## phone. Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")
const B := preload("res://scripts/bestiary.gd")
const E := preload("res://scripts/enemy.gd")
const Reg := preload("res://scripts/data_registry.gd")

var t
var P = load("res://scripts/profile.gd")


func run(smoke) -> void:
	t = smoke
	_data()
	await _tiers()
	await _hurt_and_fell()
	_saves()
	await _pages()
	await _phone()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh game with nothing met, the monsters still, the climber safe.
func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.profile.bestiary = {}
	main.player.iframes = 999.0


func _data() -> void:
	print("the Bestiary: its table")
	var want: Array = E.TYPES.keys().filter(func(k): return k != "familiar")
	var missing: Array = want.filter(func(k): return not B.BESTIARY.has(k) or not k in B.kinds())
	_check(missing.is_empty() and B.kinds().size() == want.size(), "every monster kind has a Bestiary entry and a place on its shelf (%s)" % [missing])
	var bad: Array = []
	for k in B.BESTIARY:
		var e: Dictionary = B.BESTIARY[k]
		if String(e.get("name", "")).strip_edges() == "" or String(e.get("desc", "")).length() < 30 or not e.has("lore") or String(e["lore"]) != "":
			bad.append(k)
	_check(bad.is_empty(), "...each with a name, a description and a blank lore for the owner (%s)" % [bad])
	var gs: Array = B.groups()
	var order_ok: bool = gs.size() == 7 and gs[0][0] == "every"
	for g in gs.slice(1):
		order_ok = order_ok and g[2].size() >= 3 and g[2][-1] == load("res://scripts/towers.gd").TOWERS[g[0]]["beast_kind"]
	_check(order_ok, "grouped: every tower's monsters, then each tower's own with its beast last (%s)" % [gs.map(func(g): return [g[0], g[2]])])
	for k in ["golem", "burrower", "deepfin", "harrier", "ashwing", "briar"]:
		_check(k in B.kinds() and B.shape(k)["pts"].size() > 30, "the %s has an entry and is drawn from its own script" % k)
	_check(B.shape("gryphon")["pts"].size() > 100 and B.shape("chimera")["solid"].size() > 30, "a beast's picture is its own drawing, and it has a silhouette")
	var words := (var_to_str(B.BESTIARY) + var_to_str(B.TEXT)).to_lower()
	var re := RegEx.create_from_string("\\b(attunements?|spires?|trials?|judge?ments?|mana)\\b")
	_check(re.search(words) == null, "no banned words in the Bestiary's words")
	var paths: Array = Reg.fields_in("bestiary_words").map(func(f): return f["path"])
	_check("bestiary/BESTIARY/lurker/name" in paths and "bestiary/BESTIARY/lurker/desc" in paths and "bestiary/BESTIARY/lurker/lore" in paths and "bestiary/TEXT/new" in paths,
		"the Data editor lists the names, descriptions, blank lore and words")
	var nums: Array = Reg.fields_in("bestiary_numbers").map(func(f): return f["path"])
	_check("bestiary/TIERS/slain/1" in nums and "bestiary/TIERS/beast/0" in nums, "...and the slayings each tier needs")


func _lines(kind: String) -> Array:
	return B.lines(t.main.profile, kind).map(func(l): return l[0])


func _told(text: String) -> int:
	return t.main.notices.log.filter(func(e): return String(e["text"]) == text).size()


func _tiers() -> void:
	print("the Bestiary: tiers")
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	_check(B.level(prof, "slime") == 0 and _lines("slime") == ["learn"] and B.lines(prof, "slime")[0][1] == B.TEXT["unmet"], "an unmet monster: nothing known")
	var e = main.spawn_enemy("slime", p.global_position + Vector2(140, 0))
	e.set_physics_process(false)
	await t._frames(3)
	main.set_meta("bestiary_watch", 0.0)
	B.watch(main, 1.0)
	_check(B.level(prof, "slime") == 1, "a slime on screen near the climber is seen (%s)" % [prof.bestiary])
	var r: Dictionary = prof.bestiary.get("slime", {})
	_check(r.get("tower") == main.tower and int(r.get("floor", 0)) == main.floor_num and "first" in _lines("slime") and not "desc" in _lines("slime"), "...where it was first met; how it fights not yet")
	_check(_told(B.TEXT["new"] % "Slime") == 1, "...and the game says so once: New in the Bestiary: Slime")
	e.take_hit(1.0, Vector2.RIGHT)
	await t._frames(1)
	_check(B.level(prof, "slime") == 2 and "desc" in _lines("slime") and not "health" in _lines("slime"), "struck: fought, how it fights shows, its health not yet")
	_check(_told(B.TEXT["rise_fought"] % "Slime") == 0, "...no second notice for the same kind on the same floor")
	e.take_hit(9999.0, Vector2.RIGHT)
	await t._frames(2)
	_check(int(prof.bestiary["slime"]["slain"]) == 1 and B.level(prof, "slime") == 3 and "health" in _lines("slime") and "tally" in _lines("slime") and not "weak" in _lines("slime"),
		"slain: its health and the tallies show, its weakness not yet (%s)" % [_lines("slime")])
	var hl: String = B.lines(prof, "slime").filter(func(l): return l[0] == "health")[0][1]
	_check(hl.contains(str(int(E.TYPES["slime"]["hp"]))), "...read from the monsters' own table (%s)" % hl)
	main.notices.new_floor()  # (a new floor: it may be told again)
	var steps: Array = B.TIERS["slain"]
	for i in int(steps[1]) - 1:
		B.meet(main, "slime", "slain")
	_check(B.level(prof, "slime") == 4 and "weak" in _lines("slime") and not "states" in _lines("slime"), "slain %d times: what it's weak to" % int(steps[1]))
	_check(_told(B.TEXT["rise_weak"] % "Slime") == 1, "...told once on the new floor")
	for i in int(steps[2]) - int(steps[1]):
		B.meet(main, "slime", "slain")
	_check(B.level(prof, "slime") == 5 and "states" in _lines("slime") and B.level(prof, "slime") == B.top_level("slime"), "slain %d times: how it takes states, everything known" % int(steps[2]))
	var weak: String = B.lines(prof, "slime").filter(func(l): return l[0] == "weak")[0][1]
	_check(weak.contains(E.WEAKNESS["slime"]), "the weakness is the game's own (%s)" % weak)
	# A beast: its own, smaller counts; the Proving's shade of it doesn't count.
	B.meet(main, "gryphon", "slain")
	_check(B.level(prof, "gryphon") == 3 and "calls" in _lines("gryphon") and not "champion" in _lines("gryphon"), "a beast slain once: its health, its call for help, no champion note")
	var shade = main.spawn_enemy("kraken", p.global_position + Vector2(-160, 0))
	shade.set_physics_process(false)
	shade.shade = true
	B.slain(main, shade)
	_check(B.level(prof, "kraken") == 0, "the Proving's shade of a beast isn't the beast")
	shade.queue_free()
	await t._frames(1)


func _hurt_and_fell() -> void:
	print("the Bestiary: hit by it, felled by it")
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	var e = main.spawn_enemy("cinder", p.global_position + Vector2(200, 0))
	e.set_physics_process(false)
	await t._frames(2)
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.hp = p.max_health()
	p.receive_attack(2.0, e)
	_check(B.level(prof, "cinder") == 2, "a cinder's blow landing on you: fought (%s)" % [prof.bestiary.get("cinder")])
	var shot = main.spawn_projectile(e.global_position + Vector2(-20, 0), Vector2(-280, 0), 2.0)
	_check(B._foe_of(main, shot) == e, "an ember in flight is traced back to the cinder that spat it")
	shot.queue_free()
	B.fell(main)
	_check(int(prof.bestiary["cinder"]["fell"]) == 1, "falling soon after: it felled you")
	B.fell(main)
	_check(int(prof.bestiary["cinder"]["fell"]) == 1, "...counted once")
	p.iframes = 999.0
	e.queue_free()
	await t._frames(1)


func _saves() -> void:
	print("the Bestiary: saves")
	var path := TestRun.path("user://smoke_bestiary.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "record", {"slain": 12.0})
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	_check(old.bestiary == {} and old.count("slain") == 12 and B.level(old, "slime") == 0, "an old save with no Bestiary loads: nothing met yet")
	old.saving = true
	old.bestiary = {"lurker": {"seen": true, "fought": true, "slain": 3, "fell": 1, "tower": "kraken", "floor": 2}, "bad": "x"}
	old.save()
	var again = P.new()
	again.saving = false
	again.save_path = path
	again.load_save()
	_check(again.bestiary.size() == 1 and again.bestiary["lurker"]["slain"] == 3 and again.bestiary["lurker"]["tower"] == "kraken" and B.level(again, "lurker") == 3, "the Bestiary is saved with the climber, a broken entry dropped (%s)" % [again.bestiary])
	again.saving = false
	again.reset()
	_check(again.bestiary.is_empty(), "Start over: a new climber has met nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _tiles(root: Node) -> Array:
	return root.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("bestiary") or b.has_meta("bestiary_locked"))


func _card(root: Node):
	var cs: Array = root.find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("bestiary_card"))
	return cs[0] if not cs.is_empty() else null


func _pages() -> void:
	print("the Bestiary: the Library page and the Library car")
	await _fresh()
	var main = t.main
	var menu = main.menu
	main.profile.bestiary = {"slime": {"seen": true, "fought": true, "slain": 0, "fell": 0, "tower": "kraken", "floor": 1},
		"bat": {"seen": true, "fought": false, "slain": 0, "fell": 0, "tower": "gryphon", "floor": 2}}
	menu.library_tab = "archive"
	menu.open("library")
	await t._frames(2)
	menu._cycle(1)
	await t._frames(2)
	_check(menu.page == "library" and menu.library_tab == "bestiary", "E (RB) on the Library turns to its Bestiary tab")
	var tiles := _tiles(menu.box)
	var locked: Array = tiles.filter(func(b): return b.has_meta("bestiary_locked"))
	_check(tiles.size() == B.kinds().size() and locked.size() == B.kinds().size() - 2, "a tile for every monster, the %d unmet ones locked (%d)" % [B.kinds().size() - 2, locked.size()])
	_check(_card(menu.box) == null, "no entry open yet")
	var slime: Array = tiles.filter(func(b): return b.get_meta("bestiary", "") == "slime")
	slime[0].pressed.emit()
	await t._frames(2)
	var c = _card(menu.box)
	_check(menu.bestiary_open == "slime" and c != null and c.get_meta("bestiary_level") == 2, "choosing the slime opens its entry at its tier")
	var shown: Array = c.find_children("*", "Label", true, false).filter(func(l): return l.has_meta("bestiary_line")).map(func(l): return l.get_meta("bestiary_line"))
	_check("desc" in shown and "first" in shown and not "health" in shown and not "lore" in shown, "...with how it fights, where it was met, and not its health (%s)" % [shown])
	menu.close()
	await t._frames(2)
	menu.open_bestiary("bat")
	await t._frames(2)
	_check(menu.page == "library" and menu.library_tab == "bestiary" and _card(menu.box) != null and _card(menu.box).get_meta("bestiary_card") == "bat", "open_bestiary opens the page on an entry")
	menu.close()
	await t._frames(2)
	main.profile.regarded = true
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.open_bestiary("")
	await t._frames(4)
	var tp = menu.train_page
	_check(menu.page == "train" and menu.train_car == "library" and menu.library_shelf == "bestiary", "on the train, the Bestiary is the Library car's volume")
	var vol: Array = t._car_buttons("shelf", "bestiary")
	_check(vol.size() == 1 and vol[0].on, "...its volume on the bookcase, open on the lectern")
	_check(_tiles(tp.roots["library"]).size() == B.kinds().size(), "...its tiles at the lectern")
	main.on_train = false
	menu.close()
	await t._frames(2)


func _visible(c: Control) -> void:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			n.ensure_control_visible(c)
		n = n.get_parent()
	await t._frames(3)


func _phone() -> void:
	print("the Bestiary: taps on a phone")
	await _fresh()
	var main = t.main
	var menu = main.menu
	main.profile.bestiary = {"slime": {"seen": true, "fought": true, "slain": 2, "fell": 0, "tower": "kraken", "floor": 1}}
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	await t._frames(3)
	menu.library_tab = "archive"
	menu.bestiary_open = ""
	menu.open("library")
	await t._frames(3)
	var tabs: Array = menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("tab", "") == "bestiary")
	_check(tabs.size() == 1, "the Library has a Bestiary tab")
	if tabs.size() == 1:
		await _visible(tabs[0])
		await t._tap_at(tabs[0].get_global_rect().get_center())
		await t._frames(2)
	_check(menu.library_tab == "bestiary", "tapping the Bestiary tab at 915 x 412 opens it")
	var slime: Array = _tiles(menu.box).filter(func(b): return b.get_meta("bestiary", "") == "slime")
	var big: bool = not slime.is_empty() and slime[0].size.x >= 44.0 and slime[0].size.y >= 44.0
	_check(big, "...its tiles big enough to tap")
	if not slime.is_empty():
		await _visible(slime[0])
		await t._tap_at(slime[0].get_global_rect().get_center())
		await t._frames(2)
	_check(menu.bestiary_open == "slime" and _card(menu.box) != null, "tapping a tile opens its entry")
	menu.close()
	await t._frames(2)
	main.profile.regarded = true
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.library_shelf = ""
	menu.bestiary_open = ""
	menu.train_car = "library"
	menu.open("train")
	await t._frames(3)
	var tp = menu.train_page
	tp.go_to(tp._index("library"))
	await t._wait(0.6)
	var vol: Array = t._car_buttons("shelf", "bestiary")
	if vol.size() == 1:
		await _visible(vol[0])
		await t._tap_at(vol[0].get_global_rect().get_center())
		await t._frames(3)
	_check(menu.library_shelf == "bestiary", "tapping the Bestiary volume on the train puts it on the lectern")
	var tile: Array = _tiles(tp.roots["library"]).filter(func(b): return b.get_meta("bestiary", "") == "slime")
	if not tile.is_empty():
		await _visible(tile[0])
		await t._tap_at(tile[0].get_global_rect().get_center())
		await t._frames(3)
	_check(menu.bestiary_open == "slime" and _card(tp.roots["library"]) != null, "...and tapping its slime opens the entry in the car")
	main.on_train = false
	menu.close()
	t.root.size = was
	main.touch._set_active(false)
	main.apply_view_scale()
	await t._frames(3)
