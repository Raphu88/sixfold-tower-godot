extends RefCounted
## Builds each floor of the climb: its rooms, corridors and doors, what
## each room is, and which monsters wait where. Floor 1 is a fixed
## introductory fight (its monsters depend on the tower) and the summit is
## the beast alone in an open hall; every floor between is planned fresh
## (see "floors of rooms" below), weighted by the tower's monster mix, and
## gets bigger and harder with height.

## Monster price per floor budget, how often each is picked, and the floor
## it first appears on.
const MONSTERS := {
	"slime": {"cost": 1.0, "weight": 1.0, "from": 1},
	"archer": {"cost": 1.5, "weight": 0.8, "from": 2},
	"knight": {"cost": 2.5, "weight": 0.6, "from": 2},
	# Tower monsters: only appear where the tower's mix lists them.
	"bat": {"cost": 0.8, "weight": 1.0, "from": 1, "only": true},
	"thunderling": {"cost": 2.0, "weight": 1.0, "from": 2, "only": true},
	"lurker": {"cost": 1.5, "weight": 1.0, "from": 1, "only": true},
	"shellback": {"cost": 2.0, "weight": 1.0, "from": 2, "only": true},
	"cinder": {"cost": 1.2, "weight": 1.0, "from": 1, "only": true},
	"smith": {"cost": 2.5, "weight": 1.0, "from": 2, "only": true},
	"scorpling": {"cost": 1.0, "weight": 1.0, "from": 1, "only": true},
	"ram": {"cost": 2.5, "weight": 1.0, "from": 2, "only": true},
	"wisp": {"cost": 0.9, "weight": 1.0, "from": 1, "only": true},
	"bloomcap": {"cost": 2.0, "weight": 1.0, "from": 2, "only": true},
	"thornhound": {"cost": 0.9, "weight": 1.0, "from": 1, "only": true},
	"mongrel": {"cost": 2.2, "weight": 1.0, "from": 2, "only": true},
}
const MAX_MONSTERS := 9
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
## rare case the rooms won't fit together.
static func rooms_floor(floor_num: int, tower: Dictionary) -> Dictionary:
	var plan := {}
	for attempt in 60:
		plan = plan_floor(floor_num, tower)
		if not plan.is_empty() and not plan.get("puzzle", {}).is_empty():
			return plan
	return plan


static func plan_floor(floor_num: int, tower: Dictionary) -> Dictionary:
	var cfg := plan_for(floor_num)
	var grid: Vector2i = cfg["grid"]
	var tid: String = tower.get("beast_kind", "")
	var spine := _spine(grid, _roll(cfg["spine"]))
	var infos: Array = []
	var used_ids: Array = []
	var tier_cap := 1 if floor_num <= 3 else (2 if randf() < 0.5 else 1)
	var gallery_at: int = spine.size() / 2
	for i in spine.size():
		var role := "guard"
		if i == 0:
			role = "entrance"
		elif i == spine.size() - 1:
			role = "stair"
		elif i == gallery_at:
			role = "gallery"
		var info := _place(role, spine[i], i - 1, infos, floor_num, tower, used_ids, tier_cap)
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
			var info := _place("branch", cell, s[1], infos, floor_num, tower, used_ids, tier_cap)
			if not info.is_empty():
				infos.append(info)
				branches += 1
				continue
		var keep := {"cell": cell, "parent": s[1], "area": _cell_rect(cell)}
		if wings.size() < int(cfg["wings"]) and floor_num >= 2:
			wings.append(keep)
		elif secrets.is_empty() and randf() < float(cfg["secret"]):
			secrets.append(keep)
	_crop(infos, wings, secrets)
	# What each room is.
	var themes := Themes.assign(infos, floor_num, tid, tower)
	if tower.get("chasms", false) and not ("chasm" in themes):
		# Towers with chasms always have a chasm room: the first free room that takes it.
		var order: Array = []
		for i in infos.size():
			if infos[i]["role"] in ["guard", "branch"]:
				order.append(i)
		order.sort_custom(func(a, b): return _chasm_rank(infos[a]["theme"]) < _chasm_rank(infos[b]["theme"]))
		for i in order:
			if Themes.fits("chasm", infos[i], tid, tower) and infos[i]["theme"] != "den":
				infos[i]["theme"] = "chasm"
				themes[i] = "chasm"
				break
	return _build(infos, themes, floor_num, tower, cfg, wings, secrets)


## Moves the plan so its used cells (rooms and kept cells) start at the
## grid's corner: the floor's area is only as big as what's on it.
static func _crop(infos: Array, wings: Array, secrets: Array) -> void:
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


## The cells a plan uses, as a grid size (from the corner).
static func _used_grid(infos: Array, wings: Array, secrets: Array) -> Vector2i:
	var hi := Vector2i.ZERO
	for info in infos:
		hi = hi.max(info["cell"])
	for k in wings + secrets:
		hi = hi.max(k["cell"])
	return hi + Vector2i.ONE


static func _chasm_rank(theme: String) -> int:
	return {"quiet": 0, "pillars": 1, "crypt": 2}.get(theme, 3 if Themes.get_theme(theme)["kind"] == "bad" else 4)


## Turns the placed rooms into the floor: walkable areas, corridors, the
## rooms' features, the themes' set pieces, monsters and doors.
static func _build(infos: Array, themes: Array, floor_num: int, tower: Dictionary, cfg: Dictionary, wings: Array, secrets: Array) -> Dictionary:
	var rooms: Array = []
	var walk: Array = []
	var corridors: Array = []
	var room_info: Array = []
	for info in infos:
		var rect := Rect2(ORIGIN + Vector2(info["pos"]) * CELL, Vector2(info["size"]) * CELL)
		info["rect"] = rect
		info["walk"] = Rooms.walk_rects(info["rows"], rect.position, CELL)
		info["reserved"] = {}  # local tiles nothing else may use
		rooms.append(rect)
		walk.append_array(info["walk"])
	# Corridors, and the tiles just inside each doorway kept clear.
	for i in infos.size():
		var info: Dictionary = infos[i]
		if not info.has("link"):
			continue
		var link: Dictionary = info["link"]
		var cr: Rect2i = link["corridor"]
		link["rect"] = Rect2(ORIGIN + Vector2(cr.position) * CELL, Vector2(cr.size) * CELL)
		corridors.append(link["rect"])
		for t in link["door"]:
			_reserve_door(info, t)
			_reserve_door(infos[info["parent"]], t)  # (clamped into the parent: the tile inside its end)
	walk.append_array(corridors)
	# Both ends of every corridor: doorways, kept clear of traps.
	var doorways: Array = []
	for info in infos:
		if not info.has("link"):
			continue
		var link: Dictionary = info["link"]
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
		if info["role"] == "gallery":
			puzzle = _puzzle_spec(info, f)
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
	for i in infos.size():
		var info: Dictionary = infos[i]
		var th: Dictionary = Themes.get_theme(info["theme"])
		match String(th["feature"]):
			"spring", "cache", "camp":
				var spot := Rooms.clear_spot(info["rows"], 3)
				if spot == Vector2i(-1, -1):
					info["theme"] = "quiet"
					themes[i] = "quiet"
					continue
				_reserve_box(info, spot + Vector2i(1, 1), 1)
				var pos: Vector2 = info["rect"].position + (Vector2(spot) + Vector2(1.5, 1.5)) * CELL
				if th["feature"] == "spring":
					springs.append({"pos": pos, "r": float(SPRING["r"]), "left": float(SPRING["heal"]), "room": i})
				elif th["feature"] == "camp":
					camps.append({"pos": pos, "item": pos + Vector2(CELL * 1.1, CELL * 0.5), "room": i})
				else:
					cache = {"pos": pos, "amount": cache_amount(floor_num)}
					cache_room = info["rect"]
			"chasm":
				var band := _chasm_band(i, infos)
				if band.is_empty():
					info["theme"] = "quiet"
					themes[i] = "quiet"
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
	# Doors: likelier on rooms where danger waits, never into the start room.
	var doors: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		if not info.has("link") or i == 0:
			continue
		if randf() < Themes.door_chance(info["theme"]):
			var link: Dictionary = info["link"]
			var on_chasm := false
			for t in link["door"]:
				var c := ORIGIN + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
				for ch in chasms:
					on_chasm = on_chasm or ch.grow(CELL * 0.5).has_point(c)
			if not on_chasm:
				doors.append({"tiles": link["door"].duplicate(), "horiz": link["horiz"], "out": link["out"], "room": i})
	var ids: Array = []
	var safe_rooms: Array = []
	var hazard_rooms: Array = []
	var wet_rooms: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		ids.append(info["id"])
		var th: Dictionary = Themes.get_theme(info["theme"])
		if th["kind"] == "good" or info["theme"] == "arrival":
			safe_rooms.append(info["rect"])
		elif info["role"] != "gallery":
			wet_rooms.append(info["rect"])
		if th["feature"] == "trap":
			hazard_rooms.append(i)
		room_info.append({"rect": info["rect"], "role": info["role"], "theme": info["theme"], "shape": info["shape"],
			"id": info["id"], "cell": info["cell"], "walk": info["walk"], "rows": info["rows"],
			"parent": info["parent"], "ambush": info.get("ambush", [])})
	var used := _used_grid(infos, wings, secrets)
	var arena := Rect2(ORIGIN, Vector2(used.x * CELL_TILES.x, used.y * CELL_TILES.y) * CELL)
	var plan := {"arena": arena, "grid": used, "rooms": rooms, "walk": walk,
		"corridors": corridors, "start": start, "stair": stair, "pillars": pillars, "monsters": monsters,
		"chasms": chasms, "blocks": blocks, "pools": pools, "room_ids": ids, "puzzle": puzzle,
		"room_info": room_info, "themes": themes, "doors": doors, "posts": doorways(rooms, corridors),
		"torches": _torches(infos), "springs": springs, "camps": camps, "wings": wings, "secrets": secrets,
		"safe_rooms": safe_rooms, "hazard_rooms": hazard_rooms, "wet_rooms": wet_rooms, "doorways": doorways}
	if not cache.is_empty():
		plan["cache"] = cache
		plan["cache_room"] = cache_room
	return plan


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
static func _place(role: String, cell: Vector2i, parent: int, infos: Array, floor_num: int, tower: Dictionary, used_ids: Array, tier_cap: int) -> Dictionary:
	for design_try in 8:
		var d := _design(role, floor_num, tower, used_ids, tier_cap)
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
static func _design(role: String, floor_num: int, tower: Dictionary, used_ids: Array, tier_cap: int) -> Dictionary:
	var prefab_role: String = {"entrance": "start", "guard": "combat", "branch": "combat", "stair": "stair", "gallery": "puzzle"}[role]
	if role == "gallery" or randf() < float(PREFAB_CHANCE.get(role, 0.0)):
		var fits: Array = Rooms.for_role(prefab_role, floor_num).filter(func(r): return int(r.get("tier", 1)) <= tier_cap)
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
	var shapes: Array = tower.get("shapes", ["rect", "open", "round"])
	var shape: String = shapes[randi() % shapes.size()]
	var w := randi_range(int(lim[0]), int(lim[1]))
	var h := randi_range(int(lim[2]), int(lim[3]))
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
static func _chasm_band(idx: int, infos: Array) -> Array:
	var info: Dictionary = infos[idx]
	var rows: Array = info["rows"]
	var size: Vector2i = info["size"]
	var sides := {}
	var door_tiles: Array = []  # local
	for j in infos.size():
		var other: Dictionary = infos[j]
		if other.has("link") and (j == idx or int(other["parent"]) == idx):
			var link: Dictionary = other["link"]
			sides[link["side_c"] if j == idx else link["side_p"]] = true
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
		for t in tiles:
			info["reserved"][t] = true
			for d in DIRS:
				info["reserved"][t + d] = true
			band.append(Rect2(info["rect"].position + Vector2(t) * CELL, Vector2(CELL, CELL)))
		return band
	return []


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
## the rooms they wait in: dens hold the most, the stair's guards and the
## rooms along the route come next, then the branches. None in the start
## room, the good rooms or a crypt (its dead rise when you walk in).
static func _monsters(infos: Array, spots: Array, floor_num: int, tower: Dictionary, pillars: Array) -> Array:
	var budget := 4.5 + 1.0 * floor_num + 1.0
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
	var order: Array = []
	for round_ in 3:
		for i in infos.size():
			if _room_weight(infos[i], spots[i], floor_num) > round_:
				order.append(i)
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
	if info["role"] == "entrance" or th["kind"] == "good" or th["feature"] == "ambush":
		return 0
	if info["role"] == "gallery":
		return mini(spots.size(), 2)
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
static func _torches(infos: Array) -> Array:
	var out: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		var rows: Array = info["rows"]
		var w: int = info["size"].x
		var north: Array = []
		for j in infos.size():
			var other: Dictionary = infos[j]
			if other.has("link"):
				var link: Dictionary = other["link"]
				if (j == i and link["side_c"] == 0) or (int(other["parent"]) == i and link["side_p"] == 0):
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


## The puzzle in the gallery, from its features, or {} if it has none.
static func _puzzle_spec(info: Dictionary, f: Dictionary) -> Dictionary:
	var kind: String = info.get("puzzle", "")
	if kind == "eyes" and f["eyes"].is_empty():
		return {}
	if kind == "plates" and f["plates"].is_empty():
		return {}
	if kind == "":
		return {}
	return {"type": kind, "tier": int(info.get("tier", 1)), "room": info["rect"], "id": info["id"],
		"eyes": f["eyes"], "plates": f["plates"], "pushers": f["pushers"], "rails": f["rails"],
		"gates": f["gates"], "levers": f["levers"], "rewards": f["rewards"]}


## How much essence a cache holds on a floor.
static func cache_amount(floor_num: int) -> float:
	return float(CACHE["base"]) + float(CACHE["per_floor"]) * float(maxi(floor_num - 2, 0))


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
	var budget := 4.5 + 1.0 * floor_num
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
	return Vector2(1.0 + 0.08 * f, 1.0 + 0.05 * f)


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
