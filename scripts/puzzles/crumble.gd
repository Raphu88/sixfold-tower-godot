extends "res://scripts/puzzles/base.gd"
## THE CRUMBLING PATH (the web version's crumble and hamPath): a grid of
## stones in the middle of the room, maybe with holes in it. Step on every
## stone exactly once: each stone lights as you step on it, and a lit stone
## crumbles beneath you if you come back to it (it hurts, and the path goes
## dark). The path must not break, either: every step goes to a stone beside
## the last one, and wandering off the grid puts the stones out.
## The generator only keeps a grid where a route over every stone exists
## from a stone on its edge (a bounded search: hamilton_path below).
##   tier 1: 5x3 stones
##   tier 2: 5x4 stones, one hole
##   tier 3: 6x5 stones, two holes
## Holes are pits (solid). Even a jump's shadow wakes the stones, so leaping
## over a lit stone doesn't help; only a Flamewing's glide passes unfelt.

const NAME := "The Crumbling Path"
static var NAMES := {"wyvern": "Ember Path"}
static var TEXT := {
	"rule": ["Step on every stone once, and only once.", "A stone you've used crumbles beneath you."],
	"quiet": "The stones lie cold while blood is spilled.",
	"crumble": "It crumbles beneath you",
	"broken": "The path broke: step only to a stone beside the last",
	"dark": "The path goes dark",
	"glide": "You glide over unfelt",
}
const BREAKS := {"flamewing": "Phoenix Glide: the stones don't feel you while you glide, so you can pass over a lit one."}
const SEAL_FROM := 2
const MODES := ["quiet", "pressure"]
## By tier: [columns, rows, holes].
const GRID := {1: [5, 3, 0], 2: [5, 4, 1], 3: [6, 5, 2]}
## The search gives up after this many steps (then the grid is redrawn).
const SEARCH_LIMIT := 60000
## Off the grid this long with stones lit, and they go dark.
const OFF_GRACE := 0.6

var origin := Vector2.ZERO  # the grid's top-left corner (world)
var cols := 0
var rows_n := 0
var stones := {}  # Vector2i (grid) -> lit
var holes: Array = []  # Vector2i (grid)
var last = null  # the last stone stepped on (Vector2i) or null
var off_t := 0.0
var glided := false  # passed over stones in a glide since the last step


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	var g: Array = GRID.get(tier, GRID[1])
	var c: int = g[0]
	var r: int = g[1]
	var n_holes: int = g[2]
	# Centred, with a ring of open floor around it to walk on.
	var place := Vector2i(-1, -1)
	for shift in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var o: Vector2i = Vector2i((w - c) / 2, (h - r) / 2) + shift
		if o.x < 2 or o.y < 2 or o.x + c > w - 2 or o.y + r > h - 2:
			continue
		var ok := true
		for y in range(o.y - 1, o.y + r + 1):
			for x in range(o.x - 1, o.x + c + 1):
				var t := Vector2i(x, y)
				var inside := x >= o.x and y >= o.y and x < o.x + c and y < o.y + r
				ok = ok and open_tile(ctx, t) and (not inside or not reserved(ctx, t))
		if ok:
			place = o
			break
	if place.x < 0:
		return {}
	var all: Array = []
	for y in r:
		for x in c:
			all.append(Vector2i(x, y))
	var cells: Array = all
	var holes: Array = []
	if n_holes > 0:
		var found := false
		for tries in 60:
			var test: Array = all.duplicate()
			var hs: Array = []
			for k in n_holes:
				# (Not on the outer edge: holes sit inside the grid.)
				var inner: Array = test.filter(func(t): return t.x > 0 and t.y > 0 and t.x < c - 1 and t.y < r - 1 and not (t in hs))
				if inner.is_empty():
					break
				var pick: Vector2i = inner[randi() % inner.size()]
				hs.append(pick)
				test.erase(pick)
			if hs.size() == n_holes and not hamilton_path(test, c, r).is_empty():
				cells = test
				holes = hs
				found = true
				break
		if not found:
			return {}
	elif hamilton_path(cells, c, r).is_empty():
		return {}
	var reserve: Array = []
	for y in range(place.y - 1, place.y + r + 1):
		for x in range(place.x - 1, place.x + c + 1):
			reserve.append(Vector2i(x, y))
	var corner: Vector2 = rect.position + Vector2(place) * CELL
	return {"origin": corner, "cols": c, "rows": r, "cells": cells, "holes": holes,
		"rewards": [corner + Vector2(c, r) * CELL * 0.5], "reserve": reserve}


## A route over every cell once, stepping only between side-by-side cells,
## starting from a cell on the grid's edge (where a climber can step on).
## A depth-first search that tries the most cornered cell first (Warnsdorff)
## and gives up after SEARCH_LIMIT steps. Returns the route, or [].
static func hamilton_path(cells: Array, c: int, r: int) -> Array:
	var set := {}
	for t in cells:
		set[t] = true
	# A grid's squares alternate like a chessboard: a route over all of them
	# needs the two colours within one of each other.
	var black := 0
	for t in cells:
		black += (t.x + t.y) % 2
	if absi(cells.size() - 2 * black) > 1:
		return []
	var budget := [SEARCH_LIMIT]
	for start in cells:
		if start.x != 0 and start.y != 0 and start.x != c - 1 and start.y != r - 1:
			continue
		var path: Array = [start]
		var used := {start: true}
		if _dfs(set, path, used, budget):
			return path
		if budget[0] <= 0:
			return []
	return []


static func _dfs(set: Dictionary, path: Array, used: Dictionary, budget: Array) -> bool:
	if path.size() == set.size():
		return true
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	var cur: Vector2i = path[-1]
	var opts: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cur + d
		if set.has(n) and not used.has(n):
			var free := 0
			for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if set.has(n + d2) and not used.has(n + d2):
					free += 1
			opts.append([free, n])
	opts.sort_custom(func(a, b): return a[0] < b[0])
	for o in opts:
		var n: Vector2i = o[1]
		path.append(n)
		used[n] = true
		if _dfs(set, path, used, budget):
			return true
		path.pop_back()
		used.erase(n)
	return false


func _build() -> void:
	origin = spec.get("origin", Vector2.ZERO)
	cols = int(spec.get("cols", 0))
	rows_n = int(spec.get("rows", 0))
	for t in spec.get("cells", []):
		stones[t] = false
	holes = spec.get("holes", [])
	for t in holes:
		host.add_body(Rect2(origin + Vector2(t) * CELL, Vector2(CELL, CELL)))


func grid_rect() -> Rect2:
	return Rect2(origin, Vector2(cols, rows_n) * CELL)


func stone_center(t: Vector2i) -> Vector2:
	return origin + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


func lit_count() -> int:
	var n := 0
	for t in stones:
		if stones[t]:
			n += 1
	return n


func tick(delta: float) -> void:
	var p = player()
	if p == null or p.dead:
		return
	var g := Vector2i(((p.global_position - origin) / CELL).floor())
	# Phoenix Glide: stones under a gliding Flamewing feel nothing.
	if p.in_air() and p.has_bond("flamewing"):
		if stones.has(g) and lit_count() > 0 and not glided:
			main.fx_text(p.global_position + Vector2(0, -36), TEXT["glide"], Color(1.0, 0.7, 0.4))
		glided = glided or stones.has(g)
		return
	if not stones.has(g):
		if lit_count() > 0:
			off_t += delta
			if off_t >= OFF_GRACE:
				_go_dark(TEXT["dark"], false)
				last = null
		return
	off_t = 0.0
	if last != null and g == last:
		return
	if stones[g]:
		# Back on a used stone: it crumbles.
		_go_dark(TEXT["crumble"], true)
		last = g
		return
	if last != null and lit_count() > 0 and not glided and absi(g.x - last.x) + absi(g.y - last.y) != 1:
		_go_dark(TEXT["broken"], false)
		last = g
		return
	stones[g] = true
	last = g
	glided = false
	main.sfx("glint", 0.9 + 0.4 * float(lit_count()) / maxf(1.0, stones.size()), -8.0, 0.0)
	main.fx_ring(stone_center(g), _lit_color(), 26.0, 0.25, 2.0)
	if lit_count() == stones.size():
		host.solve()


func _go_dark(msg: String, hurt: bool) -> void:
	var p = player()
	for t in stones:
		stones[t] = false
	off_t = 0.0
	glided = false
	main.fx_text(p.global_position + Vector2(0, -34), msg, Color(1.0, 0.56, 0.44) if hurt else Color(0.6, 0.57, 0.65))
	if hurt:
		p.receive_attack(4.0 + float(main.floor_num), null, true)
		main.shake(5.0)
		main.sfx("slam", 0.7, -4.0, 0.0)
		main.fx_burst(p.global_position, Vector2.ZERO, Color(0.45, 0.4, 0.38), 12, 160.0)
	else:
		main.sfx("trap_click", 0.6, -8.0)


func reset() -> void:
	for t in stones:
		stones[t] = false
	last = null
	off_t = 0.0
	glided = false


func state() -> Array:
	var st := [host.solved]
	for t in stones:
		st.append(stones[t])
	return st


func spot_ok(pos: Vector2) -> bool:
	return not grid_rect().grow(30.0).has_point(pos)


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	return [{"pos": Vector2(grid_rect().get_center().x, origin.y - 18.0), "title": host.display_name().to_upper(), "lines": TEXT["rule"]}]


func _lit_color() -> Color:
	return Color(1.0, 0.6, 0.28) if spec.get("tower", "") == "wyvern" else Color(1.0, 0.89, 0.63)


func draw(ci: CanvasItem) -> void:
	var lit_col := _lit_color()
	for t in holes:
		var r := Rect2(origin + Vector2(t) * CELL, Vector2(CELL, CELL))
		ci.draw_rect(r.grow(-1.0), Color(0.16, 0.14, 0.18))
		ci.draw_rect(r.grow(-4.0), Color(0.03, 0.02, 0.04))
	for t in stones:
		var r := Rect2(origin + Vector2(t) * CELL, Vector2(CELL, CELL)).grow(-3.0)
		var lit: bool = stones[t] or host.solved
		ci.draw_rect(r.grow(1.0), Color(0.06, 0.05, 0.08))
		ci.draw_rect(r, lit_col.darkened(0.35) if lit else Color(0.27, 0.25, 0.3))
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), (lit_col if lit else Color(0.36, 0.34, 0.4)))
		# A crack or two, so they read as old stones.
		var c := r.get_center()
		var k := float((t.x * 7 + t.y * 13) % 5)
		ci.draw_line(c + Vector2(-8 + k, -6), c + Vector2(2, 1 + k * 0.5), Color(0, 0, 0, 0.35), 1.2)
		ci.draw_line(c + Vector2(2, 1 + k * 0.5), c + Vector2(9, 4 - k), Color(0, 0, 0, 0.3), 1.0)


## Lit stones glow through the darkness.
func draw_over(ci: CanvasItem, _t: float) -> void:
	var col := _lit_color()
	var k := 0.28
	for t in stones:
		if stones[t] or host.solved:
			var r := Rect2(origin + Vector2(t) * CELL, Vector2(CELL, CELL)).grow(-6.0)
			ci.draw_rect(r, Color(col.r * k, col.g * k, col.b * k))


func draw_glow(ci: CanvasItem, t: float) -> void:
	if host.solved or not host.awake or lit_count() > 0:
		return
	# Unlit and waiting: the edge stones you may start from shimmer faintly.
	var a := 0.18 + 0.1 * sin(t * 2.0)
	ci.draw_rect(grid_rect().grow(2.0), Color(1.0, 0.85, 0.55, a), false, 1.5)


func lights() -> Array:
	var n := lit_count()
	if n == 0 and not host.solved:
		return []
	var k := 1.0 if host.solved else float(n) / maxf(1.0, stones.size())
	return [[grid_rect().get_center(), 120.0 + 60.0 * k, _lit_color(), 0.35 + 0.35 * k, 0.12 * k]]
