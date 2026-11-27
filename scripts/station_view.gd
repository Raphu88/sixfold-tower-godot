extends Control
## The station drawn behind its page (menu.gd shows it while the station's
## page is open, station_page.gd): a covered platform at dusk, the six
## towers on the horizon with a window lit in each one's essence, iron
## columns holding up a canopy with a scalloped valance, lamps glowing under
## it, the station's sign, and on the walls either side something of the
## stop you're at (Training's rings and weights, the tournament's banners,
## the Noble's curtains and crest, the renown board's pinned notices).
## Each of the six stations looks its own (`look`): its tower stands large
## and near on the horizon, the sky glows in its colour, its canopy and
## columns are painted in its trim, pennants in its banner colour hang
## along the valance, and its sign carries its crest.
## Everything is drawn in code.
##
## The small pieces the page is built from live here too: StopIcon (each
## stop's icon, also on the rail: rail.gd car_icon asks icon()), Tile (a
## lesson, drill, bracket, title, contract or rank: its icon, name, a line,
## a medal or pips, a lock), RenownBar (renown, rank and how far to the next) and
## Crest (the station's own crest under its page's title).

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")

var inset := 0.0  # the rail down the left
var stop := "gym"
var lamp := Art.LAMP
var title := ""  # the station's name, on its sign
var look := {}  # the station (stations.gd STATIONS): its tower, and its colours (lamp, banner, trim, sky)


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
	var sky: Color = look.get("sky", Art.SKY[3])
	Art.vgrad(b, Rect2(0, horizon * 0.45, w, horizon * 0.55 + 1.0), Color(sky, 0.0), Color(sky, 0.35))
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
	# The station's own tower, near and large, on the right of the horizon.
	var own := String(look.get("tower", ""))
	if Towers.TOWERS.has(own):
		_near_tower(b, Vector2(w * 0.82, horizon + 4.0), h * 0.42, own, t)
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
	var trim: Color = look.get("trim", Color(0.16, 0.2, 0.2))
	var banner: Color = look.get("banner", Color(0.3, 0.22, 0.2))
	Art.vgrad(b, Rect2(0, 0, w, roof), trim.darkened(0.25), trim.lightened(0.05))
	b.rect(Rect2(0, roof - 3.0, w, 3.0), Color(Art.GILT, 0.55))
	var sc := 26.0
	for i in int(w / sc) + 1:
		var x0 := i * sc
		b.polygon(PackedVector2Array([Vector2(x0, roof), Vector2(x0 + sc, roof), Vector2(x0 + sc * 0.5, roof + 12.0)]), banner.darkened(0.35) if i % 2 == 0 else trim.lightened(0.1))
		b.circle(Vector2(x0 + sc * 0.5, roof + 9.0), 2.0, Color(Art.GILT, 0.45), 8)
	var gap := 220.0
	var cols := int(w / gap) + 1
	for i in cols:
		var x := 40.0 + i * gap
		b.rect(Rect2(x - 5.0, roof, 10.0, deck - roof), Art.OUTLINE)
		b.rect(Rect2(x - 3.5, roof, 7.0, deck - roof), trim)
		b.rect(Rect2(x - 2.0, roof, 1.5, deck - roof), Color(1, 1, 1, 0.08))
		# A bracket where it meets the canopy, and its foot.
		b.polygon(PackedVector2Array([Vector2(x - 26, roof), Vector2(x + 26, roof), Vector2(x + 4, roof + 22), Vector2(x - 4, roof + 22)]), trim)
		# A pennant in the station's colour on every column.
		b.polygon(PackedVector2Array([Vector2(x + 5, roof + 26), Vector2(x + 30, roof + 34), Vector2(x + 5, roof + 42)]), banner)
		b.line(Vector2(x + 5, roof + 26), Vector2(x + 30, roof + 34), Color(Art.GILT, 0.5), 1.0)
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
		Art.vgrad(sb, sr.grow(-1.0), banner.darkened(0.55), banner.darkened(0.75))
		sb.flush(self)
		UI.draw_text(self, font, Vector2(sr.position.x, sr.end.y - 9.0), title, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs, Art.GILT_HI)


## The station's own tower, near: a tall silhouette in the dusk, banded,
## with lit windows in its essence's colour and its torch burning on top.
## (Static: the opening's towers use it too, opening.gd.)
static func _near_tower(b, base: Vector2, th: float, id: String, t: float) -> void:
	var tw := th * 0.2
	var wc: Color = Essence.color(String(Towers.TOWERS[id].get("essence", "air")))
	var torch: Color = Towers.TOWERS[id].get("torch", wc)
	var body := Art.FAR.lerp(Color(0.08, 0.07, 0.1), 0.4)
	b.polygon(PackedVector2Array([Vector2(base.x - tw * 0.6, base.y), Vector2(base.x - tw * 0.42, base.y - th), Vector2(base.x - tw * 0.62, base.y - th - 8.0),
		Vector2(base.x, base.y - th - tw * 0.9), Vector2(base.x + tw * 0.62, base.y - th - 8.0), Vector2(base.x + tw * 0.42, base.y - th), Vector2(base.x + tw * 0.6, base.y)]), body)
	for k in 4:
		var yy := base.y - th * (0.2 + 0.2 * k)
		b.rect(Rect2(base.x - tw * 0.52, yy, tw * 1.04, 2.0), Color(torch, 0.18))
		var wy := yy - th * 0.08
		Art.light(b, Vector2(base.x, wy), Vector2(16, 16), Color(wc, 0.3))
		b.rect(Rect2(base.x - 2.5, wy - 4.0, 5.0, 8.0), wc.lightened(0.35))
	var flick := 0.85 + 0.15 * sin(t * 6.0)
	var top := Vector2(base.x, base.y - th - tw * 0.9 - 6.0)
	Art.light(b, top, Vector2(60, 60), Color(torch, 0.35 * flick))
	b.circle(top, 4.0, torch.lightened(0.3), 10)


## The stop's things on the walls at both edges (the page covers the middle).
func _dress(b, w: float, h: float, roof: float, deck: float, _t: float) -> void:
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
			"noble":  # heavy curtains drawn back from a crest on a shield
				var top := roof + 14.0
				for sx in [-1.0, 1.0]:
					b.polygon(PackedVector2Array([Vector2(c.x + sx * 6.0, top), Vector2(c.x + sx * 48.0, top), Vector2(c.x + sx * 54.0, deck - 10.0), Vector2(c.x + sx * 30.0, deck - 10.0), Vector2(c.x + sx * 14.0, c.y)]), Color(0.36, 0.08, 0.16))
					b.line(Vector2(c.x + sx * 14.0, c.y), Vector2(c.x + sx * 34.0, c.y + 4.0), Art.GILT, 2.0)
				b.rect(Rect2(c.x - 54, top - 4, 108, 6), Art.GILT.darkened(0.2))
				var sh := Vector2(c.x, c.y - 30.0)
				b.polygon(PackedVector2Array([sh + Vector2(-16, -18), sh + Vector2(16, -18), sh + Vector2(16, 2), sh + Vector2(0, 20), sh + Vector2(-16, 2)]), Art.GILT.darkened(0.25))
				b.polygon(PackedVector2Array([sh + Vector2(-12, -14), sh + Vector2(12, -14), sh + Vector2(12, 1), sh + Vector2(0, 15), sh + Vector2(-12, 1)]), Color(0.18, 0.12, 0.3))
				b.circle(sh + Vector2(0, -2), 4.5, Art.GILT_HI, 10)
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
		"board":  # a notice board with a pinned paper
			ci.draw_rect(Rect2(P.call(-9, -7), Vector2(18, 13) * u), col, false, w)
			ci.draw_rect(Rect2(P.call(-5, -4), Vector2(7, 7) * u), Color(col, 0.55))
			ci.draw_line(P.call(-6, 6), P.call(-7, 10), col, w, true)
			ci.draw_line(P.call(6, 6), P.call(7, 10), col, w, true)
		"noble":  # a crown: a band and three points
			ci.draw_colored_polygon(PackedVector2Array([P.call(-8, 5), P.call(-9, -5), P.call(-4, 0), P.call(0, -8), P.call(4, 0), P.call(9, -5), P.call(8, 5)]), Color(col, 0.55))
			ci.draw_polyline(PackedVector2Array([P.call(-8, 5), P.call(-9, -5), P.call(-4, 0), P.call(0, -8), P.call(4, 0), P.call(9, -5), P.call(8, 5), P.call(-8, 5)]), col, w, true)
			ci.draw_line(P.call(-8, 8), P.call(8, 8), col, w, true)
		"lesson":  # a target: rings and a dot
			ci.draw_arc(c, 8.0 * u, 0, TAU, 20, col, w, true)
			ci.draw_arc(c, 4.5 * u, 0, TAU, 16, col, w, true)
			ci.draw_circle(c, 1.8 * u, col)
		"contract":  # a rolled scroll with a seal
			ci.draw_rect(Rect2(P.call(-7, -8), Vector2(14, 15) * u), col, false, w)
			ci.draw_line(P.call(-9, -8), P.call(9, -8), col, w, true)
			ci.draw_line(P.call(-9, 7), P.call(9, 7), col, w, true)
			ci.draw_line(P.call(-4, -4), P.call(4, -4), Color(col, 0.7), w * 0.8, true)
			ci.draw_line(P.call(-4, -1), P.call(3, -1), Color(col, 0.7), w * 0.8, true)
			ci.draw_circle(P.call(3, 4), 2.6 * u, Color(0.8, 0.25, 0.25))
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

	var base_h := 0.0  # its height with one line under the name (set as it's built)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		base_h = custom_minimum_size.y
		resized.connect(_fit_height)
		restyle()

	func _small() -> bool:
		return (base_h if base_h > 0.0 else size.y) < 50.0

	## Where the words go: [x, width].
	func _words() -> Array:
		var small := _small()
		var x := (20.0 if small else 24.0) + (16.0 if small else 20.0)
		var right := 12.0
		if medal >= 0 or locked:
			right = 34.0
		elif pips_of > 0:
			right = 10.0 + pips_of * 13.0
		return [x, size.x - x - right]

	## A line that doesn't fit beside the icon wraps, and the tile grows to hold it.
	func _line_h() -> float:
		if line == "":
			return 0.0
		return UI.text_height(UI.font("body"), line, _words()[1], 12 if _small() else 13)

	func _fit_height() -> void:
		if base_h <= 0.0 or size.x < 1.0:
			return
		var one: float = UI.font("body").get_height(12 if _small() else 13)
		var want := base_h + maxf(_line_h() - one, 0.0)
		if not is_equal_approx(custom_minimum_size.y, want):
			custom_minimum_size.y = want

	func restyle() -> void:
		for state in ["normal", "hover", "pressed"]:
			var bg := Color(0.13, 0.085, 0.05, 0.92) if state == "normal" else Color(0.19, 0.125, 0.07, 0.95)
			if chosen:
				bg = Color(0.27, 0.19, 0.08, 0.96) if state == "normal" else Color(0.32, 0.23, 0.1, 0.97)
			var st := UI.box(bg, Color(UI.GOLD, 0.95) if chosen else Color(UI.TRAIN_BRASS, 0.45 if state == "normal" else 0.85), 6, 2 if chosen else 1)
			add_theme_stylebox_override(state, st)
		queue_redraw()

	func _draw() -> void:
		var small := _small()
		var a := 0.55 if locked else 1.0
		var ic := Vector2(20.0 if small else 24.0, size.y * 0.5)
		if not load("res://scripts/station_view.gd").icon(self, icon_id, ic, 7.0 if small else 8.5, Color(tint, a), 1.6):
			UI.draw_icon(self, icon_id, ic, 7.0 if small else 8.5, Color(tint, a), 1.6)
		var x: float = _words()[0]
		var w: float = _words()[1]
		var hc: Color = UI.GILT_HI if chosen or lit else UI.TEXT
		# (the name and its line, centred together however many lines the line takes)
		var fs := 12 if small else 13
		var one: float = UI.font("body").get_height(fs)
		var top := size.y * 0.5 - maxf(_line_h() - one, 0.0) * 0.5
		UI.draw_label(self, Vector2(x, top - (1.0 if line != "" else -6.0)), head, 15 if small else 17, Color(hc, a), HORIZONTAL_ALIGNMENT_LEFT, w)
		if line != "":
			UI.draw_text_lines(self, UI.font("body"), Vector2(x, top + 14.0), line, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, Color(UI.DIM, 0.9 * a))
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


## The station's crest under its page's title: a pennant in its banner
## colour with its tower's shape, its city, the tower it's near, and
## whether it's your home station. Tells the six stations apart at a glance.
class Crest extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Towers := preload("res://scripts/towers.gd")
	var station := {}
	var home := false
	var wild_word := ""  # its tower's well runs wild (wild_towers.gd crest_word): the city talks of it

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var T: Dictionary = load("res://scripts/travel.gd").TEXT
		var banner: Color = station.get("banner", UI.GILT)
		var h := size.y
		var b := UI.Draw.Batch.new()
		# The pennant, and the tower's shape on it.
		var pw := h * 0.9
		b.rect(Rect2(pw * 0.5, 2.0, size.x - pw * 0.5, h - 5.0), Color(banner, 0.22))  # (a band of its colour behind the words)
		b.polygon(PackedVector2Array([Vector2(0, 0), Vector2(pw, 0), Vector2(pw, h * 0.8), Vector2(pw * 0.5, h), Vector2(0, h * 0.8)]), banner)
		b.rect(Rect2(0, 0, pw, 2.0), UI.GILT)
		var c := Vector2(pw * 0.5, h * 0.48)
		var tw := h * 0.16
		b.polygon(PackedVector2Array([c + Vector2(-tw, h * 0.3), c + Vector2(-tw * 0.7, -h * 0.18), c + Vector2(0, -h * 0.34), c + Vector2(tw * 0.7, -h * 0.18), c + Vector2(tw, h * 0.3)]), banner.lightened(0.55))
		# A thin rule in its colour under the words.
		b.rect(Rect2(pw, h - 4.0, size.x - pw, 3.0), Color(banner.lightened(0.2), 0.85))
		b.flush(self)
		var tid := String(station.get("tower", ""))
		var near: String = load("res://scripts/travel.gd").near(tid) if Towers.TOWERS.has(tid) else ""
		var tag := String(T["crest_home"] if home else T["crest_visit"])
		var fs := 14 if h < 28.0 else 16
		var font := UI.font("display")
		var name := String(station.get("name", ""))
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UI.draw_text(self, font, Vector2(pw + 8.0, h * 0.5 + fs * 0.35), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - pw - 8.0, fs, banner.lightened(0.5))
		var rest := "%s  ·  %s" % [near, tag] if near != "" else tag
		if wild_word != "":
			rest += "  ·  " + wild_word
		UI.draw_text(self, UI.font("body"), Vector2(pw + 16.0 + nw, h * 0.5 + fs * 0.3), rest, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, size.x - pw - 16.0 - nw), fs - 3, UI.GOLD if home else UI.DIM)

