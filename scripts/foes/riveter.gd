extends "res://scripts/enemy.gd"
## THE RIVETER (kind "riveter"; enemy.gd SUBKINDS spawns it with this
## script): the Wyvern's small flying iron device, held up by two whirring
## rotors. It hovers at range; to attack it stops, its lens glows and a red
## line shows its aim (it glints), then it fires a burst of three rivets
## along that line. The first two only glance off a parry; the third glows
## hot (it glints again as it fires): parry that one and it flies straight
## back, knocking the riveter out of the air, where it lies sparking a while,
## open to blows. Or roll through the burst. Words and numbers: RULES, TEXT.

const Rivet := preload("res://scripts/foes/rivet.gd")

static var RULES := {
	"keep": 190.0,  # how far it keeps from you
	"range": 300.0,  # it fires from this near
	"wind": 0.75,  # the burst's warning (the aim line)
	"gap": 0.24,  # seconds between rivets
	"speed": 330.0,  # how fast a rivet flies
	"down": 2.0,  # sent back, it lies on the floor this long (open)
	"recover": 1.6,
}
static var TEXT := {"down": "Sent back!"}

const C_IRON_DARK := Color(0.3, 0.3, 0.34)
const C_LENS := Color(1.0, 0.35, 0.25)

var shots := 0
var gap_t := 0.0
var _bursts := 0  # (tests)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "hover"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 380.0:
		_told = true
		main.tip("riveter")
	match state:
		"wind_burst":
			velocity = Vector2.ZERO
			if not glinted:
				aim_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / float(RULES["speed"])):
				state = "burst"
				shots = 0
				gap_t = 0.0
				_bursts += 1
		"burst":
			velocity = Vector2.ZERO
			gap_t -= delta
			if gap_t <= 0.0:
				gap_t = float(RULES["gap"])
				_fire(shots == 2)
				shots += 1
				if shots >= 3:
					_end_attack("recover", float(RULES["recover"]))
		"down":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.5
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, float(RULES["keep"]), speed * 0.6)
			if state_t <= 0.0:
				state = "hover"
		_:
			if dist < float(RULES["range"]) and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				aim_dir = dir
				_begin_wind("wind_burst", float(RULES["wind"]))
				main.sfx("crossbow_reload", 1.4, -4.0)
			elif dist < float(RULES["keep"]) - 50.0:
				velocity = -dir * speed
			else:
				_circle(dir, dist, float(RULES["keep"]), speed)


func _fire(hot: bool) -> void:
	var r = Rivet.new()
	r.main = main
	r.position = global_position + aim_dir * radius
	r.vel = aim_dir * float(RULES["speed"])
	r.dmg = dmg
	r.last = hot
	r.shooter = self
	main.add_child(r)
	main.sfx("crossbow", 1.5, -4.0)
	if hot:
		glint = 0.22  # (the hot one glints as it flies: parry it)
		main.sfx("glint", 1.1, 0.0, 0.03)


## Its own hot rivet came back: knocked out of the air.
func sent_back() -> void:
	if dead or state == "down":
		return
	main.release_attack(self)
	glinted = false
	state = "down"
	state_t = float(RULES["down"])
	open_t = float(RULES["down"])
	main.fx_text(global_position + Vector2(0, -radius - 26.0), TEXT["down"], Color(1.0, 0.85, 0.5))
	main.fx_burst(global_position, Vector2.DOWN, Color(1.0, 0.7, 0.3), 12, 200.0)
	main.sfx("hit_armor", 0.8)


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A riveted iron drum seen from above, held up by two rotors (spinning
## blurs), a short barrel and a red lens toward you; the lens glows as it
## aims. Knocked down, it lies on the floor, rotors stopped, sparking.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var down := state == "down"
	var h: float = _ease("h", 0.0 if down else 14.0, 8.0)
	var o := Vector2(0, -h + (0.0 if down else sin(t * 5.0) * 1.2))
	var aim := _ease("aim", 1.0 if state in ["wind_burst", "burst"] else 0.0, 12.0)
	# Rotors on two arms.
	for sgn in [-1.0, 1.0]:
		var hub: Vector2 = o + s * sgn * (radius + 3.0) - f * 1.5
		p.limb(o + s * sgn * radius * 0.6, hub, C_IRON_DARK, 2.0)
		if down:
			p.quad(hub - f * 6.0, hub + f * 6.0, 1.6, C_IRON_DARK.lightened(0.2))
		else:
			p.circle(hub, 7.5, Color(0.85, 0.88, 0.95, 0.22), 16)
			var a: float = t * 40.0 * sgn
			p.quad(hub - Vector2.from_angle(a) * 7.0, hub + Vector2.from_angle(a) * 7.0, 1.4, Color(0.8, 0.82, 0.88, 0.7))
		p.circle(hub, 1.6, C_IRON_DARK, 8)
	# The drum and its rivets.
	p.ball(o, radius * 0.85, color)
	for i in 6:
		p.circle(o + Vector2.from_angle(TAU * i / 6.0 + 0.3) * radius * 0.62, 0.9, color.lightened(0.35), 6)
	# The barrel and the lens.
	p.limb(o + f * radius * 0.4, o + f * (radius + 3.0 - 1.5 * aim), C_IRON_DARK, 3.4)
	p.circle(o + f * 1.5, 2.6, Palette.OUTLINE, 10)
	_glow.circle(o + f * 1.5, 1.8, Color(C_LENS, 0.6 + 0.4 * aim), 10)
	if aim > 0.1:
		_glow.circle(o + f * 1.5, 4.5, Color(C_LENS, 0.25 * aim), 12)
	if down:
		for i in 2:
			var ph := fmod(t * 2.0 + i * 0.5, 1.0)
			_glow.circle(o + Vector2.from_angle(t * 5.0 + i * 3.0) * radius * 0.8 + Vector2(0, -ph * 6.0), 1.2 * (1.0 - ph), Color(1.0, 0.8, 0.4, 1.0 - ph), 6)


func _overlay_extra(o) -> void:
	if state == "wind_burst":
		var k := _wk(float(RULES["wind"]))
		o.quad(aim_dir * 12.0, aim_dir * float(RULES["range"]), 1.0 + 1.5 * k, Color(Palette.DANGER, 0.25 + 0.4 * k))
		o.circle(aim_dir * 12.0, 2.0 + 2.0 * k, Color(Palette.DANGER, 0.8), 12)
	elif state == "burst":
		o.quad(aim_dir * 12.0, aim_dir * float(RULES["range"]), 1.2, Color(Palette.DANGER, 0.3))
