extends Control
## The menu's left rail (menu.gd): a column down the left of the screen
## that the pause menu, the climber screen, the inventory, the Archive,
## settings, controls and the dev tools all share, so moving between them
## is one press. At the top, who you are: your name, where you are (the
## tower and floor, or the train) and your six marks as small medallions;
## then the pages; at the bottom Start over and Exit.
##
## Keys and controller: up and down move along the rail and show each page
## as you go; Right, Enter or A goes into the page; Esc or B comes back to
## the rail, and from the rail closes the menu. Touch and mouse: tap or
## click an item. On a phone the rail narrows to icons with short names.
##
## The words live in ITEMS, TRAIN_ITEMS, FOOT and TEXT.

const UI := preload("res://scripts/ui.gd")
const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")

## The pages: [id, name, short name (a phone), a line under the name (a
## computer), icon]. The icons are drawn in ui.gd draw_icon.
const ITEMS := [
	["resume", "Resume", "Resume", "Back to the climb", "resume"],
	["climber", "Climber", "Climber", "Marks, essence, record", "climber"],
	["inventory", "Inventory", "Bag", "Gear, items, heirlooms", "inventory"],
	["archive", "Archive", "Archive", "What the Entity told you", "archive"],
	["settings", "Settings", "Settings", "Sound, screen, controller", "settings"],
	["controls", "Controls", "Controls", "Every key and button", "controls"],
	["dev", "Dev tools", "Dev", "For testing", "dev"],
]
## On the train, two of them change: Resume goes back to the train, and the
## inventory is your car (your chest and heirlooms).
const TRAIN_ITEMS := {
	"resume": ["Train", "Train", "Back to the cars", "train"],
	"inventory": ["Your car", "Your car", "Your chest and heirlooms", "car"],
}
## Along the bottom.
const FOOT := [
	["over", "Start over", "Start over", "", "over"],
	["exit", "Exit to title", "Exit", "", "exit"],
]
const TEXT := {
	"unnamed": "Unnamed climber",
	"on_train": "On the train",
	"first_climb": "The first climb",
	"place": "%s  ·  floor %d",
	"hint_keys": "↑ ↓ choose   → enter   Esc close",
	"hint_pad": "↑ ↓ choose   {a} enter   {b} close",
}

## Widths: a computer, and a phone (drawn 1.5x, so in its own units).
const WIDE := 236.0
const NARROW := 132.0

var menu  # menu.gd
var narrow := false
var buttons: Array = []  # the RailItems, top to bottom (the pages, then the foot)
var current := ""  # the item lit as the page you're on
var on_train := false
var ident: RailIdent
var list: VBoxContainer
var foot_box: VBoxContainer
var hint: Label
var _built_for := ""  # what the items were built for (train / climb, wide / narrow)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## How wide the rail is on this screen.
static func width_for(compact: bool) -> float:
	return NARROW if compact else WIDE


## Builds (or refreshes) the rail for the page showing.
func refresh(page_item: String, train: bool, compact: bool, touch: bool, pad: bool, ps: bool) -> void:
	var key := "%s %s %s %s %s" % [train, compact, touch, pad, ps]
	on_train = train
	narrow = compact
	if key != _built_for or buttons.is_empty():
		_built_for = key
		_build(touch, pad, ps)
	current = page_item
	mouse_filter = Control.MOUSE_FILTER_STOP
	for b in buttons:
		b.mouse_filter = Control.MOUSE_FILTER_STOP  # (closing the menu turned them off)
		b.on = b.id == current
		b.queue_redraw()
	if ident != null:
		ident.queue_redraw()


func _build(touch: bool, pad: bool, ps: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	buttons.clear()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side := 8.0 if narrow else 14.0
	col.offset_left = side
	col.offset_right = -side - 3.0
	col.offset_top = 8.0 if narrow else 20.0
	col.offset_bottom = -(6.0 if narrow else 14.0)
	col.add_theme_constant_override("separation", 4 if narrow else 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	ident = RailIdent.new()
	ident.rail = self
	ident.custom_minimum_size.y = 62.0 if narrow else 112.0
	col.add_child(ident)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 1 if narrow else 3)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(list)
	for it in ITEMS:
		var row: Array = it
		if on_train and TRAIN_ITEMS.has(it[0]):
			row = [it[0]] + TRAIN_ITEMS[it[0]]
		if it[0] == "archive":
			row = [it[0], Entity.TEXT["archive"], Entity.TEXT["archive"], it[3], it[4]]
		_item(list, row, _key_for(it[0], touch, pad, ps))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	foot_box = VBoxContainer.new()
	foot_box.add_theme_constant_override("separation", 1 if narrow else 2)
	foot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot_box)
	var sep := RailRule.new()
	sep.custom_minimum_size.y = 6.0 if narrow else 9.0
	foot_box.add_child(sep)
	for it in FOOT:
		var b := _item(foot_box, it, "")
		b.small = true
	hint = null
	if not narrow and not touch:
		hint = Label.new()
		hint.text = Controls.pad_text(TEXT["hint_pad"], ps) if pad else TEXT["hint_keys"]
		UI.style_label(hint, "body", 12, Color(UI.FAINT, 0.9))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.custom_minimum_size.x = 60.0
		col.add_child(hint)
	# Up and down stay on the rail (and wrap round); left stays put.
	for i in buttons.size():
		var b: Control = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
		b.focus_neighbor_left = b.get_path_to(b)
	queue_redraw()


## The key that opens a page directly, shown faintly beside it (not on a phone).
func _key_for(id: String, touch: bool, pad: bool, ps: bool) -> String:
	if touch:
		return ""
	match id:
		"climber":
			return Controls.pad_text("{back}", ps) if pad else "Tab"
		"inventory":
			return Controls.pad_text("{up}", ps) if pad else "I"
		"resume":
			return Controls.pad_text("{start}", ps) if pad else "Esc"
	return ""


func _item(parent: Node, row: Array, key: String) -> RailItem:
	var b := RailItem.new()
	b.rail = self
	b.id = row[0]
	b.text = row[1]
	b.short = row[2]
	b.sub = row[3]
	b.icon_id = row[4]
	b.key_hint = key
	b.set_meta("rail", row[0])
	b.custom_minimum_size = Vector2(0, (38.0 if narrow else 46.0))  # (a phone: still big enough to tap)
	b.pressed.connect(func(): menu.rail_pressed(b.id))
	b.focus_entered.connect(func(): menu.rail_focused(b.id))
	parent.add_child(b)
	buttons.append(b)
	return b


## The button for an item, or null.
func button(id: String) -> Control:
	for b in buttons:
		if b.id == id:
			return b
	return null


## True while one of the rail's items has the keyboard and controller focus.
func has_focus_inside() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and buttons.has(f)


## Focus the item lit for the page showing (or the first).
func focus_current() -> void:
	var b := button(current)
	if b == null and not buttons.is_empty():
		b = buttons[0]
	if b != null and b.is_inside_tree():
		menu._rail_grab = true
		b.grab_focus()
		menu._rail_grab = false


## The rail's slab: darker than the page, lit faintly at the top, with a
## thin line and a gilt hairline down its right edge.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)])
	draw_polygon(pts, PackedColorArray([Color(0.1, 0.086, 0.14, 0.97), Color(0.1, 0.086, 0.14, 0.97), Color(0.045, 0.038, 0.065, 0.97), Color(0.045, 0.038, 0.065, 0.97)]))
	# A soft violet light from the top.
	var gh := minf(size.y * 0.4, 260.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, gh), Vector2(0, gh)]),
		PackedColorArray([Color(UI.VIOLET, 0.07), Color(UI.VIOLET, 0.07), Color(UI.VIOLET, 0.0), Color(UI.VIOLET, 0.0)]))
	draw_line(Vector2(size.x - 0.5, 0), Vector2(size.x - 0.5, size.y), Color(UI.LINE_HI, 0.8), 1.0)
	draw_line(Vector2(size.x - 3.5, 0), Vector2(size.x - 3.5, size.y), Color(UI.GILT, 0.14), 1.0)


## A page's item on the rail: an icon, its name (and a line under it on a
## computer), and the key that opens it; lit gilt for the page you're on.
class RailItem extends Button:
	const UI := preload("res://scripts/ui.gd")
	var rail
	var id := ""
	var short := ""
	var sub := ""
	var icon_id := ""
	var key_hint := ""
	var on := false
	var small := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))  # (the name is drawn below, with the icon)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var narrow: bool = rail.narrow
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() or button_pressed
		if on:
			# The page you're on: a gilt wash fading to the right, a gilt edge
			# and a bright bar at the left.
			var pts := UI.rounded(r, 7.0)
			var cols := PackedColorArray()
			for p in pts:
				var k := p.x / maxf(size.x, 1.0)
				cols.append(Color(UI.GILT, lerpf(0.26, 0.05, k)))
			draw_polygon(pts, cols)
			var loop := UI.rounded(r.grow(-0.5), 7.0)
			loop.append(loop[0])
			draw_polyline(loop, Color(UI.GILT, 0.45), 1.0, true)
			draw_rect(Rect2(1, 6, 2.5, size.y - 12), UI.GILT_HI)
		elif hot:
			var pts := UI.rounded(r, 7.0)
			draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.045)]))
		if has_focus() and not (rail.menu.main != null and rail.menu.main.touch_active):
			var loop := UI.rounded(r.grow(-1.0), 7.0)
			loop.append(loop[0])
			draw_polyline(loop, Color(UI.GILT, 0.25), 5.0, true)
			draw_polyline(loop, UI.GILT_HI, 1.6, true)
		var lit := on or has_focus() or hot
		var ic := Color(UI.GILT_HI) if on else (UI.TEXT if lit else Color(UI.DIM, 0.95))
		var tc := UI.TEXT if lit else Color(UI.DIM.lerp(UI.TEXT, 0.35))
		if small and not lit:
			ic = Color(UI.DIM, 0.8)
			tc = UI.DIM
		var isz := 7.5 if narrow else (8.0 if small else 9.5)
		var ix := 15.0 if narrow else 20.0
		UI.draw_icon(self, icon_id, Vector2(ix, size.y * 0.5), isz, ic, 1.5 if narrow else 1.7)
		var x := ix + (14.0 if narrow else 20.0)
		var w := size.x - x - 6.0
		# The item's name is a label (the gothic face); what it holds, under
		# it, is text.
		var label: String = short if narrow else text
		var fs := 15 if narrow else (16 if small else 18)
		if narrow or sub == "" or small:
			UI.draw_label(self, Vector2(x, size.y * 0.5 + fs * 0.32), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w)
		else:
			UI.draw_label(self, Vector2(x, size.y * 0.5 - 1.0), label, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, w)
			draw_string(UI.font("body"), Vector2(x, size.y * 0.5 + 14.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 13, Color(UI.DIM, 0.85 if lit else 0.7))
		if key_hint != "" and not narrow:
			var mono := UI.font("mono")
			draw_string(mono, Vector2(0, size.y * 0.5 - (1.0 if sub != "" and not small else -4.0)), key_hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8.0, 11, Color(UI.FAINT, 0.95))


## The thin rule over the rail's foot.
class RailRule extends Control:
	const UI := preload("res://scripts/ui.gd")

	func _draw() -> void:
		var y := size.y * 0.5
		draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(size.x * 0.5, y), Vector2(size.x, y)]),
			PackedColorArray([Color(UI.LINE_HI, 0.0), Color(UI.LINE_HI, 0.8), Color(UI.LINE_HI, 0.0)]), 1.0, true)


## Who you are, at the top of the rail: your name in the display face, where
## you are, and your six marks as small medallions (an empty socket for a
## part with no mark yet).
class RailIdent extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Bonds := preload("res://scripts/bonds.gd")
	const ProfileScript := preload("res://scripts/profile.gd")
	var rail

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var m = rail.menu
		if m == null or m.main == null or m.main.profile == null:
			return
		var main = m.main
		var prof = main.profile
		var narrow: bool = rail.narrow
		var name: String = str(prof.appearance.get("name", ""))
		if name == "":
			name = rail.TEXT["unnamed"]
		var place := ""
		if main.on_train:
			place = rail.TEXT["on_train"]
		elif main.has_method("tower_data"):
			var td: Dictionary = main.tower_data()
			place = rail.TEXT["place"] % [td.get("short", td["name"]) if narrow else td["name"], main.floor_num]
		var x := 4.0 if narrow else 8.0
		var w := size.x - x
		var y := 0.0
		# Where you are, a small gothic label over the name (the old game's eyebrow).
		var es := 11 if narrow else 14
		var place_col: Color = UI.GOLD
		if not main.on_train and main.has_method("tower_data"):
			var ess = main.tower_data().get("essence", "")
			var Essence = load("res://scripts/essence.gd")
			if ess != "":
				place_col = Essence.color(ess).lerp(UI.TEXT, 0.25)
		y += es + 2.0
		UI.draw_eyebrow(self, Vector2(x, y), _fit(UI.font("eyebrow"), UI.titled(place), w, es), place_col, es)
		var ns := 18 if narrow else 30
		y += ns * (0.95 if narrow else 1.0) + 2.0
		UI.draw_title(self, Vector2(x, y), _fit(UI.font("display"), name, w, ns), ns, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
		# The six marks.
		var r := 6.5 if narrow else 10.0
		var gap := (w - r * 2.0 * 6.0) / 5.0 if narrow else 7.0
		var cy := y + r + (8.0 if narrow else 12.0)
		var b := UI.Draw.Batch.new()
		var i := 0
		for part in Bonds.PARTS:
			var c := Vector2(x + r + i * (r * 2.0 + gap), cy)
			var info: Dictionary = prof.bonds.get(part, {})
			if info.is_empty():
				UI.socket_into(b, c, r * 0.82)
			else:
				var data: Dictionary = Bonds.BONDS[info["id"]]
				UI.medallion_into(b, c, r, data["color"], data["affinity"], 1.0, 0, 0.35 if not info.get("faint", false) else 0.0, info.get("faint", false))
			i += 1
		b.flush(self)
		if not narrow:
			var line := "%d of 6 marks  ·  best floor %d" % [prof.bonds.size(), prof.best_floor]
			draw_string(UI.font("body"), Vector2(x, cy + r + 18.0), line, HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)

	static func _fit(f: Font, t: String, w: float, fs: int) -> String:
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return t
		while t.length() > 3 and f.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			t = t.left(t.length() - 1)
		return t + "..."
