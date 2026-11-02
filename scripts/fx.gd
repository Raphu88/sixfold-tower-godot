extends Node2D
## Short-lived visual effects: floating numbers, lightning, wind cones,
## impact rings, sparks and roll afterimages.

var texts: Array = []
var bolts: Array = []
var cones: Array = []
var rings: Array = []
var sparks: Array = []
var ghosts: Array = []


func text(pos: Vector2, s: String, color: Color) -> void:
	texts.append({"pos": pos, "text": s, "color": color, "t": 0.9})


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
		col.a = sp["t"] / sp["dur"]
		var v: Vector2 = sp["vel"]
		draw_line(sp["pos"], sp["pos"] - v * 0.03, col, 2.0)
	for b in bolts:
		var col: Color = b["color"]
		draw_polyline(b["points"], col, 3.0)
		draw_polyline(b["points"], Color(1, 1, 1, 0.8), 1.0)
	for t in texts:
		var col: Color = t["color"]
		col.a = clampf(t["t"] / 0.4, 0.0, 1.0)
		var pos: Vector2 = t["pos"]
		draw_string(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 14, col)
