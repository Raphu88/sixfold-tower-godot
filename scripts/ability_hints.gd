extends Node2D
## Names in play, so the climber learns what their buttons do (main.gd owns
## one, in the HUD's layer over the touch buttons: `main.hints`):
##   READY LABELS (a computer or a controller): when a mark or technique
##     fills enough to cast, its spell's name fades in under its medallion
##     on the HUD (hud.gd mark_spots), then fades out.
##   FIRST CASTS: the first time a climber casts each spell or technique, a
##     one-line toast names it and says what it does ("Ember Bolt: a bolt
##     thrown where you aim; it burns what it hits"). Once per spell per
##     climber (guide.gd first_cast), and quiet with the Entity's tips off.
##   THE LONG-PRESS CARD (a phone): holding a cast button that opens no ring
##     (a technique, or a mark with one spell) shows a small card with its
##     name, what it does and its numbers, and casts nothing (player.gd).
##   PRACTICE: a line at the top while in the practice room (practice.gd).
## The words are in abilities.gd (and practice.gd).

const Abilities := preload("res://scripts/abilities.gd")
const Practice := preload("res://scripts/practice.gd")
const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")

## Ready labels: fade in, stay, fade out (seconds).
const READY_IN := 0.2
const READY_STAY := 1.6
const READY_OUT := 0.5
## Toasts: how long each shows, and the gap between.
const TOAST_TIME := 3.6
## The long-press card stays this long after the button is let go.
const CARD_AFTER := 2.2

var main
var labels: Array = []  # {part, text, color, t}
var toasts: Array = []  # waiting: {name, does, color}
var toast := {}  # showing: {name, does, color, t}
var card := {}  # {part, lines, color, held, t}
var shown_ready := 0  # (tests)
var shown_toasts := 0  # (tests)
var _ready_was := {}  # part -> [bond, ready]
var _live := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (a ring stops the game's time: the card still shows)
	z_index = 4


func _process(delta: float) -> void:
	if main == null:
		return
	if get_tree().paused:
		if _live:
			_live = false
			queue_redraw()
		return
	var real: float = delta if Engine.time_scale > 0.0 else 1.0 / 60.0
	_watch_ready()
	for l in labels:
		l["t"] += delta
	labels = labels.filter(func(l): return float(l["t"]) < READY_IN + READY_STAY + READY_OUT)
	if not toast.is_empty():
		toast["t"] += delta
		if float(toast["t"]) >= TOAST_TIME:
			toast = {}
	if toast.is_empty() and not toasts.is_empty() and _can_show():
		toast = toasts.pop_front()
		toast["t"] = 0.0
		shown_toasts += 1
	if not card.is_empty() and not bool(card.get("held", false)):
		card["t"] += real
		if float(card["t"]) >= CARD_AFTER:
			card = {}
	var live := not labels.is_empty() or not toast.is_empty() or not card.is_empty() or _practicing()
	if live or _live:
		queue_redraw()
	_live = live


func _can_show() -> bool:
	return main.player != null and not main.menu_open() and not main.title_showing() and not main.choosing_tower and main.fade < 0.05


func _practicing() -> bool:
	return main.practice != null and main.practice.on


# --- ready labels ------------------------------------------------------------------

## A mark or technique that has just filled enough to cast: its name, under
## its medallion (not on a phone, whose buttons carry the names).
func _watch_ready() -> void:
	var p = main.player
	if p == null:
		return
	var seen := {}
	for part in p.bonds:
		var b = p.bonds[part]
		var ready: bool = b.essence >= b.cost() and not (b.has_method("blocked") and b.blocked())
		var was: Array = _ready_was.get(part, [])
		if not was.is_empty() and was[0] == b and not bool(was[1]) and ready and _can_show() and not main.touch_active:
			_add_label(part, b)
		_ready_was[part] = [b, ready]
		seen[part] = true
	for part in _ready_was.keys():
		if not seen.has(part):
			_ready_was.erase(part)


func _add_label(part: String, b) -> void:
	labels = labels.filter(func(l): return l["part"] != part)
	labels.append({"part": part, "text": Abilities.spell_name(b), "color": b.color(), "t": 0.0})
	shown_ready += 1


# --- first casts --------------------------------------------------------------------

## A spell or technique was cast (player.gd): the first time, its toast.
func cast_done(b) -> void:
	if b == null:
		return
	if not main.GuideScript.first_cast(Abilities.cast_key(b)):
		return
	toasts.append({"name": Abilities.spell_name(b), "does": Abilities.short_does(b), "color": b.color()})


# --- the long-press card -----------------------------------------------------------------

## Held a cast button that opens no ring (player.gd, on a phone): its card.
func show_card(part: String) -> void:
	var p = main.player
	if p == null or not p.bonds.has(part):
		return
	var b = p.bonds[part]
	card = {"part": part, "lines": Abilities.card_lines(main, b), "color": b.color(), "held": true, "t": 0.0}
	main.sfx("ui_move", 1.2, -8.0, 0.0)


## The button was let go: the card stays a moment longer.
func release_card() -> void:
	if not card.is_empty():
		card["held"] = false
		card["t"] = 0.0


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if main == null or main.player == null or main.menu_open() or main.title_showing():
		return
	var size := get_viewport_rect().size
	if _practicing() and not main.overlay_showing():
		_draw_practice(size)
	if not main.touch_active and main.hud != null:
		_draw_labels()
	if not toast.is_empty():
		_draw_toast(size)
	if not card.is_empty():
		_draw_card(size)


func _draw_labels() -> void:
	var font := UI.font("display")
	var fs := 15
	var rows: Array = []  # per row: the x spans taken
	for l in labels:
		var at = main.hud.mark_spots.get(l["part"])
		if at == null:
			continue
		var t: float = l["t"]
		var a := clampf(minf(t / READY_IN, (READY_IN + READY_STAY + READY_OUT - t) / READY_OUT), 0.0, 1.0)
		var text := UI.title_case(String(l["text"]))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		var hs: float = main.hud.hud_scale
		var x0: float = maxf(4.0, at.x - w * 0.5)
		var row := 0
		while row < rows.size() and rows[row].any(func(span): return x0 < span[1] + 4.0 and x0 + w > span[0] - 4.0):
			row += 1
		if row >= rows.size():
			rows.append([])
		rows[row].append([x0, x0 + w])
		var y: float = at.y + (main.hud.MARK_R + 13.0) * hs + row * 21.0 + (1.0 - a) * -4.0
		var col: Color = l["color"]
		var r := Rect2(Vector2(x0, y - 9.0), Vector2(w, 19.0))
		var b := Draw.Batch.new()
		UI.cartouche_into(b, r, Color(col, 0.85), a)
		b.flush(self)
		draw_string_outline(font, Vector2(r.position.x, y + 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 3, Color(0, 0, 0, 0.7 * a))
		draw_string(font, Vector2(r.position.x, y + 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(col.lightened(0.35), a))


func _draw_toast(size: Vector2) -> void:
	var t: float = toast["t"]
	var a := clampf(minf(t / 0.25, (TOAST_TIME - t) / 0.5), 0.0, 1.0)
	var title := UI.font("display")
	var body := UI.font("body")
	var name := UI.title_case(String(toast["name"]))
	var does: String = String(toast["does"])
	var ts := 19
	var bs := 15
	var nw := title.get_string_size(name + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	var dw := body.get_string_size(does, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
	var maxw := size.x - 40.0
	if nw + 8.0 + dw > maxw - 30.0:
		dw = maxw - 30.0 - nw - 8.0
	var w := nw + 8.0 + dw + 30.0
	var y := 128.0 if not main.touch_active else 112.0
	var r := Rect2(Vector2((size.x - w) * 0.5, y - 17.0), Vector2(w, 26.0))
	var col: Color = toast["color"]
	var b := Draw.Batch.new()
	UI.band_into(b, r.grow_individual(60.0, 0.0, 60.0, 0.0), a, col, 0.75)
	b.flush(self)
	var x := r.position.x + 15.0
	draw_string_outline(title, Vector2(x, y + 2.0), name + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(title, Vector2(x, y + 2.0), name + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(col.lightened(0.3), a))
	x += nw + 8.0
	draw_string_outline(body, Vector2(x, y + 1.0), does, HORIZONTAL_ALIGNMENT_LEFT, dw, bs, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(body, Vector2(x, y + 1.0), does, HORIZONTAL_ALIGNMENT_LEFT, dw, bs, Color(UI.TEXT, a))


func _draw_card(size: Vector2) -> void:
	var lines: Array = card["lines"]
	var col: Color = card["color"]
	var held: bool = card.get("held", false)
	var a := 1.0 if held else clampf((CARD_AFTER - float(card["t"])) / 0.4, 0.0, 1.0)
	var w := 250.0
	var body := UI.font("body")
	var text_h := body.get_multiline_string_size(String(lines[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 14).y
	var h := 30.0 + text_h + 40.0
	# Beside its button (left of it), kept on screen.
	var c := Vector2(size.x * 0.6, size.y * 0.4)
	var rad := 30.0
	if main.touch != null:
		for bt in main.touch.buttons:
			if bt.get("part", "") == card["part"]:
				c = bt["c"]
				rad = bt["r"]
	var pos := Vector2(c.x - rad - 14.0 - w, c.y - h * 0.5)
	pos.x = clampf(pos.x, 8.0, size.x - w - 8.0)
	pos.y = clampf(pos.y, 60.0, size.y - h - 8.0)
	var r := Rect2(pos, Vector2(w, h))
	var st := UI.card(Color(col, 0.85), true, 10.0)
	st.top = Color(0.13, 0.115, 0.17, 0.97 * a)
	st.bottom = Color(0.07, 0.06, 0.09, 0.97 * a)
	draw_style_box(st, r)
	var x := r.position.x + 15.0
	UI.draw_label(self, Vector2(x, r.position.y + 24.0), String(lines[0]), 20, Color(col.lightened(0.3), a), HORIZONTAL_ALIGNMENT_LEFT, w - 30.0)
	draw_multiline_string(body, Vector2(x, r.position.y + 44.0), String(lines[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 14, -1, Color(UI.TEXT, a))
	var mono := UI.font("mono")
	draw_string(mono, Vector2(x, r.end.y - 22.0), String(lines[2]), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 12, Color(UI.GOLD, a))
	draw_string(body, Vector2(x, r.end.y - 8.0), String(lines[3]), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 12, Color(UI.DIM, a))


func _draw_practice(size: Vector2) -> void:
	var text: String = Abilities.fill(main, Practice.TEXT["hint"])
	var font := UI.font("body")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 30.0
	var y := size.y - 18.0 if not main.touch_active else 62.0
	var x := (size.x - w) * 0.5
	if main.touch_active:
		x = size.x * 0.5 - w * 0.5
	var r := Rect2(Vector2(x, y - 13.0), Vector2(w, 20.0))
	var b := Draw.Batch.new()
	UI.cartouche_into(b, r, Color(UI.GILT, 0.7), 0.9)
	b.flush(self)
	draw_string(font, Vector2(r.position.x, y + 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 14, UI.GOLD)
