extends RefCounted
## The stair's ONE seal. Three systems can lock a stair: the climb's barrier
## (a gate or ward forming as you arrive: climb_shape.gd), the floor's task
## (a puzzle or a task wards it: objective.gd, puzzle.gd) and the floor
## itself (the stair opens once most of it is down: main.gd). Each keeps its
## own logic; this draws them as one seal showing only the strongest lock:
##   barrier  the gate or the ward stands (nothing else is drawn under it)
##   task     a ring of runes around the chain (the floor's task wards it)
##   chain    the chain and padlock across the steps
##   open     the gold ring and the chevron up the steps
## When a lock lifts, it fades as the next one comes in (the chain drops as
## it goes), never two pictures stacked. room.gd keeps the mix (`step`) and
## draws the chain, the ring and the open glow; climb_shape.gd draws the
## barrier (over the darkness) at the mix's "barrier" weight.

const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")

const LAYERS := ["barrier", "task", "chain", "open"]
const FADE := 0.45  # seconds a lock takes to give way to the next
## The task's runes: violet, as the puzzles' wards always were.
static var TASK_COLOR := Color(0.75, 0.55, 1.0)
static var IRON := Color(0.5, 0.48, 0.52)
static var OPEN_GOLD := Color(1.0, 0.85, 0.5)


## The strongest lock on `main`'s stair now (see the top of this file).
static func layer(main) -> String:
	if main == null:
		return ""
	if main.stair_open:
		return "open"
	var cs = main.get("climb_shape")
	if cs != null and not cs.bar.is_empty():
		var st := String(cs.bar.get("state", ""))
		if st in ["forming", "up", "slipped"]:
			return "barrier"
		if st == "broken" and (cs.horde_total > 0 or cs.refusing):
			return "chain"  # (broken: the horde holds the stair now, not the task it skips)
	if main.ward and not main.practice_or_arena():
		return "task"
	return "chain"


## What each picture's weight should be for a lock: the task's ring is drawn
## around the chain, so both show for it.
static func targets(lock: String) -> Dictionary:
	var out := {}
	for l in LAYERS:
		out[l] = 1.0 if l == lock or (lock == "task" and l == "chain") else 0.0
	return out


## A fresh mix showing `lock` at once (a new floor: no transition).
static func snap(mix: Dictionary, lock: String) -> void:
	var tg := targets(lock)
	for l in LAYERS:
		mix[l] = tg[l]


## Moves `mix` toward `lock` over FADE seconds.
static func step(mix: Dictionary, lock: String, delta: float) -> void:
	var tg := targets(lock)
	for l in LAYERS:
		mix[l] = move_toward(float(mix.get(l, 0.0)), float(tg[l]), delta / FADE)


## The pictures drawn now (weight over a hair): for the tests, which check
## that a stair shows one lock at a time.
static func shown(mix: Dictionary) -> Array:
	return LAYERS.filter(func(l): return float(mix.get(l, 0.0)) > 0.02)


# --- the pictures ----------------------------------------------------------------------

## The chain across the steps between two rings, its links alternately
## face-on and edge-on, a padlock in the middle. `a` fades it; `drop` (0..1)
## lets it fall as the stair opens; `rune` lights the padlock in the task's
## colour while the task's ring is round it.
static func chain_into(c, sp: Vector2, a: float, drop := 0.0, rune := 0.0) -> void:
	if a <= 0.01:
		return
	var left := Vector2(sp.x - 36.0, sp.y + 16.0 - 22.0)
	var right := Vector2(sp.x + 36.0, sp.y + 16.0 - 22.0)
	var out := Color(Palette.OUTLINE, a)
	for end in [left, right]:
		c.disc(end, 3.6, out)
		c.disc(end, 2.6, Color(IRON.darkened(0.25), a), Draw.Shade.METAL)
	var links := 9
	var sag := 6.0 + drop * 16.0
	var fall := drop * 10.0  # (let go: it slumps down the steps as it fades)
	for i in links:
		var k := (float(i) + 0.5) / float(links)
		var p := left.lerp(right, k) + Vector2(0, sin(k * PI) * sag + fall * sin(k * PI))
		var slope := cos(k * PI) * sag * PI / 72.0  # (the sag's slope here)
		var rot := atan(slope)
		if i % 2 == 0:
			c.oval(p, Vector2(4.6, 3.0), rot, out)
			c.oval(p, Vector2(3.6, 2.1), rot, Color(IRON, a), Draw.Shade.METAL)
			c.oval(p, Vector2(1.9, 0.8), rot, Color(0.08, 0.07, 0.09, a))
		else:
			var d := Vector2.from_angle(rot) * 3.6
			c.line(p - d, p + d, out, 3.0)
			c.bar(p - d, p + d, Color(IRON.darkened(0.1), a), 1.6)
	var lock_at := Vector2(sp.x, left.y + sag + fall + 5.0)
	if rune > 0.01:
		c.circle(lock_at, 11.0, Color(TASK_COLOR, 0.22 * rune * a), 20)
	UI.lock_into(c, lock_at, 7.0, Color(Color(0.62, 0.5, 0.3).lerp(TASK_COLOR.darkened(0.2), 0.55 * rune), a))
	if rune > 0.01:
		# The task's rune on the lock's face.
		var rc := Color(TASK_COLOR.lightened(0.35), 0.9 * rune * a)
		c.line(lock_at + Vector2(0, -1.5), lock_at + Vector2(0, 4.5), rc, 1.2)
		c.line(lock_at + Vector2(-2.5, 0.5), lock_at + Vector2(2.5, 2.5), rc, 1.0)


## The floor's task wards the stair: a ring of runes around the whole flight
## (and so around the chain: no part of one crosses the other), turning slowly.
static func ring_into(c, sp: Vector2, a: float, t: float) -> void:
	if a <= 0.01:
		return
	var cen := sp + Vector2(0, -4.0)
	var rad := Vector2(54.0, 34.0)
	var col := Color(TASK_COLOR, 0.75 * a)
	var pts := PackedVector2Array()
	for i in 41:
		var ang := TAU * float(i) / 40.0
		pts.append(cen + Vector2(cos(ang) * rad.x, sin(ang) * rad.y))
	c.polyline(pts, Color(TASK_COLOR, 0.18 * a), 6.0)  # (its glow)
	c.polyline(pts, col, 1.8)
	var inner := PackedVector2Array()
	var turn := t * 0.6
	for i in 33:
		var ang := turn + TAU * 0.8 * float(i) / 32.0
		inner.append(cen + Vector2(cos(ang) * (rad.x - 7.0), sin(ang) * (rad.y - 5.0)))
	c.polyline(inner, Color(TASK_COLOR, 0.42 * a), 1.2)
	# Six runes riding the ring: small upright glyphs, each with its stud.
	for i in 6:
		var ang := TAU * float(i) / 6.0 - t * 0.4
		var p := cen + Vector2(cos(ang) * rad.x, sin(ang) * rad.y)
		c.circle(p, 5.5, Color(0.06, 0.04, 0.1, 0.7 * a), 12)
		c.line(p + Vector2(0, -3.5), p + Vector2(0, 3.5), Color(TASK_COLOR.lightened(0.3), 0.95 * a), 1.4)
		c.line(p + Vector2(-2.5, -1.0 + (i % 2) * 2.0), p + Vector2(2.5, 1.0 - (i % 2) * 2.0), Color(TASK_COLOR.lightened(0.3), 0.95 * a), 1.2)


## The stair is open: a gold ring and a chevron pointing up the steps.
static func open_into(c, sp: Vector2, a: float, t: float) -> void:
	if a <= 0.01:
		return
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	c.draw_arc(sp, 30.0 + pulse * 6.0, 0.0, TAU, 40, Color(OPEN_GOLD, (0.35 + 0.3 * pulse) * a), 2.5)
	var tip := sp + Vector2(0, -26 - pulse * 4.0)
	c.draw_polyline(PackedVector2Array([tip + Vector2(-9, 7), tip, tip + Vector2(9, 7)]), Color(1.0, 0.9, 0.6, 0.9 * a), 2.5)


# --- the barrier (climb_shape.gd draws it, at the mix's "barrier" weight) ------------

## The iron gate: two posts and a lintel; its bars come down as it forms
## (`k` 0..1), slammed shut behind a slip, bent and scattered once broken.
static func gate_into(b, r: Rect2, k: float, st: String, t: float) -> void:
	var post := Color(0.32, 0.3, 0.35)
	var iron := Color(0.5, 0.48, 0.54)
	var dark := Color(0.06, 0.05, 0.07)
	if st == "broken":
		# Bent bars on the ground before the stair (the frame went with them).
		for i in 6:
			var x0 := r.position.x + 12.0 + i * 11.0
			var y0 := r.end.y + 4.0 + float(i % 3) * 4.0
			b.line(Vector2(x0, y0), Vector2(x0 + 14.0, y0 - 3.0 + float(i % 2) * 6.0), dark, 4.0)
			b.bar(Vector2(x0, y0), Vector2(x0 + 14.0, y0 - 3.0 + float(i % 2) * 6.0), iron, 2.2)
		return
	# Posts and lintel.
	# (shaded iron, lit from the top-left: the shading toolkit's METAL and TUBE)
	b.contact(Vector2(r.get_center().x, r.end.y + 2.0), r.size.x * 0.5, 0.3, 0.18)
	for x in [r.position.x, r.end.x - 8.0]:
		b.rect(Rect2(Vector2(x, r.position.y - 6.0), Vector2(8.0, r.size.y + 6.0)), dark)
		b.box(Rect2(Vector2(x + 1.0, r.position.y - 5.0), Vector2(6.0, r.size.y + 4.0)), post, Draw.Shade.METAL)
	b.rect(Rect2(Vector2(r.position.x - 4.0, r.position.y - 12.0), Vector2(r.size.x + 8.0, 9.0)), dark)
	b.box(Rect2(Vector2(r.position.x - 3.0, r.position.y - 11.0), Vector2(r.size.x + 6.0, 7.0)), post.lightened(0.1), Draw.Shade.METAL)
	for x in [r.position.x + 4.0, r.end.x - 4.0]:
		b.disc(Vector2(x, r.position.y - 7.5), 1.6, iron.lightened(0.2))  # (rivets)
	var bottom := r.position.y - 4.0 + (r.size.y + 2.0) * k
	if st == "open":
		bottom = r.position.y + 2.0
	var bars := 7
	for i in bars:
		var x := r.position.x + 12.0 + float(i) * (r.size.x - 24.0) / float(bars - 1)
		b.line(Vector2(x, r.position.y - 4.0), Vector2(x, bottom), dark, 6.0)
		b.bar(Vector2(x, r.position.y - 4.0), Vector2(x, bottom), iron, 3.6)
		# Spiked feet.
		if bottom > r.position.y + 4.0:
			b.line(Vector2(x - 3.0, bottom - 3.0), Vector2(x, bottom + 4.0), dark, 3.0)
			b.line(Vector2(x + 3.0, bottom - 3.0), Vector2(x, bottom + 4.0), dark, 3.0)
			b.line(Vector2(x - 2.5, bottom - 3.0), Vector2(x, bottom + 3.5), iron.lightened(0.25), 1.6)
			b.line(Vector2(x + 2.5, bottom - 3.0), Vector2(x, bottom + 3.5), iron.lightened(0.25), 1.6)
	for yy in [0.3, 0.7]:
		var y: float = r.position.y - 4.0 + (bottom - r.position.y + 4.0) * float(yy)
		if bottom - r.position.y > 10.0:
			b.line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), dark, 6.0)
			b.bar(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), iron.darkened(0.1), 3.2)
	if st == "forming":
		# The gap under it: where a roll goes. A glint along its lowest edge.
		var glint := 0.5 + 0.5 * sin(t * 6.0)
		b.line(Vector2(r.position.x + 8.0, bottom + 3.0), Vector2(r.end.x - 8.0, bottom + 3.0), Color(1.0, 0.85, 0.5, 0.35 + 0.4 * glint), 1.5)
	if st == "slipped":
		b.line(Vector2(r.position.x + 8.0, r.end.y), Vector2(r.end.x - 8.0, r.end.y), Color(1.0, 0.4, 0.3, 0.6 + 0.3 * sin(t * 5.0)), 2.0)


## The ward: a pane of the tower's essence rising from the floor (`k`),
## lattice-lit, pulsing once up; shards on the floor once broken. `col` is
## its presentation colour (ward_color: saturated enough to read in its own light).
static func ward_into(b, r: Rect2, k: float, st: String, t: float, col: Color) -> void:
	if st == "broken":
		for i in 9:
			var at := Vector2(r.position.x + 8.0 + fmod(i * 23.7, r.size.x - 16.0), r.end.y + 4.0 + fmod(i * 7.3, 12.0))
			b.line(at, at + Vector2(5.0, -3.0).rotated(i * 0.9), Color(col, 0.6), 2.0)
		return
	if st == "open":
		return
	var h := r.size.y * k
	var top := r.end.y - h
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if st == "forming" else 1.6))
	var edge := col.lightened(0.2)  # (lit, never white: the pane keeps its colour in its own light)
	b.rect(Rect2(Vector2(r.position.x - 4.0, top), Vector2(r.size.x + 8.0, h)), Color(col.darkened(0.15), 0.3 + 0.12 * pulse))
	b.rect(Rect2(Vector2(r.position.x - 4.0, top), Vector2(3.0, h)), Color(edge, 0.9))
	b.rect(Rect2(Vector2(r.end.x + 1.0, top), Vector2(3.0, h)), Color(edge, 0.9))
	# A lattice of light.
	var step := 10.0
	var x := r.position.x
	while x <= r.end.x + 0.1:
		b.line(Vector2(x, maxf(top, r.position.y)), Vector2(x, r.end.y), Color(col, 0.35 + 0.2 * pulse), 1.0)
		x += step
	var y := r.end.y
	while y >= top:
		b.line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(col, 0.3 + 0.15 * pulse), 1.0)
		y -= step
	# Its rising edge, bright, and runes at its feet.
	b.line(Vector2(r.position.x, top), Vector2(r.end.x, top), Color(col.lightened(0.3), 0.75 + 0.25 * pulse), 2.0)
	for i in 5:
		var rx := r.position.x + 8.0 + i * (r.size.x - 16.0) / 4.0
		b.dot(Vector2(rx, r.end.y + 3.0), 2.2, Color(edge, 0.6 + 0.4 * sin(t * 4.0 + i)))
	if st == "slipped":
		b.line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Color(1.0, 0.4, 0.3, 0.6 + 0.3 * sin(t * 5.0)), 2.0)


## A tower's ward, as drawn: its essence's colour made saturated enough to
## read against its floor and in its own light (palette.gd WARD; the essence
## keeps its own colour everywhere else).
static func ward_color(essence: String) -> Color:
	return Palette.WARD.get(essence, Palette.WARD["air"])
