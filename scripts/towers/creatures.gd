extends RefCounted
## The towers' own creatures, run and drawn here so enemy.gd only hands
## them over (its hooks call act, draw, overlay, intercept and on_lethal for
## a kind listed in KINDS). Each plays off its tower's system:
##   ashwing  (the Firebird's) an ember-bird that circles, glints and dives
##            through where you stood, trailing fire. The first time it falls
##            it sinks into a heap of glowing ash and RISES AGAIN a few
##            seconds later, unless its ash is scattered (strike it) or
##            soaked (water, a soaking spell) first.
##   briar    (the Chimera's thicket lurker) hides as a bush, often beside
##            brambles. Come close and it lashes out, grabs you and drags you
##            toward it (a roll breaks free); then it stands and swipes until
##            it can hide again. Fire flushes it out of hiding: it reels,
##            burning, open to blows.
## Their sounds borrow the bank's voices (VOICE), their numbers are enemy.gd
## TYPES and RULES below, their drops essence.gd DROPS and gear.gd FAVOUR.

const Palette := preload("res://scripts/palette.gd")

## Which existing voice (warn_, hurt_, kill_ sounds) each creature borrows.
static var VOICE := {"ashwing": "wisp", "briar": "bloomcap"}
## ashwing: ash (seconds it lies as ash), rise (health it rises with, a
## share), dive (px a second), trail (seconds each flame of its trail
## burns), reach (how near it starts a dive); briar: spring (how near you
## must come for it to lash out, px), grab (its reach), hold (seconds it
## holds you), pull (px a second), squeeze (damage each half second while
## held), restless (seconds you may linger near before it gives itself
## away), hide_after (seconds unstruck before it hides again), stun (how
## long fire flushes it out).
static var RULES := {
	"ash": 3.2, "rise": 0.55, "dive": 470.0, "trail": 1.4, "reach": 190.0,
	"spring": 80.0, "grab": 125.0, "hold": 1.5, "pull": 130.0, "squeeze": 3.0, "restless": 4.0, "hide_after": 6.0, "stun": 1.8,
}
static var TEXT := {
	"ash": "It falls to glowing ash...",
	"rise": "It rises from its ashes!",
	"scatter": "The ash scatters",
	"soaked": "The ash is soaked",
	"grabbed": "Grabbed! Roll to break free",
	"lash": "The bush lashes out!",
	"flushed": "Flushed out!",
}
const KINDS := ["ashwing", "briar"]

const C_FLAME := Color(1.0, 0.72, 0.3)
const C_CORE := Color(1.0, 0.94, 0.66)
const C_ASH := Color(0.3, 0.27, 0.27)
const C_LEAF := Color(0.26, 0.42, 0.2)
const C_LEAF_HI := Color(0.36, 0.56, 0.26)
const C_THORN := Color(0.66, 0.6, 0.42)
const C_BARK := Color(0.33, 0.24, 0.15)


static func voice(kind: String) -> String:
	return String(VOICE.get(kind, kind))


static func has(kind: String) -> bool:
	return kind in KINDS


## Just set up (enemy.gd setup).
static func setup(e) -> void:
	match e.kind:
		"ashwing":
			e.state = "rest"
		"briar":
			e.state = "hide"
			e.submerged = true
			e.set_meta("near_t", 0.0)
			e.set_meta("calm_t", 0.0)


# --- behaviour (enemy.gd _physics_process) ---------------------------------------------

static func act(e, delta: float, dir: Vector2, dist: float, p) -> void:
	match e.kind:
		"ashwing":
			_ashwing(e, delta, dir, dist, p)
		"briar":
			_briar(e, delta, dir, dist, p)


static func _ashwing(e, delta: float, dir: Vector2, dist: float, p) -> void:
	e.burn_t = 0.0  # (fire itself: it doesn't burn)
	match e.state:
		"ashes":
			e.velocity = Vector2.ZERO
			if e.soaked > 0.0 or e.main.in_water(e.global_position):
				e.main.fx_text(e.global_position + Vector2(0, -24), TEXT["soaked"], Color(0.6, 0.8, 0.95))
				scatter(e)
				return
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.set_meta("reborn", true)
				e.hp = e.max_hp * float(RULES["rise"])
				e.state = "rest"
				e.state_t = 1.0
				e.main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["rise"], C_FLAME)
				e.main.fx_burst(e.global_position, Vector2.UP, C_FLAME, 22, 220.0)
				e.main.fx_ring(e.global_position, C_FLAME, 50.0, 0.4, 3.0)
				e.main.light_flash(e.global_position, C_FLAME, 1.4, 1.6, 0.35)
				e.main.sfx("burn", 1.2, -2.0)
		"wind":
			e.velocity = Vector2.ZERO
			if not e.glinted:
				e.aim_dir = dir
				e.swoop_speed = maxf(float(RULES["dive"]), maxf(0.0, dist - (e.radius + p.radius)) / (e.GLINT_LEAD * 0.85))
			if e._wind(delta, maxf(0.0, dist - (e.radius + p.radius)) / e.swoop_speed):
				e.state = "dive"
				e.state_t = 0.42
				e.lunge_hit = false
				e.set_meta("trail_t", 0.0)
		"dive":
			e.state_t -= delta
			e.velocity = e.aim_dir * e.swoop_speed
			if not e.lunge_hit and dist < e.radius + p.radius + 6.0:
				e.lunge_hit = true
				p.receive_attack(e.dmg, e)
			var tt: float = float(e.get_meta("trail_t", 0.0)) - delta
			if tt <= 0.0:
				tt = 0.12
				e.main.add_flame(e.global_position, 16.0, float(RULES["trail"]))
			e.set_meta("trail_t", tt)
			if e.state_t <= 0.0:
				e._end_attack("rest", 1.1)
		"rest", "recover", "idle":
			e.state_t -= delta
			e._circle(dir, dist, 130.0, e.speed * 0.8)
			if e.state_t <= 0.0:
				e.state = "hover"
		_:
			if dist < float(RULES["reach"]) and e.main.request_attack(e):
				e._begin_wind("wind", 0.55)
				e.main.sfx("warn_wisp", 0.75, -2.0)
				e.aim_dir = dir
			else:
				var bob := Vector2(sin(Time.get_ticks_msec() * 0.004 + e.get_instance_id()), 0.0) * 30.0
				e._circle(dir, dist, 130.0, e.speed)
				e.velocity += bob


static func _briar(e, delta: float, dir: Vector2, dist: float, p) -> void:
	e.velocity = Vector2.ZERO
	var main = e.main
	match e.state:
		"hide":
			e.submerged = true
			if e.burn_t > 0.0 or _fire_near(e):
				flush(e)
				return
			var near: float = e.global_position.distance_to(p.global_position)
			var nt: float = float(e.get_meta("near_t", 0.0))
			nt = nt + delta if near < 220.0 else 0.0
			e.set_meta("near_t", nt)
			if (near < float(RULES["spring"]) or nt > float(RULES["restless"])) and main.clear_line(e.global_position, p.global_position) and not p.dead:
				e.submerged = false
				e.aware = true
				e._begin_wind("wind_grab", 0.5)
				e.lunge_dir = (p.global_position - e.global_position).normalized()
				main.fx_text(e.global_position + Vector2(0, -e.radius - 18.0), TEXT["lash"], Color(0.75, 0.9, 0.5))
				main.sfx("warn_bloomcap", 0.7, -2.0)
		"wind_grab":
			e.submerged = false
			if not e.glinted:
				e.lunge_dir = dir
			if e._wind(delta):
				var to: Vector2 = p.global_position - e.global_position
				if to.length() <= float(RULES["grab"]) + p.radius and p.iframes <= 0.0 and not p.in_air() and main.clear_line(e.global_position, p.global_position):
					e.state = "grab"
					e.state_t = float(RULES["hold"])
					e.set_meta("tick", 0.5)
					if main.trap_view != null:
						main.trap_view.root_t = maxf(main.trap_view.root_t, float(RULES["hold"]))
					main.fx_text(p.global_position + Vector2(0, -40), TEXT["grabbed"], Color(0.8, 0.95, 0.6))
					main.sfx("swing_heavy", 0.7, -2.0)
				else:
					e._end_attack("rooted", 1.0)
		"grab":
			e.state_t -= delta
			var held: bool = main.trap_view != null and main.trap_view.root_t > 0.0
			if not held or p.dead:
				e._end_attack("rooted", 1.2)  # (rolled free)
				return
			var to: Vector2 = e.global_position - p.global_position
			if to.length() > e.radius + p.radius + 10.0:
				p.knock = to.normalized() * float(RULES["pull"])
			var tick: float = float(e.get_meta("tick", 0.5)) - delta
			if tick <= 0.0:
				tick = 0.5
				p.receive_attack(float(RULES["squeeze"]), e, true)
			e.set_meta("tick", tick)
			if e.state_t <= 0.0:
				if main.trap_view != null:
					main.trap_view.root_t = 0.0
				e._end_attack("rooted", 1.0)
		"wind_swipe":
			if not e.glinted:
				e.lunge_dir = dir
			if e._wind(delta):
				main.fx_cone(e.global_position, e.lunge_dir, 72.0, deg_to_rad(55.0), Color(0.6, 0.9, 0.4))
				main.sfx("swing_heavy", 0.9)
				var to: Vector2 = p.global_position - e.global_position
				if to.length() <= 72.0 + p.radius and absf(e.lunge_dir.angle_to(to)) <= deg_to_rad(55.0):
					p.receive_attack(e.dmg, e)
				e._end_attack("rooted", 1.0)
		_:  # rooted: out of hiding, it shuffles at you and swipes
			e.submerged = false
			e.state_t -= delta
			var ct: float = float(e.get_meta("calm_t", 0.0)) + delta
			if e.flash > 0.0:
				ct = 0.0
			e.set_meta("calm_t", ct)
			if ct > float(RULES["hide_after"]) and dist > 150.0:
				e.state = "hide"
				e.set_meta("near_t", 0.0)
				e.set_meta("calm_t", 0.0)
				main.fx_burst(e.global_position, Vector2.UP, C_LEAF, 8, 60.0)
				return
			if e.state_t > 0.0:
				return
			if dist < 70.0 and main.request_attack(e):
				e._begin_wind("wind_swipe", 0.6)
				main.sfx("warn_bloomcap", 0.9, -2.0)
			elif dist < 9000.0:
				e.velocity = dir * e.speed


static func _fire_near(e) -> bool:
	for f in e.main.flames:
		if e.global_position.distance_to(f["pos"]) < float(f["r"]) + e.radius + 20.0:
			return true
	return false


## Fire flushes a hiding briar: it reels, burning.
static func flush(e) -> void:
	if e.kind != "briar" or e.dead or e.state != "hide":
		return
	e.submerged = false
	e.aware = true
	e.state = "rooted"
	e.state_t = 0.5
	e.stun = float(RULES["stun"])
	e.set_meta("calm_t", 0.0)
	e.main.Reactions.apply(e.main, e, "burning", float(e.main.Reactions.STATES["burning"]["seconds"]), "fire")
	e.main.fx_text(e.global_position + Vector2(0, -e.radius - 20.0), TEXT["flushed"], Color(1.0, 0.65, 0.35))
	e.main.fx_burst(e.global_position, Vector2.UP, Color(1.0, 0.55, 0.25), 14, 140.0)


## An ashwing's ash, struck or soaked: it won't rise again.
static func scatter(e) -> void:
	e.set_meta("scattered", true)
	e.hp = 0.0
	e.take_hit(1.0, Vector2.ZERO, 0.0)


## A blow lands (enemy.gd take_hit, before anything else). True stops it there.
static func intercept(e, _amount: float, _dir: Vector2, _heavy: bool) -> bool:
	match e.kind:
		"ashwing":
			if e.state == "ashes" and not e.get_meta("scattered", false):
				e.set_meta("scattered", true)
				e.hp = 0.0
				e.main.fx_text(e.global_position + Vector2(0, -24), TEXT["scatter"], Color(0.8, 0.75, 0.7))
				e.main.fx_burst(e.global_position, Vector2.ZERO, C_ASH.lightened(0.3), 16, 180.0)
		"briar":
			if e.state == "hide":
				# Struck while hiding (a spell that finds it): it's out.
				e.submerged = false
				e.aware = true
				e.state = "rooted"
				e.state_t = 0.4
	return false


## Its health reached nothing (enemy.gd take_hit). True keeps it standing.
static func on_lethal(e) -> bool:
	if e.kind != "ashwing" or e.get_meta("scattered", false) or e.get_meta("reborn", false):
		return false
	e.hp = 1.0
	e.burn_t = 0.0
	e._end_attack("ashes", float(RULES["ash"]))
	e.velocity = Vector2.ZERO
	e.knock = Vector2.ZERO
	e.main.fx_text(e.global_position + Vector2(0, -e.radius - 20.0), TEXT["ash"], Color(0.85, 0.7, 0.6))
	e.main.fx_burst(e.global_position, Vector2.ZERO, C_ASH, 18, 160.0)
	e.main.sfx("burn", 0.6, -2.0)
	return true


# --- drawing (enemy.gd _draw, with its Pens) ----------------------------------------------

static func draw(e, p, glow, t: float, f: Vector2) -> void:
	match e.kind:
		"ashwing":
			_draw_ashwing(e, p, glow, t, f)
		"briar":
			_draw_briar(e, p, glow, t, f)


static func _draw_ashwing(e, p, glow, t: float, f: Vector2) -> void:
	var r: float = e.radius
	if e.state == "ashes":
		var k: float = 1.0 - clampf(e.state_t / float(RULES["ash"]), 0.0, 1.0)
		p.oval(Vector2(0, 4), Vector2(r * 1.2, r * 0.6), 0.0, C_ASH, 18)
		p.oval(Vector2(-2, 1), Vector2(r * 0.8, r * 0.4), 0.0, C_ASH.lightened(0.12), 16)
		for i in 5:
			var at := Vector2(cos(i * 1.7) * r * 0.7, 3.0 + sin(i * 2.3) * r * 0.25)
			glow.circle(at, 1.5 + 2.0 * k * (0.6 + 0.4 * sin(t * 8.0 + i)), Color(1.0, 0.5, 0.2, 0.5 + 0.5 * k), 8)
		if k > 0.5:
			glow.circle(Vector2(0, -2), r * 0.6 * (k - 0.5) * 2.0, Color(C_FLAME, 0.5), 14)
		return
	var s := f.orthogonal()
	var flap := sin(e._flap * 2.2) * 0.5 + 0.5
	var dive: bool = e.state == "dive"
	var gather: float = e._ease("gather", e._wk(0.55) if e.state == "wind" else 0.0, 12.0)
	var span := r * (1.6 + 0.7 * flap) * (0.6 if dive else 1.0) * (1.0 - 0.3 * gather)
	# A tail of flame behind.
	for i in 4:
		var u := (i + 1) / 4.0
		glow.circle(-f * r * (0.8 + u * 1.3) + s * sin(t * 7.0 + u * 5.0) * 3.0, r * (0.6 - u * 0.35), Color(C_FLAME, 0.7 - u * 0.4), 12)
	# Wings: fans of flame feathers.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = s * sgn * r * 0.45 - f * 1.5
		for j in 3:
			var d: Vector2 = (s * sgn * (1.0 - 0.25 * j) - f * (0.25 + 0.35 * j) + f * 0.3 * flap).normalized()
			e._feather(p, root, d, span * (1.0 - 0.18 * j), r * 0.55, Color(0.95, 0.42 + 0.1 * j, 0.18), 1.0)
	p.egg(Vector2.ZERO, Vector2(r * 1.05, r * 0.7), f.angle(), e.color)
	p.egg(f * 1.0 + Vector2(-1, -1.5), Vector2(r * 0.6, r * 0.38), f.angle(), e.color.lightened(0.25), false)
	var head := f * r * 0.95
	p.ball(head, r * 0.48, e.color.lightened(0.1))
	p.tri(head + f * r * 0.45 + s * 2.0, head + f * r * 0.95, head + f * r * 0.45 - s * 2.0, Color(0.95, 0.8, 0.35))
	glow.circle(head + f * 1.5 + s * 2.2, 1.3, C_CORE, 8)
	glow.circle(head + f * 1.5 - s * 2.2, 1.3, C_CORE, 8)
	glow.circle(Vector2.ZERO, r * 1.6, Color(C_FLAME, 0.12 + 0.1 * gather), 18)
	if e.get_meta("reborn", false):
		glow.circle(Vector2.ZERO, r * 0.5, Color(C_CORE, 0.4), 12)  # (reborn: it burns brighter)


static func _draw_briar(e, p, glow, t: float, f: Vector2) -> void:
	var r: float = e.radius
	var hidden: bool = e.state == "hide"
	var open: float = e._ease("open", 0.0 if hidden else 1.0, 6.0)
	var sway := sin(t * 0.9 + e.get_instance_id()) * 1.2
	# The bush: a mound of leaves, thorns poking through.
	var lumps := [Vector2(-r * 0.55, 2), Vector2(r * 0.55, 2), Vector2(0, -r * 0.35), Vector2(-r * 0.3, -r * 0.1 + 3), Vector2(r * 0.32, -r * 0.05 + 3)]
	for i in lumps.size():
		var at: Vector2 = lumps[i] + Vector2(sway * (0.5 + 0.2 * i), 0) + Vector2(0, -open * 3.0)
		p.ball(at, r * (0.62 if i < 3 else 0.48), C_LEAF.lightened(0.06 * (i % 2)))
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		var at := Vector2.from_angle(a) * r * 0.75
		p.tri(at + Vector2.from_angle(a + 1.6) * 2.0, at + Vector2.from_angle(a) * (4.5 + 2.0 * open), at - Vector2.from_angle(a + 1.6) * 2.0, C_THORN)
	for i in 4:
		p.circle(Vector2(cos(i * 1.9) * r * 0.5, sin(i * 2.7) * r * 0.4 - 3.0), 2.4, C_LEAF_HI, 8)
	if hidden:
		# Now and then two eyes blink in the leaves: the only tell.
		if fmod(t + e.get_instance_id() * 0.37, 5.0) < 0.35:
			glow.circle(Vector2(-3, -2), 1.1, Color(1.0, 0.85, 0.4, 0.7), 6)
			glow.circle(Vector2(3, -2), 1.1, Color(1.0, 0.85, 0.4, 0.7), 6)
		return
	# Out of hiding: a maw in the leaves, and thorny arms.
	var s := f.orthogonal()
	var reach := 0.0
	if e.state == "wind_grab":
		reach = e._wk(0.5)
	elif e.state == "grab":
		reach = 1.0
	elif e.state == "wind_swipe":
		reach = 0.6 * e._wk(0.6)
	for sgn in [-1.0, 1.0]:
		var a: Vector2 = s * sgn * r * 0.6
		var b: Vector2 = a + (f * (10.0 + 14.0 * reach) + s * sgn * (8.0 - 4.0 * reach))
		p.tube(PackedVector2Array([a, (a + b) * 0.5 + s * sgn * 3.0, b]), PackedFloat32Array([3.2, 2.6, 1.8]), C_BARK)
		p.tri(b + s * 2.0, b + f * 5.0, b - s * 2.0, C_THORN)
	p.oval(f * r * 0.25 + Vector2(0, -2), Vector2(r * 0.42, r * 0.26 * (0.6 + 0.4 * open)), f.angle(), Palette.OUTLINE, 14)
	for k in 4:
		var at: Vector2 = f * r * 0.25 + s * (k - 1.5) * 2.6 + Vector2(0, -4)
		p.tri(at - s * 1.0, at + Vector2(0, 2.5), at + s * 1.0, C_THORN.lightened(0.2))
	glow.circle(f * r * 0.1 + s * 4.0 + Vector2(0, -7), 1.4, Color(1.0, 0.8, 0.35), 8)
	glow.circle(f * r * 0.1 - s * 4.0 + Vector2(0, -7), 1.4, Color(1.0, 0.8, 0.35), 8)


## Telegraphs over the darkness (enemy.gd _draw_overlay, its overlay Pen).
static func overlay(e, o) -> void:
	var danger := Palette.DANGER
	match e.kind:
		"ashwing":
			if e.state == "wind":
				o.quad(Vector2.ZERO, e.aim_dir * 170.0, 2.5, Color(danger, 0.35))
		"briar":
			if e.state == "wind_grab":
				var k: float = e._wk(0.5)
				o.quad(Vector2.ZERO, e.lunge_dir * float(RULES["grab"]), 2.0 + 3.0 * k, Color(danger, 0.25 + 0.35 * k))
			elif e.state == "grab" and e.main.player != null:
				var to: Vector2 = e.main.player.global_position - e.global_position
				o.quad(Vector2.ZERO, to, 3.0, Color(0.35, 0.5, 0.25, 0.9))
				for i in 4:
					var at := to * (0.2 + 0.2 * i)
					o.tri(at + to.normalized().orthogonal() * 4.0, at + to.normalized() * 3.0, at - to.normalized().orthogonal() * 1.0, Color(C_THORN, 0.9))
			elif e.state == "wind_swipe":
				var la: float = e.lunge_dir.angle()
				o.wedge(Vector2.ZERO, 72.0, la - deg_to_rad(55.0), la + deg_to_rad(55.0), Color(danger, 0.1 + 0.15 * e._wk(0.6)), 10)
