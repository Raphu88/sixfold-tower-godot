extends "res://scripts/enemy.gd"
## THE HUSK (kind "husk"; enemy.gd SUBKINDS spawns it with this script): the
## empty gear of a climber who died in the tower, still moving. Found in every
## tower. It fights like a climber:
##   slash   up close: the blade goes up over its shoulder (the wind-up),
##           glints, and cuts a wedge in front of it (parry it)
##   lunge   from a few steps off: a red lane, a glint, then it drives along
##           it (parry it, or step aside)
##   roll    it reads your wind-ups (a bow drawn, a spell gathering, the
##           blow that ends your chain) and rolls away from them, now and
##           then (RULES "roll_cd"); it can't be struck mid-roll
##   guard   strike it three times in the same rhythm and it reads you: its
##           blade comes up crosswise (a pale arc in front of it). The next
##           blow on that beat, from the front, is parried, and it answers
##           with a quick cut (it glints). Change your timing (wait a beat)
##           and the guard breaks: "Off the beat!"; a blow from behind is
##           never parried.
## After each attack it stands open (the gold ring). Words and numbers:
## RULES, TEXT (the Data editor's "New monsters").

static var RULES := {
	"slash": 60.0, "slash_arc": 60.0, "slash_wind": 0.55,
	"lunge": 150.0, "lunge_speed": 620.0, "lunge_wind": 0.65,
	"roll": 0.38, "roll_speed": 300.0, "roll_cd": 3.0,
	"beat": 0.1,  # seconds either side of your last gap that count as the same rhythm
	"read": 3.0,  # blows in the same rhythm before it raises its guard
	"guard": 1.4,  # how long it holds its guard, waiting for the next blow
	"riposte_wind": 0.5,
	"recover": 0.9,
}
static var TEXT := {"read": "It reads your rhythm", "parried": "Parried!", "rolls": "Rolled away", "off": "Off the beat!"}

const C_CLOTH := Color(0.36, 0.33, 0.3)
const C_VOID := Color(0.05, 0.04, 0.06)
const C_EMBER_EYE := Color(0.62, 0.86, 1.0)

var _clock := 0.0
var _last := -1.0  # when the last blow fell (its own clock)
var _gap := -1.0  # the gap before it
var _streak := 0  # blows in a row on the same beat
var _roll_cd := 0.0
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "recover"


func _physics_process(delta: float) -> void:
	_clock += delta
	_roll_cd -= delta
	super._physics_process(delta)


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("husk")
	match state:
		"roll":
			state_t -= delta
			velocity = aim_dir * float(RULES["roll_speed"])
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.25
		"guard":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				_streak = 0
				state = "chase"
		"wind_slash", "wind_riposte":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				_slash_at(p)
				_end_attack("recover", float(RULES["recover"]))
		"wind_lunge":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = lunge_dir.slerp(dir, minf(1.0, 5.0 * delta))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 8.0)) / float(RULES["lunge_speed"])):
				state = "lunge"
				state_t = float(RULES["lunge"]) / float(RULES["lunge_speed"])
				lunge_hit = false
				main.sfx("thrust", 0.85, -2.0)
		"lunge":
			state_t -= delta
			velocity = lunge_dir * float(RULES["lunge_speed"])
			if not lunge_hit and dist < radius + p.radius + 8.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", float(RULES["recover"]) + 0.1)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:  # chase: like a climber, it keeps its distance until it commits
			if _should_roll(p, dist):
				_roll_from(dir)
				return
			if dist < float(RULES["slash"]) + 8.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_slash", float(RULES["slash_wind"]))
				main.sfx("warn_knight", 1.25, -3.0)
			elif dist > 95.0 and dist < float(RULES["lunge"]) + 20.0 and randf() < delta * 0.9 and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_lunge", float(RULES["lunge_wind"]))
				main.sfx("warn_knight", 1.15, -3.0)
			elif main.holds_attack(self) or main.can_attack():
				velocity = dir * speed
			else:
				_circle(dir, dist, 120.0, speed * 0.7)


## Your wind-ups it reads: a bow drawn, a spell gathering, a finisher due next.
func _should_roll(p, dist: float) -> bool:
	if _roll_cd > 0.0 or dist > 150.0 or not ("cast_t" in p):
		return false
	if bool(p.get("drawing")) or float(p.get("cast_t")) > 0.0:
		return true
	if dist < 90.0 and float(p.get("combo_t")) > 0.0 and p.has_method("wdata"):
		var chain: Array = p.wdata().get("combo", [])
		if not chain.is_empty() and bool(chain[int(p.combo) % chain.size()].get("heavy", false)):
			return true
	return false


func _roll_from(dir: Vector2) -> void:
	_roll_cd = float(RULES["roll_cd"])
	var side := dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	aim_dir = (-dir * 0.8 + side * 0.6).normalized()
	if main.layout_on and main.is_solid(global_position + aim_dir * 60.0):
		aim_dir = (-dir * 0.8 - side * 0.6).normalized()
	main.release_attack(self)
	state = "roll"
	state_t = float(RULES["roll"])
	main.sfx("roll", 0.9, -4.0)


func _slash_at(p) -> void:
	var reach := float(RULES["slash"])
	var arc := deg_to_rad(float(RULES["slash_arc"]))
	main.fx_cone(global_position, lunge_dir, reach + 8.0, arc, Color(1.0, 0.45, 0.35))
	main.sfx("swing", 0.85)
	var to: Vector2 = p.global_position - global_position
	if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= arc:
		p.receive_attack(dmg, self)


## Its rhythm reading: three blows on one beat and it guards; the next on
## that beat, from the front, is parried. Mid-roll nothing touches it.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if dir == Vector2.ZERO or main == null:
		super.take_hit(amount, dir, force, heavy, pierce)  # (burning, bleeding: no rhythm in those)
		return
	if state == "roll":
		main.fx_text(global_position + Vector2(0, -radius - 22.0), TEXT["rolls"], Color(0.85, 0.85, 0.8))
		return
	var gap := _clock - _last if _last >= 0.0 else -1.0
	var same := gap > 0.0 and gap < 1.6 and _gap > 0.0 and absf(gap - _gap) <= float(RULES["beat"])
	if state == "guard":
		var front := face.dot(-dir) > 0.2
		if same and front:
			_parry(dir)
			_last = _clock
			return
		_streak = 0
		state = "recover"
		state_t = 0.5
		main.fx_text(global_position + Vector2(0, -radius - 34.0), TEXT["off"], Color(1.0, 0.85, 0.45))
		open_t = maxf(open_t, 0.6)  # (caught off its guard)
	elif same:
		_streak += 1
	elif gap > 0.0 and gap < 1.6:
		_streak = 1
	else:
		_streak = 0
	if gap > 0.0 and gap < 1.6:
		_gap = gap
	_last = _clock
	super.take_hit(amount, dir, force, heavy, pierce)
	if dead or state == "guard":
		return
	if _streak >= int(RULES["read"]) - 1 and not is_attacking() and stun <= 0.0:
		_streak = 0
		flinch = 0.0
		state = "guard"
		state_t = float(RULES["guard"])
		main.release_attack(self)
		main.fx_text(global_position + Vector2(0, -radius - 34.0), TEXT["read"], Color(0.75, 0.88, 1.0))
		main.sfx("equip_sword", 0.8, -4.0)


func _parry(dir: Vector2) -> void:
	var p = main.player
	main.fx_text(global_position + Vector2(0, -radius - 34.0), TEXT["parried"], Color(0.75, 0.88, 1.0))
	main.fx_ring(global_position - dir * radius, Color(0.8, 0.9, 1.0), 40.0, 0.3, 3.0)
	main.fx_burst(global_position - dir * radius, -dir, Color(0.85, 0.92, 1.0), 10, 260.0)
	main.sfx("parry", 0.85)
	if p != null:
		p.knock = (p.global_position - global_position).normalized() * 200.0
	_streak = 0
	_gap = -1.0
	flinch = 0.0
	if main.request_attack(self):
		lunge_dir = -dir
		_begin_wind("wind_riposte", float(RULES["riposte_wind"]))
	else:
		state = "recover"
		state_t = 0.4


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A climber's empty gear, seen from above: a hood over nothing (two cold
## lights where a face was), a tattered cloak, dented pauldrons, a notched
## blade. Raised crosswise on guard; tumbling in a roll.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var col: Color = color
	if state == "roll":
		var a := t * 18.0
		p.ball(Vector2.ZERO, radius * 0.85, C_CLOTH)
		p.arc(Vector2.ZERO, radius * 0.55, a, a + 2.4, 2.0, col.lightened(0.15), 10)
		p.arc(Vector2.ZERO, radius * 0.55, a + PI, a + PI + 2.0, 2.0, C_CLOTH.darkened(0.3), 10)
		_glow.circle(Vector2.from_angle(a) * 4.0, 1.1, C_EMBER_EYE, 8)
		return
	var step := sin(_stride) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 5.0 + f * (step * sgn * 4.0 + 1.5), 3.3, Color(0.3, 0.24, 0.2))
	# The cloak, ragged at the hem, trailing behind.
	var hem := PackedVector2Array()
	for i in 9:
		var a := f.angle() + PI * 0.5 + PI * float(i) / 8.0
		var rr := radius * (1.15 + 0.18 * float(i % 2)) + sin(t * 3.0 + i) * 1.2
		hem.append(Vector2.from_angle(a) * rr - f * 3.0)
	hem.append(s * radius * 0.6 + f * 2.0)
	hem.append(-s * radius * 0.6 + f * 2.0)
	p.poly(hem, C_CLOTH.darkened(0.15), 1.4)
	p.ball(Vector2.ZERO, radius * 0.82, C_CLOTH)
	# Blade: low and ready; up over the shoulder to slash; cocked to lunge;
	# crosswise in front on guard.
	var ang := -1.0
	var gx := radius * 0.85
	var gy := 3.0
	var rate := 14.0
	if state in ["wind_slash", "wind_riposte"]:
		var k := _wk(float(RULES["slash_wind"]))
		ang = -1.0 - 1.5 * k
		gx = radius * (0.85 - 0.3 * k)
		gy = 3.0 - 7.0 * k
	elif state == "wind_lunge":
		ang = -0.15
		gx = radius * 0.5
		gy = -6.0 * _wk(float(RULES["lunge_wind"]))
	elif state == "lunge":
		ang = -0.05
		gx = radius * 0.4
		gy = 10.0
		rate = 30.0
	elif state == "guard":
		ang = -PI * 0.5
		gx = radius * 0.55
		gy = 9.0
		rate = 22.0
	ang = _ease("blade_a", ang, rate)
	gx = _ease("blade_x", gx, rate)
	gy = _ease("blade_y", gy, rate)
	var grip := -s * gx + f * gy
	p.limb(-s * radius * 0.7, grip, C_CLOTH.lightened(0.05), 3.4)
	_sword(p, grip, f.rotated(ang), 21.0)
	p.tri(grip + f.rotated(ang) * 12.0, grip + f.rotated(ang) * 14.0 + f.rotated(ang).orthogonal() * 1.6, grip + f.rotated(ang) * 16.0, Palette.OUTLINE)  # (a notch in it)
	# Dented pauldrons, one cracked.
	for sgn in [-1.0, 1.0]:
		p.egg(s * sgn * radius * 0.7 + f * 1.0, Vector2(5.0, 4.0), f.angle(), col)
	p.quad(s * radius * 0.7 + f * 3.0, s * radius * 0.85 - f * 1.0, 0.9, Palette.OUTLINE)
	# The hood, and nothing in it but two cold lights.
	p.ball(f * 2.0, 7.0, C_CLOTH.lightened(0.08))
	p.oval(f * 5.0, Vector2(3.6, 4.6), f.angle(), C_VOID, 12)
	var lit := _ease("eyes", 1.0 if state.begins_with("wind") or state == "guard" else 0.45, 10.0)
	for sgn in [-1.0, 1.0]:
		_glow.circle(f * 6.0 + s * sgn * 1.6, 1.0, Color(C_EMBER_EYE, 0.5 + 0.5 * lit), 8)
	# Dust sifting off it.
	for i in 2:
		var ph := fmod(t * 0.5 + i * 0.5, 1.0)
		p.circle(-f * (6.0 + ph * 8.0) + s * (i * 2 - 1) * 4.0, 1.2 * (1.0 - ph), Color(0.55, 0.5, 0.45, 0.5 * (1.0 - ph)), 6)


func _overlay_extra(o) -> void:
	var danger := Palette.DANGER
	if state in ["wind_slash", "wind_riposte"]:
		var half := deg_to_rad(float(RULES["slash_arc"]))
		var k := _wk(float(RULES["riposte_wind"] if state == "wind_riposte" else RULES["slash_wind"]))
		o.wedge(Vector2.ZERO, float(RULES["slash"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.1 + 0.15 * k), 12)
		o.arc(Vector2.ZERO, float(RULES["slash"]) * k, lunge_dir.angle() - half, lunge_dir.angle() + half, 2.0, Color(danger, 0.7), 14)
	elif state == "wind_lunge":
		var k := _wk(float(RULES["lunge_wind"]))
		o.quad(Vector2.ZERO, lunge_dir * float(RULES["lunge"]), radius * 1.8, Color(danger, 0.13))
		o.quad(Vector2.ZERO, lunge_dir * float(RULES["lunge"]) * k, radius * 1.8, Color(danger, 0.35))
	elif state == "guard":
		# Its guard: a pale arc in front of it (the blow on that beat is parried).
		var br := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
		o.arc(Vector2.ZERO, radius + 9.0, face.angle() - 1.1, face.angle() + 1.1, 3.0, Color(0.78, 0.9, 1.0, 0.85 * br), 16)
		o.arc(Vector2.ZERO, radius + 14.0, face.angle() - 0.8, face.angle() + 0.8, 1.5, Color(0.78, 0.9, 1.0, 0.45 * br), 12)
	elif _streak >= 1:
		# Counting your beat: a pip for each blow it has read.
		for i in _streak:
			o.circle(Vector2(-4.0 + 8.0 * i, -radius - 18.0), 2.0, Color(0.78, 0.9, 1.0, 0.8), 8)
