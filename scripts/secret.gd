extends RefCounted
## The secret essences: Life and Unmaking. They are not ordinary essence
## (essence.gd KINDS stays the six tower kinds, so the crystals, the bench,
## the store and density never see them): only great foes leave them, never
## an ordinary monster.
##
## The first time a great foe falls and its secret essence rises, the
## climber chooses a PATH: Life or Unmaking (main.gd offer_path). It's for
## good. From then on only the path's essence soaks in; the other rises
## and passes straight through the climber, unbanked (a vessel that holds it
## comes later: main.gd vessel_takes).
##
## The path's essence never settles in a body part, never takes a mark and
## never pushes out a bond. It's one measure, the FLOW: carried unbanked
## during the climb (main.gd run_flow, lost on a fall like other unbanked
## essence) and banked at the stairs (profile.gd flow). Banked flow reaches
## STEPS, and each step changes how the climber plays (EFFECTS, player.gd
## set_flow). It lives in the climber's shadow, which is drawn here.
##
## Every word and number is in this file, so it's easy to rename or retune.
## Hooks for later: the Makers, fragments, the secret bonds and the Unbound
## build on profile.path / profile.flow; main.gd reset_path() clears the
## path (the Developer mark, or a Maker's mercy).

const ORDER := ["life", "unmaking"]

const KINDS := {
	"life": {"name": "Life", "color": Color(0.5, 0.81, 0.43), "deep": Color(0.07, 0.2, 0.08), "light": Color(0.78, 1.0, 0.62),
		"motto": "you endure"},
	"unmaking": {"name": "Unmaking", "color": Color(0.69, 0.44, 0.88), "deep": Color(0.11, 0.03, 0.17), "light": Color(0.9, 0.74, 1.0),
		"motto": "you take apart"},
}

## Who leaves them: great foes only. Amounts at floor 1, growing with the
## floor like other essence (GROWTH a floor, as essence.gd drop_for).
##   beast     a tower's beast (the summit)
##   shadow    the Proving's shadow of the beast (less)
##   mirror    a mirror image of the climber (mirror.gd, in a mirror room)
##   champion  a champion (a sealed wing's, the Proving's sentinel): a small
##             amount of one kind, by tower (CHAMPION_KIND)
const SOURCES := {
	"beast": {"life": 12.0, "unmaking": 6.0},
	"shadow": {"life": 6.0, "unmaking": 3.0},
	"mirror": {"unmaking": 12.0, "life": 4.0},
	"champion": 3.5,
}
const CHAMPION_KIND := {
	"gryphon": "unmaking", "kraken": "life", "wyvern": "unmaking",
	"manticore": "life", "firebird": "life", "chimera": "unmaking",
}
const GROWTH := 0.1

## Banked flow each step needs (index = step - 1).
const STEPS := [25.0, 75.0, 150.0, 300.0]

## What each step does (index = step - 1).
##   Life      regen   health regrown a second
##             mend    health back for every kill
##             heal    healing (draughts, springs, bond heals, kill heals) times this
##             refuse  once a floor, a killing blow leaves you at REFUSE_HEALTH
##   Unmaking  damage  your strikes and spells' damage, times this
##             health  your max health, times this
##             erode   damage a second to awake monsters within ERODE_REACH
##             pierce  your strikes ignore armour (a shellback's shell, a knight's guard)
##             undo    a slain foe comes apart: this share of its max health
##                     (at most UNDO_CAP) to monsters within UNDO_REACH
const EFFECTS := {
	"life": {
		"regen": [0.5, 0.75, 1.0, 1.25],
		"mend": [0.0, 4.0, 5.0, 6.0],
		"heal": [1.0, 1.0, 1.5, 1.6],
		"refuse": [false, false, false, true],
	},
	"unmaking": {
		"damage": [1.12, 1.2, 1.28, 1.36],
		"health": [0.92, 0.87, 0.82, 0.78],
		"erode": [0.0, 3.0, 4.0, 5.0],
		"pierce": [false, false, true, true],
		"undo": [0.0, 0.0, 0.0, 0.3],
	},
}
const REFUSE_HEALTH := 0.25
const REFUSE_PUSH := 120.0  # the burst throws back monsters this near
const ERODE_REACH := 64.0
const ERODE_TICK := 1.0
const UNDO_REACH := 96.0
const UNDO_CAP := 60.0

## What each step does, in words (the choice's cards, the climber screen).
const STEP_TEXT := {
	"life": [
		"Health slowly regrows",
		"Every kill mends you a little",
		"Healing is much stronger",
		"Once a floor, a killing blow leaves you standing",
	],
	"unmaking": [
		"More damage, less max health (more of both each step)",
		"An aura erodes awake monsters beside you",
		"Your strikes ignore armour",
		"Slain foes come apart and hurt those beside them",
	],
}

## Every other word.
const TEXT := {
	"choose_title": "CHOOSE YOUR PATH",
	"choose_lines": [
		"Two secret essences: Life and Unmaking. Only one can soak into you, and the choice is for good.",
		"The other will pass through you. Yours gathers in your shadow and grows as you bank it.",
	],
	"card_sub": "banked at stairs  ·  grows in four steps",
	"card_steps": "STEPS",
	"tap_choose": "Tap to choose",
	"tap_again": "Tap again to let it in",
	"press_choose": "Press %d or Enter",
	"press_again": "Press again to let it in",
	"pad_choose": "Press {a}",
	"pad_again": "Press {a} again to let it in",
	"chosen_title": "%s",
	"chosen": "It gathers in your shadow. The other will pass through you.",
	"chosen_line": "%s: %s",
	"gather": "+%d %s",
	"passes": "%s passes through you",
	"banked": "Banked %d %s",
	"step_up": "%s reaches step %d: %s",
	"refuse": "Life will not let you fall",
	"lost": "The %s you carried is lost",
	"faint_sign": "A faint %s in your shadow. It takes hold at %d banked.",
	"next": "%d banked  ·  %d more to step %d",
	"full": "%d banked  ·  every step reached",
	"unbanked": "%d unbanked: lost if you fall before the stair",
	"hud_tip": "%s  ·  step %d",
	"reset": "Your shadow is an ordinary shadow again",
}


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["life"])["color"]


static func display(kind: String) -> String:
	return KINDS.get(kind, KINDS["life"])["name"]


static func is_kind(kind: String) -> bool:
	return kind in KINDS


## The flow's step for an amount banked (0 before the first).
static func step_for(flow: float) -> int:
	var s := 0
	for i in STEPS.size():
		if flow >= float(STEPS[i]):
			s = i + 1
	return s


## Banked flow the next step needs (-1 once every step is reached).
static func next_need(flow: float) -> float:
	var s := step_for(flow)
	return float(STEPS[s]) if s < STEPS.size() else -1.0


## One effect's value at a step (nothing before the first: 0, false or 1).
static func effect(path: String, key: String, step: int):
	var list: Array = EFFECTS.get(path, {}).get(key, [])
	if step <= 0 or list.is_empty():
		if key in ["heal", "damage", "health"]:
			return 1.0
		if key in ["refuse", "pierce"]:
			return false
		return 0.0
	return list[mini(step, list.size()) - 1]


## Which kind of great foe a monster is ("" for an ordinary one).
static func great_foe(e) -> String:
	if e == null or e.ally:
		return ""
	if e.shade:
		return "shadow"
	if e.mirror:
		return "mirror"
	if e.is_boss():
		return "beast"
	if e.champion:
		return "champion"
	return ""


## What a great foe leaves on a floor: {kind: amount} ({} for an ordinary one).
static func drop(category: String, tower: String, floor_num: int) -> Dictionary:
	var grow := 1.0 + GROWTH * float(maxi(floor_num - 1, 0))
	if category == "champion":
		return {String(CHAMPION_KIND.get(tower, "life")): float(SOURCES["champion"]) * grow}
	var out := {}
	var src: Dictionary = SOURCES.get(category, {})
	for k in src:
		out[k] = float(src[k]) * grow
	return out


# --- the shadow --------------------------------------------------------------------

## How flat a shadow lies on the floor (the world's; the climber screen's is flatter).
const SQUASH := 0.45
## Fixed jitter for Unmaking's broken edge and crack shapes (no random numbers per frame).
const JIT := [0.6, -0.9, 0.3, 1.0, -0.4, 0.8, -1.0, 0.1, 0.7, -0.6, 0.9, -0.2, 0.4, -0.8, 1.0, -0.5, 0.2, -0.7]
const LEAF_LIFE := 2.2  # seconds a trailing leaf lasts (player.gd)


## A heartbeat: two quick beats, then a rest (0..1).
static func heartbeat(t: float) -> float:
	var ph := fmod(t, 1.15)
	return exp(-pow(ph / 0.07, 2.0)) + 0.65 * exp(-pow((ph - 0.24) / 0.08, 2.0))


## A convex shape filled as a fan of triangles into the batch (cheaper than
## triangulating it every frame).
static func fill(b, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var tri := PackedVector2Array()
	tri.resize((n - 2) * 3)
	for i in n - 2:
		tri[i * 3] = pts[0]
		tri[i * 3 + 1] = pts[i + 1]
		tri[i * 3 + 2] = pts[i + 2]
	b.pts.append_array(tri)
	b._color(col, tri.size())


## A shape that's star-shaped around `c` (every edge seen from it), as a fan from `c`.
static func fill_around(b, c: Vector2, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	var tri := PackedVector2Array()
	tri.resize(n * 3)
	for i in n:
		tri[i * 3] = c
		tri[i * 3 + 1] = pts[i]
		tri[i * 3 + 2] = pts[(i + 1) % n]
	b.pts.append_array(tri)
	b._color(col, tri.size())


static func _oval(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = c + Vector2(cos(a) * rx, sin(a) * ry)
	return pts


## The climber's shadow holding the path's essence, into Batch `b`: centred
## on the feet `c`, for a body of radius `r`, at flow step `step` (0: a faint
## sign only), `t` the time in seconds, `a` its opacity, `sq` how flat it
## lies. Everything goes into the one batch (one draw call).
static func draw_shadow(b, c: Vector2, r: float, path: String, step: int, t: float, a := 1.0, sq := SQUASH) -> void:
	if path == "life":
		_draw_life(b, c, r, step, t, a, sq)
	elif path == "unmaking":
		_draw_unmaking(b, c, r, step, t, a, sq)


static func _draw_life(b, c: Vector2, r: float, step: int, t: float, a: float, sq: float) -> void:
	var info: Dictionary = KINDS["life"]
	var col: Color = info["color"]
	var deep: Color = info["deep"]
	var light: Color = info["light"]
	var k := float(step)
	var faint := 0.35 if step == 0 else 1.0
	var beat := heartbeat(t) * (0.6 + 0.1 * k)
	var s := r * (1.1 + 0.17 * k) * (1.0 + 0.07 * beat)
	# The light it gives the floor, swelling with each beat.
	fill(b, _oval(c, s * 1.6, s * 1.6 * sq, 20), Color(col, (0.05 + 0.03 * k) * (0.6 + 0.6 * beat) * a * faint))
	fill(b, _oval(c, s * 1.25, s * 1.25 * sq, 20), Color(col, (0.08 + 0.03 * k) * (0.7 + 0.4 * beat) * a * faint))
	# Roots reach past its edge from step 2, longer each step; small leaves
	# sway at their tips from step 3.
	if step >= 2:
		var n := 3 + step
		for i in n:
			var ang := TAU * (float(i) + 0.3 * sin(float(i) * 2.3)) / float(n) + 0.35
			var reach := s * (1.15 + 0.16 * k + 0.12 * sin(float(i) * 1.7))
			var bend := 0.35 * sin(float(i) * 3.1 + 0.6)
			var p0 := c + Vector2(cos(ang), sin(ang) * sq) * s * 0.45
			var p1 := c + Vector2(cos(ang + bend * 0.5), sin(ang + bend * 0.5) * sq) * reach * 0.72
			var p2 := c + Vector2(cos(ang + bend), sin(ang + bend) * sq) * reach
			var rc := Color(deep.lightened(0.18), 0.85 * a)
			b.line(p0, p1, rc, 2.0)
			b.line(p1, p2, rc, 1.3)
			if step >= 3:
				var sway := 0.5 * sin(t * 2.2 + float(i) * 1.3)
				draw_leaf(b, p2, ang + bend + sway, 3.4 + 0.5 * k, Color(light.darkened(0.15), 0.9 * a))
	# The shadow itself: living green, darkest at its heart.
	fill(b, _oval(c, s, s * sq, 24), Color(deep, (0.6 + 0.07 * k) * a * faint))
	fill(b, _oval(c, s * 0.82, s * 0.82 * sq, 22), Color(col.darkened(0.55), (0.35 + 0.06 * k) * (0.8 + 0.4 * beat) * a * faint))
	fill(b, _oval(c, s * 0.5, s * 0.5 * sq, 18), Color(deep.darkened(0.5), (0.55 + 0.05 * k) * a * faint))
	# Each beat sends a bright ring out from its heart.
	var ph := fmod(t, 1.15) / 1.15
	if step >= 1:
		var rr := s * (0.4 + 0.75 * ph)
		var ring := _oval(c, rr, rr * sq, 22)
		ring.append(ring[0])
		b.polyline(ring, Color(light, (1.0 - ph) * (0.25 + 0.08 * k) * a), 1.2 + 0.25 * k)
	# Grass-light: small blades flicker where the shadow falls.
	var blades := 3 + 3 * step if step > 0 else 0
	for i in blades:
		var ang := TAU * float(i) * 0.618 + 0.2
		var d := s * (0.55 + 0.5 * absf(sin(float(i) * 1.9)))
		var base := c + Vector2(cos(ang) * d, sin(ang) * d * sq)
		var fl := sin(t * (2.6 + 0.7 * float(i % 3)) + float(i) * 1.7)
		if fl <= 0.0:
			continue
		var h := (3.0 + 1.5 * float(i % 3)) * (0.7 + 0.3 * fl)
		b.line(base, base + Vector2(0.8 * sin(t * 1.5 + float(i)), -h), Color(light, fl * fl * 0.9 * a), 1.3)


## A small leaf: a pointed oval along `ang`, `s` long.
static func draw_leaf(b, at: Vector2, ang: float, s: float, col: Color) -> void:
	var d := Vector2.from_angle(ang)
	var side := d.orthogonal() * s * 0.38
	fill(b, PackedVector2Array([at, at + d * s * 0.5 + side, at + d * s, at + d * s * 0.5 - side]), col)
	b.line(at, at + d * s * 0.85, Color(col.darkened(0.4), col.a * 0.8), 0.8)


static func _draw_unmaking(b, c: Vector2, r: float, step: int, t: float, a: float, sq: float) -> void:
	var info: Dictionary = KINDS["unmaking"]
	var col: Color = info["color"]
	var deep: Color = info["deep"]
	var light: Color = info["light"]
	var k := float(step)
	var faint := 0.35 if step == 0 else 1.0
	var s := r * (1.1 + 0.17 * k)
	# From step 3 it drinks the light around it: a wide darkness under all
	# (lighting.gd also dims the floor around it).
	if step >= 3:
		fill(b, _oval(c, s * 2.1, s * 2.1 * sq, 22), Color(0, 0, 0, (0.1 + 0.08 * (k - 3.0)) * a))
		fill(b, _oval(c, s * 1.6, s * 1.6 * sq, 22), Color(0.02, 0.0, 0.04, (0.16 + 0.08 * (k - 3.0)) * a))
	fill(b, _oval(c, s * 1.3, s * 1.3 * sq, 20), Color(col, (0.06 + 0.03 * k) * a * faint))
	# The broken body: its edge splintered (more each step), slowly shifting.
	var n := JIT.size()
	var pts := PackedVector2Array()
	pts.resize(n)
	var jag := 0.05 + 0.045 * k
	for i in n:
		var ang := TAU * float(i) / float(n)
		var rr := s * (1.0 + float(JIT[i]) * jag * (0.85 + 0.15 * sin(t * 0.9 + float(i))))
		pts[i] = c + Vector2(cos(ang) * rr, sin(ang) * rr * sq)
	fill_around(b, c, pts, Color(deep, (0.66 + 0.07 * k) * a * faint))
	fill(b, _oval(c, s * 0.55, s * 0.55 * sq, 18), Color(0, 0, 0, (0.35 + 0.08 * k) * a * faint))
	if step <= 0:
		return
	# Cracks like fractured glass, from the heart to the edge; rings of
	# cracks join them from step 2.
	var cracks := 4 + step
	var ends := PackedVector2Array()
	ends.resize(cracks * 2)
	for i in cracks:
		var ang := TAU * (float(i) + 0.35 * float(JIT[i])) / float(cracks) + 0.2
		var dir := Vector2(cos(ang), sin(ang) * sq)
		var kink := Vector2(cos(ang + 0.5 * float(JIT[i + 3])), sin(ang + 0.5 * float(JIT[i + 3])) * sq)
		var p0 := c + dir * s * 0.12
		var p1 := c + kink * s * 0.5
		var p2 := c + dir * s * (0.96 + 0.06 * float(JIT[i + 5]))
		var glint := 0.55 + 0.25 * k / 4.0 + 0.2 * sin(t * 1.6 + float(i) * 2.1)
		var cc := Color(light, glint * a)
		b.line(p0, p1, cc, 1.3)
		b.line(p1, p2, cc, 1.0)
		ends[i * 2] = p1
		ends[i * 2 + 1] = p2
	if step >= 2:
		for i in cracks:
			var j := (i + 1) % cracks
			if i % 2 == 0 or step >= 3:
				b.line(ends[i * 2], ends[j * 2], Color(col.lightened(0.2), 0.5 * a), 0.9)
	# Its edges flake away into motes that rise and fade.
	var motes := 3 + 3 * step
	for i in motes:
		var ph := fposmod(t * (0.45 + 0.05 * float(i % 4)) + float(i) * 0.618, 1.0)
		var ang := TAU * float(i) * 0.382 + 0.5
		var start := c + Vector2(cos(ang) * s, sin(ang) * s * sq)
		var pos := start + Vector2(4.0 * sin(float(i) * 2.0 + ph * 3.0), -ph * (12.0 + 3.0 * k))
		var ms := (1.9 - 1.2 * ph) * (1.0 + 0.1 * k)
		b.rect(Rect2(pos - Vector2(ms, ms) * 0.5, Vector2(ms, ms)), Color(light if i % 3 else col, (1.0 - ph) * 0.9 * a))


## A climber as a dark hooded silhouette standing at `feet`, `h` tall,
## rim-lit in `col` from below (its essence's light), breathing gently
## (the path choice's cards and the climber screen's flow).
static func draw_figure(b, feet: Vector2, h: float, col: Color, t: float) -> void:
	var u := h / 100.0
	var br := 1.0 + 0.012 * sin(t * 2.0)
	var body := PackedVector2Array()
	for v in [Vector2(-8, 0), Vector2(-26, -4), Vector2(-30, -30), Vector2(-24, -58), Vector2(-17, -70), Vector2(-15, -82),
			Vector2(-9, -94), Vector2(0, -100), Vector2(9, -94), Vector2(15, -82), Vector2(17, -70), Vector2(24, -58),
			Vector2(30, -30), Vector2(26, -4), Vector2(8, 0)]:
		body.append(feet + Vector2(v.x * u, v.y * u * br))
	b.poly(body, Color(0.035, 0.03, 0.055), 1.2)
	# The rim of light up its sides, brightest low down, from the essence underfoot.
	var n := body.size()
	for k in n - 1:
		var lo := clampf(1.0 - absf(body[k].y - feet.y) / (100.0 * u), 0.0, 1.0)
		b.line(body[k], body[k + 1], Color(col.lightened(0.15), 0.12 + 0.5 * lo * lo), 1.4)
	# The hood's opening, a shade lighter.
	var face := PackedVector2Array()
	for v in [Vector2(-7, -72), Vector2(-8, -84), Vector2(0, -91), Vector2(8, -84), Vector2(7, -72), Vector2(0, -68)]:
		face.append(feet + v * u)
	b.polygon(face, Color(col.darkened(0.75), 0.9))
