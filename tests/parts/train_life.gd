extends RefCounted
## The train's people and its life (train_view.gd, dining_page.gd,
## rune_artist_name.gd): Rayne, the Rune Artist, is named in one place and
## every line that shows her name has it (no "(The Rune Artist)" left), she
## is she/her; Joel and Rayne are drawn with a neck between head and
## shoulders, Rayne as a full figure that stands in her own column on a
## computer and still fits a phone; every car has its ambience layer, whose
## specks follow the Effects setting (none on Low); the Arena car's lamps
## stream dust; the Dining car draws its climbers bigger when few sit down
## and smaller when many, never under the placard or off the screen; no
## banned words. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const RuneArtistName := preload("res://scripts/rune_artist_name.gd")
const Bench := preload("res://scripts/bench.gd")
const Charms := preload("res://scripts/charms.gd")
const Train := preload("res://scripts/train.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Particles := preload("res://scripts/particles.gd")
const Dining := preload("res://scripts/dining.gd")
const DiningPage := preload("res://scripts/dining_page.gd")
const ArenaCar := preload("res://scripts/arena_car.gd")
const Loadout := preload("res://scripts/loadout_page.gd")
const Registry := preload("res://scripts/data_registry.gd")
const Menu := preload("res://scripts/menu.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const PLACEHOLDER := "(The Rune Artist)"

var t


func run(smoke) -> void:
	t = smoke
	print("the train's people and life: Rayne, Joel's neck, the cars' ambience, the diners")
	_names()
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	main.grant_test_bonds()
	var was: Vector2i = t.root.size
	var level: String = Particles.level
	main.await_tower()
	main.open_train()
	await t._frames(3)
	await _rayne(main)
	await _joel(main)
	await _ambience(main)
	await _arena(main)
	await _diners(main)
	Particles.set_level(level)
	t.root.size = was
	main.touch._set_active(false)
	main.apply_view_scale()
	if is_instance_valid(main.menu) and main.menu.is_open():
		main.menu.close()
	main.on_train = false
	t.paused = false
	await t._frames(2)


func _car(main, car: String) -> void:
	var menu = main.menu
	menu.train_car = car
	menu.open("train")
	await t._frames(2)
	menu.train_page.go_to(menu.train_page._index(car))
	await t._train_settled()
	await t._frames(3)


# --- her name, in one place ----------------------------------------------------------------------

func _names() -> void:
	var n: String = RuneArtistName.NAME
	t._check(n == "Rayne" and String(Bench.ARTIST["name"]) == n, "the Rune Artist is Rayne, named in one place (rune_artist_name.gd) and on the bench's table")
	var tables := [Bench.ARTIST, Bench.TEXT, Bench.EXCHANGE_TEXT, Charms.TEXT, Train.OUTFITTER, Entity.TIPS, Help.HELP, Help.COMMENTS, Help.TEXT, Talk.DIALOGUE, Loadout.TEXT]
	var all := JSON.stringify(tables)
	t._check(not all.contains(PLACEHOLDER) and not all.contains(RuneArtistName.KEY), "no shown line keeps the placeholder \"(The Rune Artist)\" or an unfilled {rune_artist}")
	t._check(String(Entity.TIPS["rune_artist"]["name"]).contains(n) and String(Entity.TIPS["rune_artist"]["tip"]).contains(n) and String(Entity.TIPS["rune_artist"]["more"]).contains(n),
		"the Entity names her in its first-time tip and its topic (%s)" % Entity.TIPS["rune_artist"]["name"])
	t._check(String(Talk.DIALOGUE["how_workshop"]["ask"]).contains(n) and String(Bench.EXCHANGE_TEXT["ask"]).contains(n) and str(Train.OUTFITTER["any"]).contains(n),
		"...the Workshop's topic, the Exchange's question and Joel speak of her by name")
	var about := (String(Help.HELP["rune_artist_npc"]) + String(Entity.TIPS["rune_artist"]["tip"]) + String(Entity.TIPS["rune_artist"]["more"])).to_lower()
	var re_they := RegEx.create_from_string("\\b(they|them|their)\\b")
	t._check(about.contains(" she ") and about.contains(" her") and re_they.search(String(Help.HELP["rune_artist_npc"]).to_lower()) == null, "...as she/her")
	var names := JSON.stringify(Registry.SECTIONS)
	t._check(names.contains(n + ", the Rune Artist"), "the Data editor names her table after her")
	var low := (all + names).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")s?\\b")
	t._check(re.search(low) == null, "no banned words in her lines")


# --- Rayne at the bench --------------------------------------------------------------------------

func _rayne_npc() -> Array:
	return t._car_buttons("rune_artist", true)


func _rayne(main) -> void:
	var menu = main.menu
	menu.train_bench = "temper"
	menu.inv_sel = ""
	t.root.size = Vector2i(1920, 1080)
	main.apply_view_scale()
	await _car(main, "workshop")
	var npc: Array = _rayne_npc()
	t._check(npc.size() == 1 and npc[0] is TrainView.RuneArtist, "Rayne stands at the workshop's bench")
	if npc.size() != 1:
		return
	var who: Control = npc[0]
	var room: Control = menu.train_view.rooms["workshop"]
	var area: Rect2 = room.area.get_global_rect()
	var f: Dictionary = who.figure()
	var neck: Rect2 = f["neck"]
	var head: Vector2 = f["head"]
	var body: Rect2 = f["body"]
	t._check(neck.size.y > 0.0 and neck.size.x > 0.0 and head.y + f["r"] > neck.position.y and head.y < neck.position.y and neck.end.y >= body.position.y,
		"she's drawn with a neck between her head and her shoulders (head %s, neck %s, body from %.0f)" % [head, neck, body.position.y])
	t._check(body.end.y > body.position.y + f["r"] * 6.0 and f["stylus"].y < head.y, "...as a full figure, down to her hem, the stylus raised over her head")
	var r: Rect2 = who.get_global_rect()
	var own: bool = who.get_parent() != null and not who.get_parent().get_children().any(func(c): return c.has_meta("artist_line"))
	t._check(r.size.y >= 160.0 and (not own or r.size.y > area.size.y * 0.3), "she's drawn much bigger than before (%s; %s)" % [r.size, "in her own column" if own else "beside her words"])
	# Where the car has the width, she stands in her own column as tall as it allows.
	var tp = menu.train_page
	var row := HBoxContainer.new()
	var said := HBoxContainer.new()
	var probe := TrainView.RuneArtist.new()
	probe.custom_minimum_size = Vector2(84, 170)
	said.add_child(probe)
	said.add_child(Control.new())
	row.add_child(Control.new())
	row.add_child(Control.new())
	room.area.add_child(row)
	tp._rayne_stands(row, said)
	t._check(probe.get_parent() == row and row.get_child(1) == probe and probe.custom_minimum_size.y >= minf(area.size.y - 24.0 - (70.0 if String(tp.tips.get("workshop", "")) != "" else 0.0), tp.RAYNE_TALL) - 1.0,
		"...with room beside the counters she stands in her own column, as tall as the car allows (%s of %.0f)" % [probe.custom_minimum_size, area.size.y])
	row.queue_free()
	said.queue_free()
	var bubbles: Array = menu.train_page.roots["workshop"].find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("artist_line"))
	t._check(bubbles.size() == 1 and t._all_labels(bubbles[0]).any(func(l): return String(l.text) == RuneArtistName.NAME), "her words carry her name: Rayne")
	t._check(String(Help.explain(menu, who)).contains(RuneArtistName.NAME), "the Entity names her when she's pointed at (%s)" % Help.explain(menu, who))
	t._check(menu.get_viewport_rect().encloses(r), "...and she's on the screen")
	# Effects on Low: no rune motes from her stylus; High: more.
	Particles.set_level("low")
	var low: int = who.motes()
	Particles.set_level("high")
	var high: int = who.motes()
	Particles.set_level("medium")
	t._check(low == 0 and high > who.motes() and who.motes() > 0, "her stylus's rune motes follow the Effects setting (Low %d, Medium %d, High %d)" % [low, who.motes(), high])
	# A computer at 1280 x 720, and a phone: she fits.
	for sz in [Vector2i(1280, 720), Vector2i(800, 400)]:
		t.root.size = sz
		main.touch._set_active(sz.y < 600)
		main.apply_view_scale()
		await _car(main, "workshop")
		npc = _rayne_npc()
		var view: Rect2 = menu.get_viewport_rect()
		var ok: bool = npc.size() == 1 and view.grow(1.0).encloses(npc[0].get_global_rect()) and npc[0].size.y >= 36.0
		t._check(ok, "at %dx%d she fits on the screen, big enough to touch (%s)" % [sz.x, sz.y, npc[0].get_global_rect() if npc.size() == 1 else "none"])
		if npc.size() == 1:
			var nf: Dictionary = npc[0].figure()
			t._check(nf["neck"].size.y > 0.0 and nf["head"].y < nf["neck"].position.y, "...her neck still drawn (%s)" % nf["neck"])
	main.touch._set_active(false)


# --- Joel's neck --------------------------------------------------------------------------------

func _joel(main) -> void:
	var menu = main.menu
	t.root.size = Vector2i(1920, 1080)
	main.apply_view_scale()
	var had: bool = bool(Menu.settings["store_upgrades"])
	Menu.settings["store_upgrades"] = false
	menu.train_store = "shop"
	await _car(main, "store")
	var joel = menu.train_page.store.joel
	var ok: bool = joel != null and is_instance_valid(joel) and joel.get_script() == TrainView.Outfitter
	t._check(ok, "Joel stands behind his counter, full figure (the tree folded)")
	if ok:
		var f: Dictionary = joel.figure()
		var neck: Rect2 = f["neck"]
		var head: Vector2 = f["head"]
		t._check(neck.size.y > f["r"] * 0.3 and head.y < neck.position.y and neck.end.y > f["shoulders"], "Joel has a neck, from under his chin into his collar (head %s, neck %s, shoulders %.0f)" % [head, neck, f["shoulders"]])
		t._check(f["shoulders"] - (head.y + f["r"] * 0.57) > f["r"] * 0.2, "...so his chin sits clear of his shoulders")
	Menu.settings["store_upgrades"] = had


# --- the cars' ambience ---------------------------------------------------------------------------

func _ambience(main) -> void:
	var menu = main.menu
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	var view = menu.train_view
	var ids: Array = view.ids()
	var counts := {}
	for lv in ["low", "medium", "high"]:
		Particles.set_level(lv)
		counts[lv] = {}
		for id in ids:
			counts[lv][id] = view.ambient_count(view.rooms[id])
	var layers := true
	var under := true
	for id in ids:
		var r = view.rooms[id]
		layers = layers and r.ambience != null and is_instance_valid(r.ambience) and r.ambience.material is CanvasItemMaterial
		under = under and r.ambience.get_index() < r.area.get_index()
	t._check(layers and ids.size() == Train.CARS.size(), "every car has its ambience layer, its light added on (%d cars)" % ids.size())
	t._check(under, "...under the car's things, so their words stay clear")
	var all_lit := ids.all(func(id): return int(counts["medium"][id]) > 0)
	var none_low := ids.all(func(id): return int(counts["low"][id]) == 0)
	var more_high := ids.all(func(id): return int(counts["high"][id]) > int(counts["medium"][id]))
	t._check(all_lit, "with Effects on Medium every car has specks of its own life (%s)" % [counts["medium"]])
	t._check(none_low and more_high, "...none on Low and more on High (%s, %s)" % [counts["low"], counts["high"]])
	t._check(view._sconce_spots(view.rooms["store"]).size() == 2 and view._signal_lamps(view.rooms["settings"]).size() == 2 and view.rooms["dining"].steam != Vector2.ZERO,
		"the cars have their own lights: candle sconces, the signal room's lamps, the Dining car's teapot")
	# Every car's ambience draws, on screen.
	Particles.set_level("high")
	for id in ids:
		await _car(main, id)
		view.rooms[id].ambience.queue_redraw()
		await t._frames(2)
	t._check(true, "every car's ambience draws (Effects on High)")
	Particles.set_level("medium")


func _arena(main) -> void:
	t._check(Particles.PRESETS.has("lamp_dust") and float(Particles.PRESETS["lamp_dust"].get("rate", 0.0)) > 0.0, "the Arena car's lamp dust is a particles.gd stream (Effects thins it, Low has none)")
	var car := ArenaCar.new()
	car.main = main
	main.add_child(car)
	await t._frames(1)
	t._check(car.dust.size() == car.lamp_spots().size() and car.dust.all(func(e): return e.live), "the Arena car streams dust in each lamp's light (%d)" % car.dust.size())
	var streams: Array = car.dust.duplicate()
	car.queue_free()
	await t._frames(2)
	t._check(streams.all(func(e): return not e.live), "...and stops when the car goes")


# --- the Dining car's climbers ------------------------------------------------------------------

func _seat(main, n: int) -> void:
	var prof = main.profile
	var st: Dictionary = Dining.state(prof)
	var used: Array = []
	var seats: Array = []
	st["faces"] = {}
	for i in n:
		var rec := Dining.new_face(prof, "kraken", used)
		used.append(String(rec["name"]))
		st["faces"][rec["id"]] = rec
		seats.append(String(rec["id"]))
	st["seats"] = seats
	st["seat_trip"] = int(st["trips"])
	main.menu.train_page.dining._reset()


func _diner_list(main) -> Array:
	var root = main.menu.train_page.roots.get("dining")
	if root == null or not is_instance_valid(root):
		return []
	return root.find_children("*", "Button", true, false).filter(func(b): return b is DiningPage.Diner and b.is_visible_in_tree())


func _diners_fit(main, label: String) -> float:
	var menu = main.menu
	var list: Array = _diner_list(main)
	var view: Rect2 = menu.get_viewport_rect()
	var plac: Array = menu.train_page.roots["dining"].find_children("*", "PanelContainer", true, false).filter(func(p): return p.has_meta("furnish") and p.get_meta("furnish") == "placard")
	var over := false
	for i in list.size():
		var a: Rect2 = list[i].get_global_rect()
		over = over or not view.grow(1.0).encloses(a)
		for p in plac:
			over = over or a.intersects(p.get_global_rect().grow(-2.0))
		for j in range(i + 1, list.size()):
			over = over or a.grow(-1.0).intersects(list[j].get_global_rect().grow(-1.0))
	t._check(not list.is_empty() and not over, "%s: the climbers sit on the screen, apart, clear of the placard (%d)" % [label, list.size()])
	return list[0].get_global_rect().size.y if not list.is_empty() else 0.0


func _diners(main) -> void:
	var menu = main.menu
	var base: Vector2 = DiningPage.DINER[0]
	t.root.size = Vector2i(1280, 720)
	main.touch._set_active(false)
	main.apply_view_scale()
	_seat(main, 3)
	await _car(main, "dining")
	var few := _diners_fit(main, "1280x720, three climbers")
	var list: Array = _diner_list(main)
	var k: float = list[0].figure_scale() if not list.is_empty() else 0.0
	t._check(few > base.y * 1.4 and k > (base.y * 0.6 - 4.0) / 150.0 * 1.4, "three climbers are drawn much bigger than before (%.0f tall, against %.0f)" % [few, base.y])
	_seat(main, 9)
	await _car(main, "dining")
	var many := _diners_fit(main, "1280x720, nine climbers")
	t._check(many < few and many >= base.y, "nine climbers are drawn smaller, to fit (%.0f against %.0f), never below their old size" % [many, few])
	t.root.size = Vector2i(1920, 1080)
	main.apply_view_scale()
	_seat(main, 3)
	await _car(main, "dining")
	var wide := _diners_fit(main, "1920x1080, three climbers")
	t._check(wide >= few, "a bigger window draws them bigger still (%.0f)" % wide)
	for n in [3, 6]:
		t.root.size = Vector2i(800, 400)
		main.touch._set_active(true)
		main.apply_view_scale()
		_seat(main, n)
		await _car(main, "dining")
		var ph := _diners_fit(main, "a phone, %d climbers" % n)
		t._check(ph >= DiningPage.DINER[1].y, "...each at least its old phone size (%.0f)" % ph)
	main.touch._set_active(false)
