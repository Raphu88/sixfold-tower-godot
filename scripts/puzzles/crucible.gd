extends "res://scripts/puzzles/base.gd"
## THE CRUCIBLE: a smooth iron floor in the middle of the gallery, lumps of
## cold slag on it, a glowing crucible of molten metal, and a mould sunk
## into the floor. Strike the crucible and it slides away from you, straight
## on, until slag or the floor's raised rim stops it (it doesn't stop on the
## mould by itself: it slides over). Bring it to rest on the mould and the
## metal pours.
##   a crucible pushed where it can never reach the mould  FAILURE: it jams,
##        the beast sends hunters, and once they're beaten it's set back
##   tier 1: 6x5 floor, 3 lumps of slag, at least 2 pushes
##   tier 2: 7x5 floor, 4 lumps, at least 3 pushes
##   tier 3: 7x6 floor, 6 lumps, at least 4 pushes, and the room closes
## Only a blow moves it (an arrow just rings off it), and you must have room
## to stand on the far side to push it. A creature in its way stops it short.
## The generator searches every way the crucible can go (solve below) and
## keeps only a mould it can reach; the floor bot uses the same search.

const NAME := "The Crucible"
static var NAMES := {"wyvern": "The Wyvern's Crucible"}
static var TEXT := {
	"rule": ["Strike the crucible: it slides away from you until something stops it.", "Bring it to rest on the mould."],
	"quiet": "The crucible won't budge while blood is spilled.",
	"jam": "The crucible jams where it can't reach the mould.",
	"heavy": "Too heavy for an arrow",
}
const BREAKS := {}
const SEAL_FROM := 3
const MODES := ["quiet", "pressure"]
## By tier: [columns, rows, lumps of slag, fewest pushes].
const GRID := {1: [6, 5, 3, 2], 2: [7, 5, 4, 3], 3: [7, 6, 6, 4]}
const SLIDE_SPEED := 300.0
const POT_R := 15.0
const ROOM_SIZE := [11, 13, 9, 11]
const ROOM_SHAPES := ["rect", "rect", "round"]
const MOLTEN := Color(1.0, 0.55, 0.18)
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var origin := Vector2.ZERO  # the iron floor's top-left corner (world)
var cols := 0
var rows_n := 0
var rocks := {}  # Vector2i -> true
var start := Vector2i.ZERO
var goal := Vector2i.ZERO
var cell := Vector2i.ZERO  # where the crucible rests
var pos := Vector2.ZERO  # where it's drawn (it slides)
var slide_dir := Vector2i.ZERO
var body: StaticBody2D
var pours := 0.0  # solved: the pour's glow


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var g: Array = GRID.get(tier, GRID[1])
	var c: int = g[0]
	var r: int = g[1]
	var o := fit_block(ctx, Vector2i(c, r), 1)
	if o.x < 0:
		return {}
	var all: Array = []
	for y in r:
		for x in c:
			all.append(Vector2i(x, y))
	for tries in 40:
		all.shuffle()
		var rk := {}
		for k in int(g[2]):
			rk[all[k]] = true
		var free: Array = all.filter(func(t): return not rk.has(t))
		var st: Vector2i = free[randi() % free.size()]
		var depth := reach_all(st, rk, c, r)
		var best: Array = []
		for t in depth:
			if int(depth[t]) >= int(g[3]):
				best.append(t)
		if best.is_empty():
			continue
		var gl: Vector2i = best[randi() % best.size()]
		var corner: Vector2 = rect.position + Vector2(o) * CELL
		return {"origin": corner, "cols": c, "rows_n": r, "rocks": rk.keys(), "start": st, "goal": gl,
			"reserve": block_tiles(o, Vector2i(c, r), 1), "rewards": [corner + Vector2(gl) * CELL + Vector2(CELL, CELL) * 0.5]}
	return {}


static func inside(t: Vector2i, c: int, r: int) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < c and t.y < r


## Where a push sends it from `at` going `d`: the last free cell before slag
## or the rim (`at` itself if it can't move).
static func slide_from(at: Vector2i, d: Vector2i, rk: Dictionary, c: int, r: int) -> Vector2i:
	var t := at
	while inside(t + d, c, r) and not rk.has(t + d):
		t += d
	return t


## The cells a climber can stand on beside the floor, with the crucible at
## `at`: every free cell joined to the rim's ring (which is all open floor).
static func standable(at: Vector2i, rk: Dictionary, c: int, r: int) -> Dictionary:
	var seen := {}
	var q: Array = []
	for x in range(-1, c + 1):
		for y in [-1, r]:
			q.append(Vector2i(x, y))
	for y in range(0, r):
		q.append(Vector2i(-1, y))
		q.append(Vector2i(c, y))
	for t in q:
		seen[t] = true
	while not q.is_empty():
		var t: Vector2i = q.pop_back()
		for d in DIRS:
			var n: Vector2i = t + d
			if seen.has(n) or not inside(n, c, r) or rk.has(n) or n == at:
				continue
			seen[n] = true
			q.append(n)
	return seen


## The pushes that can be made from `at`: [[dir, where it ends], ...].
static func pushes(at: Vector2i, rk: Dictionary, c: int, r: int) -> Array:
	var out: Array = []
	var stand := standable(at, rk, c, r)
	for d in DIRS:
		if not stand.has(at - d):
			continue
		var to := slide_from(at, d, rk, c, r)
		if to != at:
			out.append([d, to])
	return out


## Every resting cell reachable from `st`, and the fewest pushes to it.
static func reach_all(st: Vector2i, rk: Dictionary, c: int, r: int) -> Dictionary:
	var depth := {st: 0}
	var q: Array = [st]
	while not q.is_empty():
		var t: Vector2i = q.pop_front()
		for p in pushes(t, rk, c, r):
			if not depth.has(p[1]):
				depth[p[1]] = int(depth[t]) + 1
				q.append(p[1])
	return depth


## The fewest pushes from `at` to `gl`: [[dir, where it ends], ...], [] if
## it's there already, null if it can't get there.
static func solve(at: Vector2i, gl: Vector2i, rk: Dictionary, c: int, r: int) -> Variant:
	if at == gl:
		return []
	var back := {at: null}
	var q: Array = [at]
	while not q.is_empty():
		var t: Vector2i = q.pop_front()
		for p in pushes(t, rk, c, r):
			if back.has(p[1]):
				continue
			back[p[1]] = [t, p[0]]
			if p[1] == gl:
				var out: Array = []
				var k: Vector2i = gl
				while back[k] != null:
					out.push_front([back[k][1], k])
					k = back[k][0]
				return out
			q.append(p[1])
	return null


func _build() -> void:
	origin = spec.get("origin", room.position)
	cols = int(spec.get("cols", 6))
	rows_n = int(spec.get("rows_n", 5))
	for t in spec.get("rocks", []):
		rocks[t] = true
		var c := center(t)
		host.add_body(Rect2(c - Vector2(16, 16), Vector2(32, 32)))
	start = spec.get("start", Vector2i.ZERO)
	goal = spec.get("goal", Vector2i.ZERO)
	cell = start
	pos = center(cell)
	body = host.add_round_body(pos, POT_R)


func center(t: Vector2i) -> Vector2:
	return origin + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


func grid(p: Vector2) -> Vector2i:
	return Vector2i(((p - origin) / CELL).floor())


func sliding() -> bool:
	return slide_dir != Vector2i.ZERO


## The floor bot: the next push, [stand (world), dir], or [] (sliding, or there).
func next_push() -> Array:
	if sliding() or host.solved:
		return []
	var s = solve(cell, goal, rocks, cols, rows_n)
	if s == null or s.is_empty():
		return []
	var d: Vector2i = s[0][0]
	return [center(cell - d), d]


func tick(delta: float) -> void:
	if host.solved:
		pours = minf(1.0, pours + delta)


## The slide runs every frame (asleep or not: a push begun finishes).
func watch(delta: float) -> void:
	if not sliding():
		return
	var next := cell + slide_dir
	var target := center(next)
	pos = pos.move_toward(target, SLIDE_SPEED * delta)
	if pos.distance_to(target) < 0.5:
		cell = next
		pos = target
		var ahead := cell + slide_dir
		if not inside(ahead, cols, rows_n) or rocks.has(ahead) or _creature_at(center(ahead)):
			_stop()
	if is_instance_valid(body):
		body.position = pos


func _creature_at(at: Vector2) -> bool:
	var p = player()
	if p != null and p.global_position.distance_to(at) < 22.0:
		return true
	for e in main.enemies():
		if not e.dead and e.global_position.distance_to(at) < 20.0:
			return true
	return false


func _stop() -> void:
	slide_dir = Vector2i.ZERO
	main.sfx("ice_bump", 0.7, -2.0)
	main.shake(2.0)
	if cell == goal:
		main.fx_burst(pos, Vector2.UP, MOLTEN, 22, 160.0)
		main.light_flash(pos, MOLTEN, 1.6, 1.6, 0.5)
		host.solve()
		return
	if solve(cell, goal, rocks, cols, rows_n) == null:
		host.fail(TEXT["jam"])


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	if not in_swing(from, dir, pos, reach + 6.0, arc_deg):
		return 0
	if sliding() or host.solved or not host.awake or host.locked:
		return 1
	var to := pos - from
	var d := Vector2i(signi(int(round(to.x))), 0) if absf(to.x) >= absf(to.y) else Vector2i(0, signi(int(round(to.y))))
	var ahead := cell + d
	if not inside(ahead, cols, rows_n) or rocks.has(ahead) or _creature_at(center(ahead)):
		main.sfx("hit_armor", 0.7, -6.0)
		return 1
	slide_dir = d
	main.sfx("stone_slide", 1.0, -2.0)
	main.fx_burst(pos - Vector2(d) * 12.0, -Vector2(d), Color(1.0, 0.7, 0.35), 8, 90.0)
	return 1


func shot(p: Vector2) -> bool:
	if p.distance_to(pos) < POT_R + 3.0:
		main.fx_text(pos + Vector2(0, -30), TEXT["heavy"], Color(0.9, 0.8, 0.7))
		return true
	return false


func reset() -> void:
	slide_dir = Vector2i.ZERO
	cell = start
	pos = center(cell)
	if is_instance_valid(body):
		body.position = pos


func state() -> Array:
	return [cell, sliding()]


func aim_points() -> Array:
	return [pos] if not host.solved else []


func spot_ok(p: Vector2) -> bool:
	var g := grid(p)
	return not (inside(g, cols, rows_n) or p.distance_to(pos) < 50.0)


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": TEXT["rule"].duplicate()}]


func lights() -> Array:
	return [[pos, 120.0, MOLTEN, 0.65, 0.2], [center(goal), 70.0, MOLTEN, 0.3 + 0.4 * pours, 0.05]]


## The iron floor (plates, a raised rim), the slag and the mould.
func draw(ci: CanvasItem) -> void:
	var r := Rect2(origin, Vector2(cols, rows_n) * CELL)
	ci.draw_rect(r.grow(4.0), Color(0.1, 0.09, 0.1))
	ci.draw_rect(r.grow(2.0), Color(0.42, 0.38, 0.36))
	ci.draw_rect(r, Color(0.24, 0.23, 0.25))
	for x in range(1, cols):
		ci.draw_line(origin + Vector2(x * CELL, 0), origin + Vector2(x * CELL, r.size.y), Color(0.15, 0.14, 0.16), 1.5)
	for y in range(1, rows_n):
		ci.draw_line(origin + Vector2(0, y * CELL), origin + Vector2(r.size.x, y * CELL), Color(0.15, 0.14, 0.16), 1.5)
	for x in cols:
		for y in rows_n:
			ci.draw_circle(origin + Vector2(x * CELL + 5, y * CELL + 5), 1.5, Color(0.4, 0.38, 0.38))
	# The mould: a sunken outline of the crucible's foot.
	var m := center(goal)
	ci.draw_circle(m, 16.0, Color(0.08, 0.07, 0.08))
	ci.draw_arc(m, 16.0, 0.0, TAU, 28, Color(0.6, 0.45, 0.3), 2.0)
	ci.draw_arc(m, 10.0, 0.0, TAU, 20, Color(0.45, 0.33, 0.22), 1.5)
	# The slag: dark lumps with a few warm cracks.
	for t in rocks:
		var c := center(t)
		var pts := PackedVector2Array()
		for i in 9:
			var a := TAU * i / 9.0
			pts.append(c + Vector2.from_angle(a) * (14.0 + 3.0 * sin(a * 3.0 + c.x)))
		ci.draw_colored_polygon(pts, Color(0.17, 0.15, 0.16))
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.07, 0.06, 0.07), 2.0)
		ci.draw_line(c + Vector2(-6, -3), c + Vector2(2, 2), Color(0.8, 0.35, 0.15, 0.7), 1.5)
		ci.draw_line(c + Vector2(2, 2), c + Vector2(7, -1), Color(0.8, 0.35, 0.15, 0.5), 1.2)


func draw_glow(ci: CanvasItem, t: float) -> void:
	var m := center(goal)
	if host.solved:
		ci.draw_circle(m, 14.0 * pours, Color(1.0, 0.6, 0.2, 0.9))
	elif host.awake:
		ci.draw_arc(m, 20.0, 0.0, TAU, 28, Color(MOLTEN, 0.25 + 0.2 * sin(t * 3.0)), 2.0)
	# The crucible: an iron pot, molten metal at its lip.
	var c := pos
	Draw.shadow(ci, c + Vector2(0, 10), 15.0)
	var pot := PackedVector2Array([c + Vector2(-14, -8), c + Vector2(14, -8), c + Vector2(11, 10), c + Vector2(-11, 10)])
	ci.draw_colored_polygon(pot, Color(0.22, 0.2, 0.22))
	ci.draw_polyline(pot + PackedVector2Array([pot[0]]), Color(0.08, 0.07, 0.08), 2.0)
	ci.draw_line(c + Vector2(-16, -8), c + Vector2(16, -8), Color(0.45, 0.42, 0.42), 3.0)
	var f := 1.0 + 0.1 * sin(t * 7.0)
	ci.draw_rect(Rect2(c + Vector2(-11, -12), Vector2(22, 5)), Color(1.0, 0.55, 0.15, 0.95))
	ci.draw_circle(c + Vector2(0, -10), 4.0 * f, Color(1.0, 0.9, 0.55))
	if sliding():
		for k in 3:
			ci.draw_line(c - Vector2(slide_dir) * (18.0 + k * 7.0) + Vector2(slide_dir).orthogonal() * (k - 1) * 6.0,
				c - Vector2(slide_dir) * (26.0 + k * 7.0) + Vector2(slide_dir).orthogonal() * (k - 1) * 6.0, Color(1.0, 0.7, 0.4, 0.5), 2.0)


func draw_over(ci: CanvasItem, _t: float) -> void:
	ci.draw_circle(pos + Vector2(0, -10), 4.0, Color(0.6, 0.3, 0.1))
