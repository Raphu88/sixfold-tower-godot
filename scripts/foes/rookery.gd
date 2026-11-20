extends "res://scripts/enemy.gd"
## THE ROOKERY (kind "rookery"; enemy.gd SUBKINDS spawns it with this
## script): the Gryphon's tower's nest of twigs on a stone ledge, set against
## the nearest wall when it's placed. It never moves and has no blow of its
## own. Once it has seen you it hatches a bat now and then: an egg rocks and
## cracks (a ring on the floor warns of it), then a bat flies out. No more
## than RULES "alive" of its bats fly at once, and it holds RULES "most" eggs
## in all; then it's empty. Break the nest and no more come. Words and
## numbers: RULES, TEXT.

static var RULES := {
	"first": 3.0,  # seconds before its first egg hatches once it has seen you
	"every": 7.0,  # seconds between eggs
	"hatch": 1.2,  # an egg rocks and cracks this long first (the warning)
	"alive": 2.0,  # its bats on the wing at once, at most
	"most": 3.0,  # eggs it holds in all
	"wall": 110.0,  # it settles against a wall this near
}
static var TEXT := {"hatch": "An egg hatches", "empty": "The nest is empty"}

const C_TWIG := Color(0.5, 0.38, 0.26)
const C_LEDGE := Color(0.62, 0.62, 0.66)
const C_EGG := Color(0.82, 0.88, 0.92)

var hatch_t := 0.0
var hatched := 0
var bats: Array = []
var wall_dir := Vector2.ZERO  # toward the wall it's set against (zero: on the floor)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "nest"
	hatch_t = float(RULES["first"])


func _ready() -> void:
	super._ready()
	if main != null and main.layout_on:
		_settle.call_deferred()


## Against the nearest wall within RULES "wall": the ledge sits on it.
func _settle() -> void:
	if not is_inside_tree() or main == null:
		return
	var best := INF
	var best_dir := Vector2.ZERO
	for k in 16:
		var d := Vector2.from_angle(k * TAU / 16.0)
		var step := 8.0
		while step <= float(RULES["wall"]):
			if main.is_solid(global_position + d * step):
				if step < best:
					best = step
					best_dir = d
				break
			step += 8.0
	if best_dir == Vector2.ZERO:
		return
	wall_dir = best_dir
	var to: Vector2 = global_position + best_dir * maxf(0.0, best - radius - 6.0)
	if not main.is_solid(to):
		global_position = to
	face = -wall_dir


func _act(delta: float, _dir: Vector2, dist: float, _p) -> void:
	velocity = Vector2.ZERO
	if not _told and dist < 400.0:
		_told = true
		main.tip("rookery")
	if wall_dir != Vector2.ZERO:
		face = -wall_dir
	bats = bats.filter(func(b): return is_instance_valid(b) and not b.dead)
	match state:
		"hatch":
			state_t -= delta
			if state_t <= 0.0:
				_hatch()
				state = "nest" if hatched < int(RULES["most"]) else "empty"
				hatch_t = float(RULES["every"])
				if state == "empty":
					main.fx_text(global_position + Vector2(0, -radius - 26.0), TEXT["empty"], Color(0.85, 0.85, 0.8))
		"nest":
			hatch_t -= delta
			if hatch_t <= 0.0 and dist < 520.0 and bats.size() < int(RULES["alive"]) and hatched < int(RULES["most"]):
				state = "hatch"
				state_t = float(RULES["hatch"])
				main.sfx("warn_bat", 0.7, -4.0)


func _hatch() -> void:
	hatched += 1
	var out := -wall_dir if wall_dir != Vector2.ZERO else Vector2.DOWN
	var b = main.spawn_enemy("bat", global_position + out * (radius + 14.0))
	b.aware = true
	b.notice_t = 0.0
	b.state = "rest"
	b.state_t = 0.6
	b.set_meta("hatched", true)
	bats.append(b)
	main.fx_burst(global_position + out * radius, out, C_EGG, 10, 160.0)
	main.fx_text(global_position + Vector2(0, -radius - 26.0), TEXT["hatch"], Color(0.85, 0.8, 0.95))
	main.sfx("wingbeat", 1.2, -4.0)


## It never moves: a blow shakes it but doesn't shift it.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	super.take_hit(amount, dir, 0.0, heavy, pierce)
	knock = Vector2.ZERO
	flinch = 0.0


func tide_push(_v: Vector2) -> void:
	pass  # (bolted to its ledge)


func _idle_state() -> String:
	return "nest"


# --- drawing ------------------------------------------------------------------------

## A stone ledge jutting from the wall, a ring of woven twigs on it, eggs in
## the nest (one rocking and cracking before it hatches); the wall side is
## `wall_dir` (drawn on the floor if it has no wall).
func _draw_own(p, t: float, f: Vector2) -> void:
	var w := wall_dir if wall_dir != Vector2.ZERO else Vector2.UP
	var s := w.orthogonal()
	if wall_dir != Vector2.ZERO:
		# The ledge: a slab from the wall, with a bracket under it.
		var slab := PackedVector2Array([w * (radius + 8.0) + s * (radius + 4.0), -w * (radius * 0.6) + s * (radius + 2.0),
			-w * (radius * 0.75), -w * (radius * 0.6) - s * (radius + 2.0), w * (radius + 8.0) - s * (radius + 4.0)])
		p.poly(slab, C_LEDGE, 1.6)
		p.quad(-w * (radius * 0.62) + s * radius, -w * (radius * 0.62) - s * radius, 1.6, C_LEDGE.darkened(0.3))
	# The nest: twigs woven round.
	p.oval(Vector2.ZERO, Vector2(radius + 1.6, radius * 0.8 + 1.6), 0.0, Palette.OUTLINE, 20)
	p.oval(Vector2.ZERO, Vector2(radius, radius * 0.8), 0.0, C_TWIG.darkened(0.2), 20)
	p.oval(Vector2(0, -1), Vector2(radius * 0.62, radius * 0.45), 0.0, C_TWIG.darkened(0.55), 16)
	for i in 10:
		var a := float(i) * TAU / 10.0 + 0.3
		var a2 := a + 0.9
		p.quad(Vector2(cos(a) * radius * 0.85, sin(a) * radius * 0.68), Vector2(cos(a2) * radius * 0.8, sin(a2) * radius * 0.64), 1.6, C_TWIG.lightened(0.1 * float(i % 3)))
	# Twigs sticking out.
	for i in 4:
		var a := float(i) * 1.7 + 0.5
		p.quad(Vector2(cos(a), sin(a) * 0.8) * radius * 0.9, Vector2(cos(a), sin(a) * 0.8) * (radius + 5.0), 1.2, C_TWIG)
	# Eggs left: one rocks and cracks as it hatches.
	var left := int(RULES["most"]) - hatched
	var rock := _wk(float(RULES["hatch"])) if state == "hatch" else 0.0
	for i in mini(left, 3):
		var at := Vector2(-4.0 + 4.5 * i, -2.0 + (1.5 if i == 1 else 0.0))
		var ang := 0.0
		if i == 0 and rock > 0.0:
			ang = sin(t * 30.0) * 0.4 * rock
		p.oval(at, Vector2(3.0, 3.8), ang, Palette.OUTLINE, 12)
		p.oval(at, Vector2(2.2, 3.0), ang, C_EGG, 12)
		p.circle(at + Vector2(0.8, -1.0), 0.5, C_EGG.darkened(0.35), 5)
		if i == 0 and rock > 0.4:
			p.quad(at + Vector2(-2.0, -0.5), at + Vector2(0.0, 0.8), 0.7, Palette.OUTLINE)
			p.quad(at + Vector2(0.0, 0.8), at + Vector2(1.8, -0.8), 0.7, Palette.OUTLINE)
			_glow.circle(at, 3.0, Color(1.0, 0.9, 0.7, 0.25 * rock), 10)


func _overlay_extra(o) -> void:
	if state == "hatch":
		var k := _wk(float(RULES["hatch"]))
		var out := -wall_dir if wall_dir != Vector2.ZERO else Vector2.DOWN
		var at := out * (radius + 14.0)
		o.arc(at, 14.0, 0.0, TAU, 2.0, Color(Palette.DANGER, 0.5 + 0.3 * k), 20)
		o.arc(at, 14.0 * (1.0 - k) + 4.0, 0.0, TAU, 1.5, Color(Palette.DANGER, 0.8), 16)
