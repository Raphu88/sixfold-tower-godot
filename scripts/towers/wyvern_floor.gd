extends Node2D
## THE WYVERN'S FORGE: what makes a floor of the Wyvern's tower its own
## (floor_styles.gd names this script as the tower's "module").
##
## LAYOUT. Long workshop halls in a grid (more ways between rooms than other
## towers: floor_styles.gd), carved in the forge's own shapes (carve below):
##   workshop   benches and anvils in rows, a clear aisle down the middle
##   forgehall  a long hall with machine columns along both walls
## Every corridor is an iron grate over the forge's fires (drawn here), and
## the halls are cut by MOLTEN CHANNELS.
##
## THE SYSTEM: HEAT AND MOLTEN METAL.
##   Molten channels run right across a hall. Nothing crosses them but a
##   bridge: a chain bridge laid across (two tiles), or, from floor
##   RULES "crank_from", now and then a bridge hauled up out of reach,
##   lowered by striking its CRANK on the near side. (reach.gd sees the
##   channels as rock and a raised bridge as a lever's door, so the stair
##   and the task are always proved reachable.)
##   Furnaces stand in some halls, their bellows breathing: while a bellows
##   blows (a warning glow first, then the hot spell), the furnace's heat
##   reaches out (HEAT "r"). Linger in it and heat builds up on you (the
##   ring at your feet fills); full, it burns: the climber's Burning state
##   when monsters may give the climber states (reactions.gd CLIMBER
##   "enabled"), otherwise heat damage every half second until you step out
##   and cool.
##   Water barrels stand by the fires: strike one and it bursts, quenching
##   the heat around it for a while (furnaces go dark), soaking every foe in
##   the splash and cooling you at once. A forge golem caught in it is
##   quenched (scripts/towers/forge_golem.gd).
##
## ITS TASK: "furnaces" (objectives.gd KINDS): Stoke the Furnaces. Cold
## furnaces in different halls; strike each one's bellows until it roars
## (FURNACE "pumps" strikes; it cools back while you dawdle). A waking
## furnace throws its heat: don't stand at its mouth too long.
##
## ITS SCENARIO: "forge" (scenarios.gd, themes.gd scn_forge): Hold the Forge.
## Three furnaces burn in the hall; step onto the mark and the doors shut.
## The fires die down by themselves, and faster with a foe beside them
## (waves of the tower's creatures go for them): strike a furnace's bellows
## to stoke it. Graded by how many went out; all three out at once fails.
##
## Every number and word is in RULES, HEAT, BARREL, FURNACE, FORGE and TEXT
## (the Data editor's "Towers" sections).

const MODULE := "res://scripts/towers/wyvern_floor.gd"
const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0  # (floors.gd CELL)
const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

## How floors are laid: the share of halls cut by a channel (at least
## "channels_min" a floor when the halls allow), the share of halls with a
## gutter of metal along one wall (never by a doorway), how often a channel's
## bridge is raised (lowered by a crank) from floor "crank_from", how many
## halls have a furnace, how many water barrels a floor has.
static var RULES := {
	"channel_chance": 0.75, "channels_min": 3, "channels_max": 5, "gutter_chance": 0.7,
	"crank_chance": 0.45, "crank_from": 3,
	"furnaces": [1, 2], "barrels": [1, 3],
	"lock_base": 5000,  # (a raised bridge's lock id: reach.gd)
}
## Heat: how far a furnace's heat reaches, how long its bellows take to
## breathe (seconds) and the share of that it blows hot, the warning before;
## how fast heat builds on you in it and cools out of it (shares of full a
## second); what full heat does: Burning for "burn_t" seconds (reactions on),
## or "dps" damage each half second.
static var HEAT := {"r": 92.0, "cycle": 7.0, "hot_share": 0.5, "warn": 1.4, "build": 0.55, "cool": 0.7,
	"burn_t": 2.0, "dps": 3.0, "lit_heat": 0.55}
## Water barrels: the splash's reach, how long the heat around it stays
## quenched, how long a barrel takes to fill again, how long a foe is soaked.
static var BARREL := {"r": 80.0, "quench": 10.0, "refill": 18.0, "soak": 4.0, "reach": 150.0}
## Stoke the Furnaces: strikes to light one, how fast an unlit one cools
## back (share of lit a second) once it's left alone "rest" seconds, its
## heat's reach, the least time between two strikes that count.
static var FURNACE := {"pumps": 4, "decay": 0.05, "rest": 1.5, "r": 84.0, "gap": 0.3}
## Hold the Forge: how long it lasts, how fast a fire dies by itself and
## with each foe beside it (share a second), what a strike of the bellows
## gives back, waves, and the grades (furnaces that went out at most).
static var FORGE := {"time": 40.0, "decay": 0.055, "foe_drain": 0.09, "near": 56.0, "stoke": 0.4, "wave_every": 6.5, "per_wave": 2,
	"gold": 0, "silver": 1}
static var TEXT := {
	"crank": "The bridge comes down",
	"crank_hint": "Strike the crank",
	"quench": "Quenched",
	"too_hot": "Too hot!",
	"roar": "The furnace roars",
	"forge": "Keep the furnaces lit",
	"forge_line": "Lit %d of %d  ·  %d s",
	"went_out": "A furnace goes out",
	"relit": "Relit",
}

const C_MOLTEN := Color(1.0, 0.42, 0.1)
const C_MOLTEN_HI := Color(1.0, 0.82, 0.38)
const C_CRUST := Color(0.32, 0.12, 0.06)
const C_IRON := Color(0.3, 0.28, 0.3)
const C_IRON_HI := Color(0.55, 0.52, 0.56)
const C_WATER := Color(0.4, 0.7, 0.95)


# --- carving the forge's own rooms (rooms.gd carve) --------------------------------

static func carve(shape: String, size: Vector2i) -> Array:
	var w := size.x
	var h := size.y
	var g: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		g.append(row)
	var cx := w / 2
	match shape:
		"workshop":
			# Benches (low blocks two tiles long) in rows, kept two tiles off
			# the walls and out of a clear aisle down the middle.
			if w >= 9 and h >= 7:
				for y in range(2, h - 2, 3):
					for x in range(2, w - 3, 3):
						if x + 1 >= cx - 2 and x <= cx + 1:
							continue
						if y >= h - 2:
							continue
						g[y][x] = "#"
						g[y][x + 1] = "#"
		"forgehall":
			# Machine columns along both long walls, none in the middle.
			if w >= 9 and h >= 6:
				for x in range(2, w - 2, 3):
					if absi(x - cx) <= 2:
						continue
					g[1][x] = "o"
					g[h - 2][x] = "o"
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


## Molten channels, furnaces and water barrels laid over the finished plan.
static func shape_plan(plan: Dictionary, infos: Array, links: Array, floor_num: int, _tower: Dictionary) -> void:
	var out := {"module": MODULE, "channels": [], "furnaces": [], "barrels": []}
	var themes: Array = plan["themes"]
	var used_rooms := {}
	var cands: Array = []  # rooms a channel may cut (trap rooms too: the traps keep off the metal)
	var calm: Array = []  # rooms a furnace may stand in (no traps there)
	for i in infos.size():
		if _fits(infos[i], String(themes[i]), true):
			cands.append(i)
		if _fits(infos[i], String(themes[i]), false):
			calm.append(i)
	cands.shuffle()
	var molten := {}  # grid tile -> true (bridges left out)
	for i in cands:
		if out["channels"].size() >= int(RULES["channels_max"]):
			break
		if out["channels"].size() >= int(RULES["channels_min"]) and randf() > float(RULES["channel_chance"]):
			continue
		var ch := _channel(i, infos[i], links, floor_num, out["channels"].size())
		if ch.is_empty():
			continue
		out["channels"].append(ch)
		for t in ch["tiles"]:
			if not (t in ch["bridge"]):
				molten[t] = true
	# Gutters of metal along the walls of some halls (never by a doorway).
	for i in cands:
		if randf() < float(RULES["gutter_chance"]):
			var gt := _gutter(i, infos[i], links)
			if gt.is_empty():
				continue
			out["channels"].append(gt)
			for t in gt["tiles"]:
				molten[t] = true
	# Monsters never stand in the metal.
	for m in plan["monsters"]:
		var t := grid_tile(m[1])
		var near: Array = out["channels"].filter(func(c): return t in c["tiles"])
		if not near.is_empty():
			m[1] = _away_from(near[0], infos[int(near[0]["room"])], m[1])
	# Furnaces and water barrels.
	var heat_rooms: Array = calm.duplicate()
	heat_rooms.shuffle()
	var n_furn := randi_range(int(RULES["furnaces"][0]), int(RULES["furnaces"][1]))
	for i in heat_rooms:
		if out["furnaces"].size() >= n_furn:
			break
		var t := _free_tile(infos[i], molten, 1)
		if t == Vector2i(-1, -1):
			continue
		var pos := _world(t)
		out["furnaces"].append({"pos": pos, "room": i, "phase": randf()})
		plan["pillars"].append({"pos": pos, "r": 17.0})
		used_rooms[i] = true
	var n_bar := randi_range(int(RULES["barrels"][0]), int(RULES["barrels"][1]))
	var by: Array = out["furnaces"].map(func(f): return int(f["room"])) + out["channels"].map(func(c): return int(c["room"]))
	by.shuffle()
	for i in by:
		if out["barrels"].size() >= n_bar:
			break
		if out["barrels"].any(func(b): return int(b["room"]) == i):
			continue
		var t := _free_tile(infos[i], molten, 1)
		if t == Vector2i(-1, -1):
			continue
		out["barrels"].append({"pos": _world(t), "room": i})
		plan["pillars"].append({"pos": _world(t), "r": 12.0})
	# The task's furnaces (Stoke the Furnaces) are solid too.
	var obj: Dictionary = plan.get("objective", {})
	if String(obj.get("kind", "")) == "furnaces":
		for pc in obj["pieces"]:
			plan["pillars"].append({"pos": pc["furnace"], "r": 17.0})
	# What reach.gd and the traps need to know.
	_metal_to_plan(plan, out)
	for ch in out["channels"]:
		if ch.has("crank"):
			plan["keep"].append(ch["crank"])
	# The planner proves its own floors: if the metal walls anything off (a
	# low wall cutting a bridge's end from its side, say), it gives way:
	# gutters first, then raised bridges are laid down, then whole channels.
	var R = load("res://scripts/reach.gd")
	if not R.plan_check(plan)["ok"]:
		var bare := plan.duplicate()
		bare["impassable"] = []
		bare["lever_gates"] = []
		if R.plan_check(bare)["ok"]:
			var steps: Array = []
			for ch in out["channels"]:
				if ch.get("gutter", false):
					steps.append(["drop", ch])
			for ch in out["channels"]:
				if ch.has("crank"):
					steps.append(["lay", ch])
			for ch in out["channels"]:
				if not ch.get("gutter", false):
					steps.append(["drop", ch])
			for st in steps:
				if st[0] == "drop":
					out["channels"].erase(st[1])
				else:
					st[1].erase("crank")
				_metal_to_plan(plan, out)
				if R.plan_check(plan)["ok"]:
					break
	for i in used_rooms:
		plan["safe_rooms"].append(infos[i]["rect"])  # (no traps by the fires: they're danger enough)
	plan["tower_floor"] = out


## The plan's "impassable" (the metal, bridges left out) and "lever_gates"
## (raised bridges, their cranks) from the channels laid.
static func _metal_to_plan(plan: Dictionary, out: Dictionary) -> void:
	var molten := {}
	var gates: Array = []
	for ch in out["channels"]:
		for t in ch["tiles"]:
			if not (t in ch["bridge"]):
				molten[t] = true
		if ch.has("crank"):
			gates.append({"tiles": ch["bridge"], "lock_id": int(ch["lock_id"]), "lock_pos": ch["crank"]})
	var tiles: Array = molten.keys()
	tiles.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	plan["impassable"] = Rooms.merge_rows(tiles.map(func(t): return _tile_rect(t)))
	plan["lever_gates"] = gates


## Rooms a channel or a furnace may go in: ordinary halls, not the start,
## the stair, a puzzle, the task's own hall, a scenario or a good room.
static func _fits(info: Dictionary, theme: String, traps_ok: bool) -> bool:
	if not (info["role"] in ["guard", "branch", "gallery"]):
		return false
	if info["role"] == "gallery" and String(info.get("puzzle", "")) != "":
		return false
	if mini(info["size"].x, info["size"].y) < 6:
		return false
	var th: Dictionary = Themes.get_theme(theme)
	if String(th["kind"]) in ["good", "calm", "scenario", "mirror", "proving"]:
		return false
	if String(th["feature"]) == "trap":
		return traps_ok
	return not (String(th["feature"]) in ["vault", "rest", "trader", "cache", "spring", "camp", "mirror", "puzzle", "objective", "chasm", "ambush", "scenario"])


## A channel across room `i`: {room, tiles (grid), bridge (grid), vertical,
## lock_id, crank? (world)}; {} if no line across will do.
static func _channel(i: int, info: Dictionary, links: Array, floor_num: int, index: int) -> Dictionary:
	var size: Vector2i = info["size"]
	var rows: Array = info["rows"]
	var res: Dictionary = info["reserved"]
	var at0: Vector2i = info["pos"]
	var vertical := size.x >= size.y  # (the channel runs north-south across a wide hall)
	var n := size.x if vertical else size.y
	var length := size.y if vertical else size.x
	var width := 2 if n >= 11 else 1
	# The room's doorways (local tiles, just inside), and the way in from its parent.
	var doors: Array = []
	var entry := Vector2i(-99, -99)
	for l in links:
		if int(l["c"]) != i and int(l["p"]) != i:
			continue
		var cr: Rect2i = l["link"]["corridor"]
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				var lt := Vector2i(x, y) - at0
				if lt.x >= -1 and lt.y >= -1 and lt.x <= size.x and lt.y <= size.y:
					var c := Vector2i(clampi(lt.x, 0, size.x - 1), clampi(lt.y, 0, size.y - 1))
					doors.append(c)
					if int(l["c"]) == i and not l.has("kind"):
						entry = c
	# Anywhere across but the edges, the middle likelier (doorways sit near the middles of walls, so the sides often do).
	var keyed: Array = []
	for at in range(2, n - 1 - width):
		keyed.append([absi(at - n / 2) + randf() * 2.5, at])
	keyed.sort_custom(func(a, b): return a[0] < b[0])
	var options: Array = keyed.map(func(k): return k[1])
	for at in options:
		var by_k := {}  # k -> tiles across the width
		var ok := true
		for wv in width:
			for k in length:
				var t := Vector2i(at + wv, k) if vertical else Vector2i(k, at + wv)
				var ch := String(rows[t.y])[t.x]
				if ch == "X":
					continue
				if not (ch in ".M~") or res.has(t):
					ok = false
					break
				for d in doors:
					if absi(d.x - t.x) <= 1 and absi(d.y - t.y) <= 1:
						ok = false
				if not ok:
					break
				if not by_k.has(k):
					by_k[k] = []
				by_k[k].append(t)
			if not ok:
				break
		if not ok or by_k.size() < 3:
			continue
		# The bridge: two steps of the line, open floor at both ends.
		var ks: Array = by_k.keys()
		ks.shuffle()
		var bk := -1
		for k in ks:
			if not by_k.has(k + 1) or by_k[k].size() < width or by_k[k + 1].size() < width:
				continue
			var ends_ok := true
			for kk in [k, k + 1]:
				for side in [-1, width]:
					var e := Vector2i(at + side, kk) if vertical else Vector2i(kk, at + side)
					ends_ok = ends_ok and Rooms.open_at(rows, e.x, e.y) and String(rows[e.y])[e.x] != "#"
			if ends_ok:
				bk = k
				break
		if bk < 0:
			continue
		var tiles: Array = []
		var bridge: Array = []
		for k in by_k:
			for t in by_k[k]:
				tiles.append(t + at0)
				if k == bk or k == bk + 1:
					bridge.append(t + at0)
				res[t] = true
		var out := {"room": i, "tiles": tiles, "bridge": bridge, "vertical": vertical, "lock_id": int(RULES["lock_base"]) + index,
			"at": at, "width": width, "bk": bk}
		# Now and then the bridge is raised: a crank on the side you come in by lowers it.
		if floor_num >= int(RULES["crank_from"]) and randf() < float(RULES["crank_chance"]) and entry.x > -99:
			var side := -1 if (entry.x if vertical else entry.y) < at else 1
			var best := Vector2i(-1, -1)
			var best_d := INF
			for dk in range(-3, 5):
				for dd in [2, 3]:
					var along: int = (at - dd) if side < 0 else (at + width - 1 + dd)
					var t := Vector2i(along, bk + dk) if vertical else Vector2i(bk + dk, along)
					if t.x < 1 or t.y < 1 or t.x >= size.x - 1 or t.y >= size.y - 1 or res.has(t):
						continue
					if String(rows[t.y])[t.x] != "." and String(rows[t.y])[t.x] != "M":
						continue
					var open := true
					for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						open = open and Rooms.open_at(rows, t.x + d.x, t.y + d.y)
					var dist: float = absf(dk - 0.5) + float(dd)
					if open and dist < best_d:
						best_d = dist
						best = t
			if best.x >= 0:
				out["crank"] = _world(best + at0)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						res[best + Vector2i(dx, dy)] = true
		return out
	return {}


## A gutter of molten metal along one long wall of room `i` (its edge row),
## left open by every doorway: {room, tiles, bridge: [], vertical, gutter}.
static func _gutter(i: int, info: Dictionary, links: Array) -> Dictionary:
	var size: Vector2i = info["size"]
	var rows: Array = info["rows"]
	var res: Dictionary = info["reserved"]
	var at0: Vector2i = info["pos"]
	var doors: Array = []
	for l in links:
		if int(l["c"]) != i and int(l["p"]) != i:
			continue
		var cr: Rect2i = l["link"]["corridor"]
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				doors.append(Vector2i(x, y) - at0)
	var wide := size.x >= size.y
	var sides: Array = [0, size.y - 1] if wide else [0, size.x - 1]
	sides.shuffle()
	for edge in sides:
		var tiles: Array = []
		var n := size.x if wide else size.y
		for k in n:
			var t := Vector2i(k, edge) if wide else Vector2i(edge, k)
			var inner := t + (Vector2i(0, 1 if edge == 0 else -1) if wide else Vector2i(1 if edge == 0 else -1, 0))
			if not (String(rows[t.y])[t.x] in ".M") or res.has(t) or not Rooms.open_at(rows, inner.x, inner.y):
				continue
			if doors.any(func(d): return absi(d.x - t.x) <= 2 and absi(d.y - t.y) <= 2):
				continue
			tiles.append(t)
		if tiles.size() < 4:
			continue
		for t in tiles:
			res[t] = true
		return {"room": i, "tiles": tiles.map(func(t): return t + at0), "bridge": [], "vertical": not wide, "gutter": true}
	return {}


## The nearest open spot of the room off the channel (for a monster on it).
static func _away_from(ch: Dictionary, info: Dictionary, pos: Vector2) -> Vector2:
	var best := pos
	var best_d := INF
	for t in Rooms.open_tiles(info["rows"], 1):
		var g: Vector2i = t + Vector2i(info["pos"])
		if g in ch["tiles"]:
			continue
		var w := _world(g)
		var d := w.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = w
	return best


## A free tile of the room (grid), clear around it (`keep` tiles), off the
## metal and the doorways; reserved as it's taken. (-1, -1) if none.
static func _free_tile(info: Dictionary, molten: Dictionary, keep: int) -> Vector2i:
	var rows: Array = info["rows"]
	var res: Dictionary = info["reserved"]
	var tiles: Array = Rooms.open_tiles(rows, 1)
	tiles.shuffle()
	for t in tiles:
		var ok := true
		for dy in range(-keep, keep + 1):
			for dx in range(-keep, keep + 1):
				var u: Vector2i = t + Vector2i(dx, dy)
				if res.has(u) or molten.has(u + Vector2i(info["pos"])) or not Rooms.open_at(rows, u.x, u.y) or String(rows[u.y])[u.x] == "#":
					ok = false
		if not ok:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				res[t + Vector2i(dx, dy)] = true
		return t + Vector2i(info["pos"])
	return Vector2i(-1, -1)


## Stoke the Furnaces (objectives.gd place): a cold furnace in each of a few
## rooms, its bellows the piece you go to (the furnace stands just north).
static func place_task(kind: String, spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, floor_num: int, cell: float) -> Dictionary:
	var O = load("res://scripts/objectives.gd")
	if kind != "furnaces":
		return {}
	spec["hint"] = O.KINDS[kind]["hint"]
	var n: int = O.count_for(kind, floor_num)
	var spread: Array = O._spread(cands, n, infos, dist)
	if spread.size() < mini(n, 2):
		return {}
	for j in n:
		var ri: int = spread[j % spread.size()]
		var others: Array = spec["pieces"].map(func(x): return x["pos"])
		var p: Vector2 = O._spot(infos[ri], monsters, 1, false, others, 140.0)
		if p == Vector2.INF:
			return {}
		var info: Dictionary = infos[ri]
		var lt := Vector2i(((p - Vector2(info["rect"].position)) / cell).floor()) + Vector2i.UP
		if not Rooms.open_at(info["rows"], lt.x, lt.y) or String(info["rows"][lt.y])[lt.x] == "#":
			return {}
		spec["pieces"].append({"pos": p, "room": ri, "furnace": p + Vector2(0, -cell), "fire": 0.0})
	spec["pumps"] = int(FURNACE["pumps"])
	return spec


## Hold the Forge (scenarios.gd plan): the shared marks, and three furnaces
## spread round the hall away from the mark.
static func scenario_plan(kind: String, info: Dictionary, gates: Array, floor_num: int, cell: float) -> Dictionary:
	var S = load("res://scripts/scenarios.gd")
	var base: Dictionary = S.plan("gauntlet", info, gates, floor_num, cell)
	if base.is_empty():
		return {}
	base["kind"] = kind
	var rect: Rect2 = info["rect"]
	var picks: Array = []
	var open: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
	open.shuffle()
	for t in open:
		var p: Vector2 = rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * cell
		if p.distance_to(base["start"]) < cell * 1.8:
			continue
		if picks.all(func(q): return q.distance_to(p) > cell * 2.4):
			picks.append(p)
			info["reserved"][t] = true
		if picks.size() >= 3:
			break
	if picks.size() < 3:
		return {}
	base["furnaces"] = picks
	base["keep"].append_array(picks)
	base["spawns"] = base["spawns"].filter(func(sp): return picks.all(func(q): return q.distance_to(sp) > cell * 1.5))
	return base


# --- the live floor (main.tower_floor) -------------------------------------------

var main
var spec := {}
var channels: Array = []  # the plan's, plus: lowered (bool), body (a raised bridge's)
var molten := {}  # grid tile -> true: the metal no one crosses (a raised bridge's tiles too)
var furnaces: Array = []  # {pos, phase, quench}
var barrels: Array = []  # {pos, full, t}
var splashes: Array = []  # {pos, t}
var heat := 0.0  # the climber's heat, 0..1 (full: it burns)
var heat_tick := 0.0
var hot_said := 0.0
var bodies: Array = []
var lights: Array = []
var redraw_t := 0.0
var corridors: Array = []
var workshop_blocks: Array = []
var forge := {}  # the running Hold the Forge: {fires, out, went_out, wave_t}
var stoke_t := {}  # piece index -> time since its last counted strike


func _ready() -> void:
	z_index = -3  # on the floor, over the room, under everyone


func setup(plan: Dictionary) -> void:
	clear()
	spec = plan.get("tower_floor", {})
	corridors = plan.get("corridors", [])
	for c0 in spec.get("channels", []):
		var ch: Dictionary = c0.duplicate(true)
		ch["lowered"] = not ch.has("crank")
		channels.append(ch)
		for t in ch["tiles"]:
			if not ch["lowered"] or not (t in ch["bridge"]):
				molten[t] = true
	for f in spec.get("furnaces", []):
		furnaces.append({"pos": f["pos"], "phase": float(f.get("phase", 0.0)), "quench": 0.0})
	for b in spec.get("barrels", []):
		barrels.append({"pos": b["pos"], "full": true, "t": 0.0})
	# The metal is solid: no path through it, and a wall to walk into (its
	# own bodies: a raised bridge's come away when it's lowered).
	if main.astar != null:
		for t in molten:
			if main.astar.region.has_point(t):
				main.astar.set_point_solid(t, true)
	var rest := {}
	for t in molten:
		rest[t] = true
	for ch in channels:
		if not ch["lowered"]:
			ch["body"] = _body_for(ch["bridge"])
			for t in ch["bridge"]:
				rest.erase(t)
	var tiles: Array = rest.keys()
	tiles.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for r in Rooms.merge_rows(tiles.map(func(t): return _tile_rect(t))):
		bodies.append(_add_body(r))
	# Glow along the channels and from the furnaces.
	if main.lighting != null:
		for ch in channels:
			var list: Array = ch["tiles"]
			for k in range(0, list.size(), 3):
				lights.append(main.lighting.add_light(_world(list[k]), 120.0, C_MOLTEN, 0.5, 0.25))
		for f in furnaces:
			f["light"] = main.lighting.add_light(f["pos"], 150.0, Color(1.0, 0.55, 0.25), 0.55, 0.3)
			lights.append(f["light"])
	# A lost climber's cache never lies in the metal.
	if not main.lost_cache.is_empty() and molten.has(grid_tile(main.lost_cache["pos"])):
		main.lost_cache["pos"] = _off_metal(main.lost_cache["pos"])
	# Workshop benches and machine columns get drawn as the forge's own.
	for i in main.room_info.size():
		if String(main.room_info[i].get("shape", "")) in ["workshop", "forgehall"]:
			var rr: Rect2 = main.room_info[i]["rect"]
			for b in main.layout_blocks:
				if rr.encloses(b):
					workshop_blocks.append(b)
	queue_redraw()


func clear() -> void:
	for b in bodies:
		if is_instance_valid(b):
			b.collision_layer = 0
			b.queue_free()
	bodies.clear()
	for ch in channels:
		if ch.has("body") and is_instance_valid(ch["body"]):
			ch["body"].collision_layer = 0
			ch["body"].queue_free()
	if main != null and main.lighting != null:
		for id in lights:
			main.lighting.remove_light(id)
	lights.clear()
	channels.clear()
	molten.clear()
	furnaces.clear()
	barrels.clear()
	splashes.clear()
	workshop_blocks.clear()
	heat = 0.0
	forge = {}
	stoke_t.clear()


func _add_body(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	return body


func _body_for(tiles: Array) -> StaticBody2D:
	var r := _tile_rect(tiles[0])
	for t in tiles:
		r = r.merge(_tile_rect(t))
	return _add_body(r)


func _off_metal(pos: Vector2) -> Vector2:
	for ring in range(1, 6):
		for k in 8:
			var q: Vector2 = pos + Vector2.from_angle(k * TAU / 8.0) * ring * CELL
			if not molten.has(grid_tile(q)) and not main.is_solid(q):
				return q
	return pos


func is_molten(pos: Vector2) -> bool:
	return molten.has(grid_tile(pos))



## main.is_solid: the metal (a raised bridge too) is no ground to stand on.
func blocks_walking(t: Vector2i) -> bool:
	return molten.has(t)

## No sand here: nothing slows you (main.water_slow).
func slow_at(_pos: Vector2) -> float:
	return 1.0


## Monsters see you as ever (enemy.gd).
func sight_k() -> float:
	return 1.0


## reach.gd live_check: the metal as rock, a raised bridge as a lever's door.
func reach_live(solid: PackedByteArray, size: Vector2i, doors: Array, opens: Dictionary) -> void:
	for t in molten:
		if t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y:
			solid[t.y * size.x + t.x] = 1
	for ch in channels:
		if ch["lowered"]:
			continue
		var lid := int(ch["lock_id"])
		doors.append({"tiles": ch["bridge"], "lock": "lever", "lock_id": lid})
		var c := grid_tile(ch["crank"])
		opens[lid] = {"any": [c, c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]}


# --- each tick --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var p = main.player
	for f in furnaces:
		f["quench"] = maxf(0.0, f["quench"] - delta)
	for b in barrels:
		if not b["full"]:
			b["t"] -= delta
			if b["t"] <= 0.0:
				b["full"] = true
	for s in splashes:
		s["t"] -= delta
	splashes = splashes.filter(func(s): return s["t"] > 0.0)
	hot_said -= delta
	if p.dead or main.climbing:
		return
	# Heat on the climber: it builds in a hot spell's reach and cools outside.
	var k := heat_at(p.global_position)
	if k > 0.0 and not p.in_air():
		heat = minf(1.0, heat + float(HEAT["build"]) * k * delta)
	else:
		heat = maxf(0.0, heat - float(HEAT["cool"]) * delta)
	if heat >= 1.0:
		heat_tick -= delta
		if heat_tick <= 0.0:
			heat_tick = 0.5
			_burn(p)
	else:
		heat_tick = 0.0
	if heat > 0.65 and hot_said <= 0.0:
		hot_said = 4.0
		main.fx_text(p.global_position + Vector2(0, -46), String(TEXT["too_hot"]), Color(1.0, 0.6, 0.3))
	if main.scenarios != null and not forge.is_empty() and not main.scenarios.running():
		forge = {}
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()


## How hot it is here (0: not at all .. 1: a bellows' full blast).
func heat_at(pos: Vector2) -> float:
	var best := 0.0
	for f in furnaces:
		if f["quench"] > 0.0 or pos.distance_to(f["pos"]) > float(HEAT["r"]):
			continue
		best = maxf(best, _blast(f))
	var ob = main.objective
	if ob != null and ob.kind == "furnaces":
		for pc in ob.pieces:
			var fire: float = 1.0 if pc["state"] == "done" else float(pc.get("fire", 0.0))
			if fire <= 0.0 or _quenched(pc["furnace"]) or pos.distance_to(pc["furnace"]) > float(FURNACE["r"]):
				continue
			best = maxf(best, fire * (float(HEAT["lit_heat"]) if pc["state"] == "done" else 1.0))
	return best


## A furnace's bellows: 0 while it draws breath, rising through the warning, 1 while it blows hot.
func _blast(f: Dictionary) -> float:
	var cyc := float(HEAT["cycle"])
	var ph := fmod(Time.get_ticks_msec() / 1000.0 / cyc + float(f["phase"]), 1.0) * cyc
	var hot_from := cyc * (1.0 - float(HEAT["hot_share"]))
	if ph >= hot_from:
		return 1.0
	return 0.0


## The warning: how near the next hot spell is (0..1 through its last HEAT "warn" seconds).
func _warning(f: Dictionary) -> float:
	var cyc := float(HEAT["cycle"])
	var ph := fmod(Time.get_ticks_msec() / 1000.0 / cyc + float(f["phase"]), 1.0) * cyc
	var hot_from := cyc * (1.0 - float(HEAT["hot_share"]))
	var w := float(HEAT["warn"])
	if ph < hot_from and ph > hot_from - w:
		return 1.0 - (hot_from - ph) / w
	return 0.0


func _quenched(pos: Vector2) -> bool:
	for s in splashes:
		if s["pos"].distance_to(pos) < float(BARREL["reach"]):
			return true
	return false


## Full heat: Burning (when monsters may give the climber states), or heat damage.
func _burn(p) -> void:
	if bool(Reactions.CLIMBER["enabled"]):
		Reactions.apply(main, p, "burning", float(HEAT["burn_t"]), "forge")
		return
	var burn: float = float(HEAT["dps"]) * (1.0 - float(p.gfx("ailment")))
	p.hp -= burn
	main.fx_text(p.global_position + Vector2(0, -24), "-%d" % int(round(burn)), Color(1.0, 0.55, 0.25))
	main.sfx("burn", 1.2, -8.0)
	if p.hp <= 0.0 and p._defy_death():
		p.hp = maxf(p.hp, 1.0)
	if p.hp <= 0.0:
		p.hp = 0.0
		p.dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## A melee swing (player.gd): a crank, a water barrel, a furnace in Hold the Forge.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	for ch in channels:
		if ch["lowered"] or not _in_swing(from, dir, reach, arc_deg, ch["crank"], 22.0):
			continue
		lower(ch)
	for b in barrels:
		if b["full"] and _in_swing(from, dir, reach, arc_deg, b["pos"], 20.0):
			burst(b)
	if not forge.is_empty():
		var s: Dictionary = main.scenarios.active
		var fires: Array = forge["fires"]
		for i in fires.size():
			if _in_swing(from, dir, reach, arc_deg, s["furnaces"][i], 24.0):
				var was: float = fires[i]
				fires[i] = minf(1.0, fires[i] + float(FORGE["stoke"]))
				main.fx_burst(s["furnaces"][i] + Vector2(0, -10), Vector2.UP, C_MOLTEN_HI, 10, 140.0)
				main.sfx("gust", 0.7, -4.0)
				if was <= 0.0:
					main.fx_text(s["furnaces"][i] + Vector2(0, -40), String(TEXT["relit"]), C_MOLTEN_HI)


func _in_swing(from: Vector2, dir: Vector2, reach: float, arc_deg: float, at: Vector2, extra: float) -> bool:
	var to: Vector2 = at - from
	return to.length() <= reach + extra and absf(dir.angle_to(to)) <= deg_to_rad(arc_deg + 20.0)


## A crank turned: its bridge comes down for good.
func lower(ch: Dictionary) -> void:
	if ch["lowered"]:
		return
	ch["lowered"] = true
	for t in ch["bridge"]:
		molten.erase(t)
		if main.astar != null and main.astar.region.has_point(t) and not main._is_solid_tile(t.x, t.y):
			main.astar.set_point_solid(t, false)
	if ch.has("body") and is_instance_valid(ch["body"]):
		ch["body"].collision_layer = 0
		ch["body"].queue_free()
	ch.erase("body")
	var mid := Vector2.ZERO
	for t in ch["bridge"]:
		mid += _world(t) / float(ch["bridge"].size())
	main.fx_text(ch["crank"] + Vector2(0, -40), String(TEXT["crank"]), C_IRON_HI.lightened(0.3))
	main.fx_burst(mid, Vector2.UP, C_MOLTEN_HI, 14, 160.0)
	main.sfx("lever", 0.8, -2.0)
	main.sfx("slam", 0.75, -4.0)
	main.shake(3.0)


## A water barrel bursts: the heat around it is quenched a while, foes in
## the splash are soaked, the climber cooled.
func burst(b: Dictionary) -> void:
	b["full"] = false
	b["t"] = float(BARREL["refill"])
	splashes.append({"pos": b["pos"], "t": float(BARREL["quench"])})
	for f in furnaces:
		if f["pos"].distance_to(b["pos"]) < float(BARREL["reach"]):
			f["quench"] = float(BARREL["quench"])
	var r := float(BARREL["r"])
	for e in main.enemies():
		if e.global_position.distance_to(b["pos"]) < r + e.radius:
			e.soak(float(BARREL["soak"]))
			if e.has_method("quench"):
				e.quench()
	var p = main.player
	if p.global_position.distance_to(b["pos"]) < r + p.radius:
		heat = 0.0
		if bool(Reactions.CLIMBER["enabled"]):
			Reactions.apply(main, p, "soaked", 3.0, "barrel")
	main.fx_ring(b["pos"], C_WATER, r, 0.45, 4.0)
	main.fx_burst(b["pos"], Vector2.UP, C_WATER, 22, 220.0)
	main.fx_text(b["pos"] + Vector2(0, -36), String(TEXT["quench"]), C_WATER.lightened(0.3))
	main.sfx("spell_water", 1.0, -2.0)
	main.sfx("hiss", 0.9, -4.0)


# --- the task: Stoke the Furnaces (objective.gd hands it over) ----------------------

func task_tick(ob, delta: float, _p, _hurt: bool) -> void:
	if ob.kind != "furnaces":
		return
	for i in ob.pieces.size():
		var pc: Dictionary = ob.pieces[i]
		stoke_t[i] = float(stoke_t.get(i, 9.0)) + delta
		if pc["state"] == "done":
			continue
		if float(stoke_t[i]) > float(FURNACE["rest"]):
			pc["fire"] = maxf(0.0, float(pc.get("fire", 0.0)) - float(FURNACE["decay"]) * delta)
		pc["state"] = "doing" if pc["fire"] > 0.0 else "todo"


func task_strike(ob, from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	if ob.kind != "furnaces":
		return
	for i in ob.pieces.size():
		var pc: Dictionary = ob.pieces[i]
		if pc["state"] == "done" or not _in_swing(from, dir, reach, arc_deg, pc["pos"], 22.0):
			continue
		if float(stoke_t.get(i, 9.0)) < float(FURNACE["gap"]):
			continue
		stoke_t[i] = 0.0
		pc["fire"] = minf(1.0, float(pc.get("fire", 0.0)) + 1.0 / float(FURNACE["pumps"]) + 0.001)
		main.fx_burst(pc["furnace"] + Vector2(0, 8), Vector2.UP, C_MOLTEN_HI, 8 + int(pc["fire"] * 10.0), 150.0)
		main.sfx("gust", 0.6 + 0.3 * pc["fire"], -3.0)
		if pc["fire"] >= 1.0:
			ob._piece_done(pc)
			main.fx_text(pc["furnace"] + Vector2(0, -40), String(TEXT["roar"]), C_MOLTEN_HI)
			main.sfx("fire_blast", 0.8, -2.0)
			main.light_flash(pc["furnace"], C_MOLTEN, 1.6, 1.5, 0.4)
			if main.lighting != null:
				lights.append(main.lighting.add_light(pc["furnace"], 170.0, Color(1.0, 0.55, 0.25), 0.7, 0.35))


# --- the scenario: Hold the Forge (scenarios.gd hands it over) -----------------------

func scenario_begin(s: Dictionary, _host) -> void:
	forge = {"fires": [1.0, 1.0, 1.0], "out": [false, false, false], "went_out": 0}
	s["wave_t"] = 2.0


func scenario_tick(s: Dictionary, delta: float, _p, host) -> void:
	var cfg := FORGE
	var fires: Array = forge["fires"]
	for i in fires.size():
		var drain := float(cfg["decay"])
		for e in s["mobs"]:
			if e.global_position.distance_to(s["furnaces"][i]) < float(cfg["near"]):
				drain += float(cfg["foe_drain"])
		fires[i] = maxf(0.0, fires[i] - drain * delta)
		if fires[i] <= 0.0 and not forge["out"][i]:
			forge["out"][i] = true
			forge["went_out"] += 1
			main.fx_text(s["furnaces"][i] + Vector2(0, -40), String(TEXT["went_out"]), Color(0.7, 0.6, 0.55))
			main.sfx("hiss", 0.7, -2.0)
		elif fires[i] > 0.0:
			forge["out"][i] = false
	if fires.all(func(f): return f <= 0.0):
		host._finish(s, "none")
		forge = {}
		return
	s["wave_t"] -= delta
	if s["wave_t"] <= 0.0 and s["t"] < float(cfg["time"]) - 4.0:
		s["wave_t"] = float(cfg["wave_every"])
		for k in int(cfg["per_wave"]) + main.floor_num / 4:
			var e = host._spawn(s, 2.0)
			if e != null:
				e.goal = s["furnaces"][randi() % 3]
	if s["t"] >= float(cfg["time"]):
		var n: int = forge["went_out"]
		forge = {}
		host._finish(s, "gold" if n <= int(cfg["gold"]) else ("silver" if n <= int(cfg["silver"]) else "bronze"))


func scenario_title(_s: Dictionary) -> String:
	return String(TEXT["forge"])


func scenario_status(s: Dictionary) -> Dictionary:
	if forge.is_empty():
		return {}
	var lit: int = forge["fires"].filter(func(f): return f > 0.0).size()
	return {"title": String(TEXT["forge"]), "line": String(TEXT["forge_line"]) % [lit, 3, maxi(0, int(ceil(float(FORGE["time"]) - s["t"])))]}


## Where to go: the furnace burning lowest.
func scenario_goal(s: Dictionary) -> Vector2:
	if forge.is_empty():
		return Vector2.INF
	var fires: Array = forge["fires"]
	var lo := 0
	for i in fires.size():
		if fires[i] < fires[lo]:
			lo = i
	return s["furnaces"][lo]


# --- the floor bot (tests/floor_bot_driver.gd) ----------------------------------------

## Before anything else: a crank it can walk to, while its bridge is up.
func bot_step(bot) -> Dictionary:
	if channels.all(func(c): return c["lowered"]):
		return {}
	var now := Time.get_ticks_msec()
	if now < bot_next and bot_crank.is_empty():
		return {}
	if not bot_crank.is_empty() and not bot_crank["lowered"]:
		return {"pos": bot_crank["crank"], "act": "strike", "why": "a crank"}
	bot_next = now + 500
	bot_crank = {}
	bot._build_grid()  # (its own grid: locked doors shut)
	var a := grid_tile(main.player.global_position)
	for ch in channels:
		if ch["lowered"]:
			continue
		var b := grid_tile(ch["crank"])
		if bot.astar.region.has_point(a) and bot.astar.region.has_point(b):
			var was: bool = bot.astar.is_point_solid(a)
			bot.astar.set_point_solid(a, false)
			var n: int = bot.astar.get_id_path(a, b, false).size()
			bot.astar.set_point_solid(a, was)
			if n > 0:
				bot_crank = ch
				return {"pos": ch["crank"], "act": "strike", "why": "a crank"}
	return {}


var bot_next := 0
var bot_crank := {}


## The bot's grid: furnaces' heat costs a detour.
func bot_grid(astar: AStarGrid2D, _bot) -> void:
	for f in furnaces:
		var c := grid_tile(f["pos"])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var t := c + Vector2i(dx, dy)
				if astar.region.has_point(t) and not astar.is_point_solid(t):
					astar.set_point_weight_scale(t, 3.0)


## The task's next step: the nearest cold furnace's bellows, struck.
func bot_task(bot) -> Dictionary:
	var ob = main.objective
	if ob.kind != "furnaces":
		return {}
	var pc: Dictionary = bot._nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
	if pc.is_empty():
		return {}
	return {"pos": pc["pos"], "act": "strike", "why": "a furnace's bellows"}


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var view: Rect2 = main.room_view._view_rect() if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	var b := Draw.Batch.new()
	# The corridors: iron grates over the forge's fires.
	for r in corridors:
		if view.intersects(r):
			_grate(b, r, t)
	for wb in workshop_blocks:
		if view.intersects(wb):
			_bench(b, wb)
	for ch in channels:
		_channel_draw(b, ch, t, view)
	for f in furnaces:
		if view.has_point(f["pos"]):
			_heat_zone(b, f["pos"], float(HEAT["r"]), _blast(f), _warning(f), f["quench"] > 0.0, t)
			_furnace(b, f["pos"], 1.0 if f["quench"] <= 0.0 else 0.15, t)
	for br in barrels:
		if view.has_point(br["pos"]):
			_barrel(b, br["pos"], br["full"])
	for s in splashes:
		var k: float = clampf(s["t"] / float(BARREL["quench"]), 0.0, 1.0)
		b.arc(s["pos"], float(BARREL["reach"]) * (0.9 + 0.1 * sin(t * 2.0)), 0.0, TAU, 40, Color(C_WATER, 0.25 * k), 2.0)
		b.circle(s["pos"], float(BARREL["r"]) * 0.6, Color(C_WATER, 0.12 * k), 24)
	# The task's furnaces.
	var ob = main.objective
	if ob != null and ob.kind == "furnaces":
		for pc in ob.pieces:
			var fire: float = 1.0 if pc["state"] == "done" else float(pc.get("fire", 0.0))
			if fire > 0.0 and not _quenched(pc["furnace"]):
				_heat_zone(b, pc["furnace"], float(FURNACE["r"]), fire * (float(HEAT["lit_heat"]) if pc["state"] == "done" else 1.0), 0.0, false, t)
			_furnace(b, pc["furnace"], fire, t)
			_bellows(b, pc["pos"], fire, pc["state"] == "done", t)
	# Hold the Forge's furnaces.
	if main.scenarios != null:
		for s in main.scenarios.list:
			if String(s["kind"]) != "forge":
				continue
			var running: bool = not forge.is_empty() and main.scenarios.active == s
			for i in s["furnaces"].size():
				var fire := 1.0
				if running:
					fire = forge["fires"][i]
				elif s["state"] == "done":
					fire = 0.0 if s["grade"] == "none" else 0.6
				_furnace(b, s["furnaces"][i], fire, t)
				_bellows(b, s["furnaces"][i] + Vector2(0, 26), fire, false, t)
				if running:
					b.rect(Rect2(s["furnaces"][i] + Vector2(-18, -40), Vector2(36, 5)), Color(0, 0, 0, 0.6))
					b.rect(Rect2(s["furnaces"][i] + Vector2(-18, -40), Vector2(36 * fire, 5)), C_MOLTEN_HI if fire > 0.3 else Color(1.0, 0.4, 0.3))
	# The climber's heat: a ring at their feet that fills.
	var p = main.player
	if p != null and heat > 0.02:
		var c: Vector2 = p.global_position + Vector2(0, 10)
		var col := C_MOLTEN.lerp(Color(1.0, 0.95, 0.7), heat)
		b.arc(c, 20.0, -PI * 0.5, -PI * 0.5 + TAU * heat, 32, Color(col, 0.85), 3.0)
		if heat >= 1.0:
			b.circle(c, 18.0, Color(1.0, 0.45, 0.15, 0.18 + 0.12 * sin(t * 12.0)), 20)
	b.flush(self)


func _grate(b, r: Rect2, t: float) -> void:
	b.rect(r, Color(0.16, 0.08, 0.06))
	var glow := 0.5 + 0.2 * sin(t * 1.3 + r.position.x * 0.01)
	b.rect(r.grow(-6.0), Color(C_MOLTEN.darkened(0.55), glow))
	var horiz := r.size.x >= r.size.y
	var step := 10.0
	if horiz:
		var x := r.position.x + 4.0
		while x < r.end.x:
			b.rect(Rect2(x, r.position.y + 2.0, 3.0, r.size.y - 4.0), C_IRON)
			x += step
		b.rect(Rect2(r.position.x, r.position.y + r.size.y * 0.5 - 1.5, r.size.x, 3.0), C_IRON.darkened(0.2))
	else:
		var y := r.position.y + 4.0
		while y < r.end.y:
			b.rect(Rect2(r.position.x + 2.0, y, r.size.x - 4.0, 3.0), C_IRON)
			y += step
		b.rect(Rect2(r.position.x + r.size.x * 0.5 - 1.5, r.position.y, 3.0, r.size.y), C_IRON.darkened(0.2))
	b.rect(Rect2(r.position, Vector2(r.size.x, 2.0)) if horiz else Rect2(r.position, Vector2(2.0, r.size.y)), C_IRON_HI.darkened(0.3))


## A workbench or anvil on a hall's low block.
func _bench(b, r: Rect2) -> void:
	b.rect(r.grow(-3.0), Color(0.24, 0.17, 0.12))
	b.rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 6)), Color(0.4, 0.28, 0.18))
	var n := int(round(r.size.x / CELL))
	for i in maxi(n, 1):
		var c := Vector2(r.position.x + (i + 0.5) * r.size.x / maxf(n, 1), r.get_center().y)
		var top := PackedVector2Array([c + Vector2(-13, -6), c + Vector2(13, -6), c + Vector2(9, 0), c + Vector2(-9, 0)])
		b.polygon(top, C_IRON_HI.darkened(0.15))
		b.rect(Rect2(c + Vector2(-5, 0), Vector2(10, 9)), C_IRON)
		b.line(c + Vector2(-13, -6), c + Vector2(13, -6), C_IRON_HI, 1.5)


func _channel_draw(b, ch: Dictionary, t: float, view: Rect2) -> void:
	for tile in ch["tiles"]:
		var r := _tile_rect(tile)
		if not view.intersects(r):
			continue
		var on_bridge: bool = tile in ch["bridge"]
		b.rect(r, C_CRUST)
		b.rect(r.grow(-2.0), C_MOLTEN.darkened(0.15))
		# Slow bright streaks drifting along the channel.
		var along: float = r.position.y if ch["vertical"] else r.position.x
		for k in 2:
			var ph := fmod(t * 0.35 + along * 0.013 + k * 0.5 + tile.x * 0.21, 1.0)
			var o := 6.0 + ph * (CELL - 12.0)
			var s := Rect2(r.position + (Vector2(4.0 + k * 14.0, o) if ch["vertical"] else Vector2(o, 4.0 + k * 14.0)), Vector2(10, 3) if ch["vertical"] else Vector2(3, 10))
			b.rect(s, Color(C_MOLTEN_HI, 0.75 * sin(ph * PI)))
		b.circle(r.get_center() + Vector2(sin(t * 0.9 + tile.y) * 6.0, cos(t * 0.7 + tile.x) * 6.0), 3.0, Color(C_MOLTEN_HI, 0.5), 10)
		if on_bridge:
			_bridge_tile(b, r, ch, t)
	# The bridge's posts on both banks (and, raised, its leaf standing up on the near one).
	if not ch["bridge"].is_empty():
		var br := _tile_rect(ch["bridge"][0])
		for bt in ch["bridge"]:
			br = br.merge(_tile_rect(bt))
		if view.intersects(br.grow(CELL)):
			var across := Vector2(1, 0) if ch["vertical"] else Vector2(0, 1)  # (the way you cross)
			var along := Vector2(0, 1) if ch["vertical"] else Vector2(1, 0)
			var half_across := (br.size * across).length() * 0.5
			var half_along := (br.size * along).length() * 0.5
			for sa in [-1.0, 1.0]:
				for sl in [-1.0, 1.0]:
					var post: Vector2 = br.get_center() + across * sa * (half_across + 5.0) + along * sl * (half_along - 4.0)
					b.rect(Rect2(post - Vector2(5, 5), Vector2(10, 10)), Palette.OUTLINE)
					b.rect(Rect2(post - Vector2(4, 4), Vector2(8, 8)), C_IRON_HI.darkened(0.1))
			if not ch["lowered"] and ch.has("crank"):
				var near_side := signf((ch["crank"] - br.get_center()).dot(across))
				var foot: Vector2 = br.get_center() + across * near_side * (half_across + 8.0)
				var leaf := Rect2(foot - along * (half_along - 6.0) - Vector2(0, 30) - across * 3.0, along * (half_along - 6.0) * 2.0 + Vector2(0, 30) + across * 6.0).abs()
				b.rect(Rect2(leaf.position + Vector2(5, 6), leaf.size), Color(0, 0, 0, 0.3))
				b.rect(leaf.grow(1.5), Palette.OUTLINE)
				b.rect(leaf, Color(0.42, 0.3, 0.2))
				for k in 3:
					b.line(leaf.position + Vector2(2, 6 + k * 9.0), Vector2(leaf.end.x - 2, leaf.position.y + 6 + k * 9.0), Color(0.3, 0.2, 0.13), 1.5)
	if ch.has("crank"):
		_crank(b, ch["crank"], ch["lowered"], t)


func _bridge_tile(b, r: Rect2, ch: Dictionary, t: float) -> void:
	# Across the channel: planks laid the way you walk, chains at both sides.
	var down: bool = ch["lowered"]
	var cross_vertical: bool = not ch["vertical"]  # (you cross a north-south channel going east-west)
	if not down:
		# Raised: hauled up out of reach. Its outline on the metal, dashed,
		# and its shadow; the chains hang slack from the posts.
		b.rect(r.grow(-4.0), Color(0, 0, 0, 0.3))
		var dash := Color(0.95, 0.85, 0.6, 0.55 + 0.25 * sin(t * 3.0))
		var q := r.grow(-3.0)
		for k in 4:
			var u0 := k / 4.0 + 0.04
			var u1 := k / 4.0 + 0.17
			b.line(q.position + Vector2(q.size.x * u0, 0), q.position + Vector2(q.size.x * u1, 0), dash, 2.0)
			b.line(Vector2(q.position.x + q.size.x * u0, q.end.y), Vector2(q.position.x + q.size.x * u1, q.end.y), dash, 2.0)
			b.line(q.position + Vector2(0, q.size.y * u0), q.position + Vector2(0, q.size.y * u1), dash, 2.0)
			b.line(Vector2(q.end.x, q.position.y + q.size.y * u0), Vector2(q.end.x, q.position.y + q.size.y * u1), dash, 2.0)
		return
	var plank := Color(0.42, 0.3, 0.2)
	if cross_vertical:
		for k in 4:
			b.rect(Rect2(r.position + Vector2(2, 1 + k * 10.0), Vector2(r.size.x - 4, 8)), plank.lightened(0.05 * (k % 2)))
		b.rect(Rect2(r.position, Vector2(3, r.size.y)), C_IRON)
		b.rect(Rect2(r.position + Vector2(r.size.x - 3, 0), Vector2(3, r.size.y)), C_IRON)
	else:
		for k in 4:
			b.rect(Rect2(r.position + Vector2(1 + k * 10.0, 2), Vector2(8, r.size.y - 4)), plank.lightened(0.05 * (k % 2)))
		b.rect(Rect2(r.position, Vector2(r.size.x, 3)), C_IRON)
		b.rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), C_IRON)


func _crank(b, c: Vector2, down: bool, t: float) -> void:
	b.circle(c + Vector2(0, 10), 13.0, Color(0, 0, 0, 0.3), 18)
	b.rect(Rect2(c + Vector2(-4, -4), Vector2(8, 16)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-3, -3), Vector2(6, 14)), C_IRON)
	var a := 0.0 if down else t * 0.0
	b.arc(c + Vector2(0, -8), 10.0, 0.0, TAU, 20, Palette.OUTLINE, 4.0)
	b.arc(c + Vector2(0, -8), 10.0, 0.0, TAU, 20, C_IRON_HI, 2.0)
	for k in 4:
		var d := Vector2.from_angle(a + k * PI * 0.5 + (0.6 if down else 0.0))
		b.line(c + Vector2(0, -8), c + Vector2(0, -8) + d * 10.0, C_IRON_HI, 2.0)
	var handle := c + Vector2(0, -8) + Vector2.from_angle(0.6 if down else -0.9) * 10.0
	b.circle(handle, 3.5, Color(0.85, 0.65, 0.3) if not down else C_IRON_HI, 10)
	if not down:
		b.arc(c + Vector2(0, -6), 20.0, 0.0, TAU, 24, Color(1.0, 0.82, 0.45, 0.25 + 0.2 * sin(t * 3.0)), 2.0)


func _heat_zone(b, c: Vector2, r: float, blast: float, warn: float, quenched: bool, t: float) -> void:
	if quenched:
		return
	if blast > 0.0:
		var flick := 0.85 + 0.15 * sin(t * 9.0 + c.x)
		b.circle(c, r, Color(1.0, 0.45, 0.12, 0.16 * blast * flick), 40)
		b.circle(c, r * 0.65, Color(1.0, 0.6, 0.2, 0.14 * blast * flick), 32)
		b.arc(c, r, 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.55 * blast), 2.5)
		for k in 5:
			var ph := fmod(t * 0.8 + k * 0.2, 1.0)
			var a := k * 1.3 + c.x
			b.circle(c + Vector2.from_angle(a) * r * 0.5 + Vector2(0, -ph * 26.0), 2.0, Color(1.0, 0.8, 0.4, 0.6 * (1.0 - ph) * blast), 8)
	elif warn > 0.0:
		b.arc(c, r * (1.15 - 0.15 * warn), 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.25 + 0.45 * warn), 2.0)
		b.circle(c, r * warn, Color(1.0, 0.5, 0.15, 0.06 * warn), 32)


func _furnace(b, c: Vector2, fire: float, t: float) -> void:
	b.circle(c + Vector2(0, 12), 20.0, Color(0, 0, 0, 0.32), 20)
	var dome := PackedVector2Array()
	for k in 13:
		var a := PI + k * PI / 12.0
		dome.append(c + Vector2(cos(a) * 19.0, sin(a) * 22.0 + 8.0))
	dome.append(c + Vector2(19, 14))
	dome.append(c + Vector2(-19, 14))
	b.polygon(dome, Palette.OUTLINE)
	var inner := PackedVector2Array()
	for q in dome:
		inner.append(c + (q - c) * 0.9)
	b.polygon(inner, Color(0.42, 0.2, 0.14))
	for row in 3:
		b.line(c + Vector2(-15, -4 + row * 6.0), c + Vector2(15, -4 + row * 6.0), Color(0.3, 0.13, 0.1), 1.0)
	# Its mouth: dark when cold, roaring when lit.
	var mouth := Rect2(c + Vector2(-8, 1), Vector2(16, 11))
	b.rect(mouth.grow(1.5), Palette.OUTLINE)
	b.rect(mouth, Color(0.08, 0.05, 0.05))
	if fire > 0.0:
		var f := 0.75 + 0.25 * sin(t * 11.0 + c.y)
		b.rect(mouth.grow(-1.0), Color(1.0, 0.45, 0.12, 0.6 + 0.4 * fire))
		b.circle(mouth.get_center() + Vector2(0, 1), 3.0 + 3.0 * fire * f, Color(C_MOLTEN_HI, 0.9), 12)
	# The chimney.
	b.rect(Rect2(c + Vector2(-4, -22), Vector2(8, 8)), Color(0.3, 0.16, 0.12))
	if fire > 0.2:
		for k in 3:
			var ph := fmod(t * 0.6 + k * 0.33, 1.0)
			b.circle(c + Vector2(sin(ph * 6.0 + k) * 3.0, -26.0 - ph * 22.0), 2.0 + ph * 3.0, Color(0.35, 0.32, 0.32, 0.35 * (1.0 - ph)), 8)


func _bellows(b, c: Vector2, fire: float, lit: bool, t: float) -> void:
	var squeeze := 0.5 + 0.5 * sin(t * 2.0) if lit else 0.3 + 0.7 * fire
	b.circle(c + Vector2(0, 7), 11.0, Color(0, 0, 0, 0.28), 14)
	var w := 10.0
	var h := 5.0 + 4.0 * squeeze
	var body := PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w * 0.6, -h * 0.4), c + Vector2(w * 0.6, h * 0.4), c + Vector2(-w, h)])
	b.polygon(body, Palette.OUTLINE)
	var inner := PackedVector2Array([c + Vector2(-w + 1.5, -h + 1.5), c + Vector2(w * 0.6 - 1.0, -h * 0.4 + 0.5), c + Vector2(w * 0.6 - 1.0, h * 0.4 - 0.5), c + Vector2(-w + 1.5, h - 1.5)])
	b.polygon(inner, Color(0.5, 0.33, 0.2))
	b.rect(Rect2(c + Vector2(w * 0.6, -1.5), Vector2(8, 3)), C_IRON_HI)
	b.line(c + Vector2(-w - 6, -h), c + Vector2(-w, -h), Color(0.4, 0.28, 0.18), 3.0)
	if not lit:
		var k := clampf(fire, 0.0, 1.0)
		b.arc(c, 18.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, Color(1.0, 0.65, 0.3, 0.9), 3.0)
		b.arc(c, 18.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.45, 0.2 + 0.15 * sin(t * 3.0)), 1.5)


func _barrel(b, c: Vector2, full: bool) -> void:
	b.circle(c + Vector2(0, 9), 12.0, Color(0, 0, 0, 0.3), 16)
	b.circle(c, 12.0, Palette.OUTLINE, 18)
	b.circle(c, 10.5, Color(0.45, 0.3, 0.18), 18)
	b.arc(c, 8.0, 0.0, TAU, 18, C_IRON_HI.darkened(0.2), 1.5)
	if full:
		b.circle(c, 7.0, C_WATER.darkened(0.2), 16)
		b.circle(c + Vector2(-2, -2), 2.5, Color(0.85, 0.95, 1.0, 0.7), 8)
	else:
		b.circle(c, 7.0, Color(0.15, 0.1, 0.08), 16)
