extends "res://scripts/enemy.gd"
## A training dummy for the practice room (practice.gd): a straw-stuffed
## figure on a post with a painted target. It takes every hit (and every
## burn, slow, stagger and shove a spell or technique gives), shows the
## damage, but never moves to attack and never falls: its health comes
## back a moment after the last hit. It counts for nothing (no essence, no
## record, no kill).

const LOOK := {
	"straw": Color(0.8, 0.66, 0.36), "sack": Color(0.62, 0.5, 0.33), "post": Color(0.42, 0.28, 0.16),
	"rope": Color(0.33, 0.24, 0.15), "paint": Color(0.78, 0.22, 0.2), "ring": Color(0.94, 0.88, 0.74),
}
## Health, size and how long after the last hit it mends.
const STATS := {"hp": 400.0, "radius": 15.0, "mend_after": 2.5}

var mend_t := 0.0
var struck := 0.0  # damage taken since it last mended (tests)
var hits_taken := 0  # (tests)
var wobble := 0.0


## Call before adding it to the room.
func setup_dummy(room) -> void:
	main = room
	kind = "dummy"
	max_hp = float(STATS["hp"])
	hp = max_hp
	radius = float(STATS["radius"])
	color = LOOK["sack"]
	speed = 0.0
	dmg = 0.0
	weight = 6.0  # barely shoved by bodies
	aware = true
	notice_t = 0.0
	state = "idle"


## Every timer a spell sets runs down, and a shove carries it a little; it
## never chases, aims or strikes.
func _physics_process(delta: float) -> void:
	flash -= delta
	charged -= delta
	overcharge_t -= delta
	tide_t -= delta
	challenged_t -= delta
	airborne = maxf(0.0, airborne - delta)
	stun = maxf(0.0, stun - delta)
	flinch = maxf(0.0, flinch - delta)
	chill_t -= delta
	cripple_t -= delta
	disarm_t -= delta
	open_t -= delta
	lost_t -= delta
	squash = move_toward(squash, 0.0, 6.0 * delta)
	wobble = move_toward(wobble, 0.0, 3.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	_tick_burn(delta)
	_tick_venom(delta)
	glint = 0.0
	if hp <= 1.0:
		hp = 1.0
	mend_t -= delta
	if mend_t <= 0.0 and hp < max_hp:
		hp = max_hp
		struck = 0.0
	var p = main.player
	if p != null:
		face = face.slerp((p.global_position - global_position).normalized(), minf(1.0, 4.0 * delta)).normalized()
	velocity = knock * 0.35
	move_and_slide()
	_redraw()


func is_attacking() -> bool:
	return false


## Takes the hit and shows it; never falls.
func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if main.counting_hits:
		main.cast_hits += 1
	if challenged_t > 0.0:
		amount *= 1.5  # (a mark or a Challenge: it takes more, as a monster would)
	hp = maxf(1.0, hp - amount)
	struck += amount
	hits_taken += 1
	mend_t = float(STATS["mend_after"])
	flash = 0.12
	squash = 1.0
	wobble = 1.0
	if dir != Vector2.ZERO:
		squash_dir = dir
		knock = dir * force * 0.5
	if amount > 0.0:
		main.fx_text(global_position + Vector2(0, -radius - 12.0), str(int(round(amount))), Color(1.0, 0.95, 0.85))


func _leave_remains() -> void:
	pass


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 7)
	var lean := sin(t * 2.0) * 0.03 + wobble * 0.25 * sin(t * 22.0)
	var tint := clampf(flash / 0.12, 0.0, 1.0) * 0.6
	var b := Draw.Batch.new()
	# Its shadow and the post's foot.
	b.circle(Vector2(0, radius * 0.8), radius * 1.05, Color(0, 0, 0, 0.22), 20)
	b.rect(Rect2(Vector2(-9, radius * 0.55), Vector2(18, 4)), LOOK["post"].darkened(0.3))
	var xf := Transform2D(lean, Vector2.ZERO)
	var post := LOOK["post"]
	b.rect(Rect2(xf * Vector2(-2.5, -radius * 1.6), Vector2(5, radius * 2.3)), post)
	# The crossbar (its arms) and the stuffed sack of a body.
	var arm_a: Vector2 = xf * Vector2(-radius * 1.25, -radius * 0.55)
	var arm_b: Vector2 = xf * Vector2(radius * 1.25, -radius * 0.55)
	b.line(arm_a, arm_b, Palette.OUTLINE, 6.0)
	b.line(arm_a, arm_b, post.lightened(0.1), 4.0)
	for end in [arm_a, arm_b]:
		b.dot(end, 3.6, Palette.OUTLINE)
		b.dot(end, 2.6, LOOK["straw"])
	var sack: Color = LOOK["sack"].lerp(Color.WHITE, tint)
	var body_c: Vector2 = xf * Vector2(0, -radius * 0.15)
	b.dot(body_c, radius * 0.95 + 1.6, Palette.OUTLINE)
	b.dot(body_c, radius * 0.95, sack)
	b.dot(body_c + Vector2(-2.5, -3.0), radius * 0.6, sack.lightened(0.12))
	# Rope round its middle, and the painted target on its chest.
	b.line(xf * Vector2(-radius * 0.9, radius * 0.3), xf * Vector2(radius * 0.9, radius * 0.3), LOOK["rope"], 2.0)
	b.dot(body_c, radius * 0.55, LOOK["ring"].lerp(Color.WHITE, tint))
	b.dot(body_c, radius * 0.4, LOOK["paint"])
	b.dot(body_c, radius * 0.24, LOOK["ring"])
	b.dot(body_c, radius * 0.11, LOOK["paint"])
	# A straw head, a few loose straws.
	var head: Vector2 = xf * Vector2(0, -radius * 1.35)
	b.dot(head, radius * 0.5 + 1.4, Palette.OUTLINE)
	b.dot(head, radius * 0.5, LOOK["straw"].lerp(Color.WHITE, tint))
	for i in 4:
		var a := -PI * 0.5 + (i - 1.5) * 0.45
		b.line(head + Vector2.from_angle(a) * radius * 0.4, head + Vector2.from_angle(a) * radius * 0.75, LOOK["straw"].darkened(0.15), 1.2)
	b.flush(self)
