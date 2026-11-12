extends RefCounted
## The floor's ONE main task: what lifts the ward on the stair. Every floor
## of rooms (not floor 1, the camps, the Proving or the summit) has one,
## drawn from the pool below, never the same kind twice in a climb if it can
## be helped. Its pieces are spread over several rooms of the floor, on the
## main route and the branches, never in the start room. On arrival a banner
## names it; the HUD keeps a short line ("Braziers lit 2 of 4") and an arrow
## points at the nearest piece still to do, then at the stair. When it's
## done: gold light at the stair, essence, and a choice of one of three at
## the stair (objective.gd runs it; floors.gd asks `place` for the pieces).
##
## The kinds are plain data (names, words, counts, timings: all in the Data
## editor). Each of the eight puzzles (puzzles/catalog.gd) is a kind too:
## then the gallery holds that puzzle, and solving it is the task.
##   braziers   stand by each brazier until it catches; a blow puts out the
##              one you're lighting
##   runes      read the tablet, then step on the runes in its order; a wrong
##              step wakes the hall's guards and the path starts again
##   levers     strike every lever up; each falls back after `hold` seconds,
##              so all must be up together
##   orb        carry the sun orb from the far side of the floor to the
##              pedestal by the stair; a blow knocks it from your hands
##   keeper     a Keeper (a crowned champion) carries the stair's key: take it
##   wardstone  wake the stone and keep the beast's creatures off it while it
##              charges
##   shards     gather the key shards, each guarded, in different rooms
##   motes      catch the motes that drift away from you, in different rooms
## The towers' own kinds (each only in its tower, run by its floor script):
##   sluices    (the Kraken's) the way into the stair room is flooded deep;
##              turn each sluice wheel (stand at it) to drain it
##   vanes      (the Gryphon's) the way into the stair room is an open gap;
##              strike each wind vane round and the wind carries you over
##   furnaces   (the Wyvern's) strike each cold furnace's bellows until it
##              roars, in the heat it throws (scripts/towers/wyvern_floor.gd)
##   sunstones  (the Manticore's) turn each polished stone so the moving sun
##              it catches falls on its seal (scripts/towers/manticore_floor.gd)
## A kind with "towers" only turns up in those towers; one with "module" is
## placed and run by that tower's own floor script (main.tower_floor).

const Catalog := preload("res://scripts/puzzles/catalog.gd")
const Rooms := preload("res://scripts/rooms.gd")

## name: the banner's title for it; hint: one line on how; status: the HUD's
## line (%d done, %d in all); piece: what one piece is called (the arrow's
## label); count: [[up to floor, how many], ...]; weight: how likely it is
## next to the others (a puzzle kind's weight is PUZZLE_WEIGHT).
static var KINDS := {
	"braziers": {"name": "Light the Braziers", "hint": "Stand by each brazier until it catches. A blow puts out the one you're lighting.",
		"status": "Braziers lit %d of %d", "piece": "Brazier", "count": [[3, 2], [5, 3], [99, 4]], "weight": 1.0,
		"light_time": 1.6, "reach": 56.0},
	"runes": {"name": "Walk the Rune Path", "hint": "Read the tablet, then step on the runes in its order.",
		"status": "Runes walked %d of %d", "status_read": "Read the tablet", "status_next": "Next rune: %s  ·  %d of %d",
		"piece": "Rune", "tablet": "Tablet", "count": [[3, 3], [99, 4]], "weight": 1.0, "wrong_guards": 2,
		"glyphs": ["Sun", "Moon", "Star", "Wave", "Eye", "Key"]},
	"levers": {"name": "Raise the Levers", "hint": "Strike every lever up. Each falls back in time, so be quick.",
		"status": "Levers up %d of %d", "piece": "Lever", "count": [[99, 3]], "weight": 1.0,
		"hold_base": 28.0, "hold_per_floor": 2.5, "hold_min": 14.0, "walk_share": 1.6},
	"orb": {"name": "Carry the Sun Orb", "hint": "Carry the orb to the pedestal by the stair. A blow knocks it from your hands.",
		"status": "Carry the orb to the stair", "status_held": "Carrying the orb", "piece": "Orb", "pedestal": "Pedestal",
		"count": [[99, 1]], "weight": 1.0},
	"keeper": {"name": "Find the Keeper", "hint": "A Keeper carries the stair's key. Take it from them.",
		"status": "Find the Keeper", "status_key": "Take the Keeper's key", "piece": "Keeper", "key": "Key",
		"count": [[99, 1]], "weight": 1.0, "guards": [[5, 1], [99, 2]]},
	"wardstone": {"name": "Wake the Wardstone", "hint": "Wake the stone, then keep the beast's creatures off it while it charges.",
		"status": "Wardstone charged %d%%", "status_wake": "Wake the wardstone", "piece": "Wardstone",
		"count": [[99, 1]], "weight": 1.0, "charge_base": 22.0, "charge_per_floor": 2.0, "wave_every": 6.0,
		"alive_base": 2, "alive_per_floors": 4, "near": 76.0},
	"shards": {"name": "Gather the Key Shards", "hint": "Three shards of the stair's key lie in guarded rooms.",
		"status": "Key shards %d of %d", "piece": "Shard", "count": [[99, 3]], "weight": 1.0},
	"motes": {"name": "Catch the Motes", "hint": "Motes drift away from you. Corner them and catch them.",
		"status": "Motes caught %d of %d", "piece": "Mote", "count": [[3, 4], [8, 5], [99, 6]], "weight": 0.9,
		"flee": 150.0, "speed": 0.62, "names": {"gryphon": "Catch the Wind Motes", "kraken": "Catch the Tide Motes",
			"wyvern": "Catch the Ember Motes", "manticore": "Catch the Sand Motes", "firebird": "Catch the Spark Motes", "chimera": "Catch the Seed Motes"}},
	"sluices": {"name": "Drain the Stairwell", "hint": "The way to the stair is flooded. Turn every sluice wheel to send the water elsewhere.",
		"status": "Sluices turned %d of %d", "piece": "Sluice", "count": [[4, 2], [99, 3]], "weight": 1.6,
		"towers": ["kraken"], "module": "res://scripts/towers/kraken_floor.gd",
		"turn_time": 1.8, "reach": 52.0},
	"vanes": {"name": "Turn the Wind Vanes", "hint": "No bridge reaches the stair. Strike every wind vane round until the wind blows across the gap.",
		"status": "Vanes turned %d of %d", "piece": "Vane", "count": [[4, 2], [99, 3]], "weight": 1.6,
		"towers": ["gryphon"], "module": "res://scripts/towers/gryphon_floor.gd",
		"strikes": 2},
	# The towers' own kinds.
	"furnaces": {"name": "Stoke the Furnaces", "hint": "Strike each cold furnace's bellows until it roars. Don't linger in its heat.",
		"status": "Furnaces lit %d of %d", "piece": "Furnace", "count": [[5, 2], [99, 3]], "weight": 1.6,
		"towers": ["wyvern"], "module": "res://scripts/towers/wyvern_floor.gd"},
	"sunstones": {"name": "Wake the Sun Seals", "hint": "Strike each polished stone to turn it. When the sun crosses it, it throws the light where it faces: onto its seal.",
		"status": "Seals lit %d of %d", "piece": "Sun stone", "count": [[5, 2], [99, 3]], "weight": 1.6,
		"towers": ["manticore"], "module": "res://scripts/towers/manticore_floor.gd"},
}
## How likely each puzzle kind is next to the kinds above (its tower's own
## puzzle counts double).
static var PUZZLE_WEIGHT := {"base": 0.55, "signature": 1.6}
## The words around it.
static var TEXT := {
	"puzzle_status": "Solve the %s",
	"puzzle_hint": "Its answer lifts the ward on the stair.",
	"stair": "Stair",
	"done_title": "THE STAIR IS UNSEALED",
	"done": "Gold light rises on the stair. Take your pick before you climb.",
	"reliquary": "Reliquary",
	"reliquary_title": "THE RELIQUARY",
	"reliquary_sub": "One of three, for unsealing the stair.",
	"sealed": "Sealed: %s",
	"read": "The tablet's order: %s",
	"wrong": "The runes go dark. The path starts again.",
	"dropped": "The orb falls from your hands",
	"snuffed": "The brazier gutters out",
	"lever_fell": "A lever falls back",
	"stone_wakes": "The wardstone wakes",
	"keeper_falls": "The Keeper drops the stair's key",
	"optional_vault": "The puzzle's vault opens",
}
## When it's done: essence at the stair (this, plus this much a floor).
static var REWARD := {"essence": 6.0, "per_floor": 2.0, "light": 230.0}

## Dev tool and tests: when set, every floor of rooms gets this kind.
static var forced := ""
## The kinds used so far this climb (main.gd clears it as a climb starts).
static var climb_used: Array = []


static func is_puzzle(kind: String) -> bool:
	return Catalog.TYPES.has(kind)


## Whether a kind may turn up in tower `tid` (a tower's own kind only there).
static func allowed(kind: String, tid: String) -> bool:
	var towers: Array = KINDS.get(kind, {}).get("towers", [])
	return towers.is_empty() or tid in towers


## The tower floor script that places and runs a kind (null for the shared kinds).
static func module_of(kind: String) -> Script:
	var path := String(KINDS.get(kind, {}).get("module", ""))
	return load(path) if path != "" else null


## Every kind there is: the floor kinds and the puzzles.
static func all_kinds() -> Array:
	return KINDS.keys() + Catalog.TYPES.keys()


static func count_for(kind: String, floor_num: int) -> int:
	var table: Array = KINDS.get(kind, {}).get("count", [[99, 1]])
	for row in table:
		if floor_num <= int(row[0]):
			return int(row[1])
	return int(table[-1][1])


static func step_for(table: Array, floor_num: int) -> int:
	for row in table:
		if floor_num <= int(row[0]):
			return int(row[1])
	return int(table[-1][1])


## The task's name in a tower (puzzles and motes have tower names).
static func display_name(kind: String, tid: String) -> String:
	if is_puzzle(kind):
		return Catalog.display_name(kind, tid)
	var k: Dictionary = KINDS.get(kind, {})
	return String(k.get("names", {}).get(tid, k.get("name", kind)))


## The kind for a floor: never one used this climb if another is left;
## the tower's own puzzle likelier.
static func pick(floor_num: int, tid: String) -> String:
	if forced != "" and (KINDS.has(forced) or is_puzzle(forced)) and allowed(forced, tid):
		return forced
	if Catalog.forced != "" and is_puzzle(Catalog.forced):
		return Catalog.forced  # (the dev tool's Puzzles buttons: that puzzle is the task)
	var table := {}
	for k in KINDS:
		if allowed(k, tid):
			table[k] = float(KINDS[k].get("weight", 1.0))
	for k in Catalog.TYPES:
		table[k] = float(PUZZLE_WEIGHT["signature"] if Catalog.SIGNATURE.get(tid, "") == k else PUZZLE_WEIGHT["base"])
	var fresh := {}
	for k in table:
		if not (k in climb_used):
			fresh[k] = table[k]
	if fresh.is_empty():
		for k in table:
			if climb_used.is_empty() or k != climb_used[-1]:
				fresh[k] = table[k]
	return _weighted(fresh)


static func _weighted(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var roll := randf() * total
	for k in table:
		roll -= float(table[k])
		if roll <= 0.0:
			return k
	return table.keys()[0]


## Whether a kind needs the gallery for itself (the rune path, the wardstone).
static func wants_gallery(kind: String) -> bool:
	return kind in ["runes", "wardstone"]


# --- placing the pieces (floors.gd) ------------------------------------------------

## The task's pieces on a planned floor. `infos` are the rooms (rect, rows,
## reserved, role, theme, parent...), `adj` each room's neighbours, `monsters`
## the plan's list (guards are added to it), `stair` the stair's spot,
## `puzzle` the gallery's puzzle spec (when the task is that puzzle). Returns
## the spec objective.gd runs, or {} if it can't be placed (then the floor is
## planned again):
##   kind, name, hint, puzzle (true for a puzzle kind),
##   pieces: [{pos, room, glyph?}], tablet {pos, room}, pedestal (orb),
##   order (runes: piece indices), hold (levers), charge (wardstone),
##   guards (keeper)
static func place(kind: String, infos: Array, adj: Array, monsters: Array, stair: Vector2, floor_num: int, tid: String, puzzle: Dictionary, cell: float, pick_monster: Callable) -> Dictionary:
	var spec := {"kind": kind, "name": display_name(kind, tid), "puzzle": is_puzzle(kind), "pieces": []}
	if is_puzzle(kind):
		if puzzle.is_empty():
			return {}
		spec["hint"] = TEXT["puzzle_hint"]
		spec["pieces"] = [{"pos": Rect2(puzzle["room"]).get_center(), "room": _index_of_role(infos, "gallery")}]
		return spec
	var k: Dictionary = KINDS[kind]
	spec["hint"] = k["hint"]
	var n := count_for(kind, floor_num)
	var dist := _graph_dist(adj, 0)
	var stair_i := _index_of_role(infos, "stair")
	var gal := _index_of_role(infos, "gallery")
	# Rooms that may hold a piece: not the start, not the stair room, not a
	# room with its own test (a puzzle, a scenario, a mirror), farther first.
	var cands: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		if i == 0 or i == stair_i or info.get("no_piece", false):
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue
		cands.append(i)
	var own := module_of(kind)
	if own != null:
		# (a tower's own kind: its floor script places it, from the same rooms)
		return own.place_task(kind, spec, infos, cands, dist, monsters, floor_num, cell)
	match kind:
		"runes", "wardstone":
			if gal < 0 or infos[gal].get("puzzle", "") != "":
				return {}
			if kind == "wardstone":
				var c := _spot(infos[gal], monsters, 2, true)
				if c == Vector2.INF:
					return {}
				spec["pieces"] = [{"pos": c, "room": gal}]
				spec["charge"] = float(k["charge_base"]) + float(k["charge_per_floor"]) * floor_num
				return spec
			var glyphs: Array = k["glyphs"].duplicate()
			glyphs.shuffle()
			for j in n:
				var p := _spot(infos[gal], monsters, 1, false, spec["pieces"].map(func(x): return x["pos"]), 110.0)
				if p == Vector2.INF:
					return {}
				spec["pieces"].append({"pos": p, "room": gal, "glyph": glyphs[j]})
			var order: Array = range(n)
			order.shuffle()
			spec["order"] = order
			# The tablet: in another room on the way (never the start).
			var tab_rooms: Array = cands.filter(func(i): return i != gal)
			tab_rooms.sort_custom(func(a, b): return int(dist[a]) < int(dist[b]))
			for i in tab_rooms:
				var tp := _spot(infos[i], monsters, 1)
				if tp != Vector2.INF:
					spec["tablet"] = {"pos": tp, "room": i}
					break
			if not spec.has("tablet"):
				return {}
			return spec
		"orb":
			var far: Array = cands.duplicate()
			far.sort_custom(func(a, b): return _far_score(a, dist, adj, stair_i) > _far_score(b, dist, adj, stair_i))
			for i in far:
				var p := _spot(infos[i], monsters, 1)
				if p != Vector2.INF:
					spec["pieces"] = [{"pos": p, "room": i}]
					break
			if spec["pieces"].is_empty():
				return {}
			# The pedestal: beside the stair, in the stair room.
			var sr: Dictionary = infos[stair_i]
			var ped := Vector2.INF
			for off in [Vector2(cell * 2.5, cell * 1.5), Vector2(-cell * 2.5, cell * 1.5), Vector2(cell * 3.5, cell * 2.5), Vector2(-cell * 3.5, cell * 2.5), Vector2(0, cell * 3.5)]:
				var q: Vector2 = stair + off
				var t := Vector2i((q - Vector2(sr["rect"].position)) / cell)
				if Rooms.open_at(sr["rows"], t.x, t.y) and not sr["reserved"].has(t):
					ped = Vector2(sr["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * cell
					_reserve(sr, t, 1)
					break
			if ped == Vector2.INF:
				ped = _spot(sr, monsters, 1)
			if ped == Vector2.INF:
				return {}
			spec["pedestal"] = ped
			return spec
	# The rest spread their pieces over n rooms: far ones first, a branch among them.
	var spread := _spread(cands, n, infos, dist)
	if spread.size() < mini(n, 2) and kind != "keeper":
		return {}
	var per_room: Array = []  # how many pieces each chosen room holds
	for j in n:
		per_room.append(spread[j % spread.size()] if not spread.is_empty() else -1)
	for j in n:
		var ri: int = per_room[j]
		if ri < 0:
			return {}
		var p := _spot(infos[ri], monsters, 1, kind == "keeper", spec["pieces"].map(func(x): return x["pos"]), 90.0)
		if p == Vector2.INF:
			return {}
		spec["pieces"].append({"pos": p, "room": ri})
	match kind:
		"levers":
			# Each lever stays up long enough to walk to the others (and then some).
			var route := 0.0
			for j in range(1, spec["pieces"].size()):
				route += Vector2(spec["pieces"][j - 1]["pos"]).distance_to(spec["pieces"][j]["pos"]) * 1.45
			var walk := 150.0
			spec["hold"] = maxf(maxf(float(k["hold_base"]) - float(k["hold_per_floor"]) * floor_num, float(k["hold_min"])), route / walk * float(k["walk_share"]) + 8.0)
		"keeper":
			var guards: Array = []
			var g := step_for(k["guards"], floor_num)
			var at: Vector2 = spec["pieces"][0]["pos"]
			for j in g:
				var gp := _spot(infos[spec["pieces"][0]["room"]], monsters + guards.map(func(x): return [0, x]) + [[0, at]], 0)
				if gp != Vector2.INF:
					guards.append(gp)
			for gp in guards:
				var kind_m: String = pick_monster.call()
				monsters.append([kind_m, gp])
		"shards":
			for pc in spec["pieces"]:
				var gp := _spot(infos[pc["room"]], monsters + [[0, pc["pos"]]], 0)
				if gp != Vector2.INF:
					monsters.append([pick_monster.call(), gp])
	return spec


## The plain way to place a kind's pieces: `count_for` pieces spread over
## that many of `cands` (far rooms first, a dead end among them), one free
## spot each (a tower's floor script may use it for its own kind:
## scripts/towers/tower_floor.gd place_task). {} if they won't fit.
static func place_spread(kind: String, spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, floor_num: int) -> Dictionary:
	var n := count_for(kind, floor_num)
	var spread := _spread(cands, n, infos, dist)
	if spread.size() < mini(n, 2):
		return {}
	for j in n:
		var ri: int = spread[j % spread.size()]
		var p := _spot(infos[ri], monsters, 1, false, spec["pieces"].map(func(x): return x["pos"]), 90.0)
		if p == Vector2.INF:
			return {}
		spec["pieces"].append({"pos": p, "room": ri})
	return spec


## Up to `n` rooms, spread out: the farthest from the start first, a branch
## (a dead end) among them, no two in a row on the route if it can be helped.
static func _spread(cands: Array, n: int, infos: Array, dist: Array) -> Array:
	var order: Array = cands.duplicate()
	order.shuffle()
	order.sort_custom(func(a, b): return int(dist[a]) > int(dist[b]))
	var out: Array = []
	var branch: Array = order.filter(func(i): return infos[i]["role"] == "branch")
	if not branch.is_empty() and n >= 2:
		out.append(branch[randi() % branch.size()])
	for i in order:
		if out.size() >= n:
			break
		if i in out:
			continue
		out.append(i)
	return out


static func _far_score(i: int, dist: Array, adj: Array, stair_i: int) -> int:
	var to_stair := _graph_dist(adj, stair_i)
	return int(to_stair[i]) * 10 + int(dist[i])


## Rooms' distances (in rooms) from room `from` over `adj`.
static func _graph_dist(adj: Array, from: int) -> Array:
	var out: Array = []
	out.resize(adj.size())
	out.fill(999)
	if from < 0 or from >= adj.size():
		return out
	out[from] = 0
	var q: Array = [from]
	while not q.is_empty():
		var a: int = q.pop_front()
		for b in adj[a]:
			if int(out[b]) > int(out[a]) + 1:
				out[b] = int(out[a]) + 1
				q.append(b)
	return out


static func _index_of_role(infos: Array, role: String) -> int:
	for i in infos.size():
		if infos[i]["role"] == role:
			return i
	return -1


static func _reserve(info: Dictionary, t: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			info["reserved"][t + Vector2i(dx, dy)] = true


## A free spot in a room (world px), kept clear (a box `keep` tiles around
## it): open floor away from the doorways and set pieces, the monsters and
## `others`; near the middle if `middle`. Vector2.INF if none.
static func _spot(info: Dictionary, monsters: Array, keep: int, middle := false, others: Array = [], gap := 60.0) -> Vector2:
	var cell: float = info["rect"].size.x / float(info["size"].x)
	var tiles: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
	var size: Vector2i = info["size"]
	var mid := Vector2(size) * 0.5
	if middle:
		tiles.sort_custom(func(a, b): return Vector2(a).distance_squared_to(mid) < Vector2(b).distance_squared_to(mid))
	else:
		tiles.shuffle()
	for t in tiles:
		# (the tiles around it open too: something to walk round)
		var open := true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			open = open and Rooms.open_at(info["rows"], t.x + d.x, t.y + d.y)
		if not open:
			continue
		var pos: Vector2 = Vector2(info["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * cell
		if not monsters.all(func(m): return pos.distance_to(m[1]) > 50.0):
			continue
		if not others.all(func(o): return pos.distance_to(o) > gap):
			continue
		_reserve(info, t, keep)
		return pos
	return Vector2.INF


## Every place the task asks the climber to reach (world px): its pieces,
## the tablet, the pedestal. (reach.gd checks they can be reached; the
## traps keep clear of them.)
static func targets(spec: Dictionary) -> Array:
	var out: Array = []
	if spec.is_empty() or spec.get("puzzle", false):
		return out
	for p in spec.get("pieces", []):
		out.append(p["pos"])
	if spec.has("tablet"):
		out.append(spec["tablet"]["pos"])
	if spec.has("pedestal"):
		out.append(spec["pedestal"])
	return out
