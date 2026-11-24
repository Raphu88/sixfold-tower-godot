extends Node2D
## PORTALS: one design everywhere (draw_portal below: a ring of dark stone
## with six notches round a swirl of light), in every tower, in pocket
## dimensions and when a Maker draws you away.
##
## THE FLOOR'S PORTALS (floors.gd plans them: always one in the entrance and
## one in the stair hall, the rest spread out; 3 a floor, 6 from floor 10;
## none on floor 1, the Proving's floor 6, a camp or the summit)
## connect places on the SAME floor, never floor to floor. They stay ASLEEP
## (grey stone, a dim swirl barely turning) until the climber completes a
## challenge (the floor's task, a sealed wing where the Regard watches, the
## gallery's optional puzzle) or kills every creature on the floor (WAKE).
## Then every portal on the floor WAKES at once. Step onto a woken portal and
## the floor map opens (floor_map.gd): choose another woken portal and you
## step out of it. The map (O, the pause menu's Floor map, or the Map button
## on a phone) shows the rooms you've seen and the portals.
##
## POCKET DIMENSIONS (a secret room, wings.gd and vaults.gd): a room with no
## way to it on foot. A hidden spot in a wall opens a portal when leaned on
## or broken; through it, the pocket and its vault; a portal inside leads
## back to where you came in. The floor waits as it was: while you're in a
## pocket, the floor's monsters stand still, the fog shows only the pocket
## (fog.gd pocket), and a Keeper or mimic left in a pocket waits there too.
##
## A MAKER'S PORTAL (makers.gd, maker_view.gd): a Maker meets you in a pocket
## dimension of its own: a portal opens beside you and draws you in (drawn
## by maker_view.gd), and when the meeting ends you step back out of one
## (maker_return).
##
## Words and numbers: TEXT, RULES, WAKE, LOOK (the Data editor).

const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")
const Floors := preload("res://scripts/floors.gd")

static var TEXT := {
	"asleep": "The portal sleeps",
	"asleep_line": "It wakes when you complete a challenge on this floor, or slay every creature on it.",
	"wake_title": "THE PORTALS WAKE",
	"wake": "Step onto a portal to travel to another on this floor.",
	"wake_also": "The floor's portals wake: step onto one to travel.",
	"why_task": "The floor's task is done.",
	"why_wing": "The Regard's challenge is met.",
	"why_puzzle": "The puzzle is solved.",
	"why_cleared": "Every creature here has fallen.",
	"why_dev": "Woken by the dev tools.",
	"shut": "The doors are shut: the portal won't answer until they open.",
	"busy": "Not while the Regard tests you.",
	"pocket_in": "A POCKET DIMENSION",
	"pocket_in_line": "A room outside the floor. The floor waits as it was. The portal behind you leads back.",
	"pocket_out": "Back on the floor",
	"travel": "Through the portal",
	"maker_back": "The portal lets you go",
}

## radius: a portal's size (px); step_on: how near its middle you must step
## (px); rearm: how far you must step away before a portal answers again;
## light: its glow (asleep, awake); redraw: redraws a second while one is on
## screen; pocket_light: the light that fills an opened pocket.
static var RULES := {"radius": 24.0, "step_on": 18.0, "rearm": 46.0, "light_asleep": 0.25, "light_awake": 0.6, "redraw": 30.0,
	"pocket_light": 0.55, "arrive": 46.0, "hold_every": 0.2}

## What wakes the floor's portals (true: it does).
static var WAKE := {"task": true, "wing": true, "puzzle": true, "cleared": true}

## The one look: stone, the swirl awake and asleep, sparks.
static var LOOK := {"stone": Color(0.22, 0.2, 0.27), "stone_hi": Color(0.4, 0.37, 0.46), "notch": Color(0.08, 0.07, 0.1),
	"swirl": Color(0.62, 0.52, 1.0), "core": Color(0.12, 0.08, 0.24), "spark": Color(0.92, 0.88, 1.0),
	"sleep": Color(0.42, 0.4, 0.5), "sleep_core": Color(0.1, 0.09, 0.13)}

var main
var list: Array = []  # the floor's portals: {pos, room, seen, light}
var awake := false
var woke_why := ""
var armed := true  # (step off a portal before one answers again)
var pocket := {}  # the pocket dimension the climber is in (a wings.secrets record), or {}
var map  # the floor map (floor_map.gd) while it's open
var map_layer: CanvasLayer
## Stepping onto a woken portal opens the map by itself (the floor bot and
## most tests switch it off; tests/parts/portals.gd switches it on).
var auto_travel := not Engine.has_meta("sixfold_test")
var held: Array = []  # monsters held still because they're in the other place (the floor or a pocket)
var closing: Array = []  # portals closing behind someone: {pos, t}
var travels := 0  # (tests)
var told_t := 0.0
var _hold_t := 0.0
var _redraw_t := 0.0
var _last_space := ""


func _ready() -> void:
	z_index = -3  # on the floor, under everyone


# --- a new floor --------------------------------------------------------------------

func setup(plan: Dictionary) -> void:
	clear()
	# (None on the Proving's floor, where the first climb's Regard opens too:
	# a set piece walked in order. floors.gd portals_on plans none there.)
	if main == null or not main.layout_on or plan.get("proving", false) or not Floors.portals_on(int(main.floor_num)):
		return
	for p in plan.get("portals", []):
		var pt := {"pos": p["pos"], "room": int(p.get("room", -1)), "seen": false, "light": -1}
		if main.lighting != null:
			pt["light"] = main.lighting.add_light(pt["pos"], 80.0, LOOK["sleep"], float(RULES["light_asleep"]), 0.1)
		list.append(pt)
	queue_redraw()


func clear() -> void:
	close_map()
	if not pocket.is_empty() and main != null and main.fog != null:
		main.fog.pocket = Rect2i()  # (fog.gd reset follows on a new floor)
	pocket = {}
	_last_space = ""
	_release_held()
	for pt in list:
		if int(pt.get("light", -1)) >= 0 and main != null and main.lighting != null:
			main.lighting.remove_light(pt["light"])
	list.clear()
	awake = false
	woke_why = ""
	armed = true
	closing.clear()
	queue_redraw()


# --- waking --------------------------------------------------------------------------

## A challenge done (or the floor cleared): every portal on the floor wakes.
## `why`: task, wing, puzzle, cleared (WAKE says which count).
func wake(why: String) -> bool:
	if awake or list.is_empty() or (why != "dev" and not bool(WAKE.get(why, false))):
		return false
	awake = true
	woke_why = why
	for pt in list:
		if int(pt["light"]) >= 0 and main.lighting.lights.has(pt["light"]):
			main.lighting.remove_light(pt["light"])
		pt["light"] = main.lighting.add_light(pt["pos"], 110.0, LOOK["swirl"], float(RULES["light_awake"]), 0.3)
		main.fx_ring(pt["pos"], LOOK["swirl"], 70.0, 0.6, 3.0)
	var lines: Array = []
	if TEXT.has("why_" + why):
		lines.append(TEXT["why_" + why])
	lines.append(TEXT["wake"])
	if main.banner.is_empty() or why == "cleared":
		main.banner = {"title": TEXT["wake_title"], "lines": lines, "t": 3.2}
	else:
		# (the challenge just said its piece: the portals add a line under it)
		var b: Dictionary = main.banner
		b["lines"] = Array(b.get("lines", [])) + [TEXT["wake_also"]]
		b["t"] = maxf(float(b.get("t", 0.0)), 3.2)
		main.banner = b
	main.sfx("rift", 0.8, -4.0, 0.0)
	main.sfx("glint", 0.6, -6.0, 0.0)
	main.tip("portal_awake")
	queue_redraw()
	return true


# --- each frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or main.player == null or not main.layout_on:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	told_t -= delta
	if main.cleared and not awake and not list.is_empty():
		wake("cleared")
	# Which place the climber is in: the floor, or a pocket.
	var space := space_of(pos)
	if space != _last_space:
		_last_space = space
		_set_pocket(_secret(space))
	# A portal answers only once you've stepped off the last one.
	if not armed and _far_from_all(pos):
		armed = true
	var busy: bool = p.dead or main.climbing or main.camp_choosing or main.in_camp or map_open() or main.menu_open() or get_tree().paused
	if armed and not busy:
		_check_portals(pos)
	# The floor's portals seen (the map shows them; the Entity mentions the first).
	if main.fog != null:
		for pt in list:
			if not pt["seen"] and main.fog.sees(pt["pos"]):
				pt["seen"] = true
				if not awake:
					main.tip("portal")
	_hold_t -= delta
	if _hold_t <= 0.0:
		_hold_t = float(RULES["hold_every"])
		_hold()
	for c in closing:
		c["t"] = float(c["t"]) - delta
	closing = closing.filter(func(c): return float(c["t"]) > 0.0)
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 1.0 / float(RULES["redraw"])
		if _on_screen():
			queue_redraw()


func _check_portals(pos: Vector2) -> void:
	var near: float = float(RULES["step_on"]) + main.player.radius * 0.5
	if main.player.knock.length() > 80.0:
		return  # (a blow doesn't throw you through a portal: you step in yourself)
	var W = main.wings
	# A pocket's portals: in from the floor, back out from inside.
	if W != null:
		for s in W.secrets:
			if not s["open"] or not s.has("portal_out"):
				continue
			if pocket.is_empty() and pos.distance_to(s["portal_out"]) < near:
				enter_pocket(s)
				return
			if is_same(pocket, s) and pos.distance_to(s["portal_in"]) < near:
				leave_pocket()
				return
	if not pocket.is_empty():
		return
	for i in list.size():
		if pos.distance_to(list[i]["pos"]) >= near:
			continue
		armed = false
		if not awake:
			if told_t <= 0.0:
				told_t = 2.0
				main.fx_text(list[i]["pos"] + Vector2(0, -36), TEXT["asleep"], LOOK["sleep"].lightened(0.4))
				main.banner = {"title": String(TEXT["asleep"]).to_upper(), "lines": [TEXT["asleep_line"]], "t": 2.6}
			main.tip("portal")
			return
		var why := travel_block()
		if why != "":
			main.fx_text(list[i]["pos"] + Vector2(0, -36), why, LOOK["sleep"].lightened(0.4))
			return
		if auto_travel:
			open_map(i)
		return


## Why the portals won't take you now ("" when they will).
func travel_block() -> String:
	if not awake:
		return TEXT["asleep"]
	if main.wings != null and main.wings.challenge_live():
		return TEXT["busy"]
	var dv = main.door_view
	if dv != null:
		for i in dv.lock_rooms:
			if String(dv.lock_rooms[i].get("state", "")) == "shut":
				return TEXT["shut"]
	return ""


## The portal the climber stands on (-1 if none).
func portal_here() -> int:
	if main.player == null:
		return -1
	for i in list.size():
		if main.player.global_position.distance_to(list[i]["pos"]) < float(RULES["step_on"]) + main.player.radius:
			return i
	return -1


## Travel from one woken portal to another (the floor map calls it).
func travel(to: int) -> bool:
	if to < 0 or to >= list.size() or travel_block() != "" or not pocket.is_empty():
		return false
	var from: Vector2 = main.player.global_position
	_burst(from)
	_move_player(list[to]["pos"])
	armed = false
	travels += 1
	_burst(list[to]["pos"])
	main.sfx("rift", 1.1, -2.0, 0.0)
	main.fx_text(list[to]["pos"] + Vector2(0, -40), TEXT["travel"], LOOK["swirl"].lightened(0.3))
	return true


# --- pocket dimensions -------------------------------------------------------------------

## "" on the floor, or the id of the pocket dimension `pos` is in.
func space_of(pos: Vector2) -> String:
	var W = main.wings
	if W == null:
		return ""
	for s in W.secrets:
		if s["open"] and s["rect"].grow(6.0).has_point(pos):
			return String(s["id"])
	return ""


func in_pocket() -> bool:
	return not pocket.is_empty()


func _secret(id: String) -> Dictionary:
	if id == "" or main.wings == null:
		return {}
	for s in main.wings.secrets:
		if String(s["id"]) == id:
			return s
	return {}


## Through a pocket's portal: into the room outside the floor.
func enter_pocket(s: Dictionary) -> void:
	_burst(s["portal_out"])
	_move_player(s["portal_in"] + Vector2(0, -float(RULES["arrive"])))
	armed = false
	_last_space = String(s["id"])
	_set_pocket(s)
	_burst(s["portal_in"])
	main.sfx("rift", 0.9, -2.0, 0.0)
	main.sfx("secret_pass", 1.0, -6.0, 0.0)
	main.banner = {"title": TEXT["pocket_in"], "lines": [TEXT["pocket_in_line"]], "t": 2.6}
	main.tip("pocket")
	if main.get("vaults") != null:
		main.vaults.on_enter(s)


## Back through the pocket's portal: onto the floor, where you came in.
func leave_pocket() -> void:
	var s := pocket
	if s.is_empty():
		return
	_burst(s["portal_in"])
	var front: Vector2 = s["portal_out"] - Vector2(s["into"]) * float(RULES["arrive"])
	_move_player(front)
	armed = false
	_last_space = ""
	_set_pocket({})
	_burst(s["portal_out"])
	main.sfx("rift", 1.0, -2.0, 0.0)
	main.fx_text(front + Vector2(0, -40), TEXT["pocket_out"], LOOK["swirl"].lightened(0.3))


func _set_pocket(s: Dictionary) -> void:
	pocket = s
	if main.fog != null:
		main.fog.away = []
		if main.wings != null:
			for o in main.wings.secrets:
				if o["open"]:
					main.fog.away.append(main.Floors.tile_rect(o["rect"]).grow(1))
		main.fog.set_pocket(main.Floors.tile_rect(s["rect"]).grow(1) if not s.is_empty() else Rect2i())
	_hold()


## The fog learns which pockets are open (fog.gd away).
func refresh_fog() -> void:
	_set_pocket(pocket)


## The floor waits as it was: monsters in the other place stand still.
func _hold() -> void:
	var here := space_of(main.player.global_position) if main.player != null else ""
	for e in main.enemies():
		if not is_instance_valid(e) or e.dead:
			continue
		var away := space_of(e.global_position) != here
		if away and e.is_physics_processing():
			e.set_physics_process(false)
			e.velocity = Vector2.ZERO
			held.append(e)
		elif not away and e in held:
			e.set_physics_process(true)
			held.erase(e)
	held = held.filter(func(e): return is_instance_valid(e))


func _release_held() -> void:
	for e in held:
		if is_instance_valid(e):
			e.set_physics_process(true)
	held.clear()


func _move_player(to: Vector2) -> void:
	var p = main.player
	p.global_position = to
	p.velocity = Vector2.ZERO
	p.last_safe = to
	p.reset_physics_interpolation()
	main.cam_prev = to
	main.cam_curr = to
	if main.camera != null:
		main.camera.position = to
		main.camera.reset_smoothing()
	if main.fog != null:
		main.fog.last_tile = Vector2i(-999, -999)
	main.room_tile = Vector2i(-999, -999)


func _far_from_all(pos: Vector2) -> bool:
	var far := float(RULES["rearm"])
	for pt in list:
		if pos.distance_to(pt["pos"]) < far:
			return false
	if main.wings != null:
		for s in main.wings.secrets:
			if s["open"] and s.has("portal_out") and (pos.distance_to(s["portal_out"]) < far or pos.distance_to(s["portal_in"]) < far):
				return false
	return true


func _burst(at: Vector2) -> void:
	main.fx_ring(at, LOOK["swirl"], 60.0, 0.45, 3.0)
	main.fx_burst(at, Vector2.ZERO, LOOK["swirl"].lightened(0.3), 14, 140.0)
	main.light_flash(at, LOOK["swirl"], 1.4, 1.4, 0.35)


# --- a Maker's portal ---------------------------------------------------------------------

## The Maker's meeting is over (makers.gd end_meeting): the climber steps out
## of a portal that closes behind them.
func maker_return() -> void:
	if main.player == null:
		return
	var at: Vector2 = main.player.global_position + Vector2(0, -6)
	closing.append({"pos": at, "t": 1.2})
	_burst(at)
	main.fx_text(at + Vector2(0, -44), TEXT["maker_back"], LOOK["swirl"].lightened(0.3))
	main.sfx("rift", 0.7, -4.0, 0.0)
	main.tip("maker_portal")
	queue_redraw()


# --- the floor map ---------------------------------------------------------------------------

## The map can be opened (a floor of rooms, in a climb, nothing else showing).
func map_ready() -> bool:
	return main != null and main.layout_on and not main.room_info.is_empty() and not main.in_camp and not main.on_train \
		and main.player != null and not main.player.dead and not main.climbing and not main.camp_choosing \
		and not (main.practice != null and main.practice.on) and not (main.arena != null and main.arena.on) and not main.overlay_showing() and not main.menu_open() and (main.makers == null or not main.makers.meeting_live())


func map_open() -> bool:
	return map != null and is_instance_valid(map)


## Opens the floor map; `from` a portal index to travel from it (-1: only to look).
func open_map(from := -1) -> bool:
	if map_open() or not map_ready():
		return false
	map_layer = CanvasLayer.new()
	map_layer.layer = 9  # over the HUD and the touch buttons, under the menu (10)
	map_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(map_layer)
	map = load("res://scripts/floor_map.gd").new()
	map.main = main
	map.portals = self
	map.from = from
	map_layer.add_child(map)
	if main.player != null:
		main.player.velocity = Vector2.ZERO
	get_tree().paused = true
	main.sfx("ui_open", 1.0, -4.0, 0.0)
	main.tip("floor_map")
	return true


func close_map() -> void:
	if map_open():
		map.queue_free()
	if map_layer != null and is_instance_valid(map_layer):
		map_layer.queue_free()
	var was := map != null
	map = null
	map_layer = null
	if was and main != null and not main.menu_open() and (main.makers == null or not main.makers.meeting_live()):
		get_tree().paused = false
		main.overlay_closed_frame = Engine.get_process_frames()  # (so the Esc that closed it doesn't open the menu)


# --- drawing ---------------------------------------------------------------------------------

func _on_screen() -> bool:
	var cam: Camera2D = main.camera
	if cam == null:
		return true
	var size := get_viewport_rect().size / cam.zoom
	var view := Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(80.0)
	for pt in list:
		if view.has_point(pt["pos"]):
			return true
	if main.wings != null:
		for s in main.wings.secrets:
			if s["open"] and s.has("portal_out") and (view.has_point(s["portal_out"]) or view.has_point(s["portal_in"])):
				return true
	return not closing.is_empty()


func _draw() -> void:
	if main == null or not main.layout_on:
		return
	var t := Time.get_ticks_msec() * 0.001
	var r := float(RULES["radius"])
	for pt in list:
		draw_portal(self, pt["pos"], r, t, awake)
	if main.wings != null:
		for s in main.wings.secrets:
			if s["open"] and s.has("portal_out"):
				draw_portal(self, s["portal_out"], r * 0.82, t, true)
				draw_portal(self, s["portal_in"], r, t, true)
	for c in closing:
		var k := clampf(float(c["t"]) / 1.2, 0.0, 1.0)
		draw_portal(self, c["pos"], r * k, t, true, k)


## A PORTAL, the one design: a ring of dark stone with six notches round a
## swirl. Awake, the swirl turns fast in violet light with sparks circling;
## asleep, the stone is grey and the swirl barely moves behind a dull film.
## `c` its middle, `r` its radius, `t` the time, `a` fades it.
static func draw_portal(ci: CanvasItem, c: Vector2, r: float, t: float, is_awake: bool, a := 1.0) -> void:
	if r < 1.0 or a <= 0.01:
		return
	var swirl: Color = LOOK["swirl"] if is_awake else LOOK["sleep"]
	var core: Color = LOOK["core"] if is_awake else LOOK["sleep_core"]
	var squash := 0.62  # (seen from above and a little in front: an oval on the floor)
	# Its glow on the floor, and its shadow.
	if is_awake:
		for i in 4:
			ci.draw_colored_polygon(_ring(c, r * (1.5 + 0.18 * i), squash, 28), Color(swirl, 0.05 * a))
	ci.draw_colored_polygon(_ring(c, r * 1.18, squash, 28), Color(0, 0, 0, 0.35 * a))
	# The stone ring.
	ci.draw_colored_polygon(_ring(c, r * 1.12, squash, 28), Color(Palette.OUTLINE, a))
	ci.draw_colored_polygon(_ring(c, r * 1.06, squash, 28), Color(LOOK["stone"], a))
	ci.draw_polyline(_ring(c, r * 1.0, squash, 29).slice(14, 29), Color(LOOK["stone_hi"], 0.8 * a), 2.0, true)
	# The swirl in its well.
	ci.draw_colored_polygon(_ring(c, r * 0.84, squash, 28), Color(core, a))
	var speed := 2.6 if is_awake else 0.25
	for k in 3:
		var arm := PackedVector2Array()
		for i in 16:
			var f := float(i) / 15.0
			var ang := t * speed + k * TAU / 3.0 + f * 3.6
			arm.append(c + Vector2(cos(ang), sin(ang) * squash) * (r * 0.12 + r * 0.7 * f))
		ci.draw_polyline(arm, Color(swirl.lightened(0.25), (0.85 if is_awake else 0.35) * a), maxf(1.2, r * 0.12), true)
	ci.draw_colored_polygon(_ring(c, r * 0.16, squash, 12), Color(swirl.lightened(0.6), (0.9 if is_awake else 0.3) * a))
	if not is_awake:
		ci.draw_colored_polygon(_ring(c, r * 0.84, squash, 28), Color(0.3, 0.29, 0.34, 0.35 * a))  # (the dull film of a sleeping one)
	# Six notches cut in the stone.
	for i in 6:
		var ang := TAU * i / 6.0 + PI / 6.0
		var q := c + Vector2(cos(ang) * r * 0.95, sin(ang) * r * 0.95 * squash)
		ci.draw_circle(q, maxf(1.0, r * 0.08), Color(LOOK["notch"], a))
		if is_awake:
			ci.draw_circle(q, maxf(0.6, r * 0.045), Color(swirl.lightened(0.4), 0.8 * a))
	# Sparks circling a woken one.
	if is_awake:
		for k in 4:
			var ang := -t * 1.6 + k * TAU / 4.0
			var q := c + Vector2(cos(ang) * r * 1.3, sin(ang) * r * 1.3 * squash - r * 0.25)
			ci.draw_circle(q, maxf(1.0, r * 0.08), Color(LOOK["spark"], 0.85 * a))


static func _ring(c: Vector2, rad: float, squash: float, n: int) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		o.append(c + Vector2(cos(ang) * rad, sin(ang) * rad * squash))
	return o
