extends RefCounted
## How every menu answers the keyboard, the mouse, a controller and touch,
## in one place, so they all follow the same rules:
##
##   - Hover moves the focus (only one highlight shows; the keys go on from
##     what the mouse last touched). On a phone nothing shows the focus.
##   - The arrow keys, the d-pad and the left stick are one and the same: a
##     step per press, and holding repeats at one rate (DELAY, then RATE).
##   - Enter, Space, A, a click and a tap press the focused thing. On a slot
##     that opens its card (its first button takes the focus).
##   - Esc, B, a right-click or the mouse's back button go back one level,
##     the focus returning to what opened the page. In a text box they only
##     leave the box.
##   - Q / E and LB / RB switch tabs (the physical keys, whatever the layout).
##   - The mouse wheel and the right stick scroll; sliders never take the wheel.
##   - Single lists (the rail, the title's buttons, the appearance rows, the
##     cards) wrap round; grids and long pages stop at their edges.
##   - Prompts follow the last thing used ("Press again" / "Tap again").
##
## menu.gd, main.gd (the card screens) and pad_setup.gd call in here.

## The four directions, and the side of a control each one looks to.
const DIRS := ["ui_up", "ui_down", "ui_left", "ui_right"]
const SIDES := {"ui_left": SIDE_LEFT, "ui_up": SIDE_TOP, "ui_right": SIDE_RIGHT, "ui_down": SIDE_BOTTOM}
## Holding a direction: the first repeat after DELAY seconds, then every RATE.
const DELAY := 0.35
const RATE := 0.09
## The right stick scrolls a page this many pixels a second, pushed all the way.
const SCROLL_SPEED := 900.0
## The words for a second press, by what was used last.
const AGAIN := {"touch": "Tap again", "other": "Press again"}


## Holding a direction repeats it, the same for keys, the d-pad and the stick
## (Godot repeats only the keyboard, at the system's rate, and a controller
## not at all). update() once a frame, then pulse(action) is true on the
## frame it was pressed and on each repeat.
class Repeat:
	var next_at := {}  # action -> when (msec) it repeats next
	var fired := {}  # actions that pulse this frame
	var frame := -1
	var last_ms := -1  # when it last updated (a long frame doesn't count as holding)

	func update(actions: Array = DIRS) -> void:
		var f := Engine.get_process_frames()
		if f == frame:
			return
		frame = f
		fired.clear()
		var now := Time.get_ticks_msec()
		# A long frame (a page being built: the train builds all its cars)
		# isn't time the player held the key: the repeats wait on.
		var stall := now - last_ms - 50 if last_ms >= 0 else 0
		last_ms = now
		if stall > 0:
			for a in next_at:
				next_at[a] = int(next_at[a]) + stall
		for a in actions:
			if Input.is_action_just_pressed(a):
				fired[a] = true
				next_at[a] = now + int(DELAY * 1000.0)
			elif Input.is_action_pressed(a) and next_at.has(a):
				if now >= int(next_at[a]):
					fired[a] = true
					next_at[a] = now + int(RATE * 1000.0)
			elif not Input.is_action_pressed(a):
				next_at.erase(a)

	func pulse(action: String) -> bool:
		return fired.has(action)

	## Forget what's held (a page opened under a held key starts afresh).
	func reset() -> void:
		next_at.clear()
		fired.clear()


## True if this event is one of the four directions (any device, echo or not).
static func is_dir_event(event: InputEvent) -> bool:
	for a in DIRS:
		if event.is_action(a):
			return true
	return false


## The mouse really moved (not a nudge a touch screen sends).
static func mouse_moved(event: InputEvent) -> bool:
	return event is InputEventMouseMotion and event.relative.length() >= 1.0


## A right-click or the mouse's back button: back one level.
static func is_back_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_XBUTTON1)


## "Press again" or "Tap again", by what was used last.
static func again(main) -> String:
	return AGAIN["touch"] if main != null and main.touch_active else AGAIN["other"]


## Fills {again} in a line of text.
static func fill(text: String, main) -> String:
	return text.replace("{again}", again(main))


## What a control is, so the same one can be found again after its page is
## rebuilt: its first telling meta, else its text, else its place in the list.
const METAS := ["rail", "tab", "view", "part", "bud", "tree_act", "slot", "setting", "appearance", "climbers", "climber_slot", "climber_delete", "choice", "archive", "option", "finish", "turn", "tower", "car", "shelf", "panel_tab", "over", "back",
	"data_edit", "data_slider", "data_reset", "data_swatch", "data_toggle", "data_section", "data_up", "data_help", "data_more", "data_close",
	"pick", "station_do"]


static func describe(c: Control, list: Array) -> Dictionary:
	if c == null or not is_instance_valid(c):
		return {}
	for m in METAS:
		if c.has_meta(m):
			return {"meta": m, "value": c.get_meta(m)}
	if c is Button and c.text != "":
		return {"text": c.text}
	var i := list.find(c)
	return {"index": i} if i >= 0 else {}


static func find(list: Array, d: Dictionary) -> Control:
	if d.is_empty():
		return null
	for c in list:
		if not is_instance_valid(c):
			continue
		if d.has("meta") and c.has_meta(d["meta"]) and c.get_meta(d["meta"]) == d["value"]:
			return c
		if d.has("text") and c is Button and c.text == d["text"]:
			return c
	if d.has("index") and int(d["index"]) >= 0 and int(d["index"]) < list.size():
		return list[int(d["index"])]
	return null


## The topmost control of a list under a point (inside any scroll it sits in).
static func topmost_at(list: Array, pos: Vector2) -> Control:
	var found: Control = null
	for c in list:
		if not is_instance_valid(c) or not c.is_visible_in_tree() or c.focus_mode == Control.FOCUS_NONE:
			continue
		if not c.get_global_rect().has_point(pos):
			continue
		var sc := scroll_of(c)
		if sc != null and not sc.get_global_rect().has_point(pos):
			continue
		found = c
	return found


## The nearest ScrollContainer a control sits in, or null.
static func scroll_of(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## Left / Right on a slider: one step. False if it's already at that end.
static func step_slider(s: Range, by: int) -> bool:
	var v: float = clampf(s.value + by * s.step, s.min_value, s.max_value)
	if is_equal_approx(v, s.value):
		return false
	s.value = v
	return true


## A frame's real length: Godot scales `delta` with the game's time, which
## stops while a ring is open; the HUD's own timers keep real time.
static func real_delta(delta: float) -> float:
	if Engine.time_scale > 0.001:
		return delta / Engine.time_scale
	return 1.0 / maxf(Engine.get_frames_per_second(), 1.0)


## The right stick's push up (-1) or down (1), past its deadzone.
static func stick_scroll() -> float:
	return Input.get_axis("aim_up", "aim_down")


# --- rings on a phone -------------------------------------------------------------

## Where a ring (radius `outer`, its widest part) sits on a phone: next to
## the thumb that holds its button, never under it, and inside the screen.
## It goes toward the middle of the screen from the thumb; if the screen's
## edge pushes it back over the thumb, it tries straight up, then left.
static func ring_center(thumb: Vector2, outer: float, view: Vector2, thumb_r := 46.0, below := 0.0) -> Vector2:
	var gap := outer + thumb_r + 8.0
	var lo := Vector2(outer + 8.0, outer + 8.0)
	var hi := Vector2(view.x - outer - 8.0, view.y - outer - 8.0 - below)
	if hi.x < lo.x:
		hi.x = lo.x
	if hi.y < lo.y:
		hi.y = lo.y
	var dirs: Array = []
	var mid := view * 0.5 - thumb
	if mid.length() > 1.0:
		dirs.append(mid.normalized())
	dirs.append_array([Vector2.UP, Vector2.LEFT, Vector2(-0.7, -0.7).normalized(), Vector2.RIGHT, Vector2.DOWN])
	var best := Vector2.ZERO
	var best_d := -1.0
	for d in dirs:
		var c: Vector2 = (thumb + d * gap).clamp(lo, hi)
		var away := c.distance_to(thumb)
		if away >= gap - 0.5:
			return c
		if away > best_d:
			best_d = away
			best = c
	return best
