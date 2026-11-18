extends RefCounted
## The monsters and beasts, drawn the way the full game (Sixfold Tower) draws
## them: seen from above, facing `face`, built from outlined, shaded shapes.
## The drawing code is copied from the full game's enemy.gd (and its towers'
## harrier.gd, deepfin.gd and creatures.gd) with the gameplay taken out, so
## LITE never loads a file from the full game.
##
## Use it from a Node2D's draw callback:
##   Creatures.draw(self, "slime", pos, {"t": t, "face": dir, "state": "walk", "move": 1.0, "scale": 2.0, "mem": my_mem})
##
## pose keys (all optional):
##   t       seconds (animation time)         seed   int, a phase offset per creature
##   face    Vector2 it faces (default DOWN)   state  idle, walk, wind, attack, rest, stun
##                                                    (also "hide": a deepfin under water, a
##                                                    briar as a bush; "ashes": an ashwing's
##                                                    or the firebird's heap of ash)
##   wind    0..1 how far the wind-up has gone move   0..1 how fast it walks
##   flash   0..1 white hit flash              danger 0..1 red "about to attack" tint
##   scale   draw scale (outlines too)         mem    Dictionary kept per creature by the caller
##   alt     int: which of a beast's (or knight's, briar's) attacks wind/attack show (ALTS)
##   squash  0..1 squashed by a hit (default: follows flash); squash_dir Vector2
##   lift    px a harrier soars above its shadow (default the full game's 48)
##   dead    bool: drawn grey and faded

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

## Each kind's body radius, colour and walking speed in the full game (enemy.gd TYPES).
const KINDS := {
	"slime": [13.0, Color(0.5, 0.88, 0.4), 60.0],
	"archer": [11.0, Color(0.62, 0.5, 0.3), 75.0],
	"knight": [15.0, Color(0.66, 0.7, 0.8), 60.0],
	"harrier": [12.0, Color(0.58, 0.5, 0.42), 105.0],
	"deepfin": [13.0, Color(0.22, 0.42, 0.5), 120.0],
	"ashwing": [11.0, Color(1.0, 0.5, 0.22), 105.0],
	"briar": [14.0, Color(0.3, 0.46, 0.22), 38.0],
	"cinder": [10.0, Color(1.0, 0.55, 0.22), 95.0],
	"scorpling": [10.0, Color(0.72, 0.55, 0.32), 85.0],
	"ram": [17.0, Color(0.62, 0.58, 0.52), 50.0],
	"wisp": [9.0, Color(1.0, 0.75, 0.35), 110.0],
	"thornhound": [11.0, Color(0.5, 0.38, 0.3), 125.0],
	"gryphon": [26.0, Color(0.88, 0.74, 0.45), 78.0],
	"kraken": [34.0, Color(0.6, 0.3, 0.42), 35.0],
	"wyvern": [28.0, Color(0.72, 0.3, 0.22), 72.0],
	"manticore": [28.0, Color(0.82, 0.52, 0.3), 76.0],
	"firebird": [26.0, Color(1.0, 0.55, 0.2), 90.0],
	"chimera": [30.0, Color(0.78, 0.6, 0.36), 80.0],
}
const BEASTS := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]

## The full game's wind-up and attack states each LITE "wind" / "attack" shows,
## by pose["alt"] (wraps round). [wind state, attack state, attack held at full wind-up?]
const ALTS := {
	"slime": [["wind", "pounce", false]],
	"archer": [["aim", "reload", false]],
	"knight": [["wind_slash", "swing", false], ["wind_lunge", "lunge", false]],
	"harrier": [["wind_dive", "dive", false]],
	"deepfin": [["wind", "lunge", false]],
	"ashwing": [["wind", "dive", false]],
	"briar": [["wind_grab", "grab", false], ["wind_swipe", "rooted", false]],
	"cinder": [["wind_spit", "recover", false]],
	"scorpling": [["wind_sting", "wind_sting", true]],
	"ram": [["wind_charge", "charge", false]],
	"wisp": [["wind", "swoop", false]],
	"thornhound": [["wind", "lunge", false]],
	"gryphon": [["wind_rake", "wind_rake", true], ["wind_gale", "wind_gale", true], ["wind_dive", "dive", false]],
	"kraken": [["wind_sweep", "wind_sweep", true], ["wind_slam", "slam", false], ["wind_ink", "wind_ink", true]],
	"wyvern": [["wind_breath", "wind_breath", true], ["wind_tail", "wind_tail", true], ["wind_embers", "wind_embers", true]],
	"manticore": [["wind_claw", "wind_claw", true], ["wind_roar", "wind_roar", true], ["wind_spikes", "wind_spikes", true]],
	"firebird": [["wind_storm", "swoop", false], ["wind_swoop", "swoop", false]],
	"chimera": [["wind_maul", "wind_maul", true], ["wind_charge", "charge", false], ["wind_breath", "wind_breath", true], ["wind_spikes", "wind_spikes", true]],
}
## The full game's state for LITE's idle/walk, rest and stun (default: idle, recover, recover).
const CALM := {
	"slime": ["idle", "rest", "rest"],
	"wisp": ["hover", "rest", "rest"],
	"harrier": ["soar", "perch", "perch"],
	"deepfin": ["land", "stranded", "stranded"],
	"ashwing": ["hover", "rest", "rest"],
	"briar": ["rooted", "rooted", "rooted"],
}


const C_EYE := Color(0.97, 0.96, 0.9)
const C_EYE_GLOW := Color(1.0, 0.82, 0.38)
const C_BONE := Color(0.9, 0.86, 0.74)
const C_HORN := Color(0.84, 0.78, 0.64)
const C_STRING := Color(0.9, 0.88, 0.8)
const C_LEATHER := Color(0.42, 0.29, 0.19)
const C_IRON := Color(0.33, 0.31, 0.35)
const C_SKIN := Color(0.7, 0.55, 0.45)
const C_WATER := Color(0.6, 0.85, 0.95)
const C_VENOM := Color(0.6, 0.86, 0.35)
const C_THORN := Color(0.36, 0.56, 0.3)
const C_FLAME := Color(1.0, 0.72, 0.3)
const C_FLAME_CORE := Color(1.0, 0.94, 0.66)
const C_EMBER := Color(1.0, 0.5, 0.18)
const C_ASH := Color(0.27, 0.24, 0.24)
const C_BEAK := Color(0.96, 0.76, 0.32)
const C_GRYPHON_HEAD := Color(0.95, 0.92, 0.85)
const C_GRYPHON_WING := Color(0.74, 0.6, 0.4)
const C_MANE := Color(0.58, 0.32, 0.17)
const C_BAT_WING := Color(0.45, 0.28, 0.25)
const C_SERPENT := Color(0.42, 0.64, 0.34)
const C_GOAT := Color(0.82, 0.8, 0.74)
const C_SUCKER := Color(0.86, 0.62, 0.66)
# harrier.gd
const C_HARRIER_BELLY := Color(0.86, 0.8, 0.68)
const C_HARRIER_WING := Color(0.46, 0.38, 0.3)
const C_HARRIER_TIP := Color(0.24, 0.2, 0.18)
const C_HARRIER_BEAK := Color(0.96, 0.78, 0.3)
const HARRIER_SOAR := 48.0
# deepfin.gd
const C_DEEPFIN_WATER := Color(0.6, 0.85, 0.95)
const C_DEEPFIN_FIN := Color(0.5, 0.72, 0.78)
const C_DEEPFIN_BELLY := Color(0.72, 0.78, 0.7)
const C_DEEPFIN_TOOTH := Color(0.97, 0.95, 0.88)
# towers/creatures.gd (ashwing, briar)
const C_CORE := Color(1.0, 0.94, 0.66)
const C_ASHWING_ASH := Color(0.3, 0.27, 0.27)
const C_LEAF := Color(0.26, 0.42, 0.2)
const C_LEAF_HI := Color(0.36, 0.56, 0.26)
const C_BRIAR_THORN := Color(0.66, 0.6, 0.42)
const C_BARK := Color(0.33, 0.24, 0.15)
const SWEEP_REACH := 230.0  # how far the kraken's sweeping arm reaches

static var _body: Pen = null
static var _glow: Pen = null


# --- the API ---------------------------------------------------------------------

static func radius(kind: String) -> float:
	return float(KINDS.get(kind, KINDS["slime"])[0])


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["slime"])[1]


static func is_beast(kind: String) -> bool:
	return kind in BEASTS


## Draws a creature centred on `pos` (its body centre on the floor; its
## shadow falls a little below). See the top of this file for `pose`.
static func draw(c: CanvasItem, kind: String, pos: Vector2, pose: Dictionary) -> void:
	if not KINDS.has(kind):
		kind = "slime"
	if _body == null:
		_body = Pen.new()
		_glow = Pen.new()
	var x := _ctx(kind, pose)
	var sc := float(pose.get("scale", 1.0))
	var base := Transform2D(0.0, Vector2(sc, sc), 0.0, pos)
	var p := _body
	var g := _glow
	p.reset()
	g.reset()
	p.xf = base
	var lift_y := 0.0
	if kind == "slime" and x.st == "pounce":
		lift_y -= sin(PI * clampf(x.age / 0.3, 0.0, 1.0)) * 10.0
	# A soft shadow on the floor, smaller the higher it is.
	var R := x.r
	var sr := R * clampf(1.0 + lift_y / 90.0, 0.6, 1.0)
	if not x.dead:
		p.oval(Vector2(0, R * 0.7), Vector2(sr * 1.1, sr * 0.5), 0.0, Color(0, 0, 0, 0.17))
		p.oval(Vector2(0, R * 0.7), Vector2(sr * 0.85, sr * 0.38), 0.0, Color(0, 0, 0, 0.21))
	# Squashed along the direction it was hit from.
	var flash := clampf(float(pose.get("flash", 0.0)), 0.0, 1.0)
	var squash := clampf(float(pose.get("squash", flash)), 0.0, 1.0)
	var sq_dir: Vector2 = pose.get("squash_dir", x.f)
	var a := sq_dir.angle()
	var sq := Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.25)
	var body := Transform2D(0.0, Vector2(0, lift_y)) * Transform2D(a, sq, 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	# It breathes when it stands, and pulls back as it winds up.
	var breath := sin(x.t * 2.3) * 0.03 * (1.0 - x.move) * (0.0 if x.dead else 1.0)
	var pull := clampf(x.age / 0.35, 0.0, 1.0) if x.winding else 0.0
	if breath != 0.0 or pull > 0.0:
		var back: Vector2 = -x.f * 3.2 * pull
		body = Transform2D(0.0, Vector2(1.0 - breath * 0.5 + pull * 0.04, 1.0 + breath - pull * 0.03), 0.0, back) * body
	if x.lite == "stun":  # (dazed: a slow sway)
		body = Transform2D(sin(x.t * 5.0) * 0.12, Vector2.ZERO) * body
	p.xf = base * body
	g.xf = p.xf
	p.tint = flash * 0.85
	g.tint = p.tint
	p.danger = clampf(float(pose.get("danger", 0.0)), 0.0, 1.0)
	g.danger = p.danger
	p.dead = x.dead
	g.dead = x.dead
	match kind:
		"slime": _draw_slime(p, g, x)
		"archer": _draw_archer(p, g, x)
		"knight": _draw_knight(p, g, x)
		"harrier": _draw_harrier(p, g, x)
		"deepfin": _draw_deepfin(p, g, x)
		"ashwing": _draw_ashwing(p, g, x)
		"briar": _draw_briar(p, g, x)
		"cinder": _draw_cinder(p, g, x)
		"scorpling": _draw_scorpling(p, g, x)
		"ram": _draw_ram(p, g, x)
		"wisp": _draw_wisp(p, g, x)
		"thornhound": _draw_thornhound(p, g, x)
		"gryphon": _draw_gryphon(p, g, x)
		"kraken": _draw_kraken(p, g, x)
		"wyvern": _draw_wyvern(p, g, x)
		"manticore": _draw_manticore(p, g, x)
		"firebird": _draw_firebird(p, g, x)
		"chimera": _draw_chimera(p, g, x)
	p.flush(c)
	g.flush(c)  # (glowing bits: eyes, fire; over the body)


## Everything a drawing needs this frame, and the per-creature memory.
static func _ctx(kind: String, pose: Dictionary) -> Ctx:
	var x := Ctx.new()
	var info: Array = KINDS[kind]
	x.kind = kind
	x.r = info[0]
	x.col = info[1]
	var speed: float = info[2]
	x.seed_i = int(pose.get("seed", 0))
	x.t = float(pose.get("t", 0.0)) + float(posmod(x.seed_i, 100))
	var face: Vector2 = pose.get("face", Vector2.DOWN)
	x.f = face.normalized() if face.length() > 0.01 else Vector2.DOWN
	x.move = clampf(float(pose.get("move", 0.0)), 0.0, 1.0)
	x.dead = bool(pose.get("dead", false))
	x.mem = pose.get("mem", {})
	var mem := x.mem
	# The LITE state, as the full game's.
	var lite := String(pose.get("state", "idle"))
	x.lite = lite
	var alts: Array = ALTS[kind]
	var alt: Array = alts[posmod(int(pose.get("alt", 0)), alts.size())]
	var calm: Array = CALM.get(kind, ["idle", "recover", "recover"])
	x.wk = 0.0
	match lite:
		"wind":
			x.st = alt[0]
			x.wk = clampf(float(pose.get("wind", 0.0)), 0.0, 1.0)
			x.winding = true
		"attack":
			x.st = alt[1]
			if alt[2]:
				x.wk = 1.0
		"rest":
			x.st = calm[1]
		"stun":
			x.st = calm[2]
		"hide":
			x.st = {"deepfin": "swim", "briar": "hide"}.get(kind, calm[0])
		"ashes":
			x.st = "ashes" if kind in ["ashwing", "firebird"] else calm[1]
		"walk":
			x.st = "crawl" if kind == "deepfin" else calm[0]
		_:
			x.st = calm[0]
	# Time since the last frame and since the state changed.
	var now := x.t
	x.dt = clampf(now - float(mem.get("_t", now)), 0.0, 0.05)
	mem["_t"] = now
	var key := lite + str(pose.get("alt", 0))
	if String(mem.get("_st", "")) != key:
		mem["_st"] = key
		mem["_age"] = 0.0
	else:
		mem["_age"] = float(mem["_age"]) + x.dt
	x.age = float(mem["_age"])
	# How fast it moves (the wisp's trail, the deepfin's sway).
	x.vel = x.f * x.move * speed
	if lite == "attack":
		x.vel = x.f * maxf(speed, 60.0) * 3.0
	# The gait and wing cycles, accumulated so a change of speed never jumps.
	x.stride = float(mem.get("_stride", float(x.seed_i) * 1.3)) + x.move * speed * x.dt * 0.11
	mem["_stride"] = x.stride
	var flap_rate := 3.5
	if x.st.begins_with("wind") or x.st in ["swoop", "dive"]:
		flap_rate = 7.0
	x.flap = float(mem.get("_flap", x.t * 3.5)) + x.dt * flap_rate
	mem["_flap"] = x.flap
	x.lift = float(pose.get("lift", HARRIER_SOAR))
	return x


class Ctx:
	var kind := ""
	var st := "idle"  # the full game's state name
	var lite := "idle"  # LITE's
	var winding := false
	var wk := 0.0  # how far through the wind-up (the full game's _wk)
	var age := 0.0  # seconds in this state
	var t := 0.0
	var dt := 0.0
	var f := Vector2.DOWN
	var r := 12.0
	var col := Color.WHITE
	var move := 0.0
	var stride := 0.0
	var flap := 0.0
	var vel := Vector2.ZERO
	var lift := 48.0
	var seed_i := 0
	var dead := false
	var mem := {}

	## Eases a pose value toward `want` (frame-rate independent), so a pose
	## never snaps from one state to the next (kept in mem).
	func eased(key: String, want: float, rate := 10.0) -> float:
		var v: float = mem.get(key, want)
		v = lerpf(v, want, 1.0 - exp(-rate * dt))
		mem[key] = v
		return v


# --- helpers (enemy.gd) -------------------------------------------------------------

## A sword lying along dir from the grip.
static func _sword(p: Pen, grip: Vector2, dir: Vector2, length: float) -> void:
	var side := dir.orthogonal()
	var tip := grip + dir * length
	p.limb(grip - dir * 5.0, grip, Palette.WOOD.darkened(0.3), 3.0)
	p.poly(PackedVector2Array([grip + dir * 1.5 + side * 1.9, tip - dir * 4.0 + side * 1.6, tip, tip - dir * 4.0 - side * 1.6, grip + dir * 1.5 - side * 1.9]), Palette.STEEL, 1.3)
	p.quad(grip + dir * 3.0 + side * 0.6, tip - dir * 4.0 + side * 0.5, 0.9, Color(1, 1, 1, 0.6))
	p.limb(grip + side * 5.0, grip - side * 5.0, Palette.STEEL.darkened(0.35), 2.4)
	p.ball(grip - dir * 6.5, 2.0, Palette.STEEL.darkened(0.2))


## A curled horn sweeping out from its root and back round, tapering.
static func _horn(p: Pen, root: Vector2, out: Vector2, back: Vector2, size: float, w0: float, col: Color) -> void:
	p.tube(PackedVector2Array([root, root + out * 0.55 * size + back * 0.1 * size, root + out * 0.85 * size + back * 0.55 * size, root + out * 0.65 * size + back * 0.95 * size, root + out * 0.3 * size + back * 0.9 * size]), PackedFloat32Array([w0, w0 * 0.9, w0 * 0.75, w0 * 0.55, w0 * 0.35]), col)


## A feather (or flame tongue): a leaf shape from base along dir.
static func _feather(p: Pen, base: Vector2, dir: Vector2, length: float, width: float, col: Color, outline := 1.2) -> void:
	var sd := dir.orthogonal() * width * 0.5
	p.poly(PackedVector2Array([base + sd * 0.6, base + dir * length * 0.45 + sd, base + dir * length, base + dir * length * 0.45 - sd, base - sd * 0.6]), col, outline)


## Two-segment legs in a diagonal gait. `at` lists hip offsets along the facing.
static func _legs(p: Pen, x: Ctx, at: Array, wide: float, reach: float, w: float, col: Color, rate := 1.0) -> void:
	var f := x.f
	var s := f.orthogonal()
	for i in at.size():
		for sgn in [-1.0, 1.0]:
			var ph: float = x.stride * rate + (PI if (i % 2 == 0) == (sgn > 0.0) else 0.0)
			var hip: Vector2 = f * float(at[i]) + s * sgn * wide
			var foot: Vector2 = hip + s * sgn * reach * 0.7 + f * sin(ph) * reach * 0.6 * x.move
			p.limb(hip, foot, col, w)


## Membrane wing (wyvern, manticore): arm bones, fingers fanning back, skin between.
static func _membrane(p: Pen, shoulder: Vector2, out: Vector2, back: Vector2, length: float, span: float, skin: Color, bone: Color, bw: float) -> void:
	var elbow := shoulder + (out * 0.55 + back * -0.25).normalized() * length * 0.45 * span
	var wrist := elbow + (out + back * -0.15).normalized() * length * 0.5 * span
	var tips := [
		wrist + (out * 0.7 + back * 0.3).normalized() * length * 0.45 * span,
		wrist + (out * 0.2 + back * 0.8).normalized() * length * 0.55 * span,
		wrist + (back * 0.85 - out * 0.15).normalized() * length * 0.62 * span,
	]
	var root_back := shoulder + back * length * 0.42
	var skin_pts := PackedVector2Array([shoulder, elbow, wrist, tips[0]])
	skin_pts.append((tips[0] + tips[1]) * 0.5 - (out * 0.2 - back * 0.1) * length * 0.08)
	skin_pts.append(tips[1])
	skin_pts.append((tips[1] + tips[2]) * 0.5 - back * length * 0.05)
	skin_pts.append(tips[2])
	skin_pts.append((tips[2] + root_back) * 0.5 - back * length * 0.06)
	skin_pts.append(root_back)
	p.poly(skin_pts, skin, 1.4)
	p.quad(shoulder, elbow, bw, bone)
	p.quad(elbow, wrist, bw * 0.9, bone)
	for tip in tips:
		p.quad(wrist, tip, bw * 0.55, bone)
	p.circle(wrist, bw * 0.75, bone, 10)
	p.tri(wrist - out * 1.5, wrist + out * 4.5 - back * 1.0, wrist + back * 1.5, Palette.OUTLINE)  # the thumb claw


## A beast's glowing eye: dark socket, lit iris, a pupil.
static func _beast_eye(p: Pen, g: Pen, at: Vector2, r: float, iris: Color, f: Vector2) -> void:
	p.circle(at, r + 1.0, Palette.OUTLINE, 12)
	g.circle(at, r, iris, 12)
	g.oval(at + f * r * 0.15, Vector2(r * 0.3, r * 0.75), f.angle(), Palette.OUTLINE, 10)


## A flame outline: a wavering circle drawn up into a tongue.
static func _flame(at: Vector2, r: float, t: float, up: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var d := Vector2.from_angle(a)
		var tongue := pow(maxf(0.0, -d.y), 3.0) * up
		var rr := r * (1.0 + 0.1 * sin(t * 9.0 + i * 1.7)) + tongue * (0.85 + 0.15 * sin(t * 7.0))
		pts.append(at + d * rr + Vector2(sin(t * 5.0) * tongue * 0.15, 0.0))
	return pts


static func _flame_tongue(base: Vector2, dir: Vector2, length: float, width: float) -> PackedVector2Array:
	var sd := dir.orthogonal() * width
	return PackedVector2Array([base + sd, base + dir * length * 0.5 + sd * 0.6, base + dir * length, base + dir * length * 0.5 - sd * 0.6, base - sd])


# --- the monsters ---------------------------------------------------------------------

static func _draw_slime(p: Pen, _g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var col := x.col
	var s := f.orthogonal()
	var breath := sin(t * 3.0) * 0.04
	var gather := x.eased("gather", x.wk if x.st == "wind" else 0.0, 14.0)
	var sq := Vector2(1.0 + breath + 0.22 * gather, 1.0 - breath - 0.2 * gather)
	if x.st == "pounce":
		sq = Vector2(0.86, 1.14)
	var wob := 0.04 + 0.05 * gather + 0.03 * x.move
	var base := Vector2(0, radius * 0.12 * gather)
	p.poly(Draw.blob(base, radius, t, wob, sq, 16), col.darkened(0.32))
	p.fill_poly(Draw.blob(base + Vector2(-1.2, -1.8), radius * 0.82, t + 0.3, wob, sq, 16), col)
	p.circle(base + Vector2(1.8, 2.8), radius * 0.34, Color(col.darkened(0.3), 0.55))  # the core
	for i in 2:
		var bt := fmod(t * 0.45 + i * 0.5, 1.0)
		p.circle(base + Vector2(-3.0 + i * 6.0, 4.0 - bt * 9.0), 1.0 + bt * 1.2, Color(col.lightened(0.45), 0.55 * sin(bt * PI)))
	p.circle(base + Vector2(-radius * 0.38, -radius * 0.42), radius * 0.22, Color(1, 1, 1, 0.5))
	p.circle(base + Vector2(-radius * 0.16, -radius * 0.6), radius * 0.08, Color(1, 1, 1, 0.65))
	# Eyes that follow you, narrowing as it gathers to hop.
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = base + f * radius * 0.32 + s * sgn * radius * 0.32 + Vector2(0, -2.0)
		p.oval(e, Vector2(3.0, 3.0 - 1.2 * gather), 0.0, Palette.OUTLINE, 12)
		p.oval(e, Vector2(2.3, 2.3 - 1.0 * gather), 0.0, C_EYE, 12)
		p.circle(e + f * 1.0, 1.2, Palette.OUTLINE, 10)


static func _draw_archer(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var s := f.orthogonal()
	var cloak := x.col
	var bob := Vector2(0, -absf(sin(x.stride)) * 1.2 * x.move)
	var pull := x.eased("pull", 1.0 if x.st == "aim" else 0.0, 12.0)
	# Cloak tail and quiver behind.
	var sway := s * sin(t * 2.0) * 1.5
	p.poly(PackedVector2Array([s * radius * 0.8 - f * 2.0, -f * (radius + 5.0) + sway + s * 4.0, -f * (radius + 6.5) + sway, -f * (radius + 5.0) + sway - s * 4.0, -s * radius * 0.8 - f * 2.0]), cloak.darkened(0.3))
	p.limb(-f * 4.0 + s * 5.0, -f * 13.0 + s * 8.5, Palette.WOOD.darkened(0.3), 4.0)
	for i in 3:
		var nock := -f * 13.0 + s * (6.6 + i * 1.6)
		p.tri(nock, nock - f * 4.0 + s * 1.2, nock - f * 4.0 - s * 0.6, C_BONE)
	p.ball(-f * 1.5 + bob, radius, cloak)
	# Arms: one holds the bow out, the other draws the string back.
	var grip := f * (radius + 3.0) - s * 3.0 + bob
	var hand := grip - f * (2.0 + 8.0 * pull) + s * 1.5
	p.limb(-s * radius * 0.65 + bob, grip, cloak.darkened(0.12), 3.2)
	p.limb(s * radius * 0.65 + bob, hand, cloak.darkened(0.12), 3.2)
	p.ball(f * 2.0 + bob, 6.5, cloak.darkened(0.3))  # hood
	p.circle(f * 5.0 + bob, 2.8, Color(0.08, 0.07, 0.07))  # the dark of the hood
	g.circle(f * 5.6 + s * 1.2 + bob, 0.8, C_EYE_GLOW, 8)
	g.circle(f * 5.6 - s * 1.2 + bob, 0.8, C_EYE_GLOW, 8)
	# The bow bends as it's drawn.
	var a := grip - f * (4.0 + 2.0 * pull) + s * (11.0 - pull)
	var b := grip - f * (4.0 + 2.0 * pull) - s * (11.0 - pull)
	p.tube(PackedVector2Array([a, grip + s * 5.5, grip, grip - s * 5.5, b]), PackedFloat32Array([1.6, 2.6, 3.0, 2.6, 1.6]), Palette.WOOD, true, false)
	p.quad(a, hand, 1.0, C_STRING)
	p.quad(hand, b, 1.0, C_STRING)
	if pull > 0.3:
		p.limb(hand, grip + f * 7.0, Palette.WOOD.lightened(0.2), 1.3)
		p.tri(grip + f * 11.0, grip + f * 6.5 + s * 2.2, grip + f * 6.5 - s * 2.2, Palette.STEEL)
	p.circle(hand, 1.8, Palette.CLIMBER_SKIN.darkened(0.2), 10)


static func _draw_knight(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var armor := x.col
	var s := f.orthogonal()
	# Feet step under the body.
	var step := sin(x.stride) * x.move
	for sgn in [-1.0, 1.0]:
		p.ball(s * sgn * 5.5 + f * (step * sgn * 4.5 + 2.0), 3.6, armor.darkened(0.45))
	# Sword: held low; raised over the shoulder for the slash, cocked back
	# for the lunge, thrust forward in it. Eased fast, so it swings.
	var ang := -1.1
	var gx := radius * 0.9
	var gy := 3.0
	var rate := 14.0
	if x.st == "wind_slash":
		var k := x.wk
		ang = -1.1 - 1.4 * k
		gx = radius * (0.9 - 0.3 * k)
		gy = 3.0 - 7.0 * k
	elif x.st == "wind_lunge":
		ang = -0.2
		gx = radius * 0.55
		gy = -6.0 * x.wk
	elif x.st == "lunge":
		ang = -0.1
		gx = radius * 0.4
		gy = 10.0
		rate = 30.0
	elif x.st == "swing":  # (the full game's "recover" while open: the follow-through)
		ang = 0.7
		gx = radius * 0.2
		gy = 9.0
		rate = 24.0
	ang = x.eased("sword_a", ang, rate)
	gx = x.eased("sword_x", gx, rate)
	gy = x.eased("sword_y", gy, rate)
	var grip := -s * gx + f * gy
	# Body: armoured plates, a seam down the back.
	p.ball(Vector2.ZERO, radius, armor)
	p.arc(Vector2.ZERO, radius * 0.62, f.angle() + 0.9, f.angle() + TAU - 0.9, 1.5, armor.darkened(0.3), 14)
	p.ball(s * radius * 0.78, 5.5, armor.lightened(0.08))
	p.ball(-s * radius * 0.78, 5.5, armor.lightened(0.08))
	# Sword arm and sword.
	p.limb(-s * radius * 0.72, grip, armor.darkened(0.2), 3.6)
	_sword(p, grip, f.rotated(ang), 22.0)
	# Helmet with a visor slit facing you; it glows red as it winds up.
	p.ball(f * 2.0, 7.5, armor.darkened(0.1))
	p.quad(f * 6.0 + s * 3.5, f * 6.0 - s * 3.5, 2.0, Palette.OUTLINE)
	var eye := x.eased("eye", 1.0 if x.st.begins_with("wind") else 0.0, 12.0)
	if eye > 0.02:
		g.quad(f * 6.0 + s * 2.6, f * 6.0 - s * 2.6, 1.1, Color(1.0, 0.4, 0.3, eye))
	# Plume trailing behind the helmet.
	var plume_sway := s * sin(t * 3.0) * 2.0
	p.tube(PackedVector2Array([-f * 1.5, -f * 6.5 + plume_sway * 0.5 + s, -f * 12.0 + plume_sway + s * 2.0]), PackedFloat32Array([2.8, 2.6, 1.4]), Palette.PLUME)
	# Shield on the off hand.
	var sc := s * (radius * 0.85) + f * 6.0
	var shield := PackedVector2Array()
	for i in 9:
		shield.append(sc + Vector2.from_angle(f.angle() - 1.0 + 2.0 * float(i) / 8.0) * 7.0 - f * 3.0)
	for i in 9:
		shield.append(sc + Vector2.from_angle(f.angle() + 1.0 - 2.0 * float(i) / 8.0) * 3.0 - f * 3.0)
	p.poly(shield, Color(0.45, 0.3, 0.22))
	p.arc(sc - f * 3.0, 5.6, f.angle() - 0.9, f.angle() + 0.9, 1.2, Palette.STEEL.darkened(0.25), 8)
	p.circle(sc + f * 1.5, 1.6, Palette.STEEL, 10)


## harrier.gd: seen from above, broad wings spread on the soar, folded back
## in the dive, a fanned tail, a pale breast and a hooked beak; high up it's
## drawn above its shadow.
static func _draw_harrier(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var soar := x.lift
	var want := soar
	var rate := 60.0
	match x.st:
		"wind_dive":
			want = soar * 1.1
		"dive":
			want = 0.0
			rate = 260.0
		"perch":
			want = 0.0
			rate = 200.0
	var h: float = move_toward(float(x.mem.get("h", want)), want, x.dt * rate)
	x.mem["h"] = h
	var o := Vector2(0, -h)
	var s := f.orthogonal()
	var dive := 1.0 if x.st == "dive" else 0.0
	var wind := x.wk if x.st == "wind_dive" else 0.0
	var fold: float = x.eased("fold", 0.85 if x.st == "dive" else (0.15 + 0.35 * wind if x.st == "wind_dive" else (0.55 if x.st == "perch" else 0.0)), 14.0)
	var beat := sin(x.flap * (1.0 if x.st == "soar" else 2.2)) * (0.15 if x.st == "soar" else 0.35)
	if h > 6.0:
		# (the far shadow under it while it's high: a second, fainter one)
		p.oval(Vector2(0, x.r * 0.7), Vector2(x.r * 2.2, x.r * 0.7), f.angle(), Color(0, 0, 0, 0.12 * clampf(h / 40.0, 0.0, 1.0)))
	var col: Color = x.col
	# Tail: a fan of feathers behind.
	for k in 5:
		var a := (k - 2) * 0.16 * (1.0 - fold * 0.6)
		_feather(p, o - f * 6.0, (-f).rotated(a), 13.0, 4.0, C_HARRIER_WING.darkened(0.1 + 0.05 * absf(k - 2)))
	# Wings: long, stepped primaries; swept back as it folds.
	for sgn in [-1.0, 1.0]:
		var out: Vector2 = (s * sgn * (1.0 - fold) - f * (0.25 + fold * 0.9) + s * sgn * beat * 0.4).normalized()
		var span := 26.0 * (1.0 - fold * 0.45)
		var root: Vector2 = o + s * sgn * 4.0
		var wpts := PackedVector2Array([root + f * 4.0, root + out * span * 0.55 + f * 3.0, root + out * span, root + out * span * 0.9 - f * 6.0, root - f * 5.0])
		p.poly(wpts, C_HARRIER_WING, 1.3)
		for k in 4:
			var at: Vector2 = root + out * span * (0.62 + 0.11 * k)
			_feather(p, at, (out - f * 0.5).normalized(), 9.0 - k, 3.0, C_HARRIER_TIP)
		p.quad(root + out * span * 0.2, root + out * span * 0.85, 2.0, C_HARRIER_WING.lightened(0.15), 1.0)
	# Body: a pale breast, a darker back.
	p.egg(o, Vector2(9.0, 6.5), f.angle(), col, true)
	p.oval(o + f * 1.5, Vector2(5.5, 3.6), f.angle(), C_HARRIER_BELLY)
	# Head and hooked beak.
	var head := o + f * 9.0
	p.ball(head, 4.6, col.lightened(0.1))
	p.tri(head + f * 3.0 + s * 2.2, head + f * 8.5 + s * 0.2, head + f * 3.0 - s * 2.2, C_HARRIER_BEAK)
	p.tri(head + f * 8.5 + s * 0.2, head + f * 6.0 - s * 1.2, head + f * 7.4 + s * 1.0, C_HARRIER_BEAK.darkened(0.3))
	for sgn in [-1.0, 1.0]:
		g.circle(head + f * 1.6 + s * sgn * 2.4 + Vector2(0, -0.6), 1.2, Color(1.0, 0.85, 0.35) if x.st in ["wind_dive", "dive"] else Color(0.15, 0.12, 0.1), 8)
	if dive > 0.0:
		# Wind tearing off it in the dive.
		for k in 3:
			var q: Vector2 = o - f * (12.0 + k * 7.0) + s * (k - 1) * 6.0
			g.quad(q, q - f * 10.0, 1.2, Color(0.9, 0.95, 1.0, 0.35), 0.3)


## deepfin.gd: under water a dark shape, a fin and its wake; out of the water
## a heavy armoured fish with a jaw full of teeth, thrashing when stranded.
static func _draw_deepfin(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var R := x.r
	var s := f.orthogonal()
	var col: Color = x.col
	if x.st == "swim":
		p.oval(Vector2.ZERO, Vector2(R * 1.6, R * 0.7), f.angle(), Color(0.02, 0.08, 0.12, 0.45))
		var fin := f * 3.0
		p.poly(PackedVector2Array([fin + f * 6.0, fin - f * 7.0 + Vector2(0, -2), fin - f * 4.0 + Vector2(0, -12)]), col.lightened(0.15), 1.2)
		if x.vel.length() > 10.0:
			for sgn in [-1.0, 1.0]:
				p.quad(fin + f * 4.0, fin - f * 22.0 + s * sgn * 12.0, 1.4, Color(C_DEEPFIN_WATER, 0.45), 0.3)
		for k in 2:
			var ph := fmod(t * 0.7 + k * 0.5, 1.0)
			p.arc(Vector2.ZERO, 8.0 + ph * 16.0, 0.0, TAU, 1.3, Color(C_DEEPFIN_WATER, 0.4 * sin(ph * PI)), 20)
		g.circle(f * 7.0 + s * 3.0, 1.2, Color(0.75, 1.0, 0.85, 0.7), 8)
		g.circle(f * 7.0 - s * 3.0, 1.2, Color(0.75, 1.0, 0.85, 0.7), 8)
		return
	var rise := 1.0
	var thrash := 0.0
	if x.st in ["stranded", "crawl"]:
		thrash = sin(t * (14.0 if x.st == "stranded" else 7.0)) * (1.0 if x.st == "stranded" else 0.5)
	if x.st in ["rise", "wind", "dive"]:
		p.arc(Vector2.ZERO, R + 5.0, 0.0, TAU, 2.0, Color(C_DEEPFIN_WATER, 0.45), 24)
		p.arc(Vector2.ZERO, R + 9.0 + sin(t * 4.0) * 1.5, 0.0, TAU, 1.2, Color(C_DEEPFIN_WATER, 0.25), 24)
	# The body: one thick tube, a little curled when it thrashes.
	var spine := PackedVector2Array()
	var w := PackedFloat32Array()
	var widths := [15.0, 20.0, 18.0, 13.0, 8.0, 3.0]
	for k in 6:
		var u := k / 5.0
		var bend := s * (sin(t * 5.0 - u * 3.5) * 2.5 * u * minf(1.0, x.vel.length() / 60.0) + thrash * 7.0 * u * u)
		spine.append((f * R * (1.2 - 2.7 * u) + bend) * rise)
		w.append(widths[k] * rise)
	# Pectoral fins, splayed wide.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = spine[1]
		p.poly(PackedVector2Array([root + s * sgn * 7.0 * rise, root + (s * sgn * 17.0 - f * 7.0 + f * thrash * sgn * 3.0) * rise, root + (s * sgn * 12.0 - f * 12.0) * rise, root - f * 6.0 * rise]), C_DEEPFIN_FIN.darkened(0.2), 1.3)
	var tail: Vector2 = spine[5]
	var td := (spine[5] - spine[4]).normalized()
	p.poly(PackedVector2Array([tail, tail + (td * 9.0 + td.orthogonal() * 8.0) * rise, tail + td * 4.0 * rise, tail + (td * 9.0 - td.orthogonal() * 8.0) * rise]), C_DEEPFIN_FIN.darkened(0.25), 1.3)
	p.tube(spine, w, col)
	# Armour plates down its back and a crest.
	for k in range(1, 5):
		p.circle(spine[k] + Vector2(-0.6, -1.0), (3.2 - k * 0.4) * rise, Color(col.lightened(0.3), 0.85), 10)
	p.poly(PackedVector2Array([spine[1] - s * 1.5, spine[3] + Vector2(0, -7.0 * rise), spine[3] + s * 1.5]), C_DEEPFIN_FIN, 1.0)
	# The jaw: wide open in the wind-up and the leap, teeth showing.
	var open: float = x.eased("jaw", 7.0 if x.st in ["wind", "lunge"] else (3.0 if x.st == "stranded" else 1.2), 16.0)
	var head: Vector2 = spine[0]
	p.tri(head + f * 5.0 * rise + s * open, head - f * 5.0 * rise, head + f * 5.0 * rise - s * open, Color(0.12, 0.05, 0.07))
	if open > 2.5:
		for sgn in [-1.0, 1.0]:
			for k in 3:
				var at: Vector2 = head + f * (1.0 + k * 1.4) * rise + s * sgn * (open - 0.5 - k * 0.8)
				p.tri(at, at - s * sgn * 2.0 + f * 0.6, at + f * 1.4, C_DEEPFIN_TOOTH)
	p.oval(head - f * 2.0 * rise, Vector2(5.0, 3.0) * rise, f.angle(), C_DEEPFIN_BELLY)
	g.circle(head - f * 4.0 * rise + s * 5.0 * rise, 1.8, Color(0.85, 1.0, 0.7), 8)
	g.circle(head - f * 4.0 * rise - s * 5.0 * rise, 1.8, Color(0.85, 1.0, 0.7), 8)
	# Dripping out of the water.
	if x.st in ["stranded", "crawl", "lunge"]:
		for k in 3:
			var ph := fmod(t * 1.3 + k * 0.33, 1.0)
			p.circle(spine[k + 1] + s * (k - 1) * 6.0 + Vector2(0, ph * 10.0), 1.4 * (1.0 - ph), Color(C_DEEPFIN_WATER, 0.7), 6)


## towers/creatures.gd: an ember-bird with fans of flame feathers.
static func _draw_ashwing(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var r: float = x.r
	if x.st == "ashes":
		var k: float = clampf(x.age / 3.2, 0.0, 1.0)
		p.oval(Vector2(0, 4), Vector2(r * 1.2, r * 0.6), 0.0, C_ASHWING_ASH, 18)
		p.oval(Vector2(-2, 1), Vector2(r * 0.8, r * 0.4), 0.0, C_ASHWING_ASH.lightened(0.12), 16)
		for i in 5:
			var at := Vector2(cos(i * 1.7) * r * 0.7, 3.0 + sin(i * 2.3) * r * 0.25)
			g.circle(at, 1.5 + 2.0 * k * (0.6 + 0.4 * sin(t * 8.0 + i)), Color(1.0, 0.5, 0.2, 0.5 + 0.5 * k), 8)
		if k > 0.5:
			g.circle(Vector2(0, -2), r * 0.6 * (k - 0.5) * 2.0, Color(C_FLAME, 0.5), 14)
		return
	var s := f.orthogonal()
	var flap := sin(x.flap * 2.2) * 0.5 + 0.5
	var dive: bool = x.st == "dive"
	var gather: float = x.eased("gather", x.wk if x.st == "wind" else 0.0, 12.0)
	var span := r * (1.6 + 0.7 * flap) * (0.6 if dive else 1.0) * (1.0 - 0.3 * gather)
	# A tail of flame behind.
	for i in 4:
		var u := (i + 1) / 4.0
		g.circle(-f * r * (0.8 + u * 1.3) + s * sin(t * 7.0 + u * 5.0) * 3.0, r * (0.6 - u * 0.35), Color(C_FLAME, 0.7 - u * 0.4), 12)
	# Wings: fans of flame feathers.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = s * sgn * r * 0.45 - f * 1.5
		for j in 3:
			var d: Vector2 = (s * sgn * (1.0 - 0.25 * j) - f * (0.25 + 0.35 * j) + f * 0.3 * flap).normalized()
			_feather(p, root, d, span * (1.0 - 0.18 * j), r * 0.55, Color(0.95, 0.42 + 0.1 * j, 0.18), 1.0)
	p.egg(Vector2.ZERO, Vector2(r * 1.05, r * 0.7), f.angle(), x.col)
	p.egg(f * 1.0 + Vector2(-1, -1.5), Vector2(r * 0.6, r * 0.38), f.angle(), x.col.lightened(0.25), false)
	var head := f * r * 0.95
	p.ball(head, r * 0.48, x.col.lightened(0.1))
	p.tri(head + f * r * 0.45 + s * 2.0, head + f * r * 0.95, head + f * r * 0.45 - s * 2.0, Color(0.95, 0.8, 0.35))
	g.circle(head + f * 1.5 + s * 2.2, 1.3, C_CORE, 8)
	g.circle(head + f * 1.5 - s * 2.2, 1.3, C_CORE, 8)
	g.circle(Vector2.ZERO, r * 1.6, Color(C_FLAME, 0.12 + 0.1 * gather), 18)


## towers/creatures.gd: a bush that hides, then a maw in the leaves and thorny arms.
static func _draw_briar(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var r: float = x.r
	var hidden: bool = x.st == "hide"
	var open: float = x.eased("open", 0.0 if hidden else 1.0, 6.0)
	var sway := sin(t * 0.9 + x.seed_i) * 1.2
	# The bush: a mound of leaves, thorns poking through.
	var lumps := [Vector2(-r * 0.55, 2), Vector2(r * 0.55, 2), Vector2(0, -r * 0.35), Vector2(-r * 0.3, -r * 0.1 + 3), Vector2(r * 0.32, -r * 0.05 + 3)]
	for i in lumps.size():
		var at: Vector2 = lumps[i] + Vector2(sway * (0.5 + 0.2 * i), 0) + Vector2(0, -open * 3.0)
		p.ball(at, r * (0.62 if i < 3 else 0.48), C_LEAF.lightened(0.06 * (i % 2)))
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		var at := Vector2.from_angle(a) * r * 0.75
		p.tri(at + Vector2.from_angle(a + 1.6) * 2.0, at + Vector2.from_angle(a) * (4.5 + 2.0 * open), at - Vector2.from_angle(a + 1.6) * 2.0, C_BRIAR_THORN)
	for i in 4:
		p.circle(Vector2(cos(i * 1.9) * r * 0.5, sin(i * 2.7) * r * 0.4 - 3.0), 2.4, C_LEAF_HI, 8)
	if hidden:
		# Now and then two eyes blink in the leaves: the only tell.
		if fmod(t + x.seed_i * 0.37, 5.0) < 0.35:
			g.circle(Vector2(-3, -2), 1.1, Color(1.0, 0.85, 0.4, 0.7), 6)
			g.circle(Vector2(3, -2), 1.1, Color(1.0, 0.85, 0.4, 0.7), 6)
		return
	# Out of hiding: a maw in the leaves, and thorny arms.
	var s := f.orthogonal()
	var reach := 0.0
	if x.st == "wind_grab":
		reach = x.wk
	elif x.st == "grab":
		reach = 1.0
	elif x.st == "wind_swipe":
		reach = 0.6 * x.wk
	for sgn in [-1.0, 1.0]:
		var a: Vector2 = s * sgn * r * 0.6
		var b: Vector2 = a + (f * (10.0 + 14.0 * reach) + s * sgn * (8.0 - 4.0 * reach))
		p.tube(PackedVector2Array([a, (a + b) * 0.5 + s * sgn * 3.0, b]), PackedFloat32Array([3.2, 2.6, 1.8]), C_BARK)
		p.tri(b + s * 2.0, b + f * 5.0, b - s * 2.0, C_BRIAR_THORN)
	p.oval(f * r * 0.25 + Vector2(0, -2), Vector2(r * 0.42, r * 0.26 * (0.6 + 0.4 * open)), f.angle(), Palette.OUTLINE, 14)
	for k in 4:
		var at: Vector2 = f * r * 0.25 + s * (k - 1.5) * 2.6 + Vector2(0, -4)
		p.tri(at - s * 1.0, at + Vector2(0, 2.5), at + s * 1.0, C_BRIAR_THORN.lightened(0.2))
	g.circle(f * r * 0.1 + s * 4.0 + Vector2(0, -7), 1.4, Color(1.0, 0.8, 0.35), 8)
	g.circle(f * r * 0.1 - s * 4.0 + Vector2(0, -7), 1.4, Color(1.0, 0.8, 0.35), 8)


static func _draw_cinder(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var s := f.orthogonal()
	var spit := x.eased("spit", x.wk if x.st == "wind_spit" else 0.0, 12.0)
	var r := x.r * (1.0 + 0.15 * spit)
	p.poly(_flame(Vector2.ZERO, r, t, r * 0.9), x.col.darkened(0.15))
	g.fill_poly(_flame(Vector2(0, 0.5), r * 0.74, t + 0.4, r * 0.7), Color(C_FLAME, 0.9))
	g.circle(Vector2(0, 1.5), r * 0.42, C_FLAME_CORE, 14)
	g.circle(f * 3.0 + s * 3.0, 1.6, Palette.OUTLINE, 8)
	g.circle(f * 3.0 - s * 3.0, 1.6, Palette.OUTLINE, 8)
	if spit > 0.05:
		g.circle(f * 6.0, 1.0 + 2.2 * spit, Color(1.0, 1.0, 0.85, spit), 10)
	for i in 2:  # embers drifting up, fading in and out
		var ph := fmod(t * 0.9 + i * 0.5, 1.0)
		g.circle(Vector2(sin(t * 3.0 + i * 3.0) * 4.0, -r - 2.0 - ph * 10.0), 1.1, Color(C_EMBER, sin(ph * PI)), 8)


static func _draw_scorpling(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var color := x.col
	var s := f.orthogonal()
	var leg := color.darkened(0.35)
	for k in 3:
		for sgn in [-1.0, 1.0]:
			var ph: float = x.stride * 2.0 + k * 2.1 + (PI if sgn > 0.0 else 0.0)
			var root: Vector2 = s * sgn * radius * 0.45 + f * (3.0 - k * 3.5)
			var knee: Vector2 = root + s * sgn * 5.0 + f * 1.5
			var foot: Vector2 = knee + s * sgn * 2.5 - f * 2.5 + f * sin(ph) * 2.0 * (0.3 + x.move)
			p.tube(PackedVector2Array([root, knee, foot]), PackedFloat32Array([1.8, 1.6, 0.9]), leg, true, false)
	# Pincers that open and close.
	var snap := 0.4 + 0.6 * absf(sin(t * 3.0))
	for sgn in [-1.0, 1.0]:
		var elbow: Vector2 = f * radius * 0.85 + s * sgn * radius * 0.85
		var claw: Vector2 = f * radius * 1.35 + s * sgn * radius * 0.5
		p.tube(PackedVector2Array([f * radius * 0.35 + s * sgn * 3.5, elbow, claw]), PackedFloat32Array([2.4, 2.2, 3.0]), color.darkened(0.15), true, false)
		var cd: Vector2 = (claw - elbow).normalized()
		var co: Vector2 = cd.orthogonal() * sgn
		p.poly(PackedVector2Array([claw - co * 2.0, claw + cd * 6.0 - co * (0.5 + snap), claw + cd * 2.0]), color.darkened(0.05), 1.1)
		p.poly(PackedVector2Array([claw + co * 2.0, claw + cd * 5.0 + co * (0.5 + snap), claw + cd * 1.5]), color.darkened(0.05), 1.1)
	p.egg(-f * radius * 0.5, Vector2(radius * 0.62, radius * 0.66), f.angle(), color.darkened(0.08))
	p.egg(f * 1.5, Vector2(radius * 0.72, radius * 0.6), f.angle(), color)
	p.circle(f * (radius * 0.55 + 1.5) + s * 1.6, 0.9, Palette.OUTLINE, 8)
	p.circle(f * (radius * 0.55 + 1.5) - s * 1.6, 0.9, Palette.OUTLINE, 8)
	# The tail curls over the back and strikes forward on the sting.
	var strike := x.eased("strike", x.wk if x.st == "wind_sting" else 0.0, 14.0)
	var prev := Vector2.ZERO
	for k in 6:
		var u := float(k) / 5.0
		var at := -f * radius * (1.0 - u * 1.6) + s * sin(u * 3.0 + t * 1.5) * 2.5 - f * radius * 0.6 * (1.0 - strike) * u + f * radius * 1.4 * strike * u * u
		if k < 5:
			p.ball(at, 3.4 - u * 1.2, color.lightened(0.05 * k))
		else:
			var dir := (at - prev).normalized()
			p.poly(PackedVector2Array([at - dir.orthogonal() * 2.2, at + dir * 4.5, at + dir.orthogonal() * 2.2]), C_VENOM, 1.1)
			g.circle(at + dir * 3.5, 1.0, Color(C_VENOM.lightened(0.3), 0.6 + 0.4 * strike), 8)
		prev = at


static func _draw_ram(p: Pen, _g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var color := x.col
	var s := f.orthogonal()
	var lower := x.eased("lower", 1.0 if x.st in ["wind_charge", "charge"] else 0.0, 10.0)
	_legs(p, x, [radius * 0.45, -radius * 0.55], radius * 0.45, 7.0, 4.0, color.darkened(0.45), 1.3)
	var body := -f * (2.0 + 2.0 * lower)
	p.ball(body, radius, color)
	# Lumpy stone fleece: a ring of rough tufts on its back.
	for i in 7:
		var d := Vector2.from_angle(TAU * i / 7.0 + 0.3)
		var at := body + d * radius * 0.52 + Vector2(-1.0, -1.5)
		p.circle(at, radius * 0.3, color.darkened(0.22), 12)
		p.circle(at + Vector2(-0.6, -0.8), radius * 0.24, color.lightened(0.08), 12)
	p.quad(body - s * 6.0 - f * 3.0, body + s * 1.0 + f * 1.0, 1.1, color.darkened(0.35))
	p.quad(body + s * 1.0 + f * 1.0, body + s * 4.0 - f * 2.0, 1.1, color.darkened(0.35))
	# The head drops low before a charge, horns forward.
	var head := f * (radius * 0.72 + 5.0 * lower)
	p.ball(head, 6.8, color.darkened(0.12))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = head + s * sgn * 4.5 - f * 1.5
		_horn(p, root, s * sgn, -f, 9.0, 4.4, C_HORN)
	p.circle(head + f * 3.2 + s * 2.4, 1.3, Palette.OUTLINE, 8)
	p.circle(head + f * 3.2 - s * 2.4, 1.3, Palette.OUTLINE, 8)
	if lower > 0.3:  # snorting
		for i in 2:
			var ph := fmod(t * 2.5 + i * 0.5, 1.0)
			p.circle(head + f * (7.0 + ph * 6.0) + s * (i * 2.0 - 1.0) * (2.0 + ph * 3.0), 1.5 + ph * 2.0, Color(0.85, 0.85, 0.8, 0.4 * sin(ph * PI) * lower), 10)


static func _draw_wisp(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var s := f.orthogonal()
	var col := x.col
	var core := C_FLAME_CORE
	var gather := x.eased("gather", x.wk if x.st == "wind" else 0.0, 12.0)
	var k := (0.93 + 0.07 * sin(t * 9.0)) * (1.0 - 0.15 * gather)
	var r := radius * k
	var trail := -x.vel.normalized() if x.vel.length() > 20.0 else Vector2(0, 1)
	var tr := x.eased("trail_x", trail.x, 6.0)
	var ty := x.eased("trail_y", trail.y, 6.0)
	var back := Vector2(tr, ty).normalized() if Vector2(tr, ty).length() > 0.1 else Vector2(0, 1)
	p.circle(Vector2.ZERO, r + 1.6, Color(Palette.OUTLINE, 0.45), 18)  # a dim rim so it reads on pale floors
	g.circle(Vector2.ZERO, radius * 1.7, Color(col, 0.1), 20)
	g.circle(Vector2.ZERO, radius * 1.2, Color(col, 0.2), 18)
	for i in 4:  # a soft tail of flame
		var u := (i + 1) / 4.0
		g.circle(back * radius * (0.6 + u * 1.2) + back.orthogonal() * sin(t * 6.0 + u * 4.0) * 2.5, r * (0.75 - u * 0.5), Color(col, 0.75 - u * 0.4), 14)
	if x.st == "swoop":
		g.oval(Vector2.ZERO, Vector2(r * 1.3, r * 0.8), f.angle(), col, 18)
	else:
		g.circle(Vector2.ZERO, r, col, 18)
	g.circle(Vector2(-1.0, -1.5), r * 0.55, core.lerp(Color.WHITE, gather), 14)
	g.circle(f * 2.5 + s * 2.2, 1.3, Color(0.25, 0.12, 0.05), 8)
	g.circle(f * 2.5 - s * 2.2, 1.3, Color(0.25, 0.12, 0.05), 8)
	for i in 3:
		g.circle(Vector2.from_angle(t * 5.0 + TAU * i / 3.0) * radius * 1.25, 1.4, Color(col, 0.8), 8)


static func _draw_thornhound(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var radius := x.r
	var color := x.col
	var s := f.orthogonal()
	var crouch := x.eased("crouch", x.wk if x.st == "wind" else 0.0, 14.0)
	var leap := x.eased("leap", 1.0 if x.st == "lunge" else 0.0, 18.0)
	var c := -f * 3.0 * crouch + f * 2.0 * leap
	var leg := color.darkened(0.3)
	var st := x.stride * 1.5
	for sgn in [-1.0, 1.0]:
		for i in 2:
			var hip: Vector2 = c + f * (5.5 if i == 0 else -6.0) + s * sgn * 3.5
			var ph: float = st + (PI if (i == 0) == (sgn > 0.0) else 0.0)
			var foot: Vector2 = hip + s * sgn * (7.5 + 2.0 * crouch) + f * (sin(ph) * 4.5 * x.move + (3.0 if i == 0 else -3.0) * leap)
			p.tube(PackedVector2Array([hip, (hip + foot) * 0.5 + s * sgn * 1.0, foot]), PackedFloat32Array([3.0, 2.4, 2.0]), leg, true, false)
	var tail_end := c - f * (radius * 1.9) + s * sin(t * 4.0) * 4.0
	p.tube(PackedVector2Array([c - f * radius * 1.0, c - f * radius * 1.45 + s * sin(t * 4.0 + 0.6) * 1.5, tail_end]), PackedFloat32Array([3.2, 2.2, 1.2]), color.darkened(0.1))
	p.tri(tail_end + s * 1.5, tail_end - (tail_end - c).normalized() * -4.0, tail_end - s * 1.5, C_THORN)
	p.egg(c, Vector2(radius * (1.35 + 0.1 * leap), radius * 0.72), f.angle(), color)
	for i in 4:  # thorns down its back
		var at := c - f * (radius * 0.85 - i * 5.5)
		p.poly(PackedVector2Array([at + s * 2.0, at - f * 4.5 + Vector2(0, -1.5), at - s * 2.0]), C_THORN, 1.0)
	var head := c + f * radius * 1.12
	for sgn in [-1.0, 1.0]:
		p.poly(PackedVector2Array([head + s * sgn * 2.0 - f * 1.0, head + s * sgn * 5.5 - f * 5.0, head + s * sgn * 4.5]), color.darkened(0.25), 1.0)
	p.ball(head, 5.6, color.lightened(0.08))
	var open := x.eased("jaw", 1.0 if x.st in ["wind", "lunge"] else 0.0, 16.0)
	p.egg(head + f * 4.5, Vector2(3.6, 2.6 + open * 0.8), f.angle(), color.lightened(0.15), false)
	if open > 0.1:
		p.tri(head + f * 8.0 + s * 2.2 * open, head + f * 4.0, head + f * 8.0 - s * 2.2 * open, Palette.OUTLINE)
	p.circle(head + f * 7.6, 1.2, Palette.OUTLINE, 8)
	g.circle(head + f * 2.0 + s * 2.4, 1.2, C_EYE_GLOW, 8)
	g.circle(head + f * 2.0 - s * 2.4, 1.2, C_EYE_GLOW, 8)


# --- the beasts ------------------------------------------------------------------------

static func _draw_gryphon(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var color := x.col
	var s := f.orthogonal()
	var R := x.r
	var lift_y := 0.0
	if x.st == "wind_dive":
		lift_y = -40.0 * x.wk
	elif x.st == "dive":
		lift_y = -40.0 * clampf(1.0 - x.age / 0.28, 0.0, 1.0)  # (coming down)
	var o := Vector2(0, lift_y)
	# Wing pose: raised forward for the rake, swept forward for the gale,
	# folded back in the dive.
	var fwd := x.eased("wing_fwd", 0.5 if x.st == "wind_rake" else (0.8 if x.st == "wind_gale" else (-0.5 if x.st == "dive" else 0.0)), 10.0)
	var span := (0.82 + 0.18 * sin(x.flap)) * x.eased("wing_span", 0.7 if x.st == "dive" else 1.0, 10.0)
	# The lion's hindquarters, legs and tufted tail.
	var hips := o - f * R * 0.55
	_legs(p, x, [-R * 0.55], R * 0.45, 9.0, 5.0, color.darkened(0.25), 0.8)
	var sway := sin(t * 2.2)
	var tail := PackedVector2Array([hips - f * R * 0.35, hips - f * R * 0.8 + s * sway * 3.0, hips - f * R * 1.2 + s * sway * 7.0, hips - f * R * 1.45 + s * (sway * 9.0 + 4.0)])
	p.tube(tail, PackedFloat32Array([5.0, 4.0, 3.0, 2.4]), color.darkened(0.1))
	p.ball(tail[3], 4.8, color.darkened(0.45))
	p.egg(hips, Vector2(R * 0.62, R * 0.55), f.angle(), color.darkened(0.06))
	# Great feathered wings.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = o + s * sgn * R * 0.4 + f * 3.0
		var out: Vector2 = (s * sgn + f * fwd).normalized()
		var wrist: Vector2 = root + (out + f * 0.15).normalized() * R * 1.15 * span
		for i in 5:  # primaries, longest at the tip
			var along: Vector2 = root.lerp(wrist, 0.45 + 0.14 * i)
			var dir: Vector2 = (out * (0.15 + 0.2 * i) - f * (1.0 - 0.15 * i)).normalized()
			_feather(p, along, dir, R * (0.85 + 0.12 * i) * span, 10.0, C_GRYPHON_WING.darkened(0.12 * (i % 2)), 1.2)
		var covert := PackedVector2Array([root + f * 3.0, wrist + f * 2.0, wrist - f * 8.0 - out * 2.0, root.lerp(wrist, 0.5) - f * 16.0, root - f * 12.0])
		p.poly(covert, C_GRYPHON_WING.lightened(0.1), 1.4)
		p.quad(root.lerp(wrist, 0.2) - f * 3.0, wrist - f * 3.0, 1.0, C_GRYPHON_WING.darkened(0.2))
	# Chest and the eagle's head.
	p.egg(o, Vector2(R * 0.78, R * 0.66), f.angle(), color)
	for i in 3:
		p.circle(o + f * R * 0.35 + s * (i - 1) * 5.5 + Vector2(-0.5, -0.5), 3.4, C_GRYPHON_HEAD.darkened(0.1), 12)
	# Talons: forward and spread for the rake.
	var rake := x.eased("rake", x.wk if x.st == "wind_rake" else 0.0, 14.0)
	for sgn in [-1.0, 1.0]:
		var paw: Vector2 = o + f * R * (0.75 + 0.45 * rake) + s * sgn * R * 0.42
		p.limb(o + f * R * 0.3 + s * sgn * R * 0.38, paw, C_BEAK.darkened(0.25), 3.2)
		for c in 3:
			var cd: Vector2 = (f + s * sgn * (c - 1) * (0.5 + 0.4 * rake)).normalized()
			p.tri(paw + cd.orthogonal() * 1.2, paw + cd * (4.0 + 2.0 * rake), paw - cd.orthogonal() * 1.2, Palette.OUTLINE)
	var head := o + f * R * 0.72
	for sgn in [-1.0, 1.0]:  # ear tufts
		p.poly(PackedVector2Array([head + s * sgn * 4.0, head - f * 12.0 + s * sgn * 8.0, head - f * 3.0 + s * sgn * 9.0]), C_GRYPHON_HEAD.darkened(0.2), 1.2)
	p.ball(head, R * 0.42, C_GRYPHON_HEAD)
	var gape := x.eased("gape", 1.0 if x.st == "wind_gale" else 0.0, 12.0)
	var beak := head + f * R * 0.34
	p.poly(PackedVector2Array([beak + s * 4.5, beak + f * 7.0 + s * (1.0 + 2.0 * gape), beak + f * 11.0, beak + f * 7.0 - s * (1.0 + 2.0 * gape), beak - s * 4.5]), C_BEAK, 1.3)
	p.tri(beak + f * 8.5 + s * 1.2, beak + f * 11.0, beak + f * 8.5 - s * 1.2, C_BEAK.darkened(0.45))
	_beast_eye(p, g, head + f * 3.5 + s * 5.0, 2.1, C_EYE_GLOW, f)
	_beast_eye(p, g, head + f * 3.5 - s * 5.0, 2.1, C_EYE_GLOW, f)


static func _draw_kraken(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var color := x.col
	var s := f.orthogonal()
	var R := x.r
	var slam := x.eased("slam", x.wk if x.st == "wind_slam" else 0.0, 10.0)
	var ink := x.eased("ink", x.wk if x.st == "wind_ink" else 0.0, 12.0)
	# Eight arms trailing behind and around; raised and coiled for a slam.
	for i in 8:
		var base_a := f.angle() + PI + (float(i) - 3.5) * 0.27
		var length := R * (1.6 + 0.15 * ((i * 5) % 3)) * (1.0 - 0.3 * slam)
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		for k in 8:
			var u := float(k) / 7.0
			var a := base_a + sin(t * 1.6 + i * 1.3 + u * 3.0) * (0.3 + 0.5 * slam) * u
			pts.append(-f * R * 0.35 + Vector2.from_angle(a) * (R * 0.45 + u * length))
			w.append(lerpf(15.0, 2.2, u))
		p.tube(pts, w, color.darkened(0.08))
		for k in range(2, 7, 2):
			p.circle(pts[k], w[k] * 0.16 + 0.4, C_SUCKER, 8)
	# Two feeding arms in front; one lashes out across the sweep.
	var sweep := x.eased("sweep", x.wk if x.st == "wind_sweep" else 0.0, 12.0)
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		var lash: float = sweep if sgn > 0.0 else 0.0
		for k in 7:
			var u := float(k) / 6.0
			var curl: Vector2 = f * R * (0.4 + 0.6 * u) + s * sgn * R * (0.7 + 0.3 * u) + (f.rotated(sgn * (1.6 - 1.6 * u))) * sin(t * 2.0 + sgn) * 3.0 * u
			var reach: Vector2 = s * sgn * R * 0.6 + f * (R * 0.5 + u * SWEEP_REACH * 0.6)
			pts.append(curl.lerp(reach, lash))
			w.append(lerpf(9.0, 2.0, u))
		p.tube(pts, w, color.darkened(0.12))
		for k in range(2, 6, 2):
			p.circle(pts[k], w[k] * 0.16 + 0.4, C_SUCKER, 8)
	# The mantle behind, swelling as it readies its ink; the head in front.
	var pulse := 1.0 + 0.04 * sin(t * 2.0) + 0.12 * ink
	p.egg(-f * R * 0.45, Vector2(R * 1.0, R * 0.78) * pulse, f.angle(), color)
	for i in 4:
		p.circle(-f * R * (0.2 + 0.25 * (i % 2)) + s * (i - 1.5) * R * 0.35 + Vector2(-1, -1), R * 0.1, color.darkened(0.2), 12)
	p.ball(f * R * 0.2, R * 0.72, color.lightened(0.05))
	p.tri(f * R * 0.85 + s * 4.0, f * R * 0.85 + f * 7.0, f * R * 0.85 - s * 4.0, Palette.OUTLINE)
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = f * R * 0.4 + s * sgn * R * 0.42
		p.circle(e, 8.4, Palette.OUTLINE, 18)
		g.circle(e, 7.0, Color(0.98, 0.9, 0.55), 18)
		g.oval(e + f * 1.0, Vector2(1.6, 4.8 * (1.0 - 0.4 * slam)), f.angle(), Palette.OUTLINE, 12)
		g.circle(e + Vector2(-2.0, -2.5), 1.4, Color(1, 1, 1, 0.8), 8)


static func _draw_wyvern(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var color := x.col
	var s := f.orthogonal()
	var R := x.r
	var span := 0.8 + 0.2 * sin(x.flap)
	# The tail lashes across in the tail sweep.
	var swing := x.eased("swing", x.wk * 1.2 if x.st == "wind_tail" else 0.0, 12.0)
	var tail := PackedVector2Array()
	var tw := PackedFloat32Array()
	for k in 9:
		var u := float(k) / 8.0
		tail.append(-f * (R * 0.5 + u * R * 1.9) + s * sin(t * 2.5 + u * 3.0) * 7.0 * u + s * swing * u * R)
		tw.append(lerpf(10.0, 2.5, u))
	p.tube(tail, tw, color.darkened(0.15))
	var tip := tail[8]
	var td := (tail[8] - tail[7]).normalized()
	p.poly(PackedVector2Array([tip - td * 2.0, tip + td.orthogonal() * 5.0 + td * 2.0, tip + td * 9.0, tip - td.orthogonal() * 5.0 + td * 2.0]), color.darkened(0.4), 1.3)
	for k in range(1, 7, 2):
		var d := (tail[k + 1] - tail[k]).normalized()
		p.tri(tail[k] + d.orthogonal() * 2.0, tail[k] - d * 4.0, tail[k] - d.orthogonal() * 2.0, C_HORN.darkened(0.25))
	_legs(p, x, [-R * 0.25], R * 0.5, 9.0, 5.0, color.darkened(0.3), 0.7)
	# Membrane wings.
	for sgn in [-1.0, 1.0]:
		_membrane(p, s * sgn * R * 0.45 + f * 4.0, s * sgn, -f, R * 2.3, span, color.darkened(0.38), color.darkened(0.15), 2.4)
	p.egg(Vector2.ZERO, Vector2(R * 0.85, R * 0.68), f.angle(), color)
	for k in 4:  # spines down the back
		var at := -f * (R * 0.55 - k * R * 0.32)
		p.poly(PackedVector2Array([at + s * 2.5, at - f * 6.0 + Vector2(0, -1.0), at - s * 2.5]), C_HORN.darkened(0.15), 1.0)
	# Neck and head: drawn back while it breathes in, thrust forward to breathe.
	var breath := x.eased("breath", x.wk if x.st == "wind_breath" else 0.0, 10.0)
	var head := f * R * (1.05 - 0.15 * breath) + s * sin(t * 1.4) * 2.0
	p.tube(PackedVector2Array([f * R * 0.3, f * R * 0.7 + s * sin(t * 1.4) * 1.0, head]), PackedFloat32Array([13.0, 10.0, 8.0]), color.lightened(0.04))
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = head - f * 3.0 + s * sgn * 4.0
		p.tube(PackedVector2Array([root, root - f * 6.0 + s * sgn * 4.0, root - f * 11.0 + s * sgn * 4.5]), PackedFloat32Array([3.4, 2.4, 1.0]), C_HORN)
	p.egg(head, Vector2(R * 0.36, R * 0.3), f.angle(), color.lightened(0.08))
	p.egg(head + f * 6.0, Vector2(5.5, 4.2), f.angle(), color.lightened(0.12), false)
	p.circle(head + f * 10.0 + s * 1.6, 0.9, Palette.OUTLINE, 8)
	p.circle(head + f * 10.0 - s * 1.6, 0.9, Palette.OUTLINE, 8)
	_beast_eye(p, g, head + f * 2.0 + s * 4.6, 2.2, Color(1.0, 0.8, 0.3), f)
	_beast_eye(p, g, head + f * 2.0 - s * 4.6, 2.2, Color(1.0, 0.8, 0.3), f)
	if breath > 0.02:
		g.circle(head + f * R * 0.45, 3.0 + 5.0 * breath, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * breath), 16)
		g.circle(head + f * R * 0.45, 1.5 + 2.5 * breath, Color(C_FLAME_CORE, breath), 12)
	var embers := x.eased("embers", x.wk if x.st == "wind_embers" else 0.0, 12.0)
	if embers > 0.02:
		for i in 3:
			g.circle(f * R * (0.35 + 0.18 * i) + s * sin(t * 6.0 + i) * 1.5, 1.6 + embers * 1.4, Color(C_EMBER, embers), 10)


static func _draw_manticore(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var color := x.col
	var s := f.orthogonal()
	var R := x.r
	var span := 0.82 + 0.18 * sin(x.flap)
	for sgn in [-1.0, 1.0]:
		_membrane(p, s * sgn * R * 0.35 - f * 2.0, s * sgn, -f, R * 1.75, span, C_BAT_WING, C_BAT_WING.darkened(0.3), 2.0)
	_legs(p, x, [R * 0.5, -R * 0.5], R * 0.5, 9.0, 5.5, color.darkened(0.2), 0.9)
	# The scorpion tail: segments arching over the back, poised forward for the spikes.
	var curl := x.eased("curl", 1.0 if x.st == "wind_spikes" else 0.0, 8.0)
	var prev := Vector2.ZERO
	for k in 9:
		var u := float(k) / 8.0
		var at := -f * R * (0.7 + u * 1.3) + s * sin(t * 2.0 + u * 2.5) * 6.0 * u - f * R * u * u * (0.6 - curl * 2.0)
		if k < 8:
			p.ball(at, lerpf(6.5, 3.8, u), color.darkened(0.2 + 0.03 * (k % 2)))
		else:
			var dir := (at - prev).normalized()
			p.poly(PackedVector2Array([at - dir.orthogonal() * 4.5, at + dir * 9.0, at + dir.orthogonal() * 4.5]), C_VENOM, 1.4)
			for sgn in [-1.0, 1.0]:
				p.tri(at + dir.orthogonal() * sgn * 3.0, at + dir.orthogonal() * sgn * 8.0 - dir * 2.0, at + dir.orthogonal() * sgn * 2.0 + dir * 2.0, C_HORN)
			g.circle(at + dir * 7.0, 1.4 + curl, Color(C_VENOM.lightened(0.3), 0.5 + 0.5 * curl), 8)
		prev = at
	p.egg(-f * 2.0, Vector2(R * 0.95, R * 0.74), f.angle(), color)
	# The mane, flaring as it roars.
	var roar := x.eased("roar", x.wk if x.st == "wind_roar" else 0.0, 10.0)
	var mane_at := f * R * 0.7
	for i in 14:
		var a := TAU * i / 14.0 + sin(t * 2.0 + i) * 0.04
		var d := Vector2.from_angle(a)
		p.poly(PackedVector2Array([mane_at + d.rotated(0.3) * R * 0.3, mane_at + d * R * (0.62 + 0.14 * roar + 0.05 * (i % 2)), mane_at + d.rotated(-0.3) * R * 0.3]), C_MANE.darkened(0.12 * (i % 2)), 1.2)
	# A raised paw for the claw swipe.
	var claw := x.eased("claw", x.wk if x.st == "wind_claw" else 0.0, 14.0)
	if claw > 0.02:
		var paw := f * R * (0.6 + 0.6 * claw) - s * R * 0.65
		p.limb(-s * R * 0.5, paw, color.darkened(0.1), 6.0)
		for c in 3:
			var cd := (f + s * (c - 1) * 0.4).normalized()
			p.tri(paw + cd.orthogonal() * 1.4, paw + cd * 7.0 * claw, paw - cd.orthogonal() * 1.4, C_EYE)
	p.ball(mane_at, R * 0.38, color.lightened(0.1))
	p.egg(mane_at + f * 5.0, Vector2(4.6, 5.4), f.angle(), color.lightened(0.2), false)
	p.tri(mane_at + f * 7.5 + s * 2.0, mane_at + f * 9.5, mane_at + f * 7.5 - s * 2.0, Palette.OUTLINE)
	if roar > 0.05:
		p.oval(mane_at + f * 9.0, Vector2(1.5 + 3.0 * roar, 2.5 + 2.5 * roar), f.angle(), Color(0.25, 0.05, 0.05), 12)
		p.tri(mane_at + f * 8.5 + s * 2.0, mane_at + f * 11.0 + s * 1.5, mane_at + f * 8.5 + s * 1.0, C_EYE)
		p.tri(mane_at + f * 8.5 - s * 2.0, mane_at + f * 11.0 - s * 1.5, mane_at + f * 8.5 - s * 1.0, C_EYE)
	_beast_eye(p, g, mane_at + f * 2.5 + s * 4.5, 2.2, C_EYE_GLOW, f)
	_beast_eye(p, g, mane_at + f * 2.5 - s * 4.5, 2.2, C_EYE_GLOW, f)


static func _draw_firebird(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var s := f.orthogonal()
	var R := x.r
	if x.st == "ashes":
		# A smouldering heap, glowing brighter as it's about to rise.
		var glow := clampf(x.age / 2.2, 0.0, 1.0)
		p.egg(Vector2.ZERO, Vector2(R * 0.95, R * 0.62), 0.0, C_ASH)
		for i in 5:
			p.circle(Vector2.from_angle(TAU * i / 5.0 + 0.5) * R * 0.45 + Vector2(-1, -2), R * 0.25, C_ASH.lightened(0.08), 12)
		g.circle(Vector2.ZERO, R * (0.7 + 0.8 * glow), Color(1.0, 0.45, 0.15, 0.1 + 0.2 * glow), 24)
		for i in 8:
			var a := TAU * i / 8.0
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
			g.circle(Vector2.from_angle(a) * R * 0.5 * Vector2(1.0, 0.65), 2.5 + 1.5 * glow, Color(1.0, 0.45 + 0.35 * glow, 0.2, (0.3 + 0.6 * glow) * (0.6 + 0.4 * pulse)), 10)
		if glow > 0.6:
			g.arc(Vector2.ZERO, R * (0.3 + glow), 0.0, TAU, 2.5, Color(1.0, 0.7, 0.3, (glow - 0.6) * 2.0), 28)
		return
	var span := 0.8 + 0.2 * sin(x.flap)
	var back := x.eased("swept", 1.0 if x.st == "swoop" else (-0.4 if x.st == "wind_storm" else 0.0), 10.0)
	g.circle(Vector2.ZERO, R * 1.5, Color(1.0, 0.5, 0.2, 0.1), 24)
	# Tail plumes: three long streamers, each with a burning eye at its end.
	for i in 3:
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		for k in 7:
			var u := float(k) / 6.0
			pts.append(-f * R * (0.5 + u * (1.4 + 0.25 * (1 - absi(i - 1)))) + s * ((i - 1) * 6.0 * u + sin(t * 4.0 + u * 4.0 + i) * 4.0 * u))
			w.append(lerpf(6.0, 2.0, u))
		p.tube(pts, w, Color(1.0, 0.45, 0.15))
		g.circle(pts[6], 3.2, C_FLAME, 12)
		g.circle(pts[6], 1.5, C_FLAME_CORE, 10)
	# Flame-feathered wings, gold at the heart.
	for sgn in [-1.0, 1.0]:
		var root: Vector2 = s * sgn * R * 0.3 + f * 4.0
		var out: Vector2 = (s * sgn - f * back * 0.6).normalized()
		var wrist: Vector2 = root + out * R * 1.2 * span
		for i in 6:
			var along: Vector2 = root.lerp(wrist, 0.3 + 0.14 * i)
			var dir: Vector2 = (out * (0.2 + 0.18 * i) - f * (1.0 - 0.12 * i) + f * 0.2 * sin(t * 6.0 + i)).normalized()
			var length: float = R * (0.75 + 0.12 * i) * span
			_feather(p, along, dir, length, 7.0, Color(1.0, 0.42 + 0.04 * i, 0.15), 1.2)
			g.poly(PackedVector2Array([along + dir * length * 0.15, along + dir * length * 0.5 + dir.orthogonal() * 1.6, along + dir * length * 0.85, along + dir * length * 0.5 - dir.orthogonal() * 1.6]), Color(1.0, 0.78, 0.35, 0.85), 0.0)
		p.poly(PackedVector2Array([root + f * 2.0, wrist, wrist - f * 6.0, root - f * 8.0]), Color(1.0, 0.62, 0.22), 1.3)
	p.egg(Vector2.ZERO, Vector2(R * 0.7, R * 0.58), f.angle(), x.col)
	g.circle(Vector2(-1.0, -1.5), R * 0.3, Color(C_FLAME_CORE, 0.55), 16)
	var head := f * R * 0.72
	for i in 3:  # a crest of flame
		var d := (-f + s * (i - 1) * 0.5).normalized()
		g.poly(_flame_tongue(head + d * 3.0, d, 9.0 + 2.0 * sin(t * 7.0 + i), 3.0), Color(1.0, 0.7, 0.25, 0.9), 0.0)
	p.ball(head, R * 0.34, Color(1.0, 0.68, 0.3))
	p.poly(PackedVector2Array([head + f * R * 0.28 + s * 3.0, head + f * (R * 0.28 + 7.0), head + f * R * 0.28 - s * 3.0]), C_BEAK, 1.2)
	var storm := x.eased("storm", x.wk if x.st == "wind_storm" else 0.0, 10.0)
	_beast_eye(p, g, head + f * 2.0 + s * 4.0, 1.9, Color(1.0, 1.0, 0.8).lerp(Color.WHITE, storm), f)
	_beast_eye(p, g, head + f * 2.0 - s * 4.0, 1.9, Color(1.0, 1.0, 0.8).lerp(Color.WHITE, storm), f)
	if storm > 0.02:
		g.circle(Vector2.ZERO, R * (1.0 + 0.5 * storm), Color(1.0, 0.6, 0.25, 0.18 * storm), 24)


static func _draw_chimera(p: Pen, g: Pen, x: Ctx) -> void:
	var t := x.t
	var f := x.f
	var color := x.col
	var s := f.orthogonal()
	var R := x.r
	# The serpent tail: rears and opens its mouth for the spikes.
	var rear := x.eased("rear", x.wk if x.st == "wind_spikes" else 0.0, 10.0)
	var tail := PackedVector2Array()
	var tw := PackedFloat32Array()
	for k in 9:
		var u := float(k) / 8.0
		tail.append(-f * R * (0.6 + u * 1.5 * (1.0 - 0.35 * rear)) + s * sin(t * 3.0 + u * 4.0) * 9.0 * u * (1.0 - 0.5 * rear))
		tw.append(lerpf(9.0, 4.0, u))
	p.tube(tail, tw, C_SERPENT)
	for k in range(1, 8, 2):
		p.circle(tail[k] + Vector2(-0.6, -0.8), tw[k] * 0.18, C_SERPENT.lightened(0.3), 8)
	var sh := tail[8]
	var sd := (tail[8] - tail[7]).normalized().lerp(f, rear).normalized()
	p.egg(sh + sd * 3.0, Vector2(6.5, 5.0), sd.angle(), C_SERPENT.lightened(0.05))
	if rear > 0.1:
		p.tri(sh + sd * 9.5 + sd.orthogonal() * 2.5 * rear, sh + sd * 5.0, sh + sd * 9.5 - sd.orthogonal() * 2.5 * rear, Palette.OUTLINE)
	else:
		var flick := maxf(0.0, sin(t * 2.3)) * 4.0
		p.quad(sh + sd * 8.5, sh + sd * (8.5 + flick), 0.9, Color(0.85, 0.25, 0.3))
	g.circle(sh + sd * 4.0 + sd.orthogonal() * 2.6, 1.0, Color(0.95, 0.3, 0.25), 8)
	g.circle(sh + sd * 4.0 - sd.orthogonal() * 2.6, 1.0, Color(0.95, 0.3, 0.25), 8)
	# Paws: forward for the maul.
	var maul := x.eased("maul", x.wk if x.st == "wind_maul" else 0.0, 14.0)
	_legs(p, x, [-R * 0.5], R * 0.55, 9.0, 6.0, color.darkened(0.2), 0.9)
	for sgn in [-1.0, 1.0]:
		var hip: Vector2 = f * R * 0.4 + s * sgn * R * 0.55
		var paw: Vector2 = hip + f * (6.0 + 12.0 * maul) + s * sgn * 4.0 + f * sin(x.stride * 0.9 + (PI if sgn > 0.0 else 0.0)) * 5.0 * x.move
		p.limb(hip, paw, color.darkened(0.2), 6.0)
		if maul > 0.1:
			for c in 3:
				var cd: Vector2 = (f + s * (c - 1) * 0.4).normalized()
				p.tri(paw + cd.orthogonal() * 1.2, paw + cd * 6.0 * maul, paw - cd.orthogonal() * 1.2, C_EYE)
	p.egg(Vector2.ZERO, Vector2(R * 0.95, R * 0.78), f.angle(), color)
	# The goat's head on one side: lowered for the charge.
	var charge := x.eased("goat", 1.0 if x.st in ["wind_charge", "charge"] else 0.0, 10.0)
	var goat := s * R * 0.58 + f * R * (0.45 + 0.35 * charge)
	p.tube(PackedVector2Array([s * R * 0.4, goat.lerp(s * R * 0.4, 0.4), goat]), PackedFloat32Array([9.0, 8.0, 7.0]), C_GOAT.darkened(0.1))
	p.egg(goat, Vector2(R * 0.3, R * 0.25), f.angle(), C_GOAT)
	p.tri(goat + f * 5.0 + s * 1.5, goat + f * 9.0 + s * 0.5, goat + f * 5.0 - s * 1.0, C_GOAT.darkened(0.35))  # beard
	for sgn in [-1.0, 1.0]:
		_horn(p, goat - f * 1.5 + s * sgn * 3.0, s * sgn, -f, 8.0, 3.6, C_HORN.darkened(0.1))
	p.circle(goat + f * 3.0 + s * 2.6, 1.1, Palette.OUTLINE, 8)
	p.circle(goat + f * 3.0 - s * 2.6, 1.1, Palette.OUTLINE, 8)
	# The lion's head and mane.
	var lion := -s * R * 0.2 + f * R * 0.75
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0 + sin(t * 1.5 + i) * 0.04)
		p.poly(PackedVector2Array([lion + d.rotated(0.32) * R * 0.28, lion + d * R * (0.55 + 0.05 * (i % 2)), lion + d.rotated(-0.32) * R * 0.28]), C_MANE.darkened(0.12 * (i % 2)), 1.2)
	p.ball(lion, R * 0.34, color.lightened(0.12))
	p.egg(lion + f * 5.0, Vector2(4.4, 5.2), f.angle(), color.lightened(0.22), false)
	p.tri(lion + f * 7.5 + s * 2.0, lion + f * 9.5, lion + f * 7.5 - s * 2.0, Palette.OUTLINE)
	_beast_eye(p, g, lion + f * 2.5 + s * 4.2, 2.1, C_EYE_GLOW, f)
	_beast_eye(p, g, lion + f * 2.5 - s * 4.2, 2.1, C_EYE_GLOW, f)
	var breath := x.eased("breath", x.wk if x.st == "wind_breath" else 0.0, 10.0)
	if breath > 0.02:
		g.circle(lion + f * R * 0.45, 3.0 + 5.0 * breath, Color(1.0, 0.6, 0.2, 0.6 + 0.4 * breath), 16)
		g.circle(lion + f * R * 0.45, 1.5 + 2.5 * breath, Color(C_FLAME_CORE, breath), 12)


# --- the Pen (enemy.gd) ------------------------------------------------------------------
## Builds a whole creature as one list of triangles and sends it in one draw
## call. Every shape goes through `xf` (position, scale, squash and lift);
## `tint` eases every colour toward white (a hit), `danger` toward red.

class Pen:
	const Pal := preload("res://scripts/palette.gd")
	const LIGHT := Vector2(-0.7, -0.7)  # toward the top-left, where light comes from
	const RED := Color(1.0, 0.22, 0.18)
	static var _fans := {}  # sides -> unit circle as triangles

	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var xf := Transform2D.IDENTITY
	var tint := 0.0
	var danger := 0.0
	var dead := false
	var _one := PackedColorArray()

	func reset() -> void:
		pts.resize(0)
		cols.resize(0)
		xf = Transform2D.IDENTITY
		tint = 0.0
		danger = 0.0
		dead = false

	static func fan(n: int) -> PackedVector2Array:
		if not _fans.has(n):
			var ring := PackedVector2Array()
			for i in n:
				ring.append(Vector2.from_angle(i * TAU / n))
			var tris := PackedVector2Array()
			for i in n - 2:
				tris.append_array([ring[0], ring[i + 1], ring[i + 2]])
			_fans[n] = tris
		return _fans[n]

	## Enough sides that a circle looks round at its size, and no more.
	static func sides(r: float) -> int:
		return clampi(int(r * 0.85) + 7, 8, 32)

	func _fill(col: Color, n: int) -> void:
		col = Pal.toon(col)  # (LITE's brighter, more cartoony colours: palette.gd)
		if danger > 0.0:
			# Toward red, less on the dark outlines so the shapes still read.
			var k := danger * 0.6 * clampf(col.get_luminance() * 2.5, 0.25, 1.0)
			col = Color(col.lerp(RED, k), col.a)
		if tint > 0.0:
			col = Color(col.lerp(Color(1.0, 0.97, 0.92), tint), col.a)
		if dead:
			var l := col.get_luminance()
			col = Color(col.lerp(Color(l, l, l), 0.8), col.a * 0.55)
		_one.resize(n)
		_one.fill(col)
		cols.append_array(_one)

	func circle(at: Vector2, r: float, col: Color, n := 0) -> void:
		var tris := fan(n if n > 0 else sides(r))
		pts.append_array((xf * Transform2D(0.0, Vector2(r, r), 0.0, at)) * tris)
		_fill(col, tris.size())

	func oval(at: Vector2, rad: Vector2, angle: float, col: Color, n := 0) -> void:
		var tris := fan(n if n > 0 else sides(maxf(rad.x, rad.y)))
		pts.append_array((xf * Transform2D(angle, rad, 0.0, at)) * tris)
		_fill(col, tris.size())

	## A ball lit from the top-left, with a soft outline.
	func ball(at: Vector2, r: float, col: Color, outline := true) -> void:
		if outline:
			if r >= 6.0:  # the soft rim; small balls don't need it
				circle(at, r + 1.6 * Pal.TOON_LINE + 0.9, Color(Pal.OUTLINE, 0.3))
			circle(at, r + 1.6 * Pal.TOON_LINE, Pal.OUTLINE)
		circle(at, r, col.darkened(0.35))
		circle(at + Vector2(-r * 0.12, -r * 0.14), r * 0.86, col)
		circle(at + Vector2(-r * 0.32, -r * 0.36), r * 0.34, Color(col.lightened(0.45), 0.55))

	## An oval ball (bodies), lit the same way.
	func egg(at: Vector2, rad: Vector2, angle: float, col: Color, outline := true) -> void:
		if outline:
			oval(at, rad + Vector2.ONE * (1.6 * Pal.TOON_LINE + 0.9), angle, Color(Pal.OUTLINE, 0.3))
			oval(at, rad + Vector2.ONE * 1.6 * Pal.TOON_LINE, angle, Pal.OUTLINE)
		var m := minf(rad.x, rad.y)
		oval(at, rad, angle, col.darkened(0.35))
		oval(at + Vector2(-m * 0.12, -m * 0.14), rad * 0.86, angle, col)
		oval(at + Vector2(-m * 0.3, -m * 0.34), rad * 0.36, angle, Color(col.lightened(0.45), 0.5))

	## A straight band from a to b, wa wide at a and wb at b.
	func quad(a: Vector2, b: Vector2, wa: float, col: Color, wb := -1.0) -> void:
		var d := b - a
		if d.length_squared() < 0.0001:
			return
		if wb < 0.0:
			wb = wa
		var o := d.normalized().orthogonal() * 0.5
		pts.append_array(xf * PackedVector2Array([a + o * wa, b + o * wb, b - o * wb, a + o * wa, b - o * wb, a - o * wa]))
		_fill(col, 6)

	func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
		pts.append_array(xf * PackedVector2Array([a, b, c]))
		_fill(col, 3)

	## A thick outlined stroke with round ends (limbs, handles).
	func limb(a: Vector2, b: Vector2, col: Color, w: float, outline := true) -> void:
		if outline:
			var ow := w + 3.2 * Pal.TOON_LINE
			quad(a, b, ow, Pal.OUTLINE)
			circle(a, ow * 0.5, Pal.OUTLINE, 8)
			circle(b, ow * 0.5, Pal.OUTLINE, 8)
		quad(a, b, w, col)
		circle(a, w * 0.5, col, 8)
		circle(b, w * 0.5, col, 8)

	## A tapering outlined tube through points (tails, necks, tentacles),
	## shaded: darker below, a lighter band on the side toward the light.
	func tube(p: PackedVector2Array, w: PackedFloat32Array, col: Color, outline := true, shade := true) -> void:
		var n := p.size()
		if n < 2:
			return
		var nrm := PackedVector2Array()
		nrm.resize(n)
		for i in n:
			nrm[i] = (p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]).normalized().orthogonal()
		if outline:
			_strip(p, nrm, w, 1.0, 3.2 * Pal.TOON_LINE, Pal.OUTLINE, 0.0)
			circle(p[0], w[0] * 0.5 + 1.6 * Pal.TOON_LINE, Pal.OUTLINE, 10)
			circle(p[n - 1], w[n - 1] * 0.5 + 1.6 * Pal.TOON_LINE, Pal.OUTLINE, 10)
		var base := col.darkened(0.3) if shade else col
		_strip(p, nrm, w, 1.0, 0.0, base, 0.0)
		circle(p[0], w[0] * 0.5, base, 10)
		circle(p[n - 1], w[n - 1] * 0.5, base, 10)
		if shade:
			_strip(p, nrm, w, 0.55, 0.0, col, 0.2)

	func _strip(p: PackedVector2Array, nrm: PackedVector2Array, w: PackedFloat32Array, k: float, extra: float, col: Color, shift: float) -> void:
		var n := p.size()
		var sa := PackedVector2Array()
		var sb := PackedVector2Array()
		sa.resize(n)
		sb.resize(n)
		for i in n:
			var h := (w[i] * k + extra) * 0.5
			var c := p[i]
			if shift != 0.0:
				c += nrm[i] * nrm[i].dot(LIGHT) * w[i] * shift
			sa[i] = c + nrm[i] * h
			sb[i] = c - nrm[i] * h
		sa = xf * sa
		sb = xf * sb
		var q := PackedVector2Array()
		q.resize((n - 1) * 6)
		for i in n - 1:
			var j := i * 6
			q[j] = sa[i]
			q[j + 1] = sa[i + 1]
			q[j + 2] = sb[i + 1]
			q[j + 3] = sa[i]
			q[j + 4] = sb[i + 1]
			q[j + 5] = sb[i]
		pts.append_array(q)
		_fill(col, q.size())

	## A filled polygon with a soft outline grown around it.
	func poly(p: PackedVector2Array, col: Color, outline := 1.6) -> void:
		outline *= Pal.TOON_LINE
		if outline > 0.0:
			if outline >= 1.3:  # the soft rim (thin details go without)
				fill_poly(grow(p, outline + 0.9), Color(Pal.OUTLINE, 0.3))
			fill_poly(grow(p, outline), Pal.OUTLINE)
		fill_poly(p, col)

	func fill_poly(p: PackedVector2Array, col: Color) -> void:
		var q := xf * p
		var idx := Geometry2D.triangulate_polygon(q)
		if idx.is_empty():
			return
		var out := PackedVector2Array()
		out.resize(idx.size())
		for i in idx.size():
			out[i] = q[idx[i]]
		pts.append_array(out)
		_fill(col, out.size())

	## The polygon pushed outward by d (mitred, capped at sharp points).
	static func grow(p: PackedVector2Array, d: float) -> PackedVector2Array:
		var n := p.size()
		var area := 0.0
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			area += a.x * b.y - b.x * a.y
		var sg := 1.0 if area > 0.0 else -1.0
		var out := PackedVector2Array()
		out.resize(n)
		for i in n:
			var n1 := (p[i] - p[(i - 1 + n) % n]).normalized().orthogonal() * sg
			var n2 := (p[(i + 1) % n] - p[i]).normalized().orthogonal() * sg
			var m := n1 + n2
			m = m.normalized() if m.length_squared() > 0.0001 else n1
			out[i] = p[i] + m * (d / maxf(0.4, m.dot(n1)))
		return out

	## A band along a circle's arc, w wide (rings, rims).
	func arc(at: Vector2, r: float, a0: float, a1: float, w: float, col: Color, n := 24) -> void:
		var q := PackedVector2Array()
		q.resize(n * 6)
		var po := Vector2.ZERO
		var pi := Vector2.ZERO
		for i in n + 1:
			var d := Vector2.from_angle(lerpf(a0, a1, float(i) / n))
			var ou := at + d * (r + w * 0.5)
			var inn := at + d * maxf(0.0, r - w * 0.5)
			if i > 0:
				var j := (i - 1) * 6
				q[j] = po
				q[j + 1] = ou
				q[j + 2] = inn
				q[j + 3] = po
				q[j + 4] = inn
				q[j + 5] = pi
			po = ou
			pi = inn
		pts.append_array(xf * q)
		_fill(col, q.size())

	func flush(ci: CanvasItem) -> void:
		if pts.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), pts, cols)
		pts = PackedVector2Array()
		cols = PackedColorArray()
