extends "res://scripts/enemy.gd"
## THE DROWNED (kind "drowned"; enemy.gd SUBKINDS spawns it with this
## script): the Kraken's tower's waterlogged corpse. It lies face down in a
## puddle (it settles in the nearest water when it's placed), under the
## surface where blows can't reach it, until you come near: then it rises,
## streaming water, and shambles after you, slowly. Up close it raises both
## arms (the wind-up), glints and brings them down in a wedge (parry it); a
## blow that lands leaves you soaked. When it falls it swells (a ring shows
## how far it will burst), then bursts, soaking everyone in the ring, you and
## monsters alike. Soaked, lightning jumps to you (Conduct): keep clear of
## sparks while you're wet. Words and numbers: RULES, TEXT.


static var RULES := {
	"wake": 130.0,  # it rises when you come this near
	"rise": 0.9,  # rising takes this long
	"slam": 56.0,
	"slam_arc": 55.0,
	"slam_wind": 0.85,
	"recover": 1.1,
	"swell": 0.8,  # it swells this long before it bursts (the warning)
	"burst": 80.0,  # how far its burst soaks
	"soak": 5.0,  # seconds you stay soaked
	"water": 240.0,  # it looks for water this near to lie in
}
static var TEXT := {"rises": "The drowned rises", "burst": "Soaked!"}

const Marks := preload("res://scripts/foes/marks.gd")
const C_FLESH := Color(0.5, 0.6, 0.56)
const C_RAGS := Color(0.3, 0.36, 0.38)
const C_PUDDLE := Color(0.3, 0.5, 0.6, 0.55)

var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "lying"
	submerged = true


func _ready() -> void:
	super._ready()
	if main != null and main.layout_on:
		_find_water.call_deferred()


## Settles in the nearest shallow water within RULES "water" (if there is any).
func _find_water() -> void:
	if not is_inside_tree() or main == null or main.in_water(global_position):
		return
	for d in [40.0, 80.0, 120.0, 160.0, 200.0, 240.0]:
		if d > float(RULES["water"]):
			break
		for k in 12:
			var q: Vector2 = global_position + Vector2.from_angle(k * TAU / 12.0) * d
			if main.in_water(q) and not main.is_solid(q) and not _deep(q) and main.clear_line(global_position, q):
				global_position = q
				return


## Deep water or a drop (it lies only in shallows you can wade to).
func _deep(q: Vector2) -> bool:
	var tf = main.get("tower_floor")
	if tf == null:
		return false
	return (tf.has_method("deep_at") and tf.deep_at(q)) or (tf.has_method("is_void") and tf.is_void(q))


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"lying":
			submerged = true
			velocity = Vector2.ZERO
			if dist < float(RULES["wake"]):
				_rise()
		"rise":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "shamble"
		"wind_slam":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var reach := float(RULES["slam"])
				var arc := deg_to_rad(float(RULES["slam_arc"]))
				main.fx_cone(global_position, lunge_dir, reach + 8.0, arc, Color(0.6, 0.85, 1.0))
				main.fx_burst(global_position + lunge_dir * reach * 0.7, Vector2.ZERO, C_WATER, 10, 180.0)
				main.sfx("slam", 1.15, -2.0)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= arc:
					p.receive_attack(dmg, self)
				_end_attack("recover", float(RULES["recover"]))
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "shamble"
		_:  # shamble
			if dist < float(RULES["slam"]) + 6.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_slam", float(RULES["slam_wind"]))
				main.sfx("warn_lurker", 0.6, -2.0)
			else:
				velocity = dir * speed


func _rise() -> void:
	state = "rise"
	state_t = float(RULES["rise"])
	submerged = false
	_foes_changed()
	if not _told:
		_told = true
		main.tip("drowned")
	main.fx_burst(global_position, Vector2.UP, C_WATER, 14, 200.0)
	main.fx_text(global_position + Vector2(0, -radius - 26.0), TEXT["rises"], C_WATER)
	main.sfx("geyser", 0.7, -6.0)


## Slain, it falls as any monster does (it counts as slain at once), but its
## bloated body stays a moment, swelling (a ring shows how far), then bursts
## (foes/marks.gd "burst": soaks you and the monsters in the ring).
func _exit_tree() -> void:
	if dead and main != null and is_instance_valid(main) and is_inside_tree():
		var r := RULES.duplicate()
		r["soaked_text"] = TEXT["burst"]
		var m = Marks.make(main, "burst", r, null)
		m.beads.append({"pos": global_position, "t": float(RULES["swell"]), "max": float(RULES["swell"])})
		main.sfx("bubble", 0.5, 0.0)
	super._exit_tree()


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A bloated, waterlogged body in rags, seen from above. Lying, only its back
## shows in a dark puddle with weed in its hair; rising, it lifts out of the
## water streaming; it swells, glistening, before it bursts.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var rise := 0.0
	match state:
		"lying":
			rise = 0.0
		"rise":
			rise = _wk(float(RULES["rise"]))
		_:
			rise = 1.0
	rise = _ease("rise", rise, 8.0)
	var swell := _ease("swell", _wk(float(RULES["swell"])) if state == "swell" else 0.0, 10.0)
	# The puddle it lies in (it fades once it's up and walking).
	var pud := clampf(1.3 - rise, 0.0, 1.0)
	if pud > 0.02:
		p.oval(Vector2(0, 3), Vector2(radius * 1.9, radius * 1.1), 0.0, Color(C_PUDDLE, C_PUDDLE.a * pud), 20)
		for k in 2:
			var ph := fmod(t * 0.6 + k * 0.5, 1.0)
			p.arc(Vector2(0, 3), radius * (0.8 + ph * 1.1), 0.0, TAU, 1.0, Color(0.75, 0.9, 1.0, 0.4 * (1.0 - ph) * pud), 20)
	if state == "lying":
		# Only a dark back and a tangle of weedy hair above the surface.
		p.oval(Vector2(0, 1), Vector2(radius * 0.9, radius * 0.55), f.angle(), Color(0.12, 0.2, 0.22, 0.75), 16)
		for i in 4:
			var a := f.angle() + (float(i) - 1.5) * 0.5
			p.quad(f * 5.0, f * 5.0 + Vector2.from_angle(a) * 7.0, 1.0, Color(0.2, 0.32, 0.22, 0.8))
		return
	var r := radius * (1.0 + 0.35 * swell)
	var bob := Vector2(0, (1.0 - rise) * 6.0)
	var step := sin(_stride * 0.8) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(bob + s * sgn * 5.0 + f * (step * sgn * 3.5 + 1.0), 3.5, C_FLESH.darkened(0.35))
	# Arms: hanging forward, raised high for the slam.
	var lift := _ease("arms", _wk(float(RULES["slam_wind"])) if state == "wind_slam" else 0.0, 12.0)
	for sgn in [-1.0, 1.0]:
		var sh: Vector2 = bob + s * sgn * r * 0.7
		var hand: Vector2 = sh + f * (8.0 - 4.0 * lift) + s * sgn * 2.0 + Vector2(0, -9.0 * lift)
		p.limb(sh, hand, C_FLESH.darkened(0.1), 3.4)
		p.ball(hand, 2.6, C_FLESH)
	# The bloated body in rags.
	p.ball(bob, r * 0.85, C_FLESH)
	p.poly(PackedVector2Array([bob - f * r * 0.8 + s * r * 0.7, bob + s * r * 0.85, bob + f * r * 0.2 + s * r * 0.5, bob + f * r * 0.1 - s * r * 0.6, bob - s * r * 0.85, bob - f * r * 0.85 - s * r * 0.5]), C_RAGS, 1.2)
	# Head lolling, weed in its hair, pale dead eyes.
	p.ball(bob + f * 4.0, 5.5 + swell, C_FLESH.lightened(0.05))
	for i in 3:
		var a := f.angle() + PI + (float(i) - 1.0) * 0.6
		p.quad(bob + f * 2.0, bob + f * 2.0 + Vector2.from_angle(a) * 7.0, 1.2, Color(0.24, 0.36, 0.24))
	for sgn in [-1.0, 1.0]:
		p.circle(bob + f * 7.0 + s * sgn * 2.0, 1.2, Color(0.85, 0.9, 0.82), 8)
	# Water streaming off it (and glistening as it swells).
	for i in 3:
		var ph := fmod(t * 1.2 + i * 0.33, 1.0)
		p.circle(bob + s * (float(i) - 1.0) * r * 0.6 + Vector2(0, ph * 8.0), 1.3 * (1.0 - ph), Color(C_WATER, 0.7 * (1.0 - ph)), 6)
	if swell > 0.0:
		_glow.circle(bob, r, Color(0.6, 0.85, 1.0, 0.18 * swell), 18)


func _overlay_extra(o) -> void:
	var danger := Palette.DANGER
	if state == "wind_slam":
		var half := deg_to_rad(float(RULES["slam_arc"]))
		var k := _wk(float(RULES["slam_wind"]))
		o.wedge(Vector2.ZERO, float(RULES["slam"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.1 + 0.15 * k), 12)
		o.arc(Vector2.ZERO, float(RULES["slam"]) * k, lunge_dir.angle() - half, lunge_dir.angle() + half, 2.0, Color(danger, 0.7), 14)
	elif state == "swell":
		var k := _wk(float(RULES["swell"]))
		var r := float(RULES["burst"])
		o.circle(Vector2.ZERO, r, Color(0.36, 0.66, 0.96, 0.1 + 0.12 * k), 40)
		o.arc(Vector2.ZERO, r, 0.0, TAU, 2.0, Color(0.6, 0.85, 1.0, 0.8), 40)
		o.arc(Vector2.ZERO, r * (1.0 - k) + 6.0, 0.0, TAU, 1.5, Color(danger, 0.7), 32)
