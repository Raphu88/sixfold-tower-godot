extends RefCounted
## Arrange mode, step 2 (arrange.gd, arrange_ui.gd): the menus, the left
## rail and the train's furniture can be moved, scaled, resized, saved,
## reloaded and reset; an empty layout changes nothing; arrangements fit a
## phone; and Arrange mode closed catches no input. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const TestRun := preload("res://scripts/test_run.gd")
const L := preload("res://scripts/layout.gd")
const AUI := preload("res://scripts/arrange_ui.gd")

var t
var keep := []


func run(smoke) -> void:
	t = smoke
	print("arrange mode, step 2: menus, the rail and the train")
	await t._fresh_main()
	keep = [L.user_path, L.project_path, L.write_project]
	L.user_path = TestRun.path("user://arrange2_layout.cfg")
	L.project_path = TestRun.path("user://arrange2_layout.json")
	L.write_project = true  # (as from the editor: Save writes the shared file too, here a test's own)
	L.clear_state()
	L.use_set("desktop")
	await _untouched()
	await _menu_element()
	await _rail()
	await _train()
	await _save_reload_reset()
	await _phone()
	await _off_catches_nothing()
	# Tidy up: the built-in layout, the real paths, nothing left on disk.
	L.clear_state()
	L.use_set("desktop")
	AUI.enabled = true
	for f in [L.user_path, L.project_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	L.user_path = keep[0]
	L.project_path = keep[1]
	L.write_project = keep[2]
	var m = t.main.menu
	if m.is_open():
		m.close()
	await t._frames(3)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _near(a: Vector2, b: Vector2, by := 1.0) -> bool:
	return a.distance_to(b) <= by


func _rect_near(a: Rect2, b: Rect2, by := 1.0) -> bool:
	return _near(a.position, b.position, by) and _near(a.size, b.size, by)


## Every control's place on the menu (the page, the rail, the panel's
## holder), by its path in the tree, to compare two builds.
func _places(m) -> Dictionary:
	var out := {}
	for root in [m.box, m.foot, m.rail]:
		for c in root.find_children("*", "Control", true, false):
			if c.is_visible_in_tree():
				out[_index_path(m, c)] = c.get_global_rect()
	out["panel"] = m.panel.get_global_rect()
	out["center"] = [m.center.position, m.center.scale]
	return out


## Where a control is, as the child numbers down from the menu (its own
## name is made up afresh each build).
func _index_path(m, c: Node) -> String:
	var parts: Array = []
	while c != null and c != m:
		parts.push_front(str(c.get_index()) + c.get_class())
		c = c.get_parent()
	return "/".join(parts)


func _open(page: String) -> void:
	var m = t.main.menu
	if page == "inventory":
		t.main.on_train = false  # (on the train the inventory opens the Loadout: these checks want the climb's inventory page)
	if m.is_open() and m.page == page:
		m.close()
		await t._frames(3)
	m.open(page)
	await t._frames(4)
	await t._wait(0.5)  # (the page eases in: its fade and scale finished)


func _arrange_open(want := "") -> void:
	var ar = t.main.arrange
	ar.open(want)
	await t._frames(3)
	if not ar.card.is_empty():
		ar.card_next(true)
	await t._frames(1)


func _wheel(pos: Vector2, up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = t._to_window(pos)
	ev.global_position = ev.position
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)
	await t._frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await t._frames(1)


## A mouse drag from one point to another (Shift: no snapping).
func _drag(from: Vector2, to: Vector2) -> void:
	t._mouse_button(from, MOUSE_BUTTON_LEFT, true)
	await t._frames(2)
	t._mouse_drag_to(to, true)
	await t._frames(2)
	t._mouse_button(to, MOUSE_BUTTON_LEFT, false)
	await t._frames(3)


## An empty layout is exactly today's look: the same page, built with and
## without Arrange mode's tags, has every control in the same place.
func _untouched() -> void:
	var m = t.main.menu
	var same := true
	var where := ""
	for page in ["inventory", "pause", "settings"]:
		AUI.enabled = false
		await _open(page)
		var before := _places(m)
		AUI.enabled = true
		await _open(page)
		var after := _places(m)
		for k in before:
			if not after.has(k) or str(before[k]) != str(after[k]):
				same = false
				where = "%s %s: %s -> %s" % [page, k, before[k], after.get(k)]
				break
	_check(same, "with an empty layout every menu control stays exactly where it was (%s)" % where)
	_check(AUI.has("menu.inventory.panel") or m.page != "inventory", "...while its parts are tagged")
	await _open("inventory")
	var ids: Array = AUI.ids_on_screen(m)
	_check(ids.has("menu.inventory.panel") and ids.has("menu.inventory.title") and ids.has("rail.box") and ids.has("rail.ident") and ids.has("rail.list")
		and ids.any(func(id): return String(id).contains(".card")) and ids.any(func(id): return String(id).contains(".column")),
		"the inventory's panel, title, columns and card and the rail are arrangeable, with page-and-element names (%s)" % [ids])
	var all_still := true
	for id in ids:
		var c: Control = AUI.node(id)
		if c != null and id != "rail.box" and (c.scale != Vector2.ONE or not _rect_near(AUI.rect(id), AUI.default_rect(id), 0.5)):
			all_still = false
	_check(all_still, "...and none of them is moved or scaled")


## A menu's element: chosen by the mouse, dragged, scaled by the wheel; the
## page stays showing; the panel moves, scales and widens.
func _menu_element() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	await _open("inventory")
	await _arrange_open()
	_check(ar.is_open and ar.menu_mode and m.visible and m.page == "inventory", "F2 over a menu arranges the menu, which stays showing")
	_check(ar.toolbar()["buttons"].any(func(b): return b[0] == "reset_page") and ar.toolbar()["buttons"].any(func(b): return b[0] == "view"), "...its toolbar has Reset page and Arrange the HUD")
	var id := "menu.inventory.title"
	var title: Control = AUI.node(id)
	var r0: Rect2 = ar.screen_rect(id)
	var g0: Rect2 = title.get_global_rect()
	# Hovering lights it with its name.
	var at := r0.position + Vector2(40, 20)
	t._mouse_drag_to(at)
	await t._frames(2)
	_check(ar.hover_el == id, "the element under the pointer lights up (%s)" % ar.hover_el)
	await _drag(at, at + Vector2(37, 23))
	var g1: Rect2 = title.get_global_rect()
	_check(ar.sel == id and _near(g1.position, g0.position + Vector2(37, 23), 1.5), "dragging the inventory's title moves it (%s -> %s)" % [g0.position, g1.position])
	var ov = L.get_override(id)
	_check(ov != null and ov["anchor"] == "own" and absf(float(ov["x"]) - 37.0 / m.get_viewport_rect().size.x) < 0.002, "...kept as a share of the screen from its own place (%s)" % [ov])
	await _wheel(g1.get_center(), true)
	await _wheel(g1.get_center(), true)
	await t._frames(2)
	_check(absf(AUI.scale_of(id) - 1.1) < 0.001 and is_equal_approx(title.scale.x, 1.1), "the wheel scales it (%.2f)" % AUI.scale_of(id))
	# A second click on it picks the bigger thing around it.
	var c: Vector2 = ar.screen_rect(id).get_center()
	t._mouse_button(c, MOUSE_BUTTON_LEFT, true)
	await t._frames(1)
	t._mouse_button(c, MOUSE_BUTTON_LEFT, false)
	await t._frames(2)
	_check(ar.sel == "menu.inventory.panel", "clicking again picks the bigger thing around it (%s)" % ar.sel)
	# The panel: moved, scaled, made wider by its side handle.
	var pid := "menu.inventory.panel"
	var p0: Rect2 = m.panel.get_global_rect()
	ar._apply(pid, Rect2(p0.position + Vector2(-40, 16), p0.size))
	await t._frames(3)
	_check(_near(m.panel.get_global_rect().position, p0.position + Vector2(-40, 16), 1.5), "the page's panel moves (%s)" % m.panel.get_global_rect().position)
	var handles: Array = ar.side_handles(pid)
	_check(handles.any(func(h): return h[0] == "right"), "the panel has side handles")
	var w0: float = m.panel.get_global_rect().size.x
	var right: Vector2 = handles.filter(func(h): return h[0] == "right")[0][1]
	await _drag(right, right + Vector2(-60, 0))
	await t._frames(4)
	var w1: float = m.panel.get_global_rect().size.x
	_check(w1 < w0 - 40.0 and AUI.factor(pid, "w") < 1.0, "pulling its side makes it narrower (%.0f -> %.0f)" % [w0, w1])
	ar.nudge_scale(-0.1)
	await t._frames(3)
	_check(absf(AUI.scale_of(pid) - 0.9) < 0.001 and is_equal_approx(m.center.scale.x, 0.9), "...and it scales")
	var vr := Rect2(Vector2.ZERO, m.get_viewport_rect().size)
	_check(vr.grow(0.5).encloses(m.panel.get_global_rect()), "...staying on screen")
	ar.close()
	await t._frames(4)
	_check(m.is_open() and m.page == "inventory" and m.process_mode == Node.PROCESS_MODE_ALWAYS, "closing gives the menu back")


## The rail: its width (the side handle), its text size (the wheel), who
## you are and the list's spacing.
func _rail() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	await _open("pause")
	await _arrange_open()
	var w0: float = m.rail.size.x
	ar.sel = "rail.box"
	var handle: Array = ar.side_handles("rail.box")
	_check(handle.size() == 1 and handle[0][0] == "right", "the rail has a handle on its right edge")
	await _drag(handle[0][1], handle[0][1] + Vector2(48, 0))
	await t._frames(3)
	_check(m.rail.size.x > w0 + 40.0 and m.center.position.x >= m.rail.size.x - 0.5, "pulling it makes the rail wider, the page beside it (%.0f -> %.0f)" % [w0, m.rail.size.x])
	await _wheel(Vector2(40, 300), true)
	await t._frames(2)
	_check(ar.sel == "rail.box" and absf(m.rail.pane.scale.x - 1.05) < 0.001, "the wheel makes its text bigger (%.2f)" % m.rail.pane.scale.x)
	var ident: Control = m.rail.ident
	var i0: Rect2 = ident.get_global_rect()
	ar.sel = "rail.ident"
	ar._apply("rail.ident", Rect2(i0.position + Vector2(0, 30), i0.size))
	await t._frames(2)
	_check(ident.get_global_rect().position.y > i0.position.y + 20.0 and m.rail.get_global_rect().grow(0.5).encloses(ident.get_global_rect()),
		"who you are moves within the rail")
	var sep0: int = m.rail.list.get_theme_constant("separation")
	var lr: Rect2 = ar.screen_rect("rail.list")
	AUI.resize_to("rail.list", "h", AUI.default_rect("rail.list").size.y + 60.0)
	ar._changed()
	await t._frames(3)
	_check(m.rail.list.get_theme_constant("separation") > sep0, "the list's bottom edge spreads its pages apart (%d -> %d)" % [sep0, m.rail.list.get_theme_constant("separation")])
	_check(lr.size.y > 0.0, "...")
	ar.close()
	await t._frames(4)


## The train: each car's furniture moves and scales on its own.
func _train() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	t.main.open_train()
	await t._frames(6)
	if m.page != "train":
		m.open("train")
		await t._frames(4)
	m.train_page.go_to(m.train_page._index("personal"))
	await t._frames(6)
	await _arrange_open()
	var ids: Array = ar.elements()
	_check(ids.has("train.personal.book") and ids.has("train.personal.pack") and ids.has("train.personal.placard") and not ids.any(func(i): return String(i).begins_with("train.store")),
		"in Your Car: its book, pack and placard can be arranged (and not the other cars') (%s)" % [ids])
	var book: Control = AUI.node("train.personal.book")
	var b0: Rect2 = book.get_global_rect()
	ar.sel = "train.personal.book"
	ar._apply("train.personal.book", Rect2(b0.position + Vector2(-50, -30), b0.size * 1.25))
	await t._frames(3)
	var b1: Rect2 = book.get_global_rect()
	_check(_near(b1.position, b0.position + Vector2(-50, -30), 2.0) and absf(b1.size.x - b0.size.x * 1.25) < 2.0, "the book on its cushion moves and grows (%s -> %s)" % [b0, b1])
	_check(m.train_page.roots["personal"].get_global_rect().grow(0.5).encloses(b1), "...inside its car")
	ar.close()
	await t._frames(4)


## Save writes the arrangement (and, from the editor, data/layout.json);
## loading it again puts everything back; Reset puts the defaults back.
func _save_reload_reset() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	var ids := ["menu.inventory.title", "menu.inventory.panel", "rail.box", "rail.ident", "train.personal.book"]
	var snap: Dictionary = L.snapshot()
	_check(ids.all(func(id): return snap["desktop"].has(id)), "the menu's, the rail's and the train's arrangements are in the layout")
	var r := L.save()
	_check(r["user"] and r["project"] == true and FileAccess.file_exists(L.project_path), "Save keeps them (and writes the shared file)")
	var saved = L.parse(FileAccess.get_file_as_string(L.project_path))
	_check(saved != null and ids.all(func(id): return saved["desktop"].has(id) and saved["desktop"][id]["anchor"] == "own"), "...as 'own' entries in data/layout.json's format")
	var book_r: Rect2 = AUI.node("train.personal.book").get_global_rect()
	var rail_w: float = m.rail.size.x
	L.clear_state()
	L.load_all(true)
	_check(L.snapshot() == snap, "loading it again gives the same arrangement")
	m.open("train")
	await t._frames(5)
	_check(_rect_near(AUI.node("train.personal.book").get_global_rect(), book_r, 1.5) and absf(m.rail.size.x - rail_w) < 0.5, "...and the train's book and the rail are back where they were put")
	await _open("inventory")
	var title: Control = AUI.node("menu.inventory.title")
	_check(title != null and is_equal_approx(title.scale.x, 1.1), "...and the inventory's title too")
	# Reset this, then Reset page.
	await _arrange_open()
	ar.sel = "menu.inventory.title"
	ar.press("reset_one")
	ar.press("reset_one")
	await t._frames(4)
	title = AUI.node("menu.inventory.title")
	_check(L.get_override("menu.inventory.title") == null and title.scale == Vector2.ONE and _rect_near(AUI.rect("menu.inventory.title"), AUI.default_rect("menu.inventory.title"), 0.5),
		"Reset this puts the title back")
	ar.press("reset_page")
	ar.press("reset_page")
	await t._frames(5)
	_check(ar.elements().all(func(id): return L.get_override(id) == null) and L.get_override("train.personal.book") != null, "Reset page puts back everything showing (not the train's)")
	_check(is_equal_approx(m.center.scale.x, 1.0) and absf(m.rail.size.x - m.RailScript.WIDE) < 0.5, "...the panel and the rail as built")
	ar.answer("discard")
	await t._frames(4)
	_check(L.get_override("menu.inventory.title") != null and not L.dirty(), "Don't save goes back to the saved layout")
	L.clear_state()
	await _open("inventory")


## A layout made on the computer fits a phone: the phone uses it, kept on
## screen and inside each page and car.
func _phone() -> void:
	var m = t.main.menu
	var root = t.root
	var was: Vector2i = root.size
	L.clear_state()
	L.set_override("menu.inventory.panel", {"anchor": "own", "x": 0.4, "y": 0.3, "scale": 1.4})
	L.set_override("menu.inventory.title", {"anchor": "own", "x": 0.5, "y": 0.2, "scale": 2.0})
	L.set_override("rail.box", {"anchor": "own", "x": 0.0, "y": 0.0, "scale": 1.0, "w": 1.6})
	L.set_override("train.personal.book", {"anchor": "own", "x": -0.9, "y": 0.9, "scale": 2.5})
	root.size = Vector2i(800, 400)
	t.main.touch._set_active(true)
	await t._frames(3)
	_check(L.active_set == "touch" and AUI.override("menu.inventory.panel") != null, "the phone uses the computer's arrangement of a menu")
	await _open("inventory")
	await t._frames(3)
	var view := Rect2(Vector2.ZERO, m.get_viewport_rect().size)
	var pr: Rect2 = m.panel.get_global_rect()
	_check(view.grow(1.0).encloses(pr), "a panel moved and scaled on the computer stays on a phone's screen (%s on %s)" % [pr, view.size])
	var tr: Rect2 = AUI.rect("menu.inventory.title")
	_check(view.grow(1.0).encloses(tr), "...and its title on the screen (%s)" % tr)
	_check(m.rail.size.x < view.size.x * 0.5, "the wider rail still leaves the page room")
	t.main.open_train()
	await t._frames(4)
	if m.page != "train":
		m.open("train")
		await t._frames(4)
	m.train_page.go_to(m.train_page._index("personal"))
	await t._frames(6)
	var br: Rect2 = AUI.rect("train.personal.book")
	_check(m.train_page.roots["personal"].get_global_rect().grow(1.0).encloses(br) and view.grow(1.0).encloses(br), "the train's book stays inside its car (%s)" % br)
	t.main.touch._set_active(false)
	root.size = was
	L.clear_state()
	await t._frames(3)


## Closed, Arrange mode catches nothing: a click reaches the menu's button
## (where an arranged one is drawn).
func _off_catches_nothing() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	L.clear_state()
	m.inv_view = "worn"
	await _open("inventory")
	L.set_override("menu.inventory.row1.column1", {"anchor": "own", "x": 0.02, "y": 0.03, "scale": 1.0})
	AUI.apply_all()
	await t._frames(3)
	_check(not ar.is_open and not ar.visible and ar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Arrange mode closed is hidden and lets the mouse through")
	var pack: Button = null
	for b in m.box.find_children("*", "Button", true, false):
		if b.get_meta("view", "") == "pack" and b.is_visible_in_tree():
			pack = b
	_check(pack != null, "the inventory has its Pack tab")
	if pack != null:
		var at: Vector2 = pack.get_global_rect().get_center()
		t._mouse_drag_to(at)
		t._mouse_button(at, MOUSE_BUTTON_LEFT, true)
		await t._frames(2)
		t._mouse_button(at, MOUSE_BUTTON_LEFT, false)
		await t._frames(4)
		_check(m.inv_view == "pack" and not ar.is_open, "a click on a moved button presses it, Arrange mode closed")
	m.inv_view = "worn"
	L.clear_state()
	m.close()
	await t._frames(3)
