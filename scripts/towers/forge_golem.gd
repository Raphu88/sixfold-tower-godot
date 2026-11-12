extends "res://scripts/enemy.gd"
## THE FORGE GOLEM: the Wyvern's own creature (kind "golem"; enemy.gd
## SUBKINDS spawns it with this script). A lump of iron that walks, and
## heats up as it fights: every moment it's after you, every blow it swings
## and every blow it takes warms it (the seams in its plates glow from dull
## red to white).
##   Hot (heat past GOLEM "hot"): it hardens (your blows do GOLEM
##   "hot_armor" of their damage), walks faster, its slams leave the floor
##   burning, and now and then it FLARES: a ring of heat bursts out around
##   it (can't be parried: get out of the ring, or roll).
##   Full: it has to vent. It slumps, steaming, COOLING for a few seconds:
##   your blows do double. Water does the same at once: soak it (a water
##   barrel, a pool, a water spell) while it's warm and it's QUENCHED.
##   Its slam, a fist brought down in front of it, can be parried.
## Its essence (iron), gear and graft are in essence.gd, gear.gd and main.gd
## like every monster's; its numbers in GOLEM (the Data editor).

static var GOLEM := {
	"start_heat": 0.15, "heat_rate": 0.07, "swing_heat": 0.18, "hit_heat": 0.025,
	"hot": 0.6, "hot_armor": 0.5, "hot_speed": 1.3,
	"cool_time": 3.2, "quench_time": 4.0, "cool_mult": 2.0, "quench_from": 0.3,
	"slam_reach": 50.0, "slam_radius": 42.0, "slam_wind": 0.6, "slam_near": 72.0, "burn_floor": 2.5,
	"flare_every": 6.0, "flare_wind": 0.85, "flare_radius": 96.0, "flare_mult": 0.8,
}
static var GOLEM_TEXT := {"cooling": "Cooling!", "quenched": "Quenched!", "glowing": "Glowing", "venting": "It vents"}

var heat := 0.15
var flare_t := 4.0
var said_t := 0.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	heat = float(GOLEM["start_heat"])
	state = "recover"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var g := GOLEM
	said_t -= delta
	# Water on a warm golem: quenched.
	if soaked > 0.0 and heat > float(g["quench_from"]) and state != "cool":
		_cool(float(g["quench_time"]), true)
	# Full: it has to vent (not in the middle of a blow).
	if heat >= 1.0 and state != "cool" and not state.begins_with("wind"):
		_cool(float(g["cool_time"]), false)
	var hot := heat >= float(g["hot"])
	match state:
		"cool":
			velocity = Vector2.ZERO
			state_t -= delta
			heat = move_toward(heat, float(g["start_heat"]), delta * 0.35)
			if state_t <= 0.0:
				state = "chase"
		"wind_slam":
			velocity = Vector2.ZERO
			if _wind(delta):
				var spot: Vector2 = global_position + face * float(g["slam_reach"])
				var col := Color(1.0, 0.55, 0.25) if hot else Color(0.7, 0.66, 0.62)
				main.fx_ring(spot, col, float(g["slam_radius"]), 0.35, 5.0)
				main.fx_burst(spot, Vector2.ZERO, col, 12, 220.0)
				main.sfx("slam", 0.75)
				main.shake(6.0)
				if p.global_position.distance_to(spot) < float(g["slam_radius"]) + p.radius:
					p.receive_attack(dmg, self)
				if hot:
					main.add_flame(spot, 30.0, float(g["burn_floor"]))
				heat = minf(1.0, heat + float(g["swing_heat"]))
				_end_attack("recover", 1.0)
		"wind_flare":
			velocity = Vector2.ZERO
			if _wind(delta):
				var r := float(g["flare_radius"])
				main.fx_ring(global_position, Color(1.0, 0.6, 0.25), r, 0.4, 6.0)
				main.fx_burst(global_position, Vector2.ZERO, Color(1.0, 0.7, 0.3), 24, 280.0)
				main.light_flash(global_position, Color(1.0, 0.6, 0.25), 1.6, 1.6, 0.3)
				main.sfx("fire_blast", 0.85, -2.0)
				main.shake(5.0)
				if dist < r + p.radius:
					p.receive_attack(dmg * float(g["flare_mult"]), self, true)
				heat = minf(1.0, heat + 0.12)
				_end_attack("recover", 1.2)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if aware:
				heat = minf(1.0, heat + float(g["heat_rate"]) * delta)
			flare_t -= delta
			if hot and flare_t <= 0.0 and dist < float(g["flare_radius"]) * 0.85 and main.request_attack(self):
				flare_t = float(g["flare_every"])
				_begin_wind("wind_flare", float(g["flare_wind"]))
				main.sfx("charge", 0.6, -2.0)
			elif dist < float(g["slam_near"]) and main.request_attack(self):
				_begin_wind("wind_slam", float(g["slam_wind"]))
				main.sfx("warn_smith", 0.8, -2.0)
			else:
				velocity = dir * speed * (float(g["hot_speed"]) if hot else 1.0)


## It slumps and cools (it ran too hot, or water caught it): open to blows.
func _cool(seconds: float, quenched: bool) -> void:
	main.release_attack(self)
	state = "cool"
	state_t = seconds
	glinted = false
	aim_dir = Vector2.ZERO
	if quenched:
		heat = float(GOLEM["start_heat"])
	main.fx_text(global_position + Vector2(0, -radius - 26.0), String(GOLEM_TEXT["quenched" if quenched else "venting"]), Color(0.75, 0.85, 0.95) if quenched else Color(1.0, 0.75, 0.45))
	main.fx_burst(global_position, Vector2.UP, Color(0.9, 0.92, 0.95), 18, 140.0)
	main.sfx("hiss", 0.8, -2.0)


## A water barrel's splash (scripts/towers/wyvern_floor.gd).
func quench() -> void:
	if heat > float(GOLEM["quench_from"]) and state != "cool":
		_cool(float(GOLEM["quench_time"]), true)


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if state == "cool":
		amount *= float(GOLEM["cool_mult"])
		if said_t <= 0.0:
			said_t = 1.2
			main.fx_text(global_position + Vector2(0, -radius - 30.0), String(GOLEM_TEXT["cooling"]), Color(1.0, 0.9, 0.6))
	elif heat >= float(GOLEM["hot"]) and not pierce:
		amount *= float(GOLEM["hot_armor"])
		if said_t <= 0.0:
			said_t = 1.2
			main.fx_text(global_position + Vector2(0, -radius - 30.0), String(GOLEM_TEXT["glowing"]), Color(1.0, 0.6, 0.3))
	if state != "cool":
		heat = minf(1.0, heat + float(GOLEM["hit_heat"]))
	super.take_hit(amount, dir, force * 0.4, heavy, pierce)


func is_attacking() -> bool:
	return state.begins_with("wind")


func _hurt_voice() -> void:
	var now := Time.get_ticks_msec()
	if now < voice_at:
		return
	voice_at = now + int(randf_range(500.0, 950.0))
	main.sfx("hurt_smith", 0.7, -2.0)


func _leave_remains() -> void:
	main.sfx("kill_smith", 0.75, -2.0)
	main.sfx("hiss", 0.7, -6.0)
	super._leave_remains()


## Its heat as a colour: dull iron-red to white.
func heat_color() -> Color:
	var k := clampf(heat, 0.0, 1.0)
	if state == "cool":
		return Color(0.45, 0.32, 0.28)
	return Color(0.6, 0.18, 0.08).lerp(Color(1.0, 0.55, 0.18), clampf(k * 1.4, 0.0, 1.0)).lerp(Color(1.0, 0.92, 0.65), clampf((k - 0.85) / 0.15, 0.0, 1.0))


func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var step := sin(_stride) * _move
	var cool := state == "cool"
	var iron := color if not cool else color.darkened(0.25)
	var hc := heat_color()
	# Stumpy legs.
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 7.0 + f * (step * sgn * 3.5 - 1.0), 5.0, iron.darkened(0.25))
	# The fists: raised in the slam's wind-up, brought down after.
	var raise := _ease("raise", _wk(float(GOLEM["slam_wind"])) if state == "wind_slam" else 0.0, 14.0)
	var slump := _ease("slump", 1.0 if cool else 0.0, 5.0)
	for sgn in [-1.0, 1.0]:
		var sh: Vector2 = s * sgn * radius * 0.85
		var fist: Vector2 = sh + f * (radius * 0.55) * (1.0 - raise) - f * radius * 0.2 * raise + s * sgn * 3.0 * slump + Vector2(0, 6.0 * slump)
		if sgn > 0.0 and raise > 0.0:
			fist += Vector2(0, -10.0 * raise)
		p.limb(sh, fist, iron.darkened(0.1), 6.0)
		p.ball(fist, 6.2, iron.darkened(0.05))
		_glow.circle(fist + f * 2.0, 1.8, Color(hc, 0.4 + 0.5 * heat), 8)
	# The body: a squat block of plates, its seams glowing with its heat.
	var bpts := PackedVector2Array([f * radius * 0.8 + s * radius * 0.7, f * radius * 0.2 + s * radius * 0.95, -f * radius * 0.75 + s * radius * 0.8,
		-f * radius * 0.75 - s * radius * 0.8, f * radius * 0.2 - s * radius * 0.95, f * radius * 0.8 - s * radius * 0.7])
	for i in bpts.size():
		bpts[i] += Vector2(0, 3.0 * slump)
	p.poly(bpts, iron, 1.8)
	p.quad(f * radius * 0.6 + s * radius * 0.6, -f * radius * 0.6 + s * radius * 0.65, 1.2, iron.lightened(0.18))
	var seam := Color(hc, 0.55 + 0.45 * heat * (0.85 + 0.15 * sin(t * 8.0)))
	_glow.quad(s * radius * 0.05 + f * radius * 0.7, s * radius * 0.05 - f * radius * 0.6, 1.6 + heat * 1.4, seam)
	_glow.quad(-s * radius * 0.6 + f * radius * 0.05, s * radius * 0.6 + f * radius * 0.05, 1.4 + heat * 1.2, seam)
	# Its belly: a furnace grate over a glowing core.
	var core := -f * radius * 0.15 + Vector2(0, 2.0 * slump)
	p.circle(core, radius * 0.38, Palette.OUTLINE, 14)
	_glow.circle(core, radius * 0.32, Color(hc, 0.55 + 0.45 * heat), 14)
	for k in 3:
		var o := (k - 1) * radius * 0.2
		p.quad(core + s * o - f * radius * 0.3, core + s * o + f * radius * 0.3, 1.1, iron.darkened(0.35))
	# Rivets at its corners.
	for c in [bpts[0], bpts[2], bpts[3], bpts[5]]:
		p.circle(c * 0.82, 1.6, iron.lightened(0.3), 8)
	# The head: a small helm-block with a slit for an eye, jutting forward.
	var hd := f * (radius * 0.85) + Vector2(0, -3.0 + 4.0 * slump)
	p.egg(hd, Vector2(7.0, 6.0), f.angle(), iron.darkened(0.12))
	_glow.quad(hd + f * 3.0 + s * 3.0, hd + f * 3.0 - s * 3.0, 1.4, Color(hc.lightened(0.2), 0.95 if not cool else 0.35))
	# Venting: steam off its back.
	if cool:
		for k in 3:
			var ph := fmod(t * 0.9 + k * 0.33, 1.0)
			_glow.circle(-f * 4.0 + s * (k - 1) * 5.0 + Vector2(0, -8.0 - ph * 22.0), 2.0 + ph * 4.0, Color(0.92, 0.94, 0.97, 0.45 * (1.0 - ph)), 10)


func _overlay_extra(o) -> void:
	if state == "wind_slam":
		_target(o, face * float(GOLEM["slam_reach"]), float(GOLEM["slam_radius"]), _wk(float(GOLEM["slam_wind"])), 0.1)
	if state == "wind_flare":
		var k := _wk(float(GOLEM["flare_wind"]))
		var r := float(GOLEM["flare_radius"])
		o.circle(Vector2.ZERO, r, Color(Palette.DANGER, 0.08 + 0.12 * k), 48)
		o.arc(Vector2.ZERO, r, 0.0, TAU, 2.5, Color(Palette.DANGER, 0.7), 48)
		o.arc(Vector2.ZERO, r * k, 0.0, TAU, 1.5, Color(1.0, 0.7, 0.3, 0.85), 40)
	# Its heat, as a ring at its feet that fills (white-hot near venting).
	if heat > 0.05 and state != "cool":
		o.arc(Vector2(0, radius * 0.7), radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * heat, 2.0, Color(heat_color(), 0.75), 28)
