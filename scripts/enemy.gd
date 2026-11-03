extends CharacterBody2D
## Prototype monsters: slime, archer and knight.
##
## Every melee attack follows the same rhythm, so it can be learned:
##   wind-up  -> GLINT (a white flash and a "ting") -> the hit lands GLINT_LEAD
##   seconds later -> recovery, where the monster is open to punishment.
## Parry on the glint. Only a couple of monsters may attack at once (they
## take turns via the room's attack tokens); the rest circle and wait.
## Slimes and archers flinch when hit; knights don't while winding up.

## The sound a hit makes on this monster's body, layered over the weapon's.
const MATERIAL := {"slime": "hit_slime", "knight": "hit_armor", "archer": "", "bat": "", "thunderling": "", "gryphon": "hit_armor", "lurker": "hit_slime", "shellback": "hit_armor", "kraken": "hit_slime"}

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

const GLINT_LEAD := 0.25  # seconds from the glint to the hit
const FLINCH_TIME := 0.3
const POUNCE_SPEED := 420.0
const LUNGE_SPEED := 760.0

const TYPES := {
	"slime": {"hp": 24.0, "speed": 60.0, "radius": 13.0, "color": Color(0.5, 0.88, 0.4), "dmg": 8.0, "weight": 0.7},
	"archer": {"hp": 18.0, "speed": 75.0, "radius": 11.0, "color": Color(0.62, 0.5, 0.3), "dmg": 8.0, "weight": 0.8},
	"knight": {"hp": 48.0, "speed": 60.0, "radius": 15.0, "color": Color(0.66, 0.7, 0.8), "dmg": 14.0, "weight": 3.0},
	# The Gryphon's tower
	"bat": {"hp": 10.0, "speed": 120.0, "radius": 9.0, "color": Color(0.6, 0.48, 0.82), "dmg": 6.0, "weight": 0.4},
	"thunderling": {"hp": 26.0, "speed": 70.0, "radius": 11.0, "color": Color(0.95, 0.89, 0.42), "dmg": 12.0, "weight": 1.0},
	"gryphon": {"hp": 380.0, "speed": 78.0, "radius": 26.0, "color": Color(0.88, 0.74, 0.45), "dmg": 18.0, "weight": 30.0, "boss": true},
	# The Kraken's tower
	"lurker": {"hp": 30.0, "speed": 95.0, "radius": 12.0, "color": Color(0.31, 0.56, 0.66), "dmg": 11.0, "weight": 1.0},
	"shellback": {"hp": 40.0, "speed": 40.0, "radius": 16.0, "color": Color(0.5, 0.6, 0.66), "dmg": 12.0, "weight": 4.0},
	"kraken": {"hp": 450.0, "speed": 35.0, "radius": 34.0, "color": Color(0.6, 0.3, 0.42), "dmg": 18.0, "weight": 40.0, "boss": true},
}
const BOSSES := ["gryphon", "kraken"]
## What each beast calls when it's half dead.
const FLOCK := {"gryphon": "bat", "kraken": "lurker"}
const SWEEP_REACH := 230.0
const SWEEP_ARC := 60.0
const SLAM_RADIUS := 55.0
const SWOOP_SPEED := 430.0
const SPARK_RADIUS := 95.0
const RAKE_REACH := 85.0
const RAKE_ARC := 70.0
const DIVE_RADIUS := 78.0

var kind := "slime"
var main
var hp := 1.0
var max_hp := 1.0
var radius := 12.0
var color := Color.WHITE
var speed := 60.0
var dmg := 8.0
var weight := 1.0  # how hard it is to shove when bodies collide
var dead := false

var state := "idle"
var state_t := 0.0
var airborne := 0.0
var stun := 0.0
var charged := 0.0
var flash := 0.0
var contact_cd := 0.0
var aim_dir := Vector2.ZERO
var lunge_dir := Vector2.RIGHT
var lunge_hit := false
var knock := Vector2.ZERO
var squash := 0.0
var squash_dir := Vector2.RIGHT
var submerged := false  # a lurker under the surface: can't be struck or targeted
var tide_t := 0.0  # just shoved by a Tidecaller: a wall stuns it (Undercurrent)
var challenged_t := 0.0  # Warden's Challenge: comes at you and takes more damage
var overcharge_t := 0.0  # Stormcaller's Overcharge: lightning bursts from it when it dies
var overcharge_dmg := 0.0
var overcharge_r := 0.0
var flinch := 0.0  # knocked off balance by a hit (not open to ripostes)
var glint := 0.0  # the white flash before a hit, for drawing
var glinted := false
var attack_from := Vector2.ZERO  # where a pounce or lunge started
var face := Vector2.LEFT  # where it's looking, eased toward the climber
var overlay: Node2D  # unlit layer: telegraphs and the health bar


## Call before adding to the tree.
func setup(k: String, room) -> void:
	kind = k
	main = room
	var t: Dictionary = TYPES[k]
	hp = t["hp"]
	max_hp = hp
	radius = t["radius"]
	color = t["color"]
	speed = t["speed"]
	dmg = t["dmg"]
	weight = t["weight"]
	# Monsters take a moment to notice you, and not all at once.
	state_t = randf_range(1.2, 2.4)
	if kind in ["knight", "thunderling", "gryphon", "shellback", "kraken"]:
		state = "recover"  # stands still until state_t runs out, then gives chase
	if kind == "bat":
		state = "rest"
	if kind == "gryphon" or kind == "kraken":
		state_t = 1.6
	if kind == "lurker":
		state = "sub"
		submerged = true


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	overlay = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	overlay.material = unlit
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


func _physics_process(delta: float) -> void:
	flash -= delta
	charged -= delta
	overcharge_t -= delta
	tide_t -= delta
	challenged_t -= delta
	glint -= delta
	squash = move_toward(squash, 0.0, 6.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var p = main.player
	if airborne > 0.0:
		airborne -= delta
		_drift()
		return
	if stun > 0.0:
		stun -= delta
		_drift()
		return
	if flinch > 0.0:
		flinch -= delta
		_drift()
		return
	if p == null or p.dead:
		_end_attack("idle", 1.0)
		_drift()
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	# Look at the climber, except once an attack is committed (after the glint).
	if not (is_attacking() and glinted):
		face = face.slerp(dir, minf(1.0, 8.0 * delta)).normalized()
	match kind:
		"slime":
			_slime(delta, dir, dist, p)
		"archer":
			_archer(delta, dir, dist)
		"knight":
			_knight(delta, dir, dist, p)
		"bat":
			_bat(delta, dir, dist, p)
		"thunderling":
			_thunderling(delta, dir, dist, p)
		"gryphon":
			_gryphon(delta, dir, dist, p)
		"lurker":
			_lurker(delta, dir, dist, p)
		"shellback":
			_shellback(delta, dir, dist, p)
		"kraken":
			_kraken(delta, dir, dist, p)
	# Water slows walking monsters too (not fliers or the ones that live in it),
	# but never an attack already on its way: the glint promised its timing.
	# A Deepcaller's Pressure slows the badly hurt.
	if not state in ["lunge", "pounce", "swoop", "dive"]:
		velocity *= main.water_slow(global_position, kind in ["lurker", "kraken", "bat", "gryphon"])
	if hp < max_hp * 0.5 and p.has_bond("deepcaller") and dist < 150.0:
		velocity *= 0.6
	velocity += knock
	move_and_slide()
	_undercurrent()
	queue_redraw()


## A Tidecaller's shove: if it drives the foe into a wall, it's stunned.
func tide_push(v: Vector2) -> void:
	knock = v
	tide_t = 0.45


func _undercurrent() -> void:
	if tide_t > 0.0 and get_slide_collision_count() > 0 and main.player.has_bond("tidecaller"):
		tide_t = 0.0
		stagger(1.2)
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "Dashed against the wall", Color(0.37, 0.72, 0.79))
		main.sfx("hit_heavy", 0.9, -4.0)


func _drift() -> void:
	velocity = knock
	move_and_slide()
	_undercurrent()
	queue_redraw()


## True while winding up or striking: the climber's parry looks for these.
func is_attacking() -> bool:
	return state.begins_with("wind") or state in ["pounce", "lunge", "aim", "swoop", "dive"]


## Counts down a wind-up and flashes the glint GLINT_LEAD seconds before the
## blow lands. `travel` is how long a pounce or lunge will take to reach the
## climber after the wind-up, so the glint comes earlier to make up for it.
func _wind(delta: float, travel := 0.0) -> bool:
	state_t -= delta
	# Glint GLINT_LEAD before the blow lands, counting the time the attack
	# takes to travel to you (a far swoop glints earlier in its wind-up).
	if not glinted and (state_t + travel <= GLINT_LEAD or state_t <= 0.0):
		glinted = true
		glint = 0.22
		main.sfx("glint", 1.0, 0.0, 0.03)
	return state_t <= 0.0


func _begin_wind(new_state: String, duration: float) -> void:
	state = new_state
	state_t = duration
	glinted = false


func _end_attack(next_state: String, duration: float) -> void:
	state = next_state
	state_t = duration
	glinted = false
	main.release_attack(self)


## Moves around the climber at a distance while waiting for a turn to attack.
func _circle(dir: Vector2, dist: float, keep: float, spd: float) -> void:
	var side := dir.orthogonal() * (1.0 if get_instance_id() % 2 == 0 else -1.0)
	var radial := 0.0
	if dist > keep + 20.0:
		radial = 1.0
	elif dist < keep - 20.0:
		radial = -1.0
	velocity = (dir * radial + side * 0.6).normalized() * spd


# Creeps up, squats (the wind-up), then pounces at where you were.
func _slime(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind":
			velocity = Vector2.ZERO
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 6.0)) / POUNCE_SPEED):
				state = "pounce"
				state_t = 0.3
				attack_from = global_position
				aim_dir = dir
				lunge_hit = false
				main.sfx("slime_hop", randf_range(0.9, 1.15))
		"pounce":
			state_t -= delta
			velocity = aim_dir * POUNCE_SPEED
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("rest", 1.1)  # landed: open for a moment
		"rest", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "approach"
		_:  # approach: creep closer; pounce when close and it's our turn
			if dist < 110.0 and main.request_attack(self):
				_begin_wind("wind", 0.6)
			elif dist < 110.0:
				_circle(dir, dist, 95.0, speed * 0.6)
			else:
				velocity = dir * speed * 0.7


# Keeps its distance, draws (aim locks; a red line), then fires.
func _archer(delta: float, dir: Vector2, dist: float) -> void:
	if state == "aim":
		velocity = Vector2.ZERO
		state_t -= delta
		if state_t <= 0.0:
			main.spawn_projectile(global_position + aim_dir * radius, aim_dir * 260.0, dmg)
			aim_dir = Vector2.ZERO
			_end_attack("reload", randf_range(2.0, 2.8))
		return
	state_t -= delta
	if dist < 170.0:
		velocity = -dir * speed
	elif dist > 260.0:
		velocity = dir * speed
	else:
		velocity = dir.orthogonal() * speed * (1.0 if sin(Time.get_ticks_msec() * 0.0008) > 0.0 else -1.0)
	if state_t <= 0.0 and dist < 430.0 and main.request_attack(self):
		state = "aim"
		state_t = 0.5
		aim_dir = dir
		main.sfx("warn_archer")  # the bow creaks as it draws


# Two moves: a slash up close, or a lunge from further out. Each winds up,
# glints, strikes, then leaves the knight open.
func _knight(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_slash":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				_slash(p)
				_end_attack("recover", 0.9)
		"wind_lunge":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = lunge_dir.slerp(dir, minf(1.0, 5.0 * delta))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 10.0)) / LUNGE_SPEED):
				state = "lunge"
				state_t = 0.18
				lunge_hit = false
				attack_from = global_position
		"lunge":
			state_t -= delta
			velocity = lunge_dir * LUNGE_SPEED
			if not lunge_hit and dist < radius + p.radius + 10.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:  # chase
			if dist < 75.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_slash", 0.6)
				main.sfx("warn_knight")  # armour rattles as it winds up
			elif dist > 120.0 and dist < 200.0 and randf() < delta * 0.8 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_lunge", 0.7)
				main.sfx("warn_knight")
			elif main.holds_attack(self) or main.can_attack():
				velocity = dir * speed
			else:
				_circle(dir, dist, 130.0, speed * 0.7)


const SLASH_REACH := 64.0
const SLASH_ARC := 65.0  # half-angle, degrees


func _slash(p) -> void:
	var to: Vector2 = p.global_position - global_position
	main.fx_cone(global_position, lunge_dir, SLASH_REACH + 10.0, deg_to_rad(SLASH_ARC), Color(1.0, 0.4, 0.3))
	main.sfx("swing_heavy", 0.8)
	if to.length() <= SLASH_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(SLASH_ARC):
		p.receive_attack(dmg, self)


# --- the Gryphon's tower --------------------------------------------------------

# Bats circle you, then swoop straight through where you stood.
func _bat(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind":
			velocity = Vector2.ZERO  # hangs in the air, then swoops
			if not glinted:
				aim_dir = dir
			# A swoop from far away flies faster, so it always lands within
			# the parry window of its glint.
			swoop_speed = maxf(SWOOP_SPEED, maxf(0.0, dist - (radius + p.radius)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius)) / swoop_speed):
				state = "swoop"
				state_t = 0.4
				lunge_hit = false
		"swoop":
			state_t -= delta
			velocity = aim_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("rest", 1.0)
		"rest":
			state_t -= delta
			_circle(dir, dist, 130.0, speed * 0.8)
			if state_t <= 0.0:
				state = "hover"
		_:  # hover: circle, swoop when it's our turn
			if dist < 170.0 and main.request_attack(self):
				_begin_wind("wind", 0.45)
				aim_dir = dir
			else:
				_circle(dir, dist, 110.0, speed)


# Thunderlings walk up, stop and spark, then burst into a ring of lightning.
# The ring can't be parried: step out of it or roll through.
func _thunderling(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_spark":
			velocity = Vector2.ZERO
			if _wind(delta):
				main.fx_ring(global_position, color, SPARK_RADIUS, 0.3, 4.0)
				var pts: Array = []
				for i in 6:
					var a := TAU * i / 6.0 + randf()
					main.fx_bolt([global_position, global_position + Vector2.from_angle(a) * SPARK_RADIUS], color)
				main.sfx("zap", 0.9)
				main.light_flash(global_position, color, 1.4, 1.6, 0.3)
				if dist < SPARK_RADIUS + p.radius:
					p.receive_attack(dmg, self, true)
				_end_attack("recover", 1.1)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 75.0 and main.request_attack(self):
				_begin_wind("wind_spark", 0.9)
				main.sfx("charge", 1.3, -4.0)
			elif main.holds_attack(self) or main.can_attack():
				velocity = dir * speed
			else:
				_circle(dir, dist, 120.0, speed * 0.7)


var dive_from := Vector2.ZERO
var dive_to := Vector2.ZERO
var called_flock := false


# The Gryphon: rakes with its talons up close, dives on you from range, and
# throws a fan of feathers. Every attack glints. Halfway down, it calls bats.
func _gryphon(delta: float, dir: Vector2, dist: float, p) -> void:
	_call_flock()
	match state:
		"wind_rake":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, RAKE_REACH + 10.0, deg_to_rad(RAKE_ARC), Color(1.0, 0.45, 0.3))
				main.sfx("swing_heavy", 0.7)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= RAKE_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(RAKE_ARC):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.8)
		"wind_dive":
			velocity = Vector2.ZERO
			if not glinted:
				dive_to = p.global_position  # it locks on when it glints
			if _wind(delta, 0.28):
				state = "dive"
				state_t = 0.28
				dive_from = global_position
		"dive":
			state_t -= delta
			var k := clampf(1.0 - state_t / 0.28, 0.0, 1.0)
			global_position = dive_from.lerp(dive_to, k)
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				main.fx_ring(global_position, Color(1.0, 0.85, 0.6), DIVE_RADIUS, 0.4, 6.0)
				main.fx_burst(global_position, Vector2.ZERO, Color(0.85, 0.8, 0.7), 18, 280.0)
				main.sfx("hit_heavy", 0.6)
				main.shake(9.0)
				if global_position.distance_to(p.global_position) < DIVE_RADIUS + p.radius:
					p.receive_attack(dmg * 1.2, self, true)  # a landing can't be parried: roll
				_end_attack("recover", 1.3)  # a long opening after landing
		"wind_gale":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				for i in 5:
					var a := (float(i) - 2.0) * deg_to_rad(14.0)
					var v := lunge_dir.rotated(a) * 300.0
					var f = main.spawn_projectile(global_position + lunge_dir * radius, v, dmg * 0.5)
					f.style = "feather"
					f.tint = color
				main.sfx("gust", 0.8)
				_end_attack("recover", 0.7)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:  # chase, choosing an attack
			if not main.request_attack(self):
				velocity = dir * speed
			elif dist < 95.0:
				_begin_wind("wind_rake", 0.55)
				main.sfx("warn_knight", 0.7)
			elif dist > 140.0 and randf() < delta * 0.9:
				_begin_wind("wind_dive", 0.75)
				main.sfx("warn_archer", 0.6)
			elif randf() < delta * 0.6:
				_begin_wind("wind_gale", 0.6)
				main.sfx("warn_archer", 0.9)
			else:
				velocity = dir * speed
				main.release_attack(self)


## Halfway down, a beast calls for help.
func _call_flock() -> void:
	if called_flock or hp >= max_hp * 0.5:
		return
	called_flock = true
	main.fx_text(global_position + Vector2(0, -radius - 30.0), "%s calls for help" % main.beast_name().capitalize(), color)
	main.sfx("warn_knight", 0.6)
	for i in 2:
		main.spawn_enemy(FLOCK.get(kind, "slime"), global_position + Vector2.from_angle(randf() * TAU) * (radius + 40.0))


# --- the Kraken's tower ------------------------------------------------------------

# Lurkers swim under the surface (only ripples show), rise near you, lunge,
# then stay up a moment before sinking. Strike while it is up.
func _lurker(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"sub":
			submerged = true
			if dist > 70.0:
				velocity = dir * speed
			else:
				velocity = Vector2.ZERO
				if main.request_attack(self):
					state = "rise"
					state_t = 0.35
		"rise":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				_begin_wind("wind", 0.45)
				lunge_dir = dir
		"wind":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 8.0)) / 520.0):
				state = "lunge"
				state_t = 0.18
				lunge_hit = false
		"lunge":
			state_t -= delta
			velocity = lunge_dir * 520.0
			if not lunge_hit and dist < radius + p.radius + 8.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("up", 1.6)  # stays up: your chance
		"up", "recover":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "sink"
				state_t = 0.35
		"sink":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "sub"
				state_t = 0.8
		_:
			state = "sub"


# Shellbacks plod toward you, turning slowly; the shell blocks from the front.
# A slow shell-bash up close.
func _shellback(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_bash":
			velocity = Vector2.ZERO
			if _wind(delta):
				main.fx_cone(global_position, face, 70.0, deg_to_rad(55.0), Color(1.0, 0.45, 0.3))
				main.sfx("hit_heavy", 0.6)
				var to: Vector2 = p.global_position - global_position
				if to.length() < 66.0 + p.radius and absf(face.angle_to(to)) < deg_to_rad(55.0):
					p.receive_attack(dmg, self)
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 60.0 and main.request_attack(self):
				_begin_wind("wind_bash", 0.7)
				main.sfx("warn_knight", 0.9)
			else:
				velocity = dir * speed


var slam_spots: Array = []
var swoop_speed := SWOOP_SPEED


# The Kraken: sweeps a tentacle across a wide arc (parryable), slams three
# spots, one where you stand (unparryable: roll), and spits ink (parryable).
func _kraken(delta: float, dir: Vector2, dist: float, p) -> void:
	_call_flock()
	match state:
		"wind_sweep":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, SWEEP_REACH, deg_to_rad(SWEEP_ARC), Color(0.9, 0.4, 0.5))
				main.sfx("swing_heavy", 0.5)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= SWEEP_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(SWEEP_ARC):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.9)
		"wind_slam":
			velocity = Vector2.ZERO
			if not glinted:
				slam_spots[0] = p.global_position  # the first spot follows you until the glint
			if _wind(delta):
				for spot in slam_spots:
					main.fx_ring(spot, color, SLAM_RADIUS, 0.4, 5.0)
					main.fx_burst(spot, Vector2.ZERO, Color(0.5, 0.75, 0.85), 10, 200.0)
					if p.global_position.distance_to(spot) < SLAM_RADIUS + p.radius:
						p.receive_attack(dmg * 1.1, self, true)
				main.sfx("hit_heavy", 0.5)
				main.shake(8.0)
				_end_attack("recover", 1.2)
		"wind_ink":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				for i in 3:
					var a := (float(i) - 1.0) * deg_to_rad(16.0)
					var ink = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated(a) * 240.0, dmg * 0.6)
					ink.style = "ink"
					ink.tint = Color(0.12, 0.08, 0.16)
				main.sfx("hit_slime", 0.5)
				_end_attack("recover", 0.7)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if not main.request_attack(self):
				velocity = dir * speed if dist > 180.0 else Vector2.ZERO
			elif dist < SWEEP_REACH - 30.0 and randf() < 0.5:
				_begin_wind("wind_sweep", 0.7)
				main.sfx("warn_knight", 0.5)
			elif randf() < 0.5:
				slam_spots = [p.global_position]
				for i in 2:
					slam_spots.append(p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 130.0))
				_begin_wind("wind_slam", 0.9)
				main.sfx("warn_archer", 0.5)
			else:
				_begin_wind("wind_ink", 0.55)
				main.sfx("warn_archer", 0.8)


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false) -> void:
	if dead:
		return
	if submerged:
		main.fx_text(global_position + Vector2(0, -radius - 10.0), "under the water", Color(0.5, 0.75, 0.85))
		return
	# A shellback's shell turns blows from the front (heavy blows crack it).
	if kind == "shellback" and dir != Vector2.ZERO and face.dot(-dir) > 0.4:
		amount *= 0.6 if heavy else 0.15
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "Blocked" if not heavy else "Cracked", Color(0.8, 0.84, 0.9))
		main.sfx("hit_armor", 1.2, -2.0)
	if challenged_t > 0.0:
		amount *= 1.5  # Challenged foes take more damage
	hp -= amount
	flash = 0.12
	squash = 1.0
	if dir != Vector2.ZERO:
		squash_dir = dir
		# The knight is heavy and the beast is heavier: they barely budge.
		knock = dir * force * (0.4 if kind == "knight" else (0.12 if is_boss() else 1.0))
	main.fx_text(global_position + Vector2(0, -radius - 10.0), str(int(round(amount))), Color(1.0, 0.95, 0.85))
	if hp <= 0.0:
		dead = true
		main.release_attack(self)
		main.on_enemy_killed(self)
		queue_free()
		return
	# Flinching: slimes and archers are knocked out of what they were doing.
	# Knights shrug off hits while winding up; only heavy blows rock them
	# when they aren't attacking.
	var poise := (kind == "knight" and (is_attacking() or not heavy)) or is_boss()
	if not poise and dir != Vector2.ZERO and stun <= 0.0:
		flinch = FLINCH_TIME
		if is_attacking():
			aim_dir = Vector2.ZERO
			_end_attack(_idle_state(), 0.6)


## Windwalker's Gale Lift: helpless in the air.
func lift(duration: float) -> void:
	if is_boss():
		stagger(0.4)  # too heavy to lift: only staggered
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "Staggered", Color(0.75, 0.9, 1.0))
		return
	airborne = maxf(airborne, duration)
	aim_dir = Vector2.ZERO
	if is_attacking():
		_end_attack(_idle_state(), 0.3)
	main.fx_text(global_position + Vector2(0, -radius - 22.0), "Lifted", Color(0.75, 0.9, 1.0))


func is_boss() -> bool:
	return kind in BOSSES


## Where each kind goes when an attack ends or is interrupted.
func _idle_state() -> String:
	match kind:
		"slime", "bat":
			return "rest"
		"archer":
			return "reload"
	return "recover"


func stagger(duration: float) -> void:
	stun = maxf(stun, duration)


## Parried: staggered and open to a riposte. A perfect parry staggers longer.
func on_parried(perfect := false) -> void:
	stun = 1.6 if perfect else 0.9
	aim_dir = Vector2.ZERO
	_end_attack(_idle_state(), 0.0)
	knock = (global_position - main.player.global_position).normalized() * (220.0 if perfect else 140.0)
	main.fx_text(global_position + Vector2(0, -radius - 22.0), "Staggered", Color(1.0, 0.89, 0.63))


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 100)
	var lift_y := -18.0 if airborne > 0.0 else 0.0
	if kind == "slime" and state == "pounce":
		lift_y -= sin(PI * clampf(1.0 - state_t / 0.3, 0.0, 1.0)) * 10.0
	Draw.shadow(self, Vector2(0, radius * 0.7), radius * (0.8 if lift_y < -1.0 else 1.0))

	# Squashed along the direction it was hit from.
	draw_set_transform(Vector2(0, lift_y), squash_dir.angle(), Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.25))
	var f := face.rotated(-squash_dir.angle())  # facing, in the squashed frame
	match kind:
		"slime":
			_draw_slime(t, f)
		"archer":
			_draw_archer(f)
		"knight":
			_draw_knight(f)
		"bat":
			_draw_bat(t, f)
		"thunderling":
			_draw_thunderling(t)
		"gryphon":
			_draw_gryphon(t, f)
		"lurker":
			_draw_lurker(t, f)
		"shellback":
			_draw_shellback(f)
		"kraken":
			_draw_kraken(t, f)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1, 1, 1, 0.75 * flash / 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if overlay != null:
		overlay.queue_redraw()


func _draw_slime(t: float, f: Vector2) -> void:
	var col := Palette.SLIME
	# Before a hop it gathers itself: squat and wide, quivering.
	var sq := Vector2.ONE
	var wob := 0.05
	if state == "wind":
		var k := clampf(1.0 - state_t / 0.6, 0.0, 1.0)
		sq = Vector2(1.0 + 0.22 * k, 1.0 - 0.2 * k)
		wob = 0.05 + 0.06 * k
	elif state == "pounce":
		sq = Vector2(0.88, 1.12)
	var pts := Draw.blob(Vector2.ZERO, radius, t, wob, sq)
	Draw.poly(self, pts, Color(col.darkened(0.25), 0.95))
	draw_colored_polygon(Draw.blob(Vector2(-1.5, -2.0), radius * 0.8, t, wob, sq), Color(col, 0.9))
	draw_circle(Vector2(-radius * 0.35, -radius * 0.42), radius * 0.22, Color(1, 1, 1, 0.45))
	draw_circle(Vector2(radius * 0.25, radius * 0.3), radius * 0.12, Color(col.lightened(0.3), 0.5))
	# Eyes that follow you.
	var side := f.orthogonal()
	for s in [-1.0, 1.0]:
		var e: Vector2 = f * radius * 0.35 + side * s * radius * 0.32 + Vector2(0, -2)
		draw_circle(e, 2.6, Color(0.97, 0.97, 0.92))
		draw_circle(e + f * 1.1, 1.3, Palette.OUTLINE)


func _draw_archer(f: Vector2) -> void:
	var cloak := Palette.ARCHER
	var side := f.orthogonal()
	# Quiver on the back, then the cloaked body, hood and bow.
	Draw.stroke(self, -f * 6.0 + side * 4.0, -f * 14.0 + side * 8.0, Palette.WOOD.darkened(0.35), 4.0)
	for i in 3:
		draw_line(-f * 13.0 + side * (6.5 + i * 1.5), -f * 17.0 + side * (8.0 + i * 1.5), Color(0.85, 0.82, 0.75), 1.2)
	Draw.ball(self, -f * 1.5, radius, cloak)
	Draw.ball(self, f * 2.0, 6.5, cloak.darkened(0.3))
	draw_circle(f * 5.0, 2.8, Color(0.08, 0.07, 0.07))  # the dark of the hood
	draw_circle(f * 5.6 + side * 1.2, 0.8, Color(1.0, 0.75, 0.4))
	draw_circle(f * 5.6 - side * 1.2, 0.8, Color(1.0, 0.75, 0.4))
	var grip := f * (radius + 3.0) - side * 3.0
	var drawn := aim_dir != Vector2.ZERO
	var pull := 8.0 if drawn else 2.0
	var a := grip - f * 4.0 + side * 11.0
	var b := grip - f * 4.0 - side * 11.0
	var limb := PackedVector2Array([a, grip + side * 5.0, grip, grip - side * 5.0, b])
	draw_polyline(limb, Palette.OUTLINE, 5.0, true)
	draw_polyline(limb, Palette.WOOD, 2.6, true)
	draw_polyline(PackedVector2Array([a, grip - f * pull, b]), Color(0.9, 0.88, 0.8), 1.0, true)
	if drawn:
		Draw.stroke(self, grip - f * pull, grip + f * 8.0, Palette.WOOD.lightened(0.2), 1.4)


func _draw_knight(f: Vector2) -> void:
	var armor := Palette.KNIGHT
	var side := f.orthogonal()
	# Plume trailing behind the helmet.
	Draw.stroke(self, -f * 2.0, -f * 13.0 + side * 2.0, Palette.PLUME, 3.5)
	# Sword: held low, raised high during the wind-up.
	var sword_dir := f.rotated(-1.1)
	var grip := -side * (radius * 0.9) + f * 3.0
	if state.begins_with("wind"):
		sword_dir = f.rotated(-2.4)
		grip = -side * (radius * 0.6) - f * 4.0
	elif state == "lunge":
		sword_dir = f.rotated(-0.25)
		grip = -side * (radius * 0.5) + f * 8.0
	Draw.sword(self, grip, sword_dir, 22.0)
	# Body: armoured plates.
	Draw.ball(self, Vector2.ZERO, radius, armor)
	draw_arc(Vector2.ZERO, radius * 0.62, f.angle() + 0.9, f.angle() + TAU - 0.9, 16, armor.darkened(0.3), 1.5)
	Draw.ball(self, side * radius * 0.78, 5.5, armor.lightened(0.08))
	Draw.ball(self, -side * radius * 0.78, 5.5, armor.lightened(0.08))
	# Helmet with a visor slit facing you.
	Draw.ball(self, f * 2.0, 7.5, armor.darkened(0.1))
	draw_line(f * 6.0 + side * 3.5, f * 6.0 - side * 3.5, Palette.OUTLINE, 2.0)
	if state.begins_with("wind"):
		draw_line(f * 6.0 + side * 2.5, f * 6.0 - side * 2.5, Color(1.0, 0.4, 0.3), 1.0)
	# Shield on the off hand.
	var sc := side * (radius * 0.85) + f * 6.0
	var shield := PackedVector2Array()
	for i in 9:
		var a := f.angle() - 1.0 + 2.0 * float(i) / 8.0
		shield.append(sc + Vector2.from_angle(a) * 7.0 - f * 3.0)
	for i in 9:
		var a := f.angle() + 1.0 - 2.0 * float(i) / 8.0
		shield.append(sc + Vector2.from_angle(a) * 3.0 - f * 3.0)
	Draw.poly(self, shield, Color(0.45, 0.3, 0.22))
	draw_circle(sc + f * 1.5, 1.6, Palette.STEEL)


func _draw_bat(t: float, f: Vector2) -> void:
	var flap := sin(t * 22.0) * 5.0
	var bob := Vector2(0, sin(t * 6.0) * 2.0 - 10.0)  # flies above the floor
	for s in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			bob + Vector2(s * 3.0, -1.0),
			bob + Vector2(s * 12.0, -8.0 + flap),
			bob + Vector2(s * 18.0, -2.0 + flap),
			bob + Vector2(s * 13.0, 2.0 + flap * 0.5),
			bob + Vector2(s * 9.0, 0.0 + flap * 0.6),
			bob + Vector2(s * 5.0, 4.0),
		])
		Draw.poly(self, wing, color.darkened(0.25))
	Draw.ball(self, bob, 6.0, color)
	draw_circle(bob + f * 2.5 + f.orthogonal() * 2.0, 1.2, Color(1.0, 0.35, 0.3))
	draw_circle(bob + f * 2.5 - f.orthogonal() * 2.0, 1.2, Color(1.0, 0.35, 0.3))


func _draw_thunderling(t: float) -> void:
	var sparking := state == "wind_spark"
	var r := radius * (1.15 if sparking else 1.0)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + t * (6.0 if sparking else 2.0)
		pts.append(Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.55))
	Draw.poly(self, pts, color.lightened(0.25) if sparking else color)
	draw_circle(Vector2.ZERO, r * 0.35, Color(1, 1, 1, 0.9 if sparking else 0.5))
	if sparking and fmod(t, 0.15) < 0.08:
		var a2 := randf() * TAU
		draw_line(Vector2.from_angle(a2) * r, Vector2.from_angle(a2) * (r + 8.0), Color(1, 1, 0.8), 1.5)


func _draw_gryphon(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	var lift_y := 0.0
	if state == "wind_dive":
		lift_y = -40.0 * clampf(1.0 - state_t / 0.75, 0.0, 1.0)
	elif state == "dive":
		lift_y = -40.0 * clampf(state_t / 0.28, 0.0, 1.0)
	var o := Vector2(0, lift_y)
	var flap := sin(t * (9.0 if state.begins_with("wind") else 3.5)) * 6.0
	# Tail, then wings, then body and head.
	Draw.stroke(self, o - f * radius * 0.8, o - f * radius * 1.7 + side * 6.0, color.darkened(0.2), 4.0)
	draw_circle(o - f * radius * 1.75 + side * 6.0, 4.0, color.darkened(0.45))
	for s in [-1.0, 1.0]:
		var base: Vector2 = o + side * s * radius * 0.5
		var wing := PackedVector2Array([
			base,
			base + side * s * radius * 1.2 + f * (10.0 + flap),
			base + side * s * radius * 1.9 - f * (4.0 - flap),
			base + side * s * radius * 1.3 - f * radius * 0.7,
			base - f * radius * 0.6,
		])
		Draw.poly(self, wing, Color(0.75, 0.62, 0.42))
		for k in 3:
			var feather: Vector2 = base + side * s * radius * (1.0 + 0.3 * k) - f * (2.0 + 6.0 * k)
			draw_line(feather, feather - f * 10.0, Color(0.55, 0.44, 0.3), 1.5)
	Draw.ball(self, o, radius * 0.75, color)
	Draw.ball(self, o + f * radius * 0.7, radius * 0.42, Color(0.95, 0.92, 0.85))
	var beak := o + f * radius * 1.1
	draw_colored_polygon(PackedVector2Array([beak + f * 9.0, beak + side * 4.0, beak - side * 4.0]), Color(0.95, 0.75, 0.3))
	draw_circle(o + f * radius * 0.8 + side * 4.0, 1.8, Palette.OUTLINE)
	draw_circle(o + f * radius * 0.8 - side * 4.0, 1.8, Palette.OUTLINE)


func _draw_lurker(t: float, f: Vector2) -> void:
	if state == "sub":
		# Only ripples and two eyes show above the water.
		for k in 2:
			var rr := 8.0 + fmod(t * 14.0 + k * 9.0, 18.0)
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 20, Color(0.6, 0.85, 0.95, 0.5 * (1.0 - rr / 26.0)), 1.5)
		draw_circle(f * 4.0 + f.orthogonal() * 3.0, 1.4, Color(0.9, 1.0, 0.7, 0.8))
		draw_circle(f * 4.0 - f.orthogonal() * 3.0, 1.4, Color(0.9, 1.0, 0.7, 0.8))
		return
	var rise := 1.0
	if state == "rise":
		rise = clampf(1.0 - state_t / 0.35, 0.2, 1.0)
	elif state == "sink":
		rise = clampf(state_t / 0.35, 0.2, 1.0)
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(0.6, 0.85, 0.95, 0.4), 2.0)
	var side := f.orthogonal()
	var body := PackedVector2Array([f * radius * 1.3 * rise, side * radius * 0.8 * rise, -f * radius * 1.1 * rise, -side * radius * 0.8 * rise])
	Draw.poly(self, body, color)
	# Jaws, open while it lunges.
	var open := 5.0 if state in ["wind", "lunge"] else 2.0
	draw_line(f * radius * 1.2 * rise + side * open, f * radius * 0.5 * rise, Palette.OUTLINE, 2.0)
	draw_line(f * radius * 1.2 * rise - side * open, f * radius * 0.5 * rise, Palette.OUTLINE, 2.0)
	draw_circle(f * radius * 0.6 * rise + side * 3.0, 1.8, Color(0.9, 1.0, 0.7))
	draw_circle(f * radius * 0.6 * rise - side * 3.0, 1.8, Color(0.9, 1.0, 0.7))


func _draw_shellback(f: Vector2) -> void:
	var side := f.orthogonal()
	for s in [-1.0, 1.0]:
		for k in 2:
			Draw.stroke(self, side * s * radius * 0.7 + f * (k * 8.0 - 4.0), side * s * radius * 1.15 + f * (k * 10.0 - 6.0), color.darkened(0.3), 3.0)
	Draw.ball(self, f * radius * 0.85, 5.5, color.lightened(0.15))  # head
	# The shell: a domed oval, its plates facing forward.
	draw_set_transform(Vector2.ZERO, f.angle(), Vector2(1.0, 0.85))
	draw_circle(Vector2.ZERO, radius + 1.6, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, radius, color.darkened(0.2))
	draw_circle(Vector2(-2, -2), radius * 0.82, color)
	draw_arc(Vector2.ZERO, radius * 0.55, -1.0, 1.0, 10, color.lightened(0.25), 2.0)
	draw_line(Vector2(-radius * 0.6, 0), Vector2(radius * 0.6, 0), color.darkened(0.35), 1.5)
	draw_set_transform(Vector2(0, 0), 0.0, Vector2.ONE)
	# The armoured front glints faintly: hit it from behind.
	draw_arc(Vector2.ZERO, radius + 3.0, f.angle() - 1.0, f.angle() + 1.0, 12, Color(0.85, 0.9, 1.0, 0.6), 2.0)


func _draw_kraken(t: float, f: Vector2) -> void:
	# Tentacles, then the great head with two eyes.
	for i in 6:
		var base_a := f.angle() + PI + (float(i) - 2.5) * 0.45
		var pts := PackedVector2Array()
		for k in 7:
			var u := float(k) / 6.0
			var a := base_a + sin(t * 2.0 + i + u * 3.0) * 0.35 * u
			pts.append(Vector2.from_angle(a) * (radius * 0.6 + u * radius * 1.4))
		draw_polyline(pts, Palette.OUTLINE, 9.0 - 4.0 * 0.5, true)
		draw_polyline(pts, color.darkened(0.15), 5.0, true)
	if state == "wind_sweep":
		var reach := Vector2.from_angle(lunge_dir.angle()) * SWEEP_REACH * 0.6
		Draw.stroke(self, lunge_dir * radius * 0.6, reach, color.darkened(0.1), 7.0)
	Draw.ball(self, Vector2.ZERO, radius, color)
	draw_circle(f * radius * 0.35 + f.orthogonal() * 11.0, 6.0, Color(0.98, 0.9, 0.55))
	draw_circle(f * radius * 0.35 - f.orthogonal() * 11.0, 6.0, Color(0.98, 0.9, 0.55))
	draw_circle(f * radius * 0.4 + f.orthogonal() * 11.0, 3.0, Palette.OUTLINE)
	draw_circle(f * radius * 0.4 - f.orthogonal() * 11.0, 3.0, Palette.OUTLINE)


## Telegraphs, status and the health bar: unlit, so they always read.
func _draw_overlay() -> void:
	var c := overlay
	var lift_y := -18.0 if airborne > 0.0 else 0.0
	var danger := Palette.DANGER
	if kind == "knight" and state == "wind_slash":
		# The slash: a wedge in front that fills up until it strikes.
		var ks := clampf(1.0 - state_t / 0.6, 0.0, 1.0)
		var half := deg_to_rad(SLASH_ARC)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 12.0) * SLASH_REACH)
		c.draw_colored_polygon(pts, Color(danger, 0.1 + 0.15 * ks))
		c.draw_arc(Vector2.ZERO, SLASH_REACH * ks, lunge_dir.angle() - half, lunge_dir.angle() + half, 16, Color(danger, 0.7), 2.0)
	if kind == "knight" and state == "wind_lunge":
		var k := 1.0 - state_t / 0.7
		var reach := 140.0
		var w := radius * 2.0
		c.draw_line(Vector2.ZERO, lunge_dir * reach, Color(danger, 0.14), w)
		c.draw_line(Vector2.ZERO, lunge_dir * reach * k, Color(danger, 0.4), w)
		# Chevrons marching along the path.
		var side := lunge_dir.orthogonal()
		for i in 4:
			var d := fmod(float(i) * 35.0 + k * 35.0, reach)
			var at := lunge_dir * d
			c.draw_polyline(PackedVector2Array([at - lunge_dir * 5.0 + side * 6.0, at, at - lunge_dir * 5.0 - side * 6.0]), Color(danger, 0.6), 2.0)
	if kind == "archer" and aim_dir != Vector2.ZERO:
		var k2 := clampf(1.0 - state_t / 0.5, 0.0, 1.0)
		c.draw_line(aim_dir * 14.0, aim_dir * 420.0, Color(danger, 0.25 + 0.4 * k2), 1.0 + k2)
		c.draw_circle(aim_dir * 14.0, 2.0 + k2 * 2.0, Color(danger, 0.8))
	if glint > 0.0:
		# The glint: a white four-point star where the blow will come from.
		var gk := glint / 0.22
		var gp := Vector2(0, lift_y) + face * (radius + 4.0)
		var arm := 6.0 + 10.0 * gk
		var gc := Color(1, 1, 1, gk)
		c.draw_line(gp - Vector2(arm, 0), gp + Vector2(arm, 0), gc, 2.0)
		c.draw_line(gp - Vector2(0, arm), gp + Vector2(0, arm), gc, 2.0)
		c.draw_line(gp - Vector2(arm, arm) * 0.45, gp + Vector2(arm, arm) * 0.45, Color(gc, gk * 0.7), 1.5)
		c.draw_line(gp - Vector2(arm, -arm) * 0.45, gp + Vector2(arm, -arm) * 0.45, Color(gc, gk * 0.7), 1.5)
		c.draw_circle(gp, 3.0 * gk + 1.0, gc)
	if kind == "lurker" and state == "wind":
		c.draw_line(Vector2.ZERO, lunge_dir * 110.0, Color(danger, 0.4), radius * 1.5)
	if kind == "shellback" and state == "wind_bash":
		var kb := clampf(1.0 - state_t / 0.7, 0.0, 1.0)
		var wedge := PackedVector2Array([Vector2.ZERO])
		for i in 11:
			wedge.append(Vector2.from_angle(face.angle() - deg_to_rad(55.0) + deg_to_rad(110.0) * i / 10.0) * 66.0)
		c.draw_colored_polygon(wedge, Color(danger, 0.1 + 0.15 * kb))
	if kind == "kraken":
		if state == "wind_sweep":
			var ks := clampf(1.0 - state_t / 0.7, 0.0, 1.0)
			var half := deg_to_rad(SWEEP_ARC)
			var wedge2 := PackedVector2Array([Vector2.ZERO])
			for i in 17:
				wedge2.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 16.0) * SWEEP_REACH)
			c.draw_colored_polygon(wedge2, Color(danger, 0.08 + 0.12 * ks))
			c.draw_arc(Vector2.ZERO, SWEEP_REACH * ks, lunge_dir.angle() - half, lunge_dir.angle() + half, 24, Color(danger, 0.7), 2.0)
		if state == "wind_slam":
			var kl := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
			for spot in slam_spots:
				var at: Vector2 = spot - global_position
				c.draw_circle(at, SLAM_RADIUS, Color(danger, 0.1 + 0.12 * kl))
				c.draw_arc(at, SLAM_RADIUS, 0.0, TAU, 32, Color(danger, 0.7), 2.0)
				c.draw_arc(at, SLAM_RADIUS * kl, 0.0, TAU, 32, Color(danger, 0.8), 1.5)
		if state == "wind_ink":
			for i in 3:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(16.0)) * 140.0, Color(danger, 0.3), 1.5)
	if kind == "thunderling" and state == "wind_spark":
		var ks := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
		c.draw_circle(Vector2.ZERO, SPARK_RADIUS, Color(danger, 0.08 + 0.1 * ks))
		c.draw_arc(Vector2.ZERO, SPARK_RADIUS, 0.0, TAU, 40, Color(danger, 0.5), 2.0)
		c.draw_arc(Vector2.ZERO, SPARK_RADIUS * ks, 0.0, TAU, 40, Color(danger, 0.7), 1.5)
	if kind == "bat" and state == "wind":
		c.draw_line(Vector2.ZERO, aim_dir * 150.0, Color(danger, 0.35), 2.0)
	if kind == "gryphon":
		if state == "wind_rake":
			var kr := clampf(1.0 - state_t / 0.55, 0.0, 1.0)
			var half := deg_to_rad(RAKE_ARC)
			var wedge := PackedVector2Array([Vector2.ZERO])
			for i in 15:
				wedge.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 14.0) * RAKE_REACH)
			c.draw_colored_polygon(wedge, Color(danger, 0.1 + 0.15 * kr))
			c.draw_arc(Vector2.ZERO, RAKE_REACH * kr, lunge_dir.angle() - half, lunge_dir.angle() + half, 20, Color(danger, 0.7), 2.0)
		if state == "wind_dive" or state == "dive":
			var target: Vector2 = dive_to - global_position
			var kd := clampf(1.0 - state_t / (0.75 if state == "wind_dive" else 0.28), 0.0, 1.0)
			c.draw_circle(target, DIVE_RADIUS, Color(danger, 0.12 + 0.12 * kd))
			c.draw_arc(target, DIVE_RADIUS, 0.0, TAU, 40, Color(danger, 0.7), 2.5)
			c.draw_arc(target, DIVE_RADIUS * kd, 0.0, TAU, 40, Color(danger, 0.8), 1.5)
		if state == "wind_gale":
			for i in 5:
				var a := (float(i) - 2.0) * deg_to_rad(14.0)
				c.draw_line(Vector2.ZERO, lunge_dir.rotated(a) * 120.0, Color(danger, 0.3), 1.5)
	if kind == "slime" and state == "wind":
		c.draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, Color(danger, 0.6), 2.0)
	if charged > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		for i in 3:
			var a := t * 6.0 + i * TAU / 3.0
			c.draw_line(Vector2(0, lift_y) + Vector2.from_angle(a) * (radius + 2.0), Vector2(0, lift_y) + Vector2.from_angle(a + 0.4) * (radius + 6.0), Color(0.95, 0.89, 0.42, 0.9), 1.5)
	if stun > 0.0:
		var ts := Time.get_ticks_msec() * 0.004
		for i in 3:
			c.draw_circle(Vector2(0, lift_y - radius - 8.0) + Vector2.from_angle(ts + i * TAU / 3.0) * 7.0, 2.0, Color(1.0, 0.89, 0.63))
	if hp < max_hp and not is_boss():
		var w2 := radius * 2.2
		var top := Vector2(-w2 / 2.0, lift_y - radius - 11.0)
		c.draw_rect(Rect2(top - Vector2(1, 1), Vector2(w2 + 2, 5)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(top, Vector2(w2 * hp / max_hp, 3.0)), Color(0.85, 0.25, 0.2))
