extends "res://scripts/enemy.gd"
## THE BELLRINGER (kind "bellringer"; enemy.gd SUBKINDS spawns it with this
## script): a hunched tower servant with a hand bell. Found in every tower.
## It has no blow of its own and runs from you, keeping near the other
## monsters. Every few seconds it lifts its bell (a ring on the floor shows how
## far the sound will carry) and rings it: a pulse runs out, and every monster
## inside it is quickened for a while (enemy.gd haste_t: they get over their
## attacks sooner and move faster; their wind-ups and glints keep their
## timing). Strike it while the bell is up and the ring is lost. It teaches
## target priority: catch it first. Words and numbers: RULES, TEXT.

static var RULES := {
	"first": 2.5,  # seconds before its first ring once it has seen you
	"every": 6.0,  # seconds between rings
	"lift": 1.1,  # the bell held up before it rings (the warning)
	"reach": 220.0,  # how far the ring carries
	"haste": 5.0,  # seconds a rung monster stays quickened
	"quick": 1.35,  # ...this much quicker (enemy.gd haste_k)
	"flee": 170.0,  # it runs from you inside this
	"keep": 260.0,  # ...and drifts back toward you beyond this
}
static var TEXT := {"rung": "The bell quickens them", "hush": "The bell falls silent"}

const C_ROBE := Color(0.42, 0.36, 0.42)
const C_BELL := Color(0.86, 0.7, 0.32)
const C_SKIN_PALE := Color(0.72, 0.64, 0.56)

var ring_t := 0.0
var _rings := 0  # (how many times it has rung: tests)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "skulk"
	ring_t = float(RULES["first"])


func _act(delta: float, dir: Vector2, dist: float, _p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("bellringer")
	match state:
		"lift":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				_ring()
				state = "skulk"
				ring_t = float(RULES["every"])
		_:
			ring_t -= delta
			if dist < float(RULES["flee"]):
				var away := -dir
				if main.layout_on and main.is_solid(global_position + away * 40.0):
					away = (away + dir.orthogonal() * (1.0 if get_instance_id() % 2 == 0 else -1.0)).normalized()
				velocity = away * speed * 1.2
			elif dist > float(RULES["keep"]):
				velocity = dir * speed * 0.7
			else:
				velocity = dir.orthogonal() * speed * 0.4 * (1.0 if sin(Time.get_ticks_msec() * 0.0007 + get_instance_id()) > 0.0 else -1.0)
			if ring_t <= 0.0 and dist < 460.0 and _others_near() > 0:
				state = "lift"
				state_t = float(RULES["lift"])
				main.sfx_at(global_position, "shop_bell", 0.45, -10.0)


## Monsters (not itself, not another bellringer, not a beast) the ring would reach.
func _others_near() -> int:
	var n := 0
	for e in main.enemies():
		if e != self and e.kind != "bellringer" and not e.is_boss() and e.global_position.distance_to(global_position) < float(RULES["reach"]):
			n += 1
	return n


func _ring() -> void:
	_rings += 1
	var reach := float(RULES["reach"])
	main.fx_ring(global_position, C_BELL, reach, 0.55, 4.0)
	main.fx_ring(global_position, Color(1.0, 0.95, 0.75), reach * 0.6, 0.4, 2.0)
	main.sfx_at(global_position, "shop_bell", 0.6, 0.0)
	main.light_flash(global_position, C_BELL, 1.2, 1.2, 0.3)
	var any := false
	for e in main.enemies():
		if e == self or e.kind == "bellringer" or e.is_boss() or e.global_position.distance_to(global_position) > reach:
			continue
		e.haste_t = float(RULES["haste"])
		e.haste_k = float(RULES["quick"])
		main.fx_burst(e.global_position, Vector2.UP, C_BELL, 5, 120.0)
		any = true
	if any:
		main.fx_text(global_position + Vector2(0, -radius - 30.0), TEXT["rung"], C_BELL)


## Struck while its bell is up: the ring is lost.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var was := state == "lift"
	super.take_hit(amount, dir, force, heavy, pierce)
	if was and not dead and dir != Vector2.ZERO:
		state = "skulk"
		ring_t = float(RULES["every"]) * 0.6
		main.fx_text(global_position + Vector2(0, -radius - 30.0), TEXT["hush"], Color(0.85, 0.85, 0.8))


func _idle_state() -> String:
	return "skulk"


# --- drawing ------------------------------------------------------------------------

## Seen from above: a hunched back under a hooded robe, a bald pate poking
## out, one thin arm with a brass bell (held up and shaking before it rings).
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var lift := _ease("lift", _wk(float(RULES["lift"])) if state == "lift" else 0.0, 12.0)
	var shuffle := sin(_stride * 1.4) * _move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 4.0 + f * (shuffle * sgn * 3.0 + 1.0), 2.6, C_ROBE.darkened(0.4))
	# The robe and its hunched back (a hump behind the head).
	var robe := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		var rr := radius * (1.0 + 0.12 * float(i % 2))
		robe.append(Vector2.from_angle(a) * rr - f * 1.5)
	p.poly(robe, C_ROBE, 1.5)
	p.egg(-f * 3.5, Vector2(6.5, 7.5), f.angle(), C_ROBE.lightened(0.07))
	p.arc(-f * 3.5, 5.0, f.angle() + 2.2, f.angle() + 4.1, 1.0, C_ROBE.darkened(0.3), 8)
	# The off arm clutching the robe; the bell arm out, up as it lifts.
	p.limb(s * radius * 0.7, s * radius * 0.6 + f * 4.0, C_ROBE.darkened(0.1), 2.8)
	var hand: Vector2 = -s * (radius * 0.75 + 3.0 * lift) + f * (6.0 + 5.0 * lift) + Vector2(0, -10.0 * lift)
	p.limb(-s * radius * 0.65, hand, C_ROBE.darkened(0.1), 2.6)
	p.ball(hand, 2.0, C_SKIN_PALE)
	var shake := sin(t * 40.0) * 3.0 * lift
	var bell := hand + f * 3.0 + s.rotated(0.0) * shake * 0.3 + Vector2(0, 2.0)
	var bp := PackedVector2Array([bell + Vector2(-2.0, -3.0), bell + Vector2(2.0, -3.0), bell + Vector2(4.5, 3.5), bell + Vector2(-4.5, 3.5)])
	p.poly(bp, C_BELL, 1.3)
	p.quad(bell + Vector2(-4.5, 3.5), bell + Vector2(4.5, 3.5), 1.4, C_BELL.lightened(0.25))
	p.circle(bell + Vector2(shake * 0.4, 4.6), 1.2, C_BELL.darkened(0.4), 8)
	if lift > 0.1:
		_glow.circle(bell, 5.0 + 3.0 * lift, Color(1.0, 0.9, 0.55, 0.25 * lift), 14)
	# The head: a bald pate poking out of the hood, peering at you.
	p.ball(f * 4.5, 4.4, C_SKIN_PALE)
	p.arc(f * 3.5, 5.6, f.angle() + 1.4, f.angle() + TAU - 1.4, 1.8, C_ROBE.darkened(0.2), 10)
	for sgn in [-1.0, 1.0]:
		p.circle(f * 7.0 + s * sgn * 1.7, 0.9, Palette.OUTLINE, 6)


func _overlay_extra(o) -> void:
	if state == "lift":
		# How far the ring will carry: a gold circle, its edge closing in.
		var k := _wk(float(RULES["lift"]))
		var reach := float(RULES["reach"])
		o.circle(Vector2.ZERO, reach, Color(C_BELL, 0.05 + 0.07 * k), 48)
		o.arc(Vector2.ZERO, reach, 0.0, TAU, 2.0, Color(C_BELL, 0.6), 48)
		o.arc(Vector2.ZERO, reach * (1.0 - k) + 8.0, 0.0, TAU, 1.5, Color(1.0, 0.95, 0.7, 0.8), 40)
