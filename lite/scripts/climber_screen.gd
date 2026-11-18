extends Node2D
## The climber screen, after the full game's Climber's Book: a page in a
## leather and gilt edge with coloured ribbon tabs. Each tab is a picture
## with a short word (Data.TEXT):
## - Marks: the climber with their marks glowing, and a slot for each of the
##   six body parts: its magic (picture and word), stars and how close the
##   next star is; an empty part waits for a mark.
## - Weapons: the four weapons; tap one to hold it (it's also what the Swap
##   button cycles through in a climb).
## - Look: how the climber looks (look.gd, the full game's options): a big
##   picture of them, and for each choice a row of arrows or colours.
## Opened from the home screen (the You button, or tapping the climber).

const Data := preload("res://scripts/data.gd")
const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui.gd")
const ClimberArt := preload("res://scripts/climber_art.gd")
const Look := preload("res://scripts/look.gd")

const TABS := ["marks", "weapons", "look"]
## Each tab's ribbon colour (the full game's red Marks, green and violet tabs).
const TAB_COLOR := {"marks": Color(0.55, 0.16, 0.16), "weapons": Color(0.22, 0.42, 0.2), "look": Color(0.33, 0.22, 0.48)}

var game
var t := 0.0
var tab := "marks"
var look_group := "face"  # the Look tab's group of choices (look.gd TABS)
## Taps: rectangles and what they do, rebuilt each draw.
var spots: Array = []


func setup(g, start_tab := "marks") -> void:
	game = g
	tab = start_tab


func _ready() -> void:
	game.say(Data.TEXT[tab])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func page() -> Rect2:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 60.0, 1180.0)
	var h := minf(vs.y - 140.0, 560.0)
	return Rect2(Vector2((vs.x - w) / 2.0, 112.0), Vector2(w, h))


func _input(event: InputEvent) -> void:
	var p = null
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
	if p != null:
		for s in spots:
			if (s[0] as Rect2).has_point(p):
				(s[1] as Callable).call()
				get_viewport().set_input_as_handled()
				return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_BACKSPACE:
				_back()
			KEY_Q, KEY_LEFT:
				_tab(TABS[posmod(TABS.find(tab) - 1, TABS.size())])
			KEY_E, KEY_RIGHT, KEY_TAB:
				_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_START:
				_back()
			JOY_BUTTON_LEFT_SHOULDER:
				_tab(TABS[posmod(TABS.find(tab) - 1, TABS.size())])
			JOY_BUTTON_RIGHT_SHOULDER:
				_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])


func _back() -> void:
	game.sfx("ui_close")
	game.go_home()


func _tab(to: String) -> void:
	if to == tab:
		return
	tab = to
	game.sfx("ui_move")
	game.say(Data.TEXT[to])


func _spot(r: Rect2, what: Callable) -> void:
	spots.append([r, what])


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	spots.clear()
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.11, 0.1, 0.17))
	var pg := page()
	# The tabs, above the page.
	var tw := 200.0
	var x0 := pg.get_center().x - tw * 1.5 - 10.0
	for i in TABS.size():
		var id: String = TABS[i]
		var r := Rect2(Vector2(x0 + i * (tw + 10.0), pg.position.y - 74.0), Vector2(tw, 62.0))
		UI.tab(self, r, TAB_COLOR[id], id == tab)
		var lift := -6.0 if id == tab else 0.0
		var ic := Vector2(r.position.x + 34.0, r.get_center().y + lift)
		match id:
			"marks":
				Art.star(self, ic, 18.0, Color(1.0, 0.85, 0.35))
			"weapons":
				Art.weapon_icon(self, ic, 20.0, game.save.weapon)
			"look":
				Art.mirror_icon(self, ic, 22.0)
		Art.words(self, Vector2(r.position.x + 124.0, r.get_center().y + lift), Data.TEXT[id], 26, UI.TEXT)
		_spot(r.grow(4.0), _tab.bind(id))
	UI.panel(self, pg)
	# Back: top left, a house (the home screen).
	var back := Vector2(52, 52)
	UI.button(self, back, 34.0, UI.GILT)
	Art.house(self, back + Vector2(0, -4), 24.0)
	Art.words(self, back + Vector2(0, 48), Data.TEXT["back"], 20, UI.TEXT)
	_spot(Rect2(back - Vector2(44, 44), Vector2(88, 108)), _back)
	match tab:
		"marks":
			_draw_marks(pg)
		"weapons":
			_draw_weapons(pg)
		"look":
			_draw_look(pg)


func _figure(at: Vector2, s: float) -> void:
	var marks := {}
	var stars := {}
	for e in game.save.marks:
		var part: String = game.save.marks[e]["part"]
		marks[part] = Data.color(e)
		stars[part] = game.save.star(e)
	ClimberArt.draw_front(self, at, game.save.app, s, marks, stars, t)


func _draw_marks(pg: Rect2) -> void:
	_figure(Vector2(pg.position.x + pg.size.x * 0.22, pg.end.y - 40.0), pg.size.y / 112.0)
	# A slot for each body part, two columns of three.
	var x0 := pg.position.x + pg.size.x * 0.44
	var cw := (pg.end.x - x0 - 30.0) / 2.0
	var ch := (pg.size.y - 60.0) / 3.0
	for i in Data.PARTS.size():
		var part: String = Data.PARTS[i]
		var r := Rect2(Vector2(x0 + float(i % 2) * cw, pg.position.y + 30.0 + float(i / 2) * ch), Vector2(cw - 16.0, ch - 14.0))
		var e: String = game.save.mark_on(part)
		draw_rect(r, Color(0, 0, 0, 0.25))
		draw_rect(r, Color(UI.GILT, 0.3), false, 1.5)
		var ic := Vector2(r.position.x + 52.0, r.get_center().y)
		Art.words(self, Vector2(r.get_center().x + 30.0, r.position.y + 26.0), Data.PART_WORDS[part], 24, UI.TEXT)
		if e == "":
			draw_arc(ic, 34.0, 0.0, TAU, 40, Color(UI.GILT, 0.35), 2.0)
			Art.words(self, ic, "?", 30, Color(UI.TEXT, 0.4))
			continue
		var col := Data.color(e)
		Art.glow(self, ic, 54.0, col, 0.8 + 0.2 * sin(t * 3.0 + i))
		UI.button(self, ic, 34.0, col, false, true)
		Art.magic_icon(self, ic, 22.0, e)
		var st: int = game.save.star(e)
		var sx := r.get_center().x + 30.0
		Art.words(self, Vector2(sx, r.get_center().y + 4.0), String(Data.MAGIC[e]["word"]), 26, col.lightened(0.4))
		for k in 3:
			Art.star(self, Vector2(sx - 28.0 + 28.0 * k, r.end.y - 30.0), 11.0, Color(1.0, 0.85, 0.3), k < st)
		if st < 3:
			var w := 90.0
			var bar := Rect2(Vector2(sx - w / 2.0, r.end.y - 14.0), Vector2(w, 6.0))
			draw_rect(bar, Color(0, 0, 0, 0.5))
			draw_rect(Rect2(bar.position, Vector2(w * Data.star_progress(float(game.save.marks[e]["grown"])), 6.0)), col)


func _draw_weapons(pg: Rect2) -> void:
	var n := Data.WEAPON_ORDER.size()
	var cw := (pg.size.x - 60.0) / float(n)
	for i in n:
		var id: String = Data.WEAPON_ORDER[i]
		var w: Dictionary = Data.WEAPONS[id]
		var r := Rect2(Vector2(pg.position.x + 30.0 + i * cw + 8.0, pg.position.y + 40.0), Vector2(cw - 16.0, pg.size.y - 80.0))
		var on: bool = id == game.save.weapon
		if on:
			Art.glow(self, r.get_center(), r.size.x * 0.7, UI.GILT, 0.8)
		draw_rect(r, Color(0, 0, 0, 0.3 if not on else 0.15))
		draw_rect(r, Color(UI.GILT_HI, 0.9) if on else Color(UI.GILT, 0.3), false, 3.0 if on else 1.5)
		var ic := Vector2(r.get_center().x, r.position.y + r.size.y * 0.34)
		Art.weapon_icon(self, ic, minf(r.size.x * 0.32, 70.0), id)
		Art.words(self, Vector2(r.get_center().x, r.position.y + r.size.y * 0.62), String(w["word"]), 32, UI.TEXT)
		# How strong (stars) and how quick (lightning) it is: pictures, no numbers.
		var power := clampi(int(w["damage"]) + (1 if float(w["stun"]) > 0.0 else 0), 1, 3)
		var quick := 3 if float(w["cooldown"]) < 0.25 else (2 if float(w["cooldown"]) < 0.5 else 1)
		for k in 3:
			Art.star(self, Vector2(r.get_center().x - 26.0 + 26.0 * k, r.position.y + r.size.y * 0.76), 10.0, Color(1.0, 0.85, 0.3), k < power)
			var bp := Vector2(r.get_center().x - 26.0 + 26.0 * k, r.position.y + r.size.y * 0.88)
			if k < quick:
				Art.magic_icon(self, bp, 11.0, "air")
			else:
				draw_circle(bp, 4.0, Color(1, 1, 1, 0.15))
		_spot(r, _pick_weapon.bind(id))


func _pick_weapon(id: String) -> void:
	if id == game.save.weapon:
		return
	game.save.weapon = id
	game.save.save()
	game.sfx(Data.WEAPONS[id]["equip"])
	game.say(String(Data.WEAPONS[id]["word"]))


func _draw_look(pg: Rect2) -> void:
	_figure(Vector2(pg.position.x + pg.size.x * 0.2, pg.end.y - 40.0), pg.size.y / 112.0)
	var app: Dictionary = Look.normalized(game.save.app)
	var x0 := pg.position.x + pg.size.x * 0.4
	var rw := pg.end.x - x0 - 30.0
	# The groups (Face, Hair, Body, Cloak, More): a colour and a word each.
	var gw := rw / float(Look.TABS.size())
	for i in Look.TABS.size():
		var g: Array = Look.TABS[i]
		var gid: String = g[0]
		var r := Rect2(Vector2(x0 + i * gw + 4.0, pg.position.y + 24.0), Vector2(gw - 8.0, 58.0))
		var on := gid == look_group
		draw_rect(r, Color(0, 0, 0, 0.15 if on else 0.3))
		draw_rect(r, Color(UI.GILT_HI, 0.9) if on else Color(UI.GILT, 0.3), false, 3.0 if on else 1.5)
		var first: String = g[2][0]
		for k in g[2]:
			if Look.has_colors(k):
				first = k
				break
		draw_circle(Vector2(r.position.x + 22.0, r.get_center().y), 13.0, UI.OUTLINE)
		draw_circle(Vector2(r.position.x + 22.0, r.get_center().y), 11.0, Look.swatch(first, String(app.get(first, ""))))
		Art.words(self, Vector2(r.position.x + r.size.x * 0.6, r.get_center().y), String(Data.LOOK_GROUP_WORDS.get(gid, g[1])), 22, UI.TEXT)
		_spot(r, _group.bind(gid))
	# The group's choices: arrows round the current one.
	var keys: Array = []
	for g in Look.TABS:
		if g[0] == look_group:
			keys = g[2]
	var top := pg.position.y + 100.0
	var rh := minf(84.0, (pg.end.y - 24.0 - top) / maxf(1.0, float(keys.size())))
	for i in keys.size():
		var key: String = keys[i]
		var r := Rect2(Vector2(x0, top + i * rh), Vector2(rw, rh - 10.0))
		draw_rect(r, Color(0, 0, 0, 0.2))
		var opts: Array = Look.options(key)
		var cur: String = String(app.get(key, opts[0] if not opts.is_empty() else ""))
		var ah := minf(r.size.y * 0.42, 30.0)
		var la := Vector2(r.position.x + ah + 10.0, r.get_center().y)
		var ra := Vector2(r.end.x - ah - 10.0, r.get_center().y)
		UI.button(self, la, ah, UI.GILT)
		Art.arrow(self, la, ah * 0.8, false)
		UI.button(self, ra, ah, UI.GILT)
		Art.arrow(self, ra, ah * 0.8, true)
		_spot(Rect2(la - Vector2(ah, ah) * 1.3, Vector2(ah, ah) * 2.6), _step_look.bind(key, -1))
		_spot(Rect2(ra - Vector2(ah, ah) * 1.3, Vector2(ah, ah) * 2.6), _step_look.bind(key, 1))
		var sp := Vector2(la.x + ah + 40.0, r.get_center().y)
		draw_circle(sp, ah * 0.75, UI.OUTLINE)
		if Look.is_blank(key, cur):
			draw_circle(sp, ah * 0.65, Color(0.2, 0.18, 0.22))
			draw_line(sp + Vector2(-ah * 0.4, ah * 0.4), sp + Vector2(ah * 0.4, -ah * 0.4), Color(1, 1, 1, 0.5), 3.0)
		else:
			draw_circle(sp, ah * 0.65, Look.swatch(key, cur))
		Art.words(self, Vector2((sp.x + ra.x) / 2.0, r.get_center().y - 6.0), String(Data.LOOK_WORDS.get(key, key)), clampi(int(rh * 0.32), 16, 26), UI.TEXT)
		# Dots: which of the choices this is.
		var dots := mini(opts.size(), 14)
		var at := opts.find(cur)
		var dx := (sp.x + ra.x) / 2.0
		for k in dots:
			draw_circle(Vector2(dx + (float(k) - float(dots - 1) / 2.0) * 9.0, r.end.y - 12.0), 2.5, Color(UI.GILT_HI, 0.9) if k == at else Color(1, 1, 1, 0.2))
	# A die: a whole new look at random.
	var dp := Vector2(pg.position.x + 50.0, pg.position.y + 50.0)
	UI.button(self, dp, 30.0, UI.GILT)
	draw_rect(Rect2(dp - Vector2(13, 13), Vector2(26, 26)), Color(0.95, 0.92, 0.85))
	for d in [Vector2(-6, -6), Vector2(6, 6), Vector2(0, 0), Vector2(6, -6), Vector2(-6, 6)]:
		draw_circle(dp + d, 2.6, UI.OUTLINE)
	_spot(Rect2(dp - Vector2(36, 36), Vector2(72, 72)), _random_look)


func _group(gid: String) -> void:
	if gid != look_group:
		look_group = gid
		game.sfx("ui_move")
		game.say(String(Data.LOOK_GROUP_WORDS.get(gid, gid)))


func _step_look(key: String, by: int) -> void:
	game.save.app = Look.normalized(game.save.app)
	game.save.app[key] = Look.step(game.save.app, key, by)
	game.save.save()
	game.sfx("ui_move")


func _random_look() -> void:
	game.save.app = Look.random({})
	game.save.save()
	game.sfx("ui_confirm")
