extends "res://scripts/towers/brood.gd"
## THE LEAFMANTIS: a leaf-green mantis of the Chimera's tower (kind
## "leafmantis"; enemy.gd SUBKINDS spawns it with this script). Standing still
## among leaves and brambles it is NEARLY INVISIBLE (a faint outline, leaves
## round it), and can't be struck or aimed at. Come near (or linger) and the
## leaves RUSTLE (a sound, the leaves shaking, it rears up), then the GLINT,
## and it darts in with a FAST DOUBLE SLASH: two cuts a beat apart in the
## wedge in front of it (parry the first and the second never comes; a roll
## takes you through both). Then it stands in the open (your opening), stalks
## you and slashes again from the open the same way, until it's left alone a
## while: then it slips back among the leaves (into brambles nearby, on the
## Chimera's floors) and goes still. Fire flushes it out of hiding; burning or
## soaked it can't hide at all.

static var LEAFMANTIS := {
	"spring": 105.0,  # hidden, it strikes when you come this near (px)...
	"restless": 5.0,  # ...or after you linger within 220 px this long (seconds)
	"wind": 0.85,  # the rustle and the wind-up before the dash (seconds)
	"dash": 560.0,  # how fast it darts in
	"reach": 62.0, "arc": 55.0,  # each slash's wedge
	"gap": 0.28,  # seconds between the two slashes
	"slash_mult": 0.7,  # each slash's share of its blow
	"near": 92.0,  # in the open it slashes from this near
	"hide_after": 4.0,  # seconds unstruck (and you away) before it hides again
	"cover": 170.0,  # it looks for brambles this near to hide in
	"seen": 0.16,  # how much of it shows while hidden
	"stun": 1.6,  # seconds fire flushes it out
}
static var LEAFMANTIS_TEXT := {"rustle": "A rustle in the leaves!", "flushed": "Flushed out!"}

const C_LEAF := Color(0.3, 0.5, 0.22)
const C_LEAF_HI := Color(0.45, 0.66, 0.3)
const C_BLADE := Color(0.82, 0.9, 0.62)

var near_t := 0.0
var calm_t := 0.0
var slashes := 0
var cover := Vector2.INF


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "hide"
	submerged = true


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var m := LEAFMANTIS
	_first_look(dist)
	match state:
		"hide":
			submerged = true
			velocity = Vector2.ZERO
			if burn_t > 0.0 or soaked > 0.0 or _fire_near():
				flush()
				return
			var near: float = global_position.distance_to(p.global_position)
			near_t = near_t + delta if near < 220.0 else 0.0
			if (near < float(m["spring"]) or near_t > float(m["restless"])) and not p.dead and main.clear_line(global_position, p.global_position):
				_spring(dir)
		"to_cover":
			submerged = false
			if cover == Vector2.INF or global_position.distance_to(cover) < 10.0 or dist < 120.0:
				if dist >= 120.0 and cover != Vector2.INF:
					_hide()
				else:
					state = "stalk"
				return
			velocity = main.path_dir(global_position, cover) * speed
		"wind_slash":
			submerged = false
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				swoop_speed = maxf(float(m["dash"]), maxf(0.0, dist - (radius + p.radius + 30.0)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 30.0)) / swoop_speed):
				state = "lunge"
				state_t = clampf((dist - (radius + p.radius + 24.0)) / swoop_speed, 0.0, 0.25)
				slashes = 2
		"lunge":
			state_t -= delta
			velocity = lunge_dir * swoop_speed if state_t > 0.0 else Vector2.ZERO
			if state_t <= 0.0:
				state = "slash"
				state_t = 0.0
		"slash":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				if slashes <= 0:
					_end_attack("recover", 1.1)
					return
				slashes -= 1
				state_t = float(m["gap"])
				main.fx_cone(global_position, lunge_dir, float(m["reach"]), deg_to_rad(float(m["arc"])), C_BLADE)
				main.sfx("swing_light", 1.25 if slashes == 1 else 1.05, -2.0)
				_strike_cone(p, lunge_dir, float(m["reach"]), float(m["arc"]), dmg * float(m["slash_mult"]))
		"recover", "idle":
			submerged = false
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "stalk"
		_:  # stalk: in the open
			submerged = false
			state = "stalk"
			calm_t += delta
			if flash > 0.0:
				calm_t = 0.0
			if calm_t > float(m["hide_after"]) and dist > 150.0 and burn_t <= 0.0 and soaked <= 0.0:
				calm_t = 0.0
				cover = _find_cover()
				if cover == Vector2.INF or global_position.distance_to(cover) < 10.0:
					_hide()
				else:
					state = "to_cover"
				return
			if dist < float(m["near"]) and main.request_attack(self):
				_spring(dir)
			elif dist < 120.0:
				_circle(dir, dist, 100.0, speed * 0.6)
			else:
				velocity = dir * speed


func _spring(dir: Vector2) -> void:
	submerged = false
	aware = true
	near_t = 0.0
	if not main.request_attack(self) and not main.holds_attack(self):
		# (no turn free: it shows itself and waits for one)
		state = "stalk"
		return
	_begin_wind("wind_slash", float(LEAFMANTIS["wind"]))
	lunge_dir = dir
	main.fx_text(global_position + Vector2(0, -radius - 18.0), String(LEAFMANTIS_TEXT["rustle"]), Color(0.75, 0.95, 0.5))
	main.fx_burst(global_position, Vector2.UP, C_LEAF_HI, 10, 90.0)
	main.sfx("gust", 1.6, -8.0)
	_warn(1.3)


func _hide() -> void:
	state = "hide"
	submerged = true
	near_t = 0.0
	main.fx_burst(global_position, Vector2.UP, C_LEAF, 8, 60.0)


## Brambles near it to hide in (the Chimera's floors), else Vector2.INF.
func _find_cover() -> Vector2:
	var tf = _tf("in_bramble")
	if tf == null:
		return Vector2.INF
	if tf.in_bramble(global_position):
		return global_position
	var best := Vector2.INF
	var bd := float(LEAFMANTIS["cover"])
	for ring in range(1, 6):
		for k in 12:
			var q: Vector2 = global_position + Vector2.from_angle(k * TAU / 12.0) * ring * 30.0
			if tf.in_bramble(q) and not main.is_solid(q) and global_position.distance_to(q) < bd:
				bd = global_position.distance_to(q)
				best = q
		if best != Vector2.INF:
			return best
	return best


func _fire_near() -> bool:
	for f in main.flames:
		if global_position.distance_to(f["pos"]) < float(f["r"]) + radius + 20.0:
			return true
	return false


## Fire flushes it out of hiding (chimera_floor.gd blast): it reels, burning.
func flush() -> void:
	if dead or state != "hide" or main == null:
		return
	submerged = false
	aware = true
	state = "stalk"
	calm_t = 0.0
	stun = float(LEAFMANTIS["stun"])
	if burn_t <= 0.0:
		Reactions.apply(main, self, "burning", float(Reactions.STATES["burning"]["seconds"]), "fire")
	main.fx_text(global_position + Vector2(0, -radius - 20.0), String(LEAFMANTIS_TEXT["flushed"]), Color(1.0, 0.65, 0.35))
	main.fx_burst(global_position, Vector2.UP, Color(1.0, 0.55, 0.25), 12, 140.0)


func is_attacking() -> bool:
	return state.begins_with("wind") or state in ["lunge", "slash"]


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if state == "hide":
		# Found where it hid (a spell that finds it): it's out.
		submerged = false
		state = "stalk"
		calm_t = 0.0
	super.take_hit(amount, dir, force, heavy, pierce)


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var m := LEAFMANTIS
	var s := f.orthogonal()
	var hidden := state == "hide"
	var start: int = p.cols.size()
	var rear := _ease("rear", _wk(float(m["wind"])) if state == "wind_slash" else 0.0, 12.0)
	var cut := 0.0
	if state == "slash":
		cut = 1.0 if slashes == 1 else -1.0
	var cut_e := _ease("cut", cut, 22.0)
	# Leaves about its feet (they shake as it rustles).
	var shake := rear * sin(t * 40.0) * 2.0
	for i in 6:
		var a := i * TAU / 6.0 + 0.4
		var at := Vector2.from_angle(a) * radius * 1.1 + Vector2(shake * (1.0 if i % 2 == 0 else -1.0), 2.0)
		_feather(p, at, Vector2.from_angle(a + 0.6), radius * 0.8, radius * 0.45, C_LEAF.lightened(0.05 * (i % 3)), 1.0)
	# Thin legs, a long abdomen, a narrow thorax raised as it rears.
	_legs(p, f, [-radius * 0.1, -radius * 0.55], radius * 0.3, 9.0, 1.8, color.darkened(0.3), 1.4)
	p.egg(-f * radius * 0.7, Vector2(radius * 0.9, radius * 0.42), f.angle(), color.darkened(0.05))
	for i in 3:
		var at := -f * radius * (0.3 + 0.35 * i)
		p.quad(at + s * radius * 0.35, at - s * radius * 0.35, 0.9, Color(color.darkened(0.3), 0.8))
	var thorax := f * radius * (0.2 + 0.15 * rear) + Vector2(0, -4.0 * rear)
	p.egg(thorax, Vector2(radius * 0.5, radius * 0.26), f.angle(), color)
	# Folded leaf-wings on its back.
	for sgn in [-1.0, 1.0]:
		_feather(p, thorax - f * 2.0, (-f + s * sgn * 0.25).normalized(), radius * 1.3, radius * 0.5, C_LEAF_HI, 1.0)
	# The scythe arms: folded, raised as it rears, sweeping as it cuts.
	for sgn in [-1.0, 1.0]:
		var sh: Vector2 = thorax + f * radius * 0.25 + s * sgn * radius * 0.25
		var sweep: float = cut_e * sgn
		var elbow: Vector2 = sh + (f * (0.6 + 0.4 * rear) + s * sgn * 0.5).normalized() * radius * 0.6 + Vector2(0, -6.0 * rear)
		var tip: Vector2 = elbow + (f * (0.2 + 0.8 * absf(cut_e)) - s * sgn * (0.9 - 0.6 * rear) + s * sweep * 0.8).normalized() * radius * 0.9
		p.limb(sh, elbow, color.darkened(0.1), 2.4)
		p.poly(PackedVector2Array([elbow, tip, elbow + (tip - elbow) * 0.5 + (tip - elbow).orthogonal().normalized() * sgn * 2.5]), C_BLADE, 1.2)
	# A triangular head, big eyes.
	var head := thorax + f * radius * 0.55 + Vector2(0, -2.0 * rear)
	p.poly(PackedVector2Array([head + s * 4.5 - f * 1.0, head + f * 4.5, head - s * 4.5 - f * 1.0]), color.lightened(0.08), 1.2)
	p.circle(head + s * 3.2, 1.8, Color(0.75, 0.9, 0.4), 8)
	p.circle(head - s * 3.2, 1.8, Color(0.75, 0.9, 0.4), 8)
	if not hidden:
		_glow.circle(head + s * 3.2, 0.8, Color(1.0, 1.0, 0.7, 0.8), 6)
		_glow.circle(head - s * 3.2, 0.8, Color(1.0, 1.0, 0.7, 0.8), 6)
	if hidden:
		# Nearly invisible: everything it drew (its shadow too) fades to a ghost of itself.
		var k := float(m["seen"])
		for i in p.cols.size():
			var c: Color = p.cols[i]
			p.cols[i] = Color(c, c.a * (k if i >= start else k * 0.5))


func _overlay_extra(o) -> void:
	var m := LEAFMANTIS
	if state in ["wind_slash", "lunge", "slash"]:
		var k := _wk(float(m["wind"])) if state == "wind_slash" else 1.0
		_cone(o, float(m["reach"]), float(m["arc"]), k, 0.1, 0.75)
		if state == "wind_slash":
			o.quad(Vector2.ZERO, lunge_dir * 120.0, 2.0, Color(Palette.DANGER, 0.3 * k))
