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
##
## Layouts. Browsers don't all report a controller the same way. When the
## browser says "standard" (or Godot knows the controller), the buttons come
## in the usual order. Otherwise (Firefox often does this with Xbox pads)
## they arrive as raw numbers that differ by system and driver. So every
## real controller goes through here first: its buttons and sticks are put
## into the standard layout and sent on from Controls.PAD_DEVICE, which is
## all the input map and the code below listen to. A known controller passes
## straight through; an unknown Xbox-like one gets a guessed layout
## (FALLBACK); and Settings -> Controller setup (pad_setup.gd) records a
## layout for any controller, saved per controller.

const Controls := preload("res://scripts/controls.gd")
const Guide := preload("res://scripts/guide.gd")

const SAVE_PATH := "user://sixfold.cfg"

## The controls a layout names, and what each becomes in the standard
## layout. Buttons:
const BUTTONS := {
	"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y,
	"lb": JOY_BUTTON_LEFT_SHOULDER, "rb": JOY_BUTTON_RIGHT_SHOULDER,
	"back": JOY_BUTTON_BACK, "start": JOY_BUTTON_START, "guide": JOY_BUTTON_GUIDE,
	"ls": JOY_BUTTON_LEFT_STICK, "rs": JOY_BUTTON_RIGHT_STICK,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
}
## Triggers (0 at rest, 1 pulled all the way):
const TRIGGERS := {"lt": JOY_AXIS_TRIGGER_LEFT, "rt": JOY_AXIS_TRIGGER_RIGHT}
## Sticks: [axis, which way the recorded direction points]. A layout records
## each stick's "up" (ly, ry) and "right" (lx, rx); up is -1 on Godot's axes.
const STICKS := {
	"lx": [JOY_AXIS_LEFT_X, 1.0], "ly": [JOY_AXIS_LEFT_Y, -1.0],
	"rx": [JOY_AXIS_RIGHT_X, 1.0], "ry": [JOY_AXIS_RIGHT_Y, -1.0],
}

## A layout maps controls to what the controller sends ("sources"), as text
## so it saves plainly. Several sources may be listed, split by commas.
##   "b3"       button 3
##   "a2+"      axis 2 pushed positive (a stick, or a digital input on an axis)
##   "a2+@-1"   axis 2 pushed positive from a rest of -1 (a trigger that rests at -1)
##   "h9=-0.43" axis 9 sitting at -0.43 (a d-pad sent as one "hat" axis)
##
## The standard layout itself, for filling in steps a setup skipped.
const STANDARD := {
	"a": "b0", "b": "b1", "x": "b2", "y": "b3", "back": "b4", "guide": "b5", "start": "b6",
	"ls": "b7", "rs": "b8", "lb": "b9", "rb": "b10", "up": "b11", "down": "b12", "left": "b13", "right": "b14",
	"lt": "a4+", "rt": "a5+", "lx": "a0+", "ly": "a1-", "rx": "a2+", "ry": "a3-",
}

## Guessed layouts for an Xbox-like controller the browser and Godot don't
## know, by the system the browser runs on (the start of Godot's guid). They
## are guesses: Controller setup fixes whatever they get wrong.
const FALLBACK := {
	# Linux, and anything else: the usual raw Xbox order (as the xpad driver gives it).
	"Linux": {
		"a": "b0", "b": "b1", "x": "b2", "y": "b3", "lb": "b4", "rb": "b5", "back": "b6", "start": "b7",
		"guide": "b8", "ls": "b9", "rs": "b10",
		"lx": "a0+", "ly": "a1-", "lt": "a2+@-1", "rx": "a3+", "ry": "a4-", "rt": "a5+@-1",
		"up": "a7-", "down": "a7+", "left": "a6-", "right": "a6+",
	},
	# Windows and macOS: an Xbox pad the browser reads as a plain Bluetooth
	# device, whose buttons come with gaps (A 0, B 1, X 3, Y 4, LB 6, RB 7...).
	# Where its d-pad lands varies too much to guess: the setup records it.
	"Bluetooth": {
		"a": "b0", "b": "b1", "x": "b3", "y": "b4", "lb": "b6", "rb": "b7", "back": "b10", "start": "b11",
		"guide": "b12", "ls": "b13", "rs": "b14",
		"lx": "a0+", "ly": "a1-", "rx": "a2+", "ry": "a3-", "lt": "a5+@-1", "rt": "a4+@-1",
	},
}
const FALLBACK_BY_OS := {"Windows": "Bluetooth", "MacOSX": "Bluetooth"}
## Words in a controller's name that mean an Xbox (or XInput) pad.
const XBOX_WORDS := ["xbox", "x-box", "xinput", "045e-", "microsoft"]

## How a source reads in the setup screen's list and readout.
const SOURCE_TEXT := {"b": "button %d", "a": "axis %d %s", "h": "axis %d at %s", "none": "-"}

## Pressed past this much (a digital input read from an axis), let go below RELEASE.
const PRESS := 0.5
const RELEASE := 0.35

## Kept across restarts (a scene reload), so the prompts don't flip back.
static var last_active := false
static var last_ps := false
## Saved layouts: controller key (guid|name) -> {control: source}. And the
## controllers the Entity has already offered the setup for.
static var layouts := {}
static var offered := {}
static var loaded := false
## Tests: pretend controllers. device -> {name, guid, known}. (Godot can't
## fake a connected controller, nor whether it knows its layout.)
static var test_joys := {}

var main
var active := false
var cast_held := false  # LB down
var down := {}  # button (or PAD_LT / PAD_RT) -> the action it pressed
var back_since := -1  # when View (Share) went down (msec), for the short press
## Each real controller seen: device -> its state (see _dev).
var devs := {}
var last_device := -1  # the real controller pressed last
var src_device := 0  # the real controller behind the event being handled
var capture := Callable()  # the setup screen, while it records: gets the raw events instead
var offers := 0  # times the Entity offered the setup (tests)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sees releases while the menu pauses the game
	load_layouts()
	main.pad_ps = last_ps
	_set_active(last_active)
	Input.joy_connection_changed.connect(_on_connection)


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != Controls.PAD_DEVICE:
		_raw(event)
		get_viewport().set_input_as_handled()  # (only the standard-layout copy goes on)
		return
	if event is InputEventJoypadButton:
		src_device = int(event.get_meta("src", 0))
		if event.pressed:
			_noticed(src_device)
		_button(event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		src_device = int(event.get_meta("src", 0))
		if event.axis == JOY_AXIS_TRIGGER_RIGHT or event.axis == JOY_AXIS_TRIGGER_LEFT:
			var id := Controls.PAD_RT if event.axis == JOY_AXIS_TRIGGER_RIGHT else Controls.PAD_LT
			if not down.has(id) and event.axis_value >= Controls.TRIGGER_PRESS:
				_noticed(src_device)
				_button(id, true)
			elif down.has(id) and event.axis_value <= Controls.TRIGGER_RELEASE:
				_button(id, false)
		elif absf(event.axis_value) >= 0.5:
			_noticed(src_device)  # a stick pushed well past its deadzone
	elif active:
		# A keyboard, mouse or touch: hand the prompts back to them.
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventMouseMotion and event.relative.length() >= 2.0) or event is InputEventScreenTouch:
			_set_active(false)


## A controller was used: controller prompts and stick aiming.
func _noticed(device: int) -> void:
	var name := String(joy_info(device)["name"]).to_lower()
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
		if id == JOY_BUTTON_BACK:
			back_since = Time.get_ticks_msec()
		# While a menu pauses the game, its own focus keys answer instead
		# (Start still closes it, and View's short press is read on release).
		if not get_tree().paused or action == "pause":
			Input.action_press(action)
	else:
		# Let go of whatever this button pressed (after a restart this node
		# doesn't remember, so let go of both of its actions).
		var actions: Array = [down[id]] if down.has(id) else [Controls.PAD.get(id, ""), Controls.PAD_CAST.get(id, "")]
		var was_down := down.has(id)
		down.erase(id)
		for a in actions:
			if a != "":
				Input.action_release(a)
		# View (Share): a short press opens (or closes) the climber screen;
		# holding it restarts instead (main.gd).
		if id == JOY_BUTTON_BACK and was_down and back_since >= 0:
			if Time.get_ticks_msec() - back_since < int(Controls.PAD_CLIMBER_TAP * 1000.0):
				tap(Controls.PAD_BACK_TAP)
			back_since = -1


## A one-frame press of an action (the next frame lets go), like a key tap.
func tap(action: String) -> void:
	Input.action_press(action)
	get_tree().create_timer(0.05, true, false, true).timeout.connect(Input.action_release.bind(action))


## Lets go of everything the controller holds (a menu opened).
func release_all() -> void:
	for id in down:
		Input.action_release(down[id])
	down.clear()


# --- real controllers -> the standard layout ----------------------------------------

## What Godot says about a controller: its name, guid (on the web, "standard"
## when the browser reports the standard layout, else the system and the
## vendor and product numbers), whether Godot knows its layout, and the key
## its saved layout goes under.
func joy_info(device: int) -> Dictionary:
	var out := {"name": "", "guid": "", "known": true, "connected": false}
	if test_joys.has(device):
		out.merge(test_joys[device], true)
		out["connected"] = true
	elif device in Input.get_connected_joypads():
		out["name"] = Input.get_joy_name(device)
		out["guid"] = Input.get_joy_guid(device)
		out["known"] = Input.is_joy_known(device)
		out["connected"] = true
	# (a device Godot doesn't list, such as a test's, counts as a standard one)
	out["standard"] = out["guid"] == "standard"
	out["web"] = OS.has_feature("web") or test_joys.has(device)
	out["key"] = "%s|%s" % [out["guid"], out["name"]]
	return out


## A controller's state, set up the first time it's seen: its layout (null:
## it passes straight through), what kind of layout ("known", "custom",
## "guessed" or "raw": unknown and passed through), the raw buttons and axes
## as they are now, and what this has sent on for it.
func _dev(device: int) -> Dictionary:
	if devs.has(device):
		return devs[device]
	var info := joy_info(device)
	var d := {"info": info, "layout": null, "kind": "known", "btn": {}, "ax": {}, "on": {}, "val": {}, "fwd": {}, "fwd_ax": {}, "offer_checked": false}
	if layouts.has(info["key"]):
		d["layout"] = parse_layout(layouts[info["key"]])
		d["kind"] = "custom"
	elif not info["known"] and info["web"]:
		# (only browsers send raw numbers: a desktop or Android build gets
		# its controllers' buttons in order even when Godot calls them unknown)
		if looks_xbox(info["name"]):
			d["layout"] = parse_layout(fallback_for(info["guid"]))
			d["kind"] = "guessed"
		else:
			d["kind"] = "raw"
	devs[device] = d
	return d


static func looks_xbox(name: String) -> bool:
	var n := name.to_lower()
	return XBOX_WORDS.any(func(w): return n.contains(w))


## The guessed layout for an unknown Xbox-like controller on this system.
static func fallback_for(guid: String) -> Dictionary:
	for os in FALLBACK_BY_OS:
		if guid.begins_with(os):
			return FALLBACK[FALLBACK_BY_OS[os]]
	return FALLBACK["Linux"]


func _on_connection(device: int, _connected: bool) -> void:
	forget_device(device)


## Lets go of what a controller held and forgets its state (it's looked up
## again on its next press: a new layout, or a new controller).
func forget_device(device: int) -> void:
	if devs.has(device):
		_quiet(device)
		devs.erase(device)


func _raw(event: InputEvent) -> void:
	var d := _dev(event.device)
	var pressed := false
	if event is InputEventJoypadButton:
		if event.pressed:
			d["btn"][event.button_index] = true
			pressed = true
		else:
			d["btn"].erase(event.button_index)
	else:
		d["ax"][event.axis] = event.axis_value
	if pressed:
		last_device = event.device
		if not d["offer_checked"]:
			d["offer_checked"] = true
			_offer_setup(d)
	if capture.is_valid():
		capture.call(event)
		return
	if d["layout"] == null:
		# Known (or nothing better to go on): the same input, from the game's controller.
		var ev: InputEvent = event.duplicate()
		ev.device = Controls.PAD_DEVICE
		ev.set_meta("src", event.device)
		if event is InputEventJoypadButton:
			if event.pressed:
				d["fwd"][event.button_index] = true
			else:
				d["fwd"].erase(event.button_index)
		else:
			d["fwd_ax"][event.axis] = event.axis_value
		Input.parse_input_event(ev)
		return
	var L: Dictionary = d["layout"]
	for control in L:
		for src in L[control]:
			if (event is InputEventJoypadButton and src["t"] == "b" and src["i"] == event.button_index) \
					or (event is InputEventJoypadMotion and src["t"] != "b" and src["i"] == event.axis):
				_update(event.device, d, control)
				break


## Works out a control from its sources and sends it on if it changed.
func _update(device: int, d: Dictionary, control: String) -> void:
	var srcs: Array = d["layout"][control]
	if STICKS.has(control):
		var v := 0.0
		for src in srcs:
			var s := stick_value(src, d)
			if absf(s) > absf(v):
				v = s
		v = clampf(v * float(STICKS[control][1]), -1.0, 1.0)
		if absf(v - float(d["val"].get(control, 0.0))) > 0.004 or (v == 0.0 and d["val"].get(control, 0.0) != 0.0):
			d["val"][control] = v
			_send_axis(device, STICKS[control][0], v)
		return
	var amount := 0.0
	for src in srcs:
		amount = maxf(amount, source_amount(src, d))
	if TRIGGERS.has(control):
		var was := float(d["val"].get(control, 0.0))
		if absf(amount - was) > 0.01 or (amount != was and (amount == 0.0 or amount == 1.0)):
			d["val"][control] = amount
			_send_axis(device, TRIGGERS[control], amount)
		return
	var on: bool = d["on"].has(control)
	var now := amount >= (RELEASE if on else PRESS)
	if now != on:
		if now:
			d["on"][control] = true
		else:
			d["on"].erase(control)
		_send_button(device, BUTTONS[control], now)


## How far a source is pressed, 0 to 1 (a button, a trigger, a direction).
static func source_amount(src: Dictionary, d: Dictionary) -> float:
	match src["t"]:
		"b":
			return 1.0 if d["btn"].has(src["i"]) else 0.0
		"a":
			var r: float = src["r"]
			var s: float = src["s"]
			var v: float = d["ax"].get(src["i"], r)
			return clampf((v - r) * s / maxf(1.0 - r * s, 0.01), 0.0, 1.0)
		"h":
			return 1.0 if hat_on(float(d["ax"].get(src["i"], 99.0)), src["v"]) else 0.0
	return 0.0


## A stick's value along its recorded direction, -1 to 1.
static func stick_value(src: Dictionary, d: Dictionary) -> float:
	if src["t"] == "a":
		return clampf(float(d["ax"].get(src["i"], 0.0)) * float(src["s"]), -1.0, 1.0)
	return source_amount(src, d)


## A d-pad sent as one axis ("hat"): the recorded value, or (for the usual
## eight-way hat, -1 up and stepping 2/7 clockwise) the diagonals either side.
static func hat_on(v: float, target: float) -> bool:
	if absf(v - target) < 0.08:
		return true
	if absf(v) > 1.05 or absf(target) > 1.05:
		return false
	var jf := (v + 1.0) * 3.5
	var kf := (target + 1.0) * 3.5
	if absf(jf - roundf(jf)) > 0.25 or absf(kf - roundf(kf)) > 0.25:
		return false
	var step := posmod(roundi(jf) - roundi(kf), 8)
	return step == 1 or step == 7


func _send_button(device: int, button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = Controls.PAD_DEVICE
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	ev.set_meta("src", device)
	Input.parse_input_event(ev)


func _send_axis(device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = Controls.PAD_DEVICE
	ev.axis = axis
	ev.axis_value = value
	ev.set_meta("src", device)
	Input.parse_input_event(ev)


## Lets go of everything sent on for a controller (the setup screen starts
## recording, or its layout changes).
func _quiet(device: int) -> void:
	if not devs.has(device):
		return
	var d: Dictionary = devs[device]
	for control in d["on"]:
		_send_button(device, BUTTONS[control], false)
	d["on"].clear()
	for control in d["val"]:
		if d["val"][control] != 0.0:
			_send_axis(device, (STICKS[control][0] if STICKS.has(control) else TRIGGERS[control]), 0.0)
	d["val"].clear()
	for b in d["fwd"]:
		_send_button(device, b, false)
	d["fwd"].clear()
	for a in d["fwd_ax"]:
		if absf(d["fwd_ax"][a]) > 0.01:
			_send_axis(device, a, 0.0)
	d["fwd_ax"].clear()


## The first press on a controller whose layout is only a guess (or not
## known at all): once per controller, the Entity points to the setup.
func _offer_setup(d: Dictionary) -> void:
	if not (d["kind"] == "guessed" or d["kind"] == "raw"):
		return
	var key: String = d["info"]["key"]
	if offered.has(key):
		return
	offered[key] = true
	save_layouts()
	offers += 1
	if Guide.live() and Guide.tips_on():
		var PadSetup = load("res://scripts/pad_setup.gd")
		Guide.queue.push_front({"kind": "say", "id": "", "key": "pad_setup", "text": PadSetup.TEXT["entity_offer"]})


# --- the setup screen's side ----------------------------------------------------------

## The setup screen records: raw events go to `cb` instead of the game.
func start_capture(cb: Callable) -> void:
	capture = cb
	for device in devs:
		_quiet(device)
	release_all()


func stop_capture() -> void:
	capture = Callable()


## The raw buttons held and axis values of a controller, as they are now.
func raw_state(device: int) -> Dictionary:
	var d := _dev(device)
	return {"btn": d["btn"], "ax": d["ax"]}


## Saves a recorded layout for this controller and uses it from now on.
func set_layout(device: int, layout: Dictionary) -> void:
	var key: String = joy_info(device)["key"]
	layouts[key] = layout.duplicate()
	save_layouts()
	_reuse(device)


## True if this controller has a layout recorded by the setup.
func has_custom(device: int) -> bool:
	return layouts.has(joy_info(device)["key"])


## Back to the default layout (straight through, or the guess).
func reset_layout(device: int) -> void:
	layouts.erase(joy_info(device)["key"])
	save_layouts()
	_reuse(device)


func _reuse(device: int) -> void:
	var held: Dictionary = {}
	if devs.has(device):
		held = {"btn": devs[device]["btn"].duplicate(), "ax": devs[device]["ax"].duplicate(), "offer_checked": true}
	forget_device(device)
	var d := _dev(device)
	d.merge(held, true)


## The layout a controller uses now, as text ({} when it passes straight through).
func layout_of(device: int) -> Dictionary:
	var info := joy_info(device)
	if layouts.has(info["key"]):
		return layouts[info["key"]]
	var d := _dev(device)
	if d["kind"] == "guessed":
		return fallback_for(info["guid"])
	return {}


## What a controller sends for each control by default: the guess for an
## unknown Xbox pad, else the standard layout.
func default_layout(device: int) -> Dictionary:
	var info := joy_info(device)
	if not info["known"] and info["web"] and looks_xbox(info["name"]):
		return fallback_for(info["guid"])
	return STANDARD


# --- layouts as text -----------------------------------------------------------------

## "b3", "a2+@-1", "h9=-0.43" -> {t: "b"|"a"|"h", i, s, r, v}; {} if it isn't one.
static func parse_source(text: String) -> Dictionary:
	var s := text.strip_edges()
	if s.length() < 2:
		return {}
	var kind := s.left(1)
	var body := s.substr(1)
	if kind == "b" and body.is_valid_int():
		return {"t": "b", "i": body.to_int()}
	if kind == "h":
		var eq := body.find("=")
		if eq > 0 and body.left(eq).is_valid_int() and body.substr(eq + 1).is_valid_float():
			return {"t": "h", "i": body.left(eq).to_int(), "v": body.substr(eq + 1).to_float()}
		return {}
	if kind == "a":
		var rest := 0.0
		var at := body.find("@")
		if at >= 0:
			if not body.substr(at + 1).is_valid_float():
				return {}
			rest = body.substr(at + 1).to_float()
			body = body.left(at)
		if body.length() < 2 or not (body.ends_with("+") or body.ends_with("-")) or not body.left(body.length() - 1).is_valid_int():
			return {}
		var i := body.left(body.length() - 1).to_int()
		if i < 0 or i >= 10:
			return {}
		return {"t": "a", "i": i, "s": 1.0 if body.ends_with("+") else -1.0, "r": rest}
	return {}


## {control: "b3,a7-"} -> {control: [source, ...]}, dropping what doesn't read.
static func parse_layout(layout: Dictionary) -> Dictionary:
	var out := {}
	for control in layout:
		if not (BUTTONS.has(control) or TRIGGERS.has(control) or STICKS.has(control)):
			continue
		var list: Array = []
		for part in String(layout[control]).split(",", false):
			var src := parse_source(part)
			if not src.is_empty():
				list.append(src)
		if not list.is_empty():
			out[control] = list
	return out


## A source as words for the setup screen ("button 3", "axis 2 +").
static func source_text(text: String) -> String:
	var parts: Array = []
	for part in String(text).split(",", false):
		var src := parse_source(part)
		if src.is_empty():
			continue
		match src["t"]:
			"b":
				parts.append(SOURCE_TEXT["b"] % src["i"])
			"a":
				parts.append(SOURCE_TEXT["a"] % [src["i"], "+" if src["s"] > 0.0 else "-"])
			"h":
				parts.append(SOURCE_TEXT["h"] % [src["i"], "%.2f" % src["v"]])
	return SOURCE_TEXT["none"] if parts.is_empty() else ", ".join(parts)


# --- saving ---------------------------------------------------------------------------

## The saved layouts live in the "pad" section of the save file. Tests pass
## their own path (the real save is never touched in tests).
static func load_layouts(path := "") -> void:
	if path == "":
		if loaded:
			return
		loaded = true
		if Engine.has_meta("sixfold_test"):
			return
		path = SAVE_PATH
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var l = cfg.get_value("pad", "layouts", {})
	var o = cfg.get_value("pad", "offered", {})
	layouts = l if l is Dictionary else {}
	offered = o if o is Dictionary else {}


static func save_layouts(path := "") -> void:
	if path == "":
		if Engine.has_meta("sixfold_test"):
			return
		path = SAVE_PATH
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("pad", "layouts", layouts)
	cfg.set_value("pad", "offered", offered)
	cfg.save(path)
