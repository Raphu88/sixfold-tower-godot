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
