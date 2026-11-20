extends RefCounted
## The treasure chest, drawn one way everywhere it stands: a room's spoils
## (room_rewards.gd), a vault's chests (vaults.gd) and a mimic waiting as a
## chest (mimic.gd). A showcase for the shading toolkit (shade.gd): a soft
## contact shadow, wood with grain lit from the top-left (the lid's top
## face bright, its front in shade), iron bands with a sheen and darker
## edges, rivets and a lock plate that catch the light, and on a rich chest
## gold trim and corner caps with a glint that passes over them now and then.
##
## The chest keeps its old footprint (26 x 22 px round `at`: the lid's top
## face from y -9 to 0, the front from 0 to 12) so nothing else moves.

const Palette := preload("res://scripts/palette.gd")
const Shade := preload("res://scripts/shade.gd")

const WOOD := Color(0.47, 0.31, 0.18)
const WOOD_RICH := Color(0.52, 0.34, 0.19)
const IRON := Color(0.42, 0.42, 0.47)
const GOLD := Color(0.93, 0.72, 0.32)
const READY := Color(1.0, 0.84, 0.45)  # the lock glowing: it can be opened
const SHUT := Color(0.75, 0.25, 0.2)  # the lock while its guards stand
const INSIDE := Color(0.07, 0.045, 0.04)


## Draws a chest into Batch `b` at `at`. Options (all optional):
##   rich: gold trim; wood: its wood colour; ready: the lock glows (it can
##   be opened); taken: open and empty; lift: the lid raised by this many px
##   (a mimic's breath: the caller draws the maw in the gap); pulse: 0..1,
##   the glow's beat; t: the time (the rich chest's passing glint).
static func draw(b, at: Vector2, o := {}) -> void:
	var rich: bool = o.get("rich", false)
	var wood: Color = o.get("wood", WOOD_RICH if rich else WOOD)
	var ready: bool = o.get("ready", false)
	var taken: bool = o.get("taken", false)
	var lift: float = o.get("lift", 0.0)
	var pulse: float = o.get("pulse", 0.5)
	var t: float = o.get("t", 0.0)
	var band: Color = GOLD.darkened(0.12) if rich else IRON
	var ink := Palette.OUTLINE
	# Set down on the floor: a soft shadow falling to the lower right, darker right under it.
	b.contact(at + Vector2(2.5, 13.0), 15.5, 0.5, 0.32)
	b.contact(at + Vector2(0.5, 12.5), 12.0, 0.4, 0.22)
	if ready and not taken:
		b.soft(at + Vector2(0, 2), Vector2(24, 18), Color(READY, 0.1 + 0.08 * pulse))
	# The body: its outline, then the front face (in the lid's shadow at the top).
	b.rect(Rect2(at + Vector2(-13, -2), Vector2(26, 16)), ink)
	var front := Rect2(at + Vector2(-11.5, 0), Vector2(23, 12.5))
	b.box(front, wood.darkened(0.08), Shade.WOOD)
	b.grad_rect(Rect2(front.position, Vector2(front.size.x, 3.0)), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.0))
	b.line(at + Vector2(-11.5, 6.4), at + Vector2(11.5, 6.4), Color(wood.darkened(0.5), 0.8), 0.8)  # the planks' seam
	b.line(at + Vector2(-11.5, 7.2), at + Vector2(11.5, 7.2), Color(wood.lightened(0.25), 0.35), 0.6)
	b.grad_rect(Rect2(front.position + Vector2(0, front.size.y - 2.0), Vector2(front.size.x, 2.0)), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.3))  # (meeting the floor)
	# Iron (or gilt) bands down the front, with their rivets.
	for x in [-8.0, 6.0]:
		var r := Rect2(at + Vector2(x, 0), Vector2(2.6, 12.5))
		b.rect(r.grow(0.5), Color(ink, 0.7))
		b.box(r, band, Shade.METAL)
		_rivet(b, at + Vector2(x + 1.3, 3.0), band)
		_rivet(b, at + Vector2(x + 1.3, 9.8), band)
	if rich:  # gilt corner caps
		for sx in [-1.0, 1.0]:
			var cr := Rect2(at + Vector2(-11.5 if sx < 0 else 8.5, 9.5), Vector2(3.0, 3.0))
			b.box(cr, GOLD, Shade.METAL)
	if taken:
		_open_lid(b, at, wood, band, rich)
		return
	# The lid, raised by `lift` (a mimic's breath).
	var up := Vector2(0, -lift)
	b.rect(Rect2(at + Vector2(-13, -10) + up, Vector2(26, 11)), ink)
	var top := Rect2(at + Vector2(-12, -9) + up, Vector2(24, 7.5))
	b.box(top, wood.lightened(0.14), Shade.WOOD)
	b.line(top.position + Vector2(0.8, 0.7), Vector2(top.end.x - 0.8, top.position.y + 0.7), Color(wood.lightened(0.55), 0.55), 0.9)  # its lit edge
	var lip := Rect2(at + Vector2(-12, -1.5) + up, Vector2(24, 2.2))  # the lid's front edge, facing us: shaded
	b.box(lip, wood.darkened(0.22), Shade.WOOD)
	for x in [-8.0, 6.0]:  # the bands carry on over the lid
		var r2 := Rect2(at + Vector2(x, -9) + up, Vector2(2.6, 9.7))
		b.box(r2, band.lightened(0.08), Shade.METAL)
		_rivet(b, at + Vector2(x + 1.3, -6.5) + up, band)
	if rich:  # gilt trim round the lid
		b.rect(Rect2(top.position, Vector2(top.size.x, 1.2)), Color(GOLD, 0.95))
		b.rect(Rect2(lip.position, Vector2(lip.size.x, 0.9)), Color(GOLD.darkened(0.2), 0.95))
		var g := fposmod(t * 0.35 + at.x * 0.01, 1.0)  # a glint travelling along the gilt now and then
		if g < 0.3:
			var gx := lerpf(-11.0, 11.0, g / 0.3)
			_glint(b, at + Vector2(gx, -9.0) + up, 2.6 * sin(PI * g / 0.3))
	# The lock plate on the seam, its keyhole, and the light it catches.
	var lock := READY if ready else SHUT
	var plate := Rect2(at + Vector2(-2.8, -2.5), Vector2(5.6, 6.5))
	b.rect(plate.grow(0.7), ink)
	if ready:
		b.soft(plate.get_center(), Vector2(7, 7), Color(READY, 0.35 + 0.3 * pulse))
		b.box(plate, lock.lerp(Color.WHITE, 0.15 * pulse), Shade.METAL)
	else:
		b.box(plate, lock, Shade.METAL)
	b.disc(plate.get_center() + Vector2(0, -0.3), 1.0, Palette.OUTLINE)
	b.rect(Rect2(plate.get_center() + Vector2(-0.4, 0.2), Vector2(0.8, 1.6)), Palette.OUTLINE)
	b.circle(plate.position + Vector2(1.3, 1.2), 0.75, Color(1, 1, 1, 0.75), 10)


## The lid thrown back and the chest standing open and empty.
static func _open_lid(b, at: Vector2, wood: Color, band: Color, rich: bool) -> void:
	var ink := Palette.OUTLINE
	# The lid leaning back, its underside toward us (in shade).
	b.rect(Rect2(at + Vector2(-12.5, -13.5), Vector2(25, 7)), ink)
	var under := Rect2(at + Vector2(-11.5, -12.5), Vector2(23, 5))
	b.box(under, wood.darkened(0.38), Shade.WOOD)
	for x in [-8.0, 6.0]:
		b.box(Rect2(at + Vector2(x, -12.5), Vector2(2.6, 5)), band.darkened(0.25), Shade.METAL)
	if rich:
		b.rect(Rect2(under.position, Vector2(under.size.x, 0.9)), Color(GOLD.darkened(0.2), 0.9))
	# The open mouth: the far wall lit, the inside falling into shadow.
	b.rect(Rect2(at + Vector2(-13, -7.5), Vector2(26, 8.5)), ink)
	b.grad_rect(Rect2(at + Vector2(-11.5, -6.5), Vector2(23, 7)), wood.darkened(0.45), INSIDE)
	b.rect(Rect2(at + Vector2(-11.5, -6.5), Vector2(23, 1.2)), Color(wood.lightened(0.1), 0.7))  # the back rim, lit
	b.rect(Rect2(at + Vector2(-12, -0.6), Vector2(24, 1.6)), wood.lightened(0.05))  # the front rim


static func _rivet(b, p: Vector2, col: Color) -> void:
	b.circle(p, 0.85, col.darkened(0.45), 10)
	b.circle(p + Vector2(-0.25, -0.3), 0.45, Color(col.lightened(0.6), 0.9), 8)


## A four-point glint, `r` long.
static func _glint(b, p: Vector2, r: float) -> void:
	if r < 0.3:
		return
	var w := Color(1.0, 0.97, 0.85, 0.9)
	b.line(p + Vector2(-r, 0), p + Vector2(r, 0), w, 0.7)
	b.line(p + Vector2(0, -r), p + Vector2(0, r), w, 0.7)
	b.circle(p, 0.7, w, 10)
