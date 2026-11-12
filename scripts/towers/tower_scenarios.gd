extends RefCounted
## The towers' own scenario rooms (scenarios.gd: SCENARIOS entries with a
## "script" here). Both wait on the gilt mark like the others.
##   burning_bridge  (the Firebird's) the room is broken by a chasm, a narrow
##                   bridge across it. Step onto the mark and the bridge
##                   starts burning away behind you while the tower's
##                   creatures come at you from the far side: cross before
##                   the fire overtakes you (it drops you to the floor
##                   below). The bridge knits back once it's over.
##   thicket         (the Chimera's) the closing thicket: step onto the mark
##                   at the room's far end and thorns grow in from the
##                   edges, ring by ring, with hedges between you and the
##                   way out. Cut your way back to the doorway before the
##                   thicket seals it. It withers once it's over, whatever
##                   happens: you're never shut in.
## plan_extra finishes each one's plan (scenarios.gd plan); the rest runs
## from scenarios.gd. Numbers are its SCENARIOS, words its TEXT.

const ORIGIN := Vector2(80, 100)
const CELL := 40.0
const Rooms := preload("res://scripts/rooms.gd")


static func _cfg(kind: String) -> Dictionary:
	return load("res://scripts/scenarios.gd").SCENARIOS[kind]


static func _text() -> Dictionary:
	return load("res://scripts/scenarios.gd").TEXT


# --- planning -------------------------------------------------------------------------

## Finishes a scenario's plan; {} if the room won't do.
static func plan_extra(out: Dictionary, info: Dictionary, gates: Array, _floor_num: int, cell: float) -> Dictionary:
	match String(out["kind"]):
		"burning_bridge":
			return _plan_bridge(out, info, gates, cell)
		"thicket":
			return _plan_thicket(out, info, gates, cell)
	return out


static func _plan_bridge(out: Dictionary, info: Dictionary, gates: Array, cell: float) -> Dictionary:
	# Along the room's long way if its doorways allow, else across it.
	var long_x: bool = info["size"].x >= info["size"].y
	for ax in [long_x, not long_x]:
		var res := _bridge_along(out.duplicate(true), info, gates, cell, ax)
		if not res.is_empty():
			return res
	return {}


static func _bridge_along(out: Dictionary, info: Dictionary, gates: Array, cell: float, ax: bool) -> Dictionary:
	var rect: Rect2 = info["rect"]
	var rows: Array = info["rows"]
	var size: Vector2i = info["size"]
	var n := size.x if ax else size.y
	var m := size.y if ax else size.x
	if n < 8 or m < 5:
		return {}
	# Every doorway must be at an end, clear of the chasm; the near end is
	# the room's own doorway's (the first).
	var flip := false
	for gi in gates.size():
		var gt: Vector2i = Vector2i(gates[gi][0]) - Vector2i(info["pos"])
		var along := gt.x if ax else gt.y
		if along >= n * 0.3 and along <= n * 0.7:
			return {}
		if gi == 0:
			flip = along > n * 0.7
	var tile := func(u: int, v: int) -> Vector2i:
		var uu := (n - 1 - u) if flip else u
		return Vector2i(uu, v) if ax else Vector2i(v, uu)
	var a0 := int(n * 0.32)
	var a1 := int(ceil(n * 0.76))
	var mid := m / 2 - 1
	var chasms: Array = []
	var steps: Array = []
	for u in range(a0, a1):
		var step: Array = []
		for v in m:
			var t: Vector2i = tile.call(u, v)
			if not Rooms.open_at(rows, t.x, t.y):
				continue
			var r := Rect2(rect.position + Vector2(t) * cell, Vector2(cell, cell))
			if v == mid or v == mid + 1:
				step.append(r)
			else:
				chasms.append(r)
		if step.size() < 2:
			return {}
		steps.append(step[0].merge(step[1]))
	var s_t: Vector2i = tile.call(maxi(1, a0 - 1), mid)
	var e_t: Vector2i = tile.call(mini(n - 1, a1 + 1), mid)
	if not Rooms.open_at(rows, s_t.x, s_t.y) or not Rooms.open_at(rows, e_t.x, e_t.y):
		return {}
	out["start"] = rect.position + (Vector2(s_t) + Vector2(1.0, 0.5) if not ax else Vector2(s_t) + Vector2(0.5, 1.0)) * cell
	out["end"] = rect.position + (Vector2(e_t) + Vector2(1.0, 0.5) if not ax else Vector2(e_t) + Vector2(0.5, 1.0)) * cell
	out["keep"] = [out["start"], out["end"]]
	out["chasms"] = chasms
	out["steps"] = steps
	var far: Array = []
	for u in range(a1, n):
		for v in m:
			var t: Vector2i = tile.call(u, v)
			if Rooms.open_at(rows, t.x, t.y):
				far.append(rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * cell)
	if far.size() < 3:
		return {}
	far.shuffle()
	out["spawns"] = far.slice(0, 8)
	for r in chasms:
		info["reserved"][Vector2i(((r.position - rect.position) / cell).round())] = true
	return out


static func _plan_thicket(out: Dictionary, info: Dictionary, gates: Array, cell: float) -> Dictionary:
	var rect: Rect2 = info["rect"]
	var rows: Array = info["rows"]
	var door := rect.get_center()
	if not gates.is_empty():
		door = ORIGIN + (Vector2(gates[0][0]) + Vector2(0.5, 0.5)) * cell
	var open: Array = Rooms.open_tiles(rows, 0).filter(func(t): return not info["reserved"].has(t) or Vector2(rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * cell).distance_to(door) < cell * 2.0)
	if open.size() < 20:
		return {}
	var at := func(t: Vector2i) -> Vector2: return rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * cell
	open.sort_custom(func(a, b): return at.call(a).distance_to(door) < at.call(b).distance_to(door))
	var end: Vector2 = at.call(open[0])
	var start: Vector2 = at.call(open[-1])
	if start.distance_to(end) < cell * 5.0:
		return {}
	out["start"] = start
	out["end"] = end
	out["keep"] = [start, end]
	out["door"] = door
	return out


# --- running (scenarios.gd) -------------------------------------------------------------

static func _firebird(host):
	for sys in host.main.tower_systems:
		if sys.has_method("set_burnt"):
			return sys
	return null


static func _thorns(host):
	for sys in host.main.tower_systems:
		if sys.has_method("add_thorn"):
			return sys
	return null


static func begin(host, s: Dictionary) -> void:
	var cfg := _cfg(s["kind"])
	match String(s["kind"]):
		"burning_bridge":
			s["burn_t"] = float(cfg["delay"])
			s["burnt"] = 0
			s["limit"] = float(cfg["delay"]) + float(cfg["step"]) * s["steps"].size() + 6.0
			for k in int(cfg["foes"]) + host.main.floor_num / 4:
				var e = host._spawn(s, 2.0)
				if e != null:
					e.wake()
		"thicket":
			var ch = _thorns(host)
			s["grown"] = []
			s["ring_t"] = 1.0
			s["ring"] = 0
			var main = host.main
			# The open tiles of the room, by how far they are from its edge.
			var tiles: Array = []
			for r in main.room_info[s["room"]]["walk"]:
				for t in main._tiles_in(r):
					if not main._is_solid_tile(t.x, t.y):
						tiles.append(t)
			var set_ := {}
			for t in tiles:
				set_[t] = true
			var depth := {}
			var q: Array = []
			for t in tiles:
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if not set_.has(t + d):
						depth[t] = 0
						q.append(t)
						break
			while not q.is_empty():
				var t: Vector2i = q.pop_front()
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nb: Vector2i = t + d
					if set_.has(nb) and not depth.has(nb):
						depth[nb] = int(depth[t]) + 1
						q.append(nb)
			s["depth"] = depth
			s["rings"] = 0
			for t in depth:
				s["rings"] = maxi(int(s["rings"]), int(depth[t]))
			# Hedges across the way out, at a third and two thirds of the way.
			var a: Vector2 = s["start"]
			var b: Vector2 = s["end"]
			var hedges := 0
			for f in cfg["hedges"]:
				var c: Vector2 = a.lerp(b, float(f))
				var nrm: Vector2 = (b - a).normalized()
				for t in tiles:
					var wp: Vector2 = main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
					if absf((wp - c).dot(nrm)) < CELL * 0.55 and wp.distance_to(s["end"]) > CELL * 1.5:
						if ch != null and wp.distance_to(main.player.global_position) > CELL:
							s["grown"].append(ch.add_thorn([t], "scenario"))
							hedges += 1
			var path := a.distance_to(b) / CELL
			s["limit"] = path * float(cfg["per_tile"]) + float(cfg["base"]) + hedges * float(cfg["per_hedge"])


static func tick(host, s: Dictionary, delta: float, p) -> void:
	var cfg := _cfg(s["kind"])
	match String(s["kind"]):
		"burning_bridge":
			if not Rect2(s["rect"]).grow(60.0).has_point(p.global_position) and not p.in_air():
				host._finish(s, "none", _text()["left"])
				return
			if float(s["t"]) > float(s["limit"]) + 4.0:
				host._finish(s, "none")  # (the bridge is all burnt and you never crossed)
				return
			s["burn_t"] -= delta
			if s["burn_t"] <= 0.0 and int(s["burnt"]) < s["steps"].size():
				s["burn_t"] = float(cfg["step"])
				var fb = _firebird(host)
				if fb != null:
					fb.set_burnt(["scn", s["room"], s["burnt"]], s["steps"][s["burnt"]], true)
				host.main.fx_burst(Rect2(s["steps"][s["burnt"]]).get_center(), Vector2.DOWN, Color(1.0, 0.55, 0.25), 10, 140.0)
				host.main.sfx("burn", 0.9, -6.0)
				s["burnt"] += 1
			if p.global_position.distance_to(s["end"]) < 30.0:
				var hits: int = s["hits"]
				host._finish(s, "gold" if hits <= int(cfg["gold_hits"]) and s["t"] <= s["limit"] * 0.7 else ("silver" if hits <= int(cfg["silver_hits"]) else "bronze"))
		"thicket":
			var ch = _thorns(host)
			if ch == null:
				return
			if p.global_position.distance_to(s["end"]) < 34.0:
				var hits: int = s["hits"]
				host._finish(s, "gold" if hits <= int(cfg["gold_hits"]) and s["t"] <= s["limit"] * 0.6 else ("silver" if s["t"] <= s["limit"] * 0.85 else "bronze"))
				return
			if s["t"] >= s["limit"]:
				host._finish(s, "none", _text()["thicket_shut"])
				return
			s["ring_t"] -= delta
			if s["ring_t"] <= 0.0 and int(s["ring"]) <= int(s["rings"]):
				s["ring_t"] = float(cfg["ring_every"])
				var main = host.main
				for t in s["depth"]:
					if int(s["depth"][t]) != int(s["ring"]):
						continue
					var wp: Vector2 = main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
					if wp.distance_to(s["end"]) < CELL * 1.6 or wp.distance_to(p.global_position) < CELL * 1.1:
						continue
					if main.enemies().any(func(e): return e.global_position.distance_to(wp) < CELL * 0.8):
						continue
					s["grown"].append(ch.add_thorn([t], "scenario"))
				s["ring"] += 1


## Ends: the bridge knits back, the thicket withers.
static func finish(host, s: Dictionary) -> void:
	match String(s["kind"]):
		"burning_bridge":
			var fb = _firebird(host)
			if fb == null:
				return
			var keys: Array = []
			for i in int(s.get("burnt", 0)):
				keys.append(["scn", s["room"], i])
			host.get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(fb) and fb.on:
					for k in keys:
						if fb.burnt.has(k):
							fb.set_burnt(k, Rect2(), false))
		"thicket":
			var ch = _thorns(host)
			if ch == null:
				return
			var grown: Array = s.get("grown", [])
			host.get_tree().create_timer(1.2).timeout.connect(func():
				if is_instance_valid(ch):
					for th in grown:
						if th in ch.thorns:
							ch.remove_thorn(th))


static func status(_host, s: Dictionary) -> Dictionary:
	var tx := _text()
	match String(s["kind"]):
		"burning_bridge":
			return {"title": tx["burning_bridge"], "line": tx["burning_bridge_line"] % [s["hits"], maxi(0, int(ceil(float(s["limit"]) - float(s["t"]))))]}
		"thicket":
			return {"title": tx["thicket"], "line": tx["thicket_line"] % maxi(0, int(ceil(float(s["limit"]) - float(s["t"]))))}
	return {}


static func goal(_host, s: Dictionary) -> Vector2:
	return s["end"]


static func draw(host, s: Dictionary, t: float) -> void:
	var c: CanvasItem = host
	if s["state"] != "done":
		c.draw_arc(s["end"], 22.0, 0.0, TAU, 32, Color(0.7, 0.95, 0.7, 0.5 + 0.3 * sin(t * 3.0)), 2.5)
	elif s["kind"] != "burning_bridge":
		return
	if s["kind"] == "burning_bridge" and s["state"] == "run":
		var i: int = s["burnt"]
		if i < s["steps"].size():
			var r: Rect2 = s["steps"][i]
			var k: float = 1.0 - clampf(float(s["burn_t"]) / float(_cfg("burning_bridge")["step"]), 0.0, 1.0)
			c.draw_rect(r, Color(1.0, 0.45, 0.15, 0.2 + 0.45 * k))
			for j in 3:
				c.draw_circle(r.position + Vector2(fmod(j * 13.0 + t * 40.0, r.size.x), fmod(j * 17.0 + t * 25.0, r.size.y)), 3.0 + 3.0 * k, Color(1.0, 0.75, 0.3, 0.8))
	if s["kind"] == "burning_bridge":
		# Planks across the chasm: the bridge's way over, what's left of it.
		for j in range(int(s.get("burnt", 0)) if s["state"] == "run" else 0, s["steps"].size()):
			var r: Rect2 = s["steps"][j]
			var horiz := r.size.y > r.size.x  # (a step of a bridge running east-west is tall)
			for k in 4:
				var pr := Rect2(r.position + Vector2(k * r.size.x / 4.0 + 1.0, 0), Vector2(r.size.x / 4.0 - 2.0, r.size.y)) if horiz else Rect2(r.position + Vector2(0, k * r.size.y / 4.0 + 1.0), Vector2(r.size.x, r.size.y / 4.0 - 2.0))
				c.draw_rect(pr, Color(0.42, 0.29, 0.2, 0.9))
