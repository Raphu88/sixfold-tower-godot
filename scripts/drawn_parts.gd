extends Container
## The parts of something drawn in one go (its _draw), for Arrange mode
## (arrange_ui.gd): the workshop's wall (its lamp, pegboard, bottles,
## workbench and slate) and the crystals along the bottom of the train.
##
## A drawing has no controls of its own to move, so this gives it some: an
## empty Control for each part, laid over the drawing where that part is
## drawn (a share of the drawing's size, `fracs`). Arrange mode tags them
## like anything else, so a part can be moved and sized on its own and its
## place is saved in data/layout.json. The drawing asks xform() for each
## part's move and draws that part through it (draw_set_transform_matrix);
## with nothing arranged that is the identity, so it looks exactly as built.

## The node's name under the drawing.
const NODE := "Parts"

var fracs := {}  # part key -> its box, as a share of the drawing's size


## Gives `holder` its parts: [[key, friendly name, Rect2 share of its size]].
static func add(holder: Control, parts: Array):
	var p = load("res://scripts/drawn_parts.gd").new()
	p.name = NODE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for e in parts:
		var c := Control.new()
		c.name = String(e[0])
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_meta("part_name", String(e[1]))
		p.fracs[String(e[0])] = e[2]
		p.add_child(c)
	holder.add_child(p)
	p.sort_children.connect(holder.queue_redraw, CONNECT_DEFERRED)
	return p


## The drawing's parts (null: it has none).
static func of(holder: Node):
	var p = holder.get_node_or_null(NODE) if holder != null else null
	return p if p != null and p.get_script() == load("res://scripts/drawn_parts.gd") else null


## How part `key` of `holder` is moved and scaled from where it's drawn, in
## the holder's own space (the identity when it isn't arranged).
static func xform(holder: Control, key: String) -> Transform2D:
	var p = of(holder)
	if p == null or not p.fracs.has(key):
		return Transform2D.IDENTITY
	var c: Control = p.get_node_or_null(key)
	if c == null:
		return Transform2D.IDENTITY
	var fr: Rect2 = p.fracs[key]
	var built := Rect2(fr.position * p.size, fr.size * p.size)
	var s := c.scale.x
	var at: Vector2 = p.position + c.position
	if absf(s - 1.0) < 0.0001 and at.distance_squared_to(built.position) < 0.0001:
		return Transform2D.IDENTITY
	return Transform2D(0.0, Vector2(s, s), 0.0, at - built.position * s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control and fracs.has(String(c.name)):
				var fr: Rect2 = fracs[String(c.name)]
				fit_child_in_rect(c, Rect2(fr.position * size, fr.size * size))
