extends Node2D
## The secret bonds' tools in play (the data and rules are in secret_bonds.gd).
##
## THE TOOL RING: hold B (LB + LT on a controller, the Tools button on a
## phone) and past RING_HOLD a ring of the bond's unlocked tools opens while
## time slows; point at one (the mouse, a stick, or slide your finger) and
## let go to use it. A tap uses the last tool again (or closes an open panel).
## The ring shows each tool's cost as essence gems. Targeted tools aim where
## you were aiming when the ring opened (that target is outlined).
##
## While a tool is used, or its overlay is open, a faint wireframe of the
## workings is drawn in its Maker's colour: the floor's tile grid, trap lanes
## and door hinges (the Designer), monster outlines (the Manipulator), the
## reach of your spells (the Developer).
##
## This node draws in the world over the darkness (z 46); `screen` draws the
## ring and the panels in the HUD layer. Nothing is drawn or run while no tool
## is in use and no overlay is open.

const SB := preload("res://scripts/secret_bonds.gd")
const Secret := preload("res://scripts/secret.gd")
const Traps := preload("res://scripts/traps.gd")
const Draw := preload("res://scripts/draw_util.gd")
const UI := preload("res://scripts/ui.gd")
const Floors := preload("res://scripts/floors.gd")
const Essence := preload("res://scripts/essence.gd")

const RING_HOLD := 0.25
const RING_R := 76.0
## The wireframe lingers this long after a tool is used.
const SHOW_TIME := 1.6
## Trap and door readouts show within this of the climber (after the Designer's Inspect).
const READ_NEAR := 300.0
## A targeted tool picks from this cone around your aim (radians each side), else the nearest.
const AIM_CONE := 0.6
const ESSENCE_GEM := Color(0.93, 0.86, 0.68)
const BAD := Color(1.0, 0.45, 0.4)

var main
var screen: Node2D
# The ring.
var holding := false
var hold_t := 0.0
var ring_open := false
var ring_index := 0
var last_tool := ""
var dir_override := Vector2.ZERO  # touch: the finger's offset from the Tools button
var locked := {}  # tool id -> its target, fixed when the ring opened
# This floor's state.
var plan_seen = null  # the floor (main.floor_plan) these belong to
var paid := {}  # Inspect tools paid this floor (id -> true): using them again is free
var panel := ""  # the screen panel open: "", "plan" (the Designer) or "spells" (the Developer)
var inspected: Array = []  # monsters the Manipulator has read
var feuds := 0  # monsters set against another right now
var show_t := 0.0
var shown = null  # what the last use worked on (outlined while show_t runs)
var used := {}  # tools used (tests)
var message := ""  # the last refusal, in words (tests)
var plan_tex: ImageTexture
var _drew := false
var offs := 0  # traps switched off on this floor (drawn crossed out)
var note_t := 0.0  # a refusal shows over the climber this long
const NOTE_TIME := 2.2
var _feud_t := 0.0
## The depth 3 to 5 tools (edit, reroll, build, splice, write): secret_deep.gd,
## a child of this node.
var deep
var last_paid := {}  # what the last tool took: {flow, essence (kind -> amount)} (a card that can't be done gives it back)


func _ready() -> void:
	z_as_relative = false
	z_index = 46  # over the darkness layer (lighting.gd, 40)
	deep = load("res://scripts/secret_deep.gd").new()
	deep.tools = self
	deep.main = main
	add_child(deep)
	screen = Node2D.new()
	screen.name = "SecretToolsScreen"
	screen.draw.connect(_draw_screen)
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # (the plan's tiles stay crisp)
	var layer: Node = main.hud.get_parent() if main.hud != null else self
	layer.add_child(screen)
	if main.hud != null:
		layer.move_child(screen, main.hud.get_index() + 1)  # over the HUD, under the touch buttons


func _exit_tree() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()


func prof():
	return main.profile


## True while the climber holds a secret bond and could use a tool now.
func ring_ready() -> bool:
	return main.profile != null and SB.has_bond(main.profile) and not main.first_climb


func bond() -> String:
	return SB.bond_of(main.profile)


func tools() -> Array:
	return SB.ring_tools(main.profile)


func _blocked() -> bool:
	var p = main.player
	return p == null or p.dead or main.on_train or main.choosing_tower or main.camp_choosing or main.overlay_showing() or main.menu_open() or main.fade > 0.5


# --- each tick --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	if not is_same(main.floor_plan, plan_seen):
		_new_floor()
	var real := delta / maxf(Engine.time_scale, 0.01)
	show_t = maxf(0.0, show_t - real)
	note_t = maxf(0.0, note_t - real)
	if _blocked() or not ring_ready():
		if ring_open or holding:
			_close_ring()
		holding = false
	else:
		_read_input(real)
	if not inspected.is_empty():
		inspected = inspected.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	if feuds > 0:
		_feud_t -= delta
		if _feud_t <= 0.0:
			_feud_t = 0.25
			count_feuds()
	var on := _active()
	if on or _drew:
		queue_redraw()
		screen.queue_redraw()
	_drew = on


## Anything to draw: the ring, a panel, a recent use, readouts.
func _active() -> bool:
	if main.player == null or not ring_ready():
		return false
	return ring_open or panel != "" or show_t > 0.0 or note_t > 0.0 or not inspected.is_empty() or paid.has("des_inspect") or offs > 0 \
		or (paid.has("dev_inspect") and main.player.pick_open) or deep.active()


func _read_input(real: float) -> void:
	if Input.is_action_just_pressed("tool_ring") and not holding:
		holding = true
		hold_t = 0.0
		ring_open = false
	if not holding:
		return
	if Input.is_action_pressed("tool_ring"):
		hold_t += real
		if not ring_open and hold_t >= RING_HOLD and not tools().is_empty():
			open_ring()
		if ring_open:
			_aim_ring()
		return
	# Let go: use what the ring points at; a tap uses the last tool (or closes a panel).
	holding = false
	if ring_open:
		_aim_ring()
		var list := tools()
		var id: String = list[clampi(ring_index, 0, list.size() - 1)]
		var target = locked.get(id)
		_close_ring()
		use(id, target)
	elif panel != "":
		panel = ""
	else:
		var list := tools()
		if not list.is_empty():
			use(last_tool if last_tool in list and SB.usable_in_climb(last_tool) else list[0])


func open_ring() -> void:
	var list := tools()
	ring_open = true
	ring_index = maxi(0, list.find(last_tool))
	locked = {}
	for id in list:
		var t = _target_for(id)
		if t != null:
			locked[id] = t
	main.set_slowmo(true)
	main.tip("tool_ring")


func _close_ring() -> void:
	if ring_open:
		main.set_slowmo(false)
	ring_open = false
	hold_t = 0.0
	dir_override = Vector2.ZERO


## Points into the open ring: the tool in that direction is highlighted.
func _aim_ring() -> void:
	var p = main.player
	var dir := dir_override
	if dir == Vector2.ZERO and p.stick_aim:
		dir = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if dir == Vector2.ZERO:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		dir *= 100.0
	elif dir == Vector2.ZERO and not p.touch_aim:
		dir = p.get_global_mouse_position() - p.global_position
	var n := tools().size()
	if dir.length() > 18.0 and n > 0:
		ring_index = posmod(int(round((dir.angle() + PI / 2.0) / (TAU / float(n)))), n)


func _new_floor() -> void:
	plan_seen = main.floor_plan
	paid = {}
	panel = ""
	inspected = []
	locked = {}
	feuds = 0
	show_t = 0.0
	shown = null
	plan_tex = null
	offs = 0
	deep.new_floor()


## Counts the monsters set against another (projectile.gd checks it).
func count_feuds() -> void:
	feuds = main.enemies().filter(func(e): return e.feud != null).size()


# --- hooks other scripts call (one line each there; the work is in secret_deep.gd) ---

## A tool's card on the camp's card screen (main.camp_card), and taking one (main.choose_camp).
func card(pick: String) -> Dictionary:
	return deep.card(pick)


func take_card(i: int) -> void:
	deep.take_card(i)


## A spell is about to be cast / was cast (player.gd): the Developer's Splice.
func before_cast(b):
	return deep.before_cast(b)


func after_cast(b, rec) -> void:
	deep.after_cast(b, rec)


## A monster was struck while a spell was cast (enemy.gd take_hit).
func struck(e) -> void:
	if deep._rec != null:
		deep.struck(e)


## A spliced spell's shot struck a monster (projectile.gd).
func splice_hit(e, sp: Dictionary) -> void:
	deep.splice_hit(e, sp)


## A floor is about to be planned / was planned (main.gd): the Designer's Reroll.
func before_build(n: int) -> void:
	deep.before_build(n)


func after_build(plan: Dictionary) -> void:
	deep.after_build(plan)


# --- using a tool -----------------------------------------------------------------

## Uses a tool (`target`: what it works on; else it aims for itself). True if
## it was used (and paid); false with `message` saying why not.
func use(id: String, target = null) -> bool:
	message = ""
	var info: Dictionary = SB.TOOLS.get(id, {})
	if info.is_empty() or not SB.has_tool(main.profile, id):
		return _refuse(SB.TEXT["no_tools"])
	if not SB.usable_in_climb(id):
		return _refuse(SB.TOOLS[id]["name"] + ": " + SB.TEXT["train_only"])
	if target == null or (target is Object and not is_instance_valid(target)):
		target = _target_for(id)
	# What it would do (nothing is paid for a tool that can't work).
	var why := _check(id, target)
	if why != "":
		return _refuse(why)
	# A tool with a choice opens its cards: paid when a card that does something is taken.
	if info.get("cards", false):
		var q0: Dictionary = SB.quote(info["cost"], main.run_essence, main.run_flow, main.profile.path)
		if not q0["ok"]:
			return _refuse(q0["short"])
		if not deep.open(id, target):
			return _refuse(message if message != "" else SB.TEXT["no_target"])
		last_tool = id
		shown = target
		show_t = SHOW_TIME
		main.tip(String(info.get("tip", "")))
		main.sfx("glint", 0.7, -6.0, 0.02)
		return true
	var free: bool = info.get("lasts", "") == "floor" and paid.has(id)
	if not free and not pay(info["cost"]):
		return false
	_apply(id, target)
	last_tool = id
	used[id] = true
	show_t = SHOW_TIME
	shown = target
	main.tip(String(info.get("tip", "")))
	main.sfx("glint", 0.7, -6.0, 0.02)
	queue_redraw()
	screen.queue_redraw()
	return true


## Pays a cost from what the climber carries (shown over them). False (and
## nothing taken, `message` says why) if they can't.
func pay(cost: Dictionary) -> bool:
	var q: Dictionary = SB.quote(cost, main.run_essence, main.run_flow, main.profile.path)
	if not q["ok"]:
		return _refuse(q["short"])
	main.run_flow = maxf(0.0, main.run_flow - float(q["flow"]))
	last_paid = {"flow": float(q["flow"]), "essence": SB.take_essence(main.run_essence, float(q["essence"]))}
	var at: Vector2 = main.player.global_position + Vector2(0, -58)
	if float(q["flow"]) > 0.0:
		main.fx_text(at, SB.TEXT["paid"] % ("%d %s" % [int(round(float(q["flow"]))), Secret.display(main.profile.path)]), Secret.color(main.profile.path))
		at.y -= 18.0
	if float(q["essence"]) > 0.0:
		main.fx_text(at, SB.TEXT["paid"] % ("%d essence" % int(round(float(q["essence"])))), Color(ESSENCE_GEM, 0.95))
	return true


func _refuse(why: String) -> bool:
	message = why
	note_t = NOTE_TIME  # (said on the screen, over the climber)
	main.sfx("ui_move", 0.7, -8.0, 0.0)
	return false


## What a tool aims at by itself: a monster, or a trap or door ({kind, ...}).
func _target_for(id: String):
	match id:
		"man_inspect", "man_calm", "man_feud", "man_edit", "man_build":
			return monster_target(float(SB.TOOLS[id]["reach"]))
		"des_switch":
			return switch_target(float(SB.TOOLS[id]["reach"]))
		"des_edit":
			return switch_target(float(SB.TOOLS[id]["reach"]), true)
		"man_reroll":
			return deep.room_target(float(SB.TOOLS[id]["reach"]))
	return null


## Why a tool can't work on `target` ("" if it can).
func _check(id: String, target) -> String:
	match id:
		"man_inspect":
			if target == null:
				return SB.TEXT["no_target"]
		"man_calm":
			if target == null:
				return SB.TEXT["no_target"]
			if SB.resists(target):
				return SB.TEXT["resists"]
		"man_feud":
			if target == null:
				return SB.TEXT["no_target"]
			if SB.resists(target):
				return SB.TEXT["resists"]
			if feud_partner(target) == null:
				return SB.TEXT["no_pair"]
		"des_switch":
			if target == null:
				return SB.TEXT["no_target"]
			if target.has("door"):
				var d: Dictionary = target["door"]
				if String(d["lock"]) != "":
					return SB.TEXT["locked"]
				if d["open"] and not _doorway_clear(d):
					return SB.TEXT["door_blocked"]
	return ""


func _apply(id: String, target) -> void:
	var col := SB.color(bond())
	match id:
		"dev_inspect":
			if paid.has(id):
				panel = "" if panel == "spells" else "spells"
			else:
				paid[id] = true
				panel = "spells"
		"des_inspect":
			if paid.has(id):
				panel = "" if panel == "plan" else "plan"
			else:
				paid[id] = true
				panel = "plan"
			_build_plan()
		"des_switch":
			switch(target)
		"man_inspect":
			if not target in inspected:
				inspected.append(target)
			main.fx_ring(target.global_position, col, target.radius + 14.0, 0.4, 2.0)
		"man_calm":
			set_calm(target)
		"man_feud":
			set_feud(target, feud_partner(target))


# --- the Designer -------------------------------------------------------------------

## The trap or unlocked door nearest your aim, within reach: {"trap": tr} or {"door": d}.
func switch_target(reach: float, traps_only := false):
	var p = main.player
	var from: Vector2 = p.global_position
	var best = null
	var best_s := INF
	var near = null
	var near_d := INF
	var cands: Array = []
	for tr in main.traps:
		if not tr.get("own", false):
			cands.append([tr["pos"], {"trap": tr}])
	if main.door_view != null and not traps_only:
		for d in main.door_view.list:
			if String(d.get("fixed", "")) == "":
				cands.append([d["rect"].get_center(), {"door": d}])
	for c in cands:
		var to: Vector2 = c[0] - from
		var dist := to.length()
		if dist > reach:
			continue
		var ang := absf(p.aim.angle_to(to)) if dist > 1.0 else 0.0
		if ang < AIM_CONE:
			var s := dist * (1.0 + ang * 2.0)
			if s < best_s:
				best_s = s
				best = c[1]
		if dist < near_d:
			near_d = dist
			near = c[1]
	return best if best != null else near


func _doorway_clear(d: Dictionary) -> bool:
	var rect: Rect2 = d["rect"]
	var p = main.player
	if rect.grow(p.radius).has_point(p.global_position):
		return false
	for e in main.enemies():
		if rect.grow(e.radius).has_point(e.global_position):
			return false
	return true


## Turns a trap off or on, or opens or shuts a door (unlocked; a shut one holds).
func switch(target: Dictionary) -> void:
	var col := SB.color(bond())
	if target.has("trap"):
		var tr: Dictionary = target["trap"]
		var off := not bool(tr.get("off", false))
		tr["off"] = off
		if off:
			tr["state"] = "idle"
			tr["timer"] = Traps.val(tr, "cycle") if String(tr.get("trigger", "")) == "timed" else 0.0
			tr["hit"] = []
		main.fx_text(tr["pos"] + Vector2(0, -26), SB.TEXT["off"] if off else SB.TEXT["on"], col)
		main.fx_ring(tr["pos"], col, 24.0, 0.4, 2.0)
	elif target.has("door"):
		var d: Dictionary = target["door"]
		var at: Vector2 = d["rect"].get_center()
		if d["open"]:
			main.door_view.close_door(d, SB.DOOR_HOLD)
			main.fx_text(at + Vector2(0, -26), SB.TEXT["door_shut"], col)
		else:
			d["held"] = 0.0
			main.door_view.open_door(d)
			main.fx_text(at + Vector2(0, -26), SB.TEXT["door_open"], col)
		main.fx_ring(at, col, 30.0, 0.4, 2.0)
	offs = main.traps.filter(func(t): return t.get("off", false)).size()


## The floor's plan as a tiny image: one pixel a tile (walls clear, floor dark,
## hidden passages and rooms in the Maker's colour).
func _build_plan() -> void:
	if plan_tex != null or not main.layout_on or main.grid_size.x <= 0:
		return
	var gs: Vector2i = main.grid_size
	var img := Image.create(gs.x, gs.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in gs.y:
		for x in gs.x:
			if main.solid[y * gs.x + x] == 0:
				img.set_pixel(x, y, Color(0.32, 0.3, 0.36, 0.95))
	var col := SB.color("designer")
	if main.wings != null:
		for s in main.wings.secrets:
			for t in main.wings._secret_tiles(s):
				if t.x >= 0 and t.y >= 0 and t.x < gs.x and t.y < gs.y:
					img.set_pixel(t.x, t.y, Color(col.darkened(0.35), 0.85))
	if main.door_view != null:
		for d in main.door_view.list:
			for t in d["tiles"]:
				if t.x >= 0 and t.y >= 0 and t.x < gs.x and t.y < gs.y:
					img.set_pixel(t.x, t.y, Color(0.32, 0.3, 0.36, 0.95))
	plan_tex = ImageTexture.create_from_image(img)


# --- the Manipulator -----------------------------------------------------------------

## The monster nearest your aim within reach (one you can see), else the nearest.
func monster_target(reach: float):
	var p = main.player
	var best = null
	var best_s := INF
	var near = null
	var near_d := INF
	for e in main.targets():
		if e.ally or not e.visible:
			continue
		var to: Vector2 = e.global_position - p.global_position
		var dist := to.length()
		if dist > reach:
			continue
		var ang := absf(p.aim.angle_to(to)) if dist > 1.0 else 0.0
		if ang < AIM_CONE:
			var s := dist * (1.0 + ang * 2.0)
			if s < best_s:
				best_s = s
				best = e
		if dist < near_d:
			near_d = dist
			near = e
	return best if best != null else near


## The monster a feud pairs with `e`: the nearest other ordinary one.
func feud_partner(e):
	var best = null
	var best_d := float(SB.TOOLS["man_feud"]["pair"])
	for o in main.targets():
		if o == e or o.ally or SB.resists(o):
			continue
		var d: float = o.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func set_calm(e) -> void:
	e.calm = true
	e.feud = null
	main.release_attack(e)
	main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), SB.TEXT["calm"], SB.color(bond()))
	main.fx_ring(e.global_position, SB.color(bond()), e.radius + 16.0, 0.5, 2.0)


func set_feud(a, b) -> void:
	for pair in [[a, b], [b, a]]:
		var e = pair[0]
		e.feud = pair[1]
		e.feud_t = SB.FEUD_TIME
		e.calm = false
		e.aware = true
		e.notice_t = 0.0
		main.release_attack(e)
	main.fx_text((a.global_position + b.global_position) * 0.5 + Vector2(0, -30), SB.TEXT["feud"], SB.color(bond()))
	count_feuds()


# --- drawing: the world (over the darkness) ------------------------------------------

func _draw() -> void:
	if not _active():
		return
	var p = main.player
	var col := SB.color(bond())
	var font := ThemeDB.fallback_font
	var b := Draw.Batch.new()
	var labels: Array = []  # [pos, text, colour, size]
	var wire := ring_open or panel != "" or show_t > 0.0
	match bond():
		"designer":
			_world_designer(b, labels, col, wire)
		"manipulator":
			_world_manipulator(b, labels, col, wire)
		"developer":
			_world_developer(b, labels, col, wire)
	deep.draw_world(b, labels, col, wire)
	# What a targeted tool will work on (the ring open) or just worked on.
	var t = locked.get(tools()[clampi(ring_index, 0, tools().size() - 1)]) if ring_open and not tools().is_empty() else (shown if show_t > 0.0 else null)
	if t != null:
		_outline_target(b, t, col)
	# A dim plate behind each readout, so it reads over any floor.
	for l in labels:
		var wl := font.get_string_size(l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[3]).x
		b.rect(Rect2(l[0].x + 110.0 - wl * 0.5 - 4.0, l[0].y - l[3] - 1.0, wl + 8.0, l[3] + 5.0), Color(0.02, 0.015, 0.04, 0.5))
	b.flush(self)
	for l in labels:
		draw_string_outline(font, l[0], l[1], HORIZONTAL_ALIGNMENT_CENTER, 220.0, l[3], 3, Color(0, 0, 0, 0.85))
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_CENTER, 220.0, l[3], l[2])


func _outline_target(b, t, col: Color) -> void:
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	if t is Object:
		if is_instance_valid(t):
			b.arc(t.global_position, t.radius + 9.0, 0.0, TAU, 28, Color(col, 0.9 * pulse), 2.0)
	elif t is Dictionary and t.has("trap"):
		_trap_shape(b, t["trap"], Color(col, 0.9 * pulse), 2.0)
	elif t is Dictionary and t.has("door"):
		Traps._outline(b, t["door"]["rect"].grow(4.0), Color(col, 0.9 * pulse), 2.0)
	elif t is int and t >= 0 and t < main.room_info.size():  # a room (the Manipulator's Reroll)
		Traps._outline(b, main.room_info[t]["rect"].grow(-4.0), Color(col, 0.8 * pulse), 2.0)


func _trap_shape(b, tr: Dictionary, c: Color, w: float) -> void:
	if Traps.KINDS[tr["kind"]]["shape"] == "lane":
		Traps._outline(b, Traps.lane_rect(tr), c, w)
	else:
		b.arc(tr["pos"], Traps.val(tr, "reach"), 0.0, TAU, 24, c, w)


func _view_rect() -> Rect2:
	var cam: Camera2D = main.camera
	if cam == null:
		return Rect2(main.player.global_position - Vector2(700, 400), Vector2(1400, 800))
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(40.0)


func _world_designer(b, labels: Array, col: Color, wire: bool) -> void:
	var p = main.player
	var pp: Vector2 = p.global_position
	var c := Floors.CELL
	if wire and main.layout_on:
		# The tile grid around you: the tower's workings.
		var o: Vector2 = main.room.position
		var r := 6
		var t0 := Vector2i(floori((pp.x - o.x) / c) - r, floori((pp.y - o.y) / c) - r)
		var gc := Color(col, 0.12)
		for i in r * 2 + 2:
			var x: float = o.x + (t0.x + i) * c
			var y: float = o.y + (t0.y + i) * c
			b.line(Vector2(x, o.y + t0.y * c), Vector2(x, o.y + (t0.y + r * 2 + 1) * c), gc, 1.0)
			b.line(Vector2(o.x + t0.x * c, y), Vector2(o.x + (t0.x + r * 2 + 1) * c, y), gc, 1.0)
	var view := _view_rect()
	if not paid.has("des_inspect") and not wire:
		for tr in main.traps:  # (traps switched off stay crossed out)
			if tr.get("off", false) and view.has_point(tr["pos"]):
				_cross(b, tr["pos"], Color(col, 0.7))
		return
	var near := READ_NEAR * (1.6 if wire else 1.0)
	var placed: Array = []  # label spots taken (one label for traps side by side)
	for tr in main.traps:
		var at: Vector2 = tr["pos"]
		var off: bool = tr.get("off", false)
		if off and view.has_point(at):
			_cross(b, at, Color(col, 0.7))
		if at.distance_to(pp) > near or not view.has_point(at):
			continue
		var tc := Color(0.6, 0.6, 0.62, 0.8) if off else Color(col, 0.32)
		_trap_shape(b, tr, tc, 1.2)
		if not paid.has("des_inspect"):
			continue
		var k: Dictionary = Traps.KINDS[tr["kind"]]
		if String(tr.get("trigger", k["trigger"])) == "timed" and not off:
			# The beat as a ring that fills toward the next firing.
			var cyc := maxf(Traps.val(tr, "cycle"), 0.1)
			b.arc(at, 9.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - clampf(_time_to_fire(tr) / cyc, 0.0, 1.0)), 18, Color(col, 0.85), 2.0)
		if tr.get("hidden", false):
			b.arc(at, 13.0, 0.0, TAU, 18, Color(1.0, 0.95, 0.8, 0.7), 1.2)
		# One label for a set piece's traps side by side (the same kind close by).
		if placed.any(func(q): return (q[1] == tr["kind"] and q[0].distance_to(at) < 240.0) or (absf(q[0].x - at.x) < 120.0 and absf(q[0].y - at.y) < 30.0)):
			continue
		placed.append([at, tr["kind"]])
		var line := String(k["name"])
		if off:
			line += "  ·  off"
		elif String(tr.get("trigger", k["trigger"])) == "timed":
			line += "  ·  every %ss  ·  next %ss" % [SB._num(Traps.val(tr, "cycle")), SB._num(snappedf(_time_to_fire(tr), 0.1))]
		else:
			line += "  ·  plate"
		if tr.get("own", false):
			line += "  ·  " + SB.TEXT["build_trap_tag"]
		if tr.get("hidden", false):
			line += "  ·  " + SB.TEXT["hidden"]
		labels.append([at + Vector2(-110, -16), line, Color(col.lightened(0.3), 0.95), 10])
	if main.door_view != null:
		for d in main.door_view.list:
			var r2: Rect2 = d["rect"]
			var at2 := r2.get_center()
			if at2.distance_to(pp) > near or not view.has_point(at2):
				continue
			# The hinges: a small ring at each end of the doorway.
			var long := Vector2(r2.size.x * 0.5, 0) if r2.size.x >= r2.size.y else Vector2(0, r2.size.y * 0.5)
			b.arc(at2 - long, 4.0, 0.0, TAU, 12, Color(col, 0.6), 1.5)
			b.arc(at2 + long, 4.0, 0.0, TAU, 12, Color(col, 0.6), 1.5)
			b.line(at2 - long, at2 + long, Color(col, 0.25 if d["open"] else 0.5), 1.0)
			if paid.has("des_inspect"):
				var kind := ""
				if String(d.get("fixed", "")) == "sealed":
					kind = SB.TEXT["wing"]
				elif int(d["room"]) >= 0 and int(d["room"]) < main.room_themes.size():
					kind = SB.room_kind(main.room_themes[int(d["room"])])
				var line2 := (SB.TEXT["door_to"] % kind) if kind != "" else ""
				if float(d.get("held", 0.0)) > 0.0:
					line2 += "  ·  " + SB.TEXT["held"] % int(ceil(float(d["held"])))
				if line2 != "":
					labels.append([at2 + Vector2(-110, -14), line2, Color(col.lightened(0.4), 0.9), 10])
	if main.wings != null and paid.has("des_inspect"):
		for s in main.wings.secrets:
			if s["open"]:
				continue
			var at3: Vector2 = main.wings._tile_center(s["mouth"][0])
			if at3.distance_to(pp) > near:
				continue
			var half := Vector2(c, c) * 0.5
			var rr := Rect2(at3 - half, half * 2.0)
			for i in 4:  # dashed
				var a := rr.position + Vector2(rr.size.x * i / 4.0, 0)
				b.line(a, a + Vector2(rr.size.x / 8.0, 0), Color(col, 0.8), 1.5)
				var a2 := rr.position + Vector2(rr.size.x * i / 4.0, rr.size.y)
				b.line(a2, a2 + Vector2(rr.size.x / 8.0, 0), Color(col, 0.8), 1.5)
			labels.append([at3 + Vector2(-110, -c * 0.5 - 4.0), SB.TEXT["secret_wall"], Color(col.lightened(0.4), 0.95), 10])


func _cross(b, at: Vector2, c: Color) -> void:
	b.line(at + Vector2(-8, -8), at + Vector2(8, 8), c, 2.0)
	b.line(at + Vector2(-8, 8), at + Vector2(8, -8), c, 2.0)


## Seconds until a timed trap next fires.
func _time_to_fire(tr: Dictionary) -> float:
	var t := float(tr["timer"])
	match String(tr["state"]):
		"idle":
			return t + Traps.val(tr, "warn")
		"warn":
			return t
		"fire":
			return 0.0
	return t


func _world_manipulator(b, labels: Array, col: Color, wire: bool) -> void:
	var p = main.player
	if wire:
		for e in main.targets():
			if e.ally or not e.visible:
				continue
			b.arc(e.global_position, e.radius + 4.0, 0.0, TAU, 20, Color(col, 0.28), 1.0)
			b.line(e.global_position + Vector2(-e.radius - 6, 0), e.global_position + Vector2(e.radius + 6, 0), Color(col, 0.18), 1.0)
			b.line(e.global_position + Vector2(0, -e.radius - 6), e.global_position + Vector2(0, e.radius + 6), Color(col, 0.18), 1.0)
	for e in main.enemies():
		if e.calm or e.feud != null:
			var tag: String = SB.TEXT["calm_tag"] if e.calm else SB.TEXT["feud_tag"]
			if e.visible:
				labels.append([e.global_position + Vector2(-110, e.radius + 16.0), tag, Color(col.lightened(0.3), 0.85), 9])
			if e.feud != null and is_instance_valid(e.feud):
				b.line(e.global_position, e.feud.global_position, Color(col, 0.35), 1.0)
	for e in inspected:
		if not e.visible:
			continue
		var at: Vector2 = e.global_position
		b.arc(at, e.radius + 6.0, 0.0, TAU, 24, Color(col, 0.6), 1.4)
		var foe: Vector2 = e.feud.global_position if e.feud != null and is_instance_valid(e.feud) else p.global_position
		var lines: Array = SB.monster_lines(e, at.distance_to(foe), main.floor_num, main.tower)
		var top: Vector2 = at + Vector2(-110, -e.radius - 26.0 - 11.0 * float(lines.size() - 1))
		for i in lines.size():
			var lc := Color(col.lightened(0.45), 0.95)
			if i == lines.size() - 1 and String(lines[i]).begins_with("Now"):
				lc = Color(1.0, 0.75, 0.6)
			labels.append([top + Vector2(0, 11.0 * i), lines[i], lc, 9])


func _world_developer(b, labels: Array, col: Color, wire: bool) -> void:
	var p = main.player
	if not wire and not (p.pick_open and paid.has("dev_inspect")):
		return
	# The reach of the spell on each mark's key (or the one pointed at in a spell ring).
	var pp: Vector2 = p.global_position
	for part in p.bonds:
		var bd = p.bonds[part]
		var sp: Dictionary = bd.spell()
		if p.pick_open and p.pick_part == part:
			var known: Array = bd.spells()
			sp = known[clampi(p.pick_index, 0, known.size() - 1)]
		elif p.pick_open:
			continue
		var reach = null
		var key := ""
		for k in ["reach", "range", "radius"]:
			if reach == null:
				reach = bd.spell_stat(sp, k)
				key = k
		if reach == null or float(reach) <= 0.0:
			continue
		var rc: Color = bd.color()
		b.arc(pp, float(reach), 0.0, TAU, 48, Color(rc, 0.35), 1.2)
		for i in 12:
			var d := Vector2.from_angle(TAU * i / 12.0)
			b.line(pp + d * (float(reach) - 5.0), pp + d * (float(reach) + 5.0), Color(col, 0.35), 1.0)
		labels.append([pp + Vector2(-110, -float(reach) - 4.0), "%s  ·  %s %s" % [sp["name"], key, SB._num(float(reach))], Color(rc.lightened(0.3), 0.9), 9])


# --- drawing: the screen (the ring, the panels) ---------------------------------------

func _draw_screen() -> void:
	if not _active() or main.menu_open():
		return
	var font := ThemeDB.fallback_font
	var view := screen.get_viewport_rect().size
	if panel == "plan":
		_draw_plan(font, view)
	elif panel == "spells":
		_draw_spells(font, view)
	var p = main.player
	if p.pick_open and paid.has("dev_inspect"):
		_draw_pick_numbers(font, view)
	if ring_open:
		_draw_ring(font, view)
	elif note_t > 0.0 and message != "":
		var a := clampf(note_t / 0.4, 0.0, 1.0)
		var c: Vector2 = p.get_global_transform_with_canvas().origin + Vector2(0, -70)
		var w := minf(view.x - 24.0, 420.0)
		var x := clampf(c.x - w * 0.5, 12.0, view.x - w - 12.0)
		screen.draw_string_outline(font, Vector2(x, c.y), message, HORIZONTAL_ALIGNMENT_CENTER, w, 14, 4, Color(0, 0, 0, 0.85 * a))
		screen.draw_string(font, Vector2(x, c.y), message, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(BAD, a))


## The ring: each tool with its cost in gems, the highlighted one described below.
func _draw_ring(font: Font, view: Vector2) -> void:
	var p = main.player
	var list := tools()
	if list.is_empty():
		return
	var col := SB.color(bond())
	var c: Vector2 = p.get_global_transform_with_canvas().origin
	if main.touch_active:
		c = Vector2(view.x * 0.4, view.y * 0.42)
	c = Vector2(clampf(c.x, RING_R + 44.0, view.x - RING_R - 44.0), clampf(c.y, RING_R + 44.0, view.y - RING_R - 110.0))
	var path: String = main.profile.path
	var b := Draw.Batch.new()
	b.dot(c, RING_R + 40.0, Color(0, 0, 0, 0.62))
	b.arc(c, RING_R + 40.0, 0.0, TAU, 48, Color(col, 0.35), 1.5)
	# A faint wireframe in the ring itself: spokes to each tool.
	for i in list.size():
		var a := -PI / 2.0 + TAU * float(i) / float(list.size())
		b.line(c, c + Vector2.from_angle(a) * (RING_R - 26.0), Color(col, 0.18), 1.0)
	b.arc(c, 12.0, 0.0, TAU, 16, Color(col, 0.5), 1.5)
	var texts: Array = []
	for i in list.size():
		var id: String = list[i]
		var info: Dictionary = SB.TOOLS[id]
		var a := -PI / 2.0 + TAU * float(i) / float(list.size())
		var at := c + Vector2.from_angle(a) * RING_R
		var on: bool = i == ring_index
		var here: bool = SB.usable_in_climb(id)
		var r := 25.0 if on else 21.0
		var cc := col if here else Color(0.55, 0.55, 0.6)
		b.dot(at, r, Color(0.05, 0.04, 0.07, 0.94))
		b.arc(at, r, 0.0, TAU, 28, Color(cc, 1.0 if on else 0.5), 3.0 if on else 1.5)
		_tool_icon(b, id, at + Vector2(0, -6), 7.5 if on else 6.5, Color(cc.lightened(0.25), 0.95 if here else 0.6))
		texts.append([at + Vector2(-34, 12), String(info["name"]), Color(cc.lightened(0.3), 1.0) if on else Color(0.8, 0.78, 0.84, 0.85 if here else 0.55), 9])
		# Its cost as gems, under the disc.
		if here:
			var cost: Dictionary = info["cost"]
			var free: bool = info.get("lasts", "") == "floor" and paid.has(id)
			var gx := at + Vector2(0, r + 9.0)
			if deep.used_up(id) != "":
				texts.append([gx + Vector2(-34, 4), "used", Color(0.7, 0.7, 0.75, 0.85), 9])
			elif free:
				texts.append([gx + Vector2(-34, 4), "open", Color(col, 0.9), 9])
			else:
				var gems: Array = []
				if float(cost.get("flow", 0.0)) > 0.0:
					gems.append([SB.flow_color(cost, path), int(cost["flow"])])
				if float(cost.get("essence", 0.0)) > 0.0:
					gems.append([ESSENCE_GEM, int(cost["essence"])])
				var x0 := gx.x - (gems.size() - 1) * 11.0
				for g in gems.size():
					var gp := Vector2(x0 + g * 22.0, gx.y)
					UI.gem_into(b, gp + Vector2(-4, 0), 4.2, gems[g][0])
					texts.append([gp + Vector2(1, 4), str(gems[g][1]), Color(0.95, 0.93, 0.88), 9, true])
		else:
			texts.append([at + Vector2(-34, r + 13.0), SB.TEXT["train_only"], Color(0.7, 0.7, 0.75, 0.8), 8])
	b.flush(screen)
	for t in texts:
		if t.size() > 4:
			screen.draw_string_outline(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[3], 3, Color(0, 0, 0, 0.9))
			screen.draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[3], t[2])
		else:
			screen.draw_string_outline(font, t[0], t[1], HORIZONTAL_ALIGNMENT_CENTER, 68, t[3], 3, Color(0, 0, 0, 0.9))
			screen.draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_CENTER, 68, t[3], t[2])
	# The highlighted tool: its name, what it does, its cost and what's missing.
	var id2: String = list[clampi(ring_index, 0, list.size() - 1)]
	var info2: Dictionary = SB.TOOLS[id2]
	var y := c.y + RING_R + 58.0
	var w := minf(360.0, view.x - 24.0)
	var x := clampf(c.x - w * 0.5, 12.0, view.x - w - 12.0)
	var title := "%s  ·  %s" % [SB.display(bond()), String(info2["name"])]
	UI.draw_label(screen, Vector2(x, y), title, 17, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, w, 4, Color(0, 0, 0, 0.85))
	var line := String(info2["short"])
	if SB.usable_in_climb(id2):
		var free2: bool = info2.get("lasts", "") == "floor" and paid.has(id2)
		line += "  ·  " + ("open this floor" if free2 else (("from " if id2 == "des_build" else "") + SB.cost_text(info2["cost"], path)))
		if deep.used_up(id2) != "":
			line += "\n" + deep.used_up(id2)
		elif not free2:
			var q: Dictionary = SB.quote(info2["cost"], main.run_essence, main.run_flow, path)
			if not q["ok"]:
				line += "\n" + String(q["short"])
		if SB.TOOLS[id2].has("reach") and locked.get(id2) == null and id2 != "des_edit":
			line += "\n" + SB.TEXT["no_target"]
	else:
		line += "  ·  " + SB.TEXT["train_only"]
	screen.draw_multiline_string_outline(font, Vector2(x, y + 17.0), line, HORIZONTAL_ALIGNMENT_CENTER, w, 12, 3, 4, Color(0, 0, 0, 0.85))
	screen.draw_multiline_string(font, Vector2(x, y + 17.0), line, HORIZONTAL_ALIGNMENT_CENTER, w, 12, 3, Color(0.92, 0.9, 0.86))


## A tool's small glyph: an eye (Inspect), a lever (Switch), a wave (Calm),
## crossed blades (Set against), a dial (Tune).
func _tool_icon(b, id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"dev_inspect", "des_inspect", "man_inspect":
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.6))
			for i in range(11, 0, -1):
				var t := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.6))
			pts.append(pts[0])
			b.polyline(pts, col, 1.4)
			b.dot(c, s * 0.32, col)
		"des_switch":
			b.line(c + Vector2(-s, s * 0.6), c + Vector2(s, s * 0.6), col, 1.6)
			b.line(c + Vector2(0, s * 0.6), c + Vector2(s * 0.6, -s * 0.7), col, 1.6)
			b.dot(c + Vector2(s * 0.6, -s * 0.7), s * 0.3, col)
		"man_calm":
			for k in 2:
				var pts2 := PackedVector2Array()
				for i in 9:
					var t := float(i) / 8.0
					pts2.append(c + Vector2(lerpf(-s, s, t), sin(t * TAU) * s * 0.25 + (k - 0.5) * s * 0.7))
				b.polyline(pts2, col, 1.3)
		"man_feud":
			b.line(c + Vector2(-s, -s), c + Vector2(s, s), col, 1.6)
			b.line(c + Vector2(-s, s), c + Vector2(s, -s), col, 1.6)
			b.dot(c + Vector2(-s, -s), s * 0.25, col)
			b.dot(c + Vector2(s, -s), s * 0.25, col)
		"dev_tune":
			b.arc(c, s * 0.8, PI * 0.75, PI * 2.25, 16, col, 1.4)
			b.line(c, c + Vector2.from_angle(-PI * 0.3) * s * 0.8, col, 1.6)
		"dev_edit", "des_edit", "man_edit":  # a pen over a line
			b.line(c + Vector2(-s, s * 0.8), c + Vector2(s, s * 0.8), col, 1.2)
			b.line(c + Vector2(-s * 0.6, s * 0.4), c + Vector2(s * 0.7, -s * 0.9), col, 1.8)
			b.dot(c + Vector2(-s * 0.6, s * 0.4), s * 0.22, col)
		"dev_splice":  # two strands twisted
			for k in 2:
				var pts3 := PackedVector2Array()
				for i in 9:
					var t3 := float(i) / 8.0
					pts3.append(c + Vector2(lerpf(-s, s, t3), sin(t3 * TAU + PI * k) * s * 0.45))
				b.polyline(pts3, col, 1.3)
		"dev_write":  # a quill
			b.line(c + Vector2(-s * 0.8, s * 0.9), c + Vector2(s * 0.8, -s * 0.9), col, 1.6)
			b.line(c + Vector2(s * 0.8, -s * 0.9), c + Vector2(s * 0.1, -s * 0.5), col, 1.2)
			b.line(c + Vector2(s * 0.8, -s * 0.9), c + Vector2(s * 0.4, -s * 0.1), col, 1.2)
		"des_reroll", "man_reroll":  # two arrows round
			b.arc(c, s * 0.75, 0.2, PI - 0.2, 12, col, 1.4)
			b.arc(c, s * 0.75, PI + 0.2, TAU - 0.2, 12, col, 1.4)
			b.dot(c + Vector2.from_angle(PI - 0.2) * s * 0.75, s * 0.22, col)
			b.dot(c + Vector2.from_angle(TAU - 0.2) * s * 0.75, s * 0.22, col)
		"des_build":  # a block
			Traps._outline(b, Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col, 1.4)
			b.line(c + Vector2(-s * 0.75, 0), c + Vector2(s * 0.75, 0), col, 1.0)
		"man_build":  # a paw
			b.dot(c + Vector2(0, s * 0.3), s * 0.42, col)
			for i in 3:
				b.dot(c + Vector2((i - 1) * s * 0.5, -s * 0.45), s * 0.2, col)
		_:
			b.dot(c, s * 0.4, col)


## The panel's frame: a dark glass box with a title and a closing hint. Returns
## the inner rect.
func _panel_frame(font: Font, r: Rect2, title: String) -> Rect2:
	var col := SB.color(bond())
	screen.draw_rect(r, Color(0.03, 0.025, 0.05, 0.94))
	screen.draw_rect(r, Color(col, 0.45), false, 1.5)
	# The faint wireframe in the panel's corners.
	for i in 4:
		var x := r.position.x + r.size.x * (i + 1) / 5.0
		screen.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.position.y + 7), Color(col, 0.35), 1.0)
		screen.draw_line(Vector2(x, r.end.y - 7), Vector2(x, r.end.y - 2), Color(col, 0.35), 1.0)
	UI.draw_label(screen, r.position + Vector2(10, 18), title, 16, col.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0)
	var key := "Tap Tools" if main.touch_active else ("Press %s" % ("LB + LT" if main.pad_active else "B"))
	screen.draw_string(font, r.position + Vector2(10, 17), SB.TEXT["panel_close"] % key, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, 10, Color(0.75, 0.72, 0.8, 0.8))
	return Rect2(r.position + Vector2(10, 26), r.size - Vector2(20, 34))


## The Designer's plan: the floor drawn small, every room's kind, doors, traps,
## secret walls and the stair, and every trap's timing grouped below.
func _draw_plan(font: Font, view: Vector2) -> void:
	if plan_tex == null:
		_build_plan()
	var col := SB.color(bond())
	var margin := 16.0
	var avail := Rect2(margin, 44.0, view.x - margin * 2.0, view.y - 44.0 - 60.0)
	var gs: Vector2i = main.grid_size
	if plan_tex == null or gs.x <= 0:
		var r0 := _panel_frame(font, Rect2(view.x * 0.5 - 170, 60, 340, 70), SB.TEXT["plan_title"])
		screen.draw_string(font, r0.position + Vector2(0, 20), "One open hall: nothing hidden here.", HORIZONTAL_ALIGNMENT_LEFT, r0.size.x, 12, Color(0.9, 0.88, 0.84))
		return
	var groups := _trap_groups()
	var list_h := 14.0 * minf(groups.size(), 6.0) + 6.0
	var px := minf(avail.size.x / gs.x, (avail.size.y - list_h - 30.0) / gs.y)
	px = maxf(px, 2.0)
	var map_size := Vector2(gs.x, gs.y) * px
	var frame := Rect2(Vector2(view.x * 0.5 - map_size.x * 0.5 - 10.0, avail.position.y), Vector2(map_size.x + 20.0, map_size.y + 34.0 + list_h))
	var inner := _panel_frame(font, frame, SB.TEXT["plan_title"])
	var o := inner.position
	screen.draw_texture_rect(plan_tex, Rect2(o, map_size), false)
	var scale := px / Floors.CELL
	var rp: Vector2 = main.room.position
	var to_map := func(w: Vector2) -> Vector2: return o + (w - rp) * scale
	var b := Draw.Batch.new()
	var texts: Array = []
	var entries: Array = SB.plan_entries(main)
	for e in entries:
		var at: Vector2 = to_map.call(e["pos"])
		match e["type"]:
			"room":
				texts.append([at, String(e["text"]), Color(0.86, 0.84, 0.8, 0.85), 9 if px >= 6.0 else 8])
			"door":
				var dr: Rect2 = e["rect"]
				var mr := Rect2(to_map.call(dr.position), dr.size * scale)
				var dc := Color(1.0, 0.4, 0.35) if e["locked"] else Color(col, 0.95)
				if e["open"]:
					Traps._outline(b, mr.grow(0.5), dc, 1.0)
				else:
					b.rect(mr.grow(0.5), dc)
			"trap":
				var tr: Dictionary = e["trap"]
				var tc: Color = Traps.KINDS[tr["kind"]]["color"]
				if tr.get("off", false):
					tc = Color(0.55, 0.55, 0.58)
				if Traps.KINDS[tr["kind"]]["shape"] == "lane":
					var lr: Rect2 = Traps.lane_rect(tr)
					b.rect(Rect2(to_map.call(lr.position), lr.size * scale).grow(-px * 0.25), Color(tc, 0.75))
				else:
					b.dot(at, maxf(1.6, px * 0.32), Color(tc, 0.9))
				if e["hidden"]:
					b.arc(at, maxf(3.0, px * 0.55), 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.0)
			"secret":
				b.arc(at, maxf(3.5, px * 0.6), 0.0, TAU, 12, Color(col.lightened(0.3), 1.0), 1.5)
				var sr: Rect2 = e["rect"]
				texts.append([to_map.call(sr.get_center()), SB.TEXT["hidden_room"], Color(col.lightened(0.35), 0.95), 8])
			"wing":
				texts.append([at, SB.TEXT["wing"], Color(1.0, 0.75, 0.6, 0.9), 8])
			"stair":
				b.polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 4), at + Vector2(-5, 4)]), Color(1.0, 0.85, 0.45))
	var pm: Vector2 = to_map.call(main.player.global_position)
	b.dot(pm, 3.2, Color(1, 1, 1))
	b.arc(pm, 5.5, 0.0, TAU, 14, Color(1, 1, 1, 0.6), 1.0)
	b.flush(screen)
	for t in texts:
		screen.draw_string_outline(font, t[0] + Vector2(-50, 3), t[1], HORIZONTAL_ALIGNMENT_CENTER, 100, t[3], 3, Color(0, 0, 0, 0.85))
		screen.draw_string(font, t[0] + Vector2(-50, 3), t[1], HORIZONTAL_ALIGNMENT_CENTER, 100, t[3], t[2])
	# Every trap's timing, grouped (the same beat, the same kind).
	var y := o.y + map_size.y + 14.0
	var hidden: int = main.traps.filter(func(tr): return tr.get("hidden", false)).size()
	var head: String = "%d traps (%d hidden)  ·  %d doors  ·  %d secret walls" % [main.traps.size(), hidden, main.door_view.list.size() if main.door_view != null else 0, main.wings.secrets.size() if main.wings != null else 0]
	screen.draw_string(font, Vector2(o.x, y), head, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 11, Color(col.lightened(0.3), 0.95))
	for i in mini(groups.size(), 6):
		y += 14.0
		screen.draw_string(font, Vector2(o.x, y), groups[i], HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 10, Color(0.88, 0.86, 0.82, 0.9))


## Every trap's timing line, the same ones counted together.
func _trap_groups() -> Array:
	var count := {}
	var order: Array = []
	for tr in main.traps:
		var line := SB.trap_line(tr, Traps)
		if not count.has(line):
			order.append(line)
			count[line] = 0
		count[line] += 1
	return order.map(func(l): return ("%d x  " % count[l]) + l)


## The Developer's panel: every spell you carry, its real numbers and what each step adds.
func _draw_spells(font: Font, view: Vector2) -> void:
	var p = main.player
	var col := SB.color(bond())
	var w := minf(view.x - 32.0, 760.0)
	var rows: Array = []  # [text, colour, size]
	var steady: float = 0.7 if p.has_bond("rune_artist") else 1.0
	for part in main.BondScript.Bonds.PARTS:
		if not p.bonds.has(part):
			continue
		var bd = p.bonds[part]
		rows.append(["%s  ·  %s  ·  step %d" % [bd.display_name(), main.BondScript.PART_NAMES[part], bd.step], bd.color().lightened(0.2), 12])
		for sp in bd.spells():
			var nums: Array = SB.spell_numbers(bd, sp, steady)
			var bits: Array = nums.map(func(r): return "%s %s" % [r[0], r[1]])
			var tune := String(bd.tunes.get(sp["id"], ""))
			var tags: String = (" [" + SB.TUNE[tune]["name"] + "]") if tune != "" else ""
			var ed := SB.edit_text(bd.edits.get(sp["id"], {}))
			if ed != "":
				tags += " [" + ed + "]"
			if deep.splice.get("part", "") == part and deep.splice.get("spell", "") == sp["id"]:
				tags += " [" + SB.TEXT["splice_tag"] % SB.SPLICE_FX[deep.splice["effect"]]["name"] + "]"
			rows.append(["  %s%s:  %s" % [sp["name"], tags, "  ·  ".join(bits)], Color(0.93, 0.91, 0.87), 10])
			rows.append(["      " + "   ".join(SB.step_adds(sp)), Color(0.7, 0.68, 0.74), 9])
	if rows.is_empty():
		rows.append([SB.TEXT["no_spells"], Color(0.9, 0.88, 0.84), 11])
	var h := 34.0
	for r in rows:
		h += float(r[2]) + 5.0
	h = minf(h, view.y - 70.0)
	var inner := _panel_frame(font, Rect2(view.x * 0.5 - w * 0.5, 44.0, w, h), SB.TEXT["spells_title"])
	var y := inner.position.y + 10.0
	for r in rows:
		if y > inner.end.y:
			break
		screen.draw_string(font, Vector2(inner.position.x, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, r[2], r[1])
		y += float(r[2]) + 5.0


## While a spell ring is open (the Developer's Inspect paid): the pointed
## spell's real numbers, above the ring.
func _draw_pick_numbers(font: Font, view: Vector2) -> void:
	var p = main.player
	var bd = p.bonds.get(p.pick_part)
	if bd == null:
		return
	var known: Array = bd.spells()
	var sp: Dictionary = known[clampi(p.pick_index if p.pick_index >= 0 else bd.selected, 0, known.size() - 1)]
	var c: Vector2 = main.pick_anchor if main.touch_active else p.get_global_transform_with_canvas().origin
	var nums: Array = SB.spell_numbers(bd, sp, 0.7 if p.has_bond("rune_artist") else 1.0)
	var line := "  ·  ".join(nums.map(func(r): return "%s %s" % [r[0], r[1]]))
	var w := minf(view.x - 24.0, 520.0)
	var x := clampf(c.x - w * 0.5, 12.0, view.x - w - 12.0)
	var y := maxf(c.y - 78.0 - 52.0, 18.0)
	var col := SB.color(bond())
	screen.draw_multiline_string_outline(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, 11, 2, 4, Color(0, 0, 0, 0.9))
	screen.draw_multiline_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, 11, 2, col.lightened(0.35))
