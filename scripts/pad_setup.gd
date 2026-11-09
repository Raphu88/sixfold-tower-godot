extends VBoxContainer
## Settings -> Controller setup: teaches the game which button is which on a
## controller whose browser sends its buttons scrambled (Firefox often does,
## with Xbox pads). It asks for one control at a time ("Press the button you
## want for Jump"), records whatever the controller sends (a button, an axis
## and its direction, a d-pad sent as a "hat" axis), and saves the layout for
## that controller (pad.gd uses it from then on).
##
## While it records, the controller's presses come here instead of the game,
## so it works however scrambled the controller is: any button starts, the
## button you gave for Jump skips a step and the one for Roll goes back one.
## Keys, mouse and touch work too (the buttons on the page, Esc to leave).
## Underneath, a live readout shows the raw buttons and axes arriving, so
## you can tell what a controller sends if something is still off.
##
## All its words are in TEXT and STEPS.

const UI := preload("res://scripts/ui.gd")

const TEXT := {
	"title": "Controller setup",
	"settings_button": "Controller setup",
	"intro": "If a controller's buttons do the wrong things (some browsers send them scrambled), teach the game which is which. It asks for one control at a time: press whatever you want for each.",
	"pick": "Press any button on the controller you want to set up",
	"pick_hint": "Or choose Begin below. B goes back.",
	"none": "No controller yet: plug one in or switch it on, then press any button on it.",
	"controller": "%s  ·  %s",
	"unnamed": "Controller",
	"kinds": {
		"known": "standard layout",
		"custom": "your setup",
		"guessed": "guessed layout",
		"raw": "unknown layout",
	},
	"button": "Press the button you want for %s",
	"trigger": "Pull the trigger you want for %s",
	"step": "Step %d of %d",
	"got": "Recorded: %s",
	"taken": "%s is already %s: press another",
	"skipped": "Skipped",
	"nav": "Not on this controller? Your Jump button skips it, your Roll button goes back a step. Esc leaves.",
	"nav_early": "Esc or Back leaves without saving.",
	"done": "All set",
	"done_hint": "Saved for this controller: the game uses this layout from now on.",
	"begin": "Begin",
	"skip": "Skip",
	"redo": "Back a step",
	"again": "Start over",
	"reset": "Reset to default",
	"finish": "Done",
	"reset_done": "Back to the default layout for this controller.",
	"recorded": "Recorded",
	"readout": "What the controller sends",
	"readout_none": "Press something on a controller to see what it sends.",
	"readout_head": "%s  ·  device %d",
	"browser_standard": "the browser reports the standard layout",
	"browser_raw": "the browser sends raw numbers",
	"godot_known": "Godot knows it",
	"godot_unknown": "Godot doesn't know it",
	"id": "id %s",
	"buttons": "Buttons held: %s",
	"axes": "Axes: %s",
	"nothing": "none",
	# The Entity, the first time an unknown controller is used (pad.gd).
	"entity_offer": "That controller speaks a dialect I don't know. If its buttons feel wrong, open Settings, then Controller setup, and teach me which is which.",
}

## The steps, in order. kind: button, trigger (as an axis or a button),
## stick (an axis and its direction), dpad (a button, an axis or a hat).
## "for" fills TEXT["button"] / TEXT["trigger"]; "say" is the whole prompt.
## "name" is how it reads in the list of what was recorded.
const STEPS := [
	{"id": "a", "kind": "button", "for": "Jump", "name": "Jump (A)", "hint": "A on Xbox, Cross on PlayStation: the bottom face button. Also confirms in menus."},
	{"id": "b", "kind": "button", "for": "Roll", "name": "Roll (B)", "hint": "B / Circle: the right face button. Also goes back in menus."},
	{"id": "ly", "kind": "stick", "say": "Push the stick you want to move with: up", "name": "Move up", "hint": "Usually the left stick."},
	{"id": "lx", "kind": "stick", "say": "Push the same stick: right", "name": "Move right", "hint": "The moving stick, to the right."},
	{"id": "ry", "kind": "stick", "say": "Push the stick you want to aim with: up", "name": "Aim up", "hint": "Usually the right stick."},
	{"id": "rx", "kind": "stick", "say": "Push the aiming stick: right", "name": "Aim right", "hint": "The aiming stick, to the right."},
	{"id": "x", "kind": "button", "for": "Use item", "name": "Use item (X)", "hint": "X / Square: the left face button."},
	{"id": "y", "kind": "button", "for": "Take gear", "name": "Take gear (Y)", "hint": "Y / Triangle: the top face button."},
	{"id": "rt", "kind": "trigger", "for": "Attack", "name": "Attack (RT)", "hint": "RT / R2: the right trigger. Hold it to draw a bow."},
	{"id": "lt", "kind": "trigger", "for": "Parry", "name": "Parry (LT)", "hint": "LT / L2: the left trigger."},
	{"id": "rb", "kind": "button", "for": "Next weapon", "name": "Next weapon (RB)", "hint": "RB / R1: the right bumper."},
	{"id": "lb", "kind": "button", "for": "Casting", "name": "Casting (LB)", "hint": "LB / L1: the left bumper. Hold it and press a face button to cast a mark."},
	{"id": "up", "kind": "dpad", "say": "Press up on the d-pad", "name": "D-pad up", "hint": "Opens the inventory."},
	{"id": "down", "kind": "dpad", "say": "Press down on the d-pad", "name": "D-pad down", "hint": "Picks the next item."},
	{"id": "left", "kind": "dpad", "say": "Press left on the d-pad", "name": "D-pad left", "hint": "The previous weapon."},
	{"id": "right", "kind": "dpad", "say": "Press right on the d-pad", "name": "D-pad right", "hint": "The next weapon."},
	{"id": "start", "kind": "button", "for": "the pause menu", "name": "Menu (Start)", "hint": "Start, Menu or Options: the small button on the right."},
	{"id": "back", "kind": "button", "for": "the climber screen", "name": "Climber (View)", "hint": "View or Share: the small button on the left. Holding it restarts a climb."},
	{"id": "rs", "kind": "button", "say": "Click the aiming stick in", "name": "Dismiss tip (RS)", "hint": "RS / R3: dismisses the Entity's tips."},
]

## How far an axis must move from where it rests to count, and how close it
## must come back to count as let go.
const MOVE := 0.6
const BACK := 0.3
## A step moves on this long (msec) after its input is let go, at the soonest.
const SETTLE_MS := 150

var main
var menu
var pad
var state := "pick"  # pick, step, done
var device := -1  # the controller being set up
var step := 0
var got := {}  # control -> source (pad.gd's text form)
var rest := {}  # axis -> where it rested when this step began
var held := ""  # what this step recorded, waiting to be let go
var held_at := 0
var note := ""  # under the prompt: what was recorded, or why not
var note_col := UI.DIM
var readout: Label
var readout_text := ""


func _ready() -> void:
	pad = main.pad
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	device = pad.last_device
	if device < 0 and not Input.get_connected_joypads().is_empty():
		device = Input.get_connected_joypads()[0]
	pad.start_capture(_on_raw)
	_build()


func _exit_tree() -> void:
	if pad != null and pad.capture.is_valid() and pad.capture.get_object() == self:
		pad.stop_capture()


# --- recording -------------------------------------------------------------------------

func begin(dev := -1) -> void:
	if dev >= 0:
		device = dev
	if device < 0:
		return
	pad.start_capture(_on_raw)
	state = "step"
	step = 0
	got = {}
	held = ""
	note = ""
	_snap()
	_build()


## The raw events, while recording.
func _on_raw(ev: InputEvent) -> void:
	if state == "pick":
		if ev is InputEventJoypadButton and ev.pressed:
			if _means_back(ev):
				menu.go_back()
			else:
				begin(ev.device)
		return
	if state != "step" or ev.device != device or held != "":
		return
	var s: Dictionary = STEPS[step]
	var src := _read(ev, s["kind"])
	if src == "":
		return
	# The buttons given for Jump and Roll: skip, and back a step.
	if step > 0 and _same(src, got.get("a", "")):
		skip()
		return
	if step > 1 and _same(src, got.get("b", "")):
		redo()
		return
	var taken := _taken_by(src, s["id"])
	if taken != "":
		note = TEXT["taken"] % [pad.source_text(src).capitalize(), _step_name(taken)]
		note_col = UI.BAD
		_build()
		return
	got[s["id"]] = src
	held = src
	held_at = Time.get_ticks_msec()
	note = TEXT["got"] % pad.source_text(src)
	note_col = UI.GOOD
	_build()


## Pressing what the controller's current layout calls B, on the first
## screen: back out (a working controller that wandered in can leave).
func _means_back(ev: InputEventJoypadButton) -> bool:
	var layout: Dictionary = pad.layout_of(ev.device)
	if layout.is_empty():
		return ev.button_index == JOY_BUTTON_B
	return _same("b%d" % ev.button_index, String(layout.get("b", "")).get_slice(",", 0))


## What a raw event means for this kind of step, as a source ("" if nothing yet).
func _read(ev: InputEvent, kind: String) -> String:
	if ev is InputEventJoypadButton:
		return "b%d" % ev.button_index if ev.pressed and kind != "stick" else ""
	var i: int = ev.axis
	var v: float = ev.axis_value
	var r: float = rest.get(i, 0.0)
	# A d-pad sent as one axis (a "hat") rests off the usual -1..1 and jumps
	# between set values, some close together: any clear change counts.
	var hat_rest := absf(r) > 1.05
	if absf(v - r) < (0.1 if hat_rest else MOVE):
		return ""
	var sign := "+" if v > r else "-"
	if kind == "stick":
		# (an axis resting at an end is a trigger, not a stick)
		return "a%d%s" % [i, sign] if absf(r) < 0.5 and absf(v) >= MOVE else ""
	if kind == "dpad" and not hat_rest:
		if absf(r) < 0.3:
			return "a%d%s" % [i, sign] if absf(v) >= 0.9 else ""  # (an axis per direction pair)
		hat_rest = true
	if hat_rest:
		return "h%d=%.2f" % [i, v]  # remember the value itself
	if absf(r) >= 0.5:
		return "a%d%s@%d" % [i, sign, roundi(r)]  # a trigger resting at -1 (or 1)
	return "a%d%s" % [i, sign]


## Two sources are the same input (for sticks, the whole axis counts).
func _same(a: String, b: String) -> bool:
	if a == "" or b == "":
		return false
	var x: Dictionary = pad.parse_source(a)
	var y: Dictionary = pad.parse_source(b)
	if x.is_empty() or y.is_empty() or x["i"] != y["i"]:
		return false
	if x["t"] == "b" or y["t"] == "b":
		return x["t"] == y["t"]
	if x["t"] == "h" and y["t"] == "h":
		return absf(x["v"] - y["v"]) < 0.08
	if x["t"] == "a" and y["t"] == "a":
		return x["s"] == y["s"]
	return false


## The step already using this input ("" if none). A stick's axis is taken
## both ways.
func _taken_by(src: String, here: String) -> String:
	var x: Dictionary = pad.parse_source(src)
	for id in got:
		if id == here:
			continue
		var y: Dictionary = pad.parse_source(got[id])
		if _same(src, got[id]):
			return id
		var stick: bool = id in ["lx", "ly", "rx", "ry"] or here in ["lx", "ly", "rx", "ry"]
		if stick and x.get("t", "") != "b" and y.get("t", "") != "b" and x.get("i", -1) == y.get("i", -2):
			return id
	return ""


func _step_name(id: String) -> String:
	for s in STEPS:
		if s["id"] == id:
			return s["name"]
	return id


## Where each axis rests now (a step reads movement away from this).
func _snap() -> void:
	rest = pad.raw_state(device)["ax"].duplicate()


func _process(_delta: float) -> void:
	if state == "step" and held != "" and _let_go(held) and Time.get_ticks_msec() - held_at >= SETTLE_MS:
		held = ""
		_next()
	_update_readout()


func _let_go(src: String) -> bool:
	var x: Dictionary = pad.parse_source(src)
	var raw: Dictionary = pad.raw_state(device)
	match x.get("t", ""):
		"b":
			return not raw["btn"].has(x["i"])
		"a":
			return absf(float(raw["ax"].get(x["i"], 0.0)) - float(rest.get(x["i"], 0.0))) < BACK
		"h":
			return absf(float(raw["ax"].get(x["i"], 0.0)) - float(x["v"])) >= 0.08
	return true


func _next() -> void:
	step += 1
	if step >= STEPS.size():
		finish()
		return
	_snap()
	_build()


## Skip this step (the controller has no such control, or keep the default).
func skip() -> void:
	if state != "step":
		return
	got.erase(STEPS[step]["id"])
	held = ""
	note = TEXT["skipped"]
	note_col = UI.DIM
	_next()


## Back a step, to record it again.
func redo() -> void:
	if state != "step":
		return
	held = ""
	step = maxi(0, step - 1)
	got.erase(STEPS[step]["id"])
	note = ""
	_snap()
	_build()


## Saves what was recorded. A skipped control keeps its default input, if
## nothing recorded uses that input.
func finish() -> void:
	var layout := got.duplicate()
	var defaults: Dictionary = pad.default_layout(device)
	for id in defaults:
		if layout.has(id):
			continue
		var src := String(defaults[id]).get_slice(",", 0)
		if _taken_by(src, id) == "":
			layout[id] = src
	pad.set_layout(device, layout)
	pad.stop_capture()
	got = layout
	state = "done"
	note = ""
	_build()


func reset() -> void:
	if device < 0:
		return
	pad.reset_layout(device)
	pad.start_capture(_on_raw)
	state = "pick"
	note = TEXT["reset_done"]
	note_col = UI.GOOD
	_build()


# --- the page ---------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	readout = null
	var small: bool = menu != null and menu.compact()
	if state == "pick":
		_line(TEXT["intro"], UI.DIM, UI.SIZE_BODY)
	if device >= 0:
		var info: Dictionary = pad.joy_info(device)
		var nm: String = info["name"] if info["name"] != "" else TEXT["unnamed"]
		_line(TEXT["controller"] % [nm, TEXT["kinds"].get(pad._dev(device)["kind"], "")], UI.FAINT, UI.SIZE_SMALL, true)
	# The big prompt.
	var say := ""
	var hint := ""
	match state:
		"pick":
			say = TEXT["pick"] if device >= 0 or not Input.get_connected_joypads().is_empty() else TEXT["none"]
			hint = TEXT["pick_hint"] if device >= 0 else TEXT["nav_early"]
		"step":
			var s: Dictionary = STEPS[step]
			say = s["say"] if s.has("say") else TEXT["trigger" if s["kind"] == "trigger" else "button"] % s["for"]
			hint = s["hint"]
		"done":
			say = TEXT["done"]
			hint = TEXT["done_hint"]
	var big := _line(say, UI.GOLD, 20 if small else 26, true)
	big.set_meta("prompt", true)
	_line(hint, UI.DIM, UI.SIZE_BODY, true)
	if note != "":
		_line(note, note_col, UI.SIZE_LABEL, true).set_meta("note", true)
	if state == "step":
		_line(TEXT["step"] % [step + 1, STEPS.size()] + "   ·   " + (TEXT["nav"] if step > 1 else TEXT["nav_early"]), UI.FAINT, UI.SIZE_SMALL, true)
	# Buttons (keys, mouse and touch).
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var first: Button = null
	match state:
		"pick":
			first = _button(TEXT["begin"], begin.bind(-1), row)
			first.disabled = device < 0
			var r := _button(TEXT["reset"], reset, row)
			r.disabled = device < 0 or not pad.has_custom(device)
		"step":
			first = _button(TEXT["skip"], skip, row)
			_button(TEXT["redo"], redo, row).disabled = step == 0
			_button(TEXT["again"], begin.bind(-1), row)
		"done":
			first = _button(TEXT["finish"], func(): menu.go_back(), row)
			_button(TEXT["again"], begin.bind(-1), row)
			_button(TEXT["reset"], reset, row)
	# What's been recorded so far.
	if state != "pick" and not got.is_empty():
		_line(TEXT["recorded"].to_upper(), Color(UI.GOLD, 0.7), 12)
		var grid := GridContainer.new()
		grid.columns = 2 if small else 4
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 1)
		add_child(grid)
		for s in STEPS:
			if got.has(s["id"]):
				grid.add_child(_cell(s["name"], UI.DIM))
				grid.add_child(_cell(pad.source_text(got[s["id"]]), UI.TEXT))
	# The live readout.
	_line(TEXT["readout"].to_upper(), Color(UI.GOLD, 0.7), 12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.045, 0.07), Color(1, 1, 1, 0.06), 6, 1, 8.0))
	add_child(panel)
	readout = Label.new()
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.custom_minimum_size.x = 260.0
	readout.add_theme_font_size_override("font_size", UI.SIZE_SMALL + 1)
	readout.add_theme_color_override("font_color", UI.DIM)
	panel.add_child(readout)
	readout_text = ""
	_update_readout()
	if first != null and is_inside_tree() and not (main != null and main.touch_active):
		_focus.call_deferred(first if not first.disabled else null)


func _focus(b: Button) -> void:
	if b != null and is_instance_valid(b) and b.is_inside_tree():
		b.grab_focus()


func _line(text: String, col: Color, size: int, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 260.0
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _cell(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, action: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The controller's raw buttons and axes, as they arrive.
func readout_lines() -> String:
	var dev: int = device if device >= 0 else pad.last_device
	if dev < 0:
		return TEXT["readout_none"]
	var info: Dictionary = pad.joy_info(dev)
	var raw: Dictionary = pad.raw_state(dev)
	var lines: Array = []
	lines.append(TEXT["readout_head"] % [info["name"] if info["name"] != "" else TEXT["unnamed"], dev])
	var about: Array = [TEXT["browser_standard"] if info["standard"] else TEXT["browser_raw"], TEXT["godot_known"] if info["known"] else TEXT["godot_unknown"]]
	if info["guid"] != "":
		about.append(TEXT["id"] % info["guid"])
	lines.append("  ·  ".join(about))
	var btns: Array = raw["btn"].keys()
	btns.sort()
	lines.append(TEXT["buttons"] % (" ".join(btns.map(func(b): return str(b))) if not btns.is_empty() else TEXT["nothing"]))
	var axes: Array = raw["ax"].keys()
	axes.sort()
	var parts: Array = axes.map(func(a): return "%d: %+.2f" % [a, raw["ax"][a]])
	lines.append(TEXT["axes"] % ("   ".join(parts) if not parts.is_empty() else TEXT["nothing"]))
	return "\n".join(lines)


func _update_readout() -> void:
	if readout == null:
		return
	var t := readout_lines()
	if t != readout_text:
		readout_text = t
		readout.text = t
