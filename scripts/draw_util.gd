extends RefCounted
## Shared drawing helpers for the code-drawn characters: outlined, shaded
## shapes and soft shadows. Every function draws onto the CanvasItem passed in.

const Palette := preload("res://scripts/palette.gd")


## A soft oval shadow on the floor.
static func shadow(c: CanvasItem, pos: Vector2, r: float, alpha := 0.35) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(1.0, 0.45))
	c.draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, alpha * 0.5))
	c.draw_circle(Vector2.ZERO, r * 0.85, Color(0, 0, 0, alpha * 0.6))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A ball lit from the top-left: dark outline, shaded side, highlight.
static func ball(c: CanvasItem, pos: Vector2, r: float, col: Color, outline := true) -> void:
	if outline:
		c.draw_circle(pos, r + 1.6, Palette.OUTLINE)
	c.draw_circle(pos, r, col.darkened(0.35))
	c.draw_circle(pos + Vector2(-r * 0.12, -r * 0.14), r * 0.86, col)
	c.draw_circle(pos + Vector2(-r * 0.32, -r * 0.36), r * 0.34, Color(col.lightened(0.45), 0.55))


## An outlined polygon with a flat fill.
static func poly(c: CanvasItem, pts: PackedVector2Array, col: Color, outline := 1.6) -> void:
	if outline > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, Palette.OUTLINE, outline * 2.0, true)
	c.draw_colored_polygon(pts, col)


## A thick outlined line, for blades, bows and limbs.
static func stroke(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	c.draw_line(a, b, Palette.OUTLINE, width + 2.4, true)
	c.draw_circle(a, (width + 2.4) * 0.5, Palette.OUTLINE)
	c.draw_circle(b, (width + 2.4) * 0.5, Palette.OUTLINE)
	c.draw_line(a, b, col, width, true)


## A sword lying along dir from the grip, with crossguard and pommel.
static func sword(c: CanvasItem, grip: Vector2, dir: Vector2, length: float, glint := 0.0) -> void:
	var side := dir.orthogonal()
	var tip := grip + dir * length
	stroke(c, grip - dir * 5.0, grip, Palette.WOOD.darkened(0.3), 3.0)  # hilt
	stroke(c, grip + side * 5.0, grip - side * 5.0, Palette.STEEL.darkened(0.35), 2.5)  # crossguard
	stroke(c, grip + dir * 2.0, tip, Palette.STEEL, 3.2)  # blade
	c.draw_line(grip + dir * 3.0 + side * 0.6, tip - dir * 2.0 + side * 0.6, Color(1, 1, 1, 0.55 + glint * 0.45), 1.0)
	c.draw_circle(grip - dir * 6.0, 2.2, Palette.STEEL.darkened(0.2))  # pommel


## A wobbly blob outline (slimes), as polygon points.
static func blob(center: Vector2, r: float, t: float, wobble: float, squash := Vector2.ONE, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / n * TAU
		var rr := r * (1.0 + wobble * sin(a * 3.0 + t * 5.0) + wobble * 0.6 * sin(a * 5.0 - t * 7.0))
		pts.append(center + Vector2(cos(a) * rr * squash.x, sin(a) * rr * squash.y))
	return pts
