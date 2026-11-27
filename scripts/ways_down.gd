extends Node2D
## WAYS DOWN: each tower's own hole to the floor below, beside the
## Firebird's chasms and the Gryphon's drops. Falling through one drops you
## to the floor below unhurt, exactly like a chasm (main.gd fall_through:
## never below floor 1, your unbanked essence stays with you), and a jump
## carries you over. Every one is a cut in the floor that shows the floor
## below at its bottom (holes.gd), dressed in its tower's own way, so it
## never looks like a doorway or a black pit:
##   whirlpool  (the Kraken) a round drain grate in a tide room's floor. As
##              the room's water drains (kraken_floor.gd tide), a whirlpool
##              spins up over it: foam spirals in, the eye opens onto the
##              floor below, and it drags you toward the eye if you come
##              close (walk away and you get out). Once the water is gone it
##              closes again.
##   sinkhole   (the Manticore) a patch of pale sand with a dimple and
##              cracks round it. Step on it and it sags (a red ring, sand
##              pouring in, a rumble) for RULES "sag" seconds, then opens
##              for good. Step off while it sags and you're safe.
##   chute      (the Wyvern) a sloped iron chute in the forge floor, slag
##              trickling down it into the hole at its foot: step on the
##              slope and you slide toward the drop (walk back up hard).
##   hollow     (the Chimera) a ragged gap among roots, rootlets hanging
##              into it, the floor below glimpsed between them.
## Planning (each tower's floor script calls plan_for at the end of its
## shape_plan): a way down sits inside a room, with a ring of plain floor
## round it, never on what matters (Grid.protected) and never cutting
## anything off (water_wind_grid.gd cuts, then reach.gd plan_check with its
## tiles as rock). In play this node is a child of the tower's floor node
## (made by make(), freed with it); the tower's is_void, bot_avoid,
## bot_steer and reach_live hooks ask it too, so the floor bot walks round.
## Words and numbers: WAYS, RULES, TEXT, LOOK (the Data editor).

const Holes := preload("res://scripts/holes.gd")
const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Palette := preload("res://scripts/palette.gd")
const Themes := preload("res://scripts/themes.gd")
const Enemy := preload("res://scripts/enemy.gd")
const PATH := "res://scripts/ways_down.gd"
const CELL := 40.0

## Each tower's way down: its kind, the first floor it turns up on, how
## often a floor has one, and how many [least, most].
static var WAYS := {
	"kraken": {"kind": "whirlpool", "from": 2, "chance": 0.75, "count": [1, 1]},
	"manticore": {"kind": "sinkhole", "from": 2, "chance": 0.8, "count": [1, 3]},
	"wyvern": {"kind": "chute", "from": 2, "chance": 0.75, "count": [1, 1]},
	"chimera": {"kind": "hollow", "from": 2, "chance": 0.75, "count": [1, 1]},
}
## start_gap / apart: tiles from the start, and between two ways down;
## whirlpool: pull_r (how near it drags, px), pull (px a second at the
## eye), eye_r (the eye's reach), form (seconds to spin up or die down),
## drain (how fast the water must be falling, level a second), low (below
## this level there's no water to spin); sinkhole: reach (px from its middle
## that sets it off), sag (seconds of warning); chute: slide (px a second);
## tip_reach: how near before the Entity says what it is.
static var RULES := {
	"start_gap": 5, "apart": 5,
	"pull_r": 115.0, "pull": 92.0, "eye_r": 15.0, "form": 1.6, "drain": 0.008, "low": 0.1,
	"reach": 22.0, "sag": 1.5,
	"slide": 150.0,
	"tip_reach": 280.0,
}
static var TEXT := {
	"whirlpool": "Whirlpool",
	"sinkhole": "Sinkhole",
	"chute": "Slag chute",
	"hollow": "Root hollow",
	"pull": "The whirlpool drags at you",
	"sags": "The sand sags!",
	"gives": "The sand gives way",
	"slide": "Sliding down the chute!",
	"foe": "Down it goes",
}
## The Entity's first-time tip for each (entity.gd TIPS).
const TIPS := {"whirlpool": "whirlpool", "sinkhole": "sinkhole", "chute": "slag_chute", "hollow": "root_hollow"}
## Colours of the dressing (the cut itself is holes.gd's, palette.gd HOLE_*).
static var LOOK := {
	"grate": Color(0.5, 0.42, 0.27), "foam": Color(0.86, 0.95, 1.0), "water": Color(0.16, 0.38, 0.5), "deep": Color(0.05, 0.16, 0.24),
	"sand": Color(0.84, 0.7, 0.46), "sand_dark": Color(0.5, 0.37, 0.22),
	"iron": Color(0.3, 0.28, 0.29), "slag": Color(1.0, 0.5, 0.16),
	"bark": Color(0.36, 0.26, 0.16), "bark_hi": Color(0.52, 0.39, 0.24), "moss": Color(0.34, 0.5, 0.24), "loam": Color(0.24, 0.19, 0.13),
}
## (tests: every floor of the tower gets them)
static var forced := false

var main
var tf  # the tower's floor node (the Kraken's water)
var plan := {}
var ways: Array = []  # {kind, tiles, rects, pos, state, t, s, slope, prev, body, shapes, basin, told}
var t := 0.0
var redraw_t := 0.0
var look_t := 0.0
var safe := Vector2.ZERO  # where the climber last stood off every way down
var over: Node2D  # the warnings and glows, over the darkness


# --- planning (each tower's shape_plan) -----------------------------------------------

## Lays the tower's ways down over a planned floor: plan["ways_down"] (and
## their tiles into plan["impassable"]: the traps keep off, reach.gd sees
## rock). opts: "allowed" (tile -> basin: only those tiles, the Kraken's
## tide rooms), "avoid" (tiles its own ground uses).
static func plan_for(plan: Dictionary, infos: Array, floor_num: int, tower: String, opts := {}) -> void:
	plan["ways_down"] = []
	var spec: Dictionary = WAYS.get(tower, {})
	if spec.is_empty() or floor_num < int(spec["from"]) or plan.get("summit", false) or not plan.has("room_info") or not plan.get("ok", true):
		return
	if randf() > float(spec["chance"]) and not forced:
		return
	var kind := String(spec["kind"])
	var want := randi_range(int(spec["count"][0]), int(spec["count"][1]))
	var allowed: Dictionary = opts.get("allowed", {})
	var avoid: Dictionary = opts.get("avoid", {})
	var g := Grid.grid(plan)
	var start := Grid.tile(plan["start"])
	var base := Grid.walks(g, start, plan)
	var prot := Grid.protected(plan, infos)
	for p in plan.get("pillars", []):
		prot[Grid.tile(p["pos"])] = true
	for r in plan.get("chasms", []):
		for tt in Grid.tiles_of(r):
			prot[tt] = true
	var taken := {}
	var out: Array = []
	var order: Array = range(infos.size())
	order.shuffle()
	for i in order:
		if out.size() >= want:
			break
		var info: Dictionary = infos[i]
		if not _fits(info, String(plan["themes"][i])):
			continue
		var best := Vector2i(-99999, -99999)
		var best_d := INF
		var mid: Vector2 = info["rect"].get_center()
		for tt in Grid.room_tiles(info):
			var tiles := _tiles_for(kind, tt)
			if not _clear(tiles, g, info, prot, avoid, allowed, taken):
				continue
			if Grid.centre(tt).distance_to(plan["start"]) < CELL * float(RULES["start_gap"]):
				continue
			if out.any(func(w): return Grid.centre(tt).distance_to(w["pos"]) < CELL * float(RULES["apart"])):
				continue
			var d := Grid.centre(tt).distance_to(mid) + randf() * CELL * 1.5
			if d < best_d:
				best_d = d
				best = tt
		if best.x == -99999:
			continue
		var tiles := _tiles_for(kind, best)
		var block := taken.duplicate()
		for tt in tiles:
			block[tt] = true
		if Grid.cuts(g, start, base, block):
			continue
		for tt in tiles:
			taken[tt] = true
		var w := {"kind": kind, "tiles": tiles, "room": i, "pos": Grid.centre(best) if kind != "chute" else Grid.centre(best) + Vector2(0, CELL * 0.5)}
		if allowed.has(best):
			w["basin"] = int(allowed[best])
		out.append(w)
	if out.is_empty():
		return
	var before: Array = plan.get("impassable", []).duplicate()
	plan["impassable"] = before + Grid.merge(taken.keys())
	if not load("res://scripts/reach.gd").plan_check(plan)["ok"]:
		plan["impassable"] = before  # (never known to happen: the floor keeps no way down)
		return
	# A monster that would stand on one, or at its lip, stands back from it.
	for m in plan.get("monsters", []):
		for w in out:
			var c: Vector2 = w["pos"]
			if m[1].distance_to(c) < CELL * 1.6:
				var away: Vector2 = (m[1] - c).normalized() if m[1].distance_to(c) > 1.0 else Vector2.RIGHT
				m[1] = c + away * CELL * 1.9
	plan["ways_down"] = out


## Rooms a way down may lie in: ordinary halls (not the start, the stair, a
## puzzle, a scenario, a good or calm room, a vault, a trap's set piece).
static func _fits(info: Dictionary, theme: String) -> bool:
	if not (String(info["role"]) in ["guard", "branch", "gallery"]):
		return false
	if info["role"] == "gallery" and String(info.get("puzzle", "")) != "":
		return false
	if mini(info["size"].x, info["size"].y) < 5:
		return false
	var th: Dictionary = Themes.get_theme(theme)
	if String(th["kind"]) in ["good", "calm", "scenario", "mirror", "proving"]:
		return false
	return not (String(th["feature"]) in ["vault", "rest", "trader", "spring", "camp", "mirror", "puzzle", "scenario", "trap", "rival", "chasm"])


## The tiles a way down covers, from its first: a chute is two long (the
## slope, then the drop south of it).
static func _tiles_for(kind: String, tt: Vector2i) -> Array:
	return [tt, tt + Vector2i.DOWN] if kind == "chute" else [tt]


## Every tile, and the ring of plain floor round them, free.
static func _clear(tiles: Array, g: Dictionary, info: Dictionary, prot: Dictionary, avoid: Dictionary, allowed: Dictionary, taken: Dictionary) -> bool:
	var rows: Array = info["rows"]
	var at: Vector2i = info["pos"]
	var seen := {}
	for tt in tiles:
		if prot.has(tt) or avoid.has(tt) or taken.has(tt):
			return false
		if not allowed.is_empty() and not allowed.has(tt):
			return false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = tt + Vector2i(dx, dy)
				if seen.has(n):
					continue
				seen[n] = true
				var l: Vector2i = n - at
				if l.y < 0 or l.x < 0 or l.y >= rows.size() or l.x >= String(rows[l.y]).length() or String(rows[l.y])[l.x] != ".":
					return false
				if not Grid.is_open(g, n) or avoid.has(n) or taken.has(n):
					return false
				if not allowed.is_empty() and not allowed.has(n):
					return false
	return true


# --- in play ----------------------------------------------------------------------------

## The node for a floor: a child of the tower's floor node `owner_node`.
static func make(main_, owner_node, p: Dictionary):
	var n = load(PATH).new()
	n.main = main_
	n.tf = owner_node
	owner_node.add_child(n)
	n.setup(p)
	return n


func _ready() -> void:
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 44  # (over the darkness: the warnings read in the dark, like the foes' telegraphs)
	over.draw.connect(_draw_over)
	add_child(over)


func setup(p: Dictionary) -> void:
	plan = p
	ways.clear()
	var spot_lost: Vector2 = main.lost_cache.get("pos", Vector2.INF) if main.lost_cache is Dictionary else Vector2.INF
	var spot_contract: Vector2 = main.contracts.planned if main.contracts != null and "planned" in main.contracts else Vector2.INF
	for w0 in p.get("ways_down", []):
		var w: Dictionary = w0.duplicate(true)
		# (a lost cache or a contract's thing laid after the plan: never on a hole)
		if (spot_lost != Vector2.INF and spot_lost.distance_to(w["pos"]) < 90.0) or (spot_contract != Vector2.INF and spot_contract.distance_to(w["pos"]) < 90.0):
			continue
		w["rects"] = w["tiles"].map(func(tt): return Rect2(Grid.centre(tt) - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)))
		w["state"] = {"whirlpool": "calm", "sinkhole": "sand"}.get(w["kind"], "open")
		w["t"] = 0.0
		w["s"] = 0.0
		w["slope"] = 0.0
		w["prev"] = -1.0
		w["told"] = false
		_make_body(w)
		ways.append(w)
	_set_paths(true)
	safe = main.player.global_position if main.player != null else Vector2.ZERO
	queue_redraw()


## A body walking monsters can't step into (layer 16, as main.gd's chasms),
## on while the way down is open.
func _make_body(w: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var shapes: Array = []
	for r in w["rects"]:
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size - Vector2(6, 6)
		cs.shape = box
		cs.position = r.get_center()
		cs.disabled = not _open(w)
		body.add_child(cs)
		shapes.append(cs)
	add_child(body)
	w["body"] = body
	w["shapes"] = shapes


func _set_body(w: Dictionary, on: bool) -> void:
	for cs in w["shapes"]:
		cs.set_deferred("disabled", not on)


## Monsters path round every way down, open or not.
func _set_paths(on: bool) -> void:
	if main.astar == null:
		return
	for w in ways:
		for tt in w["tiles"]:
			var lt: Vector2i = main._tile_of(Grid.centre(tt))
			if main.astar.region.has_point(lt) and not main._is_solid_tile(lt.x, lt.y):
				main.astar.set_point_solid(lt, on)


func _open(w: Dictionary) -> bool:
	match String(w["kind"]):
		"whirlpool":
			return float(w["s"]) > 0.55
		"sinkhole":
			return w["state"] == "open"
	return true


func _live() -> bool:
	return main != null and main.player != null and is_same(main.floor_plan, plan)


func _process(delta: float) -> void:
	if not _live() or ways.is_empty():
		return
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		var view: Rect2 = main.room_view._view_rect().grow(140.0) if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
		if ways.any(func(w): return view.has_point(w["pos"])):
			queue_redraw()
			over.queue_redraw()


func _physics_process(delta: float) -> void:
	if not _live():
		return
	t += delta
	var p = main.player
	for w in ways:
		match String(w["kind"]):
			"whirlpool":
				_tick_whirlpool(w, delta, p)
			"sinkhole":
				_tick_sinkhole(w, delta, p)
			"chute":
				_tick_chute(w, p)
	# Through one: down a floor, as a chasm (never in the air: a jump clears
	# it). Walked onto its edge, you teeter first (player.gd begin_teeter);
	# dragged, slid or shoved in, you go straight down.
	if not main.climbing and not p.dead and not p.in_air() and p.teeter_t <= 0.0:
		var on := {}
		for w in ways:
			if _swallows(w, p.global_position):
				on = w
				break
		if on.is_empty():
			safe = p.global_position
		elif p.walked_onto(safe) and not ways.any(func(w): return _swallows(w, safe)):
			p.begin_teeter(p.global_position - safe, safe)
		else:
			p.knock = Vector2.ZERO
			p.velocity = Vector2.ZERO
			main.fall_through()
	look_t -= delta
	if look_t <= 0.0:
		look_t = 0.3
		_look(p)


## The Entity says what each kind is, the first time one is in sight; what
## lies on an open one rolls to its lip.
func _look(p) -> void:
	for w in ways:
		var c: Vector2 = w["pos"]
		if p.global_position.distance_to(c) < float(RULES["tip_reach"]) and _seen(c):
			main.tip(TIPS[w["kind"]])
	for list in [main.item_drops, main.gear_drops, main.graft_drops]:
		for d in list:
			for w in ways:
				if _open(w) and _on(w, d["pos"], 2.0):
					var to := _beside(w, d["pos"])
					if to != Vector2.INF:
						d["pos"] = to


func _seen(pos: Vector2) -> bool:
	return main.fog == null or not main.layout_on or main.fog.sees(pos)


func _on(w: Dictionary, pos: Vector2, inset: float) -> bool:
	for r in w["rects"]:
		if r.grow(-inset).has_point(pos):
			return true
	return false


## Whether standing at `pos` takes you down it.
func _swallows(w: Dictionary, pos: Vector2) -> bool:
	match String(w["kind"]):
		"whirlpool":
			return float(w["s"]) > 0.55 and pos.distance_to(w["pos"]) < float(RULES["eye_r"]) * 0.9
		"sinkhole":
			return w["state"] == "open" and _on(w, pos, 5.0)
		"chute":
			return w["rects"][1].grow(-5.0).has_point(pos)
		"hollow":
			return _on(w, pos, 7.0)
	return false


## The nearest floor beside a way down (where what fell on it rolls).
func _beside(w: Dictionary, at: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for tt in w["tiles"]:
		for d in Grid.N8:
			var n: Vector2i = tt + d
			if n in w["tiles"]:
				continue
			var c := Grid.centre(n)
			if main.is_solid(c):
				continue
			var dd := c.distance_squared_to(at)
			if dd < best_d:
				best_d = dd
				best = c
	return best


# --- each kind ----------------------------------------------------------------------------

## The Kraken's: spins up while the room's water drains, and drags at you.
func _tick_whirlpool(w: Dictionary, delta: float, p) -> void:
	var level := _level(w)
	if float(w["prev"]) < 0.0:
		w["prev"] = level
	var slope := (level - float(w["prev"])) / maxf(delta, 0.001)
	w["prev"] = level
	w["slope"] = lerpf(float(w["slope"]), slope, 1.0 - exp(-4.0 * delta))
	var want := 1.0 if (float(w["slope"]) < -float(RULES["drain"]) and level > float(RULES["low"])) else 0.0
	if w.has("force"):
		want = float(w["force"])  # (tests)
	var was_open := _open(w)
	var s0 := float(w["s"])
	w["s"] = move_toward(s0, want, delta / float(RULES["form"]))
	if s0 <= 0.0 and float(w["s"]) > 0.0:
		w["told"] = false
		if _seen(w["pos"]):
			main.sfx("wave", 0.55, -9.0, 0.05)
	if _open(w) != was_open:
		_set_body(w, _open(w))
	var s := float(w["s"])
	if s <= 0.2 or p.dead or p.in_air():
		return
	var d: Vector2 = p.global_position - Vector2(w["pos"])
	var dist := d.length()
	var r := float(RULES["pull_r"])
	if dist >= r or dist < 0.5:
		return
	var force := float(RULES["pull"]) * s * pow(1.0 - dist / r, 0.6)
	var dir := -d / dist
	var along: float = p.knock.dot(dir)
	if along < force:
		p.knock += dir * minf(force - along, (900.0 + force * 3.0) * delta + 6.0)
	if not w["told"] and s > 0.5:
		w["told"] = true
		main.fx_text(p.global_position + Vector2(0, -44), TEXT["pull"], LOOK["foam"])
		main.tip("whirlpool")


## The water's level over the eye (the tower's basin), 0 when there's none.
func _level(w: Dictionary) -> float:
	var bi := int(w.get("basin", -1))
	if tf == null or not ("basins" in tf) or bi < 0 or bi >= tf.basins.size():
		return 0.0
	return float(tf.basins[bi]["level"])


## The Manticore's: sags under you, then opens for good.
func _tick_sinkhole(w: Dictionary, delta: float, p) -> void:
	match String(w["state"]):
		"sand":
			if not p.dead and not p.in_air() and p.global_position.distance_to(w["pos"]) < float(RULES["reach"]) + p.radius * 0.5:
				w["state"] = "sag"
				w["t"] = 0.0
				main.fx_text(Vector2(w["pos"]) + Vector2(0, -34), TEXT["sags"], Palette.DANGER.lightened(0.3))
				main.sfx("stone_slide", 0.55, -2.0, 0.05)
				main.shake(2.0)
				main.tip("sinkhole")
		"sag":
			w["t"] = float(w["t"]) + delta
			if fmod(float(w["t"]), 0.3) < delta:
				main.fx_burst(w["pos"], Vector2.UP, LOOK["sand"], 5, 70.0)
			if float(w["t"]) >= float(RULES["sag"]):
				_give_way(w)


func _give_way(w: Dictionary) -> void:
	w["state"] = "open"
	_set_body(w, true)
	main.fx_text(Vector2(w["pos"]) + Vector2(0, -40), TEXT["gives"], LOOK["sand"])
	main.fx_burst(w["pos"], Vector2.UP, LOOK["sand"], 16, 140.0)
	main.sfx_at(w["pos"], "stone_thud", 0.7, -5.0, 0.05)
	main.shake(4.0)
	# A walking foe standing on it goes down with the sand.
	for e in main.enemies():
		if e.dead or e.is_boss() or e.kind in Enemy.FLIERS:
			continue
		if _on(w, e.global_position, -e.radius * 0.4):
			_drop_foe(w, e)


## A foe falls through: it's gone (what it carried lands at the lip).
func _drop_foe(w: Dictionary, e) -> void:
	var at: Vector2 = e.global_position
	main.fx_text(at + Vector2(0, -e.radius - 30.0), TEXT["foe"], LOOK["sand"])
	main.sfx("roll", 0.5, -4.0, 0.0)
	var to := _beside(w, at)
	if to != Vector2.INF:
		e.global_position = to
	e.dead = true
	main.release_attack(e)
	main.on_enemy_killed(e)
	e.queue_free()


## The Wyvern's: its slope slides you toward the drop.
func _tick_chute(w: Dictionary, p) -> void:
	if p.dead or p.in_air() or not w["rects"][0].grow(-2.0).has_point(p.global_position):
		w["told"] = false
		return
	var force := float(RULES["slide"])
	var along: float = p.knock.dot(Vector2.DOWN)
	if along < force:
		p.knock += Vector2.DOWN * (force - along)
	if not w["told"]:
		w["told"] = true
		main.fx_text(p.global_position + Vector2(0, -44), TEXT["slide"], LOOK["slag"])


# --- what the tower's floor asks (its hooks pass these on) -------------------------------

## A way down here (the floor bot never steps on one, open or not).
func is_void(pos: Vector2) -> bool:
	var tt := Grid.tile(pos)
	for w in ways:
		if tt in w["tiles"]:
			return true
	return false


func bot_avoid() -> Array:
	var out: Array = []
	for w in ways:
		for tt in w["tiles"]:
			out.append(main._tile_of(Grid.centre(tt)))
	return out


## The floor bot leans out of a whirlpool's pull.
func bot_steer(pos: Vector2, d: Vector2) -> Vector2:
	for w in ways:
		if w["kind"] != "whirlpool" or float(w["s"]) <= 0.2:
			continue
		var off: Vector2 = pos - Vector2(w["pos"])
		if off.length() < float(RULES["pull_r"]) and off.length() > 0.5:
			var lean := off.normalized() * minf(0.9, float(RULES["pull"]) * float(w["s"]) / 165.0 + 0.15)
			return (lean + (d.normalized() if d.length() > 0.01 else Vector2.ZERO) * 0.6).limit_length(1.0)
	return d


## reach.gd's safety net: a way down is rock.
func reach_live(solid: PackedByteArray, size: Vector2i) -> void:
	for w in ways:
		for tt in w["tiles"]:
			var lt: Vector2i = main._tile_of(Grid.centre(tt))
			if lt.x >= 0 and lt.y >= 0 and lt.x < size.x and lt.y < size.y:
				solid[lt.y * size.x + lt.x] = 1


# --- drawing --------------------------------------------------------------------------------

func _tint() -> Color:
	return main.room_view.self_modulate if main.room_view != null else Color.WHITE


func _origin() -> Vector2:
	return main.room_view.room.position if main.room_view != null else Grid.ORIGIN


func _draw() -> void:
	if main == null:
		return
	var view: Rect2 = main.room_view._view_rect().grow(140.0) if main.room_view != null else Rect2(-1e6, -1e6, 2e6, 2e6)
	for w in ways:
		if not view.has_point(w["pos"]):
			continue
		match String(w["kind"]):
			"whirlpool":
				_draw_whirlpool(w)
			"sinkhole":
				_draw_sinkhole(w)
			"chute":
				_draw_chute(w)
			"hollow":
				_draw_hollow(w)


static func _h(tt: Vector2i, salt: int) -> float:
	return Holes.hash01(tt.x, tt.y, salt)


## The floor below, seen through a round eye of radius `r` at the origin of
## the current transform: smaller flagstones, dimmer, the tower's haze.
func _disc_below(r: float, tower: String, tint: Color) -> void:
	if r < 1.0:
		return
	draw_circle(Vector2.ZERO, r, Palette.HOLE_GAP * tint)
	var st := 13.0
	var y := -r
	var row := 0
	while y < r:
		var ym := clampf(y + st * 0.5, -r, r)
		var hw := sqrt(maxf(0.0, r * r - ym * ym)) - 1.0
		if hw > 1.0:
			var col: Color = Palette.HOLE_FLOOR.lerp(Palette.HOLE_FLOOR_LIGHT, 0.5 + 0.5 * sin(row * 1.7)) * tint
			draw_rect(Rect2(-hw, y + 0.5, hw * 2.0, minf(st - 1.0, r - y)), col)
			var x := -hw + fmod(row * 6.0, st)
			while x < hw:
				draw_line(Vector2(x, y + 0.5), Vector2(x, minf(y + st - 0.5, r)), Palette.HOLE_GAP * tint, 1.0)
				x += st
		y += st
		row += 1
	var hz := Holes.haze(tower)
	draw_circle(Vector2.ZERO, r, hz)


func _draw_whirlpool(w: Dictionary) -> void:
	var c: Vector2 = w["pos"]
	var s := float(w["s"])
	var tint := _tint()
	var er := float(RULES["eye_r"])
	draw_set_transform(c, 0.0, Vector2(1.0, 0.82))
	# The drain: a round bronze grate set in the floor (under the water).
	var grate: Color = LOOK["grate"]
	draw_circle(Vector2.ZERO, er + 3.0, Color(0.05, 0.06, 0.07, 0.75))
	draw_arc(Vector2.ZERO, er + 2.0, 0.0, TAU, 28, grate, 2.5)
	draw_arc(Vector2.ZERO, er + 3.5, PI * 1.1, PI * 1.7, 10, grate.lightened(0.35), 1.2)
	for k in 5:
		var yy := -er + 4.0 + k * (er * 2.0 - 8.0) / 4.0
		var hw := sqrt(maxf(0.0, er * er - yy * yy)) - 2.0
		draw_line(Vector2(-hw, yy), Vector2(hw, yy), Color(grate.darkened(0.25), 0.9), 2.0)
	if s > 0.01:
		var R := float(RULES["pull_r"]) * 0.72 * (0.45 + 0.55 * s)
		var water: Color = LOOK["water"]
		var deep: Color = LOOK["deep"]
		# The funnel: rings of water darkening toward the eye.
		for k in 7:
			var f := float(k) / 6.0
			draw_circle(Vector2.ZERO, lerpf(R, er + 2.0, f), Color(water.lerp(deep, f), (0.12 + 0.12 * f) * s))
		# The eye opens onto the floor below.
		var eo := er * clampf((s - 0.25) / 0.45, 0.0, 1.0)
		_disc_below(eo, "kraken", tint)
		if eo > 2.0:
			# Water pouring over the eye's lip, and a foam rim round it.
			for k in 10:
				var a := float(k) / 10.0 * TAU - t * 3.0
				var u := Vector2.from_angle(a)
				draw_line(u * (eo + 3.5), u * maxf(eo - 4.0, 1.0), Color(deep, 0.85), 2.0)
			draw_arc(Vector2.ZERO, eo + 1.5, 0.0, TAU, 28, Color(LOOK["foam"], 0.75 * s), 2.0)
		# Spiral arms of foam, turning in.
		var rot := -t * (1.8 + 2.4 * s)
		var foam: Color = LOOK["foam"]
		for arm in 4:
			var pts := PackedVector2Array()
			for i in 15:
				var u := float(i) / 14.0
				var rr := lerpf(R, er + 3.0, u)
				pts.append(Vector2.from_angle(arm * TAU / 4.0 + rot + u * 3.6) * rr)
			draw_polyline(pts, Color(foam, 0.5 * s), 1.6 + s)
		for i in 9:
			var u := fmod(t * 0.35 + i * 0.111, 1.0)
			var rr := lerpf(R, er + 2.0, u)
			draw_circle(Vector2.from_angle(i * 2.1 + rot * (1.0 + u)) * rr, 1.4, Color(foam, 0.7 * s * (1.0 - u * 0.5)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sinkhole(w: Dictionary) -> void:
	var c: Vector2 = w["pos"]
	var tt: Vector2i = w["tiles"][0]
	var tint := _tint()
	var sand: Color = LOOK["sand"]
	var dark: Color = LOOK["sand_dark"]
	var k := clampf(float(w["t"]) / float(RULES["sag"]), 0.0, 1.0) if w["state"] == "sag" else (1.0 if w["state"] == "open" else 0.0)
	var jit := Vector2(sin(t * 47.0), cos(t * 39.0)) * 1.3 * k if w["state"] == "sag" else Vector2.ZERO
	# Cracks running out into the flagstones round it (the tell).
	for i in 6:
		var a := i * TAU / 6.0 + _h(tt, 90 + i) * 0.8
		var u := Vector2.from_angle(a)
		var from := c + u * 22.0
		var len := (7.0 + 6.0 * _h(tt, 96 + i)) * (1.0 + k * 0.8)
		var bend := u.orthogonal() * (_h(tt, 102 + i) - 0.5) * 6.0
		draw_line(from, from + u * len * 0.5 + bend, Color(Palette.FLOOR_GAP * tint, 0.9), 1.3)
		draw_line(from + u * len * 0.5 + bend, from + u * len + bend * 0.4, Color(Palette.FLOOR_GAP * tint, 0.8), 1.0)
	# The patch of sand: a ragged round, paler than the flagstones.
	var blob := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		blob.append(c + jit + Vector2.from_angle(a) * (23.0 + 4.0 * _h(tt, 110 + i) + (6.0 if w["state"] == "open" else 0.0)) * Vector2(1.0, 0.9))
	draw_colored_polygon(blob, sand.darkened(0.08))
	draw_polyline(blob + PackedVector2Array([blob[0]]), Color(dark, 0.5), 1.2)
	if w["state"] == "open":
		var r: Rect2 = w["rects"][0]
		Holes.draw_floor_below(self, r, _origin(), "manticore", tint)
		_shaft(r, tint)  # (the ring drawn over it rounds it off)
		# A faint heap of fallen sand far below, and sand trickling down the far wall.
		draw_set_transform(Vector2(c.x + 3.0, r.end.y - 9.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 7.0, Color(sand.darkened(0.6), 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var x := c.x - 8.0 + i * 8.0 + _h(tt, 120 + i) * 3.0
			var ph := fmod(t * 1.3 + i * 0.37, 1.0)
			draw_line(Vector2(x, r.position.y + 4.0), Vector2(x, r.position.y + 15.0 + ph * 7.0), Color(sand.darkened(0.2), 0.5 * (1.0 - ph * 0.5)), 1.3)
		# The sand round it: a ragged ring that rounds the opening off.
		_ring(c, 16.5, blob, sand.darkened(0.08), Color(dark, 0.95), sand.lightened(0.18))
		return
	# A dimple in it that deepens as it sags into a funnel of sand.
	for i in 5:
		var f := float(i) / 4.0
		var rr := lerpf(18.0, 3.0, f) * (1.0 + 0.2 * k)
		draw_circle(c + jit + Vector2(0, 1.5 * f), rr, Color(sand.lerp(dark.darkened(0.5 * k), 0.2 + 0.7 * f * (0.4 + 0.6 * k)), 0.3 + 0.6 * k))
	# Grains sliding in: now and then at rest, a stream while it sags.
	var n := 3 if w["state"] == "sand" else 12
	var spd := 0.25 if w["state"] == "sand" else 1.4
	for i in n:
		var u := fmod(t * spd + i * (1.0 / n), 1.0)
		var a := i * 2.4 + u * (0.6 + 2.0 * k)
		draw_circle(c + jit + Vector2.from_angle(a) * lerpf(22.0, 3.0, u) * Vector2(1.0, 0.9), 1.1 + 0.5 * k, Color(sand.lightened(0.25), 0.7 * (1.0 - u * 0.6)))


func _draw_chute(w: Dictionary) -> void:
	var tint := _tint()
	var rt: Rect2 = w["rects"][0]
	var rb: Rect2 = w["rects"][1]
	var tb: Vector2i = w["tiles"][1]
	# The drop at its foot: the cut, the floor below at the bottom.
	Holes.draw_floor_below(self, rb, _origin(), "wyvern", tint)
	Holes.draw_cut(self, rb, Holes.HOLE, Holes.FLOOR, Holes.FLOOR, Holes.FLOOR, tb, tint)
	var slag: Color = LOOK["slag"]
	# A glow of spilt slag on the floor below, drips falling into it.
	draw_set_transform(Vector2(rb.get_center().x, rb.end.y - 9.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(slag.darkened(0.45), 0.5))
	draw_circle(Vector2.ZERO, 2.6, Color(slag, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 2:
		var ph := fmod(t * 1.1 + i * 0.5, 1.0)
		draw_circle(Vector2(rb.get_center().x - 5.0 + i * 10.0, rb.position.y + 2.0 + ph * (rb.size.y - 12.0)), 1.6, Color(slag, 1.0 - ph * 0.7))
	# The slope: an iron trough going down into the drop, darker as it goes.
	var iron: Color = LOOK["iron"] * tint
	var inner := Rect2(rt.position.x + 6.0, rt.position.y, rt.size.x - 12.0, rt.size.y)
	var steps := 8
	for k in steps:
		var f := float(k) / float(steps - 1)
		draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * k / steps, inner.size.x, inner.size.y / steps + 0.5), iron.lerp(Palette.HOLE_SHAFT_DEEP * tint, f * 0.85))
	# Plates across it, and chevrons pointing down the slope.
	for k in 3:
		var y := inner.position.y + 9.0 + k * 11.0
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(0, 0, 0, 0.35), 1.0)
	for k in 2:
		var cy := inner.position.y + 12.0 + k * 13.0
		var cx := inner.get_center().x
		draw_polyline(PackedVector2Array([Vector2(cx - 6.0, cy - 3.0), Vector2(cx, cy + 2.0), Vector2(cx + 6.0, cy - 3.0)]), Color(0, 0, 0, 0.5), 1.6)
	# Slag trickling down two runnels.
	for lane in [-6.0, 6.0]:
		var x: float = inner.get_center().x + lane
		for k in 3:
			var y0 := fmod(t * 34.0 + k * 13.3 + lane, rt.size.y + rb.size.y * 0.4)
			var a := Vector2(x, rt.position.y + y0)
			draw_line(a, a + Vector2(0, 5.0), Color(slag, 0.85), 2.0)
	# The rails along both sides (riveted), and the lit lip at its head.
	for side in [rt.position.x, rt.end.x - 6.0]:
		var rail := Rect2(side, rt.position.y - 2.0, 6.0, rt.size.y + rb.size.y * 0.35)
		draw_rect(rail, iron.darkened(0.25))
		draw_rect(Rect2(rail.position, Vector2(rail.size.x, 1.5)), iron.lightened(0.3))
		draw_rect(Rect2(rail.position.x + (5.0 if side > rt.position.x else 0.0), rail.position.y, 1.0, rail.size.y), Color(0, 0, 0, 0.45))
		for k in 3:
			draw_circle(Vector2(rail.get_center().x, rail.position.y + 6.0 + k * 13.0), 1.2, iron.lightened(0.45))
	draw_rect(Rect2(rt.position.x, rt.position.y - 4.0, rt.size.x, 3.0), Palette.HOLE_RIM * tint)
	draw_rect(Rect2(rt.position.x, rt.position.y - 5.5, rt.size.x, 1.5), Color(Palette.FLOOR_GAP * tint, 0.9))


func _draw_hollow(w: Dictionary) -> void:
	var tint := _tint()
	var r: Rect2 = w["rects"][0]
	var tt: Vector2i = w["tiles"][0]
	var c: Vector2 = w["pos"]
	Holes.draw_floor_below(self, r, _origin(), "chimera", tint)
	_shaft(r, tint)  # (the ring drawn over it rounds it off)
	var loam: Color = LOOK["loam"] * tint
	var moss: Color = LOOK["moss"]
	# Earth and moss heaped round it: a ragged gap, never a square doorway.
	var blob := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		blob.append(c + Vector2.from_angle(a) * (24.0 + 5.0 * _h(tt, 130 + i)) * Vector2(1.0, 0.92))
	_ring(c, 15.5, blob, loam, Color(0, 0, 0, 0.85), loam.lightened(0.2))
	for i in 9:
		var a := i * TAU / 9.0 + _h(tt, 140 + i)
		var at := c + Vector2.from_angle(a) * (19.0 + 4.0 * _h(tt, 146 + i)) * Vector2(1.0, 0.92)
		draw_circle(at, 2.2 + 1.4 * _h(tt, 152 + i), Color(moss.darkened(0.15 * (i % 2)), 0.9))
	# Roots arching over the gap and dipping into it, rootlets hanging down.
	var sway := sin(t * 1.1 + tt.x) * 1.0
	_root(c + Vector2(-30, -12), c + Vector2(-12, -22), c + Vector2(-3, 4), 5.0, tint)
	_root(c + Vector2(31, -6), c + Vector2(14, -16), c + Vector2(7, 9), 4.0, tint)
	_root(c + Vector2(-28, 15), c + Vector2(0, 26), c + Vector2(29, 12), 4.5, tint)
	var bark: Color = LOOK["bark"]
	for i in 5:
		var base := c + Vector2(-11.0 + i * 5.5, -6.0 + 7.0 * _h(tt, 156 + i))
		var len := 6.0 + 8.0 * _h(tt, 160 + i)
		var tip := base + Vector2(sway * (0.5 + 0.2 * i), len)
		draw_line(base, (base + tip) * 0.5 + Vector2(1.2, 0), Color(bark.lightened(0.15) * tint, 0.85), 1.3)
		draw_line((base + tip) * 0.5 + Vector2(1.2, 0), tip, Color(bark.lightened(0.15) * tint, 0.55), 0.9)


## A round hole's shaft, before its ring crops it: the far wall falling away
## to near-black (holes.gd's colours), deep shade all round the bottom.
func _shaft(r: Rect2, tint: Color) -> void:
	var sh: float = Holes.LOOK["shaft"]
	var top: Color = Palette.HOLE_SHAFT * tint
	var deep: Color = Palette.HOLE_SHAFT_DEEP * tint
	for k in 6:
		var f := pow(float(k) / 5.0, 0.6)
		draw_rect(Rect2(r.position.x, r.position.y + sh * k / 6.0, r.size.x, sh / 6.0 + 0.5), top.lerp(deep, f))
	for k in 6:
		var a := 0.5 * (1.0 - float(k) / 6.0)
		var d := 3.0 * k
		draw_rect(Rect2(r.position.x, r.position.y + sh + d, r.size.x, 3.0), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position.x + d, r.position.y, 3.0, r.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(r.end.x - d - 3.0, r.position.y, 3.0, r.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position.x, r.end.y - d - 3.0, r.size.x, 3.0), Color(0, 0, 0, a * 0.7))


## A ring round a hole that rounds its opening off (sand, loam): from the
## ragged `outer` edge in to a round opening of radius `r`, with a hard dark
## lip at the opening and a lighter edge just outside it.
func _ring(c: Vector2, r: float, outer: PackedVector2Array, col: Color, lip: Color, edge: Color) -> void:
	var n := outer.size()
	var inner := PackedVector2Array()
	for i in n:
		inner.append(c + (outer[i] - c).normalized() * r * Vector2(1.0, 0.92))
	for i in n:
		var j := (i + 1) % n
		draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), col)
	var loop := inner + PackedVector2Array([inner[0]])
	draw_polyline(loop, edge, 2.0)
	var lip_loop := PackedVector2Array()
	for p in loop:
		lip_loop.append(c + (p - c) * 0.93)
	draw_polyline(lip_loop, lip, 1.6)
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(col.darkened(0.35), 0.6), 1.0)


## A root: a smooth tapering curve from `a` past `m` to `b`, outlined.
func _root(a: Vector2, m: Vector2, b: Vector2, w0: float, tint: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		pts.append(a.lerp(m, u).lerp(m.lerp(b, u), u))
	var bark: Color = LOOK["bark"] * tint
	var hi: Color = LOOK["bark_hi"] * tint
	for pass_ in 3:
		for i in pts.size() - 1:
			var wd := lerpf(w0, w0 * 0.35, float(i) / 7.0)
			match pass_:
				0:
					draw_line(pts[i], pts[i + 1], Palette.OUTLINE, wd + 2.0)
				1:
					draw_line(pts[i], pts[i + 1], bark, wd)
				_:
					draw_line(pts[i] + Vector2(0, -wd * 0.25), pts[i + 1] + Vector2(0, -wd * 0.25), Color(hi, 0.8), maxf(0.8, wd * 0.3))
	draw_circle(pts[0], w0 * 0.5 + 1.0, Palette.OUTLINE)
	draw_circle(pts[0], w0 * 0.5, bark)


## Over the darkness, while in sight: the sag's warning ring, the whirlpool's
## reach, the slag's glow, the hollow's motes.
func _draw_over() -> void:
	if main == null:
		return
	for w in ways:
		var c: Vector2 = w["pos"]
		if not _seen(c):
			continue
		match String(w["kind"]):
			"sinkhole":
				if w["state"] == "sag":
					var k := clampf(float(w["t"]) / float(RULES["sag"]), 0.0, 1.0)
					var pulse := 0.6 + 0.4 * sin(t * 14.0)
					over.draw_set_transform(c, 0.0, Vector2(1.0, 0.9))
					over.draw_circle(Vector2.ZERO, 27.0, Color(Palette.DANGER, (0.08 + 0.14 * k) * pulse))
					over.draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 32, Color(Palette.DANGER, 0.75 * pulse), 2.5)
					over.draw_arc(Vector2.ZERO, 27.0 * (1.0 - k) + 4.0, 0.0, TAU, 28, Color(Palette.DANGER, 0.6), 1.5)
					over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"whirlpool":
				var s := float(w["s"])
				if s > 0.05:
					over.draw_set_transform(c, 0.0, Vector2(1.0, 0.82))
					over.draw_arc(Vector2.ZERO, float(RULES["pull_r"]) * 0.72 * (0.45 + 0.55 * s), 0.0, TAU, 40, Color(LOOK["foam"], 0.14 * s), 1.5)
					over.draw_arc(Vector2.ZERO, float(RULES["eye_r"]) + 2.0, 0.0, TAU, 24, Color(LOOK["foam"], 0.3 * s), 1.5)
					over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"chute":
				var rt: Rect2 = w["rects"][0]
				for lane in [-6.0, 6.0]:
					var x: float = rt.get_center().x + lane
					over.draw_line(Vector2(x, rt.position.y + 2.0), Vector2(x, rt.end.y + 14.0), Color(LOOK["slag"], 0.22 + 0.06 * sin(t * 5.0 + lane)), 3.0)
			"hollow":
				for i in 2:
					var ph := fmod(t * 0.3 + i * 0.5, 1.0)
					var at := c + Vector2(sin(t * 0.9 + i * 2.0) * 8.0, 6.0 - ph * 40.0)
					over.draw_circle(at, 1.6, Color(0.7, 1.0, 0.55, 0.55 * sin(ph * PI)))
