extends RefCounted
## How every menu page and list scrolls, in one place (menu.gd and
## train_page.gd hand their input here), so it's quick and smooth everywhere:
##
##   - The mouse wheel moves a good step a notch (WHEEL_STEP, or WHEEL_SHARE
##     of the view if that's more: Godot's own is an eighth of the view),
##     eased over a few frames rather than jumping.
##   - A finger drag follows the finger one to one (the fractions of a pixel
##     a phone sends are kept, not dropped), and a flick carries on, slowing
##     down (FRICTION), when it's let go. A touch while it glides only stops
##     it (it presses nothing).
##   - Page Up / Page Down (LT / RT on a controller) jump most of a view;
##     Home / End go to the top and the bottom.
##   - The right stick scrolls, faster the longer it's held (STICK_SPEED up
##     to STICK_FAST times that, over STICK_RAMP seconds).
##
## It also keeps where a page was scrolled when the page is built again
## after a press (snapshot / keep): each scroll is known by its place among
## the page's nodes, and put back once the new page has its size.
##
## menu.gd owns one (`scroller`) and calls update() every frame.

const WHEEL_STEP := 120.0  # px a notch, at least
const WHEEL_SHARE := 0.22  # ...or this share of the view, if that's more
const GODOT_WHEEL_SHARE := 0.125  # (Godot's own ScrollContainer: an eighth of the view a notch)
const PAGE_SHARE := 0.85  # a page jump: this share of the view
const GLIDE := 18.0  # how quickly an eased scroll closes on its goal (per second)
const FRICTION := 2.4  # how quickly a flick slows (per second)
const FLING_MIN := 140.0  # px a second: a slower release just stops
const FLING_MAX := 6500.0
const STOP_SPEED := 24.0
const SAMPLE_MS := 90  # a flick's speed: the finger's last this many ms
const STICK_SPEED := 1100.0  # px a second, the right stick pushed all the way...
const STICK_FAST := 2.6  # ...up to this many times that, held
const STICK_RAMP := 0.7  # seconds held to reach full speed
## A finger moving this far is a drag (it scrolls), not a tap (no button is pressed).
const DRAG := 14.0
## How many frames after a page is built its scrolls are put back (its
## wrapped words and cards can take a frame or two to reach their height).
const KEEP_FRAMES := 8

var sc: ScrollContainer = null  # what's gliding (the wheel, a page jump, a flick)
var pos := 0.0
var goal := 0.0
var has_goal := false
var vel := 0.0
var written := -1
# A finger drag.
var drag_sc: ScrollContainer = null
var drag_pos := 0.0
var samples: Array = []  # [msec, position]
# The right stick and other small pushes (fractions carried over).
var nudge_sc: ScrollContainer = null
var nudge_pos := 0.0
var stick_t := 0.0
# Keeping scrolls across a rebuild.
var keep := {}  # key -> [vertical, horizontal]
var keep_root: Node = null
var keep_left := 0
var kept := {}  # key -> where the scroll stood after it was last put back (something else moving it: it's let go)


## How far a scroll can go down (0 if everything fits).
static func top(s: ScrollContainer) -> float:
	if s == null or not is_instance_valid(s):
		return 0.0
	var bar := s.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


static func can_scroll(s: ScrollContainer) -> bool:
	return top(s) > 1.0


## How far a notch of the wheel moves this scroll.
static func wheel_step(s: ScrollContainer) -> float:
	return maxf(WHEEL_STEP, s.size.y * WHEEL_SHARE)


## The deepest visible scroll under a point that has something to scroll,
## among `root`'s (or null).
static func scroll_at(root: Node, at: Vector2) -> ScrollContainer:
	var found: ScrollContainer = null
	for n in root.find_children("*", "ScrollContainer", true, false):
		var s: ScrollContainer = n
		if s.is_visible_in_tree() and s.mouse_filter != Control.MOUSE_FILTER_IGNORE and s.get_global_rect().has_point(at) and can_scroll(s):
			found = s
	return found


# --- the wheel, page jumps ---------------------------------------------------------

## The wheel turned `notches` (down is positive).
func wheel(s: ScrollContainer, notches: float) -> void:
	_glide(s, _base(s) + notches * wheel_step(s))


## Most of a view up (-1) or down (1).
func page(s: ScrollContainer, pages: float) -> void:
	_glide(s, _base(s) + pages * maxf(s.size.y * PAGE_SHARE, 60.0))


## The top (false) or the bottom (true).
func edge(s: ScrollContainer, bottom: bool) -> void:
	_glide(s, top(s) if bottom else 0.0)


func _base(s: ScrollContainer) -> float:
	return goal if s == sc and has_goal else float(s.scroll_vertical)


func _glide(s: ScrollContainer, to: float) -> void:
	if s == null or not is_instance_valid(s):
		return
	cancel_keep()
	if s != sc or not has_goal:
		pos = float(s.scroll_vertical)
	sc = s
	goal = clampf(to, 0.0, top(s))
	has_goal = true
	vel = 0.0
	written = s.scroll_vertical


# --- a finger -------------------------------------------------------------------------

## A finger went down: anything gliding stops. True if something was
## moving (that touch only stops it: it presses nothing).
func touch_down() -> bool:
	var was := moving()
	stop()
	drag_sc = null
	return was


## The finger moved `dy` (down is positive) on a scroll: the page follows it.
func drag(s: ScrollContainer, dy: float) -> void:
	if s == null or not is_instance_valid(s):
		return
	cancel_keep()
	if s != drag_sc:
		stop()
		drag_sc = s
		drag_pos = float(s.scroll_vertical)
		samples = []
	if absf(drag_pos - float(s.scroll_vertical)) > 1.5:
		drag_pos = float(s.scroll_vertical)  # (something else moved it)
	drag_pos = clampf(drag_pos - dy, 0.0, top(s))
	s.scroll_vertical = roundi(drag_pos)
	var now := Time.get_ticks_msec()
	samples.append([now, drag_pos])
	while samples.size() > 2 and now - int(samples[0][0]) > SAMPLE_MS * 2:
		samples.pop_front()


## The finger let go: a flick carries on.
func release() -> void:
	var s := drag_sc
	drag_sc = null
	if s == null or not is_instance_valid(s) or samples.size() < 2:
		return
	var last: Array = samples[-1]
	var now := Time.get_ticks_msec()
	if now - int(last[0]) > SAMPLE_MS:
		return  # (the finger stopped before it let go)
	var first: Array = last
	for smp in samples:
		if int(last[0]) - int(smp[0]) <= SAMPLE_MS:
			first = smp
			break
	var dt := float(int(last[0]) - int(first[0])) / 1000.0
	if dt <= 0.0:
		return
	var v := (float(last[1]) - float(first[1])) / maxf(dt, 0.016)
	if absf(v) < FLING_MIN:
		return
	sc = s
	pos = float(s.scroll_vertical)
	vel = clampf(v, -FLING_MAX, FLING_MAX)
	has_goal = false
	written = s.scroll_vertical


# --- the right stick, small pushes ------------------------------------------------------

## The right stick pushed `push` (-1 up .. 1 down) this frame: faster the
## longer it's held.
func stick(s: ScrollContainer, push: float, delta: float) -> void:
	if absf(push) < 0.2 or s == null:
		stick_t = 0.0
		return
	stick_t += delta
	var k := clampf(stick_t / STICK_RAMP, 0.0, 1.0)
	nudge(s, push * STICK_SPEED * lerpf(1.0, STICK_FAST, k * k) * delta)


## Moves a scroll by `px` (fractions carried over to the next push).
func nudge(s: ScrollContainer, px: float) -> void:
	if s == null or not is_instance_valid(s):
		return
	cancel_keep()
	if s == sc:
		stop()
	if s != nudge_sc or absf(nudge_pos - float(s.scroll_vertical)) > 1.5:
		nudge_sc = s
		nudge_pos = float(s.scroll_vertical)
	nudge_pos = clampf(nudge_pos + px, 0.0, top(s))
	s.scroll_vertical = roundi(nudge_pos)


# --- gliding -----------------------------------------------------------------------------

func moving() -> bool:
	return sc != null and is_instance_valid(sc) and (has_goal or absf(vel) > STOP_SPEED)


func stop() -> void:
	sc = null
	vel = 0.0
	has_goal = false


## Once a frame (menu.gd _process): the glide or flick moves on, and a page
## just built gets its scrolls back.
func update(delta: float) -> void:
	_keep_step()
	if sc == null:
		return
	if not is_instance_valid(sc) or not sc.is_inside_tree():
		stop()
		return
	if sc.scroll_vertical != written:
		stop()  # (something else moved it: the keys' focus, say)
		return
	var hi := top(sc)
	if has_goal:
		goal = minf(goal, hi)
		pos = lerpf(pos, goal, 1.0 - exp(-GLIDE * delta))
		if absf(goal - pos) < 0.6:
			pos = goal
			has_goal = false
	else:
		pos += vel * delta
		vel *= exp(-FRICTION * delta)
		if pos <= 0.0 or pos >= hi:
			vel = 0.0
		if absf(vel) < STOP_SPEED:
			vel = 0.0
	pos = clampf(pos, 0.0, hi)
	sc.scroll_vertical = roundi(pos)
	written = sc.scroll_vertical
	if not has_goal and vel == 0.0:
		sc = null


# --- keeping the scroll across a rebuild ---------------------------------------------------

## A scroll's key: its place among `root`'s nodes (the child index at each
## step down), so the same scroll on a page built again has the same key.
## A scroll can name itself instead with the meta "scroll_key".
static func key_of(root: Node, s: Node) -> String:
	if s.has_meta("scroll_key"):
		return "k:" + str(s.get_meta("scroll_key"))
	var bits: Array = []
	var n := s
	while n != null and n != root:
		bits.push_front(str(n.get_index()))
		n = n.get_parent()
	return "/".join(bits)


## Where every scroll under `root` stands.
static func snapshot(root: Node) -> Dictionary:
	var out := {}
	for n in root.find_children("*", "ScrollContainer", true, false):
		var s: ScrollContainer = n
		if s.scroll_vertical != 0 or s.scroll_horizontal != 0:
			out[key_of(root, s)] = [s.scroll_vertical, s.scroll_horizontal]
	return out


## The page under `root` was built again: put its scrolls back where
## `snap` had them, over the next few frames (as the new page takes its size).
func keep_from(root: Node, snap: Dictionary) -> void:
	keep = snap.duplicate()
	kept = {}
	keep_root = root
	keep_left = KEEP_FRAMES if not snap.is_empty() else 0
	_keep_apply()


## The player scrolled (or moved on): stop putting scrolls back.
func cancel_keep() -> void:
	keep_left = 0


func keeping() -> bool:
	return keep_left > 0


func _keep_step() -> void:
	if keep_left <= 0:
		return
	keep_left -= 1
	_keep_apply()


func _keep_apply() -> void:
	if keep_root == null or not is_instance_valid(keep_root) or keep.is_empty():
		keep_left = 0
		return
	for n in keep_root.find_children("*", "ScrollContainer", true, false):
		var s: ScrollContainer = n
		var k := key_of(keep_root, s)
		if not keep.has(k):
			continue
		var want: Array = keep[k]
		var cur := s.scroll_vertical
		# Moved since it was put back, and not just held short by a page
		# still taking its height: the page itself scrolled it (to show a
		# card, the focus...): that wins, it's let go.
		if kept.has(k) and cur != int(kept[k]) and not (cur < int(want[0]) and absf(float(cur) - top(s)) <= 1.0):
			keep.erase(k)
			continue
		if cur != int(want[0]):
			s.scroll_vertical = int(want[0])
		if s.scroll_horizontal != int(want[1]):
			s.scroll_horizontal = int(want[1])
		kept[k] = s.scroll_vertical
