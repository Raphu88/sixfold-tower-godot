extends Node2D
## Prototype room: one fight to test whether bonds feel good.
## Builds the walls, spawns the climber and three kinds of monster.

const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio.gd")
const RoomScript := preload("res://scripts/room.gd")
const Palette := preload("res://scripts/palette.gd")
const TouchScript := preload("res://scripts/touch.gd")
const Floors := preload("res://scripts/floors.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Essence := preload("res://scripts/essence.gd")
const BondScript := preload("res://scripts/bond.gd")
const Towers := preload("res://scripts/towers.gd")
const MenuScript := preload("res://scripts/menu.gd")
## The stair opens once this share of a floor's monsters are down.
const STAIR_OPENS_AT := 0.75

const STAIR_REACH := 26.0

const WALL := 24.0

var room := Rect2(80, 100, 1120, 530)
var player
var fx
var camera: Camera2D
var cleared := false
var shake_amount := 0.0
var audio
var hitstop_until := 0  # real-time msec when the freeze ends
var hurt_flash := 0.0
var light_tex: Texture2D
var touch_active := false  # on-screen controls in use

# The climb
var floor_num := 1
var best_floor := 1
var pillars: Array = []  # {pos, r}
var pillar_bodies: Array = []
var stair_open := false
var stair_pos := Vector2.ZERO
var climbing := false
var fade := 0.0  # black screen between floors, 0..1
var banner := {}  # {title, lines, t}: shown when a floor starts
var room_view
var player_start := Vector2.ZERO

# Marks and essence
var profile  # what carries over between climbs (profile.gd)
var first_climb := false  # bondless, ending in the Regard
var run_essence := {}  # gathered since the last stair (lost if you fall)
var run_soak := {}  # body-part soak since the last stair
var climb_essence := {}  # everything gathered this climb
var climb_soak := {}  # everything soaked this climb
var regard := {}  # the Regard, while it plays: {fell, part, id, t}
var regard_pending := false
var victory := {}  # the climb complete screen, after the beast falls: {t, beast, lines}
var tower := "kraken"  # which tower this climb is in (towers.gd)
var choosing_tower := false  # the tower choice is showing
var floor_total := 0  # monsters this floor started with
var dim: CanvasModulate
var hud
var touch
var menu  # title, pause, settings and dev tool (menu.gd)
var dev_no_death := false  # dev tool: you can't fall
var counting_hits := false  # while a spell is cast: count the foes it hits
var cast_hits := 0
var new_climber_t := 0.0

# Lingering spell effects in the room
var rod := {}  # Lightning Rod: {pos, t, reach}
var walls: Array = []  # Crosswind: {a, b, t, color}
var cyclones: Array = []  # Eye of the Storm: {pos, r, t, color}
var rains: Array = []  # Rain of Arrows: {pos, r, t, tick, damage, color}
var track_t := 0.0  # Track: foes revealed
var waves: Array = []  # Tidecaller's travelling waves: {pos, dir, width, left, dmg, push, carry, hit, color}
var maelstroms: Array = []  # Maelstrom whirlpools: {pos, r, t, damage, tick, color}
var puddles: Array = []  # standing water (the Kraken's tower): {pos, r}
var flames: Array = []  # burning floor (the Wyvern's tower): {pos, r, t}
var chasms: Array = []  # gaps in the floor (Rect2): jump across or fall
var chasm_bodies: Array = []
var runes: Array = []  # Rune Artist's Rune Traps: {pos, r, blast, damage, linked, color, t}
var wards: Array = []  # Ward Circles foes can't enter: {pos, r, t, color}
var sigils: Array = []  # Grand Sigils, free casting inside: {pos, r, t, color}
var stone_walls: Array = []  # Sandshaper's walls: {pos, r, t, body, fault}
var rubble: Array = []  # Quake rubble that slows foes: {pos, r, t}
var pits: Array = []  # Sinkholes (drawn only): {pos, r, t}
var clouds: Array = []  # Venomist's Toxic Clouds: {pos, r, t, tick, color}
var smokes: Array = []  # Ashwalker's Smoke Veils: {pos, r, t}
var decoys: Array = []  # Ashwalker's Afterimages: {pos, t, aim}
var ashfall_t := 0.0  # Ashfall: foes lose track of you once out of reach
var slowmo := false  # time slows while a spell ring is open
var player_glow: PointLight2D
var pick_anchor := Vector2.ZERO  # touch: where the held mark button is on screen  # a first press asks; a second within this time confirms

# Attack turns: only this many monsters may be attacking at once.
const MAX_ATTACKERS := 2
var attackers: Array = []


func _ready() -> void:
	# Run after the bodies have moved, so the shove-apart pass sees this frame.
	process_physics_priority = 10
	randomize()
	Engine.time_scale = 1.0  # in case we restarted mid hit-pause
	Controls.setup()
	audio = AudioScript.new()
	add_child(audio)
	_build_walls()

	# Lighting: the whole room is dimmed, torches and the climber's own glow
	# light it back up. Effects ignore the dimming so spells always read.
	RenderingServer.set_default_clear_color(Palette.VOID)
	y_sort_enabled = true  # lower things draw in front of higher things
	dim = CanvasModulate.new()
	dim.color = Palette.AMBIENT
	add_child(dim)
	room_view = RoomScript.new()
	room_view.setup(room, WALL)
	add_child(room_view)
	light_tex = RoomScript.make_light_texture()

	player_start = Vector2(room.get_center().x, room.end.y - 60.0)
	stair_pos = Vector2(room.get_center().x, room.position.y + 34.0)
	room_view.stair_pos = stair_pos
	player = PlayerScript.new()
	player.main = self
	player.position = Vector2(300, 365)  # floor 1 starts on the left, facing the fight
	add_child(player)
	var glow := PointLight2D.new()
	glow.texture = light_tex
	glow.texture_scale = 1.4
	glow.color = Color(1.0, 0.85, 0.7)
	glow.energy = 0.55
	player.add_child(glow)
	player_glow = glow

	profile = ProfileScript.new()
	if Engine.has_meta("sixfold_test"):
		profile.saving = false  # tests never touch the real save
	else:
		profile.load_save()
	best_floor = profile.best_floor
	first_climb = not profile.regarded
	_give_bonds()
	tower = profile.last_tower if Towers.TOWERS.has(profile.last_tower) else "kraken"
	_apply_tower_look()
	_start_floor(1)
	if Engine.has_meta("sixfold_test"):
		_greet()
	else:
		# Each climb begins by choosing a tower.
		choosing_tower = true
		player.set_physics_process(false)
		for e in enemies():
			e.set_physics_process(false)

	fx = FxScript.new()
	fx.main = self
	fx.z_index = 10
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.material = unlit
	add_child(fx)

	# The camera follows the climber, zoomed in, but never past the walls.
	camera = Camera2D.new()
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(room.position.x - WALL - 20.0)
	camera.limit_right = int(room.end.x + WALL + 20.0)
	camera.limit_top = int(room.position.y - RoomScript.WALL_FACE - WALL - 20.0)
	camera.limit_bottom = int(room.end.y + WALL + 70.0)  # room for the bond HUD
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)
	touch = TouchScript.new()
	touch.main = self
	layer.add_child(touch)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MenuScript.new()
	menu.main = self
	menu_layer.add_child(menu)
	# A fresh start (not a restart or a new floor) opens on the title screen.
	if not Engine.has_meta("sixfold_test") and not Engine.has_meta("sixfold_title_seen"):
		menu.open.call_deferred("title")


func _build_walls() -> void:
	var r := room
	var sides := [
		Rect2(r.position.x - WALL, r.position.y - WALL, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.end.y, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.position.y, WALL, r.size.y),
		Rect2(r.end.x, r.position.y, WALL, r.size.y),
	]
	for s in sides:
		var rect: Rect2 = s
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)


func _process(delta: float) -> void:
	if hitstop_until > 0 and Time.get_ticks_msec() >= hitstop_until:
		hitstop_until = 0
		Engine.time_scale = 0.35 if slowmo else 1.0
	if choosing_tower:
		for i in Towers.ORDER.size():
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				choose_tower(Towers.ORDER[i])
		return
	if not victory.is_empty():
		victory["t"] += delta / maxf(Engine.time_scale, 0.01)
		if overlay_done() and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("restart")):
			end_regard()
		return
	if not regard.is_empty():
		regard["t"] += delta / maxf(Engine.time_scale, 0.01)
		if regard_done() and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("restart")):
			end_regard()
		return
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	new_climber_t -= delta / maxf(Engine.time_scale, 0.01)
	if Input.is_action_just_pressed("new_climber"):
		if new_climber_t > 0.0:
			new_climber()
			return
		new_climber_t = 3.0
		var again := "Tap New again" if touch_active else "Press N again"
		banner = {"title": "NEW CLIMBER?", "lines": ["%s within 3 seconds to start over." % again, "Your marks and all their growth will be lost."], "t": 3.0}
		sfx("warn_knight", 1.2, -6.0, 0.0)
	if Input.is_action_just_pressed("toggle_music") and audio != null:
		fx_text(player.global_position + Vector2(0, -44), "Music on" if audio.toggle_music() else "Music off", Color(0.85, 0.82, 0.9))
	# The stair opens once most of the floor is down; clearing it all rings the gong.
	var alive := enemies().size()
	if not stair_open and not climbing and float(floor_total - alive) >= ceilf(STAIR_OPENS_AT * floor_total):
		stair_open = true
		room_view.stair_open = true
		if alive > 0:
			sfx("glint", 0.7, -2.0, 0.0)
	if not cleared and not climbing and alive == 0:
		cleared = true
		sfx("clear", 1.0, 0.0, 0.0)
	if stair_open and not climbing and not player.dead and player.global_position.distance_to(stair_pos) < STAIR_REACH + player.radius:
		_climb()
	if not banner.is_empty():
		banner["t"] -= delta
		if banner["t"] <= 0.0:
			banner = {}
	if player != null:
		camera.position = player.position
	# On phones the whole game is already drawn bigger, so pull the camera back.
	var want := 1.1 if touch_active else 1.35
	camera.zoom = Vector2(want, want)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
	shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)
	hurt_flash = move_toward(hurt_flash, 0.0, delta)


func _physics_process(delta: float) -> void:
	_separate_bodies()
	_update_spell_fields(delta)


## Ticks the spells that linger in the room: rods, wind walls, cyclones, rain.
func _update_spell_fields(delta: float) -> void:
	_update_ground(delta)
	_update_runes(delta)
	_update_flames(delta)
	track_t -= delta
	if not rod.is_empty():
		rod["t"] -= delta
		if rod["t"] <= 0.0:
			rod = {}
	for w in walls:
		w["t"] -= delta
	walls = walls.filter(func(w): return w["t"] > 0.0)
	for c in cyclones:
		c["t"] -= delta
		for e in enemies():
			var to: Vector2 = c["pos"] - e.global_position
			if to.length() < c["r"] + e.radius:
				e.airborne = maxf(e.airborne, 0.3)
				e.knock = to.normalized() * minf(to.length() * 3.0, 120.0)
	cyclones = cyclones.filter(func(c): return c["t"] > 0.0)
	_update_waves(delta)
	for m in maelstroms:
		m["t"] -= delta
		m["tick"] -= delta
		var hurt: bool = m["tick"] <= 0.0
		if hurt:
			m["tick"] = 0.5
		for e in enemies():
			var to: Vector2 = m["pos"] - e.global_position
			if to.length() < m["r"] + e.radius:
				e.knock = to.normalized() * minf(to.length() * 4.0, 260.0)
				if hurt:
					e.take_hit(m["damage"], Vector2.ZERO, 0.0)
	maelstroms = maelstroms.filter(func(m): return m["t"] > 0.0)
	for r in rains:
		r["t"] -= delta
		r["tick"] -= delta
		if r["tick"] <= 0.0:
			r["tick"] = 0.12
			# Each volley: one arrow at random, one at a foe caught in the area.
			var spots: Array = [r["pos"] + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r["r"]]
			var inside: Array = enemies().filter(func(e): return e.global_position.distance_to(r["pos"]) < r["r"] + e.radius)
			if not inside.is_empty():
				spots.append(inside[randi() % inside.size()].global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
			for at in spots:
				if fx != null:
					fx.falling_arrow(at, r["color"])
				for e in enemies():
					if e.global_position.distance_to(at) < e.radius + 16.0:
						e.take_hit(r["damage"], Vector2.ZERO, 0.0)
	rains = rains.filter(func(r): return r["t"] > 0.0)


## Bodies can't share space: overlapping ones are pushed apart, and the
## lighter one gives way more. Foes lifted into the air pass over everyone.
func _separate_bodies() -> void:
	var bodies: Array = enemies().filter(func(e): return e.airborne <= 0.0 and not e.submerged)
	if player != null and not player.dead:
		bodies.append(player)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			var d: Vector2 = b.global_position - a.global_position
			var min_d: float = a.radius + b.radius
			var dist := d.length()
			if dist >= min_d:
				continue
			var n := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
			var overlap := min_d - dist
			var share: float = b.weight / (a.weight + b.weight)  # a's part of the push
			a.move_and_collide(-n * overlap * share)
			b.move_and_collide(n * overlap * (1.0 - share))


# --- the climb -------------------------------------------------------------

func _start_floor(n: int) -> void:
	floor_num = n
	cleared = false
	stair_open = false
	room_view.stair_open = false
	# Clear out the last floor: monsters, arrows, pillars.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
		e.remove_from_group("enemies")
	for c in get_children():
		if "reflected" in c:
			c.queue_free()
	attackers.clear()
	rod = {}
	walls.clear()
	cyclones.clear()
	waves.clear()
	maelstroms.clear()
	rains.clear()
	flames.clear()
	runes.clear()
	wards.clear()
	sigils.clear()
	for w in stone_walls:
		if is_instance_valid(w["body"]):
			w["body"].queue_free()
	stone_walls.clear()
	rubble.clear()
	pits.clear()
	clouds.clear()
	smokes.clear()
	decoys.clear()
	ashfall_t = 0.0
	if player != null:
		player.rune_gear = ""  # runes on gear last one floor
	track_t = 0.0
	for b in pillar_bodies:
		b.queue_free()
	pillar_bodies.clear()

	var start: Vector2 = player.position if n == 1 else player_start
	var plan: Dictionary = Floors.build(n, room, start, Towers.TOWERS[tower])
	floor_total = plan["monsters"].size()
	if plan.get("summit", false):
		banner = {"title": "%s AWAITS" % beast_name().to_upper(), "lines": [tower_data().get("beast_hint", "Watch for the glint.")], "t": 3.0}
		sfx("warn_knight", 0.5, 0.0, 0.0)
	pillars = plan["pillars"]
	for p in pillars:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = p["pos"]
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = p["r"]
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		pillar_bodies.append(body)
	room_view.set_pillars(pillars)
	puddles = Floors.puddles(room, pillars, start) if tower_data().get("puddles", false) else []
	room_view.set_puddles(puddles)
	set_chasms(plan.get("chasms", []))

	var tough := Floors.toughness(n)
	for m in plan["monsters"]:
		var e = EnemyScript.new()
		e.setup(m[0], self)
		e.max_hp *= tough.x
		e.hp = e.max_hp
		e.dmg *= tough.y
		e.position = m[1]
		add_child(e)
	player.position = start
	if camera != null:
		camera.position = start
		camera.reset_smoothing()


## Walking onto the open stair: fade out, rest, grow, fade into the next floor.
func _climb() -> void:
	climbing = true
	player.set_physics_process(false)
	sfx("step", 0.8, 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.45)
	tw.tween_callback(_arrive)
	tw.tween_interval(0.25)
	tw.tween_property(self, "fade", 0.0, 0.5)
	tw.tween_callback(func(): climbing = false)


func _arrive() -> void:
	var lines: Array = []
	# Rest at the stair: burns heal, some health and all stamina return.
	var burned := false
	for b in player.bonds.values():
		burned = burned or b.burned
		b.burned = false
	player.poison_t = 0.0  # the rest at the stair cures poison too
	var healed := minf(player.max_hp - player.hp, player.max_hp * 0.35)
	player.hp += healed
	player.sta = player.max_sta
	if burned:
		lines.append("Your burns heal")
	if healed >= 1.0:
		lines.append("Rested: +%d health" % int(healed))
	# Bank the essence gathered on this floor: it strengthens your marks.
	var banked := 0.0
	for k in run_essence:
		banked += float(run_essence[k])
	if banked > 0.0:
		lines.append("Banked %d essence" % int(banked))
	lines.append_array(profile.bank(run_essence, run_soak))
	run_essence = {}
	run_soak = {}
	# An unmarked body part that has soaked up enough takes a new mark.
	if not first_climb:
		var part: String = profile.ready_for_mark()
		if part != "":
			var id: String = profile.choose_bond(profile.tally, climb_soak)
			if id != "":
				profile.add_bond(part, id, false)
				lines.append("Essence takes hold in your %s: the %s mark" % [BondScript.PART_NAMES[part], BondScript.Bonds.BONDS[id]["name"]])
				sfx("crit", 0.7, -4.0)
	_give_bonds()
	profile.save()
	# The top of the first climb: the Regard.
	if first_climb and floor_num >= ProfileScript.FIRST_CLIMB_FLOORS:
		_begin_regard(false)
		return
	# The summit: the beast has fallen and the climb is complete.
	if floor_num == int(tower_data().get("summit", 0)):
		profile.climbs += 1
		profile.save()
		victory = {"t": 0.0, "beast": beast_name(), "lines": lines}
		player.set_physics_process(false)
		sfx("clear", 0.7, 0.0, 0.0)
		return
	_start_floor(floor_num + 1)
	if floor_num > best_floor:
		best_floor = floor_num
		profile.best_floor = best_floor
		profile.save()
	if banner.get("title", "").ends_with("AWAITS"):
		banner["lines"] = lines + banner["lines"]
	else:
		banner = {"title": _floor_title(), "lines": lines, "t": 3.0}
	player.set_physics_process(true)
	sfx("clear", 0.8, -8.0, 0.0)


# --- towers ---------------------------------------------------------------------

func tower_data() -> Dictionary:
	return Towers.TOWERS[tower]


func beast_name() -> String:
	return tower_data()["beast"]


## Picks this climb's tower and starts on its first floor.
func choose_tower(id: String) -> void:
	if not choosing_tower or not Towers.TOWERS.has(id):
		return
	choosing_tower = false
	tower = id
	profile.last_tower = id
	profile.save()
	_apply_tower_look()
	_start_floor(1)
	player.set_physics_process(true)
	sfx("equip_sword", 0.8, -2.0, 0.0)
	_greet()


func _greet() -> void:
	if first_climb:
		banner = {"title": "YOUR FIRST CLIMB", "lines": ["You bear no mark.", "Climb %d floors. %s is watching." % [ProfileScript.FIRST_CLIMB_FLOORS, beast_name().capitalize()]], "t": 4.0}
	else:
		banner = {"title": tower_data()["name"].to_upper(), "lines": [], "t": 2.5}


## Each tower's stone, light and torches.
func _apply_tower_look() -> void:
	var t := tower_data()
	dim.color = t["ambient"]
	room_view.self_modulate = t["stone"]
	room_view.set_torch_color(t["torch"])


func _floor_title() -> String:
	if first_climb:
		return "FLOOR %d OF %d" % [floor_num, ProfileScript.FIRST_CLIMB_FLOORS]
	return "FLOOR %d" % floor_num


## Rebuilds the climber's bonds from the saved marks, keeping charge and burns.
func _give_bonds() -> void:
	if player == null:
		return
	var old: Dictionary = player.bonds.duplicate()
	player.bonds.clear()
	for part in profile.bonds:
		var info: Dictionary = profile.bonds[part]
		var b = BondScript.new(info["id"], part)
		b.step = ProfileScript.step_for_xp(float(info["xp"]))
		b.faint = bool(info["faint"])
		if old.has(part) and old[part].id == b.id:
			b.essence = minf(old[part].essence, b.capacity())
			b.burned = old[part].burned
			b.selected = old[part].selected
		player.bonds[part] = b
	# Hunter's Keen Eyes: you see farther in the dark.
	if player_glow != null:
		player_glow.texture_scale = 2.2 if player.has_bond("hunter") or player.has_bond("ashwalker") else 1.4  # Keen Eyes, Smokeborn


# --- essence and the Regard ----------------------------------------------------

## A body part did its thing (called by the climber).
func add_soak(part: String, amount: float) -> void:
	run_soak[part] = float(run_soak.get(part, 0.0)) + amount
	climb_soak[part] = float(climb_soak.get(part, 0.0)) + amount


## How close an unmarked body part is to taking a mark, 0..1 (for drawing).
func soak_fraction(part: String) -> float:
	if first_climb:
		# Relative to the leading part: the brightest glow is where it will form.
		var most := 15.0
		for pt in climb_soak:
			most = maxf(most, float(climb_soak[pt]))
		return clampf(float(climb_soak.get(part, 0.0)) / most, 0.0, 1.0)
	var need: float = ProfileScript.NEW_MARK_SOAK * float(maxi(1, profile.bonds.size()))
	return clampf((float(profile.soak.get(part, 0.0)) + float(run_soak.get(part, 0.0))) / need, 0.0, 1.0)


## How much each unmarked body part has soaked: this climb on the first
## climb, else everything banked plus this floor's.
func part_soak(part: String) -> float:
	if first_climb:
		return float(climb_soak.get(part, 0.0))
	return float(profile.soak.get(part, 0.0)) + float(run_soak.get(part, 0.0))


## The unmarked body part that would take the next mark ("" if none has soaked).
func leading_part() -> String:
	var best := ""
	var most := 0.0
	for pt in BondScript.Bonds.PARTS:
		if profile.bonds.has(pt):
			continue
		var v := part_soak(pt)
		if v > most:
			most = v
			best = pt
	return best


## The bond the next mark would be, if it formed now.
func predicted_bond() -> String:
	var part := leading_part()
	if part == "":
		return ""
	var essence: Dictionary = climb_essence
	if not first_climb:
		essence = profile.tally.duplicate()
		for k in run_essence:
			essence[k] = float(essence.get(k, 0.0)) + float(run_essence[k])
	return profile.choose_bond(essence, climb_soak)


func gather_essence(kind: String, amount: float, from: Vector2) -> void:
	run_essence[kind] = float(run_essence.get(kind, 0.0)) + amount
	climb_essence[kind] = float(climb_essence.get(kind, 0.0)) + amount
	if fx != null:
		fx.motes(from, Essence.color(kind), int(ceil(amount)), player)


func on_player_died() -> void:
	if first_climb and regard.is_empty() and not regard_pending:
		# Even fallen, you are regarded: a faint mark after a moment.
		regard_pending = true
		get_tree().create_timer(1.6, true, false, true).timeout.connect(func(): _begin_regard(true))


## The beast takes notice and your most-used body part takes its first mark.
## Reaching the top earns a full mark; falling earns a faint one.
func _begin_regard(fell: bool) -> void:
	if not regard.is_empty():
		return
	var part := leading_part()
	if part == "":
		part = "hand"
	var id: String = profile.choose_bond(climb_essence, climb_soak)
	profile.add_bond(part, id, fell)
	profile.regarded = true
	profile.climbs += 1
	profile.save()
	regard = {"fell": fell, "part": part, "id": id, "t": 0.0}
	banner = {}
	regard_pending = false
	player.set_physics_process(false)
	for e in enemies():
		e.set_physics_process(false)
	for c in get_children():
		if "reflected" in c:
			c.queue_free()
	sfx("clear", 0.55, 0.0, 0.0)
	sfx("glint", 0.6, -2.0, 0.0)


## True once the Regard has played long enough to be dismissed.
## True once the Regard or the victory screen can be dismissed.
func overlay_done() -> bool:
	return regard_done() or (not victory.is_empty() and victory["t"] > 2.5)


func overlay_showing() -> bool:
	return not regard.is_empty() or not victory.is_empty()


func regard_done() -> bool:
	return not regard.is_empty() and regard["t"] > 3.0


func end_regard() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


## Starts over as a new climber: no marks, back to the bondless first climb.
func new_climber() -> void:
	profile.reset()
	Engine.time_scale = 1.0
	if get_tree().current_scene == self:  # (tests run the room outside a scene)
		get_tree().reload_current_scene()


## Tests: start with two marks instead of a bondless first climb.
func grant_test_bonds() -> void:
	profile.add_bond("hand", "stormcaller", false)
	profile.add_bond("legs", "windwalker", false)
	profile.regarded = true
	first_climb = false
	_give_bonds()


# --- attack turns ------------------------------------------------------------

func _tidy_attackers() -> void:
	attackers = attackers.filter(func(e): return is_instance_valid(e) and not e.dead)


func can_attack() -> bool:
	_tidy_attackers()
	return attackers.size() < MAX_ATTACKERS


func holds_attack(e) -> bool:
	return e in attackers


## A monster asks for a turn to attack. True if it may go ahead.
func request_attack(e) -> bool:
	if e in attackers or e.challenged_t > 0.0:  # Challenged foes come at you regardless
		return true
	if not can_attack():
		return false
	attackers.append(e)
	return true


func release_attack(e) -> void:
	attackers.erase(e)


func menu_open() -> bool:
	return menu != null and menu.is_open()


# --- dev tool ----------------------------------------------------------------

## Puts a bond on a body part at a step ("" removes the mark). Saved.
func dev_set_mark(part: String, id: String, step: int) -> void:
	if id == "":
		profile.bonds.erase(part)
	else:
		profile.bonds[part] = {"id": id, "xp": ProfileScript.STEP_XP[clampi(step, 1, 5) - 1], "faint": false, "debt": 0.0}
		profile.soak.erase(part)
		profile.regarded = true
		first_climb = false
	profile.save()
	_give_bonds()
	if player.bonds.has(part):
		player.bonds[part].essence = player.bonds[part].capacity()


## Moves the climb to another tower's floor 1.
func dev_tower(id: String) -> void:
	if choosing_tower:
		choose_tower(id)
		return
	tower = id
	profile.last_tower = id
	profile.save()
	_apply_tower_look()
	_start_floor(1)
	_greet()


func dev_floor(n: int) -> void:
	if choosing_tower:
		choose_tower(tower)
	_start_floor(n)


## A monster near the climber, inside the room.
func dev_spawn(kind: String):
	var pos: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * 200.0
	pos = pos.clamp(room.position + Vector2(50, 50), room.end - Vector2(50, 50))
	return spawn_enemy(kind, pos)


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(
		func(e): return is_instance_valid(e) and not e.dead)


## Adds a monster to the room (bosses calling help, tests).
## Monsters that can be aimed at (not a lurker under the water).
func targets() -> Array:
	return enemies().filter(func(e): return not e.submerged)


func spawn_enemy(kind: String, pos: Vector2):
	var e = EnemyScript.new()
	e.setup(kind, self)
	var tough := Floors.toughness(floor_num)
	e.max_hp *= tough.x
	e.hp = e.max_hp
	e.dmg *= tough.y
	e.position = pos
	e.state_t = 0.4
	add_child(e)
	return e


# --- Tidecaller's waves and standing water ----------------------------------------

func add_wave(origin: Vector2, dir: Vector2, width: float, travel: float, dmg: float, push: float, carry: bool, color: Color) -> void:
	waves.append({"pos": origin + dir * 16.0, "dir": dir, "width": width, "left": travel, "dmg": dmg, "push": push, "carry": carry, "hit": [], "color": color})


## Waves roll forward. An aimed surge shoves each foe it meets once; Carry
## sweeps foes along with it until they break against a wall or pillar.
func _update_waves(delta: float) -> void:
	for w in waves:
		var step := 520.0 * delta
		w["left"] -= step
		var dir: Vector2 = w["dir"]
		var side := dir.orthogonal()
		w["pos"] += dir * step
		for e in enemies():
			var rel: Vector2 = e.global_position - w["pos"]
			if absf(rel.dot(side)) > w["width"] * 0.5 + e.radius:
				continue
			var along := rel.dot(dir)
			if along < -e.radius - step or along > e.radius + 10.0:
				continue
			if w["carry"]:
				if not (e in w["hit"]):
					w["hit"].append(e)
				var col = e.move_and_collide(dir * step)
				if col != null:
					_break_against_wall(e, w)
			elif not (e in w["hit"]):
				w["hit"].append(e)
				e.tide_push(dir * w["push"])
				e.take_hit(w["dmg"], dir, w["push"])
		if not room.grow(-10.0).has_point(w["pos"]) or w["left"] <= 0.0:
			if w["carry"]:
				for e in w["hit"]:
					if is_instance_valid(e) and not e.dead and e.global_position.distance_to(w["pos"]) < w["width"]:
						_break_against_wall(e, w)
			w["left"] = -1.0
	waves = waves.filter(func(w): return w["left"] > 0.0)


func _break_against_wall(e, w: Dictionary) -> void:
	if e in w.get("broken", []):
		return
	if not w.has("broken"):
		w["broken"] = []
	w["broken"].append(e)
	fx_burst(e.global_position, -w["dir"], w["color"], 10, 220.0)
	sfx("hit_heavy", 0.8, -2.0)
	e.take_hit(w["dmg"], Vector2.ZERO, 0.0, true)
	if player.has_bond("tidecaller"):
		e.stagger(1.2)  # Undercurrent: driven into a wall, stunned


## Rune Artist's fields: traps that go off under foes, circles foes can't enter.
func _update_runes(delta: float) -> void:
	for w in wards:
		w["t"] -= delta
	wards = wards.filter(func(w): return w["t"] > 0.0)
	for s in sigils:
		s["t"] -= delta
	sigils = sigils.filter(func(s): return s["t"] > 0.0)
	for w in wards:
		for e in enemies():
			var to: Vector2 = e.global_position - w["pos"]
			var edge: float = w["r"] + e.radius
			if to.length() < edge:
				var out := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
				e.global_position = w["pos"] + out * edge
				e.knock = out * 140.0
	for r in runes:
		r["t"] -= delta
	runes = runes.filter(func(r): return r["t"] > 0.0)
	var fired := false
	for r in runes:
		for e in targets():
			if e.global_position.distance_to(r["pos"]) < r["r"] + e.radius:
				fired = true
				r["fire"] = true
				if r["linked"]:
					for other in runes:
						other["fire"] = true
				break
	if fired:
		for r in runes.filter(func(x): return x.get("fire", false)):
			_detonate_rune(r)
		runes = runes.filter(func(x): return not x.get("fire", false))


func _detonate_rune(r: Dictionary) -> void:
	for e in targets():
		var to: Vector2 = e.global_position - r["pos"]
		if to.length() < r["blast"] + e.radius:
			e.take_hit(r["damage"], to.normalized(), 180.0, true)
			if not e.dead:
				e.stagger(0.6)
	fx_ring(r["pos"], r["color"], r["blast"], 0.35, 5.0)
	fx_burst(r["pos"], Vector2.ZERO, r["color"], 14, 260.0)
	light_flash(r["pos"], r["color"], 1.3, 1.4, 0.3)
	sfx("zap", 0.8)
	shake(4.0)


## Sandshaper's walls: a row of stones that blocks foes (not you) and their shots.
func add_stone_wall(points: Array, r: float, t: float, fault := false) -> void:
	for pt in points:
		var pos: Vector2 = pt
		if not room.has_point(pos):
			continue
		var body := StaticBody2D.new()
		body.collision_layer = 8  # only monsters collide with these
		body.collision_mask = 0
		body.position = pos
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = r
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		stone_walls.append({"pos": pos, "r": r, "t": t, "body": body, "fault": fault})


func blocks_shot(pos: Vector2) -> bool:
	for w in stone_walls:
		if pos.distance_to(w["pos"]) < w["r"] + 3.0:
			return true
	return false


func _update_ground(delta: float) -> void:
	for w in stone_walls:
		w["t"] -= delta
		if w["t"] <= 0.0 and is_instance_valid(w["body"]):
			w["body"].queue_free()
	stone_walls = stone_walls.filter(func(w): return w["t"] > 0.0)
	for list in [rubble, pits, smokes, decoys]:
		for x in list:
			x["t"] -= delta
	rubble = rubble.filter(func(x): return x["t"] > 0.0)
	pits = pits.filter(func(x): return x["t"] > 0.0)
	smokes = smokes.filter(func(x): return x["t"] > 0.0)
	decoys = decoys.filter(func(x): return x["t"] > 0.0)
	ashfall_t -= delta
	# Toxic Clouds poison foes inside them, a stack every half second.
	for c in clouds:
		c["t"] -= delta
		c["tick"] -= delta
		if c["tick"] <= 0.0:
			c["tick"] = 0.5
			for e in targets():
				if e.global_position.distance_to(c["pos"]) < c["r"] + e.radius:
					e.add_venom(1)
	clouds = clouds.filter(func(c): return c["t"] > 0.0)
	# Smoke and decoys: foes lose track of you.
	for e in enemies():
		if e.is_boss():
			continue
		for sm in smokes:
			if e.global_position.distance_to(sm["pos"]) < sm["r"] + e.radius:
				e.lose_track(0.6, null)
		for d in decoys:
			if e.global_position.distance_to(d["pos"]) < 320.0:
				e.lose_track(0.4, d)
				if e.global_position.distance_to(d["pos"]) < e.radius + 14.0 and d["t"] > 0.8:
					d["t"] = 0.8  # struck: the ash copy crumbles
					fx_burst(d["pos"], Vector2.ZERO, Color(0.6, 0.55, 0.55), 12, 180.0)


## How much rubble slows a foe here (1 is not at all).
func rubble_slow(pos: Vector2) -> float:
	for r in rubble:
		if pos.distance_to(r["pos"]) < r["r"]:
			return 0.5
	return 1.0


func in_sigil(pos: Vector2) -> bool:
	for s in sigils:
		if pos.distance_to(s["pos"]) < s["r"]:
			return true
	return false


## Burning floor: hurts the climber standing in it, a little at a time.
func add_flame(pos: Vector2, r: float, t: float) -> void:
	flames.append({"pos": pos, "r": r, "t": t, "max": t})


func _update_flames(delta: float) -> void:
	for f in flames:
		f["t"] -= delta
	flames = flames.filter(func(f): return f["t"] > 0.0)
	if player == null or player.dead:
		return
	for f in flames:
		if player.global_position.distance_to(f["pos"]) < f["r"] + player.radius * 0.5:
			player.stand_in_fire(delta)
			break


## Gaps in the floor. Walking monsters can't enter them (they collide with
## them on layer 16); fliers cross; the climber falls in unless jumping.
func set_chasms(list: Array) -> void:
	for b in chasm_bodies:
		b.queue_free()
	chasm_bodies.clear()
	chasms = list
	for r in chasms:
		var rect: Rect2 = r
		var body := StaticBody2D.new()
		body.collision_layer = 16
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		chasm_bodies.append(body)
	room_view.set_chasms(chasms)


func in_chasm(pos: Vector2) -> bool:
	for r in chasms:
		if r.has_point(pos):
			return true
	return false


func in_water(pos: Vector2) -> bool:
	for pd in puddles:
		if pos.distance_to(pd["pos"]) < pd["r"]:
			return true
	return false


## Water slows you (unless you're Waterborn).
func water_slow(pos: Vector2, waterborn := false) -> float:
	return 1.0 if waterborn or not in_water(pos) else 0.6


func spawn_projectile(pos: Vector2, vel: Vector2, dmg: float) -> Node2D:
	var p = ProjectileScript.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.dmg = dmg
	add_child(p)
	return p


func spawn_player_arrow(pos: Vector2, vel: Vector2, dmg: float, force: float, pierce: bool) -> Node2D:
	var p = spawn_projectile(pos, vel, dmg)
	p.friendly = true
	p.force = force
	p.pierce = pierce
	p.life = 1.6
	return p


func on_enemy_killed(e) -> void:
	# Overcharge: a charged foe's death throws lightning to everything near it.
	if e.overcharge_t > 0.0:
		var pts: Array = []
		for o in enemies():
			if o != e and o.global_position.distance_to(e.global_position) < e.overcharge_r:
				fx_bolt([e.global_position, o.global_position], Color(0.95, 0.89, 0.42))
				pts.append(o)
		for o in pts:
			o.take_hit(e.overcharge_dmg, Vector2.ZERO)
		light_flash(e.global_position, Color(0.95, 0.89, 0.42), 1.6, 1.8, 0.35)
		sfx("zap", 0.9)
	var drop: Array = Essence.drop_for(e.kind, floor_num)
	gather_essence(drop[0], drop[1], e.global_position)
	# Every kill also yields a little of the tower's own essence.
	gather_essence(tower_data()["essence"], Towers.ESSENCE_BONUS, e.global_position)
	fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))
	fx_ring(e.global_position, e.color, 46.0, 0.4, 4.0)
	fx_burst(e.global_position, Vector2.ZERO, e.color, 16, 300.0)
	if fx != null:
		fx.debris(e.global_position, e.color, int(e.radius * 0.8))
	var kill_sound: String = "kill_" + e.kind
	sfx(kill_sound if audio != null and audio.has_sound(kill_sound) else "kill")
	hitstop(0.09)
	shake(6.0)


## Hit-pause: freeze the action for a moment so impacts land.
## Overlapping calls keep the longest freeze.
func hitstop(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until > hitstop_until:
		hitstop_until = until
	Engine.time_scale = 0.02


## Time slows while you pick a spell from a mark's ring.
func set_slowmo(on: bool) -> void:
	slowmo = on
	if hitstop_until == 0:
		Engine.time_scale = 0.35 if on else 1.0


func sfx(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.06) -> void:
	if audio != null:
		audio.play(sound, pitch, volume_db, variance)


func fx_ring(pos: Vector2, color: Color, reach: float, dur := 0.3, width := 3.0) -> void:
	if fx != null:
		fx.ring(pos, color, reach, dur, width)


func fx_burst(pos: Vector2, dir: Vector2, color: Color, count: int, speed := 260.0) -> void:
	if fx != null:
		fx.burst(pos, dir, color, count, speed)


func fx_ghost(pos: Vector2, radius: float, color: Color) -> void:
	if fx != null:
		fx.ghost(pos, radius, color)


func fx_text(pos: Vector2, s: String, color: Color) -> void:
	if fx != null:
		fx.text(pos, s, color)


func fx_bolt(points: Array, color: Color) -> void:
	if fx != null:
		fx.bolt(points, color)


func fx_cone(origin: Vector2, dir: Vector2, reach: float, half: float, color: Color) -> void:
	if fx != null:
		fx.cone(origin, dir, reach, half, color)


func shake(amount: float) -> void:
	if not MenuScript.settings["shake"]:
		return
	shake_amount = maxf(shake_amount, amount)


## A brief burst of real light: lightning, parries, crits, burns.
func light_flash(pos: Vector2, color: Color, size := 1.5, energy := 1.6, dur := 0.25) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = size
	l.color = color
	l.energy = energy
	l.position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
