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
## A monster flinches from a light hit at most this often (no stun-locking
## by mashing); heavy hits (finishers) always rock it.
const FLINCH_COOLDOWN := 1.2
## After an attack, a monster is open: hits deal this much more. That's
## where your damage should come from.
const OPEN_MULT := 1.6
const POUNCE_SPEED := 420.0
const LUNGE_SPEED := 760.0

const TYPES := {
	"slime": {"hp": 24.0, "speed": 60.0, "radius": 13.0, "color": Color(0.5, 0.88, 0.4), "dmg": 8.0, "weight": 0.7},
	"archer": {"hp": 18.0, "speed": 75.0, "radius": 11.0, "color": Color(0.62, 0.5, 0.3), "dmg": 8.0, "weight": 0.8},
	"knight": {"hp": 48.0, "speed": 60.0, "radius": 15.0, "color": Color(0.66, 0.7, 0.8), "dmg": 14.0, "weight": 3.0},
	# The Gryphon's tower
	"bat": {"hp": 10.0, "speed": 120.0, "radius": 9.0, "color": Color(0.6, 0.48, 0.82), "dmg": 6.0, "weight": 0.4},
	"thunderling": {"hp": 26.0, "speed": 70.0, "radius": 11.0, "color": Color(0.95, 0.89, 0.42), "dmg": 12.0, "weight": 1.0},
	"gryphon": {"hp": 300.0, "speed": 78.0, "radius": 26.0, "color": Color(0.88, 0.74, 0.45), "dmg": 18.0, "weight": 30.0, "boss": true},
	# The Kraken's tower
	"lurker": {"hp": 30.0, "speed": 95.0, "radius": 12.0, "color": Color(0.31, 0.56, 0.66), "dmg": 11.0, "weight": 1.0},
	"shellback": {"hp": 40.0, "speed": 40.0, "radius": 16.0, "color": Color(0.5, 0.6, 0.66), "dmg": 12.0, "weight": 4.0},
	"kraken": {"hp": 340.0, "speed": 35.0, "radius": 34.0, "color": Color(0.6, 0.3, 0.42), "dmg": 18.0, "weight": 40.0, "boss": true},
	# The Wyvern's tower
	"cinder": {"hp": 16.0, "speed": 95.0, "radius": 10.0, "color": Color(1.0, 0.55, 0.22), "dmg": 9.0, "weight": 0.5},
	"smith": {"hp": 60.0, "speed": 45.0, "radius": 16.0, "color": Color(0.45, 0.42, 0.44), "dmg": 18.0, "weight": 4.0},
	"wyvern": {"hp": 320.0, "speed": 72.0, "radius": 28.0, "color": Color(0.72, 0.3, 0.22), "dmg": 18.0, "weight": 35.0, "boss": true},
	# The Manticore's tower
	"scorpling": {"hp": 20.0, "speed": 85.0, "radius": 10.0, "color": Color(0.72, 0.55, 0.32), "dmg": 7.0, "weight": 0.6},
	"ram": {"hp": 70.0, "speed": 50.0, "radius": 17.0, "color": Color(0.62, 0.58, 0.52), "dmg": 16.0, "weight": 5.0},
	"manticore": {"hp": 350.0, "speed": 76.0, "radius": 28.0, "color": Color(0.82, 0.52, 0.3), "dmg": 18.0, "weight": 35.0, "boss": true},
	# The Firebird's tower
	"wisp": {"hp": 14.0, "speed": 110.0, "radius": 9.0, "color": Color(1.0, 0.75, 0.35), "dmg": 8.0, "weight": 0.3},
	"bloomcap": {"hp": 34.0, "speed": 0.0, "radius": 14.0, "color": Color(0.88, 0.42, 0.32), "dmg": 13.0, "weight": 60.0},
	"firebird": {"hp": 330.0, "speed": 90.0, "radius": 26.0, "color": Color(1.0, 0.55, 0.2), "dmg": 17.0, "weight": 30.0, "boss": true},
	# The Chimera's tower
	"thornhound": {"hp": 22.0, "speed": 125.0, "radius": 11.0, "color": Color(0.5, 0.38, 0.3), "dmg": 9.0, "weight": 0.8},
	"mongrel": {"hp": 52.0, "speed": 62.0, "radius": 15.0, "color": Color(0.62, 0.5, 0.42), "dmg": 13.0, "weight": 3.0},
	"chimera": {"hp": 380.0, "speed": 80.0, "radius": 30.0, "color": Color(0.78, 0.6, 0.36), "dmg": 18.0, "weight": 40.0, "boss": true},
	# Covenant's spirit familiar (only ever on your side)
	"familiar": {"hp": 20.0, "speed": 130.0, "radius": 9.0, "color": Color(0.6, 0.82, 1.0), "dmg": 5.0, "weight": 0.5},
}
## Surgeon's Diagnosis: what each monster is weak to.
const WEAKNESS := {
	"slime": "flinches when hit", "archer": "close range", "knight": "parry, then riposte",
	"bat": "parry the swoop", "thunderling": "step out of the ring", "lurker": "strike while it's up",
	"shellback": "strike from behind", "cinder": "parry the ember back", "smith": "the opening after the hammer",
	"scorpling": "parry the sting", "ram": "let it charge into a wall", "wisp": "parry the dart",
	"bloomcap": "it can't move: get close", "thornhound": "parry the leap", "mongrel": "parry, then riposte",
	"gryphon": "the landing's long opening", "kraken": "the recovery after a slam", "wyvern": "stay close, away from its breath",
	"manticore": "roll through the roar", "firebird": "it rises once: save something", "chimera": "let the goat hit a wall",
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
var dead := false:
	set(v):
		if dead != v:
			dead = v
			_foes_changed()

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
var submerged := false:  # a lurker under the surface: can't be struck or targeted
	set(v):
		if submerged != v:
			submerged = v
			_foes_changed()
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
var aware := true  # on a floor of rooms, a monster waits until it sees you
var path_t := 0.0  # when to look for a way around the walls again
var path_d := Vector2.ZERO
var sight_t := 0.0  # line of sight is re-checked a few times a second (phones)
var sees := true
var lob_spot := Vector2.ZERO  # where a bloomcap's spores will land
var storm_spots: Array = []  # the Firebird's firestorm
var reborn := false  # the Firebird rises once from its ashes
var turn := 0  # a mongrel alternates its two attacks
var cripple_t := 0.0  # Surgeon's Sever: can't run or charge
var chill_t := 0.0  # a Coral Trident's hit: walks 25% slower
var burn_t := 0.0  # of Embers: burning, a little damage every half second
var burn_dmg := 0.0
var burn_tick := 0.0
var flinch_cd := 0.0  # light hits can't flinch it again until this runs out
var open_t := 0.0  # recovering from an attack: open to heavy punishment
var disarm_t := 0.0  # ...and disarmed: can't start an attack
# Covenant: a called creature fights for you.
var ally := false
var ally_t := 0.0
var ally_life := 30.0
var ally_target = null
var ally_guard := false
var ally_cd := 0.0
var vanish_t := 0.0  # (for monsters targeting a creature, which can't vanish)
var overlay: Node2D  # over the darkness: telegraphs and the health bar
## A champion (wings.gd sends one when a sealed wing's condition is broken):
## any tower monster, bigger and tougher, crowned, with a gold aura and one
## extra attack: a ground slam, telegraphed by a closing ring (roll out).
var champion := false
var champ_t := 0.0  # until its next slam
var champ_wind := 0.0  # the slam's wind-up, counting down
const CHAMPION := {"hp": 3.5, "dmg": 1.3, "size": 1.35, "weight": 3.0, "slam_every": 6.0, "slam_wind": 0.9,
	"slam_reach": 88.0, "slam_dmg": 1.3, "slam_near": 120.0, "color": Color(1.0, 0.82, 0.4)}


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
	# Covenant's Kinship: a kind in your pact book is slower to notice you.
	if main != null and main.profile != null and kind in main.profile.pacts and main.player != null and main.player.has_bond("covenant"):
		state_t *= 2.0
		notice_t = state_t
	# A Dusk Cloak: monsters are slower to notice you.
	if main != null and main.player != null and main.player.gfx("notice") > 0.0 and not (kind in BOSSES):
		state_t *= 1.0 + main.player.gfx("notice")
		notice_t = state_t
	if kind == "lurker":
		state = "sub"
		submerged = true


## A called creature (Covenant): fights on your side, scaled to your bond's step.
func setup_ally(k: String, room, step: int, seconds: float) -> void:
	setup(k, room)
	ally = true
	ally_t = seconds
	ally_life = seconds
	max_hp = 30.0 + 15.0 * step
	hp = max_hp
	dmg = 4.0 + 3.0 * step
	speed = maxf(speed, 70.0) * 1.1
	state = "ally"
	notice_t = 0.0


## Makes it a champion (call after setup, before adding it to the room).
func make_champion() -> void:
	champion = true
	max_hp *= float(CHAMPION["hp"])
	hp = max_hp
	dmg *= float(CHAMPION["dmg"])
	weight *= float(CHAMPION["weight"])
	champ_t = float(CHAMPION["slam_every"]) * 0.6
	notice_t = 0.0


## A champion's slam: every few seconds when the climber is near, a ring
## closes in around it for a moment (roll out of it), then the ground breaks.
func _champion_slam(delta: float, _dist: float, p) -> void:
	var pl = main.player
	if pl == null:
		return
	var near: float = global_position.distance_to(pl.global_position)
	if champ_wind > 0.0:
		champ_wind -= delta
		if champ_wind <= 0.0:
			var reach := float(CHAMPION["slam_reach"])
			var col: Color = CHAMPION["color"]
			main.fx_ring(global_position, col, reach, 0.35, 5.0)
			main.fx_burst(global_position, Vector2.ZERO, col, 18, 260.0)
			main.light_flash(global_position, col, 1.4, 1.6, 0.3)
			main.shake(7.0)
			main.sfx("slam", 0.7, -2.0)
			if near < reach + pl.radius and not pl.dead:
				pl.receive_attack(dmg * float(CHAMPION["slam_dmg"]), self, true)
			champ_t = float(CHAMPION["slam_every"])
		return
	champ_t -= delta
	if champ_t <= 0.0 and near < float(CHAMPION["slam_near"]) and aware and stun <= 0.0:
		champ_wind = float(CHAMPION["slam_wind"])
		main.sfx("charge", 0.6, -4.0)


## The room remembers its list of monsters for the frame (main.enemies()):
## a spawn, a death or a removal makes it build the list again.
func _foes_changed() -> void:
	if main != null and is_instance_valid(main):
		main.foes_changed()


func _enter_tree() -> void:
	_foes_changed()


func _exit_tree() -> void:
	_foes_changed()


func _ready() -> void:
	add_to_group("allies" if ally else "enemies")
	_foes_changed()
	# Spread out the monsters' sight and path checks over different ticks.
	sight_t = randf() * 0.2
	path_t = randf() * 0.2
	visibility_changed.connect(_on_visibility)
	collision_layer = 4
	collision_mask = 1 | 8  # walls, pillars, and Sandshaper's stone walls
	if not kind in FLIERS:
		collision_mask |= 16  # walking monsters can't step into chasms
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * (float(CHAMPION["size"]) if champion else 1.0)
	shape.shape = circle
	add_child(shape)
	overlay = Node2D.new()
	# Over the darkness layer (lighting.gd), so telegraphs read in the dark;
	# a monster out of sight is hidden, and its overlay with it.
	overlay.z_as_relative = false
	overlay.z_index = 45
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
	if ally:
		_ally_ai(delta)
		return
	notice_t -= delta
	lost_t -= delta
	flinch_cd -= delta
	open_t -= delta
	cripple_t -= delta
	chill_t -= delta
	_tick_burn(delta)
	disarm_t -= delta
	_tick_venom(delta)
	if dead:
		return
	p = _foe(p)
	if p == null or p.dead:
		_end_attack("idle", 1.0)
		_drift()
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	# Rooms and corridors: wait until it sees you, then find a way around walls.
	if main.layout_on:
		sight_t -= delta
		if sight_t <= 0.0:
			sight_t = 0.2
			# (Asleep and too far to wake: no need to look.)
			sees = main.clear_line(global_position, p.global_position) if aware or dist < 460.0 else false
		var seen := sees
		if not aware:
			if (seen and dist < 460.0) or dist < 110.0:
				wake()
			else:
				# Asleep: nothing to work out; only a shove moves it.
				if knock != Vector2.ZERO:
					velocity = knock
					move_and_slide()
				_redraw()
				return
		if not seen and not is_attacking():
			path_t -= delta
			# Paths are costly: only a few monsters look for one each tick
			# (main.take_path_turn), and their turns are spread out.
			if path_t <= 0.0 and main.take_path_turn():
				path_t = 0.2 + randf() * 0.06
				path_d = main.path_dir(global_position, p.global_position)
			dir = path_d
			dist = 9999.0  # can't attack what it can't see: it closes in instead
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
	# Surgeon's Sever: a crippled foe can't run or charge.
	if cripple_t > 0.0:
		velocity *= 0.35
	if chill_t > 0.0 and not is_attacking():
		velocity *= 0.75
	if not is_attacking():
		velocity *= main.rubble_slow(global_position)
		if p.has_bond("sandshaper") and dist < 110.0:
			velocity *= 0.65
	velocity += knock
	move_and_slide()
	_undercurrent()
	_ram_crash()
	if champion:
		_champion_slam(delta, dist, p)
	_redraw()


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
	_redraw()


func _on_visibility() -> void:
	if visible:
		queue_redraw()


## Asks for a fresh drawing, but only while it can be seen (fog.gd hides
## monsters out of sight; one coming back into view is redrawn then).
func _redraw() -> void:
	if visible:
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
		main.tip("glint")
	return state_t <= 0.0


func _begin_wind(new_state: String, duration: float) -> void:
	state = new_state
	state_t = duration
	glinted = false


func _end_attack(next_state: String, duration: float) -> void:
	# Finishing a committed attack leaves it open for most of its recovery.
	if glinted and next_state != "ashes":
		open_t = minf(duration, 1.6) * (1.0 if is_boss() else 0.8)
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
				_end_attack("recover", 1.1)
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
				main.sfx("slam", 1.0)
				main.shake(9.0)
				if global_position.distance_to(p.global_position) < DIVE_RADIUS + p.radius:
					p.receive_attack(dmg * 1.2, self, true)  # a landing can't be parried: roll
				_end_attack("recover", 1.6)  # a long opening after landing
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
				_end_attack("recover", 1.0)
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
				main.sfx("slam", 1.0)
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
				_end_attack("recover", 1.2)
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
				main.sfx("slam", 0.85)
				main.shake(8.0)
				_end_attack("recover", 1.5)
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
				_end_attack("recover", 1.0)
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
				main.sfx("warn_archer", 1.0, -4.0)
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
				main.sfx("slam", 0.92)
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
				_end_attack("recover", 1.2)
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
					main.add_flame(global_position + lunge_dir * (70.0 + 60.0 * i), 26.0 + 4.0 * i, 1.6)
				_end_attack("recover", 1.6)
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
				_end_attack("recover", 1.1)
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
				main.sfx("warn_archer", 1.05, -6.0)
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
		main.sfx("slam", 1.0)
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
				_end_attack("recover", 1.1)
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
				_end_attack("recover", 1.1)
		"wind_roar":
			velocity = Vector2.ZERO
			if _wind(delta):
				main.fx_ring(global_position, Color(1.0, 0.75, 0.45), ROAR_RADIUS, 0.45, 8.0)
				main.fx_burst(global_position, Vector2.ZERO, Color(0.85, 0.7, 0.5), 20, 300.0)
				main.sfx("warn_knight", 0.4)
				main.sfx("slam", 0.85)
				main.shake(9.0)
				if dist < ROAR_RADIUS + p.radius:
					p.receive_attack(dmg, self, true)  # a roar can't be parried: roll
				_end_attack("recover", 1.5)
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
				main.add_flame(global_position, 20.0, 1.2)
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("recover", 1.3)
		"wind_storm":
			velocity = Vector2.ZERO
			if not glinted:
				storm_spots[0] = p.global_position
			if _wind(delta):
				for spot in storm_spots:
					main.fx_ring(spot, color, STORM_RADIUS, 0.4, 5.0)
					main.fx_burst(spot, Vector2.UP, Color(1.0, 0.6, 0.25), 12, 260.0)
					main.add_flame(spot, 28.0, 1.6)
					if p.global_position.distance_to(spot) < STORM_RADIUS + p.radius and not p.in_air():
						p.receive_attack(dmg, self, true)
				main.sfx("burn", 0.6)
				main.light_flash(p.global_position, color, 2.0, 1.6, 0.4)
				main.shake(7.0)
				_end_attack("recover", 1.5)
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
				_end_attack("recover", 1.1)
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
				_end_attack("recover", 1.1)
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
					main.add_flame(global_position + lunge_dir * (70.0 + 60.0 * i), 26.0, 1.6)
				_end_attack("recover", 1.5)
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
				_end_attack("recover", 1.3)
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
				_end_attack("recover", 1.1)
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


# --- Covenant's creatures ---------------------------------------------------------------

## Who this monster goes after: the climber, or one of their creatures that
## is closer (creatures split the monsters' attention).
func _foe(p):
	var best = p
	var best_d: float = global_position.distance_to(p.global_position) if p != null else INF
	for a in main.allies():
		var d: float = global_position.distance_to(a.global_position)
		if d < 140.0 and d < best_d - 20.0:
			best = a
			best_d = d
	return best


func _ally_ai(delta: float) -> void:
	ally_t -= delta
	ally_cd -= delta
	if ally_t <= 0.0:
		_fade_ally()
		return
	var p = main.player
	var target = ally_target
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
		ally_target = null
	if target == null:
		# The nearest foe: near you if guarding, near itself otherwise.
		var from: Vector2 = p.global_position if ally_guard else global_position
		var best_d := 120.0 if ally_guard else 420.0
		for e in main.targets():
			var d := from.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				target = e
	var go := Vector2.ZERO
	if target != null:
		var to: Vector2 = target.global_position - global_position
		var reach: float = radius + target.radius + 10.0
		face = face.slerp(to.normalized(), minf(1.0, 8.0 * delta)).normalized()
		if to.length() > reach:
			go = to.normalized() * speed
			if not main.clear_line(global_position, target.global_position):
				go = main.path_dir(global_position, target.global_position) * speed
		elif ally_cd <= 0.0:
			ally_cd = 0.9
			target.take_hit(dmg, to.normalized(), 120.0)
			main.fx_burst(target.global_position - to.normalized() * target.radius, to.normalized(), Color(0.7, 1.0, 0.8), 5, 200.0)
			main.sfx("hit", 1.2, -6.0)
	elif p != null and global_position.distance_to(p.global_position) > 60.0:
		go = (p.global_position - global_position).normalized() * speed
	velocity = go + knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	queue_redraw()


func _fade_ally() -> void:
	dead = true
	main.fx_burst(global_position, Vector2.ZERO, Color(0.7, 1.0, 0.85), 12, 160.0)
	queue_free()


## A monster's attack reaching a creature (the same call the climber takes).
func receive_attack(amount: float, _source, _unblockable := false) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	main.fx_text(global_position + Vector2(0, -radius - 10.0), str(int(round(amount))), Color(1.0, 0.6, 0.55))
	if hp <= 0.0:
		main.fx_text(global_position + Vector2(0, -radius - 22.0), "your %s falls" % kind, Color(0.8, 0.8, 0.8))
		_fade_ally()


# Things monsters check on whoever they're fighting (a creature can't jump,
# isn't poisoned and has no bonds).
func in_air() -> bool:
	return false


func poison(_seconds: float) -> void:
	pass


func has_bond(_bond_id: String) -> bool:
	return false


# --- Venomist's poison and Ashwalker's stealth ---------------------------------------------

## Poison stacks. Each new stack also makes it last longer (Toxin Build).
func add_venom(stacks: int) -> void:
	if dead:
		return
	venom = mini(venom + stacks, 12)
	venom_t = maxf(venom_t, 3.0 + 0.5 * venom)


## Sets it burning (of Embers): `dmg` every half second for `seconds`.
func ignite(dmg: float, seconds: float) -> void:
	if dead:
		return
	burn_dmg = maxf(burn_dmg if burn_t > 0.0 else 0.0, dmg)
	burn_t = maxf(burn_t, seconds)
	main.fx_burst(global_position, Vector2.ZERO, Color(1.0, 0.5, 0.2), 6, 120.0)


func _tick_burn(delta: float) -> void:
	if burn_t <= 0.0:
		return
	burn_t -= delta
	burn_tick -= delta
	if burn_tick <= 0.0:
		burn_tick = 0.5
		if submerged:
			return
		hp -= burn_dmg
		flash = 0.05
		if hp <= 0.0:
			take_hit(1.0, Vector2.ZERO, 0.0)  # dies the usual way
			return
		main.fx_text(global_position + Vector2(0, -radius - 14.0), "-%d" % int(burn_dmg), Color(1.0, 0.55, 0.25))


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


## Notices the climber, and rouses the monsters near it.
func wake() -> void:
	if aware:
		return
	aware = true
	for e in main.enemies():
		if not e.aware and e.global_position.distance_to(global_position) < 240.0:
			e.wake()


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
	_redraw()


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
	if open_t > 0.0 and stun <= 0.0:
		amount *= OPEN_MULT  # caught recovering from its attack
		main.fx_text(global_position + Vector2(0, -radius - 34.0), "Opening!", Color(1.0, 0.85, 0.45))
	notice_t = 0.0  # it certainly knows you're here now
	if not aware:
		wake()
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
		_leave_remains()
		queue_free()
		return
	# Flinching: slimes and archers are knocked out of what they were doing.
	# Knights shrug off hits while winding up; only heavy blows rock them
	# when they aren't attacking.
	# Poise: a committed attack carries on through light hits (read the glint:
	# parry or roll), and light hits flinch a monster only now and then.
	# Heavy hits (finishers) still rock most monsters. Beasts never flinch.
	var poise := is_boss() or (not heavy and (is_attacking() or flinch_cd > 0.0)) or (kind == "knight" and not heavy)
	if not poise and dir != Vector2.ZERO and stun <= 0.0:
		flinch = FLINCH_TIME
		flinch_cd = FLINCH_COOLDOWN
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


# --- drawing ---------------------------------------------------------------------
# Every monster is drawn the way the climber is: a dark outline
# (Palette.OUTLINE) with a soft rim, lit from the top-left (a shaded side and
# a highlight), limbs as thick outlined strokes. A Pen collects the whole
# body as one list of triangles and sends it as ONE draw call: cheaper on
# phones, and lit evenly (in Godot 4.3's Compatibility renderer a wide
# draw_line/draw_arc is lit on only one of its two triangles, which made
# monsters shimmer under the torches). Glowing bits (fire, lightning, eyes in
# the dark) and the telegraphs go on the unlit overlay, also as one call.
# Poses are eased (_ease) so nothing pops between states, and every cycle
# (wings, gait, spin) is accumulated so a change of speed never jumps.

const C_EYE := Color(0.97, 0.96, 0.9)
const C_EYE_GLOW := Color(1.0, 0.82, 0.38)
const C_BONE := Color(0.9, 0.86, 0.74)
const C_HORN := Color(0.84, 0.78, 0.64)
const C_STRING := Color(0.9, 0.88, 0.8)
const C_LEATHER := Color(0.42, 0.29, 0.19)
const C_IRON := Color(0.33, 0.31, 0.35)
const C_SKIN := Color(0.7, 0.55, 0.45)
const C_WATER := Color(0.6, 0.85, 0.95)
const C_VENOM := Color(0.6, 0.86, 0.35)
const C_THORN := Color(0.36, 0.56, 0.3)
const C_QUILL := Color(0.86, 0.77, 0.58)
const C_FLAME := Color(1.0, 0.72, 0.3)
const C_FLAME_CORE := Color(1.0, 0.94, 0.66)
const C_EMBER := Color(1.0, 0.5, 0.18)
const C_ASH := Color(0.27, 0.24, 0.24)
const C_BEAK := Color(0.96, 0.76, 0.32)
const C_GRYPHON_HEAD := Color(0.95, 0.92, 0.85)
const C_GRYPHON_WING := Color(0.74, 0.6, 0.4)
const C_MANE := Color(0.58, 0.32, 0.17)
const C_BAT_WING := Color(0.45, 0.28, 0.25)
const C_SERPENT := Color(0.42, 0.64, 0.34)
const C_GOAT := Color(0.82, 0.8, 0.74)
const C_STALK := Color(0.86, 0.79, 0.66)
const C_CAP_SPOT := Color(1.0, 0.86, 0.58)
const C_SUCKER := Color(0.86, 0.62, 0.66)
const C_FAMILIAR_CORE := Color(0.9, 0.97, 1.0)

var _pen := Pen.new()  # the body (lit)
var _glow := Pen.new()  # glowing bits (unlit, drawn with the overlay)
var _ov := Pen.new()  # the overlay: telegraphs and status
var _dt := 0.016
var _stride := 0.0  # gait cycle, advanced by how far it walks
var _move := 0.0  # 0 standing .. 1 walking at full speed (eased)
var _lift := 0.0  # height off the floor (eased)
var _flap := 0.0  # wing cycle
var _spin := 0.0  # a thunderling's spin
var _eased := {}


## Eases a pose value toward `want` (frame-rate independent), so a pose
## never snaps from one state to the next.
func _ease(key: String, want: float, rate := 10.0) -> float:
	var v: float = _eased.get(key, want)
	v = lerpf(v, want, 1.0 - exp(-rate * _dt))
	_eased[key] = v
	return v


## How far through a wind-up of `dur` seconds it is, 0..1.
func _wk(dur: float) -> float:
	return clampf(1.0 - state_t / dur, 0.0, 1.0)


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 100)
	_dt = clampf(get_process_delta_time(), 0.0, 0.05)
	var spd := velocity.length()
	_move = move_toward(_move, clampf(spd / maxf(speed, 50.0), 0.0, 1.0), _dt * 5.0)
	_stride += spd * _dt * 0.11
	var flap_rate := 3.5
	if state.begins_with("wind") or state in ["swoop", "dive"]:
		flap_rate = 7.0
	if kind == "bat":
		flap_rate = 17.0
	_flap += _dt * flap_rate
	_lift = move_toward(_lift, -18.0 if airborne > 0.0 else 0.0, _dt * 110.0)
	var lift_y := _lift
	if kind == "slime" and state == "pounce":
		lift_y -= sin(PI * clampf(1.0 - state_t / 0.3, 0.0, 1.0)) * 10.0
	var p := _pen
	p.reset()
	_glow.reset()
	# A soft shadow on the floor, smaller the higher it is.
	var sr := radius * clampf(1.0 + lift_y / 90.0, 0.6, 1.0)
	p.oval(Vector2(0, radius * 0.7), Vector2(sr * 1.1, sr * 0.5), 0.0, Color(0, 0, 0, 0.17))
	p.oval(Vector2(0, radius * 0.7), Vector2(sr * 0.85, sr * 0.38), 0.0, Color(0, 0, 0, 0.21))
	# Squashed along the direction it was hit from; a hit tints it toward white.
	var a := squash_dir.angle()
	var sq := Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.25)
	p.xf = Transform2D(0.0, Vector2(0, lift_y)) * Transform2D(a, sq, 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	if champion:
		var cs := float(CHAMPION["size"])
		p.xf = Transform2D(0.0, Vector2(cs, cs), 0.0, Vector2.ZERO) * p.xf
	_glow.xf = p.xf
	p.tint = clampf(flash / 0.12, 0.0, 1.0) * 0.6
	var f := face
	match kind:
		"slime":
			_draw_slime(p, t, f)
		"archer":
			_draw_archer(p, t, f)
		"knight":
			_draw_knight(p, t, f)
		"bat":
			_draw_bat(p, t, f)
		"thunderling":
			_draw_thunderling(p, t, f)
		"gryphon":
			_draw_gryphon(p, t, f)
		"lurker":
			_draw_lurker(p, t, f)
		"shellback":
			_draw_shellback(p, t, f)
		"kraken":
			_draw_kraken(p, t, f)
		"cinder":
			_draw_cinder(p, t, f)
		"smith":
			_draw_smith(p, t, f)
		"wyvern":
			_draw_wyvern(p, t, f)
		"scorpling":
			_draw_scorpling(p, t, f)
		"ram":
			_draw_ram(p, t, f)
		"manticore":
			_draw_manticore(p, t, f)
		"wisp":
			_draw_wisp(p, t, f)
		"bloomcap":
			_draw_bloomcap(p, t, f)
		"firebird":
			_draw_firebird(p, t, f)
		"thornhound":
			_draw_thornhound(p, t, f)
		"mongrel":
			_draw_mongrel(p, t, f)
		"chimera":
			_draw_chimera(p, t, f)
		"familiar":
			_draw_wisp(p, t, f)
	p.flush(self)
	if overlay != null:
		overlay.queue_redraw()


## On death the body slumps and fades where it fell (the room's burst and
## debris play over it). A separate node, since the monster itself is freed.
func _leave_remains() -> void:
	if main == null or _pen.pts.is_empty() or not is_inside_tree():
		return
	_spawn_remains(main, position, _pen.pts, _pen.cols, radius)


static func _spawn_remains(parent: Node, at: Vector2, pts: PackedVector2Array, cols: PackedColorArray, r: float) -> void:
	var n := Node2D.new()
	n.position = at
	var k := [0.0]
	n.draw.connect(func() -> void:
		var e: float = k[0]
		n.draw_set_transform(Vector2(0, r * 0.45 * e), 0.0, Vector2(1.0 + 0.3 * e, 1.0 - 0.7 * e))
		RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), PackedInt32Array(), pts, cols))
	parent.add_child(n)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		k[0] = v
		n.modulate = Color(1.0 - 0.45 * v, 1.0 - 0.5 * v, 1.0 - 0.45 * v, 1.0 - v * v)
		n.queue_redraw(), 0.0, 1.0, 0.4)
	tw.tween_callback(n.queue_free)


## A sword lying along dir from the grip (like Draw.sword, into the pen).
func _sword(p: Pen, grip: Vector2, dir: Vector2, length: float) -> void:
	var side := dir.orthogonal()
	var tip := grip + dir * length
	p.limb(grip - dir * 5.0, grip, Palette.WOOD.darkened(0.3), 3.0)
	p.poly(PackedVector2Array([grip + dir * 1.5 + side * 1.9, tip - dir * 4.0 + side * 1.6, tip, tip - dir * 4.0 - side * 1.6, grip + dir * 1.5 - side * 1.9]), Palette.STEEL, 1.3)
	p.quad(grip + dir * 3.0 + side * 0.6, tip - dir * 4.0 + side * 0.5, 0.9, Color(1, 1, 1, 0.6))
	p.limb(grip + side * 5.0, grip - side * 5.0, Palette.STEEL.darkened(0.35), 2.4)
	p.ball(grip - dir * 6.5, 2.0, Palette.STEEL.darkened(0.2))


## A curled horn sweeping out from its root and back round, tapering.
func _horn(p: Pen, root: Vector2, out: Vector2, back: Vector2, size: float, w0: float, col: Color) -> void:
	p.tube(PackedVector2Array([root, root + out * 0.55 * size + back * 0.1 * size, root + out * 0.85 * size + back * 0.55 * size, root + out * 0.65 * size + back * 0.95 * size, root + out * 0.3 * size + back * 0.9 * size]), PackedFloat32Array([w0, w0 * 0.9, w0 * 0.75, w0 * 0.55, w0 * 0.35]), col)


## A feather (or flame tongue): a leaf shape from base along dir.
func _feather(p: Pen, base: Vector2, dir: Vector2, length: float, width: float, col: Color, outline := 1.2) -> void:
	var sd := dir.orthogonal() * width * 0.5
	p.poly(PackedVector2Array([base + sd * 0.6, base + dir * length * 0.45 + sd, base + dir * length, base + dir * length * 0.45 - sd, base - sd * 0.6]), col, outline)


## Two-segment legs in a diagonal gait. `at` lists hip offsets along the
## facing; legs swing with the walk cycle and stand still when it stops.
func _legs(p: Pen, f: Vector2, at: Array, wide: float, reach: float, w: float, col: Color, rate := 1.0) -> void:
	var s := f.orthogonal()
	for i in at.size():
		for sgn in [-1.0, 1.0]:
			var ph: float = _stride * rate + (PI if (i % 2 == 0) == (sgn > 0.0) else 0.0)
			var hip: Vector2 = f * float(at[i]) + s * sgn * wide
			var foot: Vector2 = hip + s * sgn * reach * 0.7 + f * sin(ph) * reach * 0.6 * _move
			p.limb(hip, foot, col, w)


## Membrane wing (bat, wyvern, manticore): arm bones from shoulder to
## wrist, fingers fanning back, skin between. `span` folds it (1 open).
func _membrane(p: Pen, shoulder: Vector2, out: Vector2, back: Vector2, length: float, span: float, skin: Color, bone: Color, bw: float) -> void:
	var elbow := shoulder + (out * 0.55 + back * -0.25).normalized() * length * 0.45 * span
	var wrist := elbow + (out + back * -0.15).normalized() * length * 0.5 * span
	var tips := [
		wrist + (out * 0.7 + back * 0.3).normalized() * length * 0.45 * span,
		wrist + (out * 0.2 + back * 0.8).normalized() * length * 0.55 * span,
		wrist + (back * 0.85 - out * 0.15).normalized() * length * 0.62 * span,
	]
	var root_back := shoulder + back * length * 0.42
	var skin_pts := PackedVector2Array([shoulder, elbow, wrist, tips[0]])
	# Scalloped trailing edge between the fingers.
	skin_pts.append((tips[0] + tips[1]) * 0.5 - (out * 0.2 - back * 0.1) * length * 0.08)
	skin_pts.append(tips[1])
	skin_pts.append((tips[1] + tips[2]) * 0.5 - back * length * 0.05)
	skin_pts.append(tips[2])
	skin_pts.append((tips[2] + root_back) * 0.5 - back * length * 0.06)
	skin_pts.append(root_back)
	p.poly(skin_pts, skin, 1.4)
	p.quad(shoulder, elbow, bw, bone)
	p.quad(elbow, wrist, bw * 0.9, bone)
	for tip in tips:
		p.quad(wrist, tip, bw * 0.55, bone)
	p.circle(wrist, bw * 0.75, bone, 10)
	p.tri(wrist - out * 1.5, wrist + out * 4.5 - back * 1.0, wrist + back * 1.5, Palette.OUTLINE)  # the thumb claw


func _draw_slime(p: Pen, t: float, f: Vector2) -> void:
	var col := color
	var s := f.orthogonal()
	var breath := sin(t * 3.0) * 0.04
	var gather := _ease("gather", _wk(0.6) if state == "wind" else 0.0, 14.0)
	var sq := Vector2(1.0 + breath + 0.22 * gather, 1.0 - breath - 0.2 * gather)
	if state == "pounce":
		sq = Vector2(0.86, 1.14)
	var wob := 0.04 + 0.05 * gather + 0.03 * _move
	var base := Vector2(0, radius * 0.12 * gather)
	p.poly(Draw.blob(base, radius, t, wob, sq, 16), col.darkened(0.32))
	p.fill_poly(Draw.blob(base + Vector2(-1.2, -1.8), radius * 0.82, t + 0.3, wob, sq, 16), col)
	p.circle(base + Vector2(1.8, 2.8), radius * 0.34, Color(col.darkened(0.3), 0.55))  # the core
	for i in 2:
		var bt := fmod(t * 0.45 + i * 0.5, 1.0)
		p.circle(base + Vector2(-3.0 + i * 6.0, 4.0 - bt * 9.0), 1.0 + bt * 1.2, Color(col.lightened(0.45), 0.55 * sin(bt * PI)))
	p.circle(base + Vector2(-radius * 0.38, -radius * 0.42), radius * 0.22, Color(1, 1, 1, 0.5))
	p.circle(base + Vector2(-radius * 0.16, -radius * 0.6), radius * 0.08, Color(1, 1, 1, 0.65))
	# Eyes that follow you, narrowing as it gathers to hop.
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = base + f * radius * 0.32 + s * sgn * radius * 0.32 + Vector2(0, -2.0)
		p.oval(e, Vector2(3.0, 3.0 - 1.2 * gather), 0.0, Palette.OUTLINE, 12)
		p.oval(e, Vector2(2.3, 2.3 - 1.0 * gather), 0.0, C_EYE, 12)
		p.circle(e + f * 1.0, 1.2, Palette.OUTLINE, 10)


func _draw_archer(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var cloak := color
	var bob := Vector2(0, -absf(sin(_stride)) * 1.2 * _move)
	var pull := _ease("pull", 1.0 if aim_dir != Vector2.ZERO else 0.0, 12.0)
	# Cloak tail and quiver behind.
	var sway := s * sin(t * 2.0) * 1.5
	p.poly(PackedVector2Array([s * radius * 0.8 - f * 2.0, -f * (radius + 5.0) + sway + s * 4.0, -f * (radius + 6.5) + sway, -f * (radius + 5.0) + sway - s * 4.0, -s * radius * 0.8 - f * 2.0]), cloak.darkened(0.3))
	p.limb(-f * 4.0 + s * 5.0, -f * 13.0 + s * 8.5, Palette.WOOD.darkened(0.3), 4.0)
	for i in 3:
		var nock := -f * 13.0 + s * (6.6 + i * 1.6)
		p.tri(nock, nock - f * 4.0 + s * 1.2, nock - f * 4.0 - s * 0.6, C_BONE)
	p.ball(-f * 1.5 + bob, radius, cloak)
	# Arms: one holds the bow out, the other draws the string back.
	var grip := f * (radius + 3.0) - s * 3.0 + bob
	var hand := grip - f * (2.0 + 8.0 * pull) + s * 1.5
	p.limb(-s * radius * 0.65 + bob, grip, cloak.darkened(0.12), 3.2)
	p.limb(s * radius * 0.65 + bob, hand, cloak.darkened(0.12), 3.2)
	p.ball(f * 2.0 + bob, 6.5, cloak.darkened(0.3))  # hood
	p.circle(f * 5.0 + bob, 2.8, Color(0.08, 0.07, 0.07))  # the dark of the hood
	_glow.circle(f * 5.6 + s * 1.2 + bob, 0.8, C_EYE_GLOW, 8)
	_glow.circle(f * 5.6 - s * 1.2 + bob, 0.8, C_EYE_GLOW, 8)
	# The bow bends as it's drawn.
	var a := grip - f * (4.0 + 2.0 * pull) + s * (11.0 - pull)
	var b := grip - f * (4.0 + 2.0 * pull) - s * (11.0 - pull)
	p.tube(PackedVector2Array([a, grip + s * 5.5, grip, grip - s * 5.5, b]), PackedFloat32Array([1.6, 2.6, 3.0, 2.6, 1.6]), Palette.WOOD, true, false)
	p.quad(a, hand, 1.0, C_STRING)
	p.quad(hand, b, 1.0, C_STRING)
	if pull > 0.3:
		p.limb(hand, grip + f * 7.0, Palette.WOOD.lightened(0.2), 1.3)
		p.tri(grip + f * 11.0, grip + f * 6.5 + s * 2.2, grip + f * 6.5 - s * 2.2, Palette.STEEL)
	p.circle(hand, 1.8, Palette.CLIMBER_SKIN.darkened(0.2), 10)


func _draw_knight(p: Pen, t: float, f: Vector2) -> void:
	var armor := color
	var s := f.orthogonal()
	# Feet step under the body.
	var step := sin(_stride) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 5.5 + f * (step * sgn * 4.5 + 2.0), 3.6, armor.darkened(0.45))
	# Sword: held low; raised over the shoulder for the slash, cocked back
	# for the lunge, thrust forward in it. Eased fast, so it swings.
	var ang := -1.1
	var gx := radius * 0.9
	var gy := 3.0
	var rate := 14.0
	if state == "wind_slash":
		var k := _wk(0.6)
		ang = -1.1 - 1.4 * k
		gx = radius * (0.9 - 0.3 * k)
		gy = 3.0 - 7.0 * k
	elif state == "wind_lunge":
		ang = -0.2
		gx = radius * 0.55
		gy = -6.0 * _wk(0.7)
	elif state == "lunge":
		ang = -0.1
		gx = radius * 0.4
		gy = 10.0
		rate = 30.0
	elif state == "recover" and open_t > 0.0:
		ang = 0.7  # the follow-through
		gx = radius * 0.2
		gy = 9.0
		rate = 24.0
	ang = _ease("sword_a", ang, rate)
	gx = _ease("sword_x", gx, rate)
	gy = _ease("sword_y", gy, rate)
	var grip := -s * gx + f * gy
	# Body: armoured plates, a seam down the back.
	p.ball(Vector2.ZERO, radius, armor)
	p.arc(Vector2.ZERO, radius * 0.62, f.angle() + 0.9, f.angle() + TAU - 0.9, 1.5, armor.darkened(0.3), 14)
	p.ball(s * radius * 0.78, 5.5, armor.lightened(0.08))
	p.ball(-s * radius * 0.78, 5.5, armor.lightened(0.08))
	# Sword arm and sword.
	p.limb(-s * radius * 0.72, grip, armor.darkened(0.2), 3.6)
	_sword(p, grip, f.rotated(ang), 22.0)
	# Helmet with a visor slit facing you; it glows red as it winds up.
	p.ball(f * 2.0, 7.5, armor.darkened(0.1))
	p.quad(f * 6.0 + s * 3.5, f * 6.0 - s * 3.5, 2.0, Palette.OUTLINE)
	var eye := _ease("eye", 1.0 if state.begins_with("wind") else 0.0, 12.0)
	if eye > 0.02:
		_glow.quad(f * 6.0 + s * 2.6, f * 6.0 - s * 2.6, 1.1, Color(1.0, 0.4, 0.3, eye))
	# Plume trailing behind the helmet.
	var plume_sway := s * sin(t * 3.0) * 2.0
	p.tube(PackedVector2Array([-f * 1.5, -f * 6.5 + plume_sway * 0.5 + s, -f * 12.0 + plume_sway + s * 2.0]), PackedFloat32Array([2.8, 2.6, 1.4]), Palette.PLUME)
	# Shield on the off hand.
	var sc := s * (radius * 0.85) + f * 6.0
	var shield := PackedVector2Array()
	for i in 9:
		shield.append(sc + Vector2.from_angle(f.angle() - 1.0 + 2.0 * float(i) / 8.0) * 7.0 - f * 3.0)
	for i in 9:
		shield.append(sc + Vector2.from_angle(f.angle() + 1.0 - 2.0 * float(i) / 8.0) * 3.0 - f * 3.0)
	p.poly(shield, Color(0.45, 0.3, 0.22))
	p.arc(sc - f * 3.0, 5.6, f.angle() - 0.9, f.angle() + 0.9, 1.2, Palette.STEEL.darkened(0.25), 8)
	p.circle(sc + f * 1.5, 1.6, Palette.STEEL, 10)


func _draw_bat(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var o := Vector2(0, sin(t * 6.0) * 2.0 - 10.0)  # flies above the floor
	var span := 0.75 + 0.25 * sin(_flap)  # wings seen from above shorten as they beat
	var back := -f
	var spread := 1.0
	if state == "wind":
		span = 1.0 + 0.04 * sin(t * 40.0)  # wings wide, trembling
		spread = 1.1
	elif state == "swoop":
		span = 0.7
		back = (-f * 1.6).normalized()
	span = _ease("span", span, 30.0)
	var pull := _ease("swept", 1.0 if state == "swoop" else 0.0, 16.0)
	for sgn in [-1.0, 1.0]:
		var out: Vector2 = (s * sgn * spread - f * 0.35 * pull).normalized()
		_membrane(p, o + s * sgn * 2.5, out, back, 16.0, span, color.darkened(0.3), color.darkened(0.55), 1.2)
	p.oval(o, Vector2(6.5, 5.5), f.angle(), Palette.OUTLINE, 14)
	p.egg(o, Vector2(5.0, 4.2), f.angle(), color, false)
	for sgn in [-1.0, 1.0]:
		p.poly(PackedVector2Array([o + f * 2.0 + s * sgn * 1.2, o + f * 6.5 + s * sgn * 3.6, o + f * 1.5 + s * sgn * 4.0]), color.darkened(0.15), 1.0)
		_glow.circle(o + f * 3.4 + s * sgn * 1.7, 1.1, Color(1.0, 0.35, 0.3), 8)
	if state in ["wind", "swoop"]:
		p.tri(o + f * 4.8 + s * 1.0, o + f * 6.8 + s * 0.6, o + f * 4.8, C_EYE)
		p.tri(o + f * 4.8 - s * 1.0, o + f * 6.8 - s * 0.6, o + f * 4.8, C_EYE)


func _draw_thunderling(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var sp := _ease("spark", _wk(0.9) if state == "wind_spark" else 0.0, 10.0)
	_spin += _dt * (1.6 + 5.0 * sp)
	var r := radius * (1.0 + 0.15 * sp) * (1.0 + 0.03 * sin(t * 4.0))
	var star := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + _spin
		star.append(Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.58))
		inner.append(Vector2(-1.0, -1.2) + Vector2.from_angle(a) * (r * 0.72 if i % 2 == 0 else r * 0.42))
	p.poly(star, color.darkened(0.2).lerp(color, sp))
	p.fill_poly(inner, color.lerp(color.lightened(0.35), sp))
	_glow.circle(Vector2.ZERO, r * 0.62, Color(1.0, 1.0, 0.75, 0.12 + 0.15 * sp))
	_glow.circle(Vector2.ZERO, r * 0.34, Color(1.0, 1.0, 0.9, 0.55 + 0.4 * sp))
	for sgn in [-1.0, 1.0]:
		p.circle(f * 2.6 + s * sgn * 2.6 + Vector2(0, -1.0), 1.6, Palette.OUTLINE, 10)
	# Crackling arcs that run round it, faint at rest, bright as it sparks.
	var n := 1 if sp < 0.05 else 3
	for i in n:
		var a0 := -_spin * 1.7 + i * TAU / 3.0
		var prev := Vector2.from_angle(a0) * r
		for k in 3:
			var next := Vector2.from_angle(a0 + 0.3 * (k + 1)) * (r + 1.0 + (2.5 if k % 2 == 0 else 0.5) * (0.6 + 0.4 * sin(t * 23.0 + i * 2.0 + k)))
			_glow.quad(prev, next, 1.3, Color(1.0, 1.0, 0.8, 0.35 + 0.65 * sp))
			prev = next


func _draw_lurker(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	if state == "sub":
		# Only a dark shape, ripples and two eyes show above the water.
		p.oval(Vector2.ZERO, Vector2(radius * 1.2, radius * 0.6), f.angle(), Color(0.05, 0.12, 0.16, 0.35))
		for k in 2:
			var ph := fmod(t * 0.8 + k * 0.5, 1.0)
			p.arc(Vector2.ZERO, 8.0 + ph * 18.0, 0.0, TAU, 1.5, Color(C_WATER, 0.5 * sin(ph * PI)), 20)
		_glow.circle(f * 4.0 + s * 3.0, 1.4, Color(0.9, 1.0, 0.7, 0.8), 8)
		_glow.circle(f * 4.0 - s * 3.0, 1.4, Color(0.9, 1.0, 0.7, 0.8), 8)
		return
	var rise := 1.0
	if state == "rise":
		rise = clampf(1.0 - state_t / 0.35, 0.2, 1.0)
	elif state == "sink":
		rise = clampf(state_t / 0.35, 0.2, 1.0)
	var wave := 0.5 + 0.5 * _move
	p.arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 2.0, Color(C_WATER, 0.35), 24)
	p.arc(Vector2.ZERO, radius + 7.0 + sin(t * 3.0), 0.0, TAU, 1.2, Color(C_WATER, 0.18), 24)
	# A sinuous eel-fish: the body is one tube along the spine.
	var spine := PackedVector2Array()
	var w := PackedFloat32Array()
	var widths := [10.0, 17.0, 16.0, 11.0, 6.0, 2.5]
	for k in 6:
		var u := k / 5.0
		spine.append((f * radius * (1.3 - 2.9 * u) + s * sin(t * 6.0 - u * 4.0) * 3.5 * u * wave) * rise)
		w.append(widths[k] * rise)
	for sgn in [-1.0, 1.0]:  # side fins
		var root: Vector2 = spine[2]
		p.poly(PackedVector2Array([root + s * sgn * 5.0 * rise, root + (s * sgn * 13.0 - f * 6.0 + f * sin(t * 5.0 + sgn) * 1.5) * rise, root - f * 6.0 * rise]), color.darkened(0.25), 1.2)
	var tail: Vector2 = spine[5]
	var td := (spine[5] - spine[4]).normalized()
	p.poly(PackedVector2Array([tail, tail + (td * 7.0 + td.orthogonal() * 5.0) * rise, tail + td * 4.0 * rise, tail + (td * 7.0 - td.orthogonal() * 5.0) * rise]), color.darkened(0.25), 1.2)
	p.tube(spine, w, color)
	for k in range(1, 4):
		p.circle(spine[k] + Vector2(-0.5, -0.8), 1.3 * rise, Color(color.lightened(0.35), 0.8), 8)
	# Jaws, open while it lunges.
	var open := _ease("jaw", 5.0 if state in ["wind", "lunge"] else 1.5, 16.0)
	var head: Vector2 = spine[0]
	p.tri(head + f * 3.0 * rise + s * open, head - f * 4.0 * rise, head + f * 3.0 * rise - s * open, Palette.OUTLINE)
	if open > 2.5:
		p.tri(head + f * 2.0 * rise + s * (open - 1.0), head + f * 0.5 * rise + s * (open - 2.0), head + f * 1.0 * rise + s * (open - 0.5), C_EYE)
		p.tri(head + f * 2.0 * rise - s * (open - 1.0), head + f * 0.5 * rise - s * (open - 2.0), head + f * 1.0 * rise - s * (open - 0.5), C_EYE)
	_glow.circle(head - f * 3.5 * rise + s * 3.6 * rise, 1.7, Color(0.9, 1.0, 0.7), 8)
	_glow.circle(head - f * 3.5 * rise - s * 3.6 * rise, 1.7, Color(0.9, 1.0, 0.7), 8)


func _draw_shellback(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var bash := _ease("bash", _wk(0.7) if state == "wind_bash" else 0.0, 12.0)
	# Stubby legs paddle as it walks.
	for sgn in [-1.0, 1.0]:
		for k in 2:
			var ph: float = _stride * 1.4 + k * PI + (PI if sgn > 0.0 else 0.0)
			var root: Vector2 = s * sgn * radius * 0.6 + f * (k * 9.0 - 5.0)
			p.limb(root, root + s * sgn * radius * 0.5 + f * (k * 3.0 - 2.0 + sin(ph) * 2.5 * _move), color.darkened(0.3), 3.6)
	p.tri(-f * radius * 0.8 + s * 2.5, -f * radius * 1.2, -f * radius * 0.8 - s * 2.5, color.darkened(0.3))  # tail
	# The head pulls in as it braces for the bash.
	var head := f * radius * (0.92 - 0.25 * bash) + f * sin(t * 1.6) * 0.8
	p.ball(head, 5.6, color.lightened(0.15))
	p.circle(head + f * 2.6 + s * 2.4, 1.2, Palette.OUTLINE, 8)
	p.circle(head + f * 2.6 - s * 2.4, 1.2, Palette.OUTLINE, 8)
	# The shell: a domed oval of plates, its front rim armoured.
	var c := f * 2.0 * bash
	var rad := Vector2(radius, radius * 0.86)
	p.egg(c, rad, f.angle(), color.darkened(0.08))
	var plate := color.lightened(0.08)
	p.oval(c + Vector2(-1.0, -1.2), Vector2(radius * 0.36, radius * 0.32), f.angle(), color.darkened(0.35), 14)
	p.oval(c + Vector2(-1.4, -1.7), Vector2(radius * 0.3, radius * 0.26), f.angle(), plate, 14)
	for i in 6:
		var d := Vector2.from_angle(f.angle() + TAU * i / 6.0 + PI / 6.0)
		var at := c + Vector2(d.x * rad.x, d.y * rad.x) * 0.6 + Vector2(-0.8, -1.0)
		p.circle(at, radius * 0.27, color.darkened(0.3), 12)
		p.circle(at + Vector2(-0.5, -0.7), radius * 0.21, plate, 12)
	_glow.arc(c, radius + 3.0, f.angle() - 1.0, f.angle() + 1.0, 2.0, Color(0.85, 0.9, 1.0, 0.55), 12)


func _draw_cinder(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var spit := _ease("spit", _wk(0.6) if state == "wind_spit" else 0.0, 12.0)
	var r := radius * (1.0 + 0.15 * spit)
	p.poly(_flame(Vector2.ZERO, r, t, r * 0.9), color.darkened(0.15))
	_glow.fill_poly(_flame(Vector2(0, 0.5), r * 0.74, t + 0.4, r * 0.7), Color(C_FLAME, 0.9))
	_glow.circle(Vector2(0, 1.5), r * 0.42, C_FLAME_CORE, 14)
	_glow.circle(f * 3.0 + s * 3.0, 1.6, Palette.OUTLINE, 8)
	_glow.circle(f * 3.0 - s * 3.0, 1.6, Palette.OUTLINE, 8)
	if spit > 0.05:
		_glow.circle(f * 6.0, 1.0 + 2.2 * spit, Color(1.0, 1.0, 0.85, spit), 10)
	for i in 2:  # embers drifting up, fading in and out
		var ph := fmod(t * 0.9 + i * 0.5, 1.0)
		_glow.circle(Vector2(sin(t * 3.0 + i * 3.0) * 4.0, -r - 2.0 - ph * 10.0), 1.1, Color(C_EMBER, sin(ph * PI)), 8)


## A flame outline: a wavering circle drawn up into a tongue.
func _flame(at: Vector2, r: float, t: float, up: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var d := Vector2.from_angle(a)
		var tongue := pow(maxf(0.0, -d.y), 3.0) * up
		var rr := r * (1.0 + 0.1 * sin(t * 9.0 + i * 1.7)) + tongue * (0.85 + 0.15 * sin(t * 7.0))
		pts.append(at + d * rr + Vector2(sin(t * 5.0) * tongue * 0.15, 0.0))
	return pts


func _draw_smith(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var step := sin(_stride) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 6.5 + f * (step * sgn * 4.0 + 2.0), 4.2, C_LEATHER.darkened(0.3))
	# The hammer: raised behind the head in the wind-up, slammed down after.
	var raise := _ease("raise", _wk(0.85) if state == "wind_hammer" else 0.0, 22.0 if state != "wind_hammer" else 12.0)
	var shoulder := s * radius * 0.78
	var hand := shoulder + (f * radius * 0.95 - s * 3.0).lerp(-f * radius * 0.35 - s * 4.0, raise)
	var hdir := (hand - shoulder).normalized()
	var head := hand + hdir * 10.0
	# Broad shoulders, a leather apron, a soot-dark head.
	p.egg(Vector2.ZERO, Vector2(radius * 0.82, radius), f.angle(), color)
	var apron := PackedVector2Array([f * 3.0 + s * 7.0, f * (radius - 0.5) + s * 5.5, f * (radius + 1.0), f * (radius - 0.5) - s * 5.5, f * 3.0 - s * 7.0])
	p.poly(apron, C_LEATHER, 1.0)
	_glow.circle(f * (radius - 4.5), 1.8 + 0.4 * sin(t * 3.0), Color(1.0, 0.55, 0.22, 0.9), 10)
	# The off arm hangs at its side; the hammer arm swings.
	p.limb(-s * radius * 0.78, -s * radius * 0.7 + f * radius * 0.65, color.darkened(0.15), 4.6)
	p.ball(-s * radius * 0.7 + f * radius * 0.65, 3.4, C_SKIN.darkened(0.15))
	p.limb(shoulder, hand, color.darkened(0.15), 4.6)
	p.limb(hand - hdir * 3.0, head, C_LEATHER, 2.6)
	var hs := hdir.orthogonal()
	p.poly(PackedVector2Array([head - hdir * 3.5 + hs * 6.0, head + hdir * 3.5 + hs * 6.0, head + hdir * 3.5 - hs * 6.0, head - hdir * 3.5 - hs * 6.0]), C_IRON, 1.6)
	p.quad(head - hdir * 2.2 + hs * 5.0, head - hdir * 2.2 - hs * 5.0, 1.0, C_IRON.lightened(0.35))
	p.ball(hand, 3.4, C_SKIN.darkened(0.15))
	p.ball(f * 2.0, 6.6, C_SKIN.darkened(0.25))
	p.poly(PackedVector2Array([f * 4.0 + s * 4.2, f * 9.5, f * 4.0 - s * 4.2]), Color(0.2, 0.16, 0.14), 0.0)  # beard
	p.circle(f * 4.0 + s * 2.4, 1.1, Palette.OUTLINE, 8)
	p.circle(f * 4.0 - s * 2.4, 1.1, Palette.OUTLINE, 8)


func _draw_scorpling(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var leg := color.darkened(0.35)
	for k in 3:
		for sgn in [-1.0, 1.0]:
			var ph: float = _stride * 2.0 + k * 2.1 + (PI if sgn > 0.0 else 0.0)
			var root: Vector2 = s * sgn * radius * 0.45 + f * (3.0 - k * 3.5)
			var knee: Vector2 = root + s * sgn * 5.0 + f * 1.5
			var foot: Vector2 = knee + s * sgn * 2.5 - f * 2.5 + f * sin(ph) * 2.0 * (0.3 + _move)
			p.tube(PackedVector2Array([root, knee, foot]), PackedFloat32Array([1.8, 1.6, 0.9]), leg, true, false)
	# Pincers that open and close.
	var snap := 0.4 + 0.6 * absf(sin(t * 3.0))
	for sgn in [-1.0, 1.0]:
		var elbow: Vector2 = f * radius * 0.85 + s * sgn * radius * 0.85
		var claw: Vector2 = f * radius * 1.35 + s * sgn * radius * 0.5
		p.tube(PackedVector2Array([f * radius * 0.35 + s * sgn * 3.5, elbow, claw]), PackedFloat32Array([2.4, 2.2, 3.0]), color.darkened(0.15), true, false)
		var cd: Vector2 = (claw - elbow).normalized()
		var co: Vector2 = cd.orthogonal() * sgn
		p.poly(PackedVector2Array([claw - co * 2.0, claw + cd * 6.0 - co * (0.5 + snap), claw + cd * 2.0]), color.darkened(0.05), 1.1)
		p.poly(PackedVector2Array([claw + co * 2.0, claw + cd * 5.0 + co * (0.5 + snap), claw + cd * 1.5]), color.darkened(0.05), 1.1)
	p.egg(-f * radius * 0.5, Vector2(radius * 0.62, radius * 0.66), f.angle(), color.darkened(0.08))
	p.egg(f * 1.5, Vector2(radius * 0.72, radius * 0.6), f.angle(), color)
	p.circle(f * (radius * 0.55 + 1.5) + s * 1.6, 0.9, Palette.OUTLINE, 8)
	p.circle(f * (radius * 0.55 + 1.5) - s * 1.6, 0.9, Palette.OUTLINE, 8)
	# The tail curls over the back and strikes forward on the sting.
	var strike := _ease("strike", _wk(0.5) if state == "wind_sting" else 0.0, 14.0)
	var prev := Vector2.ZERO
	for k in 6:
		var u := float(k) / 5.0
		var at := -f * radius * (1.0 - u * 1.6) + s * sin(u * 3.0 + t * 1.5) * 2.5 - f * radius * 0.6 * (1.0 - strike) * u + f * radius * 1.4 * strike * u * u
		if k < 5:
			p.ball(at, 3.4 - u * 1.2, color.lightened(0.05 * k))
		else:
			var dir := (at - prev).normalized()
			p.poly(PackedVector2Array([at - dir.orthogonal() * 2.2, at + dir * 4.5, at + dir.orthogonal() * 2.2]), C_VENOM, 1.1)
			_glow.circle(at + dir * 3.5, 1.0, Color(C_VENOM.lightened(0.3), 0.6 + 0.4 * strike), 8)
		prev = at


func _draw_ram(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var lower := _ease("lower", 1.0 if state in ["wind_charge", "charge"] else 0.0, 10.0)
	_legs(p, f, [radius * 0.45, -radius * 0.55], radius * 0.45, 7.0, 4.0, color.darkened(0.45), 1.3)
	var body := -f * (2.0 + 2.0 * lower)
	p.ball(body, radius, color)
	# Lumpy stone fleece: a ring of rough tufts on its back.
	for i in 7:
		var d := Vector2.from_angle(TAU * i / 7.0 + 0.3)
		var at := body + d * radius * 0.52 + Vector2(-1.0, -1.5)
		p.circle(at, radius * 0.3, color.darkened(0.22), 12)
		p.circle(at + Vector2(-0.6, -0.8), radius * 0.24, color.lightened(0.08), 12)
	p.quad(body - s * 6.0 - f * 3.0, body + s * 1.0 + f * 1.0, 1.1, color.darkened(0.35))
	p.quad(body + s * 1.0 + f * 1.0, body + s * 4.0 - f * 2.0, 1.1, color.darkened(0.35))
	# The head drops low before a charge, horns forward.
	var head := f * (radius * 0.72 + 5.0 * lower)
	p.ball(head, 6.8, color.darkened(0.12))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = head + s * sgn * 4.5 - f * 1.5
		_horn(p, root, s * sgn, -f, 9.0, 4.4, C_HORN)
	p.circle(head + f * 3.2 + s * 2.4, 1.3, Palette.OUTLINE, 8)
	p.circle(head + f * 3.2 - s * 2.4, 1.3, Palette.OUTLINE, 8)
	if lower > 0.3:  # snorting
		for i in 2:
			var ph := fmod(t * 2.5 + i * 0.5, 1.0)
			p.circle(head + f * (7.0 + ph * 6.0) + s * (i * 2.0 - 1.0) * (2.0 + ph * 3.0), 1.5 + ph * 2.0, Color(0.85, 0.85, 0.8, 0.4 * sin(ph * PI) * lower), 10)


func _draw_wisp(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var col := color
	var core := C_FAMILIAR_CORE if kind == "familiar" else C_FLAME_CORE
	var gather := _ease("gather", _wk(0.45) if state == "wind" else 0.0, 12.0)
	var k := (0.93 + 0.07 * sin(t * 9.0)) * (1.0 - 0.15 * gather)
	var r := radius * k
	var trail := -velocity.normalized() if velocity.length() > 20.0 else Vector2(0, 1)
	var tr := _ease("trail_x", trail.x, 6.0)
	var ty := _ease("trail_y", trail.y, 6.0)
	var back := Vector2(tr, ty).normalized() if Vector2(tr, ty).length() > 0.1 else Vector2(0, 1)
	p.circle(Vector2.ZERO, r + 1.6, Color(Palette.OUTLINE, 0.45), 18)  # a dim rim so it reads on pale floors
	_glow.circle(Vector2.ZERO, radius * 1.7, Color(col, 0.1), 20)
	_glow.circle(Vector2.ZERO, radius * 1.2, Color(col, 0.2), 18)
	for i in 4:  # a soft tail of flame
		var u := (i + 1) / 4.0
		_glow.circle(back * radius * (0.6 + u * 1.2) + back.orthogonal() * sin(t * 6.0 + u * 4.0) * 2.5, r * (0.75 - u * 0.5), Color(col, 0.75 - u * 0.4), 14)
	if kind == "familiar":  # little ears: a spirit, not a flame
		for sgn in [-1.0, 1.0]:
			_glow.tri(f * 2.0 + s * sgn * (r * 0.5) - f * 1.0, f * (r * 0.4) + s * sgn * (r + 2.5) - f * 3.0, f * 3.0 + s * sgn * (r * 0.9) - f * 2.0, col)
	if state == "swoop":
		_glow.oval(Vector2.ZERO, Vector2(r * 1.3, r * 0.8), aim_dir.angle(), col, 18)
	else:
		_glow.circle(Vector2.ZERO, r, col, 18)
	_glow.circle(Vector2(-1.0, -1.5), r * 0.55, core.lerp(Color.WHITE, gather), 14)
	_glow.circle(f * 2.5 + s * 2.2, 1.3, Color(0.25, 0.12, 0.05) if kind != "familiar" else Color(0.1, 0.2, 0.35), 8)
	_glow.circle(f * 2.5 - s * 2.2, 1.3, Color(0.25, 0.12, 0.05) if kind != "familiar" else Color(0.1, 0.2, 0.35), 8)
	for i in 3:
		_glow.circle(Vector2.from_angle(t * 5.0 + TAU * i / 3.0) * radius * 1.25, 1.4, Color(col, 0.8), 8)


func _draw_bloomcap(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var k := _wk(0.9) if state == "wind_lob" else 0.0
	var swell := _ease("swell", 1.0 + 0.2 * k, 10.0) * (1.0 + 0.03 * sin(t * 2.0))
	for i in 5:  # roots gripping the floor
		var d := Vector2.from_angle(TAU * i / 5.0 + 0.6)
		p.tube(PackedVector2Array([d * 4.0 + Vector2(0, 6), d * 10.0 + Vector2(0, 8), d * 15.0 + Vector2(0, 9) + d.orthogonal() * 2.0]), PackedFloat32Array([3.0, 2.2, 1.0]), C_LEATHER.darkened(0.1), true, false)
	p.egg(Vector2(0, 4.0), Vector2(5.5, 7.0), 0.0, C_STALK)
	var cap := Vector2(0, -4.0)
	p.oval(cap + Vector2(0, 2.5), Vector2(radius * swell + 1.0, radius * 0.62 * swell), 0.0, color.darkened(0.5), 24)  # gills under the rim
	p.ball(cap, radius * swell, color)
	for i in 5:
		var at := cap + Vector2.from_angle(TAU * i / 5.0 + 0.4) * radius * 0.55 * swell
		p.circle(at, 2.3, C_CAP_SPOT, 10)
		if k > 0.02:
			_glow.circle(at, 1.0 + 1.3 * k, Color(1.0, 0.7, 0.3, k), 8)
	# Eyes peeking from under the rim, toward you.
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = cap + f * radius * 0.62 * swell + s * sgn * 3.2 + Vector2(0, 2.0)
		p.circle(e, 1.9, Palette.OUTLINE, 10)
		_glow.circle(e, 1.0, Color(1.0, 0.75, 0.35), 8)
	if k > 0.0:  # spores rising, fading in and out
		for i in 4:
			var ph := fmod(t * 1.6 + i * 0.25, 1.0)
			_glow.circle(Vector2(sin(t * 3.0 + i * 2.0) * 6.0, -radius - 6.0 - ph * 16.0), 1.6, Color(1.0, 0.6, 0.25, 0.85 * sin(ph * PI) * minf(1.0, k * 3.0)), 8)


func _draw_thornhound(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var crouch := _ease("crouch", _wk(0.45) if state == "wind" else 0.0, 14.0)
	var leap := _ease("leap", 1.0 if state == "lunge" else 0.0, 18.0)
	var c := -f * 3.0 * crouch + f * 2.0 * leap
	var leg := color.darkened(0.3)
	var st := _stride * 1.5
	for sgn in [-1.0, 1.0]:
		for i in 2:
			var hip: Vector2 = c + f * (5.5 if i == 0 else -6.0) + s * sgn * 3.5
			var ph: float = st + (PI if (i == 0) == (sgn > 0.0) else 0.0)
			var foot: Vector2 = hip + s * sgn * (7.5 + 2.0 * crouch) + f * (sin(ph) * 4.5 * _move + (3.0 if i == 0 else -3.0) * leap)
			p.tube(PackedVector2Array([hip, (hip + foot) * 0.5 + s * sgn * 1.0, foot]), PackedFloat32Array([3.0, 2.4, 2.0]), leg, true, false)
	var tail_end := c - f * (radius * 1.9) + s * sin(t * 4.0) * 4.0
	p.tube(PackedVector2Array([c - f * radius * 1.0, c - f * radius * 1.45 + s * sin(t * 4.0 + 0.6) * 1.5, tail_end]), PackedFloat32Array([3.2, 2.2, 1.2]), color.darkened(0.1))
	p.tri(tail_end + s * 1.5, tail_end - (tail_end - c).normalized() * -4.0, tail_end - s * 1.5, C_THORN)
	p.egg(c, Vector2(radius * (1.35 + 0.1 * leap), radius * 0.72), f.angle(), color)
	for i in 4:  # thorns down its back
		var at := c - f * (radius * 0.85 - i * 5.5)
		p.poly(PackedVector2Array([at + s * 2.0, at - f * 4.5 + Vector2(0, -1.5), at - s * 2.0]), C_THORN, 1.0)
	var head := c + f * radius * 1.12
	for sgn in [-1.0, 1.0]:
		p.poly(PackedVector2Array([head + s * sgn * 2.0 - f * 1.0, head + s * sgn * 5.5 - f * 5.0, head + s * sgn * 4.5]), color.darkened(0.25), 1.0)
	p.ball(head, 5.6, color.lightened(0.08))
	var open := _ease("jaw", 1.0 if state in ["wind", "lunge"] else 0.0, 16.0)
	p.egg(head + f * 4.5, Vector2(3.6, 2.6 + open * 0.8), f.angle(), color.lightened(0.15), false)
	if open > 0.1:
		p.tri(head + f * 8.0 + s * 2.2 * open, head + f * 4.0, head + f * 8.0 - s * 2.2 * open, Palette.OUTLINE)
	p.circle(head + f * 7.6, 1.2, Palette.OUTLINE, 8)
	_glow.circle(head + f * 2.0 + s * 2.4, 1.2, C_EYE_GLOW, 8)
	_glow.circle(head + f * 2.0 - s * 2.4, 1.2, C_EYE_GLOW, 8)


func _draw_mongrel(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	_legs(p, f, [radius * 0.5, -radius * 0.5], radius * 0.5, 7.0, 4.2, color.darkened(0.35), 1.2)
	# Quills on its back, raised and spread before it throws them.
	var bristle := _ease("bristle", 1.0 if state == "wind_quills" else 0.0, 12.0)
	for i in 7:
		var a := f.angle() + PI + (float(i) - 3.0) * (0.28 + 0.08 * bristle) + sin(t * 2.0 + i) * 0.03
		var root := Vector2.from_angle(a) * radius * 0.55
		var tip := root + Vector2.from_angle(a) * (8.0 + 6.0 * bristle)
		p.limb(root, tip, C_QUILL, 1.6)
		p.circle(tip, 1.0, Palette.OUTLINE, 8)
	p.ball(Vector2.ZERO, radius, color)
	# Patches of different hides, stitched together.
	p.oval(s * 5.0 - f * 3.0 + Vector2(-0.5, -0.5), Vector2(radius * 0.5, radius * 0.42), 0.6, Color(0.45, 0.35, 0.3), 16)
	p.oval(-s * 4.5 + f * 1.5 + Vector2(-0.5, -0.5), Vector2(radius * 0.42, radius * 0.36), -0.4, Color(0.72, 0.62, 0.52), 16)
	var a0 := f * radius * 0.75 - s * 2.0
	var a1 := -f * radius * 0.75 + s * 2.0
	p.quad(a0, a1, 1.0, Color(0.2, 0.15, 0.12))
	for i in 4:
		var at := a0.lerp(a1, (i + 0.5) / 4.0)
		var d := (a1 - a0).normalized().orthogonal()
		p.quad(at + d * 2.0, at - d * 2.0, 0.9, Color(0.2, 0.15, 0.12))
	# A mismatched head: one ear floppy, one pointed, one eye red.
	var head := f * radius * 0.9
	p.oval(head + s * 4.5 - f * 1.0, Vector2(2.4, 4.0), f.angle() + 0.5, color.darkened(0.3), 12)
	p.poly(PackedVector2Array([head - s * 2.0 - f * 1.0, head - s * 6.5 - f * 5.0, head - s * 5.5 + f * 0.5]), Color(0.72, 0.62, 0.52), 1.0)
	p.ball(head, 6.6, color.lightened(0.05))
	var open := _ease("jaw", _wk(0.6) if state == "wind_bite" else 0.0, 14.0)
	p.tri(head + f * 6.0 + s * (1.0 + 2.5 * open), head + f * 3.0, head + f * 6.0 - s * (1.0 + 2.5 * open), Palette.OUTLINE)
	if open > 0.3:
		p.tri(head + f * 5.6 + s * 2.0, head + f * 4.0 + s * 1.2, head + f * 5.0 + s * 1.0, C_EYE)
		p.tri(head + f * 5.6 - s * 2.0, head + f * 4.0 - s * 1.2, head + f * 5.0 - s * 1.0, C_EYE)
	p.circle(head + f * 2.2 + s * 3.0, 1.6, Palette.OUTLINE, 8)
	p.circle(head + f * 2.2 - s * 3.0, 1.6, Palette.OUTLINE, 8)
	_glow.circle(head + f * 2.2 - s * 3.0, 1.1, Color(0.95, 0.3, 0.25), 8)


## A beast's glowing eye: dark socket, lit iris, a pupil.
func _beast_eye(p: Pen, at: Vector2, r: float, iris: Color, f: Vector2) -> void:
	p.circle(at, r + 1.0, Palette.OUTLINE, 12)
	_glow.circle(at, r, iris, 12)
	_glow.oval(at + f * r * 0.15, Vector2(r * 0.3, r * 0.75), f.angle(), Palette.OUTLINE, 10)


func _draw_gryphon(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	var lift_y := 0.0
	if state == "wind_dive":
		lift_y = -40.0 * _wk(0.75)
	elif state == "dive":
		lift_y = -40.0 * clampf(state_t / 0.28, 0.0, 1.0)
	var o := Vector2(0, lift_y)
	# Wing pose: raised forward for the rake, swept forward for the gale,
	# folded back in the dive.
	var fwd := _ease("wing_fwd", 0.5 if state == "wind_rake" else (0.8 if state == "wind_gale" else (-0.5 if state == "dive" else 0.0)), 10.0)
	var span := (0.82 + 0.18 * sin(_flap)) * _ease("wing_span", 0.7 if state == "dive" else 1.0, 10.0)
	# The lion's hindquarters, legs and tufted tail.
	var hips := o - f * R * 0.55
	_legs(p, f, [-R * 0.55], R * 0.45, 9.0, 5.0, color.darkened(0.25), 0.8)
	var sway := sin(t * 2.2)
	var tail := PackedVector2Array([hips - f * R * 0.35, hips - f * R * 0.8 + s * sway * 3.0, hips - f * R * 1.2 + s * sway * 7.0, hips - f * R * 1.45 + s * (sway * 9.0 + 4.0)])
	p.tube(tail, PackedFloat32Array([5.0, 4.0, 3.0, 2.4]), color.darkened(0.1))
	p.ball(tail[3], 4.8, color.darkened(0.45))
	p.egg(hips, Vector2(R * 0.62, R * 0.55), f.angle(), color.darkened(0.06))
	# Great feathered wings.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = o + s * sgn * R * 0.4 + f * 3.0
		var out: Vector2 = (s * sgn + f * fwd).normalized()
		var wrist: Vector2 = root + (out + f * 0.15).normalized() * R * 1.15 * span
		for i in 5:  # primaries, longest at the tip
			var along: Vector2 = root.lerp(wrist, 0.45 + 0.14 * i)
			var dir: Vector2 = (out * (0.15 + 0.2 * i) - f * (1.0 - 0.15 * i)).normalized()
			_feather(p, along, dir, R * (0.85 + 0.12 * i) * span, 10.0, C_GRYPHON_WING.darkened(0.12 * (i % 2)), 1.2)
		var covert := PackedVector2Array([root + f * 3.0, wrist + f * 2.0, wrist - f * 8.0 - out * 2.0, root.lerp(wrist, 0.5) - f * 16.0, root - f * 12.0])
		p.poly(covert, C_GRYPHON_WING.lightened(0.1), 1.4)
		p.quad(root.lerp(wrist, 0.2) - f * 3.0, wrist - f * 3.0, 1.0, C_GRYPHON_WING.darkened(0.2))
	# Chest and the eagle's head.
	p.egg(o, Vector2(R * 0.78, R * 0.66), f.angle(), color)
	for i in 3:
		p.circle(o + f * R * 0.35 + s * (i - 1) * 5.5 + Vector2(-0.5, -0.5), 3.4, C_GRYPHON_HEAD.darkened(0.1), 12)
	# Talons: forward and spread for the rake.
	var rake := _ease("rake", _wk(0.55) if state == "wind_rake" else 0.0, 14.0)
	for sgn in [-1.0, 1.0]:
		var paw: Vector2 = o + f * R * (0.75 + 0.45 * rake) + s * sgn * R * 0.42
		p.limb(o + f * R * 0.3 + s * sgn * R * 0.38, paw, C_BEAK.darkened(0.25), 3.2)
		for c in 3:
			var cd: Vector2 = (f + s * sgn * (c - 1) * (0.5 + 0.4 * rake)).normalized()
			p.tri(paw + cd.orthogonal() * 1.2, paw + cd * (4.0 + 2.0 * rake), paw - cd.orthogonal() * 1.2, Palette.OUTLINE)
	var head := o + f * R * 0.72
	for sgn in [-1.0, 1.0]:  # ear tufts
		p.poly(PackedVector2Array([head + s * sgn * 4.0, head - f * 12.0 + s * sgn * 8.0, head - f * 3.0 + s * sgn * 9.0]), C_GRYPHON_HEAD.darkened(0.2), 1.2)
	p.ball(head, R * 0.42, C_GRYPHON_HEAD)
	var gape := _ease("gape", 1.0 if state == "wind_gale" else 0.0, 12.0)
	var beak := head + f * R * 0.34
	p.poly(PackedVector2Array([beak + s * 4.5, beak + f * 7.0 + s * (1.0 + 2.0 * gape), beak + f * 11.0, beak + f * 7.0 - s * (1.0 + 2.0 * gape), beak - s * 4.5]), C_BEAK, 1.3)
	p.tri(beak + f * 8.5 + s * 1.2, beak + f * 11.0, beak + f * 8.5 - s * 1.2, C_BEAK.darkened(0.45))
	_beast_eye(p, head + f * 3.5 + s * 5.0, 2.1, C_EYE_GLOW, f)
	_beast_eye(p, head + f * 3.5 - s * 5.0, 2.1, C_EYE_GLOW, f)


func _draw_kraken(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	var slam := _ease("slam", _wk(0.9) if state == "wind_slam" else 0.0, 10.0)
	var ink := _ease("ink", _wk(0.55) if state == "wind_ink" else 0.0, 12.0)
	# Eight arms trailing behind and around; raised and coiled for a slam.
	for i in 8:
		var base_a := f.angle() + PI + (float(i) - 3.5) * 0.27
		var length := R * (1.6 + 0.15 * ((i * 5) % 3)) * (1.0 - 0.3 * slam)
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		for k in 8:
			var u := float(k) / 7.0
			var a := base_a + sin(t * 1.6 + i * 1.3 + u * 3.0) * (0.3 + 0.5 * slam) * u
			pts.append(-f * R * 0.35 + Vector2.from_angle(a) * (R * 0.45 + u * length))
			w.append(lerpf(15.0, 2.2, u))
		p.tube(pts, w, color.darkened(0.08))
		for k in range(2, 7, 2):
			p.circle(pts[k], w[k] * 0.16 + 0.4, C_SUCKER, 8)
	# Two feeding arms in front; one lashes out across the sweep.
	var sweep := _ease("sweep", _wk(0.7) if state == "wind_sweep" else 0.0, 12.0)
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		var lash: float = sweep if sgn > 0.0 else 0.0
		for k in 7:
			var u := float(k) / 6.0
			var curl: Vector2 = f * R * (0.4 + 0.6 * u) + s * sgn * R * (0.7 + 0.3 * u) + (f.rotated(sgn * (1.6 - 1.6 * u))) * sin(t * 2.0 + sgn) * 3.0 * u
			var reach: Vector2 = s * sgn * R * 0.6 + lunge_dir * (R * 0.5 + u * SWEEP_REACH * 0.6)
			pts.append(curl.lerp(reach, lash))
			w.append(lerpf(9.0, 2.0, u))
		p.tube(pts, w, color.darkened(0.12))
		for k in range(2, 6, 2):
			p.circle(pts[k], w[k] * 0.16 + 0.4, C_SUCKER, 8)
	# The mantle behind, swelling as it readies its ink; the head in front.
	var pulse := 1.0 + 0.04 * sin(t * 2.0) + 0.12 * ink
	p.egg(-f * R * 0.45, Vector2(R * 1.0, R * 0.78) * pulse, f.angle(), color)
	for i in 4:
		p.circle(-f * R * (0.2 + 0.25 * (i % 2)) + s * (i - 1.5) * R * 0.35 + Vector2(-1, -1), R * 0.1, color.darkened(0.2), 12)
	p.ball(f * R * 0.2, R * 0.72, color.lightened(0.05))
	p.tri(f * R * 0.85 + s * 4.0, f * R * 0.85 + f * 7.0, f * R * 0.85 - s * 4.0, Palette.OUTLINE)
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = f * R * 0.4 + s * sgn * R * 0.42
		p.circle(e, 8.4, Palette.OUTLINE, 18)
		_glow.circle(e, 7.0, Color(0.98, 0.9, 0.55), 18)
		_glow.oval(e + f * 1.0, Vector2(1.6, 4.8 * (1.0 - 0.4 * slam)), f.angle(), Palette.OUTLINE, 12)
		_glow.circle(e + Vector2(-2.0, -2.5), 1.4, Color(1, 1, 1, 0.8), 8)


func _draw_wyvern(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	var span := 0.8 + 0.2 * sin(_flap)
	# The tail lashes across in the tail sweep.
	var swing := _ease("swing", _wk(0.6) * 1.2 if state == "wind_tail" else 0.0, 12.0)
	var tail := PackedVector2Array()
	var tw := PackedFloat32Array()
	for k in 9:
		var u := float(k) / 8.0
		tail.append(-f * (R * 0.5 + u * R * 1.9) + s * sin(t * 2.5 + u * 3.0) * 7.0 * u + s * swing * u * R)
		tw.append(lerpf(10.0, 2.5, u))
	p.tube(tail, tw, color.darkened(0.15))
	var tip := tail[8]
	var td := (tail[8] - tail[7]).normalized()
	p.poly(PackedVector2Array([tip - td * 2.0, tip + td.orthogonal() * 5.0 + td * 2.0, tip + td * 9.0, tip - td.orthogonal() * 5.0 + td * 2.0]), color.darkened(0.4), 1.3)
	for k in range(1, 7, 2):
		var d := (tail[k + 1] - tail[k]).normalized()
		p.tri(tail[k] + d.orthogonal() * 2.0, tail[k] - d * 4.0, tail[k] - d.orthogonal() * 2.0, C_HORN.darkened(0.25))
	_legs(p, f, [-R * 0.25], R * 0.5, 9.0, 5.0, color.darkened(0.3), 0.7)
	# Membrane wings.
	for sgn in [-1.0, 1.0]:
		_membrane(p, s * sgn * R * 0.45 + f * 4.0, s * sgn, -f, R * 2.3, span, color.darkened(0.38), color.darkened(0.15), 2.4)
	p.egg(Vector2.ZERO, Vector2(R * 0.85, R * 0.68), f.angle(), color)
	for k in 4:  # spines down the back
		var at := -f * (R * 0.55 - k * R * 0.32)
		p.poly(PackedVector2Array([at + s * 2.5, at - f * 6.0 + Vector2(0, -1.0), at - s * 2.5]), C_HORN.darkened(0.15), 1.0)
	# Neck and head: drawn back while it breathes in, thrust forward to breathe.
	var breath := _ease("breath", _wk(0.8) if state == "wind_breath" else 0.0, 10.0)
	var head := f * R * (1.05 - 0.15 * breath) + s * sin(t * 1.4) * 2.0
	p.tube(PackedVector2Array([f * R * 0.3, f * R * 0.7 + s * sin(t * 1.4) * 1.0, head]), PackedFloat32Array([13.0, 10.0, 8.0]), color.lightened(0.04))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = head - f * 3.0 + s * sgn * 4.0
		p.tube(PackedVector2Array([root, root - f * 6.0 + s * sgn * 4.0, root - f * 11.0 + s * sgn * 4.5]), PackedFloat32Array([3.4, 2.4, 1.0]), C_HORN)
	p.egg(head, Vector2(R * 0.36, R * 0.3), f.angle(), color.lightened(0.08))
	p.egg(head + f * 6.0, Vector2(5.5, 4.2), f.angle(), color.lightened(0.12), false)
	p.circle(head + f * 10.0 + s * 1.6, 0.9, Palette.OUTLINE, 8)
	p.circle(head + f * 10.0 - s * 1.6, 0.9, Palette.OUTLINE, 8)
	_beast_eye(p, head + f * 2.0 + s * 4.6, 2.2, Color(1.0, 0.8, 0.3), f)
	_beast_eye(p, head + f * 2.0 - s * 4.6, 2.2, Color(1.0, 0.8, 0.3), f)
	if breath > 0.02:
		_glow.circle(head + f * R * 0.45, 3.0 + 5.0 * breath, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * breath), 16)
		_glow.circle(head + f * R * 0.45, 1.5 + 2.5 * breath, Color(C_FLAME_CORE, breath), 12)
	var embers := _ease("embers", _wk(0.6) if state == "wind_embers" else 0.0, 12.0)
	if embers > 0.02:
		for i in 3:
			_glow.circle(f * R * (0.35 + 0.18 * i) + s * sin(t * 6.0 + i) * 1.5, 1.6 + embers * 1.4, Color(C_EMBER, embers), 10)


func _draw_manticore(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	var span := 0.82 + 0.18 * sin(_flap)
	for sgn in [-1.0, 1.0]:
		_membrane(p, s * sgn * R * 0.35 - f * 2.0, s * sgn, -f, R * 1.75, span, C_BAT_WING, C_BAT_WING.darkened(0.3), 2.0)
	_legs(p, f, [R * 0.5, -R * 0.5], R * 0.5, 9.0, 5.5, color.darkened(0.2), 0.9)
	# The scorpion tail: segments arching over the back, poised forward for the spikes.
	var curl := _ease("curl", 1.0 if state == "wind_spikes" else 0.0, 8.0)
	var prev := Vector2.ZERO
	for k in 9:
		var u := float(k) / 8.0
		var at := -f * R * (0.7 + u * 1.3) + s * sin(t * 2.0 + u * 2.5) * 6.0 * u - f * R * u * u * (0.6 - curl * 2.0)
		if k < 8:
			p.ball(at, lerpf(6.5, 3.8, u), color.darkened(0.2 + 0.03 * (k % 2)))
		else:
			var dir := (at - prev).normalized()
			p.poly(PackedVector2Array([at - dir.orthogonal() * 4.5, at + dir * 9.0, at + dir.orthogonal() * 4.5]), C_VENOM, 1.4)
			for sgn in [-1.0, 1.0]:
				p.tri(at + dir.orthogonal() * sgn * 3.0, at + dir.orthogonal() * sgn * 8.0 - dir * 2.0, at + dir.orthogonal() * sgn * 2.0 + dir * 2.0, C_HORN)
			_glow.circle(at + dir * 7.0, 1.4 + curl, Color(C_VENOM.lightened(0.3), 0.5 + 0.5 * curl), 8)
		prev = at
	p.egg(-f * 2.0, Vector2(R * 0.95, R * 0.74), f.angle(), color)
	# The mane, flaring as it roars.
	var roar := _ease("roar", _wk(0.9) if state == "wind_roar" else 0.0, 10.0)
	var mane_at := f * R * 0.7
	for i in 14:
		var a := TAU * i / 14.0 + sin(t * 2.0 + i) * 0.04
		var d := Vector2.from_angle(a)
		p.poly(PackedVector2Array([mane_at + d.rotated(0.3) * R * 0.3, mane_at + d * R * (0.62 + 0.14 * roar + 0.05 * (i % 2)), mane_at + d.rotated(-0.3) * R * 0.3]), C_MANE.darkened(0.12 * (i % 2)), 1.2)
	# A raised paw for the claw swipe.
	var claw := _ease("claw", _wk(0.55) if state == "wind_claw" else 0.0, 14.0)
	if claw > 0.02:
		var paw := f * R * (0.6 + 0.6 * claw) - s * R * 0.65
		p.limb(-s * R * 0.5, paw, color.darkened(0.1), 6.0)
		for c in 3:
			var cd := (f + s * (c - 1) * 0.4).normalized()
			p.tri(paw + cd.orthogonal() * 1.4, paw + cd * 7.0 * claw, paw - cd.orthogonal() * 1.4, C_EYE)
	p.ball(mane_at, R * 0.38, color.lightened(0.1))
	p.egg(mane_at + f * 5.0, Vector2(4.6, 5.4), f.angle(), color.lightened(0.2), false)
	p.tri(mane_at + f * 7.5 + s * 2.0, mane_at + f * 9.5, mane_at + f * 7.5 - s * 2.0, Palette.OUTLINE)
	if roar > 0.05:
		p.oval(mane_at + f * 9.0, Vector2(1.5 + 3.0 * roar, 2.5 + 2.5 * roar), f.angle(), Color(0.25, 0.05, 0.05), 12)
		p.tri(mane_at + f * 8.5 + s * 2.0, mane_at + f * 11.0 + s * 1.5, mane_at + f * 8.5 + s * 1.0, C_EYE)
		p.tri(mane_at + f * 8.5 - s * 2.0, mane_at + f * 11.0 - s * 1.5, mane_at + f * 8.5 - s * 1.0, C_EYE)
	_beast_eye(p, mane_at + f * 2.5 + s * 4.5, 2.2, C_EYE_GLOW, f)
	_beast_eye(p, mane_at + f * 2.5 - s * 4.5, 2.2, C_EYE_GLOW, f)


func _draw_firebird(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	if state == "ashes":
		# A smouldering heap, glowing brighter as it's about to rise.
		var glow := clampf(1.0 - state_t / 2.2, 0.0, 1.0)
		p.egg(Vector2.ZERO, Vector2(R * 0.95, R * 0.62), 0.0, C_ASH)
		for i in 5:
			p.circle(Vector2.from_angle(TAU * i / 5.0 + 0.5) * R * 0.45 + Vector2(-1, -2), R * 0.25, C_ASH.lightened(0.08), 12)
		_glow.circle(Vector2.ZERO, R * (0.7 + 0.8 * glow), Color(1.0, 0.45, 0.15, 0.1 + 0.2 * glow), 24)
		for i in 8:
			var a := TAU * i / 8.0
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
			_glow.circle(Vector2.from_angle(a) * R * 0.5 * Vector2(1.0, 0.65), 2.5 + 1.5 * glow, Color(1.0, 0.45 + 0.35 * glow, 0.2, (0.3 + 0.6 * glow) * (0.6 + 0.4 * pulse)), 10)
		if glow > 0.6:
			_glow.arc(Vector2.ZERO, R * (0.3 + glow), 0.0, TAU, 2.5, Color(1.0, 0.7, 0.3, (glow - 0.6) * 2.0), 28)
		return
	var span := 0.8 + 0.2 * sin(_flap)
	var back := _ease("swept", 1.0 if state == "swoop" else (-0.4 if state == "wind_storm" else 0.0), 10.0)
	_glow.circle(Vector2.ZERO, R * 1.5, Color(1.0, 0.5, 0.2, 0.1), 24)
	# Tail plumes: three long streamers, each with a burning eye at its end.
	for i in 3:
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		for k in 7:
			var u := float(k) / 6.0
			pts.append(-f * R * (0.5 + u * (1.4 + 0.25 * (1 - absi(i - 1)))) + s * ((i - 1) * 6.0 * u + sin(t * 4.0 + u * 4.0 + i) * 4.0 * u))
			w.append(lerpf(6.0, 2.0, u))
		p.tube(pts, w, Color(1.0, 0.45, 0.15))
		_glow.circle(pts[6], 3.2, C_FLAME, 12)
		_glow.circle(pts[6], 1.5, C_FLAME_CORE, 10)
	# Flame-feathered wings, gold at the heart.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = s * sgn * R * 0.3 + f * 4.0
		var out: Vector2 = (s * sgn - f * back * 0.6).normalized()
		var wrist: Vector2 = root + out * R * 1.2 * span
		for i in 6:
			var along: Vector2 = root.lerp(wrist, 0.3 + 0.14 * i)
			var dir: Vector2 = (out * (0.2 + 0.18 * i) - f * (1.0 - 0.12 * i) + f * 0.2 * sin(t * 6.0 + i)).normalized()
			var length: float = R * (0.75 + 0.12 * i) * span
			_feather(p, along, dir, length, 7.0, Color(1.0, 0.42 + 0.04 * i, 0.15), 1.2)
			_glow.poly(PackedVector2Array([along + dir * length * 0.15, along + dir * length * 0.5 + dir.orthogonal() * 1.6, along + dir * length * 0.85, along + dir * length * 0.5 - dir.orthogonal() * 1.6]), Color(1.0, 0.78, 0.35, 0.85), 0.0)
		p.poly(PackedVector2Array([root + f * 2.0, wrist, wrist - f * 6.0, root - f * 8.0]), Color(1.0, 0.62, 0.22), 1.3)
	p.egg(Vector2.ZERO, Vector2(R * 0.7, R * 0.58), f.angle(), color)
	_glow.circle(Vector2(-1.0, -1.5), R * 0.3, Color(C_FLAME_CORE, 0.55), 16)
	var head := f * R * 0.72
	for i in 3:  # a crest of flame
		var d := (-f + s * (i - 1) * 0.5).normalized()
		_glow.poly(_flame_tongue(head + d * 3.0, d, 9.0 + 2.0 * sin(t * 7.0 + i), 3.0), Color(1.0, 0.7, 0.25, 0.9), 0.0)
	p.ball(head, R * 0.34, Color(1.0, 0.68, 0.3))
	p.poly(PackedVector2Array([head + f * R * 0.28 + s * 3.0, head + f * (R * 0.28 + 7.0), head + f * R * 0.28 - s * 3.0]), C_BEAK, 1.2)
	var storm := _ease("storm", _wk(0.9) if state == "wind_storm" else 0.0, 10.0)
	_beast_eye(p, head + f * 2.0 + s * 4.0, 1.9, Color(1.0, 1.0, 0.8).lerp(Color.WHITE, storm), f)
	_beast_eye(p, head + f * 2.0 - s * 4.0, 1.9, Color(1.0, 1.0, 0.8).lerp(Color.WHITE, storm), f)
	if storm > 0.02:
		_glow.circle(Vector2.ZERO, R * (1.0 + 0.5 * storm), Color(1.0, 0.6, 0.25, 0.18 * storm), 24)


func _flame_tongue(base: Vector2, dir: Vector2, length: float, width: float) -> PackedVector2Array:
	var sd := dir.orthogonal() * width
	return PackedVector2Array([base + sd, base + dir * length * 0.5 + sd * 0.6, base + dir * length, base + dir * length * 0.5 - sd * 0.6, base - sd])


func _draw_chimera(p: Pen, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var R := radius
	# The serpent tail: rears and opens its mouth for the spikes.
	var rear := _ease("rear", _wk(0.6) if state == "wind_spikes" else 0.0, 10.0)
	var tail := PackedVector2Array()
	var tw := PackedFloat32Array()
	for k in 9:
		var u := float(k) / 8.0
		tail.append(-f * R * (0.6 + u * 1.5 * (1.0 - 0.35 * rear)) + s * sin(t * 3.0 + u * 4.0) * 9.0 * u * (1.0 - 0.5 * rear))
		tw.append(lerpf(9.0, 4.0, u))
	p.tube(tail, tw, C_SERPENT)
	for k in range(1, 8, 2):
		p.circle(tail[k] + Vector2(-0.6, -0.8), tw[k] * 0.18, C_SERPENT.lightened(0.3), 8)
	var sh := tail[8]
	var sd := (tail[8] - tail[7]).normalized().lerp(f, rear).normalized()
	p.egg(sh + sd * 3.0, Vector2(6.5, 5.0), sd.angle(), C_SERPENT.lightened(0.05))
	if rear > 0.1:
		p.tri(sh + sd * 9.5 + sd.orthogonal() * 2.5 * rear, sh + sd * 5.0, sh + sd * 9.5 - sd.orthogonal() * 2.5 * rear, Palette.OUTLINE)
	else:
		var flick := maxf(0.0, sin(t * 2.3)) * 4.0
		p.quad(sh + sd * 8.5, sh + sd * (8.5 + flick), 0.9, Color(0.85, 0.25, 0.3))
	_glow.circle(sh + sd * 4.0 + sd.orthogonal() * 2.6, 1.0, Color(0.95, 0.3, 0.25), 8)
	_glow.circle(sh + sd * 4.0 - sd.orthogonal() * 2.6, 1.0, Color(0.95, 0.3, 0.25), 8)
	# Paws: forward for the maul.
	var maul := _ease("maul", _wk(0.55) if state == "wind_maul" else 0.0, 14.0)
	_legs(p, f, [-R * 0.5], R * 0.55, 9.0, 6.0, color.darkened(0.2), 0.9)
	for sgn in [-1.0, 1.0]:
		var hip: Vector2 = f * R * 0.4 + s * sgn * R * 0.55
		var paw: Vector2 = hip + f * (6.0 + 12.0 * maul) + s * sgn * 4.0 + f * sin(_stride * 0.9 + (PI if sgn > 0.0 else 0.0)) * 5.0 * _move
		p.limb(hip, paw, color.darkened(0.2), 6.0)
		if maul > 0.1:
			for c in 3:
				var cd: Vector2 = (f + s * (c - 1) * 0.4).normalized()
				p.tri(paw + cd.orthogonal() * 1.2, paw + cd * 6.0 * maul, paw - cd.orthogonal() * 1.2, C_EYE)
	p.egg(Vector2.ZERO, Vector2(R * 0.95, R * 0.78), f.angle(), color)
	# The goat's head on one side: lowered for the charge.
	var charge := _ease("goat", 1.0 if state in ["wind_charge", "charge"] else 0.0, 10.0)
	var goat := s * R * 0.58 + f * R * (0.45 + 0.35 * charge)
	p.tube(PackedVector2Array([s * R * 0.4, goat.lerp(s * R * 0.4, 0.4), goat]), PackedFloat32Array([9.0, 8.0, 7.0]), C_GOAT.darkened(0.1))
	p.egg(goat, Vector2(R * 0.3, R * 0.25), f.angle(), C_GOAT)
	p.tri(goat + f * 5.0 + s * 1.5, goat + f * 9.0 + s * 0.5, goat + f * 5.0 - s * 1.0, C_GOAT.darkened(0.35))  # beard
	for sgn in [-1.0, 1.0]:
		_horn(p, goat - f * 1.5 + s * sgn * 3.0, s * sgn, -f, 8.0, 3.6, C_HORN.darkened(0.1))
	p.circle(goat + f * 3.0 + s * 2.6, 1.1, Palette.OUTLINE, 8)
	p.circle(goat + f * 3.0 - s * 2.6, 1.1, Palette.OUTLINE, 8)
	# The lion's head and mane.
	var lion := -s * R * 0.2 + f * R * 0.75
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0 + sin(t * 1.5 + i) * 0.04)
		p.poly(PackedVector2Array([lion + d.rotated(0.32) * R * 0.28, lion + d * R * (0.55 + 0.05 * (i % 2)), lion + d.rotated(-0.32) * R * 0.28]), C_MANE.darkened(0.12 * (i % 2)), 1.2)
	p.ball(lion, R * 0.34, color.lightened(0.12))
	p.egg(lion + f * 5.0, Vector2(4.4, 5.2), f.angle(), color.lightened(0.22), false)
	p.tri(lion + f * 7.5 + s * 2.0, lion + f * 9.5, lion + f * 7.5 - s * 2.0, Palette.OUTLINE)
	_beast_eye(p, lion + f * 2.5 + s * 4.2, 2.1, C_EYE_GLOW, f)
	_beast_eye(p, lion + f * 2.5 - s * 4.2, 2.1, C_EYE_GLOW, f)
	var breath := _ease("breath", _wk(0.8) if state == "wind_breath" else 0.0, 10.0)
	if breath > 0.02:
		_glow.circle(lion + f * R * 0.45, 3.0 + 5.0 * breath, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * breath), 16)
		_glow.circle(lion + f * R * 0.45, 1.5 + 2.5 * breath, Color(C_FLAME_CORE, breath), 12)


## A red cone that fills toward its reach as the wind-up runs out.
func _cone(o: Pen, reach: float, half_deg: float, k: float, base_alpha: float, edge := 0.7) -> void:
	var half := deg_to_rad(half_deg)
	var la := lunge_dir.angle()
	o.wedge(Vector2.ZERO, reach, la - half, la + half, Color(Palette.DANGER, base_alpha + 0.15 * k), 16)
	o.arc(Vector2.ZERO, reach * k, la - half, la + half, 2.0, Color(Palette.DANGER, edge), 18)


## A red circle where something will land, its ring closing in.
func _target(o: Pen, at: Vector2, r: float, k: float, base_alpha: float, edge_w := 2.0) -> void:
	o.circle(at, r, Color(Palette.DANGER, base_alpha + 0.12 * k), 40)
	o.arc(at, r, 0.0, TAU, edge_w, Color(Palette.DANGER, 0.7), 40)
	o.arc(at, r * k, 0.0, TAU, 1.5, Color(Palette.DANGER, 0.8), 32)


## A fan of thin aim lines.
func _fan(o: Pen, n: int, step_deg: float, length: float) -> void:
	for i in n:
		o.quad(Vector2.ZERO, lunge_dir.rotated((float(i) - (n - 1) * 0.5) * deg_to_rad(step_deg)) * length, 1.5, Color(Palette.DANGER, 0.3))


## Telegraphs, status and the health bar: unlit, so they always read.
## Everything but text goes out as one draw call.
func _draw_overlay() -> void:
	var c := overlay
	var o := _ov
	o.reset()
	var lift_y := _lift
	var danger := Palette.DANGER
	if kind == "knight" and state == "wind_slash":
		_cone(o, SLASH_REACH, SLASH_ARC, _wk(0.6), 0.1)
	if kind == "knight" and state == "wind_lunge":
		var k := 1.0 - state_t / 0.7
		var reach := 140.0
		var w := radius * 2.0
		o.quad(Vector2.ZERO, lunge_dir * reach, w, Color(danger, 0.14))
		o.quad(Vector2.ZERO, lunge_dir * reach * k, w, Color(danger, 0.4))
		var side := lunge_dir.orthogonal()
		for i in 4:  # chevrons marching along the path
			var d := fmod(float(i) * 35.0 + k * 35.0, reach)
			var at := lunge_dir * d
			var al := 0.6 * clampf(minf(d, reach - d) / 15.0, 0.0, 1.0)
			o.quad(at - lunge_dir * 5.0 + side * 6.0, at, 2.0, Color(danger, al))
			o.quad(at, at - lunge_dir * 5.0 - side * 6.0, 2.0, Color(danger, al))
	if kind == "archer" and aim_dir != Vector2.ZERO:
		var k2 := clampf(1.0 - state_t / 0.5, 0.0, 1.0)
		o.quad(aim_dir * 14.0, aim_dir * 420.0, 1.0 + k2, Color(danger, 0.25 + 0.4 * k2))
		o.circle(aim_dir * 14.0, 2.0 + k2 * 2.0, Color(danger, 0.8), 14)
	if kind == "lurker" and state == "wind":
		o.quad(Vector2.ZERO, lunge_dir * 110.0, radius * 1.5, Color(danger, 0.4))
	if kind == "shellback" and state == "wind_bash":
		o.wedge(Vector2.ZERO, 66.0, face.angle() - deg_to_rad(55.0), face.angle() + deg_to_rad(55.0), Color(danger, 0.1 + 0.15 * _wk(0.7)), 10)
	if kind == "kraken":
		if state == "wind_sweep":
			var half := deg_to_rad(SWEEP_ARC)
			var la := lunge_dir.angle()
			var ks := _wk(0.7)
			o.wedge(Vector2.ZERO, SWEEP_REACH, la - half, la + half, Color(danger, 0.08 + 0.12 * ks), 24)
			o.arc(Vector2.ZERO, SWEEP_REACH * ks, la - half, la + half, 2.0, Color(danger, 0.7), 24)
		if state == "wind_slam":
			for spot in slam_spots:
				_target(o, spot - global_position, SLAM_RADIUS, _wk(0.9), 0.1)
		if state == "wind_ink":
			_fan(o, 3, 16.0, 140.0)
	if kind == "thunderling" and state == "wind_spark":
		var ks := _wk(0.9)
		o.circle(Vector2.ZERO, SPARK_RADIUS, Color(danger, 0.08 + 0.1 * ks), 48)
		o.arc(Vector2.ZERO, SPARK_RADIUS, 0.0, TAU, 2.0, Color(danger, 0.5), 48)
		o.arc(Vector2.ZERO, SPARK_RADIUS * ks, 0.0, TAU, 1.5, Color(danger, 0.7), 40)
	if kind == "bat" and state == "wind":
		o.quad(Vector2.ZERO, aim_dir * 150.0, 2.0, Color(danger, 0.35))
	if kind == "gryphon":
		if state == "wind_rake":
			_cone(o, RAKE_REACH, RAKE_ARC, _wk(0.55), 0.1)
		if state == "wind_dive" or state == "dive":
			var kd := clampf(1.0 - state_t / (0.75 if state == "wind_dive" else 0.28), 0.0, 1.0)
			_target(o, dive_to - global_position, DIVE_RADIUS, kd, 0.12, 2.5)
		if state == "wind_gale":
			_fan(o, 5, 14.0, 120.0)
	if kind == "slime" and state == "wind":
		o.arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 2.0, Color(danger, 0.6), 28)
	if kind == "thornhound" and state == "wind":
		o.quad(Vector2.ZERO, lunge_dir * 110.0, radius * 1.4, Color(danger, 0.4))
	if kind == "mongrel":
		if state == "wind_bite":
			var half := deg_to_rad(50.0)
			o.wedge(Vector2.ZERO, BITE_REACH, lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.12 + 0.15 * _wk(0.6)), 10)
		if state == "wind_quills":
			_fan(o, 3, 12.0, 130.0)
	if kind == "chimera":
		if state == "wind_maul":
			_cone(o, CLAW_REACH, CLAW_ARC, _wk(0.55), 0.1, 0.75)
		if state == "wind_breath":
			_cone(o, BREATH_REACH, BREATH_ARC, _wk(0.8), 0.1, 0.75)
		if state == "wind_charge" or state == "charge":
			o.quad(Vector2.ZERO, lunge_dir * 230.0, radius * 1.6, Color(danger, 0.2))
		if state == "wind_spikes":
			_fan(o, 3, 10.0, 150.0)
	if kind == "wisp" and state == "wind":
		o.quad(Vector2.ZERO, aim_dir * 120.0, radius * 1.6, Color(danger, 0.4))
	if kind == "bloomcap" and state == "wind_lob":
		var at := lob_spot - global_position
		if not glinted:
			at = main.player.global_position - global_position
		_target(o, at, LOB_RADIUS, _wk(0.9), 0.1)
	if kind == "firebird":
		if state == "wind_swoop":
			o.quad(Vector2.ZERO, aim_dir * 260.0, radius * 1.4, Color(danger, 0.3))
		if state == "wind_storm":
			for spot in storm_spots:
				_target(o, spot - global_position, STORM_RADIUS, _wk(0.9), 0.1)
		if state == "wind_embers":
			_fan(o, 7, 11.0, 120.0)
	if kind == "scorpling" and state == "wind_sting":
		var half := deg_to_rad(50.0)
		o.wedge(Vector2.ZERO, STING_REACH, lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.12 + 0.15 * _wk(0.5)), 10)
	if kind == "ram" and (state == "wind_charge" or state == "charge"):
		var kc := _wk(0.8) if state == "wind_charge" else 1.0
		o.quad(Vector2.ZERO, lunge_dir * 260.0, radius * 2.0, Color(danger, 0.14))
		o.quad(Vector2.ZERO, lunge_dir * 260.0 * kc, radius * 2.0, Color(danger, 0.35))
	if kind == "manticore":
		if state == "wind_claw":
			_cone(o, CLAW_REACH, CLAW_ARC, _wk(0.55), 0.1, 0.75)
		if state == "wind_roar":
			var kr := _wk(0.9)
			o.circle(Vector2.ZERO, ROAR_RADIUS, Color(danger, 0.08 + 0.12 * kr), 56)
			o.arc(Vector2.ZERO, ROAR_RADIUS, 0.0, TAU, 2.5, Color(danger, 0.7), 56)
			o.arc(Vector2.ZERO, ROAR_RADIUS * kr, 0.0, TAU, 1.5, Color(danger, 0.8), 48)
		if state == "wind_spikes":
			_fan(o, 3, 10.0, 150.0)
	if kind == "cinder" and state == "wind_spit":
		o.quad(Vector2.ZERO, lunge_dir * 140.0, 1.5, Color(danger, 0.35))
	if kind == "smith" and state == "wind_hammer":
		_target(o, face * HAMMER_REACH, HAMMER_RADIUS, _wk(0.85), 0.1)
	if kind == "wyvern":
		if state == "wind_tail":
			_cone(o, TAIL_REACH, TAIL_ARC, _wk(0.6), 0.1, 0.75)
		if state == "wind_breath":
			_cone(o, BREATH_REACH, BREATH_ARC, _wk(0.8), 0.1, 0.75)
		if state == "wind_embers":
			_fan(o, 5, 12.0, 120.0)
	# The body's glowing bits (eyes, fire, sparks).
	o.pts.append_array(_glow.pts)
	o.cols.append_array(_glow.cols)
	if glint > 0.0:
		# The glint: a white four-point star where the blow will come from.
		var gk := glint / 0.22
		var gp := Vector2(0, lift_y) + face * (radius + 4.0)
		var arm := 6.0 + 10.0 * gk
		var gc := Color(1, 1, 1, gk)
		o.quad(gp - Vector2(arm, 0), gp + Vector2(arm, 0), 2.0, gc)
		o.quad(gp - Vector2(0, arm), gp + Vector2(0, arm), 2.0, gc)
		o.quad(gp - Vector2(arm, arm) * 0.45, gp + Vector2(arm, arm) * 0.45, 1.5, Color(gc, gk * 0.7))
		o.quad(gp - Vector2(arm, -arm) * 0.45, gp + Vector2(arm, -arm) * 0.45, 1.5, Color(gc, gk * 0.7))
		o.circle(gp, 3.0 * gk + 1.0, gc, 12)
	var now := Time.get_ticks_msec() * 0.001
	if charged > 0.0:
		for i in 3:
			var a := now * 6.0 + i * TAU / 3.0
			o.quad(Vector2(0, lift_y) + Vector2.from_angle(a) * (radius + 2.0), Vector2(0, lift_y) + Vector2.from_angle(a + 0.4) * (radius + 6.0), 1.5, Color(0.95, 0.89, 0.42, 0.9))
	if stun > 0.0:
		for i in 3:
			o.circle(Vector2(0, lift_y - radius - 8.0) + Vector2.from_angle(now * 4.0 + i * TAU / 3.0) * 7.0, 2.0, Color(1.0, 0.89, 0.63), 10)
	if venom > 0:
		for i in mini(venom, 6):
			var ph := fmod(now * 3.0 + i * 0.37, 1.0)
			o.circle(Vector2(-radius + i * radius * 0.4, -radius - 4.0 + ph * 8.0), 1.6, Color(0.55, 0.85, 0.35, 0.85 * sin(ph * PI)), 8)
	if open_t > 0.0 and not ally:
		# Open to punishment: a gold ring that breathes (not strobes).
		var po := 0.8 + 0.2 * sin(now * 7.0)
		var fade := clampf(open_t / 0.2, 0.0, 1.0)
		o.arc(Vector2(0, lift_y), radius + 7.0, 0.0, TAU, 2.5, Color(1.0, 0.85, 0.45, 0.8 * po * fade), 36)
	if ally:
		o.arc(Vector2(0, radius * 0.7), radius + 4.0, 0.0, TAU, 2.0, Color(0.6, 1.0, 0.75, 0.8), 28)
		var lw := radius * 2.2
		o.rect(Rect2(Vector2(-lw / 2.0, radius + 8.0), Vector2(lw * clampf(ally_t / ally_life, 0.0, 1.0), 2.0)), Color(0.6, 1.0, 0.75, 0.8))
	var diagnosis: bool = main.player != null and main.player.has_bond("surgeon") and not ally
	var big := float(CHAMPION["size"]) if champion else 1.0
	if champion:
		# A gold aura that breathes at its feet, a crown over its head, and
		# its slam's ring closing in while it winds up.
		var cc: Color = CHAMPION["color"]
		var br := 0.75 + 0.25 * sin(now * 3.0)
		o.arc(Vector2(0, radius * 0.6 * big), radius * big + 6.0, 0.0, TAU, 2.0, Color(cc, 0.65 * br), 32)
		o.arc(Vector2(0, radius * 0.6 * big), radius * big + 11.0, 0.0, TAU, 1.2, Color(cc, 0.3 * br), 32)
		var ct := Vector2(0, lift_y - radius * big - 18.0)
		var crown := PackedVector2Array([ct + Vector2(-8, 4), ct + Vector2(-9, -5), ct + Vector2(-4, -1), ct + Vector2(0, -8),
			ct + Vector2(4, -1), ct + Vector2(9, -5), ct + Vector2(8, 4)])
		o.poly(crown, cc, 1.4)
		o.circle(ct + Vector2(0, 1.2), 1.4, Color(0.9, 0.25, 0.2), 8)
		if champ_wind > 0.0:
			var reach := float(CHAMPION["slam_reach"])
			var kw := clampf(1.0 - champ_wind / float(CHAMPION["slam_wind"]), 0.0, 1.0)
			o.circle(Vector2.ZERO, reach, Color(danger, 0.08 + 0.12 * kw), 48)
			o.arc(Vector2.ZERO, reach, 0.0, TAU, 2.5, Color(danger, 0.7), 48)
			o.arc(Vector2.ZERO, reach * (1.0 - kw) + 6.0, 0.0, TAU, 2.0, Color(cc, 0.85), 40)
	if (hp < max_hp or diagnosis or champion) and not is_boss():
		var w2 := radius * 2.2 * big
		var top := Vector2(-w2 / 2.0, lift_y - radius * big - 11.0)
		o.rect(Rect2(top - Vector2(1, 1), Vector2(w2 + 2, 5)), Color(0, 0, 0, 0.7))
		o.rect(Rect2(top, Vector2(w2 * clampf(hp / max_hp, 0.0, 1.0), 3.0)), Color(0.85, 0.25, 0.2))
	o.flush(c)
	if main.player != null and is_lost(global_position.distance_to(main.player.global_position)):
		c.draw_string(ThemeDB.fallback_font, Vector2(-4, lift_y - radius - 16.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.78, 0.75, 0.9))
	if diagnosis and not is_boss():
		c.draw_string(ThemeDB.fallback_font, Vector2(-60, lift_y - radius - 18.0), WEAKNESS.get(kind, ""), HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color(0.85, 0.9, 0.95, 0.75))
	if cripple_t > 0.0 or disarm_t > 0.0:
		c.draw_string(ThemeDB.fallback_font, Vector2(-40, radius + 18.0), "disarmed" if disarm_t > 0.0 else "crippled", HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(0.9, 0.95, 1.0, 0.85))


## Collects shapes as one list of triangles, in order, sent as one draw call.
## Every shape goes through `xf` (the squash and lift); `tint` eases every
## colour toward white (the hit flash, shaped like the body). Outlines are
## filled shapes, never wide lines, so torchlight falls on them evenly.
class Pen:
	const Pal := preload("res://scripts/palette.gd")
	const LIGHT := Vector2(-0.7, -0.7)  # toward the top-left, where light comes from
	static var _fans := {}  # sides -> unit circle as triangles

	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var xf := Transform2D.IDENTITY
	var tint := 0.0
	var _one := PackedColorArray()

	func reset() -> void:
		pts.resize(0)
		cols.resize(0)
		xf = Transform2D.IDENTITY
		tint = 0.0

	static func fan(n: int) -> PackedVector2Array:
		if not _fans.has(n):
			var ring := PackedVector2Array()
			for i in n:
				ring.append(Vector2.from_angle(i * TAU / n))
			var tris := PackedVector2Array()
			for i in n - 2:
				tris.append_array([ring[0], ring[i + 1], ring[i + 2]])
			_fans[n] = tris
		return _fans[n]

	## Enough sides that a circle looks round at its size, and no more.
	static func sides(r: float) -> int:
		return clampi(int(r * 0.85) + 7, 8, 32)

	func _fill(col: Color, n: int) -> void:
		if tint > 0.0:
			col = Color(col.lerp(Color(1.0, 0.97, 0.92), tint), col.a)
		_one.resize(n)
		_one.fill(col)
		cols.append_array(_one)

	func circle(at: Vector2, r: float, col: Color, n := 0) -> void:
		var tris := fan(n if n > 0 else sides(r))
		pts.append_array((xf * Transform2D(0.0, Vector2(r, r), 0.0, at)) * tris)
		_fill(col, tris.size())

	func oval(at: Vector2, rad: Vector2, angle: float, col: Color, n := 0) -> void:
		var tris := fan(n if n > 0 else sides(maxf(rad.x, rad.y)))
		pts.append_array((xf * Transform2D(angle, rad, 0.0, at)) * tris)
		_fill(col, tris.size())

	## A ball lit from the top-left, with a soft outline (like Draw.ball).
	func ball(at: Vector2, r: float, col: Color, outline := true) -> void:
		if outline:
			if r >= 6.0:  # the soft rim; small balls don't need it
				circle(at, r + 2.5, Color(Pal.OUTLINE, 0.3))
			circle(at, r + 1.6, Pal.OUTLINE)
		circle(at, r, col.darkened(0.35))
		circle(at + Vector2(-r * 0.12, -r * 0.14), r * 0.86, col)
		circle(at + Vector2(-r * 0.32, -r * 0.36), r * 0.34, Color(col.lightened(0.45), 0.55))

	## An oval ball (bodies), lit the same way.
	func egg(at: Vector2, rad: Vector2, angle: float, col: Color, outline := true) -> void:
		if outline:
			oval(at, rad + Vector2(2.5, 2.5), angle, Color(Pal.OUTLINE, 0.3))
			oval(at, rad + Vector2(1.6, 1.6), angle, Pal.OUTLINE)
		var m := minf(rad.x, rad.y)
		oval(at, rad, angle, col.darkened(0.35))
		oval(at + Vector2(-m * 0.12, -m * 0.14), rad * 0.86, angle, col)
		oval(at + Vector2(-m * 0.3, -m * 0.34), rad * 0.36, angle, Color(col.lightened(0.45), 0.5))

	## A straight band from a to b, wa wide at a and wb at b.
	func quad(a: Vector2, b: Vector2, wa: float, col: Color, wb := -1.0) -> void:
		var d := b - a
		if d.length_squared() < 0.0001:
			return
		if wb < 0.0:
			wb = wa
		var o := d.normalized().orthogonal() * 0.5
		pts.append_array(xf * PackedVector2Array([a + o * wa, b + o * wb, b - o * wb, a + o * wa, b - o * wb, a - o * wa]))
		_fill(col, 6)

	func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
		pts.append_array(xf * PackedVector2Array([a, b, c]))
		_fill(col, 3)

	func rect(r: Rect2, col: Color) -> void:
		var a := r.position
		var b := r.end
		pts.append_array(xf * PackedVector2Array([a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)]))
		_fill(col, 6)

	## A thick outlined stroke with round ends (limbs, handles).
	func limb(a: Vector2, b: Vector2, col: Color, w: float, outline := true) -> void:
		if outline:
			var ow := w + 3.2
			quad(a, b, ow, Pal.OUTLINE)
			circle(a, ow * 0.5, Pal.OUTLINE, 8)
			circle(b, ow * 0.5, Pal.OUTLINE, 8)
		quad(a, b, w, col)
		circle(a, w * 0.5, col, 8)
		circle(b, w * 0.5, col, 8)

	## A tapering outlined tube through points (tails, necks, tentacles),
	## shaded: darker below, a lighter band on the side toward the light.
	func tube(p: PackedVector2Array, w: PackedFloat32Array, col: Color, outline := true, shade := true) -> void:
		var n := p.size()
		if n < 2:
			return
		var nrm := PackedVector2Array()
		nrm.resize(n)
		for i in n:
			nrm[i] = (p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]).normalized().orthogonal()
		if outline:
			_strip(p, nrm, w, 1.0, 3.2, Pal.OUTLINE, 0.0)
			circle(p[0], w[0] * 0.5 + 1.6, Pal.OUTLINE, 10)
			circle(p[n - 1], w[n - 1] * 0.5 + 1.6, Pal.OUTLINE, 10)
		var base := col.darkened(0.3) if shade else col
		_strip(p, nrm, w, 1.0, 0.0, base, 0.0)
		circle(p[0], w[0] * 0.5, base, 10)
		circle(p[n - 1], w[n - 1] * 0.5, base, 10)
		if shade:
			_strip(p, nrm, w, 0.55, 0.0, col, 0.2)

	func _strip(p: PackedVector2Array, nrm: PackedVector2Array, w: PackedFloat32Array, k: float, extra: float, col: Color, shift: float) -> void:
		var n := p.size()
		var sa := PackedVector2Array()
		var sb := PackedVector2Array()
		sa.resize(n)
		sb.resize(n)
		for i in n:
			var h := (w[i] * k + extra) * 0.5
			var c := p[i]
			if shift != 0.0:
				c += nrm[i] * nrm[i].dot(LIGHT) * w[i] * shift
			sa[i] = c + nrm[i] * h
			sb[i] = c - nrm[i] * h
		sa = xf * sa
		sb = xf * sb
		var q := PackedVector2Array()
		q.resize((n - 1) * 6)
		for i in n - 1:
			var j := i * 6
			q[j] = sa[i]
			q[j + 1] = sa[i + 1]
			q[j + 2] = sb[i + 1]
			q[j + 3] = sa[i]
			q[j + 4] = sb[i + 1]
			q[j + 5] = sb[i]
		pts.append_array(q)
		_fill(col, q.size())

	## A filled polygon with a soft outline grown around it.
	func poly(p: PackedVector2Array, col: Color, outline := 1.6) -> void:
		if outline > 0.0:
			if outline >= 1.3:  # the soft rim (thin details go without)
				fill_poly(grow(p, outline + 0.9), Color(Pal.OUTLINE, 0.3))
			fill_poly(grow(p, outline), Pal.OUTLINE)
		fill_poly(p, col)

	func fill_poly(p: PackedVector2Array, col: Color) -> void:
		var q := xf * p
		var idx := Geometry2D.triangulate_polygon(q)
		if idx.is_empty():
			return
		var out := PackedVector2Array()
		out.resize(idx.size())
		for i in idx.size():
			out[i] = q[idx[i]]
		pts.append_array(out)
		_fill(col, out.size())

	## The polygon pushed outward by d (mitred, capped at sharp points).
	static func grow(p: PackedVector2Array, d: float) -> PackedVector2Array:
		var n := p.size()
		var area := 0.0
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			area += a.x * b.y - b.x * a.y
		var sg := 1.0 if area > 0.0 else -1.0
		var out := PackedVector2Array()
		out.resize(n)
		for i in n:
			var n1 := (p[i] - p[(i - 1 + n) % n]).normalized().orthogonal() * sg
			var n2 := (p[(i + 1) % n] - p[i]).normalized().orthogonal() * sg
			var m := n1 + n2
			m = m.normalized() if m.length_squared() > 0.0001 else n1
			out[i] = p[i] + m * (d / maxf(0.4, m.dot(n1)))
		return out

	## A band along a circle's arc, w wide (rings, rims, reach lines).
	func arc(at: Vector2, r: float, a0: float, a1: float, w: float, col: Color, n := 24) -> void:
		var q := PackedVector2Array()
		q.resize(n * 6)
		var po := Vector2.ZERO
		var pi := Vector2.ZERO
		for i in n + 1:
			var d := Vector2.from_angle(lerpf(a0, a1, float(i) / n))
			var ou := at + d * (r + w * 0.5)
			var inn := at + d * maxf(0.0, r - w * 0.5)
			if i > 0:
				var j := (i - 1) * 6
				q[j] = po
				q[j + 1] = ou
				q[j + 2] = inn
				q[j + 3] = po
				q[j + 4] = inn
				q[j + 5] = pi
			po = ou
			pi = inn
		pts.append_array(xf * q)
		_fill(col, q.size())

	## A filled pie slice.
	func wedge(at: Vector2, r: float, a0: float, a1: float, col: Color, n := 16) -> void:
		var q := PackedVector2Array()
		q.resize(n * 3)
		var prev := at + Vector2.from_angle(a0) * r
		for i in n:
			var next := at + Vector2.from_angle(lerpf(a0, a1, float(i + 1) / n)) * r
			q[i * 3] = at
			q[i * 3 + 1] = prev
			q[i * 3 + 2] = next
			prev = next
		pts.append_array(xf * q)
		_fill(col, q.size())

	func flush(ci: CanvasItem) -> void:
		if pts.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), pts, cols)
