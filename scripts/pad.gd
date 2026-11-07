extends Node
## The game controller (Xbox or PlayStation layout). The sticks are in the
## input map (controls.gd); this turns the buttons and triggers into the same
## actions the keyboard presses, so the rest of the game doesn't need to know
## about controllers. Holding LB (L1) turns the face buttons, RB and RT into
## the six mark casts.
##
## It also notices which device was used last: after a controller press the
## prompts and the controls panel show controller buttons, and aiming follows
## the right stick (or locks onto the nearest monster, like on a phone).

const Controls := preload("res://scripts/controls.gd")

## Kept across restarts (a scene reload), so the prompts don't flip back.
static var last_active := false
static var last_ps := false

var main
var active := false
var cast_held := false  # LB down
var down := {}  # button (or PAD_LT / PAD_RT) -> the action it pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sees releases while the menu pauses the game
	main.pad_ps = last_ps
	_set_active(last_active)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			_noticed(event.device)
		_button(event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_RIGHT or event.axis == JOY_AXIS_TRIGGER_LEFT:
			var id := Controls.PAD_RT if event.axis == JOY_AXIS_TRIGGER_RIGHT else Controls.PAD_LT
			if not down.has(id) and event.axis_value >= Controls.TRIGGER_PRESS:
				_noticed(event.device)
				_button(id, true)
			elif down.has(id) and event.axis_value <= Controls.TRIGGER_RELEASE:
				_button(id, false)
		elif absf(event.axis_value) >= 0.5:
			_noticed(event.device)  # a stick pushed well past its deadzone
	elif active:
		# A keyboard, mouse or touch: hand the prompts back to them.
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventMouseMotion and event.relative.length() >= 2.0) or event is InputEventScreenTouch:
			_set_active(false)


## A controller was used: controller prompts and stick aiming.
func _noticed(device: int) -> void:
	var name := Input.get_joy_name(device).to_lower()
	main.pad_ps = false
	for word in ["ps3", "ps4", "ps5", "sony", "dualshock", "dualsense", "playstation"]:
		if name.contains(word):
			main.pad_ps = true
	last_ps = main.pad_ps
	if main.touch != null and main.touch.active:
		main.touch._set_active(false)  # (releases what the touch buttons held)
	if not active:
		_set_active(true)


func _set_active(on: bool) -> void:
	active = on
	last_active = on
	main.pad_active = on
	if main.player != null:
		main.player.stick_aim = on


func _button(id: int, pressed: bool) -> void:
	if id == Controls.PAD_CAST_MODIFIER:
		cast_held = pressed
		return
	if pressed:
		if down.has(id):
			return
		var action: String = Controls.PAD_CAST.get(id, "") if cast_held else ""
		if action == "":
			action = Controls.PAD.get(id, "")
		if action == "":
			return
		down[id] = action
		# While a menu pauses the game, its own focus keys answer instead.
		if not get_tree().paused or action == "pause":
			Input.action_press(action)
	else:
		# Let go of whatever this button pressed (after a restart this node
		# doesn't remember, so let go of both of its actions).
		var actions: Array = [down[id]] if down.has(id) else [Controls.PAD.get(id, ""), Controls.PAD_CAST.get(id, "")]
		down.erase(id)
		for a in actions:
			if a != "":
				Input.action_release(a)


## Lets go of everything the controller holds (a menu opened).
func release_all() -> void:
	for id in down:
		Input.action_release(down[id])
	down.clear()
