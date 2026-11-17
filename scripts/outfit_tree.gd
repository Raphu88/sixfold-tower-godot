extends Control
## The outfitter's upgrade tree, drawn in code (outfitter.gd holds what it
## is; store_page.gd puts it in the Outfitter's Car). Five columns: prices
## and stock on the left, the trunk (your rank) in the middle, gifts and
## info on the right; a row for each rank, Unknown at the bottom, so the
## tree grows upwards as you rise. Lines join each node to the one it grows
## from: gilt where both are yours, brass where the next one is open, dark
## where it's still locked.
##
## Each node is a button (TreeNode): hover it, move onto it with the keys
## or a controller, or tap it, and its card shows on the store's placard
## ("tree:<id>", train_page.gd details); the Entity explains it too
## (entity_help.gd "slot:tree").

const UI := preload("res://scripts/ui.gd")
const Outfitter := preload("res://scripts/outfitter.gd")
const Renown := preload("res://scripts/renown.gd")

## Each branch's colour (and the trunk's).
const TINT := {
	"prices": Color(0.95, 0.76, 0.36), "stock": Color(0.74, 0.6, 1.0), "gifts": Color(0.93, 0.45, 0.38),
	"info": Color(0.45, 0.8, 0.84), "trunk": Color(0.58, 0.8, 0.46),
}
const ROWS := 7

var m  # the menu (menu.gd)
var prof
var col_w := 54.0
var row_h := 56.0
var head_h := 22.0
var d := 40.0  # a node's size
var centers := {}  # node id -> its centre
var buttons := {}  # node id -> its TreeNode
var keys: Array = []  # "tree:<id>", for the placard


## Lays the tree out for `width` across, in about `height` (it's taller
## if its rows would be too short for a finger).
func setup(menu, profile, width: float, height: float, small := false) -> void:
	m = menu
	prof = profile
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_h = 18.0 if small else 22.0
	col_w = maxf(width / 5.0, 40.0)
	row_h = clampf((height - head_h) / float(ROWS), 36.0 if small else 40.0, 68.0)
	d = clampf(minf(col_w * 0.74, row_h * 0.78), 28.0, 46.0)
	custom_minimum_size = Vector2(col_w * 5.0, head_h + row_h * ROWS)
	for id in Outfitter.all_ids():
		var col := int(Outfitter.COLUMNS.get(Outfitter.branch_of(id), 2))
		var rk := Outfitter.node_rank(id)
		centers[id] = Vector2(col_w * (col + 0.5), head_h + row_h * (ROWS - 1 - rk + 0.5))
		var b := TreeNode.new()
		b.id = id
		b.branch = Outfitter.branch_of(id)
		b.tint = TINT.get(b.branch, UI.GOLD)
		b.state = Outfitter.status(prof, id)
		b.afford = b.state == "open" and int(prof.crystals_held()) >= Outfitter.cost(id)
		b.titled = String(Outfitter.NODES.get(id, {}).get("title", "")) != ""
		b.here = Outfitter.is_trunk(id) and Outfitter.trunk_rank(id) == Renown.rank(prof)
		b.picked = String(m.inv_sel) == "tree:" + id
		b.size = Vector2(d, d)
		b.custom_minimum_size = Vector2(d, d)
		b.position = centers[id] - Vector2(d, d) * 0.5
		b.set_meta("slot", "tree:" + id)
		b.tooltip_text = ""
		add_child(b)
		b.focus_entered.connect(m._show_details.bind("tree:" + id))  # (the mouse moves the focus too: nav.gd)
		b.pressed.connect(m._slot_pressed.bind("tree:" + id))
		buttons[id] = b
		keys.append("tree:" + id)


func _draw() -> void:
	var font := UI.font("display")
	# The column heads.
	var heads := {2: String(Outfitter.TEXT["trunk"])}
	for e in Outfitter.BRANCHES:
		heads[int(Outfitter.COLUMNS[e[0]])] = String(e[1])
	for c in heads:
		var tint: Color = TINT.get("trunk" if c == 2 else Outfitter.BRANCHES[c if c < 2 else c - 1][0], UI.GOLD)
		UI.draw_text(self, font, Vector2(col_w * c, head_h - 6.0), heads[c], HORIZONTAL_ALIGNMENT_CENTER, col_w - 2.0, 13, tint.lightened(0.15))
	var b := UI.Draw.Batch.new()
	# The trunk: a bark-brown bole from the first rank to the last, lit up to your rank.
	var bottom: Vector2 = centers["rank0"]
	var top: Vector2 = centers["rank%d" % (ROWS - 1)]
	var reach: Vector2 = centers["rank%d" % clampi(Renown.rank(prof), 0, ROWS - 1)]
	b.line(bottom + Vector2(0, row_h * 0.35), top, Color(0.05, 0.035, 0.03, 0.9), 9.0)
	b.line(bottom + Vector2(0, row_h * 0.35), top, Color(0.32, 0.22, 0.13), 6.0)
	b.line(bottom + Vector2(0, row_h * 0.35), reach, Color(UI.GILT, 0.75), 3.0)
	# Roots under the first rank.
	for k in [-1.0, 1.0]:
		b.line(bottom + Vector2(0, row_h * 0.3), bottom + Vector2(k * col_w * 0.45, row_h * 0.48), Color(0.32, 0.22, 0.13), 3.0)
	# The branches: each node to what it grows from.
	for id in centers:
		if Outfitter.is_trunk(id):
			continue
		for p in Outfitter.parents(id):
			if not centers.has(p):
				continue
			var a: Vector2 = centers[p]
			var z: Vector2 = centers[id]
			var col := _line_col(String(p), id)
			if absf(a.x - z.x) < 1.0:
				b.line(a, z, Color(0, 0, 0, 0.55), 5.0)
				b.line(a, z, col, 2.6)
			else:
				# Out from the trunk and up: a curve.
				var pts := PackedVector2Array()
				var ctl := Vector2(z.x, a.y)
				for i in 13:
					var t := i / 12.0
					pts.append(a.lerp(ctl, t).lerp(ctl.lerp(z, t), t))
				b.polyline(pts, Color(0, 0, 0, 0.55), 5.0)
				b.polyline(pts, col, 2.6)
	b.flush(self)
	# Each rank's name under its trunk node (where the rows have room): the
	# row's nodes open at that rank.
	if row_h - d >= 17.0:
		for i in ROWS:
			var at: Vector2 = centers["rank%d" % i]
			var reached: bool = Renown.rank(prof) >= i
			var nm := Renown.rank_name(i)
			var tw := minf(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, col_w) + 8.0
			draw_rect(Rect2(at.x - tw * 0.5, at.y + d * 0.5 + 2.0, tw, 13.0), Color(0.04, 0.07, 0.05, 0.88))
			UI.draw_text(self, font, Vector2(at.x - col_w * 0.5, at.y + d * 0.5 + 12.0), Renown.rank_name(i), HORIZONTAL_ALIGNMENT_CENTER, col_w, 11, Color(UI.GILT_HI, 0.9) if reached else Color(UI.DIM, 0.8))


func _line_col(from: String, to: String) -> Color:
	var a := Outfitter.status(prof, from)
	var z := Outfitter.status(prof, to)
	if a == "bought" and z == "bought":
		return Color(UI.GILT, 0.95)
	if a == "bought" and z == "open":
		return Color(UI.TRAIN_BRASS, 0.7)
	return Color(UI.FAINT, 0.4)


## A node of the tree: a medallion in its branch's colour. Gilt-ringed and
## lit once it's yours; a brass ring when it's open to buy (brighter when
## you can pay); dark, with a small lock, while it's locked. A small
## pennant marks a node that needs a title.
class TreeNode extends Button:
	const UI := preload("res://scripts/ui.gd")
	var id := ""
	var branch := ""
	var state := "locked"
	var afford := false
	var titled := false
	var here := false  # the trunk node of your rank
	var picked := false
	var tint := Color.WHITE

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.border_color = UI.GOLD
		f.set_border_width_all(2)
		f.set_corner_radius_all(int(size.x))
		f.set_expand_margin_all(3)
		add_theme_stylebox_override("focus", f)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		medal(self, size / 2.0, minf(size.x, size.y) * 0.5, branch, state, tint, afford, titled, here, picked, is_hovered())

	## Draws a node's medallion on `ci` (the tree's button, a card's heading: Medal).
	static func medal(ci: CanvasItem, c: Vector2, r: float, branch: String, state: String, tint: Color, afford := false, titled := false, here := false, picked := false, hover := false) -> void:
		var b := UI.Draw.Batch.new()
		if state == "bought":
			UI.glow_into(b, c, r * 1.25, tint, 0.55 if not here else 0.9)
		elif state == "open" and afford:
			UI.glow_into(b, c, r * 1.15, UI.TRAIN_BRASS, 0.35)
		b.circle(c, r, UI.OUTLINE)
		var fill: Color = tint.darkened(0.55) if state == "bought" else (Color(0.17, 0.12, 0.07) if state == "open" else Color(0.08, 0.07, 0.09))
		if hover:
			fill = fill.lightened(0.12)
		b.circle(c, r - 1.5, fill)
		b.arc(c, r - 3.0, PI * 1.05, PI * 1.65, 10, Color(1, 1, 1, 0.14 if state != "locked" else 0.05), 1.5)
		var ring: Color = UI.GILT_HI if state == "bought" else (Color(UI.TRAIN_BRASS, 0.95 if afford else 0.6) if state == "open" else Color(UI.LINE_HI, 0.55))
		b.arc(c, r - 1.5, 0.0, TAU, 32, ring, 2.4 if state != "locked" else 1.4)
		if picked:
			b.arc(c, r + 2.5, 0.0, TAU, 32, Color(UI.GOLD, 0.9), 1.6)
		var ic: Color = tint.lightened(0.35) if state == "bought" else (tint if state == "open" else Color(tint.darkened(0.45), 0.8))
		_icon(b, branch, c, r * 0.52, ic)
		if titled:
			# A small pennant at the top left: this one needs a title.
			var p := c + Vector2(-r * 0.78, -r * 0.78)
			b.line(p, p + Vector2(0, r * 0.62), Color(UI.OUTLINE, 0.9), 2.4)
			b.polygon(PackedVector2Array([p, p + Vector2(r * 0.5, r * 0.14), p + Vector2(0, r * 0.3)]), UI.GILT if state != "locked" else Color(UI.GILT, 0.5))
			b.line(p, p + Vector2(0, r * 0.62), UI.GILT_DEEP.lightened(0.3), 1.2)
		b.flush(ci)
		if state == "locked" and branch != "trunk":
			UI.draw_lock(ci, c + Vector2(r * 0.55, r * 0.55), r * 0.36, Color(UI.DIM, 0.95))

	## Each branch's sign: a coin (prices), a cut gem (stock), a tied
	## parcel (gifts), an eye (info), a rank's chevrons (the trunk).
	static func _icon(b, branch: String, c: Vector2, s: float, col: Color) -> void:
		match branch:
			"prices":
				b.circle(c, s, col)
				b.circle(c, s * 0.72, col.darkened(0.35))
				b.line(c + Vector2(0, -s * 0.5), c + Vector2(0, s * 0.5), col, maxf(1.5, s * 0.18))
				b.arc(c, s * 0.3, PI * 1.2, PI * 2.3, 6, col, maxf(1.2, s * 0.14))
			"stock":
				var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.85, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.85, -s * 0.2)])
				b.polygon(pts, col)
				b.polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.85, -s * 0.2), c + Vector2(0, -s * 0.05)]), col.lightened(0.35))
				b.line(c + Vector2(-s * 0.85, -s * 0.2), c + Vector2(s * 0.85, -s * 0.2), col.darkened(0.4), 1.0)
			"gifts":
				var box := Rect2(c + Vector2(-s * 0.8, -s * 0.45), Vector2(s * 1.6, s * 1.3))
				b.rect(box, col)
				b.rect(Rect2(box.position.x - s * 0.1, box.position.y - s * 0.3, box.size.x + s * 0.2, s * 0.35), col.lightened(0.2))
				b.rect(Rect2(c.x - s * 0.14, box.position.y - s * 0.3, s * 0.28, box.size.y + s * 0.3), col.darkened(0.45))
				b.arc(c + Vector2(-s * 0.3, -s * 0.72), s * 0.28, 0.0, TAU, 10, col.darkened(0.45), maxf(1.0, s * 0.14))
				b.arc(c + Vector2(s * 0.3, -s * 0.72), s * 0.28, 0.0, TAU, 10, col.darkened(0.45), maxf(1.0, s * 0.14))
			"info":
				var eye := PackedVector2Array()
				for i in 13:
					var t := i / 12.0
					eye.append(c + Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.62))
				for i in range(1, 12):
					var t := 1.0 - i / 12.0
					eye.append(c + Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.62))
				b.polygon(eye, col)
				b.circle(c, s * 0.4, col.darkened(0.6))
				b.circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.12, col.lightened(0.5))
			_:
				for k in 2:
					var y := c.y - s * 0.15 + k * s * 0.55
					b.polyline(PackedVector2Array([Vector2(c.x - s * 0.8, y + s * 0.3), Vector2(c.x, y - s * 0.3), Vector2(c.x + s * 0.8, y + s * 0.3)]), col, maxf(1.6, s * 0.26))
				b.circle(c + Vector2(0, -s * 0.85), s * 0.2, col)


## A node's medallion on its own (the card's heading, store_page.gd).
class Medal extends Control:
	var branch := ""
	var state := "locked"
	var tint := Color.WHITE
	var titled := false

	func _draw() -> void:
		TreeNode.medal(self, size / 2.0, minf(size.x, size.y) * 0.5 - 2.0, branch, state, tint, state == "open", titled)
