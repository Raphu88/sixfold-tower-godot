extends "res://scripts/puzzles/base.gd"
## THE HALL OF LANTERNS: iron lanterns stand in a grid on the gallery floor,
## some lit, some dark. Strike (or shoot) a lantern and it changes, and so
## do the lanterns beside it (left, right, ahead, behind: grooves in the
## floor join them). Light every lantern at once.
##   tier 1: 3x3 lanterns
##   tier 2: 4x3
##   tier 3: 4x4, and the room closes behind you
## Nothing here goes wrong for good: every blow can be undone by the same
## blow again, so there's no failure, only the beast's creatures (quiet and
## pressure modes, puzzle.gd). The generator starts from every lantern lit
## and puts some out the way a blow would, so an answer always exists; the
## floor bot works it out from the lanterns as they stand (solve below).

const NAME := "The Hall of Lanterns"
static var NAMES := {"firebird": "The Ember Lanterns"}
static var TEXT := {
	"rule": ["Light every lantern.", "A blow changes a lantern and the ones beside it."],
	"quiet": "The lanterns gutter while blood is spilled.",
}
const BREAKS := {}
const SEAL_FROM := 3
const MODES := ["quiet", "pressure"]
## By tier: [columns, rows, blows used to scramble it (at least, at most)].
const GRID := {1: [3, 3, 3, 4], 2: [4, 3, 4, 5], 3: [4, 4, 5, 7]}
## Tiles between lanterns, and a lantern's size (its body and an arrow's mark).
const GAP := 2
const LANTERN_R := 13.0
## A carved hall big enough for the biggest grid.
const ROOM_SIZE := [12, 13, 10, 11]
const ROOM_SHAPES := ["rect", "rect", "round"]
const FLAME := Color(1.0, 0.66, 0.3)
const IRON := Color(0.3, 0.28, 0.3)

var cols := 0
var rows_n := 0
var lanterns: Array = []  # {pos, lit, g (grid cell), flash}


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var g: Array = GRID.get(tier, GRID[1])
	var c: int = g[0]
	var r: int = g[1]
	var size := Vector2i((c - 1) * GAP + 1, (r - 1) * GAP + 1)
	var o := fit_block(ctx, size, 1)
	if o.x < 0:
		return {}
	# Every lantern lit, then the same blows a climber would make put some out.
	var lit: Array = []
	lit.resize(c * r)
	lit.fill(true)
	var n := randi_range(int(g[2]), int(g[3]))
	var cells: Array = range(c * r)
	cells.shuffle()
	for k in n:
		_press(lit, c, r, int(cells[k]))
	if lit.all(func(v): return v):
		_press(lit, c, r, int(cells[0]))
	var spots: Array = []
	for i in c * r:
		var t := o + Vector2i(i % c, i / c) * GAP
		spots.append({"pos": tile_center(rect, t), "lit": lit[i]})
	return {"cols": c, "rows_n": r, "lanterns": spots, "reserve": block_tiles(o, size, 1),
		"rewards": [tile_center(rect, o + Vector2i(size.x / 2, size.y + 1))]}


## A blow on lantern `i` of a `c` by `r` grid: it and its four neighbours change.
static func _press(lit: Array, c: int, r: int, i: int) -> void:
	for j in neighbours(c, r, i) + [i]:
		lit[j] = not lit[j]


static func neighbours(c: int, r: int, i: int) -> Array:
	var out: Array = []
	var x := i % c
	var y := i / c
	if x > 0:
		out.append(i - 1)
	if x < c - 1:
		out.append(i + 1)
	if y > 0:
		out.append(i - c)
	if y < r - 1:
		out.append(i + c)
	return out


## Which lanterns to strike (each once) to light them all, from `lit`: the
## answer by elimination over the grid's blows (in twos: a blow twice is no
## blow). [] when they're all lit already; null if there is no answer (never
## from a lit grid scrambled by blows, as make does).
static func solve(lit: Array, c: int, r: int) -> Variant:
	var n := c * r
	# Rows of the system: for each lantern, which blows change it, and
	# whether it must change (it's dark).
	var m: Array = []
	for i in n:
		var row: Array = []
		row.resize(n + 1)
		row.fill(false)
		for j in neighbours(c, r, i) + [i]:
			row[j] = true
		row[n] = not bool(lit[i])
		m.append(row)
	var where: Array = []
	where.resize(n)
	where.fill(-1)
	var at := 0
	for col in n:
		var piv := -1
		for k in range(at, n):
			if m[k][col]:
				piv = k
				break
		if piv < 0:
			continue
		var tmp = m[at]
		m[at] = m[piv]
		m[piv] = tmp
		for k in n:
			if k != at and m[k][col]:
				for j in range(col, n + 1):
					m[k][j] = m[k][j] != m[at][j]
		where[col] = at
		at += 1
	for k in range(at, n):
		if m[k][n]:
			return null
	var out: Array = []
	for col in n:
		if where[col] >= 0 and m[where[col]][n]:
			out.append(col)
	return out


func _build() -> void:
	cols = int(spec.get("cols", 3))
	rows_n = int(spec.get("rows_n", 3))
	var i := 0
	for q in spec.get("lanterns", []):
		lanterns.append({"pos": q["pos"], "lit": q["lit"], "start": q["lit"], "i": i, "flash": 0.0})
		host.add_round_body(q["pos"], LANTERN_R)
		i += 1


func lit_list() -> Array:
	return lanterns.map(func(q): return q["lit"])


## What the floor bot strikes next (indices), from the lanterns as they are.
func answer() -> Array:
	var s = solve(lit_list(), cols, rows_n)
	return s if s != null else []


func tick(delta: float) -> void:
	for q in lanterns:
		q["flash"] = maxf(0.0, q["flash"] - delta)


func _strike_lantern(q: Dictionary) -> void:
	if host.solved or not host.awake:
		return
	var i: int = q["i"]
	for j in neighbours(cols, rows_n, i) + [i]:
		var o: Dictionary = lanterns[j]
		o["lit"] = not o["lit"]
		o["flash"] = 0.35
		main.fx_ring(o["pos"], FLAME if o["lit"] else Color(0.5, 0.45, 0.5), 26.0, 0.3, 2.0)
	main.sfx("burn" if q["lit"] else "hiss", 1.1, -6.0, 0.05)
	main.light_flash(q["pos"], FLAME, 0.7, 1.0, 0.25)
	if lanterns.all(func(o): return o["lit"]):
		host.solve()


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	var q = nearest_in_swing(lanterns, from, dir, reach, arc_deg)
	if q == null:
		return 0
	_strike_lantern(q)
	return 1


func shot(pos: Vector2) -> bool:
	for q in lanterns:
		if pos.distance_to(q["pos"]) < LANTERN_R + 3.0:
			_strike_lantern(q)
			return true
	return false


func reset() -> void:
	for q in lanterns:
		q["lit"] = q["start"]


func state() -> Array:
	return lit_list()


func aim_points() -> Array:
	var out: Array = []
	for i in answer():
		out.append(lanterns[i]["pos"])
	return out


func spot_ok(pos: Vector2) -> bool:
	for q in lanterns:
		if q["pos"].distance_to(pos) < 46.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0) or lanterns.is_empty():
		return []
	var lines: Array = TEXT["rule"].duplicate()
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": lines}]


func lights() -> Array:
	var out: Array = []
	for q in lanterns:
		if q["lit"] or host.solved:
			out.append([q["pos"] + Vector2(0, -10), 100.0, FLAME, 0.6, 0.2])
	return out


## The floor: grooves joining each lantern to the ones beside it, then the
## lanterns themselves (an iron cage on a stone foot).
func draw(ci: CanvasItem) -> void:
	var groove := Color(0.12, 0.1, 0.12, 0.7)
	for q in lanterns:
		for j in neighbours(cols, rows_n, int(q["i"])):
			if j > int(q["i"]):
				ci.draw_line(q["pos"], lanterns[j]["pos"], groove, 5.0)
				ci.draw_line(q["pos"], lanterns[j]["pos"], Color(0.4, 0.34, 0.3, 0.5), 1.5)
	for q in lanterns:
		var c: Vector2 = q["pos"]
		Draw.shadow(ci, c + Vector2(0, 10), 14.0)
		ci.draw_rect(Rect2(c + Vector2(-12, 4), Vector2(24, 8)), Color(0.1, 0.09, 0.11))
		ci.draw_rect(Rect2(c + Vector2(-11, 5), Vector2(22, 6)), Color(0.42, 0.39, 0.42))
		# The cage.
		var cage := PackedVector2Array([c + Vector2(-8, 4), c + Vector2(-9, -14), c + Vector2(0, -21), c + Vector2(9, -14), c + Vector2(8, 4)])
		ci.draw_colored_polygon(cage, Color(0.14, 0.12, 0.13))
		ci.draw_polyline(cage + PackedVector2Array([cage[0]]), IRON.lightened(0.25), 2.0)
		ci.draw_line(c + Vector2(0, -21), c + Vector2(0, 4), IRON.lightened(0.15), 1.5)
		ci.draw_line(c + Vector2(-9, -6), c + Vector2(9, -6), IRON.lightened(0.15), 1.5)
		ci.draw_circle(c + Vector2(0, -24), 3.0, IRON.lightened(0.3))


func draw_glow(ci: CanvasItem, t: float) -> void:
	for q in lanterns:
		var c: Vector2 = q["pos"] + Vector2(0, -6)
		if q["lit"] or host.solved:
			var f := 1.0 + 0.18 * sin(t * 9.0 + c.x * 0.1)
			ci.draw_circle(c, 7.5 * f, Color(1.0, 0.5, 0.18, 0.85))
			ci.draw_circle(c + Vector2(0, 1), 4.0 * f, Color(1.0, 0.92, 0.6))
		else:
			ci.draw_circle(c, 3.0, Color(0.35, 0.22, 0.2))
			if host.awake and not host.solved:
				ci.draw_arc(q["pos"] + Vector2(0, -8), 17.0, 0.0, TAU, 20, Color(1.0, 0.7, 0.4, 0.12 + 0.1 * sin(t * 2.5 + c.x)), 1.2)
		if q["flash"] > 0.0:
			ci.draw_arc(q["pos"] + Vector2(0, -8), 20.0 + (0.35 - q["flash"]) * 30.0, 0.0, TAU, 24, Color(FLAME, q["flash"] * 2.0), 2.0)


## Lit flames show through the darkness.
func draw_over(ci: CanvasItem, _t: float) -> void:
	for q in lanterns:
		if q["lit"] or host.solved:
			ci.draw_circle(q["pos"] + Vector2(0, -6), 5.0, Color(0.6, 0.35, 0.12))
