extends Node
## The floor bot: plays a floor of rooms the way a player would, to prove
## every floor can be finished. It drives the real game through the same
## inputs a controller gives (Input actions: the left stick to walk, the
## right stick to aim, Attack, Jump, the weapon keys), once per physics tick,
## before the climber reads them. It walks by path around the walls (closed
## doors open as it walks up), fights what comes for it with normal
## attacks, does the floor's task (objective.gd) piece by piece, solves the
## puzzle when the task is a puzzle (using what the puzzle's own generator
## knows: the answer plate, the mirrors' turns, the path over the stones,
## the slides on the ice...), then walks to the stair.
## Used by tests/parts/floor_bot.gd (a few floors) and tests/floor_bot_sweep.gd.

const CELL := 40.0
const Objectives := preload("res://scripts/objectives.gd")

var main
var done := false
var result := {}
var t_game := 0.0
var limit := 300.0
var floor0 := 0
var why := ""  # what it's doing (for a failure's report)
var log_lines: Array = []
var last_step := {}
var no_lure := {}  # monsters that wouldn't come to the plate
var lure_mon = null
var lure_t := 0.0

# Walking
var astar: AStarGrid2D
var grid := Vector2i.ZERO
var path: PackedVector2Array = PackedVector2Array()
var path_goal := Vector2.INF
var path_t := 0.0
var avoid: Dictionary = {}  # tiles to keep off (other runes, sparks, marks, ice, stones)
var blocked: Dictionary = {}  # tiles found shut (a door barred from this side)
var last_pos := Vector2.ZERO
var still_t := 0.0
var stuck_n := 0
var nudge := Vector2.ZERO
var nudge_t := 0.0

# Fighting
var foe = null
var foe_t := 0.0
var foe_hp := 0.0
var foe_hit_t := 0.0
var foe_dry := 0.0
var ignore: Dictionary = {}  # enemy -> until
var attack_cd := 0.0
var swing_hold := 0  # ticks to keep attack held (a bow's draw)
var swing_release := false

# Precise moves (ice, stones, pushing blocks): a list of steps
var steps: Array = []
var step_t := 0.0
var step_hp := 0.0

# Counters for the report
var fights := 0
var hits_taken := 0
var close_calls := 0
var hp_seen := 0.0
var last_move := Vector2.ZERO  # (the stick, for a fall's report)
var last_knock := Vector2.ZERO
var trail: Array = []
var stick_raw := false  # (the next move keeps its strength: bracing against the wind)


func start(m, max_time := 300.0) -> void:
	main = m
	limit = max_time
	floor0 = main.floor_num
	process_physics_priority = -100  # (before the climber reads its input)
	done = false
	result = {}
	t_game = 0.0
	main.player.stick_aim = true
	main.player.mouse_aim = false
	main.player.touch_aim = false
	hp_seen = main.player.hp
	_equip("melee")


func _finish(ok: bool, reason: String) -> void:
	if done:
		return
	done = true
	_release_all()
	if not ok:
		log_lines.append(_diagnose())
	result = {"ok": ok, "why": reason, "time": t_game, "floor": floor0, "kind": main.objective.kind if main.objective != null else "",
		"fights": fights, "hits": hits_taken, "close_calls": close_calls, "log": log_lines.slice(-8)}


## Why a floor wasn't finished: where we stand, what we were after, and
## whether a way there exists (with the doors as they are, and with every
## door open), so a failure tells a bot's fault from the floor's.
func _diagnose() -> String:
	var p = main.player
	var pos: Vector2 = p.global_position
	var at: Vector2 = last_step.get("pos", main.stair_pos)
	_build_grid()
	var a := _tile(pos)
	var b := _tile(at)
	var ours := astar.get_id_path(a, b).size() if astar.region.has_point(a) and astar.region.has_point(b) else -1
	for d in main.door_view.list:
		for t in d["tiles"]:
			astar.set_point_solid(t, false)
	for t in avoid:
		astar.set_point_solid(t, main.astar.is_point_solid(t))
	var open := astar.get_id_path(a, b).size() if astar.region.has_point(a) and astar.region.has_point(b) else -1
	var foe_s := ""
	if foe != null and is_instance_valid(foe):
		foe_s = " foe %s at %s (%d px, aware %s)" % [foe.kind, foe.global_position.round(), int(pos.distance_to(foe.global_position)), foe.aware]
	return "at %s room %d, after %s at %s (%d px); path ours %d, all doors open %d; stuck %d; locks shut %s%s; cards %s %s; moving %s; input %s; overlay %s" % [pos.round(), main.room_at,
		last_step.get("why", "?"), at.round(), int(pos.distance_to(at)), ours, open, stuck_n, main.door_view.lock_status(), foe_s, main.camp_choosing, main.camp.get("stage", ""), p.is_physics_processing(), Input.get_vector("move_left", "move_right", "move_up", "move_down").round(), main.overlay_showing()]


func _note(s: String) -> void:
	log_lines.append("%.1f %s" % [t_game, s])


# --- input -------------------------------------------------------------------------

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "attack", "jump", "roll"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _move(d: Vector2) -> void:
	# Never step off an edge into an open drop (scripts/towers/gryphon_floor.gd):
	# a player sees it; slide along it, or stop.
	var tf = main.tower_floor if main != null else null
	stick_raw = false
	if tf != null and main.player != null:
		var braced: Vector2 = tf.bot_steer(main.player.global_position, d)  # (bracing against the wind near a drop)
		stick_raw = braced != d
		d = braced
	if tf != null and d.length() > 0.01 and main.player != null:
		var pos: Vector2 = main.player.global_position
		var off_edge := func(dir: Vector2) -> bool:
			return tf.is_void(pos + dir.normalized() * 6.0) or tf.is_void(pos + dir.normalized() * 14.0) or tf.is_void(pos + dir.normalized() * 22.0)
		if off_edge.call(d):
			var keep := Vector2.ZERO
			for a in [Vector2(d.x, 0.0), Vector2(0.0, d.y)]:
				if a.length() > 0.2 and not off_edge.call(a):
					keep = a
					break
			d = keep
	last_move = d.normalized() * 10.0
	_stick(["move_left", "move_right", "move_up", "move_down"], d)


func _aim(d: Vector2) -> void:
	_stick(["aim_left", "aim_right", "aim_up", "aim_down"], d)


func _stick(names: Array, d: Vector2) -> void:
	var v := (d.limit_length(1.0) if stick_raw else d.normalized()) if d.length() > 0.01 else Vector2.ZERO
	var vals := [maxf(0.0, -v.x), maxf(0.0, v.x), maxf(0.0, -v.y), maxf(0.0, v.y)]
	for i in 4:
		if vals[i] > 0.05:
			Input.action_press(names[i], vals[i])
		elif Input.is_action_pressed(names[i]):
			Input.action_release(names[i])


## A short press: held for a few ticks (a press made inside a physics tick
## is seen as "just pressed" on the next one), then let go.
func _tap(action: String) -> void:
	if _tapped.has(action) or _cool.has(action):
		return
	Input.action_press(action)
	_tapped[action] = 3


var _tapped := {}  # action -> ticks left held
var _cool := {}  # action -> ticks before it may be pressed again


func _equip(kind: String) -> void:
	var p = main.player
	var want: String = p.gear_id("melee") if kind == "melee" else p.gear_id("ranged")
	if want == "" or p.weapon == want or p.pending_weapon == want:
		return
	_tap("weapon_2" if kind == "melee" else "weapon_3")


# --- each tick ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for a in _tapped.keys():
		_tapped[a] -= 1
		if _tapped[a] <= 0:
			Input.action_release(a)
			_tapped.erase(a)
			_cool[a] = 1
	for a in _cool.keys():
		_cool[a] -= 1
		if _cool[a] < 0:
			_cool.erase(a)
	if done or main == null or main.player == null:
		return
	var p = main.player
	t_game += delta
	if p.hp < hp_seen - 0.5:
		hits_taken += 1
		if p.hp <= 1.5 and hp_seen > 1.5:
			close_calls += 1  # (it would have fallen: the dev tool kept it standing)
	hp_seen = p.hp
	if main.climbing and main.floor_num == floor0 and main.in_chasm(p.global_position) and not p.in_air():
		var tf = main.tower_floor
		var gust: String = String(tf.get("gust_state")) if tf != null and "gust_state" in tf else ""
		_finish(false, "fell into a chasm (%s; wind %s, knock %d, avoided %s, last %s)" % [why, gust, int(last_knock.length()), avoid.has(_tile(p.global_position)), trail])  # (falling sets climbing too: it's no stair)
		return
	last_knock = p.knock
	trail.append("%s v%s m%s void_ahead %s here %s" % [p.global_position.round(), p.velocity.round(), last_move.round(), main.tower_floor.is_void(p.global_position + last_move * 2.2) if main.tower_floor != null else false, main.in_chasm(p.global_position)])
	if trail.size() > 6:
		trail.pop_front()
	if main.floor_num != floor0 or main.climbing:
		_finish(main.floor_num > floor0 or main.climbing, "stair" if main.floor_num > floor0 or main.climbing else "fell to floor %d" % main.floor_num)
		return
	if p.dead:
		_finish(false, "died (%s)" % why)
		return
	if t_game > limit:
		_finish(false, "timeout: %s; task: %s" % [why, main.objective.status_line()])
		return
	# Cards (a reliquary, a vault, a trader): take the first, as a tap would.
	if main.camp_choosing:
		_release_all()
		if main.camp.get("choices", []).size() > 0:  # (a vault, the reliquary, a trader, a full belt's swap...)
			main.choose_camp(0)
		return
	attack_cd -= delta
	path_t -= delta
	nudge_t -= delta
	if swing_hold > 0:
		swing_hold -= 1
		if swing_hold == 0:
			Input.action_release("attack")
	_think(delta)


func _think(delta: float) -> void:
	var p = main.player
	# A precise sequence (ice, stones, a block) runs to its end.
	if not steps.is_empty():
		_run_steps(delta)
		return
	# Fight what's after us (or what holds a room shut, or guards the puzzle).
	var target = _pick_foe()
	if target != null:
		_fight(target, delta)
		return
	foe = null
	var step := _task_step()
	if step.is_empty():
		_move(Vector2.ZERO)
		return
	why = String(step.get("why", ""))
	_do(step, delta)


# --- choosing what to do -----------------------------------------------------------

func _pick_foe():
	var p = main.player
	var pos: Vector2 = p.global_position
	var lock_on: bool = main.door_view != null and not main.door_view.lock_status().is_empty()
	var pz = main.puzzle
	var quiet_pz: bool = pz != null and pz.kind != "" and not pz.solved and pz.room.has_point(pos) and (not pz.awake or String(pz.kind) in ["ice", "crumble", "statues"])  # (clear the room before the ice, the stones or the plates)
	var cur_room: Rect2 = Rect2()
	if main.room_at >= 0 and main.room_at < main.room_info.size():
		cur_room = main.room_info[main.room_at]["rect"]
	var best = null
	var best_d := INF
	for e in main.enemies():
		if e.dead or e.is_queued_for_deletion() or e.get("submerged"):
			continue
		if ignore.has(e) and float(ignore[e]) > t_game:
			continue
		var d: float = pos.distance_to(e.global_position)
		var want := false
		if e.aware and d < 300.0 and main.clear_line(pos, e.global_position):
			want = true
		elif e.aware and d < 140.0:
			want = true
		elif lock_on and cur_room.has_point(e.global_position):
			want = true
		elif quiet_pz and pz.room.grow(-4.0).has_point(e.global_position):
			want = true
		elif main.objective.kind == "keeper" and e == main.objective.keeper:
			want = true
		elif main.scenarios.running() and main.scenarios.active.get("mobs", []).has(e):
			want = true
		if want and d < best_d:
			best_d = d
			best = e
	return best


func _fight(e, delta: float) -> void:
	var p = main.player
	if e != foe:
		foe = e
		foe_t = 0.0
		foe_hp = e.hp
		foe_hit_t = 0.0
		foe_dry = 0.0
		fights += 1
	foe_t += delta
	why = "fighting a %s" % e.kind
	if foe_dry > 10.0 or foe_t > 45.0:
		ignore[e] = t_game + 20.0  # (no harm done to it for a while: leave it be)
		foe = null
		return
	_equip("melee")
	# No harm done for a while (a shell's front, a pillar between): step round it.
	if e.hp < foe_hp - 0.1:
		foe_hp = e.hp
		foe_hit_t = 0.0
		foe_dry = 0.0
	else:
		foe_hit_t += delta
		foe_dry += delta
	if foe_hit_t > 2.5:
		foe_hit_t = 0.0
		var side: Vector2 = (e.global_position - p.global_position).orthogonal().normalized() * (1.0 if randf() < 0.5 else -1.0)
		nudge = side
		nudge_t = 0.5
	if nudge_t > 0.0:
		_move(nudge)
		return
	var to: Vector2 = e.global_position - p.global_position
	var reach: float = 46.0 + float(e.radius)
	var spot: Vector2 = e.global_position
	if e.kind == "shellback" and "face" in e:
		spot = e.global_position - Vector2(e.face).normalized() * (e.radius + 26.0)  # (its shell turns blows from the front)
	var pz = main.puzzle
	var on_ice: bool = pz != null and String(pz.kind) == "ice" and pz.cur != null and pz.cur.in_field(pz.cur.grid(e.global_position))
	if on_ice and to.length() > reach:
		_move(Vector2.ZERO)  # (never onto the ice after it: it comes to us)
	elif to.length() > reach or not main.clear_line(p.global_position, e.global_position):
		_go(spot, 30.0)
	elif spot != e.global_position and p.global_position.distance_to(spot) > 22.0 and Vector2(e.face).dot(-to.normalized()) > 0.2:
		_move(spot - p.global_position)
	else:
		_move(to.normalized() * 0.3 if to.length() > reach * 0.7 else Vector2.ZERO)
	if to.length() < reach + 16.0 and attack_cd <= 0.0:
		_aim(to)
		_tap("attack")
		attack_cd = 0.28
	else:
		_aim(Vector2.ZERO)


## The next step of the floor's task: {pos, act, r, ...} or {} (nothing).
func _task_step() -> Dictionary:
	var ob = main.objective
	var p = main.player
	var pos: Vector2 = p.global_position
	avoid.clear()
	_avoid_marks()
	# A tower's ground that can't be walked (deep water, open drops: tower_floor.gd bot_avoid).
	if main.tower_floor != null:
		for t in main.tower_floor.bot_avoid():
			avoid[t] = true
	# The Ice Hall's ice: walked round, never across (on it, you slide).
	var pz = main.puzzle
	if pz != null and String(pz.kind) == "ice" and pz.cur != null:
		var ice = pz.cur
		var g: Vector2i = ice.grid(pos)
		if ice.in_field(g) and (pz.solved or not main.ward or ob.kind != "ice"):
			if ice.slide_dir == Vector2i.ZERO:
				var I = load("res://scripts/puzzles/ice.gd")
				steps = []
				var off: Array = I.way_off(ice.cols, ice.rows_n, ice.rocks, g)
				if off.is_empty():
					off = [[Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP][randi() % 4]]  # (no line off from here: try a way)
				for d in off:
					steps.append({"kind": "slide", "dir": d, "max": 6.0})
			return {"pos": pos, "act": "none", "why": "off the ice"}
		for y in ice.rows_n:
			for x in ice.cols:
				avoid[_tile(ice.center(Vector2i(x, y)))] = true
	# The tower's own floor first: a crank whose bridge is still up.
	if main.get("tower_floor") != null:
		var own: Dictionary = main.tower_floor.bot_step(self)
		if not own.is_empty():
			return own
	if not main.ward or ob.kind == "" or ob.done:
		# The stair (the reliquary first if it's right there: it's on the way).
		if not ob.reliquary.is_empty() and not ob.reliquary["taken"] and pos.distance_to(ob.reliquary["pos"]) < 260.0:
			return {"pos": ob.reliquary["pos"], "act": "walk", "r": 10.0, "why": "the reliquary"}
		return {"pos": main.stair_pos, "act": "walk", "r": 8.0, "why": "the stair"}
	if ob.spec.get("puzzle", false):
		return _puzzle_step()
	var k: String = ob.kind
	match k:
		"braziers":
			var pc := _nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
			return {"pos": pc["pos"] + Vector2(0, 26), "act": "stand", "r": 12.0, "why": "a brazier"}
		"runes":
			if not ob.tablet["read"]:
				return {"pos": ob.tablet["pos"], "act": "walk", "r": 14.0, "why": "the tablet"}
			var nxt: Dictionary = ob.pieces[ob.spec["order"][ob.step]]
			for q in ob.pieces:
				if q != nxt:
					avoid[_tile(q["pos"])] = true
			return {"pos": nxt["pos"], "act": "walk", "r": 6.0, "why": "rune %s" % nxt.get("glyph", "")}
		"levers":
			var pc := _nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
			return {"pos": pc["pos"], "act": "strike", "why": "a lever"}
		"orb":
			if ob.carried:
				return {"pos": ob.pedestal, "act": "walk", "r": 10.0, "why": "the pedestal"}
			return {"pos": ob.pieces[0]["pos"], "act": "walk", "r": 8.0, "why": "the orb"}
		"keeper":
			if not ob.key.is_empty():
				return {"pos": ob.key["pos"], "act": "walk", "r": 8.0, "why": "the key"}
			if ob.keeper != null and is_instance_valid(ob.keeper):
				return {"pos": ob.keeper.global_position, "act": "walk", "r": 30.0, "why": "the Keeper"}
			return {"pos": ob.pieces[0]["pos"], "act": "walk", "r": 20.0, "why": "the Keeper's room"}
		"wardstone":
			return {"pos": ob.pieces[0]["pos"] + Vector2(0, 44), "act": "stand", "r": 14.0, "why": "the wardstone"}
		"shards":
			var pc := _nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
			return {"pos": pc["pos"], "act": "walk", "r": 6.0, "why": "a shard"}
		"motes":
			var pc := _nearest(ob.pieces.filter(func(x): return x["state"] != "done"))
			var over: Vector2 = (pc["pos"] - pos).normalized() * 24.0 if pos.distance_to(pc["pos"]) < 160.0 else Vector2.ZERO
			var want: Vector2 = main.walkable_point(pc["pos"], pc["pos"] + over, 10.0)  # (run through it: it flees)
			return {"pos": want, "act": "chase", "r": 4.0, "why": "a mote"}
	if ob.own_kind and main.get("tower_floor") != null:
		return main.tower_floor.bot_task(self)  # (a tower's own kind: its floor script knows the way)
	return {}


## Scenario marks are optional: never step on one by accident.
func _avoid_marks() -> void:
	if main.scenarios == null:
		return
	for s in main.scenarios.list:
		if s["state"] == "idle":
			avoid[_tile(s["start"])] = true


func _nearest(list: Array) -> Dictionary:
	var pos: Vector2 = main.player.global_position
	var best := {}
	var best_d := INF
	for x in list:
		var d: float = _path_len(pos, x["pos"])
		if d < best_d:
			best_d = d
			best = x
	return best


# --- doing it ----------------------------------------------------------------------

func _do(step: Dictionary, delta: float) -> void:
	last_step = step
	var p = main.player
	var pos: Vector2 = p.global_position
	var at: Vector2 = step["pos"]
	match String(step["act"]):
		"walk", "chase":
			if pos.distance_to(at) <= float(step.get("r", 12.0)):
				_move((at - pos) * 0.5 if pos.distance_to(at) > 3.0 else Vector2.ZERO)
			else:
				_go(at, float(step.get("r", 12.0)), String(step["act"]) == "chase")
		"stand":
			if pos.distance_to(at) <= float(step.get("r", 12.0)):
				_move(Vector2.ZERO)
			else:
				_go(at, float(step.get("r", 12.0)))
		"strike":
			_equip("melee")
			var to: Vector2 = at - pos
			if to.length() > 44.0 or not main.clear_line(pos, at):
				_go(at, 34.0)
				_aim(Vector2.ZERO)
			else:
				_move(to.normalized() * 0.2 if to.length() > 36.0 else Vector2.ZERO)
				_aim(to)
				if attack_cd <= 0.0 and p.attack_cd <= 0.0:
					_tap("attack")
					attack_cd = 0.55
		"shoot":
			_shoot(at, step.get("from", Vector2.INF))
		"exact":
			_go_to_exact(at)
		"none":
			pass


## Walk to a spot by path, around the walls; doors open as we walk up.
func _go(at: Vector2, r := 12.0, chase := false) -> void:
	var p = main.player
	var pos: Vector2 = p.global_position
	if path_goal == Vector2.INF or path_goal.distance_to(at) > (20.0 if not chase else 40.0) or path_t <= 0.0 or path.is_empty():
		_plan(at)
	# Stuck? (a body, a door barred from this side, a pillar's edge)
	if pos.distance_to(last_pos) < 0.6:
		still_t += get_physics_process_delta_time()
	else:
		still_t = maxf(0.0, still_t - get_physics_process_delta_time())
	last_pos = pos
	if still_t > 1.2:
		still_t = 0.0
		stuck_n += 1
		_unstick()
	if nudge_t > 0.0:
		_move(nudge)
		return
	var d := _steer(pos, at)
	# A chasm ahead: jump it (never an open drop: scripts/towers/gryphon_floor.gd).
	# (taking off close to the lip: a jump carries about 69 px, a chasm tile is 40)
	var drop_ahead: bool = main.tower_floor != null and main.tower_floor.is_void(pos + d.normalized() * 30.0)
	if d != Vector2.ZERO and main.in_chasm(pos + d.normalized() * 16.0) and not main.in_chasm(pos) and not p.in_air() and not drop_ahead:
		_move(d)
		_tap("jump")
		return
	_move(d)


func _unstick() -> void:
	var p = main.player
	var pos: Vector2 = p.global_position
	if foe != null and is_instance_valid(foe) and stuck_n % 3 == 0:
		ignore[foe] = t_game + 25.0  # (we keep sticking on the way to it: leave it)
	# A door shut to us (barred from this side): don't plan through it again.
	for d in main.door_view.list:
		if not d["open"] and d["rect"].grow(30.0).has_point(pos) and String(d["lock"]) != "":
			for t in d["tiles"]:
				blocked[t] = true
	nudge = Vector2.from_angle(randf() * TAU)
	nudge_t = 0.25
	path_t = 0.0


func _plan(at: Vector2) -> void:
	path_goal = at
	path_t = 0.5
	_build_grid()
	var a := _tile(main.player.global_position)
	var b := _tile(at)
	path = PackedVector2Array()
	if not astar.region.has_point(a) or not astar.region.has_point(b):
		return
	var was_a := astar.is_point_solid(a)
	var was_b := astar.is_point_solid(b)
	astar.set_point_solid(a, false)
	astar.set_point_solid(b, false)
	path = astar.get_point_path(a, b)
	astar.set_point_solid(a, was_a)
	astar.set_point_solid(b, was_b)


func _build_grid() -> void:
	var gs: Vector2i = main.grid_size
	if astar == null or grid != gs:
		astar = AStarGrid2D.new()
		astar.region = Rect2i(Vector2i.ZERO, gs)
		astar.cell_size = Vector2(CELL, CELL)
		astar.offset = main.room.position + Vector2(CELL, CELL) * 0.5
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.update()
		grid = gs
	astar.fill_solid_region(astar.region, false)
	astar.fill_weight_scale_region(astar.region, 1.0)
	for y in gs.y:
		for x in gs.x:
			var t := Vector2i(x, y)
			if main.astar.is_point_solid(t):
				astar.set_point_solid(t, true)
	# Closed doors open as we walk up (not locked ones, nor ones found barred).
	for d in main.door_view.list:
		var open: bool = d["open"] or String(d["lock"]) in ["", "oneway"] or (String(d["lock"]) in ["key", "carried"] and int(d["lock_id"]) in main.door_view.held)
		for t in d["tiles"]:
			if astar.region.has_point(t):
				astar.set_point_solid(t, not open or blocked.has(t))
	for t in blocked:
		if astar.region.has_point(t):
			astar.set_point_solid(t, true)
	# Round bodies (pillars, statues, mirrors) and cover.
	for pl in main.pillars:
		var t := _tile(pl["pos"])
		if astar.region.has_point(t):
			astar.set_point_solid(t, true)
	if main.puzzle != null:
		for b in main.puzzle.bodies:
			if is_instance_valid(b):
				var t := _tile(b.position)
				if astar.region.has_point(t):
					astar.set_point_solid(t, true)
	# Chasms cost a jump; traps are walked round when we can.
	for r in main.chasms:
		for t in main._tiles_in(r):
			if not astar.is_point_solid(t):
				astar.set_point_weight_scale(t, 6.0)
	for tr in main.traps:
		var t := _tile(tr["pos"])
		if astar.region.has_point(t) and not astar.is_point_solid(t):
			astar.set_point_weight_scale(t, 3.0)
	# The tower's own floor: its heat, its pits (a detour costs less than they do).
	if main.get("tower_floor") != null:
		main.tower_floor.bot_grid(astar, self)
	for t in avoid:
		if astar.region.has_point(t):
			astar.set_point_solid(t, true)


## Which way to push the stick: toward the farthest point along the path
## that's in a straight, clear line.
func _steer(pos: Vector2, at: Vector2) -> Vector2:
	if path.size() < 2:
		return (at - pos)
	# Drop the points we've passed.
	var best := 1
	for i in range(1, mini(path.size(), 7)):
		if main._wide_clear(pos, path[i], 12.0) and not _crosses_avoid(pos, path[i]):
			best = i
	var next: Vector2 = path[best]
	if best == path.size() - 1:
		next = at
	if pos.distance_to(path[0]) > 60.0:
		path_t = 0.0  # (knocked off the path: plan again)
	return next - pos


func _crosses_avoid(a: Vector2, b: Vector2) -> bool:
	if avoid.is_empty():
		return false
	var n := int(a.distance_to(b) / 10.0) + 1
	for i in n + 1:
		if avoid.has(_tile(a.lerp(b, float(i) / n))):
			return true
	return false


func _tile(pos: Vector2) -> Vector2i:
	return main._tile_of(pos)


func _center(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * CELL


func _path_len(a: Vector2, b: Vector2) -> float:
	if main.astar == null:
		return a.distance_to(b)
	var ta := _tile(a)
	var tb := _tile(b)
	if not main.astar.region.has_point(ta) or not main.astar.region.has_point(tb):
		return a.distance_to(b)
	return a.distance_to(b) + 0.01 * float(main.astar.get_id_path(ta, tb, true).size())


## Draw the bow and loose an arrow at a point.
func _shoot(at: Vector2, from: Vector2) -> void:
	var p = main.player
	var pos: Vector2 = p.global_position
	if from != Vector2.INF and pos.distance_to(from) > 14.0:
		_go(from, 10.0)
		return
	_move(Vector2.ZERO)
	_equip("ranged")
	if p.wkind() != "bow":
		return
	_aim(at - pos)
	if swing_hold <= 0 and attack_cd <= 0.0 and not p.drawing:
		Input.action_press("attack")
		swing_hold = 28  # (held about half a second: a good arrow, quickly)
		attack_cd = 0.6


# --- precise steps (ice slides, stepping stones, pushing a block) ------------------

## steps: [{kind: "to", pos, r} | {kind: "push", dir, until} | {kind: "slide", dir} | {kind: "wait", t}]
func _run_steps(delta: float) -> void:
	var p = main.player
	var pos: Vector2 = p.global_position
	var s: Dictionary = steps[0]
	if step_hp > 0.0 and p.hp < step_hp - 0.5 and String(s["kind"]) == "to":  # (on the ice a blow only nudges the line: it carries on, and plans again at its end)
		steps.clear()  # (struck: knocked about, think again)
		step_hp = 0.0
		step_t = 0.0
		return
	step_hp = p.hp
	step_t += delta
	if step_t > float(s.get("max", 12.0)):
		_note("step gave up: %s" % s)
		steps.clear()
		step_t = 0.0
		return
	match String(s["kind"]):
		"to":
			var to: Vector2 = s["pos"] - pos
			if to.length() <= float(s.get("r", 3.0)):
				_move(Vector2.ZERO)
				_next_step()
			else:
				# Slow near the end so we stop on the spot.
				_move(to.normalized() * clampf(to.length() / 30.0, 0.35, 1.0))
		"slide":
			var ice = main.puzzle.cur
			var on: bool = ice.in_field(ice.grid(pos))
			if not on and (s.get("started", false) or not s.get("enter", false)) and step_t > 0.2:
				steps.clear()  # (off the ice: the rest of the line is for nothing)
				step_t = 0.0
				step_hp = 0.0
				return
			if not s.get("started", false):
				# Push the stick that way until the slide begins (a rock right
				# there: it never does, so move on after a moment).
				_move(Vector2(s["dir"]))
				if ice.slide_dir != Vector2i.ZERO or step_t > 1.0:
					s["started"] = true
			else:
				_move(Vector2.ZERO)
				if ice.slide_dir == Vector2i.ZERO and p.velocity.length() < 5.0:
					_next_step()
		"push":
			var b: Dictionary = s["block"]
			if b["pos"].distance_to(s["until"]) < 4.0:
				_move(Vector2.ZERO)
				_next_step()
			else:
				_move(Vector2(s["dir"]))
		"wait":
			_move(Vector2.ZERO)
			if step_t >= float(s["t"]):
				_next_step()
		"go":
			if pos.distance_to(s["pos"]) <= 30.0:
				_next_step()
			else:
				_go(s["pos"], 6.0)


func _next_step() -> void:
	steps.pop_front()
	step_t = 0.0
	if steps.is_empty():
		step_hp = 0.0


# --- puzzles -----------------------------------------------------------------------

var _pz_plan := {}  # what a puzzle's solution needs, worked out once


func _puzzle_step() -> Dictionary:
	var pz = main.puzzle
	var cur = pz.cur
	var pos: Vector2 = main.player.global_position
	if pz.locked:
		# A wrong answer's hunters: the fight comes to us. Wait in the room.
		return {"pos": _room_entry(pz.room), "act": "stand", "r": 60.0, "why": "the puzzle's hunters"}
	if not pz.room.grow(-12.0).has_point(pos) and pz.kind != "memory":
		return {"pos": _room_entry(pz.room), "act": "walk", "r": 60.0, "why": "the puzzle room"}
	if not pz.awake:
		# Quiet: its guards must fall first (they're picked as foes inside).
		for e in main.enemies():
			if pz.room.grow(-4.0).has_point(e.global_position):
				return {"pos": e.global_position, "act": "walk", "r": 30.0, "why": "the puzzle's guards"}
		return {"pos": _room_entry(pz.room), "act": "stand", "r": 40.0, "why": "the puzzle wakes"}
	match String(pz.kind):
		"statues":
			var at: Vector2 = cur.plates[cur.answer]["pos"]
			return {"pos": at, "act": "stand", "r": 6.0, "why": "the true plate"}
		"mirrors":
			for i in cur.mirrors.size():
				var m: Dictionary = cur.mirrors[i]
				var want = pz.spec["mirrors"][i].get("answer", m["o"])
				if not m["fixed"] and m["o"] != want:
					return {"pos": m["pos"], "act": "strike", "why": "a mirror"}
			return {"pos": pos, "act": "stand", "r": 999.0, "why": "the beam"}
		"eyes":
			for e in cur.eyes:
				if e["lit"] <= 0.0:
					var unlit: Array = cur.eyes.filter(func(x): return x["lit"] <= 0.0).map(func(x): return x["pos"])
					return {"pos": e["pos"], "act": "shoot", "from": _shot_spot(e["pos"], unlit), "why": "an eye"}
			return {"pos": pos, "act": "stand", "r": 999.0, "why": "the eyes"}
		"memory":
			for m in cur.murals:
				if not m["seen"]:
					return {"pos": m["pos"] + Vector2(0, 60), "act": "walk", "r": 20.0, "why": "a mural"}
			if not pz.room.grow(-12.0).has_point(pos):
				return {"pos": _room_entry(pz.room), "act": "walk", "r": 60.0, "why": "the puzzle room"}
			var sign_next = cur.order[cur.lit_n] if cur.lit_n < cur.order.size() else ""
			for q in cur.pedestals:
				if q["sign"] == sign_next and not q["lit"]:
					return {"pos": q["pos"], "act": "strike", "why": "a pedestal"}
			return {}
		"lock":
			if not cur.spawned:
				return {"pos": pz.room.get_center(), "act": "walk", "r": 20.0, "why": "the lock's room"}
			var want: String = cur.answers[cur.step] if cur.step < cur.answers.size() else ""
			for s in cur.sparks:
				if s["kind"] != want:
					avoid[_tile(s["pos"])] = true
			if cur.carried == want and want != "":
				return {"pos": cur.lock + Vector2(0, 30), "act": "walk", "r": 12.0, "why": "the lock"}
			for s in cur.sparks:
				if s["kind"] == want:
					avoid.erase(_tile(s["pos"]))
					return {"pos": s["pos"], "act": "walk", "r": 6.0, "why": "the spark"}
			for g in cur.glowing:
				if g["kind"] == want and is_instance_valid(g["e"]):
					return {"pos": g["e"].global_position, "act": "strike", "why": "the glowing foe"}
			return {"pos": pz.room.get_center(), "act": "stand", "r": 40.0, "why": "the lock"}
		"crumble":
			return _plan_crumble()
		"ice":
			return _plan_ice()
		"plates":
			return _plates_step()
	return {}


## A spot in the room in clear sight of a point (to shoot it).
func _shot_spot(at: Vector2, all: Array = []) -> Vector2:
	var pz = main.puzzle
	var best := Vector2.INF
	var best_d := INF
	var r: Rect2 = pz.room
	for y in range(int(r.position.y) + 20, int(r.end.y), 40):
		for x in range(int(r.position.x) + 20, int(r.end.x), 40):
			var q := Vector2(x, y)
			if main.is_solid(q) or q.distance_to(at) < 90.0:
				continue
			var blocked_line := false
			for b in pz.rails:
				if b.has_point(q):
					blocked_line = true
			if blocked_line or not main.clear_line(q, at):
				continue
			# (somewhere we can walk to: not inside the rails' pocket)
			var tq := _tile(q)
			var tp := _tile(main.player.global_position)
			if main.astar.is_point_solid(tq) or (not main.astar.is_point_solid(tp) and main.astar.get_id_path(tp, tq).is_empty()):
				continue
			var d: float = q.distance_to(at) + q.distance_to(main.player.global_position) * 0.3
			for o in all:
				if not main.clear_line(q, o):
					d += 600.0  # (a spot that sees every eye at once is worth walking to)
			if d < best_d:
				best_d = d
				best = q
	return best


## The stones: walk the route the generator proved, one stone at a time.
func _plan_crumble() -> Dictionary:
	var cur = main.puzzle.cur
	var C = load("res://scripts/puzzles/crumble.gd")
	var route: Array = C.hamilton_path(cur.stones.keys(), cur.cols, cur.rows_n)
	if route.is_empty():
		_note("no route over the stones")
		return {"pos": Vector2.ZERO, "act": "none", "why": "no route over the stones"}
	var first: Vector2i = route[0]
	# Step on from outside, straight across the edge.
	var out := Vector2i.ZERO
	if first.x == 0:
		out = Vector2i.LEFT
	elif first.x == cur.cols - 1:
		out = Vector2i.RIGHT
	elif first.y == 0:
		out = Vector2i.UP
	else:
		out = Vector2i.DOWN
	var outside: Vector2 = cur.stone_center(first + out)
	# Walk to the outside spot by path, keeping off the stones.
	for t in cur.stones:
		avoid[_tile(cur.stone_center(t))] = true
	var pos: Vector2 = main.player.global_position
	if pos.distance_to(outside) > 6.0:
		return {"pos": outside, "act": "exact", "why": "the stones' edge"}
	steps.clear()
	for t in route:
		steps.append({"kind": "to", "pos": cur.stone_center(t), "r": 4.0, "max": 6.0})
	steps.append({"kind": "wait", "t": 0.5})
	return {"pos": pos, "act": "none", "why": "the stones"}


## Walk by path to a spot, ending exactly on it.
func _go_to_exact(at: Vector2) -> void:
	var pos: Vector2 = main.player.global_position
	if pos.distance_to(at) < 36.0 and main.clear_line(pos, at):
		steps = [{"kind": "to", "pos": at, "r": 4.0, "max": 4.0}]
		return
	_go(at, 4.0)


## The ice: the shortest line of slides to the dais, from the way on.
func _plan_ice() -> Dictionary:
	var cur = main.puzzle.cur
	var I = load("res://scripts/puzzles/ice.gd")
	var pos: Vector2 = main.player.global_position
	var g: Vector2i = cur.grid(pos)
	var idle := {"pos": pos, "act": "none", "why": "the ice"}
	if cur.in_field(g):
		if cur.slide_dir != Vector2i.ZERO:
			return idle  # (still sliding)
		# On the ice already: slide on to the dais from here if we can...
		var prev := {g: []}
		var queue: Array = [g]
		while not queue.is_empty():
			var s: Vector2i = queue.pop_front()
			if s == cur.dais:
				steps = []
				for d in prev[s]:
					steps.append({"kind": "slide", "dir": d, "max": 6.0})
				steps.append({"kind": "wait", "t": 0.8})
				return idle
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var t: Vector2i = I.slide_from(s, d, cur.cols, cur.rows_n, cur.rocks)
				if t != I.EXIT and t != s and not prev.has(t):
					prev[t] = prev[s] + [d]
					queue.append(t)
		# ...else slide off, then come round again.
		var off: Array = I.way_off(cur.cols, cur.rows_n, cur.rocks, g)
		if off.is_empty():
			return idle
		steps = []
		for d in off:
			steps.append({"kind": "slide", "dir": d, "max": 6.0})
		return idle
	# Of every way on that leads to the dais, the one nearest us.
	var route: Array = []
	var best_d := INF
	for e in I.entries(cur.cols, cur.rows_n):
		var first: Vector2i = I.slide_from(e[0], e[1], cur.cols, cur.rows_n, cur.rocks)
		if first == I.EXIT or first == e[0]:
			continue
		var on: Vector2 = cur.center(e[0])
		if main.is_solid(on) or main.astar.is_point_solid(_tile(on)):
			continue
		var prev := {first: [e[1]]}
		var queue: Array = [first]
		var found: Array = []
		while not queue.is_empty():
			var s: Vector2i = queue.pop_front()
			if s == cur.dais:
				found = prev[s]
				break
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var t: Vector2i = I.slide_from(s, d, cur.cols, cur.rows_n, cur.rocks)
				if t != I.EXIT and t != s and not prev.has(t):
					prev[t] = prev[s] + [d]
					queue.append(t)
		if found.is_empty():
			continue
		var dd: float = pos.distance_to(on) + 40.0 * found.size()
		if dd < best_d:
			best_d = dd
			route = [e[0]] + found
	if route.is_empty():
		_note("no route on the ice")
		return idle
	var way_on: Vector2 = cur.center(route[0])
	for y in range(-1, cur.rows_n + 1):
		for x in range(-1, cur.cols + 1):
			var t := Vector2i(x, y)
			if cur.in_field(t):
				avoid[_tile(cur.center(t))] = true
	if pos.distance_to(way_on) > 6.0:
		return {"pos": way_on, "act": "exact", "why": "the way onto the ice"}
	steps = []
	for i in range(1, route.size()):
		steps.append({"kind": "slide", "dir": route[i], "max": 6.0, "enter": i == 1})
	steps.append({"kind": "wait", "t": 0.8})
	return idle


## The weighing room: push each block onto a plate (a search for the
## pushes), and where there's no block left, lure a monster onto it.
func _plates_step() -> Dictionary:
	var cur = main.puzzle.cur
	var pos: Vector2 = main.player.global_position
	var free_plates: Array = cur.plates.filter(func(pl): return not pl["down"])
	if free_plates.is_empty():
		return {"pos": pos, "act": "stand", "r": 999.0, "why": "the plates"}
	var spare: Array = cur.blocks.filter(func(b): return not cur.plates.any(func(pl): return b["pos"].distance_to(pl["pos"]) < 8.0))
	if not spare.is_empty():
		var b: Dictionary = spare[0]
		var plate: Dictionary = free_plates[0]
		var best_d := INF
		for pl in free_plates:
			var d: float = b["pos"].distance_to(pl["pos"])
			if d < best_d:
				best_d = d
				plate = pl
		var pushes := _push_plan(b, plate["pos"])
		if pushes.is_empty():
			_note("no pushes for the block")
			return {"pos": pos, "act": "stand", "r": 999.0, "why": "a block that won't go"}
		var first: Array = pushes[0]  # [block tile, dir]
		var behind: Vector2 = _center(first[0] - first[1])
		for blk in cur.blocks:
			avoid[_tile(blk["pos"])] = true
		if pos.distance_to(behind) > 5.0:
			return {"pos": behind, "act": "exact", "why": "behind the block"}
		steps = [{"kind": "push", "block": b, "dir": first[1], "until": _center(first[0] + first[1]), "max": 2.0}, {"kind": "wait", "t": 0.25}]
		return {"pos": pos, "act": "none", "why": "pushing a block"}
	# No block left: bring a monster onto the plate (stand past it, wait).
	var plate2: Dictionary = free_plates[0]
	# The nearest walker in (or by) the room; the room sends one if there's none.
	var mon = null
	var best_m := INF
	var room: Rect2 = main.puzzle.room.grow(120.0)
	for e in main.enemies():
		if e.kind in main.EnemyScript.FLIERS or e.dead or not room.has_point(e.global_position) or no_lure.has(e):
			continue
		if e.kind in ["archer", "bloomcap", "thunderling", "lurker", "briar"]:
			continue  # (they keep their distance, or sink: no good on a plate)
		var dm: float = e.global_position.distance_to(plate2["pos"])
		if dm < best_m:
			best_m = dm
			mon = e
	if mon != null:
		if mon != lure_mon:
			lure_mon = mon
			lure_t = 0.0
		lure_t += get_physics_process_delta_time()
		if lure_t > 12.0:
			no_lure[mon] = true  # (it won't come: fight it, and the room sends another)
			lure_mon = null
			return {"pos": plate2["pos"] + Vector2(0, 60), "act": "stand", "r": 20.0, "why": "waiting for a monster to lure"}
	for e in main.enemies():
		if not no_lure.has(e):
			ignore[e] = t_game + 1.0  # (not now: we need them on the plate, not dead)
	if mon == null:
		return {"pos": plate2["pos"] + Vector2(0, 60), "act": "stand", "r": 20.0, "why": "waiting for a monster to lure"}
	# Stand past the plate from it: it comes to strike and stops on the plate.
	var away: Vector2 = (plate2["pos"] - mon.global_position).normalized()
	var stand: Vector2 = plate2["pos"] + away * (float(mon.radius) + 22.0)
	if main.is_solid(stand):
		stand = plate2["pos"] - away * (float(mon.radius) + 22.0)
	return {"pos": stand, "act": "stand", "r": 5.0, "why": "luring a monster onto the plate"}


## The pushes that bring a block to a spot: [[block tile, dir], ...] (a
## search over the block's tiles, the climber walking round to push).
func _push_plan(b: Dictionary, goal: Vector2) -> Array:
	var start := _tile(b["pos"])
	var target := _tile(goal)
	var cur = main.puzzle.cur
	var room: Rect2 = main.puzzle.room
	var free := func(t: Vector2i) -> bool:
		var c := _center(t)
		if not room.grow(-2.0).has_point(c):
			return false
		return cur._free(c, b)
	var prev := {start: null}
	var queue: Array = [start]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		if t == target:
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = t + d
			if prev.has(n) or not free.call(n) or not free.call(t - d):
				continue
			prev[n] = [t, d]
			queue.append(n)
	if not prev.has(target):
		return []
	var out: Array = []
	var at := target
	while prev[at] != null:
		var pr: Array = prev[at]
		out.push_front([pr[0], pr[1]])
		at = pr[0]
	return out


## A spot inside a room to walk to: its middle, or (when the middle is off
## limits: the ice, a block) the open tile nearest us that isn't.
func _room_entry(r: Rect2) -> Vector2:
	var c := r.get_center()
	var tc := _tile(c)
	if not avoid.has(tc) and not main.astar.is_point_solid(tc):
		return c
	var pos: Vector2 = main.player.global_position
	var best := c
	var best_d := INF
	for y in range(int(r.position.y) + 20, int(r.end.y), 40):
		for x in range(int(r.position.x) + 20, int(r.end.x), 40):
			var q := Vector2(x, y)
			var t := _tile(q)
			if avoid.has(t) or main.astar.is_point_solid(t):
				continue
			var d := q.distance_to(pos)
			if d < best_d:
				best_d = d
				best = q
	return best
