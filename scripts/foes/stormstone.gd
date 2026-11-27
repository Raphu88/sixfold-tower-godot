extends "res://scripts/enemy.gd"
## THE STORMSTONE (kind "stormstone"; enemy.gd SUBKINDS spawns it with this
## script): the Gryphon's tower's carved standing stone. It never moves. Once
## it has seen you it builds charge (its runes light one by one and sparks
## crawl over it); full, it picks whoever stands nearest within its reach,
## you or a monster, and a red line shows who (the line follows whoever is
## nearest until it glints). Then lightning arcs to them. It can't be
## parried: roll, or step back so something else is nearer. A monster it
## strikes takes double, is stunned a moment and left charged (a soaked one
## sets off Conduct); you're left charged. Lure them close. Nobody in reach:
## the charge goes into the ground. Words and numbers: RULES, TEXT.


static var RULES := {
	"charge": 5.0,  # seconds to build a full charge
	"aim": 0.8,  # the arc's warning (the red line)
	"reach": 230.0,  # how far it arcs
	"foe_mult": 2.0,  # it strikes monsters this much harder
	"stun": 0.6,  # a monster struck is stunned this long
}
static var TEXT := {"ground": "Grounded"}

const C_STONE := Color(0.52, 0.55, 0.62)
const C_RUNE := Color(0.8, 0.92, 1.0)
const C_BOLT := Color(0.95, 0.92, 0.55)

var charge := 0.0
var target = null
var _arcs := 0  # (tests)
var _struck = null  # (tests: what the last arc struck)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "build"


func _act(delta: float, _dir: Vector2, dist: float, _p) -> void:
	velocity = Vector2.ZERO
	if not _told and dist < 400.0:
		_told = true
		main.tip("stormstone")
	match state:
		"wind_arc":
			if not glinted:
				target = _nearest()
			if _wind(delta):
				_discharge()
				_end_attack("build", 0.0)
		_:
			if dist < 640.0:
				charge = minf(1.0, charge + delta / float(RULES["charge"]))
			if charge >= 1.0:
				_begin_wind("wind_arc", float(RULES["aim"]))
				target = _nearest()
				main.sfx("charge", 1.3, -4.0)


## Whoever stands nearest within its reach: the climber or a monster (not
## itself, nor anything under water).
func _nearest():
	var best = null
	var best_d := float(RULES["reach"])
	var p = main.player
	if p != null and not p.dead:
		var d: float = p.global_position.distance_to(global_position) - p.radius
		if d < best_d:
			best_d = d
			best = p
	for e in main.targets():
		if e == self or e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


func _discharge() -> void:
	charge = 0.0
	_arcs += 1
	var tg = target
	target = null
	_struck = null
	if tg == null or not is_instance_valid(tg) or tg.dead or tg.global_position.distance_to(global_position) > float(RULES["reach"]) + 40.0:
		main.fx_bolt([global_position + Vector2(0, -16), global_position + Vector2(randf_range(-18, 18), 14)], C_BOLT)
		main.fx_text(global_position + Vector2(0, -radius - 28.0), TEXT["ground"], C_RUNE)
		main.sfx("zap", 0.7, -6.0)
		return
	_struck = tg
	var at: Vector2 = tg.global_position
	var mid := (global_position + at) * 0.5 + (at - global_position).orthogonal().normalized() * randf_range(-18.0, 18.0)
	main.fx_bolt([global_position + Vector2(0, -16), mid, at], C_BOLT)
	main.light_flash(at, C_BOLT, 1.4, 1.8, 0.3)
	main.sfx("thunder", 1.2, -2.0)
	if tg == main.player:
		var before: float = tg.hp
		tg.receive_attack(dmg, self, true)
		if tg.hp < before:
			Reactions.apply(main, tg, "charged", Reactions.climber_seconds("charged"), self)
	else:
		tg.take_hit(dmg * float(RULES["foe_mult"]), (at - global_position).normalized(), 60.0)
		if is_instance_valid(tg) and not tg.dead:
			tg.stagger(float(RULES["stun"]))
			Reactions.apply(main, tg, "charged", float(Reactions.STATES["charged"]["seconds"]), "stormstone")


## It never moves.
func take_hit(amount: float, dir: Vector2, _force := 140.0, heavy := false, pierce := false) -> void:
	super.take_hit(amount, dir, 0.0, heavy, pierce)
	knock = Vector2.ZERO
	flinch = 0.0


func tide_push(_v: Vector2) -> void:
	pass


func _idle_state() -> String:
	return "build"


# --- drawing ------------------------------------------------------------------------

## A tall carved stone seen from the front and above, bound with two iron
## bands, a column of runes up its face that light as it charges; sparks
## crawl over it when it's nearly full.
func _draw_own(p, t: float, _f: Vector2) -> void:
	var k := 1.0 if state == "wind_arc" else charge
	# Rubble at its foot.
	for i in 4:
		p.ball(Vector2(-10.0 + 6.5 * i, 9.0 + (i % 2) * 2.0), 2.4, C_STONE.darkened(0.25))
	var stone := PackedVector2Array([Vector2(-10, 10), Vector2(-11, -8), Vector2(-7, -24), Vector2(0, -28), Vector2(7, -24), Vector2(11, -8), Vector2(10, 10)])
	p.poly(stone, C_STONE, 1.8)
	p.poly(PackedVector2Array([Vector2(-10, 10), Vector2(-11, -8), Vector2(-7, -24), Vector2(-3, -26), Vector2(-5, 10)]), C_STONE.lightened(0.12), 0.0)
	for y in [-14.0, 4.0]:
		p.quad(Vector2(-11, y), Vector2(11, y), 2.4, Palette.STEEL.darkened(0.3))
		p.circle(Vector2(-8, y), 0.9, Palette.STEEL.lightened(0.2), 6)
		p.circle(Vector2(8, y), 0.9, Palette.STEEL.lightened(0.2), 6)
	# Runes: four marks up the face, lit from the bottom as it charges.
	for i in 4:
		var y := 6.0 - 7.5 * i
		if absf(y - 4.0) < 2.0 or absf(y + 14.0) < 2.0:
			y -= 2.5
		var lit := clampf(k * 4.0 - i, 0.0, 1.0)
		var c := Vector2(0, y)
		p.quad(c + Vector2(-2.5, -2.0), c + Vector2(2.5, 2.0), 1.2, Palette.OUTLINE)
		p.quad(c + Vector2(-2.5, 2.0), c + Vector2(0.0, -2.5), 1.2, Palette.OUTLINE)
		if lit > 0.0:
			_glow.quad(c + Vector2(-2.5, -2.0), c + Vector2(2.5, 2.0), 1.4, Color(C_RUNE, lit))
			_glow.quad(c + Vector2(-2.5, 2.0), c + Vector2(0.0, -2.5), 1.4, Color(C_RUNE, lit))
	_glow.circle(Vector2(0, -10), 9.0 + 4.0 * k, Color(C_RUNE, 0.06 + 0.12 * k), 16)
	if k > 0.6:
		for i in 3:
			var a := t * (6.0 + i) + i * 2.1
			var at := Vector2(cos(a) * 11.0, -10.0 + sin(a * 1.3) * 16.0)
			_glow.quad(at, at + Vector2.from_angle(a * 3.0) * 5.0, 1.2, Color(C_BOLT, 0.5 + 0.5 * (k - 0.6) / 0.4))


func _overlay_extra(o) -> void:
	var reach := float(RULES["reach"])
	var danger := Palette.DANGER
	if state == "wind_arc":
		var k := _wk(float(RULES["aim"]))
		o.arc(Vector2.ZERO, reach, 0.0, TAU, 1.5, Color(danger, 0.45), 48)
		if target != null and is_instance_valid(target) and not target.dead:
			var at: Vector2 = target.global_position - global_position
			o.quad(Vector2(0, -16), at, 1.5 + 2.5 * k, Color(danger, 0.35 + 0.45 * k))
			o.arc(at, float(target.radius) + 6.0, 0.0, TAU, 2.0, Color(danger, 0.7 + 0.3 * k), 20)
	elif charge > 0.5:
		# Nearly full: its reach shows faint.
		o.arc(Vector2.ZERO, reach, 0.0, TAU, 1.2, Color(C_RUNE, 0.25 * (charge - 0.5) / 0.5), 48)
