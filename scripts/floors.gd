extends RefCounted
## Builds each floor of the climb: its rooms, corridors and doors, what
## each room is, and which monsters wait where. Floor 1 is a fixed
## introductory fight (its monsters depend on the tower) and the summit is
## the beast alone in an open hall; every floor between is planned fresh
## (see "floors of rooms" below), weighted by the tower's monster mix, and
## gets bigger and harder with height.

## Monster price per floor budget, how often each is picked, and the floor
## it first appears on.
static var MONSTERS := {
	"slime": {"cost": 1.0, "weight": 1.0, "from": 1},
	"archer": {"cost": 1.5, "weight": 0.8, "from": 3},
	"knight": {"cost": 2.5, "weight": 0.6, "from": 4},
	# Tower monsters: only appear where the tower's mix lists them.
	"bat": {"cost": 0.8, "weight": 1.0, "from": 1, "only": true},
	"thunderling": {"cost": 2.0, "weight": 1.0, "from": 3, "only": true},
	"harrier": {"cost": 1.4, "weight": 1.0, "from": 3, "only": true},  # (dives from the open sky: scripts/towers/harrier.gd)
	"lurker": {"cost": 1.5, "weight": 1.0, "from": 1, "only": true},
	"shellback": {"cost": 2.0, "weight": 1.0, "from": 3, "only": true},
	"deepfin": {"cost": 1.6, "weight": 1.0, "from": 3, "only": true},  # (lives in deep water: scripts/towers/kraken_floor.gd puts it in a pool)
	"cinder": {"cost": 1.2, "weight": 1.0, "from": 1, "only": true},
	"smith": {"cost": 3.0, "weight": 1.0, "from": 4, "only": true},
	"scorpling": {"cost": 1.0, "weight": 1.0, "from": 1, "only": true},
	"ram": {"cost": 3.0, "weight": 1.0, "from": 4, "only": true},
	"wisp": {"cost": 0.9, "weight": 1.0, "from": 1, "only": true},
	"bloomcap": {"cost": 2.0, "weight": 1.0, "from": 3, "only": true},
	"thornhound": {"cost": 0.9, "weight": 1.0, "from": 1, "only": true},
	"mongrel": {"cost": 2.2, "weight": 1.0, "from": 3, "only": true},
}
const MAX_MONSTERS := 9
## How the climb gets harder with height (the Data editor's "Monsters"):
## each floor past the first, monsters have `health` and `damage` more of
## their own (a share: 0.08 is 8%); each floor buys its monsters from a
## budget of `budget` plus `budget_per_floor` for each floor, and a floor
## of rooms gets `rooms_budget` more (MONSTERS' "cost" is each one's price).
static var CURVE := {"health": 0.08, "damage": 0.05, "budget": 4.5, "budget_per_floor": 1.0, "rooms_budget": 1.0}
const Rooms := preload("res://scripts/rooms.gd")

## Pillar layouts, as fractions of the room (x, y, radius in px).
const LAYOUTS := [
	[[0.3, 0.35, 26.0], [0.7, 0.35, 26.0], [0.3, 0.7, 26.0], [0.7, 0.7, 26.0]],  # four corners
	[[0.5, 0.5, 46.0]],  # one great pillar
	[[0.2, 0.5, 22.0], [0.4, 0.5, 22.0], [0.6, 0.5, 22.0], [0.8, 0.5, 22.0]],  # a row
	[[0.35, 0.3, 24.0], [0.65, 0.3, 24.0], [0.5, 0.62, 34.0]],  # a triangle
	[[0.25, 0.3, 20.0], [0.75, 0.3, 20.0], [0.25, 0.72, 20.0], [0.75, 0.72, 20.0], [0.5, 0.5, 30.0]],  # five
	[],  # open hall
]


## --- floors of rooms -----------------------------------------------------------
##
## Every floor between the first and the summit is PLANNED, the way the web
## version did it: the area is split into a grid of cells (one room each at
## most) that grows with height, and
##   a SPINE of rooms runs from cell to neighbouring cell, from the entrance
##   to the stair: the entrance, guard rooms, the gallery in the middle (it
##   holds the floor's main puzzle) and the stair hall;
##   BRANCH rooms hang off the spine in leftover cells next to it;
##   a cell or two beside the spine is kept for a sealed WING, and sometimes
##   one for a SECRET room (only reserved for now: they come later).
## Corridors are two tiles wide and run straight from one room's wall to the
## next room's facing wall, as near the middle of both walls as the rooms'
## shapes allow, so they never cut through a room: what's drawn in a room
## (rooms.gd) stays as drawn. Where a corridor meets a room there's a
## doorway two tiles wide, and often a door (main.gd, doors.gd).
## Each room then gets a THEME (themes.gd): what it is and what it holds.

const Themes := preload("res://scripts/themes.gd")
const Mirror := preload("res://scripts/mirror.gd")
const Catalog := preload("res://scripts/puzzles/catalog.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Cracks := preload("res://scripts/cracks.gd")
const Styles := preload("res://scripts/floor_styles.gd")
const Scenarios := preload("res://scripts/scenarios.gd")

## The grid's tiles start here (world px), CELL px each.
const ORIGIN := Vector2(80, 100)
const CELL := 40.0
## One cell of the plan, in tiles. A room keeps at least a tile from its
## cell's edge, so two rooms always have a wall at least two tiles thick
## between them.
const CELL_TILES := Vector2i(16, 14)
## By floor (up to "to"): the grid of cells, how many rooms the spine has,
## how many branch rooms hang off it, how many cells are kept for sealed
## wings and how often one is kept for a secret room.
const PLAN := [
	{"to": 5, "grid": Vector2i(4, 3), "spine": [5, 6], "branches": [2, 3], "wings": 1, "secret": 0.45},
	{"to": 9, "grid": Vector2i(5, 3), "spine": [6, 7], "branches": [2, 3], "wings": 1, "secret": 0.5},
	{"to": 99, "grid": Vector2i(5, 4), "spine": [7, 8], "branches": [3, 3], "wings": 2, "secret": 0.6},
]
## The area of the lowest floors of rooms (higher floors are bigger: arena_for).
const ARENA := Rect2(80, 100, 64 * 40, 42 * 40)
## Carved rooms' sizes by role, in tiles: [min width, max width, min height, max height].
const ROOM_SIZE := {
	"entrance": [8, 11, 7, 9],
	"guard": [9, 13, 8, 11],
	"stair": [10, 13, 8, 10],
	"branch": [7, 10, 6, 9],
	"gallery": [11, 14, 9, 12],
}
## How often a room of each role is a hand-made one (rooms.gd) instead of a
## shape carved in the tower's style. The gallery is always a puzzle room.
const PREFAB_CHANCE := {"entrance": 0.5, "guard": 0.45, "stair": 0.5, "branch": 0.3}
## Good rooms (themes.gd): a healing spring's pool, the essence cache's urn.
const SPRING := {"r": 46.0, "heal": 50.0, "rate": 24.0}
const CACHE := {
	"name": "Essence cache",
	"base": 8.0,  # essence on floor 2...
	"per_floor": 3.0,  # ...and this much more each floor up
	"reach": 34.0,  # how close you walk to open it
}
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## The plan settings for a floor.
static func plan_for(floor_num: int) -> Dictionary:
	for p in PLAN:
		if floor_num <= int(p["to"]):
			return p
	return PLAN[-1]


## The biggest area a floor of rooms is laid out in (a plan only uses the
## part its rooms need: plan["arena"]).
static func arena_for(floor_num: int) -> Rect2:
	var g: Vector2i = plan_for(floor_num)["grid"]
	return Rect2(ORIGIN, Vector2(g.x * CELL_TILES.x, g.y * CELL_TILES.y) * CELL)


## A floor of rooms (see above). Planned again (a few times at most) in the
## rare case the rooms won't fit together, or as a last check (reach.gd)
## finds the stair, a room, a wing's door or what opens a lock out of reach
## (the planner never makes such a floor that anyone knows of: this is the
## backstop; tests/parts/reachability.gd sweeps it).
## `check` false skips the last check (the tests, to see what the planner
## itself makes).
static func rooms_floor(floor_num: int, tower: Dictionary, check := true) -> Dictionary:
	var plan := {}
	var fallback := {}
	for attempt in 60:
		plan = plan_floor(floor_num, tower)
		if not plan.is_empty() and plan.get("ok", false):
			if not check or load("res://scripts/reach.gd").plan_check(plan)["ok"]:
				return plan
			if fallback.is_empty():
				fallback = plan  # (main.gd's safety net opens a lock if it must)
	return fallback if not fallback.is_empty() else plan


static func plan_floor(floor_num: int, tower: Dictionary) -> Dictionary:
	var cfg := plan_for(floor_num)
	var grid: Vector2i = cfg["grid"]
	var tid: String = tower.get("beast_kind", "")
	var style := Styles.for_tower(tid)
	var spine := _spine(grid, _roll(cfg["spine"]))
	var infos: Array = []
	var used_ids: Array = []
	# The floor's one task (objectives.gd): a puzzle kind puts that puzzle in
	# the gallery; otherwise the gallery holds the task's own set piece (the
	# rune path, the wardstone), now and then a puzzle with a vault for the
	# one who solves it, or is simply the floor's biggest room.
	var obj_kind := Objectives.pick(floor_num, tid)
	var pz_kind := ""
	var pz_optional := false
	if Objectives.is_puzzle(obj_kind):
		pz_kind = obj_kind
	elif not Objectives.wants_gallery(obj_kind) and randf() < float(OPTIONAL_PUZZLE["chance"]):
		pz_kind = Catalog.pick(floor_num, tid)
		pz_optional = true
	var tier_cap := mini(Catalog.tier_for(floor_num), 2)
	var gallery_at: int = spine.size() / 2
	for i in spine.size():
		var role := "guard"
		if i == 0:
			role = "entrance"
		elif i == spine.size() - 1:
			role = "stair"
		elif i == gallery_at:
			role = "gallery"
		var info := _place(role, spine[i], i - 1, infos, floor_num, tower, used_ids, tier_cap, pz_kind, style)
		if info.is_empty():
			return {}
		infos.append(info)
	# The cells beside the spine, used on purpose: branches first, then the
	# wings' cells, then maybe a secret room's.
	var used_cells := {}
	for c in spine:
		used_cells[c] = true
	var side: Array = []  # [cell, spine index it hangs off]
	for i in spine.size():
		for d in DIRS:
			var n: Vector2i = spine[i] + d
			if _in_grid(n, grid) and not used_cells.has(n) and side.all(func(s): return s[0] != n):
				side.append([n, i])
	side.shuffle()
	var n_branch := _roll(cfg["branches"])
	var branches := 0
	var wings: Array = []
	var secrets: Array = []
	for s in side:
		var cell: Vector2i = s[0]
		if branches < n_branch:
			var info := _place("branch", cell, s[1], infos, floor_num, tower, used_ids, tier_cap, "", style)
			if not info.is_empty():
				infos.append(info)
				branches += 1
				continue
		var keep := {"cell": cell, "parent": s[1], "area": _cell_rect(cell)}
		if wings.size() < int(cfg["wings"]) and floor_num >= 2:
			wings.append(keep)
		elif secrets.is_empty() and randf() < float(cfg["secret"]):
			secrets.append(keep)
	# Loops: extra ways between rooms in neighbouring cells, so the floor
	# isn't a tree (some are doors barred from one side: shortcuts back).
	var loops := _loops(infos, floor_num, style)
	_crop(infos, wings, secrets, loops)
	# Now and then a branch room is a mirror room (mirror.gd): its theme is
	# fixed before the others are handed out.
	var mi := Mirror.pick_room(infos, floor_num)
	if mi >= 0:
		infos[mi]["fixed"] = Mirror.THEME
	# Rooms with jobs of their own: the task's hall, scenarios, a rest room,
	# a trader; and the first room after the start is a kind one.
	_fix_themes(infos, obj_kind, pz_optional, floor_num, tid, tower, style)
	# What each room is.
	var themes := Themes.assign(infos, floor_num, tid, tower)
	if tower.get("chasms", false) and not ("chasm" in themes):
		# Towers with chasms always have a chasm room: the first free room that takes it.
		var order: Array = []
		for i in infos.size():
			if infos[i]["role"] in ["guard", "branch"] and not infos[i].has("fixed") and not infos[i].get("kind_first", false):
				order.append(i)
		order.sort_custom(func(a, b): return _chasm_rank(infos[a]["theme"]) < _chasm_rank(infos[b]["theme"]))
		for i in order:
			if Themes.fits("chasm", infos[i], tid, tower) and not infos[i]["theme"] in ["den", Mirror.THEME]:
				infos[i]["theme"] = "chasm"
				themes[i] = "chasm"
				break
	return _build(infos, themes, floor_num, tower, cfg, wings, secrets, loops, {"kind": obj_kind, "optional": pz_optional, "style": style})


## An optional puzzle in the gallery (when the floor's task is something
## else): how often. Its vault gives a vault's cards (wings.gd).
static var OPTIONAL_PUZZLE := {"chance": 0.45}


## Extra ways between rooms in neighbouring cells that aren't joined yet:
## [{a, b, link, kind}], `a` the room whose wall holds the doorway (as
## _link gives it for p = b, c = a). kind "open" (a plain doorway, maybe a
## door) or "oneway" (a door barred from one side, opened from the far side).
static func _loops(infos: Array, floor_num: int, style: Dictionary) -> Array:
	var want := _roll(style["loops_high"] if floor_num >= int(style["loops_high_from"]) else style["loops"])
	var pairs: Array = []
	for i in infos.size():
		for j in infos.size():
			if j <= i:
				continue
			var d: Vector2i = infos[j]["cell"] - infos[i]["cell"]
			if absi(d.x) + absi(d.y) != 1:
				continue
			if int(infos[i]["parent"]) == j or int(infos[j]["parent"]) == i:
				continue
			pairs.append([i, j])
	pairs.shuffle()
	var out: Array = []
	for pr in pairs:
		if out.size() >= want:
			break
		# Never into the start room or the stair room (each keeps its one way in).
		if pr[0] == 0 or pr[1] == 0 or infos[pr[0]]["role"] == "stair" or infos[pr[1]]["role"] == "stair":
			continue
		var a: int = pr[1]
		var b: int = pr[0]
		var link := _link(infos[b], infos[a])
		if link.is_empty():
			a = pr[0]
			b = pr[1]
			link = _link(infos[b], infos[a])
		if link.is_empty():
			continue
		out.append({"a": a, "b": b, "link": link, "kind": "oneway" if randf() < float(style["oneway"]) else "open"})
	return out


## Themes fixed before the rest are handed out (themes.gd assign keeps a
## room's "fixed"): the task's own hall in the gallery, scenario rooms (in
## dead ends first), a rest room, a trader; the first room after the start
## is marked to be a kind one. Rooms that may not hold a piece of the task
## are marked "no_piece".
static func _fix_themes(infos: Array, obj_kind: String, pz_optional: bool, floor_num: int, tid: String, tower: Dictionary, style: Dictionary) -> void:
	var gal := _index_of_role(infos, "gallery")
	if Objectives.wants_gallery(obj_kind):
		infos[gal]["fixed"] = "hall_" + obj_kind
	elif infos[gal].get("puzzle", "") != "":
		infos[gal]["optional"] = pz_optional
	for info in infos:
		if String(info.get("fixed", "")) == Mirror.THEME:
			info["no_piece"] = true
	if style.get("kind_first", true) and infos.size() > 1 and infos[1]["role"] == "guard" and not infos[1].has("fixed"):
		infos[1]["kind_first"] = true
		if Rooms.clear_spot(infos[1]["rows"], 3) == Vector2i(-1, -1):
			# (no room in it for a spring or a camp: a plain room of the same size, its doorways as they were)
			infos[1]["rows"] = Rooms.prepare(Rooms.carve("rect", infos[1]["size"]))
			infos[1]["shape"] = "rect"
			infos[1]["prefab"] = false
	if floor_num < 2:
		return
	# Scenarios: in branch rooms (dead ends) first, then guard rooms.
	var n_scn := 1 if randf() < float(style["scenario"]) else 0
	if floor_num >= int(style["scenario2_from"]) and randf() < float(style["scenario2"]):
		n_scn += 1
	var spots: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		if info.has("fixed") or info.get("kind_first", false) or info["role"] in ["entrance", "stair", "gallery"]:
			continue
		spots.append(i)
	spots.shuffle()
	spots.sort_custom(func(x, y): return (0 if infos[x]["role"] == "branch" else 1) < (0 if infos[y]["role"] == "branch" else 1))
	var kinds: Array = Scenarios.shuffled(Scenarios.kinds_for(floor_num, tid))  # (a tower's own likelier)
	for i in spots:
		if n_scn <= 0 or kinds.is_empty() or spots.filter(func(j): return not infos[j].has("fixed")).size() <= 2:  # (two rooms stay free: a den and another)
			break
		for k in kinds:
			if Themes.fits("scn_" + k, infos[i], tid, tower):
				infos[i]["fixed"] = "scn_" + k
				infos[i]["no_piece"] = true
				kinds.erase(k)
				n_scn -= 1
				break
	# A calm rest room and a wandering trader, now and then (in a free room).
	var free: Array = spots.filter(func(i): return not infos[i].has("fixed"))
	free.shuffle()
	if free.size() >= 3 and randf() < float(style["rest"]) and Themes.fits("rest", infos[free[0]], tid, tower):
		infos[free.pop_front()]["fixed"] = "rest"
	if free.size() >= 3 and floor_num >= int(style["trader_from"]) and randf() < float(style["trader"]) and Themes.fits("trader", infos[free[0]], tid, tower):
		infos[free.pop_front()]["fixed"] = "trader"


## Moves the plan so its used cells (rooms and kept cells) start at the
## grid's corner: the floor's area is only as big as what's on it.
static func _crop(infos: Array, wings: Array, secrets: Array, loops: Array = []) -> void:
	var lo := Vector2i(999, 999)
	for info in infos:
		lo = lo.min(info["cell"])
	for k in wings + secrets:
		lo = lo.min(k["cell"])
	if lo == Vector2i.ZERO:
		return
	var tiles := Vector2i(lo.x * CELL_TILES.x, lo.y * CELL_TILES.y)
	for info in infos:
		info["cell"] -= lo
		info["pos"] -= tiles
		if info.has("link"):
			var link: Dictionary = info["link"]
			var cr: Rect2i = link["corridor"]
			link["corridor"] = Rect2i(cr.position - tiles, cr.size)
			link["door"] = link["door"].map(func(t): return t - tiles)
	for k in wings + secrets:
		k["cell"] -= lo
		k["area"] = _cell_rect(k["cell"])
	for l in loops:
		var link: Dictionary = l["link"]
		var cr: Rect2i = link["corridor"]
		link["corridor"] = Rect2i(cr.position - tiles, cr.size)
		link["door"] = link["door"].map(func(t): return t - tiles)


## The cells a plan uses, as a grid size (from the corner).
static func _used_grid(infos: Array, wings: Array, secrets: Array) -> Vector2i:
	var hi := Vector2i.ZERO
	for info in infos:
		hi = hi.max(info["cell"])
	for k in wings + secrets:
		hi = hi.max(k["cell"])
	return hi + Vector2i.ONE


static func _chasm_rank(theme: String) -> int:
	return {"quiet": 0, "post": 0, "pillars": 1, "crypt": 2}.get(theme, 3 if Themes.get_theme(theme)["kind"] == "bad" else 4)


## Turns the placed rooms into the floor: walkable areas, corridors, the
## rooms' features, the themes' set pieces, monsters and doors.
static func _build(infos: Array, themes: Array, floor_num: int, tower: Dictionary, cfg: Dictionary, wings: Array, secrets: Array, loops: Array = [], obj := {}) -> Dictionary:
	var rooms: Array = []
	var walk: Array = []
	var corridors: Array = []
	var room_info: Array = []
	var ok := true
	var style: Dictionary = obj.get("style", {})
	for info in infos:
		var rect := Rect2(ORIGIN + Vector2(info["pos"]) * CELL, Vector2(info["size"]) * CELL)
		info["rect"] = rect
		info["walk"] = Rooms.walk_rects(info["rows"], rect.position, CELL)
		info["reserved"] = {}  # local tiles nothing else may use
		rooms.append(rect)
		walk.append_array(info["walk"])
	# Corridors (the rooms' own and the loops'), and the tiles just inside
	# each doorway kept clear.
	var links := _links(infos, loops)
	for l in links:
		var link: Dictionary = l["link"]
		var cr: Rect2i = link["corridor"]
		link["rect"] = Rect2(ORIGIN + Vector2(cr.position) * CELL, Vector2(cr.size) * CELL)
		corridors.append(link["rect"])
		for t in link["door"]:
			_reserve_door(infos[l["c"]], t)
			_reserve_door(infos[l["p"]], t)  # (clamped into the parent: the tile inside its end)
	# A tower's own corridors (floor_styles.gd "script"): winding, or bridges.
	var tower_script := Styles.script_for(style)
	if tower_script != null:
		corridors = tower_script.shape_corridors(infos, links, corridors, walk)
	walk.append_array(corridors)
	# The kept cells: sealed wings and secret rooms (see "sealed wings" below).
	var kept_walk: Array = []
	var kept_doorways: Array = []
	var kept_posts: Array = []
	var kept_torches: Array = []
	_carve_kept(infos, wings, secrets, walk, kept_walk, kept_doorways, kept_posts, kept_torches)
	walk.append_array(kept_walk)
	# Both ends of every corridor: doorways, kept clear of traps.
	var doorways: Array = kept_doorways.duplicate()
	for l in links:
		var link: Dictionary = l["link"]
		var d0: Vector2i = link["door"][0]
		var door_r := Rect2(ORIGIN + Vector2(d0) * CELL, (Vector2(1, 2) if not link["horiz"] else Vector2(2, 1)) * CELL)
		doorways.append(door_r)
		var cr: Rect2 = link["rect"]
		var out: Vector2 = link["out"]
		# The parent's end: the corridor's far end from the door.
		var far := door_r
		far.position += out * (((cr.size.x if link["side_c"] >= 2 else cr.size.y) - CELL))
		doorways.append(far)
	# The start and the stair.
	var first: Dictionary = infos[0]
	var start_tile := _nearest_open(first["rows"], Vector2i(first["size"].x / 2, int(first["size"].y * 0.72)))
	var start: Vector2 = first["rect"].position + (Vector2(start_tile) + Vector2(0.5, 0.5)) * CELL
	_reserve_box(first, start_tile, 1)
	var last: Dictionary = infos[_index_of_role(infos, "stair")]
	var stair := Vector2(last["rect"].get_center().x, last["rect"].position.y + 34.0)
	var mid: int = last["size"].x / 2
	for y in 3:
		for x in range(mid - 2, mid + 2):
			last["reserved"][Vector2i(x, y)] = true
	# The rooms' own features: walls, pillars, chasms, pools, monster spots.
	var pillars: Array = []
	var chasms: Array = []
	var blocks: Array = []
	var pools: Array = []
	var spots: Array = []  # per room
	var puzzle := {}
	for i in infos.size():
		var info: Dictionary = infos[i]
		var f: Dictionary = Rooms.features(info["rows"], info["rect"].position, CELL, tower)
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			var optional: bool = info.get("optional", false)
			puzzle = _puzzle_spec(info, f, floor_num, tower, [] if optional else _entrances(infos, i, loops))
			if puzzle.is_empty():
				ok = false  # (the puzzle wouldn't fit: plan again)
			else:
				puzzle["optional"] = optional
			for t in puzzle.get("reserve", []):
				info["reserved"][t] = true
		blocks.append_array(f["blocks"])
		chasms.append_array(f["chasms"])
		pillars.append_array(f["pillars"])
		for pool in f["pools"]:
			pools.append({"pos": pool.get_center(), "r": CELL * 0.72})
		spots.append(f["spots"])
	# The themes' set pieces.
	var springs: Array = []
	var camps: Array = []
	var cache := {}
	var cache_room := Rect2()
	var rests: Array = []  # calm rest rooms: {pos, room}
	var traders: Array = []  # wandering traders: {pos, room}
	var scenarios: Array = []  # scenario rooms (scenarios.gd plans each)
	for i in infos.size():
		var info: Dictionary = infos[i]
		var th: Dictionary = Themes.get_theme(info["theme"])
		match String(th["feature"]):
			"spring", "cache", "camp", "rest", "trader":
				var spot := Rooms.clear_spot(info["rows"], 3)
				if spot == Vector2i(-1, -1):
					info["theme"] = "post"
					themes[i] = "post"
					continue
				_reserve_box(info, spot + Vector2i(1, 1), 1)
				var pos: Vector2 = info["rect"].position + (Vector2(spot) + Vector2(1.5, 1.5)) * CELL
				if th["feature"] == "spring":
					springs.append({"pos": pos, "r": float(SPRING["r"]), "left": float(SPRING["heal"]), "room": i})
				elif th["feature"] == "camp":
					camps.append({"pos": pos, "item": pos + Vector2(CELL * 1.1, CELL * 0.5), "room": i})
				elif th["feature"] == "rest":
					rests.append({"pos": pos, "room": i, "rect": info["rect"]})
				elif th["feature"] == "trader":
					traders.append({"pos": pos, "room": i})
				else:
					cache = {"pos": pos, "amount": cache_amount(floor_num)}
					cache_room = info["rect"]
			"scenario":
				var sc: Dictionary = Scenarios.plan(String(info["theme"]).substr(4), info, _gates(infos, i, wings, loops), floor_num, CELL)
				if sc.is_empty():
					info["theme"] = "post"
					themes[i] = "post"
				else:
					sc["room"] = i
					blocks.append_array(sc.get("blocks", []))  # (the Watchful Hall's cover)
					scenarios.append(sc)
			"chasm":
				var band := _chasm_band(i, infos, loops)
				if band.is_empty():
					info["theme"] = "post"
					themes[i] = "post"
				else:
					chasms.append_array(band)
			"ambush":
				info["ambush"] = _ambush_spots(info)
	chasms = Rooms.merge_rows(chasms)
	# Towers with chasms that got no chasm room break a long corridor instead.
	if tower.get("chasms", false) and chasms.is_empty():
		var band := _corridor_chasm(infos)
		if band.has_area():
			chasms.append(band)
	var monsters := _monsters(infos, spots, floor_num, tower, pillars)
	# The floor's one task (objectives.gd): its pieces spread over the rooms.
	var objective := {}
	if not obj.is_empty():
		var adj := _adjacency(infos, loops)
		var tw: Dictionary = tower.get("weights", {})
		var pick_m := func() -> String:
			var k := _pick(floor_num, 3.0, 99, tw)
			return k if k != "" else "slime"
		objective = Objectives.place(String(obj["kind"]), infos, adj, monsters, stair, floor_num, tower.get("beast_kind", ""), puzzle, CELL, pick_m)
		if objective.is_empty():
			ok = false
		for p in objective.get("pieces", []):
			infos[int(p["room"])]["piece"] = true
		if objective.has("tablet"):
			infos[int(objective["tablet"]["room"])]["piece"] = true
	# Doors: likelier on rooms where danger waits, never into the start room;
	# a loop barred from one side always has its door.
	var doors: Array = []
	for l in links:
		var i: int = l["c"]
		if i == 0:
			continue
		var link: Dictionary = l["link"]
		var oneway: bool = String(l.get("kind", "")) == "oneway"
		if not oneway and randf() >= Themes.door_chance(infos[i]["theme"]):
			continue
		var on_chasm := false
		for t in link["door"]:
			var c := ORIGIN + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
			for ch in chasms:
				on_chasm = on_chasm or ch.grow(CELL * 0.5).has_point(c)
		if on_chasm:
			continue
		var d := {"tiles": link["door"].duplicate(), "horiz": link["horiz"], "out": link["out"], "room": i}
		if l.has("kind"):
			d["loop"] = true
		if oneway:
			# Barred from the side nearer the start: opened from the far side,
			# it's a shortcut back.
			var dist := Objectives._graph_dist(_adjacency(infos, []), 0)
			var open_into := i if int(dist[i]) > int(dist[l["p"]]) else int(l["p"])
			d["lock"] = "oneway"
			d["lock_id"] = 100 + doors.size()
			# The tile on the open side, just past the door.
			var step := Vector2i(link["out"]) if open_into == int(l["p"]) else -Vector2i(link["out"])
			d["lock_side"] = link["door"].map(func(t): return t + step)
			d["open_room"] = open_into
		doors.append(d)
	var ids: Array = []
	var safe_rooms: Array = []
	var hazard_rooms: Array = []
	var wet_rooms: Array = []
	# Some doors are locked, their key or lever elsewhere; what's behind a
	# lock is always worth it (see "locked doors" below).
	var locks := _locks(infos, themes, doors, monsters, wings, floor_num)
	for l in locks:
		if l.has("pos"):
			doorways.append(Rect2(l["pos"] - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)))  # (traps keep clear of keys and levers)
	# Strongrooms (behind a lock): a pedestal with a vault's cards.
	var vaults: Array = []
	for i in infos.size():
		if infos[i]["theme"] == "strongroom" and infos[i].get("vault_at", Vector2.INF) != Vector2.INF:
			vaults.append({"pos": infos[i]["vault_at"], "room": i})
	# Every room pays off: rooms with nothing of their own get a chest (opened
	# once the room's monsters are down, or when reached).
	var chests := _chests(infos, monsters, objective, scenarios)
	for i in infos.size():
		var info: Dictionary = infos[i]
		ids.append(info["id"])
		var th: Dictionary = Themes.get_theme(info["theme"])
		if th["kind"] in ["good", "calm", "scenario"] or info["theme"] == "arrival" or th["feature"] in ["mirror", "vault", "trader"]:
			safe_rooms.append(info["rect"])  # (a mirror room holds its own test; scenarios theirs)
		elif info["role"] != "gallery":
			wet_rooms.append(info["rect"])
		if th["feature"] == "trap":
			hazard_rooms.append(i)
		room_info.append({"rect": info["rect"], "role": info["role"], "theme": info["theme"], "shape": info["shape"],
			"id": info["id"], "cell": info["cell"], "walk": info["walk"], "rows": info["rows"], "size": info["size"],
			"parent": info["parent"], "ambush": info.get("ambush", []), "gates": _gates(infos, i, wings, loops)})
	for k in wings + secrets:
		safe_rooms.append(k["rect"])  # (no traps in a wing or a secret room: they hold their own tests)
	var torches := _torches(infos, wings + secrets, loops)
	if not puzzle.is_empty():
		puzzle = Catalog.finish(puzzle, infos, _index_of_role(infos, "gallery"), torches, doors)
		if puzzle.is_empty() and Objectives.is_puzzle(String(obj.get("kind", ""))):
			ok = false
	var used := _used_grid(infos, wings, secrets)
	var arena := Rect2(ORIGIN, Vector2(used.x * CELL_TILES.x, used.y * CELL_TILES.y) * CELL)
	# Cracked walls (cracks.gd): into rock nothing else uses, inside the arena.
	var cracks: Array = []
	if not style.is_empty():
		cracks = Cracks.plan(infos, loops, walk, wings + secrets, arena, floor_num, style, doors)
		for c in cracks:
			walk.append_array(c["walk"])
	# What must stay clear and reachable (traps, chasms and cover keep off it).
	var keep: Array = Objectives.targets(objective)
	for c in chests:
		keep.append(c["pos"])
	for r in rests + traders + vaults:
		keep.append(r["pos"])
	for sc in scenarios:
		keep.append_array(sc.get("keep", []))
	var plan := {"arena": arena, "grid": used, "rooms": rooms, "walk": walk,
		"corridors": corridors, "start": start, "stair": stair, "pillars": pillars, "monsters": monsters,
		"chasms": chasms, "blocks": blocks, "pools": pools, "room_ids": ids, "puzzle": puzzle,
		"room_info": room_info, "themes": themes, "doors": doors, "posts": doorways(rooms, corridors) + kept_posts,
		"torches": torches + kept_torches, "springs": springs, "camps": camps, "wings": wings, "secrets": secrets,
		"safe_rooms": safe_rooms, "hazard_rooms": hazard_rooms, "wet_rooms": wet_rooms, "doorways": doorways, "locks": locks,
		"objective": objective, "chests": chests, "cracks": cracks, "rests": rests, "traders": traders, "scenarios": scenarios, "vaults": vaults,
		"loops": loops.size(), "keep": keep, "ok": ok, "bridges": infos.filter(func(x): return x.has("bridge")).map(func(x): return x["bridge"])}
	if not cache.is_empty():
		plan["cache"] = cache
		plan["cache_room"] = cache_room
	if tower_script != null and ok:
		tower_script.finish_plan(plan, infos, links, floor_num, tower, style)  # (the tower's own system: water, voids)
	return plan


## Every corridor of the floor: [{c (the room whose wall holds its door),
## p (the room at its far end), link, kind (loops only)}].
static func _links(infos: Array, loops: Array = []) -> Array:
	var out: Array = []
	for i in infos.size():
		if infos[i].has("link"):
			out.append({"c": i, "p": int(infos[i]["parent"]), "link": infos[i]["link"]})
	for l in loops:
		out.append({"c": int(l["a"]), "p": int(l["b"]), "link": l["link"], "kind": l["kind"]})
	return out


## Each room's neighbours (by corridor).
static func _adjacency(infos: Array, loops: Array) -> Array:
	var adj: Array = []
	for i in infos.size():
		adj.append([])
	for l in _links(infos, loops):
		adj[l["c"]].append(l["p"])
		adj[l["p"]].append(l["c"])
	return adj


## Chests for the rooms that would pay nothing otherwise (the start room
## aside): danger rooms' spoils, opened once the monsters that wait in the
## room are down (or straight away if none do). [{pos, room, rich}]
static func _chests(infos: Array, monsters: Array, objective: Dictionary, scenarios: Array) -> Array:
	var out: Array = []
	var scn_rooms: Array = scenarios.map(func(s): return int(s["room"]))
	for i in infos.size():
		var info: Dictionary = infos[i]
		if i == 0 or info["role"] == "stair" or i in scn_rooms:
			continue
		var th: Dictionary = Themes.get_theme(info["theme"])
		if th["feature"] in PAYOFF_FEATURES:
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue  # (its puzzle pays: the ward, or its vault)
		if info.get("piece", false) and th["kind"] != "bad":
			continue  # (a piece of the task is its reason to be)
		var spot := Objectives._spot(info, monsters, 1, false)
		if spot == Vector2.INF:
			spot = Objectives._spot(info, [], 0, false, [], 0.0)  # (a crowded room: anywhere open)
		if spot == Vector2.INF:
			for t in Rooms.open_tiles(info["rows"], 0):
				if not info["reserved"].has(t):
					spot = Vector2(info["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
					info["reserved"][t] = true
					break
		if spot == Vector2.INF:
			continue
		out.append({"pos": spot, "room": i, "rich": info["role"] == "branch"})
	return out


## Theme features that are a room's payoff on their own.
const PAYOFF_FEATURES := ["spring", "cache", "camp", "rest", "trader", "scenario", "vault", "mirror", "puzzle", "objective", "start", "stair"]


## What cover (a room's "#" blocks) must never wall off from the start
## (main.gd _build_layout keeps a block only if all of these stay reachable).
static func cover_targets(plan: Dictionary) -> Array:
	var out: Array = [plan.get("stair", Vector2.ZERO)]
	for m in plan.get("monsters", []):
		out.append(m[1])
	if plan.has("cache"):
		out.append(plan["cache"]["pos"])
	# What opens a locked door, the murals the Hall of Pedestals asks you to
	# read, a camp's pack and a spring's pool: walled off, they'd be lost.
	for l in plan.get("locks", []):
		if l.has("pos"):
			out.append(l["pos"])
	for m in plan.get("puzzle", {}).get("murals", []):
		out.append(Vector2(m["pos"]) + Vector2(0, 30))  # (the tile under the tablet)
	for c in plan.get("camps", []):
		out.append(c["item"])
	for s in plan.get("springs", []):
		out.append(s["pos"])
	# The task's pieces, chests, rest rooms, traders, scenarios' marks.
	out.append_array(plan.get("keep", []))
	return out


## A random walk across the grid's cells: the spine. It starts on an edge.
static func _spine(grid: Vector2i, target: int) -> Array:
	for t in 300:
		var s0: Vector2i
		match randi() % 4:
			0:
				s0 = Vector2i(0, randi() % grid.y)
			1:
				s0 = Vector2i(grid.x - 1, randi() % grid.y)
			2:
				s0 = Vector2i(randi() % grid.x, 0)
			_:
				s0 = Vector2i(randi() % grid.x, grid.y - 1)
		var path: Array = [s0]
		while path.size() < target:
			var cur: Vector2i = path[-1]
			var opts: Array = []
			for d in DIRS:
				var n: Vector2i = cur + d
				if _in_grid(n, grid) and not (n in path):
					opts.append(n)
					# Steps away from the entrance are likelier, so the route
					# crosses the floor instead of curling up in a corner.
					var away: int = absi(n.x - s0.x) + absi(n.y - s0.y)
					if away > absi(cur.x - s0.x) + absi(cur.y - s0.y):
						opts.append(n)
						opts.append(n)
			if opts.is_empty():
				break
			path.append(opts[randi() % opts.size()])
		if path.size() >= maxi(target - 1, 4):
			return path
	# (never needed in practice) a snake through the grid
	var snake: Array = []
	for r in grid.y:
		for c in grid.x:
			if snake.size() < target:
				snake.append(Vector2i(c if r % 2 == 0 else grid.x - 1 - c, r))
	return snake


static func _in_grid(c: Vector2i, grid: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid.x and c.y < grid.y


static func _roll(range_: Array) -> int:
	return randi_range(int(range_[0]), int(range_[1]))


## A cell's area (world px).
static func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell.x * CELL_TILES.x, cell.y * CELL_TILES.y) * CELL, Vector2(CELL_TILES) * CELL)


static func _index_of_role(infos: Array, role: String) -> int:
	for i in infos.size():
		if infos[i]["role"] == role:
			return i
	return infos.size() - 1


## A room for `role` placed in `cell`, joined to room `parent` (an index into
## `infos`, or -1) by a corridor; {} if no room would join up.
static func _place(role: String, cell: Vector2i, parent: int, infos: Array, floor_num: int, tower: Dictionary, used_ids: Array, tier_cap: int, pz_kind := "", style := {}) -> Dictionary:
	for design_try in 8:
		var d := _design(role, floor_num, tower, used_ids, tier_cap, pz_kind, style)
		var size: Vector2i = d["size"]
		var x0 := cell.x * CELL_TILES.x + 1
		var y0 := cell.y * CELL_TILES.y + 1
		var x1 := cell.x * CELL_TILES.x + CELL_TILES.x - 1 - size.x
		var y1 := cell.y * CELL_TILES.y + CELL_TILES.y - 1 - size.y
		if x1 < x0 or y1 < y0:
			continue
		for pos_try in 24:
			var info := d.duplicate()
			info["role"] = role
			info["cell"] = cell
			info["pos"] = Vector2i(randi_range(x0, x1), randi_range(y0, y1))
			info["parent"] = parent
			if parent >= 0:
				var link := _link(infos[parent], info)
				if link.is_empty():
					continue
				info["link"] = link
			if d["prefab"]:
				used_ids.append(d["id"])
			return info
	return {}


## What a room looks like: a hand-made room (rooms.gd) or a shape carved in
## the tower's style. {id, prefab, rows, size, shape (, puzzle, tier)}
static func _design(role: String, floor_num: int, tower: Dictionary, used_ids: Array, tier_cap: int, pz_kind := "", style := {}) -> Dictionary:
	var prefab_role: String = {"entrance": "start", "guard": "combat", "branch": "combat", "stair": "stair", "gallery": "puzzle"}[role]
	if role == "gallery" and pz_kind != "" and not (pz_kind in Catalog.PREFAB):
		return _puzzle_hall(pz_kind)
	if role == "gallery" and pz_kind == "":
		# No puzzle here: the floor's big room, carved in one of its gallery shapes.
		var gshapes: Array = style.get("gallery", ["rect", "round"]) if not style.is_empty() else ["rect", "round"]
		var gl: Array = ROOM_SIZE["gallery"]
		var gsize := Vector2i(mini(randi_range(int(gl[0]), int(gl[1])), Rooms.MAX_SIZE.x), mini(randi_range(int(gl[2]), int(gl[3])), Rooms.MAX_SIZE.y))
		var gshape: String = gshapes[randi() % gshapes.size()]
		return {"id": "carved_" + gshape, "prefab": false, "rows": Rooms.prepare(Rooms.carve(gshape, gsize)), "size": gsize, "shape": gshape}
	if role == "gallery" or randf() < float(PREFAB_CHANCE.get(role, 0.0)) * float(style.get("prefab", 1.0)):
		var fits: Array = Rooms.for_role(prefab_role, floor_num, tower.get("beast_kind", "")).filter(func(r): return int(r.get("tier", 1)) <= tier_cap)
		if role == "gallery" and pz_kind != "":
			var kind_fits: Array = fits.filter(func(r): return r.get("puzzle", "") == pz_kind)
			var top: Array = kind_fits.filter(func(r): return int(r.get("tier", 1)) == tier_cap)
			fits = top if not top.is_empty() else (kind_fits if not kind_fits.is_empty() else fits)
		var fresh: Array = fits.filter(func(r): return not (r["id"] in used_ids))
		var pool: Array = fresh if not fresh.is_empty() or role == "gallery" else []
		if pool.is_empty() and role == "gallery":
			pool = fits
		if not pool.is_empty():
			var def: Dictionary = pool[randi() % pool.size()]
			var can_flip: bool = def.get("flip", false)
			var rows := Rooms.prepare(Rooms.flipped(def, can_flip and randf() < 0.5, can_flip and randf() < 0.5))
			var out := {"id": def["id"], "prefab": true, "rows": rows, "size": Rooms.size_of(def), "shape": "prefab"}
			if def.has("puzzle"):
				out["puzzle"] = def["puzzle"]
				out["tier"] = int(def.get("tier", 1))
			return out
	var lim: Array = ROOM_SIZE.get(role, ROOM_SIZE["guard"])
	var shapes: Array = tower.get("shapes", ["rect", "open", "round"]).duplicate()
	if role != "entrance":
		shapes = style.get("own_shapes", shapes).duplicate()  # (floor_styles.gd: a tower's own shapes)
		shapes.append_array(style.get("shapes", []))  # (floor_styles.gd: the newer shapes)
	var shape: String = shapes[randi() % shapes.size()]
	var w := randi_range(int(lim[0]), int(lim[1])) + int(style.get("room_grow", 0))
	var h := randi_range(int(lim[2]), int(lim[3])) + int(style.get("room_grow", 0))
	if shape == "hall":
		w += 2
		h = maxi(5, h - 2)
	elif shape == "open":
		w += 1
		h += 1
	w = mini(w, Rooms.MAX_SIZE.x)
	h = mini(h, Rooms.MAX_SIZE.y)
	var size := Vector2i(w, h)
	return {"id": "carved_" + shape, "prefab": false, "rows": Rooms.prepare(Rooms.carve(shape, size)), "size": size, "shape": shape}


## A plain carved hall for a puzzle that lays itself out (statues, mirrors,
## the crumbling path, the ice, the lock, the pedestals): open floor, so the
## puzzle has room to work, in the kind's own size and shapes if it has them.
static func _puzzle_hall(kind: String) -> Dictionary:
	var hall := Catalog.room_for(kind)
	var lim: Array = hall[0]
	var shapes: Array = hall[1]
	var size := Vector2i(mini(randi_range(int(lim[0]), int(lim[1])), Rooms.MAX_SIZE.x), mini(randi_range(int(lim[2]), int(lim[3])), Rooms.MAX_SIZE.y))
	var shape: String = shapes[randi() % shapes.size()]
	return {"id": "hall_" + kind, "prefab": false, "rows": Rooms.prepare(Rooms.carve(shape, size)), "size": size, "shape": shape, "puzzle": kind}


## The room painter's Try it (painter.gd, main.gd try_room): a floor of two
## rooms in `tower`, a plain hall to start in and the room being tried
## (`def`, a hand-made room as drawn: not flipped) beside it, joined by a
## corridor. Its monsters wait on the room's monster spots (none in a start
## room). The stair stands in the room if it's a stair room, else in the
## hall. {} if the two rooms can't be joined (no side has a doorway).
static func try_plan(def: Dictionary, floor_num: int, tower: Dictionary) -> Dictionary:
	var job: String = def.get("role", "combat")
	var role: String = {"stair": "stair", "puzzle": "gallery"}.get(job, "guard")
	var size := Rooms.size_of(def)
	var hall_size := Vector2i(9, 8)
	var cfg := plan_for(floor_num)
	for attempt in 80:
		var d: Vector2i = DIRS[randi() % DIRS.size()]
		var hall_cell := Vector2i(1, 1) + d
		var hall := {"id": "try_hall", "prefab": false, "rows": Rooms.prepare(Rooms.carve("rect", hall_size)), "size": hall_size,
			"shape": "rect", "role": "entrance", "cell": hall_cell, "parent": -1,
			"pos": Vector2i(hall_cell.x * CELL_TILES.x + randi_range(1, CELL_TILES.x - 1 - hall_size.x), hall_cell.y * CELL_TILES.y + randi_range(1, CELL_TILES.y - 1 - hall_size.y))}
		var room := {"id": def.get("id", "try"), "prefab": true, "rows": Rooms.prepare(def["grid"]), "size": size, "shape": "prefab",
			"role": role, "cell": Vector2i(1, 1), "parent": 0,
			"pos": Vector2i(CELL_TILES.x + randi_range(1, maxi(1, CELL_TILES.x - 1 - size.x)), CELL_TILES.y + randi_range(1, maxi(1, CELL_TILES.y - 1 - size.y)))}
		if role == "gallery":
			room["puzzle"] = def.get("puzzle", "eyes")
			room["tier"] = int(def.get("tier", 1))
		elif role == "guard":
			room["fixed"] = "quiet"
		var link := _link(hall, room)
		if link.is_empty():
			continue
		room["link"] = link
		var infos: Array = [hall, room]
		_crop(infos, [], [])
		var themes := Themes.assign(infos, floor_num, tower.get("beast_kind", ""), tower)
		var plan := _build(infos, themes, floor_num, tower, cfg, [], [])
		var r: Dictionary = infos[1]
		if role != "stair":
			var hr: Rect2 = infos[0]["rect"]
			plan["stair"] = Vector2(hr.get_center().x, hr.position.y + 34.0)
		# The monsters: one on each of the room's spots.
		var spots: Array = Rooms.features(r["rows"], r["rect"].position, CELL, tower)["spots"]
		if job == "start":
			plan["monsters"] = []
		elif not spots.is_empty():
			var list: Array = []
			var knights := 0
			for sp in spots:
				var kind := _pick(floor_num, 99.0, knights, tower.get("weights", {}))
				if kind == "":
					kind = "slime"
				if kind == "knight":
					knights += 1
				list.append([kind, sp])
			plan["monsters"] = list
		plan["locks"] = []
		plan["wet_rooms"] = []  # (no pools but the room's own)
		plan["try_room"] = 1
		return plan
	return {}


## Where a room's side can take a doorway (see Rooms.door_slots); a stair
## room's north wall keeps clear of the stair.
static func _slots(info: Dictionary, side: int) -> Array:
	var slots: Array = Rooms.door_slots(info["rows"], side)
	if info["role"] == "stair" and side == 0:
		var w: int = info["size"].x
		var lo := int(floor(w * 0.5 - 0.85))
		var hi := int(floor(w * 0.5 + 0.85))
		slots = slots.filter(func(k): return k + 1 < lo - 1 or k > hi + 1)
	return slots


## The corridor from room `p` to the room `c` in the cell next to it: two
## tiles wide, straight from wall to facing wall, where both walls can take
## a doorway, as near both walls' middles as can be. {} if they can't meet.
##   corridor: its tiles (Rect2i); door: the two tiles of c's doorway, on
##   c's wall line; horiz: whether that doorway is in a north or south wall;
##   out: the way out of c through it.
static func _link(p: Dictionary, c: Dictionary) -> Dictionary:
	var d: Vector2i = c["cell"] - p["cell"]
	var pp: Vector2i = p["pos"]
	var ps: Vector2i = p["size"]
	var cp: Vector2i = c["pos"]
	var cs: Vector2i = c["size"]
	var side_p := 0
	var side_c := 1
	if d == Vector2i.RIGHT:
		side_p = 3
		side_c = 2
	elif d == Vector2i.LEFT:
		side_p = 2
		side_c = 3
	elif d == Vector2i.DOWN:
		side_p = 1
		side_c = 0
	var east_west := side_p >= 2
	var base_p := pp.y if east_west else pp.x
	var base_c := cp.y if east_west else cp.x
	var mid_p := base_p + (ps.y if east_west else ps.x) * 0.5
	var mid_c := base_c + (cs.y if east_west else cs.x) * 0.5
	var in_c := {}
	for k in _slots(c, side_c):
		in_c[base_c + int(k)] = true
	var best := 0
	var best_d := INF
	for k in _slots(p, side_p):
		var a := base_p + int(k)
		if in_c.has(a):
			var dist := absf(a + 1 - mid_p) + absf(a + 1 - mid_c) + randf() * 0.6
			if dist < best_d:
				best_d = dist
				best = a
	if best_d == INF:
		return {}
	var corridor: Rect2i
	var door: Array
	var out: Vector2
	match side_c:
		2:  # c is east of p: c's west wall
			corridor = Rect2i(pp.x + ps.x, best, cp.x - (pp.x + ps.x), 2)
			door = [Vector2i(cp.x - 1, best), Vector2i(cp.x - 1, best + 1)]
			out = Vector2.LEFT
		3:  # c is west of p: c's east wall
			corridor = Rect2i(cp.x + cs.x, best, pp.x - (cp.x + cs.x), 2)
			door = [Vector2i(cp.x + cs.x, best), Vector2i(cp.x + cs.x, best + 1)]
			out = Vector2.RIGHT
		0:  # c is south of p: c's north wall
			corridor = Rect2i(best, pp.y + ps.y, 2, cp.y - (pp.y + ps.y))
			door = [Vector2i(best, cp.y - 1), Vector2i(best + 1, cp.y - 1)]
			out = Vector2.UP
		_:  # c is north of p: c's south wall
			corridor = Rect2i(best, cp.y + cs.y, 2, pp.y - (cp.y + cs.y))
			door = [Vector2i(best, cp.y + cs.y), Vector2i(best + 1, cp.y + cs.y)]
			out = Vector2.DOWN
	return {"corridor": corridor, "door": door, "horiz": side_c < 2, "out": out, "side_p": side_p, "side_c": side_c}


## Keeps the room tiles just inside a doorway clear (`t` is a doorway tile in
## grid tiles; it's clamped into the room, so either end of a corridor works).
static func _reserve_door(info: Dictionary, t: Vector2i) -> void:
	var local: Vector2i = t - Vector2i(info["pos"])
	var size: Vector2i = info["size"]
	local.x = clampi(local.x, 0, size.x - 1)
	local.y = clampi(local.y, 0, size.y - 1)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			info["reserved"][local + Vector2i(dx, dy)] = true


static func _reserve_box(info: Dictionary, centre: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			info["reserved"][centre + Vector2i(dx, dy)] = true


## The open tile nearest `want` (local tiles).
static func _nearest_open(rows: Array, want: Vector2i) -> Vector2i:
	var best := want
	var best_d := INF
	for y in rows.size():
		for x in String(rows[0]).length():
			if Rooms.open_at(rows, x, y):
				var d := Vector2(x, y).distance_squared_to(Vector2(want))
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


## A band of chasm right across a room (between its doorways when it has
## them on facing walls), its ends left open where a doorway meets it.
static func _chasm_band(idx: int, infos: Array, loops: Array = []) -> Array:
	var info: Dictionary = infos[idx]
	var rows: Array = info["rows"]
	var size: Vector2i = info["size"]
	var sides := {}
	var door_tiles: Array = []  # local
	for l in _links(infos, loops):
		if int(l["c"]) == idx or int(l["p"]) == idx:
			var link: Dictionary = l["link"]
			sides[link["side_c"] if int(l["c"]) == idx else link["side_p"]] = true
			for t in link["door"]:
				door_tiles.append(Vector2i(t) - Vector2i(info["pos"]))
	var vertical := size.x >= size.y  # a band running north-south
	if sides.has(2) and sides.has(3):
		vertical = true
	elif sides.has(0) and sides.has(1):
		vertical = false
	var n := size.x if vertical else size.y
	var options: Array = range(maxi(2, n / 2 - 2), mini(n - 2, n / 2 + 2))
	options.shuffle()
	for at in options:
		var band: Array = []
		var tiles: Array = []
		var length := size.y if vertical else size.x
		for i in length:
			var t := Vector2i(at, i) if vertical else Vector2i(i, at)
			if not Rooms.open_at(rows, t.x, t.y) or info["reserved"].has(t):
				continue
			var near_door := false
			for dt in door_tiles:
				near_door = near_door or (absi(dt.x - t.x) <= 1 and absi(dt.y - t.y) <= 1)
			if near_door:
				continue
			tiles.append(t)
		if tiles.size() < length - 3:
			continue
		# Now and then a narrow bridge crosses it (two tiles of floor left in
		# the band, drawn as planks): walk it, or jump the chasm anywhere else.
		var bridge: Array = []
		if randf() < float(BRIDGE["chance"]) and tiles.size() >= 6:
			var k: int = randi_range(2, tiles.size() - 4)
			bridge = [tiles[k], tiles[k + 1]]
		for t in tiles:
			info["reserved"][t] = true
			for d in DIRS:
				info["reserved"][t + d] = true
			if t in bridge:
				continue
			band.append(Rect2(info["rect"].position + Vector2(t) * CELL, Vector2(CELL, CELL)))
		if not bridge.is_empty():
			var a: Rect2 = Rect2(info["rect"].position + Vector2(bridge[0]) * CELL, Vector2(CELL, CELL))
			info["bridge"] = {"rect": a.merge(Rect2(info["rect"].position + Vector2(bridge[1]) * CELL, Vector2(CELL, CELL))), "vertical": vertical}
		return band
	return []


## How often a chasm room gets a narrow bridge across its band.
static var BRIDGE := {"chance": 0.5}


## A one-tile band across the longest corridor (four tiles long at least),
## away from both its ends; Rect2() if there's none.
static func _corridor_chasm(infos: Array) -> Rect2:
	var best := Rect2i()
	var best_len := 3
	for info in infos:
		if not info.has("link"):
			continue
		var cr: Rect2i = info["link"]["corridor"]
		var east_west: bool = info["link"]["side_c"] >= 2
		var length := cr.size.x if east_west else cr.size.y
		if length > best_len:
			best_len = length
			var at := (length - 1) / 2
			best = Rect2i(cr.position + (Vector2i(at, 0) if east_west else Vector2i(0, at)), Vector2i(1, 2) if east_west else Vector2i(2, 1))
	if best_len <= 3:
		return Rect2()
	return Rect2(ORIGIN + Vector2(best.position) * CELL, Vector2(best.size) * CELL)


## Where a crypt's dead rise: open tiles near its corners.
static func _ambush_spots(info: Dictionary) -> Array:
	var rows: Array = info["rows"]
	var size: Vector2i = info["size"]
	var out: Array = []
	for c in [Vector2i(1, 1), Vector2i(size.x - 2, 1), Vector2i(1, size.y - 2), Vector2i(size.x - 2, size.y - 2)]:
		var t := _nearest_open(rows, c)
		if not info["reserved"].has(t):
			out.append(info["rect"].position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL)
	out.shuffle()
	return out.slice(0, 3)


## The floor's monsters, bought from a budget that grows with height, and
## the rooms they wait in: dens hold the most, every dead end (a branch
## room) gets one before the rooms along the route do, so none is left with
## nothing in it, and the stair's guards come next. None in the start
## room, the good rooms or a crypt (its dead rise when you walk in).
static func _monsters(infos: Array, spots: Array, floor_num: int, tower: Dictionary, pillars: Array) -> Array:
	var budget := float(CURVE["budget"]) + float(CURVE["budget_per_floor"]) * floor_num + float(CURVE["rooms_budget"])
	var kinds: Array = []
	var knights := 0
	while budget >= 1.0 and kinds.size() < MAX_MONSTERS + 2:
		var pick := _pick(floor_num, budget, knights, tower.get("weights", {}))
		if pick == "":
			break
		kinds.append(pick)
		budget -= MONSTERS[pick]["cost"]
		if pick == "knight":
			knights += 1
	# Rooms take monsters in rounds: each room that holds any gets one, then
	# the busier rooms another, then the dens a third. In the first round the
	# dens come first, then the dead ends (branch rooms), so a small budget
	# never leaves a den empty or a dead end with nothing in it; the rooms on
	# the way through come after.
	var order: Array = []
	for round_ in 3:
		var these: Array = []
		for i in infos.size():
			if _room_weight(infos[i], spots[i], floor_num) > round_:
				these.append(i)
		if round_ == 0:
			var rank := func(i: int) -> int:
				if Themes.get_theme(infos[i]["theme"])["feature"] == "den":
					return 0
				return 1 if infos[i]["role"] == "branch" else 2
			these.sort_custom(func(a, b): return rank.call(a) * 100 + a < rank.call(b) * 100 + b)
		order.append_array(these)
	if order.is_empty():
		order = range(1, infos.size())
	# Archers like a pillared hall.
	var archer_room := -1
	for i in infos.size():
		if infos[i]["theme"] == "pillars":
			archer_room = i
	var monsters: Array = []
	var placed: Array = []
	var free_spots: Array = []
	for s in spots:
		var list: Array = s.duplicate()
		list.shuffle()
		free_spots.append(list)
	for k in kinds.size():
		var ri: int = order[k % order.size()]
		if kinds[k] == "archer" and archer_room >= 0 and randf() < 0.6:
			ri = archer_room
		var pos := _monster_spot(infos[ri], free_spots[ri], placed, pillars)
		placed.append(pos)
		monsters.append([kinds[k], pos])
	return monsters


static func _room_weight(info: Dictionary, spots: Array, floor_num: int) -> int:
	var th: Dictionary = Themes.get_theme(info["theme"])
	if info["role"] == "entrance" or th["kind"] in ["good", "calm", "scenario"] or th["feature"] in ["ambush", "mirror", "trader", "rest"]:
		return 0
	if info["role"] == "stair":
		return 1 if floor_num < 6 else 2  # (a destination, lightly guarded)
	if info["role"] == "gallery":
		# Guards for the puzzle (a carved hall has no marked spots).
		return mini(spots.size(), 2) if info.get("prefab", false) else (1 if floor_num < 4 else 2)
	if th["feature"] == "den":
		return 3
	if info["role"] == "stair":
		return 2 if floor_num >= 4 else 1
	return 2 if info["role"] == "guard" else 1


## A place for a monster in a room: one of its marked spots if one's free,
## else open floor clear of the doorways, the room's set pieces and the others.
static func _monster_spot(info: Dictionary, free_spots: Array, placed: Array, pillars: Array) -> Vector2:
	var origin: Vector2 = info["rect"].position
	while not free_spots.is_empty():
		var sp: Vector2 = free_spots.pop_back()
		var t := Vector2i((sp - origin) / CELL)
		if not info["reserved"].has(t) and _clear_of(sp, 40.0, pillars, placed):
			return sp
	var tiles: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
	if tiles.is_empty():
		# (A room whose middle is all kept clear, like the Ice Hall's: its edge.)
		tiles = Rooms.open_tiles(info["rows"], 0).filter(func(t): return not info["reserved"].has(t))
	tiles.shuffle()
	for t in tiles:
		var pos: Vector2 = origin + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
		if _clear_of(pos, 50.0, pillars, placed):
			return pos
	if not tiles.is_empty():
		return origin + (Vector2(tiles[0]) + Vector2(0.5, 0.5)) * CELL
	return info["rect"].get_center()


## One torch per room, on its north wall: over the middle unless a doorway
## or the room's outline is in the way. As narrow rects for room.gd, which
## hangs a torch over the middle of each.
static func _torches(infos: Array, kept: Array = [], loops: Array = []) -> Array:
	var out: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		var rows: Array = info["rows"]
		var w: int = info["size"].x
		var north: Array = []
		# A wing's doorway or a secret wall in this room's north wall: no torch
		# there (it would hang in the doorway, or give the secret away).
		for k in kept:
			if int(k["parent"]) == i and Vector2(k["into"]) == Vector2.UP:
				for t in k["mouth"]:
					north.append(t.x - info["pos"].x)
		for l in _links(infos, loops):
			var link: Dictionary = l["link"]
			if (int(l["c"]) == i and link["side_c"] == 0) or (int(l["p"]) == i and link["side_p"] == 0):
				for t in link["door"]:
					north.append(t.x - info["pos"].x)
		var col := w / 2
		for c in [w / 2, w / 2 - 2, w / 2 + 2, w / 4, w * 3 / 4, 1, w - 2]:
			var ok: bool = c >= 1 and c <= w - 2 and String(rows[0])[c] != "X"
			for nx in north:
				ok = ok and absi(int(nx) - c) > 1
			if ok:
				col = c
				break
		var x: float = info["rect"].position.x + (col + 0.5) * CELL
		out.append(Rect2(x - CELL, info["rect"].position.y, CELL * 2.0, info["rect"].size.y))
	return out


## The puzzle in the gallery (puzzles/catalog.gd), checked by its solver,
## or {} if it has none (then the floor is planned again).
static func _puzzle_spec(info: Dictionary, f: Dictionary, floor_num: int, tower: Dictionary, entrances: Array) -> Dictionary:
	var kind: String = info.get("puzzle", "")
	if kind == "":
		return {}
	return Catalog.make(kind, info, f, floor_num, tower.get("beast_kind", ""), entrances)


## The corridor tiles right outside a room's doorways (world rects): a
## sealed puzzle room closes these.
static func _entrances(infos: Array, gi: int, loops: Array = []) -> Array:
	var g: Dictionary = infos[gi]
	var lo: Vector2i = g["pos"]
	var hi: Vector2i = lo + Vector2i(g["size"])
	var out: Array = []
	for l in _links(infos, loops):
		if int(l["c"]) != gi and int(l["p"]) != gi:
			continue
		var cr: Rect2i = l["link"]["corridor"]
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				var t := Vector2i(x, y)
				for d in DIRS:
					var n: Vector2i = t + d
					if n.x >= lo.x and n.y >= lo.y and n.x < hi.x and n.y < hi.y:
						out.append(Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL)))
						break
	return out


## How much essence a cache holds on a floor.
static func cache_amount(floor_num: int) -> float:
	return float(CACHE["base"]) + float(CACHE["per_floor"]) * float(maxi(floor_num - 2, 0))


## --- sealed wings and secret rooms ---------------------------------------------
##
## The cells plan_floor keeps beside the spine are carved last, into rock
## nothing else uses (the web version's carveWings and carveAlcove):
##   a sealed WING is a room joined to its spine room by a corridor with a
##   door, with a 3x3 VAULT ALCOVE cut into one of its other walls behind a
##   one-tile vault door (wings.gd draws the seal on it, runs the wing's
##   challenge and the vault's reward);
##   a SECRET room is a small room joined by a corridor one tile wide whose
##   first tile, in the spine room's wall, stays a wall until the climber
##   leans on it (wings.gd). Some hold a Tithe Door: an alcove like a
##   vault's, opened by paying unbanked essence.
## A kept cell whose room won't fit stays solid rock.

## A wing room's size in tiles [min w, max w, min h, max h] (the alcove must
## also fit in the cell, which can trim the side it's cut into).
const WING_SIZE := [9, 11, 7, 9]
const SECRET_SIZE := [5, 7, 4, 6]
const ALCOVE := 3  # the vault alcove is this many tiles square
## What a secret room holds (weights; wings.gd fills it).
const SECRET_CONTENTS := {"cache": 3.0, "crystals": 3.0, "tithe": 2.0}


## Carves the kept cells. `walk` is the floor's walkable area so far (to stay
## clear of it); what's carved goes into the out_ lists (walkable rects,
## doorway rects to keep clear, door-frame posts, torches). `wings` and
## `secrets` are replaced by the ones that fit, each filled in with:
##   rect (the room, world px), tiles (Rect2i), corridor (world px),
##   door: [tiles] where the corridor meets the room (a wing's door hangs
##   there; a secret's is its one tile), horiz, out (out of the room);
##   mouth: [tiles] where the corridor meets the spine room (a secret's
##   wall tile is mouth[0]), into (Vector2: from the spine room inward);
##   alcove (world px), vault_door (tile), vault_dir (Vector2: from the room
##   into the alcove), seal_pos and pedestal (world px) when it has one;
##   spawns: open spots in the room away from its doorway (world px).
static func _carve_kept(infos: Array, wings: Array, secrets: Array, walk: Array, out_walk: Array, out_doorways: Array, out_posts: Array, out_torches: Array) -> void:
	var taken: Array = []  # tile rects already open (rooms, corridors, carved so far)
	for r in walk:
		taken.append(tile_rect(r))
	var made_w: Array = []
	for k in wings:
		var w := _carve_one(infos, k, WING_SIZE, true, 2, taken)
		if w.is_empty():
			continue
		w["kind"] = "wing"
		w["id"] = "wing_%d" % made_w.size()
		made_w.append(w)
	var made_s: Array = []
	for k in secrets:
		var content := _weighted(SECRET_CONTENTS)
		var s := _carve_one(infos, k, SECRET_SIZE, content == "tithe", 1, taken)
		if s.is_empty() and content == "tithe":
			content = "cache"
			s = _carve_one(infos, k, SECRET_SIZE, false, 1, taken)
		if s.is_empty():
			continue
		s["kind"] = "secret"
		s["id"] = "secret_%d" % made_s.size()
		s["content"] = content
		made_s.append(s)
	wings.clear()
	wings.append_array(made_w)
	secrets.clear()
	secrets.append_array(made_s)
	for k in made_w + made_s:
		out_walk.append(k["rect"])
		out_walk.append(k["corridor"])
		if k.has("alcove"):
			out_walk.append(k["alcove"])
			out_walk.append(Rect2(ORIGIN + Vector2(k["vault_door"]) * CELL, Vector2(CELL, CELL)))
		var p: Dictionary = infos[k["parent"]]
		for t in k["mouth"]:
			_reserve_door(p, t)
		out_doorways.append(_tiles_rect(k["mouth"]))
		if k["kind"] == "wing":
			out_doorways.append(_tiles_rect(k["door"]))
			out_posts.append_array(doorways([k["rect"], p["rect"]], [k["corridor"]]))
			# A torch on the wing's north wall, away from a vault door there.
			var tr: Rect2i = k["tiles"]
			var col := tr.position.x + tr.size.x / 2
			if k.get("vault_dir", Vector2.ZERO) == Vector2.UP and absi(k["vault_door"].x - col) <= 1:
				col = tr.position.x + (2 if k["vault_door"].x - tr.position.x > tr.size.x / 2 else tr.size.x - 3)
			var x: float = ORIGIN.x + (col + 0.5) * CELL
			out_torches.append(Rect2(x - CELL, k["rect"].position.y, CELL * 2.0, k["rect"].size.y))


## One kept cell's room (see _carve_kept), or {} if it won't fit.
static func _carve_one(infos: Array, keep: Dictionary, lim: Array, alcove: bool, width: int, taken: Array) -> Dictionary:
	var p: Dictionary = infos[keep["parent"]]
	var cell: Vector2i = keep["cell"]
	var d: Vector2i = cell - Vector2i(p["cell"])
	# The room's wall that faces the spine room (0 north, 1 south, 2 west, 3 east).
	var side_c := 0
	if d == Vector2i.RIGHT:
		side_c = 2
	elif d == Vector2i.LEFT:
		side_c = 3
	elif d == Vector2i.UP:
		side_c = 1
	var lo := Vector2i(cell.x * CELL_TILES.x + 1, cell.y * CELL_TILES.y + 1)
	var hi := Vector2i(cell.x * CELL_TILES.x + CELL_TILES.x - 2, cell.y * CELL_TILES.y + CELL_TILES.y - 2)  # inclusive
	var opposite := side_c ^ 1
	for attempt in 40:
		var a_side := -1
		if alcove:
			var sides: Array = [opposite, opposite, opposite]
			for s in 4:
				if s != side_c and s != opposite:
					sides.append(s)
			a_side = sides[randi() % sides.size()]
		var w := randi_range(int(lim[0]), int(lim[1]))
		var h := randi_range(int(lim[2]), int(lim[3]))
		var deep := ALCOVE + 1  # the vault door's wall tile and the alcove
		if a_side == 0 or a_side == 1:
			h = mini(h, hi.y - lo.y + 1 - deep)
		elif a_side >= 2:
			w = mini(w, hi.x - lo.x + 1 - deep)
		var x0 := lo.x + (deep if a_side == 2 else 0)
		var x1 := hi.x - w + 1 - (deep if a_side == 3 else 0)
		var y0 := lo.y + (deep if a_side == 0 else 0)
		var y1 := hi.y - h + 1 - (deep if a_side == 1 else 0)
		if x1 < x0 or y1 < y0 or w < 4 or h < 4:
			continue
		var rows: Array = []
		for y in h:
			rows.append(".".repeat(w))
		var info := {"cell": cell, "pos": Vector2i(randi_range(x0, x1), randi_range(y0, y1)), "size": Vector2i(w, h), "rows": rows, "role": "kept"}
		var link := _link(p, info)
		if link.is_empty():
			continue
		var corr: Rect2i = link["corridor"]
		var door: Array = link["door"]
		if width == 1:
			# A narrow passage: the first of the two tiles.
			if link["horiz"]:
				corr.size = Vector2i(1, corr.size.y)
			else:
				corr.size = Vector2i(corr.size.x, 1)
			door = [door[0]]
		var tiles := Rect2i(info["pos"], info["size"])
		var out := {"cell": cell, "parent": keep["parent"], "area": keep["area"], "tiles": tiles,
			"rect": Rect2(ORIGIN + Vector2(tiles.position) * CELL, Vector2(tiles.size) * CELL),
			"corridor": Rect2(ORIGIN + Vector2(corr.position) * CELL, Vector2(corr.size) * CELL),
			"door": door, "horiz": link["horiz"], "out": link["out"], "into": Vector2(d)}
		# The corridor's tiles at the spine room's end (on its wall line).
		var mouth: Array = []
		for t in door:
			var m: Vector2i = t
			if link["horiz"]:
				m.y = corr.position.y if d == Vector2i.DOWN else corr.end.y - 1
			else:
				m.x = corr.position.x if d == Vector2i.RIGHT else corr.end.x - 1
			mouth.append(m)
		out["mouth"] = mouth
		var opened: Array = [tiles, corr]
		if alcove:
			var vd: Vector2i
			var dir: Vector2i
			match a_side:
				0:
					vd = Vector2i(tiles.position.x + w / 2 + randi_range(-1, 1), tiles.position.y - 1)
					dir = Vector2i.UP
				1:
					vd = Vector2i(tiles.position.x + w / 2 + randi_range(-1, 1), tiles.end.y)
					dir = Vector2i.DOWN
				2:
					vd = Vector2i(tiles.position.x - 1, tiles.position.y + h / 2 + randi_range(-1, 0))
					dir = Vector2i.LEFT
				_:
					vd = Vector2i(tiles.end.x, tiles.position.y + h / 2 + randi_range(-1, 0))
					dir = Vector2i.RIGHT
			vd.x = clampi(vd.x, tiles.position.x + 1, tiles.end.x - 2) if a_side < 2 else vd.x
			vd.y = clampi(vd.y, tiles.position.y + 1, tiles.end.y - 2) if a_side >= 2 else vd.y
			var centre: Vector2i = vd + dir * 2
			var alc := Rect2i(centre - Vector2i.ONE, Vector2i(ALCOVE, ALCOVE))
			opened.append(alc)
			opened.append(Rect2i(vd, Vector2i.ONE))
			out["alcove"] = Rect2(ORIGIN + Vector2(alc.position) * CELL, Vector2(alc.size) * CELL)
			out["vault_door"] = vd
			out["vault_dir"] = Vector2(dir)
			out["seal_pos"] = ORIGIN + (Vector2(vd) + Vector2(0.5, 0.5)) * CELL
			out["pedestal"] = out["alcove"].get_center()
		# Only into rock nothing else uses (with a wall around it).
		var clear := true
		for r in opened:
			var grown: Rect2i = r.grow(1) if r != corr else r
			for t in taken:
				if grown.intersects(t):
					clear = false
		if not clear:
			continue
		taken.append_array(opened)
		# Where its monsters may appear: away from the doorway.
		var spawns: Array = []
		for y in range(tiles.position.y + 1, tiles.end.y - 1):
			for x in range(tiles.position.x + 1, tiles.end.x - 1):
				var far := true
				for t in door:
					far = far and absi(t.x - x) + absi(t.y - y) >= 4
				if far:
					spawns.append(ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL)
		out["spawns"] = spawns
		return out
	return {}


## --- locked doors and lock-in rooms ---------------------------------------------
##
## LOCKED DOORS: on floors from LOCKS["from"], a door or two is locked. Only
## doors off the main route are (a branch room's, or a sealed wing's), so
## the way to the stair never needs a key. What opens one is always found
## on the main route (a spine room), so it can be reached without passing
## the locked door:
##   key      a key lying in a spine room;
##   carried  a key carried by one of a spine room's monsters (it drops it);
##   lever    a lever in a spine room: strike it;
##   puzzle   the stair's ward: it opens when the floor's task is done.
## A locked branch room becomes a STRONGROOM (a vault's cards on a pedestal,
## themes.gd): what's behind a lock is always worth it. A door barred from
## one side (a loop's "oneway", lock id 100 and up) isn't a lock: it opens
## from its far side, and isn't listed here.
## Each lock is written on its door (plan["doors"], or a wing's "lock") as
## lock (the kind), lock_id, and pos (a key's or lever's spot) or carrier
## (an index into plan["monsters"]); plan["locks"] lists them all.
## LOCK-IN ROOMS (doors.gd decides which): every room records its "gates",
## the doorways in its own walls (two tiles each), so they can be shut
## behind the climber.

const LOCKS := {
	"from": 3,  # the first floor with locked doors
	"chance": 0.75,  # that a floor has one...
	"second_from": 7,  # ...and from this floor, the chance of a second
	"second": 0.4,
	"kinds": {"key": 0.3, "carried": 0.25, "lever": 0.3, "puzzle": 0.15},
}


## The doorways in room `i`'s walls: its own (where its corridor arrives)
## and those of the rooms and wings that hang off it, each as its tiles.
static func _gates(infos: Array, i: int, wings: Array, loops: Array = []) -> Array:
	var out: Array = []
	for l in _links(infos, loops):
		if int(l["c"]) == i:
			out.append(l["link"]["door"].duplicate())
	for l in _links(infos, loops):
		if int(l["p"]) != i:
			continue
		var link: Dictionary = l["link"]
		var cr: Rect2i = link["corridor"]
		var tiles: Array = []
		for t in link["door"]:
			var m: Vector2i = t
			match int(link["side_c"]):
				2:
					m.x = cr.position.x
				3:
					m.x = cr.end.x - 1
				0:
					m.y = cr.position.y
				_:
					m.y = cr.end.y - 1
			tiles.append(m)
		out.append(tiles)
	for w in wings:
		if int(w["parent"]) == i:
			out.append(w["mouth"].duplicate())
	return out


static func _locks(infos: Array, themes: Array, doors: Array, monsters: Array, wings: Array, floor_num: int) -> Array:
	var out: Array = []
	if floor_num < int(LOCKS["from"]) or randf() >= float(LOCKS["chance"]):
		return out
	var count := 1
	if floor_num >= int(LOCKS["second_from"]) and randf() < float(LOCKS["second"]):
		count = 2
	# What may be locked: the doors of branch rooms that hold nothing the
	# floor needs (no piece of its task, no scenario, trader or rest), which
	# become strongrooms; and wings' doors (a wing holds a vault already).
	var cands: Array = []
	for d in doors:
		var info: Dictionary = infos[d["room"]]
		if d.get("loop", false) or String(d.get("lock", "")) != "" or info["role"] != "branch" or info.get("piece", false):
			continue
		if Themes.get_theme(info["theme"])["feature"] in ["scenario", "trader", "rest", "mirror", "den"]:
			continue
		cands.append(d)
	for w in wings:
		cands.append(w)
	cands.shuffle()
	# Where keys and levers go: the main route (not the gallery, whose puzzle may fence it).
	var hosts: Array = []
	for i in infos.size():
		if infos[i]["role"] in ["guard", "stair", "entrance"]:
			hosts.append(i)
	for c in cands.slice(0, count):
		if c.has("room"):
			# A locked room is a strongroom: worth the trouble, lightly guarded.
			var ri: int = c["room"]
			infos[ri]["theme"] = "strongroom"
			themes[ri] = "strongroom"
			var kept: Array = []
			var guards := 0
			for m in monsters:
				if infos[ri]["rect"].has_point(m[1]):
					guards += 1
					if guards > 1:
						continue
				kept.append(m)
			monsters.clear()
			monsters.append_array(kept)
			if not infos[ri].has("vault_at"):
				infos[ri]["vault_at"] = Objectives._spot(infos[ri], monsters, 1, true)
		var kind := _weighted(LOCKS["kinds"])
		var lock := {"kind": kind, "id": out.size() + 1}
		if kind == "carried":
			var carriers: Array = []
			for m in monsters.size():
				if out.any(func(l): return int(l.get("carrier", -1)) == m):
					continue  # (a monster carries one key at most: a second would be lost)
				for h in hosts:
					if infos[h]["rect"].has_point(monsters[m][1]) and h != 0:
						carriers.append(m)
			if carriers.is_empty():
				kind = "key"
				lock["kind"] = kind
			else:
				lock["carrier"] = carriers[randi() % carriers.size()]
		if kind == "key" or kind == "lever":
			var spot := _lock_spot(infos, hosts, monsters)
			if spot == Vector2.INF:
				kind = "puzzle"
				lock["kind"] = kind
			else:
				lock["pos"] = spot
		c["lock"] = kind
		c["lock_id"] = lock["id"]
		for k in ["pos", "carrier"]:
			if lock.has(k):
				c["lock_" + k] = lock[k]
		lock["door"] = c.get("id", "room_%d" % int(c.get("room", -1)))
		out.append(lock)
	return out


## A free spot for a key or lever in one of the host rooms (Vector2.INF if none).
static func _lock_spot(infos: Array, hosts: Array, monsters: Array) -> Vector2:
	var order: Array = hosts.duplicate()
	order.shuffle()
	order.sort_custom(func(a, b): return (a == 0) == false and b == 0)  # the start room last
	for h in order:
		var info: Dictionary = infos[h]
		var tiles: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
		tiles.shuffle()
		for t in tiles:
			var pos: Vector2 = info["rect"].position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
			if monsters.all(func(m): return pos.distance_to(m[1]) > 50.0):
				_reserve_box(info, t, 1)
				return pos
	return Vector2.INF


## The world rect around a few tiles.
static func _tiles_rect(tiles: Array) -> Rect2:
	var r := Rect2(ORIGIN + Vector2(tiles[0]) * CELL, Vector2(CELL, CELL))
	for t in tiles:
		r = r.merge(Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL)))
	return r


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


## Which tiles of the floor's grid a rect covers (the same way main.gd
## builds the grid, whose tiles start at ORIGIN).
static func tile_rect(r: Rect2) -> Rect2i:
	var p := Vector2i(int((r.position.x - ORIGIN.x) / CELL), int((r.position.y - ORIGIN.y) / CELL))
	var e := Vector2i(int(ceil((r.end.x - ORIGIN.x) / CELL)), int(ceil((r.end.y - ORIGIN.y) / CELL)))
	return Rect2i(p, e - p)


## A small dead-end room off one of the rooms: {"room", "hall"}, or {} if
## none fits. It keeps a wall at least a tile and a half thick from

## Door frames: where a corridor opens into a room, the wall tiles on either
## side of the opening (world-space tile rects). Purely for the look;
## main.gd keeps only the ones that land on solid tiles.
static func doorways(rooms: Array, halls: Array) -> Array:
	var posts := {}
	for r in rooms:
		var rt := tile_rect(r)
		for c in halls:
			var ct := tile_rect(c)
			var y0 := maxi(ct.position.y, rt.position.y)
			var y1 := mini(ct.end.y, rt.end.y)
			if y1 > y0:
				for x in [rt.position.x - 1, rt.end.x]:  # the west and east walls
					if ct.position.x <= x and ct.end.x > x:
						posts[Vector2i(x, y0 - 1)] = true
						posts[Vector2i(x, y1)] = true
			var x0 := maxi(ct.position.x, rt.position.x)
			var x1 := mini(ct.end.x, rt.end.x)
			if x1 > x0:
				for y in [rt.position.y - 1, rt.end.y]:  # the north and south walls
					if ct.position.y <= y and ct.end.y > y:
						posts[Vector2i(x0 - 1, y)] = true
						posts[Vector2i(x1, y)] = true
	var list: Array = []
	for t in posts:
		list.append(Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL)))
	return list


static func _snap(r: Rect2) -> Rect2:
	var p := (r.position / CELL).round() * CELL
	var e := (r.end / CELL).round() * CELL
	return Rect2(p, e - p)


## Floor 1: four monsters in the familiar spots; `kinds` comes from the tower.
static func first_floor(room: Rect2, kinds: Array) -> Dictionary:
	var spots := [Vector2(680, 265), Vector2(740, 145), Vector2(780, 385), Vector2(1000, 265)]
	var monsters: Array = []
	for i in spots.size():
		monsters.append([kinds[i] if i < kinds.size() else "slime", room.position + spots[i]])
	return {"pillars": [], "monsters": monsters}


## `tower` is a tower's data (towers.gd): its monster mix and floor 1.
static func build(floor_num: int, room: Rect2, player_start: Vector2, tower: Dictionary = {}) -> Dictionary:
	if floor_num <= 1:
		return first_floor(room, tower.get("first", ["knight", "slime", "slime", "archer"]))
	# The summit: the tower's beast, alone in an open hall.
	if tower.has("beast_kind") and floor_num == int(tower.get("summit", 0)):
		return {"pillars": [], "monsters": [[tower["beast_kind"], room.get_center() + Vector2(0, -70)]], "summit": true}
	# Floors between the first and the beast: rooms joined by corridors.
	if tower.get("rooms", true):
		return rooms_floor(floor_num, tower)
	var pillars: Array = []
	for p in LAYOUTS[randi() % LAYOUTS.size()]:
		pillars.append({"pos": room.position + room.size * Vector2(p[0], p[1]), "r": p[2]})
	# Sometimes a few loose pillars on top.
	for i in randi() % 3:
		var pos := room.position + room.size * Vector2(randf_range(0.12, 0.88), randf_range(0.2, 0.7))
		if _clear_of(pos, 70.0, pillars, []) and pos.distance_to(player_start) > 140.0:
			pillars.append({"pos": pos, "r": randf_range(16.0, 24.0)})

	# Chasms (towers that have them): gaps in the floor to jump across.
	var chasms: Array = chasm_layout(room, pillars, player_start) if tower.get("chasms", false) else []

	# Spend the floor's budget on monsters.
	var budget := float(CURVE["budget"]) + float(CURVE["budget_per_floor"]) * floor_num
	var kinds: Array = []
	var knights := 0
	while budget >= 1.0 and kinds.size() < MAX_MONSTERS:
		var pick := _pick(floor_num, budget, knights, tower.get("weights", {}))
		if pick == "":
			break
		kinds.append(pick)
		budget -= MONSTERS[pick]["cost"]
		if pick == "knight":
			knights += 1

	# Place them in the far part of the room, clear of pillars and each other.
	var monsters: Array = []
	var placed: Array = []
	for kind in kinds:
		var pos := Vector2.ZERO
		for attempt in 40:
			pos = room.position + room.size * Vector2(randf_range(0.1, 0.9), randf_range(0.12, 0.62))
			if _clear_of(pos, 60.0, pillars, placed) and pos.distance_to(player_start) > 260.0 and not _in_any(pos, chasms, 30.0):
				break
		placed.append(pos)
		monsters.append([kind, pos])
	return {"pillars": pillars, "monsters": monsters, "chasms": chasms}


## Gaps in the floor: two to four, each narrow enough to jump across one way
## (about 40-50 px), clear of the start, the stair and the pillars.
static func chasm_layout(room: Rect2, pillars: Array, start: Vector2) -> Array:
	var list: Array = []
	var stair := Vector2(room.get_center().x, room.position.y + 34.0)
	for i in 2 + randi() % 3:
		for attempt in 30:
			var horizontal := randf() < 0.5
			var size := Vector2(randf_range(130.0, 260.0), randf_range(38.0, 50.0)) if horizontal else Vector2(randf_range(38.0, 50.0), randf_range(110.0, 200.0))
			var pos := room.position + Vector2(randf_range(40.0, room.size.x - 40.0 - size.x), randf_range(90.0, room.size.y - 60.0 - size.y))
			var r := Rect2(pos, size)
			var ok := not r.grow(70.0).has_point(start) and not r.grow(60.0).has_point(stair)
			for p in pillars:
				ok = ok and not r.grow(p["r"] + 10.0).has_point(p["pos"])
			for other in list:
				ok = ok and not r.grow(40.0).intersects(other)
			if ok:
				list.append(r)
				break
	return list


static func _in_any(pos: Vector2, rects: Array, margin: float) -> bool:
	for r in rects:
		if r.grow(margin).has_point(pos):
			return true
	return false


## Standing water for wet towers: a few pools, clear of pillars and the start.
static func puddles(room: Rect2, pillars: Array, start: Vector2) -> Array:
	var list: Array = []
	for i in 3 + randi() % 3:
		for attempt in 20:
			var pos := room.position + room.size * Vector2(randf_range(0.1, 0.9), randf_range(0.15, 0.85))
			var r := randf_range(45.0, 85.0)
			var ok := pos.distance_to(start) > r + 60.0
			for p in pillars:
				ok = ok and pos.distance_to(p["pos"]) > p["r"] + r * 0.6
			if ok:
				list.append({"pos": pos, "r": r})
				break
	return list


## How much tougher monsters are on a floor (health, damage).
static func toughness(floor_num: int) -> Vector2:
	var f := float(maxi(floor_num - 1, 0))
	return Vector2(1.0 + float(CURVE["health"]) * f, 1.0 + float(CURVE["damage"]) * f)


static func _pick(floor_num: int, budget: float, knights: int, mix: Dictionary = {}) -> String:
	var options: Array = []
	var total := 0.0
	for kind in MONSTERS:
		var m: Dictionary = MONSTERS[kind]
		if m.get("only", false) and not mix.has(kind):
			continue
		if floor_num < m["from"] or m["cost"] > budget:
			continue
		# Knights are capped per floor (a knight-heavy tower allows one more).
		var knight_cap := maxi(1, floor_num / 2) + (1 if float(mix.get("knight", 1.0)) > 1.0 else 0)
		if kind == "knight" and knights >= knight_cap:
			continue
		options.append(kind)
		total += float(m["weight"]) * float(mix.get(kind, 1.0))
	if options.is_empty():
		return ""
	var roll := randf() * total
	for kind in options:
		roll -= float(MONSTERS[kind]["weight"]) * float(mix.get(kind, 1.0))
		if roll <= 0.0:
			return kind
	return options[-1]


static func _clear_of(pos: Vector2, gap: float, pillars: Array, others: Array) -> bool:
	for p in pillars:
		if pos.distance_to(p["pos"]) < p["r"] + gap:
			return false
	for o in others:
		if pos.distance_to(o) < gap:
			return false
	return true
