extends "res://scripts/towers/brood.gd"
## THE CARRION: a vulture of the Manticore's tower (kind "carrion"; enemy.gd
## SUBKINDS spawns it with this script). It circles HIGH over the courts,
## out of reach: only its shadow crosses the floor. It waits for you to be
## badly hurt (below CARRION "hurt_below" of your health), and only then
## dives: a cry from above, a red ring on the floor that follows you, the
## shadow closing in, a glint, and it drops onto the spot (parryable, or
## step out of the ring). Then it stands on the floor a moment, open, before
## it climbs back up. A parried dive brings it down staggered. It also comes
## down when it's been the only foe about for a while, or has waited long
## enough (so a room never waits on it for ever).

static var CARRION := {
	"hurt_below": 0.4,  # it dives once your health is below this share of the most you have...
	"alone_wait": 5.0,  # ...or once it has been the only foe about for this long (seconds)...
	"patience": 30.0,  # ...or after circling this long whatever happens
	"near_alone": 520.0,  # another awake foe this near (px) and it isn't alone
	"circle": 170.0,  # how far out its shadow circles (px)
	"dive_near": 420.0,  # it dives only from this near
	"wind": 1.1,  # the dive's wind-up (seconds): the cry, the ring, the shadow closing in
	"radius": 44.0,  # the ring it lands in (px)
	"ground": 2.2,  # seconds on the floor after a dive (open to blows)
	"rise": 0.7,  # seconds climbing back up
	"high": 70.0,  # how high it flies (px, for drawing)
}
static var CARRION_TEXT := {"cry": "A cry from above!", "high": "too high to reach"}

var spot := Vector2.ZERO  # where the dive lands
var wait_t := 0.0
var alone_t := 0.0
var said_t := 0.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "high"
	submerged = true


func _idle_state() -> String:
	return "ground"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var c := CARRION
	_first_look(dist)
	said_t -= delta
	match state:
		"wind_dive":
			submerged = not glinted  # (it shows as it drops, from the glint on)
			if not glinted:
				spot = p.global_position
			var left := maxf(state_t, 0.05)
			velocity = ((spot - global_position) / left).limit_length(900.0)
			if _wind(delta):
				global_position = main.walkable_point(global_position, spot, 10.0)
				submerged = false
				main.fx_burst(spot, Vector2.UP, Color(0.8, 0.72, 0.6), 14, 160.0)
				main.fx_ring(spot, Color(0.85, 0.75, 0.6), float(c["radius"]), 0.3, 3.0)
				main.sfx_at(global_position, "swing_heavy", 0.75, -2.0)
				main.shake(3.0)
				if p.global_position.distance_to(spot) < float(c["radius"]) + p.radius:
					p.receive_attack(dmg, self)
				velocity = Vector2.ZERO
				if state == "wind_dive":  # (not parried)
					_end_attack("ground", float(c["ground"]))
		"ground", "recover", "idle":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "rise"
				state_t = float(c["rise"])
				main.sfx_at(global_position, "wingbeat", 0.8, -4.0)
		"rise":
			submerged = false
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "high"
				submerged = true
				wait_t = 0.0
		_:  # high: circling out of reach
			submerged = true
			state = "high"
			wait_t += delta
			alone_t = alone_t + delta if _alone() else 0.0
			var hurt: bool = "max_hp" in p and p.max_hp > 0.0 and p.hp < p.max_hp * float(c["hurt_below"])
			var ready := hurt or alone_t > float(c["alone_wait"]) or wait_t > float(c["patience"])
			if ready and dist < float(c["dive_near"]) and main.request_attack(self):
				spot = p.global_position
				_begin_wind("wind_dive", float(c["wind"]))
				_warn(1.35, 0.0)
				main.fx_text(p.global_position + Vector2(0, -52), String(CARRION_TEXT["cry"]), Color(0.95, 0.82, 0.6))
				return
			_circle(dir, dist, float(c["circle"]), speed)


## No other awake foe near (it doesn't wait on itself or on the hidden).
func _alone() -> bool:
	for o in main.enemies():
		if o == self or o.dead or o.submerged or not o.aware or o.kind == "carrion":
			continue
		if o.global_position.distance_to(global_position) < float(CARRION["near_alone"]):
			return false
	return true


## Parried in the dive: it comes down hard, staggered.
func on_parried(perfect := false) -> void:
	submerged = false
	super.on_parried(perfect)
	state = "ground"
	state_t = float(CARRION["ground"])


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	if submerged:
		if said_t <= 0.0 and main != null:
			said_t = 1.5
			main.fx_text(global_position + Vector2(0, -radius - 10.0), String(CARRION_TEXT["high"]), Color(0.85, 0.78, 0.65))
		return
	super.take_hit(amount, dir, force, heavy, pierce)


# --- drawing ---------------------------------------------------------------------------

const C_WING := Color(0.3, 0.23, 0.19)
const C_RUFF := Color(0.86, 0.8, 0.7)
const C_HEAD := Color(0.84, 0.55, 0.5)
const C_SHADOW := Color(0.02, 0.01, 0.02, 0.4)


func _draw_own(p, t: float, f: Vector2) -> void:
	var c := CARRION
	var s := f.orthogonal()
	if state == "high" or (state == "wind_dive" and not glinted):
		# Only its shadow on the floor: wings spread, banking slowly.
		var k := 0.0
		if state == "wind_dive":
			k = _wk(float(c["wind"]))
		var sc := 1.5 - 0.45 * k
		var bank := sin(t * 0.7) * 0.15
		var fw := f.rotated(bank)
		var sw := fw.orthogonal()
		var col := Color(C_SHADOW, 0.4 + 0.2 * k)
		p.oval(Vector2(0, 4), Vector2(radius * 0.5, radius * 0.28) * sc, fw.angle(), col, 14)
		for sgn in [-1.0, 1.0]:
			var tip: Vector2 = Vector2(0, 4) + sw * sgn * radius * 2.1 * sc - fw * radius * 0.35 * sc
			p.poly(PackedVector2Array([Vector2(0, 4) + fw * radius * 0.25 * sc, tip, tip - fw * radius * 0.3 * sc, Vector2(0, 4) - fw * radius * 0.45 * sc]), col, 0.0)
		p.tri(Vector2(0, 4) - fw * radius * 0.4 * sc + sw * 3.0 * sc, Vector2(0, 4) - fw * radius * 0.95 * sc, Vector2(0, 4) - fw * radius * 0.4 * sc - sw * 3.0 * sc, col)
		return
	var h := 0.0  # how high it is (it drops after the glint, and climbs as it rises)
	if state == "wind_dive":
		h = float(c["high"]) * clampf(state_t / GLINT_LEAD, 0.0, 1.0)
	elif state == "rise":
		h = float(c["high"]) * (1.0 - clampf(state_t / float(c["rise"]), 0.0, 1.0))
	var up := Vector2(0, -h)
	var flying: bool = state in ["wind_dive", "rise"]
	var flap := sin(_flap * 2.0) * 0.5 + 0.5
	# Wings: mantled over its kill on the floor, wide and beating in the air.
	var span := radius * ((1.7 + 0.5 * flap) if flying else (1.05 + 0.1 * sin(t * 1.3)))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = up + s * sgn * radius * 0.35 - f * 2.0
		for j in 4:
			var d: Vector2 = (s * sgn * (1.0 - 0.18 * j) - f * (0.15 + 0.3 * j) + (f * 0.35 * flap if flying else -f * 0.25)).normalized()
			_feather(p, root, d, span * (1.0 - 0.14 * j), radius * 0.85, C_WING.lightened(0.06 * j), 1.2)
		p.quad(root, root + s * sgn * span * 0.55 - f * 2.0, 2.2, C_WING.darkened(0.25))
	# Tail fan, body, the pale ruff at the neck, the bare pink head and hooked beak.
	for j in 3:
		_feather(p, up - f * radius * 0.5, (-f + s * (j - 1) * 0.3).normalized(), radius * 0.8, radius * 0.38, C_WING.darkened(0.1), 1.0)
	p.egg(up, Vector2(radius * 0.85, radius * 0.62), f.angle(), color)
	p.egg(up + f * radius * 0.45, Vector2(radius * 0.42, radius * 0.48), f.angle(), C_RUFF)
	var head := up + f * radius * 0.95
	var hunch := 0.0 if flying else 2.0 * sin(t * 2.0)
	head += f * hunch * 0.5
	p.ball(head, radius * 0.32, C_HEAD)
	p.poly(PackedVector2Array([head + f * radius * 0.2 + s * 2.2, head + f * radius * 0.62, head + f * radius * 0.55 - s * 1.0, head + f * radius * 0.2 - s * 2.2]), Color(0.9, 0.82, 0.6), 1.1)
	p.tri(head + f * radius * 0.62, head + f * radius * 0.5 - s * 0.6 + Vector2(0, 2.0), head + f * radius * 0.5 + s * 0.6, Palette.OUTLINE)
	p.circle(head + f * 1.5 + s * 2.5, 1.2, Palette.OUTLINE, 8)
	p.circle(head + f * 1.5 - s * 2.5, 1.2, Palette.OUTLINE, 8)
	_glow.circle(head + f * 1.5 + s * 2.5, 0.7, Color(1.0, 0.75, 0.35), 6)
	_glow.circle(head + f * 1.5 - s * 2.5, 0.7, Color(1.0, 0.75, 0.35), 6)
	if not flying:
		for sgn in [-1.0, 1.0]:  # talons
			var foot: Vector2 = s * sgn * 4.0 + Vector2(0, radius * 0.45)
			p.limb(s * sgn * 3.0 + Vector2(0, radius * 0.2), foot, Color(0.75, 0.68, 0.5), 1.8)


func _overlay_extra(o) -> void:
	if state == "wind_dive":
		_target(o, spot - global_position, float(CARRION["radius"]), _wk(float(CARRION["wind"])), 0.12, 2.5)
