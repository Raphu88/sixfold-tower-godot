extends "res://scripts/towers/brood.gd"
## THE BASILISK: a lizard of the Manticore's tower (kind "basilisk"; enemy.gd
## SUBKINDS spawns it with this script). Its eyes are the danger. Every few
## seconds, from a distance, its eyes begin to glow (a faint cone fills
## toward you, a sound, then the glint) and it GLARES: a pale cone of light
## for a moment. Stand in the cone FACING it and you're slowed (the Slowed
## state, refreshed while you keep looking). Turn away while its eyes glow
## (face anything else) and the glare does nothing. Up close it bites
## (parryable), a modest bite. On a phone, while it glares, the aim stops
## turning you toward it (player.gd _auto_aim), so walking away turns you away.

static var BASILISK := {
	"glare_every": 4.5,  # seconds between glares
	"glare_near": 280.0,  # it glares from this near (px)...
	"glare_far": 70.0,  # ...but not from nearer than this (it bites instead)
	"gaze_wind": 0.9,  # its eyes glow this long before the glare (seconds)
	"glare": 1.8,  # how long the glare lasts
	"reach": 270.0,  # the glare's cone: how far...
	"cone": 30.0,  # ...and its half-angle (degrees)
	"facing": 0.45,  # you face it when your aim points within about 63 degrees of it (a cosine)
	"slow": 1.2,  # seconds of Slowed each moment you meet its eyes (renewed while you look)
	"keep": 150.0,  # how far off it likes to stay (px)
	"bite_near": 52.0, "bite_wind": 0.55, "bite_reach": 58.0, "bite_arc": 45.0, "bite_mult": 0.8,
}
static var BASILISK_TEXT := {"glow": "Its eyes glow: look away!", "stiff": "Your limbs stiffen"}

const C_GLARE := Color(0.86, 1.0, 0.5)

var glare_cd := 2.0
var gaze_dir := Vector2.RIGHT
var stiff_said := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	glare_cd = 1.5 + randf() * 1.5


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var b := BASILISK
	_first_look(dist)
	glare_cd -= delta
	if state != "glare" and state != "gaze_wind" and has_meta("look_away"):
		remove_meta("look_away")
	match state:
		"gaze_wind":
			velocity = Vector2.ZERO
			gaze_dir = gaze_dir.slerp(dir, minf(1.0, 6.0 * delta)).normalized()
			if _wind(delta):
				state = "glare"
				state_t = float(b["glare"])
				stiff_said = false
				main.sfx("eye_open", 0.8, -2.0)
				main.light_flash(global_position + gaze_dir * radius, C_GLARE, 1.0, 1.4, 0.3)
		"glare":
			velocity = Vector2.ZERO
			state_t -= delta
			if _meets_eyes(p):
				Reactions.apply(main, p, "slowed", float(b["slow"]), self)
				if not stiff_said:
					stiff_said = true
					main.fx_text(p.global_position + Vector2(0, -56), String(BASILISK_TEXT["stiff"]), C_GLARE)
			if state_t <= 0.0:
				remove_meta("look_away")
				glare_cd = float(b["glare_every"])
				_end_attack("recover", 0.6)
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, float(b["bite_reach"]), deg_to_rad(float(b["bite_arc"])), Color(0.8, 0.95, 0.5))
				main.sfx("swing_light", 0.7, -3.0)
				_strike_cone(p, lunge_dir, float(b["bite_reach"]), float(b["bite_arc"]), dmg * float(b["bite_mult"]))
				_end_attack("recover", 0.9)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, float(b["keep"]), speed * 0.5)
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < float(b["bite_near"]) and main.request_attack(self):
				_begin_wind("wind_bite", float(b["bite_wind"]))
				_warn(0.75)
			elif glare_cd <= 0.0 and dist < float(b["glare_near"]) and dist > float(b["glare_far"]) and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				_begin_wind("gaze_wind", float(b["gaze_wind"]))
				gaze_dir = dir
				set_meta("look_away", true)  # (a phone's aim stops turning you toward it)
				main.sfx("hiss", 1.2, -4.0)
				main.fx_text(global_position + Vector2(0, -radius - 22.0), String(BASILISK_TEXT["glow"]), C_GLARE)
			else:
				_circle(dir, dist, float(b["keep"]), speed)


## You stand in its glare's cone looking at it (not rolling).
func _meets_eyes(p) -> bool:
	if p == null or p.dead or not ("aim" in p):
		return false
	var b := BASILISK
	var to: Vector2 = p.global_position - global_position
	if to.length() > float(b["reach"]) + p.radius or absf(gaze_dir.angle_to(to)) > deg_to_rad(float(b["cone"])):
		return false
	if "iframes" in p and p.iframes > 0.0:
		return false
	if Vector2(p.aim).dot(-to.normalized()) < float(b["facing"]):
		return false  # (looking away)
	return main.clear_line(global_position, p.global_position)


## Struck while it gazes or glares: the glare is broken off.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var gazing: bool = state in ["gaze_wind", "glare"]
	super.take_hit(amount, dir, force, heavy, pierce)
	if gazing and not dead and dir != Vector2.ZERO:
		if has_meta("look_away"):
			remove_meta("look_away")
		glare_cd = float(BASILISK["glare_every"]) * 0.5
		_end_attack("recover", 0.8)


# --- drawing ---------------------------------------------------------------------------

const C_BELLY := Color(0.82, 0.78, 0.55)
const C_CREST := Color(0.75, 0.32, 0.22)


func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var glow := 0.0
	if state == "gaze_wind":
		glow = _wk(float(BASILISK["gaze_wind"]))
	elif state == "glare":
		glow = 1.0
	var lunge := _ease("lunge", _wk(float(BASILISK["bite_wind"])) if state == "wind_bite" else 0.0, 14.0)
	# Tail sweeping behind, six splayed legs, a long low body.
	var sway := sin(t * 2.0) * 3.0
	var tail := PackedVector2Array([-f * radius * 0.6, -f * radius * 1.3 + s * sway * 0.5, -f * radius * 2.0 + s * sway, -f * radius * 2.6 + s * sway * 1.6])
	p.tube(tail, PackedFloat32Array([radius * 0.55, radius * 0.4, radius * 0.24, radius * 0.08]), color.darkened(0.08))
	_legs(p, f, [radius * 0.55, 0.0, -radius * 0.5], radius * 0.45, 7.5, 3.0, color.darkened(0.3), 1.6)
	var c := f * lunge * 3.0
	p.egg(c, Vector2(radius * 1.05, radius * 0.6), f.angle(), color)
	p.egg(c + Vector2(0, 1.5), Vector2(radius * 0.7, radius * 0.32), f.angle(), C_BELLY, false)
	for i in 5:  # scale bands across the back
		var at := c - f * radius * (0.6 - i * 0.3)
		p.quad(at + s * radius * 0.45, at - s * radius * 0.45, 1.0, Color(color.darkened(0.3), 0.8))
	# A crest of spines down its back, raised as its eyes glow.
	for i in 4:
		var at := c + f * radius * (0.35 - i * 0.32)
		p.tri(at + s * 2.0, at - f * 3.0 + Vector2(0, -3.5 - 3.0 * glow), at - s * 2.0, C_CREST)
	var head := c + f * radius * 1.05
	p.egg(head, Vector2(radius * 0.5, radius * 0.38), f.angle(), color.lightened(0.06))
	var open := _ease("jaw", lunge, 16.0)
	p.tri(head + f * radius * 0.48 + s * (1.0 + 2.5 * open), head + f * radius * 0.2, head + f * radius * 0.48 - s * (1.0 + 2.5 * open), Palette.OUTLINE)
	# The eyes: dark until they glow, then bright, with rays.
	for sgn in [-1.0, 1.0]:
		var eye: Vector2 = head + f * 1.5 + s * sgn * radius * 0.26
		p.circle(eye, 2.2, Palette.OUTLINE, 10)
		_glow.circle(eye, 1.3 + 1.2 * glow, Color(0.75, 0.9, 0.35).lerp(C_GLARE, glow), 10)
		if glow > 0.05:
			_glow.circle(eye, 3.0 + 5.0 * glow, Color(C_GLARE, 0.25 * glow), 12)


func _overlay_extra(o) -> void:
	var b := BASILISK
	var la := gaze_dir.angle()
	var half := deg_to_rad(float(b["cone"]))
	var reach := float(b["reach"])
	if state == "gaze_wind":
		var k := _wk(float(b["gaze_wind"]))
		o.wedge(Vector2.ZERO, reach * k, la - half, la + half, Color(C_GLARE, 0.06 + 0.1 * k), 18)
		o.arc(Vector2.ZERO, reach, la - half, la + half, 1.5, Color(C_GLARE, 0.35 + 0.3 * k), 18)
	elif state == "glare":
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.02)
		o.wedge(Vector2.ZERO, reach, la - half, la + half, Color(C_GLARE, 0.2 * pulse), 18)
		o.arc(Vector2.ZERO, reach, la - half, la + half, 2.5, Color(C_GLARE, 0.8), 18)
		for i in 5:  # rays
			var a := la + (float(i) - 2.0) / 2.0 * half * 0.85
			o.quad(Vector2.from_angle(a) * 14.0, Vector2.from_angle(a) * reach * 0.9, 1.2, Color(C_GLARE, 0.35 * pulse))
	elif state == "wind_bite":
		o.wedge(Vector2.ZERO, float(b["bite_reach"]), lunge_dir.angle() - deg_to_rad(float(b["bite_arc"])), lunge_dir.angle() + deg_to_rad(float(b["bite_arc"])), Color(Palette.DANGER, 0.12 + 0.15 * _wk(float(b["bite_wind"]))), 10)
