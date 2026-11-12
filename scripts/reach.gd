extends RefCounted
## Can the climber always get out? Works out, on a floor's tile grid, where
## the climber can walk from a tile, the way the game's rules allow:
##   a closed door opens when you walk up to it, so it doesn't stop you;
##   a LOCKED door stops you until what opens it is in reach: its key or
##     lever lying somewhere you can walk to, the monster that carries its
##     key standing somewhere you can walk to, or (a warded door) the floor's
##     puzzle (its room, and for the Hall of Pedestals every mural);
##   shut doorways that open again by themselves (a lock-in room's bars, a
##     sealed wing's gate, a puzzle room's seal) don't count as walls.
## Each time a lock opens the walk goes on from where it reached, until
## nothing more opens (a fixpoint).
##
## Used twice: floors.gd checks every plan it makes with plan_check (a plan
## that fails is planned again), and main.gd's safety net checks the live
## floor with live_check (main.gd check_stuck: if the stair can't be reached,
## a lock whose opener can't be reached gives way). The tests (tests/parts/
## reachability.gd) sweep thousands of floors through plan_check.

const Floors := preload("res://scripts/floors.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Objectives := preload("res://scripts/objectives.gd")


## The walk itself. `size` and `solid` are the grid (1 = rock), `start` a
## tile. `doors`: [{tiles, lock, lock_id}] closed doors (lock "" for none);
## a lock kind that isn't key, carried, lever or puzzle (the Proving's own
## doors) is opened by its own flow, so it doesn't count. `opens`: lock_id
## -> {any: [tiles]} (any one reached opens it) or {all: [tiles]} (every
## one reached opens it). Gives {reach: PackedByteArray (1 = reached),
## open: {lock_id: true}, blocked: [lock ids of locked doors the walk
## reached but couldn't pass]}.
static func flood(size: Vector2i, solid: PackedByteArray, start: Vector2i, doors: Array, opens: Dictionary) -> Dictionary:
	var n := size.x * size.y
	var lock_at := PackedInt32Array()  # per tile: the lock id holding it shut, or 0
	lock_at.resize(n)
	var walkable := PackedByteArray()  # per tile: 1 = may be walked (locks aside)
	walkable.resize(n)
	for i in n:
		walkable[i] = 1 if solid[i] == 0 else 0
	for d in doors:
		var kind := String(d.get("lock", ""))
		var locked := kind in ["key", "carried", "lever", "puzzle", "oneway", "gate"]
		for t in d["tiles"]:
			if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
				continue
			var i: int = t.y * size.x + t.x
			walkable[i] = 1
			if locked:
				lock_at[i] = int(d.get("lock_id", 0))
	var reach := PackedByteArray()
	reach.resize(n)
	var open := {}
	if start.x < 0 or start.y < 0 or start.x >= size.x or start.y >= size.y:
		return {"reach": reach, "open": open, "blocked": []}
	var queue := PackedInt32Array()
	var waiting := {}  # lock id -> tiles held by it next to reached ones
	queue.append(start.y * size.x + start.x)
	reach[queue[0]] = 1
	var head := 0
	while true:
		while head < queue.size():
			var i: int = queue[head]
			head += 1
			var x := i % size.x
			var y := i / size.x
			for k in 4:
				var nx := x + (1 if k == 0 else (-1 if k == 1 else 0))
				var ny := y + (1 if k == 2 else (-1 if k == 3 else 0))
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var j := ny * size.x + nx
				if reach[j] == 1 or walkable[j] == 0:
					continue
				var lid := lock_at[j]
				if lid != 0 and not open.has(lid):
					if not waiting.has(lid):
						waiting[lid] = []
					waiting[lid].append(j)
					continue
				reach[j] = 1
				queue.append(j)
		# Nothing more to walk to: does a lock open now?
		var opened := false
		for lid in waiting.keys():
			if _opens(opens.get(lid, {}), reach, size):
				open[lid] = true
				for j in waiting[lid]:
					if reach[j] == 0:
						reach[j] = 1
						queue.append(j)
				waiting.erase(lid)
				opened = true
		# (a lock whose door isn't in reach yet may open too: noted for the report)
		for lid in opens:
			if not open.has(lid) and _opens(opens[lid], reach, size):
				open[lid] = true
		if not opened:
			break
	return {"reach": reach, "open": open, "blocked": waiting.keys()}


static func _opens(need: Dictionary, reach: PackedByteArray, size: Vector2i) -> bool:
	if need.has("all"):
		for t in need["all"]:
			if not reached(reach, size, t):
				return false
		return not need["all"].is_empty()
	for t in need.get("any", []):
		if reached(reach, size, t):
			return true
	return false


static func reached(reach: PackedByteArray, size: Vector2i, t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and reach[t.y * size.x + t.x] == 1


## A world position's tile (the grid starts at Floors.ORIGIN).
static func tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - Floors.ORIGIN.x) / Floors.CELL)), int(floor((pos.y - Floors.ORIGIN.y) / Floors.CELL)))


## Whether any tile under a world rect (or next to a world point) is reached.
static func rect_reached(reach: PackedByteArray, size: Vector2i, r: Rect2) -> bool:
	var tr := Floors.tile_rect(r)
	for y in range(tr.position.y, tr.end.y):
		for x in range(tr.position.x, tr.end.x):
			if reached(reach, size, Vector2i(x, y)):
				return true
	return false


## A point counts as reached when its own tile or one next to it is (a key
## or a monster may sit at a tile's edge, by a pillar or a wall).
static func near_reached(reach: PackedByteArray, size: Vector2i, pos: Vector2) -> bool:
	var t := tile(pos)
	for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if reached(reach, size, t + d):
			return true
	return false


static func _near_tiles(pos: Vector2) -> Array:
	var t := tile(pos)
	return [t, t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]


## --- a plan (floors.gd) -------------------------------------------------------------

## A plan's grid as main.gd builds it (_build_layout): its walkable areas,
## the cover it keeps (Floors.cover_targets: the same goals main.gd uses), a
## secret room's passage and room as rock, and every vault door shut.
static func plan_grid(plan: Dictionary) -> Dictionary:
	var arena: Rect2 = plan.get("arena", Floors.ARENA)
	var size := Vector2i(int(arena.size.x / Floors.CELL), int(arena.size.y / Floors.CELL))
	var solid := PackedByteArray()
	solid.resize(size.x * size.y)
	solid.fill(1)
	for r in plan.get("walk", []):
		_fill(solid, size, Floors.tile_rect(r), 0)
	var from := tile(plan.get("start", Vector2.ZERO))
	var goals: Array = []
	if _open_tile(solid, size, from):
		for g in Floors.cover_targets(plan):
			var t := tile(g)
			if _open_tile(solid, size, t):
				goals.append(t)
	var block_tiles: Array = []
	for b in plan.get("blocks", []):
		var list: Array = []
		var tr := Floors.tile_rect(b)
		for y in range(tr.position.y, tr.end.y):
			for x in range(tr.position.x, tr.end.x):
				list.append(Vector2i(x, y))
		block_tiles.append(list)
	Rooms.cover_kept(size, solid, block_tiles, from, goals)  # (marks the kept cover solid)
	# A tower's own ground no one walks (plan["impassable"], from its floor
	# script: the Kraken's deep pools and flooding corridors, the Gryphon's
	# drops, the Wyvern's molten channels, bridges left out). What a tower
	# opens in play (a moat, a gap, a sunken room, a raised bridge) is a gate
	# instead: plan["gates"], see plan_check.
	for r in plan.get("impassable", []):
		_fill(solid, size, Floors.tile_rect(r), 1)
	for s in plan.get("secrets", []):
		for r in [s["rect"], s["corridor"]] + ([s["alcove"]] if s.has("alcove") else []):
			_fill(solid, size, Floors.tile_rect(r), 1)
		if s.has("vault_door"):
			_fill(solid, size, Rect2i(s["vault_door"], Vector2i.ONE), 1)
	for w in plan.get("wings", []):
		_fill(solid, size, Rect2i(w["vault_door"], Vector2i.ONE), 1)
	# Cracked walls are rock until broken (never needed), and so is what's behind.
	for c in plan.get("cracks", []):
		for t in c["tiles"]:
			_fill(solid, size, Rect2i(t, Vector2i.ONE), 1)
		if String(c["kind"]) != "loop" and c.has("alcove"):
			_fill(solid, size, Floors.tile_rect(c["alcove"]), 1)
	return {"size": size, "solid": solid}


## The tiles the stair's ward asks the climber to reach on a plan: the
## task's pieces (objectives.gd), or the puzzle's room and its murals when
## the puzzle is the task.
static func ward_tiles(plan: Dictionary, solid: PackedByteArray, size: Vector2i) -> Array:
	var out: Array = []
	var obj: Dictionary = plan.get("objective", {})
	var pz: Dictionary = plan.get("puzzle", {})
	if not obj.is_empty() and not obj.get("puzzle", false):
		for p in Objectives.targets(obj):
			out.append(tile(p))
		return out
	if pz.is_empty() or pz.get("optional", false):
		return out
	var gallery: Rect2 = pz.get("room", Rect2())
	if gallery.has_area():
		out.append(_open_in(solid, size, gallery))
	for m in pz.get("murals", []):
		out.append(tile(Vector2(m["pos"]) + Vector2(0, 30)))
	return out


static func _fill(solid: PackedByteArray, size: Vector2i, tr: Rect2i, v: int) -> void:
	for y in range(maxi(tr.position.y, 0), mini(tr.end.y, size.y)):
		for x in range(maxi(tr.position.x, 0), mini(tr.end.x, size.x)):
			solid[y * size.x + x] = v


static func _open_tile(solid: PackedByteArray, size: Vector2i, t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and solid[t.y * size.x + t.x] == 0


## Checks a plan: {ok, stair, rooms (indices not reached), wings (ids not
## reached), locks (ids whose opener is never reached), problems (words)}.
## Secret rooms and wing interiors don't count; a wing's door does.
static func plan_check(plan: Dictionary) -> Dictionary:
	var out := {"ok": true, "stair": true, "rooms": [], "wings": [], "locks": [], "problems": []}
	if not plan.has("room_info") or plan.get("walk", []).is_empty():
		return out  # (an open floor: nothing walls anything off)
	var g := plan_grid(plan)
	var size: Vector2i = g["size"]
	var solid: PackedByteArray = g["solid"]
	var doors: Array = []
	var opens := {}
	var puzzle_all: Array = ward_tiles(plan, solid, size)
	# A monster carries one key (doors.gd tag_carriers: the last lock to name it wins).
	var carries := {}
	for d in plan.get("doors", []) + plan.get("wings", []):
		if String(d.get("lock", "")) == "carried":
			carries[int(d.get("lock_carrier", -1))] = int(d.get("lock_id", 0))
	for d in plan.get("doors", []) + plan.get("wings", []):
		var tiles: Array = d["door"] if d.get("kind", "") == "wing" else d["tiles"]  # (a wing's "tiles" are its room)
		var kind := String(d.get("lock", ""))
		doors.append({"tiles": tiles, "lock": kind, "lock_id": int(d.get("lock_id", 0))})
		if kind == "":
			continue
		var lid := int(d.get("lock_id", 0))
		match kind:
			"key", "lever":
				opens[lid] = {"any": _near_tiles(d.get("lock_pos", Vector2.INF))} if d.has("lock_pos") else {}
			"carried":
				var c := int(d.get("lock_carrier", -1))
				var mons: Array = plan.get("monsters", [])
				opens[lid] = {"any": _near_tiles(mons[c][1])} if c >= 0 and c < mons.size() and int(carries.get(c, -1)) == lid else {}
			"puzzle":
				opens[lid] = {"all": puzzle_all}
			"oneway":
				opens[lid] = {"any": d.get("lock_side", [])}
	# A tower's own gates (plan["gates"], from its floor script: the Kraken's
	# moat and sunken rooms, the Gryphon's gap, the Wyvern's raised bridges):
	# shut until what opens them is reached, like a lever's door.
	# {tiles, lock_id, opens: {any: [tiles]} (any one reached) or {all: [tiles]}}
	for gt in plan.get("gates", []):
		doors.append({"tiles": gt["tiles"], "lock": "gate", "lock_id": int(gt["lock_id"])})
		opens[int(gt["lock_id"])] = gt["opens"]
	var start := tile(plan.get("start", Vector2.ZERO))
	var f := flood(size, solid, start, doors, opens)
	var reach: PackedByteArray = f["reach"]
	# The stair, and its ward (the puzzle).
	var stair_ok := near_reached(reach, size, plan.get("stair", Vector2.ZERO))
	if not puzzle_all.is_empty():
		for t in puzzle_all:
			stair_ok = stair_ok and reached(reach, size, t)
	if not stair_ok:
		out["stair"] = false
		out["problems"].append("the stair can't be reached")
	for l in plan.get("locks", []):
		if not f["open"].has(int(l["id"])):
			out["locks"].append(int(l["id"]))
			out["problems"].append("lock %d (%s) never opens" % [int(l["id"]), String(l["kind"])])
	var info: Array = plan["room_info"]
	for i in info.size():
		var walked := false
		for r in info[i]["walk"]:
			walked = walked or rect_reached(reach, size, r)
		if not walked:
			out["rooms"].append(i)
			out["problems"].append("room %d (%s, %s) can't be reached" % [i, String(info[i]["role"]), String(info[i]["theme"])])
	for w in plan.get("wings", []):
		if not rect_reached(reach, size, w["rect"]):
			out["wings"].append(String(w.get("id", "wing")))
			out["problems"].append("%s can't be reached" % String(w.get("id", "wing")))
	out["ok"] = out["problems"].is_empty()
	return out


## An open tile of a room (its middle if that's open), for "reached the room".
static func _open_in(solid: PackedByteArray, size: Vector2i, r: Rect2) -> Vector2i:
	var c := tile(r.get_center())
	if _open_tile(solid, size, c):
		return c
	var tr := Floors.tile_rect(r)
	var best := c
	var best_d := INF
	for y in range(tr.position.y, tr.end.y):
		for x in range(tr.position.x, tr.end.x):
			var t := Vector2i(x, y)
			if _open_tile(solid, size, t):
				var dd := Vector2(t).distance_squared_to(Vector2(c))
				if dd < best_d:
					best_d = dd
					best = t
	return best


## --- the live floor (main.gd) ---------------------------------------------------------

## Checks the floor being played from the climber's tile (or `from`), with
## what's true now: keys taken or lying where they fell, levers pulled,
## carriers where they stand, the puzzle solved or not, murals seen.
## {checked (false when there's nothing to check), stair (it, and what
## lifts its ward, can be reached), blocked (lock ids of locked doors in
## reach whose opener isn't), reach, size}.
static func live_check(main, from := Vector2.INF) -> Dictionary:
	var out := {"checked": false, "stair": true, "blocked": []}
	if main == null or not main.layout_on or main.solid.is_empty() or main.door_view == null or main.player == null:
		return out
	var size: Vector2i = main.grid_size
	var solid: PackedByteArray = main.solid.duplicate()
	var dv = main.door_view
	# Doorways shut for now (a lock-in room's bars) open again by themselves.
	for i in dv.lock_rooms:
		var lr: Dictionary = dv.lock_rooms[i]
		if String(lr.get("state", "")) == "shut":
			for g in lr["gates"]:
				for t in g:
					if t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y:
						solid[t.y * size.x + t.x] = 0
	var pz = main.puzzle
	var puzzle_all: Array = []
	var ob = main.get("objective")
	if main.ward and ob != null and ob.kind != "" and not ob.spec.get("puzzle", false):
		for p in ob.live_targets():
			puzzle_all.append(tile(p))
	elif main.ward and pz != null and String(pz.kind) != "" and not pz.solved:
		puzzle_all.append(_open_in(solid, size, pz.room))
		if pz.cur != null and "murals" in pz.cur:
			for m in pz.cur.murals:
				if not m.get("seen", false):
					puzzle_all.append(tile(Vector2(m["pos"]) + Vector2(0, 30)))
	var doors: Array = []
	var opens := {}
	for d in dv.list:
		var kind := String(d["lock"]) if not d["open"] else ""
		var lid := int(d.get("lock_id", 0))
		if kind in ["key", "carried"] and lid in dv.held:
			kind = ""  # (its key is in hand)
		doors.append({"tiles": d["tiles"], "lock": kind, "lock_id": lid})
		if kind == "" or opens.has(lid):
			continue
		if kind == "oneway":
			opens[lid] = {"any": d.get("lock_side", [])}
			continue
		var any: Array = []
		for k in dv.keys:
			if not k["taken"] and int(k["lock_id"]) == lid:
				any.append_array(_near_tiles(k["pos"]))
		for l in dv.levers:
			if not l["pulled"] and int(l["lock_id"]) == lid:
				any.append_array(_near_tiles(l["pos"]))
		for e in main.get_tree().get_nodes_in_group("enemies"):  # (not main.enemies(): its list is kept for a frame)
			if is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion() and e.has_meta("key") and int(e.get_meta("key")) == lid:
				any.append_array(_near_tiles(e.global_position))
		opens[lid] = {"all": puzzle_all} if kind == "puzzle" else {"any": any}
	# The tower's own ground and gates as they are now (main.tower_floor).
	var own = main.get("tower_floor")
	if own != null and is_instance_valid(own):
		own.reach_live(solid, size, doors, opens)
	var start := tile(main.player.global_position if from == Vector2.INF else from)
	if not _open_tile(solid, size, start):
		# (standing in a doorway that's shut, or over a pit: look from a tile beside)
		var found := false
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if _open_tile(solid, size, start + d):
				start += d
				found = true
				break
		if not found:
			return out
	var f := flood(size, solid, start, doors, opens)
	var reach: PackedByteArray = f["reach"]
	var ok := near_reached(reach, size, main.stair_pos)
	for t in puzzle_all:
		ok = ok and reached(reach, size, t)
	out["checked"] = true
	out["stair"] = ok
	out["blocked"] = f["blocked"].filter(func(lid): return not f["open"].has(lid))
	out["reach"] = reach
	out["size"] = size
	out["open"] = f["open"]
	out["opens"] = opens
	return out
