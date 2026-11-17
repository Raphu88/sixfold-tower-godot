extends RefCounted
## How long the Entity's words stay (entity.gd TIMING, guide.gd,
## entity_helper.gd): in a climb its tips and tidbits stay about twice as
## long as they did, longer for longer words, and a tap on the bubble or the
## sphere still sends them sooner; in the menus its lines on a page have no
## timer at all and stay, through the page being built again, until a
## click, a tap or L sends them away (and then stay away); a button or a
## piece of furniture that's highlighted (the mouse resting on it, the keys
## on it, a finger held on it) keeps its explanation and the Entity's own
## comment under it for as long as it's highlighted, on the train's cars and
## stations and on every page of the pause menu in a climb, and they go when
## it isn't. Run by smoke_test.gd (_part_tests).

const Guide := preload("res://scripts/guide.gd")
const Entity := preload("res://scripts/entity.gd")
const Help := preload("res://scripts/entity_help.gd")
const Helper := preload("res://scripts/entity_helper.gd")
const Stations := preload("res://scripts/stations.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var M = load("res://scripts/menu.gd")
var keep_ui := ""
var keep_size := Vector2i.ZERO
var keep_guide := {}
var keep_help := true


func run(smoke) -> void:
	t = smoke
	print("the Entity's words: how long they stay, sent away, explaining what's highlighted")
	await _begin()
	_timings()
	await _in_climb()
	await _menu_lines()
	await _highlight_train()
	await _highlight_touch()
	await _highlight_pages()
	_words()
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
	keep_guide = Guide.state.duplicate(true)
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
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	await t._frames(3)


func _end() -> void:
	var main = t.main
	var menu = _menu()
	if menu.is_open():
		menu.close()
	main.on_train = false
	Engine.remove_meta("sixfold_tips")
	Guide.state = keep_guide
	Guide.queue.clear()
	Guide.held.clear()
	Entity.gone.clear()
	main.touch._set_active(false)
	main.pad._set_active(false)
	M.settings["ui_size"] = keep_ui
	M.settings["entity_help"] = keep_help
	t.root.size = keep_size
	main.apply_view_scale()
	t.paused = false
	await t._frames(2)


## What a tip and a tidbit lasted before (seconds), for comparison.
static func _old_tip(n: int) -> float:
	return clampf(3.0 + n * 0.055, 6.0, 12.0)


static func _old_bit(n: int) -> float:
	return 3.6 + n * 0.035


# --- in a climb ------------------------------------------------------------------------------

func _timings() -> void:
	var short := "Short."
	var mid := "x".repeat(110)
	var long := "x".repeat(170)
	var ok := true
	for s in [short, mid, long]:
		ok = ok and Guide.tip_life(s) >= 1.9 * _old_tip(s.length()) and Guide.bit_life(s) >= 1.9 * _old_bit(s.length())
	_check(ok, "in a climb tips and tidbits stay about twice as long as before (%.1f s for a %d-letter tip, was %.1f)" % [Guide.tip_life(mid), mid.length(), _old_tip(mid.length())])
	_check(Guide.tip_life(long) > Guide.tip_life(mid) and Guide.tip_life(mid) > Guide.tip_life(short) and Guide.bit_life(mid) > Guide.bit_life(short), "...longer words stay longer")
	var keep: Dictionary = Entity.TIMING.duplicate()
	Entity.TIMING["tip_min"] = 30.0
	Entity.TIMING["tip_max"] = 40.0
	_check(is_equal_approx(Guide.tip_life(short), 30.0), "...and the times are data (entity.gd TIMING)")
	Entity.TIMING.merge(keep, true)


func _in_climb() -> void:
	var main = t.main
	var en = main.entity
	Guide.queue.clear()
	_check(main.tip("glint"), "a first-time tip in a climb")
	await t._until_bubble()
	var text: String = String(en.current.get("text", ""))
	_check(en.showing() and is_equal_approx(en.life, Guide.tip_life(text)) and en.life >= 1.9 * _old_tip(text.length()), "...its bubble stays %.1f s (it was %.1f)" % [en.life, _old_tip(text.length())])
	# Past the old time, it's still there.
	en.shown_t = _old_tip(text.length()) + 0.5
	await t._frames(5)
	_check(en.showing() and en.leaving <= 0.0, "...still showing after the old time")
	_check(not t.paused and main.player.is_physics_processing(), "...and the game goes on under it")
	# A click on the sphere sends it away (the panel stays shut).
	await t._frames(2)
	var orb: Rect2 = en.orb_rect
	_check(orb.has_area(), "the sphere is on screen beside it")
	await t._click_at(orb.get_center())
	await t._until_no_bubble()
	_check(not en.showing() and not en.open, "a click on the sphere sends the tip away, the panel stays shut")
	# A tidbit: twice as long, and a tap on it sends it too.
	en.new_climb()
	en.bit_at = -1000000
	_check(en.remark("stair"), "a tidbit")
	await t._until(func(): return en.showing(), 3.0)
	await t._wait(0.4)
	var bt: String = String(en.current.get("text", ""))
	_check(en.current.get("kind", "") == "bit" and is_equal_approx(en.life, Guide.bit_life(bt)) and en.life >= 1.9 * _old_bit(bt.length()), "...stays %.1f s (it was %.1f)" % [en.life, _old_bit(bt.length())])
	if en.rect.has_area():
		await t._click_at(en.rect.get_center())
	else:
		en.dismiss()
	await t._until_no_bubble()
	_check(not en.showing(), "...a click on it sends it away sooner")
	# L sends a tip away first (then opens the panel).
	main.tip("essence")
	await t._until_bubble()
	await t._key_tap(KEY_L)
	await t._until_no_bubble()
	_check(not en.showing() and not en.open, "L sends a tip away first")
	Guide.queue.clear()


# --- the menus: its lines stay until sent away ------------------------------------------------

func _away_lines(where: Node) -> Array:
	return where.find_children("*", "HBoxContainer", true, false).filter(func(c): return c.has_meta("entity_away") and c.is_visible_in_tree())


func _menu_lines() -> void:
	var main = t.main
	var menu = _menu()
	var h = _helper()
	Guide.forget()
	main.open_train()
	await t._frames(3)
	# Your car: the Entity's first-time tip about the train, at the top of the car.
	menu.train_page.tips = {}
	menu.train_car = "personal"
	menu.open("train")
	await t._frames(3)
	var said: Array = _away_lines(menu).filter(func(c): return c.get_meta("entity", "") == "personal")
	var tip_line: String = Entity.fill_keys(String(Entity.entry("train")["tip"]), "keys")
	_check(not said.is_empty() and String(said[0].get_meta("entity_line", "")).contains(tip_line.substr(1, 30)), "on the train the Entity's first-time tip shows on the car")
	_check(said.size() > 0 and said[0].find_children("*", "Label", true, false).any(func(l): return l.has_meta("entity_away_hint") and l.text.contains("click")), "...saying how to send it away")
	# No timer: it's there after a while, and through the page being built again.
	await t._wait(3.5)
	menu.train_page.tips = {}  # (as if the car were visited again)
	menu.open("train")
	await t._frames(3)
	said = _away_lines(menu).filter(func(c): return c.get_meta("entity", "") == "personal")
	_check(not said.is_empty() and Guide.held.has("train"), "...it stays: still there after a while and when the car is built again")
	# A click on it sends it away, and it stays away.
	var away0: int = h.sent
	await t._click_at(said[0].get_global_rect().get_center())
	await t._frames(3)
	_check(h.sent == away0 + 1 and not said[0].visible and not Guide.held.has("train"), "a click on it sends it away")
	_check(menu.page == "train" and menu.train_car == "personal", "...and does nothing else")
	menu.train_page.tips = {}
	menu.open("train")
	await t._frames(3)
	said = _away_lines(menu).filter(func(c): return c.get_meta("entity", "") == "personal" and String(c.get_meta("entity_line", "")).contains(tip_line.substr(1, 30)))
	_check(said.is_empty(), "...and the car built again leaves it out")
	# An answer on a page (a toast in its bubble) stays past its old two seconds.
	menu.toast = "A line just for this test."
	menu.toast_t = 2.0
	menu.open("settings")
	await t._frames(2)
	await t._wait(2.6)
	_check(menu.toast == "", "(the toast's own timer has run out)")
	menu.open("settings")
	await t._frames(3)
	var ans: Array = _away_lines(menu).filter(func(c): return c.get_meta("entity_line", "") == "A line just for this test.")
	_check(not ans.is_empty(), "its answer on a page stays when the page is built again, with no timer")
	# A tap sends it away (a phone).
	if not ans.is_empty():
		await t._tap_at(ans[0].get_global_rect().get_center())
		await t._frames(2)
	_check(not ans.is_empty() and not ans[0].visible and menu.said_toast == "" and menu.page == "settings", "...a tap sends it away")
	main.touch._set_active(false)
	# L sends one away too (the keys and a controller).
	menu.toast = "Another line for this test."
	menu.toast_t = 2.0
	menu.open("settings")
	await t._frames(3)
	ans = _away_lines(menu).filter(func(c): return c.get_meta("entity_line", "") == "Another line for this test.")
	await t._key_tap(KEY_L)
	await t._frames(3)
	_check(not ans.is_empty() and not ans[0].visible and menu.page == "settings", "L sends its line away instead of talking (%d, %s, %s)" % [ans.size(), menu.page, h.active()])
	# The Archive's words aren't sent away by a click: they were asked for.
	var archive_said := Entity.says("x", 30.0, "", false)
	_check(not archive_said.has_meta("entity_away"), "words the player chose to read (the Archive, a talk) can't be sent away")
	archive_said.free()
	Entity.gone.clear()


# --- highlighting: the explanation and a comment, for as long as it lasts -------------------------

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


func _find(meta: String, val = null) -> Control:
	for b in _helper().buttons():
		if b.has_meta(meta) and (val == null or b.get_meta(meta) == val):
			return b
	return null


func _comment_ok(h, b: Control) -> bool:
	var kind := Help.comment_kind(Help.key_for(b))
	return h.comment != "" and Help.COMMENTS.get(kind, Help.COMMENTS["any"]).has(h.comment)


func _highlight_train() -> void:
	var menu = _menu()
	var h = _helper()
	t.main.touch._set_active(false)
	await _car("personal")
	menu.nav_keys = false
	var rail_b: Control = menu.rail.button("store")
	t._mouse_move(rail_b.get_global_rect().get_center())
	await t._wait(Helper.DELAY + 0.3)
	await t._frames(2)
	_check(h.target == rail_b and h.text == String(Help.HELP["rail:store"]) and _comment_ok(h, rail_b), "the mouse on a button: its explanation first, then the Entity's comment (%s / %s)" % [h.text, h.comment])
	_check(h.bubble.size.y > h.bubble_h(h.bubble.size.x, h.text) + 2.0, "...the comment on a second line, under the explanation")
	# No timer while it's highlighted.
	var said: String = h.text
	await t._wait(5.0)
	t._mouse_move(rail_b.get_global_rect().get_center() + Vector2(1, 0))
	await t._frames(3)
	_check(h.target == rail_b and h.text == said and h.appear > 0.9, "...and it stays for as long as the button is highlighted")
	# Off the button: it goes.
	t._mouse_move(Vector2(t.root.size) * Vector2(0.62, 0.04))
	await t._wait(Helper.LEAVE + 0.5)
	await t._frames(2)
	_check(h.target == null and h.comment == "", "...and goes once it isn't")
	# The keys: the same, for as long as the focus stays.
	var lo: Control = _find("car_page", "loadout")
	menu.nav_keys = true
	lo.grab_focus()
	await t._wait(Helper.DELAY_KEYS + 0.3)
	_check(h.target == lo and _comment_ok(h, lo), "the keys on a button: its explanation and the comment")
	await t._wait(4.0)
	_check(h.target == lo, "...for as long as the focus stays on it")
	t.root.gui_release_focus()
	await t._wait(Helper.LEAVE + 0.4)
	_check(h.target == null, "...gone when nothing has the focus")
	menu.nav_keys = false
	# An object: a piece of furniture (not a button).
	var furn: Control = null
	var spot := Vector2(-1, -1)
	for car in ["personal", "store", "library", "dining"]:
		await _car(car)
		for top in h._tops():
			for f in top.find_children("*", "PanelContainer", true, false):
				if not f.has_meta("furnish") or not f.is_visible_in_tree() or Help.entry(Help.key_for(f)) == "":
					continue
				var r: Rect2 = f.get_global_rect()
				for i in 12:
					for j in 8:
						var p := r.position + Vector2(r.size.x * (i + 0.5) / 12.0, r.size.y * (j + 0.5) / 8.0)
						if h.button_at(p) == null and h.line_at(p) == null and h.object_at(p) == f:
							spot = p
							furn = f
							break
					if furn != null:
						break
				if furn != null:
					break
			if furn != null:
				break
		if furn != null:
			break
	if furn != null:
		t._mouse_move(spot)
		await t._wait(Helper.DELAY + 0.3)
		await t._frames(2)
	_check(furn != null and h.target == furn and h.text == Help.entry("furnish:" + String(furn.get_meta("furnish"))) and _comment_ok(h, furn),
		"the mouse on a piece of furniture: the Entity says what it is, and comments (%s)" % [h.text])
	t._mouse_move(Vector2(-40, -40))
	await t._wait(Helper.LEAVE + 0.4)


func _highlight_touch() -> void:
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
	for l in h.lines_up():
		h.send_away(l)  # (the car's first-time tips, so its tabs are in view on a short screen)
	menu.open("train")
	await t._frames(3)
	var sell_tab: Control = _find("store_tab", "sell")
	var at: Vector2 = sell_tab.get_global_rect().get_center()
	t._touch(0, at, true)
	await t._wait(Helper.HOLD + 0.2)
	await t._frames(2)
	_check(h.target == sell_tab and _comment_ok(h, sell_tab), "a finger held on a button: its explanation and the comment (%s %s %s)" % [h.target, h.text, h.comment])
	t._touch(0, at, false)
	await t._frames(2)
	_check(menu.train_store == "shop", "...letting go doesn't press it")
	await t._wait(4.0)
	_check(h.target == sell_tab, "...and it stays after you let go, until your next tap")
	# A tap on the bubble only sends it away.
	var on_bubble: Vector2 = h.bubble.get_center()
	await t._tap_at(on_bubble)
	await t._frames(2)
	_check(h.target == null and menu.train_store == "shop", "...a tap on its bubble sends it away (and presses nothing)")
	# Held again, then a tap on the button presses it as always.
	t._touch(0, at, true)
	await t._wait(Helper.HOLD + 0.2)
	t._touch(0, at, false)
	await t._frames(2)
	await t._tap_at(at)
	await t._frames(2)
	_check(h.target == null and menu.train_store == "sell", "...a tap anywhere else does what it always does")
	menu.train_store = "shop"
	Entity.gone.clear()
	main.touch._set_active(false)
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	await t._frames(3)


## Every kind of menu page: the train's own (the Loadout, the stash, a
## station, the Dining car) and the pause menu's in a climb (the inventory,
## the book, the Library and its Bestiary, Settings, the controls).
func _highlight_pages() -> void:
	var menu = _menu()
	var h = _helper()
	var main = t.main
	var bad: Array = []
	var seen := 0
	var spots: Array = []
	for pg in ["loadout", "stash"]:
		spots.append(["train", pg, ""])
	spots.append(["train", "car", "dining"])
	spots.append(["station", "gym", ""])
	for pg in ["pause", "inventory", "settings"]:
		spots.append(["climb", pg, ""])
	for tab in ["abilities", "tree", "marks", "essence", "record"]:
		spots.append(["climb", "climber", tab])
	for tab in ["archive", "bestiary"]:
		spots.append(["climb", "library", tab])
	for s in spots:
		if s[0] == "train":
			if not main.on_train or menu.at_station():
				main.open_train()
				await t._frames(3)
			if s[1] == "car":
				await _car(String(s[2]))
			else:
				menu.open(String(s[1]), true)
				await t._frames(3)
		elif s[0] == "station":
			if not main.on_train:
				main.open_train()
				await t._frames(3)
			menu.go_station(String(Stations.STATIONS[0]["id"]), String(s[1]))
			await t._frames(3)
		else:
			if main.on_train:
				menu.close()
				main.on_train = false
				await t._frames(2)
			if s[1] == "climber":
				menu.climber_tab = String(s[2])
			if s[1] == "library":
				menu.set("library_tab", String(s[2]))
			menu.open(String(s[1]))
			await t._frames(3)
		var where := "%s %s %s" % s
		var list: Array = menu.focusables().filter(func(b): return b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE and Help.explain(menu, b) != "")
		if not h.active() or list.is_empty():
			bad.append(where + " (not active or nothing to explain)")
			continue
		var b: Control = list[mini(1, list.size() - 1)]
		menu.nav_keys = true
		b.grab_focus()
		await t._wait(Helper.DELAY_KEYS + 0.3)
		await t._frames(2)
		if h.target != b or h.text == "" or not _comment_ok(h, b):
			bad.append("%s: %s" % [where, Help.key_for(b)])
		else:
			seen += 1
		t.root.gui_release_focus()
		menu.nav_keys = false
	_check(bad.is_empty() and seen >= 12, "on every kind of menu page a highlighted button gets its explanation and the comment (%d pages; %s)" % [seen, bad])
	if menu.at_station():
		menu.leave_station()
		await t._frames(2)
	menu.close()
	main.on_train = false
	await t._frames(2)


func _words() -> void:
	var bad: Array = []
	for k in Help.COMMENTS:
		for l in Help.COMMENTS[k]:
			for w in BANNED:
				if String(l).to_lower().contains(w):
					bad.append("%s: %s" % [k, l])
	for k in Help.HELP:
		if String(k).begins_with("furnish:"):
			for w in BANNED:
				if String(Help.HELP[k]).to_lower().contains(w):
					bad.append(k)
	for k in ["away", "away_touch", "away_keys"]:
		for w in BANNED:
			if String(Entity.TEXT[k]).to_lower().contains(w):
				bad.append(k)
	_check(bad.is_empty() and Help.COMMENTS.has("any"), "the comments and the furniture's words have no banned words, and every kind has a comment (%s)" % [bad])
