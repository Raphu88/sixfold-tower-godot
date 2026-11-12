extends Node2D
## An arrow. Monsters' arrows: roll through to fill your legs, or parry to send
## them back. Friendly arrows (yours, or reflected ones) hit monsters instead.

const Draw := preload("res://scripts/draw_util.gd")
const Pacts := preload("res://scripts/pacts.gd")

var main
var vel := Vector2.ZERO
var dmg := 8.0
var life := 2.5
var dodged := false
var reflected := false  # parried arrows fly back and hurt monsters
var friendly := false
var pierce := false  # a fully drawn arrow passes through foes
var heavy := false  # a crossbow bolt: its hit breaks poise like a heavy blow
var force := 140.0
var hit: Array = []
var style := "arrow"  # or "blade": a conjured blade
var tint := Color.WHITE
var poison := 0.0  # seconds of poison a landed hit gives the climber
var venom := 0  # Venomist's spit: poison stacks it puts on a foe
var explode_r := 0.0  # a fireball: explodes on impact (or at the end of its flight)
var explode_dmg := 0.0
var cluster := 0  # Cluster Blast: splits into this many explosions
var return_to = null  # Recall: blades that come back to this node
var out_t := 0.0  # how long before a recalled blade turns back
var returning := false
var weapon := false  # the climber's own bow, crossbow or pistol shot (spells' shots don't fill the hand or carry the weapon's rules)
var fills := true  # a weapon shot fills the hand's mark (an enchanted pistol's essence shot doesn't)
var shot := ""  # an enchanted pistol's essence shot: its essence (weapons.gd ESSENCE_SHOT)
var splice := {}  # the Developer's Splice: a spliced spell's shot carries its behaviour (secret_tools.gd)
## Marks' spells (scripts/spells/): fn(shot, foe) after it strikes a foe, and
## fn(shot, where) once when it ends (on a foe, a wall, or at the end of its flight).
var on_strike: Array = []
var on_end: Array = []


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if return_to != null and is_instance_valid(return_to):
		# Recall: fly out, turn back (after a while, a hit, or a wall), and
		# cut again on the way home.
		out_t -= delta
		if not returning and (out_t <= 0.0 or not hit.is_empty() or not main.room.has_point(position)):
			returning = true
			hit.clear()
		if returning:
			var home: Vector2 = return_to.global_position - position
			vel = home.normalized() * maxf(vel.length(), 520.0)
			if home.length() < 18.0 or life <= -1.5:
				queue_free()
				return
	elif life <= 0.0 or not main.room.has_point(position):
		_burst()
		_ended()
		queue_free()
		return
	# Crosswind: a wall of wind turns enemy arrows back at their shooter.
	if not friendly:
		for w in main.walls:
			if Geometry2D.segment_intersects_segment(position - vel * delta, position, w["a"], w["b"]) != null:
				reflected = true
				friendly = true
				vel = -vel
				main.fx_burst(position, vel.normalized(), w["color"], 6, 180.0)
				break
	# The walls between rooms stop every shot.
	if return_to == null and main.is_solid(position):
		_burst()
		_ended()
		main.fx_burst(position, -vel.normalized(), Color(0.8, 0.75, 0.7), 4, 140.0)
		if friendly and style in ["arrow", "bolt"]:
			main.sfx("arrow_hit", 1.25, -12.0)  # your arrow thunks into the wall
		queue_free()
		return
	# Sandshaper's walls stop monsters' shots.
	if not friendly and main.blocks_shot(position):
		main.fx_burst(position, -vel.normalized(), Color(0.85, 0.7, 0.42), 5, 160.0)
		queue_free()
		return
	for pl in main.pillars:
		if return_to == null and position.distance_to(pl["pos"]) < pl["r"]:
			_burst()
			_ended()
			main.fx_burst(position, -vel.normalized(), Color(0.8, 0.75, 0.7), 5, 160.0)
			main.sfx("arrow_hit", 1.2, -8.0)
			queue_free()
			return
	# The climber's arrows light the puzzle's eyes (and stop there).
	if friendly and return_to == null and main.puzzle != null and main.puzzle.shot(position):
		_burst()
		_ended()
		main.sfx("arrow_hit", 1.1, -6.0)
		queue_free()
		return
	if friendly:
		for e in main.targets():
			if e in hit:
				continue
			if position.distance_to(e.global_position) < e.radius + 4.0:
				hit.append(e)
				if not splice.is_empty() and main.secret_tools != null:
					main.secret_tools.splice_hit(e, splice)
				if venom > 0:
					e.add_venom(venom)
				if explode_r > 0.0:
					_burst()
					_ended()
					queue_free()
					return
				main.player.ranged_hit(e, dmg, vel.normalized(), force, pierce or reflected or heavy, weapon, shot, fills)
				for fn in on_strike:
					if fn.is_valid():
						fn.call(self, e)
				# Whirling Steel (Blade Forger and Windwalker): a conjured blade lifts a light foe.
				if style == "blade" and is_instance_valid(e) and not e.dead and not e.is_boss() and Pacts.has(main.player, "whirling_steel") \
						and float(e.weight) <= Pacts.num("whirling_steel", "weight") and e.airborne <= 0.0:
					e.lift(Pacts.num("whirling_steel", "lift"))
				if not pierce:
					_ended()
					queue_free()
					return
		queue_redraw()
		return
	# Monsters set against each other (the Manipulator, secret_tools.gd): their shots hit each other.
	if main.secret_tools != null and main.secret_tools.feuds > 0:
		for e in main.targets():
			if e.feud != null and position.distance_to(e.global_position) < e.radius * 0.8:
				e.take_hit(dmg, vel.normalized(), 80.0)
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
		var before: float = p.hp
		p.receive_attack(dmg, self)
		if poison > 0.0 and p.hp < before:
			p.poison(poison)
		queue_free()
		return
	queue_redraw()


func _ended() -> void:
	var fns := on_end
	on_end = []
	for fn in fns:
		if fn.is_valid():
			fn.call(self, position)


## A fireball goes off: one explosion, or a cluster of three around the impact.
func _burst() -> void:
	if explode_r <= 0.0:
		return
	var r := explode_r
	explode_r = 0.0
	if cluster > 0:
		for i in cluster:
			main.explode(position + Vector2.from_angle(TAU * i / cluster + vel.angle()) * r * 0.8, r, explode_dmg, tint)
	else:
		main.explode(position, r, explode_dmg, tint)


func on_parried(_perfect := false) -> void:
	reflected = true
	friendly = true
	dmg *= 2.0
	force = 220.0
	life = 2.5
	vel = main.player.aim * vel.length() * 1.5


## Drawn as one batch of quads and circles: torchlight falls on arrows, and
## Godot lights a wide draw_line only half (see draw_util.gd).
func _draw() -> void:
	var b := Draw.Batch.new()
	_draw_into(b)
	b.flush(self)


func _draw_into(c) -> void:
	var dir := vel.normalized()
	var side := dir.orthogonal()
	if style == "ink":
		# A glob of ink with a dark smear behind it.
		c.draw_line(-dir * 18.0, Vector2.ZERO, Color(0.1, 0.06, 0.14, 0.5), 7.0)
		c.draw_circle(Vector2.ZERO, 5.5, Color(0.08, 0.05, 0.1))
		c.draw_circle(Vector2(-1.5, -1.5), 2.0, Color(0.5, 0.35, 0.6, 0.8))
		c.draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.35, 0.3, 0.18))
		return
	if style == "fireball":
		c.draw_line(-dir * 22.0, Vector2.ZERO, Color(tint, 0.35), 9.0)
		c.draw_circle(Vector2.ZERO, 8.0, Color(tint, 0.95))
		c.draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.92, 0.6))
		c.draw_circle(Vector2.ZERO, 14.0, Color(tint, 0.18))
		return
	if style == "venom":
		# A glob of venom with a dripping trail.
		c.draw_line(-dir * 16.0, Vector2.ZERO, Color(tint, 0.4), 5.0)
		c.draw_circle(Vector2.ZERO, 4.5, Color(tint, 0.95))
		c.draw_circle(Vector2(-1.2, -1.2), 1.6, Color(1, 1, 1, 0.7))
		return
	if style == "spike":
		# A barbed tail spike, its tip green with venom.
		c.draw_line(-dir * 12.0, dir * 6.0, Color(0.06, 0.05, 0.07), 4.0)
		c.draw_line(-dir * 12.0, dir * 6.0, Color(0.85, 0.72, 0.5), 2.0)
		c.draw_circle(dir * 6.0, 2.2, Color(0.55, 0.85, 0.35))
		c.draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.35, 0.3, 0.18))
		return
	if style == "ember":
		# A burning ember with a short flame trail.
		c.draw_line(-dir * 14.0, Vector2.ZERO, Color(1.0, 0.45, 0.15, 0.5), 6.0)
		c.draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.6, 0.2))
		c.draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.92, 0.6))
		c.draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.4, 0.2, 0.2))
		return
	if style == "feather":
		# The Gryphon's feathers: a quill with a vane.
		c.draw_line(-dir * 12.0, dir * 8.0, Color(0.06, 0.05, 0.07), 3.0)
		c.draw_line(-dir * 12.0, dir * 8.0, Color(0.95, 0.9, 0.8), 1.5)
		for k in 3:
			var at := -dir * (2.0 + 4.0 * k)
			c.draw_line(at, at - dir * 3.0 + side * 4.0, Color(tint, 0.9), 1.5)
			c.draw_line(at, at - dir * 3.0 - side * 4.0, Color(tint, 0.9), 1.5)
		c.draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.35, 0.3, 0.2))
		return
	if style == "essence":
		# A streak of essence: a bright head and a long fading tail.
		c.draw_line(-dir * 40.0, Vector2.ZERO, Color(tint, 0.3), 5.0)
		c.draw_line(-dir * 22.0, dir * 4.0, Color(tint.lightened(0.3), 0.95), 2.5)
		c.draw_circle(Vector2.ZERO, 7.0, Color(tint, 0.25))
		return
	if style == "blade":
		# A glowing conjured blade with a faint trail.
		c.draw_line(-dir * 26.0, -dir * 6.0, Color(tint, 0.25), 5.0)
		var blade := PackedVector2Array([dir * 11.0, side * 3.0, -dir * 7.0, -side * 3.0])
		c.draw_colored_polygon(blade, Color(tint, 0.9))
		c.draw_line(-dir * 5.0, dir * 9.0, Color(1, 1, 1, 0.9), 1.0)
		c.draw_circle(Vector2.ZERO, 6.0, Color(tint, 0.2))
		return
	if style == "shot":
		# A pistol's lead ball: small, hot and fast, with a short bright streak.
		c.draw_line(-dir * 26.0, Vector2.ZERO, Color(1.0, 0.86, 0.55, 0.28), 3.5)
		c.draw_line(-dir * 10.0, Vector2.ZERO, Color(1.0, 0.94, 0.75, 0.7), 2.0)
		c.draw_circle(Vector2.ZERO, 2.8, Color(0.06, 0.05, 0.07))
		c.draw_circle(Vector2.ZERO, 2.0, Color(0.62, 0.62, 0.66))
		c.draw_circle(Vector2(-0.6, -0.6), 0.8, Color(1, 1, 1, 0.7))
		if not friendly:
			c.draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.35, 0.3, 0.25))  # (a monster's shot glows red, as its arrows do)
		return
	if style == "bolt":
		# A crossbow bolt: short, thick and fast, with a long streak.
		c.draw_line(-dir * 40.0, -dir * 6.0, Color(1.0, 0.9, 0.6, 0.22), 5.0)
		c.draw_line(-dir * 10.0, dir * 4.0, Color(0.06, 0.05, 0.07), 4.5)
		c.draw_line(-dir * 10.0, dir * 4.0, Color(0.6, 0.45, 0.3), 2.6)
		c.draw_colored_polygon(PackedVector2Array([dir * 10.0, dir * 3.0 + side * 3.5, dir * 3.0 - side * 3.5]), Color(0.85, 0.87, 0.92))
		c.draw_line(-dir * 10.0 + side * 3.0, -dir * 6.0, Color(0.85, 0.3, 0.25), 1.5)
		c.draw_line(-dir * 10.0 - side * 3.0, -dir * 6.0, Color(0.85, 0.3, 0.25), 1.5)
		return
	var glow := Color(1.0, 0.35, 0.3)  # monsters' arrows glow red so you can see them
	if reflected or pierce:
		glow = Color(1.0, 0.85, 0.4)
	elif friendly:
		glow = Color(0.75, 0.95, 0.8)
	# Motion streak, shaft, head and fletching.
	c.draw_line(-dir * 30.0, -dir * 8.0, Color(glow, 0.18), 4.0)
	c.draw_line(-dir * 14.0, dir * 4.0, Color(0.06, 0.05, 0.07), 3.5)
	c.draw_line(-dir * 14.0, dir * 4.0, Color(0.72, 0.55, 0.35), 1.8)
	c.draw_colored_polygon(PackedVector2Array([dir * 9.0, dir * 3.0 + side * 3.0, dir * 3.0 - side * 3.0]), Color(0.85, 0.87, 0.92))
	c.draw_line(-dir * 14.0, -dir * 18.0 + side * 3.5, Color(0.9, 0.88, 0.85), 1.5)
	c.draw_line(-dir * 14.0, -dir * 18.0 - side * 3.5, Color(0.9, 0.88, 0.85), 1.5)
	c.draw_circle(dir * 5.0, 5.0, Color(glow, 0.22))
