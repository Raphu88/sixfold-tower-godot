extends Node2D
## An enemy arrow. Roll through it to fill your legs, or parry it to send it back.

var main
var vel := Vector2.ZERO
var dmg := 8.0
var life := 2.5
var dodged := false
var reflected := false  # parried arrows fly back and hurt monsters


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or not main.room.has_point(position):
		queue_free()
		return
	if reflected:
		for e in main.enemies():
			if position.distance_to(e.global_position) < e.radius + 4.0:
				main.fx_burst(position, vel.normalized(), Color(1.0, 0.85, 0.4), 8)
				main.sfx("hit_heavy")
				main.hitstop(0.06)
				e.take_hit(dmg * 2.0, vel.normalized(), 220.0)
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
	life = 2.5
	vel = main.player.aim * vel.length() * 1.5


func _draw() -> void:
	var back := -vel.normalized() * 12.0
	var col := Color(1.0, 0.85, 0.4) if reflected else Color(0.95, 0.92, 0.85)
	draw_line(back * (1.6 if reflected else 1.0), Vector2.ZERO, Color(col, 0.6), 2.0)
	draw_circle(Vector2.ZERO, 3.5, col)
