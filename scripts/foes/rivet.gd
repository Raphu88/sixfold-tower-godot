extends "res://scripts/projectile.gd"
## A riveter's rivet (foes/riveter.gd). The first two of a burst, parried,
## only glance off; the last, glowing hot, flies back at the riveter when
## parried and knocks it out of the air.

var last := false  # the hot one: parry it to send it back
var shooter = null  # the riveter that fired it


func on_parried(perfect := false) -> void:
	if not last or shooter == null or not is_instance_valid(shooter) or shooter.dead:
		main.fx_burst(position, -vel.normalized(), Color(0.85, 0.85, 0.9), 6, 160.0)
		main.sfx("hit_armor", 1.5, -6.0)
		queue_free()  # (it glances off)
		return
	super.on_parried(perfect)
	vel = (shooter.global_position - position).normalized() * vel.length()  # (straight back at it)


func _physics_process(delta: float) -> void:
	if reflected and last and shooter != null and is_instance_valid(shooter) and not shooter.dead:
		vel = (shooter.global_position - position).normalized() * vel.length()  # (it finds its way home)
		if position.distance_to(shooter.global_position) < float(shooter.radius) + 10.0 + vel.length() * delta:  # (it reaches it this tick)
			shooter.sent_back()
	super._physics_process(delta)


func _draw_into(c) -> void:
	var dir := vel.normalized()
	var hot := Color(1.0, 0.62, 0.25) if last else Color(0.75, 0.76, 0.8)
	c.draw_line(-dir * 10.0, Vector2.ZERO, Color(hot, 0.35), 4.0)
	c.draw_line(-dir * 4.0, dir * 4.0, Color(0.06, 0.05, 0.07), 5.0)
	c.draw_line(-dir * 4.0, dir * 4.0, hot, 3.0)
	c.draw_circle(-dir * 4.0, 2.6, Color(0.06, 0.05, 0.07))
	c.draw_circle(-dir * 4.0, 1.8, hot.lightened(0.2))
	c.draw_circle(Vector2.ZERO, 8.0 if last else 6.0, Color(1.0, 0.35, 0.3, 0.22 if last else 0.15))
