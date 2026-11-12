extends Node2D
## Scenario rooms: short set pieces you play through, and how you do is
## noticed. Each waits on a glowing MARK in its room; step onto it to begin
## (nothing starts by accident, and you can walk past). It ends with a grade,
## gold, silver, bronze or none, and the grade is noticed: essence, renown
## (Renown.earn), the Makers' interest (Makers.feed "scenario"), and the
## climb's tally of what the beast noticed (main.noticed, for the summit or
## the Regard to read later), with a banner: "THE GRYPHON NOTICED".
##
## The kinds (names and words in themes.gd's scn_ rooms and TEXT below,
## numbers in SCENARIOS, all in the Data editor):
##   defend    keep the monsters off a fallen climber's camp for 30 seconds
##   collapse  run the falling hall to its far end, dodging the rocks
##   duel      a champion fights you fairly, alone: take as few hits as you can
##   unseen    cross the hall without the lanterns' light falling on you
##   rescue    free a caged cub and lead it to the door, keeping it safe
##   gauntlet  beat every wave, and be quick
##   forge     (the Wyvern's) keep three furnaces lit while waves come
##   sinking   (the Manticore's) the court's floor gives way to sand: keep to
##             the stones and reach the far gate
## A kind with "towers" only turns up in those towers; one with "module" is
## planned and run by that tower's floor script (main.tower_floor:
## scenario_plan, scenario_begin, scenario_tick, scenario_status,
## scenario_goal), and it draws it too. "seal": its doors shut while it runs.
## "weight": how many times likelier it is than one of the shared kinds.
## floors.gd fixes scenario rooms (in dead ends first) and asks `plan` for
## each one's marks; main.gd runs them through `setup`.

const ORIGIN := Vector2(80, 100)  # (floors.gd ORIGIN)
const CELL := 40.0  # (floors.gd CELL)
const Rooms := preload("res://scripts/rooms.gd")
const Renown := preload("res://scripts/renown.gd")
const Makers := preload("res://scripts/makers.gd")
const Essence := preload("res://scripts/essence.gd")
const Palette := preload("res://scripts/palette.gd")

## from: the first floor it appears on; time / waves / thresholds per kind.
## Grades: "gold", "silver", "bronze" thresholds (what each means is per kind).
static var SCENARIOS := {
	"defend": {"from": 2, "time": 30.0, "wave_every": 5.0, "per_wave": 2, "camp_hp": 100.0, "drain": 9.0, "near": 54.0,
		"gold": 0.75, "silver": 0.4},
	"collapse": {"from": 2, "every": 0.32, "warn": 0.9, "radius": 34.0, "dmg": 10.0, "dmg_per_floor": 1.0, "slack": 2.4, "gold_hits": 0, "silver_hits": 1},
	"duel": {"from": 3, "hp": 2.0, "gold_hits": 0, "silver_hits": 2},
	"unseen": {"from": 2, "reach": 230.0, "half_angle": 24.0, "sweep": 0.9, "speed": 0.8, "cooldown": 1.6, "gold": 0, "silver": 1, "fail": 3},
	"rescue": {"from": 3, "cage_hits": 3, "cub_hp": 60.0, "drain": 10.0, "near": 40.0, "speed": 150.0, "wave_every": 6.0, "per_wave": 2,
		"gold": 0.75, "silver": 0.4},
	"gauntlet": {"from": 2, "waves": 3, "budget": 2.6, "budget_per_floor": 0.35, "par": 14.0, "par_per_wave": 7.0, "silver_k": 1.5},
	"forge": {"from": 3, "towers": ["wyvern"], "module": "res://scripts/towers/wyvern_floor.gd", "seal": true, "weight": 3},
	"sinking": {"from": 2, "towers": ["manticore"], "module": "res://scripts/towers/manticore_floor.gd", "weight": 3},
}
## What a grade pays: essence (base, per floor) and renown.
static var GRADES := {
	"gold": {"essence": 14.0, "per_floor": 3.0, "renown": 8, "name": "Gold"},
	"silver": {"essence": 9.0, "per_floor": 2.0, "renown": 4, "name": "Silver"},
	"bronze": {"essence": 5.0, "per_floor": 1.0, "renown": 2, "name": "Bronze"},
	"none": {"essence": 0.0, "per_floor": 0.0, "renown": 0, "name": "No grade"},
}
static var TEXT := {
	"mark": "Step onto the mark to begin",
	"begin": "Begin!",
	"noticed": "%s NOTICED",
	"noticed_line": "%s: %s",
	"renown": "Renown: %s",
	"defend": "Keep them off the camp",
	"defend_line": "Camp %d%%  ·  %d s",
	"collapse": "Run for the far end",
	"collapse_line": "Hits %d  ·  %d s",
	"duel": "Fight the champion",
	"duel_line": "Hits taken: %d",
	"unseen": "Cross unseen",
	"unseen_line": "Seen %d times",
	"seen": "Seen!",
	"rescue": "Free the cub",
	"rescue_free": "Lead it to the door",
	"rescue_line": "Cub %d%%",
	"gauntlet": "Beat every wave",
	"gauntlet_line": "Wave %d of %d  ·  %d s",
	"failed": "It's over",
	"left": "You left the room",
	"cub": "A small grey creature, all ears",
}

var main
var list: Array = []  # each scenario: plan + state
var active := {}
var hp_seen := 0.0
var redraw_t := 0.0
var bodies: Array = []
var rocks: Array = []  # collapse: {pos, t (warning left), r}
var cub := {}  # rescue: {pos, hp, free}
var results: Array = []  # this floor's grades (tests)


## Which kinds may appear on a floor.
static func kinds_for(floor_num: int, tid: String) -> Array:
	var out: Array = []
	for k in SCENARIOS:
		var towers: Array = SCENARIOS[k].get("towers", [])
		if floor_num >= int(SCENARIOS[k]["from"]) and (towers.is_empty() or tid in towers):
			for n in maxi(1, int(SCENARIOS[k].get("weight", 1))):
				out.append(k)  # ("weight": listed that many times, so likelier)
	return out


## A scenario's marks in its room (floors.gd): {kind, rect, start (the mark),
## end, spawns, gates, sentries, centre, keep}; {} if the room won't do.
static func plan(kind: String, info: Dictionary, gates: Array, _floor_num: int, cell: float) -> Dictionary:
	if SCENARIOS.get(kind, {}).has("module"):
		return load(String(SCENARIOS[kind]["module"])).scenario_plan(kind, info, gates, _floor_num, cell)
	var rect: Rect2 = info["rect"]
	var rows: Array = info["rows"]
	var size: Vector2i = info["size"]
	var open: Array = Rooms.open_tiles(rows, 1).filter(func(t): return not info["reserved"].has(t))
	if open.size() < 12:
		return {}
	var at := func(t: Vector2i) -> Vector2: return rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * cell
	# The way in: the first gate's tiles (the room's own doorway).
	var door := rect.get_center()
	if not gates.is_empty():
		var t0: Vector2i = gates[0][0]
		door = ORIGIN + (Vector2(t0) + Vector2(0.5, 0.5)) * cell
	open.sort_custom(func(a, b): return at.call(a).distance_to(door) < at.call(b).distance_to(door))
	var start: Vector2 = at.call(open[mini(2, open.size() - 1)])
	var end: Vector2 = at.call(open[-1])
	var mid := Vector2(size) * 0.5
	var centre_t: Vector2i = open[0]
	for t in open:
		if Vector2(t).distance_to(mid) < Vector2(centre_t).distance_to(mid):
			centre_t = t
	var centre: Vector2 = at.call(centre_t)
	var spawns: Array = []
	for t in open:
		var p: Vector2 = at.call(t)
		if p.distance_to(start) > cell * 3.0 and p.distance_to(centre) > cell * 2.0:
			spawns.append(p)
	spawns.shuffle()
	var out := {"kind": kind, "rect": rect, "start": start, "end": end, "centre": centre, "spawns": spawns.slice(0, 10), "gates": gates,
		"keep": [start, centre]}
	if kind in ["collapse", "unseen"]:
		out["keep"].append(end)
		if start.distance_to(end) < cell * 5.0:
			return {}
	if kind == "unseen":
		# Lanterns along the long wall opposite the way across, sweeping.
		var sentries: Array = []
		var n := 2 if maxi(size.x, size.y) < 11 else 3
		var horiz := absf(end.x - start.x) >= absf(end.y - start.y)
		for k in n:
			var f := (k + 1.0) / (n + 1.0)
			var p: Vector2
			var face: float
			if horiz:
				p = Vector2(lerpf(start.x, end.x, f), rect.position.y + cell * 0.7 if k % 2 == 0 else rect.end.y - cell * 0.7)
				face = PI * 0.5 if k % 2 == 0 else -PI * 0.5
			else:
				p = Vector2(rect.position.x + cell * 0.7 if k % 2 == 0 else rect.end.x - cell * 0.7, lerpf(start.y, end.y, f))
				face = 0.0 if k % 2 == 0 else PI
			sentries.append({"pos": p, "face": face, "phase": randf() * TAU})
		out["sentries"] = sentries
		# Low walls to hide behind along the way (between the lanterns and the line across).
		var cover: Array = []
		for f in [0.3, 0.55, 0.8]:
			var q: Vector2 = start.lerp(end, f)
			var near_s: Dictionary = sentries[0]
			for sn in sentries:
				if q.distance_to(sn["pos"]) < q.distance_to(near_s["pos"]):
					near_s = sn
			var toward: Vector2 = (near_s["pos"] - q).normalized()
			var c: Vector2 = q + toward * cell * 1.2
			var t := Vector2i(((c - rect.position) / cell).floor())
			if Rooms.open_at(rows, t.x, t.y) and not info["reserved"].has(t) and at.call(t).distance_to(start) > cell * 1.5 and at.call(t).distance_to(end) > cell * 1.5:
				cover.append(Rect2(rect.position + Vector2(t) * cell, Vector2(cell, cell)))
				info["reserved"][t] = true
		out["blocks"] = cover
	if kind == "rescue":
		out["cage"] = end
		out["keep"].append(end)
	if kind == "defend":
		out["camp"] = centre
	return out


func _ready() -> void:
	z_index = -2


func setup(plan: Dictionary) -> void:
	clear()
	for s0 in plan.get("scenarios", []):
		var s: Dictionary = s0.duplicate(true)
		s["state"] = "idle"
		s["grade"] = ""
		list.append(s)
	queue_redraw()


func clear() -> void:
	_unseal()
	list.clear()
	active = {}
	rocks.clear()
	cub = {}
	results.clear()
	queue_redraw()


## True while a scenario is being played.
func running() -> bool:
	return not active.is_empty() and String(active.get("state", "")) in ["intro", "run"]


func _process(delta: float) -> void:
	if list.is_empty() or main == null or main.player == null:
		return
	var p = main.player
	if active.is_empty():
		for s in list:
			if s["state"] == "idle" and not p.dead and not main.climbing and p.global_position.distance_to(s["start"]) < 26.0:
				_begin(s)
				break
	else:
		_tick(active, delta, p)
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()


func _begin(s: Dictionary) -> void:
	active = s
	s["state"] = "intro"
	s["t"] = 0.0
	s["intro"] = 1.4
	s["hits"] = 0
	s["seen"] = 0
	s["seen_cd"] = 0.0
	s["wave"] = 0
	s["wave_t"] = 0.0
	s["mobs"] = []
	hp_seen = main.player.hp
	var cfg: Dictionary = SCENARIOS[s["kind"]]
	match String(s["kind"]):
		"defend":
			s["camp_hp"] = float(cfg["camp_hp"])
		"collapse":
			s["limit"] = s["start"].distance_to(s["end"]) / 140.0 * float(cfg["slack"]) + 4.0
			s["drop_t"] = 0.0
		"rescue":
			cub = {"pos": s["cage"], "hp": float(cfg["cub_hp"]), "free": false, "cage": int(cfg["cage_hits"])}
	if cfg.has("module") and main.get("tower_floor") != null:
		main.tower_floor.scenario_begin(s, self)  # (a tower's own scenario)
	if s["kind"] in ["defend", "duel", "rescue", "gauntlet"] or cfg.get("seal", false):
		_seal(s)
	var th: Dictionary = main.Themes.get_theme("scn_" + String(s["kind"]))
	main.banner = {"title": String(th["name"]).to_upper(), "lines": [TEXT.get(s["kind"], status_title(s))], "t": 2.2}
	main.sfx("ready", 0.9, -2.0)
	main.shake(3.0)


func _tick(s: Dictionary, delta: float, p) -> void:
	if s["state"] == "intro":
		s["intro"] -= delta
		if s["intro"] <= 0.0:
			s["state"] = "run"
			main.fx_text(p.global_position + Vector2(0, -40), TEXT["begin"], Color(1.0, 0.88, 0.6))
			if s["kind"] == "duel":
				_spawn_champion(s)
		return
	if s["state"] != "run":
		return
	s["t"] += delta
	var cfg: Dictionary = SCENARIOS[s["kind"]]
	# Hits taken (any drop in health).
	if p.hp < hp_seen - 0.5:
		s["hits"] += 1
	hp_seen = p.hp
	if p.dead:
		_finish(s, "none")
		return
	s["mobs"] = s["mobs"].filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	if cfg.has("module"):
		if main.get("tower_floor") != null:
			main.tower_floor.scenario_tick(s, delta, p, self)  # (it calls _finish)
		else:
			_finish(s, "none")
		return
	match String(s["kind"]):
		"defend":
			s["wave_t"] -= delta
			if s["wave_t"] <= 0.0 and s["t"] < float(cfg["time"]) - 3.0:
				s["wave_t"] = float(cfg["wave_every"])
				for k in int(cfg["per_wave"]) + main.floor_num / 4:
					var e = _spawn(s, 2.0)
					if e != null:
						e.goal = s["camp"]
			for e in s["mobs"]:
				if e.global_position.distance_to(s["camp"]) < float(cfg["near"]):
					s["camp_hp"] -= float(cfg["drain"]) * delta
			if s["camp_hp"] <= 0.0:
				_finish(s, "none")
			elif s["t"] >= float(cfg["time"]):
				var k: float = s["camp_hp"] / float(cfg["camp_hp"])
				_finish(s, "gold" if k >= float(cfg["gold"]) else ("silver" if k >= float(cfg["silver"]) else "bronze"))
		"collapse":
			if not s["rect"].grow(-4.0).has_point(p.global_position):
				_finish(s, "none", TEXT["left"])
				return
			s["drop_t"] -= delta
			if s["drop_t"] <= 0.0:
				s["drop_t"] = float(cfg["every"])
				var at: Vector2
				if randf() < 0.55:
					at = p.global_position + (s["end"] - p.global_position).normalized() * randf_range(30.0, 110.0) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
				else:
					at = s["rect"].position + Vector2(randf() * s["rect"].size.x, randf() * s["rect"].size.y)
				if not main.is_solid(at) and at.distance_to(s["end"]) > 40.0:
					rocks.append({"pos": at, "t": float(cfg["warn"]), "r": float(cfg["radius"])})
			for r in rocks:
				r["t"] -= delta
				if r["t"] <= 0.0 and not r.get("hit", false):
					r["hit"] = true
					main.fx_burst(r["pos"], Vector2.ZERO, Palette.WALL_EDGE, 10, 160.0)
					main.sfx("slam", 1.2, -10.0)
					if p.global_position.distance_to(r["pos"]) < r["r"] + p.radius and p.iframes <= 0.0:
						p.receive_attack(float(cfg["dmg"]) + float(cfg["dmg_per_floor"]) * main.floor_num, null, true)
			rocks = rocks.filter(func(r): return r["t"] > -0.4)
			if p.global_position.distance_to(s["end"]) < 30.0:
				var hits: int = s["hits"]
				_finish(s, "gold" if hits <= int(cfg["gold_hits"]) and s["t"] <= s["limit"] * 0.6 else ("silver" if hits <= int(cfg["silver_hits"]) else "bronze"))
			elif s["t"] >= s["limit"]:
				p.receive_attack(15.0, null, true)
				_finish(s, "none")
		"duel":
			if s["t"] > 1.0 and s["mobs"].is_empty():
				var hits: int = s["hits"]
				_finish(s, "gold" if hits <= int(cfg["gold_hits"]) else ("silver" if hits <= int(cfg["silver_hits"]) else "bronze"))
		"unseen":
			if not s["rect"].grow(-4.0).has_point(p.global_position):
				_finish(s, "none", TEXT["left"])
				return
			s["seen_cd"] -= delta
			if s["seen_cd"] <= 0.0 and _spotted(s, p):
				s["seen"] += 1
				s["seen_cd"] = float(cfg["cooldown"])
				main.fx_text(p.global_position + Vector2(0, -40), TEXT["seen"], Color(1.0, 0.55, 0.4))
				main.sfx("warn_knight", 1.1, -4.0)
				main.light_flash(p.global_position, Color(1.0, 0.85, 0.5), 1.2, 1.2, 0.3)
				var e = _spawn(s, 2.0)
				if e != null:
					e.wake()
				if s["seen"] >= int(cfg["fail"]):
					_finish(s, "none")
					return
			if p.global_position.distance_to(s["end"]) < 30.0:
				var n: int = s["seen"]
				_finish(s, "gold" if n <= int(cfg["gold"]) else ("silver" if n <= int(cfg["silver"]) else "bronze"))
		"rescue":
			if not cub["free"]:
				return
			# The cub follows you; foes near it hurt it.
			var to: Vector2 = p.global_position - cub["pos"]
			if to.length() > 46.0:
				var step: Vector2 = main.path_dir(cub["pos"], p.global_position) * float(cfg["speed"]) * delta
				var next: Vector2 = cub["pos"] + step
				if not main.is_solid(next):
					cub["pos"] = next
			for e in s["mobs"]:
				e.goal = cub["pos"]
				if e.global_position.distance_to(cub["pos"]) < float(cfg["near"]):
					cub["hp"] -= float(cfg["drain"]) * delta
			s["wave_t"] -= delta
			if s["wave_t"] <= 0.0:
				s["wave_t"] = float(cfg["wave_every"])
				for k in int(cfg["per_wave"]):
					var e = _spawn(s, 2.0)
					if e != null:
						e.goal = cub["pos"]
			if cub["hp"] <= 0.0:
				_finish(s, "none")
			elif cub["pos"].distance_to(s["start"]) < 40.0:
				var k: float = cub["hp"] / float(cfg["cub_hp"])
				_finish(s, "gold" if k >= float(cfg["gold"]) else ("silver" if k >= float(cfg["silver"]) else "bronze"))
		"gauntlet":
			if s["mobs"].is_empty():
				if s["wave"] >= int(cfg["waves"]):
					var par: float = float(cfg["par"]) + float(cfg["par_per_wave"]) * int(cfg["waves"])
					_finish(s, "gold" if s["t"] <= par else ("silver" if s["t"] <= par * float(cfg["silver_k"]) else "bronze"))
				else:
					s["wave"] += 1
					var budget: float = float(cfg["budget"]) + float(cfg["budget_per_floor"]) * main.floor_num
					while budget >= 1.0:
						var kind: String = main.Floors._pick(main.floor_num, budget, 99, main.tower_data().get("weights", {}))
						if kind == "":
							break
						budget -= float(main.Floors.MONSTERS[kind]["cost"])
						var e = _spawn(s, 0.0, kind)
						if e != null:
							e.wake()


## A lantern's light on the climber: in its cone, near enough, nothing in between.
func _spotted(s: Dictionary, p) -> bool:
	var cfg: Dictionary = SCENARIOS["unseen"]
	var t := Time.get_ticks_msec() / 1000.0
	for sn in s.get("sentries", []):
		var ang: float = sn["face"] + sin(t * float(cfg["speed"]) + sn["phase"]) * float(cfg["sweep"])
		var to: Vector2 = p.global_position - sn["pos"]
		if to.length() > float(cfg["reach"]):
			continue
		if absf(Vector2.from_angle(ang).angle_to(to)) > deg_to_rad(float(cfg["half_angle"])):
			continue
		if main.clear_line(sn["pos"], p.global_position) and not main.blocks_shot(p.global_position):
			return true
	return false


func _spawn(s: Dictionary, budget := 2.0, kind := ""):
	var spots: Array = s["spawns"]
	if spots.is_empty():
		return null
	var pos: Vector2 = spots[randi() % spots.size()]
	for k in 6:
		var q: Vector2 = spots[randi() % spots.size()]
		if q.distance_to(main.player.global_position) > pos.distance_to(main.player.global_position):
			pos = q
	if kind == "":
		kind = main.Floors._pick(main.floor_num, maxf(budget, 1.0), 99, main.tower_data().get("weights", {}))
	if kind == "":
		kind = "slime"
	var e = main.spawn_enemy(kind, pos)
	e.aware = true
	e.notice_t = 0.0
	main.floor_total += 1
	main.foes_changed()
	main.fx_burst(pos, Vector2.UP, Color(0.6, 0.5, 0.85), 12, 120.0)
	s["mobs"].append(e)
	return e


func _spawn_champion(s: Dictionary) -> void:
	var kind: String = String(main.tower_data().get("sentinel", "knight"))
	var e = main.EnemyScript.new()
	e.setup(kind, main)
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	e.max_hp *= tough.x
	e.dmg *= tough.y
	e.make_champion()
	e.max_hp *= float(SCENARIOS["duel"]["hp"]) / float(e.CHAMPION["hp"])  # (a fair fight: tough, not endless)
	e.hp = e.max_hp
	e.position = main.clear_spot(s["end"], e.radius)
	e.aware = true
	main.add_child(e)
	e.wake()
	main.floor_total += 1
	main.foes_changed()
	main.fx_ring(s["end"], Color(1.0, 0.82, 0.4), 70.0, 0.5, 4.0)
	s["mobs"].append(e)


## A strike (player.gd): breaks the cub's cage.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	if active.is_empty() or active["kind"] != "rescue" or active["state"] != "run" or cub.is_empty() or cub["free"]:
		return
	var to: Vector2 = cub["pos"] - from
	if to.length() > reach + 20.0 or absf(dir.angle_to(to)) > deg_to_rad(arc_deg + 15.0):
		return
	cub["cage"] -= 1
	main.fx_burst(cub["pos"], -to.normalized(), Color(0.6, 0.55, 0.5), 8, 120.0)
	main.sfx("hit_armor", 0.8, -4.0)
	if cub["cage"] <= 0:
		cub["free"] = true
		active["wave_t"] = 1.0
		main.fx_text(cub["pos"] + Vector2(0, -30), TEXT["rescue_free"], Color(0.7, 0.95, 0.6))
		main.sfx("glass_break", 0.8, -4.0)


func _finish(s: Dictionary, grade: String, why := "") -> void:
	s["state"] = "done"
	s["grade"] = grade
	_unseal()
	rocks.clear()
	for e in s.get("mobs", []):
		if is_instance_valid(e):
			e.goal = Vector2.INF
	active = {}
	results.append({"kind": s["kind"], "grade": grade})
	var th: Dictionary = main.Themes.get_theme("scn_" + String(s["kind"]))
	var g: Dictionary = GRADES[grade]
	if grade == "none":
		main.banner = {"title": String(th["name"]).to_upper(), "lines": [why if why != "" else TEXT["failed"]], "t": 2.5}
		main.sfx("puzzle_fail", 1.0, -4.0)
		return
	var kind: String = main.tower_data().get("essence", "air")
	var amount: float = float(g["essence"]) + float(g["per_floor"]) * main.floor_num
	main.gather_essence(kind, amount, main.player.global_position)
	var lines: Array = [TEXT["noticed_line"] % [th["name"], g["name"]]]
	if main.profile != null and int(g["renown"]) > 0:
		var r: Dictionary = Renown.earn(main.profile, int(g["renown"]), "%s (%s)" % [th["name"], g["name"]])
		lines.append(TEXT["renown"] % ("+%d" % int(g["renown"])))
		if String(r.get("rank_up", "")) != "":
			lines.append(String(r["rank_up"]))
	Makers.feed(main, "scenario", {"gold": 3.0, "silver": 2.0, "bronze": 1.0}[grade])
	main.note_noticed(String(s["kind"]), grade)
	main.banner = {"title": TEXT["noticed"] % main.beast_name().to_upper(), "lines": lines, "t": 3.0}
	main.sfx("puzzle_solve", 1.0, -2.0)
	main.fx_ring(main.player.global_position, Color(1.0, 0.85, 0.5), 80.0, 0.6, 4.0)


## A tower's own scenario's title (its floor script's words).
func status_title(s: Dictionary) -> String:
	var tf = main.get("tower_floor")
	return String(tf.scenario_title(s)) if tf != null else ""


## The scenario's line on the HUD: {title, line} or {}.
func status() -> Dictionary:
	if active.is_empty() or active["state"] != "run":
		return {}
	var s := active
	var cfg: Dictionary = SCENARIOS[s["kind"]]
	if cfg.has("module"):
		return main.tower_floor.scenario_status(s) if main.get("tower_floor") != null else {}
	match String(s["kind"]):
		"defend":
			return {"title": TEXT["defend"], "line": TEXT["defend_line"] % [int(100.0 * maxf(s["camp_hp"], 0.0) / float(cfg["camp_hp"])), maxi(0, int(ceil(float(cfg["time"]) - s["t"])))]}
		"collapse":
			return {"title": TEXT["collapse"], "line": TEXT["collapse_line"] % [s["hits"], maxi(0, int(ceil(s["limit"] - s["t"])))]}
		"duel":
			return {"title": TEXT["duel"], "line": TEXT["duel_line"] % s["hits"]}
		"unseen":
			return {"title": TEXT["unseen"], "line": TEXT["unseen_line"] % s["seen"]}
		"rescue":
			return {"title": TEXT["rescue_free"] if cub.get("free", false) else TEXT["rescue"], "line": TEXT["rescue_line"] % int(100.0 * maxf(cub.get("hp", 0.0), 0.0) / float(cfg["cub_hp"]))}
		"gauntlet":
			return {"title": TEXT["gauntlet"], "line": TEXT["gauntlet_line"] % [s["wave"], int(cfg["waves"]), int(s["t"])]}
	return {}


## Where the bot (or a test) should go next in the running scenario.
func goal_point() -> Vector2:
	if active.is_empty():
		return Vector2.INF
	if SCENARIOS[active["kind"]].has("module"):
		return main.tower_floor.scenario_goal(active) if main.get("tower_floor") != null else Vector2.INF
	match String(active["kind"]):
		"collapse", "unseen":
			return active["end"]
		"rescue":
			return cub["pos"] if not cub.get("free", false) else active["start"]
		"defend":
			return active["camp"]
	return Vector2.INF


# --- shutting the room ----------------------------------------------------------------

func _seal(s: Dictionary) -> void:
	_unseal()
	for g in s.get("gates", []):
		var r := Rect2(ORIGIN + Vector2(g[0]) * CELL, Vector2(CELL, CELL))
		for t in g:
			r = r.merge(Rect2(ORIGIN + Vector2(t) * CELL, Vector2(CELL, CELL)))
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = r.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size
		shape.shape = box
		body.add_child(shape)
		main.add_child(body)
		bodies.append({"body": body, "rect": r})
		main.fx_burst(r.get_center(), Vector2.ZERO, Color(0.55, 0.51, 0.6), 8, 100.0)
	main.sfx("slam", 0.7, -2.0)


func _unseal() -> void:
	for b in bodies:
		if is_instance_valid(b["body"]):
			b["body"].queue_free()
	bodies.clear()


# --- drawing --------------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for s in list:
		var gold := Color(1.0, 0.84, 0.45)
		if s["state"] == "idle":
			# The mark: a gilt ring with a star in it.
			draw_circle(s["start"], 20.0, Color(gold, 0.12 + 0.1 * pulse))
			draw_arc(s["start"], 20.0, 0.0, TAU, 32, Color(gold, 0.7), 2.5)
			for k in 6:
				var a := k * TAU / 6.0 + t * 0.4
				draw_line(s["start"] + Vector2.from_angle(a) * 6.0, s["start"] + Vector2.from_angle(a) * 15.0, Color(gold, 0.6), 2.0)
		elif s["state"] == "done":
			var col: Color = {"gold": gold, "silver": Color(0.85, 0.88, 0.95), "bronze": Color(0.85, 0.6, 0.4), "none": Color(0.4, 0.38, 0.42)}[s["grade"]]
			draw_arc(s["start"], 16.0, 0.0, TAU, 24, Color(col, 0.6), 2.0)
		if s["kind"] in ["collapse", "unseen"] and s["state"] != "done":
			draw_arc(s["end"], 22.0, 0.0, TAU, 32, Color(0.7, 0.95, 0.7, 0.5 + 0.3 * pulse), 2.5)
		match String(s["kind"]):
			"defend":
				_draw_camp(s, t)
			"unseen":
				_draw_sentries(s, t)
			"rescue":
				_draw_cub(s, t)
		for b in bodies:
			var r: Rect2 = b["rect"]
			draw_rect(r, Color(0.2, 0.18, 0.22))
			for k in 4:
				var x := r.position.x + (k + 0.5) * r.size.x / 4.0
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.55, 0.52, 0.58), 3.0)
	for r in rocks:
		var k: float = clampf(1.0 - r["t"] / float(SCENARIOS["collapse"]["warn"]), 0.0, 1.0)
		if r["t"] > 0.0:
			draw_arc(r["pos"], r["r"] * (1.0 - 0.5 * k), 0.0, TAU, 24, Color(1.0, 0.6, 0.4, 0.4 + 0.5 * k), 2.0)
			draw_circle(r["pos"], r["r"] * 0.3 * k, Color(0.2, 0.15, 0.12, 0.5))
		else:
			draw_circle(r["pos"], 9.0, Palette.WALL_TOP.lightened(0.15))


func _draw_camp(s: Dictionary, t: float) -> void:
	var c: Vector2 = s["camp"]
	draw_circle(c + Vector2(0, 6), 16.0, Color(0, 0, 0, 0.3))
	for k in 5:
		var a := k * TAU / 5.0
		draw_line(c + Vector2.from_angle(a) * 4.0, c + Vector2.from_angle(a) * 14.0, Color(0.4, 0.28, 0.18), 4.0)
	var alive: bool = s["state"] != "done" or s["grade"] != "none"
	if alive:
		var f := 0.6 + 0.4 * sin(t * 9.0)
		draw_circle(c + Vector2(0, -3), 6.0 + 2.0 * f, Color(1.0, 0.55, 0.2, 0.85))
		draw_circle(c + Vector2(0, -5), 3.0 + f, Color(1.0, 0.9, 0.5, 0.9))
	if s["state"] == "run":
		var k: float = clampf(s["camp_hp"] / float(SCENARIOS["defend"]["camp_hp"]), 0.0, 1.0)
		draw_rect(Rect2(c + Vector2(-20, -30), Vector2(40, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(c + Vector2(-20, -30), Vector2(40 * k, 5)), Color(1.0, 0.7, 0.3))


func _draw_sentries(s: Dictionary, t: float) -> void:
	var cfg: Dictionary = SCENARIOS["unseen"]
	for sn in s.get("sentries", []):
		var ang: float = sn["face"] + sin(t * float(cfg["speed"]) + sn["phase"]) * float(cfg["sweep"])
		var half := deg_to_rad(float(cfg["half_angle"]))
		var reach := float(cfg["reach"])
		if s["state"] != "done":
			var pts := PackedVector2Array([sn["pos"]])
			for k in 9:
				var a: float = ang - half + 2.0 * half * k / 8.0
				# (the light stops at walls)
				var far: Vector2 = sn["pos"] + Vector2.from_angle(a) * reach
				for step in range(1, 12):
					var q: Vector2 = sn["pos"] + Vector2.from_angle(a) * reach * step / 11.0
					if main.is_solid(q):
						far = q
						break
				pts.append(far)
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.5, 0.13))
		draw_circle(sn["pos"], 9.0, Palette.OUTLINE)
		draw_circle(sn["pos"], 7.0, Color(0.45, 0.4, 0.32))
		draw_circle(sn["pos"] + Vector2.from_angle(ang) * 3.0, 3.5, Color(1.0, 0.85, 0.5))


func _draw_cub(s: Dictionary, t: float) -> void:
	var at: Vector2 = cub.get("pos", s["cage"]) if not cub.is_empty() else s["cage"]
	var free: bool = cub.get("free", false)
	var saved: bool = s["state"] == "done" and s["grade"] != "none"
	if s["state"] == "done" and not saved and not cub.is_empty() and cub.get("hp", 1.0) <= 0.0:
		return
	# A small grey creature, all ears.
	var bob := sin(t * 6.0) * 1.5 if free else 0.0
	draw_circle(at + Vector2(0, 8), 9.0, Color(0, 0, 0, 0.3))
	draw_circle(at + Vector2(0, bob), 8.0, Color(0.62, 0.6, 0.64))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -4 + bob), at + Vector2(-9, -15 + bob), at + Vector2(-2, -7 + bob)]), Color(0.62, 0.6, 0.64))
	draw_colored_polygon(PackedVector2Array([at + Vector2(6, -4 + bob), at + Vector2(9, -15 + bob), at + Vector2(2, -7 + bob)]), Color(0.62, 0.6, 0.64))
	draw_circle(at + Vector2(-3, -1 + bob), 1.3, Palette.OUTLINE)
	draw_circle(at + Vector2(3, -1 + bob), 1.3, Palette.OUTLINE)
	if not free and not saved:
		# The cage: bars over it.
		draw_rect(Rect2(at + Vector2(-14, -18), Vector2(28, 30)), Color(0.3, 0.28, 0.3), false, 2.5)
		for k in 4:
			var x := at.x - 14.0 + (k + 0.5) * 7.0
			draw_line(Vector2(x, at.y - 18.0), Vector2(x, at.y + 12.0), Color(0.45, 0.42, 0.46), 2.0)
	if s["state"] == "run" and free:
		var k: float = clampf(cub["hp"] / float(SCENARIOS["rescue"]["cub_hp"]), 0.0, 1.0)
		draw_rect(Rect2(at + Vector2(-14, -24), Vector2(28, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(at + Vector2(-14, -24), Vector2(28 * k, 4)), Color(0.6, 0.95, 0.55))
