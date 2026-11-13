extends Control
## A Maker shows itself (makers.gd start_meeting): the game pauses and this
## plays the scene, over everything but the menu. A presence drawn like the
## Entity, but vast and wrong-scaled, in the Maker's colour, fills the top of
## the screen; a small climber stands below it. Its speech is redacted (the
## story isn't written). Then a choice of answers on cards: left / right (the
## d-pad or stick) and Enter or A, the number keys, a click or a tap.
##
## Stages: rise (it appears), speech, interrupt (the Maker whose core mark you
## carry arrives, if it does), answer (the cards), verdict (its reply and
## what happened, in plain words). Enter, A, a click or a tap goes on.

const UI := preload("res://scripts/ui.gd")
const Makers := preload("res://scripts/makers.gd")
const Controls := preload("res://scripts/controls.gd")

## Seconds before each stage can be moved on from (the rise moves on by itself).
const STAGE_MIN := {"rise": 1.4, "speech": 0.9, "interrupt": 1.0, "answer": 0.45, "verdict": 0.9}
## Each speech line appears this long after the last.
const LINE_GAP := 0.45

var main
var makers
var maker := ""
var interrupter := ""  # the Maker whose core mark you carry, if it interrupts
var way := ""  # how the interruption plays out: cut_short, contradict, listen
var stage := "rise"
var t := 0.0  # seconds in this stage (real time: the game is paused)
var clock := 0.0
var focus := 0
var result := {}
var guest := 0.0  # the interrupter's presence, 0..1
var guest_to := 0.0
var listening := false
var options: Array = []
var _last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	options = makers.answers()
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if makers.view != self:
		return  # (over: freed at the end of this frame)
	queue_redraw()
	if main.menu_open():
		return  # (the menu has the keys; it pauses the game itself)
	if not get_tree().paused:
		get_tree().paused = true  # (closing a menu over the meeting mustn't let the game go on)
	t += dt
	clock += dt
	guest = move_toward(guest, guest_to, dt * 1.4)
	if stage == "rise" and t >= float(STAGE_MIN["rise"]):
		_to("speech")
		return
	if stage == "answer":
		var was := focus
		if Input.is_action_just_pressed("ui_left"):
			focus = posmod(focus - 1, options.size())
		elif Input.is_action_just_pressed("ui_right"):
			focus = posmod(focus + 1, options.size())
		if focus != was:
			main.sfx("ui_move")
		for i in mini(options.size(), 6):
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				choose(i)
				return
		if Input.is_action_just_pressed("ui_accept"):
			choose(focus)
		return
	if Input.is_action_just_pressed("ui_accept"):
		advance()


func _input(event: InputEvent) -> void:
	if main == null or main.menu_open() or makers.view != self:
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and not event.pressed and event.index == 0:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	get_viewport().set_input_as_handled()
	if stage == "answer":
		var i := card_at(pos)
		if i >= 0:
			choose(i)
	else:
		advance()


## Leaving (the meeting over, or the scene reloaded under it): the game
## mustn't stay paused (unless a menu is holding it).
func _exit_tree() -> void:
	var m = main
	if m == null or not is_instance_valid(m) or m.menu == null or not is_instance_valid(m.menu) or not m.menu.is_open():
		get_tree().paused = false


func can_advance() -> bool:
	return t >= float(STAGE_MIN.get(stage, 0.5))


## Moves the scene on (Enter, A, a click or a tap), once it has shown a moment.
func advance() -> void:
	if not can_advance():
		return
	match stage:
		"speech":
			if interrupter != "":
				guest_to = 1.0
				_to("interrupt")
			else:
				_to("answer")
		"interrupt":
			match way:
				"cut_short":
					makers.st()["met"][maker] = int(makers.st()["met"].get(maker, 0)) + 1
					result = {"good": false, "granted": "", "reply": "", "gains": {},
						"lines": [Makers.TEXT["cut_short"] % Makers.MAKERS[interrupter]["Name"]]}
					main.profile.save()
					_to("verdict")
				"listen":
					listening = true
					_to("answer")
				_:
					guest_to = 0.0
					_to("answer")
		"verdict":
			finish()


## Takes an answer card: the Maker weighs it (makers.gd answer).
func choose(i: int) -> void:
	if stage != "answer" or i < 0 or i >= options.size() or not can_advance():
		return
	result = makers.answer(maker, String(options[i]["id"]))
	if way == "contradict" and interrupter != "":
		result["lines"].append(Makers.TEXT["contradict"] % Makers.MAKERS[interrupter]["Name"])
	elif listening:
		result["lines"].append(Makers.TEXT["listen"] % Makers.MAKERS[interrupter]["Name"])
	if result.get("granted", "") != "":
		main.sfx("maker_grant", 1.0, 0.0, 0.0)
	else:
		main.sfx("ui_back", 0.7, -4.0, 0.0)
	_to("verdict")


func finish() -> void:
	makers.end_meeting(result)


func _to(s: String) -> void:
	stage = s
	t = 0.0
	focus = 0
	main.sfx("ui_move", 0.6, -6.0, 0.0)


# --- layout --------------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size


func card_rect(i: int, vs := Vector2.ZERO) -> Rect2:
	if vs == Vector2.ZERO:
		vs = _view()
	var n := maxi(options.size(), 1)
	var gap := 10.0 if vs.x < 900.0 else 16.0
	var w := minf(190.0, (vs.x - 32.0 - gap * (n - 1)) / n)
	var h := clampf(vs.y * 0.27, 84.0, 150.0)
	var x0 := (vs.x - (w * n + gap * (n - 1))) * 0.5
	var top := vs.y - h - maxf(vs.y * 0.08, 30.0)
	return Rect2(Vector2(x0 + i * (w + gap), top), Vector2(w, h))


func card_at(pos: Vector2) -> int:
	for i in options.size():
		if card_rect(i).has_point(pos):
			return i
	return -1


## The words for a prompt on the device in use.
func _say(keys: String, pad: String, tap: String) -> String:
	if main.touch_active:
		return tap
	if main.pad_active:
		return Controls.pad_text(pad, main.pad_ps)
	return keys


# --- drawing -------------------------------------------------------------------------

func _draw() -> void:
	var vs := _view()
	var font := ThemeDB.fallback_font
	var col := Makers.color(maker)
	var a := clampf(clock / 1.2, 0.0, 1.0)
	var small := vs.y < 520.0
	# The world goes dark around it.
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.003, 0.012, 0.93 * a))
	# The presence, vast, too big for the screen; the interrupter beside it.
	var r := vs.y * (0.58 if not small else 0.55)
	var cy := vs.y * 0.15
	var cx := lerpf(vs.x * 0.5, vs.x * 0.34, guest)
	var rise := (1.0 - a) * r * 0.25
	if interrupter != "" and guest > 0.01:
		var gcol := Makers.color(interrupter)
		draw_presence(self, Vector2(lerpf(vs.x * 1.4, vs.x * 0.84, guest), cy + r * 0.12), r * 0.8, clock + 3.0, gcol, Makers.MAKERS[interrupter]["sign"], guest)
	draw_presence(self, Vector2(cx, cy - rise), r, clock, col, Makers.MAKERS[maker]["sign"], a)
	# The climber, small beneath it (for scale).
	var below := cy + r
	if stage != "answer":
		_climber(Vector2(vs.x * 0.5, below + 3.0), 14.0 if small else 20.0, a)
	# Who speaks, and what (redacted until written).
	var speaker := maker
	var lines: Array = []
	match stage:
		"speech", "rise":
			lines = Makers.MAKERS[maker]["speech"]
		"interrupt":
			speaker = interrupter
			lines = Makers.MAKERS[interrupter]["interrupt"]
		"answer":
			lines = [Makers.MAKERS[maker]["speech"][-1]]
		"verdict":
			lines = [result.get("reply", "")] if String(result.get("reply", "")) != "" else []
			if result.get("reply", "") == "" and interrupter != "":
				speaker = interrupter
				lines = [Makers.MAKERS[interrupter]["interrupt"][0]]
	var scol := Makers.color(speaker)
	var name: String = String(Makers.MAKERS[speaker]["Name"])
	var ty := below + (22.0 if not small else 18.0)
	if stage == "answer":
		ty = card_rect(0, vs).position.y - (64.0 if not small else 54.0)
	# Its name in the gothic face; its words in the fine italic (redact_into).
	var fs := 17.0 if not small else 15.0
	UI.draw_label(self, Vector2(0, ty), name, 22 if not small else 19, Color(scol.lightened(0.25), a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 5, Color(0, 0, 0, 0.8 * a))
	var ly := ty + 10.0
	var tw := minf(vs.x - 60.0, 520.0)
	for i in lines.size():
		var la := clampf((t - i * LINE_GAP) / 0.35, 0.0, 1.0) if stage in ["speech", "interrupt"] else 1.0
		if la <= 0.0:
			break
		ly += Makers.redact_into(self, Vector2((vs.x - tw) * 0.5, ly), tw, lines[i], Color(scol.lightened(0.15), 0.85 * la * a), fs, true) + (6.0 if not small else 3.0)
	if stage == "verdict":
		ly += 6.0
		for line in result.get("lines", []):
			draw_string_outline(font, Vector2(0, ly + 14.0), line, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14 if not small else 12, 4, Color(0, 0, 0, 0.8))
			UI.draw_text(self, font, Vector2(0, ly + 14.0), line, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14 if not small else 12, UI.TEXT)
			ly += 20.0 if not small else 17.0
		var gains: Dictionary = result.get("gains", {})
		if not gains.is_empty() and makers.hooks != null and (makers.hooks.has_method("gain_secret") or makers.hooks.has_method("rise_secret")):
			var bits: Array = []
			for k in gains:
				bits.append(Makers.TEXT["secret_gain"] % [int(gains[k]), String(k).capitalize()])
			UI.draw_text(self, font, Vector2(0, ly + 14.0), "   ".join(bits), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, UI.GOLD)
	if stage == "answer":
		_draw_cards(vs, font, col)
	elif can_advance() and stage != "rise":
		var pulse := 0.5 + 0.5 * sin(clock * 4.0)
		var prompt: String = _say("Press Enter or click", "Press {a}", "Tap") + " " + Makers.TEXT["go_on"]
		UI.draw_text(self, font, Vector2(0, vs.y - 16.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, Color(UI.DIM, 0.5 + 0.5 * pulse))


func _draw_cards(vs: Vector2, font: Font, col: Color) -> void:
	var panel := UI.panel()
	for i in options.size():
		var o: Dictionary = options[i]
		var r := card_rect(i, vs)
		var plea: bool = String(o["id"]).begins_with("plea")  # (plea, or plea_vessel: the vessel offered)
		var cc := Color(0.6, 0.9, 0.62) if plea else col
		var appear := clampf((t - i * 0.08) / 0.25, 0.0, 1.0)
		r.position.y += (1.0 - appear) * 16.0
		draw_style_box(panel, r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 4)), Color(cc, 0.8 * appear))
		if not main.touch_active and i == focus:
			draw_rect(r.grow(3.0), Color(UI.GOLD, 0.95), false, 2.0)
		var mid := r.position.y + r.size.y * (0.4 if not plea else 0.3)
		UI.draw_text_lines(self, font, Vector2(r.position.x + 6, mid), o["text"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 15 if r.size.x > 150 else 13, 2, cc.lightened(0.35))
		if plea:
			UI.draw_text_lines(self, font, Vector2(r.position.x + 6, mid + 18.0), String(o.get("desc", Makers.PLEA["desc"])), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 12, 3, UI.DIM)
			if o["id"] == "plea_vessel" and main.player != null:
				var V = load("res://scripts/vessel.gd")
				V.draw_icon(self, Vector2(r.end.x - 15.0, r.position.y + 20.0), 10.0, V.carried(main.player), appear)
		elif o.get("placeholder", false):
			UI.draw_text(self, font, Vector2(r.position.x, mid + 20.0), Makers.TEXT["placeholder"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(UI.FAINT, 0.9))
		UI.draw_text(self, font, Vector2(r.position.x, r.end.y - 10.0), _hint(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, UI.GOLD)


func _hint(i: int) -> String:
	if main.touch_active:
		return "Tap"
	if main.pad_active:
		return Controls.pad_text("Press {a}", main.pad_ps) if i == focus else ""
	return "Press %d%s" % [i + 1, " or Enter" if i == focus else ""]


## The climber, a small hooded figure seen from behind, for scale.
func _climber(feet: Vector2, h: float, a: float) -> void:
	var dark := Color(0.05, 0.04, 0.06, a)
	var rim := Color(Makers.color(maker), 0.5 * a)
	draw_colored_polygon(Makers._oval(feet, Vector2(h * 0.5, h * 0.12), 12), Color(0, 0, 0, 0.5 * a))
	var body := PackedVector2Array([feet + Vector2(-h * 0.28, 0), feet + Vector2(-h * 0.2, -h * 0.62), feet + Vector2(-h * 0.14, -h * 0.78),
		feet + Vector2(0, -h * 1.02), feet + Vector2(h * 0.14, -h * 0.78), feet + Vector2(h * 0.2, -h * 0.62), feet + Vector2(h * 0.28, 0)])
	draw_colored_polygon(body, dark)
	var edge := PackedVector2Array(body)
	draw_polyline(edge, rim, 1.0, true)


## A Maker: drawn like the Entity (an orb with two eyes, rays and sparks) but
## vast and wrong, like an eclipse: a dark body with a burning rim and corona
## where the Entity is a bright orb, two lit slits for eyes, tiny eyes
## crowding its rim, slow rings turning against each other, rays running off
## the screen, motes falling the wrong way (in), its sign faint on its brow.
## `c` and `r` are its centre and radius; `t` the time; `a` fades it.
static func draw_presence(ci: CanvasItem, c: Vector2, r: float, t: float, col: Color, sign: String, a := 1.0) -> void:
	r *= 1.0 + 0.012 * sin(t * 0.9)
	var hot := col.lightened(0.45)
	# Rays, far too long, slowly turning, each breathing in its own time.
	for i in 28:
		var ang := TAU * i / 28.0 + t * 0.02 + 0.07 * sin(i * 3.1)
		var d := Vector2.from_angle(ang)
		var k := 0.5 + 0.5 * sin(t * 0.5 + i * 1.7)
		var long := 1.5 + 0.9 * absf(sin(i * 2.3)) + 0.25 * k
		ci.draw_line(c + d * r * 1.04, c + d * r * long, Color(col, (0.05 + 0.12 * k) * a), maxf(1.0, r * (0.004 + 0.006 * absf(sin(i * 1.3)))), true)
	# The corona: light pressing out from behind its rim.
	for i in 10:
		var f := float(i) / 10.0
		ci.draw_circle(c, r * (1.0 + 0.2 * f * f + 0.02), Color(col, 0.07 * (1.0 - f) * a))
	ci.draw_circle(c, r * 1.012, Color(hot, 0.85 * a))
	# The body: dark, deepening from the rim inward.
	for i in 8:
		var f := float(i) / 8.0
		ci.draw_circle(c, r * (1.0 - 0.018 * i), Color(col.darkened(0.45 + 0.5 * f), a))
	ci.draw_circle(c, r * 0.85, Color(col.darkened(0.93), a))
	ci.draw_circle(c + Vector2(r * 0.06, r * 0.08), r * 0.62, Color(col.darkened(0.96), 0.8 * a))
	# Rings inside it, turning against each other, notched like a dial.
	for ring in 3:
		var rr := r * (0.8 - ring * 0.16)
		var spin := t * (0.05 if ring % 2 == 0 else -0.07) * (1.0 + ring * 0.4)
		ci.draw_arc(c, rr, 0.0, TAU, 128, Color(col, 0.13 * a), 1.0, true)
		var notches := 36 + ring * 12
		for j in notches:
			var nd := Vector2.from_angle(spin + TAU * j / notches)
			var long := 2.2 if j % 6 == 0 else 1.0
			ci.draw_line(c + nd * rr, c + nd * (rr - r * 0.016 * long), Color(col, 0.22 * a), 1.0, true)
		_ring_marks(ci, c, rr - r * 0.045, spin, col, sign, r, a * 0.55)
	# Tiny eyes crowding its rim, of uneven sizes, each blinking in its own time.
	for j in 30:
		var ea := TAU * j / 30.0 + 0.1 - t * 0.01
		var ep := c + Vector2.from_angle(ea) * r * 0.925
		var blink := fmod(t * 0.7 + j * 0.61, 5.0)
		var open := 1.0 if blink > 0.25 else absf(blink - 0.125) / 0.125
		_eye(ci, ep, r * (0.007 + 0.006 * absf(sin(j * 2.7))), open, col, a * 0.85, Vector2.ZERO)
	# Its sign where the Entity has a mouth, faint and huge.
	var b := UI.Draw.Batch.new()
	Makers.draw_sign(b, c + Vector2(0, r * 0.27), r * 0.065, sign, Color(hot, 0.2 * a), maxf(1.5, r * 0.007))
	b.flush(ci)
	# Two great eyes, like the Entity's but lit slits, looking down at you.
	var slow := fmod(t, 7.3)
	var open := 1.0 if slow > 0.3 else absf(slow - 0.15) / 0.15
	open = maxf(open, 0.05)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.22, -r * 0.08)
		for g in 4:
			ci.draw_colored_polygon(_almond(e, r * (0.145 + g * 0.012), r * (0.06 + g * 0.018) * open + 1.0), Color(col, 0.06 * a))
		_eye(ci, e, r * 0.13, open, col, a, Vector2(0, r * 0.012))
	# Motes drifting the wrong way: in toward it.
	for j in 14:
		var ph := fmod(t * 0.1 + j * 0.137, 1.0)
		var p := c + Vector2.from_angle(TAU * j / 14.0 + 0.4 + 0.3 * sin(j)) * r * (1.8 - ph * 0.75)
		var ma := sin(PI * ph) * a
		ci.draw_circle(p, maxf(1.2, r * 0.005), Color(hot, 0.8 * ma))
		ci.draw_circle(p, maxf(3.0, r * 0.016), Color(col, 0.12 * ma))


## One of a Maker's eyes: a lit almond, pointed at both ends, with a dark
## slit, blinking (`open`). `s` is half its width.
static func _eye(ci: CanvasItem, e: Vector2, s: float, open: float, col: Color, a: float, look: Vector2) -> void:
	var h := s * 0.42 * open + 0.3
	ci.draw_colored_polygon(_almond(e, s, h), Color(col.lightened(0.35), 0.95 * a))
	ci.draw_colored_polygon(_almond(e, s * 0.86, h * 0.8), Color(col.lightened(0.85), a))
	if open > 0.35:
		ci.draw_colored_polygon(_almond(e + look, maxf(0.5, s * 0.07), h * 0.85, true), Color(0.02, 0.01, 0.03, a))


## An almond (a vertical one, for a slit, with `upright`).
static func _almond(c: Vector2, w: float, h: float, upright := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var f := float(i) / 16.0
		var x := cos(f * TAU)
		var bulge := pow(1.0 - absf(x), 0.6)
		var pt := Vector2(x * w, sign(sin(f * TAU)) * bulge * h)
		if upright:
			pt = Vector2(sign(sin(f * TAU)) * bulge * w, x * h)
		pts.append(c + pt)
	return pts


## What turns in its rings, by its craft: marks like script (marks), courses
## of stone (towers), claw strokes (creatures).
static func _ring_marks(ci: CanvasItem, c: Vector2, rr: float, spin: float, col: Color, sign: String, r: float, a: float) -> void:
	var n := 16
	for j in n:
		var ang := spin * 1.3 + TAU * j / n
		var d := Vector2.from_angle(ang)
		var tg := d.orthogonal()
		var p := c + d * rr
		var s := r * 0.018
		match sign:
			"trowel":
				ci.draw_rect(Rect2(p - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 1.2)), Color(col, 0.25 * a), false, 1.0)
			"paw":
				for k in 3:
					var o := tg * (k - 1) * s * 0.9
					ci.draw_line(p + o - d * s, p + o + d * s * 0.8 + tg * s * 0.3, Color(col, 0.3 * a), 1.0, true)
			_:
				ci.draw_line(p - tg * s, p + tg * s, Color(col, 0.3 * a), 1.0, true)
				ci.draw_line(p, p - d * s * 1.2, Color(col, 0.3 * a), 1.0, true)
