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
var motes_list: Array = []  # essence flying into the climber
var arrows_falling: Array = []  # Rain of Arrows
var main  # the room, for drawing lingering spells (rods, walls, cyclones...)


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


## Essence motes: burst out of a slain monster, then home in on `target`.
func motes(pos: Vector2, color: Color, count: int, target: Node2D) -> void:
	for i in clampi(count, 1, 14):
		var d := Vector2.from_angle(randf() * TAU)
		motes_list.append({"pos": pos, "vel": d * randf_range(80.0, 180.0), "color": color, "target": target, "age": 0.0, "delay": randf_range(0.15, 0.4)})


func falling_arrow(at: Vector2, color: Color) -> void:
	arrows_falling.append({"pos": at, "color": color, "t": 0.18})


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
	for m in motes_list:
		m["age"] += delta
		var tgt = m["target"]
		if m["age"] > m["delay"] and is_instance_valid(tgt):
			var to: Vector2 = tgt.global_position - m["pos"]
			if to.length() < 10.0:
				m["done"] = true
			m["vel"] = m["vel"].lerp(to.normalized() * 520.0, minf(1.0, 6.0 * delta))
		else:
			m["vel"] *= 0.9
		m["pos"] += m["vel"] * delta
		if m["age"] > 2.5:
			m["done"] = true
	motes_list = motes_list.filter(func(i): return not i.get("done", false))
	for a in arrows_falling:
		a["t"] -= delta
	arrows_falling = arrows_falling.filter(func(a): return a["t"] > 0.0)
	rings = rings.filter(func(i): return i["t"] > 0.0)
	ghosts = ghosts.filter(func(i): return i["t"] > 0.0)
	sparks = sparks.filter(func(i): return i["t"] > 0.0)
	texts = texts.filter(func(i): return i["t"] > 0.0)
	bolts = bolts.filter(func(i): return i["t"] > 0.0)
	cones = cones.filter(func(i): return i["t"] > 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_fields()
	var font := ThemeDB.fallback_font
	for c in cones:
		var col: Color = c["color"]
		col.a = 0.35 * c["t"] / 0.3
		draw_colored_polygon(c["poly"], col)
	for m in motes_list:
		var mc: Color = m["color"]
		draw_circle(m["pos"], 4.5, Color(mc, 0.2))
		draw_circle(m["pos"], 2.0, Color(mc.lightened(0.3), 0.95))
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


## Spells that linger in the room, drawn unlit so they always read.
func _draw_fields() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	if not main.rod.is_empty():
		var rp: Vector2 = main.rod["pos"]
		var gold := Color(0.95, 0.89, 0.42)
		draw_line(rp + Vector2(0, 6), rp + Vector2(0, -26), Color(0.06, 0.05, 0.07), 5.0)
		draw_line(rp + Vector2(0, 6), rp + Vector2(0, -26), Color(0.75, 0.75, 0.8), 2.5)
		draw_circle(rp + Vector2(0, -28), 4.0 + sin(t * 9.0), Color(gold, 0.9))
		draw_arc(rp, main.rod["reach"] * 0.15 + 6.0 * sin(t * 4.0), 0.0, TAU, 20, Color(gold, 0.25), 1.5)
	for w in main.walls:
		var c: Color = w["color"]
		var a: float = clampf(w["t"] / 0.5, 0.0, 1.0)
		draw_line(w["a"], w["b"], Color(c, 0.25 * a), 10.0)
		var dir: Vector2 = (w["b"] - w["a"]).normalized()
		for k in 6:
			var u := fmod(t * 1.5 + k / 6.0, 1.0)
			var p: Vector2 = w["a"].lerp(w["b"], u)
			draw_line(p - dir * 8.0, p + dir * 8.0, Color(1, 1, 1, 0.6 * a), 1.5)
	for cy in main.cyclones:
		var cc: Color = cy["color"]
		var ca: float = clampf(cy["t"] / 0.5, 0.0, 1.0)
		for k in 4:
			var rr: float = cy["r"] * (0.35 + 0.2 * k)
			var start := t * (3.0 - k * 0.4) + k
			draw_arc(cy["pos"], rr, start, start + 2.2, 20, Color(cc, 0.45 * ca), 2.0)
	for r in main.rains:
		draw_arc(r["pos"], r["r"], 0.0, TAU, 40, Color(r["color"], 0.35), 1.5)
	for a in arrows_falling:
		var k: float = a["t"] / 0.18
		var top: Vector2 = a["pos"] + Vector2(-6, -60) * k
		draw_line(top, top + Vector2(3, 18), Color(a["color"], 0.9), 2.0)
		if k < 0.3:
			draw_circle(a["pos"], 3.0, Color(a["color"], 0.6))
	if main.track_t > 0.0:
		var ta: float = clampf(main.track_t / 0.6, 0.0, 1.0)
		for e in main.enemies():
			draw_arc(e.global_position, e.radius + 5.0, 0.0, TAU, 20, Color(0.85, 0.63, 0.42, 0.8 * ta), 1.5)
			var v: Vector2 = e.velocity
			if v.length() > 5.0:
				draw_line(e.global_position, e.global_position + v.normalized() * 34.0, Color(0.85, 0.63, 0.42, 0.7 * ta), 1.5)
