extends RefCounted
## The climber, drawn like the full game's: in the tower seen from above
## (a port of the full game's player.gd _draw and the functions after it:
## the body in layers from look.gd, the arms, the weapon in hand, the swing
## and its trail, the roll and the parry), and on menus seen from the front
## (look.gd draw_front, with the marks glowing at their spots). Static: the
## caller keeps anything that changes across frames in pose["mem"].
##
##   ClimberArt.draw(self, pos, {"app": save.look, "face": facing, "move": 1.0,
##       "weapon": "sword", "swing": -1.0, "t": t, "scale": 2.2, "mem": _mem})
##   ClimberArt.draw_front(self, feet, save.look, 4.0, marks, stars, t)
##
## Both end with the canvas item's draw transform reset (Vector2.ZERO, no
## rotation, scale 1).

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Look := preload("res://scripts/look.gd")

const RADIUS := 14.0  # the full game's climber radius (player.gd `radius`)
const WALK := 165.0  # the full game's walking speed: "move" 1 is this fast
const BOB := 1.4  # pixels the body rises with each step (anim.gd walk bob)
const ROLL_STRETCH := 0.3  # how much a roll stretches the body along it (anim.gd)
const SHIVER := 1.8  # pixels a hit makes the body shiver (anim.gd hurt)
const HURT_RED := Color(1.0, 0.35, 0.3)  # what a hit flushes the clothes toward
const TRAIL := Color(0.95, 0.97, 1.0)  # a swing's trail
const TRAIL_HEAVY := Color(1.0, 0.88, 0.55)
const PARRY := Color(1.0, 0.89, 0.63)  # the parry's crescent
## The front figure's frame is about 290 tall (look.gd); `scale` 1 draws it
## this much smaller, about 60 px tall (the size of LITE's old climber at 1).
const FRONT_K := 0.22
const FRONT_SOLE := 124.0  # where the front figure's soles are, in its frame

## The weapons LITE's climber holds, as the full game draws them: its id
## (which drawing), style ("arc" swung, "stab" thrust, "bow"), class (heavy
## is two-handed), length, and the first blow of its chain (arc in degrees,
## range in pixels, which way it sweeps) and its finisher's (pose "heavy").
## From the full game's weapons.gd.
static var WEAPONS := {
	"sword": {"id": "sword", "style": "arc", "class": "medium", "length": 24.0, "arc": 55.0, "range": 46.0, "heavy_arc": 75.0, "heavy_range": 56.0, "side": 1.0},
	"dagger": {"id": "dagger", "style": "stab", "class": "light", "length": 14.0, "arc": 35.0, "range": 36.0, "heavy_arc": 40.0, "heavy_range": 40.0, "side": 1.0},
	"hammer": {"id": "war_hammer", "style": "arc", "class": "heavy", "length": 32.0, "arc": 55.0, "range": 52.0, "heavy_arc": 70.0, "heavy_range": 56.0, "side": 1.0},
	"bow": {"id": "shortbow", "style": "bow", "class": "light", "limb": 14.0},
	"none": {"id": "fists", "style": "jab", "class": "light", "range": 30.0, "side": 1.0},
}
## Marks on the body in the tower: where each part's mark sits (from the
## middle, in units of RADIUS: x along the facing, y toward the weapon hand;
## "legs" is fixed below the middle). player.gd _mark_anchor.
const PARTS := ["brow", "throat", "heart", "back", "hand", "legs"]
## Where each mark sits on the front figure (its frame; menu.gd BodyView.SPOTS).
const SPOTS := {
	"brow": Vector2(0, -110), "throat": Vector2(0, -77), "heart": Vector2(-11, -47),
	"back": Vector2(24, -36), "hand": Vector2(-50, 9), "legs": Vector2(-11, 62),
}

static var _looks := {}  # hash(app) -> look.gd look(), so it isn't worked out every frame


## The look for a saved appearance (cached).
static func look_of(app) -> Dictionary:
	var key := hash(app)
	if not _looks.has(key):
		if _looks.size() > 32:
			_looks.clear()
		_looks[key] = Look.look(app)
	return _looks[key]


# --- the tower: seen from above ------------------------------------------------

## The climber in the tower (top-down, like player.gd), its middle at `pos`
## (the shadow, under the feet, a little below it). See the top of the file
## for `pose`; every key is optional.
static func draw(c: CanvasItem, pos: Vector2, pose: Dictionary) -> void:
	var t := float(pose.get("t", 0.0))
	var sc := float(pose.get("scale", 1.0))
	var face: Vector2 = pose.get("face", Vector2.DOWN)
	face = face.normalized() if face.length_squared() > 0.0001 else Vector2.DOWN
	var move := clampf(float(pose.get("move", 0.0)), 0.0, 1.0)
	var wid := String(pose.get("weapon", "sword"))
	var w: Dictionary = WEAPONS.get(wid, WEAPONS["none"])
	var swing := float(pose.get("swing", -1.0))
	var roll := float(pose.get("roll", -1.0))
	var parry := float(pose.get("parry", -1.0))
	var flash := clampf(float(pose.get("flash", 0.0)), 0.0, 1.0)
	var rolling := roll >= 0.0
	# A swing (or a shot) faces where it goes.
	var aim := face
	if swing >= 0.0 and not rolling:
		var sd0: Vector2 = pose.get("swing_dir", face)
		if sd0.length_squared() > 0.0001:
			aim = sd0.normalized()
	# The walk cycle and the cloak ease toward how you move (kept in mem).
	var spd := move * WALK if not rolling else 0.0
	var want_amp := clampf(spd / 120.0, 0.0, 1.0)
	var want_drift := Vector2(-move * 4.0, 0.0) if not rolling else Vector2.ZERO  # (walking the way you face)
	var amp := want_amp
	var phase := fmod(t * spd / 11.0, TAU)
	var drift := want_drift
	if pose.has("mem"):
		var mem: Dictionary = pose["mem"]
		var dt := clampf(t - float(mem.get("t", t)), 0.0, 0.1)
		mem["t"] = t
		amp = move_toward(float(mem.get("amp", want_amp)), want_amp, dt * 6.0)
		phase = fmod(float(mem.get("phase", 0.0)) + spd * dt / 11.0, TAU)
		drift = (mem.get("drift", want_drift) as Vector2).lerp(want_drift, 1.0 - exp(-dt * 8.0))
		mem["amp"] = amp
		mem["phase"] = phase
		mem["drift"] = drift
	# A hit flushes the clothes red (not the skin).
	var lk: Dictionary = look_of(pose.get("app", {}))
	var hurt := flash * 0.6
	if hurt > 0.0:
		lk = lk.duplicate()
		for k in lk:
			if lk[k] is Color and k != "skin":
				lk[k] = (lk[k] as Color).lerp(HURT_RED, hurt)
	var st := {
		"t": t, "aim": aim, "w": w, "swing": swing, "parry": parry, "flash": flash,
		"heavy": bool(pose.get("heavy", false)), "side": float(pose.get("swing_side", w.get("side", 1.0))),
		"phase": phase, "amp": amp, "drift": drift,
	}

	# The shadow under the feet.
	var r := RADIUS
	c.draw_set_transform(pos + Vector2(0, r * 0.75) * sc, 0.0, Vector2(sc, sc * 0.45))
	Draw.circles(c, [Vector2.ZERO, Vector2.ZERO], [r * 1.1, r * 0.85], [Color(0, 0, 0, 0.175), Color(0, 0, 0, 0.21)])
	# Each step lifts the body; a roll stretches it along the roll; a hit
	# flattens it and makes it shiver.
	var lift := absf(sin(phase)) * amp * BOB if not rolling else 0.0
	var shk := clampf((flash - 0.75) / 0.25, 0.0, 1.0)
	var shiver := Vector2(sin(t * 95.0), cos(t * 77.0)) * SHIVER * shk
	var squash := flash * 0.6
	var stretch := sin(PI * clampf(roll, 0.0, 1.0)) * ROLL_STRETCH if rolling else 0.0
	var off := (Vector2(0, -lift) + shiver) * sc
	c.draw_set_transform(pos + off, aim.angle(), Vector2(1.0 + squash * 0.25 + stretch, 1.0 - squash * 0.2 - stretch * 0.5) * sc)
	# The drawing frame faces the aim: forward is +x, the weapon hand -y.
	st["f"] = Vector2.RIGHT
	st["sd"] = Vector2.RIGHT.orthogonal()
	st["light"] = Draw.LIGHT_DIR.rotated(-aim.angle())
	var b := Draw.Batch.new()
	if rolling:
		_draw_rolling(b, lk, st, roll)
	else:
		_draw_standing(b, lk, st)
	b.flush(c)
	# Marks, the swing's trail and the parry, unrotated, over the body.
	c.draw_set_transform(pos + off, 0.0, Vector2(sc, sc))
	_draw_marks(c, aim, pose.get("marks", {}), pose.get("stars", {}), t)
	if not rolling:
		_draw_effects(c, st)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A blow's arc or range: the finisher's when `heavy`.
static func _blow(w: Dictionary, key: String, heavy: bool) -> float:
	return float(w.get("heavy_" + key, w.get(key, 0.0)) if heavy else w.get(key, 0.0))


static func _at(st: Dictionary, x: float, y: float) -> Vector2:
	return (st["f"] as Vector2) * x + (st["sd"] as Vector2) * y


## Standing (player.gd _draw_standing): legs stepping out from under the
## cloak, the cloak swaying, the chest and belt, the shoulders, the head,
## then the arms, the weapon and the hands over it.
static func _draw_standing(b, lk: Dictionary, st: Dictionary) -> void:
	var f: Vector2 = st["f"]
	var sd: Vector2 = st["sd"]
	var light: Vector2 = st["light"]
	var amp: float = st["amp"]
	var phase: float = st["phase"]
	var s := sin(phase) * amp  # -1..1 through a stride
	var lx := f * (-2.5 * float(st["flash"]))  # rocked back by a hit
	var d: Vector2 = st["drift"]
	var sway := sin(float(st["t"]) * 1.7) * 0.8 + cos(phase) * 1.4 * amp
	Look.draw_legs(b, lx, f, sd, light, lk, s)
	Look.draw_cloak(b, lx, f, sd, light, lk, sway, d)
	Look.draw_torso(b, lx, f, sd, light, lk)
	var sh_y: float = lk.get("sh_y", 9.3)  # (wider apart on a broad build)
	var sh_r: float = float(lk.get("shoulder_r", 4.6)) + float(lk.get("sh_add", 0.0))
	for sgn in [-1.0, 1.0]:  # the shoulders, in the cloak
		b.ball(lx + _at(st, 0.3, sgn * sh_y), sh_r, lk["shoulder"], true, light)
	Look.draw_head(b, lx + _at(st, -0.5, 0.0), f, sd, light, lk, sway, d)
	var sh_w := lx + _at(st, 0.3 + s * 0.8, sh_y)
	var sh_o := lx + _at(st, 0.3 - s * 0.8, -sh_y)
	_draw_weapon(b, sh_w, sh_o, lk, s, st)


## Arms from the shoulders to the hands, the weapon in hand, then the hands
## on its grip (player.gd _draw_weapon). `s` is the stride: a free hand
## swings with it. A parry holds the weapon across the front, on guard.
static func _draw_weapon(b, sh_w: Vector2, sh_o: Vector2, lk: Dictionary, s: float, st: Dictionary) -> void:
	var dir: Vector2 = st["f"]
	var side: Vector2 = st["sd"]
	var light: Vector2 = st["light"]
	var w: Dictionary = st["w"]
	var swing: float = st["swing"]
	var guard: bool = float(st["parry"]) >= 0.0 and swing < 0.0
	var heavy: bool = st["heavy"]
	var radius := RADIUS
	var free := sh_o + _at(st, 5.0 - s * 3.0, -1.2)  # the off hand, at rest
	var hands: Array = []  # [shoulder, hand, size]
	var draw_weapon := Callable()
	match String(w["style"]):
		"arc":
			# Swung weapons: rest angled forward, follow the swing across its arc.
			var two_hands: bool = w["class"] == "heavy"
			var grip := side * (radius * (0.5 if two_hands else 0.95)) + dir * (7.0 if two_hands else 4.0)
			var along := dir.rotated(0.8 if two_hands else 0.5)
			if swing >= 0.0:
				var k := clampf(swing, 0.0, 1.0)
				var half := deg_to_rad(_blow(w, "arc", heavy))
				var sweep: float = st["side"]
				along = dir.rotated(lerpf(-half * sweep, half * sweep, minf(1.0, k * 1.6)))
				grip = along * 10.0
			elif guard:
				grip = dir * 9.0 + side * (4.0 if two_hands else 7.0)
				along = dir.rotated(1.35)
			var length: float = float(w["length"]) + (2.0 if heavy else 0.0)
			var glint := 1.0 if swing >= 0.0 else 0.0
			var id: String = w["id"]
			draw_weapon = func(): _draw_swung(b, id, grip, along, length, glint, light)
			hands.append([sh_w, grip - along * 3.0, 3.0])
			hands.append([sh_o, grip + along * 1.5 if two_hands else free, 2.8])
		"stab":
			# A dagger: held point-first, driven straight out on a thrust.
			var length2: float = w["length"]
			var rest := side * (radius * 0.85) + dir * 2.0
			var ext := 0.0
			if swing >= 0.0:
				ext = sin(PI * minf(1.0, clampf(swing, 0.0, 1.0) * 1.3))
			var reach: float = _blow(w, "range", heavy) - length2 - radius * 0.3
			var grip2 := rest.lerp(dir * maxf(reach, 6.0) + side * 2.0, ext)
			var dir2 := dir
			if guard:
				grip2 = dir * 8.0 + side * 5.0
				dir2 = dir.rotated(1.1)
			var glint2 := 1.0 if swing >= 0.0 else 0.0
			draw_weapon = func(): b.sword(grip2, dir2, length2, glint2)
			hands.append([sh_w, grip2 - dir2 * 2.0, 3.0])
			hands.append([sh_o, free, 2.8])
		"jab":
			for sgn in [-1.0, 1.0]:
				var rest2: Vector2 = dir * (radius * 0.7) + side * sgn * radius * 0.75
				var pos: Vector2 = rest2
				var r := 3.8
				if guard:
					pos = dir * (radius * 0.9) + side * sgn * 4.0
				elif swing >= 0.0 and sgn == float(st["side"]):
					var ext2: float = sin(PI * minf(1.0, clampf(swing, 0.0, 1.0) * 1.2))
					pos = rest2.lerp(dir * float(w["range"]), ext2)
					r = 5.2 if heavy else 4.4
				else:
					pos += dir * (s * sgn * 1.5)
				hands.append([sh_w if sgn > 0.0 else sh_o, pos, r])
		"bow":
			# A shot: the string drawn back over most of it, then loosed.
			var drawing := swing >= 0.0 and swing < 0.6
			var kd := clampf(swing / 0.6, 0.0, 1.0) if drawing else 0.0
			var limb: float = w["limb"]
			var bgrip := dir * (radius + 5.0)
			var tip_a := bgrip - dir * (5.0 + 2.0 * kd) + side * limb * (1.0 - 0.06 * kd)
			var tip_b := bgrip - dir * (5.0 + 2.0 * kd) - side * limb * (1.0 - 0.06 * kd)
			var nock := bgrip - dir * (5.0 + 12.0 * kd)
			var wood: Color = Palette.WOOD.darkened(0.15) if limb > 16.0 else Palette.WOOD
			draw_weapon = func():
				var bow := PackedVector2Array([tip_a, bgrip + side * limb * 0.5 - dir * kd, bgrip, bgrip - side * limb * 0.5 - dir * kd, tip_b])
				b.path(bow, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA), 7.0)
				b.path(bow, Palette.OUTLINE, 5.5)
				b.path(bow, wood, 3.0)
				b.dot(bgrip, 2.0, Palette.WOOD.darkened(0.35))  # the grip's wrap
				# The string pulls back as you draw.
				b.path(PackedVector2Array([tip_a, nock, tip_b]), Color(0.92, 0.9, 0.82), 1.0)
				if drawing:
					b.stroke(nock, nock + dir * (18.0 + 14.0 * kd), Palette.WOOD.lightened(0.2), 1.6)
					var head := nock + dir * (19.0 + 14.0 * kd)
					b.poly(PackedVector2Array([head + dir * 4.0, head - dir * 1.5 + side * 2.2, head - dir * 1.5 - side * 2.2]), Palette.STEEL, 0.8)
					b.line(nock - side * 1.8, nock + dir * 4.0, Color(0.85, 0.3, 0.25), 1.2)  # fletching
					b.line(nock + side * 1.8, nock + dir * 4.0, Color(0.85, 0.3, 0.25), 1.2)
			hands.append([sh_w, bgrip + side * 0.5, 3.0])
			hands.append([sh_o, nock if drawing else free, 2.8])
	for h in hands:
		b.stroke(h[0], h[1], lk["sleeve"], 3.4)
	if draw_weapon.is_valid():
		draw_weapon.call()
	for h in hands:
		b.ball(h[1], h[2], lk["hand"], true, light)


## A swung weapon lying along `along` from the grip: the war hammer, or a
## sword (player.gd _draw_swung).
static func _draw_swung(b, id: String, grip: Vector2, along: Vector2, length: float, glint: float, _light: Vector2) -> void:
	var side := along.orthogonal()
	match id:
		"war_hammer":
			var head2 := grip + along * length
			b.stroke(grip - along * 6.0, head2, Palette.WOOD.darkened(0.1), 3.0)
			var pts := PackedVector2Array([head2 - along * 5.0 + side * 9.0, head2 + along * 5.0 + side * 9.0, head2 + along * 5.0 - side * 6.0, head2 - along * 5.0 - side * 6.0])
			b.poly(pts, Palette.STEEL.darkened(0.15), 1.4)
			b.line(pts[0] - side * 0.8, pts[1] - side * 0.8, Color(1, 1, 1, 0.45 + 0.4 * glint), 1.2)
		_:
			b.sword(grip, along, length, glint)


## Curled up in the cloak, tumbling along the roll, head over heels
## (player.gd _draw_rolling). `k` is 0..1 through the roll.
static func _draw_rolling(b, lk: Dictionary, st: Dictionary, k: float) -> void:
	var light: Vector2 = st["light"]
	var spin := clampf(k, 0.0, 1.0) * TAU
	var fwd := Vector2.RIGHT  # the drawing frame faces the roll
	var across := Vector2.UP
	Look.draw_rolled_cloak(b, lk, fwd, across, spin, light)
	for sgn in [-1.0, 1.0]:  # hands tucked in
		b.ball(fwd * 3.0 + across * sgn * 8.0, 2.6, lk["hand"], true, light)
	var cs := cos(spin)
	b.ball(fwd * (5.0 * cs), 5.0 + 1.2 * cs, Look.crown(lk), true, light)


## Where each body part's mark sits on the climber (unrotated; player.gd _mark_anchor).
static func mark_anchor(part: String, aim: Vector2) -> Vector2:
	var side := aim.orthogonal()
	var radius := RADIUS
	match part:
		"throat":
			return aim * (radius * 0.25) + side * 2.0
		"back":
			return -aim * (radius * 0.7) + side * 2.0
		"hand":
			return side * radius * 0.95 + aim * 3.0
		"brow":
			return aim * (radius * 0.55)
		"heart":
			return -side * radius * 0.3 - aim * 3.0
	return Vector2(0, radius * 0.55)  # legs


## The marks on the body (player.gd _draw_marks and its unlit glow): a dot
## in the mark's colour with a ray for each star, and a soft glow round it,
## bigger and brighter with more stars.
static func _draw_marks(c: CanvasItem, aim: Vector2, marks: Dictionary, stars: Dictionary, t: float) -> void:
	if marks.is_empty():
		return
	var b := Draw.Batch.new()
	for part in marks:
		var col: Color = marks[part]
		var n := clampi(int(stars.get(part, 1)), 1, 3)
		var anchor := mark_anchor(String(part), aim)
		b.dot(anchor, 3.4, Palette.OUTLINE)
		b.dot(anchor, 2.5, col)
		b.dot(anchor + Vector2(-0.6, -0.6), 1.0, Color(1, 1, 1, 0.6 * col.a))
		for i in n:
			var spread: float = float(i) - (float(n) - 1.0) / 2.0
			var ang: float = anchor.angle() + PI + spread * 0.5
			b.line(anchor + Vector2.from_angle(ang) * 3.0, anchor + Vector2.from_angle(ang) * 6.5, col, 1.4)
		var pulse := 0.8 + 0.2 * sin(t * 2.5 + anchor.x)
		var grow := 1.0 + 0.45 * (n - 1)
		b.dot(anchor, 6.5 * grow, Color(col, 0.12 * col.a * pulse * grow))
		b.dot(anchor, 4.0 * grow, Color(col, 0.25 * col.a * pulse * minf(grow, 1.6)))
	b.flush(c)


## The swing's trail and the parry's crescent (player.gd _draw_overlay and
## _draw_swing_trail), and a bow's aim line while it's drawn.
static func _draw_effects(c: CanvasItem, st: Dictionary) -> void:
	var aim: Vector2 = st["aim"]
	var w: Dictionary = st["w"]
	var swing: float = st["swing"]
	var heavy: bool = st["heavy"]
	var radius := RADIUS
	if swing >= 0.0:
		var k := clampf(swing, 0.0, 1.0)
		var col := TRAIL_HEAVY if heavy else TRAIL
		match String(w["style"]):
			"arc":
				var reach := _blow(w, "range", heavy)
				var a := aim.angle()
				var half := deg_to_rad(_blow(w, "arc", heavy))
				var sweep: float = st["side"]
				var from := a - half * sweep
				var to := lerpf(from, a + half * sweep, minf(1.0, k * 1.6))
				var thick: float = (3.5 if heavy else 2.5) * (1.4 if w["class"] == "heavy" else 1.0)
				if absf(to - from) > 0.01:
					# A crescent trail: several arcs fading toward the inside.
					for i in 5:
						var rr := reach - i * 3.0
						c.draw_arc(Vector2.ZERO, rr, minf(from, to), maxf(from, to), 20, Color(col, (0.75 - i * 0.14) * (1.0 - k * 0.5)), thick)
					if heavy:
						for j in 2:
							c.draw_arc(Vector2.ZERO, reach + 3.0 + j * 4.0, minf(from, to), maxf(from, to), 20, Color(col.lightened(0.3), (0.5 - j * 0.15) * (1.0 - k * 0.7)), thick * 1.5)
				# A bright leading edge where the blade is now.
				c.draw_line(Vector2.from_angle(to) * (reach - 12.0), Vector2.from_angle(to) * (reach + 3.0), Color(1, 1, 1, 0.7 * (1.0 - k)), thick)
			"stab":
				var reach2 := _blow(w, "range", heavy)
				var ext := sin(PI * minf(1.0, k * 1.3))
				var tip := aim * reach2 * (0.6 + 0.4 * ext)
				c.draw_line(aim * radius, tip, Color(col, 0.5 * (1.0 - k * 0.6)), 3.0 if heavy else 2.0)
				c.draw_circle(tip, 3.0 if heavy else 2.0, Color(col, 0.7 * (1.0 - k)))
			"jab":
				if k > 0.3:
					c.draw_arc(aim * float(w["range"]), 7.0 + 6.0 * k, 0.0, TAU, 14, Color(1, 0.95, 0.85, 0.6 * (1.0 - k)), 2.0)
			"bow":
				var grip := aim * (radius + 5.0)
				if k < 0.6:  # drawing: the line the arrow will fly
					var kd := k / 0.6
					var col2 := Color(1.0, 0.9, 0.6, 0.8) if kd >= 0.95 else Color(1, 1, 1, 0.15 + 0.3 * kd)
					c.draw_line(grip + aim * 18.0, grip + aim * (60.0 + 160.0 * kd), col2, 1.0 + kd)
				else:  # loosed: the arrow streaks away
					var u := (k - 0.6) / 0.4
					var head := grip + aim * (24.0 + 150.0 * u)
					c.draw_line(head - aim * 22.0, head, Color(1.0, 0.95, 0.8, 0.8 * (1.0 - u)), 2.0)
					c.draw_line(head - aim * 6.0, head, Color(Palette.STEEL, 1.0 - u), 3.0)
	var parry: float = st["parry"]
	if parry >= 0.0:
		var fade := 1.0 - smoothstep(0.7, 1.0, parry)
		var pa := aim.angle()
		c.draw_arc(Vector2.ZERO, radius + 10.0, pa - 1.0, pa + 1.0, 14, Color(PARRY, fade), 4.0)
		c.draw_arc(Vector2.ZERO, radius + 14.0, pa - 0.8, pa + 0.8, 14, Color(PARRY, 0.4 * fade), 2.0)


# --- menus: seen from the front --------------------------------------------------

## The front-facing figure for menus (home screen, climber screen, the
## Regard), its feet at `pos`. `scale` 1 is about 60 px tall (FRONT_K).
## `marks` is body part -> colour, glowing at the part's spot; `stars` is
## body part -> 1..3 (a bigger, brighter glow and sign); `t` makes them pulse.
static func draw_front(c: CanvasItem, pos: Vector2, app: Dictionary, scale: float, marks := {}, stars := {}, t := 0.0) -> void:
	var lk := look_of(app)
	var k := scale * FRONT_K
	c.draw_set_transform(pos - Vector2(0, FRONT_SOLE) * k, 0.0, Vector2(k, k))
	var b := Draw.Batch.new()
	# The shadow at the feet (menu.gd BodyView._backdrop).
	b.polygon(Look._oval(Vector2(0, 126), Vector2(74, 12), 24), Color(0, 0, 0, 0.3))
	b.polygon(Look._oval(Vector2(0, 126), Vector2(48, 7), 24), Color(0, 0, 0, 0.3))
	Look.draw_front(b, lk)
	for part in SPOTS:
		if marks.has(part):
			_front_mark(b, SPOTS[part], marks[part], clampi(int(stars.get(part, 1)), 1, 3), t)
	b.flush(c)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where a body part's mark shows on the front figure drawn by draw_front
## with these `pos` and `scale` (screen units), for things flying to it.
static func front_spot(pos: Vector2, scale: float, part: String) -> Vector2:
	var k := scale * FRONT_K
	return pos - Vector2(0, FRONT_SOLE) * k + SPOTS.get(part, Vector2(0, -47)) * k


## How tall the front figure is at `scale` (to place things over its head).
static func front_height(scale: float) -> float:
	return (FRONT_SOLE + 130.0) * scale * FRONT_K


## A mark on the front figure (menu.gd BodyView._mark): a soft glow in its
## colour, a dark medallion, and a four-pointed sign; more stars, more glow.
static func _front_mark(b, at: Vector2, col: Color, n: int, t: float) -> void:
	var pulse := 0.75 + 0.25 * sin(t * 2.2 + at.y * 0.05)
	var r := 24.0 + 6.0 * n
	var strength := (1.0 + 0.4 * n) * pulse
	for i in 5:
		var kk := 1.0 - i / 5.0
		b.dot(at, r * (0.45 + 0.55 * kk), Color(col, 0.07 * strength))
	b.dot(at, 9.4, Color(Look.OUTLINE, 0.9))
	b.dot(at, 8.0, col.darkened(0.7))
	var sr := 5.0 + 0.7 * n
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		pts.append(at + Vector2.from_angle(a) * (sr if i % 2 == 0 else sr * 0.4))
	b.polygon(pts, col.lightened(0.12 * pulse + 0.1 * (n - 1)))
	if n >= 3:  # three stars: a thin bright ring
		b.arc(at, 12.0, 0.0, TAU, 24, Color(col.lightened(0.4), 0.7 * pulse), 1.4)
