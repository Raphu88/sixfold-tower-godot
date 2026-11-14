extends RefCounted
## The Entity on the train (entity_helper.gd, entity_help.gd) and talking
## with it (entity_talk.gd, menu.gd's "talk" page, guide.gd's Talk): its
## sphere is on every car, page and station stop, resting clear of every
## button; hovering (mouse) or moving onto (keys) a button sends it beside
## the button with the right words, after a short wait (a sweep of the mouse
## doesn't move it); a finger held on a button explains it without pressing
## it, and a tap still presses at once; the bubble never covers the button
## and stays on the screen, on a phone too; the Settings switch turns it
## off; no train button lacks words of its own; the talk opens from the
## sphere (a click, a tap, L) and from the panel in play, its choices go by
## mouse, keys and touch, its answers come from the game's facts, the
## owner's story slots stay hidden until written, and Esc or Goodbye
## leaves. No banned words in its tables. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const Help := preload("res://scripts/entity_help.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Helper := preload("res://scripts/entity_helper.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Stations := preload("res://scripts/stations.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Guide := preload("res://scripts/guide.gd")
const Towers := preload("res://scripts/towers.gd")
const Nav := preload("res://scripts/nav.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var M = load("res://scripts/menu.gd")
var keep_ui := ""
var keep_size := Vector2i.ZERO
var keep_help := true


func run(smoke) -> void:
	t = smoke
	print("the Entity on the train: explaining buttons, and talking with it")
	await _begin()
	await _everywhere()
	await _hover_and_keys()
	await _phone()
	await _toggle()
	await _missing()
	await _talk()
	await _talk_in_play()
	_banned()
	await _end()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _menu():
	return t.main.menu


func _helper():
	return t.main.menu.helper


func _begin() -> void:
	keep_ui = String(M.settings["ui_size"])
	keep_size = t.root.size
	keep_help = bool(M.settings.get("entity_help", true))
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	t.root.size = Vector2i(1280, 720)
	M.settings["ui_size"] = "normal"
	M.settings["entity_help"] = true
	main.apply_view_scale()
	var prof = main.profile
	for k in Essence.KINDS:
		prof.add_crystal(k, 300)
	prof.pack = [Gear.make("leather_cap")]
	prof.chest = [Gear.make("iron_helm"), Gear.make("travel_cloak")]
	prof.supplies = {}
	main.open_train()
	await t._frames(3)


func _end() -> void:
	var main = t.main
	var menu = _menu()
	if menu.page == "talk":
		menu.leave_talk()
	menu.close()
	t.paused = false
	main.on_train = false
	main.touch._set_active(false)
	M.settings["ui_size"] = keep_ui
	M.settings["entity_help"] = keep_help
	t.root.size = keep_size
	main.apply_view_scale()
	await t._frames(2)


## Waits until the train has stopped sliding.
func _settled() -> void:
	var v = _menu().train_view
	for i in 240:
		if v.pos == float(v.target):
			break
		await t.process_frame
	await t._frames(2)


func _car(car: String) -> void:
	var menu = _menu()
	menu.train_car = car
	menu.open("train")
	await t._frames(2)
	menu.train_page.go_to(menu.train_page._index(car))
	await _settled()


## A circle of the sphere's size at `c`, as a box.
func _orb_box(c: Vector2) -> Rect2:
	return Rect2(c - Vector2(Helper.ORB_R, Helper.ORB_R), Vector2(Helper.ORB_R, Helper.ORB_R) * 2.0)


## The button in the car (or page) with this tag, or null.
func _find(meta: String, val = null) -> Control:
	for b in _helper().buttons():
		if b.has_meta(meta) and (val == null or b.get_meta(meta) == val):
			return b
	return null


# --- the sphere on every car and page ----------------------------------------------------

func _everywhere() -> void:
	var menu = _menu()
	var h = _helper()
	var bad: Array = []
	var where: Array = []
	for c in Train.CARS:
		await _car(c[0])
		where.append("car " + c[0])
	for pg in ["loadout", "stash", "climber"]:
		where.append("page " + pg)
	var view := Rect2(Vector2.ZERO, Vector2(t.root.size))
	for w in where:
		if w.begins_with("page "):
			menu.open(w.trim_prefix("page "), true)
			await t._frames(4)
		else:
			await _car(w.trim_prefix("car "))
		await t._wait(0.9)
		await t._frames(2)
		var ok: bool = h.active() and h.pos.x >= 0.0 and view.encloses(_orb_box(h.pos))
		var hit: Array = h.buttons().filter(func(b): return b.get_global_rect().intersects(_orb_box(h.pos)))
		if not ok or not hit.is_empty() or h.pos.distance_to(h.rest) > 4.0 or h.target != null:
			bad.append("%s (at %s, over %d buttons)" % [w, h.pos, hit.size()])
	menu.close()
	await t._frames(2)
	menu.go_station(String(Stations.STATIONS[0]["id"]), "gym")
	await t._frames(3)
	for stop in menu.station_page.stop_ids():
		menu.go_station(menu.station_page.station, stop)
		await t._frames(3)
		var hit2: Array = h.buttons().filter(func(b): return b.get_global_rect().intersects(_orb_box(h.pos)))
		if not h.active() or h.pos.x < 0.0 or not hit2.is_empty():
			bad.append("station %s" % stop)
	menu.leave_station()
	await t._frames(3)
	_check(bad.is_empty(), "the Entity's sphere rests on every car, page and station stop, over no button (%s)" % [bad])
	# Nowhere else: not in play, not on the title.
	menu.close()
	await t._frames(1)
	_check(h.active(), "...and on the train itself")


# --- pointing at a button: the mouse and the keys ----------------------------------------------

func _hover_and_keys() -> void:
	var menu = _menu()
	var h = _helper()
	await _car("personal")
	# The mouse on the rail's Outfitter's Car: after a moment, beside it, with its words.
	var rail_b: Control = menu.rail.button("store")
	var at: Vector2 = rail_b.get_global_rect().get_center()
	t._mouse_move(at)
	await t._frames(3)
	_check(h.target == null, "a hover waits a moment before the Entity moves")
	await t._wait(Helper.DELAY + 0.25)
	await t._frames(2)
	_check(h.target == rail_b and h.text == String(Help.HELP["rail:store"]), "hovering the rail's Outfitter's Car: it says where it goes (%s)" % h.text)
	await t._wait(0.4)
	var br: Rect2 = rail_b.get_global_rect()
	var rail_r: Rect2 = menu.rail.get_global_rect()
	_check(not h.bubble.intersects(br) and not _orb_box(h.pos).intersects(br.grow(-1.0)) and not h.bubble.intersects(rail_r), "...beside it, not over it nor the rail")
	var beside := Rect2(br.position, Vector2(rail_r.end.x - br.position.x, br.size.y))
	_check(beside.grow(Helper.GAP + Helper.ORB_R * 2.0 + 2.0).has_point(h.pos), "...the sphere right next to it, just past the rail (%s by %s)" % [h.pos, br])
	_check(Rect2(Vector2.ZERO, Vector2(t.root.size)).encloses(h.bubble), "...its bubble on the screen")
	# A piece in your stash: its name, from its own card.
	var slot: Control = _find("slot", "chest:0")
	t._mouse_move(slot.get_global_rect().get_center())
	await t._wait(Helper.DELAY + 0.25)
	await t._frames(2)
	_check(h.target == slot and h.text.contains(Gear.display(t.main.profile.chest[0])) and h.text.contains("stash"), "hovering a stash piece: its name and where it is (%s)" % h.text)
	# A sweep across many buttons doesn't send it flying.
	var shown: int = h.explained
	for b in h.buttons().slice(0, 10):
		t._mouse_move(b.get_global_rect().get_center())
		await t._frames(1)
	await t._frames(1)
	_check(h.explained == shown, "sweeping the mouse across the buttons doesn't make it fly about")
	# Off every button: back to its corner.
	t._mouse_move(Vector2(t.root.size) * Vector2(0.62, 0.04))
	await t._wait(Helper.DELAY + Helper.LEAVE + 0.5)
	await t._frames(2)
	_check(h.target == null and h.pos.distance_to(h.rest) < 20.0, "away from the buttons it goes back to its corner")
	# The keys: the focus on the Loadout button.
	var lo: Control = _find("car_page", "loadout")
	menu.nav_keys = true
	lo.grab_focus()
	await t._wait(Helper.DELAY_KEYS + 0.25)
	await t._frames(2)
	_check(h.target == lo and h.text == String(Help.HELP["car_page:loadout"]), "moving onto a button by the keys explains it too (%s)" % h.text)
	# A store card's Sell: its price.
	await _car("store")
	menu.train_store = "sell"
	menu.inv_sel = "pack:0"
	menu.open("train")
	await t._frames(3)
	var sell: Control = _find("sell", "pack:0")
	menu.nav_keys = true
	if sell != null:
		sell.grab_focus()
	await t._wait(Helper.DELAY_KEYS + 0.25)
	await t._frames(2)
	var price := Train.price_text(Train.gear_kind(t.main.profile.pack[0]), Train.gear_sell(t.main.profile.pack[0]))
	_check(sell != null and h.target == sell and h.text.contains(price), "Sell says what the outfitter pays (%s)" % h.text)
	menu.train_store = "shop"
	menu.inv_sel = ""
	await _car("engine")
	var tower: Control = _find("tower", "gryphon")
	tower.grab_focus()
	await t._wait(Helper.DELAY_KEYS + 0.25)
	await t._frames(2)
	_check(h.target == tower and h.text.contains("Gryphon") and h.text.contains("Air"), "a tower's plaque: its essence and its beast (%s)" % h.text)
	menu.nav_keys = false
	t.root.gui_release_focus()


# --- a phone: press and hold, and the bubble's place --------------------------------------------

func _phone() -> void:
	var menu = _menu()
	var h = _helper()
	var main = t.main
	t.root.size = Vector2i(915, 412)
	main.apply_view_scale()
	main.touch._set_active(true)
	await _car("store")
	menu.train_store = "shop"
	menu.open("train")
	await t._frames(3)
	var sell_tab: Control = _find("store_tab", "sell")
	var at: Vector2 = sell_tab.get_global_rect().get_center()
	# Held: the explanation, and letting go doesn't press it.
	t._touch(0, at, true)
	await t._wait(Helper.HOLD + 0.2)
	await t._frames(2)
	_check(h.target == sell_tab and h.text == String(Help.HELP["store_tab:sell"]), "a finger held on a button: the Entity explains it (%s)" % h.text)
	t._touch(0, at, false)
	await t._frames(3)
	_check(menu.train_store == "shop", "...and letting go doesn't press it")
	await t._frames(2)
	var view := Rect2(Vector2.ZERO, Vector2(t.root.size))
	_check(view.encloses(h.bubble) and not h.bubble.intersects(sell_tab.get_global_rect()), "...its bubble on a phone's screen, off the button")
	# A tap still presses at once.
	await t._tap_at(at)
	await t._frames(2)
	_check(menu.train_store == "sell", "a tap still presses the button at once")
	menu.train_store = "shop"
	# A finger that moves is a swipe, not a hold.
	await _car("personal")
	var slot: Control = _find("slot", "chest:0")
	var p0: Vector2 = slot.get_global_rect().get_center()
	var before: int = h.explained
	t._touch(0, p0, true)
	await t._frames(1)
	t._drag(0, p0 + Vector2(40, 0))
	await t._wait(Helper.HOLD + 0.2)
	t._touch(0, p0 + Vector2(40, 0), false)
	await _settled()
	_check(h.explained == before, "a finger that slides is a swipe, not a hold")
	await _car("personal")
	# Every button on every car: the bubble beside it, never over it, on the screen, off the rail.
	var bad: Array = []
	var count := 0
	for c in Train.CARS:
		await _car(c[0])
		var rail: Rect2 = menu.rail.get_global_rect()
		for b in h.buttons():
			var r: Rect2 = b.get_global_rect()
			var sc = Nav.scroll_of(b)
			if sc != null:
				r = r.intersection(sc.get_global_rect())
			if r.size.x < 4.0 or r.size.y < 4.0 or not view.encloses(r):
				continue
			var words: String = Help.explain(menu, b)
			if words == "":
				continue
			var p: Dictionary = h.place(b.get_global_rect(), words)
			var area: Rect2 = p["bubble"].merge(_orb_box(p["orb"]))
			count += 1
			var on_rail: bool = not menu.rail.buttons.has(b) and area.intersects(rail)
			if not view.encloses(area) or area.intersects(r) or on_rail:
				bad.append("%s %s" % [c[0], Help.key_for(b)])
	_check(count > 40 and bad.is_empty(), "on a phone every bubble (%d) sits beside its button, on the screen and off the rail (%s)" % [count, bad.slice(0, 8)])
	main.touch._set_active(false)
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	await t._frames(3)


# --- the Settings switch --------------------------------------------------------------------

func _toggle() -> void:
	var menu = _menu()
	var h = _helper()
	await _car("settings")
	var sw: Control = _find("setting", "entity_help")
	_check(sw != null and sw is CheckButton and sw.button_pressed, "Settings has the switch: the Entity explains buttons, beside its tips")
	if sw != null:
		sw.button_pressed = false  # (toggled: saved in the settings)
		await t._frames(2)
	_check(not bool(M.settings["entity_help"]), "...turning it off is kept")
	await _car("personal")
	var lo: Control = _find("car_page", "loadout")
	menu.nav_keys = true
	lo.grab_focus()
	await t._wait(Helper.DELAY + 0.3)
	_check(h.target == null and h.active() and h.pos.distance_to(h.rest) < 20.0, "...then the sphere only rests")
	M.settings["entity_help"] = true
	await t._wait(Helper.DELAY + 0.3)
	_check(h.target == lo, "...and turned on again, it explains")
	menu.nav_keys = false
	t.root.gui_release_focus()


# --- no button forgotten ---------------------------------------------------------------------

func _missing() -> void:
	var menu = _menu()
	var h = _helper()
	var main = t.main
	var lacking := {}
	var seen := 0
	var views: Array = [["engine", {"train_board": "towers"}], ["engine", {"train_board": "stations"}], ["store", {"train_store": "shop", "inv_sel": "outfit:0"}],
		["store", {"train_store": "shop", "inv_sel": "supply:draught"}], ["store", {"train_store": "shop", "inv_sel": "today"}],
		["store", {"train_store": "shop", "inv_sel": "upgrades"}], ["store", {"train_store": "sell", "inv_sel": "pack:0"}],
		["personal", {"inv_sel": "worn:melee"}], ["personal", {"inv_sel": "chest:0"}], ["library", {}],
		["settings", {"settings_tab": "settings"}], ["settings", {"settings_tab": "controls"}]]
	for c in Bench.COUNTERS:
		views.append(["workshop", {"train_bench": c[0], "inv_sel": ""}])
	views.append(["workshop", {"train_bench": "brew", "inv_sel": "bench:item:draught"}])
	views.append(["workshop", {"train_bench": "break", "inv_sel": "bench:pack:0"}])
	main.profile.supplies = {"draught": 1}
	for v in views:
		for k in v[1]:
			menu.set(k, v[1][k])
		menu.train_sel[v[0]] = menu.inv_sel
		await _car(v[0])
		for b in h.buttons():
			seen += 1
			if Help.missing(b):
				lacking["%s: %s" % [v[0], Help.words(b)]] = true
	menu.train_board = "towers"
	menu.train_store = "shop"
	menu.train_bench = "brew"
	menu.settings_tab = "settings"
	for pg in ["loadout", "stash"]:
		for sel in ["worn:helm", "pack:0", "chest:0"]:
			menu.inv_sel = sel
			menu.open(pg, true)
			await t._frames(3)
			for b in h.buttons():
				seen += 1
				if Help.missing(b):
					lacking["%s: %s" % [pg, Help.words(b)]] = true
	menu.close()
	await t._frames(2)
	menu.go_station(String(Stations.STATIONS[0]["id"]), "gym")
	await t._frames(3)
	for stop in menu.station_page.stop_ids():
		menu.go_station(menu.station_page.station, stop)
		await t._frames(3)
		for b in h.buttons():
			seen += 1
			if Help.missing(b):
				lacking["station %s: %s" % [stop, Help.words(b)]] = true
	menu.leave_station()
	await t._frames(3)
	main.profile.supplies = {}
	_check(seen > 200 and lacking.is_empty(), "every train button (%d looked at) has the Entity's own words for it; lacking: %s" % [seen, lacking.keys()])


# --- talking with it --------------------------------------------------------------------------

func _choice(id: String) -> Control:
	for b in _menu().focusables():
		if b.get_meta("talk", "") == id:
			return b
	return null


## A choice on the page, paging on through "Something else..." to find it.
func _reach(id: String) -> Control:
	for i in 4:
		var b := _choice(id)
		if b != null:
			return b
		var more := _choice("+more")
		if more == null:
			return null
		more.pressed.emit()
		await t._frames(3)
	return _choice(id)


## Every choice at the node the talk is at, on all its pages.
func _all_ids(main) -> Array:
	var tk = Talk.new()
	tk.node = _menu().talk.node
	var ids: Array = []
	for i in 5:
		var list: Array = tk.choices(main)
		ids += list.map(func(c): return c["id"])
		var at: int = list.map(func(c): return c["id"]).find("+more")
		if at < 0:
			break
		tk.choose(main, at)
	return ids


func _talk() -> void:
	var menu = _menu()
	var h = _helper()
	var main = t.main
	await _car("personal")
	await t._wait(0.9)
	# A click on the sphere.
	t._mouse_move(h.pos)
	await t._frames(1)
	await t._click_at(h.pos)
	await t._frames(3)
	_check(menu.page == "talk" and menu.talk.node == "start", "a click on the Entity's sphere: a talk")
	var list: Array = menu.talk.choices(main)
	var said: Array = menu.box.find_children("*", "Label", true, false).filter(func(l): return l.text == menu.talk.line)
	_check(menu.talk.line != "" and not said.is_empty(), "...its line on the page (%s)" % menu.talk.line)
	_check(list.size() >= 3 and list.size() <= Talk.MAX_CHOICES and _choice("bye") != null, "...then 3 to %d choices, Goodbye among them (%s)" % [Talk.MAX_CHOICES, list.map(func(c): return c["ask"])])
	_check(_choice("who") == null and _choice("why") == null and not Talk.shows(main, "who"), "the owner's story slots stay hidden while they're blank")
	# The mouse: "What should I do next?" (the belt is empty: it says so).
	var nb: Control = _choice("next")
	await t._click_at(nb.get_global_rect().get_center())
	await t._frames(3)
	var hints: Array = Talk.hints(main)
	_check(menu.talk.node == "next" and menu.talk.line == String(hints[0]) and menu.talk.line.contains(Gear.display(main.profile.chest[1])), "a click on a choice: the Entity answers from the game (%s)" % menu.talk.line)
	_check(hints.has(String(Talk.HINTS["belt_empty"])), "...it knows the belt is empty too (%s)" % [hints])
	_check(_choice("next_more") != null and _choice("start") != null, "...with follow-up choices")
	# The keys: down to "Something else.", Enter.
	menu.nav_keys = true
	_choice("next_more").grab_focus()
	await t._frames(1)
	await t._key_tap(KEY_DOWN)
	await t._frames(2)
	_check(t.root.gui_get_focus_owner() == _choice("start"), "the arrows move between the choices")
	await t._key_tap(KEY_ENTER)
	await t._frames(3)
	_check(menu.page == "talk" and menu.talk.node == "start", "...Enter chooses (back to the first questions)")
	# The tower: its own words.
	var tb: Control = await _reach("tower")
	if tb != null:
		tb.pressed.emit()
		await t._frames(3)
	var tower_id: String = Talk.tower_id(main)
	_check(menu.talk.node == "tower" and menu.talk.line.contains(String(Towers.TOWERS[tower_id]["blurb"]).left(24)), "What is this tower like: its own description (%s)" % menu.talk.line)
	var hz: Control = _choice("tower_hazards")
	if hz != null:
		hz.pressed.emit()
		await t._frames(3)
	_check(menu.talk.line.contains(String(Notes.lines("tower:" + tower_id)[0]).left(20)), "...what to watch for: the tower's own facts (%s)" % menu.talk.line)
	# Touch: a tap on a choice.
	main.touch._set_active(true)
	menu.open("talk")
	await t._frames(3)
	var back: Control = _choice("start")
	await t._tap_at(back.get_global_rect().get_center())
	await t._frames(3)
	_check(menu.talk.node == "start", "a tap on a choice works too")
	main.touch._set_active(false)
	menu.open("talk")
	await t._frames(3)
	# Marks: from the climber's own marks.
	var mk: Control = await _reach("marks")
	if mk != null:
		mk.pressed.emit()
		await t._frames(3)
	_check(menu.talk.node == "marks" and menu.talk.line.contains("Stormcaller") and menu.talk.line.contains("step 1"), "What do my marks do: each mark and its next step (%s)" % menu.talk.line)
	# How things work: the game's rules, its numbers from its own tables.
	menu.talk.begin(main)
	menu.open("talk")
	await t._frames(3)
	var how: Control = await _reach("how")
	if how != null:
		how.pressed.emit()
		await t._frames(3)
	var topics: Array = _all_ids(main).filter(func(id): return String(id).begins_with("how_"))
	_check(menu.talk.node == "how" and topics.size() >= 5, "How do things work here: a topic for each part of the game (%s)" % [topics])
	var lines := {}
	for id in topics:
		lines[id] = Talk.line_for(main, String(id))
	var Lost = load("res://scripts/lost.gd")
	var R = load("res://scripts/renown.gd")
	_check(String(lines.get("how_fall", "")).contains("%d%%" % int(round(Lost.WEAPON_CHANCE * 100.0))) and String(lines.get("how_renown", "")).contains("Noticed at %d" % int(R.RANKS[1][2]))
		and String(lines.get("how_new_mark", "")).contains(str(int(load("res://scripts/profile.gd").FAINT_DEBT))) and lines.values().all(func(l): return l != "" and not l.contains("{")),
		"...its numbers read from the game's own tables (%s)" % lines.get("how_renown", ""))
	var keep_w: float = Lost.WEAPON_CHANCE
	Lost.WEAPON_CHANCE = 0.5
	_check(Talk.line_for(main, "how_fall").contains("50%"), "...and a changed number shows at once")
	Lost.WEAPON_CHANCE = keep_w
	# A story slot, once written, shows (and reads its words).
	var keep: Array = Talk.DIALOGUE["who"]["lines"].duplicate()
	Talk.DIALOGUE["who"]["lines"] = ["A test answer."]
	menu.talk.begin(main)
	var ids: Array = []
	for i in 3:
		ids += menu.talk.choices(main).map(func(c): return c["id"])
		if not ids.has("+more"):
			break
		menu.talk.choose(main, menu.talk.choices(main).map(func(c): return c["id"]).find("+more"))
	_check(ids.has("who") and Talk.line_for(main, "who") == "A test answer.", "...a story slot the owner has written appears (%s)" % [ids])
	Talk.DIALOGUE["who"]["lines"] = keep
	# Esc leaves, back to the car.
	menu.talk.begin(main)
	menu.open("talk")
	await t._frames(2)
	await t._key_tap(KEY_ESCAPE)
	await t._frames(3)
	_check(menu.page == "train" and menu.train_car == "personal", "Esc leaves the talk, back on the car")
	# L opens it from the train; Goodbye leaves.
	menu.nav_keys = true
	await t._key_tap(KEY_L)
	await t._frames(3)
	_check(menu.page == "talk", "L talks with the Entity on the train")
	var bye: Control = _choice("bye")
	if bye != null:
		bye.pressed.emit()
		await t._frames(3)
	_check(menu.page == "train", "Goodbye leaves")
	# A tap on the sphere, on a phone.
	main.touch._set_active(true)
	menu.open("train")
	await t._frames(4)
	await t._tap_at(h.pos)
	await t._frames(3)
	_check(menu.page == "talk", "a tap on the sphere talks too")
	menu.leave_talk()
	await t._frames(2)
	main.touch._set_active(false)
	menu.nav_keys = false
	# After a climb: "How did my last climb go?" from its log.
	var N = load("res://scripts/notices.gd")
	var keep_log: Dictionary = N.climb_log
	N.climb_log = {"tower": "kraken", "log": [{"kind": "floor", "text": "Reached floor 3", "floor": 3, "n": 1}, {"kind": "essence", "text": "+14 Water", "floor": 3, "n": 1},
		{"kind": "gear", "text": "Iron Helm", "floor": 3, "n": 1}]}
	var climbs: int = main.profile.climbs
	main.profile.climbs = maxi(climbs, 1)
	var line: String = Talk.line_for(main, "climb")
	_check(Talk.shows(main, "climb") and line.contains("floor 3") and line.contains("14 essence"), "How did my last climb go: from the climb's own log (%s)" % line)
	main.profile.climbs = climbs
	N.climb_log = keep_log


## In a climb: the Entity's panel has Talk; the game waits while you talk.
func _talk_in_play() -> void:
	var menu = _menu()
	var main = t.main
	menu.close()
	main.on_train = false
	main.choosing_tower = false
	await t._frames(2)
	menu.close()
	t.paused = false
	await t._frames(2)
	Engine.set_meta("sixfold_tips", true)
	var g = main.entity
	g.set_open(true)
	for i in 30:
		await t.process_frame
	await t._frames(3)
	_check(g.open and g.talk_rect.size.x > 0.0, "in a climb, the Entity's panel has a Talk button")
	await t._click_at(g.talk_rect.get_center())
	await t._frames(3)
	_check(menu.page == "talk" and t.paused and g.talks >= 1, "...a click on it talks (the game waits)")
	var ids: Array = _all_ids(main)
	_check(ids.has("this_climb") and not ids.has("train") and not ids.has("climb"), "...in a climb it asks about this climb, not the train (%s)" % [ids])
	await t._key_tap(KEY_ESCAPE)
	await t._frames(3)
	_check(menu.page == "" and not t.paused, "...Esc leaves, back to the climb")
	Engine.remove_meta("sixfold_tips")
	main.await_tower()
	main.open_train()
	await t._frames(2)


# --- words ------------------------------------------------------------------------------------

func _strings(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k in v:
			_strings(v[k], out)
	elif v is Array:
		for x in v:
			_strings(x, out)


func _banned() -> void:
	var all: Array = []
	for tbl in [Help.HELP, Help.TEXT, Talk.DIALOGUE, Talk.HINTS, Talk.TEXT, Notes.TEXT]:
		_strings(tbl, all)
	var found: Array = []
	for s in all:
		for w in BANNED:
			if String(s).to_lower().contains(w):
				found.append(s)
	_check(found.is_empty() and all.size() > 100, "no banned words in the Entity's new tables (%d lines; %s)" % [all.size(), found])
	var reg = load("res://scripts/data_registry.gd")
	_check(reg.field("entity_help/HELP/rail:store").get("kind", "") == "text" and reg.field("entity_talk/DIALOGUE/next/ask").get("kind", "") == "text",
		"the Data editor offers the Entity's explanations and its talk")
