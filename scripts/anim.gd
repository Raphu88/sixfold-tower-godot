extends RefCounted
## Motion and life: the small animations and effects that make the climber,
## the foes and each tower feel alive. All of it is VISUAL: nothing here
## changes when a blow lands, how long a roll keeps you untouchable or when a
## foe's glint shows.
##
## What it holds:
##   DATA     every amount, duration and strength (the Data editor changes them)
##   AMBIENT  each tower's own life: drips and bubbles (Kraken), wind and
##            feathers (Gryphon), ash and heat (Wyvern), sand (Manticore),
##            embers (Firebird), leaves and spores (Chimera)
##   hooks    the few calls the rest of the game makes: a swing, a roll, a
##            landing, a parry, a drink, a foe's end, a beast's arrival, the
##            ward lifting, a door, a crumbling wall, a chest, a pickup
##
## Everything goes through particles.gd (one drawer, one cap, the Effects
## setting: Low keeps only the few "key" flashes and no ambient streams) and
## through main's own rings, lights and shake (Settings -> Screen shake).
## Where something is drawn in code (the walk bob, a stretch, a breath) the
## drawing script asks here for the number.

const Particles := preload("res://scripts/particles.gd")

static var DATA := {
	# The climber.
	"walk": {"bob": 1.4},  # pixels the body rises with each step
	"swing": {"sparks": 1.0, "heavy_sparks": 1.0, "heavy_arcs": 2, "heavy_width": 1.5},
	"roll": {"stretch": 0.3, "puff": 1.0, "land": 1.0},  # how much the roll stretches you; its dust, and the dust as it ends
	"jump": {"land": 1.0},  # the puff when you land
	"hurt": {"shiver": 1.8, "time": 0.14},  # pixels the body shivers for this long after a hit
	"heal": {"every": 0.16, "glow": 0.16},  # a sparkle this often while a drink mends you; the soft glow's strength
	"death": {"time": 0.45, "crumple": 0.32},  # the fall: how long, and how far it folds
	# Foes.
	"foe": {"breath": 0.03, "breath_rate": 2.3, "pull": 3.2, "hit_tint": 0.85, "dissolve": 1.0, "dissolve_beast": 2.4, "drift": 1.0},
	# The six beasts.
	"beast": {"entrance": 1.0, "phase": 1.0, "phase_at": 0.5, "slow_scale": 0.35, "slow_seconds": 0.8, "slow": true},
	# Screen shake: the setting turns it all off; this scales it, and adds a little for a beast's blows and a blast.
	"shake": {"mult": 1.0, "blast": 3.0, "beast_blow": 3.0},
	# Numbers in the world: a pop, an arc, a crit's size.
	"text": {"pop": 110.0, "settle": 16.0, "pull": 340.0, "drift": 34.0, "crit_scale": 1.5, "crit_color": Color(1.0, 0.82, 0.35)},
	# Menus and the HUD.
	"ui": {"wheel_bloom": 0.16, "wheel_from": 0.7, "feed_slide": 26.0, "feed_in": 0.18},
	# A mark growing, on the train's body view.
	"grow": {"time": 1.1, "rays": 10, "reach": 34.0},
	# The world: torches' sparks (how often one looks), the ward's pulse, and how full the pool may be before ambient life waits.
	"world": {"torch": 0.35, "ward_every": 1.6, "crowd": 0.6, "door": 1.0, "wall": 1.0, "chest": 1.0, "pickup": 1.0},
}

## Each tower's ambient life: [preset, share of its rate]. Streams over the
## whole view (the level's rate scales them; Low has none).
static var AMBIENT := {
	"gryphon": [["amb_wind", 1.0], ["amb_feather", 1.0]],
	"kraken": [["amb_drip", 1.0], ["amb_bubble", 1.0]],
	"wyvern": [["amb_ash", 1.0], ["amb_heat", 1.0]],
	"manticore": [["amb_sand", 1.0]],
	"firebird": [["amb_ember", 1.0]],
	"chimera": [["amb_leaf", 1.0], ["amb_spore", 1.0]],
}

static var force_beat := false  # tests: the slow beat runs even without a screen


static func num(group: String, key: String) -> float:
	return float(DATA[group][key])


# --- the climber ---------------------------------------------------------------

## How far the body rises on a step (0..1 through the stride, scaled by how fast you walk).
static func bob(phase: float, amp: float) -> float:
	return absf(sin(phase)) * amp * num("walk", "bob")


## How far a roll has stretched you, 0..1 through it (k: 0 at its start, 1 at its end).
static func roll_stretch(k: float) -> float:
	return sin(PI * clampf(k, 0.0, 1.0)) * num("roll", "stretch")


## The little tremor of a hit, as an offset (zero once it has passed).
static func shiver(hurt_t: float, grace: float, t: float) -> Vector2:
	var span := num("hurt", "time")
	var k := clampf((hurt_t - (grace - span)) / maxf(span, 0.01), 0.0, 1.0)
	if k <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 95.0), cos(t * 77.0)) * num("hurt", "shiver") * k


## 0..1 through the fall (a body folding as it drops), then it stays at 1.
static func crumple(age: float) -> float:
	var k := clampf(age / maxf(num("death", "time"), 0.05), 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## Sparks along a swing's path, as it begins. `reach` and `half` (radians) and
## `side` give an arc's sweep; a thrust throws them along its line.
static func swing(m, from: Vector2, aim: Vector2, reach: float, half: float, side: float, style: String, heavy: bool) -> void:
	var preset := "swing_heavy" if heavy else "swing_spark"
	var k := num("swing", "heavy_sparks" if heavy else "sparks")
	match style:
		"arc":
			var a0 := aim.angle() - half * side
			var a1 := aim.angle() + half * side
			for i in 4:
				var a := lerpf(a0, a1, float(i) / 3.0)
				var tangent := Vector2.from_angle(a + side * PI * 0.5)
				Particles.burst(m, from + Vector2.from_angle(a) * reach * 0.92, preset, k, tangent)
		"stab", "thrust":
			for i in 2:
				Particles.burst(m, from + aim * reach * (0.6 + 0.4 * i), preset, k, aim)
		_:
			Particles.burst(m, from + aim * reach, preset, k * 0.6, aim)


## A roll begins: dust kicked up behind you.
static func roll_start(m, at: Vector2, dir: Vector2) -> void:
	Particles.burst(m, at + Vector2(0, 8), "roll_dust", num("roll", "puff"), -dir)


## A roll ends or you land: a puff round the feet.
static func land(m, at: Vector2, scale: float) -> void:
	Particles.burst(m, at + Vector2(0, 9), "land_dust", scale)


## A parry: a flash of glints and a ring (the perfect one more).
static func parry(m, at: Vector2, aim: Vector2, perfect: bool) -> void:
	Particles.burst(m, at + aim * 16.0, "glint", 1.4 if perfect else 0.8, aim)
	if perfect:
		Particles.burst(m, at + aim * 16.0, "flourish", 0.7)


## A drink mending you: a green sparkle now and then, rising.
static func heal_tick(m, at: Vector2, state: Array, delta: float) -> void:
	state[0] = float(state[0]) - delta
	if float(state[0]) > 0.0:
		return
	state[0] = num("heal", "every")
	Particles.burst(m, at + Vector2(randf_range(-8.0, 8.0), 4.0), "bloom", 0.35)


# --- foes ----------------------------------------------------------------------

## A foe's end: it comes apart into motes that rise and drift toward the
## climber (the essence itself is awarded as ever: main.gather_essence).
static func dissolve(m, e) -> void:
	if m == null or e == null:
		return
	var big: bool = e.is_boss()
	var k := (num("foe", "dissolve_beast") if big else num("foe", "dissolve")) * clampf(float(e.radius) / 12.0, 0.7, 2.5)
	var col: Color = Color(e.color).lightened(0.35)
	col.a = 1.0
	Particles.burst(m, e.global_position, "dissolve", k, Vector2.ZERO, col)
	if m.player != null and is_instance_valid(m.player):
		var to: Vector2 = m.player.global_position - e.global_position
		if to.length() > 1.0:
			Particles.burst(m, e.global_position, "dissolve_drift", k * num("foe", "drift"), to.normalized(), col)


## A beast arrives (its floor's first sight of it): a ring, flare and a light.
static func entrance(m, e) -> void:
	if m == null or e == null or not is_instance_valid(e) or not e.is_inside_tree():
		return
	var s := num("beast", "entrance")
	m.fx_ring(e.global_position, e.color, 120.0 * s, 0.6, 5.0)
	m.light_flash(e.global_position, e.color, 2.2 * s, 2.0, 0.5)
	Particles.burst(m, e.global_position, "flourish", 1.2 * s, Vector2.ZERO, e.color.lightened(0.2))
	m.shake(4.0 * s)


## A beast at half health: it flares (the fight turns).
static func phase(m, e) -> void:
	if m == null or e == null:
		return
	var s := num("beast", "phase")
	m.fx_ring(e.global_position, e.color.lightened(0.3), 100.0 * s, 0.5, 6.0)
	m.light_flash(e.global_position, e.color, 2.4 * s, 2.2, 0.45)
	Particles.burst(m, e.global_position, "flourish", 1.5 * s, Vector2.ZERO, e.color.lightened(0.25))
	m.fx_text(e.global_position + Vector2(0, -float(e.radius) - 30.0), "Enraged", e.color.lightened(0.3))
	m.shake(5.0 * s)


## A beast falls: a short slow beat after the hit-pause. Never while a test
## runs the game fast or headless (real time would slow every check).
static func slow_beat(m) -> void:
	if m == null or not bool(DATA["beast"]["slow"]) or m.test_speed != 1.0:
		return
	if DisplayServer.get_name() == "headless" and not force_beat:
		return
	var now := Time.get_ticks_msec()
	var extra := maxi(0, int(m.hitstop_until) - now)
	m.beat_scale = clampf(num("beast", "slow_scale"), 0.05, 1.0)
	m.beat_until = now + extra + int(num("beast", "slow_seconds") * 1000.0)


# --- the world -----------------------------------------------------------------

## Starts the floor's ambient life (the tower's own streams). Particles.clear
## ends every stream on a new floor, so main calls this right after it.
static func start_ambient(m) -> int:
	var pf = Particles.of(m)
	if pf == null:
		return 0
	var list: Array = AMBIENT.get(String(m.tower), [])
	var made := 0
	for entry in list:
		var e := Particles.emitter(m, func(): return Vector2.ZERO, String(entry[0]), Particles.NONE, func(): return pf.count() < int(float(pf.cap()) * num("world", "crowd")), float(entry[1]))
		e.tag = "ambient"
		e.spread_view = true
		made += 1
	return made


## How many ambient streams are running.
static func ambient_count(m) -> int:
	var pf = Particles.of(m)
	if pf == null:
		return 0
	return pf.emitters.filter(func(e): return e.live and e.tag == "ambient").size()


## Each frame (particles.gd calls it): torches throw an occasional spark, a
## warded stair pulses.
static func tick(pf, delta: float, st: Dictionary) -> void:
	var m = pf.main
	if m == null or m.player == null or m.on_train or m.title_showing():
		return
	var rate_k: float = Particles.lv()["rate"]
	st["torch"] = float(st.get("torch", 0.0)) - delta
	if st["torch"] <= 0.0:
		st["torch"] = 0.25
		if rate_k > 0.0 and m.room_view != null and "torches" in m.room_view:
			var d: Dictionary = Particles.PRESETS["torch_spark"]
			var shown := 0
			for tc in m.room_view.torches:
				if shown >= 6:
					break
				var at: Vector2 = tc["pos"] + Vector2(0, -5)
				if not pf.visible_at(at):
					continue
				shown += 1
				if randf() < num("world", "torch") * rate_k:
					pf._emit(d, at, Vector2.UP, Particles.NONE)
	st["ward"] = float(st.get("ward", 0.0)) - delta
	if st["ward"] <= 0.0:
		st["ward"] = num("world", "ward_every")
		if m.ward and not m.stair_open and not m.in_camp and pf.visible_at(m.stair_pos):
			m.fx_ring(m.stair_pos, Color(1.0, 0.84, 0.45, 0.7), 34.0, 0.9, 2.0)
			Particles.burst(m, m.stair_pos, "ward_motes", 1.0)


## The ward lifts: the stair bursts open in gold.
static func ward_lift(m) -> void:
	Particles.burst(m, m.stair_pos, "flourish", 1.6, Vector2.ZERO, Color(1.0, 0.84, 0.45))
	Particles.burst(m, m.stair_pos, "pop", 1.2, Vector2.UP, Color(1.0, 0.9, 0.6))
	m.light_flash(m.stair_pos, Color(1.0, 0.84, 0.45), 2.4, 2.2, 0.6)
	m.fx_ring(m.stair_pos, Color(1.0, 0.9, 0.6), 110.0, 0.7, 5.0)


## A door swings open: dust from its edges.
static func door(m, at: Vector2, out: Vector2) -> void:
	Particles.burst(m, at, "land_dust", 1.2 * num("world", "door"), out)


## A cracked wall comes down: chips and dust.
static func wall(m, at: Vector2) -> void:
	Particles.burst(m, at, "chips", 1.2 * num("world", "wall"))
	Particles.burst(m, at, "land_dust", 1.5 * num("world", "wall"))


## A chest or cache pops open: a fountain of sparks.
static func chest(m, at: Vector2, color: Color) -> void:
	Particles.burst(m, at, "pop", 2.0 * num("world", "chest"), Vector2.UP, color)
	Particles.burst(m, at, "flourish", 0.8 * num("world", "chest"), Vector2.ZERO, color)


## Something picked up: a small arc of sparks as it goes.
static func pickup(m, at: Vector2, color: Color) -> void:
	Particles.burst(m, at, "pop", 0.9 * num("world", "pickup"), Vector2.UP, color)
