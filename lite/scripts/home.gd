extends Node2D
## The home screen: the only "menu". Six towers across the top, each
## showing its beast; tap one to climb it. A crown sits on each tower whose
## beast you've beaten. Below, your climber, big, with every mark glowing on
## its body and a badge beside it for each magic (its picture and stars).
## The guide (the Entity, without words) floats over the tower to try next.
## Keys or a controller: left and right pick a tower, Enter or A climbs it.

const Data := preload("res://scripts/data.gd")
const Art := preload("res://scripts/art.gd")

var game
var t := 0.0
var selected := 0  # the tower picked with keys or a controller
var picked := ""  # a tower tapped: it bounces, then the climb starts
var picked_t := 0.0
var celebrate := ""  # a tower whose beast was just beaten
var confetti: Array = []


func setup(g, celebrate_tower := "") -> void:
	game = g
	celebrate = celebrate_tower


func _ready() -> void:
	game.audio.set_ambience("train")
	selected = maxi(0, Data.ORDER.find(suggested()))
	if celebrate != "":
		selected = maxi(0, Data.ORDER.find(celebrate))
		for k in 80:
			confetti.append({"pos": Vector2(randf_range(0, 1), randf_range(-0.6, 0.0)), "vel": randf_range(0.15, 0.35), "col": Color.from_hsv(randf(), 0.6, 1.0), "spin": randf() * TAU})


## The tower to try next: the first whose beast you haven't beaten.
func suggested() -> String:
	for tw in Data.ORDER:
		if not game.save.beaten.has(tw):
			return tw
	return ""


func card_rect(i: int) -> Rect2:
	var vs := get_viewport_rect().size
	var gap := 14.0
	var w := minf(200.0, (vs.x - 40.0 - gap * 5.0) / 6.0)
	var total := w * 6.0 + gap * 5.0
	var x0 := (vs.x - total) / 2.0
	return Rect2(Vector2(x0 + float(i) * (w + gap), 70), Vector2(w, minf(300.0, vs.y * 0.42)))


func _process(delta: float) -> void:
	t += delta
	if picked != "":
		picked_t += delta
		if picked_t > 0.7:
			game.start_climb(picked)
			return
	for c in confetti:
		c["pos"].y += c["vel"] * delta
		c["spin"] += delta * 5.0
	confetti = confetti.filter(func(c): return c["pos"].y < 1.1)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if picked != "":
		return
	var p = null
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
	if p != null:
		for i in Data.ORDER.size():
			if card_rect(i).grow(6.0).has_point(p):
				_pick(i)
				return
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT, KEY_A:
				step = -1
			KEY_RIGHT, KEY_D:
				step = 1
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_J:
				_pick(selected)
			_:
				if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
					_pick(event.physical_keycode - KEY_1)
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER:
				step = -1
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER:
				step = 1
			JOY_BUTTON_A:
				_pick(selected)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.6:
		if not has_meta("stick_held"):
			step = signi(int(signf(event.axis_value)))
			set_meta("stick_held", true)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		remove_meta("stick_held")
	if step != 0:
		selected = posmod(selected + step, Data.ORDER.size())
		game.sfx("ui_move")


func _pick(i: int) -> void:
	selected = i
	picked = Data.ORDER[i]
	picked_t = 0.0
	game.sfx("ui_confirm")
	game.sfx("roar_" + picked, 1.0, -4.0)


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	var vs := get_viewport_rect().size
	# A night sky over the towers.
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.07, 0.06, 0.12))
	for k in 60:
		var sp := Vector2(fmod(float(k) * 211.7, vs.x), fmod(float(k) * 97.3, vs.y * 0.7))
		draw_circle(sp, 1.5 + float(k % 3) * 0.5, Color(1, 1, 1, 0.25 + 0.25 * sin(t * 1.5 + float(k))))
	draw_rect(Rect2(0, vs.y * 0.62, vs.x, vs.y * 0.38), Color(0.1, 0.09, 0.14))
	var sug := suggested()
	for i in Data.ORDER.size():
		_draw_tower(i, Data.ORDER[i] == sug)
	_draw_climber(vs)
	# The guide floats over the tower to try next (or the one picked with keys).
	var gi := selected
	var gr := card_rect(gi)
	var gp := Vector2(gr.get_center().x, gr.position.y - 26.0) + Vector2(sin(t * 1.6) * 10.0, sin(t * 2.2) * 6.0)
	Art.guide(self, gp, t, 12.0)
	if game.save.beaten.is_empty() and picked == "":
		Art.finger(self, gr.get_center() + Vector2(10, 20), 50.0, t)
	for c in confetti:
		var p := Vector2(c["pos"].x * vs.x, c["pos"].y * vs.y)
		draw_set_transform(p, c["spin"], Vector2.ONE)
		draw_rect(Rect2(-6, -3, 12, 6), c["col"])
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_tower(i: int, suggested_here: bool) -> void:
	var tw: String = Data.ORDER[i]
	var r := card_rect(i)
	var col := Data.tower_color(tw)
	var stone: Color = Data.TOWERS[tw]["floor"]
	var bounce := 0.0
	if picked == tw:
		bounce = -18.0 * absf(sin(picked_t * 12.0)) * (1.0 - picked_t)
	elif i == selected:
		bounce = -4.0 * absf(sin(t * 3.0))
	r.position.y += bounce
	if i == selected or suggested_here:
		Art.glow(self, r.get_center(), r.size.y * 0.7, col, 0.9 + 0.3 * sin(t * 3.0))
	# The tower: a tall stone shape with battlements, windows and a door.
	var body := Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.16), Vector2(r.size.x * 0.76, r.size.y * 0.84))
	draw_rect(body.grow(3.0), Art.OUT)
	draw_rect(body, stone)
	draw_rect(Rect2(body.position, Vector2(body.size.x * 0.25, body.size.y)), stone.lightened(0.1))
	var bw := body.size.x / 5.0
	for k in 3:
		var b := Rect2(body.position + Vector2(bw * 2.0 * float(k), -bw), Vector2(bw, bw))
		draw_rect(b.grow(3.0), Art.OUT)
		draw_rect(b, stone)
	for k in 2:
		var wy := body.position.y + body.size.y * (0.18 + 0.2 * float(k))
		draw_rect(Rect2(Vector2(body.get_center().x - 6, wy), Vector2(12, 18)), Color(1.0, 0.85, 0.5, 0.7 + 0.3 * sin(t * 2.0 + float(i + k))))
	var door := Rect2(Vector2(body.get_center().x - body.size.x * 0.18, body.end.y - body.size.y * 0.2), Vector2(body.size.x * 0.36, body.size.y * 0.2))
	draw_rect(door.grow(3.0), Art.OUT)
	draw_rect(door, Color(0.2, 0.13, 0.08))
	# The beast in a round window over the door.
	var face := Vector2(body.get_center().x, body.position.y + body.size.y * 0.62)
	var fr := body.size.x * 0.4
	draw_circle(face, fr + 4.0, Art.OUT)
	draw_circle(face, fr, col.darkened(0.55))
	Art.beast_badge(self, face + Vector2(0, fr * 0.45), tw, t + float(i), fr / 95.0)
	# Beaten: a crown on top, and the magic it gave.
	if game.save.beaten.has(tw):
		Art.crown(self, Vector2(r.get_center().x, r.position.y - 2.0 + 3.0 * sin(t * 2.0 + float(i))), 22.0)
	var e: String = Data.TOWERS[tw]["essence"]
	var mp := Vector2(r.get_center().x, r.end.y + 34.0)
	if game.save.marks.has(e):
		draw_circle(mp, 26.0, col.darkened(0.2))
		Art.magic_icon(self, mp, 17.0, e)
	else:
		draw_circle(mp, 22.0, Color(col, 0.25))
		draw_arc(mp, 22.0, 0.0, TAU, 32, Color(col, 0.6), 3.0)


func _draw_climber(vs: Vector2) -> void:
	var s := clampf(vs.y / 720.0 * 3.4, 2.4, 4.2)
	var center := Vector2(vs.x / 2.0, vs.y - 24.0)
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	Art.climber(self, center, s, false, marks, stars, t)
	# A badge beside the climber for each mark: its magic and stars.
	var k := 0
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		var spot: Vector2 = center + Art.PART_SPOT[part] * s
		var left := k % 2 == 0
		var bp := Vector2(vs.x / 2.0 + (-1.0 if left else 1.0) * (130.0 + 120.0 * float(k / 2)), center.y - 150.0 + 70.0 * float(k / 2))
		var col := Data.color(e)
		draw_line(spot, bp, Color(col, 0.5), 3.0)
		draw_circle(bp, 34.0, Art.OUT)
		draw_circle(bp, 31.0, col.darkened(0.25))
		Art.magic_icon(self, bp, 20.0, e)
		var st: int = game.save.star(e)
		for n in 3:
			Art.star(self, bp + Vector2(-22 + 22 * n, 46), 9.0, Color(1.0, 0.85, 0.3), n < st)
		# How close the next star is: a little bar under the stars.
		if st < 3:
			var w := 60.0
			var pr := Data.star_progress(float(game.save.marks[e]["grown"]))
			draw_rect(Rect2(bp + Vector2(-w / 2.0, 60), Vector2(w, 6)), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(bp + Vector2(-w / 2.0, 60), Vector2(w * pr, 6)), col)
		k += 1
