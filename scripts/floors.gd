extends RefCounted
## Builds each floor of the climb: where the pillars stand and which
## monsters wait there. Floor 1 is a fixed introductory fight (its monsters
## depend on the tower); above that every floor is rolled fresh, weighted by
## the tower's monster mix, and gets harder.

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


## --- rooms and hallways -------------------------------------------------------------

## The area a floor of rooms is laid out in, and its tile size.
const ARENA := Rect2(80, 100, 2160, 1320)
const CELL := 40.0
const GRID := Vector2i(3, 2)  # the area is split into 3x2 cells, one room each at most

## Cover: short low walls inside the bigger rooms (solid tiles, so they
## block movement, sight and shots like any wall).
const COVER := {
	"min_area": 150000.0,  # rooms smaller than this (px²) get none
	"per_room": [1, 2],  # how many to try in each big room (min, max)
	"length": [2, 4],  # tiles long (one tile thick)
}

## Side rooms: a small dead-end room off one of the rooms, holding an
## essence cache, sometimes guarded. Text and amounts live here.
const SIDE_ROOM := {
	"chance": 0.7,  # how often a floor tries for one (about 3 in 4 fit: half the floors)
	"guard_chance": 0.5,  # how often one of the floor's monsters waits there
	"tiles": [5, 6],  # side length in tiles (min, max)
}
const CACHE := {
	"name": "Essence cache",
	"base": 8.0,  # essence on floor 2...
	"per_floor": 3.0,  # ...and this much more each floor up
	"reach": 34.0,  # how close you walk to open it
}


## A floor of 3-5 rooms joined by corridors. You start in the first room; the
## stair is in the last. Monsters wait in the rooms beyond the first.
static func rooms_floor(floor_num: int, tower: Dictionary) -> Dictionary:
	# Lay the floor out again (a few times at most) if a corridor ran through
	# a piece its puzzle needs: every floor of rooms should have its test.
	var plan := {}
	for attempt in 8:
		plan = _rooms_floor_once(floor_num, tower)
		if not plan.get("puzzle", {}).is_empty():
			break
	return plan


static func _rooms_floor_once(floor_num: int, tower: Dictionary) -> Dictionary:
	var cell_size := ARENA.size / Vector2(GRID)
	# A path through the cells: from a bottom cell to a top one.
	var path: Array = []
	var cur := Vector2i(randi() % GRID.x, GRID.y - 1)
	path.append(cur)
	var want := 3 + randi() % 3
	for step in 12:
		if path.size() >= want and cur.y == 0:
			break
		var options: Array = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= GRID.x or nxt.y >= GRID.y or nxt in path:
				continue
			# Head up once the path is long enough.
			if path.size() >= want - 1 and d == Vector2i.DOWN:
				continue
			options.append(nxt)
		if options.is_empty():
			break
		cur = options[randi() % options.size()]
		path.append(cur)
	# A hand-made room (rooms.gd) in each cell of the path: the start room
	# first, the stair room last, combat rooms between. No room twice a floor.
	var rooms: Array = []
	var room_rows: Array = []
	var used: Array = []
	# One room between the start and the stair holds the floor's puzzle.
	var puzzle_at := 1 + randi() % maxi(path.size() - 2, 1) if path.size() >= 3 else -1
	var tier_cap := 1 if floor_num <= 3 else (2 if randf() < 0.5 else 1)
	var puzzle_room := {}
	for i in path.size():
		var c: Vector2i = path[i]
		var role := "start" if i == 0 else ("stair" if i == path.size() - 1 else "combat")
		if i == puzzle_at:
			role = "puzzle"
		var pick := _pick_room(role, floor_num, used, cell_size, tier_cap)
		if role == "puzzle":
			puzzle_room = pick
		used.append(pick["id"])
		var tiles := Rooms.size_of(pick)
		var size := Vector2(tiles) * CELL
		var origin: Vector2 = ARENA.position + Vector2(c) * cell_size
		var pos := origin + Vector2(randf_range(40.0, maxf(40.0, cell_size.x - 40.0 - size.x)), randf_range(50.0, maxf(50.0, cell_size.y - 40.0 - size.y)))
		pos = ARENA.position + ((pos - ARENA.position) / CELL).floor() * CELL
		rooms.append(Rect2(pos, size))
		var can_flip: bool = pick.get("flip", false)
		room_rows.append(Rooms.flipped(pick, can_flip and randf() < 0.5, can_flip and randf() < 0.5))
	# Corridors: an L from each room's centre to the next one's.
	var corridors: Array = []
	for i in rooms.size() - 1:
		corridors.append_array(_corridor(rooms[i].get_center(), rooms[i + 1].get_center()))
	var start: Vector2 = rooms[0].get_center() + Vector2(0, rooms[0].size.y * 0.25)
	var last: Rect2 = rooms[-1]
	var stair := Vector2(last.get_center().x, last.position.y + 34.0)
	# Sometimes a small dead-end room with an essence cache.
	var side: Dictionary = side_room(rooms, corridors, start, stair) if randf() < float(SIDE_ROOM["chance"]) else {}
	# The rooms' own features: walls, pillars, chasms, pools, monster spots.
	# Whatever stands in a corridor's way (or on the start or stair) is cleared.
	var pillars: Array = []
	var chasms: Array = []
	var room_blocks: Array = []
	var pools: Array = []
	var spots: Array = []  # [room index, pos]
	var keep_clear: Array = []
	for cr in corridors:
		keep_clear.append(cr)
	keep_clear.append(Rect2(start - Vector2(CELL, CELL) * 1.5, Vector2(CELL, CELL) * 3.0))
	keep_clear.append(Rect2(stair - Vector2(CELL, CELL) * 1.5, Vector2(CELL, CELL) * 3.0))
	var puzzle := {}
	for i in rooms.size():
		var f: Dictionary = Rooms.features(room_rows[i], rooms[i].position, CELL, tower)
		if i == puzzle_at and not puzzle_room.is_empty():
			puzzle = _puzzle_spec(puzzle_room, f, keep_clear, rooms[i])
		for b in f["blocks"]:
			if not _in_any_rect(b, keep_clear):
				room_blocks.append(b)
		for ch in f["chasms"]:
			if not _in_any_rect(ch.grow(CELL * 0.5), keep_clear):
				chasms.append(ch)
		for pl in f["pillars"]:
			if not _in_any(pl["pos"], keep_clear, pl["r"] + 8.0):
				pillars.append(pl)
		for pool in f["pools"]:
			pools.append({"pos": pool.get_center(), "r": CELL * 0.72})
		if i > 0:
			for sp in f["spots"]:
				spots.append([i, sp])
	room_blocks = Rooms.merge_rows(room_blocks)
	chasms = Rooms.merge_rows(chasms)
	# The Firebird's tower also breaks one corridor with a chasm (jump it, or fall).
	if tower.get("chasms", false):
		for c in corridors:
			var r: Rect2 = c
			var band := Rect2()
			if r.size.x > 260.0 and r.size.y < 140.0:  # a long east-west corridor
				band = Rect2(Vector2(r.get_center().x - 21.0, r.position.y), Vector2(42.0, r.size.y))
			elif r.size.y > 260.0 and r.size.x < 140.0:  # a long north-south one
				band = Rect2(Vector2(r.position.x, r.get_center().y - 21.0), Vector2(r.size.x, 42.0))
			if band.size != Vector2.ZERO and not band.grow(110.0).has_point(start) and not band.grow(80.0).has_point(stair):
				# Not where it opens into a room (the band must cross the corridor itself).
				var in_room := false
				for rm in rooms:
					in_room = in_room or rm.intersects(band)
				if not in_room:
					chasms.append(band)
					break
	# Cover: low walls in the bigger rooms, clear of every corridor's route.
	var halls: Array = corridors.duplicate()
	if not side.is_empty():
		halls.append(side["hall"])
	var blocks: Array = room_blocks
	# Monsters, spread over the rooms beyond the first.
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
	var monsters: Array = []
	var placed: Array = []
	spots.shuffle()
	# Monsters go to the combat and stair rooms (the puzzle room only gets its marked spots).
	var fight_rooms: Array = []
	for ri in range(1, rooms.size()):
		if ri != puzzle_at or puzzle.is_empty():
			fight_rooms.append(rooms[ri])
	for i in kinds.size():
		var r: Rect2 = fight_rooms[i % fight_rooms.size()]
		var pos := r.get_center()
		# The rooms' marked spots first (an archer on a balcony, a guard by a door).
		if not spots.is_empty():
			var sp: Array = spots.pop_back()
			if _clear_of(sp[1], 40.0, pillars, placed) and not _in_any(sp[1], chasms, 30.0) and not _in_any(sp[1], blocks, 30.0):
				placed.append(sp[1])
				monsters.append([kinds[i], sp[1]])
				continue
		for attempt in 40:
			pos = r.position + Vector2(randf_range(40.0, r.size.x - 40.0), randf_range(40.0, r.size.y - 40.0))
			if _clear_of(pos, 50.0, pillars, placed) and not _in_any(pos, chasms, 30.0) and not _in_any(pos, blocks, 34.0):
				break
		placed.append(pos)
		monsters.append([kinds[i], pos])
	var walk: Array = rooms.duplicate()
	walk.append_array(corridors)
	var plan := {"arena": ARENA, "rooms": rooms, "walk": walk, "start": start, "stair": stair,
		"pillars": pillars, "monsters": monsters, "chasms": chasms, "blocks": blocks,
		"pools": pools, "room_ids": used, "puzzle": puzzle}
	var all_rooms: Array = rooms.duplicate()
	if not side.is_empty():
		walk.append(side["room"])
		walk.append(side["hall"])
		all_rooms.append(side["room"])
		plan["side_room"] = side["room"]
		plan["cache"] = {"pos": side["room"].get_center(), "amount": cache_amount(floor_num)}
		# One of the floor's monsters may guard it, between the door and the cache.
		if monsters.size() >= 2 and randf() < float(SIDE_ROOM["guard_chance"]):
			monsters[-1][1] = side["room"].get_center().lerp(side["hall"].get_center(), 0.35)
	plan["doors"] = doorways(all_rooms, halls)
	return plan


## A room for a role that fits a cell, not used yet this floor.
static func _pick_room(role: String, floor_num: int, used: Array, cell_size: Vector2, tier_cap := 2) -> Dictionary:
	var fits: Array = Rooms.for_role(role, floor_num).filter(func(r):
		var sz := Vector2(Rooms.size_of(r)) * CELL
		return sz.x <= cell_size.x - 80.0 and sz.y <= cell_size.y - 90.0 and int(r.get("tier", 1)) <= tier_cap)
	var fresh: Array = fits.filter(func(r): return not (r["id"] in used))
	var pool: Array = fresh if not fresh.is_empty() else fits
	return pool[randi() % pool.size()]


## The puzzle in a room, from its features, or {} if a corridor ran through
## a piece it needs (then the floor has no puzzle and no ward).
static func _puzzle_spec(room_def: Dictionary, f: Dictionary, keep_clear: Array, rect: Rect2) -> Dictionary:
	for key in ["eyes", "plates", "pushers", "levers", "rewards"]:
		for p in f[key]:
			if _in_any(p, keep_clear, CELL * 0.6):
				return {}
	for key in ["rails", "gates"]:
		for r in f[key]:
			if _in_any_rect(r, keep_clear):
				return {}
	var kind: String = room_def["puzzle"]
	if kind == "eyes" and f["eyes"].is_empty():
		return {}
	if kind == "plates" and f["plates"].is_empty():
		return {}
	return {"type": kind, "tier": int(room_def.get("tier", 1)), "room": rect, "id": room_def["id"],
		"eyes": f["eyes"], "plates": f["plates"], "pushers": f["pushers"], "rails": f["rails"],
		"gates": f["gates"], "levers": f["levers"], "rewards": f["rewards"]}


static func _in_any_rect(r: Rect2, rects: Array) -> bool:
	for o in rects:
		if r.intersects(o):
			return true
	return false


## How much essence a cache holds on a floor.
static func cache_amount(floor_num: int) -> float:
	return float(CACHE["base"]) + float(CACHE["per_floor"]) * float(maxi(floor_num - 2, 0))


## Which tiles of the floor's grid a rect covers (the same way main.gd
## builds the grid, whose tiles start at ARENA's corner).
static func tile_rect(r: Rect2) -> Rect2i:
	var p := Vector2i(int((r.position.x - ARENA.position.x) / CELL), int((r.position.y - ARENA.position.y) / CELL))
	var e := Vector2i(int(ceil((r.end.x - ARENA.position.x) / CELL)), int(ceil((r.end.y - ARENA.position.y) / CELL)))
	return Rect2i(p, e - p)


## A small dead-end room off one of the rooms: {"room", "hall"}, or {} if
## none fits. It keeps a wall at least a tile and a half thick from
## everything else.
static func side_room(rooms: Array, corridors: Array, start: Vector2, stair: Vector2) -> Dictionary:
	var w := CELL * 3.0
	var lo: int = SIDE_ROOM["tiles"][0]
	var hi: int = SIDE_ROOM["tiles"][1]
	for attempt in 60:
		var host: Rect2 = rooms[randi() % rooms.size()]
		var size := Vector2(lo + randi() % (hi - lo + 1), lo + randi() % (hi - lo + 1)) * CELL
		var gap := CELL * float(3 + randi() % 2)
		var dir: Vector2 = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][randi() % 4]
		var side_r: Rect2
		var hall: Rect2
		var outer: Rect2  # the part of the hall between the two rooms
		if dir.x != 0.0:
			if host.size.y < w + 80.0:
				continue
			var y := randf_range(host.position.y + w * 0.5 + 40.0, host.end.y - w * 0.5 - 40.0)
			var shift := randf_range(-1.0, 1.0) * (size.y * 0.5 - w * 0.5 - CELL)
			var x := host.position.x - gap - size.x if dir.x < 0.0 else host.end.x + gap
			side_r = _snap(Rect2(Vector2(x, y - size.y * 0.5 + shift), size))
			var hx := side_r.end.x - CELL if dir.x < 0.0 else host.end.x - CELL
			hall = _snap(Rect2(Vector2(hx, y - w * 0.5), Vector2(gap + CELL * 2.0, w)))
			outer = Rect2(Vector2(side_r.end.x if dir.x < 0.0 else host.end.x, hall.position.y), Vector2(gap, hall.size.y))
		else:
			if host.size.x < w + 80.0:
				continue
			var x := randf_range(host.position.x + w * 0.5 + 40.0, host.end.x - w * 0.5 - 40.0)
			var shift := randf_range(-1.0, 1.0) * (size.x * 0.5 - w * 0.5 - CELL)
			var y := host.position.y - gap - size.y if dir.y < 0.0 else host.end.y + gap
			side_r = _snap(Rect2(Vector2(x - size.x * 0.5 + shift, y), size))
			var hy := side_r.end.y - CELL if dir.y < 0.0 else host.end.y - CELL
			hall = _snap(Rect2(Vector2(x - w * 0.5, hy), Vector2(w, gap + CELL * 2.0)))
			outer = Rect2(Vector2(hall.position.x, side_r.end.y if dir.y < 0.0 else host.end.y), Vector2(hall.size.x, gap))
		if not ARENA.grow(-CELL).encloses(side_r) or not host.intersects(hall) or not side_r.intersects(hall):
			continue
		var ok := not hall.grow(CELL * 2.0).has_point(stair) and not hall.grow(CELL * 2.0).has_point(start)
		ok = ok and not side_r.grow(CELL * 1.5).intersects(host)
		for other in rooms:
			if other != host:
				ok = ok and not side_r.grow(CELL * 1.5).intersects(other) and not outer.grow(CELL).intersects(other)
		for c in corridors:
			ok = ok and not side_r.grow(CELL * 1.5).intersects(c) and not outer.grow(CELL).intersects(c)
		if ok:
			return {"room": side_r, "hall": hall}
	return {}


## Low walls in the bigger rooms: one tile thick and a few long, kept two
## tiles from the room's walls and a tile from every corridor's route through
## the room (corridors run to each room's centre), so the way between
## doorways stays open. Not near the start, the stair, pillars or chasms.
static func cover_blocks(rooms: Array, halls: Array, start: Vector2, stair: Vector2, pillars: Array, chasms: Array) -> Array:
	var list: Array = []
	var lo: int = COVER["length"][0]
	var hi: int = COVER["length"][1]
	for r in rooms:
		var rr: Rect2 = r
		if rr.size.x * rr.size.y < float(COVER["min_area"]):
			continue
		var t := tile_rect(rr).grow(-2)  # the tiles a block may use
		var count: int = COVER["per_room"][0] + randi() % (COVER["per_room"][1] - COVER["per_room"][0] + 1)
		for k in count:
			for attempt in 20:
				var n := lo + randi() % (hi - lo + 1)
				var size := Vector2i(n, 1) if randf() < 0.5 else Vector2i(1, n)
				if t.size.x < size.x or t.size.y < size.y:
					continue
				var tp := t.position + Vector2i(randi() % (t.size.x - size.x + 1), randi() % (t.size.y - size.y + 1))
				var b := Rect2(ARENA.position + Vector2(tp) * CELL, Vector2(size) * CELL)
				if _cover_ok(b, halls, start, stair, pillars, chasms, list):
					list.append(b)
					break
	return list


static func _cover_ok(b: Rect2, halls: Array, start: Vector2, stair: Vector2, pillars: Array, chasms: Array, others: Array) -> bool:
	if b.grow(CELL * 3.0).has_point(start) or b.grow(CELL * 3.0).has_point(stair):
		return false
	for c in halls:
		if b.intersects(c.grow(CELL)):
			return false
	for p in pillars:
		var near := Vector2(clampf(p["pos"].x, b.position.x, b.end.x), clampf(p["pos"].y, b.position.y, b.end.y))
		if near.distance_to(p["pos"]) < p["r"] + 50.0:
			return false
	for ch in chasms:
		if b.grow(CELL * 1.5).intersects(ch):
			return false
	for o in others:
		if b.grow(CELL * 2.0).intersects(o):
			return false
	return true


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
		list.append(Rect2(ARENA.position + Vector2(t) * CELL, Vector2(CELL, CELL)))
	return list


static func _snap(r: Rect2) -> Rect2:
	var p := (r.position / CELL).round() * CELL
	var e := (r.end / CELL).round() * CELL
	return Rect2(p, e - p)


## An L-shaped corridor, three tiles wide, from a to b.
static func _corridor(a: Vector2, b: Vector2) -> Array:
	var w := CELL * 3.0
	var corner := Vector2(b.x, a.y) if randf() < 0.5 else Vector2(a.x, b.y)
	return [_snap(_band(a, corner, w)), _snap(_band(corner, b, w))]


static func _band(a: Vector2, b: Vector2, w: float) -> Rect2:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(w, w) * 0.5
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(w, w) * 0.5
	return Rect2(lo, hi - lo)


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
