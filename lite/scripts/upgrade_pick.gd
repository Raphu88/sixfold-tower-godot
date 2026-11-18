extends Node2D
## A mark gained a star: pick one of two upgrades for its magic (Data
## upgrade_choices). Shown over whatever is on screen (game.gd show_upgrades)
## until every waiting pick is made (save.gd pending_ups). Pictures first: the
## magic's picture with a badge on each card (power, quick, big or special)
## and its words, read aloud.

const Data := preload("res://scripts/data.gd")
const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui.gd")

var game
var t := 0.0
var choices: Array = []
var essence := ""
var cards: Array = []  # [Rect2, id]
var picked_t := -1.0
var picked := ""


func setup(g) -> void:
	game = g


func _ready() -> void:
	z_index = 60
	_next()


## The next waiting pick, or close.
func _next() -> void:
	if game.save.pending_ups.is_empty():
		game.close_upgrades()
		return
	essence = game.save.pending_ups[0]
	# (the star this pick is for: picks come in order, the first at star 2)
	var st := clampi((game.save.marks[essence].get("ups", []) as Array).size() + 2, 2, Data.STAR_MAX)
	choices = Data.upgrade_choices(essence, st)
	picked = ""
	picked_t = -1.0
	game.sfx("maker_grant")
	game.say_list([Data.TEXT["pick_one"], String(Data.UPGRADE_INFO[choices[0]]["word"]), String(Data.UPGRADE_INFO[choices[1]]["word"])])


func _process(delta: float) -> void:
	t += delta
	if picked_t >= 0.0:
		picked_t += delta
		if picked_t > 1.0:
			game.save.take_upgrade(picked)
			game.save.save()
			_next()
	queue_redraw()


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if picked_t >= 0.0:
		return
	var p = null
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
	if p != null:
		for cd in cards:
			if (cd[0] as Rect2).has_point(p):
				_pick(cd[1])
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_LEFT, KEY_A, KEY_1]:
			_pick(choices[0])
		elif event.physical_keycode in [KEY_RIGHT, KEY_D, KEY_2]:
			_pick(choices[1])
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_X]:
			_pick(choices[0])
		elif event.button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B]:
			_pick(choices[1])


func pick(id: String) -> void:  # (for tests)
	_pick(id)


func _pick(id: String) -> void:
	picked = id
	picked_t = 0.0
	game.sfx("ui_confirm")
	game.say(String(Data.UPGRADE_INFO[id]["word"]))


func _draw() -> void:
	cards.clear()
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.06, 0.82))
	if essence == "":
		return
	var col := Data.color(essence)
	# The magic and its words over the cards.
	var top := Vector2(vs.x / 2.0, vs.y * 0.17)
	Art.glow(self, top, 70.0, col, 1.2)
	UI.button(self, top, 40.0, col, false, true)
	Art.magic_icon(self, top, 26.0, essence)
	Art.words(self, top + Vector2(0, 70), Data.TEXT["pick_one"], 44, Color(1.0, 0.95, 0.75))
	var cw := minf(320.0, vs.x * 0.3)
	var ch := minf(320.0, vs.y * 0.5)
	for i in 2:
		var id: String = choices[i]
		var r := Rect2(Vector2(vs.x / 2.0 + (-cw - 30.0 if i == 0 else 30.0), vs.y * 0.38), Vector2(cw, ch))
		var on := picked == id
		if on:
			r = r.grow(10.0 * minf(1.0, picked_t * 4.0))
		elif picked != "":
			continue  # (the one not picked fades away)
		UI.panel(self, r)
		var c := r.get_center() + Vector2(0, -ch * 0.12)
		Art.glow(self, c, 80.0 + 6.0 * sin(t * 3.0 + i), col, 1.0)
		UI.button(self, c, 50.0, col, on, true)
		Art.magic_icon(self, c, 32.0, essence)
		_badge(c + Vector2(42, -40), String(Data.UPGRADE_INFO[id]["badge"]))
		Art.words(self, Vector2(r.get_center().x, r.end.y - 52.0), String(Data.UPGRADE_INFO[id]["word"]), 32, UI.TEXT)
		cards.append([r, id])
		if picked == "" and i == 0:
			Art.finger(self, c + Vector2(30, 34), 40.0, t)


## The little picture for an upgrade's kind: a fist (power), a clock (quick),
## arrows outward (big) or a sparkle (special).
func _badge(at: Vector2, kind: String) -> void:
	draw_circle(at, 22.0, Art.OUT)
	draw_circle(at, 19.0, Color(0.98, 0.88, 0.55))
	match kind:
		"power":
			Art.star(self, at, 13.0, Color(0.95, 0.4, 0.25))
		"quick":
			draw_arc(at, 11.0, 0.0, TAU, 24, Art.OUT, 3.0)
			draw_line(at, at + Vector2(0, -8), Art.OUT, 3.0)
			draw_line(at, at + Vector2(6, 2), Art.OUT, 3.0)
		"big":
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var a: Vector2 = at + d * 4.0
				var b: Vector2 = at + d * 12.0
				draw_line(a, b, Art.OUT, 3.0)
				draw_colored_polygon(PackedVector2Array([b + d * 2.0, b - Vector2(d.x * 6.0, 0), b - Vector2(0, d.y * 6.0)]), Art.OUT)
		_:
			Art.star(self, at, 14.0, Color(0.55, 0.4, 1.0))
			draw_circle(at, 3.0, Color(1, 1, 1))
