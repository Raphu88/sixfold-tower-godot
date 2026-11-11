extends "res://scripts/puzzles/base.gd"
## THE HALL OF PEDESTALS (the web version's memory puzzle): the gallery
## holds a row of stone pedestals, each carved with a SIGN, and no order is
## given there. The order is kept in MURALS: stone tablets set into the
## north walls of OTHER rooms of the floor, each showing a numeral and a
## sign. Find them, remember them, then come back and light the pedestals
## (strike or shoot them) in the murals' order.
##   the right next pedestal  it lights and stays lit
##   any other                FAILURE: the pedestals go dark and the beast
##                            sends hunters; once they're beaten, try again
##                            (the murals don't change)
##   tier 1: three signs
##   tier 2: four signs
##   tier 3: four signs, and a fifth pedestal whose sign no mural shows
## The floor plan lays the murals once the floor's rooms are known
## (floors.gd calls place_murals): never in the gallery, never behind a
## locked door, never by a doorway or the torch; each in a different room
## (a floor without rooms enough is planned again). The gallery's panel counts the murals seen.

const Rooms := preload("res://scripts/rooms.gd")

const NAME := "The Hall of Pedestals"
static var NAMES := {"firebird": "The Remembered Fires"}
static var TEXT := {
	"rule": ["Light them in the order the murals keep.", "The murals hang in other rooms."],
	"found": "Murals found: %d of %d",
	"quiet": "The pedestals stay cold while blood is spilled.",
	"seen": "A mural: %d of %d found",
	"wrong": "The pedestals go dark. Something stirs.",
	# The signs (ids are drawn by draw_sign; names are for the Archive and later use).
	"signs": {"sun": "the Sun", "moon": "the Moon", "eye": "the Eye", "wave": "the Wave",
		"tree": "the Tree", "star": "the Star", "key": "the Key", "crown": "the Crown"},
}
const BREAKS := {}
const SEAL_FROM := 99  # never: the murals are elsewhere
const MODES := ["quiet", "pressure"]
const SIGNS := ["sun", "moon", "eye", "wave", "tree", "star", "key", "crown"]
## By tier: [signs in the order, pedestals no mural shows].
const COUNT := {1: [3, 0], 2: [4, 0], 3: [4, 1]}
## A strike's reach on a pedestal, and how near a mural counts as seen.
const PED_R := 15.0
const SEE := 300.0
const LIT := Color(1.0, 0.72, 0.36)
const CARVE := Color(0.72, 0.64, 0.5)

var pedestals: Array = []  # {pos, sign, lit}
var order: Array = []  # signs, as the murals number them
var murals: Array = []  # {pos (the tablet's middle), sign, n, room (Rect2), seen}
var lit_n := 0


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	var cnt: Array = COUNT.get(tier, COUNT[1])
	var n: int = int(cnt[0]) + int(cnt[1])
	var gap := 2
	var span := (n - 1) * gap
	# A row across the room, below the middle (the rules hang above it).
	for dy in [1, 0, 2]:
		var y: int = h / 2 + dy
		var x0: int = (w - 1 - span) / 2
		if x0 < 1 or x0 + span > w - 2:
			return {}
		var ok := y + 1 < h
		for k in n:
			for yy in range(y - 1, y + 2):
				var t := Vector2i(x0 + k * gap, yy)
				ok = ok and open_tile(ctx, t) and not reserved(ctx, t)
		if not ok:
			continue
		var signs: Array = SIGNS.duplicate()
		signs.shuffle()
		var used: Array = signs.slice(0, n)
		var ord: Array = used.slice(0, int(cnt[0]))
		var shown: Array = used.duplicate()
		shown.shuffle()  # (the pedestals stand in no particular order)
		var peds: Array = []
		var reserve: Array = []
		for k in n:
			var t := Vector2i(x0 + k * gap, y)
			peds.append({"pos": tile_center(rect, t), "sign": shown[k]})
			for yy in range(y - 1, y + 2):
				for xx in range(t.x - 1, t.x + 2):
					reserve.append(Vector2i(xx, yy))
		return {"pedestals": peds, "order": ord, "rewards": [tile_center(rect, Vector2i(w / 2, y - 2))], "reserve": reserve}
	return {}


## Lays the murals for a spec in the floor's other rooms (floors.gd, once
## the rooms, doors and torches are known). Returns the spec with
## "murals", or {} if they won't fit (then the floor is planned again).
## `infos`: the floor plan's rooms; `gi` the gallery's index; `torches`
## narrow rects (one per room); `doors` the plan's doors (locked ones say so).
static func place_murals(spec: Dictionary, infos: Array, gi: int, torches: Array, doors: Array) -> Dictionary:
	var order: Array = spec.get("order", [])
	var locked := {}
	for d in doors:
		if String(d.get("lock", "")) != "":
			locked[int(d["room"])] = true
	var rooms: Array = []
	for i in infos.size():
		if i != gi and not locked.has(i):
			rooms.append(i)
	rooms.shuffle()
	var spots := {}  # room index -> columns free for a tablet
	for i in rooms:
		var info: Dictionary = infos[i]
		var rows: Array = info["rows"]
		var torch_col := -99
		if i < torches.size():
			torch_col = int(floor((torches[i].get_center().x - info["rect"].position.x) / CELL))
		var cols: Array = []
		for c in range(1, String(rows[0]).length() - 1):
			if absi(c - torch_col) <= 1:
				continue
			var ok := true
			for dc in [-1, 0, 1]:
				ok = ok and Rooms.open_at(rows, c + dc, 0) and not info["reserved"].has(Vector2i(c + dc, 0))
			if ok and Rooms.open_at(rows, c, 1):
				cols.append(c)
		cols.shuffle()
		if not cols.is_empty():
			spots[i] = cols
	var with_room: Array = rooms.filter(func(i): return spots.has(i))
	if with_room.size() < order.size():
		return {}  # (each mural in a room of its own: else the floor is planned again)
	var out: Array = []
	for k in order.size():
		var i: int = with_room[k % with_room.size()]
		var cols: Array = spots[i]
		var pick := -1
		for c in cols:
			if out.all(func(m): return m["room_i"] != i or absi(int(m["col"]) - int(c)) >= 3):
				pick = c
				break
		if pick < 0:
			return {}
		var rect: Rect2 = infos[i]["rect"]
		out.append({"pos": Vector2(rect.position.x + (pick + 0.5) * CELL, rect.position.y - 16.0), "sign": order[k], "n": k + 1,
			"room": rect, "room_i": i, "col": pick})
	var s := spec.duplicate()
	s["murals"] = out
	return s


func _build() -> void:
	for q in spec.get("pedestals", []):
		pedestals.append({"pos": q["pos"], "sign": q["sign"], "lit": false})
		host.add_round_body(q["pos"], 13.0)
	order = spec.get("order", [])
	for m in spec.get("murals", []):
		murals.append({"pos": m["pos"], "sign": m["sign"], "n": m["n"], "room": m["room"], "seen": false})
		host.add_light(m["pos"] + Vector2(0, 24), 120.0, Color(1.0, 0.85, 0.6), 0.55, 0.08)


func found() -> int:
	return murals.filter(func(m): return m["seen"]).size()


func tick(_delta: float) -> void:
	pass


## Murals are noticed even while the hall sleeps (the host only ticks an
## awake puzzle; it calls watch every frame).
func watch(_delta: float) -> void:
	var p = player()
	if p == null or p.dead:
		return
	for m in murals:
		if m["seen"] or not m["room"].has_point(p.global_position):
			continue
		if p.global_position.distance_to(m["pos"]) < SEE and main.clear_line(p.global_position, m["pos"] + Vector2(0, 30)):
			m["seen"] = true
			main.fx_text(m["pos"] + Vector2(0, 40), TEXT["seen"] % [found(), murals.size()], Color(1.0, 0.85, 0.6))
			main.sfx("glint", 0.9, -6.0, 0.0)
			main.tip("puzzle_memory")  # (it may be found before the hall)


## Lights a pedestal (a strike or an arrow). True if it was the next.
func light(q: Dictionary) -> bool:
	if q["lit"] or host.solved or host.locked or not host.awake:
		return false
	if lit_n < order.size() and q["sign"] == order[lit_n]:
		q["lit"] = true
		lit_n += 1
		main.sfx("pedestal", 0.9 + 0.08 * lit_n, 0.0, 0.0)
		main.fx_burst(q["pos"] + Vector2(0, -10), Vector2.UP, LIT, 10, 120.0)
		if lit_n >= order.size():
			host.solve()
		return true
	for o in pedestals:
		o["lit"] = false
	lit_n = 0
	host.fail(TEXT["wrong"])
	return false


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	# The nearest pedestal in the swing (one at a time: an order puzzle).
	var best = null
	var best_d := INF
	for q in pedestals:
		var d: float = from.distance_to(q["pos"])
		if d < best_d and not q["lit"] and in_swing(from, dir, q["pos"], reach, arc_deg):
			best_d = d
			best = q
	if best == null:
		return 0
	light(best)
	return 1


func shot(pos: Vector2) -> bool:
	for q in pedestals:
		if pos.distance_to(q["pos"]) < PED_R + 2.0:
			light(q)
			return true
	return false


func reset() -> void:
	for q in pedestals:
		q["lit"] = false
	lit_n = 0


func state() -> Array:
	var st := [lit_n, found()]
	return st


func aim_points() -> Array:
	var out: Array = []
	for q in pedestals:
		if not q["lit"]:
			out.append(q["pos"])
	return out


func spot_ok(pos: Vector2) -> bool:
	for q in pedestals:
		if q["pos"].distance_to(pos) < 50.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	var lines: Array = TEXT["rule"].duplicate()
	lines.append(TEXT["found"] % [found(), murals.size()])
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": lines}]


func lights() -> Array:
	var out: Array = []
	for q in pedestals:
		if q["lit"] or host.solved:
			out.append([q["pos"] + Vector2(0, -8), 90.0, LIT, 0.6, 0.15])
	return out


## A sign, centred on `c`, `s` across (half-size), in strokes of `col`.
static func draw_sign(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, wd := 2.0) -> void:
	match id:
		"sun":
			ci.draw_arc(c, s * 0.45, 0.0, TAU, 16, col, wd)
			for k in 8:
				var v := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + v * s * 0.65, c + v * s, col, wd)
		"moon":
			ci.draw_arc(c, s * 0.85, PI * 0.35, PI * 1.65, 18, col, wd)
			ci.draw_arc(c + Vector2(-s * 0.35, 0), s * 0.62, PI * 0.25, PI * 1.75, 16, col, wd)
		"eye":
			var pts := PackedVector2Array()
			for i in 9:
				var a := PI * float(i) / 8.0
				pts.append(c + Vector2(cos(a) * s, -sin(a) * s * 0.55))
			for i in range(1, 8):
				var a := PI * float(i) / 8.0
				pts.append(c + Vector2(-cos(a) * s, sin(a) * s * 0.55))
			pts.append(pts[0])
			ci.draw_polyline(pts, col, wd)
			ci.draw_circle(c, s * 0.28, col)
		"wave":
			for row in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var f := float(i) / 8.0
					pts.append(c + Vector2(lerpf(-s, s, f), (row - 0.5) * s * 0.8 + sin(f * TAU) * s * 0.25))
				ci.draw_polyline(pts, col, wd)
		"tree":
			ci.draw_line(c + Vector2(0, s), c + Vector2(0, -s * 0.2), col, wd)
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(-s * 0.7, -s * 0.9), col, wd)
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(s * 0.7, -s * 0.9), col, wd)
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(0, -s), col, wd)
			ci.draw_line(c + Vector2(0, s * 0.3), c + Vector2(s * 0.5, -s * 0.1), col, wd)
		"star":
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * float(i * 2 % 5) / 5.0) * s)
			ci.draw_polyline(pts, col, wd)
		"key":
			ci.draw_arc(c + Vector2(-s * 0.5, 0), s * 0.38, 0.0, TAU, 14, col, wd)
			ci.draw_line(c + Vector2(-s * 0.12, 0), c + Vector2(s, 0), col, wd)
			ci.draw_line(c + Vector2(s * 0.55, 0), c + Vector2(s * 0.55, s * 0.4), col, wd)
			ci.draw_line(c + Vector2(s * 0.9, 0), c + Vector2(s * 0.9, s * 0.45), col, wd)
		"crown":
			var pts := PackedVector2Array([c + Vector2(-s, s * 0.6), c + Vector2(-s, -s * 0.4), c + Vector2(-s * 0.5, s * 0.1),
				c + Vector2(0, -s * 0.7), c + Vector2(s * 0.5, s * 0.1), c + Vector2(s, -s * 0.4), c + Vector2(s, s * 0.6), c + Vector2(-s, s * 0.6)])
			ci.draw_polyline(pts, col, wd)
		_:
			ci.draw_arc(c, s * 0.7, 0.0, TAU, 14, col, wd)


## A numeral (1 to 4) in strokes, centred on `c`, `h` tall.
static func draw_numeral(ci: CanvasItem, n: int, c: Vector2, h: float, col: Color, wd := 2.0) -> void:
	var marks: Array = [["I"], ["I", "I"], ["I", "I", "I"], ["I", "V"]][clampi(n - 1, 0, 3)]
	var step := h * 0.45
	var x := c.x - step * (marks.size() - 1) * 0.5
	for m in marks:
		if m == "I":
			ci.draw_line(Vector2(x, c.y - h * 0.5), Vector2(x, c.y + h * 0.5), col, wd)
		else:
			ci.draw_line(Vector2(x - h * 0.28, c.y - h * 0.5), Vector2(x, c.y + h * 0.5), col, wd)
			ci.draw_line(Vector2(x + h * 0.28, c.y - h * 0.5), Vector2(x, c.y + h * 0.5), col, wd)
		x += step


func draw(ci: CanvasItem) -> void:
	var dark := Color(0.1, 0.09, 0.12)
	# The murals: stone tablets set in the wall, a numeral over a sign.
	for m in murals:
		var c: Vector2 = m["pos"]
		var r := Rect2(c - Vector2(19, 21), Vector2(38, 42))
		ci.draw_rect(r.grow(2.0), dark)
		ci.draw_rect(r, Color(0.5, 0.43, 0.37))
		ci.draw_rect(r.grow(-3.0), Color(0.3, 0.26, 0.24))
		var ink := Color(1.0, 0.86, 0.55)
		draw_numeral(ci, int(m["n"]), c + Vector2(0, -10), 11.0, ink, 2.6)
		ci.draw_line(c + Vector2(-12, -2), c + Vector2(12, -2), Color(ink, 0.4), 1.0)
		draw_sign(ci, String(m["sign"]), c + Vector2(0, 9), 9.5, ink, 2.0)
	# The pedestals: round-topped stone columns, the sign carved on top.
	for q in pedestals:
		var c: Vector2 = q["pos"]
		var on: bool = q["lit"] or host.solved
		Draw.shadow(ci, c + Vector2(0, 10), 15.0)
		ci.draw_rect(Rect2(c + Vector2(-13, -6), Vector2(26, 18)), dark)
		ci.draw_rect(Rect2(c + Vector2(-12, -5), Vector2(24, 16)), Color(0.36, 0.33, 0.38))
		ci.draw_circle(c + Vector2(0, -6), 14.0, dark)
		ci.draw_circle(c + Vector2(0, -6), 12.5, Color(0.48, 0.44, 0.5))
		draw_sign(ci, String(q["sign"]), c + Vector2(0, -6), 8.0, LIT if on else CARVE, 1.8)


func draw_glow(ci: CanvasItem, t: float) -> void:
	# A lit pedestal burns.
	for q in pedestals:
		if not (q["lit"] or host.solved):
			continue
		var c: Vector2 = q["pos"] + Vector2(0, -22)
		var f := 1.0 + 0.15 * sin(t * 9.0 + c.x)
		ci.draw_circle(c, 6.0 * f, Color(1.0, 0.55, 0.2, 0.8))
		ci.draw_circle(c + Vector2(0, 1), 3.5 * f, Color(1.0, 0.9, 0.6))
	if not host.solved and host.awake and lit_n == 0:
		for q in pedestals:
			ci.draw_arc(q["pos"] + Vector2(0, -6), 16.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.55, 0.15 + 0.1 * sin(t * 2.0 + q["pos"].x)), 1.2)


## Lit signs glow through the darkness.
func draw_over(ci: CanvasItem, _t: float) -> void:
	for q in pedestals:
		if q["lit"] or host.solved:
			draw_sign(ci, String(q["sign"]), q["pos"] + Vector2(0, -6), 8.0, Color(0.5, 0.35, 0.15), 1.8)
