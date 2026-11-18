extends Node2D
## A climb: six floors of one tower, each a single room. Floors 1 to 5 hold
## the tower's monsters; floor 6 holds its beast. Clear a room and a stair
## appears; step on it and the sparkles of essence you carry pour into your
## marks. On the first climb (no mark yet) the beast takes notice after floor
## 3 (the Regard) and marks you, and the climb goes on. Beat the beast, take
## its stair, and it gives you its mark (or grows the one it gave before).
##
## Kind on purpose: monsters flash before they attack, hearts refill on each
## floor, and losing every heart just starts the room again (nothing is lost).
## Pictures first (hearts, dots for floors, a glowing guide), with a few
## short words (Data.TEXT) shown big and read aloud, to help with reading.

const Data := preload("res://scripts/data.gd")
const Art := preload("res://scripts/art.gd")
const Pad := preload("res://scripts/pad.gd")
const Creatures := preload("res://scripts/creatures.gd")
const ClimberArt := preload("res://scripts/climber_art.gd")
const RoomArt := preload("res://scripts/room_art.gd")

const ROOM := Vector2(1280, 720)
const WALL := 46.0
const PLAYER_R := 22.0
## Characters are drawn this much bigger than the full game's (its own
## drawings: climber_art.gd, creatures.gd), to be easy for a child to follow.
const CLIMBER_SCALE := 2.2
const MON_SCALE := 2.2
const BEAST_SCALE := 1.6
const PILLAR_R := 34.0
const START := Vector2(640, 610)
## Where a body's middle is, from its position (throws aim here). The
## full game's drawings are centred on their position, seen from above.
const BODY := Vector2(0, -6)
## Where the torches hang on the north wall (x).
const TORCHES := [250.0, 640.0, 1030.0]
const STAIR := Vector2(640, 175)

var game  # game.gd
var tower := "gryphon"
var floor_i := 0  # 0 to 4: monsters; 5: the beast (FLOORS.size())
var phase := "fight"  # fight, clear, fallen, bank, regard
var phase_t := 0.0
var t := 0.0
var paused := false

var world: Node2D
var room_layer: Node2D  # (under the world's bodies: redrawn only when a floor starts)
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
var roll_t := 0.0  # time left in a roll (you can't be hurt)
var roll_cd := 0.0
var roll_dir := Vector2.UP
var parry_t := 0.0  # time left in a parry's window
var parry_cd := 0.0
var weapon := "sword"
var arrows: Array = []  # the bow's: {pos, vel, life}
var blades_t := 0.0
var blade_n := 3
var blade_dmg := 1

var monsters: Array = []
var orbs: Array = []  # monsters' throws: {pos, vel, life}
var fireballs: Array = []
var sparks: Array = []  # essence flying to you: {pos, vel, essence, t}
var pickups: Array = []
var player_mem := {}
var regard_mem := {}  # (climber_art.gd's smoothed pose, between frames)  # hearts: {pos, t}
var fx: Array = []
var pillars: Array = []
var bag := {}  # essence carried, not yet banked
var recharge := {}  # essence -> seconds until its magic is ready
var chosen := ""
var shake := 0.0
var beast_called := false
var bank_bag := {}  # what pours in at the stair
var regard_new := false
var regard_beat := true  # the Regard after beating the beast (false: floor 3's)
var banner := ""  # big words across the screen (and read aloud)
var banner_at := -100.0
var used := {}  # first-time hints met on this climb: move, attack, magic


func setup(g, tower_id: String) -> void:
	game = g
	tower = tower_id


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	world.draw.connect(_draw_world)
	room_layer = Node2D.new()
	room_layer.z_index = -1
	world.add_child(room_layer)
	room_layer.draw.connect(_draw_room)
	hud = Node2D.new()
	add_child(hud)
	hud.draw.connect(_draw_hud)
	pad = Pad.new()
	pad.words = Data.TEXT
	weapon = game.save.weapon
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
	roll_t = 0.0
	parry_t = 0.0
	arrows.clear()
	beast_called = false
	pillars.clear()
	if room_layer != null:
		room_layer.queue_redraw()
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
		b["r"] = Creatures.radius(tower) * BEAST_SCALE * 0.9
		b["speed"] = Data.BEAST_SPEED
		b["t"] = 1.4
		game.sfx("roar_" + tower)
		shake = 8.0
	_say(Data.TEXT["beast"] % beast_name() if beast_floor() else Data.TEXT["floor"] % str(i + 1))


func beast_name() -> String:
	return Data.TOWERS[tower]["name"]


## Big words across the screen for a moment, read aloud too.
func _say(text: String) -> void:
	banner = text
	banner_at = t
	game.say(text)


## Is the first climb's Regard due once this floor is done?
func regard_due() -> bool:
	return game.save.marks.is_empty() and floor_i + 1 == Data.REGARD_FLOOR


func _spawn_spot() -> Vector2:
	for n in 30:
		var p := Vector2(randf_range(WALL + 80, ROOM.x - WALL - 80), randf_range(WALL + 80, ROOM.y * 0.6))
		if p.distance_to(pos) > 320.0 and not pillars.any(func(pl): return p.distance_to(pl) < PILLAR_R + 50.0):
			return p
	return Vector2(randf_range(200, 1080), 180)


func _spawn(id: String, at: Vector2) -> Dictionary:
	var info: Dictionary = Data.MONSTERS.get(id, {"kind": "walker", "look": "blob", "hp": 3, "speed": 60.0})
	# Higher floors: more health, faster, quicker to strike (Data.HARDER).
	var k := float(mini(floor_i, Data.FLOORS.size() - 1))
	var hp := int(round(float(info["hp"]) * (1.0 + Data.HARDER["hp"] * k)))
	var m := {"id": id, "kind": info["kind"], "look": info["look"], "pos": at, "hp": hp, "max": hp,
		"windup": Data.WINDUP * (1.0 - Data.HARDER["windup"] * k), "rest_k": 1.0 - Data.HARDER["rest"] * k,
		"orb": Data.ORB_SPEED * (1.0 + Data.HARDER["orb"] * k),
		"state": "appear", "t": 0.7, "dir": Vector2.DOWN, "hurt": 0.0, "stun": 0.0, "kv": Vector2.ZERO,
		"cd": randf_range(1.2, 2.6), "beast": false, "r": Creatures.radius(id) * MON_SCALE * 0.9, "mem": {}, "seed": randi() % 1000, "speed": float(info["speed"]) * (1.0 + Data.HARDER["speed"] * k), "blade_cd": 0.0, "next": "charge"}
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
	pad.weapon = weapon
	pad.roll_ready = 1.0 - clampf(roll_cd / (Data.ROLL_TIME + Data.ROLL_COOLDOWN), 0.0, 1.0)
	pad.parry_ready = 1.0 - clampf(parry_cd / Data.PARRY_COOLDOWN, 0.0, 1.0)
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
				_say(Data.TEXT["go_up"])
			elif phase == "clear" and pos.distance_to(STAIR) < 46.0 and sparks.is_empty():
				_begin_bank()
		"fallen":
			_update_sparks(delta)
			if phase_t >= Data.FALL_WAIT:
				_start_floor(floor_i)  # (the room again, hearts full; you keep what you carry)
		"bank":
			if phase_t >= (2.6 if not bank_bag.is_empty() else 1.0):
				if beast_floor():
					_begin_regard(true)
				elif regard_due():
					_begin_regard(false)
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
			if regard_beat:
				game.go_home(tower)
			else:
				# Floor 3's Regard: the climb goes on, with the new magic.
				game.audio.set_ambience(tower)
				_start_floor(floor_i + 1)
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
	roll_t -= delta
	roll_cd -= delta
	parry_t -= delta
	parry_cd -= delta
	if pad.roll_pressed and roll_cd <= 0.0:
		_roll(mv)
	if pad.parry_pressed and parry_cd <= 0.0:
		parry_t = Data.PARRY_WINDOW
		parry_cd = Data.PARRY_COOLDOWN
		game.sfx("draw")
	if pad.swap_pressed:
		swap_weapon()
	if roll_t > 0.0:
		pos += roll_dir * Data.ROLL_SPEED * delta  # (a roll carries you; you can't steer it)
	else:
		pos += mv * Data.SPEED * delta
	pos += knock * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	pos = _collide(pos, PLAYER_R)
	safe_t -= delta
	swing_t -= delta
	swing_cd -= delta
	barrier_t -= delta
	blades_t -= delta
	for e in recharge:
		recharge[e] = maxf(0.0, recharge[e] - delta)
	if (pad.attack_pressed or pad.attack_held) and swing_cd <= 0.0 and roll_t <= 0.0:
		_swing()
	_update_arrows(delta)
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


func wdata() -> Dictionary:
	return Data.WEAPONS.get(weapon, Data.WEAPONS["sword"])


## A swing of the weapon in hand (or a shot of the bow), aimed at the nearest
## monster by itself.
func _swing() -> void:
	var w := wdata()
	swing_cd = float(w["cooldown"])
	swing_t = Data.SWING_TIME
	var ranged: bool = w.get("ranged", false)
	var target := _nearest(900.0 if ranged else float(w["reach"]) + 70.0)
	swing_dir = (target["pos"] - pos).normalized() if not target.is_empty() else facing
	facing = swing_dir
	game.sfx(w["sound"])
	if ranged:
		arrows.append({"pos": pos + BODY + swing_dir * 24.0, "vel": swing_dir * float(w["arrow_speed"]), "life": 1.4})
		used["attack"] = true
		return
	var hit := false
	for m in monsters.duplicate():
		if m["state"] == "appear":
			continue
		var d: Vector2 = m["pos"] - pos
		var close: bool = d.length() <= float(w["reach"]) + m["r"] and absf(angle_difference(swing_dir.angle(), d.angle())) <= float(w["arc"]) / 2.0
		if close or d.length() < m["r"] + PLAYER_R + 12.0:
			hit = true
			_strike(m, swing_dir)
	if hit:
		game.sfx(w["hit_sound"])
		used["attack"] = true


## The weapon in hand strikes a monster: its damage, push and stun.
func _strike(m: Dictionary, dir: Vector2) -> void:
	var w := wdata()
	if float(w["stun"]) > 0.0:
		m["stun"] = maxf(float(m["stun"]), float(w["stun"]) * (0.4 if m["beast"] else 1.0))
	_damage(m, int(w["damage"]), dir * float(w["push"]))


func _update_arrows(delta: float) -> void:
	for a in arrows.duplicate():
		a["pos"] += a["vel"] * delta
		a["life"] -= delta
		var p: Vector2 = a["pos"]
		var gone: bool = a["life"] <= 0.0 or p.x < WALL or p.y < WALL or p.x > ROOM.x - WALL or p.y > ROOM.y - WALL
		if pillars.any(func(pl): return p.distance_to(pl) < PILLAR_R):
			gone = true
		for m in monsters.duplicate():
			if not gone and m["state"] != "appear" and p.distance_to(m["pos"] + BODY * 0.5) < m["r"] + 10.0:
				gone = true
				_strike(m, a["vel"].normalized())
				game.sfx(wdata()["hit_sound"])
		if gone:
			arrows.erase(a)


## A roll: a quick dodge the way you're going (or facing) that nothing can hurt.
func _roll(mv: Vector2) -> void:
	roll_dir = mv.normalized() if mv.length() > 0.15 else facing
	facing = roll_dir
	roll_t = Data.ROLL_TIME
	roll_cd = Data.ROLL_TIME + Data.ROLL_COOLDOWN
	used["roll"] = true
	game.sfx("roll")


## The next weapon (the Swap button), or a given one (the climber screen).
func swap_weapon(to := "") -> void:
	if to == "":
		to = Data.WEAPON_ORDER[(Data.WEAPON_ORDER.find(weapon) + 1) % Data.WEAPON_ORDER.size()]
	weapon = to
	game.save.weapon = to
	swing_cd = 0.2
	used["swap"] = true
	game.sfx(wdata()["equip"])
	_say(String(wdata()["word"]))


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
			fireballs.append({"pos": pos + BODY + dir * 20.0, "vel": dir * 640.0, "life": 1.3,
				"dmg": int(Data.magic_value(e, "damage", st)), "r": float(Data.magic_value(e, "radius", st))})
		"blade":
			blades_t = float(Data.magic_value(e, "time", st))
			blade_n = int(Data.magic_value(e, "blades", st))
			blade_dmg = int(Data.magic_value(e, "damage", st))


## A monster's blow or throw reaches you from `from` (`m`: the monster, for
## a lunge or charge). A roll dodges it; a parry blocks it and stuns `m`.
func _hurt_player(from: Vector2, m := {}) -> void:
	if phase != "fight" and phase != "clear":
		return
	if roll_t > 0.0:
		if safe_t <= 0.0:
			game.sfx("dodge")
			safe_t = 0.3
		return
	if parry_t > 0.0:
		_parried(from, m)
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
		_say(Data.TEXT["oops"])
		fx.append({"type": "puff", "pos": pos, "t": 0.0, "dur": 0.9, "col": Color(1, 1, 1), "r": 70.0})


## A blow blocked: the parry's spark and sound; a lunging monster is stunned
## and thrown back; the parry is ready again at once.
func _parried(from: Vector2, m: Dictionary) -> void:
	game.sfx("parry")
	used["parry"] = true
	parry_t = 0.0
	parry_cd = 0.0
	safe_t = maxf(safe_t, 0.35)
	fx.append({"type": "spark", "pos": pos.lerp(from, 0.5) + BODY, "t": 0.0, "dur": 0.35, "col": Color(1.0, 0.9, 0.5)})
	if not m.is_empty() and monsters.has(m):
		m["stun"] = Data.PARRY_STUN * (0.5 if m["beast"] else 1.0)
		m["state"] = "rest" if m["beast"] else "walk"
		m["t"] = 1.0
		m["kv"] = (m["pos"] - pos).normalized() * (160.0 if m["beast"] else 420.0)


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
				m["t"] = m["windup"]
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
				_hurt_player(m["pos"], m)
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "rest"
				m["t"] = 0.9
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["cd"] = randf_range(1.0, 2.2) * m["rest_k"]


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
				m["t"] = m["windup"]
				game.sfx("warn_" + String(m["id"]))
		"windup":
			m["t"] -= delta
			if m["t"] <= 0.0:
				_throw(m["pos"] + BODY * 0.6, dir, m["orb"])
				m["state"] = "rest"
				m["t"] = 0.6
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["cd"] = randf_range(2.6, 3.6) * m["rest_k"]


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
				_hurt_player(m["pos"], m)
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "rest"
				m["t"] = 1.3
		"rest":
			m["t"] -= delta
			if m["t"] <= 0.0:
				m["state"] = "walk"
				m["t"] = randf_range(1.6, 2.6)


func _throw(from: Vector2, dir: Vector2, speed := Data.ORB_SPEED) -> void:
	orbs.append({"pos": from, "vel": dir * speed, "life": 6.0, "mine": false})
	game.sfx("throw")


func _update_orbs(delta: float) -> void:
	for o in orbs.duplicate():
		o["pos"] += o["vel"] * delta
		o["life"] -= delta
		var p: Vector2 = o["pos"]
		var gone: bool = o["life"] <= 0.0 or p.x < WALL or p.y < WALL or p.x > ROOM.x - WALL or p.y > ROOM.y - WALL
		if pillars.any(func(pl): return p.distance_to(pl) < PILLAR_R):
			gone = true
		var to_me := p.distance_to(pos + BODY)
		if o["mine"]:
			# Sent back by a parry: it hurts the monsters.
			for m in monsters.duplicate():
				if not gone and m["state"] != "appear" and p.distance_to(m["pos"] + BODY * 0.5) < m["r"] + 12.0:
					gone = true
					_damage(m, Data.REFLECT_DAMAGE, o["vel"].normalized() * 200.0)
		elif barrier_t > 0.0 and to_me < 68.0:
			gone = true
			game.sfx("glint")
		elif parry_t > 0.0 and to_me < PLAYER_R + 34.0:
			# Parried: it flies back at the nearest monster.
			_parried(p, {})
			var target := _nearest(1200.0)
			var back: Vector2 = (target["pos"] + BODY * 0.5 - p).normalized() if not target.is_empty() else -o["vel"].normalized()
			o["vel"] = back * o["vel"].length() * 1.8
			o["mine"] = true
			o["life"] = 3.0
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
		var target := pos + BODY
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
			fx.append({"type": "puff", "pos": pos + BODY, "t": 0.0, "dur": 0.5, "col": Color(1.0, 0.4, 0.45), "r": 40.0})


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
	if not bank_bag.is_empty() and not game.save.marks.is_empty():
		_say(Data.TEXT["grows"])


## The beast marks you (or grows its mark). `beat`: after beating it on the
## top floor; false for the first climb's Regard on floor 3.
func _begin_regard(beat: bool) -> void:
	phase = "regard"
	phase_t = 0.0
	regard_beat = beat
	regard_new = game.save.regard(tower, beat)
	game.save.save()
	var e := essence()
	recharge[e] = 0.0
	if regard_new:
		chosen = e
	_say(Data.TEXT["you_beat" if beat else "sees_you"] % beast_name())
	var line2: String = Data.TEXT["new_mark"] if regard_new else Data.TEXT["grows"]
	get_tree().create_timer(2.2).timeout.connect(_say_in_regard.bind(line2))
	game.sfx("regard")
	game.audio.set_ambience("train")
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(game.sfx.bind("summit_win"))


## Reads the Regard's second line once the mark has landed (if it's still up).
func _say_in_regard(text: String) -> void:
	if phase == "regard":
		game.say(text)


## The bag's total.
func carried() -> float:
	var n := 0.0
	for k in bag:
		n += float(bag[k])
	return n


# --- drawing: the world ----------------------------------------------------------

func _draw_world() -> void:
	var c := world
	# (the floor, walls and pillars are on room_layer, drawn once a floor)
	for tx in TORCHES:
		RoomArt.torch(c, Vector2(tx, WALL - 20.0), t + tx)
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
	for a in arrows:
		var d: Vector2 = a["vel"].normalized()
		c.draw_line(a["pos"] - d * 26.0, a["pos"], Art.OUT, 6.0)
		c.draw_line(a["pos"] - d * 25.0, a["pos"], Color(0.75, 0.55, 0.3), 3.0)
		c.draw_colored_polygon(PackedVector2Array([a["pos"] + d * 9.0, a["pos"] + d.orthogonal() * 5.0, a["pos"] - d.orthogonal() * 5.0]), Color(0.85, 0.88, 0.95))
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
	RoomArt.stair(c, STAIR, t, tower)


## The room itself (floor, walls, pillars), drawn like the full game's; it
## only changes when a floor starts.
func _draw_room() -> void:
	var floor_rect := Rect2(Vector2(WALL, WALL), ROOM - Vector2(WALL, WALL) * 2.0)
	RoomArt.draw(room_layer, floor_rect, WALL, tower)
	for pl in pillars:
		RoomArt.pillar(room_layer, pl, PILLAR_R, tower)


## The climber, drawn like the full game's (climber_art.gd): their look,
## the weapon in hand, the swing, roll and parry, and their marks.
func _draw_player(c: CanvasItem) -> void:
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	if phase == "fallen":
		for k in 5:
			var ang := t * 3.0 + TAU * float(k) / 5.0
			Art.star(c, pos + Vector2(0, -52) + Vector2(cos(ang) * 30.0, sin(ang) * 10.0), 8.0, Color(1.0, 0.9, 0.4))
		ClimberArt.draw(c, pos, {"app": game.save.app, "t": t, "face": facing, "weapon": weapon, "flash": 0.6,
			"marks": marks, "stars": stars, "scale": CLIMBER_SCALE, "mem": player_mem})
		return
	if safe_t > 0.0 and roll_t <= 0.0 and parry_t <= 0.0 and fmod(t, 0.2) < 0.08:
		return  # (blinking: you can't be hurt right now)
	var hurt := clampf((safe_t - (Data.HURT_SAFE - 0.25)) / 0.25, 0.0, 1.0)
	ClimberArt.draw(c, pos, {
		"app": game.save.app, "t": t, "face": facing, "move": pad.move.length() if roll_t <= 0.0 else 0.0,
		"weapon": weapon, "swing": 1.0 - swing_t / Data.SWING_TIME if swing_t > 0.0 else -1.0, "swing_dir": swing_dir,
		"roll": 1.0 - roll_t / Data.ROLL_TIME if roll_t > 0.0 else -1.0,
		"parry": 1.0 - parry_t / Data.PARRY_WINDOW if parry_t > 0.0 else -1.0,
		"flash": hurt, "marks": marks, "stars": stars, "scale": CLIMBER_SCALE, "mem": player_mem})
	if barrier_t > 0.0:
		var col := Data.color("iron")
		var fade := minf(1.0, barrier_t)
		c.draw_circle(pos + BODY, 58.0, Color(col, 0.18 * fade))
		c.draw_arc(pos + BODY, 58.0, 0.0, TAU, 40, Color(col.lightened(0.3), 0.8 * fade), 4.0)
	if blades_t > 0.0:
		for i in blade_n:
			var bp := _blade_pos(i)
			Art.glow(c, bp, 20.0, Data.color("blade"), 1.0)
			Art.magic_icon(c, bp, 13.0, "blade")


## A monster or beast, drawn like the full game's (creatures.gd). Before it
## strikes it turns red (and shows where the blow will land): the warning.
func _draw_monster(c: CanvasItem, m: Dictionary) -> void:
	var p: Vector2 = m["pos"]
	var beast: bool = m["beast"]
	var sc := BEAST_SCALE if beast else MON_SCALE
	if m["state"] == "appear":
		sc *= clampf(1.0 - m["t"] / (1.4 if beast else 0.7), 0.05, 1.0)
	var state := "walk"
	var wind := 0.0
	var danger := 0.0
	var alt := 0
	match m["state"]:
		"appear":
			state = "idle"
		"windup":
			state = "wind"
			var full: float = 1.1 if beast else float(m.get("windup", Data.WINDUP))
			wind = clampf(1.0 - m["t"] / full, 0.0, 1.0)
			danger = 0.35 + 0.65 * wind
			# Where the attack will land, so it can be seen coming.
			if m["kind"] == "walker":
				c.draw_circle(p + m["dir"] * 70.0, 36.0, Color(1.0, 0.2, 0.2, 0.16 + 0.1 * sin(t * 20.0)))
			elif beast and m["next"] == "charge":
				var d: Vector2 = m["dir"]
				var n := Vector2(-d.y, d.x) * 44.0
				c.draw_colored_polygon(PackedVector2Array([p + n, p + n + d * 300.0, p - n + d * 300.0, p - n]), Color(1.0, 0.2, 0.2, 0.16 + 0.08 * sin(t * 20.0)))
			elif beast:
				c.draw_arc(p, 80.0 + 30.0 * wind, 0.0, TAU, 40, Color(1.0, 0.3, 0.4, 0.6), 6.0)
		"lunge", "charge":
			state = "attack"
			danger = 0.6
		"rest":
			state = "rest"
	if m["stun"] > 0.0:
		state = "stun"
	if beast:
		# Which of its full-game attacks it shows: the charge, or the ring of throws.
		var ring: bool = m["state"] == "windup" and m["next"] == "ring"
		alt = int(Data.BEAST_ALTS.get(tower, {}).get("ring" if ring else "charge", 0))
	var moving: float = 1.0 if m["state"] == "walk" and m["stun"] <= 0.0 else 0.0
	Creatures.draw(c, String(m["id"]), p, {"t": t, "seed": int(m["seed"]), "face": m["dir"], "state": state,
		"wind": wind, "move": moving, "flash": m["hurt"], "danger": danger, "scale": sc, "alt": alt,
		"lift": 16.0, "mem": m["mem"]})
	if m["stun"] > 0.0:
		for k in 3:
			var ang := t * 4.0 + TAU * float(k) / 3.0
			Art.star(c, p + Vector2(0, -m["r"] - 24.0) + Vector2(cos(ang) * 22.0, sin(ang) * 7.0), 7.0)


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
		if k == Data.REGARD_FLOOR - 1 and game.save.marks.is_empty() and not done:
			Art.star(c, dp, 9.0, Color(1, 1, 1))  # (the Regard comes here)
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
	# The banner: big words for a moment.
	var age := t - banner_at
	if banner != "" and age < 2.6 and (phase == "fight" or phase == "clear" or phase == "fallen"):
		Art.words(c, Vector2(vs.x / 2.0, vs.y * 0.42), banner, 56, Color(1.0, 0.95, 0.75), minf(1.0, age * 5.0) * clampf((2.6 - age) * 2.0, 0.0, 1.0))
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
	elif not seen.get("roll", false) and not used.get("roll", false) and _danger_near():
		h["roll"] = true
	elif seen.get("roll", false) and not seen.get("parry", false) and not used.get("parry", false) and _danger_near():
		h["parry"] = true
	elif floor_i >= 1 and not seen.get("swap", false) and not used.get("swap", false):
		h["swap"] = true
	elif not game.save.marks.is_empty() and not seen.get("magic", false) and not used.get("magic", false) and not monsters.is_empty():
		h["magic"] = true
	elif game.save.marks.size() > 1 and not seen.get("gems", false):
		h["gems"] = true
	return h


## Is a monster about to strike nearby (or a throw coming)? The time to show
## Roll and Parry.
func _danger_near() -> bool:
	for m in monsters:
		if m["state"] == "windup" and pos.distance_to(m["pos"]) < 320.0:
			return true
	for o in orbs:
		if not o["mine"] and pos.distance_to(o["pos"]) < 260.0:
			return true
	return false


func _shade(c: CanvasItem, vs: Vector2, a: float) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.05, a))


## The stair: sparkles pour from the top of the screen into your marks.
func _draw_bank(c: CanvasItem, vs: Vector2) -> void:
	_shade(c, vs, minf(0.75, phase_t * 2.0))
	var center := Vector2(vs.x / 2.0, vs.y * 0.82)
	var s := 3.6
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	ClimberArt.draw_front(c, center, game.save.app, s, marks, stars, t)
	if bank_bag.is_empty():
		return
	if not marks.is_empty():
		Art.words(c, Vector2(vs.x / 2.0, vs.y * 0.14), Data.TEXT["grows"], 52, Color(1.0, 0.95, 0.75), minf(1.0, phase_t * 3.0))
	var spots: Array = []
	for part in marks:
		spots.append(ClimberArt.front_spot(center, s, part))
	if spots.is_empty():
		spots.append(ClimberArt.front_spot(center, s, "heart"))  # (no mark yet: into your heart)
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
	var s := 3.8
	Creatures.draw(c, tower, bp + Vector2(0, -70), {"t": t, "face": Vector2.DOWN, "state": "idle", "scale": 2.6, "mem": regard_mem})
	Art.words(c, Vector2(bp.x, vs.y * 0.12), Data.TEXT["you_beat" if regard_beat else "sees_you"] % beast_name(), 46, Color(1.0, 0.95, 0.75), minf(1.0, phase_t * 3.0))
	var part: String = game.save.marks[e]["part"] if game.save.marks.has(e) else "heart"
	var spot: Vector2 = ClimberArt.front_spot(cp, s, part)
	var landed := phase_t > 1.6
	var marks := {}
	var stars := {}
	for k in game.save.marks:
		if k == e and not landed:
			continue
		marks[game.save.marks[k]["part"]] = Data.color(k)
		stars[game.save.marks[k]["part"]] = game.save.star(k)
	ClimberArt.draw_front(c, cp, game.save.app, s, marks, stars, t)
	if not landed and phase_t > 0.5:
		var f := clampf((phase_t - 0.5) / 1.1, 0.0, 1.0)
		var from := bp + Vector2(0, -90)
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
		var pop := minf(1.0, (phase_t - 1.6) * 3.0)
		Art.words(c, ic + Vector2(0, 140), String(Data.MAGIC[e]["word"]) + "!", 44, col.lightened(0.4), pop)
		Art.words(c, Vector2(bp.x, vs.y * 0.12 + 58), Data.TEXT["new_mark"] if regard_new else Data.TEXT["grows"], 38, Color(1, 1, 1), pop)
	if phase_t > 2.6:
		var gp := Vector2(vs.x - 110, vs.y - 110)
		c.draw_circle(gp, 70.0 + 5.0 * sin(t * 5.0), Color(0.2, 0.5, 0.25))
		Art.check(c, gp + Vector2(0, -10), 56.0)
		Art.words(c, gp + Vector2(0, 40), Data.TEXT["ok"], 28)
		Art.finger(c, gp + Vector2(20, 20), 44.0, t)


func _draw_pause(c: CanvasItem, vs: Vector2) -> void:
	_shade(c, vs, 0.7)
	var hp := Vector2(vs.x * 0.36, vs.y * 0.55)
	var pp := Vector2(vs.x * 0.64, vs.y * 0.55)
	c.draw_circle(hp, 100.0, Color(0.35, 0.3, 0.45))
	Art.house(c, hp + Vector2(0, -14), 70.0)
	Art.words(c, hp + Vector2(0, 62), Data.TEXT["home"], 34)
	c.draw_circle(pp, 100.0 + 5.0 * sin(t * 4.0), Color(0.2, 0.5, 0.25))
	Art.play(c, pp + Vector2(8, -14), 60.0)
	Art.words(c, pp + Vector2(0, 62), Data.TEXT["play"], 34)
