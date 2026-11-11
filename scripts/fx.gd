extends Node2D
## Short-lived visual effects: floating numbers, lightning, wind cones,
## impact rings, sparks and roll afterimages.

const Draw := preload("res://scripts/draw_util.gd")

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
## Words in the world (floating numbers, gear names), drawn above the
## darkness layer so the dark never dims them.
var labels: Node2D


func _ready() -> void:
	labels = Node2D.new()
	labels.z_as_relative = false
	labels.z_index = 60  # over the darkness (40)
	labels.draw.connect(_draw_labels)
	add_child(labels)


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


## Secret essence (secret.gd) rising from a great foe: bigger, brighter motes
## that rise first, then fly to the climber. `through`: the essence that isn't
## the climber's path streaks through them and out the far side, fading.
func secret_motes(pos: Vector2, color: Color, count: int, target: Node2D, through: bool) -> void:
	for i in clampi(count, 5, 16):
		var d := Vector2.from_angle(randf() * TAU) * 0.6 + Vector2.UP
		motes_list.append({"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)), "vel": d.normalized() * randf_range(90.0, 170.0),
			"color": color, "target": target, "age": 0.0, "delay": randf_range(0.45, 0.85), "secret": true, "through": through})


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
		if m.has("out"):
			# Passed through the climber: on out the far side, fading.
			m["out"] -= delta
			m["pos"] += m["vel"] * delta
			m["vel"] *= 0.97
			if m["out"] <= 0.0:
				m["done"] = true
			continue
		if m["age"] > m["delay"] and is_instance_valid(tgt) and m.get("through", false):
			var to_t: Vector2 = tgt.global_position - m["pos"]
			if to_t.length() < 12.0:
				m["out"] = 0.5
				m["vel"] = m["vel"].normalized() * 560.0
				continue
			m["vel"] = m["vel"].lerp(to_t.normalized() * 600.0, minf(1.0, 7.0 * delta))
			m["pos"] += m["vel"] * delta
			if m["age"] > 3.0:
				m["done"] = true
			continue
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
	if labels != null and (not texts.is_empty() or (main != null and not main.gear_drops.is_empty()) or _had_labels):
		_had_labels = not texts.is_empty() or (main != null and not main.gear_drops.is_empty())
		labels.queue_redraw()


var _had_labels := false


## Whether words at `pos` would be in the climber's sight (not hidden in fog).
func _in_sight(pos: Vector2) -> bool:
	if main == null or main.fog == null or main.player == null:
		return true
	if pos.distance_to(main.player.global_position) < 160.0:
		return true
	return main.fog.sees(pos) or main.fog.sees(pos + Vector2(0, 40))


func _draw_labels() -> void:
	# Words and numbers that pop up, and names over gear: the gothic face.
	var font: Font = preload("res://scripts/ui.gd").font("display")
	for t in texts:
		var pos: Vector2 = t["pos"]
		if not _in_sight(pos):
			continue
		var col: Color = t["color"]
		var a := clampf(t["t"] / 0.4, 0.0, 1.0)
		col.a = a
		# Numbers pop in big, then settle.
		var age: float = 0.9 - t["t"]
		var fsize := int(14.0 + 8.0 * maxf(0.0, 1.0 - age / 0.12))
		labels.draw_string_outline(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsize, 4, Color(0, 0, 0, 0.75 * a))
		labels.draw_string(font, pos - Vector2(60, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsize, col)
	if main == null:
		return
	# Gear on the floor: its name over it, in its rarity's colour; a glint
	# over anything better than Common. Hunter's Keen Eyes outline it in
	# that colour even through the dark.
	var t := Time.get_ticks_msec() * 0.001
	var keen: bool = main.player != null and main.player.has_bond("hunter")
	for g in main.gear_drops:
		var gp: Vector2 = g["pos"]
		var r = g.get("rec", g["id"])
		var rc: Color = main.Gear.rarity_color(r)
		var fancy: bool = main.Gear.rarity(r) != "common"
		if keen:
			labels.draw_arc(gp, 17.0 + sin(t * 3.0) * 1.5, 0.0, TAU, 28, Color(rc, 0.85), 2.0, true)
		if not _in_sight(gp):
			continue
		var here: bool = main.gear_here == g
		var label: String = main.Gear.display(r)
		var lc: Color = (Color(1.0, 0.9, 0.65) if here else Color(0.9, 0.88, 0.85, 0.85)) if not fancy else Color(rc.lightened(0.25 if here else 0.1), 1.0 if here else 0.9)
		labels.draw_string_outline(font, gp + Vector2(-90, -20), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, 3, Color(0, 0, 0, 0.8))
		labels.draw_string(font, gp + Vector2(-90, -20), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, lc)
		if fancy:
			# A glint that turns and pulses over it: brighter for rarer finds.
			var rank: int = main.Gear.rarity_rank(main.Gear.rarity(r))
			var pulse := 0.55 + 0.45 * sin(t * 4.0 + gp.x * 0.01)
			var sc := gp + Vector2(-11, -9)
			var rr := (4.5 + 1.5 * rank) * (0.7 + 0.3 * pulse)
			var ang := t * 1.5
			for k in 4:
				var dir := Vector2.from_angle(ang + k * PI / 2.0)
				labels.draw_line(sc - dir * rr * 0.2, sc + dir * rr, Color(rc.lightened(0.4), 0.85 * pulse), 1.5, true)
			labels.draw_circle(sc, 1.6, Color(1, 1, 1, 0.9 * pulse))


func _draw() -> void:
	_draw_fields()
	for c in cones:
		var col: Color = c["color"]
		col.a = 0.35 * c["t"] / 0.3
		draw_colored_polygon(c["poly"], col)
	var motes := Draw.Batch.new()  # all motes in one draw
	for m in motes_list:
		var mc: Color = m["color"]
		if m.get("secret", false):
			# Secret essence: a glowing mote with a streak behind it (longer
			# while it passes through and out, fading as it goes).
			var k: float = clampf(m["out"] / 0.5, 0.0, 1.0) if m.has("out") else 1.0
			var v: Vector2 = m["vel"]
			var tail: float = 0.07 if m.has("out") else 0.035
			motes.line(m["pos"], m["pos"] - v * tail, Color(mc, 0.35 * k), 4.0)
			motes.line(m["pos"], m["pos"] - v * tail * 0.6, Color(mc.lightened(0.4), 0.8 * k), 1.6)
			motes.circle(m["pos"], 7.0, Color(mc, 0.18 * k), 16)
			motes.circle(m["pos"], 3.0, Color(mc.lightened(0.5), k), 12)
			continue
		motes.circle(m["pos"], 4.5, Color(mc, 0.2))
		motes.circle(m["pos"], 2.0, Color(mc.lightened(0.3), 0.95))
	motes.flush(self)
	for c in chunks:
		var a := clampf(c["t"] / 0.4, 0.0, 1.0)
		var s: float = c["size"]
		draw_set_transform(c["pos"], c["rot"], Vector2.ONE)
		draw_rect(Rect2(-s, -s * 0.6, s * 2.0, s * 1.2), Color(0.06, 0.05, 0.07, a))
		draw_rect(Rect2(-s + 0.8, -s * 0.6 + 0.8, s * 2.0 - 1.6, s * 1.2 - 1.6), Color(c["color"], a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var afterimages := Draw.Batch.new()
	for g in ghosts:
		var col: Color = g["color"]
		col.a = 0.4 * g["t"] / 0.2
		afterimages.circle(g["pos"], g["radius"], col)
	afterimages.flush(self)
	for r in rings:
		var k: float = 1.0 - r["t"] / r["dur"]
		var col: Color = r["color"]
		col.a = 1.0 - k
		draw_arc(r["pos"], 6.0 + r["reach"] * (1.0 - pow(1.0 - k, 3.0)), 0.0, TAU, 40, col, r["width"] * (1.0 - k * 0.6), true)
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


## Spells that linger in the room, drawn unlit so they always read.
func _draw_fields() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	for w in main.stone_walls:
		var wp: Vector2 = w["pos"]
		var wr: float = w["r"]
		var wa: float = clampf(w["t"] / 0.4, 0.0, 1.0)
		var stone := Color(0.7, 0.6, 0.42) if not w["fault"] else Color(0.35, 0.28, 0.22)
		draw_circle(wp + Vector2(0, 2), wr, Color(0, 0, 0, 0.35 * wa))
		draw_circle(wp, wr, Color(stone, wa))
		draw_circle(wp - Vector2(2, 2), wr * 0.6, Color(stone.lightened(0.15), wa))
	for r in main.rubble:
		var ra: float = clampf(r["t"] / 0.5, 0.0, 1.0)
		for i in 10:
			var ang := TAU * i / 10.0 + float(i) * 0.7
			var at: Vector2 = r["pos"] + Vector2.from_angle(ang) * r["r"] * (0.3 + 0.6 * fmod(i * 0.37, 1.0))
			draw_circle(at, 3.0 + fmod(i * 1.3, 3.0), Color(0.6, 0.5, 0.36, 0.7 * ra))
	for pt in main.pits:
		var pa: float = clampf(pt["t"] / 0.5, 0.0, 1.0)
		draw_circle(pt["pos"], pt["r"], Color(0.06, 0.04, 0.03, 0.85 * pa))
		draw_arc(pt["pos"], pt["r"], 0.0, TAU, 28, Color(0.7, 0.58, 0.4, 0.8 * pa), 3.0)
	for cl in main.clouds:
		var ca: float = clampf(cl["t"] / 0.6, 0.0, 1.0)
		var cc: Color = cl["color"]
		for i in 7:
			var ang := TAU * i / 7.0 + t * 0.4
			draw_circle(cl["pos"] + Vector2.from_angle(ang) * cl["r"] * 0.5, cl["r"] * 0.45, Color(cc, 0.12 * ca))
		draw_arc(cl["pos"], cl["r"], 0.0, TAU, 32, Color(cc, 0.3 * ca), 1.5)
	for sm in main.smokes:
		var sa: float = clampf(sm["t"] / 0.8, 0.0, 1.0)
		for i in 9:
			var ang := TAU * i / 9.0 - t * 0.25
			draw_circle(sm["pos"] + Vector2.from_angle(ang) * sm["r"] * 0.5, sm["r"] * 0.5, Color(0.42, 0.4, 0.42, 0.22 * sa))
	for d in main.decoys:
		var da: float = clampf(d["t"] / 0.8, 0.0, 1.0)
		draw_circle(d["pos"], 12.0, Color(0.55, 0.5, 0.5, 0.75 * da))
		draw_circle(d["pos"] + d["aim"] * 4.0, 7.0, Color(0.45, 0.4, 0.4, 0.85 * da))
		draw_circle(d["pos"] + Vector2(sin(t * 3.0) * 4.0, -16.0 - fmod(t * 20.0, 10.0)), 1.5, Color(1.0, 0.55, 0.25, 0.8 * da))
	if main.ashfall_t > 0.0 and main.player != null:
		var aa := clampf(main.ashfall_t / 1.0, 0.0, 1.0)
		for i in 60:
			var ax: float = fmod(i * 97.3 + t * (12.0 + i % 7), 1200.0) - 600.0
			var ay: float = fmod(i * 53.1 + t * (30.0 + i % 5 * 6.0), 700.0) - 350.0
			draw_circle(main.player.global_position + Vector2(ax, ay), 1.4, Color(0.65, 0.62, 0.6, 0.55 * aa))
	for rn in main.runes:
		var rc: Color = rn["color"]
		var rp: Vector2 = rn["pos"]
		draw_circle(rp, rn["r"], Color(rc, 0.12))
		draw_arc(rp, rn["r"], 0.0, TAU, 24, Color(rc, 0.75), 1.5)
		for i in 3:
			var ra := t * 0.8 + TAU * i / 3.0
			draw_line(rp + Vector2.from_angle(ra) * 6.0, rp + Vector2.from_angle(ra + 2.0) * rn["r"] * 0.8, Color(rc, 0.6), 1.5)
		if rn["linked"]:
			for other in main.runes:
				if other != rn:
					draw_line(rp, other["pos"], Color(rc, 0.15), 1.0)
	for wd in main.wards:
		var wc: Color = wd["color"]
		var wa: float = clampf(wd["t"] / 0.5, 0.0, 1.0)
		draw_arc(wd["pos"], wd["r"], 0.0, TAU, 48, Color(wc, 0.8 * wa), 3.0, true)
		for i in 12:
			var ta := TAU * i / 12.0 - t * 0.5
			var tp: Vector2 = wd["pos"] + Vector2.from_angle(ta) * wd["r"]
			draw_line(tp, tp + Vector2.from_angle(ta) * 7.0, Color(wc, 0.7 * wa), 2.0)
	for sg in main.sigils:
		var sc: Color = sg["color"]
		var sa: float = clampf(sg["t"] / 0.5, 0.0, 1.0)
		draw_circle(sg["pos"], sg["r"], Color(sc, 0.06 * sa))
		draw_arc(sg["pos"], sg["r"], 0.0, TAU, 64, Color(sc, 0.7 * sa), 2.5, true)
		draw_arc(sg["pos"], sg["r"] * 0.7, t * 0.3, t * 0.3 + TAU, 48, Color(sc, 0.4 * sa), 1.5)
		for i in 6:
			var ga := TAU * i / 6.0 + t * 0.3
			draw_circle(sg["pos"] + Vector2.from_angle(ga) * sg["r"] * 0.85, 3.0, Color(sc, 0.7 * sa))
	for g in main.graft_drops:
		var gp: Vector2 = g["pos"] + Vector2(0, sin(t * 4.0) * 2.0)
		draw_circle(gp, 7.0, Color(0.55, 0.35, 0.5, 0.9))
		draw_line(gp + Vector2(-5, -2), gp + Vector2(5, 2), Color(0.95, 0.85, 0.9), 1.5)
		draw_line(gp + Vector2(-3, 3), gp + Vector2(3, -3), Color(0.95, 0.85, 0.9), 1.0)
		draw_arc(gp, 10.0, 0.0, TAU, 16, Color(0.75, 0.55, 0.7, 0.5), 1.5)
	for it in main.item_drops:
		var ip: Vector2 = it["pos"] + Vector2(0, sin(t * 3.5) * 2.5 - 4.0)
		var ic: Color = main.Items.color(it["id"])
		var ia: float = clampf(it["t"] / 3.0, 0.0, 1.0)
		draw_circle(it["pos"] + Vector2(0, 6), 9.0, Color(0, 0, 0, 0.3 * ia))
		draw_arc(ip, 13.0 + sin(t * 5.0), 0.0, TAU, 20, Color(ic, 0.45 * ia), 1.5)
		main.Items.draw_icon(self, it["id"], ip, 9.0, ia)
	# Gear on the floor: its icon on a little glowing plinth in its rarity's
	# colour (its name and glint are in _draw_labels).
	for g in main.gear_drops:
		var gp: Vector2 = g["pos"]
		var grec = g.get("rec", g["id"])
		var gc: Color = main.Gear.color(grec)
		var here: bool = main.gear_here == g
		var fancy: bool = main.Gear.rarity(grec) != "common"
		var ring_c: Color = main.Gear.rarity_color(grec) if fancy else Color(1.0, 0.85, 0.5)
		draw_circle(gp + Vector2(0, 7), 11.0, Color(0, 0, 0, 0.3))
		if fancy:
			draw_circle(gp, 16.0, Color(ring_c, 0.12))
		draw_arc(gp, 15.0 + sin(t * 3.0) * 1.5, 0.0, TAU, 24, Color(ring_c, 0.85 if here else (0.6 if fancy else 0.35)), 2.0 if here or fancy else 1.5)
		var ip2 := gp + Vector2(0, sin(t * 2.5) * 1.5 - 3.0)
		main.Gear.draw_icon(self, g.get("rec", g["id"]), ip2 + Vector2(1, 1), 10.0, Color(0, 0, 0, 0.6))
		main.Gear.draw_icon(self, g.get("rec", g["id"]), ip2, 10.0, gc)
	# Fire Flasks in flight: an arc from your hand to where they'll burst.
	for f in main.flasks:
		var k: float = clampf(f["t"] / maxf(f["total"], 0.01), 0.0, 1.0)
		var fp: Vector2 = f["from"].lerp(f["to"], k) + Vector2(0, -sin(k * PI) * 34.0)
		draw_circle(f["from"].lerp(f["to"], k) + Vector2(0, 6), 5.0, Color(0, 0, 0, 0.25))
		var fid: String = f.get("id", "fire_flask")
		draw_arc(f["to"], f["r"], 0.0, TAU, 32, Color(main.Items.color(fid), 0.25 + 0.3 * k), 1.5, true)
		main.Items.draw_icon(self, fid, fp, 7.0)
	for m in main.meteors:
		var mk: float = clampf(1.0 - m["t"] / 0.6, 0.0, 1.0)
		draw_circle(m["pos"], m["r"], Color(m["color"], 0.08 + 0.12 * mk))
		draw_arc(m["pos"], m["r"], 0.0, TAU, 48, Color(m["color"], 0.7), 2.5, true)
		draw_circle(m["pos"] + Vector2(0, -260.0 * (1.0 - mk)), 10.0 + 6.0 * mk, Color(1.0, 0.6, 0.25, 0.9))
	for fl in main.flames:
		var fade: float = clampf(fl["t"] / 0.5, 0.0, 1.0)
		var fp: Vector2 = fl["pos"]
		var fr: float = fl["r"]
		var fcol := Color(1.0, 0.35, 0.1) if not fl.get("friendly", false) else Color(1.0, 0.6, 0.15)
		draw_circle(fp, fr, Color(fcol, 0.22 * fade))
		for i in 6:
			var a := TAU * i / 6.0 + t * 0.7
			var at := fp + Vector2.from_angle(a) * fr * 0.55
			var h := 6.0 + 4.0 * sin(t * 12.0 + i * 2.1)
			draw_line(at, at + Vector2(0, -h), Color(1.0, 0.6, 0.2, 0.7 * fade), 3.0)
		draw_arc(fp, fr, 0.0, TAU, 24, Color(1.0, 0.5, 0.2, 0.45 * fade), 1.5)
	if not main.rod.is_empty():
		var rp: Vector2 = main.rod["pos"]
		var gold := Color(0.95, 0.89, 0.42)
		draw_line(rp + Vector2(0, 6), rp + Vector2(0, -26), Color(0.06, 0.05, 0.07), 5.0)
		draw_line(rp + Vector2(0, 6), rp + Vector2(0, -26), Color(0.75, 0.75, 0.8), 2.5)
		draw_circle(rp + Vector2(0, -28), 4.0 + sin(t * 9.0), Color(gold, 0.9))
		draw_arc(rp, main.rod["reach"] * 0.15 + 6.0 * sin(t * 4.0), 0.0, TAU, 20, Color(gold, 0.25), 1.5)
		# Its reach on the floor, and a flash at each beat; it brightens as its burst nears.
		var fk: float = clampf(float(main.rod.get("flash", 1.0)) / 0.3, 0.0, 1.0)
		var near_end: float = 1.0 - clampf(float(main.rod.get("t", 9.0)) / 1.5, 0.0, 1.0)
		draw_arc(rp, float(main.rod.get("radius", 0.0)), 0.0, TAU, 40, Color(gold, 0.12 + 0.2 * near_end), 1.0, true)
		draw_circle(rp + Vector2(0, -28), 9.0 * (1.0 - fk) + 3.0 * near_end, Color(gold, 0.35 * (1.0 - fk) + 0.2 * near_end))
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
	for w in main.waves:
		var side: Vector2 = w["dir"].orthogonal()
		var half: float = w["width"] * 0.5
		var wp: Vector2 = w["pos"]
		draw_line(wp - side * half, wp + side * half, Color(w["color"], 0.85), 5.0)
		draw_line(wp - side * half - w["dir"] * 10.0, wp + side * half - w["dir"] * 10.0, Color(w["color"], 0.3), 9.0)
		for k in 4:
			# Foam drifts along the crest (no new random spot every frame: that flickers).
			var foam := wp + side * half * sin(t * (1.3 + k * 0.4) + k * 2.1)
			draw_circle(foam, 2.0, Color(1, 1, 1, 0.6))
	for m in main.maelstroms:
		var mc: Color = m["color"]
		for k in 5:
			var rr: float = m["r"] * (0.2 + 0.18 * k)
			var st := -t * (2.0 + k * 0.5) + k
			draw_arc(m["pos"], rr, st, st + 2.6, 22, Color(mc, 0.5), 2.0)
	for r in main.rains:
		draw_arc(r["pos"], r["r"], 0.0, TAU, 40, Color(r["color"], 0.35), 1.5, true)
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
