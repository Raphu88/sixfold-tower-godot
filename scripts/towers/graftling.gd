extends "res://scripts/towers/brood.gd"
## THE GRAFTLING: a patchwork creature of the Chimera's tower (kind
## "graftling"; enemy.gd SUBKINDS spawns it with this script). Alone it only
## claws (a short wind-up, the glint: parryable). But beside another monster
## it reaches out with stitched tendrils (a line between them, a moment's
## pull: strike it to break it off) and TEARS A PART AWAY, grafting it onto
## itself, where you can see it: a hound's legs, a mongrel's quills, an iron
## arm, a stinging tail. From then on it has that monster's attack, with
## that attack's own telegraph: a LEAP (a red line, then the lunge), a fan of
## three QUILLS (thin aim lines), a SLAM (a ring in front of it) or a STING
## (a short wedge; it poisons). Every one glints and can be parried. The
## monster it robbed loses some health and reels. It carries one part at a
## time; which part each monster gives is GRAFTS.

static var GRAFTLING := {
	"graft_near": 170.0,  # it reaches for a monster this near (px)
	"graft_time": 0.9,  # seconds the pull takes
	"tear": 0.15,  # the share of the robbed monster's health torn away
	"daze": 0.6,  # seconds the robbed monster reels
	"claw_near": 50.0, "claw_wind": 0.5, "claw_reach": 56.0, "claw_arc": 50.0, "claw_mult": 0.7,
	"leap_near": 125.0, "leap_wind": 0.5,
	"quill_near": 240.0, "quill_wind": 0.6, "quill_speed": 300.0, "quill_mult": 0.6,
	"slam_near": 72.0, "slam_wind": 0.85, "slam_ahead": 40.0, "slam_r": 44.0,
	"sting_near": 60.0, "sting_wind": 0.5, "sting_reach": 56.0,
}
## Which part (and attack) each monster gives: "leap", "quills", "slam" or "sting".
static var GRAFTS := {
	"thornhound": "leap", "lurker": "leap", "deepfin": "leap", "harrier": "leap", "bat": "leap", "wisp": "leap", "ashwing": "leap",
	"burrower": "leap", "leafmantis": "leap", "carrion": "leap",
	"mongrel": "quills", "archer": "quills", "cinder": "quills", "bloomcap": "quills", "kindler": "quills",
	"knight": "slam", "smith": "slam", "ram": "slam", "golem": "slam", "shellback": "slam", "cairn": "slam", "mimic": "slam", "thunderling": "slam",
	"scorpling": "sting", "briar": "sting", "hydra": "sting", "basilisk": "sting", "slime": "sting", "salamander": "sting", "flamemoth": "sting",
}
static var GRAFTLING_TEXT := {
	"pull": "It reaches for a part!",
	"torn": "A part torn away",
	"leap": "It grafts on a hound's legs",
	"quills": "It grafts on a mongrel's quills",
	"slam": "It grafts on an iron arm",
	"sting": "It grafts on a stinging tail",
}

const C_STITCH := Color(0.2, 0.14, 0.12)
const C_FLESH := Color(0.74, 0.58, 0.5)

var graft := ""  # the part it carries (GRAFTS' values), "" none yet
var graft_col := Color(0.6, 0.5, 0.4)  # the colour of the monster it came from
var donor = null


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var g := GRAFTLING
	_first_look(dist)
	match state:
		"graft":
			velocity = Vector2.ZERO
			if donor == null or not is_instance_valid(donor) or donor.dead or donor.global_position.distance_to(global_position) > float(g["graft_near"]) + 40.0:
				donor = null
				state = "recover"
				state_t = 0.5
				return
			face = face.slerp((donor.global_position - global_position).normalized(), minf(1.0, 8.0 * delta)).normalized()
			state_t -= delta
			if state_t <= 0.0:
				_take_part(donor)
				donor = null
				state = "recover"
				state_t = 0.6
		"wind_claw":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, float(g["claw_reach"]), deg_to_rad(float(g["claw_arc"])), Color(0.9, 0.6, 0.45))
				main.sfx_at(global_position, "swing_light", 0.9, -3.0)
				_strike_cone(p, lunge_dir, float(g["claw_reach"]), float(g["claw_arc"]), dmg * float(g["claw_mult"]))
				_end_attack("recover", 0.8)
		"wind_leap":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				swoop_speed = maxf(LUNGE_SPEED * 0.7, maxf(0.0, dist - (radius + p.radius + 4.0)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 4.0)) / swoop_speed):
				state = "lunge"
				state_t = 0.2
				lunge_hit = false
		"lunge":
			state_t -= delta
			velocity = lunge_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 0.9)
		"wind_quills":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / float(g["quill_speed"])):
				for i in 3:
					var q = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(12.0)) * float(g["quill_speed"]), dmg * float(g["quill_mult"]))
					q.style = "spike"
					q.tint = graft_col
				main.sfx_at(global_position, "bow", 1.1)
				_end_attack("recover", 0.9)
		"wind_slam":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var at := global_position + lunge_dir * float(g["slam_ahead"])
				main.fx_ring(at, Color(0.8, 0.8, 0.85), float(g["slam_r"]), 0.3, 4.0)
				main.fx_burst(at, Vector2.UP, Color(0.7, 0.68, 0.7), 12, 180.0)
				main.sfx_at(global_position, "slam", 1.0, -3.0)
				main.shake(4.0)
				if p.global_position.distance_to(at) < float(g["slam_r"]) + p.radius:
					p.receive_attack(dmg, self)
				_end_attack("recover", 1.2)
		"wind_sting":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.sfx_at(global_position, "swing", 1.5, -4.0)
				if _in_cone(p, lunge_dir, float(g["sting_reach"]), 50.0):
					_sting(p, dmg)
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, 100.0, speed * 0.6)
			if state_t <= 0.0:
				state = "chase"
		_:
			if graft == "":
				var d = _donor()
				if d != null:
					donor = d
					state = "graft"
					state_t = float(g["graft_time"])
					main.fx_text(global_position + Vector2(0, -radius - 22.0), String(GRAFTLING_TEXT["pull"]), Color(0.95, 0.75, 0.6))
					main.sfx_at(global_position, "hit_slime", 0.7, -2.0)
					return
			if _try_attack(dir, dist):
				return
			velocity = dir * speed if dist > 44.0 else Vector2.ZERO


## Starts the attack its part gives (or its claw). True if it did.
func _try_attack(dir: Vector2, dist: float) -> bool:
	var g := GRAFTLING
	var want := ""
	var wind := 0.0
	match graft:
		"leap":
			if dist < float(g["leap_near"]):
				want = "wind_leap"
				wind = float(g["leap_wind"])
		"quills":
			if dist > 70.0 and dist < float(g["quill_near"]):
				want = "wind_quills"
				wind = float(g["quill_wind"])
		"slam":
			if dist < float(g["slam_near"]):
				want = "wind_slam"
				wind = float(g["slam_wind"])
		"sting":
			if dist < float(g["sting_near"]):
				want = "wind_sting"
				wind = float(g["sting_wind"])
	if want == "" and dist < float(g["claw_near"]):
		want = "wind_claw"
		wind = float(g["claw_wind"])
	if want == "" or not main.request_attack(self):
		return false
	_begin_wind(want, wind)
	lunge_dir = dir
	_warn(1.0 if want != "wind_slam" else 0.7)
	return true


## A monster near it with a part to give (not a beast, not one of its own).
func _donor():
	var best = null
	var bd := float(GRAFTLING["graft_near"])
	for o in main.enemies():
		if o == self or o.dead or o.submerged or o.is_boss() or o.ally or o.kind == "graftling" or not GRAFTS.has(String(o.kind)):
			continue
		var d: float = o.global_position.distance_to(global_position)
		if d < bd and main.clear_line(global_position, o.global_position):
			bd = d
			best = o
	return best


## It tears the part away: the robbed monster reels and loses some health.
func _take_part(o) -> void:
	graft = String(GRAFTS.get(String(o.kind), ""))
	if graft == "":
		return
	graft_col = o.color
	var tear: float = o.max_hp * float(GRAFTLING["tear"])
	o.take_hit(tear, (o.global_position - global_position).normalized(), 60.0)
	if is_instance_valid(o) and not o.dead:
		o.stagger(float(GRAFTLING["daze"]))
		main.fx_text(o.global_position + Vector2(0, -o.radius - 22.0), String(GRAFTLING_TEXT["torn"]), Color(0.9, 0.7, 0.6))
	main.fx_text(global_position + Vector2(0, -radius - 34.0), String(GRAFTLING_TEXT[graft]), Color(1.0, 0.8, 0.6))
	main.fx_burst(global_position, Vector2.UP, graft_col, 12, 140.0)
	main.sfx_at(global_position, "hit_slime", 1.0, -2.0)


func is_attacking() -> bool:
	return state.begins_with("wind") or state == "lunge"


## Struck while it pulls: the tendrils snap.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var pulling := state == "graft"
	super.take_hit(amount, dir, force, heavy, pierce)
	if pulling and not dead and state == "graft" and dir != Vector2.ZERO:
		donor = null
		state = "recover"
		state_t = 0.8


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var g := GRAFTLING
	var crouch := _ease("crouch", _wk(float(g["leap_wind"])) if state == "wind_leap" else 0.0, 14.0)
	# Its own stubby legs (or a hound's long ones, grafted on behind).
	_legs(p, f, [radius * 0.45, -radius * 0.4], radius * 0.45, 6.0, 3.4, C_FLESH.darkened(0.35), 1.4)
	if graft == "leap":
		for sgn in [-1.0, 1.0]:
			var hip: Vector2 = -f * radius * 0.5 + s * sgn * radius * 0.5
			var foot: Vector2 = hip - f * (8.0 - 3.0 * crouch) + s * sgn * 5.0 + f * sin(_stride * 1.5 + (PI if sgn > 0.0 else 0.0)) * 3.0 * _move
			p.tube(PackedVector2Array([hip, hip - f * 3.0 + s * sgn * 7.0, foot]), PackedFloat32Array([3.6, 2.8, 2.0]), graft_col.darkened(0.2), true, false)
	if graft == "quills":
		var bristle := _ease("bristle", 1.0 if state == "wind_quills" else 0.0, 12.0)
		for i in 5:
			var a := f.angle() + PI + (float(i) - 2.0) * (0.32 + 0.08 * bristle)
			var root := Vector2.from_angle(a) * radius * 0.5
			p.limb(root, root + Vector2.from_angle(a) * (7.0 + 5.0 * bristle), C_QUILL, 1.5)
	if graft == "sting":
		var strike := _ease("strike", _wk(float(g["sting_wind"])) if state == "wind_sting" else 0.0, 14.0)
		var prev := Vector2.ZERO
		for k in 5:
			var u := float(k) / 4.0
			var at := -f * radius * (0.9 - u * 1.4) + s * sin(u * 3.0 + t * 1.5) * 2.0 - f * radius * 0.5 * (1.0 - strike) * u + f * radius * 1.2 * strike * u * u + Vector2(0, -4.0 * u)
			if k < 4:
				p.ball(at, 3.0 - u * 1.0, graft_col.lightened(0.05 * k))
			else:
				var d := (at - prev).normalized()
				p.poly(PackedVector2Array([at - d.orthogonal() * 2.0, at + d * 4.5, at + d.orthogonal() * 2.0]), C_VENOM, 1.1)
			prev = at
	# A lumpy body of mismatched hides, stitched.
	p.ball(Vector2.ZERO, radius, C_FLESH)
	p.oval(s * radius * 0.35 - f * 2.0 + Vector2(-0.5, -0.5), Vector2(radius * 0.5, radius * 0.4), 0.7, color, 14)
	p.oval(-s * radius * 0.3 + f * 2.0 + Vector2(-0.5, -0.5), Vector2(radius * 0.4, radius * 0.35), -0.5, color.darkened(0.25), 14)
	for sgn in [-1.0, 1.0]:
		var a0: Vector2 = f * radius * 0.7 + s * sgn * 2.0
		var a1: Vector2 = -f * radius * 0.7 + s * sgn * 4.0
		p.quad(a0, a1, 0.9, C_STITCH)
		for i in 3:
			var at := a0.lerp(a1, (i + 0.5) / 3.0)
			var d := (a1 - a0).normalized().orthogonal()
			p.quad(at + d * 1.8, at - d * 1.8, 0.8, C_STITCH)
	if graft == "slam":
		# An iron arm, much too big for it, stitched on at the shoulder.
		var raise := _ease("raise", _wk(float(g["slam_wind"])) if state == "wind_slam" else 0.0, 12.0)
		var sh := s * radius * 0.7
		var fist := sh + f * (radius * 0.9 - 4.0 * raise) + s * 3.0 + Vector2(0, -12.0 * raise)
		p.limb(sh, fist, Palette.STEEL.darkened(0.3), 4.6)
		p.ball(fist, 4.6, Palette.STEEL.darkened(0.15))
		p.quad(sh + Vector2(-2, -2), sh + Vector2(2, 2), 1.0, C_STITCH)
	# Two heads that don't match: one big-eyed, one with a long jaw.
	var h1 := f * radius * 0.85 + s * radius * 0.35
	var h2 := f * radius * 0.8 - s * radius * 0.4
	p.ball(h2, radius * 0.4, color.darkened(0.15))
	p.ball(h1, radius * 0.46, C_FLESH.lightened(0.05))
	var open := _ease("jaw", _wk(float(g["claw_wind"])) if state == "wind_claw" else 0.0, 14.0)
	p.tri(h2 + f * 5.5 + s * (1.0 + 2.0 * open), h2 + f * 2.5, h2 + f * 5.5 - s * (1.0 + 2.0 * open), Palette.OUTLINE)
	p.circle(h1 + f * 2.0 + s * 1.5, 2.0, C_EYE, 10)
	p.circle(h1 + f * 2.6 + s * 1.5, 1.0, Palette.OUTLINE, 8)
	p.circle(h2 + f * 1.8 - s * 1.5, 1.1, Palette.OUTLINE, 8)
	_glow.circle(h2 + f * 1.8 - s * 1.5, 0.8, Color(0.95, 0.35, 0.25), 6)
	if graft == "leap":
		# The hound's jaw, grafted under its own.
		p.egg(h1 + f * 4.0 + Vector2(0, 2.0), Vector2(3.4, 2.2), f.angle(), graft_col.lightened(0.1))


func _overlay_extra(o) -> void:
	var g := GRAFTLING
	match state:
		"graft":
			if donor != null and is_instance_valid(donor):
				var to: Vector2 = donor.global_position - global_position
				var k := 1.0 - clampf(state_t / float(g["graft_time"]), 0.0, 1.0)
				var now := Time.get_ticks_msec() * 0.001
				for j in 2:
					var prev := Vector2.ZERO
					for i in range(1, 9):
						var u := float(i) / 8.0
						var at := to * u * (0.4 + 0.6 * k) + to.normalized().orthogonal() * sin(now * 10.0 + u * 8.0 + j * 2.0) * 4.0 * (1.0 - u)
						o.quad(prev, at, 1.6, Color(0.85, 0.45, 0.4, 0.8))
						prev = at
		"wind_claw":
			o.wedge(Vector2.ZERO, float(g["claw_reach"]), lunge_dir.angle() - deg_to_rad(float(g["claw_arc"])), lunge_dir.angle() + deg_to_rad(float(g["claw_arc"])), Color(Palette.DANGER, 0.12 + 0.15 * _wk(float(g["claw_wind"]))), 10)
		"wind_leap":
			o.quad(Vector2.ZERO, lunge_dir * 110.0, radius * 1.4, Color(Palette.DANGER, 0.4))
		"wind_quills":
			_fan(o, 3, 12.0, 130.0)
		"wind_slam":
			_target(o, lunge_dir * float(g["slam_ahead"]), float(g["slam_r"]), _wk(float(g["slam_wind"])), 0.1)
		"wind_sting":
			o.wedge(Vector2.ZERO, float(g["sting_reach"]), lunge_dir.angle() - deg_to_rad(50.0), lunge_dir.angle() + deg_to_rad(50.0), Color(Palette.DANGER, 0.12 + 0.15 * _wk(float(g["sting_wind"]))), 10)
