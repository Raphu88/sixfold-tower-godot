extends "res://scripts/enemy.gd"
## The harrier: the Gryphon's tower's own creature (enemy.gd SUBKINDS spawns it with this script).
## A raptor that soars high over the open halls (only its shadow sweeps the
## floor), then folds its wings and dives at you with a glint. Its strike
## throws you the way it was flying: toward the edge if you stand on one.
## After the dive it stands on the floor a moment (your opening), then climbs
## back into the sky. Parry the dive near a drop (gryphon_floor.gd near_void)
## and it tumbles over the edge and falls; parried elsewhere it's staggered.
## A stunned flier over an open void falls too (gryphon_floor.gd).
## Its numbers are in HARRIER (the Data editor's "Monsters" numbers).

static var HARRIER := {
	"soar_r": 165.0,  # how far it circles from you
	"soar_h": 48.0,  # how high it flies (px it's drawn above its shadow)
	"dive_range": 290.0,  # it dives from this near
	"dive_speed": 520.0,
	"wind": 0.6,  # the dive's wind-up (the glint comes within it)
	"knock": 240.0,  # how hard its strike throws you (px/s, along the dive)
	"perch": 1.0,  # seconds on the floor after a dive (open)
	"climb": 0.7,  # seconds to climb back up
	"ledge": 75.0,  # a parry within this of a drop sends it over
}
static var HARRIER_TEXT := {"falls": "Sent falling!"}


static func _begin(e) -> void:
	e.state = "soar"
	e.state_t = randf_range(0.5, 1.5)
	e.set_meta("h", float(HARRIER["soar_h"]))


static func _own_act(e, delta: float, dir: Vector2, dist: float, p) -> void:
	var H := HARRIER
	var h: float = e.get_meta("h", float(H["soar_h"]))
	match e.state:
		"wind_dive":
			e.velocity = Vector2.ZERO
			h = move_toward(h, float(H["soar_h"]) * 1.1, delta * 60.0)
			if not e.glinted:
				e.aim_dir = dir
			var spd := maxf(float(H["dive_speed"]), maxf(0.0, dist - (e.radius + p.radius)) / (e.GLINT_LEAD * 0.85))
			e.set_meta("spd", spd)
			if e._wind(delta, maxf(0.0, dist - (e.radius + p.radius)) / spd):
				e.state = "dive"
				e.state_t = clampf((dist + 50.0) / spd, 0.25, 0.8)
				e.lunge_hit = false
				e.main.sfx("gust", 1.3, -6.0, 0.05)
		"dive":
			e.state_t -= delta
			var spd: float = e.get_meta("spd", float(H["dive_speed"]))
			e.velocity = e.aim_dir * spd
			h = move_toward(h, 0.0, delta * 260.0)
			if not e.lunge_hit and dist < e.radius + p.radius + 8.0:
				e.lunge_hit = true
				var before: float = p.hp
				p.receive_attack(e.dmg, e)
				if p.hp < before - 0.1 and not e.dead:
					p.knock = e.aim_dir * float(H["knock"])  # (thrown the way it flew)
					p.set_meta("thrown_until", Time.get_ticks_msec() + 400)  # (gryphon_floor.gd lets this one carry you over an edge)
			if e.state_t <= 0.0 and e.state == "dive":
				e._end_attack("perch", float(H["perch"]))
		"perch":
			e.velocity = Vector2.ZERO
			h = move_toward(h, 0.0, delta * 200.0)
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "climb"
				e.state_t = float(H["climb"])
				e.main.sfx("wingbeat", 0.8, -8.0, 0.05)
		"climb":
			e.state_t -= delta
			h = move_toward(h, float(H["soar_h"]), delta * float(H["soar_h"]) / float(H["climb"]))
			e._circle(dir, dist, float(H["soar_r"]), e.speed * 0.6)
			if e.state_t <= 0.0:
				e.state = "soar"
				e.state_t = randf_range(1.2, 2.2)
		_:  # soar: circle high, dive when it's our turn
			h = move_toward(h, float(H["soar_h"]), delta * 60.0)
			e.state_t -= delta
			e._circle(dir, dist, float(H["soar_r"]), e.speed)
			if e.state_t <= 0.0 and dist < float(H["dive_range"]) and e.main.request_attack(e):
				e._begin_wind("wind_dive", float(H["wind"]))
				e.aim_dir = dir
				e.main.sfx("warn_bat", 0.6, -2.0)
	e.set_meta("h", h)


## Parried near a drop: over the edge it goes.
static func _own_parried(e, _perfect: bool) -> bool:
	var tf = e.main.get("tower_floor")
	if tf == null or not tf.has_method("near_void") or not tf.near_void(e.global_position, float(HARRIER["ledge"])):
		return false
	e.main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), HARRIER_TEXT["falls"], Color(1.0, 0.89, 0.63))
	tf.drop_foe(e)
	return true


# --- as a monster (enemy.gd calls these) -------------------------------------------

func setup(k: String, room) -> void:
	super.setup(k, room)
	_begin(self)


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	_own_act(self, delta, dir, dist, p)


func _draw_own(p, t: float, f: Vector2) -> void:
	_own_draw(self, p, _glow, t, f)


func on_parried(perfect := false) -> void:
	if not _own_parried(self, perfect):
		super.on_parried(perfect)


# --- drawing -----------------------------------------------------------------------

const C_HARRIER_BELLY := Color(0.86, 0.8, 0.68)
const C_HARRIER_WING := Color(0.46, 0.38, 0.3)
const C_HARRIER_TIP := Color(0.24, 0.2, 0.18)
const C_HARRIER_BEAK := Color(0.96, 0.78, 0.3)


## Seen from above: broad wings spread on the soar, folded back in the dive,
## a fanned tail, a pale breast and a hooked beak; high up it's drawn above
## its shadow (enemy.gd draws the shadow where it is).
static func _own_draw(e, p, glow, t: float, f: Vector2) -> void:
	var h: float = e.get_meta("h", 40.0)
	var o := Vector2(0, -h)
	var s := f.orthogonal()
	var dive := 1.0 if e.state == "dive" else 0.0
	var wind := clampf(e._wk(float(HARRIER["wind"])), 0.0, 1.0) if e.state == "wind_dive" else 0.0
	var fold: float = e._ease("fold", 0.85 if e.state == "dive" else (0.15 + 0.35 * wind if e.state == "wind_dive" else (0.55 if e.state == "perch" else 0.0)), 14.0)
	var beat := sin(e._flap * (1.0 if e.state == "soar" else 2.2)) * (0.15 if e.state == "soar" else 0.35)
	if h > 6.0:
		# (the far shadow under it while it's high: a second, fainter one)
		p.oval(Vector2(0, e.radius * 0.7), Vector2(e.radius * 2.2, e.radius * 0.7), f.angle(), Color(0, 0, 0, 0.12 * clampf(h / 40.0, 0.0, 1.0)))
	var col: Color = e.color
	# Tail: a fan of feathers behind.
	for k in 5:
		var a := (k - 2) * 0.16 * (1.0 - fold * 0.6)
		e._feather(p, o - f * 6.0, (-f).rotated(a), 13.0, 4.0, C_HARRIER_WING.darkened(0.1 + 0.05 * absf(k - 2)))
	# Wings: long, stepped primaries; swept back as it folds.
	for sgn in [-1.0, 1.0]:
		var out: Vector2 = (s * sgn * (1.0 - fold) - f * (0.25 + fold * 0.9) + s * sgn * beat * 0.4).normalized()
		var span := 26.0 * (1.0 - fold * 0.45)
		var root: Vector2 = o + s * sgn * 4.0
		var wpts := PackedVector2Array([root + f * 4.0, root + out * span * 0.55 + f * 3.0, root + out * span, root + out * span * 0.9 - f * 6.0, root - f * 5.0])
		p.poly(wpts, C_HARRIER_WING, 1.3)
		for k in 4:
			var at: Vector2 = root + out * span * (0.62 + 0.11 * k)
			e._feather(p, at, (out - f * 0.5).normalized(), 9.0 - k, 3.0, C_HARRIER_TIP)
		p.quad(root + out * span * 0.2, root + out * span * 0.85, 2.0, C_HARRIER_WING.lightened(0.15), 1.0)
	# Body: a pale breast, a darker back.
	p.egg(o, Vector2(9.0, 6.5), f.angle(), col, true)
	p.oval(o + f * 1.5, Vector2(5.5, 3.6), f.angle(), C_HARRIER_BELLY)
	# Head and hooked beak.
	var head := o + f * 9.0
	p.ball(head, 4.6, col.lightened(0.1))
	p.tri(head + f * 3.0 + s * 2.2, head + f * 8.5 + s * 0.2, head + f * 3.0 - s * 2.2, C_HARRIER_BEAK)
	p.tri(head + f * 8.5 + s * 0.2, head + f * 6.0 - s * 1.2, head + f * 7.4 + s * 1.0, C_HARRIER_BEAK.darkened(0.3))
	for sgn in [-1.0, 1.0]:
		glow.circle(head + f * 1.6 + s * sgn * 2.4 + Vector2(0, -0.6), 1.2, Color(1.0, 0.85, 0.35) if e.state in ["wind_dive", "dive"] else Color(0.15, 0.12, 0.1), 8)
	if dive > 0.0:
		# Wind tearing off it in the dive.
		for k in 3:
			var q: Vector2 = o - f * (12.0 + k * 7.0) + s * (k - 1) * 6.0
			glow.quad(q, q - f * 10.0, 1.2, Color(0.9, 0.95, 1.0, 0.35), 0.3)
