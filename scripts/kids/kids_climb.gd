extends Node2D
## A climb in the kids version: three floors of one tower, each a single room.
## Floors 1 and 2 hold the tower's monsters; floor 3 holds its beast. Clear a
## room and a stair appears; step on it and the sparkles of essence you carry
## pour into your marks. Beat the beast, take its stair, and the beast marks
## you (the Regard) or grows the mark it gave you before.
##
## Kind on purpose: monsters flash before they attack, hearts refill on each
## floor, and losing every heart just starts the room again (nothing is lost).
## No words anywhere: hearts, dots for floors, a glowing guide and pictures.

const Data := preload("res://scripts/kids/kids_data.gd")
const Art := preload("res://scripts/kids/kids_art.gd")
const Pad := preload("res://scripts/kids/kids_pad.gd")

const ROOM := Vector2(1280, 720)
const WALL := 46.0
const PLAYER_R := 22.0
## Characters are drawn this much bigger than the full game's, to be easy to follow.
const BIG := 1.3
const PILLAR_R := 34.0
const START := Vector2(640, 610)
const STAIR := Vector2(640, 175)

var game  # kids_game.gd
var tower := "gryphon"
var floor_i := 0  # 0 and 1: monsters; 2: the beast (FLOORS.size())
var phase := "fight"  # fight, clear, fallen, bank, regard
var phase_t := 0.0
var t := 0.0
var paused := false

var world: Node2D
var hud: Node2D
var pad

# The climber.
var pos := START
var facing := Vector2.UP
var hearts := Data.HEARTS
var safe_t := 0.0
var swing_t := 0.0
var swing_cd := 0.0
var swing_dir := Vector2.UP
var walk_t := 0.0
var knock := Vector2.ZERO
var barrier_t := 0.0
var blades_t := 0.0
var blade_n := 3
var blade_dmg := 1

var monsters: Array = []
var orbs: Array = []  # monsters' throws: {pos, vel, life}
var fireballs: Array = []
var sparks: Array = []  # essence flying to you: {pos, vel, essence, t}
var pickups: Array = []  # hearts: {pos, t}
var fx: Array = []
var pillars: Array = []
var bag := {}  # essence carried, not yet banked
var recharge := {}  # essence -> seconds until its magic is ready
var chosen := ""
var shake := 0.0
var beast_called := false
var bank_bag := {}  # what pours in at the stair
var regard_new := false
var used := {}  # first-time hints met on this climb: move, attack, magic


func setup(g, tower_id: String) -> void:
	game = g
	tower = tower_id


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	world.draw.connect(_draw_world)
	hud = Node2D.new()
	add_child(hud)
	hud.draw.connect(_draw_hud)
	pad = Pad.new()
	for e in game.save.marks:
		recharge[e] = 0.0
	chosen = game.save.chosen if game.save.marks.has(game.save.chosen) else (game.save.marks.keys()[0] if not game.save.marks.is_empty() else "")
	game.audio.set_ambience(tower)
	_start_floor(0)


func essence() -> String:
	return Data.TOWERS[tower]["essence"]


func beast_floor() -> bool:
	return floor_i >= Data.FLOORS.size()


func _start_floor(i: int) -> void:
	floor_i = i
	phase = "fight"
	monsters.clear()
	orbs.clear()
	fireballs.clear()
	pickups.clear()
	sparks.clear()
	pos = START
	facing = Vector2.UP
	knock = Vector2.ZERO
	hearts = Data.HEARTS
	safe_t = 1.0
	barrier_t = 0.0
	blades_t = 0.0
	beast_called = false
	pillars.clear()
	if not beast_floor():
		var spots := [Vector2(330, 380), Vector2(950, 380), Vector2(470, 260), Vector2(810, 260)]
		spots.shuffle()
		for k in randi_range(0, 2):
			pillars.append(spots[k])
		var kinds: Array = Data.TOWERS[tower]["monsters"]
		for k in int(Data.FLOORS[i]):
			_spawn(kinds[k % kinds.size()], _spawn_spot())
	else:
		var b := _spawn(tower, Vector2(640, 260))
		b["beast"] = true
		b["kind"] = "beast"
		b["hp"] = Data.BEAST_HP
		b["max"] = Data.BEAST_HP
		b["r"] = 54.0
		b["speed"] = Data.BEAST_SPEED
		b["t"] = 1.4
		game.sfx("roar_" + tower)
		shake = 8.0


func _spawn_spot() -> Vector2:
	for n in 30:
		var p := Vector2(randf_range(WALL + 80, ROOM.x - WALL - 80), randf_range(WALL + 80, ROOM.y * 0.6))
		if p.distance_to(pos) > 320.0 and not pillars.any(func(pl): return p.distance_to(pl) < PILLAR_R + 50.0):
			return p
	return Vector2(randf_range(200, 1080), 180)


func _spawn(id: String, at: Vector2) -> Dictionary:
	var info: Dictionary = Data.MONSTERS.get(id, {"kind": "walker", "look": "blob", "hp": 3, "speed": 60.0})
	var m := {"id": id, "kind": info["kind"], "look": info["look"], "pos": at, "hp": info["hp"], "max": info["hp"],
		"state": "appear", "t": 0.7, "dir": Vector2.DOWN, "hurt": 0.0, "stun": 0.0, "kv": Vector2.ZERO,
		"cd": randf_range(1.2, 2.6), "beast": false, "r": 25.0, "speed": info["speed"], "blade_cd": 0.0, "next": "charge"}
	monsters.append(m)
	fx.append({"type": "puff", "pos": at, "t": 0.0, "dur": 0.6, "col": Data.tower_color(tower), "r": 40.0})
	return m


# --- each frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	var vs := get_viewport_rect().size
	pad.size = vs
	var sc := minf(vs.x / ROOM.x, vs.y / ROOM.y)
	shake = maxf(0.0, shake - delta * 30.0)
	var wobble := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	world.scale = Vector2(sc, sc)
	world.position = (vs - ROOM * sc) / 2.0 + wobble
	pad.magics = game.save.marks.keys()
	pad.chosen = chosen
	for e in recharge:
		pad.charge[e] = 1.0 - recharge[e] / float(Data.MAGIC[e]["recharge"])
	pad.update()
	if not paused:
		_step(delta)
	pad.consume()
	world.queue_redraw()
	hud.queue_redraw()


func _step(delta: float) -> void:
	phase_t += delta
	for f in fx.duplicate():
		f["t"] += delta
		if f["t"] >= f["dur"]:
			fx.erase(f)
	match phase:
		"fight", "clear":
			_update_player(delta)
			_update_monsters(delta)
			_update_orbs(delta)
			_update_fireballs(delta)
			_update_sparks(delta)
			_update_pickups(delta)
			if phase == "fight" and monsters.is_empty():
				phase = "clear"
				phase_t = 0.0
				orbs.clear()  # (a throw still flying can't hurt once the room is won)
				game.sfx("clear")
			elif phase == "clear" and pos.distance_to(STAIR) < 46.0 and sparks.is_empty():
				_begin_bank()
		"fallen":
			_update_sparks(delta)
			if phase_t >= Data.FALL_WAIT:
				_start_floor(floor_i)  # (the room again, hearts full; you keep what you carry)
		"bank":
			if phase_t >= (2.6 if not bank_bag.is_empty() else 1.0):
				if beast_floor():
					_begin_regard()
				else:
					_start_floor(floor_i + 1)
					game.sfx("step")
		"regard":
			pass


func _input(event: InputEvent) -> void:
	if paused:
		var p = _tap(event)
		if p != null:
			var vs := get_viewport_rect().size
			if p.distance_to(Vector2(vs.x * 0.36, vs.y * 0.55)) < 110.0:
				game.sfx("ui_back")
				game.go_home()
			elif p.distance_to(Vector2(vs.x * 0.64, vs.y * 0.55)) < 110.0:
				_resume()
		elif _key_go(event) or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
			_resume()
		get_viewport().set_input_as_handled()
		return
	if phase == "regard":
		if phase_t > 2.6 and (_tap(event) != null or _key_go(event)):
			game.go_home(tower)
		return
	pad.handle(event)
	if pad.home_pressed:
		paused = true
		pad.release_all()
		game.sfx("ui_open")


func _resume() -> void:
	paused = false
	pad.release_all()
	game.sfx("ui_close")


## Where a tap or click landed (or null).
static func _tap(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed:
		return event.position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return event.position
	return null


static func _key_go(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_J]
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A


# --- the climber ---------------------------------------------------------------

func _update_player(delta: float) -> void:
	var mv: Vector2 = pad.move
	if mv.length() > 0.15:
		facing = mv.normalized()
		walk_t += delta
		used["move"] = true
	else:
		walk_t = 0.0
	pos += mv * Data.SPEED * delta + knock * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	pos = _collide(pos, PLAYER_R)
	safe_t -= delta
	swing_t -= delta
	swing_cd -= delta
	barrier_t -= delta
	blades_t -= delta
	for e in recharge:
		recharge[e] = maxf(0.0, recharge[e] - delta)
	if (pad.attack_pressed or pad.attack_held) and swing_cd <= 0.0:
		_swing()
	if pad.choose != "" and pad.choose != chosen and game.save.marks.has(pad.choose):
		chosen = pad.choose
		game.save.chosen = chosen
		used["gems"] = true
		game.sfx("ui_move")
	if pad.magic_pressed:
		_cast()
	if blades_t > 0.0:
		for i in blade_n:
			var bp := _blade_pos(i)
			for m in monsters.duplicate():
				if m["state"] != "appear" and m["blade_cd"] <= 0.0 and bp.distance_to(m["pos"]) < m["r"] + 16.0:
					m["blade_cd"] = 0.5
					_damage(m, blade_dmg, (m["pos"] - pos).normalized() * 160.0)


func _blade_pos(i: int) -> Vector2:
	var a := t * 4.5 + TAU * float(i) / float(blade_n)
	return pos + Vector2(cos(a), sin(a)) * 70.0 + Vector2(0, -20)


func _nearest(reach: float) -> Dictionary:
	var best := {}
	var bd := reach
	for m in monsters:
		if m["state"] == "appear":
			continue
		var d: float = pos.distance_to(m["pos"]) - m["r"]
		if d < bd:
			bd = d
			best = m
	return best


func _swing() -> void:
	swing_cd = 0.34
	swing_t = Data.SWING_TIME
	var target := _nearest(Data.SWING_REACH + 70.0)
	swing_dir = (target["pos"] - pos).normalized() if not target.is_empty() else facing
	facing = swing_dir
	game.sfx("swing")
	var hit := false
	for m in monsters.duplicate():
		if m["state"] == "appear":
			continue
		var d: Vector2 = m["pos"] - pos
		var close: bool = d.length() <= Data.SWING_REACH + m["r"] and absf(angle_difference(swing_dir.angle(), d.angle())) <= Data.SWING_ARC / 2.0
		if close or d.length() < m["r"] + PLAYER_R + 12.0:
			hit = true
			_damage(m, Data.SWING_DAMAGE, swing_dir * 260.0)
	if hit:
		game.sfx("hit")
		used["attack"] = true


func _cast() -> void:
	if chosen == "" or not game.save.marks.has(chosen):
		return
	if recharge.get(chosen, 0.0) > 0.0:
		game.sfx("ui_back")
		return
	var e := chosen
	var st: int = game.save.star(e)
	var info: Dictionary = Data.MAGIC[e]
	recharge[e] = float(info["recharge"])
	used["magic"] = true
	game.sfx(info["sound"])
	var col := Data.color(e)
	match e:
		"air":
			var pts: Array = [pos + Vector2(0, -30)]
			var from := pos
			var left: Array = monsters.filter(func(m): return m["state"] != "appear")
			for k in int(Data.magic_value(e, "targets", st)):
				if left.is_empty():
					break
				left.sort_custom(func(a, b): return from.distance_to(a["pos"]) < from.distance_to(b["pos"]))
				var m: Dictionary = left.pop_front()
				pts.append(m["pos"] + Vector2(0, -16))
				from = m["pos"]
				_damage(m, int(Data.magic_value(e, "damage", st)), Vector2.ZERO)
			if pts.size() == 1:
				pts.append(pos + facing * 160.0)
			fx.append({"type": "bolt", "pts": pts, "t": 0.0, "dur": 0.4, "col": Color(1.0, 0.95, 0.55)})
		"water", "stone":
			var r: float = Data.magic_value(e, "radius", st)
			fx.append({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.55, "col": col, "r": r})
			if e == "stone":
				shake = 12.0
				for k in 10:
					fx.append({"type": "rock", "pos": pos + Vector2.from_angle(randf() * TAU) * randf_range(40, r), "t": 0.0, "dur": 0.7, "col": col})
			for m in monsters.duplicate():
				var d: Vector2 = m["pos"] - pos
				if d.length() <= r + m["r"]:
					var push := d.normalized() * (560.0 if not m["beast"] else 140.0)
					if e == "stone":
						m["stun"] = float(Data.magic_value(e, "stun", st)) * (0.5 if m["beast"] else 1.0)
						if m["state"] in ["windup", "lunge", "charge"]:
							m["state"] = "rest" if m["beast"] else "walk"
							m["t"] = 1.0
						push *= 0.3
					_damage(m, int(Data.magic_value(e, "damage", st)), push)
			orbs = orbs.filter(func(o): return o["pos"].distance_to(pos) > r)
		"iron":
			barrier_t = float(Data.magic_value(e, "time", st))
		"fire":
			var target := _nearest(900.0)
			var dir: Vector2 = (target["pos"] - pos).normalized() if not target.is_empty() else facing
			fireballs.append({"pos": pos + Vector2(0, -31) + dir * 20.0, "vel": dir * 640.0, "life": 1.3,
				"dmg": int(Data.magic_value(e, "damage", st)), "r": float(Data.magic_value(e, "radius", st))})
		"blade":
			blades_t = float(Data.magic_value(e, "time", st))
			blade_n = int(Data.magic_value(e, "blades", st))
			blade_dmg = int(Data.magic_value(e, "damage", st))


func _hurt_player(from: Vector2) -> void:
	if phase != "fight" and phase != "clear":
		return
	if barrier_t > 0.0:
		game.sfx("hit_armor")
		return
	if safe_t > 0.0:
		return
	hearts -= 1
	safe_t = Data.HURT_SAFE
	knock = (pos - from).normalized() * 520.0
	shake = 9.0
	game.sfx("hurt")
	if hearts <= 0:
		phase = "fallen"
		phase_t = 0.0
		orbs.clear()
		fireballs.clear()
		game.sfx("winded")
		fx.append({"type": "puff", "pos": pos, "t": 0.0, "dur": 0.9, "col": Color(1, 1, 1), "r": 70.0})


# --- monsters ------------------------------------------------------------------

func _damage(m: Dictionary, amount: int, push: Vector2) -> void:
	if not monsters.has(m):
		return
	m["hp"] = int(m["hp"]) - amount
	m["hurt"] = 1.0
	m["kv"] = push * (0.25 if m["beast"] else 1.0)
	game.sfx("hurt_" + String(m["id"]))
	fx.append({"type": "spark", "pos": m["pos"] + Vector2(0, -20), "t": 0.0, "dur": 0.25, "col": Color.WHITE})
	if m["hp"] <= 0:
		_kill(m)
	elif m["beast"] and not beast_called and m["hp"] <= int(m["max"]) / 2:
		beast_called = true
		game.sfx("roar_" + tower)
		shake = 10.0
		var kinds: Array = Data.TOWERS[tower]["monsters"]
		for k in Data.BEAST_HELPERS:
			_spawn(kinds[k % kinds.size()], _collide(m["pos"] + Vector2(-120 + 240 * k, 60), 20.0))


func _kill(m: Dictionary) -> void:
	monsters.erase(m)
	game.sfx("kill_" + String(m["id"]))
	var col := Data.tower_color(tower)
	fx.append({"type": "puff", "pos": m["pos"], "t": 0.0, "dur": 0.6, "col": col, "r": 50.0 if not m["beast"] else 140.0})
	var n := Data.BEAST_SPARKS if m["beast"] else Data.SPARKS
	for k in n:
		sparks.append({"pos": m["pos"] + Vector2(0, -20), "vel": Vector2.from_angle(randf() * TAU) * randf_range(140, 320), "essence": essence(), "t": 0.0})
	if m["beast"]:
		shake = 16.0
		# Its helpers flee with it: the room is won.
		for other in monsters.duplicate():
			fx.append({"type": "puff", "pos": other["pos"], "t": 0.0, "dur": 0.6, "col": col, "r": 50.0})
			monsters.erase(other)
		orbs.clear()
	elif randf() < Data.HEART_DROP and hearts < Data.HEARTS:
		pickups.append({"pos": _collide(m["pos"], 16.0), "t": 0.0})


func _update_monsters(delta: float) -> void:
	for m in monsters.duplicate():
		if not monsters.has(m):
			continue
		m["hurt"] = maxf(0.0, m["hurt"] - delta * 4.0)
		m["blade_cd"] = maxf(0.0, m["blade_cd"] - delta)
		m["pos"] += m["kv"] * delta
		m["kv"] = m["kv"].move_toward(Vector2.ZERO, 900.0 * delta)
		if m["state"] == "appear":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["t"] = randf_range(1.5, 2.5)
			continue
		if m["stun"] > 0.0:
			m["stun"] -= delta
			m["pos"] = _collide(m["pos"], m["r"])
			continue
		var to: Vector2 = pos - m["pos"]
		var dist := to.length()
		var dir := to.normalized() if dist > 0.1 else Vector2.DOWN
		if phase == "fallen":
			continue
		match m["kind"]:
			"walker":
				_walker(m, delta, dir, dist)
			"shooter":
				_shooter(m, delta, dir, dist)
			"beast":
				_beast(m, delta, dir, dist)
		m["pos"] = _collide(m["pos"], m["r"])
	# Keep monsters from piling on top of each other.
	for i in monsters.size():
		for j in range(i + 1, monsters.size()):
			var a: Dictionary = monsters[i]
			var b: Dictionary = monsters[j]
			var d: Vector2 = b["pos"] - a["pos"]
			var need: float = a["r"] + b["r"] + 4.0
			if d.length() < need and d.length() > 0.01:
				var push := d.normalized() * (need - d.length()) * 0.5
				a["pos"] -= push
				b["pos"] += push


func _walker(m: Dictionary, delta: float, dir: Vector2, dist: float) -> void:
	match m["state"]:
		"walk":
			if dist > m["r"] + PLAYER_R + 36.0:
				m["pos"] += dir * float(m["speed"]) * delta
			m["dir"] = dir
			m["cd"] -= delta
			if dist < 120.0 and m["cd"] <= 0.0:
				m["state"] = "windup"
				m["t"] = Data.WINDUP
				m["dir"] = dir
				game.sfx("warn_" + String(m["id"]))
		"windup":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "lunge"
				m["t"] = 0.26
		"lunge":
			m["pos"] += m["dir"] * 400.0 * delta
			if pos.distance_to(m["pos"]) < m["r"] + PLAYER_R + 4.0:
				_hurt_player(m["pos"])
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "rest"
				m["t"] = 0.9
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["cd"] = randf_range(1.0, 2.2)


func _shooter(m: Dictionary, delta: float, dir: Vector2, dist: float) -> void:
	match m["state"]:
		"walk":
			m["dir"] = dir
			var side := Vector2(-dir.y, dir.x) * sin(t * 0.8 + float(m["max"]))
			if dist < 250.0:
				m["pos"] -= dir * float(m["speed"]) * delta
			elif dist > 420.0:
				m["pos"] += dir * float(m["speed"]) * delta
			else:
				m["pos"] += side * float(m["speed"]) * 0.6 * delta
			m["cd"] -= delta
			if m["cd"] <= 0.0:
				m["state"] = "windup"
				m["t"] = Data.WINDUP
				game.sfx("warn_" + String(m["id"]))
		"windup":
			m["t"] -= delta
			if m["t"] <= 0.0:
				_throw(m["pos"] + Vector2(0, -20), dir)
				m["state"] = "rest"
				m["t"] = 0.6
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["cd"] = randf_range(2.6, 3.6)


func _beast(m: Dictionary, delta: float, dir: Vector2, dist: float) -> void:
	match m["state"]:
		"walk":
			if dist > m["r"] + PLAYER_R + 30.0:
				m["pos"] += dir * float(m["speed"]) * delta
			m["dir"] = dir
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "windup"
				m["t"] = 1.1
				m["dir"] = dir
				game.sfx("warn_" + tower)
		"windup":
			m["t"] -= delta
			if m["t"] <= 0.0:
				if m["next"] == "charge":
					m["state"] = "charge"
					m["t"] = 0.55
					m["next"] = "ring"
				else:
					var n := 10
					var off := randf() * TAU
					for k in n:
						_throw(m["pos"] + Vector2(0, -40), Vector2.from_angle(off + TAU * float(k) / float(n)))
					game.sfx("roar_" + tower, 1.1)
					m["state"] = "rest"
					m["t"] = 1.3
					m["next"] = "charge"
		"charge":
			m["pos"] += m["dir"] * 460.0 * delta
			if pos.distance_to(m["pos"]) < m["r"] + PLAYER_R:
				_hurt_player(m["pos"])
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "rest"
				m["t"] = 1.3
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["t"] = randf_range(1.6, 2.6)


func _throw(from: Vector2, dir: Vector2) -> void:
	orbs.append({"pos": from, "vel": dir * Data.ORB_SPEED, "life": 6.0})
	game.sfx("throw")


func _update_orbs(delta: float) -> void:
	for o in orbs.duplicate():
		o["pos"] += o["vel"] * delta
		o["life"] -= delta
		var p: Vector2 = o["pos"]
		var gone: bool = o["life"] <= 0.0 or p.x < WALL or p.y < WALL or p.x > ROOM.x - WALL or p.y > ROOM.y - WALL
		if pillars.any(func(pl): return p.distance_to(pl) < PILLAR_R):
			gone = true
		var to_me := p.distance_to(pos + Vector2(0, -31))
		if barrier_t > 0.0 and to_me < 68.0:
			gone = true
			game.sfx("glint")
		elif to_me < PLAYER_R + 10.0:
			gone = true
			_hurt_player(p)
		if gone:
			orbs.erase(o)
			fx.append({"type": "spark", "pos": p, "t": 0.0, "dur": 0.2, "col": Color(1.0, 0.5, 0.6)})


func _update_fireballs(delta: float) -> void:
	for f in fireballs.duplicate():
		f["pos"] += f["vel"] * delta
		f["life"] -= delta
		var p: Vector2 = f["pos"]
		var boom: bool = f["life"] <= 0.0 or p.x < WALL or p.y < WALL or p.x > ROOM.x - WALL or p.y > ROOM.y - WALL
		for m in monsters:
			if m["state"] != "appear" and p.distance_to(m["pos"] + Vector2(0, -20)) < m["r"] + 14.0:
				boom = true
		if boom:
			fireballs.erase(f)
			fx.append({"type": "ring", "pos": p, "t": 0.0, "dur": 0.45, "col": Color(1.0, 0.55, 0.2), "r": f["r"]})
			game.sfx("fire_blast")
			shake = 6.0
			for m in monsters.duplicate():
				if p.distance_to(m["pos"]) <= f["r"] + m["r"]:
					_damage(m, f["dmg"], (m["pos"] - p).normalized() * 300.0)


func _update_sparks(delta: float) -> void:
	for s in sparks.duplicate():
		s["t"] += delta
		var target := pos + Vector2(0, -34)
		if s["t"] < 0.4:
			s["vel"] = s["vel"].move_toward(Vector2.ZERO, 600.0 * delta)
		else:
			var want: Vector2 = (target - s["pos"]).normalized() * (300.0 + 900.0 * (s["t"] - 0.4))
			s["vel"] = s["vel"].lerp(want, minf(1.0, delta * 8.0))
		s["pos"] += s["vel"] * delta
		if s["t"] > 0.4 and s["pos"].distance_to(target) < 22.0:
			sparks.erase(s)
			bag[s["essence"]] = float(bag.get(s["essence"], 0.0)) + 1.0
			game.sfx("pickup", 1.0 + 0.04 * float(bag[s["essence"]] - int(bag[s["essence"]] / 10.0) * 10.0), -6.0)


func _update_pickups(delta: float) -> void:
	for h in pickups.duplicate():
		h["t"] += delta
		if h["pos"].distance_to(pos) < 40.0 and hearts < Data.HEARTS:
			hearts += 1
			pickups.erase(h)
			game.sfx("life_mend")
			fx.append({"type": "puff", "pos": pos + Vector2(0, -31), "t": 0.0, "dur": 0.5, "col": Color(1.0, 0.4, 0.45), "r": 40.0})


## Keeps a body of radius `r` inside the walls and out of the pillars.
func _collide(p: Vector2, r: float) -> Vector2:
	p.x = clampf(p.x, WALL + r, ROOM.x - WALL - r)
	p.y = clampf(p.y, WALL + r + 20.0, ROOM.y - WALL - 4.0)
	for pl in pillars:
		var d: Vector2 = p - pl
		if d.length() < PILLAR_R + r:
			p = pl + (d.normalized() if d.length() > 0.01 else Vector2.DOWN) * (PILLAR_R + r)
	return p


# --- stair, banking and the Regard ---------------------------------------------

func _begin_bank() -> void:
	phase = "bank"
	phase_t = 0.0
	bank_bag = bag.duplicate()
	bag.clear()
	game.save.bank(bank_bag)
	for k in used:
		game.save.seen[k] = true
	game.save.save()
	game.sfx("vessel_fill" if not bank_bag.is_empty() else "step")


func _begin_regard() -> void:
	phase = "regard"
	phase_t = 0.0
	regard_new = game.save.regard(tower)
	game.save.save()
	game.sfx("regard")
	game.audio.set_ambience("default")
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(game.sfx.bind("summit_win"))


## The bag's total.
func carried() -> float:
	var n := 0.0
	for k in bag:
		n += float(bag[k])
	return n


# --- drawing: the world ----------------------------------------------------------

func _draw_world() -> void:
	var c := world
	var floor_col: Color = Data.TOWERS[tower]["floor"]
	var tint := Data.tower_color(tower)
	c.draw_rect(Rect2(Vector2(-400, -400), ROOM + Vector2(800, 800)), floor_col.darkened(0.75))
	c.draw_rect(Rect2(Vector2.ZERO, ROOM), floor_col.darkened(0.55))
	var tile := 80.0
	for x in int(ROOM.x / tile):
		for y in int(ROOM.y / tile):
			var r := Rect2(Vector2(x, y) * tile, Vector2(tile, tile)).grow(-2.0)
			c.draw_rect(r, floor_col if (x + y) % 2 == 0 else floor_col.darkened(0.08))
	# walls
	var wc := floor_col.darkened(0.45)
	c.draw_rect(Rect2(0, 0, ROOM.x, WALL), wc)
	c.draw_rect(Rect2(0, ROOM.y - WALL, ROOM.x, WALL), wc)
	c.draw_rect(Rect2(0, 0, WALL, ROOM.y), wc)
	c.draw_rect(Rect2(ROOM.x - WALL, 0, WALL, ROOM.y), wc)
	c.draw_rect(Rect2(WALL, WALL, ROOM.x - WALL * 2.0, 14), floor_col.darkened(0.25))
	# torches in the tower's colour
	for tp in [Vector2(WALL * 0.5, 160), Vector2(ROOM.x - WALL * 0.5, 160), Vector2(WALL * 0.5, ROOM.y - 160), Vector2(ROOM.x - WALL * 0.5, ROOM.y - 160)]:
		Art.glow(c, tp, 60.0 + 6.0 * sin(t * 7.0 + tp.y), tint, 1.2)
		c.draw_circle(tp, 7.0, tint.lightened(0.5))
	for pl in pillars:
		c.draw_circle(pl + Vector2(0, 8), PILLAR_R, Color(0, 0, 0, 0.3))
		c.draw_circle(pl, PILLAR_R + 3.0, Art.OUT)
		c.draw_circle(pl, PILLAR_R, floor_col.lightened(0.15))
		c.draw_circle(pl + Vector2(-8, -8), PILLAR_R * 0.4, floor_col.lightened(0.3))
	if phase == "clear" or phase == "bank":
		_draw_stair(c)
	for h in pickups:
		Art.heart(c, h["pos"] + Vector2(0, -14 - 5.0 * sin(t * 5.0)), 15.0)
	# Bodies, lower ones in front.
	var bodies: Array = monsters.duplicate()
	bodies.append({"player": true, "pos": pos})
	bodies.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for b in bodies:
		if b.has("player"):
			_draw_player(c)
		else:
			_draw_monster(c, b)
	for o in orbs:
		Art.glow(c, o["pos"], 26.0, Color(1.0, 0.3, 0.45), 1.5)
		c.draw_circle(o["pos"], 10.0, Color(1.0, 0.35, 0.5))
		c.draw_circle(o["pos"], 5.0, Color(1, 0.9, 0.95))
	for f in fireballs:
		Art.glow(c, f["pos"], 34.0, Color(1.0, 0.55, 0.2), 1.6)
		c.draw_circle(f["pos"], 13.0, Color(1.0, 0.6, 0.25))
		c.draw_circle(f["pos"], 7.0, Color(1.0, 0.95, 0.6))
	for s in sparks:
		var sc := Data.color(s["essence"])
		Art.glow(c, s["pos"], 16.0, sc, 1.4)
		c.draw_circle(s["pos"], 4.0, sc.lightened(0.5))
	_draw_fx(c)
	# The guide: near you, or at the stair once it's open.
	var gp := pos + Vector2(-50, -90)
	if phase == "clear":
		gp = STAIR + Vector2(0, -70)
	gp += Vector2(sin(t * 1.7) * 8.0, sin(t * 2.3) * 6.0)
	Art.guide(c, gp, t, 10.0)
	if phase == "clear" and pos.distance_to(STAIR) > 140.0:
		# An arrow from you toward the stair.
		var d := (STAIR - pos).normalized()
		var a := pos + Vector2(0, -30) + d * (70.0 + 10.0 * sin(t * 6.0))
		var n := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([a + d * 26.0, a - d * 6.0 + n * 18.0, a - d * 6.0 - n * 18.0]), Color(1.0, 0.92, 0.5, 0.9))


func _draw_stair(c: CanvasItem) -> void:
	var p := STAIR
	Art.glow(c, p, 110.0 + 10.0 * sin(t * 3.0), Color(1.0, 0.85, 0.5), 1.4)
	for k in 4:
		var w := 110.0 - 16.0 * float(k)
		var r := Rect2(p + Vector2(-w / 2.0, 30.0 - 18.0 * float(k)), Vector2(w, 18))
		c.draw_rect(r.grow(2.0), Art.OUT)
		c.draw_rect(r, Color(0.85, 0.78, 0.62).darkened(0.12 * float(k)))
	var bob := 8.0 * sin(t * 5.0)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -70 + bob), p + Vector2(-22, -100 + bob), p + Vector2(22, -100 + bob)]), Color(1.0, 0.92, 0.5))


func _draw_player(c: CanvasItem) -> void:
	if phase == "fallen":
		var a := clampf(phase_t / Data.FALL_WAIT, 0.0, 1.0)
		for k in 5:
			var ang := t * 3.0 + TAU * float(k) / 5.0
			Art.star(c, pos + Vector2(0, -70) + Vector2(cos(ang) * 30.0, sin(ang) * 10.0), 8.0, Color(1.0, 0.9, 0.4))
		Art.climber(c, pos + Vector2(0, 6.0 * a), BIG, facing.x < 0.0, {}, {}, t)
		return
	if safe_t > 0.0 and fmod(t, 0.2) < 0.08:
		return  # (blinking: you can't be hurt right now)
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	Art.climber(c, pos, BIG, facing.x < 0.0, marks, stars, t, walk_t)
	if swing_t > 0.0:
		var f := 1.0 - swing_t / Data.SWING_TIME
		var a0 := swing_dir.angle() - Data.SWING_ARC / 2.0
		var center := pos + Vector2(0, -31)
		c.draw_arc(center, Data.SWING_REACH * (0.7 + 0.3 * f), a0, a0 + Data.SWING_ARC * minf(1.0, f * 1.6), 24, Color(1, 1, 1, 0.85 * (1.0 - f)), 14.0)
		Art.sword(c, center + swing_dir.rotated(-Data.SWING_ARC / 2.0 + Data.SWING_ARC * minf(1.0, f * 1.6)) * 46.0, 28.0)
	if barrier_t > 0.0:
		var col := Data.color("iron")
		var fade := minf(1.0, barrier_t)
		c.draw_circle(pos + Vector2(0, -34), 66.0, Color(col, 0.18 * fade))
		c.draw_arc(pos + Vector2(0, -34), 66.0, 0.0, TAU, 40, Color(col.lightened(0.3), 0.8 * fade), 4.0)
	if blades_t > 0.0:
		for i in blade_n:
			var bp := _blade_pos(i)
			Art.glow(c, bp, 20.0, Data.color("blade"), 1.0)
			Art.magic_icon(c, bp, 13.0, "blade")


func _draw_monster(c: CanvasItem, m: Dictionary) -> void:
	var p: Vector2 = m["pos"]
	var grow := 1.0
	if m["state"] == "appear":
		grow = clampf(1.0 - m["t"] / 0.7, 0.05, 1.0)
	var flash := 0.0
	if m["state"] == "windup":
		flash = 1.0
		# Where the attack will land, so it can be seen coming.
		if m["kind"] == "walker":
			c.draw_circle(p + m["dir"] * 60.0, 34.0, Color(1.0, 0.2, 0.2, 0.18 + 0.1 * sin(t * 20.0)))
		elif m["kind"] == "beast" and m["next"] == "charge":
			var d: Vector2 = m["dir"]
			var n := Vector2(-d.y, d.x) * 40.0
			c.draw_colored_polygon(PackedVector2Array([p + n, p + n + d * 280.0, p - n + d * 280.0, p - n]), Color(1.0, 0.2, 0.2, 0.16 + 0.08 * sin(t * 20.0)))
		elif m["kind"] == "beast":
			c.draw_arc(p + Vector2(0, -40), 70.0 + 30.0 * (1.0 - m["t"]), 0.0, TAU, 40, Color(1.0, 0.3, 0.4, 0.6), 6.0)
	var flip: bool = m["dir"].x < 0.0
	if m["beast"]:
		Art.beast(c, p, tower, t, flash, m["hurt"], flip, grow * 1.3)
	else:
		Art.monster(c, p, m["look"], Data.monster_color(m["id"], tower), t + float(m["max"]), flash, m["hurt"], flip, grow * 1.45)
	if m["stun"] > 0.0:
		for k in 3:
			var ang := t * 4.0 + TAU * float(k) / 3.0
			Art.star(c, p + Vector2(0, -80 if not m["beast"] else -150) + Vector2(cos(ang) * 22.0, sin(ang) * 7.0), 7.0)


func _draw_fx(c: CanvasItem) -> void:
	for f in fx:
		var a: float = f["t"] / f["dur"]
		match f["type"]:
			"puff":
				for k in 6:
					var ang := TAU * float(k) / 6.0
					c.draw_circle(f["pos"] + Vector2(cos(ang), sin(ang) * 0.6) * f["r"] * a + Vector2(0, -20), 12.0 * (1.0 - a) + 3.0, Color(f["col"], 0.8 * (1.0 - a)))
			"ring":
				c.draw_circle(f["pos"], f["r"] * minf(1.0, a * 1.5), Color(f["col"], 0.18 * (1.0 - a)))
				c.draw_arc(f["pos"], f["r"] * minf(1.0, a * 1.5), 0.0, TAU, 48, Color(f["col"].lightened(0.3), 0.9 * (1.0 - a)), 10.0)
			"bolt":
				var pts: Array = f["pts"]
				for k in pts.size() - 1:
					var line := PackedVector2Array()
					var p0: Vector2 = pts[k]
					var p1: Vector2 = pts[k + 1]
					for s in 7:
						var q := p0.lerp(p1, float(s) / 6.0)
						if s > 0 and s < 6:
							q += Vector2(randf_range(-12, 12), randf_range(-12, 12))
						line.append(q)
					c.draw_polyline(line, Color(f["col"], 0.5 * (1.0 - a)), 14.0)
					c.draw_polyline(line, Color(1, 1, 1, 1.0 - a), 4.0)
			"rock":
				var rp: Vector2 = f["pos"] + Vector2(0, -60.0 * sin(a * PI))
				c.draw_circle(rp, 9.0 * (1.0 - a * 0.5), f["col"].darkened(0.2))
			"spark":
				for k in 5:
					var ang := TAU * float(k) / 5.0
					c.draw_line(f["pos"] + Vector2.from_angle(ang) * 8.0 * a, f["pos"] + Vector2.from_angle(ang) * (8.0 + 18.0 * a), Color(f["col"], 1.0 - a), 3.0)


# --- drawing: the screen ---------------------------------------------------------

func _draw_hud() -> void:
	var c := hud
	var vs := get_viewport_rect().size
	# Hearts
	for k in Data.HEARTS:
		Art.heart(c, Vector2(48 + 56 * k, 50), 21.0, k < hearts)
	# Sparkles you carry: an orb that grows.
	var n := carried()
	if n > 0.0 or phase == "clear":
		var op := Vector2(48, 112)
		var col := Data.tower_color(tower)
		var r := 10.0 + minf(22.0, sqrt(n) * 3.2)
		Art.glow(c, op, r * 2.2, col, 1.3)
		c.draw_circle(op, r, col.lightened(0.35))
		c.draw_circle(op, r * 0.5, Color(1, 1, 1, 0.8))
	# The climb: a dot for each floor and the beast's crown.
	var total := Data.FLOORS.size() + 1
	for k in total:
		var dp := Vector2(vs.x / 2.0 + (float(k) - float(total - 1) / 2.0) * 70.0, 44)
		var here := k == floor_i
		var done := k < floor_i or (k == floor_i and phase in ["clear", "bank", "regard"])
		if k == total - 1:
			c.draw_circle(dp, 26.0 if here else 22.0, Color(0.1, 0.08, 0.12, 0.8))
			Art.crown(c, dp, 18.0 if here else 14.0)
		else:
			c.draw_circle(dp, 18.0 + (3.0 * sin(t * 5.0) if here else 0.0), Art.OUT)
			c.draw_circle(dp, 14.0 + (3.0 * sin(t * 5.0) if here else 0.0), Color(1.0, 0.85, 0.4) if done else (Data.tower_color(tower) if here else Color(0.3, 0.28, 0.34)))
		if k < total - 1:
			c.draw_line(dp + Vector2(22, 0), dp + Vector2(48, 0), Color(1, 1, 1, 0.3), 4.0)
	# The beast's health: a long bar under the dots.
	for m in monsters:
		if m["beast"]:
			var w := 420.0
			var r := Rect2(Vector2(vs.x / 2.0 - w / 2.0, 82), Vector2(w, 20))
			c.draw_rect(r.grow(4.0), Art.OUT)
			c.draw_rect(r, Color(0.25, 0.1, 0.12))
			c.draw_rect(Rect2(r.position, Vector2(w * float(m["hp"]) / float(m["max"]), 20)), Data.tower_color(tower))
	if phase == "fight" or phase == "clear":
		pad.draw(c, t, _hints())
	match phase:
		"bank":
			_draw_bank(c, vs)
		"regard":
			_draw_regard(c, vs)
	if paused:
		_draw_pause(c, vs)


## The first-time pointers: walking, swinging and casting.
func _hints() -> Dictionary:
	var h := {}
	var seen: Dictionary = game.save.seen
	if not seen.get("move", false) and not used.get("move", false):
		h["move"] = true
	elif not seen.get("attack", false) and not used.get("attack", false) and not monsters.is_empty():
		h["attack"] = true
	elif not game.save.marks.is_empty() and not seen.get("magic", false) and not used.get("magic", false) and not monsters.is_empty():
		h["magic"] = true
	elif game.save.marks.size() > 1 and not seen.get("gems", false):
		h["gems"] = true
	return h


func _shade(c: CanvasItem, vs: Vector2, a: float) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.05, a))


## The stair: sparkles pour from the top of the screen into your marks.
func _draw_bank(c: CanvasItem, vs: Vector2) -> void:
	_shade(c, vs, minf(0.75, phase_t * 2.0))
	var center := Vector2(vs.x / 2.0, vs.y * 0.82)
	var s := 4.0
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	Art.climber(c, center, s, false, marks, stars, t)
	if bank_bag.is_empty():
		return
	var spots: Array = []
	for part in marks:
		spots.append(center + Art.PART_SPOT[part] * s)
	if spots.is_empty():
		spots.append(center + Vector2(0, -27) * s)  # (no mark yet: into your heart)
	var e: String = bank_bag.keys()[0]
	for k in 26:
		var f := fmod(phase_t * 0.9 + float(k) / 26.0, 1.0)
		if phase_t < 0.3 + float(k) * 0.02 or phase_t > 2.2:
			continue
		var target: Vector2 = spots[k % spots.size()]
		var from := Vector2(vs.x / 2.0 + sin(float(k) * 2.3) * vs.x * 0.35, -20)
		var p := from.lerp(target, f * f)
		Art.glow(c, p, 18.0, Data.color(e), 1.4)
		c.draw_circle(p, 5.0, Data.color(e).lightened(0.5))
	for sp in spots:
		Art.glow(c, sp, 50.0 + 10.0 * sin(t * 8.0), Color(1, 1, 0.8), 0.8)


## The Regard: the beast takes notice and its mark flies onto your body.
func _draw_regard(c: CanvasItem, vs: Vector2) -> void:
	_shade(c, vs, minf(0.88, phase_t * 1.5))
	var e := essence()
	var col := Data.color(e)
	var bp := Vector2(vs.x * 0.3, vs.y * 0.68)
	var cp := Vector2(vs.x * 0.66, vs.y * 0.86)
	var s := 4.2
	Art.beast(c, bp, tower, t, 0.0, 0.0, false, 2.1)
	var part: String = game.save.marks[e]["part"] if game.save.marks.has(e) else "heart"
	var spot: Vector2 = cp + Art.PART_SPOT[part] * s
	var landed := phase_t > 1.6
	var marks := {}
	var stars := {}
	for k in game.save.marks:
		if k == e and not landed:
			continue
		marks[game.save.marks[k]["part"]] = Data.color(k)
		stars[game.save.marks[k]["part"]] = game.save.star(k)
	Art.climber(c, cp, s, true, marks, stars, t)
	if not landed and phase_t > 0.5:
		var f := clampf((phase_t - 0.5) / 1.1, 0.0, 1.0)
		var from := bp + Vector2(10, -140)
		var p := from.lerp(spot, f) + Vector2(0, -120.0 * sin(f * PI))
		Art.glow(c, p, 60.0, col, 2.0)
		Art.magic_icon(c, p, 22.0, e)
	if landed:
		var burst := clampf((phase_t - 1.6) / 0.6, 0.0, 1.0)
		if burst < 1.0:
			c.draw_arc(spot, 30.0 + 200.0 * burst, 0.0, TAU, 48, Color(col, 1.0 - burst), 8.0)
		# The magic it gives, and its stars.
		var ic := Vector2(vs.x * 0.66, vs.y * 0.2)
		Art.glow(c, ic, 110.0, col, 1.2 + 0.3 * sin(t * 4.0))
		c.draw_circle(ic, 62.0, col.darkened(0.3))
		Art.magic_icon(c, ic, 42.0, e)
		var st: int = game.save.star(e)
		for k in 3:
			Art.star(c, ic + Vector2(-56 + 56 * k, 92), 20.0, Color(1.0, 0.85, 0.3), k < st)
	if phase_t > 2.6:
		var gp := Vector2(vs.x - 110, vs.y - 110)
		c.draw_circle(gp, 70.0 + 5.0 * sin(t * 5.0), Color(0.2, 0.5, 0.25))
		Art.check(c, gp, 70.0)
		Art.finger(c, gp + Vector2(20, 20), 44.0, t)


func _draw_pause(c: CanvasItem, vs: Vector2) -> void:
	_shade(c, vs, 0.7)
	var hp := Vector2(vs.x * 0.36, vs.y * 0.55)
	var pp := Vector2(vs.x * 0.64, vs.y * 0.55)
	c.draw_circle(hp, 100.0, Color(0.35, 0.3, 0.45))
	Art.house(c, hp, 80.0)
	c.draw_circle(pp, 100.0 + 5.0 * sin(t * 4.0), Color(0.2, 0.5, 0.25))
	Art.play(c, pp + Vector2(8, 0), 70.0)
