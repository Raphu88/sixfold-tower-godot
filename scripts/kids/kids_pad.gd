extends RefCounted
## The kids version's controls: big and few.
##
## Touch: put a thumb anywhere on the left side and slide it to walk (a
## floating joystick). Right side: a huge sword button (hold it to keep
## swinging) and, once you have a mark, the magic button with a gem for each
## mark above it to pick which magic. Top right: home and fullscreen.
## Keyboard: arrows or WASD walk; Space, J or Enter swing; K or E cast; 1-6
## pick a magic. Controller: left stick walks, A swings, X or B casts, the
## shoulder buttons pick a magic.

const Art := preload("res://scripts/kids/kids_art.gd")
const Data := preload("res://scripts/kids/kids_data.gd")

const STICK_R := 85.0
const ATTACK_R := 105.0
const MAGIC_R := 80.0
const GEM_R := 36.0
const TOP_R := 36.0
const MOUSE := 100  # the mouse acts as one more finger

var size := Vector2(1280, 720)
var touch_used := false
## index -> what it holds: "stick", "attack", "magic", "home", "full", "gem"
var held := {}
var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO

var move := Vector2.ZERO
var attack_held := false
var attack_pressed := false
var magic_pressed := false
var home_pressed := false
var choose := ""  # an essence chosen this frame
var cycle := 0  # +1 / -1: the controller's shoulder buttons
var _key_attack := false

## Set by the climb each frame: the marks (essences), the chosen one, and
## each one's charge (0 to 1).
var magics: Array = []
var chosen := ""
var charge := {}


func attack_center() -> Vector2:
	return size - Vector2(150, 150)


func magic_center() -> Vector2:
	return size - Vector2(345, 120)


func gem_center(i: int) -> Vector2:
	return Vector2(size.x - 90.0 - 82.0 * float(i), size.y - 305.0)


func home_center() -> Vector2:
	return Vector2(size.x - 60, 60)


func full_center() -> Vector2:
	return Vector2(size.x - 150, 60)


func stick_home() -> Vector2:
	return Vector2(190, size.y - 170)


## What a press at `p` lands on.
func _hit(p: Vector2) -> String:
	if p.distance_to(home_center()) <= TOP_R + 14.0:
		return "home"
	if p.distance_to(full_center()) <= TOP_R + 14.0:
		return "full"
	if p.distance_to(attack_center()) <= ATTACK_R + 30.0:
		return "attack"
	if not magics.is_empty():
		if p.distance_to(magic_center()) <= MAGIC_R + 24.0:
			return "magic"
		if magics.size() > 1:
			for i in magics.size():
				if p.distance_to(gem_center(i)) <= GEM_R + 14.0:
					return "gem:" + String(magics[i])
	if p.x < size.x * 0.5:
		return "stick"
	return "attack"  # (anywhere else on the right swings: big target)


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
		if k == KEY_K or k == KEY_E or k == KEY_SHIFT:
			magic_pressed = true
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
			JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y:
				magic_pressed = true
			JOY_BUTTON_RIGHT_SHOULDER:
				cycle = 1
			JOY_BUTTON_LEFT_SHOULDER:
				cycle = -1
			JOY_BUTTON_START:
				home_pressed = true
	return false


func _press(index: int, p: Vector2, down: bool) -> bool:
	if not down:
		var what = held.get(index, "")
		held.erase(index)
		if what == "stick":
			stick_index = -1
		return what != ""
	var what := _hit(p)
	held[index] = what
	match what:
		"stick":
			stick_index = index
			stick_origin = p
			stick_pos = p
		"attack":
			attack_pressed = true
		"magic":
			magic_pressed = true
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
	magic_pressed = false
	home_pressed = false
	choose = ""


func release_all() -> void:
	held.clear()
	stick_index = -1
	move = Vector2.ZERO
	attack_held = false
	consume()


# --- drawing -------------------------------------------------------------------

func _button(c: CanvasItem, p: Vector2, r: float, col: Color, down: bool) -> void:
	c.draw_circle(p + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
	c.draw_circle(p, r + 4.0, Color(0.06, 0.05, 0.08, 0.8))
	c.draw_circle(p, r, col.darkened(0.25) if down else col)
	c.draw_arc(p, r - 6.0, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.25), 5.0)


## Draws the controls. `hints`: "move", "attack", "magic", "gems": a
## pointing finger and a pulse on that control (the first time).
func draw(c: CanvasItem, t: float, hints := {}) -> void:
	# Joystick: a faint ring where it waits; under the thumb when held.
	var base := stick_origin if stick_index >= 0 else stick_home()
	var knob := stick_pos if stick_index >= 0 else stick_home()
	if stick_index >= 0:
		var d := knob - base
		if d.length() > STICK_R:
			knob = base + d.normalized() * STICK_R
	elif hints.has("move"):
		knob = base + Vector2(cos(t * 2.0), sin(t * 2.0) * 0.6) * STICK_R * 0.6
	if touch_used or stick_index >= 0 or hints.has("move"):
		c.draw_circle(base, STICK_R + 10.0, Color(1, 1, 1, 0.08))
		c.draw_arc(base, STICK_R + 10.0, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 4.0)
		c.draw_circle(knob, 42.0, Color(1, 1, 1, 0.45 if stick_index >= 0 else 0.3))
		if hints.has("move") and stick_index < 0:
			Art.finger(c, knob + Vector2(10, 10), 40.0, t)
	# Sword
	var ac := attack_center()
	var pulse := 1.0 + (0.06 * sin(t * 6.0) if hints.has("attack") else 0.0)
	_button(c, ac, ATTACK_R * pulse, Color(0.85, 0.35, 0.3), attack_held)
	Art.sword(c, ac, ATTACK_R * 0.62)
	if hints.has("attack"):
		c.draw_arc(ac, ATTACK_R + 14.0 + 8.0 * sin(t * 6.0), 0.0, TAU, 48, Color(1, 1, 0.7, 0.8), 6.0)
		Art.finger(c, ac + Vector2(20, 20), 50.0, t)
	# Magic
	if not magics.is_empty() and chosen != "":
		var mc := magic_center()
		var col := Data.color(chosen)
		var ch := float(charge.get(chosen, 1.0))
		var ready := ch >= 1.0
		_button(c, mc, MAGIC_R, col.darkened(0.1) if ready else Color(0.25, 0.23, 0.3), held.values().has("magic"))
		if not ready:
			# The recharge fills up like a clock.
			c.draw_arc(mc, MAGIC_R - 10.0, -PI / 2.0, -PI / 2.0 + TAU * ch, 40, col, 12.0)
		else:
			Art.glow(c, mc, MAGIC_R * 1.5, col, 0.6 + 0.4 * sin(t * 4.0))
		Art.magic_icon(c, mc, MAGIC_R * 0.6, chosen)
		if hints.has("magic"):
			c.draw_arc(mc, MAGIC_R + 14.0 + 8.0 * sin(t * 6.0), 0.0, TAU, 48, Color(1, 1, 0.7, 0.8), 6.0)
			Art.finger(c, mc + Vector2(16, 16), 46.0, t)
		if magics.size() > 1:
			for i in magics.size():
				var e: String = magics[i]
				var gp := gem_center(i)
				var sel := e == chosen
				if sel:
					c.draw_circle(gp, GEM_R + 9.0, Color(1, 1, 0.8, 0.85))
				_button(c, gp, GEM_R, Data.color(e).darkened(0.1 if float(charge.get(e, 1.0)) >= 1.0 else 0.55), false)
				Art.magic_icon(c, gp, GEM_R * 0.6, e)
			if hints.has("gems"):
				Art.finger(c, gem_center(magics.size() - 1) + Vector2(10, 10), 36.0, t)
	# Top: fullscreen and home.
	_button(c, full_center(), TOP_R * 0.85, Color(0.3, 0.3, 0.38), false)
	var fc := full_center()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := fc + Vector2(sx, sy) * 13.0
			c.draw_line(corner, corner - Vector2(sx * 8.0, 0), Color.WHITE, 3.0)
			c.draw_line(corner, corner - Vector2(0, sy * 8.0), Color.WHITE, 3.0)
	_button(c, home_center(), TOP_R, Color(0.3, 0.3, 0.38), false)
	Art.house(c, home_center(), TOP_R * 0.75)
