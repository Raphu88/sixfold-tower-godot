extends Control
## The station drawn behind its page (menu.gd shows it while the station's
## page is open, station_page.gd): a covered platform at dusk, the six
## towers on the horizon with a window lit in each one's essence, iron
## columns holding up a canopy with a scalloped valance, lamps glowing under
## it, the station's sign, and on the walls either side something of the
## stop you're at (the gym's rings and weights, the arena's banners, the
## challenges' red pennants, the renown board's pinned notices, the shrine's
## candles). Everything is drawn in code.
##
## The small pieces the page is built from live here too: StopIcon (each
## stop's icon, also on the rail: rail.gd car_icon asks icon()), Tile (a
## drill, bout, challenge, title or boon: its icon, name, a line, a medal or
## pips, a lock), RenownBar (renown, rank and how far to the next) and
## StationCard (a station's plaque on the engine's board).

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")

var inset := 0.0  # the rail down the left
var stop := "gym"
var lamp := Art.LAMP
var title := ""  # the station's name, on its sign


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_inset(x: float) -> void:
	inset = x
	offset_left = x
	queue_redraw()


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 6 == 0:
		queue_redraw()  # (the lamps and candles flicker)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var t := Time.get_ticks_msec() * 0.001
	var b := UI.Draw.Batch.new()
	var horizon := h * 0.6
	# The sky, from night to the glow on the horizon, and a few stars.
	Art.vgrad(b, Rect2(0, 0, w, horizon * 0.5), Art.SKY[0], Art.SKY[1])
	Art.vgrad(b, Rect2(0, horizon * 0.5, w, horizon * 0.35), Art.SKY[1], Art.SKY[2])
	Art.vgrad(b, Rect2(0, horizon * 0.85, w, horizon * 0.15 + 1.0), Art.SKY[2], Art.SKY[3])
	for i in 40:
		var sp := Vector2(Art.rnd(i * 3 + 1) * w, Art.rnd(i * 7 + 2) * horizon * 0.7)
		b.rect(Rect2(sp, Vector2(1.5, 1.5)), Color(Art.STAR, 0.25 + 0.4 * Art.rnd(i)))
	# The six towers far off, each with a lit window in its essence's colour.
	var n := Towers.ORDER.size()
	for i in n:
		var id: String = Towers.ORDER[i]
		var x := w * (0.1 + 0.8 * (i + 0.5) / n) + (Art.rnd(i + 11) - 0.5) * 30.0
		var th := h * (0.16 + 0.1 * Art.rnd(i + 5))
		var tw := 18.0 + 10.0 * Art.rnd(i + 9)
		var base := horizon + 2.0
		b.polygon(PackedVector2Array([Vector2(x - tw * 0.6, base), Vector2(x - tw * 0.42, base - th), Vector2(x - tw * 0.6, base - th - 6.0),
			Vector2(x, base - th - 22.0), Vector2(x + tw * 0.6, base - th - 6.0), Vector2(x + tw * 0.42, base - th), Vector2(x + tw * 0.6, base)]), Art.FAR)
		var wc: Color = Essence.color(String(Towers.TOWERS[id].get("essence", "air")))
		Art.light(b, Vector2(x, base - th * 0.7), Vector2(12, 12), Color(wc, 0.35))
		b.rect(Rect2(x - 2.0, base - th * 0.7 - 3.0, 4.0, 6.0), wc.lightened(0.3))
	# The far hills, and the land.
	var hills := PackedVector2Array([Vector2(0, h)])
	for i in 13:
		hills.append(Vector2(w * i / 12.0, horizon - 8.0 - 14.0 * Art.rnd(i + 40)))
	hills.append(Vector2(w, h))
	b.polygon(hills, Art.NEAR)
	# The platform: boards under the canopy, a painted edge.
	var deck := h * 0.84
	Art.vgrad(b, Rect2(0, deck, w, h - deck), Art.OAK.darkened(0.45), Art.WALNUT.darkened(0.55))
	for i in int(w / 46.0) + 1:
		b.rect(Rect2(i * 46.0, deck, 1.0, h - deck), Color(0, 0, 0, 0.35))
	b.rect(Rect2(0, deck, w, 3.0), Color(0.86, 0.72, 0.3, 0.8))
	b.rect(Rect2(0, deck + 3.0, w, 2.0), Color(0, 0, 0, 0.45))
	# The back wall under the canopy: dark boards, lit by the lamps.
	var wall_top := h * 0.14
	Art.vgrad(b, Rect2(0, wall_top, w, h * 0.22), Color(0.12, 0.08, 0.06, 0.95), Color(0.12, 0.08, 0.06, 0.0))
	# The canopy: a roof band, its scalloped valance, iron columns.
	var roof := h * 0.1
	Art.vgrad(b, Rect2(0, 0, w, roof), Color(0.16, 0.12, 0.13), Color(0.24, 0.18, 0.17))
	b.rect(Rect2(0, roof - 3.0, w, 3.0), Color(Art.GILT, 0.55))
	var sc := 26.0
	for i in int(w / sc) + 1:
		var x0 := i * sc
		b.polygon(PackedVector2Array([Vector2(x0, roof), Vector2(x0 + sc, roof), Vector2(x0 + sc * 0.5, roof + 12.0)]), Color(0.3, 0.22, 0.2))
		b.circle(Vector2(x0 + sc * 0.5, roof + 9.0), 2.0, Color(Art.GILT, 0.45), 8)
	var gap := 220.0
	var cols := int(w / gap) + 1
	for i in cols:
		var x := 40.0 + i * gap
		b.rect(Rect2(x - 5.0, roof, 10.0, deck - roof), Art.OUTLINE)
		b.rect(Rect2(x - 3.5, roof, 7.0, deck - roof), Color(0.16, 0.2, 0.2))
		b.rect(Rect2(x - 2.0, roof, 1.5, deck - roof), Color(1, 1, 1, 0.08))
		# A bracket where it meets the canopy, and its foot.
		b.polygon(PackedVector2Array([Vector2(x - 26, roof), Vector2(x + 26, roof), Vector2(x + 4, roof + 22), Vector2(x - 4, roof + 22)]), Color(0.16, 0.2, 0.2))
		b.rect(Rect2(x - 9.0, deck - 8.0, 18.0, 8.0), Art.OUTLINE)
		# A lamp hanging between columns.
		if i < cols - 1:
			var lx := x + gap * 0.5
			var flick := 0.9 + 0.1 * sin(t * 7.0 + i * 1.7)
			b.line(Vector2(lx, roof), Vector2(lx, roof + 34.0), Art.OUTLINE, 2.0)
			Art.light(b, Vector2(lx, roof + 44.0), Vector2(150, 120), Color(lamp, 0.16 * flick))
			b.polygon(PackedVector2Array([Vector2(lx - 7, roof + 34), Vector2(lx + 7, roof + 34), Vector2(lx + 5, roof + 50), Vector2(lx - 5, roof + 50)]), Art.OUTLINE)
			b.rect(Rect2(lx - 4.0, roof + 37.0, 8.0, 11.0), lamp.lightened(0.2))
	# What the stop has on its walls, either side of the page.
	_dress(b, w, h, roof, deck, t)
	b.flush(self)
	# The station's sign, hanging from the canopy.
	if title != "":
		var font := UI.font("display")
		var fs := 22 if h < 500.0 else 26
		var tw2 := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
		var sr := Rect2((w - tw2) * 0.5, roof + 4.0, tw2, fs + 12.0)
		var sb := UI.Draw.Batch.new()
		sb.line(Vector2(sr.position.x + 16, roof), Vector2(sr.position.x + 16, sr.position.y), Art.OUTLINE, 2.0)
		sb.line(Vector2(sr.end.x - 16, roof), Vector2(sr.end.x - 16, sr.position.y), Art.OUTLINE, 2.0)
		sb.rect(sr.grow(2.0), Art.OUTLINE)
		sb.rect(sr.grow(1.0), Art.GILT.darkened(0.2))
		Art.vgrad(sb, sr.grow(-1.0), Color(0.1, 0.16, 0.15), Color(0.06, 0.1, 0.1))
		sb.flush(self)
		UI.draw_text(self, font, Vector2(sr.position.x, sr.end.y - 9.0), title, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs, Art.GILT_HI)


## The stop's things on the walls at both edges (the page covers the middle).
func _dress(b, w: float, h: float, roof: float, deck: float, t: float) -> void:
	var spots := [Vector2(70.0, h * 0.42), Vector2(w - 70.0, h * 0.42)]
	for k in spots.size():
		var c: Vector2 = spots[k]
		match stop:
			"gym":  # training rings on ropes, a rack of weights
				for dx in [-16.0, 16.0]:
					b.line(Vector2(c.x + dx, roof + 12.0), Vector2(c.x + dx, c.y - 20.0), Color(0.55, 0.42, 0.26), 2.0)
					b.arc(Vector2(c.x + dx, c.y - 12.0), 9.0, 0.0, TAU, 16, Art.GILT.darkened(0.2), 3.0)
				b.rect(Rect2(c.x - 34, deck - 46, 68, 6), Art.WALNUT)
				for i in 3:
					var wx := c.x - 24.0 + i * 24.0
					b.rect(Rect2(wx - 9, deck - 40, 18, 4), Art.IRON.lightened(0.25))
					b.circle(Vector2(wx - 9, deck - 38), 6.0, Art.IRON.lightened(0.1), 12)
					b.circle(Vector2(wx + 9, deck - 38), 6.0, Art.IRON.lightened(0.1), 12)
			"arena":  # long banners with crossed swords
				var bn := Rect2(c.x - 26, roof + 16.0, 52, h * 0.42)
				b.polygon(PackedVector2Array([bn.position, Vector2(bn.end.x, bn.position.y), bn.end, Vector2(bn.get_center().x, bn.end.y - 18.0), Vector2(bn.position.x, bn.end.y)]), Color(0.42, 0.1, 0.12))
				b.rect(Rect2(bn.position.x - 4, bn.position.y - 3, bn.size.x + 8, 5), Art.GILT.darkened(0.15))
				var sx := bn.get_center()
				b.line(sx + Vector2(-14, -14), sx + Vector2(14, 14), Art.GILT_HI, 3.0)
				b.line(sx + Vector2(14, -14), sx + Vector2(-14, 14), Art.GILT_HI, 3.0)
			"challenges":  # red pennants on a line
				var y0 := roof + 26.0
				b.line(Vector2(c.x - 50, y0), Vector2(c.x + 50, y0 + 6.0), Art.OUTLINE, 1.5)
				for i in 5:
					var px := c.x - 44.0 + i * 22.0
					var py := y0 + i * 1.2
					var sway := sin(t * 2.0 + i) * 2.0
					b.polygon(PackedVector2Array([Vector2(px, py), Vector2(px + 16, py), Vector2(px + 8 + sway, py + 22)]), Color(0.75, 0.16, 0.14) if i % 2 == 0 else Color(0.86, 0.66, 0.24))
			"board":  # a notice board with pinned papers
				var nb := Rect2(c.x - 46, c.y - 60, 92, 110)
				b.rect(nb.grow(3.0), Art.OUTLINE)
				b.rect(nb.grow(2.0), Art.WALNUT)
				b.rect(nb, Color(0.42, 0.3, 0.2))
				for i in 5:
					var pr := Rect2(nb.position + Vector2(8 + (i % 2) * 42, 8 + (i / 2) * 34), Vector2(32, 28))
					b.rect(pr, Color(0.86, 0.8, 0.66).darkened(0.1 * (i % 3)))
					b.circle(pr.position + Vector2(16, 3), 2.2, Color(0.75, 0.2, 0.18), 8)
					for ln in 3:
						b.rect(Rect2(pr.position + Vector2(4, 9 + ln * 6), Vector2(24 - ln * 4, 1.2)), Color(0.2, 0.15, 0.1, 0.7))
			"shrine":  # candles on a ledge, flickering
				b.rect(Rect2(c.x - 40, deck - 30, 80, 6), Color(0.5, 0.46, 0.44))
				for i in 4:
					var cx := c.x - 27.0 + i * 18.0
					var chh := 16.0 + 6.0 * Art.rnd(i + k * 5)
					b.rect(Rect2(cx - 3, deck - 30 - chh, 6, chh), Color(0.92, 0.86, 0.72))
					var fl := 0.85 + 0.15 * sin(t * 9.0 + i * 2.1)
					Art.light(b, Vector2(cx, deck - 36 - chh), Vector2(30, 30), Color(1.0, 0.7, 0.35, 0.28 * fl))
					b.polygon(PackedVector2Array([Vector2(cx - 2.5, deck - 31 - chh), Vector2(cx + 2.5, deck - 31 - chh), Vector2(cx, deck - 40 - chh - 2.0 * fl)]), Color(1.0, 0.75, 0.3))


# --- icons ---------------------------------------------------------------------------

## Each stop's icon (and the station's, a medal's), on a 20 x 20 grid around
## `c`; false for an id it doesn't draw.
static func icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, w := 1.6) -> bool:
	var u := s / 10.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"gym":  # a dumbbell
			ci.draw_line(P.call(-6, 0), P.call(6, 0), col, w, true)
			for sx in [-1.0, 1.0]:
				ci.draw_rect(Rect2(P.call(6.0 * sx - (2.5 if sx > 0 else 0.0), -5), Vector2(2.5, 10) * u), col, false, w)
				ci.draw_rect(Rect2(P.call(9.0 * sx - (1.5 if sx > 0 else 0.0), -3), Vector2(1.5, 6) * u), col)
		"arena":  # crossed swords
			ci.draw_line(P.call(-8, -8), P.call(7, 7), col, w, true)
			ci.draw_line(P.call(8, -8), P.call(-7, 7), col, w, true)
			ci.draw_line(P.call(3, 7), P.call(7, 3), col, w, true)
			ci.draw_line(P.call(-3, 7), P.call(-7, 3), col, w, true)
		"challenges":  # a pennant on a pole
			ci.draw_line(P.call(-6, -9), P.call(-6, 9), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-6, -9), P.call(8, -5), P.call(-6, -1)]), Color(col, 0.55))
			ci.draw_polyline(PackedVector2Array([P.call(-6, -9), P.call(8, -5), P.call(-6, -1)]), col, w, true)
		"board":  # a notice board with a pinned paper
			ci.draw_rect(Rect2(P.call(-9, -7), Vector2(18, 13) * u), col, false, w)
			ci.draw_rect(Rect2(P.call(-5, -4), Vector2(7, 7) * u), Color(col, 0.55))
			ci.draw_line(P.call(-6, 6), P.call(-7, 10), col, w, true)
			ci.draw_line(P.call(6, 6), P.call(7, 10), col, w, true)
		"shrine":  # a candle and its flame
			ci.draw_rect(Rect2(P.call(-3, -2), Vector2(6, 10) * u), col, false, w)
			ci.draw_line(P.call(-7, 8), P.call(7, 8), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-2, -4), P.call(2, -4), P.call(0, -10)]), col)
		"clock":  # a platform clock on its post
			ci.draw_arc(P.call(0, -3), 6.0 * u, 0, TAU, 18, col, w, true)
			ci.draw_line(P.call(0, -3), P.call(0, -6.5), col, w, true)
			ci.draw_line(P.call(0, -3), P.call(2.5, -3), col, w, true)
			ci.draw_line(P.call(0, 3), P.call(0, 9), col, w, true)
			ci.draw_line(P.call(-4, 9), P.call(4, 9), col, w, true)
		"title":  # a laurel wreath: two curved stems with leaves, open at the top
			var lc: Vector2 = P.call(0, 1)
			for sx in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for i in 9:
					var a: float = PI * 0.5 + sx * (0.25 + i * 0.13) * PI
					pts.append(lc + Vector2(cos(a), sin(a)) * 7.5 * u)
				ci.draw_polyline(pts, col, w, true)
				for i in range(1, 9, 2):
					var a: float = PI * 0.5 + sx * (0.25 + i * 0.13) * PI
					var at: Vector2 = lc + Vector2(cos(a), sin(a)) * 7.5 * u
					var out: Vector2 = Vector2(cos(a), sin(a)) * 2.6 * u + Vector2(-sin(a), cos(a)) * sx * -2.0 * u
					ci.draw_colored_polygon(PackedVector2Array([at, at + out + out.orthogonal() * 0.35, at + out * 1.6, at + out - out.orthogonal() * 0.35]), col)
			ci.draw_line(P.call(-2, 9), P.call(2, 9), col, w, true)
		"boon":  # a sun-burst
			ci.draw_arc(c, 3.5 * u, 0, TAU, 14, col, w, true)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * 5.5 * u, c + Vector2.from_angle(a) * 8.5 * u, col, w, true)
		_:
			return false
	return true


## A medal: a ribbon and a disc (`m` 1 bronze, 2 silver, 3 gold; 0 an empty ring).
static func medal_into(ci: CanvasItem, c: Vector2, r: float, m: int, col: Color) -> void:
	if m <= 0:
		ci.draw_arc(c, r, 0, TAU, 18, Color(UI.FAINT, 0.8), 1.2, true)
		return
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 1.9), c + Vector2(-r * 0.1, -r * 1.9), c + Vector2(r * 0.25, -r * 0.6), c + Vector2(-r * 0.35, -r * 0.6)]), Color(0.45, 0.14, 0.16))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, -r * 1.9), c + Vector2(r * 0.7, -r * 1.9), c + Vector2(r * 0.35, -r * 0.6), c + Vector2(-r * 0.25, -r * 0.6)]), Color(0.2, 0.25, 0.45))
	ci.draw_circle(c, r + 1.2, UI.OUTLINE)
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.45, col.lightened(0.35))
	ci.draw_arc(c, r * 0.68, 0, TAU, 16, col.darkened(0.3), 1.0, true)


## A stop's icon by itself (a heading's).
class StopIcon extends Control:
	var id := ""
	var tint := Color(1, 1, 1)

	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.42
		load("res://scripts/station_view.gd").icon(self, id, size * 0.5, s, tint, 1.8)


## A drill, a bout, a challenge, a title or a boon: a button with its icon,
## name and a line, and on the right a medal, pips (levels or wins) or a lock.
class Tile extends Button:
	const UI := preload("res://scripts/ui.gd")
	var head := ""
	var line := ""
	var icon_id := ""
	var tint := Color(0.86, 0.64, 0.3)
	var medal := -1  # -1 none shown; 0 to 3
	var pips := 0
	var pips_of := 0
	var locked := false
	var chosen := false
	var lit := false  # (a won challenge, a worn title)
	var touch := false  # (a phone: no focus ring)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		restyle()

	func restyle() -> void:
		for state in ["normal", "hover", "pressed"]:
			var bg := Color(0.13, 0.085, 0.05, 0.92) if state == "normal" else Color(0.19, 0.125, 0.07, 0.95)
			if chosen:
				bg = Color(0.27, 0.19, 0.08, 0.96) if state == "normal" else Color(0.32, 0.23, 0.1, 0.97)
			var st := UI.box(bg, Color(UI.GOLD, 0.95) if chosen else Color(UI.TRAIN_BRASS, 0.45 if state == "normal" else 0.85), 6, 2 if chosen else 1)
			add_theme_stylebox_override(state, st)
		queue_redraw()

	func _draw() -> void:
		var small := size.y < 50.0
		var a := 0.55 if locked else 1.0
		var ic := Vector2(20.0 if small else 24.0, size.y * 0.5)
		if not load("res://scripts/station_view.gd").icon(self, icon_id, ic, 7.0 if small else 8.5, Color(tint, a), 1.6):
			UI.draw_icon(self, icon_id, ic, 7.0 if small else 8.5, Color(tint, a), 1.6)
		var x := ic.x + (16.0 if small else 20.0)
		var right := 12.0
		if medal >= 0 or locked:
			right = 34.0
		elif pips_of > 0:
			right = 10.0 + pips_of * 13.0
		var w := size.x - x - right
		var hc: Color = UI.GILT_HI if chosen or lit else UI.TEXT
		UI.draw_label(self, Vector2(x, size.y * 0.5 - (1.0 if line != "" else -6.0)), head, 15 if small else 17, Color(hc, a), HORIZONTAL_ALIGNMENT_LEFT, w)
		if line != "":
			UI.draw_text(self, UI.font("body"), Vector2(x, size.y * 0.5 + 14.0), line, HORIZONTAL_ALIGNMENT_LEFT, w, 12 if small else 13, Color(UI.DIM, 0.9 * a))
		if locked:
			UI.draw_lock(self, Vector2(size.x - 18.0, size.y * 0.5), 10.0, Color(UI.DIM, 0.9))
		elif medal >= 0:
			var Stations = load("res://scripts/stations.gd")
			load("res://scripts/station_view.gd").medal_into(self, Vector2(size.x - 18.0, size.y * 0.5 + 4.0), 7.0, medal, Stations.medal_color(medal))
		elif pips_of > 0:
			for i in pips_of:
				var pc := Vector2(size.x - 6.0 - (pips_of - i) * 13.0 + 5.0, size.y * 0.5)
				if i < pips:
					draw_circle(pc, 4.0, UI.GILT)
				else:
					draw_arc(pc, 4.0, 0, TAU, 12, Color(UI.FAINT, 0.9), 1.2, true)
		if has_focus() and not touch:
			var loop := UI.rounded(Rect2(Vector2.ZERO, size).grow(-1.0), 6.0)
			loop.append(loop[0])
			draw_polyline(loop, UI.GILT_HI, 1.6, true)


## Renown, rank and how far to the next rank: a gauge with words on it.
class RenownBar extends Control:
	const UI := preload("res://scripts/ui.gd")
	var profile

	func _draw() -> void:
		if profile == null:
			return
		var Renown = load("res://scripts/renown.gd")
		var pts: int = Renown.points(profile)
		var rk: int = Renown.rank(profile)
		var small := size.y < 40.0
		var font := UI.font("body")
		var left := "%s  ·  %s" % [Renown.TEXT["points"] % pts, Renown.rank_name(rk)]
		UI.draw_label(self, Vector2(0, 16.0 if small else 18.0), left, 16 if small else 18, UI.GILT_HI)
		UI.draw_text(self, font, Vector2(0, 16.0 if small else 18.0), Renown.next_text(profile), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 13, UI.DIM)
		var gr := Rect2(0, size.y - (9.0 if small else 11.0), size.x, 6.0 if small else 7.0)
		var b := UI.Draw.Batch.new()
		UI.gauge_into(b, gr, Renown.progress(profile), UI.GILT, -1.0, Color(1, 1, 1, 0), 0)
		b.flush(self)


## A station's plaque on the engine's destination board.
class StationCard extends Button:
	const UI := preload("res://scripts/ui.gd")
	var station := {}
	var chosen := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed"]:
			var bg := Color(0.13, 0.1, 0.08) if state == "normal" else Color(0.18, 0.14, 0.1)
			if chosen:
				bg = Color(0.22, 0.17, 0.08) if state == "normal" else Color(0.28, 0.21, 0.1)
			add_theme_stylebox_override(state, UI.box(bg, Color(UI.GOLD, 0.95) if chosen else Color(UI.TRAIN_BRASS, 0.5 if state == "normal" else 0.85), 5, 2 if chosen else 1))

	func _draw() -> void:
		var small := size.y < 64.0
		var lamp: Color = station.get("lamp", Color(1.0, 0.78, 0.45))
		draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 4)), Color(lamp, 0.8))
		load("res://scripts/station_view.gd").icon(self, "clock", Vector2(20, size.y * 0.5 + 3.0), 8.0, lamp, 1.6)
		UI.draw_text(self, UI.font("display"), Vector2(36, 28 if small else 34), String(station.get("short", station.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 21 if small else 23, UI.GILT_HI if chosen else UI.TEXT)
		UI.draw_text(self, UI.font("body"), Vector2(36, (28 if small else 34) + 16.0), String(station.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 13, UI.DIM)
