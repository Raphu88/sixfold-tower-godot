extends "res://scripts/towers/brood.gd"
## THE FLAMEMOTH: a swarm of glowing moths in the Firebird's tower (kind
## "flamemoth"; enemy.gd SUBKINDS spawns it with this script). It flies (it
## crosses the abyss). It is DRAWN TO LIGHT AND FIRE: burning floor (yours
## too), a kindler's torch, the wall torches, and you if you're burning. Near
## a light it hovers round it and forgets you unless you come close; burning
## floor FEEDS it and it grows. FIRE MAKES IT GROW: a fire spell or burning
## ground that catches it doesn't burn it, it grows bigger, tougher and
## harder-hitting (up to FLAMEMOTH "grow_max"). WATER OR WIND DISPERSES it:
## soaked, thrown up, or shoved hard, the swarm scatters (most of its health
## gone, back to its smallest). It attacks by tightening into a ball, a
## glint, and darting through where you stood (parryable); its touch burns.

static var FLAMEMOTH := {
	"lure": 240.0,  # a light this near draws it (px)...
	"hover": 30.0,  # ...and it circles it this close
	"ignore": 110.0,  # hovering at a light, it still goes for you this near
	"feed_every": 3.0,  # seconds at burning floor for each step it grows
	"grow_max": 3,  # the most it can grow
	"grow_hp": 0.35,  # each step: this much more health (a share)...
	"grow_size": 0.22,  # ...size...
	"grow_dmg": 0.25,  # ...and bite
	"dart_near": 130.0, "dart_wind": 0.6, "dart_speed": 430.0,
	"disperse": 0.75,  # dispersed: this share of its health is lost
	"shove": 380.0,  # a shove this hard disperses it
	"daze": 1.0,  # seconds it reels after dispersing
}
static var FLAMEMOTH_TEXT := {"grow": "The swarm feeds on the fire!", "disperse": "Dispersed!"}

const C_WING := Color(1.0, 0.78, 0.42)
const C_BODY := Color(0.55, 0.3, 0.18)

var grown := 0
var feed_t := 0.0
var moth_r := 9.0
var moth_hp := 14.0
var moth_dmg := 8.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "rest"
	moth_r = radius


func _ready() -> void:
	super._ready()
	moth_hp = max_hp
	moth_dmg = dmg


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var m := FLAMEMOTH
	_first_look(dist)
	burn_t = 0.0  # (fire feeds it; it never burns)
	if soaked > 0.0:
		soaked = 0.0
		disperse()
		return
	match state:
		"wind":
			velocity = Vector2.ZERO
			if not glinted:
				aim_dir = dir
				swoop_speed = maxf(float(m["dart_speed"]), maxf(0.0, dist - (radius + p.radius)) / (GLINT_LEAD * 0.85))
			if _wind(delta, maxf(0.0, dist - (radius + p.radius)) / swoop_speed):
				state = "dive"
				state_t = 0.35
				lunge_hit = false
		"dive":
			state_t -= delta
			velocity = aim_dir * swoop_speed
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				_end_attack("rest", 1.0)
		"rest", "recover", "idle":
			state_t -= delta
			_circle(dir, dist, 120.0, speed * 0.7)
			if state_t <= 0.0:
				state = "hover"
		_:
			var light := _lure(p, dist)
			if light != Vector2.INF:
				# Drawn to a light: it circles it, and feeds where the floor burns.
				var to := light - global_position
				var side := to.orthogonal().normalized() * (1.0 if get_instance_id() % 2 == 0 else -1.0)
				var radial := to.normalized() * (1.0 if to.length() > float(m["hover"]) else -0.6)
				velocity = (radial + side * 0.9).normalized() * speed * 0.8
				if not _flame_at(light, -float(m["hover"])).is_empty():
					feed_t += delta
					if feed_t >= float(m["feed_every"]):
						feed_t = 0.0
						grow()
				if dist > float(m["ignore"]):
					return
			if dist < float(m["dart_near"]) and main.request_attack(self):
				_begin_wind("wind", float(m["dart_wind"]))
				_warn(1.2)
				main.sfx("wingbeat", 1.6, -6.0)
				aim_dir = dir
			else:
				var bob := Vector2(sin(Time.get_ticks_msec() * 0.005 + get_instance_id()), cos(Time.get_ticks_msec() * 0.004)) * 25.0
				_circle(dir, dist, 110.0, speed)
				velocity += bob


## The light that draws it, if one is nearer than you (Vector2.INF if none):
## burning floor, a kindler's torch, a wall torch. Burning, you're the light.
func _lure(p, dist: float) -> Vector2:
	if p != null and "states" in p and float(p.states.get("burning", 0.0)) > 0.0:
		return Vector2.INF  # (you're the brightest thing here: it comes for you)
	var reach := float(FLAMEMOTH["lure"])
	var best := Vector2.INF
	var bd := minf(reach, dist)
	for f in main.flames:
		var d: float = global_position.distance_to(f["pos"])
		if d < bd:
			bd = d
			best = f["pos"]
	for e in main.enemies():
		if e.kind == "kindler" and e.has_method("torch_tip"):
			var at: Vector2 = e.global_position + e.torch_tip()
			var d2 := global_position.distance_to(at)
			if d2 < bd:
				bd = d2
				best = at
	var rv = main.get("room_view")
	if rv != null and "torches" in rv:
		for tr in rv.torches:
			var at2: Vector2 = Vector2(tr["pos"]) + Vector2(0, 14)
			var d3 := global_position.distance_to(at2)
			if d3 < bd:
				bd = d3
				best = at2
	return best


## Fire feeds it (enemy.gd ignite, which every burning blow goes through).
func ignite(_dmg: float, _seconds: float) -> void:
	if dead:
		return
	grow()


## One step bigger: more health (healed by the same), size and bite.
func grow() -> void:
	var m := FLAMEMOTH
	if grown >= int(m["grow_max"]) or dead or main == null:
		return
	grown += 1
	var share := hp / maxf(max_hp, 0.001)
	max_hp = moth_hp * (1.0 + float(m["grow_hp"]) * grown)
	hp = max_hp * minf(1.0, share + 0.25)
	dmg = moth_dmg * (1.0 + float(m["grow_dmg"]) * grown)
	_resize(moth_r * (1.0 + float(m["grow_size"]) * grown))
	main.fx_text(global_position + Vector2(0, -radius - 22.0), String(FLAMEMOTH_TEXT["grow"]), C_WING)
	main.fx_burst(global_position, Vector2.UP, C_WING, 10, 120.0)
	main.light_flash(global_position, C_WING, 1.0, 1.3, 0.25)
	main.sfx("burn", 1.4, -6.0)


## Water or wind: the swarm scatters (most of its health gone, back to its smallest).
func disperse() -> void:
	var m := FLAMEMOTH
	if dead or main == null:
		return
	grown = 0
	max_hp = moth_hp
	dmg = moth_dmg
	_resize(moth_r)
	main.fx_text(global_position + Vector2(0, -radius - 22.0), String(FLAMEMOTH_TEXT["disperse"]), Color(0.7, 0.85, 1.0))
	main.fx_burst(global_position, Vector2.ZERO, C_WING, 16, 220.0)
	main.sfx("wingbeat", 1.3, -2.0)
	if is_attacking():
		_end_attack("rest", 1.2)
	stun = maxf(stun, float(m["daze"]))
	hp = minf(hp, max_hp) - max_hp * float(m["disperse"])
	if hp <= 0.0:
		hp = 0.0
		take_hit(1.0, Vector2.ZERO, 0.0)


func lift(_duration: float) -> void:
	disperse()


func tide_push(v: Vector2) -> void:
	super.tide_push(v)
	soaked = 0.0
	disperse()


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	super.take_hit(amount, dir, force, heavy, pierce)
	if not dead and force >= float(FLAMEMOTH["shove"]):
		disperse()


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var size := radius / maxf(moth_r, 1.0)
	var tight := _ease("tight", _wk(float(FLAMEMOTH["dart_wind"])) if state == "wind" else (1.0 if state == "dive" else 0.0), 10.0)
	var n := 9 + grown * 3
	var spread := radius * (1.5 - 0.8 * tight)
	_glow.circle(Vector2.ZERO, spread * 1.3, Color(1.0, 0.6, 0.25, 0.1 + 0.05 * grown + 0.1 * tight), 18)
	for i in n:
		var ph := float(i) * 2.399 + float(get_instance_id() % 7)
		var a := ph + t * (1.6 + 0.4 * sin(ph))
		var rr := spread * (0.35 + 0.65 * fmod(ph * 0.37, 1.0))
		var at := Vector2(cos(a), sin(a * 1.3) * 0.8) * rr + Vector2(0, sin(t * 3.0 + ph) * 2.0)
		var heading := Vector2(-sin(a), cos(a * 1.3)).normalized()
		var flap := absf(sin(t * 22.0 + ph * 3.0))
		var side := heading.orthogonal()
		var w := (2.2 + 0.6 * grown) * size * 0.7
		for sgn in [-1.0, 1.0]:
			p.poly(PackedVector2Array([at, at + side * sgn * w * (0.4 + 0.6 * flap) + heading * w * 0.4, at + side * sgn * w * (0.3 + 0.5 * flap) - heading * w * 0.6]), C_WING.darkened(0.1 * (i % 3)), 0.9)
		p.circle(at, 1.0 * size, C_BODY, 6)
		_glow.circle(at, 0.9 * size, Color(1.0, 0.92, 0.6, 0.8), 6)


func _overlay_extra(o) -> void:
	if state == "wind":
		o.quad(Vector2.ZERO, aim_dir * 130.0, radius * 1.6, Color(Palette.DANGER, 0.35))
