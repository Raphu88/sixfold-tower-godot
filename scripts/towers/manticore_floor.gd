extends Node2D
## THE MANTICORE'S SANDSTONE: what makes a floor of the Manticore's tower its
## own (floor_styles.gd names this script as the tower's "module").
##
## LAYOUT. Wide courtyards open to the sky, colonnades, and low-walled
## alleys between them (more ways between rooms than most towers), carved in
## the tower's own shapes (carve below):
##   court      an open courtyard ringed by a colonnade (pillars one tile in
##              from its walls); the walk under the colonnade is shade
##   colonnade  a long nave between two rows of pillars, shaded side aisles
##   alleys     a maze of low walls with narrow alleys between (deep shade)
##
## THE SYSTEM: SUN AND SHIFTING SAND.
##   Sun: a shaft of sunlight lies across every courtyard and nave and moves
##   slowly back and forth across it (SUN "period" seconds). Standing in it
##   you're seen from farther (SUN "sight": monsters wake to you from that
##   much farther, enemy.gd through main.sight_k). Shade (colonnade walks,
##   aisles, alleys) hides you: monsters notice you only from SHADE
##   "sight" as far, and one that's after you loses track of you (the Unseen
##   state) while you stay in the shade more than SHADE "lose" away from it.
##   Sand: soft drifts in the courts slow you a little; a burrower swims in
##   them. Sand pits (from floor SAND "pits_from") pull you slowly toward
##   the sink in their middle; reach it and the sand swallows you: it hurts,
##   and spits you out at the edge. Cracked flagstones crumble into sand
##   after you've crossed them. None of it ever walls anything off (reach.gd
##   needs nothing new: all of it can be walked).
##
## ITS TASK: "sunstones" (objectives.gd KINDS): Wake the Sun Seals. In
## different rooms a polished stone stands under a skylight, its seal set in
## the floor a few steps away. Strike the stone to turn it (an eighth of a
## turn a blow). When the moving sunlight crosses the stone it throws the
## light the way it faces: facing its seal, the seal drinks the light and
## wakes (SEAL "charge" seconds of it).
##
## ITS SCENARIO: "sinking" (scenarios.gd, themes.gd scn_sinking): The
## Sinking Court. Step onto the mark and the court's floor starts giving way
## to quicksand behind you, rolling toward the far gate. Only the old
## stones (a winding path of them, and a few more) hold. Quicksand slows you
## and drags you under: stand in it too long and it swallows you (a hit;
## you're thrown onto the nearest stone). Reach the far gate: graded by hits
## and time. Leaving the court ends it.
##
## Every number and word is in SUN, SHADE, SAND, SEAL, SINK and TEXT (the
## Data editor's "Towers" sections).

const MODULE := "res://scripts/towers/manticore_floor.gd"
const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0  # (floors.gd CELL)
const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

## The sun: the shaft's width (tiles), how long it takes to cross and come
## back (seconds), how much farther monsters notice you in it, how bright
## the open sky makes a court.
static var SUN := {"width": 3, "period": 34.0, "sight": 1.4, "sky": 0.35}
## Shade: how far monsters notice you from in it (a share), and how far one
## that's after you must be to lose you there (px).
static var SHADE := {"sight": 0.45, "lose": 170.0, "lose_t": 0.6}
## Sand: how much a drift slows you, how many drifts a floor (patches), how
## big; sand pits (from "pits_from"): how many, their reach (px), their
## pull (px a second) and slow, the sink's reach, what being swallowed
## costs (plus "swallow_per_floor" each floor); cracked flagstones: patches
## a floor, from floor "crumble_from", and how long one takes to give way.
static var SAND := {"slow": 0.85, "drifts": [4, 7], "drift_size": [4, 9], "pits": [1, 2], "pits_from": 3, "pit_r": 62.0,
	"pull": 55.0, "pit_slow": 0.65, "sink_r": 13.0, "swallow": 8.0, "swallow_per_floor": 0.8, "crumbles": [2, 3], "crumble_from": 2,
	"crumble_t": 0.5}
## Wake the Sun Seals: how long a seal must drink the light, the skylight's
## reach (px), how long its patch of sun takes to drift over the stone and
## back (seconds), how near it must be to light the stone, the least time
## between two strikes that count.
static var SEAL := {"charge": 1.2, "sun_r": 46.0, "period": 9.0, "near": 34.0, "gap": 0.25, "beam": 3}
## The Sinking Court: how fast the floor gives way after the start (tiles a
## second), the grace before the first tile goes, how fast quicksand drags
## you under (share a second), how much it slows you, the time allowed
## (the way's length at "pace" tiles a second, plus "spare"), and grades.
static var SINK := {"speed": 2.4, "grace": 1.0, "drag": 0.9, "slow": 0.5, "pace": 1.6, "spare": 6.0, "extra": 0.12,
	"dmg": 8.0, "dmg_per_floor": 0.8, "gold_hits": 0, "silver_hits": 1, "gold_share": 0.7}
static var TEXT := {
	"swallowed": "Swallowed!",
	"seen": "In the sun",
	"hidden": "In the shade",
	"seal": "The seal wakes",
	"sinking": "Keep to the stones",
	"sinking_line": "Hits %d  ·  %d s",
	"left": "You left the court",
}

const C_SAND := Color(0.86, 0.72, 0.46)
const C_SAND_DARK := Color(0.66, 0.52, 0.32)
const C_SUN := Color(1.0, 0.93, 0.68)
const C_SHADE := Color(0.08, 0.06, 0.12)
const C_STONE := Color(0.78, 0.7, 0.58)
const C_POLISH := Color(0.95, 0.92, 0.8)
const DIRS8 := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]


# --- carving the tower's own rooms (rooms.gd carve) --------------------------------

static func carve(shape: String, size: Vector2i) -> Array:
	var w := size.x
	var h := size.y
	var g: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		g.append(row)
	match shape:
		"court":
			# A colonnade one tile in from the walls, all round.
			if w >= 8 and h >= 7:
				for x in range(2, w - 2, 3):
					g[1][x] = "o"
					g[h - 2][x] = "o"
				for y in range(4, h - 3, 3):
					g[y][1] = "o"
					g[y][w - 2] = "o"
		"colonnade":
			# Two rows of pillars down the long way: a nave and two aisles.
			if w >= 8 and h >= 7:
				var horiz := w >= h
				var n := w if horiz else h
				var a := 2
				var b := (h if horiz else w) - 3
				for k in range(2, n - 2, 2):
					if horiz:
						g[a][k] = "o"
						g[b][k] = "o"
					else:
						g[k][a] = "o"
						g[k][b] = "o"
		"alleys":
			# Low walls in staggered rows, each with gaps: narrow alleys
			# winding between them, a clear walk all round the edge.
			if w >= 8 and h >= 7:
				var horiz := w >= h
				var rows_n := h if horiz else w
				var len_n := w if horiz else h
				var flip := false
				for r in range(2, rows_n - 2, 2):
					var gaps: Array = []
					var g0 := randi_range(2, maxi(2, len_n / 2 - 1)) if not flip else randi_range(len_n / 2, len_n - 3)
					gaps.append(g0)
					if len_n >= 11:
						gaps.append(randi_range(2, len_n - 3))
					for k in range(2, len_n - 2):
						if k in gaps:
							continue
						if horiz:
							g[r][k] = "#"
						else:
							g[k][r] = "#"
					flip = not flip
	var rows: Array = []
	for row in g:
		rows.append("".join(PackedStringArray(row)))
	return rows


# --- planning (floors.gd, as it finishes a plan) ---------------------------------------

static func _world(t: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


static func _tile_rect(t: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL))


static func grid_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - ORIGIN.x) / CELL)), int(floor((pos.y - ORIGIN.y) / CELL)))


## Sun shafts, shade, sand drifts, pits and cracked flagstones over the plan.
static func shape_plan(plan: Dictionary, infos: Array, links: Array, floor_num: int, _tower: Dictionary) -> void:
	var out := {"module": MODULE, "suns": [], "shade": [], "drifts": [], "pits": [], "crumbles": []}
	var themes: Array = plan["themes"]
	var shade := {}
	var sand := {}
	# Shade: the walks under the colonnades, the aisles and the alleys.
	for i in infos.size():
		var info: Dictionary = infos[i]
		var rows: Array = info["rows"]
		var size: Vector2i = info["size"]
		var at0: Vector2i = info["pos"]
		var shape := String(info.get("shape", ""))
		var th := String(themes[i])
		for y in size.y:
			for x in size.x:
				if not Rooms.open_at(rows, x, y):
					continue
				var dark := false
				match shape:
					"court":
						dark = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
					"colonnade":
						if size.x >= size.y:
							dark = y <= 1 or y >= size.y - 2
						else:
							dark = x <= 1 or x >= size.x - 2
					"alleys":
						for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
							var yy: int = y + d.y
							var xx: int = x + d.x
							if yy >= 0 and xx >= 0 and yy < size.y and xx < size.x and String(rows[yy])[xx] == "#":
								dark = true
				if dark:
					shade[at0 + Vector2i(x, y)] = true
		# The sun lies across the open rooms: courts, naves, the big hall.
		if shape in ["court", "colonnade"] or (info["role"] == "gallery" and String(info.get("puzzle", "")) == "" and not th.begins_with("hall_")):
			var r: Rect2 = info["rect"]
			var vertical := r.size.x >= r.size.y  # (a north-south band, moving east and west)
			var wpx := float(SUN["width"]) * CELL
			var lo := (r.position.x if vertical else r.position.y) + wpx * 0.5
			var hi := (r.end.x if vertical else r.end.y) - wpx * 0.5
			if hi > lo:
				out["suns"].append({"rect": r, "vertical": vertical, "lo": lo, "hi": hi, "w": wpx, "phase": randf(), "room": i})
	# Sand: drifts in open rooms (more where burrowers wait), pits, cracked flagstones.
	var open_rooms: Array = []
	for i in infos.size():
		if _fits(infos[i], String(themes[i])):
			open_rooms.append(i)
	open_rooms.shuffle()
	var n_drift := randi_range(int(SAND["drifts"][0]), int(SAND["drifts"][1]))
	for k in mini(n_drift, open_rooms.size() * 2):
		var i: int = open_rooms[k % open_rooms.size()]
		_drift(infos[i], sand, randi_range(int(SAND["drift_size"][0]), int(SAND["drift_size"][1])), Vector2i(-1, -1))
	# Burrowers start in sand: theirs, or a drift made round them.
	for m in plan["monsters"]:
		if String(m[0]) != "burrower":
			continue
		var t := grid_tile(m[1])
		var room := _room_of(infos, t)
		if room < 0:
			continue
		if not sand.has(t):
			_drift(infos[room], sand, 6, t - Vector2i(infos[room]["pos"]))
	var used_pit := {}
	if floor_num >= int(SAND["pits_from"]):
		var n_pit := randi_range(int(SAND["pits"][0]), int(SAND["pits"][1]))
		for i in open_rooms:
			if out["pits"].size() >= n_pit:
				break
			if String(Themes.get_theme(String(themes[i]))["feature"]) == "trap":
				continue  # (a trap room keeps its whole floor for its set piece)
			var t := _clear_tile(infos[i], links, i, 1)
			if t == Vector2i(-1, -1):
				continue
			out["pits"].append({"pos": _world(t), "r": float(SAND["pit_r"]), "room": i})
			used_pit[i] = true
	if floor_num >= int(SAND["crumble_from"]):
		var n_cr := randi_range(int(SAND["crumbles"][0]), int(SAND["crumbles"][1]))
		var made := 0
		for i in open_rooms:
			if made >= n_cr:
				break
			var t := _clear_tile(infos[i], links, i, 1)
			if t == Vector2i(-1, -1):
				continue
			for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i(1, 1)]:
				var u: Vector2i = t + d
				if not sand.has(u) and _open_grid(infos[i], u):
					out["crumbles"].append(u)
			made += 1
	# Monsters on a pit's sink stand at its edge instead.
	for m in plan["monsters"]:
		for pit in out["pits"]:
			if m[1].distance_to(pit["pos"]) < pit["r"] and String(m[0]) != "burrower":
				m[1] = pit["pos"] + (m[1] - pit["pos"]).normalized() * (pit["r"] + 14.0) if m[1] != pit["pos"] else pit["pos"] + Vector2(pit["r"] + 14.0, 0)
	for pit in out["pits"]:
		plan["safe_rooms"].append(Rect2(pit["pos"] - Vector2.ONE * pit["r"], Vector2.ONE * pit["r"] * 2.0))  # (no traps in a pit)
	out["shade"] = shade.keys()
	out["drifts"] = sand.keys()
	plan["tower_floor"] = out


## Rooms sand may lie in: ordinary rooms and courts, not the start, the stair,
## a puzzle, a scenario or a good room.
static func _fits(info: Dictionary, theme: String) -> bool:
	if not (info["role"] in ["guard", "branch", "gallery"]):
		return false
	if info["role"] == "gallery" and String(info.get("puzzle", "")) != "":
		return false
	var th: Dictionary = Themes.get_theme(theme)
	if String(th["kind"]) in ["good", "calm", "scenario", "mirror", "proving"]:
		return false
	return not (String(th["feature"]) in ["vault", "rest", "trader", "spring", "camp", "mirror", "puzzle", "scenario"])


static func _room_of(infos: Array, t: Vector2i) -> int:
	for i in infos.size():
		var r := Rect2i(infos[i]["pos"], infos[i]["size"])
		if r.has_point(t):
			return i
	return -1


static func _open_grid(info: Dictionary, g: Vector2i) -> bool:
	var lt: Vector2i = g - Vector2i(info["pos"])
	var rows: Array = info["rows"]
	if not Rooms.open_at(rows, lt.x, lt.y):
		return false
	return String(rows[lt.y])[lt.x] in ".M"


## A drift of `n` tiles grown from `seed` (local; random if (-1, -1)).
static func _drift(info: Dictionary, sand: Dictionary, n: int, seed: Vector2i) -> void:
	var tiles: Array = Rooms.open_tiles(info["rows"], 1)
	if tiles.is_empty():
		return
	var at: Vector2i = seed if seed.x >= 0 else tiles[randi() % tiles.size()]
	var at0: Vector2i = info["pos"]
	var grown: Array = [at]
	for k in n * 4:
		if grown.size() >= n:
			break
		var from: Vector2i = grown[randi() % grown.size()]
		var nx: Vector2i = from + [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP][randi() % 4]
		if not (nx in grown) and _open_grid(info, nx + at0):
			grown.append(nx)
	for t in grown:
		if _open_grid(info, t + at0):
			sand[t + at0] = true


## An open tile (grid) of room `i` with `keep` tiles of open floor round
## it, unreserved, and well away from the doorways; reserved. (-1, -1) if none.
static func _clear_tile(info: Dictionary, links: Array, i: int, keep: int) -> Vector2i:
	var rows: Array = info["rows"]
	var res: Dictionary = info["reserved"]
	var size: Vector2i = info["size"]
	var at0: Vector2i = info["pos"]
	var doors: Array = []
	for l in links:
		if int(l["c"]) == i or int(l["p"]) == i:
			var cr: Rect2i = l["link"]["corridor"]
			for y in range(cr.position.y, cr.end.y):
				for x in range(cr.position.x, cr.end.x):
					doors.append(Vector2i(x, y) - at0)
	var tiles: Array = Rooms.open_tiles(rows, keep)
	tiles.shuffle()
	for t in tiles:
		var ok := true
		for dy in range(-keep, keep + 1):
			for dx in range(-keep, keep + 1):
				var u: Vector2i = t + Vector2i(dx, dy)
				if res.has(u) or not Rooms.open_at(rows, u.x, u.y) or String(rows[u.y])[u.x] != ".":
					ok = false
		for d in doors:
			if absi(d.x - t.x) <= keep + 2 and absi(d.y - t.y) <= keep + 2:
				ok = false
		if not ok:
			continue
		for dy in range(-keep, keep + 1):
			for dx in range(-keep, keep + 1):
				res[t + Vector2i(dx, dy)] = true
		return t + at0
	return Vector2i(-1, -1)


## Wake the Sun Seals (objectives.gd place): a polished stone in each of a
## few rooms, its seal a few steps off in one of eight directions.
static func place_task(kind: String, spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, floor_num: int, cell: float) -> Dictionary:
	var O = load("res://scripts/objectives.gd")
	if kind != "sunstones":
		return {}
	spec["hint"] = O.KINDS[kind]["hint"]
	var n: int = O.count_for(kind, floor_num)
	var spread: Array = O._spread(cands, n, infos, dist)
	if spread.size() < mini(n, 2):
		return {}
	for j in n:
		var ri: int = spread[j % spread.size()]
		var info: Dictionary = infos[ri]
		var rows: Array = info["rows"]
		var res: Dictionary = info["reserved"]
		var placed := false
		for attempt in 8:
			var others: Array = spec["pieces"].map(func(x): return x["pos"])
			var p: Vector2 = O._spot(info, monsters, 0, false, others, 140.0)
			if p == Vector2.INF:
				break
			var st := Vector2i(((p - Vector2(info["rect"].position)) / cell).floor())
			var dirs: Array = range(8)
			dirs.shuffle()
			for di in dirs:
				var d: Vector2i = DIRS8[di]
				var steps := 3 if (d.x == 0 or d.y == 0) else 2
				var ok := true
				for k in range(1, steps + 1):
					var u: Vector2i = st + d * k
					ok = ok and Rooms.open_at(rows, u.x, u.y) and String(rows[u.y])[u.x] in ".M"
				var seal_t: Vector2i = st + d * steps
				if not ok or res.has(seal_t):
					continue
				res[st] = true
				res[seal_t] = true
				for dd in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					res[st + dd] = true
				var face: int = (di + randi_range(2, 6)) % 8
				var axis := Vector2.RIGHT if info["size"].x >= info["size"].y else Vector2.DOWN
				spec["pieces"].append({"pos": p, "room": ri, "seal": Vector2(info["rect"].position) + (Vector2(seal_t) + Vector2(0.5, 0.5)) * cell,
					"want": di, "face": face, "charge": 0.0, "sun_a": p - axis * cell * 1.4, "sun_b": p + axis * cell * 1.4, "phase": randf()})
				placed = true
				break
			if placed:
				break
		if not placed:
			return {}
	return spec


## The Sinking Court (scenarios.gd plan): the shared marks (a run from the
## mark to the far end), and the old stones that hold: a winding path from
## one to the other, and a few more.
static func scenario_plan(kind: String, info: Dictionary, gates: Array, floor_num: int, cell: float) -> Dictionary:
	var S = load("res://scripts/scenarios.gd")
	var base: Dictionary = S.plan("collapse", info, gates, floor_num, cell)
	if base.is_empty():
		return {}
	base["kind"] = kind
	var rect: Rect2 = info["rect"]
	var rows: Array = info["rows"]
	var at0: Vector2i = info["pos"]
	var open := {}
	for t in Rooms.open_tiles(rows, 0):
		if String(rows[t.y])[t.x] in ".M":
			open[t] = true
	var a := Vector2i(((base["start"] - rect.position) / cell).floor())
	var b := Vector2i(((base["end"] - rect.position) / cell).floor())
	if not open.has(a) or not open.has(b):
		return {}
	# A random-weighted walk from the mark to the far end (Dijkstra on noise).
	var cost := {}
	for t in open:
		cost[t] = 1.0 + randf() * 3.0
	var best := {a: 0.0}
	var prev := {}
	var todo: Array = [a]
	while not todo.is_empty():
		var bi := 0
		for k in todo.size():
			if best[todo[k]] < best[todo[bi]]:
				bi = k
		var cur: Vector2i = todo[bi]
		todo.remove_at(bi)
		if cur == b:
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var nx: Vector2i = cur + d
			if not open.has(nx):
				continue
			var nd: float = best[cur] + float(cost[nx])
			if not best.has(nx) or nd < best[nx]:
				best[nx] = nd
				prev[nx] = cur
				if not (nx in todo):
					todo.append(nx)
	if not prev.has(b):
		return {}
	var stones := {}
	var cur2: Vector2i = b
	while cur2 != a:
		stones[cur2] = true
		cur2 = prev[cur2]
	stones[a] = true
	for t in open:
		if randf() < float(SINK["extra"]):
			stones[t] = true
	# Around the mark and at the gate: solid ground to start and finish on.
	for t in open:
		if Vector2(t).distance_to(Vector2(a)) <= 1.5 or Vector2(t).distance_to(Vector2(b)) <= 1.0:
			stones[t] = true
	var floor_tiles: Array = []
	for t in open:
		floor_tiles.append(t + at0)
	base["stones"] = stones.keys().map(func(t): return t + at0)
	base["floor"] = floor_tiles
	base["path_len"] = best[b] / 2.5
	return base


# --- the live floor (main.tower_floor) -------------------------------------------

var main
var spec := {}
var shade := {}  # grid tile -> true
var sand := {}  # grid tile -> true (drifts, crumbled flagstones, settled quicksand)
var crumbles := {}  # grid tile -> state: 0 intact, 1 stepped on, then seconds left as it gives way (negative: gone)
var pits: Array = []
var suns: Array = []
var lights: Array = []
var sun_lights: Array = []
var light_t := 0.0
var cur_k := 1.0  # this tick's sight share (main.sight_k)
var where := ""  # "sun", "shade" or ""
var lose_t := 0.0
var swallow_cd := 0.0
var last_out := Vector2.ZERO  # the climber's last spot outside a pit
var stone_t := {}  # piece index -> time since its last counted strike
var sink := {}  # the running Sinking Court: {stones, delay, meter, s}
var redraw_t := 0.0
var crumble_tile := Vector2i(-999, -999)


func _ready() -> void:
	z_index = -3  # on the floor, over the room, under everyone


func setup(plan: Dictionary) -> void:
	clear()
	spec = plan.get("tower_floor", {})
	for t in spec.get("shade", []):
		shade[t] = true
	for t in spec.get("drifts", []):
		sand[t] = true
	for t in spec.get("crumbles", []):
		crumbles[t] = 0.0
	for p in spec.get("pits", []):
		pits.append(p.duplicate())
	for s in spec.get("suns", []):
		suns.append(s.duplicate())
	# The sun's light, a few patches along each shaft (moved with it).
	if main.lighting != null:
		for s in suns:
			# Open to the sky: the whole court lies in a warm light.
			var rr: Rect2 = s["rect"]
			lights.append(main.lighting.add_light(rr.get_center(), maxf(rr.size.x, rr.size.y) * 0.75, Color(1.0, 0.9, 0.7), float(SUN["sky"]), 0.0))
			for k in 3:
				sun_lights.append([main.lighting.add_light(s["rect"].get_center(), 130.0, C_SUN, 0.55, 0.15), s, k])
		var ob = main.objective
		if ob != null and ob.kind == "sunstones":
			for pc in ob.pieces:
				sun_lights.append([main.lighting.add_light(pc["pos"], 90.0, C_SUN, 0.6, 0.2), pc, -1])
	if main.player != null:
		last_out = main.player.global_position
	queue_redraw()


func clear() -> void:
	if main != null and main.lighting != null:
		for l in sun_lights:
			main.lighting.remove_light(l[0])
		for id in lights:
			main.lighting.remove_light(id)
	sun_lights.clear()
	lights.clear()
	shade.clear()
	sand.clear()
	crumbles.clear()
	pits.clear()
	suns.clear()
	stone_t.clear()
	sink = {}
	cur_k = 1.0
	where = ""


## Where a sun shaft's middle lies now (world, along its axis).
func _sun_at(s: Dictionary) -> float:
	var ph := fmod(Time.get_ticks_msec() / 1000.0 / float(SUN["period"]) + float(s["phase"]), 1.0)
	var k := 0.5 - 0.5 * cos(ph * TAU)
	return lerpf(float(s["lo"]), float(s["hi"]), k)


func _sun_rect(s: Dictionary) -> Rect2:
	var r: Rect2 = s["rect"]
	var c := _sun_at(s)
	var w: float = s["w"]
	return Rect2(c - w * 0.5, r.position.y, w, r.size.y) if s["vertical"] else Rect2(r.position.x, c - w * 0.5, r.size.x, w)


## A sun stone's patch of light (Wake the Sun Seals): where it is now.
func _skylight(pc: Dictionary) -> Vector2:
	var ph := fmod(Time.get_ticks_msec() / 1000.0 / float(SEAL["period"]) + float(pc["phase"]), 1.0)
	return Vector2(pc["sun_a"]).lerp(pc["sun_b"], 0.5 - 0.5 * cos(ph * TAU))


func in_sun(pos: Vector2) -> bool:
	if shade.has(grid_tile(pos)):
		return false
	for s in suns:
		if _sun_rect(s).has_point(pos) and Rect2(s["rect"]).has_point(pos):
			return true
	var ob = main.objective
	if ob != null and ob.kind == "sunstones":
		for pc in ob.pieces:
			if _skylight(pc).distance_to(pos) < float(SEAL["sun_r"]):
				return true
	return false


func in_shade(pos: Vector2) -> bool:
	return shade.has(grid_tile(pos))


func is_sand(pos: Vector2) -> bool:
	var t := grid_tile(pos)
	if sand.has(t) or (crumbles.has(t) and float(crumbles[t]) < 0.0):
		return true
	if not sink.is_empty() and sink["sunk"].has(t):
		return true
	for p in pits:
		if pos.distance_to(p["pos"]) < float(p["r"]):
			return true
	return false


func pit_at(pos: Vector2) -> Dictionary:
	for p in pits:
		if pos.distance_to(p["pos"]) < float(p["r"]):
			return p
	return {}



## main.is_solid: sand is walked on like stone.
func blocks_walking(_t: Vector2i) -> bool:
	return false

## Sand slows you (main.water_slow): a drift a little, a pit and quicksand more.
func slow_at(pos: Vector2) -> float:
	var t := grid_tile(pos)
	if not sink.is_empty() and sink["sunk"].has(t) and not sink["stones"].has(t):
		return float(SINK["slow"])
	if not pit_at(pos).is_empty():
		return float(SAND["pit_slow"])
	if sand.has(t) or (crumbles.has(t) and float(crumbles[t]) < 0.0):
		return float(SAND["slow"])
	return 1.0


## Monsters notice you from farther in the sun, from nearer in the shade (enemy.gd).
func sight_k() -> float:
	return cur_k


## reach.gd live_check: nothing here walls anything off.
func reach_live(_solid: PackedByteArray, _size: Vector2i, _doors: Array, _opens: Dictionary) -> void:
	pass


# --- each tick --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var p = main.player
	swallow_cd -= delta
	var pos: Vector2 = p.global_position
	# Sun or shade under the climber.
	where = "shade" if in_shade(pos) else ("sun" if in_sun(pos) else "")
	cur_k = float(SHADE["sight"]) if where == "shade" else (float(SUN["sight"]) if where == "sun" else 1.0)
	lose_t -= delta
	if where == "shade" and lose_t <= 0.0 and not p.dead:
		lose_t = 0.3
		for e in main.enemies():
			if e.is_boss() or not e.aware or e.is_attacking():
				continue
			if e.global_position.distance_to(pos) > float(SHADE["lose"]):
				e.lose_track(float(SHADE["lose_t"]), null)
	if p.dead or main.climbing:
		_tick_lights(delta)
		return
	# Sand pits pull you toward their sink.
	var pit := pit_at(pos)
	if pit.is_empty():
		last_out = pos
	elif not p.in_air() and not p.has_bond("sandshaper"):
		var to: Vector2 = pit["pos"] - pos
		if to.length() < float(SAND["sink_r"]) and swallow_cd <= 0.0:
			_swallow(p, pit["pos"] + (last_out - pit["pos"]).normalized() * (float(pit["r"]) + 16.0))
		elif to.length() > 2.0:
			p.move_and_collide(to.normalized() * float(SAND["pull"]) * delta)
	# Cracked flagstones give way after you've crossed.
	var t := grid_tile(pos)
	if t != crumble_tile:
		if crumbles.has(crumble_tile) and float(crumbles[crumble_tile]) == 1.0:
			crumbles[crumble_tile] = float(SAND["crumble_t"]) + 1.0
		crumble_tile = t
		if crumbles.has(t) and float(crumbles[t]) == 0.0:
			crumbles[t] = 1.0
			main.sfx("stone_slide", 1.4, -12.0)
	for c in crumbles.keys():
		var v: float = crumbles[c]
		if v > 1.0:
			v -= delta
			if v <= 1.0:
				v = -1.0
				main.fx_burst(_world(c), Vector2.UP, C_SAND, 10, 90.0)
				main.sfx("spell_sand", 1.3, -10.0)
			crumbles[c] = v
	_tick_lights(delta)
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()


func _tick_lights(delta: float) -> void:
	light_t -= delta
	if light_t > 0.0 or main.lighting == null:
		return
	light_t = 0.1
	for l in sun_lights:
		if int(l[2]) < 0:
			main.lighting.move_light(l[0], _skylight(l[1]))
			continue
		var s: Dictionary = l[1]
		var r := _sun_rect(s).intersection(s["rect"])
		var f := (int(l[2]) + 0.5) / 3.0
		main.lighting.move_light(l[0], r.position + Vector2(r.size.x * 0.5, r.size.y * f) if s["vertical"] else r.position + Vector2(r.size.x * f, r.size.y * 0.5))


## The sand swallows the climber: it hurts, and spits them out at `to`.
func _swallow(p, to: Vector2) -> void:
	swallow_cd = 1.2
	main.fx_burst(p.global_position, Vector2.UP, C_SAND, 18, 160.0)
	main.fx_text(p.global_position + Vector2(0, -40), String(TEXT["swallowed"]), C_SAND.lightened(0.2))
	main.sfx("spell_sand", 0.8, -2.0)
	p.receive_attack(float(SAND["swallow"]) + float(SAND["swallow_per_floor"]) * main.floor_num, null, true)
	if not p.dead:
		p.global_position = main.walkable_point(to, to, 14.0) if not main.is_solid(to) else last_out
		p.last_safe = p.global_position
		p.reset_physics_interpolation()


## A melee swing (player.gd): nothing of the floor's own to strike here (the
## task's stones go through objective.gd).
func strike(_from: Vector2, _dir: Vector2, _reach: float, _arc_deg: float) -> void:
	pass


# --- the task: Wake the Sun Seals (objective.gd hands it over) ----------------------

func task_tick(ob, delta: float, _p, _hurt: bool) -> void:
	if ob.kind != "sunstones":
		return
	for i in ob.pieces.size():
		var pc: Dictionary = ob.pieces[i]
		stone_t[i] = float(stone_t.get(i, 9.0)) + delta
		if pc["state"] == "done":
			continue
		var lit := stone_lit(pc)
		if lit and int(pc["face"]) == int(pc["want"]):
			pc["charge"] = float(pc["charge"]) + delta
			pc["state"] = "doing"
			if float(pc["charge"]) >= float(SEAL["charge"]):
				ob._piece_done(pc)
				main.fx_text(pc["seal"] + Vector2(0, -36), String(TEXT["seal"]), C_SUN)
				main.light_flash(pc["seal"], C_SUN, 1.6, 1.6, 0.4)
				main.sfx("puzzle_solve", 1.2, -4.0)
				if main.lighting != null:
					lights.append(main.lighting.add_light(pc["seal"], 110.0, C_SUN, 0.6, 0.3))
		else:
			pc["charge"] = maxf(0.0, float(pc["charge"]) - delta * 0.5)
			pc["state"] = "todo" if float(pc["charge"]) <= 0.0 else "doing"


## Is the sun on this stone now?
func stone_lit(pc: Dictionary) -> bool:
	return _skylight(pc).distance_to(pc["pos"]) < float(SEAL["near"])


func task_strike(ob, from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	if ob.kind != "sunstones":
		return
	for i in ob.pieces.size():
		var pc: Dictionary = ob.pieces[i]
		if pc["state"] == "done":
			continue
		var to: Vector2 = pc["pos"] - from
		if to.length() > reach + 22.0 or absf(dir.angle_to(to)) > deg_to_rad(arc_deg + 20.0):
			continue
		if float(stone_t.get(i, 9.0)) < float(SEAL["gap"]):
			continue
		stone_t[i] = 0.0
		pc["face"] = (int(pc["face"]) + 1) % 8
		main.sfx("mirror_turn", 1.0, -2.0)
		main.fx_burst(pc["pos"], Vector2.UP, C_POLISH, 6, 80.0)


# --- the scenario: The Sinking Court (scenarios.gd hands it over) --------------------

func scenario_begin(s: Dictionary, _host) -> void:
	var stones := {}
	for t in s["stones"]:
		stones[t] = true
	var start_t := grid_tile(s["start"])
	var delay := {}
	for t in s["floor"]:
		if not stones.has(t):
			delay[t] = float(SINK["grace"]) + Vector2(t).distance_to(Vector2(start_t)) / float(SINK["speed"])
	sink = {"stones": stones, "delay": delay, "sunk": {}, "meter": 0.0, "hits": 0}
	s["limit"] = float(s.get("path_len", 8.0)) / float(SINK["pace"]) + float(SINK["spare"])


func scenario_tick(s: Dictionary, delta: float, p, host) -> void:
	if sink.is_empty():
		host._finish(s, "none")
		return
	if not Rect2(s["rect"]).grow(-4.0).has_point(p.global_position):
		_settle()
		host._finish(s, "none", String(TEXT["left"]))
		return
	var delay: Dictionary = sink["delay"]
	var sunk: Dictionary = sink["sunk"]
	for t in delay.keys():
		if s["t"] >= float(delay[t]):
			sunk[t] = true
			delay.erase(t)
			if randf() < 0.3:
				main.fx_burst(_world(t), Vector2.UP, C_SAND, 5, 70.0)
	var pt := grid_tile(p.global_position)
	if sunk.has(pt) and not sink["stones"].has(pt) and not p.in_air():
		sink["meter"] = float(sink["meter"]) + float(SINK["drag"]) * delta
		if float(sink["meter"]) >= 1.0:
			sink["meter"] = 0.0
			sink["hits"] = int(sink["hits"]) + 1
			main.fx_burst(p.global_position, Vector2.UP, C_SAND, 18, 160.0)
			main.fx_text(p.global_position + Vector2(0, -40), String(TEXT["swallowed"]), C_SAND.lightened(0.2))
			main.sfx("spell_sand", 0.8, -2.0)
			p.receive_attack(float(SINK["dmg"]) + float(SINK["dmg_per_floor"]) * main.floor_num, null, true)
			var best: Vector2i = pt
			var best_d := INF
			for st in sink["stones"]:
				var d := Vector2(st).distance_squared_to(Vector2(pt))
				if d < best_d and Vector2(st).distance_squared_to(Vector2(grid_tile(s["end"]))) <= Vector2(pt).distance_squared_to(Vector2(grid_tile(s["end"]))) + 4.0:
					best_d = d
					best = st
			if not p.dead:
				p.global_position = _world(best)
				p.reset_physics_interpolation()
	else:
		sink["meter"] = maxf(0.0, float(sink["meter"]) - delta)
	if p.global_position.distance_to(s["end"]) < 30.0:
		var hits: int = sink["hits"]
		_settle()
		host._finish(s, "gold" if hits <= int(SINK["gold_hits"]) and s["t"] <= float(s["limit"]) * float(SINK["gold_share"]) else ("silver" if hits <= int(SINK["silver_hits"]) else "bronze"))
	elif s["t"] >= float(s["limit"]):
		p.receive_attack(15.0, null, true)
		_settle()
		host._finish(s, "none")


## The quicksand settles into soft sand once it's over.
func _settle() -> void:
	if sink.is_empty():
		return
	for t in sink["sunk"]:
		if not sink["stones"].has(t):
			sand[t] = true
	sink = {}


func scenario_title(_s: Dictionary) -> String:
	return String(TEXT["sinking"])


func scenario_status(s: Dictionary) -> Dictionary:
	if sink.is_empty():
		return {}
	return {"title": String(TEXT["sinking"]), "line": String(TEXT["sinking_line"]) % [int(sink["hits"]), maxi(0, int(ceil(float(s.get("limit", 0.0)) - s["t"])))]}


func scenario_goal(s: Dictionary) -> Vector2:
	return s["end"]


# --- the floor bot (tests/floor_bot_driver.gd) ----------------------------------------

func bot_step(_bot) -> Dictionary:
	return {}


## The bot's grid: pits cost a detour; their sinks are walked round.
func bot_grid(astar: AStarGrid2D, _bot) -> void:
	for p in pits:
		var c := grid_tile(p["pos"])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var t := c + Vector2i(dx, dy)
				if astar.region.has_point(t) and not astar.is_point_solid(t):
					astar.set_point_weight_scale(t, 4.0 if (dx != 0 or dy != 0) else 12.0)


## The task's next step: turn the nearest stone that faces wrong; wait by
## one that faces right for the sun to come round.
func bot_task(bot) -> Dictionary:
	var ob = main.objective
	if ob.kind != "sunstones":
		return {}
	var pc: Dictionary = bot._nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
	if pc.is_empty():
		return {}
	if int(pc["face"]) != int(pc["want"]):
		return {"pos": pc["pos"], "act": "strike", "why": "a sun stone"}
	var away: Vector2 = Vector2(pc["pos"]) - Vector2(DIRS8[int(pc["want"])]).normalized() * 40.0
	return {"pos": main.walkable_point(pc["pos"], away, 12.0), "act": "stand", "r": 16.0, "why": "the sun, on a stone"}


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var view: Rect2 = main.room_view._view_rect() if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	var b := Draw.Batch.new()
	# Shade: a cool dark wash.
	for tile in shade:
		var r := _tile_rect(tile)
		if view.intersects(r) and not main._is_solid_tile(tile.x, tile.y):
			b.rect(r, Color(C_SHADE, 0.28))
	# Sand drifts, crumbled flagstones, settled quicksand.
	for tile in sand:
		var r := _tile_rect(tile)
		if view.intersects(r):
			_sand_tile(b, r, tile, t)
	for tile in crumbles:
		var r := _tile_rect(tile)
		if not view.intersects(r):
			continue
		var v: float = crumbles[tile]
		if v < 0.0:
			_sand_tile(b, r, tile, t)
		else:
			_cracked(b, r, tile, v)
	for p in pits:
		if view.has_point(p["pos"]):
			_pit(b, p["pos"], float(p["r"]), t)
	# The sun: a warm bright band moving over the court.
	for s in suns:
		var r := _sun_rect(s).intersection(s["rect"])
		if not view.intersects(r):
			continue
		for wr in main.room_info[int(s["room"])]["walk"]:
			var c: Rect2 = r.intersection(wr)
			if c.has_area():
				b.rect(c, Color(C_SUN, 0.22))
				b.rect(c.grow_individual(0, 0, 0, -c.size.y * 0.5) if not s["vertical"] else c.grow_individual(0, 0, -c.size.x * 0.5, 0), Color(C_SUN, 0.06))
		# Its edges, and motes of dust turning in the light.
		var e0 := r.position
		var e1 := r.position + (Vector2(0, r.size.y) if s["vertical"] else Vector2(r.size.x, 0))
		b.line(e0, e1, Color(C_SUN, 0.3), 2.0)
		var e2 := r.end - (Vector2(0, r.size.y) if s["vertical"] else Vector2(r.size.x, 0))
		b.line(e2, r.end, Color(C_SUN, 0.3), 2.0)
		for k in 6:
			var ph := fmod(t * 0.13 + k * 0.17, 1.0)
			var q := r.position + Vector2(r.size.x * fmod(k * 0.37 + ph * 0.3, 1.0), r.size.y * ph)
			b.circle(q, 1.6, Color(1.0, 0.97, 0.85, 0.6 * sin(ph * PI)), 6)
	# The quicksand of the Sinking Court, and its stones.
	if not sink.is_empty():
		for tile in sink["sunk"]:
			if not sink["stones"].has(tile):
				var r := _tile_rect(tile)
				if view.intersects(r):
					_quicksand(b, r, tile, t)
		for tile in sink["stones"]:
			var r := _tile_rect(tile)
			if view.intersects(r):
				_old_stone(b, r)
	elif main.scenarios != null:
		for s in main.scenarios.list:
			if String(s["kind"]) == "sinking" and s["state"] == "idle":
				for tile in s["stones"]:
					var r := _tile_rect(tile)
					if view.intersects(r):
						_old_stone(b, r)
	# The task's stones, seals and the light they throw.
	var ob = main.objective
	if ob != null and ob.kind == "sunstones":
		for pc in ob.pieces:
			_sun_stone(b, pc, t)
	# Where the climber stands: a small sun or a shade sign at their feet.
	var p = main.player
	if p != null and not p.dead:
		var c: Vector2 = p.global_position + Vector2(0, 16)
		if where == "sun":
			b.arc(c, 7.0, 0.0, TAU, 14, Color(C_SUN, 0.85), 1.5)
			for k in 8:
				var a := k * TAU / 8.0 + t * 0.5
				b.line(c + Vector2.from_angle(a) * 9.0, c + Vector2.from_angle(a) * 12.0, Color(C_SUN, 0.7), 1.2)
		elif where == "shade":
			b.arc(c, 8.0, PI * 0.35, PI * 1.65, 14, Color(0.7, 0.72, 0.9, 0.7), 1.8)
	b.flush(self)


func _sand_tile(b, r: Rect2, tile: Vector2i, t: float) -> void:
	b.rect(r, Color(C_SAND, 0.82))
	for k in 3:
		var y := r.position.y + 8.0 + k * 11.0 + sin(t * 0.4 + tile.x * 1.7 + k) * 1.5
		b.line(Vector2(r.position.x + 4.0, y), Vector2(r.end.x - 4.0, y + 2.0), Color(C_SAND_DARK, 0.45), 1.5)
	b.circle(r.position + Vector2(10.0 + (tile.x * 7 % 20), 12.0 + (tile.y * 5 % 18)), 2.0, Color(C_SAND_DARK, 0.5), 6)


func _cracked(b, r: Rect2, tile: Vector2i, v: float) -> void:
	var inner := r.grow(-2.0)
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.05) * 1.5, 0) if v > 1.0 else Vector2.ZERO
	b.rect(Rect2(inner.position + shake, inner.size), C_STONE.darkened(0.15))
	var c := inner.get_center() + shake
	for k in 4:
		var a := k * 1.6 + tile.x
		b.line(c, c + Vector2.from_angle(a) * 16.0, Color(0.3, 0.22, 0.14, 0.8), 1.5)
	if v > 0.0:
		b.rect(Rect2(inner.position + shake, inner.size), Color(C_SAND, 0.25 + (0.3 if v > 1.0 else 0.0)))


func _pit(b, c: Vector2, r: float, t: float) -> void:
	b.circle(c, r + 3.0, Color(C_SAND_DARK, 0.7), 40)
	b.circle(c, r, Color(C_SAND, 0.92), 40)
	# Rings sliding inward, toward the sink.
	for k in 4:
		var ph := fmod(t * 0.25 + k * 0.25, 1.0)
		b.arc(c, r * (1.0 - ph), 0.0, TAU, 32, Color(C_SAND_DARK, 0.55 * sin(ph * PI)), 2.0)
	b.circle(c, float(SAND["sink_r"]) + 4.0, Color(0.35, 0.25, 0.14, 0.85), 20)
	b.circle(c, float(SAND["sink_r"]), Color(0.18, 0.12, 0.08), 18)


func _quicksand(b, r: Rect2, tile: Vector2i, t: float) -> void:
	b.rect(r, Color(0.7, 0.55, 0.32, 0.95))
	var c := r.get_center()
	var ph := fmod(t * 0.6 + (tile.x + tile.y) * 0.3, 1.0)
	b.arc(c, 4.0 + ph * 14.0, 0.0, TAU, 16, Color(0.45, 0.33, 0.18, 0.6 * (1.0 - ph)), 1.5)


func _old_stone(b, r: Rect2) -> void:
	var inner := r.grow(-3.0)
	b.rect(inner.grow(1.5), Palette.OUTLINE)
	b.rect(inner, C_STONE.lightened(0.08))
	b.line(inner.position, Vector2(inner.end.x, inner.position.y), C_STONE.lightened(0.3), 1.5)


func _sun_stone(b, pc: Dictionary, t: float) -> void:
	var c: Vector2 = pc["pos"]
	var done: bool = pc["state"] == "done"
	# The skylight's patch of sun drifting over it.
	var sky := _skylight(pc)
	b.circle(sky, float(SEAL["sun_r"]), Color(C_SUN, 0.18), 32)
	b.circle(sky, float(SEAL["sun_r"]) * 0.6, Color(C_SUN, 0.12), 24)
	# The seal in the floor.
	var sc: Vector2 = pc["seal"]
	var charge := 1.0 if done else clampf(float(pc["charge"]) / float(SEAL["charge"]), 0.0, 1.0)
	b.circle(sc, 15.0, Palette.OUTLINE, 24)
	b.circle(sc, 13.0, C_STONE.darkened(0.25), 24)
	b.arc(sc, 9.0, 0.0, TAU, 20, Color(C_SUN.darkened(0.3), 0.8), 1.5)
	for k in 6:
		var a := k * TAU / 6.0
		b.line(sc + Vector2.from_angle(a) * 4.0, sc + Vector2.from_angle(a) * 9.0, Color(C_SUN.darkened(0.35), 0.8), 1.2)
	if charge > 0.0:
		b.circle(sc, 13.0 * charge, Color(C_SUN, 0.5 + 0.4 * charge), 20)
	# The beam: when the sun is on the stone, it throws the light the way it faces.
	var d := Vector2(DIRS8[int(pc["face"])]).normalized()
	if not done and stone_lit(pc):
		var reach := CELL * float(SEAL["beam"]) * (1.0 if int(pc["face"]) % 2 == 0 else 0.95)
		var end: Vector2 = c + d * reach
		for step in range(1, 13):
			var q: Vector2 = c + d * reach * step / 12.0
			if main.is_solid(q):
				end = q
				break
		b.line(c, end, Color(C_SUN, 0.35), 9.0)
		b.line(c, end, Color(1.0, 0.98, 0.85, 0.85), 3.0)
	# The stone: a polished slab on a plinth, its face showing which way it turns.
	b.circle(c + Vector2(0, 8), 13.0, Color(0, 0, 0, 0.3), 16)
	b.rect(Rect2(c + Vector2(-11, 2), Vector2(22, 8)), C_STONE.darkened(0.3))
	var side := d.orthogonal()
	var face := PackedVector2Array([c + side * 10.0 - d * 3.0 + Vector2(0, -4), c + side * 10.0 + d * 3.0 + Vector2(0, -4), c - side * 10.0 + d * 3.0 + Vector2(0, -4), c - side * 10.0 - d * 3.0 + Vector2(0, -4)])
	b.polygon(face, Palette.OUTLINE)
	var face2 := PackedVector2Array()
	for q in face:
		face2.append(c + Vector2(0, -4) + (q - c - Vector2(0, -4)) * 0.8)
	b.polygon(face2, C_POLISH if not done else C_SUN)
	b.line(c + Vector2(0, -4), c + Vector2(0, -4) + d * 12.0, Color(C_SUN.darkened(0.2), 0.9), 2.0)
	if not done:
		b.arc(c, 22.0, 0.0, TAU, 24, Color(C_SUN, 0.15 + 0.15 * sin(t * 3.0)), 1.5)
