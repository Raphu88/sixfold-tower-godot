extends "res://scripts/enemy.gd"
## THE STOKER (kind "stoker"; enemy.gd SUBKINDS spawns it with this script):
## the Wyvern's forge-hand with a coal shovel. From a few steps off it loads
## its shovel with glowing coal (red circles mark where the coal will land:
## one on you, one beside a fire already burning, or nearer you) and flings
## it: the floor there burns, and coal on a fire that's already alight makes
## it bigger and longer. The coal can't be parried: step out of the circles,
## or jump. Up close it swings the shovel (a wedge, a glint: parry it). It
## keeps at most RULES "most" fires of its own alight; slay it and they die
## down at once. Words and numbers: RULES, TEXT.


static var RULES := {
	"throw": 200.0,  # it flings coal from this near
	"throw_wind": 0.9,  # the coal's warning (the circles)
	"spots": 2.0,
	"spot_r": 32.0,  # each fire's radius
	"fire_t": 6.0,  # how long a fire burns
	"most": 5.0,  # its own fires alight at once, at most
	"every": 4.0,  # seconds between flings
	"swing": 54.0,
	"swing_arc": 60.0,
	"swing_wind": 0.6,
	"recover": 1.0,
	"die_down": 0.8,  # its fires last at most this long once it falls
}
static var TEXT := {"die": "Its fires die down"}

const C_SOOT := Color(0.24, 0.21, 0.2)
const C_APRON := Color(0.45, 0.32, 0.22)
const C_COAL := Color(0.16, 0.13, 0.12)

var throw_cd := 1.5
var spots: Array = []
var _flings := 0  # (tests)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "recover"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("stoker")
	throw_cd -= delta
	match state:
		"wind_throw":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				spots = _pick_spots(p)
			if _wind(delta):
				_fling(p)
				_end_attack("recover", float(RULES["recover"]))
		"wind_swing":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var reach := float(RULES["swing"])
				var arc := deg_to_rad(float(RULES["swing_arc"]))
				main.fx_cone(global_position, lunge_dir, reach + 8.0, arc, Color(1.0, 0.55, 0.3))
				main.sfx_at(global_position, "swing_blunt_heavy", 0.85)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= arc:
					p.receive_attack(dmg, self)
				_end_attack("recover", float(RULES["recover"]))
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < float(RULES["swing"]) + 6.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_swing", float(RULES["swing_wind"]))
				main.sfx_at(global_position, "warn_smith", 1.2, -3.0)
			elif throw_cd <= 0.0 and dist > 80.0 and dist < float(RULES["throw"]) and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				lunge_dir = dir
				spots = _pick_spots(p)
				_begin_wind("wind_throw", float(RULES["throw_wind"]))
				main.sfx_at(global_position, "burn", 0.6, -6.0)
			elif dist > float(RULES["throw"]) * 0.7:
				velocity = dir * speed
			else:
				_circle(dir, dist, float(RULES["throw"]) * 0.6, speed * 0.6)


## Where the coal lands: one on the climber, one beside a fire already
## burning near them (or between it and the climber).
func _pick_spots(p) -> Array:
	var at: Vector2 = p.global_position
	var out: Array = [at]
	if int(RULES["spots"]) < 2:
		return out
	var best := Vector2.INF
	var best_d := 160.0
	for f in main.flames:
		if f.get("friendly", false):
			continue
		var d: float = Vector2(f["pos"]).distance_to(at)
		if d < best_d and d > 24.0:
			best_d = d
			best = f["pos"]
	if best != Vector2.INF:
		out.append(best + (at - best).normalized() * float(RULES["spot_r"]))
	else:
		out.append(at + (global_position - at).normalized() * float(RULES["spot_r"]) * 1.8)
	return out


func _fling(p) -> void:
	_flings += 1
	throw_cd = float(RULES["every"])
	main.sfx_at(global_position, "throw", 0.8)
	main.sfx_at(global_position, "burn", 0.9, -2.0)
	var r := float(RULES["spot_r"])
	var mine: Array = main.flames.filter(func(f): return int(f.get("stoker", 0)) == get_instance_id() and float(f["t"]) > 0.0)
	for spot in spots:
		main.fx_burst(spot, Vector2.UP, Color(1.0, 0.55, 0.2), 10, 200.0)
		# Coal on a fire already alight feeds it; otherwise a new fire (if it may).
		var fed := false
		for f in main.flames:
			if not f.get("friendly", false) and Vector2(f["pos"]).distance_to(spot) < float(f["r"]):
				f["r"] = minf(float(f["r"]) + 8.0, 60.0)
				f["t"] = maxf(float(f["t"]), float(RULES["fire_t"]))
				f["max"] = maxf(float(f.get("max", 0.0)), float(f["t"]))
				fed = true
				break
		if not fed and mine.size() < int(RULES["most"]):
			main.add_flame(spot, r, float(RULES["fire_t"]))
			main.flames[-1]["stoker"] = get_instance_id()
			mine.append(main.flames[-1])
		if p.global_position.distance_to(spot) < r + p.radius and p.iframes <= 0.0 and not p.in_air():
			var before: float = p.hp
			p.receive_attack(dmg * 0.6, self, true)
			if p.hp < before:
				Reactions.apply(main, p, "burning", Reactions.climber_seconds("burning"), self)
	spots = []


## Slain: its fires die down.
func _exit_tree() -> void:
	if dead and main != null and is_instance_valid(main):
		var any := false
		for f in main.flames:
			if int(f.get("stoker", 0)) == get_instance_id():
				f["t"] = minf(float(f["t"]), float(RULES["die_down"]))
				any = true
		if any:
			main.fx_text(global_position + Vector2(0, -radius - 30.0), TEXT["die"], Color(1.0, 0.75, 0.5))
	super._exit_tree()


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A squat forge-hand seen from above: soot-black, a leather apron, a coal
## sack on its back with embers glowing through, and a long shovel, swung
## back and heaped with glowing coal before it flings.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var step := sin(_stride) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 6.0 + f * (step * sgn * 4.0 + 1.5), 3.8, C_SOOT.darkened(0.3))
	# The coal sack on its back.
	p.egg(-f * 8.0, Vector2(7.0, 6.0), f.angle(), Color(0.36, 0.3, 0.24))
	for i in 3:
		var at := -f * (7.0 + i * 1.5) + s * (float(i) - 1.0) * 3.0
		_glow.circle(at, 1.0 + 0.4 * sin(t * 5.0 + i), Color(1.0, 0.5, 0.2, 0.8), 6)
	# Body and apron.
	p.ball(Vector2.ZERO, radius * 0.88, C_SOOT)
	p.poly(PackedVector2Array([f * 2.0 + s * 7.0, f * radius * 0.95 + s * 5.0, f * radius * 0.95 - s * 5.0, f * 2.0 - s * 7.0]), C_APRON, 1.2)
	# The shovel: held low and ready; swung back (heaped with coal) to fling;
	# raised for the swing.
	var ang := 0.4
	var reach := 1.0
	var rate := 12.0
	var loaded := false
	if state == "wind_throw":
		var k := _wk(float(RULES["throw_wind"]))
		ang = 0.4 + 2.2 * k
		reach = 1.0 - 0.15 * k
		loaded = true
	elif state == "wind_swing":
		var k2 := _wk(float(RULES["swing_wind"]))
		ang = 0.4 - 1.6 * k2
	elif state == "recover" and open_t > 0.0:
		ang = -0.4
		rate = 24.0
	ang = _ease("shovel", ang, rate)
	var dir := f.rotated(ang)
	var grip := s * radius * 0.6 + f * 2.0
	var head: Vector2 = grip + dir * 20.0 * reach
	p.limb(grip, grip + dir * 4.0, C_SOOT.lightened(0.1), 3.4)
	p.limb(-s * radius * 0.6 + f * 3.0, grip + dir * 6.0, C_SOOT.lightened(0.1), 3.2)
	p.limb(grip - dir * 3.0, head, Palette.WOOD.darkened(0.2), 2.2)
	var hs := dir.orthogonal()
	p.poly(PackedVector2Array([head - hs * 4.5, head + dir * 7.0 - hs * 3.5, head + dir * 8.0 + hs * 3.5, head + hs * 4.5]), Palette.STEEL.darkened(0.25), 1.3)
	if loaded:
		for i in 4:
			var c: Vector2 = head + dir * (2.5 + (i % 2) * 3.0) + hs * (float(i) - 1.5) * 1.8
			p.circle(c, 1.7, C_COAL, 6)
			_glow.circle(c, 1.2, Color(1.0, 0.55, 0.2, 0.9), 6)
	# Head: a soot-smeared cap, eyes glowing like coals.
	p.ball(f * 3.0, 5.6, C_SOOT.lightened(0.05))
	p.arc(f * 3.0, 5.0, f.angle() + 1.5, f.angle() + TAU - 1.5, 2.0, C_APRON.darkened(0.2), 10)
	for sgn in [-1.0, 1.0]:
		_glow.circle(f * 6.4 + s * sgn * 2.0, 1.0, Color(1.0, 0.6, 0.25), 8)


func _overlay_extra(o) -> void:
	var danger := Palette.DANGER
	if state == "wind_throw":
		var k := _wk(float(RULES["throw_wind"]))
		for spot in spots:
			_target(o, Vector2(spot) - global_position, float(RULES["spot_r"]), k, 0.1)
	elif state == "wind_swing":
		var half := deg_to_rad(float(RULES["swing_arc"]))
		o.wedge(Vector2.ZERO, float(RULES["swing"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.1 + 0.15 * _wk(float(RULES["swing_wind"]))), 12)
