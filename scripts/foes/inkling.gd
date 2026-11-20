extends "res://scripts/enemy.gd"
## THE INKLING (kind "inkling"; enemy.gd SUBKINDS spawns it with this
## script): the Kraken's tower's small octopus. It keeps a few steps off, then
## puffs up (a dark ring marks where the ink will land, on you) and sprays: a
## cloud of ink spreads where you stood, darkening the floor round you for a
## few seconds (foes/marks.gd "ink"). It slips into the cloud and nips from
## inside it: its warning wedge and glint show over the ink, so watch for the
## flash and parry, or walk out of the cloud. After a nip it stands open. The
## ink itself doesn't hurt. Words and numbers: RULES, TEXT.

const Marks := preload("res://scripts/foes/marks.gd")

static var RULES := {
	"keep": 140.0,  # how far it keeps from you
	"spray": 230.0,  # it sprays from this near
	"puff": 0.7,  # it puffs up this long first (the ring shows where)
	"cloud": 80.0,  # the cloud's radius
	"cloud_t": 4.0,  # how long the cloud lasts
	"nip": 44.0,  # the nip's reach
	"nip_arc": 60.0,
	"nip_wind": 0.45,
	"every": 5.0,  # seconds between sprays
	"recover": 0.9,
}
static var TEXT := {"ink": "Ink!"}

const C_INK := Color(0.08, 0.05, 0.14)

var spray_cd := 1.5
var cloud_at := Vector2.INF
var cloud_t := 0.0
var ink_spot := Vector2.ZERO
var _sprays := 0  # (tests)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "swim"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("inkling")
	spray_cd -= delta
	cloud_t -= delta
	if cloud_t <= 0.0:
		cloud_at = Vector2.INF
	match state:
		"puff":
			velocity = Vector2.ZERO
			state_t -= delta
			ink_spot = p.global_position
			if state_t <= 0.0:
				_spray()
				state = "slip"
				state_t = 2.5
		"slip":
			# Into the cloud, toward you.
			state_t -= delta
			velocity = dir * speed * 1.2
			if dist < float(RULES["nip"]) + 4.0 or state_t <= 0.0:
				lunge_dir = dir
				_begin_wind("wind_nip", float(RULES["nip_wind"]))
				main.sfx("warn_lurker", 1.5, -6.0)
		"wind_nip":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var reach := float(RULES["nip"])
				var arc := deg_to_rad(float(RULES["nip_arc"]))
				main.fx_cone(global_position, lunge_dir, reach + 6.0, arc, Color(1.0, 0.5, 0.5))
				main.sfx("swing_light", 1.3)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= arc:
					p.receive_attack(dmg, self)
				_end_attack("recover", float(RULES["recover"]))
		"recover", "idle":
			state_t -= delta
			velocity = -dir * speed * 0.3
			if state_t <= 0.0:
				state = "swim"
		_:  # swim: keep off, spray when it's our turn
			if spray_cd <= 0.0 and dist < float(RULES["spray"]) and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				state = "puff"
				state_t = float(RULES["puff"])
				ink_spot = p.global_position
				main.sfx("bubble", 0.7, -4.0)
			elif dist < float(RULES["nip"]) + 4.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_nip", float(RULES["nip_wind"]))
				main.sfx("warn_lurker", 1.5, -6.0)
			else:
				_circle(dir, dist, float(RULES["keep"]), speed)


func _spray() -> void:
	_sprays += 1
	spray_cd = float(RULES["every"])
	cloud_at = ink_spot
	cloud_t = float(RULES["cloud_t"])
	var m = Marks.make(main, "ink", RULES, self)
	m.beads.append({"pos": ink_spot, "t": float(RULES["cloud_t"]), "max": float(RULES["cloud_t"])})
	main.fx_burst(global_position, (ink_spot - global_position).normalized(), C_INK, 14, 300.0)
	main.fx_text(ink_spot + Vector2(0, -50), TEXT["ink"], Color(0.6, 0.5, 0.8))
	main.sfx("hiss", 0.6, -4.0)


## True while `pos` is inside its cloud (tests, and the Entity's word).
func in_cloud(pos: Vector2) -> bool:
	return cloud_at != Vector2.INF and pos.distance_to(cloud_at) < float(RULES["cloud"])


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A small octopus seen from above: a round mantle, eight curling arms that
## wave as it swims, big eyes; it swells as it puffs up to spray.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var puff := _ease("puff", _wk(float(RULES["puff"])) if state == "puff" else 0.0, 12.0)
	var o := Vector2.ZERO
	# Arms, trailing behind and curling.
	for i in 8:
		var a := f.angle() + PI + (float(i) - 3.5) * 0.36
		var base: Vector2 = o + Vector2.from_angle(a) * radius * 0.6
		var wave := sin(t * 6.0 + i * 0.9) * 0.5
		var mid: Vector2 = base + Vector2.from_angle(a + wave * 0.5) * 6.0
		var tip: Vector2 = mid + Vector2.from_angle(a + wave) * 5.5
		p.tube(PackedVector2Array([base, mid, tip]), PackedFloat32Array([3.0, 2.2, 1.0]), color.darkened(0.12))
		p.circle(mid, 0.7, C_SUCKER, 5)
	# Mantle.
	var r := radius * (0.85 + 0.3 * puff)
	p.egg(o - f * 1.0, Vector2(r, r * 0.92), f.angle(), color)
	p.oval(o - f * 3.5, Vector2(r * 0.4, r * 0.3), f.angle(), color.lightened(0.18), 10)
	# Eyes, and a dark siphon that puffs.
	for sgn in [-1.0, 1.0]:
		p.ball(o + f * 3.5 + s * sgn * 3.6, 2.4, C_EYE, true)
		p.circle(o + f * 4.2 + s * sgn * 3.6, 1.1, Palette.OUTLINE, 8)
	p.circle(o + f * (r + 1.0), 1.6 + 1.6 * puff, C_INK, 10)


func _overlay_extra(o) -> void:
	var danger := Palette.DANGER
	if state == "puff":
		var k := _wk(float(RULES["puff"]))
		var at := ink_spot - global_position
		var r := float(RULES["cloud"])
		o.circle(at, r, Color(0.25, 0.12, 0.4, 0.1 + 0.12 * k), 36)
		o.arc(at, r, 0.0, TAU, 2.0, Color(0.55, 0.4, 0.85, 0.7), 36)
		o.arc(at, r * (1.0 - k) + 6.0, 0.0, TAU, 1.5, Color(0.7, 0.55, 1.0, 0.8), 30)
	elif state == "wind_nip":
		var half := deg_to_rad(float(RULES["nip_arc"]))
		o.wedge(Vector2.ZERO, float(RULES["nip"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.18 + 0.2 * _wk(float(RULES["nip_wind"]))), 10)
		# Its eyes over the ink, so you can see where it is.
		var s := face.orthogonal()
		for sgn in [-1.0, 1.0]:
			o.circle(face * 3.5 + s * sgn * 3.6, 1.6, Color(1.0, 0.95, 0.7, 0.9), 8)
