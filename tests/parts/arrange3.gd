extends RefCounted
## Arrange mode, step 3 (arrange.gd, arrange_ui.gd, layout.gd): the screen
## is shown as a few big blocks, one level at a time; Go inside and Back out
## move between levels; the list at the side chooses and resets blocks; blocks
## have friendly names; the chosen block has handles, a readout in plain
## numbers and an overlap warning; Undo and Redo; a layout saved before still
## applies; and Arrange mode closed catches no input. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const TestRun := preload("res://scripts/test_run.gd")
const L := preload("res://scripts/layout.gd")
const AUI := preload("res://scripts/arrange_ui.gd")
const UI := preload("res://scripts/ui.gd")
const Stations := preload("res://scripts/stations.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")

var t
var keep := []


func run(smoke) -> void:
	t = smoke
	print("arrange mode, step 3: levels, the list and names")
	await t._fresh_main()
	keep = [L.user_path, L.project_path, L.write_project]
	L.user_path = TestRun.path("user://arrange3_layout.cfg")
	L.project_path = TestRun.path("user://arrange3_layout.json")
	L.write_project = false
	L.clear_state()
	L.use_set("desktop")
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)
	t.main.grant_test_bonds()
	t.main.player.add_item("tonic")
	for e in t.main.enemies():
		e.set_physics_process(false)
	await t._frames(3)
	await _hud_levels()
	await _menu_levels()
	await _inside_and_out()
	await _the_list()
	await _names()
	await _views_and_scrolling()
	await _handles_and_readout()
	await _overlaps_undo_redo()
	await _old_layout()
	await _intro()
	await _off()
	# Tidy up: the built-in layout, the real paths, nothing left on disk.
	L.clear_state()
	L.use_set("desktop")
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


func _open(page: String) -> void:
	var m = t.main.menu
	if page == "inventory":
		t.main.on_train = false  # (on the train the inventory opens the Loadout: these checks want the climb's inventory page)
	if m.is_open():
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
	ar.intro = -1
	await t._frames(1)


func _click(pos: Vector2) -> void:
	t._mouse_drag_to(pos)
	await t._frames(1)
	t._mouse_button(pos, MOUSE_BUTTON_LEFT, true)
	await t._frames(1)
	t._mouse_button(pos, MOUSE_BUTTON_LEFT, false)
	await t._frames(2)


func _drag(from: Vector2, to: Vector2) -> void:
	t._mouse_button(from, MOUSE_BUTTON_LEFT, true)
	await t._frames(2)
	t._mouse_drag_to(to, true)
	await t._frames(2)
	t._mouse_button(to, MOUSE_BUTTON_LEFT, false)
	await t._frames(3)


## The level showing is a handful of blocks, none of their outlines inside
## another, their labels apart, and nothing from any other level drawn.
func _level_ok(what: String, most := 10) -> void:
	var ar = t.main.arrange
	var blocks: Array = ar.level_blocks()
	var outs: Array = ar.outlines()
	var nested := ""
	for a in outs:
		for b in outs:
			if a[0] != b[0] and (a[1] as Rect2).grow(0.5).encloses(b[1]):
				nested = "%s holds %s" % [a[0], b[0]]
	_check(blocks.size() >= 1 and blocks.size() <= most, "%s: a handful of blocks (%d: %s)" % [what, blocks.size(), blocks])
	_check(nested == "", "%s: no outline lies inside another (%s)" % [what, nested])
	_check(not outs.is_empty() and outs.all(func(o): return o[0] in blocks), "%s: only that level's outlines show" % what)
	var rects := {}
	for id in blocks:
		rects[id] = ar.screen_rect(id).abs()
	var chips: Dictionary = ar._place_labels(blocks, rects, UI.font("body"))
	var crossed := ""
	for a in chips:
		for b in chips:
			if a != b and (chips[a]["rect"] as Rect2).intersects(chips[b]["rect"]):
				crossed = "%s and %s" % [a, b]
	_check(crossed == "" and not chips.is_empty(), "%s: no two labels overlap (%s)" % [what, crossed])
	_check(blocks.all(func(id): return ar.label_of(id) != "" and not String(ar.label_of(id)).begins_with("menu.") and ar.label_of(id) != id), "%s: every block has a friendly name (%s)" % [what, blocks.map(func(id): return ar.label_of(id))])


## In play: the HUD's groups at the top level, their parts inside; the
## phone's layout too.
func _hud_levels() -> void:
	var ar = t.main.arrange
	await _arrange_open()
	_check(ar.is_open and not ar.menu_mode and ar.path.is_empty(), "F2 in play opens at the HUD's top level")
	var top: Array = ar.level_blocks()
	_check(top.has("group.status") and top.has("group.notices") and top.has("hud.hints") and not top.has("hud.bars") and not top.has("hud.weapon"),
		"the HUD's top level is its groups, not every element (%s)" % [top])
	await _level_ok("the HUD's top level")
	_check(ar.is_zone("hud.stair") and top.has("hud.stair") and not ar.outlines().any(func(o): return o[0] == "hud.stair"), "the stair arrow's ring, which fills the screen, is in the list but not outlined")
	var ring: Rect2 = ar.screen_rect("hud.stair")
	_check(ring.has_point(ring.get_center()) and not ar.blocks_at(ring.get_center()).has("hud.stair") and not ar.blocks_at(ring.position + Vector2(30, 30)).has("hud.stair"),
		"...and a click inside it doesn't pick it (it's chosen from the list)")
	ar.choose("hud.stair")
	_check(ar.blocks_at(ring.position + Vector2(30, 30)).has("hud.stair"), "...until it's the chosen one, when it can be dragged")
	ar.choose("group.status")
	_check(ar.enter("group.status") and ar.path == ["group.status"] and ar.level_blocks() == L.group_members("group.status"), "inside the status corner: its six parts")
	await _level_ok("inside the status corner")
	ar.back_out()
	ar.switch_set()
	await t._frames(3)
	if not ar.card.is_empty():
		ar.card_next(true)
	top = ar.level_blocks()
	_check(L.active_set == "touch" and top.has("group.touch_actions") and top.has("group.touch_menu") and top.has("touch.stick") and not top.has("touch.attack"),
		"the phone's layout: its buttons in two blocks (%s)" % [top])
	await _level_ok("the phone's top level")
	_check(L.is_loose("group.touch_actions") and ar.outlines().filter(func(o): return o[0] == "group.touch_actions").size() > 4, "the scattered action buttons are outlined button by button")
	var atk: Rect2 = ar.screen_rect("touch.attack")
	_check(ar.block_at(atk.get_center()) == "group.touch_actions", "...and a press on one of them picks the block")
	_check(ar.enter("group.touch_actions") and ar.level_blocks().has("touch.attack") and ar.level_blocks().has("touch.mark_6"), "inside it: each button")
	ar.switch_set()
	await t._frames(3)
	if not ar.card.is_empty():
		ar.card_next(true)
	ar.close()
	await t._frames(4)
	t.main.touch._set_active(false)
	await t._frames(2)


## Over menus, the train's cars and a station: the page and the rail at the
## top, the page's parts inside.
func _menu_levels() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	for page in ["inventory", "pause", "settings", "climber", "library", "dev"]:
		await _open(page)
		await _arrange_open()
		var panel := "menu.%s.panel" % page
		_check(ar.menu_mode and ar.level_blocks() == [panel, "rail.box"], "%s: the page and the rail are the top level (%s)" % [page, ar.level_blocks()])
		await _level_ok(page + "'s top level")
		_check(ar.enter(panel), page + ": the page can be gone inside")
		await _level_ok("inside the %s page" % page, 24)
		var frame: Rect2 = m.scroll.get_global_rect().grow(2.0)
		_check(ar.level_blocks().all(func(id): return not m.scroll.is_ancestor_of(AUI.node(id)) or ar.screen_rect(id).intersection(frame).get_area() >= ar.screen_rect(id).get_area() * 0.5),
			page + ": what's scrolled out of sight isn't offered")
		ar.close()
		await t._frames(4)
	# The inventory: the row that only holds its two columns isn't a block of its own.
	await _open("inventory")
	await _arrange_open()
	ar.enter("menu.inventory.panel")
	_check(ar.level_blocks() == ["menu.inventory.title", "menu.inventory.row1.column1", "menu.inventory.row1.column2"], "inside the inventory: its title and its two sides (%s)" % [ar.level_blocks()])
	_check(ar.enter("menu.inventory.row1.column2") and ar.level_blocks() == ["menu.inventory.row1.column2.card1"], "inside its right side: the item card")
	_check(ar.elements().has("menu.inventory.row1") and not ar.tree().has("menu.inventory.row1"), "...the row itself still exists (for a saved layout), only not as a block")
	ar.close()
	await t._frames(4)
	m.close()
	await t._frames(3)
	# The train: each car's furniture, and the rail.
	t.main.open_train()
	await t._frames(6)
	if m.page != "train":
		m.open("train")
		await t._frames(4)
	for car in m.train_page.roots.keys():
		m.train_page.go_to(m.train_page._index(String(car)))
		await t._frames(6)
		await t._wait(0.4)
		await _arrange_open()
		var top: Array = ar.level_blocks()
		_check(top.has("rail.box") and top.size() >= 2 and top.all(func(id): return id == "rail.box" or String(id).begins_with("train.%s." % car)), "the %s car: its furniture and the rail (%s)" % [car, top])
		await _level_ok("the %s car" % car)
		ar.close()
		await t._frames(4)
	# A station's page.
	m.go_station(String(Stations.STATIONS[0]["id"]), "gym")
	await t._frames(4)
	await t._wait(0.5)
	_check(m.page == "station", "at a station")
	await _arrange_open()
	_check(ar.level_blocks() == ["menu.station.panel", "rail.box"], "a station's page: the page and the rail (%s)" % [ar.level_blocks()])
	await _level_ok("the station's top level")
	_check(ar.enter("menu.station.panel"), "...and the page can be gone inside")
	await _level_ok("inside the station's page", 24)
	ar.close()
	await t._frames(4)
	m.rail_pressed("leave_station")
	await t._frames(3)
	m.close()
	await t._frames(3)
	t.main.on_train = false


## Go inside and Back out: double-click, Enter and Esc, the toolbar's
## buttons, the controller; the breadcrumb says where you are.
func _inside_and_out() -> void:
	var ar = t.main.arrange
	await _open("inventory")
	await _arrange_open()
	var page := "menu.inventory.panel"
	_check(ar.sel == page and ar.crumbs() == ["Inventory"], "it opens at the top, the page chosen (%s, %s)" % [ar.sel, ar.crumbs()])
	# Enter goes inside; Esc backs out; at the top Esc finishes.
	await t._key_tap(KEY_ENTER)
	_check(ar.path == [page] and ar.sel == "menu.inventory.title" and ar.crumbs() == ["Inventory", "Inventory page"], "Enter goes inside the chosen block (%s)" % [ar.crumbs()])
	await t._key_tap(KEY_ENTER)
	_check(ar.path == [page] and ar.toast != "", "Enter on a block with nothing inside says so")
	await t._key_tap(KEY_ESCAPE)
	_check(ar.is_open and ar.path.is_empty() and ar.sel == page, "Esc backs out, the block left chosen")
	# The toolbar's buttons.
	var tb: Dictionary = ar.toolbar()
	var inside: Array = tb["buttons"].filter(func(b): return b[0] == "inside")
	var back: Array = tb["buttons"].filter(func(b): return b[0] == "back")
	_check(inside.size() == 1 and back.size() == 1 and ar._button_live("inside") and not ar._button_live("back"), "the toolbar has Go inside and Back out (Back out dim at the top)")
	await _click(inside[0][1].get_center())
	_check(ar.path == [page], "Go inside goes inside")
	tb = ar.toolbar()
	back = tb["buttons"].filter(func(b): return b[0] == "back")
	await _click(back[0][1].get_center())
	_check(ar.path.is_empty() and ar.sel == page, "Back out backs out")
	# A double-click on a block goes inside it, choosing what's under the pointer.
	var right: Rect2 = ar.screen_rect("menu.inventory.row1.column2")
	var at := right.position + Vector2(right.size.x * 0.5, 30.0)
	await _click(at)
	_check(ar.path.is_empty() and ar.sel == page and ar.drag.is_empty(), "one click chooses the page (and moves nothing)")
	_check(L.get_override(page) == null and ar.undo.is_empty(), "...a click alone changes nothing")
	await _click(at)
	_check(ar.path == [page] and ar.sel == "menu.inventory.row1.column2", "a double-click goes inside it, the part under the pointer chosen (%s)" % ar.sel)
	await t._wait(0.5)
	await _click(at)
	await _click(at)
	_check(ar.path == [page, "menu.inventory.row1.column2"] and ar.crumbs() == ["Inventory", "Inventory page", AUI.NAMES["menu.inventory.row1.column2"]],
		"...and again, a level deeper, the breadcrumb following (%s)" % [ar.crumbs()])
	_check(ar.level_blocks() == ["menu.inventory.row1.column2.card1"] and ar.outlines().size() == 1, "only that level's one block is outlined")
	# A double-click outside the block you're in backs out.
	await t._wait(0.5)
	var out_at := Vector2(ar.screen_rect("menu.inventory.row1.column1").get_center())
	await _click(out_at)
	_check(ar.path.size() == 2, "one click outside does nothing")
	await _click(out_at)
	_check(ar.path == [page], "a double-click outside the block you're in backs out")
	await t._key_tap(KEY_ESCAPE)
	await t._key_tap(KEY_ESCAPE)
	await t._frames(4)
	_check(not ar.is_open, "at the top level Esc finishes")
	# The controller: A goes inside, B backs out, Start finishes.
	await _arrange_open()
	await t._pad_tap(JOY_BUTTON_A)
	_check(ar.path == [page], "a controller's A goes inside")
	await t._pad_tap(JOY_BUTTON_DPAD_DOWN)
	_check(ar.sel == "menu.inventory.row1.column1", "the d-pad steps through that level's blocks (%s)" % ar.sel)
	await t._pad_tap(JOY_BUTTON_B)
	_check(ar.is_open and ar.path.is_empty() and ar.sel == page, "B backs out")
	await t._pad_tap(JOY_BUTTON_START)
	await t._frames(4)
	_check(not ar.is_open, "Start finishes")
	t.main.pad._set_active(false)
	await t._frames(2)


## The list: its rows are the level's blocks; a click chooses, pointing
## lights, the > goes inside, the round arrow resets, a dot marks what moved.
func _the_list() -> void:
	var ar = t.main.arrange
	await _open("inventory")
	await _arrange_open()
	var lp: Dictionary = ar.list_panel()
	_check(lp["on"] and lp["rows"].map(func(r): return r[0]) == ar.level_blocks(), "the list shows the level's blocks, in order")
	_check(Rect2(Vector2.ZERO, ar.get_viewport_rect().size).encloses(lp["box"]) and not (lp["box"] as Rect2).intersects(ar.toolbar()["bar"]), "...on screen, clear of the toolbar")
	_check(not (lp["box"] as Rect2).intersects(ar.screen_rect("menu.inventory.panel")) and not (ar.toolbar()["bar"] as Rect2).intersects(ar.screen_rect("menu.inventory.panel")),
		"over a menu the list and the toolbar stand over the rail, clear of the page")
	# Pointing at a row lights its block; a click chooses it.
	ar.enter("menu.inventory.panel")
	await t._frames(2)
	lp = ar.list_panel()
	var row: Array = lp["rows"].filter(func(r): return r[0] == "menu.inventory.row1.column2")[0]
	var name_at: Vector2 = (row[1] as Rect2).position + Vector2(60, 12)
	t._mouse_drag_to(name_at)
	await t._frames(2)
	_check(ar.hover_el == "menu.inventory.row1.column2" and ar.sel != "menu.inventory.row1.column2", "pointing at a row lights its block up")
	await _click(name_at)
	_check(ar.sel == "menu.inventory.row1.column2" and ar.path == ["menu.inventory.panel"], "a click on a row chooses its block (%s)" % ar.sel)
	_check(row[2] == null and row[3] != null, "a block as built has no reset arrow; one with parts inside has a >")
	# Move it: the row gets its dot and its reset arrow.
	var r0: Rect2 = ar.screen_rect(ar.sel)
	await _drag(r0.get_center(), r0.get_center() + Vector2(24, 16))
	lp = ar.list_panel()
	row = lp["rows"].filter(func(r): return r[0] == "menu.inventory.row1.column2")[0]
	_check(ar.arranged("menu.inventory.row1.column2") and row[2] != null, "moved, its row has the dot and the round arrow")
	await _click((row[2] as Rect2).get_center())
	await t._frames(4)
	_check(not ar.arranged("menu.inventory.row1.column2") and L.get_override("menu.inventory.row1.column2") == null, "the round arrow puts it back")
	ar.do_undo()
	await t._frames(4)
	_check(ar.arranged("menu.inventory.row1.column2"), "...and Undo brings the move back")
	# At the top, the page's row shows something inside it was moved.
	ar.back_out()
	_check(not ar.arranged("menu.inventory.panel") and ar.arranged_inside("menu.inventory.panel"), "the page's row marks that something inside it moved")
	lp = ar.list_panel()
	row = lp["rows"].filter(func(r): return r[0] == "menu.inventory.panel")[0]
	await _click((row[2] as Rect2).get_center())
	await t._frames(4)
	_check(not ar.arranged_inside("menu.inventory.panel"), "...and its round arrow puts back the page and all that's inside it")
	# The > on a row goes inside; the list's Back out goes back.
	lp = ar.list_panel()
	row = lp["rows"].filter(func(r): return r[0] == "menu.inventory.panel")[0]
	await _click((row[3] as Rect2).get_center())
	_check(ar.path == ["menu.inventory.panel"], "a row's > goes inside its block")
	lp = ar.list_panel()
	await _click((lp["back"] as Rect2).get_center())
	_check(ar.path.is_empty(), "the list's Back out backs out")
	# The rail chosen: the column steps aside, so the rail shows.
	ar.choose("rail.box")
	await t._frames(2)
	lp = ar.list_panel()
	_check(not (lp["box"] as Rect2).intersects(ar.screen_rect("rail.box")) and not (ar.toolbar()["bar"] as Rect2).intersects(ar.screen_rect("rail.box")), "with the rail chosen, the list and the toolbar step off it")
	# The toolbar's List button hides and shows it.
	ar.press("list")
	_check(not ar.list_panel()["on"], "List: off hides the list")
	ar.press("list")
	_check(ar.list_panel()["on"], "...and on shows it again")
	ar.list_user = -1  # (as it starts: by the view's size)
	ar.close()
	await t._frames(4)
	L.clear_state()


## Friendly names: from the names table, else made from the block's kind
## and its own words; the stable ids underneath are unchanged.
func _names() -> void:
	var ar = t.main.arrange
	await _open("inventory")
	await _arrange_open()
	_check(ar.label_of("menu.inventory.panel") == "Inventory page" and ar.label_of("rail.box") == "Left rail", "the page and the rail are called what they are")
	_check(ar.label_of("menu.inventory.title") == AUI.NAMES["*.title"] and ar.label_of("menu.inventory.row1.column1") == AUI.NAMES["menu.inventory.row1.column1"]
		and ar.label_of("menu.inventory.row1.column2.card1") == AUI.NAMES["menu.inventory.row1.column2.card1"], "names come from the names table (%s)" % ar.label_of("menu.inventory.row1.column1"))
	_check(AUI.display_name("menu.inventory.title") == "Inventory: Title", "the full name says the page too")
	_check(ar.label_of("group.status") == L.GROUPS["group.status"]["name"] and ar.label_of("hud.bars") == L.ELEMENTS["hud.bars"]["name"], "the HUD's blocks and elements are named in layout.gd")
	ar.close()
	await t._frames(4)
	# No name in the table: its kind and its own words.
	await _open("settings")
	await _arrange_open()
	ar.enter("menu.settings.panel")
	var names: Array = ar.level_blocks().map(func(id): return ar.label_of(id))
	_check(names.has("Row “Music”") and names.has("Tabs") and names.has(AUI.NAMES["menu.settings.settings.row1"]), "a row nobody named is called by its kind and its words (%s)" % [names])
	var seen := {}
	var twice := ""
	for n in names:
		if seen.has(n):
			twice = n
		seen[n] = true
	_check(twice == "", "no two blocks of a level share a name (%s)" % twice)
	ar.close()
	await t._frames(4)
	await _open("dev")
	await _arrange_open()
	ar.enter("menu.dev.panel")
	names = ar.level_blocks().map(func(id): return ar.label_of(id))
	_check(names.any(func(n): return String(n).begins_with("Heading “")), "a section's heading is called a heading (%s)" % [names])
	ar.close()
	await t._frames(4)
	t.main.menu.close()
	await t._frames(3)


## Switching between the menu and the HUD, and the computer's and the
## phone's layouts, starts at the top level each time; a long level scrolls
## in the list.
func _views_and_scrolling() -> void:
	var ar = t.main.arrange
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(1280, 720)  # (a view the Settings page's rows don't all fit the list on)
	await t._frames(3)
	await _open("settings")
	await _arrange_open()
	ar.enter("menu.settings.panel")
	var n: int = ar.level_blocks().size()
	var lp: Dictionary = ar.list_panel()
	_check(n > lp["rows"].size() and lp["down"] != null and lp["up"] == null, "a level with more blocks than the list has room for scrolls (%d of %d rows showing)" % [lp["rows"].size(), n])
	_check((lp["rows"] as Array).all(func(r): return (lp["view"] as Rect2).grow(1.0).encloses(r[1])) and (lp["box"] as Rect2).encloses(lp["detail"]), "...its rows inside its window")
	ar.choose(ar.level_blocks()[n - 1])
	await t._frames(2)
	lp = ar.list_panel()
	_check((lp["rows"] as Array).any(func(r): return r[0] == ar.sel) and lp["up"] != null, "choosing the last block scrolls its row into sight")
	await _click((lp["up"] as Rect2).get_center())
	lp = ar.list_panel()
	_check(lp["rows"][0][0] == ar.level_blocks()[0], "the list's arrow scrolls back up")
	# The HUD from over a menu, and back.
	ar.press("view")
	await t._frames(3)
	_check(not ar.menu_mode and ar.path.is_empty() and ar.level_blocks().has("group.status") and ar.sel == "group.status" and not t.main.menu.visible, "Arrange the HUD: the HUD's top level (the menu hidden)")
	ar.press("view")
	await t._frames(3)
	_check(ar.menu_mode and ar.path.is_empty() and ar.level_blocks() == ["menu.settings.panel", "rail.box"] and t.main.menu.visible, "Arrange the menu: the menu's top level again")
	# The phone's layout of the menu, and back.
	ar.enter("menu.settings.panel")
	ar.switch_set()
	await t._frames(4)
	_check(L.active_set == "touch" and ar.is_open and ar.path == ["menu.settings.panel"] and not ar.level_blocks().is_empty() and ar.level_blocks().has(ar.sel),
		"the phone's layout of the menu: still inside the page, a block of it chosen (%s)" % ar.sel)
	var view := Rect2(Vector2.ZERO, ar.get_viewport_rect().size)
	_check(view.encloses(ar.toolbar()["bar"]) and (not ar.list_panel()["on"] or view.encloses(ar.list_panel()["box"])), "...the toolbar (and the list, if it shows) on the smaller view")
	ar.switch_set()
	await t._frames(4)
	_check(L.active_set == "desktop" and ar.path == ["menu.settings.panel"], "...and the computer's again")
	ar.close()
	await t._frames(4)
	t.main.touch._set_active(false)
	t.main.menu.close()
	t.root.size = was
	await t._frames(3)


## The chosen block: big handles, dragging its body, a corner, the arrow
## keys; a group moves all its parts; the readout says how far and how big.
func _handles_and_readout() -> void:
	var ar = t.main.arrange
	await _arrange_open()
	_check(ar.sel == "group.status" and ar.HANDLE >= 12.0, "the chosen block has big handles")
	var before := {}
	for id in L.group_members("group.status"):
		before[id] = ar.screen_rect(id)
	var g0: Rect2 = ar.screen_rect("group.status")
	_check(ar.readout("group.status") == [ar.TEXT["not_moved"], ar.TEXT["size"] % 100], "as built, the readout says so (%s)" % [ar.readout("group.status")])
	# Dragging the block moves every part by the same amount (Shift: no snapping).
	await _drag(g0.get_center(), g0.get_center() + Vector2(200, 120))
	var same := true
	for id in before:
		var now: Rect2 = ar.screen_rect(id)
		if now.position.distance_to((before[id] as Rect2).position + Vector2(200, 120)) > 1.0 or now.size.distance_to((before[id] as Rect2).size) > 0.5:
			same = false
	_check(same and L.moved("hud.bars") and L.moved("hud.marks") and L.get_override("group.status") == null, "dragging the status corner moves each of its parts together (and only they are saved)")
	_check(ar.readout("group.status")[0] == ar.TEXT["moved"] % (ar.TEXT["right"] % 200 + ar.TEXT["and"] + ar.TEXT["down"] % 120), "the readout says how far in plain numbers (%s)" % ar.readout("group.status")[0])
	# A corner scales it, parts and all.
	var g1: Rect2 = ar.screen_rect("group.status")
	await _drag(g1.end, g1.end + Vector2(g1.size.x * 0.5, g1.size.y * 0.5))
	var g2: Rect2 = ar.screen_rect("group.status")
	_check(absf(g2.size.x / g1.size.x - 1.5) < 0.03 and g2.position.distance_to(g1.position) < 1.5, "pulling a corner makes the whole block bigger, its other corner staying put (%s -> %s)" % [g1.size, g2.size])
	_check(absf(L.get_override("hud.bars")["scale"] - 1.5) < 0.03 and ar.readout("group.status")[1] == ar.TEXT["size"] % 150, "...each part scaled, the readout saying 150%% (%s)" % ar.readout("group.status")[1])
	# The arrow keys nudge it.
	var x0: float = ar.screen_rect("group.status").position.x
	await t._key_tap(KEY_RIGHT)
	_check(absf(ar.screen_rect("group.status").position.x - x0 - ar.GRID) < 0.6, "the arrow keys nudge the chosen block")
	# Reset this puts the chosen block back (Undo brings it back).
	ar.press("reset_one")
	_check(not ar.arranged("group.status") and not L.moved("hud.bars") and not L.moved("hud.weapon"), "Reset this puts the block and its parts back")
	ar.answer("discard")
	await t._frames(4)
	L.clear_state()
	# Over a menu: what can't be dragged isn't dragged; sides resize where they can.
	await _open("inventory")
	await _arrange_open()
	_check(not ar.can_move("rail.box") and ar.can_move("menu.inventory.panel"), "the rail can't be dragged from the left edge; the page can")
	ar.choose("rail.box")
	await t._frames(2)
	var rr: Rect2 = ar.screen_rect("rail.box")
	await _drag(Vector2(rr.get_center().x, rr.size.y * 0.42), Vector2(rr.get_center().x + 60.0, rr.size.y * 0.42))
	_check(L.get_override("rail.box") == null and not ar.arranged("rail.box"), "...dragging its body leaves it alone (no arrangement made)")
	_check(ar.side_handles("rail.box").size() == 1 and ar.side_handles("menu.inventory.panel").size() == 2 and ar.side_handles("menu.inventory.title").is_empty(),
		"side handles only where a block can be made wider")
	_check(AUI.how("rail.box") != "" and ar.detail_lines("rail.box").any(func(l): return l[0] == AUI.how("rail.box")), "the list says what's special about arranging the rail")
	ar.close()
	await t._frames(4)
	t.main.menu.close()
	await t._frames(3)
	L.clear_state()


## Blocks that come to overlap are flagged; Undo and Redo.
func _overlaps_undo_redo() -> void:
	var ar = t.main.arrange
	await _arrange_open()
	ar.enter("group.status")
	_check(ar.clashes("hud.weapon").is_empty() and ar._clashes(ar.level_blocks(), _rects(ar)).is_empty(), "as built nothing is flagged as overlapping")
	# Snapping to a neighbour's edge shows a guide line.
	ar.choose("hud.weapon")
	var under: Rect2 = ar.screen_rect("hud.essence")
	var w0: Rect2 = ar.screen_rect("hud.weapon")
	var to := w0.get_center() + Vector2(0.0, under.end.y - w0.position.y + 3.0)
	t._mouse_button(w0.get_center(), MOUSE_BUTTON_LEFT, true)
	await t._frames(2)
	t._mouse_drag_to(to)
	await t._frames(2)
	_check(absf(ar.screen_rect("hud.weapon").position.y - under.end.y) < 0.1 and ar.guides.any(func(g): return g[0] == "y" and absf(g[1] - under.end.y) < 0.1),
		"dragged near a neighbour's edge it snaps there, with a guide line (%s)" % [ar.guides])
	t._mouse_button(to, MOUSE_BUTTON_LEFT, false)
	await t._frames(2)
	_check(ar.guides.is_empty() and ar.clashes("hud.weapon").is_empty(), "...edge to edge isn't an overlap")
	ar.press("undo")
	var item: Rect2 = ar.screen_rect("hud.item")
	var marks: Rect2 = ar.screen_rect("hud.marks")
	ar.choose("hud.item")
	ar._push_undo()
	ar._apply("hud.item", Rect2(marks.position + Vector2(20, 0), item.size))
	await t._frames(2)
	_check(ar.clashes("hud.item") == ["hud.marks"] and ar.clashes("hud.marks") == ["hud.item"], "moved onto the marks, the quick item is flagged as overlapping them (%s)" % [ar.clashes("hud.item")])
	_check(ar.detail_lines("hud.item").any(func(l): return l[1] == "bad" and l[0] == ar.TEXT["overlaps"] % "Marks"), "...the list says \"Overlaps Marks\"")
	# Undo takes the move back; Redo does it again.
	_check(ar._button_live("undo") and not ar._button_live("redo"), "Undo is ready, Redo isn't yet")
	ar.press("undo")
	_check(not L.moved("hud.item") and ar.clashes("hud.item").is_empty() and ar._button_live("redo"), "Undo takes the move back, and the warning with it")
	await t._key_tap(KEY_Y)  # (no Ctrl: nothing)
	_check(not L.moved("hud.item"), "Y alone does nothing")
	ar.press("redo")
	_check(L.moved("hud.item") and ar.clashes("hud.item") == ["hud.marks"], "Redo does it again")
	ar.press("undo")
	ar._push_undo()
	ar._apply("hud.weapon", ar.screen_rect("hud.weapon"))
	_check(not ar._button_live("redo"), "a new change forgets what Redo held")
	var ids: Array = ar.toolbar()["buttons"].map(func(b): return b[0])
	_check(ids.has("undo") and ids.has("redo") and ids.has("reset_one") and ids.has("reset_all") and ids.has("save") and ids.has("done"), "the toolbar keeps Undo, Redo, the resets, Save and Done (%s)" % [ids])
	ar.answer("discard")
	await t._frames(4)
	L.clear_state()


func _rects(ar) -> Dictionary:
	var out := {}
	for id in ar.level_blocks():
		out[id] = ar.screen_rect(id).abs()
	return out


## A layout saved before the levels (data/layout.json's format, the old ids)
## still loads and applies, to every level, and its blocks can be reset.
func _old_layout() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	var old := {"format": 1,
		"desktop": {
			"hud.bars": {"anchor": "bl", "scale": 1.25, "x": 16.0, "y": -16.0},
			"menu.inventory.title": {"anchor": "own", "scale": 0.9, "x": 0.02, "y": 0.01},
			"menu.inventory.row1": {"anchor": "own", "scale": 1.0, "x": 0.0, "y": 0.02},
			"menu.inventory.row1.column2.card1": {"anchor": "own", "scale": 0.9, "x": -0.01, "y": 0.0},
			"rail.box": {"anchor": "own", "scale": 1.1, "w": 1.2, "x": 0.0, "y": 0.0},
			"train.personal.book": {"anchor": "own", "scale": 1.3, "x": -0.05, "y": -0.04},
		},
		"touch": {"touch.attack": {"anchor": "br", "scale": 1.1, "x": -12.0, "y": -8.0}}}
	var f := FileAccess.open(L.project_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old, "\t"))
	f.close()
	L.clear_state()
	L.load_all(false)
	var snap: Dictionary = L.snapshot()
	_check(snap["desktop"].size() == 6 and snap["touch"].has("touch.attack") and not L.dirty(), "an old data/layout.json loads whole (%s)" % [snap["desktop"].keys()])
	var view: Vector2 = t.main.hud.get_viewport_rect().size
	_check(L.box("hud.bars", view).position.distance_to(Vector2(16.0, view.y - 16.0 - 40.0)) < 0.6 and absf(L.box("hud.bars", view).size.x - 218.0 * 1.25) < 0.5, "the HUD's old entry applies (%s)" % L.box("hud.bars", view))
	await _open("inventory")
	var title: Control = AUI.node("menu.inventory.title")
	var card: Control = AUI.node("menu.inventory.row1.column2.card1")
	var row: Control = AUI.node("menu.inventory.row1")
	_check(is_equal_approx(title.scale.x, 0.9) and is_equal_approx(card.scale.x, 0.9) and absf(m.rail.size.x - m.RailScript.WIDE * 1.2) < 0.6,
		"the menu's old entries apply: the title, a card two levels down, the rail's width (%.2f, %.2f, %.0f)" % [title.scale.x, card.scale.x, m.rail.size.x])
	_check(absf(AUI.rect("menu.inventory.row1").position.y - AUI.default_rect("menu.inventory.row1").position.y - 0.02 * view.y) < 1.5 and row != null, "...and the row that isn't offered as a block by default")
	await _arrange_open()
	ar.enter("menu.inventory.panel")
	_check(ar.level_blocks().has("menu.inventory.row1") and ar.arranged("menu.inventory.row1"), "an arranged row shows as a block, so it can be put back (%s)" % [ar.level_blocks()])
	_check(ar.arranged("menu.inventory.title") and ar.arranged_inside("menu.inventory.row1") and ar.arranged("rail.box"), "what the old layout moved is marked as moved")
	L.write_project = true  # (as from the editor: Reset goes back to the built-in layout, not to this file's)
	ar.choose("menu.inventory.row1")
	ar.press("reset_one")
	await t._frames(5)
	_check(L.get_override("menu.inventory.row1") == null and L.get_override("menu.inventory.row1.column2.card1") == null and L.get_override("menu.inventory.title") != null,
		"Reset this puts back the row and what's inside it, and nothing else")
	_check(not ar.tree().has("menu.inventory.row1") and ar.level_blocks().has("menu.inventory.row1.column1"), "...after which its columns stand in the page again")
	# Saving keeps the ids as they always were.
	ar.save()
	var saved = L.parse(FileAccess.get_file_as_string(L.project_path))
	_check(saved != null and saved["desktop"].has("menu.inventory.title") and saved["desktop"].has("rail.box") and saved["desktop"].has("hud.bars") and saved["desktop"].has("train.personal.book")
		and not saved["desktop"].keys().any(func(k): return String(k).begins_with("group.")), "Save writes the same stable ids (no block names) (%s)" % [saved["desktop"].keys() if saved != null else []])
	L.write_project = false
	ar.close()
	await t._frames(4)
	m.close()
	await t._frames(3)
	L.clear_state()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(L.project_path))


## The first time: the Entity's card, then its three steps, ticked off as
## they're done (pick a block from the list, drag it, Save).
func _intro() -> void:
	var ar = t.main.arrange
	var steps: Array = Entity.TIPS["arrange"].get("steps", [])
	_check(steps.size() == 3 and ar.intro_steps() == steps, "the three steps are in the Entity's tip (%s)" % [steps])
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	ar.open()
	await t._frames(3)
	_check(ar.card.get("ids", []) == ["arrange"] and ar.intro == 0, "the first time, the Entity explains and the three steps begin")
	ar.card_next(true)
	await t._frames(2)
	var lp: Dictionary = ar.list_panel()
	_check((lp["intro"] as Rect2).size.y > 40.0 and (lp["box"] as Rect2).encloses(lp["intro"]), "the steps show at the top of the list")
	var row: Array = lp["rows"][1]
	await _click((row[1] as Rect2).position + Vector2(60, 12))
	_check(ar.intro == 1 and ar.sel == row[0], "step one: a block picked from the list")
	ar.choose("group.status")
	var r: Rect2 = ar.screen_rect("group.status")
	await _drag(r.get_center(), r.get_center() + Vector2(64, 48))
	_check(ar.intro == 2 and L.dirty(), "step two: it's dragged")
	ar.press("save")
	_check(ar.intro == -1 and not L.dirty(), "step three: Save (and the steps are done)")
	ar.card_next(true)
	ar.close()
	await t._frames(4)
	ar.open()
	await t._frames(2)
	_check(ar.card.is_empty() and ar.intro == -1, "the second time, no card and no steps")
	ar.press("help")
	_check(ar.card.get("ids", []) == ar.HELP and ar.intro == 0, "the toolbar's ? shows them again")
	ar.card_next(true)
	ar.close()
	await t._frames(4)
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	L.clear_state()
	for f in [L.user_path, L.project_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## Closed, Arrange mode catches nothing: where its list and toolbar stood, a
## click reaches the menu; its keys do nothing; it draws nothing.
func _off() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	await _open("pause")
	await _arrange_open()
	var list_box: Rect2 = ar.list_panel()["box"]
	var bar_box: Rect2 = ar.toolbar()["bar"]
	ar.enter("menu.pause.panel")
	ar.close()
	await t._frames(4)
	_check(not ar.is_open and not ar.visible and ar.mouse_filter == Control.MOUSE_FILTER_IGNORE and ar.path.is_empty(), "closed, Arrange mode is hidden and lets the mouse through")
	_check(m.is_open() and m.page == "pause" and m.process_mode == Node.PROCESS_MODE_ALWAYS, "the menu answers again")
	# A rail button under where the list stood is pressed by a click.
	var inv: Control = null
	for b in m.rail.buttons:
		if b.id == "inventory":
			inv = b
	_check(inv != null and (list_box.intersects(inv.get_global_rect()) or bar_box.intersects(inv.get_global_rect())), "the rail's Inventory button lies where Arrange mode's column stood")
	var sel0: String = ar.sel
	var redraws: int = ar.redraws
	if inv != null:
		var at: Vector2 = inv.get_global_rect().get_center()
		await _click(at)
		await t._frames(3)
		_check(m.page == "inventory" and not ar.is_open, "a click there presses the menu's button (%s)" % m.page)
	# Its keys: Enter, Tab and the arrows are the menu's own; nothing of Arrange mode's changes.
	await t._key_tap(KEY_TAB)
	await t._key_tap(KEY_RIGHT)
	await t._frames(2)
	_check(not ar.is_open and ar.sel == sel0 and ar.drag.is_empty() and ar.path.is_empty() and ar.hover_el == "" and L.snapshot() == {"desktop": {}, "touch": {}},
		"closed, its keys and the mouse change nothing of its own")
	_check(ar.redraws <= redraws + 1, "...and it draws nothing")
	if m.is_open():
		m.close()
	await t._frames(3)
	t.main.on_train = false
