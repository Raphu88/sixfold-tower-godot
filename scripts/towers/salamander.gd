extends "res://scripts/towers/brood.gd"
## THE SALAMANDER: a fire lizard of the Firebird's tower (kind "salamander";
## enemy.gd SUBKINDS spawns it with this script). It SWIMS THROUGH BURNING
## FLOOR: inside fire it's under the flames, seen only as a heat shimmer and
## two eyes, and nothing can touch it there (as a lurker in water). It keeps
## to the fire; when you come near the edge it surfaces, glints and lunges
## out to bite (parryable), then lies on the floor a moment (your opening)
## before it slips back in. With no fire near, it walks (slowly, open to
## blows) and KINDLES a pool of its own: it glows, a red ring marks the pool
## round it (step out: can't be parried), and the floor bursts alight. It
## swims in any fire, yours too. PUT THE FIRE OUT (water on it, or soak the
## salamander) and it's thrown out, dazed and exposed. Fire doesn't burn it.

static var SALAMANDER := {
	"kindle_every": 6.0,  # seconds before it kindles a pool again
	"kindle_wind": 0.9,  # the pool's wind-up (seconds)
	"pool_r": 54.0,  # the pool it kindles (px)...
	"pool_t": 9.0,  # ...burns this long (seconds)
	"pool_dmg": 0.6,  # the burst hurts this share of its bite
	"use_near": 80.0,  # it slips into fire this near
	"bite_near": 100.0,  # from the fire it lunges at you this near
	"rise": 0.35, "bite_wind": 0.45, "leap": 480.0,
	"up": 1.4,  # seconds on the floor after a lunge
	"sink": 0.35,
	"walk": 0.6,  # out of the fire it walks this much as fast
	"douse": 1.8,  # seconds it reels when its fire is put out
}
static var SALAMANDER_TEXT := {"kindle": "It sets the floor alight!", "doused": "Doused! It's out of the fire", "under": "in the flames"}

const C_BELLY := Color(1.0, 0.82, 0.45)
const C_SPOT := Color(0.25, 0.12, 0.1)

var kindle_cd := 2.0
var said_t := 0.0
var goal_fire := Vector2.INF


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "walk"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var c := SALAMANDER
	_first_look(dist)
	burn_t = 0.0  # (fire itself: it doesn't burn)
	kindle_cd -= delta
	said_t -= delta
	var here := _flame_at(global_position)
	if submerged and (soaked > 0.0 or here.is_empty() or main.in_water(global_position)):
		if soaked > 0.0 or main.in_water(global_position):
			douse(here)
		else:
			_surface("walk", 0.0)  # (its fire burned out)
		return
	match state:
		"sub":
			submerged = true
			# Swim toward you, but never out of the fire.
			var step := dir * speed
			var next := global_position + dir * (radius + 6.0)
			if _flame_at(next).is_empty():
				step = Vector2.ZERO
			velocity = step
			if dist < float(c["bite_near"]) and dist < 9000.0 and main.request_attack(self):
				state = "rise"
				state_t = float(c["rise"])
				velocity = Vector2.ZERO
				main.sfx("burn", 1.3, -6.0)
		"rise":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				_begin_wind("wind", float(c["bite_wind"]))
				_warn(1.1)
				lunge_dir = dir
		"wind":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 8.0)) / float(c["leap"])):
				state = "lunge"
				state_t = clampf((dist + 10.0) / float(c["leap"]), 0.14, 0.3)
				lunge_hit = false
		"lunge":
			state_t -= delta
			velocity = lunge_dir * float(c["leap"])
			if not lunge_hit and dist < radius + p.radius + 8.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("up", float(c["up"]))
		"up", "recover":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				if not _flame_at(global_position).is_empty():
					state = "sink"
					state_t = float(c["sink"])
				else:
					state = "walk"
		"sink":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "sub"
				submerged = true
		"wind_kindle":
			velocity = Vector2.ZERO
			if _wind(delta):
				main.add_flame(global_position, float(c["pool_r"]), float(c["pool_t"]))
				main.fx_ring(global_position, Color(1.0, 0.55, 0.2), float(c["pool_r"]), 0.4, 4.0)
				main.fx_burst(global_position, Vector2.UP, Color(1.0, 0.6, 0.25), 20, 200.0)
				main.light_flash(global_position, Color(1.0, 0.55, 0.22), 1.4, 1.6, 0.3)
				main.sfx("fire_blast", 1.0, -3.0)
				if p.global_position.distance_to(global_position) < float(c["pool_r"]) + p.radius:
					p.receive_attack(dmg * float(c["pool_dmg"]), self, true)
				kindle_cd = float(c["kindle_every"])
				_end_attack("sink", float(c["sink"]))
		_:  # walk: out of the fire
			state = "walk"
			submerged = false
			if not here.is_empty():
				state = "sink"
				state_t = float(c["sink"])
				return
			var fire := _fire_near(float(c["use_near"]))
			if fire != Vector2.INF:
				velocity = (fire - global_position).normalized() * speed
				return
			if kindle_cd <= 0.0 and dist < 260.0 and main.request_attack(self):
				_begin_wind("wind_kindle", float(c["kindle_wind"]))
				main.fx_text(global_position + Vector2(0, -radius - 22.0), String(SALAMANDER_TEXT["kindle"]), Color(1.0, 0.7, 0.35))
				main.sfx("spell_fire", 0.8, -3.0)
				return
			velocity = dir * speed * float(c["walk"]) if dist > 50.0 else Vector2.ZERO


## The nearest burning floor this near (Vector2.INF if none).
func _fire_near(reach: float) -> Vector2:
	var best := Vector2.INF
	var bd := reach
	for f in main.flames:
		if float(f["t"]) < 1.0 or float(f["r"]) < 18.0:
			continue
		var d: float = global_position.distance_to(f["pos"]) - float(f["r"]) * 0.5
		if d < bd:
			bd = d
			best = f["pos"]
	return best


## Its fire is put out: the flames round it die and it's thrown out, dazed.
func douse(here: Dictionary) -> void:
	for f in main.flames:
		if Vector2(f["pos"]).distance_to(global_position) < float(f["r"]) + radius:
			f["t"] = 0.0
	if not here.is_empty():
		here["t"] = 0.0
	soaked = 0.0
	_surface("recover", float(SALAMANDER["douse"]))
	stun = maxf(stun, float(SALAMANDER["douse"]) * 0.6)
	kindle_cd = maxf(kindle_cd, 3.0)
	main.fx_text(global_position + Vector2(0, -radius - 22.0), String(SALAMANDER_TEXT["doused"]), Color(0.7, 0.85, 1.0))
	main.fx_burst(global_position, Vector2.UP, Color(0.92, 0.94, 0.96), 18, 160.0)
	main.sfx("hiss", 0.9, -2.0)


func _surface(next: String, t: float) -> void:
	if is_attacking():
		_end_attack(next, t)
	state = next
	state_t = t
	submerged = false
	velocity = Vector2.ZERO


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if submerged:
		if said_t <= 0.0 and main != null:
			said_t = 1.5
			main.fx_text(global_position + Vector2(0, -radius - 10.0), String(SALAMANDER_TEXT["under"]), Color(1.0, 0.7, 0.4))
		return
	super.take_hit(amount, dir, force, heavy, pierce)


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	if submerged:
		# Only a heat shimmer in the flames, and two eyes.
		var moving := clampf(velocity.length() / 60.0, 0.0, 1.0)
		for k in 3:
			var ph := fmod(t * (1.2 + moving) + k * 0.33, 1.0)
			var y := -ph * 18.0
			p.quad(Vector2(-8 + sin(t * 9.0 + k) * 2.0, y), Vector2(8 + sin(t * 9.0 + k + 1.0) * 2.0, y - 2.0), 1.4, Color(1.0, 0.85, 0.6, 0.35 * sin(ph * PI)))
		p.oval(Vector2.ZERO, Vector2(radius * 1.2, radius * 0.45), f.angle(), Color(1.0, 0.45, 0.15, 0.25), 16)
		_glow.circle(f * radius * 0.6 + s * 2.5, 1.2, Color(1.0, 0.95, 0.6, 0.9), 6)
		_glow.circle(f * radius * 0.6 - s * 2.5, 1.2, Color(1.0, 0.95, 0.6, 0.9), 6)
		return
	var rise := 1.0
	if state == "sink":
		rise = clampf(state_t / float(SALAMANDER["sink"]), 0.3, 1.0)
	elif state == "rise":
		rise = 1.0 - clampf(state_t / float(SALAMANDER["rise"]), 0.0, 0.7)
	var glow := _ease("kglow", _wk(float(SALAMANDER["kindle_wind"])) if state == "wind_kindle" else 0.0, 10.0)
	var sway := sin(t * 3.0) * 4.0 * (0.3 + _move)
	var tail := PackedVector2Array([-f * radius * 0.5, -f * radius * 1.2 + s * sway * 0.4, -f * radius * 1.9 + s * sway, -f * radius * 2.5 + s * sway * 1.5])
	p.tube(tail, PackedFloat32Array([radius * 0.6, radius * 0.45, radius * 0.25, radius * 0.08]), color.darkened(0.05))
	_legs(p, f, [radius * 0.5, -radius * 0.35], radius * 0.5, 7.0 * rise, 3.2, color.darkened(0.3), 1.8)
	p.egg(Vector2.ZERO, Vector2(radius * 1.0, radius * 0.6) * rise, f.angle(), color)
	p.egg(Vector2(0, 1.5), Vector2(radius * 0.65, radius * 0.3) * rise, f.angle(), C_BELLY, false)
	for i in 4:
		p.circle(f * radius * (0.5 - i * 0.35) + s * (2.5 if i % 2 == 0 else -3.0), 1.8, C_SPOT, 8)
	# A crest of flame down its back.
	for i in 4:
		var at := f * radius * (0.4 - i * 0.3) + Vector2(0, -radius * 0.35)
		var fl := _flame(at, 2.6 + glow * 2.0, t + i, 1.6, 8)
		p.poly(fl, Color(1.0, 0.65 + 0.1 * i, 0.25), 0.0)
		_glow.circle(at + Vector2(0, -2), 2.0 + glow * 3.0, Color(1.0, 0.75, 0.35, 0.5), 8)
	var head := f * radius * 1.0
	p.egg(head, Vector2(radius * 0.48, radius * 0.38), f.angle(), color.lightened(0.08))
	var open := _ease("jaw", 1.0 if state in ["wind", "lunge"] else 0.0, 16.0)
	p.tri(head + f * radius * 0.45 + s * (0.8 + 2.4 * open), head + f * radius * 0.15, head + f * radius * 0.45 - s * (0.8 + 2.4 * open), Palette.OUTLINE)
	_glow.circle(head + f * 1.5 + s * radius * 0.24, 1.2, Color(1.0, 0.95, 0.6), 6)
	_glow.circle(head + f * 1.5 - s * radius * 0.24, 1.2, Color(1.0, 0.95, 0.6), 6)
	if glow > 0.05:
		_glow.circle(Vector2.ZERO, radius * (1.2 + glow), Color(1.0, 0.5, 0.2, 0.25 * glow), 16)


func _overlay_extra(o) -> void:
	if state == "wind":
		o.quad(Vector2.ZERO, lunge_dir * 110.0, radius * 1.5, Color(Palette.DANGER, 0.4))
	elif state == "wind_kindle":
		_target(o, Vector2.ZERO, float(SALAMANDER["pool_r"]), _wk(float(SALAMANDER["kindle_wind"])), 0.1)
