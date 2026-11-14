extends RefCounted
## Arrange mode, step 4 (arrange.gd, arrange_ui.gd, drawn_parts.gd): the
## train's furniture, one level in. Every car's furniture can be gone
## inside (headings, grids and their slots, buttons, notes, the placard's
## parts, the workshop wall's drawn parts, the crystal bar's kinds); parts
## move, save and load again; moved slots and buttons still answer a tap;
## a touch-only flow on a phone (915x412): opened from the Settings car,
## the cars switched, a part chosen from the list, dragged and sized with a
## finger, Back out, Save and Done, the toolbar and the list never over the
## block being moved; and Reset. Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")
const L := preload("res://scripts/layout.gd")
const AUI := preload("res://scripts/arrange_ui.gd")
const DrawnParts := preload("res://scripts/drawn_parts.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")

var t
var keep := []
## Furniture that has parts in each car (the store as it opens: the shelves).
const ENTERABLE := {
	"engine": ["board", "placard"],
	"store": ["speech", "shelf", "rail", "case", "placard"],
	"personal": ["rack", "pack", "chest", "placard"],
	"workshop": ["bench", "drawers", "plain", "placard"],
	"library": ["bookcase", "lectern"],
	"settings": ["signal", "brake"],
}


func run(smoke) -> void:
	t = smoke
	print("arrange mode, step 4: the train's furniture, one level in")
	await t._fresh_main()
	keep = [L.user_path, L.project_path, L.write_project]
	L.user_path = TestRun.path("user://arrange4_layout.cfg")
	L.project_path = TestRun.path("user://arrange4_layout.json")
	L.write_project = false
	L.clear_state()
	L.use_set("desktop")
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)
	t.main.grant_test_bonds()
	for e in t.main.enemies():
		e.set_physics_process(false)
	await _to_train()
	await _every_car()
	await _sell_counter()
	await _move_save_reload()
	await _taps_still_work()
	await _reset()
	await _phone_touch()
	# Tidy up.
	L.clear_state()
	L.use_set("desktop")
	for f in [L.user_path, L.project_path]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	L.user_path = keep[0]
	L.project_path = keep[1]
	L.write_project = keep[2]
	var ar = t.main.arrange
	if ar.is_open:
		ar.close()
	var m = t.main.menu
	if m.is_open():
		m.close()
	t.main.on_train = false
	t.paused = false
	await t._frames(3)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _to_train() -> void:
	var m = t.main.menu
	t.main.open_train()
	await t._frames(6)
	if m.page != "train":
		m.open("train")
		await t._frames(4)


func _go(car: String) -> void:
	var m = t.main.menu
	m.train_page.go_to(m.train_page._index(car))
	await t._frames(6)
	await t._wait(0.5)


func _arrange_open() -> void:
	var ar = t.main.arrange
	ar.open()
	await t._frames(3)
	if not ar.card.is_empty():
		ar.card_next(true)
	ar.intro = -1
	await t._frames(1)


func _close() -> void:
	var ar = t.main.arrange
	ar.asking = false
	ar.close()
	await t._frames(4)


## Each car's furniture is at the top level and can be gone inside, and
## what's inside has friendly names; slots inside a grid; the crystal bar
## and its kinds in every car.
func _every_car() -> void:
	var ar = t.main.arrange
	var m = t.main.menu
	for car in ENTERABLE:
		await _go(car)
		await _arrange_open()
		var top: Array = ar.level_blocks()
		_check(top.has("train.crystals") and top.has("rail.box"), "the %s car: the crystal bar and the rail are blocks (%s)" % [car, top])
		for f in ENTERABLE[car]:
			var id := "train.%s.%s" % [car, f]
			_check(top.has(id), "the %s car: %s is at the top level" % [car, id])
			_check(ar.enter(id), "...and can be gone inside (%s)" % id)
			var inside: Array = ar.level_blocks()
			_check(not inside.is_empty() and inside.all(func(k): return String(k).begins_with(id + ".")), "...its parts show (%s)" % [inside])
			_check(inside.all(func(k): return ar.label_of(k) != "" and ar.label_of(k) != k and not String(ar.label_of(k)).begins_with("train.")), "...each with a friendly name (%s)" % [inside.map(func(k): return ar.label_of(k))])
			_check(ar.screen_rect(id).grow(2.0).encloses(ar.screen_rect(inside[0])), "...lying on it (%s)" % inside[0])
			ar.back_out()
		# The crystal bar: each kind's crystals a part of their own.
		_check(ar.enter("train.crystals") and ar.level_blocks().size() == 6, "the %s car: the crystal bar holds each kind's crystals (%s)" % [car, ar.level_blocks()])
		ar.back_out()
		await _close()
	# A grid's slots; the placard's button; the workshop wall's drawn parts.
	await _go("personal")
	await _arrange_open()
	_check(ar.enter("train.personal.chest") and ar.level_blocks().has("train.personal.chest.grid") and ar.level_blocks().has("train.personal.chest.title"),
		"inside the stash: its heading and its grid (%s)" % [ar.level_blocks()])
	_check(ar.enter("train.personal.chest.grid") and ar.level_blocks().size() >= 8 and ar.label_of("train.personal.chest.grid.slot2") == "Stash space 2",
		"inside its grid: every stash space, named (%s)" % ar.label_of("train.personal.chest.grid.slot2"))
	_check(ar.crumbs() == ["Train: Your Car", "Stash", "Stash spaces"], "the breadcrumb says where (%s)" % [ar.crumbs()])
	await _close()
	await _go("workshop")
	await _arrange_open()
	_check(ar.enter("train.workshop.bench") and ar.level_blocks() == ["train.workshop.bench.lamp", "train.workshop.bench.tools", "train.workshop.bench.bottles",
		"train.workshop.bench.workbench", "train.workshop.bench.slate"], "the workshop's drawn wall: its lamp, pegboard, bottles, workbench and slate (%s)" % [ar.level_blocks()])
	await _close()
	_check(m.page == "train", "still on the train")


## The outfitter's Sell counter: what you brought down, its parts too.
func _sell_counter() -> void:
	var ar = t.main.arrange
	var m = t.main.menu
	var prof = t.main.profile
	prof.pack.append(Gear.make("dagger"))
	await _go("store")
	m.train_page._set_store("sell")
	await t._frames(6)
	await _arrange_open()
	var top: Array = ar.level_blocks()
	_check(top.has("train.store.plain") and top.has("train.store.pack"), "selling: the sign's panel and the pack are blocks (%s)" % [top])
	_check(ar.enter("train.store.pack") and ar.level_blocks().has("train.store.pack.grid"), "...the pack can be gone inside (%s)" % [ar.level_blocks()])
	ar.back_out()
	_check(ar.enter("train.store.plain") and ar.level_blocks().has("train.store.plain.title"), "...and the panel (%s)" % [ar.level_blocks()])
	await _close()
	m.train_page._set_store("shop")
	await t._frames(6)
	prof.pack.clear()


## A slot, a heading, a drawn part and a crystal moved; saved; loaded again.
func _move_save_reload() -> void:
	var ar = t.main.arrange
	var m = t.main.menu
	L.clear_state()
	await _go("personal")
	await _arrange_open()
	var slot := "train.personal.chest.grid.slot2"
	ar.enter("train.personal.chest")
	ar.enter("train.personal.chest.grid")
	ar.sel = slot
	var r0: Rect2 = ar.screen_rect(slot)
	var c0: Rect2 = AUI.node(slot).get_global_rect()
	ar._apply(slot, Rect2(r0.position + Vector2(40, -60), r0.size * 1.25))
	await t._frames(3)
	var c1: Rect2 = AUI.node(slot).get_global_rect()
	_check(c1.position.distance_to(c0.position + Vector2(40, -60)) < 3.0 and absf(c1.size.x - c0.size.x * 1.25) < 2.0,
		"a stash space moves and grows on its own (%s -> %s)" % [c0, c1])
	var others: Control = AUI.node("train.personal.chest.grid.slot3")
	_check(others != null and others.scale == Vector2.ONE, "...the one beside it stays")
	ar.back_out()
	ar.back_out()
	ar.enter("train.crystals")
	ar.sel = "train.crystals.water"
	var w0: Rect2 = ar.screen_rect("train.crystals.water")
	ar._apply("train.crystals.water", Rect2(w0.position + Vector2(0, -30), w0.size))
	await t._frames(2)
	await _close()
	await _go("workshop")
	await _arrange_open()
	ar.enter("train.workshop.bench")
	ar.sel = "train.workshop.bench.slate"
	var s0: Rect2 = ar.screen_rect("train.workshop.bench.slate")
	ar._apply("train.workshop.bench.slate", Rect2(s0.position + Vector2(-20, 0), s0.size * 0.9))
	await t._frames(2)
	var bench: Control = AUI.node("train.workshop.bench")
	_check(DrawnParts.xform(bench, "slate") != Transform2D.IDENTITY and DrawnParts.xform(bench, "lamp") == Transform2D.IDENTITY, "the slate drawn on the workshop wall moves on its own (the lamp stays)")
	await _close()
	var snap: Dictionary = L.snapshot()
	_check([slot, "train.crystals.water", "train.workshop.bench.slate"].all(func(id): return snap["desktop"].has(id) and snap["desktop"][id]["anchor"] == "own"),
		"the parts' places are in the layout, as 'own' entries")
	var res := L.save()
	_check(res["user"], "Save keeps them")
	L.clear_state()
	m.open("train")
	await t._frames(5)
	_check(AUI.node(slot).scale == Vector2.ONE, "(the built-in layout: the space as built)")
	L.load_all(true)
	_check(L.snapshot() == snap, "loading the saved layout gives the same arrangement")
	m.open("train")
	await t._frames(6)
	await _go("personal")
	var c2: Rect2 = AUI.node(slot).get_global_rect()
	_check(c2.position.distance_to(c1.position) < 3.0 and absf(c2.size.x - c1.size.x) < 2.0, "...and the stash space is back where it was put (%s, %s)" % [c1, c2])
	var water: Control = AUI.node("train.crystals.water")
	var purse: Control = water.get_parent().get_parent()
	_check(DrawnParts.xform(purse, "water") != Transform2D.IDENTITY, "...and the Water crystals too")


## Closed, a moved stash space and moved shop buttons answer a tap where they're drawn.
func _taps_still_work() -> void:
	var m = t.main.menu
	var prof = t.main.profile
	var slot := "train.personal.chest.grid.slot2"
	m.inv_sel = ""
	t.main.touch._set_active(true)
	await t._frames(4)
	if m.page != "train":
		await _to_train()
	await _go("personal")
	var cell: Control = AUI.node(slot)
	_check(cell != null and cell.scale.x > 1.1, "with a finger, the stash space is still moved")
	if cell == null:
		return
	var key := String(cell.get_child(0).get_meta("slot", ""))
	await t._tap_at(cell.get_global_rect().get_center())
	await t._frames(3)
	_check(m.inv_sel == key, "a tap on a moved stash space chooses it (%s, %s)" % [m.inv_sel, key])
	# The store: the Sell sign and the placard's Buy button, moved.
	await _go("store")
	L.set_override("train.store.sign", {"anchor": "own", "x": 0.03, "y": -0.04, "scale": 1.1})
	AUI.apply_all()
	await t._frames(3)
	var sign: Control = AUI.node("train.store.sign")
	_check(sign != null and sign.scale.x > 1.05, "the Sell sign is moved and grown")
	await t._tap_at(sign.get_global_rect().get_center())
	await t._frames(6)
	_check(m.train_store == "sell", "a tap on the moved Sell sign opens the Sell counter (%s)" % m.train_store)
	m.train_page._set_store("shop")
	await t._frames(6)
	prof.add_crystal("stone", 400.0)
	prof.add_crystal("water", 400.0)
	prof.add_crystal("fire", 400.0)
	prof.add_crystal("air", 400.0)
	prof.add_crystal("iron", 400.0)
	prof.add_crystal("blade", 400.0)
	m.open("train")
	await t._frames(6)
	var supply := String(m.inv_sel).get_slice(":", 1)
	_check(String(m.inv_sel).begins_with("supply:"), "the store's placard shows a supply (%s)" % m.inv_sel)
	var buy0: Rect2 = AUI.rect("train.store.placard.button")
	L.set_override("train.store.placard.button", {"anchor": "own", "x": 0.02, "y": 0.0, "scale": 0.8})
	AUI.apply_all()
	await t._frames(3)
	var buy: Control = AUI.node("train.store.placard.button")
	_check(buy is Button and buy.scale.x < 0.85 and buy.get_global_rect().get_center().x > buy0.get_center().x + 5.0, "the placard's Buy button is moved and shrunk (in its placard)")
	var had := int(prof.supplies.get(supply, 0))
	if buy != null:
		await t._tap_at(buy.get_global_rect().get_center())
		await t._frames(6)
	_check(int(prof.supplies.get(supply, 0)) == had + 1, "a tap on the moved Buy button buys it (%d -> %d)" % [had, int(prof.supplies.get(supply, 0))])
	t.main.touch._set_active(false)
	await t._frames(2)


## Reset this on a piece of furniture puts its parts back too.
func _reset() -> void:
	var ar = t.main.arrange
	await _go("personal")
	await _arrange_open()
	var slot := "train.personal.chest.grid.slot2"
	_check(ar.arranged_inside("train.personal.chest"), "the stash has something moved inside it")
	ar.sel = "train.personal.chest"
	ar.press("reset_one")
	await t._frames(3)
	_check(L.get_override(slot) == null and AUI.node(slot).scale == Vector2.ONE, "Reset this on the stash puts its space back")
	ar.sel = "train.crystals"
	ar.press("reset_one")
	await t._frames(2)
	_check(L.get_override("train.crystals.water") == null, "...and on the crystal bar, its Water crystals")
	ar.press("reset_all")
	ar.press("reset_all")
	await t._frames(4)
	_check(not L.snapshot()["desktop"].keys().any(func(k): return String(k).begins_with("train.")), "Reset all puts every car back")
	await _close()
	L.clear_state()


func _tap(pos: Vector2) -> void:
	await t._tap_at(pos)
	await t._frames(1)


func _finger_drag(from: Vector2, to: Vector2) -> void:
	t._touch(0, from, true)
	await t._frames(2)
	for i in 4:
		t._drag(0, from.lerp(to, (i + 1) / 4.0))
		await t._frames(1)
	t._touch(0, to, false)
	await t._frames(3)


func _button(ar, id: String) -> Rect2:
	for b in ar.toolbar()["buttons"]:
		if b[0] == id:
			return b[1]
	return Rect2()


## The phone: only taps and drags. Opened from the Settings car's button;
## the cars switched from the toolbar; a stash space chosen from the list,
## dragged and sized with a finger; Back out, Save and Done.
func _phone_touch() -> void:
	var m = t.main.menu
	var ar = t.main.arrange
	var root = t.root
	var was: Vector2i = root.size
	L.clear_state()
	root.size = Vector2i(915, 412)
	t.main.touch._set_active(true)
	t.main.apply_view_scale()
	await t._frames(3)
	await _to_train()
	m.open("train")
	await t._frames(4)
	await _go("settings")
	var view: Vector2 = ar.get_viewport_rect().size
	_check(view.y < ar.COMPACT_H, "a phone's view is short (%s)" % view)
	# The Settings car's button.
	var btn: Button = null
	for b in m.train_page.roots["settings"].find_children("*", "Button", true, false):
		if b.get_meta("setting", "") == "arrange":
			btn = b
	_check(btn != null and btn.text == ar.DEV["train"], "the Settings car has an \"Arrange the train\" button")
	if btn == null:
		return
	var sc: ScrollContainer = m.train_page.card_scrolls.get("settings")
	if sc != null:
		sc.ensure_control_visible(btn)
	var pane: ScrollContainer = m.train_page.car_scrolls.get("settings")
	if pane != null:
		pane.ensure_control_visible(btn)
	await t._frames(4)
	await _tap(btn.get_global_rect().get_center())
	await t._frames(4)
	_check(ar.is_open and ar.menu_mode and m.page == "train", "a tap on it opens Arrange mode over the train (%s)" % ar.screen_name())
	if not ar.is_open:
		return
	if not ar.card.is_empty():
		ar.card_next(true)
	ar.intro = -1
	await t._frames(2)
	var tb: Dictionary = ar.toolbar()
	var lp: Dictionary = ar.list_panel()
	var screen := Rect2(Vector2.ZERO, view)
	_check(tb.get("compact", false) and screen.encloses(tb["bar"]) and (tb["bar"] as Rect2).size.y <= view.y * 0.25, "the toolbar is one short strip on the screen (%s)" % tb["bar"])
	_check(lp["on"] and screen.encloses(lp["box"]) and not (lp["box"] as Rect2).intersects(tb["bar"]), "the list shows beside it, over the rail (%s)" % lp["box"])
	# The cars, from the toolbar: back to Your Car.
	for i in 3:
		await _tap(_button(ar, "car_prev").get_center())
		await t._frames(2)
	_check(m.train_car == "personal" and ar.is_open and ar.level_blocks().has("train.personal.chest"), "the toolbar's ‹ Car goes back along the train to Your Car (%s)" % m.train_car)
	# The stash from the list: a tap on its row, then its >.
	lp = ar.list_panel()
	var row = null
	for r in lp["rows"]:
		if r[0] == "train.personal.chest":
			row = r
	_check(row != null, "the list has a row for the stash")
	if row == null:
		return
	await _tap((row[1] as Rect2).position + Vector2(40, 10))
	_check(ar.sel == "train.personal.chest", "a tap on its row chooses it")
	lp = ar.list_panel()
	for r in lp["rows"]:
		if r[0] == "train.personal.chest" and r[3] != null:
			await t._wait(0.5)
			await _tap((r[3] as Rect2).get_center())
	_check(ar.path == ["train.personal.chest"], "its > goes inside (%s)" % [ar.path])
	# Into the grid with a double tap on it.
	var grid_r: Rect2 = ar.screen_rect("train.personal.chest.grid")
	var gp := grid_r.position + Vector2(grid_r.size.x * 0.5, grid_r.size.y * 0.5)
	await t._wait(0.5)
	await _tap(gp)
	await _tap(gp)
	_check(ar.path == ["train.personal.chest", "train.personal.chest.grid"] and String(ar.sel).begins_with("train.personal.chest.grid.slot"), "a double tap goes inside the grid (%s, %s)" % [ar.path, ar.sel])
	var slot: String = ar.sel
	var r0: Rect2 = ar.screen_rect(slot)
	# Drag it with a finger, from its middle.
	await t._wait(0.5)
	await _finger_drag(r0.get_center(), r0.get_center() + Vector2(48, -40))
	var r1: Rect2 = ar.screen_rect(slot)
	_check(r1.get_center().distance_to(r0.get_center() + Vector2(48, -40)) < 12.0 and ar.sel == slot, "a finger drags the space (%s -> %s)" % [r0, r1])
	tb = ar.toolbar()
	lp = ar.list_panel()
	_check(not (tb["bar"] as Rect2).intersects(r1) and not (lp["box"] as Rect2).intersects(r1), "neither the toolbar nor the list lies over it (%s, %s, %s)" % [tb["bar"], lp["box"], r1])
	# A corner handle (standing off a block this small) sizes it.
	var pts: Array = ar._handle_points(r1)
	_check((pts[2] as Vector2).x > r1.end.x and (pts[2] as Vector2).y > r1.end.y, "a small block's handles stand off its corners, for a finger")
	await _finger_drag(pts[2], (pts[2] as Vector2) + Vector2(20, 20))
	var r2: Rect2 = ar.screen_rect(slot)
	_check(r2.size.x > r1.size.x + 8.0 and absf(r2.position.x - r1.position.x) < 3.0, "pulling the corner handle sizes it, its far corner staying (%s -> %s)" % [r1, r2])
	# A block at the bottom: the toolbar steps up out of its way.
	ar.sel = "train.crystals"
	ar.path = []
	ar._changed()
	await t._frames(2)
	_check(not (ar.toolbar()["bar"] as Rect2).intersects(ar.screen_rect("train.crystals")), "with the crystal bar chosen, the toolbar stands clear of it (%s)" % ar.toolbar()["bar"])
	ar.sel = slot
	ar._sync()
	ar._changed()
	await t._frames(2)
	# Back out, Save and Done, by taps.
	await _tap(_button(ar, "back").get_center())
	_check(ar.path == ["train.personal.chest"], "Back out backs out (%s)" % [ar.path])
	await _tap(_button(ar, "save").get_center())
	_check(not L.dirty() and FileAccess.file_exists(L.user_path) and L.get_override(slot) != null, "Save keeps it")
	await _tap(_button(ar, "done").get_center())
	await t._frames(4)
	_check(not ar.is_open and m.page == "train", "Done finishes, the train showing")
	var cell: Control = AUI.node(slot)
	_check(cell != null and cell.scale.x > 1.05, "the space stays where it was put")
	t.main.touch._set_active(false)
	root.size = was
	t.main.apply_view_scale()
	L.clear_state()
	await t._frames(3)
