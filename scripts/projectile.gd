extends Node2D
## An arrow. Monsters' arrows: roll through to fill your legs, or parry to send
## them back. Friendly arrows (yours, or reflected ones) hit monsters instead.

var main
var vel := Vector2.ZERO
var dmg := 8.0
var life := 2.5
var dodged := false
var reflected := false  # parried arrows fly back and hurt monsters
var friendly := false
var pierce := false  # a fully drawn arrow passes through foes
var force := 140.0
var hit: Array = []


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or not main.room.has_point(position):
		queue_free()
		return
	if friendly:
		for e in main.enemies():
			if e in hit:
				continue
			if position.distance_to(e.global_position) < e.radius + 4.0:
				hit.append(e)
				main.player.ranged_hit(e, dmg, vel.normalized(), force, pierce or reflected)
				if not pierce:
					queue_free()
					return
		queue_redraw()
		return
	var p = main.player
	if p == null or p.dead:
		queue_redraw()
		return
	var d: float = position.distance_to(p.global_position)
	if p.iframes > 0.0:
		# Rolling through an arrow counts as a dodge.
		if not dodged and d < p.radius + 22.0:
			dodged = true
			p.on_dodge()
	elif d < p.radius + 4.0:
		p.receive_attack(dmg, self)
		queue_free()
		return
	queue_redraw()


func on_parried() -> void:
	reflected = true
	friendly = true
	dmg *= 2.0
	force = 220.0
	life = 2.5
	vel = main.player.aim * vel.length() * 1.5


func _draw() -> void:
	var back := -vel.normalized() * 12.0
	var col := Color(0.95, 0.92, 0.85)
	if reflected or pierce:
		col = Color(1.0, 0.85, 0.4)
	elif friendly:
		col = Color(0.75, 0.95, 0.8)
	draw_line(back * (1.6 if friendly else 1.0), Vector2.ZERO, Color(col, 0.6), 2.0)
	draw_circle(Vector2.ZERO, 3.5, col)
