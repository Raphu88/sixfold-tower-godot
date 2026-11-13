extends RefCounted
## The Firebird's own task, REKINDLE THE BEACONS (objectives.gd "rekindle"):
## a hearth burns in a room near the start; take a flame from it (walk up)
## and carry it to each cold beacon (2 to 4, in far rooms) to light it. The
## flame gutters as you go (its time is worked out so that every beacon can
## be reached from a hearth, a brazier or a beacon already lit, with time
## to spare), and a blow costs it a share. Braziers on the way, and every
## beacon once lit, relight it. Placed by `place` (objectives.gd), run by
## the Firebird's floor script (firebird_floor.gd task_tick), with the
## floor's objective node as its host. Words and numbers: objectives.gd
## KINDS["rekindle"] and TEXT.

const Objectives := preload("res://scripts/objectives.gd")
const Palette := preload("res://scripts/palette.gd")

const FIRE := Color(1.0, 0.6, 0.28)
const WALK := 150.0  # px a second a climber walks, for the flame's time

var host  # objective.gd
var main
var spec := {}
var extras: Array = []  # {pos, room, kind ("hearth", "brazier"), light}
var carrying := false
var flame := 0.0
var burn := 20.0
var carry_light := -1
var kindles := 0  # (tests)


## The pieces: the hearth in a room near the start, beacons spread over far
## rooms, braziers between. {} if they won't fit.
static func place(spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, floor_num: int, n: int, _cell: float) -> Dictionary:
	var k: Dictionary = Objectives.KINDS["rekindle"]
	if cands.size() < 3:
		return {}
	# The hearth: the nearest room to the start that has room for it.
	var near: Array = cands.duplicate()
	near.sort_custom(func(a, b): return int(dist[a]) < int(dist[b]))
	var extra: Array = []
	for i in near:
		var hp := Objectives._spot(infos[i], monsters, 1, true)
		if hp != Vector2.INF:
			extra.append({"pos": hp, "room": i, "kind": "hearth"})
			break
	if extra.is_empty():
		return {}
	var hearth_room: int = extra[0]["room"]
	var spread := Objectives._spread(cands.filter(func(i): return i != hearth_room), n, infos, dist)
	if spread.size() < mini(n, 2):
		return {}
	for j in n:
		var ri: int = spread[j % spread.size()]
		var p := Objectives._spot(infos[ri], monsters, 1, false, spec["pieces"].map(func(x): return x["pos"]), 90.0)
		if p == Vector2.INF:
			return {}
		spec["pieces"].append({"pos": p, "room": ri})
	# Braziers in rooms on the way (not the hearth's, not a beacon's if it can be helped).
	var used: Array = [hearth_room] + spec["pieces"].map(func(x): return int(x["room"]))
	var mids: Array = cands.filter(func(i): return not (i in used))
	if mids.is_empty():
		mids = cands.filter(func(i): return i != hearth_room)
	mids.shuffle()
	for j in Objectives.step_for(k["braziers"], floor_num):
		for i in mids:
			var bp := Objectives._spot(infos[i], monsters, 1, false, extra.map(func(x): return x["pos"]) + spec["pieces"].map(func(x): return x["pos"]), 90.0)
			if bp != Vector2.INF:
				extra.append({"pos": bp, "room": i, "kind": "brazier"})
				mids.erase(i)
				break
	spec["extra"] = extra
	spec["burn"] = burn_time(extra.map(func(x): return x["pos"]), spec["pieces"].map(func(x): return x["pos"]), floor_num)
	return spec


## How long a flame lasts: the shortest the rules allow on this floor, but
## always long enough for the worst leg of the best order (from the fires
## lit so far to the next beacon: the widest gap a spanning tree must
## cross), walked the long way round.
static func burn_time(sources: Array, beacons: Array, floor_num: int) -> float:
	var k: Dictionary = Objectives.KINDS["rekindle"]
	var lit: Array = sources.duplicate()
	var left: Array = beacons.duplicate()
	var worst := 0.0
	while not left.is_empty():
		var best_d := INF
		var best_i := 0
		for i in left.size():
			for s in lit:
				var d: float = Vector2(left[i]).distance_to(s)
				if d < best_d:
					best_d = d
					best_i = i
		worst = maxf(worst, best_d)
		lit.append(left[best_i])
		left.remove_at(best_i)
	var need := worst * 1.6 / WALK * float(k["walk_share"]) + 6.0
	return maxf(maxf(float(k["burn_base"]) - float(k["burn_per_floor"]) * floor_num, float(k["burn_min"])), need)


func setup(s: Dictionary) -> void:
	spec = s
	burn = float(s.get("burn", 20.0))
	for x in s.get("extra", []):
		var e: Dictionary = x.duplicate()
		if main.lighting != null:
			e["light"] = main.lighting.add_light(e["pos"], 150.0 if e["kind"] == "hearth" else 110.0, FIRE, 0.7, 0.3)
		extras.append(e)
	for pc in host.pieces:
		pc["state"] = "todo"
	# The plan judged the legs as the crow flies; on the floor as built, the
	# worst leg is walked round the walls (bridges wind): never shorter than that.
	var lit: Array = extras.map(func(e): return e["pos"])
	var left: Array = host.pieces.map(func(pc): return pc["pos"])
	var worst := 0.0
	while not left.is_empty():
		var best_d := INF
		var best_i := 0
		for i in left.size():
			for q in lit:
				var d: float = host._path_len(q, left[i])
				if d < best_d:
					best_d = d
					best_i = i
		worst = maxf(worst, best_d)
		lit.append(left[best_i])
		left.remove_at(best_i)
	burn = maxf(burn, worst / WALK * float(_k()["walk_share"]) + 6.0)


func clear() -> void:
	if main != null and main.lighting != null:
		for e in extras:
			if e.has("light"):
				main.lighting.remove_light(e["light"])
		if carry_light >= 0:
			main.lighting.remove_light(carry_light)
	extras.clear()
	carry_light = -1
	carrying = false


func _k() -> Dictionary:
	return Objectives.KINDS["rekindle"]


## Where a flame can be taken or renewed: the hearth, the braziers, lit beacons.
func sources() -> Array:
	var out: Array = extras.map(func(e): return e["pos"])
	for pc in host.pieces:
		if pc["state"] == "done":
			out.append(pc["pos"])
	return out


func tick(delta: float, p, hurt: bool) -> bool:
	var pos: Vector2 = p.global_position
	var reach: float = 40.0 + p.radius
	for s in sources():
		if pos.distance_to(s) < reach:
			if not carrying:
				carrying = true
				kindles += 1
				main.fx_text(pos + Vector2(0, -44), Objectives.TEXT["kindled"], FIRE)
				main.sfx("burn", 1.3, -4.0)
				if main.lighting != null and carry_light < 0:
					carry_light = main.lighting.add_light(pos, 120.0, FIRE, 0.6, 0.3)
			elif flame < burn * 0.7:
				main.fx_text(pos + Vector2(0, -44), Objectives.TEXT["relit"], FIRE)
			flame = burn
			break
	if carrying:
		flame -= delta
		if hurt:
			flame -= burn * float(_k()["hit_loss"])
			main.fx_text(pos + Vector2(0, -44), Objectives.TEXT["flicker"], Color(1.0, 0.75, 0.5))
		if flame <= 0.0:
			carrying = false
			flame = 0.0
			main.fx_text(pos + Vector2(0, -44), Objectives.TEXT["guttered"], Color(0.7, 0.6, 0.55))
			main.fx_burst(pos + Vector2(0, -30), Vector2.UP, Color(0.4, 0.38, 0.4), 8, 60.0)
			main.sfx("burn", 0.5, -8.0)
			if carry_light >= 0 and main.lighting != null:
				main.lighting.remove_light(carry_light)
				carry_light = -1
		elif carry_light >= 0 and main.lighting != null:
			main.lighting.move_light(carry_light, pos + Vector2(0, -30))
		if carrying:
			for pc in host.pieces:
				if pc["state"] != "done" and pos.distance_to(pc["pos"]) < reach:
					host._piece_done(pc)
					if main.lighting != null:
						pc["light"] = main.lighting.add_light(pc["pos"], 190.0, FIRE, 0.8, 0.4)
	return host.done_count() == host.pieces.size() and not host.pieces.is_empty()


## The arrow: a beacon while the flame will last the way, else the nearest fire.
func arrow_target(from: Vector2) -> Array:
	var goal := _goal(from)
	return [goal[0], String(_k()[goal[1]])] if not goal.is_empty() else []


func _goal(from: Vector2) -> Array:
	var best := Vector2.INF
	var best_d := INF
	for pc in host.pieces:
		if pc["state"] == "done":
			continue
		var d: float = host._path_len(from, pc["pos"])
		if d < best_d:
			best_d = d
			best = pc["pos"]
	if best == Vector2.INF:
		return []
	if carrying and (flame > best_d / WALK * 1.15 + 1.0 or flame >= burn * 0.95):  # (a fresh flame: go, whatever the way)
		return [best, "piece"]
	var src := Vector2.INF
	var src_d := INF
	for s in sources():
		var d: float = host._path_len(from, s)
		if d < src_d:
			src_d = d
			src = s
	var label := "hearth"
	for e in extras:
		if Vector2(e["pos"]) == src and e["kind"] == "brazier":
			label = "brazier"
	if src == Vector2.INF:
		return [best, "piece"]
	if not extras.any(func(e): return Vector2(e["pos"]) == src):
		label = "piece"
	return [src, label]


func live_targets() -> Array:
	var out: Array = [extras[0]["pos"]] if not extras.is_empty() else []
	for pc in host.pieces:
		if pc["state"] != "done":
			out.append(pc["pos"])
	return out


func strike(_from: Vector2, _dir: Vector2, _reach: float, _arc: float) -> void:
	pass


## The floor bot: to a fire while the flame won't last, else to a beacon.
func bot_step(_bot, pos: Vector2) -> Dictionary:
	var goal := _goal(pos)
	if goal.is_empty():
		return {}
	return {"pos": goal[0], "act": "walk", "r": 14.0, "why": "a beacon" if goal[1] == "piece" and carrying else "a fire for the flame"}


# --- drawing ----------------------------------------------------------------------------

func draw(c: CanvasItem, t: float) -> void:
	for e in extras:
		_bowl(c, e["pos"], true, t, 1.25 if e["kind"] == "hearth" else 1.0)
	for pc in host.pieces:
		_beacon(c, pc["pos"], pc["state"] == "done", t)
	if carrying and main.player != null:
		var at: Vector2 = main.player.global_position + Vector2(14, -30)
		var k := clampf(flame / burn, 0.0, 1.0)
		var f := 0.7 + 0.3 * sin(t * 12.0)
		c.draw_line(at + Vector2(0, 10), at + Vector2(0, 2), Palette.WOOD, 3.0)
		c.draw_circle(at, (3.0 + 4.0 * k) * f, Color(1.0, 0.5, 0.2, 0.9))
		c.draw_circle(at + Vector2(0, -2), (1.5 + 2.5 * k) * f, Color(1.0, 0.9, 0.5))
		c.draw_arc(at, 11.0, -PI * 0.5, -PI * 0.5 + TAU * k, 20, Color(FIRE, 0.8), 2.0)


func _bowl(c: CanvasItem, at: Vector2, lit: bool, t: float, s: float) -> void:
	c.draw_circle(at + Vector2(0, 10) * s, 13.0 * s, Color(0, 0, 0, 0.3))
	c.draw_line(at + Vector2(-8, 12) * s, at, Palette.OUTLINE, 3.0)
	c.draw_line(at + Vector2(8, 12) * s, at, Palette.OUTLINE, 3.0)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-13, -4) * s, at + Vector2(13, -4) * s, at + Vector2(8, 4) * s, at + Vector2(-8, 4) * s]), Color(0.36, 0.3, 0.3))
	if lit:
		var f := 0.6 + 0.4 * sin(t * 10.0 + at.x)
		c.draw_circle(at + Vector2(0, -9) * s, (7.0 + 2.0 * f) * s, Color(1.0, 0.5, 0.18, 0.9))
		c.draw_circle(at + Vector2(0, -12) * s, (4.0 + f) * s, Color(1.0, 0.88, 0.5, 0.95))


func _beacon(c: CanvasItem, at: Vector2, lit: bool, t: float) -> void:
	# A tall stone beacon with a bowl on top.
	c.draw_circle(at + Vector2(3, 12), 12.0, Color(0, 0, 0, 0.3))
	var pts := PackedVector2Array([at + Vector2(-8, 12), at + Vector2(-5, -18), at + Vector2(5, -18), at + Vector2(8, 12)])
	c.draw_colored_polygon(pts, Color(0.4, 0.33, 0.32))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.OUTLINE, 1.5)
	c.draw_rect(Rect2(at + Vector2(-11, -24), Vector2(22, 7)), Color(0.3, 0.26, 0.26))
	if lit:
		var f := 0.6 + 0.4 * sin(t * 9.0 + at.y)
		c.draw_circle(at + Vector2(0, -30), 9.0 + 2.0 * f, Color(1.0, 0.5, 0.18, 0.9))
		c.draw_circle(at + Vector2(0, -33), 5.0 + f, Color(1.0, 0.9, 0.55))
	else:
		c.draw_arc(at + Vector2(0, -26), 16.0, 0.0, TAU, 24, Color(FIRE, 0.25 + 0.2 * sin(t * 3.0)), 2.0)
