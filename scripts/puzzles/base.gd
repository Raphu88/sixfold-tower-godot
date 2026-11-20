extends RefCounted
## What every kind of puzzle shares (puzzle.gd is the HOST that runs one).
## Each kind is its own script in this folder, extending this one, with:
##
##   static func make(rect, floor_num, tier, ctx) -> Dictionary
##       Builds a puzzle for a room: `rect` is the room (world px), `ctx`
##       holds what the floor plan knows about it: "rows" (the room's text
##       grid, rooms.gd), "reserved" (local tiles kept clear: doorways),
##       "features" (a hand-made room's eyes, plates...) and "tower".
##       Returns {} if it can't make one that its solver accepts.
##   setup(spec)        builds the objects (bodies etc.) from that spec
##   tick(delta)        runs while the puzzle is awake (see puzzle.gd: modes)
##   watch(delta)       runs every frame until solved, awake or not
##   draw(ci)           the stone parts, redrawn only when state() changes
##   draw_glow(ci, t)   what pulses, redrawn 30 times a second while unsolved
##   draw_over(ci, t)   glow drawn over the darkness (only near the climber)
##   strike(from, dir, reach, arc) -> hits    a swing of the climber's weapon
##   shot(pos) -> bool  a climber's arrow at pos: true if it stops there
##   reset()            back to the start (after a failure's ambush)
##   aim_points()       what auto-aim may point at when no monster is near
##   panels()           the rule text drawn in the world: [{pos, lines, ...}]
##   lights()           [[pos, reach, colour, strength, glow], ...] each frame
##   spot_ok(pos)       whether a monster may appear here (ambush, pressure)
##   steer(p, delta) -> bool   takes over the climber's movement this frame
##                      (the Ice Hall's slide); false to leave it alone
##   no_footing(pos, leap) -> bool   no roll (or, with leap, no jump) here
##   footing_note(pos)  says why, when the climber tries anyway
##   offer(kind, pos, how) -> bool   an essence offered near the puzzle: a
##                      bond's spell ("bond") or an item ("item") of that kind
##
## And these constants (names and text are data: edit freely):
##   NAME      the puzzle's name; NAMES (optional) per tower
##   TEXT      everything it says ("rule" is the rule panel's lines)
##   BREAKS    bond id -> the shortcut that bond gives (never required)
##   SEAL_FROM the first tier whose room closes behind you (99: never)
##   MODES     which of "quiet" and "pressure" it takes (puzzle.gd)

const CELL := 40.0
const Draw := preload("res://scripts/draw_util.gd")

var host  # puzzle.gd
var main
var spec := {}
var tier := 1
var room := Rect2()


func setup(s: Dictionary) -> void:
	spec = s
	tier = int(s.get("tier", 1))
	room = s.get("room", Rect2())
	_build()


func _build() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func watch(_delta: float) -> void:
	pass


func state() -> Array:
	return []


func draw(_ci: CanvasItem) -> void:
	pass


func draw_glow(_ci: CanvasItem, _t: float) -> void:
	pass


func draw_over(_ci: CanvasItem, _t: float) -> void:
	pass


func strike(_from: Vector2, _dir: Vector2, _reach: float, _arc_deg: float) -> int:
	return 0


func shot(_pos: Vector2) -> bool:
	return false


func reset() -> void:
	pass


func aim_points() -> Array:
	return []


func panels() -> Array:
	return []


func lights() -> Array:
	return []


func spot_ok(_pos: Vector2) -> bool:
	return true


func steer(_p, _delta: float) -> bool:
	return false


func no_footing(_pos: Vector2, _leap: bool) -> bool:
	return false


func footing_note(_pos: Vector2) -> void:
	pass


func offer(_kind: String, _pos: Vector2, _how: String) -> bool:
	return false


# --- helpers ---------------------------------------------------------------------

## The world centre of a room's local tile.
static func tile_center(rect: Rect2, t: Vector2i) -> Vector2:
	return rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


## Whether a room's local tile is plain open floor (and not kept clear).
static func open_tile(ctx: Dictionary, t: Vector2i) -> bool:
	var rows: Array = ctx.get("rows", [])
	if t.y < 0 or t.y >= rows.size() or t.x < 0 or t.x >= String(rows[0]).length():
		return false
	var ch := String(rows[t.y])[t.x]
	return ch == "." or ch == "M"


static func reserved(ctx: Dictionary, t: Vector2i) -> bool:
	return ctx.get("reserved", {}).has(t)


## Where a block of `size` local tiles fits, centred in the room as near as
## it can be, with `margin` tiles of open floor round it, every tile open and
## none kept clear: its top-left tile, or Vector2i(-1, -1) if it won't fit.
## (The lanterns, the bells, the crucible's floor and the pods use it.)
static func fit_block(ctx: Dictionary, size: Vector2i, margin := 1) -> Vector2i:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return Vector2i(-1, -1)
	var w := String(rows[0]).length()
	var h := rows.size()
	var mid := Vector2i((w - size.x) / 2, (h - size.y) / 2)
	for shift in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var o: Vector2i = mid + shift
		if o.x - margin < 0 or o.y - margin < 0 or o.x + size.x + margin > w or o.y + size.y + margin > h:
			continue
		var ok := true
		for y in range(o.y - margin, o.y + size.y + margin):
			for x in range(o.x - margin, o.x + size.x + margin):
				var t := Vector2i(x, y)
				ok = ok and open_tile(ctx, t) and not reserved(ctx, t)
				if not ok:
					break
			if not ok:
				break
		if ok:
			return o
	return Vector2i(-1, -1)


## The local tiles of a block and its margin (a spec's "reserve").
static func block_tiles(o: Vector2i, size: Vector2i, margin := 1) -> Array:
	var out: Array = []
	for y in range(o.y - margin, o.y + size.y + margin):
		for x in range(o.x - margin, o.x + size.x + margin):
			out.append(Vector2i(x, y))
	return out


## The nearest of `list` (dictionaries with "pos") in a swing, or null.
func nearest_in_swing(list: Array, from: Vector2, dir: Vector2, reach: float, arc_deg: float, ok := Callable()):
	var best = null
	var best_d := INF
	for q in list:
		if ok.is_valid() and not ok.call(q):
			continue
		var d: float = from.distance_to(q["pos"])
		if d < best_d and in_swing(from, dir, q["pos"], reach, arc_deg):
			best_d = d
			best = q
	return best


## Whether a swing from `from` toward `dir` reaches `at`.
func in_swing(from: Vector2, dir: Vector2, at: Vector2, reach: float, arc_deg: float, slack := 18.0) -> bool:
	var to := at - from
	if to.length() > reach + slack:
		return false
	if to.length() > 26.0 and absf(dir.angle_to(to)) > deg_to_rad(arc_deg):
		return false
	return main.clear_line(from, at)


func player():
	return main.player if main != null else null


func has_bond(id: String) -> bool:
	var p = player()
	return p != null and p.has_bond(id)


## The player is in the puzzle's room.
func player_in_room(grow := 0.0) -> bool:
	var p = player()
	return p != null and room.grow(grow).has_point(p.global_position)


func near_player(pos: Vector2, d: float) -> bool:
	var p = player()
	return p != null and p.global_position.distance_to(pos) < d
