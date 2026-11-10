extends "res://scripts/puzzles/base.gd"
## THE ICE HALL (the web version's ice, iceSolve and puzMove): the room's
## floor is a sheet of ice with rocks frozen into it, and a ring of plain
## floor around it. Once you step onto the ice you SLIDE in a straight line,
## along the tile grid, until a rock stops you, or off the far edge back onto
## the floor. Come to rest on the DAIS to solve it: sliding over it does
## nothing.
## The generator scatters rocks at random, then searches every slide from
## every way onto the ice (moves below) to find how many slides each resting
## place needs; the dais goes on one needing NEED to NEED+3 (the most it
## can). It also makes sure no resting place is a dead end: from anywhere you
## can stop, some line of slides leads off the ice, so you can never be stuck.
##   tier 1: the dais needs 2+ slides
##   tier 2: 3+ slides
##   tier 3: 4+ slides
## On the ice (player.gd asks steer() every frame) you can't walk, roll or
## jump: the stick, keys or touch stick pick the nearest of the four
## directions and off you go. A blow that knocks you about starts a slide
## the way it pushed. A monster in your lane stops you on the nearest tile.
## Getting it wrong costs nothing: slide off the ice and try again.

const NAME := "The Ice Hall"
static var NAMES := {"kraken": "Tide Slick"}
static var TEXT := {
	"rule": ["On the ice you slide until a rock stops you.", "Come to rest on the dais."],
	"quiet": "The dais sleeps while blood is spilled.",
	"footing": "No footing on the ice",
}
const BREAKS := {}
## Never sealed: sliding off the ice and walking back round is the reset.
const SEAL_FROM := 99
const MODES := ["quiet", "pressure"]
## The hall's size in tiles ([min w, max w, min h, max h]) and shape: a plain
## rectangle, its floor all ice but a one-tile ring.
const ROOM_SIZE := [10, 12, 8, 10]
const ROOM_SHAPES := ["rect"]
## By tier: the fewest slides the dais needs, and the share of ice that is rock.
const NEED := {1: 2, 2: 3, 3: 4}
const ROCKS := {1: 0.13, 2: 0.15, 3: 0.19}
## Rock layouts tried for one hall (the deepest is kept).
const TRIES := 240
const SLIDE := 330.0  # px a second
const SNAP := 300.0  # px a second toward the middle of the lane
const DEAD := 0.4  # how far the stick must tilt to slide
const EXIT := Vector2i(-999, -999)
const NONE := Vector2i(-998, -998)
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const ICE := Color(0.3, 0.42, 0.52)
const ICE_HI := Color(0.62, 0.78, 0.9)
const ROCK := Color(0.34, 0.32, 0.36)

var origin := Vector2.ZERO  # the ice's top-left corner (world)
var cols := 0
var rows_n := 0
var rocks := {}  # Vector2i (on the ice) -> true
var dais := Vector2i.ZERO
var need := 0  # the fewest slides the dais needs (the solver's answer)
var slide_dir := Vector2i.ZERO  # while sliding
var target := Vector2.ZERO  # where the slide ends (world)
var exit_slide := false  # the slide runs off the ice
var last_tile := NONE  # the tile (ice coordinates) the climber stood on last frame
var last_pos := Vector2.ZERO
var stuck_t := 0.0
var note_t := 0.0
var slides := 0  # slides since the climber last stepped onto the ice


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	var c := w - 2
	var r := h - 2
	if c < 6 or r < 5:
		return {}
	# The whole room must be open floor (ice inside, the ring around). The
	# tiles kept clear in front of doorways may be ice, but never rock.
	for y in h:
		for x in w:
			if not open_tile(ctx, Vector2i(x, y)):
				return {}
	var lo: int = NEED.get(tier, 2)
	var n_rocks := int(round(c * r * float(ROCKS.get(tier, 0.13))))
	var all: Array = []
	for y in r:
		for x in c:
			if not reserved(ctx, Vector2i(x + 1, y + 1)):
				all.append(Vector2i(x, y))
	if all.size() < n_rocks * 2:
		return {}
	# Rocks at random, kept if every resting place can get off the ice and
	# one needs enough slides; the deepest of several tries (one more slide
	# than the least is plenty).
	var keep := {}
	var keep_d := -1
	for tries in TRIES * 2:
		all.shuffle()
		var rk := {}
		for i in n_rocks:
			rk[all[i]] = true
		var dist := moves(c, r, rk)
		if dist.is_empty() or not escapable(c, r, rk, dist):
			continue
		var best := -1
		var picks: Array = []
		for t in dist:
			var d: int = dist[t]
			if d < lo or d > lo + 3:
				continue
			if d > best:
				best = d
				picks = [t]
			elif d == best:
				picks.append(t)
		if best > keep_d:
			keep_d = best
			keep = {"rocks": rk.keys(), "dais": picks[randi() % picks.size()]}
		if keep_d >= lo + 1 or (keep_d >= lo and tries >= TRIES / 3):
			break
	if keep.is_empty():
		return {}
	var at: Vector2i = keep["dais"]
	var reserve: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			reserve.append(Vector2i(x, y))
	var corner: Vector2 = rect.position + Vector2(CELL, CELL)
	return {"origin": corner, "cols": c, "rows": r, "rocks": keep["rocks"], "dais": at, "need": keep_d,
		"rewards": [corner + (Vector2(at) + Vector2(0.5, 0.5)) * CELL], "reserve": reserve}


## Where a slide from `pos` toward `d` comes to rest: the tile before the
## first rock, EXIT if it runs off the ice, or `pos` itself if a rock is
## right there. `pos` may be just off the ice (a way on).
static func slide_from(pos: Vector2i, d: Vector2i, c: int, r: int, rk: Dictionary) -> Vector2i:
	var p := pos
	for i in c + r + 2:
		var n := p + d
		if n.x < 0 or n.y < 0 or n.x >= c or n.y >= r:
			return EXIT
		if rk.has(n):
			return p
		p = n
	return p


## The ways onto the ice: [tile just off it, direction], one per edge tile.
static func entries(c: int, r: int) -> Array:
	var out: Array = []
	for x in c:
		out.append([Vector2i(x, -1), Vector2i.DOWN])
		out.append([Vector2i(x, r), Vector2i.UP])
	for y in r:
		out.append([Vector2i(-1, y), Vector2i.RIGHT])
		out.append([Vector2i(c, y), Vector2i.LEFT])
	return out


## The solver (the web version's iceSolve): every resting place on the ice
## and the fewest slides that reach it, stepping on from the floor counting
## as the first. A breadth-first search over slides.
static func moves(c: int, r: int, rk: Dictionary) -> Dictionary:
	var dist := {}
	var queue: Array = []
	for e in entries(c, r):
		var s := slide_from(e[0], e[1], c, r, rk)
		if s == EXIT or s == e[0] or dist.has(s):
			continue
		dist[s] = 1
		queue.append(s)
	var i := 0
	while i < queue.size():
		var s: Vector2i = queue[i]
		i += 1
		for d in DIRS:
			var t := slide_from(s, d, c, r, rk)
			if t == EXIT or t == s or dist.has(t):
				continue
			dist[t] = int(dist[s]) + 1
			queue.append(t)
	return dist


## Whether every resting place can slide its way off the ice (no dead ends).
static func escapable(c: int, r: int, rk: Dictionary, dist: Dictionary) -> bool:
	var free := {}
	var changed := true
	while changed:
		changed = false
		for s in dist:
			if free.has(s):
				continue
			for d in DIRS:
				var t := slide_from(s, d, c, r, rk)
				if t == EXIT or free.has(t):
					free[s] = true
					changed = true
					break
	return free.size() == dist.size()


## A shortest line of slides to the dais: [way on (tile off the ice), dir,
## then dirs...] (for tests and hints), or [] if none.
static func route(c: int, r: int, rk: Dictionary, goal: Vector2i) -> Array:
	var prev := {}
	var queue: Array = []
	for e in entries(c, r):
		var s := slide_from(e[0], e[1], c, r, rk)
		if s == EXIT or s == e[0] or prev.has(s):
			continue
		prev[s] = [e[0], e[1], true]
		queue.append(s)
	var i := 0
	while i < queue.size():
		var s: Vector2i = queue[i]
		i += 1
		if s == goal:
			break
		for d in DIRS:
			var t := slide_from(s, d, c, r, rk)
			if t == EXIT or t == s or prev.has(t):
				continue
			prev[t] = [s, d, false]
			queue.append(t)
	if not prev.has(goal):
		return []
	var dirs: Array = []
	var at := goal
	while true:
		var p: Array = prev[at]
		dirs.push_front(p[1])
		if p[2]:
			return [p[0]] + dirs
		at = p[0]
	return []


## The fewest slides from a resting place `from` off the ice: [dirs...]
## (the last one runs off), not resting on `avoid`, or [] if there's no way.
static func way_off(c: int, r: int, rk: Dictionary, from: Vector2i, avoid := EXIT) -> Array:
	var prev := {from: []}
	var queue: Array = [from]
	var i := 0
	while i < queue.size():
		var s: Vector2i = queue[i]
		i += 1
		for d in DIRS:
			var t := slide_from(s, d, c, r, rk)
			if t == EXIT:
				return prev[s] + [d]
			if t != s and t != avoid and not prev.has(t):
				prev[t] = prev[s] + [d]
				queue.append(t)
	return []


func _build() -> void:
	origin = spec.get("origin", Vector2.ZERO)
	cols = int(spec.get("cols", 0))
	rows_n = int(spec.get("rows", 0))
	dais = spec.get("dais", Vector2i.ZERO)
	need = int(spec.get("need", 0))
	for t in spec.get("rocks", []):
		rocks[t] = true
		host.add_body(Rect2(origin + Vector2(t) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)))
	# A cold light over the ice, so the rocks can be read from its edge.
	var f := field_rect()
	host.add_light(f.get_center(), f.size.length() * 0.5 + 40.0, Color(0.7, 0.85, 1.0), 0.28, 0.0)


func field_rect() -> Rect2:
	return Rect2(origin, Vector2(cols, rows_n) * CELL)


func grid(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - origin) / CELL).floor())


func in_field(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows_n


func center(t: Vector2i) -> Vector2:
	return origin + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


func on_ice(pos: Vector2) -> bool:
	return in_field(grid(pos))


## No rolling on the ice, and no jumping on it or on the ring of floor
## around it (`leap`): a leap over a rock would skip the puzzle.
func no_footing(pos: Vector2, leap: bool) -> bool:
	return field_rect().grow(CELL * 1.1 if leap else 0.0).has_point(pos)


func footing_note(pos: Vector2) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - note_t > 2.5:
		note_t = now
		main.fx_text(pos + Vector2(0, -34), TEXT["footing"], ICE_HI)


static func cardinal(v: Vector2) -> Vector2i:
	if absf(v.x) >= absf(v.y):
		return Vector2i.RIGHT if v.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if v.y > 0.0 else Vector2i.UP


## The climber's movement while on the ice (player.gd calls this every frame
## before moving): true if it set the climber's velocity.
func steer(p, delta: float) -> bool:
	if p.in_air():
		return false  # (a lift or a leap: we'll see where it lands)
	var g := grid(p.global_position)
	if not in_field(g):
		last_tile = g
		if slide_dir != Vector2i.ZERO and exit_slide:
			_slide(p, delta)  # running off the ice onto the floor
			return true
		slide_dir = Vector2i.ZERO
		slides = 0
		return false
	if slide_dir == Vector2i.ZERO:
		var d := Vector2i.ZERO
		if last_tile != NONE and not in_field(last_tile):
			# Just stepped (or landed) on: slide on the way you came.
			var step := g - last_tile
			if step.x != 0 and step.y != 0:
				d = cardinal(p.velocity if p.velocity.length() > 1.0 else Vector2(step))
			else:
				d = cardinal(Vector2(step))
		elif p.knock.length() > 100.0:
			d = cardinal(p.knock)  # knocked about: off you go
		else:
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if input.length() >= DEAD:
				d = cardinal(input)
		if d != Vector2i.ZERO:
			_start(p, g, d)
	last_tile = g
	p.knock = Vector2.ZERO
	if slide_dir != Vector2i.ZERO:
		_slide(p, delta)
	else:
		# At rest: drift to the middle of the tile.
		var to: Vector2 = center(g) - p.global_position
		p.velocity = Vector2.ZERO if to.length() < 0.5 else to.normalized() * minf(SNAP, to.length() / delta)
	return true


func _start(p, g: Vector2i, d: Vector2i) -> void:
	var stop := slide_from(g, d, cols, rows_n, rocks)
	if stop == g:
		return  # a rock right there
	slide_dir = d
	exit_slide = stop == EXIT
	if exit_slide:
		var t := g
		while in_field(t):
			t += d
		target = center(t)
	else:
		target = center(stop)
	last_pos = p.global_position
	stuck_t = 0.0
	slides += 1
	main.sfx("roll", 1.45, -12.0, 0.08)


func _slide(p, delta: float) -> void:
	var dv := Vector2(slide_dir)
	var to: Vector2 = target - p.global_position
	var along: float = to.dot(dv)
	if along <= SLIDE * delta:
		# Arrived: land exactly on the tile.
		p.velocity = to / delta
		slide_dir = Vector2i.ZERO
		if not exit_slide:
			main.sfx("hit_blunt", 0.7, -14.0, 0.05)
			main.fx_burst(target + dv * 18.0, -dv, ICE_HI, 5, 70.0)
		else:
			slides = 0
		return
	var perp: Vector2 = to - dv * along
	var fix: Vector2 = Vector2.ZERO if perp.length() < 0.5 else perp.normalized() * minf(SNAP, perp.length() / delta)
	p.velocity = dv * SLIDE + fix
	# Blocked (a monster in the lane): stop on the tile you're on.
	if last_pos.distance_to(p.global_position) < SLIDE * delta * 0.25:
		stuck_t += delta
		if stuck_t > 0.12:
			slide_dir = Vector2i.ZERO
			stuck_t = 0.0
	else:
		stuck_t = 0.0
	last_pos = p.global_position


func tick(_delta: float) -> void:
	var p = player()
	if p == null or p.dead or p.in_air() or slide_dir != Vector2i.ZERO:
		return
	if grid(p.global_position) == dais and p.global_position.distance_to(center(dais)) < 8.0:
		host.solve()


func reset() -> void:
	slide_dir = Vector2i.ZERO


func state() -> Array:
	return [host.solved]


func spot_ok(pos: Vector2) -> bool:
	return not field_rect().grow(6.0).has_point(pos)


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": TEXT["rule"]}]


func lights() -> Array:
	var col := Color(1.0, 0.89, 0.63) if host.solved else Color(0.75, 0.9, 1.0)
	return [[center(dais), 110.0, col, 0.55 if host.solved else 0.4, 0.15]]


static func _h(t: Vector2i, k: int) -> float:
	return float(abs((t.x * 73856093) ^ (t.y * 19349663) ^ (k * 83492791)) % 1000) / 1000.0


func draw(ci: CanvasItem) -> void:
	var f := field_rect()
	# The ice: pale blue slabs, each with a sheen and a crack or two.
	ci.draw_rect(f.grow(3.0), Color(0.2, 0.26, 0.32))
	ci.draw_rect(f, ICE.darkened(0.1))
	for y in rows_n:
		for x in cols:
			var t := Vector2i(x, y)
			var r := Rect2(origin + Vector2(t) * CELL, Vector2(CELL, CELL)).grow(-1.0)
			ci.draw_rect(r, ICE.lightened(0.06 * _h(t, 1)))
			ci.draw_line(r.position + Vector2(4, 8 + 10 * _h(t, 2)), r.position + Vector2(14 + 8 * _h(t, 3), 4), Color(ICE_HI, 0.4), 2.0)
			if _h(t, 4) < 0.45:
				var c := r.get_center() + Vector2(6 * _h(t, 5) - 3, 6 * _h(t, 6) - 3)
				ci.draw_line(c, c + Vector2(10, 6 - 12 * _h(t, 7)), Color(0.3, 0.42, 0.52, 0.8), 1.0)
				ci.draw_line(c, c + Vector2(-7, 8 * _h(t, 8)), Color(0.3, 0.42, 0.52, 0.6), 1.0)
	# Frost along the edge, where ice meets floor.
	ci.draw_rect(f, Color(0.82, 0.92, 1.0, 0.7), false, 2.0)
	# The dais: a round stone set in the ice.
	var dc := center(dais)
	ci.draw_circle(dc, 17.0, Color(0.1, 0.09, 0.12))
	ci.draw_circle(dc, 15.0, Color(0.42, 0.38, 0.44))
	ci.draw_circle(dc, 10.0, Color(1.0, 0.89, 0.63) if host.solved else Color(0.3, 0.27, 0.33))
	for k in 6:
		var a := TAU * k / 6.0
		ci.draw_line(dc + Vector2.from_angle(a) * 11.0, dc + Vector2.from_angle(a) * 14.0, Color(0.62, 0.56, 0.42), 2.0)
	# The rocks: boulders frozen in, rimed on top.
	for t in rocks:
		var c := center(t)
		Draw.shadow(ci, c + Vector2(0, 9), 16.0, 0.4)
		var pts := PackedVector2Array()
		for k in 8:
			var a := TAU * k / 8.0
			pts.append(c + Vector2.from_angle(a) * (14.0 + 4.0 * _h(t, 10 + k)) * Vector2(1.0, 0.9))
		Draw.poly(ci, pts, ROCK.lightened(0.08 * _h(t, 20)), 1.8)
		ci.draw_circle(c + Vector2(-4, -5), 6.0, ROCK.lightened(0.18))
		ci.draw_line(c + Vector2(-9, -9), c + Vector2(5, -12), Color(0.85, 0.93, 1.0, 0.8), 2.5)


func draw_glow(ci: CanvasItem, t: float) -> void:
	var dc := center(dais)
	if host.solved:
		return
	var a := 0.35 + 0.2 * sin(t * 2.5)
	ci.draw_arc(dc, 20.0, 0.0, TAU, 28, Color(0.8, 0.92, 1.0, a if host.awake else a * 0.4), 2.0)
	# A glint sweeping slowly across the ice.
	var f := field_rect()
	var x := f.position.x + fposmod(t * 70.0, f.size.x + 120.0) - 60.0
	ci.draw_line(Vector2(x, f.position.y + 2.0), Vector2(x - 40.0, f.end.y - 2.0), Color(1, 1, 1, 0.04), 10.0)


func draw_over(ci: CanvasItem, t: float) -> void:
	var dc := center(dais)
	var k := 0.22 + 0.06 * sin(t * 2.5)
	var col := Color(1.0, 0.85, 0.5) if host.solved else Color(0.6, 0.8, 1.0)
	ci.draw_circle(dc, 8.0, Color(col.r * k, col.g * k, col.b * k))
