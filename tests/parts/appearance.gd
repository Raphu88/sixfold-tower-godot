extends RefCounted
## More character customisation (appearance.gd, appearance_page.gd): every
## option changes the drawing everywhere the climber is drawn (the tower in
## every pose and direction, the mirror image, the front figure that the
## book, the body map, the climber picker and the preview share), Randomise
## covers them, old saves load with defaults, and the page's tabs work by
## keys, controller and touch and fit 800x400 at every Interface size.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const A := preload("res://scripts/appearance.gd")
const Mirror := preload("res://scripts/mirror.gd")
const M := preload("res://scripts/menu.gd")
const Draw := preload("res://scripts/draw_util.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _every_option_draws()
	_randomise_covers()
	_old_saves()
	await _page_by_hand()
	await _page_fits()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A look dressed as player.gd dresses it (no gear worn).
func _dressed(p, app: Dictionary) -> Dictionary:
	var lk: Dictionary = A.look(app)
	p._piece_look(lk, true)
	p._armor_look(lk)
	p._piece_look(lk, false)
	return lk


## What a batch drew, as one comparable value.
func _sig(b) -> Array:
	return [b.pts, b.cols]


## The tower: standing mid-stride, facing four ways.
func _tower(p, lk: Dictionary) -> Array:
	var out: Array = []
	p._walk_amp = 1.0
	p._walk_phase = PI * 0.5
	p._cloak_drift = Vector2.ZERO
	p.hurt_t = 0.0
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		p._f = Vector2.from_angle(a)
		p._sd = p._f.orthogonal()
		var b = Draw.Batch.new()
		p._draw_standing(b, lk, 1.0)
		out.append(_sig(b))
	return out


func _rolling(p, lk: Dictionary) -> Array:
	p.roll_t = 0.1
	var b = Draw.Batch.new()
	p._draw_rolling(b, lk)
	p.roll_t = 0.0
	return _sig(b)


func _fallen(p, lk: Dictionary) -> Array:
	p._f = Vector2.RIGHT
	p._sd = Vector2.DOWN
	var b = Draw.Batch.new()
	p._draw_fallen(b, lk)
	return _sig(b)


func _mirror(lk: Dictionary) -> Array:
	var out: Array = []
	for a in [0.0, PI]:
		var f := Vector2.from_angle(a)
		var b = Draw.Batch.new()
		Mirror.draw_climber(b, lk, {"f": f, "sd": -f.orthogonal(), "s": 1.0, "t": 1.0, "weapon": "sword", "w": {}, "armor": ""})
		out.append(_sig(b))
	return out


func _front(lk: Dictionary) -> Array:
	var b = Draw.Batch.new()
	M.BodyView._figure(b, lk)  # (the climber screen, the book, the body map, the picker and the preview)
	return _sig(b)


func _every_option_draws() -> void:
	print("appearance: every option shows everywhere the climber is drawn")
	await t._fresh_main()
	var p = t.main.player
	var missing: Array = []
	# What shows while rolling (the cloak and the top of the head) and fallen
	# (the cloak, the legs and boots, the chest, the top of the head).
	var rolls := ["cloak", "cloak_style", "trim", "pattern", "build"]
	var falls := ["cloak", "cloak_style", "trim", "pattern", "trousers", "boots", "build", "tunic"]
	for hood in ["up", "down"]:
		var base := A.DEFAULTS.duplicate()
		base["hood"] = hood
		var lk0 := _dressed(p, base)
		var tower0 := _tower(p, lk0)
		var mirror0 := _mirror(lk0)
		var front0 := _front(A.look(base))
		var roll0 := _rolling(p, lk0)
		var fall0 := _fallen(p, lk0)
		if hood == "up":
			_check(_tower(p, lk0) == tower0 and _mirror(lk0) == mirror0 and _front(A.look(base)) == front0 and _rolling(p, lk0) == roll0, "the climber's drawing is repeatable (so a change is the option's)")
		for key in A.OPTIONS:
			if key == "hood":
				continue
			for opt in A.OPTIONS[key]:
				var id: String = opt[0]
				if id == base[key]:
					continue
				var app := base.duplicate()
				app[key] = id
				var lk := _dressed(p, app)
				var tw := _tower(p, lk)
				var same_dir := 0
				for i in tw.size():
					if tw[i] == tower0[i]:
						same_dir += 1
				if same_dir > 0:
					missing.append("tower %s=%s hood %s (same in %d of 4 directions)" % [key, id, hood, same_dir])
				if _mirror(lk) == mirror0:
					missing.append("mirror %s=%s hood %s" % [key, id, hood])
				if _front(A.look(app)) == front0:
					missing.append("front %s=%s hood %s" % [key, id, hood])
				if key in rolls and _rolling(p, lk) == roll0:
					missing.append("rolling %s=%s" % [key, id])
				if key in falls and _fallen(p, lk) == fall0:
					missing.append("fallen %s=%s" % [key, id])
		# With the hood down the hair is on top while rolling and fallen.
		if hood == "down":
			for opt in A.OPTIONS["hair_color"]:
				if opt[0] == base["hair_color"]:
					continue
				var app2 := base.duplicate()
				app2["hair_color"] = opt[0]
				var lk2 := _dressed(p, app2)
				if _rolling(p, lk2) == roll0 or _fallen(p, lk2) == fall0:
					missing.append("rolling/fallen hair colour %s" % opt[0])
	_check(missing.is_empty(), "every option changes the climber in the tower (4 directions, hood up and down), the mirror image and the front figure, and the cloak, legs and build when rolling or fallen (%d missing): %s" % [missing.size(), missing.slice(0, 8)])
	# With a helm, a cap or armour on, the new options still draw (and a helm hides the face).
	var app3 := A.DEFAULTS.duplicate()
	app3.merge({"beard": "full", "accessory": "feather", "neck": "scarf", "cloak_style": "tattered", "trim": "gold", "pattern": "striped", "build": "broad"}, true)
	var lk3 := _dressed(p, app3)
	var ok := true
	for head in ["helm", "cap", "coif"]:
		var lh := lk3.duplicate()
		lh["head"] = head
		lh["cap"] = Color(0.4, 0.3, 0.2)
		var b = Draw.Batch.new()
		p._f = Vector2.RIGHT
		p._sd = Vector2.DOWN
		p._draw_standing(b, lh, 1.0)
		ok = ok and b.pts.size() > 100
	_check(ok, "the new options draw under a helm, a cap and a mail coif")
	# The places that draw the front figure all draw it through BodyView._figure.
	var uses := 0
	for f in ["res://scripts/tree_view.gd", "res://scripts/menu.gd", "res://scripts/climbers_page.gd"]:
		var src := FileAccess.get_file_as_string(f)
		if "_figure(" in src or "figure_into" in src:
			uses += 1
	_check(uses == 3, "the book, its body map and the climber picker draw the same figure")
	# The mirror image copies the climber's look.
	p.set_appearance(app3)
	var lk4: Dictionary = Mirror.climber_look(p)
	_check(lk4["cloak_style"] == "tattered" and lk4["beard"] == "full" and lk4["trim_on"] and lk4["build"] == "broad", "the mirror image wears the climber's whole look")
	p.set_appearance(t.main.profile.appearance)


func _randomise_covers() -> void:
	print("appearance: Randomise")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 600:
		var r: Dictionary = A.random({"name": "Fen"}, rng)
		for key in A.OPTIONS:
			seen[key + "=" + str(r[key])] = true
		if r["name"] != "Fen":
			seen["lost_name"] = true
	var never: Array = []
	for key in A.OPTIONS:
		for opt in A.OPTIONS[key]:
			if not seen.has(key + "=" + opt[0]):
				never.append(key + "=" + opt[0])
	_check(never.is_empty() and not seen.has("lost_name"), "Randomise reaches every choice of every option and keeps the name (never: %s)" % [never])


func _old_saves() -> void:
	print("appearance: old saves")
	var Prof = load("res://scripts/profile.gd")
	var path := "user://smoke_look_old_%d.cfg" % OS.get_process_id()
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("look", "appearance", {"name": "Wren", "skin": "deep", "hair": "braid", "hair_color": "copper", "eyes": "green", "cloak": "plum", "tunic": "navy", "hood": "down"})
	old.save(path)
	var again = Prof.new()
	again.save_path = path
	again.load_save()
	var app: Dictionary = again.appearance
	var ok: bool = app["name"] == "Wren" and app["hair"] == "braid" and app["cloak"] == "plum"
	for key in ["eye_shape", "face", "beard", "build", "trousers", "boots", "cloak_style", "trim", "pattern", "belt", "neck", "accessory"]:
		ok = ok and app.get(key, "") == A.DEFAULTS[key]
	_check(ok, "a save from before the new options loads with them at today's look, the old choices kept")
	var lk: Dictionary = A.look(app)
	_check(lk["trousers"] == lk["tunic"] and lk["boot"] == A.BOOT and not lk["trim_on"] and lk["cloak_style"] == "long" and is_equal_approx(lk["torso_r"], 8.5), "...so the climber looks as before (trousers as the tunic, today's boots, a long cloak, no trim, an average build)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _page_by_hand() -> void:
	print("appearance: the page's tabs by keys, controller and touch")
	await t._fresh_main()
	var main = t.main
	var menu = main.menu
	var prof = main.profile
	main.touch._set_active(false)
	main.pad._set_active(false)
	menu.open_appearance("climber")
	await t._frames(3)
	var page = menu.look_page
	page.show_tab("face", false)
	await t._frames(1)
	# Keys: Down from the name runs through the tabs and every row, round to the start.
	page.name_edit.release_focus()
	page.dice.grab_focus()
	await t._frames(1)
	var visited: Array = []
	for i in 12:
		await t._key_tap(KEY_DOWN)
		visited.append(t._focus_now())
	var want: Array = [page.tabs] + page.rows.values()
	var all_in := true
	for c in want:
		all_in = all_in and visited.has(c)
	_check(all_in and visited.has(page.finish), "Down runs through the tabs, every row of the tab, Randomise and Done")
	# Every tab by the keys.
	page.tabs.grab_focus()
	await t._frames(1)
	var tabs_seen: Array = [page.tab]
	for i in A.TABS.size():
		await t._key_tap(KEY_RIGHT)
		tabs_seen.append(page.tab)
	_check(tabs_seen.size() == A.TABS.size() + 1 and tabs_seen[0] == tabs_seen[-1] and A.TABS.all(func(tb): return tabs_seen.has(tb[0])), "Right on the tabs turns through every tab and round again (%s)" % [tabs_seen])
	# Each tab's rows can be reached and changed.
	var changed_all := true
	for tb in A.TABS:
		page.show_tab(tb[0], false)
		await t._frames(1)
		for key in tb[2]:
			var before: String = prof.appearance[key]
			page.rows[key].grab_focus()
			await t._key_tap(KEY_RIGHT)
			changed_all = changed_all and prof.appearance[key] == A.step({key: before}, key, 1) and main.climber_look == A.look(prof.appearance)
	_check(changed_all, "every option on every tab changes by the keys, kept and worn at once")
	# The controller: Extras, the accessory.
	main.pad._set_active(true)
	await t._frames(2)
	page.show_tab("extras", false)
	await t._frames(1)
	page.rows["accessory"].grab_focus()
	var acc0: String = prof.appearance["accessory"]
	await t._pad_tap(JOY_BUTTON_DPAD_LEFT)
	_check(prof.appearance["accessory"] == A.step({"accessory": acc0}, "accessory", -1), "the d-pad changes a row on the Extras tab")
	await t._pad_tap(JOY_BUTTON_DPAD_UP)
	await t._pad_tap(JOY_BUTTON_DPAD_UP)
	await t._pad_tap(JOY_BUTTON_DPAD_UP)
	_check(t._focus_now() == page.tabs, "...and Up climbs back to the tabs")
	await t._pad_tap(JOY_BUTTON_A)
	_check(t._focus_now() == page.first_focus and page.first_focus == page.rows["belt"], "A on the tabs goes into the tab's first row")
	main.pad._set_active(false)
	# Touch: a tab, then a swatch.
	main.touch._set_active(true)
	await t._frames(3)
	page = menu.look_page
	menu.scroll.ensure_control_visible(page.tabs)
	await t._frames(2)
	var bi: int = A.TABS.map(func(tb): return tb[0]).find("body")
	await t._tap_at(page.tabs.get_global_transform() * Vector2(page.tabs.size.x / A.TABS.size() * (bi + 0.5), page.tabs.size.y * 0.5))
	_check(page.tab == "body" and page.rows.has("boots"), "a tap on a tab shows its rows (Body)")
	var boots = page.rows["boots"]
	menu.scroll.ensure_control_visible(boots)
	await t._frames(2)
	var mid: Rect2 = boots._middle()
	var n: int = A.OPTIONS["boots"].size()
	var oi: int = A.index_of("boots", "tan")
	await t._tap_at(boots.get_global_transform() * Vector2(mid.position.x + mid.size.x / n * (oi + 0.5), boots.size.y * 0.5))
	_check(prof.appearance["boots"] == "tan" and main.climber_look["boot"] == A.color_of("boots", "tan") and main.player.appearance_look["boot"] == A.color_of("boots", "tan"), "a tap on a swatch picks it (tan boots), in the tower and on the climber screen")
	# Randomise: the rows on show follow, the name stays.
	page.set_name("Quill")
	page.randomise()
	var follow := true
	for key in page.rows:
		follow = follow and page.rows[key].value == prof.appearance[key]
	_check(follow and prof.appearance["name"] == "Quill", "Randomise rolls the new options too; the rows on show follow and the name stays")
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)


func _page_fits() -> void:
	print("appearance: the page fits a phone")
	var main = t.main
	var menu = main.menu
	var U = load("res://scripts/ui.gd")
	var keep: String = M.settings["ui_size"]
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	var problems: Array = []
	for ui in U.UI_SIZE_ORDER:
		menu._set_setting("ui_size", ui)
		menu.open_appearance("climber")
		await t._frames(3)
		var page = menu.look_page
		for tb in A.TABS:
			page.show_tab(tb[0], false)
			await t._frames(2)
			problems.append_array(t._fit_problems("appearance %s %s" % [ui, tb[0]], menu.panel, t.root.get_visible_rect()))
			var font: Font = U.font("display")
			var w: float = page.tabs.size.x / A.TABS.size()
			for tt in A.TABS:
				if U.fit_size(font, String(tt[1]), 16, w - 10.0) < 12:
					problems.append("appearance %s: the tab %s squeezed" % [ui, tt[1]])
	_check(problems.is_empty(), "the appearance page fits 800x400 at every Interface size, on every tab (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	menu.close()
	menu._set_setting("ui_size", keep)
	main.touch._set_active(false)
	t.root.size = was_size
	await t._frames(2)
