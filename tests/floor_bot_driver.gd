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
	d = _ice_keep_off(d)
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
	if target != null and _ice_under():
		# (on the ice the stick slides us: strike from where we stand; stay
		# while it's in reach, else carry on)
		var stay := _ice_jab(target, delta)
		# Out on the ice too, and keeping the puzzle asleep: slide over
		# beside it (round to its back if our blows do it no harm: a shell).
		var pz = main.puzzle
		if foe == target and foe_t < 25.0 and not pz.awake and pz.cur.in_field(pz.cur.grid(target.global_position)) and _ice_huntable(target):
			if (not stay or foe_dry > 2.5) and not _ice_after(target, stay).is_empty():
				if steps.is_empty():
					_move(Vector2.ZERO)
				return
		if stay:
			_move(Vector2.ZERO)
			return
	elif target != null:
		_fight(target, delta)
		return
	if target == null:
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
	# Out on the ice where a blade can't reach it (we keep off the ice): an arrow.
	if foe_t > 1.5 and _ice_bow_at(e):
		if e.hp < foe_hp - 0.1:
			foe_hp = e.hp
			foe_dry = 0.0
		else:
			foe_dry += delta
		_shoot(e.global_position, Vector2.INF)
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
		# Never walk onto the ice after it: it comes to us. One that stays
		# out there: step on and slide over to rest beside it (_ice_after).
		# (not a flier: it comes and goes over the ice; and not for ever:
		# after a while it's left be, as any foe we can't harm)
		var st: Dictionary = _ice_after(e) if foe_t > 3.0 and foe_t < 20.0 and _ice_huntable(e) else {}
		if st.is_empty():
			_move(Vector2.ZERO)
		else:
			foe_dry = minf(foe_dry, 5.0)  # (on our way to it)
			_do(st, delta)
			return
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
	ice_pad.clear()
	_avoid_marks()
	# A tower's ground that can't be walked (deep water, open drops: tower_floor.gd bot_avoid).
	if main.tower_floor != null:
		for t in main.tower_floor.bot_avoid():
			avoid[t] = true
	# The Ice Hall's ice: walked round, never across (on it, you slide).
	var pz = main.puzzle
	if pz != null and String(pz.kind) == "ice" and pz.cur != null:
		var ice = pz.cur
		ice_pad.clear()
		for y in ice.rows_n:
			for x in ice.cols:
				avoid[_tile(ice.center(Vector2i(x, y)))] = true
				ice_pad[_tile(ice.center(Vector2i(x, y)))] = true
		if _ice_under():
			# On it (stepped on, or knocked on): slide by slide, each planned
			# afresh from wherever the last one ended: to the dais if it's
			# the task and awake, else off.
			var to_dais: bool = main.ward and ob.kind == "ice" and not pz.solved and pz.awake and not pz.locked
			if main.ward and ob.kind == "ice" and not pz.awake:
				# (asleep while a guard stands out on the ice: go to it, not off)
				for e in main.enemies():
					if not e.dead and pz.room.grow(-4.0).has_point(e.global_position) and ice.in_field(ice.grid(e.global_position)) and _ice_huntable(e) and not (ignore.has(e) and float(ignore[e]) > t_game):
						var st := _ice_after(e)
						if not st.is_empty():
							return st
			return _ice_on(ice, to_dais)
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
			if pc.is_empty():
				return {"pos": pos, "act": "stand", "r": 999.0, "why": "the braziers"}
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
			if pc.is_empty():  # (every lever up: the task finishes in a moment)
				return {"pos": pos, "act": "stand", "r": 999.0, "why": "the levers"}
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
			if _ice_under():
				_move(Vector2.ZERO)  # (on the ice a stick left pushed would start a slide)


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
	# The Ice Hall's ice: a line that only grazes a corner of it would put
	# us on it, sliding (so: finer steps, with a margin).
	if not ice_pad.is_empty():
		var m := int(a.distance_to(b) / 4.0) + 1
		for i in range(1, m + 1):
			var q := a.lerp(b, float(i) / m)
			for o in ICE_PAD:
				if ice_pad.has(_tile(q + o)):
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
			elif s.get("fine", false) and to.length() < 20.0:
				# (the stick only half pushed near the end, past its deadzone:
				# we creep onto the exact spot instead of stepping past it)
				_move(to)
				stick_raw = true
				_stick(["move_left", "move_right", "move_up", "move_down"], to.normalized() * (0.21 + 0.79 * clampf(to.length() / 20.0, 0.05, 1.0)))
			else:
				# Slow near the end so we stop on the spot.
				_move(to.normalized() * clampf(to.length() / 30.0, 0.35, 1.0))
		"slide":
			# ONE slide on the ice (the plan is made again from wherever it
			# ends: _ice_on). Push the stick that way just until the slide
			# begins, let go at once (so the next one doesn't start by
			# itself), then wait until it has fully stopped.
			var ice = main.puzzle.cur if main.puzzle != null else null
			if ice == null or not ice.has_method("in_field"):
				_next_step()
				return
			var on: bool = ice.in_field(ice.grid(pos))
			if not s.get("started", false):
				if ice.slide_dir != Vector2i.ZERO:
					s["started"] = true  # (begun: ours, or a blow's)
					_move(Vector2.ZERO)
				elif step_t > (1.5 if s.get("enter", false) else 0.35) or (s.get("enter", false) and on and step_t > 0.3):
					_next_step()  # (it never began: a rock right there, a monster in the way)
					_move(Vector2.ZERO)
				else:
					ice_enter = true
					_move(Vector2(s["dir"]))
					ice_enter = false
			else:
				_move(Vector2.ZERO)
				if ice.slide_dir == Vector2i.ZERO and (not on or p.velocity.length() < 5.0):
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
				if String(pz.kind) == "ice" and cur.in_field(cur.grid(e.global_position)) and _ice_huntable(e) and not (ignore.has(e) and float(ignore[e]) > t_game):
					var st := _ice_after(e)  # (out on the ice: slide over beside it)
					if not st.is_empty():
						return st
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


## --- the Ice Hall (scripts/puzzles/ice.gd) ---
## The bot plays the ice with the puzzle's own solver (ice.gd slide_from /
## way_off): ONE slide at a time, each planned afresh from the tile it is
## resting on, so a blow or a monster in the lane that leaves it somewhere
## unplanned costs nothing. It steps on only from the way on it chose (kept
## until reached, or dropped after a while if it can't get there), lined up
## on the tile's middle and standing still, once no monster is about.

var ice_entry: Array = []  # [tile just off the ice, dir]: the way on we're making for
var ice_entry_t := 0.0
var ice_foe_entry: Array = []  # the way on toward a foe out on the ice
var ice_bad := {}  # str(way on) -> until (one we couldn't reach)
var ice_wait_t := 0.0  # waiting to settle on a tile
var ice_pad := {}  # the ice's tiles: walked round with a margin (_crosses_avoid, _ice_keep_off)
var ice_enter := false  # (this tick's push is the planned step onto the ice)
const ICE_PAD := [Vector2(9, 9), Vector2(-9, 9), Vector2(9, -9), Vector2(-9, -9)]


## Walking off the ice, never a step onto it by accident (a corner cut, a
## sidestep in a fight, a nudge when stuck): the part of the stick that
## would take us on is dropped, so we walk along its edge instead. Only the
## planned step on (ice_enter) goes onto it.
func _ice_keep_off(d: Vector2) -> Vector2:
	if ice_enter or ice_pad.is_empty() or d.length() <= 0.01 or main.player == null or _ice_under():
		return d
	var pos: Vector2 = main.player.global_position
	var onto := func(dir: Vector2) -> bool:
		return ice_pad.has(_tile(pos + dir.normalized() * 6.0)) or ice_pad.has(_tile(pos + dir.normalized() * 12.0))
	if not onto.call(d):
		return d
	for a in [Vector2(d.x, 0.0), Vector2(0.0, d.y)]:
		if a.length() > 0.2 and not onto.call(a):
			return a
	return Vector2.ZERO


## Whether we've come to rest on the ice: not sliding, settled on the
## middle of the tile (the ice drifts us there) and still. A body pressed
## against us can keep us from settling: after a second, near enough will do.
func _ice_settled(ice) -> bool:
	var p = main.player
	if ice.slide_dir != Vector2i.ZERO:
		ice_wait_t = 0.0
		return false
	if p.global_position.distance_to(ice.center(ice.grid(p.global_position))) > 2.5 or p.velocity.length() > 8.0:
		ice_wait_t += get_physics_process_delta_time()
		if ice_wait_t < 1.0:
			return false
	ice_wait_t = 0.0
	return true


## Whether to shoot a foe that's out on the ice: we're off it, it's out of
## a blade's reach (or round a rock), there's a clear line for an arrow, and
## a bow in the ranged slot.
func _ice_bow_at(e) -> bool:
	var pz = main.puzzle
	if pz == null or String(pz.kind) != "ice" or pz.cur == null or _ice_under() or e.get("submerged"):
		return false
	if not pz.cur.in_field(pz.cur.grid(e.global_position)):
		return false
	var p = main.player
	var to: Vector2 = e.global_position - p.global_position
	if to.length() <= 46.0 + float(e.radius) and main.clear_line(p.global_position, e.global_position):
		return false  # (in reach: the blade)
	if to.length() > 360.0 or not main.clear_line(p.global_position, e.global_position):
		return false
	var W: Dictionary = load("res://scripts/weapons.gd").WEAPONS
	var bow: String = p.gear_id("ranged")
	return bow != "" and W.has(bow) and String(W[bow].get("kind", "")) == "bow"


## A foe out on the ice we may go after: not one under the surface (it
## rises beside us of itself), nor a flier that's awake (it comes and goes).
func _ice_huntable(e) -> bool:
	return not e.get("submerged") and not (e.kind in main.EnemyScript.FLIERS and e.aware)


## Whether the climber is on the ice (or still sliding off it).
func _ice_under() -> bool:
	var pz = main.puzzle
	if pz == null or String(pz.kind) != "ice" or pz.cur == null:
		return false
	var ice = pz.cur
	return ice.in_field(ice.grid(main.player.global_position)) or ice.slide_dir != Vector2i.ZERO


## A foe while we're on the ice: strike it if it's in reach, never walk at
## it (the stick would slide us). True while it's in reach and we're still
## (stay and fight); false to carry on sliding (out of reach, or no harm
## done to it for a while: then it's left be).
func _ice_jab(e, delta: float) -> bool:
	if e != foe:
		foe = e
		foe_t = 0.0
		foe_hp = e.hp
		foe_dry = 0.0
		fights += 1
	foe_t += delta
	if e.hp < foe_hp - 0.1:
		foe_hp = e.hp
		foe_dry = 0.0
	else:
		foe_dry += delta
	if foe_dry > 8.0:
		ignore[e] = t_game + 20.0
		foe = null
		return false
	why = "fighting a %s on the ice" % e.kind
	var to: Vector2 = e.global_position - main.player.global_position
	var near := to.length() < 46.0 + float(e.radius) + 12.0
	_equip("melee")
	if near and attack_cd <= 0.0:
		_aim(to)
		_tap("attack")
		attack_cd = 0.28
	elif not near:
		_aim(Vector2.ZERO)
	return near and main.puzzle.cur.slide_dir == Vector2i.ZERO


## A foe that stays out on the ice: the slides that bring us to rest beside
## it (it stops a slide like a rock: the puzzle's own slide_from with its
## tile counted as one). Off the ice: walk to the way on that starts the
## fewest such slides and step on; on it: the next slide. {} if no line of
## slides reaches it (it's left be, then, as any foe we can't harm).
func _ice_after(e, behind_only := false) -> Dictionary:
	var pz = main.puzzle
	if pz == null or String(pz.kind) != "ice" or pz.cur == null:
		return {}
	var ice = pz.cur
	var I = ice.get_script()
	var at: Vector2i = ice.grid(e.global_position)
	if not ice.in_field(at) or ice.rocks.has(at):
		return {}
	var rk: Dictionary = ice.rocks.duplicate()
	rk[at] = true
	var pos: Vector2 = main.player.global_position
	var what := "after a %s on the ice" % e.kind
	# (its back, for one whose front turns blows: the tile behind where it looks)
	var back: Vector2i = at - I.cardinal(Vector2(e.face)) if "face" in e and Vector2(e.face).length() > 0.1 else Vector2i(-999, -999)
	var beside := func(t: Vector2i) -> bool:
		return t == back if behind_only else absi(t.x - at.x) + absi(t.y - at.y) == 1
	if _ice_under():
		if not _ice_settled(ice):
			return {"pos": pos, "act": "none", "why": what}
		if beside.call(ice.grid(pos)):
			return {"pos": pos, "act": "none", "why": what}  # (there: strike it)
		var dirs := _ice_path_to(ice, rk, ice.grid(pos), beside)
		if dirs.is_empty():
			return {}
		steps = [{"kind": "slide", "dir": dirs[0], "max": 4.0}]
		return {"pos": pos, "act": "none", "why": what}
	var best: Array = []
	var best_d := INF
	for en in I.entries(ice.cols, ice.rows_n):
		var first: Vector2i = I.slide_from(en[0], en[1], ice.cols, ice.rows_n, rk)
		if first == I.EXIT or first == en[0] or main.astar.is_point_solid(_tile(ice.center(en[0]))):
			continue
		var n := 0 if beside.call(first) else _ice_path_to(ice, rk, first, beside).size()
		if n == 0 and not beside.call(first):
			continue
		var dd: float = _path_len(pos, ice.center(en[0])) + 40.0 * n + (60.0 if ice_foe_entry.size() == 2 and en[0] != ice_foe_entry[0] else 0.0)  # (keep to the one we chose)
		if dd < best_d:
			best_d = dd
			best = [en[0], en[1]]
	if best.is_empty():
		return {}
	ice_foe_entry = best
	return _ice_go_on(ice, best, what)


## The fewest slides (over rocks `rk`) from a resting tile to one `goal`
## accepts: [dirs], [] if none or already there.
func _ice_path_to(ice, rk: Dictionary, from: Vector2i, goal: Callable) -> Array:
	var I = ice.get_script()
	var prev := {from: []}
	var queue: Array = [from]
	var i := 0
	while i < queue.size():
		var s: Vector2i = queue[i]
		i += 1
		if goal.call(s):
			return prev[s]
		for d in I.DIRS:
			var t: Vector2i = I.slide_from(s, d, ice.cols, ice.rows_n, rk)
			if t != I.EXIT and t != s and not prev.has(t):
				prev[t] = prev[s] + [d]
				queue.append(t)
	return []


## Walk to a way onto the ice (by path, then exactly onto the middle of its
## tile), stand still, and step on.
func _ice_go_on(ice, entry: Array, what: String) -> Dictionary:
	var p = main.player
	var pos: Vector2 = p.global_position
	var idle := {"pos": pos, "act": "none", "why": what}
	var way_on: Vector2 = ice.center(entry[0])
	if pos.distance_to(way_on) > 2.0:
		if pos.distance_to(way_on) < 30.0 and main.clear_line(pos, way_on):
			steps = [{"kind": "to", "pos": way_on, "r": 1.5, "fine": true, "max": 4.0}]  # (right onto the middle of the tile)
			return idle
		return {"pos": way_on, "act": "exact", "why": what}
	if p.velocity.length() > 8.0:
		return {"pos": pos, "act": "stand", "r": 999.0, "why": what}
	steps = [{"kind": "slide", "dir": entry[1], "max": 4.0, "enter": true}]
	ice_entry = []
	ice_foe_entry = []
	return idle


## The fewest slides from a resting tile to `goal` (dirs), [] if none (or already there).
func _ice_path(ice, from: Vector2i, goal: Vector2i) -> Array:
	var I = ice.get_script()
	var prev := {from: []}
	var queue: Array = [from]
	var i := 0
	while i < queue.size():
		var s: Vector2i = queue[i]
		i += 1
		if s == goal:
			return prev[s]
		for d in I.DIRS:
			var t: Vector2i = I.slide_from(s, d, ice.cols, ice.rows_n, ice.rocks)
			if t != I.EXIT and t != s and not prev.has(t):
				prev[t] = prev[s] + [d]
				queue.append(t)
	return []


## On the ice: once fully stopped on a tile's middle, the next slide of the
## fewest to the dais (or, with `to_dais` false or no way to it, off).
func _ice_on(ice, to_dais: bool) -> Dictionary:
	var I = ice.get_script()
	var p = main.player
	var pos: Vector2 = p.global_position
	var idle := {"pos": pos, "act": "none", "why": "on the ice" if to_dais else "off the ice"}
	ice_entry = []
	if not _ice_settled(ice):
		return idle
	var g: Vector2i = ice.grid(pos)
	if to_dais and g == ice.dais:
		return idle  # (on it: it wakes and takes us)
	# Monsters standing on the ice stop a slide as a rock does: plan round
	# them first (one pressed against us would stop every slide its way).
	var rk: Dictionary = ice.rocks.duplicate()
	for e in main.enemies():
		var et: Vector2i = ice.grid(e.global_position)
		if not e.dead and not e.get("submerged") and ice.in_field(et) and et != g and et != ice.dais and not (e.kind in main.EnemyScript.FLIERS):
			rk[et] = true
	var dirs: Array = []
	for r in [rk, ice.rocks]:
		if to_dais:
			dirs = _ice_path_to(ice, r, g, func(t): return t == ice.dais)
		if dirs.is_empty():
			dirs = I.way_off(ice.cols, ice.rows_n, r, g, ice.dais if to_dais else I.EXIT)
		if dirs.is_empty():
			dirs = I.way_off(ice.cols, ice.rows_n, r, g)
		if not dirs.is_empty():
			break
	if dirs.is_empty():
		_note("no slide off the ice from %s" % g)
		return idle
	steps = [{"kind": "slide", "dir": dirs[0], "max": 4.0}]
	return idle


## Of every way onto the ice that leads to the dais, the nearest by path
## counting the slides (none we couldn't reach lately): [tile off, dir] or [].
func _ice_pick_entry(ice) -> Array:
	var I = ice.get_script()
	var pos: Vector2 = main.player.global_position
	var best: Array = []
	var best_d := INF
	for e in I.entries(ice.cols, ice.rows_n):
		var first: Vector2i = I.slide_from(e[0], e[1], ice.cols, ice.rows_n, ice.rocks)
		if first == I.EXIT or first == e[0]:
			continue
		if float(ice_bad.get(str(e[0]), -1.0)) > t_game:
			continue
		var on: Vector2 = ice.center(e[0])
		if main.is_solid(on) or main.astar.is_point_solid(_tile(on)):
			continue
		var n: int = 0 if first == ice.dais else _ice_path(ice, first, ice.dais).size()
		if n == 0 and first != ice.dais:
			continue
		var dd: float = _path_len(pos, on) + 40.0 * n
		if dd < best_d:
			best_d = dd
			best = [e[0], e[1]]
	return best


## The ice is the task: off it, make for the way on we chose and step on
## from it, straight and from a standstill.
func _plan_ice() -> Dictionary:
	var ice = main.puzzle.cur
	var p = main.player
	var pos: Vector2 = p.global_position
	var idle := {"pos": pos, "act": "none", "why": "the ice"}
	if _ice_under():
		return _ice_on(ice, true)
	if ice_entry.is_empty():
		ice_entry = _ice_pick_entry(ice)
		ice_entry_t = 0.0
		if ice_entry.is_empty():
			ice_bad.clear()  # (every way on was given up on: try them all again)
			_note("no way onto the ice")
			return idle
	ice_entry_t += get_physics_process_delta_time()
	var way_on: Vector2 = ice.center(ice_entry[0])
	if ice_entry_t > 20.0:
		_note("couldn't reach the way onto the ice at %s" % way_on.round())
		ice_bad[str(ice_entry[0])] = t_game + 40.0
		ice_entry = []
		return idle
	# A monster close by would knock us about on the ice: deal with it first.
	if pos.distance_to(way_on) <= 2.0:
		for e in main.enemies():
			if not e.dead and e.aware and not e.get("submerged") and e.global_position.distance_to(pos) < 110.0 and not (ignore.has(e) and float(ignore[e]) > t_game):
				return {"pos": pos, "act": "stand", "r": 999.0, "why": "a monster by the ice"}
	return _ice_go_on(ice, ice_entry, "the way onto the ice")


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
