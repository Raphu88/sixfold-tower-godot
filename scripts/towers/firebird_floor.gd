extends Node2D
## The Firebird's tower: islands of rock over the abyss. Its rooms are
## ragged islands (towers/organic.gd), the corridors between them bridges
## over nothing, and you can see across the abyss to the islands beyond
## (main.sight_open: rock to walk, open to the eye). Its own system is
## EMBERS AND REBIRTH:
##   updrafts   a long bridge may be broken by a gap too wide to jump, with
##              a vent of rising air on either side: step onto it and you're
##              carried across (faster in Firebird Form, which flies anyway)
##   burning    some bridges burn behind you once you've crossed: a slice of
##              them falls away into the abyss (a one-tile gap: jump it) and
##              regrows from embers a few seconds later, so the way back
##              always comes again
##   storms     ember storms sweep across some islands on a beat: a warning
##              haze on the windward side, then a front of burning wind
##              across the island; stand behind rock (a spire, a pillar, the
##              island's edge) and it passes over you. Firebird Form's own
##              fire doesn't burn you. It burns monsters too (not the fiery ones).
## Planned by after_build (floors.gd, from floor_styles.gd "builder"), run
## by this node (main.gd tower_systems), which also paints the abyss
## (room.gd layout_painter). Every number and word is in RULES and TEXT.

const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")
const Palette := preload("res://scripts/palette.gd")

const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0

## gap_len: a bridge this many tiles long or more may have a gap (gap: its
## width in tiles, then a wider one from gap_wide tiles); gaps: [[up to
## floor, how many]]; carry: px a second an updraft carries you (fly: times
## that in Firebird Form); burning: [[up to floor, bridges]], burn_wait:
## seconds from crossing to the fall, regrow: seconds until it's back;
## storms: [[up to floor, islands]], every / warn / sweep: the beat
## (seconds), dmg (+ per_floor), shelter: how far rock upwind shelters you
## (px), spires: [least, most] rock spires laid on a storm island.
static var RULES := {
	"gap_len": 8, "gap": 2, "gap_wide": 10, "gaps": [[3, 1], [7, 2], [99, 2]],
	"carry": 250.0, "fly": 1.6,
	"burning": [[2, 0], [6, 1], [99, 2]], "burn_wait": 1.3, "regrow": 9.0,
	"storms": [[2, 0], [5, 1], [99, 2]], "every": 8.0, "warn": 1.8, "sweep": 1.3, "dmg": 9.0, "per_floor": 1.0,
	"shelter": 110.0, "spires": [2, 3], "storm_from": 3,
}
static var TEXT := {
	"updraft": "Carried on the updraft",
	"burns": "The bridge burns behind you",
	"regrows": "Embers knit the bridge back",
	"storm": "Ember storm! Get behind rock",
	"sheltered": "Sheltered",
	"singed": "Caught in the storm",
}
## Monsters the storm doesn't burn (they're fire themselves, or fly above it).
const FIERY := ["wisp", "cinder", "firebird", "ashwing", "bloomcap", "wyvern", "bat", "gryphon"]

var main
var on := false
var data := {}
var gaps: Array = []
var bridges: Array = []  # burning bridges: {slice, corridor, a, b, state, t, inside, from}
var storms: Array = []  # {room, rect, dir, phase, t, hit}
var carry := {}  # {to, t}
var vent_wait := false
var burnt := {}  # key -> Rect2: slices fallen away (chasms for now)
var base_chasms: Array = []
var bridge_tiles := {}  # Vector2i -> "h" or "v": corridor tiles drawn as bridges
var over: Node2D  # storms and updrafts, drawn over the darkness
var redraw_t := 0.0
var carries := 0  # (tests)
var storm_hits := 0
var sheltered := 0


# --- planning (floors.gd) ---------------------------------------------------------------

static func step_for(table: Array, floor_num: int) -> int:
	for row in table:
		if floor_num <= int(row[0]):
			return int(row[1])
	return int(table[-1][1])


## Lays the tower's own features on a planned floor: gaps with updrafts and
## burning bridges in the corridors, ember storms (with rock spires to
## shelter behind) on some islands. Writes plan["firebird"].
static func after_build(plan: Dictionary, infos: Array, links: Array, floor_num: int, _tower: Dictionary, _style: Dictionary) -> void:
	var out := {"corridors": [], "gaps": [], "burning": [], "storms": []}
	var cands: Array = []
	for l in links:
		var link: Dictionary = l["link"]
		out["corridors"].append({"rect": link["rect"], "horiz": int(link["side_c"]) >= 2})
		cands.append(link)
	cands.shuffle()
	var chasms: Array = plan["chasms"]
	var used := {}
	# Gaps too wide to jump, an updraft on either side.
	var want := step_for(RULES["gaps"], floor_num)
	for link in cands:
		if out["gaps"].size() >= want:
			break
		var cr: Rect2i = link["corridor"]
		var ew: bool = int(link["side_c"]) >= 2
		var n := cr.size.x if ew else cr.size.y
		if n < int(RULES["gap_len"]) or chasms.any(func(c): return Rect2(c).intersects(link["rect"])):
			continue
		var g := int(RULES["gap"]) + (1 if n >= int(RULES["gap_wide"]) else 0)
		var a := (n - g) / 2
		var gap_r := _span(cr, ew, a, a + g)
		var v1 := _span(cr, ew, a - 1, a)
		var v2 := _span(cr, ew, a + g, a + g + 1)
		var land1 := _span(cr, ew, a + g + 1, a + g + 2).get_center()  # (from v1, past v2)
		var land2 := _span(cr, ew, a - 2, a - 1).get_center()
		chasms.append(gap_r)
		out["gaps"].append({"rect": gap_r, "horiz": ew, "vents": [{"rect": v1, "to": land1}, {"rect": v2, "to": land2}]})
		plan["doorways"].append(link["rect"])  # (traps keep off it)
		used[link] = true
	# Bridges that burn behind you.
	want = step_for(RULES["burning"], floor_num)
	for link in cands:
		if out["burning"].size() >= want:
			break
		if used.has(link):
			continue
		var cr: Rect2i = link["corridor"]
		var ew: bool = int(link["side_c"]) >= 2
		var n := cr.size.x if ew else cr.size.y
		if n < 3 or chasms.any(func(c): return Rect2(c).intersects(link["rect"])):
			continue
		var mid := n / 2
		out["burning"].append({"slice": _span(cr, ew, mid, mid + 1), "corridor": link["rect"], "horiz": ew,
			"a": _span(cr, ew, 0, 1).get_center(), "b": _span(cr, ew, n - 1, n).get_center()})
		plan["doorways"].append(link["rect"])
		used[link] = true
	# Ember storms on some islands, with rock spires to shelter behind.
	want = step_for(RULES["storms"], floor_num) if floor_num >= int(RULES["storm_from"]) else 0
	var order: Array = range(1, infos.size())
	order.shuffle()
	var keep: Array = plan.get("keep", [])
	for i in order:
		if out["storms"].size() >= want:
			break
		var info: Dictionary = infos[i]
		var th: Dictionary = Themes.get_theme(String(info["theme"]))
		if info["role"] in ["stair", "entrance"] or th["kind"] in ["good", "calm", "scenario", "mirror"] or th["feature"] in ["trap", "puzzle", "objective", "trader", "rest", "vault", "chasm"]:
			continue
		if info["role"] == "gallery" and info.get("puzzle", "") != "":
			continue
		if mini(info["size"].x, info["size"].y) < 7:
			continue
		var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
		var storm := {"room": i, "rect": info["rect"], "dir": dirs[randi() % 4], "phase": randf() * float(RULES["every"])}
		# Rock spires (cover: main.gd keeps only those that wall nothing off).
		var spots: Array = Rooms.open_tiles(info["rows"], 2).filter(func(t): return not info["reserved"].has(t))
		spots.shuffle()
		var placed: Array = []
		var n_sp := randi_range(int(RULES["spires"][0]), int(RULES["spires"][1]))
		for t in spots:
			if placed.size() >= n_sp:
				break
			var at: Vector2 = Vector2(info["rect"].position) + (Vector2(t) + Vector2(0.5, 0.5)) * CELL
			if keep.any(func(k): return Vector2(k).distance_to(at) < CELL * 1.6) or placed.any(func(q): return Vector2(q).distance_to(Vector2(t)) < 3.0):
				continue
			if plan["monsters"].any(func(m): return Vector2(m[1]).distance_to(at) < CELL):
				continue
			placed.append(t)
			info["reserved"][t] = true
			plan["blocks"].append(Rect2(Vector2(info["rect"].position) + Vector2(t) * CELL, Vector2(CELL, CELL)))
		storm["spires"] = placed.size()
		out["storms"].append(storm)
	plan["firebird"] = out


## Tiles a..b (exclusive) along a corridor, across its full width (world px).
static func _span(cr: Rect2i, ew: bool, a: int, b: int) -> Rect2:
	var r: Rect2i = Rect2i(cr.position + Vector2i(a, 0), Vector2i(b - a, cr.size.y)) if ew else Rect2i(cr.position + Vector2i(0, a), Vector2i(cr.size.x, b - a))
	return Rect2(ORIGIN + Vector2(r.position) * CELL, Vector2(r.size) * CELL)


# --- running (main.gd) ------------------------------------------------------------------

func _ready() -> void:
	z_index = -2
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 44  # (over the darkness, under the monsters' telegraphs)
	over.draw.connect(_draw_over)
	add_child(over)


func setup(plan: Dictionary) -> void:
	on = false
	carry = {}
	vent_wait = false
	burnt.clear()
	gaps.clear()
	bridges.clear()
	storms.clear()
	bridge_tiles.clear()
	carries = 0
	storm_hits = 0
	sheltered = 0
	if main == null:
		return
	if main.room_view != null and main.room_view.layout_painter == self:
		main.room_view.layout_painter = null
	data = plan.get("firebird", {})
	if data.is_empty() or not main.layout_on:
		queue_redraw()
		return
	on = true
	base_chasms = main.chasms.duplicate()
	gaps = data["gaps"].duplicate(true)
	for b0 in data["burning"]:
		var b: Dictionary = b0.duplicate()
		b["state"] = "whole"
		b["t"] = 0.0
		b["inside"] = false
		b["from"] = Vector2.INF
		b["id"] = bridges.size()
		bridges.append(b)
	for s0 in data["storms"]:
		var s: Dictionary = s0.duplicate()
		s["t"] = 0.0
		s["hit"] = {}
		s["was"] = false
		storms.append(s)
	for c in data["corridors"]:
		for t in main._tiles_in(c["rect"]):
			bridge_tiles[t] = "h" if c["horiz"] else "v"
	for w in plan.get("wings", []):  # (a sealed wing's way in is a bridge too; a secret's stays hidden)
		var wr: Rect2 = w["corridor"]
		for t in main._tiles_in(wr):
			bridge_tiles[t] = "h" if wr.size.x > wr.size.y else "v"
	# The abyss: rock to walk on, open to the eye (what's carved, hidden or not, stays rock to sight).
	var gs: Vector2i = main.grid_size
	var walked := PackedByteArray()
	walked.resize(gs.x * gs.y)
	for r in plan.get("walk", []):
		for t in main._tiles_in(r):
			walked[t.y * gs.x + t.x] = 1
	var open := PackedByteArray()
	open.resize(gs.x * gs.y)
	for i in open.size():
		open[i] = 1 if main.solid[i] == 1 and walked[i] == 0 else 0
	main.sight_open = open
	main.room_view.layout_painter = self
	main.room_view.queue_redraw()
	queue_redraw()


func slow(_pos: Vector2) -> float:
	return 1.0


func _physics_process(delta: float) -> void:
	if not on or main == null or main.player == null:
		return
	var p = main.player
	if not p.dead and not main.climbing:
		_updrafts(p)
		_bridges(delta, p)
		_storms(delta, p)
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()
		over.queue_redraw()


## Step onto a vent and the rising air carries you over the gap.
func _updrafts(p) -> void:
	if not carry.is_empty():
		if p.jump_t <= 0.0 or p.dead:
			carry = {}
		else:
			p.jump_vel = (Vector2(carry["to"]) - p.global_position) / maxf(p.jump_t, 0.05)
			if randf() < 0.5:
				main.fx_burst(p.global_position + Vector2(randf_range(-10, 10), 8), Vector2.UP, Color(1.0, 0.7, 0.35), 1, 90.0)
		return
	var in_vent := false
	for g in gaps:
		for v in g["vents"]:
			if Rect2(v["rect"]).has_point(p.global_position):
				in_vent = true
				if not vent_wait:
					_lift(p, v["to"])
					return
	vent_wait = in_vent


func _lift(p, to: Vector2) -> void:
	var speed := float(RULES["carry"]) * (float(RULES["fly"]) if p.flying() else 1.0)
	var dur := maxf(0.35, p.global_position.distance_to(to) / speed)
	p.jump_t = dur
	p.jump_total = dur
	p.glide_left = 0.0
	p.roll_t = 0.0
	p.jump_vel = (to - p.global_position) / dur
	carry = {"to": to}
	vent_wait = true
	carries += 1
	main.fx_text(p.global_position + Vector2(0, -40), TEXT["updraft"], Color(1.0, 0.8, 0.5))
	main.sfx("gust", 1.2, -4.0)
	main.fx_ring(p.global_position, Color(1.0, 0.75, 0.4), 30.0, 0.3, 2.0)


## A bridge you've crossed burns behind you; it regrows from embers.
func _bridges(delta: float, p) -> void:
	var pos: Vector2 = p.global_position
	for b in bridges:
		var cor: Rect2 = b["corridor"]
		var inside := cor.has_point(pos)
		match String(b["state"]):
			"whole":
				if inside and not b["inside"]:
					b["from"] = b["a"] if pos.distance_to(b["a"]) < pos.distance_to(b["b"]) else b["b"]
				elif not inside and b["inside"] and b["from"] != Vector2.INF:
					var out_end: Vector2 = b["a"] if pos.distance_to(b["a"]) < pos.distance_to(b["b"]) else b["b"]
					if out_end != b["from"]:
						b["state"] = "smoulder"
						b["t"] = float(RULES["burn_wait"])
						main.fx_text(Rect2(b["slice"]).get_center() + Vector2(0, -30), TEXT["burns"], Color(1.0, 0.6, 0.3))
						main.sfx("burn", 1.0, -4.0)
					b["from"] = Vector2.INF
			"smoulder":
				b["t"] -= delta
				if b["t"] <= 0.0:
					if Rect2(b["slice"]).grow(p.radius).has_point(pos) and not p.in_air():
						b["t"] = 0.3  # (never out from under the climber's feet)
					else:
						b["state"] = "burnt"
						b["t"] = float(RULES["regrow"])
						set_burnt(b["id"], b["slice"], true)
						main.fx_burst(Rect2(b["slice"]).get_center(), Vector2.DOWN, Color(1.0, 0.55, 0.25), 16, 160.0)
						main.sfx("burn", 0.7, -2.0)
			"burnt":
				b["t"] -= delta
				if b["t"] <= 0.0 and not (Rect2(b["slice"]).grow(4.0).has_point(pos) and p.in_air()):
					b["state"] = "whole"
					set_burnt(b["id"], b["slice"], false)
					main.fx_burst(Rect2(b["slice"]).get_center(), Vector2.UP, Color(1.0, 0.75, 0.4), 12, 100.0)
					if pos.distance_to(Rect2(b["slice"]).get_center()) < 400.0:
						main.fx_text(Rect2(b["slice"]).get_center() + Vector2(0, -30), TEXT["regrows"], Color(1.0, 0.8, 0.5))
		b["inside"] = inside


## A slice of floor falls away into the abyss (a chasm) or comes back.
func set_burnt(key, r: Rect2, gone: bool) -> void:
	if gone:
		burnt[key] = r
	else:
		burnt.erase(key)
	main.set_chasms(base_chasms + burnt.values())


## The storms' beat: a warning, then a front of burning wind across the island.
func _storms(delta: float, p) -> void:
	var every := float(RULES["every"])
	var warn := float(RULES["warn"])
	var sweep := float(RULES["sweep"])
	for s in storms:
		s["t"] += delta
		var local := fmod(s["t"] + s["phase"], every)
		var rect: Rect2 = s["rect"]
		var here: bool = rect.has_point(p.global_position)
		if local >= every - warn and not s["was"] and here:
			s["was"] = true
			main.fx_text(p.global_position + Vector2(0, -46), TEXT["storm"], Color(1.0, 0.55, 0.3))
			main.sfx("gust", 0.7, -2.0)
		if local < sweep:
			s["was"] = false
			var front := _front(s, local / sweep)
			# The climber, once a sweep, unless rock stands upwind.
			if here and not s["hit"].has("p") and absf(_along(s, p.global_position) - front) < 26.0:
				s["hit"]["p"] = true
				if p.flying():
					pass  # (Firebird Form's own fire: it doesn't burn you)
				elif shelter(s, p.global_position):
					sheltered += 1
					main.fx_text(p.global_position + Vector2(0, -40), TEXT["sheltered"], Color(0.85, 0.85, 0.75))
				else:
					storm_hits += 1
					p.receive_attack(float(RULES["dmg"]) + float(RULES["per_floor"]) * main.floor_num, null, true)
					main.fx_burst(p.global_position, Vector2(s["dir"]), Color(1.0, 0.55, 0.25), 10, 160.0)
			for e in main.enemies():
				if e.kind in FIERY or s["hit"].has(e) or not rect.has_point(e.global_position):
					continue
				if absf(_along(s, e.global_position) - front) < 26.0:
					s["hit"][e] = true
					if not shelter(s, e.global_position):
						e.take_hit(float(RULES["dmg"]) * 0.8, Vector2(s["dir"]), 120.0)
		elif not s["hit"].is_empty():
			s["hit"] = {}


## Where along the storm's way a point lies (px from the windward edge).
func _along(s: Dictionary, pos: Vector2) -> float:
	var r: Rect2 = s["rect"]
	var d: Vector2 = s["dir"]
	var lo := minf(r.position.dot(d), r.end.dot(d))
	return pos.dot(d) - lo


func _front(s: Dictionary, k: float) -> float:
	var r: Rect2 = s["rect"]
	var d: Vector2 = s["dir"]
	return (absf(r.size.dot(d)) + 60.0) * k - 30.0


## Rock upwind (a wall, a spire, a pillar) within reach shelters a spot.
func shelter(s: Dictionary, pos: Vector2) -> bool:
	var d: Vector2 = s["dir"]
	var n := int(float(RULES["shelter"]) / 14.0)
	for i in range(1, n + 1):
		var q: Vector2 = pos - d * 14.0 * i
		if main.is_solid(q):
			return true
		for pl in main.pillars:
			if q.distance_to(pl["pos"]) < float(pl["r"]) + 4.0:
				return true
	return false


## How the storm on an island stands now: {state ("calm", "warn", "sweep"), k}.
func storm_state(s: Dictionary) -> Dictionary:
	var every := float(RULES["every"])
	var local := fmod(float(s["t"]) + float(s["phase"]), every)
	if local < float(RULES["sweep"]):
		return {"state": "sweep", "k": local / float(RULES["sweep"])}
	if local >= every - float(RULES["warn"]):
		return {"state": "warn", "k": (local - (every - float(RULES["warn"]))) / float(RULES["warn"])}
	return {"state": "calm", "k": 0.0}


# --- the floor bot and the tests ---------------------------------------------------------

## The bot: wait out a storm's warning behind rock? It simply keeps going;
## nothing here needs more than walking (updrafts take you when you step on).
func bot_avoid() -> Array:
	return []


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if not on:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for b in bridges:
		var r: Rect2 = b["slice"]
		match String(b["state"]):
			"smoulder":
				var k: float = 1.0 - float(b["t"]) / float(RULES["burn_wait"])
				draw_rect(r, Color(1.0, 0.45, 0.15, 0.25 + 0.4 * k))
				for i in 4:
					var fx := r.position + Vector2(fmod(i * 13.7 + t * 30.0, r.size.x), r.size.y * (0.2 + 0.2 * i))
					draw_circle(fx, 3.0 + 3.0 * k, Color(1.0, 0.75, 0.3, 0.7))
			"burnt":
				# Ember strands knitting across the gap as it regrows.
				var k2: float = 1.0 - float(b["t"]) / float(RULES["regrow"])
				var horiz: bool = b["horiz"]
				for i in 3:
					var y := r.position.y + r.size.y * (0.25 + 0.25 * i) if horiz else r.position.y
					var x := r.position.x if horiz else r.position.x + r.size.x * (0.25 + 0.25 * i)
					var a := Vector2(x, y)
					var e := a + (Vector2(r.size.x * k2, 0) if horiz else Vector2(0, r.size.y * k2))
					draw_line(a, e, Color(1.0, 0.6, 0.25, 0.5 + 0.3 * sin(t * 6.0 + i)), 1.5)


func _draw_over() -> void:
	if not on or main == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var view: Rect2 = main.room_view._view_rect()
	# Updrafts: rising streaks and motes over each vent.
	for g in gaps:
		for v in g["vents"]:
			var r: Rect2 = v["rect"]
			if not view.intersects(r):
				continue
			over.draw_rect(r.grow(-3.0), Color(1.0, 0.7, 0.4, 0.1 + 0.05 * sin(t * 3.0)))
			for i in 5:
				var ph := fmod(t * 0.9 + i * 0.21, 1.0)
				var x := r.position.x + r.size.x * (0.15 + 0.17 * i)
				var y := r.end.y - r.size.y * ph - 10.0 * ph
				over.draw_line(Vector2(x, y), Vector2(x + sin(t * 4.0 + i) * 3.0, y - 9.0), Color(1.0, 0.85, 0.6, 0.55 * sin(ph * PI)), 1.5)
			# A chevron toward the far side.
			var to: Vector2 = Vector2(v["to"]) - r.get_center()
			var c := r.get_center() + to.normalized() * 6.0
			var s := to.normalized().orthogonal() * 6.0
			over.draw_polyline(PackedVector2Array([c - to.normalized() * 6.0 + s, c, c - to.normalized() * 6.0 - s]), Color(1.0, 0.85, 0.55, 0.6), 2.0)
	# Storms: the haze building on the windward side, then the front.
	for s in storms:
		var rect: Rect2 = s["rect"]
		if not view.intersects(rect):
			continue
		var st := storm_state(s)
		var d: Vector2 = s["dir"]
		if st["state"] == "warn":
			var k: float = st["k"]
			var edge := _band(rect, d, -30.0, 30.0 + 40.0 * k)
			over.draw_colored_polygon(edge, Color(1.0, 0.45, 0.2, 0.12 + 0.2 * k))
			for i in 8:
				var at := _point(rect, d, 10.0 + 30.0 * k * fmod(i * 0.37 + t, 1.0), (i + 0.5) / 8.0)
				over.draw_circle(at, 2.0, Color(1.0, 0.7, 0.3, 0.4 + 0.5 * k))
		elif st["state"] == "sweep":
			var front := _front(s, st["k"])
			over.draw_colored_polygon(_band(rect, d, front - 34.0, front + 22.0), Color(1.0, 0.5, 0.2, 0.28))
			over.draw_colored_polygon(_band(rect, d, front - 12.0, front + 10.0), Color(1.0, 0.75, 0.35, 0.3))
			for i in 14:
				var at := _point(rect, d, front - 30.0 + fmod(i * 23.0 + t * 200.0, 50.0), fmod(i * 0.137 + t * 0.3, 1.0))
				over.draw_circle(at, 2.2, Color(1.0, 0.85, 0.45, 0.8))


## A band across a rect, from `a` to `b` px along `d` (from its windward edge).
func _band(r: Rect2, d: Vector2, a: float, b: float) -> PackedVector2Array:
	return PackedVector2Array([_point(r, d, a, 0.0), _point(r, d, b, 0.0), _point(r, d, b, 1.0), _point(r, d, a, 1.0)])


## The point `along` px from the rect's windward edge, `across` (0..1) along that edge.
func _point(r: Rect2, d: Vector2, along: float, across: float) -> Vector2:
	if absf(d.x) > 0.5:
		var x0 := r.position.x if d.x > 0.0 else r.end.x
		return Vector2(x0 + d.x * along, r.position.y + r.size.y * across)
	var y0 := r.position.y if d.y > 0.0 else r.end.y
	return Vector2(r.position.x + r.size.x * across, y0 + d.y * along)


## Paints the abyss round the islands, the cliffs under their edges, the
## bridges, and rock spires (room.gd calls it while it draws the floor).
func paint(rv, batch) -> bool:
	if not on or rv.grid == Vector2i.ZERO:
		return false
	var grid: Vector2i = rv.grid
	var solid: PackedByteArray = rv.solid
	var room: Rect2 = rv.room
	var T := CELL
	var deep := Color(0.03, 0.02, 0.035)
	var haze := Color(0.32, 0.12, 0.08)
	var rock := Color(0.26, 0.2, 0.2)
	var rock_dark := Color(0.13, 0.1, 0.11)
	# The arena's edge falls away too: the abyss beyond it.
	var far := room.grow(rv.wall + 30.0)
	batch.rect(Rect2(far.position, Vector2(far.size.x, room.position.y - far.position.y)), deep)
	batch.rect(Rect2(far.position.x, room.end.y, far.size.x, far.end.y - room.end.y), deep)
	batch.rect(Rect2(far.position.x, room.position.y, room.position.x - far.position.x, room.size.y), deep)
	batch.rect(Rect2(room.end.x, room.position.y, far.end.x - room.end.x, room.size.y), deep)
	var open := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < grid.x and y < grid.y and solid[y * grid.x + x] == 0
	for y in grid.y:
		for x in grid.x:
			if solid[y * grid.x + x] == 0 or rv.block_tiles.has(Vector2i(x, y)):
				continue
			var tile := Rect2(room.position + Vector2(x, y) * T, Vector2(T, T))
			batch.rect(tile, deep)
			# Far below: a warm haze here and there, and the odd ember.
			var hz: float = rv._hash(x / 3, y / 3, 41)
			if hz < 0.35:
				batch.rect(tile, Color(haze, 0.06 + 0.08 * (0.35 - hz)))
			if rv._hash(x, y, 43) < 0.07:
				batch.circle(tile.position + Vector2(rv._hash(x, y, 44), rv._hash(x, y, 45)) * T, 1.3, Color(1.0, 0.55, 0.25, 0.5))
			# An island's edge just north of here: its cliff, falling away into the dark.
			if open.call(x, y - 1):
				var drop: float = T * (0.55 + 0.35 * rv._hash(x, y, 46))
				var pts := PackedVector2Array([tile.position, Vector2(tile.end.x, tile.position.y)])
				pts.append(Vector2(tile.end.x, tile.position.y + drop * (0.7 + 0.3 * rv._hash(x + 1, y, 46))))
				pts.append(Vector2(tile.position.x + T * 0.5, tile.position.y + drop))
				pts.append(Vector2(tile.position.x, tile.position.y + drop * (0.7 + 0.3 * rv._hash(x, y, 47))))
				batch._clipped(pts, rock_dark)
				batch.rect(Rect2(tile.position, Vector2(T, 6.0)), rock)
				batch.line(tile.position + Vector2(0, T * 0.3), tile.position + Vector2(T, T * 0.28), Color(rock, 0.6), 1.5)
			if open.call(x, y + 1):
				batch.rect(Rect2(tile.position.x, tile.end.y - 4.0, T, 4.0), rock)
				batch.line(Vector2(tile.position.x, tile.end.y - 4.0), Vector2(tile.end.x, tile.end.y - 4.0), Color(0.45, 0.36, 0.33), 1.5)
			if open.call(x - 1, y):
				batch.rect(Rect2(tile.position.x, tile.position.y, 4.0, T), rock)
			if open.call(x + 1, y):
				batch.rect(Rect2(tile.end.x - 4.0, tile.position.y, 4.0, T), rock)
			# Ragged corners: a chip of rock where two edges meet.
			if open.call(x - 1, y) and open.call(x, y + 1):
				batch.circle(Vector2(tile.position.x, tile.end.y), 7.0, rock)
			if open.call(x + 1, y) and open.call(x, y + 1):
				batch.circle(tile.end, 7.0, rock)
	# The bridges: planks across, a rope along each side.
	for t in bridge_tiles:
		if not open.call(t.x, t.y):
			continue
		var tile := Rect2(room.position + Vector2(t) * T, Vector2(T, T))
		var horiz: bool = bridge_tiles[t] == "h"
		var plank := Color(0.42, 0.29, 0.2)
		for i in 4:
			var shade: float = rv._hash(t.x * 4 + i, t.y, 48) * 0.15
			var pr := Rect2(tile.position + Vector2(i * T / 4.0 + 1.0, 0), Vector2(T / 4.0 - 2.0, T)) if horiz else Rect2(tile.position + Vector2(0, i * T / 4.0 + 1.0), Vector2(T, T / 4.0 - 2.0))
			batch.rect(pr, plank.lightened(shade))
		var side := Vector2(0, 1) if horiz else Vector2(1, 0)
		for k in [0.08, 0.92]:
			var a: Vector2 = tile.position + side * T * k
			var b: Vector2 = a + (Vector2(T, 0) if horiz else Vector2(0, T))
			batch.line(a, b, Color(0.62, 0.52, 0.36), 2.0)
	# Rock spires (cover): a jagged column of the island's rock.
	for b in rv.blocks:
		var r: Rect2 = b
		batch.circle(r.get_center() + Vector2(4, r.size.y * 0.35), r.size.x * 0.42, Color(0, 0, 0, 0.3))
		var c := r.get_center()
		var pts := PackedVector2Array([c + Vector2(-r.size.x * 0.42, r.size.y * 0.4), c + Vector2(-r.size.x * 0.3, -r.size.y * 0.3),
			c + Vector2(-r.size.x * 0.05, -r.size.y * 0.48), c + Vector2(r.size.x * 0.32, -r.size.y * 0.25), c + Vector2(r.size.x * 0.44, r.size.y * 0.4)])
		batch._clipped(pts, rock)
		batch._clipped(PackedVector2Array([pts[1], pts[2], c + Vector2(0, r.size.y * 0.3)]), rock.lightened(0.15))
		batch.polyline(pts, Palette.OUTLINE, 1.5)
	return true
