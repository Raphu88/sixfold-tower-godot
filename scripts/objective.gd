extends Node2D
## The floor's one task in play (objectives.gd has the kinds, their words
## and numbers, and plans where the pieces go). This node keeps each piece's
## state, draws it, ticks it, tells the HUD its line and where its arrow
## points, and when the task is done lifts the stair's ward (main.lift_ward):
## gold light at the stair, essence, and a reliquary beside the stair with a
## choice of one of three (a relic, gear, an item).
##
## A puzzle kind is run by puzzle.gd as before; this only follows it. When
## the floor's puzzle isn't the task, it's optional: solving it opens its
## vault (a vault's cards).

const Objectives := preload("res://scripts/objectives.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")

const GOLD := Color(1.0, 0.84, 0.45)
const WARD := Color(0.75, 0.55, 1.0)

var main
var spec := {}
var kind := ""
var done := false
var pieces: Array = []  # {pos, room, state ("todo", "doing", "done"), t, light, glyph...}
var tablet := {}  # runes: {pos, read}
var pedestal := Vector2.INF  # orb: where it goes
var carried := false  # orb: in your hands
var keeper = null  # the Keeper (an enemy)
var key := {}  # the Keeper's key on the floor: {pos}
var step := 0  # runes: how far along the order
var charge := 0.0  # wardstone: 0..1
var stone_awake := false
var wave_t := 0.0
var mobs: Array = []
var hp_seen := 0.0
var reliquary := {}  # after: {pos, taken, light}
var stair_light := -1
var target_t := 0.0
var target := []  # [pos, label]: what the arrow points at
var redraw_t := 0.0
var over: Node2D  # the marker over the arrow's target, over the darkness
var optional_done := false
var reach_lights: Array = []


func _ready() -> void:
	z_index = -2
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 58
	over.draw.connect(_draw_over)
	add_child(over)


## A new floor: the plan's task (or none).
func setup(s: Dictionary) -> void:
	clear()
	if s.is_empty() or main == null:
		return
	spec = s
	kind = String(s["kind"])
	hp_seen = main.player.hp if main.player != null else 0.0
	if s.get("puzzle", false):
		return  # (puzzle.gd runs it)
	for p in s.get("pieces", []):
		var pc: Dictionary = p.duplicate()
		pc["state"] = "todo"
		pc["t"] = 0.0
		pc["home"] = pc["pos"]
		pieces.append(pc)
	if s.has("tablet"):
		tablet = {"pos": s["tablet"]["pos"], "read": false}
	pedestal = s.get("pedestal", Vector2.INF)
	for pc in pieces:
		pc["light"] = _light(pc["pos"], 90.0, _piece_color(), 0.45)
	if not tablet.is_empty():
		tablet["light"] = _light(tablet["pos"], 80.0, GOLD, 0.4)
	if pedestal != Vector2.INF:
		reach_lights.append(_light(pedestal, 80.0, GOLD, 0.4))
	if kind == "keeper":
		_spawn_keeper()
	queue_redraw()


func clear() -> void:
	if main != null and main.lighting != null:
		for pc in pieces:
			if pc.has("light"):
				main.lighting.remove_light(pc["light"])
		if tablet.has("light"):
			main.lighting.remove_light(tablet["light"])
		for id in reach_lights:
			main.lighting.remove_light(id)
		if reliquary.has("light"):
			main.lighting.remove_light(reliquary["light"])
		if stair_light >= 0:
			main.lighting.remove_light(stair_light)
	reach_lights.clear()
	stair_light = -1
	spec = {}
	kind = ""
	done = false
	pieces.clear()
	tablet = {}
	pedestal = Vector2.INF
	carried = false
	keeper = null
	key = {}
	step = 0
	charge = 0.0
	stone_awake = false
	mobs.clear()
	reliquary = {}
	target = []
	optional_done = false
	queue_redraw()


func _light(pos: Vector2, reach: float, col: Color, strength: float) -> int:
	if main.lighting == null:
		return -1
	return main.lighting.add_light(pos, reach, col, strength, 0.2)


func _drop_light(pc: Dictionary) -> void:
	if pc.has("light") and main.lighting != null:
		main.lighting.remove_light(pc["light"])
		pc.erase("light")


## True while the stair is still warded by it.
func active() -> bool:
	if kind == "" or done:
		return false
	if spec.get("puzzle", false):
		return main.puzzle != null and main.puzzle.active()
	return true


func _k() -> Dictionary:
	return Objectives.KINDS.get(kind, {})


func _piece_color() -> Color:
	match kind:
		"braziers":
			return Color(1.0, 0.6, 0.3)
		"runes", "orb", "keeper", "shards":
			return GOLD
		"wardstone":
			return WARD
		"motes":
			return Essence.color(main.tower_data().get("essence", "air"))
	return GOLD


func done_count() -> int:
	return pieces.filter(func(pc): return pc["state"] == "done").size()


# --- the HUD ------------------------------------------------------------------------

## The HUD's line ("" when there's nothing to say).
func status_line() -> String:
	if kind == "":
		return ""
	if done:
		return ""
	if spec.get("puzzle", false):
		if main.puzzle == null or not main.puzzle.active():
			return ""
		var pname: String = main.puzzle.display_name()
		if pname.begins_with("The "):
			pname = pname.substr(4)  # ("Solve the Ice Hall", not "the The")
		return Objectives.TEXT["puzzle_status"] % pname
	var k := _k()
	match kind:
		"runes":
			if not tablet.get("read", false):
				return String(k["status_read"])
			var nxt: Dictionary = pieces[spec["order"][step]] if step < pieces.size() else {}
			return String(k["status_next"]) % [nxt.get("glyph", ""), step, pieces.size()]
		"orb":
			return String(k["status_held"]) if carried else String(k["status"])
		"keeper":
			return String(k["status_key"]) if not key.is_empty() else String(k["status"])
		"wardstone":
			return String(k["status_wake"]) if not stone_awake else String(k["status"]) % int(charge * 100.0)
	return String(k["status"]) % [done_count(), pieces.size()]


## The banner's lines on arrival: the task's name and how.
func banner_lines() -> Array:
	if kind == "":
		return []
	return [String(spec.get("name", "")), String(spec.get("hint", ""))]


## What the arrow points at: [pos, label] (the nearest piece still to do),
## or [] (none: then the HUD points at the stair once it opens).
func arrow_target() -> Array:
	if kind == "" or done or main.player == null:
		return []
	target_t -= get_process_delta_time()
	if target_t > 0.0 and not target.is_empty():
		return target
	target_t = 0.4
	target = _find_target()
	return target


func _find_target() -> Array:
	var k := _k()
	var from: Vector2 = main.player.global_position
	if spec.get("puzzle", false):
		if main.puzzle == null or not main.puzzle.active():
			return []
		return [main.puzzle.room.get_center(), main.puzzle.display_name()]
	match kind:
		"runes":
			if not tablet.get("read", false):
				return [tablet["pos"], String(k["tablet"])]
			if step < pieces.size():
				var pc: Dictionary = pieces[spec["order"][step]]
				return [pc["pos"], String(pc.get("glyph", k["piece"]))]
			return []
		"orb":
			if carried:
				return [pedestal, String(k["pedestal"])]
			return [pieces[0]["pos"], String(k["piece"])]
		"keeper":
			if not key.is_empty():
				return [key["pos"], String(k["key"])]
			if keeper != null and is_instance_valid(keeper) and not keeper.dead:
				return [keeper.global_position, String(k["piece"])]
			return [pieces[0]["pos"], String(k["piece"])]
	var best := []
	var best_d := INF
	for pc in pieces:
		if pc["state"] == "done":
			continue
		var d := _path_len(from, pc["pos"])
		if d < best_d:
			best_d = d
			best = [pc["pos"], String(k.get("piece", ""))]
	return best


## How far to walk (px), around the walls.
func _path_len(a: Vector2, b: Vector2) -> float:
	if main.astar == null or not main.layout_on:
		return a.distance_to(b)
	var ta: Vector2i = main._tile_of(a)
	var tb: Vector2i = main._tile_of(b)
	if main._is_solid_tile(ta.x, ta.y) or main._is_solid_tile(tb.x, tb.y):
		return a.distance_to(b) * 1.5
	var pts: PackedVector2Array = main.astar.get_point_path(ta, tb)
	if pts.size() < 2:
		return a.distance_to(b) * 3.0
	return float(pts.size()) * 40.0


## Every place the climber still has to reach (reach.gd's live check).
func live_targets() -> Array:
	var out: Array = []
	if kind == "" or done or spec.get("puzzle", false):
		return out
	match kind:
		"runes":
			if not tablet.get("read", false):
				out.append(tablet["pos"])
		"orb":
			if not carried:
				out.append(pieces[0]["pos"])
			out.append(pedestal)
			return out
		"keeper":
			if not key.is_empty():
				out.append(key["pos"])
			elif keeper != null and is_instance_valid(keeper) and not keeper.dead:
				out.append(keeper.global_position)
			return out
	for pc in pieces:
		if pc["state"] != "done":
			out.append(pc["pos"])
	return out


# --- running ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or main.player == null or kind == "":
		return
	var p = main.player
	var hurt: bool = p.hp < hp_seen - 0.5
	hp_seen = p.hp
	if not done and not spec.get("puzzle", false) and not p.dead and not main.climbing:
		_tick(delta, p, hurt)
	if not reliquary.is_empty() and not reliquary["taken"] and not p.dead and not main.climbing \
			and p.global_position.distance_to(reliquary["pos"]) < 30.0 + p.radius and not main.camp_choosing:
		_open_reliquary()
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()
		over.queue_redraw()


func _tick(delta: float, p, hurt: bool) -> void:
	var k := _k()
	var pos: Vector2 = p.global_position
	match kind:
		"braziers":
			for pc in pieces:
				if pc["state"] == "done":
					continue
				if pos.distance_to(pc["pos"]) < float(k["reach"]):
					if hurt and pc["t"] > 0.0:
						pc["t"] = 0.0
						main.fx_text(pc["pos"] + Vector2(0, -30), Objectives.TEXT["snuffed"], Color(0.8, 0.7, 0.6))
					pc["state"] = "doing"
					pc["t"] += delta
					if pc["t"] >= float(k["light_time"]):
						_piece_done(pc)
						if main.lighting != null:
							pc["light"] = main.lighting.add_light(pc["pos"], 190.0, Color(1.0, 0.62, 0.3), 0.8, 0.4)
				elif pc["state"] == "doing":
					pc["state"] = "todo"
					pc["t"] = maxf(0.0, pc["t"] - delta * 2.0)
		"runes":
			if not tablet["read"] and pos.distance_to(tablet["pos"]) < 34.0 + p.radius:
				tablet["read"] = true
				var names: Array = spec["order"].map(func(i): return pieces[i]["glyph"])
				main.banner = {"title": String(k["tablet"]).to_upper(), "lines": [Objectives.TEXT["read"] % ", ".join(names)], "t": 3.5, "inscribed": true}
				main.sfx("glint", 1.1, -4.0)
			for i in pieces.size():
				var pc: Dictionary = pieces[i]
				var on := pos.distance_to(pc["pos"]) < 20.0
				if on and not pc.get("under", false) and pc["state"] != "done":
					if not tablet["read"]:
						pass  # (nothing happens until the order is known)
					elif i == int(spec["order"][step]):
						step += 1
						_piece_done(pc)
					else:
						_wrong_rune()
				pc["under"] = on
		"levers":
			for pc in pieces:
				if pc["state"] == "done":
					pc["t"] -= delta
					if pc["t"] <= 0.0 and not done:
						pc["state"] = "todo"
						main.fx_text(pc["pos"] + Vector2(0, -30), Objectives.TEXT["lever_fell"], Color(0.85, 0.75, 0.6))
						main.sfx("slam", 1.3, -8.0)
			if done_count() == pieces.size():
				_complete()
				return
		"orb":
			var orb: Dictionary = pieces[0]
			if carried:
				orb["pos"] = pos + Vector2(0, -28)
				if hurt:
					carried = false
					orb["pos"] = main.walkable_point(pos, pos + Vector2(randf_range(-30, 30), 24.0))
					main.fx_text(pos + Vector2(0, -40), Objectives.TEXT["dropped"], Color(1.0, 0.8, 0.5))
					main.sfx("glass_break", 1.2, -6.0)
				elif pos.distance_to(pedestal) < 30.0 + p.radius:
					carried = false
					orb["pos"] = pedestal + Vector2(0, -14)
					_piece_done(orb)
				if orb.has("light") and main.lighting != null:
					main.lighting.move_light(orb["light"], orb["pos"])
			elif orb["state"] != "done" and pos.distance_to(orb["pos"]) < 24.0 + p.radius and not hurt:
				carried = true
				main.sfx("pickup", 0.8, -2.0)
		"keeper":
			if not key.is_empty() and pos.distance_to(key["pos"]) < 24.0 + p.radius:
				key = {}
				_piece_done(pieces[0])
		"wardstone":
			var st: Dictionary = pieces[0]
			if not stone_awake:
				if pos.distance_to(st["pos"]) < 60.0 + p.radius:
					stone_awake = true
					wave_t = 1.5
					main.fx_text(st["pos"] + Vector2(0, -50), Objectives.TEXT["stone_wakes"], WARD)
					main.sfx("ready", 0.7, -2.0)
					main.shake(3.0)
				return
			mobs = mobs.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
			var blocked := false
			for e in main.enemies():
				if e.global_position.distance_to(st["pos"]) < float(k["near"]):
					blocked = true
					break
			if not blocked:
				charge = minf(1.0, charge + delta / float(spec.get("charge", 30.0)))
			wave_t -= delta
			var most: int = int(k["alive_base"]) + main.floor_num / int(k["alive_per_floors"])
			if wave_t <= 0.0:
				wave_t = float(k["wave_every"])
				if mobs.size() < most:
					var e = _spawn_near(st["pos"], 200.0)
					if e != null:
						e.goal = st["pos"]
						mobs.append(e)
			if charge >= 1.0:
				for e in mobs:
					if is_instance_valid(e):
						e.goal = Vector2.INF
				_piece_done(st)
		"shards":
			for pc in pieces:
				if pc["state"] != "done" and pos.distance_to(pc["pos"]) < 22.0 + p.radius:
					_piece_done(pc)
		"motes":
			var flee := float(k["flee"])
			var spd: float = p.WALK * float(k["speed"]) if "WALK" in p else 100.0
			for pc in pieces:
				if pc["state"] == "done":
					continue
				var to: Vector2 = pc["pos"] - pos
				if to.length() < 22.0 + p.radius:
					_piece_done(pc)
					continue
				var v := Vector2.ZERO
				if to.length() < flee:
					v = to.normalized() * spd
				else:
					# drift home, slowly
					var home: Vector2 = pc["home"] - pc["pos"]
					if home.length() > 8.0:
						v = home.normalized() * spd * 0.3
				v += Vector2.from_angle(Time.get_ticks_msec() * 0.002 + pc["pos"].x) * 14.0
				var next: Vector2 = pc["pos"] + v * delta
				var room_r: Rect2 = main.room_info[pc["room"]]["rect"] if pc["room"] < main.room_info.size() else main.room
				if not main.is_solid(next) and room_r.grow(-14.0).has_point(next) and not _near_wall(next):
					pc["pos"] = next
				elif v != Vector2.ZERO:
					# slide along a wall
					for alt in [Vector2(v.x, 0), Vector2(0, v.y)]:
						var q: Vector2 = pc["pos"] + alt * delta
						if not main.is_solid(q) and room_r.grow(-14.0).has_point(q) and not _near_wall(q):
							pc["pos"] = q
							break
				if pc.has("light") and main.lighting != null:
					main.lighting.move_light(pc["light"], pc["pos"])
	if not done and kind != "levers" and done_count() == pieces.size() and not pieces.is_empty():
		_complete()


func _near_wall(q: Vector2) -> bool:
	for d in [Vector2(12, 0), Vector2(-12, 0), Vector2(0, 12), Vector2(0, -12)]:
		if main.is_solid(q + d):
			return true
	return false


func _piece_done(pc: Dictionary) -> void:
	pc["state"] = "done"
	_drop_light(pc)
	if kind == "levers":
		pc["t"] = float(spec.get("hold", 20.0))
	main.fx_ring(pc["pos"], _piece_color(), 50.0, 0.4, 3.0)
	main.fx_burst(pc["pos"], Vector2.UP, _piece_color(), 10, 120.0)
	main.sfx("glint", 1.0 + 0.1 * done_count(), -3.0)
	target_t = 0.0


func _wrong_rune() -> void:
	step = 0
	for pc in pieces:
		pc["state"] = "todo"
	main.banner = {"title": String(spec.get("name", "")).to_upper(), "lines": [Objectives.TEXT["wrong"]], "t": 2.5}
	main.sfx("puzzle_fail", 1.0, -4.0)
	main.shake(4.0)
	for k in int(_k().get("wrong_guards", 2)):
		var e = _spawn_near(main.player.global_position, 160.0)
		if e != null:
			e.wake()


func _spawn_near(at: Vector2, dist: float):
	var best := Vector2.INF
	for tries in 24:
		var q: Vector2 = at + Vector2.from_angle(randf() * TAU) * randf_range(dist * 0.6, dist)
		if main.is_solid(q) or not main.clear_line(at, q):
			continue
		if main.player != null and q.distance_to(main.player.global_position) < 110.0:
			continue
		best = q
		break
	if best == Vector2.INF:
		return null
	var kind_e: String = main.Floors._pick(main.floor_num, 2.0, 99, main.tower_data().get("weights", {}))
	if kind_e == "":
		kind_e = "slime"
	var e = main.spawn_enemy(kind_e, best)
	e.aware = true
	e.notice_t = 0.0
	main.floor_total += 1
	main.foes_changed()
	main.fx_burst(best, Vector2.UP, Color(0.6, 0.5, 0.85), 12, 120.0)
	return e


## A melee swing (player.gd): strikes a lever up.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	if kind != "levers" or done:
		return
	for pc in pieces:
		if pc["state"] == "done":
			continue
		var to: Vector2 = pc["pos"] - from
		if to.length() > reach + 22.0 or absf(dir.angle_to(to)) > deg_to_rad(arc_deg + 20.0):
			continue
		_piece_done(pc)
		main.sfx("slam", 0.9, -4.0)
		main.shake(2.0)


func _spawn_keeper() -> void:
	var at: Vector2 = pieces[0]["pos"]
	var kinds: Array = ["knight"]
	var tw: Dictionary = main.tower_data()
	if String(tw.get("sentinel", "")) != "":
		kinds = [tw["sentinel"]]
	var e = main.EnemyScript.new()
	e.setup(kinds[0], main)
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	e.max_hp *= tough.x
	e.dmg *= tough.y
	e.make_champion()
	e.max_hp *= 0.7  # (tougher than its guards, not a wall)
	e.hp = e.max_hp
	e.position = main.clear_spot(at, e.radius)
	e.aware = false
	e.set_meta("keeper", true)
	main.add_child(e)
	main.floor_total += 1
	main.foes_changed()
	keeper = e


## A monster fell (main.gd): the Keeper drops the stair's key.
func on_enemy_killed(e) -> void:
	if kind == "keeper" and e == keeper:
		key = {"pos": main.walkable_point(e.global_position, e.global_position)}
		keeper = null
		main.fx_text(key["pos"] + Vector2(0, -40), Objectives.TEXT["keeper_falls"], GOLD)
		main.sfx("glint", 0.9, -2.0)
		target_t = 0.0


## The floor's puzzle was solved (puzzle.gd): the task, or its own vault.
func puzzle_solved(host) -> void:
	if spec.get("puzzle", false) and not done:
		_complete()
		return
	if optional_done:
		return
	optional_done = true
	var at: Vector2 = host.room.get_center()
	if not host.rewards.is_empty():
		at = host.rewards[0]
	main.fx_text(at + Vector2(0, -40), Objectives.TEXT["optional_vault"], GOLD)
	main.offer_vault(main.wings.vault_choices(false), String(host.display_name()).to_upper(), [Objectives.TEXT["optional_vault"]])
	main.MakersScript.feed(main, "puzzle")


func _complete() -> void:
	if done:
		return
	done = true
	target = []
	for e in mobs:
		if is_instance_valid(e):
			e.goal = Vector2.INF
	main.lift_ward()


## The ward is lifted (main.gd lift_ward calls this): the stair's gold
## light, its essence and the reliquary beside it.
func reward() -> void:
	if main.lighting != null and stair_light < 0:
		stair_light = main.lighting.add_light(main.stair_pos + Vector2(0, -10), float(Objectives.REWARD["light"]), GOLD, 0.95, 0.6)
	var kind_e: String = main.tower_data().get("essence", "air")
	var amount: float = float(Objectives.REWARD["essence"]) + float(Objectives.REWARD["per_floor"]) * main.floor_num
	main.gather_essence(kind_e, amount, main.stair_pos)
	var at: Vector2 = main.clear_spot(main.stair_pos + Vector2(70.0, 60.0), 16.0)
	if main.is_solid(at) or not main.clear_line(main.stair_pos + Vector2(0, 30), at):
		at = main.clear_spot(main.stair_pos + Vector2(-70.0, 60.0), 16.0)
	reliquary = {"pos": at, "taken": false}
	if main.lighting != null:
		reliquary["light"] = main.lighting.add_light(at, 100.0, GOLD, 0.7, 0.3)
	main.fx_ring(main.stair_pos, GOLD, 90.0, 0.7, 5.0)
	main.fx_burst(main.stair_pos, Vector2.UP, GOLD, 24, 220.0)
	main.light_flash(main.stair_pos, GOLD, 2.4, 2.0, 0.6)


func _open_reliquary() -> void:
	reliquary["taken"] = true
	if reliquary.has("light") and main.lighting != null:
		main.lighting.remove_light(reliquary["light"])
		reliquary.erase("light")
	main.offer_vault(reliquary_choices(), Objectives.TEXT["reliquary_title"], [Objectives.TEXT["reliquary_sub"]])


## The reliquary's cards: a relic (a ring or an amulet), a piece of gear and an item.
func reliquary_choices() -> Array:
	var out: Array = []
	var bases: Array = Gear.PIECE_ORDER.filter(func(b): return Gear.slot_of(b) in ["ring", "amulet"])
	if not bases.is_empty():
		var b: String = bases[randi() % bases.size()]
		var r := Gear.natural_rarity(b)
		if Gear.rarity_rank(r) < Gear.rarity_rank("fine"):
			r = "fine"
		out.append("gear:" + Gear.code(Gear.make(b, r, Gear.roll_traits(b, r))))
	out.append("gear:" + main.wings.better_gear())
	out.append(Items.random_item(not main.player.bonds.is_empty()))
	return out


# --- drawing --------------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	if not reliquary.is_empty():
		_draw_reliquary(reliquary["pos"], reliquary["taken"], pulse)
	if kind == "" or spec.get("puzzle", false):
		return
	match kind:
		"braziers":
			for pc in pieces:
				_draw_brazier(pc, t)
		"runes":
			_draw_tablet(t)
			for i in pieces.size():
				_draw_rune(pieces[i], t)
		"levers":
			for pc in pieces:
				_draw_lever(pc, t)
		"orb":
			_draw_pedestal(pedestal, pieces[0]["state"] == "done")
			if pieces[0]["state"] != "done":
				_draw_orb(pieces[0]["pos"], t)
			else:
				_draw_orb(pedestal + Vector2(0, -14), t)
		"keeper":
			if not key.is_empty():
				_draw_key(key["pos"], t)
		"wardstone":
			_draw_stone(pieces[0], t)
		"shards":
			for pc in pieces:
				if pc["state"] != "done":
					_draw_shard(pc["pos"], t)
		"motes":
			for pc in pieces:
				if pc["state"] != "done":
					var col := _piece_color()
					draw_circle(pc["pos"], 9.0 + pulse * 2.0, Color(col, 0.25))
					draw_circle(pc["pos"], 5.0, Color(col.lightened(0.3), 0.95))


## The gold chevron over the arrow's target, over the darkness.
func _draw_over() -> void:
	if target.is_empty() or done:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var at: Vector2 = target[0] + Vector2(0, -34.0 - 4.0 * sin(t * 4.0))
	var pts := PackedVector2Array([at + Vector2(-8, -6), at, at + Vector2(8, -6)])
	over.draw_polyline(pts, Color(0, 0, 0, 0.6), 5.0)
	over.draw_polyline(pts, GOLD, 2.5)


func _draw_brazier(pc: Dictionary, t: float) -> void:
	var c: Vector2 = pc["pos"]
	draw_circle(c + Vector2(0, 10), 12.0, Color(0, 0, 0, 0.3))
	draw_line(c + Vector2(-8, 12), c + Vector2(0, 0), Palette.OUTLINE, 3.0)
	draw_line(c + Vector2(8, 12), c + Vector2(0, 0), Palette.OUTLINE, 3.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -4), c + Vector2(13, -4), c + Vector2(8, 4), c + Vector2(-8, 4)]), Color(0.32, 0.3, 0.34))
	draw_line(c + Vector2(-13, -4), c + Vector2(13, -4), Color(0.55, 0.52, 0.56), 2.0)
	if pc["state"] == "done":
		var f := 0.6 + 0.4 * sin(t * 10.0 + c.x)
		draw_circle(c + Vector2(0, -9), 7.0 + 2.0 * f, Color(1.0, 0.5, 0.18, 0.9))
		draw_circle(c + Vector2(0, -12), 4.0 + f, Color(1.0, 0.88, 0.5, 0.95))
	else:
		draw_circle(c + Vector2(0, -5), 3.0, Color(0.25, 0.2, 0.2))
		if pc["t"] > 0.0:
			var k: float = clampf(pc["t"] / float(_k()["light_time"]), 0.0, 1.0)
			draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, Color(1.0, 0.65, 0.3, 0.9), 3.0)
			draw_circle(c + Vector2(0, -8), 2.0 + 4.0 * k, Color(1.0, 0.55, 0.2, 0.7))


func _draw_tablet(t: float) -> void:
	if tablet.is_empty():
		return
	var c: Vector2 = tablet["pos"]
	draw_rect(Rect2(c + Vector2(-13, -18), Vector2(26, 26)), Palette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-11, -16), Vector2(22, 22)), Color(0.42, 0.4, 0.44))
	for i in 3:
		draw_line(c + Vector2(-7, -11 + i * 6), c + Vector2(7, -11 + i * 6), Color(GOLD, 0.6 if tablet["read"] else 0.9), 1.5)
	if not tablet["read"]:
		draw_arc(c, 22.0, 0.0, TAU, 24, Color(GOLD, 0.3 + 0.3 * sin(t * 3.0)), 2.0)


func _draw_rune(pc: Dictionary, t: float) -> void:
	var c: Vector2 = pc["pos"]
	var lit: bool = pc["state"] == "done"
	var col := GOLD if lit else Color(0.6, 0.56, 0.5)
	draw_circle(c, 17.0, Color(0, 0, 0, 0.25))
	draw_arc(c, 16.0, 0.0, TAU, 28, Color(col, 0.9), 2.0)
	_glyph(c, String(pc.get("glyph", "")), col)
	if lit:
		draw_circle(c, 16.0, Color(GOLD, 0.15 + 0.1 * sin(t * 4.0)))


## A rune's sign, drawn in lines.
func _glyph(c: Vector2, g: String, col: Color) -> void:
	match g:
		"Sun":
			draw_arc(c, 5.0, 0.0, TAU, 16, col, 2.0)
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c + Vector2.from_angle(a) * 7.0, c + Vector2.from_angle(a) * 11.0, col, 1.5)
		"Moon":
			draw_arc(c, 9.0, PI * 0.35, PI * 1.65, 18, col, 2.0)
			draw_arc(c + Vector2(4, 0), 7.0, PI * 0.5, PI * 1.5, 14, col, 1.5)
		"Star":
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU * 2.0 / 5.0) * 10.0)
			draw_polyline(pts, col, 2.0)
		"Wave":
			var pts2 := PackedVector2Array()
			for k in 9:
				pts2.append(c + Vector2(-10 + k * 2.5, sin(k * 1.1) * 4.0))
			draw_polyline(pts2, col, 2.0)
		"Eye":
			draw_arc(c + Vector2(0, 5), 10.0, PI * 1.2, PI * 1.8, 12, col, 2.0)
			draw_arc(c + Vector2(0, -5), 10.0, PI * 0.2, PI * 0.8, 12, col, 2.0)
			draw_circle(c, 2.5, col)
		_:
			draw_arc(c + Vector2(0, -4), 4.0, 0.0, TAU, 12, col, 2.0)
			draw_line(c + Vector2(0, 0), c + Vector2(0, 10), col, 2.0)
			draw_line(c + Vector2(0, 6), c + Vector2(4, 6), col, 2.0)


func _draw_lever(pc: Dictionary, t: float) -> void:
	var c: Vector2 = pc["pos"]
	var up: bool = pc["state"] == "done"
	draw_rect(Rect2(c + Vector2(-10, 2), Vector2(20, 10)), Palette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-8, 4), Vector2(16, 6)), Color(0.38, 0.35, 0.38))
	var tip := c + (Vector2(-6, -18) if up else Vector2(10, -6))
	draw_line(c + Vector2(0, 4), tip, Palette.OUTLINE, 5.0)
	draw_line(c + Vector2(0, 4), tip, Color(0.6, 0.5, 0.35), 3.0)
	draw_circle(tip, 4.0, GOLD if up else Color(0.6, 0.3, 0.25))
	if up:
		var k: float = clampf(pc["t"] / float(spec.get("hold", 20.0)), 0.0, 1.0)
		draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, Color(GOLD, 0.8), 2.5)


func _draw_pedestal(c: Vector2, filled: bool) -> void:
	if c == Vector2.INF:
		return
	draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 18)), Palette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 14)), Color(0.45, 0.42, 0.46))
	draw_rect(Rect2(c + Vector2(-13, -9), Vector2(26, 5)), Color(0.55, 0.52, 0.56))
	if not filled:
		draw_arc(c + Vector2(0, -12), 7.0, 0.0, TAU, 16, Color(GOLD, 0.6), 1.5)


func _draw_orb(c: Vector2, t: float) -> void:
	draw_circle(c, 10.0 + sin(t * 4.0), Color(1.0, 0.8, 0.35, 0.3))
	draw_circle(c, 7.0, Color(1.0, 0.86, 0.5))
	draw_circle(c + Vector2(-2, -2), 3.0, Color(1.0, 0.98, 0.85))


func _draw_key(c: Vector2, t: float) -> void:
	var bob := sin(t * 4.0) * 2.0
	draw_arc(c + Vector2(-5, bob), 4.0, 0.0, TAU, 12, GOLD, 2.5)
	draw_line(c + Vector2(-1, bob), c + Vector2(9, bob), GOLD, 2.5)
	draw_line(c + Vector2(6, bob), c + Vector2(6, 4 + bob), GOLD, 2.0)
	draw_line(c + Vector2(9, bob), c + Vector2(9, 4 + bob), GOLD, 2.0)


func _draw_stone(pc: Dictionary, t: float) -> void:
	var c: Vector2 = pc["pos"]
	draw_circle(c + Vector2(0, 14), 18.0, Color(0, 0, 0, 0.3))
	var pts := PackedVector2Array([c + Vector2(-12, 14), c + Vector2(-9, -26), c + Vector2(0, -34), c + Vector2(9, -26), c + Vector2(12, 14)])
	draw_colored_polygon(pts, Color(0.36, 0.33, 0.42))
	draw_polyline(pts, Palette.OUTLINE, 2.0)
	var col := WARD if stone_awake or pc["state"] == "done" else Color(0.5, 0.45, 0.6)
	for i in 3:
		draw_line(c + Vector2(-5, -20 + i * 10), c + Vector2(5, -16 + i * 10), col, 2.0)
	if stone_awake and pc["state"] != "done":
		draw_arc(c, 34.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, Color(WARD, 0.9), 4.0)
		draw_arc(c, float(_k()["near"]), 0.0, TAU, 40, Color(WARD, 0.15 + 0.1 * sin(t * 3.0)), 2.0)


func _draw_shard(c: Vector2, t: float) -> void:
	var bob := sin(t * 3.0 + c.x) * 2.0
	var pts := PackedVector2Array([c + Vector2(0, -12 + bob), c + Vector2(6, bob), c + Vector2(0, 8 + bob), c + Vector2(-6, bob)])
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.5, 0.9))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.OUTLINE, 1.5)


func _draw_reliquary(c: Vector2, taken: bool, pulse: float) -> void:
	draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 20)), Palette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 16)), Color(0.5, 0.44, 0.34))
	draw_rect(Rect2(c + Vector2(-15, -11), Vector2(30, 5)), Color(0.75, 0.62, 0.38))
	if not taken:
		draw_circle(c + Vector2(0, -18), 6.0 + pulse * 1.5, Color(GOLD, 0.85))
		draw_arc(c, 26.0, 0.0, TAU, 28, Color(GOLD, 0.25 + 0.3 * pulse), 2.0)
