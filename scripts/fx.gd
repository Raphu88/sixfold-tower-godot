extends Node2D
## Short-lived visual effects: floating numbers, lightning, wind cones.

var texts: Array = []
var bolts: Array = []
var cones: Array = []


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


func _process(delta: float) -> void:
	for item in texts:
		item["t"] -= delta
		item["pos"] += Vector2(0, -30.0 * delta)
	for item in bolts:
		item["t"] -= delta
	for item in cones:
		item["t"] -= delta
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
	for b in bolts:
		var col: Color = b["color"]
		draw_polyline(b["points"], col, 3.0)
		draw_polyline(b["points"], Color(1, 1, 1, 0.8), 1.0)
	for t in texts:
		var col: Color = t["color"]
		col.a = clampf(t["t"] / 0.4, 0.0, 1.0)
		var pos: Vector2 = t["pos"]
		draw_string(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 14, col)
