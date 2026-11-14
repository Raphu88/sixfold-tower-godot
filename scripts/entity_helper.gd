extends Control
## The Entity on the train: its sphere on every car and station screen (and
## the pages reached from the train: the Loadout, the stash, the climber's
## book...), drawn as in play (entity.gd draw_face). The menu (menu.gd) owns
## one, on top of everything else on the page.
##
## IDLE it rests in a corner that covers nothing (rest_spot: a spot clear of
## every button and word on the screen).
##
## EXPLAINING: it glides beside the button you point at and says what it
## does or where it goes, in a small bubble (the words: entity_help.gd):
##   mouse       hover a button (it waits DELAY first, so sweeping the mouse
##               across the screen doesn't make it fly about; it goes back
##               LEAVE after the pointer leaves)
##   keys, pad   move onto a button (the focus)
##   touch       press and hold a button for HOLD seconds: the explanation,
##               and letting go then does NOT press it (a normal tap still
##               presses at once)
## The bubble and the sphere never cover the button, stay on the screen and
## keep off the rail; of the places beside the button, it takes the one that
## covers the fewest neighbours (place). Settings: "The Entity explains
## buttons" off, and it only rests.
##
## TALKING: click or tap the sphere (or press L, or the right stick on a
## controller) and it talks with you (entity_talk.gd; menu.gd open_talk).

const Entity := preload("res://scripts/entity.gd")
const UI := preload("res://scripts/ui.gd")
const Nav := preload("res://scripts/nav.gd")
const Help := preload("res://scripts/entity_help.gd")
const Guide := preload("res://scripts/guide.gd")

## The pages it shows on (between climbs).
const PAGES := ["train", "station", "loadout", "stash", "climber", "mark", "library", "settings", "controls", "techniques"]
## Seconds: a hover waits this long before the sphere moves (keys a little
## less), goes back this long after the pointer leaves, a finger is held
## this long for an explanation, and the bubble stays this long after the
## finger lets go.
const DELAY := 0.35
const DELAY_KEYS := 0.18
const LEAVE := 0.6
const HOLD := 0.4
const LINGER := 2.5
## A finger moving this far is a drag, not a hold.
const SLIP := 14.0
## The sphere's radius (as in play), and its gap from the button.
const ORB_R := Guide.ORB_R
const GAP := 6.0
## The bubble: its widest (computer, phone), its narrowest, its type size
## and its padding.
const BUBBLE_W := 280.0
const BUBBLE_W_TOUCH := 250.0
const BUBBLE_MIN := 130.0
const FONT_SIZE := 14
const FONT_SIZE_TOUCH := 13
const PAD := Vector2(11.0, 7.0)

var menu  # menu.gd
var t := 0.0
var pos := Vector2(-1, -1)  # where the sphere is (it glides to `goal`)
var goal := Vector2.ZERO
var rest := Vector2.ZERO  # its corner while idle
var target: Control = null  # the button it's explaining
var text := ""  # what it says about it
var orb_at := Vector2.ZERO  # beside the target
var bubble := Rect2()  # the bubble beside the target
var pending: Control = null  # the button under the pointer, waiting out DELAY
var pending_t := 0.0
var appear := 0.0  # the bubble fading in (0..1)
var hold := {}  # a finger down: {at, ms, button, fired}
var linger := 0.0
var explained := 0  # explanations shown (tests)
var _eaten := false  # a touch on the sphere: its release is eaten too
var _mouse_eaten := false
var _key := ""  # the page (and car) it was last on
var _rest_t := 0.0
var _since_key := 0.0  # seconds since the page (or car) changed
var _drawn := false
var _target_rect := Rect2()
var _style: StyleBox
var orb: Control  # the sphere, on its own layer (the bubble's fade never dims it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("layout_stack", true)  # (a bubble over the page on purpose: the layout audit looks at its edges, not what it's over)
	orb = Control.new()
	orb.name = "EntityOrb"
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orb.draw.connect(_draw_orb)
	add_child(orb)


## On a page between climbs (not the title's, nor while arranging).
func active() -> bool:
	if menu == null or menu.main == null or not menu.visible:
		return false
	var main = menu.main
	if not bool(main.on_train) or menu.opened_from_title or not (String(menu.page) in PAGES):
		return false
	if main.get("arrange") != null and main.arrange != null and bool(main.arrange.is_open):
		return false
	return true


## The explanations are on (Settings: "The Entity explains buttons").
func help_on() -> bool:
	return bool(menu.settings.get("entity_help", true))


func touch() -> bool:
	return menu.main != null and bool(menu.main.touch_active)


# --- input ----------------------------------------------------------------------------

## The menu hands it every input first (menu.gd _input). True if used here:
## a click or tap on the sphere (it talks), or the release of a finger held
## for an explanation (so the button isn't pressed).
func input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and event.index == 0 and not event.pressed and _eaten:
		_eaten = false
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _mouse_eaten:
		_mouse_eaten = false
		return true
	if not active():
		hold = {}
		return false
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			hold = {}
			if on_orb(event.position):
				_eaten = true
				menu.open_talk()
				return true
			if help_on():
				hold = {"at": event.position, "ms": Time.get_ticks_msec(), "button": button_at(event.position), "fired": false}
			return false
		var fired: bool = bool(hold.get("fired", false))
		hold = {}
		if fired:
			linger = LINGER
			return true  # (held for its explanation: letting go doesn't press it)
		return false
	if event is InputEventScreenDrag and event.index == 0 and not hold.is_empty() and not bool(hold["fired"]):
		if (event.position - hold["at"]).length() > SLIP:
			hold = {}  # (a drag or a swipe, not a hold)
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not touch():
		if on_orb(event.position):
			_mouse_eaten = true
			menu.open_talk()
			return true
	return false


## True if a point is on the sphere (a finger's width on a phone).
func on_orb(at: Vector2) -> bool:
	if pos.x < 0.0:
		return false
	var reach := ORB_R + (12.0 if touch() else 4.0)
	return at.distance_to(pos) <= reach


## The buttons on the page showing (the car you're in on the train) and the rail.
func buttons() -> Array:
	var list: Array = menu.focusables()
	if menu.rail.visible:
		list = menu.rail.buttons + list
	return list.filter(func(c): return is_instance_valid(c) and c is Control and c.is_visible_in_tree())


## The topmost button under a point, or null.
func button_at(at: Vector2) -> Control:
	return Nav.topmost_at(buttons(), at)


# --- each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active():
		if _drawn:
			_drawn = false
			queue_redraw()
			orb.queue_redraw()
		target = null
		pending = null
		pos = Vector2(-1, -1)
		_key = ""
		return
	t += delta
	# A new page or car: back to its corner at once (no flying across).
	var key := "%s|%s|%s|%s" % [menu.page, menu.train_car, get_viewport_rect().size, menu.climber_tab]
	_rest_t -= delta
	_since_key += delta
	if key != _key or _rest_t <= 0.0:
		# (often while a new page settles, then twice a second)
		_rest_t = 0.1 if _since_key < 0.8 else 0.5
		rest = rest_spot()
		if key != _key:
			_key = key
			_since_key = 0.0
			target = null
			pending = null
			appear = 0.0
		if _since_key < 0.8 and target == null:
			pos = rest  # (the page settling: it sits there at once, no gliding)
	# The Entity talks: L, or the right stick (a click or tap on it: input).
	if Input.is_action_just_pressed("entity") and not menu._typing():
		menu.open_talk()
		return
	var wait := DELAY_KEYS if menu.nav_keys else DELAY
	if target != null and (not is_instance_valid(target) or not target.is_visible_in_tree()):
		# The page was built again (a choice): the same place's new button, at once.
		var was_shown := appear > 0.0
		target = null
		var again: Control = _candidate() if was_shown and hold.is_empty() else null
		pending = again
		pending_t = wait
		show_for(again)
	# What it should be explaining now.
	var cand: Control = _candidate()
	var moving: bool = menu.page == "train" and menu.train_view != null and menu.train_view.pos != float(menu.train_view.target)
	if moving:
		cand = null
	if cand != pending:
		pending = cand
		pending_t = 0.0
	else:
		pending_t += delta
	if pending != target:
		if pending != null and pending_t >= wait:
			show_for(pending)
		elif pending == null and (pending_t >= LEAVE or moving) and linger <= 0.0:
			show_for(null)
	linger = maxf(0.0, linger - delta)
	# The finger held long enough: say it now.
	if not hold.is_empty() and not bool(hold["fired"]) and Time.get_ticks_msec() - int(hold["ms"]) >= int(HOLD * 1000.0):
		hold["fired"] = true
		var b: Control = hold["button"]
		if b != null and is_instance_valid(b) and b.is_visible_in_tree():
			pending = b
			show_for(b)
			linger = LINGER
	if target != null:
		var r := target.get_global_rect()
		if r != _target_rect:
			_place_for(r)  # (it moved: a page scrolled)
	goal = orb_at if target != null else rest
	if pos.x < 0.0:
		pos = goal
	pos = pos.lerp(goal, 1.0 - exp(-delta * 10.0))
	var arrived := pos.distance_to(goal) < 10.0
	appear = move_toward(appear, 1.0 if target != null and arrived else 0.0, delta / 0.14)
	_drawn = true
	queue_redraw()
	orb.queue_redraw()


## The button the pointer, the keys or a finger is on (null for none).
func _candidate() -> Control:
	if not help_on():
		return null
	if touch():
		if bool(hold.get("fired", false)):
			return hold["button"]
		return target if linger > 0.0 else null
	if menu.nav_keys:
		var f: Control = get_viewport().gui_get_focus_owner()
		if f != null and is_instance_valid(f) and (f is BaseButton or f is HSlider) and menu.is_ancestor_of(f) and f.is_visible_in_tree():
			return f
		return null
	var at := get_local_mouse_position()
	if target != null and (on_orb(at) or (appear > 0.5 and bubble.has_point(at))):
		return target  # (the pointer went to the sphere or its words: it stays)
	return button_at(at)


## Explains a button now (null: back to the corner).
func show_for(b: Control) -> void:
	target = b
	text = ""
	if b != null:
		text = Help.explain(menu, b)
		if text == "":
			target = null
	if target != null:
		explained += 1
		_place_for(b.get_global_rect())
	else:
		_target_rect = Rect2()


func _place_for(r: Rect2) -> void:
	_target_rect = r
	var p := place(r, text)
	orb_at = p["orb"]
	bubble = p["bubble"]


# --- where it goes -----------------------------------------------------------------------

func _font() -> Font:
	return UI.font("body")


func _font_size() -> int:
	return FONT_SIZE_TOUCH if touch() or menu.compact() else FONT_SIZE


## How tall the bubble is at width `w`.
func bubble_h(w: float, words: String) -> float:
	return UI.text_height(_font(), words, w - PAD.x * 2.0, _font_size()) + PAD.y * 2.0


## The rail's box, if it's showing (nothing goes under it).
func _rail_rect() -> Rect2:
	return menu.rail.get_global_rect() if menu.rail.visible else Rect2()


## The other buttons on the screen (it keeps off them where it can).
func _neighbours(r: Rect2) -> Array:
	var out: Array = []
	for c in buttons():
		var cr: Rect2 = c.get_global_rect()
		if cr == r or cr.size.x <= 0.0:
			continue
		var sc := Nav.scroll_of(c)
		if sc != null:
			cr = cr.intersection(sc.get_global_rect())
			if cr.size.x <= 0.0 or cr.size.y <= 0.0:
				continue
		out.append(cr)
	return out


## Where the sphere and its bubble go beside a button's box `r`: {orb,
## bubble}. Never over the button, always on the screen and off the rail;
## of the places that fit, the one over the fewest neighbours (right, left,
## under, over, in that order when it's a tie).
func place(r: Rect2, words: String) -> Dictionary:
	var view := get_viewport_rect().size
	var screen := Rect2(Vector2(4, 4), view - Vector2(8, 8))
	var rail := _rail_rect()
	var others := _neighbours(r)
	if rail.size.x > 0.0 and rail.grow(1.0).encloses(r):
		# A rail entry: beside the rail, level with it (the rest of the rail stays clear).
		r = Rect2(r.position, Vector2(rail.end.x - r.position.x, r.size.y))
	var widest := BUBBLE_W_TOUCH if touch() or menu.compact() else BUBBLE_W
	var one_line := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x + PAD.x * 2.0 + 2.0
	widest = minf(widest, maxf(one_line, BUBBLE_MIN))
	var best := {}
	var best_score := INF
	for w in [widest, widest * 0.8, maxf(BUBBLE_MIN, widest * 0.62)]:
		var h := bubble_h(w, words)
		for side in [["right", 0.0], ["left", 30.0], ["below", 60.0], ["above", 90.0]]:
			for c in _spots(side[0], r, w, h, view):
				var area: Rect2 = c["bubble"].merge(Rect2(c["orb"] - Vector2(ORB_R, ORB_R), Vector2(ORB_R, ORB_R) * 2.0))
				if not screen.encloses(area) or area.intersects(r.grow(2.0)):
					continue
				if rail.size.x > 0.0 and area.intersects(rail):
					continue
				var score: float = float(side[1]) + (widest - w) * 0.6
				for o in others:
					var shared: Rect2 = area.intersection(o)
					if shared.size.x > 0.0 and shared.size.y > 0.0:
						score += 400.0 + shared.get_area()
				if score < best_score:
					best_score = score
					best = c
	if not best.is_empty():
		return best
	# Nowhere beside it: the half of the screen away from it, across the top or the foot.
	var w2 := minf(widest, view.x - rail.size.x - 16.0 - ORB_R * 2.0)
	var h2 := bubble_h(w2, words)
	var left := maxf(rail.end.x, 0.0) + 8.0
	var y := 6.0 if r.get_center().y > view.y * 0.5 else view.y - 6.0 - h2
	var x := clampf(r.get_center().x - w2 * 0.5, left + ORB_R * 2.0 + 4.0, view.x - 6.0 - w2)
	return {"orb": Vector2(x - ORB_R - 4.0, y + ORB_R), "bubble": Rect2(x, y, w2, h2)}


## The places to try on one side of `r`: the sphere next to the button, the
## bubble on from it (lined up a few ways).
func _spots(side: String, r: Rect2, w: float, h: float, view: Vector2) -> Array:
	var out: Array = []
	var cy := clampf(r.get_center().y, ORB_R + 4.0, view.y - ORB_R - 4.0)
	match side:
		"right", "left":
			var ox: float = r.end.x + GAP + ORB_R if side == "right" else r.position.x - GAP - ORB_R
			var bx: float = ox + ORB_R + 4.0 if side == "right" else ox - ORB_R - 4.0 - w
			for by in [cy - h * 0.5, cy - ORB_R, cy + ORB_R - h]:
				var y := clampf(by, 4.0, view.y - 4.0 - h)
				out.append({"orb": Vector2(ox, cy), "bubble": Rect2(bx, y, w, h)})
		"below", "above":
			var oy: float = r.end.y + GAP + ORB_R if side == "below" else r.position.y - GAP - ORB_R
			var by2: float = oy - ORB_R if side == "below" else oy + ORB_R - h
			for ox2 in [r.position.x + ORB_R, r.get_center().x, r.end.x - ORB_R]:
				out.append({"orb": Vector2(ox2, oy), "bubble": Rect2(ox2 + ORB_R + 4.0, by2, w, h)})
				out.append({"orb": Vector2(ox2, oy), "bubble": Rect2(ox2 - ORB_R - 4.0 - w, by2, w, h)})
	return out


## Its corner while idle: a spot clear of every button and word on the
## screen (and the rail), near the top right if it can, else the foot.
func rest_spot() -> Vector2:
	var view := get_viewport_rect().size
	var blocks: Array = []
	var rail := _rail_rect()
	if rail.size.x > 0.0:
		blocks.append(rail)
	for top in _tops():
		for c in top.find_children("*", "Control", true, false):
			if not (c is BaseButton or c is Label or c is RichTextLabel or c is Range or c is LineEdit):
				continue
			if not c.is_visible_in_tree():
				continue
			var cr: Rect2 = c.get_global_rect()
			var sc := Nav.scroll_of(c)
			if sc != null:
				cr = cr.intersection(sc.get_global_rect())
			if cr.size.x > 0.0 and cr.size.y > 0.0:
				blocks.append(cr)
	if menu.page == "train" and menu.train_view != null and menu.train_view.chrome != null:
		for c in menu.train_view.chrome.get_children():
			if c is Control and c.visible:
				blocks.append(c.get_global_rect())  # (the crystals along the bottom)
	var reach := ORB_R + 6.0
	var rows: Array = [reach + 4.0, reach + 22.0, view.y - reach - 4.0, view.y * 0.5]
	for y in rows:
		var x := view.x - reach - 4.0
		while x > maxf(rail.end.x, 0.0) + reach:
			var c := Vector2(x, y)
			if not blocks.any(func(b): return b.grow(reach).has_point(c)):
				return c
			x -= 10.0
	return Vector2(view.x - reach - 4.0, reach + 4.0)


## What's on the screen under it: the page's panel, or on the train the car you're in.
func _tops() -> Array:
	if menu.page == "train" and menu.train_page != null:
		var root = menu.train_page.roots.get(menu.train_car)
		return [root] if root != null and is_instance_valid(root) else []
	return [menu.panel]


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if not active() or target == null or text == "" or appear <= 0.01:
		self_modulate.a = 0.0
		return
	self_modulate.a = appear
	if _style == null:
		_style = UI.entity_bubble()
		_style.inner = Color(UI.PERIWINKLE, 0.18)
	var r := bubble
	r.position.x += (1.0 - appear) * (6.0 if orb_at.x < r.position.x else -6.0)
	draw_style_box(_style, r)
	var fs := _font_size()
	UI.draw_text_lines(self, _font(), Vector2(r.position.x + PAD.x, r.position.y + PAD.y + _font().get_ascent(fs)), text,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - PAD.x * 2.0, fs, -1, Entity.GLOW.lerp(Color.WHITE, 0.62))


func _draw_orb() -> void:
	if not active() or pos.x < 0.0:
		return
	var busy := target != null
	orb.draw_circle(pos, ORB_R * 1.05, Color(0.05, 0.04, 0.09, 0.35))
	Entity.draw_face(orb, pos, ORB_R, t, 1.0 if busy else 0.85)
