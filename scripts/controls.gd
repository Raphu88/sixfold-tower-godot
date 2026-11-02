extends RefCounted
## Sets up the input actions in code, so the project needs no editor setup.

static func setup() -> void:
	_bind("move_up", [_key(KEY_W), _key(KEY_UP)])
	_bind("move_down", [_key(KEY_S), _key(KEY_DOWN)])
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_bind("sprint", [_key(KEY_SHIFT)])
	_bind("roll", [_key(KEY_SPACE)])
	_bind("attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_bind("parry", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K)])
	_bind("cast_hand", [_key(KEY_Q)])
	_bind("cast_legs", [_key(KEY_E)])
	_bind("restart", [_key(KEY_R)])
	_bind("toggle_music", [_key(KEY_M)])
	_bind("toggle_help", [_key(KEY_H)])
	_bind("weapon_1", [_key(KEY_1)])
	_bind("weapon_2", [_key(KEY_2)])
	_bind("weapon_3", [_key(KEY_3)])
	_bind("weapon_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN)])
	_bind("weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP)])
	_bind("step_up", [_key(KEY_BRACKETRIGHT)])
	_bind("step_down", [_key(KEY_BRACKETLEFT)])


static func _bind(action: String, events: Array) -> void:
	# Reloading the scene runs setup again; skip actions that already exist.
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev in events:
		InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev
