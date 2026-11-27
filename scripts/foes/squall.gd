extends "res://scripts/enemy.gd"
## THE SQUALL (kind "squall"; enemy.gd SUBKINDS spawns it with this script):
## the Gryphon's tower's whirl of wind. It drifts over the drops (it flies)
## and keeps a few steps off. Whirling, the wind turns most of every blow
## (RULES "shield"). To attack it stops, spins up (streaks run down a lane in
## front of it: the warning) and lets go a gust down that lane. A gust can't
## be parried: step sideways out of the lane, or roll through it. Caught,
## you're shoved down the lane, bent toward a drop if one is near you (the
## gust can carry you over: it's wind). Other monsters in the lane are shoved
## too. After a gust it slows to wind up its next spin: then it is open, and
## blows land in full. Words and numbers: RULES, TEXT.

const Grid := preload("res://scripts/towers/water_wind_grid.gd")

static var RULES := {
	"keep": 120.0,  # how far it keeps from you
	"range": 210.0,  # it gusts from this near
	"wind": 0.85,  # the gust's warning
	"lane": 230.0,  # how far the gust reaches
	"width": 70.0,  # ...and how wide its lane is
	"push": 300.0,  # how hard it shoves (px/s)
	"spin_up": 1.6,  # seconds it's open after a gust
	"shield": 0.35,  # the share of a blow it takes while whirling
	"edge": 110.0,  # a drop this near you bends the gust toward it
	"bend": 0.6,  # ...this much
}
static var TEXT := {"turned": "The wind turns it"}

const C_WIND := Color(0.84, 0.92, 1.0)

var _turned_at := 0
var _told := false
var _gusts := 0  # (tests)


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "whirl"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 380.0:
		_told = true
		main.tip("squall")
	match state:
		"wind_gust":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				_gust(p)
				_end_attack("spinup", float(RULES["spin_up"]))
		"spinup":
			state_t -= delta
			velocity = -dir * speed * 0.15
			if state_t <= 0.0:
				state = "whirl"
		_:
			if dist < float(RULES["range"]) and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_gust", float(RULES["wind"]))
				main.sfx_at(global_position, "spell_wind", 1.3, -6.0)
			else:
				_circle(dir, dist, float(RULES["keep"]), speed)


## The gust: whoever stands in the lane is shoved down it (toward a drop if
## one is near them). It can't be parried.
func _gust(p) -> void:
	_gusts += 1
	var lane := float(RULES["lane"])
	var half := float(RULES["width"]) * 0.5
	main.sfx_at(global_position, "gust", 1.1)
	main.fx_burst(global_position + lunge_dir * radius, lunge_dir, C_WIND, 16, 420.0)
	for i in 3:
		var side := lunge_dir.orthogonal() * (float(i) - 1.0) * half * 0.6
		main.fx_bolt([global_position + side, global_position + side + lunge_dir * lane], Color(C_WIND, 0.5))
	if _in_lane(p.global_position, p.radius, lane, half) and p.iframes <= 0.0 and not p.dead:
		p.receive_attack(dmg, self, true)
		var push := lunge_dir
		var edge := _edge_dir(p.global_position)
		if edge != Vector2.ZERO:
			push = (lunge_dir * (1.0 - float(RULES["bend"])) + edge * float(RULES["bend"])).normalized()
		p.knock = push * float(RULES["push"])
		p.set_meta("thrown_until", Time.get_ticks_msec() + 450)  # (the wind may carry you over an edge: gryphon_floor.gd)
	for e in main.enemies():
		if e != self and not e.is_boss() and _in_lane(e.global_position, e.radius, lane, half):
			e.knock = lunge_dir * float(RULES["push"]) * 0.6


func _in_lane(pos: Vector2, r: float, lane: float, half: float) -> bool:
	var to := pos - global_position
	var along := to.dot(lunge_dir)
	return along > -r and along < lane + r and absf(to.dot(lunge_dir.orthogonal())) < half + r


## The way to the nearest drop within RULES "edge" of `pos` (or zero).
func _edge_dir(pos: Vector2) -> Vector2:
	var tf = main.get("tower_floor")
	var near := float(RULES["edge"])
	for d in [30.0, 55.0, 80.0, 110.0]:
		if d > near:
			break
		for k in 16:
			var q: Vector2 = pos + Vector2.from_angle(k * TAU / 16.0) * d
			var hole: bool = main.in_chasm(q)
			if not hole and tf != null and tf.has_method("is_void"):
				hole = tf.is_void(q)
			if hole:
				return (q - pos).normalized()
	return Vector2.ZERO


## Whirling, the wind turns most of a blow; spinning up, it lands in full.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if state == "whirl" and not pierce and dir != Vector2.ZERO:
		amount *= float(RULES["shield"])
		var now := Time.get_ticks_msec()
		if now > _turned_at and main != null:
			_turned_at = now + 900
			main.fx_text(global_position + Vector2(0, -radius - 34.0), TEXT["turned"], C_WIND)
	super.take_hit(amount, dir, force, heavy, pierce)


func _idle_state() -> String:
	return "whirl"


# --- drawing ------------------------------------------------------------------------

## A funnel of wind seen from above: rings of pale air turning round a dense
## core, grit and a leaf caught in it, two pale eyes in the eye of it. It
## spins faster as it winds up, and slows, loose and frayed, after a gust.
func _draw_own(p, t: float, f: Vector2) -> void:
	var wind := _wk(float(RULES["wind"])) if state == "wind_gust" else 0.0
	var rate := 4.0 + 10.0 * wind - (2.5 if state == "spinup" else 0.0)
	_spin += _dt * rate
	var o := Vector2(0, -6.0 + sin(t * 2.0) * 1.5)
	var loose := 1.25 if state == "spinup" else 1.0
	# Rings of air, each turning, broken into strokes.
	for ring in 4:
		var rr := (radius * 0.35 + ring * radius * 0.3) * loose
		var a0 := _spin * (1.0 + ring * 0.25) + ring * 1.3
		for seg in 3:
			var a := a0 + seg * TAU / 3.0
			p.arc(o, rr + 1.4, a, a + 1.4, 3.6, Color(Palette.OUTLINE, 0.35), 10)
			p.arc(o, rr, a, a + 1.4, 2.4, C_WIND.darkened(0.1 + 0.08 * ring).lerp(color, 0.3), 10)
	# The core.
	p.ball(o, radius * 0.38, C_WIND.lightened(0.1))
	# Grit and a leaf, whirled round.
	for i in 4:
		var a := -_spin * 1.6 + i * TAU / 4.0
		var at: Vector2 = o + Vector2.from_angle(a) * radius * (0.9 + 0.15 * sin(t * 3.0 + i)) * loose
		if i == 0:
			p.tri(at + Vector2.from_angle(a) * 3.0, at + Vector2.from_angle(a + 2.2) * 2.5, at + Vector2.from_angle(a - 2.2) * 2.5, Color(0.5, 0.62, 0.35))
		else:
			p.circle(at, 1.3, Color(0.55, 0.5, 0.45), 6)
	var s := f.orthogonal()
	for sgn in [-1.0, 1.0]:
		_glow.circle(o + f * 2.0 + s * sgn * 2.2, 1.1, Color(0.9, 0.97, 1.0, 0.7 + 0.3 * wind), 8)


func _overlay_extra(o) -> void:
	if state != "wind_gust":
		return
	var danger := Palette.DANGER
	var k := _wk(float(RULES["wind"]))
	var lane := float(RULES["lane"])
	var half := float(RULES["width"]) * 0.5
	var side := lunge_dir.orthogonal()
	o.quad(Vector2.ZERO, lunge_dir * lane, half * 2.0, Color(danger, 0.08 + 0.1 * k))
	o.quad(side * half, side * half + lunge_dir * lane, 1.5, Color(danger, 0.55))
	o.quad(-side * half, -side * half + lunge_dir * lane, 1.5, Color(danger, 0.55))
	# Streaks of wind running down the lane, faster as it winds up.
	var now := Time.get_ticks_msec() * 0.001
	for i in 5:
		var d := fmod(now * (160.0 + 260.0 * k) + i * lane / 5.0, lane)
		var off := side * (float(i % 3) - 1.0) * half * 0.55
		o.quad(off + lunge_dir * d, off + lunge_dir * minf(lane, d + 26.0), 1.6, Color(C_WIND, 0.7))
