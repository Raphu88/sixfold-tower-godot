extends RefCounted
## The interface's shared look: one panel style, one slot style and the text
## sizes, used by the HUD (hud.gd), the menus (menu.gd) and the touch
## buttons, so they read as one set. (The world's colours are in
## palette.gd; the interface's are here.)

# Interface colours
const GOLD := Color(0.95, 0.8, 0.5)
const TEXT := Color(0.86, 0.83, 0.9)
const DIM := Color(0.62, 0.59, 0.67)
const FAINT := Color(0.42, 0.4, 0.47)
const PANEL := Color(0.07, 0.063, 0.09, 0.88)
const PANEL_EDGE := Color(0.95, 0.8, 0.5, 0.2)
const MENU_PANEL := Color(0.08, 0.075, 0.1, 0.97)
const SLOT := Color(0.12, 0.11, 0.15, 0.92)
const SLOT_EDGE := Color(0.34, 0.31, 0.39, 0.9)
const SLOT_ON := Color(0.17, 0.13, 0.09, 0.95)
const BUTTON := Color(0.15, 0.14, 0.18)
const BUTTON_HOVER := Color(0.21, 0.19, 0.25)
const BUTTON_DOWN := Color(0.3, 0.25, 0.18)
const SHADE := Color(0.025, 0.022, 0.035, 0.8)
const GOOD := Color(0.55, 0.9, 0.55)
const BAD := Color(1.0, 0.5, 0.42)
const HEALTH := Color(0.78, 0.22, 0.2)
const STAMINA := Color(0.45, 0.72, 0.38)
## The Entity's speech bubbles (its own colours are in entity.gd).
const ENTITY_BG := Color(0.11, 0.09, 0.19)
const ENTITY_EDGE := Color(0.79, 0.75, 1.0, 0.42)

## Text sizes (at the desktop scale; phones draw everything 1.5x bigger).
const SIZE_SMALL := 11
const SIZE_BODY := 13
const SIZE_LABEL := 15
const SIZE_HEADING := 28

## How long menus take to fade in and out (seconds).
const FADE_IN := 0.12
const FADE_OUT := 0.1


static func box(bg: Color, border: Color, radius := 6, border_w := 1, margin := 0.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	if margin > 0.0:
		b.set_content_margin_all(margin)
	return b


## The HUD's panels (bars, marks, cards, prompts).
static func panel() -> StyleBoxFlat:
	return box(PANEL, PANEL_EDGE, 6)


## An item or gear slot; `on` for the one in hand.
static func slot(on := false) -> StyleBoxFlat:
	return box(SLOT_ON if on else SLOT, GOLD if on else SLOT_EDGE, 5)


## The menus' big panel.
static func menu_panel() -> StyleBoxFlat:
	var b := box(MENU_PANEL, PANEL_EDGE, 10, 1, 20.0)
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 12
	return b


## The Entity's speech bubble: deep violet, a soft lavender edge.
static func entity_bubble(margin := 10.0) -> StyleBoxFlat:
	var b := box(Color(ENTITY_BG, 0.94), ENTITY_EDGE, 10, 1, margin)
	b.content_margin_top = margin * 0.6
	b.content_margin_bottom = margin * 0.7
	return b


## A small padlock, for slots and spells that aren't open yet: an outlined,
## shaded body with a shackle and a keyhole.
static func draw_lock(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var b := Draw.Batch.new()
	lock_into(b, c, s, col)
	b.flush(ci)


static func lock_into(b, c: Vector2, s: float, col: Color) -> void:
	var sw := maxf(1.2, s * 0.16)
	var top := c + Vector2(0, -s * 0.22)
	b.arc(top, s * 0.36, PI, TAU, 12, Color(OUTLINE, col.a), sw + 2.0)
	b.arc(top, s * 0.36, PI, TAU, 12, col.darkened(0.15), sw)
	var body := Rect2(c + Vector2(-s * 0.56, -s * 0.24), Vector2(s * 1.12, s * 0.9))
	b.rect(body.grow(1.4), Color(OUTLINE, col.a))
	b.rect(body, col.darkened(0.2))
	b.rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.38)), col)
	b.rect(Rect2(body.position + Vector2(s * 0.08, s * 0.06), Vector2(body.size.x * 0.3, s * 0.1)), Color(col.lightened(0.5), 0.6 * col.a))
	b.dot(c + Vector2(0, s * 0.14), s * 0.13, Color(OUTLINE, 0.85 * col.a))
	b.rect(Rect2(c + Vector2(-s * 0.05, s * 0.14), Vector2(s * 0.1, s * 0.26)), Color(OUTLINE, 0.85 * col.a))


# --- drawn pieces (menus and HUD) ------------------------------------------------
# Filled, outlined and shaded like the characters (see draw_util.gd's style
# guide), lit from the top-left. Each builds into a Batch, so a whole
# medallion or bar is one draw call. Menus and HUD are unlit, so these are
# cheap; the item and gear icons (items.gd, gear.gd) follow the same look.

const Draw := preload("res://scripts/draw_util.gd")
const OUTLINE := Color(0.03, 0.025, 0.04)
## HUD sizes (a setting): how much bigger or smaller the HUD is drawn.
const HUD_SCALES := {"small": 0.85, "normal": 1.0, "large": 1.2}
const HUD_SCALE_ORDER := ["small", "normal", "large"]


## A capsule (a bar with round ends) from x0 to x1 along y, `r` its half height.
static func capsule(b, x0: float, x1: float, y: float, r: float, col: Color) -> void:
	if x1 - x0 <= 0.5:
		return
	if x1 - x0 < r * 2.0:
		# Too short for both ends: a squashed dot.
		var w := (x1 - x0) * 0.5
		b.polygon(_oval(Vector2(x0 + w, y), Vector2(w, r * minf(1.0, w / r + 0.35)), 14), col)
		return
	b.rect(Rect2(x0 + r, y - r, x1 - x0 - r * 2.0, r * 2.0), col)
	b.dot(Vector2(x0 + r, y), r, col)
	b.dot(Vector2(x1 - r, y), r, col)


static func _oval(c: Vector2, rad: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return pts


## A gauge: a dark rounded trough with an outline, filled to `k` with a lit
## top band and a soft highlight; `trail` (above k) shows recent loss.
static func bar_into(b, r: Rect2, k: float, col: Color, trail := -1.0, trail_col := Color(1.0, 0.85, 0.6, 0.85)) -> void:
	var h := r.size.y * 0.5
	var y := r.position.y + h
	var x0 := r.position.x
	var x1 := r.end.x
	capsule(b, x0 - 1.6, x1 + 1.6, y, h + 1.6, OUTLINE)
	capsule(b, x0, x1, y, h, col.darkened(0.78))
	capsule(b, x0 + 1.0, x1 - 1.0, y + h * 0.35, h * 0.55, Color(0, 0, 0, 0.25))  # the trough's inner shadow
	k = clampf(k, 0.0, 1.0)
	if trail > k:
		capsule(b, x0, x0 + r.size.x * clampf(trail, 0.0, 1.0), y, h, trail_col)
	if k <= 0.0:
		return
	var xe := x0 + r.size.x * k
	capsule(b, x0, xe, y, h, col.darkened(0.25))
	capsule(b, x0, xe, y - h * 0.12, h * 0.82, col)
	if h >= 2.5:
		capsule(b, x0 + h * 0.5, xe - h * 0.4, y - h * 0.42, h * 0.32, Color(col.lightened(0.55), 0.55))


static func draw_bar(ci: CanvasItem, r: Rect2, k: float, col: Color, trail := -1.0) -> void:
	var b := Draw.Batch.new()
	bar_into(b, r, k, col, trail)
	b.flush(ci)


## A soft round glow (rings of falling alpha).
static func glow_into(b, c: Vector2, r: float, col: Color, strength := 1.0) -> void:
	for i in 5:
		var k := 1.0 - i / 5.0
		b.dot(c, r * (0.45 + 0.55 * k), Color(col, 0.07 * strength))


## A faceted essence gem in the essence's colour.
static func gem_into(b, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * r)
	b.poly(pts, col.darkened(0.3), 1.0)
	var light := Draw.LIGHT_DIR.normalized()
	for i in 6:
		var a := pts[i]
		var bb := pts[(i + 1) % 6]
		var n := ((a + bb) * 0.5 - c).normalized()
		var lit := n.dot(light)
		b.polygon(PackedVector2Array([c, a, bb]), col.lightened(0.3 * lit) if lit > 0.0 else col.darkened(-0.35 * lit))
	b.polygon(PackedVector2Array([c + Vector2(-r * 0.42, -r * 0.2), c + Vector2(0, -r * 0.62), c + Vector2(r * 0.1, -r * 0.18)]), Color(1, 1, 1, 0.45))


static func draw_gem(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var b := Draw.Batch.new()
	gem_into(b, c, r, col)
	b.flush(ci)


## A bond's emblem, by the essence that formed it: air a three-bladed
## swirl, water a drop, fire a flame, stone a cut gem, iron a shield, blade
## a four-pointed star. Filled, outlined (`outline` 0 for none) and shaded.
static func emblem_into(b, c: Vector2, r: float, affinity: String, col: Color, outline := 1.2) -> void:
	var light := Draw.LIGHT_DIR.normalized()
	var hi := Color(col.lightened(0.55), 0.7)
	match affinity:
		"air":
			for i in 3:
				var blade := _swirl_blade(c, r, -PI / 2.0 + TAU * i / 3.0)
				b.poly(blade, col.darkened(0.15) if i != 0 else col, outline)
			b.ball(c, r * 0.2, col.lightened(0.2), outline > 0.0)
		"water":
			var drop := _drop(c, r)
			b.poly(drop, col.darkened(0.3), outline)
			b.polygon(_drop(c + light * r * 0.08, r * 0.82), col)
			# A wave across it, and a glint.
			var wave := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				wave.append(c + Vector2(lerpf(-0.42, 0.42, t) * r, r * (0.38 + 0.08 * sin(t * TAU))))
			b.path(wave, Color(col.lightened(0.4), 0.6), maxf(1.0, r * 0.09))
			b.polygon(_oval(c + Vector2(-r * 0.2, r * 0.02), Vector2(r * 0.1, r * 0.2), 10), hi)
		"fire":
			b.poly(_flame(c, r), col.darkened(0.25), outline)
			b.polygon(_flame(c + Vector2(0, r * 0.12), r * 0.78), col)
			b.polygon(_flame(c + Vector2(0, r * 0.38), r * 0.42), col.lightened(0.5))
		"stone":
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * r * Vector2(0.9, 1.0))
			b.poly(pts, col.darkened(0.35), outline)
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.45 + Vector2(0, -r * 0.05))
			for i in 6:
				var n := ((pts[i] + pts[(i + 1) % 6]) * 0.5 - c).normalized()
				var lit := n.dot(light)
				var fc := col.lightened(0.28 * lit) if lit > 0.0 else col.darkened(-0.32 * lit)
				b.polygon(PackedVector2Array([pts[i], pts[(i + 1) % 6], inner[(i + 1) % 6], inner[i]]), fc)
			b.polygon(inner, col.lightened(0.18))
			b.polygon(PackedVector2Array([inner[5], inner[0], inner[1], c + Vector2(0, -r * 0.05)]), hi)
		"iron":
			var sh := PackedVector2Array([c + Vector2(-0.78, -0.82) * r, c + Vector2(0, -0.98) * r, c + Vector2(0.78, -0.82) * r,
				c + Vector2(0.74, 0.0) * r, c + Vector2(0.42, 0.62) * r, c + Vector2(0, 1.0) * r,
				c + Vector2(-0.42, 0.62) * r, c + Vector2(-0.74, 0.0) * r])
			b.poly(sh, col.darkened(0.35), outline)
			var lh := PackedVector2Array([c + Vector2(-0.64, -0.7) * r, c + Vector2(0, -0.84) * r, c + Vector2(0, 0.82) * r,
				c + Vector2(-0.34, 0.52) * r, c + Vector2(-0.6, -0.02) * r])
			b.polygon(lh, col.lightened(0.12))
			var rh := PackedVector2Array([c + Vector2(0, -0.84) * r, c + Vector2(0.64, -0.7) * r, c + Vector2(0.6, -0.02) * r,
				c + Vector2(0.34, 0.52) * r, c + Vector2(0, 0.82) * r])
			b.polygon(rh, col.darkened(0.1))
			b.ball(c + Vector2(0, -0.08) * r, r * 0.24, col.lightened(0.25), outline > 0.0)
		"blade":
			var star := PackedVector2Array()
			for i in 8:
				var a := -PI / 2.0 + TAU * i / 8.0
				var rr := r * (1.0 if i % 4 == 0 else (0.62 if i % 2 == 0 else 0.24))
				star.append(c + Vector2.from_angle(a) * rr)
			b.poly(star, col.darkened(0.3), outline)
			for i in 8:
				var a0 := star[i]
				var a1 := star[(i + 1) % 8]
				var n := ((a0 + a1) * 0.5 - c).normalized()
				var lit := n.dot(light)
				b.polygon(PackedVector2Array([c, a0, a1]), col.lightened(0.3 * lit) if lit > 0.0 else col.darkened(-0.3 * lit))
		_:
			b.ball(c, r * 0.7, col, outline > 0.0)


static func _swirl_blade(c: Vector2, r: float, a0: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 8
	for i in n + 1:
		var t := float(i) / n
		pts.append(c + Vector2.from_angle(a0 + t * 1.9) * r * (0.22 + 0.78 * t))
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		pts.append(c + Vector2.from_angle(a0 + t * 1.9 - 0.25 * sin(PI * t)) * r * (0.22 + 0.78 * t) * (1.0 - 0.42 * sin(PI * t)))
	return pts


static func _drop(c: Vector2, r: float) -> PackedVector2Array:
	var cc := c + Vector2(0, r * 0.3)
	var rad := r * 0.62
	var phi := asin(rad / (r * 1.3))
	var pts := PackedVector2Array([c + Vector2(0, -r)])
	var n := 16
	for i in n + 1:
		var a := lerpf(-phi, PI + phi, float(i) / n)
		pts.append(cc + Vector2.from_angle(a) * rad)
	return pts


static func _flame(c: Vector2, r: float) -> PackedVector2Array:
	var unit := [Vector2(0, -1.0), Vector2(0.2, -0.62), Vector2(0.42, -0.72), Vector2(0.44, -0.3),
		Vector2(0.64, -0.06), Vector2(0.66, 0.34), Vector2(0.48, 0.7), Vector2(0.2, 0.9), Vector2(0, 0.94),
		Vector2(-0.2, 0.9), Vector2(-0.48, 0.7), Vector2(-0.66, 0.34), Vector2(-0.6, -0.02),
		Vector2(-0.4, -0.38), Vector2(-0.3, -0.12), Vector2(-0.14, -0.5)]
	var pts := PackedVector2Array()
	for u in unit:
		pts.append(c + u * r)
	return pts


## A mark's medallion: a dark disc with a gauge ring (filled to `k` in the
## bond's colour), its emblem inside, and step pips below. `glow` lights it
## up (a spell ready to cast); `faint` dims it.
static func medallion_into(b, c: Vector2, r: float, col: Color, affinity: String, k := 1.0, step := 0, glow := 0.0, faint := false) -> void:
	if glow > 0.0:
		glow_into(b, c, r * 1.9, col, glow)
	var ring := maxf(2.0, r * 0.16)
	b.dot(c, r + 2.6, Color(OUTLINE, Draw.FEATHER_ALPHA))
	b.dot(c, r + 1.6, OUTLINE)
	b.dot(c, r, col.darkened(0.82))
	# The gauge: a dark track, then the filled part, then a bright edge.
	b.arc(c, r - ring * 0.5, 0.0, TAU, 40, col.darkened(0.6), ring)
	if k > 0.0:
		var a1 := -PI / 2.0 + TAU * clampf(k, 0.0, 1.0)
		var n := maxi(4, int(40 * k))
		b.arc(c, r - ring * 0.5, -PI / 2.0, a1, n, Color(col, 0.55 if faint else 1.0), ring)
		b.arc(c, r - ring * 0.3, -PI / 2.0, a1, n, Color(col.lightened(0.45), 0.25 if faint else 0.5), ring * 0.28)
	var inner := r - ring - 1.2
	b.dot(c, inner, Color(0.05, 0.045, 0.07))
	b.dot(c + Draw.LIGHT_DIR * inner * 0.18, inner * 0.82, col.darkened(0.7))
	emblem_into(b, c, inner * 0.68, affinity, col if not faint else col.darkened(0.35), 1.0 if r > 14.0 else 0.0)
	if step > 0:
		for i in 5:
			var a := PI / 2.0 + (i - 2) * 0.32
			var p := c + Vector2.from_angle(a) * (r + ring * 0.2 + 3.2)
			b.dot(p, 2.4, OUTLINE)
			b.dot(p, 1.6, col.lightened(0.2) if i < step else Color(0.25, 0.23, 0.3))


static func draw_medallion(ci: CanvasItem, c: Vector2, r: float, col: Color, affinity: String, k := 1.0, step := 0, glow := 0.0, faint := false) -> void:
	var b := Draw.Batch.new()
	medallion_into(b, c, r, col, affinity, k, step, glow, faint)
	b.flush(ci)


## An empty socket: a body part with no mark yet (a gold arc where one is forming).
static func socket_into(b, c: Vector2, r: float, forming := 0.0) -> void:
	b.dot(c, r + 1.6, OUTLINE)
	b.dot(c, r, Color(0.1, 0.095, 0.13))
	b.arc(c, r * 0.72, 0.0, TAU, 28, Color(0.36, 0.33, 0.42), maxf(1.0, r * 0.1))
	if forming > 0.0:
		b.arc(c, r * 0.72, -PI / 2.0, -PI / 2.0 + TAU * clampf(forming, 0.0, 1.0), 28, GOLD, maxf(1.2, r * 0.14))


## A small rounded key badge ("Q", "LB"), for cast and use keys. Returns its size.
static func draw_key(ci: CanvasItem, at: Vector2, key: String, size := 11, col := GOLD) -> Vector2:
	var font := ThemeDB.fallback_font
	var w := maxf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8.0, size + 5.0)
	var r := Rect2(at, Vector2(w, size + 5.0))
	ci.draw_style_box(_key_box(), r)
	ci.draw_string(font, Vector2(r.position.x, r.end.y - 4.0), key, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
	return r.size


static var _key_style: StyleBoxFlat


static func _key_box() -> StyleBoxFlat:
	if _key_style == null:
		_key_style = box(Color(0.05, 0.045, 0.07, 0.92), Color(GOLD, 0.45), 4)
		_key_style.border_width_bottom = 2
	return _key_style
