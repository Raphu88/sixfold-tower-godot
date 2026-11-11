extends RefCounted
## THE BOOK: the climber screen is a bound grimoire (menu.gd "climber"
## page). Drawn in code in the menus' palette: a leather cover tooled in
## gilt, an open spread of candlelit parchment (dark vellum, so the menus'
## light ink reads on it), a crease down the spine, and a ribbon hanging
## from the top edge for each section: Abilities, Tree, Marks (Body for the
## Unbound), Essence, Record (and Core with a secret bond). Pages turn with
## Q / E, LB / RB, a swipe across the page, or a tap on a ribbon; a leaf
## lifts and sweeps over as they do (Turn).
##
## The tooling: a double gilt fillet round the cover with a row of stamped
## dots between, a fleuron in each corner, headbands striped at the spine's
## ends and gilt page edges; the ribbons are satin, with a sheen down the
## middle, a forked tail and a little gilt bar where they leave the spine.
##
## It opens from the identity block on the rail, Tab, the Climber button,
## and the book lying in Your Car on the train (ClosedBook, train_page.gd).
## Every word on it is in TEXT; colours in RIBBONS and the constants below.

const UI := preload("res://scripts/ui.gd")
const Controls := preload("res://scripts/controls.gd")

static var TEXT := {
	"name": "Climber's book",
	"short": "Book",
	"open": "Open your book",
}
## Each section's ribbon colour.
static var RIBBONS := {
	"abilities": Color(0.78, 0.6, 0.24), "tree": Color(0.36, 0.6, 0.34), "marks": Color(0.66, 0.18, 0.2),
	"essence": Color(0.26, 0.42, 0.7), "record": Color(0.5, 0.32, 0.62), "core": Color(0.7, 0.72, 0.78),
}
static var LEATHER := Color(0.26, 0.11, 0.09)
static var PAGE := Color(0.155, 0.125, 0.105)
static var PAGE_EDGE := Color(0.32, 0.27, 0.2)
## A swipe turns a page once it has gone this far across (view px), mostly sideways.
const SWIPE := 70.0
const TURN_TIME := 0.34


## The book's panel look (menu.gd sets it on the climber page's panel).
static func panel_style(compact: bool) -> StyleBox:
	var s := BookStyle.new()
	s.compact = compact
	var side := 16.0 if compact else 30.0
	s.content_margin_left = side
	s.content_margin_right = side
	s.content_margin_top = 10.0 if compact else 18.0
	s.content_margin_bottom = 10.0 if compact else 20.0
	return s


## The ribbons: one per section, hanging from the top of the page (the
## chosen one longer and brighter), Q / E (LB / RB) either side.
static func ribbons(menu, list: Array, current: String, choose: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4 if menu.compact() else 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_meta("ribbons", true)
	menu.box.add_child(row)
	var keys := ["", ""]
	var main = menu.main
	if main != null and not main.touch_active:
		keys = [Controls.pad_name("lb", main.pad_ps), Controls.pad_name("rb", main.pad_ps)] if main.pad_active else ["Q", "E"]
	if keys[0] != "":
		row.add_child(menu._key_hint(keys[0]))
	for t in list:
		var b := Ribbon.new()
		b.text = t[1]
		b.col = RIBBONS.get(t[0], UI.GILT)
		b.on = t[0] == current
		b.compact = menu.compact()
		b.custom_minimum_size = Vector2(96.0, 36.0) if menu.compact() else Vector2(112.0, 42.0)
		b.set_meta("tab", t[0])
		b.set_meta("ribbon", t[0])
		b.pressed.connect(choose.bind(t[0]))
		row.add_child(b)
	if keys[1] != "":
		row.add_child(menu._key_hint(keys[1]))


## A page turning: a soft shadow sweeps across the book (dir 1: forward).
static func turn(menu, dir: int) -> void:
	if menu.panel == null or not menu.is_inside_tree():
		return
	var t := Turn.new()
	t.dir = dir
	t.top_level = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.panel.add_child(t)
	t.global_position = menu.panel.global_position
	t.size = menu.panel.size


## The book's look: leather, gilt tooling, two pages and the spine.
class BookStyle extends StyleBox:
	const UI := preload("res://scripts/ui.gd")
	var compact := false

	func _draw(ci: RID, rect: Rect2) -> void:
		var rs := RenderingServer
		var Book = load("res://scripts/book.gd")
		var leather: Color = Book.LEATHER
		var page: Color = Book.PAGE
		var edge: Color = Book.PAGE_EDGE
		var border := 6.0 if compact else 10.0
		# A shadow under the book, then the cover.
		for i in 3:
			var g := rect.grow(4.0 + i * 3.0)
			g.position.y += 5.0
			rs.canvas_item_add_polygon(ci, UI.rounded(g, 12.0), PackedColorArray([Color(0, 0, 0, 0.12)]))
		var cover := UI.rounded(rect, 9.0)
		var cc := PackedColorArray()
		for p in cover:
			cc.append(leather.lightened(0.06).lerp(leather.darkened(0.35), clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
		rs.canvas_item_add_polygon(ci, cover, cc)
		# The tooling: a double gilt fillet, stamped dots between, a fleuron
		# in each corner.
		var tool := UI.rounded(rect.grow(-3.0), 7.0)
		tool.append(tool[0])
		rs.canvas_item_add_polyline(ci, tool, PackedColorArray([Color(UI.GILT, 0.55)]), 1.0, true)
		if border >= 8.0:
			var inner := UI.rounded(rect.grow(-border + 2.0), 5.0)
			inner.append(inner[0])
			rs.canvas_item_add_polyline(ci, inner, PackedColorArray([Color(UI.GILT, 0.3)]), 1.0, true)
			var mid_r := rect.grow(-(3.0 + border - 2.0) * 0.5)
			var step_px := 14.0
			for x in range(int(mid_r.position.x + 22.0), int(mid_r.end.x - 22.0), int(step_px)):
				for y in [mid_r.position.y, mid_r.end.y]:
					rs.canvas_item_add_circle(ci, Vector2(x, y), 0.9, Color(UI.GILT, 0.32))
			for y in range(int(mid_r.position.y + 22.0), int(mid_r.end.y - 22.0), int(step_px)):
				for x in [mid_r.position.x, mid_r.end.x]:
					rs.canvas_item_add_circle(ci, Vector2(x, y), 0.9, Color(UI.GILT, 0.32))
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var at: Vector2 = rect.position + rect.size * corner + Vector2(1.0 - 2.0 * corner.x, 1.0 - 2.0 * corner.y) * (border * 0.5 + 1.5)
			var d: Vector2 = Vector2(1.0 - 2.0 * corner.x, 1.0 - 2.0 * corner.y)
			_fleuron(ci, at, d, 6.0 if compact else 9.0)
		# The pages: a stack of edges at the sides, then the spread.
		var pr := rect.grow(-border)
		for i in 3:
			var e := pr.grow(-float(i) * 1.2)
			e.position.y += 1.5
			rs.canvas_item_add_polygon(ci, UI.rounded(e, 4.0), PackedColorArray([edge.darkened(0.2 * i)]))
		# Gilt page edges, showing round the spread.
		var gilt_edge := UI.rounded(pr.grow(0.5), 4.0)
		gilt_edge.append(gilt_edge[0])
		rs.canvas_item_add_polyline(ci, gilt_edge, PackedColorArray([Color(UI.GILT, 0.4)]), 1.0, true)
		var spread := pr.grow(-2.0)
		var mid := spread.position.x + spread.size.x * 0.5
		for half in [0, 1]:
			var r := Rect2(spread.position.x if half == 0 else mid, spread.position.y, spread.size.x * 0.5, spread.size.y)
			var pts := UI.rounded(r, 3.0)
			var cols := PackedColorArray()
			for p in pts:
				# Lighter toward the outer edge, shadowed into the spine.
				var k := absf(p.x - mid) / maxf(r.size.x, 1.0)
				cols.append(page.darkened(0.35 * (1.0 - clampf(k * 3.0, 0.0, 1.0))).lightened(0.04 * k))
			rs.canvas_item_add_polygon(ci, pts, cols)
		# Foxing: a few faint spots, always in the same places.
		for i in 9:
			var fx := spread.position.x + spread.size.x * fmod(0.137 + i * 0.391, 1.0)
			var fy := spread.position.y + spread.size.y * fmod(0.21 + i * 0.617, 1.0)
			rs.canvas_item_add_circle(ci, Vector2(fx, fy), 10.0 + float(i % 3) * 7.0, Color(0.3, 0.22, 0.12, 0.05))
		# The spine's crease, and a faint rule round each page.
		rs.canvas_item_add_line(ci, Vector2(mid, spread.position.y + 2.0), Vector2(mid, spread.end.y - 2.0), Color(0, 0, 0, 0.45), 2.0)
		rs.canvas_item_add_line(ci, Vector2(mid + 2.0, spread.position.y + 2.0), Vector2(mid + 2.0, spread.end.y - 2.0), Color(1, 1, 1, 0.03), 1.0)
		var rule := UI.rounded(spread.grow(-6.0), 2.0)
		rule.append(rule[0])
		rs.canvas_item_add_polyline(ci, rule, PackedColorArray([Color(UI.GILT, 0.12)]), 1.0, true)
		# The headbands: a little striped silk band at each end of the spine.
		var hw := 14.0 if compact else 20.0
		for y in [spread.position.y - 1.0, spread.end.y - 3.0]:
			for i in 6:
				var c := Color(0.62, 0.16, 0.16) if i % 2 == 0 else Color(0.86, 0.74, 0.46)
				rs.canvas_item_add_rect(ci, Rect2(mid - hw * 0.5 + hw * i / 6.0, y, hw / 6.0 + 0.5, 4.0), c)
			rs.canvas_item_add_rect(ci, Rect2(mid - hw * 0.5, y + 4.0, hw, 1.0), Color(0, 0, 0, 0.35))

	## A gilt fleuron in a corner of the cover, pointing in along `d`.
	func _fleuron(ci: RID, at: Vector2, d: Vector2, s: float) -> void:
		var rs := RenderingServer
		var g := Color(UI.GILT, 0.7)
		rs.canvas_item_add_circle(ci, at, s * 0.22, g)
		var leaf := PackedVector2Array([at, at + Vector2(d.x * s * 0.5, d.y * s * 0.12), at + Vector2(d.x * s, 0), at + Vector2(d.x * s * 0.5, -d.y * s * 0.05)])
		rs.canvas_item_add_polygon(ci, leaf, PackedColorArray([g]))
		var leaf2 := PackedVector2Array([at, at + Vector2(d.x * s * 0.12, d.y * s * 0.5), at + Vector2(0, d.y * s), at + Vector2(-d.x * s * 0.05, d.y * s * 0.5)])
		rs.canvas_item_add_polygon(ci, leaf2, PackedColorArray([g]))
		rs.canvas_item_add_line(ci, at, at + d * s * 0.62, Color(UI.GILT, 0.55), 1.0, true)
		rs.canvas_item_add_circle(ci, at + d * s * 0.7, s * 0.12, g)


## A section's ribbon: a strip of silk hanging from the top edge, notched at
## its tail, its name on it; the chosen one longer and brighter.
class Ribbon extends Button:
	const UI := preload("res://scripts/ui.gd")
	var col := Color(0.6, 0.2, 0.2)
	var on := false
	var compact := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))  # (the name is drawn on the silk)
		for s in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			connect(s, queue_redraw)

	func _draw() -> void:
		var hot := is_hovered() or has_focus()
		var w := size.x
		var h := size.y if on else size.y - (6.0 if not hot else 3.0)
		var notch := 7.0
		var c := col.lightened(0.12) if on else col.darkened(0.25 if not hot else 0.05)
		var pts := PackedVector2Array([Vector2(3, 0), Vector2(w - 3, 0), Vector2(w - 3, h), Vector2(w * 0.5, h - notch), Vector2(3, h)])
		draw_colored_polygon(PackedVector2Array([Vector2(5, 2), Vector2(w - 1, 2), Vector2(w - 1, h + 2), Vector2(w * 0.5 + 2, h - notch + 2), Vector2(5, h + 2)]), Color(0, 0, 0, 0.35))
		# Satin: darker at the edges, a sheen down the middle.
		var cols := PackedColorArray([c.darkened(0.12), c.darkened(0.12), c.darkened(0.2), c.darkened(0.05), c.darkened(0.2)])
		draw_polygon(pts, cols)
		var sheen := PackedVector2Array([Vector2(w * 0.3, 0), Vector2(w * 0.55, 0), Vector2(w * 0.55, h - notch * 0.7), Vector2(w * 0.3, h - notch * 0.4)])
		draw_colored_polygon(sheen, Color(1, 1, 1, 0.1 if not on else 0.14))
		draw_line(Vector2(6, 2), Vector2(6, h - 2), Color(1, 1, 1, 0.12), 1.0)
		draw_line(Vector2(w - 6, 2), Vector2(w - 6, h - 2), Color(0, 0, 0, 0.2), 1.0)
		# Where it leaves the spine: a little gilt bar.
		draw_rect(Rect2(3, 0, w - 6, 3), Color(UI.GILT, 0.55 if on else 0.3))
		if on:
			var gl := pts.duplicate()
			gl.append(gl[0])
			draw_polyline(gl, Color(UI.GILT_HI, 0.85), 1.2, true)
		var fs := 15 if compact else 16
		var tc := Color(1.0, 0.95, 0.82) if on or hot else Color(0.92, 0.85, 0.75, 0.85)
		UI.draw_label(self, Vector2(6, h * 0.5 + fs * 0.25 - 2.0), text, fs, tc, HORIZONTAL_ALIGNMENT_CENTER, w - 12.0, 3, Color(0, 0, 0, 0.6))
		if has_focus() and not _touching():
			var ring := pts.duplicate()
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT, 0.3), 5.0, true)
			draw_polyline(ring, UI.GILT_HI, 1.6, true)

	func _touching() -> bool:
		var n := get_parent()
		while n != null:
			if n.has_method("rail_showing"):
				return n.main != null and n.main.touch_active
			n = n.get_parent()
		return false


## A page turning: a leaf lifts from one side of the spread and sweeps over
## the spine to the other, its free edge lit and curling, a shadow running
## ahead of it on the page below; then it's gone (a third of a second), so
## nothing is hidden for long.
class Turn extends Control:
	var dir := 1
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= load("res://scripts/book.gd").TURN_TIME:
			queue_free()

	func _draw() -> void:
		var Book = load("res://scripts/book.gd")
		var k := clampf(t / float(Book.TURN_TIME), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)  # (eased: it lifts slowly, falls quickly, settles)
		var m := 12.0
		var top := m
		var bot := size.y - m
		var spine := size.x * 0.5
		var half := spine - m
		# Where the free edge is: from the far side, over the spine, to the near side.
		var x := spine + dir * half * cos(k * PI)
		var lift := sin(k * PI)
		var page: Color = Book.PAGE.lightened(0.08)
		var fade := 1.0 - smoothstep(0.85, 1.0, k)
		# The shadow it casts ahead of its edge, on the page below.
		var sw := 40.0 * lift + 6.0
		var ahead := -dir if k < 0.5 else dir
		for i in 6:
			var a := 0.16 * lift * (1.0 - float(i) / 6.0) * fade
			var x0: float = x + ahead * sw * float(i) / 6.0
			draw_rect(Rect2(minf(x0, x0 + ahead * sw / 6.0), top, sw / 6.0, bot - top), Color(0, 0, 0, a))
		# The leaf: from the spine to its free edge, its edge raised and curved.
		var curl := 10.0 * lift
		var pts := PackedVector2Array()
		var n := 10
		pts.append(Vector2(spine, top))
		for i in n + 1:
			var f := float(i) / n
			pts.append(Vector2(lerpf(spine, x, f), top - curl * f * f))
		for i in n + 1:
			var f := float(n - i) / n
			pts.append(Vector2(lerpf(spine, x, f) + (x - spine) * 0.04 * sin(f * PI) , bot + curl * 0.6 * f * f))
		var cols := PackedColorArray()
		for p in pts:
			var f := absf(p.x - spine) / maxf(absf(x - spine), 1.0)
			cols.append(Color(page.darkened(0.35 * (1.0 - f) + 0.15 * (1.0 - lift)), 0.96 * fade))
		if absf(x - spine) > 1.5:
			draw_polygon(pts, cols)
			draw_line(Vector2(x, top - curl), Vector2(x + (x - spine) * 0.0, bot + curl * 0.6), Color(1.0, 0.92, 0.72, 0.5 * fade), 1.5, true)
			draw_line(Vector2(spine, top), Vector2(spine, bot), Color(0, 0, 0, 0.3 * fade), 2.0)


## The book as it lies closed in Your Car (train_page.gd): a thick volume in
## worn leather, gilt corners and a clasp, a ribbon peeking out, on a small
## cushion. A Button: a tap, Enter or A opens it. Its words are drawn under it.
## While a choice waits on the tree, a gilt mote glows over it.
class ClosedBook extends Button:
	const UI := preload("res://scripts/ui.gd")
	var ready_star := false
	var t := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			connect(s, queue_redraw)

	func _process(delta: float) -> void:
		if ready_star:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var Book = load("res://scripts/book.gd")
		var hot := is_hovered() or has_focus() or button_pressed
		var w := size.x
		var h := size.y
		var lh := 18.0 if h > 50.0 else 15.0  # (the words under it)
		var area := Rect2(4, 2, w - 8, h - lh - 4)
		# The cushion it lies on.
		var cushion := Rect2(area.position.x, area.end.y - area.size.y * 0.26, area.size.x, area.size.y * 0.26)
		draw_colored_polygon(UI.rounded(cushion, cushion.size.y * 0.45), Color(0.3, 0.12, 0.16))
		draw_colored_polygon(UI.rounded(cushion.grow(-2.0), cushion.size.y * 0.4), Color(0.4, 0.17, 0.2))
		draw_line(Vector2(cushion.position.x + 8, cushion.position.y + 3), Vector2(cushion.end.x - 8, cushion.position.y + 3), Color(1, 1, 1, 0.08), 1.0)
		# The book: the cover on top, seen a little from above, and under it
		# the pages' fore-edge.
		var ch := area.size.y * 0.56
		var bw := minf(area.size.x * 0.84, ch * 1.55)
		var bx := area.position.x + (area.size.x - bw) * 0.5
		var thick := maxf(6.0, area.size.y * 0.13)
		var by := cushion.position.y + cushion.size.y * 0.35 - thick - ch
		var pages := Rect2(bx + 3.0, by + ch - 1.0, bw - 6.0, thick)
		draw_rect(pages, Color(0.82, 0.74, 0.58))
		for i in int(thick / 2.6):
			draw_line(Vector2(pages.position.x, pages.position.y + 2.0 + i * 2.6), Vector2(pages.end.x, pages.position.y + 2.0 + i * 2.6), Color(0.55, 0.47, 0.35, 0.6), 1.0)
		draw_rect(Rect2(bx, pages.end.y - 2.0, bw, 3.0), Book.LEATHER.darkened(0.3))  # (the back cover's edge)
		var cover := Rect2(bx, by, bw, ch)
		var leather: Color = Book.LEATHER.lightened(0.12 if hot else 0.0)
		draw_colored_polygon(UI.rounded(cover.grow(1.0), 4.0), UI.OUTLINE)
		draw_colored_polygon(UI.rounded(cover, 4.0), leather)
		draw_rect(Rect2(cover.position.x, cover.position.y, cover.size.x, 2.0), Color(1, 1, 1, 0.1))
		var tool := UI.rounded(cover.grow(-4.0), 3.0)
		tool.append(tool[0])
		draw_polyline(tool, Color(UI.GILT, 0.7), 1.0, true)
		# A gilt device in the middle: a ring of six marks around a seventh.
		var c := cover.get_center()
		var rr := minf(cover.size.x, cover.size.y) * 0.24
		draw_arc(c, rr, 0.0, TAU, 24, Color(UI.GILT, 0.85), 1.4, true)
		for i in 6:
			draw_circle(c + Vector2.from_angle(i * TAU / 6.0 - PI * 0.5) * rr, 2.0, UI.GILT)
		draw_circle(c, 2.6, UI.GILT_HI)
		# Corner pieces and the clasp.
		for cx in [cover.position.x + 2.0, cover.end.x - 8.0]:
			for cy in [cover.position.y + 2.0, cover.end.y - 8.0]:
				draw_rect(Rect2(cx, cy, 6.0, 6.0), Color(UI.GILT, 0.8))
		draw_rect(Rect2(cover.end.x - 3.0, c.y - 5.0, 8.0, 10.0), UI.GILT.darkened(0.2))
		# A ribbon hanging out of the pages.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x + rr * 1.6, pages.end.y - 2.0), Vector2(c.x + rr * 1.6 + 5.0, pages.end.y - 2.0),
			Vector2(c.x + rr * 1.6 + 5.0, pages.end.y + 9.0), Vector2(c.x + rr * 1.6 + 2.5, pages.end.y + 6.0), Vector2(c.x + rr * 1.6, pages.end.y + 9.0)]), Book.RIBBONS["tree"])
		if ready_star:
			# A choice waits: a gilt mote over the book.
			var s := Vector2(cover.end.x - 6.0, cover.position.y - 4.0)
			var pulse := 0.6 + 0.4 * sin(t * 4.0)
			draw_circle(s, 7.0 * pulse + 2.0, Color(UI.GILT, 0.25))
			for i in 4:
				var d := Vector2.from_angle(i * PI * 0.5)
				draw_line(s - d * 6.0 * pulse, s + d * 6.0 * pulse, UI.GILT_HI, 1.4, true)
		var fs := 15 if h > 50.0 else 13
		UI.draw_label(self, Vector2(0, h - 4.0), text, fs, UI.GOLD if hot else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w, 3, Color(0, 0, 0, 0.7))
		if has_focus() and not _touching():
			var ring := UI.rounded(Rect2(Vector2(1, 1), size - Vector2(2, 2)), 6.0)
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT, 0.3), 5.0, true)
			draw_polyline(ring, UI.GILT_HI, 1.6, true)

	func _touching() -> bool:
		var n := get_parent()
		while n != null:
			if n.has_method("rail_showing"):
				return n.main != null and n.main.touch_active
			n = n.get_parent()
		return false
