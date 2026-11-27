extends Node2D
## A camp's fire, drawn in code: a ring of stones, crossed logs and
## flickering flames and sparks rising. It is solid, so you walk around it.
## Its warm light is cast by the darkness layer (lighting.gd).

const Draw := preload("res://scripts/draw_util.gd")
const Shade := preload("res://scripts/shade.gd")

var sparks: Array = []  # {pos, vel, t}
const R := 20.0


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = R
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
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
	# (stones and logs in the shading toolkit, lit from the top-left like the
	# room; the fire itself glows, so it stays flat and bright)
	var b := Draw.Batch.new()
	# Warm glow on the floor, and the soot-dark ash under it.
	b.soft(Vector2(0, 4), Vector2(R * 2.8, R * 2.0), Color(1.0, 0.55, 0.25, 0.24))
	b.contact(Vector2(0, 6), R * 1.05, 0.45, 0.6)
	# Ring of stones, the far ones drawn first.
	var order: Array = []
	for i in 9:
		order.append(i)
	order.sort_custom(func(x, y): return sin(TAU * x / 9.0) < sin(TAU * y / 9.0))
	for i in order:
		var a := TAU * float(i) / 9.0
		var at := Vector2(cos(a) * R, sin(a) * R * 0.6 + 4.0)
		b.contact(at + Vector2(1.5, 2.5), 4.5, 0.35)
		b.ball(at, 4.4, Color(0.44, 0.42, 0.44).lightened(0.06 * float(int(i) % 3)))
	# Crossed logs.
	for d in [Vector2(14, 5), Vector2(-14, 5)]:
		b.stroke(-d + Vector2(0, 4), d + Vector2(0, 4) - Vector2(0, 10), Color(0.45, 0.28, 0.15), 4.6, Shade.WOOD)
	b.flush(self)
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
