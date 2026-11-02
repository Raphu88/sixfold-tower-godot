extends Node2D
## An enemy arrow. Roll through it to fill your legs, or parry it to break it.

var main
var vel := Vector2.ZERO
var dmg := 8.0
var life := 2.5
var dodged := false


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or not main.room.has_point(position):
		queue_free()
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
	queue_free()


func _draw() -> void:
	var back := -vel.normalized() * 12.0
	draw_line(back, Vector2.ZERO, Color(0.87, 0.83, 0.74, 0.6), 2.0)
	draw_circle(Vector2.ZERO, 3.5, Color(0.95, 0.92, 0.85))
