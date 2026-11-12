extends Node2D
## The Chimera's tower, the Thornwild: grown caves, dens and grottoes
## (towers/organic.gd) joined by passages the roots have pushed through
## (they bulge and wander: after_build adds the bulges), drawn as rounded
## rock and root with no straight wall in sight (paint). Its own system is
## LIVING THORNS:
##   thorn walls   hedges of thorn across a passage. Any blow cuts them (two
##                 blows, or one finishing blow), fire burns them at once, and
##                 they grow back after a while (never onto anyone standing
##                 there). Like a cracked wall, but alive. Any weapon cuts
##                 them, so they may stand on the way to the stair.
##   closing       some thickets stand open as you pass, then grow closed
##                 behind you: cut your way back out.
##   brambles      patches of bramble on the floor slow whoever walks them,
##                 and a foe knocked into them bleeds.
##   spore pods    glowing pods: strike one, walk into it, burn it or knock a
##                 foe into it and it bursts into a cloud: green poisons
##                 whoever stands in it (you and foes alike), blue calms the
##                 foes in it for a while (they wander and don't attack until struck).
## Planned by after_build (floors.gd, floor_styles.gd "builder"), run here
## (main.gd tower_systems). The hungry grove (towers/heartroots.gd) withers
## every thorn when its heart-roots are cut; the closing thicket scenario
## (towers/tower_scenarios.gd) grows thorns through this node.

const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")
const Palette := preload("res://scripts/palette.gd")

const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0

## walls / closing: [[up to floor, how many]]; hp: blows a thorn wall takes
## (a finishing blow counts double); regrow / regrow_fire: seconds until a
## cut / burnt wall grows back; close_after: seconds after you've passed
## before a closing thicket shuts; brambles: [[up to floor, rooms]],
## patch: [least, most] tiles, slow: how much they slow (a share of speed),
## bleed: a knocked foe's bleed (per half second, seconds), knock: how hard
## it must be knocked; pods: [least, most] a floor, calm_share: how many are
## calming, cloud: radius, seconds, poison damage per half second, calm
## seconds; bulge: the chance a passage tile grows a pocket beside it.
static var RULES := {
	"walls": [[2, 1], [5, 2], [99, 3]], "closing": [[2, 0], [6, 1], [99, 2]], "hp": 2, "regrow": 24.0, "regrow_fire": 40.0, "close_after": 0.8,
	"brambles": [[3, 1], [7, 2], [99, 3]], "patch": [3, 6], "slow": 0.55, "bleed": [3.0, 3.0], "knock": 110.0,
	"pods": [2, 4], "pods_from": 2, "calm_share": 0.4, "cloud_r": 64.0, "cloud_t": 5.0, "poison": 4.0, "calm_t": 6.0,
	"bulge": 0.3,
}
static var TEXT := {
	"cut": "Cut through",
	"burnt": "The thorns burn away",
	"regrow": "The thorns grow back",
	"closes": "The thicket grows closed behind you",
	"knock": "Thorns. A blow will cut them, or fire",
	"withered": "Every thorn on the floor withers",
	"poison": "Choking spores!",
	"calm": "Soothing spores",
}

var main
var on := false
var data := {}
var thorns: Array = []  # {tiles, rect, kind, state ("grown", "cut", "open", "closing", "withered"), hp, t, fire, body, passed}
var bramble := {}  # Vector2i -> true
var pods: Array = []  # {pos, kind, burst}
var clouds: Array = []  # {pos, r, t, kind, tick}
var calmed := {}  # enemy -> seconds left
var check_t := 0.0
var redraw_t := 0.0
var withered := false
var cuts := 0  # (tests)
var burns := 0
var regrown := 0


# --- planning (floors.gd) ---------------------------------------------------------------

static func step_for(table: Array, floor_num: int) -> int:
	for row in table:
		if floor_num <= int(row[0]):
			return int(row[1])
	return int(table[-1][1])


## Lays the Thornwild's features on a planned floor: passages that bulge,
## thorn walls and closing thickets across passages, bramble patches and
## spore pods in the rooms. Writes plan["thornwild"].
static func after_build(plan: Dictionary, infos: Array, links: Array, floor_num: int, _tower: Dictionary, _style: Dictionary) -> void:
	var out := {"thorns": [], "brambles": [], "pods": []}
	var walk: Array = plan["walk"]
	var taken := {}
	for r in walk:
		for t in _tiles(r):
			taken[t] = true
	# Passages the roots pushed through: a pocket here and there beside them.
	for l in links:
		var link: Dictionary = l["link"]
		var cr: Rect2i = link["corridor"]
		var ew: bool = int(link["side_c"]) >= 2
		var own := {}
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				own[Vector2i(x, y)] = true
		var n := cr.size.x if ew else cr.size.y
		for i in range(1, n - 1):
			if randf() >= float(RULES["bulge"]):
				continue
			var side := -1 if randf() < 0.5 else 2
			var t := cr.position + (Vector2i(i, side) if ew else Vector2i(side, i))
			var ok := not taken.has(t)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := t + Vector2i(dx, dy)
					if q != t and taken.has(q) and not own.has(q):
						ok = false
			if ok:
				taken[t] = true
				walk.append(Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL)))
	# Thorn walls and closing thickets across the middle of passages.
	var cands: Array = links.map(func(l): return l["link"]).filter(func(k): return (Rect2i(k["corridor"]).size.x if int(k["side_c"]) >= 2 else Rect2i(k["corridor"]).size.y) >= 3)
	cands.shuffle()
	var walls := step_for(RULES["walls"], floor_num)
	var closing := step_for(RULES["closing"], floor_num)
	for link in cands:
		var kind := ""
		if walls > 0:
			kind = "wall"
			walls -= 1
		elif closing > 0:
			kind = "closing"
			closing -= 1
		else:
			break
		var cr: Rect2i = link["corridor"]
		var ew: bool = int(link["side_c"]) >= 2
		var n := cr.size.x if ew else cr.size.y
		var mid := n / 2
		var tiles: Array = []
		for j in 2:
			tiles.append(cr.position + (Vector2i(mid, j) if ew else Vector2i(j, mid)))
		out["thorns"].append({"tiles": tiles, "kind": kind, "corridor": link["rect"]})
		plan["doorways"].append(link["rect"])  # (traps keep off it)
	# Brambles in some rooms, clear of what matters.
	var keep: Array = plan.get("keep", []) + [plan.get("stair", Vector2.INF), plan.get("start", Vector2.INF)]
	var order: Array = range(1, infos.size())
	order.shuffle()
	var rooms_b := step_for(RULES["brambles"], floor_num)
	for i in order:
		if rooms_b <= 0:
			break
		var info: Dictionary = infos[i]
		var th: Dictionary = Themes.get_theme(String(info["theme"]))
		if th["kind"] in ["good", "calm", "scenario", "mirror"] or th["feature"] in ["trap", "puzzle", "objective", "trader", "rest"] or info["role"] == "stair":
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue
		var opens: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
		if opens.size() < 12:
			continue
		var seed_t: Vector2i = opens[randi() % opens.size()]
		var patch: Array = [seed_t]
		var want := randi_range(int(RULES["patch"][0]), int(RULES["patch"][1]))
		for tries in 30:
			if patch.size() >= want:
				break
			var from: Vector2i = patch[randi() % patch.size()]
			var nt: Vector2i = from + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][randi() % 4]
			if nt in opens and not nt in patch:
				patch.append(nt)
		var world: Array = []
		for t in patch:
			var at: Vector2 = Vector2(info["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
			if keep.any(func(k): return Vector2(k).distance_to(at) < CELL * 1.2):
				continue
			world.append(info["pos"] + t)
		if world.size() >= 2:
			out["brambles"].append({"room": i, "tiles": world})
			rooms_b -= 1
	# Spore pods.
	if floor_num >= int(RULES["pods_from"]):
		var n_pods := randi_range(int(RULES["pods"][0]), int(RULES["pods"][1]))
		order.shuffle()
		for i in order:
			if out["pods"].size() >= n_pods:
				break
			var info: Dictionary = infos[i]
			var th: Dictionary = Themes.get_theme(String(info["theme"]))
			if th["kind"] in ["scenario", "mirror"] or th["feature"] in ["puzzle", "trader"] or (info["role"] == "gallery" and info.get("puzzle", "") != ""):
				continue
			var opens: Array = Rooms.open_tiles(info["rows"], 1).filter(func(t): return not info["reserved"].has(t))
			opens.shuffle()
			for t in opens:
				var at: Vector2 = Vector2(info["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
				if keep.any(func(k): return Vector2(k).distance_to(at) < CELL * 1.5) or plan["monsters"].any(func(m): return Vector2(m[1]).distance_to(at) < CELL * 1.5):
					continue
				info["reserved"][t] = true
				out["pods"].append({"pos": at, "kind": "calm" if randf() < float(RULES["calm_share"]) else "poison", "room": i})
				break
	# A thicket lurker waits beside the brambles if it can (the better to pull you in).
	var btiles: Array = []
	for b in out["brambles"]:
		btiles.append_array(b["tiles"])
	for m in plan["monsters"]:
		if String(m[0]) != "briar":
			continue
		# (never in a puzzle's hall: a bush that won't budge would stand in the puzzle's way)
		var in_puzzle := false
		for info in infos:
			if info["role"] == "gallery" and info.get("puzzle", "") != "" and Rect2(info["rect"]).has_point(m[1]):
				in_puzzle = true
		if in_puzzle:
			m[0] = "thornhound"
			continue
		if btiles.is_empty():
			continue
		var best := Vector2.INF
		for bt in btiles:
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = bt + d
				if not taken.has(q) or q in btiles:
					continue
				var at := ORIGIN + (Vector2(q) + Vector2(0.5, 0.5)) * CELL
				if at.distance_to(m[1]) < CELL * 6.0 and (best == Vector2.INF or at.distance_to(m[1]) < best.distance_to(m[1])):
					best = at
		if best != Vector2.INF and not keep.any(func(k): return Vector2(k).distance_to(best) < CELL):
			m[1] = best
	plan["thornwild"] = out


static func _tiles(r: Rect2) -> Array:
	var out: Array = []
	var a := Vector2i(((r.position - ORIGIN) / CELL).round())
	var b := Vector2i(((r.end - ORIGIN) / CELL).round())
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			out.append(Vector2i(x, y))
	return out


# --- running (main.gd) ------------------------------------------------------------------

func _ready() -> void:
	z_index = -1  # (on the floor, under the bodies)


func setup(plan: Dictionary) -> void:
	_clear()
	if main == null:
		return
	if main.room_view != null and main.room_view.layout_painter == self:
		main.room_view.layout_painter = null
	data = plan.get("thornwild", {})
	if data.is_empty() or not main.layout_on:
		return
	on = true
	for th in data["thorns"]:
		var t := add_thorn(th["tiles"], String(th["kind"]))
		t["corridor"] = th.get("corridor", Rect2())
	for b in data["brambles"]:
		for t in b["tiles"]:
			bramble[t] = true
	for p0 in data["pods"]:
		var p: Dictionary = p0.duplicate()
		p["burst"] = false
		pods.append(p)
	main.room_view.layout_painter = self
	main.room_view.queue_redraw()
	queue_redraw()


func _clear() -> void:
	for th in thorns:
		_drop_body(th)
	thorns.clear()
	bramble.clear()
	pods.clear()
	clouds.clear()
	calmed.clear()
	withered = false
	on = false
	cuts = 0
	burns = 0
	regrown = 0
	queue_redraw()


## A thorn wall over `tiles` (grid tiles): kind "wall" (grown), "closing"
## (open until you've passed), or "scenario" (grown, never regrows: the
## closing thicket's own). Returns it.
func add_thorn(tiles: Array, kind: String) -> Dictionary:
	var r := Rect2(main.room.position + Vector2(tiles[0]) * CELL, Vector2(CELL, CELL))
	for t in tiles:
		r = r.merge(Rect2(main.room.position + Vector2(t) * CELL, Vector2(CELL, CELL)))
	var th := {"tiles": tiles.duplicate(), "rect": r, "kind": kind, "state": "open" if kind == "closing" else "cut", "hp": int(RULES["hp"]), "t": 0.0,
		"fire": false, "body": null, "passed": false, "seed": randi() % 1000}
	thorns.append(th)
	if kind != "closing":
		_grow(th, true)
	return th


func _grow(th: Dictionary, quiet := false) -> void:
	th["state"] = "grown"
	th["hp"] = int(RULES["hp"])
	th["fire"] = false
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Rect2(th["rect"]).get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Rect2(th["rect"]).size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	th["body"] = body
	_set_path(th, true)
	if not quiet:
		regrown += 1
		main.fx_burst(Rect2(th["rect"]).get_center(), Vector2.UP, Color(0.4, 0.6, 0.3), 10, 90.0)
	queue_redraw()


func _set_path(th: Dictionary, closed: bool) -> void:
	if main.astar == null:
		return
	for t in th["tiles"]:
		if main.astar.region.has_point(t) and not main._is_solid_tile(t.x, t.y):
			main.astar.set_point_solid(t, closed)


func _drop_body(th: Dictionary) -> void:
	if th.get("body") != null and is_instance_valid(th["body"]):
		th["body"].collision_layer = 0
		th["body"].queue_free()
	th["body"] = null


## Cuts (or burns) a thorn wall away; it grows back later unless it's withered.
func cut(th: Dictionary, fire := false) -> void:
	if th["state"] != "grown":
		return
	th["state"] = "cut"
	th["fire"] = fire
	th["t"] = float(RULES["regrow_fire"] if fire else RULES["regrow"])
	_drop_body(th)
	_set_path(th, false)
	var c: Vector2 = Rect2(th["rect"]).get_center()
	if fire:
		burns += 1
		main.fx_burst(c, Vector2.UP, Color(1.0, 0.55, 0.25), 18, 160.0)
		main.fx_text(c + Vector2(0, -30), TEXT["burnt"], Color(1.0, 0.65, 0.35))
		main.sfx("burn", 1.1, -4.0)
	else:
		cuts += 1
		main.fx_burst(c, Vector2.ZERO, Color(0.42, 0.6, 0.3), 14, 150.0)
		main.fx_text(c + Vector2(0, -30), TEXT["cut"], Color(0.7, 0.9, 0.55))
		main.sfx("swing_light", 0.7, -4.0)
	queue_redraw()


## The hungry grove's heart-roots are cut: every thorn on the floor withers.
func wither_all() -> void:
	withered = true
	for th in thorns:
		if th["kind"] == "scenario":
			continue
		if th["state"] == "grown":
			_drop_body(th)
			_set_path(th, false)
		th["state"] = "withered"
	queue_redraw()


func remove_thorn(th: Dictionary) -> void:
	_drop_body(th)
	_set_path(th, false)
	thorns.erase(th)
	queue_redraw()


func grown() -> Array:
	return thorns.filter(func(th): return th["state"] == "grown")


## Brambles slow whoever walks them (main.gd water_slow).
func slow(pos: Vector2) -> float:
	if bramble.is_empty():
		return 1.0
	return float(RULES["slow"]) if bramble.has(main._tile_of(pos)) else 1.0


func in_bramble(pos: Vector2) -> bool:
	return bramble.has(main._tile_of(pos))


## A melee swing (player.gd): cuts thorn walls in reach, bursts pods.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float, heavy: bool) -> void:
	for th in thorns:
		if th["state"] != "grown":
			continue
		var q := _near_point(th, from)
		var to := q - from
		if to.length() > reach + 24.0 or absf(dir.angle_to(to)) > deg_to_rad(arc_deg + 25.0):
			continue
		th["hp"] -= 2 if heavy else 1
		main.fx_burst(q, -to.normalized(), Color(0.4, 0.58, 0.3), 6, 110.0)
		if th["hp"] <= 0:
			cut(th)
		else:
			main.sfx("hit_light", 0.8, -6.0)
			main.fx_text(q + Vector2(0, -26), TEXT["knock"], Color(0.7, 0.85, 0.55))
		break
	for pd in pods:
		if pd["burst"]:
			continue
		var to: Vector2 = pd["pos"] - from
		if to.length() < reach + 16.0 and absf(dir.angle_to(to)) < deg_to_rad(arc_deg + 20.0):
			burst(pd)


## A burst of fire (main.explode): burns thorns, bursts pods, flushes lurkers.
func blast(pos: Vector2, r: float) -> void:
	for th in thorns:
		if th["state"] == "grown" and _near_point(th, pos).distance_to(pos) < r + 30.0:
			cut(th, true)
	for pd in pods:
		if not pd["burst"] and Vector2(pd["pos"]).distance_to(pos) < r + 20.0:
			burst(pd)
	for e in main.enemies():
		if e.kind == "briar" and e.global_position.distance_to(pos) < r + 50.0:
			main.Creatures.flush(e)


func _near_point(th: Dictionary, from: Vector2) -> Vector2:
	var r: Rect2 = th["rect"]
	return Vector2(clampf(from.x, r.position.x + 6.0, r.end.x - 6.0), clampf(from.y, r.position.y + 6.0, r.end.y - 6.0))


func burst(pd: Dictionary) -> void:
	if pd["burst"]:
		return
	pd["burst"] = true
	var calm: bool = pd["kind"] == "calm"
	clouds.append({"pos": pd["pos"], "r": float(RULES["cloud_r"]), "t": float(RULES["cloud_t"]), "kind": pd["kind"], "tick": 0.0})
	var col := Color(0.55, 0.65, 1.0) if calm else Color(0.6, 0.9, 0.3)
	main.fx_burst(pd["pos"], Vector2.UP, col, 18, 140.0)
	main.fx_ring(pd["pos"], col, float(RULES["cloud_r"]), 0.4, 3.0)
	main.fx_text(Vector2(pd["pos"]) + Vector2(0, -34), TEXT["calm"] if calm else TEXT["poison"], col)
	main.sfx("glass_break", 0.6, -6.0)


func _physics_process(delta: float) -> void:
	if not on or main == null or main.player == null:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	check_t -= delta
	if check_t <= 0.0:
		check_t = 0.1
		_tick_thorns(0.1, p)
		_tick_pods(p)
		_tick_brambles()
	_tick_clouds(delta, p)
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 20.0
		var view: Rect2 = main.room_view._view_rect()
		if view.has_point(pos):
			queue_redraw()


func _tick_thorns(dt: float, p) -> void:
	var pos: Vector2 = p.global_position
	for th in thorns:
		var r: Rect2 = th["rect"]
		match String(th["state"]):
			"grown":
				# Fire on the floor (a flask, burning ground, a spell) burns them.
				for f in main.flames:
					if Vector2(f["pos"]).distance_to(_near_point(th, f["pos"])) < float(f["r"]) + 8.0:
						cut(th, true)
						break
			"cut":
				if th["kind"] == "scenario":
					continue
				th["t"] -= dt
				if th["t"] <= 0.0 and not _someone_in(r):
					_grow(th)
					if pos.distance_to(r.get_center()) < 500.0:
						main.fx_text(r.get_center() + Vector2(0, -30), TEXT["regrow"], Color(0.6, 0.8, 0.45))
			"open":
				# A closing thicket: once you're through and away, it grows shut behind you.
				var cor: Rect2 = th.get("corridor", r)
				if cor.grow(4.0).has_point(pos):
					th["passed"] = true
				elif th["passed"] and pos.distance_to(r.get_center()) > CELL * 2.5:
					th["state"] = "closing"
					th["t"] = float(RULES["close_after"])
			"closing":
				th["t"] -= dt
				if th["t"] <= 0.0 and not _someone_in(r):
					_grow(th)
					th["kind"] = "wall"
					main.fx_text(r.get_center() + Vector2(0, -30), TEXT["closes"], Color(0.7, 0.9, 0.5))
					main.sfx("slam", 1.4, -8.0)


func _someone_in(r: Rect2) -> bool:
	var p = main.player
	if r.grow(p.radius + 2.0).has_point(p.global_position):
		return true
	for e in main.enemies():
		if r.grow(e.radius).has_point(e.global_position):
			return true
	return false


func _tick_pods(p) -> void:
	for pd in pods:
		if pd["burst"]:
			continue
		if Vector2(pd["pos"]).distance_to(p.global_position) < 18.0 + p.radius:
			burst(pd)
			continue
		for e in main.enemies():
			if e.knock.length() > 120.0 and Vector2(pd["pos"]).distance_to(e.global_position) < 16.0 + e.radius:
				burst(pd)
				break


## A foe knocked into the brambles bleeds.
func _tick_brambles() -> void:
	if bramble.is_empty():
		return
	for e in main.enemies():
		if e.knock.length() > float(RULES["knock"]) and in_bramble(e.global_position) and e.bleeding <= 0.0 and e.kind != "briar":
			e.bleed(float(RULES["bleed"][0]), float(RULES["bleed"][1]))
			main.fx_text(e.global_position + Vector2(0, -e.radius - 16.0), "Bleeding", Color(0.9, 0.4, 0.35))


func _tick_clouds(delta: float, p) -> void:
	for c in clouds:
		c["t"] -= delta
		c["tick"] -= delta
		var pos: Vector2 = c["pos"]
		var r: float = c["r"]
		if c["kind"] == "calm":
			for e in main.enemies():
				if not e.is_boss() and e.global_position.distance_to(pos) < r and not e.calm:
					e.calm = true
					calmed[e] = float(RULES["calm_t"])
		elif c["tick"] <= 0.0:
			c["tick"] = 0.5
			if p.global_position.distance_to(pos) < r and not p.dead:
				p.receive_attack(float(RULES["poison"]), null, true)
			for e in main.enemies():
				if e.global_position.distance_to(pos) < r:
					e.take_hit(float(RULES["poison"]), Vector2.ZERO, 0.0)
	clouds = clouds.filter(func(c): return c["t"] > 0.0)
	for e in calmed.keys():
		calmed[e] -= delta
		if not is_instance_valid(e) or e.dead:
			calmed.erase(e)
		elif calmed[e] <= 0.0:
			e.calm = false
			calmed.erase(e)


# --- the floor bot ----------------------------------------------------------------------

## The bot's path grid: thorn walls can be cut, so it may plan through them.
func bot_grid(astar: AStarGrid2D) -> void:
	for th in grown():
		for t in th["tiles"]:
			if astar.region.has_point(t):
				astar.set_point_solid(t, false)
				astar.set_point_weight_scale(t, 4.0)
	for t in bramble:
		if astar.region.has_point(t) and not astar.is_point_solid(t):
			astar.set_point_weight_scale(t, 2.0)


## The bot walking: a thorn wall in the way is struck until it's cut.
## True when it took over this tick.
func bot_go(bot, pos: Vector2, d: Vector2) -> bool:
	if d == Vector2.ZERO:
		return false
	for th in grown():
		var q := _near_point(th, pos)
		if q.distance_to(pos) < 50.0 and (q - pos).normalized().dot(d.normalized()) > 0.3:
			bot.strike_at(q)
			return true
	return false


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if not on:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for th in thorns:
		_draw_thorn(th, t)
	for pd in pods:
		if not pd["burst"]:
			_draw_pod(pd, t)
	for c in clouds:
		var calm: bool = c["kind"] == "calm"
		var col := Color(0.5, 0.6, 1.0) if calm else Color(0.55, 0.85, 0.3)
		var k := clampf(float(c["t"]) / 1.0, 0.0, 1.0)
		for i in 6:
			var a := i * TAU / 6.0 + t * 0.4
			draw_circle(Vector2(c["pos"]) + Vector2.from_angle(a) * float(c["r"]) * 0.45, float(c["r"]) * 0.5, Color(col, 0.08 * k))
		draw_arc(c["pos"], c["r"], 0.0, TAU, 32, Color(col, 0.25 * k), 2.0)


func _draw_thorn(th: Dictionary, t: float) -> void:
	var r: Rect2 = th["rect"]
	var st: String = th["state"]
	var vine := Color(0.2, 0.32, 0.16)
	var thorn := Color(0.62, 0.58, 0.42)
	var sd: int = th["seed"]
	if st in ["grown", "closing"]:
		var k := 1.0
		if st == "closing":
			k = 1.0 - clampf(float(th["t"]) / float(RULES["close_after"]), 0.0, 1.0)
		draw_rect(r.grow(-2.0), Color(0.06, 0.1, 0.05, 0.85 * k))
		# Tangled stems across the gap, thorns along them.
		for i in 13:
			var a := r.position + Vector2(_h(sd, i) * r.size.x, _h(sd, i + 9) * r.size.y)
			var b := r.position + Vector2(_h(sd, i + 20) * r.size.x, _h(sd, i + 31) * r.size.y)
			var m := (a + b) * 0.5 + (b - a).orthogonal().normalized() * 6.0 * sin(t * 0.8 + i)
			var pts := PackedVector2Array([a, m, b])
			draw_polyline(pts, Color(Palette.OUTLINE, k), 5.5)
			draw_polyline(pts, Color(vine.lightened(0.12 * (i % 3)), k), 3.5)
			for j in 3:
				var q := a.lerp(b, 0.25 + 0.25 * j)
				var n := (b - a).orthogonal().normalized() * (1.0 if j % 2 == 0 else -1.0)
				draw_colored_polygon(PackedVector2Array([q - (b - a).normalized() * 2.5, q + n * 7.5 * k, q + (b - a).normalized() * 2.5]), Color(thorn, k))
		if st == "grown" and int(th["hp"]) < int(RULES["hp"]):
			draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color(0.75, 0.9, 0.6, 0.6), 2.0)
		# A leaf or two.
		for i in 5:
			var c := r.position + Vector2(_h(sd, 50 + i) * r.size.x, _h(sd, 60 + i) * r.size.y)
			draw_circle(c, 5.0 * k, Color(0.3, 0.5, 0.22, k))
	elif st in ["cut", "open"]:
		# Stumps along the edges (cut), or a thicket held back to either side (open).
		var horiz := r.size.x < r.size.y  # (a wall across a passage running east-west is tall)
		var col := Color(0.32, 0.25, 0.16) if st == "cut" else vine
		for i in 4:
			var u := (i + 0.5) / 4.0
			var c := r.position + (Vector2(r.size.x * 0.5 + (-1.0 if i % 2 == 0 else 1.0) * 6.0, r.size.y * u) if horiz else Vector2(r.size.x * u, r.size.y * 0.5 + (-1.0 if i % 2 == 0 else 1.0) * 6.0))
			draw_circle(c, 3.5, col)
		if st == "cut" and th["kind"] != "scenario":
			var k2 := 1.0 - clampf(float(th["t"]) / float(RULES["regrow_fire"] if th["fire"] else RULES["regrow"]), 0.0, 1.0)
			if k2 > 0.6:
				# Shoots creeping back as it nears regrowing.
				for i in 3:
					var c := r.position + Vector2(_h(sd, 70 + i) * r.size.x, _h(sd, 80 + i) * r.size.y)
					draw_line(c, c + Vector2(sin(t * 2.0 + i) * 3.0, -8.0 * (k2 - 0.6) / 0.4), vine.lightened(0.2), 2.0)
	elif st == "withered":
		for i in 4:
			var c := r.position + Vector2(_h(sd, i) * r.size.x, _h(sd, i + 9) * r.size.y)
			draw_line(c, c + Vector2(6, 3), Color(0.35, 0.3, 0.22, 0.7), 2.0)


func _draw_pod(pd: Dictionary, t: float) -> void:
	var c: Vector2 = pd["pos"]
	var calm: bool = pd["kind"] == "calm"
	var col := Color(0.5, 0.62, 1.0) if calm else Color(0.6, 0.92, 0.32)
	var pulse := 0.5 + 0.5 * sin(t * 2.5 + c.x * 0.1)
	draw_circle(c + Vector2(0, 8), 10.0, Color(0, 0, 0, 0.3))
	draw_line(c + Vector2(0, 8), c + Vector2(-5, 2), Color(0.25, 0.35, 0.18), 2.5)
	draw_line(c + Vector2(0, 8), c + Vector2(5, 3), Color(0.25, 0.35, 0.18), 2.5)
	draw_circle(c, 11.0 + pulse * 2.0, Color(col, 0.15))
	draw_circle(c, 8.0, Palette.OUTLINE)
	draw_circle(c, 6.8, col.darkened(0.25))
	draw_circle(c + Vector2(-2, -2), 3.0, col.lightened(0.4))
	for i in 3:
		draw_circle(c + Vector2.from_angle(i * TAU / 3.0 + 0.5) * 5.0, 1.2, Color(1, 1, 1, 0.4 + 0.4 * pulse))


func _h(s: int, i: int) -> float:
	var h := (s * 73856093) ^ (i * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return 0.15 + 0.7 * float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


## Paints the Thornwild's rock: rounded, root-bound, never a straight wall,
## and the brambles on the floor (room.gd calls it while it draws the floor).
func paint(rv, batch) -> bool:
	if not on or rv.grid == Vector2i.ZERO:
		return false
	var grid: Vector2i = rv.grid
	var solid: PackedByteArray = rv.solid
	var room: Rect2 = rv.room
	var T := CELL
	var earth := Color(0.07, 0.08, 0.055)
	var rock := Color(0.2, 0.22, 0.15)
	var rock_hi := Color(0.28, 0.31, 0.2)
	var root := Color(0.3, 0.22, 0.14)
	var moss := Color(0.24, 0.36, 0.16)
	var far := room.grow(rv.wall + 30.0)
	batch.rect(Rect2(far.position, Vector2(far.size.x, room.position.y - far.position.y)), earth)
	batch.rect(Rect2(far.position.x, room.end.y, far.size.x, far.end.y - room.end.y), earth)
	batch.rect(Rect2(far.position.x, room.position.y, room.position.x - far.position.x, room.size.y), earth)
	batch.rect(Rect2(room.end.x, room.position.y, far.end.x - room.end.x, room.size.y), earth)
	var open := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < grid.x and y < grid.y and solid[y * grid.x + x] == 0
	var lumps: Array = []  # [pos, r] rounded rock along the edges, drawn after the fill
	for y in grid.y:
		for x in grid.x:
			if solid[y * grid.x + x] == 0 or rv.block_tiles.has(Vector2i(x, y)):
				continue
			var tile := Rect2(room.position + Vector2(x, y) * T, Vector2(T, T))
			var c := tile.get_center()
			var edge := false
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if open.call(x + d.x, y + d.y):
					edge = true
					# A rounded boulder bulging out over the floor.
					var at: Vector2 = c + Vector2(d) * T * (0.2 + 0.12 * rv._hash(x, y, 51 + d.x * 3 + d.y))
					at += Vector2(d).orthogonal() * T * (rv._hash(x, y, 55 + d.x + d.y * 5) - 0.5) * 0.4
					lumps.append([at, T * (0.42 + 0.14 * rv._hash(x, y, 57 + d.x * 7 + d.y))])
			batch.rect(tile, earth if not edge else earth.lerp(rock, 0.4))
			if not edge and rv._hash(x, y, 52) < 0.12:
				batch.circle(c + Vector2(rv._hash(x, y, 53) - 0.5, rv._hash(x, y, 54) - 0.5) * T * 0.5, 5.0, Color(root, 0.5))
	# Inner corners of the floor rounded off (a floor tile shut in on two sides).
	for y in grid.y:
		for x in grid.x:
			if not open.call(x, y):
				continue
			var tile := Rect2(room.position + Vector2(x, y) * T, Vector2(T, T))
			for cd in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if not open.call(x + cd.x, y) and not open.call(x, y + cd.y):
					var corner := tile.get_center() + Vector2(cd) * T * 0.5
					lumps.append([corner, T * 0.38])
	for l in lumps:
		batch.circle(l[0] + Vector2(2, 4), l[1], Color(0, 0, 0, 0.25))
	for l in lumps:
		batch.circle(l[0], l[1], rock)
	for l in lumps:
		var at: Vector2 = l[0]
		var r: float = l[1]
		batch.circle(at + Vector2(-r * 0.25, -r * 0.3), r * 0.55, rock_hi)
		if int(at.x * 7.0 + at.y * 3.0) % 5 == 0:
			batch.circle(at + Vector2(r * 0.2, -r * 0.45), r * 0.35, Color(moss, 0.8))
	# Roots creeping out over the floor, and thorny runners along the edges.
	for y in grid.y:
		for x in grid.x:
			if solid[y * grid.x + x] == 0 or rv._hash(x, y, 58) > 0.16:
				continue
			for d in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
				if open.call(x + d.x, y + d.y):
					var c := room.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * T
					var e: Vector2 = c + Vector2(d) * T * 1.1 + Vector2(d).orthogonal() * (rv._hash(x, y, 59) - 0.5) * T * 0.8
					var m := (c + e) * 0.5 + Vector2(d).orthogonal() * 6.0
					batch.polyline(PackedVector2Array([c, m, e]), Palette.OUTLINE, 5.0)
					batch.polyline(PackedVector2Array([c, m, e]), root, 3.0)
					break
	# Root clumps (cover): a gnarled stump with roots splayed.
	for b in rv.blocks:
		var r: Rect2 = b
		var c := r.get_center()
		batch.circle(c + Vector2(3, 6), r.size.x * 0.48, Color(0, 0, 0, 0.3))
		for i in 5:
			var a := i * TAU / 5.0 + 0.4
			batch.line(c, c + Vector2.from_angle(a) * r.size.x * 0.55, root.darkened(0.2), 5.0)
		batch.circle(c, minf(r.size.x, r.size.y) * 0.42, root)
		batch.circle(c + Vector2(-3, -4), minf(r.size.x, r.size.y) * 0.24, root.lightened(0.15))
	# Brambles: low thorny tufts.
	for t in bramble:
		var tile := Rect2(room.position + Vector2(t) * T, Vector2(T, T))
		batch.rect(tile.grow(-2.0), Color(0.12, 0.2, 0.08, 0.45))
		for i in 5:
			var c: Vector2 = tile.position + Vector2(rv._hash(t.x * 5 + i, t.y, 61), rv._hash(t.x, t.y * 5 + i, 62)) * T
			for k in 3:
				var a: float = k * TAU / 3.0 + rv._hash(t.x + i, t.y + k, 63) * 2.0
				batch.line(c, c + Vector2.from_angle(a) * 8.0, Color(0.28, 0.42, 0.18), 2.0)
			batch.circle(c, 1.5, Color(0.7, 0.62, 0.42))
	return true
