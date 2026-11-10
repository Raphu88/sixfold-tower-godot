extends RefCounted
## The checks a hand-made room must pass before the floor planner may use
## it (the room painter, painter.gd, shows them as you paint; room_store.gd
## only lets a room into climbs once it passes). They follow what the game
## itself does with a room (rooms.gd, floors.gd, main.gd):
##   - a corridor meets a room only where two open tiles side by side reach
##     two tiles in (rooms.gd door_slots), away from the corners;
##   - a stair room's stair stands in the middle of its top row;
##   - everything that matters (the doorways, the stair, every monster spot,
##     where the climber starts, the plates) must be reachable, and a low
##     wall (a wall standing free inside the room) that would cut one off is
##     left out in play: rooms.gd cover_kept, the game's own check;
##   - a puzzle room holds what its puzzle needs.
## Chasms (C) are only real in towers that have them (the Firebird's), where
## they're jumped; elsewhere they're low walls. Water (~) is walked through.
## Pillars and rails count as solid here (stricter than the path grid).
##
## Each problem is {"text", "tiles" (Vector2i, to light on the grid),
## "level": "error" (the room can't be used until it's fixed), "warn" (it
## can, but something's off) or "info"}.

const Rooms := preload("res://scripts/rooms.gd")
const Towers := preload("res://scripts/towers.gd")

## The smallest and biggest a room may be, in tiles (the biggest must fit a
## cell of the floor's plan: rooms.gd MAX_SIZE).
const MIN_SIZE := Vector2i(7, 6)
const MAX_SIZE := Rooms.MAX_SIZE
## A room's jobs (rooms.gd "role") and the puzzles a hand-made room can hold.
const ROLES := ["start", "combat", "stair", "puzzle"]
const PUZZLES := ["eyes", "plates"]
## The tiles only a puzzle room uses.
const PUZZLE_TILES := "=EPBGL$"

## Every line the checks say (easy to reword).
const TEXT := {
	"bad_rows": "The room's rows aren't all the same length.",
	"bad_char": "Unknown tile \"%s\".",
	"empty": "The room is empty.",
	"too_small": "Too small: a room is at least %d tiles wide and %d tall.",
	"too_big": "Too big: a room is at most %d tiles wide and %d tall.",
	"bad_role": "Choose the room's job: start, combat, stair or puzzle.",
	"no_doors": "No side has room for a doorway. A doorway needs 2 open tiles side by side, 2 deep, away from the corners.",
	"side_no_door": "The %s side has no room for a doorway, so the room can only join rooms on its other sides (it will turn up less often).",
	"shut": "%s can't be reached: rock, pillars or rails shut it off.",
	"wall_cuts": "This low wall cuts off %s. In play it would be left out.",
	"stair_blocked": "The stair needs open floor in the middle of the top row.",
	"puzzle_kind": "A puzzle room needs its puzzle: eyes or plates.",
	"no_eyes": "A Hall of Eyes needs at least one stone eye (E).",
	"eye_hidden": "A stone eye can't be hit. Put open floor next to it, or let it be seen over a rail.",
	"no_plates": "A Weighing Room needs at least one pressure plate (P).",
	"few_weights": "More plates than blocks and monster spots to weigh them down.",
	"block_stuck": "A stone block can't be reached to push it.",
	"lever_cut": "The lever can't be reached.",
	"no_lever": "No lever (L): a block pushed into a corner can't be put back.",
	"reward_cut": "The reward ($) can't be reached, even with the gate open.",
	"reward_open": "The reward ($) isn't shut behind a gate (G).",
	"gate_alone": "A gate (G) with no reward ($) behind it.",
	"puzzle_tiles": "Rails, eyes, plates, blocks, gates, levers and rewards only work in puzzle rooms. Here they're bare floor.",
	"start_monsters": "Start rooms never hold monsters, so these spots are ignored.",
	"chasm_note": "Chasms (C) are only real in the Firebird's tower. In the other towers they're low walls.",
	"water_note": "Water (~) only fills in the Kraken's tower. In the other towers it's floor.",
}
## What can be cut off, as the checks name it.
const THINGS := {
	"door": "A doorway on the %s side",
	"stair": "The stair",
	"monster": "A monster spot",
	"start": "Where the climber starts",
	"plate": "A pressure plate",
}
const THINGS_LOW := {
	"door": "a doorway on the %s side",
	"stair": "the stair",
	"monster": "a monster spot",
	"start": "where the climber starts",
	"plate": "a pressure plate",
}
const SIDES := ["north", "south", "west", "east"]


## The room's problems in a tower (`tid`; "" for the strictest: chasms as walls).
static func problems(def: Dictionary, tid := "") -> Array:
	var out: Array = []
	var grid: Array = def.get("grid", [])
	if grid.is_empty() or String(grid[0]).length() == 0:
		return [_p(TEXT["empty"])]
	var w := String(grid[0]).length()
	for row in grid:
		if String(row).length() != w:
			return [_p(TEXT["bad_rows"])]
		for ch in String(row):
			if not Rooms.CHARS.contains(ch):
				return [_p(TEXT["bad_char"] % ch)]
	var h := grid.size()
	if w < MIN_SIZE.x or h < MIN_SIZE.y:
		out.append(_p(TEXT["too_small"] % [MIN_SIZE.x, MIN_SIZE.y]))
	if w > MAX_SIZE.x or h > MAX_SIZE.y:
		out.append(_p(TEXT["too_big"] % [MAX_SIZE.x, MAX_SIZE.y]))
	if not out.is_empty():
		return out
	var role: String = def.get("role", "")
	if not role in ROLES:
		out.append(_p(TEXT["bad_role"]))
		return out
	var real_chasms: bool = Towers.TOWERS.get(tid, {}).get("chasms", false)
	# The room as the game builds it: random tiles open (they may become a
	# low wall, which the game drops if it cuts anything off, or a pillar),
	# walls on its edge part of its outline.
	var rows: Array = Rooms.prepare(grid.map(func(r): return String(r).replace("?", ".")))
	var solid := PackedByteArray()
	solid.resize(w * h)
	var blocks: Array = []  # low walls, as runs of tiles along a row (rooms.gd features: merge_rows)
	var marks := {"M": [], "E": [], "P": [], "B": [], "G": [], "L": [], "$": [], "puzzle": []}
	for y in h:
		var run: Array = []
		for x in w:
			var ch: String = String(rows[y])[x]
			var t := Vector2i(x, y)
			var low := ch == "#" or (ch == "C" and not real_chasms)
			if low:
				run.append(t)
			elif not run.is_empty():
				blocks.append(run)
				run = []
			if ch in ["X", "o", "=", "E", "G", "L"]:
				solid[y * w + x] = 1
			if marks.has(ch):
				marks[ch].append(t)
			if PUZZLE_TILES.contains(ch):
				marks["puzzle"].append(t)
		if not run.is_empty():
			blocks.append(run)
	# The doorways: every place a corridor could meet each side.
	var doors: Array = []  # [tile, side]
	var sides_open: Array = []
	for side in 4:
		var slots: Array = Rooms.door_slots(rows, side)
		if role == "stair" and side == 0:
			var lo := int(floor(w * 0.5 - 0.85))
			var hi := int(floor(w * 0.5 + 0.85))
			slots = slots.filter(func(k): return k + 1 < lo - 1 or k > hi + 1)
		if slots.is_empty():
			continue
		sides_open.append(side)
		for k in slots:
			var t: Vector2i = [Vector2i(k, 0), Vector2i(k, h - 1), Vector2i(0, k), Vector2i(w - 1, k)][side]
			doors.append([t, side])
	if doors.is_empty():
		out.append(_p(TEXT["no_doors"]))
		return out
	for side in 4:
		if not side in sides_open and not (role == "stair" and side == 0):  # (a stair room's top is the stair's)
			out.append(_p(TEXT["side_no_door"] % SIDES[side], _side_tiles(side, w, h), "warn"))
	# What must be reachable: [tile, what, side].
	var goals: Array = []
	for d in doors:
		goals.append([d[0], "door", d[1]])
	if role == "stair":
		var c0 := int(w * 0.5 - 0.5)
		var c1 := int(w * 0.5)
		var stair_tiles: Array = []
		var open := true
		for x in range(c0, c1 + 1):
			stair_tiles.append(Vector2i(x, 0))
			open = open and ".M~".contains(String(rows[0])[x])
		if not open:
			out.append(_p(TEXT["stair_blocked"], stair_tiles))
		else:
			goals.append([Vector2i(c1, 0), "stair", -1])
	if role == "start":
		goals.append([_nearest_open(rows, Vector2i(w / 2, int(h * 0.72))), "start", -1])
		if not marks["M"].is_empty():
			out.append(_p(TEXT["start_monsters"], marks["M"], "warn"))
	else:
		for t in marks["M"]:
			goals.append([t, "monster", -1])
	if role == "puzzle":
		for t in marks["P"]:
			goals.append([t, "plate", -1])
	# 1. Shut in whatever the low walls do: rock, pillars, rails.
	# (from the doorway that opens onto the most of the room)
	var from: Vector2i = doors[0][0]
	var reach0 := {}
	for d in doors:
		if reach0.has(d[0]):
			continue
		var r := _flood(solid, w, h, [d[0]])
		if r.size() > reach0.size():
			reach0 = r
			from = d[0]
	var live: Array = []
	for g in goals:
		if reach0.has(g[0]):
			live.append(g)
		else:
			out.append(_p(TEXT["shut"] % _thing(g, false), [g[0]]))
	# 2. The low walls, one at a time, as the game lays them (main.gd).
	var final_solid := solid.duplicate()
	var kept: Array = Rooms.cover_kept(Vector2i(w, h), final_solid, blocks, from, live.map(func(g): return g[0]))
	for i in blocks.size():
		if i in kept:
			continue
		var test := final_solid.duplicate()
		for t in blocks[i]:
			test[t.y * w + t.x] = 1
		var r := _flood(test, w, h, [from])
		var cut: Array = live.filter(func(g): return not r.has(g[0]))
		var what := _thing(cut[0], true) if not cut.is_empty() else THINGS_LOW["monster"]
		var tiles: Array = blocks[i].duplicate()
		if not cut.is_empty():
			tiles.append(cut[0][0])
		out.append(_p(TEXT["wall_cuts"] % what, tiles))
	var reach := _flood(final_solid, w, h, [from])
	# 3. The puzzle.
	if role == "puzzle":
		var kind: String = def.get("puzzle", "")
		if not kind in PUZZLES:
			out.append(_p(TEXT["puzzle_kind"]))
		elif kind == "eyes":
			if marks["E"].is_empty():
				out.append(_p(TEXT["no_eyes"]))
			for e in marks["E"]:
				if not _can_hit(e, rows, reach, w, h):
					out.append(_p(TEXT["eye_hidden"], [e]))
		elif kind == "plates":
			if marks["P"].is_empty():
				out.append(_p(TEXT["no_plates"]))
			elif marks["B"].size() + marks["M"].size() < marks["P"].size():
				out.append(_p(TEXT["few_weights"], marks["P"], "warn"))
			for b in marks["B"]:
				if not _next_to(b, reach, false):
					out.append(_p(TEXT["block_stuck"], [b]))
			if marks["L"].is_empty() and not marks["B"].is_empty():
				out.append(_p(TEXT["no_lever"], [], "warn"))
		for l in marks["L"]:
			if not _next_to(l, reach, true):
				out.append(_p(TEXT["lever_cut"], [l]))
		if not marks["$"].is_empty():
			var gates_open := final_solid.duplicate()
			for g in marks["G"]:
				gates_open[g.y * w + g.x] = 0
			var reach_g := _flood(gates_open, w, h, [from])
			for r in marks["$"]:
				if not reach_g.has(r):
					out.append(_p(TEXT["reward_cut"], [r]))
				elif reach.has(r):
					out.append(_p(TEXT["reward_open"], [r], "warn"))
		elif not marks["G"].is_empty():
			out.append(_p(TEXT["gate_alone"], marks["G"], "warn"))
	elif not marks["puzzle"].is_empty():
		out.append(_p(TEXT["puzzle_tiles"], marks["puzzle"], "warn"))
	# The same problem in several places: one line, every place lit.
	var merged: Array = []
	for p in out:
		var same: Array = merged.filter(func(m): return m["text"] == p["text"] and m["level"] == p["level"])
		if same.is_empty():
			merged.append(p)
		else:
			for t in p["tiles"]:
				if not t in same[0]["tiles"]:
					same[0]["tiles"].append(t)
	return merged


## True if the room has no problem that stops it being used, in this tower.
static func passes(def: Dictionary, tid := "") -> bool:
	return not problems(def, tid).any(func(p): return p["level"] == "error")


## The towers where the room may appear and passes (its "towers", or all).
static func ok_towers(def: Dictionary) -> Array:
	var allowed: Array = def.get("towers", [])
	if allowed.is_empty():
		allowed = Towers.ORDER
	var out: Array = []
	var plain := -1  # (the towers without chasms all see the room the same way)
	for tid in allowed:
		if not Towers.TOWERS.has(tid):
			continue
		var ok: bool
		if Towers.TOWERS[tid].get("chasms", false):
			ok = passes(def, tid)
		else:
			if plain < 0:
				plain = 1 if passes(def, tid) else 0
			ok = plain == 1
		if ok:
			out.append(tid)
	return out


## Notes on how a room's tiles change from tower to tower (chasms, water).
static func notes(def: Dictionary) -> Array:
	var out: Array = []
	var text := "".join(PackedStringArray(def.get("grid", [])))
	if text.contains("C"):
		out.append(_p(TEXT["chasm_note"], [], "info"))
	if text.contains("~"):
		out.append(_p(TEXT["water_note"], [], "info"))
	return out


static func _p(text: String, tiles: Array = [], level := "error") -> Dictionary:
	return {"text": text, "tiles": tiles, "level": level}


static func _thing(g: Array, low: bool) -> String:
	var words: String = (THINGS_LOW if low else THINGS)[g[1]]
	return words % SIDES[g[2]] if g[1] == "door" else words


static func _side_tiles(side: int, w: int, h: int) -> Array:
	var out: Array = []
	var n := w if side < 2 else h
	for k in n:
		out.append([Vector2i(k, 0), Vector2i(k, h - 1), Vector2i(0, k), Vector2i(w - 1, k)][side])
	return out


## The open tile nearest `want` (floors.gd puts the climber's start there).
static func _nearest_open(rows: Array, want: Vector2i) -> Vector2i:
	var best := want
	var best_d := INF
	for y in rows.size():
		for x in String(rows[0]).length():
			if Rooms.open_at(rows, x, y):
				var d := Vector2(x - want.x, y - want.y).length_squared()
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


## Every tile reachable from `from` (diagonal steps only past two open
## sides, so the four directions are enough).
static func _flood(solid: PackedByteArray, w: int, h: int, from: Array) -> Dictionary:
	var seen := {}
	var todo: Array = []
	for f in from:
		if f.x >= 0 and f.y >= 0 and f.x < w and f.y < h and solid[f.y * w + f.x] == 0:
			seen[f] = true
			todo.append(f)
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n) or solid[n.y * w + n.x] == 1:
				continue
			seen[n] = true
			todo.append(n)
	return seen


## A reachable tile beside `t` (the four sides, or the eight with `diag`).
static func _next_to(t: Vector2i, reach: Dictionary, diag: bool) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx == 0 and dy == 0) or (not diag and dx != 0 and dy != 0):
				continue
			if reach.has(t + Vector2i(dx, dy)):
				return true
	return false


## An eye can be struck from beside it, or shot along a row or column over
## rails and floor (walls, pillars and rock stop arrows).
static func _can_hit(e: Vector2i, rows: Array, reach: Dictionary, w: int, h: int) -> bool:
	if _next_to(e, reach, true):
		return true
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = e + d
		while t.x >= 0 and t.y >= 0 and t.x < w and t.y < h:
			var ch: String = String(rows[t.y])[t.x]
			if not ".M~=P$B".contains(ch):
				break
			if reach.has(t):
				return true
			t += d
	return false
