extends Node2D
## Short-lived visual effects: floating numbers, lightning, wind cones,
## impact rings, sparks and roll afterimages.

var texts: Array = []
var bolts: Array = []
var cones: Array = []
var rings: Array = []
var sparks: Array = []
var ghosts: Array = []
var chunks: Array = []


func text(pos: Vector2, s: String, color: Color) -> void:
	texts.append({"pos": pos + Vector2(randf_range(-6.0, 6.0), 0), "text": s, "color": color, "t": 0.9})


func bolt(points: Array, color: Color) -> void:
	# Jitter each segment once so the bolt looks like lightning.
	var jagged := PackedVector2Array()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		jagged.append(a)
		for k in range(1, 4):
			var mid := a.lerp(b, k / 4.0)
			var n := (b - a).orthogonal().normalized()
			jagged.append(mid + n * randf_range(-8.0, 8.0))
	jagged.append(points[points.size() - 1])
	bolts.append({"points": jagged, "color": color, "t": 0.22})


func cone(origin: Vector2, dir: Vector2, reach: float, half: float, color: Color) -> void:
	var poly := PackedVector2Array([origin])
	var steps := 12
	for i in steps + 1:
		var ang := dir.angle() - half + (2.0 * half) * float(i) / float(steps)
		poly.append(origin + Vector2.from_angle(ang) * reach)
	cones.append({"poly": poly, "color": color, "t": 0.3})


## An expanding ring: parries, dodges, kills.
func ring(pos: Vector2, color: Color, reach: float, dur := 0.3, width := 3.0) -> void:
	rings.append({"pos": pos, "color": color, "reach": reach, "t": dur, "dur": dur, "width": width})


## A spray of sparks, thrown mostly along dir (or every way if dir is zero).
func burst(pos: Vector2, dir: Vector2, color: Color, count: int, speed := 260.0) -> void:
	for i in count:
		var d := Vector2.from_angle(randf() * TAU)
		if dir != Vector2.ZERO:
			d = dir.rotated(randf_range(-0.7, 0.7))
		var life := randf_range(0.15, 0.32)
		sparks.append({"pos": pos, "vel": d * speed * randf_range(0.5, 1.2), "color": color, "t": life, "dur": life})


## Bits of a slain monster that scatter, tumble and fade.
func debris(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var d := Vector2.from_angle(randf() * TAU)
		chunks.append({"pos": pos, "vel": d * randf_range(60.0, 220.0), "spin": randf_range(-10.0, 10.0), "rot": randf() * TAU,
			"size": randf_range(2.0, 4.5), "color": color.darkened(randf_range(0.0, 0.4)), "t": randf_range(0.6, 1.1)})


## A fading copy of the climber, left behind while it is invulnerable.
func ghost(pos: Vector2, radius: float, color: Color) -> void:
	ghosts.append({"pos": pos, "radius": radius, "color": color, "t": 0.2})


func _process(delta: float) -> void:
	for item in texts:
		item["t"] -= delta
		item["pos"] += Vector2(0, -30.0 * delta)
	for item in bolts:
		item["t"] -= delta
	for item in cones:
		item["t"] -= delta
	for item in rings:
		item["t"] -= delta
	for item in ghosts:
		item["t"] -= delta
	for item in sparks:
		item["t"] -= delta
		item["pos"] += item["vel"] * delta
		item["vel"] *= 0.88
	for c in chunks:
		c["t"] -= delta
		c["pos"] += c["vel"] * delta
		c["vel"] *= 0.9
		c["rot"] += c["spin"] * delta
	chunks = chunks.filter(func(i): return i["t"] > 0.0)
	rings = rings.filter(func(i): return i["t"] > 0.0)
	ghosts = ghosts.filter(func(i): return i["t"] > 0.0)
	sparks = sparks.filter(func(i): return i["t"] > 0.0)
	texts = texts.filter(func(i): return i["t"] > 0.0)
	bolts = bolts.filter(func(i): return i["t"] > 0.0)
	cones = cones.filter(func(i): return i["t"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for c in cones:
		var col: Color = c["color"]
		col.a = 0.35 * c["t"] / 0.3
		draw_colored_polygon(c["poly"], col)
	for c in chunks:
		var a := clampf(c["t"] / 0.4, 0.0, 1.0)
		var s: float = c["size"]
		draw_set_transform(c["pos"], c["rot"], Vector2.ONE)
		draw_rect(Rect2(-s, -s * 0.6, s * 2.0, s * 1.2), Color(0.06, 0.05, 0.07, a))
		draw_rect(Rect2(-s + 0.8, -s * 0.6 + 0.8, s * 2.0 - 1.6, s * 1.2 - 1.6), Color(c["color"], a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for g in ghosts:
		var col: Color = g["color"]
		col.a = 0.4 * g["t"] / 0.2
		draw_circle(g["pos"], g["radius"], col)
	for r in rings:
		var k: float = 1.0 - r["t"] / r["dur"]
		var col: Color = r["color"]
		col.a = 1.0 - k
		draw_arc(r["pos"], 6.0 + r["reach"] * (1.0 - pow(1.0 - k, 3.0)), 0.0, TAU, 40, col, r["width"] * (1.0 - k * 0.6))
	for sp in sparks:
		var col: Color = sp["color"]
		var k: float = sp["t"] / sp["dur"]
		var v: Vector2 = sp["vel"]
		# A soft glow under a hot core.
		draw_line(sp["pos"], sp["pos"] - v * 0.04, Color(col, 0.25 * k), 5.0)
		draw_line(sp["pos"], sp["pos"] - v * 0.03, Color(col.lightened(0.3), k), 2.0)
	for b in bolts:
		var col: Color = b["color"]
		var k: float = b["t"] / 0.22
		draw_polyline(b["points"], Color(col, 0.25 * k), 9.0)
		draw_polyline(b["points"], Color(col, k), 3.0)
		draw_polyline(b["points"], Color(1, 1, 1, 0.9 * k), 1.2)
	for t in texts:
		var col: Color = t["color"]
		var a := clampf(t["t"] / 0.4, 0.0, 1.0)
		col.a = a
		var pos: Vector2 = t["pos"]
		# Numbers pop in big, then settle.
		var age: float = 0.9 - t["t"]
		var fsize := int(14.0 + 8.0 * maxf(0.0, 1.0 - age / 0.12))
		draw_string_outline(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsize, 4, Color(0, 0, 0, 0.75 * a))
		draw_string(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsize, col)
