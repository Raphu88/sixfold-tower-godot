extends Control
## Arrange mode: grab the things on screen and move them yourself.
##
## Opened from Dev tools ("Arrange layout") or with F2. The game pauses and
## every arrangeable element (layout.gd) shows a dashed gilt outline with its
## name. Then:
##   - Mouse or finger: drag an element to move it, pull a corner handle to
##     scale it (it keeps its shape). Positions snap to an 8 px grid, to the
##     screen's edges and centre lines and to the other elements' edges, with
##     guides showing while you drag; hold Shift to place freely.
##   - Keys: Tab / Shift+Tab pick the next element, the arrows nudge it (8 px,
##     1 px with Shift), [ and ] (or the wheel) scale it, Ctrl+Z undoes,
##     Ctrl+S saves, G turns the grid on or off, Esc, Enter or F2 finish.
##   - Controller: the d-pad or LB / RB pick the next element, the left stick
##     moves it, the right stick scales it, X undoes, Y saves, View turns the
##     grid on or off, and A or B finish.
##   - A small toolbar (drag it by its title to move it aside): Save, Copy
##     layout, Undo, Grid, Reset this, Reset all (each asks twice), Done, which
##     layout is being edited (computer or phone: on a computer the phone's
##     layout shows as the phone draws it), and a readout of the chosen
##     element's place and size.
## Finishing with unsaved changes asks whether to save them. The Entity
## explains it all (entity.gd's creator tips "arrange", "arrange_sets",
## "arrange_save" and "arrange_menus") in a card of this screen's own, the
## first time each comes up (tips on, as in play), and the toolbar's ? shows
## them again. The words are in TEXT.
##
## Over a menu (F2 with a page open, or Dev tools: Arrange menus) it
## arranges the menu instead, which stays showing: the page's panel, its
## title, rows, columns and cards, the left rail (its width, text size, who
## you are, the list's spacing) and, on the train, the furniture and
## placards of the car you're in (arrange_ui.gd tags them all). The element
## under the pointer lights up with its name; a second click where the chosen
## one is picks the bigger thing around it (PgUp / PgDn too). Side handles
## resize what can be resized (the panel's width, the rail's width and its
## list's spacing). Reset page puts back everything showing. The toolbar's
## "Arrange the HUD" / "Arrange the menu" switches between the two.

const Layout := preload("res://scripts/layout.gd")
const ArrangeUI := preload("res://scripts/arrange_ui.gd")
const UI := preload("res://scripts/ui.gd")
const Controls := preload("res://scripts/controls.gd")
const Nav := preload("res://scripts/nav.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
## The Entity's explanations, in the order ? shows them (over a menu, its own first).
const HELP := ["arrange", "arrange_sets", "arrange_save"]
const MENU_HELP := ["arrange_menus", "arrange", "arrange_sets", "arrange_save"]

const TEXT := {
	"title": "Arrange",
	"editing": "%s layout",
	"set_names": {"desktop": "Computer", "touch": "Phone"},
	"switch": {"desktop": "Edit the phone's", "touch": "Edit the computer's"},
	"save": "Save", "copy": "Copy layout", "undo": "Undo", "grid_on": "Grid: on", "grid_off": "Grid: off",
	"reset_one": "Reset this", "reset_page": "Reset page", "reset_all": "Reset all", "sure": "Sure?", "done": "Done",
	"view_menu": "Arrange the menu", "view_hud": "Arrange the HUD",
	"none": "Choose something: tap, click, Tab or the d-pad",
	"readout": "%s  ·  x %d  y %d  ·  %d × %d  ·  %d%%  ·  %s",
	"pinned": "pinned %s", "as_built": "as built", "moved": "moved from its place",
	"hint_keys": "Drag to move · drag a corner to scale · Shift: no snapping · Tab: next · arrows: nudge · [ ]: size · Ctrl+Z: undo · Esc: done",
	"hint_menu": "Point at a thing, drag to move · corner: scale · side: resize · wheel or [ ]: size · click again or PgUp: the bigger part · Esc: done",
	"hint_pad": "D-pad or {lb} {rb}: next · left stick: move · right stick: size · {x}: undo · {y}: save · {a} or {b}: done",
	"hint_touch": "Drag a thing to move it · pull a corner to scale it · drag this bar to move the toolbar",
	"saved": "Saved",
	"saved_project": "Saved, and to data/layout.json: commit it in GitHub Desktop to share it",
	"save_failed": "Couldn't save the layout",
	"copied": "Layout copied to the clipboard",
	"copy_title": "Your layout",
	"copy_note": "It's on the clipboard. On a phone: long-press in the box, Select all, then Copy, and paste it to Claude.",
	"close": "Close",
	"reset_one_done": "%s is back in its default place",
	"reset_page_done": "Everything showing is back in its default place",
	"reset_all_done": "Everything is back in its default place",
	"undone": "Undone", "nothing": "Nothing to undo",
	"ask": "Save your changes?",
	"ask_note": "They're used now either way; unsaved, they're gone after a restart.",
	"ask_save": "Save", "ask_discard": "Don't save", "ask_stay": "Keep arranging",
	"help": "?", "next": "Next", "page": "%d of %d",
}

## Snapping: the grid's step, and how close (px) an edge must come to a line to stick.
const GRID := 8.0
const SNAP := 6.0
const SNAP_TOUCH := 9.0
## Corner handles: drawn this big, grabbed from this far (a finger: farther).
const HANDLE := 8.0
const GRAB := 12.0
const GRAB_TOUCH := 20.0
## The controller: the left stick moves this many px a second, the right
## stick scales this much a second, past this deadzone.
const STICK_SPEED := 260.0
const STICK_SCALE := 0.9
const STICK_DEAD := 0.2
## How long a Reset waits for its second press (ms), and a notice stays.
const CONFIRM_MS := 3000
const TOAST_MS := 3500
const UNDO_MAX := 60

var main
var is_open := false
var sel := ""  # the chosen element
var grid := true
var drag := {}  # {kind: move / scale / bar, ptr: -1 mouse or touch index, from, rect, corner, scale}
var guides: Array = []  # [axis "x" or "y", where] while dragging
var undo: Array = []
var toast := ""
var toast_until := 0
var armed := ""  # a Reset waiting for its second press
var armed_until := 0
var asking := false  # "Save your changes?"
var ask_focus := 0
var bar_at := Vector2(-1, -1)  # the toolbar's top left (-1: centred)
var copy_open := false
var copy_text := ""
var copy_box: TextEdit
var axes := {}  # the controller's sticks (PAD_DEVICE axis -> value)
var stick_moving := false
var hover := ""  # the toolbar button under the mouse
var card := {}  # the Entity's card: {ids, i}
var card_then := ""  # what to do once it's closed ("finish")
var redraws := 0  # (tests)
var menu_mode := false  # arranging the menu showing (not the HUD)
var hover_el := ""  # over a menu: the element under the mouse (lit with its name)

var _menu_page := ""  # the menu page it was opened from (reopened on Done)
var _was_paused := false
var _was_touch := false
var _hud_kept: Array = []
var _closed_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(delta: float) -> void:
	if not is_open:
		if Input.is_action_just_pressed("arrange") and Engine.get_process_frames() != _closed_frame and can_open():
			open()
		return
	# The controller's sticks: move and scale the chosen element.
	if sel != "" and not asking and not copy_open:
		var dt := Nav.real_delta(delta)
		var lv := Vector2(float(axes.get(JOY_AXIS_LEFT_X, 0.0)), float(axes.get(JOY_AXIS_LEFT_Y, 0.0)))
		var rv := float(axes.get(JOY_AXIS_RIGHT_Y, 0.0))
		var push := lv.length() > STICK_DEAD or absf(rv) > STICK_DEAD
		if push and not stick_moving:
			stick_moving = true
			_push_undo()
		if lv.length() > STICK_DEAD:
			var r := screen_rect(sel)
			_apply(sel, Rect2(r.position + lv * lv.length() * STICK_SPEED * dt, r.size))
		if absf(rv) > STICK_DEAD:
			var r := screen_rect(sel)
			var f := 1.0 - rv * absf(rv) * STICK_SCALE * dt
			var c := r.get_center()
			_apply(sel, Rect2(c - r.size * f * 0.5, r.size * f))
		if not push and stick_moving:
			stick_moving = false
			_settle(sel)  # (let go: onto the grid)
	if toast != "" and Time.get_ticks_msec() > toast_until:
		toast = ""
		queue_redraw()
	if armed != "" and Time.get_ticks_msec() > armed_until:
		armed = ""
		queue_redraw()


## The Dev tools page's section (menu.gd): the button that opens Arrange mode.
static func dev_section(menu) -> void:
	menu._section(DEV["section"])
	var row: HBoxContainer = menu._row()
	var b: Button = menu._button(DEV["button"], _dev_open.bind(menu, "hud"), row)
	b.disabled = menu.main == null or menu.main.arrange == null
	var bm: Button = menu._button(DEV["menus"], _dev_open.bind(menu, "menu"), row)
	bm.disabled = b.disabled
	menu._note(DEV["note"])


static func _dev_open(menu, want: String) -> void:
	if menu.main != null and menu.main.arrange != null:
		menu.main.arrange.open(want)


const DEV := {
	"section": "Layout",
	"button": "Arrange layout",
	"menus": "Arrange menus",
	"note": "Arrange layout moves and scales the HUD and the touch buttons (F2 in play); Arrange menus does the same for this page, and F2 with any menu open (or on the train) for that one: its panels, titles, buttons, cards, the rail and the train's furniture. Save keeps it; run from the Godot editor, Save also writes data/layout.json for GitHub Desktop.",
}


## Not over the title screen, a new climber's look or a name being typed.
func can_open() -> bool:
	if main == null or main.player == null or main.title_showing():
		return false
	var m = main.menu
	return m == null or not m.is_open() or (m.page != "create" and not m._typing())


# --- opening and closing -------------------------------------------------------------

## `want`: "hud" arranges the HUD (an open menu hides), "menu" the menu
## showing, "" the menu if one is open, else the HUD.
func open(want := "") -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	_was_touch = main.touch_active
	var m = main.menu
	_menu_page = m.page if m != null and m.is_open() else ""
	menu_mode = _menu_page != "" and not (_menu_page in ArrangeUI.SKIP_PAGES) and want != "hud"
	hover_el = ""
	if m != null:
		if _menu_page != "" and not menu_mode:
			m.page = ""  # (hidden while arranging the HUD; Done opens it again)
			m.visible = false
		m.process_mode = Node.PROCESS_MODE_DISABLED  # (it stays showing over a menu, but doesn't answer)
	get_tree().paused = true
	if main.touch != null:
		main.touch.release_all()
	if main.pad != null:
		main.pad.release_all()
	# The floor title and the key hints show, so you see what you move.
	var hud = main.hud
	_hud_kept = []
	if hud != null and not menu_mode:
		_hud_kept = [hud.floor_t, hud.hints_t]
		hud.floor_t = hud.FLOOR_SHOW * 0.5
		hud.hints_t = hud.HINTS_SHOW * 0.5
	undo.clear()
	drag = {}
	guides.clear()
	asking = false
	armed = ""
	axes.clear()
	stick_moving = false
	if menu_mode:
		ArrangeUI.tag_page(m)  # (what's on the page now)
		get_viewport().gui_release_focus()  # (a controller's d-pad picks things here, not the page's buttons)
	var list := elements()
	if not (sel in list):
		sel = list[0] if not list.is_empty() else ""
	visible = true
	if main.has_method("sfx"):
		main.sfx("ui_open")
	card = {}
	var first: Array = []
	for id in (["arrange", "arrange_menus"] if menu_mode else ["arrange"]):
		if Guide.tell(id) != "":
			first.append(id)
	if not first.is_empty():
		show_card(first)
	_changed()


## What can be arranged now: the menu's elements (arrange_ui.gd), or the HUD's.
func elements() -> Array:
	if menu_mode and main.menu != null:
		return ArrangeUI.ids_on_screen(main.menu)
	return Layout.ids()


## Over a menu: arranges the menu (true) or the HUD (false, the menu hidden).
func set_view(on_menu: bool) -> void:
	var m = main.menu
	if _menu_page == "" or m == null or (_menu_page in ArrangeUI.SKIP_PAGES) or on_menu == menu_mode:
		return
	menu_mode = on_menu
	m.page = _menu_page if on_menu else ""
	m.visible = on_menu
	hover_el = ""
	drag = {}
	guides.clear()
	if on_menu:
		ArrangeUI.tag_page(m)
		_tell("arrange_menus")
	elif main.hud != null and _hud_kept.is_empty():
		# (the floor title and the key hints show, so you see what you move)
		_hud_kept = [main.hud.floor_t, main.hud.hints_t]
		main.hud.floor_t = main.hud.FLOOR_SHOW * 0.5
		main.hud.hints_t = main.hud.HINTS_SHOW * 0.5
	var list := elements()
	sel = list[0] if not list.is_empty() else ""
	_changed()


## The page built again as it is (after a resize, the other layout set).
func _rebuild_menu() -> void:
	var m = main.menu
	if not is_open or not menu_mode or m == null or m.page == "":
		return
	m._quiet = true
	m.open(m.page, m.opened_direct)
	m._quiet = false
	m.process_mode = Node.PROCESS_MODE_DISABLED
	get_viewport().gui_release_focus.call_deferred()  # (after the page puts its focus back)
	if not (sel in elements()):
		var list := elements()
		sel = list[0] if not list.is_empty() else ""
	_changed()


## Done: asks first if there are unsaved changes (and, the first time, the
## Entity says how saving works).
func finish() -> void:
	if not card.is_empty():
		return
	if _tell("arrange_save"):
		card_then = "finish"
		return
	if Layout.dirty():
		asking = true
		ask_focus = 0
		queue_redraw()
		return
	close()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_closed_frame = Engine.get_process_frames()
	drag = {}
	guides.clear()
	asking = false
	card = {}
	card_then = ""
	_hide_copy()
	var hud = main.hud
	if hud != null and _hud_kept.size() == 2:
		hud.floor_t = _hud_kept[0]
		hud.hints_t = _hud_kept[1]
	if main.touch != null and main.touch.active != _was_touch:
		main.touch._set_active(_was_touch)
	if main.has_method("sfx"):
		main.sfx("ui_close")
	# The menu comes back a frame later, so the key that finished doesn't
	# reach it too.
	_restore.call_deferred(_menu_page, _was_paused, menu_mode)
	_menu_page = ""
	hover_el = ""
	_changed()
	menu_mode = false


func _restore(page: String, was_paused: bool, quiet := false) -> void:
	var m = main.menu
	if m != null:
		m.process_mode = Node.PROCESS_MODE_ALWAYS
	if page != "" and m != null:
		m.visible = true
		if quiet and m.page == page:
			# (it stayed showing: built again as it is, so what was resized fits)
			m._quiet = true
			m.open(page, m.opened_direct)
			m._quiet = false
		else:
			m.open(page)
	else:
		get_tree().paused = was_paused


# --- where things are ------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size


func _hs() -> float:
	return main.hud.hud_scale if main.hud != null else 1.0


## A menu's, the rail's or the train's element (arrange_ui.gd), not the HUD's.
func is_live(id: String) -> bool:
	return not Layout.has(id) and ArrangeUI.has(id)


## An element's arranged box on the view, in view pixels.
func screen_rect(id: String) -> Rect2:
	if is_live(id):
		return ArrangeUI.rect(id)
	var k := Layout.space_scale(id, _hs())
	var b := Layout.box(id, Layout.space_size(id, _view(), _hs()))
	return Rect2(b.position * k, b.size * k)


## Its size at scale 1 (a menu's element: as resized).
func _default_size(id: String) -> Vector2:
	if is_live(id):
		return ArrangeUI.base_rect(id).size
	var k := Layout.space_scale(id, _hs())
	return Layout.default_box(id, Layout.space_size(id, _view(), _hs())).size * k


## Puts an element at this view rect (Layout re-anchors it to the nearest corner or edge).
func _apply(id: String, r: Rect2) -> void:
	if is_live(id):
		ArrangeUI.move_to(id, r)
		_changed()
		return
	var k := Layout.space_scale(id, _hs())
	Layout.move_to(id, Rect2(r.position / k, r.size / k), Layout.space_size(id, _view(), _hs()))
	_changed()


## Everything that draws from the layout redraws (the game is paused, so
## their own change checks don't run); over a menu, the menu is laid out again.
func _changed() -> void:
	queue_redraw()
	if main == null:
		return
	if menu_mode and main.menu != null and main.menu.page != "":
		ArrangeUI.refresh(main.menu)
	if main.hud != null:
		main.hud.queue_redraw()
		if main.hud.core != null:
			main.hud.core.queue_redraw()
	if main.touch != null:
		main.touch.queue_redraw()
	if main.entity != null:
		main.entity.queue_redraw()


## The element under a point: the smallest one there (so a button wins over
## the joystick zone it sits beside).
func element_at(pos: Vector2) -> String:
	var hits := elements_at(pos)
	return hits[0] if not hits.is_empty() else ""


## Every element under a point, the smallest first.
func elements_at(pos: Vector2) -> Array:
	var found: Array = []
	for id in elements():
		var r := screen_rect(id).abs().grow(0.0 if menu_mode else 4.0)
		if r.has_point(pos):
			found.append([r.get_area(), id])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.map(func(f): return f[1])


## Over a menu: the thing around the chosen one (`by` 1), or the biggest
## thing inside it (-1).
func pick_nested(by: int) -> void:
	if sel == "":
		return
	var r := screen_rect(sel)
	var best := ""
	var area := INF if by > 0 else -1.0
	for id in elements():
		if id == sel:
			continue
		var o := screen_rect(id)
		if by > 0 and o.grow(0.5).encloses(r) and o.get_area() > r.get_area() and o.get_area() < area:
			best = id
			area = o.get_area()
		elif by < 0 and r.grow(0.5).encloses(o) and o.get_area() < r.get_area() and o.get_area() > area:
			best = id
			area = o.get_area()
	if best != "":
		sel = best
		if main.has_method("sfx"):
			main.sfx("ui_move")
		queue_redraw()


## Is it on screen just now (the rest are outlined fainter)?
func showing(id: String) -> bool:
	if is_live(id):
		return true
	var p = main.player
	match id:
		"hud.item":
			return p != null and p.selected_item() != ""
		"hud.gem":
			return main.flow_shown() or (p != null and p.item_count("vessel") > 0)
		"hud.marks":
			return p != null and not p.bonds.is_empty()
		"hud.essence":
			return main.hud != null and main.hud.essence_t > 0.0
		"hud.banner":
			return not main.banner.is_empty()
		"hud.beast":
			return main.hud != null and main.hud._boss_alive()
		"hud.plates":
			return main.wings != null and (main.wings.challenge_live() or (main.door_view != null and not main.door_view.lock_status().is_empty()))
		"hud.stair":
			return main.stair_open
		"hud.entity":
			return main.entity != null and main.entity.showing()
	if id.begins_with("touch.") and id != "touch.stick" and main.touch != null:
		main.touch._layout()
		for b in main.touch.buttons:
			if b.get("el", "") == id:
				return true
		return false
	return true


## The name Arrange mode shows (a mark button says whose mark is there now).
func label_of(id: String) -> String:
	if is_live(id):
		return ArrangeUI.display_name(id)
	var name := Layout.display_name(id)
	if id.begins_with("touch.mark_") and main.touch != null:
		for b in main.touch.buttons:
			if b.get("el", "") == id and b.has("part"):
				name += " (%s)" % main.BondScript.PART_NAMES.get(b["part"], b["part"])
	return name


# --- the toolbar --------------------------------------------------------------------

## The toolbar's rect and its buttons: {"bar": Rect2, "title": Rect2, "buttons": [[id, Rect2, label]]}.
func toolbar() -> Dictionary:
	var view := _view()
	var w := minf(660.0 if menu_mode else 560.0, view.x - 16.0)
	var display := UI.font("display")
	var ids := ["save", "copy", "undo", "grid", "reset_one", "reset_all", "done"]
	if menu_mode:
		ids.insert(5, "reset_page")
	var labels := {}
	var widest := 0.0
	for id in ids:
		var label: String
		match id:
			"grid":
				label = TEXT["grid_on"] if grid else TEXT["grid_off"]
			"reset_one", "reset_all", "reset_page":
				label = TEXT["sure"] if armed == id else TEXT[id]
			_:
				label = TEXT[id]
		labels[id] = label
		widest = maxf(widest, display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0)
	# A narrow view (a phone at a big Interface size): the buttons in two rows.
	var gap := 4.0
	var per_row := ids.size()
	if (w - 12.0 - gap * (per_row - 1)) / per_row < widest:
		per_row = ceili(ids.size() / 2.0)
	var rows := ceili(float(ids.size()) / per_row)
	var h := 92.0 + (rows - 1) * 30.0
	var at := bar_at
	if at.x < 0.0:
		# (over a menu: at the bottom, out of the page's way)
		at = Vector2((view.x - w) * 0.5, view.y - h - 8.0 if menu_mode else view.y * 0.5 - h * 0.5)
	at.x = clampf(at.x, 0.0, maxf(view.x - w, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.y - h, 0.0))
	var bar := Rect2(at, Vector2(w, h))
	var title := Rect2(at, Vector2(w, 24.0))
	var out: Array = []
	var set_label: String = TEXT["switch"][Layout.active_set]
	var set_w := clampf(display.get_string_size(set_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, 130.0, w * 0.5)
	out.append(["set", Rect2(at + Vector2(w - set_w - 6.0, 3.0), Vector2(set_w, 19.0)), set_label])
	out.append(["help", Rect2(at + Vector2(w - set_w - 34.0, 3.0), Vector2(24.0, 19.0)), TEXT["help"]])
	if _menu_page != "" and not (_menu_page in ArrangeUI.SKIP_PAGES):
		# Over a menu: switch between arranging it and the HUD.
		var vl: String = TEXT["view_hud"] if menu_mode else TEXT["view_menu"]
		var vw := clampf(display.get_string_size(vl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, 110.0, w * 0.3)
		out.append(["view", Rect2(at + Vector2(w - set_w - 40.0 - vw, 3.0), Vector2(vw, 19.0)), vl])
	var bw := (w - 12.0 - gap * (per_row - 1)) / per_row
	for i in ids.size():
		var id: String = ids[i]
		var col := i % per_row
		var row := i / per_row
		out.append([id, Rect2(at + Vector2(6.0 + col * (bw + gap), 27.0 + row * 30.0), Vector2(bw, 26.0)), labels[id]])
	return {"bar": bar, "title": title, "buttons": out, "text_y": (rows - 1) * 30.0}


func _toolbar_button_at(pos: Vector2) -> String:
	for b in toolbar()["buttons"]:
		if b[1].has_point(pos):
			return b[0]
	return ""


## A toolbar button (or its key, or a controller button) was pressed.
func press(id: String) -> void:
	match id:
		"save":
			save()
		"copy":
			copy_layout()
		"undo":
			do_undo()
		"grid":
			grid = not grid
		"reset_one", "reset_all", "reset_page":
			if armed == id and Time.get_ticks_msec() <= armed_until:
				armed = ""
				_push_undo()
				if id == "reset_one" and sel != "":
					Layout.reset(sel)
					_say(TEXT["reset_one_done"] % label_of(sel))
				elif id == "reset_page":
					reset_page()
					_say(TEXT["reset_page_done"])
				elif id == "reset_all":
					Layout.reset_all()
					_say(TEXT["reset_all_done"])
				if menu_mode:
					_rebuild_menu.call_deferred()  # (a panel's width back: its rows unwrap)
			else:
				armed = id
				armed_until = Time.get_ticks_msec() + CONFIRM_MS
		"done":
			finish()
		"set":
			switch_set()
		"view":
			set_view(not menu_mode)
		"help":
			show_card(MENU_HELP if menu_mode else HELP)
	if main.has_method("sfx"):
		main.sfx("ui_confirm")
	_changed()


## Everything showing back in its default place (a menu's page, the rail, the car).
func reset_page() -> void:
	for id in elements():
		Layout.reset(id)
	if menu_mode:
		ArrangeUI.refresh(main.menu)


func save() -> void:
	var r := Layout.save()
	if not r["user"]:
		_say(TEXT["save_failed"])
	elif r["project"] == true:
		_say(TEXT["saved_project"])
	else:
		_say(TEXT["saved"])
	if is_open and not asking:
		_tell("arrange_save")


## Copy layout: the arrangement as JSON on the clipboard (on the web this
## must run from the press itself), and in a box to copy from by hand.
func copy_layout() -> void:
	copy_text = Layout.to_json()
	DisplayServer.clipboard_set(copy_text)
	_show_copy()
	_say(TEXT["copied"])
	if OS.has_feature("web"):
		# (a phone's browser can't long-press into the game's own text box:
		# show the words in a box of the page's own, over the game)
		var js := "(function(t){var d=document.getElementById('sixfold-layout');if(d)d.remove();d=document.createElement('div');d.id='sixfold-layout';" \
			+ "d.style.cssText='position:fixed;left:4%;top:6%;right:4%;bottom:6%;z-index:9999;background:#141020;border:1px solid #e2b55a;border-radius:8px;padding:10px;display:flex;flex-direction:column;gap:8px;font-family:sans-serif;color:#ece3cf';" \
			+ "var n=document.createElement('div');n.textContent=" + JSON.stringify(TEXT["copy_note"]) + ";" \
			+ "var a=document.createElement('textarea');a.value=t;a.readOnly=true;a.style.cssText='flex:1;width:100%;box-sizing:border-box;font:12px monospace;background:#0b0912;color:#ece3cf;border:1px solid #6a6080';" \
			+ "var b=document.createElement('button');b.textContent=" + JSON.stringify(TEXT["close"]) + ";b.style.cssText='padding:10px;font-size:16px';b.onclick=function(){d.remove()};" \
			+ "d.appendChild(n);d.appendChild(a);d.appendChild(b);document.body.appendChild(d);a.focus();a.select();})(" + JSON.stringify(copy_text) + ")"
		JavaScriptBridge.eval(js, true)


func do_undo() -> void:
	if undo.is_empty():
		_say(TEXT["nothing"])
		return
	Layout.restore(undo.pop_back())
	_say(TEXT["undone"])
	_changed()
	if menu_mode:
		_rebuild_menu.call_deferred()


## Edits the other layout set: on a computer, the phone's (drawn as the phone draws it).
func switch_set() -> void:
	if main.touch == null:
		return
	main.touch._set_active(not main.touch.active)
	get_tree().paused = true  # (still)
	if menu_mode:
		_rebuild_menu()  # (the menu as that layout draws it)
	var list := elements()
	if not (sel in list):
		sel = list[0] if not list.is_empty() else ""
	_tell("arrange_sets")


func _push_undo() -> void:
	undo.append(Layout.snapshot())
	if undo.size() > UNDO_MAX:
		undo.pop_front()


func _say(text: String) -> void:
	toast = text
	toast_until = Time.get_ticks_msec() + TOAST_MS
	queue_redraw()


# --- the copy box ------------------------------------------------------------------

func _copy_rect() -> Rect2:
	var view := _view()
	var w := minf(620.0, view.x - 24.0)
	var h := minf(360.0, view.y - 24.0)
	return Rect2((view - Vector2(w, h)) * 0.5, Vector2(w, h))


func _copy_close_rect() -> Rect2:
	var r := _copy_rect()
	return Rect2(r.end - Vector2(96.0, 34.0), Vector2(88.0, 26.0))


func _show_copy() -> void:
	copy_open = true
	if copy_box == null:
		copy_box = TextEdit.new()
		copy_box.editable = false
		copy_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		copy_box.add_theme_font_override("font", UI.font("mono"))
		copy_box.add_theme_font_size_override("font_size", 12)
		copy_box.add_theme_color_override("font_readonly_color", UI.TEXT)
		add_child(copy_box)
	var r := _copy_rect()
	copy_box.position = r.position + Vector2(10.0, 52.0)
	copy_box.size = r.size - Vector2(20.0, 52.0 + 44.0)
	copy_box.text = copy_text
	copy_box.visible = true
	copy_box.mouse_filter = Control.MOUSE_FILTER_STOP
	copy_box.select_all()
	copy_box.grab_focus()


func _hide_copy() -> void:
	copy_open = false
	if copy_box != null:
		copy_box.visible = false
		copy_box.release_focus()
	queue_redraw()


# --- the Entity's card ------------------------------------------------------------

## The first time something comes up (tips on, once per climber, as in
## play: guide.gd tell), the Entity explains it. True if it does.
func _tell(id: String) -> bool:
	if Guide.tell(id) == "":
		return false
	show_card([id])
	return true


## Shows the Entity's explanations, a page each.
func show_card(ids: Array) -> void:
	card = {"ids": ids, "i": 0}
	queue_redraw()


## Next page, or closed (and then whatever was waiting on it).
func card_next(close_now := false) -> void:
	if card.is_empty():
		return
	if not close_now and int(card["i"]) < card["ids"].size() - 1:
		card["i"] = int(card["i"]) + 1
		queue_redraw()
		return
	card = {}
	queue_redraw()
	var then := card_then
	card_then = ""
	if then == "finish":
		finish()


func _card_rect() -> Rect2:
	var view := _view()
	var w := minf(600.0, view.x - 16.0)
	var h := minf(330.0, view.y - 16.0)
	return Rect2((view - Vector2(w, h)) * 0.5, Vector2(w, h))


## [[id, rect, label]] for the card's buttons: Next (with pages left) and Close.
func _card_buttons() -> Array:
	var r := _card_rect()
	var out: Array = [["close", Rect2(r.end - Vector2(98.0, 36.0), Vector2(88.0, 26.0)), TEXT["close"]]]
	if not card.is_empty() and int(card["i"]) < card["ids"].size() - 1:
		out.push_front(["next", Rect2(r.end - Vector2(192.0, 36.0), Vector2(88.0, 26.0)), TEXT["next"]])
	return out


func _card_input(event: InputEvent) -> void:
	var pos = event.get("position")
	if pos != null and _pressed(event):
		for b in _card_buttons():
			if b[1].has_point(pos):
				card_next(b[0] == "close")
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			card_next(true)
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			card_next()
	elif event is InputEventJoypadButton and event.pressed and event.device == Controls.PAD_DEVICE:
		if event.button_index == JOY_BUTTON_A:
			card_next()
		elif event.button_index == JOY_BUTTON_B:
			card_next(true)


func _draw_card(body: Font, display: Font) -> void:
	var view := _view()
	var r := _card_rect()
	var id: String = card["ids"][int(card["i"])]
	var e := Entity.entry(id)
	var mode := "touch" if main.touch_active else ("pad" if main.pad_active else "keys")
	var tip := Entity.fill_keys(String(e.get("tip", "")), mode, main.pad_ps)
	var more := Entity.fill_keys(String(e.get("more", "")), mode, main.pad_ps)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.45))
	draw_style_box(UI.entity_bubble(), r)
	Entity.draw_face(self, r.position + Vector2(30, 32), 19.0, Time.get_ticks_msec() / 1000.0)
	var x := r.position.x + 58.0
	var tw := r.size.x - 58.0 - 14.0
	UI.draw_eyebrow(self, Vector2(x, r.position.y + 19.0), Entity.TEXT["tag"], Color(UI.PERIWINKLE, 0.9), 13)
	UI.draw_title(self, Vector2(x, r.position.y + 40.0), String(e.get("name", "")), 20, Color(0.9, 0.86, 1.0), HORIZONTAL_ALIGNMENT_LEFT, tw, 0.0)
	if card["ids"].size() > 1:
		draw_string(UI.font("mono"), Vector2(r.position.x, r.position.y + 19.0), TEXT["page"] % [int(card["i"]) + 1, card["ids"].size()], HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 14.0, 11, UI.FAINT)
	# The Entity's line, then the plain account under it, as big as fits.
	var top := r.position.y + 52.0
	var room := r.size.y - 52.0 - 46.0
	var fs := 15
	while fs > 9:
		var a1 := body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, tw, fs).y
		var a2 := body.get_multiline_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 2).y
		if a1 + 6.0 + a2 <= room:
			break
		fs -= 1
	draw_multiline_string(body, Vector2(x, top + fs), tip, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, -1, Entity.GLOW.lerp(Color.WHITE, 0.62))
	var h1 := body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, tw, fs).y
	draw_multiline_string(body, Vector2(x, top + h1 + 6.0 + fs - 2), more, HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 2, -1, UI.TEXT)
	for b in _card_buttons():
		_draw_button(b[1], b[2], b[0] == "close", display)


# --- input -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if not card.is_empty():
		# The Entity's card: Next, Close (Enter, Esc, A, B, a click or a tap).
		if event is InputEventJoypadMotion:
			return
		_card_input(event)
		if not (event is InputEventJoypadButton):
			get_viewport().set_input_as_handled()
		return
	# The controller: read, never kept back (pad.gd turns a real pad's
	# events into the standard ones this reads).
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.device == Controls.PAD_DEVICE:
			_pad_event(event)
		return
	var pos = event.get("position")
	if copy_open:
		# The box takes clicks and keys of its own (select, Ctrl+C); Close or Esc shuts it.
		var close_hit: bool = pos != null and _pressed(event) and _copy_close_rect().has_point(pos)
		if close_hit or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_hide_copy()
			get_viewport().set_input_as_handled()
			return
		if pos != null and copy_box != null and copy_box.get_global_rect().has_point(pos):
			return
		if event is InputEventKey:
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_down(-1, event.position, event.shift_pressed)
			else:
				pointer_up(-1)
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and sel != "" and not asking and (not menu_mode or ArrangeUI.has(sel)):
			_push_undo()
			nudge_scale(0.05 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.05)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if asking:
				asking = false
				queue_redraw()
			else:
				finish()
	elif event is InputEventMouseMotion:
		pointer_move(-1, event.position, event.shift_pressed)
		var h := _toolbar_button_at(event.position)
		if h != hover:
			hover = h
			queue_redraw()
		if menu_mode and drag.is_empty():
			# Over a menu: the element under the mouse lights up with its name.
			var he := "" if toolbar()["bar"].has_point(event.position) else element_at(event.position)
			if he != hover_el:
				hover_el = he
				queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			pointer_down(event.index, event.position, false)
		else:
			pointer_up(event.index)
	elif event is InputEventScreenDrag:
		pointer_move(event.index, event.position, false)
	elif event is InputEventKey and event.pressed:
		_key(event)
	get_viewport().set_input_as_handled()


func _pressed(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)


func _key(event: InputEventKey) -> void:
	var k := event.keycode
	if asking:
		match k:
			KEY_LEFT, KEY_UP:
				ask_focus = (ask_focus + 2) % 3
			KEY_RIGHT, KEY_DOWN, KEY_TAB:
				ask_focus = (ask_focus + 1) % 3
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				answer(["save", "discard", "stay"][ask_focus])
			KEY_ESCAPE:
				answer("stay")
		queue_redraw()
		return
	if event.ctrl_pressed or event.meta_pressed:
		if k == KEY_Z:
			do_undo()
		elif k == KEY_S:
			save()
		elif k == KEY_C:
			copy_layout()
		return
	match k:
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_F2:
			finish()
		KEY_TAB:
			pick(-1 if event.shift_pressed else 1)
		KEY_G:
			press("grid")
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if sel != "":
				var step := 1.0 if event.shift_pressed else GRID
				var d := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[k] as Vector2
				if not event.echo:
					_push_undo()
				var r := screen_rect(sel)
				_apply(sel, Rect2(r.position + d * step, r.size))
		KEY_BRACKETLEFT, KEY_MINUS:
			if sel != "":
				_push_undo()
				nudge_scale(-0.05)
		KEY_BRACKETRIGHT, KEY_EQUAL, KEY_PLUS:
			if sel != "":
				_push_undo()
				nudge_scale(0.05)
		KEY_DELETE, KEY_BACKSPACE:
			press("reset_one")
		KEY_PAGEUP:
			pick_nested(1)
		KEY_PAGEDOWN:
			pick_nested(-1)


func _pad_event(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		axes[event.axis] = event.axis_value
		return
	if not event.pressed:
		return
	var b: int = event.button_index
	if asking:
		match b:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP:
				ask_focus = (ask_focus + 2) % 3
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN:
				ask_focus = (ask_focus + 1) % 3
			JOY_BUTTON_A:
				answer(["save", "discard", "stay"][ask_focus])
			JOY_BUTTON_B:
				answer("stay")
		queue_redraw()
		return
	if copy_open:
		if b == JOY_BUTTON_A or b == JOY_BUTTON_B:
			_hide_copy()
		return
	match b:
		JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_RIGHT_SHOULDER:
			pick(1)
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_LEFT_SHOULDER:
			pick(-1)
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START:
			finish()
		JOY_BUTTON_X:
			do_undo()
		JOY_BUTTON_Y:
			save()
		JOY_BUTTON_BACK:
			press("grid")


## The next (or previous) element.
func pick(by: int) -> void:
	var list := elements()
	if list.is_empty():
		return
	var i := list.find(sel)
	sel = list[(i + by + list.size()) % list.size()] if i >= 0 else list[0]
	if main.has_method("sfx"):
		main.sfx("ui_move")
	queue_redraw()


## "Save your changes?": save, discard (back to the last save) or stay.
func answer(what: String) -> void:
	match what:
		"save":
			save()
			asking = false
			close()
		"discard":
			Layout.revert()
			asking = false
			close()
		_:
			asking = false
			queue_redraw()


func _ask_buttons() -> Array:
	var view := _view()
	var w := minf(420.0, view.x - 24.0)
	var panel := Rect2((view.x - w) * 0.5, view.y * 0.5 - 60.0, w, 120.0)
	var bw := (w - 32.0) / 3.0
	var out: Array = []
	for i in 3:
		out.append([["save", "discard", "stay"][i], Rect2(panel.position + Vector2(10.0 + i * (bw + 6.0), 76.0), Vector2(bw, 30.0)), TEXT[["ask_save", "ask_discard", "ask_stay"][i]]])
	return [panel, out]


## A press (mouse button or finger) at a point.
func pointer_down(ptr: int, pos: Vector2, free := false) -> void:
	if not drag.is_empty():
		return  # (one thing at a time)
	if asking:
		for b in _ask_buttons()[1]:
			if b[1].has_point(pos):
				answer(b[0])
				return
		return
	var tb := toolbar()
	var hit := _toolbar_button_at(pos)
	if hit != "":
		press(hit)
		return
	if tb["title"].has_point(pos) or tb["bar"].has_point(pos):
		drag = {"kind": "bar", "ptr": ptr, "from": pos, "at": tb["bar"].position}
		return
	# A corner handle of the chosen element: scale; a side handle: resize.
	if sel != "":
		var r := screen_rect(sel)
		var grab := GRAB_TOUCH if ptr >= 0 else GRAB
		if _corner_handles(sel):
			var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for ci in 4:
				if pos.distance_to(corners[ci]) <= grab:
					_push_undo()
					drag = {"kind": "scale", "ptr": ptr, "from": pos, "rect": r, "corner": ci, "scale": r.size.x / maxf(_default_size(sel).x, 0.001)}
					queue_redraw()
					return
		for sh in side_handles(sel):
			if pos.distance_to(sh[1]) <= grab:
				_push_undo()
				drag = {"kind": "resize", "ptr": ptr, "from": pos, "rect": r, "side": sh[0]}
				queue_redraw()
				return
	# What's under it: the smallest thing; pressed again where the chosen
	# one is, it stays chosen (to drag it) and, if it isn't dragged, the
	# bigger thing around it is chosen.
	var hits := elements_at(pos)
	if not hits.is_empty():
		var again: bool = sel in hits
		var id: String = sel if again else hits[0]
		sel = id
		_push_undo()
		drag = {"kind": "move", "ptr": ptr, "from": pos, "rect": screen_rect(id), "moved": false, "again": again, "hits": hits}
	queue_redraw()


## Whether the chosen element has corner handles (it scales with its box).
func _corner_handles(id: String) -> bool:
	return not is_live(id) or (ArrangeUI.cap(id, "scale") and not ArrangeUI.cap(id, "inside"))


## The side handles of an element that can be resized: [side, point].
func side_handles(id: String) -> Array:
	if not is_live(id):
		return []
	var r := screen_rect(id)
	var out: Array = []
	if ArrangeUI.cap(id, "x"):
		out.append(["right", Vector2(r.end.x, r.get_center().y)])
		if r.position.x > 1.0:
			out.append(["left", Vector2(r.position.x, r.get_center().y)])
	if ArrangeUI.cap(id, "y"):
		out.append(["bottom", Vector2(r.get_center().x, r.end.y)])
		if r.position.y > 1.0:
			out.append(["top", Vector2(r.get_center().x, r.position.y)])
	return out


func pointer_move(ptr: int, pos: Vector2, free := false) -> void:
	if drag.is_empty() or drag["ptr"] != ptr:
		return
	var d: Vector2 = pos - drag["from"]
	free = free or Input.is_key_pressed(KEY_SHIFT)
	match drag["kind"]:
		"bar":
			bar_at = drag["at"] + d
			queue_redraw()
		"move":
			var r: Rect2 = drag["rect"]
			r.position += d
			if not free:
				r = snap(r, sel)
			else:
				guides.clear()
			drag["moved"] = true
			_apply(sel, r)
		"scale":
			_scale_drag(pos, free)
		"resize":
			_resize_drag(pos, free)


func pointer_up(ptr: int) -> void:
	if drag.is_empty() or drag["ptr"] != ptr:
		return
	var kind: String = drag["kind"]
	if kind == "move" and not drag.get("moved", false):
		if not undo.is_empty():
			undo.pop_back()  # (a tap that only chose it changed nothing)
		if drag.get("again", false):
			# Pressed again where the chosen one is: the bigger thing around it
			# (and from the biggest, back to the smallest).
			var hits: Array = drag["hits"]
			var i := hits.find(sel)
			if hits.size() > 1 and i >= 0:
				sel = hits[(i + 1) % hits.size()]
				if main.has_method("sfx"):
					main.sfx("ui_move")
	drag = {}
	guides.clear()
	queue_redraw()
	if kind == "resize" and menu_mode:
		_rebuild_menu.call_deferred()  # (narrower or wider: the page's rows wrap again to fit)


## Pulling a side handle: the element is resized (the page's panel and the
## rail across, the rail's list down), the other side staying put.
func _resize_drag(pos: Vector2, free: bool) -> void:
	var r: Rect2 = drag["rect"]
	var side: String = drag["side"]
	var s := ArrangeUI.scale_of(sel)
	if ArrangeUI.cap(sel, "inside"):
		s = 1.0
	var px := 0.0
	match side:
		"right":
			px = pos.x - r.position.x
		"left":
			px = r.end.x - pos.x
		"bottom":
			px = pos.y - r.position.y
		"top":
			px = r.end.y - pos.y
	if not free and grid:
		px = roundf(px / GRID) * GRID
	ArrangeUI.resize_to(sel, "w" if side in ["left", "right"] else "h", maxf(px, 8.0) / maxf(s, 0.01))
	_changed()


## Pulling a corner: the opposite corner stays put and the element keeps its shape.
func _scale_drag(pos: Vector2, free: bool) -> void:
	var r: Rect2 = drag["rect"]
	var ci: int = drag["corner"]
	var right := ci == 1 or ci == 2
	var down := ci == 2 or ci == 3
	var fixed := Vector2(r.position.x if right else r.end.x, r.position.y if down else r.end.y)
	var d := pos - fixed
	var f := maxf((d.x if right else -d.x) / maxf(r.size.x, 1.0), (d.y if down else -d.y) / maxf(r.size.y, 1.0))
	var s0: float = drag["scale"]
	var s := s0 * f
	if not free:
		s = snappedf(s, 0.05)
	s = clampf(s, _min_scale(sel), Layout.MAX_SCALE)
	var size := r.size / maxf(s0, 0.001) * s
	var at := Vector2(fixed.x if right else fixed.x - size.x, fixed.y if down else fixed.y - size.y)
	_apply(sel, Rect2(at, size))


func _min_scale(id: String) -> float:
	if is_live(id):
		return Layout.MIN_SCALE
	return Layout.min_scale(id, Layout.space_size(id, _view(), _hs()))


## Grows or shrinks the chosen element by this much of its default size, about its centre.
func nudge_scale(by: float) -> void:
	if is_live(sel):
		ArrangeUI.nudge_scale(sel, by)
		_changed()
		return
	var r := screen_rect(sel)
	var base := _default_size(sel)
	var s := clampf(snappedf(r.size.x / maxf(base.x, 0.001) + by, 0.05), _min_scale(sel), Layout.MAX_SCALE)
	var size := base * s
	_apply(sel, Rect2(r.get_center() - size * 0.5, size))


## Let go of the stick: onto the grid (and a tidy scale).
func _settle(id: String) -> void:
	if is_live(id):
		if grid:
			_apply(id, snap(screen_rect(id), id))
			guides.clear()
		return
	var r := screen_rect(id)
	var base := _default_size(id)
	var s := clampf(snappedf(r.size.x / maxf(base.x, 0.001), 0.05), _min_scale(id), Layout.MAX_SCALE)
	var size := base * s
	r = Rect2(r.get_center() - size * 0.5, size)
	if grid:
		r = snap(r, id)
		guides.clear()
	_apply(id, r)


## Snaps a rect: an edge or centre near a screen edge, the centre lines or
## another element's edge sticks there (and shows a guide); otherwise, with
## the grid on, its corner goes onto the grid.
func snap(r: Rect2, id: String) -> Rect2:
	guides.clear()
	var view := _view()
	var near := SNAP_TOUCH if main.touch_active else SNAP
	var xs: Array = [0.0, view.x * 0.5, view.x]
	var ys: Array = [0.0, view.y * 0.5, view.y]
	for o in elements():
		if o == id:
			continue
		var orr := screen_rect(o)
		if menu_mode:
			if ArrangeUI.is_inside(id, o):
				continue  # (what's in it moves with it)
		elif orr.size.x >= view.x * 0.45 or orr.size.y >= view.y * 0.8:
			continue  # (the big zones would catch everything)
		xs.append_array([orr.position.x, orr.end.x])
		ys.append_array([orr.position.y, orr.end.y])
	var dx := _best(xs, [r.position.x, r.get_center().x, r.end.x], near)
	var dy := _best(ys, [r.position.y, r.get_center().y, r.end.y], near)
	if dx[0] != null:
		r.position.x += dx[0]
		guides.append(["x", dx[1]])
	elif grid:
		r.position.x = roundf(r.position.x / GRID) * GRID
	if dy[0] != null:
		r.position.y += dy[0]
		guides.append(["y", dy[1]])
	elif grid:
		r.position.y = roundf(r.position.y / GRID) * GRID
	return r


## The smallest shift (within reach) that puts one of these edges on one of
## these lines: [shift or null, the line].
func _best(lines: Array, edges: Array, reach: float) -> Array:
	var best = null
	var at := 0.0
	for l in lines:
		for e in edges:
			var d: float = l - e
			if absf(d) <= reach and (best == null or absf(d) < absf(best)):
				best = d
				at = l
	return [best, at]


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	redraws += 1
	if not is_open:
		return
	var view := _view()
	var body := UI.font("body")
	var mono := UI.font("mono")
	var display := UI.font("display")
	# The grid, faint (every 8 px, stronger every 64).
	if grid:
		var fine := PackedVector2Array()
		var bold := PackedVector2Array()
		var x := 0.0
		while x <= view.x:
			if int(x) % 64 == 0:
				bold.append_array([Vector2(x, 0), Vector2(x, view.y)])
			else:
				fine.append_array([Vector2(x, 0), Vector2(x, view.y)])
			x += GRID
		var y := 0.0
		while y <= view.y:
			if int(y) % 64 == 0:
				bold.append_array([Vector2(0, y), Vector2(view.x, y)])
			else:
				fine.append_array([Vector2(0, y), Vector2(view.x, y)])
			y += GRID
		draw_multiline(fine, Color(UI.GILT, 0.05))
		draw_multiline(bold, Color(UI.GILT, 0.11))
		draw_line(Vector2(view.x * 0.5, 0), Vector2(view.x * 0.5, view.y), Color(UI.PERIWINKLE, 0.12))
		draw_line(Vector2(0, view.y * 0.5), Vector2(view.x, view.y * 0.5), Color(UI.PERIWINKLE, 0.12))
	# Each element: a dashed gilt outline and its name (the chosen one solid,
	# with handles). Over a menu, only the one under the mouse and the chosen one.
	if menu_mode:
		if hover_el != "" and hover_el != sel and ArrangeUI.has(hover_el):
			_draw_element(hover_el, false, body)
	else:
		for id in Layout.ids():
			if id == sel:
				continue
			_draw_element(id, false, body)
	if sel != "" and (not menu_mode or ArrangeUI.has(sel)):
		_draw_element(sel, true, body)
	# The guides of a drag.
	for g in guides:
		if g[0] == "x":
			draw_line(Vector2(g[1], 0), Vector2(g[1], view.y), Color(UI.PERIWINKLE, 0.85), 1.0)
		else:
			draw_line(Vector2(0, g[1]), Vector2(view.x, g[1]), Color(UI.PERIWINKLE, 0.85), 1.0)
	_draw_toolbar(body, mono, display)
	if toast != "":
		var tw := minf(body.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0, view.x - 16.0)
		var tb := toolbar()["bar"] as Rect2
		var ty := tb.end.y + 6.0 if tb.end.y + 36.0 < view.y else tb.position.y - 34.0
		var tr := Rect2(Vector2((view.x - tw) * 0.5, ty), Vector2(tw, 28.0))
		draw_rect(tr, Color(UI.VOID, 0.92))
		draw_rect(tr, Color(UI.GILT, 0.6), false, 1.0)
		draw_string(body, Vector2(tr.position.x, tr.position.y + 19.0), toast, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 14, UI.GILT_HI)
	if copy_open:
		var cr := _copy_rect()
		draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.5))
		draw_style_box(UI.panel(), cr)
		draw_rect(cr, Color(UI.GILT, 0.5), false, 1.0)
		UI.draw_label(self, cr.position + Vector2(12, 24), TEXT["copy_title"], 19, UI.GOLD)
		draw_string(body, cr.position + Vector2(12, 44), TEXT["copy_note"], HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 24.0, 12, UI.DIM)
		_draw_button(_copy_close_rect(), TEXT["close"], true, display)
	if asking:
		var ab := _ask_buttons()
		var pr: Rect2 = ab[0]
		draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.45))
		draw_style_box(UI.panel(), pr)
		draw_rect(pr, Color(UI.GILT, 0.6), false, 1.0)
		UI.draw_label(self, Vector2(pr.position.x, pr.position.y + 30.0), TEXT["ask"], 21, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		draw_string(body, Vector2(pr.position.x + 10.0, pr.position.y + 54.0), TEXT["ask_note"], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x - 20.0, 12, UI.DIM)
		for i in ab[1].size():
			var b: Array = ab[1][i]
			_draw_button(b[1], b[2], i == 0, display, i == ask_focus and not main.touch_active)
	if not card.is_empty():
		_draw_card(body, display)


func _draw_element(id: String, chosen: bool, font: Font) -> void:
	var r := screen_rect(id)
	var on := showing(id)
	var a := 1.0 if chosen else (0.7 if on else 0.35)
	var col := Color(UI.GILT_HI if chosen else UI.GILT, a)
	if chosen:
		draw_rect(r, Color(UI.GILT, 0.1))
		draw_rect(r, col, false, 2.0)
	else:
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(pts[i], pts[(i + 1) % 4], col, 1.0, 5.0)
	var name := label_of(id)
	var big := r.size.x > _view().x * 0.45 or r.size.y > _view().y * 0.8
	# The name: just above the box, or inside it when there's no room (a big
	# zone names itself at its bottom left).
	var at := r.position + Vector2(3.0, -4.0)
	if big:
		at = Vector2(r.position.x + 8.0, r.end.y - 8.0)
	elif at.y < 12.0:
		at.y = r.position.y + 13.0
	var size := 12 if chosen else 11
	# (on a dark chip, so names stay readable where the HUD crowds together)
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(at + Vector2(-3.0, -size + 1.0), Vector2(nw + 6.0, size + 3.0)), Color(UI.VOID, 0.72 * a))
	draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if chosen:
		if _corner_handles(id):
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				var h := Rect2(c - Vector2(HANDLE, HANDLE) * 0.5, Vector2(HANDLE, HANDLE))
				draw_rect(h.grow(1.0), Color(0, 0, 0, 0.8))
				draw_rect(h, UI.GILT_HI)
		# Side handles (resizing): bars across the edge's middle.
		for sh in side_handles(id):
			var across: bool = sh[0] in ["left", "right"]
			var hs := Vector2(HANDLE * 0.75, HANDLE * 2.2) if across else Vector2(HANDLE * 2.2, HANDLE * 0.75)
			var h := Rect2(sh[1] - hs * 0.5, hs)
			draw_rect(h.grow(1.0), Color(0, 0, 0, 0.8))
			draw_rect(h, UI.PERIWINKLE)


func _draw_button(r: Rect2, label: String, primary: bool, font: Font, focused := false) -> void:
	draw_style_box(UI.primary_box() if primary else UI.button_box("hover" if focused else "normal"), r)
	if focused:
		draw_rect(r.grow(2.0), Color(UI.GILT_HI, 0.9), false, 1.5)
	var fs := UI.fit_size(font, label, 14, r.size.x - 8.0)
	draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UI.GILT_HI if primary else UI.TEXT)


func _draw_toolbar(body: Font, mono: Font, display: Font) -> void:
	var tb := toolbar()
	var bar: Rect2 = tb["bar"]
	draw_style_box(UI.panel(), bar)
	draw_rect(bar, Color(UI.GILT, 0.55), false, 1.0)
	# The title bar (its grip: a few dots), and which layout is being edited.
	var title: Rect2 = tb["title"]
	draw_rect(title, Color(UI.GILT, 0.08))
	for i in 3:
		draw_circle(title.position + Vector2(10.0, 8.0 + i * 4.5), 1.2, Color(UI.GILT, 0.6))
		draw_circle(title.position + Vector2(14.0, 8.0 + i * 4.5), 1.2, Color(UI.GILT, 0.6))
	var title_text: String = TEXT["title"] + "  ·  " + TEXT["editing"] % TEXT["set_names"][Layout.active_set]
	var room := title.size.x
	for b in tb["buttons"]:
		if (b[1] as Rect2).position.y < title.end.y:
			room = minf(room, (b[1] as Rect2).position.x - title.position.x - 26.0)
	if display.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > room:
		title_text = TEXT["title"]  # (a narrow toolbar: the buttons beside it need the room)
	UI.draw_label(self, title.position + Vector2(22.0, 17.0), title_text, 15, UI.GOLD)
	for b in tb["buttons"]:
		var primary: bool = b[0] == "done" or (b[0] == "save" and Layout.dirty())
		var armed_now: bool = b[0] == armed
		_draw_button(b[1], b[2], primary or armed_now, display, b[0] == hover)
	# The readout of the chosen element, then how to work it.
	var line: String = TEXT["none"]
	if sel != "":
		var r := screen_rect(sel)
		var ov = Layout.get_override(sel)
		var scale := r.size.x / maxf(_default_size(sel).x, 0.001)
		var anchor: String = TEXT["pinned"] % Layout.ANCHOR_NAMES.get(String(ov.get("anchor", "")), "") if ov != null else TEXT["as_built"]
		if is_live(sel):
			scale = ArrangeUI.scale_of(sel)
			anchor = TEXT["moved"] if ArrangeUI.override(sel) != null else TEXT["as_built"]
		line = TEXT["readout"] % [label_of(sel), int(round(r.position.x)), int(round(r.position.y)), int(round(r.size.x)), int(round(r.size.y)), int(round(scale * 100.0)), anchor]
	var ty: float = tb.get("text_y", 0.0)
	draw_string(mono, Vector2(bar.position.x + 8.0, bar.position.y + 70.0 + ty), line, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 16.0, 11, UI.TEXT)
	var hint: String = TEXT["hint_touch"] if main.touch_active else (Controls.pad_text(TEXT["hint_pad"], main.pad_ps) if main.pad_active else (TEXT["hint_menu"] if menu_mode else TEXT["hint_keys"]))
	draw_string(body, Vector2(bar.position.x + 8.0, bar.position.y + 86.0 + ty), hint, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 16.0, 11, UI.DIM)
