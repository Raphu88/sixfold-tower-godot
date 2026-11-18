extends RefCounted
## The controls: few, with pictures, in the full game's glassy style (ui.gd).
##
## Touch: put a thumb anywhere on the left side and slide it to walk (a
## floating joystick). Right side, round the attack button: Roll, Parry,
## the magic button (once you have a mark) with a gem for each mark above it
## to pick which magic, and Swap (the next weapon). Each button shows a
## picture with a short word under it. Top right: fullscreen and home.
## Keyboard: arrows or WASD walk; Space, J or Enter attack (hold to keep
## going); L or Ctrl roll; K or Q parry; E cast; Tab or X swap; 1-6 pick a
## magic. Controller: left stick walks, A attacks, B rolls, the left trigger
## parries, Y casts, X swaps, the shoulder buttons pick a magic.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/data.gd")
const UI := preload("res://scripts/ui.gd")

## Sizes (radius, virtual px). Smaller than before so the room stays in view
## in fullscreen; a touch still counts a little way outside each (HIT_PAD).
const STICK_R := 62.0
const ATTACK_R := 58.0
const SMALL_R := 40.0  # Roll, Parry
const MAGIC_R := 44.0
const SWAP_R := 32.0
const GEM_R := 24.0
const TOP_R := 26.0
const HIT_PAD := 16.0
const MOUSE := 100  # the mouse acts as one more finger

var size := Vector2(1280, 720)
var touch_used := false
## index -> what it holds: "stick", "attack", "roll", "parry", "magic", "swap", "home", "full", "gem:<essence>"
var held := {}
var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO

var move := Vector2.ZERO
var attack_held := false
var attack_pressed := false
var roll_pressed := false
var parry_pressed := false
var magic_pressed := false
var swap_pressed := false
var home_pressed := false
var choose := ""  # an essence chosen this frame
var cycle := 0  # +1 / -1: the controller's shoulder buttons
var _key_attack := false

## Set by the climb each frame.
var magics: Array = []  # the marks (essences)
var chosen := ""
var charge := {}  # essence -> 0..1
var weapon := "sword"
var roll_ready := 1.0  # 0..1
var parry_ready := 1.0
## The words under the buttons (Data.TEXT).
var words := {}


func attack_center() -> Vector2:
	return size - Vector2(108, 108)


func roll_center() -> Vector2:
	return attack_center() + Vector2(-128, 34)


func parry_center() -> Vector2:
	return attack_center() + Vector2(10, -128)


func magic_center() -> Vector2:
	return attack_center() + Vector2(-112, -104)


func swap_center() -> Vector2:
	return attack_center() + Vector2(-232, 56)


func gem_center(i: int) -> Vector2:
	return Vector2(size.x - 52.0 - 56.0 * float(i), size.y - 340.0)


func home_center() -> Vector2:
	return Vector2(size.x - 44, 44)


func full_center() -> Vector2:
	return Vector2(size.x - 108, 44)


func stick_home() -> Vector2:
	return Vector2(150, size.y - 140)


## What a press at `p` lands on.
func _hit(p: Vector2) -> String:
	var spots := [["home", home_center(), TOP_R], ["full", full_center(), TOP_R], ["attack", attack_center(), ATTACK_R],
		["roll", roll_center(), SMALL_R], ["parry", parry_center(), SMALL_R], ["swap", swap_center(), SWAP_R]]
	if not magics.is_empty():
		spots.append(["magic", magic_center(), MAGIC_R])
		if magics.size() > 1:
			for i in magics.size():
				spots.append(["gem:" + String(magics[i]), gem_center(i), GEM_R])
	var best := ""
	var best_d := INF
	for s in spots:
		var d: float = p.distance_to(s[1]) - s[2]
		if d <= HIT_PAD and d < best_d:
			best_d = d
			best = s[0]
	if best != "":
		return best
	if p.x < size.x * 0.5:
		return "stick"
	return ""


## Feed every input event here. Returns true if it was used.
func handle(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		touch_used = true
		return _press(event.index, event.position, event.pressed)
	if event is InputEventScreenDrag:
		return _drag(event.index, event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _press(MOUSE, event.position, event.pressed)
	if event is InputEventMouseMotion and held.has(MOUSE):
		return _drag(MOUSE, event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		touch_used = false
		var k: int = event.physical_keycode
		if k == KEY_E or k == KEY_SHIFT:
			magic_pressed = true
		elif k == KEY_L or k == KEY_CTRL:
			roll_pressed = true
		elif k == KEY_K or k == KEY_Q:
			parry_pressed = true
		elif k == KEY_TAB or k == KEY_X:
			swap_pressed = true
		elif k >= KEY_1 and k <= KEY_6:
			var i := k - KEY_1
			if i < magics.size():
				choose = magics[i]
		elif k == KEY_ESCAPE:
			home_pressed = true
		return false
	if event is InputEventJoypadButton and event.pressed:
		touch_used = false
		match event.button_index:
			JOY_BUTTON_B:
				roll_pressed = true
			JOY_BUTTON_Y:
				magic_pressed = true
			JOY_BUTTON_X:
				swap_pressed = true
			JOY_BUTTON_RIGHT_SHOULDER:
				cycle = 1
			JOY_BUTTON_LEFT_SHOULDER:
				cycle = -1
			JOY_BUTTON_START:
				home_pressed = true
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value > 0.6:
		parry_pressed = true
	return false


func _press(index: int, p: Vector2, down: bool) -> bool:
	if not down:
		var what = held.get(index, "")
		held.erase(index)
		if what == "stick":
			stick_index = -1
		return what != ""
	var what := _hit(p)
	if what == "":
		return false
	held[index] = what
	match what:
		"stick":
			stick_index = index
			stick_origin = p
			stick_pos = p
		"attack":
			attack_pressed = true
		"roll":
			roll_pressed = true
		"parry":
			parry_pressed = true
		"magic":
			magic_pressed = true
		"swap":
			swap_pressed = true
		"home":
			home_pressed = true
		"full":
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			if what.begins_with("gem:"):
				choose = what.trim_prefix("gem:")
	return true


func _drag(index: int, p: Vector2) -> bool:
	if index == stick_index:
		stick_pos = p
		# The base follows a thumb that slides far, so it never runs out.
		var d := stick_pos - stick_origin
		if d.length() > STICK_R * 1.4:
			stick_origin = stick_pos - d.normalized() * STICK_R * 1.4
		return true
	return held.has(index)


## Reads the keys, sticks and touches into move / attack_held. Call once a frame.
func update() -> void:
	var v := Vector2.ZERO
	if stick_index >= 0:
		var d := stick_pos - stick_origin
		v = d / STICK_R
		if v.length() > 1.0:
			v = v.normalized()
		if d.length() < 8.0:
			v = Vector2.ZERO
	else:
		v.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		v.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if joy.length() > 0.25:
			v = joy
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): v.x = -1.0
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): v.x = 1.0
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): v.y = -1.0
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): v.y = 1.0
		if v.length() > 1.0:
			v = v.normalized()
	move = v
	var keys := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_ENTER) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if keys and not _key_attack:
		attack_pressed = true
	_key_attack = keys
	attack_held = keys or held.values().has("attack")
	if cycle != 0 and magics.size() > 1:
		var i := magics.find(chosen)
		choose = magics[posmod(i + cycle, magics.size())]
	cycle = 0


## Clears this frame's presses (after the climb has read them).
func consume() -> void:
	attack_pressed = false
	roll_pressed = false
	parry_pressed = false
	magic_pressed = false
	swap_pressed = false
	home_pressed = false
	choose = ""


func release_all() -> void:
	held.clear()
	stick_index = -1
	move = Vector2.ZERO
	attack_held = false
	consume()


# --- drawing -------------------------------------------------------------------

## A button: the glass, its picture (drawn by `icon`) and its word under it.
func _button(c: CanvasItem, at: Vector2, r: float, id: String, col: Color, word: String, icon: Callable, ready := false, fill := 0.0, hint := false, t := 0.0) -> void:
	var down := held.values().has(id)
	UI.button(c, at, r, col, down, ready, fill)
	icon.call(at + Vector2(0, -r * 0.14), r * 0.62)
	if word != "":
		Art.words(c, at + Vector2(0, r * 0.56), word, clampi(int(r * 0.36), 12, 20), UI.TEXT)
	if hint:
		c.draw_arc(at, r + 10.0 + 5.0 * sin(t * 6.0), 0.0, TAU, 48, Color(1, 1, 0.7, 0.85), 4.0)
		Art.finger(c, at + Vector2(r * 0.3, r * 0.3), r * 0.8, t)


## Swap's picture: the next weapon, with arrows going round it.
func _swap_icon(c: CanvasItem, p: Vector2, r: float) -> void:
	var nxt: String = Data.WEAPON_ORDER[(Data.WEAPON_ORDER.find(weapon) + 1) % Data.WEAPON_ORDER.size()]
	Art.weapon_icon(c, p, r * 0.9, nxt)
	Art.swap_arrows(c, p, r * 1.15)


## Draws the controls. `hints`: "move", "attack", "roll", "parry", "magic",
## "gems", "swap": a pointing finger and a pulse on that control (the first time).
func draw(c: CanvasItem, t: float, hints := {}) -> void:
	# Joystick: a dark well in a thin gilt ring (the full game's), shown
	# where it waits once touch is in use, or under the thumb.
	var base := stick_origin if stick_index >= 0 else stick_home()
	var knob := stick_pos if stick_index >= 0 else stick_home()
	if stick_index >= 0:
		knob = base + (knob - base).limit_length(STICK_R)
	elif hints.has("move"):
		knob = base + Vector2(cos(t * 2.0), sin(t * 2.0) * 0.6) * STICK_R * 0.6
	if touch_used or stick_index >= 0 or hints.has("move"):
		c.draw_circle(base, STICK_R, Color(0, 0, 0, 0.3))
		c.draw_arc(base, STICK_R, 0.0, TAU, 48, Color(UI.GILT, 0.5), 2.0)
		UI.button(c, knob, 26.0, UI.GILT, stick_index >= 0)
		if hints.has("move") and stick_index < 0:
			Art.finger(c, knob + Vector2(8, 8), 34.0, t)
	var w: Dictionary = Data.WEAPONS.get(weapon, Data.WEAPONS["sword"])
	_button(c, attack_center(), ATTACK_R, "attack", Color(0.9, 0.4, 0.32), String(w.get("word", "")),
		func(p, r): Art.weapon_icon(c, p, r * 1.1, weapon), false, 0.0, hints.has("attack"), t)
	_button(c, roll_center(), SMALL_R, "roll", Color(0.6, 0.85, 1.0), String(words.get("roll", "")),
		func(p, r): Art.roll_icon(c, p, r), roll_ready >= 1.0, 0.0 if roll_ready >= 1.0 else roll_ready, hints.has("roll"), t)
	_button(c, parry_center(), SMALL_R, "parry", Color(1.0, 0.85, 0.45), String(words.get("parry", "")),
		func(p, r): Art.parry_icon(c, p, r), parry_ready >= 1.0, 0.0 if parry_ready >= 1.0 else parry_ready, hints.has("parry"), t)
	_button(c, swap_center(), SWAP_R, "swap", UI.GILT, String(words.get("swap", "")),
		func(p, r): _swap_icon(c, p, r), false, 0.0, hints.has("swap"), t)
	# Magic: lights up in its colour when it's ready; a ring fills as it recharges.
	if not magics.is_empty() and chosen != "":
		var col := Data.color(chosen)
		var ch := float(charge.get(chosen, 1.0))
		_button(c, magic_center(), MAGIC_R, "magic", col, String(Data.MAGIC[chosen].get("word", "")),
			func(p, r): Art.magic_icon(c, p, r * 0.95, chosen), ch >= 1.0, 0.0 if ch >= 1.0 else ch, hints.has("magic"), t)
		if magics.size() > 1:
			for i in magics.size():
				var e: String = magics[i]
				var gp := gem_center(i)
				if e == chosen:
					c.draw_circle(gp, GEM_R + 6.0, Color(UI.GILT_HI, 0.8))
				UI.button(c, gp, GEM_R, Data.color(e), false, float(charge.get(e, 1.0)) >= 1.0)
				Art.magic_icon(c, gp, GEM_R * 0.6, e)
			if hints.has("gems"):
				Art.finger(c, gem_center(magics.size() - 1) + Vector2(8, 8), 30.0, t)
	# Top: fullscreen and home.
	var fc := full_center()
	UI.button(c, fc, TOP_R, UI.GILT, held.values().has("full"))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := fc + Vector2(sx, sy) * 9.0
			c.draw_line(corner, corner - Vector2(sx * 6.0, 0), UI.TEXT, 2.5)
			c.draw_line(corner, corner - Vector2(0, sy * 6.0), UI.TEXT, 2.5)
	UI.button(c, home_center(), TOP_R, UI.GILT, held.values().has("home"))
	Art.house(c, home_center(), TOP_R * 0.7)
