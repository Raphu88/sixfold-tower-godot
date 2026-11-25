extends Control
## The Makers' council (climb_shape.gd start_story): the plea after the third
## guardian ("plea") and the final meeting after the sixth ("final"), in the
## style of a Maker's meeting (maker_view.gd): the game pauses, the world goes
## dark, and all three Makers fill the top of the screen, vast and wrong, the
## one speaking brighter. In the final meeting the Entity steps out beside
## the small climber, seen for the first time. Every word is in
## story_scenes.gd TEXT.
##
## Stages: rise (they appear), beat (one speaker's lines; Enter, A, a click or
## a tap goes on, and first shows the rest of a beat still fading in), answer
## (three cards). Skip (the corner button, or Esc) jumps to the cards. The
## cards: left / right (the d-pad or stick) and Enter or A, the number keys,
## a click or a tap. The focused card's help (the Entity's word on it) shows
## over the cards; on a touch screen the first tap on a card shows its help
## and a second chooses it. In the final meeting Ascend and Fight always ask
## for a second press (they can't be taken back).

const UI := preload("res://scripts/ui.gd")
const Makers := preload("res://scripts/makers.gd")
const MakerView := preload("res://scripts/maker_view.gd")
const Controls := preload("res://scripts/controls.gd")
const Story := preload("res://scripts/story_scenes.gd")

## Seconds before each stage can be moved on from (the rise moves on by itself).
const STAGE_MIN := {"rise": 1.2, "beat": 0.35, "answer": 0.45}
## Each line of a beat appears this long after the last.
const LINE_GAP := 0.45

var main
var shape  # climb_shape.gd (it ends the scene)
var kind := "plea"
var stage := "rise"
var t := 0.0  # seconds in this stage (real time: the game is paused)
var clock := 0.0
var beats: Array = []
var beat_i := 0
var then := "answer"  # after the beats: "answer" (the cards) or "finish"
var after := ""  # plain words under the last reply
var options: Array = []
var focus := 0
var armed := -1  # a card pressed once, waiting for the second press
var chosen := ""  # the answer that ended the scene
var entity_k := 0.0  # the Entity revealed (the final meeting), 0..1
var shown_entity := false
var _last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var prof = main.profile
	beats = Story.beats(prof, kind + "_beats")
	options = Story.answers(prof, kind)
	focus = -1 if main.touch_active else 0
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if shape == null or shape.story_view != self:
		return  # (over: freed at the end of this frame)
	queue_redraw()
	if main.menu_open():
		return  # (the menu has the keys; it pauses the game itself)
	if not get_tree().paused:
		get_tree().paused = true
	t += dt
	clock += dt
	if shown_entity:
		entity_k = move_toward(entity_k, 1.0, dt * 1.2)
	if stage == "rise" and t >= float(STAGE_MIN["rise"]):
		_to_beat(0)
		return
	if stage != "answer" and Input.is_action_just_pressed("ui_cancel"):
		skip()
		return
	if stage == "answer":
		var was := focus
		if Input.is_action_just_pressed("ui_left"):
			focus = posmod(maxi(focus, 0) - 1, options.size())
		elif Input.is_action_just_pressed("ui_right"):
			focus = posmod(focus + 1, options.size())
		if focus != was:
			armed = -1
			main.sfx("ui_move")
		for i in mini(options.size(), 6):
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				press(i, false)
				return
		if Input.is_action_just_pressed("ui_accept") and focus >= 0:
			press(focus, false)
		return
	if Input.is_action_just_pressed("ui_accept"):
		advance()


func _input(event: InputEvent) -> void:
	if main == null or main.menu_open() or shape == null or shape.story_view != self:
		return
	if event is InputEventMouseMotion and stage == "answer":
		var over := card_at(event.position)
		if over >= 0 and over != focus:
			focus = over
			armed = -1
		return
	var pos := Vector2.INF
	var touch := false
	if event is InputEventScreenTouch and not event.pressed and event.index == 0:
		pos = event.position
		touch = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	get_viewport().set_input_as_handled()
	if stage != "answer" and skip_rect().has_point(pos):
		skip()
		return
	if stage == "answer":
		var i := card_at(pos)
		if i >= 0:
			press(i, touch)
	else:
		advance()


## Leaving: the game mustn't stay paused (unless a menu is holding it).
func _exit_tree() -> void:
	var m = main
	if m == null or not is_instance_valid(m) or m.menu == null or not is_instance_valid(m.menu) or not m.menu.is_open():
		get_tree().paused = false


func can_advance() -> bool:
	return t >= float(STAGE_MIN.get(stage, 0.5))


## The time a beat's lines take to fade in.
func _beat_time() -> float:
	if beat_i >= beats.size():
		return 0.0
	return float(beats[beat_i]["lines"].size() - 1) * LINE_GAP + 0.35


## Moves the scene on (Enter, A, a click or a tap): the rest of a beat
## still fading in, else the next beat.
func advance() -> void:
	if stage != "beat" or not can_advance():
		return
	if t < _beat_time():
		t = _beat_time()
		return
	_to_beat(beat_i + 1)


## Straight past the words to the cards (or the end, after a reply).
func skip() -> void:
	if stage == "rise" or stage == "beat":
		for i in range(beat_i, beats.size()):
			if String(beats[i]["who"]) == "entity":
				shown_entity = true
		_to_beat(beats.size())


func _to_beat(i: int) -> void:
	beat_i = i
	t = 0.0
	if i >= beats.size():
		if then == "finish":
			finish()
			return
		stage = "answer"
		options = Story.answers(main.profile, kind)
		armed = -1
		if focus >= options.size():
			focus = 0
		main.sfx("ui_move", 0.6, -6.0, 0.0)
		return
	stage = "beat"
	if String(beats[i]["who"]) == "entity" and not shown_entity:
		shown_entity = true
		main.sfx("maker_glimpse", 1.0, 0.0, 0.0)
	main.sfx("ui_move", 0.6, -6.0, 0.0)


## A card pressed: a choice that can't be undone, or a first tap on a touch
## screen, waits for a second press.
func press(i: int, touch: bool) -> void:
	if stage != "answer" or i < 0 or i >= options.size() or not can_advance():
		return
	focus = i
	var weighty: bool = kind == "final" and String(options[i]["id"]) != "not_yet"
	if (weighty or touch) and armed != i:
		armed = i
		main.sfx("ui_move", 0.9, -2.0, 0.0)
		return
	choose(i)


## Takes an answer: story_scenes.gd answer says what happens; its reply plays.
func choose(i: int) -> void:
	if stage != "answer" or i < 0 or i >= options.size():
		return
	var id := String(options[i]["id"])
	var res: Dictionary = Story.answer(main, kind, id)
	if res.get("then", "finish") == "finish":
		chosen = id
	beats = res.get("beats", [])
	then = String(res.get("then", "finish"))
	after = String(res.get("after", ""))
	armed = -1
	main.sfx("maker_grant" if id in ["ascend", "fight"] else "ui_back", 0.8, -2.0, 0.0)
	_to_beat(0)


func finish() -> void:
	if shape != null:
		shape.end_story(kind, chosen)


# --- layout --------------------------------------------------------------------------

func _view() -> Vector2:
	return get_viewport_rect().size


func small(vs := Vector2.ZERO) -> bool:
	if vs == Vector2.ZERO:
		vs = _view()
	return vs.y < 520.0


## Each Maker's place across the top: [centre, radius].
func presence_spot(i: int, vs := Vector2.ZERO) -> Array:
	if vs == Vector2.ZERO:
		vs = _view()
	var r := minf(vs.y * 0.19, vs.x * 0.12)
	var xs := [0.2, 0.5, 0.8]
	return [Vector2(vs.x * float(xs[i]), vs.y * 0.16), r]


## The bottom of the Makers (where the words start).
func presence_bottom(vs := Vector2.ZERO) -> float:
	var s := presence_spot(0, vs)
	return float(s[0].y) + float(s[1])


func card_rect(i: int, vs := Vector2.ZERO) -> Rect2:
	if vs == Vector2.ZERO:
		vs = _view()
	var n := maxi(options.size(), 1)
	var gap := 10.0 if vs.x < 900.0 else 16.0
	var w := minf(230.0, (vs.x - 32.0 - gap * (n - 1)) / n)
	var h := clampf(vs.y * 0.24, 84.0, 140.0)
	var x0 := (vs.x - (w * n + gap * (n - 1))) * 0.5
	var top := vs.y - h - maxf(vs.y * 0.06, 24.0)
	return Rect2(Vector2(x0 + i * (w + gap), top), Vector2(w, h))


func card_at(pos: Vector2) -> int:
	for i in options.size():
		if card_rect(i).has_point(pos):
			return i
	return -1


## The Skip button, top right.
func skip_rect(vs := Vector2.ZERO) -> Rect2:
	if vs == Vector2.ZERO:
		vs = _view()
	var w := 74.0 if not small(vs) else 60.0
	return Rect2(Vector2(vs.x - w - 12.0, 10.0), Vector2(w, 30.0 if not small(vs) else 26.0))


## How far down a beat's words reach (tests: it must fit the screen).
func words_bottom(bt: Dictionary, vs: Vector2) -> float:
	var sm := small(vs)
	var fs := 17.0 if not sm else 14.0
	var tw := minf(vs.x - 60.0, 600.0)
	var y := presence_bottom(vs) + (22.0 if not sm else 18.0) + 10.0
	for l in bt["lines"]:
		y += Makers.redact_height(tw, String(l), fs) + (6.0 if not sm else 3.0)
	return y


## The speaker's colour.
func _color(who: String) -> Color:
	if Makers.MAKERS.has(who):
		return Makers.color(who)
	if who == "entity":
		return load("res://scripts/entity.gd").GLOW
	if who == "all":
		return Color(0.92, 0.88, 0.98)
	return UI.DIM


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
	var a := clampf(clock / 1.0, 0.0, 1.0)
	var sm := small(vs)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.003, 0.012, 0.95 * a))
	_draw_void(vs, a)
	var who := ""
	if stage == "beat" and beat_i < beats.size():
		who = String(beats[beat_i]["who"])
	elif stage == "answer" and not beats.is_empty():
		who = String(beats[-1]["who"])
	# The three Makers, vast, the one speaking brighter.
	for i in Makers.ORDER.size():
		var m: String = Makers.ORDER[i]
		var spot := presence_spot(i, vs)
		var rise := clampf((clock - i * 0.25) / 1.0, 0.0, 1.0)
		var lit := 1.0 if who == m or who == "all" else (0.7 if who == "" else 0.42)
		var r: float = float(spot[1]) * (1.06 if who == m else 1.0)
		MakerView.draw_presence(self, spot[0] - Vector2(0, (1.0 - rise) * r * 0.3), r, clock + i * 2.0, Makers.color(m), Makers.MAKERS[m]["sign"], rise * lit)
	# The climber, small beneath them, and the Entity at their side once seen.
	if stage != "answer":
		var h := 22.0 if not sm else 15.0
		var feet := Vector2(vs.x * 0.5, vs.y - (46.0 if not sm else 34.0))
		var b := UI.Draw.Batch.new()
		b.poly(PackedVector2Array([feet + Vector2(-h * 2.4, 2), feet + Vector2(h * 2.4, 2), feet + Vector2(h * 1.5, h * 0.7), feet + Vector2(0, h * 1.1), feet + Vector2(-h * 1.6, h * 0.6)]), Color(0.13, 0.11, 0.17, a), 1.0)
		b.flush(self)
		Story.climber(self, feet, h, a, Color(0.85, 0.85, 0.95))
		if entity_k > 0.0:
			var Entity = load("res://scripts/entity.gd")
			var ec := feet + Vector2(h * 1.3, -h * 1.3)
			draw_circle(ec, h * (1.6 + 0.6 * entity_k), Color(Entity.GLOW, 0.08 * entity_k))
			Entity.draw_face(self, ec, h * 0.75, clock, entity_k)
	# Who speaks, and what.
	var lines: Array = []
	if stage == "beat" and beat_i < beats.size():
		lines = beats[beat_i]["lines"]
	elif stage == "answer" and not beats.is_empty():
		lines = [beats[-1]["lines"][-1]]
	var scol := _color(who)
	var name := Story.speaker_name(who)
	var ty := presence_bottom(vs) + (22.0 if not sm else 18.0)
	if stage == "answer":
		ty = card_rect(0, vs).position.y - (84.0 if not sm else 70.0)
	var fs := 17.0 if not sm else 14.0
	if name != "":
		UI.draw_label(self, Vector2(0, ty), name, 22 if not sm else 18, Color(scol.lightened(0.25), a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 5, Color(0, 0, 0, 0.8 * a))
	var ly := ty + 10.0
	var tw := minf(vs.x - 60.0, 600.0)
	for i in lines.size():
		var la := clampf((t - i * LINE_GAP) / 0.35, 0.0, 1.0) if stage == "beat" else 1.0
		if la <= 0.0:
			break
		var lc: Color = Color(scol.lightened(0.15), 0.9 * la * a) if who != "" else Color(UI.TEXT, 0.85 * la * a)
		ly += Makers.redact_into(self, Vector2((vs.x - tw) * 0.5, ly), tw, String(lines[i]), lc, fs, true) + (6.0 if not sm else 3.0)
	if stage == "beat" and beat_i == beats.size() - 1 and then == "finish" and after != "" and t > _beat_time():
		UI.draw_text(self, font, Vector2(0, ly + 16.0), after, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14 if not sm else 12, UI.TEXT)
	if stage == "answer":
		_draw_cards(vs, font)
	elif stage == "beat" and can_advance():
		var pulse := 0.5 + 0.5 * sin(clock * 4.0)
		var prompt: String = _say("Press Enter or click", "Press {a}", "Tap") + " " + String(Story.TEXT["go_on"])
		UI.draw_text(self, font, Vector2(0, vs.y - 12.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, Color(UI.DIM, 0.5 + 0.5 * pulse))
	if stage != "answer" and then == "answer":
		var sr := skip_rect(vs)
		draw_style_box(UI.panel(), sr)
		var label: String = String(Story.TEXT["skip"]) + ("" if main.touch_active else (" (Esc)" if not main.pad_active else ""))
		UI.draw_text(self, font, Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 13 if not sm else 12, UI.DIM)


## The void they meet in: far stones drifting, motes of all three colours.
func _draw_void(vs: Vector2, a: float) -> void:
	for i in 24:
		var f := fmod(clock * 0.05 + i * 0.0417, 1.0)
		var p := Vector2(fmod(i * 83.0 + 17.0, vs.x), vs.y * (1.0 - f))
		var col := Makers.color(Makers.ORDER[i % 3])
		draw_circle(p, 1.2, Color(col.lightened(0.4), 0.35 * a * sin(f * PI)))


func _draw_cards(vs: Vector2, font: Font) -> void:
	var panel := UI.panel()
	var sm := small(vs)
	for i in options.size():
		var o: Dictionary = options[i]
		var r := card_rect(i, vs)
		var cc := _card_color(String(o["id"]))
		var appear := clampf((t - i * 0.08) / 0.25, 0.0, 1.0)
		r.position.y += (1.0 - appear) * 16.0
		draw_style_box(panel, r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 4)), Color(cc, 0.8 * appear))
		if i == focus and (not main.touch_active or armed == i):
			draw_rect(r.grow(3.0), Color(UI.GOLD, 0.95), false, 2.0)
		var mid := r.position.y + (24.0 if not sm else 20.0)
		UI.draw_text_lines(self, font, Vector2(r.position.x + 6, mid), String(o["text"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 16 if not sm else 14, 1, cc.lightened(0.35))
		UI.draw_text_lines(self, font, Vector2(r.position.x + 8, mid + (20.0 if not sm else 17.0)), String(o.get("desc", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 12 if not sm else 11, 3, UI.DIM)
		UI.draw_text(self, font, Vector2(r.position.x, r.end.y - 9.0), _hint(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, UI.GOLD)
	# The Entity's word on the focused card (hover, focus or a first tap).
	var Entity = load("res://scripts/entity.gd")
	var help := ""
	if focus >= 0 and focus < options.size() and (not main.touch_active or armed == focus):
		help = String(options[focus].get("help", ""))
	elif main.touch_active:
		help = String(Story.TEXT["help_touch"])
	if help != "":
		var hy := card_rect(0, vs).position.y - (24.0 if not sm else 20.0)
		var hw := minf(vs.x - 80.0, 640.0)
		var hx := (vs.x - hw) * 0.5
		Entity.draw_face(self, Vector2(hx - 4.0, hy - 5.0), 9.0, clock, 0.95)
		UI.draw_text_lines(self, font, Vector2(hx + 12.0, hy), help, HORIZONTAL_ALIGNMENT_LEFT, hw - 12.0, 13 if not sm else 12, 1, Color(Entity.GLOW.lerp(Color.WHITE, 0.55), 0.95))


func _card_color(id: String) -> Color:
	match id:
		"stop", "ascend":
			return Color(0.56, 0.92, 1.0)
		"go", "fight":
			return Color(1.0, 0.5, 0.42)
	return Color(0.82, 0.78, 0.9)


func _hint(i: int) -> String:
	var again := String(Story.TEXT["confirm"])
	if armed == i:
		return ("Tap" if main.touch_active else (Controls.pad_text("Press {a}", main.pad_ps) if main.pad_active else "Press %d or Enter" % (i + 1))) + " " + again
	if main.touch_active:
		return "Tap"
	if main.pad_active:
		return Controls.pad_text("Press {a}", main.pad_ps) if i == focus else ""
	return "Press %d%s" % [i + 1, " or Enter" if i == focus else ""]
