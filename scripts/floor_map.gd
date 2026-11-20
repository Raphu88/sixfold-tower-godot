extends Control
## THE FLOOR MAP (portals.gd opens it): the rooms and corridors you've seen
## on this floor, where you stand, the stair once seen, and the floor's
## portals (asleep, or woken: a woken portal shows even in a room you haven't
## seen, since it can take you there). Pocket dimensions aren't on it: they
## aren't part of the floor.
##
## Opened by stepping onto a woken portal, it's for TRAVEL: choose another
## woken portal (click or tap it; or the arrows or D-pad, then Enter or A, or
## the Travel button) and you step out of it. Opened to look (O, the pause
## menu's Floor map, a phone's Map button), it only shows. Close: Esc, B, O,
## or the Close button. The game waits while it's open.
##
## HELP: hover a marker or a button with the mouse, move onto it with the
## keys or a controller, or hold a finger on it, and the Entity says what it
## is (TEXT's "help_" lines).

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Entity := preload("res://scripts/entity.gd")
const Controls := preload("res://scripts/controls.gd")
const Palette := preload("res://scripts/palette.gd")

static var TEXT := {
	"title": "FLOOR MAP",
	"sub": "%s  ·  floor %d",
	"travel_sub": "Choose a portal to travel to",
	"asleep_sub": "The portals sleep",
	"close": "Close",
	"travel": "Travel",
	"keys_look": "Esc or O to close",
	"keys_travel": "Arrows to choose, Enter to travel, Esc to stay",
	"pad_look": "{b} to close",
	"pad_travel": "D-pad to choose, {a} to travel, {b} to stay",
	"tap_look": "Hold a marker to ask what it is",
	"tap_travel": "Tap a portal to travel. Hold one to ask what it is",
	"help_you": "You are here.",
	"help_you_pocket": "You are in a pocket dimension, outside the floor. Its portal leads back here.",
	"help_here": "The portal you stand on.",
	"help_awake": "A woken portal. Choose it and you step out of it.",
	"help_awake_look": "A woken portal. Stand on any portal on this floor to travel to it.",
	"help_asleep": "A sleeping portal. Complete a challenge on this floor, or slay every creature on it, and every portal wakes.",
	"help_stair": "The stair up.",
	"help_unseen": "A room you haven't seen yet. A woken portal will take you there.",
	"help_close": "Closes the map and goes back to the climb.",
	"help_travel": "Steps through to the portal you chose.",
}
## hold: seconds a finger rests on a marker before the Entity explains it
## instead of choosing it.
static var RULES := {"hold": 0.45, "pick": 26.0}

var main
var portals
var from := -1  # the portal you stand on (-1: only looking)
var focus := -1  # the chosen target (an index into portals.list)
var hover := ""  # what the help is about: "portal:3", "you", "stair", "close", "travel", "unseen:2"
var t := 0.0
var _frame0 := 0
var _last_us := 0
var _press := {}  # a finger down: {pos, t}
var _scale := 1.0
var _origin := Vector2.ZERO  # the map's top left on screen
var _arena := Rect2()
var _tiles: Array = []  # the seen floor tiles to draw (worked out once: nothing moves while it's open)
var _seen_rooms := {}  # room index -> true once any of it has been seen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame0 = Engine.get_process_frames()
	_last_us = Time.get_ticks_usec()
	_learn()
	var ts := targets()
	if from >= 0 and not ts.is_empty():
		focus = ts[0]
		hover = "portal:%d" % focus


func travelling() -> bool:
	return from >= 0 and portals.awake


## The portals you can travel to from here (indices).
func targets() -> Array:
	var out: Array = []
	if not travelling():
		return out
	for i in portals.list.size():
		if i != from:
			out.append(i)
	return out


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	t += dt
	queue_redraw()
	if main == null or portals == null or portals.map != self:
		return
	if main.menu_open():
		return
	if not get_tree().paused:
		get_tree().paused = true  # (closing something over the map mustn't let the game go on)
	if Engine.get_process_frames() <= _frame0:
		return  # (the press that opened it)
	if not _press.is_empty() and t - float(_press["t"]) >= float(RULES["hold"]):
		var what := _at(_press["pos"])
		if what != "":
			hover = what
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("floor_map"):
		close()
		return
	var ts := targets()
	if not ts.is_empty():
		var step := 0
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
			step = -1
		elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
			step = 1
		if step != 0:
			var k := ts.find(focus)
			focus = ts[posmod(k + step, ts.size())]
			hover = "portal:%d" % focus
			main.sfx("ui_move")
	if Input.is_action_just_pressed("ui_accept"):
		if not ts.is_empty() and focus in ts:
			go(focus)
		else:
			close()


func close() -> void:
	portals.close_map()


## Steps through to portal `i`.
func go(i: int) -> void:
	if not i in targets():
		return
	var p = portals
	p.close_map()
	p.travel(i)


func _input(event: InputEvent) -> void:
	if main == null or portals == null or portals.map != self or main.menu_open():
		return
	if event is InputEventMouseMotion:
		var what := _at(event.position)
		if what != hover and what != "":
			hover = what
		return
	if event is InputEventScreenTouch and event.index == 0:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_press = {"pos": event.position, "t": t}
			return
		var held: bool = not _press.is_empty() and t - float(_press["t"]) >= float(RULES["hold"])
		_press = {}
		if not held:
			_tap(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_tap(event.position)


func _tap(pos: Vector2) -> void:
	var what := _at(pos)
	if what == "close":
		close()
	elif what == "travel":
		if focus in targets():
			go(focus)
	elif what.begins_with("portal:"):
		var i := int(what.get_slice(":", 1))
		hover = what
		if i in targets():
			go(i)
	elif what != "":
		hover = what


# --- layout ---------------------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size


func _small() -> bool:
	return _view().y < 520.0


func _header_h() -> float:
	return 46.0 if _small() else 70.0


func _footer_h() -> float:
	return 44.0 if _small() else 58.0


func close_rect() -> Rect2:
	var vs := _view()
	var h := _footer_h() - 12.0
	return Rect2(Vector2(vs.x - 16.0 - 110.0, vs.y - h - 6.0), Vector2(110.0, h))


func travel_rect() -> Rect2:
	var c := close_rect()
	return Rect2(c.position - Vector2(c.size.x + 10.0, 0), c.size)


func _map_area() -> Rect2:
	var vs := _view()
	var top := _header_h()
	return Rect2(Vector2(16, top), Vector2(vs.x - 32.0, vs.y - top - _footer_h() - 4.0))


## Lays the floor out to fit the map area.
func _fit() -> void:
	_arena = main.room
	var area := _map_area()
	_scale = minf(area.size.x / maxf(_arena.size.x, 1.0), area.size.y / maxf(_arena.size.y, 1.0))
	var size := _arena.size * _scale
	_origin = area.position + (area.size - size) * 0.5


func to_map(p: Vector2) -> Vector2:
	return _origin + (p - _arena.position) * _scale


func portal_r() -> float:
	return clampf(22.0 * _scale * 2.2, 8.0, 16.0)


## What's under a point on the screen ("" if nothing): a marker or a button.
func _at(pos: Vector2) -> String:
	_fit()
	if close_rect().has_point(pos):
		return "close"
	if travelling() and travel_rect().has_point(pos):
		return "travel"
	var best := ""
	var best_d := float(RULES["pick"])
	for i in portals.list.size():
		if not _shown(i):
			continue
		var d := pos.distance_to(to_map(portals.list[i]["pos"]))
		if d < best_d:
			best_d = d
			best = "portal:%d" % i
	if best != "":
		return best
	if pos.distance_to(to_map(_you())) < best_d:
		return "you"
	if _stair_seen() and pos.distance_to(to_map(main.stair_pos)) < best_d:
		return "stair"
	for i in portals.list.size():
		var room := int(portals.list[i]["room"])
		if portals.awake and room >= 0 and room < main.room_info.size() and not _room_seen(room):
			var r: Rect2 = main.room_info[room]["rect"]
			if Rect2(to_map(r.position), r.size * _scale).has_point(pos):
				return "unseen:%d" % room
	return ""


# --- what's known -----------------------------------------------------------------------------

## What the climber has seen of the floor (pocket dimensions left out).
func _learn() -> void:
	_tiles.clear()
	_seen_rooms.clear()
	if main == null or main.solid.is_empty():
		return
	var skip := {}
	if main.wings != null:
		for s in main.wings.secrets:
			var r: Rect2i = main.Floors.tile_rect(s["rect"]).grow(1)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					skip[Vector2i(x, y)] = true
	var gs: Vector2i = main.grid_size
	for y in gs.y:
		for x in gs.x:
			var i := y * gs.x + x
			if main.solid[i] == 0 and _seen_tile(i) and not skip.has(Vector2i(x, y)):
				_tiles.append(Vector2i(x, y))
	for ri in main.room_info.size():
		for k in main._tiles_in(main.room_info[ri]["rect"]):
			if _seen_tile(k.y * gs.x + k.x):
				_seen_rooms[ri] = true
				break


func _seen_tile(i: int) -> bool:
	var fog = main.fog
	if fog == null or fog.grid == Vector2i.ZERO or fog.seen.size() <= i:
		return true
	return fog.seen[i] == 1


func _room_seen(room: int) -> bool:
	return _seen_rooms.has(room)


func _stair_seen() -> bool:
	var tl: Vector2i = main._tile_of(main.stair_pos)
	return tl.x >= 0 and tl.y >= 0 and tl.x < main.grid_size.x and tl.y < main.grid_size.y and _seen_tile(tl.y * main.grid_size.x + tl.x)


## A portal shows once seen, or anywhere once woken.
func _shown(i: int) -> bool:
	return portals.awake or bool(portals.list[i]["seen"])


func _you() -> Vector2:
	if portals.in_pocket():
		return portals.pocket["portal_out"]
	return main.player.global_position


func help_text() -> String:
	if hover == "":
		return ""
	if hover == "you":
		return TEXT["help_you_pocket"] if portals.in_pocket() else TEXT["help_you"]
	if hover.begins_with("portal:"):
		var i := int(hover.get_slice(":", 1))
		if i == from:
			return TEXT["help_here"]
		if not portals.awake:
			return TEXT["help_asleep"]
		return TEXT["help_awake"] if travelling() else TEXT["help_awake_look"]
	if hover.begins_with("unseen:"):
		return TEXT["help_unseen"]
	return String(TEXT.get("help_" + hover, ""))


# --- drawing ------------------------------------------------------------------------------------

func _draw() -> void:
	if main == null or portals == null:
		return
	var vs := _view()
	var small := _small()
	_fit()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.016, 0.03, 0.97))
	# The heading.
	var font: Font = UI.font("display")
	var body: Font = UI.font("body")
	UI.draw_title(self, Vector2(0, (26.0 if small else 40.0)), TEXT["title"], 22 if small else 28, UI.GILT_HI, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var sub: String = TEXT["sub"] % [main.tower_data()["name"], main.floor_num]
	if travelling():
		sub = TEXT["travel_sub"]
	elif not portals.awake and not portals.list.is_empty():
		sub += "  ·  " + TEXT["asleep_sub"]
	UI.draw_text(self, body, Vector2(0, (42.0 if small else 60.0)), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13 if small else 14, UI.DIM)
	# The floor: seen tiles, rooms outlined.
	var b := Draw.Batch.new()
	var area := _map_area()
	b.rect(Rect2(_origin, _arena.size * _scale).grow(4.0), Color(0.06, 0.05, 0.08, 0.9))
	var cell: float = main.Floors.CELL * _scale
	var floor_col := Color(0.34, 0.31, 0.4)
	for tl in _tiles:
		b.rect(Rect2(_origin + Vector2(tl) * cell, Vector2(cell + 0.5, cell + 0.5)), floor_col)
	for ri in main.room_info.size():
		var r: Rect2 = main.room_info[ri]["rect"]
		var mr := Rect2(to_map(r.position), r.size * _scale)
		if _room_seen(ri):
			_outline(b, mr, Color(0.6, 0.55, 0.7, 0.8), 1.2)
			if main.room_entered.has(ri):
				b.rect(mr.grow(-1.0), Color(1.0, 0.9, 0.7, 0.04))
		elif portals.awake and portals.list.any(func(pt): return int(pt["room"]) == ri):
			b.rect(mr, Color(0.62, 0.52, 1.0, 0.07))
			_outline(b, mr, Color(0.62, 0.52, 1.0, 0.45), 1.0)
	# The stair.
	if _stair_seen():
		var sp := to_map(main.stair_pos)
		for k in 3:
			b.rect(Rect2(sp + Vector2(-7 + k * 2, -2 + k * 3 - 4), Vector2(14 - k * 4, 3)), UI.GILT if main.stair_open else UI.FAINT)
	b.flush(self)
	# The portals.
	var pr := portal_r()
	var ts := targets()
	for i in portals.list.size():
		if not _shown(i):
			continue
		var c := to_map(portals.list[i]["pos"])
		load("res://scripts/portals.gd").draw_portal(self, c, pr, t, portals.awake)
		if i == from:
			draw_arc(c, pr + 6.0, 0.0, TAU, 28, Color(UI.GILT, 0.8), 2.0, true)
		elif i in ts and (i == focus or hover == "portal:%d" % i):
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			draw_arc(c, pr + 6.0 + pulse * 2.0, 0.0, TAU, 28, Color(UI.GOLD, 0.95), 2.5, true)
	# You.
	var yp := to_map(_you())
	var yk := 0.5 + 0.5 * sin(t * 4.0)
	draw_circle(yp, 9.0 + 3.0 * yk, Color(UI.GILT, 0.18))
	draw_circle(yp, 5.0, Palette.OUTLINE)
	draw_circle(yp, 4.0, UI.GILT_HI)
	# The footer: the hint, Travel and Close.
	var foot_y := vs.y - _footer_h() * 0.5 + 4.0
	var hint := _hint()
	UI.draw_text(self, body, Vector2(16, foot_y), hint, HORIZONTAL_ALIGNMENT_LEFT, travel_rect().position.x - 30.0 if travelling() else close_rect().position.x - 30.0, 12 if small else 13, Color(UI.DIM, 0.85))
	_button(close_rect(), TEXT["close"], hover == "close", font)
	if travelling():
		_button(travel_rect(), TEXT["travel"], hover == "travel" or focus >= 0, font, true)
	# The Entity's help, over the map's corner.
	var line := help_text()
	if line != "":
		_bubble(line, area, body, small)


func _hint() -> String:
	var tr := travelling()
	if main.touch_active:
		return TEXT["tap_travel"] if tr else TEXT["tap_look"]
	if main.pad_active:
		return Controls.pad_text(TEXT["pad_travel"] if tr else TEXT["pad_look"], main.pad_ps)
	return TEXT["keys_travel"] if tr else TEXT["keys_look"]


func _outline(b, r: Rect2, col: Color, w: float) -> void:
	b.line(r.position, Vector2(r.end.x, r.position.y), col, w)
	b.line(Vector2(r.end.x, r.position.y), r.end, col, w)
	b.line(r.end, Vector2(r.position.x, r.end.y), col, w)
	b.line(Vector2(r.position.x, r.end.y), r.position, col, w)


func _button(r: Rect2, label: String, hot: bool, font: Font, primary := false) -> void:
	draw_rect(r, UI.BUTTON_HOVER if hot else UI.BUTTON)
	draw_rect(r, Color(UI.GILT, 0.9 if hot else 0.45), false, 1.5)
	if primary:
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3)), Color(0.62, 0.52, 1.0, 0.9))
	var fs := 15 if r.size.y > 34.0 else 13
	UI.draw_text(self, font, Vector2(r.position.x, r.get_center().y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UI.GILT_HI if hot else UI.TEXT)


## The Entity's bubble: its face and a line, low on the map.
func _bubble(line: String, area: Rect2, font: Font, small: bool) -> void:
	var fs := 13 if small else 14
	var w := minf(area.size.x * 0.6, 420.0)
	var h := UI.text_height(font, line, w - 20.0, fs) + 16.0
	var orb_r := 12.0 if small else 16.0
	var r := Rect2(Vector2(area.position.x + orb_r * 2.0 + 14.0, area.end.y - h - 4.0), Vector2(w, h))
	var style := UI.entity_bubble()
	draw_style_box(style, r)
	UI.draw_text_lines(self, font, Vector2(r.position.x + 12.0, r.position.y + 8.0 + font.get_ascent(fs)), line, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, fs, -1, Entity.GLOW.lerp(Color.WHITE, 0.62))
	Entity.draw_face(self, Vector2(area.position.x + orb_r + 6.0, r.get_center().y), orb_r, t, 1.0)
