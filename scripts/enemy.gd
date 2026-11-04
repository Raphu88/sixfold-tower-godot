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
const MATERIAL := {"slime": "hit_slime", "knight": "hit_armor", "archer": "", "bat": "", "thunderling": "", "gryphon": "hit_armor", "lurker": "hit_slime", "shellback": "hit_armor", "kraken": "hit_slime", "cinder": "", "smith": "hit_armor", "wyvern": "hit_armor", "scorpling": "hit_armor", "ram": "hit_armor", "manticore": "hit_armor", "wisp": "", "bloomcap": "hit_slime", "firebird": "", "thornhound": "", "mongrel": "hit_slime", "chimera": "hit_armor"}

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
	# The Wyvern's tower
	"cinder": {"hp": 16.0, "speed": 95.0, "radius": 10.0, "color": Color(1.0, 0.55, 0.22), "dmg": 9.0, "weight": 0.5},
	"smith": {"hp": 60.0, "speed": 45.0, "radius": 16.0, "color": Color(0.45, 0.42, 0.44), "dmg": 18.0, "weight": 4.0},
	"wyvern": {"hp": 420.0, "speed": 72.0, "radius": 28.0, "color": Color(0.72, 0.3, 0.22), "dmg": 18.0, "weight": 35.0, "boss": true},
	# The Manticore's tower
	"scorpling": {"hp": 20.0, "speed": 85.0, "radius": 10.0, "color": Color(0.72, 0.55, 0.32), "dmg": 7.0, "weight": 0.6},
	"ram": {"hp": 70.0, "speed": 50.0, "radius": 17.0, "color": Color(0.62, 0.58, 0.52), "dmg": 16.0, "weight": 5.0},
	"manticore": {"hp": 460.0, "speed": 76.0, "radius": 28.0, "color": Color(0.82, 0.52, 0.3), "dmg": 18.0, "weight": 35.0, "boss": true},
	# The Firebird's tower
	"wisp": {"hp": 14.0, "speed": 110.0, "radius": 9.0, "color": Color(1.0, 0.75, 0.35), "dmg": 8.0, "weight": 0.3},
	"bloomcap": {"hp": 34.0, "speed": 0.0, "radius": 14.0, "color": Color(0.88, 0.42, 0.32), "dmg": 13.0, "weight": 60.0},
	"firebird": {"hp": 440.0, "speed": 90.0, "radius": 26.0, "color": Color(1.0, 0.55, 0.2), "dmg": 17.0, "weight": 30.0, "boss": true},
	# The Chimera's tower
	"thornhound": {"hp": 22.0, "speed": 125.0, "radius": 11.0, "color": Color(0.5, 0.38, 0.3), "dmg": 9.0, "weight": 0.8},
	"mongrel": {"hp": 52.0, "speed": 62.0, "radius": 15.0, "color": Color(0.62, 0.5, 0.42), "dmg": 13.0, "weight": 3.0},
	"chimera": {"hp": 500.0, "speed": 80.0, "radius": 30.0, "color": Color(0.78, 0.6, 0.36), "dmg": 18.0, "weight": 40.0, "boss": true},
}
const BOSSES := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]
## Monsters that fly over chasms.
const FLIERS := ["bat", "gryphon", "cinder", "wyvern", "wisp", "firebird"]
## What each beast calls when it's half dead.
const FLOCK := {"gryphon": "bat", "kraken": "lurker", "wyvern": "cinder", "manticore": "scorpling", "firebird": "wisp", "chimera": "thornhound"}
const BITE_REACH := 70.0  # a thornhound's leap
const LOB_RADIUS := 46.0  # a bloomcap's burning spores land in this circle
const STORM_RADIUS := 52.0  # each spot of the Firebird's firestorm
const STING_REACH := 55.0
const CHARGE_SPEED := 480.0
const CLAW_REACH := 95.0
const CLAW_ARC := 70.0
const ROAR_RADIUS := 130.0
const HAMMER_REACH := 48.0  # a smith's slam lands this far in front of it
const HAMMER_RADIUS := 46.0
const TAIL_REACH := 110.0
const TAIL_ARC := 75.0
const BREATH_REACH := 210.0
const BREATH_ARC := 22.0
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
var venom := 0  # Venomist's poison stacks
var venom_t := 0.0
var venom_tick := 0.0
var lost_t := 0.0  # Ashwalker: it has lost track of you
var lure = null  # ...and goes after this decoy instead (a dictionary with "pos")
var notice_t := 0.0  # still noticing you at the start of a floor
var lob_spot := Vector2.ZERO  # where a bloomcap's spores will land
var storm_spots: Array = []  # the Firebird's firestorm
var reborn := false  # the Firebird rises once from its ashes
var turn := 0  # a mongrel alternates its two attacks
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
	notice_t = state_t
	if kind in ["knight", "thunderling", "gryphon", "shellback", "kraken", "smith", "wyvern", "ram", "manticore", "bloomcap", "firebird", "mongrel", "chimera"]:
		state = "recover"  # stands still until state_t runs out, then gives chase
	if kind == "bat":
		state = "rest"
	if kind in BOSSES:
		state_t = 1.6
	if kind == "lurker":
		state = "sub"
		submerged = true


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 8  # walls, pillars, and Sandshaper's stone walls
	if not kind in FLIERS:
		collision_mask |= 16  # walking monsters can't step into chasms
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
	notice_t -= delta
	lost_t -= delta
	_tick_venom(delta)
	if dead:
		return
	if p == null or p.dead:
		_end_attack("idle", 1.0)
		_drift()
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	# Ashwalker: a foe that has lost you wanders, or goes after a decoy.
	if is_lost(dist) and not (is_attacking() and glinted):
		_wander(delta)
		return
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
		"cinder":
			_cinder(delta, dir, dist, p)
		"smith":
			_smith(delta, dir, dist, p)
		"wyvern":
			_wyvern(delta, dir, dist, p)
		"scorpling":
			_scorpling(delta, dir, dist, p)
		"ram":
			_ram(delta, dir, dist, p)
		"manticore":
			_manticore(delta, dir, dist, p)
		"wisp":
			_wisp(delta, dir, dist, p)
		"bloomcap":
			_bloomcap(delta, dir, dist, p)
		"firebird":
			_firebird(delta, dir, dist, p)
		"thornhound":
			_thornhound(delta, dir, dist, p)
		"mongrel":
			_mongrel(delta, dir, dist, p)
		"chimera":
			_chimera(delta, dir, dist, p)
	# Water slows walking monsters too (not fliers or the ones that live in it),
	# but never an attack already on its way: the glint promised its timing.
	# A Deepcaller's Pressure slows the badly hurt.
	if not state in ["lunge", "pounce", "swoop", "dive", "charge"]:
		velocity *= main.water_slow(global_position, kind in ["lurker", "kraken"] or kind in FLIERS)
	if hp < max_hp * 0.5 and p.has_bond("deepcaller") and dist < 150.0:
		velocity *= 0.6
	# Sandshaper: rubble slows; Shifting Sands slows foes walking up to you
	# (never an attack already under way, which keeps its glint's timing).
	if not is_attacking():
		velocity *= main.rubble_slow(global_position)
		if p.has_bond("sandshaper") and dist < 110.0:
			velocity *= 0.65
	velocity += knock
	move_and_slide()
	_undercurrent()
	_ram_crash()
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
	return state.begins_with("wind") or state in ["pounce", "lunge", "aim", "swoop", "dive", "charge"]


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


# --- the Wyvern's tower --------------------------------------------------------------

# Cinders: living embers that flit at range, glint and spit a burning ember
# (parryable; a parry turns it back).
func _cinder(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_spit":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / 280.0):
				var e = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir * 280.0, dmg)
				e.style = "ember"
				e.tint = color
				main.sfx("zap", 1.6, -6.0)
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, 150.0, speed * 0.6)
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 210.0 and main.request_attack(self):
				_begin_wind("wind_spit", 0.6)
				main.sfx("warn_archer", 1.4, -4.0)
			elif dist < 140.0:
				velocity = -dir * speed  # keeps its distance
			else:
				_circle(dir, dist, 160.0, speed)


# Smiths: slow, heavy forge-workers. The hammer comes down in front of them
# (parryable, but it hits hard) and leaves the floor burning.
func _smith(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_hammer":
			velocity = Vector2.ZERO
			if _wind(delta):
				var spot: Vector2 = global_position + face * HAMMER_REACH
				main.fx_ring(spot, Color(1.0, 0.6, 0.3), HAMMER_RADIUS, 0.35, 5.0)
				main.fx_burst(spot, Vector2.ZERO, Color(1.0, 0.6, 0.3), 12, 240.0)
				main.sfx("hit_heavy", 0.55)
				main.shake(6.0)
				if p.global_position.distance_to(spot) < HAMMER_RADIUS + p.radius:
					p.receive_attack(dmg, self)
				main.add_flame(spot, 34.0, 2.5)
				_end_attack("recover", 1.2)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 75.0 and main.request_attack(self):
				_begin_wind("wind_hammer", 0.85)
				main.sfx("warn_knight", 0.75)
			else:
				velocity = dir * speed


# The Wyvern: a tail sweep up close (parryable), fire breath down a narrow
# cone that sets the floor alight (can't be parried: roll or step aside),
# and a spray of embers (parryable). At half health it calls cinders.
func _wyvern(delta: float, dir: Vector2, dist: float, p) -> void:
	_call_flock()
	match state:
		"wind_tail":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, TAIL_REACH + 10.0, deg_to_rad(TAIL_ARC), Color(1.0, 0.45, 0.3))
				main.sfx("swing_heavy", 0.6)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= TAIL_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(TAIL_ARC):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.9)
		"wind_breath":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, BREATH_REACH, deg_to_rad(BREATH_ARC), Color(1.0, 0.5, 0.15))
				main.light_flash(global_position + lunge_dir * 100.0, Color(1.0, 0.5, 0.2), 1.6, 2.2, 0.4)
				main.sfx("burn", 0.6)
				main.shake(5.0)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= BREATH_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(BREATH_ARC) + 0.1:
					p.receive_attack(dmg * 1.1, self, true)  # fire can't be parried: roll
				for i in 3:
					main.add_flame(global_position + lunge_dir * (70.0 + 60.0 * i), 30.0 + 6.0 * i, 3.0)
				_end_attack("recover", 1.2)
		"wind_embers":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				for i in 5:
					var a := (float(i) - 2.0) * deg_to_rad(12.0)
					var e = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated(a) * 270.0, dmg * 0.5)
					e.style = "ember"
					e.tint = Color(1.0, 0.55, 0.22)
				main.sfx("zap", 1.2, -4.0)
				_end_attack("recover", 0.8)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if not main.request_attack(self):
				velocity = dir * speed if dist > 120.0 else Vector2.ZERO
			elif dist < 105.0:
				_begin_wind("wind_tail", 0.6)
				main.sfx("warn_knight", 0.6)
			elif dist < BREATH_REACH and randf() < 0.55:
				_begin_wind("wind_breath", 0.8)
				main.sfx("charge", 0.6)
			else:
				_begin_wind("wind_embers", 0.6)
				main.sfx("warn_archer", 0.8)


# --- the Manticore's tower ----------------------------------------------------------------

## A hit that landed (not parried, dodged or blocked away) also poisons.
func _sting(p, amount: float, unblockable := false, poison := 4.0) -> void:
	var before: float = p.hp
	p.receive_attack(amount, self, unblockable)
	if p.hp < before:
		p.poison(poison)


# Scorplings: small scorpions that scuttle up, glint and sting (parryable).
# A sting that lands poisons you for a few seconds.
func _scorpling(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_sting":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.sfx("swing", 1.5, -4.0)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= STING_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(50.0):
					_sting(p, dmg)
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, 90.0, speed * 0.6)
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 60.0 and main.request_attack(self):
				_begin_wind("wind_sting", 0.5)
				main.sfx("warn_archer", 1.6, -6.0)
			elif dist < 60.0:
				_circle(dir, dist, 85.0, speed * 0.7)
			else:
				velocity = dir * speed


# Rams: stone-hided brutes that lower their horns, glint, and charge in a
# straight line (parryable). A ram that charges into a wall or pillar is
# stunned: let it miss.
func _ram(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_charge":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				# A charge from far away runs faster, so it lands within the
				# parry window of its glint.
				swoop_speed = maxf(CHARGE_SPEED, maxf(0.0, dist - (radius + p.radius + 4.0)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 4.0)) / swoop_speed):
				state = "charge"
				state_t = 0.75
				lunge_hit = false
				main.sfx("roll", 0.6)
		"charge":
			state_t -= delta
			velocity = lunge_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 4.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 210.0 and dist > 70.0 and main.request_attack(self):
				_begin_wind("wind_charge", 0.8)
				main.sfx("warn_knight", 0.65)
			else:
				velocity = dir * speed


## A charging ram that hits a wall or pillar is stunned (called after it moves).
func _ram_crash() -> void:
	if kind in ["ram", "chimera"] and state == "charge" and get_slide_collision_count() > 0:
		_end_attack("recover", 0.2)
		stagger(1.6)
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "Crashed", Color(0.9, 0.8, 0.6))
		main.fx_burst(global_position + lunge_dir * radius, -lunge_dir, Color(0.85, 0.75, 0.55), 12, 220.0)
		main.sfx("hit_heavy", 0.6)
		main.shake(5.0)


# The Manticore: a claw swipe up close (parryable), a volley of poisoned tail
# spikes (parryable), and a roar that bursts out around it (can't be
# parried: roll through it). At half health it calls scorplings.
func _manticore(delta: float, dir: Vector2, dist: float, p) -> void:
	_call_flock()
	match state:
		"wind_claw":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, CLAW_REACH + 10.0, deg_to_rad(CLAW_ARC), Color(1.0, 0.45, 0.3))
				main.sfx("swing_heavy", 0.8)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= CLAW_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(CLAW_ARC):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.8)
		"wind_spikes":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / 330.0):
				for i in 3:
					var a := (float(i) - 1.0) * deg_to_rad(10.0)
					var sp = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated(a) * 330.0, dmg * 0.45)
					sp.style = "spike"
					sp.tint = color
					sp.poison = 3.0
				main.sfx("bow", 0.7)
				_end_attack("recover", 0.8)
		"wind_roar":
			velocity = Vector2.ZERO
			if _wind(delta):
				main.fx_ring(global_position, Color(1.0, 0.75, 0.45), ROAR_RADIUS, 0.45, 8.0)
				main.fx_burst(global_position, Vector2.ZERO, Color(0.85, 0.7, 0.5), 20, 300.0)
				main.sfx("warn_knight", 0.4)
				main.sfx("hit_heavy", 0.5)
				main.shake(9.0)
				if dist < ROAR_RADIUS + p.radius:
					p.receive_attack(dmg, self, true)  # a roar can't be parried: roll
				_end_attack("recover", 1.2)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if not main.request_attack(self):
				velocity = dir * speed if dist > 110.0 else Vector2.ZERO
			elif dist < 100.0 and randf() < 0.6:
				_begin_wind("wind_claw", 0.55)
				main.sfx("warn_knight", 0.75)
			elif dist < ROAR_RADIUS:
				_begin_wind("wind_roar", 0.9)
				main.sfx("charge", 0.5)
			else:
				_begin_wind("wind_spikes", 0.6)
				main.sfx("warn_archer", 0.7)


# --- the Firebird's tower ---------------------------------------------------------------

# Wisps: flickering spirits that drift around you, glint, and dart straight
# through where you stood (parryable), leaving a little fire behind.
func _wisp(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind":
			velocity = Vector2.ZERO
			if not glinted:
				aim_dir = dir
				swoop_speed = maxf(SWOOP_SPEED, maxf(0.0, dist - (radius + p.radius)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius)) / swoop_speed):
				state = "swoop"
				state_t = 0.35
				lunge_hit = false
		"swoop":
			state_t -= delta
			velocity = aim_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				main.add_flame(global_position, 20.0, 1.5)
				_end_attack("rest", 1.0)
		"rest", "recover", "idle":
			state_t -= delta
			_circle(dir, dist, 120.0, speed * 0.8)
			if state_t <= 0.0:
				state = "hover"
		_:
			if dist < 170.0 and main.request_attack(self):
				_begin_wind("wind", 0.45)
				aim_dir = dir
			else:
				# Flickers about rather than circling smoothly.
				var jitter := Vector2(sin(Time.get_ticks_msec() * 0.007 + get_instance_id()), cos(Time.get_ticks_msec() * 0.009)) * 40.0
				_circle(dir, dist, 120.0, speed)
				velocity += jitter


# Bloomcaps: rooted fire-fungi. They glint, lock onto where you stand, and
# lob burning spores that land a moment later (can't be parried: step out of
# the circle). The ground they hit keeps burning.
func _bloomcap(delta: float, dir: Vector2, dist: float, p) -> void:
	velocity = Vector2.ZERO
	match state:
		"wind_lob":
			if not glinted:
				lob_spot = p.global_position  # it locks on when it glints
			if _wind(delta):
				main.fx_ring(lob_spot, Color(1.0, 0.5, 0.25), LOB_RADIUS, 0.35, 5.0)
				main.fx_burst(lob_spot, Vector2.ZERO, Color(1.0, 0.55, 0.25), 12, 220.0)
				main.sfx("burn", 1.1, -4.0)
				if p.global_position.distance_to(lob_spot) < LOB_RADIUS + p.radius and not p.in_air():
					p.receive_attack(dmg, self, true)
				main.add_flame(lob_spot, 30.0, 2.5)
				_end_attack("recover", 1.6)
		"recover", "idle":
			state_t -= delta
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 340.0 and main.request_attack(self):
				_begin_wind("wind_lob", 0.9)
				main.sfx("charge", 1.2, -6.0)


# The Firebird: a burning swoop straight through you (parryable) that leaves
# fire in its wake, a firestorm of four spots, one where you stand (can't be
# parried: get out of the circles), and a fan of embers (parryable). The
# first time it falls it burns to ashes and rises again. Calls wisps at half.
func _firebird(delta: float, dir: Vector2, dist: float, p) -> void:
	if state == "ashes":
		velocity = Vector2.ZERO
		state_t -= delta
		if state_t <= 0.0:
			hp = max_hp * 0.4
			state = "recover"
			state_t = 0.6
			main.fx_ring(global_position, color, 120.0, 0.5, 8.0)
			main.fx_burst(global_position, Vector2.ZERO, color, 30, 360.0)
			main.light_flash(global_position, color, 2.5, 2.5, 0.6)
			main.fx_text(global_position + Vector2(0, -radius - 30.0), "The Firebird rises again", color)
			main.sfx("crit", 0.5)
			main.shake(10.0)
		return
	_call_flock()
	match state:
		"wind_swoop":
			velocity = Vector2.ZERO
			if not glinted:
				aim_dir = dir
				swoop_speed = maxf(SWOOP_SPEED, maxf(0.0, dist - (radius + p.radius)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius)) / swoop_speed):
				state = "swoop"
				state_t = 0.45
				lunge_hit = false
				main.sfx("gust", 0.8)
		"swoop":
			state_t -= delta
			velocity = aim_dir * swoop_speed
			if fmod(state_t, 0.09) < delta:
				main.add_flame(global_position, 22.0, 2.0)
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 1.0)
		"wind_storm":
			velocity = Vector2.ZERO
			if not glinted:
				storm_spots[0] = p.global_position
			if _wind(delta):
				for spot in storm_spots:
					main.fx_ring(spot, color, STORM_RADIUS, 0.4, 5.0)
					main.fx_burst(spot, Vector2.UP, Color(1.0, 0.6, 0.25), 12, 260.0)
					main.add_flame(spot, 32.0, 2.5)
					if p.global_position.distance_to(spot) < STORM_RADIUS + p.radius and not p.in_air():
						p.receive_attack(dmg, self, true)
				main.sfx("burn", 0.6)
				main.light_flash(p.global_position, color, 2.0, 1.6, 0.4)
				main.shake(7.0)
				_end_attack("recover", 1.2)
		"wind_embers":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				for i in 7:
					var a := (float(i) - 3.0) * deg_to_rad(11.0)
					var e = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated(a) * 280.0, dmg * 0.45)
					e.style = "ember"
					e.tint = color
				main.sfx("gust", 1.1)
				_end_attack("recover", 0.8)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, 170.0, speed * 0.5)
			if state_t <= 0.0:
				state = "chase"
		_:
			if not main.request_attack(self):
				_circle(dir, dist, 170.0, speed)
			elif dist < 230.0 and randf() < 0.45:
				_begin_wind("wind_swoop", 0.6)
				main.sfx("warn_knight", 0.8)
			elif randf() < 0.5:
				storm_spots = [p.global_position]
				for i in 3:
					storm_spots.append(p.global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * randf_range(90.0, 140.0))
				_begin_wind("wind_storm", 0.9)
				main.sfx("charge", 0.6)
			else:
				_begin_wind("wind_embers", 0.6)
				main.sfx("warn_archer", 0.7)


## The Firebird's first death: it burns down to ashes, then rises.
func _fall_to_ashes() -> void:
	reborn = true
	hp = 1.0
	_end_attack("ashes", 2.2)
	main.fx_text(global_position + Vector2(0, -radius - 20.0), "The Firebird falls to ashes...", color)
	main.fx_burst(global_position, Vector2.ZERO, Color(0.5, 0.45, 0.42), 24, 220.0)
	main.sfx("burn", 0.5)


# --- the Chimera's tower -------------------------------------------------------------------

# Thornhounds: fast pack hounds. They circle, glint and leap at you with a
# bite (parryable).
func _thornhound(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				swoop_speed = maxf(LUNGE_SPEED * 0.7, maxf(0.0, dist - (radius + p.radius + 4.0)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 4.0)) / swoop_speed):
				state = "lunge"
				state_t = 0.2
				lunge_hit = false
		"lunge":
			state_t -= delta
			velocity = lunge_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 0.9)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, 110.0, speed * 0.6)
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < 120.0 and main.request_attack(self):
				_begin_wind("wind", 0.45)
				main.sfx("warn_archer", 1.5, -6.0)
			elif dist < 120.0:
				_circle(dir, dist, 110.0, speed * 0.8)
			else:
				velocity = dir * speed


# Mongrels: patchwork beasts that alternate a bite up close (parryable) with
# a fan of thrown quills (parryable).
func _mongrel(delta: float, dir: Vector2, dist: float, p) -> void:
	match state:
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, BITE_REACH, deg_to_rad(50.0), Color(1.0, 0.45, 0.3))
				main.sfx("swing_heavy", 1.1)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= BITE_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(50.0):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.9)
		"wind_quills":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / 300.0):
				for i in 3:
					var q = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(12.0)) * 300.0, dmg * 0.6)
					q.style = "spike"
					q.tint = color
				main.sfx("bow", 1.1)
				_end_attack("recover", 0.9)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			# Bite when close; every other turn, throw quills from range.
			if dist < 75.0 and main.request_attack(self):
				turn += 1
				_begin_wind("wind_bite", 0.6)
				main.sfx("warn_knight", 1.0)
			elif dist < 260.0 and turn % 2 == 1 and main.request_attack(self):
				turn += 1
				_begin_wind("wind_quills", 0.6)
				main.sfx("warn_archer", 1.0)
			else:
				velocity = dir * speed
				if randf() < delta * 0.5:
					turn += 1


# The Chimera: three beasts in one. The lion mauls up close (parryable) and
# breathes fire down a narrow cone (can't be parried: roll or step aside); the
# goat charges in a straight line (parryable; it's stunned if it hits a
# wall); the serpent tail spits poisoned spikes (parryable). Calls thornhounds.
func _chimera(delta: float, dir: Vector2, dist: float, p) -> void:
	_call_flock()
	match state:
		"wind_maul":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, CLAW_REACH + 10.0, deg_to_rad(CLAW_ARC), Color(1.0, 0.45, 0.3))
				main.sfx("swing_heavy", 0.7)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= CLAW_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(CLAW_ARC):
					p.receive_attack(dmg, self)
				_end_attack("recover", 0.8)
		"wind_breath":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, BREATH_REACH, deg_to_rad(BREATH_ARC), Color(1.0, 0.5, 0.15))
				main.light_flash(global_position + lunge_dir * 100.0, Color(1.0, 0.5, 0.2), 1.6, 2.2, 0.4)
				main.sfx("burn", 0.6)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= BREATH_REACH + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(BREATH_ARC) + 0.1:
					p.receive_attack(dmg * 1.1, self, true)
				for i in 3:
					main.add_flame(global_position + lunge_dir * (70.0 + 60.0 * i), 28.0, 2.5)
				_end_attack("recover", 1.1)
		"wind_charge":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
				swoop_speed = maxf(CHARGE_SPEED, maxf(0.0, dist - (radius + p.radius + 4.0)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius + 4.0)) / swoop_speed):
				state = "charge"
				state_t = 0.7
				lunge_hit = false
				main.sfx("roll", 0.5)
		"charge":
			state_t -= delta
			velocity = lunge_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 4.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 1.0)
		"wind_spikes":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / 330.0):
				for i in 3:
					var sp = main.spawn_projectile(global_position + lunge_dir * radius, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(10.0)) * 330.0, dmg * 0.45)
					sp.style = "spike"
					sp.tint = Color(0.55, 0.8, 0.35)
					sp.poison = 3.0
				main.sfx("bow", 0.7)
				_end_attack("recover", 0.8)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if not main.request_attack(self):
				velocity = dir * speed if dist > 110.0 else Vector2.ZERO
			elif dist < 100.0:
				_begin_wind("wind_maul", 0.55)
				main.sfx("warn_knight", 0.7)
			else:
				var roll := randf()
				if dist < 210.0 and roll < 0.35:
					_begin_wind("wind_charge", 0.8)
					main.sfx("warn_knight", 0.55)
				elif dist < BREATH_REACH and roll < 0.7:
					_begin_wind("wind_breath", 0.8)
					main.sfx("charge", 0.6)
				else:
					_begin_wind("wind_spikes", 0.6)
					main.sfx("warn_archer", 0.7)


# --- Venomist's poison and Ashwalker's stealth ---------------------------------------------

## Poison stacks. Each new stack also makes it last longer (Toxin Build).
func add_venom(stacks: int) -> void:
	if dead:
		return
	venom = mini(venom + stacks, 12)
	venom_t = maxf(venom_t, 3.0 + 0.5 * venom)


## All the poison still to come, at once (Virulence).
func venom_left() -> float:
	return float(venom) * ceilf(venom_t / 0.5)


func _tick_venom(delta: float) -> void:
	if venom <= 0:
		return
	venom_t -= delta
	venom_tick -= delta
	if venom_tick <= 0.0:
		venom_tick = 0.5
		hp -= float(venom)
		flash = 0.05
		if hp <= 0.0:
			take_hit(1.0, Vector2.ZERO, 0.0)  # dies the usual way
			return
	if venom_t <= 0.0:
		venom = 0


## Loses track of the climber for a while (smoke, a decoy). Beasts never do.
func lose_track(seconds: float, decoy) -> void:
	if is_boss():
		return
	lost_t = maxf(lost_t, seconds)
	if decoy != null:
		lure = decoy


func is_lost(dist := 0.0) -> bool:
	if is_boss():
		return false
	var p = main.player
	return lost_t > 0.0 or p.vanish_t > 0.0 or (main.ashfall_t > 0.0 and dist > 170.0)


## Unseen Strike: true if it hasn't noticed the climber yet, or has lost them.
func unaware() -> bool:
	if is_boss():
		return false
	return notice_t > 0.0 or is_lost(global_position.distance_to(main.player.global_position))


func _wander(delta: float) -> void:
	if state.begins_with("wind") or main.holds_attack(self):
		_end_attack("idle", 0.4)
	var go := Vector2.ZERO
	if lure != null and lure["t"] > 0.0:
		go = (lure["pos"] - global_position)
		if go.length() < radius + 10.0:
			go = Vector2.ZERO
		else:
			go = go.normalized() * speed * 0.8
	else:
		lure = null
		var a := Time.get_ticks_msec() * 0.0007 + float(get_instance_id() % 17)
		go = Vector2(cos(a), sin(a * 1.3)) * speed * 0.35
	velocity = go + knock
	if go != Vector2.ZERO:
		face = face.slerp(go.normalized(), minf(1.0, 4.0 * delta)).normalized()
	move_and_slide()
	queue_redraw()


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false) -> void:
	if dead:
		return
	if submerged:
		main.fx_text(global_position + Vector2(0, -radius - 10.0), "under the water", Color(0.5, 0.75, 0.85))
		return
	if main.counting_hits:
		main.cast_hits += 1
	# A shellback's shell turns blows from the front (heavy blows crack it).
	if kind == "shellback" and dir != Vector2.ZERO and face.dot(-dir) > 0.4:
		amount *= 0.6 if heavy else 0.15
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "Blocked" if not heavy else "Cracked", Color(0.8, 0.84, 0.9))
		main.sfx("hit_armor", 1.2, -2.0)
	if challenged_t > 0.0:
		amount *= 1.5  # Challenged foes take more damage
	notice_t = 0.0  # it certainly knows you're here now
	if kind == "firebird" and state == "ashes":
		main.fx_text(global_position + Vector2(0, -radius - 10.0), "ashes", Color(0.7, 0.6, 0.55))
		return
	hp -= amount
	flash = 0.12
	squash = 1.0
	if dir != Vector2.ZERO:
		squash_dir = dir
		# The knight is heavy and the beast is heavier: they barely budge.
		knock = dir * force * (0.4 if kind == "knight" else (0.12 if is_boss() else 1.0))
	main.fx_text(global_position + Vector2(0, -radius - 10.0), str(int(round(amount))), Color(1.0, 0.95, 0.85))
	if hp <= 0.0 and kind == "firebird" and not reborn:
		_fall_to_ashes()
		return
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
		"cinder":
			_draw_cinder(t, f)
		"smith":
			_draw_smith(f)
		"wyvern":
			_draw_wyvern(t, f)
		"scorpling":
			_draw_scorpling(t, f)
		"ram":
			_draw_ram(f)
		"manticore":
			_draw_manticore(t, f)
		"wisp":
			_draw_wisp(t)
		"bloomcap":
			_draw_bloomcap(t, f)
		"firebird":
			_draw_firebird(t, f)
		"thornhound":
			_draw_thornhound(t, f)
		"mongrel":
			_draw_mongrel(t, f)
		"chimera":
			_draw_chimera(t, f)
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


func _draw_cinder(t: float, f: Vector2) -> void:
	# A flickering flame with two dark eyes.
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var r := radius * (1.0 + 0.18 * sin(t * 14.0 + i * 1.7))
		if a > PI * 1.25 and a < PI * 1.75:
			r *= 1.5  # the tip licks upward
		pts.append(Vector2.from_angle(a) * r)
	Draw.poly(self, pts, color)
	draw_circle(Vector2(0, 1), radius * 0.55, Color(1.0, 0.85, 0.4))
	draw_circle(f * 3.0 + f.orthogonal() * 3.0, 1.6, Palette.OUTLINE)
	draw_circle(f * 3.0 - f.orthogonal() * 3.0, 1.6, Palette.OUTLINE)


func _draw_smith(f: Vector2) -> void:
	var side := f.orthogonal()
	# The hammer: raised during the wind-up, down after.
	var raise := 0.0
	if state == "wind_hammer":
		raise = clampf(1.0 - state_t / 0.85, 0.0, 1.0)
	var head := side * radius * 0.9 + f * (radius * 1.2) * (1.0 - raise) - f * radius * 0.6 * raise
	Draw.stroke(self, side * radius * 0.7, head, Color(0.4, 0.28, 0.18), 3.5)
	Draw.ball(self, head, 7.0, Color(0.32, 0.3, 0.33))
	Draw.ball(self, Vector2.ZERO, radius, color)
	draw_circle(Vector2(-2, -3), radius * 0.7, color.lightened(0.12))
	# A leather apron and a glowing forge-mark.
	draw_line(f * 2.0 - side * 7.0, f * 2.0 + side * 7.0, Color(0.4, 0.28, 0.18), 4.0)
	draw_circle(f * radius * 0.45, 3.0, Color(1.0, 0.55, 0.22))


func _draw_wyvern(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	var flap := sin(t * (6.0 if state.begins_with("wind") else 3.0))
	# Tail, then wings, then the body and head.
	var tail := PackedVector2Array()
	var swing := 0.0
	if state == "wind_tail":
		swing = clampf(1.0 - state_t / 0.6, 0.0, 1.0) * 1.2
	for k in 7:
		var u := float(k) / 6.0
		tail.append(-f * (radius * 0.6 + u * radius * 1.8) + side * sin(t * 2.5 + u * 3.0) * 8.0 * u + side * swing * u * radius)
	draw_polyline(tail, Palette.OUTLINE, 8.0, true)
	draw_polyline(tail, color.darkened(0.2), 5.0, true)
	for s in [-1.0, 1.0]:
		var root: Vector2 = side * s * radius * 0.5
		var tip: Vector2 = side * s * radius * (2.2 + 0.3 * flap) - f * radius * 0.4
		var back: Vector2 = -f * radius * 0.9 + side * s * radius * 0.9
		var wing := PackedVector2Array([root + f * 6.0, tip, back])
		draw_colored_polygon(wing, color.darkened(0.35))
		draw_polyline(PackedVector2Array([root + f * 6.0, tip, back]), Palette.OUTLINE, 1.5)
	Draw.ball(self, Vector2.ZERO, radius * 0.8, color)
	var head_at := f * radius * 0.95
	Draw.ball(self, head_at, radius * 0.42, color.lightened(0.08))
	draw_circle(head_at + f * 4.0 + side * 5.0, 2.6, Color(1.0, 0.8, 0.3))
	draw_circle(head_at + f * 4.0 - side * 5.0, 2.6, Color(1.0, 0.8, 0.3))
	if state == "wind_breath":
		var k := clampf(1.0 - state_t / 0.8, 0.0, 1.0)
		draw_circle(head_at + f * radius * 0.45, 3.0 + 5.0 * k, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * k))


func _draw_scorpling(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	# Legs, pincers, then the body and the curled tail over it.
	for k in 3:
		for sgn in [-1.0, 1.0]:
			var root: Vector2 = side * sgn * radius * 0.6 + f * (4.0 - k * 4.0)
			Draw.stroke(self, root, root + side * sgn * 6.0 + f * sin(t * 18.0 + k) * 2.0, color.darkened(0.35), 1.6)
	for sgn in [-1.0, 1.0]:
		var claw: Vector2 = f * radius * 1.2 + side * sgn * radius * 0.6
		Draw.stroke(self, f * radius * 0.5 + side * sgn * 4.0, claw, color.darkened(0.2), 2.4)
		draw_circle(claw, 3.0, color.darkened(0.1))
	Draw.ball(self, Vector2.ZERO, radius, color)
	var strike := 0.0
	if state == "wind_sting":
		strike = clampf(1.0 - state_t / 0.5, 0.0, 1.0)
	var tail := PackedVector2Array()
	for k in 6:
		var u := float(k) / 5.0
		tail.append(-f * radius * (1.0 - u * 1.6) + side * sin(u * 3.0) * 3.0 - f * radius * 0.6 * (1.0 - strike) * u + f * radius * 1.4 * strike * u * u)
	draw_polyline(tail, Palette.OUTLINE, 4.0, true)
	draw_polyline(tail, color.lightened(0.1), 2.2, true)
	draw_circle(tail[tail.size() - 1], 2.5, Color(0.6, 0.85, 0.35))


func _draw_ram(f: Vector2) -> void:
	var side := f.orthogonal()
	Draw.ball(self, Vector2.ZERO, radius, color)
	draw_circle(Vector2(-2, -3), radius * 0.72, color.lightened(0.1))
	# Cracked stone hide and two curled horns.
	draw_line(-side * 6.0 - f * 4.0, side * 2.0 + f * 2.0, color.darkened(0.3), 1.5)
	for sgn in [-1.0, 1.0]:
		var base: Vector2 = f * radius * 0.6 + side * sgn * radius * 0.45
		draw_arc(base + side * sgn * 4.0, 6.0, 0.0, TAU * 0.8, 12, Palette.OUTLINE, 4.0)
		draw_arc(base + side * sgn * 4.0, 6.0, 0.0, TAU * 0.8, 12, Color(0.85, 0.8, 0.68), 2.0)
	draw_circle(f * radius * 0.85 + side * 3.5, 1.6, Palette.OUTLINE)
	draw_circle(f * radius * 0.85 - side * 3.5, 1.6, Palette.OUTLINE)


func _draw_manticore(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	var flap := sin(t * 3.0)
	# Bat wings, the scorpion tail, the lion's body, mane and face.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = side * sgn * radius * 0.4
		var tip: Vector2 = side * sgn * radius * (1.9 + 0.25 * flap) - f * radius * 0.2
		var back: Vector2 = -f * radius * 0.8 + side * sgn * radius * 0.8
		draw_colored_polygon(PackedVector2Array([root + f * 4.0, tip, back]), Color(0.45, 0.28, 0.25))
		draw_polyline(PackedVector2Array([root + f * 4.0, tip, back]), Palette.OUTLINE, 1.5)
	var curl := 1.0 if state == "wind_spikes" else 0.0
	var tail := PackedVector2Array()
	for k in 8:
		var u := float(k) / 7.0
		tail.append(-f * radius * (0.7 + u * 1.3) + side * sin(t * 2.0 + u * 2.5) * 6.0 * u - f * radius * u * u * (0.6 - curl * 1.8))
	draw_polyline(tail, Palette.OUTLINE, 7.0, true)
	draw_polyline(tail, color.darkened(0.25), 4.5, true)
	draw_circle(tail[tail.size() - 1], 5.0, Color(0.55, 0.8, 0.35))
	Draw.ball(self, Vector2.ZERO, radius * 0.85, color)
	var mane_at := f * radius * 0.7
	for i in 12:
		var a := TAU * i / 12.0
		draw_circle(mane_at + Vector2.from_angle(a) * radius * 0.42, radius * 0.18, Color(0.6, 0.32, 0.18))
	Draw.ball(self, mane_at, radius * 0.38, color.lightened(0.1))
	var open := 4.0 if state == "wind_roar" else 1.5
	draw_line(mane_at + f * 6.0 - side * 4.0, mane_at + f * 6.0 + side * 4.0, Palette.OUTLINE, open)
	draw_circle(mane_at + f * 2.0 + side * 5.0, 2.2, Color(1.0, 0.85, 0.35))
	draw_circle(mane_at + f * 2.0 - side * 5.0, 2.2, Color(1.0, 0.85, 0.35))


func _draw_wisp(t: float) -> void:
	var k := 0.8 + 0.2 * sin(t * 16.0)
	draw_circle(Vector2.ZERO, radius * 1.6, Color(color, 0.18))
	draw_circle(Vector2.ZERO, radius * k, color)
	draw_circle(Vector2(0, -1), radius * 0.55 * k, Color(1.0, 0.95, 0.7))
	for i in 3:
		var a := t * 5.0 + TAU * i / 3.0
		draw_circle(Vector2.from_angle(a) * radius * 1.2, 1.6, Color(color, 0.8))


func _draw_bloomcap(t: float, f: Vector2) -> void:
	# A squat stalk under a broad, spotted cap that swells as it winds up.
	var swell := 1.0
	if state == "wind_lob":
		swell = 1.0 + 0.2 * clampf(1.0 - state_t / 0.9, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-5, -2), Vector2(10, radius * 0.9)), Color(0.85, 0.78, 0.65))
	Draw.ball(self, Vector2(0, -4), radius * swell, color)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		draw_circle(Vector2(0, -4) + Vector2.from_angle(a) * radius * 0.55 * swell, 2.2, Color(1.0, 0.85, 0.55))
	if state == "wind_lob":
		for i in 3:
			draw_circle(Vector2(sin(t * 9.0 + i) * 6.0, -radius - 6.0 - fmod(t * 30.0 + i * 7.0, 14.0)), 1.6, Color(1.0, 0.6, 0.25, 0.8))


func _draw_firebird(t: float, f: Vector2) -> void:
	if state == "ashes":
		# A smouldering heap, glowing brighter as it's about to rise.
		var glow := clampf(1.0 - state_t / 2.2, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0.25, 0.22, 0.22))
		for i in 8:
			var a := TAU * i / 8.0
			draw_circle(Vector2.from_angle(a) * radius * 0.5, 4.0, Color(1.0, 0.45 + 0.3 * glow, 0.2, 0.3 + 0.6 * glow))
		return
	var side := f.orthogonal()
	var flap := sin(t * (7.0 if state == "swoop" else 4.0))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = side * sgn * radius * 0.35
		var tip: Vector2 = side * sgn * radius * (2.3 + 0.35 * flap) - f * radius * 0.5
		var back: Vector2 = -f * radius * 0.9 + side * sgn * radius * 0.6
		draw_colored_polygon(PackedVector2Array([root + f * 6.0, tip, back]), Color(1.0, 0.45, 0.15, 0.85))
		draw_colored_polygon(PackedVector2Array([root + f * 3.0, root.lerp(tip, 0.7), back.lerp(root, 0.3)]), Color(1.0, 0.8, 0.35, 0.8))
	# A tail of trailing flame.
	for i in 5:
		var u := float(i) / 4.0
		draw_circle(-f * radius * (0.8 + u * 1.2) + side * sin(t * 6.0 + u * 4.0) * 5.0, radius * 0.35 * (1.0 - u * 0.6), Color(1.0, 0.5 + 0.3 * u, 0.2, 0.7 - u * 0.4))
	Draw.ball(self, Vector2.ZERO, radius * 0.7, color)
	Draw.ball(self, f * radius * 0.75, radius * 0.35, Color(1.0, 0.7, 0.3))
	draw_circle(f * radius * 0.85 + side * 4.0, 2.0, Palette.OUTLINE)
	draw_circle(f * radius * 0.85 - side * 4.0, 2.0, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, radius * 1.4, Color(1.0, 0.5, 0.2, 0.12))


func _draw_thornhound(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	var run := sin(t * 16.0) * 2.0
	# A lean hound with thorny ridges down its back.
	for sgn in [-1.0, 1.0]:
		Draw.stroke(self, side * sgn * 5.0 + f * 5.0, side * sgn * 8.0 + f * (8.0 + run * sgn), color.darkened(0.3), 2.0)
		Draw.stroke(self, side * sgn * 5.0 - f * 6.0, side * sgn * 8.0 - f * (8.0 - run * sgn), color.darkened(0.3), 2.0)
	draw_set_transform(Vector2.ZERO, f.angle(), Vector2(1.4, 0.8))
	draw_circle(Vector2.ZERO, radius + 1.5, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2(0, 0), 0.0, Vector2.ONE)
	for i in 4:
		var at := -f * (radius * 0.9 - i * 6.0)
		draw_line(at, at - f * 3.0 + Vector2(0, -6.0), Color(0.35, 0.55, 0.3), 2.0)
	Draw.ball(self, f * radius * 1.2, 6.0, color.lightened(0.1))
	draw_circle(f * radius * 1.4 + side * 2.5, 1.4, Color(1.0, 0.75, 0.3))
	draw_circle(f * radius * 1.4 - side * 2.5, 1.4, Color(1.0, 0.75, 0.3))


func _draw_mongrel(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	# Patches of different hides, stitched together, with quills on its back.
	Draw.ball(self, Vector2.ZERO, radius, color)
	draw_circle(side * 5.0 - f * 3.0, radius * 0.5, Color(0.45, 0.35, 0.3))
	draw_circle(-side * 4.0 + f * 2.0, radius * 0.45, Color(0.72, 0.62, 0.52))
	draw_line(f * radius * 0.8 - side * 2.0, -f * radius * 0.8 + side * 2.0, Color(0.2, 0.15, 0.12), 1.2)
	for i in 5:
		var a := f.angle() + PI + (float(i) - 2.0) * 0.35
		var root := Vector2.from_angle(a) * radius * 0.7
		draw_line(root, root + Vector2.from_angle(a) * (8.0 if state != "wind_quills" else 12.0), Color(0.85, 0.75, 0.55), 2.0)
	Draw.ball(self, f * radius * 0.9, 6.5, color.lightened(0.05))
	draw_circle(f * radius * 1.1 + side * 3.0, 1.6, Palette.OUTLINE)
	draw_circle(f * radius * 1.1 - side * 3.0, 1.6, Color(0.9, 0.3, 0.25))


func _draw_chimera(t: float, f: Vector2) -> void:
	var side := f.orthogonal()
	# The serpent tail behind, the lion's body, the goat's head on one side.
	var tail := PackedVector2Array()
	for k in 8:
		var u := float(k) / 7.0
		tail.append(-f * radius * (0.7 + u * 1.4) + side * sin(t * 3.0 + u * 4.0) * 9.0 * u)
	draw_polyline(tail, Palette.OUTLINE, 7.0, true)
	draw_polyline(tail, Color(0.4, 0.62, 0.32), 4.5, true)
	Draw.ball(self, tail[tail.size() - 1], 5.0, Color(0.45, 0.68, 0.36))
	Draw.ball(self, Vector2.ZERO, radius * 0.85, color)
	# Goat head with curled horns.
	var goat := side * radius * 0.55 + f * radius * 0.45
	Draw.ball(self, goat, radius * 0.3, Color(0.82, 0.8, 0.74))
	draw_arc(goat - f * 3.0 + side * 5.0, 6.0, 0.0, TAU * 0.75, 12, Color(0.55, 0.5, 0.45), 3.0)
	# Lion head with a mane.
	var lion := -side * radius * 0.2 + f * radius * 0.75
	for i in 10:
		draw_circle(lion + Vector2.from_angle(TAU * i / 10.0) * radius * 0.38, radius * 0.16, Color(0.6, 0.38, 0.2))
	Draw.ball(self, lion, radius * 0.34, color.lightened(0.12))
	draw_circle(lion + f * 3.0 + side * 4.0, 2.2, Color(1.0, 0.85, 0.35))
	draw_circle(lion + f * 3.0 - side * 4.0, 2.2, Color(1.0, 0.85, 0.35))
	if state == "wind_breath":
		var k := clampf(1.0 - state_t / 0.8, 0.0, 1.0)
		draw_circle(lion + f * radius * 0.45, 3.0 + 5.0 * k, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * k))


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
	if kind == "thornhound" and state == "wind":
		c.draw_line(Vector2.ZERO, lunge_dir * 110.0, Color(danger, 0.4), radius * 1.4)
	if kind == "mongrel":
		if state == "wind_bite":
			var half := deg_to_rad(50.0)
			var wedge := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				wedge.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 8.0) * BITE_REACH)
			c.draw_colored_polygon(wedge, Color(danger, 0.12 + 0.15 * clampf(1.0 - state_t / 0.6, 0.0, 1.0)))
		if state == "wind_quills":
			for i in 3:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(12.0)) * 130.0, Color(danger, 0.3), 1.5)
	if kind == "chimera":
		for pair in [["wind_maul", CLAW_REACH, CLAW_ARC, 0.55], ["wind_breath", BREATH_REACH, BREATH_ARC, 0.8]]:
			if state == pair[0]:
				var kw := clampf(1.0 - state_t / pair[3], 0.0, 1.0)
				var half2 := deg_to_rad(pair[2])
				var wedge2 := PackedVector2Array([Vector2.ZERO])
				for i in 15:
					wedge2.append(Vector2.from_angle(lunge_dir.angle() - half2 + 2.0 * half2 * i / 14.0) * pair[1])
				c.draw_colored_polygon(wedge2, Color(danger, 0.1 + 0.15 * kw))
				c.draw_arc(Vector2.ZERO, pair[1] * kw, lunge_dir.angle() - half2, lunge_dir.angle() + half2, 20, Color(danger, 0.75), 2.0)
		if state == "wind_charge" or state == "charge":
			c.draw_line(Vector2.ZERO, lunge_dir * 230.0, Color(danger, 0.2), radius * 1.6)
		if state == "wind_spikes":
			for i in 3:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(10.0)) * 150.0, Color(danger, 0.3), 1.5)
	if kind == "wisp" and state == "wind":
		c.draw_line(Vector2.ZERO, aim_dir * 120.0, Color(danger, 0.4), radius * 1.6)
	if kind == "bloomcap" and state == "wind_lob":
		var kl := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
		var at := lob_spot - global_position
		if not glinted:
			at = main.player.global_position - global_position
		c.draw_circle(at, LOB_RADIUS, Color(danger, 0.1 + 0.14 * kl))
		c.draw_arc(at, LOB_RADIUS, 0.0, TAU, 32, Color(danger, 0.7), 2.0)
		c.draw_arc(at, LOB_RADIUS * kl, 0.0, TAU, 32, Color(danger, 0.8), 1.5)
	if kind == "firebird":
		if state == "wind_swoop":
			c.draw_line(Vector2.ZERO, aim_dir * 260.0, Color(danger, 0.3), radius * 1.4)
		if state == "wind_storm":
			var ks := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
			for spot in storm_spots:
				var sp: Vector2 = spot - global_position
				c.draw_circle(sp, STORM_RADIUS, Color(danger, 0.1 + 0.12 * ks))
				c.draw_arc(sp, STORM_RADIUS, 0.0, TAU, 32, Color(danger, 0.7), 2.0)
				c.draw_arc(sp, STORM_RADIUS * ks, 0.0, TAU, 32, Color(danger, 0.8), 1.5)
		if state == "wind_embers":
			for i in 7:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 3.0) * deg_to_rad(11.0)) * 120.0, Color(danger, 0.3), 1.5)
	if kind == "scorpling" and state == "wind_sting":
		var half := deg_to_rad(50.0)
		var wedge := PackedVector2Array([Vector2.ZERO])
		for i in 9:
			wedge.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 8.0) * STING_REACH)
		c.draw_colored_polygon(wedge, Color(danger, 0.12 + 0.15 * clampf(1.0 - state_t / 0.5, 0.0, 1.0)))
	if kind == "ram" and (state == "wind_charge" or state == "charge"):
		var kc := clampf(1.0 - state_t / 0.8, 0.0, 1.0) if state == "wind_charge" else 1.0
		c.draw_line(Vector2.ZERO, lunge_dir * 260.0, Color(danger, 0.14), radius * 2.0)
		c.draw_line(Vector2.ZERO, lunge_dir * 260.0 * kc, Color(danger, 0.35), radius * 2.0)
	if kind == "manticore":
		if state == "wind_claw":
			var kw := clampf(1.0 - state_t / 0.55, 0.0, 1.0)
			var half2 := deg_to_rad(CLAW_ARC)
			var wedge2 := PackedVector2Array([Vector2.ZERO])
			for i in 15:
				wedge2.append(Vector2.from_angle(lunge_dir.angle() - half2 + 2.0 * half2 * i / 14.0) * CLAW_REACH)
			c.draw_colored_polygon(wedge2, Color(danger, 0.1 + 0.15 * kw))
			c.draw_arc(Vector2.ZERO, CLAW_REACH * kw, lunge_dir.angle() - half2, lunge_dir.angle() + half2, 20, Color(danger, 0.75), 2.0)
		if state == "wind_roar":
			var kr := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
			c.draw_circle(Vector2.ZERO, ROAR_RADIUS, Color(danger, 0.08 + 0.12 * kr))
			c.draw_arc(Vector2.ZERO, ROAR_RADIUS, 0.0, TAU, 48, Color(danger, 0.7), 2.5)
			c.draw_arc(Vector2.ZERO, ROAR_RADIUS * kr, 0.0, TAU, 48, Color(danger, 0.8), 1.5)
		if state == "wind_spikes":
			for i in 3:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 1.0) * deg_to_rad(10.0)) * 150.0, Color(danger, 0.3), 1.5)
	if kind == "cinder" and state == "wind_spit":
		c.draw_line(Vector2.ZERO, lunge_dir * 140.0, Color(danger, 0.35), 1.5)
	if kind == "smith" and state == "wind_hammer":
		var kh := clampf(1.0 - state_t / 0.85, 0.0, 1.0)
		var spot := face * HAMMER_REACH
		c.draw_circle(spot, HAMMER_RADIUS, Color(danger, 0.1 + 0.14 * kh))
		c.draw_arc(spot, HAMMER_RADIUS, 0.0, TAU, 32, Color(danger, 0.7), 2.0)
		c.draw_arc(spot, HAMMER_RADIUS * kh, 0.0, TAU, 32, Color(danger, 0.8), 1.5)
	if kind == "wyvern":
		for pair in [["wind_tail", TAIL_REACH, TAIL_ARC, 0.6], ["wind_breath", BREATH_REACH, BREATH_ARC, 0.8]]:
			if state == pair[0]:
				var kw := clampf(1.0 - state_t / pair[3], 0.0, 1.0)
				var half := deg_to_rad(pair[2])
				var wedge := PackedVector2Array([Vector2.ZERO])
				for i in 15:
					wedge.append(Vector2.from_angle(lunge_dir.angle() - half + 2.0 * half * i / 14.0) * pair[1])
				c.draw_colored_polygon(wedge, Color(danger, 0.1 + 0.15 * kw))
				c.draw_arc(Vector2.ZERO, pair[1] * kw, lunge_dir.angle() - half, lunge_dir.angle() + half, 20, Color(danger, 0.75), 2.0)
		if state == "wind_embers":
			for i in 5:
				c.draw_line(Vector2.ZERO, lunge_dir.rotated((float(i) - 2.0) * deg_to_rad(12.0)) * 120.0, Color(danger, 0.3), 1.5)
	if charged > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		for i in 3:
			var a := t * 6.0 + i * TAU / 3.0
			c.draw_line(Vector2(0, lift_y) + Vector2.from_angle(a) * (radius + 2.0), Vector2(0, lift_y) + Vector2.from_angle(a + 0.4) * (radius + 6.0), Color(0.95, 0.89, 0.42, 0.9), 1.5)
	if stun > 0.0:
		var ts := Time.get_ticks_msec() * 0.004
		for i in 3:
			c.draw_circle(Vector2(0, lift_y - radius - 8.0) + Vector2.from_angle(ts + i * TAU / 3.0) * 7.0, 2.0, Color(1.0, 0.89, 0.63))
	if venom > 0:
		var tv := Time.get_ticks_msec() * 0.003
		for i in mini(venom, 6):
			var dp := Vector2(-radius + i * radius * 0.4, -radius - 4.0 + fmod(tv + i * 0.37, 1.0) * 8.0)
			c.draw_circle(dp, 1.6, Color(0.55, 0.85, 0.35, 0.85))
	if is_lost(global_position.distance_to(main.player.global_position)) and main.player != null:
		c.draw_string(ThemeDB.fallback_font, Vector2(-4, lift_y - radius - 16.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.78, 0.75, 0.9))
	if hp < max_hp and not is_boss():
		var w2 := radius * 2.2
		var top := Vector2(-w2 / 2.0, lift_y - radius - 11.0)
		c.draw_rect(Rect2(top - Vector2(1, 1), Vector2(w2 + 2, 5)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(top, Vector2(w2 * hp / max_hp, 3.0)), Color(0.85, 0.25, 0.2))
