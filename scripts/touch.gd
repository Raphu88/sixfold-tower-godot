extends Node2D
## On-screen controls for phones and tablets. They appear the first time
## the screen is touched and hide again if a keyboard or mouse is used.
##
## Left side: a floating joystick (appears under your thumb; push it all
## the way to sprint). Right side: attack (hold to draw the bow), roll,
## parry, both bond casts and weapon switch. Top right: fullscreen, music,
## restart. The controls press the same input actions as the keyboard, so
## the rest of the game doesn't need to know about touch at all.

const Palette := preload("res://scripts/palette.gd")

const STICK_RADIUS := 70.0
const SPRINT_AT := 0.92
const ONE_SHOT := ["weapon", "music", "restart"]

var main
var active := false
var stick_touch := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var held := {}  # touch index -> button id
var buttons: Array = []  # {id, action, center, radius, label}


func _ready() -> void:
	set_process_input(true)


func _layout() -> void:
	var s := get_viewport_rect().size
	buttons = [
		{"id": "attack", "action": "attack", "c": Vector2(s.x - 130, s.y - 130), "r": 62.0},
		{"id": "roll", "action": "roll", "c": Vector2(s.x - 268, s.y - 86), "r": 44.0},
		{"id": "parry", "action": "parry", "c": Vector2(s.x - 150, s.y - 278), "r": 42.0},
		{"id": "cast_hand", "action": "cast_hand", "c": Vector2(s.x - 282, s.y - 222), "r": 34.0},
		{"id": "cast_legs", "action": "cast_legs", "c": Vector2(s.x - 52, s.y - 262), "r": 34.0},
		{"id": "weapon", "action": "weapon_next", "c": Vector2(s.x - 290, s.y - 330), "r": 28.0},
		{"id": "fullscreen", "action": "", "c": Vector2(s.x - 40, 40), "r": 24.0},
		{"id": "music", "action": "toggle_music", "c": Vector2(s.x - 100, 40), "r": 24.0},
		{"id": "restart", "action": "restart", "c": Vector2(s.x - 160, 40), "r": 24.0},
	]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not active:
			_set_active(true)
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_touch:
			stick_pos = event.position
			_update_stick()
		get_viewport().set_input_as_handled()
	elif active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		# Someone picked up a keyboard or mouse: hand control back to them.
		if not (event is InputEventMouseMotion and event.relative.length() < 2.0):
			_set_active(false)


func _set_active(on: bool) -> void:
	active = on
	main.touch_active = on
	if main.player != null:
		main.player.touch_aim = on
	if not on:
		_release_all()
	queue_redraw()


func _touch_down(index: int, pos: Vector2) -> void:
	_layout()
	for b in buttons:
		if pos.distance_to(b["c"]) <= b["r"] + 12.0:
			held[index] = b["id"]
			if b["id"] == "fullscreen":
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif b["action"] != "":
				Input.action_press(b["action"])
				if b["id"] in ONE_SHOT:
					# Taps: release on the next frame so the next tap registers too.
					get_tree().create_timer(0.05, true, false, true).timeout.connect(Input.action_release.bind(b["action"]))
			return
	# Anywhere on the left side starts the joystick under the thumb.
	if stick_touch == -1 and pos.x < get_viewport_rect().size.x * 0.5:
		stick_touch = index
		stick_origin = pos
		stick_pos = pos
		_update_stick()


func _touch_up(index: int) -> void:
	if index == stick_touch:
		stick_touch = -1
		_set_move(Vector2.ZERO)
	elif held.has(index):
		var id: String = held[index]
		held.erase(index)
		for b in buttons:
			if b["id"] == id and b["action"] != "" and not (id in ONE_SHOT):
				Input.action_release(b["action"])


func _update_stick() -> void:
	var v := (stick_pos - stick_origin) / STICK_RADIUS
	if v.length() > 1.0:
		# Drag past the edge and the stick follows your thumb.
		stick_origin = stick_pos - v.normalized() * STICK_RADIUS
		v = v.normalized()
	_set_move(v)


func _set_move(v: Vector2) -> void:
	var dead := 0.15
	_axis("move_right", "move_left", v.x if absf(v.x) > dead else 0.0)
	_axis("move_down", "move_up", v.y if absf(v.y) > dead else 0.0)
	if v.length() >= SPRINT_AT:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _axis(pos_action: String, neg_action: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(pos_action, value)
		Input.action_release(neg_action)
	elif value < 0.0:
		Input.action_press(neg_action, -value)
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _release_all() -> void:
	stick_touch = -1
	_set_move(Vector2.ZERO)
	for b in buttons:
		if b["action"] != "":
			Input.action_release(b["action"])
	held.clear()


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	_layout()
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	if size.x < size.y:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0, size.y / 2.0), "Turn your phone sideways", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(0.95, 0.8, 0.5))
		return

	if stick_touch != -1:
		draw_circle(stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.3))
		draw_arc(stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0)
		var knob := stick_origin + (stick_pos - stick_origin).limit_length(STICK_RADIUS)
		var sprinting := (stick_pos - stick_origin).length() >= STICK_RADIUS * SPRINT_AT
		draw_circle(knob, 28.0, Color(0.95, 0.8, 0.5, 0.55) if sprinting else Color(1, 1, 1, 0.35))
	else:
		draw_string(font, Vector2(30, size.y - 30), "touch here to move", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.3))

	var p = main.player
	var down := held.values()
	for b in buttons:
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var pressed: bool = b["id"] in down
		var col := Color(1, 1, 1)
		var fill := 0.0
		var label := ""
		match b["id"]:
			"attack":
				label = p.Weapons.WEAPONS[p.weapon]["name"] if p != null else "Attack"
				if p != null and p.drawing:
					fill = clampf(p.draw_t / p.wdata()["draw_time"], 0.0, 1.0)
			"roll":
				label = "Roll"
			"parry":
				label = "Parry"
			"cast_hand", "cast_legs":
				var bond = p.bonds.get("hand" if b["id"] == "cast_hand" else "legs") if p != null else null
				if bond != null:
					col = bond.color()
					fill = bond.essence / bond.capacity()
					label = bond.spell_name().split(" ")[0]
			"weapon":
				label = "Swap"
			"fullscreen":
				label = "[ ]"
			"music":
				label = "Music"
			"restart":
				label = "R"
		draw_circle(c, r, Color(0, 0, 0, 0.45 if not pressed else 0.6))
		draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.55 if not pressed else 0.95), 2.5)
		if fill > 0.0:
			draw_arc(c, r - 4.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, Color(col, 0.9), 4.0)
		if pressed:
			draw_circle(c, r - 3.0, Color(col, 0.18))
		var fsize := 15 if r > 30.0 else 12
		draw_string(font, c + Vector2(-r, fsize * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fsize, Color(col, 0.9))
