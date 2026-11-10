extends "res://scripts/puzzles/base.gd"
## BEAM AND MIRRORS (the web version's mirrors puzzle): a lamp throws a beam
## of light across the room's tiles; mirrors stand where it must turn, and
## the beam must reach the sigil. The generator walks a path with M turns
## (2-4 tiles between turns, never crossing itself, only over open floor),
## puts a mirror at each turn, then scrambles them, making sure the beam
## doesn't already reach the sigil. trace() follows the beam tile by tile;
## walls stop it. A solver tries every way the mirrors can face to confirm
## the beam can always be brought home.
##   tier 1: 3 mirrors
##   tier 2: 4 mirrors and a decoy (a mirror the beam doesn't need)
##   tier 3: 5 mirrors, two decoys, and one mirror fixed in place (grey)
## Strike or shoot a mirror to turn it a quarter. Hold the beam on the sigil
## for HOLD seconds to solve it.

const NAME := "Beam and Mirrors"
static var NAMES := {"gryphon": "Wind Mirrors"}
static var TEXT := {
	"rule": ["Strike or shoot a mirror to turn it.", "Carry the light to the sigil."],
	"fixed": "The grey mirror will not turn.",
	"quiet": "The lamp will not wake while blood is spilled.",
	"wind": "The wind turns the mirror",
}
const BREAKS := {"windwalker": "Crosswind: the wall of wind turns every mirror it passes."}
const SEAL_FROM := 3
const MODES := ["quiet", "pressure"]
## Mirrors by tier, decoys by tier.
const MIRRORS := {1: 3, 2: 4, 3: 5}
const DECOYS := {1: 0, 2: 1, 3: 2}
## The beam must rest on the sigil this long.
const HOLD := 0.6
## A mirror can't be turned again for this long (one swing, one turn).
const TURN_CD := 0.3
const BEAM := Color(0.75, 0.9, 1.0)
const BEAM_HIT := Color(1.0, 0.94, 0.7)

var mirrors: Array = []  # {pos, tile, o ("/" or "\\"), fixed, cd}
var emitter := Vector2.ZERO
var receiver := Vector2.ZERO
var em_tile := Vector2i.ZERO
var tg_tile := Vector2i.ZERO
var dir := Vector2i.RIGHT
var tile_lo := Vector2i.ZERO  # the room's tiles in the floor's grid
var tile_hi := Vector2i.ZERO
var beam: Array = []  # world points of the beam, as last traced
var hit := false
var hit_t := 0.0
var light_id := -1


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	var x0 := 1
	var x1 := w - 2
	var y0 := 1
	var y1 := h - 2
	var m: int = MIRRORS.get(tier, 3)
	var blocked := func(t: Vector2i) -> bool: return not open_tile(ctx, t)
	for tries in 600:
		var side := randi() % 4
		var e := Vector2i.ZERO
		var d := Vector2i.ZERO
		match side:
			0:
				e = Vector2i(x0, randi_range(y0 + 1, y1 - 1))
				d = Vector2i.RIGHT
			1:
				e = Vector2i(x1, randi_range(y0 + 1, y1 - 1))
				d = Vector2i.LEFT
			2:
				e = Vector2i(randi_range(x0 + 1, x1 - 1), y0)
				d = Vector2i.DOWN
			_:
				e = Vector2i(randi_range(x0 + 1, x1 - 1), y1)
				d = Vector2i.UP
		if not open_tile(ctx, e) or reserved(ctx, e):
			continue
		var cur := e
		var cd := d
		var seen := {e: true}
		var mir: Array = []  # [tile, o]
		var ok := true
		for k in m + 1:
			var length := randi_range(2, 4)
			for s in length:
				cur += cd
				if cur.x < x0 or cur.x > x1 or cur.y < y0 or cur.y > y1 or seen.has(cur) or not open_tile(ctx, cur):
					ok = false
					break
				seen[cur] = true
			if not ok:
				break
			if k < m:
				if reserved(ctx, cur):
					ok = false
					break
				var opts: Array = [Vector2i(0, 1), Vector2i(0, -1)] if cd.x != 0 else [Vector2i(1, 0), Vector2i(-1, 0)]
				var nd: Vector2i = opts[randi() % 2]
				var o := "/" if (nd == Vector2i(-cd.y, -cd.x)) else "\\"
				mir.append([cur, o])
				cd = nd
		if not ok or mir.size() < m or reserved(ctx, cur):
			continue
		var tg := cur
		# Decoys: mirrors off the path, beside it (so the beam may meet them
		# while the mirrors are wrong).
		var decoys: Array = []
		var path_tiles: Array = seen.keys()
		path_tiles.shuffle()
		for pt in path_tiles:
			if decoys.size() >= int(DECOYS.get(tier, 0)):
				break
			for nd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var t: Vector2i = pt + nd
				if t.x < x0 or t.x > x1 or t.y < y0 or t.y > y1 or seen.has(t) or not open_tile(ctx, t) or reserved(ctx, t):
					continue
				var near_other := false
				for q in mir + decoys:
					near_other = near_other or (absi(q[0].x - t.x) <= 1 and absi(q[0].y - t.y) <= 1)
				if near_other or t == tg or (absi(t.x - e.x) <= 1 and absi(t.y - e.y) <= 1):
					continue
				decoys.append([t, "/" if randf() < 0.5 else "\\"])
				break
		if decoys.size() < int(DECOYS.get(tier, 0)):
			continue
		var all: Array = []
		for q in mir:
			all.append({"tile": q[0], "o": q[1], "fixed": false, "decoy": false})
		for q in decoys:
			all.append({"tile": q[0], "o": q[1], "fixed": false, "decoy": true})
		if tier >= 3:
			all[randi() % mir.size()]["fixed"] = true
		var answer: Array = all.map(func(q): return q["o"])
		# Scramble, until the beam no longer reaches the sigil.
		var scrambled := false
		for s in 12:
			for q in all:
				if not q["fixed"] and randf() < 0.7:
					q["o"] = flip(q["o"])
			if not trace(e, d, tg, all, blocked)["hit"]:
				scrambled = true
				break
		if not scrambled:
			continue
		if solve(e, d, tg, all, blocked).is_empty():
			continue  # (never: the path it was built on works)
		var reserve: Array = path_tiles.duplicate()
		for q in all:
			reserve.append(q["tile"])
		var spec_m: Array = []
		for i in all.size():
			var q: Dictionary = all[i]
			spec_m.append({"pos": tile_center(rect, q["tile"]), "o": q["o"], "fixed": q["fixed"], "decoy": q["decoy"], "answer": answer[i]})
		return {"emitter": tile_center(rect, e), "dir": d, "receiver": tile_center(rect, tg), "mirrors": spec_m,
			"rewards": [tile_center(rect, tg)], "reserve": reserve}
	return {}


static func flip(o: String) -> String:
	return "\\" if o == "/" else "/"


## Follows the beam from the lamp tile by tile: {tiles (where it turned or
## stopped), hit}. `mirrors`: [{tile, o}], `blocked`: tile -> bool.
static func trace(e: Vector2i, d: Vector2i, tg: Vector2i, mirrors: Array, blocked: Callable) -> Dictionary:
	var at := {}
	for q in mirrors:
		at[q["tile"]] = q
	var cur := e
	var pts: Array = [e]
	for s in 80:
		var nxt: Vector2i = cur + d
		if blocked.call(nxt):
			pts.append(cur)
			return {"tiles": pts, "hit": false, "end": d}
		cur = nxt
		if cur == tg:
			pts.append(cur)
			return {"tiles": pts, "hit": true, "end": d}
		if at.has(cur):
			pts.append(cur)
			var o: String = at[cur]["o"]
			d = Vector2i(-d.y, -d.x) if o == "/" else Vector2i(d.y, d.x)
	pts.append(cur)
	return {"tiles": pts, "hit": false, "end": d}


## The solver: tries every way the turnable mirrors can face; returns the
## first that brings the beam home ([o per mirror]), or [] if none does.
static func solve(e: Vector2i, d: Vector2i, tg: Vector2i, mirrors: Array, blocked: Callable) -> Array:
	var free: Array = []
	for i in mirrors.size():
		if not mirrors[i]["fixed"]:
			free.append(i)
	var attempt: Array = mirrors.map(func(q): return q.duplicate())
	for mask in 1 << free.size():
		for k in free.size():
			attempt[free[k]]["o"] = "\\" if (mask >> k) & 1 else "/"
		if trace(e, d, tg, attempt, blocked)["hit"]:
			return attempt.map(func(q): return q["o"])
	return []


func _build() -> void:
	emitter = spec.get("emitter", Vector2.ZERO)
	receiver = spec.get("receiver", Vector2.ZERO)
	dir = spec.get("dir", Vector2i.RIGHT)
	em_tile = main._tile_of(emitter)
	tg_tile = main._tile_of(receiver)
	tile_lo = main._tile_of(room.position + Vector2(1, 1))
	tile_hi = main._tile_of(room.end - Vector2(1, 1))
	for q in spec.get("mirrors", []):
		mirrors.append({"pos": q["pos"], "tile": main._tile_of(q["pos"]), "o": q["o"], "fixed": q["fixed"], "decoy": q.get("decoy", false), "cd": 0.0})
		host.add_round_body(q["pos"], 12.0)
	host.add_round_body(emitter, 12.0)
	_retrace()


func _blocked(t: Vector2i) -> bool:
	return t.x < tile_lo.x or t.y < tile_lo.y or t.x > tile_hi.x or t.y > tile_hi.y or main._is_solid_tile(t.x, t.y)


func _retrace() -> void:
	var tr := trace(em_tile, dir, tg_tile, mirrors, _blocked)
	hit = tr["hit"]
	beam.clear()
	var tiles: Array = tr["tiles"]
	for i in tiles.size():
		var p: Vector2 = main.room.position + (Vector2(tiles[i]) + Vector2(0.5, 0.5)) * CELL
		if i == tiles.size() - 1 and not hit:
			p += Vector2(tr["end"]) * CELL * 0.45  # (the beam runs on to the wall's face)
		beam.append(p)


## Turns a mirror a quarter. Returns whether it turned.
func turn(m: Dictionary, quiet := false) -> bool:
	if m["fixed"] or m["cd"] > 0.0 or host.solved or not host.awake:
		return false
	m["o"] = flip(m["o"])
	m["cd"] = TURN_CD
	_retrace()
	if not quiet:
		main.sfx("trap_click", 1.3, -6.0)
	main.fx_burst(m["pos"], Vector2.ZERO, Color(0.9, 0.95, 1.0), 6, 90.0)
	return true


func tick(delta: float) -> void:
	for m in mirrors:
		m["cd"] = maxf(0.0, m["cd"] - delta)
	# Windwalker's Crosswind turns every mirror its wall of wind passes.
	for wall in main.walls:
		if wall.get("turned_mirrors", false):
			continue
		wall["turned_mirrors"] = true
		for m in mirrors:
			var on_seg := Geometry2D.get_closest_point_to_segment(m["pos"], wall["a"], wall["b"])
			if on_seg.distance_to(m["pos"]) < 34.0 and turn(m, true):
				main.fx_text(m["pos"] + Vector2(0, -26), TEXT["wind"], Color(0.8, 0.92, 1.0))
	hit_t = hit_t + delta if hit else 0.0
	if hit and hit_t >= HOLD:
		host.solve()


func state() -> Array:
	var st := [hit]
	for m in mirrors:
		st.append(m["o"])
	return st


func reset() -> void:
	_retrace()


func strike(from: Vector2, aim: Vector2, reach: float, arc_deg: float) -> int:
	var n := 0
	for m in mirrors:
		if in_swing(from, aim, m["pos"], reach, arc_deg) and turn(m):
			n += 1
	return n


func shot(pos: Vector2) -> bool:
	for m in mirrors:
		if pos.distance_to(m["pos"]) < 16.0:
			turn(m)
			return true
	return pos.distance_to(emitter) < 14.0


func aim_points() -> Array:
	var out: Array = []
	for m in mirrors:
		if not m["fixed"]:
			out.append(m["pos"])
	return out


func spot_ok(pos: Vector2) -> bool:
	if pos.distance_to(emitter) < 50.0 or pos.distance_to(receiver) < 40.0:
		return false
	for m in mirrors:
		if m["pos"].distance_to(pos) < 50.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	var lines: Array = TEXT["rule"].duplicate()
	if mirrors.any(func(m): return m["fixed"]):
		lines.append(TEXT["fixed"])
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": lines}]


func lights() -> Array:
	var out: Array = []
	var col := BEAM_HIT if hit or host.solved else BEAM
	out.append([emitter, 90.0, col, 0.55, 0.2])
	if host.awake or host.solved:
		for i in range(1, beam.size()):
			out.append([beam[i], 70.0, col, 0.4, 0.12])
	if hit or host.solved:
		if light_id < 0 and main.lighting != null:
			light_id = host.add_light(receiver, 170.0, BEAM_HIT, 0.8, 0.3)
	elif light_id >= 0:
		host.remove_light(light_id)
		light_id = -1
	return out


func draw(ci: CanvasItem) -> void:
	var dark := Color(0.1, 0.09, 0.13)
	# The sigil: a carved ring on the floor.
	ci.draw_circle(receiver, 17.0, dark)
	ci.draw_arc(receiver, 14.0, 0.0, TAU, 28, Color(0.45, 0.6, 0.7), 2.0)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		ci.draw_line(receiver + Vector2.from_angle(a) * 6.0, receiver + Vector2.from_angle(a) * 12.0, Color(0.45, 0.6, 0.7), 2.0)
	# The lamp: a crystal on a plinth, open on the beam's side.
	Draw.shadow(ci, emitter + Vector2(0, 8), 14.0)
	ci.draw_rect(Rect2(emitter - Vector2(13, 13), Vector2(26, 26)), Color(0.28, 0.26, 0.32))
	ci.draw_rect(Rect2(emitter - Vector2(10, 10), Vector2(20, 20)), Color(0.38, 0.35, 0.42))
	ci.draw_circle(emitter + Vector2(dir) * 9.0, 4.0, Color(0.18, 0.17, 0.22))
	# The mirrors: a stone disc holding a silver pane.
	for m in mirrors:
		var c: Vector2 = m["pos"]
		Draw.shadow(ci, c + Vector2(0, 6), 13.0)
		ci.draw_circle(c, 13.0, dark)
		if m["fixed"]:
			# Fixed: bound in an iron ring, its pane dull and bolted.
			ci.draw_circle(c, 13.0, Color(0.42, 0.36, 0.28))
			ci.draw_circle(c, 10.0, Color(0.18, 0.17, 0.2))
		else:
			ci.draw_circle(c, 11.5, Color(0.3, 0.28, 0.34))
		var a := Vector2(-9, 9) if m["o"] == "/" else Vector2(-9, -9)
		var col := Color(0.88, 0.93, 0.98) if not m["fixed"] else Color(0.4, 0.39, 0.43)
		ci.draw_line(c + a + Vector2(1, 1), c - a + Vector2(1, 1), Color(0, 0, 0, 0.5), 5.0)
		ci.draw_line(c + a, c - a, col, 4.0)
		if m["fixed"]:
			for k in 4:
				ci.draw_circle(c + Vector2.from_angle(TAU * k / 4.0 + PI / 4.0) * 11.5, 1.8, Color(0.62, 0.55, 0.42))


func draw_glow(ci: CanvasItem, t: float) -> void:
	var col := BEAM_HIT if hit or host.solved else BEAM
	# The lamp's crystal and the sigil pulse.
	ci.draw_circle(emitter, 6.0 + sin(t * 4.0) * 0.8, Color(0.95, 0.98, 1.0))
	var ring := Color(1.0, 0.89, 0.63) if host.solved or hit else Color(0.62, 0.83, 0.94)
	ci.draw_arc(receiver, 15.0 + sin(t * 4.0) * 1.5, 0.0, TAU, 28, ring, 3.0)
	if not host.awake and not host.solved:
		return
	# The beam: a soft wide band under a bright core.
	if beam.size() >= 2:
		var pts := PackedVector2Array(beam)
		ci.draw_polyline(pts, Color(col, 0.22), 9.0)
		ci.draw_polyline(pts, Color(col, 0.9), 3.0)
	for m in mirrors:
		if m["cd"] > 0.0:
			ci.draw_arc(m["pos"], 16.0, 0.0, TAU, 20, Color(1, 1, 1, m["cd"] / TURN_CD), 2.0)


## The beam's core, added over the darkness so it glows.
func draw_over(ci: CanvasItem, t: float) -> void:
	if beam.size() < 2 or (not host.awake and not host.solved):
		return
	var col := BEAM_HIT if hit or host.solved else BEAM
	var k := 0.55 + 0.1 * sin(t * 6.0)
	ci.draw_polyline(PackedVector2Array(beam), Color(col.r * k, col.g * k, col.b * k), 2.5)
	ci.draw_circle(emitter, 5.0, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6))
	if hit or host.solved:
		ci.draw_circle(receiver, 9.0, Color(0.6, 0.55, 0.35))
