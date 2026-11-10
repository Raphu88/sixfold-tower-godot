extends RefCounted
## Sets up the input actions in code, so the project needs no editor setup.
##
## Keyboard and mouse are bound straight into Godot's input map, and so are
## the sticks (the left one moves, the right one aims; they come from pad.gd's
## PAD_DEVICE, the controller put into the standard layout). The controller's
## buttons and triggers are listed in PAD and PAD_CAST below and pressed by
## pad.gd, because holding LB turns the face buttons, RB and RT into the six
## mark casts (Godot's input map can't do button combinations by itself).

## How far a stick must tilt before it counts (0 to 1).
const MOVE_DEADZONE := 0.2
const AIM_DEADZONE := 0.3
## Triggers: pressed past this much, let go below TRIGGER_RELEASE.
const TRIGGER_PRESS := 0.45
const TRIGGER_RELEASE := 0.3
## The triggers are axes; pad.gd treats them as these extra "buttons".
const PAD_LT := 100
const PAD_RT := 101
## The button that turns the others into casts while held: LB (L1).
const PAD_CAST_MODIFIER := JOY_BUTTON_LEFT_SHOULDER
## The game's own controller. Browsers don't all report a controller's
## buttons the same way, so pad.gd reads every real controller, puts its
## buttons and sticks into the standard layout (its own guess, or what you
## set up in Settings -> Controller setup) and sends them on as if from this
## device. The input map below listens to this device only, so a scrambled
## controller's raw button numbers never reach the game.
const PAD_DEVICE := 32

## Godot 4.3's web export has a slip for controllers the browser calls
## "standard" (Chrome, Edge, most Firefox setups): it sends the triggers on
## axes 6 and 7, but its built-in layout for those pads looks for them on
## buttons 6 and 7, so trigger presses were lost. This is that layout with
## the triggers read from axes 6 and 7 (0 at rest, 1 pulled).
const WEB_STANDARD_FIX := "standard,Standard Gamepad Mapping,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:+a6,righttrigger:+a7,back:b8,start:b9,leftstick:b10,rightstick:b11,dpup:b12,dpdown:b13,dpleft:b14,dpright:b15,guide:b16,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Web"
static var web_fixed := false

## Controller buttons -> actions (Xbox names; PlayStation in brackets).
const PAD := {
	JOY_BUTTON_A: "jump",  # A (Cross)
	JOY_BUTTON_B: "roll",  # B (Circle)
	JOY_BUTTON_X: "use_item",  # X (Square)
	JOY_BUTTON_Y: "interact",  # Y (Triangle): take the gear you stand on
	JOY_BUTTON_RIGHT_SHOULDER: "weapon_next",  # RB (R1)
	PAD_RT: "attack",  # RT (R2): hold to draw a bow
	PAD_LT: "parry",  # LT (L2)
	JOY_BUTTON_DPAD_RIGHT: "weapon_next",
	JOY_BUTTON_DPAD_LEFT: "weapon_prev",
	JOY_BUTTON_DPAD_DOWN: "item_next",
	JOY_BUTTON_DPAD_UP: "inventory",
	JOY_BUTTON_START: "pause",  # Start (Options)
	JOY_BUTTON_BACK: "restart",  # View (Share): hold to restart; a short press opens the climber screen (pad.gd)
}

## View (Share): a press shorter than this (seconds) opens the climber
## screen; holding it restarts (main.gd RESTART_HOLD), so a stray press can't
## end a climb.
const PAD_CLIMBER_TAP := 0.35
## The action a short press of View gives.
const PAD_BACK_TAP := "climber"

## While LB (L1) is held, these cast your marks instead.
const PAD_CAST := {
	JOY_BUTTON_X: "cast_hand",
	JOY_BUTTON_A: "cast_legs",
	JOY_BUTTON_B: "cast_heart",
	JOY_BUTTON_Y: "cast_brow",
	JOY_BUTTON_RIGHT_SHOULDER: "cast_throat",
	PAD_RT: "cast_back",
}

## Also while LB (L1) is held: LT (L2) holds the tool ring of a secret bond
## (secret_tools.gd), instead of parrying.
const PAD_LB_EXTRA := {PAD_LT: "tool_ring"}

## Button names for prompts: [Xbox, PlayStation, short PlayStation].
const PAD_NAMES := {
	"a": ["A", "Cross", "X"], "b": ["B", "Circle", "O"], "x": ["X", "Square", "Sq"], "y": ["Y", "Triangle", "Tri"],
	"lb": ["LB", "L1", "L1"], "rb": ["RB", "R1", "R1"], "lt": ["LT", "L2", "L2"], "rt": ["RT", "R2", "R2"],
	"start": ["Start", "Options", "Opt"], "back": ["View", "Share", "Share"],
	"ls": ["Left stick", "Left stick", "LS"], "rs": ["Right stick", "Right stick", "RS"],
}

## The cast button for each body part (with LB held), as PAD_NAMES ids.
const PART_PAD := {"hand": "x", "legs": "a", "heart": "b", "brow": "y", "throat": "rb", "back": "rt"}

## The controls list, shown by the HUD panel (H, or the setting) and the menu's
## Controls page: [what it does, keys, controller]. {names} in the
## controller column become Xbox or PlayStation button names.
const HELP := [
	["move", "WASD / arrows", "{ls}"],
	["aim", "mouse", "{rs} (else auto)"],
	["roll", "Space", "{b}"],
	["jump", "Z", "{a}"],
	["strike / hold to draw", "Left click / J", "{rt}"],
	["parry", "Right click / K", "{lt}"],
	["weapon", "1 2 3 / wheel", "{rb} / D-pad left right"],
	["cast marks (hold to pick)", "Q E F C X V", "hold {lb} + {x} {a} {b} {y} {rb} {rt}"],
	["use item / next item (hold: item ring)", "G / T", "{x} / D-pad down"],
	["take gear", "Y", "{y}"],
	["tool ring (a secret bond's tools; hold)", "B", "hold {lb} + {lt}"],
	["pause menu", "Esc / P", "{start}"],
	["climber screen", "Tab", "{back} (press)"],
	["inventory", "I", "D-pad up"],
	["restart (hold)", "R", "hold {back}"],
	["music", "M", "-"],
	["controls panel", "H", "-"],
	["arrange the layout (move the HUD)", "F2", "Dev tools"],
	["dismiss the Entity's tip", "Enter / click it", "press {rs}"],
]


## A controller button's name for prompts ("a", "rt", ...).
static func pad_name(id: String, ps := false, short := false) -> String:
	var names: Array = PAD_NAMES.get(id, [id, id, id])
	return names[2 if ps and short else (1 if ps else 0)]


## Fills {a}, {rt}, ... in a line of text with button names.
static func pad_text(text: String, ps := false) -> String:
	for id in PAD_NAMES:
		text = text.replace("{%s}" % id, pad_name(id, ps))
	return text


static func setup() -> void:
	_bind("move_up", [_key(KEY_W), _key(KEY_UP)])
	_bind("move_down", [_key(KEY_S), _key(KEY_DOWN)])
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_bind("roll", [_key(KEY_SPACE)])
	_bind("jump", [_key(KEY_Z)])
	_bind("attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_bind("parry", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K)])
	_bind("cast_hand", [_key(KEY_Q)])
	_bind("cast_legs", [_key(KEY_E)])
	_bind("cast_heart", [_key(KEY_F)])
	_bind("cast_brow", [_key(KEY_C)])
	_bind("cast_throat", [_key(KEY_X)])
	_bind("cast_back", [_key(KEY_V)])
	_bind("use_item", [_key(KEY_G)])
	_bind("item_next", [_key(KEY_T)])
	_bind("interact", [_key(KEY_Y)])  # take the gear you stand on
	_bind("tool_ring", [_key(KEY_B)])  # a secret bond's tool ring (secret_tools.gd): tap or hold
	_bind("restart", [_key(KEY_R)])  # hold (main.gd), so a stray press doesn't end the climb
	_bind("toggle_music", [_key(KEY_M)])
	_bind("toggle_help", [_key(KEY_H)])
	_bind("arrange", [_key(KEY_F2)])  # Arrange mode (arrange.gd)
	_bind("new_climber", [_key(KEY_N)])
	_bind("weapon_1", [_key(KEY_1)])
	_bind("weapon_2", [_key(KEY_2)])
	_bind("weapon_3", [_key(KEY_3)])
	_bind("weapon_4", [_key(KEY_4)])  # (the tower cards)
	_bind("weapon_5", [_key(KEY_5)])
	_bind("weapon_6", [_key(KEY_6)])
	_bind("weapon_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN)])
	_bind("weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP)])
	_bind("pause", [_key(KEY_ESCAPE), _key(KEY_P)])
	_bind("climber", [_key(KEY_TAB)])  # the climber screen (marks, essence, record)
	_bind("inventory", [_key(KEY_I)])
	_bind("dismiss_tip", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _button(JOY_BUTTON_RIGHT_STICK)])  # the Entity's tip (guide.gd)
	# The sticks: the left one moves, the right one aims.
	_bind("move_left", [_axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("move_up", [_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("move_down", [_axis(JOY_AXIS_LEFT_Y, 1.0)])
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(a, MOVE_DEADZONE)
	_bind("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(a, AIM_DEADZONE)
	# Menus and card screens: A (Cross) confirms, B (Circle) goes back.
	# (Godot's own ui_ actions already have the arrows, d-pad and left stick.)
	_bind("ui_accept", [_button(JOY_BUTTON_A)])
	_bind("ui_cancel", [_button(JOY_BUTTON_B)])
	# Godot's own menu actions (ui_up, ui_left...) listen to the game's
	# controller too, not to the raw one (see PAD_DEVICE).
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) and ev.device != PAD_DEVICE:
				var moved: InputEvent = ev.duplicate()
				moved.device = PAD_DEVICE
				InputMap.action_erase_event(action, ev)
				if not InputMap.action_has_event(action, moved):
					InputMap.action_add_event(action, moved)
	if not web_fixed:
		web_fixed = true
		Input.add_joy_mapping(WEB_STANDARD_FIX, true)


static func _bind(action: String, events: Array) -> void:
	# Reloading the scene runs setup again: add only what isn't there yet.
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in events:
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = PAD_DEVICE  # the game's controller (pad.gd)
	ev.axis = axis
	ev.axis_value = value
	return ev


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = PAD_DEVICE
	ev.button_index = button
	return ev
