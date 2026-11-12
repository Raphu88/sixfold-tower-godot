extends RefCounted
## The deepfin: the Kraken's tower's own creature (enemy.gd TOWER_KINDS).
## It lives in deep water (kraken_floor.gd): only a fin and a wake show as
## it shadows you along the bank, and nothing can touch it down there. When
## you come near the water it rises, glints, and LEAPS out at you, jaws
## first. Then it's on dry stone: it thrashes a moment (your opening), soaked
## through, so lightning arcs through it (reactions.gd Conduct) and every
## blow lands harder, before it drags itself back to the water. Out of the
## water too long (its pool drained by a sluice wheel) it dries out and
## weakens. With no deep water to live in, it keeps to the shallows as a
## lurker does. Its numbers are in DEEPFIN (the Data editor's "Monsters").

const Reactions := preload("res://scripts/reactions.gd")

static var DEEPFIN := {
	"leap_range": 175.0,  # it leaps at you from this near
	"leap_speed": 470.0,
	"rise": 0.45,  # seconds surfacing before the wind-up
	"wind": 0.5,
	"stranded": 2.2,  # seconds thrashing on land after a leap (open)
	"crawl": 60.0,  # how fast it drags itself back
	"exposed": 0.5,  # how much more it takes from everything out of the water
	"dry_after": 7.0,  # seconds out of the water before it dries out...
	"dry_dps": 4.0,  # ...and loses this much health a second
}
static var TEXT := {"stranded": "Stranded!", "dry": "Drying out"}


static func setup(e) -> void:
	e.state = "swim"
	e.submerged = true
	e.set_meta("out_t", 0.0)
	e.set_meta("dry_tick", 1.0)


static func act(e, delta: float, dir: Vector2, dist: float, p) -> void:
	var D := DEEPFIN
	var main = e.main
	var tf = main.get("tower_floor")
	if tf == null or not tf.has_method("deep_at"):
		# No deep water on this floor: it keeps to the shallows like a lurker.
		e.kind = "lurker"
		e.state = "sub"
		e.submerged = true
		return
	var pos: Vector2 = e.global_position
	var in_deep: bool = tf.deep_at(pos)
	match e.state:
		"swim":
			e.submerged = true
			if not in_deep:
				_strand(e, "crawl", 0.0)  # (its water drained away under it)
				return
			var want: Vector2 = tf.deep_toward(pos, p.global_position)
			var to: Vector2 = want - pos
			e.velocity = to.normalized() * e.speed if to.length() > 6.0 else Vector2.ZERO
			if e.velocity != Vector2.ZERO and not tf.deep_at(pos + e.velocity.normalized() * (e.radius + 4.0)):
				e.velocity = Vector2.ZERO  # (it never swims out of the water on its own)
			if dist < float(D["leap_range"]) and main.clear_line(pos, p.global_position) and main.request_attack(e):
				e.state = "rise"
				e.state_t = float(D["rise"])
				main.sfx("bubble", 0.7, -4.0)
		"rise":
			e.submerged = false
			e.velocity = Vector2.ZERO
			e.state_t -= delta
			if e.state_t <= 0.0:
				e._begin_wind("wind", float(D["wind"]))
				main.sfx_kind("warn", "lurker", "warn_knight", 0.8, -2.0)
				e.lunge_dir = dir
		"wind":
			e.submerged = false
			e.velocity = Vector2.ZERO
			if not e.glinted:
				e.lunge_dir = dir
			if e._wind(delta, maxf(0.0, dist - (e.radius + p.radius + 8.0)) / float(D["leap_speed"])):
				e.state = "lunge"
				e.state_t = clampf((dist + 30.0) / float(D["leap_speed"]), 0.2, 0.55)
				e.lunge_hit = false
				e.attack_from = pos
				main.sfx("spell_water", 1.1, -6.0)
				main.fx_burst(pos, e.lunge_dir, Color(0.6, 0.85, 0.95), 10, 160.0)
		"lunge":
			e.submerged = false
			e.state_t -= delta
			e.velocity = e.lunge_dir * float(D["leap_speed"])
			if not e.lunge_hit and dist < e.radius + p.radius + 8.0:
				e.lunge_hit = true
				p.receive_attack(e.dmg, e)
			if e.state_t <= 0.0:
				if in_deep:
					e._end_attack("dive", 0.3)
				else:
					e._end_attack("stranded", float(D["stranded"]))
					_strand(e, "stranded", float(D["stranded"]))
		"stranded":
			e.submerged = false
			e.velocity = Vector2.ZERO
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "crawl"
		"crawl":
			e.submerged = false
			if in_deep:
				e.state = "dive"
				e.state_t = 0.3
				main.sfx("bubble", 0.9, -6.0)
			else:
				var home: Vector2 = tf.nearest_deep(pos, 520.0)
				e.velocity = (home - pos).normalized() * float(D["crawl"]) if home != Vector2.INF else Vector2.ZERO
		"dive":
			e.velocity = Vector2.ZERO
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "swim"
				e.submerged = in_deep
		_:
			e.state = "swim" if in_deep else "crawl"
	# Out of the water: soaked through (lightning arcs through it) and
	# exposed; too long out and it dries.
	if not e.submerged:
		if e.soaked < 1.0:
			Reactions.apply(main, e, "soaked", 3.0, "deepfin")
		if not in_deep:
			e.hollow_t = maxf(e.hollow_t, 0.2)
			e.hollow_k = float(D["exposed"])
	var out_t: float = e.get_meta("out_t", 0.0)
	out_t = 0.0 if in_deep else out_t + delta
	e.set_meta("out_t", out_t)
	if out_t > float(D["dry_after"]):
		var tick: float = e.get_meta("dry_tick", 1.0) - delta
		if tick <= 0.0:
			tick = 1.0
			if out_t < float(D["dry_after"]) + 1.1:
				main.fx_text(pos + Vector2(0, -e.radius - 24.0), TEXT["dry"], Color(0.8, 0.75, 0.6))
			e.take_hit(float(D["dry_dps"]), Vector2.ZERO, 0.0)
		e.set_meta("dry_tick", tick)


static func _strand(e, next: String, seconds: float) -> void:
	e.state = next
	e.state_t = seconds
	e.submerged = false
	e.main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), TEXT["stranded"], Color(0.6, 0.85, 0.95))
	e.main.fx_burst(e.global_position, Vector2.UP, Color(0.6, 0.85, 0.95), 8, 120.0)


## Never staggered differently: a parried leap leaves it stranded where it lands.
static func parried(_e, _perfect: bool) -> bool:
	return false


# --- drawing -----------------------------------------------------------------------

const C_WATER := Color(0.6, 0.85, 0.95)
const C_FIN := Color(0.5, 0.72, 0.78)
const C_BELLY := Color(0.72, 0.78, 0.7)
const C_TOOTH := Color(0.97, 0.95, 0.88)


## Under water: a dark shape, a fin cutting the surface and its wake.
## Out of the water: a heavy armoured fish with a jaw full of teeth, fins
## splayed, thrashing when stranded, dripping.
static func draw(e, p, glow, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var col: Color = e.color
	if e.submerged and e.state in ["swim", "dive"]:
		p.oval(Vector2.ZERO, Vector2(e.radius * 1.6, e.radius * 0.7), f.angle(), Color(0.02, 0.08, 0.12, 0.45))
		var fin := f * 3.0
		p.poly(PackedVector2Array([fin + f * 6.0, fin - f * 7.0 + Vector2(0, -2), fin - f * 4.0 + Vector2(0, -12)]), col.lightened(0.15), 1.2)
		var spd: float = e.velocity.length()
		if spd > 10.0:
			for sgn in [-1.0, 1.0]:
				p.quad(fin + f * 4.0, fin - f * 22.0 + s * sgn * 12.0, 1.4, Color(C_WATER, 0.45), 0.3)
		for k in 2:
			var ph := fmod(t * 0.7 + k * 0.5, 1.0)
			p.arc(Vector2.ZERO, 8.0 + ph * 16.0, 0.0, TAU, 1.3, Color(C_WATER, 0.4 * sin(ph * PI)), 20)
		glow.circle(f * 7.0 + s * 3.0, 1.2, Color(0.75, 1.0, 0.85, 0.7), 8)
		glow.circle(f * 7.0 - s * 3.0, 1.2, Color(0.75, 1.0, 0.85, 0.7), 8)
		return
	var rise := 1.0
	if e.state == "rise":
		rise = clampf(1.0 - e.state_t / float(DEEPFIN["rise"]), 0.25, 1.0)
	var thrash := 0.0
	if e.state in ["stranded", "crawl"]:
		thrash = sin(t * (14.0 if e.state == "stranded" else 7.0)) * (1.0 if e.state == "stranded" else 0.5)
	if e.state in ["rise", "wind", "dive"]:
		p.arc(Vector2.ZERO, e.radius + 5.0, 0.0, TAU, 2.0, Color(C_WATER, 0.45), 24)
		p.arc(Vector2.ZERO, e.radius + 9.0 + sin(t * 4.0) * 1.5, 0.0, TAU, 1.2, Color(C_WATER, 0.25), 24)
	# The body: one thick tube, a little curled when it thrashes.
	var spine := PackedVector2Array()
	var w := PackedFloat32Array()
	var widths := [15.0, 20.0, 18.0, 13.0, 8.0, 3.0]
	for k in 6:
		var u := k / 5.0
		var bend := s * (sin(t * 5.0 - u * 3.5) * 2.5 * u * minf(1.0, e.velocity.length() / 60.0) + thrash * 7.0 * u * u)
		spine.append((f * e.radius * (1.2 - 2.7 * u) + bend) * rise)
		w.append(widths[k] * rise)
	# Pectoral fins, splayed wide.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = spine[1]
		p.poly(PackedVector2Array([root + s * sgn * 7.0 * rise, root + (s * sgn * 17.0 - f * 7.0 + f * thrash * sgn * 3.0) * rise, root + (s * sgn * 12.0 - f * 12.0) * rise, root - f * 6.0 * rise]), C_FIN.darkened(0.2), 1.3)
	var tail: Vector2 = spine[5]
	var td := (spine[5] - spine[4]).normalized()
	p.poly(PackedVector2Array([tail, tail + (td * 9.0 + td.orthogonal() * 8.0) * rise, tail + td * 4.0 * rise, tail + (td * 9.0 - td.orthogonal() * 8.0) * rise]), C_FIN.darkened(0.25), 1.3)
	p.tube(spine, w, col)
	# Armour plates down its back and a crest.
	for k in range(1, 5):
		p.circle(spine[k] + Vector2(-0.6, -1.0), (3.2 - k * 0.4) * rise, Color(col.lightened(0.3), 0.85), 10)
	p.poly(PackedVector2Array([spine[1] - s * 1.5, spine[3] + Vector2(0, -7.0 * rise), spine[3] + s * 1.5]), C_FIN, 1.0)
	# The jaw: wide open in the wind-up and the leap, teeth showing.
	var open: float = e._ease("jaw", 7.0 if e.state in ["wind", "lunge"] else (3.0 if e.state == "stranded" else 1.2), 16.0)
	var head: Vector2 = spine[0]
	p.tri(head + f * 5.0 * rise + s * open, head - f * 5.0 * rise, head + f * 5.0 * rise - s * open, Color(0.12, 0.05, 0.07))
	if open > 2.5:
		for sgn in [-1.0, 1.0]:
			for k in 3:
				var at: Vector2 = head + f * (1.0 + k * 1.4) * rise + s * sgn * (open - 0.5 - k * 0.8)
				p.tri(at, at - s * sgn * 2.0 + f * 0.6, at + f * 1.4, C_TOOTH)
	p.oval(head - f * 2.0 * rise, Vector2(5.0, 3.0) * rise, f.angle(), C_BELLY)
	glow.circle(head - f * 4.0 * rise + s * 5.0 * rise, 1.8, Color(0.85, 1.0, 0.7), 8)
	glow.circle(head - f * 4.0 * rise - s * 5.0 * rise, 1.8, Color(0.85, 1.0, 0.7), 8)
	# Dripping out of the water.
	if e.state in ["stranded", "crawl", "lunge"]:
		for k in 3:
			var ph := fmod(t * 1.3 + k * 0.33, 1.0)
			p.circle(spine[k + 1] + s * (k - 1) * 6.0 + Vector2(0, ph * 10.0), 1.4 * (1.0 - ph), Color(C_WATER, 0.7), 6)
