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


## A floor of 3-5 rooms joined by corridors. You start in the first room; the
## stair is in the last. Monsters wait in the rooms beyond the first.
static func rooms_floor(floor_num: int, tower: Dictionary) -> Dictionary:
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
	# A room in each cell of the path, snapped to the tile grid.
	var rooms: Array = []
	for c in path:
		var origin: Vector2 = ARENA.position + Vector2(c) * cell_size
		var size := Vector2(randf_range(380.0, cell_size.x - 80.0), randf_range(320.0, cell_size.y - 90.0))
		var pos := origin + Vector2(randf_range(40.0, cell_size.x - 40.0 - size.x), randf_range(50.0, cell_size.y - 40.0 - size.y))
		rooms.append(_snap(Rect2(pos, size)))
	# Corridors: an L from each room's centre to the next one's.
	var corridors: Array = []
	for i in rooms.size() - 1:
		corridors.append_array(_corridor(rooms[i].get_center(), rooms[i + 1].get_center()))
	var start: Vector2 = rooms[0].get_center() + Vector2(0, rooms[0].size.y * 0.25)
	var last: Rect2 = rooms[-1]
	var stair := Vector2(last.get_center().x, last.position.y + 34.0)
	# Pillars in the bigger rooms, clear of the middle (where corridors meet).
	var pillars: Array = []
	for r in rooms:
		if r.size.x * r.size.y < 170000.0:
			continue
		for k in randi() % 3:
			var pp: Vector2 = r.position + Vector2(randf_range(70.0, r.size.x - 70.0), randf_range(70.0, r.size.y - 70.0))
			if pp.distance_to(r.get_center()) > 110.0 and pp.distance_to(stair) > 90.0 and _clear_of(pp, 70.0, pillars, []):
				pillars.append({"pos": pp, "r": randf_range(18.0, 28.0)})
	# Chasms (the Firebird's tower): one in some rooms, and one across a corridor.
	var chasms: Array = []
	if tower.get("chasms", false):
		for i in range(1, rooms.size()):
			if randf() < 0.7:
				var inner: Array = chasm_layout(rooms[i].grow(-20.0), pillars, rooms[i].get_center())
				if not inner.is_empty():
					var ch: Rect2 = inner[0]
					if not ch.grow(40.0).has_point(stair):
						chasms.append(ch)
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
	for i in kinds.size():
		var r: Rect2 = rooms[1 + i % (rooms.size() - 1)]
		var pos := r.get_center()
		for attempt in 40:
			pos = r.position + Vector2(randf_range(40.0, r.size.x - 40.0), randf_range(40.0, r.size.y - 40.0))
			if _clear_of(pos, 50.0, pillars, placed) and not _in_any(pos, chasms, 30.0):
				break
		placed.append(pos)
		monsters.append([kinds[i], pos])
	var walk: Array = rooms.duplicate()
	walk.append_array(corridors)
	return {"arena": ARENA, "rooms": rooms, "walk": walk, "start": start, "stair": stair,
		"pillars": pillars, "monsters": monsters, "chasms": chasms}


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
