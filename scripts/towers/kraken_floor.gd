extends Node2D
## The Kraken's tower: flooded floors (floor_styles.gd "script").
##
## LAYOUT: round and oval rooms (floor_styles.gd), corridors that wind and
## twist between them (shape_corridors: a 2-tile passage that wanders up to
## WATER "meander" tiles sideways), and pools.
##
## THE WATER: every floor is cut into BASINS, each with a water level from 0
## (dry) to 1 (brim-full) drawn in code (a level line on the north wall, a
## tide mark where it last reached, ripples):
##   tide    most rooms and corridors: the water rises and drains on its own
##           cycle, never deeper than shallow. The rooms' cycles are offset
##           along the floor, so the tide seems to roll from room to room.
##   flood   a loop corridor (a second way round) that floods deep at high
##           tide: can't be waded then (rising water sweeps you out).
##   pool    the deep middle of a round room: never waded.
##   sunken  a dead-end room under deep water, with its chest on the bottom;
##           a SLUICE WHEEL in the next room drains it (stand at the wheel),
##           sending the water into the wheel's own room for a while.
##   moat    the floor's task "sluices" (objectives.gd): the passage into the
##           stair room is flooded deep; each wheel turned lowers it a step.
## Shallow water (level WATER "shallow" and up) slows walking and soaks foes
## (main.gd in_water / water_slow); deep water (WATER "deep" and up) can't
## be crossed on foot (a body on layer 32 that the climber and walking
## monsters collide with; swimmers pass). Pools and flooding corridors never
## cut anything off (water_wind_grid.gd), so they only ever close a second
## way; a sunken room and the moat are locks (reach.gd "fluid_locks") whose
## openers are their wheels.
##
## The creature: the deepfin (deepfin.gd) swims in deep water and lunges out.
## The scenario: the Filling Room (scenarios.gd "flood"): the water comes in
## while foes come for you; turn the drain wheel at the far end in time.

const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Palette := preload("res://scripts/palette.gd")
const Enemy := preload("res://scripts/enemy.gd")
const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0  # (floors.gd CELL)
const PATH := "res://scripts/towers/kraken_floor.gd"
const DEEP_LAYER := 32  # (player.gd and enemy.gd collide with it; SWIMMERS don't)

## The water's numbers (the Data editor's "Floors" numbers).
##   shallow / deep   the levels from which water slows you / stops you
##   tide_period      seconds for a tide to rise and fall [least, most]
##   tide_high        how high a room's tide comes [least, most] (shallow)
##   tide_lag         seconds the tide lags from one room to the next
##   dry_rooms        the share of rooms that stay dry
##   flood_chance     how often a loop corridor floods deep at high tide
##   flood_high/low   a flooding corridor's tide
##   pool_chance      how often a round room has a deep pool in its middle
##   pool_margin      tiles of floor kept round a pool
##   sunken_chance    how often a floor has a sunken room (from sunken_from)
##   drain            share of the way a level moves a second toward a new one
##   spill            how high a sunken room's water lifts the wheel's room
##   spill_time       ...and for how long
##   sweep            how hard rising deep water shoves you out (px/s)
##   meander          how far a winding corridor wanders sideways (tiles)
##   wind_chance      how often a long enough corridor winds
##   moat_low         the moat's level once every wheel is turned (wadeable)
static var WATER := {
	"shallow": 0.18, "deep": 0.62,
	"tide_period": [18.0, 30.0], "tide_high": [0.34, 0.5], "tide_lag": 2.2, "dry_rooms": 0.2,
	"flood_chance": 0.75, "flood_high": 0.95, "flood_low": 0.08,
	"pool_chance": 0.8, "pool_margin": 2.2,
	"sunken_chance": 0.7, "sunken_from": 2,
	"drain": 0.55, "spill": 0.55, "spill_time": 14.0,
	"sweep": 260.0, "meander": 3, "wind_chance": 0.9, "moat_low": 0.3,
	"wheel_time": 1.6, "wheel_reach": 52.0,
}
## The words (the Data editor's "Floors" words).
static var TEXT := {
	"wheel": "Sluice wheel",
	"turning": "Turning the wheel...",
	"drains": "The water drains away",
	"spills": "The water rushes in here",
	"swept": "Swept back by the water",
	"moat": "The stairwell drains a little",
	"moat_done": "The stairwell is drained",
	"sunken": "A sunken room: its wheel is near",
}
## How the water looks.
static var LOOK := {
	"water": Color(0.16, 0.38, 0.5), "deep": Color(0.04, 0.14, 0.22), "rim": Color(0.62, 0.88, 0.95),
	"sheen": Color(0.3, 0.5, 0.55), "salt": Color(0.86, 0.9, 0.84), "wheel": Color(0.5, 0.38, 0.24), "iron": Color(0.36, 0.4, 0.44),
}

var main
var plan := {}
var basins: Array = []
var tile_basin := {}  # Vector2i -> basin index
var valves: Array = []  # sunken rooms' wheels: {pos, basin, room, t, done}
var t := 0.0
var redraw_t := 0.0
var scn_basin := -1  # the Filling Room's water while it runs


# --- planning (floors.gd) ------------------------------------------------------------

## Corridors that wind: each long enough corridor wanders sideways and back
## (2 tiles wide, 3 at a bend), in rock nothing else uses. `corridors` are
## the straight rects (one per link, in order); returns what replaces them.
## Each link gets "tiles" (its floor) and "path" (the line down its middle).
static func shape_corridors(infos: Array, links: Array, corridors: Array, walk: Array) -> Array:
	var occ := {}
	for r in walk:
		for tt in Grid.tiles_of(r):
			occ[tt] = true
	for r in corridors:
		for tt in Grid.tiles_of(r):
			occ[tt] = true
	var out: Array = []
	for li in links.size():
		var link: Dictionary = links[li]["link"]
		var cg := Grid.corridor(link, infos, int(links[li]["c"]))
		var own := {}
		for tt in Grid.tiles_of_i(link["corridor"]):
			own[tt] = true
		var tiles: Array = own.keys()
		var offs: Array = []
		var n: int = cg["len"]
		if n >= 5 and randf() < float(WATER["wind_chance"]):
			for attempt in 5:
				var amp := randi_range(2, int(WATER["meander"])) * (1 if randf() < 0.5 else -1)
				var wave := randf() < 0.45
				var o: Array = []
				for i in n:
					var u := float(i - 1) / float(n - 3)
					o.append(0 if i <= 1 or i == n - 1 else int(round(amp * (sin(TAU * u) * 0.8 if wave else sin(PI * u)))))
				for i in range(1, n):
					o[i] = clampi(o[i], o[i - 1] - 1, o[i - 1] + 1)
				o[n - 1] = 0
				for i in range(n - 2, -1, -1):
					o[i] = clampi(o[i], o[i + 1] - 1, o[i + 1] + 1)
				o[1] = 0
				var mine := {}
				var ok := true
				for i in n:
					# Each row across spans its own offset and the next one's
					# (a bend is 3 wide); both end rows stay as they were.
					var nxt: int = o[i + 1] if i < n - 1 else o[i]
					var a: int = mini(o[i], nxt)
					var b: int = maxi(o[i], nxt)
					for j in range(a, b + 2):
						var lat: int = int(cg["lat"]) + j
						var tt := Grid.at(cg, i, lat)
						mine[tt] = true
						if not own.has(tt) and (lat < int(cg["lo"]) or lat > int(cg["hi"]) or not Grid.clear_beside(tt, occ, own)):
							ok = false
				if ok and o.any(func(v): return v != 0):
					tiles = mine.keys()
					offs = o
					break
		for tt in tiles:
			occ[tt] = true
		if offs.is_empty():
			offs.resize(n)
			offs.fill(0)
		var path := PackedVector2Array()
		for i in n:
			path.append(Grid.centre(Grid.at(cg, i, int(cg["lat"]) + int(offs[i]))) + (Vector2(0, CELL * 0.5) if cg["ew"] else Vector2(CELL * 0.5, 0)))
		link["tiles"] = tiles
		link["path"] = _smooth(path)
		link["offs"] = offs
		link["wound"] = offs.any(func(v): return v != 0)
		STATS["corridors"] += 1
		STATS["long"] += 1 if n >= 5 else 0
		STATS["wound"] += 1 if link["wound"] else 0
		out.append_array(Grid.merge(tiles))
	return out


## A line's corners rounded off (two passes of corner cutting), its ends kept.
static func _smooth(p: PackedVector2Array) -> PackedVector2Array:
	var out := p
	for pass_ in 2:
		if out.size() < 3:
			return out
		var q := PackedVector2Array([out[0]])
		for i in out.size() - 1:
			q.append(out[i].lerp(out[i + 1], 0.25))
			q.append(out[i].lerp(out[i + 1], 0.75))
		q.append(out[out.size() - 1])
		out = q
	return out


## Corridors shaped so far (the tests read it): all, long enough to wind, wound.
static var STATS := {"corridors": 0, "long": 0, "wound": 0}


## The water, laid over a planned floor (see the top). Sets plan["ok"] false
## when the floor's task can't be built (then the floor is planned again).
static func finish_plan(plan: Dictionary, infos: Array, links: Array, floor_num: int, tower: Dictionary, _style: Dictionary) -> void:
	var W := WATER
	var g := Grid.grid(plan)
	var start := Grid.tile(plan["start"])
	var base := Grid.walk(g, start, {})
	var prot := Grid.protected(plan, infos)
	var used := {}
	var basins: Array = []
	var no_foot := {}
	var locks: Array = []
	var valves: Array = []
	var deg := Grid.degree(links, infos.size())
	var obj: Dictionary = plan.get("objective", {})
	var stair_i := -1
	for i in infos.size():
		if infos[i]["role"] == "stair":
			stair_i = i
	# The stair's own corridor, flooded (the task "sluices").
	if String(obj.get("kind", "")) == "sluices":
		var moat: Array = []
		var mpath := PackedVector2Array()
		for l in links:
			if int(l["c"]) == stair_i and not l.has("kind"):
				moat = _interior(l["link"], infos, stair_i)
				mpath = _inner_path(l["link"])
		if moat.size() < 6:
			plan["ok"] = false
			return
		var opens: Array = []
		for pc in obj["pieces"]:
			var pt := Grid.tile(pc["pos"])
			opens.append_array([pt, pt + Vector2i.RIGHT, pt + Vector2i.LEFT, pt + Vector2i.DOWN, pt + Vector2i.UP])
		# The moat must really shut the stair room off (the task opens it).
		var mblock := {}
		for tt in moat:
			mblock[tt] = true
		var mw := Grid.walk(g, start, mblock)
		var st := Grid.tile(plan["stair"])
		if mw[st.y * int(g["size"].x) + st.x] == 1:
			plan["ok"] = false
			return
		# ...and every wheel must be on this side of it.
		for pc in obj["pieces"]:
			if not load("res://scripts/reach.gd").near_reached(mw, g["size"], pc["pos"]):
				plan["ok"] = false
				return
		locks.append({"id": 900, "tiles": moat, "opens": {"all": opens}})
		basins.append({"kind": "moat", "tiles": moat, "room": stair_i, "shape": "channel", "path": mpath, "level": 0.92})
		for tt in moat:
			used[tt] = true
	# A sunken room (a dead end under deep water) and its wheel next door.
	if floor_num >= int(W["sunken_from"]) and randf() < float(W["sunken_chance"]):
		var cands: Array = []
		for i in infos.size():
			var info: Dictionary = infos[i]
			var th: Dictionary = load("res://scripts/themes.gd").get_theme(String(info["theme"]))
			if info["role"] != "branch" or int(deg[i]) != 1 or info.get("piece", false) or not String(th["feature"]) in ["", "den", "pillars", "post", "trap"]:
				continue
			cands.append(i)
		cands.shuffle()
		var door_prot := Grid.protected({"doors": plan.get("doors", []), "doorways": plan.get("doorways", []), "wings": plan.get("wings", []),
			"secrets": plan.get("secrets", []), "cracks": plan.get("cracks", []), "start": plan["start"], "stair": plan["stair"]}, [])
		for i in cands:
			var info: Dictionary = infos[i]
			if _holds_opener(plan, info["rect"]):
				continue
			var tiles: Array = Grid.room_tiles(info).filter(func(x): return not door_prot.has(x) and not used.has(x))
			if tiles.size() < 8:
				continue
			var block := {}
			for tt in tiles:
				block[tt] = true
			if Grid.cuts_off(g, start, base, block):
				continue
			var par := int(info["parent"])
			var vpos: Vector2 = load("res://scripts/objectives.gd")._spot(infos[par], plan["monsters"], 1)
			if vpos == Vector2.INF:
				continue
			var vt := Grid.tile(vpos)
			if used.has(vt):
				continue
			var bi := basins.size()
			basins.append({"kind": "sunken", "tiles": tiles, "room": i, "shape": "ellipse" if info["shape"] == "circle" else "tiles",
				"c": info["rect"].get_center(), "rx": info["rect"].size.x * 0.5, "ry": info["rect"].size.y * 0.5, "level": 0.9})
			valves.append({"pos": vpos, "basin": bi, "room": par})
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					prot[vt + Vector2i(dx, dy)] = true
			locks.append({"id": 901 + i, "tiles": tiles, "opens": {"any": [vt, vt + Vector2i.RIGHT, vt + Vector2i.LEFT, vt + Vector2i.DOWN, vt + Vector2i.UP]}})
			for tt in tiles:
				used[tt] = true
			plan["keep"].append(vpos)
			break
	# Deep pools in the middle of round rooms.
	for i in infos.size():
		var info: Dictionary = infos[i]
		if info["role"] in ["entrance", "stair"] or info["shape"] != "circle" or randf() > float(W["pool_chance"]):
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue
		var th: Dictionary = load("res://scripts/themes.gd").get_theme(String(info["theme"]))
		if String(th["kind"]) == "scenario" or String(th["feature"]) in ["mirror", "trap"]:
			continue
		var r: Rect2 = info["rect"]
		var rx: float = r.size.x * 0.5 - float(W["pool_margin"]) * CELL
		var ry: float = r.size.y * 0.5 - float(W["pool_margin"]) * CELL
		if rx < CELL * 0.9 or ry < CELL * 0.9:
			continue
		var c := r.get_center()
		var tiles: Array = []
		for tt in Grid.room_tiles(info):
			var q := Grid.centre(tt) - c
			if (q.x * q.x) / (rx * rx) + (q.y * q.y) / (ry * ry) <= 1.0 and not prot.has(tt) and not used.has(tt):
				tiles.append(tt)
		if tiles.size() < 3:
			continue
		var block := no_foot.duplicate()
		for tt in tiles:
			block[tt] = true
		if Grid.cuts_off(g, start, base, block):
			continue
		basins.append({"kind": "pool", "tiles": tiles, "room": i, "shape": "ellipse", "c": c, "rx": rx + CELL * 0.55, "ry": ry + CELL * 0.55, "level": 0.86})
		for tt in tiles:
			used[tt] = true
			no_foot[tt] = true
	# Loop corridors that flood deep at high tide.
	for l in links:
		if not l.has("kind") or randf() > float(W["flood_chance"]):
			continue
		var tiles: Array = _interior(l["link"], infos, int(l["c"])).filter(func(x): return not used.has(x) and not prot.has(x))
		if tiles.size() < 2:
			continue
		var block := no_foot.duplicate()
		for tt in tiles:
			block[tt] = true
		if Grid.cuts_off(g, start, base, block):
			continue
		basins.append({"kind": "flood", "tiles": tiles, "room": -1, "shape": "channel", "path": _inner_path(l["link"]),
			"low": float(W["flood_low"]), "high": float(W["flood_high"]), "period": randf_range(W["tide_period"][0], W["tide_period"][1]), "phase": randf()})
		for tt in tiles:
			used[tt] = true
			no_foot[tt] = true
	# Tides: the rest of the rooms and corridors, shallow, lagging room to room.
	var dist: Array = load("res://scripts/objectives.gd")._graph_dist(_adj(links, infos.size()), 0)
	var period := randf_range(W["tide_period"][0], W["tide_period"][1])
	for i in infos.size():
		var info: Dictionary = infos[i]
		if info["role"] == "entrance" or randf() < float(W["dry_rooms"]):
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue  # (a puzzle hall stays dry: the ice slides, the plates weigh as they should)
		var tiles: Array = Grid.room_tiles(info).filter(func(x): return not used.has(x))
		if tiles.is_empty():
			continue
		basins.append({"kind": "tide", "tiles": tiles, "room": i, "shape": "ellipse", "c": info["rect"].get_center(),
			"rx": info["rect"].size.x * 0.5, "ry": info["rect"].size.y * 0.5, "low": 0.0, "high": randf_range(W["tide_high"][0], W["tide_high"][1]),
			"period": period, "phase": -float(dist[i]) * float(W["tide_lag"]) / period})
		for tt in tiles:
			used[tt] = true
	for l in links:
		var all_tiles: Array = l["link"].get("tiles", Grid.tiles_of_i(l["link"]["corridor"]))
		var tiles: Array = all_tiles.filter(func(x): return not used.has(x))
		if tiles.is_empty():
			continue
		var d := mini(int(dist[int(l["c"])]), int(dist[int(l["p"])]))
		basins.append({"kind": "tide", "tiles": tiles, "room": -1, "shape": "channel" if tiles.size() == all_tiles.size() else "tiles", "path": l["link"].get("path", PackedVector2Array()),
			"low": 0.0, "high": randf_range(W["tide_high"][0], W["tide_high"][1]), "period": period, "phase": -(float(d) + 0.5) * float(W["tide_lag"]) / period})
		for tt in tiles:
			used[tt] = true
	# Monsters in deep water swim (deepfins go to the pools; walkers there
	# become swimmers); a deepfin with no deep water to live in is a lurker.
	var deep_spots: Array = []
	for b in basins:
		if b["kind"] in ["pool", "flood", "sunken"]:
			for tt in b["tiles"]:
				if Grid.centre(tt).distance_to(plan["start"]) > CELL * 6.0:
					deep_spots.append(tt)
	deep_spots.shuffle()
	var deep_set := {}
	for b in basins:
		if b["kind"] != "tide":
			for tt in b["tiles"]:
				deep_set[tt] = true
	for m in plan["monsters"]:
		var mt := Grid.tile(m[1])
		if m[0] == "deepfin":
			if deep_spots.is_empty():
				m[0] = "lurker"
			else:
				m[1] = Grid.centre(deep_spots.pop_back())
		elif deep_set.has(mt) and not m[0] in ["lurker", "kraken"]:
			m[0] = "deepfin" if floor_num >= 3 else "lurker"
	var all_deep: Array = deep_set.keys()
	plan["water"] = {"basins": basins, "valves": valves}
	plan["no_foot"] = Grid.merge(no_foot.keys())
	plan["fluid_locks"] = locks
	plan["no_trap"] = Grid.merge(all_deep)
	plan["tower_floor"] = PATH
	plan["pools"] = []  # (the old round puddles: this water replaces them)
	plan["wet_rooms"] = []


## A corridor's floor without its two end rows (they stay dry: doorways).
static func _interior(link: Dictionary, infos: Array, c: int) -> Array:
	var cg := Grid.corridor(link, infos, c)
	var n: int = cg["len"]
	var out: Array = []
	for tt in link.get("tiles", Grid.tiles_of_i(link["corridor"])):
		var along: int = (tt.x if cg["ew"] else tt.y) - int(cg["axis0"])
		if along >= 1 and along <= n - 2:
			out.append(tt)
	return out


static func _inner_path(link: Dictionary) -> PackedVector2Array:
	var p: PackedVector2Array = link.get("path", PackedVector2Array())
	if p.size() < 2:
		return p
	var a := p[0]
	var b := p[p.size() - 1]
	var out := PackedVector2Array()
	for q in p:
		if q.distance_to(a) >= CELL * 0.95 and q.distance_to(b) >= CELL * 0.95:
			out.append(q)
	return out


## Whether a room holds what opens a lock (a key, a lever) or a piece of the task.
static func _holds_opener(plan: Dictionary, r: Rect2) -> bool:
	for l in plan.get("locks", []):
		if l.has("pos") and r.has_point(l["pos"]):
			return true
	for p in load("res://scripts/objectives.gd").targets(plan.get("objective", {})):
		if r.has_point(p):
			return true
	# Anything else the floor asks you to reach (a mural, a camp's pack...), but its chest.
	var chests: Array = plan.get("chests", []).map(func(c): return c["pos"])
	var mons: Array = plan.get("monsters", []).map(func(m): return m[1])
	for p in load("res://scripts/floors.gd").cover_targets(plan):
		if r.has_point(p) and not p in chests and not p in mons:
			return true
	return false


static func _adj(links: Array, n: int) -> Array:
	var adj: Array = []
	for i in n:
		adj.append([])
	for l in links:
		adj[int(l["c"])].append(int(l["p"]))
		adj[int(l["p"])].append(int(l["c"]))
	return adj


# --- the scenario's plan (scenarios.gd "flood") --------------------------------------

## The Filling Room: the mark by the door, the drain wheel at the far end.
static func scn_plan(kind: String, info: Dictionary, gates: Array, _floor_num: int, cell: float) -> Dictionary:
	var rect: Rect2 = info["rect"]
	var open: Array = load("res://scripts/rooms.gd").open_tiles(info["rows"], 1).filter(func(x): return not info["reserved"].has(x))
	if open.size() < 12 or gates.is_empty():
		return {}
	var at := func(x: Vector2i) -> Vector2: return rect.position + (Vector2(x) + Vector2(0.5, 0.5)) * cell
	var door: Vector2 = ORIGIN + (Vector2(gates[0][0]) + Vector2(0.5, 0.5)) * cell
	open.sort_custom(func(a, b): return at.call(a).distance_to(door) < at.call(b).distance_to(door))
	var s: Vector2 = at.call(open[mini(2, open.size() - 1)])
	var e: Vector2 = at.call(open[-1])
	if s.distance_to(e) < cell * 4.0:
		return {}
	var spawns: Array = []
	for x in open:
		var p: Vector2 = at.call(x)
		if p.distance_to(s) > cell * 2.5 and p.distance_to(e) > cell * 1.5:
			spawns.append(p)
	spawns.shuffle()
	var tiles: Array = Grid.room_tiles(info)
	return {"kind": kind, "rect": rect, "start": s, "end": e, "wheel": e, "centre": rect.get_center(), "spawns": spawns.slice(0, 8),
		"gates": gates, "keep": [s, e], "tiles": tiles, "ellipse": info["shape"] == "circle"}


# --- in play (main.gd) ----------------------------------------------------------------

var water_layer: Node2D  # the water itself, drawn into the room's look under the pillars (room.gd)


func _ready() -> void:
	z_index = -3  # (the wheels: over the floor, under the climber)


func _exit_tree() -> void:
	if water_layer != null and is_instance_valid(water_layer):
		water_layer.queue_free()


func setup(p: Dictionary) -> void:
	plan = p
	water_layer = Node2D.new()
	water_layer.draw.connect(_draw_water)
	if main.room_view != null:
		main.room_view.add_child(water_layer)
		main.room_view.move_child(water_layer, 0)  # (over the floor, under pillars and torches)
	else:
		add_child(water_layer)
	var water: Dictionary = p.get("water", {})
	for b0 in water.get("basins", []):
		_add_basin(b0.duplicate(true))
	for v in water.get("valves", []):
		var vv: Dictionary = v.duplicate()
		vv["t"] = 0.0
		vv["done"] = false
		valves.append(vv)
	_tick_levels(0.0, true)
	queue_redraw()


func _add_basin(b: Dictionary) -> int:
	var bi := basins.size()
	b["id"] = bi
	b["deep"] = false
	if not b.has("level"):
		b["level"] = 0.0
	b["mark"] = b["level"]  # the highest it has come (the tide mark)
	b["target"] = b.get("target", -1.0)
	b["spill_t"] = 0.0
	b["swept"] = false
	b["rects"] = Grid.merge(b["tiles"])
	for tt in b["tiles"]:
		tile_basin[tt] = bi
	if b["kind"] in ["pool", "flood", "sunken", "moat"]:
		var body := StaticBody2D.new()
		body.collision_layer = DEEP_LAYER
		body.collision_mask = 0
		var shapes: Array = []
		for r in b["rects"]:
			var cs := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = r.size
			cs.shape = box
			cs.position = r.get_center()
			cs.disabled = true
			body.add_child(cs)
			shapes.append(cs)
		add_child(body)
		b["body"] = body
		b["shapes"] = shapes
	basins.append(b)
	return bi


func _process(delta: float) -> void:
	if main == null or not is_same(main.floor_plan, plan):
		return
	t += delta
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()
		if water_layer != null:
			water_layer.queue_redraw()


func _physics_process(delta: float) -> void:
	if main == null or main.player == null or not is_same(main.floor_plan, plan):
		return
	_tick_levels(delta, false)
	_tick_valves(delta)
	# Something the task needs that fell into deep water (a dropped orb, a
	# key) washes up on the nearest bank.
	var ob = main.objective
	if ob != null and ob.kind == "orb" and not ob.carried and not ob.pieces.is_empty() and deep_at(ob.pieces[0]["pos"]):
		var bi: int = tile_basin.get(Grid.tile(ob.pieces[0]["pos"]), -1)
		var dry := _nearest_dry(ob.pieces[0]["pos"], bi)
		if dry != Vector2.INF:
			ob.pieces[0]["pos"] = dry


## Levels move: tides on their cycles, the rest toward their targets; deep
## water turns solid (and its tiles leave the monsters' paths) or opens.
func _tick_levels(delta: float, first: bool) -> void:
	var W := WATER
	var now := t + delta
	for b in basins:
		match String(b["kind"]):
			"tide", "flood":
				var k := 0.5 - 0.5 * cos(TAU * (now / float(b["period"]) + float(b["phase"])))
				var high: float = b["high"]
				if b["spill_t"] > 0.0:
					b["spill_t"] -= delta
					high = maxf(high, float(W["spill"]))
					k = maxf(k, clampf(b["spill_t"] / 3.0, 0.0, 1.0))
				var want: float = lerpf(float(b["low"]), high, k)
				b["level"] = want if first else move_toward(b["level"], want, delta * 0.4)
			_:
				if float(b["target"]) >= 0.0:
					b["level"] = move_toward(b["level"], float(b["target"]), delta * maxf(0.08, absf(b["level"] - float(b["target"])) * float(W["drain"]) + 0.03))
		b["mark"] = maxf(b["mark"], b["level"])
		var deep: bool = b.has("body") and b["level"] >= float(W["deep"])
		if deep != b["deep"] or first:
			b["deep"] = deep
			b["swept"] = deep and not first and _anyone_in(b)
			_set_solid(b, deep and not b["swept"])
			if b["swept"]:
				main.fx_text(main.player.global_position + Vector2(0, -40), TEXT["swept"], LOOK["rim"])
		if b["swept"]:
			# Rising deep water: shove whoever stands in it out, then close.
			if not _anyone_in(b):
				b["swept"] = false
				_set_solid(b, true)
			else:
				_sweep(b, delta)


func _set_solid(b: Dictionary, on: bool) -> void:
	for cs in b.get("shapes", []):
		cs.set_deferred("disabled", not on)
	if main.astar != null:
		for tt in b["tiles"]:
			var lt: Vector2i = main._tile_of(Grid.centre(tt))
			if main.astar.region.has_point(lt) and not main._is_solid_tile(lt.x, lt.y):
				main.astar.set_point_solid(lt, on)


func _anyone_in(b: Dictionary) -> bool:
	if tile_basin.get(Grid.tile(main.player.global_position), -1) == int(b["id"]):
		return true
	for e in main.enemies():
		if not e.kind in Enemy.SWIMMERS and not e.kind in Enemy.FLIERS and tile_basin.get(Grid.tile(e.global_position), -1) == int(b["id"]):
			return true
	return false


func _sweep(b: Dictionary, delta: float) -> void:
	var bodies: Array = [main.player]
	for e in main.enemies():
		if not e.kind in Enemy.SWIMMERS and not e.kind in Enemy.FLIERS:
			bodies.append(e)
	for who in bodies:
		var at: Vector2 = who.global_position
		if tile_basin.get(Grid.tile(at), -1) != int(b["id"]):
			continue
		var dry := _nearest_dry(at, int(b["id"]))
		if dry != Vector2.INF:
			who.knock = (dry - at).normalized() * float(WATER["sweep"])
	if randf() < 8.0 * delta:
		main.fx_burst(main.player.global_position, Vector2.UP, LOOK["rim"], 2, 60.0)


func _nearest_dry(at: Vector2, bi: int) -> Vector2:
	var t0 := Grid.tile(at)
	var best := Vector2.INF
	var best_d := INF
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var tt := t0 + Vector2i(dx, dy)
				if tile_basin.get(tt, -1) == bi or main.is_solid(Grid.centre(tt)):
					continue
				var d := Grid.centre(tt).distance_squared_to(at)
				if d < best_d:
					best_d = d
					best = Grid.centre(tt)
		if best != Vector2.INF:
			return best
	return best


## A sunken room's wheel: stand at it until it turns; the room drains and
## its water spills into the wheel's room.
func _tick_valves(delta: float) -> void:
	var p = main.player
	if p.dead:
		return
	for v in valves:
		if v["done"]:
			continue
		if p.global_position.distance_to(v["pos"]) < float(WATER["wheel_reach"]):
			if v["t"] <= 0.0:
				main.fx_text(v["pos"] + Vector2(0, -34), TEXT["turning"], LOOK["rim"])
			v["t"] += delta
			if randf() < 6.0 * delta:
				main.sfx("lock_turn", randf_range(0.8, 1.0), -14.0, 0.0)
			if v["t"] >= float(WATER["wheel_time"]):
				v["done"] = true
				var b: Dictionary = basins[int(v["basin"])]
				b["target"] = 0.04
				_spill(int(v["room"]))
				main.fx_text(v["pos"] + Vector2(0, -40), TEXT["drains"], LOOK["rim"])
				main.sfx("wave", 0.8, -4.0, 0.0)
				main.shake(2.0)
		else:
			v["t"] = maxf(0.0, v["t"] - delta * 2.0)


## Water sent into a room: its tide rises past its usual mark for a while.
func _spill(room: int) -> void:
	for b in basins:
		if int(b["room"]) == room and b["kind"] == "tide":
			b["spill_t"] = float(WATER["spill_time"])
			main.fx_text(Vector2(b["c"]) + Vector2(0, -20), TEXT["spills"], LOOK["rim"])
			return


# --- what the rest of the game asks ---------------------------------------------------

## Shallow water here (main.gd in_water: slows walking, soaks foes).
func wet(pos: Vector2) -> bool:
	var bi: int = tile_basin.get(Grid.tile(pos), -1)
	if bi < 0:
		return false
	var b: Dictionary = basins[bi]
	if b["level"] < float(WATER["shallow"]):
		return false
	if b["kind"] in ["tide", "scenario"] and b.get("shape", "") == "ellipse":
		var f := _cover(b)
		var q: Vector2 = pos - Vector2(b["c"])
		return (q.x * q.x) / pow(float(b["rx"]) * f, 2) + (q.y * q.y) / pow(float(b["ry"]) * f, 2) <= 1.0
	return true


## Deep water here (swimmers live in it; nobody wades it).
func deep_at(pos: Vector2) -> bool:
	var bi: int = tile_basin.get(Grid.tile(pos), -1)
	return bi >= 0 and basins[bi]["deep"]


## The middle of the deep tile nearest `pos` within `reach` px (INF if none).
func nearest_deep(pos: Vector2, reach := 400.0) -> Vector2:
	var best := Vector2.INF
	var best_d := reach * reach
	for b in basins:
		if not b["deep"]:
			continue
		for tt in b["tiles"]:
			var c := Grid.centre(tt)
			var d := c.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = c
	return best


## The deep tile in the same water as `from` that comes nearest `toward`.
func deep_toward(from: Vector2, toward: Vector2) -> Vector2:
	var bi: int = tile_basin.get(Grid.tile(from), -1)
	if bi < 0 or not basins[bi]["deep"]:
		return nearest_deep(from)
	var best := from
	var best_d := INF
	for tt in basins[bi]["tiles"]:
		var c := Grid.centre(tt)
		var d := c.distance_squared_to(toward)
		if d < best_d:
			best_d = d
			best = c
	return best


## Tiles nobody can walk on right now (the floor bot keeps off them).
func no_foot_tiles() -> Array:
	var out: Array = []
	for b in basins:
		if b["deep"]:
			for tt in b["tiles"]:
				out.append(main._tile_of(Grid.centre(tt)))
	return out


func bot_steer(_pos: Vector2, d: Vector2) -> Vector2:
	return d


## The floor bot's next step for the task (tests/floor_bot_driver.gd).
func bot_step(bot) -> Dictionary:
	var ob = main.objective
	if ob.kind != "sluices" or ob.done:
		return {}
	var pos: Vector2 = main.player.global_position
	var best := {}
	var best_d := INF
	for pc in ob.pieces:
		if pc["state"] == "done":
			continue
		var d: float = bot._path_len(pos, pc["pos"])
		if d < best_d:
			best_d = d
			best = pc
	if best.is_empty():
		return {}
	return {"pos": best["pos"], "act": "stand", "r": 14.0, "why": "a sluice wheel"}


# --- the task (objectives.gd "sluices") -----------------------------------------------

func task_tick(ob, delta: float, p, hurt: bool) -> void:
	var k: Dictionary = ob._k()
	for pc in ob.pieces:
		if pc["state"] == "done":
			continue
		if p.global_position.distance_to(pc["pos"]) < float(k["reach"]):
			if hurt:
				pc["t"] = 0.0
			pc["state"] = "doing"
			pc["t"] += delta
			if randf() < 6.0 * delta:
				main.sfx("lock_turn", randf_range(0.8, 1.0), -14.0, 0.0)
			if pc["t"] >= float(k["turn_time"]):
				ob._piece_done(pc)
				_moat_step(ob)
		elif pc["state"] == "doing":
			pc["state"] = "todo"
			pc["t"] = maxf(0.0, pc["t"] - delta * 2.0)


func task_strike(_ob, _from: Vector2, _dir: Vector2, _reach: float, _arc: float) -> void:
	pass


func _moat_step(ob) -> void:
	var n: int = ob.pieces.size()
	var done: int = ob.done_count()
	for b in basins:
		if b["kind"] == "moat":
			b["target"] = lerpf(0.92, float(WATER["moat_low"]), float(done) / float(maxi(n, 1)))
			if done >= n:
				b["target"] = float(WATER["moat_low"])
				main.fx_text(main.player.global_position + Vector2(0, -56), TEXT["moat_done"], LOOK["rim"])
			else:
				main.fx_text(main.player.global_position + Vector2(0, -56), TEXT["moat"], LOOK["rim"])
			main.sfx("wave", 0.7 + 0.1 * done, -4.0, 0.0)


# --- the Filling Room (scenarios.gd "flood") ------------------------------------------

func scn_begin(scn, s: Dictionary) -> void:
	scn._seal(s)
	var prev := {}
	for tt in s["tiles"]:
		if tile_basin.has(tt):
			prev[tt] = tile_basin[tt]
	var b := {"kind": "scenario", "tiles": s["tiles"], "room": -1, "shape": "ellipse" if s.get("ellipse", false) else "tiles",
		"c": s["rect"].get_center(), "rx": s["rect"].size.x * 0.5, "ry": s["rect"].size.y * 0.5, "level": 0.0, "prev": prev}
	scn_basin = _add_basin(b)
	s["wheel_t"] = 0.0
	s["wave_t"] = 2.5
	s["hits_seen"] = 0
	var cfg: Dictionary = scn.SCENARIOS["flood"]
	s["fill"] = maxf(float(cfg["fill_min"]), float(cfg["fill"]) + float(cfg["fill_per_floor"]) * main.floor_num)
	main.sfx("wave", 0.6, -2.0, 0.0)


func scn_tick(scn, s: Dictionary, delta: float, p) -> void:
	var cfg: Dictionary = scn.SCENARIOS["flood"]
	if scn_basin < 0:
		scn._finish(s, "none")
		return
	var b: Dictionary = basins[scn_basin]
	b["level"] = minf(1.0, b["level"] + delta / float(s["fill"]))
	b["mark"] = b["level"]
	s["wave_t"] -= delta
	if s["wave_t"] <= 0.0 and b["level"] < 0.9:
		s["wave_t"] = float(cfg["wave_every"])
		for k in int(cfg["per_wave"]) + main.floor_num / 5:
			scn._spawn(s, 2.0, "lurker" if randf() < 0.6 else "")
	# A blow knocks your hands off the wheel: it slips back a little.
	if int(s["hits"]) > int(s["hits_seen"]):
		s["hits_seen"] = s["hits"]
		s["wheel_t"] = maxf(0.0, s["wheel_t"] - 1.0)
	if p.global_position.distance_to(s["wheel"]) < float(WATER["wheel_reach"]):
		s["wheel_t"] += delta
		if randf() < 6.0 * delta:
			main.sfx("lock_turn", randf_range(0.7, 0.9), -12.0, 0.0)
	if s["wheel_t"] >= float(cfg["turn"]):
		var hits: int = s["hits"]
		var grade := "bronze"
		if hits <= int(cfg["gold_hits"]) and b["level"] <= float(cfg["gold_level"]):
			grade = "gold"
		elif hits <= int(cfg["silver_hits"]):
			grade = "silver"
		_scn_drain()
		main.sfx("wave", 0.8, -2.0, 0.0)
		scn._finish(s, grade)
	elif b["level"] >= 1.0:
		p.receive_attack(15.0, null, true)
		_scn_drain()
		scn._finish(s, "none", scn.TEXT["flood_full"])


## The scenario's water runs off; the room's own tide takes its tiles back.
func _scn_drain() -> void:
	if scn_basin < 0:
		return
	var b: Dictionary = basins[scn_basin]
	b["target"] = 0.0
	b["kind"] = "scenario_done"
	for tt in b["tiles"]:
		if b["prev"].has(tt):
			tile_basin[tt] = b["prev"][tt]
		else:
			tile_basin.erase(tt)
	scn_basin = -1


func scn_status(s: Dictionary) -> Dictionary:
	var S = load("res://scripts/scenarios.gd")
	var lvl: float = basins[scn_basin]["level"] if scn_basin >= 0 else 0.0
	var k := clampf(s.get("wheel_t", 0.0) / float(S.SCENARIOS["flood"]["turn"]), 0.0, 1.0)
	return {"title": S.TEXT["flood"], "line": S.TEXT["flood_line"] % [int(lvl * 100.0), int(k * 100.0)]}


func scn_goal(s: Dictionary) -> Vector2:
	return s["wheel"]


# --- drawing --------------------------------------------------------------------------

## How far a room's tide has spread across it (0..1 of its outline).
func _cover(b: Dictionary) -> float:
	if not b["kind"] in ["tide", "scenario", "scenario_done"]:
		return 1.0
	var high: float = maxf(float(b.get("high", 1.0)), 0.01) if b["kind"] == "tide" else 1.0
	return clampf(sqrt(clampf(b["level"] / high, 0.0, 1.0)) * 1.08, 0.0, 1.15)


## The wheels (over the floor and the water).
func _draw() -> void:
	if main == null:
		return
	for v in valves:
		_draw_wheel(v["pos"], v["done"], clampf(v["t"] / float(WATER["wheel_time"]), 0.0, 1.0))
	var ob = main.objective
	if ob != null and ob.kind == "sluices":
		var k: Dictionary = ob._k()
		for pc in ob.pieces:
			_draw_wheel(pc["pos"], pc["state"] == "done", clampf(pc["t"] / float(k["turn_time"]), 0.0, 1.0))
	if main.scenarios != null:
		var cfg: Dictionary = main.scenarios.SCENARIOS["flood"]
		for s in main.scenarios.list:
			if s["kind"] == "flood":
				_draw_wheel(s["wheel"], s["state"] == "done" and s["grade"] != "none", clampf(s.get("wheel_t", 0.0) / float(cfg["turn"]), 0.0, 1.0))


## The water (into the room's look: water_layer).
func _draw_water() -> void:
	if main == null:
		return
	var view: Rect2 = main.room_view._view_rect() if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	# The shallow tides first: deep water (pools, floods, sunken rooms) lies over them.
	for b in basins.filter(func(x): return x["kind"] == "tide") + basins.filter(func(x): return x["kind"] != "tide"):
		if b["rects"].is_empty():
			continue
		var bound: Rect2 = b["rects"][0]
		for r in b["rects"]:
			bound = bound.merge(r)
		if not view.intersects(bound.grow(80.0)):
			continue
		_draw_basin(water_layer, b)


func _draw_basin(cv: CanvasItem, b: Dictionary) -> void:
	var W := WATER
	var lvl: float = b["level"]
	var deep: bool = lvl >= float(W["deep"])
	var k := clampf((lvl - float(W["shallow"])) / (1.0 - float(W["shallow"])), 0.0, 1.0)
	var col: Color = LOOK["water"].lerp(LOOK["deep"], k)
	col.a = 0.3 + 0.55 * k if lvl >= float(W["shallow"]) else lerpf(0.08, 0.3, lvl / float(W["shallow"]))
	var rim: Color = Color(LOOK["rim"], 0.25 + 0.45 * k)
	var shape := String(b.get("shape", "tiles"))
	if lvl < 0.015:
		col = Color(LOOK["sheen"], 0.07)  # (wet stone where the water was)
	if b["kind"] in ["pool", "sunken"]:
		shape = "blob"
	match shape:
		"blob":
			_blob(cv, b, col, rim)
		"ellipse":
			var f := _cover(b)
			var c: Vector2 = b["c"]
			if b["kind"] in ["scenario", "scenario_done"]:
				for r in b["rects"]:
					cv.draw_rect(r, col)
			else:
				_ellipse(cv, c, float(b["rx"]) * f, float(b["ry"]) * f, col)
				_ellipse_line(cv, c, float(b["rx"]) * f, float(b["ry"]) * f, rim, 2.0)
			# The tide mark: a crust of salt where it last reached.
			if b["kind"] == "tide" and b["mark"] > lvl + 0.04:
				var fm := clampf(sqrt(clampf(b["mark"] / maxf(float(b.get("high", 1.0)), 0.01), 0.0, 1.0)) * 1.08, 0.0, 1.15)
				_ellipse_line(cv, c, float(b["rx"]) * fm, float(b["ry"]) * fm, Color(LOOK["salt"], 0.25), 2.0)
		"channel":
			var path: PackedVector2Array = b.get("path", PackedVector2Array())
			if path.size() >= 2:
				var w := CELL * (0.9 + 1.0 * clampf(lvl / 0.5, 0.0, 1.0)) if b["kind"] == "tide" else CELL * 1.95
				cv.draw_polyline(path, col, w)
				for q in path:
					cv.draw_circle(q, w * 0.5, col)
				if lvl >= float(W["shallow"]):
					_edges(cv, path, w, rim)
			else:
				for r in b["rects"]:
					cv.draw_rect(r, col)
		_:
			for r in b["rects"]:
				cv.draw_rect(r, col)
	if lvl >= float(W["shallow"]):
		_ripples(cv, b, k, deep)
	_level_line(cv, b)


## Deep water over exactly its tiles, its outline rounded: a disc on every
## tile (they overlap into one sheet) and a scalloped bank where it ends.
func _blob(cv: CanvasItem, b: Dictionary, col: Color, rim: Color) -> void:
	var own := {}
	for tt in b["tiles"]:
		own[tt] = true
	# (opaque, blended over the stone beforehand: the overlapping discs mustn't darken)
	var solid_col: Color = Palette.FLOOR.lerp(Color(col, 1.0), col.a)
	solid_col.a = 1.0
	var m := CELL * 0.3
	for tt in b["tiles"]:
		var c := Grid.centre(tt)
		var r := Rect2(c - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
		var l := 0.0 if own.has(tt + Vector2i.LEFT) else m
		var rr := 0.0 if own.has(tt + Vector2i.RIGHT) else m
		var u := 0.0 if own.has(tt + Vector2i.UP) else m
		var dn := 0.0 if own.has(tt + Vector2i.DOWN) else m
		cv.draw_rect(Rect2(r.position + Vector2(l, u), r.size - Vector2(l + rr, u + dn)), solid_col)
		if l + rr + u + dn > 0.0:
			cv.draw_circle(c, CELL * 0.62, solid_col)
	for tt in b["tiles"]:
		var c := Grid.centre(tt)
		for d in Grid.N4:
			if not own.has(tt + d):
				var a := Vector2(d).angle()
				cv.draw_arc(c, CELL * 0.62 - 1.0, a - 0.8, a + 0.8, 8, rim, 2.0)


## The two banks of a channel, wavering.
func _edges(cv: CanvasItem, path: PackedVector2Array, w: float, col: Color) -> void:
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in path.size():
			var a: Vector2 = path[maxi(i - 1, 0)]
			var b: Vector2 = path[mini(i + 1, path.size() - 1)]
			var n := (b - a).normalized().orthogonal()
			pts.append(path[i] + n * sgn * (w * 0.5 - 2.0 + sin(t * 1.6 + i * 1.3) * 1.5))
		cv.draw_polyline(pts, col, 1.5)


## Rings spreading on the surface, a few per basin.
func _ripples(cv: CanvasItem, b: Dictionary, k: float, deep: bool) -> void:
	var tiles: Array = b["tiles"]
	var n := mini(tiles.size(), 2 + tiles.size() / 8)
	var f := _cover(b)
	for i in n:
		var tt: Vector2i = tiles[(i * 7919 + int(b["id"]) * 31) % tiles.size()]
		var ph := fmod(t * (0.35 + 0.1 * (i % 3)) + float(i) * 0.37 + float(b["id"]) * 0.13, 1.0)
		var c := Grid.centre(tt) + Vector2(sin(i * 2.3) * 9.0, cos(i * 1.7) * 9.0)
		if b.get("shape", "") == "ellipse" and b["kind"] == "tide":
			var q: Vector2 = c - Vector2(b["c"])
			if (q.x * q.x) / pow(float(b["rx"]) * f, 2) + (q.y * q.y) / pow(float(b["ry"]) * f, 2) > 0.75:
				continue
		cv.draw_arc(c, 4.0 + ph * (16.0 if deep else 11.0), 0.0, TAU, 18, Color(LOOK["rim"], (0.3 + 0.3 * k) * sin(ph * PI)), 1.5)
	if deep:
		# Glints drifting on deep water.
		for i in mini(tiles.size(), 4):
			var tt: Vector2i = tiles[(i * 104729 + int(b["id"])) % tiles.size()]
			var c := Grid.centre(tt) + Vector2(sin(t * 0.7 + i) * 10.0, cos(t * 0.5 + i * 2.0) * 6.0)
			cv.draw_line(c, c + Vector2(8, -1), Color(1, 1, 1, 0.16 + 0.1 * sin(t * 2.0 + i)), 1.5)


## A room's level line: on the north wall's face (room.gd draws it on the
## rock tile above the room's top row), the water's height and, above it,
## the tide mark where it last stood, with salt stains running down.
func _level_line(cv: CanvasItem, b: Dictionary) -> void:
	if int(b["room"]) < 0 or b["kind"] in ["moat", "pool"] or main.room_info.size() <= int(b["room"]):
		return
	var info: Dictionary = main.room_info[int(b["room"])]
	var row0: String = info["rows"][0]
	var r: Rect2 = info["rect"]
	var face := CELL * 0.65
	var h: float = clampf(b["level"], 0.0, 1.0) * face * 0.9
	var hm: float = clampf(b["mark"], 0.0, 1.0) * face * 0.9
	for x in row0.length():
		if row0[x] == "X" or row0[x] == "#":
			continue
		var left := r.position.x + x * CELL
		var y := r.position.y
		if not main.is_solid(Vector2(left + CELL * 0.5, y - CELL * 0.5)):
			continue  # (a doorway: no wall here)
		if h > 1.0:
			cv.draw_rect(Rect2(left, y - h, CELL, h), Color(LOOK["water"], 0.5))
			cv.draw_line(Vector2(left, y - h), Vector2(left + CELL, y - h), Color(LOOK["rim"], 0.75), 1.5)
		if hm > h + 2.0:
			cv.draw_line(Vector2(left, y - hm), Vector2(left + CELL, y - hm), Color(LOOK["salt"], 0.5), 1.5)
			for i in 2:
				var sx := left + 10.0 + i * 20.0
				cv.draw_line(Vector2(sx, y - hm), Vector2(sx, y - hm + 4.0 + 3.0 * sin(x * 3.1 + i)), Color(LOOK["salt"], 0.25), 1.0)


func _ellipse(cv: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 2.0 or ry < 2.0:
		return
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	cv.draw_colored_polygon(pts, col)


func _ellipse_line(cv: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	if rx < 2.0 or ry < 2.0:
		return
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		var wob := 1.0 + sin(t * 1.3 + i * 0.9) * 0.008
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * wob)
	cv.draw_polyline(pts, col, w)


## A sluice wheel on its post: spokes turn as you turn it.
func _draw_wheel(c: Vector2, done: bool, k: float) -> void:
	var spin := k * TAU * 1.5 + (t * 0.6 if done else 0.0)
	var hub := c + Vector2(0, -6)
	draw_circle(c + Vector2(0, 10), 13.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(c + Vector2(-3, -2), Vector2(6, 14)), LOOK["iron"].darkened(0.3))
	draw_arc(hub, 13.0, 0.0, TAU, 24, Palette.OUTLINE, 6.0)
	draw_arc(hub, 13.0, 0.0, TAU, 24, LOOK["wheel"], 3.5)
	for i in 4:
		var a := spin + i * TAU / 4.0
		draw_line(hub, hub + Vector2.from_angle(a) * 13.0, LOOK["wheel"].darkened(0.2), 2.5)
		draw_circle(hub + Vector2.from_angle(a) * 15.5, 2.0, LOOK["wheel"].darkened(0.1))
	draw_circle(hub, 3.5, LOOK["iron"])
	if done:
		draw_arc(hub, 19.0, 0.0, TAU, 24, Color(LOOK["rim"], 0.5), 2.0)
	elif k > 0.0:
		draw_arc(hub, 20.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(1.0, 0.86, 0.5, 0.9), 3.0)
