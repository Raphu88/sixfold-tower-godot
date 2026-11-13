extends Control
## The room painter (Dev tools -> Paint rooms): paint the game's hand-made
## rooms yourself, tile by tile, without code. A page of its own that fills
## the screen (menu.gd opens it as the page "painter" and leaves it the
## input):
##   - the grid: the room, drawn in the game's own tile look (painter_tiles.gd)
##     in the current tower's colours; tap, click or drag to paint;
##   - the tools down the left: brush, fill, box, eraser, mirror left-right
##     and top-bottom, undo and redo, zoom;
##   - the palette and the checks down the right: every tile, and what's
##     wrong with the room in plain words (room_check.gd), as you paint;
##   - the top bar: the room list, the room's settings, Save (and Copy /
##     Paste rooms), Try it and "?" (the Entity's explanation again).
## Built-in rooms (rooms.gd) can be opened and copied but not changed:
## painting one makes a copy. Your rooms are kept by room_store.gd, and the
## ones that pass the checks and are switched on join the floor planner's
## pool for their job.
##
## Input follows nav.gd's rules for the buttons. On the grid:
##   keys       arrows move the cursor, Enter or Space paints, Delete or
##              Backspace erases, Q / E switch the tile, Tab goes to the
##              buttons, Ctrl+Z / Ctrl+Y undo and redo, Esc leaves
##   controller the d-pad or stick moves the cursor, A paints, B erases,
##              LB / RB switch the tile, X the tool, Y goes to the buttons,
##              Start leaves
##   mouse      click or drag to paint, right-click erases, the wheel zooms,
##              the middle button drags the view
##   touch      tap or drag to paint, two fingers zoom and move the view

const Rooms := preload("res://scripts/rooms.gd")
const Check := preload("res://scripts/room_check.gd")
const Store := preload("res://scripts/room_store.gd")
const Tiles := preload("res://scripts/painter_tiles.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Nav := preload("res://scripts/nav.gd")
const Controls := preload("res://scripts/controls.gd")

## Every word the painter says (easy to change).
const TEXT := {
	"dev_section": "Creator tools",
	"dev_button": "Paint rooms",
	"dev_note": "Paint the hand-made rooms yourself, try them at once, and switch them on for climbs.",
	"eyebrow": "Room painter",
	"back": "Back",
	"rooms": "Rooms",
	"room": "Room",
	"save": "Save",
	"try": "Try it",
	"help": "?",
	"job": {"start": "Start room", "combat": "Combat room", "stair": "Stair room", "puzzle": "Puzzle room"},
	"job_short": {"start": "Start", "combat": "Combat", "stair": "Stair", "puzzle": "Puzzle"},
	"builtin": "Built-in",
	"ready": "Ready",
	"draft": "Draft",
	"on": "In climbs",
	"off": "Not in climbs",
	"on_waits": "On, waiting for the checks",
	"toggle_on": "Use in climbs: on",
	"toggle_off": "Use in climbs: off",
	"all_good": "Every check passes.",
	"checks": "Checks",
	"tile_now": "Tile: %s",
	"tools": {"brush": "Brush", "fill": "Fill", "rect": "Box", "erase": "Eraser", "mirror_x": "Mirror", "mirror_y": "Mirror", "undo": "Undo", "redo": "Redo", "zoom_in": "Zoom", "zoom_out": "Zoom"},
	"tool_tips": {"brush": "Paint tile by tile", "fill": "Fill an area of the same tile", "rect": "Drag a box of the tile", "erase": "Paint floor",
		"mirror_x": "Mirror left and right", "mirror_y": "Mirror top and bottom", "undo": "Undo", "redo": "Redo", "zoom_in": "Zoom in", "zoom_out": "Zoom out"},
	"copy_made": "Built-in rooms stay as they are: you're painting a copy, \"%s\".",
	"hint_keys": "Arrows move   Enter paints   Del erases   Q / E tile   Tab buttons   Esc leaves",
	"hint_pad": "{a} paints   {b} erases   {lb} / {rb} tile   {x} tool   {y} buttons   {start} leaves",
	"hint_touch": "Tap or drag to paint. Two fingers zoom and move the view.",
	"hint_mouse": "Click or drag to paint. Right-click erases. The wheel zooms.",
	"builtin_hint": "A built-in room: painting makes your own copy.",
	"hint_buttons_keys": "Buttons: arrows move, Enter presses, Tab or Esc back to the grid",
	"hint_buttons_pad": "Buttons: {a} presses, {y} or {b} back to the grid",
	# The room list.
	"list_title": "Rooms",
	"list_sub": "Open a room to paint it. Built-in rooms can be copied, not changed.",
	"yours": "Your rooms",
	"none_yet": "None yet. Copy a built-in room, or make a new one.",
	"builtins": "Built-in rooms",
	"new": "New room",
	"open": "Open",
	"copy": "Copy",
	"rename": "Rename",
	"delete": "Delete",
	"delete_again": "{again} to delete",
	"turn_on": "Off",
	"turn_off": "On",
	"deleted": "Deleted \"%s\".",
	"copied_room": "Copied as \"%s\".",
	"new_name": "New room",
	"copy_name": "%s copy",
	# Settings.
	"settings_title": "Room settings",
	"settings_builtin": "Built-in rooms can't be changed. Copy it to make your own.",
	"copy_to_change": "Copy it",
	"name": "Name",
	"job_label": "Job",
	"puzzle_label": "Puzzle",
	"puzzles": {"eyes": "Hall of Eyes", "plates": "Weighing Room"},
	"tier_label": "Tier",
	"width": "Width",
	"height": "Height",
	"from": "First floor",
	"flip": "Flips in play",
	"flip_stair": "(stair rooms never flip)",
	"towers": "Towers",
	"all_towers": "All towers",
	"seen_in": "Shown as in",
	"yes": "Yes",
	"no": "No",
	# Saving and sharing.
	"share_title": "Save and share",
	"saves_project": "Running from Godot: Save writes data/rooms_custom.json in the project. Then in GitHub Desktop, write a summary, press Commit to main, then Push origin, and the rooms are in the game for good, the web build too.",
	"saves_device": "Save keeps your rooms on this device. To make them part of the game for everyone: press Copy rooms and paste the text to Claude, or paste it into Paste rooms on your computer (running from Godot) and Save there.",
	"copy_rooms": "Copy rooms",
	"paste_rooms": "Paste rooms",
	"show_text": "Show the text",
	"box_hint": "Your rooms as text appear here. To paste, put rooms text here, then press Paste rooms.",
	"saved_project": "Saved to data/rooms_custom.json. Now commit it in GitHub Desktop.",
	"saved_device": "Saved on this device.",
	"save_failed": "Couldn't save.",
	"copied": "Copied %d rooms. Paste them to Claude, or into Paste rooms on the computer.",
	"pasted": "Pasted: %d new, %d updated.",
	"paste_empty": "Nothing to paste: put rooms text in the box first.",
	"paste_prompt": "Paste your rooms here:",
	"copy_prompt": "Copy this text:",
	"unsaved": "Not saved yet",
	# Try it.
	"try_title": "TRYING YOUR ROOM",
	"try_back": "%s goes back to the painter (so does the stair).",
	"try_fail": "This room can't be tried: no side has room for a doorway.",
	"try_draft": "This room is a draft: it can be tried, but it won't be used in climbs until the checks pass.",
	# Help and tips.
	"help_title": "How the room painter works",
	"got_it": "Got it",
	"close": "Close",
	"rename_title": "Rename the room",
	"ok": "OK",
	"cancel": "Cancel",
}
## The tools down the left, in order (a pair to a row).
const TOOL_ORDER := ["brush", "fill", "rect", "erase", "mirror_x", "mirror_y", "undo", "redo", "zoom_out", "zoom_in"]
const PAINT_TOOLS := ["brush", "fill", "rect", "erase"]
const JOBS := ["start", "combat", "stair", "puzzle"]
## The Entity's tips about the painter (entity.gd), in the order "?" shows them.
const HELP_TIPS := ["painter", "painter_checks", "painter_try", "painter_climbs", "painter_save"]
const UNDO_MAX := 100
const ZOOM_MAX := 4.0
## A new room's size, in tiles.
const NEW_SIZE := Vector2i(13, 11)

var menu
var main

# --- the room open ---
var room := {}  # the room being painted (one of room_store.gd's rooms, or a copy of a built-in's)
var builtin := false  # it's a built-in (rooms.gd): painting it makes a copy
var tile := "#"  # the tile that paints
var tool := "brush"
var mirror_x := false
var mirror_y := false
var undo_stack: Array = []
var redo_stack: Array = []
var problems: Array = []  # room_check.gd's, for the tower shown
var picked := -1  # the problem whose tiles flash (tapped)
var view_tower := ""  # whose colours and rules the room is shown in

# --- the grid's view and cursor ---
var zoom := 1.0
var pan := Vector2.ZERO
var cursor := Vector2i(6, 5)
var on_grid := true  # keys and controller: the cursor is on the grid (else on the buttons)
var stroke := {}  # a paint stroke under way: {ch, last, before, changed}
var rect_from := Vector2i(-1, -1)  # the box tool's first corner
var hover := Vector2i(-1, -1)

# --- pages over the painter ---
var panel := ""  # "" (none), "rooms", "settings", "share", "help", "tip", "rename"
var panel_from: Control = null  # what opened it (the focus goes back there)
var tip_queue: Array = []
var armed := ""  # a room whose Delete was pressed once
var toast := ""
var toast_t := 0.0
var showing := false
var tried := false  # Try it was used: back from it, the Entity explains
var rep := Nav.Repeat.new()
var touches := {}  # finger -> position
var touch_mode := ""  # "paint", "tap", "pinch"
var touch_from := Vector2.ZERO
var touch_moved := 0.0
var pinch := {}
var _rclick_grid := false
var _a_held := false  # A, Enter or Space held on the grid (painting as the cursor moves)
var _b_held := false  # B, Delete or Backspace held (erasing as it moves)

# --- nodes ---
var bg: ColorRect
var top: HBoxContainer
var title_l: Label
var status_l: Label
var top_buttons := {}
var tools_grid: GridContainer
var tool_buttons := {}
var grid_view: GridView
var hint_l: Label
var toast_l: Label
var side: VBoxContainer
var tile_l: Label
var palette: GridContainer
var palette_scroll: ScrollContainer
var tile_buttons := {}
var climbs_btn: Button
var checks_l: Label
var checks_box: VBoxContainer
var checks_scroll: ScrollContainer
var overlay: Control
var sheet: PanelContainer
var sheet_title: Label
var sheet_scroll: ScrollContainer
var sheet_box: VBoxContainer
var sheet_foot: HBoxContainer
var text_box: TextEdit
var name_edit: LineEdit


## Dev tools: the "Creator tools" section with the painter's button.
static func dev_section(m) -> void:
	m._section(TEXT["dev_section"])
	var row: HBoxContainer = m._row()
	var b: Button = m._button(TEXT["dev_button"], m.open.bind("painter"), row)
	b.set_meta("setting", "painter")
	b.custom_minimum_size.x = 200.0
	m._primary(b)
	m._note(TEXT["dev_note"])


func _ready() -> void:
	main = menu.main if menu != null else null
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(func(): if visible: _relayout())
	hide()


# --- building the page -------------------------------------------------------------

func _build() -> void:
	bg = ColorRect.new()
	bg.color = UI.VOID
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	# The top bar.
	top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	top_buttons["back"] = _btn(TEXT["back"], _leave, top)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", -4)
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tcol)
	title_l = Label.new()
	UI.keep_text(title_l)  # (its words whole: smaller, then wrapped, never cut)
	tcol.add_child(title_l)
	status_l = Label.new()
	UI.keep_text(status_l)  # (its words whole: smaller, then wrapped, never cut)
	tcol.add_child(status_l)
	top_buttons["rooms"] = _btn(TEXT["rooms"], open_panel.bind("rooms"), top)
	top_buttons["room"] = _btn(TEXT["room"], open_panel.bind("settings"), top)
	top_buttons["save"] = _btn(TEXT["save"], open_panel.bind("share"), top)
	top_buttons["try"] = _btn(TEXT["try"], try_it, top)
	top_buttons["help"] = _btn(TEXT["help"], open_panel.bind("help"), top)
	for k in top_buttons:
		top_buttons[k].set_meta("painter", "top_" + k)
	# The body: tools, the grid, the palette and checks.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	tools_grid = GridContainer.new()
	tools_grid.columns = 2
	tools_grid.add_theme_constant_override("h_separation", 4)
	tools_grid.add_theme_constant_override("v_separation", 4)
	tools_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(tools_grid)
	for id in TOOL_ORDER:
		var tb := ToolButton.new()
		tb.kind = id
		tb.caption = TEXT["tools"][id]
		tb.tooltip_text = TEXT["tool_tips"][id]
		tb.set_meta("painter", "tool_" + id)
		tb.pressed.connect(_tool_pressed.bind(id))
		tools_grid.add_child(tb)
		tool_buttons[id] = tb
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(mid)
	grid_view = GridView.new()
	grid_view.p = self
	grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(grid_view)
	hint_l = Label.new()
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.keep_text(hint_l)  # (its words whole: smaller, then wrapped, never cut)
	mid.add_child(hint_l)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(side)
	tile_l = Label.new()
	tile_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(tile_l)
	palette_scroll = ScrollContainer.new()
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.follow_focus = true
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(palette_scroll)
	palette = GridContainer.new()
	palette.columns = 2
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_theme_constant_override("h_separation", 4)
	palette.add_theme_constant_override("v_separation", 4)
	palette_scroll.add_child(palette)
	for t in Tiles.TILES:
		var b := TileButton.new()
		b.p = self
		b.ch = t[0]
		b.label = t[1]
		b.tooltip_text = t[2]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("painter", "tile_" + t[0])
		b.pressed.connect(pick_tile.bind(t[0]))
		palette.add_child(b)
		tile_buttons[t[0]] = b
	climbs_btn = _btn(TEXT["toggle_off"], toggle_climbs, side)
	climbs_btn.set_meta("painter", "climbs")
	checks_l = Label.new()
	side.add_child(checks_l)
	checks_scroll = ScrollContainer.new()
	checks_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	checks_scroll.follow_focus = true
	checks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(checks_scroll)
	checks_box = VBoxContainer.new()
	checks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checks_box.add_theme_constant_override("separation", 2)
	checks_scroll.add_child(checks_box)
	# The toast, over the grid's foot.
	toast_l = Label.new()
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb_style := UI.box(Color(UI.ENTITY_BG, 0.95), UI.ENTITY_EDGE, 6, 1, 8.0)
	toast_l.add_theme_stylebox_override("normal", tb_style)
	toast_l.hide()
	add_child(toast_l)
	# The pages over it (the room list, settings, saving, help, the Entity).
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = UI.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UI.menu_panel())
	overlay.add_child(sheet)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 6)
	sheet.add_child(scol)
	sheet_title = Label.new()
	scol.add_child(sheet_title)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.follow_focus = true
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scol.add_child(sheet_scroll)
	sheet_box = VBoxContainer.new()
	sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_box.add_theme_constant_override("separation", 6)
	sheet_scroll.add_child(sheet_box)
	sheet_foot = HBoxContainer.new()
	sheet_foot.alignment = BoxContainer.ALIGNMENT_END
	sheet_foot.add_theme_constant_override("separation", 8)
	scol.add_child(sheet_foot)


func _btn(text: String, action: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _lbl(text: String, parent: Node, size := UI.SIZE_BODY, col := UI.TEXT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120.0
	parent.add_child(l)
	return l


## A phone (or a short window): smaller type and buttons.
func small() -> bool:
	return is_inside_tree() and get_viewport_rect().size.y < 600.0


## Sizes everything for the screen: the grid gets most of it.
func _relayout() -> void:
	var sm := small()
	var vs := get_viewport_rect().size
	var m: MarginContainer = get_node("Margin")
	for side_name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side_name, 6 if sm else 12)
	var fs := 15 if sm else 17
	var bh := 32.0 if sm else 38.0
	for k in top_buttons:
		var b: Button = top_buttons[k]
		b.add_theme_font_size_override("font_size", fs)
		b.custom_minimum_size = Vector2(36.0 if k == "help" else (0.0), bh)
	UI.style_label(title_l, "display", 20 if sm else 26, UI.GOLD)
	UI.style_label(status_l, "body", 13 if sm else 14, UI.DIM)
	var ts := Vector2(44, 42) if sm else Vector2(56, 52)
	for id in tool_buttons:
		tool_buttons[id].custom_minimum_size = ts
	var sw := clampf(vs.x * 0.24, 196.0, 300.0)
	side.custom_minimum_size.x = sw
	var row_h := 32.0 if sm else 36.0
	for ch in tile_buttons:
		tile_buttons[ch].custom_minimum_size = Vector2(0, row_h)
	climbs_btn.add_theme_font_size_override("font_size", fs - 1)
	climbs_btn.custom_minimum_size.y = bh
	UI.style_label(tile_l, "body", 13 if sm else 14, UI.DIM)
	UI.style_label(checks_l, "eyebrow", 14 if sm else 15, UI.GOLD)
	UI.style_label(hint_l, "body", 12 if sm else 13, UI.FAINT)
	# The palette as tall as it needs, leaving the checks room to show.
	var rows := ceili(Tiles.TILES.size() / 2.0)
	var avail := vs.y - bh - (6.0 if sm else 12.0) * 2.0 - 6.0
	var tile_h := 20.0 if sm else 44.0
	var room_for := avail - tile_h - bh - 22.0 - (90.0 if sm else 150.0) - 20.0
	palette_scroll.size_flags_vertical = Control.SIZE_FILL
	palette_scroll.custom_minimum_size.y = clampf(room_for, row_h * 3.0, rows * (row_h + 4.0))
	# The page over it: as big as the screen allows.
	var pw := minf(vs.x - 24.0, 720.0)
	var ph := vs.y - (16.0 if sm else 40.0)
	if panel == "tip" or panel == "rename":
		# A word from the Entity, or a name: only as big as it needs.
		pw = minf(pw, 600.0)
		ph = minf(ph, sheet.get_combined_minimum_size().y + sheet_box.get_combined_minimum_size().y + 10.0)
	sheet.position = Vector2((vs.x - pw) * 0.5, (vs.y - ph) * 0.5)
	sheet.size = Vector2(pw, ph)
	sheet_scroll.custom_minimum_size = Vector2(pw - 48.0, 0)
	UI.style_label(sheet_title, "display", 22 if sm else 28, UI.GOLD)
	var tw := minf(vs.x * 0.6, 560.0)
	toast_l.custom_minimum_size.x = tw
	toast_l.size = Vector2(tw, 0)
	toast_l.reset_size()
	toast_l.position = Vector2((vs.x - toast_l.size.x) * 0.5, vs.y - toast_l.size.y - (40.0 if sm else 56.0))
	UI.style_label(toast_l, "body", 13 if sm else 15, Entity.GLOW.lerp(Color.WHITE, 0.55))


# --- opening and leaving ------------------------------------------------------------

## The page opens (menu.gd _page_painter), or is rebuilt for another input.
func enter() -> void:
	main = menu.main
	var first := not showing
	showing = true
	show()
	if main != null and main.trying_room():
		main.end_try()  # (back from Try it: the floor you were on is laid out again)
		tried = true
		first = true
	if first:
		view_tower = main.tower if main != null else Towers.ORDER[0]
		if room.is_empty():
			var list: Array = Store.rooms
			if not list.is_empty():
				open_room(list[0]["id"])
			else:
				open_room(Rooms.ROOMS[0]["id"])
		else:
			_refresh()
		if overlay.visible and panel != "tip":
			close_panel()
		rep.reset()
		_go_grid()
	_relayout()
	_refresh()
	if first:
		var said: String = main.tip_now("painter") if main != null else ""
		if said != "":
			show_tip(said)
		if tried:
			tried = false
			var t: String = main.tip_now("painter_try") if main != null else ""
			if t != "":
				show_tip(t)


## Back to the Dev tools page (what isn't saved yet is saved first).
func _leave() -> void:
	_end_stroke()
	if Store.dirty:
		Store.save()
	showing = false
	if main != null:
		main.sfx("ui_back")
	menu._back_frame = Engine.get_process_frames()  # (the Esc that did this doesn't go back again)
	menu._returning = true  # (the focus goes back to Paint rooms)
	menu.open("dev")
	menu._returning = false


func _process(delta: float) -> void:
	if menu == null:
		return
	if menu.page != "painter":
		if visible:
			hide()
		showing = false
		return
	if not visible:
		show()
	toast_t -= Nav.real_delta(delta)
	if toast_t <= 0.0 and toast_l.visible:
		toast_l.hide()
	if _typing():
		return
	# Start: back a level (out of a page, or out of the painter).
	if Input.is_action_just_pressed("pause") and not Input.is_key_pressed(KEY_ESCAPE) and not Input.is_key_pressed(KEY_P):
		_back()
		return
	rep.update()
	for a in Nav.DIRS:
		if rep.pulse(a):
			_dir(a)
	# The right stick scrolls a page.
	var rs := Nav.stick_scroll()
	if absf(rs) > 0.2:
		var sc := sheet_scroll if overlay.visible else checks_scroll
		sc.scroll_vertical += int(rs * Nav.SCROLL_SPEED * delta)


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


# --- input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or menu == null or menu.page != "painter":
		return
	var pad = main.pad if main != null else null
	if _typing():
		# A text box: Esc or B only leave it.
		if event.is_action_pressed("ui_cancel"):
			get_viewport().gui_release_focus()
			_focus_first()
			get_viewport().set_input_as_handled()
		return
	var joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if joy and event.device != Controls.PAD_DEVICE:
		return  # (pad.gd puts a real controller into the standard layout and sends it on)
	if Nav.is_dir_event(event):
		if pad != null:
			pad._input(event)  # (it still notices which device is in use)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Nav.mouse_moved(event):
		_hover(event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_XBUTTON1:
			var on_g := not overlay.visible and grid_view.get_global_rect().has_point(event.position)
			if event.pressed:
				_rclick_grid = on_g and event.button_index == MOUSE_BUTTON_RIGHT
			elif not _rclick_grid:
				_back()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		_pad_button(event)
		return
	if event is InputEventKey:
		if _key(event):
			if pad != null:
				pad._input(event)
			get_viewport().set_input_as_handled()


## A controller button (the standard layout). Not marked handled: pad.gd
## still sees it (which device is in use, Start), and A presses the focused button.
func _pad_button(e: InputEventJoypadButton) -> void:
	var b := e.button_index
	if overlay.visible:
		if e.pressed and b == JOY_BUTTON_B:
			_back()
		elif e.pressed and (b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER):
			pass
		return
	if b == JOY_BUTTON_Y and e.pressed:
		_toggle_buttons()
		return
	if b == JOY_BUTTON_LEFT_SHOULDER and e.pressed:
		cycle_tile(-1)
		return
	if b == JOY_BUTTON_RIGHT_SHOULDER and e.pressed:
		cycle_tile(1)
		return
	if not on_grid:
		if e.pressed and b == JOY_BUTTON_B:
			_go_grid()
		return
	match b:
		JOY_BUTTON_A:
			_grid_press(e.pressed, false)
		JOY_BUTTON_B:
			_grid_press(e.pressed, true)
		JOY_BUTTON_X:
			if e.pressed:
				cycle_tool()


## A key. True if the painter used it.
func _key(e: InputEventKey) -> bool:
	if e.echo:
		return e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_DELETE, KEY_BACKSPACE]
	var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	if e.pressed and e.ctrl_pressed and code == KEY_Z:
		if e.shift_pressed:
			do_redo()
		else:
			do_undo()
		return true
	if e.pressed and e.ctrl_pressed and code == KEY_Y:
		do_redo()
		return true
	if code == KEY_ESCAPE:
		if e.pressed:
			if not overlay.visible and not on_grid:
				_go_grid()
			else:
				_back()
		return true
	if overlay.visible:
		return false  # (Enter presses the focused button)
	if code == KEY_TAB:
		if e.pressed:
			_toggle_buttons()
		return true
	if code == KEY_Q or code == KEY_E:
		if e.pressed:
			cycle_tile(1 if code == KEY_E else -1)
		return true
	if not on_grid:
		return false
	if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_grid_press(e.pressed, false)
		return true
	if code in [KEY_DELETE, KEY_BACKSPACE]:
		_grid_press(e.pressed, true)
		return true
	return false


## A or Enter (paint), B or Delete (erase), pressed or let go on the grid.
func _grid_press(down: bool, erase: bool) -> void:
	if down:
		if erase:
			_b_held = true
		else:
			_a_held = true
		begin_stroke(cursor, erase)
	else:
		if erase:
			_b_held = false
		else:
			_a_held = false
		if not _a_held and not _b_held:
			end_stroke()


## The arrows, the d-pad or the stick: the cursor on the grid, or the focus.
func _dir(a: String) -> void:
	var d: Vector2i = {"ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN, "ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT}[a]
	if not overlay.visible and on_grid:
		var sz := size_of()
		var c := Vector2i(clampi(cursor.x + d.x, 0, sz.x - 1), clampi(cursor.y + d.y, 0, sz.y - 1))
		if c != cursor:
			cursor = c
			if not stroke.is_empty():
				continue_stroke(cursor)
			grid_view.show_tile(cursor)
			grid_view.queue_redraw()
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	var list := focusables()
	if f == null or not f in list:
		_focus_first()
		return
	var n := _neighbour(f, Vector2(d), list)
	if n != null:
		n.grab_focus()
	elif not overlay.visible:
		# Off the buttons toward the grid: back onto it.
		var g := grid_view.get_global_rect()
		var fc := f.get_global_rect().get_center()
		var toward := (d.x > 0 and fc.x < g.position.x) or (d.x < 0 and fc.x > g.end.x) or (d.y > 0 and fc.y < g.position.y)
		if toward:
			_go_grid()


## The nearest of `list` from `f` in direction `d` (nav.gd: grids stop at their edges).
func _neighbour(f: Control, d: Vector2, list: Array) -> Control:
	var from := f.get_global_rect().get_center()
	var best: Control = null
	var best_s := INF
	for c in list:
		if c == f or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var v := r.get_center() - from
		var along := v.dot(d)
		if along < 4.0:
			continue
		var across := absf(v.dot(Vector2(d.y, d.x)))
		# (overlapping rows or columns first)
		var overlap := (r.position.y < f.get_global_rect().end.y and r.end.y > f.get_global_rect().position.y) if d.x != 0 else (r.position.x < f.get_global_rect().end.x and r.end.x > f.get_global_rect().position.x)
		var s := along + across * (0.5 if overlap else 3.0) + (0.0 if overlap else 200.0)
		if s < best_s:
			best_s = s
			best = c
	return best


## What the keys and controller can focus now: the page's buttons over the
## painter, or the painter's own.
func focusables() -> Array:
	var root: Node = sheet if overlay.visible else self
	var out: Array = []
	_collect(root, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c == overlay and not overlay.visible:
			continue
		if c is Control and not c.is_visible_in_tree():
			continue
		if (c is BaseButton or c is LineEdit or c is TextEdit) and c.focus_mode != Control.FOCUS_NONE:
			out.append(c)
		else:
			_collect(c, out)


func _focus_first() -> void:
	var list := focusables()
	if list.is_empty():
		return
	var want: Control = list[0]
	if not overlay.visible:
		want = top_buttons["rooms"]
	elif panel == "share" and text_box != null and list.size() > 1:
		want = list[0] if not list[0] is TextEdit else list[1]
	want.grab_focus()


## Y or Tab: from the grid to the buttons, and back.
func _toggle_buttons() -> void:
	_end_stroke()
	if on_grid:
		on_grid = false
		_focus_first()
		if main != null:
			main.sfx("ui_move")
	else:
		_go_grid()
	_refresh_hint()


func _go_grid() -> void:
	on_grid = true
	if is_inside_tree():
		get_viewport().gui_release_focus()
	_refresh_hint()
	grid_view.queue_redraw()


## Esc, B, a right-click or Start: back one level.
func _back() -> void:
	_end_stroke()
	if overlay.visible:
		if main != null:
			main.sfx("ui_back")
		close_panel()
		return
	if not on_grid and not (main != null and main.touch_active):
		_go_grid()
		return
	_leave()


## The mouse moving over a button gives it the focus (one highlight).
func _hover(pos: Vector2) -> void:
	if main != null and main.touch_active:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	if f is LineEdit or f is TextEdit:
		return
	var c := Nav.topmost_at(focusables(), pos)
	if c != null and c != f and not (c is LineEdit or c is TextEdit):  # (a text box takes the keys only when chosen)
		on_grid = false
		c.grab_focus()
		_refresh_hint()


## Touch: a tap presses a button; a drag on the grid paints; a drag
## elsewhere scrolls; two fingers on the grid zoom and move the view.
func _touch(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
			if touches.size() == 1:
				touch_from = e.position
				touch_moved = 0.0
				if not overlay.visible and grid_view.get_global_rect().has_point(e.position):
					touch_mode = "paint"
					var t := grid_view.tile_at(grid_view.get_global_transform().affine_inverse() * e.position)
					if t.x >= 0:
						cursor = t
						begin_stroke(t, false)
				else:
					touch_mode = "tap"
			elif touches.size() == 2 and touch_mode != "tap":
				# Two fingers: what the first one painted is taken back.
				cancel_stroke()
				touch_mode = "pinch"
				var ps: Array = touches.values()
				pinch = {"d": maxf(ps[0].distance_to(ps[1]), 1.0), "zoom": zoom, "mid": (ps[0] + ps[1]) * 0.5, "pan": pan}
		else:
			touches.erase(e.index)
			if touch_mode == "paint":
				end_stroke()
				touch_mode = ""
			elif touch_mode == "tap" and touches.is_empty():
				if touch_moved < 14.0:
					_tap(e.position)
				touch_mode = ""
			elif touches.is_empty():
				touch_mode = ""
			if touches.is_empty() and main != null and main.touch != null and not main.touch.active:
				main.touch._set_active(true)  # (the phone layout, after the tap)
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		touch_moved += e.relative.length()
		match touch_mode:
			"paint":
				var t := grid_view.tile_at(grid_view.get_global_transform().affine_inverse() * e.position)
				if t.x >= 0 and t != cursor:
					cursor = t
					continue_stroke(t)
			"pinch":
				if touches.size() >= 2:
					var ps: Array = touches.values()
					var d: float = ps[0].distance_to(ps[1])
					var mid: Vector2 = (ps[0] + ps[1]) * 0.5
					zoom = clampf(float(pinch["zoom"]) * d / float(pinch["d"]), 1.0, ZOOM_MAX)
					pan = pinch["pan"] + (mid - pinch["mid"])
					grid_view.queue_redraw()
			"tap":
				if touch_moved >= 14.0:
					var sc := _scroll_at(touch_from)
					if sc != null:
						sc.scroll_vertical -= int(e.relative.y)


func _scroll_at(pos: Vector2) -> ScrollContainer:
	for sc in ([sheet_scroll] if overlay.visible else [palette_scroll, checks_scroll]):
		if sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			return sc
	return null


## A tap presses the button under it (or opens a text box).
func _tap(pos: Vector2) -> void:
	var c := Nav.topmost_at(focusables(), pos)
	if c == null:
		return
	if c is LineEdit or c is TextEdit:
		_edit_text(c)
		return
	var b: BaseButton = c
	if b.disabled:
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()


## A text box on a phone in the browser: the browser's own box (its keyboard
## and paste work there); elsewhere the box takes the keys.
func _edit_text(c: Control) -> void:
	if OS.has_feature("web") and main != null and main.touch_active:
		var ask: String = TEXT["paste_prompt"] if c == text_box else TEXT["rename_title"]
		var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(ask), JSON.stringify(c.text if c is LineEdit else "")], true)
		if v != null:
			c.text = str(v)
			if c == name_edit:
				_rename_done()
		return
	c.grab_focus()


# --- the room ------------------------------------------------------------------------

## Opens a room by id: one of yours, or a built-in (shown as it is).
func open_room(id: String) -> void:
	_end_stroke()
	var mine := Store.find(id)
	if not mine.is_empty():
		room = mine
		builtin = false
	else:
		for r in Rooms.ROOMS:
			if r["id"] == id:
				room = _from_builtin(r)
				builtin = true
	undo_stack.clear()
	redo_stack.clear()
	picked = -1
	var sz := size_of()
	cursor = Vector2i(clampi(cursor.x, 0, sz.x - 1), clampi(cursor.y, 0, sz.y - 1))
	zoom = 1.0
	pan = Vector2.ZERO
	_refresh()


## A built-in room as the painter holds one (a fresh copy: never the original).
func _from_builtin(r: Dictionary) -> Dictionary:
	var out := {"id": r["id"], "name": Store.display_name(r), "role": r["role"], "from": int(r["from"]), "flip": bool(r.get("flip", false)),
		"towers": [], "on": true, "grid": r["grid"].duplicate()}
	if r.has("puzzle"):
		out["puzzle"] = r["puzzle"]
		out["tier"] = int(r.get("tier", 1))
	return out


func size_of() -> Vector2i:
	var g: Array = room.get("grid", [""])
	return Vector2i(String(g[0]).length() if not g.is_empty() else 0, g.size())


func tile_at(t: Vector2i) -> String:
	var g: Array = room.get("grid", [])
	if t.y < 0 or t.y >= g.size() or t.x < 0 or t.x >= String(g[t.y]).length():
		return ""
	return String(g[t.y])[t.x]


## A built-in is about to change: it becomes a copy of your own first.
func _own() -> void:
	if not builtin:
		return
	var copy := room.duplicate(true)
	copy["id"] = ""
	copy["name"] = Store.free_name(TEXT["copy_name"] % room["name"])
	copy["on"] = false
	room = Store.add(copy)
	builtin = false
	say(TEXT["copy_made"] % room["name"])


func _snap() -> Dictionary:
	var s := room.duplicate(true)
	s.erase("id")
	s.erase("on")
	return s


func _push_undo() -> void:
	undo_stack.append(_snap())
	if undo_stack.size() > UNDO_MAX:
		undo_stack.pop_front()
	redo_stack.clear()


func _restore(s: Dictionary) -> void:
	for k in s:
		room[k] = s[k].duplicate(true) if (s[k] is Array or s[k] is Dictionary) else s[k]
	for k in ["puzzle", "tier"]:
		if not s.has(k):
			room.erase(k)
	var sz := size_of()
	cursor = Vector2i(clampi(cursor.x, 0, sz.x - 1), clampi(cursor.y, 0, sz.y - 1))
	_changed()


func do_undo() -> void:
	_end_stroke()
	if undo_stack.is_empty():
		return
	redo_stack.append(_snap())
	_restore(undo_stack.pop_back())
	if main != null:
		main.sfx("ui_back")


func do_redo() -> void:
	_end_stroke()
	if redo_stack.is_empty():
		return
	undo_stack.append(_snap())
	_restore(redo_stack.pop_back())
	if main != null:
		main.sfx("ui_confirm")


## The room changed: checks again, back into play (or out), redrawn.
func _changed() -> void:
	if not builtin:
		Store.changed()
	_refresh()


## Sets one tile (and its mirror images). True if anything changed.
func _put(t: Vector2i, ch: String) -> bool:
	var sz := size_of()
	var spots := {t: true}
	if mirror_x:
		spots[Vector2i(sz.x - 1 - t.x, t.y)] = true
	if mirror_y:
		spots[Vector2i(t.x, sz.y - 1 - t.y)] = true
	if mirror_x and mirror_y:
		spots[Vector2i(sz.x - 1 - t.x, sz.y - 1 - t.y)] = true
	var did := false
	for s in spots:
		if s.x < 0 or s.y < 0 or s.x >= sz.x or s.y >= sz.y:
			continue
		var row: String = room["grid"][s.y]
		if row[s.x] == ch:
			continue
		room["grid"][s.y] = row.substr(0, s.x) + ch + row.substr(s.x + 1)
		did = true
	return did


## Paints one tile with the current tile (tests and the simplest uses).
func paint(t: Vector2i, ch := "") -> void:
	begin_stroke(t, false, ch)
	end_stroke()


## A stroke starts at `t`: with the tool in hand (`erase`: floor, as a brush).
func begin_stroke(t: Vector2i, erase := false, ch := "") -> void:
	_end_stroke()
	var sz := size_of()
	if t.x < 0 or t.y < 0 or t.x >= sz.x or t.y >= sz.y:
		return
	_own()
	var use := "brush" if erase else tool
	var paint_ch := "." if erase or tool == "erase" else (ch if ch != "" else tile)
	stroke = {"ch": paint_ch, "tool": use, "last": t, "before": _snap(), "changed": false}
	match use:
		"brush", "erase":
			stroke["changed"] = _put(t, paint_ch)
		"fill":
			stroke["changed"] = _fill(t, paint_ch)
		"rect":
			rect_from = t
	if stroke["changed"]:
		_paint_feedback()


## The stroke moves on to `t` (a line from the last tile, so no gaps).
func continue_stroke(t: Vector2i) -> void:
	if stroke.is_empty():
		return
	var sz := size_of()
	t = Vector2i(clampi(t.x, 0, sz.x - 1), clampi(t.y, 0, sz.y - 1))
	match String(stroke["tool"]):
		"brush", "erase":
			var a: Vector2i = stroke["last"]
			var n := maxi(absi(t.x - a.x), absi(t.y - a.y))
			var did := false
			for i in range(1, n + 1):
				var p := Vector2(a).lerp(Vector2(t), float(i) / n).round()
				did = _put(Vector2i(p), stroke["ch"]) or did
			if did:
				stroke["changed"] = true
				_paint_feedback()
		"rect":
			grid_view.queue_redraw()
	stroke["last"] = t
	cursor = t


## The stroke ends: the box is laid; one step to undo.
func end_stroke() -> void:
	if stroke.is_empty():
		return
	if stroke["tool"] == "rect" and rect_from.x >= 0:
		var a := rect_from
		var b: Vector2i = stroke["last"]
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				stroke["changed"] = _put(Vector2i(x, y), stroke["ch"]) or stroke["changed"]
	rect_from = Vector2i(-1, -1)
	if stroke["changed"]:
		undo_stack.append(stroke["before"])
		if undo_stack.size() > UNDO_MAX:
			undo_stack.pop_front()
		redo_stack.clear()
		stroke = {}
		_changed()
		if main != null:
			main.sfx("ui_confirm", 1.2, -8.0)
		_tip_checks()
	else:
		stroke = {}
		grid_view.queue_redraw()


func _end_stroke() -> void:
	_a_held = false
	_b_held = false
	end_stroke()


## Two fingers arrived: what the first painted is taken back.
func cancel_stroke() -> void:
	if stroke.is_empty():
		return
	var before: Dictionary = stroke["before"]
	stroke = {}
	rect_from = Vector2i(-1, -1)
	for k in before:
		room[k] = before[k]
	_refresh()


func _paint_feedback() -> void:
	problems = _all_problems()
	_refresh_checks()
	grid_view.queue_redraw()


## Fills the area of the same tile around `t` (and its mirror images).
func _fill(t: Vector2i, ch: String) -> bool:
	var sz := size_of()
	var starts: Array = [t]
	if mirror_x:
		starts.append(Vector2i(sz.x - 1 - t.x, t.y))
	if mirror_y:
		starts.append(Vector2i(t.x, sz.y - 1 - t.y))
	if mirror_x and mirror_y:
		starts.append(Vector2i(sz.x - 1 - t.x, sz.y - 1 - t.y))
	var did := false
	for s in starts:
		var from := tile_at(s)
		if from == "" or from == ch:
			continue
		var todo: Array = [s]
		var seen := {s: true}
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			var row: String = room["grid"][c.y]
			room["grid"][c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)
			did = true
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if not seen.has(n) and tile_at(n) == from:
					seen[n] = true
					todo.append(n)
	return did


## Changes the room's size, keeping what's painted (new tiles are floor).
func resize_room(w: int, h: int) -> void:
	w = clampi(w, Check.MIN_SIZE.x, Check.MAX_SIZE.x)
	h = clampi(h, Check.MIN_SIZE.y, Check.MAX_SIZE.y)
	if Vector2i(w, h) == size_of():
		return
	_own()
	_push_undo()
	var g: Array = []
	for y in h:
		var row: String = room["grid"][y] if y < room["grid"].size() else ""
		row = row.substr(0, w)
		while row.length() < w:
			row += "."
		g.append(row)
	room["grid"] = g
	cursor = Vector2i(mini(cursor.x, w - 1), mini(cursor.y, h - 1))
	_changed()


func set_field(key: String, value) -> void:
	if room.get(key) == value:
		return
	_own()
	_push_undo()
	room[key] = value
	if key == "role":
		if value == "puzzle":
			room["puzzle"] = room.get("puzzle", "eyes")
			room["tier"] = room.get("tier", 1)
		else:
			room.erase("puzzle")
			room.erase("tier")
		if value == "stair":
			room["flip"] = false
	_changed()
	if panel == "settings":
		_rebuild_panel()


func toggle_tower(tid: String) -> void:
	_own()
	_push_undo()
	var list: Array = room.get("towers", []).duplicate()
	if tid == "":
		list = []
	elif tid in list:
		list.erase(tid)
	else:
		list.append(tid)
		if list.size() == Towers.ORDER.size():
			list = []
	room["towers"] = list
	_changed()
	if panel == "settings":
		_rebuild_panel()


## Use in climbs: on or off (a built-in is always in play).
func toggle_climbs() -> void:
	if builtin:
		say(TEXT["settings_builtin"])
		return
	room["on"] = not bool(room.get("on", false))
	Store.changed()
	_refresh()
	if main != null:
		main.sfx("ui_confirm")
	if room["on"]:
		var said: String = main.tip_now("painter_climbs") if main != null else ""
		if said != "":
			show_tip(said)
	if panel != "":
		_rebuild_panel()


func pick_tile(ch: String) -> void:
	tile = ch
	if tool == "erase":
		tool = "brush"
	if main != null:
		main.sfx("ui_move")
	_refresh_side()
	_refresh_tools()


## LB / RB, Q / E: the next tile in the palette.
func cycle_tile(by: int) -> void:
	var order: Array = Tiles.TILES.map(func(t): return t[0])
	pick_tile(order[(order.find(tile) + by + order.size()) % order.size()])
	if tile_buttons.has(tile):
		palette_scroll.ensure_control_visible(tile_buttons[tile])


## X: the next painting tool.
func cycle_tool() -> void:
	_tool_pressed(PAINT_TOOLS[(PAINT_TOOLS.find(tool) + 1) % PAINT_TOOLS.size()])


func _tool_pressed(id: String) -> void:
	match id:
		"mirror_x":
			mirror_x = not mirror_x
		"mirror_y":
			mirror_y = not mirror_y
		"undo":
			do_undo()
			return
		"redo":
			do_redo()
			return
		"zoom_in":
			set_zoom(zoom * 1.5)
		"zoom_out":
			set_zoom(zoom / 1.5)
		_:
			tool = id
	if main != null:
		main.sfx("ui_move")
	_refresh_tools()
	grid_view.queue_redraw()


func set_zoom(z: float, at := Vector2(-1, -1)) -> void:
	var old := zoom
	zoom = clampf(z, 1.0, ZOOM_MAX)
	if zoom <= 1.001:
		pan = Vector2.ZERO
	elif at.x >= 0.0:
		# Zoom about the point under the mouse.
		var c := grid_view.size * 0.5 + pan
		pan += (at - c) * (1.0 - zoom / old)
	if on_grid and at.x < 0.0:
		grid_view.show_tile(cursor)
	grid_view.queue_redraw()


# --- the rooms -----------------------------------------------------------------------

func new_room() -> void:
	var g: Array = []
	for y in NEW_SIZE.y:
		g.append(".".repeat(NEW_SIZE.x))
	var r := Store.add({"id": "", "name": Store.free_name(TEXT["new_name"]), "role": "combat", "from": Store.FROM["combat"], "flip": true,
		"towers": [], "on": false, "grid": g})
	open_room(r["id"])
	close_panel()


## Copies a room (yours or a built-in) as a new room of yours, and opens it.
func copy_room(id: String) -> void:
	var src := Store.find(id)
	if src.is_empty():
		for r in Rooms.ROOMS:
			if r["id"] == id:
				src = _from_builtin(r)
	if src.is_empty():
		return
	var copy := src.duplicate(true)
	copy["id"] = ""
	copy["name"] = Store.free_name(TEXT["copy_name"] % src["name"])
	copy["on"] = false
	var r := Store.add(copy)
	open_room(r["id"])
	say(TEXT["copied_room"] % r["name"])
	if panel == "rooms":
		_rebuild_panel()


func delete_room(id: String) -> void:
	if Store.find(id).is_empty():
		return
	var name: String = Store.find(id)["name"]
	Store.remove(id)
	armed = ""
	if room.get("id", "") == id:
		room = {}
		if not Store.rooms.is_empty():
			open_room(Store.rooms[0]["id"])
		else:
			open_room(Rooms.ROOMS[0]["id"])
	say(TEXT["deleted"] % name)
	if panel == "rooms":
		_rebuild_panel()


func _delete_pressed(id: String) -> void:
	if armed == id:
		delete_room(id)
	else:
		armed = id
		_rebuild_panel()


func rename_room(name: String) -> void:
	name = name.strip_edges()
	if name == "" or builtin:
		return
	_push_undo()
	room["name"] = name
	_changed()


# --- saving and sharing ----------------------------------------------------------------

func save_rooms() -> String:
	_end_stroke()
	var where := Store.save()
	if where == "":
		say(TEXT["save_failed"])
	else:
		say(TEXT["saved_project"] if where.begins_with("res://") else TEXT["saved_device"])
	_tip_save()
	_refresh()
	if panel == "share":
		_rebuild_panel()
	return where


func copy_rooms() -> String:
	var text := Store.export_text()
	DisplayServer.clipboard_set(text)
	if text_box != null and is_instance_valid(text_box):
		text_box.text = text
	say(TEXT["copied"] % Store.rooms.size())
	_tip_save()
	return text


## Paste rooms: from the box (or, if it's empty, the clipboard).
func paste_rooms(text := "") -> Dictionary:
	if text == "" and text_box != null and is_instance_valid(text_box):
		text = text_box.text
	if text.strip_edges() == "":
		text = DisplayServer.clipboard_get()
	if text.strip_edges() == "":
		say(TEXT["paste_empty"])
		return {"error": TEXT["paste_empty"]}
	var r := Store.import_text(text)
	if r["error"] != "":
		say(r["error"])
	else:
		say(TEXT["pasted"] % [r["added"], r["updated"]])
		if not r["ids"].is_empty():
			open_room(r["ids"][0])
	if panel != "":
		_rebuild_panel()
	return r


func _paste_pressed() -> void:
	if OS.has_feature("web") and main != null and main.touch_active and (text_box == null or text_box.text.strip_edges() == ""):
		var v = JavaScriptBridge.eval("window.prompt(%s, '')" % JSON.stringify(TEXT["paste_prompt"]), true)
		if v != null and str(v).strip_edges() != "":
			paste_rooms(str(v))
		return
	paste_rooms()


func _show_text() -> void:
	var text := Store.export_text()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(TEXT["copy_prompt"]), JSON.stringify(text.replace("\n", " ").replace("\t", ""))], true)
	elif text_box != null:
		text_box.text = text


# --- Try it ------------------------------------------------------------------------------

func try_it() -> bool:
	_end_stroke()
	if main == null or room.is_empty():
		return false
	var def := room.duplicate(true)
	if not main.try_room(def):
		say(TEXT["try_fail"])
		return false
	var key: String = "Menu" if main.touch_active else (Controls.pad_name("start", main.pad_ps) if main.pad_active else "Esc")
	main.banner = {"title": TEXT["try_title"], "lines": [String(room["name"]), TEXT["try_back"] % key], "t": 4.0}
	tried = true
	return true


# --- the Entity's tips -------------------------------------------------------------------

func show_tip(text: String) -> void:
	if panel == "tip" or (overlay.visible and panel != ""):
		tip_queue.append(text)
		return
	open_panel("tip", text)


func _tip_checks() -> void:
	if main == null or not problems.any(func(p): return p["level"] == "error"):
		return
	var said: String = main.tip_now("painter_checks")
	if said != "":
		show_tip(said)


func _tip_save() -> void:
	if main == null:
		return
	var said: String = main.tip_now("painter_save")
	if said != "":
		show_tip(said)


func say(text: String) -> void:
	toast = text
	toast_t = 4.0
	toast_l.text = text
	toast_l.show()
	_relayout()


# --- refreshing what shows ---------------------------------------------------------------

func _all_problems() -> Array:
	var tid := view_tower
	var out: Array = Check.problems(room, tid)
	# The other kind of tower, if the room may go there too (chasms differ).
	var other := "gryphon" if Towers.TOWERS.get(tid, {}).get("chasms", false) else "firebird"
	var allowed: Array = room.get("towers", [])
	if allowed.is_empty() or other in allowed:
		var seen: Array = out.map(func(p): return p["text"])
		var name: String = Towers.TOWERS[other]["short"] if other == "firebird" else "other"
		for p in Check.problems(room, other):
			if p["level"] == "error" and not p["text"] in seen:
				var q: Dictionary = p.duplicate()
				q["text"] = ("In the Firebird's tower: %s" if other == "firebird" else "In the other towers: %s") % p["text"]
				q["other"] = name
				out.append(q)
	return out + Check.notes(room)


func _refresh() -> void:
	if room.is_empty() or not is_inside_tree():
		return
	problems = _all_problems()
	var sz := size_of()
	title_l.text = String(room.get("name", ""))
	UI.style_label(title_l, "display", 20 if small() else 26, UI.GOLD)
	var bits: Array = [TEXT["job"][room.get("role", "combat")], "%d x %d" % [sz.x, sz.y]]
	if builtin:
		bits.append(TEXT["builtin"])
	else:
		bits.append(TEXT["ready"] if ready() else TEXT["draft"])
		bits.append(_climbs_word())
		if Store.dirty:
			bits.append(TEXT["unsaved"])
	status_l.text = "   ".join(PackedStringArray(bits))
	_refresh_tools()
	_refresh_side()
	_refresh_checks()
	_refresh_hint()
	grid_view.queue_redraw()


## The room passes in at least one tower it may appear in.
func ready() -> bool:
	return not Check.ok_towers(room).is_empty()


func _climbs_word() -> String:
	if builtin:
		return TEXT["on"]
	if not bool(room.get("on", false)):
		return TEXT["off"]
	return TEXT["on"] if ready() else TEXT["on_waits"]


func _refresh_tools() -> void:
	for id in tool_buttons:
		var b: ToolButton = tool_buttons[id]
		b.lit = (id == tool) or (id == "mirror_x" and mirror_x) or (id == "mirror_y" and mirror_y)
		b.disabled = (id == "undo" and undo_stack.is_empty()) or (id == "redo" and redo_stack.is_empty()) \
			or (id == "zoom_in" and zoom >= ZOOM_MAX - 0.01) or (id == "zoom_out" and zoom <= 1.001)
		b.queue_redraw()


func _refresh_side() -> void:
	tile_l.text = (TEXT["tile_now"] % Tiles.tile_name(tile)) + ("" if small() else "\n" + Tiles.tile_note(tile))
	for ch in tile_buttons:
		tile_buttons[ch].lit = ch == tile
		tile_buttons[ch].queue_redraw()
	climbs_btn.text = TEXT["toggle_on"] if bool(room.get("on", false)) and not builtin else TEXT["toggle_off"]
	if builtin:
		climbs_btn.text = TEXT["builtin"] + ": " + TEXT["on"]
	climbs_btn.add_theme_color_override("font_color", UI.GOOD if (bool(room.get("on", false)) and ready()) or builtin else UI.TEXT)


func _refresh_checks() -> void:
	var errors: int = problems.filter(func(p): return p["level"] == "error").size()
	checks_l.text = "%s: %s" % [TEXT["checks"], TEXT["ready"] if errors == 0 else "%s, %d" % [TEXT["draft"], errors]]
	checks_l.add_theme_color_override("font_color", UI.GOOD if errors == 0 else UI.BAD)
	for c in checks_box.get_children():
		checks_box.remove_child(c)
		c.queue_free()
	if problems.is_empty() or problems.all(func(p): return p["level"] == "info"):
		var ok := _lbl(TEXT["all_good"], checks_box, 12 if small() else 14, UI.GOOD)
		ok.set_meta("check", "ok")
	for i in problems.size():
		var p: Dictionary = problems[i]
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = ("x  " if p["level"] == "error" else ("!  " if p["level"] == "warn" else "")) + String(p["text"])
		b.add_theme_font_override("font", UI.font("body"))
		b.add_theme_font_size_override("font_size", 12 if small() else 14)
		var col: Color = UI.BAD if p["level"] == "error" else (UI.GILT if p["level"] == "warn" else UI.DIM)
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(k, col)
		b.set_meta("check", i)
		b.pressed.connect(_pick_problem.bind(i))
		checks_box.add_child(b)


func _pick_problem(i: int) -> void:
	picked = i if picked != i else -1
	if picked >= 0 and not problems[i]["tiles"].is_empty():
		cursor = problems[i]["tiles"][0]
		grid_view.show_tile(cursor)
	grid_view.queue_redraw()


func _refresh_hint() -> void:
	if main == null:
		return
	var text: String
	if main.touch_active:
		text = TEXT["hint_touch"]
	elif main.pad_active:
		text = Controls.pad_text(TEXT["hint_pad"] if on_grid else TEXT["hint_buttons_pad"], main.pad_ps)
	elif on_grid and menu.nav_keys:
		text = TEXT["hint_keys"]
	elif not on_grid and menu.nav_keys:
		text = TEXT["hint_buttons_keys"]
	else:
		text = TEXT["hint_mouse"]
	if builtin:
		text = TEXT["builtin_hint"] + "   " + text
	hint_l.text = text
	hint_l.add_theme_color_override("font_color", UI.GILT if builtin else UI.FAINT)


# --- the pages over the painter -------------------------------------------------------------

func open_panel(which: String, arg = null) -> void:
	_end_stroke()
	if panel == "":
		var f := get_viewport().gui_get_focus_owner()
		panel_from = f if f != null and is_ancestor_of(f) else null
	panel = which
	armed = ""
	overlay.show()
	_rebuild_panel(arg)
	if main != null:
		main.sfx("ui_open" if which != "tip" else "ui_move")
	if which == "share":
		_tip_save()
	if main == null or not main.touch_active:
		_focus_first.call_deferred()
	else:
		get_viewport().gui_release_focus()


func close_panel() -> void:
	overlay.hide()
	var was := panel
	panel = ""
	text_box = null
	name_edit = null
	for c in sheet_box.get_children() + sheet_foot.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	if not tip_queue.is_empty():
		open_panel("tip", tip_queue.pop_front())
		return
	if was != "" and is_instance_valid(panel_from) and panel_from.is_visible_in_tree() and not (main != null and main.touch_active):
		on_grid = false
		panel_from.grab_focus()
	elif not (main != null and main.touch_active) and not on_grid:
		_focus_first()
	_refresh()


var _tip_text := ""


func _rebuild_panel(arg = null) -> void:
	var f := get_viewport().gui_get_focus_owner()
	var keep := ""
	if f != null and sheet.is_ancestor_of(f):
		keep = String(f.get_meta("painter", f.text if f is Button else ""))
	var scroll_at := sheet_scroll.scroll_vertical
	for c in sheet_box.get_children() + sheet_foot.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	text_box = null
	name_edit = null
	match panel:
		"rooms":
			_page_rooms()
		"settings":
			_page_settings()
		"share":
			_page_share()
		"help":
			_page_help()
		"tip":
			if arg != null:
				_tip_text = str(arg)
			_page_tip(_tip_text)
		"rename":
			_page_rename()
	var close := _btn(TEXT["got_it"] if panel == "tip" else TEXT["close"], _close_pressed, sheet_foot)
	close.set_meta("painter", "close")
	close.custom_minimum_size.x = 110.0
	_relayout()
	_relayout.call_deferred()  # (again once the wrapped lines know their width)
	if keep != "":
		_refocus.call_deferred(keep, scroll_at)


func _close_pressed() -> void:
	if main != null:
		main.sfx("ui_back")
	close_panel()


func _refocus(meta: String, scroll_at: int) -> void:
	sheet_scroll.scroll_vertical = scroll_at
	if main != null and main.touch_active:
		return
	for c in focusables():
		if String(c.get_meta("painter", c.text if c is Button else "")) == meta:
			c.grab_focus()
			return


func _row(parent: Node = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	(parent if parent != null else sheet_box).add_child(r)
	return r


func _small_btn(text: String, action: Callable, parent: Node, meta: String) -> Button:
	var b := _btn(text, action, parent)
	b.add_theme_font_size_override("font_size", 14 if small() else 16)
	b.custom_minimum_size = Vector2(0, 32 if small() else 34)
	b.set_meta("painter", meta)
	return b


func _page_rooms() -> void:
	sheet_title.text = TEXT["list_title"]
	_lbl(TEXT["list_sub"], sheet_box, UI.SIZE_BODY, UI.DIM)
	var nr := _row()
	_small_btn(TEXT["new"], new_room, nr, "new")
	_section(TEXT["yours"])
	if Store.rooms.is_empty():
		_lbl(TEXT["none_yet"], sheet_box, UI.SIZE_BODY, UI.FAINT)
	for r in Store.rooms:
		_room_row(r, false)
	_section(TEXT["builtins"])
	for r in Rooms.ROOMS:
		_room_row(_from_builtin(r), true)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW + 1, Color(UI.GOLD, 0.82))
	sheet_box.add_child(l)


func _room_row(r: Dictionary, is_builtin: bool) -> void:
	var row := _row()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", -2)
	row.add_child(info)
	var current: bool = r["id"] == room.get("id", "")
	var nl := _lbl(String(r["name"]), info, 15 if small() else 17, UI.GOLD if current else UI.TEXT, false)
	UI.keep_text(nl)  # (its words whole: smaller, then wrapped, never cut)
	var sz := Rooms.size_of(r)
	var bits: Array = [TEXT["job_short"][r["role"]], "%d x %d" % [sz.x, sz.y]]
	if not is_builtin:
		bits.append(TEXT["ready"] if not Check.ok_towers(r).is_empty() else TEXT["draft"])
	var sl := _lbl("   ".join(PackedStringArray(bits)), info, 12 if small() else 13, UI.DIM, false)
	UI.keep_text(sl)  # (its words whole: smaller, then wrapped, never cut)
	var id: String = r["id"]
	_small_btn(TEXT["open"], _list_open.bind(id), row, "open_" + id)
	_small_btn(TEXT["copy"], copy_room.bind(id), row, "copy_" + id)
	if not is_builtin:
		var on: bool = bool(r.get("on", false))
		var tb := _small_btn(TEXT["turn_off"] if on else TEXT["turn_on"], _list_climbs.bind(id), row, "on_" + id)
		tb.add_theme_color_override("font_color", UI.GOOD if on else UI.DIM)
		_small_btn(TEXT["rename"], _list_rename.bind(id), row, "rename_" + id)
		var db := _small_btn(Nav.fill(TEXT["delete_again"], main) if armed == id else TEXT["delete"], _delete_pressed.bind(id), row, "delete_" + id)
		if armed == id:
			db.add_theme_color_override("font_color", UI.BAD)


func _list_open(id: String) -> void:
	open_room(id)
	close_panel()


func _list_climbs(id: String) -> void:
	open_room(id)
	toggle_climbs()


func _list_rename(id: String) -> void:
	open_room(id)
	open_panel("rename")


func _copy_it() -> void:
	copy_room(room["id"])
	_rebuild_panel()


## A setting's name, at the start of its row.
func _key_lbl(text: String, row: Node) -> void:
	var l := _lbl(text, row, UI.SIZE_BODY, UI.DIM, false)
	l.custom_minimum_size.x = 96.0 if small() else 120.0


func _page_settings() -> void:
	sheet_title.text = TEXT["settings_title"]
	if builtin:
		_lbl(TEXT["settings_builtin"], sheet_box, UI.SIZE_BODY, UI.GILT)
		var cr := _row()
		_small_btn(TEXT["copy_to_change"], _copy_it, cr, "copy_it")
	var name_row := _row()
	_key_lbl(TEXT["name"], name_row)
	var nl := _lbl(String(room["name"]), name_row, UI.SIZE_BODY + 1, UI.TEXT, false)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.keep_text(nl)  # (its words whole: smaller, then wrapped, never cut)
	var rb := _small_btn(TEXT["rename"], open_panel.bind("rename"), name_row, "rename")
	rb.disabled = builtin
	# Job.
	var jr := _row()
	_key_lbl(TEXT["job_label"], jr)
	for j in JOBS:
		var b := _small_btn(TEXT["job_short"][j], set_field.bind("role", j), jr, "job_" + j)
		_lit(b, room["role"] == j)
		b.disabled = builtin
	if room["role"] == "puzzle":
		var pr := _row()
		_key_lbl(TEXT["puzzle_label"], pr)
		for k in Check.PUZZLES:
			var b := _small_btn(TEXT["puzzles"][k], set_field.bind("puzzle", k), pr, "puzzle_" + k)
			_lit(b, room.get("puzzle", "") == k)
			b.disabled = builtin
		_lbl(TEXT["tier_label"], pr, UI.SIZE_BODY, UI.DIM, false)
		for t in [1, 2]:
			var b := _small_btn(str(t), set_field.bind("tier", t), pr, "tier_%d" % t)
			_lit(b, int(room.get("tier", 1)) == t)
			b.disabled = builtin
	# Size and first floor.
	var sz := size_of()
	for what in [["width", sz.x, Check.MIN_SIZE.x, Check.MAX_SIZE.x], ["height", sz.y, Check.MIN_SIZE.y, Check.MAX_SIZE.y], ["from", int(room["from"]), 1, Towers.SUMMIT - 1]]:
		var r := _row()
		_key_lbl(TEXT[what[0]], r)
		var minus := _small_btn("-", _step_field.bind(what[0], -1), r, what[0] + "_minus")
		minus.custom_minimum_size.x = 44.0
		minus.disabled = builtin or int(what[1]) <= int(what[2])
		var vl := _lbl(str(what[1]), r, UI.SIZE_BODY + 2, UI.GOLD, false)
		vl.custom_minimum_size.x = 36.0
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := _small_btn("+", _step_field.bind(what[0], 1), r, what[0] + "_plus")
		plus.custom_minimum_size.x = 44.0
		plus.disabled = builtin or int(what[1]) >= int(what[3])
	var fr := _row()
	_key_lbl(TEXT["flip"], fr)
	if room["role"] == "stair":
		_lbl(TEXT["flip_stair"], fr, UI.SIZE_BODY, UI.FAINT, false)
	else:
		for v in [true, false]:
			var b := _small_btn(TEXT["yes"] if v else TEXT["no"], set_field.bind("flip", v), fr, "flip_%s" % v)
			_lit(b, bool(room["flip"]) == v)
			b.disabled = builtin
	# Towers.
	_section(TEXT["towers"])
	var tg := GridContainer.new()
	tg.columns = 4 if small() else 7
	tg.add_theme_constant_override("h_separation", 6)
	tg.add_theme_constant_override("v_separation", 6)
	sheet_box.add_child(tg)
	var allowed: Array = room.get("towers", [])
	var ab := _small_btn(TEXT["all_towers"], toggle_tower.bind(""), tg, "tower_all")
	_lit(ab, allowed.is_empty())
	ab.disabled = builtin
	for tid in Towers.ORDER:
		var b := _small_btn(Towers.TOWERS[tid]["short"], toggle_tower.bind(tid), tg, "tower_" + tid)
		_lit(b, tid in allowed)
		b.disabled = builtin
	# Use in climbs, and the tower it's shown as.
	var cr2 := _row()
	var cb := _small_btn(TEXT["toggle_on"] if bool(room.get("on", false)) else TEXT["toggle_off"], toggle_climbs, cr2, "climbs")
	cb.disabled = builtin
	var vr := _row()
	_key_lbl(TEXT["seen_in"], vr)
	var vg := GridContainer.new()
	vg.columns = 3 if small() else 6
	vg.add_theme_constant_override("h_separation", 6)
	vg.add_theme_constant_override("v_separation", 6)
	vr.add_child(vg)
	for tid in Towers.ORDER:
		var b := _small_btn(Towers.TOWERS[tid]["short"], set_view_tower.bind(tid), vg, "view_" + tid)
		_lit(b, view_tower == tid)


func _lit(b: Button, on: bool) -> void:
	if on:
		for k in ["normal", "hover", "focus", "pressed", "disabled"]:
			b.add_theme_stylebox_override(k, UI.primary_box("hover" if k == "focus" or k == "hover" else "normal"))
		b.add_theme_color_override("font_color", UI.GOLD)
		b.add_theme_color_override("font_disabled_color", Color(UI.GOLD, 0.7))


func _step_field(what: String, by: int) -> void:
	var sz := size_of()
	match what:
		"width":
			resize_room(sz.x + by, sz.y)
		"height":
			resize_room(sz.x, sz.y + by)
		"from":
			set_field("from", clampi(int(room["from"]) + by, 1, Towers.SUMMIT - 1))
	if panel == "settings":
		_rebuild_panel()


func set_view_tower(tid: String) -> void:
	view_tower = tid
	_refresh()
	if panel == "settings":
		_rebuild_panel()


func _page_share() -> void:
	sheet_title.text = TEXT["share_title"]
	_lbl(TEXT["saves_project"] if Store.writes_project() else TEXT["saves_device"], sheet_box, UI.SIZE_BODY, UI.TEXT)
	var r := _row()
	var sb := _small_btn(TEXT["save"], save_rooms, r, "save")
	sb.custom_minimum_size.x = 110.0
	_small_btn(TEXT["copy_rooms"], copy_rooms, r, "copy_rooms")
	_small_btn(TEXT["paste_rooms"], _paste_pressed, r, "paste_rooms")
	if OS.has_feature("web"):
		_small_btn(TEXT["show_text"], _show_text, r, "show_text")
	text_box = TextEdit.new()
	text_box.placeholder_text = TEXT["box_hint"]
	text_box.custom_minimum_size = Vector2(0, 110 if small() else 160)
	text_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_box.add_theme_font_override("font", UI.font("mono"))
	text_box.add_theme_font_size_override("font_size", 12)
	text_box.set_meta("painter", "text_box")
	sheet_box.add_child(text_box)


func _page_help() -> void:
	sheet_title.text = TEXT["help_title"]
	var mode := "touch" if main != null and main.touch_active else ("pad" if main != null and main.pad_active else "keys")
	var ps: bool = main != null and main.pad_ps
	for id in HELP_TIPS:
		var e: Dictionary = Entity.TIPS.get(id, {})
		if e.is_empty():
			continue
		_section(String(e["name"]))
		_lbl(Entity.fill_keys(String(e["more"]), mode, ps), sheet_box, UI.SIZE_BODY, UI.TEXT)


func _page_tip(text: String) -> void:
	sheet_title.text = TEXT["eyebrow"]
	var mode := "touch" if main != null and main.touch_active else ("pad" if main != null and main.pad_active else "keys")
	sheet_box.add_child(Entity.says(Entity.fill_keys(text, mode, main != null and main.pad_ps), 40.0 if small() else 48.0))


func _page_rename() -> void:
	sheet_title.text = TEXT["rename_title"]
	name_edit = LineEdit.new()
	name_edit.text = String(room.get("name", ""))
	name_edit.max_length = 40
	name_edit.custom_minimum_size = Vector2(260, 40)
	name_edit.set_meta("painter", "name_edit")
	name_edit.text_submitted.connect(func(_t): _rename_done())
	sheet_box.add_child(name_edit)
	var r := _row()
	_small_btn(TEXT["ok"], _rename_done, r, "rename_ok")
	if main == null or not main.touch_active:
		name_edit.grab_focus.call_deferred()


func _rename_done() -> void:
	if name_edit != null and is_instance_valid(name_edit):
		rename_room(name_edit.text)
	close_panel()


# --- the grid -----------------------------------------------------------------------------

## The room drawn large, in the game's tile look, with the checks' marks,
## the doorways' places and the cursor.
class GridView extends Control:
	const Tiles := preload("res://scripts/painter_tiles.gd")
	const Rooms := preload("res://scripts/rooms.gd")
	const UI := preload("res://scripts/ui.gd")
	var p  # the painter
	var t := 0.0
	var panning := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		focus_mode = Control.FOCUS_NONE

	func _process(delta: float) -> void:
		if p == null or not is_visible_in_tree():
			return
		t += delta
		if p.picked >= 0:
			queue_redraw()  # (the problem tapped pulses)

	## [origin, tile size] of the grid inside the view.
	func geometry() -> Array:
		var sz: Vector2i = p.size_of()
		if sz.x == 0:
			return [Vector2.ZERO, 1.0]
		var m := 14.0
		var fit := minf((size.x - m * 2.0) / sz.x, (size.y - m * 2.0) / sz.y)
		var ts := maxf(4.0, fit * p.zoom)
		var gs := Vector2(sz) * ts
		var origin: Vector2 = (size - gs) * 0.5 + p.pan
		# Keep the grid in view.
		for i in 2:
			if gs[i] + m * 2.0 <= size[i]:
				origin[i] = (size[i] - gs[i]) * 0.5
			else:
				origin[i] = clampf(origin[i], size[i] - gs[i] - m, m)
		return [origin, ts]

	func tile_at(local: Vector2) -> Vector2i:
		var g := geometry()
		var sz: Vector2i = p.size_of()
		var tt := Vector2i(((local - g[0]) / g[1]).floor())
		if tt.x < 0 or tt.y < 0 or tt.x >= sz.x or tt.y >= sz.y:
			return Vector2i(-1, -1)
		return tt

	## Pans so a tile is in view (the cursor moving off the edge).
	func show_tile(tt: Vector2i) -> void:
		var g := geometry()
		var r := Rect2(g[0] + Vector2(tt) * g[1], Vector2(g[1], g[1]))
		var view := Rect2(Vector2.ZERO, size).grow(-8.0)
		var shift := Vector2.ZERO
		if r.position.x < view.position.x:
			shift.x = view.position.x - r.position.x
		elif r.end.x > view.end.x:
			shift.x = view.end.x - r.end.x
		if r.position.y < view.position.y:
			shift.y = view.position.y - r.position.y
		elif r.end.y > view.end.y:
			shift.y = view.end.y - r.end.y
		if shift != Vector2.ZERO:
			p.pan += shift
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if p == null or p.overlay.visible:
			return
		if e is InputEventMouseButton:
			var tt := tile_at(e.position)
			match e.button_index:
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
					if e.pressed and tt.x >= 0:
						p.on_grid = true
						p.cursor = tt
						get_viewport().gui_release_focus()
						p.begin_stroke(tt, e.button_index == MOUSE_BUTTON_RIGHT)
					elif not e.pressed:
						p.end_stroke()
					accept_event()
				MOUSE_BUTTON_MIDDLE:
					panning = e.pressed
					accept_event()
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					if e.pressed:
						p.set_zoom(p.zoom * (1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), e.position)
						p._refresh_tools()
					accept_event()
		elif e is InputEventMouseMotion:
			if panning:
				p.pan += e.relative
				queue_redraw()
				return
			var tt := tile_at(e.position)
			if tt != p.hover:
				p.hover = tt
				queue_redraw()
			if not p.stroke.is_empty() and tt.x >= 0 and (e.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
				p.continue_stroke(tt)

	func _draw() -> void:
		if p == null or p.room.is_empty():
			return
		var g := geometry()
		var origin: Vector2 = g[0]
		var ts: float = g[1]
		var grid: Array = p.room["grid"]
		var sz: Vector2i = p.size_of()
		var lk := Tiles.look(p.view_tower)
		draw_rect(Rect2(Vector2.ZERO, size), UI.VOID)
		var shown: Array = grid.map(func(r): return String(r).replace("?", "."))
		var prepared: Array = Rooms.prepare(shown)
		for y in sz.y:
			for x in sz.x:
				var ch: String = String(grid[y])[x]
				var r := Rect2(origin + Vector2(x, y) * ts, Vector2(ts, ts))
				var outline: bool = ch == "#" and String(prepared[y])[x] == "X"
				var below := y + 1 < sz.y and String(prepared[y + 1])[x] != "X" and String(prepared[y + 1])[x] != "#"
				Tiles.draw(self, ch, r, lk, Vector2i(x, y), outline, below)
		# The stair, in a stair room.
		if p.room.get("role", "") == "stair":
			Tiles.draw_stair(self, origin + Vector2(sz.x * 0.5, 0.0) * ts, ts, lk["tint"])
		# Faint lines between tiles.
		var line := Color(1, 1, 1, 0.06)
		for x in range(sz.x + 1):
			draw_line(origin + Vector2(x * ts, 0), origin + Vector2(x * ts, sz.y * ts), line, 1.0)
		for y in range(sz.y + 1):
			draw_line(origin + Vector2(0, y * ts), origin + Vector2(sz.x * ts, y * ts), line, 1.0)
		draw_rect(Rect2(origin, Vector2(sz) * ts), Color(UI.GILT, 0.35), false, 1.5)
		# Where corridors can join: small gilt marks outside each side.
		var role: String = p.room.get("role", "")
		for side in 4:
			var slots: Array = Rooms.door_slots(prepared, side)
			if role == "stair" and side == 0:
				var lo := int(floor(sz.x * 0.5 - 0.85))
				var hi := int(floor(sz.x * 0.5 + 0.85))
				slots = slots.filter(func(k): return k + 1 < lo - 1 or k > hi + 1)
			for k in slots:
				var c: Vector2
				var along: Vector2
				match side:
					0:
						c = origin + Vector2((k + 1) * ts, -5.0)
						along = Vector2(ts * 0.6, 0)
					1:
						c = origin + Vector2((k + 1) * ts, sz.y * ts + 5.0)
						along = Vector2(ts * 0.6, 0)
					2:
						c = origin + Vector2(-5.0, (k + 1) * ts)
						along = Vector2(0, ts * 0.6)
					_:
						c = origin + Vector2(sz.x * ts + 5.0, (k + 1) * ts)
						along = Vector2(0, ts * 0.6)
				draw_line(c - along, c + along, Color(UI.GILT, 0.55), 3.0)
		# The checks: problem tiles outlined (the picked one pulses).
		var pulse := 0.55 + 0.45 * sin(t * 6.0)
		for i in p.problems.size():
			var pr: Dictionary = p.problems[i]
			if pr["level"] == "info":
				continue
			var col: Color = UI.BAD if pr["level"] == "error" else UI.GILT
			var a := pulse if i == p.picked else 0.75
			for tt in pr["tiles"]:
				var r := Rect2(origin + Vector2(tt) * ts, Vector2(ts, ts)).grow(-1.5)
				draw_rect(r, Color(col, 0.18 * a))
				draw_rect(r, Color(col, a), false, 2.0 if i != p.picked else 3.0)
		# The box being dragged.
		if p.rect_from.x >= 0 and not p.stroke.is_empty():
			var a: Vector2i = p.rect_from
			var b: Vector2i = p.stroke["last"]
			var lo := Vector2(mini(a.x, b.x), mini(a.y, b.y))
			var hi := Vector2(maxi(a.x, b.x) + 1, maxi(a.y, b.y) + 1)
			var rr := Rect2(origin + lo * ts, (hi - lo) * ts)
			draw_rect(rr, Color(UI.GILT_HI, 0.15))
			draw_rect(rr, UI.GILT_HI, false, 2.0)
		# The mirror lines.
		if p.mirror_x:
			draw_line(origin + Vector2(sz.x * ts * 0.5, -8), origin + Vector2(sz.x * ts * 0.5, sz.y * ts + 8), Color(UI.PERIWINKLE, 0.6), 2.0)
		if p.mirror_y:
			draw_line(origin + Vector2(-8, sz.y * ts * 0.5), origin + Vector2(sz.x * ts + 8, sz.y * ts * 0.5), Color(UI.PERIWINKLE, 0.6), 2.0)
		# The mouse's tile, and the keys' or controller's cursor (with its mirror images).
		var mouse_on: bool = p.hover.x >= 0 and p.main != null and not p.main.touch_active and not p.main.pad_active
		if mouse_on:
			draw_rect(Rect2(origin + Vector2(p.hover) * ts, Vector2(ts, ts)).grow(-1.0), Color(1, 1, 1, 0.5), false, 1.5)
		var cursor_on: bool = p.on_grid and p.main != null and (p.main.pad_active or (p.menu.nav_keys and not p.main.touch_active))
		if cursor_on:
			var spots: Array = [p.cursor]
			if p.mirror_x:
				spots.append(Vector2i(sz.x - 1 - p.cursor.x, p.cursor.y))
			if p.mirror_y:
				spots.append(Vector2i(p.cursor.x, sz.y - 1 - p.cursor.y))
			if p.mirror_x and p.mirror_y:
				spots.append(Vector2i(sz.x - 1 - p.cursor.x, sz.y - 1 - p.cursor.y))
			for i in spots.size():
				var r := Rect2(origin + Vector2(spots[i]) * ts, Vector2(ts, ts)).grow(1.0)
				draw_rect(r, Color(UI.GILT_HI, 1.0 if i == 0 else 0.45), false, 3.0 if i == 0 else 2.0)
			# The tile that paints, small in the cursor's corner.
			var mini_r := Rect2(origin + Vector2(p.cursor) * ts + Vector2(ts * 0.62, -ts * 0.3), Vector2(ts * 0.5, ts * 0.5))
			draw_rect(mini_r.grow(2.0), UI.OUTLINE)
			Tiles.draw(self, p.tile, mini_r, lk, Vector2i.ZERO, false, false)


## A tile in the palette: its look and its name; gilt when it's the one in hand.
class TileButton extends Button:
	const Tiles := preload("res://scripts/painter_tiles.gd")
	const UI := preload("res://scripts/ui.gd")
	var p
	var ch := "."
	var label := ""
	var lit := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""
		clip_contents = true

	func _draw() -> void:
		var s := minf(size.y - 8.0, 28.0)
		var r := Rect2(Vector2(5, (size.y - s) * 0.5), Vector2(s, s))
		if lit:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color(UI.GILT, 0.16))
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), UI.GOLD, false, 2.0)
		draw_rect(r.grow(1.0), UI.OUTLINE)
		Tiles.draw(self, ch, r, Tiles.look(p.view_tower if p != null else ""), Vector2i(3, 2), false, false)
		var f := UI.font("body")
		var fs := 12 if size.y < 34.0 else 14
		UI.draw_text(self, f, Vector2(r.end.x + 6, size.y * 0.5 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - r.end.x - 8, fs, UI.GOLD if lit else UI.TEXT)


## A tool: an icon drawn in code with its name under it; gilt when in hand.
class ToolButton extends Button:
	const UI := preload("res://scripts/ui.gd")
	var kind := ""
	var caption := ""
	var lit := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""

	func _draw() -> void:
		var col: Color = UI.FAINT if disabled else (UI.GOLD if lit else UI.TEXT)
		if lit:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color(UI.GILT, 0.16))
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), UI.GOLD, false, 2.0)
		var fs := 11 if size.y < 46.0 else 12
		var c := Vector2(size.x * 0.5, (size.y - fs) * 0.5)
		var u := minf(size.x, size.y - fs) * 0.32
		var w := maxf(1.5, u * 0.16)
		match kind:
			"brush":
				draw_line(c + Vector2(u * 0.7, -u * 0.8), c + Vector2(-u * 0.1, u * 0.1), col, w * 1.4)
				draw_circle(c + Vector2(-u * 0.35, u * 0.4), u * 0.38, col)
			"fill":
				var pts := PackedVector2Array([c + Vector2(-u * 0.6, -u * 0.2), c + Vector2(0, -u * 0.8), c + Vector2(u * 0.6, -u * 0.2), c + Vector2(0, u * 0.5)])
				draw_colored_polygon(pts, Color(col, 0.35))
				draw_polyline(pts + PackedVector2Array([pts[0]]), col, w)
				draw_circle(c + Vector2(u * 0.75, u * 0.45), u * 0.22, col)
			"rect":
				draw_rect(Rect2(c - Vector2(u * 0.75, u * 0.6), Vector2(u * 1.5, u * 1.2)), Color(col, 0.3))
				draw_rect(Rect2(c - Vector2(u * 0.75, u * 0.6), Vector2(u * 1.5, u * 1.2)), col, false, w)
			"erase":
				var pts := PackedVector2Array([c + Vector2(-u * 0.8, u * 0.2), c + Vector2(-u * 0.1, -u * 0.6), c + Vector2(u * 0.8, -u * 0.6), c + Vector2(u * 0.1, u * 0.2)])
				draw_colored_polygon(pts, Color(col, 0.35))
				draw_polyline(pts + PackedVector2Array([pts[0]]), col, w)
				draw_line(c + Vector2(-u * 0.9, u * 0.6), c + Vector2(u * 0.9, u * 0.6), col, w)
			"mirror_x":
				draw_line(c + Vector2(0, -u * 0.9), c + Vector2(0, u * 0.9), Color(col, 0.6), w * 0.8)
				for sd in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(sd * u * 0.2, -u * 0.5), c + Vector2(sd * u * 0.9, 0), c + Vector2(sd * u * 0.2, u * 0.5)]), col)
			"mirror_y":
				draw_line(c + Vector2(-u * 0.9, 0), c + Vector2(u * 0.9, 0), Color(col, 0.6), w * 0.8)
				for sd in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.5, sd * u * 0.2), c + Vector2(0, sd * u * 0.9), c + Vector2(u * 0.5, sd * u * 0.2)]), col)
			"undo", "redo":
				var sd := -1.0 if kind == "undo" else 1.0
				draw_arc(c + Vector2(0, u * 0.15), u * 0.6, PI * 1.05 if sd < 0 else -PI * 0.05, PI * 2.0 if sd < 0 else PI * 0.95, 16, col, w)
				var tip := c + Vector2(sd * u * 0.6, u * 0.15)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-u * 0.3, -u * 0.05), tip + Vector2(u * 0.3, -u * 0.05), tip + Vector2(0, u * 0.35)]), col)
			"zoom_in", "zoom_out":
				draw_arc(c + Vector2(-u * 0.15, -u * 0.15), u * 0.55, 0.0, TAU, 20, col, w)
				draw_line(c + Vector2(u * 0.25, u * 0.25), c + Vector2(u * 0.8, u * 0.8), col, w * 1.5)
				draw_line(c + Vector2(-u * 0.45, -u * 0.15), c + Vector2(u * 0.15, -u * 0.15), col, w)
				if kind == "zoom_in":
					draw_line(c + Vector2(-u * 0.15, -u * 0.45), c + Vector2(-u * 0.15, u * 0.15), col, w)
		var f := UI.font("body")
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UI.draw_text(self, f, Vector2((size.x - tw) * 0.5, size.y - 4.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
