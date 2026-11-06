extends Node2D
## A camp's fire, drawn in code: a ring of stones, crossed logs and
## flickering flames, with warm light and sparks rising. It is solid, so
## you walk around it.

var light_tex: Texture2D  # set by main before adding
var light: PointLight2D
var sparks: Array = []  # {pos, vel, t}
const R := 20.0


func _ready() -> void:
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit  # fire glows; it isn't dimmed by the dark
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = R
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	light = PointLight2D.new()
	light.texture = light_tex
	light.texture_scale = 4.2
	light.color = Color(1.0, 0.68, 0.38)
	light.energy = 1.5
	light.position = Vector2(0, -10)
	add_child(light)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	light.energy = 1.4 + 0.15 * sin(t * 8.0) + 0.08 * sin(t * 21.0)
	light.texture_scale = 4.1 + 0.15 * sin(t * 4.0)
	if randf() < 10.0 * delta:
		sparks.append({"pos": Vector2(randf_range(-8, 8), -14), "vel": Vector2(randf_range(-12, 12), randf_range(-60, -35)), "t": randf_range(0.6, 1.3)})
	for s in sparks:
		s["t"] -= delta
		s["pos"] += s["vel"] * delta
		s["vel"].x += randf_range(-50.0, 50.0) * delta
	sparks = sparks.filter(func(s): return s["t"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	# Warm glow on the floor.
	draw_circle(Vector2(0, 4), R * 2.4, Color(1.0, 0.55, 0.25, 0.08))
	# Ring of stones.
	for i in 9:
		var a := TAU * i / 9.0
		var at := Vector2(cos(a) * R, sin(a) * R * 0.6 + 4.0)
		draw_circle(at, 5.5, Color(0.05, 0.04, 0.05))
		draw_circle(at, 4.5, Color(0.42, 0.4, 0.42))
		draw_circle(at + Vector2(-1, -1.5), 1.8, Color(0.6, 0.58, 0.6))
	# Crossed logs.
	for d in [Vector2(14, 5), Vector2(-14, 5)]:
		draw_line(-d + Vector2(0, 4), d + Vector2(0, 4) - Vector2(0, 10), Color(0.08, 0.05, 0.03), 7.0)
		draw_line(-d + Vector2(0, 4), d + Vector2(0, 4) - Vector2(0, 10), Color(0.45, 0.28, 0.15), 5.0)
	draw_circle(Vector2(0, 2), 7.0, Color(1.0, 0.45, 0.15, 0.9))  # embers in the middle
	# Flames: a few tongues that lick up and sway.
	var tongues := [[0.0, 26.0, 9.0, Color(1.0, 0.45, 0.15)], [-6.0, 18.0, 6.0, Color(1.0, 0.55, 0.2)], [6.0, 20.0, 6.0, Color(1.0, 0.5, 0.18)], [0.0, 15.0, 5.0, Color(1.0, 0.85, 0.45)]]
	for i in tongues.size():
		var tg: Array = tongues[i]
		var h: float = tg[1] * (0.85 + 0.2 * sin(t * (9.0 + i * 2.3) + i))
		var w: float = tg[2]
		var sway := sin(t * (5.0 + i) + i * 1.7) * 3.0
		var base := Vector2(tg[0], 2)
		var poly := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(sway * 0.5 - w * 0.5, -h * 0.55), base + Vector2(sway, -h), base + Vector2(sway * 0.5 + w * 0.5, -h * 0.55), base + Vector2(w, 0)])
		draw_colored_polygon(poly, tg[3])
	for s in sparks:
		draw_circle(s["pos"], 1.4, Color(1.0, 0.75, 0.35, clampf(s["t"], 0.0, 1.0)))
