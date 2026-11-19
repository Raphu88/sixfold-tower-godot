extends RefCounted
## Six stations and travel (travel.gd, stations.gd, engine_page.gd,
## tour.gd): six stations on a loop in tower order, each with its own Noble
## and colours; the loop distance (the shorter way round); fares of 12
## crystals a stop and titles' discounts; travel locked until the first
## mark (or the Unbound path); riding the train from the engine's map
## (paid, moved, its tower then open to climb); the home and current
## station saved with the climber; stepping off at the station you're at;
## the Entity's tours in the owner's order (the station: gym, tournament
## grounds, the Noble's estate, the train; the train: the climbers' car,
## outfitter, workshop, dining car, settings and controls, the engine's
## map), skippable and replayed from its talk; first-time moments, the
## "How does it work?" topic and help on every new button; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Travel := preload("res://scripts/travel.gd")
const Stations := preload("res://scripts/stations.gd")
const Towers := preload("res://scripts/towers.gd")
const Noble := preload("res://scripts/noble.gd")
const Titles := preload("res://scripts/titles.gd")
const Renown := preload("res://scripts/renown.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Guide := preload("res://scripts/guide.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("travel: six stations on a loop, fares, the lock, the map and the Entity's tours")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	_stations()
	_loop()
	_fares()
	_lock_and_ride()
	_saves()
	_words()
	await _engine(main)
	await _tours(main)
	await _talk(main)
	await _phone(main)
	main.menu.tour.finish()
	main.menu.station_page.station = ""
	main.menu.close()
	main.profile.station = ""
	t.paused = false
	main.on_train = false
	await t._frames(2)


func _fresh_profile():
	var p = ProfileScript.new()
	p.saving = false
	p.save_path = TestRun.path("user://travel_test.cfg")
	return p


# --- the stations ---------------------------------------------------------------------------

func _stations() -> void:
	var ids := Stations.station_ids()
	t._check(ids.size() == 6 and Travel.loop() == Towers.ORDER, "six stations, one near each tower, on a loop in tower order (%s)" % [Travel.loop()])
	var nobles := {}
	var lamps := {}
	var banners := {}
	var ok := true
	for s in Stations.STATIONS:
		var id := String(s["id"])
		nobles[Noble.name_of(id)] = true
		lamps[str(s.get("lamp"))] = true
		banners[str(s.get("banner"))] = true
		if Travel.tower_of(id) != String(s["tower"]) or Travel.station_for(String(s["tower"])) != id or Stations.stops(id) != ["gym", "arena", "noble", "board"]:
			ok = false
		if not String(s["name"]).begins_with("(") or not String(s["noble"]).begins_with("("):
			ok = false  # (placeholder names, the owner's to write)
	t._check(ok, "each station is near its tower, has the same stops (Training, Tournament, the Noble, the Renown Board) and placeholder names")
	t._check(nobles.size() == 6 and lamps.size() == 6 and banners.size() == 6, "each station has its own Noble and its own colours (%d nobles, %d lamps, %d banners)" % [nobles.size(), lamps.size(), banners.size()])
	t._check(Titles.GROUPS.any(func(g): return String(g[0]) == "travel") and Renown.TITLES.size() > 0, "titles are shared by every Noble: one table, with a Train fares benefit group")


func _loop() -> void:
	var cases := [["gryphon", "kraken", 1], ["gryphon", "wyvern", 2], ["gryphon", "manticore", 3], ["gryphon", "firebird", 2], ["gryphon", "chimera", 1],
		["kraken", "firebird", 3], ["wyvern", "chimera", 3], ["chimera", "kraken", 2], ["manticore", "manticore", 0]]
	var bad: Array = []
	for c in cases:
		if Travel.stops(String(c[0]), String(c[1])) != int(c[2]) or Travel.stops(String(c[1]), String(c[0])) != int(c[2]):
			bad.append(c)
	t._check(bad.is_empty() and Travel.max_stops() == 3, "the loop distance is the shorter way round, both ways, 3 stops at most (%s)" % [bad])


func _fares() -> void:
	var p = _fresh_profile()
	var fares := {}
	for a in Travel.loop():
		p.station = a
		for b in Travel.loop():
			if a != b:
				fares[Travel.fare(p, b)] = true
	var list: Array = fares.keys()
	list.sort()
	t._check(Travel.FARE == 12 and list == [12, 24, 36], "the fare is 12 crystals a stop, so 12, 24 or 36 (%s)" % [list])
	var cuts: Array = []
	for id in Titles.SOCIAL:
		var c := float(Titles.of(String(id), "travel").get("fare_cut", 0.0))
		if c > 0.0:
			cuts.append(c)
	t._check(not cuts.is_empty() and cuts.all(func(c): return c <= 0.5), "some titles cut the fare, modestly (at most half: %s)" % [cuts])
	p.station = "gryphon"
	Renown.state(p)["titles"] = ["stairworn", "paragon"]
	Renown.state(p)["worn"] = "stairworn"
	var quarter := Travel.fare(p, "manticore")
	Renown.state(p)["worn"] = "paragon"
	var half := Travel.fare(p, "manticore")
	Renown.state(p)["worn"] = ""
	t._check(quarter == 27 and half == 18 and Travel.fare(p, "manticore") == 36, "a worn title's cut applies to every stop (a quarter off: %d, half: %d, none: 36)" % [quarter, half])
	t._check(Titles.lines("stairworn").any(func(l): return String(l).contains("Fares")), "...and the title's card says so")


func _lock_and_ride() -> void:
	var p = _fresh_profile()
	p.add_crystal("stone", 30.0)
	t._check(not Travel.unlocked(p) and Travel.why_not(p, "kraken") == String(Travel.TEXT["lock_why"]), "travel is locked before the first mark")
	var res := Travel.ride(p, "kraken")
	t._check(not bool(res["ok"]) and Travel.current(p) == "gryphon" and p.crystals_held() == 30.0, "...a ride is refused: nothing paid, still at home")
	Unbound.state(p)["on"] = true
	t._check(Travel.unlocked(p), "becoming Unbound opens travel too")
	Unbound.state(p)["on"] = false
	p.add_bond("hand", "stormcaller", true)
	t._check(Travel.unlocked(p), "the first mark (even a faint one) opens travel")
	t._check(Travel.why_not(p, "gryphon") == "?", "...riding to where you are isn't a ride")
	res = Travel.ride(p, "wyvern")
	t._check(bool(res["ok"]) and int(res["fare"]) == 24 and Travel.current(p) == "wyvern" and p.crystals_held() == 6.0 and String(res["line"]).contains("24"),
		"a ride pays its fare in crystals of any kind and moves you there (%s)" % [res])
	res = Travel.ride(p, "chimera")
	t._check(not bool(res["ok"]) and String(res["why"]).contains("30") and Travel.current(p) == "wyvern", "a fare you can't pay says how much more it needs (%s)" % [res.get("why", "")])


func _saves() -> void:
	var path := TestRun.path("user://travel_saves.cfg")
	var p = ProfileScript.new()
	p.save_path = path
	t._check(p.home == "gryphon" and p.station == "" and Travel.current(p) == "gryphon", "a new climber's home is the Gryphon's station until the questions set it")
	p.home = "kraken"
	t._check(Travel.home(p) == "kraken" and Travel.current(p) == "kraken", "the home station is the one near profile.home, and you start there")
	p.station = "firebird"
	p.save()
	var q = ProfileScript.new()
	q.save_path = path
	q.load_save()
	t._check(q.home == "kraken" and q.station == "firebird" and Travel.current(q) == "firebird", "the home and the station you're at save with the climber")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _words() -> void:
	var texts: Array = []
	for k in Travel.TEXT:
		texts.append(String(Travel.TEXT[k]))
	for kind in Travel.TOURS:
		for s in Travel.TOURS[kind]:
			texts.append(String(s.get("say", "")))
			texts.append(String(s.get("point_say", "")))
	for id in ["travel", "travel_lock", "fares", "tour_station", "tour_train", "station"]:
		texts.append(String(Entity.TIPS.get(id, {}).get("tip", "")))
		texts.append(String(Entity.TIPS.get(id, {}).get("more", "")))
	for id in ["how_travel", "tour"]:
		texts.append_array(Talk.DIALOGUE.get(id, {}).get("lines", []))
	for s in Stations.STATIONS:
		texts.append(String(s["name"]) + " " + String(s["noble"]) + " " + String(s["sub"]))
	var bad: Array = []
	for tx in texts:
		for w in BANNED:
			if String(tx).to_lower().contains(w):
				bad.append(w)
	t._check(bad.is_empty(), "no banned words in stations and travel (%s)" % [bad])
	t._check(["travel", "travel_lock", "fares", "tour_station", "tour_train"].all(func(id): return Entity.TIPS.has(id) and String(Entity.TIPS[id]["tip"]) != ""),
		"the Entity has first-time moments for the map, the lock, fares and its tours (each in the Archive)")
	var p = _fresh_profile()
	t._check(Travel.engine_tips(p) == ["travel", "travel_lock"], "...before the first mark the engine's moment is the lock")
	p.add_bond("hand", "stormcaller", false)
	t._check(Travel.engine_tips(p) == ["travel", "fares"], "...after it, the fares")


# --- the engine's map --------------------------------------------------------------------

func _engine(main) -> void:
	var menu = main.menu
	var prof = main.profile
	prof.bonds = {}
	prof.regarded = true
	main.first_climb = false
	prof.station = ""
	prof.crystals = []
	main.open_train()
	await t._frames(2)
	menu.train_car = "engine"
	menu.train_tower = ""
	menu.open("train")
	await t._frames(3)
	var stops: Array = t._all_buttons(menu.train_page.roots["engine"]).filter(func(b): return b.has_meta("tower"))
	t._check(stops.size() == 6 and menu.train_tower == "gryphon", "the engine's map shows the six towers, and the one by your station is chosen (%s)" % menu.train_tower)
	t._check(t._car_buttons("depart", "gryphon").size() == 1 and t._car_buttons("go_station", "gryphon").size() == 1, "...its lever departs for that tower, and Step off is there")
	var maps: Array = menu.train_page.roots["engine"].find_children("*", "Control", true, false).filter(func(c): return c.has_meta("travel_map"))
	t._check(maps.size() == 1, "the map is drawn as a loop")
	var kr: Array = t._car_buttons("tower", "kraken")
	if kr.size() == 1:
		kr[0].pressed.emit()
		await t._frames(3)
	var locks: Array = menu.train_page.roots["engine"].find_children("*", "Control", true, false).filter(func(c): return c.has_meta("travel_lock"))
	t._check(menu.train_tower == "kraken" and t._car_buttons("travel", "kraken").is_empty() and t._car_buttons("depart", "kraken").is_empty() and locks.size() == 1,
		"before the first mark another tower shows the lock: no ride, no climb")
	stops = t._all_buttons(menu.train_page.roots["engine"]).filter(func(b): return b.has_meta("tower"))
	t._check(stops.size() == 6 and stops.all(func(b): return not Help.missing(b) and not Help.explain(menu, b).contains("{")), "every stop on the map has the Entity's help, filled in")
	main.grant_test_bonds()
	prof.add_crystal("water", 20.0)
	menu.open("train")
	await t._frames(3)
	var lever: Array = t._car_buttons("travel", "kraken")
	var fare_shown: bool = t._all_labels(menu.train_page.roots["engine"]).any(func(l): return l.text.contains("1 stop"))
	t._check(lever.size() == 1 and fare_shown and not Help.missing(lever[0]) and Help.explain(menu, lever[0]).contains("12"), "after it, the placard offers the ride: stops, fare, a lever with help")
	if lever.size() == 1:
		lever[0].pressed.emit()
		await t._frames(3)
	t._check(Travel.current(prof) == "kraken" and prof.crystals_held() == 8.0 and menu.train_tower == "kraken" and t._car_buttons("depart", "kraken").size() == 1,
		"pulling it pays 12 and takes you to the Kraken's station; its tower is now the one to climb")
	t._check(t._all_labels(menu.train_page.roots["engine"]).any(func(l): return l.text.contains(String(Travel.TEXT["rode"]).get_slice("%", 0))), "...and the placard says the train pulled in")
	var off: Array = t._car_buttons("go_station", "kraken")
	if off.size() == 1:
		off[0].pressed.emit()
		await t._frames(3)
	t._check(menu.page == "station" and menu.station_page.station == "kraken" and String(menu.station_view.look.get("tower", "")) == "kraken", "Step off takes you to the station you're at, drawn in its own colours")
	var crest: Array = menu.box.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("station_crest"))
	t._check(crest.size() == 1 and String(crest[0].get_meta("station_crest")) == "kraken", "...with its crest under the title")
	menu.go_station("kraken", "noble")
	await t._frames(2)
	t._check(t._all_labels(menu.box).any(func(l): return l.text == Noble.name_of("kraken")) and t._all_labels(menu.box).any(func(l): return l.text == String(Travel.TEXT["shared_titles"])),
		"its Noble is its own, and the titles are shared by every Noble")
	menu.leave_station()
	await t._frames(2)


# --- the Entity's tours ---------------------------------------------------------------------

func _tours(main) -> void:
	var menu = main.menu
	var tour = menu.tour
	var st: Array = Travel.TOURS["station"].map(func(s): return String(s["point"][1]))
	t._check(st == ["gym", "arena", "noble", "leave_station"], "the station's tour: the gym, the tournament grounds, the Noble's estate, the train (%s)" % [st])
	var cars: Array = []
	for s in Travel.TOURS["train"]:
		if cars.is_empty() or cars[-1] != String(s["car"]):
			cars.append(String(s["car"]))
	t._check(cars == ["personal", "store", "workshop", "dining", "settings", "engine"] and Travel.TOURS["train"][-1]["point"][0] == "travel_map",
		"the train's tour: the climbers' car, outfitter, workshop, dining car, settings and controls, and last the engine's map (%s)" % [cars])
	t._check(Travel.TOURS["train"].filter(func(s): return String(s["car"]) == "personal").size() >= 3, "...the climbers' car explaining its things one by one")
	# The station's tour, step by step.
	tour.start("station")
	await t._frames(3)
	var where: Array = []
	var found := true
	for i in Travel.TOURS["station"].size():
		where.append(menu.station_page.stop)
		if tour.target() == null:
			found = false
		var bar: Array = menu.box.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("tour_bar"))
		if bar.size() != 1:
			found = false
		if i < Travel.TOURS["station"].size() - 1:
			tour.next()
			await t._frames(3)
	t._check(menu.page == "station" and where.slice(0, 3) == ["gym", "arena", "noble"] and found, "the station's tour walks its stops, points at each and shows its bar (%s)" % [where])
	menu.nav_keys = false
	t._mouse_move(menu.get_viewport_rect().size - Vector2(4, 4))  # (the pointer on nothing: an earlier part may have left it on a button)
	await t._until(func(): return menu.helper.target != null and menu.helper.target == tour.target(), 2.0)
	t._check(menu.helper.target == tour.target() and menu.helper.text == tour.point_words(), "the Entity's sphere goes beside what the step points at and says so (%s %s %s %s)" % [menu.helper.target, tour.target(), menu.helper.text, menu.helper.active()])
	var buttons: Array = t._all_buttons(menu.box).filter(func(b): return b.has_meta("tour"))
	t._check(buttons.size() == 3 and buttons.all(func(b): return not Help.missing(b)), "Back, Done and Skip the tour, each with the Entity's help")
	tour.next()
	await t._frames(2)
	t._check(not tour.active() and menu.page == "station", "Done ends the tour, still at the station")
	tour.start("station")
	await t._frames(2)
	tour.skip()
	await t._frames(2)
	t._check(not tour.active() and menu.box.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("tour_bar")).is_empty(), "Skip the tour ends it at once")
	# The train's tour.
	tour.start("train")
	await t._frames(3)
	var seen: Array = []
	var ok := true
	for i in Travel.TOURS["train"].size():
		await t._frames(2)
		seen.append(String(menu.train_car))
		if tour.target() == null:
			ok = false
			print("    (no target at step %d: %s)" % [i, Travel.TOURS["train"][i]["point"]])
		if i < Travel.TOURS["train"].size() - 1:
			tour.next()
	t._check(menu.page == "train" and not menu.at_station() and ok and seen[0] == "personal" and seen[-1] == "engine", "the train's tour moves car to car and finds what each step points at (%s)" % [seen])
	tour.next()
	await t._frames(2)
	t._check(not tour.active(), "...and ends on the engine")
	# The station's tour ends if you board the train.
	menu.go_station(Travel.current(main.profile), "gym")
	await t._frames(2)
	tour.start("station")
	await t._frames(2)
	menu.leave_station()
	await t._frames(2)
	t._check(not tour.active() or tour.which == "train", "leaving the station ends its tour")
	tour.finish()
	# The first time, by itself (with the Entity's tips on).
	Engine.set_meta("sixfold_tips", true)
	Engine.set_meta("sixfold_tours", true)
	var keep: Dictionary = Guide.state.duplicate(true)
	Guide.forget()
	menu.go_station(Travel.current(main.profile), "board")
	await t._frames(3)
	var auto_station: bool = tour.active() and tour.which == "station" and menu.station_page.stop == "gym"
	tour.skip()
	await t._frames(2)
	menu.leave_station()
	await t._frames(3)
	var auto_train: bool = tour.active() and tour.which == "train" and menu.train_car == "personal"
	tour.skip()
	await t._frames(2)
	menu.go_station(Travel.current(main.profile), "gym")
	await t._frames(2)
	var not_again: bool = not tour.active()
	menu.leave_station()
	await t._frames(2)
	t._check(auto_station and auto_train and not_again and Tour_seen("station") and Tour_seen("train"), "the first time at a station and on the train the tour starts by itself, and only once (%s %s %s)" % [auto_station, auto_train, not_again])
	Guide.state = keep
	Guide.queue.clear()
	Guide.held.clear()
	Engine.remove_meta("sixfold_tips")
	Engine.remove_meta("sixfold_tours")


func Tour_seen(kind: String) -> bool:
	return Guide.told("tour_" + kind)


func _talk(main) -> void:
	var menu = main.menu
	t._check(Talk.DIALOGUE["how"]["choices"].has("how_travel") and Talk.DIALOGUE["start"]["choices"].has("tour"), "the Entity's talk: \"Stations and travel?\" under How does it work, and \"Show me around again\"")
	var line := Talk.line_for(main, "how_travel")
	t._check(line.contains("12") and line.contains("36") and line.contains(String(Stations.station(Travel.current(main.profile))["name"])) and not line.contains("{"), "...its answer reads the game: the fare, the most, where you are (%s)" % line.left(90))
	menu.open_talk()
	await t._frames(2)
	menu.talk.node = "tour"
	menu.talk.say(main)
	var list: Array = menu.talk.choices(main)
	var idx := -1
	for i in list.size():
		if String(list[i]["id"]) == "tour_train":
			idx = i
	t._check(idx >= 0, "Show me around again offers the station and the train")
	if idx >= 0:
		menu._talk_choose(idx)
		await t._frames(3)
	t._check(menu.tour.active() and menu.tour.which == "train" and menu.page == "train", "choosing one replays that tour")
	menu.tour.skip()
	await t._frames(2)


## The map and the tour's bar at a phone's size: nothing runs off across.
func _phone(main) -> void:
	var menu = main.menu
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(844, 390)
	main.touch._set_active(true)
	main.apply_view_scale()
	await t._frames(2)
	menu.train_car = "engine"
	menu.train_tower = "wyvern"
	menu.open("train")
	await t._frames(4)
	var vw: float = menu.get_viewport_rect().size.x
	var over: Array = []
	for b in t._all_buttons(menu.train_page.roots["engine"]):
		if b.is_visible_in_tree():
			var r: Rect2 = b.get_global_rect()
			if r.position.x < -1.0 or r.end.x > vw + 1.0:
				over.append(str(b.get_meta("tower", b.text)))
	t._check(over.is_empty() and t._car_buttons("travel", "wyvern").size() == 1, "on a phone the map and its placard fit across the screen (%s %s %s %s)" % [over, menu.train_car, menu.train_tower, Travel.current(main.profile)])
	var tl: Array = t._car_buttons("tower", "gryphon")
	if tl.size() == 1:
		await t._tap_at(tl[0].get_global_rect().get_center())
	t._check(menu.train_tower == "gryphon", "a tap on a stop chooses it")
	menu.tour.start("train")
	await t._frames(4)
	var nb: Array = t._all_buttons(menu.train_page.roots.get(menu.train_car)).filter(func(b): return b.get_meta("tour", "") == "next")
	if nb.size() == 1:
		await t._tap_at(nb[0].get_global_rect().get_center())
	t._check(menu.tour.step == 1, "a tap on Next moves the tour on")
	menu.tour.skip()
	main.touch._set_active(false)
	t.root.size = was
	main.apply_view_scale()
	await t._frames(2)
