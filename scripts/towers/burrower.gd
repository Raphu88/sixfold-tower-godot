extends "res://scripts/enemy.gd"
## THE BURROWER: the Manticore's own creature (kind "burrower"; enemy.gd
## SUBKINDS spawns it with this script). A sand-coloured, many-legged
## digger that swims under the sand, seen only as a ripple and a moving
## mound. It can't be struck down there.
##   Under the sand it closes in. When you stand on sand (a drift, a pit,
##   crumbled flagstones) and it's near, it marks the spot under you (a ring
##   in the sand), and erupts out of it a moment later: can't be parried,
##   so step or roll off the ring. Then it stays up a moment: your chance.
##   It can only swim in sand. Stand on stone and it must come up to reach
##   you: EXPOSED on the stone it crawls, slow, takes more from every blow
##   (BURROWER "exposed_mult") and can only bite (parryable). It dives again
##   as soon as it's back on sand. So lure it onto the stone.
## Off the Manticore's floors (no sand anywhere) it treats all ground as sand.
## Its essence (stone), gear and graft are in essence.gd, gear.gd and main.gd.

static var BURROWER := {
	"erupt_near": 75.0, "erupt_wind": 0.75, "erupt_radius": 40.0, "up_time": 1.4, "sink_time": 0.35,
	"crawl_speed": 0.4, "exposed_mult": 1.5, "bite_near": 46.0, "bite_wind": 0.5, "bite_reach": 52.0, "bite_mult": 0.8,
	"look_every": 0.4,
}
static var BURROWER_TEXT := {"under": "under the sand", "exposed": "Exposed!"}

var spot := Vector2.ZERO  # where it will erupt
var look_t := 0.0
var goal_sand := Vector2.INF
var said_t := 0.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "sub"
	submerged = true


func _sand(pos: Vector2) -> bool:
	var tf = main.get("tower_floor") if main != null else null
	if tf == null or not tf.has_method("is_sand"):
		return true
	return tf.is_sand(pos)


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var g := BURROWER
	said_t -= delta
	match state:
		"sub":
			submerged = true
			var on_sand := _sand(global_position)
			if not on_sand:
				_surface()
				return
			if dist < float(g["erupt_near"]) and _sand(p.global_position) and main.request_attack(self):
				spot = p.global_position
				_begin_wind("wind_erupt", float(g["erupt_wind"]))
				main.sfx("warn_lurker", 0.7, -2.0)
				velocity = Vector2.ZERO
				return
			# Swim toward the climber; at the edge of the sand, come up and crawl.
			var spd := speed / maxf(main.water_slow(global_position, false), 0.2)  # (sand doesn't slow it)
			var step: Vector2 = dir * spd
			var next: Vector2 = global_position + dir * (radius + 6.0)
			if dist > 30.0 and not _sand(next):
				if dist < 260.0:
					_surface()
					return
				step = Vector2.ZERO
			velocity = step
		"wind_erupt":
			submerged = true
			velocity = (spot - global_position).limit_length(speed * 1.5)
			if _wind(delta):
				global_position = main.walkable_point(global_position, spot, 10.0)
				submerged = false
				main.fx_burst(spot, Vector2.UP, Color(0.86, 0.72, 0.46), 22, 220.0)
				main.fx_ring(spot, Color(0.86, 0.72, 0.46), float(g["erupt_radius"]), 0.35, 4.0)
				main.sfx("spell_sand", 0.9, -2.0)
				main.shake(5.0)
				if p.global_position.distance_to(spot) < float(g["erupt_radius"]) + p.radius:
					p.receive_attack(dmg, self, true)
				_end_attack("up", float(g["up_time"]))
		"up", "recover":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				if _sand(global_position):
					state = "sink"
					state_t = float(g["sink_time"])
				else:
					state = "crawl"
		"sink":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "sub"
				submerged = true
		"crawl":
			submerged = false
			if _sand(global_position):
				state = "sink"
				state_t = float(g["sink_time"])
				velocity = Vector2.ZERO
				return
			if dist < float(g["bite_near"]) and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_bite", float(g["bite_wind"]))
				main.sfx("warn_scorpling", 0.7, -2.0)
				velocity = Vector2.ZERO
				return
			# Out of reach: back toward the nearest sand, or crawl at the climber.
			look_t -= delta
			if look_t <= 0.0:
				look_t = float(g["look_every"])
				goal_sand = _near_sand()
			var to := dir
			if dist > 140.0 and goal_sand != Vector2.INF:
				to = main.path_dir(global_position, goal_sand)
			velocity = to * speed * float(g["crawl_speed"])
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				if dist < float(g["bite_reach"]) + p.radius and absf(lunge_dir.angle_to(dir)) < 1.1:
					p.receive_attack(dmg * float(g["bite_mult"]), self)
				main.sfx("swing_light", 0.7, -4.0)
				_end_attack("up", 0.8)
		_:
			state = "sub" if _sand(global_position) else "crawl"


## Lost track of you (shade, smoke): it wanders, and comes up off the sand all the same.
func _wander(delta: float) -> void:
	if submerged and not _sand(global_position):
		_surface()
	super._wander(delta)


func _surface() -> void:
	state = "crawl"
	submerged = false
	velocity = Vector2.ZERO
	main.fx_burst(global_position, Vector2.UP, Color(0.86, 0.72, 0.46), 10, 120.0)
	if said_t <= 0.0:
		said_t = 2.0
		main.fx_text(global_position + Vector2(0, -radius - 22.0), String(BURROWER_TEXT["exposed"]), Color(1.0, 0.85, 0.5))


## The nearest sand to it (a few steps around), or INF.
func _near_sand() -> Vector2:
	for ring in range(1, 7):
		for k in 12:
			var q: Vector2 = global_position + Vector2.from_angle(k * TAU / 12.0) * ring * 30.0
			if not main.is_solid(q) and _sand(q):
				return q
	return Vector2.INF


func is_attacking() -> bool:
	return state.begins_with("wind")


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if submerged:
		main.fx_text(global_position + Vector2(0, -radius - 10.0), String(BURROWER_TEXT["under"]), Color(0.86, 0.72, 0.46))
		return
	if state == "crawl":
		amount *= float(BURROWER["exposed_mult"])
	super.take_hit(amount, dir, force, heavy, pierce)


func _hurt_voice() -> void:
	var now := Time.get_ticks_msec()
	if now < voice_at:
		return
	voice_at = now + int(randf_range(450.0, 900.0))
	main.sfx("hurt_scorpling", 0.7, -2.0)


func _leave_remains() -> void:
	main.sfx("kill_scorpling", 0.7, -2.0)
	super._leave_remains()


func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var sand := Color(0.86, 0.72, 0.46)
	if submerged:
		# Only a moving mound and ripples in the sand.
		var moving := clampf(velocity.length() / 60.0, 0.0, 1.0)
		p.oval(Vector2(0, 2), Vector2(radius * 1.1, radius * 0.55), f.angle(), Color(sand.darkened(0.35), 0.55))
		p.oval(Vector2(0, 0), Vector2(radius * 0.8, radius * 0.4), f.angle(), Color(sand.lightened(0.1), 0.8))
		for k in 2:
			var ph := fmod(t * (0.8 + moving) + k * 0.5, 1.0)
			p.arc(Vector2.ZERO, 8.0 + ph * 16.0, 0.0, TAU, 1.5, Color(sand.darkened(0.45), 0.55 * sin(ph * PI)), 20)
		for k in 3:
			var ph := fmod(t * 1.3 + k * 0.33, 1.0)
			p.circle(-f * (6.0 + ph * 14.0) + s * sin(k * 2.0) * 4.0, 1.6, Color(sand.darkened(0.2), 0.7 * (1.0 - ph)), 6)
		return
	var rise := 1.0
	if state == "sink":
		rise = clampf(state_t / float(BURROWER["sink_time"]), 0.25, 1.0)
	# A segmented digger: plates down its back, many short legs, two mandibles.
	var segs := 4
	for k in range(segs - 1, -1, -1):
		var u := float(k) / (segs - 1)
		var at := (f * radius * (0.75 - 1.9 * u) + s * sin(t * 7.0 - u * 3.0) * 2.5 * _move) * rise
		var sr := radius * (0.82 - 0.3 * u) * rise
		for sgn in [-1.0, 1.0]:
			var ph: float = _stride * 2.0 + k * 1.7 + (PI if sgn > 0.0 else 0.0)
			p.limb(at + s * sgn * sr * 0.6, at + (s * sgn * (sr + 6.0) + f * sin(ph) * 4.0) * rise, color.darkened(0.4), 2.2)
		p.ball(at, sr, color.darkened(0.05 * k))
		p.quad(at - s * sr * 0.7, at + s * sr * 0.7, 1.4, Color(color.darkened(0.3), 0.9))
		p.circle(at - f * sr * 0.2 + s * -sr * 0.25 + Vector2(-1, -1.5), sr * 0.28, Color(color.lightened(0.3), 0.8), 8)
	var head := f * radius * 1.15 * rise
	var open := _ease("jaw", 5.5 if state == "wind_bite" else 2.0, 16.0)
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = head + s * sgn * 3.5
		p.poly(PackedVector2Array([root, root + (f * 10.0 + s * sgn * (2.5 + open)) * rise, root + f * 3.5 * rise]), Color(0.3, 0.2, 0.12), 1.2)
	p.circle(head + s * 3.0 - f * 2.0, 1.4, Palette.OUTLINE, 8)
	p.circle(head - s * 3.0 - f * 2.0, 1.4, Palette.OUTLINE, 8)
	if state == "crawl":
		_glow.arc(Vector2(0, radius * 0.6), radius + 6.0, 0.0, TAU, 1.5, Color(1.0, 0.85, 0.5, 0.5 + 0.3 * sin(t * 6.0)), 24)


func _overlay_extra(o) -> void:
	if state == "wind_erupt":
		_target(o, spot - global_position, float(BURROWER["erupt_radius"]), _wk(float(BURROWER["erupt_wind"])), 0.12)
	if state == "wind_bite":
		var half := deg_to_rad(50.0)
		o.wedge(Vector2.ZERO, float(BURROWER["bite_reach"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(Palette.DANGER, 0.12 + 0.15 * _wk(float(BURROWER["bite_wind"]))), 10)
