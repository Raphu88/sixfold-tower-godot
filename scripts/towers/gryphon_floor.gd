extends Node2D
## The Gryphon's tower: open heights (floor_styles.gd "script").
##
## LAYOUT: big open halls (floor_styles.gd) with ledges and balconies over
## open VOIDS, and corridors that are BRIDGES: the rock beside each long
## corridor falls away (shape_corridors), so you cross a narrow walkway over
## the drop. Halls get one of three set pieces (VOIDS "designs"):
##   well    a round drop in the middle, a balcony all round it, sometimes a
##           bridge straight across
##   ledge   one side of the hall falls away (the side with no doorway)
##   span    a band of drop right across the hall, one narrow bridge over it
## SEEING DOWN: through every void you see the floors below, drawn in code:
## two layers of the floor's own halls, smaller and dimmer the deeper they
## are, sliding with parallax as you move, with tiny shapes walking them.
## FALLING off an edge drops you to the floor below (main.gd fall_through:
## "YOU FELL"). Voids are main.gd chasms (you fall in unless jumping; walking
## monsters keep out), and they never cut anything off (water_wind_grid.gd).
##
## WIND: across open spans the wind gusts (GUST): streaks show which way a
## moment before, then it shoves whoever stands near a drop (the climber and
## foes) that way. Brace by walking against it. A foe thrown into the air
## (airborne) is carried over the edge by it, and a flier stunned over a
## void (a parried harrier or bat) drops.
##
## The task "vanes" (objectives.gd): the way into the stair room is an open
## gap with no bridge; strike each wind vane round and a steady wind blows
## across the gap, and you walk over on it.
## The creature: the harrier (harrier.gd). The scenario: the Long Bridge
## (scenarios.gd "bridge").

const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Palette := preload("res://scripts/palette.gd")
const Enemy := preload("res://scripts/enemy.gd")
const ORIGIN := Vector2(80, 100)
const CELL := 40.0
const PATH := "res://scripts/towers/gryphon_floor.gd"

## The voids' numbers (the Data editor's "Floors" numbers).
##   flank        [least, most] tiles of drop beside a bridge, each side
##   bridge_len   the shortest corridor that becomes a bridge
##   room_chance  how often a hall gets a set piece of drop
##   designs      how likely each set piece is
##   well_margin  tiles of balcony kept round a well
##   well_bridge  how often a well has a bridge across it
##   ledge        [least, most] tiles deep a ledge's drop is
##   span         [least, most] tiles wide a span is
static var VOIDS := {
	"flank": [1, 3], "bridge_len": 4, "room_chance": 0.8,
	"designs": {"well": 3.0, "ledge": 3.0, "span": 2.0},
	"well_margin": 2.2, "well_bridge": 0.45, "ledge": [2, 3], "span": [2, 3],
}
## The wind (the Data editor's "Floors" numbers).
##   every        seconds between gusts [least, most]
##   warn         seconds the streaks show before it blows
##   blow         seconds it blows
##   force        how hard it shoves (px/s), and per floor more
##   reach        tiles from a drop where it reaches you
static var GUST := {"every": [6.0, 9.5], "warn": 1.2, "blow": 1.5, "force": 105.0, "force_per_floor": 3.0, "reach": 2}
## The words.
static var TEXT := {
	"gust": "Wind!",
	"vane": "Wind vane",
	"vane_turned": "The vane swings round",
	"wind_bridge": "The wind blows across the gap",
	"fell": "Falls!",
}
static var LOOK := {
	"sky": Color(0.05, 0.07, 0.12), "lower": Color(0.42, 0.44, 0.52), "lower_edge": Color(0.7, 0.74, 0.86),
	"cliff": Color(0.16, 0.15, 0.18), "rim": Color(0.82, 0.86, 0.96), "plank": Color(0.5, 0.38, 0.26), "rope": Color(0.72, 0.62, 0.45),
	"wind": Color(0.86, 0.93, 1.0), "vane": Color(0.62, 0.6, 0.66),
}

var main
var plan := {}
var voids := {}  # Vector2i -> true: open drop
var span := {}  # Vector2i -> true: the stair's gap (vanes)
var span_open := false
var exposed := {}  # Vector2i -> true: floor near a drop, where the wind reaches
var void_rects: Array = []
var air_rects: Array = []  # open air beyond the halls' walls (drawn as sky; solid rock to walk)
var air_set := {}
var solid_seen := PackedByteArray()  # the rock when the air was worked out
var air_t := 0.5
var bridge_tiles: Array = []  # walkways between drops: drawn as planks
var lower: Array = []  # the floor's halls and corridors, for the floors below
var t := 0.0
var redraw_t := 0.0
# The wind: "calm", "warn" or "blow"; its way and strength.
var gust_state := "calm"
var gust_t := 4.0
var gust_dir := Vector2.RIGHT
var gust_force := 100.0
var forced := {}  # a scenario's gust: {dir, force}
var streaks: Array = []
var scn_t := 0.0


# --- planning (floors.gd) ------------------------------------------------------------

## Bridges: the rock beside each long corridor falls away. Each link gets
## "tiles" (its floor and the drop beside it), "flank" (the drop) and "path".
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
		var flank: Array = []
		var n: int = cg["len"]
		if n >= int(VOIDS["bridge_len"]):
			var want := randi_range(int(VOIDS["flank"][0]), int(VOIDS["flank"][1]))
			for i in range(1, n - 1):
				for sgn in [-1, 1]:
					for k in want:
						var lat: int = (int(cg["lat"]) - 1 - k) if sgn < 0 else (int(cg["lat"]) + 2 + k)
						if lat < int(cg["lo"]) or lat > int(cg["hi"]):
							break
						var tt := Grid.at(cg, i, lat)
						if not Grid.clear_beside(tt, occ, own):
							break
						own[tt] = true
						flank.append(tt)
		for tt in own:
			occ[tt] = true
		link["tiles"] = own.keys()
		link["flank"] = flank
		var a := Grid.centre(Grid.at(cg, 0, int(cg["lat"]))) + (Vector2(0, CELL * 0.5) if cg["ew"] else Vector2(CELL * 0.5, 0))
		var b := Grid.centre(Grid.at(cg, n - 1, int(cg["lat"]))) + (Vector2(0, CELL * 0.5) if cg["ew"] else Vector2(CELL * 0.5, 0))
		link["path"] = PackedVector2Array([a, b])
		out.append_array(Grid.merge(own.keys()))
	return out


## The drops, laid over a planned floor (see the top). Sets plan["ok"] false
## when the floor's task can't be built (then the floor is planned again).
static func finish_plan(plan: Dictionary, infos: Array, links: Array, floor_num: int, _tower: Dictionary, _style: Dictionary) -> void:
	var V := VOIDS
	var g := Grid.grid(plan)
	var start := Grid.tile(plan["start"])
	var base := Grid.walks(g, start, plan)
	var prot := Grid.protected(plan, infos)
	var drop := {}  # tiles of open drop (not the gap)
	var gap := {}
	var bridges: Array = []
	var obj: Dictionary = plan.get("objective", {})
	var stair_i := -1
	for i in infos.size():
		if infos[i]["role"] == "stair":
			stair_i = i
	# The stair's own corridor, its bridge gone (the task "vanes").
	var vanes := String(obj.get("kind", "")) == "vanes"
	if vanes:
		for l in links:
			if int(l["c"]) == stair_i and not l.has("kind"):
				var cg := Grid.corridor(l["link"], infos, stair_i)
				var n: int = cg["len"]
				# (the stair room's own end: the last tile along when it lies east or south)
				var lo := 1 if int(l["link"]["side_c"]) in [0, 2] else 2
				var hi := n - 3 if int(l["link"]["side_c"]) in [0, 2] else n - 2
				for tt in l["link"]["tiles"]:
					var along: int = (tt.x if cg["ew"] else tt.y) - int(cg["axis0"])
					if along >= lo and along <= hi:  # (never beside the door: it stays a ledge)
						gap[tt] = true
				# The gap must cut the corridor: its every row across.
				if n < 5:
					gap.clear()
		if gap.size() < 4:
			plan["ok"] = false
			return
	# The drop beside the bridges.
	for l in links:
		for tt in l["link"].get("flank", []):
			if not gap.has(tt) and not prot.has(tt):
				drop[tt] = true
	if Grid.cuts(g, start, base, drop):
		drop.clear()  # (never happens that anyone knows of: the bridges' rock is apart)
	# The halls' set pieces.
	for i in infos.size():
		var info: Dictionary = infos[i]
		if info["role"] in ["entrance", "stair"] or randf() > float(V["room_chance"]):
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue
		var th: Dictionary = load("res://scripts/themes.gd").get_theme(String(info["theme"]))
		if String(th["kind"]) in ["scenario", "good"] or String(th["feature"]) in ["mirror", "trap", "ambush", "rest", "trader", "vault"]:
			continue
		if mini(info["size"].x, info["size"].y) < 7:
			continue
		var order: Array = _design_order()
		for design in order:
			var res := _design(design, info, prot, drop, gap)
			if res["tiles"].is_empty():
				continue
			var block := drop.duplicate()
			for tt in res["tiles"]:
				block[tt] = true
			if Grid.cuts(g, start, base, block):
				continue
			for tt in res["tiles"]:
				drop[tt] = true
			bridges.append_array(res["bridge"])
			break
	# The Long Bridge's drop (scenarios.gd "bridge": its plan made it).
	for sc in plan.get("scenarios", []):
		if String(sc["kind"]) != "bridge":
			continue
		var block := drop.duplicate()
		for tt in sc["voids"]:
			block[tt] = true
		if not Grid.cuts(g, start, base, block):
			for tt in sc["voids"]:
				drop[tt] = true
			bridges.append_array(sc["bridge"])
	# Into the floor's chasms (main.gd falls), then kept clear of what
	# matters exactly as the traps will (traps.gd clear_pits).
	var all := drop.duplicate()
	for tt in gap:
		all[tt] = true
	plan["chasms"] = plan.get("chasms", []) + Grid.merge(all.keys())
	load("res://scripts/traps.gd").clear_pits(plan)
	var left := {}
	for r in plan["chasms"]:
		for tt in Grid.tiles_of(r):
			left[tt] = true
	var drop_tiles: Array = drop.keys().filter(func(x): return left.has(x))
	var gap_tiles: Array = gap.keys().filter(func(x): return left.has(x))
	if vanes:
		# The gap must still shut the stair room off (the task opens it).
		var block := {}
		for tt in drop_tiles + gap_tiles:
			block[tt] = true
		var now := Grid.walk(g, start, block)
		var st := Grid.tile(plan["stair"])
		if now[st.y * int(g["size"].x) + st.x] == 1:
			plan["ok"] = false
			return
		# ...and every vane must be on this side of it.
		for pc in obj["pieces"]:
			if not load("res://scripts/reach.gd").near_reached(now, g["size"], pc["pos"]):
				plan["ok"] = false
				return
		var opens: Array = []
		for pc in obj["pieces"]:
			var pt := Grid.tile(pc["pos"])
			opens.append_array([pt, pt + Vector2i.RIGHT, pt + Vector2i.LEFT, pt + Vector2i.DOWN, pt + Vector2i.UP])
		plan["fluid_locks"] = [{"id": 950, "tiles": gap_tiles, "opens": {"all": opens}}]
	plan["voids"] = Grid.merge(drop_tiles + gap_tiles)
	plan["span"] = Grid.merge(gap_tiles)
	plan["no_foot"] = Grid.merge(drop_tiles)
	plan["sky_bridges"] = bridges
	plan["tower_floor"] = PATH
	plan["floor_num"] = floor_num


static func _design_order() -> Array:
	var table: Dictionary = VOIDS["designs"].duplicate()
	var out: Array = []
	while not table.is_empty():
		var total := 0.0
		for k in table:
			total += float(table[k])
		var roll := randf() * total
		var pick: String = table.keys()[0]
		for k in table:
			roll -= float(table[k])
			if roll <= 0.0:
				pick = k
				break
		out.append(pick)
		table.erase(pick)
	return out


## One hall's set piece: {tiles (drop), bridge (walkway tiles over it)}.
static func _design(design: String, info: Dictionary, prot: Dictionary, drop: Dictionary, gap: Dictionary) -> Dictionary:
	var V := VOIDS
	var at: Vector2i = info["pos"]
	var size: Vector2i = info["size"]
	var open := {}
	for tt in Grid.room_tiles(info):
		open[tt] = true
	var ok := func(tt: Vector2i) -> bool: return open.has(tt) and not prot.has(tt) and not drop.has(tt) and not gap.has(tt)
	var tiles: Array = []
	var bridge: Array = []
	match design:
		"well":
			var rx := size.x * 0.5 - float(V["well_margin"])
			var ry := size.y * 0.5 - float(V["well_margin"])
			if rx < 1.2 or ry < 1.2:
				return {"tiles": [], "bridge": []}
			var c := Vector2(size) * 0.5
			var across := -1  # a bridge across: 0 east-west, 1 north-south
			if randf() < float(V["well_bridge"]):
				across = randi() % 2
			for y in size.y:
				for x in size.x:
					var q := Vector2(x + 0.5, y + 0.5) - c
					if (q.x * q.x) / (rx * rx) + (q.y * q.y) / (ry * ry) > 1.0:
						continue
					var tt := at + Vector2i(x, y)
					if across == 0 and (y == size.y / 2 or y == size.y / 2 - 1):
						bridge.append(tt)
						continue
					if across == 1 and (x == size.x / 2 or x == size.x / 2 - 1):
						bridge.append(tt)
						continue
					if ok.call(tt):
						tiles.append(tt)
		"ledge":
			var depth := randi_range(int(V["ledge"][0]), int(V["ledge"][1]))
			var sides: Array = [0, 1, 2, 3]
			sides.shuffle()
			for side in sides:
				var cand: Array = []
				var clean := true
				for y in size.y:
					for x in size.x:
						var d: int = [y, size.y - 1 - y, x, size.x - 1 - x][side]
						if d >= depth:
							continue
						var tt := at + Vector2i(x, y)
						if not open.has(tt):
							continue
						if prot.has(tt) or drop.has(tt) or gap.has(tt):
							if d == 0:
								clean = false  # (a doorway on this side: not here)
							continue
						cand.append(tt)
				if clean and cand.size() >= size.x + size.y - 4:
					tiles = cand
					break
		"span":
			var wide := randi_range(int(V["span"][0]), int(V["span"][1]))
			var vertical := randf() < 0.5  # a band running north-south
			var n := size.x if vertical else size.y
			var length := size.y if vertical else size.x
			var at0 := n / 2 - wide / 2
			var cross := randi_range(1, maxi(1, length - 3))
			for k in wide:
				for i in length:
					var tt := at + (Vector2i(at0 + k, i) if vertical else Vector2i(i, at0 + k))
					if i == cross or i == cross + 1:
						if open.has(tt):
							bridge.append(tt)
						continue
					if ok.call(tt):
						tiles.append(tt)
	if tiles.size() < 4:
		return {"tiles": [], "bridge": []}
	return {"tiles": tiles, "bridge": bridge}


# --- the Long Bridge's plan (scenarios.gd "bridge") -----------------------------------

## The Long Bridge: only in a dead end (one way in). The hall falls away but
## for a landing by the door, a bridge two tiles wide to a perch at the far
## end, and the mark on the landing.
static func scn_plan(kind: String, info: Dictionary, gates: Array, _floor_num: int, cell: float) -> Dictionary:
	if gates.size() != 1:
		return {}
	var rect: Rect2 = info["rect"]
	var at: Vector2i = info["pos"]
	var open: Array = load("res://scripts/rooms.gd").open_tiles(info["rows"], 1).filter(func(x): return not info["reserved"].has(x))
	if open.size() < 16:
		return {}
	var door_t: Vector2i = gates[0][0]
	var door: Vector2 = ORIGIN + (Vector2(door_t) + Vector2(0.5, 0.5)) * cell
	var tile_at := func(x: Vector2i) -> Vector2: return rect.position + (Vector2(x) + Vector2(0.5, 0.5)) * cell
	open.sort_custom(func(a, b): return tile_at.call(a).distance_to(door) < tile_at.call(b).distance_to(door))
	var s_t: Vector2i = open[mini(1, open.size() - 1)]
	var e_t: Vector2i = open[-1]
	var s: Vector2 = tile_at.call(s_t)
	var e: Vector2 = tile_at.call(e_t)
	if s.distance_to(e) < cell * 5.0:
		return {}
	# What stays floor: the door's tiles, a landing round the mark, the bridge, a perch.
	var keep := {}
	for tt in info["reserved"]:
		keep[at + Vector2i(tt)] = true
	var box := func(c: Vector2i, r: int) -> void:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				keep[at + c + Vector2i(dx, dy)] = true
	box.call(s_t, 1)
	box.call(e_t, 1)
	var bridge: Array = []
	var dist_t := Vector2(e_t - s_t).length()
	var dirv := Vector2(e_t - s_t).normalized()
	var side := Vector2i(0, 1) if absf(dirv.x) >= absf(dirv.y) else Vector2i(1, 0)
	for k in int(dist_t * 3.0) + 1:
		var q := Vector2(s_t) + dirv * (float(k) / 3.0)
		var tt := Vector2i(int(round(q.x)), int(round(q.y)))
		for o in [Vector2i.ZERO, side]:
			keep[at + tt + o] = true
			bridge.append(at + tt + o)
	# (the way from the door to the mark, too)
	var dl := Grid.tile(door) - at
	for k in 12:
		var q := Vector2(dl).lerp(Vector2(s_t), k / 11.0)
		box.call(Vector2i(int(round(q.x)), int(round(q.y))), 0)
	var voids: Array = []
	var inside := {}
	for tt in Grid.room_tiles(info):
		inside[tt] = true
		if not keep.has(tt):
			voids.append(tt)
	bridge = bridge.filter(func(x): return inside.has(x))
	if voids.size() < 8:
		return {}
	var spawns: Array = []
	for tt in voids:
		if Grid.centre(tt).distance_to(s) > cell * 3.0:
			spawns.append(Grid.centre(tt))
	spawns.shuffle()
	if spawns.is_empty():
		spawns = [e, rect.get_center()]
	return {"kind": kind, "rect": rect, "start": s, "end": e, "centre": rect.get_center(), "spawns": spawns.slice(0, 8), "gates": gates,
		"keep": [s, e], "voids": voids, "bridge": bridge, "dir": (e - s).normalized()}


# --- in play (main.gd) ----------------------------------------------------------------

func _ready() -> void:
	z_index = -3  # (over the floor and its chasm drawing, under the climber)
	process_physics_priority = -50  # (before the climber moves: a blow's knock is checked first)


func setup(p: Dictionary) -> void:
	plan = p
	var live := {}
	for r in main.chasms:
		for tt in Grid.tiles_of(r):
			live[tt] = true
	for r in p.get("voids", []):
		for tt in Grid.tiles_of(r):
			if live.has(tt):
				voids[tt] = true
	for r in p.get("span", []):
		for tt in Grid.tiles_of(r):
			if voids.has(tt):
				span[tt] = true
	void_rects = Grid.merge(voids.keys())
	bridge_tiles = p.get("sky_bridges", [])
	# Floor near a drop: where the wind reaches.
	var reach := int(GUST["reach"])
	for tt in voids:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n: Vector2i = tt + Vector2i(dx, dy)
				if not voids.has(n) and not main.is_solid(Grid.centre(n)):
					exposed[n] = true
	# The floor's own halls and corridors, for the floors seen below.
	for r in p.get("rooms", []):
		lower.append(r)
	for r in p.get("corridors", []):
		if r.size.x >= CELL * 2.0 or r.size.y >= CELL * 2.0:
			lower.append(r)
	_find_air()
	_set_solid(voids.keys(), true)
	gust_force = float(GUST["force"]) + float(GUST["force_per_floor"]) * float(main.floor_num)
	gust_t = randf_range(3.0, 6.0)
	queue_redraw()


## Open air beyond the halls' walls: rock with no floor beside it is drawn as
## sky over the floors below, so every hall stands like a balcony. Worked out
## again whenever the floor's rock changes (a secret room found, a cracked
## wall broken: what opens shows, with walls round it).
func _find_air() -> void:
	air_set.clear()
	solid_seen = main.solid.duplicate()
	var air: Array = []
	var gs: Vector2i = main.grid_size
	for y in gs.y:
		for x in gs.x:
			if not main._is_solid_tile(x, y):
				continue
			var inner := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not main._is_solid_tile(x + dx, y + dy):
						inner = false
			if inner:
				var tt := Grid.tile(main.room.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL)
				air.append(tt)
				air_set[tt] = true
	air_rects = Grid.merge(air)


func _set_solid(tiles: Array, on: bool) -> void:
	if main.astar == null:
		return
	for tt in tiles:
		var lt: Vector2i = main._tile_of(Grid.centre(tt))
		if main.astar.region.has_point(lt) and not main._is_solid_tile(lt.x, lt.y):
			main.astar.set_point_solid(lt, on)


func _process(delta: float) -> void:
	if main == null or not is_same(main.floor_plan, plan):
		return
	t += delta
	air_t -= delta
	if air_t <= 0.0:
		air_t = 0.5
		if main.solid != solid_seen:
			_find_air()
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()


func _physics_process(delta: float) -> void:
	if main == null or main.player == null or not is_same(main.floor_plan, plan):
		return
	_catch_edge()
	_tick_gust(delta)
	_tick_falls()


## A blow that would throw the climber over an edge stops at the edge: you
## catch yourself. Only the wind and a harrier's dive throw you off.
func _catch_edge() -> void:
	var p = main.player
	# (a strike's little step forward never carries you over either)
	if p.lunge_t > 0.0 and is_void(p.global_position + p.aim * (p.lunge_speed * p.lunge_t + 6.0)):
		p.lunge_t = 0.0
	if p.dead or p.knock.length() < 20.0 or Time.get_ticks_msec() < int(p.get_meta("thrown_until", 0)):
		return
	# (in a gust the wind's own shove is left alone: only the rest is caught)
	var wind := Vector2.ZERO
	if gust_state == "blow":
		wind = gust_dir * clampf(p.knock.dot(gust_dir), 0.0, float(forced.get("force", gust_force)))
	var k: Vector2 = p.knock - wind
	var reach: float = k.length_squared() / 1800.0 + float(p.radius) * 0.5  # (how far the knock carries, as it wears off)
	for part in [Vector2(k.x, 0.0), Vector2(0.0, k.y)]:
		if part.length() > 1.0 and is_void(p.global_position + part.normalized() * minf(reach, CELL * 2.0)):
			k -= part
	p.knock = k + wind


## The wind: calm, then streaks (warn), then a shove (blow) at whoever
## stands near a drop.
func _tick_gust(delta: float) -> void:
	if voids.is_empty():
		return
	gust_t -= delta
	match gust_state:
		"calm":
			if gust_t <= 0.0:
				gust_state = "warn"
				gust_t = float(GUST["warn"])
				if not forced.is_empty():
					gust_dir = forced["dir"]
				else:
					gust_dir = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()][randi() % 8]
				main.sfx("gust", 0.8, -10.0, 0.05)
		"warn":
			if gust_t <= 0.0:
				gust_state = "blow"
				gust_t = float(GUST["blow"])
				main.sfx("gust", 1.0, -3.0, 0.05)
				if exposed.has(Grid.tile(main.player.global_position)):
					main.fx_text(main.player.global_position + Vector2(0, -44), TEXT["gust"], LOOK["wind"])
		"blow":
			var force: float = forced.get("force", gust_force)
			var p = main.player
			if exposed.has(Grid.tile(p.global_position)) and not p.dead:
				_push(p, force, delta)
			for e in main.enemies():
				if e.is_boss() or e.dead:
					continue
				if exposed.has(Grid.tile(e.global_position)) or voids.has(Grid.tile(e.global_position)):
					_push(e, force * (1.4 if e.airborne > 0.0 else 0.8), delta)
			if gust_t <= 0.0:
				gust_state = "calm"
				gust_t = randf_range(float(GUST["every"][0]), float(GUST["every"][1])) if forced.is_empty() else float(forced.get("every", 3.0))
				forced = {}


## Keeps a shove of `force` going on a body (its knock wears off each tick).
func _push(who, force: float, delta: float) -> void:
	var along: float = who.knock.dot(gust_dir)
	if along < force:
		who.knock += gust_dir * minf(force - along, (900.0 + force * 3.0) * delta + 6.0)


## A foe in the air drifts over drops (walking ones keep out of them only on
## foot) and falls when it comes down over one; a stunned flier over a drop falls.
func _tick_falls() -> void:
	for e in main.enemies():
		if e.dead or e.is_boss() or e.is_queued_for_deletion():
			continue
		var over: bool = voids.has(Grid.tile(e.global_position)) and not (span_open and span.has(Grid.tile(e.global_position)))
		var flier: bool = e.kind in Enemy.FLIERS
		if e.airborne > 0.0 and not flier:
			e.collision_mask &= ~16
			e.set_meta("aloft", true)
		elif e.has_meta("aloft"):
			e.remove_meta("aloft")
			e.collision_mask |= 16
			if over:
				drop_foe(e)
				continue
		if flier and e.stun > 0.0 and over:
			drop_foe(e)
		elif not flier and over and e.airborne <= 0.0 and not e.has_meta("aloft"):
			drop_foe(e)  # (shoved in somehow)


## A foe falls into the drop: it's gone (what it carried flies to the climber
## from the nearest edge).
func drop_foe(e) -> void:
	if e.dead:
		return
	var at: Vector2 = e.global_position
	main.fx_text(at + Vector2(0, -e.radius - 30.0), TEXT["fell"], LOOK["rim"])
	main.fx_burst(at, Vector2.DOWN, LOOK["wind"], 10, 90.0)
	main.fx_ring(at, Color(0, 0, 0, 0.6), 30.0, 0.5, 3.0)
	main.sfx("roll", 0.5, -4.0, 0.0)
	var edge := _nearest_floor(at)
	if edge != Vector2.INF:
		e.global_position = edge  # (its drops land on the edge, in reach)
	e.dead = true
	main.release_attack(e)
	main.on_enemy_killed(e)
	e.queue_free()


func _nearest_floor(at: Vector2) -> Vector2:
	var t0 := Grid.tile(at)
	for r in range(0, 7):
		var best := Vector2.INF
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var tt := t0 + Vector2i(dx, dy)
				if voids.has(tt) or main.is_solid(Grid.centre(tt)):
					continue
				var d := Grid.centre(tt).distance_squared_to(at)
				if d < best_d:
					best_d = d
					best = Grid.centre(tt)
		if best != Vector2.INF:
			return best
	return Vector2.INF


# --- what the rest of the game asks ---------------------------------------------------

func wet(_pos: Vector2) -> bool:
	return false


## The dev tool's Open all doors (main.gd open_all_doors): the wind bridges the gap.
func open_gates() -> void:
	_open_span()


## A drop within `r` px of `pos` (a harrier parried on a ledge falls).
func near_void(pos: Vector2, r: float) -> bool:
	var t0 := Grid.tile(pos)
	var n := int(ceil(r / CELL))
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var tt := t0 + Vector2i(dx, dy)
			if voids.has(tt) and not (span_open and span.has(tt)) and Grid.centre(tt).distance_to(pos) <= r + CELL * 0.5:
				return true
	return false


func is_void(pos: Vector2) -> bool:
	var tt := Grid.tile(pos)
	return voids.has(tt) and not (span_open and span.has(tt))


## Tiles nobody can walk on right now (the floor bot keeps off them).
func no_foot_tiles() -> Array:
	var out: Array = []
	for tt in voids:
		if not (span_open and span.has(tt)):
			out.append(main._tile_of(Grid.centre(tt)))
	return out


## The floor bot braces against a gust near a drop.
func bot_steer(pos: Vector2, d: Vector2) -> Vector2:
	if gust_state == "blow" and exposed.has(Grid.tile(pos)):
		# Lean into it just hard enough to stand, and creep on a little.
		var force: float = forced.get("force", gust_force)
		var lean := -gust_dir * minf(0.95, force / 165.0 + 0.08)
		var on := (d.normalized() if d.length() > 0.01 else Vector2.ZERO) * 0.25
		return (lean + on).limit_length(1.0)
	return d


func bot_step(_bot) -> Dictionary:
	var ob = main.objective
	if ob.kind != "vanes" or ob.done:
		return {}
	var pos: Vector2 = main.player.global_position
	var best := {}
	var best_d := INF
	for pc in ob.pieces:
		if pc["state"] == "done":
			continue
		var d: float = _bot_len(pos, pc["pos"])
		if d < best_d:
			best_d = d
			best = pc
	if best.is_empty():
		return {}
	return {"pos": best["pos"], "act": "strike", "why": "a wind vane"}


func _bot_len(a: Vector2, b: Vector2) -> float:
	if main.astar == null:
		return a.distance_to(b)
	var ta: Vector2i = main._tile_of(a)
	var tb: Vector2i = main._tile_of(b)
	if not main.astar.region.has_point(ta) or not main.astar.region.has_point(tb):
		return a.distance_to(b)
	var n: int = main.astar.get_id_path(ta, tb, true).size()
	return a.distance_to(b) + float(n) * 40.0


# --- the task (objectives.gd "vanes") -------------------------------------------------

func task_tick(ob, _delta: float, _p, _hurt: bool) -> void:
	if not span_open and ob.pieces.size() > 0 and ob.done_count() == ob.pieces.size():
		_open_span()


## A swing at a vane turns it a quarter round; `strikes` turns and it points
## at the gap and stays.
func task_strike(ob, from: Vector2, dir: Vector2, reach: float, arc: float) -> void:
	var k: Dictionary = ob._k()
	for pc in ob.pieces:
		if pc["state"] == "done":
			continue
		var to: Vector2 = pc["pos"] - from
		if to.length() > reach + 22.0 or absf(dir.angle_to(to)) > deg_to_rad(arc + 20.0):
			continue
		pc["t"] = float(pc["t"]) + 1.0
		main.sfx("lever", 1.1, -4.0)
		main.fx_burst(pc["pos"], dir, LOOK["wind"], 6, 90.0)
		if pc["t"] >= float(k["strikes"]):
			ob._piece_done(pc)
			main.fx_text(pc["pos"] + Vector2(0, -40), TEXT["vane_turned"], LOOK["wind"])
			if ob.done_count() == ob.pieces.size():
				_open_span()


func _open_span() -> void:
	if span_open or span.is_empty():
		return
	span_open = true
	var keep: Array = []
	for r in main.chasms:
		var any_span := false
		for tt in Grid.tiles_of(r):
			if span.has(tt):
				any_span = true
				break
		if not any_span:
			keep.append(r)
		else:
			var rest: Array = Grid.tiles_of(r).filter(func(x): return not span.has(x))
			keep.append_array(Grid.merge(rest))
	main.set_chasms(keep)
	_set_solid(span.keys(), false)
	if not span.is_empty():
		var c := Vector2.ZERO
		for tt in span:
			c += Grid.centre(tt)
		c /= float(span.size())
		main.fx_text(main.player.global_position + Vector2(0, -56), TEXT["wind_bridge"], LOOK["wind"])
		main.fx_ring(c, LOOK["wind"], 120.0, 0.7, 4.0)
	main.sfx("spell_wind", 0.8, -2.0)


# --- the Long Bridge (scenarios.gd "bridge") ------------------------------------------

func scn_begin(scn, s: Dictionary) -> void:
	var cfg: Dictionary = scn.SCENARIOS["bridge"]
	s["gust_in"] = 1.5
	s["spawn_t"] = 0.8
	s["raptors"] = int(cfg["raptors"]) + main.floor_num / int(cfg["raptors_per_floors"])
	s["limit"] = s["start"].distance_to(s["end"]) / 140.0 * float(cfg["slack"]) + 4.0


func scn_tick(scn, s: Dictionary, delta: float, p) -> void:
	var cfg: Dictionary = scn.SCENARIOS["bridge"]
	if not s["rect"].grow(-4.0).has_point(p.global_position):
		scn._finish(s, "none", scn.TEXT["left"])
		return
	# Gusts across the bridge, toward the drop.
	s["gust_in"] -= delta
	if s["gust_in"] <= 0.0 and gust_state == "calm":
		s["gust_in"] = float(cfg["gust_every"])
		var side: Vector2 = Vector2(s["dir"]).orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		forced = {"dir": side, "force": float(cfg["gust"]), "every": float(cfg["gust_every"])}
		gust_t = 0.0
	# Raptors dive out of the open air.
	s["spawn_t"] -= delta
	if s["spawn_t"] <= 0.0 and int(s["raptors"]) > 0:
		s["spawn_t"] = float(cfg["dive_every"])
		s["raptors"] = int(s["raptors"]) - 1
		var e = scn._spawn(s, 0.0, "harrier")
		if e != null:
			e.wake()
	if p.global_position.distance_to(s["end"]) < 30.0:
		var hits: int = s["hits"]
		var grade := "bronze"
		if hits <= int(cfg["gold_hits"]) and s["t"] <= s["limit"]:
			grade = "gold"
		elif hits <= int(cfg["silver_hits"]):
			grade = "silver"
		forced = {}
		scn._finish(s, grade)


func scn_status(s: Dictionary) -> Dictionary:
	var S = load("res://scripts/scenarios.gd")
	return {"title": S.TEXT["bridge"], "line": S.TEXT["bridge_line"] % [int(s.get("hits", 0)), int(s.get("t", 0.0))]}


func scn_goal(s: Dictionary) -> Vector2:
	return s["end"]


# --- drawing --------------------------------------------------------------------------


func _draw() -> void:
	if main == null:
		return
	var view: Rect2 = main.room_view._view_rect() if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	var cam: Vector2 = view.get_center()
	# The open air all round: beyond the floor's edge, and beyond the halls' walls.
	var ar: Rect2 = main.room
	var far := ar.grow(420.0)
	for r in [Rect2(far.position, Vector2(far.size.x, ar.position.y - far.position.y)), Rect2(far.position.x, ar.end.y, far.size.x, far.end.y - ar.end.y),
			Rect2(far.position.x, ar.position.y, ar.position.x - far.position.x, ar.size.y), Rect2(ar.end.x, ar.position.y, far.end.x - ar.end.x, ar.size.y)]:
		if view.intersects(r):
			_draw_sky(r.intersection(view), cam, false)
	for r in air_rects:
		if view.intersects(r):
			_draw_sky(r, cam, false)
	for r in void_rects:
		if view.intersects(r):
			_draw_sky(r, cam, true)
	_draw_edges(view)
	for tt in bridge_tiles:
		if view.has_point(Grid.centre(tt)):
			_draw_plank(tt)
	_draw_corridor_bridges(view)
	if span_open:
		_draw_wind_bridge()
	var ob = main.objective
	if ob != null and ob.kind == "vanes":
		for pc in ob.pieces:
			_draw_vane(pc)
	_draw_wind(view)


## Open air, and through it the floors below: the floor's own halls drawn
## again smaller and dimmer the deeper they are, sliding with parallax as you
## move (they shrink toward the middle of the view), with their flagstones,
## walls, a torch each and tiny shapes walking them. `drop`: a void you can
## fall into (a little lighter, and the wind's gap glows once it's bridged).
func _draw_sky(r: Rect2, cam: Vector2, drop: bool) -> void:
	draw_rect(r, LOOK["sky"] if not drop else LOOK["sky"].lightened(0.03))
	for layer in [2, 1]:
		var s := 0.34 if layer == 2 else 0.55
		var dim := 0.38 if layer == 2 else 0.66
		var shift := Vector2(61.0, 37.0) * float(layer)
		var floor_col: Color = LOOK["lower"].darkened(1.0 - dim)
		var grid_col := Color(0.0, 0.0, 0.0, 0.25)
		var wall_col: Color = LOOK["cliff"].darkened(0.2)
		for k in lower.size():
			var src: Rect2 = lower[k]
			var q := Rect2(cam + (src.position - cam) * s + shift, src.size * s)
			var cut := q.intersection(r)
			if cut.size.x <= 0.5 or cut.size.y <= 0.5:
				continue
			draw_rect(cut, floor_col)
			# Flagstones (the nearer floor only).
			if layer == 1:
				var step := CELL * s
				var x := q.position.x + step
				while x < q.end.x - 1.0:
					if x > r.position.x and x < r.end.x:
						_clip_edge(Rect2(x, q.position.y, 1.0, q.size.y), r, grid_col)
					x += step
				var y := q.position.y + step
				while y < q.end.y - 1.0:
					if y > r.position.y and y < r.end.y:
						_clip_edge(Rect2(q.position.x, y, q.size.x, 1.0), r, grid_col)
					y += step
			# Its walls: a rim all round, the north wall's face lit.
			var w := 7.0 * s
			_clip_edge(Rect2(q.position - Vector2(w, w * 2.5), Vector2(q.size.x + w * 2.0, w * 2.5)), r, wall_col.lightened(0.12))
			_clip_edge(Rect2(Vector2(q.position.x - w, q.end.y), Vector2(q.size.x + w * 2.0, w)), r, wall_col)
			_clip_edge(Rect2(Vector2(q.position.x - w, q.position.y), Vector2(w, q.size.y)), r, wall_col)
			_clip_edge(Rect2(Vector2(q.end.x, q.position.y), Vector2(w, q.size.y)), r, wall_col)
			_clip_edge(Rect2(q.position, Vector2(q.size.x, 2.0)), r, Color(0, 0, 0, 0.4))
			# A torch, and tiny shapes walking.
			var torch := Vector2(q.get_center().x, q.position.y - w)
			if r.grow(-2.0).has_point(torch):
				draw_circle(torch, 6.0 * s, Color(1.0, 0.7, 0.35, 0.25 * dim))
				draw_circle(torch, 2.2 * s + 0.5, Color(1.0, 0.8, 0.45, 0.8 * dim))
			for wk in 2:
				var u := Vector2(0.5 + 0.38 * sin(t * (0.21 + 0.05 * wk) + k * 1.7 + wk * 2.3), 0.5 + 0.38 * cos(t * (0.17 + 0.04 * wk) + k * 2.1 + wk))
				var at := q.position + q.size * u
				if r.grow(-1.0).has_point(at):
					draw_circle(at + Vector2(0, 1.5 * s), 3.0 * s, Color(0, 0, 0, 0.3 * dim))
					draw_circle(at, 2.4 * s + 0.4, Color(0.12, 0.1, 0.13, dim + 0.2))
		# The air between the floors: haze over the deeper one.
		draw_rect(r, Color(0.45, 0.55, 0.78, 0.09 if layer == 2 else 0.06))
	if drop and span_open and span.has(Grid.tile(r.get_center())):
		draw_rect(r, Color(LOOK["wind"], 0.12 + 0.05 * sin(t * 3.0)))


func _clip_edge(e: Rect2, clip: Rect2, col: Color) -> void:
	var c := e.intersection(clip)
	if c.size.x > 0.0 and c.size.y > 0.0:
		draw_rect(c, col)


## The edges: where a floor stops at a drop, a rim of lit stone and below it
## the cliff falling away; where the open air meets a hall's wall, the wall's
## outer face dropping into it.
func _draw_edges(view: Rect2) -> void:
	var tiles: Array = voids.keys()
	for tt in tiles:
		var c := Grid.centre(tt)
		if not view.has_point(c):
			continue
		var r := Rect2(ORIGIN + Vector2(tt) * CELL, Vector2(CELL, CELL))
		var n: Vector2i = tt + Vector2i.UP
		if not voids.has(n):
			# The cliff under the ledge to the north (or the wall above).
			draw_rect(Rect2(r.position, Vector2(CELL, 18.0)), LOOK["cliff"])
			for k in 3:
				draw_rect(Rect2(r.position + Vector2(0, 18.0 + k * 4.0), Vector2(CELL, 4.0)), Color(LOOK["cliff"], 0.5 - k * 0.15))
			draw_line(r.position + Vector2(0, 6), Vector2(r.end.x, r.position.y + 6), Color(0, 0, 0, 0.35), 1.0)
			if not main.is_solid(Grid.centre(n)):
				draw_line(r.position, Vector2(r.end.x, r.position.y), LOOK["rim"].darkened(0.1), 2.0)
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var m: Vector2i = tt + d
			if voids.has(m):
				continue
			match d:
				Vector2i.DOWN:
					draw_rect(Rect2(Vector2(r.position.x, r.end.y - 5.0), Vector2(CELL, 5.0)), Color(0, 0, 0, 0.35))
					if not main.is_solid(Grid.centre(m)):
						draw_line(Vector2(r.position.x, r.end.y), r.end, LOOK["rim"], 2.5)
				Vector2i.LEFT:
					draw_rect(Rect2(r.position, Vector2(6.0, CELL)), Color(0, 0, 0, 0.35))
					if not main.is_solid(Grid.centre(m)):
						draw_line(r.position, Vector2(r.position.x, r.end.y), Color(LOOK["rim"], 0.7), 2.0)
				_:
					draw_rect(Rect2(Vector2(r.end.x - 6.0, r.position.y), Vector2(6.0, CELL)), Color(0, 0, 0, 0.35))
					if not main.is_solid(Grid.centre(m)):
						draw_line(Vector2(r.end.x, r.position.y), r.end, Color(LOOK["rim"], 0.7), 2.0)
	# The halls' walls seen from outside: their faces drop into the air below them.
	for r in air_rects:
		if not view.intersects(r):
			continue
		for tt in Grid.tiles_of(r):
			if air_set.has(tt + Vector2i.UP) or main._tile_of(Grid.centre(tt)).y <= 0:
				continue
			var tr := Rect2(ORIGIN + Vector2(tt) * CELL, Vector2(CELL, CELL))
			draw_rect(Rect2(tr.position, Vector2(CELL, 22.0)), LOOK["cliff"])
			draw_rect(Rect2(tr.position + Vector2(0, 22.0), Vector2(CELL, 6.0)), Color(LOOK["cliff"], 0.4))
			draw_line(tr.position + Vector2(0, 8), Vector2(tr.end.x, tr.position.y + 8), Color(0, 0, 0, 0.3), 1.0)



## A walkway tile between drops: planks, with a rope rail at its sides.
func _draw_plank(tt: Vector2i) -> void:
	var r := Rect2(ORIGIN + Vector2(tt) * CELL, Vector2(CELL, CELL))
	var horiz := voids.has(tt + Vector2i.UP) or voids.has(tt + Vector2i.DOWN)
	draw_rect(r.grow(-1.0), LOOK["plank"].darkened(0.15))
	for k in 4:
		if horiz:
			var x := r.position.x + 2.0 + k * 9.5
			draw_rect(Rect2(x, r.position.y + 1.0, 8.0, CELL - 2.0), LOOK["plank"].lightened(0.05 * (k % 2)))
		else:
			var y := r.position.y + 2.0 + k * 9.5
			draw_rect(Rect2(r.position.x + 1.0, y, CELL - 2.0, 8.0), LOOK["plank"].lightened(0.05 * (k % 2)))
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if voids.has(tt + d):
			var a := r.get_center() + Vector2(d) * (CELL * 0.5 - 2.0) - Vector2(d).orthogonal() * CELL * 0.5
			var b := r.get_center() + Vector2(d) * (CELL * 0.5 - 2.0) + Vector2(d).orthogonal() * CELL * 0.5
			draw_line(a, b, LOOK["rope"], 2.0)


## The bridges the corridors became: planks wherever a corridor tile has
## drop beside it.
func _draw_corridor_bridges(view: Rect2) -> void:
	for r in plan.get("corridors", []):
		if not view.intersects(r):
			continue
		for tt in Grid.tiles_of(r):
			if voids.has(tt):
				continue
			var beside := false
			for d in Grid.N4:
				beside = beside or voids.has(tt + d)
			if beside:
				_draw_plank(tt)


## The steady wind across the opened gap: streams of light along it.
func _draw_wind_bridge() -> void:
	for tt in span:
		var c := Grid.centre(tt)
		for k in 3:
			var ph := fmod(t * 0.8 + k * 0.33 + (tt.x + tt.y) * 0.17, 1.0)
			var a := c + Vector2(-CELL * 0.5 + ph * CELL, -12.0 + k * 12.0)
			draw_line(a, a + Vector2(9, 0), Color(LOOK["wind"], 0.5 * sin(ph * PI)), 2.0)
			var b := c + Vector2(-12.0 + k * 12.0, -CELL * 0.5 + ph * CELL)
			draw_line(b, b + Vector2(0, 9), Color(LOOK["wind"], 0.35 * sin(ph * PI)), 2.0)


## A wind vane on a post: an arrow and a cup on each arm; each strike turns
## it a quarter; once turned it spins, pointing the wind at the gap.
func _draw_vane(pc: Dictionary) -> void:
	var c: Vector2 = pc["pos"]
	var done: bool = pc["state"] == "done"
	var turns: float = float(pc.get("t", 0.0))
	var ang := turns * PI * 0.5 + (t * 5.0 if done else sin(t * 1.3) * 0.15)
	draw_circle(c + Vector2(0, 10), 12.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(c + Vector2(-2.5, -22.0), Vector2(5.0, 32.0)), Palette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-1.5, -21.0), Vector2(3.0, 30.0)), LOOK["vane"])
	var hub := c + Vector2(0, -22)
	for i in 4:
		var a := ang + i * TAU / 4.0
		var tip := hub + Vector2(cos(a), sin(a) * 0.55) * 15.0
		draw_line(hub, tip, Palette.OUTLINE, 3.5)
		draw_line(hub, tip, LOOK["vane"].lightened(0.2), 2.0)
		draw_circle(tip, 3.5, LOOK["vane"].darkened(0.1) if not done else LOOK["wind"])
	draw_circle(hub, 3.0, LOOK["vane"].lightened(0.3))
	if done:
		draw_arc(hub, 19.0, 0.0, TAU, 24, Color(LOOK["wind"], 0.5), 2.0)


## Streaks of wind near the climber: faint while it gathers, bright as it blows.
func _draw_wind(view: Rect2) -> void:
	if gust_state == "calm":
		return
	var k := 0.35 if gust_state == "warn" else 0.85
	var p = main.player
	var n := 26
	for i in n:
		var seed := float(i) * 12.9898
		var base := view.position + view.size * Vector2(fmod(sin(seed) * 43758.5453, 1.0) * 0.5 + 0.5, fmod(cos(seed * 1.7) * 23421.631, 1.0) * 0.5 + 0.5)
		var ph := fmod(t * (0.9 + 0.3 * (i % 3)) + float(i) * 0.21, 1.0)
		var at: Vector2 = base + gust_dir * (ph - 0.5) * 260.0
		if not exposed.has(Grid.tile(at)) and not voids.has(Grid.tile(at)):
			continue
		var len := 18.0 + 14.0 * k
		draw_line(at, at + gust_dir * len, Color(LOOK["wind"], k * 0.55 * sin(ph * PI)), 1.6)
	if p != null and exposed.has(Grid.tile(p.global_position)):
		var c: Vector2 = p.global_position + Vector2(0, -30)
		draw_line(c - gust_dir * 12.0, c + gust_dir * 12.0, Color(LOOK["wind"], k), 2.5)
		draw_line(c + gust_dir * 12.0, c + gust_dir * 6.0 + gust_dir.orthogonal() * 5.0, Color(LOOK["wind"], k), 2.5)
		draw_line(c + gust_dir * 12.0, c + gust_dir * 6.0 - gust_dir.orthogonal() * 5.0, Color(LOOK["wind"], k), 2.5)
