extends Control
## Arrange mode: move and resize the things on screen yourself, a few big
## blocks at a time.
##
## Opened with F2 (in play: the HUD; with a menu open: that menu) or from
## Dev tools. The game pauses. What's on screen is shown as BLOCKS, one level
## at a time, so outlines never pile up:
##   - At first only the big pieces show: a menu's page and the left rail,
##     each piece of furniture in a train car, the HUD's groups. Each has one
##     clean outline with its number and name.
##   - "Go inside" a block (double-click it, Enter, the toolbar's button or
##     the > on its row) shows only the parts directly inside it; "Back out"
##     (Esc, Backspace, the button) goes up again. A breadcrumb such as
##     "Inventory > Inventory page > Right side" says where you are.
##   - The LIST (a panel at the side) names the blocks of the level showing.
##     Click a row to choose its block; pointing at a row lights the block up.
##     A dot marks a block that was moved, and the round arrow puts it back.
##   - The chosen block has big handles: drag its body to move it, a corner
##     to make it bigger or smaller, and (where it can be made wider or
##     taller) a blue bar on its side. The list says how far it has moved
##     and its size in plain numbers. It snaps to an 8 px grid, the screen's
##     edges and centre lines and its neighbours' edges, with guide lines
##     showing; hold Shift to place it freely. The arrow keys nudge it.
##   - Blocks that came to overlap are flagged in red ("Overlaps Marks").
##   - The toolbar (drag it by its title): Back out, Go inside, Undo, Redo,
##     Reset this, Reset page (over a menu), Reset all, Grid, List, Copy
##     layout, Save, Done; which layout is being edited (computer or phone),
##     and a line saying where you are and what's chosen.
##   - Keys: Tab / Shift+Tab pick the next block, the arrows nudge it (8 px,
##     1 px with Shift), [ and ] (or the wheel over it) scale it, Enter goes
##     inside, Esc backs out (at the top level it finishes), Ctrl+Z undoes,
##     Ctrl+Y redoes, Ctrl+S saves, G is the grid, L the list, F2 finishes.
##   - Controller: the d-pad or LB / RB pick the next block, A goes inside,
##     B backs out, the left stick moves it, the right stick scales it, X
##     undoes, Y saves, View is the grid, and Start finishes.
## Finishing with unsaved changes asks whether to save them. The Entity
## explains it all (entity.gd's creator tips "arrange", "arrange_sets",
## "arrange_save" and "arrange_menus") in a card of this screen's own, the
## first time each comes up (tips on, as in play), then leaves its three
## steps (pick a block, drag it, Save) at the top of the list until they're
## done; the toolbar's ? shows them again. The words are in TEXT.
##
## What the blocks are: over a menu, the page's panel, the rail and the
## train's furniture, and what's inside each (arrange_ui.gd tags them as a
## page is built and says what sits in what); in play, the HUD's and the
## phone's elements (layout.gd), in the groups layout.gd GROUPS gives. A
## group isn't saved: moving it moves each of its parts.

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
	"save": "Save", "copy": "Copy layout", "undo": "Undo", "redo": "Redo", "grid_on": "Grid: on", "grid_off": "Grid: off",
	"list_on": "List: on", "list_off": "List: off", "back": "Back out", "inside": "Go inside",
	"reset_one": "Reset this", "reset_page": "Reset page", "reset_all": "Reset all", "sure": "Sure?", "done": "Done",
	"view_menu": "Arrange the menu", "view_hud": "Arrange the HUD",
	"none": "Nothing chosen: click a block, or a row of the list",
	# The breadcrumb: the screen's own name, then each block stepped into.
	"top_hud": "The HUD", "top_touch": "The HUD and buttons", "top_train": "Train: %s", "crumb": "  ›  ", "more": "…",
	# The list.
	"blocks": "Blocks", "count": "%d here", "empty": "Nothing here to arrange",
	"moved": "Moved %s", "right": "%d right", "left": "%d left", "down": "%d down", "up": "%d up", "and": ", ",
	"not_moved": "In its built-in place",
	"size": "Size %d%%", "wide": "width %d%%", "tall": "height %d%%", "dot": "  ·  ",
	"overlaps": "Overlaps %s",
	"inside_n": "%d parts inside: double-click it to go in", "inside_1": "1 part inside: double-click it to go in",
	"inside_moved": "Something inside it was moved",
	"hidden": "Not on screen just now: outlined where it shows",
	"zone": "It fills the screen, so its outline only shows while it's chosen",
	"cant_move": "It can't be dragged from its place",
	"nothing_inside": "%s has nothing inside to arrange",
	"at_top": "This is the top level",
	"entered": "Inside %s",
	"hint_short": "Drag a block to move it · corners: size · double-click: go inside · Esc: back out",
	"hint_keys": "Drag a block to move it · corners: size · double-click or Enter: go inside · Esc: back out · arrows: nudge · Shift: no snapping",
	"hint_pad": "D-pad or {lb} {rb}: next · {a}: go inside · {b}: back out · left stick: move · right stick: size · {x}: undo · {y}: save · {start}: done",
	"hint_touch": "Tap a block, drag it to move it · pull a corner to size it · double-tap: go inside · drag this bar to move the toolbar",
	"step": "Step %d of %d: %s",
	"intro_done": "That's all there is to it",
	"saved": "Saved",
	"saved_project": "Saved, and to data/layout.json: commit it in GitHub Desktop to share it",
	"save_failed": "Couldn't save the layout",
	"copied": "Layout copied to the clipboard",
	"copy_title": "Your layout",
	"copy_note": "It's on the clipboard. On a phone: long-press in the box, Select all, then Copy, and paste it to Claude.",
	"close": "Close",
	"reset_one_done": "%s is back in its default place (Undo brings it back)",
	"reset_none": "%s is already in its default place",
	"reset_page_done": "Everything showing is back in its default place",
	"reset_all_done": "Everything is back in its default place",
	"undone": "Undone", "nothing": "Nothing to undo", "redone": "Redone", "nothing_redo": "Nothing to redo",
	"ask": "Save your changes?",
	"ask_note": "They're used now either way; unsaved, they're gone after a restart.",
	"ask_save": "Save", "ask_discard": "Don't save", "ask_stay": "Keep arranging",
	"help": "?", "next": "Next", "page": "%d of %d",
}

## Snapping: the grid's step, and how close (px) an edge must come to a line to stick.
const GRID := 8.0
const SNAP := 6.0
const SNAP_TOUCH := 9.0
## The chosen block's handles: drawn this big, grabbed from this far (a finger: farther).
const HANDLE := 13.0
const GRAB := 14.0
const GRAB_TOUCH := 22.0
## The controller: the left stick moves this many px a second, the right
## stick scales this much a second, past this deadzone.
const STICK_SPEED := 260.0
const STICK_SCALE := 0.9
const STICK_DEAD := 0.2
## How long a Reset waits for its second press (ms), and a notice stays.
const CONFIRM_MS := 3000
const TOAST_MS := 3500
const UNDO_MAX := 60
## Two presses this close together (ms, and px) are a double-click.
const DOUBLE_MS := 450
const DOUBLE_PX := 14.0
## The list: a row's height (a finger's: taller), and the smallest view it
## opens on by itself (smaller: the toolbar's List button shows it).
const ROW_H := 26.0
const ROW_TOUCH := 30.0
const LIST_MIN := Vector2(700, 400)
## Over a menu with the rail showing, the list and the toolbar stand in a
## column this wide over the rail (on a view at least COL_MIN), so the page
## stays clear.
const COL_W := 272.0
const COL_MIN := Vector2(900, 600)

var main
var is_open := false
var sel := ""  # the chosen block
var path: Array = []  # the blocks stepped into, outermost first ([]: the top level)
var grid := true
var drag := {}  # {kind: move / scale / resize / bar / list, ptr: -1 mouse or touch index, from, rect, corner, scale}
var guides: Array = []  # [axis "x" or "y", where] while dragging
var undo: Array = []
var redo: Array = []
var toast := ""
var toast_until := 0
var armed := ""  # a Reset waiting for its second press
var armed_until := 0
var asking := false  # "Save your changes?"
var ask_focus := 0
var bar_at := Vector2(-1, -1)  # the toolbar's top left (-1: centred)
var list_at := Vector2(-1, -1)  # the list's top left (-1: at the side)
var list_user := -1  # the list: -1 by the view's size, 0 hidden, 1 shown
var list_scroll := 0.0
var copy_open := false
var copy_text := ""
var copy_box: TextEdit
var axes := {}  # the controller's sticks (PAD_DEVICE axis -> value)
var stick_moving := false
var hover := ""  # the toolbar button under the mouse
var hover_row := ""  # the part of the list under the mouse ("row:<id>", "reset:<id>", "enter:<id>", "back")
var card := {}  # the Entity's card: {ids, i}
var card_then := ""  # what to do once it's closed ("finish")
var intro := -1  # the Entity's three steps: the one to do next (-1: not showing)
var redraws := 0  # (tests)
var menu_mode := false  # arranging the menu showing (not the HUD)
var hover_el := ""  # the block under the mouse, or of the list's row under it (lit up)

var _menu_page := ""  # the menu page it was opened from (reopened on Done)
var _was_paused := false
var _was_touch := false
var _hud_kept: Array = []
var _closed_frame := -1
var _tree := {}  # the blocks as a tree (tree())
var _tree_key: Array = []
var _last_tap: Array = ["", 0, Vector2.ZERO]  # what the last press that didn't drag was on, when and where
var _shown := {}  # showing()'s answers, until something changes


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
	# The controller's sticks: move and scale the chosen block.
	if _exists(sel) and not asking and not copy_open:
		var dt := Nav.real_delta(delta)
		var lv := Vector2(float(axes.get(JOY_AXIS_LEFT_X, 0.0)), float(axes.get(JOY_AXIS_LEFT_Y, 0.0)))
		var rv := float(axes.get(JOY_AXIS_RIGHT_Y, 0.0))
		var push := lv.length() > STICK_DEAD or absf(rv) > STICK_DEAD
		if push and not stick_moving:
			stick_moving = true
			_push_undo()
		if lv.length() > STICK_DEAD and can_move(sel):
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
	"note": "Arrange layout moves and scales the HUD and the touch buttons (F2 in play); Arrange menus does the same for this page, and F2 with any menu open (or on the train) for that one. It shows a few big blocks at a time, with a list of them at the side: pick one, drag it, and Go inside it for its parts. Save keeps it; run from the Godot editor, Save also writes data/layout.json for GitHub Desktop.",
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
	hover_row = ""
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
	redo.clear()
	drag = {}
	guides.clear()
	asking = false
	armed = ""
	axes.clear()
	stick_moving = false
	_last_tap = ["", 0, Vector2.ZERO]
	if menu_mode:
		ArrangeUI.tag_page(m)  # (what's on the page now)
		get_viewport().gui_release_focus()  # (a controller's d-pad picks things here, not the page's buttons)
	_to_top()
	visible = true
	if main.has_method("sfx"):
		main.sfx("ui_open")
	card = {}
	intro = -1
	var first: Array = []
	for id in (["arrange", "arrange_menus"] if menu_mode else ["arrange"]):
		if Guide.tell(id) != "":
			first.append(id)
	if not first.is_empty():
		show_card(first)
		if "arrange" in first:
			intro = 0  # (the three steps stay in the list until they're done)
	_changed()


## Every element that can be arranged now, whatever level it's on: the
## menu's (arrange_ui.gd), or the HUD's.
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
	hover_row = ""
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
	_to_top()
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
	_tree = {}
	_sync()
	if not _exists(sel):
		var list := level_blocks()
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
	intro = -1
	path = []
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
	hover_row = ""
	_changed()
	menu_mode = false
	_tree = {}


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


# --- the blocks, a level at a time ---------------------------------------------------

## The blocks on screen as a tree: {id: {"up": the block it's in ("" for the
## screen itself), "kids": [the blocks directly inside it]}}, with "" the
## screen. Over a menu: what arrange_ui.gd tagged, each in the nearest tagged
## thing around it (a row that only holds columns is skipped: its columns
## stand in the page). In play: layout.gd's elements, in its GROUPS.
func tree() -> Dictionary:
	var key := [menu_mode, Layout.active_set, Layout.version, Engine.get_process_frames()]
	if not _tree.is_empty() and key == _tree_key:
		return _tree
	var t := {"": {"up": "", "kids": []}}
	if main == null:
		return t
	if menu_mode and main.menu != null:
		var ids: Array = ArrangeUI.ids_on_screen(main.menu).filter(func(id): return ArrangeUI.offered(id))
		var among := {}
		for id in ids:
			among[id] = true
		var up := {}
		for id in ids:
			up[id] = ArrangeUI.parent_of(id, among)
		var skip := {}
		for id in ids:
			if ArrangeUI.kind_of(id) == "row" and ArrangeUI.override(id) == null:
				var cols: Array = ids.filter(func(k): return up[k] == id)
				if cols.size() >= 2 and cols.all(func(k): return ArrangeUI.kind_of(k) == "column"):
					skip[id] = true
		for id in ids:
			if skip.has(id):
				continue
			var p: String = up[id]
			while skip.has(p):
				p = up[p]
			t[id] = {"up": p, "kids": []}
		for id in ids:
			if t.has(id):
				t[t[id]["up"]]["kids"].append(id)
		# (the page first, the rail after it)
		var top: Array = t[""]["kids"]
		if top.has("rail.box") and top.size() > 1:
			top.erase("rail.box")
			top.append("rail.box")
	else:
		for id in Layout.ids():
			var g := Layout.group_of(id)
			if g != "" and not t.has(g):
				t[g] = {"up": "", "kids": []}
				t[""]["kids"].append(g)
			t[id] = {"up": g, "kids": []}
			t[g]["kids"].append(id)
	_tree = t
	_tree_key = key
	return t


## The blocks directly inside a block ("": the top level's).
func kids(id := "") -> Array:
	return tree().get(id, {}).get("kids", [])


## The block a block is in ("" at the top level, or if it isn't a block).
func up_of(id: String) -> String:
	return String(tree().get(id, {}).get("up", ""))


## The block whose parts are showing ("": the top level).
func level() -> String:
	return String(path.back()) if not path.is_empty() else ""


## The blocks showing: the level's.
func level_blocks() -> Array:
	return kids(level())


func can_enter(id: String) -> bool:
	return id != "" and tree().has(id) and not kids(id).is_empty()


## Go inside a block (the chosen one): only its parts show, the first chosen
## (or the one at `at`). False if it has nothing inside.
func enter(id := "", at = null) -> bool:
	if id == "":
		id = sel
	if not can_enter(id):
		if _exists(id):
			_say(TEXT["nothing_inside"] % label_of(id))
		return false
	path = _chain(id)
	var inside := kids(id)
	sel = inside[0]
	if at != null:
		var under := blocks_at(at)
		if not under.is_empty():
			sel = under[0]
	list_scroll = 0.0
	hover_el = ""
	hover_row = ""
	_last_tap = ["", 0, Vector2.ZERO]
	if main.has_method("sfx"):
		main.sfx("ui_confirm")
	_reveal_row()
	queue_redraw()
	return true


## Back out to the level above (the block just left stays chosen). False at the top.
func back_out() -> bool:
	_sync()
	if path.is_empty():
		return false
	sel = String(path.pop_back())
	list_scroll = 0.0
	hover_el = ""
	hover_row = ""
	_last_tap = ["", 0, Vector2.ZERO]
	if main.has_method("sfx"):
		main.sfx("ui_back")
	_reveal_row()
	queue_redraw()
	return true


## The top level, its first block chosen.
func _to_top() -> void:
	path = []
	_tree = {}
	list_scroll = 0.0
	var top := kids("")
	sel = top[0] if not top.is_empty() else ""


## The blocks around a block, outermost first, then the block itself.
func _chain(id: String) -> Array:
	var out: Array = [id]
	var p := up_of(id)
	while p != "" and out.size() < 16:
		out.push_front(p)
		p = up_of(p)
	return out


## Keeps the level true: a block that's gone is stepped out of, and the level
## follows the chosen block (chosen from outside: a test, Tab after a rebuild).
func _sync() -> void:
	while not path.is_empty() and not can_enter(String(path.back())):
		path.pop_back()
	if not path.is_empty():
		path = _chain(String(path.back()))
	if sel != "" and tree().has(sel) and up_of(sel) != level():
		var p := up_of(sel)
		path = _chain(p) if p != "" else []
		list_scroll = 0.0


## Everything inside a block, at every depth.
func _below(id: String) -> Array:
	var out: Array = []
	for k in kids(id):
		out.append(k)
		out.append_array(_below(k))
	return out


## The breadcrumb's names: the screen, then each block stepped into.
func crumbs() -> Array:
	var out: Array = [screen_name()]
	for id in path:
		out.append(label_of(id))
	return out


## What the screen being arranged is called (the breadcrumb's first name).
func screen_name() -> String:
	if menu_mode and main.menu != null:
		var m = main.menu
		if m.page == "train":
			return TEXT["top_train"] % ArrangeUI._car_name(String(m.train_car))
		return ArrangeUI.page_name(m)
	return TEXT["top_touch"] if Layout.active_set == "touch" else TEXT["top_hud"]


# --- where things are ------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size


func _hs() -> float:
	return main.hud.hud_scale if main.hud != null else 1.0


## A group of the HUD's elements arranged together (layout.gd GROUPS).
func is_group(id: String) -> bool:
	return Layout.is_group(id)


## A menu's, the rail's or the train's element (arrange_ui.gd), not the HUD's.
func is_live(id: String) -> bool:
	return not Layout.has(id) and not Layout.is_group(id) and ArrangeUI.has(id)


## Something that can be arranged just now.
func _exists(id: String) -> bool:
	if id == "":
		return false
	if Layout.is_group(id):
		return not Layout.group_members(id).is_empty()
	return Layout.has(id) or ArrangeUI.has(id)


## It lies under everything (the stair arrow's ring, the joystick zone):
## listed, and only outlined while it's chosen.
func is_zone(id: String) -> bool:
	return Layout.is_zone(id)


static func _union(rects: Array) -> Rect2:
	if rects.is_empty():
		return Rect2()
	var out: Rect2 = rects[0]
	for r in rects:
		out = out.merge(r)
	return out


## The parts a group's box goes around: the ones on screen just now (all of
## them if none is), so its outline hugs what you see.
func _box_parts(id: String) -> Array:
	var all := Layout.group_members(id)
	var on := all.filter(func(m): return showing(m))
	return all if on.is_empty() else on


## A block's arranged box on the view, in view pixels (a group: around its parts).
func screen_rect(id: String) -> Rect2:
	if is_group(id):
		return _union(_box_parts(id).map(func(m): return screen_rect(m)))
	if is_live(id):
		return ArrangeUI.rect(id)
	var k := Layout.space_scale(id, _hs())
	var b := Layout.box(id, Layout.space_size(id, _view(), _hs()))
	return Rect2(b.position * k, b.size * k)


## Its box with nothing arranged, on the view (a menu's element: where its
## page puts it now).
func default_rect(id: String) -> Rect2:
	if is_group(id):
		return _union(_box_parts(id).map(func(m): return default_rect(m)))
	if is_live(id):
		return ArrangeUI.default_rect(id)
	var k := Layout.space_scale(id, _hs())
	var b := Layout.default_box(id, Layout.space_size(id, _view(), _hs()))
	return Rect2(b.position * k, b.size * k)


## Its size at scale 1 (a menu's element: as resized; a group: as it is).
func _default_size(id: String) -> Vector2:
	if is_group(id):
		return screen_rect(id).size
	if is_live(id):
		return ArrangeUI.base_rect(id).size
	var k := Layout.space_scale(id, _hs())
	return Layout.default_box(id, Layout.space_size(id, _view(), _hs())).size * k


## A group's parts' boxes now: {id: Rect2}.
func _part_rects(id: String) -> Dictionary:
	var out := {}
	for m in Layout.group_members(id):
		out[m] = screen_rect(m)
	return out


## Puts a block at this view rect (Layout re-anchors it to the nearest
## corner or edge). A group: each part keeps its place in it.
func _apply(id: String, r: Rect2) -> void:
	if is_group(id):
		# (while it's dragged: from where its parts were when the drag began)
		var dragging: bool = drag.get("group", "") == id
		var from: Rect2 = drag["rect"] if dragging else screen_rect(id)
		var parts: Dictionary = drag["parts"] if dragging else _part_rects(id)
		var k := r.size.x / maxf(from.size.x, 1.0)
		for m in parts:
			var pr: Rect2 = parts[m]
			_apply_one(m, Rect2(r.position + (pr.position - from.position) * k, pr.size * k))
		_changed()
		return
	_apply_one(id, r)
	_changed()


func _apply_one(id: String, r: Rect2) -> void:
	if is_live(id):
		ArrangeUI.move_to(id, r)
		return
	var k := Layout.space_scale(id, _hs())
	Layout.move_to(id, Rect2(r.position / k, r.size / k), Layout.space_size(id, _view(), _hs()))


## Everything that draws from the layout redraws (the game is paused, so
## their own change checks don't run); over a menu, the menu is laid out again.
func _changed() -> void:
	queue_redraw()
	_tree = {}
	_shown = {}
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


## The block of the level showing under a point: the smallest one there.
func block_at(pos: Vector2) -> String:
	var hits := blocks_at(pos)
	return hits[0] if not hits.is_empty() else ""


## Every block of the level showing under a point, the smallest first (a
## zone only while it's the chosen one, and then last).
func blocks_at(pos: Vector2) -> Array:
	var found: Array = []
	var grow := 0.0 if menu_mode else 4.0
	var blocks := level_blocks()
	var rects := {}
	for id in blocks:
		rects[id] = screen_rect(id).abs()
	var drawn := {}
	for o in _solid(blocks, rects):
		drawn[o[0]] = true
	for id in blocks:
		if id != sel and not drawn.has(id):
			continue  # (not outlined: it's chosen from the list)
		var r: Rect2 = (rects[id] as Rect2).grow(grow)
		var hit := r.has_point(pos)
		if hit and Layout.is_loose(id):
			# (scattered parts: only where one of them is)
			hit = _part_rects(id).values().any(func(p): return (p as Rect2).abs().grow(grow).has_point(pos))
		if hit:
			found.append([INF if is_zone(id) else r.get_area(), id])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.map(func(f): return f[1])


## Is it on screen just now (the rest are outlined fainter)?
func showing(id: String) -> bool:
	var key := [id, Layout.active_set]
	if not _shown.has(key):
		_shown[key] = _showing(id)
	return _shown[key]


func _showing(id: String) -> bool:
	if is_group(id):
		return Layout.group_members(id).any(func(m): return showing(m))
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


## The friendly name Arrange mode shows (a mark button says whose mark is there now).
func label_of(id: String) -> String:
	if is_live(id):
		return ArrangeUI.friendly(id)
	var name := Layout.display_name(id)
	if id.begins_with("touch.mark_") and main.touch != null:
		for b in main.touch.buttons:
			if b.get("el", "") == id and b.has("part"):
				name += " (%s)" % main.BondScript.PART_NAMES.get(b["part"], b["part"])
	return name


## Can it be dragged from its place (the rail can't: it stays at the left edge)?
func can_move(id: String) -> bool:
	return not is_live(id) or ArrangeUI.cap(id, "move")


## Was it arranged (moved, scaled or resized from how it's built)? A group:
## any of its parts.
func arranged(id: String) -> bool:
	if is_group(id):
		return Layout.group_members(id).any(func(m): return arranged(m))
	if is_live(id):
		return ArrangeUI.override(id) != null
	return Layout.moved(id)


## Was anything inside it arranged?
func arranged_inside(id: String) -> bool:
	return _below(id).any(func(k): return not is_group(k) and arranged(k))


## How far its middle is from where it was built, in view pixels.
func offset_of(id: String) -> Vector2:
	return screen_rect(id).get_center() - default_rect(id).get_center()


## How big it is next to how it was built (1: as built).
func scale_of(id: String) -> float:
	if is_live(id):
		return ArrangeUI.scale_of(id)
	return screen_rect(id).size.x / maxf(default_rect(id).size.x, 0.001)


## The chosen block in plain words: [how far it moved, its size].
func readout(id: String) -> Array:
	var off := offset_of(id)
	var bits: Array = []
	if absf(off.x) >= 0.5:
		bits.append(TEXT["right" if off.x > 0.0 else "left"] % int(round(absf(off.x))))
	if absf(off.y) >= 0.5:
		bits.append(TEXT["down" if off.y > 0.0 else "up"] % int(round(absf(off.y))))
	var moved: String = TEXT["not_moved"] if bits.is_empty() else TEXT["moved"] % TEXT["and"].join(bits)
	var size: String = TEXT["size"] % int(round(scale_of(id) * 100.0))
	if is_live(id):
		for axis in [["w", "wide"], ["h", "tall"]]:
			var f := ArrangeUI.factor(id, axis[0])
			if absf(f - 1.0) > 0.004:
				size += TEXT["dot"] + TEXT[axis[1]] % int(round(f * 100.0))
	return [moved, size]


## The blocks beside it that it has come to overlap (not counting what
## overlapped as built): the names for "Overlaps ...".
func clashes(id: String) -> Array:
	if not tree().has(id):
		return []
	var sibs := kids(up_of(id))
	var rects := {}
	for o in sibs:
		rects[o] = screen_rect(o).abs()
	return _clashes(sibs, rects).get(id, [])


## {id: [the ids it clashes with]} among these blocks.
func _clashes(blocks: Array, rects: Dictionary) -> Dictionary:
	var out := {}
	var defs := {}
	for i in blocks.size():
		var a: String = blocks[i]
		if is_zone(a) or Layout.is_loose(a):
			continue
		for j in range(i + 1, blocks.size()):
			var b: String = blocks[j]
			if is_zone(b) or Layout.is_loose(b) or not (arranged(a) or arranged(b)):
				continue
			var now: Rect2 = (rects[a] as Rect2).intersection(rects[b])
			if now.size.x < 3.0 or now.size.y < 3.0:
				continue
			for x in [a, b]:
				if not defs.has(x):
					defs[x] = default_rect(x).abs()
			var built: Rect2 = (defs[a] as Rect2).intersection(defs[b])
			if now.get_area() <= built.get_area() + 24.0:
				continue
			out[a] = out.get(a, []) + [b]
			out[b] = out.get(b, []) + [a]
	return out


# --- the toolbar --------------------------------------------------------------------

func _button_label(id: String) -> String:
	match id:
		"grid":
			return TEXT["grid_on"] if grid else TEXT["grid_off"]
		"list":
			return TEXT["list_on"] if list_showing() else TEXT["list_off"]
		"reset_all", "reset_page":
			return TEXT["sure"] if armed == id else TEXT[id]
	return TEXT[id]


## Would pressing it do anything just now (the rest are drawn dim)?
func _button_live(id: String) -> bool:
	match id:
		"back":
			return not path.is_empty()
		"inside":
			return can_enter(sel)
		"undo":
			return not undo.is_empty()
		"redo":
			return not redo.is_empty()
		"reset_one":
			return _exists(sel) and (arranged(sel) or arranged_inside(sel))
	return true


## Over a menu with the rail showing (on a view with room): the list and the
## toolbar stand in a column over the rail (-1), so the page is clear; while
## the rail itself is being arranged, at the right (1). 0: no column.
func _column() -> int:
	if not menu_mode or main == null or main.menu == null or not main.menu.rail_showing():
		return 0
	var view := _view()
	if view.x < COL_MIN.x or view.y < COL_MIN.y:
		return 0
	return 1 if (sel.begins_with("rail.") or level().begins_with("rail.")) else -1


## Where the toolbar and the list stand until they're dragged somewhere:
## {"tall" (the toolbar's buttons two to a row), "bar_w", "bar_x", "list_w",
## "list_x", "list_y", "above_bar" (the list ends above the toolbar)}. The
## toolbar stands at the bottom.
func _dock() -> Dictionary:
	var view := _view()
	var lw := minf(clampf(view.x * 0.21, 204.0, COL_W), view.x - 16.0)
	var wide := minf(700.0, view.x - 16.0)
	var out := {"tall": false, "bar_w": wide, "bar_x": (view.x - wide) * 0.5, "list_w": lw, "list_x": view.x - lw - 8.0, "list_y": 8.0, "above_bar": false}
	var col := _column()
	if col != 0:
		var x := 8.0 if col < 0 else view.x - COL_W - 8.0
		out.merge({"tall": true, "bar_w": COL_W, "bar_x": x, "list_w": COL_W, "list_x": x, "above_bar": true}, true)
	elif not menu_mode and Layout.active_set == "touch":
		# The phone's layout: its buttons are at the right, so both at the left.
		if view.x >= 840.0 and view.y >= 470.0:
			out.merge({"tall": true, "bar_w": 204.0, "bar_x": 8.0 + lw + 8.0, "list_x": 8.0, "list_y": 124.0}, true)
		else:
			out.merge({"bar_w": clampf(view.x * 0.5 - 12.0, minf(260.0, view.x - 16.0), wide), "bar_x": 8.0}, true)
	elif not menu_mode and view.y >= 560.0:
		out["list_y"] = 124.0  # (below the key hints and the Entity's bubble)
	if not out["tall"] and not out["above_bar"]:
		var lx: float = out["list_x"]
		var bx: float = out["bar_x"]
		if lx < bx + float(out["bar_w"]) + 8.0 and bx < lx + lw + 8.0:
			out["above_bar"] = true  # (a narrow view: they'd lie on each other)
	return out


## The toolbar's rect and its buttons: {"bar": Rect2, "title": Rect2,
## "buttons": [[id, Rect2, label]], "text": where its words go, "tall"}.
func toolbar() -> Dictionary:
	var view := _view()
	var dock := _dock()
	var tall: bool = dock["tall"]
	var w: float = dock["bar_w"]
	var display := UI.font("display")
	var ids := ["back", "inside", "undo", "redo", "reset_one", "reset_all", "grid", "list", "copy", "save", "done"]
	if menu_mode:
		ids.insert(5, "reset_page")
	var labels := {}
	var widest := 0.0
	for id in ids:
		var label := _button_label(id)
		labels[id] = label
		widest = maxf(widest, display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0)
	# As many rows as the buttons need (a phone at a big Interface size: more).
	var gap := 4.0
	var rows := 2
	var per_row := ceili(ids.size() / 2.0)
	if tall:
		per_row = 2
		rows = ceili(ids.size() / 2.0)
	while rows < 6 and (w - 12.0 - gap * (per_row - 1)) / per_row < widest:
		rows += 1
		per_row = ceili(float(ids.size()) / rows)
	# (tall: the switches have a row of their own under the title, and the words wrap)
	var top := 52.0 if tall else 27.0
	var foot := 50.0 if tall else 35.0
	var h := top + rows * 30.0 + foot
	var at := bar_at
	if at.x < 0.0:
		at = Vector2(float(dock["bar_x"]), view.y - h - 8.0)  # (at the bottom, out of the way)
	at.x = clampf(at.x, 0.0, maxf(view.x - w, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.y - h, 0.0))
	var bar := Rect2(at, Vector2(w, h))
	var title := Rect2(at, Vector2(w, 24.0))
	var out: Array = []
	var sy := 28.0 if tall else 3.0
	var over_menu: bool = _menu_page != "" and not (_menu_page in ArrangeUI.SKIP_PAGES)
	var set_label: String = TEXT["switch"][Layout.active_set]
	var set_w := clampf(display.get_string_size(set_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, 130.0, w * 0.5)
	if tall:
		set_w = (w - 12.0 - 28.0 - 4.0) * (0.55 if over_menu else 1.0)
	out.append(["set", Rect2(at + Vector2(w - set_w - 6.0, sy), Vector2(set_w, 19.0)), set_label])
	out.append(["help", Rect2(at + Vector2(w - set_w - 34.0, sy), Vector2(24.0, 19.0)), TEXT["help"]])
	if over_menu:
		# Over a menu: switch between arranging it and the HUD.
		var vl: String = TEXT["view_hud"] if menu_mode else TEXT["view_menu"]
		var vw := clampf(display.get_string_size(vl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, 110.0, w * 0.3)
		if tall:
			vw = w - 12.0 - set_w - 28.0 - 8.0
		out.append(["view", Rect2(at + Vector2(w - set_w - 40.0 - vw, sy), Vector2(vw, 19.0)), vl])
	var bw := (w - 12.0 - gap * (per_row - 1)) / per_row
	for i in ids.size():
		var id: String = ids[i]
		var col := i % per_row
		var row := i / per_row
		out.append([id, Rect2(at + Vector2(6.0 + col * (bw + gap), top + row * 30.0), Vector2(bw, 26.0)), labels[id]])
	return {"bar": bar, "title": title, "buttons": out, "tall": tall, "text": Rect2(at + Vector2(8.0, top + rows * 30.0), Vector2(w - 16.0, foot - 4.0))}


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
		"redo":
			do_redo()
		"grid":
			grid = not grid
		"list":
			list_user = 0 if list_showing() else 1
		"back":
			if not back_out():
				_say(TEXT["at_top"])
		"inside":
			enter()
		"reset_one":
			if _exists(sel):
				reset_block(sel)
		"reset_all", "reset_page":
			if armed == id and Time.get_ticks_msec() <= armed_until:
				armed = ""
				_push_undo()
				if id == "reset_page":
					reset_page()
					_say(TEXT["reset_page_done"])
				else:
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
			intro = 0
	if main.has_method("sfx"):
		main.sfx("ui_confirm")
	_changed()


## Puts a block, and everything inside it, back in its default place (Undo
## brings it back). True if anything had been arranged.
func reset_block(id: String) -> bool:
	var all: Array = ([id] + _below(id)).filter(func(x): return not is_group(x))
	if is_group(id) and all.is_empty():
		all = Layout.group_members(id)
	if not all.any(func(x): return arranged(x)):
		_say(TEXT["reset_none"] % label_of(id))
		return false
	_push_undo()
	for x in all:
		Layout.reset(x)
	_say(TEXT["reset_one_done"] % label_of(id))
	if menu_mode:
		_rebuild_menu.call_deferred()  # (a panel's width back: its rows unwrap)
	_changed()
	return true


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
	if intro >= 0 and r["user"]:
		intro = -1  # (the last of the three steps)
		if r["project"] != true:
			_say(TEXT["saved"] + ". " + TEXT["intro_done"])
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
	redo.append(Layout.snapshot())
	Layout.restore(undo.pop_back())
	_say(TEXT["undone"])
	_changed()
	if menu_mode:
		_rebuild_menu.call_deferred()


## Redo: what Undo just took back (until something else is changed).
func do_redo() -> void:
	if redo.is_empty():
		_say(TEXT["nothing_redo"])
		return
	undo.append(Layout.snapshot())
	Layout.restore(redo.pop_back())
	_say(TEXT["redone"])
	_changed()
	if menu_mode:
		_rebuild_menu.call_deferred()


## Edits the other layout set: on a computer, the phone's (drawn as the phone draws it).
func switch_set() -> void:
	if main.touch == null:
		return
	main.touch._set_active(not main.touch.active)
	get_tree().paused = true  # (still)
	_tree = {}
	if menu_mode:
		_rebuild_menu()  # (the menu as that layout draws it)
	_sync()
	if not _exists(sel) or not tree().has(sel):
		var list := level_blocks()
		sel = list[0] if not list.is_empty() else ""
	_tell("arrange_sets")


func _push_undo() -> void:
	undo.append(Layout.snapshot())
	if undo.size() > UNDO_MAX:
		undo.pop_front()
	redo.clear()


func _say(text: String) -> void:
	toast = text
	toast_until = Time.get_ticks_msec() + TOAST_MS
	queue_redraw()


# --- the list -----------------------------------------------------------------------

## Is the list showing (the toolbar's List button; by itself only on a view
## big enough for it)?
func list_showing() -> bool:
	if list_user >= 0:
		return list_user == 1
	var view := _view()
	return view.x >= LIST_MIN.x and view.y >= LIST_MIN.y


## The list's rects: {"on", "box", "head" (its title: drag it), "crumb",
## "back", "intro", "view" (the rows' window), "rows": [[id, row, reset or
## null, go inside or null, number]], "up" / "down" (more rows that way: the
## arrows' rects, or null), "detail"}.
func list_panel() -> Dictionary:
	var out := {"on": false, "box": Rect2(), "head": Rect2(), "crumb": Rect2(), "back": Rect2(), "intro": Rect2(), "view": Rect2(),
		"rows": [], "up": null, "down": null, "detail": Rect2()}
	if not list_showing():
		return out
	var view := _view()
	var dock := _dock()
	var w: float = dock["list_w"]
	var row_h := ROW_TOUCH if main.touch_active else ROW_H
	var blocks := level_blocks()
	var top_h := 24.0 + 22.0 + 32.0  # its title, the breadcrumb, Back out
	var intro_h := 0.0 if intro < 0 else 70.0
	# How tall it may be: to the bottom of the view, or to the toolbar under it.
	var at := list_at
	var most := view.y - 16.0
	if at.x < 0.0:
		at = Vector2(float(dock["list_x"]), float(dock["list_y"]))
		most = view.y - at.y - 8.0
		if dock["above_bar"] and bar_at.x < 0.0:
			most = (toolbar()["bar"] as Rect2).position.y - 8.0 - at.y
	# (the chosen block's lines: fewer when the rows need the room)
	var detail_h := 104.0
	if most - top_h - intro_h - detail_h - 8.0 < blocks.size() * row_h:
		detail_h = 62.0
	var rows_h := clampf(blocks.size() * row_h, row_h, maxf(most - top_h - intro_h - detail_h - 8.0, row_h))
	rows_h = floorf(rows_h / row_h) * row_h
	var h := top_h + intro_h + rows_h + detail_h + 8.0
	if list_at.x < 0.0 and dock["tall"] and dock["above_bar"] and bar_at.x < 0.0 and most > h:
		# (in the column over the rail: down to the toolbar, so the rail doesn't show between them)
		detail_h += most - h
		h = most
	at.x = clampf(at.x, 0.0, maxf(view.x - w, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.y - h, 0.0))
	out["on"] = true
	out["box"] = Rect2(at, Vector2(w, h))
	out["head"] = Rect2(at, Vector2(w, 24.0))
	out["crumb"] = Rect2(at + Vector2(8.0, 26.0), Vector2(w - 16.0, 20.0))
	out["back"] = Rect2(at + Vector2(6.0, 48.0), Vector2(w - 12.0, 26.0))
	out["intro"] = Rect2(at + Vector2(6.0, top_h), Vector2(w - 12.0, intro_h))
	var rows_top := at.y + top_h + intro_h
	out["view"] = Rect2(at.x + 4.0, rows_top, w - 8.0, rows_h)
	var sc := clampf(list_scroll, 0.0, maxf(blocks.size() * row_h - rows_h, 0.0))
	sc = roundf(sc / row_h) * row_h
	for i in blocks.size():
		var y := rows_top + i * row_h - sc
		if y < rows_top - 0.5 or y + row_h > rows_top + rows_h + 0.5:
			continue
		var id: String = blocks[i]
		var row := Rect2(at.x + 4.0, y, w - 8.0, row_h - 2.0)
		var go = Rect2(row.end.x - 24.0, y, 24.0, row_h - 2.0) if can_enter(id) else null
		var back = Rect2(row.end.x - 50.0, y, 24.0, row_h - 2.0) if (arranged(id) or arranged_inside(id)) else null
		out["rows"].append([id, row, back, go, i + 1])
	if sc > 0.0:
		out["up"] = Rect2(at.x + w - 30.0, rows_top - 13.0, 26.0, 13.0)
	if sc < blocks.size() * row_h - rows_h - 0.5:
		out["down"] = Rect2(at.x + w - 30.0, rows_top + rows_h, 26.0, 13.0)
	out["detail"] = Rect2(at.x + 6.0, rows_top + rows_h + 6.0, w - 12.0, detail_h - 4.0)
	return out


## What part of the list is at a point: "" (not on it), "head", "back",
## "up", "down", "row:<id>", "reset:<id>", "enter:<id>", or "box".
func _list_hit(pos: Vector2, lp := {}) -> String:
	if lp.is_empty():
		lp = list_panel()
	if not lp["on"] or not (lp["box"] as Rect2).has_point(pos):
		return ""
	if (lp["back"] as Rect2).has_point(pos):
		return "back"
	for k in ["up", "down"]:
		if lp[k] != null and (lp[k] as Rect2).grow(4.0).has_point(pos):
			return k
	for row in lp["rows"]:
		if row[2] != null and (row[2] as Rect2).has_point(pos):
			return "reset:" + String(row[0])
		if row[3] != null and (row[3] as Rect2).has_point(pos):
			return "enter:" + String(row[0])
		if (row[1] as Rect2).has_point(pos):
			return "row:" + String(row[0])
	if (lp["head"] as Rect2).has_point(pos):
		return "head"
	return "box"


## The block a part of the list ("row:<id>", ...) is about, or "".
func _hit_id(hit: String) -> String:
	var cut := hit.find(":")
	return hit.substr(cut + 1) if cut >= 0 else ""


## Chooses a block (the list, a click, Tab).
func choose(id: String) -> void:
	if id == sel:
		return
	sel = id
	if intro == 0:
		intro = 1
	if main.has_method("sfx"):
		main.sfx("ui_move")
	_reveal_row()
	queue_redraw()


## Scrolls the list so the chosen block's row shows.
func _reveal_row() -> void:
	var blocks := level_blocks()
	var i := blocks.find(sel)
	if i < 0 or not list_showing():
		return
	var lp := list_panel()
	var row_h := ROW_TOUCH if main.touch_active else ROW_H
	var rows_h: float = (lp["view"] as Rect2).size.y
	if i * row_h < list_scroll:
		list_scroll = i * row_h
	elif (i + 1) * row_h > list_scroll + rows_h:
		list_scroll = (i + 1) * row_h - rows_h


func _scroll_list(by: int) -> void:
	var row_h := ROW_TOUCH if main.touch_active else ROW_H
	var rows_h: float = (list_panel()["view"] as Rect2).size.y
	list_scroll = clampf(list_scroll + by * row_h, 0.0, maxf(level_blocks().size() * row_h - rows_h, 0.0))
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


## The Entity's three steps (entity.gd TIPS "arrange": "steps"), to do in order.
func intro_steps() -> Array:
	return Entity.entry("arrange").get("steps", [])


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
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and not asking:
			var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
			if _list_hit(event.position) != "":
				_scroll_list(-2 if up else 2)  # (over the list: its rows)
			elif _exists(sel) and screen_rect(sel).abs().grow(4.0).has_point(event.position):
				# (over the chosen block: its size)
				_push_undo()
				nudge_scale(0.05 if up else -0.05)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if asking:
				asking = false
				queue_redraw()
			elif not back_out():
				finish()
	elif event is InputEventMouseMotion:
		pointer_move(-1, event.position, event.shift_pressed)
		var h := _toolbar_button_at(event.position)
		if h != hover:
			hover = h
			queue_redraw()
		if drag.is_empty():
			# The block under the mouse lights up (or the one whose row is).
			var hr := _list_hit(event.position)
			var he := ""
			if hr != "":
				he = _hit_id(hr)
			elif not (toolbar()["bar"] as Rect2).has_point(event.position):
				he = block_at(event.position)
			if he != hover_el or hr != hover_row:
				hover_el = he
				hover_row = hr
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
		if k == KEY_Z and event.shift_pressed:
			do_redo()
		elif k == KEY_Z:
			do_undo()
		elif k == KEY_Y:
			do_redo()
		elif k == KEY_S:
			save()
		elif k == KEY_C:
			copy_layout()
		return
	match k:
		KEY_F2:
			finish()
		KEY_ESCAPE:
			if not event.echo and not back_out():
				finish()  # (at the top level: done)
		KEY_BACKSPACE, KEY_PAGEUP:
			if not event.echo:
				press("back")
		KEY_ENTER, KEY_KP_ENTER, KEY_PAGEDOWN:
			if not event.echo:
				press("inside")
		KEY_TAB:
			pick(-1 if event.shift_pressed else 1)
		KEY_G:
			press("grid")
		KEY_L:
			press("list")
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if _exists(sel) and can_move(sel):
				var step := 1.0 if event.shift_pressed else GRID
				var d := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[k] as Vector2
				if not event.echo:
					_push_undo()
				var r := screen_rect(sel)
				_apply(sel, Rect2(r.position + d * step, r.size))
		KEY_BRACKETLEFT, KEY_MINUS:
			if _exists(sel):
				_push_undo()
				nudge_scale(-0.05)
		KEY_BRACKETRIGHT, KEY_EQUAL, KEY_PLUS:
			if _exists(sel):
				_push_undo()
				nudge_scale(0.05)
		KEY_DELETE:
			press("reset_one")


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
		JOY_BUTTON_A:
			press("inside")
		JOY_BUTTON_B:
			if not back_out():
				finish()  # (at the top level: done)
		JOY_BUTTON_START:
			finish()
		JOY_BUTTON_X:
			do_undo()
		JOY_BUTTON_Y:
			save()
		JOY_BUTTON_BACK:
			press("grid")


## The next (or previous) block of the level showing.
func pick(by: int) -> void:
	_sync()
	var list := level_blocks()
	if list.is_empty():
		return
	var i := list.find(sel)
	sel = ""
	choose(list[(i + by + list.size()) % list.size()] if i >= 0 else list[0])


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
func pointer_down(ptr: int, pos: Vector2, _free := false) -> void:
	if not drag.is_empty():
		return  # (one thing at a time)
	if asking:
		for b in _ask_buttons()[1]:
			if b[1].has_point(pos):
				answer(b[0])
				return
		return
	_sync()
	var now := Time.get_ticks_msec()
	var tb := toolbar()
	var hit := _toolbar_button_at(pos)
	if hit != "":
		press(hit)
		return
	if tb["title"].has_point(pos) or tb["bar"].has_point(pos):
		drag = {"kind": "bar", "ptr": ptr, "from": pos, "at": tb["bar"].position}
		return
	# The list: a row chooses its block (twice: goes inside), its round arrow
	# puts it back, its > goes inside; anywhere else on it drags it.
	var lp := list_panel()
	var lh := _list_hit(pos, lp)
	if lh != "":
		var lid := _hit_id(lh)
		if lh == "back":
			press("back")
		elif lh == "up" or lh == "down":
			_scroll_list(-3 if lh == "up" else 3)
		elif lh.begins_with("reset:"):
			sel = lid
			reset_block(lid)
		elif lh.begins_with("enter:"):
			enter(lid)
		elif lh.begins_with("row:"):
			var twice: bool = _last_tap[0] == lh and now - int(_last_tap[1]) <= DOUBLE_MS
			_last_tap = [lh, now, pos]
			if twice and can_enter(lid):
				enter(lid)
			else:
				choose(lid)
		else:
			drag = {"kind": "list", "ptr": ptr, "from": pos, "at": (lp["box"] as Rect2).position}
		queue_redraw()
		return
	# A corner handle of the chosen block: scale; a side handle: resize.
	if _exists(sel):
		var r := screen_rect(sel)
		var grab := GRAB_TOUCH if ptr >= 0 else GRAB
		if _corner_handles(sel):
			var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for ci in 4:
				if pos.distance_to(corners[ci]) <= grab:
					drag = {"kind": "scale", "ptr": ptr, "from": pos, "rect": r, "corner": ci, "scale": r.size.x / maxf(_default_size(sel).x, 0.001)}
					_drag_group()
					queue_redraw()
					return
		for sh in side_handles(sel):
			if pos.distance_to(sh[1]) <= grab + 4.0:
				drag = {"kind": "resize", "ptr": ptr, "from": pos, "rect": r, "side": sh[0]}
				queue_redraw()
				return
	# A block of the level showing: chosen, and dragged from anywhere on it;
	# pressed twice, it's gone inside. (Where blocks overlap the chosen one
	# keeps the press, so it can be dragged out again.)
	var hits := blocks_at(pos)
	if not hits.is_empty():
		var id: String = sel if (sel in hits and not is_zone(sel)) else hits[0]
		var twice: bool = _last_tap[0] == id and now - int(_last_tap[1]) <= DOUBLE_MS and pos.distance_to(_last_tap[2]) <= DOUBLE_PX
		if twice and can_enter(id):
			enter(id, pos)
			return
		choose(id)
		drag = {"kind": "move", "ptr": ptr, "from": pos, "rect": screen_rect(id), "moved": false, "id": id}
		_drag_group()
	else:
		# Outside the block you're in, twice: back out.
		var out_of: bool = level() != "" and not screen_rect(level()).grow(8.0).has_point(pos)
		var twice: bool = _last_tap[0] == "out" and now - int(_last_tap[1]) <= DOUBLE_MS and pos.distance_to(_last_tap[2]) <= DOUBLE_PX
		_last_tap = ["out" if out_of else "", now, pos]
		if out_of and twice:
			back_out()
	queue_redraw()


## A drag of a group: where it and its parts are as it begins.
func _drag_group() -> void:
	if is_group(sel):
		drag["group"] = sel
		drag["parts"] = _part_rects(sel)


## The first change of a drag: what was there before is kept for Undo.
func _drag_changes() -> void:
	if not drag.get("kept", false):
		drag["kept"] = true
		_push_undo()


## Whether the chosen block has corner handles (it scales with its box).
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
		"list":
			list_at = (drag["at"] + d).max(Vector2.ZERO)
			queue_redraw()
		"move":
			if not can_move(sel):
				return
			_drag_changes()
			var r: Rect2 = drag["rect"]
			r.position += d
			if not free:
				r = snap(r, sel)
			else:
				guides.clear()
			drag["moved"] = true
			_apply(sel, r)
		"scale":
			_drag_changes()
			_scale_drag(pos, free)
		"resize":
			_drag_changes()
			_resize_drag(pos, free)


func pointer_up(ptr: int) -> void:
	if drag.is_empty() or drag["ptr"] != ptr:
		return
	var kind: String = drag["kind"]
	if kind == "move":
		if drag.get("moved", false):
			_last_tap = ["", 0, Vector2.ZERO]
			if intro == 1:
				intro = 2
		else:
			# (a press that didn't drag: a second one soon goes inside)
			_last_tap = [String(drag["id"]), Time.get_ticks_msec(), drag["from"]]
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


## Pulling a corner: the opposite corner stays put and the block keeps its shape.
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
	if is_live(id) or is_group(id):
		return Layout.MIN_SCALE
	return Layout.min_scale(id, Layout.space_size(id, _view(), _hs()))


## Grows or shrinks the chosen block by this much of its default size, about its centre.
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
	if not _exists(id):
		return
	if is_live(id) or is_group(id):
		if grid and can_move(id):
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


## Snaps a rect: an edge or centre near a screen edge, the centre lines, the
## block it's in or a block beside it sticks there (and shows a guide);
## otherwise, with the grid on, its corner goes onto the grid.
func snap(r: Rect2, id: String) -> Rect2:
	guides.clear()
	var view := _view()
	var near := SNAP_TOUCH if main.touch_active else SNAP
	var xs: Array = [0.0, view.x * 0.5, view.x]
	var ys: Array = [0.0, view.y * 0.5, view.y]
	var around := up_of(id) if tree().has(id) else level()
	if around != "" and not is_group(around):
		var pr := screen_rect(around)
		xs.append_array([pr.position.x, pr.get_center().x, pr.end.x])
		ys.append_array([pr.position.y, pr.get_center().y, pr.end.y])
	for o in kids(around):
		if o == id or is_zone(o):
			continue
		var orr := screen_rect(o)
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
	_shown = {}
	_sync()
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
	_draw_blocks(body)
	# The guides of a drag.
	for g in guides:
		if g[0] == "x":
			draw_line(Vector2(g[1], 0), Vector2(g[1], view.y), Color(UI.PERIWINKLE, 0.9), 1.5)
		else:
			draw_line(Vector2(0, g[1]), Vector2(view.x, g[1]), Color(UI.PERIWINKLE, 0.9), 1.5)
	_draw_list(body, mono, display)
	_draw_toolbar(body, mono, display)
	if toast != "":
		var tw := minf(body.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0, view.x - 16.0)
		var tbd := toolbar()
		var tb := tbd["bar"] as Rect2
		var ty := tb.end.y + 6.0 if tb.end.y + 36.0 < view.y else tb.position.y - 34.0
		if tbd["tall"]:
			ty = view.y - 40.0  # (the toolbar's at the side: the notice at the bottom, in the middle)
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


## The outlines drawn just now, as [[id, Rect2]]: the level's blocks (not a
## zone unless it's the chosen one). One level only, ever.
func outlines() -> Array:
	var blocks := level_blocks()
	var rects := {}
	for id in blocks:
		rects[id] = screen_rect(id).abs()
	return _solid(blocks, rects)


## The boxes outlined for these blocks, as [[id, Rect2]]: a block's own box,
## or (its parts being scattered: layout.gd "loose") each part's. No zone;
## and a block that isn't on screen just now only where its box is clear of
## the others (else it's in the list alone, until it's chosen).
func _solid(blocks: Array, rects: Dictionary) -> Array:
	var out: Array = []
	var later: Array = []
	for id in blocks:
		if is_zone(id):
			continue
		if Layout.is_loose(id):
			for p in _part_rects(id).values():
				out.append([id, (p as Rect2).abs()])
		elif showing(id):
			out.append([id, rects[id]])
		else:
			later.append(id)
	for id in later:
		var r: Rect2 = rects[id]
		if not out.any(func(o): return (o[1] as Rect2).intersects(r)):
			out.append([id, r])
	return out


## The level showing: outside the block you're in, a veil; each of its
## blocks one outline with its number and name; the chosen one lit, with
## its handles; what overlaps hatched red.
func _draw_blocks(font: Font) -> void:
	var view := _view()
	var lv := level()
	var blocks := level_blocks()
	if lv != "":
		# Everything outside the block you're in is dimmed; a dashed line marks it.
		var pr := Rect2(Vector2.ZERO, view).intersection(screen_rect(lv).abs().grow(6.0))
		var veil := Color(0, 0, 0, 0.42)
		for vr in [Rect2(0, 0, view.x, pr.position.y), Rect2(0, pr.end.y, view.x, view.y - pr.end.y),
				Rect2(0, pr.position.y, pr.position.x, pr.size.y), Rect2(pr.end.x, pr.position.y, view.x - pr.end.x, pr.size.y)]:
			if vr.size.x > 0.0 and vr.size.y > 0.0:
				draw_rect(vr, veil)
		var pts := [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]
		for i in 4:
			draw_dashed_line(pts[i], pts[(i + 1) % 4], Color(UI.PERIWINKLE, 0.7), 1.5, 6.0)
	var rects := {}
	for id in blocks:
		rects[id] = screen_rect(id).abs()
	var drawn := {}
	for o in _solid(blocks, rects):
		drawn[o[0]] = true
	var chips := _place_labels(blocks, rects, font)
	var clash := _clashes(blocks, rects)
	for id in blocks:
		if id == sel or id == hover_el or not drawn.has(id):
			continue
		_draw_block(id, rects[id], "rest", chips.get(id, {}), clash.has(id), font)
	# What overlaps: the shared part, in red.
	for a in clash:
		for b in clash[a]:
			if String(a) < String(b):
				var shared: Rect2 = (rects[a] as Rect2).intersection(rects[b])
				draw_rect(shared, Color(UI.BAD, 0.28))
				draw_rect(shared, Color(UI.BAD, 0.95), false, 1.5)
	if hover_el != "" and hover_el != sel and blocks.has(hover_el):
		_draw_block(hover_el, rects[hover_el], "hover", chips.get(hover_el, {}), clash.has(hover_el), font)
	if _exists(sel):
		_draw_block(sel, rects.get(sel, screen_rect(sel).abs()), "sel", chips.get(sel, {}), clash.has(sel), font)


## Where each block's label goes so no two overlap: {id: {"rect", "text"}}.
## The number and name inside the block's top left when they fit, else just
## above or below it (clear of the other blocks), else only the number on a
## corner; the list names every number.
func _place_labels(blocks: Array, rects: Dictionary, font: Font) -> Dictionary:
	var out := {}
	var placed: Array = []
	var solid := _solid(blocks, rects)
	var drawn := {}
	for o in solid:
		drawn[o[0]] = true
	var screen := Rect2(Vector2.ZERO, _view())
	var fs := 13
	var h := fs + 7.0
	for i in blocks.size():
		var id: String = blocks[i]
		if not drawn.has(id) and id != sel:
			continue
		var r: Rect2 = _label_box(id, rects[id])
		var num := str(i + 1)
		var full := "%s  %s" % [num, label_of(id)]
		var fw := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		# [rect, words, must keep clear of the other blocks]
		var tries: Array = []
		# (inside it: only if it's tall enough that its own words still show)
		if fw + 6.0 <= r.size.x and h * 2.4 <= r.size.y:
			tries.append([Rect2(r.position + Vector2(3.0, 3.0), Vector2(fw, h)), full, false])
		tries.append([Rect2(r.position + Vector2(0.0, -h - 2.0), Vector2(fw, h)), full, true])
		tries.append([Rect2(Vector2(r.position.x, r.end.y + 2.0), Vector2(fw, h)), full, true])
		# (only its number: just left of it, clear of its own words, else on it)
		tries.append([Rect2(Vector2(r.position.x - nw - 2.0, r.position.y + minf((r.size.y - h) * 0.5, 6.0)), Vector2(nw, h)), num, true])
		if nw + 6.0 <= r.size.x and h + 6.0 <= r.size.y:
			tries.append([Rect2(r.position + Vector2(3.0, 3.0), Vector2(nw, h)), num, false])
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			tries.append([Rect2(c - Vector2(nw, h) * 0.5, Vector2(nw, h)), num, false])
		for t in tries:
			var cr: Rect2 = t[0]
			if not screen.encloses(cr) or placed.any(func(p): return (p as Rect2).grow(1.0).intersects(cr)):
				continue
			if t[2] and solid.any(func(o): return o[0] != id and (o[1] as Rect2).intersects(cr)):
				continue
			out[id] = {"rect": cr, "text": t[1]}
			placed.append(cr)
			break
	return out


## The box a block's label goes by: its own, or (scattered parts) its first part's.
func _label_box(id: String, r: Rect2) -> Rect2:
	if Layout.is_loose(id):
		var parts := Layout.group_members(id)
		if not parts.is_empty():
			return screen_rect(parts[0]).abs()
	return r


## One block: its outline (dashed and faint if it isn't on screen just now),
## its label, and for the chosen one its handles.
func _draw_block(id: String, r: Rect2, state: String, chip: Dictionary, clash: bool, font: Font) -> void:
	var on := showing(id)
	var chosen := state == "sel"
	var lit := chosen or state == "hover"
	var col := UI.GILT_HI if lit else Color(UI.GILT, 0.9 if on else 0.5)
	if clash:
		col = UI.BAD
	var w := 2.5 if chosen else (2.0 if lit else 1.5)
	var loose := Layout.is_loose(id)
	if loose:
		# Scattered parts: each outlined; one box around them all only when chosen.
		for m in Layout.group_members(id):
			var pr := screen_rect(m).abs()
			draw_rect(pr, Color(UI.GILT, 0.09 if lit else 0.03))
			draw_rect(pr.grow(1.0), Color(0, 0, 0, 0.5), false, 3.0)
			draw_rect(pr, Color(col, 1.0 if showing(m) or lit else 0.5), false, 1.5)
	if loose and not chosen:
		pass
	elif on or lit:
		draw_rect(r, Color(UI.GILT, 0.13 if chosen else (0.09 if lit else 0.03)))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55), false, w + 2.0)  # (a dark edge: it reads over anything)
		draw_rect(r, col, false, w)
	else:
		draw_rect(r, Color(UI.GILT, 0.03))
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(pts[i], pts[(i + 1) % 4], col, w, 5.0)
	if loose and not chosen:
		r = _label_box(id, r)
	# Its label: where it was placed; the lit one always says its whole name.
	var fs := 13
	var num := level_blocks().find(id) + 1
	var full := ("%d  %s" % [num, label_of(id)]) if num > 0 else label_of(id)
	var cr: Rect2 = chip.get("rect", Rect2())
	var words := String(chip.get("text", ""))
	if lit and words != full:
		var fw := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		var at := r.position + Vector2(0.0, -fs - 9.0)
		if at.y < 2.0:
			at = r.position + Vector2(3.0, 3.0)
		var view := _view()
		at.x = clampf(at.x, 2.0, maxf(view.x - fw - 2.0, 2.0))
		cr = Rect2(at, Vector2(fw, fs + 7.0))
		words = full
	if words != "":
		draw_rect(cr, Color(UI.VOID, 0.92 if lit else 0.82))
		draw_rect(cr, Color(col, 0.9 if lit else 0.55), false, 1.0)
		draw_string(font, cr.position + Vector2(6.0, fs + 1.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GILT_HI if lit else (UI.TEXT if on else UI.DIM))
	if not chosen:
		return
	# The handles: big gilt squares on the corners (size), blue bars on the
	# sides that can be pulled (width, height), and a cross in the middle (move).
	if can_move(id) and r.size.x >= 70.0 and r.size.y >= 56.0:
		_draw_move_mark(r.get_center())
	if _corner_handles(id):
		for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var hr := Rect2(c - Vector2(HANDLE, HANDLE) * 0.5, Vector2(HANDLE, HANDLE))
			draw_rect(hr.grow(2.0), Color(0, 0, 0, 0.85))
			draw_rect(hr, UI.GILT_HI)
	for sh in side_handles(id):
		var across: bool = sh[0] in ["left", "right"]
		var hs := Vector2(HANDLE * 0.7, HANDLE * 3.0) if across else Vector2(HANDLE * 3.0, HANDLE * 0.7)
		var hr := Rect2(sh[1] - hs * 0.5, hs)
		draw_rect(hr.grow(2.0), Color(0, 0, 0, 0.85))
		draw_rect(hr, UI.PERIWINKLE)


## The four-way arrows in the middle of the chosen block: drag it to move it.
func _draw_move_mark(c: Vector2) -> void:
	var col := Color(UI.GILT_HI, 0.85)
	draw_circle(c, 15.0, Color(0, 0, 0, 0.5))
	for d in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var side := Vector2(-d.y, d.x)
		draw_line(c, c + d * 8.0, col, 1.6)
		draw_colored_polygon(PackedVector2Array([c + d * 12.0, c + d * 7.0 + side * 3.5, c + d * 7.0 - side * 3.5]), col)


func _draw_button(r: Rect2, label: String, primary: bool, font: Font, focused := false, dim := false) -> void:
	draw_style_box(UI.primary_box() if primary else UI.button_box("hover" if focused and not dim else "normal"), r)
	if focused and not dim:
		draw_rect(r.grow(2.0), Color(UI.GILT_HI, 0.9), false, 1.5)
	var fs := UI.fit_size(font, label, 14, r.size.x - 8.0)
	var col := UI.GILT_HI if primary else UI.TEXT
	draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(col, 0.38) if dim else col)


## Words that must fit a width: if they don't, the front goes ("… > Page > Title").
func _fit_left(font: Font, text: String, size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var sep: String = TEXT["crumb"]
	var parts := text.split(sep)
	while parts.size() > 1:
		parts.remove_at(0)
		var t: String = TEXT["more"] + sep + sep.join(parts)
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return t
	return text


## A row's little pictures: the round arrow (put it back), the > (go inside),
## the tick of a step done.
func _draw_reset_icon(c: Vector2, col: Color) -> void:
	draw_arc(c, 5.5, deg_to_rad(-50.0), deg_to_rad(230.0), 14, col, 1.6, true)
	var tip := c + Vector2.from_angle(deg_to_rad(-50.0)) * 5.5
	draw_colored_polygon(PackedVector2Array([tip + Vector2(3.6, 0.6), tip + Vector2(-1.4, -3.8), tip + Vector2(-1.8, 2.6)]), col)


func _draw_chevron(c: Vector2, col: Color, back := false) -> void:
	var k := -1.0 if back else 1.0
	draw_polyline(PackedVector2Array([c + Vector2(-3.0 * k, -5.0), c + Vector2(3.0 * k, 0.0), c + Vector2(-3.0 * k, 5.0)]), col, 2.0, true)


func _draw_tick(c: Vector2, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-4.5, 0.0), c + Vector2(-1.5, 3.5), c + Vector2(5.0, -4.0)]), col, 2.0, true)


## The list: where you are, Back out, the level's blocks by name, and the
## chosen one in plain words.
func _draw_list(body: Font, mono: Font, _display: Font) -> void:
	var lp := list_panel()
	if not lp["on"]:
		return
	var box: Rect2 = lp["box"]
	draw_style_box(UI.panel(), box)
	draw_rect(box, Color(UI.GILT, 0.55), false, 1.0)
	# Its title (the grip: drag it), and how many blocks are here.
	var head: Rect2 = lp["head"]
	draw_rect(head, Color(UI.GILT, 0.08))
	for i in 3:
		draw_circle(head.position + Vector2(10.0, 8.0 + i * 4.5), 1.2, Color(UI.GILT, 0.6))
		draw_circle(head.position + Vector2(14.0, 8.0 + i * 4.5), 1.2, Color(UI.GILT, 0.6))
	UI.draw_label(self, head.position + Vector2(22.0, 17.0), TEXT["blocks"], 15, UI.GOLD)
	var blocks := level_blocks()
	draw_string(mono, Vector2(head.position.x, head.position.y + 16.0), TEXT["count"] % blocks.size(), HORIZONTAL_ALIGNMENT_RIGHT, head.size.x - 8.0, 11, UI.DIM)
	# Where you are, and the way back out.
	var crumb: Rect2 = lp["crumb"]
	var where: String = _fit_left(body, String(TEXT["crumb"]).join(crumbs()), 13, crumb.size.x)
	draw_string(body, crumb.position + Vector2(0.0, 14.0), where, HORIZONTAL_ALIGNMENT_LEFT, crumb.size.x, 13, UI.GILT_HI)
	var back: Rect2 = lp["back"]
	var at_top := path.is_empty()
	draw_style_box(UI.button_box("hover" if hover_row == "back" and not at_top else "normal"), back)
	_draw_chevron(back.position + Vector2(14.0, back.size.y * 0.5), Color(UI.TEXT, 0.38 if at_top else 1.0), true)
	draw_string(body, Vector2(back.position.x + 26.0, back.get_center().y + 5.0), TEXT["at_top"] if at_top else TEXT["back"], HORIZONTAL_ALIGNMENT_LEFT, back.size.x - 32.0, 13,
		Color(UI.TEXT, 0.45 if at_top else 1.0))
	# The Entity's three steps, ticked off as they're done.
	if intro >= 0:
		var ir: Rect2 = lp["intro"]
		draw_rect(ir.grow_individual(0.0, -2.0, 0.0, -4.0), Color(UI.PERIWINKLE, 0.1))
		var steps := intro_steps()
		for i in steps.size():
			var y := ir.position.y + 4.0 + i * 20.0
			var done := i < intro
			var now := i == intro
			draw_rect(Rect2(ir.position.x + 6.0, y + 2.0, 14.0, 14.0), Color(UI.PERIWINKLE, 0.9 if now else 0.5), false, 1.5)
			if done:
				_draw_tick(Vector2(ir.position.x + 13.0, y + 9.0), UI.GOOD)
			draw_string(body, Vector2(ir.position.x + 26.0, y + 14.0), "%d. %s" % [i + 1, steps[i]], HORIZONTAL_ALIGNMENT_LEFT, ir.size.x - 30.0, 13,
				UI.DIM if done else (Color(0.9, 0.86, 1.0) if now else UI.TEXT))
	# The rows.
	var view: Rect2 = lp["view"]
	draw_rect(view, Color(0, 0, 0, 0.22))
	if blocks.is_empty():
		draw_string(body, view.position + Vector2(8.0, 17.0), TEXT["empty"], HORIZONTAL_ALIGNMENT_LEFT, view.size.x - 12.0, 13, UI.DIM)
	var clash := {}
	if not blocks.is_empty():
		var rects := {}
		for id in blocks:
			rects[id] = screen_rect(id).abs()
		clash = _clashes(blocks, rects)
	for row in lp["rows"]:
		var id: String = row[0]
		var r: Rect2 = row[1]
		var chosen := id == sel
		var lit := id == hover_el
		if chosen:
			draw_rect(r, Color(UI.GILT, 0.24))
			draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), UI.GILT_HI)
		elif lit:
			draw_rect(r, Color(UI.GILT, 0.1))
		var mid := r.get_center().y
		draw_string(mono, Vector2(r.position.x + 6.0, mid + 4.0), str(row[4]), HORIZONTAL_ALIGNMENT_LEFT, 18.0, 11, UI.GILT if chosen else UI.DIM)
		var right := r.end.x - 4.0
		if row[3] != null:
			var go: Rect2 = row[3]
			if hover_row == "enter:" + id:
				draw_rect(go, Color(UI.GILT, 0.25))
			_draw_chevron(go.get_center(), UI.GILT_HI if hover_row == "enter:" + id else UI.TEXT)
		right -= 24.0
		if row[2] != null:
			var rr: Rect2 = row[2]
			if hover_row == "reset:" + id:
				draw_rect(rr, Color(UI.GILT, 0.25))
			_draw_reset_icon(rr.get_center(), UI.GILT_HI if hover_row == "reset:" + id else UI.TEXT)
			right -= 26.0
			# The dot: moved itself (filled), or only something inside it (a ring).
			if arranged(id):
				draw_circle(Vector2(right - 5.0, mid), 4.0, UI.GILT_HI)
			else:
				draw_arc(Vector2(right - 5.0, mid), 3.5, 0.0, TAU, 12, UI.GILT_HI, 1.4, true)
			right -= 14.0
		if clash.has(id):
			draw_colored_polygon(PackedVector2Array([Vector2(right - 6.0, mid - 6.0), Vector2(right, mid + 5.0), Vector2(right - 12.0, mid + 5.0)]), UI.BAD)
			draw_line(Vector2(right - 6.0, mid - 2.0), Vector2(right - 6.0, mid + 1.5), UI.VOID, 1.6)
			draw_circle(Vector2(right - 6.0, mid + 3.3), 0.9, UI.VOID)
			right -= 16.0
		var name := label_of(id)
		var x := r.position.x + 26.0
		var fs := UI.fit_size(body, name, 14, right - x)
		var col := UI.GILT_HI if chosen else (UI.TEXT if showing(id) else UI.FAINT)
		draw_string(body, Vector2(x, mid + fs * 0.36), name, HORIZONTAL_ALIGNMENT_LEFT, right - x, fs, col)
	for k in ["up", "down"]:
		if lp[k] != null:
			var ar: Rect2 = lp[k]
			var c := ar.get_center()
			var s := -1.0 if k == "up" else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6.0, -3.0 * s), c + Vector2(6.0, -3.0 * s), c + Vector2(0.0, 4.0 * s)]), UI.GILT)
	# The chosen block, in plain words.
	var dr: Rect2 = lp["detail"]
	draw_line(dr.position + Vector2(0.0, -1.0), Vector2(dr.end.x, dr.position.y - 1.0), Color(UI.GILT, 0.3))
	if not _exists(sel):
		draw_multiline_string(body, dr.position + Vector2(2.0, 16.0), TEXT["none"], HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 4.0, 13, 3, UI.DIM)
		return
	var lines := detail_lines(sel)
	var y := dr.position.y + 16.0
	draw_string(body, Vector2(dr.position.x + 2.0, y), label_of(sel), HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 4.0, 14, UI.GILT_HI)
	y += 17.0
	for line in lines:
		if y > dr.end.y + 1.0:
			break
		var lcol: Color = UI.BAD if line[1] == "bad" else (UI.TEXT if line[1] == "main" else UI.DIM)
		var room := maxi(int((dr.end.y - y) / 15.0) + 1, 1)
		var lh := body.get_multiline_string_size(String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 4.0, 12, room).y
		draw_multiline_string(body, Vector2(dr.position.x + 2.0, y), String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 4.0, 12, room, lcol)
		y += lh + 1.0


## What the list says under the chosen block's name: [[words, "main" /
## "bad" / "note"]]: how far it moved, its size, what it overlaps, and
## anything worth knowing about it.
func detail_lines(id: String) -> Array:
	var out: Array = []
	var ro := readout(id)
	out.append([ro[0], "main"])
	out.append([ro[1], "main"])
	var hit := clashes(id)
	if not hit.is_empty():
		out.append([TEXT["overlaps"] % TEXT["and"].join(hit.map(func(o): return label_of(o))), "bad"])
	if is_zone(id):
		out.append([TEXT["zone"], "note"])
	elif not showing(id):
		out.append([TEXT["hidden"], "note"])
	var n := kids(id).size()
	if n > 0:
		out.append([TEXT["inside_1"] if n == 1 else TEXT["inside_n"] % n, "note"])
		if arranged_inside(id) and not is_group(id):
			out.append([TEXT["inside_moved"], "note"])
	if is_live(id):
		var how := ArrangeUI.how(id)
		if how != "":
			out.append([how, "note"])
		elif not can_move(id):
			out.append([TEXT["cant_move"], "note"])
	return out


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
		_draw_button(b[1], b[2], primary or armed_now, display, b[0] == hover, not _button_live(b[0]))
	# Where you are and what's chosen (how far it moved, its size), then how to work it.
	var line: String = String(TEXT["crumb"]).join(crumbs())
	var bad := false
	if _exists(sel):
		var ro := readout(sel)
		line += TEXT["crumb"] + label_of(sel) + "   —   " + ro[0] + TEXT["dot"] + ro[1]
		var hit := clashes(sel)
		if not hit.is_empty():
			bad = true
			line += TEXT["dot"] + TEXT["overlaps"] % label_of(hit[0])
	else:
		line += "   —   " + TEXT["none"]
	var tr: Rect2 = tb["text"]
	var tall: bool = tb["tall"]
	var hint: String = TEXT["hint_touch"] if main.touch_active else (Controls.pad_text(TEXT["hint_pad"], main.pad_ps) if main.pad_active else (TEXT["hint_short"] if tall else TEXT["hint_keys"]))
	var steps := intro_steps()
	if intro >= 0 and intro < steps.size() and not list_showing():
		hint = TEXT["step"] % [intro + 1, steps.size(), steps[intro]]  # (no list to show the three steps in)
	if tall and list_showing():
		# (the list beside it says where you are and what's chosen)
		draw_multiline_string(body, tr.position + Vector2(0.0, 13.0), hint, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 11, 3, UI.DIM)
		return
	line = _fit_left(mono, line, 11, tr.size.x)
	draw_string(mono, tr.position + Vector2(0.0, 13.0), line, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 11, UI.BAD if bad else UI.TEXT)
	draw_multiline_string(body, tr.position + Vector2(0.0, 29.0), hint, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 11, 2 if tall else 1, UI.DIM)
