extends "res://scripts/towers/brood.gd"
## THE CAIRN: a heap of stones in the Manticore's tower (kind "cairn"; enemy.gd
## SUBKINDS spawns it with this script). It lies as a low pile of stones until
## you pass near (or strike it); then the stones grind and PULL TOGETHER into
## a stone figure. It walks slowly and swings heavily (a long wind-up, the
## glint, a wide arc in front: parryable, and open after). Light blows don't
## rock it. Beaten down, it FALLS APART into rubble, and pulls itself back
## together a few seconds later with part of its health, unless a HEAVY blow
## (a finisher, a heavy weapon's blow, a blast) scatters the stones: a heavy
## blow that fells it, or one on its rubble, ends it for good. It only has
## stones enough to rebuild so many times (CAIRN "rebuilds").

static var CAIRN := {
	"wake_near": 115.0,  # it gathers itself when you pass this near (px)
	"assemble": 1.0,  # seconds pulling itself together
	"swing_near": 64.0, "swing_wind": 0.9, "swing_reach": 70.0, "swing_arc": 60.0,
	"rubble": 4.0,  # seconds lying as rubble before it rebuilds
	"rebuild": 0.8,  # seconds rebuilding
	"rise": 0.6,  # the share of its health it rebuilds with
	"rebuilds": 2,  # how many times it can rebuild
}
static var CAIRN_TEXT := {
	"gather": "The stones pull together!",
	"fall": "It falls apart... strike hard!",
	"rebuild": "The stones pull together again",
	"scatter": "Scattered!",
	"shift": "The stones shift",
}

const C_STONE := Color(0.62, 0.56, 0.48)
const C_MOSS := Color(0.44, 0.5, 0.3)

var rebuilt := 0
var last_heavy := false
var scattered := false
var said_t := 0.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "pile"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var c := CAIRN
	_first_look(dist)
	said_t -= delta
	flinch_cd = 1.0  # (stone: light blows never rock it; heavy ones still do)
	match state:
		"pile":
			velocity = Vector2.ZERO
			if dist < float(c["wake_near"]):
				_gather()
		"assemble", "rebuild":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.4
		"rubble":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				rebuilt += 1
				hp = max_hp * float(c["rise"])
				state = "rebuild"
				state_t = float(c["rebuild"])
				main.fx_text(global_position + Vector2(0, -radius - 22.0), String(CAIRN_TEXT["rebuild"]), Color(0.9, 0.82, 0.62))
				main.sfx_at(global_position, "stone_slide", 0.9, -2.0)
		"wind_swing":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, float(c["swing_reach"]), deg_to_rad(float(c["swing_arc"])), Color(0.85, 0.75, 0.6))
				main.sfx_at(global_position, "swing_blunt_heavy", 0.8)
				main.shake(3.0)
				_strike_cone(p, lunge_dir, float(c["swing_reach"]), float(c["swing_arc"]), dmg)
				_end_attack("recover", 1.4)
		"recover", "idle":
			state_t -= delta
			velocity = dir * speed * 0.4 if dist > 80.0 else Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < float(c["swing_near"]) and main.request_attack(self):
				_begin_wind("wind_swing", float(c["swing_wind"]))
				_warn(0.7)
			else:
				velocity = dir * speed if dist > 40.0 else Vector2.ZERO


func _gather() -> void:
	state = "assemble"
	state_t = float(CAIRN["assemble"])
	aware = true
	main.fx_text(global_position + Vector2(0, -radius - 22.0), String(CAIRN_TEXT["gather"]), Color(0.9, 0.82, 0.62))
	main.fx_burst(global_position, Vector2.UP, C_STONE, 10, 120.0)
	main.sfx_at(global_position, "stone_slide", 0.75, 0.0)


func is_attacking() -> bool:
	return state.begins_with("wind")


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if state == "pile":
		_gather()
	if state in ["rubble", "rebuild"]:
		if heavy:
			_scatter()
		elif said_t <= 0.0 and main != null and dir != Vector2.ZERO:
			said_t = 1.0
			main.fx_text(global_position + Vector2(0, -radius - 10.0), String(CAIRN_TEXT["shift"]), Color(0.85, 0.8, 0.7))
			main.sfx_at(global_position, "hit_blunt", 0.8, -4.0)
		return
	last_heavy = heavy
	super.take_hit(amount, dir, force, heavy, pierce)


## Beaten down: it falls apart (unless a heavy blow did it, or it's out of stones).
func _refuse_death() -> bool:
	if scattered or last_heavy or rebuilt >= int(CAIRN["rebuilds"]):
		if last_heavy and main != null:
			main.fx_text(global_position + Vector2(0, -radius - 30.0), String(CAIRN_TEXT["scatter"]), Color(1.0, 0.88, 0.6))
		return false
	hp = 1.0
	burn_t = 0.0
	bleeding = 0.0
	_end_attack("rubble", float(CAIRN["rubble"]))
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	main.fx_text(global_position + Vector2(0, -radius - 20.0), String(CAIRN_TEXT["fall"]), Color(0.9, 0.82, 0.62))
	main.fx_burst(global_position, Vector2.ZERO, C_STONE, 16, 180.0)
	main.sfx_at(global_position, "hit_heavy", 0.6, -2.0)
	main.shake(4.0)
	return true


## A heavy blow on its rubble: the stones fly apart, and it's done.
func _scatter() -> void:
	scattered = true
	main.fx_text(global_position + Vector2(0, -radius - 20.0), String(CAIRN_TEXT["scatter"]), Color(1.0, 0.88, 0.6))
	main.fx_burst(global_position, Vector2.ZERO, C_STONE.lightened(0.15), 22, 260.0)
	hp = 0.0
	state = "scattered"
	super.take_hit(1.0, Vector2.ZERO, 0.0)


# --- drawing ---------------------------------------------------------------------------

## The stones: where each lies in the pile, and where it sits in the figure
## (along the facing: x forward, y to the side, z height), and its size.
const STONES := [
	[Vector2(-6, 3), Vector3(0, 0, 13), 7.5],  # the body
	[Vector2(5, 4), Vector3(1, 0, 23), 5.0],  # the head
	[Vector2(-1, -4), Vector3(0, 0, 4), 6.0],  # the hips
	[Vector2(8, -3), Vector3(3, -10, 14), 4.2],  # the shoulders and fists
	[Vector2(-9, -5), Vector3(3, 10, 14), 4.2],
	[Vector2(2, 9), Vector3(6, -13, 7), 4.6],
	[Vector2(-4, 10), Vector3(6, 13, 7), 4.6],
	[Vector2(10, 6), Vector3(-1, -5, 0), 3.8],  # the feet
	[Vector2(-11, 3), Vector3(-1, 5, 0), 3.8],
]


func _draw_own(p, t: float, f: Vector2) -> void:
	var c := CAIRN
	var s := f.orthogonal()
	var k := 1.0  # 0 a pile .. 1 standing
	match state:
		"pile":
			k = 0.0
		"rubble", "scattered":
			k = 0.0
		"assemble":
			k = 1.0 - clampf(state_t / float(c["assemble"]), 0.0, 1.0)
		"rebuild":
			k = 1.0 - clampf(state_t / float(c["rebuild"]), 0.0, 1.0)
	var swing := _ease("swing", _wk(float(c["swing_wind"])) if state == "wind_swing" else 0.0, 12.0)
	var stride := sin(_stride * 1.2) * 2.5 * _move
	var spread := 1.6 if state == "rubble" else 1.0
	var drawn: Array = []
	for i in STONES.size():
		var st: Array = STONES[i]
		var pile: Vector2 = Vector2(st[0]) * spread
		var fig: Vector3 = st[1]
		var at := f * fig.x + s * fig.y * 1.15 + Vector2(0, -fig.z * 1.45)
		if i == 3 or i == 5:  # the right arm swings up and across
			at += -f * 6.0 * swing + Vector2(0, -8.0 * swing)
		if i == 7:
			at += f * stride
		if i == 8:
			at -= f * stride
		var rise := sin(k * PI) * 6.0 * (1.0 if i % 2 == 0 else 0.6)  # (stones lift as they fly into place)
		drawn.append([pile.lerp(at, k) + Vector2(0, -rise), float(st[2]), i])
	drawn.sort_custom(func(a, b): return a[0].y < b[0].y)
	for d in drawn:
		var at: Vector2 = d[0]
		var r: float = d[1]
		var col := C_STONE.darkened(0.06 * (int(d[2]) % 3))
		p.ball(at, r, col)
		if int(d[2]) % 3 == 0:
			p.oval(at + Vector2(-r * 0.2, -r * 0.45), Vector2(r * 0.5, r * 0.22), 0.0, C_MOSS, 10)
		p.quad(at + Vector2(-r * 0.3, r * 0.1), at + Vector2(r * 0.25, -r * 0.2), 0.9, Color(C_STONE.darkened(0.45), 0.8))
	if k > 0.6:
		var head := f * 1.0 + Vector2(0, -23.0 * 1.45)
		_glow.circle(head + f * 2.5 + s * 2.0, 1.2, Color(1.0, 0.75, 0.4, (k - 0.6) * 2.5), 8)
		_glow.circle(head + f * 2.5 - s * 2.0, 1.2, Color(1.0, 0.75, 0.4, (k - 0.6) * 2.5), 8)
	elif state == "rubble":
		# A faint pulse between the stones: it's gathering again.
		var left := clampf(1.0 - state_t / float(c["rubble"]), 0.0, 1.0)
		_glow.circle(Vector2(0, 2), 3.0 + 4.0 * left, Color(1.0, 0.75, 0.4, 0.15 + 0.35 * left * (0.6 + 0.4 * sin(t * 8.0))), 12)


func _overlay_extra(o) -> void:
	if state == "wind_swing":
		_cone(o, float(CAIRN["swing_reach"]), float(CAIRN["swing_arc"]), _wk(float(CAIRN["swing_wind"])), 0.1, 0.75)
